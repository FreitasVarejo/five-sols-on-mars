#!/usr/bin/env python3
"""Gera as imagens placeholder do protótipo da câmera (só biblioteca padrão).

Uso: scripts/gerar_placeholder.py [--largura 1280]

Escreve em arte/placeholder/: sala.png (panorama com grade numerada, altura
fixa de 360 px) e as texturas do botão central e das setas.
"""
import argparse
import struct
import zlib
from pathlib import Path

ALTURA = 360
CELULA_L, CELULA_A = 80, 60
ESCALA_FONTE = 4

# Fonte bitmap 3x5, um dígito = 5 linhas de 3 bits (bit mais à esquerda = coluna 0).
FONTE = {
    "0": (0b111, 0b101, 0b101, 0b101, 0b111),
    "1": (0b010, 0b110, 0b010, 0b010, 0b111),
    "2": (0b111, 0b001, 0b111, 0b100, 0b111),
    "3": (0b111, 0b001, 0b111, 0b001, 0b111),
    "4": (0b101, 0b101, 0b111, 0b001, 0b001),
    "5": (0b111, 0b100, 0b111, 0b001, 0b111),
    "6": (0b111, 0b100, 0b111, 0b101, 0b111),
    "7": (0b111, 0b001, 0b001, 0b001, 0b001),
    "8": (0b111, 0b101, 0b111, 0b101, 0b111),
    "9": (0b111, 0b101, 0b111, 0b001, 0b111),
}


class Imagem:
    def __init__(self, largura, altura, fundo=(0, 0, 0, 0)):
        self.l, self.a = largura, altura
        self.px = bytearray(bytes(fundo) * (largura * altura))

    def ponto(self, x, y, cor):
        if 0 <= x < self.l and 0 <= y < self.a:
            i = (y * self.l + x) * 4
            self.px[i:i + 4] = bytes(cor)

    def retangulo(self, x0, y0, x1, y1, cor):
        """Preenche [x0, x1) x [y0, y1)."""
        for y in range(max(y0, 0), min(y1, self.a)):
            for x in range(max(x0, 0), min(x1, self.l)):
                self.ponto(x, y, cor)

    def texto(self, x, y, s, cor, escala=ESCALA_FONTE):
        for k, ch in enumerate(s):
            for ly, linha in enumerate(FONTE[ch]):
                for lx in range(3):
                    if linha & (0b100 >> lx):
                        px = x + (k * 4 + lx) * escala
                        self.retangulo(px, y + ly * escala, px + escala, y + (ly + 1) * escala, cor)

    def salvar(self, caminho):
        bruto = b"".join(
            b"\x00" + bytes(self.px[y * self.l * 4:(y + 1) * self.l * 4]) for y in range(self.a)
        )

        def bloco(tipo, dados):
            corpo = tipo + dados
            return struct.pack(">I", len(dados)) + corpo + struct.pack(">I", zlib.crc32(corpo))

        png = (
            b"\x89PNG\r\n\x1a\n"
            + bloco(b"IHDR", struct.pack(">IIBBBBB", self.l, self.a, 8, 6, 0, 0, 0))
            + bloco(b"IDAT", zlib.compress(bruto, 9))
            + bloco(b"IEND", b"")
        )
        Path(caminho).parent.mkdir(parents=True, exist_ok=True)
        Path(caminho).write_bytes(png)
        print("escrito", caminho)


def clarear(cor, n):
    return tuple(min(255, c + n) for c in cor) + (255,)


def gerar_sala(largura, saida):
    colunas = largura // CELULA_L
    linhas = ALTURA // CELULA_A
    bases = [(150, 70, 50), (105, 50, 45)]  # cores alternadas por coluna
    img = Imagem(largura, ALTURA, (0, 0, 0, 255))
    for y in range(ALTURA):
        for x in range(largura):
            base = bases[(x // CELULA_L) % 2]
            if x % CELULA_L == 0 or y % CELULA_A == 0:
                cor = clarear(base, 110)  # borda de célula
            elif x % 20 == 0 or y % 20 == 0:
                cor = clarear(base, 45)  # linhas finas a cada 20 px
            else:
                cor = base + (255,)
            img.ponto(x, y, cor)
    meio = largura // 2
    img.retangulo(meio, 0, meio + 1, ALTURA, (255, 0, 255, 255))  # centro horizontal
    img.retangulo(0, 179, largura, 181, (0, 255, 255, 255))  # linha y=180
    for c in range(colunas):
        for r in range(linhas):
            s = str(r * colunas + c)
            x, y = c * CELULA_L + 6, r * CELULA_A + 6
            img.texto(x + 2, y + 2, s, (0, 0, 0, 255))
            img.texto(x, y, s, (255, 255, 255, 255))
    img.salvar(saida)


def gerar_botao_centro(pasta):
    # Cores chapadas bem distintas para ver cada estado.
    estados = {"normal": (255, 210, 0, 255), "pressed": (0, 200, 80, 255), "hover": (60, 120, 255, 255)}
    for nome, cor in estados.items():
        img = Imagem(64, 64, (0, 0, 0, 255))
        img.retangulo(4, 4, 60, 60, cor)
        img.retangulo(26, 26, 38, 38, (0, 0, 0, 255))
        img.salvar(pasta / f"botao_centro_{nome}.png")


def gerar_setas(pasta):
    l, a = 48, 120
    for lado in ("esquerda", "direita"):
        for estado, (fundo, cor) in {
            "normal": ((0, 0, 0, 130), (255, 255, 255, 255)),
            "pressed": ((255, 255, 255, 170), (255, 140, 0, 255)),
        }.items():
            img = Imagem(l, a, fundo)
            for y in range(a):
                for x in range(l):
                    # triângulo apontando para o lado (esquerda: ponta em x=10; direita: ponta em x=37)
                    dx = (x - 10) if lado == "esquerda" else (37 - x)
                    if 0 <= dx <= 28 and abs(y - a // 2) <= dx * 22 // 28:
                        img.ponto(x, y, cor)
            sufixo = "" if estado == "normal" else "_pressed"
            img.salvar(pasta / f"seta_{lado}{sufixo}.png")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--largura", type=int, default=1280, help="largura do panorama (padrão 1280)")
    args = ap.parse_args()
    pasta = Path(__file__).resolve().parent.parent / "arte" / "placeholder"
    gerar_sala(args.largura, pasta / "sala.png")
    gerar_botao_centro(pasta)
    gerar_setas(pasta)


if __name__ == "__main__":
    main()
