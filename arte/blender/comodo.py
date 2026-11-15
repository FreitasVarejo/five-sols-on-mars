"""Gera o módulo de comando do zero e renderiza um PNG em pixel art por estado.

Uso (da raiz do repo):
    blender -b --factory-startup -P $PWD/arte/blender/comodo.py
    blender -b --factory-startup -P $PWD/arte/blender/comodo.py -- --estados normal
(o `blender` do PATH é o Flatpak: passe o script por caminho absoluto.)

Fonte da verdade: este script. Nenhum .blend é salvo nem lido.
Mesma câmera em todos os estados. A geometria também é a mesma, com duas exceções permitidas:
a persiana da janela, que só o estado `abrigo` fecha, e a alavanca do abrigo, que fica embaixo
em `abrigo` e `abrigo_aberto` e em cima nos outros estados (a placa, a fenda e o pino são os
mesmos; muda só o braço, com o punho). O estado muda luz e emissão.
A persiana fica dentro do vão da janela, entre a moldura de aço e o vidro, com a largura exata
do vão: a moldura e o montante central a tapam e continuam visíveis por cima dela. Há o estado
extra `abrigo_aberto`: a mesma luz e emissão do `abrigo`, sem a persiana e com o vidro em alpha 0.
A alavanca está embaixo nos dois. Ele não entra no padrão de `--estados` (renderize com
`--estados abrigo,abrigo_aberto`);
scripts/gerar_persiana.py usa a diferença entre `abrigo` e `abrigo_aberto` como a camada da
persiana.

Os PNGs da sala com a alavanca (15/11) não são o render cru: são o render só na região de repintura
da alavanca (x 154..271, y 131..257), colado sobre os PNGs anteriores por scripts/compor_sala.py,
que leva a região, a tabela de cor do pilar e a prova de que fora dela os PNGs ficam idênticos. O
render inteiro muda o tom do pilar na tempestade e uns pixels longe do objeto. Depois do render:
`scripts/compor_sala.py --render <pasta do --saida> --regiao 154 131 272 258`, depois
scripts/gerar_persiana.py. O `--saida` tem de ficar dentro do repo (o Blender é um Flatpak).

Arte final, não mais gray-box: o casco tem placas com juntas, meia-parede, friso, rodapé, calha
em trechos, teto em placas e uma grade de ventilação; a glovebox e a estufa têm miolo com luz
própria (luvas, tubo de amostra, alface); o console tem teclado, gaveteiro e caneca, e o pilar da
Terra, antena de prato e fone. Na imagem, cada face plana de cada objeto resolve em dois tons
(o dela e a sombra), um filtro de maioria tira o pixel solto, e o verde, o azul e o rosa da
paleta só aparecem nos objetos que têm esse sentido no jogo (pixel_art).

A janela larga do centro não leva vista assada: o vidro sai com alpha 0 no PNG (menos no
`abrigo`, onde a persiana o cobre) e o Godot põe a vista de Marte atrás, por composição. A vista
vem do exterior.py, que usa a mesma câmera (OLHO, PANORAMA) deste script. O vidro não ilumina a
sala, e o traço dele e as faces internas da moldura saem em neutro escuro (COR_AROS_JANELA): o
Godot escurece a vista no pôr do Sol e à noite.

Além dos PNGs do panorama, grava assets/comodo/regioes.json (retângulos dos botões e telas,
calculados pela projeção real da câmera sobre os vértices). Botões: abrigo (a alavanca: o retângulo
da união das duas posições), estufa, glovebox e porta (a porta do dormitório, na ponta esquerda:
tocá-la encerra o sol). Telas: energia, oxigenio, radiacao e comunicacao (a tela da Terra, apagada: quem a acende é o Godot). Desenho: porta_lampada,
a lâmpada verde da porta, para o Godot acendê-la ou apagá-la por cima do render (o indicador de
"pode dormir"). Região de desenho é o retângulo do que o passe de índice mostra de fato (justo, sem
a folga da projeção), porque o Godot a pinta por cima do render. O terminal não é render: é camada de tela no Godot.
Uma imagem de depuração com os retângulos fica em arte/blender/.render/regioes_debug.png.

Vista de perto (`-- --perto estufa,glovebox`): a peça da planta e a da amostra abrem numa imagem da própria
estação, vista de frente por uma câmera em perspectiva (640x360, só o estado normal). Mesma cena
(construir) e mesmo pipeline (pixel_art), com o miolo que fica atrás do vidro escondido: a peça do
Godot desenha o interior. O vidro da câmara sai com alpha 0 no PNG, como o da janela, e o Godot põe
a peça ATRÁS do PNG, no maior retângulo inscrito nessa região (calculado pela máscara do vidro, sem
o traço do contorno). O que fica na frente do vidro (aros e bocas das luvas) continua no render e
encolhe o retângulo. Grava assets/comodo/perto_<estacao>.png e a chave "perto" de regioes.json (o
resto do arquivo e os PNGs do panorama não mudam) e, em arte/blender/.render/, perto_<estacao>_debug.png
(2x, com o retângulo da peça, a faixa do HUD, o botão de voltar e o de mudo).

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
from mathutils import Matrix, Vector

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
    p.add_argument("--perto", default="",
                   help="estações da vista de perto (estufa, glovebox); só elas são renderizadas")
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

# trechos (metros) da calha e da faixa de parede acima dela: na frente em x, nos lados em y
TRECHOS_FRENTE = ((-2.6, -1.95), (-1.95, -1.3), (-1.3, -0.65), (-0.65, 0.0), (0.0, 0.65),
                  (0.65, 1.3), (1.3, 1.95), (1.95, 2.6))
TRECHOS_LADO = ((-1.0, 0.0), (0.0, 0.75), (0.75, 1.5), (1.5, 2.2))

COR_TELA_APAGADA = "202e37"          # cor única das telas em branco (Apollo)
TELAS_APAGADAS = ("energia_tela", "oxigenio_tela", "radiacao_tela", "comunicacao_tela")
AZUL_TERRA = "73bed3"                # azul é só do que vem da Terra (moldura da tela de comunicação)
COR_AROS_JANELA = "151d28"           # traço do vidro e faces internas da moldura, em todo estado
PERSIANA = []                        # objetos da persiana; só o estado abrigo os renderiza
GLOVEBOX_C = (2.087, 1.466)          # (x, y) do painel da glovebox e o da estufa, no chão
ESTUFA_C = (2.315, 0.66)
# Braço e punho da alavanca do abrigo, nas duas posições: só um par é renderizado por estado.
# Embaixo (abrigo ativo) em `abrigo` e `abrigo_aberto`; em cima nos outros estados.
ALAVANCA = {"cima": [], "baixo": []}
ESTADOS_ABRIGADOS = ("abrigo", "abrigo_aberto")
ALAVANCA_Z = 1.12                    # altura do pino, centro da placa
ALAVANCA_CURSO = 0.17                # do pino ao centro do punho (a barra em T), para cima ou para baixo


def botao(nome, cor):
    """Material de botão: a cor vem da emissão; o difuso escuro e sem especular não estoura."""
    mb = material(nome, tuple(c * 0.35 for c in hexrgb(cor)), 0.9)
    mb.node_tree.nodes["Principled BSDF"].inputs["Specular IOR Level"].default_value = 0.0
    COR_BOTAO[nome] = hexrgb(cor)
    return mb


def mat(nome, hexa, emite=False):
    """Material pelo nome, criado na primeira vez. `emite`: cor chapada de emissão, igual em
    todos os estados (o miolo das câmaras de ciência, como as telas)."""
    if nome not in MATS:
        if emite:
            tela_apagada(nome, hexa)
        else:
            material(nome, hexrgb(hexa))
    return MATS[nome]


def disco(nome, centro, rx, rz, espessura, mat_, indice, eixo, giro=0.0, segs=20):
    """Elipse de rx por rz (metros), com espessura, de face para `eixo`; `giro` (graus) a gira no
    próprio plano, no sentido anti-horário de quem olha. rz é a medida que fica em pé."""
    me = bpy.data.meshes.new(nome)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=1.0, radius2=1.0,
                          depth=espessura)
    for v in bm.verts:
        v.co.x *= rx
        v.co.y *= rz
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0),
                     matrix=Matrix.Rotation(math.radians(giro), 3, "Z"))
    bm.to_mesh(me)
    bm.free()
    ob = _objeto(nome, me, mat_, indice)
    ob.location = centro
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = Vector(eixo).to_track_quat("Z", "Y")
    return ob


def apontar(ob, eixo):
    """Gira o objeto para o eixo z local seguir `eixo`."""
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = Vector(eixo).normalized().to_track_quat("Z", "Y")
    return ob


def _faixas_de_parede(i, nome, eixo, plano, trechos, z0, z1, recuo, mat_):
    """Placas encostadas na parede, uma por trecho, cada uma com índice próprio (a junta sai
    do contorno). eixo 'x': parede da frente (trechos em x); 'y': paredes laterais (em y).
    plano: a coordenada da face da parede; recuo: espessura da placa, para dentro da sala."""
    lado = 1 if plano > 0 else -1
    for k, (a0, a1) in enumerate(trechos):
        meio, larg = (a0 + a1) / 2, a1 - a0
        c = plano - lado * recuo / 2
        if eixo == "x":
            caixa(f"{nome}{k}", (meio, c, (z0 + z1) / 2), (larg, recuo, z1 - z0), mat_, next(i))
        else:
            caixa(f"{nome}{k}", (c, meio, (z0 + z1) / 2), (recuo, larg, z1 - z0), mat_, next(i))


def _paredes(i, W, F):
    """Casco com cara de módulo: placas de 1,5 cm com juntas na metade de cima e na faixa acima
    da calha, meia-parede um tom mais escura embaixo, friso entre as duas, rodapé e o teto em
    placas. Tudo entra em RECUO (prefixos `parede_` e `teto_`): o traço entre essas peças é
    meio-tom. Nada encosta na janela nem na porta.
    Um só grupo de detalhe médio em parede livre: a grade de ventilação entre a janela e a
    glovebox, no alto, longe dos clicáveis."""
    placa = mat("parede_placa", "8a9f9e")
    baixa = mat("parede_baixa", "5f7778")
    rodape = mat("parede_rodape", "394a50")
    friso = MATS["nervura"]
    zc = (0.86, 1.97)          # placas de cima: do friso até a calha
    zb = (0.13, 0.845)         # meia-parede: do rodapé até o friso
    frente_cima = ((-W, -2.0), (-2.0, -1.40), (1.40, 2.0), (2.0, W))
    frente_baixo = ((-W, -1.8), (-1.8, -0.9), (-0.9, 0.0), (0.0, 0.9), (0.9, 1.8), (1.8, W))
    esq = ((1.07, 2.0), (2.0, F))       # a porta vai até y 1,07
    dir_ = ((0.0, 1.0), (1.0, 2.0), (2.0, F))
    _faixas_de_parede(i, "parede_placa_f", "x", F, frente_cima, *zc, 0.015, placa)
    _faixas_de_parede(i, "parede_placa_e", "y", -W, esq, *zc, 0.015, placa)
    _faixas_de_parede(i, "parede_placa_d", "y", W, dir_, *zc, 0.015, placa)
    _faixas_de_parede(i, "parede_alta_f", "x", F, TRECHOS_FRENTE, 2.11, 2.4, 0.015, placa)
    _faixas_de_parede(i, "parede_alta_e", "y", -W, TRECHOS_LADO, 2.11, 2.4, 0.015, placa)
    _faixas_de_parede(i, "parede_alta_d", "y", W, TRECHOS_LADO, 2.11, 2.4, 0.015, placa)
    _faixas_de_parede(i, "parede_baixa_f", "x", F, frente_baixo, *zb, 0.02, baixa)
    _faixas_de_parede(i, "parede_baixa_e", "y", -W, esq, *zb, 0.02, baixa)
    _faixas_de_parede(i, "parede_baixa_d", "y", W, dir_, *zb, 0.02, baixa)
    for nome, z0, z1, recuo, m in (("parede_friso", 0.845, 0.86, 0.035, friso),
                                   ("parede_rodape", 0.0, 0.13, 0.035, rodape)):
        _faixas_de_parede(i, f"{nome}_f", "x", F, ((-W, W),), z0, z1, recuo, m)
        _faixas_de_parede(i, f"{nome}_e", "y", -W, ((1.07, F),), z0, z1, recuo, m)
        _faixas_de_parede(i, f"{nome}_d", "y", W, ((-1.0, F),), z0, z1, recuo, m)

    # teto em placas de 1 cm, cada uma com índice próprio: o teto só aparece nos cantos de cima,
    # e cada placa resolve num tom, em degraus, em vez de uma mancha só
    teto = mat("teto_placa", "a8b5b2")
    xs, ys = (-W, -1.3, 0.0, 1.3, W), (-1.0, 0.0, 0.75, 1.5, F)
    for a in range(4):
        for b in range(4):
            caixa(f"teto_placa{a}{b}", ((xs[a] + xs[a + 1]) / 2, (ys[b] + ys[b + 1]) / 2, 2.395),
                  (xs[a + 1] - xs[a], ys[b + 1] - ys[b], 0.01), teto, next(i))

    # grade de ventilação: aro e ripas largas (passo de ~10 px no panorama, nunca 1 px)
    gx, gz, gl, ga = 1.70, 1.66, 0.36, 0.30
    caixa("parede_grade", (gx, F - 0.025, gz), (gl, 0.02, ga), MATS["nervura"], next(i))
    for k in range(4):
        caixa(f"parede_grade_ripa{k}", (gx, F - 0.04, gz - 0.10 + k * 0.066),
              (gl - 0.06, 0.02, 0.034), rodape, next(i))


def _antena(i, t):
    """Antena em cima do pilar da Terra: um prato pequeno inclinado para cima e para o olho,
    com o alimentador na frente (só enfeite; o ícone da Terra vem na tela, pelo Godot)."""
    claro = mat("metal_claro", "c7cfcc")
    escuro = mat("metal_escuro", "394a50")
    t.caixa("comunicacao_suporte_antena", 0.10, 0.0, 1.775, 0.16, 0.14, 0.07, escuro, next(i))
    cilindro("comunicacao_mastro", t.pos(0.10, 0.0, 1.85), 0.022, 0.10, escuro, next(i), segs=12)
    olho = Vector((-t.f[0], -t.f[1], 0.0))
    lado = Vector((t.u[0], t.u[1], 0.0))
    eixo = (Vector((0, 0, 1)) * 0.8 + olho * 0.55 - lado * 0.35).normalized()
    centro = Vector(t.pos(0.10, 0.0, 1.92))
    me = bpy.data.meshes.new("comunicacao_prato")
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, segments=24, radius1=0.03, radius2=0.12,
                          depth=0.045)
    bm.to_mesh(me)
    bm.free()
    prato = _objeto("comunicacao_prato", me, claro, next(i))
    prato.location = centro
    apontar(prato, eixo)
    haste = cilindro("comunicacao_alimentador", tuple(centro + eixo * 0.07), 0.011, 0.11,
                     escuro, next(i), segs=8)
    apontar(haste, eixo)
    ponta = caixa("comunicacao_corneta", tuple(centro + eixo * 0.13), (0.04, 0.04, 0.03),
                  escuro, next(i))
    apontar(ponta, eixo)


def _fone(i, t):
    """Toque humano: um fone de ouvido pendurado num gancho do pilar da Terra, embaixo da tela."""
    escuro = mat("metal_escuro", "394a50")
    almofada = mat("almofada", "202e37")
    ac, zc, d = 0.0, 0.88, 0.16
    t.caixa("fone_gancho", ac, d, zc + 0.10, 0.05, 0.03, 0.03, escuro, next(i))
    ix = next(i)
    r = 0.075
    for k in range(7):                       # o arco de cima, em gomos
        th = math.radians(180 * k / 6)
        caixa(f"fone_arco{k}", t.pos(ac + r * math.cos(th), d + 0.005, zc + r * math.sin(th)),
              (0.035, 0.02, 0.02), escuro, ix, rot=(0, -math.degrees(th) - 90, t.yaw))
    for k, s in enumerate((-1, 1)):
        t.cil(f"fone_concha{k}", ac + s * r, d + 0.012, zc - 0.02, 0.045, 0.025, almofada,
              next(i), segs=16)


def _glovebox(i, g):
    """Miolo da glovebox: a câmara (fundo e chão mais escuros que o vidro, que fica como uma
    borda clara), a barra de luz neutra, as bocas das luvas com anel e punho, as duas luvas
    erguidas por dentro, o tubo de amostra num suporte, cantoneiras e a faixa de comandos."""
    fundo = mat("glovebox_fundo", "25562e", emite=True)
    chao = mat("glovebox_chao", "19332d", emite=True)
    luz = mat("luz_interna", "ebede9", emite=True)
    # o que fica dentro da câmara é iluminado pela barra de luz dela, não pela sala: emissão
    # chapada, igual em todos os estados (como o vidro), e a glovebox se lê no escuro também
    luva = mat("luva", "819796", emite=True)
    borracha = mat("borracha", "394a50")
    escuro = MATS["moldura"]
    cantoneira = mat("cantoneira", "819796")
    tecla = mat("tecla", "a8b5b2")
    tubo = mat("tubo", "c7cfcc", emite=True)
    amostra = mat("amostra", "ad7757", emite=True)         # regolito de Marte
    tampa = mat("tampa_tubo", "202e37", emite=True)
    suporte = mat("suporte_tubo", "151d28", emite=True)
    olho = (-g.f[0], -g.f[1], 0.0)

    # o vidro (glovebox_vidro) tem a face em d = 0,23: o miolo fica logo à frente dela
    g.caixa("glovebox_fundo", 0, 0.2315, 1.17, 0.60, 0.002, 0.44, fundo, next(i))
    g.caixa("glovebox_chao", 0, 0.2325, 0.985, 0.60, 0.002, 0.07, chao, next(i))
    g.caixa("glovebox_luz", 0, 0.2335, 1.37, 0.50, 0.002, 0.03, luz, next(i))

    for k, s in enumerate((-1, 1)):
        a = s * 0.18
        # luva: manga que sai da boca, mão (luva de forno) e polegar para dentro
        ix = next(i)
        g.caixa(f"glovebox_manga{k}", a, 0.235, 1.09, 0.09, 0.002, 0.18, luva, ix)
        disco(f"glovebox_mao{k}", g.pos(a + s * 0.005, 0.236, 1.195), 0.056, 0.058, 0.002, luva,
              ix, olho)
        disco(f"glovebox_polegar{k}", g.pos(a - s * 0.055, 0.236, 1.21), 0.02, 0.042, 0.002,
              luva, ix, olho, giro=s * 35)
        # boca: aro de aço (glovebox_aro, nas regiões), anel, punho de borracha e o furo
        g.cil(f"glovebox_anel{k}", a, 0.258, 0.99, 0.100, 0.03, cantoneira, next(i))
        g.cil(f"glovebox_punho{k}", a, 0.27, 0.99, 0.082, 0.03, borracha, next(i))
        g.cil(f"glovebox_boca{k}", a, 0.282, 0.99, 0.052, 0.03, escuro, next(i))

    # tubo de amostra deitado num suporte, acima das mãos
    g.caixa("glovebox_suporte", 0, 0.237, 1.235, 0.24, 0.002, 0.02, suporte, next(i))
    # um índice por peça: com índice comum, as facetas de mesma normal do vidro e da amostra
    # viravam uma face só no tons_por_face e as cores se misturavam
    for nome, da, raio, comp, m in (("glovebox_tubo", 0.0, 0.045, 0.34, tubo),
                                    ("glovebox_liquido", -0.06, 0.047, 0.15, amostra),
                                    ("glovebox_tampa", 0.18, 0.05, 0.05, tampa)):
        cilindro(nome, g.pos(da, 0.29, 1.29), raio, comp, m, next(i), rot=(0, 90, g.yaw),
                 segs=16)

    # cantoneiras nos cantos da moldura e a faixa de comandos na base
    for k, (a, z) in enumerate(((-0.36, 0.835), (0.36, 0.835), (-0.36, 1.465), (0.36, 1.465))):
        g.caixa(f"glovebox_cantoneira{k}", a, 0.222, z, 0.05, 0.006, 0.04, cantoneira, next(i))
    g.caixa("glovebox_comandos", 0, 0.205, 0.66, 0.48, 0.012, 0.13, MATS["painel_console"],
            next(i))
    for k, a in enumerate((-0.165, -0.055, 0.055, 0.165)):
        g.caixa(f"glovebox_tecla{k}", a, 0.214, 0.66, 0.07, 0.012, 0.05, tecla, next(i))


def _estufa(i, e, pz):
    """Miolo da estufa: câmara de cultivo com fundo escuro, bandeja de solo, uma alface (roseta
    de folhas) como protagonista e um broto ao lado, sob a barra de LED rosa (estufa_luz). Embaixo,
    a porta do armário com puxador."""
    # como na glovebox, o miolo tem luz própria (a do LED): emissão chapada em todos os estados
    fundo = mat("estufa_fundo", "19332d", emite=True)
    bandeja = mat("bandeja", "577277", emite=True)
    solo = mat("solo", "7a4841", emite=True)
    escura = mat("folha_escura", "468232", emite=True)
    folha = mat("folha", "75a743", emite=True)
    clara = mat("folha_clara", "a8ca58", emite=True)
    olho = (-e.f[0], -e.f[1], 0.0)

    e.caixa("estufa_fundo", 0, 0.247, pz, 0.40, 0.002, 0.50, fundo, next(i))
    e.caixa("estufa_bandeja", 0, 0.252, 0.955, 0.40, 0.006, 0.05, bandeja, next(i))
    e.caixa("estufa_solo", 0, 0.251, 1.0, 0.36, 0.006, 0.045, solo, next(i))

    ac, zb = -0.04, 1.005
    # (camada, a, z, rx, rz, giro): de trás para a frente, do escuro para o claro
    folhas = (
        (escura, -0.10, 0.08, 0.075, 0.042, -28), (escura, 0.10, 0.08, 0.075, 0.042, 28),
        (escura, 0.0, 0.13, 0.05, 0.07, 0),
        (folha, -0.07, 0.055, 0.065, 0.04, -15), (folha, 0.07, 0.055, 0.065, 0.04, 15),
        (folha, 0.0, 0.08, 0.05, 0.055, 0),
        (clara, 0.0, 0.05, 0.035, 0.032, 0),
    )
    for k, (m, a, z, rx, rz, giro) in enumerate(folhas):
        disco(f"estufa_folha{k}", e.pos(ac + a, 0.256 + 0.003 * k, zb + z), rx, rz, 0.003, m,
              next(i), olho, giro=giro)
    # broto ao lado
    ab = 0.15
    e.caixa("estufa_broto_caule", ab, 0.256, zb + 0.03, 0.016, 0.003, 0.06, folha, next(i))
    for k, s in enumerate((-1, 1)):
        disco(f"estufa_broto{k}", e.pos(ab + s * 0.025, 0.258, zb + 0.065), 0.028, 0.014, 0.003,
              folha, next(i), olho, giro=s * 25)

    porta = mat("porta_armario", "a8b5b2")
    e.caixa("estufa_armario", 0, 0.205, 0.46, 0.56, 0.01, 0.72, porta, next(i))
    e.caixa("estufa_puxador", 0, 0.215, 0.76, 0.18, 0.025, 0.03, MATS["painel_console"], next(i))


def _console(i):
    """Bancada: gaveteiro na ponta direita, entre a bancada e a base da glovebox; um teclado na
    ponta esquerda e a caneca na direita (toque humano). O meio da bancada fica fora do quadro."""
    console = MATS["console"]
    claro = mat("console_claro", "577277")
    escuro = MATS["painel_console"]
    caixa("console_gaveteiro", (1.54, 1.99, 0.31), (0.32, 0.38, 0.62), console, next(i))
    for k, z in enumerate((0.45, 0.17)):
        caixa(f"console_gaveta{k}", (1.54, 1.795, z), (0.28, 0.012, 0.25), claro, next(i))
        caixa(f"console_puxador{k}", (1.54, 1.785, z + 0.07), (0.12, 0.012, 0.025), escuro,
              next(i))
    k = Painel(-1.08, 1.42)
    k.caixa("console_teclado", 0, 0, BANCADA_Z + 0.015, 0.40, 0.16, 0.03, escuro, next(i))
    for n in range(5):
        k.caixa(f"console_tecla{n}", -0.14 + n * 0.07, 0.03, BANCADA_Z + 0.035, 0.05, 0.05,
                0.012, mat("tecla_teclado", "819796"), next(i))
    caneca = mat("caneca", "c7cfcc")
    cx, cy = 1.15, 1.36
    cilindro("caneca", (cx, cy, BANCADA_Z + 0.05), 0.042, 0.10, caneca, next(i), rot=(0, 0, 0),
             segs=16)
    cilindro("caneca_cafe", (cx, cy, BANCADA_Z + 0.0975), 0.034, 0.006, mat("cafe", "4d2b32"),
             next(i), segs=16)
    caixa("caneca_alca", (cx + 0.05, cy, BANCADA_Z + 0.055), (0.02, 0.012, 0.05), caneca, next(i))


def construir():
    """Módulo de comando, pronto para o render. Unidades em metros; o olho fica em OLHO.

    Esquerda (x<320 no panorama): porta, suporte de vida com a tela de radiação e a alavanca
    do abrigo; na parede da frente, a tela de comunicação com a Terra (apagada, moldura azul),
    com a antena em cima e um fone pendurado embaixo.
    Centro (320-960): a janela larga para Marte e, abaixo dela, a rampa com as telas de energia
    e oxigênio e a bancada (teclado, caneca e gaveteiro nas pontas). Direita (>960): a parede da
    ciência de dentro, com a glovebox e a estufa lado a lado, em destaque.
    Todo botão clicável fica entre x 60 e 1220 (ZONA_LIVRE_X), fora das setas de pan do jogo.
    Este corpo monta o casco, a janela, as telas, a porta e os objetos das regiões; o resto vem
    das funções por área: _paredes, _antena, _fone, _glovebox, _estufa e _console.
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

    # calha de cabos: linha reta longa em todas as paredes, a 2,05 m, em trechos (cada trecho com
    # índice próprio resolve num tom; inteira, a luz que cai ao longo dela virava uma cunha)
    for k, (a0, a1) in enumerate(TRECHOS_FRENTE):
        caixa(f"calha_frente{k}", ((a0 + a1) / 2, F - 0.1, 2.05), (a1 - a0, 0.2, 0.12), nervura,
              next(i))
    for k, (a0, a1) in enumerate(TRECHOS_LADO):
        for nome, x in (("esq", -W + 0.1), ("dir", W - 0.1)):
            caixa(f"calha_{nome}{k}", (x, (a0 + a1) / 2, 2.05), (0.2, a1 - a0, 0.12), nervura,
                  next(i))

    # luminárias no teto
    for y in (0.6, 1.6):
        caixa(f"luminaria_{y}", (0, y, H - 0.03), (1.6, 0.25, 0.06), luminaria, next(i))

    _paredes(i, W, F)

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
    vidro = caixa("janela", (0.0, F - 0.02, jc), (jl, 0.01, jz1 - jz0), janela, next(i))
    # a emissão do vidro só serve à câmera: não ilumina nem tinge a sala (a luz que entra pela
    # janela é a do Godot, que escurece a vista no pôr do Sol e à noite)
    vidro.visible_diffuse = vidro.visible_glossy = vidro.visible_transmission = False
    vidro.visible_volume_scatter = False
    pitch = (jz1 - jz0) / N_PERSIANA
    for k in range(N_PERSIANA):
        mat_s = faixa if k in (0, N_PERSIANA - 1) else blindagem
        # dentro do vão: atrás da moldura (F-0,10 a F), na frente do vidro (F-0,02), na largura dele
        PERSIANA.append(caixa(f"persiana_{k}", (0.0, F - 0.06, jz0 + (k + 0.5) * pitch),
                              (jl, 0.03, pitch + 0.004), mat_s, next(i)))

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
    # e a alavanca do abrigo embaixo: placa de aro amarelo, fenda escura, pino cinza e, no braço de aço,
    # o punho em T, uma barra vermelha (a cor do alerta que pede o abrigo) atravessada na ponta do braço
    # e mais larga que a fenda, como o punho de incêndio de um avião. Em cima, o abrigo está desligado;
    # embaixo, ativo. O braço sai do pino para a posição do estado: ver ALAVANCA e aplicar_estado.
    s = Painel(-2.14, 1.235)
    s.caixa("suporte_base", 0, 0, 0.06, 0.95, 0.42, 0.12, moldura, next(i))
    s.caixa("suporte_corpo", 0, 0, 1.05, 0.85, 0.30, 1.86, console, next(i))
    s.caixa("radiacao_moldura", 0, 0.17, 1.72, 0.80, 0.04, 0.50, moldura, next(i))
    s.caixa("radiacao_tela", 0, 0.195, 1.72, 0.72, 0.01, 0.42, ecra, next(i))
    botao("botao_abrigo", "cf573c")
    aco = mat("alavanca_aco", "a8b5b2")
    pino = mat("alavanca_pino", "577277")
    s.caixa("abrigo_aro", 0, 0.175, ALAVANCA_Z, 0.34, 0.05, 0.54, amarelo, next(i))
    s.caixa("abrigo_fenda", 0, 0.20, ALAVANCA_Z, 0.14, 0.03, 0.48, moldura, next(i))
    s.cil("abrigo_pino", 0, 0.23, ALAVANCA_Z, 0.03, 0.03, pino, next(i))
    for pos, sinal in (("cima", 1), ("baixo", -1)):
        zc = ALAVANCA_Z + sinal * ALAVANCA_CURSO
        ALAVANCA[pos] += [
            s.caixa(f"abrigo_braco_{pos}", 0, 0.225, ALAVANCA_Z + sinal * ALAVANCA_CURSO / 2,
                    0.035, 0.03, ALAVANCA_CURSO, aco, next(i)),
            # o T: 0,20 x 0,048 m, uns 33 x 8 px no panorama, 3 cm mais largo que a fenda de cada lado
            s.caixa(f"abrigo_punho_{pos}", 0, 0.25, zc, 0.20, 0.035, 0.048, MATS["botao_abrigo"],
                    next(i)),
        ]

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
    _antena(i, t)
    _fone(i, t)

    # ---- direita: a parede da ciência de dentro, com a estufa (cultivar planta) e a glovebox
    # (selar a amostra), lado a lado e voltadas para o olho. São os dois objetos maiores e mais
    # claros da parede: moldura clara e uma faixa de luz própria cada. Verde só no que se clica
    # (o vidro e a planta). Tudo clicável fica entre x 60 e 1220 do panorama (as setas de pan
    # cobrem as pontas) e na faixa y 120..250.
    vidro_gb = tela_apagada("vidro_glovebox", "468232")

    g = Painel(*GLOVEBOX_C)
    g.caixa("glovebox_base", 0, 0, 0.40, 0.70, 0.40, 0.80, console, next(i))
    g.caixa("glovebox_moldura", 0, 0.05, 1.15, 0.78, 0.34, 0.68, caixa_c, next(i))
    g.caixa("glovebox_vidro", 0, 0.225, 1.17, 0.68, 0.01, 0.52, vidro_gb, next(i))
    for k, da in enumerate((-0.18, 0.18)):                  # as bocas das luvas: o aro de aço
        g.cil(f"glovebox_aro{k}", da, 0.24, 0.99, 0.115, 0.03, moldura, next(i))
    _glovebox(i, g)

    e = Painel(*ESTUFA_C)
    e.caixa("estufa_corpo", 0, 0, 0.88, 0.66, 0.40, 1.76, caixa_c, next(i))
    pz = 1.18
    e.caixa("estufa_moldura", 0, 0.22, pz, 0.54, 0.04, 0.66, moldura, next(i))
    e.caixa("estufa_vidro", 0, 0.24, pz, 0.46, 0.01, 0.58, vidro_estufa, next(i))
    e.caixa("estufa_luz", 0, 0.25, pz + 0.255, 0.40, 0.02, 0.05, luz_cultivo, next(i))
    _estufa(i, e, pz)

    _console(i)

    # alarmes nos cantos de cima da frente
    for x in (-2.3, 2.3):
        cilindro(f"alarme_{x}", (x, F - 0.12, 2.25), 0.09, 0.14, alarme, next(i), rot=(90, 0, 0))

    # luzes (energia e cor mudam por estado)
    luzes = {}
    # luz do teto larga e recuada da parede da frente: a parede recebe luz quase por igual, sem
    # foco no alto (o foco virava mancha no tons_por_face)
    for nome, loc, tam in (("luz_teto", (0, 0.7, H - 0.1), (3.0, 1.4)),):
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
    """Só luz e emissão, a persiana da janela (no abrigo) e a posição da alavanca do abrigo.
    Nada de material base ou câmera."""
    branco = hexrgb("ebede9")
    ambar = hexrgb("de9e41")
    vermelho = hexrgb("cf573c")
    verde = hexrgb("75a743")

    # (cor, energia W) por luz; (cor, força) por emissão
    E = {
        "normal": dict(
            luz_teto=(branco, 150), luz_console=25, luz_porta=(verde, 0),
            alarme=(vermelho, 0), luz_alarme=(vermelho, 0), luminaria=(branco, 6),
            telas=1.0, janela=1.2, botoes=0.8, lampada_porta=(verde, 0.5), mundo=0.02),
        "tempestade": dict(
            luz_teto=(ambar, 90), luz_console=25, luz_porta=(verde, 0),
            alarme=(vermelho, 12), luz_alarme=(vermelho, 60), luminaria=(ambar, 2),
            telas=1.0, janela=0.25, botoes=1.0, lampada_porta=(ambar, 3), mundo=0.01),
        "abrigo": dict(
            luz_teto=(branco, 30), luz_console=10, luz_porta=(verde, 80),
            alarme=(vermelho, 0), luz_alarme=(vermelho, 0), luminaria=(branco, 1),
            telas=0.7, janela=0.6, botoes=0.8, lampada_porta=(verde, 8), mundo=0.01),
        "modo_seguranca": dict(
            luz_teto=(vermelho, 25), luz_console=0, luz_porta=(verde, 0),
            alarme=(vermelho, 4), luz_alarme=(vermelho, 15), luminaria=(vermelho, 0.5),
            telas=0.0, janela=0.4, botoes=0.0, lampada_porta=(vermelho, 2), mundo=0.005),
    }["abrigo" if estado == "abrigo_aberto" else estado]

    def luz(nome, cor_energia):
        luzes[nome].color, luzes[nome].energy = cor_energia

    luz("luz_teto", E["luz_teto"])
    # a luz do console é neutra: leva a cor da luz do teto, sem tingir a parede de azul
    luz("luz_console", (E["luz_teto"][0], E["luz_console"]))
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
    for ob in PERSIANA:                  # diferença de geometria entre estados (1 de 2)
        ob.hide_render = estado != "abrigo"  # (abrigo_aberto também a esconde)
    for pos, obs in ALAVANCA.items():    # diferença de geometria entre estados (2 de 2)
        for ob in obs:
            ob.hide_render = (pos == "baixo") == (estado not in ESTADOS_ABRIGADOS)
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
OBJETOS_VERDES = ("porta_lampada", "estufa_vidro", "estufa_fundo",
                  *(f"estufa_folha{k}" for k in range(7)),
                  "estufa_broto_caule", "estufa_broto0", "estufa_broto1",
                  "glovebox_vidro", "glovebox_fundo", "glovebox_chao")
# Superfícies que recuam (casco, painéis, juntas): o traço entre duas delas é meio-tom.
RECUO = ("parede", "piso", "teto", "nervura", "calha")
FATOR_JUNTA = 0.6


# Azul é só do que vem da Terra: a rampa azul da Apollo vale só na moldura da tela de
# comunicação, para luz fria em parede cinza não virar azul. Violeta e rosa são de outros
# recursos no jogo: a rampa só vale na barra de LED da estufa.
AZUIS = np.arange(0, 6)
ROSAS = np.arange(30, 36)
OBJETOS_AZUIS = ("comunicacao_moldura",)
OBJETOS_ROSAS = ("estufa_luz",)


def quantizar(lin, verde_ok=True, azul_ok=True, rosa_ok=True):
    """Linear -> índice da cor mais próxima da paleta em OKLab.

    verde_ok, azul_ok, rosa_ok: bool ou máscara por pixel de onde a rampa verde, a azul e a
    violeta/rosa podem ser usadas.
    """
    lab = lin_para_oklab(np.clip(lin, 0, 1))
    d = ((lab[..., None, :] - PALETA_LAB[None, None]) ** 2).sum(-1)
    for rampa, ok in ((AZUIS, azul_ok), (ROSAS, rosa_ok), (VERDES, verde_ok)):
        sem = d.copy()
        sem[..., rampa] = np.inf
        d = np.where(np.asarray(ok)[..., None], d, sem)
    return d.argmin(-1)


# ---- tons limpos: cada face plana de cada objeto resolve em dois tons

VIZINHOS4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
VIZINHOS8 = VIZINHOS4 + ((1, 1), (1, -1), (-1, 1), (-1, -1))
TOM_SOMBRA = 0.60                    # razão da luz suavizada sobre a mediana da face
PASSOS_SUAVE = 24                    # difusão da luz dentro da face, em passos de 1 px


def faces_planas(p):
    """Rótulo por pixel: mesmo objeto e mesma normal, ou seja, a mesma face plana."""
    n = np.rint(p["normal"] * 200).astype(np.int64)
    chave = np.stack([p["indice"], n[..., 0], n[..., 1], n[..., 2]], -1).reshape(-1, 4)
    _, rot = np.unique(chave, axis=0, return_inverse=True)
    return rot.reshape(p["indice"].shape)


def _mediana_por_grupo(valores, grupo):
    """Mediana de cada canal de `valores` (N, C) por grupo (N,), devolvida por pixel."""
    out = np.empty_like(valores)
    for c in range(valores.shape[1]):
        ordem = np.lexsort((valores[:, c], grupo))
        g = grupo[ordem]
        inicio = np.r_[0, np.nonzero(np.diff(g))[0] + 1]
        conta = np.diff(np.r_[inicio, len(g)])
        med = valores[ordem, c][inicio + conta // 2]
        out[:, c] = med[np.searchsorted(g[inicio], grupo)]
    return out


def tons_por_face(cor, rot):
    """Troca o gradiente e o ruído do render por dois tons chapados por face: o da face e a sombra.

    A luz de cada pixel (a luminância, suavizada só dentro da própria face) é comparada com a
    mediana da face: abaixo de TOM_SOMBRA é sombra, o resto é o tom da face. Cada (face, faixa)
    leva a mediana das cores do render nela. Assim a fronteira entre tons vem da sombra de um
    objeto, e não da rampa suave da luz que a quantização transformava em manchas.
    """
    h, w = rot.shape
    lum = cor @ np.array([0.2126, 0.7152, 0.0722])
    iguais = [np.roll(rot, d, (0, 1)) == rot for d in VIZINHOS4]
    s = lum.copy()
    for _ in range(PASSOS_SUAVE):
        soma, conta = s.copy(), np.ones_like(s)
        for d, m in zip(VIZINHOS4, iguais):
            soma += np.where(m, np.roll(s, d, (0, 1)), 0.0)
            conta += m
        s = soma / conta
    plano = rot.reshape(-1)
    med = _mediana_por_grupo(s.reshape(-1, 1), plano)[:, 0]
    razao = s.reshape(-1) / np.maximum(med, 1e-6)
    sombra = (razao < TOM_SOMBRA).astype(np.int64)
    return _mediana_por_grupo(cor.reshape(-1, 3), plano * 2 + sombra).reshape(h, w, 3)


def limpar_orfaos(q, rot, fora, alvo, mesma_min=3, validos_min=3, passos=3):
    """Filtro de maioria: um pixel de `alvo` com menos de `mesma_min` vizinhos (de 8) da mesma
    cor, entre os vizinhos do mesmo rótulo `rot` que não estão em `fora`, toma a cor mais comum
    entre eles (se houver pelo menos `validos_min`).

    Dentro da face (rot = face, fora = contorno, alvo = o resto) some o pixel solto e a linha de
    1 px entre dois tons. No contorno (rot = contorno, fora = o resto, alvo = contorno) a cor do
    traço fica igual ao longo da linha, sem mudar o lugar do traço.
    """
    for _ in range(passos):
        viz = np.stack([np.where(np.roll(rot, d, (0, 1)) == rot,
                                 np.where(np.roll(fora, d, (0, 1)), -1, np.roll(q, d, (0, 1))), -1)
                        for d in VIZINHOS8], -1)
        validos = (viz >= 0).sum(-1)
        mesma = (viz == q[..., None]).sum(-1)
        votos = (viz[..., :, None] == viz[..., None, :]).sum(-1)
        votos = np.where(viz >= 0, votos, 0)
        maioria = np.take_along_axis(viz, votos.argmax(-1)[..., None], -1)[..., 0]
        trocar = alvo & (mesma < mesma_min) & (validos >= validos_min) & (maioria >= 0)
        if not trocar.any():
            break
        q = np.where(trocar, maioria, q)
    return q


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


def _ids(prefixos):
    return [v for n, v in INDICE.items() if n.startswith(prefixos)]


def pixel_art(p, borda, estado, vidros=()):
    """Devolve o RGBA do panorama; o vidro da janela sai com alpha 0 (menos no abrigo), e o dos objetos
    em `vidros` (as câmaras da vista de perto) também.

    Passos: tons chapados por face (tons_por_face), quantização na Apollo com o verde, o azul e o
    rosa restritos aos seus objetos, filtro de maioria contra pixel solto (limpar_orfaos) e o
    contorno de 1 px por cima, com a cor do traço igualada ao longo da linha.
    """
    if estado in ("abrigo", "abrigo_aberto"):
        verde_ok = True
    else:
        verde_ok = np.isin(p["indice"], [INDICE[n] for n in OBJETOS_VERDES if n in INDICE])
    azul_ok = np.isin(p["indice"], [INDICE[n] for n in OBJETOS_AZUIS])
    rosa_ok = np.isin(p["indice"], [INDICE[n] for n in OBJETOS_ROSAS])
    rot = faces_planas(p)
    q = quantizar(tons_por_face(p["cor"], rot), verde_ok, azul_ok, rosa_ok)
    q = limpar_orfaos(q, rot, borda, ~borda)
    # traço: a cor da paleta mais próxima de 25 % do brilho do pixel por baixo; entre duas
    # superfícies que recuam (junta de painel, quina da sala), meio-tom, para não competir
    # com o traço dos objetos
    recuo = np.isin(p["indice"], _ids(RECUO))
    junta = recuo.copy()
    for d in VIZINHOS4:
        junta &= np.roll(recuo, d, (0, 1))
    fator = np.where(junta, FATOR_JUNTA, 0.25)[..., None]
    escura = quantizar(PALETA_LAB_LIN[q] * fator, verde_ok, azul_ok, rosa_ok)
    q = np.where(borda, escura, q)
    igualado = limpar_orfaos(q, borda.astype(np.int8), ~borda, borda, mesma_min=1, validos_min=2)
    # a cor que vem do vizinho respeita as mesmas restrições de verde, azul e rosa
    pode = np.ones(q.shape, bool)
    for rampa, ok in ((VERDES, verde_ok), (AZUIS, azul_ok), (ROSAS, rosa_ok)):
        pode &= ~np.isin(igualado, rampa) | ok
    q = np.where(pode, igualado, q)
    rgb = PALETA_SRGB[q].copy()
    # telas em branco: cor única por dentro (o contorno de 1 px fica), para o Godot
    # desenhar as barras por cima sem ruído do render
    cor_tela = PALETA_SRGB[APOLLO.index(COR_TELA_APAGADA)]
    for nome in TELAS_APAGADAS:
        rgb[(p["indice"] == INDICE[nome]) & ~borda] = cor_tela
    # em volta do vidro, neutro escuro em todos os estados: o traço do vidro e as faces internas
    # da moldura (as que não olham para o olho). A vista atrás escurece à noite no Godot, e um
    # aro laranja ali pareceria erro.
    interna = (p["indice"] == INDICE["janela_moldura_topo"]) & (p["normal"][..., 1] > -0.9)
    rgb[interna | ((p["indice"] == INDICE["janela"]) & borda)] = PALETA_SRGB[APOLLO.index(COR_AROS_JANELA)]
    # vidro da janela: alpha 0, e o Godot põe a vista de Marte atrás. No abrigo a persiana tapa
    # o vidro, e o que sobrar dele (frestas) fica opaco.
    alfa = np.full(rgb.shape[:2], 255, np.uint8)
    if estado != "abrigo":
        vidro = (p["indice"] == INDICE["janela"]) & ~borda
        alfa[vidro] = 0
        rgb[vidro] = 0
    for nome in vidros:
        vidro = (p["indice"] == INDICE[nome]) & ~borda
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
    # a alavanca: a placa e as duas posições do braço com o punho (o retângulo é a união)
    "abrigo": ["abrigo_aro", "abrigo_fenda", "abrigo_pino", "abrigo_braco_cima", "abrigo_punho_cima",
               "abrigo_braco_baixo", "abrigo_punho_baixo"],
    "porta": ["porta_folha", "porta_moldura_topo", "porta_moldura_tras", "porta_moldura_frente"],
    "porta_lampada": ["porta_lampada"],
    "estufa": ["estufa_moldura", "estufa_vidro"],
    "glovebox": ["glovebox_moldura", "glovebox_vidro", "glovebox_aro0", "glovebox_aro1"],
    "janela": list(JANELA_OBJS),
}
TELAS = ("energia", "oxigenio", "radiacao", "comunicacao")
# As telas saem como trapézio na câmera cilíndrica (as da rampa, em ~10 px de folga; radiação e comunicação,
# em 1 a 3 px): o json guarda o retângulo inscrito (o que o Godot pinta), não a caixa envolvente. O resto do
# trapézio continua escuro pelo próprio PNG.
MARGEM_TELA = 2   # px: o traço do contorno come 1 a 2 px da borda da tela no PNG (medido em normal.png)
BOTOES = ("abrigo", "estufa", "glovebox")
# A porta é botão, mas fica na ponta esquerda do panorama (x < 60), sob a seta de pan quando o pan está
# em 0: não segue ZONA_LIVRE_X nem FAIXA_CLIQUE, que valem para os botões do meio da sala. O Godot
# esconde a seta no limite do pan para a porta se alcançar.
PORTA = "porta"
DESENHO = ("porta_lampada",)   # regiões só de desenho: o Godot pinta por cima do render
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


def retangulo_inscrito(pts_xy, largura, altura, margem=0):
    """Maior retângulo alinhado aos eixos que cabe inteiro no contorno projetado (pixels cujo
    centro está dentro). A tela fica numa rampa e a câmera a projeta como trapézio: a caixa
    envolvente (retangulo) passa da moldura; este não. Os pontos são os vértices e as amostras
    das arestas, e o contorno é lido ordenando-os em volta do centro (vale para tela convexa).
    `margem` (px) encolhe o resultado de cada lado: o traço do contorno come 1 a 2 px da borda."""
    x, y = pts_xy
    ang = np.arctan2(y - y.mean(), x - x.mean())
    px, py = x[np.argsort(ang)], y[np.argsort(ang)]
    qx, qy = np.roll(px, -1), np.roll(py, -1)
    y0, y1 = max(int(np.floor(y.min())), 0), min(int(np.ceil(y.max())), altura)
    linhas = []  # (y, esquerda, direita) no centro de cada linha de pixels
    for j in range(y0, y1):
        yc = j + 0.5
        cruza = (py <= yc) != (qy <= yc)
        if cruza.sum() < 2:
            continue
        xs = px[cruza] + (yc - py[cruza]) * (qx[cruza] - px[cruza]) / (qy[cruza] - py[cruza])
        linhas.append((j, xs.min(), xs.max()))
    melhor = None
    for i in range(len(linhas)):
        esq, dir_ = -np.inf, np.inf
        for k in range(i, len(linhas)):
            if linhas[k][0] != linhas[i][0] + (k - i):
                break  # linha sem cruzamento no meio: o contorno não é contínuo
            esq, dir_ = max(esq, linhas[k][1]), min(dir_, linhas[k][2])
            xa, xb = int(np.ceil(esq - 0.5)), int(np.floor(dir_ - 0.5)) + 1
            if xb <= xa:
                break
            area = (xb - xa) * (k - i + 1)
            if melhor is None or area > melhor[0]:
                melhor = (area, xa, linhas[i][0], xb - xa, k - i + 1)
    _, xa, ya, w, h = melhor
    return {"x": xa + margem, "y": ya + margem, "w": w - 2 * margem, "h": h - 2 * margem}


def calcular_regioes(a, rad_px):
    bpy.context.view_layer.update()
    out = {}
    for nome, objs in REGIOES.items():
        pts = np.concatenate([pontos_do_objeto(o) for o in objs])
        proj = projetar(pts, a, rad_px)
        if nome in TELAS:
            out[nome] = retangulo_inscrito(proj, a.largura, a.altura, MARGEM_TELA)
        else:
            out[nome] = retangulo(proj, a.largura, a.altura)
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
    r = reg[PORTA]
    checa(r["w"] >= 24 and r["h"] >= 24, f"{PORTA}: tamanho {r['w']}x{r['h']} px (mínimo 24x24)")
    checa(r["x"] + r["w"] <= 320, f"{PORTA}: x {r['x']}..{r['x'] + r['w']} dentro de x<320")
    r, p = reg["porta_lampada"], reg[PORTA]
    checa(r["w"] >= 4 and r["h"] >= 4, f"porta_lampada: tamanho {r['w']}x{r['h']} px")
    checa(r["y"] + r["h"] <= p["y"] + 4 and p["x"] - 4 <= r["x"] and r["x"] + r["w"] <= p["x"] + p["w"] + 4,
          f"porta_lampada: x {r['x']}..{r['x'] + r['w']} y {r['y']}..{r['y'] + r['h']} acima da porta "
          f"(x {p['x']}..{p['x'] + p['w']}, y {p['y']})")
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


# ---------------------------------------------------------------- vista de perto

# Cada estação: o painel no chão, o vidro da câmara (a face dele, em metros, na normal do painel, e o
# centro dele), o miolo que fica atrás do vidro (escondido: a peça do Godot desenha o interior), a
# escala (px por metro no plano do vidro), a distância da câmera ao vidro e onde, na imagem, cai o
# centro do vidro. O vidro da glovebox é cortado embaixo pela imagem: os aros das luvas comem a parte
# de baixo dele, e o retângulo da peça só existe acima deles.
PERTO_DIST = 1.0                     # m da câmera ao vidro; perspectiva suave, sem deformar a peça
PERTO_W, PERTO_H = 640, 360
PERTO = {
    "estufa": dict(
        centro=ESTUFA_C, vidro="estufa_vidro", d_vidro=0.245, z_vidro=1.18,
        esconder=("estufa_luz", "estufa_fundo", "estufa_bandeja", "estufa_solo",
                  *(f"estufa_folha{k}" for k in range(7)),
                  "estufa_broto_caule", "estufa_broto0", "estufa_broto1"),
        px_por_m=530.0, ancora_px=(320, 195)),
    "glovebox": dict(
        centro=GLOVEBOX_C, vidro="glovebox_vidro", d_vidro=0.23, z_vidro=1.17,
        esconder=("glovebox_fundo", "glovebox_chao", "glovebox_luz", "glovebox_manga0",
                  "glovebox_manga1", "glovebox_mao0", "glovebox_mao1", "glovebox_polegar0",
                  "glovebox_polegar1", "glovebox_suporte", "glovebox_tubo", "glovebox_liquido",
                  "glovebox_tampa"),
        px_por_m=760.0, ancora_px=(320, 238)),
}
# Onde o Godot desenha o resto da tela da vista de perto (640x360): a faixa do HUD do turno (y < 34), o
# botão de voltar (canto de cima à direita) e o de mudo (canto de baixo à direita). A peça não os cobre.
PERTO_HUD_Y = 34
PERTO_VOLTAR = (562, 6, 72, 32)
PERTO_MUDO = (596, 328, 38, 28)


def posicionar_camera_perto(cfg):
    """Põe a câmera de frente para o vidro, a PERTO_DIST dele, de modo que o centro do vidro caia em
    `ancora_px` com `px_por_m` px por metro. Só translada (não gira nem inclina): o vidro, que é plano e
    paralelo ao sensor, continua um retângulo alinhado aos eixos na imagem."""
    painel = Painel(*cfg["centro"])
    s_ = cfg["px_por_m"]
    ax, ay = cfg["ancora_px"]
    a_cam = -(ax - PERTO_W / 2) / s_
    z_cam = cfg["z_vidro"] + (ay - PERTO_H / 2) / s_
    cam = bpy.context.scene.camera
    cam.location = painel.pos(a_cam, cfg["d_vidro"] + PERTO_DIST, z_cam)
    ang = math.degrees(math.atan2(painel.f[0], painel.f[1]))   # de +y para +x, para a direita
    cam.rotation_euler = (math.radians(90), 0, math.radians(-ang))
    rad_px = 1.0 / (s_ * PERTO_DIST)
    cam.data.angle_y = 2 * math.atan(rad_px * PERTO_H / 2)
    return rad_px


def maior_retangulo(mascara):
    """Maior retângulo alinhado aos eixos todo dentro da máscara (histograma por linha): x, y, w, h."""
    h, w = mascara.shape
    alturas = np.zeros(w, np.int64)
    melhor = (0, 0, 0, 0, 0)
    for y in range(h):
        alturas = np.where(mascara[y], alturas + 1, 0)
        pilha = []
        for x in range(w + 1):
            atual = alturas[x] if x < w else 0
            inicio = x
            while pilha and pilha[-1][1] >= atual:
                x0, alt = pilha.pop()
                area = alt * (x - x0)
                if area > melhor[0]:
                    melhor = (area, x0, y - alt + 1, x - x0, alt)
                inicio = x0
            pilha.append((inicio, atual))
    _, x, y, w_, h_ = melhor
    return {"x": int(x), "y": int(y), "w": int(w_), "h": int(h_)}


def desenhar_perto(rgba, r):
    """Depuração em 2x: o vidro (azul), o retângulo da peça (magenta), a faixa do HUD, o botão de voltar e o de mudo."""
    fundo = np.where(rgba[..., 3:4] > 0, rgba[..., :3], np.array([32, 96, 160], np.uint8))
    img = np.repeat(np.repeat(fundo, 2, 0), 2, 1).astype(np.uint8).copy()
    img[PERTO_HUD_Y * 2, ::6] = (255, 255, 255)

    def moldura(x, y, w, h, cor):
        x0, y0, x1, y1 = x * 2, y * 2, (x + w) * 2 - 1, (y + h) * 2 - 1
        img[y0:y1 + 1, [x0, x0 + 1, x1 - 1, x1]] = cor
        img[[y0, y0 + 1, y1 - 1, y1], x0:x1 + 1] = cor

    moldura(r["x"], r["y"], r["w"], r["h"], (255, 0, 255))
    moldura(*PERTO_VOLTAR, (255, 255, 0))
    moldura(*PERTO_MUDO, (255, 255, 0))
    return img


def main_perto(a):
    estacoes = [e for e in a.perto.split(",") if e]
    for e in estacoes:
        if e not in PERTO:
            raise SystemExit(f"--perto: estação desconhecida '{e}' (use {', '.join(PERTO)})")
    a.camera, a.largura, a.altura = "perspectiva", PERTO_W, PERTO_H
    bpy.ops.wm.read_factory_settings(use_empty=True)
    luzes = construir()
    configurar(a)
    CACHE.mkdir(parents=True, exist_ok=True)
    (CACHE / ".gdignore").touch()
    saida = RAIZ / a.saida
    aplicar_estado("normal", luzes)
    regioes = {}
    ok_geral = True
    for nome in estacoes:
        cfg = PERTO[nome]
        for ob in cfg["esconder"]:
            bpy.data.objects[ob].hide_render = True
        posicionar_camera_perto(cfg)
        bpy.context.view_layer.update()
        exr = CACHE / f"perto_{nome}.exr"
        bpy.context.scene.render.filepath = str(exr)
        bpy.ops.render.render(write_still=True)
        p = ler_exr(exr)
        borda = contorno(p)
        rgba = pixel_art(p, borda, "normal", vidros=(cfg["vidro"],))
        for ob in cfg["esconder"]:
            bpy.data.objects[ob].hide_render = False
        caminho = saida / f"perto_{nome}.png"
        salvar_png_rgba(caminho, rgba)

        transp = rgba[..., 3] == 0
        r = maior_retangulo(transp)
        dentro = np.zeros(transp.shape, bool)
        dentro[r["y"]:r["y"] + r["h"], r["x"]:r["x"] + r["w"]] = True
        vx = [r["x"], r["x"] + r["w"]]
        checagens = [
            (f"nada opaco dentro do retângulo da peça ({int((dentro & ~transp).sum())} px opacos)",
             not (dentro & ~transp).any()),
            (f"o alpha 0 é só o vidro ({int((transp & (p['indice'] != INDICE[cfg['vidro']])).sum())} px de outro objeto)",
             not (transp & (p["indice"] != INDICE[cfg["vidro"]])).any()),
            (f"a janela não aparece na imagem ({int((p['indice'] == INDICE['janela']).sum())} px)",
             not (p["indice"] == INDICE["janela"]).any()),
            (f"retângulo abaixo da faixa do HUD: y {r['y']} >= {PERTO_HUD_Y}", r["y"] >= PERTO_HUD_Y),
            (f"retângulo dentro da imagem: x {vx[0]}..{vx[1]}, y {r['y']}..{r['y'] + r['h']}",
             vx[0] >= 0 and vx[1] <= PERTO_W and r["y"] + r["h"] <= PERTO_H),
        ]
        for rect_ui, nome_ui in ((PERTO_VOLTAR, "voltar"), (PERTO_MUDO, "mudo")):
            ux, uy, uw, uh = rect_ui
            livre = r["x"] + r["w"] <= ux or ux + uw <= r["x"] or r["y"] + r["h"] <= uy or uy + uh <= r["y"]
            checagens.append((f"retângulo não cobre o botão {nome_ui} {rect_ui}", livre))
        print(f"[comodo] perto {nome}: {caminho}")
        print(f"[comodo]   retângulo da peça: {r['x']}, {r['y']}, {r['w']}x{r['h']}")
        for msg, ok in checagens:
            print(f"[comodo]   {'ok   ' if ok else 'FALHA'} {msg}")
            ok_geral &= bool(ok)
        regioes[nome] = r
        salvar_png(CACHE / f"perto_{nome}_debug.png", desenhar_perto(rgba, r))
        print(f"[comodo]   depuração: {CACHE / f'perto_{nome}_debug.png'}")

    # só a chave "perto" muda: o resto do regioes.json (e os PNGs do panorama) ficam como estão
    arq = saida / "regioes.json"
    doc = json.loads(arq.read_text()) if arq.exists() else {}
    doc.setdefault("perto", {}).update(regioes)
    doc["perto"]["nota"] = ("x, y, w, h em px da imagem perto_<estacao>.png (640x360), no maior retângulo "
                           "inscrito no vidro (alpha 0): é onde o Godot põe a peça, atrás do PNG.")
    arq.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n")
    print(f"[comodo] regiões: {arq}")
    print(f"[comodo] vista de perto: {'PASSA' if ok_geral else 'FALHA'}")


def main():
    a = args()
    if a.perto:
        return main_perto(a)
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

    # a geometria não pode mudar entre estados, salvo a persiana dentro do retângulo da janela e a
    # alavanca dentro do retângulo do abrigo: profundidade, normal, índice e contorno idênticos fora
    # deles (com 3 px de folga para o traço)
    def caixa_com_folga(r):
        m = np.zeros((a.altura, a.largura), bool)
        m[max(r["y"] - 3, 0):r["y"] + r["h"] + 3, max(r["x"] - 3, 0):r["x"] + r["w"] + 3] = True
        return m

    j = reg["janela"]
    dentro = caixa_com_folga(j)
    dentro_alavanca = caixa_com_folga(reg["abrigo"])
    base = estados[0]
    for e in estados[1:]:
        dz = np.abs(passes[e]["z"] - passes[base]["z"])
        dn = np.abs(passes[e]["normal"] - passes[base]["normal"]).max(-1)
        di = passes[e]["indice"] != passes[base]["indice"]
        db = contorno(passes[e]) != contorno(passes[base])
        fora = ~dentro & ~dentro_alavanca
        print(f"[comodo] {base} x {e}: FORA da janela e da alavanca max|Δz|={dz[fora].max():.2e} "
              f"max|Δnormal|={dn[fora].max():.2e} px índice diferente={int(di[fora].sum())} "
              f"px contorno diferente={int(db[fora].sum())}")
        print(f"[comodo] {base} x {e}: DENTRO da janela (a persiana) "
              f"px índice diferente={int(di[dentro].sum())} px contorno diferente={int(db[dentro].sum())}")
        print(f"[comodo] {base} x {e}: DENTRO do retângulo da alavanca "
              f"px índice diferente={int(di[dentro_alavanca].sum())} "
              f"px contorno diferente={int(db[dentro_alavanca].sum())}")

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

    # regiões de desenho: o retângulo visível de fato no passe de índice (o Godot pinta por cima do render)
    for nome in DESENHO:
        mask = np.isin(passes[base]["indice"], [INDICE[o] for o in REGIOES[nome]])
        ys, xs = np.nonzero(mask)
        reg[nome] = {"x": int(xs.min()), "y": int(ys.min()), "w": int(xs.max() + 1 - xs.min()),
                     "h": int(ys.max() + 1 - ys.min())}
        print(f"[comodo] {nome} (visível no passe de índice): {reg[nome]}")

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
    for nome in BOTOES + (PORTA, "comunicacao"):
        print(f"[comodo] {nome}: {reg[nome]['w']}x{reg[nome]['h']} px")
    print(f"[comodo] rad_por_px={rad_px:.6f} câmera={a.camera} yaw={a.yaw}")

    doc = {
        "formato": "x, y, w, h em px do PNG; origem no canto superior esquerdo",
        "panorama": {"largura": a.largura, "altura": a.altura, "graus": a.graus,
                     "faixa_de_clique_y": list(FAIXA_CLIQUE),
                     "cor_das_telas_em_branco": "#" + COR_TELA_APAGADA,
                     "arquivos": [f"{e}.png" for e in ESTADOS]},
        "telas": {n: reg[n] for n in TELAS},
        "botoes": {n: reg[n] for n in BOTOES + (PORTA,)},
        "desenho": {n: reg[n] for n in DESENHO},
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
