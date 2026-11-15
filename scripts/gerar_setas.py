#!/usr/bin/env python3
"""Gera as setas do pan em assets/ui/ (Pillow e numpy).

Uso: scripts/gerar_setas.py

Cada PNG tem 48 x 120 px, o tamanho da área de toque no main.tscn. A aba visível é mais estreita
(LARGURA_ABA x ALTURA_ABA), colada à borda da tela: fundo MOLDURA a ~80% de alfa, borda de 1 px BORDA
nos lados de dentro e os cantos de dentro chanfrados em degraus de pixel. No meio, um chevron grosso.
Estados: normal (VERDE), pressionado (VERDE_ESCURO, 1 px mais perto da borda) e desabilitado
(CELULA_VAZIA). A seta direita é a esquerda espelhada. As cores são as de scripts/desenho.gd.
"""
from pathlib import Path

import numpy as np
from PIL import Image

LARGURA, ALTURA = 48, 120
LARGURA_ABA, ALTURA_ABA = 36, 104
CHANFRO = 4  # degraus de pixel nos cantos de dentro
CHEVRON_L, CHEVRON_A, TRACO = 14, 28, 5  # 5 px na horizontal, uns 4 px na perpendicular da diagonal

MOLDURA = (0x0B, 0x0F, 0x14)
BORDA = (0x3D, 0x4F, 0x5A)
VERDE = (0x7E, 0xD9, 0x57)
VERDE_ESCURO = (0x3F, 0x8A, 0x2A)
CELULA_VAZIA = (0x3D, 0x4F, 0x5A)
ALFA_ABA = 204  # 80%

DESTINO = Path(__file__).resolve().parent.parent / "assets" / "ui"


def mascara_da_aba() -> np.ndarray:
    """A aba da seta esquerda: True onde há aba. Cantos de dentro (direita) chanfrados."""
    m = np.zeros((ALTURA, LARGURA), bool)
    y0 = (ALTURA - ALTURA_ABA) // 2
    m[y0:y0 + ALTURA_ABA, :LARGURA_ABA] = True
    for k in range(CHANFRO):
        corte = CHANFRO - k  # a linha k de cada ponta perde `corte` px à direita
        m[y0 + k, LARGURA_ABA - corte:LARGURA_ABA] = False
        m[y0 + ALTURA_ABA - 1 - k, LARGURA_ABA - corte:LARGURA_ABA] = False
    return m


def mascara_do_chevron(deslocar: int) -> np.ndarray:
    """Chevron "<" de CHEVRON_L x CHEVRON_A, traço horizontal de TRACO px, no centro da aba."""
    m = np.zeros((ALTURA, LARGURA), bool)
    meia = CHEVRON_A // 2
    x_base = (LARGURA_ABA - CHEVRON_L) // 2 + deslocar
    y_base = (ALTURA - CHEVRON_A) // 2
    alcance = CHEVRON_L - TRACO
    for y in range(CHEVRON_A):
        d = min(y, CHEVRON_A - 1 - y)  # 0 na ponta de cima/baixo, meia-1 no meio
        x0 = x_base + round(alcance * (meia - 1 - d) / (meia - 1))
        m[y_base + y, x0:x0 + TRACO] = True
    return m


def imagem(cor_chevron, deslocar: int = 0) -> Image.Image:
    aba = mascara_da_aba()
    # A borda: pixels da aba com vizinho fora dela, menos os do lado da borda da tela (x = 0).
    dentro = np.pad(aba, 1, constant_values=False)
    dentro[:, 0] = True  # o que está além da borda esquerda da tela não conta como "fora"
    vizinhos = dentro[:-2, 1:-1] & dentro[2:, 1:-1] & dentro[1:-1, :-2] & dentro[1:-1, 2:]
    borda = aba & ~vizinhos
    px = np.zeros((ALTURA, LARGURA, 4), np.uint8)
    px[aba] = (*MOLDURA, ALFA_ABA)
    px[borda] = (*BORDA, 255)
    px[mascara_do_chevron(deslocar)] = (*cor_chevron, 255)
    return Image.fromarray(px, "RGBA")


def main() -> None:
    DESTINO.mkdir(parents=True, exist_ok=True)
    estados = {"": (VERDE, 0), "_pressed": (VERDE_ESCURO, -1), "_disabled": (CELULA_VAZIA, 0)}
    for sufixo, (cor, desloc) in estados.items():
        esq = imagem(cor, desloc)
        esq.save(DESTINO / f"seta_esquerda{sufixo}.png")
        esq.transpose(Image.FLIP_LEFT_RIGHT).save(DESTINO / f"seta_direita{sufixo}.png")
    print(f"6 PNGs em {DESTINO}")


if __name__ == "__main__":
    main()
