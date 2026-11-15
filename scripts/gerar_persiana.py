"""Separa a persiana da janela dos PNGs do cômodo (Pillow, numpy e scipy).

Uso:
    ~/.local/bin/blender -b --factory-startup -P $PWD/arte/blender/comodo.py -- --estados abrigo,abrigo_aberto
    scripts/gerar_persiana.py

A persiana fica dentro do vão da janela, entre a moldura de aço e o vidro (arte/blender/comodo.py),
então a moldura e o montante central a tapam. O vidro (alfa 0 em normal.png) é o vão visto até o
fundo. Em volta dele, de 1 a 5 px, a persiana, mais rasa que o vidro, ainda aparece entre as
paredes internas da moldura (em normal.png ali se vê a parede da moldura). A máscara da persiana
é o vidro mais esse aro. O Blender renderiza o estado extra `abrigo_aberto` (mesma luz do abrigo,
sem a persiana, vidro em alfa 0) direto em assets/comodo/abrigo_aberto.png. Este script escreve em assets/comodo/:

- persiana.png: a persiana, ou seja, os pixels de abrigo.png dentro da máscara, o resto transparente;
- persiana_indice.png: em cinza, a lâmina de cada pixel da persiana (R = lâmina * 20 + 10, de 0 a 9;
  255 fora dela). O shader (shaders/persiana.gdshader) mostra só as lâminas até a do progresso;
- abrigo_aberto.png, reescrito: o render do Blender dentro da máscara (vidro em alfa 0, parede da
  moldura no aro) e abrigo.png fora dela.

A máscara é o pedaço conectado de pixels em que abrigo.png e o render sem persiana diferem,
até ARO px do vidro. Os dois renders diferem também mais longe (a luz que a persiana reflete e o
ruído): esses pixels ficam fora da máscara, e ali o abrigo_aberto copia o abrigo, para a camada
sobre ele refazer o abrigo.png pixel a pixel. O script diz quantos são.

A persiana tem N_PERSIANA = 10 lâminas (arte/blender/comodo.py), separadas por 9 linhas escuras de
1 px. Em cada linha, acha os pixels escuros perto da posição esperada, ajusta uma curva suave
(polinômio, descartando os pontos fora da curva) e cola a linha no pixel escuro mais próximo da
curva. A linha (de 1 ou 2 px, conta o último) pertence à lâmina de cima. No aro, fora das colunas
do vidro, a linha vem das colunas vizinhas e cada pixel fica na lâmina da mesma altura. Falha se
alguma coluna de vidro ficar sem as 10 lâminas.
"""
import sys
from pathlib import Path

import numpy as np
import scipy.ndimage as ndi
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
COMODO = RAIZ / "assets" / "comodo"
N_LAMINAS = 10
COLUNA_REFERENCIA = 620  # coluna em que as 9 linhas aparecem inteiras
LIMIAR_ESCURO = 125  # soma de R+G+B até aqui é linha entre lâminas (de 1 ou 2 px)
JANELA = 5  # px, de busca em volta da posição esperada
GRAU = 4
TOLERANCIA = 1.2  # px, entre o ponto e a curva
ARO = 6  # px em volta do vidro onde ainda se procura persiana (0 = só o vidro)


def carregar(nome):
    return np.array(Image.open(COMODO / nome).convert("RGBA"))


def limites_do_vidro(vidro):
    """Primeira e última linha do vidro em cada coluna (0 onde não há vidro)."""
    tem = vidro.any(axis=0)
    topo = np.where(tem, vidro.argmax(axis=0), 0)
    base = np.where(tem, vidro.shape[0] - 1 - vidro[::-1].argmax(axis=0), 0)
    return tem, topo, base


def linhas_entre_laminas(abrigo, vidro, mascara):
    """Matriz [N_LAMINAS - 1, largura]: a linha (y) de cada divisória em cada coluna da máscara."""
    escuro = abrigo[:, :, :3].astype(int).sum(axis=2) <= LIMIAR_ESCURO
    tem, topo, base = limites_do_vidro(vidro)
    colunas = np.where(tem)[0]
    altura = (base - topo + 1).astype(float)
    xr = COLUNA_REFERENCIA
    ref = [y for y in range(topo[xr], base[xr] + 1) if escuro[y, xr] and not escuro[y + 1, xr]]
    if len(ref) != N_LAMINAS - 1:
        sys.exit("coluna %d tem %d linhas escuras, esperava %d" % (xr, len(ref), N_LAMINAS - 1))
    todas = np.arange(abrigo.shape[1])
    colunas_mascara = np.where(mascara.any(axis=0))[0]
    linhas = np.zeros((N_LAMINAS - 1, abrigo.shape[1]))
    for k, r in enumerate(ref):
        esperada = topo + (r - topo[xr]) / altura[xr] * altura
        xs, ds = [], []
        for x in colunas:
            achados = [y for y in range(topo[x], base[x] + 1)
                       if escuro[y, x] and not escuro[y + 1, x] and abs(y - esperada[x]) <= JANELA]
            if achados:
                xs.append(x)
                ds.append(min(achados, key=lambda y: abs(y - esperada[x])) - esperada[x])
        xs, ds = np.array(xs, float), np.array(ds)
        manter = np.ones(len(xs), bool)
        for _ in range(6):
            coef = np.polyfit(xs[manter], ds[manter], GRAU)
            manter = np.abs(ds - np.polyval(coef, xs)) <= TOLERANCIA
        curva = esperada + np.polyval(coef, todas)
        # no aro, fora das colunas do vidro: a curva das colunas vizinhas
        curva = np.where(tem, curva, np.interp(todas, colunas, curva[colunas]))
        for x in colunas_mascara:
            ys = np.where(mascara[:, x])[0]
            perto = [y for y in range(int(curva[x]) - 1, int(curva[x]) + 3)
                     if ys[0] <= y <= ys[-1] and escuro[y, x] and not escuro[y + 1, x]
                     and abs(y - curva[x]) <= (1.5 if tem[x] else 2.0)]
            linhas[k, x] = min(perto, key=lambda y: abs(y - curva[x])) if perto else round(curva[x])
    return linhas


def mascara_da_persiana(abrigo, aberto, vidro):
    """O vidro mais o aro em volta dele (menos o montante) onde abrigo.png e o render sem persiana diferem (o maior
    pedaço conectado de cada vão, para largar pontos soltos de luz e ruído)."""
    perto = ndi.binary_dilation(vidro, structure=np.ones((3, 3)), iterations=ARO)
    # o montante, entre os dois vãos, é só moldura: nenhum pixel da persiana ali
    cols = np.where(vidro.any(axis=0))[0]
    montante = np.zeros_like(vidro)
    montante[:, cols[0]:cols[-1] + 1] = True
    perto &= ~(montante & ~vidro.any(axis=0)[None, :])
    candidatos = ndi.binary_fill_holes(((abrigo != aberto).any(axis=2) & perto) | vidro)
    rotulos, n = ndi.label(candidatos, structure=np.ones((3, 3)))
    # um pedaço por vão (o montante separa os dois); o que não toca o vidro é ruído
    com_vidro = np.unique(rotulos[vidro])
    return np.isin(rotulos, com_vidro[com_vidro > 0])


def indice_das_laminas(abrigo, vidro, mascara):
    """Matriz [altura, largura] com a lâmina (0 a 9) de cada pixel da máscara, e 255 fora dela."""
    linhas = linhas_entre_laminas(abrigo, vidro, mascara)
    indice = np.full(vidro.shape, 255, np.uint8)
    for x in np.where(mascara.any(axis=0))[0]:
        divisorias = np.sort(linhas[:, x]) + 1  # a linha é da lâmina de cima
        ys = np.where(mascara[:, x])[0]
        lamina = np.searchsorted(divisorias, ys, side="right")
        if vidro[:, x].any() and len(set(lamina)) != N_LAMINAS:
            sys.exit("coluna %d ficou com %d lâminas, esperava %d" % (x, len(set(lamina)), N_LAMINAS))
        indice[ys, x] = lamina
    return indice


def main():
    normal = carregar("normal.png")
    abrigo = carregar("abrigo.png")
    aberto = carregar("abrigo_aberto.png")  # o render do Blender (ou o que este script já limpou)
    vidro = normal[:, :, 3] == 0
    if not (abrigo[:, :, 3][vidro] == 255).all():
        sys.exit("o vidro de normal.png tem pixel que não é opaco em abrigo.png")
    if not ((aberto[:, :, 3] == 0) == vidro).all():
        sys.exit("o vidro de abrigo_aberto.png não bate com o de normal.png: rode o Blender antes")

    mascara = mascara_da_persiana(abrigo, aberto, vidro)
    fora = int(((abrigo != aberto).any(axis=2) & ~mascara).sum())
    indice = indice_das_laminas(abrigo, vidro, mascara)

    persiana = np.zeros_like(abrigo)
    persiana[mascara] = abrigo[mascara]
    Image.fromarray(persiana, "RGBA").save(COMODO / "persiana.png", optimize=True)

    cinza = np.where(mascara, indice.astype(int) * 20 + 10, 255).astype(np.uint8)
    Image.fromarray(cinza, "L").save(COMODO / "persiana_indice.png", optimize=True)

    limpo = np.where(mascara[:, :, None], aberto, abrigo)
    Image.fromarray(limpo.astype(np.uint8), "RGBA").save(COMODO / "abrigo_aberto.png", optimize=True)

    print("%d px de persiana (%d de vidro e %d de aro); %d px diferem fora dela e ficam de fora; "
          "escrito em %s" % (mascara.sum(), vidro.sum(), (mascara & ~vidro).sum(), fora, COMODO))


if __name__ == "__main__":
    main()
