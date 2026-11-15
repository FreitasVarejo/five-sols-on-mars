extends Control
## Cena de captura da página do diário (scripts/pagina_diario.gd) no jogo de verdade: instancia a main, passa
## pela tela inicial e pela abertura e salva a introdução do sol 1, a do sol de história mais longa (a que mais
## linhas ocupa na caixa), a do sol 3 (poeira) e a do sol 5 (gerador quebrado), no idioma pedido. Precisa de janela (não roda headless).
## Roda com: godot --path . res://tests/cena_pagina_diario.tscn -- --capturar=<pasta> [--lang=pt|en]
## (sem --lang, os dois idiomas). Cada captura sai em 640x360 e ampliada 3x (nearest).

const PaginaDiario := preload("res://scripts/pagina_diario.gd")
const Missao := preload("res://scripts/missao.gd")

const TEMPO_DA_CAPTURA := 4.2  # a introdução já terminou de aparecer (o amanhecer leva 3,5 s, a barra 3,4 s)
const PASTA_PADRAO := "/home/freitaspinhe/Pictures/five-sols-on-mars/pecas-do-primo/pagina-diario/"


func _ready() -> void:
	var pasta := PASTA_PADRAO
	var langs: Array[String] = ["en", "pt"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturar="):
			pasta = arg.trim_prefix("--capturar=").path_join("")
		elif arg.begins_with("--lang="):
			langs = [arg.trim_prefix("--lang=")]
	DirAccess.make_dir_recursive_absolute(pasta)
	for lang in langs:
		await _jogo(lang, pasta)
	get_tree().quit()


## O sol cuja história ocupa mais linhas na caixa de texto (empate: a mais comprida), no idioma atual.
func _sol_mais_longo() -> int:
	var p: PaginaDiario = PaginaDiario.new()
	p.size = Vector2(640, 360)
	var largura := p.rect_texto().size.x
	var melhor := 1
	var linhas_melhor := 0
	var tam_melhor := 0
	for n in range(1, 6):
		var s := tr("DIARIO_HISTORIA_%d" % n)
		var linhas := PaginaDiario.quebrar(s, largura).size()
		if linhas > linhas_melhor or (linhas == linhas_melhor and s.length() > tam_melhor):
			melhor = n
			linhas_melhor = linhas
			tam_melhor = s.length()
	p.free()
	return melhor


func _quadros(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _esperar_pagina(main: Control, tempo: float = 0.0) -> void:
	await _quadros(2)
	while main.sobreposicao() != null and main.sobreposicao().tempo() < tempo:
		await get_tree().process_frame
	await _quadros(2)


func _jogo(lang: String, pasta: String) -> void:
	TranslationServer.set_locale(lang)
	var main: Control = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _quadros(3)
	# A main começa em inglês; o idioma entra pela tela inicial, como o jogador faria.
	main.sobreposicao().acionar("idioma_" + lang)
	main.sobreposicao().acionar("jogar")
	main.sobreposicao().concluida.emit()
	var t = main._terminal
	var m = main._missao
	# Os sóis que se capturam: o 1, o da história mais longa, o 3 (poeira) e o 5 (gerador quebrado).
	var sois := [1, _sol_mais_longo(), 3, 5]
	# Do sol 1 ao 5 pelo caminho real: a página, o Continuar, os cards, confirmar, fim do sol e noite.
	for sol_n in range(1, 6):
		if sol_n > 1:
			m.fase = "fim_do_sol"
			m.st_fim = m.st.duplicate()
			m.enviar_a_terra()
			m.avancar(Missao.NOITE_S + 0.1)
		await _esperar_pagina(main, TEMPO_DA_CAPTURA if sol_n in sois else 0.0)
		if sol_n in sois:
			await _salvar("%ssol%d_%s" % [pasta, sol_n, lang])
		var p: Control = main.sobreposicao()
		p.avancar(1.0)
		p.acionar("continuar")
		await _quadros(2)
		var guarda := 0
		while t.card_aberto and guarda < 20:
			t._acionar("fechar_card")
			guarda += 1
		t._acionar("confirmar")
		await _quadros(2)
		while t.animando():
			await get_tree().process_frame
		await _quadros(2)
	main.queue_free()
	await _quadros(2)


func _salvar(base: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(base + ".png")
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(base + "_x3.png")
	print("%s (%dx%d)" % [base, img.get_width(), img.get_height()])
