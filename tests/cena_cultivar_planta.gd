extends Control
## Cena de teste do minigame "Cultivar a planta": hospeda a peça sozinha.
## Sem argumento, é jogável à mão (área cheia, semente 0; qualquer tecla sorteia outra).
## Com `--capturar=<pasta>` depois de `--`, percorre os estados, salva os PNGs e sai:
##   godot --path . res://tests/cena_cultivar_planta.tscn -- --capturar=<pasta>

const Planta := preload("res://scripts/minigames/cultivar_planta.gd")
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
	_g = Planta.new()
	add_child(_g)
	_g.semente(_n)
	_g.configurar(Rect2(0, 0, 640, 360), 10.0, false)
	_g.concluido.connect(func() -> void: print("concluido"))
	var pasta := _pasta_de_captura()
	if pasta != "":
		_capturar(pasta)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo:
		_n += 1
		_g.semente(_n)
		_g.configurar(Rect2(0, 0, 640, 360), 10.0, false)


func _pasta_de_captura() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capturar="):
			return a.substr("--capturar=".length())
	return ""


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


func _levar(c: int, alvo: int) -> void:
	while _g.nivel(c) != alvo and not _g.ocupada():
		_g.apertar(c, 1 if alvo > _g.nivel(c) else -1)
		_passo(0.2)


func _capturar(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	_g.set_process(false)  # o tempo anda à mão
	_g.semente(1)
	_g.configurar(Rect2(0, 0, 640, 360), 10.0, false)
	_passo(0.5)
	await _salvar(pasta, "planta_inicial.png")
	_levar(Planta.LUZ, Planta.FAIXA_DE)
	await _salvar(pasta, "planta_luz_na_faixa.png")
	_levar(Planta.AGUA, Planta.FAIXA_DE)
	_passo(0.5)
	await _salvar(pasta, "planta_crescendo.png")
	_passo(2.0)
	await _salvar(pasta, "planta_crescida.png")
	_g.semente(2)
	_g.configurar(Rect2(130, 73, 368, 207), 10.0, false)
	await _salvar(pasta, "planta_area_pequena.png")
	get_tree().quit()
