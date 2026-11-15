extends SceneTree
## Teste headless da tela inicial (scripts/inicio.gd) e do começo do jogo na main (main.gd): tela inicial ->
## abertura -> plano do sol 1. A escolha de idioma e o "Jogar", os alvos, o que fica parado por baixo
## enquanto uma sobreposição está na tela, o fluxo com o botão final e com o "Pular", e o "Free play" que
## nunca volta à tela inicial.
## Roda com: godot --headless --path . --script tests/test_inicio.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Inicio := preload("res://scripts/inicio.gd")
const Abertura := preload("res://scripts/abertura/abertura.gd")
const Main := preload("res://scripts/main.gd")

var falhas := 0
var total := 0
var escolhas: Array = []
var jogou := 0


class SomFalso:
	extends RefCounted
	var tocados: Array = []

	func tocar(nome: String) -> void:
		tocados.append(nome)


func _init() -> void:
	_tudo()


func _tudo() -> void:
	_tela_inicial()
	await _fluxo_com_o_botao_final()
	await _fluxo_com_o_pular()
	await _free_play_nao_passa_pela_tela_inicial()
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


func _escolheu(lang: String) -> void:
	escolhas.append(lang)


func _jogou() -> void:
	jogou += 1


func _clique(i: Control, pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = pos
	i._gui_input(e)
	e = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	e.position = pos
	i._gui_input(e)


# --- a tela inicial sozinha -------------------------------------------------------

func _tela_inicial() -> void:
	var som := SomFalso.new()
	var i: Inicio = Inicio.new()
	i.size = Vector2(640, 360)
	i.som = som
	escolhas = []
	jogou = 0
	i.idioma_escolhido.connect(_escolheu)
	i.jogar.connect(_jogou)
	var tela := Rect2(Vector2.ZERO, i.size)
	for nome: String in ["idioma_en", "idioma_pt", "jogar"]:
		var u: Array = i.ui()[nome]
		_verdade(u[2] >= 24 and u[3] >= 24, "%s: alvo de pelo menos 24x24 (%dx%d)" % [nome, u[2], u[3]])
		_verdade(tela.encloses(Rect2(u[0], u[1], u[2], u[3])), "%s: dentro da tela" % nome)
	_verdade(not i.rect_en().intersects(i.rect_pt()), "EN e PT não se sobrepõem")
	_verdade(not i.rect_jogar().intersects(i.rect_en()) and not i.rect_jogar().intersects(i.rect_pt()), "o Jogar não toca o seletor")
	_igual(i.idioma, "en", "inglês marcado por padrão")
	i.marcar_idioma("pt")
	_igual(i.idioma, "pt", "marcar_idioma('pt')")
	_igual(escolhas.size(), 0, "marcar não emite")
	_clique(i, i.rect_en().get_center())
	_igual(escolhas, ["en"], "clicar EN emite 'en'")
	_igual(i.idioma, "en", "EN fica marcado")
	_clique(i, i.rect_pt().get_center())
	_igual(escolhas, ["en", "pt"], "clicar PT emite 'pt'")
	_igual(i.idioma, "pt", "PT fica marcado")
	_igual(som.tocados, ["clique_navegar", "clique_navegar"], "o seletor faz o clique de navegar")
	_clique(i, Vector2(5, 5))
	_igual(escolhas.size(), 2, "clique fora não escolhe nada")
	_igual(jogou, 0, "clique fora não joga")
	_clique(i, i.rect_jogar().get_center())
	_igual(jogou, 1, "clicar Jogar emite 'jogar'")
	_clique(i, i.rect_jogar().get_center())
	_igual(jogou, 1, "o Jogar emite uma vez só")
	_igual(som.tocados.back(), "clique_confirmar", "o Jogar faz o clique de confirmar")
	_igual(som.tocados.size(), 3, "o segundo Jogar não soa")
	i.free()


# --- o fluxo na main -----------------------------------------------------------------

func _nova_main() -> Control:
	var m: Control = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m


func _fluxo_com_o_botao_final() -> void:
	TranslationServer.set_locale("en")
	var m: Control = await _nova_main()
	_igual(m.tela_atual(), "inicio", "o jogo abre na tela inicial")
	_verdade(m.sobreposicao() is Inicio, "a sobreposição é a tela inicial")
	_verdade(m._terminal.card_aberto, "o plano do sol 1 já está montado por baixo (com o aviso)")
	_igual(m._terminal.is_processing_input(), false, "o terminal não recebe entrada por baixo da tela inicial")
	_igual(m._missao.sol, 1, "sol 1")
	# O relógio não corre, e o clique na sala não faz nada.
	var cliques: int = m._cliques
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(320, 180)
	m._unhandled_input(ev)
	_igual(m._cliques, cliques, "o clique da sala não vale com a sobreposição")
	_igual(m._regiao_em(Vector2(320, 180)), "", "nenhuma região da sala responde")
	_igual(m._ui_da_tela().keys().has("fechar_card"), false, "a sonda não lista o card de baixo")
	_verdade(m._ui_da_tela().has("jogar") and m._ui_da_tela().has("idioma_en") and m._ui_da_tela().has("idioma_pt"),
		"a sonda lista jogar e os idiomas")
	_verdade(m._ui_da_tela().has("mudo"), "o mudo continua clicável por cima")
	# Idioma: troca na hora, inclusive os nomes das telas de barra da sala.
	_igual(m._tela_energia.nome, "Energy", "a tela de energia da sala em inglês")
	m.sobreposicao().acionar("idioma_pt")
	_igual(TranslationServer.get_locale(), "pt", "o seletor troca o idioma")
	_igual(m._tela_energia.nome, "Energia", "a tela de energia da sala segue o idioma")
	_igual(m._tela_oxigenio.nome, "Oxigênio", "a tela de oxigênio da sala segue o idioma")
	m.sobreposicao().acionar("idioma_en")
	_igual(m._tela_energia.nome, "Energy", "volta ao inglês")
	# Jogar -> abertura.
	m.sobreposicao().acionar("jogar")
	_igual(m.tela_atual(), "abertura", "Jogar leva à abertura")
	_verdade(m.sobreposicao() is Abertura, "a sobreposição é a abertura")
	_igual(m._terminal.is_processing_input(), false, "o terminal segue sem entrada na abertura")
	_verdade(m._ui_da_tela().has("pular"), "a sonda lista o pular")
	_igual(m._ui_da_tela().has("comecar"), false, "o começar só no último quadro")
	_igual(m._quadro_da_abertura(), 0, "abertura no quadro 0")
	var abertura: Abertura = m.sobreposicao()
	abertura.definir_rolagem(Abertura.ULTIMO * abertura.size.y)
	_igual(m._quadro_da_abertura(), Abertura.ULTIMO, "abertura no último quadro")
	_verdade(m._ui_da_tela().has("comecar"), "a sonda lista o começar no último quadro")
	# Botão final -> plano do sol 1.
	abertura.concluida.emit()
	await process_frame
	_igual(m.tela_atual(), "jogo", "a abertura leva ao jogo")
	_verdade(m.sobreposicao() == null, "sem sobreposição")
	_verdade(m._terminal.is_processing_input(), "o terminal volta a receber entrada")
	_igual(m._missao.fase, "plano", "plano")
	_igual(m._missao.sol, 1, "do sol 1")
	_verdade(m._terminal.aberto, "com o terminal no alto")
	_verdade(m._terminal.card_aberto, "e o card do aviso ainda lá")
	m.queue_free()
	await process_frame


func _fluxo_com_o_pular() -> void:
	TranslationServer.set_locale("en")
	var m: Control = await _nova_main()
	m.sobreposicao().acionar("jogar")
	var abertura: Abertura = m.sobreposicao()
	var pular := abertura.rect_pular().get_center()
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = pular
	abertura._gui_input(e)
	e = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	e.position = pular
	abertura._gui_input(e)
	await process_frame
	_igual(m.tela_atual(), "jogo", "o Pular leva ao jogo")
	_verdade(m._terminal.is_processing_input(), "entrada do terminal de volta depois do Pular")
	m.queue_free()
	await process_frame


func _free_play_nao_passa_pela_tela_inicial() -> void:
	TranslationServer.set_locale("en")
	var m: Control = await _nova_main()
	m.sobreposicao().acionar("jogar")
	m.sobreposicao().concluida.emit()
	await process_frame
	var missao = m._missao
	missao.fase = "relatorio"
	missao.freeplay_aberto = true
	_verdade(missao.jogar_de_novo(), "o 'Free play' recomeça")
	await process_frame
	await process_frame
	_igual(m.tela_atual(), "jogo", "o Free play vai direto ao plano, sem tela inicial nem abertura")
	_verdade(m.sobreposicao() == null, "sem sobreposição no Free play")
	_igual(missao.fase, "plano", "plano")
	_verdade(missao.livre, "em modo livre")
	_verdade(m._terminal.is_processing_input(), "terminal com entrada")
	m.queue_free()
	await process_frame
