extends SceneTree
## Teste headless do card do primeiro turno, na main: depois do "Confirmar plano" do sol 1 da missão fixa o
## terminal desce e o card abre sobre a sala; o relógio do turno só corre depois que ele fecha; enquanto
## aberto a sala não se clica e o botão TERMINAL fica apagado (as setas seguem à vista); nenhum outro card
## abre no turno; e o card não volta no sol 2 nem no reinício do sol 1.
## Roda com: godot --headless --path . --script tests/test_primeiro_turno.gd
## Sai com código 1 se algo falhar e imprime cada falha.

var falhas := 0
var total := 0
var _main: Control


func _init() -> void:
	_tudo()


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


func _verdade(cond: bool, nome: String) -> void:
	_igual(cond, true, nome)


## Roda quadros até passarem `s` segundos de relógio da parede.
func _esperar(s: float) -> void:
	var fim := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < fim:
		await process_frame


func _esperar_terminal() -> void:
	await process_frame
	await process_frame
	var guarda := 0
	while _main._terminal.animando() and guarda < 20000:
		await process_frame
		guarda += 1
	await process_frame
	await process_frame


## Fecha os cards do plano, um por vez, e devolve quantos fechou.
func _fechar_fila() -> int:
	var n := 0
	_main._terminal._acionar("inicio_fase")  # o plano abre na tela inicial do terminal: a fase leva ao plano
	while _main._terminal.card_aberto and n < 20:
		_main._terminal._acionar("fechar_card")
		n += 1
	return n


func _tudo() -> void:
	TranslationServer.set_locale("en")
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await process_frame
	await process_frame
	_main.sobreposicao().acionar("jogar")
	_main.sobreposicao().concluida.emit()  # a viagem
	_main.sobreposicao().concluida.emit()  # a abertura
	await process_frame
	_igual(_main.tela_atual(), "pagina", "depois da abertura vem a página do diário do sol 1")
	if _main.tela_atual() == "pagina":
		_main.sobreposicao().avancar(1.0)
		_main.sobreposicao().acionar("continuar")
		await process_frame
	var t = _main._terminal
	var m = _main._missao
	_igual(_fechar_fila(), 4, "o plano do sol 1 abre com quatro cards (aviso e os três do sol 1)")
	await process_frame
	_igual(t.segura_o_relogio(), false, "no plano, o relógio não espera nada")

	# Confirmar plano no sol 1: o relógio espera desde o primeiro quadro do turno.
	t._acionar("confirmar")
	_igual(m.fase, "turno", "o turno começou")
	_igual(t.segura_o_relogio(), true, "o relógio espera já ao confirmar (antes de o terminal ver a troca)")
	await _esperar_terminal()
	_igual(t.card_id, "turno", "o card do primeiro turno abre quando o terminal chega embaixo")
	_igual(t.aberto, false, "o terminal desceu")
	_igual(t.segura_o_relogio(), true, "com o card aberto o relógio espera")

	# Com o card aberto, alguns segundos de quadros: o relógio não anda.
	await _esperar(2.5)
	_igual(m.t, 0.0, "o tempo do turno fica em 0 com o card aberto")
	_igual(m.relogio(), 0.0, "o relógio do turno fica em 0 com o card aberto")
	# A sala não se clica, o botão TERMINAL fica apagado e só o Fechar está na tela; as setas seguem à vista.
	_igual(_main._clicavel("abrigo"), false, "card aberto: o abrigo não se clica")
	_igual(_main._regiao_em(Vector2(320, 180)), "", "card aberto: o clique na sala não pega")
	var ui: Dictionary = _main._ui_da_tela()
	_verdade(ui.has("fechar_card"), "o Fechar está na tela")
	_igual(ui.has("terminal"), false, "o botão TERMINAL fica apagado (fora de ui)")
	_igual(ui.has("aba_cameras"), false, "nada do terminal se clica")
	_verdade(_main._seta_esq.visible and _main._seta_dir.visible, "as setas seguem à vista")
	t._acionar("terminal")
	_igual(t.aberto, false, "o TERMINAL não sobe com o card aberto")
	# O card cabe na tela, longe do medidor (no alto) e das setas (nas bordas).
	var f: Array = ui["fechar_card"]
	var botao := Rect2(f[0], f[1], f[2], f[3])
	_verdade(Rect2(60, 150, 520, 200).encloses(botao), "o Fechar do card fica embaixo, entre as setas")

	# Fechar: o relógio corre e nenhum outro card abre durante o turno.
	t._acionar("fechar_card")
	_igual(t.card_aberto, false, "o card fechou")
	_igual(t.segura_o_relogio(), false, "o relógio não espera mais")
	await _esperar(1.0)
	_verdade(m.t > 0.3, "depois de fechar, o relógio anda (t = %.2f)" % m.t)
	_verdade(m.relogio() > 0.0, "relogio() anda")
	_igual(t.card_aberto, false, "nenhum card durante o relógio")
	_verdade(_main._ui_da_tela().has("terminal"), "o botão TERMINAL volta")

	# Sol 2: sem card do turno. O aviso do plano abre e fecha; o turno corre desde o primeiro instante.
	m.montar_sol(2, {"E": 12.0, "O": 12.0, "M": 12.0, "P": 1.0, "gerador_quebrado": false})
	await process_frame
	await process_frame
	_igual(_main.tela_atual(), "pagina", "sol 2: a página do diário abre antes do plano")
	if _main.tela_atual() == "pagina":
		_main.sobreposicao().avancar(1.0)
		_main.sobreposicao().acionar("continuar")
		await process_frame
	_igual(_fechar_fila(), 1 if m.aviso_ativo() else 0, "o plano do sol 2 leva só o aviso (se houver)")
	t._acionar("confirmar")
	_igual(t.segura_o_relogio(), false, "sol 2: o relógio não espera nada")
	await _esperar_terminal()
	_igual(t.card_aberto, false, "sol 2: sem card no turno")
	await _esperar(0.5)
	_verdade(m.t > 0.2, "sol 2: o relógio anda (t = %.2f)" % m.t)

	# Reinício do sol 1: o card do turno não volta.
	m.montar_sol(1, {"E": 6.0, "O": 4.0, "M": 12.0, "P": 1.0, "gerador_quebrado": false})
	await process_frame
	await process_frame
	_igual(_fechar_fila(), 1 if m.aviso_ativo() else 0, "o plano do sol 1 de novo leva só o aviso (os do sol 1 não voltam)")
	t._acionar("confirmar")
	_igual(t.segura_o_relogio(), false, "sol 1 de novo: o relógio não espera")
	await _esperar_terminal()
	_igual(t.card_aberto, false, "sol 1 de novo: o card do turno não volta")
	await _esperar(0.5)
	_verdade(m.t > 0.2, "sol 1 de novo: o relógio anda (t = %.2f)" % m.t)

	_main.queue_free()
	await process_frame
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)
