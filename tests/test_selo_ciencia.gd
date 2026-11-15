extends SceneTree
## Teste headless do selo "+N" de ciência (scripts/selo_ciencia.gd): o texto, o tamanho e o lugar, que nunca
## cobre o medidor, as barras do cabeçalho, as teclas, o alerta nem o botão TERMINAL.
## Roda com: godot --headless --path . --script tests/test_selo_ciencia.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Selo := preload("res://scripts/selo_ciencia.gd")
const Mov := preload("res://scripts/movimento_aviso.gd")
const Terminal := preload("res://scripts/terminal.gd")
const HudTurno := preload("res://scripts/hud_turno.gd")

var falhas := 0
var total := 0


func _init() -> void:
	_texto_e_tamanho()
	_lugar_com_o_terminal_embaixo()
	_lugar_com_o_terminal_no_alto()
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)


func _igual(obtido, esperado, nome: String) -> void:
	total += 1
	var bate := false
	if (obtido is float or obtido is int) and (esperado is float or esperado is int):
		bate = absf(float(obtido) - float(esperado)) < 1e-6
	else:
		bate = obtido == esperado
	if not bate:
		falhas += 1
		printerr("FALHOU: %s (obtido %s, esperado %s)" % [nome, str(obtido), str(esperado)])


func _verdade(valor: bool, nome: String) -> void:
	_igual(valor, true, nome)


func _texto_e_tamanho() -> void:
	_igual(Selo.rotulo(1), "+1", "rótulo: +1")
	_igual(Selo.rotulo(12), "+12", "rótulo: +12")
	_verdade(Selo.tamanho(12).x > Selo.tamanho(1).x, "tamanho: dois dígitos são mais largos")
	_igual(Selo.tamanho(1).y, Selo.ALTURA, "tamanho: a altura é fixa")
	_verdade(Selo.retangulo(1, Mov.SELO_S, false).size.x == 0.0, "retângulo: vazio quando o selo some")
	_verdade(Selo.retangulo(1, 0.5, false).size.x > 0.0, "retângulo: existe enquanto o selo está à vista")


## Cada retângulo do selo ao longo da vida, já com a escala elástica em torno do centro, fora das zonas proibidas.
func _fora_das_zonas(terminal_no_alto: bool, zonas: Array, nome: String) -> void:
	var ok := true
	for i in 151:
		var t := i * 0.01
		var r := Selo.retangulo(1, t, terminal_no_alto)
		if r.size.x <= 0.0:
			continue
		var k := Mov.escala(t)
		var maior := Rect2(r.get_center() - r.size * k / 2.0, r.size * k)
		for z: Rect2 in zonas:
			if maior.intersects(z):
				ok = false
				printerr("  o selo em t=%.2f (%s) cobre %s" % [t, str(maior), str(z)])
	_verdade(ok, nome)


## As barras do cabeçalho do turno (_cabecalho_aba: x 284 a 624, y 12 a 36, com a moldura da falha) e a faixa do Sol.
func _lugar_com_o_terminal_embaixo() -> void:
	var zonas := [
		Rect2(280, 8, 348, 32),                 # as três barras
		HudTurno.FAIXA,                         # o relógio do turno
		Rect2(6, 6, 170, 22),                   # os chips do HUD (sol, evento, poeira, gerador, lua, alerta)
		Terminal.BOTAO,                         # o botão TERMINAL
		Rect2(0, 120, 40, 120),                 # as setas do pan, nas bordas
	]
	_fora_das_zonas(false, zonas, "lugar (terminal embaixo): não cobre barras, relógio, chips, botão nem setas")
	_verdade(Selo.origem(false).x < 100.0 and Selo.origem(false).y < 80.0, "lugar (terminal embaixo): no canto superior esquerdo")


func _lugar_com_o_terminal_no_alto() -> void:
	var zonas := [Terminal.TELA_COM_TECLAS, Terminal.ALERTA, Terminal.BOTAO]
	for tecla_y: float in Terminal.TECLAS_Y:
		zonas.append(Rect2(Terminal.TECLA_X, tecla_y, Terminal.TECLA_W, Terminal.TECLA_H))
	_fora_das_zonas(true, zonas, "lugar (terminal no alto): não cobre tela, teclas, alerta nem o botão")
