"""Gera o exterior da base (cratera Gale, Marte) do zero e renderiza um PNG em pixel art
por câmera externa e por estado. Gray-box: geometria simples e legível, para o time
preencher depois; não é arte final.

Uso (da raiz do repo, caminho absoluto no script porque o Blender é o Flatpak):
    blender -b --factory-startup -P $PWD/arte/blender/exterior.py
    blender -b --factory-startup -P $PWD/arte/blender/exterior.py -- \
        --estados normal --cameras painel,rocha
    blender -b --factory-startup -P $PWD/arte/blender/exterior.py -- --salvar-blend --sem-render

Fonte da verdade: este script. O .blend de --salvar-blend (arte/blender/.render/exterior.blend,
pasta ignorada no git) é só para abrir e mexer; nada o lê de volta.
Os helpers (materiais, caixa, cilindro, EXR, contorno, paleta) vêm do comodo.py.

Mesma geometria e mesma câmera em todos os estados; o estado muda só luz, céu e névoa.
A névoa é aplicada depois do render, pelo passe de profundidade (o Cycles não a desenha).

Referencial: +x leste, +y para o Monte Sharp (a SSO do pouso real da Curiosity, então o
"sul" daqui é +y), +z para cima. Unidades em metros. O Sol vem de trás das câmeras.

Paleta: Apollo, de AdamCYounis (https://lospec.com/palette-list/apollo).
"""

import argparse
import math
import random
import sys
import types
from pathlib import Path

sys.dont_write_bytecode = True                      # sem __pycache__ dentro de arte/
sys.path.insert(0, str(Path(__file__).resolve().parent))

import bmesh                                        # noqa: E402
import bpy                                          # noqa: E402
import numpy as np                                  # noqa: E402
from mathutils import Vector, noise                 # noqa: E402

import comodo as c                                  # noqa: E402

RAIZ = c.RAIZ
CACHE = c.CACHE
hexrgb = c.hexrgb

ESTADOS = ["normal", "poeira"]

# nome: (posição do olho, alvo, campo vertical em graus). As quatro câmeras de parede saem
# das cápsulas no teto do habitat (as telas do interior); a visão geral está só no ar.
CAMERAS = {
    "painel": ((3.05, -1.2, 2.4), (14.0, 6.0, 1.0), 38.0),
    "rocha": ((13.5, -3.5, 2.6), (9.6, 2.6, 1.0), 38.0),
    "amostra": ((-1.4, 2.55, 2.4), (-0.3, 6.9, 0.4), 38.0),
    "moxie": ((-2.0, -6.8, 2.6), (2.3, -2.2, 0.8), 38.0),
    "visao_geral": ((-7.5, -16.5, 3.6), (9.0, 5.5, 1.3), 40.0),
}

POSTES = {"rocha", "moxie"}      # câmeras que ficam num poste, não na parede
LARGURA_PAINEL, PROFUNDIDADE_PAINEL, INCLINACAO_PAINEL = 3.0, 1.7, 14.0
ROCHA = Vector((7.6, 3.0, 0.0))
ROVER = Vector((11.6, 2.2, 0.0))
AMOSTRA = Vector((-0.8, 7.5, 0.0))
MONTE_SHARP = Vector((2500.0, 5100.0, 0.0))


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser(prog="exterior.py")
    p.add_argument("--estados", default=",".join(ESTADOS), help="lista separada por vírgula")
    p.add_argument("--cameras", default=",".join(CAMERAS), help="lista separada por vírgula")
    p.add_argument("--largura", type=int, default=640)
    p.add_argument("--altura", type=int, default=360)
    p.add_argument("--saida", default="assets/exterior")
    p.add_argument("--amostras", type=int, default=64)
    p.add_argument("--salvar-blend", action="store_true",
                   help="grava a cena em arte/blender/.render/exterior.blend")
    p.add_argument("--sem-render", action="store_true", help="só constrói (útil com --salvar-blend)")
    a = p.parse_args(argv)
    for nome, validos in (("estados", ESTADOS), ("cameras", list(CAMERAS))):
        for x in getattr(a, nome).split(","):
            if x and x not in validos:
                p.error(f"--{nome}: {x!r} não existe (use {', '.join(validos)})")
    return a


# ---------------------------------------------------------------- ajudantes

_INDICES = {}
_PROX = iter(range(1, 100000))


def idx(grupo=None):
    """Índice de objeto. Com grupo, objetos do mesmo grupo não ganham contorno entre si."""
    if grupo is None:
        return next(_PROX)
    if grupo not in _INDICES:
        _INDICES[grupo] = next(_PROX)
    return _INDICES[grupo]


def mat(nome, hexa, rugosidade=0.9):
    m = c.material(nome, hexrgb(hexa), rugosidade)
    m.node_tree.nodes["Principled BSDF"].inputs["Specular IOR Level"].default_value = 0.0
    return m


def alinhar(ob, direcao, eixo="Z", cima="Y"):
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = Vector(direcao).to_track_quat(eixo, cima)
    return ob


def barra(nome, a, b, esp, m, indice):
    a, b = Vector(a), Vector(b)
    ob = c.caixa(nome, (a + b) / 2, (esp, esp, (b - a).length), m, indice)
    return alinhar(ob, b - a, "Z", "Y")


def tubo(nome, a, b, raio, m, indice, segs=12):
    a, b = Vector(a), Vector(b)
    ob = c.cilindro(nome, (a + b) / 2, raio, (b - a).length, m, indice, segs=segs)
    return alinhar(ob, b - a, "Z", "Y")


def tronco(nome, centro, r1, r2, h, m, indice, rot=(0, 0, 0), segs=24):
    me = bpy.data.meshes.new(nome)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=h)
    bm.to_mesh(me)
    bm.free()
    ob = c._objeto(nome, me, m, indice)
    ob.location = centro
    ob.rotation_euler = [math.radians(a) for a in rot]
    return ob


def pedra(nome, centro, raios, m, indice, semente, sub=2, rugosidade=0.28, yaw=0.0):
    """Pedra facetada: icosfera deformada por ruído, base achatada (enterrada)."""
    me = bpy.data.meshes.new(nome)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
    off = Vector((semente * 7.31, semente * 3.17, semente * 1.93))
    for v in bm.verts:
        v.co *= 1.0 + rugosidade * noise.noise(v.co * 1.6 + off)
        v.co.x *= raios[0]
        v.co.y *= raios[1]
        v.co.z = max(v.co.z * raios[2], -0.35 * raios[2])
    bm.to_mesh(me)
    bm.free()
    ob = c._objeto(nome, me, m, indice)
    ob.location = centro
    ob.rotation_euler = (0, 0, yaw)
    return ob


def cotovelo(base, alvo, l1, l2, cima=(0, 0, 1)):
    """Dois segmentos que ligam base a alvo; devolve o cotovelo (curvado para cima)."""
    base, alvo = Vector(base), Vector(alvo)
    d = (alvo - base).length
    assert d < l1 + l2 - 0.02, f"braço não alcança: {d:.2f} > {l1 + l2:.2f}"
    u = (alvo - base) / d
    a = (l1 ** 2 - l2 ** 2 + d ** 2) / (2 * d)
    h = math.sqrt(max(l1 ** 2 - a ** 2, 0.0))
    perp = Vector(cima) - u * Vector(cima).dot(u)
    return base + u * a + perp.normalized() * h


def braco(nome, base, alvo, l1, l2, m_seg, m_junta, esp=0.09):
    e = cotovelo(base, alvo, l1, l2)
    barra(f"{nome}_seg1", base, e, esp, m_seg, idx())
    barra(f"{nome}_seg2", e, alvo, esp * 0.85, m_seg, idx())
    for k, p in enumerate((base, e, alvo)):
        c.caixa(f"{nome}_junta{k}", p, (esp * 1.6,) * 3, m_junta, idx())
    return e


# ---------------------------------------------------------------- relevo

def _ondas():
    rng = random.Random(11)
    ondas = []
    for comp in (260, 170, 110, 70, 40, 26, 16, 10, 6.5, 4.0, 2.6, 1.7):
        amp = 0.012 * comp if comp >= 60 else (0.011 * comp if comp >= 10 else 0.0075 * comp)
        ang = rng.uniform(0, math.pi)
        ondas.append((comp, amp, math.cos(ang), math.sin(ang), rng.uniform(0, 2 * math.pi)))
    return ondas


ONDAS = _ondas()


def _suave(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3 - 2 * t)


def _sdf_retangulo(x, y, x0, x1, y0, y1):
    return np.hypot(np.maximum(np.maximum(x0 - x, x - x1), 0), np.maximum(np.maximum(y0 - y, y - y1), 0))


def _plano(x, y):
    """1 onde o chão é aterrado e plano (base, campo de painéis, área de amostra)."""
    m = np.zeros_like(x)
    for x0, x1, y0, y1, borda in ((-6.5, 6.0, -4.8, 3.2, 3.5), (5.0, 27.0, 0.0, 13.8, 3.0),
                                  (-5.5, 3.5, 3.0, 10.8, 3.0)):
        m = np.maximum(m, 1 - _suave(_sdf_retangulo(x, y, x0, x1, y0, y1) / borda))
    return m


def altura(x, y, so_grandes=False):
    """Relevo do chão. Só componentes grandes (>= 60 m) quando a grade é grossa; as menores
    somem até 80 m do centro, onde a grade fina encontra a grossa sem degrau."""
    x = np.asarray(x, float)
    y = np.asarray(y, float)
    r = np.maximum(np.abs(x), np.abs(y))
    h = np.zeros_like(x)
    for comp, amp, cx, sy, fase in ONDAS:
        if comp < 60:
            if so_grandes:
                continue
            f = 1 - _suave((r - 50.0) / 30.0)
        else:
            f = 1.0
        h += f * amp * np.sin((x * cx + y * sy) * 2 * math.pi / comp + fase)
    h *= 1 - _plano(x, y)
    # monte de regolito sobre o abrigo (o anexo do lado oeste, enterrado para a radiação)
    d = _sdf_retangulo(x, y, -5.2, -2.8, -0.1, 2.0)
    h += 1.35 * (1 - _suave(d / 3.0)) ** 1.2
    return h


def grade(nome, lado, passo, m, so_grandes=False, furo=None):
    n = int(round(2 * lado / passo))
    xs = np.linspace(-lado, lado, n + 1)
    X, Y = np.meshgrid(xs, xs)
    Z = altura(X, Y, so_grandes)
    verts = np.stack([X.ravel(), Y.ravel(), Z.ravel()], 1)
    i, j = np.meshgrid(np.arange(n), np.arange(n))
    v0 = (j * (n + 1) + i).ravel()
    faces = np.stack([v0, v0 + 1, v0 + n + 2, v0 + n + 1], 1)
    if furo is not None:
        cx = (xs[:-1] + xs[1:]) / 2
        CX, CY = np.meshgrid(cx, cx)
        manter = ~((np.abs(CX) < furo) & (np.abs(CY) < furo)).ravel()
        faces = faces[manter]
    me = bpy.data.meshes.new(nome)
    me.from_pydata(verts.tolist(), [], faces.tolist())
    me.update()
    me.shade_smooth()
    return c._objeto(nome, me, m, idx("chao"))


def material_regolito(nome):
    """Chão: ruído grande em três tons; longe, cor chapada (sem chuvisco de pixel)."""
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 1.0
    b.inputs["Specular IOR Level"].default_value = 0.0
    tc = nt.nodes.new("ShaderNodeTexCoord")
    n1 = nt.nodes.new("ShaderNodeTexNoise")
    n1.inputs["Scale"].default_value = 0.35
    n1.inputs["Detail"].default_value = 4.0
    n2 = nt.nodes.new("ShaderNodeTexNoise")
    n2.inputs["Scale"].default_value = 2.0
    mix = nt.nodes.new("ShaderNodeMath")
    mix.operation = "MULTIPLY_ADD"
    mix.inputs[1].default_value = 0.25
    rampa = nt.nodes.new("ShaderNodeValToRGB")
    rampa.color_ramp.elements[0].color = (*hexrgb("602c2c"), 1)
    rampa.color_ramp.elements[1].color = (*hexrgb("ad7757"), 1)
    e = rampa.color_ramp.elements.new(0.5)
    e.color = (*hexrgb("7a4841"), 1)
    luz = nt.nodes.new("ShaderNodeLightPath")
    dist = nt.nodes.new("ShaderNodeMapRange")
    dist.inputs["From Min"].default_value = 40.0
    dist.inputs["From Max"].default_value = 160.0
    chapado = nt.nodes.new("ShaderNodeMix")
    chapado.data_type = "RGBA"
    chapado.inputs["B"].default_value = (*hexrgb("7a4841"), 1)
    nt.links.new(tc.outputs["Object"], n1.inputs["Vector"])
    nt.links.new(tc.outputs["Object"], n2.inputs["Vector"])
    nt.links.new(n2.outputs["Fac"], mix.inputs[0])
    nt.links.new(n1.outputs["Fac"], mix.inputs[2])
    nt.links.new(mix.outputs["Value"], rampa.inputs["Fac"])
    nt.links.new(luz.outputs["Ray Length"], dist.inputs["Value"])
    nt.links.new(dist.outputs["Result"], chapado.inputs["Factor"])
    nt.links.new(rampa.outputs["Color"], chapado.inputs["A"])
    nt.links.new(chapado.outputs["Result"], b.inputs["Base Color"])
    c.MATS[nome] = m
    return m


def material_painel(nome, sujeira, deslocamento, limpo_ate=None):
    """Célula solar azul com nervuras; poeira em manchas. limpo_ate: fração do painel (em x)
    onde a escova já passou."""
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.6
    b.inputs["Specular IOR Level"].default_value = 0.2
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    mapa = nt.nodes.new("ShaderNodeMapping")
    mapa.inputs["Scale"].default_value = (6.0, 3.4, 1.0)
    tijolo = nt.nodes.new("ShaderNodeTexBrick")
    tijolo.offset = 0.0
    tijolo.inputs["Color1"].default_value = (*hexrgb("253a5e"), 1)
    tijolo.inputs["Color2"].default_value = (*hexrgb("253a5e"), 1)
    tijolo.inputs["Mortar"].default_value = (*hexrgb("4f8fba"), 1)
    tijolo.inputs["Mortar Size"].default_value = 0.05
    tijolo.inputs["Brick Width"].default_value = 1.0
    tijolo.inputs["Row Height"].default_value = 1.0
    ruido = nt.nodes.new("ShaderNodeTexNoise")
    ruido.inputs["Scale"].default_value = 3.0
    ruido.inputs["Detail"].default_value = 3.0
    desl = nt.nodes.new("ShaderNodeVectorMath")
    desl.operation = "ADD"
    desl.inputs[1].default_value = deslocamento
    cut = nt.nodes.new("ShaderNodeMath")
    cut.operation = "GREATER_THAN"
    cut.inputs[1].default_value = 1.0 - sujeira
    mask = cut
    nt.links.new(tc.outputs["Generated"], mapa.inputs["Vector"])
    nt.links.new(mapa.outputs["Vector"], tijolo.inputs["Vector"])
    nt.links.new(tc.outputs["Generated"], desl.inputs[0])
    nt.links.new(desl.outputs["Vector"], ruido.inputs["Vector"])
    nt.links.new(ruido.outputs["Fac"], cut.inputs[0])
    if limpo_ate is not None:
        nt.links.new(tc.outputs["Generated"], sep.inputs[0])
        dir_ = nt.nodes.new("ShaderNodeMath")
        dir_.operation = "GREATER_THAN"
        dir_.inputs[1].default_value = limpo_ate
        nt.links.new(sep.outputs["X"], dir_.inputs[0])
        prod = nt.nodes.new("ShaderNodeMath")
        prod.operation = "MULTIPLY"
        nt.links.new(cut.outputs["Value"], prod.inputs[0])
        nt.links.new(dir_.outputs["Value"], prod.inputs[1])
        mask = prod
    poeira = nt.nodes.new("ShaderNodeMix")
    poeira.data_type = "RGBA"
    poeira.inputs["B"].default_value = (*hexrgb("c09473"), 1)
    nt.links.new(mask.outputs["Value"], poeira.inputs["Factor"])
    nt.links.new(tijolo.outputs["Color"], poeira.inputs["A"])
    nt.links.new(poeira.outputs["Result"], b.inputs["Base Color"])
    c.MATS[nome] = m
    return m


# ---------------------------------------------------------------- cena

def construir():
    """Devolve as luzes e os nós que mudam por estado."""
    s = bpy.context.scene

    regolito = material_regolito("regolito")
    grade("chao_proximo", 80.0, 0.5, regolito)
    grade("chao_medio", 3000.0, 25.0, regolito, so_grandes=True, furo=80.0)
    far = bpy.data.meshes.new("chao_longe")
    far.from_pydata([(-16000, -16000, -0.6), (16000, -16000, -0.6), (16000, 16000, -0.6),
                     (-16000, 16000, -0.6)], [], [(0, 1, 2, 3)])
    c._objeto("chao_longe", far, regolito, idx("chao"))
    seguro = bpy.data.meshes.new("chao_base")          # pega raio que escape por fresta
    seguro.from_pydata([(-90, -90, -3), (90, -90, -3), (90, 90, -3), (-90, 90, -3)], [], [(0, 1, 2, 3)])
    c._objeto("chao_base", seguro, regolito, idx("chao"))

    paisagem()
    habitat()
    moxie()
    campo_de_paineis()
    rover_e_rocha()
    area_de_amostra()
    pedras_soltas()
    cabos()
    return luzes_e_mundo()


def paisagem():
    """Monte Sharp em camadas (estratos) e a borda da cratera, bem longe."""
    estratos = [("7a4841", 3000, 2750, 90), ("ad7757", 2750, 2300, 110), ("4d2b32", 2300, 2150, 70),
                ("c09473", 2150, 1650, 120), ("7a4841", 1650, 1500, 60), ("ad7757", 1500, 1000, 100),
                ("4d2b32", 1000, 880, 50), ("c09473", 880, 450, 60), ("7a4841", 450, 380, 30)]
    z = 0.0
    for k, (cor, r1, r2, h) in enumerate(estratos):
        m = mat(f"estrato_{k}", cor, 1.0)
        tronco(f"monte_sharp_{k}", MONTE_SHARP + Vector((0, 0, z + h / 2)), r1, r2, h, m,
               idx("monte"), segs=64)
        z += h
    # borda da cratera: uma faixa baixa e irregular num arco atrás do monte
    me = bpy.data.meshes.new("borda_cratera")
    rng = random.Random(5)
    verts, faces = [], []
    n = 120
    for k in range(n + 1):
        ang = math.radians(-110 + 220 * k / n)
        h = 140 + 90 * noise.noise(Vector((k * 0.17, 3.1, 0.0))) + rng.uniform(-18, 18)
        for r, zz in ((8700, -50), (9100, h), (9600, -50)):
            verts.append((r * math.sin(ang), r * math.cos(ang), zz))
    for k in range(n):
        for q in range(2):
            a = 3 * k + q
            faces.append((a, a + 1, a + 4, a + 3))
    me.from_pydata(verts, [], faces)
    me.update()
    me.shade_smooth()
    c._objeto("borda_cratera", me, mat("borda", "7a4841", 1.0), idx("monte"))


def habitat():
    casco = mat("casco", "c7cfcc")
    base = mat("casco_base", "577277")
    nerv = mat("casco_nervura", "819796")
    teto = mat("casco_teto", "a8b5b2")
    vidro = mat("vidro", "10141f", 0.2)
    escuro = mat("escuro", "151d28")
    faixa = mat("faixa_abrigo", "de9e41")
    abrigo = mat("abrigo", "a8b5b2")
    farol = mat("farol", "a53030", 0.5)
    i = idx
    Wd, y0, y1, H = 2.8, -1.4, 2.4, 2.6
    yc = (y0 + y1) / 2

    c.caixa("habitat", (0, yc, H / 2), (2 * Wd, y1 - y0, H), casco, i())
    c.caixa("habitat_saia", (0, yc, 0.25), (2 * Wd + 0.3, y1 - y0 + 0.3, 0.5), base, i())
    c.caixa("habitat_teto", (0, yc, H + 0.04), (2 * Wd + 0.1, y1 - y0 + 0.1, 0.08), teto, i())
    # nervuras verticais nas quatro paredes (como as do interior)
    for x in (-2.0, 0.0, 2.0):
        c.caixa(f"nervura_s{x}", (x, y0 - 0.04, 1.3), (0.14, 0.08, 2.3), nerv, i())
        if x != -2.0:                                   # a janela fica nesse trecho da parede norte
            c.caixa(f"nervura_n{x}", (x, y1 + 0.04, 1.3), (0.14, 0.08, 2.3), nerv, i())
    for y in (-0.2, 1.4):
        c.caixa(f"nervura_l{y}", (Wd + 0.04, y, 1.3), (0.08, 0.14, 2.3), nerv, i())
    # calha de cabos, a 2,05 m como no interior
    c.caixa("calha_ext_sul", (0, y0 - 0.1, 2.05), (2 * Wd, 0.12, 0.12), nerv, i())
    c.caixa("calha_ext_norte", (0, y1 + 0.1, 2.05), (2 * Wd, 0.12, 0.12), nerv, i())
    # janela da parede norte, à esquerda (interior: parede da frente, x -2,05, z 1,64)
    c.caixa("janela_moldura_ext", (-2.05, y1 + 0.04, 1.64), (1.0, 0.1, 0.72), escuro, i())
    c.caixa("janela_ext", (-2.05, y1 + 0.1, 1.64), (0.84, 0.02, 0.56), vidro, i())

    # abrigo (a porta do interior abre para ele): anexo baixo, enterrado num monte
    c.caixa("abrigo_corpo", (-4.0, 0.95, 1.0), (2.4, 2.1, 2.0), abrigo, i())
    c.caixa("abrigo_faixa", (-4.0, 0.95, 2.04), (2.46, 2.16, 0.1), faixa, i())
    c.cilindro("abrigo_respiro", (-4.4, 1.5, 2.3), 0.12, 0.5, escuro, i(), segs=12)
    c.cilindro("abrigo_respiro2", (-3.7, 0.4, 2.2), 0.09, 0.3, escuro, i(), segs=12)

    # teto: vigas, radiadores, antena de alto ganho, farol
    for y in (-0.7, 0.5, 1.7):
        c.caixa(f"viga_{y}", (0, y, H + 0.13), (2 * Wd, 0.12, 0.1), nerv, i())
    for k, x in enumerate((-1.4, 1.4)):
        c.caixa(f"radiador_{k}", (x, 0.5, H + 0.42), (1.8, 1.9, 0.05), casco, i(), rot=(0, 0, 0))
        for dx in (-0.6, 0.6):
            barra(f"radiador_pe_{k}_{dx}", (x + dx, 0.5, H + 0.08), (x + dx, 0.5, H + 0.4), 0.07, nerv, i())
    tubo("antena_mastro", (0.0, 1.6, H + 0.1), (0.0, 1.6, H + 1.35), 0.05, nerv, i())
    tronco("antena_prato", (0.0, 1.45, H + 1.45), 0.75, 0.08, 0.28, casco, i(), rot=(-62, 0, 0), segs=24)
    tubo("antena_haste", (0.0, 1.6, H + 1.3), (0.0, 1.32, H + 1.7), 0.025, escuro, i(), segs=6)
    tubo("farol_mastro", (2.4, 2.1, H + 0.1), (2.4, 2.1, H + 0.75), 0.04, nerv, i(), segs=8)
    c.cilindro("farol", (2.4, 2.1, H + 0.82), 0.09, 0.14, farol, i(), segs=12)

    # cápsulas das câmeras externas, nas paredes: ficam nos pontos de onde as câmeras renderizam
    for nome, (loc, alvo, _) in CAMERAS.items():
        if nome == "visao_geral":
            continue
        loc = Vector(loc)
        d = (Vector(alvo) - loc).normalized()
        if nome in POSTES:                              # câmera num poste, longe da parede
            tubo(f"capsula_{nome}_poste", (loc.x, loc.y, -0.8), (loc.x, loc.y, loc.z - 0.14), 0.06, nerv, i(), segs=8)
        else:
            parede = Vector((min(max(loc.x, -Wd), Wd), min(max(loc.y, y0), y1), loc.z))
            c.caixa(f"capsula_{nome}_suporte", (parede + loc) / 2 - d * 0.04, (0.14, 0.14, 0.14), nerv, i())
        ob = c.caixa(f"capsula_{nome}", loc - d * 0.12, (0.3, 0.26, 0.26), escuro, i())
        alinhar(ob, d, "Y", "Z")
        ob = c.cilindro(f"capsula_{nome}_lente", loc - d * 0.02, 0.07, 0.06, vidro, i(), segs=12)
        alinhar(ob, d, "Z", "Y")


def moxie():
    ouro = mat("moxie_corpo", "e8c170")
    azul = mat("moxie_faixa", "4f8fba")
    escuro = mat("moxie_grade", "202e37")
    cinza = mat("moxie_base", "577277")
    tanque = mat("tanque", "ebede9")
    tubo_m = mat("moxie_tubo", "a8b5b2")
    i = idx
    cx, cy = 1.7, -2.05
    c.caixa("moxie_plataforma", (cx, cy, 0.08), (1.9, 1.3, 0.16), cinza, i())
    c.caixa("moxie_corpo", (cx, cy, 0.78), (1.5, 0.95, 1.2), ouro, i())
    # as faces voltadas para a câmera (oeste e norte) levam a faixa de O2 e a grade de entrada
    c.caixa("moxie_faixa_oeste", (cx - 0.76, cy, 0.9), (0.04, 0.97, 0.2), azul, i())
    c.caixa("moxie_faixa_norte", (cx, cy + 0.49, 0.9), (1.52, 0.04, 0.2), azul, i())
    c.caixa("moxie_grade", (cx - 0.76, cy + 0.1, 0.45), (0.04, 0.5, 0.3), escuro, i())
    c.caixa("moxie_faixa_sul", (cx, cy - 0.49, 0.9), (1.52, 0.04, 0.2), azul, i())
    c.caixa("moxie_grade_sul", (cx + 0.3, cy - 0.49, 0.45), (0.5, 0.04, 0.3), escuro, i())
    for k in range(5):                                     # aletas de calor no topo
        c.caixa(f"moxie_aleta_{k}", (cx - 0.55 + k * 0.28, cy, 1.45), (0.07, 0.8, 0.16), cinza, i())
    c.caixa("moxie_tampa", (cx + 0.55, cy, 1.38), (0.38, 0.55, 0.05), cinza, i())
    # tubos: entrada de CO2 (sai do chão), saída de O2 para a parede e para os tanques
    tubo("moxie_tubo_o2_a", (cx + 0.4, cy + 0.45, 0.95), (cx + 0.4, y_parede_sul(), 0.95), 0.06, tubo_m, i())
    tubo("moxie_tubo_o2_b", (cx - 0.1, cy + 0.45, 0.6), (cx - 0.1, y_parede_sul(), 0.6), 0.06, tubo_m, i())
    tubo("moxie_exaustao", (cx - 0.65, cy - 0.2, 1.5), (cx - 0.65, cy - 0.2, 2.1), 0.07, tubo_m, i())
    tubo("moxie_tubo_tanque", (cx + 0.75, cy, 0.5), (3.2, cy, 0.5), 0.05, tubo_m, i())
    for k, y in enumerate((-1.9, -2.75)):
        t = tubo(f"tanque_{k}", (3.0, y, 0.5), (5.2, y, 0.5), 0.42, tanque, i(), segs=24)
        c.caixa(f"tanque_faixa_{k}", (4.1, y, 0.5), (0.2, 0.92, 0.92), azul, i())
    c.caixa("tanque_suporte", (3.6, -2.3, 0.1), (0.2, 1.9, 0.2), cinza, i())
    c.caixa("tanque_suporte2", (4.7, -2.3, 0.1), (0.2, 1.9, 0.2), cinza, i())


def y_parede_sul():
    return -1.4


def campo_de_paineis():
    quadro = mat("painel_quadro", "a8b5b2")
    pe = mat("painel_pe", "577277")
    rng = random.Random(3)
    th = math.radians(INCLINACAO_PAINEL)
    for fila in range(3):
        yc = 5.4 + 3.0 * fila
        for k in range(5):
            xc = 11.0 + 3.1 * k
            # o painel 0 da fila 1 é o que a escova está limpando: limpo à esquerda dela
            limpo = (ROVER.x + 0.15 - (xc - LARGURA_PAINEL / 2)) / LARGURA_PAINEL if (fila, k) == (0, 0) else None
            suj = 0.82 if (fila, k) == (0, 0) else rng.uniform(0.45, 0.72)
            m = material_painel(f"painel_{fila}_{k}", suj,
                                (rng.uniform(0, 50), rng.uniform(0, 50), rng.uniform(0, 50)), limpo)
            c.caixa(f"painel_{fila}_{k}_quadro", (xc, yc, 0.9), (LARGURA_PAINEL + 0.08, PROFUNDIDADE_PAINEL + 0.08, 0.05),
                    quadro, idx(), rot=(INCLINACAO_PAINEL, 0, 0))
            normal = Vector((0, -math.sin(th), math.cos(th)))
            c.caixa(f"painel_{fila}_{k}", Vector((xc, yc, 0.9)) + normal * 0.012,
                    (LARGURA_PAINEL, PROFUNDIDADE_PAINEL, 0.05), m, idx(), rot=(INCLINACAO_PAINEL, 0, 0))
            for dx in (-1.2, 1.2):
                for t in (-0.72, 0.72):
                    y = yc + t * math.cos(th)
                    z = 0.9 + t * math.sin(th) - 0.03
                    barra(f"painel_{fila}_{k}_pe_{dx}_{t}", (xc + dx, y, 0), (xc + dx, y, z), 0.07, pe, idx("pes"))


def rover_e_rocha():
    corpo = mat("rover_corpo", "a8b5b2")
    deck = mat("rover_deck", "577277")
    roda = mat("rover_roda", "202e37")
    cubo = mat("rover_cubo", "819796")
    rtg = mat("rover_rtg", "394a50")
    braco_m = mat("rover_braco", "c7cfcc")
    junta = mat("rover_junta", "394a50")
    escova = mat("rover_escova", "151d28")
    pa = mat("rover_pa", "819796")
    laser = mat("laser", "a4dddb", 0.5)
    P = ROVER
    i = idx

    def L(x, y, z):
        return Vector((P.x + x, P.y + y, P.z + z))

    c.caixa("rover_chassi", L(0, 0, 0.88), (1.2, 2.0, 0.5), corpo, i())
    c.caixa("rover_deck", L(0, -0.1, 1.17), (1.1, 1.6, 0.08), deck, i())
    c.caixa("rover_eletronica", L(0.3, -0.25, 1.35), (0.5, 0.7, 0.3), cubo, i())
    for sx in (-1, 1):
        barra(f"rover_trilho_{sx}", L(sx * 0.98, -0.85, 0.5), L(sx * 0.98, 0.85, 0.5), 0.07, deck, i())
        for yy in (-0.85, 0.0, 0.85):
            c.cilindro(f"rover_roda_{sx}_{yy}", L(sx * 1.0, yy, 0.32), 0.32, 0.3, roda, i("rodas"),
                       rot=(0, 90, 0), segs=16)
            c.cilindro(f"rover_cubo_{sx}_{yy}", L(sx * 1.0, yy, 0.32), 0.12, 0.34, cubo, i("rodas"),
                       rot=(0, 90, 0), segs=12)
            barra(f"rover_escora_{sx}_{yy}", L(sx * 0.62, yy, 0.9), L(sx * 0.98, yy, 0.45), 0.08, deck, i())
    tubo("rover_rtg", L(0, -1.4, 1.0), L(0, -0.8, 1.0), 0.17, rtg, i(), segs=12)
    for k in range(4):
        c.caixa(f"rover_rtg_aleta_{k}", L(0, -1.35 + k * 0.17, 1.0), (0.5, 0.03, 0.36), rtg, i())
    c.caixa("rover_antena_apoio", L(0.55, -0.7, 1.28), (0.05, 0.05, 0.22), deck, i())
    tronco("rover_antena", L(0.55, -0.7, 1.45), 0.22, 0.22, 0.03, braco_m, i(), rot=(-35, 0, 20), segs=6)

    # mastro com o ChemCam, virado para a rocha
    mastro = L(-0.45, 0.35, 2.0)
    barra("rover_mastro", L(-0.45, 0.35, 1.2), L(-0.45, 0.35, 1.95), 0.07, braco_m, i())
    alvo_h = Vector((ROCHA.x - mastro.x, ROCHA.y - mastro.y, 0.0)).normalized()
    cab = c.caixa("rover_cabeca", mastro, (0.3, 0.22, 0.24), braco_m, i())
    alinhar(cab, alvo_h, "Y", "Z")
    c.caixa("rover_cabeca_olho_a", mastro + alvo_h * 0.12 + Vector((0, 0, 0.14)), (0.08, 0.08, 0.08), escuro_rover(), i())
    lente = tubo("rover_chemcam", mastro + alvo_h * 0.1, mastro + alvo_h * 0.28, 0.05, escuro_rover(), i(), segs=10)

    # braço com a escova (e a pá, recolhida) sobre o painel
    th = math.radians(INCLINACAO_PAINEL)
    tip = Vector((ROVER.x + 0.15, 4.95, 0.9 + (4.95 - 5.4) * math.tan(th) + 0.06))
    base = L(0.15, 1.05, 0.95)
    c.caixa("rover_torre", L(0.15, 0.95, 0.95), (0.4, 0.3, 0.35), junta, i())
    punho = tip + Vector((0, -0.3, 0.42))
    braco("rover_braco", base, punho, 0.85, 0.85, braco_m, junta)
    barra("rover_cabo_escova", punho, tip + Vector((0, 0, 0.05)), 0.06, junta, i())
    normal = Vector((0, -math.sin(th), math.cos(th)))
    c.caixa("rover_escova", tip + normal * 0.0, (0.6, 0.16, 0.07), escova, i(), rot=(INCLINACAO_PAINEL, 0, 0))
    c.caixa("rover_pa", punho + Vector((0.2, 0.0, 0.1)), (0.3, 0.26, 0.04), pa, i(), rot=(-40, 0, 0))

    # rocha alvo do ChemCam
    m = mat("rocha_alvo", "4d2b32", 1.0)
    rocha = pedra("rocha_alvo", ROCHA + Vector((0, 0, 0.45)), (0.9, 0.7, 0.75), m, i(), 3, sub=3,
                  rugosidade=0.22, yaw=math.radians(20))
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    centro = ROCHA + Vector((0, 0, 0.5))
    d0 = (centro - mastro).normalized()
    lado = d0.cross(Vector((0, 0, 1))).normalized()
    pontos = []
    for dy, dz in ((-0.16, 0.1), (0.0, 0.14), (0.16, 0.1), (-0.08, -0.06), (0.08, -0.06)):
        o = mastro + alvo_h * 0.32                      # depois da cabeça e da lente
        d = (centro + lado * dy + Vector((0, 0, dz)) - o).normalized()
        hit, loc, nor, _, ob, _ = bpy.context.scene.ray_cast(dg, o, d)
        if hit and ob.name == rocha.name:
            pontos.append((loc, nor))
    pit = mat("rocha_pontos", "151d28")
    for k, (loc, nor) in enumerate(pontos):
        ob = c.cilindro(f"rocha_ponto_{k}", loc + nor * 0.004, 0.045, 0.02, pit, i("pontos"), segs=10)
        alinhar(ob, nor, "Z", "Y")
    print(f"[exterior] pontos de laser na rocha: {len(pontos)}")
    if pontos:
        alvo = pontos[1 if len(pontos) > 1 else 0][0]
        barra("laser_chemcam", mastro + alvo_h * 0.3, alvo, 0.03, laser, i())


def escuro_rover():
    return c.MATS.get("rover_escuro") or mat("rover_escuro", "151d28")


def area_de_amostra():
    laje = mat("amostra_laje", "d7b594", 1.0)
    furo = mat("amostra_furo", "10141f")
    po = mat("amostra_po", "e7d5b3", 1.0)
    braco_m = mat("amostra_braco", "c7cfcc")
    junta = mat("amostra_junta", "394a50")
    brocas = mat("amostra_broca", "819796")
    mesa = mat("amostra_mesa", "577277")
    bandeja = mat("amostra_bandeja", "202e37")
    tubo_m = mat("amostra_tubo", "c7cfcc")
    selo = mat("amostra_selo", "cf573c")
    vazio = mat("amostra_vazio", "73bed3")
    i = idx
    A = AMOSTRA
    tronco("amostra_laje", (A.x, A.y, 0.07), 1.9, 1.75, 0.16, laje, i(), segs=7)
    tronco("amostra_po", (A.x + 0.02, A.y, 0.17), 0.34, 0.14, 0.06, po, i(), segs=14)
    c.cilindro("amostra_furo", (A.x, A.y, 0.205), 0.1, 0.02, furo, i(), segs=14)
    # braço de campo, num pedestal, com a broca sobre o furo
    ped = Vector((A.x - 1.7, A.y - 1.7, 0))
    tubo("amostra_pedestal", ped, ped + Vector((0, 0, 0.9)), 0.22, junta, i(), segs=16)
    punho = Vector((A.x, A.y, 0.95))
    braco("amostra_braco", ped + Vector((0, 0, 0.95)), punho, 1.4, 1.4, braco_m, junta, esp=0.11)
    tubo("amostra_broca", punho, Vector((A.x, A.y, 0.24)), 0.045, brocas, i(), segs=8)
    tubo("amostra_mandril", punho + Vector((0, 0, 0.05)), punho - Vector((0, 0, 0.25)), 0.11, junta, i(), segs=12)
    # porta-tubos numa mesa baixa
    M = Vector((A.x + 2.3, A.y - 1.0, 0))
    c.caixa("amostra_mesa", M + Vector((0, 0, 0.62)), (1.3, 0.55, 0.05), mesa, i())
    for dx in (-0.58, 0.58):
        for dy in (-0.22, 0.22):
            barra(f"amostra_mesa_pe_{dx}_{dy}", M + Vector((dx, dy, 0)), M + Vector((dx, dy, 0.6)), 0.05, mesa, i("pes"))
    c.caixa("amostra_bandeja", M + Vector((0, 0, 0.68)), (1.2, 0.45, 0.06), bandeja, i())
    for r in range(2):
        for q in range(5):
            p = M + Vector((-0.45 + q * 0.225, -0.1 + r * 0.2, 0.0))
            tubo(f"amostra_tubo_{r}_{q}", p + Vector((0, 0, 0.7)), p + Vector((0, 0, 0.98)), 0.036, tubo_m, i("tubos"), segs=10)
            cheio = (r * 5 + q) < 4
            c.cilindro(f"amostra_selo_{r}_{q}", p + Vector((0, 0, 1.0)), 0.04, 0.04, selo if cheio else vazio,
                       i("selos" if cheio else "selos_v"), segs=10)
    # cabo do pedestal até a parede norte do habitat
    c.caixa("amostra_cabo", (ped.x, (ped.y + 2.4) / 2, 0.04), (0.12, ped.y - 2.4, 0.08), junta, i("cabos"))


def pedras_soltas():
    rng = random.Random(7)
    claras = [mat(f"pedra_{k}", h, 1.0) for k, h in enumerate(("4d2b32", "7a4841", "577277", "884b2b"))]
    proibido = [(-6.5, 6.5, -4.8, 3.2), (5.0, 12.5, 0.0, 4.5), (8.0, 27.5, 3.5, 13.8),
                (-3.6, 4.9, 4.0, 11.0), (0.5, 6.0, -4.5, -0.5), (6.0, 9.0, 1.8, 4.2), (12.5, 14.5, -4.5, -2.5), (-3.0, -1.0, -7.8, -5.8)]

    def livre(x, y, r):
        return not any(x0 - r < x < x1 + r and y0 - r < y < y1 + r for x0, x1, y0, y1 in proibido)

    feitas, k = 0, 0
    while feitas < 210 and k < 5000:
        k += 1
        alcance = 60 if feitas < 150 else 250
        x, y = rng.uniform(-alcance, alcance), rng.uniform(-alcance, alcance)
        t = rng.random()
        r = 0.05 + 0.1 * t if feitas < 110 else (0.15 + 0.35 * t if feitas < 170 else 0.5 + 1.4 * t)
        if not livre(x, y, r + 0.3):
            continue
        z = float(altura(np.array([x]), np.array([y]))[0]) + 0.25 * r
        pedra(f"pedra_solta_{feitas}", (x, y, z), (r * rng.uniform(0.8, 1.4), r * rng.uniform(0.8, 1.3), r * rng.uniform(0.6, 1.0)),
              rng.choice(claras), idx("pedras"), rng.uniform(0, 50), sub=1 if r < 0.2 else 2,
              yaw=rng.uniform(0, 6.28))
        feitas += 1


def cabos():
    m = mat("cabo", "202e37")
    barra("cabo_painel_a", (2.8, 0.0, 0.07), (9.0, 0.0, 0.07), 0.12, m, idx("cabos"))
    barra("cabo_painel_b", (9.0, 0.0, 0.07), (9.0, 5.0, 0.07), 0.12, m, idx("cabos"))
    c.caixa("cabo_caixa", (9.0, 5.4, 0.25), (0.5, 0.5, 0.5), mat("cabo_caixa", "577277"), idx())
    barra("cabo_painel_c", (9.0, 5.0, 0.07), (9.0, 5.2, 0.07), 0.12, m, idx("cabos"))


def luzes_e_mundo():
    s = bpy.context.scene
    sol = bpy.data.lights.new("luz_sol", "SUN")
    sol.angle = math.radians(0.6)
    ob = bpy.data.objects.new("luz_sol", sol)
    ob.location = (0, 0, 30)
    s.collection.objects.link(ob)
    d = Vector((0.4, 0.55, -0.72)).normalized()
    alinhar(ob, d, "-Z", "Y")

    w = bpy.data.worlds.new("marte")
    s.world = w
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    saida = nt.nodes.new("ShaderNodeOutputWorld")
    visto = nt.nodes.new("ShaderNodeBackground")      # o que a câmera enxerga: força 1
    fundo = nt.nodes.new("ShaderNodeBackground")      # o que ilumina a cena: força do estado
    luz = nt.nodes.new("ShaderNodeLightPath")
    mistura = nt.nodes.new("ShaderNodeMixShader")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    rampa = nt.nodes.new("ShaderNodeValToRGB")
    rampa.color_ramp.elements[1].position = 1.0
    rampa.color_ramp.elements.new(0.3)
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], rampa.inputs["Fac"])
    nt.links.new(rampa.outputs["Color"], visto.inputs["Color"])
    nt.links.new(rampa.outputs["Color"], fundo.inputs["Color"])
    nt.links.new(luz.outputs["Is Camera Ray"], mistura.inputs["Fac"])
    nt.links.new(fundo.outputs[0], mistura.inputs[1])
    nt.links.new(visto.outputs[0], mistura.inputs[2])
    nt.links.new(mistura.outputs[0], saida.inputs[0])
    return types.SimpleNamespace(sol=sol, rampa=rampa, fundo=fundo)


# ---------------------------------------------------------------- estados

# sol: (cor, energia); ceu: (horizonte, meio, zênite); mundo: força do céu como luz ambiente
# (a câmera sempre vê o céu com força 1);
# neblina: densidade por metro; traco: brilho do contorno (menor = mais contraste)
E = {
    "normal": dict(sol=("e7d5b3", 3.6), ceu=("e8c170", "de9e41", "be772b"), mundo=0.8,
                   neblina=6e-5, traco=0.25, janela=0.15, farol=3.0, laser=6.0),
    "poeira": dict(sol=("de9e41", 2.0), ceu=("be772b", "be772b", "884b2b"), mundo=1.0,
                   neblina=3e-2, traco=0.55, janela=1.2, farol=9.0, laser=3.0),
}


def aplicar_estado(estado, mundo):
    """Só luz, céu, emissão e a névoa do pós-processo. Nada de geometria nem de câmera."""
    e = E[estado]
    mundo.sol.color = hexrgb(e["sol"][0])
    mundo.sol.energy = e["sol"][1]
    for el, h in zip(mundo.rampa.color_ramp.elements, e["ceu"]):
        el.color = (*hexrgb(h), 1)
    mundo.fundo.inputs["Strength"].default_value = e["mundo"]
    c.emissao(c.MATS["vidro"], hexrgb("e8c170"), e["janela"])
    c.emissao(c.MATS["farol"], hexrgb("cf573c"), e["farol"])
    c.emissao(c.MATS["laser"], hexrgb("a4dddb"), e["laser"])
    return e


def cor_neblina(e):
    return np.array(hexrgb(e["ceu"][0]))


def neblina(p, e):
    """Névoa por profundidade, aplicada ao render linear. Devolve (cor, transmitância)."""
    z = p["z"]
    t = np.where(z > 1e8, 1.0, np.exp(-e["neblina"] * np.minimum(z, 1e8)))
    cor = p["cor"] * t[..., None] + cor_neblina(e) * (1 - t[..., None])
    return cor, t


def pixel_art(cor, t, p, e):
    # céu (profundidade infinita, normal zero) não ganha traço, nem o que a névoa engoliu
    borda = c.contorno(p) & (t > 0.5) & (p["z"] < 1e8)
    q = c.quantizar(cor, False)
    escura = c.quantizar(c.PALETA_LAB_LIN[q] * e["traco"], False)
    q = np.where(borda, escura, q)
    return c.PALETA_SRGB[q]


# ---------------------------------------------------------------- câmeras e render

def criar_cameras(a):
    s = bpy.context.scene
    cams = {}
    for nome, (loc, alvo, fov) in CAMERAS.items():
        cd = bpy.data.cameras.new(f"camera_{nome}")
        cd.sensor_fit = "VERTICAL"
        cd.angle_y = math.radians(fov)
        cd.clip_start = 0.05
        cd.clip_end = 50000.0
        ob = bpy.data.objects.new(f"camera_{nome}", cd)
        ob.location = loc
        alinhar(ob, Vector(alvo) - Vector(loc), "-Z", "Y")
        s.collection.objects.link(ob)
        cams[nome] = ob
    return cams


def main():
    a = args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mundo = construir()
    c.configurar(types.SimpleNamespace(amostras=a.amostras, largura=a.largura, altura=a.altura,
                                       camera="perspectiva", yaw=0.0, graus=180.0, rad_por_px=None))
    s = bpy.context.scene
    bpy.data.objects.remove(bpy.data.objects["camera"])         # a câmera genérica do comodo
    cams = criar_cameras(a)
    estados = [x for x in a.estados.split(",") if x]
    escolhidas = [x for x in a.cameras.split(",") if x]
    CACHE.mkdir(parents=True, exist_ok=True)
    (CACHE / ".gdignore").touch()
    saida = RAIZ / a.saida

    if a.salvar_blend:
        aplicar_estado("normal", mundo)
        s.camera = cams["visao_geral"]
        for k, v in E["poeira"].items():
            s[f"poeira_{k}"] = str(v)
        s["neblina_pos_processo"] = "a névoa do estado poeira é aplicada pelo script, sobre o passe de profundidade"
        destino = CACHE / "exterior.blend"
        bpy.ops.wm.save_as_mainfile(filepath=str(destino))
        print(f"[exterior] blend: {destino}")
    if a.sem_render:
        return

    for nome in escolhidas:
        s.camera = cams[nome]
        passes = {}
        for estado in estados:
            e = aplicar_estado(estado, mundo)
            exr = CACHE / f"exterior_{nome}_{estado}.exr"
            s.render.filepath = str(exr)
            bpy.ops.render.render(write_still=True)
            p = c.ler_exr(exr)
            passes[estado] = p
            cor, t = neblina(p, e)
            destino = saida / f"{nome}_{estado}.png"
            c.salvar_png(destino, pixel_art(cor, t, p, e))
            print(f"[exterior] {nome} {estado}: {destino}")
        base = estados[0]
        for est in estados[1:]:
            dz = np.abs(passes[est]["z"] - passes[base]["z"]).max()
            dn = np.abs(passes[est]["normal"] - passes[base]["normal"]).max()
            di = int((passes[est]["indice"] != passes[base]["indice"]).sum())
            db = int((c.contorno(passes[est]) != c.contorno(passes[base])).sum())
            print(f"[exterior] {nome} {base} x {est}: max|Δz|={dz:.2e} max|Δnormal|={dn:.2e} "
                  f"px índice diferente={di} px contorno diferente={db}")


if __name__ == "__main__":
    main()
