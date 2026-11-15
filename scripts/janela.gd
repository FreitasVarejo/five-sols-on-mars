extends TextureRect
## A vista da janela (nó Sala/Vista), atrás do panorama da sala. Mostra a vista normal ou a de poeira
## (cross-fade de FADE_POEIRA_S) e a hora do dia (dia, pôr do Sol azulado, noite), as duas pelo shader
## shaders/janela.gdshader. O Sol como relógio: o turno anda de 0 a 1 e a janela acompanha.
##
## O mesmo relógio dá a luz da sala (fator `luz`, de 0 a 1): nos últimos ~10 s do turno a sala fica
## azulada, sem piscar. Quem aplica é este script, em `self_modulate` dos nós de `configurar_luz`
## (não em `modulate`: persiana.gd anima o `modulate.a` do panorama).
## As funções estáticas (hora_da_fase, luz_da_fase) são puras e ficam testadas em tests/test_janela.gd.

const SHADER := preload("res://shaders/janela.gdshader")
const VISTA_POEIRA := preload("res://assets/exterior/vista_janela_poeira.png")
const FADE_POEIRA_S := 1.5
const VELOCIDADE_HORA := 0.8  # a hora exibida anda no máximo isto por segundo (a hora-alvo salta ao mudar de fase)
const SEGUNDOS_DE_POR_DO_SOL := 10.0  # a luz da sala fica azulada nos últimos ~10 s do turno
const LUZ_FRIA := Color(0.66, 0.74, 0.98)

## Hora do dia mostrada, de 0 (dia) a 1 (noite), e a mistura da vista de poeira (0 normal, 1 poeira).
var hora := 0.0
var mistura := 0.0
## Fator da luz da sala, de 0 (branca) a 1 (fria).
var luz := 0.0

var _alvos: Array[CanvasItem] = []
var _poeira_alvo := 0.0
var _hora_alvo := 0.0
var _primeira := true
var _hora_logica := 0.0  # a hora de hora_da_fase (a exibida segue ela)


## Hora do dia, de 0 a 1, para a fase da tela. "turno": o relógio do turno; "plano": 0 (amanhecer);
## "fim_do_sol", "noite" e "relatorio": 1; qualquer outra fase (por exemplo "seguranca"): `anterior`.
static func hora_da_fase(fase_ui: String, relogio: float, anterior: float) -> float:
	match fase_ui:
		"turno":
			return relogio
		"plano":
			return 0.0
		"fim_do_sol", "noite", "relatorio":
			return 1.0
	return anterior


## Fator da luz fria da sala, de 0 a 1. No turno sobe suave nos últimos 10 s (`turno_s` é a duração
## do turno); no fim do sol, na noite e no relatório vale 1; no plano, 0; nas outras fases, `anterior`.
static func luz_da_fase(fase_ui: String, relogio: float, turno_s: float, anterior: float) -> float:
	match fase_ui:
		"turno":
			return smoothstep(1.0 - SEGUNDOS_DE_POR_DO_SOL / maxf(turno_s, 0.001), 1.0, relogio)
		"plano":
			return 0.0
		"fim_do_sol", "noite", "relatorio":
			return 1.0
	return anterior


func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("vista_poeira", VISTA_POEIRA)
	material = mat


## Os nós que recebem a luz fria da sala em self_modulate (panorama, panorama anterior e persiana).
func configurar_luz(alvos: Array[CanvasItem]) -> void:
	_alvos = alvos


## Uma vez por quadro: a hora e a luz saem da fase da tela e do relógio do turno.
func acompanhar(fase_ui: String, relogio: float, turno_s: float, poeira: bool) -> void:
	_hora_logica = hora_da_fase(fase_ui, relogio, _hora_logica)
	luz = luz_da_fase(fase_ui, relogio, turno_s, luz)
	atualizar(poeira, _hora_logica)
	for alvo in _alvos:
		alvo.self_modulate = Color.WHITE.lerp(LUZ_FRIA, luz)


## A vista de poeira (ou a normal) e a hora do dia (0 a 1). A primeira chamada vale direto, sem fade.
func atualizar(poeira: bool, hora_nova: float) -> void:
	_poeira_alvo = 1.0 if poeira else 0.0
	_hora_alvo = clampf(hora_nova, 0.0, 1.0)
	if _primeira:
		_primeira = false
		mistura = _poeira_alvo
		hora = _hora_alvo
		_aplicar()


func _process(delta: float) -> void:
	if _primeira:
		return
	var antes := mistura
	var hora_antes := hora
	mistura = move_toward(mistura, _poeira_alvo, delta / FADE_POEIRA_S)
	hora = move_toward(hora, _hora_alvo, delta * VELOCIDADE_HORA)
	if mistura != antes or hora != hora_antes:
		_aplicar()


func _aplicar() -> void:
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("mistura", mistura)
	mat.set_shader_parameter("hora", hora)
