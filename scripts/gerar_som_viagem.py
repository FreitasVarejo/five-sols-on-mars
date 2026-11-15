#!/usr/bin/env python3
"""Gera os sons da viagem Terra -> Marte em assets/sons/ (numpy, wave e o ffmpeg com libvorbis).

Uso: scripts/gerar_som_viagem.py [--previas]

Obra própria, sem amostra de terceiros. Dois sons, ambos graves e macios: o jogo é para crianças de 7 a
12 anos, então nada áspero nem agudo.

- viagem_ignicao.ogg (2,5 s): o ronco do motor quando o foguete parte. Ruído branco passado por um
  passa-baixa (corte em ~220 Hz) com uma senoide de 50 Hz por baixo (e um pouco do 2º harmônico, para
  o ronco aparecer também em alto-falante de celular, que não toca 50 Hz). Uma oscilação lenta de
  amplitude (5 Hz e 1,7 Hz, fundas em 20% e 12%) tira o ronco do estático. Sobe em 0,15 s, segura 1,3 s
  e some em 1,05 s, como o foguete que se afasta; nessa saída o grave cai um pouco de tom.
- viagem_pouso.ogg (0,7 s): o baque do pouso em Marte. Uma senoide que cai de 120 para 45 Hz (a queda
  leva ~0,4 s), um estalo de ruído filtrado nos primeiros 30 ms e uma cauda que morre em ~0,3 s.

O volume é de ~-13 dB de média nos dois (viagem_ignicao -13,1 dB e viagem_pouso -12,9 dB pelo
volumedetect do ffmpeg, com pico de -2,5 dB e de -2,7 dB: sem clip), na faixa dos outros sons (o alarme
fica em -12 dB, o terminal_sobe em -13 dB e o clique_navegar em -18 dB). Um limitador suave (ver
normalizar) arredonda os picos onde o grave e o ruído se somam.

Com --previas, grava também três variantes de cada som (A, B e C, com graves e durações um pouco
diferentes; a A é a que vai para assets/sons/) em ~/Music/five-sols-on-mars/sfx-viagem/, para o dono
escolher de ouvido. Os parâmetros do mesmo som mudam só em VARIANTES_*: o resto é igual.
"""
import argparse
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

TAXA = 44100
ALVO_DB = -13.0  # volume médio de cada som
PICO_MAX = 0.95  # o pico não passa daqui: sem clip

RAIZ = Path(__file__).resolve().parent.parent
DESTINO = RAIZ / "assets" / "sons"
PREVIAS = Path.home() / "Music" / "five-sols-on-mars" / "sfx-viagem"

# Ignição: grave (Hz), corte do passa-baixa (Hz), subida, corpo e saída (s).
VARIANTES_IGNICAO = {
    "A": dict(grave=50.0, corte=220.0, subida=0.15, corpo=1.30, saida=1.05),
    "B": dict(grave=42.0, corte=160.0, subida=0.20, corpo=1.40, saida=1.20),
    "C": dict(grave=60.0, corte=300.0, subida=0.12, corpo=1.10, saida=0.95),
}
# Pouso: onde a senoide começa e termina (Hz), tempo da queda e duração total (s).
VARIANTES_POUSO = {
    "A": dict(f0=120.0, f1=45.0, queda=0.40, total=0.70),
    "B": dict(f0=100.0, f1=38.0, queda=0.45, total=0.80),
    "C": dict(f0=140.0, f1=55.0, queda=0.35, total=0.60),
}


def passa_baixa(x: np.ndarray, corte: float) -> np.ndarray:
    """Passa-baixa de fase zero, de 4ª ordem (|H| = 1/sqrt(1 + (f/corte)^8)), pela FFT."""
    espectro = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / TAXA)
    return np.fft.irfft(espectro / np.sqrt(1.0 + (f / corte) ** 8), len(x))


def ruido_baixo(n: int, corte: float, semente: int) -> np.ndarray:
    """Ruído passa-baixa com rms 1 (a semente fixa deixa a saída igual a cada execução)."""
    r = np.clip(np.random.default_rng(semente).standard_normal(n), -2.0, 2.0)
    r = passa_baixa(r, corte)
    return r / np.sqrt(np.mean(r**2))


def ignicao(grave: float, corte: float, subida: float, corpo: float, saida: float) -> np.ndarray:
    n = int(TAXA * (subida + corpo + saida))
    t = np.arange(n) / TAXA
    total = n / TAXA
    # Envelope: sobe em cosseno, segura o corpo e some em meio cosseno (sem estalo no fim).
    env = np.ones(n)
    ns, nc = int(TAXA * subida), int(TAXA * corpo)
    env[:ns] = 0.5 - 0.5 * np.cos(np.pi * np.arange(ns) / ns)
    env[ns + nc :] = (0.5 + 0.5 * np.cos(np.pi * np.arange(n - ns - nc) / (n - ns - nc))) ** 0.7
    # O foguete se afasta: o grave cai até 12% de tom na saída (a fase é a integral da frequência).
    queda = np.clip((t - subida - corpo) / saida, 0.0, 1.0)
    freq = grave * (1.0 - 0.12 * queda)
    fase = 2 * np.pi * np.cumsum(freq) / TAXA
    senoide = np.sin(fase) + 0.35 * np.sin(2 * fase + 0.7)
    ruido = ruido_baixo(n, corte, semente=7)
    # A oscilação lenta de amplitude, para o ronco não soar estático.
    osc = (1.0 + 0.20 * np.sin(2 * np.pi * 5.0 * t) + 0.12 * np.sin(2 * np.pi * 1.7 * t + 1.1)) / 1.32
    corpo_som = (0.45 * ruido + 0.75 * senoide) * osc
    return corpo_som * env


def pouso(f0: float, f1: float, queda: float, total: float) -> np.ndarray:
    n = int(TAXA * total)
    t = np.arange(n) / TAXA
    # A frequência cai exponencialmente de f0 a f1 e assenta: aos `queda` s falta 5% do caminho.
    freq = f1 + (f0 - f1) * np.exp(-3.0 * t / queda)
    fase = 2 * np.pi * np.cumsum(freq) / TAXA
    ataque = np.minimum(t / 0.004, 1.0)
    cauda = np.exp(-t / 0.22)
    saida = np.minimum((total - t) / 0.03, 1.0)  # os últimos 30 ms vão a zero
    corpo = np.sin(fase) * ataque * cauda * saida
    # O estalo: ruído filtrado (corte em 900 Hz) nos primeiros 30 ms.
    estalo = ruido_baixo(n, 900.0, semente=11) * np.exp(-t / 0.009) * np.where(t < 0.03, 1.0, 0.0)
    return corpo + 0.3 * estalo * ataque


def normalizar(x: np.ndarray) -> np.ndarray:
    """Escala para ALVO_DB de média (rms do arquivo inteiro) passando por um limitador suave.

    O limitador (PICO_MAX * tanh(y / PICO_MAX)) só arredonda os picos mais altos do ronco, onde o grave e o
    ruído se somam: o pico nunca passa de PICO_MAX, então não há clip, e o ganho é achado por bisecção para
    a média, depois do limitador, cair em ALVO_DB.
    """
    alvo = 10 ** (ALVO_DB / 20)
    baixo, alto = 0.0, 100.0 / np.max(np.abs(x))
    for _ in range(60):
        g = (baixo + alto) / 2
        y = PICO_MAX * np.tanh(g * x / PICO_MAX)
        if np.sqrt(np.mean(y**2)) < alvo:
            baixo = g
        else:
            alto = g
    return y


def gravar(sinal: np.ndarray, destino: Path) -> None:
    pcm = (np.clip(sinal, -1.0, 1.0) * 32767).astype("<i2")
    with tempfile.TemporaryDirectory() as pasta:
        wav = Path(pasta) / "som.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(TAXA)
            w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "4",
                        str(destino)], check=True)
    media = 20 * np.log10(np.sqrt(np.mean(sinal**2)))
    pico = 20 * np.log10(np.max(np.abs(sinal)))
    print(f"{destino}: {len(sinal) / TAXA:.2f} s, média {media:.1f} dB, pico {pico:.1f} dB")


def main() -> None:
    ap = argparse.ArgumentParser(description="Gera os sons da viagem Terra -> Marte.")
    ap.add_argument("--previas", action="store_true",
                    help=f"grava também as variantes A, B e C em {PREVIAS}")
    args = ap.parse_args()
    DESTINO.mkdir(parents=True, exist_ok=True)
    gravar(normalizar(ignicao(**VARIANTES_IGNICAO["A"])), DESTINO / "viagem_ignicao.ogg")
    gravar(normalizar(pouso(**VARIANTES_POUSO["A"])), DESTINO / "viagem_pouso.ogg")
    if args.previas:
        PREVIAS.mkdir(parents=True, exist_ok=True)
        for letra, p in VARIANTES_IGNICAO.items():
            gravar(normalizar(ignicao(**p)), PREVIAS / f"ignicao_{letra}.ogg")
        for letra, p in VARIANTES_POUSO.items():
            gravar(normalizar(pouso(**p)), PREVIAS / f"pouso_{letra}.ogg")


if __name__ == "__main__":
    main()
