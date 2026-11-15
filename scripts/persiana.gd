extends TextureRect
## Persiana da janela. Este nó é a camada da persiana, acima do Panorama da Sala e abaixo das
## Telas (a persiana fica na frente da moldura e cobre também o montante e as bordas da janela).
## O shader dele mostra só as primeiras N lâminas. Quem manda é o estado da sala: fechar ao entrar
## no abrigo, abrir ao sair. Aqui moram o progresso (0 a 1), o cross-fade da luz e os sons.
##
## Fechar vai de 0 a 1 e abrir, de 1 a 0. Sempre uma lâmina inteira por vez (pixel art, sem meia
## lâmina), de cima para baixo; a conta está em laminas_visiveis(). Cada lâmina que aparece ou some
## dá uma batida, e a última cai no fim exato da animação, junto do som do fecho.

signal mudou  # o progresso ou o fim da animação mudaram (a sonda lê)

const N_LAMINAS := 10
const DURACAO_PADRAO := 1.5
const DURACAO_MIN := 0.5
const DURACAO_MAX := 3.0
const Som := preload("res://scripts/som.gd")
const SOM_LAMINA := preload("res://assets/sons/persiana_lamina.ogg")
const SOM_FECHO := preload("res://assets/sons/persiana_fecho.ogg")
const VOLUME_DB := -4.0  # de todos os sons da persiana, em relação ao volume geral do barramento SFX (som.gd)
const VOLUME_BATIDA_DB := -7.0  # das batidas por lâmina, em relação à trava e ao fecho
const PITCH_MIN := 0.9
const PITCH_MAX := 1.1
const PICO_DO_FECHO_S := 0.12  # o pico de persiana_fecho.ogg está a 0,12 s do começo

var duracao := DURACAO_PADRAO
var progresso := 0.0
var animando := false

var _panorama: TextureRect
var _anterior: TextureRect
var _fechando := false
var _laminas := 0
var _tween: Tween
var _tocador: AudioStreamPlayer
var _som: AudioStreamPlaybackPolyphonic


## Quantas lâminas aparecem com o progresso p. Fechando, a k-ésima aparece em p = k/10; abrindo, a
## k-ésima some em p = (k-1)/10, e com p = 1 aparecem todas.
static func laminas_visiveis(p: float, fechando: bool) -> int:
	if fechando:
		return clampi(floori(p * N_LAMINAS + 1e-6), 0, N_LAMINAS)
	return clampi(ceili(p * N_LAMINAS - 1e-6), 0, N_LAMINAS)


## Duração pedida na URL (?persiana=<s>): vale de 0,5 a 3,0 s; fora disso ou ausente, o padrão.
static func duracao_da_url(valor: Variant) -> float:
	var s := float(valor) if valor != null else 0.0
	return s if s >= DURACAO_MIN and s <= DURACAO_MAX else DURACAO_PADRAO


## panorama: o TextureRect da sala; anterior: o que fica por baixo dele durante o cross-fade.
func configurar(panorama: TextureRect, anterior: TextureRect, duracao_s: float) -> void:
	_panorama = panorama
	_anterior = anterior
	duracao = duracao_s
	_anterior.visible = false
	_aplicar(0.0)
	Som.garantir_barramento()
	_tocador = AudioStreamPlayer.new()
	_tocador.bus = Som.BARRAMENTO
	_tocador.stream = AudioStreamPolyphonic.new()
	_tocador.max_polyphony = 16
	add_child(_tocador)
	_tocador.play()
	_som = _tocador.get_stream_playback()


## Se a persiana está (ou está indo para) fechada.
func fechada() -> bool:
	return _fechando


## Começa a animação para fechada/aberta, com cross-fade do panorama atual para `nova`. Uma animação
## em curso termina na hora antes da nova começar.
func ir_para(fechar: bool, nova: Texture2D) -> void:
	_concluir()
	_fechando = fechar
	_anterior.texture = _panorama.texture
	_anterior.visible = true
	_panorama.texture = nova
	_panorama.modulate.a = 0.0
	animando = true
	var de := progresso
	var para := 1.0 if fechar else 0.0
	var dur := duracao * absf(para - de)
	if not fechar:
		_tocar_destaque(SOM_LAMINA)
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(_aplicar, de, para, dur)
	_tween.tween_property(_panorama, "modulate:a", 1.0, dur)
	if fechar:
		_tween.tween_callback(_tocar_destaque.bind(SOM_FECHO)).set_delay(maxf(dur - PICO_DO_FECHO_S, 0.0))
	_tween.chain().tween_callback(_concluir)
	mudou.emit()


## Para a animação no ponto final.
func _concluir() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	if not animando:
		return
	animando = false
	_aplicar(1.0 if _fechando else 0.0, false)
	_panorama.modulate.a = 1.0
	_anterior.visible = false
	mudou.emit()


func _aplicar(p: float, com_som := true) -> void:
	progresso = p
	var n := laminas_visiveis(p, _fechando)
	if n != _laminas and com_som and animando:
		_tocar_batida()
	_laminas = n
	(material as ShaderMaterial).set_shader_parameter("laminas", n)
	mudou.emit()


func laminas() -> int:
	return _laminas


func _tocar_batida() -> void:
	_som.play_stream(SOM_LAMINA, 0.0, VOLUME_DB + VOLUME_BATIDA_DB, randf_range(PITCH_MIN, PITCH_MAX),
		AudioServer.PLAYBACK_TYPE_DEFAULT, Som.BARRAMENTO)


func _tocar_destaque(som: AudioStream) -> void:
	_som.play_stream(som, 0.0, VOLUME_DB, 1.0, AudioServer.PLAYBACK_TYPE_DEFAULT, Som.BARRAMENTO)
