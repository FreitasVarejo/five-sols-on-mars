extends Node
## Som do jogo: o barramento SFX, o volume geral, o mudo e os sons do terminal e dos cliques.
##
## Todo player de som do jogo toca no barramento SFX (a persiana inclusive, que mantém o -4 dB
## relativo dela). O volume geral é VOLUME_GERAL_DB, aplicado ao barramento; o mudo é o mute dele.
##
## O mudo fica guardado no navegador (localStorage, só no Web). Fora do Web, ou se o acesso falhar,
## o jogo segue sem mudo guardado: vale só na sessão.
##
## Cada clique tem um peso (navegar, confirmar, abrigo), escolhido pelo nome da ação do terminal ou da
## sala (clique_da_acao). O botão do terminal, as setas e o mudo não fazem clique.

const BARRAMENTO := &"SFX"
const VOLUME_GERAL_DB := 0.0   # o único botão de volume do jogo; a persiana tem o -4 dB dela por cima
const CHAVE_MUDO := "five-sols-on-mars.mudo"
const MAX_HISTORICO := 40

const SONS := {
	"clique_navegar": preload("res://assets/sons/clique_navegar.ogg"),
	"clique_confirmar": preload("res://assets/sons/clique_confirmar.ogg"),
	"clique_abrigo": preload("res://assets/sons/clique_abrigo.ogg"),
	"terminal_sobe": preload("res://assets/sons/terminal_sobe.ogg"),
	"terminal_desce": preload("res://assets/sons/terminal_desce.ogg"),
	"desligar": preload("res://assets/sons/desligar.ogg"),
	"alarme": preload("res://assets/sons/alarme.ogg"),  # o medidor passou do limiar de abrigo (terminal.gd)
	"viagem_ignicao": preload("res://assets/sons/viagem_ignicao.ogg"),  # o foguete parte, no começo da viagem (viagem.gd)
	"viagem_pouso": preload("res://assets/sons/viagem_pouso.ogg"),  # o baque do pouso, junto do flash (viagem.gd)
	# A estufa (minigames/cultivar_planta.gd): a luz verde, as três ferramentas, o retorno e o acerto final.
	"estufa_luz": preload("res://assets/sons/estufa_luz.ogg"),
	"estufa_regar": preload("res://assets/sons/estufa_regar.ogg"),
	"estufa_ventilar": preload("res://assets/sons/estufa_ventilar.ogg"),
	"estufa_cortar": preload("res://assets/sons/estufa_cortar.ogg"),
	"estufa_melhorou": preload("res://assets/sons/estufa_melhorou.ogg"),
	"estufa_piorou": preload("res://assets/sons/estufa_piorou.ogg"),
	"estufa_ploc": preload("res://assets/sons/estufa_ploc.ogg"),
}

## Ação -> clique. Ação que não está aqui não faz som (o botão do terminal, por exemplo).
const CLIQUE_DA_ACAO := {
	"aba_cameras": "clique_navegar", "aba_tarefas": "clique_navegar", "aba_diario": "clique_navegar",
	"aba_fontes": "clique_navegar", "voltar_plano": "clique_navegar", "fechar_card": "clique_navegar",
	"o2_menos": "clique_navegar", "o2_mais": "clique_navegar", "tarefa_chemcam": "clique_navegar",
	"tarefa_amostra": "clique_navegar", "tarefa_planta": "clique_navegar",
	"confirmar": "clique_confirmar", "enviar": "clique_confirmar", "iniciar_chemcam": "clique_confirmar",
	"consertar_gerador": "clique_confirmar", "reiniciar": "clique_confirmar", "seguir": "clique_confirmar",
	"jogar_de_novo": "clique_confirmar", "estufa": "clique_confirmar", "glovebox": "clique_confirmar",
	"abrigo": "clique_abrigo", "ir_ao_abrigo": "clique_navegar", "ir_chemcam": "clique_navegar", "ir_gerador": "clique_navegar",
	"porta": "clique_confirmar",
	"card_confirmar": "clique_confirmar", "card_cancelar": "clique_navegar",
}

## O que a sonda de teste lê: os nomes dos últimos sons pedidos (mesmo com o mudo ligado) e a contagem.
var historico: Array = []
var total := 0

var _tocador: AudioStreamPlayer
var _playback: AudioStreamPlaybackPolyphonic


## Aplica o volume geral ao barramento SFX e devolve o índice dele. O barramento vem do
## default_bus_layout.tres: criado só em tempo de execução, o Web (modo sample) perde o caminho até a
## saída e fica mudo. A criação aqui é só a rede de segurança dos testes. Todo play_stream passa o
## barramento na chamada (ver tocar()).
static func garantir_barramento() -> int:
	var i := AudioServer.get_bus_index(BARRAMENTO)
	if i == -1:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, BARRAMENTO)
		AudioServer.set_bus_send(i, &"Master")
	AudioServer.set_bus_volume_db(i, VOLUME_GERAL_DB)
	return i


## O clique da ação `acao` ("" se a ação não faz som).
static func clique_da_acao(acao: String) -> String:
	return CLIQUE_DA_ACAO.get(acao, "")


## O texto guardado no navegador vira o mudo: só "1" liga.
static func mudo_de_texto(texto: Variant) -> bool:
	return str(texto) == "1"


func _ready() -> void:
	var i := garantir_barramento()
	AudioServer.set_bus_mute(i, _ler_guardado())
	_tocador = AudioStreamPlayer.new()
	_tocador.bus = BARRAMENTO
	_tocador.stream = AudioStreamPolyphonic.new()
	_tocador.max_polyphony = 8
	add_child(_tocador)
	_tocador.play()
	_playback = _tocador.get_stream_playback()


func esta_mudo() -> bool:
	var i := AudioServer.get_bus_index(BARRAMENTO)
	return i != -1 and AudioServer.is_bus_mute(i)


func definir_mudo(mudo: bool) -> void:
	AudioServer.set_bus_mute(garantir_barramento(), mudo)
	_guardar(mudo)


func alternar_mudo() -> void:
	definir_mudo(not esta_mudo())


## Toca o som `nome` (uma chave de SONS) e o registra para a sonda.
func tocar(nome: String) -> void:
	if not SONS.has(nome):
		return
	total += 1
	historico.append(nome)
	if historico.size() > MAX_HISTORICO:
		historico.pop_front()
	if _playback != null:
		# O barramento vai na chamada: no Web (modo sample) o som ignora o barramento do player e iria ao Master.
		_playback.play_stream(SONS[nome], 0.0, 0.0, 1.0, AudioServer.PLAYBACK_TYPE_DEFAULT, BARRAMENTO)


## O clique da ação, se ela faz som.
func clique(acao: String) -> void:
	var nome := clique_da_acao(acao)
	if nome != "":
		tocar(nome)


# --- localStorage (só Web) --------------------------------------------------------

static func _ler_guardado() -> bool:
	if not OS.has_feature("web"):
		return false
	var valor = JavaScriptBridge.eval(
		"(function(){try{return window.localStorage.getItem('%s')}catch(e){return null}})()" % CHAVE_MUDO, true)
	return mudo_de_texto(valor)


static func _guardar(mudo: bool) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(
		"(function(){try{window.localStorage.setItem('%s','%s')}catch(e){}})()" % [CHAVE_MUDO, "1" if mudo else "0"], true)
