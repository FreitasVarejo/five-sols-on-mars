extends RefCounted
## A aparência de prancha (blueprint, papel azul de arquiteto) do terminal: a paleta e as peças que desenham a
## grade, a borda dupla, a linha sob o título e o selo.
##
## Port da aparência do painel da versão do primo (`_draw`), ajustada à nossa tela de 640x360 e à nossa regra de contraste: o azul dele (#1f4f8f) deixava o
## vermelho de alerta em 2,2:1, a energia em 2,96:1 e o texto suave em 4,0:1 (todos abaixo do mínimo). O fundo
## aqui é um azul-marinho (#122a4a). A estrutura do terminal continua a nossa (4 abas, sem sub-aba).
##
## É só do terminal: as telas da sala (tela_barra, tela_radiacao, tela_comunicacao) seguem com as constantes
## compartilhadas de Desenho. As cores reservadas (verde = clica, vermelho e amarelo = alerta, azul = Terra) não
## mudam; os cards da Terra seguem em azul-claro sólido com texto escuro, que é o que os separa da prancha.
##
## Contraste (WCAG, texto >= 4,5:1; elemento gráfico >= 3:1) de cada par usado: tests/test_prancha.gd.

const Desenho := preload("res://scripts/desenho.gd")

# Fundos.
const FUNDO := Color("#122a4a")        # a tela do terminal
const CAIXA := Color("#17375f")        # as caixas internas
const FUNDO_MAPA := Color("#0c1f38")   # o mapa da aba Câmeras e os chips de telemetria: mais escuro que o papel, como a tela da câmera
# Linhas. A borda externa e a linha do título são claras, como no papel; a das caixas é um azul-claro.
const LINHA := Color("#e8f1ff")        # borda externa (2 px)
const LINHA_SUAVE := Color(1, 1, 1, 0.5)  # borda interna (1 px) e linha sob o título: enfeite, sem informação
const BORDA := Color("#6f8fb8")        # borda das caixas e das linhas da lista
const SELO_TEXTO := Color("#9fc0ea")   # o texto do selo
const MOLDURA := Color("#08182e")      # o aro fino de cada corpo, para ele não se perder na sala
# A grade (enfeite): linhas brancas bem fracas, com a forte a cada 5.
const GRADE_FINA := Color(1, 1, 1, 0.05)
const GRADE_FORTE := Color(1, 1, 1, 0.12)
const GRADE_PASSO := 10                # px (a do primo é 20 em 1280x720)
const GRADE_FORTE_A_CADA := 50         # px (a dele, 100)
# O compartimento vazio de uma barra de células (o número "N/12" repete o que a barra mostra) e o que está desligado.
const CELULA_VAZIA := Color("#2b4f7e")
const DESAB_TEXTO := Color("#8da2bd")
# O botão do painel, no estilo do primo (`_make_theme` do blueprint.gd dele): contorno claro de 2 px sobre o papel,
# com o fundo quase transparente (branco a 3%); o hover sobe a 14% e o apertado ou selecionado a 30%. Desligado:
# contorno a 30% e texto apagado. O estado não é só cor: o selecionado tem fundo, o desligado tem contorno apagado.
const BTN_CONTORNO := LINHA
const BTN_FUNDO := Color(1, 1, 1, 0.03)
const BTN_FUNDO_HOVER := Color(1, 1, 1, 0.14)
const BTN_FUNDO_ATIVO := Color(1, 1, 1, 0.30)
const BTN_TEXTO_ATIVO := Color.WHITE   # sobre o fundo a 30%, o texto claro padrão fica abaixo de 4,5:1 na caixa
const BTN_DESAB_CONTORNO := Color(1, 1, 1, 0.30)
const BTN_DESAB_FUNDO := Color(0, 0, 0, 0.06)
const BTN_LARG := 2.0
const BTN_LARG_DESTAQUE := 3.0         # a ação principal de cada tela
# O vermelho de alerta quando é texto: o #e8504a de Desenho.VERMELHO dá 3,25:1 sobre a caixa; este, 4,76.
const VERMELHO_TEXTO := Color("#ff7b72")

const SELO_TAM := 9
const SELO_ALTURA := 12.0


## Luminância relativa (WCAG) de uma cor opaca.
static func luminancia(c: Color) -> float:
	var canais := []
	for v: float in [c.r, c.g, c.b]:
		canais.append(v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * canais[0] + 0.7152 * canais[1] + 0.0722 * canais[2]


## Razão de contraste (WCAG) entre duas cores opacas, de 1 a 21.
static func contraste(a: Color, b: Color) -> float:
	var la := luminancia(a)
	var lb := luminancia(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## O contorno de `larg` px, por dentro de `r` (quatro tiras: não depende de como o draw_rect trata a largura).
static func contorno(ci: CanvasItem, r: Rect2, cor: Color, larg: float) -> void:
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, larg), cor)
	ci.draw_rect(Rect2(r.position.x, r.end.y - larg, r.size.x, larg), cor)
	ci.draw_rect(Rect2(r.position.x, r.position.y + larg, larg, r.size.y - 2.0 * larg), cor)
	ci.draw_rect(Rect2(r.end.x - larg, r.position.y + larg, larg, r.size.y - 2.0 * larg), cor)


## A tela do terminal em prancha: o fundo, a grade, a borda dupla e o selo (se `selo` não for vazio). `r` é o
## corpo da tela; o aro fino em volta fica a cargo de quem chama (`MOLDURA`).
static func desenhar_tela(ci: CanvasItem, r: Rect2, selo: String = "") -> void:
	ci.draw_rect(r, FUNDO)
	grade(ci, r)
	borda_dupla(ci, r)
	if selo != "":
		desenhar_selo(ci, r, selo)


## A grade: uma linha a cada GRADE_PASSO px, alinhada à tela de 640x360 (e não ao corpo), com a forte a cada
## GRADE_FORTE_A_CADA. Dentro de `r`, sem cobrir a borda dupla.
static func grade(ci: CanvasItem, r: Rect2) -> void:
	var dentro := r.grow(-2.0)
	var x0 := int(ceil(dentro.position.x / GRADE_PASSO)) * GRADE_PASSO
	for x in range(x0, int(dentro.end.x), GRADE_PASSO):
		ci.draw_rect(Rect2(x, dentro.position.y, 1.0, dentro.size.y), GRADE_FORTE if x % GRADE_FORTE_A_CADA == 0 else GRADE_FINA)
	var y0 := int(ceil(dentro.position.y / GRADE_PASSO)) * GRADE_PASSO
	for y in range(y0, int(dentro.end.y), GRADE_PASSO):
		ci.draw_rect(Rect2(dentro.position.x, y, dentro.size.x, 1.0), GRADE_FORTE if y % GRADE_FORTE_A_CADA == 0 else GRADE_FINA)


## A borda dupla: 2 px claros na beirada e 1 px a 50% por dentro.
static func borda_dupla(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, LINHA, false, 2.0)
	ci.draw_rect(r.grow(-3.0), LINHA_SUAVE, false, 1.0)


## A linha sob o título, de `x0` a `x1`, em `y`.
static func linha_do_titulo(ci: CanvasItem, x0: float, x1: float, y: float) -> void:
	ci.draw_rect(Rect2(x0, y, x1 - x0, 1.0), LINHA_SUAVE)


## O retângulo do selo: no canto inferior direito da tela, pousado sobre a borda de baixo, como a aba do carimbo
## de uma prancha. Fica abaixo do corpo da tela (y >= 314, onde acabam as abas, as barras e o texto) e acima da faixa do
## botão de mudo (y 328). Vazio sem texto.
static func retangulo_do_selo(r: Rect2, texto: String) -> Rect2:
	if texto == "":
		return Rect2()
	var larg := Desenho.largura_texto(texto, SELO_TAM, false) + 14.0
	return Rect2(r.end.x - 6.0 - larg, r.end.y - SELO_ALTURA + 6.0, larg, SELO_ALTURA)


static func desenhar_selo(ci: CanvasItem, r: Rect2, texto: String) -> void:
	var s := retangulo_do_selo(r, texto)
	ci.draw_rect(s, CAIXA)
	ci.draw_rect(s, LINHA_SUAVE, false, 1.0)
	Desenho.texto(ci, texto, Vector2(s.position.x + 7.0, s.position.y + 1.0), SELO_TAM, SELO_TEXTO)
