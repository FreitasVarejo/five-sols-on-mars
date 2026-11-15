extends Control
## O ponteiro do tutorial: uma seta grossa do card da Terra até o controle que ele nomeia e uma moldura que
## pulsa em volta do controle. Port do TutPointer da versão do primo: o pulso é o dele, sin(t * 6), e a seta balança com sin(t * 7).
##
## Fica de fora o que era dele: o rótulo de texto ("CLIQUE EM R"), porque o card já diz, e o amarelo, que aqui é só
## alerta. O ponteiro é parte do card que vem da Terra, então usa o azul-claro da Terra (Desenho.AZUL).
##
## É filho do terminal, por cima dele, e redesenha sozinho a cada quadro enquanto aponta. O terminal só diz o que
## apontar (`apontar`, de dentro do desenho do card) e avisa que o quadro acabou (`terminar_quadro`, ligado ao
## sinal `desenhou`): o ponteiro some no quadro em que ninguém o chamou. Não captura clique: o controle apontado
## segue clicável (aqui o card é quem trava o resto, e o ponteiro nunca bloqueia nada).
## Só aparece com o terminal parado no alto e depois de o card entrar (MovimentoAviso.DURACAO_ENTRADA_S), para a
## seta não chegar antes do card.

const Desenho := preload("res://scripts/desenho.gd")
const Mov := preload("res://scripts/movimento_aviso.gd")

const PULSO_RAD_S := 6.0       # sin(t * 6), como o do primo: ~0,95 pulso por segundo, abaixo de 3
const BALANCO_RAD_S := 7.0     # sin(t * 7): a seta balança ~1,1 vez por segundo
const MOLDURA_FOLGA := 2.0     # a moldura fica 2 px fora do controle, e cresce até 3 px mais com o pulso
const MOLDURA_PULSO := 3.0
const MOLDURA_GROSSURA := 3.0
const HALO_FOLGA := 4.0        # o halo, mais fora, só aparece com o pulso (translúcido)
const SETA_CABECA := 16.0      # comprimento da ponta da seta
const SETA_ALTURA := 12.0      # meia altura da ponta
const SETA_CORPO := 5.0        # meia grossura do corpo
const SETA_DENTRO := 6.0       # o corpo entra tanto no card (mesma cor, une os dois)
const SETA_AFASTA := 4.0       # a ponta fica a 4 px da moldura, mais o balanço
const SETA_BALANCO := 3.0

var t := 0.0                   # s com o ponteiro à vista (para o pulso; o atraso da entrada conta aqui também)
var _alvo := Rect2()
var _card := Rect2()
var _card_na_direita := false
var _chamado := false          # `apontar` foi chamado no quadro que está acabando
var _vivo := false             # o ponteiro está à vista


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


## O desenho do card diz o que apontar: o retângulo do controle, o do card e de que lado do controle o card está.
## `parado`: o terminal está parado no alto (com ele subindo ou descendo, o ponteiro espera).
func apontar(alvo: Rect2, card: Rect2, card_na_direita: bool, parado: bool = true) -> void:
	if not parado or alvo.size.x <= 0.0:
		return
	_chamado = true
	if not _vivo or alvo != _alvo:
		t = 0.0
	_alvo = alvo
	_card = card
	_card_na_direita = card_na_direita


## O quadro do terminal acabou: o ponteiro fica à vista só se o card o chamou neste quadro.
func terminar_quadro() -> void:
	_vivo = _chamado
	_chamado = false
	visible = _vivo and apareceu()
	if not _vivo:
		t = 0.0
		_alvo = Rect2()


func _process(delta: float) -> void:
	if not _vivo:
		return
	t += delta
	visible = apareceu()
	queue_redraw()


## O ponteiro já pode aparecer (o card terminou de entrar)?
func apareceu() -> bool:
	return _vivo and t >= Mov.DURACAO_ENTRADA_S


## O retângulo que o ponteiro aponta agora (vazio se não aponta nada).
func alvo() -> Rect2:
	return _alvo if _vivo else Rect2()


## O ponteiro está à vista agora?
func esta_visivel() -> bool:
	return visible and _vivo


## De 0 a 1: o pulso da moldura, sin(t * 6) como o do primo.
static func pulso(tempo: float) -> float:
	return 0.5 + 0.5 * sin(tempo * PULSO_RAD_S)


## A moldura em volta do controle `alvo` em `tempo`: cresce e encolhe com o pulso.
static func moldura(alvo: Rect2, tempo: float) -> Rect2:
	return alvo.grow(MOLDURA_FOLGA + pulso(tempo) * MOLDURA_PULSO)


## Os dois polígonos da seta (a ponta e o corpo) do card até o controle: a ponta aponta para o controle e
## balança. `card_na_direita`: o card está à direita do controle (a seta aponta para a esquerda).
static func seta(alvo: Rect2, card: Rect2, card_na_direita: bool, tempo: float) -> Array:
	var d := -1.0 if card_na_direita else 1.0          # para onde a seta aponta, em x
	var y := clampf(alvo.get_center().y, card.position.y + SETA_ALTURA + 2.0, card.end.y - SETA_ALTURA - 2.0)
	var g := moldura(alvo, tempo)
	var borda_perto := g.end.x if card_na_direita else g.position.x
	var ponta := borda_perto - d * (SETA_AFASTA + SETA_BALANCO + SETA_BALANCO * sin(tempo * BALANCO_RAD_S))
	var base := ponta - d * SETA_CABECA
	var cabeca := PackedVector2Array([Vector2(ponta, y), Vector2(base, y - SETA_ALTURA), Vector2(base, y + SETA_ALTURA)])
	var x_card := (card.position.x if card_na_direita else card.end.x) - d * SETA_DENTRO
	var x0 := minf(base, x_card)
	var x1 := maxf(base, x_card)
	var corpo := PackedVector2Array([Vector2(x0, y - SETA_CORPO), Vector2(x1, y - SETA_CORPO),
		Vector2(x1, y + SETA_CORPO), Vector2(x0, y + SETA_CORPO)])
	return [cabeca, corpo]


func _draw() -> void:
	if not apareceu():
		return
	var g := moldura(_alvo, t)
	draw_rect(g, Desenho.AZUL, false, MOLDURA_GROSSURA)
	draw_rect(g.grow(HALO_FOLGA), Color(Desenho.AZUL, 0.4 * pulso(t)), false, 2.0)
	for poligono: PackedVector2Array in seta(_alvo, _card, _card_na_direita, t):
		draw_colored_polygon(poligono, Desenho.AZUL)
