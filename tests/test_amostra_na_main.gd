extends SceneTree
## Teste headless da amostra na cena principal (main.tscn): tocar a glovebox na sala começa a tarefa, faz o zoom e abre
## a vista de perto (scripts/vista_de_perto.gd) com a peça "Selar a amostra", com o relógio do turno correndo, o
## terminal fechado e bloqueado e o HUD do turno por cima; os três passos (golpes na broca, três toques no tubo, a tampa), pelo viewport, terminam a tarefa (e só
## eles: o relógio não) e a vista volta sozinha; a barra da glovebox na sala é a da peça; voltar no meio mantém a
## tarefa e a peça (escondida), e tocar a glovebox de novo traz a MESMA instância; abrigo e fim do turno liberam a
## peça; a sonda tem "minigame" no formato de sempre, "perto" e "voltar".
## Roda com: godot --headless --path . --script tests/test_amostra_na_main.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Amostra := preload("res://scripts/minigames/selar_amostra.gd")

var falhas := 0
var total := 0
var _main: Control
var _t: Control  # o terminal
var _m  # a missão
var _v: Control  # a vista de perto


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


## Anda a peça, à mão, até a agulha entrar na faixa (e a broca estar pronta).
func _esperar_agulha(peca: Control, faixa: int) -> void:
	var t := 0.0
	while t < 10.0 and not (peca.pronta() and peca.faixa_da_agulha() == faixa):
		peca.avancar(1.0 / 60.0)
		t += 1.0 / 60.0


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


## Espera a vista chegar à fase `fase` ("aberta" ou "").
func _esperar_fase(fase: String) -> void:
	await _quadros(2)
	var guarda := 0
	while _v.fase != fase and guarda < 20000:
		await process_frame
		guarda += 1
	await _quadros(2)


func _esperar_terminal() -> void:
	await _quadros(2)
	var guarda := 0
	while _t.animando() and guarda < 20000:
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


func _rect(r: Array) -> Rect2:
	return Rect2(r[0], r[1], r[2], r[3])


func _toque(pos: Vector2) -> void:
	root.push_input(_botao(pos, true), true)
	root.push_input(_botao(pos, false), true)


## Monta o sol `sol` com a amostra no plano e leva a missão ao turno, com o terminal abaixado.
func _comecar_turno(sol: int) -> void:
	_m.montar_sol(sol, {"E": 12.0, "O": 12.0, "M": 12.0, "P": 1.0, "gerador_quebrado": false})
	await _quadros(2)
	if _t.aba_na_tela() == "inicio":
		_t._acionar("inicio_fase")  # o plano abre na tela inicial do Painel: a fase leva ao plano
	var n := 0
	while _t.card_aberto and n < 20:
		_t._acionar("fechar_card")
		n += 1
	_m.alternar_tarefa("amostra")
	_t._acionar("confirmar")
	await _esperar_terminal()


func _tudo() -> void:
	TranslationServer.set_locale("en")
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await _quadros(2)
	_main.sobreposicao().acionar("jogar")
	_main.sobreposicao().concluida.emit()  # a viagem
	_main.sobreposicao().concluida.emit()  # a abertura
	await process_frame
	if _main.tela_atual() == "pagina":
		_main.sobreposicao().avancar(1.0)
		_main.sobreposicao().acionar("continuar")
		await process_frame
	_t = _main._terminal
	_m = _main._missao
	_v = _main._perto
	await _comecar_turno(2)
	_igual(_m.fase, "turno", "no turno")
	_igual(_t.aberto, false, "o terminal começa o turno abaixado")
	_igual(_m.tarefas["amostra"], "pendente", "a amostra está pendente")
	_igual(_v.fase, "", "a vista de perto começa fechada")
	# A sala vira até a glovebox ficar à vista.
	_main._pan = _main.pan_para_ver(_main._botoes["glovebox"], 640.0, _main._alcance())
	_main._pan_alvo = _main._pan
	await _quadros(3)
	var ui: Dictionary = _main._ui_da_tela()
	_verdade(ui.has("glovebox"), "a glovebox é clicável na sala")

	# A aba tarefas mostra a linha da amostra sem botão no terminal.
	_t._acionar("terminal")
	await _esperar_terminal()
	_t._acionar("aba_tarefas")
	await _quadros(2)
	_igual(_t.ui().has("ir_amostra"), false, "a linha da amostra não tem botão no terminal")
	_igual(_t._acionar("ir_amostra"), null, "e a ação ir_amostra não existe")
	_igual(_m.tarefas["amostra"], "pendente", "nada começou")
	_t._acionar("terminal")
	await _esperar_terminal()
	ui = _main._ui_da_tela()

	# Tocar a glovebox (pelo viewport): a tarefa começa, a sala faz o zoom e a vista abre com a peça.
	var pan0: int = _main._pan_inteiro
	_toque(_centro(ui["glovebox"]))
	_igual(_m.tarefas["amostra"], "rodando", "a glovebox inicia a amostra")
	_igual(_v.fase, "zoom", "a vista começa pelo zoom")
	_igual(_v.tarefa, "amostra", "da amostra")
	_igual(_main._clicavel("glovebox"), false, "no zoom a sala não se clica")
	_igual(_main._ui_da_tela().has("glovebox"), false, "e a glovebox não está em ui()")
	_verdade(_t.bloqueado, "o terminal fica bloqueado")
	_igual(_t.aberto, false, "e abaixado")
	await _esperar_fase("aberta")
	var peca = _v.peca_da_tarefa("amostra")
	_verdade(peca != null and peca.get_script() == Amostra, "a peça da amostra está hospedada na vista")
	_verdade(peca.visible and _v.visible, "e à vista")
	_igual(_t._visor.peca("glovebox"), null, "o visor do terminal não a hospeda")
	_igual(_t._visor.visible, false, "o terminal não mostra visor")
	_igual(_main._pan_inteiro, pan0, "o pan não anda com a vista aberta")
	_verdade(_main._hud_turno.visible and _main._hud_turno.z_index > _v.z_index, "o HUD do turno está visível, por cima da vista")
	_igual(_main._seta_esq.visible or _main._seta_dir.visible, false, "as setas de pan somem")
	_igual(_main._sobreposicao, null, "a vista não é a sobreposição da main")
	var mg: Dictionary = _v.minigame()
	_igual(mg.get("tipo", ""), "amostra", "a vista descreve a peça da amostra")
	_igual(mg.get("passo", -1), 0, "no 1º passo")
	_igual(_t.minigame(), {}, "e o terminal não tem peça à vista")

	# A sonda: "minigame" no formato de sempre, "perto" e "voltar".
	var sonda: Dictionary = _main._estado_da_sonda()
	_igual(sonda["perto"], {"tarefa": "amostra", "fase": "aberta"}, "a sonda: perto aberta")
	var chaves: Array = sonda["minigame"].keys()
	chaves.sort()
	_igual(chaves, ["alvo", "graus", "passo", "profundidade", "progresso", "tipo"], "a sonda: o minigame da amostra tem as chaves de sempre")
	_igual(sonda["minigame"]["alvo"].size(), 4, "a sonda: o alvo é [x, y, w, h]")
	_verdade(sonda["ui"].has("voltar") and sonda["ui"].has("mudo"), "a sonda: ui tem voltar e mudo")
	_igual(sonda["tela"], "jogo", "a sonda: a tela segue sendo jogo")

	# Onde ficam as coisas: a peça no vão do vidro, abaixo do HUD, sem cobrir o voltar nem o mudo.
	var rv := _rect(sonda["ui"]["voltar"])
	var rm := _rect(sonda["ui"]["mudo"])
	var vao: Rect2 = _v.retangulo_da_peca("glovebox")
	_verdade(vao.position.y >= 34.0, "a peça fica abaixo da faixa do HUD")
	_verdade(vao.size.x >= 420.0 and vao.size.y >= 236.0, "a peça tem ao menos o tamanho que tinha no visor (%s)" % str(vao.size))
	_verdade(not vao.intersects(rv) and not vao.intersects(rm), "a peça não cobre o voltar nem o mudo")
	_verdade(peca.get_global_rect().is_equal_approx(vao), "a peça está no retângulo do regioes.json")
	_verdade(vao.encloses(_rect(mg["alvo"])), "o alvo do passo fica dentro do vão da peça")
	_verdade(mg["alvo"][2] >= 24 and mg["alvo"][3] >= 24, "o alvo do passo é grande (%s)" % str(mg["alvo"]))

	# O relógio do turno corre; o terminal não abre.
	var r0: float = _m.relogio()
	await _quadros(30)
	_verdade(_m.relogio() > r0, "o relógio do turno avança com a vista aberta")
	_toque(Vector2(320, 342))  # onde fica o botão TERMINAL, por baixo da vista
	_igual(_t.aberto, false, "o botão do terminal, por baixo da vista, não abre o terminal")

	# O relógio não termina a tarefa: só a peça.
	_m.avancar(_m.tarefa_s + 1.0)
	_igual(_m.tarefas["amostra"], "rodando", "o relógio não termina a amostra")

	# Passo 1: golpes na broca, pelo viewport. Um golpe cinza racha um quarto; o perfeito quebra o resto.
	var c := _centro(mg["alvo"])
	_esperar_agulha(peca, Amostra.Faixa.CINZA)
	root.push_input(_botao(c, true), true)
	root.push_input(_botao(c, false), true)
	_igual(peca.profundidade(), 0.25, "o golpe cinza na baia da broca racha um quarto")
	_igual(peca.passo(), 0, "e segue no 1º passo")
	_igual(_t._progresso_da_linha("amostra"), peca.progresso(), "a barra da linha é a da peça")
	await _quadros(2)
	# Os quadros reais também andam a peça: a barra da sala acompanha a dela, não o relógio.
	_verdade(absf(float(_main._estacoes.progresso.get("amostra", -1.0)) - peca.progresso()) < 0.02, "a barra da glovebox na sala é a da peça")
	_verdade(_m.progresso_tarefa("amostra") > 0.9, "enquanto o relógio da missão já passou da duração")
	peca.avancar(Amostra.T_GOLPE + 0.05)
	_esperar_agulha(peca, Amostra.Faixa.PERFEITA)
	root.push_input(_botao(c, true), true)
	root.push_input(_botao(c, false), true)
	_igual(peca.passo(), 1, "o golpe perfeito quebra a rocha e passa ao tubo")

	# Passo 2: três toques no tubo.
	for k in 3:
		mg = _v.minigame()
		_toque(_centro(mg["alvo"]))
	_igual(peca.graus(), 3, "três toques enchem o tubo")
	_igual(_m.tarefas["amostra"], "rodando", "ainda não terminou")

	# Voltar para a sala no meio da peça: a tarefa segue, a peça fica escondida e a barra segue a peça.
	_toque(_centro(_main._estado_da_sonda()["ui"]["voltar"]))
	_igual(_v.fase, "voltando", "o botão de voltar começa a volta")
	await _esperar_fase("")
	_igual(_v.visible, false, "a vista se escondeu")
	_igual(_m.tarefas["amostra"], "rodando", "a tarefa segue rodando")
	_verdade(_v.peca_da_tarefa("amostra") == peca, "a peça foi mantida")
	_igual(peca.visible, false, "escondida")
	_igual(_t.bloqueado, false, "o terminal se desbloqueia")
	_verdade(absf(float(_main._estacoes.progresso.get("amostra", -1.0)) - peca.progresso()) < 0.02, "a barra da glovebox lê a peça escondida")
	ui = _main._ui_da_tela()
	_verdade(ui.has("glovebox"), "a glovebox segue clicável com a amostra rodando")
	_igual(ui.has("voltar"), false, "e o voltar saiu de ui()")
	_toque(_centro(ui["glovebox"]))
	_igual(_v.fase, "zoom", "tocar a glovebox de novo faz o zoom")
	_verdade(_v.peca_da_tarefa("amostra") == peca, "e é a mesma peça, sem recriar")
	await _esperar_fase("aberta")

	# Passo 3: a tampa. Termina a tarefa, e a vista volta sozinha.
	mg = _v.minigame()
	_igual(mg.get("passo", -1), 2, "no 3º passo")
	_toque(_centro(mg["alvo"]))
	_igual(_m.tarefas["amostra"], "rodando", "selando: ainda não terminou")
	peca.avancar(2.0)
	_igual(_m.tarefas["amostra"], "feita", "a peça termina a tarefa")
	_igual(_m.tarefa_rodando, "", "nada roda")
	_igual(_v.fase, "aberta", "a vista segue aberta um instante, com a amostra selada")
	await _esperar_fase("")
	_igual(_v.fase, "", "a vista voltou sozinha para a sala")
	await _quadros(3)
	_igual(_v.peca_da_tarefa("amostra"), null, "a peça foi liberada")
	_igual(_m.ciencia_do_sol(), 1, "a amostra rende ciência")
	_igual(_main._sala.scale, Vector2.ONE, "a Sala voltou à escala normal")
	_igual(_t._visor.vista_atual(), _t._visor.camera_atual(), "o visor segue na câmera atual")
	_igual(_t._visor_pend.get("visao_geral", false), false, "a visão geral nunca é pendência do mapa")

	# Abrigar com a vista aberta: a peça é liberada e a vista volta sem animação longa.
	await _comecar_turno(3)
	_main._pan = _main.pan_para_ver(_main._botoes["glovebox"], 640.0, _main._alcance())
	_main._pan_alvo = _main._pan
	await _quadros(3)
	_main._ao_clicar("glovebox")
	await _esperar_fase("aberta")
	var peca2 = _v.peca_da_tarefa("amostra")
	_verdade(peca2 != null and peca2 != peca, "uma peça nova para a nova tarefa")
	_verdade(_m.abrigar(), "abrigar")
	await _quadros(2)
	_igual(_v.fase, "voltando", "a tarefa parou por fora: a vista volta")
	var t_volta := Time.get_ticks_msec()
	await _esperar_fase("")
	_verdade(Time.get_ticks_msec() - t_volta < 400, "e sem animação longa (%d ms)" % (Time.get_ticks_msec() - t_volta))
	await _quadros(3)
	_igual(_v.peca_da_tarefa("amostra"), null, "abrigar libera a peça")
	_igual(is_instance_valid(peca2), false, "e a instância some")
	_igual(_m.tarefas["amostra"], "pendente", "a tarefa volta a pendente (cancelada)")
	_igual(_main._clicavel("glovebox"), false, "abrigado, a glovebox não se clica")

	# Fim do turno com a peça escondida: sai junto.
	await _comecar_turno(4)
	_main._pan = _main.pan_para_ver(_main._botoes["glovebox"], 640.0, _main._alcance())
	_main._pan_alvo = _main._pan
	await _quadros(3)
	_main._ao_clicar("glovebox")
	await _esperar_fase("aberta")
	_toque(_centro(_main._estado_da_sonda()["ui"]["voltar"]))
	await _esperar_fase("")
	_verdade(_v.peca_da_tarefa("amostra") != null, "escondida, a peça segue")
	_m.avancar(_m.turno_s)
	await _quadros(3)
	_igual(_v.peca_da_tarefa("amostra"), null, "o fim do turno libera a peça escondida")
	_igual(_v.fase, "", "sem vista")

	_main.queue_free()
	await process_frame
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)
