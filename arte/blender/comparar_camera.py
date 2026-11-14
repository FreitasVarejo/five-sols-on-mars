"""Compara câmera cilíndrica x perspectiva sob o shader de panorama do Godot.

Uso (da raiz do repo, Python do host com numpy e Pillow):
    python3 arte/blender/comparar_camera.py            # renderiza e compara
    python3 arte/blender/comparar_camera.py --sem-render

Renderiza o estado normal com as duas câmeras (1280x360) e as "verdades": uma
câmera perspectiva de 640x360 girada para onde cada janela de pan olha. Em cada
janela aplica a mesma conta do shader CC0 "Accurate FNAF Clickteam Panorama"
(shaders/panorama.gdshader) e mede quanto a borda de baixo da calha de cabos,
que é reta em 3D, se afasta de uma reta na tela.
"""

import argparse
import json
import math
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
CACHE = RAIZ / "arte" / "blender" / ".render"
SAIDA = CACHE / "camera"
SCRIPT = RAIZ / "arte" / "blender" / "comodo.py"

LARG, ALT, JANELA = 1280, 360, 640
RAD_PX = math.radians(180) / LARG
OFFSETS = (0, 320, 640)            # pan: esquerda, centro, direita


def render(camera, largura, sufixo, yaw=0.0):
    cmd = ["blender", "-b", "--factory-startup", "-P", str(SCRIPT), "--",
           "--estados", "normal", "--camera", camera, "--largura", str(largura),
           "--rad-por-px", repr(RAD_PX), "--yaw", repr(yaw),
           "--saida", str(SAIDA.relative_to(RAIZ)), "--sufixo", sufixo]
    out = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout
    print(*[l for l in out.splitlines() if l.startswith("[comodo] normal:")], sep="\n")


def yaw_da_janela(camera, off):
    d = off + JANELA / 2 - LARG / 2           # px do centro da janela ao centro do panorama
    return math.degrees(d * RAD_PX) if camera == "cilindrica" else math.degrees(math.atan(d * RAD_PX))


def shader(img, zoom):
    """A conta do shader do Godot (vertical=false, smoothed=true), com filtro Nearest."""
    h, w = img.shape[:2]
    u = (np.arange(w) + 0.5) / w
    v = (np.arange(h) + 0.5) / h
    fB = 1.0 - zoom * 0.0015
    fC = np.maximum(0.02, 1.0 + (fB - 1.0) * 4.0 * (u - 0.5) ** 2)
    pos_y = v[:, None] * fC[None, :] + (1.0 - fC[None, :]) * 0.5
    linhas = np.clip(np.floor(pos_y * h).astype(int), 0, h - 1)
    return img[linhas, np.arange(w)[None, :]]


def desvio_da_reta(indice, calhas):
    """Para cada trecho de calha (frente, esq, dir), maior desvio em px da borda de baixo
    em relação à reta que melhor se ajusta."""
    piores = []
    for k in calhas:
        xs, ys = [], []
        for x in range(indice.shape[1]):
            linhas = np.nonzero(indice[:, x] == k)[0]
            if len(linhas) >= 2:
                xs.append(x)
                ys.append(linhas.max())
        if len(xs) < 20:
            continue
        corte = len(xs) // 10                              # tira 10 % de cada ponta (cantos)
        xs, ys = np.array(xs[corte:-corte]), np.array(ys[corte:-corte])
        a, b = np.polyfit(xs, ys, 1)
        piores.append(np.abs(ys - (a * xs + b)).max())
    return max(piores) if piores else float("nan")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--sem-render", action="store_true")
    a = p.parse_args()
    SAIDA.mkdir(parents=True, exist_ok=True)

    yaws = sorted({round(yaw_da_janela(c, o), 3)
                   for c in ("cilindrica", "perspectiva") for o in OFFSETS})
    if not a.sem_render:
        render("cilindrica", LARG, "_cil")
        render("perspectiva", LARG, "_persp")
        for y in yaws:
            render("perspectiva", JANELA, f"_verdade_{y:+.1f}", y)

    idx = json.loads((CACHE / "indices.json").read_text())
    calhas = [idx[n] for n in ("calha_frente", "calha_esq", "calha_dir")]

    def carregar(suf):
        return (np.asarray(Image.open(SAIDA / f"normal{suf}.png").convert("RGB")),
                np.load(CACHE / f"normal{suf}_indice.npy"))

    fontes = {"cilindrica": carregar("_cil"), "perspectiva": carregar("_persp")}
    zooms = list(range(0, 301, 5))
    linhas_img = []
    print("\ndesvio máximo da calha em relação a uma reta (px), por janela de pan")
    print(f"{'fonte':12} {'janela':>7} {'yaw':>7} {'verdade':>8} {'sem shader':>10} "
          f"{'zoom 75':>8} {'melhor zoom':>12}")
    for camera, (rgb, ind) in fontes.items():
        for off in OFFSETS:
            y = yaw_da_janela(camera, off)
            v_rgb, v_ind = carregar(f"_verdade_{round(y, 3):+.1f}")
            jr, ji = rgb[:, off:off + JANELA], ind[:, off:off + JANELA]
            dv = desvio_da_reta(v_ind, calhas)
            d0 = desvio_da_reta(ji, calhas)
            d75 = desvio_da_reta(shader(ji, 75), calhas)
            por_zoom = [(desvio_da_reta(shader(ji, z), calhas), z) for z in zooms]
            dz, zb = min(por_zoom)
            print(f"{camera:12} {off:7d} {y:7.1f} {dv:8.1f} {d0:10.1f} {d75:8.1f} "
                  f"{dz:6.1f} @ {zb:3d}")
            linhas_img.append((camera, off, v_rgb, shader(jr, 75), shader(jr, 195)))

    # folha: por janela, verdade | cilíndrica+shader 75 | 195 | perspectiva+shader 75 | 195
    blocos = []
    for off in OFFSETS:
        cil = next(l for l in linhas_img if l[0] == "cilindrica" and l[1] == off)
        per = next(l for l in linhas_img if l[0] == "perspectiva" and l[1] == off)
        sep = np.zeros((ALT, 6, 3), np.uint8)
        blocos.append(np.concatenate([cil[2], sep, cil[3], sep, cil[4]], 1))
        blocos.append(np.concatenate([per[2], sep, per[3], sep, per[4]], 1))
        blocos.append(np.full((10, blocos[-1].shape[1], 3), 255, np.uint8))
    Image.fromarray(np.concatenate(blocos, 0)).save(SAIDA / "comparacao.png")
    print(f"\nfolha: {SAIDA / 'comparacao.png'}")
    print("linhas por janela: cilíndrica, perspectiva; colunas: verdade | shader zoom 75 | zoom 195")


main()
