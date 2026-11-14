#!/usr/bin/env bash
# Exporta o jogo para Web e publica no branch gh-pages (GitHub Pages).
# Uso: scripts/publicar.sh   (precisa do Godot 4.7.2 com os templates de export)
set -euo pipefail
raiz="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT:-godot}"
saida="$raiz/build/web"

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
