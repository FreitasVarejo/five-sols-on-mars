#!/usr/bin/env python3
"""Leva uma foto da NASA à paleta dos renders do jogo (Pillow e numpy, sem IA).

Uso:
    python3 scripts/reduzir_foto.py ORIGINAL.jpg SAIDA.png --recorte ESQ,TOPO,DIR,BAIXO --largura 200

O original fica fora do repo; só a saída entra, em assets/fotos/<tarefa>.png. Passos:
1. recorta o retângulo `--recorte` (px do original; sem ele, a foto inteira);
2. reduz até `--largura` px, com a altura na mesma proporção, pelo filtro `--filtro` (padrão: box, que tira a
   média de cada bloco; `nearest` pega um pixel só de cada bloco e, de uma foto de milhares de px, sai
   cheio de ruído);
3. leva cada pixel à cor mais próxima da Apollo (AdamCYounis, https://lospec.com/palette-list/apollo), a
   mesma paleta dos renders, medida em OKLab como em arte/blender/comodo.py. Sem pontilhado.

A foto sai opaca, em RGB. No jogo ela é desenhada com o filtro Nearest (o do projeto), sem suavizar.
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image

# Apollo, AdamCYounis (a mesma lista de APOLLO em arte/blender/comodo.py, que não se importa daqui por
# depender do bpy).
APOLLO = (
    "172038 253a5e 3c5e8b 4f8fba 73bed3 a4dddb 19332d 25562e 468232 75a743 "
    "a8ca58 d0da91 4d2b32 7a4841 ad7757 c09473 d7b594 e7d5b3 341c27 602c2c "
    "884b2b be772b de9e41 e8c170 241527 411d31 752438 a53030 cf573c da863e "
    "1e1d39 402751 7a367b a23e8c c65197 df84a5 090a14 10141f 151d28 202e37 "
    "394a50 577277 819796 a8b5b2 c7cfcc ebede9"
).split()

FILTROS = {"nearest": Image.NEAREST, "box": Image.BOX}


def srgb_para_oklab(rgb: np.ndarray) -> np.ndarray:
    """sRGB (0 a 1, forma (..., 3)) -> OKLab."""
    lin = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    m1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929],
                   [0.2119034982, 0.6806995451, 0.1073969566],
                   [0.0883024619, 0.2817188376, 0.6299787005]])
    m2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468],
                   [1.9779984951, -2.4285922050, 0.4505937099],
                   [0.0259040371, 0.7827717662, -0.8086757660]])
    lms = np.cbrt(lin @ m1.T)
    return lms @ m2.T


def para_a_paleta(im: Image.Image) -> Image.Image:
    """Cada pixel vira a cor mais próxima da Apollo em OKLab."""
    paleta = np.array([[int(h[i:i + 2], 16) for i in (0, 2, 4)] for h in APOLLO], np.uint8)
    lab_paleta = srgb_para_oklab(paleta / 255.0)
    rgb = np.asarray(im.convert("RGB"), np.float64) / 255.0
    lab = srgb_para_oklab(rgb)
    d = ((lab[:, :, None, :] - lab_paleta[None, None]) ** 2).sum(-1)
    return Image.fromarray(paleta[d.argmin(-1)], "RGB")


def reduzir(origem: Path, saida: Path, recorte: tuple | None, largura: int, filtro: str) -> Image.Image:
    im = Image.open(origem).convert("RGB")
    if recorte is not None:
        im = im.crop(recorte)
    altura = max(1, round(im.height * largura / im.width))
    im = im.resize((largura, altura), FILTROS[filtro])
    im = para_a_paleta(im)
    saida.parent.mkdir(parents=True, exist_ok=True)
    im.save(saida, optimize=True)
    return im


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("original", type=Path)
    p.add_argument("saida", type=Path)
    p.add_argument("--recorte", help="ESQ,TOPO,DIR,BAIXO em px do original")
    p.add_argument("--largura", type=int, default=200)
    p.add_argument("--filtro", choices=sorted(FILTROS), default="box")
    a = p.parse_args()
    recorte = tuple(int(v) for v in a.recorte.split(",")) if a.recorte else None
    if recorte is not None and len(recorte) != 4:
        p.error("--recorte pede quatro números: ESQ,TOPO,DIR,BAIXO")
    im = reduzir(a.original, a.saida, recorte, a.largura, a.filtro)
    print(f"{a.saida}: {im.width}x{im.height}")


if __name__ == "__main__":
    main()
