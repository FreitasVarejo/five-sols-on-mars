extends Control
## HUD do turno, depois do shader (não curva e não muda com o pan). Só ícones e números, porque o
## turno não tem texto para ler:
##  - canto superior esquerdo, fixo: o sol atual, o evento em curso e o alerta do medidor;
##  - faixa do Sol no topo, no centro: o Sol anda da esquerda para a direita e é o relógio do turno.
## Sem cor de pôr do Sol: a cor do pôr do Sol em Marte ainda não tem fonte conferida.

const Desenho := preload("res://scripts/desenho.gd")
const Missao := preload("res://scripts/missao.gd")

const FAIXA := Rect2(200, 6, 240, 14)

var missao: Missao


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _chip(r: Rect2) -> void:
	draw_rect(r, Color(Desenho.NOITE, 0.8))
	draw_rect(r, Desenho.BORDA, false, 1.0)


func _draw() -> void:
	if missao == null:
		return
	var x := 6.0
	# O sol atual: ícone de dia e o número.
	var rs := Rect2(x, 6, 46, 22)
	_chip(rs)
	Desenho.icone(self, "sol", Rect2(x + 5, 9, 16, 16), Desenho.TEXTO, Desenho.NOITE)
	Desenho.texto(self, str(missao.sol), Vector2(x + 25, 7), 15, Desenho.TEXTO, 20, HORIZONTAL_ALIGNMENT_LEFT, true)
	x += rs.size.x + 4
	# O evento em curso: tempestade do Sol, do pico em diante.
	if missao.tempestade_em_curso():
		_chip(Rect2(x, 6, 26, 22))
		Desenho.icone(self, "tempestade", Rect2(x + 4, 9, 18, 16), Desenho.TEXTO, Desenho.NOITE)
		x += 30
	# O alerta: amarelo em "atenção", vermelho em "abrigo", enquanto fora do abrigo. Fixo, sem piscar.
	var m := missao.medidor()
	if not missao.abrigado and m >= Missao.LIMIAR_ATENCAO:
		var cor := Desenho.VERMELHO if m > Missao.LIMIAR_ABRIGO else Desenho.AMARELO
		_chip(Rect2(x, 6, 26, 22))
		draw_rect(Rect2(x, 6, 26, 22), cor, false, 2.0)
		Desenho.icone(self, "alerta", Rect2(x + 4, 9, 18, 16), cor, Desenho.NOITE)

	# Faixa do Sol: o relógio do turno.
	draw_rect(FAIXA, Color(Desenho.NOITE, 0.8))
	draw_rect(FAIXA, Desenho.BORDA, false, 1.0)
	draw_line(Vector2(FAIXA.position.x + 4, FAIXA.get_center().y), Vector2(FAIXA.end.x - 4, FAIXA.get_center().y),
		Desenho.CELULA_VAZIA, 2.0)
	var andou := FAIXA.size.x - 20.0
	var cx := FAIXA.position.x + 10.0 + andou * missao.relogio()
	draw_line(Vector2(FAIXA.position.x + 4, FAIXA.get_center().y), Vector2(cx, FAIXA.get_center().y), Desenho.TEXTO, 2.0)
	draw_circle(Vector2(cx, FAIXA.get_center().y), 6, Desenho.NOITE)
	Desenho.icone(self, "sol", Rect2(cx - 8, FAIXA.get_center().y - 8, 16, 16), Desenho.TEXTO, Desenho.NOITE)
