extends Control
## Minigame "Consertar o gerador": achar a peça certa e encaixar. Sem texto: o encaixe mostra o
## contorno da forma que falta, e a criança leva à vaga uma das três peças da bandeja (toque ou arraste).
## Errar não custa nada além do tempo: a peça errada sacode no encaixe e volta.
##
## Base real: filtro entupido e sensor de hidrogênio trocado nos geradores de oxigênio da ISS.
##
## Interface (comum aos minigames da noite): `signal concluido` (uma vez), `configurar(area, duracao_s,
## poeira)`, `progresso()` (0 a 1) e `semente(n)`. Esta peça só mostra e anima: não lê nem escreve o
## estado da missão. Quem hospeda liga `concluido` ao conserto do gerador na missão.

signal concluido

const Desenho := preload("res://scripts/desenho.gd")

const FUNDO_NORMAL := "res://assets/exterior/moxie_normal.png"
const FUNDO_POEIRA := "res://assets/exterior/moxie_poeira.png"
const FORMAS := ["circulo", "quadrado", "triangulo", "hexagono", "cruz"]

const T_VOO := 0.25  # tocar ou soltar no encaixe: a peça voa até lá
const T_VOLTA_SOLTA := 0.25  # soltar longe do encaixe: volta à bandeja
const T_VOLTA_ERRADA := 0.3  # depois da sacudida, a errada volta à bandeja
const T_SACUDIDA := 0.35
const SACUDIDA_AMPLITUDE := 4.0
const SACUDIDA_OSCILACOES := 2  # no máximo 3
const T_ASSENTAR := 0.2
const T_CABECALHO := 0.3  # o alerta vira check, em fade
const LIMITE_TOQUE := 6.0  # até aqui, pressionar e soltar é um toque; além, é arrasto
const FOLGA_ENCAIXE := 0.75  # o encaixe vale expandido em 0,75·s em volta
const T_GARRA := 0.15  # a garra entra e sai em fade

enum Estado { LIVRE, PRESSIONADO, ARRASTANDO, VOANDO, SACUDINDO, VOLTANDO, ASSENTANDO, RELIGANDO, CONCLUIDO }

var _duracao_s := 20.0
var _fundo: Texture2D
var _sorteio := {}
var _estado := Estado.LIVRE
var _ativa := -1  # peça que o dedo ou a animação está mexendo
var _chegou := false  # a certa já está no encaixe
var _emitido := false
var _pos: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _t := 0.0
var _dur := 0.0
var _de := Vector2.ZERO
var _desloc := Vector2.ZERO  # do ponteiro ao centro da peça, no arrasto
var _ponto_inicial := Vector2.ZERO
var _garra := 0.0  # 0 a 1: opacidade da garra

# Layout, recalculado a partir do tamanho.
var _painel := Rect2()
var _cab := Rect2()
var _bandeja := Rect2()
var _s := 48.0  # lado da peça
var _lado := 60.0  # lado do alvo de toque
var _casas: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _encaixe := Vector2.ZERO


func _init() -> void:
	_sorteio = sorteio(0)
	_fundo = load(FUNDO_NORMAL)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	size = Vector2(640, 360)
	_calcular_layout()
	_reiniciar()


## Sorteio puro: as três formas da bandeja (distintas, na ordem), o índice da certa e a posição do
## encaixe (0 esquerda, 1 centro, 2 direita). Mesmo `n`, mesmo resultado.
static func sorteio(n: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = n
	var pool: Array = FORMAS.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return {"formas": pool.slice(0, 3), "certa": rng.randi_range(0, 2), "encaixe": rng.randi_range(0, 2)}


func configurar(area: Rect2, duracao_s: float, poeira: bool) -> void:
	position = area.position
	size = area.size
	_duracao_s = duracao_s
	_fundo = load(FUNDO_POEIRA if poeira else FUNDO_NORMAL)
	_calcular_layout()
	_reiniciar()


func semente(n: int) -> void:
	_sorteio = sorteio(n)
	_calcular_layout()
	_reiniciar()


func progresso() -> float:
	match _estado:
		Estado.ASSENTANDO:
			return clampf(_t / (T_ASSENTAR + _t_religar()), 0.0, 1.0)
		Estado.RELIGANDO:
			return clampf((T_ASSENTAR + _t) / (T_ASSENTAR + _t_religar()), 0.0, 1.0)
		Estado.CONCLUIDO:
			return 1.0
	return 0.0


## Toda a lógica de tempo. `_process` só chama isto; o teste anda o tempo à mão.
func avancar(delta: float) -> void:
	var alvo_garra := 1.0 if _garra_visivel() else 0.0
	_garra = move_toward(_garra, alvo_garra, delta / T_GARRA)
	var resto := delta
	while resto > 0.0 and _estado >= Estado.VOANDO and _estado < Estado.CONCLUIDO:
		var passo := minf(resto, _dur - _t)
		_t += passo
		resto -= passo
		_aplicar()
		if _t < _dur - 0.000001:
			break
		_fim_da_fase()


func alvo_da_peca(i: int) -> Rect2:
	return Rect2(_casas[i] - Vector2(_lado, _lado) / 2.0, Vector2(_lado, _lado))


func centro_do_encaixe() -> Vector2:
	return _encaixe


## A peça `i` está parada no seu lugar da bandeja.
func peca_na_bandeja(i: int) -> bool:
	return _pos[i].distance_to(_casas[i]) < 0.01


func posicao_da_peca(i: int) -> Vector2:
	return _pos[i]


## O sorteio em uso: `formas`, `certa` e `encaixe`.
func sorteio_atual() -> Dictionary:
	return _sorteio


## Há uma peça animando (voando, sacudindo, voltando) ou o conserto em curso: toques são ignorados.
func ocupada() -> bool:
	return _estado >= Estado.VOANDO


func concluida() -> bool:
	return _estado == Estado.CONCLUIDO


## A textura de fundo em uso.
func fundo() -> Texture2D:
	return _fundo


func _process(delta: float) -> void:
	avancar(delta)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_calcular_layout()
		if _estado == Estado.LIVRE:
			_posicionar_pecas()


# --- estado --------------------------------------------------------------------

func _t_religar() -> float:
	return clampf(_duracao_s * 0.1, 0.6, 1.5)


func _reiniciar() -> void:
	_estado = Estado.LIVRE
	_ativa = -1
	_chegou = false
	_emitido = false
	_t = 0.0
	_dur = 0.0
	_garra = 0.0
	_posicionar_pecas()


func _posicionar_pecas() -> void:
	for i in 3:
		_pos[i] = _encaixe if (_chegou and i == _sorteio["certa"]) else _casas[i]


func _garra_visivel() -> bool:
	return _ativa >= 0 and (_estado == Estado.ARRASTANDO or _estado == Estado.VOANDO
		or _estado == Estado.SACUDINDO or _estado == Estado.VOLTANDO)


func _iniciar_voo() -> void:
	_estado = Estado.VOANDO
	_t = 0.0
	_dur = T_VOO
	_de = _pos[_ativa]


func _iniciar_volta(dur: float) -> void:
	_estado = Estado.VOLTANDO
	_t = 0.0
	_dur = dur
	_de = _pos[_ativa]


## Posição da peça ativa no ponto `_t` da fase atual.
func _aplicar() -> void:
	var u := clampf(_t / _dur, 0.0, 1.0) if _dur > 0.0 else 1.0
	match _estado:
		Estado.VOANDO:
			_pos[_ativa] = _de.lerp(_encaixe, smoothstep(0.0, 1.0, u))
		Estado.VOLTANDO:
			_pos[_ativa] = _de.lerp(_casas[_ativa], smoothstep(0.0, 1.0, u))
		Estado.SACUDINDO:
			var dx := sin(TAU * SACUDIDA_OSCILACOES * u) * SACUDIDA_AMPLITUDE * (1.0 - u)
			_pos[_ativa] = _encaixe + Vector2(dx, 0.0)


func _fim_da_fase() -> void:
	match _estado:
		Estado.VOANDO:
			_pos[_ativa] = _encaixe
			_t = 0.0
			if _ativa == _sorteio["certa"]:
				_chegou = true
				_estado = Estado.ASSENTANDO
				_dur = T_ASSENTAR
			else:
				_estado = Estado.SACUDINDO
				_dur = T_SACUDIDA
		Estado.SACUDINDO:
			_pos[_ativa] = _encaixe
			_iniciar_volta(T_VOLTA_ERRADA)
		Estado.VOLTANDO:
			_pos[_ativa] = _casas[_ativa]
			_ativa = -1
			_estado = Estado.LIVRE
		Estado.ASSENTANDO:
			_t = 0.0
			_estado = Estado.RELIGANDO
			_dur = _t_religar()
		Estado.RELIGANDO:
			_estado = Estado.CONCLUIDO
			_ativa = -1
			if not _emitido:
				_emitido = true
				concluido.emit()


# --- toque ---------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressionar(event.position)
		else:
			_soltar(event.position)
	elif event is InputEventMouseMotion:
		_mover(event.position)


func _pressionar(p: Vector2) -> void:
	if _estado != Estado.LIVRE:
		return
	for i in 3:
		if alvo_da_peca(i).has_point(p):
			_ativa = i
			_estado = Estado.PRESSIONADO
			_ponto_inicial = p
			_desloc = _pos[i] - p
			return


func _mover(p: Vector2) -> void:
	if _estado == Estado.PRESSIONADO and p.distance_to(_ponto_inicial) > LIMITE_TOQUE:
		_estado = Estado.ARRASTANDO
	if _estado == Estado.ARRASTANDO:
		# Presa à área: a peça não se desenha por cima do que o hospedeiro põe em volta (o mapa).
		var meio := _s / 2.0
		var q := p + _desloc
		_pos[_ativa] = Vector2(clampf(q.x, meio, maxf(meio, size.x - meio)), clampf(q.y, meio, maxf(meio, size.y - meio)))


func _soltar(_p: Vector2) -> void:
	if _estado == Estado.PRESSIONADO:
		_iniciar_voo()
	elif _estado == Estado.ARRASTANDO:
		var zona := Rect2(_encaixe - Vector2(_s, _s) / 2.0, Vector2(_s, _s)).grow(FOLGA_ENCAIXE * _s)
		if zona.has_point(_pos[_ativa]):
			_iniciar_voo()
		else:
			_iniciar_volta(T_VOLTA_SOLTA)


# --- layout --------------------------------------------------------------------

func _calcular_layout() -> void:
	var w := size.x
	var h := size.y
	var m := clampf(minf(w, h) * 0.06, 10.0, 26.0)
	_painel = Rect2(m, m, w - 2.0 * m, h - 2.0 * m)
	var hh := clampf(_painel.size.y * 0.12, 16.0, 28.0)
	_cab = Rect2(_painel.position + Vector2(2, 2), Vector2(_painel.size.x - 4.0, hh))
	_s = roundf(clampf(minf(_painel.size.x * 0.18, _painel.size.y * 0.26), 24.0, 72.0) / 2.0) * 2.0
	_lado = maxf(_s + 12.0, 32.0)
	var faixa := _lado + 12.0
	_bandeja = Rect2(_painel.position.x + 6.0, _painel.end.y - 6.0 - faixa, _painel.size.x - 12.0, faixa)
	var passo := _lado + clampf(_painel.size.x * 0.05, 6.0, 28.0)
	var cx := _painel.get_center().x
	for i in 3:
		_casas[i] = Vector2(roundf(cx + (i - 1) * passo), roundf(_bandeja.get_center().y))
	var meio := _painel.position.y + _painel.size.y / 2.0
	var cy := roundf((_cab.end.y + meio) / 2.0)
	var fracoes := [0.25, 0.5, 0.75]
	_encaixe = Vector2(roundf(_painel.position.x + _painel.size.x * fracoes[_sorteio["encaixe"]]), cy)


# --- desenho -------------------------------------------------------------------

func _draw() -> void:
	_desenhar_fundo()
	_desenhar_painel()
	_desenhar_cabecalho()
	_desenhar_encaixe()
	for i in 3:
		if i != _ativa or _estado == Estado.ASSENTANDO:
			_desenhar_peca(i)
	if _ativa >= 0 and _estado != Estado.ASSENTANDO:
		if _garra > 0.0:
			_desenhar_garra(_pos[_ativa])
		_desenhar_peca(_ativa)
	if not _chegou:
		for i in 3:
			if i != _ativa or peca_na_bandeja(i):
				_desenhar_cantoneiras(alvo_da_peca(i))


func _desenhar_fundo() -> void:
	var tam := _fundo.get_size()
	var esc := maxf(size.x / tam.x, size.y / tam.y)
	var dest := tam * esc
	draw_texture_rect(_fundo, Rect2((size - dest) / 2.0, dest), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.06, 0.09, 0.5))


func _desenhar_painel() -> void:
	var p := _painel
	# Portinhola aberta de lado, à esquerda: aparece de perfil, em perspectiva.
	var lp := p.position.x
	var lw := lp * 0.75
	var y0 := p.position.y + _cab.size.y + 10.0
	var y1 := p.end.y - 10.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(lp, y0), Vector2(lp - lw, y0 + 5.0), Vector2(lp - lw, y1 - 5.0), Vector2(lp, y1)]), Desenho.BORDA)
	draw_polyline(PackedVector2Array([
		Vector2(lp, y0), Vector2(lp - lw, y0 + 5.0), Vector2(lp - lw, y1 - 5.0), Vector2(lp, y1)]), Desenho.MOLDURA, 1.0)
	draw_line(Vector2(lp - lw * 0.55, y0 + 12.0), Vector2(lp - lw * 0.55, y0 + 22.0), Desenho.TEXTO_SUAVE, 2.0)
	for yd: float in [y0 + 6.0, y1 - 10.0]:
		draw_rect(Rect2(lp - 1.0, yd, 3.0, 5.0), Desenho.MOLDURA)
	# Chapa.
	draw_rect(p, Desenho.FUNDO_TELA)
	Desenho.moldura(self, p, Desenho.MOLDURA, 2.0)
	Desenho.moldura(self, p.grow(-2.0), Desenho.BORDA, 1.0)
	for canto: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var c := p.get_center() + (p.size / 2.0 - Vector2(7, 7)) * canto
		draw_circle(c, 3.0, Desenho.BORDA)
		draw_circle(c + Vector2(-0.5, -0.5), 1.5, Desenho.TEXTO_SUAVE)
		draw_line(c + Vector2(-2, 1), c + Vector2(2, -1), Desenho.MOLDURA, 1.0)
	# Bandeja rebaixada.
	draw_rect(_bandeja, Desenho.FUNDO_TERMINAL)
	Desenho.moldura(self, _bandeja, Desenho.MOLDURA, 1.0)


func _desenhar_cabecalho() -> void:
	draw_rect(_cab, Desenho.FUNDO_TERMINAL)
	draw_line(Vector2(_cab.position.x, _cab.end.y), Vector2(_cab.end.x, _cab.end.y), Desenho.BORDA, 1.0)
	var lado := roundf(_cab.size.y - 8.0)
	var vao := 12.0
	var x0 := roundf(_cab.get_center().x - (3.0 * lado + 2.0 * vao) / 2.0)
	var y := roundf(_cab.position.y + (_cab.size.y - lado) / 2.0)
	var fundo := Desenho.FUNDO_TERMINAL
	Desenho.icone(self, "gerador", Rect2(x0, y, lado, lado), Desenho.TEXTO_SUAVE, fundo)
	var k := _k_cabecalho()
	var r_meio := Rect2(x0 + lado + vao, y, lado, lado)
	if k < 1.0:
		Desenho.icone(self, "alerta", r_meio, Color(Desenho.AMARELO, 1.0 - k), fundo)
	if k > 0.0:
		Desenho.icone(self, "check", r_meio, Color(Desenho.TEXTO, k), fundo)
	var cor_o2 := Desenho.CELULA_VAZIA.lerp(Desenho.OXIGENIO, _k_oxigenio())
	Desenho.icone(self, "oxigenio", Rect2(x0 + 2.0 * (lado + vao), y, lado, lado), cor_o2, fundo)


## 0 (quebrado) a 1 (consertado): o alerta vira check em fade logo depois que a certa chega.
func _k_cabecalho() -> float:
	var t_cons := 0.0
	match _estado:
		Estado.ASSENTANDO:
			t_cons = _t
		Estado.RELIGANDO:
			t_cons = T_ASSENTAR + _t
		Estado.CONCLUIDO:
			return 1.0
		_:
			return 0.0
	return smoothstep(0.0, 1.0, clampf(t_cons / T_CABECALHO, 0.0, 1.0))


## 0 (apagado) a 1 (aceso): sobe suave ao longo da animação de religar.
func _k_oxigenio() -> float:
	match _estado:
		Estado.RELIGANDO:
			return smoothstep(0.0, 1.0, clampf(_t / _dur, 0.0, 1.0))
		Estado.CONCLUIDO:
			return 1.0
	return 0.0


func _desenhar_encaixe() -> void:
	var forma: String = _sorteio["formas"][_sorteio["certa"]]
	var recesso := Rect2(_encaixe - Vector2(_s + 10.0, _s + 10.0) / 2.0, Vector2(_s + 10.0, _s + 10.0))
	draw_rect(recesso, Desenho.MOLDURA)
	Desenho.moldura(self, recesso, Desenho.BORDA, 1.0)
	var pts := _poligono(forma, _encaixe, 1.0)
	draw_colored_polygon(pts, Desenho.FUNDO_TERMINAL)
	if not _chegou:
		_tracejar(pts, Desenho.TEXTO, 2.0)


## Contorno tracejado de um polígono fechado: um traço por trecho, sempre com o começo no vértice.
func _tracejar(pts: PackedVector2Array, cor: Color, larg: float) -> void:
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var comp := a.distance_to(b)
		var n := maxi(1, roundi(comp / 10.0))
		for k in n:
			draw_line(a.lerp(b, float(k) / n), a.lerp(b, (k + 0.62) / n), cor, larg)


func _desenhar_peca(i: int) -> void:
	var forma: String = _sorteio["formas"][i]
	var c := _pos[i]
	var esc := 1.0
	var no_ar := i == _ativa and not peca_na_bandeja(i)
	if i == _ativa and _estado == Estado.ASSENTANDO:
		esc = lerpf(1.15, 1.0, smoothstep(0.0, 1.0, clampf(_t / _dur, 0.0, 1.0)))
	if no_ar:
		var sombra := _poligono(forma, c + Vector2(2, 3), esc)
		draw_colored_polygon(sombra, Color(0, 0, 0, 0.35))
	var pts := _poligono(forma, c, esc)
	draw_colored_polygon(pts, Desenho.TEXTO_SUAVE)
	var fecho := pts.duplicate()
	fecho.append(pts[0])
	draw_polyline(fecho, Desenho.BORDA, 2.0)
	# Detalhe interno: a mesma forma menor, em baixo-relevo, e um rebite no meio.
	var miolo := _poligono(forma, c, esc * 0.5)
	miolo.append(miolo[0])
	draw_polyline(miolo, Desenho.BORDA, 1.0)
	draw_circle(c, maxf(1.5, _s * 0.05), Desenho.BORDA)


## Pontos da forma `nome` centrada em `c`, com o lado da peça `_s` vezes `esc`.
func _poligono(nome: String, c: Vector2, esc: float) -> PackedVector2Array:
	var s := _s * esc
	var pts := PackedVector2Array()
	match nome:
		"circulo":
			for k in 20:
				pts.append(c + Vector2.from_angle(k * TAU / 20.0) * s * 0.5)
		"quadrado":
			var m := s * 0.44
			pts = PackedVector2Array([c + Vector2(-m, -m), c + Vector2(m, -m), c + Vector2(m, m), c + Vector2(-m, m)])
		"triangulo":
			for k in 3:
				pts.append(c + Vector2(0, s * 0.07) + Vector2.from_angle(-PI / 2.0 + k * TAU / 3.0) * s * 0.58)
		"hexagono":
			for k in 6:
				pts.append(c + Vector2.from_angle(k * TAU / 6.0) * s * 0.52)
		"cruz":
			var a := s * 0.5
			var b := s * 0.17
			for q: Vector2 in [Vector2(-b, -a), Vector2(b, -a), Vector2(b, -b), Vector2(a, -b), Vector2(a, b), Vector2(b, b),
					Vector2(b, a), Vector2(-b, a), Vector2(-b, b), Vector2(-a, b), Vector2(-a, -b), Vector2(-b, -b)]:
				pts.append(c + q)
	return pts


## Quatro cantoneiras em L, verde (é o que se clica): braço de 8 px, traço de 2 px.
func _desenhar_cantoneiras(r: Rect2) -> void:
	var braco := 8.0
	var traco := 2.0
	for canto: Vector2 in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		var sx := 1.0 if canto.x == r.position.x else -1.0
		var sy := 1.0 if canto.y == r.position.y else -1.0
		draw_rect(Rect2(canto.x if sx > 0 else canto.x - braco, canto.y if sy > 0 else canto.y - traco, braco, traco), Desenho.VERDE)
		draw_rect(Rect2(canto.x if sx > 0 else canto.x - traco, canto.y if sy > 0 else canto.y - braco, traco, braco), Desenho.VERDE)


## Garra do braço robótico: haste vinda do alto, corpo e duas pinças segurando a peça em `c`.
func _desenhar_garra(c: Vector2) -> void:
	var a := _garra
	var metal := Color(Desenho.TEXTO_SUAVE, a)
	var borda := Color(Desenho.MOLDURA, a)
	var topo := c.y - _s * 0.5 - 8.0
	draw_rect(Rect2(c.x - 3.0, -1.0, 6.0, maxf(0.0, topo + 1.0)), borda)
	draw_rect(Rect2(c.x - 2.0, 0.0, 4.0, maxf(0.0, topo)), Color(Desenho.BORDA, a))
	draw_rect(Rect2(c.x - 8.0, topo - 4.0, 16.0, 9.0), borda)
	draw_rect(Rect2(c.x - 7.0, topo - 3.0, 14.0, 7.0), metal)
	var base := c.y - _s * 0.5 + 2.0
	for lado: float in [-1.0, 1.0]:
		var ponta := PackedVector2Array([
			Vector2(c.x + lado * 5.0, topo + 4.0),
			Vector2(c.x + lado * (_s * 0.5 + 5.0), base + 4.0),
			Vector2(c.x + lado * (_s * 0.5 + 1.0), base + _s * 0.42)])
		draw_polyline(ponta, borda, 5.0)
		draw_polyline(ponta, metal, 3.0)
