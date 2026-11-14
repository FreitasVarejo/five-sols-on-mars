#!/usr/bin/env bash
# Exporta o jogo para Web e publica no branch gh-pages (GitHub Pages).
# Uso: scripts/publicar.sh   (precisa do Godot 4.7.2 com os templates de export)
set -euo pipefail
raiz="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT:-godot}"
saida="$raiz/build/web"

# Dado do DONKI embutido no build: baixa os últimos 60 dias antes do export.
# Se falhar, segue com o dados/donki.json que já existe (ou sem ele: o jogo cai no histórico).
if ! python3 "$raiz/scripts/baixar_donki.py"; then
  echo "" >&2
  echo "################################################################" >&2
  echo "# ATENÇÃO: não consegui baixar o DONKI. O build segue com o    #" >&2
  echo "# dados/donki.json que já existe; sem ele, o jogo usa o        #" >&2
  echo "# recorte histórico de maio de 2024.                           #" >&2
  echo "################################################################" >&2
  echo "" >&2
fi

rm -rf "$saida"
mkdir -p "$saida"
"$godot_bin" --headless --path "$raiz" --export-release "Web" "$saida/index.html"
touch "$saida/.nojekyll"

commit="$(git -C "$raiz" rev-parse --short HEAD)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp -r "$saida"/. "$tmp"/
cd "$tmp"
git init -q -b gh-pages
git add -A
git commit -q -m "Publica o build de $commit"
git push -q -f "$(git -C "$raiz" remote get-url origin)" gh-pages
echo "Publicado o build de $commit no gh-pages."
if [ -f "$raiz/dados/donki.json" ]; then
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); n=len(d["chegadas_marte"]); print("Dado do DONKI embutido: coletado em %s (%d chegadas a Marte)%s." % (d["coletado_em"], n, "" if n else "; sem chegadas, o jogo usa o recorte histórico"))' "$raiz/dados/donki.json"
else
  echo "Sem dados/donki.json: o jogo usa o recorte histórico de maio de 2024."
fi
