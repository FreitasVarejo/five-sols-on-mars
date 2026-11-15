extends SceneTree
## Teste headless da planta na cena principal (main.tscn): tocar na estufa na sala começa a tarefa, faz o zoom e abre
## a vista de perto (scripts/vista_de_perto.gd) com a peça, o problema do sol da missão, o relógio do turno
## correndo, o terminal fechado e bloqueado e o HUD do turno por cima; os toques nos botões (pelo viewport)
## acendem a luz e usam a ferramenta certa; voltar mantém a tarefa e a peça (escondida) e tocar de novo traz a
## MESMA instância; a peça conclui a tarefa e a vista volta sozinha; abrigo, fim do turno e reinício liberam a peça;
## a barra da estação lê o progresso da peça; a sonda tem "minigame" no formato de sempre, "perto" e "voltar".
## Roda com: godot --headless --path . --script tests/test_planta_na_main.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Planta := preload("res://scripts/minigames/cultivar_planta.gd")
const Missao := preload("res://scripts/missao.gd")

var falhas := 0
var total := 0
var _main: Control
var _t: Control  # o terminal
var _m: Missao
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


## Toca no botão `nome` ("luz", "regador", "ventilador" ou "tesoura") da peça à vista, pelo viewport.
func _tocar(nome: String) -> void:
	_toque(_centro(_v.minigame()["botoes"][nome]))


## A ferramenta certa agora, pela sonda: com mofo a tesoura, depois o ventilador (umidade acima de 0) ou o regador.
func _certa(mg: Dictionary) -> String:
	if mg["mofo"] > 0:
		return "tesoura"
	return "ventilador" if mg["umidade"] > 0 else "regador"


## Os toques de um acerto pelo viewport: a luz e a ferramenta certa até a planta crescer.
func _curar_pelo_viewport(peca) -> void:
	if not peca.luz_acesa():
		_tocar("luz")
	var guarda := 0
	while not peca.ocupada() and guarda < 8:
		_tocar(_certa(_v.minigame()))
		guarda += 1


## Monta o sol `sol` com a planta no plano e leva a missão ao turno, com o terminal abaixado.
func _comecar_turno(sol: int) -> void:
	_m.montar_sol(sol, {"E": 12.0, "O": 12.0, "M": 12.0, "P": 1.0, "gerador_quebrado": false})
	await _quadros(2)
	if _t.aba_na_tela() == "inicio":
		_t._acionar("inicio_fase")  # o plano abre na tela inicial do Painel: a fase leva ao plano
	var n := 0
	while _t.card_aberto and n < 20:
		_t._acionar("fechar_card")
		n += 1
	_m.alternar_tarefa("planta")
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
	_igual(_t.aberto, false, "o terminal desce no turno")
	_igual(_m.tarefas["planta"], "pendente", "a planta está pendente")
	_verdade("planta" in _m.POR_PECA, "a planta só acaba pela peça")
	_verdade(_main._clicavel("estufa"), "a estufa é clicável")
	_igual(_v.fase, "", "a vista de perto começa fechada")
	_igual(_v.visible, false, "e escondida")
	_igual(_main._estado_da_sonda()["perto"], {"tarefa": "", "fase": ""}, "a sonda: perto vazio")
	_igual(_main._estado_da_sonda()["ui"].has("voltar"), false, "a sonda: sem voltar com a vista fechada")

	# Tocar na estufa: a tarefa começa, a sala faz o zoom e a vista abre. Durante o zoom nada da sala se clica.
	var pan0: int = _main._pan_inteiro
	_main._ao_clicar("estufa")
	_igual(_m.tarefas["planta"], "rodando", "tocar na estufa inicia a planta")
	_igual(_v.fase, "zoom", "a vista começa pelo zoom")
	_igual(_v.tarefa, "planta", "da planta")
	_igual(_main._estado_da_sonda()["perto"], {"tarefa": "planta", "fase": "zoom"}, "a sonda: perto em zoom")
	for nome in ["estufa", "glovebox", "abrigo", "porta"]:
		_igual(_main._clicavel(nome), false, "no zoom a sala não se clica: %s" % nome)
	_igual(_main._regiao_em(Vector2(320, 180)), "", "no zoom nenhum ponto da sala vale")
	_verdade(_t.bloqueado, "o terminal fica bloqueado")
	var peca = _v.peca_da_tarefa("planta")
	_verdade(peca != null and peca.get_script() == Planta, "a peça da planta nasce com a tarefa")
	_verdade(_main._ui_da_tela().has("mudo"), "o botão de mudo segue na tela")
	_igual(_main._ui_da_tela().has("estufa"), false, "e a estufa não está mais em ui()")
	await _quadros(3)
	_verdade(_v.zoom() > 0.0 and _main._sala.scale.x > 1.0, "a Sala está crescendo até a estação")
	await _esperar_fase("aberta")
	_igual(_v.fase, "aberta", "a vista abre")
	_verdade(absf(_main._sala.scale.x - _main.ZOOM_SALA) < 0.01, "a Sala fica no zoom máximo atrás da vista")
	_igual(_main._pan_inteiro, pan0, "o pan não anda com a vista aberta")
	_verdade(_v.visible and _v.modulate.a >= 0.99, "a vista está à vista, inteira")
	_igual(_t.aberto, false, "o terminal segue abaixado")
	_igual(_t.posicao(), 0.0, "e parado embaixo")
	_igual(_t.aba_na_tela(), "tarefas", "e não abriu na aba câmeras")
	_igual(_t._visor.visible, false, "o visor do terminal não mostra a peça")
	_igual(_t._visor.peca("estufa"), null, "o visor não hospeda a planta")
	_verdade(_main._hud_turno.visible, "o HUD do turno segue visível")
	_verdade(_main._hud_turno.z_index > _v.z_index, "e fica por cima da vista")
	_igual(_main._seta_esq.visible or _main._seta_dir.visible, false, "as setas de pan somem")
	_igual(_main._esq_pressionada or _main._dir_pressionada, false, "e estão soltas")
	_igual(_main._sobreposicao, null, "a vista não é a sobreposição da main")
	_igual(_main.tela_atual(), "jogo", "e a tela segue sendo o jogo")
	var mg: Dictionary = _v.minigame()
	_igual(mg.get("tipo", ""), "planta", "a peça da planta está à vista, e a vista a descreve")
	_igual(_t.minigame(), {}, "e o terminal não tem peça à vista")

	# A sonda: "minigame" no formato de sempre, "perto" e "voltar".
	var sonda: Dictionary = _main._estado_da_sonda()
	_igual(sonda["perto"], {"tarefa": "planta", "fase": "aberta"}, "a sonda: perto aberta")
	var chaves: Array = sonda["minigame"].keys()
	chaves.sort()
	_igual(chaves, ["botoes", "luz_acesa", "mofo", "problema", "progresso", "tipo", "umidade"], "a sonda: o minigame da planta tem as chaves de sempre")
	_igual(sonda["minigame"]["botoes"].keys().size(), 4, "a sonda: os quatro botões")
	_verdade(sonda["ui"].has("voltar") and sonda["ui"].has("mudo"), "a sonda: ui tem voltar e mudo")
	_igual(sonda["tela"], "jogo", "a sonda: a tela segue sendo jogo")
	_igual(sonda["terminal_aberto"], false, "a sonda: o terminal fechado")
	_igual(sonda["ui"].has("terminal"), false, "a sonda: sem o botão do terminal em ui()")

	# Onde ficam as coisas: a peça no vão do vidro, fora do HUD (y < 34), sem cobrir o voltar nem o mudo.
	var rv := _rect(sonda["ui"]["voltar"])
	var rm := _rect(sonda["ui"]["mudo"])
	var vao: Rect2 = _v.retangulo_da_peca("estufa")
	_verdade(vao.position.y >= 34.0, "a peça fica abaixo da faixa do HUD")
	_verdade(not vao.intersects(rv), "a peça não cobre o botão de voltar")
	_verdade(not vao.intersects(rm), "a peça não cobre o botão de mudo")
	_verdade(not rv.intersects(rm), "o voltar e o mudo não se sobrepõem")
	_verdade(rv.position.y >= 0.0 and rv.size.x >= 44.0 and rv.size.y >= 28.0, "o botão de voltar é grande (%s)" % str(rv))
	_verdade(Rect2(0, 0, 640, 360).encloses(rv), "o voltar cabe na tela")
	_verdade(peca.get_global_rect().is_equal_approx(vao), "a peça está no retângulo do regioes.json")
	for nome in ["luz", "regador", "ventilador", "tesoura"]:
		var rb := _rect(mg["botoes"][nome])
		_verdade(vao.encloses(rb), "o botão %s fica dentro do vão da peça" % nome)
		_verdade(not rb.intersects(rv) and not rb.intersects(rm), "o botão %s não cobre o voltar nem o mudo" % nome)
		_verdade(rb.size.x >= 40.0 and rb.size.y >= 40.0, "o botão %s tem ao menos 40 px (%s)" % [nome, str(rb.size)])
	var hud_baixo := 34.0
	for chip in [Rect2(6, 6, 46, 22), Rect2(200, 6, 240, 14)]:
		_verdade(not vao.intersects(chip) and chip.end.y <= hud_baixo, "a peça não cobre o HUD do turno")

	# O relógio do turno corre na vista de perto.
	var r0: float = _m.relogio()
	var t0: float = _m.t
	await _quadros(30)
	_verdade(_m.relogio() > r0 and _m.t > t0, "o relógio do turno avança com a vista aberta")
	_igual(_t.segura_o_relogio(), false, "e o terminal não o segura")

	# Nada da sala se clica, e o terminal não abre: toques na sala e no botão do terminal não fazem nada.
	var cliques0: int = _main._cliques
	_toque(Vector2(20, 200))
	_toque(Vector2(320, 342))  # onde fica o botão TERMINAL, por baixo da vista
	_igual(_main._cliques, cliques0, "toque fora da peça e do voltar não chega à sala")
	_igual(_t.aberto, false, "o botão do terminal, por baixo da vista, não abre o terminal")
	var mudo0: bool = _main._som.esta_mudo()
	_toque(_centro(sonda["ui"]["mudo"]))
	_igual(_main._som.esta_mudo(), not mudo0, "o botão de mudo segue valendo")
	_toque(_centro(sonda["ui"]["mudo"]))

	# A peça: o problema e o estado de abertura.
	_igual(mg["problema"], "encharcada", "o sol 2 da fixa: a planta é a encharcada")
	_igual(mg["problema"], _m.problema_da_planta(), "o problema da peça é o da missão")
	_igual(peca.problema(), "encharcada", "a peça tem o problema da missão")
	_igual([mg["umidade"], mg["mofo"], mg["luz_acesa"]], [1, 0, false], "a peça abre sob a luz rosa")

	# O relógio não termina a tarefa: passa o tempo todo da tarefa e ela segue rodando.
	_m.avancar(_m.tarefa_s + 1.0)
	await _quadros(2)
	_igual(_m.tarefas["planta"], "rodando", "o relógio não termina a planta")
	_igual(_main._terminal.progresso_da_tarefa("planta"), 0.0, "a barra segue a peça (0 até a planta crescer)")

	# Toques pelo viewport: a ferramenta antes da luz é ignorada; a luz acende; um erro piora e se desfaz.
	_tocar("ventilador")
	_igual(_v.minigame()["umidade"], 1, "a ferramenta antes da luz é ignorada")
	_tocar("luz")
	_verdade(_v.minigame()["luz_acesa"], "o toque na luz acende")
	_tocar("regador")
	_igual(_v.minigame()["umidade"], 2, "o regador a mais piora (+2)")
	_igual(_m.tarefas["planta"], "rodando", "o erro não termina a tarefa")

	# Voltar para a sala: a tarefa e a peça ficam (escondida, a mesma instância).
	_toque(_centro(_main._estado_da_sonda()["ui"]["voltar"]))
	_igual(_v.fase, "voltando", "o botão de voltar começa a volta")
	_igual(_main._estado_da_sonda()["perto"]["fase"], "voltando", "a sonda: voltando")
	_igual(_v.minigame(), {}, "voltando, a peça já não oferece alvos")
	await _esperar_fase("")
	_igual(_v.fase, "", "a vista fechou")
	_igual(_v.visible, false, "e se escondeu")
	_igual(_main._sala.scale, Vector2.ONE, "a Sala voltou à escala normal")
	_igual(_main._sala.position, Vector2(-_main._pan_inteiro, 0), "e ao lugar de antes")
	_igual(_m.tarefas["planta"], "rodando", "a tarefa segue rodando")
	_verdade(_v.peca_da_tarefa("planta") == peca and is_instance_valid(peca), "a peça foi mantida, não recriada")
	_igual(peca.visible, false, "mas escondida")
	_igual(_t.bloqueado, false, "o terminal se desbloqueia")
	_igual(_t.aberto, false, "e segue abaixado")
	_igual(_main._hud_turno.z_index, 0, "o HUD do turno volta ao z de antes")
	_igual(_main._estado_da_sonda()["perto"], {"tarefa": "", "fase": ""}, "a sonda: perto vazio de novo")
	_igual(_main._estado_da_sonda()["ui"].has("voltar"), false, "a sonda: sem voltar")
	_verdade(_main._clicavel("estufa"), "a estufa segue clicável com a planta rodando")
	_verdade(_main._clicavel("abrigo"), "e a sala volta a responder")
	var tempo0: float = peca._tempo
	await _quadros(10)
	_verdade(peca._tempo > tempo0, "a peça segue andando escondida")

	# Tocar de novo: a MESMA peça, com o estado de antes (luz acesa, umidade 2).
	_main._ao_clicar("estufa")
	_igual(_v.fase, "zoom", "tocar a estufa de novo faz o zoom")
	_verdade(_v.peca_da_tarefa("planta") == peca, "é a mesma instância")
	await _esperar_fase("aberta")
	_igual([_v.minigame()["luz_acesa"], _v.minigame()["umidade"]], [true, 2], "com o estado de antes: a luz acesa e a umidade em 2")
	_verdade(peca.visible, "e à vista")
	_igual(_m.tarefas["planta"], "rodando", "a tarefa não recomeçou")

	# Cura pelo viewport e a barra da estação: lê o progresso da peça, com a vista aberta e escondida.
	_curar_pelo_viewport(peca)
	_verdade(peca.ocupada(), "a planta curou e cresce")
	_igual(_m.tarefas["planta"], "rodando", "a planta ainda cresce: a tarefa só acaba quando o crescimento termina")
	peca.avancar(Planta.T_ATRASO_CRESCER + 0.6)
	await _quadros(2)
	_verdade(peca.progresso() > 0.2 and peca.progresso() < 0.95, "a planta está no meio do crescimento (%.2f)" % peca.progresso())
	_verdade(absf(float(_main._estacoes.progresso.get("planta", -1.0)) - peca.progresso()) < 0.1, "a barra da estufa na sala lê a peça")
	_verdade(absf(_t.progresso_da_tarefa("planta") - peca.progresso()) < 0.1, "e a linha da aba tarefas também")
	_verdade(_m.progresso_tarefa("planta") > 0.9, "enquanto o relógio da missão já passou da duração")

	# Concluir: a peça conclui a tarefa e, depois de ~0,5 s, a vista volta sozinha.
	peca.avancar(Planta.T_CRESCER + 0.1)
	_igual(_m.tarefas["planta"], "feita", "a peça conclui a tarefa")
	_igual(_m.tarefa_rodando, "", "nada roda")
	_igual(_v.fase, "aberta", "a vista segue aberta um instante, com a planta pronta")
	await _quadros(3)
	_verdade(_v.peca_da_tarefa("planta") == peca, "a peça pronta fica à vista até a vista voltar")
	var historico: Array = _main._som.historico
	_verdade("estufa_luz" in historico and "estufa_regar" in historico and "estufa_ventilar" in historico, "a peça toca os sons da luz e das ferramentas")
	_verdade("estufa_piorou" in historico, "o erro tocou o som de pior, mesmo com o toque seguinte logo depois")
	_verdade("estufa_ploc" in historico, "o acerto final toca o ploc")
	await _esperar_fase("")
	_igual(_v.fase, "", "a vista voltou sozinha para a sala")
	await _quadros(3)
	_igual(_v.peca_da_tarefa("planta"), null, "e a peça foi liberada")
	_igual(_m.tarefas["planta"], "feita", "a tarefa segue feita")
	_igual(_m.ciencia_do_sol(), 1, "a planta rende ciência")
	_igual(_main._clicavel("estufa"), false, "feita, a estufa não se clica mais")
	_igual(_t._visor.vista_atual(), _t._visor.camera_atual(), "o visor segue na câmera atual")

	# O terminal não hospeda a planta: a linha da aba tarefas não tem botão, e a ação ir_planta não existe.
	await _comecar_turno(3)
	_igual(_m.tarefas["planta"], "pendente", "no sol 3 a planta está pendente")
	_t._acionar("terminal")
	await _esperar_terminal()
	_igual(_t.aba_na_tela(), "tarefas", "o turno abre na aba tarefas")
	await _quadros(2)
	_igual(_t.ui().has("ir_planta"), false, "a linha da planta não tem botão no terminal")
	_igual(_t._acionar("ir_planta"), null, "e a ação ir_planta não existe")
	_igual(_m.tarefas["planta"], "pendente", "ir_planta não inicia nada")
	_t._acionar("terminal")
	await _esperar_terminal()

	# Abrigar com a vista aberta: a peça é liberada e a vista volta sem animação longa.
	_verdade(_main._clicavel("estufa"), "a estufa é clicável")
	_main._ao_clicar("estufa")
	await _esperar_fase("aberta")
	_igual(_v.minigame()["problema"], "mofo", "o sol 3 da fixa: a planta é o mofo")
	var peca2 = _v.peca_da_tarefa("planta")
	_verdade(peca2 != null and peca2 != peca, "uma peça nova para a nova tarefa")
	_igual(peca2.problema(), _m.problema_da_planta(), "o problema da peça é o da missão")
	_tocar("luz")
	_tocar("tesoura")
	_igual(_v.minigame()["mofo"], 0, "a tesoura corta o mofo, pelo viewport")
	_verdade(_m.abrigar(), "abrigar")
	await _quadros(2)
	_igual(_v.fase, "voltando", "a tarefa parou por fora: a vista volta")
	_verdade(_v.minigame() == {}, "sem peça à vista")
	var t_volta := Time.get_ticks_msec()
	await _esperar_fase("")
	_verdade(Time.get_ticks_msec() - t_volta < 400, "e sem animação longa (%d ms)" % (Time.get_ticks_msec() - t_volta))
	await _quadros(3)
	_igual(_v.peca_da_tarefa("planta"), null, "abrigar libera a peça")
	_igual(is_instance_valid(peca2), false, "e a instância some")
	_igual(_m.tarefas["planta"], "pendente", "a tarefa volta a pendente (cancelada)")
	_igual(_v.fase, "", "a vista está fechada")
	_igual(_t.bloqueado, false, "o terminal se desbloqueia")

	# Abrigar com a peça escondida: libera na hora, sem vista nenhuma.
	await _comecar_turno(4)
	_main._ao_clicar("estufa")
	await _esperar_fase("aberta")
	_toque(_centro(_main._estado_da_sonda()["ui"]["voltar"]))
	await _esperar_fase("")
	var peca3 = _v.peca_da_tarefa("planta")
	_verdade(peca3 != null, "escondida, a peça segue")
	_verdade(_m.abrigar(), "abrigar com a peça escondida")
	await _quadros(3)
	_igual(_v.peca_da_tarefa("planta"), null, "abrigar libera a peça escondida")
	_igual(_v.fase, "", "sem vista")

	# Fim do turno com a vista aberta: a peça sai e a vista volta.
	await _comecar_turno(5)
	_main._ao_clicar("estufa")
	await _esperar_fase("aberta")
	var peca4 = _v.peca_da_tarefa("planta")
	_verdade(peca4 != null, "no sol 5 a peça está à vista")
	_m.avancar(_m.turno_s)
	_verdade(_m.fase != "turno", "o turno acabou (%s)" % _m.fase)
	await _quadros(3)
	_verdade(_v.fase in ["voltando", ""], "a vista volta com o fim do turno")
	await _esperar_fase("")
	await _quadros(3)
	_igual(_v.peca_da_tarefa("planta"), null, "o fim do turno libera a peça")
	_igual(_v.visible, false, "a vista está escondida")
	_igual(_main._sala.scale, Vector2.ONE, "e a Sala na escala normal")

	_main.queue_free()
	await process_frame
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)
