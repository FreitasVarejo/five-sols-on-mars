extends Control
## Terminal: o computador da base. Camada de tela por cima do panorama, depois do shader (não curva).
##
## Desenho imediato: tudo sai de _draw() a partir do estado da Missao (scripts/missao.gd), e cada
## controle que se clica é registrado em _botoes no momento em que é desenhado. Assim a lista de
## controles visíveis (ui()) e o que responde ao clique são sempre a mesma coisa.
##
## O botão único fica fixo embaixo, no centro, sempre no mesmo lugar: sobe o terminal e o mesmo
## botão o abaixa. Aberto, o terminal ocupa a tela inteira (decisão do P0) e tapa o clique da sala.
## O botão só vale no plano e no turno; nas outras fases o terminal fica aberto e o botão apagado.
##
## Toda mudança de `aberto` é uma animação: o terminal sobe de baixo para cima e desce de cima para
## baixo, com som, também quando sobe ou desce sozinho (troca de fase). `aberto` é o alvo; a posição
## visual é `_pos` (0 = abaixado, 1 = no alto) e anda até ele em `duracao` s. O botão TERMINAL apertado
## no meio da animação inverte o sentido a partir do ponto em que está. Enquanto anima, a sala não
## recebe clique e o conteúdo do terminal também não.
##
## Só o corpo de cada tecla e o da tela são pintados: a sala aparece nas frestas (bordas, vãos entre as
## teclas e a faixa de baixo, em volta dos botões). A área útil da tela não muda.
##
## `fase_ui` é a fase que a sala vê (muda na hora). `_fase_tela` é a que o terminal desenha: ao descer
## depois de uma troca de fase (confirmar o plano), ela fica a anterior até o terminal chegar embaixo.
##
## Plano, turno e fim do sol levam 4 teclas na moldura (câmeras, tarefas, diário, fontes), à esquerda:
## cada uma abre uma aba, sem sub-aba. `aba` guarda a aba aberta; "" é a tela própria da fase
## (plano -> o plano; turno -> tarefas; fim_do_sol -> diário). Mudar de fase zera `aba`.
## seguranca, noite e relatorio não levam teclas.
##
## Os cards da Terra abrem por cima do plano numa fila, um por vez (card_id é o da tela; card_aberto, se
## há algum). Cada um leva o botão "Fechar", que abre o próximo da fila; enquanto há card, só "Fechar" se clica.
## O aviso da tempestade é centrado e cobre o plano; os cards do sol 1 ficam ao lado do controle que nomeiam,
## que fica claro e com contorno enquanto o resto do plano escurece.
##
## Encerrar o sol não é botão do terminal: é a porta do dormitório, na sala (main.gd).
## "Consertar" (consertar_gerador) e "Iniciar" (iniciar_chemcam) são provisórios: as câmeras do
## terminal os substituem na próxima parte.
##
## Cores [R]: verde só no que se clica; vermelho e amarelo só em alerta; azul só no que vem da Terra.

const Missao := preload("res://scripts/missao.gd")
const Som := preload("res://scripts/som.gd")
const Modelo := preload("res://scripts/modelo.gd")
const Desenho := preload("res://scripts/desenho.gd")
const DadosDonki := preload("res://scripts/dados_donki.gd")
const HudTurno := preload("res://scripts/hud_turno.gd")
const Abertura := preload("res://scripts/abertura/abertura.gd")

## Avisa que acabou de desenhar (a sonda de teste lê ui() depois disso).
signal desenhou
## A linha do abrigo foi tocada: o terminal já desceu e a sala deve virar para o botão do abrigo (main.gd).
## A linha não abriga; abrigar é o toque no botão da sala.
signal pediu_abrigo

const DURACAO_PADRAO := 0.3  # escolhida de ouvido pelo dono (14/11), entre 0,25, 0,4 e 0,6
const DURACAO_MIN := 0.15
const DURACAO_MAX := 1.5
const BOTAO := Rect2(260, 328, 120, 28)
## O alerta do medidor por cima do terminal: embaixo à esquerda, na faixa abaixo das teclas e ao lado do
## BOTAO, onde não cobre tecla, tela nem botão.
const ALERTA := Rect2(8, 328, 34, 28)
const TELA := Rect2(0, 0, 640, 360)
const ESCURECER_S := 0.8   # fim do turno: escurece para um cinza neutro
const CLAREAR_S := 0.5

# Moldura com as 4 teclas (plano, turno, fim do sol): as teclas à esquerda, a tela à direita.
const TELA_COM_TECLAS := Rect2(80, 6, 554, 316)
const TELA_CHEIA := Rect2(6, 6, 628, 316)
# Os vãos de 12 a 14 px entre as teclas, e entre elas e a tela, deixam a sala aparecer (a tela não encolhe).
const TECLA_X := 6.0
const TECLA_W := 62.0
const TECLA_H := 66.0
const TECLAS_Y := [8.0, 88.0, 168.0, 248.0]
const ABAS := ["cameras", "tarefas", "diario", "fontes"]
const ICONES_ABA := {"cameras": "camera", "tarefas": "lista", "diario": "diario", "fontes": "fontes"}
const ROTULOS_ABA := {"cameras": "ABA_CAMERAS", "tarefas": "ABA_TAREFAS", "diario": "ABA_DIARIO", "fontes": "ABA_FONTES"}

# Dentro da tela com teclas: o miolo vai de X0 a X1; o corpo, de Y_CORPO a Y_FIM.
const X0 := 90.0
const X1 := 624.0
const Y_CORPO := 42.0
const Y_FIM := 314.0
const CARD := Rect2(147, 74, 420, 180)
# Os cards ao lado do controle: o texto de cada um, o controle que nomeiam (_alvos) e o lado do card.
const CARD_TEXTO := {"sol1_o2": "SOL1_CARD_O2", "sol1_ciencia": "SOL1_CARD_CIENCIA", "sol1_confirmar": "SOL1_CARD_CONFIRMAR"}
const CARD_ALVO := {"sol1_o2": "o2", "sol1_ciencia": "ciencia", "sol1_confirmar": "confirmar"}
const CARDS_SOL1 := ["sol1_o2", "sol1_ciencia", "sol1_confirmar"]
const CARD_LARGURA := 236.0
const CARD_TAM := 13
# Os cards ficam na coluna que não tem o controle: a da esquerda tem o O2 e a ciência; a da direita, o confirmar.
const CARD_X_DIREITA := 372.0
const CARD_X_ESQUERDA := 98.0

# Tela cheia (relatório).
const X_ESQ := 14.0

const ROTULOS_TAREFA := {"chemcam": "TAREFA_CHEMCAM", "amostra": "TAREFA_AMOSTRA", "planta": "TAREFA_PLANTA",
	"gerador": "TAREFA_GERADOR"}
const PARES_FONTES := ["O2", "MOXIE", "LIMITE", "RAD", "ESCALA", "PAINEL", "ATRASO"]
const SEM_FONTE := []  # fatos do jogo que não levam linha de fonte
const PASSO_LINHA := 42.0      # altura de uma linha da lista de tarefas, com o espaço entre elas

var missao: Missao
var donki := {}
var aberto := false
var som: Som                # os sons de subir e descer (main.gd o liga)
var duracao := DURACAO_PADRAO  # segundos para subir ou descer por inteiro (?terminal=<s>)
var fase_ui := "plano"      # a fase que a sala vê (atrasa o fim do turno, por causa do fade)
var aba := ""               # "" = a tela própria da fase; ou "cameras", "tarefas", "diario", "fontes"
var card_id := ""           # o card da Terra na tela agora ("" = nenhum): "aviso" ou um de CARD_TEXTO
var gravar_textos := false  # só com a sonda de teste ligada (main.gd, ?sonda=1)

var _fase_logica := "plano"
var _modos_vistos := 0      # quantas entradas no modo de segurança o terminal já viu (cada uma toca o desligar)
var _fase_tela := "plano"   # a fase que o terminal desenha (ver o cabeçalho)
var _pos := 1.0             # 0 = abaixado, 1 = no alto; anda até `aberto` em `duracao` s
var _fade := 0.0
var _fade_estado := ""      # "", "escurecendo" ou "clareando"
var _botoes := {}           # nome -> Rect2, só o que se clica agora
var _travado := false       # card aberto: o que está por baixo é desenhado mas não se clica
var _fila: Array = []       # os cards que ainda faltam abrir neste plano
var _vistos := {}           # card -> true: o que já abriu nesta sessão (os do sol 1 não voltam)
var _alvos := {}            # nome -> Rect2 dos controles que um card pode apontar, como o último quadro os pôs
var _textos: Array = []     # [texto, x, y, tamanho] de tudo que o quadro desenhou (para a sonda de teste)
var _mouse := Vector2(-100, -100)
var _hover := ""
var _versao_vista := -1
var _alarmou := false       # o alarme já tocou nesta travessia do limiar de abrigo


func iniciar(m: Missao, dado_donki: Dictionary) -> void:
	missao = m
	donki = dado_donki
	_fase_logica = m.fase
	_modos_vistos = m.modos
	_mostrar_fase(m.fase)
	aberto = _abre_na_fase(m.fase)
	_pos = 1.0 if aberto else 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Nome -> [x, y, w, h] do que se clica agora no terminal (px da tela de 640x360).
func ui() -> Dictionary:
	var d := {}
	for nome: String in _botoes:
		var r: Rect2 = _botoes[nome]
		d[nome] = [roundi(r.position.x), roundi(r.position.y), roundi(r.size.x), roundi(r.size.y)]
	return d


## Todo texto que o último quadro desenhou: [texto, x, y, tamanho].
func textos() -> Array:
	return _textos.duplicate()


## A aba na tela: "plano", "cameras", "tarefas", "diario" ou "fontes"; "" nas fases sem teclas.
func aba_na_tela() -> String:
	if not _tem_teclas(_fase_tela):
		return ""
	if aba != "":
		return aba
	return _aba_da_fase(_fase_tela)


## O terminal tapa a sala (pan parado, sem clique) enquanto estiver aberto, em animação (subindo ou
## descendo) ou escurecendo.
func tapa_a_sala() -> bool:
	return aberto or _pos > 0.0 or _fade_estado == "escurecendo"


## O alerta do medidor está desenhado por cima do terminal agora (a sonda de teste lê)? O HUD do turno some
## com o terminal aberto, em animação ou escurecendo; o alerta fica por cima dele.
func alerta_sobre_o_terminal() -> bool:
	return missao != null and fase_ui == "turno" and (aberto or _pos > 0.0) and HudTurno.cor_do_alerta(missao).a > 0.0


## Duração pedida na URL (?terminal=<s>): vale de DURACAO_MIN a DURACAO_MAX; fora disso ou ausente, o padrão.
static func duracao_da_url(valor: Variant) -> float:
	var s := float(valor) if valor != null else 0.0
	return s if s >= DURACAO_MIN and s <= DURACAO_MAX else DURACAO_PADRAO


## Easing suave (entra e sai devagar) de um progresso linear de 0 a 1.
static func suavizar(p: float) -> float:
	var x := clampf(p, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## O terminal está subindo ou descendo (ainda não chegou ao alvo)?
func animando() -> bool:
	return _pos != (1.0 if aberto else 0.0)


## Posição visual do terminal, de 0 (abaixado) a 1 (no alto), já com o easing (a sonda de teste lê).
func posicao() -> float:
	return suavizar(_pos)


static func _abre_na_fase(fase: String) -> bool:
	return fase != "turno"


static func _tem_teclas(fase: String) -> bool:
	return fase == "plano" or fase == "turno" or fase == "fim_do_sol"


## A aba que a fase mostra quando `aba` está vazia.
static func _aba_da_fase(fase: String) -> String:
	match fase:
		"turno":
			return "tarefas"
		"fim_do_sol":
			return "diario"
	return "plano"


## No turno, só câmeras e tarefas valem: todo texto mora fora do turno.
func _aba_habilitada(nome: String) -> bool:
	return _fase_tela != "turno" or nome == "cameras" or nome == "tarefas"


## Há card na tela (ou na fila de abrir)? A sonda e os testes leem.
var card_aberto: bool:
	get:
		return card_id != ""


func _card_visivel() -> bool:
	return _pos > 0.0 and _fase_tela == "plano" and card_aberto


## A tela passa a mostrar a fase `f`: zera a aba e, no plano, monta a fila de cards.
func _mostrar_fase(f: String) -> void:
	fase_ui = f
	_mostrar_na_tela(f)


## O terminal passa a desenhar a fase `f`: zera a aba e, no plano, monta a fila de cards e abre o primeiro.
func _mostrar_na_tela(f: String) -> void:
	_fase_tela = f
	aba = ""
	_fila = _cards_do_plano() if f == "plano" else []
	card_id = ""
	_abrir_proximo()


## Os cards deste plano, na ordem: o aviso da tempestade (reabre em todo plano em que está ativo, inclusive no
## reinício do sol), depois os do sol 1 da missão fixa, uma vez só por sessão.
func _cards_do_plano() -> Array:
	var fila: Array = []
	if missao.aviso_ativo():
		fila.append("aviso")
	if not missao.livre and missao.sol == 1:
		for id: String in CARDS_SOL1:
			if not _vistos.has(id):
				fila.append(id)
	return fila


## Abre o próximo card da fila (ou deixa a tela sem card). O card se marca visto quando abre.
func _abrir_proximo() -> void:
	if _fila.is_empty():
		card_id = ""
		return
	card_id = _fila.pop_front()
	_vistos[card_id] = true


## Muda o alvo do terminal (sobe ou desce) e toca o som do começo do movimento. Se `valor` já é o
## alvo, não faz nada. Subir mostra a fase atual: o conteúdo que ficou para trás numa descida
## interrompida não volta.
func _definir_aberto(valor: bool) -> void:
	if valor == aberto:
		return
	aberto = valor
	if valor and _fase_tela != fase_ui:
		_mostrar_na_tela(fase_ui)
	if som != null:
		som.tocar("terminal_sobe" if valor else "terminal_desce")


## Anda a posição até o alvo; embaixo, o conteúdo atrasado de uma descida passa para a fase atual.
## Devolve se algo mudou (a posição ou o conteúdo): o último passo, o que chega ao alvo, também se redesenha.
func _animar(delta: float) -> bool:
	var alvo := 1.0 if aberto else 0.0
	var mudou := false
	if _pos != alvo:
		_pos = move_toward(_pos, alvo, minf(delta, 0.1) / duracao)
		mudou = true
	if _pos <= 0.0 and _fase_tela != fase_ui:
		_mostrar_na_tela(fase_ui)
		mudou = true
	return mudou


func _process(delta: float) -> void:
	if missao == null:
		return
	# Cada entrada no modo de segurança toca o desligar uma vez, no mesmo quadro em que o terminal a vê:
	# com o relógio, é o começo do escurecimento; no meio do turno, a hora da entrada.
	if missao.modos > _modos_vistos and som != null:
		som.tocar("desligar")
	_modos_vistos = missao.modos
	_vigiar_alarme()
	if missao.fase != _fase_logica:
		_ao_mudar_de_fase(_fase_logica, missao.fase)
	match _fade_estado:
		"escurecendo":
			_fade = minf(1.0, _fade + delta / ESCURECER_S)
			if _fade >= 1.0:
				# O escurecimento chegou ao máximo: o terminal sobe junto com o clarear.
				_mostrar_fase(missao.fase)
				_definir_aberto(_abre_na_fase(fase_ui))
				_fade_estado = "clareando"
		"clareando":
			_fade = maxf(0.0, _fade - delta / CLAREAR_S)
			if _fade <= 0.0:
				_fade_estado = ""
	var animou := _animar(delta)
	var precisa := missao.fase == "turno" or _fade_estado != "" or missao.versao != _versao_vista or animou
	if precisa:
		queue_redraw()


## O alarme toca uma vez cada vez que o medidor passa para cima do limiar de abrigo no turno, fora do abrigo.
## Abrigar, sair do turno ou o medidor voltar ao limiar ou abaixo rearma.
func _vigiar_alarme() -> void:
	var acima := missao.fase == "turno" and not missao.abrigado and missao.medidor() > Missao.LIMIAR_ABRIGO
	if acima and not _alarmou and som != null:
		som.tocar("alarme")
	_alarmou = acima


func _ao_mudar_de_fase(de: String, para: String) -> void:
	_fase_logica = para
	# O turno que acaba pelo relógio escurece para um cinza neutro antes do terminal subir.
	# O modo de segurança no meio do turno entra direto.
	if de == "turno" and (para == "fim_do_sol" or para == "seguranca") and missao.t >= missao.turno_s - 1e-6:
		_fade_estado = "escurecendo"
		_fade = 0.0
		return
	fase_ui = para
	var abre := _abre_na_fase(para)
	# Subindo (ou com o terminal já embaixo) a tela já mostra a fase nova; descendo, só quando chegar.
	if abre or _pos <= 0.0:
		_mostrar_na_tela(para)
	_definir_aberto(abre)
	_fade_estado = ""
	_fade = 0.0
	queue_redraw()


# --- entrada -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if missao == null:
		return
	if event is InputEventMouse:
		_mouse = event.position
		var h := _botao_em(_mouse)
		if h != _hover:
			_hover = h
			queue_redraw()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var nome := _botao_em(event.position)
		if nome != "":
			_acionar(nome)
			get_viewport().set_input_as_handled()
		elif tapa_a_sala():
			get_viewport().set_input_as_handled()


func _botao_em(p: Vector2) -> String:
	for nome: String in _botoes:
		if _botoes[nome].has_point(p):
			return nome
	return ""


## Faz a ação `nome` e, se ela aconteceu de fato, toca o clique do peso dela (som.gd). O botão TERMINAL
## não faz clique: tem o som de subir e descer.
func _acionar(nome: String) -> void:
	if card_aberto and nome != "fechar_card":
		return
	var fez := true
	match nome:
		"terminal":
			_definir_aberto(not aberto)
		"fechar_card":
			_abrir_proximo()
		"voltar_plano":
			aba = ""
		"aba_cameras", "aba_tarefas", "aba_diario", "aba_fontes":
			fez = _apertar_tecla(nome.trim_prefix("aba_"))
		"o2_menos":
			fez = missao.mudar_q(-1)
		"o2_mais":
			fez = missao.mudar_q(1)
		"tarefa_chemcam", "tarefa_amostra", "tarefa_planta":
			fez = missao.alternar_tarefa(nome.trim_prefix("tarefa_"))
		"confirmar":
			fez = missao.confirmar_plano()
		"iniciar_chemcam":
			fez = missao.iniciar_tarefa("chemcam")
		"consertar_gerador":
			fez = missao.iniciar_tarefa("gerador")
		"enviar":
			fez = missao.enviar_a_terra()
		"reiniciar":
			fez = missao.reiniciar_sol()
		"seguir":
			fez = missao.seguir_em_seguranca()
		"jogar_de_novo":
			fez = missao.jogar_de_novo()
		"ir_ao_abrigo":
			fez = _ir_ao_abrigo()
	if fez and som != null:
		som.clique(nome)
	queue_redraw()


## A linha do abrigo: abaixa o terminal e pede à sala que vire para o botão. Não abriga. Só vale no turno
## e fora do abrigo.
func _ir_ao_abrigo() -> bool:
	if missao.fase != "turno" or fase_ui != "turno" or missao.abrigado:
		return false
	_definir_aberto(false)
	pediu_abrigo.emit()
	return true


## Apertar a tecla da aba na tela volta à tela própria da fase; apertar outra abre a aba dela.
## A aba que a própria fase mostra (tarefas no turno, diário no fim do sol) fica como "".
func _apertar_tecla(nome: String) -> bool:
	if not _aba_habilitada(nome):
		return false
	aba = "" if aba_na_tela() == nome else nome
	if aba == _aba_da_fase(_fase_tela):
		aba = ""
	return true


# --- desenho: peças ------------------------------------------------------------

func _t(s: String, x: float, y: float, tam: int = 11, cor: Color = Desenho.TEXTO, largura: float = -1.0,
		alinh: int = HORIZONTAL_ALIGNMENT_LEFT, negrito: bool = false) -> float:
	if gravar_textos:
		_textos.append([s, roundi(x), roundi(y), tam])
	return Desenho.texto(self, s, Vector2(x, y), tam, cor, largura, alinh, negrito)


func _caixa(r: Rect2, fundo: Color = Desenho.FUNDO_TELA, borda: Color = Desenho.BORDA) -> void:
	draw_rect(r, fundo)
	draw_rect(r, borda, false, 1.0)


## Pinta o corpo de um botão e devolve [fundo, cor do texto]. Habilitado entra em ui(), salvo com o
## card aberto por cima (aí é desenhado igual, mas não se clica). Desabilitado fica apagado.
func _pintar_botao(nome: String, r: Rect2, habilitado: bool, apertado: bool) -> Array:
	var fundo: Color
	var borda: Color
	var cor_texto: Color
	if habilitado:
		if not _travado:
			_botoes[nome] = r
		var hover := r.has_point(_mouse) and not _travado
		fundo = Desenho.VERDE_CLARO if hover else Desenho.VERDE
		borda = Desenho.VERDE_ESCURO
		cor_texto = Desenho.TEXTO_ESCURO
		if apertado:
			fundo = Desenho.VERDE_ESCURO
			borda = Desenho.VERDE
			cor_texto = Desenho.TEXTO
	else:
		fundo = Color("#27343d")
		borda = Color("#1c262d")
		cor_texto = Color("#6f8089")
	draw_rect(r, borda)
	draw_rect(r.grow(-2.0), fundo)
	return [fundo, cor_texto]


## Botão verde (todo botão é verde). Desabilitado fica apagado e não entra em ui().
func _botao(nome: String, r: Rect2, rotulo: String, icone: String = "", habilitado: bool = true,
		tam: int = 12, apertado: bool = false) -> void:
	var cores := _pintar_botao(nome, r, habilitado, apertado)
	var fundo: Color = cores[0]
	var cor_texto: Color = cores[1]
	var lado := float(tam + 2)
	var larg_texto := Desenho.largura_texto(rotulo, tam, true)
	var total := larg_texto + (lado + 5.0 if icone != "" else 0.0)
	var x := r.position.x + (r.size.x - total) / 2.0
	var y_meio := r.position.y + r.size.y / 2.0
	if icone != "":
		Desenho.icone(self, icone, Rect2(x, y_meio - lado / 2.0, lado, lado), cor_texto, fundo)
		x += lado + 5.0
	_t(rotulo, x, y_meio - Desenho.fonte().get_height(tam) / 2.0, tam, cor_texto, -1.0,
		HORIZONTAL_ALIGNMENT_LEFT, true)


## Tecla da moldura: ícone em cima, palavra embaixo. Mesmo estilo do botão; a da aba na tela fica apertada.
func _tecla(a: String, r: Rect2) -> void:
	_aro(r)
	var cores := _pintar_botao("aba_" + a, r, _aba_habilitada(a), aba_na_tela() == a)
	var fundo: Color = cores[0]
	var cor: Color = cores[1]
	Desenho.icone(self, ICONES_ABA[a], Rect2(r.position.x + (r.size.x - 22.0) / 2.0, r.position.y + 14, 22, 22), cor, fundo)
	_t(tr(ROTULOS_ABA[a]), r.position.x, r.position.y + 44, 11, cor, r.size.x, HORIZONTAL_ALIGNMENT_CENTER, true)


## Uma barra do cabeçalho: ícone, nome, número e células. Com `falha`, leva moldura vermelha e o ícone de alerta.
func _barra(x: float, y: float, w: float, icone: String, nome: String, valor: float, maximo: int,
		falha: bool = false, fundo: Color = Desenho.FUNDO_TERMINAL) -> void:
	if falha:
		draw_rect(Rect2(x - 4, y - 4, w + 8, 33), Desenho.VERMELHO, false, 2.0)
	var cor_rec := Desenho.cor_recurso(icone)
	Desenho.icone(self, icone, Rect2(x, y + 1, 12, 12), cor_rec, fundo)
	_t(nome, x + 16, y, 11, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	var rot := "%d/%d" % [roundi(valor), maximo]
	_t(rot, x, y - 1, 12, Desenho.TEXTO, w - (16.0 if falha else 0.0), HORIZONTAL_ALIGNMENT_RIGHT, true)
	if falha:
		Desenho.icone(self, "alerta", Rect2(x + w - 13, y, 13, 13), Desenho.VERMELHO, fundo)
	Desenho.celulas(self, Rect2(x, y + 17, w, 7), valor, maximo, cor_rec)


## "a → b" alinhado à direita em [x, x+w], com a seta desenhada (a fonte padrão não tem "→").
func _de_para(x: float, y: float, w: float, a: String, b: String, cor: Color, tam: int = 12) -> void:
	var lb := Desenho.largura_texto(b, tam, true)
	var la := Desenho.largura_texto(a, tam, true)
	var xr := x + w
	_t(b, xr - lb, y, tam, cor, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	var xs := xr - lb - 17.0
	var ys := y + Desenho.fonte().get_height(tam) * 0.55
	draw_line(Vector2(xs, ys), Vector2(xs + 11, ys), cor, 1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(xs + 13, ys), Vector2(xs + 8, ys - 3), Vector2(xs + 8, ys + 3)]), cor)
	_t(a, xs - 4.0 - la, y, tam, cor, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)


func _numero(x: float) -> String:
	var n := roundi(x)
	return ("−%d" % -n) if n < 0 else str(n)


## Inteiro quando é inteiro; senão uma casa decimal, com vírgula em português.
func _decimal(x: float) -> String:
	var d := snappedf(x, 0.1)
	if is_equal_approx(d, roundf(d)):
		return _numero(d)
	var s := "%.1f" % absf(d)
	if TranslationServer.get_locale().begins_with("pt"):
		s = s.replace(".", ",")
	return ("−" + s) if d < 0.0 else s


func _nome_tarefa(nome: String) -> String:
	return tr(ROTULOS_TAREFA[nome])


# --- desenho: o quadro -----------------------------------------------------------

func _draw() -> void:
	_botoes.clear()
	_textos.clear()
	_alvos.clear()
	if missao == null:
		return
	_versao_vista = missao.versao
	var card := _card_visivel()
	var anima := animando()
	if _pos > 0.0:
		# O terminal (e o card, que vem junto) sobe e desce; o botão TERMINAL, embaixo, fica parado.
		draw_set_transform(Vector2(0.0, roundf((1.0 - suavizar(_pos)) * TELA.size.y)))
		_travado = card or anima  # o que se clica no terminal só vale parado e sem o card por cima
		_desenhar_terminal()
		if card:
			# O plano fica atrás, escurecido (só o terminal, não a sala); só o "Fechar" se clica. O card ao lado
			# de um controle deixa esse controle claro, com contorno.
			var alvo := _alvo_do_card()
			_escurecer_corpos(alvo)
			_travado = anima
			_desenhar_card(alvo)
		draw_set_transform(Vector2.ZERO)
	_travado = card
	var no_jogo := fase_ui == "plano" or fase_ui == "turno"
	var livre := _fade_estado != "escurecendo"
	_botao("terminal", BOTAO, tr("TERMINAL"), "terminal", no_jogo and livre and not card, 12, aberto)
	if alerta_sobre_o_terminal():
		_desenhar_alerta()
	if _fade > 0.0:
		draw_rect(TELA, Color(Desenho.NOITE, _fade))
	desenhou.emit()


## O alerta do medidor (o ícone do HUD do turno, no mesmo chip), por cima do terminal. Só se vê: não é botão.
func _desenhar_alerta() -> void:
	var cor := HudTurno.cor_do_alerta(missao)
	draw_rect(ALERTA, Color(Desenho.NOITE, 0.92))
	draw_rect(ALERTA, cor, false, 2.0)
	Desenho.icone(self, "alerta", Rect2(ALERTA.position.x + 7, ALERTA.position.y + 4, 20, 20), cor, Desenho.NOITE)


func _desenhar_terminal() -> void:
	if _fase_tela == "seguranca":
		# O modo de segurança é um painel central sobre a sala (no estado modo_seguranca); a faixa de
		# baixo não tem moldura: a sala aparece em volta dos botões.
		draw_rect(TELA, Color(Desenho.NOITE, 0.62))
		_desenhar_seguranca()
		return
	# Sem moldura opaca: só o corpo da tela e o de cada tecla, com um aro fino. A sala aparece nas frestas.
	var tela := _retangulo_da_tela()
	_aro(tela)
	draw_rect(tela, Desenho.FUNDO_TERMINAL)
	draw_rect(tela, Desenho.BORDA, false, 2.0)
	if _tem_teclas(_fase_tela):
		for i in ABAS.size():
			_tecla(ABAS[i], _retangulos_das_teclas()[i])
		match aba_na_tela():
			"plano":
				_desenhar_plano()
			"cameras":
				_desenhar_cameras()
			"tarefas":
				_desenhar_tarefas()
			"diario":
				_desenhar_diario()
			"fontes":
				_desenhar_fontes()
		return
	match _fase_tela:
		"noite":
			_desenhar_noite()
		"relatorio":
			_desenhar_relatorio()


## O corpo da tela do terminal: com as 4 teclas à esquerda, ou cheia.
func _retangulo_da_tela() -> Rect2:
	return TELA_COM_TECLAS if _tem_teclas(_fase_tela) else TELA_CHEIA


## O corpo de cada tecla, na ordem de ABAS.
func _retangulos_das_teclas() -> Array:
	var lista := []
	for y: float in TECLAS_Y:
		lista.append(Rect2(TECLA_X, y, TECLA_W, TECLA_H))
	return lista


## Aro fino e escuro de 1 px em volta de um corpo, para ele não se perder na sala que aparece atrás.
func _aro(r: Rect2) -> void:
	draw_rect(r.grow(1.0), Desenho.MOLDURA, false, 1.0)


## O card da Terra por cima: o plano (a tela e as teclas, sem a sala em volta) fica escurecido. O retângulo
## `claro`, se houver, fica de fora (o controle que o card aponta).
func _escurecer_corpos(claro: Rect2 = Rect2()) -> void:
	var cor := Color(Desenho.NOITE, 0.6)
	for r: Rect2 in [_retangulo_da_tela()] + _retangulos_das_teclas():
		for pedaco: Rect2 in _menos(r, claro):
			draw_rect(pedaco, cor)


## O retângulo `r` sem a parte de `furo`: até quatro pedaços (em cima, embaixo, à esquerda, à direita).
static func _menos(r: Rect2, furo: Rect2) -> Array:
	if furo.size.x <= 0.0 or not r.intersects(furo):
		return [r]
	var f := r.intersection(furo)
	var saida: Array = []
	if f.position.y > r.position.y:
		saida.append(Rect2(r.position.x, r.position.y, r.size.x, f.position.y - r.position.y))
	if f.end.y < r.end.y:
		saida.append(Rect2(r.position.x, f.end.y, r.size.x, r.end.y - f.end.y))
	if f.position.x > r.position.x:
		saida.append(Rect2(r.position.x, f.position.y, f.position.x - r.position.x, f.size.y))
	if f.end.x < r.end.x:
		saida.append(Rect2(f.end.x, f.position.y, r.end.x - f.end.x, f.size.y))
	return saida


## O controle que o card da tela aponta, como o último quadro o desenhou (vazio se o card não aponta nada).
func _alvo_do_card() -> Rect2:
	return _alvos.get(CARD_ALVO.get(card_id, ""), Rect2())


# --- cabeçalhos ------------------------------------------------------------------

## Ícone, título (14, negrito) e subtítulo (12, suave) no alto da tela com teclas. Devolve o x onde acaba.
func _titulo(icone: String, titulo: String, sub: String) -> float:
	Desenho.icone(self, icone, Rect2(X0, 13, 16, 16), Desenho.TEXTO, Desenho.FUNDO_TERMINAL)
	_t(titulo, X0 + 22, 12, 14, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	var x_sub := X0 + 22 + Desenho.largura_texto(titulo, 14, true) + 6
	_t(sub, x_sub, 14, 12, Desenho.TEXTO_SUAVE)
	return x_sub + Desenho.largura_texto(sub, 12)


## Cabeçalho de aba: ícone e nome da aba, "· Sol N de 5". No plano, "Voltar ao plano" à direita;
## no turno, as três barras ao vivo.
func _cabecalho_aba(a: String, sol_n: int, barras: Dictionary = {}) -> void:
	_titulo(ICONES_ABA[a], tr(ROTULOS_ABA[a]), tr("CAB_SOL_ABA") % [sol_n, Modelo.N.SOLS])
	if _fase_tela == "plano":
		_botao("voltar_plano", Rect2(X1 - 140, 8, 140, 28), tr("VOLTAR_AO_PLANO"), "", true, 12)
	if not barras.is_empty():
		var x := 284.0
		_barra(x, 12, 108, "energia", tr("ENERGIA"), barras["E"], 12)
		_barra(x + 116, 12, 108, "oxigenio", tr("OXIGENIO"), barras["O"], 12)
		_barra(x + 232, 12, 108, "radiacao", tr("MARGEM"), barras["M"], 12)


# --- plano -----------------------------------------------------------------------

func _desenhar_plano() -> void:
	var p := missao.previsao()
	_titulo("sol", tr("CAB_SOL") % [missao.sol, Modelo.N.SOLS], tr("CAB_PLANO"))
	_coluna_energia(Rect2(X0, Y_CORPO, 262, 272))
	_coluna_previsao(Rect2(X0 + 270, Y_CORPO, 264, 272), p)


## "−N ⚡ cada" alinhado à direita em `x_dir`.
func _custo_cada(x_dir: float, y: float, valor: float) -> void:
	var num := _numero(-valor)
	var l_num := Desenho.largura_texto(num, 13, true)
	var l_cada := Desenho.largura_texto(tr("CADA"), 11)
	var x := x_dir - (l_num + 4.0 + 12.0 + 4.0 + l_cada)
	_t(num, x, y - 1, 13, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	Desenho.icone(self, "energia", Rect2(x + l_num + 4.0, y + 2, 12, 12), Desenho.ENERGIA, Desenho.FUNDO_TELA)
	_t(tr("CADA"), x + l_num + 20.0, y + 1, 11, Desenho.TEXTO_SUAVE)


## Cabeça de uma linha: ícone e nome em negrito.
func _cabeca_linha(x: float, y: float, icone: String, nome: String) -> void:
	Desenho.icone(self, icone, Rect2(x, y + 1, 14, 14), Desenho.cor_recurso(icone), Desenho.FUNDO_TELA)
	_t(nome, x + 20, y, 12, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)


## Para onde vai a energia: aquecimento (fixo), oxigênio e ciência.
func _coluna_energia(r: Rect2) -> void:
	_caixa(r)
	var x := r.position.x + 8
	var w := r.size.x - 16
	var y := r.position.y + 10

	# A. Aquecimento da noite: fixo, sem botão. Na tempestade de poeira, logo abaixo, a linha da poeira.
	_cabeca_linha(x, y, "noite", tr("AQUECIMENTO_DA_NOITE"))
	var num := _numero(-Modelo.N.AQUEC)
	var l_num := Desenho.largura_texto(num, 13, true)
	_t(num, x + w - l_num - 16, y - 1, 13, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	Desenho.icone(self, "energia", Rect2(x + w - 12, y + 2, 12, 12), Desenho.ENERGIA, Desenho.FUNDO_TELA)
	y += 26
	if missao.eh_poeira():
		Desenho.icone(self, "poeira", Rect2(x, y + 1, 12, 12), Desenho.TEXTO, Desenho.FUNDO_TELA)
		y += _t(tr("PLANO_POEIRA") % roundi(Modelo.N.FATOR_POEIRA * 100.0), x + 16, y, 11, Desenho.TEXTO, w - 16) + 4
	draw_line(Vector2(x, y), Vector2(x + w, y), Desenho.BORDA, 1.0)
	y += 9

	# B. Oxigênio: − q +.
	_cabeca_linha(x, y, "oxigenio", tr("OXIGENIO"))
	_custo_cada(x + w, y, Modelo.N.GEN_CUSTO)
	y += 24
	var q := missao.plano_q
	var n := missao.plano_tarefas.size()
	_alvos["o2"] = Rect2(x, y, w, 42)
	_botao("o2_menos", Rect2(x, y, 64, 42), "−", "", q > 0, 22)
	_t(str(q), x + 64, y + (42.0 - Desenho.fonte().get_height(24)) / 2.0, 24, Desenho.TEXTO, w - 128, HORIZONTAL_ALIGNMENT_CENTER, true)
	_botao("o2_mais", Rect2(x + w - 64, y, 64, 42), "+", "", missao.plano_cabe(q + 1, n), 22)
	y += 48
	if missao.st["gerador_quebrado"]:
		Desenho.icone(self, "alerta", Rect2(x, y + 1, 12, 12), Desenho.AMARELO, Desenho.FUNDO_TELA)
		y += _t(tr("GERADOR_QUEBRADO"), x + 16, y, 11, Desenho.AMARELO, w - 16) + 6
	else:
		y += 4
	draw_line(Vector2(x, y), Vector2(x + w, y), Desenho.BORDA, 1.0)
	y += 9

	# C. Ciência: três cartões liga/desliga.
	_cabeca_linha(x, y, "ciencia", tr("CIENCIA"))
	_custo_cada(x + w, y, Modelo.N.CIENCIA_CUSTO)
	y += 24
	_alvos["ciencia"] = Rect2(x, y, w, 60)
	var cx := x
	for nome in Missao.TAREFAS:
		_cartao_tarefa(nome, Rect2(cx, y, 78, 60))
		cx += 84


func _cartao_tarefa(nome: String, r: Rect2) -> void:
	var ligada: bool = nome in missao.plano_tarefas
	var habilitado := ligada or missao.plano_cabe(missao.plano_q, missao.plano_tarefas.size() + 1)
	var fundo: Color
	var cor: Color
	var borda: Color
	if habilitado:
		if not _travado:
			_botoes["tarefa_" + nome] = r
		var hover := r.has_point(_mouse) and not _travado
		borda = Desenho.VERDE_ESCURO
		if ligada:
			fundo = Desenho.VERDE_CLARO if hover else Desenho.VERDE
			cor = Desenho.TEXTO_ESCURO
		else:
			fundo = Color("#2a3b2a") if not hover else Color("#35503a")
			cor = Desenho.VERDE
			borda = Desenho.VERDE
	else:
		fundo = Color("#27343d")
		cor = Color("#6f8089")
		borda = Color("#1c262d")
	draw_rect(r, borda)
	draw_rect(r.grow(-2), fundo)
	Desenho.icone(self, nome, Rect2(r.position.x + (r.size.x - 22.0) / 2.0, r.position.y + 10, 22, 22), cor, fundo)
	if ligada:
		Desenho.icone(self, "check", Rect2(r.end.x - 18, r.position.y + 5, 12, 12), cor, fundo)
	_t(_nome_tarefa(nome), r.position.x + 2, r.position.y + 40, 11, cor, r.size.x - 4, HORIZONTAL_ALIGNMENT_CENTER, true)


## O que acontece se confirmar: uma barra "antes → depois" por recurso, a ciência e o botão.
func _coluna_previsao(r: Rect2, p: Dictionary) -> void:
	_caixa(r)
	_alvos["confirmar"] = r
	var x := r.position.x + 8
	var w := r.size.x - 16
	var y := r.position.y + 10
	var st := missao.st
	var fim: Dictionary = p["st"]
	var falhas: Array = p["falhas"]

	# Energia.
	var falha_e := "energia" in falhas
	_bloco_previsao(x, y, w, "energia", tr("ENERGIA"), st["E"], fim["E"], falha_e)
	if falha_e:
		_nota(x, y + 36, w, tr("FALHA_ENERGIA"), Desenho.VERMELHO, true, "alerta")
	elif p["perdida_no_teto"] > 0.0:
		_nota(x, y + 36, w, tr("BATERIA_CHEIA_PERDE") % roundi(p["perdida_no_teto"]), Desenho.TEXTO, true)
	y += 58

	# Oxigênio.
	var falha_o := "oxigenio" in falhas
	_bloco_previsao(x, y, w, "oxigenio", tr("OXIGENIO"), st["O"], fim["O"], falha_o)
	if falha_o:
		_nota(x, y + 36, w, tr("FALHA_OXIGENIO"), Desenho.VERMELHO, true, "alerta")
	else:
		var sois := maxi(0, floori(maxf(0.0, fim["O"]) / Modelo.N.CREW_O2 + 1e-9))
		# Com o gerador quebrado a previsão supõe o conserto no turno, e a nota diz isso.
		var quebrado: bool = st["gerador_quebrado"]
		var ar: String
		if quebrado:
			ar = tr("AR_PARA_1_SE_CONSERTAR") if sois == 1 else (tr("AR_PARA_N_SE_CONSERTAR") % sois)
		else:
			ar = tr("AR_PARA_1") if sois == 1 else (tr("AR_PARA_N") % sois)
		if sois == 0 or quebrado:
			_nota(x, y + 36, w, ar, Desenho.AMARELO, true, "alerta")
		else:
			_nota(x, y + 36, w, ar, Desenho.TEXTO, true)
	y += 58

	# Margem.
	var falha_m := "radiacao" in falhas
	_bloco_previsao(x, y, w, "radiacao", tr("MARGEM"), st["M"], fim["M"], falha_m)
	if falha_m:
		_nota(x, y + 36, w, tr("FALHA_MARGEM"), Desenho.VERMELHO, true, "alerta")
	elif missao.aviso_ativo():
		_nota(x, y + 36, w, tr("SEM_CONTAR_TEMPESTADE"), Desenho.TEXTO_SUAVE)
	y += 58

	# Ciência.
	draw_line(Vector2(x, y), Vector2(x + w, y), Desenho.BORDA, 1.0)
	y += 8
	_cabeca_linha(x, y, "ciencia", tr("CIENCIA"))
	_t("+%d" % int(p["ciencia"]), x, y - 3, 17, Desenho.TEXTO, w, HORIZONTAL_ALIGNMENT_RIGHT, true)
	_botao("confirmar", Rect2(x, r.end.y - 8 - 44, w, 44), tr("CONFIRMAR_PLANO"), "check", true, 14)


## Um bloco da previsão: ícone, nome, "antes → depois" e a barra. A nota vai em y + 36.
## O "depois" nunca aparece negativo; em falha, tudo vai para o vermelho.
func _bloco_previsao(x: float, y: float, w: float, icone: String, nome: String, antes: float, depois: float,
		falha: bool) -> void:
	var cor := Desenho.VERMELHO if falha else Desenho.TEXTO
	var cor_rec := Desenho.VERMELHO if falha else Desenho.cor_recurso(icone)
	Desenho.icone(self, icone, Rect2(x, y + 1, 14, 14), cor_rec, Desenho.FUNDO_TELA)
	_t(nome, x + 20, y, 12, cor, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	var d := maxf(0.0, depois)
	_de_para(x, y, w, _numero(maxf(0.0, antes)), _numero(d), cor, 12)
	Desenho.celulas_de_para(self, Rect2(x, y + 21, w, 8), antes, d, 12, cor_rec)


## Uma linha de nota de 11 px, com ícone opcional (alerta).
func _nota(x: float, y: float, w: float, texto: String, cor: Color, negrito: bool = false, icone: String = "") -> void:
	var dx := 0.0
	if icone != "":
		Desenho.icone(self, icone, Rect2(x, y + 1, 12, 12), cor, Desenho.FUNDO_TELA)
		dx = 16.0
	_t(texto, x + dx, y, 11, cor, w - dx, HORIZONTAL_ALIGNMENT_LEFT, negrito)


# --- card da Terra -------------------------------------------------------------

## O card da tela: o aviso (centrado) ou o que fica ao lado de um controle.
func _desenhar_card(alvo: Rect2) -> void:
	if card_id == "aviso":
		_desenhar_card_aviso()
	else:
		_desenhar_card_ao_lado(alvo)


## O aviso da Terra por cima do plano: retângulo azul simples, sem destaque, seta nem animação.
func _desenhar_card_aviso() -> void:
	var r := CARD
	draw_rect(r, Desenho.AZUL)
	var x := r.position.x + 14
	var larg := r.size.x - 28
	var y := r.position.y + 12
	y += _t(tr("AVISO_TEMPESTADE"), x, y, 14, Desenho.TEXTO_ESCURO, larg, HORIZONTAL_ALIGNMENT_LEFT, true) + 6
	if donki.get("historico", true):
		_t(tr("DONKI_FRASE_HISTORICO"), x, y, 12, Desenho.TEXTO_ESCURO, larg)
	else:
		_t(tr("DONKI_FRASE_ATUAL") % DadosDonki.data_br(_chegada_mais_recente()), x, y, 12, Desenho.TEXTO_ESCURO, larg)
	var rodape := r.end.y - 12 - 28
	var larg_rodape := larg - 134
	Desenho.icone(self, "terra", Rect2(x, rodape + 1, 12, 12), Desenho.TEXTO_ESCURO, Desenho.AZUL)
	_t(tr("ENVIADO_DA_TERRA") % missao.atraso_min, x + 16, rodape, 11, Desenho.TEXTO_ESCURO, larg_rodape - 16)
	if donki.get("historico", true):
		_t(tr("DONKI_DADO_HISTORICO"), x, rodape + 14, 11, Desenho.TEXTO_ESCURO, larg_rodape)
	else:
		_t(tr("DONKI_DADO_DE") % DadosDonki.data_br(str(donki.get("coletado_em", ""))), x, rodape + 14, 11,
			Desenho.TEXTO_ESCURO, larg_rodape)
	_botao("fechar_card", Rect2(r.end.x - 14 - 120, r.end.y - 12 - 36, 120, 36), tr("FECHAR"), "", true, 13)


## O card ao lado do controle `alvo`, na coluna que não o tem, com uma frase por linha e uma ponta
## apontando para ele. O controle leva um contorno azul (a Terra fala); o resto do plano já está escurecido.
func _desenhar_card_ao_lado(alvo: Rect2) -> void:
	var texto := tr(CARD_TEXTO[card_id])
	var larg := CARD_LARGURA - 24.0
	var altura_texto := 0.0
	var frases := Abertura.frases(texto)
	for frase: String in frases:
		altura_texto += Desenho.altura_texto(frase, CARD_TAM, larg, true) + 4.0
	var altura := 12.0 + altura_texto + 4.0 + 36.0 + 12.0
	# O controle na esquerda: o card vai para a direita (e a ponta aponta para a esquerda); o da direita, o contrário.
	var na_direita := alvo.get_center().x < 360.0
	var x := CARD_X_DIREITA if na_direita else CARD_X_ESQUERDA
	var y := clampf(alvo.get_center().y - altura / 2.0, Y_CORPO + 6.0, Y_FIM - altura - 6.0)
	var r := Rect2(x, y, CARD_LARGURA, altura)
	if alvo.size.x > 0.0:
		draw_rect(alvo.grow(2.0), Desenho.AZUL, false, 2.0)
		var ponta_y := clampf(alvo.get_center().y, r.position.y + 10.0, r.end.y - 10.0)
		if na_direita:
			draw_colored_polygon(PackedVector2Array([Vector2(r.position.x, ponta_y - 8.0),
				Vector2(r.position.x - 10.0, ponta_y), Vector2(r.position.x, ponta_y + 8.0)]), Desenho.AZUL)
		else:
			draw_colored_polygon(PackedVector2Array([Vector2(r.end.x, ponta_y - 8.0),
				Vector2(r.end.x + 10.0, ponta_y), Vector2(r.end.x, ponta_y + 8.0)]), Desenho.AZUL)
	draw_rect(r, Desenho.AZUL)
	var yy := r.position.y + 12.0
	for frase: String in frases:
		yy += _t(frase, r.position.x + 12.0, yy, CARD_TAM, Desenho.TEXTO_ESCURO, larg, HORIZONTAL_ALIGNMENT_LEFT, true) + 4.0
	_botao("fechar_card", Rect2(r.end.x - 12.0 - 100.0, r.end.y - 12.0 - 36.0, 100, 36), tr("FECHAR"), "", true, 13)


## A chegada a Marte com `chegada_prevista` mais recente (dado atual do DONKI).
func _chegada_mais_recente() -> String:
	var melhor := ""
	for c in donki.get("chegadas_marte", []):
		var quando = c.get("chegada_prevista")
		if quando is String and quando > melhor:
			melhor = quando
	return melhor


# --- aba câmeras -----------------------------------------------------------------

## Placeholder: o conteúdo das câmeras é a próxima fatia.
func _desenhar_cameras() -> void:
	_cabecalho_aba("cameras", missao.sol)
	var r := Rect2(X0, Y_CORPO, X1 - X0, Y_FIM - Y_CORPO)
	_caixa(r)
	var c := r.get_center()
	Desenho.icone(self, "camera", Rect2(c.x - 24, c.y - 40, 48, 48), Desenho.TEXTO_SUAVE, Desenho.FUNDO_TELA)
	_t(tr("CAMERAS_VAZIO"), r.position.x, c.y + 20, 12, Desenho.TEXTO_SUAVE, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


# --- aba fontes ------------------------------------------------------------------

## O que saiu do plano (a conta da energia e o tanque de O2) e de onde vêm os números.
func _desenhar_fontes() -> void:
	_cabecalho_aba("fontes", missao.sol)
	var m := Modelo.manha(missao.st, missao.eh_poeira())
	var rl := Rect2(X0, Y_CORPO, 180, Y_FIM - Y_CORPO)
	_caixa(rl)
	var x := rl.position.x + 8
	var w := rl.size.x - 16
	var y := rl.position.y + 8

	# Energia do sol: bateria + painel − aquecimento = para dividir.
	Desenho.icone(self, "energia", Rect2(x, y + 1, 12, 12), Desenho.ENERGIA, Desenho.FUNDO_TELA)
	y += _t(tr("ENERGIA_DO_SOL") % missao.sol, x + 16, y, 12, Desenho.TEXTO, w - 16, HORIZONTAL_ALIGNMENT_LEFT, true) + 4
	# Uma casa decimal quando a conta não é inteira (o painel na poeira rende 0,8): a conta tem de fechar.
	var linhas := [
		[tr("LINHA_BATERIA"), _decimal(missao.st["E"])],
		[tr("LINHA_PAINEL"), _decimal(m["renda"])],
		[tr("LINHA_AQUECIMENTO"), _decimal(Modelo.N.AQUEC)],
	]
	for l in linhas:
		var h := _t(l[0], x, y, 11, Desenho.TEXTO, w - 24)
		_t(l[1], x, y, 11, Desenho.TEXTO, w, HORIZONTAL_ALIGNMENT_RIGHT, true)
		y += maxf(h, 14.0)
	draw_line(Vector2(x, y + 1), Vector2(x + w, y + 1), Desenho.BORDA, 1.0)
	y += 5
	var h_dividir := _t(tr("LINHA_PARA_DIVIDIR"), x, y, 12, Desenho.TEXTO, w - 24, HORIZONTAL_ALIGNMENT_LEFT, true)
	_t(_decimal(m["para_dividir"]), x, y, 12, Desenho.TEXTO, w, HORIZONTAL_ALIGNMENT_RIGHT, true)
	y += h_dividir + 10

	# Tanque de O2.
	Desenho.icone(self, "oxigenio", Rect2(x, y + 1, 12, 12), Desenho.OXIGENIO, Desenho.FUNDO_TELA)
	y += _t(tr("TANQUE_O2"), x + 16, y, 12, Desenho.TEXTO, w - 16, HORIZONTAL_ALIGNMENT_LEFT, true) + 6
	var h_nota := Desenho.altura_texto(tr("FONTE_UNIDADES_FATO"), 10, w)
	_tanque(Rect2(x, y, w, rl.end.y - 8 - y - h_nota - 8))
	_t(tr("FONTE_UNIDADES_FATO"), x, rl.end.y - 8 - h_nota, 10, Desenho.TEXTO_SUAVE, w)

	# De onde vêm os números.
	var rr := Rect2(X0 + 186, Y_CORPO, X1 - X0 - 186, Y_FIM - Y_CORPO)
	_caixa(rr)
	x = rr.position.x + 8
	w = rr.size.x - 16
	y = rr.position.y + 7
	var pares := _pares_fontes()
	# O texto usa 10 px; se o idioma não couber na caixa, desce para 9 px, e o espaço entre os fatos
	# (5 px) encolhe para 2 px quando só assim a lista cabe.
	var livre := rr.end.y - 7 - y
	var tam := 10
	var espaco := 2.0
	if _altura_pares(pares, w, 10) > livre:
		tam = 9
		if _altura_pares(pares, w, 9) + 3.0 * pares.size() <= livre:
			espaco = 5.0
	for par in pares:
		y += _par_fonte(x, y, w, par[0], par[1], tam) + espaco


## Um fato (`tam` px) e a fonte dele (9 px, suave). Se a fonte cabe na última linha do fato, vai ali
## mesmo, ao lado; senão, embaixo. Assim a lista cabe na tela em inglês e em português.
## Devolve a altura ocupada. Com `desenhar` falso só mede.
func _par_fonte(x: float, y: float, w: float, fato: String, fonte: String, tam: int, desenhar: bool = true) -> float:
	var par := TextParagraph.new()
	par.add_string(fato, Desenho.fonte(), tam)
	par.width = w
	var h_fato := Desenho.altura_texto(fato, tam, w)
	var ao_lado := false
	var l_ultima := par.get_line_width(par.get_line_count() - 1)
	if fonte != "":
		ao_lado = l_ultima + 6.0 + Desenho.largura_texto(fonte, 9) <= w
	if desenhar:
		_t(fato, x, y, tam, Desenho.TEXTO, w)
		if ao_lado:
			# Alinha as linhas de base: a fonte de 9 px fica na base da última linha do fato.
			var dy := Desenho.fonte().get_ascent(tam) - Desenho.fonte().get_ascent(9)
			_t(fonte, x + l_ultima + 6.0, y + h_fato - Desenho.fonte().get_height(tam) + dy, 9, Desenho.TEXTO_SUAVE)
		elif fonte != "":
			_t(fonte, x, y + h_fato, 9, Desenho.TEXTO_SUAVE, w)
	if fonte != "" and not ao_lado:
		h_fato += Desenho.altura_texto(fonte, 9, w)
	return h_fato


func _altura_pares(pares: Array, w: float, tam: int) -> float:
	var total := 0.0
	for par in pares:
		total += _par_fonte(0.0, 0.0, w, par[0], par[1], tam, false) + 2.0
	return total


## [fato, fonte] de cada número do jogo; a fonte é "" quando o fato não leva.
func _pares_fontes() -> Array:
	var pares := []
	if donki.get("historico", true):
		pares.append([tr("FONTE_DONKI_HIST_FATO"), tr("FONTE_DONKI_HIST_FONTE")])
	else:
		pares.append([tr("FONTE_DONKI_FATO") % DadosDonki.data_br(_chegada_mais_recente()),
			tr("FONTE_DONKI_FONTE") % DadosDonki.data_br(str(donki.get("coletado_em", "")))])
	for k in PARES_FONTES:
		pares.append([tr("FONTE_%s_FATO" % k), "" if k in SEM_FONTE else tr("FONTE_%s_FONTE" % k)])
	return pares


## O tanque na vertical: 12 faixas, cheio é bom; a chave marca o que a tripulação respira em 1 sol.
func _tanque(r: Rect2) -> void:
	var agora: float = missao.st["O"]
	var g := Rect2(r.position.x + 2, r.position.y, 26, r.size.y)
	draw_rect(g, Desenho.FUNDO_TERMINAL)
	var faixa := g.size.y / 12.0
	var cheias := clampi(roundi(agora), 0, 12)
	for i in 12:
		var rf := Rect2(g.position.x + 2, g.end.y - (i + 1) * faixa + 1, g.size.x - 4, faixa - 1)
		draw_rect(rf, Desenho.OXIGENIO if i < cheias else Desenho.CELULA_VAZIA)
	draw_rect(g, Desenho.TEXTO_SUAVE, false, 1.0)
	var h_sol := Modelo.N.CREW_O2 * faixa
	var xc := g.end.x + 3
	draw_line(Vector2(xc, g.end.y), Vector2(xc, g.end.y - h_sol), Desenho.TEXTO_SUAVE, 1.0)
	_t(tr("UM_SOL"), xc + 4, g.end.y - 13, 10, Desenho.TEXTO_SUAVE)
	var tx := r.position.x + 58
	var lw := r.size.x - 58
	var y := r.position.y
	y += _t(tr("TANQUE_AGORA") % [roundi(agora), 12], tx, y, 11, Desenho.TEXTO, lw, HORIZONTAL_ALIGNMENT_LEFT, true) + 6
	y += _t(tr("TRIPULACAO_RESPIRA") % roundi(Modelo.N.CREW_O2), tx, y, 10, Desenho.TEXTO_SUAVE, lw) + 4
	_t(tr("O2_CUSTO") % roundi(Modelo.N.GEN_CUSTO), tx, y, 10, Desenho.TEXTO_SUAVE, lw)


# --- aba tarefas ---------------------------------------------------------------

## A lista de tarefas do sol, estilo Among Us: ícone, uma palavra, estado. No turno leva as barras ao vivo.
func _desenhar_tarefas() -> void:
	_cabecalho_aba("tarefas", missao.sol, missao.barras_na_fase("turno") if _fase_tela == "turno" else {})
	var r := Rect2(X0, Y_CORPO, X1 - X0, Y_FIM - Y_CORPO)
	_caixa(r)
	var x := r.position.x + 10
	var y := r.position.y + 10
	var lista := missao.lista_do_turno()
	# A linha do abrigo vale enquanto o medidor pede abrigo e, depois de abrigar, até o fim do sol.
	var com_abrigo := missao.abrigado or missao.medidor() > Missao.LIMIAR_ABRIGO
	if com_abrigo:
		_linha_abrigo(Rect2(x, y, r.size.x - 20, 40))
		y += PASSO_LINHA
	for nome in lista:
		_linha_tarefa(nome, Rect2(x, y, r.size.x - 20, 40))
		y += PASSO_LINHA
	if lista.is_empty() and not com_abrigo:
		_t(tr("SEM_TAREFAS"), x, y + 6, 12, Desenho.TEXTO_SUAVE)
	if missao.abrigado:
		_t(tr("ABRIGO_ATE_FIM"), x, y + 4, 12, Desenho.TEXTO_SUAVE, r.size.x - 20)


func _linha_base(r: Rect2) -> void:
	draw_rect(r, Desenho.FUNDO_TERMINAL)
	draw_rect(r, Desenho.BORDA, false, 1.0)


func _estado_texto(estado: String) -> String:
	return tr("ESTADO_" + estado.to_upper())


func _linha_tarefa(nome: String, r: Rect2) -> void:
	_linha_base(r)
	var estado: String = missao.tarefas.get(nome, "pendente")
	Desenho.icone(self, nome, Rect2(r.position.x + 10, r.position.y + 10, 20, 20), Desenho.TEXTO, Desenho.FUNDO_TERMINAL)
	_t(_nome_tarefa(nome), r.position.x + 40, r.position.y + 12, 14, Desenho.TEXTO, 120, HORIZONTAL_ALIGNMENT_LEFT, true)
	var xe := r.position.x + 170
	match estado:
		"feita":
			Desenho.icone(self, "check", Rect2(xe, r.position.y + 12, 16, 16), Desenho.TEXTO, Desenho.FUNDO_TERMINAL)
			_t(_estado_texto("feita"), xe + 22, r.position.y + 13, 13, Desenho.TEXTO, 120)
		"rodando":
			var f := missao.progresso_tarefa(nome)
			_t(_estado_texto("rodando"), xe, r.position.y + 5, 11, Desenho.TEXTO)
			var rb := Rect2(xe, r.position.y + 22, 150, 10)
			draw_rect(rb, Desenho.CELULA_VAZIA)
			draw_rect(Rect2(rb.position, Vector2(rb.size.x * f, rb.size.y)), Desenho.TEXTO)
			_t("%d%%" % roundi(f * 100.0), rb.end.x + 8, rb.position.y - 3, 12, Desenho.TEXTO, 40, HORIZONTAL_ALIGNMENT_LEFT, true)
		_:
			# Depois de abrigar a tripulação não faz mais tarefas no turno: a pendente fica cancelada.
			var cancelada := missao.abrigado
			Desenho.icone(self, "circulo", Rect2(xe, r.position.y + 12, 16, 16), Desenho.TEXTO_SUAVE, Desenho.FUNDO_TERMINAL)
			_t(_estado_texto("cancelada" if cancelada else "pendente"), xe + 22, r.position.y + 13, 13, Desenho.TEXTO_SUAVE, 140)
	var livre := missao.fase == "turno" and estado == "pendente" and not missao.abrigado and missao.tarefa_rodando == ""
	if missao.abrigado and estado == "pendente":
		return  # cancelada: sem botão
	if nome == "chemcam":
		# Placeholder: o ChemCam de verdade se faz pelas câmeras do terminal (P1).
		_botao("iniciar_chemcam", Rect2(r.end.x - 130, r.position.y + 5, 122, 30), tr("INICIAR"), "", livre, 12)
	elif nome == "gerador":
		# Placeholder: o conserto de verdade se faz pela câmera do MOXIE (próxima parte). Não gasta energia.
		_botao("consertar_gerador", Rect2(r.end.x - 130, r.position.y + 5, 122, 30), tr("CONSERTAR"), "", livre, 12)


func _linha_abrigo(r: Rect2) -> void:
	_linha_base(r)
	var feita := missao.abrigado
	var cor := Desenho.TEXTO if feita else Desenho.VERMELHO
	draw_rect(r, cor, false, 2.0)
	if not feita and not _travado and r.has_point(_mouse):
		draw_rect(r.grow(-2.0), Color(Desenho.TEXTO, 0.08))
	Desenho.icone(self, "alerta", Rect2(r.position.x + 10, r.position.y + 10, 20, 20), cor, Desenho.FUNDO_TERMINAL)
	_t(tr("ABRIGO"), r.position.x + 40, r.position.y + 12, 14, cor, 120, HORIZONTAL_ALIGNMENT_LEFT, true)
	var xe := r.position.x + 170
	if feita:
		Desenho.icone(self, "check", Rect2(xe, r.position.y + 12, 16, 16), cor, Desenho.FUNDO_TERMINAL)
		_t(_estado_texto("feita"), xe + 22, r.position.y + 13, 13, cor, 120)
	else:
		Desenho.icone(self, "circulo", Rect2(xe, r.position.y + 12, 16, 16), cor, Desenho.FUNDO_TERMINAL)
		_t(_estado_texto("pendente"), xe + 22, r.position.y + 13, 13, cor, 120)
		# Antes de abrigar a linha é botão: o verde marca o que se toca, e a linha inteira vale o toque.
		_botao("ir_ao_abrigo", Rect2(r.end.x - 130, r.position.y + 5, 122, 30), tr("IR_AO_ABRIGO"), "", true, 12)
		if _botoes.has("ir_ao_abrigo"):
			_botoes["ir_ao_abrigo"] = r


# --- aba diário ------------------------------------------------------------------

func _registro_atual() -> Dictionary:
	if missao.registros.is_empty():
		return {}
	return missao.registros[missao.registros.size() - 1]


## No fim do sol, o diário do sol com "Enviar à Terra". Nas outras fases, o do último registro, só leitura.
func _desenhar_diario() -> void:
	var reg := _registro_atual()
	_cabecalho_aba("diario", reg["sol"] if not reg.is_empty() else missao.sol)
	if reg.is_empty():
		var rv := Rect2(X0, Y_CORPO, X1 - X0, Y_FIM - Y_CORPO)
		_caixa(rv)
		_t(tr("DIARIO_VAZIO"), rv.position.x + 10, rv.position.y + 12, 12, Desenho.TEXTO_SUAVE)
		return

	# Esquerda: o que se escreveu sozinho.
	var r := Rect2(X0, Y_CORPO, 306, Y_FIM - Y_CORPO)
	_caixa(r)
	_pintar_itens(_itens_diario(reg), r.position.x + 10, r.position.y + 9, r.size.x - 20, r.end.y - 6)

	# Direita: as barras, antes e depois.
	var rb := Rect2(r.end.x + 6, Y_CORPO, X1 - r.end.x - 6, 214)
	_caixa(rb)
	var bx := rb.position.x + 10
	var bw := rb.size.x - 20
	var by := rb.position.y + 9
	_t(tr("DIARIO_BARRAS"), bx, by, 11, Desenho.TEXTO_SUAVE, bw)
	by += 22
	var nomes := {"E": ["energia", tr("ENERGIA")], "O": ["oxigenio", tr("OXIGENIO")], "M": ["radiacao", tr("MARGEM")]}
	for k in ["E", "O", "M"]:
		var a: float = reg["antes"][k]
		var d: float = reg["depois"][k]
		Desenho.icone(self, nomes[k][0], Rect2(bx, by + 1, 12, 12), Desenho.cor_recurso(k), Desenho.FUNDO_TELA)
		_t(nomes[k][1], bx + 16, by, 11, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
		_de_para(bx, by - 1, bw, _numero(a), "%s/12" % _numero(d), Desenho.TEXTO)
		Desenho.celulas(self, Rect2(bx, by + 17, bw, 6), maxf(0.0, d), 12, Desenho.cor_recurso(k))
		by += 44
	if _fase_tela == "fim_do_sol":
		_botao("enviar", Rect2(rb.position.x, Y_FIM - 50, rb.size.x, 50), tr("ENVIAR_A_TERRA"), "terra", true, 14)


## As linhas do diário do sol, na ordem: o que aconteceu, a poeira, a ciência, a tarefa não feita, a
## manutenção e a mensagem recebida. Cada uma: ícone (opcional), texto, tamanho, cor e espaço depois.
func _itens_diario(reg: Dictionary) -> Array:
	var itens: Array = []
	# 1. O que aconteceu.
	if reg["seguranca"]:
		itens.append({"icone": "alerta", "cor_icone": Desenho.AMARELO, "texto": tr("DIARIO_SEGURANCA"), "tam": 12,
			"negrito": true, "cor": Desenho.AMARELO, "gap": 6})
	elif reg["tempestade"]:
		itens.append({"texto": tr("DIARIO_TEMPESTADE"), "tam": 12, "negrito": true, "gap": 2})
		var chave := "DIARIO_ABRIGO_A_TEMPO"
		if not reg["abrigou"]:
			chave = "DIARIO_SEM_ABRIGO"
		elif reg["f_exposto"] > 0.0:
			chave = "DIARIO_ABRIGO_TARDE"
		itens.append({"texto": tr(chave) % roundi(reg["dose"]), "tam": 12, "gap": 6})
	else:
		itens.append({"texto": tr("DIARIO_CALMO"), "tam": 12, "negrito": true, "gap": 6})
	if reg["poeira"]:
		itens.append({"icone": "poeira", "texto": tr("DIARIO_POEIRA") % roundi(Modelo.N.FATOR_POEIRA * 100.0), "tam": 12,
			"gap": 4})
	if not reg["seguranca"]:
		# 2. Ciência.
		itens.append({"icone": "ciencia", "texto": tr("DIARIO_CIENCIA") % [reg["ciencia"], missao.ciencia_total()],
			"tam": 12, "gap": 4})
		# 3. Tarefa não feita: a reserva volta à bateria (e o que passou do teto se perdeu).
		var nao_feitas: Array = reg["nao_feitas"]
		if nao_feitas.size() == 1:
			itens.append({"texto": tr("DIARIO_NAO_FEITA") % [_nome_tarefa(nao_feitas[0]), roundi(Modelo.N.CIENCIA_CUSTO)],
				"tam": 11, "gap": 2})
		elif nao_feitas.size() > 1:
			var nomes: Array = []
			for nome in nao_feitas:
				nomes.append(_nome_tarefa(nome))
			itens.append({"texto": tr("DIARIO_NAO_FEITAS") % [", ".join(nomes),
				roundi(Modelo.N.CIENCIA_CUSTO * nao_feitas.size())], "tam": 11, "gap": 2})
		if reg["perdida_no_teto"] > 0.0:
			itens.append({"texto": tr("DIARIO_PERDIDA") % roundi(reg["perdida_no_teto"]), "tam": 11, "gap": 2})
		# A manutenção: a consequência da que não foi feita, antes de ela pesar.
		if reg["gerador_quebrado"]:
			var consertou: bool = reg["consertou"]
			var cor := Desenho.TEXTO if consertou else Desenho.AMARELO
			itens.append({"icone": "gerador", "cor_icone": cor, "cor": cor, "tam": 11, "gap": 2,
				"texto": tr("DIARIO_GERADOR_CONSERTADO" if consertou else "DIARIO_GERADOR_QUEBRADO")})
		itens[itens.size() - 1]["gap"] += 4
	# 4. A mensagem recebida.
	if reg["aviso"]:
		itens.append({"linha": true, "icone": "terra", "cor_icone": Desenho.AZUL, "texto": tr("DIARIO_MENSAGEM"), "tam": 11,
			"negrito": true, "cor": Desenho.AZUL, "gap": 0})
		itens.append({"texto": tr("AVISO_TEMPESTADE"), "tam": 11, "recuo": true, "gap": 0})
	return itens


## Desenha as linhas de `_itens_diario` de `y` até `y_max`. Se não couberem, desce 1 px no tamanho de todas.
func _pintar_itens(itens: Array, x: float, y: float, w: float, y_max: float) -> void:
	var menos := 0
	if _altura_itens(itens, w, 0) > y_max - y:
		menos = 1
	for it in itens:
		var tam: int = int(it["tam"]) - menos
		var recuo: bool = it.has("icone") or it.get("recuo", false)
		var larg := w - (16.0 if recuo else 0.0)
		var cor: Color = it.get("cor", Desenho.TEXTO)
		if it.get("linha", false):
			draw_line(Vector2(x, y), Vector2(x + w, y), Desenho.BORDA, 1.0)
			y += 6.0
		if it.has("icone"):
			Desenho.icone(self, it["icone"], Rect2(x, y + 1, 12, 12), it.get("cor_icone", Desenho.TEXTO), Desenho.FUNDO_TELA)
		y += _t(it["texto"], x + (16.0 if recuo else 0.0), y, tam, cor, larg, HORIZONTAL_ALIGNMENT_LEFT,
			it.get("negrito", false)) + float(it["gap"])


func _altura_itens(itens: Array, w: float, menos: int) -> float:
	var total := 0.0
	for it in itens:
		var recuo: bool = it.has("icone") or it.get("recuo", false)
		total += (6.0 if it.get("linha", false) else 0.0)
		total += Desenho.altura_texto(it["texto"], int(it["tam"]) - menos, w - (16.0 if recuo else 0.0),
			it.get("negrito", false)) + float(it["gap"])
	return total


# --- noite -----------------------------------------------------------------------

func _desenhar_noite() -> void:
	draw_rect(TELA, Desenho.NOITE)
	Desenho.icone(self, "noite", Rect2(304, 124, 32, 32), Desenho.TEXTO, Desenho.NOITE)
	_t(tr("NOITE_AQUECIMENTO") % roundi(Modelo.N.AQUEC), 120, 170, 16, Desenho.TEXTO, 400, HORIZONTAL_ALIGNMENT_CENTER, true)


# --- modo de segurança -----------------------------------------------------------

func _desenhar_seguranca() -> void:
	var r := Rect2(40, 10, 560, 310)
	draw_rect(r, Desenho.FUNDO_TERMINAL)
	draw_rect(r, Desenho.BORDA, false, 2.0)
	var x := r.position.x + 16
	var w := r.size.x - 32
	var y := r.position.y + 12
	Desenho.icone(self, "alerta", Rect2(x, y + 1, 20, 20), Desenho.AMARELO, Desenho.FUNDO_TERMINAL)
	_t(tr("MODO_SEGURANCA"), x + 28, y, 18, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	Desenho.icone(self, "sol", Rect2(r.end.x - 90, y + 3, 14, 14), Desenho.TEXTO, Desenho.FUNDO_TERMINAL)
	_t(tr("SOL_N") % missao.sol, r.end.x - 70, y + 2, 14, Desenho.TEXTO, 56, HORIZONTAL_ALIGNMENT_LEFT, true)
	y += 32
	var b := missao.barras_falha
	var causa := missao.causa
	var larg_barra := (w - 40.0) / 3.0
	_barra(x + 4, y + 4, larg_barra - 8, "energia", tr("ENERGIA"), b["E"], 12, causa == "energia")
	_barra(x + larg_barra + 24, y + 4, larg_barra - 8, "oxigenio", tr("OXIGENIO"), b["O"], 12, causa == "oxigenio")
	_barra(x + 2 * larg_barra + 44, y + 4, larg_barra - 8, "radiacao", tr("MARGEM"), b["M"], 12, causa == "radiacao")
	y += 38

	# A causa: a barra que zerou e, se houver, o contexto (até 3 linhas no pior caso, medido).
	var frase := tr("CAUSA_" + causa.to_upper())
	var contexto := missao.causa_contexto()
	if contexto != "":
		frase += " " + tr("CAUSA_" + contexto.to_upper())
	y += _t(frase, x, y, 14, Desenho.TEXTO, w, HORIZONTAL_ALIGNMENT_LEFT, true) + 4
	if not missao.tem_conserto:
		y += _t(tr("SEM_CONSERTO"), x, y, 13, Desenho.TEXTO, w) + 4
	y += 4

	# O caso real.
	var h_caso := 62.0
	var rc := Rect2(x, y, w, h_caso)
	_caixa(rc, Desenho.FUNDO_TELA)
	var caso := missao.caso_real().to_upper()
	_t(tr("CASO_REAL_" + caso), rc.position.x + 10, rc.position.y + 6, 11, Desenho.TEXTO_SUAVE, w - 20,
		HORIZONTAL_ALIGNMENT_LEFT, true)
	_t(tr("CASO_TEXTO_" + caso), rc.position.x + 10, rc.position.y + 22, 12, Desenho.TEXTO, w - 20)

	# Os modos da missão ficam embaixo do botão, para o quadro do caso real ter o espaço do pior caso.
	var y_modos := r.end.y - 18
	Desenho.icone(self, "alerta", Rect2(x, y_modos + 1, 12, 12), Desenho.TEXTO, Desenho.FUNDO_TERMINAL)
	_t(tr("MODOS_NA_MISSAO") % missao.modos, x + 18, y_modos, 12, Desenho.TEXTO, w - 18)

	# Um botão só: reinicia (há conserto) ou segue (não há).
	var rb := Rect2(x, r.end.y - 66, 260, 46)
	if missao.tem_conserto:
		_botao("reiniciar", rb, tr("REINICIA_O_SOL"), "", true, 13)
		_t(tr("VOLTA_AO_PLANO") % missao.sol, rb.end.x + 14, rb.position.y + 14, 12, Desenho.TEXTO_SUAVE, w - 280)
	else:
		_botao("seguir", Rect2(x, r.end.y - 66, 300, 46), tr("SEGUIR_EM_SEGURANCA"), "", true, 13)
		_t(tr("SEGUIR_NOTA"), x + 314, rb.position.y + 6, 11, Desenho.TEXTO_SUAVE, w - 314)


# --- relatório -------------------------------------------------------------------

func _desenhar_relatorio() -> void:
	var x := X_ESQ
	_t(tr("RELATORIO_TITULO"), x, 12, 16, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	_t(tr("RELATORIO_SUB") % Modelo.N.SOLS, x, 31, 11, Desenho.TEXTO_SUAVE)
	# Estrelas.
	var estrelas := missao.estrelas()
	for i in 3:
		Desenho.icone(self, "estrela" if i < estrelas else "estrela_vazia", Rect2(544 + i * 27, 11, 22, 22),
			Desenho.TEXTO, Desenho.FUNDO_TERMINAL)
	_t(tr("N_DE_3_ESTRELAS") % estrelas, 280, 11, 14, Desenho.TEXTO, 254, HORIZONTAL_ALIGNMENT_RIGHT, true)
	_t(tr("ESTRELAS_NOTA"), 280, 34, 10, Desenho.TEXTO_SUAVE, 346, HORIZONTAL_ALIGNMENT_RIGHT)

	# Três blocos.
	var y := 52.0
	var bw := 196.0
	var rects := [Rect2(x, y, bw, 52), Rect2(x + bw + 12, y, bw, 52), Rect2(x + 2 * (bw + 12), y, bw, 52)]
	_caixa(rects[0])
	Desenho.icone(self, "ciencia", Rect2(rects[0].position.x + 10, y + 14, 22, 22), Desenho.TEXTO, Desenho.FUNDO_TELA)
	_t(tr("CIENCIA"), rects[0].position.x + 42, y + 8, 11, Desenho.TEXTO_SUAVE)
	_t(tr("N_PONTOS") % missao.ciencia_total(), rects[0].position.x + 42, y + 22, 18, Desenho.TEXTO, bw - 50,
		HORIZONTAL_ALIGNMENT_LEFT, true)
	_caixa(rects[1])
	Desenho.icone(self, "radiacao", Rect2(rects[1].position.x + 10, y + 14, 22, 22), Desenho.RADIACAO, Desenho.FUNDO_TELA)
	_t(tr("MARGEM_FINAL"), rects[1].position.x + 42, y + 8, 11, Desenho.TEXTO_SUAVE)
	_t(tr("N_DE_12") % roundi(missao.st["M"]), rects[1].position.x + 42, y + 22, 18, Desenho.TEXTO, 90,
		HORIZONTAL_ALIGNMENT_LEFT, true)
	Desenho.celulas(self, Rect2(rects[1].position.x + 118, y + 28, 68, 8), missao.st["M"], 12, Desenho.RADIACAO)
	_caixa(rects[2])
	Desenho.icone(self, "alerta", Rect2(rects[2].position.x + 10, y + 14, 22, 22), Desenho.TEXTO, Desenho.FUNDO_TELA)
	_t(tr("MODOS_SEGURANCA"), rects[2].position.x + 42, y + 8, 11, Desenho.TEXTO_SUAVE, bw - 50)
	_t(str(missao.modos), rects[2].position.x + 42, y + 22, 18, Desenho.TEXTO, 60, HORIZONTAL_ALIGNMENT_LEFT, true)

	# A faixa dos 5 sóis.
	y = 114.0
	var sw := 116.0
	for i in missao.registros.size():
		var reg: Dictionary = missao.registros[i]
		var rs := Rect2(x + i * (sw + 8), y, sw, 40)
		_caixa(rs)
		Desenho.icone(self, "sol", Rect2(rs.position.x + 8, y + 8, 14, 14), Desenho.TEXTO, Desenho.FUNDO_TELA)
		_t(tr("SOL_N") % reg["sol"], rs.position.x + 26, y + 6, 11, Desenho.TEXTO_SUAVE)
		_t("+%d" % reg["ciencia"], rs.position.x + 8, y + 22, 14, Desenho.TEXTO, 60, HORIZONTAL_ALIGNMENT_LEFT, true)
		var xi := rs.end.x - 22
		if reg["seguranca"]:
			Desenho.icone(self, "alerta", Rect2(xi, y + 20, 16, 16), Desenho.AMARELO, Desenho.FUNDO_TELA)
			xi -= 20
		if reg["tempestade"]:
			Desenho.icone(self, "tempestade", Rect2(xi, y + 20, 16, 16), Desenho.TEXTO, Desenho.FUNDO_TELA)
			xi -= 20
		if reg["poeira"]:
			Desenho.icone(self, "poeira", Rect2(xi, y + 20, 16, 16), Desenho.TEXTO, Desenho.FUNDO_TELA)

	# O que aconteceu de verdade.
	# O quadro vai até 274, logo acima do botão: o texto vai em 13 px se couber; senão, em 12 px (o
	# português de 15/11 tem 4 linhas).
	y = 158.0
	_t(tr("DE_VERDADE"), x, y, 13, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	var rv := Rect2(x, y + 20, 612, 96)
	_caixa(rv)
	_t(tr("DE_VERDADE_DATA"), rv.position.x + 10, rv.position.y + 7, 11, Desenho.TEXTO_SUAVE, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	var de_verdade := tr("DE_VERDADE_TEXTO")
	var tam_dv := 13 if Desenho.altura_texto(de_verdade, 13, rv.size.x - 20) <= rv.size.y - 26 else 12
	_t(de_verdade, rv.position.x + 10, rv.position.y + 24, tam_dv, Desenho.TEXTO, rv.size.x - 20)
	_botao("jogar_de_novo", Rect2(220, 276, 200, 40), tr("JOGAR_DE_NOVO"), "", true, 14)
