# Uso de IA (SI) no projeto

Base para o campo de uso de SI do formulário de submissão. Uma linha por bloco de trabalho, com data, ferramenta, o que ela fez e o que ficou de fora. Exemplo:

- 14/11: Claude Code gerou o esqueleto do projeto Godot e o script de publicação; nenhum asset do jogo.

## Registro

- 14/11: Claude Code gerou o esqueleto do projeto Godot (640×360, preset Web), o `scripts/publicar.sh` e este briefing a partir da spec do dono.
- 14/11: Claude Code escreveu o protótipo do pipeline de arte (`arte/blender/comodo.py`): script `bpy` que gera o módulo de comando em gray-box e renderiza os 4 estados no Cycles, com contorno por profundidade, normal e índice e paleta Apollo (AdamCYounis); e `arte/blender/comparar_camera.py`, que compara câmera cilíndrica e perspectiva com o shader de panorama reproduzido em numpy. Nenhuma IA de imagem e nenhum inpainting.
- 14/11: Claude Code (subagente implementador) escreveu o protótipo da câmera: pan por mouse e setas, o shader CC0 de b en com uma linha trocada (`texelFetch`), o script do placeholder em grade e as texturas dos botões geradas, e testou no navegador com Playwright; nenhum asset de terceiros, e nenhum código do Cupcakes Framework copiado.
