extends SceneTree
## Teste headless do ponteiro do tutorial ligado ao terminal (scripts/terminal.gd, gancho do ponteiro): com cada
## card do plano do sol 1 que nomeia um controle (oxigênio, ciência, "Confirmar plano"), a seta e a moldura
## aparecem e apontam o retângulo desse controle; nos outros cards e sem card, não. En e pt.
## Roda com: godot --headless --path . --script tests/test_ponteiro_no_terminal.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Terminal := preload("res://scripts/terminal.gd")
const Missao := preload("res://scripts/missao.gd")
const Ponteiro := preload("res://scripts/ponteiro_tutorial.gd")

var falhas := 0
var total := 0


func _init() -> void:
	_tudo()


func _tudo() -> void:
	await _ponteiro_com_cada_card()
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


## Espera `n` quadros e mais o tempo da entrada do card (0,35 s) e do ponteiro.
func _esperar(s: float) -> void:
	var fim := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < fim:
		await process_frame


func _ponteiro_com_cada_card() -> void:
	var idioma := TranslationServer.get_locale()
	var alvos := {"sol1_o2": "o2", "sol1_ciencia": "ciencia", "sol1_confirmar": "confirmar"}
	for loc in ["en", "pt"]:
		TranslationServer.set_locale(loc)
		var m := Missao.new(1)
		var t: Control = Terminal.new()
		t.gravar_textos = true
		t.iniciar(m, {})
		root.add_child(t)
		var p: Control = t._ponteiro
		_verdade(p != null and p.get_parent() == t, "%s: o ponteiro é filho do terminal" % loc)
		await _esperar(0.8)
		_igual(p.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s: o ponteiro não bloqueia o clique" % loc)
		_igual(t.card_id, "aviso", "%s: o aviso abre primeiro" % loc)
		_verdade(not p.esta_visivel(), "%s: o card do aviso, centrado, não aponta nada" % loc)
		t._acionar("fechar_card")
		for id: String in ["sol1_o2", "sol1_ciencia", "sol1_confirmar"]:
			_igual(t.card_id, id, "%s: o card %s abre na ordem" % [loc, id])
			await _esperar(0.9)
			var alvo: Rect2 = t._alvos[alvos[id]]
			_verdade(p.esta_visivel(), "%s: o card %s traz o ponteiro" % [loc, id])
			_igual(p.alvo(), alvo, "%s: o ponteiro do card %s aponta o retângulo do controle %s" % [loc, id, alvos[id]])
			_verdade(p.visible, "%s: o nó do ponteiro está visível" % loc)
			# O que o ponteiro desenha não tapa o "Fechar" do card.
			var fechar := Rect2(t.ui()["fechar_card"][0], t.ui()["fechar_card"][1], t.ui()["fechar_card"][2], t.ui()["fechar_card"][3])
			var g := Ponteiro.moldura(alvo, p.t)
			_verdade(not g.grow(Ponteiro.HALO_FOLGA).intersects(fechar), "%s: a moldura do controle %s não chega ao Fechar" % [loc, alvos[id]])
			t._acionar("fechar_card")
		_igual(t.card_id, "", "%s: a fila acabou" % loc)
		await _esperar(0.2)
		_verdade(not p.esta_visivel(), "%s: sem card, sem ponteiro" % loc)
		_igual(p.alvo(), Rect2(), "%s: e sem alvo" % loc)
		root.remove_child(t)
		t.free()
	TranslationServer.set_locale(idioma)
