"""Gera o módulo de comando do zero e renderiza um PNG em pixel art por estado.

Uso (da raiz do repo):
    blender -b --factory-startup -P $PWD/arte/blender/comodo.py
    blender -b --factory-startup -P $PWD/arte/blender/comodo.py -- --estados normal --sem-monitor
(o `blender` do PATH é o Flatpak: passe o script por caminho absoluto.)

Fonte da verdade: este script. Nenhum .blend é salvo nem lido.
Mesma câmera em todos os estados. A geometria também é a mesma, com uma única exceção
permitida: a persiana da janela, que só o estado `abrigo` fecha. O estado muda luz e emissão.

Além dos PNGs do panorama, grava assets/comodo/regioes.json (retângulos dos botões e telas,
calculados pela projeção real da câmera sobre os vértices) e o monitor portátil
assets/comodo/monitor_portatil.png (render separado, com a área da tela em alpha 0).
Uma imagem de depuração com os retângulos fica em arte/blender/.render/regioes_debug.png.

Paleta: Apollo, de AdamCYounis (https://lospec.com/palette-list/apollo).
"""

import argparse
import json
import math
import sys
import types
from pathlib import Path

import bmesh
import bpy
import numpy as np
import OpenImageIO as oiio

RAIZ = Path(__file__).resolve().parents[2]
CACHE = RAIZ / "arte" / "blender" / ".render"

ESTADOS = ["normal", "tempestade", "abrigo", "modo_seguranca"]

# Apollo, AdamCYounis — https://lospec.com/palette-list/apollo
APOLLO = (
    "172038 253a5e 3c5e8b 4f8fba 73bed3 a4dddb 19332d 25562e 468232 75a743 "
    "a8ca58 d0da91 4d2b32 7a4841 ad7757 c09473 d7b594 e7d5b3 341c27 602c2c "
    "884b2b be772b de9e41 e8c170 241527 411d31 752438 a53030 cf573c da863e "
    "1e1d39 402751 7a367b a23e8c c65197 df84a5 090a14 10141f 151d28 202e37 "
    "394a50 577277 819796 a8b5b2 c7cfcc ebede9"
).split()

OLHO = (0.0, 0.0, 1.2)


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser(prog="comodo.py")
    p.add_argument("--estados", default=",".join(ESTADOS))
    p.add_argument("--camera", choices=["cilindrica", "perspectiva"], default="cilindrica")
    p.add_argument("--largura", type=int, default=1280)
    p.add_argument("--altura", type=int, default=360)
    p.add_argument("--graus", type=float, default=180.0,
                   help="campo horizontal do panorama (cilíndrica) em graus")
    p.add_argument("--yaw", type=float, default=0.0, help="graus, positivo vira para a direita")
    p.add_argument("--rad-por-px", type=float, default=None,
                   help="escala angular no centro; padrão: graus/largura")
    p.add_argument("--saida", default="assets/comodo")
    p.add_argument("--sufixo", default="")
    p.add_argument("--amostras", type=int, default=64)
    p.add_argument("--sem-monitor", action="store_true", help="não renderiza o monitor portátil")
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


COR_TELA_APAGADA = "202e37"          # cor única das telas em branco (Apollo)
TELAS_APAGADAS = ("energia_tela", "oxigenio_tela", "radiacao_tela")
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
    do abrigo; na parede da frente, a janela e o botão da Terra.
    Centro (320-960): as telas de energia e oxigênio. Direita (>960): o console das câmeras
    e a estufa da planta.
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
    blindagem = material("blindagem", hexrgb("577277"))
    estufa = material("estufa", hexrgb("a8b5b2"))
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

    # ---- centro: console decorativo (sem botão) sob as duas telas grandes
    caixa("console_mesa", (0, 1.25, 0.4), (2.2, 0.7, 0.8), console, next(i))
    caixa("console_painel", (0, 1.5, 0.95), (2.2, 0.45, 0.06), painel, next(i), rot=(35, 0, 0))
    # duas telas em branco na parede da frente: energia (esquerda) e oxigênio (direita)
    for nome, x in (("energia", -0.7), ("oxigenio", 0.7)):
        caixa(f"{nome}_moldura", (x, F - 0.06, 1.56), (1.40, 0.08, 0.82), moldura, next(i))
        caixa(f"{nome}_tela", (x, F - 0.105, 1.56), (1.30, 0.01, 0.72), ecra, next(i))

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

    # parede da frente, à esquerda: a janela (com persiana, que só o abrigo fecha) e a Terra
    jx, jz = -2.05, 1.64
    caixa("janela_moldura", (jx, F - 0.05, jz), (0.90, 0.10, 0.62), moldura, next(i))
    caixa("janela", (jx, F - 0.105, jz), (0.74, 0.01, 0.46), janela, next(i))
    for k in range(6):
        mat_s = faixa if k in (0, 5) else blindagem
        PERSIANA.append(caixa(f"persiana_{k}", (jx, F - 0.135, jz - 0.20 + k * 0.08),
                              (0.78, 0.05, 0.075), mat_s, next(i)))

    tx, tz = -2.05, 1.0
    botao("botao_terra", "73bed3")
    caixa("terra_placa", (tx, F - 0.04, tz), (0.62, 0.08, 0.62), console, next(i))
    cilindro("terra_aro", (tx, F - 0.105, tz), 0.29, 0.05, amarelo, next(i), rot=(90, 0, 0))
    cilindro("terra_anel", (tx, F - 0.13, tz), 0.25, 0.05, moldura, next(i), rot=(90, 0, 0))
    cilindro("terra_botao", (tx, F - 0.18, tz), 0.19, 0.1, MATS["botao_terra"], next(i), rot=(90, 0, 0))

    # ---- direita: console das 4 câmeras (voltado para o olho) e a estufa da planta
    r = Painel(2.10, 1.15)
    r.caixa("cameras_base", 0, 0, 0.06, 1.05, 0.42, 0.12, moldura, next(i))
    r.caixa("cameras_corpo", 0, 0, 0.93, 0.95, 0.30, 1.62, console, next(i))
    r.caixa("cameras_lampadas", 0, 0.17, 1.66, 0.8, 0.04, 0.1, moldura, next(i))
    cores = {"painel": "75a743", "rocha": "4f8fba", "amostra": "c65197", "moxie": "be772b"}
    for k, (nome, cor) in enumerate(cores.items()):
        a_ = -0.235 if k % 2 == 0 else 0.235
        z_ = 1.35 if k < 2 else 1.0
        botao(f"botao_camera_{nome}", cor)
        r.caixa(f"camera_{nome}_aro", a_, 0.17, z_, 0.46, 0.04, 0.33, moldura, next(i))
        r.caixa(f"camera_{nome}_botao", a_, 0.22, z_, 0.40, 0.07, 0.27, MATS[f"botao_camera_{nome}"], next(i))

    # estufa da planta, encostada na parede direita perto do canto de trás (P2)
    ex, ey = W - 0.275, 0.30
    caixa("estufa_corpo", (ex, ey, 0.85), (0.55, 0.62, 1.7), estufa, next(i))
    pz = 1.175                                   # vidro todo dentro da faixa de clique
    caixa("planta_moldura", (W - 0.55 - 0.02, ey, pz), (0.04, 0.54, 0.62), moldura, next(i))
    caixa("planta_vidro", (W - 0.55 - 0.04, ey, pz), (0.01, 0.46, 0.54), vidro_estufa, next(i))
    caixa("planta_luz", (W - 0.55 - 0.05, ey, pz + 0.23), (0.02, 0.44, 0.05), luz_cultivo, next(i))
    caixa("planta_solo", (W - 0.55 - 0.06, ey, pz - 0.22), (0.04, 0.42, 0.08), solo, next(i))
    caixa("planta_caule", (W - 0.55 - 0.06, ey, pz - 0.06), (0.03, 0.04, 0.28), folha, next(i))
    for k, (dy, dz, rz) in enumerate(((0.10, pz + 0.04, 25), (-0.10, pz - 0.02, -25), (0.0, pz + 0.12, 0))):
        caixa(f"planta_folha{k}", (W - 0.55 - 0.06, ey + dy, dz), (0.03, 0.14, 0.06), folha,
              next(i), rot=(rz, 0, 0))

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
    }[estado]

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
        elif n.startswith("botao_"):
            emissao(m, COR_BOTAO[n], E["botoes"])
    emissao(MATS["janela"], None, E["janela"])
    for ob in PERSIANA:                  # única diferença de geometria entre estados
        ob.hide_render = estado != "abrigo"
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
OBJETOS_VERDES = ("botao_camera_painel", "camera_painel_botao", "porta_lampada", "planta_caule",
                  "planta_folha0", "planta_folha1", "planta_folha2", "vidro_estufa")


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
    if estado == "abrigo":
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
    return rgb


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
    "abrigo": ["abrigo_aro", "abrigo_anel", "abrigo_botao"],
    "terra": ["terra_aro", "terra_anel", "terra_botao"],
    "camera_painel": ["camera_painel_aro", "camera_painel_botao"],
    "camera_rocha": ["camera_rocha_aro", "camera_rocha_botao"],
    "camera_amostra": ["camera_amostra_aro", "camera_amostra_botao"],
    "camera_moxie": ["camera_moxie_aro", "camera_moxie_botao"],
    "planta": ["planta_moldura", "planta_vidro"],
    "janela": ["janela_moldura", "janela"],
}
TELAS = ("energia", "oxigenio", "radiacao")
BOTOES = ("abrigo", "terra", "camera_painel", "camera_rocha", "camera_amostra", "camera_moxie",
          "planta")
FAIXA_CLIQUE = (120, 250)


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
    for n in BOTOES:
        r = reg[n]
        checa(y_min <= r["y"] and r["y"] + r["h"] <= y_max,
              f"{n}: faixa y {r['y']}..{r['y'] + r['h']} dentro de {y_min}..{y_max}")
        checa(r["w"] >= 24 and r["h"] >= 24, f"{n}: tamanho {r['w']}x{r['h']} px (mínimo 24x24)")
    for n in ("abrigo", "radiacao"):
        r = reg[n]
        checa(r["x"] + r["w"] <= 320, f"{n}: x {r['x']}..{r['x'] + r['w']} dentro de x<320")
    for n in ("energia", "oxigenio"):
        r = reg[n]
        checa(r["x"] >= 320 and r["x"] + r["w"] <= 960,
              f"{n}: x {r['x']}..{r['x'] + r['w']} dentro de 320..960")
    for n in ("camera_painel", "camera_rocha", "camera_amostra", "camera_moxie", "planta"):
        r = reg[n]
        checa(r["x"] >= 960, f"{n}: x {r['x']}..{r['x'] + r['w']} dentro de x>960")
    for n in ("terra", "janela"):
        r = reg[n]
        checa(r["x"] + r["w"] <= 420, f"{n}: x {r['x']}..{r['x'] + r['w']} até x<=420 (limite tolerado)")
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
        print(f"[comodo]   {nome}: {proj} | {vis}  (maior diferença {folga} px)")


def desenhar_regioes(rgb, reg, monitor=None):
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


# ---------------------------------------------------------------- monitor portátil

MON_PX = 0.01                  # 1 px do PNG = 1 cm; o PNG tem 400x300
MON_W, MON_H = 400, 300
MON_TELA = (-160, 160, -60, 120)      # x0, x1, z0, z1 em px: 320x180, uma imagem 16:9


def _prisma_triangulo(nome, pontos_xz, y_frente, prof, mat, indice):
    """Prisma triangular (setinha): triângulo no plano xz, extrudado em y."""
    me = bpy.data.meshes.new(nome)
    vs = []
    for y in (y_frente, y_frente + prof):
        vs += [(x * MON_PX, y, z * MON_PX) for x, z in pontos_xz]
    fs = [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)]
    me.from_pydata(vs, [], fs)
    me.update()
    return _objeto(nome, me, mat, indice)


def _caixa_bisel(nome, centro, tamanho, mat, indice, bisel):
    me = bpy.data.meshes.new(nome)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=tamanho, verts=bm.verts)
    if bisel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bisel, segments=1, profile=0.5,
                        affect="EDGES")
    bm.to_mesh(me)
    bm.free()
    ob = _objeto(nome, me, mat, indice)
    ob.location = centro
    return ob


def construir_monitor():
    """Monitor portátil de frente, em ortográfica. Medidas em px do PNG (x para a direita,
    z para cima, origem no centro); a câmera olha para +y e a frente fica em y negativo.
    """
    MATS.clear()
    INDICE.clear()
    COR_BOTAO.clear()
    carcaca = material("m_carcaca", hexrgb("a8b5b2"))
    painel_b = material("m_painel", hexrgb("819796"))
    aro = material("m_aro", hexrgb("394a50"))
    escuro = material("m_escuro", hexrgb("151d28"))
    amarelo = material("m_aviso", hexrgb("e8c170"))
    parafuso = material("m_parafuso", hexrgb("577277"))
    borracha = material("m_borracha", hexrgb("be772b"))
    branco = material("m_branco", hexrgb("ebede9"))
    verde = material("m_lampada_verde", hexrgb("75a743"))
    ambar = material("m_lampada_ambar", hexrgb("de9e41"))
    emissao(verde, hexrgb("75a743"), 2.0)
    emissao(ambar, hexrgb("de9e41"), 2.0)
    cap = material("m_botao_abaixar", tuple(c * 0.35 for c in hexrgb("cf573c")), 0.9)
    cap.node_tree.nodes["Principled BSDF"].inputs["Specular IOR Level"].default_value = 0.0
    emissao(cap, hexrgb("cf573c"), 0.6)

    i = iter(range(1, 200))
    T = MON_PX

    def barra(nome, x0, x1, z0, z1, yf, prof, mat, bisel=0.0):
        return _caixa_bisel(nome, ((x0 + x1) / 2 * T, yf + prof / 2, (z0 + z1) / 2 * T),
                            ((x1 - x0) * T, prof, (z1 - z0) * T), mat, next(i), bisel)

    tx0, tx1, tz0, tz1 = MON_TELA
    # carcaça: quatro peças em volta do vazio da tela (não há nada atrás dele: alpha 0)
    barra("m_topo", -195, 195, tz1, 145, -0.10, 0.20, carcaca, 0.03)
    barra("m_base", -195, 195, -145, tz0, -0.10, 0.20, painel_b, 0.03)
    barra("m_esq", -195, tx0, tz0, tz1, -0.10, 0.20, carcaca, 0.03)
    barra("m_dir", tx1, 195, tz0, tz1, -0.10, 0.20, carcaca, 0.03)
    # aro da tela, fora do vazio
    barra("m_aro_topo", tx0 - 8, tx1 + 8, tz1, tz1 + 8, -0.14, 0.05, aro)
    barra("m_aro_base", tx0 - 8, tx1 + 8, tz0 - 8, tz0, -0.14, 0.05, aro)
    barra("m_aro_esq", tx0 - 8, tx0, tz0, tz1, -0.14, 0.05, aro)
    barra("m_aro_dir", tx1, tx1 + 8, tz0, tz1, -0.14, 0.05, aro)
    # pára-choques de borracha nos quatro cantos
    for sx in (-1, 1):
        for sz in (-1, 1):
            xa, xb = (165, 195) if sx > 0 else (-195, -165)
            za, zb = (115, 145) if sz > 0 else (-145, -115)
            barra(f"m_canto_{sx}_{sz}", xa, xb, za, zb, -0.14, 0.05, borracha, 0.04)
    # parafusos
    for x, z in ((-181, 132), (181, 132), (-181, -132), (181, -132), (-120, 132), (120, 132)):
        cilindro(f"m_parafuso_{x}_{z}", (x * T, -0.115, z * T), 0.05, 0.03, parafuso, next(i),
                 rot=(90, 0, 0), segs=6)
    # lâmpadas de estado, à esquerda da faixa de baixo
    for k, m_ in enumerate((verde, ambar, verde)):
        cilindro(f"m_lampada_{k}", ((-165 + k * 30) * T, -0.12, -80 * T), 0.10, 0.04, m_,
                 next(i), rot=(90, 0, 0), segs=12)
    barra("m_placa_lampadas", -182, -78, -100, -62, -0.105, 0.015, escuro)
    # grade de ventilação
    barra("m_vent_fundo", -60, 40, -134, -70, -0.105, 0.015, escuro)
    for k in range(5):
        z = -125 + k * 12
        barra(f"m_vent_{k}", -54, 34, z, z + 5, -0.125, 0.03, parafuso)
    # botão "abaixar": aro de aviso, anel escuro, tampa vermelha e seta para baixo
    barra("abaixar_aro", 72, 184, -139, -66, -0.13, 0.04, amarelo, 0.02)
    barra("abaixar_anel", 78, 178, -133, -72, -0.15, 0.04, escuro, 0.01)
    barra("abaixar_botao", 84, 172, -127, -78, -0.18, 0.06, cap, 0.025)
    _prisma_triangulo("abaixar_seta", [(106, -92), (150, -92), (128, -116)], -0.20, 0.03,
                      branco, next(i))


def monitor(a, saida):
    """Renderiza o monitor portátil e devolve (retângulos, rgba)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    construir_monitor()
    s = bpy.context.scene
    configurar(types.SimpleNamespace(amostras=a.amostras, largura=MON_W, altura=MON_H,
                                     camera="perspectiva", yaw=0.0, graus=180.0, rad_por_px=None))
    s.render.film_transparent = True
    cam = s.camera
    cam.location = (0.0, -6.0, 0.0)
    cam.rotation_euler = (math.radians(90), 0, 0)
    cam.data.type = "ORTHO"
    cam.data.sensor_fit = "HORIZONTAL"
    cam.data.ortho_scale = MON_W * MON_PX          # largura inteira do PNG
    cam.data.clip_start = 0.1
    cam.data.clip_end = 20.0
    # luz: ambiente suave e uma luz de área do alto à esquerda, na frente
    w = s.world.node_tree.nodes["Background"]
    w.inputs["Color"].default_value = (1, 1, 1, 1)
    w.inputs["Strength"].default_value = 0.45
    ld = bpy.data.lights.new("luz_monitor", "AREA")
    ld.shape = "RECTANGLE"
    ld.size, ld.size_y = 6.0, 4.0
    ld.energy = 260
    ld.color = hexrgb("ebede9")
    lo = bpy.data.objects.new("luz_monitor", ld)
    lo.location = (-2.5, -4.0, 3.0)
    lo.rotation_euler = (math.radians(65), 0, math.radians(-30))
    s.collection.objects.link(lo)

    exr = CACHE / "monitor_portatil.exr"
    s.render.filepath = str(exr)
    bpy.ops.render.render(write_still=True)
    p = ler_exr(exr)
    alfa = p["alfa"] if p["alfa"] is not None else np.ones_like(p["z"])
    opaco = alfa > 0.5
    p["z"] = np.where(opaco, p["z"], 1e4)
    borda = contorno(p) & opaco
    verde_ok = np.isin(p["indice"], [INDICE[n] for n in INDICE if "lampada" in n and "ambar" not in n])
    cor = np.where(opaco[..., None], p["cor"] / np.maximum(alfa[..., None], 1e-3), 0.0)
    q = quantizar(cor, verde_ok)
    escura = quantizar(PALETA_LAB_LIN[q] * 0.25, verde_ok)
    q = np.where(borda, escura, q)
    rgba = np.zeros((MON_H, MON_W, 4), np.uint8)
    rgba[..., :3] = PALETA_SRGB[q]
    rgba[..., 3] = np.where(opaco, 255, 0)
    rgba[~opaco, :3] = 0
    bpy.context.view_layer.update()
    return rgba, p


def salvar_png_rgba(caminho, rgba):
    caminho.parent.mkdir(parents=True, exist_ok=True)
    h, w, _ = rgba.shape
    out = oiio.ImageOutput.create(str(caminho))
    out.open(str(caminho), oiio.ImageSpec(w, h, 4, "uint8"))
    out.write_image(np.ascontiguousarray(rgba))
    out.close()


def regioes_monitor(rgba, p):
    """Retângulos do monitor, lidos da projeção ortográfica e conferidos com o alfa e o índice."""
    def proj(objs):
        pts = np.concatenate([pontos_do_objeto(o) for o in objs])
        x = MON_W / 2 + pts[:, 0] / (MON_W * MON_PX) * MON_W
        y = MON_H / 2 - pts[:, 2] / (MON_W * MON_PX) * MON_W
        return retangulo((x, y), MON_W, MON_H)

    tx0, tx1, tz0, tz1 = MON_TELA
    tela = {"x": MON_W // 2 + tx0, "y": MON_H // 2 - tz1, "w": tx1 - tx0, "h": tz1 - tz0}
    abaixar = proj(["abaixar_aro", "abaixar_anel", "abaixar_botao"])
    return tela, abaixar


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
        salvar_png(saida / f"{estado}{a.sufixo}.png", pngs[estado])
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

    # regiões
    linhas, ok = validar_regioes(reg)
    print("[comodo] regiões (x, y, largura, altura em px do panorama):")
    for nome, r in reg.items():
        print(f"[comodo]   {nome}: {r['x']}, {r['y']}, {r['w']}x{r['h']}")
    print("[comodo] validação das regiões:")
    print("\n".join(linhas))
    print(f"[comodo] validação: {'PASSA' if ok else 'FALHA'}")
    conferir_projecao(reg, passes[base], base)
    salvar_png(CACHE / "regioes_debug.png", desenhar_regioes(pngs[base], reg))
    print(f"[comodo] depuração: {CACHE / 'regioes_debug.png'}")

    # tamanho em px dos botões na escala 1x (a região inclui o aro)
    for nome in BOTOES:
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
    }

    if not a.sem_monitor:
        rgba, pm = monitor(a, saida)
        tela, abaixar = regioes_monitor(rgba, pm)
        salvar_png_rgba(saida / f"monitor_portatil{a.sufixo}.png", rgba)
        alfa0 = np.nonzero(rgba[..., 3] == 0)
        mt = (rgba[tela["y"]:tela["y"] + tela["h"], tela["x"]:tela["x"] + tela["w"], 3] == 0).all()
        print(f"[monitor] tela {tela} toda em alfa 0: {bool(mt)}; "
              f"px com alfa 0 no PNG: {len(alfa0[0])} (a tela tem {tela['w'] * tela['h']})")
        ys, xs = np.nonzero(np.isin(pm["indice"], [INDICE[n] for n in ("abaixar_aro", "abaixar_anel", "abaixar_botao")]))
        print(f"[monitor] abaixar projetado {abaixar} | visível "
              f"({xs.min()}, {ys.min()}, {xs.max() + 1}, {ys.max() + 1})")
        print(f"[monitor] tela {tela['w']}x{tela['h']} (16:9); abaixar {abaixar['w']}x{abaixar['h']} px")
        doc["monitor_portatil"] = {
            "arquivo": f"monitor_portatil{a.sufixo}.png", "largura": MON_W, "altura": MON_H,
            "tela": tela, "abaixar": abaixar,
            "tela_proporcao": "16:9 (320x180: a câmera externa de 640x360 cabe a 50%)"}
        fundo = np.where(rgba[..., 3:4] > 0, rgba[..., :3], 40).astype(np.uint8)
        dbg = np.repeat(np.repeat(fundo, 2, 0), 2, 1)
        for r_, cor in ((tela, (255, 255, 0)), (abaixar, (255, 0, 255))):
            x0, y0 = r_["x"] * 2, r_["y"] * 2
            x1, y1 = (r_["x"] + r_["w"]) * 2 - 1, (r_["y"] + r_["h"]) * 2 - 1
            dbg[y0:y1 + 1, [x0, x0 + 1, x1 - 1, x1]] = cor
            dbg[[y0, y0 + 1, y1 - 1, y1], x0:x1 + 1] = cor
        salvar_png(CACHE / "monitor_debug.png", dbg)
        print(f"[monitor] depuração: {CACHE / 'monitor_debug.png'}")

    (saida / f"regioes{a.sufixo}.json").write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n")
    print(f"[comodo] regiões: {saida / f'regioes{a.sufixo}.json'}")


if __name__ == "__main__":
    main()
