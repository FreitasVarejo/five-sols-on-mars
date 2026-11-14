extends Control
## Tela de barra do cômodo (energia, oxigênio, radiação): ícone, nome, número e
## barra em células. Fica dentro da Sala, antes do shader, para curvar com a parede.
## Protótipo de legibilidade: fonte padrão, valores de teste.
## Três formatos pelo tamanho da região: grande (as telas antigas da parede), ampla (as telas
## baixas e largas da rampa: ícone e nome à esquerda, número à direita, barra embaixo) e pequena.

const FUNDO := Color("#202e37")
const TEXTO := Color("#e8f0f2")
const CELULA_VAZIA := Color("#3d4f5a")

var nome := ""
var icone := "energia"
var valor := 0
var maximo := 1
var cor := Color.WHITE


func _draw() -> void:
	if size.x > size.y * 2.0:
		_desenhar_ampla()
		return
	var fonte := ThemeDB.fallback_font
	var grande := size.y > 100.0
	var tam_nome := 16 if grande else 11
	var tam_num := 36 if grande else 20
	var margem := 12.0 if grande else 7.0
	var lado_icone := 22.0 if grande else 14.0

	draw_rect(Rect2(Vector2.ZERO, size), FUNDO)

	var y := margem
	_desenhar_icone(Rect2(margem, y, lado_icone, lado_icone))
	draw_string(fonte, Vector2(margem + lado_icone + 6.0, y + lado_icone - (3.0 if grande else 2.0)),
		nome, HORIZONTAL_ALIGNMENT_LEFT, size.x - margem * 2.0 - lado_icone, tam_nome, TEXTO)

	y += lado_icone + (6.0 if grande else 4.0)
	draw_string(fonte, Vector2(margem, y + tam_num * 0.85), "%d/%d" % [valor, maximo],
		HORIZONTAL_ALIGNMENT_LEFT, size.x - margem * 2.0, tam_num, cor)

	var alt_barra := 20.0 if grande else 10.0
	var y_barra := size.y - margem - alt_barra
	var larg := size.x - margem * 2.0
	var vao := 2.0
	var larg_celula := (larg - vao * (maximo - 1)) / maximo
	for i in maximo:
		var r := Rect2(margem + i * (larg_celula + vao), y_barra, larg_celula, alt_barra)
		draw_rect(r, cor if i < valor else CELULA_VAZIA)


func _desenhar_ampla() -> void:
	var fonte := ThemeDB.fallback_font
	var margem := 8.0
	var lado_icone := 22.0
	var tam_nome := 14
	var tam_num := 34
	draw_rect(Rect2(Vector2.ZERO, size), FUNDO)

	var topo := margem
	_desenhar_icone(Rect2(margem, topo + 2.0, lado_icone, lado_icone))
	draw_string(fonte, Vector2(margem + lado_icone + 6.0, topo + lado_icone - 1.0), nome,
		HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.5, tam_nome, TEXTO)
	# número à direita, na altura da linha do ícone
	draw_string(fonte, Vector2(margem, topo + tam_num * 0.8), "%d/%d" % [valor, maximo],
		HORIZONTAL_ALIGNMENT_RIGHT, size.x - margem * 2.0, tam_num, cor)

	var alt_barra := 16.0
	var y_barra := size.y - margem - alt_barra
	var larg := size.x - margem * 2.0
	var vao := 2.0
	var larg_celula := (larg - vao * (maximo - 1)) / maximo
	for i in maximo:
		var r := Rect2(margem + i * (larg_celula + vao), y_barra, larg_celula, alt_barra)
		draw_rect(r, cor if i < valor else CELULA_VAZIA)


func _desenhar_icone(r: Rect2) -> void:
	var c := r.get_center()
	var s := r.size.x
	match icone:
		"energia":
			draw_colored_polygon(PackedVector2Array([
				r.position + Vector2(s * 0.60, 0), r.position + Vector2(s * 0.15, s * 0.58),
				r.position + Vector2(s * 0.48, s * 0.58), r.position + Vector2(s * 0.34, s),
				r.position + Vector2(s * 0.88, s * 0.38), r.position + Vector2(s * 0.54, s * 0.38),
			]), cor)
		"oxigenio":
			draw_circle(c + Vector2(0, s * 0.12), s * 0.38, cor)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -s * 0.5), c + Vector2(-s * 0.33, s * 0.0), c + Vector2(s * 0.33, s * 0.0)]), cor)
		"radiacao":
			# Trifólio: três setores de 60 graus em volta de um miolo.
			for k in 3:
				var a0 := deg_to_rad(-90.0 + k * 120.0 - 30.0)
				var pts := PackedVector2Array([c])
				for j in 7:
					pts.append(c + Vector2.from_angle(a0 + deg_to_rad(60.0) * j / 6.0) * s * 0.5)
				draw_colored_polygon(pts, cor)
			draw_circle(c, s * 0.12, FUNDO)
			draw_circle(c, s * 0.08, cor)
