extends SceneTree
## Teste headless do minigame do ChemCam (scripts/minigames/chemcam.gd), sem desenhar: os alvos na
## área, o raio de toque, o disparo e a fila, o progresso, o sinal, o fundo e o caminho do _input.
## Roda com: godot --headless --path . --script tests/test_chemcam.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const ChemCam := preload("res://scripts/minigames/chemcam.gd")

const AREAS: Array[Rect2] = [Rect2(0, 0, 640, 360), Rect2(40, 60, 400, 225), Rect2(10, 20, 300, 300)]
const DT := 0.05

## Fica na árvore e conta o que chega à fase "unhandled": o que a peça consome não chega aqui.
class Sonda extends Node:
	var n := 0

	func _unhandled_input(_event: InputEvent) -> void:
		n += 1


var falhas := 0
var total := 0
var _concluidos := 0


func _init() -> void:
	_rodar()


## O root só está "dentro da árvore" depois do primeiro quadro; o caminho do _input (push_input) precisa disso.
func _rodar() -> void:
	await process_frame
	_alvos_e_raio()
	_toque_longe()
	_toque_perto_dispara()
	_fila_e_repeticao()
	_progresso_monotonico_e_sinal()
	_crianca_que_toca_a_cada_segundo()
	_toques_de_uma_vez()
	_fundo()
	_entrada()
	_depois_de_concluir()
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


func _verdade(cond: bool, nome: String) -> void:
	_igual(cond, true, nome)


func _nova(area: Rect2, duracao := 10.0, poeira := false) -> ChemCam:
	var c: ChemCam = ChemCam.new()
	root.add_child(c)
	c.configurar(area, duracao, poeira)
	_concluidos = 0
	c.concluido.connect(func(): _concluidos += 1)
	return c


func _descartar(c: ChemCam) -> void:
	root.remove_child(c)
	c.free()


func _alvos_e_raio() -> void:
	for area in AREAS:
		var rot := "área %s: " % str(area.size)
		var c := _nova(area)
		var alvos := c.alvos_na_area()
		_igual(alvos.size(), 4, rot + "4 alvos")
		_igual(c.position, area.position, rot + "posição")
		_igual(c.size, area.size, rot + "tamanho")
		var r: float = c.raio_toque()
		_verdade(r >= 24.0, rot + "raio >= 24")
		var cabe := Rect2(Vector2.ZERO, area.size).grow(-12.0)
		for i in alvos.size():
			_verdade(cabe.has_point(alvos[i]), rot + "alvo %d dentro da área" % i)
			for j in range(i + 1, alvos.size()):
				_verdade(alvos[i].distance_to(alvos[j]) >= 2.0 * r, rot + "alvos %d e %d sem sobreposição" % [i, j])
		_descartar(c)


func _toque_longe() -> void:
	var c := _nova(AREAS[0])
	var alvos := c.alvos_na_area()
	# O canto inferior esquerdo da área: longe de todo alvo.
	var longe := Vector2(5, 355)
	for a in alvos:
		_verdade(longe.distance_to(a) > c.raio_toque(), "ponto longe de todos os alvos")
	_igual(c.tocar(longe), false, "tocar longe não acerta")
	_igual(c.progresso(), 0.0, "tocar longe: progresso 0")
	c.avancar(1.0)
	_igual(c.progresso(), 0.0, "tocar longe e avançar: progresso 0")
	for i in 4:
		_igual(c.estado_alvo(i), "pendente", "tocar longe: alvo %d pendente" % i)
	_descartar(c)


func _toque_perto_dispara() -> void:
	var c := _nova(AREAS[1])
	var a := c.alvos_na_area()[2]
	_verdade(c.tocar(a + Vector2(20, 0)), "tocar a 20 px acerta")
	_igual(c.estado_alvo(2), "disparando", "acertou: disparando")
	c.avancar(0.75)
	_verdade(c.progresso() > 0.0, "disparando: progresso > 0")
	_verdade(c.progresso() < 0.25, "disparando: progresso < 1/4")
	_descartar(c)


func _fila_e_repeticao() -> void:
	var c := _nova(AREAS[0])
	var a := c.alvos_na_area()
	_verdade(c.tocar(a[0]), "toque 1")
	_verdade(c.tocar(a[1]), "toque 2 durante o disparo acerta")
	_igual(c.estado_alvo(0), "disparando", "primeiro disparando")
	_igual(c.estado_alvo(1), "fila", "segundo na fila")
	_igual(c.tocar(a[1]), false, "tocar de novo o da fila não faz nada")
	_igual(c.tocar(a[0]), false, "tocar de novo o que dispara não faz nada")
	_verdade(c.tocar(a[3]), "toque 3")
	c.avancar(1.5)
	_igual(c.estado_alvo(0), "feito", "primeiro feito")
	_igual(c.estado_alvo(1), "disparando", "a fila segue na ordem do toque")
	_igual(c.estado_alvo(3), "fila", "o terceiro ainda na fila")
	_igual(c.tocar(a[0]), false, "tocar um feito não faz nada")
	_igual(c.estado_alvo(0), "feito", "feito continua feito")
	_igual(c.estado_alvo(2), "pendente", "o não tocado continua pendente")
	_descartar(c)


func _progresso_monotonico_e_sinal() -> void:
	var c := _nova(AREAS[0])
	var a := c.alvos_na_area()
	for i in 4:
		c.tocar(a[i])
	var anterior := 0.0
	var sempre_sobe := true
	var passos := 0
	while _concluidos == 0 and passos < 1000:
		c.avancar(0.01)
		passos += 1
		var p: float = c.progresso()
		if p < anterior:
			sempre_sobe = false
		anterior = p
		if _concluidos == 0 and p >= 1.0:
			_verdade(false, "progresso chegou a 1 antes do sinal")
	_verdade(sempre_sobe, "progresso nunca cai")
	_igual(_concluidos, 1, "concluido saiu")
	_igual(c.progresso(), 1.0, "progresso 1 ao concluir")
	for i in 4:
		_igual(c.estado_alvo(i), "feito", "alvo %d feito ao concluir" % i)
	for i in 100:
		c.avancar(0.1)
	_igual(_concluidos, 1, "concluido saiu uma única vez")
	_descartar(c)


func _crianca_que_toca_a_cada_segundo() -> void:
	var duracao := 10.0
	var c := _nova(AREAS[1], duracao)
	var a := c.alvos_na_area()
	var t := 0.0
	var proximo_toque := 0.0
	var i := 0
	var concluidos_antes_do_ultimo := 0
	while _concluidos == 0 and t < 60.0:
		var ocupado := false
		for k in 4:
			if c.estado_alvo(k) == "disparando" or c.estado_alvo(k) == "fila":
				ocupado = true
		if not ocupado and t >= proximo_toque and i < 4:
			_verdade(c.tocar(a[i]), "criança acerta o alvo %d" % i)
			i += 1
			proximo_toque = t + 1.0
			if i == 4:
				concluidos_antes_do_ultimo = _concluidos
		c.avancar(DT)
		t += DT
	_igual(concluidos_antes_do_ultimo, 0, "sinal só depois do último alvo")
	_igual(_concluidos, 1, "criança conclui")
	_verdade(t <= duracao + 2.0, "criança termina em <= duracao + 2 s (levou %.2f s)" % t)
	_descartar(c)


func _toques_de_uma_vez() -> void:
	var duracao := 10.0
	var c := _nova(AREAS[2], duracao)
	var tiro := clampf(duracao * 0.6 / 4.0, 0.5, 2.0)
	_igual(tiro, 1.5, "tiro de 10 s e 4 alvos")
	var a := c.alvos_na_area()
	for i in 4:
		c.tocar(a[i])
	var t := 0.0
	while _concluidos == 0 and t < 60.0:
		c.avancar(DT)
		t += DT
	_verdade(absf(t - 4.0 * tiro) <= DT + 1e-6, "fila toda termina em ~ n * tiro_s (levou %.2f s)" % t)
	_descartar(c)
	# Duração curta: o tiro sobe até o mínimo de 0,5 s.
	var d := _nova(AREAS[0], 1.0)
	var ad := d.alvos_na_area()
	for i in 4:
		d.tocar(ad[i])
	var t2 := 0.0
	while _concluidos == 0 and t2 < 60.0:
		d.avancar(0.01)
		t2 += 0.01
	_verdade(absf(t2 - 2.0) < 0.02, "duração 1 s: tiro mínimo de 0,5 s (levou %.2f s)" % t2)
	_descartar(d)


func _fundo() -> void:
	var normal := _nova(AREAS[0], 10.0, false)
	var poeira := _nova(AREAS[0], 10.0, true)
	_igual(normal.textura(), load("res://assets/exterior/rocha_normal.png"), "fundo normal")
	_igual(poeira.textura(), load("res://assets/exterior/rocha_poeira.png"), "fundo de poeira")
	_verdade(normal.textura() != poeira.textura(), "as duas texturas são diferentes")
	_descartar(normal)
	_descartar(poeira)


func _clique(pos_viewport: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = pos_viewport
	ev.global_position = pos_viewport
	return ev


func _entrada() -> void:
	var area := AREAS[1]
	var c := _nova(area)
	var a := c.alvos_na_area()
	var sonda := Sonda.new()
	root.add_child(sonda)
	# Acerto: posição do viewport = posição global do alvo.
	var ev := _clique(c.get_global_transform() * a[1])
	_igual(ev.position, area.position + a[1], "posição global do alvo")
	root.push_input(ev, true)
	_igual(c.estado_alvo(1), "disparando", "_input: clique no alvo dispara")
	_igual(sonda.n, 0, "_input: clique no alvo é consumido (não chega ao unhandled)")
	# Dentro da área mas longe de qualquer alvo: não faz nada, mas consome.
	root.push_input(_clique(area.position + Vector2(5, area.size.y - 5)), true)
	_igual(sonda.n, 0, "_input: clique dentro da área, sem acertar, é consumido")
	_igual(c.estado_alvo(0), "pendente", "_input: clique sem acerto não dispara")
	# Fora da área (o canto do viewport, antes do início da área): ignorado e não tratado.
	_verdade(not Rect2(area).has_point(Vector2(10, 10)), "o ponto de teste fica fora da área")
	root.push_input(_clique(Vector2(10, 10)), true)
	_igual(sonda.n, 1, "_input: clique fora da área não é consumido (chega ao unhandled)")
	_igual(c.estado_alvo(0), "pendente", "_input: clique fora da área não dispara")
	# Clique com botão direito dentro da área: não dispara.
	var dir := _clique(area.position + a[0])
	dir.button_index = MOUSE_BUTTON_RIGHT
	root.push_input(dir, true)
	_igual(c.estado_alvo(0), "pendente", "_input: botão direito não dispara")
	# Peça escondida: ignora tudo.
	c.visible = false
	root.push_input(_clique(area.position + a[0]), true)
	_igual(c.estado_alvo(0), "pendente", "_input: escondida, ignora")
	c.visible = true
	# Movimento do mouse move a mira (grudada no centro do alvo mais perto, dentro do raio).
	var mov := InputEventMouseMotion.new()
	mov.position = area.position + a[0] + Vector2(10, 5)
	root.push_input(mov, true)
	_igual(c._mira, a[0] + Vector2(10, 5), "_input: o movimento move a mira")
	root.remove_child(sonda)
	sonda.free()
	_descartar(c)


func _depois_de_concluir() -> void:
	var c := _nova(AREAS[0])
	var a := c.alvos_na_area()
	for i in 4:
		c.tocar(a[i])
	c.avancar(100.0)
	_igual(_concluidos, 1, "avançar muito conclui uma vez")
	_igual(c.tocar(a[0]), false, "depois de concluir, tocar não faz nada")
	_igual(c.progresso(), 1.0, "depois de concluir: progresso 1")
	_descartar(c)
