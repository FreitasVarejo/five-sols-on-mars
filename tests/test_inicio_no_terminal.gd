extends SceneTree
## Teste headless da tela inicial ligada ao terminal (scripts/terminal.gd, gancho da tela inicial): aparece
## primeiro no plano e no fim do sol, nunca no turno; o bloco da fase leva à tela da fase; as teclas da moldura
## seguem indo direto às abas; os cards do plano esperam a tela inicial e a tela do plano; a página do diário
## (card "pagina_N") vem antes da tela inicial. Sem `com_inicio` o terminal fica como era.
## Roda com: godot --headless --path . --script tests/test_inicio_no_terminal.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Terminal := preload("res://scripts/terminal.gd")
const Missao := preload("res://scripts/missao.gd")
const Som := preload("res://scripts/som.gd")
const Desenho := preload("res://scripts/desenho.gd")

const QUADRO := 1.0 / 60.0
const BLOCOS := ["inicio_fase", "inicio_cameras", "inicio_tarefas", "inicio_diario", "inicio_fontes"]

var falhas := 0
var total := 0


func _init() -> void:
	_tudo()


func _tudo() -> void:
	await _sem_com_inicio_nada_muda()
	await _plano_do_sol_1()
	await _tecla_da_moldura_vai_direto()
	await _plano_de_outro_sol_e_modo_livre()
	await _turno_nunca_tem_tela_inicial()
	await _fim_do_sol()
	await _a_pagina_vem_antes()
	await _textos_cabem_nos_blocos()
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)


func _igual(obtido, esperado, nome: String) -> void:
	total += 1
	if obtido != esperado:
		falhas += 1
		printerr("FALHOU: %s (obtido %s, esperado %s)" % [nome, str(obtido), str(esperado)])


func _verdade(valor: bool, nome: String) -> void:
	_igual(valor, true, nome)


func _quadros(n: int = 2) -> void:
	for i in n:
		await process_frame


## Espera a entrada do card (0,35 s).
func _esperar_card(t: Control) -> void:
	await _quadros(2)
	var guarda := 0
	while not t._card_entrou() and guarda < 600:
		await process_frame
		guarda += 1
	await _quadros(2)


## Um terminal no `sol` da missão fixa (ou livre), com a tela inicial ligada, já na árvore e desenhado.
func _novo(sol: int = 1, livre: bool = false, com_inicio: bool = true, turno_s: float = 0.0) -> Array:
	var m := Missao.new(1, {"livre": livre}) if livre else Missao.new(1)
	if turno_s > 0.0:
		m.turno_s = turno_s
	if sol != 1:
		m.montar_sol(sol, {"E": 12.0, "O": 12.0, "M": 12.0, "P": 1.0, "gerador_quebrado": false})
	var t: Control = Terminal.new()
	t.com_inicio = com_inicio
	t.som = Som.new()
	t.gravar_textos = true
	t.iniciar(m, {})
	root.add_child(t)
	await _quadros(3)
	return [t, m]


func _liberar(t: Control) -> void:
	root.remove_child(t)
	t.free()


func _fechar_fila(t: Control) -> int:
	var n := 0
	while t.card_aberto and n < 20:
		await _esperar_card(t)
		t._acionar("fechar_card")
		n += 1
	return n


func _sem_com_inicio_nada_muda() -> void:
	var par: Array = await _novo(1, false, false)
	var t: Control = par[0]
	_igual(t.aba_na_tela(), "plano", "sem com_inicio, o plano abre direto")
	_igual(t.card_id, "aviso", "sem com_inicio, o card do aviso abre direto")
	_igual(t.ui().has("inicio_fase"), false, "sem com_inicio, nenhum bloco")
	_liberar(t)


## O plano do sol 1: a tela inicial primeiro, os cards só depois que a criança entra no plano.
func _plano_do_sol_1() -> void:
	for loc in ["en", "pt"]:
		TranslationServer.set_locale(loc)
		var par: Array = await _novo()
		var t: Control = par[0]
		_igual(t.aba_na_tela(), "inicio", "%s: o plano abre na tela inicial" % loc)
		_igual(t.card_id, "", "%s: nenhum card por cima da tela inicial" % loc)
		_igual(t.card_aberto, false, "%s: card_aberto falso" % loc)
		_verdade(t._fila.size() >= 4, "%s: os quatro cards do plano 1 esperam na fila (%d)" % [loc, t._fila.size()])
		_igual(t.segura_o_relogio(), false, "%s: o relógio não espera nada na tela inicial" % loc)
		var ui: Dictionary = t.ui()
		for nome: String in BLOCOS:
			_verdade(ui.has(nome), "%s: o bloco %s se clica" % [loc, nome])
		_verdade(ui.has("aba_cameras") and ui.has("aba_fontes"), "%s: as teclas da moldura seguem clicáveis" % loc)
		_igual(ui.has("fechar_card"), false, "%s: sem Fechar na tela inicial" % loc)
		t._acionar("fechar_card")
		_igual(t.aba_na_tela(), "inicio", "%s: fechar_card não faz nada na tela inicial" % loc)
		# O bloco da fase: 1 toque e o plano com o primeiro card.
		t._acionar("inicio_fase")
		await _quadros(2)
		_igual(t.aba_na_tela(), "plano", "%s: o bloco da fase leva ao plano" % loc)
		_igual(t.card_id, "aviso", "%s: o aviso abre depois da tela inicial" % loc)
		_igual(t.ui().has("inicio_fase"), false, "%s: os blocos saem" % loc)
		_igual(await _fechar_fila(t), 4, "%s: os quatro cards do sol 1, como antes" % loc)
		t._acionar("inicio_fase")
		_igual(t.aba_na_tela(), "plano", "%s: o bloco não faz nada fora da tela inicial" % loc)
		# Descer e subir o terminal não traz a tela inicial de volta.
		t._definir_aberto(false)
		t._definir_aberto(true)
		_igual(t.aba_na_tela(), "plano", "%s: descer e subir não volta à tela inicial" % loc)
		_liberar(t)
	TranslationServer.set_locale("en")


## Tecla da moldura na tela inicial vai direto à aba; os cards esperam a tela do plano.
func _tecla_da_moldura_vai_direto() -> void:
	for aba: String in ["cameras", "tarefas", "diario", "fontes"]:
		var par: Array = await _novo()
		var t: Control = par[0]
		t._acionar("aba_" + aba)
		await _quadros(2)
		_igual(t.aba_na_tela(), aba, "a tecla %s abre a aba direto" % aba)
		_igual(t.card_id, "", "a aba %s não abre card por cima" % aba)
		_verdade(not t._fila.is_empty(), "os cards do plano seguem esperando (aba %s)" % aba)
		t._acionar("voltar_plano")
		await _quadros(2)
		_igual(t.aba_na_tela(), "plano", "voltar leva ao plano (aba %s)" % aba)
		_igual(t.card_id, "aviso", "ao chegar ao plano o primeiro card abre (aba %s)" % aba)
		_liberar(t)
	# Um bloco de aba também vai direto à aba.
	var par: Array = await _novo()
	var t: Control = par[0]
	t._acionar("inicio_fontes")
	_igual(t.aba_na_tela(), "fontes", "o bloco fontes abre a aba")
	_igual(t.card_id, "", "sem card por cima da aba")
	# A tecla da mesma aba fecha e volta ao plano, onde os cards abrem.
	t._acionar("aba_fontes")
	_igual(t.aba_na_tela(), "plano", "a tecla da aba aberta volta ao plano")
	_igual(t.card_id, "aviso", "e os cards abrem")
	_liberar(t)


func _plano_de_outro_sol_e_modo_livre() -> void:
	var par: Array = await _novo(2)
	var t: Control = par[0]
	var m: Missao = par[1]
	_igual(t.aba_na_tela(), "inicio", "sol 2: tela inicial primeiro")
	_igual(t.card_id, "", "sol 2: sem card por cima")
	t._acionar("inicio_fase")
	_igual(t.card_id, "aviso" if m.aviso_ativo() else "", "sol 2: o aviso só depois, se houver")
	_liberar(t)
	var par2: Array = await _novo(1, true)
	t = par2[0]
	_igual(t.aba_na_tela(), "inicio", "modo livre: tela inicial primeiro")
	t._acionar("inicio_fase")
	_igual(t.aba_na_tela(), "plano", "modo livre: o bloco da fase leva ao plano")
	_liberar(t)


func _turno_nunca_tem_tela_inicial() -> void:
	var par: Array = await _novo(2)
	var t: Control = par[0]
	var m: Missao = par[1]
	t._acionar("inicio_fase")
	await _fechar_fila(t)
	t._acionar("confirmar")
	for i in 120:
		m.avancar(QUADRO)
		t._process(QUADRO)
	await _quadros(2)
	_igual(m.fase, "turno", "o turno começou")
	_igual(t.aba_na_tela(), "tarefas", "no turno, a tela é a das tarefas")
	for nome: String in BLOCOS:
		_igual(t.ui().has(nome), false, "no turno, sem o bloco %s" % nome)
	_igual(t._inicio, false, "no turno a tela inicial não vale")
	_liberar(t)


## Confirma o plano e roda o turno (curto, sem tarefa nem tempestade) até o terminal subir no fim do sol.
func _ate_o_fim_do_sol(t: Control, m: Missao) -> void:
	await _fechar_fila(t)
	t._acionar("confirmar")
	var guarda := 0
	while m.fase != "fim_do_sol" and guarda < 4000:
		m.avancar(0.1)
		t._process(0.1)
		guarda += 1
	for i in 120:
		t._process(0.02)
	await _quadros(3)


func _fim_do_sol() -> void:
	var par: Array = await _novo(1, false, true, 10.0)
	var t: Control = par[0]
	var m: Missao = par[1]
	t._acionar("inicio_fase")
	await _ate_o_fim_do_sol(t, m)
	_igual(m.fase, "fim_do_sol", "o turno acabou")
	_igual(t.aba_na_tela(), "inicio", "o fim do sol abre na tela inicial")
	_igual(t.card_id, "", "sem card no fim do sol")
	for nome: String in BLOCOS:
		_verdade(t.ui().has(nome), "fim do sol: o bloco %s se clica" % nome)
	t._acionar("inicio_fase")
	_igual(t.aba_na_tela(), "diario", "fim do sol: o bloco da fase leva ao diário com o Enviar")
	await _quadros(2)
	_verdade(t.ui().has("enviar"), "e o Enviar à Terra se clica")
	_liberar(t)
	# As teclas vão direto também no fim do sol.
	var par2: Array = await _novo(1, false, true, 10.0)
	t = par2[0]
	m = par2[1]
	t._acionar("inicio_fase")
	await _ate_o_fim_do_sol(t, m)
	_igual(t.aba_na_tela(), "inicio", "fim do sol de novo na tela inicial")
	t._acionar("aba_fontes")
	_igual(t.aba_na_tela(), "fontes", "fim do sol: a tecla vai direto à aba")
	_liberar(t)


## A página do diário (card "pagina_N") é o primeiro item da fila: vem antes da tela inicial, e a tela inicial
## vem antes dos cards do plano.
func _a_pagina_vem_antes() -> void:
	var par: Array = await _novo()
	var t: Control = par[0]
	t._fila = ["pagina_1", "aviso", "sol1_o2"]
	t.card_id = ""
	t._abrir_proximo()
	_igual(t.card_id, "pagina_1", "a página abre mesmo com a tela inicial pendente")
	t._abrir_proximo()
	_igual(t.card_id, "", "fechada a página, nenhum card: a tela inicial vem")
	_igual(t.aba_na_tela(), "inicio", "e a tela inicial está na tela")
	_igual(t._fila, ["aviso", "sol1_o2"], "os cards esperam na fila")
	t._acionar("inicio_fase")
	_igual(t.card_id, "aviso", "só depois da tela inicial, o primeiro card")
	_liberar(t)


## Todo texto dos blocos cabe dentro do bloco, em en e pt.
func _textos_cabem_nos_blocos() -> void:
	var Tela := preload("res://scripts/tela_inicial_terminal.gd")
	var blocos := Tela.blocos()
	for loc in ["en", "pt"]:
		TranslationServer.set_locale(loc)
		var par: Array = await _novo()
		var t: Control = par[0]
		var ui: Dictionary = t.ui()
		var vistos := 0
		for linha in t.textos():
			var r := _rect_do_texto(linha)
			for nome: String in BLOCOS:
				var u: Array = ui[nome]
				var bloco := Rect2(u[0], u[1], u[2], u[3])
				if bloco.has_point(Vector2(linha[1], linha[2])):
					vistos += 1
					_verdade(bloco.encloses(r.grow(-0.5)), "%s: o texto '%s' cabe no bloco %s (%s em %s)" % [loc, linha[0], nome, str(r), str(bloco)])
		_verdade(vistos >= 14, "%s: os textos dos 5 blocos foram desenhados (%d)" % [loc, vistos])
		for nome: String in BLOCOS:
			var u: Array = ui[nome]
			var b: Rect2 = blocos["fase" if nome == "inicio_fase" else nome.trim_prefix("inicio_")]
			_igual(Rect2(u[0], u[1], u[2], u[3]), b, "%s: o bloco %s está onde a geometria diz" % [loc, nome])
		_liberar(t)
	TranslationServer.set_locale("en")


func _rect_do_texto(l: Array) -> Rect2:
	var tam: int = l[3]
	var larg: float = l[4]
	var f: Font = Desenho.fonte_negrito() if l[6] else Desenho.fonte()
	var tamanho := f.get_multiline_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, larg, tam)
	return Rect2(l[1], l[2], tamanho.x, tamanho.y)
