"""Gera o módulo de comando do zero e renderiza um PNG em pixel art por estado.

Uso (da raiz do repo):
    blender -b --factory-startup -P $PWD/arte/blender/comodo.py
    blender -b --factory-startup -P $PWD/arte/blender/comodo.py -- --estados normal
(o `blender` do PATH é o Flatpak: passe o script por caminho absoluto.)

Fonte da verdade: este script. Nenhum .blend é salvo nem lido.
Mesma câmera em todos os estados. A geometria também é a mesma, com uma única exceção
permitida: a persiana da janela, que só o estado `abrigo` fecha. O estado muda luz e emissão.
A persiana fica 6,5 cm na frente da moldura, então no `abrigo` ela cobre também o montante
central e as bordas da janela, não só o vidro. Por isso há o estado extra `abrigo_aberto`: a
mesma luz e emissão do `abrigo`, sem a persiana e com o vidro em alpha 0. Ele não entra no padrão
de `--estados` (renderize com `--estados abrigo_aberto`); scripts/gerar_persiana.py usa a
diferença entre `abrigo` e `abrigo_aberto` como a camada da persiana.

A janela larga do centro não leva vista assada: o vidro sai com alpha 0 no PNG (menos no
`abrigo`, onde a persiana o cobre) e o Godot põe a vista de Marte atrás, por composição. A vista
vem do exterior.py, que usa a mesma câmera (OLHO, PANORAMA) deste script.

Além dos PNGs do panorama, grava assets/comodo/regioes.json (retângulos dos botões e telas,
calculados pela projeção real da câmera sobre os vértices). Botões: abrigo, estufa e glovebox.
Telas: energia, oxigenio, radiacao e comunicacao (a tela da Terra, apagada: quem a acende é o
Godot). O terminal não é render: é camada de tela no Godot.
Uma imagem de depuração com os retângulos fica em arte/blender/.render/regioes_debug.png.

Paleta: Apollo, de AdamCYounis (https://lospec.com/palette-list/apollo).
"""

import argparse
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
import OpenImageIO as oiio
from mathutils import Vector

RAIZ = Path(__file__).resolve().parents[2]
CACHE = RAIZ / "arte" / "blender" / ".render"

ESTADOS = ["normal", "tempestade", "abrigo", "modo_seguranca"]
# Fora do padrão de --estados: só se pede por nome. Usa a luz do abrigo, sem a persiana.
ESTADOS_EXTRA = ["abrigo_aberto"]

# Apollo, AdamCYounis — https://lospec.com/palette-list/apollo
APOLLO = (
    "172038 253a5e 3c5e8b 4f8fba 73bed3 a4dddb 19332d 25562e 468232 75a743 "
    "a8ca58 d0da91 4d2b32 7a4841 ad7757 c09473 d7b594 e7d5b3 341c27 602c2c "
    "884b2b be772b de9e41 e8c170 241527 411d31 752438 a53030 cf573c da863e "
    "1e1d39 402751 7a367b a23e8c c65197 df84a5 090a14 10141f 151d28 202e37 "
    "394a50 577277 819796 a8b5b2 c7cfcc ebede9"
).split()

OLHO = (0.0, 0.0, 1.2)
# Campo do panorama: o exterior.py renderiza a vista da janela com os mesmos valores.
PANORAMA = dict(largura=1280, altura=360, graus=180.0, yaw=0.0)


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser(prog="comodo.py")
    p.add_argument("--estados", default=",".join(ESTADOS))
    p.add_argument("--camera", choices=["cilindrica", "perspectiva"], default="cilindrica")
    p.add_argument("--largura", type=int, default=PANORAMA["largura"])
    p.add_argument("--altura", type=int, default=PANORAMA["altura"])
    p.add_argument("--graus", type=float, default=PANORAMA["graus"],
                   help="campo horizontal do panorama (cilíndrica) em graus")
    p.add_argument("--yaw", type=float, default=0.0, help="graus, positivo vira para a direita")
    p.add_argument("--rad-por-px", type=float, default=None,
                   help="escala angular no centro; padrão: graus/largura")
    p.add_argument("--saida", default="assets/comodo")
    p.add_argument("--sufixo", default="")
    p.add_argument("--amostras", type=int, default=64)
    return p.parse_args(argv)


# ---------------------------------------------------------------- materiais

MATS = {}


def material(nome, cor, rugosidade=0.8):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*cor, 1.0)
    b.inputs["Roughness"].default_value = rugosidade
    MATS[nome] = m
    return m


def hexrgb(h):
    """sRGB hex -> linear RGB."""
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def tela_horizonte(nome, ceu, chao, altura_horizonte):
    """Tela de câmera: céu e chão em duas faixas, só emissão."""
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (*hexrgb(chao), 1)
    ramp.color_ramp.elements[1].position = altura_horizonte
    ramp.color_ramp.elements[1].color = (*hexrgb(ceu), 1)
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], em.inputs["Color"])
    nt.links.new(em.outputs[0], out.inputs[0])
    MATS[nome] = m
    return m


def emissao(mat, cor, forca):
    nt = mat.node_tree
    if "Principled BSDF" in nt.nodes:
        b = nt.nodes["Principled BSDF"]
        b.inputs["Emission Color"].default_value = (*cor, 1.0)
        b.inputs["Emission Strength"].default_value = forca
    else:
        nt.nodes["Emission"].inputs["Strength"].default_value = forca


# ---------------------------------------------------------------- geometria

INDICE = {}
COR_BOTAO = {}


def _objeto(nome, malha, mat, indice):
    ob = bpy.data.objects.new(nome, malha)
    bpy.context.scene.collection.objects.link(ob)
    if mat:
        ob.data.materials.append(mat)
    ob.pass_index = indice
    INDICE[nome] = indice
    return ob


def caixa(nome, centro, tamanho, mat, indice, rot=(0, 0, 0)):
    me = bpy.data.meshes.new(nome)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=tamanho, verts=bm.verts)
    bm.to_mesh(me)
    bm.free()
    ob = _objeto(nome, me, mat, indice)
    ob.location = centro
    ob.rotation_euler = [math.radians(a) for a in rot]
    return ob


def cilindro(nome, centro, raio, comprimento, mat, indice, rot=(0, 0, 0), segs=24):
    me = bpy.data.meshes.new(nome)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=raio, radius2=raio,
                          depth=comprimento)
    bm.to_mesh(me)
    bm.free()
    ob = _objeto(nome, me, mat, indice)
    ob.location = centro
    ob.rotation_euler = [math.radians(a) for a in rot]
    for p in me.polygons:
        p.use_smooth = False
    return ob


def toro(nome, centro, raio, espessura, mat, indice, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=raio, minor_radius=espessura,
                                     major_segments=24, minor_segments=8,
                                     location=centro,
                                     rotation=[math.radians(a) for a in rot])
    ob = bpy.context.active_object
    ob.name = nome
    ob.data.materials.append(mat)
    ob.pass_index = indice
    INDICE[nome] = indice
    return ob


def prisma_yz(nome, pontos_yz, x0, x1, mat, indice):
    """Prisma: polígono no plano yz (y para o fundo, z para cima) extrudado de x0 a x1."""
    me = bpy.data.meshes.new(nome)
    bm = bmesh.new()
    lado = [[bm.verts.new((x, y, z)) for y, z in pontos_yz] for x in (x0, x1)]
    bm.faces.new(lado[0])
    bm.faces.new(lado[1][::-1])
    n = len(pontos_yz)
    for k in range(n):
        bm.faces.new((lado[0][k], lado[0][(k + 1) % n], lado[1][(k + 1) % n], lado[1][k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    return _objeto(nome, me, mat, indice)


def placa_para_o_olho(nome, centro, tamanho, mat, indice, avanco=0.0):
    """Caixa cuja face da frente (-y local) olha direto para o olho, em guinada e em arfagem.

    Uma placa perpendicular à linha de visão projeta quase um retângulo na câmera cilíndrica,
    mesmo inclinada, e o retângulo da região casa com o que o Godot desenha por cima.
    `avanco` desloca o centro, em metros, pela normal (para o olho).
    """
    c = Vector(centro)
    v = (Vector(OLHO) - c).normalized()
    ob = caixa(nome, tuple(c + v * avanco), tamanho, mat, indice)
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = v.to_track_quat("-Y", "Z")
    return ob


class Painel:
    """Plano vertical voltado para o olho, em torno de (cx, cy) no chão.

    A criança olha para ele de frente, então as bordas horizontais não viram trapézio no
    panorama e o retângulo da tela casa com a textura que o Godot desenha por cima.
    Coordenadas locais: `a` para a direita de quem olha, `d` para o olho, `z` para cima.
    """

    def __init__(self, cx, cy):
        d = math.hypot(cx, cy)
        self.c = (cx, cy)
        self.f = (cx / d, cy / d)                 # do olho para o painel
        self.u = (self.f[1], -self.f[0])          # direita de quem olha
        self.yaw = math.degrees(math.atan2(self.u[1], self.u[0]))

    def pos(self, a, d, z):
        return (self.c[0] + a * self.u[0] - d * self.f[0],
                self.c[1] + a * self.u[1] - d * self.f[1], z)

    def caixa(self, nome, a, d, z, larg, prof, alt, mat, indice):
        return caixa(nome, self.pos(a, d, z), (larg, prof, alt), mat, indice,
                     rot=(0, 0, self.yaw))

    def cil(self, nome, a, d, z, raio, comp, mat, indice, segs=24):
        # eixo do cilindro apontando para o olho
        return cilindro(nome, self.pos(a, d, z), raio, comp, mat, indice,
                        rot=(90, 0, self.yaw), segs=segs)


def tela_apagada(nome, hexa):
    """Tela em branco: emissão de uma cor só, igual em todos os estados."""
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*hexrgb(hexa), 1.0)
    em.inputs["Strength"].default_value = 1.0
    nt.links.new(em.outputs[0], out.inputs[0])
    MATS[nome] = m
    return m


# Centro da sala (metros): janela larga, rampa e telas. O exterior.py abre o casco no mesmo lugar.
JANELA_Z = (1.00, 1.84)              # vão do vidro
JANELA_LARG = 2.4
N_PERSIANA = 10
BANCADA_Z = 0.46                     # topo da bancada
RAMPA_ELEV = 22.0                    # a normal da rampa sobe tantos graus acima da horizontal
RAMPA_CENTRO = (1.86, 0.74)          # (y, z) do centro de cada face da rampa
RAMPA_LARG, RAMPA_ALT = 1.30, 0.56   # medidas de cada face
TELA_X = 0.62                        # centro de cada face, para a esquerda e a direita
TELA_MOLDURA = (1.14, 0.50)
TELA_TAMANHO = (1.02, 0.40)
JANELA_OBJS = ("janela_moldura_topo", "janela_moldura_base", "janela_moldura_esq",
               "janela_moldura_dir", "janela_moldura_montante", "janela")

COR_TELA_APAGADA = "202e37"          # cor única das telas em branco (Apollo)
TELAS_APAGADAS = ("energia_tela", "oxigenio_tela", "radiacao_tela", "comunicacao_tela")
AZUL_TERRA = "73bed3"                # azul é só do que vem da Terra (moldura da tela de comunicação)
PERSIANA = []                        # objetos da persiana; só o estado abrigo os renderiza


def botao(nome, cor):
    """Material de botão: a cor vem da emissão; o difuso escuro e sem especular não estoura."""
    mb = material(nome, tuple(c * 0.35 for c in hexrgb(cor)), 0.9)
    mb.node_tree.nodes["Principled BSDF"].inputs["Specular IOR Level"].default_value = 0.0
    COR_BOTAO[nome] = hexrgb(cor)
    return mb


def construir():
    """Gray-box do módulo de comando. Unidades em metros; o olho fica em OLHO.

    Esquerda (x<320 no panorama): porta, suporte de vida com a tela de radiação e a alavanca
    do abrigo; na parede da frente, a tela de comunicação com a Terra (apagada, moldura azul).
    Centro (320-960): a janela larga para Marte e, abaixo dela, a rampa com as telas de energia
    e oxigênio e a bancada. Direita (>960): a parede da ciência de dentro, com a glovebox e a
    estufa lado a lado, em destaque.
    Todo botão clicável fica entre x 60 e 1220 (ZONA_LIVRE_X), fora das setas de pan do jogo.
    """
    W = 2.6       # meia largura (paredes laterais em x = ±W)
    F = 2.2       # parede da frente em y = F
    H = 2.4       # pé-direito

    parede = material("parede", hexrgb("819796"))
    piso = material("piso", hexrgb("394a50"))
    teto = material("teto", hexrgb("a8b5b2"))
    nervura = material("nervura", hexrgb("577277"))
    console = material("console", hexrgb("394a50"))
    painel = material("painel_console", hexrgb("202e37"))
    moldura = material("moldura", hexrgb("151d28"))
    porta = material("porta", hexrgb("884b2b"))
    faixa = material("faixa_abrigo", hexrgb("de9e41"))
    lampada_porta = material("lampada_porta", hexrgb("468232"))
    luminaria = material("luminaria", hexrgb("ebede9"))
    alarme = material("alarme", hexrgb("a53030"))
    janela = tela_horizonte("janela", "de9e41", "be772b", 0.35)
    ecra = tela_apagada("ecra_apagado", COR_TELA_APAGADA)
    amarelo = material("amarelo_aviso", hexrgb("e8c170"))
    caixa_c = material("caixa_ciencia", hexrgb("c7cfcc"))
    blindagem = material("blindagem", hexrgb("577277"))
    vidro_estufa = tela_apagada("vidro_estufa", "25562e")
    solo = material("solo", hexrgb("7a4841"))
    folha = material("folha", hexrgb("75a743"))
    luz_cultivo = tela_apagada("luz_cultivo", "df84a5")

    i = iter(range(1, 400))
    caixa("piso", (0, 1, -0.05), (2 * W, 4, 0.1), piso, next(i))
    caixa("teto", (0, 1, H + 0.05), (2 * W, 4, 0.1), teto, next(i))
    caixa("parede_frente", (0, F + 0.05, H / 2), (2 * W, 0.1, H), parede, next(i))
    caixa("parede_esq", (-W - 0.05, 1, H / 2), (0.1, 4, H), parede, next(i))
    caixa("parede_dir", (W + 0.05, 1, H / 2), (0.1, 4, H), parede, next(i))

    # nervuras verticais nas paredes (dão leitura de profundidade ao contorno);
    # param na calha, para não furar a linha reta que mede a câmera
    hn = 1.99
    caixa("nervura_f2.0", (2.0, F - 0.04, hn / 2), (0.12, 0.08, hn), nervura, next(i))
    for y in (0.0, 2.0):
        caixa(f"nervura_e{y}", (-W + 0.04, y, hn / 2), (0.08, 0.12, hn), nervura, next(i))
        caixa(f"nervura_d{y}", (W - 0.04, y, hn / 2), (0.08, 0.12, hn), nervura, next(i))

    # calha de cabos: linha reta longa em todas as paredes, a 2,05 m
    caixa("calha_frente", (0, F - 0.1, 2.05), (2 * W, 0.2, 0.12), nervura, next(i))
    caixa("calha_esq", (-W + 0.1, 1, 2.05), (0.2, 4, 0.12), nervura, next(i))
    caixa("calha_dir", (W - 0.1, 1, 2.05), (0.2, 4, 0.12), nervura, next(i))

    # luminárias no teto
    for y in (0.6, 1.6):
        caixa(f"luminaria_{y}", (0, y, H - 0.03), (1.6, 0.25, 0.06), luminaria, next(i))

    # ---- centro, de cima para baixo: a janela larga para Marte, a rampa com as telas de
    # energia e oxigênio e a bancada. A janela vai de 1,00 a 1,84 m: o horizonte (altura do
    # olho, 1,2 m) cai dentro dela, com um pouco de chão abaixo. O vidro é recuado em relação
    # à moldura e sai com alpha 0 no PNG (ver pixel_art); a persiana só fecha no abrigo.
    jz0, jz1 = JANELA_Z
    jl = JANELA_LARG
    borda = 0.10
    ix_moldura = next(i)                               # um índice só: sem traço entre as barras
    jc = (jz0 + jz1) / 2
    for nome, cx, cz, larg, alt in (
            ("topo", 0.0, jz1 + borda / 2, jl + 2 * borda, borda),
            ("base", 0.0, jz0 - borda / 2, jl + 2 * borda, borda),
            ("esq", -(jl + borda) / 2, jc, borda, jz1 - jz0),
            ("dir", (jl + borda) / 2, jc, borda, jz1 - jz0),
            ("montante", 0.0, jc, 0.10, jz1 - jz0)):
        caixa(f"janela_moldura_{nome}", (cx, F - 0.05, cz), (larg, 0.10, alt), moldura, ix_moldura)
    caixa("janela", (0.0, F - 0.02, jc), (jl, 0.01, jz1 - jz0), janela, next(i))
    pitch = (jz1 - jz0) / N_PERSIANA
    for k in range(N_PERSIANA):
        mat_s = faixa if k in (0, N_PERSIANA - 1) else blindagem
        PERSIANA.append(caixa(f"persiana_{k}", (0.0, F - 0.115, jz0 + (k + 0.5) * pitch),
                              (jl + 0.04, 0.03, pitch + 0.004), mat_s, next(i)))

    # bancada baixa e, atrás dela, a rampa: duas faces inclinadas, cada uma virada (em guinada)
    # para o olho, como um console que envolve quem olha. Cada tela fica rente à sua face, e assim
    # as bordas horizontais não curvam na câmera cilíndrica.
    caixa("console_bancada", (0.0, 1.65, BANCADA_Z / 2), (2 * 1.35, 0.9, BANCADA_Z), console,
          next(i))
    el = math.radians(RAMPA_ELEV)
    for nome, x in (("energia", -TELA_X), ("oxigenio", TELA_X)):
        c0 = Vector((x, RAMPA_CENTRO[0], RAMPA_CENTRO[1]))
        h = Vector((OLHO[0] - c0.x, OLHO[1] - c0.y, 0.0)).normalized()
        n = Vector((h.x * math.cos(el), h.y * math.cos(el), math.sin(el)))
        q = n.to_track_quat("-Y", "Z")

        def na_face(nome_, centro, tamanho, mat_, indice, avanco):
            ob = caixa(nome_, tuple(centro + n * avanco), tamanho, mat_, indice)
            ob.rotation_mode = "QUATERNION"
            ob.rotation_quaternion = q
            return ob

        na_face(f"rampa_{nome}", c0, (RAMPA_LARG, 0.2, RAMPA_ALT), console, next(i), -0.10)
        na_face(f"{nome}_moldura", c0, (TELA_MOLDURA[0], 0.06, TELA_MOLDURA[1]), moldura, next(i),
                0.03)
        na_face(f"{nome}_tela", c0, (TELA_TAMANHO[0], 0.01, TELA_TAMANHO[1]), ecra, next(i), 0.065)

    # ---- esquerda: porta do abrigo (parede esquerda), um pouco mais para o canto
    py = 0.55
    hw = 0.4
    caixa("porta_moldura_topo", (-W + 0.05, py, 2.0), (0.1, 2 * hw + 0.24, 0.15), moldura, next(i))
    caixa("porta_moldura_tras", (-W + 0.05, py - hw - 0.06, 1.0), (0.1, 0.12, 2.0), moldura, next(i))
    caixa("porta_moldura_frente", (-W + 0.05, py + hw + 0.06, 1.0), (0.1, 0.12, 2.0), moldura, next(i))
    caixa("porta_folha", (-W + 0.03, py, 0.97), (0.06, 2 * hw, 1.9), porta, next(i))
    caixa("porta_faixa", (-W + 0.07, py, 1.55), (0.04, 2 * hw, 0.12), faixa, next(i))
    toro("porta_volante", (-W + 0.12, py, 1.05), 0.22, 0.03, moldura, next(i), rot=(0, 90, 0))
    caixa("porta_lampada", (-W + 0.06, py, 2.2), (0.08, 0.3, 0.1), lampada_porta, next(i))

    # suporte de vida: coluna voltada para o olho, com a tela de radiação em cima
    # e a alavanca (botão cogumelo) do abrigo embaixo
    s = Painel(-2.14, 1.235)
    s.caixa("suporte_base", 0, 0, 0.06, 0.95, 0.42, 0.12, moldura, next(i))
    s.caixa("suporte_corpo", 0, 0, 1.05, 0.85, 0.30, 1.86, console, next(i))
    s.caixa("radiacao_moldura", 0, 0.17, 1.72, 0.80, 0.04, 0.50, moldura, next(i))
    s.caixa("radiacao_tela", 0, 0.195, 1.72, 0.72, 0.01, 0.42, ecra, next(i))
    botao("botao_abrigo", "cf573c")
    s.cil("abrigo_aro", 0, 0.175, 1.10, 0.25, 0.05, amarelo, next(i))
    s.cil("abrigo_anel", 0, 0.2, 1.10, 0.215, 0.05, moldura, next(i))
    s.cil("abrigo_botao", 0, 0.25, 1.10, 0.17, 0.12, MATS["botao_abrigo"], next(i))

    # parede da frente, à esquerda: a tela de comunicação com a Terra, num pilar voltado para o
    # olho (como o suporte de vida) e encostado na parede da frente. O miolo fica apagado, na cor
    # única das outras telas: quem a acende é o Godot. Azul é a cor do que vem da Terra, então só
    # a moldura leva azul (a mesma emissão em todos os estados, como a dos botões).
    botao("moldura_terra", AZUL_TERRA)
    t = Painel(-1.47, 1.82)
    t.caixa("comunicacao_base", 0, 0, 0.06, 0.74, 0.34, 0.12, moldura, next(i))
    t.caixa("comunicacao_corpo", 0, 0, 0.90, 0.60, 0.30, 1.68, console, next(i))
    t.caixa("comunicacao_moldura", 0, 0.17, 1.25, 0.52, 0.04, 0.40, MATS["moldura_terra"], next(i))
    t.caixa("comunicacao_tela", 0, 0.195, 1.25, 0.46, 0.01, 0.34, ecra, next(i))
    # antena de prato em cima do pilar (só enfeite; o ícone da Terra vem na tela, pelo Godot)
    t.cil("comunicacao_mastro", 0, 0.0, 1.80, 0.025, 0.16, blindagem, next(i))
    t.cil("comunicacao_prato", 0, 0.05, 1.92, 0.11, 0.04, nervura, next(i))

    # ---- direita: a parede da ciência de dentro, com a estufa (cultivar planta) e a glovebox
    # (selar a amostra), lado a lado e voltadas para o olho. São os dois objetos maiores e mais
    # claros da parede: moldura clara e uma faixa de luz própria cada. Verde só no que se clica
    # (o vidro e a planta). Tudo clicável fica entre x 60 e 1220 do panorama (as setas de pan
    # cobrem as pontas) e na faixa y 120..250.
    vidro_gb = tela_apagada("vidro_glovebox", "468232")
    luva = material("luva", hexrgb("819796"))
    tubo = material("tubo", hexrgb("ebede9"))
    tampa = material("tampa_tubo", hexrgb("c65197"))

    g = Painel(2.087, 1.466)
    g.caixa("glovebox_base", 0, 0, 0.40, 0.70, 0.40, 0.80, console, next(i))
    g.caixa("glovebox_moldura", 0, 0.05, 1.15, 0.78, 0.34, 0.68, caixa_c, next(i))
    g.caixa("glovebox_vidro", 0, 0.225, 1.17, 0.68, 0.01, 0.52, vidro_gb, next(i))
    for k, da in enumerate((-0.18, 0.18)):                  # as duas luvas: aro, borracha, boca
        g.cil(f"glovebox_aro{k}", da, 0.24, 0.99, 0.115, 0.03, moldura, next(i))
        g.cil(f"glovebox_luva{k}", da, 0.26, 0.99, 0.085, 0.03, luva, next(i))
        g.cil(f"glovebox_boca{k}", da, 0.28, 0.99, 0.050, 0.03, painel, next(i))
    # o tubo de amostra, deitado num suporte dentro da câmara: vidro, faixa rosa e tampa escura
    g.caixa("glovebox_suporte", 0, 0.24, 1.17, 0.40, 0.02, 0.03, moldura, next(i))
    ix_tubo = next(i)
    for nome, da, raio, comp, mat in (("glovebox_tubo", 0.0, 0.040, 0.34, tubo),
                                      ("glovebox_liquido", -0.07, 0.044, 0.13, tampa),
                                      ("glovebox_tampa", 0.19, 0.046, 0.05, painel)):
        cilindro(nome, g.pos(da, 0.265, 1.245), raio, comp, mat, ix_tubo, rot=(0, 90, g.yaw),
                 segs=16)

    e = Painel(2.315, 0.66)
    e.caixa("estufa_corpo", 0, 0, 0.88, 0.66, 0.40, 1.76, caixa_c, next(i))
    pz = 1.18
    e.caixa("estufa_moldura", 0, 0.22, pz, 0.54, 0.04, 0.66, moldura, next(i))
    e.caixa("estufa_vidro", 0, 0.24, pz, 0.46, 0.01, 0.58, vidro_estufa, next(i))
    e.caixa("estufa_luz", 0, 0.25, pz + 0.255, 0.40, 0.02, 0.05, luz_cultivo, next(i))
    e.caixa("estufa_solo", 0, 0.26, pz - 0.23, 0.40, 0.04, 0.09, solo, next(i))
    e.caixa("estufa_caule", 0, 0.26, pz - 0.04, 0.045, 0.03, 0.34, folha, next(i))
    for k, (da, dz, giro) in enumerate(((-0.10, pz + 0.05, 25), (0.10, pz - 0.03, -25),
                                         (0.0, pz + 0.15, 0))):
        caixa(f"estufa_folha{k}", e.pos(da, 0.26, dz), (0.15, 0.03, 0.075), folha, next(i),
              rot=(0, giro, e.yaw))

    # alarmes nos cantos de cima da frente
    for x in (-2.3, 2.3):
        cilindro(f"alarme_{x}", (x, F - 0.12, 2.25), 0.09, 0.14, alarme, next(i), rot=(90, 0, 0))

    # luzes (energia e cor mudam por estado)
    luzes = {}
    for nome, loc, tam in (("luz_teto", (0, 1.1, H - 0.1), (1.6, 1.2)),):
        ld = bpy.data.lights.new(nome, "AREA")
        ld.shape = "RECTANGLE"
        ld.size, ld.size_y = tam
        ob = bpy.data.objects.new(nome, ld)
        ob.location = loc
        bpy.context.scene.collection.objects.link(ob)
        luzes[nome] = ld
    for x in (-2.3, 2.3):
        ld = bpy.data.lights.new(f"luz_alarme_{x}", "POINT")
        ld.shadow_soft_size = 0.1
        ob = bpy.data.objects.new(ld.name, ld)
        ob.location = (x, F - 0.35, 2.15)
        bpy.context.scene.collection.objects.link(ob)
        luzes[ld.name] = ld
    ld = bpy.data.lights.new("luz_porta", "POINT")
    ob = bpy.data.objects.new("luz_porta", ld)
    ob.location = (-W + 0.4, py, 2.0)
    bpy.context.scene.collection.objects.link(ob)
    luzes["luz_porta"] = ld
    ld = bpy.data.lights.new("luz_console", "AREA")
    ld.size = 3.0
    ob = bpy.data.objects.new("luz_console", ld)
    ob.location = (0, 1.9, 1.55)
    ob.rotation_euler = (math.radians(-90), 0, 0)
    bpy.context.scene.collection.objects.link(ob)
    luzes["luz_console"] = ld
    return luzes


# ---------------------------------------------------------------- estados

def aplicar_estado(estado, luzes):
    """Só luz e emissão (e a persiana da janela, no abrigo). Nada de material base ou câmera."""
    branco = hexrgb("ebede9")
    ambar = hexrgb("de9e41")
    vermelho = hexrgb("cf573c")
    verde = hexrgb("75a743")
    azul = hexrgb("73bed3")

    # (cor, energia W) por luz; (cor, força) por emissão
    E = {
        "normal": dict(
            luz_teto=(branco, 150), luz_console=(azul, 25), luz_porta=(verde, 0),
            alarme=(vermelho, 0), luz_alarme=(vermelho, 0), luminaria=(branco, 6),
            telas=1.0, janela=1.2, botoes=0.8, lampada_porta=(verde, 0.5), mundo=0.02),
        "tempestade": dict(
            luz_teto=(ambar, 90), luz_console=(azul, 25), luz_porta=(verde, 0),
            alarme=(vermelho, 12), luz_alarme=(vermelho, 60), luminaria=(ambar, 2),
            telas=1.0, janela=0.25, botoes=1.0, lampada_porta=(ambar, 3), mundo=0.01),
        "abrigo": dict(
            luz_teto=(branco, 40), luz_console=(azul, 15), luz_porta=(verde, 80),
            alarme=(vermelho, 0), luz_alarme=(vermelho, 0), luminaria=(branco, 1),
            telas=0.7, janela=0.6, botoes=0.8, lampada_porta=(verde, 8), mundo=0.01),
        "modo_seguranca": dict(
            luz_teto=(vermelho, 25), luz_console=(azul, 0), luz_porta=(verde, 0),
            alarme=(vermelho, 4), luz_alarme=(vermelho, 15), luminaria=(vermelho, 0.5),
            telas=0.0, janela=0.4, botoes=0.0, lampada_porta=(vermelho, 2), mundo=0.005),
    }["abrigo" if estado == "abrigo_aberto" else estado]

    def luz(nome, cor_energia):
        luzes[nome].color, luzes[nome].energy = cor_energia

    luz("luz_teto", E["luz_teto"])
    luz("luz_console", E["luz_console"])
    luz("luz_porta", E["luz_porta"])
    for n in luzes:
        if n.startswith("luz_alarme"):
            luz(n, E["luz_alarme"])
    emissao(MATS["alarme"], *E["alarme"])
    emissao(MATS["luminaria"], *E["luminaria"])
    emissao(MATS["lampada_porta"], *E["lampada_porta"])
    for n, m in MATS.items():
        if n.startswith("tela_"):
            emissao(m, None, E["telas"])
        elif n in COR_BOTAO:
            emissao(m, COR_BOTAO[n], E["botoes"])
    emissao(MATS["janela"], None, E["janela"])
    for ob in PERSIANA:                  # única diferença de geometria entre estados
        ob.hide_render = estado != "abrigo"  # (abrigo_aberto também a esconde)
    bpy.context.scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = E["mundo"]


# ---------------------------------------------------------------- câmera e render

def configurar(a):
    s = bpy.context.scene
    s.render.engine = "CYCLES"
    s.cycles.device = "CPU"
    s.cycles.samples = a.amostras
    s.cycles.use_denoising = True
    s.cycles.seed = 0
    s.cycles.filter_width = 0.01          # um raio por pixel no centro: sem antialiasing
    s.render.resolution_x = a.largura
    s.render.resolution_y = a.altura
    s.render.resolution_percentage = 100
    s.render.use_compositing = False      # sem isso o EXR multilayer sai só com o Combined
    s.view_settings.view_transform = "Standard"
    s.view_settings.look = "None"
    vl = s.view_layers[0]
    vl.use_pass_z = True
    vl.use_pass_normal = True
    vl.use_pass_object_index = True
    s.render.image_settings.media_type = "MULTI_LAYER_IMAGE"
    s.render.image_settings.file_format = "OPEN_EXR_MULTILAYER"
    s.render.image_settings.color_depth = "32"
    s.render.image_settings.exr_codec = "ZIP"

    if s.world is None:
        s.world = bpy.data.worlds.new("mundo")
    s.world.use_nodes = True

    cam = bpy.data.cameras.new("camera")
    ob = bpy.data.objects.new("camera", cam)
    s.collection.objects.link(ob)
    s.camera = ob
    ob.location = OLHO
    ob.rotation_euler = (math.radians(90), 0, math.radians(-a.yaw))
    cam.clip_start = 0.05

    rad_px = a.rad_por_px or math.radians(a.graus) / a.largura
    meia_v = rad_px * a.altura / 2          # tan da meia altura, pixel quadrado no centro
    if a.camera == "cilindrica":
        cam.type = "PANO"
        cam.panorama_type = "CENTRAL_CYLINDRICAL"
        meia_u = rad_px * a.largura / 2
        cam.central_cylindrical_range_u_min = -meia_u
        cam.central_cylindrical_range_u_max = meia_u
        cam.central_cylindrical_range_v_min = -meia_v
        cam.central_cylindrical_range_v_max = meia_v
        cam.central_cylindrical_radius = 1.0
    else:
        cam.type = "PERSP"
        cam.sensor_fit = "VERTICAL"
        cam.angle_y = 2 * math.atan(meia_v)
    return rad_px


def ler_exr(caminho):
    """O Blender 5.3 grava cada passe como uma parte (subimagem) do EXR."""
    inp = oiio.ImageInput.open(str(caminho))
    canais = {}
    sub = 0
    while inp.seek_subimage(sub, 0):
        spec = inp.spec()
        px = np.asarray(inp.read_image(sub, 0, 0, spec.nchannels, "float"))
        px = px.reshape(spec.height, spec.width, spec.nchannels)
        for k, nome in enumerate(spec.channelnames):
            canais[nome] = px[:, :, k]
        sub += 1
    inp.close()

    def canal(*sufixos):
        out = []
        for suf in sufixos:
            achados = [n for n in canais if n.endswith(suf)]
            if not achados:
                raise KeyError(f"canal {suf} não está em {list(canais)}")
            out.append(canais[achados[0]])
        return np.stack(out, -1)

    alfa = [n for n in canais if n.endswith("Combined.A")]
    return {
        "alfa": canais[alfa[0]] if alfa else None,
        "cor": canal("Combined.R", "Combined.G", "Combined.B"),
        "z": canal("Depth.Z")[..., 0],
        "normal": canal("Normal.X", "Normal.Y", "Normal.Z"),
        "indice": np.rint(canal("Object Index.X")[..., 0]).astype(np.int32),
    }


# ---------------------------------------------------------------- pixel art

def srgb_para_oklab(c):
    c = np.clip(c, 0, 1)
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    return lin_para_oklab(lin)


def lin_para_oklab(lin):
    M1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929],
                   [0.2119034982, 0.6806995451, 0.1073969566],
                   [0.0883024619, 0.2817188376, 0.6299787005]])
    M2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468],
                   [1.9779984951, -2.4285922050, 0.4505937099],
                   [0.0259040371, 0.7827717662, -0.8086757660]])
    lms = np.cbrt(np.clip(lin, 0, None) @ M1.T)
    return lms @ M2.T


PALETA_SRGB = np.array([[int(h[i:i + 2], 16) for i in (0, 2, 4)] for h in APOLLO], np.uint8)
PALETA_LAB = srgb_para_oklab(PALETA_SRGB / 255.0)


# Verde é sinal (abrigo, painel ok): a rampa verde da Apollo só vale nos objetos verdes
# e no estado abrigo, para a mistura de luz âmbar com parede cinza não virar verde.
VERDES = np.array([6, 7, 8, 9, 10, 11])
OBJETOS_VERDES = ("porta_lampada", "estufa_vidro", "estufa_caule", "estufa_folha0",
                  "estufa_folha1", "estufa_folha2", "glovebox_vidro")


def quantizar(lin, verde_ok=True):
    """Linear -> índice da cor mais próxima da paleta em OKLab.

    verde_ok: bool ou máscara por pixel de onde a rampa verde pode ser usada.
    """
    lab = lin_para_oklab(np.clip(lin, 0, 1))
    d = ((lab[..., None, :] - PALETA_LAB[None, None]) ** 2).sum(-1)
    q = d.argmin(-1)
    d[..., VERDES] = np.inf
    return np.where(verde_ok, q, d.argmin(-1))


def contorno(p):
    """Máscara de contorno de 1 px a partir de profundidade, normal e índice de objeto.

    Vizinhança de 4 (cima, baixo, esquerda, direita), como em David Holland,
    "3D Pixel Art Rendering". O traço fica no pixel mais próximo da câmera.
    """
    z, n, idx = p["z"], p["normal"], p["indice"]
    borda = np.zeros(z.shape, bool)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        zv = np.roll(z, (dy, dx), (0, 1))
        nv = np.roll(n, (dy, dx), (0, 1))
        iv = np.roll(idx, (dy, dx), (0, 1))
        mais_perto = z <= zv
        silhueta = (zv - z) / np.maximum(z, 1e-3) > 0.06
        vinco = ((n * nv).sum(-1) < 0.75) & mais_perto
        objeto = (iv != idx) & mais_perto
        borda |= silhueta | vinco | objeto
    borda[0, :] = borda[-1, :] = False
    borda[:, 0] = borda[:, -1] = False
    return borda


def pixel_art(p, borda, estado):
    """Devolve o RGBA do panorama; o vidro da janela sai com alpha 0 (menos no abrigo)."""
    if estado in ("abrigo", "abrigo_aberto"):
        verde_ok = True
    else:
        verde_ok = np.isin(p["indice"], [INDICE[n] for n in OBJETOS_VERDES if n in INDICE])
    q = quantizar(p["cor"], verde_ok)
    # traço: a cor da paleta mais próxima de 25 % do brilho do pixel por baixo
    escura = quantizar(PALETA_LAB_LIN[q] * 0.25, verde_ok)
    q = np.where(borda, escura, q)
    rgb = PALETA_SRGB[q].copy()
    # telas em branco: cor única por dentro (o contorno de 1 px fica), para o Godot
    # desenhar as barras por cima sem ruído do render
    cor_tela = PALETA_SRGB[APOLLO.index(COR_TELA_APAGADA)]
    for nome in TELAS_APAGADAS:
        rgb[(p["indice"] == INDICE[nome]) & ~borda] = cor_tela
    # vidro da janela: alpha 0, e o Godot põe a vista de Marte atrás. No abrigo a persiana tapa
    # o vidro, e o que sobrar dele (frestas) fica opaco.
    alfa = np.full(rgb.shape[:2], 255, np.uint8)
    if estado != "abrigo":
        vidro = (p["indice"] == INDICE["janela"]) & ~borda
        alfa[vidro] = 0
        rgb[vidro] = 0
    return np.dstack([rgb, alfa])


def _srgb_lin(c):
    c = c / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


PALETA_LAB_LIN = _srgb_lin(PALETA_SRGB.astype(np.float64))


def salvar_png(caminho, rgb):
    caminho.parent.mkdir(parents=True, exist_ok=True)
    h, w, _ = rgb.shape
    out = oiio.ImageOutput.create(str(caminho))
    out.open(str(caminho), oiio.ImageSpec(w, h, 3, "uint8"))
    out.write_image(np.ascontiguousarray(rgb))
    out.close()


# ---------------------------------------------------------------- regiões clicáveis

# região -> objetos cuja projeção forma o retângulo (botão inteiro, com aro)
REGIOES = {
    "energia": ["energia_tela"],
    "oxigenio": ["oxigenio_tela"],
    "radiacao": ["radiacao_tela"],
    "comunicacao": ["comunicacao_tela"],
    "abrigo": ["abrigo_aro", "abrigo_anel", "abrigo_botao"],
    "estufa": ["estufa_moldura", "estufa_vidro"],
    "glovebox": ["glovebox_moldura", "glovebox_vidro", "glovebox_aro0", "glovebox_aro1"],
    "janela": list(JANELA_OBJS),
}
TELAS = ("energia", "oxigenio", "radiacao", "comunicacao")
BOTOES = ("abrigo", "estufa", "glovebox")
FAIXA_CLIQUE = (120, 250)
LARG_CIENCIA = 70              # estufa e glovebox: largura-alvo no panorama, em px
ZONA_LIVRE_X = (60, 1220)      # fora das setas de pan (~50 px em cada ponta da tela)


def pontos_do_objeto(nome, passos=8):
    """Vértices em coordenadas de mundo, mais pontos ao longo das arestas.

    Na câmera cilíndrica uma aresta reta a altura constante vira curva, então só os
    vértices poderiam subestimar o retângulo.
    """
    ob = bpy.data.objects[nome]
    m = np.array(ob.matrix_world)
    v = np.array([tuple(x.co) + (1.0,) for x in ob.data.vertices]) @ m.T
    v = v[:, :3]
    out = [v]
    t = np.linspace(0, 1, passos + 1)[1:-1, None]
    for e in ob.data.edges:
        a, b = v[e.vertices[0]], v[e.vertices[1]]
        out.append(a + (b - a) * t)
    return np.concatenate(out)


def projetar(pts, a, rad_px):
    """Mundo -> pixel do PNG, pela mesma câmera de configurar()."""
    d = pts - np.array(OLHO)
    yaw = math.radians(a.yaw)
    frente = d[:, 0] * math.sin(yaw) + d[:, 1] * math.cos(yaw)
    direita = d[:, 0] * math.cos(yaw) - d[:, 1] * math.sin(yaw)
    if a.camera == "cilindrica":
        az = np.arctan2(direita, frente)
        x = a.largura / 2 + az / rad_px
        y = a.altura / 2 - (d[:, 2] / np.hypot(direita, frente)) / rad_px
    else:
        x = a.largura / 2 + (direita / frente) / rad_px
        y = a.altura / 2 - (d[:, 2] / frente) / rad_px
    return x, y


def retangulo(pts_xy, largura, altura):
    x, y = pts_xy
    x0, x1 = int(np.floor(x.min())), int(np.ceil(x.max()))
    y0, y1 = int(np.floor(y.min())), int(np.ceil(y.max()))
    x0, y0 = max(x0, 0), max(y0, 0)
    x1, y1 = min(x1, largura), min(y1, altura)
    return {"x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0}


def calcular_regioes(a, rad_px):
    bpy.context.view_layer.update()
    out = {}
    for nome, objs in REGIOES.items():
        pts = np.concatenate([pontos_do_objeto(o) for o in objs])
        out[nome] = retangulo(projetar(pts, a, rad_px), a.largura, a.altura)
    return out


def validar_regioes(reg):
    """Confere as regras de layout. Devolve (linhas, ok)."""
    linhas, ok = [], True

    def checa(cond, msg):
        nonlocal ok
        linhas.append(f"  {'ok   ' if cond else 'FALHA'} {msg}")
        ok &= bool(cond)

    y_min, y_max = FAIXA_CLIQUE
    x_min, x_max = ZONA_LIVRE_X
    for n in BOTOES:
        r = reg[n]
        checa(y_min <= r["y"] and r["y"] + r["h"] <= y_max,
              f"{n}: faixa y {r['y']}..{r['y'] + r['h']} dentro de {y_min}..{y_max}")
        checa(r["w"] >= 24 and r["h"] >= 24, f"{n}: tamanho {r['w']}x{r['h']} px (mínimo 24x24)")
        checa(x_min <= r["x"] and r["x"] + r["w"] <= x_max,
              f"{n}: x {r['x']}..{r['x'] + r['w']} fora da zona das setas ({x_min}..{x_max})")
    for n in ("abrigo", "radiacao"):
        r = reg[n]
        checa(r["x"] + r["w"] <= 320, f"{n}: x {r['x']}..{r['x'] + r['w']} dentro de x<320")
    for n in ("energia", "oxigenio"):
        r = reg[n]
        checa(r["x"] >= 320 and r["x"] + r["w"] <= 960,
              f"{n}: x {r['x']}..{r['x'] + r['w']} dentro de 320..960")
    for n in ("estufa", "glovebox"):
        r = reg[n]
        checa(r["x"] >= 960, f"{n}: x {r['x']}..{r['x'] + r['w']} dentro de x>=960")
        # destaque da parede da ciência: bem maiores que o mínimo de 24 px, para a criança
        checa(r["w"] >= LARG_CIENCIA, f"{n}: largura {r['w']} px (alvo >= {LARG_CIENCIA})")
    e, g = reg["estufa"], reg["glovebox"]
    checa(g["x"] + g["w"] <= e["x"] or e["x"] + e["w"] <= g["x"],
          f"glovebox x {g['x']}..{g['x'] + g['w']} e estufa x {e['x']}..{e['x'] + e['w']} "
          f"não se sobrepõem")
    r = reg["comunicacao"]
    checa(r["x"] + r["w"] <= 420, f"comunicacao: x {r['x']}..{r['x'] + r['w']} até x<=420 (limite tolerado)")
    checa(r["w"] >= 70 and r["h"] >= 50,
          f"comunicacao: tamanho {r['w']}x{r['h']} px (alvo >= 70x50, cabe ícone e número)")
    r = reg["janela"]
    checa(r["x"] >= 320 and r["x"] + r["w"] <= 960,
          f"janela: x {r['x']}..{r['x'] + r['w']} no centro, dentro de 320..960")
    checa(r["w"] >= 400 and r["y"] < 90 and r["y"] + r["h"] > 190,
          f"janela: {r['w']}x{r['h']} px, larga e cruzando a altura do olho (y 180)")
    return linhas, ok


def conferir_projecao(reg, passes, estado):
    """Compara o retângulo projetado com o que o passe de índice mostra de fato."""
    print(f"[comodo] projeção x passe de índice ({estado}); objeto: retângulo projetado | visível")
    for nome, objs in REGIOES.items():
        mask = np.isin(passes["indice"], [INDICE[o] for o in objs])
        ys, xs = np.nonzero(mask)
        r = reg[nome]
        if not len(xs):
            print(f"[comodo]   {nome}: sem pixel visível")
            continue
        vis = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
        proj = (r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"])
        folga = max(abs(p - v) for p, v in zip(proj, vis))
        vis = tuple(int(v) for v in vis)
        print(f"[comodo]   {nome}: {proj} | {vis}  (maior diferença {int(folga)} px)")


def desenhar_regioes(rgb, reg):
    """Imagem de depuração em 2x: retângulos, faixa de clique (y 120..250) e as divisas x=320/960."""
    img = np.repeat(np.repeat(rgb, 2, 0), 2, 1).copy()
    cores = {"tela": (255, 255, 0), "botao": (255, 0, 255), "janela": (0, 255, 255)}
    for x in (320, 960):
        img[::6, x * 2] = (255, 255, 255)
    for y in FAIXA_CLIQUE:
        img[y * 2, ::6] = (255, 255, 255)
    for nome, r in reg.items():
        cor = cores["tela" if nome in TELAS else "janela" if nome == "janela" else "botao"]
        x0, y0, x1, y1 = r["x"] * 2, r["y"] * 2, (r["x"] + r["w"]) * 2 - 1, (r["y"] + r["h"]) * 2 - 1
        img[y0:y1 + 1, [x0, x0 + 1, x1 - 1, x1]] = cor
        img[[y0, y0 + 1, y1 - 1, y1], x0:x1 + 1] = cor
    return img


def salvar_png_rgba(caminho, rgba):
    caminho.parent.mkdir(parents=True, exist_ok=True)
    h, w, _ = rgba.shape
    out = oiio.ImageOutput.create(str(caminho))
    out.open(str(caminho), oiio.ImageSpec(w, h, 4, "uint8"))
    out.write_image(np.ascontiguousarray(rgba))
    out.close()


def main():
    a = args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    luzes = construir()
    rad_px = configurar(a)
    estados = [e for e in a.estados.split(",") if e]
    CACHE.mkdir(parents=True, exist_ok=True)
    (CACHE / ".gdignore").touch()
    saida = RAIZ / a.saida
    reg = calcular_regioes(a, rad_px)

    passes, pngs = {}, {}
    for estado in estados:
        aplicar_estado(estado, luzes)
        exr = CACHE / f"{estado}{a.sufixo}.exr"
        bpy.context.scene.render.filepath = str(exr)
        bpy.ops.render.render(write_still=True)
        p = ler_exr(exr)
        passes[estado] = p
        borda = contorno(p)
        pngs[estado] = pixel_art(p, borda, estado)
        salvar_png_rgba(saida / f"{estado}{a.sufixo}.png", pngs[estado])
        np.save(CACHE / f"{estado}{a.sufixo}_indice.npy", p["indice"])
        print(f"[comodo] {estado}: {saida / f'{estado}{a.sufixo}.png'}")

    (CACHE / "indices.json").write_text(json.dumps(INDICE, indent=1))

    # a geometria não pode mudar entre estados, salvo a persiana dentro do retângulo da janela:
    # profundidade, normal, índice e contorno idênticos fora dele (com 3 px de folga para o traço)
    j = reg["janela"]
    dentro = np.zeros((a.altura, a.largura), bool)
    dentro[max(j["y"] - 3, 0):j["y"] + j["h"] + 3, max(j["x"] - 3, 0):j["x"] + j["w"] + 3] = True
    base = estados[0]
    for e in estados[1:]:
        dz = np.abs(passes[e]["z"] - passes[base]["z"])
        dn = np.abs(passes[e]["normal"] - passes[base]["normal"]).max(-1)
        di = passes[e]["indice"] != passes[base]["indice"]
        db = contorno(passes[e]) != contorno(passes[base])
        fora = ~dentro
        print(f"[comodo] {base} x {e}: FORA da janela max|Δz|={dz[fora].max():.2e} "
              f"max|Δnormal|={dn[fora].max():.2e} px índice diferente={int(di[fora].sum())} "
              f"px contorno diferente={int(db[fora].sum())}")
        print(f"[comodo] {base} x {e}: DENTRO da janela (única diferença permitida, a persiana) "
              f"px índice diferente={int(di[dentro].sum())} px contorno diferente={int(db[dentro].sum())}")

    # vidro da janela: alpha 0 onde a persiana está aberta, tudo opaco no abrigo
    vidro_ok = True
    for e in estados:
        transp = pngs[e][..., 3] == 0
        ys, xs = np.nonzero(transp)
        esperado = e != "abrigo"
        fora = int((~dentro & transp).sum())
        print(f"[comodo] alpha 0 em {e}: {int(transp.sum())} px"
              + (f", x {xs.min()}..{xs.max()} y {ys.min()}..{ys.max()}, fora do retângulo da janela: {fora}" if len(xs) else ""))
        vidro_ok &= (transp.any() == esperado) and fora == 0
    print(f"[comodo] vidro transparente só com a persiana aberta: {'PASSA' if vidro_ok else 'FALHA'}")

    # regiões
    linhas, ok = validar_regioes(reg)
    print("[comodo] regiões (x, y, largura, altura em px do panorama):")
    for nome, r in reg.items():
        print(f"[comodo]   {nome}: {r['x']}, {r['y']}, {r['w']}x{r['h']}")
    print("[comodo] validação das regiões:")
    print("\n".join(linhas))
    print(f"[comodo] validação: {'PASSA' if ok else 'FALHA'}")
    conferir_projecao(reg, passes[base], base)
    fundo_vidro = np.where(pngs[base][..., 3:4] > 0, pngs[base][..., :3], np.array([32, 96, 160], np.uint8))
    salvar_png(CACHE / "regioes_debug.png", desenhar_regioes(fundo_vidro.astype(np.uint8), reg))
    print(f"[comodo] depuração: {CACHE / 'regioes_debug.png'}")

    # tamanho em px dos botões na escala 1x (a região inclui o aro)
    for nome in BOTOES + ("comunicacao",):
        print(f"[comodo] {nome}: {reg[nome]['w']}x{reg[nome]['h']} px")
    print(f"[comodo] rad_por_px={rad_px:.6f} câmera={a.camera} yaw={a.yaw}")

    doc = {
        "formato": "x, y, w, h em px do PNG; origem no canto superior esquerdo",
        "panorama": {"largura": a.largura, "altura": a.altura, "graus": a.graus,
                     "faixa_de_clique_y": list(FAIXA_CLIQUE),
                     "cor_das_telas_em_branco": "#" + COR_TELA_APAGADA,
                     "arquivos": [f"{e}.png" for e in ESTADOS]},
        "telas": {n: reg[n] for n in TELAS},
        "botoes": {n: reg[n] for n in BOTOES},
        "janela": reg["janela"],
        "vista_janela": {
            "arquivos": {"normal": "assets/exterior/vista_janela_normal.png",
                         "poeira": "assets/exterior/vista_janela_poeira.png"},
            "nota": "1280x360, mesma câmera do panorama; vai atrás dele. O vidro do panorama "
                    "tem alpha 0, menos no estado abrigo (persiana fechada)."},
    }

    (saida / f"regioes{a.sufixo}.json").write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n")
    print(f"[comodo] regiões: {saida / f'regioes{a.sufixo}.json'}")


if __name__ == "__main__":
    main()
