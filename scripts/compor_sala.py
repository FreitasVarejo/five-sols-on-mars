"""Compõe os PNGs da sala: o render novo só dentro de uma região, o resto igual ao de um commit base.

Para que serve. Um objeto novo na sala (a alavanca do abrigo, depois o pato) muda o render inteiro um
pouco: a luz que rebate, o tom que a mediana de uma face grande resolve e uns pixels esparsos longe do
objeto. Fora do objeto a sala tem de ficar igual, então só a região dele entra, sobre os PNGs do commit
base. A região cobre o que o objeto novo ocupa, o que o antigo ocupava e a sombra dos dois.

Uso (da raiz do repo, depois de renderizar com `--saida` DENTRO do repo: o Blender é um Flatpak e não
grava em /tmp). O fluxo completo, em quatro passos:
    ~/.local/bin/blender -b --factory-startup -P $PWD/arte/blender/comodo.py -- \\
        --estados normal,tempestade,abrigo,modo_seguranca,abrigo_aberto --saida arte/blender/.render/novo
    python3 scripts/compor_sala.py --render arte/blender/.render/novo --regiao 154 131 272 258
    python3 scripts/gerar_persiana.py
    python3 scripts/compor_sala.py --persiana --regiao 154 131 272 258
O último passo devolve à base os pixels da persiana fora da região e roda a prova (`--provar`).
Para o pato (15/11): `--regiao 848 192 892 222 --objeto pato_ --base alavanca-do-abrigo` em todos os passos.

Argumentos:
    --render DIR     onde o Blender gravou os PNGs crus e o regioes.json (padrão arte/blender/.render/novo).
                     Os passes de índice (<estado>_indice.npy) e o indices.json vêm de arte/blender/.render,
                     onde o comodo.py os grava sempre.
    --regiao X0 Y0 X1 Y1   a região de repintura, em px do panorama, com X1 e Y1 exclusivos.
    --base REF       de onde vêm os PNGs fora da região (padrão origin/main). Lidos com `git show`.
    --pilar NOMES    o objeto de fundo em que o objeto novo está montado, ou vários separados por vírgula
                     (padrão suporte_corpo). Cada um leva a sua tabela de cor (abaixo).
    --objeto PREFIXO prefixo dos nomes dos objetos novos no indices.json (padrão abrigo_).
    --persiana       não compõe: depois do scripts/gerar_persiana.py, devolve à base os pixels de
                     persiana.png e persiana_indice.png fora da região e roda a prova (abaixo).
                     O ajuste das curvas das lâminas do gerar_persiana.py muda um pouco com qualquer
                     objeto novo perto da janela e move a divisória 1 px em colunas longe dele, onde
                     a persiana não mudou; este passo mantém essas colunas iguais à base.
    --provar         não compõe: só compara os 5 PNGs da sala, a persiana.png e a persiana_indice.png
                     de assets/comodo com os da base e sai com 1 se algum pixel difere fora da região.

O que faz (sem --provar), por estado (normal, tempestade, abrigo, abrigo_aberto, modo_seguranca):
1. Parte do PNG da base.
2. Cola o render novo dentro da região.
3. Troca a cor dos pixels do pilar dentro da região pela tabela de cor do pilar (abaixo).
4. Grava em assets/comodo e copia o regioes.json do render para lá, se ele existir.
Depois confere o diff contra a base e mostra os pixels que diferem fora da região.

A tabela de cor do pilar. O render novo pinta o pilar de outro tom em alguns estados: na tempestade o
botão grande tinha emissão vermelha, e sem ele a mediana da face do pilar cai em `202e37` (ardósia)
em vez de `341c27` (vinho). Colado como veio, o render deixaria um retângulo de pilar de outra cor
dentro do pilar de antes. A tabela novo -> base é medida em cada estado, por maioria (no mínimo 20
pixels), nos pixels do pilar fora da região, que têm a mesma luz nos dois renders menos esse tom.
Dentro da região só os pixels que o passe de índice do render novo diz serem do pilar passam pela
tabela; o objeto novo e o contorno dele ficam como o render os fez.

A persiana: rode scripts/gerar_persiana.py depois da composição e, depois dele, `--persiana`. Se a
região fica longe da janela (a alavanca), persiana.png e persiana_indice.png já saem iguais aos da
base; se toca o vidro (o pato), só mudam dentro da região. A prova `--provar` confere.
"""
import argparse
import io
import json
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
COMODO = RAIZ / "assets" / "comodo"
CACHE = RAIZ / "arte" / "blender" / ".render"
ESTADOS = ("normal", "tempestade", "abrigo", "abrigo_aberto", "modo_seguranca")
PERSIANA = ("persiana", "persiana_indice")
MIN_PIXELS_TABELA = 20


def da_base(base, nome):
    saida = subprocess.run(["git", "show", f"{base}:assets/comodo/{nome}.png"], cwd=RAIZ,
                           capture_output=True, check=True).stdout
    return np.array(Image.open(io.BytesIO(saida)).convert("RGBA"))


def empacotar(rgba):
    p = rgba.astype(np.uint32)
    return (p[..., 0] << 24) | (p[..., 1] << 16) | (p[..., 2] << 8) | p[..., 3]


def desempacotar(v):
    v = np.uint32(v)
    return np.array([(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255], np.uint8)


def tabela_do_pilar(novo, base, indice, pilar, regiao):
    """Cor do render novo -> cor da base, por maioria, nos pixels do pilar fora da região."""
    x0, y0, x1, y1 = regiao
    fora = indice == pilar
    fora[y0:y1, x0:x1] = False
    pares = np.stack([empacotar(novo)[fora], empacotar(base)[fora]], 1)
    unicos, conta = np.unique(pares, axis=0, return_counts=True)
    melhor = {}
    for (cn, cb), n in zip(unicos, conta):
        if n >= MIN_PIXELS_TABELA and (cn not in melhor or n > melhor[cn][1]):
            melhor[cn] = (cb, n)
    return {cn: cb for cn, (cb, _) in melhor.items()}


def compor(args, regiao):
    x0, y0, x1, y1 = regiao
    render = Path(args.render) if Path(args.render).is_absolute() else RAIZ / args.render
    indices = json.loads((CACHE / "indices.json").read_text())
    pilares = [indices[n] for n in args.pilar.split(",")]
    nomes = {v: k for k, v in indices.items()}
    novos = {v for k, v in indices.items() if k.startswith(args.objeto)}
    for estado in ESTADOS:
        base = da_base(args.base, estado)
        novo = np.array(Image.open(render / f"{estado}.png").convert("RGBA"))
        indice = np.load(CACHE / f"{estado}_indice.npy")
        saida = base.copy()
        saida[y0:y1, x0:x1] = novo[y0:y1, x0:x1]
        trecho = saida[y0:y1, x0:x1]
        original = empacotar(trecho)  # as máscaras saem do render, não do que já foi trocado
        for pilar in pilares:
            tabela = tabela_do_pilar(novo, base, indice, pilar, regiao)
            do_pilar = indice[y0:y1, x0:x1] == pilar
            trocados = 0
            for cn, cb in tabela.items():
                alvo = do_pilar & (original == cn)
                if cn != cb:
                    trecho[alvo] = desempacotar(cb)
                    trocados += int(alvo.sum())
            legenda = ", ".join(f"{int(a):08x}->{int(b):08x}" for a, b in tabela.items())
            print(f"{estado}: tabela de {nomes[pilar]} (RRGGBBAA) {{{legenda}}}; trocado: {trocados} px")
        saida[y0:y1, x0:x1] = trecho
        outros = sorted(k for k, v in indices.items()
                        if v in set(np.unique(indice[y0:y1, x0:x1])) - novos - set(pilares))
        Image.fromarray(saida, "RGBA").save(COMODO / f"{estado}.png", optimize=True)
        print(f"{estado}: outros objetos na região: {outros}")
    if (render / "regioes.json").exists():
        shutil.copy(render / "regioes.json", COMODO / "regioes.json")
        print(f"regioes.json copiado de {render}")


def restaurar_persiana(args, regiao):
    """Fora da região, persiana.png e persiana_indice.png voltam a ser os da base."""
    x0, y0, x1, y1 = regiao
    fora = np.ones((360, 1280), bool)
    fora[y0:y1, x0:x1] = False
    for nome in PERSIANA:
        base = da_base(args.base, nome)
        atual = np.array(Image.open(COMODO / f"{nome}.png").convert("RGBA"))
        n = int(((atual != base).any(axis=2) & fora).sum())
        atual[fora] = base[fora]
        modo = "L" if nome == "persiana_indice" else "RGBA"
        img = Image.fromarray(atual, "RGBA").convert(modo)
        img.save(COMODO / f"{nome}.png", optimize=True)
        print(f"{nome}: {n} px fora da região voltaram à base")


def provar(args, regiao):
    x0, y0, x1, y1 = regiao
    dentro = np.zeros((360, 1280), bool)
    dentro[y0:y1, x0:x1] = True
    total = 0
    print(f"região de repintura: x {x0}..{x1 - 1}, y {y0}..{y1 - 1}; base {args.base}")
    for nome in ESTADOS + PERSIANA:
        a = da_base(args.base, nome).astype(int)
        b = np.array(Image.open(COMODO / f"{nome}.png").convert("RGBA")).astype(int)
        dif = (a != b).any(axis=2)
        fora = int((dif & ~dentro).sum())
        ys, xs = np.nonzero(dif)
        caixa = f"x {xs.min()}..{xs.max()}, y {ys.min()}..{ys.max()}" if len(xs) else "nenhum"
        print(f"{nome:16s} difere {int(dif.sum()):6d} px | dentro {int((dif & dentro).sum()):6d} | "
              f"FORA {fora:6d} | caixa do que difere: {caixa}")
        total += fora
    print("TOTAL FORA da região:", total, "->", "PASSA" if total == 0 else "FALHA")
    return total


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--render", default="arte/blender/.render/novo")
    p.add_argument("--regiao", type=int, nargs=4, required=True, metavar=("X0", "Y0", "X1", "Y1"))
    p.add_argument("--base", default="origin/main")
    p.add_argument("--pilar", default="suporte_corpo")
    p.add_argument("--objeto", default="abrigo_")
    p.add_argument("--persiana", action="store_true")
    p.add_argument("--provar", action="store_true")
    args = p.parse_args()
    if args.persiana:
        restaurar_persiana(args, args.regiao)
    elif not args.provar:
        compor(args, args.regiao)
    sys.exit(1 if provar(args, args.regiao) else 0)


if __name__ == "__main__":
    main()
