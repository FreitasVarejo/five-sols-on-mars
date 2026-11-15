extends SceneTree
## Teste headless da porta do dormitório (main.gd, scripts/indicador_porta.gd e assets/comodo/regioes.json):
## a região existe, só se clica quando dá para encerrar o sol, o clique encerra o sol com o clique de
## confirmar, e a lâmpada acende (e a lua aparece) só quando dá.
## Roda com: godot --headless --path . --script tests/test_porta.gd
## Sai com código 1 se algo falhar e imprime cada falha.

var falhas := 0
var total := 0
var _main: Control


func _init() -> void:
	_tudo()


func _igual(obtido, esperado, nome: String) -> void:
	total += 1
	if obtido != esperado:
		falhas += 1
		printerr("FALHOU: %s (obtido %s, esperado %s)" % [nome, str(obtido), str(esperado)])


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


## Espera o terminal chegar ao alvo (os quadros do teste são curtos: o tempo real é que anda a animação).
func _esperar_terminal() -> void:
	var guarda := 0
	while _main._terminal.animando() and guarda < 20000:
		await process_frame
		guarda += 1
	await _quadros(2)


## Uma partida nova no turno do sol 1, com o plano dado, e o terminal abaixado.
func _turno(tarefas: Array) -> void:
	_main._missao.montar_sol(1, _main._missao.st)
	for nome in tarefas:
		_main._missao.alternar_tarefa(nome)
	_main._missao.confirmar_plano()
	await _quadros(2)
	await _esperar_terminal()


func _tudo() -> void:
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await _quadros(3)
	# O jogo abre na tela inicial e na abertura; o teste passa por elas até o plano do sol 1.
	_igual(_main.tela_atual(), "inicio", "o jogo abre na tela inicial")
	_main.sobreposicao().acionar("jogar")
	_main.sobreposicao().concluida.emit()
	await _quadros(2)
	_igual(_main.tela_atual(), "jogo", "depois da abertura, o jogo")
	var regioes = JSON.parse_string(FileAccess.get_file_as_string("res://assets/comodo/regioes.json"))
	_igual(regioes["botoes"].has("porta"), true, "regioes.json tem a porta clicável")
	_igual(regioes["desenho"].has("porta_lampada"), true, "regioes.json tem a lâmpada da porta (desenho)")
	var r: Dictionary = regioes["botoes"]["porta"]
	_igual(r["w"] >= 24 and r["h"] >= 24, true, "a porta tem pelo menos 24 x 24 px")

	# No plano: o terminal está aberto e a porta não se clica; a lâmpada está apagada.
	_igual(_main._clicavel("porta"), false, "plano: a porta não se clica")
	_igual(_main._indicador_porta.aceso, false, "plano: lâmpada apagada")

	# Turno com uma tarefa pendente: ainda não dá para dormir.
	await _turno(["chemcam"])
	_igual(_main._missao.fase, "turno", "turno em curso")
	_igual(_main._terminal.tapa_a_sala(), false, "terminal abaixado")
	_igual(_main._missao.pode_encerrar_sol(), false, "tarefa pendente: não pode encerrar")
	_igual(_main._clicavel("porta"), false, "tarefa pendente: a porta não se clica")
	_igual(_main._indicador_porta.aceso, false, "tarefa pendente: lâmpada apagada")
	_main._pan = 0.0
	_main._pan_inteiro = 0
	var centro := Rect2(r["x"], r["y"], r["w"], r["h"]).get_center()
	var na_tela: Vector2 = _main._panorama_para_tela(centro)
	_igual(_main._regiao_em(na_tela), "", "tarefa pendente: o clique na porta não pega")

	# Sem tarefa: dá para dormir. A porta se clica, a lâmpada acende e o clique encerra o sol.
	await _turno([])
	_igual(_main._missao.pode_encerrar_sol(), true, "lista vazia: pode encerrar")
	_igual(_main._clicavel("porta"), true, "lista vazia: a porta se clica")
	_igual(_main._indicador_porta.aceso, true, "lista vazia: lâmpada acesa")
	_main._pan = 0.0
	_main._pan_inteiro = 0
	_igual(_main._regiao_em(na_tela), "porta", "o clique no meio da porta pega")
	# Com o terminal subindo (tapando a sala), a porta não se clica, mesmo podendo dormir.
	_main._terminal._acionar("terminal")
	await _quadros(2)
	_igual(_main._terminal.tapa_a_sala(), true, "terminal subindo tapa a sala")
	_igual(_main._clicavel("porta"), false, "terminal tapando: a porta não se clica")
	_igual(_main._regiao_em(na_tela), "", "terminal tapando: o clique não pega")
	_igual(_main._indicador_porta.aceso, true, "a lâmpada segue acesa por baixo do terminal")
	_main._terminal._acionar("terminal")
	await _quadros(2)
	await _esperar_terminal()
	_igual(_main._terminal.tapa_a_sala(), false, "terminal abaixado de novo")

	# O clique encerra o sol e toca o clique de confirmar.
	var tocados: int = _main._som.historico.size()
	_main._ao_clicar("porta")
	_igual(_main._missao.acelerado, true, "a porta encerra o sol")
	_igual(_main._som.historico.slice(tocados), ["clique_confirmar"], "a porta toca o clique de confirmar")
	_igual(_main._missao.pode_encerrar_sol(), false, "acelerado: não encerra de novo")
	_igual(_main._clicavel("porta"), false, "acelerado: a porta deixa de se clicar")
	await _quadros(2)
	_igual(_main._indicador_porta.aceso, false, "acelerado: lâmpada apagada")
	var antes: int = _main._som.historico.size()
	_main._ao_clicar("porta")
	_igual(_main._som.historico.size(), antes, "a porta que não encerra nada não faz som")

	# Abrigado, com a tarefa por fazer: a lista acabou e dá para dormir.
	await _turno(["chemcam"])
	_main._missao.abrigar()
	await _quadros(2)
	_igual(_main._missao.pode_encerrar_sol(), true, "abrigado: lista acabada")
	_igual(_main._indicador_porta.aceso, true, "abrigado: lâmpada acesa")

	_main.queue_free()
	await _quadros(2)
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)
