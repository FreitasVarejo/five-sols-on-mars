extends Control
## Câmera em primeira pessoa: pan horizontal da Sala; a curvatura vem do shader
## em Distorcao (acima da Sala, abaixo do HUD).

const VELOCIDADE_BORDA := 600.0  # px/s, no limite da tela
const VELOCIDADE_SETA := 400.0  # px/s, seta pressionada
const ALTURA_BOTAO_Y := 180.0  # centro vertical do BotaoCentro no panorama
const LADO_BOTAO := 64.0

@onready var _sala: Control = $Sala
@onready var _panorama: TextureRect = $Sala/Panorama
@onready var _botao_centro: TextureButton = $Sala/BotaoCentro
@onready var _seta_esq: TextureButton = $HUD/SetaEsquerda
@onready var _seta_dir: TextureButton = $HUD/SetaDireita
@onready var _depuracao: Label = $HUD/Depuracao

var _pan := 0.0
var _pan_inteiro := 0
var _cliques := 0
var _esq_pressionada := false
var _dir_pressionada := false
var _mouse_x := 0.0
# O pan por posição só vale com mouse de verdade e com o mouse dentro da janela.
var _mouse_real := false
var _mouse_dentro := true


func _ready() -> void:
	_aplicar_stretch_da_url()

	var tamanho := _panorama.texture.get_size()
	_panorama.size = tamanho
	_sala.size = tamanho
	_botao_centro.size = Vector2(LADO_BOTAO, LADO_BOTAO)
	_botao_centro.position = Vector2(roundf(tamanho.x / 2.0) - LADO_BOTAO / 2.0, ALTURA_BOTAO_Y - LADO_BOTAO / 2.0)

	_seta_esq.button_down.connect(func() -> void: _esq_pressionada = true)
	_seta_esq.button_up.connect(func() -> void: _esq_pressionada = false)
	_seta_dir.button_down.connect(func() -> void: _dir_pressionada = true)
	_seta_dir.button_up.connect(func() -> void: _dir_pressionada = false)
	_botao_centro.pressed.connect(_ao_clicar_botao_centro)

	_pan = _alcance() / 2.0
	_pan_inteiro = roundi(_pan)
	_sala.position.x = -_pan_inteiro
	_atualizar_depuracao()
	# Espera um frame: depois de trocar o content_scale_mode, o tamanho da
	# textura do viewport só vale no frame seguinte.
	await get_tree().process_frame
	_sonda_teste()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_mouse_real = false
	elif event is InputEventMouse:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			_mouse_real = false  # mouse emulado a partir de toque
		elif event is InputEventMouseMotion:
			_mouse_real = true
			_mouse_x = event.position.x


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse_dentro = false
	elif what == NOTIFICATION_WM_MOUSE_ENTER:
		_mouse_dentro = true


func _process(delta: float) -> void:
	var velocidade := _velocidade_seta() if (_esq_pressionada or _dir_pressionada) else _velocidade_mouse()
	if velocidade != 0.0:
		_pan = clampf(_pan + velocidade * delta, 0.0, _alcance())
	var novo := roundi(_pan)
	_sala.position.x = -novo
	if novo != _pan_inteiro:
		_pan_inteiro = novo
		_sonda_teste()
	_atualizar_depuracao()


## Alcance do pan: largura da textura menos a largura visível da tela.
func _alcance() -> float:
	return maxf(0.0, _panorama.texture.get_size().x - get_viewport_rect().size.x)


func _velocidade_seta() -> float:
	return (int(_dir_pressionada) - int(_esq_pressionada)) * VELOCIDADE_SETA


## Zonas de borda de 1/3 da tela; a velocidade cresce da fronteira (0) até a borda.
func _velocidade_mouse() -> float:
	if not (_mouse_real and _mouse_dentro):
		return 0.0
	var largura := get_viewport_rect().size.x
	var zona := largura / 3.0
	var x := clampf(_mouse_x, 0.0, largura)
	if x < zona:
		return -VELOCIDADE_BORDA * (zona - x) / zona
	if x > largura - zona:
		return VELOCIDADE_BORDA * (x - (largura - zona)) / zona
	return 0.0


func _ao_clicar_botao_centro() -> void:
	_cliques += 1
	_sonda_teste()


func _nome_do_modo() -> String:
	match get_tree().root.content_scale_mode:
		Window.CONTENT_SCALE_MODE_VIEWPORT:
			return "viewport"
		Window.CONTENT_SCALE_MODE_CANVAS_ITEMS:
			return "canvas_items"
	return "disabled"


## Resolução em que o shader roda: 640x360 em viewport; a da janela em canvas_items.
## (get_viewport().get_texture().get_size() reporta 3x a janela em canvas_items,
## sem que nada desse tamanho seja alocado; por isso não serve aqui.)
func _resolucao_do_shader() -> Vector2i:
	if get_tree().root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS:
		return get_tree().root.size
	return get_tree().root.content_scale_size


func _atualizar_depuracao() -> void:
	var res := _resolucao_do_shader()
	_depuracao.text = "stretch: %s\nshader em: %dx%d\npan: %d / %d\ncliques: %d" % [
		_nome_do_modo(), res.x, res.y, _pan_inteiro, roundi(_alcance()), _cliques]


## No Web, lê ?stretch=viewport|canvas_items e aplica em content_scale_mode.
## Sem parâmetro (ou valor desconhecido) vale o project.godot.
func _aplicar_stretch_da_url() -> void:
	if not OS.has_feature("web"):
		return
	var valor = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('stretch')", true)
	match valor:
		"viewport":
			get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		"canvas_items":
			get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS


## SONDA DE TESTE (só Web): expõe o estado em window.fsom para o Playwright.
func _sonda_teste() -> void:
	if not OS.has_feature("web"):
		return
	var res := _resolucao_do_shader()
	var estado := {"cliques": _cliques, "pan": _pan_inteiro, "modo": _nome_do_modo(), "shader_em": [res.x, res.y]}
	JavaScriptBridge.eval("window.fsom = %s;" % JSON.stringify(estado), true)
