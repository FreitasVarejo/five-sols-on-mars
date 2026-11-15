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
##
## O jogo em si mora em missao.gd (lógica pura). Aqui ficam a sala, a câmera e a ligação: a cada
## quadro a missão avança, a sala se redesenha com o estado dela (barras, medidor, estações,
## panorama) e o terminal (terminal.gd) e o HUD do turno desenham a parte de tela.

const VELOCIDADE_BORDA := 600.0  # px/s, no limite da tela
const VELOCIDADE_SETA := 400.0  # px/s, seta pressionada
const VELOCIDADE_VIRAR := 1000.0  # px/s, a sala virando sozinha para o botão do abrigo (~0,3 s do repouso)
const JSON_REGIOES := "res://assets/comodo/regioes.json"
const DadosDonki := preload("res://scripts/dados_donki.gd")
const Missao := preload("res://scripts/missao.gd")
const Desenho := preload("res://scripts/desenho.gd")
const TelaBarra := preload("res://scripts/tela_barra.gd")
const TelaRadiacao := preload("res://scripts/tela_radiacao.gd")
const Estacoes := preload("res://scripts/estacoes.gd")
const TelaComunicacao := preload("res://scripts/tela_comunicacao.gd")
const IndicadorPorta := preload("res://scripts/indicador_porta.gd")
const Persiana := preload("res://scripts/persiana.gd")
const Janela := preload("res://scripts/janela.gd")
const Som := preload("res://scripts/som.gd")
const Terminal := preload("res://scripts/terminal.gd")
const Inicio := preload("res://scripts/inicio.gd")
const Abertura := preload("res://scripts/abertura/abertura.gd")
const SONDA_PERIODO_S := 0.2  # no turno a sonda se atualiza pelo menos 5 vezes por segundo

const PANORAMAS := {
	"normal": preload("res://assets/comodo/normal.png"),
	"tempestade": preload("res://assets/comodo/tempestade.png"),
	# O vidro aberto: a persiana vem da camada Sala/Persiana (persiana.gd), não do panorama.
	"abrigo": preload("res://assets/comodo/abrigo_aberto.png"),
	"modo_seguranca": preload("res://assets/comodo/modo_seguranca.png"),
}
# Telas de barra da sala: nome (chave de tradução), ícone.
const TELAS := {
	"energia": ["ENERGIA", "energia"],
	"oxigenio": ["OXIGENIO", "oxigenio"],
}
# Estação de cada tarefa de ciência: tarefa -> botão da sala.
const ESTACOES := {"planta": "estufa", "amostra": "glovebox"}

@onready var _sala: Control = $Sala
@onready var _vista_janela: Janela = $Sala/Vista
@onready var _panorama: TextureRect = $Sala/Panorama
@onready var _panorama_anterior: TextureRect = $Sala/PanoramaAnterior
@onready var _persiana: Persiana = $Sala/Persiana
@onready var _telas: Control = $Sala/Telas
@onready var _realce: Control = $Sala/Realce
@onready var _distorcao: ColorRect = $Distorcao
@onready var _seta_esq: TextureButton = $HUD/SetaEsquerda
@onready var _seta_dir: TextureButton = $HUD/SetaDireita
@onready var _depuracao: Label = $HUD/Depuracao
@onready var _contornos: Control = $HUD/Contornos
@onready var _hud_turno: Control = $HUD/HudTurno
@onready var _terminal: Control = $Terminal
@onready var _som: Som = $Som
@onready var _botao_mudo: Control = $BotaoMudo

var _botoes := {}  # nome -> Rect2 no panorama (o que se clica)
var _regioes_telas := {}  # nome -> Rect2 no panorama (telas: só para os contornos de depuração)
var _donki := {}  # dado do DONKI embutido (dados_donki.gd)
var _missao: Missao
var _tela_energia: Control
var _tela_oxigenio: Control
var _tela_radiacao: Control
var _estacoes: Control
var _indicador_porta: Control
var _parametros := {}  # parâmetros da URL (só Web)
var _freeplay_gravado := false  # o destrave do freeplay já foi gravado no navegador nesta sessão
var _sonda_chave := ""
var _sonda_t := 0.0
var _pan := 0.0
var _pan_inteiro := 0
# A sala vira sozinha para o botão do abrigo (a linha do abrigo no terminal pede). Enquanto guiado, o pan
# por posição do mouse fica parado, senão o mouse que tocou a linha puxaria a sala de volta; um movimento
# do mouse ou uma seta solta o pan.
var _pan_alvo := 0.0
var _pan_guiado := false
var _cliques := 0
var _ultimo_clique := ""
var _hover := ""
var _estado := "normal"
var _vista := "normal"  # a vista de poeira (vista_janela_poeira.png) entra no P1
var _depurar := false
# Só com ?sonda=1 na URL (Web): window.fsom para o Playwright e a tecla D da depuração.
# Sem o parâmetro, o build que vai ao ar não expõe nada disso.
var _sondar := false
var _esq_pressionada := false
var _dir_pressionada := false
var _mouse_pos := Vector2.ZERO
# O pan por posição só vale com mouse de verdade e com o mouse dentro da janela.
var _mouse_real := false
var _mouse_dentro := true
# O começo do jogo: tela inicial -> abertura -> plano do sol 1. Enquanto uma dessas sobreposições está na
# tela, nada por baixo responde (terminal, clique e pan da sala, setas); só o botão de mudo.
var _sobreposicao: Control = null
var _tela := "jogo"  # "inicio", "abertura" ou "jogo" (a sonda lê)


func _ready() -> void:
	_parametros = _parametros_da_url()
	_sondar = _parametros.get("sonda") == "1"
	_terminal.gravar_textos = _sondar
	_botao_mudo.som = _som
	_terminal.som = _som
	_terminal.duracao = Terminal.duracao_da_url(_parametros.get("terminal"))
	_aplicar_stretch_da_url()
	# Inglês por padrão; ?lang=pt (ou en) é a escolha inicial. O idioma do navegador não conta.
	TranslationServer.set_locale("pt" if _parametros.get("lang") == "pt" else "en")
	_depuracao.hide()
	_donki = DadosDonki.carregar()
	_missao = Missao.new(int(_parametros.get("semente", -1)), _opcoes_da_missao())
	_carregar_regioes()
	_hud_turno.missao = _missao
	_terminal.iniciar(_missao, _donki)
	_terminal.desenhou.connect(_sonda_se_mudou)
	_terminal.pediu_abrigo.connect(_virar_para_abrigo)

	var tamanho := _panorama.texture.get_size()
	_panorama.size = tamanho
	_vista_janela.size = tamanho
	_panorama_anterior.size = tamanho
	_persiana.size = tamanho
	_persiana.configurar(_panorama, _panorama_anterior, Persiana.duracao_da_url(_parametros.get("persiana")))
	_persiana.mudou.connect(_sonda_persiana)
	_vista_janela.configurar_luz([_panorama, _panorama_anterior, _persiana])
	_sala.size = tamanho
	_telas.size = tamanho
	_realce.size = tamanho
	_realce.draw.connect(_desenhar_realce)
	_contornos.draw.connect(_desenhar_contornos)

	_seta_esq.button_down.connect(func() -> void:
		_esq_pressionada = true
		_pan_guiado = false)
	_seta_esq.button_up.connect(func() -> void: _esq_pressionada = false)
	_seta_dir.button_down.connect(func() -> void:
		_dir_pressionada = true
		_pan_guiado = false)
	_seta_dir.button_up.connect(func() -> void: _dir_pressionada = false)

	_pan = _alcance() / 2.0
	_pan_inteiro = roundi(_pan)
	_sala.position.x = -_pan_inteiro
	_atualizar_depuracao()
	_abrir_inicio()
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
		var tela: Control = TelaBarra.new()
		var r := _rect(dados["telas"][nome])
		tela.position = r.position
		tela.size = r.size
		tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tela.nome = tr(t[0])
		tela.icone = t[1]
		tela.maximo = 12
		_telas.add_child(tela)
		if nome == "energia":
			_tela_energia = tela
		else:
			_tela_oxigenio = tela

	# A tela de radiação leva a margem e o medidor (separado dela).
	_tela_radiacao = TelaRadiacao.new()
	var rr: Rect2 = _regioes_telas["radiacao"]
	_tela_radiacao.position = rr.position
	_tela_radiacao.size = rr.size
	_tela_radiacao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_telas.add_child(_tela_radiacao)

	var comunicacao: Control = TelaComunicacao.new()
	var rc: Rect2 = _regioes_telas["comunicacao"]
	comunicacao.position = rc.position
	comunicacao.size = rc.size
	comunicacao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_telas.add_child(comunicacao)

	# A lâmpada da porta do dormitório e a lua de "pode dormir", na camada da sala.
	_indicador_porta = IndicadorPorta.new()
	_indicador_porta.size = _panorama.texture.get_size()
	_indicador_porta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicador_porta.porta = _botoes["porta"]
	_indicador_porta.lampada = _rect(dados["desenho"]["porta_lampada"])
	_telas.add_child(_indicador_porta)

	# Andamento das tarefas nas estações.
	_estacoes = Estacoes.new()
	_estacoes.size = _panorama.texture.get_size()
	_estacoes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for tarefa: String in ESTACOES:
		_estacoes.regioes[tarefa] = _botoes[ESTACOES[tarefa]]
	_telas.add_child(_estacoes)


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
		# Só depois que a sala chegou ao abrigo: o mouse que mexe enquanto o terminal desce não desfaz a virada.
		if event is InputEventMouseMotion and _pan_guiado and absf(_pan - _pan_alvo) < 1.0:
			_pan_guiado = false


## Só chega aqui o que nenhum Control (as setas) consumiu.
func _unhandled_input(event: InputEvent) -> void:
	if _sobreposicao != null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var nome := _regiao_em(event.position)
		if nome != "":
			_ao_clicar(nome)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_D and _sondar:
			_depurar = not _depurar
			_contornos.visible = _depurar
			_depuracao.visible = _depurar
		elif event.keycode == KEY_P and _sondar and not _persiana.animando:
			# Teste: abre ou fecha a persiana só no visual e no som, sem mudar a missão.
			_persiana.ir_para(not _persiana.fechada(), PANORAMAS["abrigo" if not _persiana.fechada() else _estado])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse_dentro = false
	elif what == NOTIFICATION_WM_MOUSE_ENTER:
		_mouse_dentro = true


func _process(delta: float) -> void:
	# O relógio do jogo não dá salto se a aba ficou parada: no máximo 0,25 s por quadro. Parado enquanto a
	# tela inicial ou a abertura estão na tela.
	if _sobreposicao == null:
		_missao.avancar(minf(delta, 0.25))
	if _missao.fixa_concluida and not _freeplay_gravado:
		_freeplay_gravado = true
		_gravar_freeplay_destravado()
	var tapa: bool = _terminal.tapa_a_sala() or _sobreposicao != null
	if tapa:
		_esq_pressionada = false
		_dir_pressionada = false
	_seta_esq.visible = not tapa
	_seta_dir.visible = not tapa
	# No limite do pan a seta daquele lado desabilita: verde é só no que se clica.
	_seta_esq.disabled = _pan <= 0.0
	_seta_dir.disabled = _pan >= _alcance()
	if _seta_esq.disabled:
		_esq_pressionada = false
	if _seta_dir.disabled:
		_dir_pressionada = false

	var velocidade := 0.0
	if not tapa and not _pan_guiado:
		velocidade = _velocidade_seta() if (_esq_pressionada or _dir_pressionada) else _velocidade_mouse()
	if velocidade != 0.0:
		_pan = clampf(_pan + velocidade * delta, 0.0, _alcance())
	elif _pan_guiado and not tapa:
		_pan = passo_do_pan(_pan, _pan_alvo, VELOCIDADE_VIRAR * delta)
	var novo := roundi(_pan)
	_sala.position.x = -novo
	_pan_inteiro = novo

	var hover := _regiao_em(_mouse_pos) if (_mouse_real and _mouse_dentro) else ""
	if hover != _hover:
		_hover = hover
		_realce.queue_redraw()
	_atualizar_sala()
	if _depurar:
		_contornos.queue_redraw()
	_atualizar_depuracao()
	_sonda_se_mudou()


## A sala e o HUD do jogo, a partir do estado da missão.
func _atualizar_sala() -> void:
	var fase_ui: String = _terminal.fase_ui
	var barras := _missao.barras_na_fase(fase_ui)
	_tela_energia.atualizar(roundi(barras["E"]))
	_tela_oxigenio.atualizar(roundi(barras["O"]))
	_tela_radiacao.atualizar(barras["M"], _missao.medidor() if fase_ui == "turno" else Missao.MEDIDOR_BAIXO)
	# Panorama: normal; da tempestade em diante, tempestade; abrigado, abrigo; modo de segurança.
	var estado := "normal"
	if fase_ui == "seguranca":
		estado = "modo_seguranca"
	elif fase_ui == "turno":
		if _missao.abrigado:
			estado = "abrigo"
		elif _missao.tempestade_em_curso():
			estado = "tempestade"
	if estado != _estado:
		_definir_estado(estado)
	_vista_janela.acompanhar(fase_ui, _missao.relogio(), _missao.turno_s, _missao.eh_poeira())
	_hud_turno.visible = fase_ui == "turno" and not _terminal.aberto and _terminal.posicao() <= 0.0
	var estados := {}
	var progresso := {}
	var clicaveis := {}
	if fase_ui == "turno":
		for tarefa: String in ESTACOES:
			if _missao.tarefas.has(tarefa):
				estados[tarefa] = _missao.tarefas[tarefa]
				progresso[tarefa] = _missao.progresso_tarefa(tarefa)
				clicaveis[tarefa] = _clicavel(ESTACOES[tarefa])
	_estacoes.atualizar(estados, progresso, clicaveis)
	_indicador_porta.atualizar(_missao.pode_encerrar_sol())


## O que dá para clicar agora na sala: o abrigo no turno; a estufa e a glovebox quando a tarefa
## delas está escolhida, pendente, sem outra rodando e fora do abrigo; a porta do dormitório quando dá
## para encerrar o sol (a lista acabou e o medidor não pede atenção).
func _clicavel(nome: String) -> bool:
	if _missao.fase != "turno" or _terminal.fase_ui != "turno" or _terminal.tapa_a_sala() or _sobreposicao != null:
		return false
	match nome:
		"abrigo":
			return not _missao.abrigado
		"estufa":
			return _pode_iniciar("planta")
		"glovebox":
			return _pode_iniciar("amostra")
		"porta":
			return _missao.pode_encerrar_sol()
	return false


func _pode_iniciar(tarefa: String) -> bool:
	return _missao.tarefas.get(tarefa, "") == "pendente" and not _missao.abrigado and _missao.tarefa_rodando == ""


## A linha do abrigo foi tocada no terminal (já descendo): a sala vira até o botão do abrigo ficar à vista.
## Não abriga: abrigar é o toque no botão.
func _virar_para_abrigo() -> void:
	_pan_alvo = pan_para_ver(_botoes["abrigo"], get_viewport_rect().size.x, _alcance())
	_pan_guiado = true


## O pan que põe o centro do retângulo `r` (px do panorama) no meio da tela, preso ao alcance.
static func pan_para_ver(r: Rect2, largura_tela: float, alcance: float) -> float:
	return clampf(r.get_center().x - largura_tela / 2.0, 0.0, alcance)


## Anda o pan até o alvo, no máximo `passo` px (sem passar dele).
static func passo_do_pan(pan: float, alvo: float, passo: float) -> float:
	return move_toward(pan, alvo, passo)


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
	if _terminal.tapa_a_sala() or _sobreposicao != null:
		return ""
	for seta in [_seta_esq, _seta_dir]:
		if seta.is_visible_in_tree() and seta.get_global_rect().has_point(p):
			return ""
	var q := _tela_para_panorama(p)
	for nome: String in _botoes:
		if _botoes[nome].has_point(q) and _clicavel(nome):
			return nome
	return ""


# --- desenho -----------------------------------------------------------------

## Na Sala, antes do shader: o realce curva junto com a arte.
func _desenhar_realce() -> void:
	if _hover == "":
		return
	var r: Rect2 = _botoes[_hover]
	_realce.draw_rect(r, Color(1, 1, 1, 0.1))
	# Quatro cantoneiras em L, verde (é o que se clica): braço de 8 px, traço de 2 px.
	var braco := 8.0
	var traco := 2.0
	for canto in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		var sx := 1.0 if canto.x == r.position.x else -1.0
		var sy := 1.0 if canto.y == r.position.y else -1.0
		var horizontal := Rect2(canto.x if sx > 0 else canto.x - braco, canto.y if sy > 0 else canto.y - traco, braco, traco)
		var vertical := Rect2(canto.x if sx > 0 else canto.x - traco, canto.y if sy > 0 else canto.y - braco, traco, braco)
		_realce.draw_rect(horizontal, Desenho.VERDE)
		_realce.draw_rect(vertical, Desenho.VERDE)


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


# --- o começo do jogo: tela inicial, abertura ----------------------------------

## Põe a tela inicial por cima de tudo (só abaixo do botão de mudo) e desliga a entrada do que está por baixo.
func _abrir_inicio() -> void:
	var inicio := Inicio.new()
	inicio.som = _som
	inicio.marcar_idioma(TranslationServer.get_locale())
	inicio.idioma_escolhido.connect(definir_idioma)
	inicio.jogar.connect(_abrir_abertura)
	_por_sobreposicao(inicio, "inicio")


## Troca a tela inicial pela abertura (instanciada por código, tela cheia).
func _abrir_abertura() -> void:
	var abertura := Abertura.new()
	abertura.som = _som
	abertura.concluida.connect(_comecar_o_jogo)
	_por_sobreposicao(abertura, "abertura")


## A abertura acabou (botão final ou "Pular"): tira a sobreposição e devolve a entrada ao plano do sol 1.
func _comecar_o_jogo() -> void:
	_por_sobreposicao(null, "jogo")
	_terminal.queue_redraw()


func _por_sobreposicao(nova: Control, tela: String) -> void:
	if _sobreposicao != null:
		_sobreposicao.queue_free()
	_sobreposicao = nova
	_tela = tela
	if nova != null:
		nova.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(nova)
		move_child(nova, _botao_mudo.get_index())  # por cima de tudo, menos do botão de mudo
	_terminal.set_process_input(nova == null)
	_esq_pressionada = false
	_dir_pressionada = false
	_pan_guiado = false
	if is_node_ready():
		_sonda_teste()


## O idioma da tela inicial: troca na hora o que se desenha uma vez só (as telas de barra da sala) e manda o
## terminal redesenhar.
func definir_idioma(lang: String) -> void:
	TranslationServer.set_locale("pt" if lang == "pt" else "en")
	_atualizar_nomes_das_telas()
	_terminal.queue_redraw()
	_sonda_teste()


func _atualizar_nomes_das_telas() -> void:
	_tela_energia.nome = tr(TELAS["energia"][0])
	_tela_energia.queue_redraw()
	_tela_oxigenio.nome = tr(TELAS["oxigenio"][0])
	_tela_oxigenio.queue_redraw()


## A sobreposição de agora (ou null): o teste lê.
func sobreposicao() -> Control:
	return _sobreposicao


func tela_atual() -> String:
	return _tela


func _quadro_da_abertura() -> int:
	return (_sobreposicao as Abertura).quadro_atual() if _tela == "abertura" else -1


## O que se clica na sobreposição, nome -> [x, y, w, h]: a tela inicial (jogar, idioma_en, idioma_pt) ou a
## abertura (pular e, no último quadro, comecar).
func _ui_da_sobreposicao() -> Dictionary:
	if _tela == "inicio":
		return (_sobreposicao as Inicio).ui()
	var a := _sobreposicao as Abertura
	var ui := {}
	var itens := [["pular", a.rect_pular()]]
	if a.quadro_atual() == Abertura.ULTIMO:
		itens.append(["comecar", a.rect_botao_final()])
	for par in itens:
		var r: Rect2 = par[1]
		ui[par[0]] = [roundi(r.position.x), roundi(r.position.y), roundi(r.size.x), roundi(r.size.y)]
	return ui


# --- ações -------------------------------------------------------------------

func _ao_clicar(nome: String) -> void:
	_cliques += 1
	_ultimo_clique = nome
	var fez := false
	match nome:
		"abrigo":
			fez = _missao.abrigar()
		"estufa":
			fez = _missao.iniciar_tarefa("planta")
		"glovebox":
			fez = _missao.iniciar_tarefa("amostra")
		"porta":
			fez = _missao.encerrar_sol()
	if fez:
		_som.clique(nome)
	_sonda_teste()


func _definir_estado(estado: String) -> void:
	_estado = estado
	# Entrar no abrigo fecha a persiana (com cross-fade da luz); sair do abrigo abre.
	if (estado == "abrigo") != _persiana.fechada():
		_persiana.ir_para(estado == "abrigo", PANORAMAS[estado])
	else:
		_panorama.texture = PANORAMAS[estado]


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
	_depuracao.text = "stretch: %s\nshader em: %dx%d zoom %d\npan: %d / %d\nestado: %s  hover: %s\ncliques: %d (%s)\nfase: %s  sol %d  t %.1f\n%s" % [
		_nome_do_modo(), res.x, res.y, int(_zoom()), _pan_inteiro, roundi(_alcance()),
		_estado, _hover, _cliques, _ultimo_clique, _missao.fase, _missao.sol, _missao.t, DadosDonki.resumo(_donki)]


# --- parâmetros da URL (só Web) -------------------------------------------------

## ?lang=pt, ?turno=<s>, ?tarefa=<s>, ?persiana=<s> (duração da persiana, 0,5 a 3,0), ?terminal=<s> (duração
## do terminal subir e descer, 0,15 a 1,5; padrão 0,3), ?semente=<int>,
## ?sol_solar=2|3|4, ?sol_poeira=2..5, ?sol_quebra=2..5, ?stretch=viewport|canvas_items.
func _parametros_da_url() -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	var texto = JavaScriptBridge.eval(
		"JSON.stringify(Object.fromEntries(new URLSearchParams(window.location.search)))", true)
	var dados = JSON.parse_string(str(texto))
	return dados if dados is Dictionary else {}


func _opcoes_da_missao() -> Dictionary:
	var opcoes := {}
	var turno := float(_parametros.get("turno", 0.0))
	if turno > 0.0:
		opcoes["turno_s"] = turno
	var tarefa := float(_parametros.get("tarefa", 0.0))
	if tarefa > 0.0:
		opcoes["tarefa_s"] = tarefa
	var sol_solar := int(_parametros.get("sol_solar", 0))
	if sol_solar in Missao.SOLS_SOLAR:
		opcoes["sol_solar"] = sol_solar
	for chave: String in ["sol_poeira", "sol_quebra"]:
		var sol_forcado := int(_parametros.get(chave, 0))
		if sol_forcado in Missao.SOLS_EVENTO:
			opcoes[chave] = sol_forcado
	if _freeplay_destravado():
		opcoes["freeplay_aberto"] = true
	return opcoes


# --- freeplay destravado (localStorage, só Web) -----------------------------------

const CHAVE_FREEPLAY := "five-sols-on-mars.freeplay"  # "1" quando a missão fixa já chegou ao relatório


## A missão fixa já foi concluída neste navegador? Fora do Web, ou se o acesso falhar, não.
func _freeplay_destravado() -> bool:
	if not OS.has_feature("web"):
		return false
	var valor = JavaScriptBridge.eval(
		"(function(){try{return window.localStorage.getItem('%s')}catch(e){return null}})()" % CHAVE_FREEPLAY, true)
	return str(valor) == "1"


func _gravar_freeplay_destravado() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(
		"(function(){try{window.localStorage.setItem('%s','1')}catch(e){}})()" % CHAVE_FREEPLAY, true)


## No Web, lê ?stretch=viewport|canvas_items e aplica em content_scale_mode.
## Sem parâmetro (ou valor desconhecido) vale o project.godot.
func _aplicar_stretch_da_url() -> void:
	match _parametros.get("stretch"):
		"viewport":
			get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		"canvas_items":
			get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS


# --- sonda de teste -------------------------------------------------------------

## Retângulo, em px da tela, que o retângulo r do panorama ocupa agora (já com a curva do shader),
## cortado na tela. Vazio se está fora da vista.
func _rect_na_tela(r: Rect2) -> Rect2:
	var pts := _contorno_na_tela(r)
	var minimo := pts[0]
	var maximo := pts[0]
	for q in pts:
		minimo = Vector2(minf(minimo.x, q.x), minf(minimo.y, q.y))
		maximo = Vector2(maxf(maximo.x, q.x), maxf(maximo.y, q.y))
	var tela := Rect2(Vector2.ZERO, get_viewport_rect().size)
	return Rect2(minimo, maximo - minimo).intersection(tela)


## Tudo que se clica agora, nome -> [x, y, w, h] em px da tela de 640x360: o terminal e o que ele
## mostra, mais a sala (abrigo, estufa, glovebox, porta) e as setas, quando valem.
func _ui_da_tela() -> Dictionary:
	if _sobreposicao != null:
		var sobre := _ui_da_sobreposicao()
		sobre.merge(_botao_mudo.ui())
		return sobre
	var ui: Dictionary = _terminal.ui()
	for nome: String in _botoes:
		if _clicavel(nome):
			var r := _rect_na_tela(_botoes[nome])
			if r.size.x >= 4.0 and r.size.y >= 4.0:
				ui[nome] = [roundi(r.position.x), roundi(r.position.y), roundi(r.size.x), roundi(r.size.y)]
	ui.merge(_botao_mudo.ui())
	for par in [["seta_esq", _seta_esq], ["seta_dir", _seta_dir]]:
		if par[1].is_visible_in_tree() and not par[1].disabled:
			var r: Rect2 = par[1].get_global_rect()
			ui[par[0]] = [roundi(r.position.x), roundi(r.position.y), roundi(r.size.x), roundi(r.size.y)]
	return ui


## Só o bloco da persiana, a cada passo da animação (o resto da sonda não precisa de tanta pressa).
func _sonda_persiana() -> void:
	if _sondar:
		JavaScriptBridge.eval("window.fsom = window.fsom || {}; window.fsom.persiana = %s;" % JSON.stringify(_dados_persiana()), true)


func _dados_persiana() -> Dictionary:
	return {"progresso": _persiana.progresso, "animando": _persiana.animando, "laminas": _persiana.laminas(),
		"fechada": _persiana.fechada(), "duracao": _persiana.duracao}


func _sonda_se_mudou() -> void:
	if not _sondar:
		return
	var chave := "%s|%d|%s|%s|%d|%s|%s|%s|%s|%s|%s|%s|%s|%d|%s|%s|%s|%d|%s|%s" % [_missao.fase, _missao.versao, _terminal.aberto, _terminal.fase_ui,
		_pan_inteiro, _estado, _hover, _depurar, _seta_esq.visible, JSON.stringify(_terminal.ui()),
		_terminal.aba_na_tela(), _terminal.card_aberto, _som.esta_mudo(), _som.total, _terminal.tapa_a_sala(), _terminal.animando(),
		_tela, _quadro_da_abertura(), TranslationServer.get_locale(), _terminal.card_id]
	# Os retângulos da sobreposição andam com a rolagem da abertura: a sonda os relê a cada mudança.
	if _sobreposicao != null:
		chave += JSON.stringify(_ui_da_sobreposicao())
	var agora := Time.get_ticks_msec() / 1000.0
	if chave != _sonda_chave or _terminal.animando() or (_missao.fase == "turno" and agora - _sonda_t >= SONDA_PERIODO_S):
		_sonda_chave = chave
		_sonda_teste()


## SONDA DE TESTE (só Web, só com ?sonda=1): expõe o estado em window.fsom para o Playwright.
func _sonda_teste() -> void:
	if not _sondar:
		return
	_sonda_t = Time.get_ticks_msec() / 1000.0
	var res := _resolucao_do_shader()
	var m := _missao
	var prev := m.previsao()
	var tarefas := {}
	for nome in m.tarefas:
		tarefas[nome] = m.tarefas[nome]
	var estado := {
		"cliques": _cliques, "ultimo_clique": _ultimo_clique, "pan": _pan_inteiro,
		"modo": _nome_do_modo(), "shader_em": [res.x, res.y], "zoom": _zoom(),
		"estado": _estado, "vista": _vista, "persiana": _dados_persiana(),
		"hover": _hover, "depurar": _depurar,
		"pan_guiado": _pan_guiado, "pan_alvo": roundi(_pan_alvo) if _pan_guiado else null,
		"pan_do_abrigo": roundi(pan_para_ver(_botoes["abrigo"], get_viewport_rect().size.x, _alcance())),
		"alerta_sobre_terminal": _terminal.alerta_sobre_o_terminal(),
		"donki": {
			"historico": _donki["historico"], "chegadas": _donki["chegadas_marte"].size(),
			"coletado_em": _donki.get("coletado_em"), "motivo_historico": _donki.get("motivo_historico"),
			"texto": DadosDonki.resumo(_donki),
		},
		"fase": m.fase, "fase_ui": _terminal.fase_ui, "sol": m.sol,
		"st": {"E": m.st["E"], "O": m.st["O"], "M": m.st["M"]},
		"barras": m.barras_na_fase(_terminal.fase_ui),
		"margem_ao_vivo": m.margem_ao_vivo(),
		"plano": {"q": m.plano_q, "tarefas": m.plano_tarefas},
		"para_dividir": m.para_dividir(),
		"previsao": {"E": prev["st"]["E"], "O": prev["st"]["O"], "M": prev["st"]["M"], "falhas": prev["falhas"]},
		"relogio": m.relogio(), "turno_s": m.turno_s, "tarefa_s": m.tarefa_s,
		"t_pico": m.t_pico if m.t_pico >= 0.0 else null,
		"sol_solar": m.sol_solar, "freeplay": m.livre, "freeplay_aberto": m.freeplay_aberto, "atraso_min": m.atraso_min, "aviso_ativo": m.aviso_ativo(),
		"medidor": m.medidor(), "abrigado": m.abrigado, "tarefas": tarefas,
		"ciencia": m.ciencia_ate_agora(), "ciencia_sol": m.ciencia_do_sol(), "modos": m.modos,
		"tem_conserto": m.tem_conserto if m.fase == "seguranca" else null,
		"causa": m.causa if m.fase == "seguranca" else null,
		"causa_contexto": m.causa_contexto() if m.fase == "seguranca" else null,
		"estrelas": m.estrelas(),
		"terminal_aberto": _terminal.aberto,
		"terminal": {"pos": _terminal.posicao(), "animando": _terminal.animando(), "tapa": _terminal.tapa_a_sala(),
			"duracao": _terminal.duracao},
		"aba": _terminal.aba_na_tela(), "card_aberto": _terminal.card_aberto, "card": _terminal.card_id, "textos": _terminal.textos(),
		"idioma": TranslationServer.get_locale(), "tela": _tela, "abertura_quadro": _quadro_da_abertura(),
		"som": {"mudo": _som.esta_mudo(), "total": _som.total, "tocados": _som.historico},
		"ui": _ui_da_tela(),
		"sol_poeira": m.sol_poeira, "sol_quebra": m.sol_quebra, "poeira": m.eh_poeira(),
		"gerador_quebrado": m.st["gerador_quebrado"], "lista_acabou": m.lista_acabou(), "acelerado": m.acelerado,
		"pode_dormir": m.pode_encerrar_sol(), "porta_clicavel": _clicavel("porta"),
		"porta_acesa": _indicador_porta.aceso,
	}
	estado.merge(_sonda_graficos())
	JavaScriptBridge.eval("window.fsom = %s;" % JSON.stringify(estado), true)


## O que os gráficos expõem à sonda: a hora e a luz da sala, a mistura da vista de poeira e as setas.
func _sonda_graficos() -> Dictionary:
	return {"hora": _vista_janela.hora, "luz": _vista_janela.luz, "mistura_poeira": _vista_janela.mistura,
		"setas_desabilitadas": [_seta_esq.disabled, _seta_dir.disabled]}
