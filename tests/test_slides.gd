extends SceneTree
## Teste headless dos slides da Terra que introduzem cada minigame (terminal.gd, pedir_slides), ligados à marcação
## das tarefas de ciência no plano e à câmera do gerador no turno: abrem uma vez por tarefa por carregamento da
## página, seguram o relógio, "Próximo" leva ao slide 2 e "Entendi" ou "Consertar" fecham; o gerador só começa
## depois de fechar; os textos cabem no card em inglês e português; as fotos estão na paleta Apollo, com a largura
## certa e crédito no README; e o AVISO_TEMPESTADE diz "alavanca".
## Roda com: godot --headless --path . --script tests/test_slides.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Desenho := preload("res://scripts/desenho.gd")
const Terminal := preload("res://scripts/terminal.gd")

var falhas := 0
var total := 0
var _main: Control


func _init() -> void:
	_tudo()


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


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _esperar(s: float) -> void:
	var fim := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < fim:
		await process_frame


## O card entra em 0,35 s e nada nele se clica antes: espera o quadro em que os botões existem.
func _esperar_card() -> void:
	await _quadros(2)
	var guarda := 0
	while not _main._terminal._card_entrou() and guarda < 600:
		await process_frame
		guarda += 1
	await _quadros(2)


func _esperar_terminal() -> void:
	await _quadros(2)
	var guarda := 0
	while _main._terminal.animando() and guarda < 20000:
		await process_frame
		guarda += 1
	await _quadros(2)


## Os cards do plano, um por vez (sem tocar nos slides).
func _fechar_fila() -> void:
	var t = _main._terminal
	t._acionar("inicio_fase")  # o plano abre na tela inicial do Painel: a fase leva ao plano
	var n := 0
	while t.card_aberto and t.card_id != "slides" and n < 20:
		t._acionar("fechar_card")
		n += 1


func _textos(t) -> Array:
	var d: Array = []
	for linha: Array in t.textos():
		d.append(linha[0])
	return d


## O texto à direita da coluna do card: onde o texto dos slides acaba (px da tela) e o menor tamanho usado.
func _fim_do_texto(t) -> float:
	var fim := 0.0
	var x_min := Terminal.SLIDES_CARD.position.x + 12.0 + Terminal.SLIDES_ZONA_W + 14.0
	for linha: Array in t.textos():
		if linha[4] > 0.0 and linha[1] >= x_min - 1.0 and linha[2] >= Terminal.SLIDES_CARD.position.y and linha[2] < Terminal.SLIDES_CARD.end.y:
			fim = maxf(fim, linha[2] + Desenho.altura_texto(linha[0], linha[3], linha[4], true))
	return fim


func _tudo() -> void:
	TranslationServer.set_locale("en")
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await _quadros(3)
	_main.sobreposicao().acionar("jogar")
	_main.sobreposicao().concluida.emit()  # a viagem
	_main.sobreposicao().concluida.emit()  # a abertura
	await _quadros(2)
	if _main.tela_atual() == "pagina":
		_main.sobreposicao().avancar(1.0)
		_main.sobreposicao().acionar("continuar")
		await _quadros(2)
	var t = _main._terminal
	var m = _main._missao
	t.gravar_textos = true
	var folga := {"E": 12.0, "O": 12.0, "M": 12.0, "P": 1.0, "gerador_quebrado": false}

	await _ciencia(t, m, folga)
	await _gerador(t, m)
	await _modo_livre(t, m, folga)
	await _painel_embaixo()
	await _textos_cabem(t, m, folga)
	_fotos()
	_textos_do_csv()

	_main.queue_free()
	await _quadros(2)
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)


# --- a ciência: marcar a tarefa no plano ---------------------------------------------

func _ciencia(t, m, folga: Dictionary) -> void:
	m.montar_sol(1, folga)
	await _quadros(2)
	_fechar_fila()
	_igual(t.card_aberto, false, "plano do sol 1 sem card antes de marcar")
	var antes: int = _main._som.historico.size()
	for tarefa: String in ["chemcam", "amostra", "planta"]:
		t._acionar("tarefa_" + tarefa)
		_verdade(tarefa in m.plano_tarefas, tarefa + ": marcada")
		_igual(t.slides_na_tela(), {"tarefa": tarefa, "pagina": 0}, tarefa + ": marcar abre o slide 1")
		_igual(t.card_id, "slides", tarefa + ": o card é o dos slides")
		_igual(t.segura_o_relogio(), true, tarefa + ": o relógio espera com o slide aberto")
		await _esperar_card()
		var ui: Dictionary = t.ui()
		_verdade(ui.has("slides_proximo") and not ui.has("slides_fim"), tarefa + ": slide 1 leva Próximo, e só ele")
		_igual(ui.has("fechar_card") or ui.has("card_confirmar") or ui.has("terminal"), false, tarefa + ": nenhum outro botão")
		var b: Array = ui["slides_proximo"]
		_verdade(b[2] >= 24 and b[3] >= 24, tarefa + ": o botão tem 24x24 px ou mais")
		_verdade(Terminal.SLIDES_CARD.encloses(Rect2(b[0], b[1], b[2], b[3])), tarefa + ": o botão está dentro do card")
		_verdade(_textos(t).has("Next"), tarefa + ": o botão diz Next")
		_verdade(_textos(t).has("Sent from Earth %d min ago" % m.atraso_min), tarefa + ": o rótulo de atraso, como o do aviso")
		# Com os slides abertos, o resto do Painel não responde.
		t._acionar("tarefa_" + tarefa)
		_verdade(tarefa in m.plano_tarefas, tarefa + ": o resto do Painel não responde com os slides abertos")
		t._acionar("fechar_card")
		_igual(t.card_id, "slides", tarefa + ": o Fechar dos outros cards não fecha os slides")
		t._acionar("slides_fim")
		_igual(t.slides_na_tela().get("pagina", -1), 0, tarefa + ": o botão do slide 2 não vale no slide 1")
		t._acionar("slides_proximo")
		_igual(t.slides_na_tela(), {"tarefa": tarefa, "pagina": 1}, tarefa + ": Próximo leva ao slide 2")
		await _esperar_card()
		ui = t.ui()
		_verdade(ui.has("slides_fim") and not ui.has("slides_proximo"), tarefa + ": slide 2 leva só o botão final")
		_verdade(_textos(t).has("Got it"), tarefa + ": a ciência fecha com Entendi")
		t._acionar("slides_fim")
		_igual(t.card_aberto, false, tarefa + ": Entendi fecha")
		_verdade(tarefa in m.plano_tarefas, tarefa + ": a marcação vale depois de fechar")
		_igual(t.segura_o_relogio(), false, tarefa + ": o relógio volta")
		# Desmarcar e marcar de novo não reabre.
		t._acionar("tarefa_" + tarefa)
		_verdade(not (tarefa in m.plano_tarefas), tarefa + ": desmarcada")
		_igual(t.card_aberto, false, tarefa + ": desmarcar não abre")
		t._acionar("tarefa_" + tarefa)
		_verdade(tarefa in m.plano_tarefas, tarefa + ": marcada de novo")
		_igual(t.card_aberto, false, tarefa + ": marcar de novo não reabre")
		t._acionar("tarefa_" + tarefa)  # deixa o plano sem tarefa para a próxima caber
	var tocados: Array = _main._som.historico.slice(antes)
	_verdade("clique_navegar" in tocados, "os botões dos slides fazem o clique de navegar")

	# O reinício do sol e o resto da sessão não zeram a flag: ela mora no terminal, que a missão não toca.
	m.montar_sol(1, folga)
	await _quadros(2)
	_fechar_fila()
	t._acionar("tarefa_chemcam")
	_igual(t.card_aberto, false, "montar o sol de novo não reabre os slides do ChemCam")
	t._acionar("tarefa_chemcam")

	# pedir_slides direto: tarefa desconhecida, outro card na vez e a flag.
	var novo: Control = (load("res://scripts/terminal.gd") as GDScript).new()
	root.add_child(novo)
	novo.iniciar(m, {})
	novo.aberto = false
	novo._pos = 0.0
	novo._fila.clear()  # o plano do sol 1 monta uma fila de cards; aqui o terminal começa sem nenhum
	novo.card_id = ""
	_igual(novo.pedir_slides("laser"), false, "tarefa sem slides: false, quem chama age")
	var rodou := [0]
	_igual(novo.pedir_slides("chemcam", func() -> void: rodou[0] += 1), true, "primeira vez: abre")
	_igual(novo.pedir_slides("chemcam", func() -> void: rodou[0] += 1), true, "com os slides abertos, outro pedido espera")
	_igual(novo.pedir_slides("planta"), true, "com um card aberto, outro pedido espera sem abrir")
	_igual(novo.slides_na_tela()["tarefa"], "chemcam", "e os slides abertos seguem os do primeiro pedido")
	novo._acionar("slides_proximo")
	novo._acionar("slides_fim")
	_igual(rodou[0], 1, "fechar o slide 2 roda o que veio, uma vez")
	_igual(novo.pedir_slides("chemcam", func() -> void: rodou[0] += 1), false, "depois de visto: false")
	_igual(novo.pedir_slides("planta"), true, "a planta não ficou marcada como vista pelo pedido que esperou")
	novo.queue_free()


# --- o gerador: a câmera dele no turno ----------------------------------------------

## O turno do sol 5 com o gerador quebrado e o Painel no alto, na aba tarefas.
func _turno_do_gerador(t, m) -> void:
	m.montar_sol(5, {"E": 12.0, "O": 12.0, "M": 12.0, "P": 1.0, "gerador_quebrado": true})
	await _quadros(2)
	_fechar_fila()
	m.confirmar_plano()
	await _esperar_terminal()
	if t.card_id == "turno":
		t._acionar("fechar_card")
	t._acionar("terminal")
	await _esperar_terminal()
	_igual(m.tarefas.get("gerador", ""), "pendente", "o gerador quebrado está na lista, pendente")


func _gerador(t, m) -> void:
	await _turno_do_gerador(t, m)
	t._acionar("ir_gerador")
	_igual(t.slides_na_tela(), {"tarefa": "gerador", "pagina": 0}, "gerador: a linha da aba tarefas abre o slide 1")
	_igual(m.tarefas["gerador"], "pendente", "gerador: o conserto espera os slides")
	_igual(m.tarefa_rodando, "", "gerador: nada roda")
	await _esperar_card()
	_igual(t._visor.peca("moxie"), null, "gerador: sem a peça com os slides abertos")
	_igual(t._visor.visible, false, "gerador: o visor fica escondido atrás do card")
	_igual(t.aberto, true, "gerador: com o Painel no alto")
	_verdade(_textos(t).has("Next"), "gerador: slide 1 leva Next")
	# O relógio do turno não anda com o card aberto.
	var t0: float = m.t
	await _esperar(1.2)
	_igual(m.t, t0, "gerador: o relógio fica parado com os slides abertos")
	t._acionar("slides_proximo")
	await _esperar_card()
	_verdade(_textos(t).has("Fix it"), "gerador: slide 2 leva Fix it")
	_igual(m.tarefas["gerador"], "pendente", "gerador: no slide 2 ainda não começou")
	var tocados: int = _main._som.historico.size()
	t._acionar("slides_fim")
	_igual(t.card_aberto, false, "gerador: Consertar fecha")
	_igual(m.tarefas["gerador"], "rodando", "gerador: Consertar começa a peça")
	_verdade(t._visor.peca("moxie") != null, "gerador: a peça entra na vista")
	_igual(_main._som.historico.slice(tocados), ["clique_confirmar"], "gerador: Consertar toca um clique só, o de confirmar")
	await _quadros(2)
	_igual(t._visor.visible, true, "gerador: o visor volta, com a peça")
	var t1: float = m.t
	await _esperar(0.6)
	_verdade(m.t > t1 + 0.2, "gerador: o relógio volta a andar")
	# A segunda abertura vai direto à peça.
	t._ao_concluir_peca("gerador")
	await _quadros(2)
	m.tarefas["gerador"] = "pendente"
	t._acionar("ir_gerador")
	_igual(t.card_aberto, false, "gerador: a segunda abertura não abre os slides")
	_igual(m.tarefas["gerador"], "rodando", "gerador: a segunda abertura vai direto à peça")

	# Uma outra carga (flag nova), pela câmera do MOXIE no mapa: abre igual.
	t._vistos.erase("slides_gerador")
	t._ao_concluir_peca("gerador")
	await _quadros(2)
	m.tarefas["gerador"] = "pendente"
	t._acionar("aba_cameras")
	t._visor.escolher("moxie")
	_igual(t.slides_na_tela(), {"tarefa": "gerador", "pagina": 0}, "gerador: a câmera do MOXIE abre o slide 1")
	_igual(m.tarefas["gerador"], "pendente", "gerador: pela câmera também espera")
	t._acionar("slides_proximo")
	t._acionar("slides_fim")
	_igual(m.tarefas["gerador"], "rodando", "gerador: Consertar, pela câmera, começa a peça")
	t._ao_concluir_peca("gerador")
	await _quadros(2)


# --- "Jogar de novo": o Modo livre depois da missão ----------------------------------

## A flag mora no terminal, que a missão não toca: "Jogar de novo" (nova_missao, em Modo livre) não reabre os slides
## das tarefas que a criança já viu, nem o do gerador.
func _modo_livre(t, m, folga: Dictionary) -> void:
	m.fase = "relatorio"
	m.freeplay_aberto = true
	_verdade(m.jogar_de_novo(), "Jogar de novo: começa o Modo livre")
	_igual(m.livre, true, "Jogar de novo: a missão é livre")
	await _quadros(3)
	m.montar_sol(1, folga)
	await _quadros(2)
	_fechar_fila()
	for tarefa: String in ["chemcam", "amostra", "planta"]:
		t._acionar("tarefa_" + tarefa)
		_verdade(tarefa in m.plano_tarefas, "Modo livre: %s marcada" % tarefa)
		_igual(t.card_aberto, false, "Modo livre: marcar %s não abre os slides, já vistos" % tarefa)
		t._acionar("tarefa_" + tarefa)
	await _turno_do_gerador(t, m)
	t._acionar("ir_gerador")
	_igual(t.card_aberto, false, "Modo livre: o gerador não abre os slides, já vistos")
	_igual(m.tarefas["gerador"], "rodando", "Modo livre: o gerador vai direto à peça")
	t._ao_concluir_peca("gerador")
	await _quadros(2)


# --- com o Painel embaixo -------------------------------------------------------------

func _painel_embaixo() -> void:
	var m = _main._missao
	var novo: Control = (load("res://scripts/terminal.gd") as GDScript).new()
	root.add_child(novo)
	novo.gravar_textos = true
	novo.iniciar(m, {})
	novo.aberto = false
	novo._pos = 0.0
	novo._fila.clear()  # o plano do sol 1 monta uma fila de cards; aqui o terminal começa sem nenhum
	novo.card_id = ""
	_igual(novo.pedir_slides("amostra"), true, "Painel embaixo: abre")
	_igual(novo._card_sobre_a_sala(), true, "Painel embaixo: o card fica sobre a sala")
	_igual(novo._card_visivel(), true, "Painel embaixo: o card está à vista")
	_igual(novo.segura_o_relogio(), true, "Painel embaixo: segura o relógio")
	var n := 0
	while not novo._card_entrou() and n < 600:
		await process_frame
		n += 1
	await _quadros(2)
	_verdade(novo.ui().has("slides_proximo"), "Painel embaixo: o botão está na tela")
	_igual(novo.ui().has("terminal"), false, "Painel embaixo: o botão do Painel fica apagado")
	novo.queue_free()


# --- o texto cabe -----------------------------------------------------------------------

func _textos_cabem(t, m, folga: Dictionary) -> void:
	var limite := Terminal.SLIDES_CARD.end.y - 12.0 - Terminal.SLIDES_BOTAO.y - 10.0  # onde a coluna acaba
	for lang: String in ["en", "pt"]:
		TranslationServer.set_locale(lang)
		for tarefa: String in Terminal.SLIDES:
			for pagina in 2:
				t._vistos.erase("slides_" + tarefa)
				t.card_id = ""
				t._slides_ao_fechar = Callable()
				_verdade(t.pedir_slides(tarefa), "%s/%s/%d: abre" % [lang, tarefa, pagina])
				if pagina == 1:
					t._acionar("slides_proximo")
				await _esperar_card()
				var chave := "SLIDES_%s_%d" % [tarefa.to_upper(), pagina + 1]
				_verdade(tr(chave) != chave, "%s: %s existe no CSV" % [lang, chave])
				_verdade(_textos(t).has(Abertura_frases(tr(chave))[0]), "%s: o texto de %s está na tela" % [lang, chave])
				var fim := _fim_do_texto(t)
				_verdade(fim > 0.0 and fim <= limite, "%s: o texto de %s cabe no card (acaba em %.1f, limite %.1f)" % [lang, chave, fim, limite])
				for linha: Array in t.textos():
					if Terminal.SLIDES_CARD.has_point(Vector2(linha[1], linha[2])):
						_verdade(linha[3] >= 11, "%s: %s sem fonte menor que 11 px (%s)" % [lang, chave, linha[0]])
				var b: Array = t.ui()["slides_proximo" if pagina == 0 else "slides_fim"]
				_verdade(b[2] >= 24 and b[3] >= 24, "%s/%s/%d: botão de 24x24 px ou mais" % [lang, tarefa, pagina])
				_verdade(_textos(t).has(tr("SLIDES_PROXIMO" if pagina == 0 else Terminal.SLIDES[tarefa]["fim"])), "%s/%s/%d: o rótulo do botão" % [lang, tarefa, pagina])
				t._acionar("slides_fim" if pagina == 1 else "slides_proximo")
				if pagina == 0:
					t._acionar("slides_fim")
				_igual(t.card_aberto, false, "%s/%s/%d: fecha" % [lang, tarefa, pagina])
	TranslationServer.set_locale("en")


func Abertura_frases(s: String) -> PackedStringArray:
	return (load("res://scripts/abertura/abertura.gd") as GDScript).frases(s)


# --- as fotos e os textos ---------------------------------------------------------------

func _apollo() -> Array:
	var f := FileAccess.open("res://scripts/reduzir_foto.py", FileAccess.READ)
	var src := f.get_as_text()
	var ini := src.find("APOLLO = (")
	var fim := src.find(").split()", ini)
	var cores: Array = []
	for hex: String in src.substr(ini, fim - ini).replace("\"", " ").replace("\n", " ").split(" ", false):
		if hex.length() == 6 and hex.is_valid_hex_number():
			cores.append(Color("#" + hex))
	return cores


func _fotos() -> void:
	var apollo := _apollo()
	_igual(apollo.size(), 46, "a Apollo tem 46 cores")
	var readme := FileAccess.open("res://README.md", FileAccess.READ).get_as_text()
	var n := 0
	for tarefa: String in Terminal.SLIDES:
		var larguras := 0.0
		var fotos: Array = Terminal.SLIDES[tarefa]["fotos"]
		for foto: Texture2D in fotos:
			larguras += foto.get_width()
			_verdade(foto.get_width() <= 200, "%s: nenhuma foto passa de 200 px de largura" % tarefa)
		larguras += 4.0 * (fotos.size() - 1)
		_verdade(larguras <= Terminal.SLIDES_ZONA_W, "%s: as fotos lado a lado cabem na coluna (%d de %d px)" % [tarefa, int(larguras), int(Terminal.SLIDES_ZONA_W)])
		_verdade(larguras >= 190.0, "%s: as fotos somam cerca de 200 px de largura (%d)" % [tarefa, int(larguras)])
	for arq: String in DirAccess.get_files_at("res://assets/fotos"):
		if not arq.ends_with(".png"):
			continue
		n += 1
		var im: Image = (load("res://assets/fotos/" + arq) as Texture2D).get_image()
		var fora := 0
		for y in im.get_height():
			for x in im.get_width():
				var c := im.get_pixel(x, y)
				var ok := false
				for p: Color in apollo:
					if absf(c.r - p.r) < 0.004 and absf(c.g - p.g) < 0.004 and absf(c.b - p.b) < 0.004:
						ok = true
						break
				if not ok:
					fora += 1
		_igual(fora, 0, "%s: todo pixel está na Apollo" % arq)
		_verdade(readme.contains("`assets/fotos/%s`" % arq) or readme.contains("`%s`" % arq), "%s: o README lista a foto" % arq)
	_igual(n, 6, "seis fotos em assets/fotos")
	for id: String in ["PIA13809", "PIA24808", "PIA24799", "iss040e009125", "iss046e001336", "PIA23154"]:
		_verdade(readme.contains(id), "o README cita o ID " + id)
	_verdade(readme.contains("NASA/JPL-Caltech"), "o README traz o crédito NASA/JPL-Caltech")
	_verdade(not readme.contains("no third-party art assets."), "o README não diz mais que não há arte de terceiros")


func _textos_do_csv() -> void:
	TranslationServer.set_locale("en")
	_verdade(tr("AVISO_TEMPESTADE").contains("shelter lever") and not tr("AVISO_TEMPESTADE").contains("button"), "o aviso diz lever, em inglês")
	_verdade(tr("CREDITOS").contains("photos: NASA/JPL-Caltech"), "os créditos trazem a linha das fotos, em inglês")
	TranslationServer.set_locale("pt")
	_verdade(tr("AVISO_TEMPESTADE").contains("alavanca do abrigo") and not tr("AVISO_TEMPESTADE").contains("botão"), "o aviso diz alavanca, em português")
	_verdade(tr("CREDITOS").contains("fotos: NASA/JPL-Caltech"), "os créditos trazem a linha das fotos, em português")
	for chave: String in ["SLIDES_PROXIMO", "SLIDES_ENTENDI", "SLIDES_CONSERTAR"]:
		TranslationServer.set_locale("en")
		var en := tr(chave)
		TranslationServer.set_locale("pt")
		_verdade(en != chave and tr(chave) != chave and en != tr(chave), "%s nos dois idiomas" % chave)
	TranslationServer.set_locale("en")
