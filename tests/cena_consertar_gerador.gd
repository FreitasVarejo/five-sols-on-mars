extends Control
## Cena de teste do minigame "Consertar o gerador": hospeda a peça sozinha.
## Sem argumento, é jogável à mão (área cheia, semente 0; qualquer tecla sorteia outra).
## Com `--capturar=<pasta>` depois de `--`, percorre os estados, salva os PNGs e sai:
##   godot --path . res://tests/cena_consertar_gerador.tscn -- --capturar=<pasta>

const Gerador := preload("res://scripts/minigames/consertar_gerador.gd")
const Desenho := preload("res://scripts/desenho.gd")

var _g: Control
var _n := 0


func _ready() -> void:
	size = Vector2(640, 360)
	var fundo := ColorRect.new()
	fundo.color = Desenho.MOLDURA
	fundo.size = size
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	_g = Gerador.new()
	add_child(_g)
	_g.semente(_n)
	_g.configurar(Rect2(0, 0, 640, 360), 20.0, false)
	_g.concluido.connect(func() -> void: print("concluido"))
	var pasta := _pasta_de_captura()
	if pasta != "":
		_capturar(pasta)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo:
		_n += 1
		_g.semente(_n)


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


func _mover(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
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


func _capturar(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	_g.set_process(false)  # o tempo anda à mão, para parar no meio das animações

	# 1. Inicial, área cheia, semente 0, clima normal.
	_g.semente(0)
	_g.configurar(Rect2(0, 0, 640, 360), 20.0, false)
	await _salvar(pasta, "gerador_inicial_normal.png")

	# 2. Uma peça (não a certa) no meio do arrasto, com a garra.
	var certa: int = _g.sorteio_atual()["certa"]
	var errada := 0 if certa != 0 else 1
	var c: Vector2 = _g.alvo_da_peca(errada).get_center()
	var destino: Vector2 = c.lerp(_g.centro_do_encaixe(), 0.55)
	_botao(c, true)
	_mover(c.lerp(destino, 0.5))
	_mover(destino)
	_passo(0.3)  # a garra termina de entrar
	await _salvar(pasta, "gerador_arrastando.png")
	_botao(destino, false)
	_passo(1.5)

	# 3. A errada no encaixe, no meio da sacudida.
	_botao(c, true)
	_botao(c, false)
	_passo(0.25 + 0.35 * 0.12)
	await _salvar(pasta, "gerador_errada_sacudindo.png")
	_passo(1.5)

	# 4. Certa encaixada, O2 aceso.
	var cc: Vector2 = _g.alvo_da_peca(certa).get_center()
	_botao(cc, true)
	_botao(cc, false)
	_passo(5.0)
	await _salvar(pasta, "gerador_consertado.png")

	# 5. Poeira, outra semente (encaixe e forma diferentes).
	var base: Dictionary = Gerador.sorteio(0)
	var outra := 1
	while Gerador.sorteio(outra)["encaixe"] == base["encaixe"] \
			or Gerador.sorteio(outra)["formas"][Gerador.sorteio(outra)["certa"]] == base["formas"][base["certa"]]:
		outra += 1
	_g.semente(outra)
	_g.configurar(Rect2(0, 0, 640, 360), 20.0, true)
	await _salvar(pasta, "gerador_poeira.png")

	# 6. Área pequena dentro da tela, como numa câmera do terminal.
	_g.semente(2)
	_g.configurar(Rect2(130, 73, 380, 214), 20.0, false)
	await _salvar(pasta, "gerador_area_pequena.png")
	get_tree().quit()
