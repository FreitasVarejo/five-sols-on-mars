#!/usr/bin/env python3
"""Gera o som do alarme da radiação em assets/sons/alarme.ogg (numpy, wave e o ffmpeg com libvorbis).

Uso: scripts/gerar_alarme.py

Obra própria, sem amostra de terceiros: dois tons que se alternam (agudo, grave, agudo, grave), cada
um uma senoide com um pouco do 3º harmônico, para soar como sirene de painel e não como apito.
Cada tom tem ataque e saída curtos, para não estalar. O volume é de ~-12 dB de média, na faixa dos
sons do terminal (o clique_navegar fica em -18 dB e o terminal_sobe em -13 dB).
"""
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

TAXA = 44100
TOM_AGUDO = 880.0  # Hz
TOM_GRAVE = 622.25  # Hz, uma quarta aumentada abaixo: soa a alerta
DURACAO_TOM = 0.27  # s; quatro tons = 1,08 s
TONS = [TOM_AGUDO, TOM_GRAVE, TOM_AGUDO, TOM_GRAVE]
ATAQUE = 0.008  # s
SAIDA = 0.03  # s
AMPLITUDE = 0.45
HARMONICO_3 = 0.25

DESTINO = Path(__file__).resolve().parent.parent / "assets" / "sons" / "alarme.ogg"


def tom(freq: float) -> np.ndarray:
    n = int(TAXA * DURACAO_TOM)
    t = np.arange(n) / TAXA
    onda = np.sin(2 * np.pi * freq * t) + HARMONICO_3 * np.sin(2 * np.pi * 3 * freq * t)
    env = np.ones(n)
    na, ns = int(TAXA * ATAQUE), int(TAXA * SAIDA)
    env[:na] = np.linspace(0.0, 1.0, na)
    env[-ns:] = np.linspace(1.0, 0.0, ns)
    return onda / (1 + HARMONICO_3) * env


def main() -> None:
    sinal = AMPLITUDE * np.concatenate([tom(f) for f in TONS])
    pcm = (np.clip(sinal, -1.0, 1.0) * 32767).astype("<i2")
    with tempfile.TemporaryDirectory() as pasta:
        wav = Path(pasta) / "alarme.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(TAXA)
            w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "4",
                        str(DESTINO)], check=True)
    print(f"{DESTINO}: {len(sinal) / TAXA:.2f} s")


if __name__ == "__main__":
    main()
