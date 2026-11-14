#!/usr/bin/env python3
"""Separa a persiana da janela dos PNGs do cômodo (Pillow e numpy).

Uso: scripts/gerar_persiana.py

Lê assets/comodo/normal.png e abrigo.png. O vidro da janela tem alfa 0 em normal.png e é opaco em
abrigo.png, onde ali está a persiana fechada. Escreve em assets/comodo/:

- persiana.png: a persiana (pixels de abrigo.png sob o vidro), o resto transparente;
- persiana_indice.png: em cinza, a lâmina de cada pixel da persiana (R = lâmina * 20 + 10, de 0 a 9;
  255 fora dela). O shader (shaders/persiana.gdshader) mostra só as lâminas até a do progresso;
- abrigo_aberto.png: abrigo.png com o vidro em alfa 0, para a persiana vir da camada.

A persiana tem N_PERSIANA = 10 lâminas (arte/blender/comodo.py), separadas por 9 linhas escuras de
1 px. Em cada linha, acha os pixels escuros perto da posição esperada, ajusta uma curva suave
(polinômio, descartando os pontos fora da curva) e cola a linha no pixel escuro mais próximo da
curva. A linha pertence à lâmina de cima. Falha se alguma coluna ficar sem as 10 lâminas.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
COMODO = RAIZ / "assets" / "comodo"
N_LAMINAS = 10
COLUNA_REFERENCIA = 620  # coluna em que as 9 linhas aparecem inteiras
LIMIAR_ESCURO = 90  # soma de R+G+B até aqui é linha entre lâminas
JANELA = 5  # px, de busca em volta da posição esperada
GRAU = 4
TOLERANCIA = 1.2  # px, entre o ponto e a curva


def carregar(nome):
    return np.array(Image.open(COMODO / nome).convert("RGBA"))


def limites_do_vidro(vidro):
    """Primeira e última linha do vidro em cada coluna (0 onde não há vidro)."""
    tem = vidro.any(axis=0)
    topo = np.where(tem, vidro.argmax(axis=0), 0)
    base = np.where(tem, vidro.shape[0] - 1 - vidro[::-1].argmax(axis=0), 0)
    return tem, topo, base


def linhas_entre_laminas(abrigo, vidro):
    """Matriz [N_LAMINAS - 1, largura]: a linha (y) de cada divisória em cada coluna do vidro."""
    escuro = abrigo[:, :, :3].astype(int).sum(axis=2) <= LIMIAR_ESCURO
    tem, topo, base = limites_do_vidro(vidro)
    colunas = np.where(tem)[0]
    altura = (base - topo + 1).astype(float)
    xr = COLUNA_REFERENCIA
    ref = [y for y in range(topo[xr], base[xr] + 1) if escuro[y, xr]]
    if len(ref) != N_LAMINAS - 1:
        sys.exit("coluna %d tem %d linhas escuras, esperava %d" % (xr, len(ref), N_LAMINAS - 1))
    todas = np.arange(abrigo.shape[1])
    linhas = np.zeros((N_LAMINAS - 1, abrigo.shape[1]))
    for k, r in enumerate(ref):
        esperada = topo + (r - topo[xr]) / altura[xr] * altura
        xs, ds = [], []
        for x in colunas:
            achados = [y for y in range(topo[x], base[x] + 1)
                       if escuro[y, x] and abs(y - esperada[x]) <= JANELA]
            if achados:
                xs.append(x)
                ds.append(min(achados, key=lambda y: abs(y - esperada[x])) - esperada[x])
        xs, ds = np.array(xs, float), np.array(ds)
        manter = np.ones(len(xs), bool)
        for _ in range(6):
            coef = np.polyfit(xs[manter], ds[manter], GRAU)
            manter = np.abs(ds - np.polyval(coef, xs)) <= TOLERANCIA
        curva = esperada + np.polyval(coef, todas)
        for x in colunas:
            perto = [y for y in range(int(curva[x]) - 1, int(curva[x]) + 3)
                     if topo[x] <= y <= base[x] and escuro[y, x] and abs(y - curva[x]) <= 1.5]
            linhas[k, x] = min(perto, key=lambda y: abs(y - curva[x])) if perto else round(curva[x])
    return linhas


def indice_das_laminas(abrigo, vidro):
    """Matriz [altura, largura] com a lâmina (0 a 9) de cada pixel do vidro, e 255 fora dele."""
    linhas = linhas_entre_laminas(abrigo, vidro)
    tem, topo, base = limites_do_vidro(vidro)
    indice = np.full(vidro.shape, 255, np.uint8)
    for x in np.where(tem)[0]:
        divisorias = np.sort(linhas[:, x]) + 1  # a linha é da lâmina de cima
        ys = np.where(vidro[:, x])[0]
        lamina = np.searchsorted(divisorias, ys, side="right")
        if len(set(lamina)) != N_LAMINAS:
            sys.exit("coluna %d ficou com %d lâminas, esperava %d" % (x, len(set(lamina)), N_LAMINAS))
        indice[ys, x] = lamina
    return indice


def main():
    normal = carregar("normal.png")
    abrigo = carregar("abrigo.png")
    vidro = normal[:, :, 3] == 0
    if not (abrigo[:, :, 3][vidro] == 255).all():
        sys.exit("o vidro de normal.png tem pixel que não é opaco em abrigo.png")

    indice = indice_das_laminas(abrigo, vidro)

    persiana = np.zeros_like(abrigo)
    persiana[vidro] = abrigo[vidro]
    Image.fromarray(persiana, "RGBA").save(COMODO / "persiana.png", optimize=True)

    cinza = np.where(vidro, indice.astype(int) * 20 + 10, 255).astype(np.uint8)
    Image.fromarray(cinza, "L").save(COMODO / "persiana_indice.png", optimize=True)

    aberto = abrigo.copy()
    aberto[vidro] = 0
    Image.fromarray(aberto, "RGBA").save(COMODO / "abrigo_aberto.png", optimize=True)

    print("%d px de persiana, %d lâminas, escrito em %s" % (vidro.sum(), N_LAMINAS, COMODO))


if __name__ == "__main__":
    main()
