extends Control
## Tela de barra do cômodo (energia, oxigênio): ícone, nome, número e barra em células.
## Fica dentro da Sala, antes do shader, para curvar com a parede.
## Cor neutra (a do texto): barra de recurso nunca é verde, amarela nem azul (spec, "Terminal").
## Três formatos pelo tamanho da região: grande (as telas antigas da parede), ampla (as telas
## baixas e largas da rampa: ícone e nome à esquerda, número à direita, barra embaixo) e pequena.

const Desenho := preload("res://scripts/desenho.gd")

const FUNDO := Desenho.FUNDO_TELA
const TEXTO := Desenho.TEXTO
const CELULA_VAZIA := Desenho.CELULA_VAZIA

var nome := ""
var icone := "energia"
var valor := 0
var maximo := 1
var cor := Desenho.TEXTO


func atualizar(novo_valor: int) -> void:
	if novo_valor != valor:
		valor = novo_valor
		queue_redraw()


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
	Desenho.icone(self, icone, Rect2(margem, y, lado_icone, lado_icone), cor, FUNDO)
	draw_string(fonte, Vector2(margem + lado_icone + 6.0, y + lado_icone - (3.0 if grande else 2.0)),
		nome, HORIZONTAL_ALIGNMENT_LEFT, size.x - margem * 2.0 - lado_icone, tam_nome, TEXTO)

	y += lado_icone + (6.0 if grande else 4.0)
	draw_string(fonte, Vector2(margem, y + tam_num * 0.85), "%d/%d" % [valor, maximo],
		HORIZONTAL_ALIGNMENT_LEFT, size.x - margem * 2.0, tam_num, cor)

	var alt_barra := 20.0 if grande else 10.0
	Desenho.celulas(self, Rect2(margem, size.y - margem - alt_barra, size.x - margem * 2.0, alt_barra), valor, maximo, cor)


func _desenhar_ampla() -> void:
	var fonte := ThemeDB.fallback_font
	var margem := 8.0
	var lado_icone := 22.0
	var tam_nome := 14
	var tam_num := 34
	draw_rect(Rect2(Vector2.ZERO, size), FUNDO)

	var topo := margem
	Desenho.icone(self, icone, Rect2(margem, topo + 2.0, lado_icone, lado_icone), cor, FUNDO)
	draw_string(fonte, Vector2(margem + lado_icone + 6.0, topo + lado_icone - 1.0), nome,
		HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.5, tam_nome, TEXTO)
	# número à direita, na altura da linha do ícone
	draw_string(fonte, Vector2(margem, topo + tam_num * 0.8), "%d/%d" % [valor, maximo],
		HORIZONTAL_ALIGNMENT_RIGHT, size.x - margem * 2.0, tam_num, cor)

	var alt_barra := 16.0
	Desenho.celulas(self, Rect2(margem, size.y - margem - alt_barra, size.x - margem * 2.0, alt_barra), valor, maximo, cor)
