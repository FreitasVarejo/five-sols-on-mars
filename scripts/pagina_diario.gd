extends Control
## A introdução de cada sol da missão fixa, antes do plano: à esquerda o amanhecer em Gale (o relógio passando
## de 05:54 a 06:00, "SOL N", a checklist de sistemas e a barra "Systems ready"), à direita a página do diário
## em papel pautado, com o título "Diary — Sol N", a história do sol e, nos sóis que têm, uma pista do que
## pode acontecer. Fica parada até o botão "Continuar", que se toca a qualquer momento: nada de texto com
## tempo limite. Quem hospeda (main.gd) a põe por cima de tudo antes do plano do sol e a tira quando `fechada`
## é emitido (uma vez só).
##
## Port da tela de abertura de cada sol da versão do primo (IntroView e _draw_card):
## o relógio, o "SOL N" entrando da esquerda, a checklist que ganha o check em sequência, a barra de
## preparo, o fundo com pan lento e escurecimento de amanhecer, a poeira, e a página com papel creme, sombra,
## pauta azul-clara, linha de margem, título e texto em marrom e tinta, subida curta e a seção das pistas.
## O que mudou para o jogo: o amarelo dele no "SOL N" e o vermelho da linha de margem e das pistas viraram
## cores neutras (amarelo e vermelho são só alerta [R]); o OK é o ícone de check, não verde (verde é só o que
## se clica); o item da checklist em alerta troca o check pelo ícone de alerta, amarelo, só quando o estado do
## plano já mostra o problema (o gerador no sol da quebra, o painel nos sóis de poeira); sem o reciclador de
## água (a água foi recusada); o fundo é o render do jogo (visao_geral_<clima>.png). "Pesquisas de hoje" ficou
## de fora: mexe no balanço.
##
## A pista é vaga de manhã e o jogo a confirma no plano do mesmo sol (os cards da Terra: aviso, poeira, gerador
## quebrado), então não dá informação nova; só aparece quando o fato é verdade (contexto_da_missao).
##
## Desenho imediato em 640x360, filtro Nearest, a fonte do projeto (desenho.gd). O botão é verde (é o que se
## clica [R]). Mouse e dedo (o toque chega como mouse emulado), sem teclado. O tempo passa por `avancar(delta)`,
## que o _process chama: um teste ou uma captura desliga o _process e conduz o relógio.

signal fechada

const Desenho := preload("res://scripts/desenho.gd")

const FUNDO := {
	"normal": preload("res://assets/exterior/visao_geral_normal.png"),
	"poeira": preload("res://assets/exterior/visao_geral_poeira.png"),
}

# O tempo da introdução, em segundos (os números são os do primo).
const SUBIDA_S := 0.7            # a folha sobe e aparece neste tempo
const SUBIDA_PX := 40.0          # de quanto abaixo ela parte
const GUARDA_S := 0.25           # o Continuar só responde depois disto: um toque que vinha da tela anterior não o pega
const AMANHECER_S := 3.5         # o céu clareia
const RELOGIO_S := 1.6           # 05:54 a 06:00
const TITULO_ATRASO_S := 0.5     # o "SOL N" entra da esquerda
const TITULO_S := 0.6
const CHECK_ATRASO_S := 1.2      # o primeiro item da checklist; os outros vêm a cada CHECK_PASSO_S
const CHECK_PASSO_S := 0.5
const CHECK_PRONTO_S := 0.35     # "..." vira o check/alerta este tempo depois de o item entrar
const BARRA_S := 3.4
const PAN_S := 20.0              # o pan do fundo, devagar
const ZOOM_FUNDO := 1.15         # o recorte do render que o pan percorre

# A folha, à direita; a coluna da introdução, à esquerda.
const PAPEL_TAMANHO := Vector2(324, 254)
const Y_PAPEL := 40.0
const DIREITA_PAPEL := 18.0      # folga da folha até a borda direita da tela
const SOMBRA := Vector2(4, 5)
const X_MARGEM := 30.0           # a linha de margem, a partir da esquerda da folha
const X_TEXTO := 40.0
const DIREITA_TEXTO := 16.0
const Y_PRIMEIRA_PAUTA := 36.0   # y da primeira linha da pauta, a partir do topo da folha
const PASSO := 20.0              # a distância entre as linhas da pauta (e entre as linhas do texto)
const TAM_TITULO := 18
const TAM_TEXTO := 14
const TAM_SECAO := 12
const MAX_LINHAS := 3            # a caixa da história: a maior das 5 (em português, no sol 2) ocupa 3
const MAX_LINHAS_PISTA := 3      # a caixa da pista: a maior (2 linhas) cabe com folga
const LINHA_SECAO := 5           # a pauta em que o título "O que pode acontecer" assenta; a pista vem depois
const BOTAO_TAMANHO := Vector2(150, 34)
const BASE_DO_BOTAO := 16.0      # folga do botão até o fim da folha

const X_COLUNA := 20.0
const DIREITA_COLUNA := 270.0    # onde a coluna acaba (a folha começa em x = 298)
const Y_RELOGIO := 38.0
const Y_SOL := 70.0
const Y_LOCAL := 128.0
const Y_CHECK := 162.0
const PASSO_CHECK := 19.0
const TAM_RELOGIO := 28
const TAM_SOL := 44
const TAM_COLUNA := 12
const Y_BARRA := 258.0
const ALTURA_BARRA := 10.0
const N_POEIRA := 70

const PAPEL := Color(0.95, 0.9, 0.79)
const TINTA := Color(0.18, 0.13, 0.08)
const MARROM := Color(0.45, 0.22, 0.06)
const PAUTA := Color(0.5, 0.62, 0.8, 0.3)
const MARGEM := Color(0.74, 0.5, 0.44, 0.65)
const CEU := Color(0.06, 0.03, 0.14)

## Os sistemas da checklist: a chave do nome e o contexto que põe o item em alerta ("" = nunca).
const SISTEMAS := [
	["PAGINA_SIS_PRESSAO", ""],
	["PAGINA_SIS_OXIGENIO", "gerador"],
	["PAGINA_SIS_PAINEL", "poeira"],
	["PAGINA_SIS_TERRA", ""],
]

## A pista de cada sol que a tem: a chave do texto e o fato que a torna verdadeira (o mesmo que o plano do sol
## mostra num card da Terra). Os sóis 1 e 4 não têm pista.
const PISTAS := {2: ["DIARIO_PISTA_2", "aviso"], 3: ["DIARIO_PISTA_3", "poeira"], 5: ["DIARIO_PISTA_5", "gerador"]}

## Opcional: o nó Som (scripts/som.gd), injetado por quem hospeda. Só precisa de `tocar(nome)`.
var som = null
## O sol da página, a história dele (já traduzida) e o que a missão já mostra no plano desse sol.
var sol := 1
var texto := ""
var pista := ""
var poeira := false
var gerador := false

var _t := 0.0
var _hover := false
var _emitido := false
var _particulas: Array[Vector3] = []


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in N_POEIRA:
		_particulas.append(Vector3(rng.randf() * 640.0, 200.0 + rng.randf() * 160.0, rng.randf()))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## `contexto` (contexto_da_missao): "pista" (o texto, ou "" sem pista), "poeira" e "gerador" (o plano do sol já
## mostra a poeira / o gerador quebrado).
func configurar(sol_n: int, texto_do_sol: String, contexto: Dictionary = {}) -> void:
	sol = sol_n
	texto = texto_do_sol
	pista = str(contexto.get("pista", ""))
	poeira = bool(contexto.get("poeira", false))
	gerador = bool(contexto.get("gerador", false))
	_t = 0.0
	_hover = false
	_emitido = false
	queue_redraw()


## O que a missão já mostra no começo do plano do sol atual, para a página: a pista (só se o fato que ela anuncia
## é verdade neste plano), a poeira e o gerador quebrado. Sem página no Modo livre: vazio.
static func contexto_da_missao(m) -> Dictionary:
	if m.livre:
		return {}
	var fatos := {"aviso": m.aviso_ativo(), "poeira": m.eh_poeira(), "gerador": bool(m.st_inicio.get("gerador_quebrado", false))}
	var ctx := {"pista": "", "poeira": fatos["poeira"], "gerador": fatos["gerador"]}
	if PISTAS.has(m.sol):
		var par: Array = PISTAS[m.sol]
		if fatos[par[1]]:
			ctx["pista"] = TranslationServer.translate(par[0])
	return ctx


## A pista como se escreve na folha, entre aspas.
static func com_aspas(s: String) -> String:
	return "\u201c%s\u201d" % s


# --- tempo ------------------------------------------------------------------------

func _process(delta: float) -> void:
	avancar(delta)


## Passa `delta` segundos. A poeira e o pan andam sempre, então redesenha todo quadro.
func avancar(delta: float) -> void:
	_t += delta
	queue_redraw()


## Os segundos desde que a página abriu (a captura espera a introdução toda).
func tempo() -> float:
	return _t


## O Continuar já responde? (A subida não precisa acabar.)
func aceita_clique() -> bool:
	return _t >= GUARDA_S


## A folha já parou de subir?
func pronta() -> bool:
	return _t >= SUBIDA_S


## A subida de 0 a 1, com o easing suave (entra e sai devagar).
func progresso() -> float:
	var x := clampf(_t / SUBIDA_S, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _deslocamento() -> float:
	return roundf((1.0 - progresso()) * SUBIDA_PX)


# --- geometria --------------------------------------------------------------------

## A folha parada, em px da tela (à direita).
func rect_papel() -> Rect2:
	return Rect2(Vector2(roundf(size.x - DIREITA_PAPEL - PAPEL_TAMANHO.x), Y_PAPEL), PAPEL_TAMANHO)


## A caixa onde a história é escrita, em px da tela, com a folha parada.
func rect_texto() -> Rect2:
	var p := rect_papel()
	return Rect2(p.position.x + X_TEXTO, p.position.y + Y_PRIMEIRA_PAUTA + 1.0,
		p.size.x - X_TEXTO - DIREITA_TEXTO, PASSO * MAX_LINHAS)


## A caixa da pista, com a folha parada (abaixo do título da seção).
func rect_pista() -> Rect2:
	var p := rect_papel()
	return Rect2(p.position.x + X_TEXTO, p.position.y + Y_PRIMEIRA_PAUTA + PASSO * LINHA_SECAO + 1.0,
		p.size.x - X_TEXTO - DIREITA_TEXTO, PASSO * MAX_LINHAS_PISTA)


## O título da seção das pistas: a linha onde assenta, com a folha parada.
func rect_secao() -> Rect2:
	var p := rect_papel()
	return Rect2(p.position.x + X_TEXTO, p.position.y + Y_PRIMEIRA_PAUTA + PASSO * (LINHA_SECAO - 1) + 1.0,
		p.size.x - X_TEXTO - DIREITA_TEXTO, PASSO)


## O botão com a folha parada.
func rect_continuar() -> Rect2:
	var p := rect_papel()
	return Rect2(roundf(p.position.x + (p.size.x - BOTAO_TAMANHO.x) / 2.0),
		p.end.y - BASE_DO_BOTAO - BOTAO_TAMANHO.y, BOTAO_TAMANHO.x, BOTAO_TAMANHO.y)


## O botão onde ele está agora (a folha sobe com ele).
func _rect_continuar_agora() -> Rect2:
	var r := rect_continuar()
	r.position.y += _deslocamento()
	return r


## O que se clica agora, nome -> [x, y, w, h] (a sonda de teste lê). Vazio só na guarda do começo.
func ui() -> Dictionary:
	if not aceita_clique():
		return {}
	var r := _rect_continuar_agora()
	return {"continuar": [roundi(r.position.x), roundi(r.position.y), roundi(r.size.x), roundi(r.size.y)]}


## A coluna da esquerda: o x do ícone de cada item da checklist, e a largura que o nome pode ocupar.
static func x_icone() -> float:
	return DIREITA_COLUNA - 14.0


static func largura_do_nome() -> float:
	return x_icone() - X_COLUNA - 8.0


## As linhas em que `s` se quebra numa caixa de `largura` px, no tamanho `tam`.
static func quebrar(s: String, largura: float, tam: int = TAM_TEXTO) -> PackedStringArray:
	var linhas := PackedStringArray()
	var atual := ""
	for palavra in s.split(" ", false):
		var tentativa := palavra if atual == "" else atual + " " + palavra
		if atual != "" and Desenho.largura_texto(tentativa, tam) > largura:
			linhas.append(atual)
			atual = palavra
		else:
			atual = tentativa
	if atual != "":
		linhas.append(atual)
	return linhas


## `s` cabe numa caixa de `largura_da_caixa` px com no máximo `max_linhas` linhas, cada uma dentro da largura?
static func cabe(s: String, largura_da_caixa: float, max_linhas: int = MAX_LINHAS) -> bool:
	var linhas := quebrar(s, largura_da_caixa)
	if linhas.size() > max_linhas:
		return false
	for l in linhas:
		if Desenho.largura_texto(l, TAM_TEXTO) > largura_da_caixa:
			return false
	return true


# --- entrada ----------------------------------------------------------------------

## Só o mouse (o toque chega como mouse emulado): o clique no botão fecha, e nada passa para baixo.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var dentro := aceita_clique() and _rect_continuar_agora().has_point((event as InputEventMouseMotion).position)
		if dentro != _hover:
			_hover = dentro
			queue_redraw()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and aceita_clique() \
				and _rect_continuar_agora().has_point(mb.position):
			acionar("continuar")
		accept_event()


## Faz a ação do botão `nome`. O "Continuar" emite `fechada` uma vez só.
func acionar(nome: String) -> void:
	if nome != "continuar" or _emitido or not aceita_clique():
		return
	_emitido = true
	if som != null:
		som.tocar("clique_confirmar")
	fechada.emit()


# --- desenho ----------------------------------------------------------------------

func _draw() -> void:
	_fundo()
	_coluna()
	_folha()


## O render do clima do sol, com o pan lento e o escurecimento de amanhecer; uma faixa escura à esquerda
## para o texto da coluna; a poeira.
func _fundo() -> void:
	var tela := Rect2(Vector2.ZERO, size)
	var tex: Texture2D = FUNDO["poeira" if poeira else "normal"]
	var tam := tex.get_size()
	var recorte := tam / ZOOM_FUNDO
	var origem := Vector2((tam.x - recorte.x) * clampf(_t / PAN_S, 0.0, 1.0), (tam.y - recorte.y) / 2.0)
	draw_texture_rect_region(tex, tela, Rect2(origem, recorte))
	var rise := clampf(_t / AMANHECER_S, 0.0, 1.0)
	var e := rise * rise * (3.0 - 2.0 * rise)
	draw_rect(tela, Color(CEU, 0.75 * (1.0 - e)))
	# Faixa escura de leitura: de 62% na borda esquerda a 0 onde a coluna acaba (colunas inteiras, sem sobrepor).
	var colunas := 14
	for i in colunas:
		draw_rect(Rect2(i * 20.0, 0, 20.0, size.y), Color(0, 0, 0, 0.62 * (1.0 - float(i) / colunas)))
	# A poeira (pontinhos que passam devagar; nada pisca).
	for d in _particulas:
		var x := fmod(d.x + _t * 15.0 * (0.4 + d.z), 660.0) - 10.0
		draw_rect(Rect2(roundf(x), roundf(d.y), 2, 2), Color(1, 0.85, 0.6, 0.35))


## O relógio, o "SOL N", o lugar, a checklist e a barra.
func _coluna() -> void:
	var cor := Desenho.TEXTO
	var mins := int(lerpf(54.0, 60.0, clampf(_t / RELOGIO_S, 0.0, 1.0)))
	var relogio := "05:%02d" % mins if mins < 60 else "06:00"
	_escrever(relogio, X_COLUNA, Y_RELOGIO, TAM_RELOGIO, cor, true)
	var a := clampf((_t - TITULO_ATRASO_S) / TITULO_S, 0.0, 1.0)
	var nome_sol := (tr("SOL_N") % sol).to_upper()
	_escrever(nome_sol, X_COLUNA - roundf((1.0 - a) * 30.0), Y_SOL, TAM_SOL, Color(cor, a), true)
	_escrever(tr("PAGINA_LOCAL"), X_COLUNA + 2.0, Y_LOCAL, TAM_COLUNA + 2, Color(Desenho.TEXTO_SUAVE, a), true)
	for i in SISTEMAS.size():
		var ti := CHECK_ATRASO_S + i * CHECK_PASSO_S
		if _t < ti:
			continue
		var y := Y_CHECK + i * PASSO_CHECK
		_escrever(tr(SISTEMAS[i][0]), X_COLUNA, y, TAM_COLUNA, cor)
		var pronto := _t > ti + CHECK_PRONTO_S
		var r := Rect2(x_icone(), y, 13, 13)
		if not pronto:
			_escrever("...", x_icone(), y, TAM_COLUNA, Desenho.TEXTO_SUAVE)
		elif _em_alerta(SISTEMAS[i][1]):
			Desenho.icone(self, "alerta", r, Desenho.AMARELO, Desenho.NOITE)
		else:
			Desenho.icone(self, "check", r, cor, Desenho.NOITE)
	var p := clampf(_t / BARRA_S, 0.0, 1.0)
	var barra := Rect2(X_COLUNA, Y_BARRA, DIREITA_COLUNA - X_COLUNA, ALTURA_BARRA)
	draw_rect(barra, Color(0, 0, 0, 0.5))
	draw_rect(Rect2(barra.position, Vector2(barra.size.x * p, barra.size.y)), Desenho.TEXTO_SUAVE)
	draw_rect(barra, cor, false, 1.0)
	var estado := tr("PAGINA_PRONTOS") if p >= 1.0 else tr("PAGINA_PREPARANDO") % int(p * 100.0)
	_escrever(estado, X_COLUNA, Y_BARRA + ALTURA_BARRA + 6.0, TAM_COLUNA, cor)


func _em_alerta(contexto: String) -> bool:
	match contexto:
		"gerador":
			return gerador
		"poeira":
			return poeira
	return false


## A folha à direita: papel, pauta, margem, título, história, pista e botão.
func _folha() -> void:
	var e := progresso()
	var p := rect_papel()
	p.position.y += _deslocamento()
	var o := p.position
	draw_rect(Rect2(o + SOMBRA, p.size), Color(0, 0, 0, 0.35 * e))
	draw_rect(p, Color(PAPEL, e))
	# A pauta: de baixo do título até perto do pé da folha. A margem passa por cima.
	var y := Y_PRIMEIRA_PAUTA
	while y < p.size.y - 8.0:
		draw_rect(Rect2(o.x + 10.0, o.y + y, p.size.x - 20.0, 1.0), Color(PAUTA, PAUTA.a * e))
		y += PASSO
	draw_rect(Rect2(o.x + X_MARGEM, o.y, 2.0, p.size.y), Color(MARGEM, MARGEM.a * e))
	# O título e a história: cada linha de texto assenta na linha da pauta.
	_linha(tr("PAGINA_DIARIO_TITULO") % sol, o.x + X_TEXTO, o.y + Y_PRIMEIRA_PAUTA - 4.0, TAM_TITULO, Color(MARROM, e), true)
	var linhas := quebrar(texto, rect_texto().size.x)
	for i in linhas.size():
		_linha(linhas[i], o.x + X_TEXTO, o.y + Y_PRIMEIRA_PAUTA + PASSO * (i + 1) - 4.0, TAM_TEXTO, Color(TINTA, e))
	# A pista, com o título da seção (só quando há pista: nada de seção vazia).
	if pista != "":
		_linha(tr("PAGINA_PISTAS_TITULO"), o.x + X_TEXTO, o.y + Y_PRIMEIRA_PAUTA + PASSO * LINHA_SECAO - 4.0, TAM_SECAO,
			Color(MARROM, e), true)
		var dicas := quebrar(com_aspas(pista), rect_pista().size.x)
		for i in dicas.size():
			_linha(dicas[i], o.x + X_TEXTO, o.y + Y_PRIMEIRA_PAUTA + PASSO * (LINHA_SECAO + 1 + i) - 4.0, TAM_TEXTO,
				Color(MARROM, e))
	_botao(_rect_continuar_agora(), e)


## Escreve `s` com o topo da letra em `y`.
func _escrever(s: String, x: float, y: float, tam: int, cor: Color, negrito: bool = false) -> void:
	Desenho.texto(self, s, Vector2(x + 1.0, y + 1.0), tam, Color(0, 0, 0, 0.7 * cor.a), -1.0, HORIZONTAL_ALIGNMENT_LEFT, negrito)
	Desenho.texto(self, s, Vector2(x, y), tam, cor, -1.0, HORIZONTAL_ALIGNMENT_LEFT, negrito)


## Escreve `s` com a base da letra em `y_base`.
func _linha(s: String, x: float, y_base: float, tam: int, cor: Color, negrito: bool = false) -> void:
	var f := Desenho.fonte_negrito() if negrito else Desenho.fonte()
	Desenho.texto(self, s, Vector2(x, y_base - f.get_ascent(tam)), tam, cor, -1.0, HORIZONTAL_ALIGNMENT_LEFT, negrito)


func _botao(r: Rect2, e: float) -> void:
	var fundo := Desenho.VERDE_CLARO if _hover else Desenho.VERDE
	draw_rect(r, Color(Desenho.VERDE_ESCURO, e))
	draw_rect(r.grow(-2.0), Color(fundo, e))
	var rotulo := tr("PAGINA_DIARIO_CONTINUAR")
	var tam := 18
	var larg := Desenho.largura_texto(rotulo, tam, true)
	Desenho.texto(self, rotulo, Vector2(r.position.x + (r.size.x - larg) / 2.0,
		r.position.y + (r.size.y - Desenho.fonte().get_height(tam)) / 2.0), tam, Color(Desenho.TEXTO_ESCURO, e), -1.0,
		HORIZONTAL_ALIGNMENT_LEFT, true)
