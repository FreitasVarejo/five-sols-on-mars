extends SceneTree
## Teste headless do gancho da amostra na cena principal (main.tscn): tocar a glovebox na sala faz o terminal subir
## na aba câmeras com a peça "Selar a amostra" hospedada; os três passos, pelo viewport, terminam a tarefa (e
## só eles: o relógio não); a barra da glovebox na sala é a da peça; e, com o terminal abaixado no meio da
## peça, tocar a glovebox de novo a retoma.
## Roda com: godot --headless --path . --script tests/test_amostra_na_main.gd
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


func _esperar_terminal() -> void:
	await _quadros(2)
	var guarda := 0
	while _main._terminal.animando() and guarda < 20000:
		await process_frame
		guarda += 1
	await _quadros(2)


func _botao(pos: Vector2, apertado: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = apertado
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if apertado else 0
	return e


func _centro(r: Array) -> Vector2:
	return Vector2(r[0] + r[2] / 2.0, r[1] + r[3] / 2.0)


func _toque(pos: Vector2) -> void:
	root.push_input(_botao(pos, true), true)
	root.push_input(_botao(pos, false), true)


func _tudo() -> void:
	TranslationServer.set_locale("en")
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await _quadros(2)
	_main.sobreposicao().acionar("jogar")
	_main.sobreposicao().concluida.emit()
	await process_frame
	var t = _main._terminal
	var m = _main._missao
	m.montar_sol(2, {"E": 12.0, "O": 12.0, "M": 12.0, "P": 1.0, "gerador_quebrado": false})
	await _quadros(2)
	var n := 0
	while t.card_aberto and n < 20:
		t._acionar("fechar_card")
		n += 1
	m.alternar_tarefa("amostra")
	t._acionar("confirmar")
	await _esperar_terminal()
	_igual(m.fase, "turno", "no turno")
	_igual(t.aberto, false, "o terminal começa o turno abaixado")
	_igual(m.tarefas["amostra"], "pendente", "a amostra está pendente")
	# A sala vira até a glovebox ficar à vista.
	_main._pan = _main.pan_para_ver(_main._botoes["glovebox"], 640.0, _main._alcance())
	_main._pan_alvo = _main._pan
	await _quadros(3)
	var ui: Dictionary = _main._ui_da_tela()
	_verdade(ui.has("glovebox"), "a glovebox é clicável na sala")

	# A aba tarefas mostra a linha da amostra sem botão no terminal.
	t._acionar("terminal")
	await _esperar_terminal()
	t._acionar("aba_tarefas")
	await _quadros(2)
	_igual(t.ui().has("ir_amostra"), false, "a linha da amostra não tem botão no terminal")
	_igual(t._acionar("ir_amostra"), null, "e a ação ir_amostra não existe")
	_igual(m.tarefas["amostra"], "pendente", "nada começou")
	t._acionar("terminal")
	await _esperar_terminal()
	ui = _main._ui_da_tela()

	# Tocar a glovebox: a tarefa começa, o terminal sobe na aba câmeras com a peça à vista.
	_toque(_centro(ui["glovebox"]))
	_igual(m.tarefas["amostra"], "rodando", "a glovebox inicia a amostra")
	_igual(t.aberto, true, "o terminal sobe")
	_igual(t.aba_na_tela(), "cameras", "na aba câmeras")
	await _esperar_terminal()
	var peca = t._visor.peca("glovebox")
	_verdade(peca != null, "a peça está hospedada")
	_verdade(t._visor.visible, "o visor está à vista")
	_igual(t._visor.camera_atual(), "visao_geral", "a câmera do mapa não mudou")
	var mg: Dictionary = t.minigame()
	_igual(mg.get("tipo", ""), "amostra", "a sonda descreve a peça da amostra")
	_igual(mg.get("passo", -1), 0, "no 1º passo")

	# O relógio não termina a tarefa: só a peça.
	m.avancar(m.tarefa_s + 1.0)
	_igual(m.tarefas["amostra"], "rodando", "o relógio não termina a amostra")

	# Passo 1: segura a broca, pelo viewport, até a barra encher.
	var c := _centro(mg["alvo"])
	root.push_input(_botao(c, true), true)
	_verdade(peca.segurando(), "o toque na baia da broca a segura")
	peca.avancar(1.0)
	_igual(t._progresso_da_linha("amostra"), peca.progresso(), "a barra da linha é a da peça")
	await _quadros(2)
	# Os quadros reais também andam a peça (segurando): a barra da sala acompanha a dela, não o relógio.
	_verdade(absf(float(_main._estacoes.progresso.get("amostra", -1.0)) - peca.progresso()) < 0.02, "a barra da glovebox na sala é a da peça")
	_verdade(m.progresso_tarefa("amostra") > 0.9, "enquanto o relógio da missão já passou da duração")
	peca.avancar(1.2)
	root.push_input(_botao(c, false), true)
	_igual(peca.passo(), 1, "a broca cheia passa ao tubo")

	# Passo 2: três toques no tubo.
	for k in 3:
		mg = t.minigame()
		_toque(_centro(mg["alvo"]))
	_igual(peca.graus(), 3, "três toques enchem o tubo")
	_igual(m.tarefas["amostra"], "rodando", "ainda não terminou")

	# Terminal abaixado no meio da peça: a tarefa segue rodando e a glovebox a retoma.
	t._acionar("terminal")
	await _esperar_terminal()
	_igual(t.aberto, false, "o terminal desceu")
	_igual(m.tarefas["amostra"], "rodando", "a tarefa segue rodando")
	_verdade(t._visor.peca("glovebox") == peca, "a peça segue hospedada")
	ui = _main._ui_da_tela()
	_verdade(ui.has("glovebox"), "a glovebox segue clicável com a amostra rodando")
	_toque(_centro(ui["glovebox"]))
	_igual(t.aberto, true, "tocar a glovebox sobe o terminal de novo")
	_verdade(t._visor.peca("glovebox") == peca, "e é a mesma peça, sem recriar")
	await _esperar_terminal()

	# Passo 3: a tampa. Termina a tarefa.
	mg = t.minigame()
	_igual(mg.get("passo", -1), 2, "no 3º passo")
	_toque(_centro(mg["alvo"]))
	_igual(m.tarefas["amostra"], "rodando", "selando: ainda não terminou")
	peca.avancar(2.0)
	_igual(m.tarefas["amostra"], "feita", "a peça termina a tarefa")
	_igual(m.tarefa_rodando, "", "nada roda")
	await _quadros(3)
	_igual(t._visor.peca("glovebox"), null, "a peça sai")
	_igual(m.ciencia_do_sol(), 1, "a amostra rende ciência")
	_igual(t._visor.vista_atual(), t._visor.camera_atual(), "a vista volta à câmera atual")
	_igual(t._visor_pend.get("visao_geral", false), false, "a visão geral nunca é pendência do mapa")

	_main.queue_free()
	await process_frame
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)
