extends SceneTree
## Teste headless da página do diário que abre cada sol da missão fixa (scripts/pagina_diario.gd) e da ligação
## dela no jogo (terminal.gd, main.gd): a peça emite `fechada` uma vez só e só depois da subida, com o clique
## de confirmar; a história de cada sol cabe na caixa, em inglês e em português; a página abre nos sóis 1 a 5 da
## missão fixa, antes de qualquer card do plano (que só abre depois dela), e não abre no Modo livre nem de novo
## no reinício do sol.
## Roda com: godot --headless --path . --script tests/test_pagina_diario.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const PaginaDiario := preload("res://scripts/pagina_diario.gd")
const Terminal := preload("res://scripts/terminal.gd")
const Missao := preload("res://scripts/missao.gd")
const Modelo := preload("res://scripts/modelo.gd")
const Desenho := preload("res://scripts/desenho.gd")

var falhas := 0
var total := 0
var fechou := 0


class SomFalso:
	extends RefCounted
	var tocados: Array = []

	func tocar(nome: String) -> void:
		tocados.append(nome)


func _init() -> void:
	_tudo()


func _tudo() -> void:
	_a_peca()
	_o_texto_cabe()
	_nos_cinco_sois_da_missao_fixa()
	_modo_livre_e_reinicio()
	_pistas_e_alertas()
	await _na_main()
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


func _fechou() -> void:
	fechou += 1


func _clique(p: Control, pos: Vector2) -> void:
	for pressionado in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressionado
		e.position = pos
		p._gui_input(e)


# --- a peça sozinha -----------------------------------------------------------------

func _a_peca() -> void:
	TranslationServer.set_locale("en")
	var som := SomFalso.new()
	var p: PaginaDiario = PaginaDiario.new()
	p.size = Vector2(640, 360)
	p.som = som
	p.configurar(3, tr("DIARIO_HISTORIA_3"))
	fechou = 0
	p.fechada.connect(_fechou)
	var tela := Rect2(Vector2.ZERO, p.size)

	# Subida: começa em 0, anda e para em 1. O Continuar responde logo depois de uma guarda curta, sem esperar a subida.
	_igual(p.progresso(), 0.0, "a folha começa fora (progresso 0)")
	_igual(p.pronta(), false, "ainda não está pronta")
	_igual(p.aceita_clique(), false, "na guarda do começo o botão não responde")
	_igual(p.ui().size(), 0, "sem botão na guarda do começo")
	_clique(p, p.rect_continuar().get_center())
	_igual(fechou, 0, "o clique na guarda do começo não fecha")
	p.avancar(PaginaDiario.GUARDA_S + 0.01)
	var meio := p.progresso()
	_verdade(meio > 0.0 and meio < 1.0, "depois da guarda a subida ainda anda (progresso %.2f)" % meio)
	_igual(p.pronta(), false, "no meio da subida ainda não está pronta")
	_verdade(p.aceita_clique(), "o Continuar já responde no meio da subida")
	_verdade(p.ui().has("continuar"), "o botão está na sonda no meio da subida")
	var no_meio: Array = p.ui()["continuar"]
	_verdade(no_meio[1] > p.rect_continuar().position.y, "no meio da subida o botão está mais abaixo, com a folha")
	# O rect da sonda é onde o botão está desenhado: o clique ali pega, e a posição final (ainda longe) não.
	_clique(p, Vector2(p.rect_continuar().get_center().x, p.rect_continuar().position.y - 2.0))
	_igual(fechou, 0, "o clique acima do botão não fecha")
	p.avancar(PaginaDiario.SUBIDA_S)
	_igual(p.progresso(), 1.0, "a subida termina em 1")
	_verdade(p.pronta(), "pronta depois da subida")

	# O botão: alvo grande, dentro da tela e da folha, sem tocar o texto nem a coluna da esquerda.
	_verdade(p.ui().has("continuar"), "o botão está na sonda")
	var u: Array = p.ui()["continuar"]
	_verdade(u[2] >= 24 and u[3] >= 24, "o botão tem pelo menos 24x24 (%dx%d)" % [u[2], u[3]])
	var botao := Rect2(u[0], u[1], u[2], u[3])
	_igual(botao, p.rect_continuar(), "parada, a sonda dá o botão final")
	_verdade(tela.encloses(botao), "o botão está dentro da tela")
	var papel := p.rect_papel()
	_verdade(papel.encloses(botao), "o botão está dentro da folha")
	_verdade(tela.encloses(papel), "a folha cabe na tela de 640x360")
	_verdade(papel.end.y < 328.0, "a folha acaba acima do botão de mudo (y 328)")
	_verdade(papel.position.x >= PaginaDiario.DIREITA_COLUNA + 8.0, "a folha começa depois da coluna da esquerda")
	_verdade(papel.encloses(p.rect_texto()), "a caixa da história está dentro da folha")
	_verdade(papel.encloses(p.rect_pista()), "a caixa da pista está dentro da folha")
	_verdade(p.rect_texto().end.y <= p.rect_secao().position.y, "o título da seção vem depois da história")
	_verdade(p.rect_secao().end.y <= p.rect_pista().position.y, "a pista vem depois do título da seção")
	_verdade(p.rect_pista().end.y <= botao.position.y, "a caixa da pista termina antes do botão")
	_verdade(Desenho.largura_texto(tr("PAGINA_DIARIO_CONTINUAR"), 18, true) <= botao.size.x - 8.0, "o rótulo cabe no botão")

	# Só o botão fecha: o clique fora dele não faz nada; o clique nele fecha uma vez, com o clique de confirmar.
	_clique(p, Vector2(5, 5))
	_clique(p, papel.position + Vector2(60, 20))
	_igual(fechou, 0, "o clique fora do botão não fecha")
	_igual(som.tocados.size(), 0, "o clique fora do botão não soa")
	_clique(p, botao.get_center())
	_igual(fechou, 1, "o clique no botão emite fechada")
	_igual(som.tocados, ["clique_confirmar"], "o Continuar faz o clique de confirmar")
	_clique(p, botao.get_center())
	p.acionar("continuar")
	_igual(fechou, 1, "fechada sai uma vez só")
	_igual(som.tocados.size(), 1, "o segundo clique não soa")
	p.free()

	# Tocado no meio da subida (onde o botão está agora), fecha.
	var m: PaginaDiario = PaginaDiario.new()
	m.size = Vector2(640, 360)
	m.configurar(2, "x")
	fechou = 0
	m.fechada.connect(_fechou)
	m.avancar(0.4)
	var agora: Array = m.ui()["continuar"]
	_clique(m, Vector2(agora[0] + agora[2] / 2.0, agora[1] + agora[3] / 2.0))
	_igual(fechou, 1, "o Continuar tocado no meio da subida fecha")
	m.free()

	# Sem som injetado também funciona; configurar de novo rearma a página.
	var q: PaginaDiario = PaginaDiario.new()
	q.size = Vector2(640, 360)
	q.configurar(1, "x")
	q.fechada.connect(_fechou)
	fechou = 0
	q.avancar(1.0)
	q.acionar("continuar")
	_igual(fechou, 1, "sem som, o Continuar fecha")
	q.configurar(2, "y")
	_igual(q.aceita_clique(), false, "configurar reinicia a página")
	q.avancar(1.0)
	q.acionar("continuar")
	_igual(fechou, 2, "uma página nova emite a sua fechada")
	q.free()


# --- o texto cabe -------------------------------------------------------------------

func _o_texto_cabe() -> void:
	var p: PaginaDiario = PaginaDiario.new()
	p.size = Vector2(640, 360)
	var largura := p.rect_texto().size.x
	var mais_linhas := 0
	var mais_longa := ""
	for lang in ["en", "pt"]:
		TranslationServer.set_locale(lang)
		# O título (com o sol de dois dígitos, por segurança) cabe na folha, ao lado da linha de margem.
		var folga := p.rect_papel().size.x - PaginaDiario.X_MARGEM - 14.0 - 12.0
		for n in [1, 5, 10]:
			var titulo: String = tr("PAGINA_DIARIO_TITULO") % n
			_verdade(Desenho.largura_texto(titulo, PaginaDiario.TAM_TITULO, true) <= folga, "%s: o título do sol %d cabe" % [lang, n])
		_verdade(tr("PAGINA_DIARIO_TITULO") != "PAGINA_DIARIO_TITULO", "%s: a chave do título existe" % lang)
		_verdade(tr("PAGINA_DIARIO_CONTINUAR") != "PAGINA_DIARIO_CONTINUAR", "%s: a chave do botão existe" % lang)
		for n in range(1, 6):
			var chave := "DIARIO_HISTORIA_%d" % n
			var s := tr(chave)
			_verdade(s != chave, "%s: %s existe" % [lang, chave])
			var linhas := PaginaDiario.quebrar(s, largura)
			_verdade(linhas.size() >= 1 and linhas.size() <= PaginaDiario.MAX_LINHAS,
				"%s: %s cabe em %d linhas (%d)" % [lang, chave, PaginaDiario.MAX_LINHAS, linhas.size()])
			for l in linhas:
				_verdade(Desenho.largura_texto(l, PaginaDiario.TAM_TEXTO) <= largura, "%s: %s: a linha cabe na largura" % [lang, chave])
			_verdade(PaginaDiario.cabe(s, largura), "%s: %s cabe na caixa" % [lang, chave])
			_igual(" ".join(linhas), s, "%s: %s: quebrar não perde nem inventa palavra" % [lang, chave])
			if linhas.size() > mais_linhas or (linhas.size() == mais_linhas and s.length() > mais_longa.length()):
				mais_linhas = linhas.size()
				mais_longa = s
	_coluna_e_pistas(p, largura)
	print("a maior história: %d linhas na caixa de %d px: %s" % [mais_linhas, int(largura), mais_longa])
	# A caixa não é folgada à toa: uma história de 5 linhas não caberia.
	_igual(PaginaDiario.cabe("palavra ".repeat(80), largura), false, "um texto longo demais não cabe")
	_igual(PaginaDiario.quebrar("", largura).size(), 0, "texto vazio: nenhuma linha")
	p.free()


## A pista e a coluna da introdução cabem, em inglês e em português.
func _coluna_e_pistas(p: PaginaDiario, largura_historia: float) -> void:
	var larg_pista := p.rect_pista().size.x
	var larg_secao := p.rect_secao().size.x
	var mais := 0
	for lang in ["en", "pt"]:
		TranslationServer.set_locale(lang)
		for n in [2, 3, 5]:
			var chave := "DIARIO_PISTA_%d" % n
			var s := tr(chave)
			_verdade(s != chave, "%s: %s existe" % [lang, chave])
			var linhas := PaginaDiario.quebrar(PaginaDiario.com_aspas(s), larg_pista)
			mais = maxi(mais, linhas.size())
			_verdade(PaginaDiario.cabe(PaginaDiario.com_aspas(s), larg_pista, PaginaDiario.MAX_LINHAS_PISTA), "%s: %s cabe na caixa da pista (%d linhas)" % [lang, chave, linhas.size()])
		_verdade(tr("PAGINA_PISTAS_TITULO") != "PAGINA_PISTAS_TITULO", "%s: a chave do título das pistas existe" % lang)
		_verdade(Desenho.largura_texto(tr("PAGINA_PISTAS_TITULO"), PaginaDiario.TAM_SECAO, true) <= larg_secao, "%s: o título das pistas cabe" % lang)
		for chave in ["DIARIO_PISTA_1", "DIARIO_PISTA_4"]:
			_igual(tr(chave), chave, "%s: o sol sem pista não tem a chave %s" % [lang, chave])
		# A coluna: cada nome cabe antes do ícone; o "SOL N", o relógio, o lugar e a barra cabem na coluna.
		var larg_coluna := PaginaDiario.DIREITA_COLUNA - PaginaDiario.X_COLUNA
		for par in PaginaDiario.SISTEMAS:
			var nome := tr(par[0])
			_verdade(nome != par[0], "%s: %s existe" % [lang, par[0]])
			_verdade(Desenho.largura_texto(nome, PaginaDiario.TAM_COLUNA) <= PaginaDiario.largura_do_nome(),
				"%s: '%s' cabe na checklist" % [lang, nome])
		for n in [1, 5, 10]:
			var sol_n: String = (tr("SOL_N") % n).to_upper()
			_verdade(Desenho.largura_texto(sol_n, PaginaDiario.TAM_SOL, true) <= larg_coluna, "%s: '%s' cabe na coluna" % [lang, sol_n])
		_verdade(Desenho.largura_texto("05:59", PaginaDiario.TAM_RELOGIO, true) <= larg_coluna, "%s: o relógio cabe" % lang)
		_verdade(Desenho.largura_texto(tr("PAGINA_LOCAL"), PaginaDiario.TAM_COLUNA + 2, true) <= larg_coluna, "%s: o lugar cabe" % lang)
		for estado in [tr("PAGINA_PRONTOS"), tr("PAGINA_PREPARANDO") % 99]:
			_verdade(Desenho.largura_texto(estado, PaginaDiario.TAM_COLUNA) <= larg_coluna, "%s: '%s' cabe" % [lang, estado])
	print("a maior pista: %d linhas na caixa de %d px" % [mais, int(larg_pista)])


# --- no terminal: nos 5 sóis da missão fixa ----------------------------------------------

func _terminal_do_sol(n: int, livre: bool) -> Terminal:
	var m := Missao.new(1, {"livre": livre})
	m.montar_sol(n, Modelo.estado_inicial())
	var t: Terminal = Terminal.new()
	t.com_pagina = true
	t.iniciar(m, {})
	return t


func _nos_cinco_sois_da_missao_fixa() -> void:
	TranslationServer.set_locale("en")
	# O terminal sozinho, sem o hospedeiro pedir (com_pagina), não abre página: os testes dele seguem como eram.
	var sem := Missao.new(1)
	var t_sem: Terminal = Terminal.new()
	t_sem.iniciar(sem, {})
	_igual(t_sem.sol_da_pagina(), 0, "sem com_pagina o plano do sol 1 não abre com a página")
	_igual(t_sem.card_id, "aviso", "sem com_pagina o primeiro card é o aviso, como antes")
	t_sem.free()
	for n in range(1, 6):
		var t := _terminal_do_sol(n, false)
		_igual(t.sol_da_pagina(), n, "missão fixa, sol %d: o plano abre com a página" % n)
		_igual(t.card_id, "pagina_%d" % n, "sol %d: a página é o item da vez" % n)
		_verdade(t.card_aberto, "sol %d: a página segura o plano (card aberto)" % n)
		# Os cards do plano ficam na fila, sem abrir, até a página fechar.
		_igual(t._vistos.has("aviso"), false, "sol %d: o aviso ainda não abriu" % n)
		_igual(t._vistos.has("sol1_o2"), false, "sol %d: o card do sol 1 ainda não abriu" % n)
		t.fechar_pagina()
		_igual(t.sol_da_pagina(), 0, "sol %d: depois do Continuar a página saiu" % n)
		if n == 1:
			_igual(t.card_id, "aviso", "sol 1: depois da página abre o aviso, e depois os três cards do sol 1")
			t._acionar("fechar_card")
			_igual(t.card_id, "sol1_o2", "sol 1: o primeiro card do sol 1 vem depois do aviso")
		elif n == 2:
			_igual(t.card_id, "aviso", "sol 2: depois da página abre o aviso da tempestade")
		t.free()


func _modo_livre_e_reinicio() -> void:
	TranslationServer.set_locale("en")
	for n in range(1, 6):
		var t := _terminal_do_sol(n, true)
		_igual(t.sol_da_pagina(), 0, "Modo livre, sol %d: sem página" % n)
		_verdade(not t.card_id.begins_with("pagina_"), "Modo livre, sol %d: nenhum card é a página" % n)
		t.free()
	# Reinício do sol: a mesma página não volta (uma vez por sol e por sessão).
	var t := _terminal_do_sol(2, false)
	_igual(t.sol_da_pagina(), 2, "sol 2: a página abre")
	t.fechar_pagina()
	t._mostrar_na_tela("plano")
	_igual(t.sol_da_pagina(), 0, "o plano do mesmo sol de novo não repete a página")
	# Outro sol, na mesma sessão: abre a dele.
	t.missao.montar_sol(3, Modelo.estado_inicial())
	t._mostrar_na_tela("plano")
	_igual(t.sol_da_pagina(), 3, "o sol 3 abre a página dele")
	# Um sol sem história não leva página.
	t.missao.montar_sol(6, Modelo.estado_inicial())
	t._mostrar_na_tela("plano")
	_igual(t.sol_da_pagina(), 0, "sol sem DIARIO_HISTORIA: sem página")
	# fechar_pagina sem página na vez não fecha o card que está lá.
	t.missao.montar_sol(2, Modelo.estado_inicial())
	t._mostrar_na_tela("plano")
	var id := t.card_id
	t.fechar_pagina()
	_igual(t.card_id, id, "fechar_pagina só vale para a página")
	t.free()


# --- a pista e os alertas, pelo estado da missão ---------------------------------------------

## A missão fixa (ou com a agenda forçada) no plano do sol `n`, pelo caminho real: fim do sol, noite, plano.
func _missao_no_sol(n: int, opcoes: Dictionary = {}) -> Missao:
	var m := Missao.new(1, opcoes)
	for sol_n in range(2, n + 1):
		m.fase = "fim_do_sol"
		m.st_fim = m.st.duplicate()
		m.enviar_a_terra()
		m.avancar(Missao.NOITE_S + 0.1)
	return m


func _pistas_e_alertas() -> void:
	TranslationServer.set_locale("en")
	# Missão fixa: pista nos sóis 2, 3 e 5; sóis 1 e 4 sem pista. Alertas: o painel nos sóis de poeira (3 e 4),
	# o gerador no sol da quebra (5). No começo do plano esses fatos já valem.
	var esperado := {
		1: {"pista": false, "poeira": false, "gerador": false},
		2: {"pista": true, "poeira": false, "gerador": false},
		3: {"pista": true, "poeira": true, "gerador": false},
		4: {"pista": false, "poeira": true, "gerador": false},
		5: {"pista": true, "poeira": false, "gerador": true},
	}
	for n in range(1, 6):
		var m := _missao_no_sol(n)
		_igual(m.sol, n, "a missão chegou ao plano do sol %d" % n)
		_igual(m.fase, "plano", "sol %d: no plano" % n)
		var c := PaginaDiario.contexto_da_missao(m)
		_igual(c["pista"] != "", esperado[n]["pista"], "sol %d: pista %s" % [n, "sim" if esperado[n]["pista"] else "não"])
		if esperado[n]["pista"]:
			_igual(c["pista"], tr("DIARIO_PISTA_%d" % n), "sol %d: o texto da pista" % n)
		_igual(c["poeira"], esperado[n]["poeira"], "sol %d: alerta do painel (poeira) %s" % [n, str(esperado[n]["poeira"])])
		_igual(c["gerador"], esperado[n]["gerador"], "sol %d: alerta do gerador %s" % [n, str(esperado[n]["gerador"])])
	# Sem pista falsa: a pista só vale quando o plano do mesmo sol mostra o fato (o card da Terra).
	for opcoes in [{"sol_poeira": 4}, {"sol_poeira": 2}, {"sol_quebra": 3}, {"sol_solar": 4}]:
		for n in [2, 3, 5]:
			var m := _missao_no_sol(n, opcoes)
			var c := PaginaDiario.contexto_da_missao(m)
			var fato: bool = m.aviso_ativo() if n == 2 else (m.eh_poeira() if n == 3 else bool(m.st_inicio.get("gerador_quebrado", false)))
			_igual(c["pista"] != "", fato, "agenda %s, sol %d: a pista só aparece com o fato no plano" % [str(opcoes), n])
		var m1 := _missao_no_sol(4, opcoes)
		_igual(PaginaDiario.contexto_da_missao(m1)["pista"], "", "agenda %s, sol 4: nunca tem pista" % str(opcoes))
		_igual(PaginaDiario.contexto_da_missao(m1)["poeira"], m1.eh_poeira(), "agenda %s, sol 4: o alerta segue a missão" % str(opcoes))
	# Modo livre: sem página, sem contexto.
	var livre := Missao.new(1, {"livre": true})
	_igual(PaginaDiario.contexto_da_missao(livre).size(), 0, "Modo livre: sem contexto")
	# O que cada pista diz bate com o card da Terra do mesmo plano: o aviso no sol 2, a poeira no 3, o gerador no 5.
	for par in [[2, "aviso"], [3, "poeira"], [5, "gerador"]]:
		var m := _missao_no_sol(par[0])
		var t: Terminal = Terminal.new()
		t.com_pagina = true
		t.iniciar(m, {})
		t.fechar_pagina()
		var fila: Array = [t.card_id] + t._fila
		_verdade(par[1] in fila, "sol %d: o card '%s' do plano confirma a pista (fila %s)" % [par[0], par[1], str(fila)])
		t.free()


# --- na main: o jogo de verdade -------------------------------------------------------------

func _esperar_terminal(main: Control) -> void:
	await process_frame
	await process_frame
	var guarda := 0
	while main._terminal.animando() and guarda < 20000:
		await process_frame
		guarda += 1
	await process_frame
	await process_frame


## Roda quadros até a página parar de subir (a main a conduz pelo _process).
func _esperar_pagina(main: Control) -> void:
	var guarda := 0
	while main.sobreposicao() != null and not main.sobreposicao().pronta() and guarda < 20000:
		await process_frame
		guarda += 1
	await process_frame


func _na_main() -> void:
	for lang in ["en", "pt"]:
		await _jogo(lang)


func _jogo(lang: String) -> void:
	TranslationServer.set_locale(lang)
	var main: Control = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var t = main._terminal
	var m = main._missao
	var r := lang + ": "

	# A tela inicial e a abertura vêm antes; a página do sol 1 só depois da abertura.
	_igual(main.tela_atual(), "inicio", r + "o jogo abre na tela inicial")
	_igual(t.sol_da_pagina(), 1, r + "o plano do sol 1 já está montado com a página na vez")
	main.sobreposicao().acionar("jogar")
	_igual(main.tela_atual(), "abertura", r + "a abertura vem antes da página")
	main.sobreposicao().concluida.emit()
	await process_frame
	_igual(main.tela_atual(), "pagina", r + "depois da abertura, a página do sol 1")
	_verdade(main.sobreposicao() is PaginaDiario, r + "a sobreposição é a página")
	var pagina: PaginaDiario = main.sobreposicao()
	_igual(pagina.sol, 1, r + "é a página do sol 1")
	_igual(pagina.texto, tr("DIARIO_HISTORIA_1"), r + "com a história do sol 1")
	_igual(pagina.pista, "", r + "o sol 1 não tem pista")
	_verdade(not pagina.poeira and not pagina.gerador, r + "o sol 1 não tem sistema em alerta")
	_igual(t.card_id, "pagina_1", r + "o terminal tem a página na vez")
	_igual(t.is_processing_input(), false, r + "o terminal não recebe entrada por baixo da página")
	_igual(t._vistos.has("aviso"), false, r + "os cards do plano não abriram")
	_igual(m.fase, "plano", r + "a missão está no plano")
	var t0: float = m.t

	# Parada esperando: sem botão até a subida acabar; depois, só o Continuar (e o mudo) na sonda. O tempo
	# passa e a página fica (sem tempo limite), e a missão não anda.
	_igual(main._ui_da_tela().has("continuar"), false, r + "sem botão na subida")
	await _esperar_pagina(main)
	var ui: Dictionary = main._ui_da_tela()
	_verdade(ui.has("continuar") and ui.has("mudo"), r + "a sonda lista o Continuar e o mudo")
	_igual(ui.has("fechar_card"), false, r + "a sonda não lista o card de baixo")
	_igual(ui.has("confirmar"), false, r + "o terminal de baixo não se clica")
	var fim := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < fim:
		await process_frame
	_igual(main.tela_atual(), "pagina", r + "depois de um tempo a página segue lá (sem tempo limite)")
	_igual(m.t, t0, r + "o relógio da missão não anda com a página")
	_igual(main._regiao_em(Vector2(320, 180)), "", r + "a sala não responde com a página")
	_igual(m.fase, "plano", r + "a página não confirma nada do plano")

	# Continuar: a página sai e só então o primeiro card do plano (o aviso) abre.
	var som_antes: int = main._som.total
	_clique(pagina, pagina.rect_continuar().get_center())
	await process_frame
	await process_frame
	_igual(main.tela_atual(), "jogo", r + "o Continuar leva ao jogo")
	_verdade(main.sobreposicao() == null, r + "sem sobreposição")
	_igual(main._som.historico.back(), "clique_confirmar", r + "o clique de confirmar tocou")
	_igual(main._som.total, som_antes + 1, r + "um clique só")
	_verdade(t.is_processing_input(), r + "o terminal volta a receber entrada")
	_igual(t.sol_da_pagina(), 0, r + "a página saiu da vez")
	_igual(t.card_id, "aviso", r + "o primeiro card do plano abre depois da página")
	_verdade(main._ui_da_tela().has("fechar_card"), r + "o Fechar do card está na tela")
	var cards := 0
	while t.card_aberto and cards < 20:
		t._acionar("fechar_card")
		cards += 1
	_igual(cards, 4, r + "o plano do sol 1 tem os quatro cards de sempre (aviso e os três do sol 1)")
	for _i in 5:
		await process_frame
	_igual(main.tela_atual(), "jogo", r + "a página não volta no mesmo plano")

	# O dia seguinte pelo caminho real: turno, fim do sol, noite e o plano do sol 2 abre com a página do sol 2.
	t._acionar("confirmar")
	await _esperar_terminal(main)
	_igual(m.fase, "turno", r + "o turno do sol 1")
	for sol_n in range(2, 6):
		m.fase = "fim_do_sol"
		m.st_fim = m.st.duplicate()
		_verdade(m.enviar_a_terra(), r + "envia à Terra o sol %d" % (sol_n - 1))
		m.avancar(Missao.NOITE_S + 0.1)
		_igual(m.sol, sol_n, r + "a noite passou para o sol %d" % sol_n)
		await process_frame
		await process_frame
		await process_frame
		_igual(main.tela_atual(), "pagina", r + "sol %d: a página abre antes do plano" % sol_n)
		_igual(main.sobreposicao().sol, sol_n, r + "sol %d: é a página dele" % sol_n)
		_igual(main.sobreposicao().texto, tr("DIARIO_HISTORIA_%d" % sol_n), r + "sol %d: com a história dele" % sol_n)
		_igual(t.card_id, "pagina_%d" % sol_n, r + "sol %d: nenhum card antes dela" % sol_n)
		var pg: PaginaDiario = main.sobreposicao()
		_igual(pg.pista != "", sol_n in [2, 3, 5], r + "sol %d: a pista aparece nos sóis 2, 3 e 5" % sol_n)
		_igual(pg.poeira, sol_n in [3, 4], r + "sol %d: o painel em alerta nos sóis de poeira" % sol_n)
		_igual(pg.gerador, sol_n == 5, r + "sol %d: o gerador em alerta no sol da quebra" % sol_n)
		main.sobreposicao().avancar(1.0)
		_clique(main.sobreposicao(), main.sobreposicao().rect_continuar().get_center())
		await process_frame
		await process_frame
		_igual(main.tela_atual(), "jogo", r + "sol %d: o Continuar leva ao plano" % sol_n)
		_igual(t.sol_da_pagina(), 0, r + "sol %d: a página saiu" % sol_n)
		var restantes := 0
		while t.card_aberto and restantes < 20:
			t._acionar("fechar_card")
			restantes += 1
		t._acionar("confirmar")
		await _esperar_terminal(main)

	# Reinício do sol e Modo livre: sem página.
	m.fase = "relatorio"
	m.freeplay_aberto = true
	_verdade(m.jogar_de_novo(), r + "o Modo livre recomeça")
	for _i in 4:
		await process_frame
	_verdade(m.livre, r + "em Modo livre")
	_igual(main.tela_atual(), "jogo", r + "o Modo livre não abre a página")
	_verdade(main.sobreposicao() == null, r + "sem sobreposição no Modo livre")
	_igual(t.sol_da_pagina(), 0, r + "Modo livre: nenhuma página na vez")

	main.queue_free()
	await process_frame
