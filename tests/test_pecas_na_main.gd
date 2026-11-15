extends SceneTree
## Teste headless das peças da aba câmeras na cena principal (main.tscn): o clique dentro do visor atravessa o
## terminal (que consome todo clique com ele aberto) e chega ao visor e à peça, sem a sala o receber; o
## arrasto do gerador (pressionar, mover com o botão, soltar) chega inteiro; e a sonda oferece os alvos do
## mapa (cam_*) e o que a peça à vista oferece (minigame), em px da tela.
## Roda com: godot --headless --path . --script tests/test_pecas_na_main.gd
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


func _movimento(pos: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	return e


func _centro(r: Array) -> Vector2:
	return Vector2(r[0] + r[2] / 2.0, r[1] + r[3] / 2.0)


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
	# Sol 2 com o gerador quebrado e o ChemCam escolhido; cards fechados; o turno com o terminal no alto.
	m.montar_sol(2, {"E": 12.0, "O": 12.0, "M": 12.0, "P": 1.0, "gerador_quebrado": true})
	await _quadros(2)
	var n := 0
	while t.card_aberto and n < 20:
		t._acionar("fechar_card")
		n += 1
	m.alternar_tarefa("chemcam")
	t._acionar("confirmar")
	await _esperar_terminal()
	t._acionar("terminal")
	await _esperar_terminal()
	t._acionar("aba_cameras")
	await _quadros(3)
	_igual(m.fase, "turno", "no turno")
	_verdade(t._visor.visible, "o visor está à vista")
	var ui: Dictionary = _main._ui_da_tela()
	for cam in ["painel", "rocha", "moxie", "visao_geral"]:
		_verdade(ui.has("cam_" + cam), "a sonda lê cam_" + cam)
	_igual(_main._ui_da_tela().has("terminal"), true, "o botão TERMINAL segue à vista")

	# O clique no mapa atravessa o terminal e chega ao visor; a sala não o recebe.
	var cliques: int = _main._cliques
	root.push_input(_botao(_centro(ui["cam_moxie"]), true), true)
	root.push_input(_botao(_centro(ui["cam_moxie"]), false), true)
	_igual(t._visor.camera_atual(), "moxie", "o clique no mapa chega ao visor")
	_igual(m.tarefas["gerador"], "rodando", "a câmera do MOXIE inicia o conserto")
	_igual(_main._cliques, cliques, "a sala não recebeu o clique")
	await _quadros(2)
	var mg: Dictionary = _main._terminal.minigame()
	_igual(mg.get("tipo", ""), "gerador", "o gerador está à vista, e a sonda o descreve")

	# O arrasto inteiro, com o botão apertado nos movimentos, conclui o conserto.
	var g = t._visor.peca("moxie")
	var peca: Array = mg["pecas"][mg["certa"]]
	var de := _centro(peca)
	var para := Vector2(mg["encaixe"][0], mg["encaixe"][1])
	root.push_input(_botao(de, true), true)
	for i in range(1, 7):
		root.push_input(_movimento(de.lerp(para, i / 6.0)), true)
	_verdade(g.posicao_da_peca(mg["certa"]).distance_to(para - g.global_position) < 2.0, "a peça seguiu o arrasto até o encaixe")
	root.push_input(_botao(para, false), true)
	_verdade(g.ocupada(), "soltar no encaixe a põe em voo")
	g.avancar(5.0)
	_verdade(g.concluida(), "o arrasto inteiro conclui o conserto")
	_igual(m.tarefas["gerador"], "feita", "a tarefa fica feita pelo concluido")
	_igual(m.gerador_quebrado_agora(), false, "o gerador está consertado")
	await _quadros(3)
	_igual(t._visor.peca("moxie"), null, "a peça sai")

	# O ChemCam: o toque num alvo, pelo viewport, dispara; a sala segue sem receber o clique.
	root.push_input(_botao(_centro(_main._ui_da_tela()["cam_rocha"]), true), true)
	root.push_input(_botao(_centro(_main._ui_da_tela()["cam_rocha"]), false), true)
	_igual(m.tarefas["chemcam"], "rodando", "a câmera da rocha inicia o ChemCam")
	await _quadros(2)
	var mc: Dictionary = _main._terminal.minigame()
	_igual(mc.get("alvos", []).size(), 4, "quatro alvos pendentes")
	var a: Array = mc["alvos"][0]
	root.push_input(_botao(Vector2(a[0], a[1]), true), true)
	root.push_input(_botao(Vector2(a[0], a[1]), false), true)
	_igual(_main._terminal.minigame()["alvos"].size(), 3, "o alvo tocado dispara")
	_igual(_main._cliques, cliques, "a sala ainda não recebeu clique nenhum")

	# Fora do visor o terminal segue consumindo o clique (a sala não o recebe).
	root.push_input(_botao(Vector2(40, 340), true), true)
	root.push_input(_botao(Vector2(40, 340), false), true)
	_igual(_main._cliques, cliques, "fora do visor o terminal ainda tapa a sala")

	_main.queue_free()
	await process_frame
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)
