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
## A página do diário (pagina_diario.gd, que a main desenha por cima de tudo) abre cada sol da missão fixa antes
## de qualquer card: é o primeiro item da fila do plano ("pagina_<sol>"), uma vez por sol por sessão, e segura os
## cards até fechar (fechar_pagina).
##
## O card do primeiro turno (só no sol 1 da missão fixa, uma vez por sessão) abre quando o terminal chega
## embaixo, sobre a sala, perto do botão TERMINAL. O relógio do turno só corre depois que ele fecha
## (segura_o_relogio, que a main lê); com ele aberto a sala não se clica e o botão TERMINAL fica apagado.
##
## Encerrar o sol não é botão do terminal: é a porta do dormitório, na sala (main.gd).
## Card da primeira vez com confirmação (pedir_confirmacao): na primeira vez que a criança toca uma ação da
## sala no turno, abre um card azul embaixo, como o do primeiro turno, com "o que a ação faz" e dois botões;
## a ação só roda se ela confirmar. O relógio fica parado e a sala não se clica enquanto ele está aberto. Vale
## uma vez por carregamento da página, por ação: a flag mora em `_vistos`, que a missão não toca (o reinício
## do sol restaura a missão, não o terminal).
## A aba câmeras é o visor (scripts/cameras/visor_cameras.gd), filho deste nó, por cima da aba. Ele só
## aparece com a aba na tela, o terminal parado no alto, sem card e sem escurecer. Escolher a câmera de
## uma tarefa de POR_PECA (missao.gd) pendente começa a tarefa e põe a peça dela (ChemCam, gerador) na
## vista; a planta e a amostra começam pela estação da sala (abrir_na_estacao), sem botão aqui; a peça é quem conclui a tarefa (concluir_tarefa), e sai quando a tarefa deixa de rodar. Na aba
## tarefas, o botão da linha (ir_chemcam, ir_gerador) leva à câmera. Com o visor à vista, o clique dentro
## dele não é consumido aqui: segue para o visor e para a peça.
##
## Na aba fontes, a coluna da direita (de onde vêm os números) só rola quando a lista não cabe nem na fonte
## compacta: aí a lista é desenhada por um filho (scripts/coluna_fontes.gd) que recorta e rola, e o clique
## dentro dele segue para ele. Quando a lista cabe, o filho fica escondido e nada muda.
##
## Cores [R]: verde só no que se clica; vermelho e amarelo só em alerta; azul só no que vem da Terra.

const Missao := preload("res://scripts/missao.gd")
const Som := preload("res://scripts/som.gd")
const Modelo := preload("res://scripts/modelo.gd")
const Desenho := preload("res://scripts/desenho.gd")
const Prancha := preload("res://scripts/prancha.gd")
const DadosDonki := preload("res://scripts/dados_donki.gd")
const HudTurno := preload("res://scripts/hud_turno.gd")
const PonteiroTutorial := preload("res://scripts/ponteiro_tutorial.gd")
const Abertura := preload("res://scripts/abertura/abertura.gd")
const VisorCameras := preload("res://scripts/cameras/visor_cameras.gd")
const ColunaFontes := preload("res://scripts/coluna_fontes.gd")
const Chemcam := preload("res://scripts/minigames/chemcam.gd")
const ConsertarGerador := preload("res://scripts/minigames/consertar_gerador.gd")
const CultivarPlanta := preload("res://scripts/minigames/cultivar_planta.gd")
const SelarAmostra := preload("res://scripts/minigames/selar_amostra.gd")
const MovimentoAviso := preload("res://scripts/movimento_aviso.gd")
const SeloCiencia := preload("res://scripts/selo_ciencia.gd")
const TelaInicial := preload("res://scripts/tela_inicial_terminal.gd")

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
const CARD_TEXTO := {"sol1_o2": "SOL1_CARD_O2", "sol1_ciencia": "SOL1_CARD_CIENCIA", "sol1_confirmar": "SOL1_CARD_CONFIRMAR",
	"poeira": "CARD_POEIRA", "gerador": "CARD_GERADOR"}
const CARD_ALVO := {"sol1_o2": "o2", "sol1_ciencia": "ciencia", "sol1_confirmar": "confirmar", "poeira": "poeira",
	"gerador": "gerador"}
const CARDS_SOL1 := ["sol1_o2", "sol1_ciencia", "sol1_confirmar"]
const CARD_LARGURA := 236.0
const CARD_TAM := 13
# Os cards ficam na coluna que não tem o controle: a da esquerda tem o O2 e a ciência; a da direita, o confirmar.
const CARD_X_DIREITA := 372.0
const CARD_X_ESQUERDA := 98.0
# O card do primeiro turno: embaixo, acima do botão TERMINAL, longe do medidor (no alto da sala) e das setas
# (nas bordas, de y 120 a 240).
const CARD_TURNO_LARGURA := 340.0
const CARD_TURNO_FUNDO := 322.0
# O card de confirmação é mais estreito e escolhe o x: nunca cobre as telas das barras nem o medidor (zonas_a_evitar),
# entre as setas (que ficam nas bordas, de x 0 a 48 e de 592 a 640).
const CARD_CONF_LARGURA := 300.0
const CARD_CONF_X_MIN := 52.0
const CARD_CONF_X_MAX := 588.0
# O card entra pela borda esquerda: anda esta distância (px) até o lugar (movimento do primo, movimento_aviso.gd).
const CARD_DISTANCIA := 400.0

# Tela cheia (relatório).
const X_ESQ := 14.0

const ROTULOS_TAREFA := {"chemcam": "TAREFA_CHEMCAM", "amostra": "TAREFA_AMOSTRA", "planta": "TAREFA_PLANTA",
	"gerador": "TAREFA_GERADOR"}
# Tarefa -> câmera onde ela se faz, e a peça (minigame) de cada uma; o som de começar pela câmera.
# A planta e a amostra não têm câmera nem botão no terminal: começam na estação da sala (a estufa, a glovebox)
# e, aqui, só aparecem como linha com estado e andamento. A estação é onde o visor hospeda a peça delas.
const CAMERA_DA_TAREFA := {"chemcam": "rocha", "gerador": "moxie"}
const ESTACAO_DA_TAREFA := {"planta": "estufa", "amostra": "glovebox"}
const PECAS := {"chemcam": Chemcam, "gerador": ConsertarGerador, "planta": CultivarPlanta, "amostra": SelarAmostra}
const SOM_DE_INICIAR := {"chemcam": "iniciar_chemcam", "gerador": "consertar_gerador", "planta": "estufa",
	"amostra": "glovebox"}
const PARES_FONTES := ["O2", "MOXIE", "LIMITE", "RAD", "ESCALA", "PAINEL", "ATRASO"]
# A coluna "de onde vêm os números" da aba fontes: a caixa, o interior dela (onde o filho recorta) e a margem
# da lista dentro do interior. A lista começa 7 px abaixo da caixa e 8 px à direita da borda; a faixa de 8 px
# na direita (largura da lista = caixa − 16) fica livre para o indicador de rolagem.
const FONTES_CAIXA := Rect2(X0 + 186.0, Y_CORPO, X1 - X0 - 186.0, Y_FIM - Y_CORPO)
const FONTES_MARGEM_X := 8.0
const FONTES_MARGEM_Y := 7.0
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
var com_inicio := false     # o plano e o fim do sol abrem na tela inicial do terminal (a main liga; ver _mostrar_na_tela)
var gravar_textos := false  # só com a sonda de teste ligada (main.gd, ?sonda=1)
## As zonas da tela (Rect2, px da tela de 640x360) que o card de confirmação não pode cobrir: as barras e o medidor,
## como a sala os mostra agora (a main as liga). Sem ela, o card fica no centro.
var zonas_a_evitar := Callable()
var rect_do_card_confirmacao := Rect2()  # onde o último quadro desenhou o card de confirmação (a sonda e os testes leem)
var com_pagina := false     # o plano de cada sol da missão fixa abre com a página do diário (a main liga; ver _tem_pagina)

var _fase_logica := "plano"
var _modos_vistos := 0      # quantas entradas no modo de segurança o terminal já viu (cada uma toca o desligar)
var _fase_tela := "plano"   # a fase que o terminal desenha (ver o cabeçalho)
var _pos := 1.0             # 0 = abaixado, 1 = no alto; anda até `aberto` em `duracao` s
var _fade := 0.0
var _fade_estado := ""      # "", "escurecendo" ou "clareando"
var _botoes := {}           # nome -> Rect2, só o que se clica agora
var _travado := false       # card aberto: o que está por baixo é desenhado mas não se clica
var _fila: Array = []       # os cards que ainda faltam abrir neste plano
var _inicio := false        # a tela inicial (os blocos) está na tela: as abas e os cards do plano esperam a criança escolher
var _vistos := {}           # card -> true: o que já abriu nesta sessão (os do sol 1 não voltam)
var _alvos := {}            # nome -> Rect2 dos controles que um card pode apontar, como o último quadro os pôs
var _ponteiro: Control      # a seta e a moldura pulsante do card ao lado de um controle (ponteiro_tutorial.gd)
var _textos: Array = []     # [texto, x, y, tamanho] de tudo que o quadro desenhou (para a sonda de teste)
var _mouse := Vector2(-100, -100)
var _hover := ""
var _versao_vista := -1
var _alarmou := false       # o alarme já tocou nesta travessia do limiar de abrigo
var _segura_turno := false  # o card do primeiro turno ainda não fechou: o relógio não corre
var _confirma_id := ""      # a ação do card de confirmação aberto ("" = nenhum); card_id é "confirmacao"
var _confirma_acao := Callable()  # o que roda se a criança confirmar
var _visor: VisorCameras    # o corpo da aba câmeras
var _visor_chave := ""      # "sol|poeira" da última configuração do visor
var _visor_pend := {}       # as últimas pendências enviadas ao visor
var _coluna: ColunaFontes   # a coluna da direita da aba fontes, quando a lista rola
var _textos_col: Array = [] # o que o filho desenhou no último quadro dele (mesmo formato de _textos)
var _alvo: CanvasItem       # onde _t desenha: null = este nó; o filho enquanto ele desenha a lista
var _origem := Vector2.ZERO # somado às posições que _t grava quando desenha no filho (coordenadas da tela)
var _plano_chave := ""      # o idioma do último _plano_fontes
var _plano := {}
var _card_t := 0.0          # s desde que o card da tela chegou à vista (a entrada com o movimento do primo)
var _card_anim_id := ""     # o card a que _card_t se refere
var _alerta_visto := false  # o alerta do medidor estava por cima do terminal no quadro anterior
var _vermelho_visto := false  # e estava vermelho (o limiar de abrigo, o do alarme)
var _alerta_t := 99.0       # s desde que o alerta apareceu por cima do terminal (o tremor)
var _flash_t := 99.0        # s desde o flash de tela do alerta
var _flash_dado := false    # já deu o flash nesta travessia do limiar de abrigo (um flash só)
var _ciencia_vista := 0     # a ciência feita no turno, no quadro anterior
var _selo_n := 0            # o "+N" do selo de ciência (0 = nenhum)
var _selo_t := 99.0         # s desde que o selo nasceu


func iniciar(m: Missao, dado_donki: Dictionary) -> void:
	missao = m
	donki = dado_donki
	_fase_logica = m.fase
	_modos_vistos = m.modos
	_mostrar_fase(m.fase)
	aberto = _abre_na_fase(m.fase)
	_pos = 1.0 if aberto else 0.0
	if _visor == null:
		_visor = VisorCameras.new()
		add_child(_visor)
		_visor.camera_escolhida.connect(_ao_escolher_camera)
	if _ponteiro == null:
		_ponteiro = PonteiroTutorial.new()
		add_child(_ponteiro)
		desenhou.connect(_ponteiro.terminar_quadro)
	_visor_chave = ""
	_visor_pend = {}
	if _coluna == null:
		_coluna = ColunaFontes.new()
		_coluna.terminal = self
		add_child(_coluna)
		_coluna.rolou.connect(queue_redraw)
	_coluna.zerar()
	_atualizar_visor()
	_atualizar_coluna()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Nome -> [x, y, w, h] do que se clica agora no terminal (px da tela de 640x360).
func ui() -> Dictionary:
	var d := {}
	for nome: String in _botoes:
		var r: Rect2 = _botoes[nome]
		d[nome] = [roundi(r.position.x), roundi(r.position.y), roundi(r.size.x), roundi(r.size.y)]
	# Com o visor à vista, o botão de cada câmera do mapa (em px da tela). Não entram em _botoes: quem trata
	# o clique é o visor.
	if _visor != null and _visor.visible:
		var origem := _visor.get_global_rect().position
		var alvos := _visor.alvos()
		for cam: String in alvos:
			var r: Rect2 = alvos[cam]
			d["cam_" + cam] = [roundi(origem.x + r.position.x), roundi(origem.y + r.position.y), roundi(r.size.x), roundi(r.size.y)]
	return d


## O que a peça (minigame) à vista oferece, em px da tela, para o teste no navegador (a sonda de main.gd).
## Vazio sem peça visível. ChemCam: "alvos" (o centro de cada alvo pendente) e "raio". Gerador: "pecas" (o
## retângulo de cada peça na bandeja), "certa" (o índice da peça que encaixa), "formas" e "encaixe" (o centro).
func minigame() -> Dictionary:
	if _visor == null or not _visor.visible:
		return {}
	var p := _visor.peca(_visor.vista_atual())
	if p == null or not p.visible:
		return {}
	var m := p.get_global_transform()
	if p.has_method("alvos_na_area"):
		var alvos: Array = []
		var locais: PackedVector2Array = p.alvos_na_area()
		for i in locais.size():
			if p.estado_alvo(i) == "pendente":
				var c: Vector2 = m * locais[i]
				alvos.append([roundi(c.x), roundi(c.y)])
		return {"tipo": "chemcam", "alvos": alvos, "raio": p.raio_toque(), "progresso": p.progresso()}
	if p.has_method("centro_do_encaixe"):
		var pecas: Array = []
		for i in 3:
			var r: Rect2 = p.alvo_da_peca(i)
			var o: Vector2 = m * r.position
			pecas.append([roundi(o.x), roundi(o.y), roundi(r.size.x), roundi(r.size.y)])
		var sorteio: Dictionary = p.sorteio_atual()
		var e: Vector2 = m * p.centro_do_encaixe()
		return {"tipo": "gerador", "pecas": pecas, "certa": sorteio["certa"], "formas": sorteio["formas"],
			"encaixe": [roundi(e.x), roundi(e.y)], "progresso": p.progresso()}
	if p.has_method("retangulo_do_botao"):
		var botoes := {}
		for c in 2:
			for mais in [false, true]:
				var rb: Rect2 = p.retangulo_do_botao(c, mais)
				var ob: Vector2 = m * rb.position
				botoes["%s_%s" % [["luz", "agua"][c], "mais" if mais else "menos"]] = [roundi(ob.x), roundi(ob.y), roundi(rb.size.x), roundi(rb.size.y)]
		return {"tipo": "planta", "botoes": botoes, "luz": p.nivel(0), "agua": p.nivel(1), "progresso": p.progresso()}
	if p.has_method("alvo_do_passo"):
		var a: Rect2 = p.alvo_do_passo()
		var o: Vector2 = m * a.position
		return {"tipo": "amostra", "passo": p.passo(), "alvo": [roundi(o.x), roundi(o.y), roundi(a.size.x), roundi(a.size.y)],
			"profundidade": p.profundidade(), "graus": p.graus(), "progresso": p.progresso()}
	return {}


## Todo texto que o último quadro desenhou: [texto, x, y, tamanho, largura (-1 sem quebra), alinhamento, negrito, fonte própria (ou null)].
func textos() -> Array:
	var t := _textos.duplicate()
	if _coluna != null and _coluna.visible:
		t.append_array(_textos_col)  # a lista que o filho desenha, já com a rolagem aplicada
	return t


## A rolagem da coluna da direita da aba fontes (a sonda de teste lê). `ligada`: a aba está na tela e a lista não
## cabe (nem na fonte compacta), então ela rola; `rolagem` e `maximo` em px; `recorte` é [x, y, w, h] do retângulo
## que recorta, na tela sem o deslocamento da animação (vazio se desligada); `mais_embaixo`: o indicador está aceso.
func rolagem_fontes() -> Dictionary:
	var plano := _plano_fontes() if aba_na_tela() == "fontes" and missao != null else {}
	var ligada: bool = not plano.is_empty() and plano["ligada"]
	if not ligada or _coluna == null:
		return {"ligada": false, "rolagem": 0.0, "maximo": 0.0, "recorte": [], "mais_embaixo": false}
	var r := _interior_coluna()
	var maximo: float = plano["maximo"]
	return {"ligada": true, "rolagem": _coluna.rolagem, "maximo": maximo,
		"recorte": [roundi(r.position.x), roundi(r.position.y), roundi(r.size.x), roundi(r.size.y)],
		"mais_embaixo": _coluna.rolagem < maximo - 0.5}


## A aba na tela: "plano", "cameras", "tarefas", "diario" ou "fontes"; "" nas fases sem teclas.
func aba_na_tela() -> String:
	if not _tem_teclas(_fase_tela):
		return ""
	if _inicio:
		return "inicio"
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


## O card da tela está à vista? Os do plano, com o terminal no alto; o do primeiro turno, com ele embaixo.
func _card_visivel() -> bool:
	if _card_sobre_a_sala():
		return _pos <= 0.0
	return _pos > 0.0 and _fase_tela == "plano" and card_aberto


## O card da tela é dos que ficam sobre a sala, com o terminal embaixo (o do primeiro turno e o de confirmação)?
func _card_sobre_a_sala() -> bool:
	return card_id == "turno" or card_id == "confirmacao"


## O relógio do turno espera? Do "Confirmar plano" do sol 1 da missão fixa até o card do primeiro turno fechar
## (uma vez por sessão), e enquanto um card de confirmação está aberto. A main não avança a missão enquanto isto vale.
func segura_o_relogio() -> bool:
	if missao == null:
		return false
	if _segura_turno or card_id == "confirmacao":
		return true
	# Já no quadro em que a missão entrou no turno, antes de o terminal ver a troca de fase.
	return missao.fase == "turno" and _fase_logica != "turno" and _tem_card_de_turno()


func _tem_card_de_turno() -> bool:
	return not missao.livre and missao.sol == 1 and not _vistos.has("turno")


## A tela passa a mostrar a fase `f`: zera a aba e, no plano, monta a fila de cards.
func _mostrar_fase(f: String) -> void:
	fase_ui = f
	_mostrar_na_tela(f)


## O terminal passa a desenhar a fase `f`: zera a aba e, no plano, monta a fila de cards e abre o primeiro.
func _mostrar_na_tela(f: String) -> void:
	_fase_tela = f
	aba = ""
	_zerar_rolagem()
	_confirma_id = ""
	_confirma_acao = Callable()
	_inicio = com_inicio and TelaInicial.vale_na_fase(f)
	_fila = _cards_do_plano() if f == "plano" else []
	card_id = ""
	_abrir_proximo()


## Os cards deste plano, na ordem: o aviso da tempestade (reabre em todo plano em que está ativo, inclusive no
## reinício do sol), depois os do sol 1 da missão fixa e os da primeira vez da poeira e do gerador quebrado.
## Cada um só abre uma vez por sessão: "primeira vez" é o primeiro plano que a criança de fato vê com o evento
## (um sol que já começa em modo de segurança não monta plano, e o card fica para o próximo plano em que o
## evento ainda vale).
func _cards_do_plano() -> Array:
	var fila: Array = []
	if _tem_pagina():
		fila.append("pagina_%d" % missao.sol)
	if missao.aviso_ativo():
		fila.append("aviso")
	if not missao.livre and missao.sol == 1:
		for id: String in CARDS_SOL1:
			if not _vistos.has(id):
				fila.append(id)
	if missao.eh_poeira() and not _vistos.has("poeira"):
		fila.append("poeira")
	if missao.st_inicio.get("gerador_quebrado", false) and not _vistos.has("gerador"):
		fila.append("gerador")
	return fila


## O plano deste sol abre com a página do diário? Só se o hospedeiro a quer (com_pagina), só na missão fixa, só nos sóis que têm história, uma vez por sol.
func _tem_pagina() -> bool:
	var chave := "DIARIO_HISTORIA_%d" % missao.sol
	return com_pagina and not missao.livre and tr(chave) != chave and not _vistos.has("pagina_%d" % missao.sol)


## O sol da página do diário que está na tela agora (0 se o item da vez não é a página).
func sol_da_pagina() -> int:
	return int(card_id.trim_prefix("pagina_")) if card_id.begins_with("pagina_") else 0


## A página fechou: abre o próximo item da fila (os cards do plano).
func fechar_pagina() -> void:
	if sol_da_pagina() > 0:
		_abrir_proximo()
		queue_redraw()


## Abre o próximo card da fila (ou deixa a tela sem card). O card se marca visto quando abre.
func _abrir_proximo() -> void:
	if _fila.is_empty():
		card_id = ""
		return
	if _inicio and not str(_fila[0]).begins_with("pagina_"):
		card_id = ""  # a tela inicial vai antes: os cards do plano esperam a criança sair dela
		return
	card_id = _fila.pop_front()
	_vistos[card_id] = true


## Pede a confirmação da primeira vez de uma ação da sala, para quem chama (a main). `id` nomeia a ação e os
## textos do card: CONFIRMA_<ID> (o que a ação faz), CONFIRMA_<ID>_SIM e CONFIRMA_<ID>_NAO (os botões), em
## textos/textos.csv. `ao_confirmar` é o que a ação faz; roda só se a criança confirmar.
## Devolve true se o card abriu (quem chama não age: a ação espera a confirmação) e false se a criança já viu o
## card dessa ação neste carregamento da página (quem chama age direto). Confirmar ou cancelar conta como visto.
## Só abre com o terminal embaixo e sem outro card; senão devolve true sem abrir (a ação não roda).
func pedir_confirmacao(id: String, ao_confirmar: Callable) -> bool:
	var chave := "confirmacao_" + id
	if _vistos.has(chave):
		return false
	if aberto or _pos > 0.0 or card_aberto:
		return true
	_vistos[chave] = true
	_confirma_id = id
	_confirma_acao = ao_confirmar
	card_id = "confirmacao"
	queue_redraw()
	return true


## Fecha o card de confirmação e devolve o que ele guardava para rodar (vazio se não havia).
func _fechar_confirmacao() -> Callable:
	var acao := _confirma_acao
	_confirma_id = ""
	_confirma_acao = Callable()
	card_id = ""
	return acao


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
	_atualizar_visor()
	_atualizar_coluna()
	# O card do primeiro turno abre quando o terminal chega embaixo.
	if _segura_turno and card_id == "" and not aberto and _pos <= 0.0 and fase_ui == "turno":
		card_id = "turno"
		_vistos["turno"] = true
		animou = true
	animou = _avancar_avisos(delta) or animou
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
	_segura_turno = para == "turno" and _tem_card_de_turno()
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
		elif _visor != null and _visor.visible and _visor.get_global_rect().has_point(event.position):
			pass  # o clique segue para o visor e para a peça hospedada (o _gui_input deles)
		elif _coluna != null and _coluna.visible and _coluna.get_global_rect().has_point(event.position):
			pass  # a coluna das fontes, quando rola, trata o clique (o _gui_input dela)
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
	if card_aberto and nome != "fechar_card" and not (card_id == "confirmacao" and nome in ["card_confirmar", "card_cancelar"]):
		return
	var fez := true
	match nome:
		"terminal":
			_definir_aberto(not aberto)
		"fechar_card":
			_abrir_proximo()
			if card_id == "":
				_segura_turno = false
		"card_confirmar":
			var acao := _fechar_confirmacao()
			if acao.is_valid():
				acao.call()
		"card_cancelar":
			_fechar_confirmacao()
		"voltar_plano":
			aba = ""
			_zerar_rolagem()
			_liberar_cards()
		"inicio_fase":
			fez = _sair_do_inicio("")
			nome = "voltar_plano"  # o som do clique
		"inicio_cameras", "inicio_tarefas", "inicio_diario", "inicio_fontes":
			var destino := nome.trim_prefix("inicio_")
			fez = _sair_do_inicio(destino)
			nome = "aba_" + destino
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
		"ir_chemcam", "ir_gerador":
			# A linha da tarefa leva à câmera dela. Se a tarefa está pendente, escolher a câmera a começa.
			var tarefa := nome.trim_prefix("ir_")
			fez = _pode_ir_a_camera(tarefa)
			if fez:
				aba = "cameras"
				_visor.escolher(CAMERA_DA_TAREFA[tarefa])
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
	if _inicio:
		return _sair_do_inicio(nome)  # a tecla da moldura vai direto à aba, sem passar pelos blocos
	aba = "" if aba_na_tela() == nome else nome
	if aba == _aba_da_fase(_fase_tela):
		aba = ""
	_zerar_rolagem()
	_liberar_cards()
	return true


## A criança saiu da tela inicial: para a tela da fase (`destino` vazio) ou para uma aba. Os cards do plano que
## esperavam abrem quando a tela do plano chega à vista.
func _sair_do_inicio(destino: String) -> bool:
	if not _inicio or (destino != "" and not _aba_habilitada(destino)):
		return false
	_inicio = false
	aba = "" if destino == _aba_da_fase(_fase_tela) else destino
	_zerar_rolagem()
	_liberar_cards()
	return true


## Os cards que a tela inicial segurou abrem quando a tela do plano está à vista (e não por cima de uma aba).
func _liberar_cards() -> void:
	if _fase_tela == "plano" and aba == "" and not _inicio and card_id == "" and not _fila.is_empty():
		_abrir_proximo()


# --- aba câmeras: o visor e as peças -------------------------------------------------

## O visor só aparece com a aba câmeras na tela, o terminal parado no alto, sem card e sem escurecer. Leva o
## sol, o clima e as pendências, e tira a peça cuja tarefa deixou de rodar (feita, abrigo, fim do turno,
## reinício). Roda todo quadro, com o visor à vista ou não.
func _atualizar_visor() -> void:
	if _visor == null:
		return
	var no_turno := missao.fase == "turno" and not missao.abrigado
	_visor.visible = aba_na_tela() == "cameras" and _pos >= 1.0 and not _card_visivel() and _fade_estado == ""
	var pend := {}
	for tarefa: String in PECAS:
		var cam := _lugar_da_peca(tarefa)
		var estado: String = missao.tarefas.get(tarefa, "")
		var rodando := no_turno and missao.tarefa_rodando == tarefa
		if CAMERA_DA_TAREFA.has(tarefa):  # as estações da sala não são câmera do mapa: sem pendência
			pend[cam] = no_turno and (estado == "pendente" or rodando)
		if _visor.peca(cam) != null and not rodando:
			_visor.hospedar(cam, null)
	var chave := "%d|%s" % [missao.sol, missao.eh_poeira()]
	if chave != _visor_chave:
		_visor_chave = chave
		_visor.configurar(Rect2(X0, Y_CORPO, X1 - X0, Y_FIM - Y_CORPO), missao.tarefa_s, missao.eh_poeira())
		_visor.sol(missao.sol, Modelo.N.SOLS)
		_visor_pend = {}  # configurar zera as pendências do visor: reenvia
	if pend != _visor_pend:  # pendencias() redesenha: só quando muda
		_visor_pend = pend
		_visor.pendencias(pend)


## A criança escolheu uma câmera. A tarefa dela pendente, sem outra rodando, no turno e fora do abrigo,
## começa e a peça entra na vista. Se a tarefa já roda, só se mostra a peça que está lá. Outra tarefa
## rodando (amostra, planta): nada começa, o marcador fica.
func _ao_escolher_camera(cam: String) -> void:
	for tarefa: String in PECAS:
		if _lugar_da_peca(tarefa) != cam:
			continue
		if missao.tarefa_rodando == tarefa:
			if _visor.peca(cam) == null:
				_hospedar_peca(tarefa)  # rodando sem peça (não deveria): só então se cria
		elif missao.iniciar_tarefa(tarefa):
			_hospedar_peca(tarefa)
			if som != null:
				som.clique(SOM_DE_INICIAR[tarefa])
		return


func _hospedar_peca(tarefa: String) -> void:
	var peca: Control = PECAS[tarefa].new()
	if peca.has_method("semente"):
		peca.semente(missao.sol * 100 + missao.modos)  # muda a cada conserto e segue determinística
	peca.concluido.connect(_ao_concluir_peca.bind(tarefa))
	_visor.hospedar(_lugar_da_peca(tarefa), peca)


## Onde o visor hospeda a peça da tarefa: a câmera dela (ChemCam, gerador) ou a estação da sala (planta, amostra).
func _lugar_da_peca(tarefa: String) -> String:
	return CAMERA_DA_TAREFA.get(tarefa, ESTACAO_DA_TAREFA.get(tarefa, ""))


## A peça terminou: a tarefa vira feita; o quadro seguinte tira a peça.
func _ao_concluir_peca(tarefa: String) -> void:
	missao.concluir_tarefa(tarefa)
	queue_redraw()


## Tocar na estação da sala (a estufa, a glovebox): a tarefa começa, o terminal sobe já na aba câmeras com a
## peça dela à vista e a peça fica hospedada. Se a tarefa já roda (o terminal foi abaixado no meio), a mesma
## peça volta à vista, sem recriar. O som de começar é o clique da própria estação (main.gd), por isso aqui não
## toca. Devolve se aconteceu.
func abrir_na_estacao(tarefa: String) -> bool:
	if not ESTACAO_DA_TAREFA.has(tarefa) or not _pode_ir_a_camera(tarefa):
		return false
	if missao.tarefa_rodando != tarefa:
		missao.iniciar_tarefa(tarefa)
		_hospedar_peca(tarefa)
	elif _visor.peca(_lugar_da_peca(tarefa)) == null:
		_hospedar_peca(tarefa)
	aba = "cameras"
	_zerar_rolagem()
	_definir_aberto(true)
	_visor.escolher(_lugar_da_peca(tarefa))
	queue_redraw()
	return true


## O botão da linha da tarefa vale no turno, fora do abrigo, quando a tarefa roda ou está pendente e
## nenhuma outra roda.
func _pode_ir_a_camera(tarefa: String) -> bool:
	if missao.fase != "turno" or missao.abrigado:
		return false
	if missao.tarefa_rodando == tarefa:
		return true
	return missao.tarefas.get(tarefa, "") == "pendente" and missao.tarefa_rodando == ""


## O andamento da tarefa `nome` (0 a 1): a peça hospedada, para a tarefa que só acaba por ela; o relógio,
## para as demais. A barra da linha e a barra da estação na sala leem daqui.
func progresso_da_tarefa(nome: String) -> float:
	return _progresso_da_linha(nome)


## A barra da linha: a peça hospedada, para a tarefa que só acaba por ela; o relógio, para as demais.
func _progresso_da_linha(nome: String) -> float:
	if nome in Missao.POR_PECA:
		var peca: Control = _visor.peca(_lugar_da_peca(nome)) if _visor != null else null
		return clampf(peca.progresso(), 0.0, 1.0) if peca != null else 0.0
	return missao.progresso_tarefa(nome)


# --- desenho: peças ------------------------------------------------------------

func _t(s: String, x: float, y: float, tam: int = 11, cor: Color = Desenho.TEXTO, largura: float = -1.0,
		alinh: int = HORIZONTAL_ALIGNMENT_LEFT, negrito: bool = false, fonte_propria: Font = null) -> float:
	if gravar_textos:
		# No filho (_alvo), x e y são locais a ele; a sonda e os testes leem em coordenadas da tela.
		var registro := _textos if _alvo == null else _textos_col
		registro.append([s, roundi(x + _origem.x), roundi(y + _origem.y), tam, largura, alinh, negrito, fonte_propria])
	return Desenho.texto(_alvo if _alvo != null else self, s, Vector2(x, y), tam, cor, largura, alinh, negrito, fonte_propria)


func _caixa(r: Rect2, fundo: Color = Prancha.CAIXA, borda: Color = Prancha.BORDA) -> void:
	draw_rect(r, fundo)
	draw_rect(r, borda, false, 1.0)


## Pinta o corpo de um botão e devolve [fundo, cor do texto]. Habilitado entra em ui(), salvo com o
## card aberto por cima (aí é desenhado igual, mas não se clica). Desabilitado fica apagado.
## Pinta o botão e devolve [fundo opaco para os furos do ícone, cor do texto e do ícone]. O estilo padrão é o da
## prancha (contorno claro sobre o papel, estilo do primo); `verde` é o da sala e dos cards azuis da Terra, onde
## o contorno claro não teria contraste. `destaque` põe 3 px de contorno na ação principal da tela.
func _pintar_botao(nome: String, r: Rect2, habilitado: bool, apertado: bool, verde: bool = false,
		destaque: bool = false) -> Array:
	if verde:
		return _pintar_botao_verde(nome, r, habilitado, apertado)
	var camada: Color
	var contorno: Color
	var cor_texto: Color
	if habilitado:
		if not _travado:
			_botoes[nome] = r
		var hover := r.has_point(_mouse) and not _travado
		camada = Prancha.BTN_FUNDO_ATIVO if apertado else (Prancha.BTN_FUNDO_HOVER if hover else Prancha.BTN_FUNDO)
		contorno = Prancha.BTN_CONTORNO
		cor_texto = Prancha.BTN_TEXTO_ATIVO if apertado else Desenho.TEXTO
	else:
		camada = Prancha.BTN_DESAB_FUNDO
		contorno = Prancha.BTN_DESAB_CONTORNO
		cor_texto = Prancha.DESAB_TEXTO
	draw_rect(r, camada)
	Prancha.contorno(self, r, contorno, Prancha.BTN_LARG_DESTAQUE if destaque and habilitado else Prancha.BTN_LARG)
	return [Prancha.CAIXA.blend(camada), cor_texto]


func _pintar_botao_verde(nome: String, r: Rect2, habilitado: bool, apertado: bool) -> Array:
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
		fundo = Color("#1d3556")
		borda = Color("#10233f")
		cor_texto = Prancha.DESAB_TEXTO
	draw_rect(r, borda)
	draw_rect(r.grow(-2.0), fundo)
	return [fundo, cor_texto]


## Botão do painel (veja _pintar_botao). Desabilitado fica apagado e não entra em ui().
func _botao(nome: String, r: Rect2, rotulo: String, icone: String = "", habilitado: bool = true,
		tam: int = 12, apertado: bool = false, verde: bool = false, destaque: bool = false) -> void:
	var cores := _pintar_botao(nome, r, habilitado, apertado, verde, destaque)
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


## A faixa do Painel: triângulo, nome, triângulo, tudo desenhado. Os triângulos apontam para cima com o
## painel embaixo (o botão o sobe) e para baixo com ele no alto (o botão o desce). Seguem `aberto`, que muda
## no toque: durante a subida ou a descida já mostram o destino do próximo toque, sem cálculo por quadro.
func _botao_painel(nome: String, r: Rect2, rotulo: String, habilitado: bool = true, tam: int = 12,
		apertado: bool = false) -> void:
	var cores := _pintar_botao(nome, r, habilitado, apertado, true)  # é da sala: segue verde
	var fundo: Color = cores[0]
	var cor_texto: Color = cores[1]
	var lado := float(tam + 2)
	var y_meio := r.position.y + r.size.y / 2.0
	var icone := "triangulo_baixo" if apertado else "triangulo_cima"
	for x: float in [r.position.x + 10.0, r.end.x - 10.0 - lado]:
		Desenho.icone(self, icone, Rect2(x, y_meio - lado / 2.0, lado, lado), cor_texto, fundo)
	_t(rotulo, r.position.x, y_meio - Desenho.fonte().get_height(tam) / 2.0, tam, cor_texto, r.size.x,
		HORIZONTAL_ALIGNMENT_CENTER, true)


## Tecla da moldura: ícone em cima, palavra embaixo. Mesmo estilo do botão; a da aba na tela fica selecionada.
func _tecla(a: String, r: Rect2) -> void:
	_aro(r)
	draw_rect(r, Prancha.FUNDO)  # a tecla fica sobre a sala: o papel por baixo da camada translúcida do botão
	var cores := _pintar_botao("aba_" + a, r, _aba_habilitada(a), aba_na_tela() == a)
	var fundo: Color = cores[0]
	var cor: Color = cores[1]
	Desenho.icone(self, ICONES_ABA[a], Rect2(r.position.x + (r.size.x - 22.0) / 2.0, r.position.y + 14, 22, 22), cor, fundo)
	_t(tr(ROTULOS_ABA[a]), r.position.x, r.position.y + 44, 11, cor, r.size.x, HORIZONTAL_ALIGNMENT_CENTER, true)


## Uma barra do cabeçalho: ícone, nome, número e células. Com `falha`, leva moldura vermelha e o ícone de alerta.
func _barra(x: float, y: float, w: float, icone: String, nome: String, valor: float, maximo: int,
		falha: bool = false, fundo: Color = Prancha.FUNDO) -> void:
	if falha:
		draw_rect(Rect2(x - 4, y - 4, w + 8, 33), Desenho.VERMELHO, false, 2.0)
	var cor_rec := Desenho.cor_recurso(icone)
	Desenho.icone(self, icone, Rect2(x, y + 1, 12, 12), cor_rec, fundo)
	_t(nome, x + 16, y, 11, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	var rot := "%d/%d" % [roundi(valor), maximo]
	_t(rot, x, y - 1, 12, Desenho.TEXTO, w - (16.0 if falha else 0.0), HORIZONTAL_ALIGNMENT_RIGHT, true)
	if falha:
		Desenho.icone(self, "alerta", Rect2(x + w - 13, y, 13, 13), Desenho.VERMELHO, fundo)
	Desenho.celulas(self, Rect2(x, y + 17, w, 7), valor, maximo, cor_rec, Prancha.CELULA_VAZIA)


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
	_atualizar_coluna()
	if _coluna != null and _coluna.visible:
		_coluna.queue_redraw()  # o filho redesenha depois deste quadro (a lista não duplica: ele zera o que gravou)
	_versao_vista = missao.versao
	var card := _card_visivel()
	var anima := animando()
	if _pos > 0.0:
		# O terminal (e o card, que vem junto) sobe e desce; o botão TERMINAL, embaixo, fica parado.
		draw_set_transform(Vector2(0.0, roundf((1.0 - suavizar(_pos)) * TELA.size.y)))
		_travado = card or anima  # o que se clica no terminal só vale parado e sem o card por cima
		_desenhar_terminal()
		if card and not _card_sobre_a_sala() and sol_da_pagina() == 0:
			# O plano fica atrás, escurecido (só o terminal, não a sala); só o "Fechar" se clica. O card ao lado
			# de um controle deixa esse controle claro, com contorno.
			var alvo := _alvo_do_card()
			_escurecer_corpos(alvo)
			_travado = anima or not _card_entrou()
			draw_set_transform_matrix(Transform2D(0.0, Vector2(0.0, roundf((1.0 - suavizar(_pos)) * TELA.size.y)))
				* MovimentoAviso.transformacao(_t_do_card(), _pivo_do_card(alvo), CARD_DISTANCIA))
			_desenhar_card(alvo)
		draw_set_transform(Vector2.ZERO)
	_travado = card
	var no_jogo := fase_ui == "plano" or fase_ui == "turno"
	var livre := _fade_estado != "escurecendo"
	_botao_painel("terminal", BOTAO, tr("TERMINAL"), no_jogo and livre and not card, 12, aberto)
	if card and card_id == "turno":
		_travado = not _card_entrou()
		draw_set_transform_matrix(MovimentoAviso.transformacao(_t_do_card(), _pivo_do_card(Rect2()), CARD_DISTANCIA))
		_desenhar_card_turno()
		draw_set_transform(Vector2.ZERO)
	elif card and card_id == "confirmacao":
		_travado = false
		_desenhar_card_confirmacao()
	if alerta_sobre_o_terminal():
		draw_set_transform(Vector2(MovimentoAviso.tremor(_alerta_t), 0.0))
		_desenhar_alerta()
		draw_set_transform(Vector2.ZERO)
	var flash := MovimentoAviso.flash_alfa(_flash_t)
	if flash > 0.0:
		draw_rect(TELA, Color(Desenho.VERMELHO, flash))
	if _selo_n > 0 and fase_ui == "turno":
		SeloCiencia.desenhar(self, _selo_n, _selo_t, _pos > 0.0)
	if _fade > 0.0:
		draw_rect(TELA, Color(Desenho.NOITE, _fade))
	desenhou.emit()


## O alerta do medidor (o ícone do HUD do turno, no mesmo chip), por cima do terminal. Só se vê: não é botão.
func _desenhar_alerta() -> void:
	var cor := HudTurno.cor_do_alerta(missao)
	draw_rect(ALERTA, Color(Desenho.NOITE, 0.92))
	draw_rect(ALERTA, cor, false, 2.0)
	Desenho.icone(self, "alerta", Rect2(ALERTA.position.x + 7, ALERTA.position.y + 4, 20, 20), cor, Desenho.NOITE)


## Os avisos com o movimento do primo (movimento_aviso.gd): a entrada de cada card, o tremor e o flash do alerta
## do medidor por cima do terminal e o selo "+N" quando uma tarefa de ciência termina. Anda os relógios de cada
## um e devolve se algo ainda se mexe (o quadro precisa ser redesenhado, inclusive o último passo).
func _avancar_avisos(delta: float) -> bool:
	var mexe := false
	# O card conta a entrada quando chega à vista: com o terminal já no alto, ou o do turno, embaixo.
	if _card_visivel() and (_pos >= 1.0 or card_id == "turno"):
		if _card_anim_id != card_id:
			_card_anim_id = card_id
			_card_t = 0.0
			mexe = true
		else:
			mexe = not MovimentoAviso.entrada_terminou(_card_t)
			_card_t += delta
	else:
		_card_anim_id = ""
		_card_t = 0.0
	# O alerta por cima do terminal: treme quando aparece e quando passa a vermelho; o flash vermelho é o do alarme
	# (um por travessia do limiar de abrigo).
	var alerta := alerta_sobre_o_terminal()
	var vermelho := alerta and HudTurno.cor_do_alerta(missao) == Desenho.VERMELHO
	if (alerta and not _alerta_visto) or (vermelho and not _vermelho_visto):
		_alerta_t = 0.0
	if vermelho and not _flash_dado:
		_flash_t = 0.0
		_flash_dado = true
	_alerta_visto = alerta
	_vermelho_visto = vermelho
	if missao.fase != "turno" or missao.abrigado or missao.medidor() <= Missao.LIMIAR_ABRIGO:
		_flash_dado = false
	mexe = mexe or _alerta_t < MovimentoAviso.DURACAO_TREMOR_S + delta or _flash_t < MovimentoAviso.FLASH_S + delta
	_alerta_t += delta
	_flash_t += delta
	# O selo de ciência: nasce quando a ciência feita no turno sobe (uma tarefa de ciência terminou).
	if missao.fase == "turno" and _fase_logica == "turno":
		var feita := missao.ciencia_do_sol()
		if feita > _ciencia_vista:
			_selo_n = feita - _ciencia_vista
			_selo_t = 0.0
		_ciencia_vista = feita
	else:
		_ciencia_vista = 0
	mexe = mexe or _selo_t < MovimentoAviso.SELO_S + delta
	_selo_t += delta
	return mexe


## O "+N" do selo de ciência à vista agora (0 = nenhum). A sonda e os testes leem.
func selo_ativo() -> int:
	return _selo_n if _selo_t < MovimentoAviso.SELO_S else 0


## O card da tela terminou de entrar? Até lá ele é desenhado em movimento e nada nele se clica: os alvos de
## clique só existem com o card parado, para bater com o que está desenhado.
func _card_entrou() -> bool:
	return MovimentoAviso.entrada_terminou(_t_do_card())


## O tempo de entrada do card da tela: 0 no quadro em que o card muda, antes de _process contá-lo.
func _t_do_card() -> float:
	return _card_t if _card_anim_id == card_id else 0.0


## O centro do card, de onde a escala elástica cresce. É uma conta aproximada do lugar de cada card (a escala
## acaba em 0,35 s, então um erro de poucos px no pivô não se vê).
func _pivo_do_card(alvo: Rect2) -> Vector2:
	match card_id:
		"aviso":
			return CARD.get_center()
		"turno":
			return Vector2(320.0, CARD_TURNO_FUNDO - 50.0)
	var x := CARD_X_DIREITA if alvo.get_center().x < 360.0 else CARD_X_ESQUERDA
	return Vector2(x + CARD_LARGURA / 2.0, clampf(alvo.get_center().y, Y_CORPO + 40.0, Y_FIM - 40.0))


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
	Prancha.desenhar_tela(self, tela, tr("PRANCHA_SELO") % missao.sol)
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
			"inicio":
				_desenhar_inicio()
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
	draw_rect(r.grow(1.0), Prancha.MOLDURA, false, 1.0)


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
	Prancha.linha_do_titulo(self, X0 - 4.0, X1 + 4.0, 39.0)
	var x_titulo := X0
	if icone != "":
		Desenho.icone(self, icone, Rect2(X0, 13, 16, 16), Desenho.TEXTO, Prancha.FUNDO)
		x_titulo += 22.0
	_t(titulo, x_titulo, 12, 14, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	var x_sub := x_titulo + Desenho.largura_texto(titulo, 14, true) + 6
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


# --- tela inicial ----------------------------------------------------------------

## A tela inicial: o bloco grande da fase e um bloco por aba (para que serve e o estado ao vivo). Todo bloco é
## um botão verde; as teclas da moldura seguem valendo.
func _desenhar_inicio() -> void:
	_titulo("", tr("INICIO_TITULO"), "")
	var b := TelaInicial.blocos()
	var sub_fase := tr("CAB_SOL") % [missao.sol, Modelo.N.SOLS]
	_bloco_inicio("inicio_fase", b["fase"], "terra" if _fase_tela == "fim_do_sol" else "sol",
		TelaInicial.titulo_da_fase(_fase_tela, missao.sol), TelaInicial.dica_da_fase(_fase_tela), sub_fase, true)
	var atual := _frase_donki_atual() != ""
	for a: String in ABAS:
		_bloco_inicio("inicio_" + a, b[a], ICONES_ABA[a], tr(ROTULOS_ABA[a]), TelaInicial.dica_da_aba(a),
			TelaInicial.estado_da_aba(a, _fase_tela, missao, atual), false)


func _bloco_inicio(nome: String, r: Rect2, icone: String, titulo: String, dica: String, estado: String,
		grande: bool) -> void:
	var cores := _pintar_botao(nome, r, true, false, false, grande)  # o bloco grande é a ação da fase
	var fundo: Color = cores[0]
	var cor: Color = cores[1]
	var lado := 30.0 if grande else 24.0
	Desenho.icone(self, icone, Rect2(r.position.x + 12.0, r.position.y + (r.size.y - lado) / 2.0, lado, lado), cor, fundo)
	var x := r.position.x + 12.0 + lado + 12.0
	var w := r.end.x - x - 8.0
	var y := r.position.y + (12.0 if grande else 8.0)
	y += _t(titulo, x, y, 16 if grande else 14, cor, w, HORIZONTAL_ALIGNMENT_LEFT, true) + 2.0
	y += _t(dica, x, y, 12 if grande else 11, cor, w) + 2.0
	_t(estado, x, y, 12 if grande else 11, cor, w, HORIZONTAL_ALIGNMENT_LEFT, true)


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
	Desenho.icone(self, "energia", Rect2(x + l_num + 4.0, y + 2, 12, 12), Desenho.ENERGIA, Prancha.CAIXA)
	_t(tr("CADA"), x + l_num + 20.0, y + 1, 11, Desenho.TEXTO_SUAVE)


## Cabeça de uma linha: ícone e nome em negrito.
func _cabeca_linha(x: float, y: float, icone: String, nome: String) -> void:
	Desenho.icone(self, icone, Rect2(x, y + 1, 14, 14), Desenho.cor_recurso(icone), Prancha.CAIXA)
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
	Desenho.icone(self, "energia", Rect2(x + w - 12, y + 2, 12, 12), Desenho.ENERGIA, Prancha.CAIXA)
	y += 26
	if missao.eh_poeira():
		Desenho.icone(self, "poeira", Rect2(x, y + 1, 12, 12), Desenho.TEXTO, Prancha.CAIXA)
		var h_poeira := _t(tr("PLANO_POEIRA") % roundi(Modelo.N.FATOR_POEIRA * 100.0), x + 16, y, 11, Desenho.TEXTO, w - 16)
		_alvos["poeira"] = Rect2(x, y, w, maxf(h_poeira, 14.0))
		y += h_poeira + 4
	draw_line(Vector2(x, y), Vector2(x + w, y), Prancha.BORDA, 1.0)
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
		Desenho.icone(self, "alerta", Rect2(x, y + 1, 12, 12), Desenho.AMARELO, Prancha.CAIXA)
		var h_gerador := _t(tr("GERADOR_QUEBRADO"), x + 16, y, 11, Desenho.AMARELO, w - 16)
		_alvos["gerador"] = Rect2(x, y, w, maxf(h_gerador, 14.0))
		y += h_gerador + 6
	else:
		y += 4
	draw_line(Vector2(x, y), Vector2(x + w, y), Prancha.BORDA, 1.0)
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
	# Ligada é o estado apertado do botão (fundo a 30%, mais o visto no canto): o estado não é só cor.
	var cores := _pintar_botao("tarefa_" + nome, r, habilitado, ligada)
	var fundo: Color = cores[0]
	var cor: Color = cores[1]
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
		_nota(x, y + 36, w, tr("FALHA_ENERGIA"), Prancha.VERMELHO_TEXTO, true, "alerta")
	elif p["perdida_no_teto"] > 0.0:
		_nota(x, y + 36, w, tr("BATERIA_CHEIA_PERDE") % roundi(p["perdida_no_teto"]), Desenho.TEXTO, true)
	y += 58

	# Oxigênio.
	var falha_o := "oxigenio" in falhas
	_bloco_previsao(x, y, w, "oxigenio", tr("OXIGENIO"), st["O"], fim["O"], falha_o)
	if falha_o:
		_nota(x, y + 36, w, tr("FALHA_OXIGENIO"), Prancha.VERMELHO_TEXTO, true, "alerta")
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
		_nota(x, y + 36, w, tr("FALHA_MARGEM"), Prancha.VERMELHO_TEXTO, true, "alerta")
	elif missao.aviso_ativo():
		_nota(x, y + 36, w, tr("SEM_CONTAR_TEMPESTADE"), Desenho.TEXTO_SUAVE)
	y += 58

	# Ciência.
	draw_line(Vector2(x, y), Vector2(x + w, y), Prancha.BORDA, 1.0)
	y += 8
	_cabeca_linha(x, y, "ciencia", tr("CIENCIA"))
	_t("+%d" % int(p["ciencia"]), x, y - 3, 17, Desenho.TEXTO, w, HORIZONTAL_ALIGNMENT_RIGHT, true)
	_botao("confirmar", Rect2(x, r.end.y - 8 - 44, w, 44), tr("CONFIRMAR_PLANO"), "check", true, 14, false, false, true)


## Um bloco da previsão: ícone, nome, "antes → depois" e a barra. A nota vai em y + 36.
## O "depois" nunca aparece negativo; em falha, tudo vai para o vermelho.
func _bloco_previsao(x: float, y: float, w: float, icone: String, nome: String, antes: float, depois: float,
		falha: bool) -> void:
	var cor := Prancha.VERMELHO_TEXTO if falha else Desenho.TEXTO
	var cor_rec := Prancha.VERMELHO_TEXTO if falha else Desenho.cor_recurso(icone)
	Desenho.icone(self, icone, Rect2(x, y + 1, 14, 14), cor_rec, Prancha.CAIXA)
	_t(nome, x + 20, y, 12, cor, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	var d := maxf(0.0, depois)
	_de_para(x, y, w, _numero(maxf(0.0, antes)), _numero(d), cor, 12)
	Desenho.celulas_de_para(self, Rect2(x, y + 21, w, 8), antes, d, 12, cor_rec, Prancha.CELULA_VAZIA)


## Uma linha de nota de 11 px, com ícone opcional (alerta).
func _nota(x: float, y: float, w: float, texto: String, cor: Color, negrito: bool = false, icone: String = "") -> void:
	var dx := 0.0
	if icone != "":
		Desenho.icone(self, icone, Rect2(x, y + 1, 12, 12), cor, Prancha.CAIXA)
		dx = 16.0
	_t(texto, x + dx, y, 11, cor, w - dx, HORIZONTAL_ALIGNMENT_LEFT, negrito)


# --- card da Terra -------------------------------------------------------------

## O card da tela: o aviso (centrado) ou o que fica ao lado de um controle.
func _desenhar_card(alvo: Rect2) -> void:
	if card_id == "aviso":
		_desenhar_card_aviso()
	else:
		_desenhar_card_ao_lado(alvo)


## O aviso da Terra por cima do plano: retângulo azul simples, sem destaque, seta nem animação. Três partes
## de cima para baixo: o aviso (14, negrito), a frase do histórico de maio de 2024 (sempre) e, quando há dado
## do build, a frase datada do dado de hoje. O rodapé (enviado da Terra) fica ao lado do "Fechar".
func _desenhar_card_aviso() -> void:
	var larg := CARD.size.x - 28
	var f_hist := tr("DONKI_FRASE_HISTORICO")
	var f_atual := _frase_donki_atual()
	# As três partes mandam na altura: o card cresce (centrado) se não couberem entre o alto e o "Fechar", que
	# fica a 12 px da base. O texto acaba 10 px acima do "Fechar".
	var h_aviso := Desenho.altura_texto(tr("AVISO_TEMPESTADE"), 14, larg, true)
	# As frases do DONKI vão em 12 px; se o card (centrado) passaria do alto do corpo do terminal, em 11 px.
	var tam_donki := 12
	var altura := 0.0
	for tentativa in [12, 11]:
		tam_donki = tentativa
		var h_hist := Desenho.altura_texto(f_hist, tam_donki, larg)
		var h_atual := Desenho.altura_texto(f_atual, tam_donki, larg) + 6.0 if f_atual != "" else 0.0
		altura = maxf(CARD.size.y, 12.0 + h_aviso + 6.0 + h_hist + h_atual + 10.0 + 36.0 + 12.0)
		if CARD.get_center().y - altura / 2.0 >= Y_CORPO:
			break
	var r := Rect2(CARD.position.x, CARD.position.y - (altura - CARD.size.y) / 2.0, CARD.size.x, altura)
	draw_rect(r, Desenho.AZUL)
	var x := r.position.x + 14
	var y := r.position.y + 12
	y += _t(tr("AVISO_TEMPESTADE"), x, y, 14, Desenho.TEXTO_ESCURO, larg, HORIZONTAL_ALIGNMENT_LEFT, true) + 6
	y += _t(f_hist, x, y, tam_donki, Desenho.TEXTO_ESCURO, larg) + 6
	if f_atual != "":
		_t(f_atual, x, y, tam_donki, Desenho.TEXTO_ESCURO, larg)
	# O rodapé na altura do meio do "Fechar", à esquerda dele.
	var rodape := r.end.y - 12 - 18 - roundf(Desenho.fonte().get_height(11) / 2.0)
	var larg_rodape := larg - 134
	Desenho.icone(self, "terra", Rect2(x, rodape + 2, 12, 12), Desenho.TEXTO_ESCURO, Desenho.AZUL)
	_t(tr("ENVIADO_DA_TERRA") % missao.atraso_min, x + 16, rodape, 11, Desenho.TEXTO_ESCURO, larg_rodape - 16)
	_botao("fechar_card", Rect2(r.end.x - 14 - 120, r.end.y - 12 - 36, 120, 36), tr("FECHAR"), "", true, 13, false, true)


## A frase do dado do build, datada ("Dados do DONKI de 14/11/2026: 25 chegadas previstas a Marte em 60 dias. A
## última: ..."), para o card do aviso (a aba fontes não o mostra). "" quando o dado é o histórico ou não há chegada. A
## "última" é a mais recente que traz velocidade (o DONKI manda algumas sem ela, e "0 km/s" seria dado falso).
func _frase_donki_atual() -> String:
	if donki.get("historico", true):
		return ""
	var com_velocidade := []
	for c in donki.get("chegadas_marte", []):
		if c is Dictionary and (c.get("velocidade_kms") is float or c.get("velocidade_kms") is int):
			com_velocidade.append(c)
	var ultima := DadosDonki.mais_recente({"chegadas_marte": com_velocidade})
	if ultima.is_empty():
		return ""
	var loc := TranslationServer.get_locale()
	var raspao := tr("DONKI_RASPAO") if ultima.get("raspao", false) == true else ""
	return tr("DONKI_FRASE_ATUAL") % [DadosDonki.data_texto(str(donki.get("coletado_em", "")), loc),
		donki["chegadas_marte"].size(), DadosDonki.data_texto(str(ultima["chegada_prevista"]), loc),
		roundi(float(ultima["velocidade_kms"])), raspao]


## O card ao lado do controle `alvo`, na coluna que não o tem, com uma frase por linha. O ponteiro (seta do card
## até o controle e moldura pulsante em azul, ponteiro_tutorial.gd) é filho do terminal e aparece por cima quando
## o card termina de entrar; o resto do plano já está escurecido.
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
	_ponteiro.apontar(alvo, r, na_direita, not animando())
	draw_rect(r, Desenho.AZUL)
	var yy := r.position.y + 12.0
	for frase: String in frases:
		yy += _t(frase, r.position.x + 12.0, yy, CARD_TAM, Desenho.TEXTO_ESCURO, larg, HORIZONTAL_ALIGNMENT_LEFT, true) + 4.0
	_botao("fechar_card", Rect2(r.end.x - 12.0 - 100.0, r.end.y - 12.0 - 36.0, 100, 36), tr("FECHAR"), "", true, 13, false, true)


## O card do primeiro turno, sobre a sala, acima do botão TERMINAL (que fica apagado) e com a ponta para ele.
func _desenhar_card_turno() -> void:
	var larg := CARD_TURNO_LARGURA - 24.0
	var frases := Abertura.frases(tr("SOL1_CARD_TURNO"))
	var altura_texto := 0.0
	for frase: String in frases:
		altura_texto += Desenho.altura_texto(frase, CARD_TAM, larg, true) + 4.0
	var altura := 12.0 + altura_texto + 4.0 + 36.0 + 12.0
	var r := Rect2(roundf((640.0 - CARD_TURNO_LARGURA) / 2.0), CARD_TURNO_FUNDO - altura, CARD_TURNO_LARGURA, altura)
	var cx := BOTAO.get_center().x
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 8.0, r.end.y), Vector2(cx, BOTAO.position.y - 1.0),
		Vector2(cx + 8.0, r.end.y)]), Desenho.AZUL)
	draw_rect(r, Desenho.AZUL)
	var yy := r.position.y + 12.0
	for frase: String in frases:
		yy += _t(frase, r.position.x + 12.0, yy, CARD_TAM, Desenho.TEXTO_ESCURO, larg, HORIZONTAL_ALIGNMENT_LEFT, true) + 4.0
	_botao("fechar_card", Rect2(r.end.x - 12.0 - 100.0, r.end.y - 12.0 - 36.0, 100, 36), tr("FECHAR"), "", true, 13, false, true)


## O card de confirmação da primeira vez, sobre a sala, no lugar do card do primeiro turno (embaixo, longe do
## medidor e das setas): o que a ação faz, o rótulo de procedimento gravado (no lugar do "há N min") e dois botões,
## cancelar à esquerda e confirmar à direita. Confirmar é o verde de sempre; cancelar também é botão (todo botão é verde).
func _desenhar_card_confirmacao() -> void:
	var chave := "CONFIRMA_" + _confirma_id.to_upper()
	var larg := CARD_CONF_LARGURA - 24.0
	var frases := Abertura.frases(tr(chave))
	var altura_texto := 0.0
	for frase: String in frases:
		altura_texto += Desenho.altura_texto(frase, CARD_TAM, larg, true) + 4.0
	var altura := 12.0 + altura_texto + 4.0 + 14.0 + 10.0 + 36.0 + 12.0
	var y0 := CARD_TURNO_FUNDO - altura
	var r := Rect2(_x_do_card_confirmacao(y0, altura), y0, CARD_CONF_LARGURA, altura)
	rect_do_card_confirmacao = r
	draw_rect(r, Desenho.AZUL)
	var x := r.position.x + 12.0
	var yy := r.position.y + 12.0
	for frase: String in frases:
		yy += _t(frase, x, yy, CARD_TAM, Desenho.TEXTO_ESCURO, larg, HORIZONTAL_ALIGNMENT_LEFT, true) + 4.0
	yy += 4.0
	Desenho.icone(self, "terra", Rect2(x, yy + 1.0, 12, 12), Desenho.TEXTO_ESCURO, Desenho.AZUL)
	_t(tr("ENVIADO_PACOTE_DA_MANHA"), x + 16.0, yy, 11, Desenho.TEXTO_ESCURO, larg - 16.0)
	var y_botoes := r.end.y - 12.0 - 36.0
	_botao("card_confirmar", Rect2(r.end.x - 12.0 - 110.0, y_botoes, 110, 36), tr(chave + "_SIM"), "", true, 13, false, true)
	_botao("card_cancelar", Rect2(r.end.x - 12.0 - 110.0 - 8.0 - 110.0, y_botoes, 110, 36), tr(chave + "_NAO"), "", true, 13, false, true)


## O x do card de confirmação: o mais perto do centro em que ele não cobre nenhuma zona de zonas_a_evitar (com 4 px
## de folga). Se nenhum serve, o centro.
func _x_do_card_confirmacao(y: float, altura: float) -> float:
	var centro := roundf((640.0 - CARD_CONF_LARGURA) / 2.0)
	if not zonas_a_evitar.is_valid():
		return centro
	var zonas: Array = zonas_a_evitar.call()
	var melhor := centro
	var achou := false
	var x := CARD_CONF_X_MIN
	while x + CARD_CONF_LARGURA <= CARD_CONF_X_MAX:
		var r := Rect2(x, y, CARD_CONF_LARGURA, altura).grow(4.0)
		var livre := true
		for z: Rect2 in zonas:
			if r.intersects(z):
				livre = false
				break
		if livre and (not achou or absf(x - centro) < absf(melhor - centro)):
			melhor = x
			achou = true
		x += 4.0
	return melhor


# --- aba câmeras -----------------------------------------------------------------

## O corpo é o visor (scripts/cameras/visor_cameras.gd), filho deste nó: aparece por cima com o terminal
## parado no alto; subindo ou descendo, fica só a caixa vazia.
func _desenhar_cameras() -> void:
	_cabecalho_aba("cameras", missao.sol)
	_caixa(Rect2(X0, Y_CORPO, X1 - X0, Y_FIM - Y_CORPO))


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
	Desenho.icone(self, "energia", Rect2(x, y + 1, 12, 12), Desenho.ENERGIA, Prancha.CAIXA)
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
	draw_line(Vector2(x, y + 1), Vector2(x + w, y + 1), Prancha.BORDA, 1.0)
	y += 5
	var h_dividir := _t(tr("LINHA_PARA_DIVIDIR"), x, y, 12, Desenho.TEXTO, w - 24, HORIZONTAL_ALIGNMENT_LEFT, true)
	_t(_decimal(m["para_dividir"]), x, y, 12, Desenho.TEXTO, w, HORIZONTAL_ALIGNMENT_RIGHT, true)
	y += h_dividir + 10

	# Tanque de O2.
	Desenho.icone(self, "oxigenio", Rect2(x, y + 1, 12, 12), Desenho.OXIGENIO, Prancha.CAIXA)
	y += _t(tr("TANQUE_O2"), x + 16, y, 12, Desenho.TEXTO, w - 16, HORIZONTAL_ALIGNMENT_LEFT, true) + 6
	var h_nota := Desenho.altura_texto(tr("FONTE_UNIDADES_FATO"), 10, w)
	_tanque(Rect2(x, y, w, rl.end.y - 8 - y - h_nota - 8))
	_t(tr("FONTE_UNIDADES_FATO"), x, rl.end.y - 8 - h_nota, 10, Desenho.TEXTO_SUAVE, w)

	# De onde vêm os números.
	var rr := FONTES_CAIXA
	_caixa(rr)
	var plano := _plano_fontes()
	if plano["ligada"]:
		return  # a lista não cabe: o filho (coluna_fontes.gd) a desenha, recortada e rolada
	x = rr.position.x + FONTES_MARGEM_X
	y = rr.position.y + FONTES_MARGEM_Y
	for par in plano["pares"]:
		y += _par_fonte(x, y, plano["w"], par[0], par[1], plano["tam"], true, plano["compacto"]) + plano["espaco"]


## Como a lista de fontes se desenha na caixa da direita: os pares, a largura, o tamanho do texto, o espaço entre
## os fatos e a fonte compacta. O texto usa 10 px; se o idioma não couber na caixa, desce para 9 px, e o espaço
## entre os fatos (5 px) encolhe para 2 px quando só assim a lista cabe. Se nem assim cabe, os 9 px passam à fonte
## compacta (11 px de passo de linha em vez de 13). Se nem a compacta cabe, `ligada`: a lista rola (o filho
## desenha), com `altura` (a lista inteira) e `maximo` (quanto rola). Guardado por idioma: o resultado só depende dele.
func _plano_fontes() -> Dictionary:
	var chave := TranslationServer.get_locale()
	if not _plano.is_empty() and chave == _plano_chave:
		return _plano
	var rr := FONTES_CAIXA
	var pares := _pares_fontes()
	var w := rr.size.x - 2.0 * FONTES_MARGEM_X
	var livre := rr.size.y - 2.0 * FONTES_MARGEM_Y
	var tam := 10
	var espaco := 2.0
	var compacto := false
	if _altura_pares(pares, w, 10) > livre:
		tam = 9
		if _altura_pares(pares, w, 9) > livre:
			compacto = true
		if _altura_pares(pares, w, 9, compacto) + 3.0 * pares.size() <= livre:
			espaco = 5.0
	var altura := 0.0
	var ligada := _altura_pares(pares, w, 9, true) > livre
	var interior := _interior_coluna()
	var maximo := 0.0
	if ligada:
		altura = _altura_pares(pares, w, 9, true)
		# A lista fica a 6 px do alto do interior e deixa 6 px embaixo, como a caixa a deixa sem rolagem.
		maximo = maxf(0.0, altura + 2.0 * (FONTES_MARGEM_Y - 1.0) - interior.size.y)
	_plano_chave = chave
	_plano = {"pares": pares, "w": w, "livre": livre, "tam": tam, "espaco": espaco, "compacto": compacto,
		"ligada": ligada, "altura": altura, "maximo": maximo}
	return _plano


## O interior da caixa das fontes (1 px dentro da borda): o retângulo que o filho recorta, em px da tela.
func _interior_coluna() -> Rect2:
	return FONTES_CAIXA.grow(-1.0)


## O filho aceita gesto: o terminal parado no alto e sem card.
func _coluna_aceita() -> bool:
	return _pos >= 1.0 and not card_aberto


## Zera a rolagem da coluna (a aba mudou).
func _zerar_rolagem() -> void:
	if _coluna != null:
		_coluna.zerar()


## Liga, posiciona e dimensiona o filho da coluna: roda a cada quadro e a cada desenho. À vista só com a aba
## fontes na tela, a lista rolando (não cabe) e o terminal fora de baixo. Subindo e descendo, o filho acompanha o
## deslocamento do terminal, e o fundo dele nunca passa do BOTAO (o botão TERMINAL é desenhado por baixo dele).
func _atualizar_coluna() -> void:
	if _coluna == null or missao == null:
		return
	if aba_na_tela() != "fontes":
		_coluna.zerar()  # saiu da aba: a próxima abertura começa no alto
		_coluna.visible = false
		return
	var plano := _plano_fontes()
	if not plano["ligada"]:
		_coluna.zerar()
		_coluna.visible = false
		return
	_coluna.limitar(plano["maximo"])
	var r := _interior_coluna()
	var topo := r.position.y + roundf((1.0 - suavizar(_pos)) * TELA.size.y)
	_coluna.position = Vector2(r.position.x, topo)
	_coluna.size = Vector2(r.size.x, clampf(BOTAO.position.y - topo, 0.0, r.size.y))
	_coluna.visible = _pos > 0.0 and not _card_visivel() and _coluna.size.y > 0.0


## A lista rolada, desenhada pelo filho `c` (a partir do _draw dele). Mesmo _par_fonte, mesmo tamanho, compacto e
## espaço de quando a lista cabe; na rolagem 0 cada texto fica onde estaria sem rolagem. As posições gravadas
## para a sonda são da tela, sem o deslocamento da animação, já com a rolagem.
func _desenhar_coluna(c: Control) -> void:
	_textos_col.clear()
	if missao == null:
		return
	var plano := _plano_fontes()
	if not plano["ligada"]:
		return
	var interior := _interior_coluna()
	_alvo = c
	_origem = interior.position
	var x := FONTES_CAIXA.position.x + FONTES_MARGEM_X - interior.position.x
	var rolagem: float = c.rolagem
	var y := FONTES_CAIXA.position.y + FONTES_MARGEM_Y - interior.position.y - rolagem
	for par in plano["pares"]:
		y += _par_fonte(x, y, plano["w"], par[0], par[1], plano["tam"], true, plano["compacto"]) + plano["espaco"]
	_alvo = null
	_origem = Vector2.ZERO
	_indicador_coluna(c, interior.size, plano["maximo"])
	if _fade > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(Desenho.NOITE, _fade))


## O indicador de rolagem, na faixa de 8 px da margem direita (o texto não chega nela): um trilho de 2 px com o
## polegar na posição, e, enquanto há mais embaixo, um triângulo para baixo no canto inferior. Só forma e cores
## neutras, parado. `tam` é o interior inteiro (o filho encolhe ao descer, mas o desenho segue o tamanho cheio).
func _indicador_coluna(c: Control, tam: Vector2, maximo: float) -> void:
	var cx := tam.x - 4.0
	var topo := 6.0
	var base := tam.y - 16.0
	c.draw_rect(Rect2(cx - 1.0, topo, 2.0, base - topo), Prancha.BORDA)
	var h_polegar := maxf(8.0, (base - topo) * tam.y / (tam.y + maximo))
	var rolagem: float = c.rolagem
	var y_polegar := topo + (base - topo - h_polegar) * (rolagem / maximo if maximo > 0.0 else 0.0)
	c.draw_rect(Rect2(cx - 1.0, y_polegar, 2.0, h_polegar), Desenho.TEXTO_SUAVE)
	if rolagem < maximo - 0.5:
		c.draw_colored_polygon(PackedVector2Array([Vector2(cx - 3.0, tam.y - 10.0), Vector2(cx + 3.0, tam.y - 10.0),
			Vector2(cx, tam.y - 5.0)]), Desenho.TEXTO_SUAVE)


## Um fato (`tam` px) e a fonte dele (9 px, suave). Se a fonte cabe na última linha do fato, vai ali
## mesmo, ao lado; senão, embaixo. Assim a lista cabe na tela em inglês e em português.
## Devolve a altura ocupada. Com `desenhar` falso só mede. Com `compacto`, as linhas ficam 2 px mais juntas.
func _par_fonte(x: float, y: float, w: float, fato: String, fonte: String, tam: int, desenhar: bool = true,
		compacto: bool = false) -> float:
	var f := Desenho.fonte_compacta() if compacto else Desenho.fonte()
	var par := TextParagraph.new()
	par.add_string(fato, f, tam)
	par.width = w
	var h_fato := Desenho.altura_texto(fato, tam, w, false, f)
	var ao_lado := false
	var l_ultima := par.get_line_width(par.get_line_count() - 1)
	if fonte != "":
		ao_lado = l_ultima + 6.0 + Desenho.largura_texto(fonte, 9) <= w
	if desenhar:
		_t(fato, x, y, tam, Desenho.TEXTO, w, HORIZONTAL_ALIGNMENT_LEFT, false, f if compacto else null)
		if ao_lado:
			# Alinha as linhas de base: a fonte de 9 px fica na base da última linha do fato.
			var dy := f.get_ascent(tam) - f.get_ascent(9)
			_t(fonte, x + l_ultima + 6.0, y + h_fato - f.get_height(tam) + dy, 9, Desenho.TEXTO_SUAVE, -1.0,
				HORIZONTAL_ALIGNMENT_LEFT, false, f if compacto else null)
		elif fonte != "":
			_t(fonte, x, y + h_fato, 9, Desenho.TEXTO_SUAVE, w, HORIZONTAL_ALIGNMENT_LEFT, false, f if compacto else null)
	if fonte != "" and not ao_lado:
		h_fato += Desenho.altura_texto(fonte, 9, w, false, f)
	return h_fato


func _altura_pares(pares: Array, w: float, tam: int, compacto: bool = false) -> float:
	var total := 0.0
	for par in pares:
		total += _par_fonte(0.0, 0.0, w, par[0], par[1], tam, false, compacto) + 2.0
	return total


## [fato, fonte] de cada número do jogo; a fonte é "" quando o fato não leva.
func _pares_fontes() -> Array:
	var pares := []
	# O histórico de maio de 2024 (a data da missão), os números do jogo e, por último, os créditos. O dado do
	# build não entra aqui: é o card do aviso que o mostra.
	pares.append([tr("FONTE_DONKI_HIST_FATO"), tr("FONTE_DONKI_HIST_FONTE")])
	for k in PARES_FONTES:
		pares.append([tr("FONTE_%s_FATO" % k), "" if k in SEM_FONTE else tr("FONTE_%s_FONTE" % k)])
	pares.append([tr("CREDITOS"), tr("CREDITOS_README")])
	return pares


## O tanque na vertical: 12 faixas, cheio é bom; a chave marca o que a tripulação respira em 1 sol.
func _tanque(r: Rect2) -> void:
	var agora: float = missao.st["O"]
	var g := Rect2(r.position.x + 2, r.position.y, 26, r.size.y)
	draw_rect(g, Prancha.FUNDO)
	var faixa := g.size.y / 12.0
	var cheias := clampi(roundi(agora), 0, 12)
	for i in 12:
		var rf := Rect2(g.position.x + 2, g.end.y - (i + 1) * faixa + 1, g.size.x - 4, faixa - 1)
		draw_rect(rf, Desenho.OXIGENIO if i < cheias else Prancha.CELULA_VAZIA)
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
	draw_rect(r, Prancha.FUNDO)
	draw_rect(r, Prancha.BORDA, false, 1.0)


func _estado_texto(estado: String) -> String:
	return tr("ESTADO_" + estado.to_upper())


func _linha_tarefa(nome: String, r: Rect2) -> void:
	_linha_base(r)
	var estado: String = missao.tarefas.get(nome, "pendente")
	Desenho.icone(self, nome, Rect2(r.position.x + 10, r.position.y + 10, 20, 20), Desenho.TEXTO, Prancha.FUNDO)
	_t(_nome_tarefa(nome), r.position.x + 40, r.position.y + 12, 14, Desenho.TEXTO, 120, HORIZONTAL_ALIGNMENT_LEFT, true)
	var xe := r.position.x + 170
	match estado:
		"feita":
			Desenho.icone(self, "check", Rect2(xe, r.position.y + 12, 16, 16), Desenho.TEXTO, Prancha.FUNDO)
			_t(_estado_texto("feita"), xe + 22, r.position.y + 13, 13, Desenho.TEXTO, 120)
		"rodando":
			var f := _progresso_da_linha(nome)
			_t(_estado_texto("rodando"), xe, r.position.y + 5, 11, Desenho.TEXTO)
			var rb := Rect2(xe, r.position.y + 22, 150, 10)
			draw_rect(rb, Prancha.CELULA_VAZIA)
			draw_rect(Rect2(rb.position, Vector2(rb.size.x * f, rb.size.y)), Desenho.TEXTO)
			_t("%d%%" % roundi(f * 100.0), rb.end.x + 8, rb.position.y - 3, 12, Desenho.TEXTO, 40, HORIZONTAL_ALIGNMENT_LEFT, true)
		_:
			# Depois de abrigar a tripulação não faz mais tarefas no turno: a pendente fica cancelada.
			var cancelada := missao.abrigado
			Desenho.icone(self, "circulo", Rect2(xe, r.position.y + 12, 16, 16), Desenho.TEXTO_SUAVE, Prancha.FUNDO)
			_t(_estado_texto("cancelada" if cancelada else "pendente"), xe + 22, r.position.y + 13, 13, Desenho.TEXTO_SUAVE, 140)
	if missao.abrigado and estado == "pendente":
		return  # cancelada: sem botão
	if CAMERA_DA_TAREFA.has(nome):
		# A tarefa se faz pela câmera dela. Não gasta energia.
		_botao("ir_" + nome, Rect2(r.end.x - 130, r.position.y + 5, 122, 30), tr("ABA_CAMERAS"), "camera",
			_pode_ir_a_camera(nome), 12)


func _linha_abrigo(r: Rect2) -> void:
	_linha_base(r)
	var feita := missao.abrigado
	var cor := Desenho.TEXTO if feita else Prancha.VERMELHO_TEXTO
	draw_rect(r, cor, false, 2.0)
	if not feita and not _travado and r.has_point(_mouse):
		draw_rect(r.grow(-2.0), Color(Desenho.TEXTO, 0.08))
	Desenho.icone(self, "alerta", Rect2(r.position.x + 10, r.position.y + 10, 20, 20), cor, Prancha.FUNDO)
	_t(tr("ABRIGO"), r.position.x + 40, r.position.y + 12, 14, cor, 120, HORIZONTAL_ALIGNMENT_LEFT, true)
	var xe := r.position.x + 170
	if feita:
		Desenho.icone(self, "check", Rect2(xe, r.position.y + 12, 16, 16), cor, Prancha.FUNDO)
		_t(_estado_texto("feita"), xe + 22, r.position.y + 13, 13, cor, 120)
	else:
		Desenho.icone(self, "circulo", Rect2(xe, r.position.y + 12, 16, 16), cor, Prancha.FUNDO)
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
		Desenho.icone(self, nomes[k][0], Rect2(bx, by + 1, 12, 12), Desenho.cor_recurso(k), Prancha.CAIXA)
		_t(nomes[k][1], bx + 16, by, 11, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
		_de_para(bx, by - 1, bw, _numero(a), "%s/12" % _numero(d), Desenho.TEXTO)
		Desenho.celulas(self, Rect2(bx, by + 17, bw, 6), maxf(0.0, d), 12, Desenho.cor_recurso(k), Prancha.CELULA_VAZIA)
		by += 44
	if _fase_tela == "fim_do_sol":
		_botao("enviar", Rect2(rb.position.x, Y_FIM - 50, rb.size.x, 50), tr("ENVIAR_A_TERRA"), "terra", true, 14, false, false, true)


## As linhas do diário do sol, na ordem: a história do sol (só na missão fixa), o que aconteceu, a poeira,
## a ciência, a tarefa não feita, a manutenção e a mensagem recebida. Cada uma: ícone (opcional), texto,
## tamanho, cor e espaço depois.
func _itens_diario(reg: Dictionary) -> Array:
	var itens: Array = []
	# 0. A história do sol: clima, sem regra de jogo. Só na missão fixa, e só se o sol tem texto.
	if not missao.livre:
		var k := "DIARIO_HISTORIA_%d" % reg["sol"]
		if tr(k) != k:
			itens.append({"texto": tr(k), "tam": 11, "cor": Desenho.TEXTO_SUAVE, "gap": 6})
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
			draw_line(Vector2(x, y), Vector2(x + w, y), Prancha.BORDA, 1.0)
			y += 6.0
		if it.has("icone"):
			Desenho.icone(self, it["icone"], Rect2(x, y + 1, 12, 12), it.get("cor_icone", Desenho.TEXTO), Prancha.CAIXA)
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
	Prancha.desenhar_tela(self, r, tr("PRANCHA_SELO") % missao.sol)
	var x := r.position.x + 16
	var w := r.size.x - 32
	var y := r.position.y + 12
	Desenho.icone(self, "alerta", Rect2(x, y + 1, 20, 20), Desenho.AMARELO, Prancha.FUNDO)
	_t(tr("MODO_SEGURANCA"), x + 28, y, 18, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	Prancha.linha_do_titulo(self, r.position.x + 8.0, r.end.x - 8.0, y + 29.0)
	Desenho.icone(self, "sol", Rect2(r.end.x - 90, y + 3, 14, 14), Desenho.TEXTO, Prancha.FUNDO)
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
	_caixa(rc, Prancha.CAIXA)
	var caso := missao.caso_real().to_upper()
	_t(tr("CASO_REAL_" + caso), rc.position.x + 10, rc.position.y + 6, 11, Desenho.TEXTO_SUAVE, w - 20,
		HORIZONTAL_ALIGNMENT_LEFT, true)
	_t(tr("CASO_TEXTO_" + caso), rc.position.x + 10, rc.position.y + 22, 12, Desenho.TEXTO, w - 20)

	# Os modos da missão ficam embaixo do botão, para o quadro do caso real ter o espaço do pior caso.
	var y_modos := r.end.y - 18
	Desenho.icone(self, "alerta", Rect2(x, y_modos + 1, 12, 12), Desenho.TEXTO, Prancha.FUNDO)
	_t(tr("MODOS_NA_MISSAO") % missao.modos, x + 18, y_modos, 12, Desenho.TEXTO, w - 18)

	# Um botão só: reinicia (há conserto) ou segue (não há).
	var rb := Rect2(x, r.end.y - 66, 260, 46)
	if missao.tem_conserto:
		_botao("reiniciar", rb, tr("REINICIA_O_SOL"), "", true, 13, false, false, true)
		_t(tr("VOLTA_AO_PLANO") % missao.sol, rb.end.x + 14, rb.position.y + 14, 12, Desenho.TEXTO_SUAVE, w - 280)
	else:
		_botao("seguir", Rect2(x, r.end.y - 66, 300, 46), tr("SEGUIR_EM_SEGURANCA"), "", true, 13, false, false, true)
		_t(tr("SEGUIR_NOTA"), x + 314, rb.position.y + 6, 11, Desenho.TEXTO_SUAVE, w - 314)


# --- relatório -------------------------------------------------------------------

## O relatório é a carga da nave: tudo cabe em x 14 a 626 e y 10 a 314 (a faixa de baixo, com o botão do
## terminal e o mudo, começa em 328), com texto de 12 px ou mais. De cima para baixo: a manchete; o título, as
## três medidas e a caixa das estrelas (com a nota e a linha reservada para "o que faltou para a próxima
## estrela", 2.9); a faixa dos sóis; "o que aconteceu de verdade" à esquerda e, à direita, as duas frases do
## tempo e da escala com o botão no canto.
const REL_X := 14.0
const REL_LARG := 612.0
const REL_Y_MEDIDAS := 38.0
const REL_ALTURA_MEDIDAS := 110.0
const REL_MEDIDAS_W := 242.0
## A caixa das estrelas; a linha "o que faltou" (até 50 caracteres, 12 px) fica reservada na base dela.
const REL_ESTRELAS := Rect2(264, 38, 362, 110)
const REL_FALTOU := Rect2(272, 125, 346, 17)
const REL_Y_SOIS := 156.0
const REL_ALTURA_SOIS := 24.0
const REL_Y_BAIXO := 185.0
const REL_Y_FIM := 314.0
const REL_VERDADE_W := 372.0
const REL_BOTAO := Rect2(394, 282, 232, 32)


## O que faltou para a estrela seguinte (ou que não faltou nada), pela regra de Modelo.estrelas.
func _estrelas_faltou(modos: int, ciencia: int) -> String:
	if modos > 0:
		return tr("ESTRELAS_FALTA_MODO")
	if ciencia < Modelo.ciencia_para_3():
		return tr("ESTRELAS_FALTA_CIENCIA") % (Modelo.ciencia_para_3() - ciencia)
	return tr("ESTRELAS_MAXIMO")


func _desenhar_relatorio() -> void:
	var x := REL_X
	var estrelas := missao.estrelas()
	# A manchete.
	_t(tr("RELATORIO_NAVE"), x, 10, 16, Desenho.TEXTO, REL_LARG, HORIZONTAL_ALIGNMENT_LEFT, true)

	# Título, sub e as três medidas, à esquerda.
	var y := REL_Y_MEDIDAS
	_t(tr("RELATORIO_TITULO"), x, y, 12, Desenho.TEXTO, REL_MEDIDAS_W, HORIZONTAL_ALIGNMENT_LEFT, true)
	_t(tr("RELATORIO_SUB") % Modelo.N.SOLS, x, y + 17, 12, Desenho.TEXTO_SUAVE, REL_MEDIDAS_W)
	var w := REL_MEDIDAS_W
	var ry := y + 36.0
	var r0 := Rect2(x, ry, w, 20)
	var r1 := Rect2(x, ry + 22, w, 20)
	var r2 := Rect2(x, ry + 44, w, 20)
	_caixa(r0)
	Desenho.icone(self, "ciencia", Rect2(r0.position.x + 6, ry + 3, 14, 14), Desenho.TEXTO, Prancha.CAIXA)
	_t(tr("RELATORIO_CIENCIA_ENVIADA") % missao.ciencia_total(), r0.position.x + 26, ry + 1, 12,
		Desenho.TEXTO, w - 32, HORIZONTAL_ALIGNMENT_LEFT, true)
	_caixa(r1)
	Desenho.icone(self, "radiacao", Rect2(r1.position.x + 6, r1.position.y + 3, 14, 14), Desenho.RADIACAO, Prancha.CAIXA)
	var rotulo_margem := tr("MARGEM_FINAL")
	_t(rotulo_margem, r1.position.x + 26, r1.position.y + 1, 12, Desenho.TEXTO_SUAVE)
	_t(tr("N_DE_12") % roundi(missao.st["M"]), r1.position.x + 34 + Desenho.largura_texto(rotulo_margem, 12),
		r1.position.y + 1, 13, Desenho.TEXTO, 52, HORIZONTAL_ALIGNMENT_LEFT, true)
	Desenho.celulas(self, Rect2(r1.end.x - 70, r1.position.y + 6, 64, 8), missao.st["M"], 12, Desenho.RADIACAO, Prancha.CELULA_VAZIA)
	_caixa(r2)
	Desenho.icone(self, "alerta", Rect2(r2.position.x + 6, r2.position.y + 3, 14, 14), Desenho.TEXTO, Prancha.CAIXA)
	_t(tr("MODOS_SEGURANCA"), r2.position.x + 26, r2.position.y + 1, 12, Desenho.TEXTO_SUAVE, w - 70)
	_t(str(missao.modos), r2.end.x - 46, r2.position.y + 1, 13, Desenho.TEXTO, 40, HORIZONTAL_ALIGNMENT_RIGHT, true)
	# Só na missão fixa: o melhor sem modo de segurança (o TEORICO). No Modo livre o teto não existe.
	if not missao.livre:
		_t(tr("RELATORIO_MELHOR_SEM_MODO") % Modelo.N.TEORICO, x + 2, r2.end.y + 3, 12, Desenho.TEXTO_SUAVE, w - 4)

	# A caixa das estrelas: os três ícones, "N de 3", a nota e, na base, a linha reservada (2.9).
	var re := REL_ESTRELAS
	_caixa(re)
	for i in 3:
		Desenho.icone(self, "estrela" if i < estrelas else "estrela_vazia", Rect2(re.position.x + 10 + i * 27, re.position.y + 6, 22, 22),
			Desenho.TEXTO, Prancha.CAIXA)
	_t(tr("N_DE_3_ESTRELAS") % estrelas, re.position.x + 99, re.position.y + 7, 14, Desenho.TEXTO, -1.0,
		HORIZONTAL_ALIGNMENT_LEFT, true)
	_t(tr("ESTRELAS_NOTA"), re.position.x + 8, re.position.y + 32, 12, Desenho.TEXTO_SUAVE, re.size.x - 16)
	_t(_estrelas_faltou(missao.modos, missao.ciencia_total()), REL_FALTOU.position.x, REL_FALTOU.position.y, 12,
		Desenho.TEXTO, REL_FALTOU.size.x, HORIZONTAL_ALIGNMENT_LEFT, true)

	# A faixa dos 5 sóis, baixa: o sol, a ciência do sol e o que houve nele.
	y = REL_Y_SOIS
	var sw := 119.0
	for i in missao.registros.size():
		var reg: Dictionary = missao.registros[i]
		var rs := Rect2(x + i * (sw + 4), y, sw, REL_ALTURA_SOIS)
		_caixa(rs)
		Desenho.icone(self, "sol", Rect2(rs.position.x + 5, y + 6, 12, 12), Desenho.TEXTO, Prancha.CAIXA)
		var rotulo_sol := tr("SOL_N") % reg["sol"]
		_t(rotulo_sol, rs.position.x + 20, y + 3, 12, Desenho.TEXTO_SUAVE)
		_t("+%d" % reg["ciencia"], rs.position.x + 26 + Desenho.largura_texto(rotulo_sol, 12), y + 2, 14, Desenho.TEXTO, 30,
			HORIZONTAL_ALIGNMENT_LEFT, true)
		var xi := rs.end.x - 20
		if reg["seguranca"]:
			Desenho.icone(self, "alerta", Rect2(xi, y + 5, 14, 14), Desenho.AMARELO, Prancha.CAIXA)
			xi -= 16
		if reg["tempestade"]:
			Desenho.icone(self, "tempestade", Rect2(xi, y + 5, 14, 14), Desenho.TEXTO, Prancha.CAIXA)
			xi -= 16
		if reg["poeira"]:
			Desenho.icone(self, "poeira", Rect2(xi, y + 5, 14, 14), Desenho.TEXTO, Prancha.CAIXA)

	# O que aconteceu de verdade, à esquerda: o título com a data na mesma linha e o texto em 12 px.
	y = REL_Y_BAIXO
	_t(tr("DE_VERDADE"), x, y, 13, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	_t(tr("DE_VERDADE_DATA"), x, y + 1, 12, Desenho.TEXTO_SUAVE, REL_VERDADE_W, HORIZONTAL_ALIGNMENT_RIGHT, true)
	var rv := Rect2(x, y + 20, REL_VERDADE_W, REL_Y_FIM - y - 20)
	_caixa(rv)
	_t(tr("DE_VERDADE_TEXTO"), rv.position.x + 8, rv.position.y + 6, 12, Desenho.TEXTO, rv.size.x - 16)

	# À direita: o tempo (26 meses), a escala da radiação e o botão no canto.
	var xd := x + REL_VERDADE_W + 8.0
	var wd := X_ESQ + REL_LARG - xd
	y += _t(tr("RELATORIO_26_MESES"), xd, y, 12, Desenho.TEXTO, wd) + 5.0
	_t(tr("FONTE_ESCALA_FATO"), xd, y, 12, Desenho.TEXTO, wd)
	_botao("jogar_de_novo", REL_BOTAO, tr("JOGAR_DE_NOVO"), "", true, 14, false, false, true)
