extends Node
## A trilha do jogo: uma faixa por momento, no barramento Musica (bem abaixo dos efeitos; o volume é
## Som.VOLUME_MUSICA_DB e o mudo é o do Som). A main pede a faixa de cada quadro (pedir); a troca é um
## crossfade de FADE_S, e pedir a faixa que já toca não a reinicia.
##
## Quem escolhe a faixa é faixa_do_estado, uma função pura (estado do jogo -> nome da faixa).
## A vinheta do relatório toca uma vez; quando acaba, entra a calma sozinha.
##
## O fade é feito aqui, a cada quadro (avancar), e não por Tween: o teste dirige o tempo à mão.

const Som := preload("res://scripts/som.gd")

const FAIXAS := {
	"calma": preload("res://assets/musica/musica_calma.ogg"),
	"tensa": preload("res://assets/musica/musica_tensa.ogg"),
	"turno": preload("res://assets/musica/musica_turno.ogg"),
	"relatorio": preload("res://assets/musica/musica_relatorio.ogg"),  # vinheta de 4,6 s, não faz loop
}
const FADE_S := 1.5
const SILENCIO_DB := -80.0

## A faixa de cada momento ("" é silêncio). `tela` é a da main ("inicio", "viagem", "abertura", "pagina" ou
## "jogo"); `fase_ui` é a do terminal. Só no jogo a fase manda: o turno é "turno", e vira "tensa" com a
## tempestade em curso (Missao.tempestade_em_curso) ou com a criança abrigada. O modo de segurança cala.
static func faixa_do_estado(tela: String, fase_ui: String, tempestade: bool, abrigado: bool) -> String:
	if tela != "jogo":
		return "calma"
	match fase_ui:
		"seguranca":
			return ""
		"relatorio":
			return "relatorio"
		"turno":
			return "tensa" if (tempestade or abrigado) else "turno"
		_:
			return "calma"

## A faixa que está entrando (ou já tocando) e a última que a main pediu. Diferem na vinheta: depois dela
## `atual` é "calma" e `pedida` segue "relatorio", para o pedido repetido de cada quadro não a refazer.
var atual := ""
var pedida := ""
## Quantas trocas houve e quais foram, as últimas (a sonda de teste lê).
var trocas := 0
var historico: Array = []

var _tempo := 0.0  # segundos desde que `atual` começou
var _tocadores: Array[AudioStreamPlayer] = []
var _faixa: Array[String] = ["", ""]  # o que cada tocador tem
var _nivel: Array[float] = [0.0, 0.0]  # 0 a 1, o fade de cada tocador
var _vivo := -1  # o tocador de `atual` (-1: silêncio)


func _ready() -> void:
	Som.garantir_barramento()
	for i in 2:
		var t := AudioStreamPlayer.new()
		t.bus = Som.BARRAMENTO_MUSICA
		t.volume_db = SILENCIO_DB
		add_child(t)
		_tocadores.append(t)


func _process(delta: float) -> void:
	avancar(delta)


## Pede a faixa `nome` ("" é silêncio). Igual ao último pedido: não faz nada.
func pedir(nome: String) -> void:
	if nome == pedida:
		return
	pedida = nome
	_trocar(nome)


## Passa `delta` segundos: o fade das faixas e o fim da vinheta.
func avancar(delta: float) -> void:
	_tempo += delta
	if atual == "relatorio" and _tempo >= FAIXAS["relatorio"].get_length():
		_trocar("calma")
	for i in _tocadores.size():
		var alvo := 1.0 if i == _vivo else 0.0
		_nivel[i] = move_toward(_nivel[i], alvo, delta / FADE_S)
		_tocadores[i].volume_db = SILENCIO_DB if _nivel[i] <= 0.0 else maxf(linear_to_db(_nivel[i]), SILENCIO_DB)
		if _nivel[i] <= 0.0 and i != _vivo and _tocadores[i].playing:
			_tocadores[i].stop()
			_faixa[i] = ""


func _trocar(nome: String) -> void:
	if nome == atual:
		return
	atual = nome
	_tempo = 0.0
	trocas += 1
	historico.append(nome)
	if historico.size() > Som.MAX_HISTORICO:
		historico.pop_front()
	var antigo := _vivo
	_vivo = -1
	if nome == "" or _tocadores.is_empty():
		return
	# O tocador que não é o da faixa que sai (se ele ainda fazia fade, é cortado).
	_vivo = 1 if antigo == 0 else 0
	var t := _tocadores[_vivo]
	t.stop()
	t.stream = FAIXAS[nome]
	_faixa[_vivo] = nome
	_nivel[_vivo] = 0.0
	t.volume_db = SILENCIO_DB
	t.play()


## O que a sonda de teste lê: a faixa de agora, a última pedida, as trocas e o que cada tocador faz.
func estado() -> Dictionary:
	var tocando := []
	for i in _tocadores.size():
		tocando.append({"faixa": _faixa[i], "toca": _tocadores[i].playing, "nivel": _nivel[i], "bus": String(_tocadores[i].bus)})
	return {"atual": atual, "pedida": pedida, "trocas": trocas, "historico": historico, "tocadores": tocando}
