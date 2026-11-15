#!/usr/bin/env python3
"""Desenha o ícone do jogo (favicon da aba) e a imagem da tela de abertura, em pixel art.

Uso: python3 scripts/gerar_icone_e_abertura.py

Escreve:
- assets/icone.png: Marte em 32x32, ampliado 8x sem filtro (256x256), fundo transparente.
  É o application/config/icon; o export Web tira dele o index.icon.png (a aba) e o ícone da Apple.
- assets/abertura.png: céu de Marte à noite, o planeta, Fobos e o nome do jogo, em 320x180
  ampliado 2x (640x360). É o application/boot_splash/image: aparece enquanto o jogo carrega.

Determinístico: rodar de novo dá os mesmos pixels.
"""
import math
import random
from pathlib import Path

from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent

NOITE = (16, 20, 31)  # Desenho.NOITE
TEXTO = (232, 240, 242)  # Desenho.TEXTO
TEXTO_SUAVE = (169, 184, 191)  # Desenho.TEXTO_SUAVE
CONTORNO = (36, 16, 18)

# Tons do solo, do mais claro ao mais escuro (tirados do exterior renderizado).
SOLO = [(246, 178, 98), (226, 132, 64), (190, 92, 46), (138, 60, 38), (82, 36, 32)]
# Tons das regiões escuras (Syrtis, Acidalia), um degrau abaixo do solo.
ESCURO = [(196, 112, 62), (166, 78, 44), (126, 54, 36), (92, 40, 32), (58, 26, 28)]
GELO = [(250, 246, 238), (226, 214, 204), (178, 160, 156), (120, 100, 104), (70, 56, 62)]

BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

LUZ = (-0.62, -0.5, 0.6)
_n = math.sqrt(sum(c * c for c in LUZ))
LUZ = tuple(c / _n for c in LUZ)


def _hash(ix, iy, semente):
    h = (ix * 374761393 + iy * 668265263 + semente * 2147483647) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 0xFFFF


def _ruido(x, y, semente):
    """Ruído de valor suave em [0, 1]."""
    ix, iy = math.floor(x), math.floor(y)
    fx, fy = x - ix, y - iy
    sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = _hash(ix, iy, semente)
    b = _hash(ix + 1, iy, semente)
    c = _hash(ix, iy + 1, semente)
    d = _hash(ix + 1, iy + 1, semente)
    return (a + (b - a) * sx) + ((c + (d - c) * sx) - (a + (b - a) * sx)) * sy


def _fbm(x, y, semente):
    return 0.6 * _ruido(x, y, semente) + 0.3 * _ruido(2 * x, 2 * y, semente + 1) + 0.1 * _ruido(4 * x, 4 * y, semente + 2)


def desenhar_marte(img, cx, cy, raio, contorno=True, detalhe=1.0, pontilhado=True, calota_lat=-1.08):
    """Planeta com luz de cima à esquerda, tons em degraus com pontilhado, regiões escuras e calota polar."""
    px = img.load()
    r_borda = raio + (1 if contorno else 0)
    for y in range(int(cy - r_borda) - 1, int(cy + r_borda) + 2):
        for x in range(int(cx - r_borda) - 1, int(cx + r_borda) + 2):
            dx = (x + 0.5 - cx) / raio
            dy = (y + 0.5 - cy) / raio
            d2 = dx * dx + dy * dy
            if d2 > 1.0:
                if contorno and math.sqrt(d2) <= (raio + 1.0) / raio:
                    px[x, y] = CONTORNO + (255,)
                continue
            nz = math.sqrt(1.0 - d2)
            luz = dx * LUZ[0] + dy * LUZ[1] + nz * LUZ[2]
            luz = max(0.0, luz) * 0.9 + 0.1
            # Coordenadas da superfície (gira um pouco para as manchas não ficarem no centro).
            lon = math.atan2(dx, nz) + 0.4
            lat = math.asin(max(-1.0, min(1.0, dy)))
            u, v = lon * 1.6 * detalhe, lat * 1.9 * detalhe
            n = _fbm(u + 3.0, v + 7.0, 11)
            mancha = n > 0.56
            # Calota polar no norte, com a borda ruidosa.
            calota = lat < calota_lat + 0.12 * _ruido(lon * 4, 1.0, 5)
            paleta = GELO if calota else (ESCURO if mancha else SOLO)
            # Degraus de luz com pontilhado Bayer entre eles.
            t = (1.0 - luz) * (len(paleta) - 1)
            base = int(t)
            frac = t - base
            limiar = (BAYER4[y % 4][x % 4] + 0.5) / 16 if pontilhado else 0.5
            i = min(len(paleta) - 1, base + (1 if frac > limiar else 0))
            px[x, y] = paleta[i] + (255,)


def icone():
    lado = 32
    img = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    desenhar_marte(img, 16, 16, 14.5, contorno=True, detalhe=0.8, pontilhado=False, calota_lat=-0.9)
    return img.resize((lado * 8, lado * 8), Image.NEAREST)


# Fonte bitmap 5x7 só com as letras do nome do jogo (bit mais à esquerda = coluna 0).
FONTE = {
    "A": ("01110", "10001", "10001", "11111", "10001", "10001", "10001"),
    "E": ("11111", "10000", "10000", "11110", "10000", "10000", "11111"),
    "F": ("11111", "10000", "10000", "11110", "10000", "10000", "10000"),
    "I": ("11111", "00100", "00100", "00100", "00100", "00100", "11111"),
    "L": ("10000", "10000", "10000", "10000", "10000", "10000", "11111"),
    "M": ("10001", "11011", "10101", "10101", "10001", "10001", "10001"),
    "N": ("10001", "11001", "10101", "10011", "10001", "10001", "10001"),
    "O": ("01110", "10001", "10001", "10001", "10001", "10001", "01110"),
    "R": ("11110", "10001", "10001", "11110", "10100", "10010", "10001"),
    "S": ("01111", "10000", "10000", "01110", "00001", "00001", "11110"),
    "V": ("10001", "10001", "10001", "10001", "01010", "01010", "00100"),
    " ": ("000",) * 7,
}


def largura_texto(texto, escala):
    return sum((len(FONTE[c][0]) + 1) * escala for c in texto) - escala


def escrever(img, texto, x, y, escala, cor, sombra=None):
    px = img.load()
    for c in texto:
        linhas = FONTE[c]
        for ly, linha in enumerate(linhas):
            for lx, bit in enumerate(linha):
                if bit != "1":
                    continue
                for sy in range(escala):
                    for sx in range(escala):
                        if sombra:
                            px[x + lx * escala + sx, y + ly * escala + sy + escala] = sombra + (255,)
        for ly, linha in enumerate(linhas):
            for lx, bit in enumerate(linha):
                if bit != "1":
                    continue
                for sy in range(escala):
                    for sx in range(escala):
                        px[x + lx * escala + sx, y + ly * escala + sy] = cor + (255,)
        x += (len(linhas[0]) + 1) * escala


def abertura():
    l, a = 320, 180
    img = Image.new("RGBA", (l, a), NOITE + (255,))
    px = img.load()
    rng = random.Random(5)
    for _ in range(110):
        x, y = rng.randrange(l), rng.randrange(a)
        brilho = rng.choice([(48, 56, 72), (72, 82, 100), (110, 122, 140), (169, 184, 191)])
        px[x, y] = brilho + (255,)
    for _ in range(6):  # estrelas maiores, em cruz
        x, y = rng.randrange(4, l - 4), rng.randrange(4, 120)
        for ddx, ddy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            px[x + ddx, y + ddy] = ((232, 240, 242) if (ddx, ddy) == (0, 0) else (110, 122, 140)) + (255,)

    cx, cy, raio = 160, 72, 44
    # Céu limpo atrás do planeta, para nenhuma estrela aparecer "na frente" dele.
    for y in range(a):
        for x in range(l):
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= (raio + 3) ** 2:
                px[x, y] = NOITE + (255,)
    desenhar_marte(img, cx, cy, raio, contorno=False)
    # Fobos, pequeno e cinza, no alto à direita.
    for y in range(-3, 4):
        for x in range(-4, 5):
            if (x / 4.2) ** 2 + (y / 3.2) ** 2 <= 1:
                tom = (150, 132, 124) if x + y < 0 else (98, 84, 84)
                px[cx + raio + 22 + x, cy - raio + 6 + y] = tom + (255,)

    titulo = "FIVE SOLS ON MARS"
    escala = 2
    x = (l - largura_texto(titulo, escala)) // 2
    escrever(img, titulo, x, 128, escala, TEXTO, sombra=(138, 60, 38))
    return img.resize((l * 2, a * 2), Image.NEAREST)


def main():
    destino = RAIZ / "assets"
    icone().save(destino / "icone.png")
    abertura().save(destino / "abertura.png")
    print("Escrevi assets/icone.png e assets/abertura.png")


if __name__ == "__main__":
    main()
