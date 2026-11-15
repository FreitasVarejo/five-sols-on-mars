extends SceneTree
## Teste headless do card da primeira vez com confirmação (terminal.gd, pedir_confirmacao), ligado à porta do
## dormitório na main: o primeiro toque abre o card azul sobre a sala e a ação espera; o relógio fica parado e a
## sala não se clica; cancelar fecha sem agir; o segundo toque age direto; a flag sobrevive ao reinício do sol
## (a missão é restaurada, o terminal não); confirmar encerra o sol; os textos vêm do CSV em inglês e português.
## Roda com: godot --headless --path . --script tests/test_card_confirmacao.gd
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


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _esperar(s: float) -> void:
	var fim := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < fim:
		await process_frame


func _esperar_terminal() -> void:
	await _quadros(2)
	var guarda := 0
	while _main._terminal.animando() and guarda < 20000:
		await process_frame
		guarda += 1
	await _quadros(2)


## Fecha os cards do plano, um por vez.
func _fechar_fila() -> void:
	_main._terminal._acionar("inicio_fase")  # o plano abre na tela inicial do Painel: a fase leva ao plano
	var n := 0
	while _main._terminal.card_aberto and n < 20:
		_main._terminal._acionar("fechar_card")
		n += 1


## Um turno sem tarefas no sol `sol`, com o terminal abaixado e o card do primeiro turno (se abrir) fechado.
func _turno(sol: int, estado: Dictionary) -> void:
	_main._missao.montar_sol(sol, estado)
	await _quadros(2)
	_fechar_fila()
	_main._missao.confirmar_plano()
	await _esperar_terminal()
	if _main._terminal.card_id == "turno":
		_main._terminal._acionar("fechar_card")
	await _quadros(2)


func _textos(t) -> Array:
	var d: Array = []
	for linha: Array in t.textos():
		d.append(linha[0])
	return d


func _tudo() -> void:
	TranslationServer.set_locale("en")
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await _quadros(3)
	_main.sobreposicao().acionar("jogar")
	_main.sobreposicao().concluida.emit()  # a viagem
	_main.sobreposicao().concluida.emit()  # a abertura
	await _quadros(2)
	if _main.tela_atual() == "pagina":
		_main.sobreposicao().avancar(1.0)
		_main.sobreposicao().acionar("continuar")
		await _quadros(2)
	var t = _main._terminal
	var m = _main._missao
	t.gravar_textos = true
	var base := {"E": 6.0, "O": 4.0, "M": 12.0, "P": 1.0, "gerador_quebrado": false}

	await _turno(1, base)
	_igual(m.fase, "turno", "turno do sol 1")
	_verdade(m.pode_encerrar_sol(), "lista vazia: pode dormir")
	_igual(t.card_aberto, false, "sem card antes do toque")

	# A sala no pan 0 (a porta à vista, as telas das barras no lugar de sempre): o card não cobre nenhuma delas.
	_main._pan = 0.0
	_main._pan_inteiro = 0
	var zonas: Array = _main._zonas_das_barras()
	_igual(zonas.size(), 3, "três zonas a evitar: energia, oxigênio e a da radiação (com o medidor)")

	# Primeiro toque: abre o card, a ação espera, o relógio para.
	_main._ao_clicar("porta")
	_igual(t.card_id, "confirmacao", "o primeiro toque abre o card de confirmação")
	_igual(m.acelerado, false, "a ação espera a confirmação")
	_igual(m.fase, "turno", "ainda no turno")
	_igual(t.segura_o_relogio(), true, "o relógio espera com o card aberto")
	await _quadros(3)
	var rc: Rect2 = t.rect_do_card_confirmacao
	_verdade(rc.size.x > 0.0 and Rect2(0, 0, 640, 360).encloses(rc), "o card cabe na tela")
	for z: Rect2 in zonas:
		_verdade(not rc.intersects(z), "o card não cobre a zona %s (card %s)" % [str(z), str(rc)])
	var t0: float = m.t
	await _esperar(1.5)
	_igual(m.t, t0, "o relógio fica parado com o card aberto")
	_igual(_main._clicavel("porta"), false, "card aberto: a sala não se clica")
	_igual(_main._regiao_em(Vector2(320, 180)), "", "card aberto: o clique na sala não pega")
	var ui: Dictionary = _main._ui_da_tela()
	_verdade(ui.has("card_confirmar") and ui.has("card_cancelar"), "os dois botões estão na tela")
	_igual(ui.has("terminal"), false, "o botão TERMINAL fica apagado")
	_igual(ui.has("fechar_card"), false, "sem Fechar neste card")
	for nome: String in ["card_confirmar", "card_cancelar"]:
		var b: Array = ui[nome]
		_verdade(Rect2(60, 60, 520, 290).encloses(Rect2(b[0], b[1], b[2], b[3])), nome + " fica abaixo do medidor e entre as setas")
	_igual(_textos(t).has("Going to sleep ends the sol."), true, "o texto da ação, em inglês, vem do CSV")
	_igual(_textos(t).has("Sent from Earth in the morning packet"), true, "o rótulo é o do pacote da manhã")
	_igual(_textos(t).has("Sleep") and _textos(t).has("Not yet"), true, "os botões em inglês")
	t._acionar("terminal")
	_igual(t.aberto, false, "o TERMINAL não sobe com o card aberto")
	t._acionar("confirmar")
	_igual(t.card_id, "confirmacao", "o resto do terminal não responde")
	_igual(m.acelerado, false, "e nada age")

	# Cancelar: fecha, não age, toca o clique de navegar, o relógio volta.
	var tocados: int = _main._som.historico.size()
	t._acionar("card_cancelar")
	_igual(t.card_aberto, false, "cancelar fecha o card")
	_igual(m.acelerado, false, "cancelar não encerra o sol")
	_igual(_main._som.historico.slice(tocados), ["clique_navegar"], "cancelar toca o clique de navegar")
	_igual(t.segura_o_relogio(), false, "o relógio volta")
	await _esperar(0.6)
	_verdade(m.t > t0 + 0.2, "o relógio anda depois de cancelar")

	# O reinício do sol restaura a missão, não o terminal: a flag fica. Sol 2 (tempestade) sem abrigo vai ao modo
	# de segurança; "o simulador reinicia o sol" volta ao plano.
	await _turno(2, {"E": 6.0, "O": 4.0, "M": 4.0, "P": 1.0, "gerador_quebrado": false})
	var guarda := 0
	while m.fase == "turno" and guarda < 2000:
		m.avancar(0.25)
		guarda += 1
	_igual(m.fase, "seguranca", "sem abrigo na tempestade: modo de segurança")
	_verdade(m.reiniciar_sol(), "o simulador reinicia o sol")
	await _turno(2, m.st_inicio)

	# Segundo toque (depois do cancelar e do reinício): age direto, sem card.
	tocados = _main._som.historico.size()
	_verdade(m.pode_encerrar_sol(), "pode dormir de novo")
	_main._ao_clicar("porta")
	_igual(t.card_aberto, false, "o segundo toque não abre o card")
	_igual(m.acelerado, true, "o segundo toque encerra o sol direto")
	_igual(_main._som.historico.slice(tocados), ["clique_confirmar"], "e toca o clique de confirmar")

	# Outra ação ainda não vista ganha o card com a mesma chamada; confirmar roda o que veio e toca confirmar.
	var rodou := [0]
	await _turno(1, base)
	_igual(t.pedir_confirmacao("dormir", func() -> void: rodou[0] += 1), false, "dormir já visto: age direto")
	TranslationServer.set_locale("pt")
	_igual(t.pedir_confirmacao("dormir", func() -> void: rodou[0] += 1), false, "idioma não zera a flag")
	_igual(t.card_aberto, false, "sem card")
	_igual(rodou[0], 0, "o chamador age sozinho quando devolve false")

	# Português, e confirmar de verdade: uma partida nova do terminal (outra página) mostra o card em português.
	var novo: Control = (load("res://scripts/terminal.gd") as GDScript).new()
	root.add_child(novo)
	novo.gravar_textos = true
	novo.iniciar(m, {})
	novo.aberto = false
	novo._pos = 0.0
	_igual(novo.pedir_confirmacao("dormir", func() -> void: rodou[0] += 1), true, "página nova: abre o card")
	await _quadros(2)
	var ts: Array = []
	for linha: Array in novo.textos():
		ts.append(linha[0])
	_verdade(ts.has("Ir dormir encerra o sol."), "o texto em português")
	_verdade(ts.has("Enviado da Terra no pacote da manhã"), "o rótulo em português")
	_verdade(ts.has("Dormir") and ts.has("Ainda não"), "os botões em português")
	novo._acionar("card_confirmar")
	_igual(rodou[0], 1, "confirmar roda a ação")
	_igual(novo.card_aberto, false, "e fecha o card")
	_igual(novo.pedir_confirmacao("dormir", func() -> void: rodou[0] += 1), false, "depois de confirmar, direto")
	novo.queue_free()

	_main.queue_free()
	await _quadros(2)
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)
