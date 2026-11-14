// Persiana da janela: mostra só as primeiras `laminas` lâminas (de cima para baixo).
// A textura do nó é a persiana (assets/comodo/persiana.png); `indice` guarda a lâmina de cada pixel
// (R = lâmina * 20 + 10, 255 fora da persiana), gerado por scripts/gerar_persiana.py.
// A camada fica na Sala, então a curvatura vem do shader de panorama, que roda depois.

shader_type canvas_item;

uniform sampler2D indice : filter_nearest;
uniform int laminas = 0;

void fragment() {
	int lamina = int(floor(texture(indice, UV).r * 255.0 / 20.0));
	if (lamina >= laminas) {
		COLOR.a = 0.0;
	}
}
