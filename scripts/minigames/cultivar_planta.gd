extends Control
## Minigame "Cultivar a planta": diagnosticar e tratar. A criança abre a câmara do Veggie sob a luz rosa
## (o sintoma fica escondido), acende a luz verde para ver a planta na cor real, descobre o problema
## (seca, encharcada ou mofo) e escolhe a ferramenta: regador, ventilador ou tesoura. Sem texto: cada
## ferramenta tem ícone, e cada resposta tem animação (a ferramenta age dentro da câmara, a planta reage).
## Errar piora a planta por um instante e se desfaz com a escolha oposta: a planta nunca morre.
##
## O modelo é um eixo só: `umidade` de -2 a +2 e `mofo` de 0 a 2. O regador soma 1 à umidade, o ventilador
## tira 1, a tesoura zera o mofo (sem mofo, corta o ar e nada muda). Depois de cada toque, com mofo, ele vale
## 2 se a umidade chegou a +2 e 1 se não: espalha com rega a mais e volta quando seca. A peça termina com
## umidade 0 e mofo 0. Seca = (-1, 0), encharcada = (+1, 0) e mofo = (+1, 1): o mofo é a encharcada com
## manchas, e pede dois passos em qualquer ordem (tesoura e ventilador).
##
## Base real: Veggie e APH na ISS. O Veggie cultiva com LEDs vermelhos e azuis, que dão à câmara a luz rosa; a
## luz verde existe para os astronautas verem a planta normal. Usar o verde como lupa de diagnóstico é
## inferência nossa, não fato da NASA (a luz verde não serve a isso no Veggie). Os erros do jogo vêm do que
## aconteceu lá: as zínias de 2015-16 murcharam e criaram mofo, e o ventilador a mais as secou demais. Fontes:
## https://en.wikipedia.org/wiki/Vegetable_Production_System ,
## https://www.sciencedaily.com/releases/2016/01/160119143038.htm ,
## https://www.scientificamerican.com/article/a-garden-grows-in-space-first-zinnias-bloom-to-an-astronaut-s-delight/ ,
## https://www.nasa.gov/sites/default/files/atoms/files/advanced-plant-habitat.pdf
##
## Cores [R]: verde só nos botões. A folha usa um verde de ilustração (nunca Desenho.VERDE); vermelho,
## amarelo e azul nunca; os LEDs são rosa sob a luz rosa e brancos com a verde; o check do fim é TEXTO. A flor
## laranja é a cor da zínia real, só de ilustração.
##
## Interface (comum aos minigames da noite): `signal concluido` (uma vez, quando o crescimento termina),
## `configurar(area, duracao_s, poeira)`, `progresso()` (0 até o acerto final; no crescimento sobe de 0 a 1; 1
## no fim) e `semente(n)`. Esta peça só mostra e anima: não lê nem escreve o estado da missão. Quem hospeda
## liga `concluido` ao fim da tarefa da planta e escolhe o problema (`definir_problema`).
##
## Calibração: o caminho certo pede a luz e de 1 a 2 ferramentas (até 4, se a criança errou uma vez), e com o
## crescimento cabe em ≤10 s para um adulto (teto da calibração, que supõe a tarefa feita).

signal concluido

const Desenho := preload("res://scripts/desenho.gd")

const FERRAMENTAS := ["regador", "ventilador", "tesoura"]
const PROBLEMAS := ["seca", "encharcada", "mofo"]
const UMIDADE_MIN := -2
const UMIDADE_MAX := 2
const MOFO_MAX := 2

const T_LUZ := 0.35  # a luz branca sobe nesta duração
const T_FERRAMENTA := 0.45  # a ferramenta anima dentro da câmara
const T_REACAO := 0.5  # a planta sacode (pior) ou dá o pulo (melhor)
const T_VISIVEL := 0.25  # o sintoma anda até o novo valor
const T_ATRASO_CRESCER := 0.25  # no acerto final, a água cai antes do "ploc" e do crescimento
const T_CRESCER := 1.2
const T_APERTO := 0.14  # o botão fica apertado por este tempo
const T_SOM_RESULTADO := 0.12  # o som de melhorou/piorou vem logo depois do da ferramenta
const LADO_MIN := 24.0  # lado mínimo do botão (o desenho nunca passa abaixo disto)
const LADO_MAX := 64.0
const FOLGA_TOQUE := 2.0  # o teste de acerto cresce o botão nesta folga
const PROJETO_W := 220.0  # a câmara é desenhada num espaço de 220×174 e escalada para a área
const PROJETO_H := 174.0

# Cores da ilustração (a câmara e a planta). A interface usa só a paleta de desenho.gd.
const PAREDE := Color("#1a252e")
const GRADE := Color("#22303a")
const FOLE := Color("#56707e")
const LED_FUNDO := Color("#2a333c")
const LED_CASCA := Color("#5a6873")
const LED_ROSA_A := Color("#ff7ad6")
const LED_ROSA_B := Color("#c48cff")
const LED_BRANCO := Color("#f4f4ea")
const FOLHA := Color("#4f9466")
const FOLHA_BORDA := Color("#24503a")
const FOLHA_SECA := Color("#a8964c")
const FOLHA_SECA_BORDA := Color("#6b5a2a")
const FOLHA_MARROM := Color("#8a6238")
const FOLHA_MOLHADA := Color("#7ea25e")
const CAULE := Color("#3d6e4c")
const ALM_SECA := Color("#ddcca2")
const ALM_OK := Color("#b39a72")
const ALM_MOLHADA := Color("#4a382c")
const BANDEJA := Color("#8d9ca4")
const BANDEJA_SOMBRA := Color("#5d6b73")
const GOTA := Color("#d8eef3")
const POCA := Color("#7c95a0")
const MOFO_COR := Color("#f3f2e8")
const PETALA := Color("#f08c4a")
const PETALA_ESCURA := Color("#c4642c")
const MIOLO := Color("#5a3a20")
const BOTAO_FLOR := Color("#5c9a5c")
const ROSA := Color("#b25ac8")  # a luz do Veggie: a cena é multiplicada por esta cor
const ROSA_BRILHO := Color(0.863, 0.353, 0.824, 0.16)
const FERRAMENTA_COR := Color("#c7d3d9")

enum Estado { LIVRE, CRESCENDO, CONCLUIDO }

## Opcional: o nó Som (scripts/som.gd), injetado por quem hospeda. Só precisa de `tocar(nome)`.
var som = null
## Para o teste: registra as cores que o desenho usa, a da cena e a dos botões (`cores_usadas()`).
var registrar_cores := false

var _sorteio := {}
var _problema := "seca"
var _umidade := 0
var _mofo := 0
var _luz_acesa := false
var _luz := 0.0  # 0 (rosa) a 1 (branca)
var _u_vis := 0.0  # a umidade e o mofo mostrados: andam até o valor, suave
var _m_vis := 0.0
var _estado := Estado.LIVRE
var _tg := 0.0  # relógio do acerto final: negativo na espera, depois de 0 a T_CRESCER
var _g := 0.0  # o degrau de crescimento, 0 a 1
var _tempo := 0.0  # relógio da animação (pulso, gotas)
var _emitido := false
var _anim := {}  # a ferramenta em ação: {"id", "t", "cortou"}; vazio sem animação
var _reacao := {}  # {"tipo", "t"}
var _aperto := ""  # o botão apertado agora ("luz" ou o nome da ferramenta)
var _t_aperto := 0.0
var _som_depois := ""  # o som de melhorou/piorou que ainda vai tocar
var _t_som := 0.0
var _mouse := Vector2(-1000.0, -1000.0)

# Layout, recalculado a partir do tamanho.
var _painel := Rect2()
var _r_luz := Rect2()
var _r_ferr := {}
var _cam := Rect2()
var _u := 1.0  # escala da câmara
var _larg := PROJETO_W  # a câmara em unidades de projeto
var _alt := PROJETO_H
var _xc := Transform2D.IDENTITY  # unidades da câmara -> px
var _fio := Rect2()

# Desenho.
var _mul := Color.WHITE  # a luz que multiplica as cores da câmara
var _ctx_botao := false
var _cores_cena := {}
var _cores_botao := {}


func _init() -> void:
	_sorteio = sorteio(0)
	_problema = _sorteio["problema"]
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	size = Vector2(640, 360)
	_calcular_layout()
	_reiniciar()


## Sorteio puro: o problema deste sol. Mesmo `n`, mesmo resultado; os três aparecem.
static func sorteio(n: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = n
	return {"problema": PROBLEMAS[rng.randi_range(0, PROBLEMAS.size() - 1)]}


func configurar(area: Rect2, _duracao_s: float, _poeira: bool) -> void:
	position = area.position
	size = area.size
	_calcular_layout()
	_reiniciar()


func semente(n: int) -> void:
	_sorteio = sorteio(n)
	_problema = _sorteio["problema"]
	_reiniciar()


## Reinicia a peça com o problema `nome` ("seca", "encharcada" ou "mofo"); outro nome não muda nada.
func definir_problema(nome: String) -> void:
	if not nome in PROBLEMAS:
		return
	_problema = nome
	_reiniciar()


func progresso() -> float:
	match _estado:
		Estado.CRESCENDO:
			return clampf(_tg / T_CRESCER, 0.0, 1.0)
		Estado.CONCLUIDO:
			return 1.0
	return 0.0


## Toda a lógica de tempo. `_process` só chama isto; o teste anda o tempo à mão.
func avancar(delta: float) -> void:
	_tempo += delta
	if _luz < (1.0 if _luz_acesa else 0.0):
		_luz = minf(1.0, _luz + delta / T_LUZ)
	_u_vis = move_toward(_u_vis, float(_umidade), delta / T_VISIVEL)
	_m_vis = move_toward(_m_vis, float(_mofo), delta / T_VISIVEL)
	if not _anim.is_empty():
		_anim["t"] += delta
		if _anim["t"] >= T_FERRAMENTA:
			_anim = {}
	if not _reacao.is_empty():
		_reacao["t"] += delta
		if _reacao["t"] >= T_REACAO:
			_reacao = {}
	if _t_aperto > 0.0:
		_t_aperto = maxf(0.0, _t_aperto - delta)
		if _t_aperto <= 0.0:
			_aperto = ""
	if _som_depois != "":
		_t_som -= delta
		if _t_som <= 0.0:
			_tocar(_som_depois)
			_som_depois = ""
	if _estado == Estado.CRESCENDO:
		var antes := _tg
		_tg += delta
		if antes < 0.0 and _tg >= 0.0:
			_tocar("estufa_ploc")
		_g = smoothstep(0.0, 1.0, clampf(_tg / T_CRESCER, 0.0, 1.0))
		if _tg >= T_CRESCER:
			_tg = T_CRESCER
			_g = 1.0
			_estado = Estado.CONCLUIDO
			if not _emitido:
				_emitido = true
				concluido.emit()


## O botão da luz verde. Só vale uma vez (é de mão única) e com a peça livre. Devolve se acendeu.
func acender_luz() -> bool:
	if _estado != Estado.LIVRE or _luz_acesa:
		return false
	_luz_acesa = true
	_aperto = "luz"
	_t_aperto = T_APERTO
	_tocar("estufa_luz")
	return true


## Usa a ferramenta `nome`. Devolve "melhor" (a planta ficou menos doente), "pior" (mais doente) ou "nada" (a
## tesoura sem mofo), e "" se o toque foi ignorado: a luz ainda apagada, a planta crescendo ou um nome
## que não é ferramenta. O estado muda neste mesmo quadro; a animação e o retorno seguem por 0,5 s.
func usar(ferramenta: String) -> String:
	if _estado != Estado.LIVRE or not _luz_acesa or not ferramenta in FERRAMENTAS:
		return ""
	_aperto = ferramenta
	_t_aperto = T_APERTO
	if _som_depois != "":  # um toque rápido não perde o som do toque anterior
		_tocar(_som_depois)
		_som_depois = ""
	var antes := ruim()
	var cortou := false
	match ferramenta:
		"regador":
			_umidade = mini(UMIDADE_MAX, _umidade + 1)
		"ventilador":
			_umidade = maxi(UMIDADE_MIN, _umidade - 1)
		"tesoura":
			if _mofo > 0:
				_mofo = 0
				cortou = true
	if _mofo > 0:
		_mofo = MOFO_MAX if _umidade >= UMIDADE_MAX else 1
	var depois := ruim()
	var tipo := "melhor" if depois < antes else ("pior" if depois > antes else "nada")
	_anim = {"id": ferramenta, "t": 0.0, "cortou": cortou}
	_reacao = {"tipo": tipo, "t": 0.0}
	_tocar("estufa_" + {"regador": "regar", "ventilador": "ventilar", "tesoura": "cortar"}[ferramenta])
	if _umidade == 0 and _mofo == 0:
		_estado = Estado.CRESCENDO
		_tg = -T_ATRASO_CRESCER
	elif tipo != "nada":
		_som_depois = "estufa_melhorou" if tipo == "melhor" else "estufa_piorou"
		_t_som = T_SOM_RESULTADO
	return tipo


## Quão doente a planta está: |umidade| + mofo. Zero é curada.
func ruim() -> int:
	return absi(_umidade) + _mofo


func problema() -> String:
	return _problema


func umidade() -> int:
	return _umidade


func mofo() -> int:
	return _mofo


func luz_acesa() -> bool:
	return _luz_acesa


## O retângulo do botão da luz verde, nas coordenadas desta peça.
func retangulo_da_luz() -> Rect2:
	return _r_luz


## O retângulo do botão da ferramenta `nome` ("regador", "ventilador" ou "tesoura"), nas coordenadas desta peça.
func retangulo_da_ferramenta(nome: String) -> Rect2:
	return _r_ferr.get(nome, Rect2())


## O retângulo da câmara (onde a planta aparece), nas coordenadas desta peça.
func retangulo_da_camara() -> Rect2:
	return _cam


## O sorteio em uso: `problema`.
func sorteio_atual() -> Dictionary:
	return _sorteio


## A planta está crescendo ou já cresceu: toques são ignorados.
func ocupada() -> bool:
	return _estado != Estado.LIVRE


func concluida() -> bool:
	return _estado == Estado.CONCLUIDO


## As cores que o desenho usou desde `registrar_cores = true`: {"cena": [Color], "botao": [Color]}, sem alfa.
func cores_usadas() -> Dictionary:
	return {"cena": _cores_cena.keys(), "botao": _cores_botao.keys()}


func _process(delta: float) -> void:
	avancar(delta)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_calcular_layout()


# --- estado --------------------------------------------------------------------

func _reiniciar() -> void:
	match _problema:
		"seca":
			_umidade = -1
			_mofo = 0
		"encharcada":
			_umidade = 1
			_mofo = 0
		_:
			_umidade = 1
			_mofo = 1
	_luz_acesa = false
	_luz = 0.0
	_u_vis = float(_umidade)
	_m_vis = float(_mofo)
	_estado = Estado.LIVRE
	_tg = 0.0
	_g = 0.0
	_emitido = false
	_anim = {}
	_reacao = {}
	_aperto = ""
	_t_aperto = 0.0
	_som_depois = ""
	_t_som = 0.0


func _tocar(nome: String) -> void:
	if som != null:
		som.tocar(nome)


# --- toque ---------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_mouse = event.position
		if _r_luz.grow(FOLGA_TOQUE).has_point(event.position):
			acender_luz()
			accept_event()
			return
		for nome: String in FERRAMENTAS:
			if _r_ferr[nome].grow(FOLGA_TOQUE).has_point(event.position):
				usar(nome)  # apagada ou ocupada: ignorada
				accept_event()
				return


# --- layout --------------------------------------------------------------------

func _calcular_layout() -> void:
	if size.y > size.x:
		_calcular_layout_retrato()
		return
	var w := size.x
	var h := size.y
	var m := roundf(clampf(minf(w, h) * 0.04, 4.0, 12.0))
	_painel = Rect2(m, m, w - 2.0 * m, h - 2.0 * m)
	var pad := 8.0
	var vao := 8.0  # entre a câmara e as colunas de botões
	var topo := _painel.position.y + pad
	var alto := _painel.size.y - 2.0 * pad
	var gap := roundf(alto * 0.07)
	var b := clampf(floorf((alto - 2.0 * gap) / 3.0), LADO_MIN, LADO_MAX)
	var x_luz := _painel.position.x + pad
	var x_ferr := _painel.end.x - pad - b
	_r_luz = Rect2(x_luz, topo, b, b)
	var y0 := topo + roundf((alto - 3.0 * b - 2.0 * gap) / 2.0)
	for i in FERRAMENTAS.size():
		_r_ferr[FERRAMENTAS[i]] = Rect2(x_ferr, y0 + i * (b + gap), b, b)
	_cam = Rect2(_r_luz.end.x + vao, topo, x_ferr - vao - (_r_luz.end.x + vao), alto)
	_u = clampf(minf(_cam.size.x / PROJETO_W, _cam.size.y / PROJETO_H), 0.5, 3.0)
	_larg = _cam.size.x / _u
	_alt = _cam.size.y / _u
	_xc = Transform2D(Vector2(_u, 0.0), Vector2(0.0, _u), _cam.position)
	# O fio da lâmpada ao banco de LEDs: na altura do banco, da borda do botão à borda da câmara.
	var esp := maxf(2.0, roundf(_u * 2.0))
	_fio = Rect2(_r_luz.end.x, roundf(_cam.position.y + 10.0 * _u - esp / 2.0), _cam.position.x - _r_luz.end.x, esp)


## O layout em retrato (a vista de perto da estufa, num vão mais alto que largo): a câmara em cima, na largura
## útil, e os quatro botões numa fileira embaixo (luz, e as três ferramentas um pouco mais afastadas dela). O fio da
## lâmpada não existe aqui: o botão da luz fica embaixo, longe do banco de LEDs, que fica no alto da câmara.
func _calcular_layout_retrato() -> void:
	var w := size.x
	var h := size.y
	var m := roundf(clampf(minf(w, h) * 0.025, 3.0, 8.0))
	_painel = Rect2(m, m, w - 2.0 * m, h - 2.0 * m)
	var pad := 6.0
	var vao := 8.0  # entre a câmara e a fileira de botões
	var gap := 6.0  # entre os botões
	var gap_luz := 14.0  # entre a luz e as ferramentas
	var util := _painel.size.x - 2.0 * pad
	var b := clampf(floorf((util - 2.0 * gap - gap_luz) / 4.0), LADO_MIN, LADO_MAX)
	var total := 4.0 * b + 2.0 * gap + gap_luz
	var x := _painel.position.x + roundf((_painel.size.x - total) / 2.0)
	var y := _painel.end.y - pad - b
	_r_luz = Rect2(x, y, b, b)
	x += b + gap_luz
	for nome: String in FERRAMENTAS:
		_r_ferr[nome] = Rect2(x, y, b, b)
		x += b + gap
	var topo := _painel.position.y + pad
	_cam = Rect2(_painel.position.x + pad, topo, util, maxf(y - vao - topo, 1.0))
	_u = clampf(minf(_cam.size.x / PROJETO_W, _cam.size.y / PROJETO_H), 0.5, 3.0)
	_larg = _cam.size.x / _u
	_alt = _cam.size.y / _u
	_xc = Transform2D(Vector2(_u, 0.0), Vector2(0.0, _u), _cam.position)
	_fio = Rect2()


# --- desenho: ajudantes ----------------------------------------------------------

## A cor `c` na luz da câmara (multiplicada, como a luz do Veggie). Registra a cor para o teste.
func _cor(c: Color) -> Color:
	if registrar_cores:
		(_cores_botao if _ctx_botao else _cores_cena)[Color(c.r, c.g, c.b)] = true
	return Color(c.r * _mul.r, c.g * _mul.g, c.b * _mul.b, c.a)


static func _escala(xf: Transform2D) -> float:
	return xf.x.length()


func _ret(xf: Transform2D, x: float, y: float, w: float, h: float, cor: Color) -> void:
	draw_rect(Rect2(xf * Vector2(x, y), Vector2(w, h) * _escala(xf)), _cor(cor))


func _linha(xf: Transform2D, pts: PackedVector2Array, cor: Color, w: float) -> void:
	var t := PackedVector2Array()
	for p in pts:
		t.append(xf * p)
	draw_polyline(t, _cor(cor), maxf(1.0, w * _escala(xf)))


func _poli(xf: Transform2D, pts: PackedVector2Array, cor: Color) -> void:
	var t := PackedVector2Array()
	for p in pts:
		t.append(xf * p)
	draw_colored_polygon(t, _cor(cor))


func _tri(xf: Transform2D, a: Vector2, b: Vector2, c: Vector2, cor: Color) -> void:
	var k := _cor(cor)
	draw_primitive(PackedVector2Array([xf * a, xf * b, xf * c]), PackedColorArray([k, k, k]), PackedVector2Array())


func _circ(xf: Transform2D, c: Vector2, r: float, cor: Color) -> void:
	draw_circle(xf * c, r * _escala(xf), _cor(cor))


func _arco(xf: Transform2D, c: Vector2, r: float, a0: float, a1: float, cor: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for k in 17:
		pts.append(c + Vector2.from_angle(lerpf(a0, a1, k / 16.0)) * r)
	_linha(xf, pts, cor, w)


func _elipse(xf: Transform2D, c: Vector2, rx: float, ry: float, rot: float, cor: Color) -> void:
	var pts := PackedVector2Array()
	for k in 14:
		pts.append(c + Vector2(cos(TAU * k / 14.0) * rx, sin(TAU * k / 14.0) * ry).rotated(rot))
	_poli(xf, pts, cor)


## Curva quadrática de `a` a `b` com controle `c`.
static func _bez(a: Vector2, c: Vector2, b: Vector2, n: int = 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n + 1:
		var f := float(k) / float(n)
		pts.append(a.lerp(c, f).lerp(c.lerp(b, f), f))
	return pts


static func _mist(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, clampf(t, 0.0, 1.0))


func _com_alfa(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


# --- desenho -------------------------------------------------------------------

func _draw() -> void:
	_mul = Color.WHITE
	_ctx_botao = false
	draw_rect(Rect2(Vector2.ZERO, size), _cor(Desenho.MOLDURA))
	draw_rect(_painel, _cor(Desenho.FUNDO_TELA))
	draw_rect(_painel, _cor(Desenho.BORDA), false, 2.0)
	_desenhar_camara()
	draw_rect(_fio, _cor(Desenho.BORDA))
	_ctx_botao = true
	_desenhar_botao_luz()
	for nome: String in FERRAMENTAS:
		_desenhar_botao_ferramenta(nome)
	_ctx_botao = false


## O estado do botão: "desligado", "apertado", "sob" (mouse em cima), "ativo" ou "aceso".
func _estado_botao(id: String, r: Rect2, ativo: bool) -> String:
	if not ativo:
		return "desligado"
	if _aperto == id and _t_aperto > 0.0:
		return "apertado"
	if r.grow(FOLGA_TOQUE).has_point(_mouse):
		return "sob"
	return "ativo"


## Fundo e borda do botão no estilo dos botões verdes do terminal; devolve a cor do ícone.
func _fundo_botao(r: Rect2, est: String) -> Color:
	var fundo := Desenho.VERDE
	var borda := Desenho.VERDE_ESCURO
	var icone := Desenho.TEXTO_ESCURO
	match est:
		"sob":
			fundo = Desenho.VERDE_CLARO
		"apertado":
			fundo = Desenho.VERDE_ESCURO
			borda = Desenho.VERDE
			icone = Desenho.TEXTO
		"desligado":
			fundo = Desenho.CELULA_VAZIA
			borda = Desenho.MOLDURA
			icone = Desenho.TEXTO_SUAVE
		"aceso":
			fundo = Desenho.FUNDO_TERMINAL
			borda = Desenho.BORDA
			icone = Desenho.TEXTO
	draw_rect(r, _cor(borda))
	draw_rect(r.grow(-2.0), _cor(fundo))
	return icone


## O ícone do botão `r`: o espaço do ícone é o de um botão de 50 px, com a origem no centro.
func _xf_icone(r: Rect2) -> Transform2D:
	var k := minf(r.size.x, r.size.y) / 50.0
	return Transform2D(Vector2(k, 0.0), Vector2(0.0, k), r.get_center())


func _desenhar_botao_luz() -> void:
	var r := _r_luz
	var aceso := _luz_acesa
	var est := "aceso" if aceso else _estado_botao("luz", r, _estado == Estado.LIVRE)
	if not aceso and _estado == Estado.LIVRE:
		# O pulso suave de 1 Hz no único botão que vale no começo.
		var a := 0.25 + 0.35 * (0.5 + 0.5 * sin(_tempo * TAU))
		draw_rect(r.grow(3.0), _cor(_com_alfa(Desenho.VERDE_CLARO, a)))
	var cor := _fundo_botao(r, est)
	_icone_lampada(_xf_icone(r), cor, aceso)


func _desenhar_botao_ferramenta(nome: String) -> void:
	var r: Rect2 = _r_ferr[nome]
	var ativo := _estado == Estado.LIVRE and _luz_acesa
	var est := _estado_botao(nome, r, ativo)
	var cor := _fundo_botao(r, est)
	var xf := _xf_icone(r)
	match nome:
		"regador":
			_icone_regador(xf, cor)
		"ventilador":
			_icone_ventilador(xf, Vector2.ZERO, cor, _tempo * 20.0 if est == "apertado" else 0.0)
		_:
			_icone_tesoura(xf, Vector2(0.0, 2.0), cor, 0.35)


# --- ícones --------------------------------------------------------------------

func _icone_lampada(xf: Transform2D, cor: Color, aceso: bool) -> void:
	var c := Vector2(0.0, -5.0)
	_circ(xf, c, 9.0, cor)
	_ret(xf, -5.0, 4.0, 10.0, 3.0, cor)
	_ret(xf, -4.0, 8.0, 8.0, 3.0, cor)
	_ret(xf, -2.0, 12.0, 4.0, 2.0, cor)
	if aceso:
		for k in 7:
			var a := PI + (k / 6.0) * PI
			_linha(xf, PackedVector2Array([c + Vector2.from_angle(a) * 13.0, c + Vector2.from_angle(a) * 17.0]), cor, 2.0)


func _icone_regador(xf: Transform2D, cor: Color) -> void:
	var o := Vector2(-16.0, -8.0)
	_poli(xf, PackedVector2Array([o + Vector2(4, 0), o + Vector2(22, 0), o + Vector2(20, 20), o + Vector2(6, 20)]), cor)
	_arco(xf, o + Vector2(13, 0), 7.0, PI, TAU, cor, 3.0)
	_linha(xf, PackedVector2Array([o + Vector2(21, 14), o + Vector2(30, 4)]), cor, 3.0)
	_ret(xf, o.x + 28.0, o.y, 5.0, 6.0, cor)


func _icone_ventilador(xf: Transform2D, c: Vector2, cor: Color, giro: float) -> void:
	_arco(xf, c, 16.0, 0.0, TAU, cor, 2.0)
	for k in 3:
		var a := giro + k * TAU / 3.0
		_elipse(xf, c + Vector2.from_angle(a) * 7.0, 7.0, 3.5, a, cor)
	_circ(xf, c, 3.0, cor)


## A tesoura com o pivô em `c`; `abre` é a abertura das lâminas, em radianos.
func _icone_tesoura(xf: Transform2D, c: Vector2, cor: Color, abre: float) -> void:
	for s in [-1.0, 1.0]:
		var a: float = -PI / 2.0 + s * abre
		_linha(xf, PackedVector2Array([c, c + Vector2.from_angle(a) * 18.0]), cor, 3.0)
		var b: float = PI / 2.0 - s * abre
		var anel := c + Vector2.from_angle(b) * 9.0 + Vector2(0.0, 3.0)
		_arco(xf, anel, 5.0, 0.0, TAU, cor, 2.5)
	_circ(xf, c, 2.0, cor)


# --- desenho: a câmara (Veggie) -------------------------------------------------

func _desenhar_camara() -> void:
	var largura := _larg
	_mul = ROSA.lerp(Color.WHITE, _luz)  # a luz do Veggie: rosa (LEDs vermelho + azul) ou branca (com o verde)
	var xf := _xc
	_ret(xf, 0.0, 0.0, largura, _alt, PAREDE)
	var x := 20.0
	while x < largura:
		_ret(xf, x, 0.0, 1.0 / _u, _alt, GRADE)
		x += 20.0
	# O fole: as paredes sanfonadas do Veggie.
	for lado in 2:
		var x0 := largura - 14.0 if lado == 1 else 4.0
		var pts := PackedVector2Array()
		for k in 15:
			pts.append(Vector2(x0 + (10.0 if k % 2 == 1 else 0.0), 22.0 + k * 10.5))
		_linha(xf, pts, _com_alfa(FOLE, 0.8), 1.5)
	var cx := largura / 2.0
	var bandeja_y := _alt - 20.0
	# O cone de luz.
	_poli(xf, PackedVector2Array([Vector2(26, 18), Vector2(largura - 26.0, 18), Vector2(largura - 6.0, bandeja_y),
		Vector2(6, bandeja_y)]), Color(1.0, 1.0, 1.0, 0.05))
	# A poça na bandeja (a encharcada a mais), a bandeja e as almofadas.
	if _u_vis > 1.0:
		var f := minf(1.0, _u_vis - 1.0)
		_elipse(xf, Vector2(cx + 10.0, bandeja_y + 1.0), 46.0 * f + 10.0, 4.0, 0.0, _com_alfa(POCA, 0.85 * f))
	_ret(xf, 16.0, bandeja_y + 2.0, largura - 32.0, 8.0, BANDEJA)
	_ret(xf, 16.0, bandeja_y + 8.0, largura - 32.0, 2.0, BANDEJA_SOMBRA)
	_almofada(xf, 40.0, bandeja_y, 26.0, 12.0, ALM_OK)
	_almofada(xf, largura - 40.0, bandeja_y, 26.0, 12.0, ALM_OK)
	var uv := _u_vis
	var cor_alm := ALM_OK
	if uv < 0.0:
		cor_alm = _mist(ALM_OK, ALM_SECA, -uv)
	elif uv > 0.0:
		cor_alm = _mist(ALM_OK, ALM_MOLHADA, minf(1.0, uv))
	_almofada(xf, cx, bandeja_y, 52.0, 20.0, cor_alm)
	if uv > 0.3:  # o brilho de molhado
		_ret(xf, cx - 16.0, bandeja_y - 15.0, 10.0, 2.0, Color(1.0, 1.0, 1.0, 0.25 * minf(1.0, uv)))
	if uv < -0.3:  # as rachaduras
		var rach := _com_alfa(FOLHA_MARROM, minf(1.0, -uv) * 0.8)
		_linha(xf, PackedVector2Array([Vector2(cx - 14.0, bandeja_y - 8.0), Vector2(cx - 8.0, bandeja_y - 11.0),
			Vector2(cx - 4.0, bandeja_y - 7.0)]), rach, 1.0)
		_linha(xf, PackedVector2Array([Vector2(cx + 8.0, bandeja_y - 6.0), Vector2(cx + 13.0, bandeja_y - 10.0)]), rach, 1.0)
	_desenhar_planta(Vector2(cx, bandeja_y - 17.0))
	_desenhar_ferramenta_em_acao(cx, bandeja_y)
	# O brilho rosa fraco, por cima de tudo (some com a luz verde).
	_mul = Color.WHITE
	if _luz < 1.0:
		draw_rect(_cam, _cor(_com_alfa(ROSA_BRILHO, 1.0 - _luz)))
	# O banco de LEDs, por cima: é a própria luz (rosa sob o Veggie, branca com o verde).
	_ret(xf, 14.0, 4.0, largura - 28.0, 12.0, LED_CASCA)
	_ret(xf, 16.0, 6.0, largura - 32.0, 8.0, LED_FUNDO)
	for k in 16:
		var xl := 14.0 + 6.0 + k * ((largura - 28.0 - 12.0) / 15.0)
		var rosa := LED_ROSA_B if k % 2 == 0 else LED_ROSA_A
		_ret(xf, roundf(xl) - 1.0, 9.0, 3.0, 3.0, rosa.lerp(LED_BRANCO, _luz))
	# O check do fim: TEXTO, não verde (não é botão).
	if _estado == Estado.CONCLUIDO:
		_ret(xf, largura - 26.0, 22.0, 20.0, 18.0, _com_alfa(Desenho.MOLDURA, 0.75))
		_linha(xf, PackedVector2Array([Vector2(largura - 22.0, 31.0), Vector2(largura - 17.0, 36.0),
			Vector2(largura - 9.0, 26.0)]), Desenho.TEXTO, 3.0)
	draw_rect(_cam, _cor(Desenho.BORDA), false, 1.0)


## A almofada de cultivo (a "pillow" do Veggie): base em `base_y`, largura `w`, altura `h`.
func _almofada(xf: Transform2D, cx: float, base_y: float, w: float, h: float, cor: Color) -> void:
	var pts := PackedVector2Array()
	pts.append_array(_bez(Vector2(cx - w / 2.0, base_y + 2.0), Vector2(cx - w / 2.0 - 2.0, base_y - h), Vector2(cx - w / 4.0, base_y - h), 6))
	pts.append_array(_bez(Vector2(cx + w / 4.0, base_y - h), Vector2(cx + w / 2.0 + 2.0, base_y - h), Vector2(cx + w / 2.0, base_y + 2.0), 6))
	_poli(xf, pts, cor)
	var contorno := pts.duplicate()
	contorno.append(pts[0])
	_linha(xf, contorno, Color(0.0, 0.0, 0.0, 0.35), 1.0)


## A planta (a zínia), com a base em `b`. Os sintomas aparecem na proporção da luz: sob a rosa a cor, as gotas
## e as manchas somem; a forma (a folha caída) não muda com a luz.
func _desenhar_planta(b: Vector2) -> void:
	var xf := _xc
	var uv := _u_vis
	var mv := _m_vis
	var seca := maxf(0.0, -uv)  # 0 a 2
	var molhada := maxf(0.0, uv)  # 0 a 2
	var ver := _luz
	# A reação: sacudida (pior) ou pulo das folhas (melhor).
	var sacode := 0.0
	var pulo := 0.0
	if not _reacao.is_empty():
		var tr: float = _reacao["t"] / T_REACAO
		if _reacao["tipo"] == "pior":
			sacode = sin(_reacao["t"] * 45.0) * 2.5 * (1.0 - tr)
		elif _reacao["tipo"] == "melhor":
			pulo = sin(minf(1.0, tr) * PI) * 0.35
	if _estado == Estado.CRESCENDO and _tg > 0.0:
		pulo += sin(minf(1.0, _tg / 0.5) * PI) * 0.3
	var altura := 74.0 + 24.0 * _g
	# O topo cai de lado quando seca: a flor de cabeça baixa.
	var topo := Vector2(b.x + sacode + 10.0 * seca, b.y - altura + 7.0 * seca)
	var ctrl := Vector2(b.x + sacode * 0.5, b.y - altura * 0.6)
	var sint_folha := FOLHA
	var sint_borda := FOLHA_BORDA
	var sint_caule := CAULE
	if seca > 0.0:
		sint_folha = _mist(FOLHA, FOLHA_SECA, seca) if seca <= 1.0 else _mist(FOLHA_SECA, FOLHA_MARROM, seca - 1.0)
		sint_borda = _mist(FOLHA_BORDA, FOLHA_SECA_BORDA, minf(1.0, seca))
		sint_caule = _mist(CAULE, FOLHA_SECA_BORDA, minf(1.0, seca))
	else:
		sint_folha = _mist(FOLHA, FOLHA_MOLHADA, minf(1.0, molhada) * 0.5)
	# A cor do sintoma só aparece com a luz branca.
	var cor_folha := FOLHA.lerp(sint_folha, ver)
	var cor_borda := FOLHA_BORDA.lerp(sint_borda, ver)
	var cor_caule := CAULE.lerp(sint_caule, ver)
	_linha(xf, _bez(b, ctrl, topo, 10), cor_caule, 3.0)
	# Os pares de folhas: [fração no caule, comprimento, semente das manchas].
	var pares: Array = [[0.22, 34.0, 1.0], [0.5, 28.0, 2.0]]
	if _g > 0.0:
		pares.append([0.76, 22.0 * _g, 3.0])
	var pontas: Array = []  # [base, ponta, lado, índice do par, semente]
	for idx in pares.size():
		var par: Array = pares[idx]
		var f: float = par[0]
		var comp: float = par[1]
		var base := _no_caule(b, ctrl, topo, f)
		for lado in [-1.0, 1.0]:
			# O ângulo: saudável sobe 25°; seca cai até ~15° abaixo da horizontal (e mais em -2) e enrola;
			# encharcada demais cai um pouco.
			var ang := -25.0 + 40.0 * minf(1.0, seca) + 18.0 * maxf(0.0, seca - 1.0)
			if molhada > 1.0:
				ang += 14.0 * (molhada - 1.0)
			ang -= pulo * 40.0
			if idx == 2:
				ang -= 10.0
			var enrola := 0.45 * minf(1.0, seca) + 0.2 * maxf(0.0, seca - 1.0)
			var larg := comp * 0.26 * (1.0 - 0.3 * minf(1.0, seca))
			var ponta := _folha(xf, base, lado, deg_to_rad(ang), comp, larg, enrola, cor_folha, cor_borda)
			pontas.append([base, ponta, lado, idx, par[2]])
	# As manchas de mofo: nas folhas de baixo (em 2, também nas de cima e no caule).
	if mv > 0.02:
		var a := minf(1.0, mv) * ver
		for pt: Array in pontas:
			var idx: int = pt[3]
			if idx == 2:
				continue
			var n := 2 if idx == 0 else (2 if mv > 1.2 else 0)
			var voltas := n + (1 if mv > 1.2 else 0)
			for k in voltas:
				var t: float = 0.35 + 0.22 * k + 0.05 * float(pt[4])
				var p: Vector2 = pt[0] + (pt[1] - pt[0]) * t - Vector2(0.0, 1.0)
				_mancha(xf, Vector2(p.x + float(pt[2]), p.y), 2.2 + (k % 2), a)
		if mv > 1.2:
			_mancha(xf, Vector2(b.x + 1.0, b.y - altura * 0.35), 2.5, minf(1.0, mv - 1.0) * ver)
	# As gotas saindo da ponta das folhas (e pingando, no +2).
	if molhada > 0.02:
		var a := minf(1.0, molhada) * ver
		for k in pontas.size():
			var pt: Array = pontas[k]
			if pt[3] == 2 and molhada < 1.5:
				continue
			var ponta: Vector2 = pt[1]
			_gota(xf, Vector2(ponta.x, ponta.y + 4.0), 3.2, a)
			if molhada > 1.3 and k % 2 == 0:
				var fase := fposmod(_tempo * 0.9 + k * 0.23, 1.0)
				_gota(xf, Vector2(ponta.x, ponta.y + 6.0 + fase * 40.0), 1.8, a * (1.0 - fase))
	_flor(xf, topo, seca, ver)
	# As faíscas do crescimento.
	if _estado == Estado.CRESCENDO and _tg > 0.0:
		var t := minf(1.0, _tg / T_CRESCER)
		var a := sin(t * PI)
		var cor := Color(Desenho.TEXTO, a)
		for k in 6:
			var ang := k * TAU / 6.0 + _tg * 2.2
			var r := 20.0 + 16.0 * t
			var p := Vector2(topo.x + cos(ang) * r, topo.y + 10.0 + sin(ang) * r * 0.8)
			var braco := 3.0 + 1.5 * sin(_tg * 10.0 + k)
			_linha(xf, PackedVector2Array([p - Vector2(braco, 0.0), p + Vector2(braco, 0.0)]), cor, 1.5)
			_linha(xf, PackedVector2Array([p - Vector2(0.0, braco), p + Vector2(0.0, braco)]), cor, 1.5)


## O ponto do caule (a curva de `b` a `topo` com controle `ctrl`) na fração `f`.
static func _no_caule(b: Vector2, ctrl: Vector2, topo: Vector2, f: float) -> Vector2:
	var a := 1.0 - f
	return a * a * b + 2.0 * a * f * ctrl + f * f * topo


## Uma folha saindo de `base` para o lado `lado` (-1 ou 1), com ângulo `ang` (para a direita), comprimento
## `comp` e largura `larg`; `enrola` curva a ponta. Devolve a ponta.
func _folha(xf: Transform2D, base: Vector2, lado: float, ang: float, comp: float, larg: float, enrola: float,
		cor: Color, borda: Color) -> Vector2:
	var d := Vector2(cos(ang) * lado, sin(ang))
	var meio := base + d * comp * 0.55
	var ang_p := ang + enrola
	var ponta := meio + Vector2(cos(ang_p) * lado, sin(ang_p)) * comp * 0.45
	var n := Vector2(-d.y * lado, d.x * lado)
	var cima := _bez(base, meio - n * larg, ponta, 8)
	var baixo := _bez(base, meio + n * larg * 0.7, ponta, 8)
	for i in cima.size() - 1:
		_tri(xf, cima[i], cima[i + 1], baixo[i], cor)
		_tri(xf, baixo[i], cima[i + 1], baixo[i + 1], cor)
	var contorno := cima.duplicate()
	for i in range(baixo.size() - 1, -1, -1):
		contorno.append(baixo[i])
	_linha(xf, contorno, borda, 1.0)
	_linha(xf, _bez(base, meio, ponta, 8), borda, 1.0)
	return ponta


func _mancha(xf: Transform2D, p: Vector2, r: float, a: float) -> void:
	_circ(xf, p, r, _com_alfa(MOFO_COR, 0.95 * a))
	var fofo := _com_alfa(MOFO_COR, 0.6 * a)
	_circ(xf, p + Vector2(r * 0.9, -r * 0.4), r * 0.6, fofo)
	_circ(xf, p + Vector2(-r * 0.8, r * 0.5), r * 0.5, fofo)


func _gota(xf: Transform2D, p: Vector2, r: float, a: float) -> void:
	var pts := PackedVector2Array()
	pts.append_array(_bez(Vector2(p.x, p.y - r * 1.9), Vector2(p.x + r * 1.1, p.y - r * 0.3), Vector2(p.x, p.y + r), 6))
	pts.append_array(_bez(Vector2(p.x, p.y + r), Vector2(p.x - r * 1.1, p.y - r * 0.3), Vector2(p.x, p.y - r * 1.9), 6))
	_poli(xf, pts, _com_alfa(GOTA, a))
	_ret(xf, roundf(p.x - r * 0.4), roundf(p.y - r * 0.4), 1.0 / _u, 1.0 / _u, Color(1.0, 1.0, 1.0, a))


## O botão de flor no topo, que abre na flor laranja (zínia) com o crescimento.
func _flor(xf: Transform2D, p: Vector2, seca: float, ver: float) -> void:
	if _g <= 0.02:
		var cor := BOTAO_FLOR
		if seca > 0.5:
			cor = BOTAO_FLOR.lerp(_mist(BOTAO_FLOR, FOLHA_SECA, minf(1.0, seca)), ver)
		_elipse(xf, Vector2(p.x, p.y - 2.0), 4.0, 5.5, seca * 0.6, cor)
		_ret(xf, roundf(p.x - 1.0), roundf(p.y - 7.0), 2.0, 2.0, PETALA_ESCURA)
		return
	var n := 12
	var r := 4.0 + 8.0 * _g
	for k in n:
		var a := TAU * k / n
		_elipse(xf, Vector2(p.x + cos(a) * r * 0.6, p.y - 3.0 + sin(a) * r * 0.6), r * 0.45, r * 0.2, a,
			PETALA if k % 2 == 1 else PETALA_ESCURA)
	_circ(xf, Vector2(p.x, p.y - 3.0), 2.0 + 2.0 * _g, MIOLO)


## A ferramenta em ação dentro da câmara, por T_FERRAMENTA: o regador inclina e as gotas caem, o ventilador gira com
## riscos de vento e a tesoura abre e fecha perto de uma folha (as manchas caem, se cortou).
func _desenhar_ferramenta_em_acao(cx: float, bandeja_y: float) -> void:
	if _anim.is_empty():
		return
	var xf := _xc
	var ta: float = _anim["t"]
	var t := ta / T_FERRAMENTA
	var entra := minf(1.0, t * 4.0)
	var sai := (1.0 - t) / 0.2 if t > 0.8 else 1.0
	var a := minf(entra, sai)
	var cor := _com_alfa(FERRAMENTA_COR, a)
	match _anim["id"]:
		"regador":
			var o := Transform2D(-0.5 * entra, Vector2(cx + 44.0, bandeja_y - 72.0))
			var xr := xf * o
			_poli(xr, PackedVector2Array([Vector2(-10, -8), Vector2(10, -8), Vector2(8, 10), Vector2(-8, 10)]), cor)
			_linha(xr, PackedVector2Array([Vector2(-8, 4), Vector2(-22, -6)]), cor, 3.0)
			for k in 6:
				var f := fposmod(t * 2.2 + k / 6.0, 1.0)
				_gota(xf, Vector2(cx + 18.0 - k * 3.0 - f * 14.0, bandeja_y - 74.0 + f * 54.0), 1.8, a)
		"ventilador":
			var c := Vector2(30.0, bandeja_y - 56.0)
			_arco(xf, c, 13.0, 0.0, TAU, cor, 2.0)
			for k in 3:
				var g2 := ta * 30.0 + k * TAU / 3.0
				_elipse(xf, c + Vector2.from_angle(g2) * 6.0, 6.0, 3.0, g2, cor)
			_ret(xf, c.x - 2.0, c.y + 13.0, 4.0, 18.0, cor)
			var vento := _com_alfa(Desenho.TEXTO, 0.7 * a)
			for k in 5:
				var f := fposmod(t * 1.8 + k * 0.2, 1.0)
				var y := c.y - 26.0 + k * 12.0
				var x := c.x + 18.0 + f * 120.0
				_linha(xf, PackedVector2Array([Vector2(x, y), Vector2(x + 18.0, y)]), vento, 1.5)
		"tesoura":
			var p := Vector2(cx - 38.0, bandeja_y - 34.0)
			var abre := 0.1 + 0.45 * absf(sin(ta * PI * 4.4))
			_icone_tesoura(xf * Transform2D(-0.4, p), Vector2.ZERO, cor, abre)
			if _anim["cortou"]:
				for k in 4:
					_mancha(xf, Vector2(p.x + 10.0 + k * 5.0, p.y + 6.0 + t * 30.0 + k * 3.0), 1.6, a)
