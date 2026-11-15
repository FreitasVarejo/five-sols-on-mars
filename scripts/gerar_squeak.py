#!/usr/bin/env python3
"""Gera o squeak do pato de borracha em assets/sons/squeak.ogg (numpy, wave e o ffmpeg com libvorbis).

Uso: scripts/gerar_squeak.py [--previas]

Obra própria, sem amostra de terceiros: um apito de cerca de 0,25 s cuja altura sobe em glissando
(de ~950 para ~1650 Hz, quase uma oitava), como o apito de borracha que se aperta. A onda é uma soma de
harmônicos (o 3º forte, para soar a palheta de brinquedo e não a senoide), com uma tremulação leve de
amplitude (~55 Hz). Por cima entra um sopro de ar: ruído branco passa-alta, mais forte no começo, que
é o ar saindo do pato. Ataque de 8 ms e saída de 60 ms, para não estalar.

O volume médio é de ~-15 dB (volumedetect do ffmpeg), um pouco abaixo dos outros sons: o squeak é agudo e
curto, e o agudo soa mais alto do que o número diz. O jogo ainda sorteia o pitch de cada toque (±10%).

Com --previas, grava em ~/Pictures/five-sols-on-mars/easter-egg-squeak/ a prévia do som que vai para
o jogo (squeak-previa.wav e .ogg) e três variações dos parâmetros (squeak-alt-1, -2 e -3, em .wav e .ogg),
para o dono ouvir. As variações só mudam em VARIANTES; nenhuma delas vai para assets/sons/.
"""
import argparse
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

TAXA = 44100
ALVO_DB = -15.0  # volume médio (RMS) de cada squeak
PICO_MAX = 0.9  # o pico não passa daqui: sem clip
ATAQUE = 0.008  # s
SAIDA = 0.06  # s

RAIZ = Path(__file__).resolve().parent.parent
DESTINO = RAIZ / "assets" / "sons" / "squeak.ogg"
PREVIAS = Path.home() / "Pictures" / "five-sols-on-mars" / "easter-egg-squeak"

# O som do jogo é o PRINCIPAL. Cada variação muda só o que está escrito aqui.
#   f0, f1      Hz no começo e no fim do glissando
#   duracao     s
#   curva       expoente da subida: < 1 sobe depressa e se acomoda, > 1 sobe só no fim
#   harmonicos  amplitude do 1º, 2º, 3º e 4º harmônico
#   tremulo     profundidade (0 a 1) da tremulação de amplitude, a 55 Hz
#   ar          amplitude do sopro de ar, em relação à onda
#   queda       fração de f1 que a altura perde no último quarto do apito (0 = só sobe)
PRINCIPAL = dict(f0=950.0, f1=1650.0, duracao=0.25, curva=0.65, harmonicos=(1.0, 0.45, 0.6, 0.2),
                 tremulo=0.12, ar=0.10, queda=0.0)
VARIANTES = [
    # 1: mais grave e mais gordo, o pato grande
    dict(f0=700.0, f1=1250.0, duracao=0.29, curva=0.7, harmonicos=(1.0, 0.7, 0.5, 0.3),
         tremulo=0.18, ar=0.12, queda=0.0),
    # 2: agudo e curto, o patinho
    dict(f0=1250.0, f1=2350.0, duracao=0.19, curva=0.55, harmonicos=(1.0, 0.3, 0.35, 0.1),
         tremulo=0.06, ar=0.08, queda=0.0),
    # 3: sobe e cai um pouco no fim, o "squeeak" de quem solta o ar
    dict(f0=820.0, f1=1900.0, duracao=0.27, curva=0.5, harmonicos=(1.0, 0.5, 0.55, 0.15),
         tremulo=0.1, ar=0.14, queda=0.12),
]


def sintetizar(p: dict, semente: int = 7) -> np.ndarray:
    n = int(TAXA * p["duracao"])
    t = np.arange(n) / TAXA
    u = t / p["duracao"]
    g = u ** p["curva"]
    f = p["f0"] * (p["f1"] / p["f0"]) ** g
    if p["queda"]:
        ultimo = np.clip((u - 0.75) / 0.25, 0.0, 1.0)
        f = f * (1.0 - p["queda"] * ultimo ** 2)
    fase = 2 * np.pi * np.cumsum(f) / TAXA
    onda = sum(a * np.sin((k + 1) * fase) for k, a in enumerate(p["harmonicos"]))
    onda = onda / sum(p["harmonicos"])
    onda = onda * (1.0 - p["tremulo"] * (0.5 + 0.5 * np.sin(2 * np.pi * 55.0 * t)))

    # envelope: ataque curto, um leve declínio (o ar acaba) e saída em meio cosseno
    env = 1.0 - 0.25 * u
    na, ns = int(TAXA * ATAQUE), int(TAXA * SAIDA)
    env[:na] *= np.linspace(0.0, 1.0, na)
    env[-ns:] *= 0.5 + 0.5 * np.cos(np.linspace(0.0, np.pi, ns))

    # sopro de ar: ruído passa-alta (diferença de segunda ordem), forte no começo
    rng = np.random.default_rng(semente)
    ruido = rng.standard_normal(n + 2)
    ruido = np.diff(ruido, 2)
    ruido = ruido / np.abs(ruido).max()
    sopro = ruido * (0.35 + 0.65 * np.exp(-t / 0.05)) * env
    return onda * env + p["ar"] * sopro


def normalizar(sinal: np.ndarray) -> np.ndarray:
    """Leva o RMS a ALVO_DB; um limitador suave (tanh) arredonda os picos que passarem de PICO_MAX."""
    rms = np.sqrt(np.mean(sinal ** 2))
    sinal = sinal * (10 ** (ALVO_DB / 20) / rms)
    return PICO_MAX * np.tanh(sinal / PICO_MAX)


def gravar(sinal: np.ndarray, destino: Path) -> None:
    pcm = (np.clip(sinal, -1.0, 1.0) * 32767).astype("<i2")
    destino.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as pasta:
        wav = Path(pasta) / "squeak.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(TAXA)
            w.writeframes(pcm.tobytes())
        if destino.suffix == ".wav":
            destino.write_bytes(wav.read_bytes())
        else:
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis",
                            "-q:a", "4", str(destino)], check=True)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--previas", action="store_true",
                    help="grava também a prévia e as variações em ~/Pictures/five-sols-on-mars/easter-egg-squeak/")
    args = ap.parse_args()
    principal = normalizar(sintetizar(PRINCIPAL))
    gravar(principal, DESTINO)
    print(f"{DESTINO}: {len(principal) / TAXA:.2f} s, pico {np.abs(principal).max():.2f}")
    if args.previas:
        for sufixo in (".wav", ".ogg"):
            gravar(principal, PREVIAS / f"squeak-previa{sufixo}")
        for i, p in enumerate(VARIANTES, 1):
            sinal = normalizar(sintetizar(p))
            for sufixo in (".wav", ".ogg"):
                gravar(sinal, PREVIAS / f"squeak-alt-{i}{sufixo}")
            print(f"{PREVIAS}/squeak-alt-{i}: {len(sinal) / TAXA:.2f} s")


if __name__ == "__main__":
    main()
