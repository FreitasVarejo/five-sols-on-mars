#!/usr/bin/env python3
"""Gera os sons da estufa (a peça da planta) em assets/sons/ (numpy, wave e o ffmpeg com libvorbis).

Uso: scripts/gerar_som_estufa.py

Obra própria, sem amostra de terceiros. O jogo é para crianças de 7 a 12 anos: tudo macio, curto (até
0,4 s; o ploc, até 0,5 s) e sem buzina. Cada som tem um equivalente visual na peça (a lâmpada acende, a
ferramenta anima, a planta reage); o som só reforça.

- estufa_luz.ogg (0,30 s): brilho curto que sobe, o botão da luz verde. Senoide de 520 a 1040 Hz com o
  2º harmônico baixo e um envelope de sino suave.
- estufa_regar.ogg (0,35 s): o "chuá" do regador. Ruído passa-faixa em ~2,4 kHz, com uma oscilação rápida
  de amplitude (gotas) e entrada e saída suaves.
- estufa_ventilar.ogg (0,40 s): o sopro do ventilador. Ruído passa-faixa em ~700 Hz que sobe e desce em
  cosseno, com um toque do giro (35 Hz) por baixo.
- estufa_cortar.ogg (0,30 s): dois estalos da tesoura, a 0 e a 0,12 s. Cada um é um ruído passa-faixa em
  ~2,6 kHz que morre em ~25 ms, com um "tim" de 1,9 kHz por cima.
- estufa_melhorou.ogg (0,20 s): blip suave que sobe (a escolha certa). Senoide de 520 a 700 Hz.
- estufa_piorou.ogg (0,30 s): grave e baixo (-20 dB de média), a escolha errada. Senoide de 220 a 150 Hz
  que morre em ~0,12 s. Sem buzina: é um "uh" macio.
- estufa_ploc.ogg (0,50 s): o acerto final. A gota que cai (senoide de 720 a 240 Hz em 90 ms) e, em
  seguida, um "tilim" de duas notas (1320 e 1760 Hz) que morrem em ~0,15 s.

O volume é de ~-15 dB de média (o alarme fica em -12 dB, a viagem em -13 dB e o clique_navegar em
-18 dB), menos o piorou, que fica em -20 dB. Um limitador suave (ver normalizar) arredonda os picos.
"""
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

TAXA = 44100
ALVO_DB = -15.0  # volume médio dos sons
PICO_MAX = 0.95  # o pico não passa daqui: sem clip

RAIZ = Path(__file__).resolve().parent.parent
DESTINO = RAIZ / "assets" / "sons"


def tempo(dur: float) -> np.ndarray:
    return np.arange(int(TAXA * dur)) / TAXA


def passa_faixa(x: np.ndarray, centro: float, largura: float) -> np.ndarray:
    """Passa-faixa de fase zero pela FFT: ganho gaussiano em torno de `centro` (Hz), desvio `largura`."""
    espectro = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / TAXA)
    return np.fft.irfft(espectro * np.exp(-0.5 * ((f - centro) / largura) ** 2), len(x))


def ruido(n: int, semente: int) -> np.ndarray:
    return np.clip(np.random.default_rng(semente).standard_normal(n), -3.0, 3.0)


def rms1(x: np.ndarray) -> np.ndarray:
    return x / np.sqrt(np.mean(x**2))


def entra_e_sai(n: int, entra: float, sai: float) -> np.ndarray:
    """Envelope de cosseno: sobe em `entra` s, segura e desce em `sai` s (sem estalo nas pontas)."""
    env = np.ones(n)
    ne, ns = min(n, int(TAXA * entra)), min(n, int(TAXA * sai))
    if ne:
        env[:ne] = 0.5 - 0.5 * np.cos(np.pi * np.arange(ne) / ne)
    if ns:
        env[n - ns :] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(ns) / ns)
    return env


def fase_de(t: np.ndarray, f0: float, f1: float, tau: float) -> np.ndarray:
    """Fase de uma senoide cuja frequência vai de f0 a f1 em curva exponencial de constante `tau` s."""
    freq = f1 + (f0 - f1) * np.exp(-t / tau)
    return 2 * np.pi * np.cumsum(freq) / TAXA


def glissando(t: np.ndarray, f0: float, f1: float, tau: float) -> np.ndarray:
    return np.sin(fase_de(t, f0, f1, tau))


def luz() -> np.ndarray:
    t = tempo(0.30)
    fase = fase_de(t, 520.0, 1040.0, 0.12)
    s = np.sin(fase) + 0.25 * np.sin(2 * fase)
    return s * entra_e_sai(len(t), 0.02, 0.16)


def regar() -> np.ndarray:
    t = tempo(0.35)
    r = rms1(passa_faixa(ruido(len(t), 21), 2400.0, 900.0))
    gotas = 0.65 + 0.35 * np.sin(2 * np.pi * 26.0 * t + 0.6 * np.sin(2 * np.pi * 7.0 * t))
    return r * gotas * entra_e_sai(len(t), 0.05, 0.14)


def ventilar() -> np.ndarray:
    t = tempo(0.40)
    r = rms1(passa_faixa(ruido(len(t), 33), 700.0, 320.0))
    giro = 0.25 * np.sin(2 * np.pi * 35.0 * t)
    sopro = np.sin(np.pi * t / t[-1] * 0.999) ** 1.5  # sobe e desce
    return (r + giro) * sopro


def estalo(n: int, semente: int) -> np.ndarray:
    t = np.arange(n) / TAXA
    r = rms1(passa_faixa(ruido(n, semente), 2600.0, 700.0))
    tim = np.sin(2 * np.pi * 1900.0 * t)
    return (0.8 * r + 0.35 * tim) * np.exp(-t / 0.025) * np.minimum(t / 0.002, 1.0)


def cortar() -> np.ndarray:
    n = int(TAXA * 0.30)
    x = np.zeros(n)
    for i, (inicio, semente, ganho) in enumerate([(0.0, 41, 1.0), (0.12, 42, 0.85)]):
        k = int(TAXA * inicio)
        e = estalo(int(TAXA * 0.12), semente) * ganho
        x[k : k + len(e)] += e
    return x * entra_e_sai(n, 0.0, 0.02)


def melhorou() -> np.ndarray:
    t = tempo(0.20)
    fase = fase_de(t, 520.0, 700.0, 0.06)
    s = np.sin(fase) + 0.15 * np.sin(2 * fase)
    return s * entra_e_sai(len(t), 0.01, 0.12)


def piorou() -> np.ndarray:
    t = tempo(0.30)
    s = glissando(t, 220.0, 150.0, 0.10)
    return s * np.exp(-t / 0.12) * np.minimum(t / 0.01, 1.0) * entra_e_sai(len(t), 0.0, 0.05)


def ploc() -> np.ndarray:
    n = int(TAXA * 0.50)
    x = np.zeros(n)
    gota_t = tempo(0.12)
    gota = glissando(gota_t, 720.0, 240.0, 0.03) * np.exp(-gota_t / 0.05) * np.minimum(gota_t / 0.003, 1.0)
    x[: len(gota)] += gota
    for inicio, freq, ganho in [(0.10, 1320.0, 0.45), (0.20, 1760.0, 0.40)]:
        k = int(TAXA * inicio)
        tt = tempo(0.30)
        nota = np.sin(2 * np.pi * freq * tt) * np.exp(-tt / 0.07) * np.minimum(tt / 0.004, 1.0) * ganho
        x[k : k + len(nota)] += nota[: n - k]
    return x * entra_e_sai(n, 0.0, 0.05)


def normalizar(x: np.ndarray, alvo_db: float) -> np.ndarray:
    """Escala para `alvo_db` de média (rms do arquivo inteiro) passando por um limitador suave.

    O limitador (PICO_MAX * tanh(y / PICO_MAX)) só arredonda os picos: o pico nunca passa de PICO_MAX, então
    não há clip, e o ganho é achado por bisecção para a média, depois do limitador, cair em `alvo_db`.
    """
    alvo = 10 ** (alvo_db / 20)
    baixo, alto = 0.0, 100.0 / np.max(np.abs(x))
    y = x
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


# nome do arquivo -> (função que gera o sinal, média em dB)
SONS = {
    "estufa_luz": (luz, ALVO_DB),
    "estufa_regar": (regar, ALVO_DB),
    "estufa_ventilar": (ventilar, ALVO_DB),
    "estufa_cortar": (cortar, ALVO_DB),
    "estufa_melhorou": (melhorou, ALVO_DB),
    "estufa_piorou": (piorou, -20.0),
    "estufa_ploc": (ploc, ALVO_DB),
}


def main() -> None:
    DESTINO.mkdir(parents=True, exist_ok=True)
    for nome, (gera, db) in SONS.items():
        gravar(normalizar(gera(), db), DESTINO / f"{nome}.ogg")


if __name__ == "__main__":
    main()
