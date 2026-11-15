// A vista da janela: normal ou de poeira (cross-fade), faixas de vento na poeira e a hora do dia.
// A textura do nó é a vista normal; `vista_poeira` é a de poeira. Fica na Sala, antes do shader do
// panorama, então curva com a parede: tudo aqui vai preso à grade de pixels da imagem e só mexe no
// brilho em horizontal (faixas), sem padrão de 1 px na vertical, que cintilaria ao virar a sala.

shader_type canvas_item;

uniform sampler2D vista_poeira : filter_nearest;
uniform float mistura : hint_range(0.0, 1.0) = 0.0;  // 0 vista normal, 1 vista de poeira
uniform float hora : hint_range(0.0, 1.0) = 0.0;     // 0 dia, 1 noite

// Faixas de vento: duas camadas de ruído de valor, cada faixa com a sua altura e a sua velocidade.
const float ALTURA_FAIXA_A = 7.0;   // px
const float ALTURA_FAIXA_B = 17.0;
const float CELULA_A = 56.0;        // px de comprimento do ruído
const float CELULA_B = 120.0;
const float VELOCIDADE_A = 40.0;    // px/s
const float VELOCIDADE_B = 20.0;
const float VENTO = 0.06;           // brilho: no máximo +-6%

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Ruído de valor 1D ao longo de x, uma sequência por faixa (linha).
float ruido(float x, float faixa, float celula) {
	float c = floor(x / celula);
	float f = fract(x / celula);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash(vec2(c, faixa)), hash(vec2(c + 1.0, faixa)), f);
}

void fragment() {
	vec3 normal = texture(TEXTURE, UV).rgb;
	vec3 poeira = texture(vista_poeira, UV).rgb;
	float m = smoothstep(0.0, 1.0, mistura);
	vec3 rgb = mix(normal, poeira, m);

	// Vento: só com poeira, preso à grade de pixels da imagem.
	vec2 tam = vec2(textureSize(TEXTURE, 0));
	vec2 px = floor(UV * tam);
	float xa = floor(px.x + TIME * VELOCIDADE_A);
	float xb = floor(px.x + TIME * VELOCIDADE_B);
	float na = ruido(xa, floor(px.y / ALTURA_FAIXA_A), CELULA_A);
	float nb = ruido(xb, floor(px.y / ALTURA_FAIXA_B) + 97.0, CELULA_B);
	float vento = (na - 0.5) + (nb - 0.5);  // -1 a 1
	rgb *= 1.0 + VENTO * vento * m;

	// Hora do dia: dia até 0,70; pôr do Sol de 0,70 a 0,92 (mais escuro, menos saturado e frio: em Gale o
	// pôr do Sol é azulado, como o Curiosity fotografou no sol 956); noite de 0,90 a 1,0.
	float k = smoothstep(0.70, 0.92, hora);
	float k2 = smoothstep(0.90, 1.0, hora);
	float luma = dot(rgb, vec3(0.299, 0.587, 0.114));
	vec3 por = luma * vec3(0.46, 0.54, 0.80) + rgb * vec3(0.14, 0.13, 0.20);
	rgb = mix(rgb, por, k);
	vec3 noite = vec3(0.035, 0.045, 0.085) + rgb * 0.10;
	rgb = mix(rgb, noite, k2);

	COLOR = vec4(rgb, COLOR.a);
}
