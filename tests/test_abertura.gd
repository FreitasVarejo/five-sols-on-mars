extends SceneTree
## Teste headless da abertura (scripts/abertura/abertura.gd): os oito quadros, os dois botões e a guarda
## de "emitido uma vez", a roda, o arrasto do mouse e do dedo (sem contar duas vezes o toque que chega
## também como mouse emulado), os limites da rolagem, as bolinhas, a divisão em frases e o texto cabendo
## na largura nos dois idiomas.
## Roda com: godot --headless --path . --script tests/test_abertura.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Abertura := preload("res://scripts/abertura/abertura.gd")
const Cena := preload("res://tests/cena_abertura.gd")

var falhas := 0
var total := 0
var emitidos := 0


class SomFalso:
	extends RefCounted
	var tocados: Array = []

	func tocar(nome: String) -> void:
		tocados.append(nome)


func _init() -> void:
	Cena.registrar_textos()
	TranslationServer.set_locale("en")
	_quadros()
	_botao_final_emite_uma_vez()
	_pular_emite_uma_vez()
	_pular_depois_de_comecar()
	_toque_fora_do_ultimo_quadro()
	_som()
	_roda()
	_arrasto_do_mouse()
	_arrasto_do_dedo()
	_toque_nao_conta_duas_vezes()
	_toque_sem_arrasto_nao_rola()
	_limites()
	_alvos_de_toque()
	_bolinhas()
	_frases()
	_texto_cabe()
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)


func _igual(obtido, esperado, nome: String) -> void:
	total += 1
	var bate := false
	if (obtido is float or obtido is int) and (esperado is float or esperado is int):
		bate = absf(float(obtido) - float(esperado)) < 1e-4
	else:
		bate = obtido == esperado
	if not bate:
		falhas += 1
		printerr("FALHOU: %s (obtido %s, esperado %s)" % [nome, str(obtido), str(esperado)])


func _verdade(cond: bool, nome: String) -> void:
	_igual(cond, true, nome)


func _contar() -> void:
	emitidos += 1


## Uma abertura de 640x360 que conta as emissões de `concluida`.
func _nova() -> Abertura:
	var a := Abertura.new()
	a.size = Vector2(640, 360)
	emitidos = 0
	a.concluida.connect(_contar)
	return a


func _mouse(a: Abertura, pos: Vector2, apertado: bool, botao: int = MOUSE_BUTTON_LEFT, emulado: bool = false) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = botao
	e.pressed = apertado
	e.position = pos
	if emulado:
		e.device = InputEvent.DEVICE_ID_EMULATION
	a._gui_input(e)


func _mouse_move(a: Abertura, pos: Vector2, emulado: bool = false) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	if emulado:
		e.device = InputEvent.DEVICE_ID_EMULATION
	a._gui_input(e)


func _toque(a: Abertura, pos: Vector2, apertado: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = apertado
	e.position = pos
	a._gui_input(e)


func _arrasta_dedo(a: Abertura, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = pos
	a._gui_input(e)


func _clique(a: Abertura, pos: Vector2) -> void:
	_mouse(a, pos, true)
	_mouse(a, pos, false)


func _roda_para(a: Abertura, baixo: bool) -> void:
	_mouse(a, Vector2(300, 200), true, MOUSE_BUTTON_WHEEL_DOWN if baixo else MOUSE_BUTTON_WHEEL_UP)
	_mouse(a, Vector2(300, 200), false, MOUSE_BUTTON_WHEEL_DOWN if baixo else MOUSE_BUTTON_WHEEL_UP)


## Vai ao quadro `q` e deixa o encaixe terminar.
func _vai(a: Abertura, q: int) -> void:
	a.ir_para(q)
	a.avancar(1.0)


func _quadros() -> void:
	_igual(Abertura.N_QUADROS, 8, "há 8 quadros")
	_igual(Abertura.CHAVES_DOS_QUADROS.size(), 8, "uma lista de chaves por quadro")
	_igual(Abertura.CHAVES_DOS_QUADROS[0], ["ABERTURA_1_TITULO", "ABERTURA_1_A", "ABERTURA_1_B", "ABERTURA_ROLAR"], "chaves do 1")
	_igual(Abertura.CHAVES_DOS_QUADROS[4].size(), 5, "o quadro da radiação tem rótulo e 4 frases")
	_igual(Abertura.CHAVES_DOS_QUADROS[7][2], "ABERTURA_FIM_BOTAO", "o último quadro leva o botão")
	var a := _nova()
	_igual(a.quadro_atual(), 0, "começa no quadro 1")
	_vai(a, 7)
	_igual(a.quadro_atual(), 7, "chega ao quadro 8")
	_igual(a.rolagem(), 7.0 * 360.0, "rolagem do quadro 8")
	a.free()
	# Com outra altura, a rolagem acompanha o quadro de repouso .
	var b := _nova()
	_vai(b, 3)
	b.size = Vector2(640, 300)
	_igual(b.rolagem(), 3.0 * 300.0, "com outra altura a rolagem acompanha")
	b.free()


func _botao_final_emite_uma_vez() -> void:
	var a := _nova()
	_vai(a, 7)
	var c := a.rect_botao_final().get_center()
	_clique(a, c)
	_clique(a, c)
	_igual(emitidos, 1, "botão final: dois cliques emitem uma vez")
	_verdade(a.ja_concluiu(), "botão final: ja_concluiu")
	# Com um dedo também.
	var b := _nova()
	_vai(b, 7)
	_toque(b, b.rect_botao_final().get_center(), true)
	_toque(b, b.rect_botao_final().get_center(), false)
	_igual(emitidos, 1, "botão final com o dedo")
	a.free()
	b.free()


func _pular_emite_uma_vez() -> void:
	var a := _nova()
	var c := a.rect_pular().get_center()
	_clique(a, c)
	_clique(a, c)
	_igual(emitidos, 1, "Pular: dois cliques emitem uma vez")
	a.free()
	# Em qualquer quadro.
	for q in 8:
		var b := _nova()
		_vai(b, q)
		_clique(b, b.rect_pular().get_center())
		_igual(emitidos, 1, "Pular visível no quadro %d" % (q + 1))
		b.free()


func _pular_depois_de_comecar() -> void:
	var a := _nova()
	_vai(a, 7)
	_clique(a, a.rect_botao_final().get_center())
	_clique(a, a.rect_pular().get_center())
	_igual(emitidos, 1, "Pular depois de Começar não emite de novo")
	var b := _nova()
	_clique(b, b.rect_pular().get_center())
	_vai(b, 7)
	_clique(b, b.rect_botao_final().get_center())
	_igual(emitidos, 1, "Começar depois de Pular não emite de novo")
	a.free()
	b.free()


func _toque_fora_do_ultimo_quadro() -> void:
	var ref := _nova()
	_vai(ref, 7)
	var onde := ref.rect_botao_final().get_center()
	ref.free()
	for q in 7:
		var a := _nova()
		_vai(a, q)
		_clique(a, onde)
		_toque(a, onde, true)
		_toque(a, onde, false)
		_igual(emitidos, 0, "toque no lugar do botão final no quadro %d não emite" % (q + 1))
		_verdade(not Rect2(Vector2.ZERO, a.size).encloses(a.rect_botao_final()), "botão fora da tela no quadro %d" % (q + 1))
		a.free()


func _som() -> void:
	var a := _nova()
	var s := SomFalso.new()
	a.som = s
	_vai(a, 7)
	_clique(a, a.rect_botao_final().get_center())
	_clique(a, a.rect_botao_final().get_center())
	_clique(a, a.rect_pular().get_center())
	_igual(s.tocados, ["clique_confirmar"], "o clique soa uma vez, no que emite")
	var b := _nova()
	var s2 := SomFalso.new()
	b.som = s2
	_clique(b, b.rect_pular().get_center())
	_igual(s2.tocados, ["clique_confirmar"], "Pular também soa")
	# Sem som injetado: funciona.
	var c := _nova()
	_clique(c, c.rect_pular().get_center())
	_igual(emitidos, 1, "sem som injetado")
	a.free()
	b.free()
	c.free()


func _roda() -> void:
	var a := _nova()
	_roda_para(a, true)
	a.avancar(1.0)
	_igual(a.quadro_atual(), 1, "roda para baixo vai ao quadro 2")
	_roda_para(a, false)
	a.avancar(1.0)
	_igual(a.quadro_atual(), 0, "roda para cima volta ao quadro 1")
	_roda_para(a, false)
	a.avancar(1.0)
	_igual(a.quadro_atual(), 0, "roda para cima no primeiro não passa")
	_igual(a.rolagem(), 0.0, "rolagem 0 no primeiro")
	# Uma rajada sem tempo entre os passos conta um passo só.
	_roda_para(a, true)
	_roda_para(a, true)
	_roda_para(a, true)
	a.avancar(1.0)
	_igual(a.quadro_atual(), 1, "rajada da roda é um passo")
	for i in 20:
		_roda_para(a, true)
		a.avancar(1.0)
	_igual(a.quadro_atual(), 7, "roda para baixo para no último")
	_igual(a.rolagem(), 7.0 * 360.0, "rolagem no limite do último")
	# O encaixe é uma interpolação: no meio do caminho a rolagem está entre os dois quadros.
	var b := _nova()
	_roda_para(b, true)
	b.avancar(0.1)
	_verdade(b.rolagem() > 0.0 and b.rolagem() < 360.0, "no meio do encaixe")
	b.avancar(1.0)
	_igual(b.rolagem(), 360.0, "o encaixe termina no quadro")
	a.free()
	b.free()


func _arrasta_mouse(a: Abertura, de: Vector2, para: Vector2) -> void:
	_mouse(a, de, true)
	_mouse_move(a, de.lerp(para, 0.5))
	_mouse_move(a, para)
	_mouse(a, para, false)
	a.avancar(1.0)


func _arrasto_do_mouse() -> void:
	var a := _nova()
	_arrasta_mouse(a, Vector2(300, 300), Vector2(300, 100))
	_igual(a.quadro_atual(), 1, "arrastar para cima avança um quadro")
	_igual(a.rolagem(), 360.0, "e encaixa nele")
	_arrasta_mouse(a, Vector2(300, 100), Vector2(300, 300))
	_igual(a.quadro_atual(), 0, "arrastar para baixo volta")
	_arrasta_mouse(a, Vector2(300, 100), Vector2(300, 300))
	_igual(a.quadro_atual(), 0, "arrastar para baixo no primeiro não passa")
	_igual(a.rolagem(), 0.0, "rolagem no 0 no primeiro")
	# Segue o dedo durante o arrasto: sobe 100 px, a rolagem é 100 px.
	_mouse(a, Vector2(300, 300), true)
	_mouse_move(a, Vector2(300, 295))   # ainda dentro do limiar
	_igual(a.rolagem(), 0.0, "movimento pequeno não rola")
	_mouse_move(a, Vector2(300, 200))
	_mouse_move(a, Vector2(300, 100))
	_verdade(a.rolagem() > 150.0 and a.rolagem() < 250.0, "a rolagem segue o mouse")
	_mouse(a, Vector2(300, 100), false)
	a.avancar(1.0)
	_igual(a.quadro_atual(), 1, "solto depois de 200 px")
	# Gesto curto e devagar volta ao quadro de onde saiu (arrasto de 12 px só passa o limiar).
	var b := _nova()
	_mouse(b, Vector2(300, 300), true)
	_mouse_move(b, Vector2(300, 288))
	_mouse(b, Vector2(300, 288), false)
	b.avancar(1.0)
	_igual(b.quadro_atual(), 0, "arrasto mínimo e curto volta ao quadro")
	# Os limites: arrastar para cima no último não passa dele.
	_vai(b, 7)
	_arrasta_mouse(b, Vector2(300, 300), Vector2(300, 10))
	_igual(b.quadro_atual(), 7, "arrastar para cima no último não passa")
	_igual(b.rolagem(), 7.0 * 360.0, "rolagem no limite do último")
	# Durante o arrasto a rolagem nunca sai de 0 a 7 quadros.
	var c := _nova()
	_mouse(c, Vector2(300, 100), true)
	_mouse_move(c, Vector2(300, 250))
	_mouse_move(c, Vector2(300, 350))
	_igual(c.rolagem(), 0.0, "arrastando para baixo no primeiro a rolagem fica em 0")
	_mouse(c, Vector2(300, 350), false)
	a.free()
	b.free()
	c.free()


func _arrasto_do_dedo() -> void:
	var a := _nova()
	_toque(a, Vector2(300, 300), true)
	_arrasta_dedo(a, Vector2(300, 200))
	_arrasta_dedo(a, Vector2(300, 100))
	_verdade(a.rolagem() > 150.0, "a rolagem segue o dedo")
	_toque(a, Vector2(300, 100), false)
	a.avancar(1.0)
	_igual(a.quadro_atual(), 1, "arrasto do dedo para cima avança")
	_toque(a, Vector2(300, 100), true)
	_arrasta_dedo(a, Vector2(300, 220))
	_arrasta_dedo(a, Vector2(300, 300))
	_toque(a, Vector2(300, 300), false)
	a.avancar(1.0)
	_igual(a.quadro_atual(), 0, "arrasto do dedo para baixo volta")
	_toque(a, Vector2(300, 100), true)
	_arrasta_dedo(a, Vector2(300, 300))
	_toque(a, Vector2(300, 300), false)
	a.avancar(1.0)
	_igual(a.quadro_atual(), 0, "o dedo para baixo no primeiro não passa")
	_igual(a.rolagem(), 0.0, "rolagem 0")
	# Outro dedo (índice 1) não mexe.
	var e := InputEventScreenDrag.new()
	e.index = 1
	e.position = Vector2(300, 50)
	a._gui_input(e)
	_igual(a.rolagem(), 0.0, "só o primeiro dedo vale")
	a.free()


## No Web o toque vem como ScreenTouch/ScreenDrag e também como mouse emulado: um arrasto avança um
## quadro, não dois, em qualquer ordem de chegada.
func _toque_nao_conta_duas_vezes() -> void:
	var a := _nova()
	_toque(a, Vector2(300, 300), true)
	_mouse(a, Vector2(300, 300), true, MOUSE_BUTTON_LEFT, true)
	_arrasta_dedo(a, Vector2(300, 200))
	_mouse_move(a, Vector2(300, 200), true)
	_arrasta_dedo(a, Vector2(300, 100))
	_mouse_move(a, Vector2(300, 100), true)
	_verdade(a.rolagem() < 250.0, "durante o arrasto o toque e o mouse emulado contam uma vez")
	_toque(a, Vector2(300, 100), false)
	_mouse(a, Vector2(300, 100), false, MOUSE_BUTTON_LEFT, true)
	a.avancar(1.0)
	_igual(a.quadro_atual(), 1, "toque e mouse emulado juntos: um quadro")
	# O mouse emulado chega primeiro.
	var b := _nova()
	_mouse(b, Vector2(300, 300), true, MOUSE_BUTTON_LEFT, true)
	_toque(b, Vector2(300, 300), true)
	_mouse_move(b, Vector2(300, 200), true)
	_arrasta_dedo(b, Vector2(300, 200))
	_mouse_move(b, Vector2(300, 100), true)
	_arrasta_dedo(b, Vector2(300, 100))
	_mouse(b, Vector2(300, 100), false, MOUSE_BUTTON_LEFT, true)
	_toque(b, Vector2(300, 100), false)
	b.avancar(1.0)
	_igual(b.quadro_atual(), 1, "mouse emulado e depois o toque: um quadro")
	# Um toque no botão final, com o emulado junto, emite uma vez.
	var c := _nova()
	_vai(c, 7)
	var p := c.rect_botao_final().get_center()
	_toque(c, p, true)
	_mouse(c, p, true, MOUSE_BUTTON_LEFT, true)
	_toque(c, p, false)
	_mouse(c, p, false, MOUSE_BUTTON_LEFT, true)
	_igual(emitidos, 1, "toque no botão com o mouse emulado emite uma vez")
	a.free()
	b.free()
	c.free()


func _toque_sem_arrasto_nao_rola() -> void:
	var a := _nova()
	_clique(a, Vector2(300, 200))
	a.avancar(1.0)
	_igual(a.quadro_atual(), 0, "clique sem arrasto não rola")
	_igual(a.rolagem(), 0.0, "rolagem parada")
	_toque(a, Vector2(300, 200), true)
	_toque(a, Vector2(302, 203), false)
	a.avancar(1.0)
	_igual(a.rolagem(), 0.0, "toque sem arrasto não rola")
	_igual(emitidos, 0, "e não emite")
	# Um arrasto que começa no Pular rola e não emite.
	var b := _nova()
	var c := b.rect_pular().get_center()
	_mouse(b, c, true)
	_mouse_move(b, c + Vector2(0, 120))
	_mouse_move(b, c + Vector2(0, 250))
	_mouse(b, c + Vector2(0, 250), false)
	_igual(emitidos, 0, "arrastar a partir do Pular não emite")
	a.free()
	b.free()


func _limites() -> void:
	var a := _nova()
	for i in 12:
		_roda_para(a, true)
		a.avancar(0.5)
		_verdade(a.rolagem() >= 0.0 and a.rolagem() <= 7.0 * 360.0, "rolagem em [0, 7 quadros] (roda %d)" % i)
	for i in 12:
		_roda_para(a, false)
		a.avancar(0.5)
		_verdade(a.rolagem() >= 0.0 and a.rolagem() <= 7.0 * 360.0, "rolagem em [0, 7 quadros] (volta %d)" % i)
	_igual(a.quadro_atual(), 0, "volta ao primeiro")
	a.definir_rolagem(99999.0)
	_igual(a.rolagem(), 7.0 * 360.0, "definir_rolagem limita no último")
	a.definir_rolagem(-5.0)
	_igual(a.rolagem(), 0.0, "definir_rolagem limita no primeiro")
	a.free()


func _alvos_de_toque() -> void:
	var a := _nova()
	var p := a.rect_pular()
	_verdade(p.size.x >= 24.0 and p.size.y >= 24.0, "Pular tem pelo menos 24x24")
	_verdade(Rect2(Vector2.ZERO, a.size).encloses(p), "Pular cabe na tela")
	_verdade(p.position.y < 60.0, "Pular num canto de cima")
	_vai(a, 7)
	var f := a.rect_botao_final()
	_verdade(f.size.x >= 150.0 and f.size.y >= 40.0, "botão final bem maior que 24x24")
	_verdade(Rect2(Vector2.ZERO, a.size).encloses(f), "botão final cabe na tela no último quadro")
	_verdade(not f.intersects(p), "botão e Pular não se tocam")
	a.free()


func _bolinhas() -> void:
	var a := _nova()
	var pts := a.centros_das_bolinhas()
	_igual(pts.size(), 8, "uma bolinha por quadro")
	var soma := 0.0
	for i in pts.size():
		soma += pts[i].y
		_verdade(pts[i].x > a.size.x - 20.0 and pts[i].x < a.size.x, "bolinha %d na borda direita" % i)
		if i > 0:
			_verdade(pts[i].y > pts[i - 1].y, "bolinhas em ordem")
	_igual(soma / pts.size(), 180.0, "bolinhas centradas na vertical")
	a.free()


func _frases() -> void:
	_igual(Abertura.frases("Heaters use energy every night. No energy, no oxygen."),
		PackedStringArray(["Heaters use energy every night.", "No energy, no oxygen."]), "duas frases")
	_igual(Abertura.frases("O aquecedor gasta energia toda noite. Sem energia, sem oxigênio."),
		PackedStringArray(["O aquecedor gasta energia toda noite.", "Sem energia, sem oxigênio."]), "duas frases em português")
	_igual(Abertura.frases("Cada sol: planejar, trabalhar, relatar."),
		PackedStringArray(["Cada sol: planejar, trabalhar, relatar."]), "uma frase com dois pontos")
	_igual(Abertura.frases("Em 5 sóis, uma nave chega."), PackedStringArray(["Em 5 sóis, uma nave chega."]), "uma frase")
	_igual(Abertura.frases("Real NASA data · May 2024"), PackedStringArray(["Real NASA data · May 2024"]), "sem ponto")
	_igual(Abertura.frases("Vai ver a nave. É grande."), PackedStringArray(["Vai ver a nave.", "É grande."]), "maiúscula acentuada")


## Nenhuma linha passa da largura útil (a que deixa folga para as bolinhas), em inglês e em português.
func _texto_cabe() -> void:
	for lang in ["en", "pt"]:
		TranslationServer.set_locale(lang)
		var a := _nova()
		_verdade(a.maior_linha() > 100.0, "a fonte mede texto (%s)" % lang)
		_verdade(a.maior_linha() <= a.largura_util(), "a linha mais larga cabe em %s (%.0f de %.0f px)" % [lang, a.maior_linha(), a.largura_util()])
		_verdade(a.largura_util() < a.size.x - 2.0 * 11.0 - 8.0, "o texto não invade as bolinhas (%s)" % lang)
		a.free()
	TranslationServer.set_locale("en")
