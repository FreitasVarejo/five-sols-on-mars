extends Control
## Câmera em primeira pessoa: pan horizontal da Sala; a curvatura vem do shader
## em Distorcao (acima da Sala, abaixo do HUD).
##
## Cliques e shader: o shader só desloca a imagem na vertical, por um fator
## que depende da coluna da tela (zero no meio, máximo nas bordas). Os nós da
## Sala não sabem disso, então o clique é resolvido aqui: a posição do mouse na
## tela vira posição no panorama pela mesma fórmula do shader (_tela_para_panorama),
## e só então é comparada com os retângulos de regioes.json. O realce de hover e
## as telas de barras ficam na Sala (antes do shader) e curvam junto com a arte;
## os contornos de depuração (tecla D) são desenhados no HUD, depois do shader,
## a partir da fórmula direta, para conferir o alinhamento.

const VELOCIDADE_BORDA := 600.0  # px/s, no limite da tela
const VELOCIDADE_SETA := 400.0  # px/s, seta pressionada
const JSON_REGIOES := "res://assets/comodo/regioes.json"
const DadosDonki := preload("res://scripts/dados_donki.gd")

const PANORAMAS := {
	"normal": preload("res://assets/comodo/normal.png"),
	"tempestade": preload("res://assets/comodo/tempestade.png"),
	"abrigo": preload("res://assets/comodo/abrigo.png"),
	"modo_seguranca": preload("res://assets/comodo/modo_seguranca.png"),
}
const ORDEM_ESTADOS := ["normal", "tempestade", "abrigo", "modo_seguranca"]
# Vista de Marte pela janela: fica atrás do panorama (o vidro dele tem alpha 0, menos no
# abrigo, em que a persiana cobre). A vista é independente do estado da sala: P alterna.
const VISTAS := {
	"normal": preload("res://assets/exterior/vista_janela_normal.png"),
	"poeira": preload("res://assets/exterior/vista_janela_poeira.png"),
}
# Valores de teste das telas: nome, ícone, valor, máximo, cor.
const TELAS := {
	"energia": ["ENERGIA", "energia", 9, 12, Color("#f2b631")],
	"oxigenio": ["OXIGÊNIO", "oxigenio", 6, 8, Color("#5fc8e8")],
	"radiacao": ["RADIAÇÃO", "radiacao", 3, 5, Color("#7ed957")],
}
# Tela de comunicação com a Terra: por enquanto só apagada, na cor única das telas em branco.
const COR_TELA_APAGADA := Color("#202e37")

@onready var _sala: Control = $Sala
@onready var _vista_janela: TextureRect = $Sala/Vista
@onready var _panorama: TextureRect = $Sala/Panorama
@onready var _telas: Control = $Sala/Telas
@onready var _realce: Control = $Sala/Realce
@onready var _distorcao: ColorRect = $Distorcao
@onready var _seta_esq: TextureButton = $HUD/SetaEsquerda
@onready var _seta_dir: TextureButton = $HUD/SetaDireita
@onready var _depuracao: Label = $HUD/Depuracao
@onready var _contornos: Control = $HUD/Contornos

var _botoes := {}  # nome -> Rect2 no panorama (o que se clica)
var _regioes_telas := {}  # nome -> Rect2 no panorama (telas: só para os contornos de depuração)
var _donki := {}  # dado do DONKI embutido (dados_donki.gd), só para verificação
var _pan := 0.0
var _pan_inteiro := 0
var _cliques := 0
var _ultimo_clique := ""
var _hover := ""
var _estado := "normal"
var _estado_antes_do_abrigo := "normal"
var _vista := "normal"
var _depurar := false
var _esq_pressionada := false
var _dir_pressionada := false
var _mouse_pos := Vector2.ZERO
# O pan por posição só vale com mouse de verdade e com o mouse dentro da janela.
var _mouse_real := false
var _mouse_dentro := true


func _ready() -> void:
	_aplicar_stretch_da_url()
	_depuracao.hide()
	_donki = DadosDonki.carregar()
	_carregar_regioes()

	var tamanho := _panorama.texture.get_size()
	_panorama.size = tamanho
	_vista_janela.size = tamanho
	_sala.size = tamanho
	_telas.size = tamanho
	_realce.size = tamanho
	_realce.draw.connect(_desenhar_realce)
	_contornos.draw.connect(_desenhar_contornos)

	_seta_esq.button_down.connect(func() -> void: _esq_pressionada = true)
	_seta_esq.button_up.connect(func() -> void: _esq_pressionada = false)
	_seta_dir.button_down.connect(func() -> void: _dir_pressionada = true)
	_seta_dir.button_up.connect(func() -> void: _dir_pressionada = false)

	_pan = _alcance() / 2.0
	_pan_inteiro = roundi(_pan)
	_sala.position.x = -_pan_inteiro
	_atualizar_depuracao()
	# Espera um frame: depois de trocar o content_scale_mode, o tamanho da
	# textura do viewport só vale no frame seguinte.
	await get_tree().process_frame
	_sonda_teste()


## Lê regioes.json: os botões clicáveis e as telas (barras e comunicação).
func _carregar_regioes() -> void:
	var dados = JSON.parse_string(FileAccess.get_file_as_string(JSON_REGIOES))
	assert(dados is Dictionary, "regioes.json não carregou")
	for nome: String in dados["botoes"]:
		_botoes[nome] = _rect(dados["botoes"][nome])

	for nome: String in dados["telas"]:
		_regioes_telas[nome] = _rect(dados["telas"][nome])

	for nome: String in TELAS:
		var t: Array = TELAS[nome]
		var tela: Control = preload("res://scripts/tela_barra.gd").new()
		var r := _rect(dados["telas"][nome])
		tela.position = r.position
		tela.size = r.size
		tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tela.nome = t[0]
		tela.icone = t[1]
		tela.valor = t[2]
		tela.maximo = t[3]
		tela.cor = t[4]
		_telas.add_child(tela)

	var comunicacao := ColorRect.new()
	var rc: Rect2 = _regioes_telas["comunicacao"]
	comunicacao.position = rc.position
	comunicacao.size = rc.size
	comunicacao.color = COR_TELA_APAGADA
	comunicacao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_telas.add_child(comunicacao)


func _rect(d: Dictionary) -> Rect2:
	return Rect2(d["x"], d["y"], d["w"], d["h"])


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_mouse_real = false
	elif event is InputEventMouse:
		_mouse_pos = event.position
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			_mouse_real = false  # mouse emulado a partir de toque
		elif event is InputEventMouseMotion:
			_mouse_real = true


## Só chega aqui o que nenhum Control (as setas) consumiu.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var nome := _regiao_em(event.position)
		if nome != "":
			_ao_clicar(nome)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4:
				_definir_estado(ORDEM_ESTADOS[event.keycode - KEY_1])
			KEY_P:
				_definir_vista("poeira" if _vista == "normal" else "normal")
			KEY_D:
				_depurar = not _depurar
				_contornos.visible = _depurar
				_depuracao.visible = _depurar
				_sonda_teste()


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
	var mudou := novo != _pan_inteiro
	_pan_inteiro = novo

	var hover := _regiao_em(_mouse_pos) if (_mouse_real and _mouse_dentro) else ""
	if hover != _hover:
		_hover = hover
		_realce.queue_redraw()
		mudou = true
	if mudou:
		_sonda_teste()
	if _depurar:
		_contornos.queue_redraw()
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
	var x := clampf(_mouse_pos.x, 0.0, largura)
	if x < zona:
		return -VELOCIDADE_BORDA * (zona - x) / zona
	if x > largura - zona:
		return VELOCIDADE_BORDA * (x - (largura - zona)) / zona
	return 0.0


# --- geometria do shader --------------------------------------------------

func _zoom() -> float:
	return float((_distorcao.material as ShaderMaterial).get_shader_parameter("zoom"))


## Fator vertical do shader (fC) na coluna x da tela. Mesma conta de panorama.gdshader.
func _fator(x_tela: float) -> float:
	var fb := 1.0 - _zoom() * 0.0015
	var u := x_tela / get_viewport_rect().size.x
	return maxf(0.02, 1.0 + (fb - 1.0) * 4.0 * pow(u - 0.5, 2.0))


## Onde, no panorama, está o que aparece no ponto p da tela.
func _tela_para_panorama(p: Vector2) -> Vector2:
	var meio := get_viewport_rect().size.y / 2.0
	return Vector2(p.x + _pan_inteiro, meio + (p.y - meio) * _fator(p.x))


## Onde, na tela, aparece o ponto q do panorama.
func _panorama_para_tela(q: Vector2) -> Vector2:
	var meio := get_viewport_rect().size.y / 2.0
	var x := q.x - _pan_inteiro
	return Vector2(x, meio + (q.y - meio) / _fator(x))


## Nome do botão sob o ponto p da tela ("" se nenhum). As setas tapam.
func _regiao_em(p: Vector2) -> String:
	for seta in [_seta_esq, _seta_dir]:
		if seta.is_visible_in_tree() and seta.get_global_rect().has_point(p):
			return ""
	var q := _tela_para_panorama(p)
	for nome: String in _botoes:
		if _botoes[nome].has_point(q):
			return nome
	return ""


# --- desenho -----------------------------------------------------------------

## Na Sala, antes do shader: o realce curva junto com a arte.
func _desenhar_realce() -> void:
	if _hover == "":
		return
	var r: Rect2 = _botoes[_hover]
	_realce.draw_rect(r, Color(1, 1, 1, 0.22))
	_realce.draw_rect(r, Color(1, 1, 1, 0.6), false, 1.0)


## No HUD, depois do shader: o contorno do que é clicável (magenta) e o das telas (ciano), pela
## fórmula direta.
func _desenhar_contornos() -> void:
	for nome: String in _botoes:
		var cor := Color(1, 0.2, 1) if nome != _hover else Color(1, 1, 0)
		_contornos.draw_polyline(_contorno_na_tela(_botoes[nome]), cor, 1.0)
	for nome: String in _regioes_telas:
		_contornos.draw_polyline(_contorno_na_tela(_regioes_telas[nome]), Color(0, 1, 1), 1.0)


func _contorno_na_tela(r: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var passo := 4.0
	var x := r.position.x
	while x < r.end.x:
		pts.append(_panorama_para_tela(Vector2(x, r.position.y)))
		x += passo
	pts.append(_panorama_para_tela(Vector2(r.end.x, r.position.y)))
	pts.append(_panorama_para_tela(Vector2(r.end.x, r.end.y)))
	x = r.end.x
	while x > r.position.x:
		pts.append(_panorama_para_tela(Vector2(x, r.end.y)))
		x -= passo
	pts.append(_panorama_para_tela(Vector2(r.position.x, r.end.y)))
	pts.append(pts[0])
	return pts


# --- ações -------------------------------------------------------------------

func _ao_clicar(nome: String) -> void:
	_cliques += 1
	_ultimo_clique = nome
	match nome:
		"abrigo":
			if _estado == "abrigo":
				_definir_estado(_estado_antes_do_abrigo)
			else:
				_estado_antes_do_abrigo = _estado
				_definir_estado("abrigo")
		"estufa", "glovebox":
			print("clique: ", nome)  # o jogo vem na próxima fatia: por ora só registra
	_sonda_teste()


func _definir_estado(estado: String) -> void:
	_estado = estado
	_panorama.texture = PANORAMAS[estado]
	_sonda_teste()


func _definir_vista(vista: String) -> void:
	_vista = vista
	_vista_janela.texture = VISTAS[vista]
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
	if not _depurar:
		return
	var res := _resolucao_do_shader()
	_depuracao.text = "stretch: %s\nshader em: %dx%d zoom %d\npan: %d / %d\nestado: %s  hover: %s\ncliques: %d (%s)\n%s" % [
		_nome_do_modo(), res.x, res.y, int(_zoom()), _pan_inteiro, roundi(_alcance()),
		_estado, _hover, _cliques, _ultimo_clique, DadosDonki.resumo(_donki)]


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
	var estado := {
		"cliques": _cliques, "ultimo_clique": _ultimo_clique, "pan": _pan_inteiro,
		"modo": _nome_do_modo(), "shader_em": [res.x, res.y], "zoom": _zoom(),
		"estado": _estado, "vista": _vista,
		"hover": _hover, "depurar": _depurar,
		"donki": {
			"historico": _donki["historico"], "chegadas": _donki["chegadas_marte"].size(),
			"coletado_em": _donki.get("coletado_em"), "motivo_historico": _donki.get("motivo_historico"),
			"texto": DadosDonki.resumo(_donki),
		},
	}
	JavaScriptBridge.eval("window.fsom = %s;" % JSON.stringify(estado), true)
