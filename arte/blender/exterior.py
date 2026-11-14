"""Gera o exterior da base (sopé do Monte Sharp, cratera Gale, Marte) do zero e renderiza um PNG
em pixel art por câmera externa e por estado. Gray-box: geometria simples e legível, para o time
preencher depois; não é arte final.

Uso (da raiz do repo, caminho absoluto no script porque o Blender é o Flatpak):
    blender -b --factory-startup -P $PWD/arte/blender/exterior.py
    blender -b --factory-startup -P $PWD/arte/blender/exterior.py -- \
        --estados normal --cameras painel,rocha
    blender -b --factory-startup -P $PWD/arte/blender/exterior.py -- --salvar-blend --sem-render

Fonte da verdade: este script. O .blend de --salvar-blend (arte/blender/.render/exterior.blend,
pasta ignorada no git) é só para abrir e mexer; nada o lê de volta.
Os helpers (materiais, caixa, cilindro, EXR, contorno, paleta) vêm do comodo.py.

Além das câmeras externas, gera a vista da janela do cômodo: assets/exterior/vista_janela_<estado>.png,
1280x360, com a MESMA câmera cilíndrica do comodo.py (mesmo olho, yaw, 180 graus e escala angular,
valores importados de lá). O casco do habitat e tudo o que fica entre o olho e a janela saem do render
(visível para a câmera = não, mas ainda projetam sombra), porque o interior é o comodo.py. O Godot põe
a vista atrás do panorama da sala, cujo vidro da janela tem alpha 0. `--so-vista` renderiza só ela;
`compor_janela` grava a sobreposição da sala com a vista em arte/blender/.render/janela_composicao.png
e imprime a composição do vidro (chão e encosta, montanha, céu).

Lugar: a base fica no sopé do Monte Sharp, dentro de Gale, e a janela da sala (a câmera do
comodo.py olha para +y, yaw 0) fica de frente para a montanha, olhando morro acima. O chão sobe
para +y (rampa do sopé, com buttes e mesas em degraus), e o Monte Sharp é um maciço em estratos
que preenche a parte de cima da janela. Na frente da janela ficam o campo de painéis, o rover
com o braço na escova e a rocha do ChemCam; a área de amostra fica no morro acima do campo, e o
MOXIE com os tanques ao leste do habitat.

Mesma geometria e mesma câmera em todos os estados; o estado muda só luz, céu e névoa.
A névoa é aplicada depois do render, pelo passe de profundidade (o Cycles não a desenha).

Referencial: +x leste, +y para o Monte Sharp, +z para cima. Unidades em metros. O Sol vem do sul
(de trás da janela), então a encosta da montanha pega luz de frente.

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
DIST_MONTE = 1000.0              # profundidade a partir da qual o terreno conta como montanha

# nome: (posição do olho, alvo, campo vertical em graus). As câmeras de poste saem das cápsulas
# do habitat (as telas do interior); a visão geral está só no ar. A do painel olha de cima, de um
# mastro a noroeste do habitat, para a escova no painel sujo (ver CAPSULAS).
CAMERAS = {
    "painel": ((-9.0, 9.0, 4.8), (-2.6, 15.0, 1.7), 27.0),
    "rocha": ((0.2, 7.6, 2.4), (-0.3, 13.0, 1.3), 38.0),
    "amostra": ((-2.5, 29.0, 4.4), (-3.0, 36.0, 3.2), 38.0),
    "moxie": ((4.2, -5.6, 2.3), (9.5, -2.2, 1.0), 31.0),
    "visao_geral": ((-13.0, -10.5, 6.2), (1.0, 12.0, 4.2), 54.0),
}

HABITAT = []                     # objetos do casco, escondidos da câmera na vista da janela
POSTES = {"painel", "rocha", "amostra", "moxie"}   # câmeras que ficam num poste, não na parede
CAPSULAS = {}
LARGURA_PAINEL, PROFUNDIDADE_PAINEL, INCLINACAO_PAINEL = 3.0, 1.7, 30.0

# Layout visto da janela (olho em 0,0,1.2, vidro de ±28,6 graus): quem está na frente tem de
# caber em |x| < 0,54 y.
COLUNAS = [-9.3, -6.2, -3.1, 0.0, 3.1, 6.2, 9.3]              # centro x de cada coluna de painéis
LINHAS = [15.5, 18.5, 21.5, 24.5]                  # centro y de cada fila
PAINEL_LIMPO = (0, 2)                              # (fila, coluna) onde a escova trabalha
ROVER = Vector((COLUNAS[2] + 0.6, LINHAS[0] - 0.45 - 2.75, 0.0))
ROCHA = Vector((ROVER.x + 4.6, ROVER.y + 0.9, 0.0))
AMOSTRA = Vector((-3.5, 36.0, 0.0))
MOXIE_O = Vector((8.7, -2.05, 0.0))                # centro do corpo do MOXIE


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser(prog="exterior.py")
    p.add_argument("--estados", default=",".join(ESTADOS), help="lista separada por vírgula")
    p.add_argument("--cameras", default=",".join(CAMERAS), help="lista separada por vírgula")
    p.add_argument("--largura", type=int, default=640)
    p.add_argument("--altura", type=int, default=360)
    p.add_argument("--saida", default="assets/exterior")
    p.add_argument("--amostras", type=int, default=64)
    p.add_argument("--sem-vista", action="store_true", help="não renderiza a vista da janela")
    p.add_argument("--so-vista", action="store_true", help="renderiza só a vista da janela")
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

# Rampa do sopé: (y, z). Plana na base (a bancada do habitat), sobe cerca de 10 % no começo e
# depois mais devagar, até o pé do maciço do Monte Sharp, que entra por cima dela.
RAMPA = ([-1e5, 3.0, 60.0, 150.0, 300.0, 600.0, 1000.0, 1e5],
         [0.0, 0.0, 5.7, 13.0, 26.0, 52.0, 84.0, 84.0])
BASE_MONTE = RAMPA[1][-1]


def nivel(y):
    return np.interp(y, *RAMPA)


# Maciço do Monte Sharp: domo elíptico em degraus (estratos). O Curiosity sobe por ele desde 2014.
MONTE = dict(cx=-1000.0, cy=3100.0, ax=4400.0, ay=2200.0, h=700.0, n=6)
PERIODO_ESTRATO = 0.8 * MONTE["h"] / MONTE["n"]       # altura de um degrau, que a cor segue

# Buttes e mesas do sopé: (x, y, semi-eixo x, semi-eixo y, altura, degraus). Elípticos, com
# degraus e topo plano; os alongados fazem de afloramento em camadas.
BUTTES = [
    (-26.0, 62.0, 16.0, 6.0, 2.4, 2), (31.0, 88.0, 14.0, 9.0, 3.0, 2),
    (-58.0, 118.0, 30.0, 12.0, 5.5, 3), (14.0, 165.0, 24.0, 18.0, 7.0, 3),
    (84.0, 205.0, 40.0, 16.0, 9.0, 3), (-110.0, 240.0, 46.0, 20.0, 10.0, 3),
    (-8.0, 310.0, 70.0, 28.0, 14.0, 4), (150.0, 360.0, 60.0, 38.0, 18.0, 4),
    (-190.0, 420.0, 80.0, 32.0, 16.0, 4), (60.0, 520.0, 110.0, 44.0, 22.0, 5),
    (-120.0, 640.0, 120.0, 50.0, 28.0, 5), (230.0, 700.0, 90.0, 60.0, 26.0, 5),
    (-20.0, 790.0, 150.0, 60.0, 30.0, 5), (-300.0, 880.0, 110.0, 70.0, 34.0, 5),
]

# Pés chatos do chão aterrado: (x0, x1, y0, y1, borda). O campo, o rover e a bancada do
# habitat não têm as ondas pequenas.
PLANOS = [(-6.5, 6.0, -4.8, 3.2, 3.5), (-12.5, 12.5, 13.0, 27.0, 2.5), (-8.5, 1.5, 31.5, 41.5, 3.0),
          (6.5, 12.0, -5.0, 2.0, 3.0)]
# Pátios nivelados na altura da rampa no centro deles: (cx, cy, meia-largura x, meia y, borda).
PATIOS = [(ROVER.x, ROVER.y, 2.6, 2.8, 3.0), (ROCHA.x, ROCHA.y, 1.6, 1.4, 2.5),
          (AMOSTRA.x + 1.0, AMOSTRA.y - 0.5, 4.4, 3.2, 2.5)]


def _suave(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3 - 2 * t)


def _sdf_retangulo(x, y, x0, x1, y0, y1):
    return np.hypot(np.maximum(np.maximum(x0 - x, x - x1), 0), np.maximum(np.maximum(y0 - y, y - y1), 0))


def _plano(x, y, alargar=1.0):
    """1 onde o chão é aterrado e plano (base, campo de painéis, área de amostra). alargar
    multiplica a borda: as ondas grandes (metros de altura) saem do campo devagar, sem degrau."""
    m = np.zeros_like(x)
    for x0, x1, y0, y1, borda in PLANOS:
        m = np.maximum(m, 1 - _suave(_sdf_retangulo(x, y, x0, x1, y0, y1) / (borda * alargar)))
    return m


def _degraus(t, n, bancada=0.52, riser=0.30):
    """t em 0..1 vira 0..1 em n degraus: bancadas quase planas e paredes entre elas."""
    w = np.clip(t, 0.0, 1.0) * n
    k = np.floor(w)
    return np.minimum(k + _suave((w - k - bancada) / riser), n) / n


def _relevo_grande(x, y):
    """Rampa, buttes e maciço: tudo o que é maior que a grade fina."""
    z = nivel(y) * (1 - 0.75 * _suave((np.abs(x) - 1500.0) / 3500.0))
    for bx, by, ax, ay, hh, n in BUTTES:
        d = np.hypot((x - bx) / ax, (y - by) / ay)
        d = d * (1 + 0.16 * np.sin((x - bx) * 0.11 + (y - by) * 0.07 + bx))
        t = (1 - d) * 1.35
        z = z + hh * (0.15 * np.clip(t, 0, 1) + 0.85 * _degraus(t, n))
    m = MONTE
    u = np.hypot((x - m["cx"]) / m["ax"], (y - m["cy"]) / m["ay"])
    u = u * (1 + 0.06 * np.sin(x * 0.0021 + 1.3) + 0.04 * np.sin(y * 0.0033 + 0.4)
             + 0.025 * np.sin((x + y) * 0.0075 + 2.0))
    t = np.clip(1 - u ** 1.7, 0, 1) ** 1.1
    z = z + m["h"] * (0.2 * t + 0.8 * _degraus(t, m["n"]))
    return z


def altura(x, y, celula=None):
    """Relevo do chão. celula: tamanho da célula da malha em cada ponto (m); as ondas menores
    que ~6 células somem, para a malha não amostrar o que não representa. As pequenas também
    somem a 80 m do centro, onde o chão vira cor chapada."""
    x = np.asarray(x, float)
    y = np.asarray(y, float)
    r = np.maximum(np.abs(x), np.abs(y))
    z = _relevo_grande(x, y)
    h = np.zeros_like(x)
    plano_pequeno, plano_grande = _plano(x, y), _plano(x, y, 14.0)
    for comp, amp, cx, sy, fase in ONDAS:
        f = (1 - (plano_grande if comp >= 40 else plano_pequeno))
        if comp < 60:
            f = f * (1 - _suave((r - 50.0) / 30.0))
        if celula is not None:
            f = f * _suave((comp / np.maximum(celula, 1e-6) - 4.0) / 4.0)
        h += f * amp * np.sin((x * cx + y * sy) * 2 * math.pi / comp + fase)
    z = z + h
    for cx, cy, hx, hy, borda in PATIOS:
        m = 1 - _suave(_sdf_retangulo(x, y, cx - hx, cx + hx, cy - hy, cy + hy) / borda)
        z = z * (1 - m) + float(nivel(cy)) * m
    # a bancada do habitat é plana (z = 0)
    m = 1 - _suave(_sdf_retangulo(x, y, -6.5, 6.0, -4.8, 3.0) / 0.5)
    z = z * (1 - m)
    # monte de regolito sobre o abrigo (o anexo do lado oeste, enterrado para a radiação)
    d = _sdf_retangulo(x, y, -5.2, -2.8, -0.1, 2.0)
    z = z + 1.35 * (1 - _suave(d / 3.0)) ** 1.2
    return z


def chao(x, y):
    return float(altura(np.array([x], float), np.array([y], float))[0])


ROVER.z = float(nivel(ROVER.y))
ROCHA.z = float(nivel(ROCHA.y))
AMOSTRA.z = float(nivel(AMOSTRA.y))


def malha_polar(nome, raio_max, m, n_ang=1200):
    """O chão todo numa malha só, em anéis em volta do habitat: a célula cresce com a distância
    (0,5 m perto, 1,6 % do raio longe), sem emendas entre faixas de resolução."""
    rs = [0.4]
    while rs[-1] < raio_max:
        rs.append(rs[-1] + max(0.5, 0.016 * rs[-1]))
    rs = np.array(rs)
    th = np.linspace(0, 2 * math.pi, n_ang, endpoint=False)
    R, T = np.meshgrid(rs, th, indexing="ij")
    X, Y = R * np.sin(T), R * np.cos(T)                     # theta = 0 aponta para +y
    dr = np.gradient(rs)[:, None] * np.ones_like(R)
    celula = np.maximum(dr, 2 * math.pi * R / n_ang)
    Z = altura(X, Y, celula)
    verts = np.stack([X.ravel(), Y.ravel(), Z.ravel()], 1)
    nr = len(rs)
    i, j = np.meshgrid(np.arange(nr - 1), np.arange(n_ang), indexing="ij")
    v00 = (i * n_ang + j).ravel()
    v01 = (i * n_ang + (j + 1) % n_ang).ravel()
    v10 = ((i + 1) * n_ang + j).ravel()
    v11 = ((i + 1) * n_ang + (j + 1) % n_ang).ravel()
    faces = np.stack([v00, v10, v11, v01], 1)
    me = bpy.data.meshes.new(nome)
    me.from_pydata(verts.tolist(), [], faces.tolist())
    me.update()
    me.shade_smooth()
    print(f"[exterior] chão: {nr} anéis x {n_ang}, {len(faces)} quadros")
    return c._objeto(nome, me, m, idx("chao"))


def material_regolito(nome):
    """Chão: regolito em ruído grande perto; nas encostas íngremes e no alto, estratos em faixas
    por altura (cor por z, com ondulação), como as camadas do Monte Sharp."""
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

    # estratos: z do mundo + ondulação lenta, em faixas
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Position"], sep.inputs[0])
    ond = nt.nodes.new("ShaderNodeTexNoise")
    ond.inputs["Scale"].default_value = 0.006
    ond.inputs["Detail"].default_value = 2.0
    nt.links.new(geo.outputs["Position"], ond.inputs["Vector"])

    def faixas(periodo, fase, ondula, cores):
        a = nt.nodes.new("ShaderNodeMath")                       # (z + ondulação * período) / período
        a.operation = "MULTIPLY_ADD"
        a.inputs[1].default_value = ondula * periodo
        nt.links.new(ond.outputs["Fac"], a.inputs[0])
        a.inputs[2].default_value = 0.0
        soma = nt.nodes.new("ShaderNodeMath")
        soma.operation = "ADD"
        nt.links.new(sep.outputs["Z"], soma.inputs[0])
        nt.links.new(a.outputs["Value"], soma.inputs[1])
        div = nt.nodes.new("ShaderNodeMath")
        div.operation = "MULTIPLY_ADD"
        div.inputs[1].default_value = 1.0 / periodo
        div.inputs[2].default_value = fase
        nt.links.new(soma.outputs["Value"], div.inputs[0])
        fr = nt.nodes.new("ShaderNodeMath")
        fr.operation = "FRACT"
        nt.links.new(div.outputs["Value"], fr.inputs[0])
        rp = nt.nodes.new("ShaderNodeValToRGB")
        rp.color_ramp.interpolation = "CONSTANT"
        while len(rp.color_ramp.elements) < len(cores):
            rp.color_ramp.elements.new(0.5)
        n = len(cores)
        for k, (el, (pos, h)) in enumerate(zip(rp.color_ramp.elements, cores)):
            el.position = pos
            el.color = (*hexrgb(h), 1)
        nt.links.new(fr.outputs["Value"], rp.inputs["Fac"])
        return rp

    # camada fina (buttes, afloramentos) e camada grossa (o maciço)
    fina = faixas(1.7, 0.0, 0.8, [(0.0, "7a4841"), (0.3, "ad7757"), (0.55, "602c2c"), (0.8, "c09473")])
    grossa = faixas(PERIODO_ESTRATO, -BASE_MONTE / PERIODO_ESTRATO + 0.3, 0.5,
                    [(0.0, "ad7757"), (0.38, "7a4841"), (0.72, "c09473")])
    zalto = nt.nodes.new("ShaderNodeMapRange")                  # fina em baixo, grossa no alto
    zalto.inputs["From Min"].default_value = BASE_MONTE + 6.0
    zalto.inputs["From Max"].default_value = BASE_MONTE + 40.0
    nt.links.new(sep.outputs["Z"], zalto.inputs["Value"])
    camadas = nt.nodes.new("ShaderNodeMix")
    camadas.data_type = "RGBA"
    nt.links.new(zalto.outputs["Result"], camadas.inputs["Factor"])
    nt.links.new(fina.outputs["Color"], camadas.inputs["A"])
    nt.links.new(grossa.outputs["Color"], camadas.inputs["B"])
    # onde usar estrato: paredes (normal quase horizontal) e tudo o que está acima da rampa do sopé
    nz = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], nz.inputs[0])
    inclin = nt.nodes.new("ShaderNodeMapRange")
    inclin.inputs["From Min"].default_value = 0.985
    inclin.inputs["From Max"].default_value = 0.93
    nt.links.new(nz.outputs["Z"], inclin.inputs["Value"])
    alto = nt.nodes.new("ShaderNodeMapRange")
    alto.inputs["From Min"].default_value = 70.0
    alto.inputs["From Max"].default_value = BASE_MONTE + 4.0
    nt.links.new(sep.outputs["Z"], alto.inputs["Value"])
    uso = nt.nodes.new("ShaderNodeMath")
    uso.operation = "MAXIMUM"
    nt.links.new(inclin.outputs["Result"], uso.inputs[0])
    nt.links.new(alto.outputs["Result"], uso.inputs[1])
    final = nt.nodes.new("ShaderNodeMix")
    final.data_type = "RGBA"
    nt.links.new(uso.outputs["Value"], final.inputs["Factor"])
    nt.links.new(chapado.outputs["Result"], final.inputs["A"])
    nt.links.new(camadas.outputs["Result"], final.inputs["B"])
    nt.links.new(final.outputs["Result"], b.inputs["Base Color"])
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
    malha_polar("chao", 16000.0, regolito)
    far = bpy.data.meshes.new("chao_longe")
    far.from_pydata([(-40000, -40000, -0.6), (40000, -40000, -0.6), (40000, 40000, -0.6),
                     (-40000, 40000, -0.6)], [], [(0, 1, 2, 3)])
    c._objeto("chao_longe", far, regolito, idx("chao"))
    seguro = bpy.data.meshes.new("chao_base")          # pega raio que escape por fresta
    seguro.from_pydata([(-90, -90, -3), (90, -90, -3), (90, 90, -3), (-90, 90, -3)], [], [(0, 1, 2, 3)])
    c._objeto("chao_base", seguro, regolito, idx("chao"))

    paisagem()
    antes = set(bpy.data.objects)
    habitat()
    HABITAT[:] = [ob for ob in bpy.data.objects if ob not in antes]
    moxie()
    campo_de_paineis()
    rover_e_rocha()
    area_de_amostra()
    pedras_soltas()
    afloramentos()
    cabos()
    return luzes_e_mundo()


def paisagem():
    """A borda da cratera, bem longe, atrás do maciço do Monte Sharp (que é o próprio chão)."""
    me = bpy.data.meshes.new("borda_cratera")
    rng = random.Random(5)
    verts, faces = [], []
    n = 120
    for k in range(n + 1):
        ang = math.radians(-110 + 220 * k / n)
        h = 140 + 90 * noise.noise(Vector((k * 0.17, 3.1, 0.0))) + rng.uniform(-18, 18)
        for r, zz in ((10200, -50), (10600, h), (11200, -50)):
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
        if x != 0.0:                                    # a janela larga ocupa o centro da parede norte
            c.caixa(f"nervura_n{x}", (x, y1 + 0.04, 1.3), (0.14, 0.08, 2.3), nerv, i())
    for y in (-0.2, 1.4):
        c.caixa(f"nervura_l{y}", (Wd + 0.04, y, 1.3), (0.08, 0.14, 2.3), nerv, i())
    # calha de cabos, a 2,05 m como no interior
    c.caixa("calha_ext_sul", (0, y0 - 0.1, 2.05), (2 * Wd, 0.12, 0.12), nerv, i())
    c.caixa("calha_ext_norte", (0, y1 + 0.1, 2.05), (2 * Wd, 0.12, 0.12), nerv, i())
    # janela larga no centro da parede norte, no mesmo lugar da do interior (comodo.JANELA_*):
    # vão de 2,4 m por z 1,00..1,84, moldura de 0,10 m e um montante no meio
    jz0, jz1 = c.JANELA_Z
    jl, jc = c.JANELA_LARG, (jz0 + jz1) / 2
    c.caixa("janela_moldura_ext", (0.0, y1 + 0.04, jc), (jl + 0.2, 0.1, jz1 - jz0 + 0.2), escuro, i())
    c.caixa("janela_ext", (0.0, y1 + 0.1, jc), (jl, 0.02, jz1 - jz0), vidro, i())
    c.caixa("janela_montante_ext", (0.0, y1 + 0.115, jc), (0.1, 0.03, jz1 - jz0), escuro, i())

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
        loc, alvo = CAPSULAS.get(nome, (loc, alvo))
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
    cx, cy = MOXIE_O.x, MOXIE_O.y
    x_parede = 2.8                                          # parede leste do habitat
    c.caixa("moxie_plataforma", (cx, cy, 0.08), (1.9, 1.3, 0.16), cinza, i())
    c.caixa("moxie_corpo", (cx, cy, 0.78), (1.5, 0.95, 1.2), ouro, i())
    # as faces voltadas para a câmera (oeste e sul) levam a faixa de O2 e a grade de entrada
    c.caixa("moxie_faixa_oeste", (cx - 0.76, cy, 0.9), (0.04, 0.97, 0.2), azul, i())
    c.caixa("moxie_faixa_norte", (cx, cy + 0.49, 0.9), (1.52, 0.04, 0.2), azul, i())
    c.caixa("moxie_grade", (cx - 0.76, cy + 0.1, 0.45), (0.04, 0.5, 0.3), escuro, i())
    c.caixa("moxie_faixa_sul", (cx, cy - 0.49, 0.9), (1.52, 0.04, 0.2), azul, i())
    c.caixa("moxie_grade_sul", (cx + 0.3, cy - 0.49, 0.45), (0.5, 0.04, 0.3), escuro, i())
    for k in range(5):                                     # aletas de calor no topo
        c.caixa(f"moxie_aleta_{k}", (cx - 0.55 + k * 0.28, cy, 1.45), (0.07, 0.8, 0.16), cinza, i())
    c.caixa("moxie_tampa", (cx + 0.55, cy, 1.38), (0.38, 0.55, 0.05), cinza, i())
    # tubos: saída de O2 para a parede leste do habitat, exaustão e linha dos tanques
    tubo("moxie_tubo_o2_a", (cx - 0.76, cy + 0.25, 0.95), (x_parede, cy + 0.25, 0.95), 0.06, tubo_m, i())
    tubo("moxie_tubo_o2_b", (cx - 0.76, cy - 0.15, 0.6), (x_parede, cy - 0.15, 0.6), 0.06, tubo_m, i())
    tubo("moxie_exaustao", (cx - 0.65, cy - 0.2, 1.5), (cx - 0.65, cy - 0.2, 2.1), 0.07, tubo_m, i())
    tubo("moxie_tubo_tanque", (cx + 0.75, cy, 0.5), (cx + 1.5, cy, 0.5), 0.05, tubo_m, i())
    for k, dy in enumerate((0.15, -0.7)):
        tubo(f"tanque_{k}", (cx + 1.3, cy + dy, 0.5), (cx + 3.5, cy + dy, 0.5), 0.42, tanque, i(), segs=24)
        c.caixa(f"tanque_faixa_{k}", (cx + 2.4, cy + dy, 0.5), (0.2, 0.92, 0.92), azul, i())
    c.caixa("tanque_suporte", (cx + 1.9, cy - 0.28, 0.1), (0.2, 1.9, 0.2), cinza, i())
    c.caixa("tanque_suporte2", (cx + 3.0, cy - 0.28, 0.1), (0.2, 1.9, 0.2), cinza, i())


def campo_de_paineis():
    quadro = mat("painel_quadro", "a8b5b2")
    pe = mat("painel_pe", "577277")
    rng = random.Random(3)
    th = math.radians(INCLINACAO_PAINEL)
    for fila, yc in enumerate(LINHAS):
        for k, xc in enumerate(COLUNAS):
            zc = chao(xc, yc) + 0.9
            # o painel da escova é o limpo à esquerda dela
            limpo = (ROVER.x + 0.15 - (xc - LARGURA_PAINEL / 2)) / LARGURA_PAINEL if (fila, k) == PAINEL_LIMPO else None
            suj = 0.82 if (fila, k) == PAINEL_LIMPO else rng.uniform(0.45, 0.72)
            m = material_painel(f"painel_{fila}_{k}", suj,
                                (rng.uniform(0, 50), rng.uniform(0, 50), rng.uniform(0, 50)), limpo)
            c.caixa(f"painel_{fila}_{k}_quadro", (xc, yc, zc), (LARGURA_PAINEL + 0.08, PROFUNDIDADE_PAINEL + 0.08, 0.05),
                    quadro, idx(), rot=(INCLINACAO_PAINEL, 0, 0))
            normal = Vector((0, -math.sin(th), math.cos(th)))
            c.caixa(f"painel_{fila}_{k}", Vector((xc, yc, zc)) + normal * 0.012,
                    (LARGURA_PAINEL, PROFUNDIDADE_PAINEL, 0.05), m, idx(), rot=(INCLINACAO_PAINEL, 0, 0))
            for dx in (-1.2, 1.2):
                for t in (-0.72, 0.72):
                    y = yc + t * math.cos(th)
                    z = zc + t * math.sin(th) - 0.03
                    barra(f"painel_{fila}_{k}_pe_{dx}_{t}", (xc + dx, y, chao(xc + dx, y) - 0.05), (xc + dx, y, z), 0.07, pe, idx("pes"))


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
    mastro = L(0.45, 0.35, 2.0)
    barra("rover_mastro", L(0.45, 0.35, 1.2), L(0.45, 0.35, 1.95), 0.07, braco_m, i())
    alvo_h = Vector((ROCHA.x - mastro.x, ROCHA.y - mastro.y, 0.0)).normalized()
    cab = c.caixa("rover_cabeca", mastro, (0.3, 0.22, 0.24), braco_m, i())
    alinhar(cab, alvo_h, "Y", "Z")
    c.caixa("rover_cabeca_olho_a", mastro + alvo_h * 0.12 + Vector((0, 0, 0.14)), (0.08, 0.08, 0.08), escuro_rover(), i())
    lente = tubo("rover_chemcam", mastro + alvo_h * 0.1, mastro + alvo_h * 0.28, 0.05, escuro_rover(), i(), segs=10)

    # braço com a escova (e a pá, recolhida) sobre o painel
    th = math.radians(INCLINACAO_PAINEL)
    yp = LINHAS[PAINEL_LIMPO[0]]
    zp = chao(COLUNAS[PAINEL_LIMPO[1]], yp) + 0.9
    tip = Vector((ROVER.x + 0.15, yp - 0.45, zp + (-0.45) * math.tan(th) + 0.06))
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
    rocha = pedra("rocha_alvo", ROCHA + Vector((0, 0, 0.28)), (0.85, 0.65, 0.6), m, i(), 3, sub=3,
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
    z0 = Vector((0, 0, A.z))
    tronco("amostra_laje", (A.x, A.y, A.z + 0.07), 1.9, 1.75, 0.16, laje, i(), segs=7)
    tronco("amostra_po", (A.x + 0.02, A.y, A.z + 0.17), 0.34, 0.14, 0.06, po, i(), segs=14)
    c.cilindro("amostra_furo", (A.x, A.y, A.z + 0.205), 0.1, 0.02, furo, i(), segs=14)
    # braço de campo, num pedestal, com a broca sobre o furo
    ped = Vector((A.x - 1.7, A.y - 1.7, A.z))
    tubo("amostra_pedestal", ped, ped + Vector((0, 0, 0.9)), 0.22, junta, i(), segs=16)
    punho = Vector((A.x, A.y, A.z + 0.95))
    braco("amostra_braco", ped + Vector((0, 0, 0.95)), punho, 1.4, 1.4, braco_m, junta, esp=0.11)
    tubo("amostra_broca", punho, Vector((A.x, A.y, A.z + 0.24)), 0.045, brocas, i(), segs=8)
    tubo("amostra_mandril", punho + Vector((0, 0, 0.05)), punho - Vector((0, 0, 0.25)), 0.11, junta, i(), segs=12)
    # porta-tubos numa mesa baixa
    M = Vector((A.x + 2.3, A.y - 1.0, A.z))
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
    # cabo do pedestal até o campo de painéis (a caixa de junção da fila de trás)
    cabo_no_chao("amostra_cabo", [(ped.x, ped.y), (ped.x, LINHAS[-1] + 1.8), (-3.1, LINHAS[-1] + 1.8)], junta)


def pedras_soltas():
    rng = random.Random(7)
    claras = [mat(f"pedra_{k}", h, 1.0) for k, h in enumerate(("4d2b32", "7a4841", "577277", "884b2b"))]
    proibido = [(-6.5, 6.5, -4.8, 3.2), (-12.5, 12.5, 13.0, 27.0), (-9.0, 2.0, 31.0, 42.0),
                (-1.5, 1.5, 3.0, 13.0), (-6.5, 4.5, 8.0, 14.0), (-1.2, 2.5, 3.2, 9.2),
                (5.5, 13.5, -4.5, 1.0), (-4.0, -1.0, -8.0, -5.0), (3.0, 6.0, -9.5, -6.0)]

    def livre(x, y, r):
        return not any(x0 - r < x < x1 + r and y0 - r < y < y1 + r for x0, x1, y0, y1 in proibido)

    feitas, k = 0, 0
    while feitas < 260 and k < 12000:
        k += 1
        # a maior parte cai no que a janela vê (frente e lados), o resto no entorno
        if feitas < 130:
            y = rng.uniform(4.0, 90.0) if feitas < 70 else rng.uniform(27.0, 140.0)
            x = rng.uniform(-0.75, 0.75) * y + rng.uniform(-4, 4)
        else:
            alcance = 60 if feitas < 190 else 250
            x, y = rng.uniform(-alcance, alcance), rng.uniform(-alcance * 0.6, alcance)
        t = rng.random()
        if feitas < 70:
            r = 0.1 + 0.5 * t                              # pedras que a janela vê na frente
        elif feitas < 130:
            r = 0.4 + 1.2 * t                              # blocos no morro, mais longe
        else:
            r = 0.15 + 0.35 * t if feitas < 190 else 0.5 + 1.4 * t
        if not livre(x, y, r + 0.3):
            continue
        z = chao(x, y) + 0.25 * r
        pedra(f"pedra_solta_{feitas}", (x, y, z), (r * rng.uniform(0.8, 1.4), r * rng.uniform(0.8, 1.3), r * rng.uniform(0.6, 1.0)),
              rng.choice(claras), idx("pedras"), rng.uniform(0, 50), sub=1 if r < 0.2 else 2,
              yaw=rng.uniform(0, 6.28))
        feitas += 1


def afloramentos():
    """Lajes em camadas empilhadas, como os afloramentos do sopé: cada camada de uma cor."""
    rng = random.Random(21)
    cores = [mat(f"afloramento_{k}", h, 1.0) for k, h in enumerate(("c09473", "7a4841", "ad7757", "4d2b32"))]
    lugares = [(7.0, 33.0, 3.0), (14.0, 42.0, 3.6), (-12.0, 46.0, 3.2), (3.0, 58.0, 4.4),
               (-18.0, 66.0, 4.0), (19.0, 74.0, 5.0), (-4.0, 92.0, 5.5)]
    for k, (x, y, r) in enumerate(lugares):
        z = chao(x, y)
        yaw = rng.uniform(0, math.pi)
        for n in range(4):
            esc = 1.0 - 0.17 * n
            pedra(f"afloramento_{k}_{n}", (x + 0.1 * n, y, z + 0.14 + 0.26 * n),
                  (r * esc, r * 0.7 * esc, 0.2), cores[(k + n) % 4], idx("pedras"), 3.0 + 1.7 * k + n, sub=2,
                  rugosidade=0.12, yaw=yaw)


def cabo_no_chao(nome, pontos, m, esp=0.12, passo=1.0):
    """Cabo que segue o chão: trechos de ~1 m, cada um na altura do relevo."""
    for n, ((x0, y0), (x1, y1)) in enumerate(zip(pontos[:-1], pontos[1:])):
        d = math.hypot(x1 - x0, y1 - y0)
        k = max(1, int(round(d / passo)))
        for q in range(k):
            ax, ay = x0 + (x1 - x0) * q / k, y0 + (y1 - y0) * q / k
            bx, by = x0 + (x1 - x0) * (q + 1) / k, y0 + (y1 - y0) * (q + 1) / k
            barra(f"{nome}_{n}_{q}", (ax, ay, chao(ax, ay) + 0.06), (bx, by, chao(bx, by) + 0.06), esp, m, idx("cabos"))


def cabos():
    m = mat("cabo", "202e37")
    cabo_no_chao("cabo_painel", [(0.0, 2.6), (0.0, LINHAS[0] - 1.8), (COLUNAS[2] - 1.0, LINHAS[0] - 1.8)], m)
    c.caixa("cabo_caixa", (COLUNAS[2] - 1.0, LINHAS[0] - 1.8, chao(COLUNAS[2] - 1.0, LINHAS[0] - 1.8) + 0.25),
            (0.5, 0.5, 0.5), mat("cabo_caixa", "577277"), idx())


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


# ---------------------------------------------------------------- vista da janela do cômodo

def renderizar_vista(a, mundo, estados, saida):
    """Vista de Marte pela janela: câmera cilíndrica idêntica à do comodo.py, 1280x360.

    O casco do habitat sai do render para a câmera (continua projetando sombra no chão):
    o interior é o comodo.py. Devolve {estado: passes} para a conferência do horizonte.
    """
    s = bpy.context.scene
    pano = c.PANORAMA
    c.configurar(types.SimpleNamespace(amostras=a.amostras, largura=pano["largura"],
                                       altura=pano["altura"], camera="cilindrica", yaw=pano["yaw"],
                                       graus=pano["graus"], rad_por_px=None))
    cam = s.camera
    cam.data.clip_end = 50000.0                              # o Monte Sharp está a quilômetros
    assert np.allclose(tuple(cam.location), c.OLHO), "a vista tem de sair do olho do comodo.py"
    for ob in HABITAT:
        ob.visible_camera = False
    out = {}
    for estado in estados:
        e = aplicar_estado(estado, mundo)
        exr = CACHE / f"exterior_vista_janela_{estado}.exr"
        s.render.filepath = str(exr)
        bpy.ops.render.render(write_still=True)
        p = c.ler_exr(exr)
        cor, t = neblina(p, e)
        destino = saida / f"vista_janela_{estado}.png"
        c.salvar_png(destino, pixel_art(cor, t, p, e))
        out[estado] = p
        print(f"[exterior] vista da janela {estado}: {destino}")
    return out


def ler_png_rgba(caminho):
    import OpenImageIO as oiio
    inp = oiio.ImageInput.open(str(caminho))
    spec = inp.spec()
    px = np.asarray(inp.read_image(0, 0, 0, spec.nchannels, "uint8")).reshape(spec.height, spec.width, spec.nchannels)
    inp.close()
    if spec.nchannels == 3:
        px = np.dstack([px, np.full(px.shape[:2], 255, np.uint8)])
    return px


def compor_janela(saida, passes):
    """Sala por cima da vista, como o Godot faz: normal x normal, normal x poeira, abrigo x normal.

    Imprime onde o horizonte cai na vista e quantas linhas do vidro ficam acima e abaixo dele.
    """
    sala = RAIZ / "assets" / "comodo"
    linhas = []
    for estado_sala, estado_vista in (("normal", "normal"), ("normal", "poeira"), ("abrigo", "normal")):
        if estado_vista not in passes:
            continue
        s_ = ler_png_rgba(sala / f"{estado_sala}.png")
        v_ = ler_png_rgba(saida / f"vista_janela_{estado_vista}.png")
        linhas.append(np.where(s_[..., 3:4] > 0, s_[..., :3], v_[..., :3]).astype(np.uint8))
    if linhas:
        destino = CACHE / "janela_composicao.png"
        c.salvar_png(destino, np.concatenate(linhas, 0))
        print(f"[exterior] composição sala x vista ({len(linhas)} quadros, de cima para baixo: "
              f"normal+normal, normal+poeira, abrigo+normal): {destino}")

    sala_n = ler_png_rgba(sala / "normal.png")
    vidro = sala_n[..., 3] == 0
    ys, xs = np.nonzero(vidro)
    if not len(xs) or "normal" not in passes:
        return
    p = passes["normal"]
    z = p["z"]
    ceu = z > 1e8
    monte = ~ceu & (z >= DIST_MONTE)
    chao = ~ceu & ~monte
    n = vidro.sum()
    print(f"[exterior] vidro transparente do normal.png: x {xs.min()}..{xs.max()}, y {ys.min()}..{ys.max()} "
          f"({n} px; altura do olho = y {c.PANORAMA['altura'] // 2})")
    print(f"[exterior] composição do vidro: chão e encosta (até {DIST_MONTE:.0f} m, com as peças da base) "
          f"{(chao & vidro).sum() / n:.1%}, montanha {(monte & vidro).sum() / n:.1%}, "
          f"céu {(ceu & vidro).sum() / n:.1%}")
    cols = range(xs.min() + 4, xs.max() - 3)

    def topo(m):
        return np.array([np.nonzero(m[:, x] & vidro[:, x])[0].min() if (m[:, x] & vidro[:, x]).any() else np.nan
                         for x in cols], float)

    t_chao, t_monte = topo(chao), topo(~ceu)
    print(f"[exterior] linha do chão (primeira linha de chão na coluna, só vidro): "
          f"y {np.nanmin(t_chao):.0f}..{np.nanmax(t_chao):.0f}, mediana {np.nanmedian(t_chao):.0f}")
    print(f"[exterior] linha da montanha (primeira linha sem céu): "
          f"y {np.nanmin(t_monte):.0f}..{np.nanmax(t_monte):.0f}, mediana {np.nanmedian(t_monte):.0f}")
    print(f"[exterior] linhas do vidro: {180 - ys.min()} acima da altura do olho, "
          f"{ys.max() + 1 - 180} abaixo")


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
    escolhidas = [] if a.so_vista else [x for x in a.cameras.split(",") if x]
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

    if not a.sem_vista:
        passes = renderizar_vista(a, mundo, estados, saida)
        compor_janela(saida, passes)


if __name__ == "__main__":
    main()
