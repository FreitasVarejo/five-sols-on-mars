"""Gera o módulo de comando do zero e renderiza um PNG em pixel art por estado.

Uso (da raiz do repo):
    blender -b --factory-startup -P arte/blender/comodo.py
    blender -b --factory-startup -P arte/blender/comodo.py -- --estados normal --camera perspectiva

Fonte da verdade: este script. Nenhum .blend é salvo nem lido.
Mesma geometria e mesma câmera em todos os estados; o estado muda só luz e emissão.

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


def construir():
    """Gray-box do módulo de comando. Unidades em metros; o olho fica em OLHO."""
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
    armario = material("armario", hexrgb("577277"))

    i = iter(range(1, 200))
    caixa("piso", (0, 1, -0.05), (2 * W, 4, 0.1), piso, next(i))
    caixa("teto", (0, 1, H + 0.05), (2 * W, 4, 0.1), teto, next(i))
    caixa("parede_frente", (0, F + 0.05, H / 2), (2 * W, 0.1, H), parede, next(i))
    caixa("parede_esq", (-W - 0.05, 1, H / 2), (0.1, 4, H), parede, next(i))
    caixa("parede_dir", (W + 0.05, 1, H / 2), (0.1, 4, H), parede, next(i))

    # nervuras verticais nas paredes (dão leitura de profundidade ao contorno);
    # param na calha, para não furar a linha reta que mede a câmera
    hn = 1.99
    for x in (-2.0, 2.0):
        caixa(f"nervura_f{x}", (x, F - 0.04, hn / 2), (0.12, 0.08, hn), nervura, next(i))
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

    # console: mesa + painel inclinado voltado para o olho
    caixa("console_mesa", (0, 1.25, 0.4), (3.2, 0.7, 0.8), console, next(i))
    caixa("console_painel", (0, 1.5, 0.95), (3.2, 0.45, 0.06), painel, next(i), rot=(35, 0, 0))

    # botões grandes no painel inclinado
    cores_botao = {"botao_painel": "75a743", "botao_gerador": "4f8fba",
                   "botao_ciencia": "c65197", "botao_abrigo": "cf573c"}
    for k, (nome, cor) in enumerate(cores_botao.items()):
        x = -0.75 + k * 0.5
        # a cor do botão vem da emissão; o difuso escuro e sem especular não estoura
        mb = material(nome, tuple(c * 0.35 for c in hexrgb(cor)), 0.9)
        mb.node_tree.nodes["Principled BSDF"].inputs["Specular IOR Level"].default_value = 0.0
        COR_BOTAO[nome] = hexrgb(cor)
        caixa(f"{nome}_aro", (x, 1.48, 1.0), (0.2, 0.2, 0.04), moldura, next(i), rot=(35, 0, 0))
        caixa(nome, (x, 1.47, 1.015), (0.15, 0.15, 0.05), mb, next(i), rot=(35, 0, 0))

    # 4 monitores de câmera na parede da frente
    telas = [("tela_painel", "4f8fba", "ad7757"), ("tela_rocha", "73bed3", "7a4841"),
             ("tela_amostra", "4f8fba", "c09473"), ("tela_moxie", "73bed3", "884b2b")]
    for k, (nome, ceu, chao) in enumerate(telas):
        x = -1.35 + k * 0.9
        caixa(f"{nome}_moldura", (x, F - 0.06, 1.55), (0.78, 0.08, 0.56), moldura, next(i))
        caixa(nome, (x, F - 0.105, 1.55), (0.66, 0.02, 0.44),
              tela_horizonte(nome, ceu, chao, 0.45), next(i))

    # porta do abrigo, parede esquerda
    py = 0.95
    caixa("porta_moldura_topo", (-W + 0.05, py, 2.0), (0.1, 1.2, 0.15), moldura, next(i))
    caixa("porta_moldura_tras", (-W + 0.05, py - 0.55, 1.0), (0.1, 0.12, 2.0), moldura, next(i))
    caixa("porta_moldura_frente", (-W + 0.05, py + 0.55, 1.0), (0.1, 0.12, 2.0), moldura, next(i))
    caixa("porta_folha", (-W + 0.03, py, 0.97), (0.06, 0.98, 1.9), porta, next(i))
    caixa("porta_faixa", (-W + 0.07, py, 1.55), (0.04, 0.98, 0.12), faixa, next(i))
    toro("porta_volante", (-W + 0.12, py, 1.05), 0.22, 0.03, moldura, next(i), rot=(0, 90, 0))
    caixa("porta_lampada", (-W + 0.06, py, 2.2), (0.08, 0.3, 0.1), lampada_porta, next(i))

    # janela para fora e armário, parede direita
    caixa("janela_moldura", (W - 0.05, 1.2, 1.35), (0.1, 1.0, 0.7), moldura, next(i))
    caixa("janela", (W - 0.11, 1.2, 1.35), (0.02, 0.84, 0.54), janela, next(i))
    caixa("armario", (W - 0.25, 0.25, 0.8), (0.5, 0.6, 1.6), armario, next(i))

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
    """Só luz e emissão. Nada de geometria, material base ou câmera."""
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
            telas=1.0, janela=1.2, botoes=0.25, lampada_porta=(verde, 0.5), mundo=0.02),
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

    return {
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
OBJETOS_VERDES = ("botao_painel", "porta_lampada")


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
        verde_ok = np.isin(p["indice"], [INDICE[n] for n in OBJETOS_VERDES])
    q = quantizar(p["cor"], verde_ok)
    # traço: a cor da paleta mais próxima de 25 % do brilho do pixel por baixo
    escura = quantizar(PALETA_LAB_LIN[q] * 0.25, verde_ok)
    q = np.where(borda, escura, q)
    return PALETA_SRGB[q]


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


def main():
    a = args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    luzes = construir()
    rad_px = configurar(a)
    estados = [e for e in a.estados.split(",") if e]
    CACHE.mkdir(parents=True, exist_ok=True)
    (CACHE / ".gdignore").touch()
    saida = RAIZ / a.saida

    passes = {}
    for estado in estados:
        aplicar_estado(estado, luzes)
        exr = CACHE / f"{estado}{a.sufixo}.exr"
        bpy.context.scene.render.filepath = str(exr)
        bpy.ops.render.render(write_still=True)
        p = ler_exr(exr)
        passes[estado] = p
        borda = contorno(p)
        salvar_png(saida / f"{estado}{a.sufixo}.png", pixel_art(p, borda, estado))
        np.save(CACHE / f"{estado}{a.sufixo}_indice.npy", p["indice"])
        print(f"[comodo] {estado}: {saida / f'{estado}{a.sufixo}.png'}")

    (CACHE / "indices.json").write_text(json.dumps(INDICE, indent=1))

    # a geometria não pode mudar entre estados: profundidade, normal e índice idênticos
    base = estados[0]
    for e in estados[1:]:
        dz = np.abs(passes[e]["z"] - passes[base]["z"]).max()
        dn = np.abs(passes[e]["normal"] - passes[base]["normal"]).max()
        di = int((passes[e]["indice"] != passes[base]["indice"]).sum())
        db = int((contorno(passes[e]) != contorno(passes[base])).sum())
        print(f"[comodo] {base} x {e}: max|Δz|={dz:.2e} max|Δnormal|={dn:.2e} "
              f"px índice diferente={di} px contorno diferente={db}")

    # tamanho em px dos botões na escala 1x
    for nome, k in INDICE.items():
        if nome.startswith("botao_") and not nome.endswith("_aro"):
            ys, xs = np.nonzero(passes[base]["indice"] == k)
            if len(xs):
                print(f"[comodo] {nome}: {xs.max() - xs.min() + 1}x{ys.max() - ys.min() + 1} px "
                      f"(incluindo o aro: ver {nome}_aro)")
    print(f"[comodo] rad_por_px={rad_px:.6f} câmera={a.camera} yaw={a.yaw}")


main()
