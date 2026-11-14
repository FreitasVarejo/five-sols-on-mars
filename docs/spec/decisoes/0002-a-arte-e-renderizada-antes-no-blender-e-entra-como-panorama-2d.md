> Cópia do vault do dono em 14/11/2026 09:26. Não edite aqui: proponha a mudança ao dono, que atualiza a fonte e recopia.

# 0002 — A arte é renderizada antes no Blender e entra no Godot como panorama 2D

O jogo roda no navegador, e lá o Godot só tem o renderer Compatibility (WebGL 2). Esse renderer não fornece a textura de normais de que o contorno de pixel art em 3D precisa. Por isso o cômodo é 3D gerado como script `bpy` e renderizado em baixa resolução no Blender, um PNG por estado com a mesma câmera, e o jogo é 2D com o shader de panorama CC0, o que também deixa a arte andar em paralelo à programação.

## Alternativas recusadas

- 3D ao vivo no Godot, com SubViewport pixelizado: sem contorno no Web, mais pesado em tablet e com a arte acoplada ao código.
- IA de imagem para gerar os estados do cômodo: não garante que a mesma sala fique idêntica com a luz acesa, a porta aberta ou o alarme, e traz termos de terceiros para a seção de uso de SI. Fica só para retoque por inpainting numa região.
