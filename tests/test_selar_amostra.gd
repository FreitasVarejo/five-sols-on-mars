extends SceneTree
## Teste headless do minigame "Selar a amostra" (scripts/minigames/selar_amostra.gd).
## Roda com: godot --headless --path . --script tests/test_selar_amostra.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Amostra := preload("res://scripts/minigames/selar_amostra.gd")

var falhas := 0
var total := 0
var _concluidos := 0


func _init() -> void:
	_sem_toque_nao_conclui()
	_tres_passos_concluem(Rect2(0, 0, 640, 360))
	_tres_passos_concluem(Rect2(0, 0, 368, 207))
	_tres_passos_concluem(Rect2(90, 42, 368, 207))
	_ordem_dos_passos()
	_golpe_perfeito_quebra_em_um()
	_golpe_verde_precisa_de_dois()
	_golpe_cinza_precisa_de_quatro()
	_misto_soma_o_dano()
	_toque_no_recuo_nao_conta()
	_agulha_constante_e_deterministica()
	_faixas_da_barra()
	_toque_fora_nao_faz_nada()
	_sumir_reinicia_a_agulha_e_guarda_o_dano()
	_botoes_grandes()
	_barra_cabe()
	_progresso_monotono()
	_tempo_do_adulto()
	_tempo_do_pior_caso()
	_reconfigurar_reinicia()
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

func _nova(area: Rect2 = Rect2(0, 0, 368, 207)) -> Control:
	var g: Control = Amostra.new()
	root.add_child(g)
	g.configurar(area, 10.0, false)
	_concluidos = 0
	g.concluido.connect(func() -> void: _concluidos += 1)
	return g


func _botao(g: Control, pos: Vector2, pressionado: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressionado
	ev.position = pos
	g._gui_input(ev)


func _tocar(g: Control) -> void:
	var c: Vector2 = g.alvo_do_passo().get_center()
	_botao(g, c, true)
	_botao(g, c, false)


## Anda o tempo em quadros de 1/60 s.
func _passo(g: Control, segundos: float) -> void:
	var feito := 0.0
	while feito < segundos - 0.0001:
		g.avancar(1.0 / 60.0)
		feito += 1.0 / 60.0


## Espera a agulha entrar na faixa (e a broca estar pronta) e dá um golpe; devolve o tempo esperado.
func _golpear(g: Control, faixa: int) -> float:
	var t := 0.0
	while t < 10.0 and not (g.pronta() and g.faixa_da_agulha() == faixa):
		g.avancar(1.0 / 60.0)
		t += 1.0 / 60.0
	_tocar(g)
	return t


## Fura com golpes da faixa dada até passar ao tubo; devolve o tempo gasto (esperas e recuos incluídos).
func _furar(g: Control, faixa: int = Amostra.Faixa.PERFEITA) -> float:
	var t := 0.0
	while g.passo() == 0 and t < 30.0:
		t += _golpear(g, faixa)
	return t


# --- casos ---------------------------------------------------------------------

func _sem_toque_nao_conclui() -> void:
	var g := _nova()
	_passo(g, 60.0)
	_igual(g.passo(), 0, "sem toque, segue no 1º passo")
	_igual(g.progresso(), 0.0, "sem toque, o progresso é 0")
	_igual(_concluidos, 0, "sem toque, não conclui")
	_verdade(not g.concluida(), "sem toque, não está concluída")
	g.queue_free()


func _tres_passos_concluem(area: Rect2) -> void:
	var rotulo := "área %s: " % str(area.size)
	var g := _nova(area)
	_furar(g)
	_igual(g.passo(), 1, rotulo + "a rocha quebrada passa ao tubo")
	_igual(g.profundidade(), 1.0, rotulo + "a barra está cheia")
	for k in 3:
		_igual(g.graus(), k, rotulo + "degrau %d antes do toque" % k)
		_tocar(g)
	_igual(g.graus(), 3, rotulo + "o tubo tem 3 degraus")
	_igual(g.passo(), 2, rotulo + "o tubo cheio passa à tampa")
	_igual(_concluidos, 0, rotulo + "ainda não concluiu antes de selar")
	_tocar(g)
	_igual(g.passo(), 3, rotulo + "tocar a tampa começa a selar")
	_igual(_concluidos, 0, rotulo + "selando ainda não conclui")
	_passo(g, 0.5)
	_igual(_concluidos, 0, rotulo + "o selo ainda está à vista")
	_passo(g, 2.0)
	_igual(_concluidos, 1, rotulo + "o 3º passo conclui, uma vez")
	_verdade(g.concluida(), rotulo + "concluída")
	_igual(g.progresso(), 1.0, rotulo + "progresso 1")
	_passo(g, 5.0)
	_igual(_concluidos, 1, rotulo + "não emite de novo")
	g.queue_free()


func _ordem_dos_passos() -> void:
	var g := _nova()
	# Tocar o tubo e a tampa antes da broca não adianta.
	for i in [1, 2]:
		var c: Vector2 = g.alvo(i).get_center()
		_botao(g, c, true)
		_botao(g, c, false)
	_igual(g.graus(), 0, "o tubo não recebe pó antes da broca")
	_igual(g.passo(), 0, "tampa e tubo antes da broca não mudam o passo")
	_furar(g)
	# Na tampa antes do tubo cheio: nada.
	var c2: Vector2 = g.alvo(2).get_center()
	_botao(g, c2, true)
	_botao(g, c2, false)
	_igual(g.passo(), 1, "a tampa antes do tubo cheio não vale")
	# Quatro toques no tubo: o quarto cai na baia que já não vale e nada acontece.
	var c1: Vector2 = g.alvo(1).get_center()
	for k in 4:
		_botao(g, c1, true)
		_botao(g, c1, false)
	_igual(g.graus(), 3, "o tubo não passa de 3 degraus")
	_igual(g.passo(), 2, "o quarto toque no tubo não sela a tampa")
	g.queue_free()


func _golpe_perfeito_quebra_em_um() -> void:
	var g := _nova()
	_golpear(g, Amostra.Faixa.PERFEITA)
	_igual(g.profundidade(), 1.0, "o perfeito dá 100% do dano")
	_igual(g.passo(), 1, "o perfeito quebra a rocha num golpe só")
	g.queue_free()


func _golpe_verde_precisa_de_dois() -> void:
	var g := _nova()
	_golpear(g, Amostra.Faixa.VERDE)
	_igual(g.profundidade(), 0.5, "o verde dá 50%")
	_igual(g.passo(), 0, "um golpe verde não basta")
	_golpear(g, Amostra.Faixa.VERDE)
	_igual(g.profundidade(), 1.0, "dois verdes enchem")
	_igual(g.passo(), 1, "dois golpes verdes quebram a rocha")
	g.queue_free()


func _golpe_cinza_precisa_de_quatro() -> void:
	var g := _nova()
	for k in 3:
		_golpear(g, Amostra.Faixa.CINZA)
		_igual(g.profundidade(), 0.25 * (k + 1), "o cinza dá 25%% (golpe %d)" % (k + 1))
		_igual(g.passo(), 0, "ainda no 1º passo após %d golpes cinza" % (k + 1))
	_golpear(g, Amostra.Faixa.CINZA)
	_igual(g.passo(), 1, "quatro golpes cinza quebram a rocha")
	_igual(g.profundidade(), 1.0, "e a barra enche")
	g.queue_free()


func _misto_soma_o_dano() -> void:
	var g := _nova()
	_golpear(g, Amostra.Faixa.CINZA)
	_golpear(g, Amostra.Faixa.VERDE)
	_igual(g.profundidade(), 0.75, "cinza mais verde soma 75%")
	_golpear(g, Amostra.Faixa.PERFEITA)
	_igual(g.profundidade(), 1.0, "o dano não passa de 100%")
	_igual(g.passo(), 1, "o perfeito termina o que faltava")
	g.queue_free()


func _toque_no_recuo_nao_conta() -> void:
	var g := _nova()
	_golpear(g, Amostra.Faixa.CINZA)
	_verdade(not g.pronta(), "logo após o golpe, a broca não está pronta")
	var a0: float = g.agulha()
	_tocar(g)
	_tocar(g)
	_igual(g.profundidade(), 0.25, "toque durante o recuo é ignorado")
	_passo(g, Amostra.T_GOLPE * 0.5)
	_tocar(g)
	_igual(g.profundidade(), 0.25, "ainda no recuo, a meio caminho")
	_verdade(g.agulha() != a0, "a agulha segue andando durante o recuo")
	_passo(g, Amostra.T_GOLPE)
	_verdade(g.pronta(), "passado o recuo, a broca está pronta")
	_golpear(g, Amostra.Faixa.CINZA)
	_igual(g.profundidade(), 0.5, "depois do recuo o toque vale")
	g.queue_free()


func _agulha_constante_e_deterministica() -> void:
	var a := _nova()
	var b := _nova()
	_igual(a.agulha(), 0.0, "a agulha parte da ponta esquerda")
	var passos := [0.016, 0.1, 0.5, 0.033, 0.2, 1.7, 0.01]
	for d in passos:
		a.avancar(d)
		b.avancar(d)
		_igual(a.agulha(), b.agulha(), "mesma sequência de avancar, mesma agulha (%.3f)" % d)
	a.queue_free()
	b.queue_free()
	# Velocidade constante: uma travessia em T_TRAVESSIA, ida e volta, sem acelerar.
	var g := _nova()
	_passo(g, Amostra.T_TRAVESSIA * 0.5)
	_verdade(absf(g.agulha() - 0.5) < 0.02, "meia travessia, meio da barra (%.3f)" % g.agulha())
	_passo(g, Amostra.T_TRAVESSIA * 0.5)
	_verdade(absf(g.agulha() - 1.0) < 0.02, "uma travessia chega na ponta direita (%.3f)" % g.agulha())
	_passo(g, Amostra.T_TRAVESSIA)
	_verdade(absf(g.agulha() - 0.0) < 0.02, "e volta à esquerda em outra travessia (%.3f)" % g.agulha())
	g.queue_free()
	var h := _nova()
	var passo_ref := -1.0
	var ok := true
	var antes: float = h.agulha()
	for k in 600:
		h.avancar(1.0 / 60.0)
		var dx := absf(h.agulha() - antes)
		antes = h.agulha()
		if passo_ref < 0.0:
			passo_ref = dx
		if absf(dx - passo_ref) > 0.0005:
			# Só pode diferir na virada da ponta (um quadro).
			ok = ok and (h.agulha() < 0.03 or h.agulha() > 0.97)
	_verdade(ok, "a velocidade não muda ao longo do tempo")
	h.queue_free()
	# Tocar não acelera a agulha (ao contrário do reciclador): com e sem golpes, a posição é função só do tempo.
	var c := _nova()
	var d := _nova()
	_golpear(c, Amostra.Faixa.CINZA)
	d.avancar(c._t_agulha)
	_igual(c.agulha(), d.agulha(), "golpear não muda a velocidade da agulha")
	c.queue_free()
	d.queue_free()


## Percorre a barra e confere a proporção de cada faixa: perfeito 10%, verde 20% ao redor, cinza 70%.
func _faixas_da_barra() -> void:
	var g := _nova()
	var cont := [0, 0, 0]
	var n := 24000
	for k in n:
		g.avancar(Amostra.T_TRAVESSIA * 2.0 / n)
		cont[g.faixa_da_agulha()] += 1
	var perfeito: float = float(cont[0]) / n
	var verde: float = float(cont[1]) / n
	var cinza: float = float(cont[2]) / n
	_verdade(absf(perfeito - 2.0 * Amostra.ZONA_PERFEITA) < 0.01, "o perfeito é cerca de 10%% da barra (%.3f)" % perfeito)
	_verdade(absf(verde - 2.0 * (Amostra.ZONA_VERDE - Amostra.ZONA_PERFEITA)) < 0.01, "o verde é cerca de 20%% além do perfeito (%.3f)" % verde)
	_verdade(absf(cinza - (1.0 - 2.0 * Amostra.ZONA_VERDE)) < 0.01, "o resto é cinza (%.3f)" % cinza)
	g.queue_free()


func _toque_fora_nao_faz_nada() -> void:
	var g := _nova()
	_passo(g, 1.0)
	_botao(g, Vector2(2, 2), true)
	_botao(g, Vector2(2, 2), false)
	_igual(g.profundidade(), 0.0, "tocar fora da baia não fura")
	_verdade(g.pronta(), "e não gasta o recuo")
	# Tocar a baia do tubo ou da tampa antes da hora também não vale.
	for i in [1, 2]:
		var c: Vector2 = g.alvo(i).get_center()
		_botao(g, c, true)
		_botao(g, c, false)
	_igual(g.profundidade(), 0.0, "tocar outra baia não fura")
	g.queue_free()


func _sumir_reinicia_a_agulha_e_guarda_o_dano() -> void:
	var g := _nova()
	_golpear(g, Amostra.Faixa.CINZA)
	_passo(g, 0.2)
	_verdade(not g.pronta() and g.agulha() > 0.0, "em recuo, com a agulha andada")
	g.visible = false
	_igual(g.agulha(), 0.0, "esconder a peça leva a agulha de volta à ponta")
	_verdade(g.pronta(), "e acaba o recuo")
	_igual(g.profundidade(), 0.25, "o que já rachou fica")
	g.visible = true
	_golpear(g, Amostra.Faixa.VERDE)
	_igual(g.profundidade(), 0.75, "e dá para seguir golpeando")
	g.queue_free()


func _botoes_grandes() -> void:
	for area in [Rect2(0, 0, 640, 360), Rect2(0, 0, 368, 207), Rect2(0, 0, 300, 170)]:
		var g := _nova(area)
		for i in 3:
			var r: Rect2 = g.alvo(i)
			_verdade(r.size.x >= 48.0 and r.size.y >= 48.0, "o botão %d é grande em %s (%s)" % [i, str(area.size), str(r.size)])
			_verdade(Rect2(Vector2.ZERO, g.size).encloses(r), "o botão %d cabe na peça" % i)
		g.queue_free()


func _barra_cabe() -> void:
	for area in [Rect2(0, 0, 640, 360), Rect2(0, 0, 368, 207), Rect2(0, 0, 300, 170)]:
		var g := _nova(area)
		var b: Rect2 = g.retangulo_da_barra()
		var baia: Rect2 = g.alvo(0)
		_verdade(baia.encloses(b), "a barra cabe na baia da broca em %s" % str(area.size))
		_verdade(b.size.x >= 60.0, "e é larga o bastante para a faixa perfeita ter 5 px (%.1f px)" % b.size.x)
		_verdade(b.size.x * 2.0 * Amostra.ZONA_PERFEITA >= 5.0, "a faixa perfeita tem ao menos 5 px em %s" % str(area.size))
		g.queue_free()


func _progresso_monotono() -> void:
	var g := _nova()
	var anterior := 0.0
	var t := 0.0
	while g.passo() == 0 and t < 30.0:
		g.avancar(1.0 / 30.0)
		t += 1.0 / 30.0
		if g.pronta() and g.faixa_da_agulha() == Amostra.Faixa.CINZA:
			_tocar(g)
		_verdade(g.progresso() >= anterior, "o progresso não cai (broca)")
		_verdade(g.progresso() <= 1.0 / 3.0 + 0.0001, "a broca vale no máximo um terço")
		anterior = g.progresso()
	_igual(g.passo(), 1, "quatro golpes cinza passam ao tubo")
	for k in 3:
		_tocar(g)
		_passo(g, 0.1)
		_verdade(g.progresso() >= anterior, "o progresso não cai (tubo)")
		anterior = g.progresso()
	_tocar(g)
	while not g.concluida() and t < 30.0:
		g.avancar(1.0 / 30.0)
		t += 1.0 / 30.0
		_verdade(g.progresso() >= anterior, "o progresso não cai (selo)")
		_verdade(g.concluida() or g.progresso() < 1.0, "só chega a 1 quando conclui")
		anterior = g.progresso()
	_igual(g.progresso(), 1.0, "termina em 1")
	g.queue_free()


## Um adulto mira o centro: a peça inteira leva menos de 6 s.
func _tempo_do_adulto() -> void:
	var g := _nova()
	var tempo := _furar(g, Amostra.Faixa.PERFEITA)
	for k in 3:
		_tocar(g)
		_passo(g, 0.25)
		tempo += 0.25
	_tocar(g)
	while not g.concluida() and tempo < 30.0:
		g.avancar(1.0 / 60.0)
		tempo += 1.0 / 60.0
	print("tempo de jogo de um adulto: %.2f s" % tempo)
	_verdade(tempo < 6.0, "a peça leva menos de 6 s para o adulto (%.2f)" % tempo)
	g.queue_free()


## O pior caso: sempre cinza, logo que o recuo acaba, e 0,25 s entre os toques do tubo. Cabe nos 10 s.
func _tempo_do_pior_caso() -> void:
	var g := _nova()
	var tempo := _furar(g, Amostra.Faixa.CINZA)
	_igual(g.profundidade(), 1.0, "o pior caso precisa dos 4 golpes")
	for k in 3:
		_tocar(g)
		_passo(g, 0.25)
		tempo += 0.25
	_tocar(g)
	while not g.concluida() and tempo < 30.0:
		g.avancar(1.0 / 60.0)
		tempo += 1.0 / 60.0
	print("tempo do pior caso: %.2f s" % tempo)
	_verdade(tempo < 10.0, "a peça inteira leva menos de 10 s no pior caso (%.2f)" % tempo)
	g.queue_free()


func _reconfigurar_reinicia() -> void:
	var g := _nova()
	_golpear(g, Amostra.Faixa.CINZA)
	_passo(g, 0.3)
	g.configurar(Rect2(0, 0, 368, 207), 10.0, true)
	_igual(g.passo(), 0, "configurar recomeça no 1º passo")
	_igual(g.profundidade(), 0.0, "configurar zera o dano")
	_igual(g.agulha(), 0.0, "e a agulha")
	_verdade(g.pronta(), "e o recuo")
	g.queue_free()
