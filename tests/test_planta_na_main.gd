extends SceneTree
## Teste headless da planta na cena principal (main.tscn): tocar na estufa na sala começa a tarefa e sobe o
## terminal já na aba câmeras com a peça à vista; os toques nos botões (pelo viewport) levam luz e água à
## faixa; a peça conclui a tarefa (não o relógio); a barra da estação segue a peça.
## Roda com: godot --headless --path . --script tests/test_planta_na_main.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Planta := preload("res://scripts/minigames/cultivar_planta.gd")

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


## Toca no botão `nome` ("luz_mais", "agua_menos"...) da peça à vista, pelo viewport.
func _tocar(nome: String) -> void:
	var c := _centro(_main._terminal.minigame()["botoes"][nome])
	root.push_input(_botao(c, true), true)
	root.push_input(_botao(c, false), true)


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
	m.alternar_tarefa("planta")
	t._acionar("confirmar")
	await _esperar_terminal()
	_igual(m.fase, "turno", "no turno")
	_igual(t.aberto, false, "o terminal desce no turno")
	_igual(m.tarefas["planta"], "pendente", "a planta está pendente")
	_verdade("planta" in m.POR_PECA, "a planta só acaba pela peça")
	_verdade(_main._clicavel("estufa"), "a estufa é clicável")

	# Tocar na estufa: a tarefa começa e o terminal sobe com a peça à vista.
	_main._ao_clicar("estufa")
	_igual(m.tarefas["planta"], "rodando", "tocar na estufa inicia a planta")
	_verdade(t.aberto, "o terminal sobe")
	await _esperar_terminal()
	await _quadros(2)
	_igual(t.aba_na_tela(), "cameras", "na aba câmeras")
	_verdade(t._visor.visible, "o visor está à vista")
	var mg: Dictionary = t.minigame()
	_igual(mg.get("tipo", ""), "planta", "a peça da planta está à vista, e a sonda a descreve")

	# O relógio não termina a tarefa: passa o tempo todo da tarefa e ela segue rodando.
	var peca = t._visor.peca("estufa")
	_verdade(peca != null, "a peça está hospedada na estufa")
	m.avancar(m.tarefa_s + 1.0)
	await _quadros(2)
	_igual(m.tarefas["planta"], "rodando", "o relógio não termina a planta")
	_verdade(is_instance_valid(t._visor.peca("estufa")), "a peça segue hospedada")
	_igual(_main._terminal.progresso_da_tarefa("planta"), 0.0, "a barra segue a peça (0 até a planta crescer)")

	# Os toques pelo viewport levam luz e água à faixa; a peça conclui.
	var luz: int = mg["luz"]
	var agua: int = mg["agua"]
	var guarda := 0
	while not peca.na_faixa(0) and guarda < 20:
		_tocar("luz_mais" if peca.nivel(0) < Planta.FAIXA_DE else "luz_menos")
		guarda += 1
	_verdade(peca.na_faixa(0), "a luz entrou na faixa por toques (partiu de %d)" % luz)
	_igual(m.tarefas["planta"], "rodando", "só a luz na faixa: a tarefa segue")
	guarda = 0
	while not peca.na_faixa(1) and guarda < 20:
		_tocar("agua_mais" if peca.nivel(1) < Planta.FAIXA_DE else "agua_menos")
		guarda += 1
	_verdade(peca.na_faixa(1), "a água entrou na faixa por toques (partiu de %d)" % agua)
	_igual(m.tarefas["planta"], "rodando", "os dois na faixa: a planta ainda cresce")
	peca.avancar(Planta.T_CRESCER + 0.1)
	_igual(m.tarefas["planta"], "feita", "a peça conclui a tarefa")
	await _quadros(3)
	_igual(t._visor.peca("estufa"), null, "a peça sai")
	_igual(t._visor.vista_atual(), t._visor.camera_atual(), "a vista volta à câmera atual")

	# Outro sol: a aba tarefas mostra a linha da planta sem botão, e o toque na estufa começa a peça.
	m.montar_sol(3, {"E": 12.0, "O": 12.0, "M": 12.0, "P": 1.0, "gerador_quebrado": false})
	await _quadros(2)
	n = 0
	while t.card_aberto and n < 20:
		t._acionar("fechar_card")
		n += 1
	m.alternar_tarefa("planta")
	t._acionar("confirmar")
	await _esperar_terminal()
	t._acionar("terminal")
	await _esperar_terminal()
	_igual(t.aba_na_tela(), "tarefas", "o turno abre na aba tarefas")
	await _quadros(2)
	_igual(t.ui().has("ir_planta"), false, "a linha da planta não tem botão no terminal")
	_igual(t._pode_ir_a_camera("planta"), true, "mas a tarefa pode começar (pela estufa)")
	_igual(t._acionar("ir_planta"), null, "e a ação ir_planta não existe")
	_igual(m.tarefas["planta"], "pendente", "ir_planta não inicia nada")
	t._acionar("terminal")
	await _esperar_terminal()
	_verdade(_main._clicavel("estufa"), "a estufa é clicável")
	_main._ao_clicar("estufa")
	await _esperar_terminal()
	_igual(m.tarefas["planta"], "rodando", "tocar na estufa inicia a planta")
	var peca2 = t._visor.peca("estufa")
	_verdade(peca2 != null, "a peça está na estufa")

	# Terminal abaixado no meio: a tarefa segue rodando e tocar na estufa de novo retoma a mesma peça.
	t._acionar("terminal")
	await _esperar_terminal()
	_igual(t.aberto, false, "o terminal desceu")
	_igual(m.tarefas["planta"], "rodando", "a tarefa segue rodando")
	_verdade(_main._clicavel("estufa"), "a estufa segue clicável com a planta rodando")
	_main._ao_clicar("estufa")
	await _esperar_terminal()
	_igual(t.aberto, true, "tocar a estufa sobe o terminal de novo")
	_igual(t.aba_na_tela(), "cameras", "na aba câmeras")
	_verdade(t._visor.peca("estufa") == peca2, "é a mesma peça, sem recriar")
	_igual(t.minigame().get("tipo", ""), "planta", "e está à vista")

	_main.queue_free()
	await process_frame
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)
