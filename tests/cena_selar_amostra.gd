extends Control
## Cena de teste do minigame "Selar a amostra": hospeda a peça sozinha.
## Sem argumento, é jogável à mão. Com `--capturar=<pasta>` depois de `--`, percorre os passos, salva os PNGs e sai:
##   godot --path . res://tests/cena_selar_amostra.tscn -- --capturar=<pasta>

const Amostra := preload("res://scripts/minigames/selar_amostra.gd")
const Desenho := preload("res://scripts/desenho.gd")

var _g: Control


func _ready() -> void:
	size = Vector2(640, 360)
	var fundo := ColorRect.new()
	fundo.color = Desenho.MOLDURA
	fundo.size = size
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	_g = Amostra.new()
	add_child(_g)
	_g.configurar(Rect2(90, 42, 534, 272), 10.0, false)
	_g.concluido.connect(func() -> void: print("concluido"))
	var pasta := _pasta_de_captura()
	if pasta != "":
		_capturar(pasta)


func _pasta_de_captura() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capturar="):
			return a.substr("--capturar=".length())
	return ""


func _botao(pos: Vector2, pressionado: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressionado
	ev.position = pos
	_g._gui_input(ev)


func _passo(segundos: float) -> void:
	var feito := 0.0
	while feito < segundos - 0.0001:
		_g.avancar(1.0 / 60.0)
		feito += 1.0 / 60.0


func _salvar(pasta: String, nome: String) -> void:
	_g.queue_redraw()
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var erro := img.save_png(pasta.path_join(nome))
	print("%s: %s (%dx%d)" % [nome, "ok" if erro == OK else "erro %d" % erro, img.get_width(), img.get_height()])


## Anda o tempo até a agulha estar na faixa dada (e a broca pronta) e dá o golpe.
func _golpear(faixa: int) -> void:
	var t := 0.0
	while t < 10.0 and not (_g.pronta() and _g.faixa_da_agulha() == faixa):
		_g.avancar(1.0 / 60.0)
		t += 1.0 / 60.0
	var c: Vector2 = _g.alvo_do_passo().get_center()
	_botao(c, true)
	_botao(c, false)


func _capturar(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	_g.set_process(false)
	await _salvar(pasta, "amostra_0_inicial.png")
	_passo(0.3)
	await _salvar(pasta, "amostra_1_agulha_andando.png")
	_golpear(Amostra.Faixa.CINZA)
	_passo(0.12)
	await _salvar(pasta, "amostra_2_golpe_cinza_descendo.png")
	_passo(0.15)
	await _salvar(pasta, "amostra_3_golpe_cinza_rachadura.png")
	_passo(0.5)
	_golpear(Amostra.Faixa.VERDE)
	_passo(0.3)
	await _salvar(pasta, "amostra_4_golpe_verde_mais_rachaduras.png")
	_passo(0.6)
	_golpear(Amostra.Faixa.PERFEITA)
	_passo(0.22)
	await _salvar(pasta, "amostra_5_perfeito_impacto.png")
	_passo(0.15)
	await _salvar(pasta, "amostra_6_rocha_quebrando.png")
	_passo(0.6)
	await _salvar(pasta, "amostra_7_rocha_quebrada_tubo.png")
	var c1: Vector2 = _g.alvo_do_passo().get_center()
	for k in 3:
		_botao(c1, true)
		_botao(c1, false)
		_passo(0.5)
	await _salvar(pasta, "amostra_8_tubo_cheio.png")
	var c2: Vector2 = _g.alvo_do_passo().get_center()
	_botao(c2, true)
	_botao(c2, false)
	_passo(0.6)
	await _salvar(pasta, "amostra_9_selando.png")
	_passo(1.0)
	await _salvar(pasta, "amostra_10_lacrado.png")
	get_tree().quit()
