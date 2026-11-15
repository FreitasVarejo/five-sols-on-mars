extends SceneTree
## Teste headless do ponteiro do tutorial (scripts/ponteiro_tutorial.gd): o pulso (o do primo, abaixo de 3 por
## segundo), a moldura em volta do controle, a seta do card até ele e o ciclo de aparecer e sumir.
## Roda com: godot --headless --path . --script tests/test_ponteiro_tutorial.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Ponteiro := preload("res://scripts/ponteiro_tutorial.gd")
const Mov := preload("res://scripts/movimento_aviso.gd")

var falhas := 0
var total := 0


func _init() -> void:
	_pulso()
	_moldura()
	_seta()
	_ciclo()
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)


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


func _verdade(valor: bool, nome: String) -> void:
	_igual(valor, true, nome)


func _pulso() -> void:
	_igual(Ponteiro.pulso(0.0), 0.5, "pulso: começa no meio")
	var menor := 2.0
	var maior := -1.0
	var cruzamentos := 0  # subidas por 0,5, em 10 s: dá a frequência
	var anterior := Ponteiro.pulso(0.0)
	for i in 10001:
		var p := Ponteiro.pulso(i * 0.001)
		menor = minf(menor, p)
		maior = maxf(maior, p)
		if anterior < 0.5 and p >= 0.5:
			cruzamentos += 1
		anterior = p
	_verdade(menor >= 0.0 and maior <= 1.0, "pulso: fica entre 0 e 1")
	_verdade(maior > 0.99 and menor < 0.01, "pulso: vai de 0 a 1")
	_verdade(cruzamentos / 10.0 < 3.0, "pulso: menos de 3 por segundo (o do primo, ~1 Hz)")
	_verdade(cruzamentos / 10.0 > 0.5, "pulso: e pulsa de fato")
	_igual(Ponteiro.PULSO_RAD_S, 6.0, "pulso: é o sin(t * 6) do primo")


func _moldura() -> void:
	var alvo := Rect2(98, 160, 262, 60)
	var g := Ponteiro.moldura(alvo, 0.0)
	_verdade(g.encloses(alvo), "moldura: cerca o controle")
	var no_vale := Ponteiro.moldura(alvo, 3.0 * PI / 12.0)  # sin(t * 6) = -1: pulso 0
	var no_pico := Ponteiro.moldura(alvo, PI / 12.0)                                # sin(t * 6) = 1: pulso 1
	_igual(no_vale.size.x - alvo.size.x, 2.0 * Ponteiro.MOLDURA_FOLGA, "moldura: no vale, só a folga")
	_igual(no_pico.size.x - alvo.size.x, 2.0 * (Ponteiro.MOLDURA_FOLGA + Ponteiro.MOLDURA_PULSO), "moldura: no pico, a folga e o pulso")
	var k := 0.0
	for i in 200:
		k = maxf(k, Ponteiro.moldura(alvo, i * 0.01).size.x - alvo.size.x)
	_verdade(k <= 2.0 * (Ponteiro.MOLDURA_FOLGA + Ponteiro.MOLDURA_PULSO) + 1e-6, "moldura: cresce no máximo MOLDURA_FOLGA + MOLDURA_PULSO por lado")
	_verdade(k > 2.0 * Ponteiro.MOLDURA_FOLGA, "moldura: de fato cresce com o pulso")


## A seta sai do card, aponta para o controle sem tocá-lo e balança.
func _seta() -> void:
	var alvo := Rect2(90, 160, 262, 60)           # coluna da esquerda
	var card := Rect2(372, 140, 236, 100)         # o card, na direita
	for i in 120:
		var tempo := i * 0.02
		var p: Array = Ponteiro.seta(alvo, card, true, tempo)
		var cabeca: PackedVector2Array = p[0]
		var corpo: PackedVector2Array = p[1]
		var ponta := cabeca[0]
		_verdade(ponta.x > alvo.end.x, "seta (card à direita) t=%.2f: a ponta não encosta no controle" % tempo)
		_verdade(not Ponteiro.moldura(alvo, tempo).has_point(ponta), "seta t=%.2f: a ponta fica fora da moldura" % tempo)
		_verdade(ponta.x < card.position.x + 1.0, "seta t=%.2f: a ponta fica entre o controle e o card" % tempo)
		_verdade(corpo[1].x >= card.position.x, "seta t=%.2f: o corpo entra no card" % tempo)
		_verdade(ponta.y >= card.position.y and ponta.y <= card.end.y, "seta t=%.2f: sai de uma altura do card" % tempo)
	var xs: Array = []
	for i in 60:
		xs.append((Ponteiro.seta(alvo, card, true, i * 0.02)[0] as PackedVector2Array)[0].x)
	_verdade(xs.max() - xs.min() > 1.0, "seta: balança")
	# O card à esquerda do controle (o confirmar): a seta aponta para a direita.
	var alvo2 := Rect2(360, 42, 264, 272)
	var card2 := Rect2(98, 120, 236, 100)
	var q: Array = Ponteiro.seta(alvo2, card2, false, 0.4)
	var ponta2: Vector2 = (q[0] as PackedVector2Array)[0]
	_verdade(ponta2.x < alvo2.position.x, "seta (card à esquerda): a ponta não encosta no controle")
	_verdade(ponta2.x > card2.end.x - 1.0, "seta (card à esquerda): a ponta fica depois do card")


func _ciclo() -> void:
	var p: Control = Ponteiro.new()
	var alvo := Rect2(90, 160, 262, 60)
	var card := Rect2(372, 140, 236, 100)
	_igual(p.mouse_filter, Control.MOUSE_FILTER_STOP, "antes do _ready o filtro é o padrão do Control")
	p._ready()
	_igual(p.mouse_filter, Control.MOUSE_FILTER_IGNORE, "o ponteiro não captura clique")
	_verdade(not p.esta_visivel(), "sem ninguém apontar, não aparece")
	p.apontar(alvo, card, true)
	p.terminar_quadro()
	_igual(p.alvo(), alvo, "o ponteiro guarda o controle apontado")
	_verdade(not p.esta_visivel(), "logo que o card abre, o ponteiro espera a entrada")
	for i in 30:
		p._process(1.0 / 60.0)
		p.apontar(alvo, card, true)
		p.terminar_quadro()
	_verdade(p.esta_visivel(), "depois da entrada, aparece")
	_igual(p.alvo(), alvo, "e aponta o controle do card")
	# O terminal em movimento: não aponta.
	p.apontar(alvo, card, true, false)
	p.terminar_quadro()
	_verdade(not p.esta_visivel(), "com o terminal em movimento, some")
	p.apontar(alvo, card, true)
	p.terminar_quadro()
	_verdade(not p.esta_visivel(), "e volta a esperar a entrada")
	# Um quadro em que ninguém chama: some, e o alvo se zera.
	p.terminar_quadro()
	_igual(p.alvo(), Rect2(), "sem chamada no quadro, o ponteiro some")
	p.free()
