extends SceneTree
## Teste headless do minigame "Cultivar a planta" (scripts/minigames/cultivar_planta.gd).
## Roda com: godot --headless --path . --script tests/test_cultivar_planta.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Planta := preload("res://scripts/minigames/cultivar_planta.gd")

var falhas := 0
var total := 0
var _concluidos := 0


func _init() -> void:
	_sorteio()
	_partida_fora_da_faixa()
	_os_dois_na_faixa_concluem()
	_um_so_nao_conclui()
	_nao_ha_falha_e_as_pontas_seguram()
	_travada_enquanto_cresce()
	_toque_pelo_ponteiro(Rect2(0, 0, 640, 360))
	_toque_pelo_ponteiro(Rect2(40, 30, 368, 207))
	_botoes_grandes(Rect2(0, 0, 640, 360))
	_botoes_grandes(Rect2(40, 30, 368, 207))
	_botoes_grandes(Rect2(0, 0, 320, 180))
	_reinicio()
	_poucos_toques()
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)


func _igual(obtido, esperado, nome: String) -> void:
	total += 1
	if obtido != esperado:
		falhas += 1
		printerr("FALHOU: %s (obtido %s, esperado %s)" % [nome, str(obtido), str(esperado)])


func _verdade(cond: bool, nome: String) -> void:
	_igual(cond, true, nome)


# --- ajudantes -----------------------------------------------------------------

func _nova(n: int = 0, area: Rect2 = Rect2(0, 0, 368, 207)) -> Control:
	var p: Control = Planta.new()
	root.add_child(p)
	p.configurar(area, 20.0, false)
	p.semente(n)
	_concluidos = 0
	p.concluido.connect(func() -> void: _concluidos += 1)
	return p


func _tempo(p: Control, segundos: float) -> void:
	var feito := 0.0
	while feito < segundos - 0.0001:
		p.avancar(1.0 / 60.0)
		feito += 1.0 / 60.0


## Leva o controle `c` à casa `alvo` com toques (o passo certo a cada vez); para se a planta começa a crescer
## (entrar na faixa por cima ou por baixo já fecha o par).
func _levar(p: Control, c: int, alvo: int) -> void:
	var guarda := 0
	while p.nivel(c) != alvo and not p.ocupada() and guarda < 30:
		guarda += 1
		p.apertar(c, 1 if alvo > p.nivel(c) else -1)
		_tempo(p, 0.2)


func _clicar(p: Control, pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = pos
	p._gui_input(ev)


# --- casos ---------------------------------------------------------------------

func _sorteio() -> void:
	_igual(Planta.sorteio(7), Planta.sorteio(7), "sorteio: mesma semente, mesmo resultado")
	var vistos := {}
	for n in 60:
		var s := Planta.sorteio(n)
		_verdade(s["luz"] in Planta.INICIOS and s["agua"] in Planta.INICIOS, "sorteio %d: parte de uma casa do conjunto" % n)
		_verdade(s["luz"] < Planta.FAIXA_DE or s["luz"] > Planta.FAIXA_ATE, "sorteio %d: a luz parte fora da faixa" % n)
		_verdade(s["agua"] < Planta.FAIXA_DE or s["agua"] > Planta.FAIXA_ATE, "sorteio %d: a água parte fora da faixa" % n)
		vistos["%d-%d" % [s["luz"], s["agua"]]] = true
	_verdade(vistos.size() > 4, "sorteio: as sementes variam o início")
	# Mesma semente, mesmo início na peça.
	var a := _nova(5)
	var b := _nova(5)
	_igual([a.nivel(Planta.LUZ), a.nivel(Planta.AGUA)], [b.nivel(Planta.LUZ), b.nivel(Planta.AGUA)], "mesma semente: mesmo início")
	var s5 := Planta.sorteio(5)
	_igual([a.nivel(Planta.LUZ), a.nivel(Planta.AGUA)], [s5["luz"], s5["agua"]], "o início é o do sorteio")
	a.queue_free()
	b.queue_free()


func _partida_fora_da_faixa() -> void:
	for n in 40:
		var p := _nova(n)
		_verdade(not p.na_faixa(Planta.LUZ), "semente %d: a luz começa fora da faixa" % n)
		_verdade(not p.na_faixa(Planta.AGUA), "semente %d: a água começa fora da faixa" % n)
		_igual(p.progresso(), 0.0, "semente %d: progresso 0 no início" % n)
		_verdade(not p.ocupada(), "semente %d: livre no início" % n)
		p.queue_free()


func _os_dois_na_faixa_concluem() -> void:
	for n in [0, 1, 2, 3, 4]:
		var p := _nova(n)
		_levar(p, Planta.LUZ, Planta.FAIXA_DE)
		_igual(_concluidos, 0, "semente %d: só a luz na faixa, sem sinal" % n)
		_levar(p, Planta.AGUA, Planta.FAIXA_DE)
		_verdade(p.na_faixa(Planta.LUZ) and p.na_faixa(Planta.AGUA), "semente %d: os dois na faixa" % n)
		_igual(_concluidos, 0, "semente %d: o degrau ainda está crescendo" % n)
		_verdade(p.ocupada(), "semente %d: crescendo" % n)
		_tempo(p, Planta.T_CRESCER + 0.2)
		_igual(_concluidos, 1, "semente %d: concluido uma vez" % n)
		_verdade(p.concluida(), "semente %d: concluída" % n)
		_igual(p.progresso(), 1.0, "semente %d: progresso 1" % n)
		_tempo(p, 3.0)
		_igual(_concluidos, 1, "semente %d: o sinal não repete" % n)
		p.queue_free()


func _um_so_nao_conclui() -> void:
	var p := _nova(0)
	_levar(p, Planta.LUZ, 4)
	_tempo(p, 5.0)
	_igual(_concluidos, 0, "só a luz na faixa: não conclui")
	_igual(p.progresso(), 0.0, "só a luz na faixa: progresso 0")
	p.queue_free()
	var q := _nova(0)
	_levar(q, Planta.AGUA, 4)
	_tempo(q, 5.0)
	_igual(_concluidos, 0, "só a água na faixa: não conclui")
	q.queue_free()


func _nao_ha_falha_e_as_pontas_seguram() -> void:
	var p := _nova(0)
	# Passar da faixa e voltar não custa nada nem trava (só a luz: a água fica fora, o par não fecha).
	_levar(p, Planta.LUZ, 5)
	p.apertar(Planta.LUZ, 1)
	p.apertar(Planta.LUZ, 1)
	_verdade(not p.na_faixa(Planta.LUZ), "passou da faixa")
	_verdade(not p.ocupada(), "passar da faixa não trava")
	_levar(p, Planta.LUZ, 4)
	_verdade(p.na_faixa(Planta.LUZ), "voltou à faixa")
	p.apertar(Planta.LUZ, -1)
	p.apertar(Planta.LUZ, -1)
	_igual(p.nivel(Planta.LUZ), 2, "e desceu para o outro lado")
	for i in 12:
		p.apertar(Planta.LUZ, -1)
	_igual(p.nivel(Planta.LUZ), 0, "a ponta de baixo segura")
	# A água, de baixo para cima, sem passar pela faixa por cima.
	p.configurar(Rect2(0, 0, 368, 207), 20.0, false)
	p.semente(0)
	# As pontas do medidor seguram.
	for i in 12:
		p.apertar(Planta.AGUA, 1)
	_igual(p.nivel(Planta.AGUA), Planta.NIVEIS - 1, "a ponta de cima segura")
	_igual(_concluidos, 0, "nada disso conclui")
	p.queue_free()


func _travada_enquanto_cresce() -> void:
	var p := _nova(0)
	_levar(p, Planta.LUZ, 4)
	_levar(p, Planta.AGUA, 4)
	_verdade(p.ocupada(), "crescendo")
	_igual(p.apertar(Planta.LUZ, 1), false, "crescendo: toque ignorado")
	_igual(p.nivel(Planta.LUZ), 4, "crescendo: a luz não mexe")
	_tempo(p, Planta.T_CRESCER / 2.0)
	var meio: float = p.progresso()
	_verdade(meio > 0.3 and meio < 0.95, "crescendo: o progresso anda pelo meio")
	_tempo(p, Planta.T_CRESCER)
	_igual(_concluidos, 1, "terminou uma vez")
	p.queue_free()


func _toque_pelo_ponteiro(area: Rect2) -> void:
	var rot := "área %s: " % str(area.size)
	var n := 0
	while Planta.sorteio(n)["luz"] > 2:
		n += 1
	var p := _nova(n, area)
	var luz0: int = p.nivel(Planta.LUZ)
	var agua0: int = p.nivel(Planta.AGUA)
	_clicar(p, p.retangulo_do_botao(Planta.LUZ, true).get_center())
	_igual(p.nivel(Planta.LUZ), luz0 + 1, rot + "+ da luz sobe uma casa")
	_clicar(p, p.retangulo_do_botao(Planta.LUZ, false).get_center())
	_igual(p.nivel(Planta.LUZ), luz0, rot + "− da luz desce uma casa")
	_clicar(p, p.retangulo_do_botao(Planta.AGUA, false).get_center())
	_igual(p.nivel(Planta.AGUA), agua0 - 1, rot + "− da água desce uma casa")
	_clicar(p, p.retangulo_do_botao(Planta.AGUA, true).get_center())
	_igual(p.nivel(Planta.AGUA), agua0, rot + "+ da água sobe uma casa")
	_clicar(p, Vector2(area.size.x / 2.0, area.size.y / 2.0))
	_igual([p.nivel(Planta.LUZ), p.nivel(Planta.AGUA)], [luz0, agua0], rot + "o meio da cena não mexe em nada")
	# Jogo inteiro pelo ponteiro.
	for c in 2:
		var guarda := 0
		while not p.na_faixa(c) and guarda < 30:
			guarda += 1
			_clicar(p, p.retangulo_do_botao(c, p.nivel(c) < Planta.FAIXA_DE).get_center())
			_tempo(p, 0.2)
	_tempo(p, Planta.T_CRESCER + 0.1)
	_igual(_concluidos, 1, rot + "jogado pelo ponteiro conclui")
	p.queue_free()


func _botoes_grandes(area: Rect2) -> void:
	var rot := "área %s: " % str(area.size)
	var p := _nova(0, area)
	for c in 2:
		for mais in [false, true]:
			var r: Rect2 = p.retangulo_do_botao(c, mais)
			_verdade(r.size.x >= 24.0 and r.size.y >= 24.0, rot + "botão %d/%s tem ao menos 24x24 (%s)" % [c, str(mais), str(r.size)])
			_verdade(Rect2(Vector2.ZERO, area.size).encloses(r), rot + "botão %d/%s cabe na área" % [c, str(mais)])
		_verdade(not p.retangulo_do_botao(c, false).intersects(p.retangulo_do_botao(c, true)), rot + "os dois botões do controle %d não se sobrepõem" % c)
		_verdade(Rect2(Vector2.ZERO, area.size).encloses(p.retangulo_do_medidor(c)), rot + "medidor %d cabe na área" % c)
	p.queue_free()


func _reinicio() -> void:
	var p := _nova(3)
	_levar(p, Planta.LUZ, 4)
	_levar(p, Planta.AGUA, 4)
	_tempo(p, 2.0)
	_igual(_concluidos, 1, "reinício: concluiu")
	p.configurar(Rect2(0, 0, 368, 207), 20.0, false)
	var s := Planta.sorteio(3)
	_igual([p.nivel(Planta.LUZ), p.nivel(Planta.AGUA)], [s["luz"], s["agua"]], "reinício: volta ao início do sorteio")
	_verdade(not p.ocupada(), "reinício: livre")
	_igual(p.progresso(), 0.0, "reinício: progresso 0")
	_levar(p, Planta.LUZ, 4)
	_levar(p, Planta.AGUA, 4)
	_tempo(p, 2.0)
	_igual(_concluidos, 2, "reinício: conclui de novo")
	p.queue_free()


## O pior caso do sorteio pede no máximo 6 toques: com 0,6 s por toque (um adulto devagar) são 3,6 s mais
## o degrau, bem abaixo do teto de 10 s.
func _poucos_toques() -> void:
	var pior := 0
	for n in 200:
		var s := Planta.sorteio(n)
		var toques := 0
		for c in [s["luz"], s["agua"]]:
			toques += (Planta.FAIXA_DE - c) if c < Planta.FAIXA_DE else (c - Planta.FAIXA_ATE)
		pior = maxi(pior, toques)
	_verdade(pior <= 6, "no máximo 6 toques para o pior sorteio (%d)" % pior)
	_verdade(pior * 0.6 + Planta.T_CRESCER <= 10.0, "cabe em 10 s com 0,6 s por toque")
