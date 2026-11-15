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
	_soltar_nao_perde_o_furo()
	_toque_fora_nao_faz_nada()
	_botoes_grandes()
	_progresso_monotono()
	_tempo_do_adulto()
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


## Segura a broca até encher; devolve o tempo gasto.
func _furar(g: Control) -> float:
	var c: Vector2 = g.alvo_do_passo().get_center()
	_botao(g, c, true)
	var t := 0.0
	while g.passo() == 0 and t < 10.0:
		g.avancar(1.0 / 60.0)
		t += 1.0 / 60.0
	_botao(g, c, false)
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
	var t := _furar(g)
	_verdade(t >= 1.9 and t <= 2.2, rotulo + "a broca leva cerca de 2 s segurando (%.2f)" % t)
	_igual(g.passo(), 1, rotulo + "a broca cheia passa ao tubo")
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


func _soltar_nao_perde_o_furo() -> void:
	var g := _nova()
	var c: Vector2 = g.alvo_do_passo().get_center()
	_botao(g, c, true)
	_passo(g, 1.0)
	_botao(g, c, false)
	var p: float = g.profundidade()
	_verdade(p > 0.45 and p < 0.55, "1 s segurando fura metade (%.2f)" % p)
	_passo(g, 3.0)
	_igual(g.profundidade(), p, "soltado, a broca para e o furo fica")
	_igual(g.passo(), 0, "soltar antes de encher não passa de passo")
	_botao(g, c, true)
	_passo(g, 1.1)
	_botao(g, c, false)
	_igual(g.passo(), 1, "segurar de novo termina o furo")
	g.queue_free()


func _toque_fora_nao_faz_nada() -> void:
	var g := _nova()
	_botao(g, Vector2(2, 2), true)
	_passo(g, 3.0)
	_botao(g, Vector2(2, 2), false)
	_igual(g.profundidade(), 0.0, "segurar fora da baia não fura")
	# Perder o foco ou sumir com o dedo apertado: a broca para.
	var c: Vector2 = g.alvo_do_passo().get_center()
	_botao(g, c, true)
	_verdade(g.segurando(), "segurando")
	g.visible = false
	_verdade(not g.segurando(), "esconder a peça solta a broca")
	g.queue_free()


func _botoes_grandes() -> void:
	for area in [Rect2(0, 0, 640, 360), Rect2(0, 0, 368, 207), Rect2(0, 0, 300, 170)]:
		var g := _nova(area)
		for i in 3:
			var r: Rect2 = g.alvo(i)
			_verdade(r.size.x >= 48.0 and r.size.y >= 48.0, "o botão %d é grande em %s (%s)" % [i, str(area.size), str(r.size)])
			_verdade(Rect2(Vector2.ZERO, g.size).encloses(r), "o botão %d cabe na peça" % i)
		g.queue_free()


func _progresso_monotono() -> void:
	var g := _nova()
	var anterior := 0.0
	var c: Vector2 = g.alvo_do_passo().get_center()
	_botao(g, c, true)
	var t := 0.0
	while g.passo() == 0 and t < 10.0:
		g.avancar(1.0 / 30.0)
		t += 1.0 / 30.0
		_verdade(g.progresso() >= anterior, "o progresso não cai (broca)")
		anterior = g.progresso()
	_botao(g, c, false)
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


## Um adulto toca o mais rápido que dá: a peça inteira cabe nos 10 s da calibração.
func _tempo_do_adulto() -> void:
	var g := _nova()
	var tempo := _furar(g)
	for k in 3:
		_tocar(g)
		_passo(g, 0.25)
		tempo += 0.25
	_tocar(g)
	while not g.concluida() and tempo < 30.0:
		g.avancar(1.0 / 60.0)
		tempo += 1.0 / 60.0
	print("tempo de jogo de um adulto: %.2f s" % tempo)
	_verdade(tempo <= 10.0, "a peça cabe em 10 s (%.2f)" % tempo)
	g.queue_free()


func _reconfigurar_reinicia() -> void:
	var g := _nova()
	_furar(g)
	g.configurar(Rect2(0, 0, 368, 207), 10.0, true)
	_igual(g.passo(), 0, "configurar recomeça no 1º passo")
	_igual(g.profundidade(), 0.0, "configurar zera o furo")
	g.queue_free()
