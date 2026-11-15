extends SceneTree
## Teste headless do minigame "Consertar o gerador" (scripts/minigames/consertar_gerador.gd).
## Roda com: godot --headless --path . --script tests/test_consertar_gerador.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Gerador := preload("res://scripts/minigames/consertar_gerador.gd")

var falhas := 0
var total := 0
var _concluidos := 0


func _init() -> void:
	_sorteio()
	_alvos(Rect2(0, 0, 640, 360))
	_alvos(Rect2(0, 0, 320, 180))
	_alvos(Rect2(40, 30, 300, 170))
	_toque_na_errada()
	_arrasto_longe()
	_arrasto_no_encaixe()
	_toque_na_certa()
	_arrasto_da_errada_no_encaixe()
	_reinicio_e_fundo()
	_toque_ignorado_enquanto_anima()
	_progresso_monotono()
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

func _nova(area: Rect2 = Rect2(0, 0, 640, 360), n: int = 0, poeira: bool = false, duracao: float = 20.0) -> Control:
	var g: Control = Gerador.new()
	root.add_child(g)
	g.configurar(area, duracao, poeira)
	g.semente(n)
	_concluidos = 0
	g.concluido.connect(func() -> void: _concluidos += 1)
	return g


func _botao(g: Control, pos: Vector2, pressionado: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressionado
	ev.position = pos
	g._gui_input(ev)


func _mover(g: Control, pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	g._gui_input(ev)


func _tocar(g: Control, i: int) -> void:
	var c: Vector2 = g.alvo_da_peca(i).get_center()
	_botao(g, c, true)
	_botao(g, c, false)


## Pega a peça `i` pelo centro, leva ao ponto `destino` (em três movimentos) e solta.
func _arrastar(g: Control, i: int, destino: Vector2) -> void:
	var c: Vector2 = g.alvo_da_peca(i).get_center()
	_botao(g, c, true)
	for k in [0.3, 0.7, 1.0]:
		_mover(g, c.lerp(destino, k))
	_botao(g, destino, false)


func _andar(g: Control, segundos: float) -> void:
	var passo := 1.0 / 60.0
	var feito := 0.0
	while feito < segundos:
		g.avancar(passo)
		feito += passo


func _liberar(g: Control) -> void:
	root.remove_child(g)
	g.free()


# --- sorteio -------------------------------------------------------------------

func _sorteio() -> void:
	var certas := {}
	var indices := {}
	var encaixes := {}
	for n in 30:
		var a := Gerador.sorteio(n)
		var b := Gerador.sorteio(n)
		_igual(a, b, "sorteio %d determinístico" % n)
		var formas: Array = a["formas"]
		_igual(formas.size(), 3, "sorteio %d: três formas" % n)
		var distintas := {}
		for f in formas:
			distintas[f] = true
			_verdade(Gerador.FORMAS.has(f), "sorteio %d: %s é do pool" % [n, f])
		_igual(distintas.size(), 3, "sorteio %d: formas distintas" % n)
		_verdade(a["certa"] >= 0 and a["certa"] <= 2, "sorteio %d: índice da certa" % n)
		_verdade(a["encaixe"] >= 0 and a["encaixe"] <= 2, "sorteio %d: posição do encaixe" % n)
		certas[formas[a["certa"]]] = true
		indices[a["certa"]] = true
		encaixes[a["encaixe"]] = true
	_verdade(certas.size() > 1, "a forma certa varia")
	_verdade(indices.size() > 1, "o índice da certa varia")
	_verdade(encaixes.size() > 1, "a posição do encaixe varia")
	_igual(Gerador.sorteio(7) == Gerador.sorteio(8), false, "sementes diferentes, sorteios diferentes (7 e 8)")


# --- alvos ---------------------------------------------------------------------

func _alvos(area: Rect2) -> void:
	for n in [0, 1, 2, 3, 4]:
		var g := _nova(area, n)
		var nome := "área %s semente %d" % [str(area.size), n]
		var area_local := Rect2(Vector2.ZERO, area.size)
		for i in 3:
			var r: Rect2 = g.alvo_da_peca(i)
			_verdade(r.size.x >= 24.0 and r.size.y >= 24.0, "%s: alvo %d >= 24x24 (%s)" % [nome, i, str(r.size)])
			_verdade(area_local.encloses(r), "%s: alvo %d dentro da área" % [nome, i])
			for j in range(i + 1, 3):
				_verdade(not r.intersects(g.alvo_da_peca(j)), "%s: alvos %d e %d não se sobrepõem" % [nome, i, j])
		_verdade(area_local.has_point(g.centro_do_encaixe()), "%s: encaixe dentro da área" % nome)
		_igual(g.position, area.position, "%s: position" % nome)
		_igual(g.size, area.size, "%s: size" % nome)
		_liberar(g)


# --- interação -----------------------------------------------------------------

## Índice de uma peça errada (a primeira que não é a certa) e a certa.
func _errada(g: Control) -> int:
	return 0 if g.sorteio_atual()["certa"] != 0 else 1


func _toque_na_errada() -> void:
	var g := _nova()
	var e := _errada(g)
	_tocar(g, e)
	_verdade(g.ocupada(), "toque na errada: animando")
	_andar(g, 1.2)
	_igual(g.progresso(), 0.0, "toque na errada: progresso 0")
	_igual(_concluidos, 0, "toque na errada: não conclui")
	_verdade(g.peca_na_bandeja(e), "toque na errada: voltou à bandeja")
	_verdade(not g.ocupada(), "toque na errada: livre de novo")
	# Voltou inteira em ~1 s (voo 0,25 + sacudida 0,35 + volta 0,3).
	_tocar(g, e)
	_andar(g, 1.0)
	_verdade(g.peca_na_bandeja(e), "toque na errada: de volta em 1 s")
	_liberar(g)


func _arrasto_longe() -> void:
	var g := _nova()
	var certa: int = g.sorteio_atual()["certa"]
	var c: Vector2 = g.alvo_da_peca(certa).get_center()
	var longe := c + Vector2(30, -10)  # ainda na bandeja, longe do encaixe
	_arrastar(g, certa, longe)
	_verdade(g.ocupada(), "arrasto longe: volta animando")
	_andar(g, 0.6)
	_verdade(g.peca_na_bandeja(certa), "arrasto longe: voltou à bandeja")
	_igual(_concluidos, 0, "arrasto longe: não conclui")
	_igual(g.progresso(), 0.0, "arrasto longe: progresso 0")
	_liberar(g)


func _arrasto_no_encaixe() -> void:
	var g := _nova()
	var certa: int = g.sorteio_atual()["certa"]
	var c: Vector2 = g.alvo_da_peca(certa).get_center()
	var ponto := c + Vector2(5, -3)  # pegou a peça fora do centro
	_botao(g, ponto, true)
	_mover(g, ponto + Vector2(0, -40))
	_igual(g.posicao_da_peca(certa), c + Vector2(0, -40), "arrasto: segue o ponteiro mantendo o deslocamento")
	_mover(g, g.centro_do_encaixe() + Vector2(5, -3) + Vector2(10, 8))
	_botao(g, g.centro_do_encaixe() + Vector2(5, -3) + Vector2(10, 8), false)
	_andar(g, 0.3)
	_verdade(g.progresso() > 0.0 and g.progresso() < 1.0, "arrasto no encaixe: progresso em curso")
	_igual(_concluidos, 0, "arrasto no encaixe: ainda não concluiu")
	_andar(g, 3.0)
	_igual(_concluidos, 1, "arrasto no encaixe: concluído uma vez")
	_igual(g.progresso(), 1.0, "arrasto no encaixe: progresso 1")
	_verdade(g.concluida(), "arrasto no encaixe: concluida()")
	for i in 3:
		_tocar(g, i)
	_andar(g, 3.0)
	_igual(_concluidos, 1, "depois de concluir, mais toques não emitem de novo")
	_igual(g.progresso(), 1.0, "depois de concluir, progresso segue 1")
	_liberar(g)


func _toque_na_certa() -> void:
	for n in [0, 1, 2, 3]:
		var g := _nova(Rect2(0, 0, 640, 360), n)
		var certa: int = g.sorteio_atual()["certa"]
		_tocar(g, certa)
		_andar(g, 3.0)
		_igual(_concluidos, 1, "toque na certa (semente %d): conclui" % n)
		_igual(g.progresso(), 1.0, "toque na certa (semente %d): progresso 1" % n)
		_liberar(g)


func _arrasto_da_errada_no_encaixe() -> void:
	var g := _nova()
	var e := _errada(g)
	_arrastar(g, e, g.centro_do_encaixe())
	_andar(g, 0.3)
	_verdade(g.ocupada(), "errada arrastada: animando (sacudida)")
	_andar(g, 1.5)
	_igual(_concluidos, 0, "errada arrastada: não conclui")
	_verdade(g.peca_na_bandeja(e), "errada arrastada: voltou à bandeja")
	# A sacudida desloca só na horizontal, no máximo 4 px.
	var h: Control = _nova()
	var e2 := _errada(h)
	_tocar(h, e2)
	var maior := 0.0
	var fora_do_eixo := 0.0
	_andar(h, 0.27)  # o voo (0,25 s) acabou: daqui até 0,6 s é a sacudida
	for k in 18:
		h.avancar(1.0 / 60.0)
		var d: Vector2 = h.posicao_da_peca(e2) - h.centro_do_encaixe()
		maior = maxf(maior, absf(d.x))
		fora_do_eixo = maxf(fora_do_eixo, absf(d.y))
	_verdade(maior > 0.5 and maior <= 4.0, "sacudida: amplitude até 4 px (%f)" % maior)
	_igual(fora_do_eixo, 0.0, "sacudida: só horizontal")
	_liberar(g)
	_liberar(h)


func _reinicio_e_fundo() -> void:
	var g := _nova()
	_verdade(g.fundo().resource_path.ends_with("moxie_normal.png"), "clima normal: moxie_normal.png")
	_tocar(g, g.sorteio_atual()["certa"])
	_andar(g, 3.0)
	_igual(_concluidos, 1, "reinício: concluiu")
	g.semente(5)
	_igual(g.sorteio_atual(), Gerador.sorteio(5), "semente(5) fixa o sorteio")
	_igual(g.progresso(), 0.0, "semente reinicia: progresso 0")
	_verdade(not g.concluida() and not g.ocupada(), "semente reinicia: livre")
	for i in 3:
		_verdade(g.peca_na_bandeja(i), "semente reinicia: peça %d na bandeja" % i)
	_tocar(g, g.sorteio_atual()["certa"])
	_andar(g, 3.0)
	_igual(_concluidos, 2, "depois de reiniciar, conclui de novo")
	g.configurar(Rect2(10, 20, 400, 225), 20.0, true)
	_verdade(g.fundo().resource_path.ends_with("moxie_poeira.png"), "poeira: moxie_poeira.png")
	_igual(g.fundo().resource_path, "res://assets/exterior/moxie_poeira.png", "poeira: caminho do recurso")
	_igual(g.progresso(), 0.0, "configurar reinicia: progresso 0")
	_verdade(not g.concluida(), "configurar reinicia: não concluída")
	g.configurar(Rect2(0, 0, 640, 360), 20.0, false)
	_igual(g.fundo().resource_path, "res://assets/exterior/moxie_normal.png", "volta ao fundo normal")
	_liberar(g)


func _toque_ignorado_enquanto_anima() -> void:
	var g := _nova()
	var e := _errada(g)
	var certa: int = g.sorteio_atual()["certa"]
	_tocar(g, e)
	_andar(g, 0.1)
	var antes: Vector2 = g.posicao_da_peca(certa)
	_tocar(g, certa)
	_andar(g, 0.1)
	_igual(g.posicao_da_peca(certa), antes, "toque durante a animação: a outra peça não mexe")
	_andar(g, 1.5)
	_igual(_concluidos, 0, "toque durante a animação: não concluiu")
	_verdade(g.peca_na_bandeja(e) and g.peca_na_bandeja(certa), "toque durante a animação: tudo na bandeja")
	_liberar(g)


func _progresso_monotono() -> void:
	var g := _nova(Rect2(0, 0, 640, 360), 0, false, 20.0)
	_tocar(g, g.sorteio_atual()["certa"])
	var anterior := 0.0
	var ok := true
	for k in 300:
		g.avancar(1.0 / 60.0)
		var p: float = g.progresso()
		if p < anterior or p < 0.0 or p > 1.0:
			ok = false
		anterior = p
	_verdade(ok, "progresso sobe sem voltar, entre 0 e 1")
	_igual(g.progresso(), 1.0, "progresso termina em 1")
	_liberar(g)
