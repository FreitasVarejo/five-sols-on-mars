# Uso de IA (SI) no projeto

Base para o campo de uso de SI do formulário de submissão. Uma linha por bloco de trabalho, com data, ferramenta, o que ela fez e o que ficou de fora. Exemplo:

- 14/11: Claude Code gerou o esqueleto do projeto Godot e o script de publicação; nenhum asset do jogo.

## Registro

- 14/11: Claude Code gerou o esqueleto do projeto Godot (640×360, preset Web), o `scripts/publicar.sh` e este briefing a partir da spec do dono.
- 14/11: Claude Code escreveu o protótipo do pipeline de arte (`arte/blender/comodo.py`): script `bpy` que gera o módulo de comando em gray-box e renderiza os 4 estados no Cycles, com contorno por profundidade, normal e índice e paleta Apollo (AdamCYounis); e `arte/blender/comparar_camera.py`, que compara câmera cilíndrica e perspectiva com o shader de panorama reproduzido em numpy. Nenhuma IA de imagem e nenhum inpainting.
- 14/11: Claude Code (subagente implementador) escreveu o protótipo da câmera: pan por mouse e setas, o shader CC0 de b en com uma linha trocada (`texelFetch`), o script do placeholder em grade e as texturas dos botões geradas, e testou no navegador com Playwright; nenhum asset de terceiros, e nenhum código do Cupcakes Framework copiado.
- 14/11: Claude Code (subagente implementador) escreveu `arte/blender/exterior.py`: script `bpy` que gera o exterior da base em Gale (relevo, Monte Sharp, habitat, MOXIE, campo de painéis, rover com braço, rocha do ChemCam, área de amostra) e renderiza 5 câmeras em 2 estados (normal e poeira) em pixel art com a paleta Apollo, reaproveitando os helpers do `comodo.py`. Nenhum asset baixado, nenhuma IA de imagem e nenhum inpainting.
- 14/11: Claude Code (subagente implementador) refez o cômodo do `comodo.py` para o novo layout (esquerda: abrigo, radiação, Terra e janela com persiana; centro: telas de energia e oxigênio; direita: console das 4 câmeras e estufa), passou a gerar `assets/comodo/regioes.json` pela projeção da câmera cilíndrica sobre os vértices e o monitor portátil em render ortográfico com a tela em alpha 0, e moveu a janela do casco no `exterior.py`; tudo por script `bpy` e numpy, sem IA de imagem e sem asset de terceiros.
