extends RefCounted
## Paleta e peças de desenho do jogo: ícones por código, texto e barras de células.
## Tudo estático: quem desenha passa o CanvasItem (dentro do seu _draw).
##
## Cores [R] (spec, "Terminal"): verde só no que se clica; vermelho e amarelo só em alerta; azul só
## no que vem da Terra. O resto é neutro. Barras e ícones de recurso são neutros (TEXTO).

const TEXTO := Color("#e8f0f2")
const TEXTO_SUAVE := Color("#a9b8bf")
const TEXTO_ESCURO := Color("#10141f")  # texto sobre o card azul e sobre o verde
const FUNDO_TELA := Color("#202e37")
const FUNDO_TERMINAL := Color("#141c23")
const MOLDURA := Color("#0b0f14")
const BORDA := Color("#3d4f5a")
const CELULA_VAZIA := Color("#3d4f5a")
const NOITE := Color("#10141f")  # transições neutras: sem cor de pôr do Sol (sem fonte conferida)
const VERDE := Color("#7ed957")
const VERDE_ESCURO := Color("#3f8a2a")
const VERDE_CLARO := Color("#a8ee86")
const AMARELO := Color("#f2b631")
const VERMELHO := Color("#e8504a")
const AZUL := Color("#73bed3")

static var _negrito: FontVariation


static func fonte() -> Font:
	return ThemeDB.fallback_font


static func fonte_negrito() -> Font:
	if _negrito == null:
		_negrito = FontVariation.new()
		_negrito.base_font = ThemeDB.fallback_font
		_negrito.variation_embolden = 0.5
	return _negrito


## Desenha `s` com o canto superior esquerdo em `pos`. Com `largura` > 0, quebra em linhas (alinhado
## à esquerda) ou alinha dentro dela. Devolve a altura ocupada.
static func texto(ci: CanvasItem, s: String, pos: Vector2, tam: int, cor: Color, largura: float = -1.0,
		alinh: int = HORIZONTAL_ALIGNMENT_LEFT, negrito: bool = false) -> float:
	var f := fonte_negrito() if negrito else fonte()
	var base := Vector2(pos.x, pos.y + f.get_ascent(tam))
	if largura > 0.0:
		var tamanho := f.get_multiline_string_size(s, alinh, largura, tam)
		ci.draw_multiline_string(f, base, s, alinh, largura, tam, -1, cor)
		return tamanho.y
	ci.draw_string(f, base, s, alinh, -1, tam, cor)
	return f.get_height(tam)


static func largura_texto(s: String, tam: int, negrito: bool = false) -> float:
	var f := fonte_negrito() if negrito else fonte()
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x


static func altura_texto(s: String, tam: int, largura: float) -> float:
	return fonte().get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, largura, tam).y


## Barra de células: `valor` de `maximo`, cheia é bom. Cada célula é inteira ou vazia.
static func celulas(ci: CanvasItem, r: Rect2, valor: float, maximo: int, cor: Color = TEXTO,
		vazio: Color = CELULA_VAZIA) -> void:
	var vao := 1.0 if r.size.x / maximo < 14.0 else 2.0
	var larg := (r.size.x - vao * (maximo - 1)) / maximo
	var cheias := clampi(roundi(valor), 0, maximo)
	for i in maximo:
		ci.draw_rect(Rect2(r.position.x + i * (larg + vao), r.position.y, larg, r.size.y),
			cor if i < cheias else vazio)


## Moldura de um retângulo: `grossura` px por dentro.
static func moldura(ci: CanvasItem, r: Rect2, cor: Color, grossura: float = 1.0) -> void:
	ci.draw_rect(r, cor, false, grossura)


# --- ícones --------------------------------------------------------------------

## Ícone `nome` dentro do quadrado `r`, na cor `cor`. `fundo` é a cor de trás, para os furos.
static func icone(ci: CanvasItem, nome: String, r: Rect2, cor: Color, fundo: Color = FUNDO_TELA) -> void:
	var s := minf(r.size.x, r.size.y)
	var p := r.position
	var c := r.get_center()
	var w := maxf(1.0, roundf(s / 9.0))
	match nome:
		"energia":
			ci.draw_colored_polygon(PackedVector2Array([
				p + Vector2(s * 0.60, 0), p + Vector2(s * 0.15, s * 0.58), p + Vector2(s * 0.48, s * 0.58),
				p + Vector2(s * 0.34, s), p + Vector2(s * 0.88, s * 0.38), p + Vector2(s * 0.54, s * 0.38),
			]), cor)
		"oxigenio":
			ci.draw_circle(c + Vector2(0, s * 0.12), s * 0.38, cor)
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -s * 0.5), c + Vector2(-s * 0.33, 0), c + Vector2(s * 0.33, 0)]), cor)
		"radiacao":
			# Trifólio: três setores de 60 graus em volta de um miolo.
			for k in 3:
				var a0 := deg_to_rad(-90.0 + k * 120.0 - 30.0)
				var pts := PackedVector2Array([c])
				for j in 7:
					pts.append(c + Vector2.from_angle(a0 + deg_to_rad(60.0) * j / 6.0) * s * 0.5)
				ci.draw_colored_polygon(pts, cor)
			ci.draw_circle(c, s * 0.12, fundo)
			ci.draw_circle(c, s * 0.08, cor)
		"sol":
			ci.draw_circle(c, s * 0.2, cor)
			for k in 8:
				var d := Vector2.from_angle(k * TAU / 8.0)
				ci.draw_line(c + d * s * 0.32, c + d * s * 0.48, cor, w)
		"tempestade":
			# O Sol com um raio na frente: tempestade do Sol.
			var cs := p + Vector2(s * 0.36, s * 0.36)
			ci.draw_circle(cs, s * 0.15, cor)
			for k in 8:
				var d := Vector2.from_angle(k * TAU / 8.0)
				ci.draw_line(cs + d * s * 0.23, cs + d * s * 0.34, cor, w)
			ci.draw_colored_polygon(PackedVector2Array([
				p + Vector2(s * 0.82, s * 0.38), p + Vector2(s * 0.52, s * 0.72), p + Vector2(s * 0.68, s * 0.72),
				p + Vector2(s * 0.56, s * 1.0), p + Vector2(s * 0.98, s * 0.60), p + Vector2(s * 0.80, s * 0.60),
				p + Vector2(s * 0.92, s * 0.38)]), cor)
		"alerta":
			ci.draw_colored_polygon(PackedVector2Array([
				p + Vector2(s * 0.5, s * 0.04), p + Vector2(s * 0.98, s * 0.94), p + Vector2(s * 0.02, s * 0.94)]), cor)
			ci.draw_rect(Rect2(p.x + s * 0.45, p.y + s * 0.34, maxf(1.0, s * 0.1), s * 0.30), fundo)
			ci.draw_rect(Rect2(p.x + s * 0.45, p.y + s * 0.72, maxf(1.0, s * 0.1), maxf(1.0, s * 0.1)), fundo)
		"terra":
			# Antena parabólica com ondas.
			ci.draw_line(p + Vector2(s * 0.5, s * 0.5), p + Vector2(s * 0.5, s * 0.95), cor, w)
			ci.draw_line(p + Vector2(s * 0.3, s * 0.95), p + Vector2(s * 0.7, s * 0.95), cor, w)
			ci.draw_circle(p + Vector2(s * 0.5, s * 0.42), s * 0.1, cor)
			ci.draw_arc(p + Vector2(s * 0.5, s * 0.42), s * 0.28, deg_to_rad(120), deg_to_rad(240), 8, cor, w)
			ci.draw_arc(p + Vector2(s * 0.5, s * 0.42), s * 0.28, deg_to_rad(-60), deg_to_rad(60), 8, cor, w)
			ci.draw_arc(p + Vector2(s * 0.5, s * 0.42), s * 0.46, deg_to_rad(125), deg_to_rad(235), 8, cor, w)
			ci.draw_arc(p + Vector2(s * 0.5, s * 0.42), s * 0.46, deg_to_rad(-55), deg_to_rad(55), 8, cor, w)
		"terminal":
			ci.draw_rect(Rect2(p.x + s * 0.04, p.y + s * 0.12, s * 0.92, s * 0.66), cor, false, w)
			ci.draw_polyline(PackedVector2Array([
				p + Vector2(s * 0.22, s * 0.30), p + Vector2(s * 0.40, s * 0.45), p + Vector2(s * 0.22, s * 0.60)]), cor, w)
			ci.draw_line(p + Vector2(s * 0.50, s * 0.62), p + Vector2(s * 0.74, s * 0.62), cor, w)
			ci.draw_line(p + Vector2(s * 0.32, s * 0.92), p + Vector2(s * 0.68, s * 0.92), cor, w)
		"check":
			ci.draw_polyline(PackedVector2Array([
				p + Vector2(s * 0.12, s * 0.54), p + Vector2(s * 0.40, s * 0.80), p + Vector2(s * 0.90, s * 0.22)]),
				cor, maxf(2.0, w * 1.4))
		"circulo":
			ci.draw_arc(c, s * 0.40, 0.0, TAU, 20, cor, w)
		"estrela", "estrela_vazia":
			var pts := PackedVector2Array()
			for k in 10:
				var raio := s * (0.5 if k % 2 == 0 else 0.22)
				pts.append(c + Vector2.from_angle(-PI / 2.0 + k * PI / 5.0) * raio)
			if nome == "estrela":
				ci.draw_colored_polygon(pts, cor)
			else:
				pts.append(pts[0])
				ci.draw_polyline(pts, cor, w)
		"abrigo":
			ci.draw_polyline(PackedVector2Array([
				p + Vector2(s * 0.06, s * 0.48), p + Vector2(s * 0.5, s * 0.08), p + Vector2(s * 0.94, s * 0.48)]), cor, w)
			ci.draw_rect(Rect2(p.x + s * 0.18, p.y + s * 0.46, s * 0.64, s * 0.46), cor, false, w)
			ci.draw_rect(Rect2(p.x + s * 0.42, p.y + s * 0.62, s * 0.16, s * 0.30), cor)
		"chemcam":
			# Mira sobre a rocha.
			ci.draw_arc(c, s * 0.32, 0.0, TAU, 16, cor, w)
			ci.draw_circle(c, s * 0.08, cor)
			for k in 4:
				var d := Vector2.from_angle(k * PI / 2.0)
				ci.draw_line(c + d * s * 0.2, c + d * s * 0.5, cor, w)
		"amostra":
			# Tubo de amostra com líquido.
			ci.draw_rect(Rect2(p.x + s * 0.32, p.y + s * 0.06, s * 0.36, s * 0.88), cor, false, w)
			ci.draw_rect(Rect2(p.x + s * 0.32, p.y + s * 0.50, s * 0.36, s * 0.44), cor)
			ci.draw_line(p + Vector2(s * 0.24, s * 0.06), p + Vector2(s * 0.76, s * 0.06), cor, w)
		"planta":
			ci.draw_line(p + Vector2(s * 0.5, s * 0.95), p + Vector2(s * 0.5, s * 0.30), cor, w)
			ci.draw_colored_polygon(PackedVector2Array([
				p + Vector2(s * 0.5, s * 0.60), p + Vector2(s * 0.12, s * 0.46), p + Vector2(s * 0.22, s * 0.22),
				p + Vector2(s * 0.5, s * 0.46)]), cor)
			ci.draw_colored_polygon(PackedVector2Array([
				p + Vector2(s * 0.5, s * 0.42), p + Vector2(s * 0.88, s * 0.28), p + Vector2(s * 0.78, s * 0.04),
				p + Vector2(s * 0.5, s * 0.28)]), cor)
		"ciencia":
			ci.draw_polyline(PackedVector2Array([
				p + Vector2(s * 0.36, s * 0.08), p + Vector2(s * 0.36, s * 0.40), p + Vector2(s * 0.08, s * 0.88),
				p + Vector2(s * 0.92, s * 0.88), p + Vector2(s * 0.64, s * 0.40), p + Vector2(s * 0.64, s * 0.08)]), cor, w)
			ci.draw_line(p + Vector2(s * 0.30, s * 0.08), p + Vector2(s * 0.70, s * 0.08), cor, w)
			ci.draw_line(p + Vector2(s * 0.22, s * 0.64), p + Vector2(s * 0.78, s * 0.64), cor, w)
		"noite":
			ci.draw_circle(c, s * 0.42, cor)
			ci.draw_circle(c + Vector2(s * 0.22, -s * 0.12), s * 0.36, fundo)
