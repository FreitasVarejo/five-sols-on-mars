extends Control
## HUD do turno, depois do shader (não curva e não muda com o pan). Só ícones e números, porque o
## turno não tem texto para ler:
##  - canto superior esquerdo, fixo: o sol atual, os eventos em curso (tempestade do Sol, poeira),
##    o alerta do gerador quebrado, o alerta do medidor e a lua de "pode dormir" (a porta do dormitório
##    fica na ponta da sala e só aparece virando);
##  - faixa do Sol no topo, no centro: o Sol anda da esquerda para a direita e é o relógio do turno.
## Sem cor de pôr do Sol: a cor do pôr do Sol em Marte ainda não tem fonte conferida.

const Desenho := preload("res://scripts/desenho.gd")
const Missao := preload("res://scripts/missao.gd")

const FAIXA := Rect2(200, 6, 240, 14)
const SEGUNDOS_DE_POR_DO_SOL := 10.0  # a zona do pôr do Sol no fim do trilho
const ZONA_POR_DO_SOL := Color("#1c262d")  # neutro, mais escuro que o trilho (CELULA_VAZIA)

var missao: Missao


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


## A cor do alerta do medidor: amarela em "atenção", vermelha em "abrigo", e transparente (sem alerta)
## abrigado ou abaixo da atenção. O terminal usa a mesma regra para o alerta por cima dele.
static func cor_do_alerta(m: Missao) -> Color:
	var medidor := m.medidor()
	if m.abrigado or medidor < Missao.LIMIAR_ATENCAO:
		return Color(0, 0, 0, 0)
	return Desenho.VERMELHO if medidor > Missao.LIMIAR_ABRIGO else Desenho.AMARELO


func _chip(r: Rect2) -> void:
	draw_rect(r, Color(Desenho.NOITE, 0.85))
	draw_rect(r, Desenho.BORDA, false, 1.0)
	# Relevo discreto: 1 px mais claro por dentro, no topo.
	draw_rect(Rect2(r.position.x + 1, r.position.y + 1, r.size.x - 2, 1), Color(Desenho.TEXTO, 0.12))


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
	# A tempestade de poeira, o sol inteiro: só o ícone.
	if missao.eh_poeira():
		_chip(Rect2(x, 6, 26, 22))
		Desenho.icone(self, "poeira", Rect2(x + 4, 9, 18, 16), Desenho.TEXTO, Desenho.NOITE)
		x += 30
	# O gerador quebrado e ainda não consertado: alerta amarelo, só o ícone.
	if missao.gerador_quebrado_agora():
		_chip(Rect2(x, 6, 26, 22))
		draw_rect(Rect2(x, 6, 26, 22), Desenho.AMARELO, false, 2.0)
		Desenho.icone(self, "gerador", Rect2(x + 4, 9, 18, 16), Desenho.AMARELO, Desenho.NOITE)
		x += 30
	# Pode dormir (a lista acabou): a lua, firme. A porta do dormitório encerra o sol.
	if missao.pode_encerrar_sol():
		_chip(Rect2(x, 6, 26, 22))
		Desenho.icone(self, "lua", Rect2(x + 4, 9, 18, 16), Desenho.TEXTO)
		x += 30
	# O alerta: amarelo em "atenção", vermelho em "abrigo", enquanto fora do abrigo. Fixo, sem piscar.
	var cor := cor_do_alerta(missao)
	if cor.a > 0.0:
		_chip(Rect2(x, 6, 26, 22))
		draw_rect(Rect2(x, 6, 26, 22), cor, false, 2.0)
		Desenho.icone(self, "alerta", Rect2(x + 4, 9, 18, 16), cor, Desenho.NOITE)

	_faixa_do_sol()


## Faixa do Sol: o relógio do turno. O trilho vai do começo ao horizonte, com uma marca a cada quarto;
## o trecho já andado é claro e a zona do pôr do Sol (os últimos 10 s) é um tom neutro mais escuro.
## Tudo neutro: sem azul, violeta nem amarelo.
func _faixa_do_sol() -> void:
	_chip(FAIXA)
	var cy := roundf(FAIXA.get_center().y)
	var x0 := FAIXA.position.x + 10.0
	var x1 := FAIXA.end.x - 28.0
	var comprimento := x1 - x0
	# A zona do pôr do Sol: faixa escura atrás do trilho e o trilho mais escuro dentro dela.
	var xz := x0 + roundf(comprimento * (1.0 - SEGUNDOS_DE_POR_DO_SOL / missao.turno_s))
	xz = clampf(xz, x0, x1)
	draw_rect(Rect2(xz, FAIXA.position.y + 2, x1 - xz, FAIXA.size.y - 4), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(x0, cy - 1, comprimento, 2), Desenho.CELULA_VAZIA)
	draw_rect(Rect2(xz, cy - 1, x1 - xz, 2), ZONA_POR_DO_SOL)
	# O trecho já andado.
	var cx := x0 + roundf(comprimento * missao.relogio())
	draw_rect(Rect2(x0, cy - 1, cx - x0, 2), Desenho.TEXTO)
	# Marcas a cada quarto.
	for k in 5:
		var xm := x0 + roundf(comprimento * k / 4.0)
		draw_rect(Rect2(xm, cy - 5, 1, 3), Desenho.TEXTO_SUAVE)
		draw_rect(Rect2(xm, cy + 2, 1, 3), Desenho.TEXTO_SUAVE)
	# O horizonte, no fim do trilho: meio Sol sobre uma linha.
	var gx := FAIXA.end.x - 12.0
	var gy := cy + 3.0
	var meio := PackedVector2Array()
	for j in 9:
		var a := PI + PI * j / 8.0
		meio.append(Vector2(roundf(gx + cos(a) * 5.0), roundf(gy + sin(a) * 5.0)))
	draw_colored_polygon(meio, Desenho.TEXTO_SUAVE)
	draw_rect(Rect2(gx - 7, gy, 14, 1), Desenho.TEXTO_SUAVE)
	# O Sol, por cima de tudo.
	draw_circle(Vector2(cx, cy), 6, Desenho.NOITE)
	Desenho.icone(self, "sol", Rect2(cx - 8, cy - 8, 16, 16), Desenho.TEXTO, Desenho.NOITE)
