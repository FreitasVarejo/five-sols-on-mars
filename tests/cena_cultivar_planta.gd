extends Control
## Cena de teste do minigame "Cultivar a planta": hospeda a peça sozinha.
## Sem argumento, é jogável à mão (área cheia, problema da semente 0; qualquer tecla sorteia outro).
## Com `--capturar=<pasta>` depois de `--`, percorre os estados, salva os PNGs e sai: a câmara sob a luz rosa, cada
## problema sob a luz verde, um "pior" de cada, o crescimento, o fim e as áreas 368×207 e 320×180:
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


## Recomeça a peça com o problema `nome`, na área `area`.
func _abrir(nome: String, area: Rect2 = Rect2(0, 0, 640, 360)) -> void:
	_g.definir_problema(nome)
	_g.configurar(area, 10.0, false)


## A ferramenta do erro de cada problema (a que piora) e a do acerto.
const ERRO := {"seca": "ventilador", "encharcada": "regador", "mofo": "regador"}
const CERTO := {"seca": ["regador"], "encharcada": ["ventilador"], "mofo": ["tesoura", "ventilador"]}


func _capturar(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	_g.set_process(false)  # o tempo anda à mão
	var area_real := Rect2(130, 73, 368, 207)
	# A câmara sob a luz rosa: o sintoma fica escondido.
	_abrir("mofo")
	_passo(0.5)
	await _salvar(pasta, "planta_rosa.png")
	# Cada problema sob a luz verde, e o "pior" de cada (a sacudida e depois o sintoma que cresce).
	for nome: String in Planta.PROBLEMAS:
		_abrir(nome)
		_g.acender_luz()
		_passo(0.6)
		await _salvar(pasta, "planta_%s.png" % nome)
		_g.usar(ERRO[nome])
		_passo(0.15)
		await _salvar(pasta, "planta_%s_pior_sacode.png" % nome)
		_passo(0.5)
		await _salvar(pasta, "planta_%s_pior.png" % nome)
	# Uma ferramenta em ação (a tesoura no mofo) e o crescimento, passo a passo, até o fim.
	_abrir("mofo")
	_g.acender_luz()
	_passo(0.5)
	_g.usar("tesoura")
	_passo(0.22)
	await _salvar(pasta, "planta_mofo_tesoura.png")
	_passo(0.4)
	_g.usar("ventilador")
	_passo(0.1)
	await _salvar(pasta, "planta_acerto.png")
	_passo(0.25 + 0.5)
	await _salvar(pasta, "planta_crescendo.png")
	_passo(1.5)
	await _salvar(pasta, "planta_fim.png")
	# A área real da estação (368×207) e a menor dos testes (320×180).
	_abrir("encharcada", area_real)
	await _salvar(pasta, "planta_368x207_rosa.png")
	_g.acender_luz()
	_passo(0.6)
	await _salvar(pasta, "planta_368x207_encharcada.png")
	_g.usar("ventilador")
	_passo(0.25 + 2.0)
	await _salvar(pasta, "planta_368x207_fim.png")
	_abrir("seca", Rect2(0, 0, 320, 180))
	_g.acender_luz()
	_passo(0.6)
	await _salvar(pasta, "planta_320x180_seca.png")
	get_tree().quit()
