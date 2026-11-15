extends Control
## Minigame "Selar a amostra": três passos, sempre na mesma ordem, cada um com um botão grande.
##   1. segurar a broca até a barra de profundidade encher (T_BROCA segurando; soltar não perde o que já furou);
##   2. tocar o tubo para receber o pó (3 degraus, um por toque);
##   3. tocar a tampa para selar (a tampa desce e o selo de "lacrado" aparece).
## Sem texto, sem falha e sem sorteio: tocar fora do botão do passo não faz nada, e a peça termina só quando
## a criança termina o 3º passo. Para um adulto leva menos de 6 s.
##
## Base real: 43 tubos de amostra no Perseverance; a primeira coleta saiu vazia, e por isso o tubo se confere.
##
## Interface (comum aos minigames da noite): `signal concluido` (uma vez), `configurar(area, duracao_s,
## poeira)`, `progresso()` (0 a 1) e `avancar(delta)`. Esta peça só mostra e anima: não lê nem escreve o
## estado da missão. Quem hospeda liga `concluido` à conclusão da tarefa. Não tem `semente`: não há acaso.

signal concluido

const Desenho := preload("res://scripts/desenho.gd")

const T_BROCA := 2.0   # segurando, a barra enche em 2 s
const GRAUS := 3       # degraus do tubo, um por toque
const T_NIVEL := 0.2   # o pó sobe um degrau em 0,2 s
const T_PO := 0.35     # o pó cai no tubo depois do toque
const T_TAMPA := 0.3   # a tampa desce
const T_SELO := 0.3    # o selo aparece
const T_FIM := 0.5     # o selo fica à vista antes de a peça terminar

enum Passo { BROCA, TUBO, TAMPA, SELANDO, CONCLUIDO }

var _poeira := false
var _passo := Passo.BROCA
var _prof := 0.0          # 0 a 1: profundidade do furo
var _segurando := false
var _graus := 0           # degraus já dados (lógica)
var _nivel := 0.0         # o mesmo, suavizado para o desenho
var _t := 0.0             # tempo de animação (só o avancar anda)
var _t_toque := 99.0      # desde o último toque no tubo
var _t_tampa := 0.0       # desde o toque na tampa
var _emitido := false

# Layout, recalculado a partir do tamanho.
var _painel := Rect2()
var _cab := Rect2()
var _baias: Array[Rect2] = [Rect2(), Rect2(), Rect2()]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	size = Vector2(640, 360)
	_calcular_layout()


func configurar(area: Rect2, _duracao_s: float, poeira: bool) -> void:
	position = area.position
	size = area.size
	_poeira = poeira
	_calcular_layout()
	_reiniciar()


## 0 a 1, sem voltar: um terço por passo; só chega a 1 quando a peça termina.
func progresso() -> float:
	match _passo:
		Passo.BROCA:
			return _prof / 3.0
		Passo.TUBO, Passo.TAMPA:
			return (1.0 + float(_graus) / GRAUS) / 3.0
		Passo.SELANDO:
			return (2.0 + clampf(_t_tampa / (T_TAMPA + T_SELO + T_FIM), 0.0, 0.999)) / 3.0
	return 1.0


## Toda a lógica de tempo. `_process` só chama isto; o teste anda o tempo à mão.
func avancar(delta: float) -> void:
	_t += delta
	_t_toque += delta
	_nivel = move_toward(_nivel, float(_graus), delta / T_NIVEL)
	match _passo:
		Passo.BROCA:
			if _segurando:
				_prof = minf(1.0, _prof + delta / T_BROCA)
				if _prof >= 1.0:
					_segurando = false
					_passo = Passo.TUBO
		Passo.SELANDO:
			_t_tampa += delta
			if _t_tampa >= T_TAMPA + T_SELO + T_FIM:
				_passo = Passo.CONCLUIDO
				if not _emitido:
					_emitido = true
					concluido.emit()


## O passo em curso: 0 broca, 1 tubo, 2 tampa, 3 selando, 4 concluída.
func passo() -> int:
	return _passo


func profundidade() -> float:
	return _prof


func graus() -> int:
	return _graus


func segurando() -> bool:
	return _segurando


func concluida() -> bool:
	return _passo == Passo.CONCLUIDO


## O botão do passo `i` (0 a 2), nas coordenadas da peça.
func alvo(i: int) -> Rect2:
	return _baias[i]


## O botão que vale agora (vazio quando não há: selando ou concluída).
func alvo_do_passo() -> Rect2:
	return _baias[_passo] if _passo <= Passo.TAMPA else Rect2()


func _process(delta: float) -> void:
	avancar(delta)
	queue_redraw()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			_calcular_layout()
		NOTIFICATION_VISIBILITY_CHANGED, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_segurando = false  # o dedo some sem soltar: a broca para, o que já furou fica


func _reiniciar() -> void:
	_passo = Passo.BROCA
	_prof = 0.0
	_segurando = false
	_graus = 0
	_nivel = 0.0
	_t = 0.0
	_t_toque = 99.0
	_t_tampa = 0.0
	_emitido = false


# --- toque ---------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressionar(event.position)
		else:
			_segurando = false


func _pressionar(p: Vector2) -> void:
	if not alvo_do_passo().has_point(p):
		return
	match _passo:
		Passo.BROCA:
			_segurando = true
		Passo.TUBO:
			_graus += 1
			_t_toque = 0.0
			if _graus >= GRAUS:
				_passo = Passo.TAMPA
		Passo.TAMPA:
			_passo = Passo.SELANDO
			_t_tampa = 0.0


# --- layout --------------------------------------------------------------------

func _calcular_layout() -> void:
	var m := clampf(minf(size.x, size.y) * 0.04, 6.0, 20.0)
	_painel = Rect2(m, m, size.x - 2.0 * m, size.y - 2.0 * m)
	var hh := clampf(_painel.size.y * 0.14, 18.0, 30.0)
	_cab = Rect2(_painel.position + Vector2(2, 2), Vector2(_painel.size.x - 4.0, hh))
	var vao := clampf(_painel.size.x * 0.05, 6.0, 16.0)
	var topo := _cab.end.y + vao * 0.6
	var base := _painel.end.y - 6.0
	var larg := (_painel.size.x - 12.0 - 2.0 * vao) / 3.0
	for i in 3:
		_baias[i] = Rect2(_painel.position.x + 6.0 + i * (larg + vao), topo, larg, maxf(base - topo, 24.0))


# --- desenho -------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Desenho.FUNDO_TERMINAL)
	draw_rect(_painel, Desenho.FUNDO_TELA)
	Desenho.moldura(self, _painel, Desenho.MOLDURA, 2.0)
	Desenho.moldura(self, _painel.grow(-2.0), Desenho.BORDA, 1.0)
	_desenhar_cabecalho()
	for i in 3:
		_desenhar_baia(i)


func _desenhar_cabecalho() -> void:
	draw_rect(_cab, Desenho.FUNDO_TERMINAL)
	draw_line(Vector2(_cab.position.x, _cab.end.y), Vector2(_cab.end.x, _cab.end.y), Desenho.BORDA, 1.0)
	var lado := roundf(_cab.size.y - 8.0)
	var vao := 14.0
	var x0 := roundf(_cab.get_center().x - (3.0 * lado + 2.0 * vao) / 2.0)
	var y := roundf(_cab.position.y + (_cab.size.y - lado) / 2.0)
	var fundo := Desenho.FUNDO_TERMINAL
	for i in 3:
		var r := Rect2(x0 + i * (lado + vao), y, lado, lado)
		var feito := i < mini(_passo, 3) or _passo == Passo.CONCLUIDO
		var agora := i == mini(_passo, 2) and _passo != Passo.CONCLUIDO
		var cor := Desenho.TEXTO if agora else (Desenho.TEXTO_SUAVE if feito else Desenho.BORDA)
		match i:
			0:
				_icone_broca(r, cor, fundo)
			1:
				Desenho.icone(self, "amostra", r, cor, fundo)
			2:
				_selo(r.get_center(), lado * 0.46, cor, fundo)
		if agora:
			draw_rect(r.grow(3.0), Desenho.TEXTO, false, 1.0)
		if feito:
			Desenho.icone(self, "check", Rect2(r.end.x - 6.0, r.end.y - 6.0, 9.0, 9.0), Desenho.TEXTO, fundo)
		if i < 2:
			var cx := r.end.x + vao / 2.0
			draw_polyline(PackedVector2Array([Vector2(cx - 2, y + lado / 2.0 - 4), Vector2(cx + 2, y + lado / 2.0),
				Vector2(cx - 2, y + lado / 2.0 + 4)]), Desenho.TEXTO_SUAVE, 1.0)


func _desenhar_baia(i: int) -> void:
	var r := _baias[i]
	draw_rect(r, Desenho.FUNDO_TERMINAL)
	match i:
		0:
			_cena_broca(r)
		1:
			_cena_tubo(r)
		2:
			_cena_tampa(r)
	var futuro := i > mini(_passo, 2)
	var feito := (i < _passo and i < 2) or _passo == Passo.CONCLUIDO
	var ativo := i == _passo and _passo <= Passo.TAMPA
	draw_rect(r, Desenho.MOLDURA, false, 1.0)
	if futuro:
		draw_rect(r, Color(Desenho.FUNDO_TERMINAL, 0.6))
	if feito:
		var c := Rect2(r.end.x - 20.0, r.position.y + 5.0, 15.0, 15.0)
		draw_circle(c.get_center(), 10.0, Desenho.FUNDO_TELA)
		Desenho.icone(self, "check", c, Desenho.TEXTO, Desenho.FUNDO_TELA)
	if ativo:
		_cantoneiras(r.grow(-2.0))


## Quatro cantoneiras em L, verde (é o que se clica): braço de 8 px, traço de 2 px.
func _cantoneiras(r: Rect2) -> void:
	var braco := 8.0
	var traco := 2.0
	for canto: Vector2 in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		var sx := 1.0 if canto.x == r.position.x else -1.0
		var sy := 1.0 if canto.y == r.position.y else -1.0
		draw_rect(Rect2(canto.x if sx > 0 else canto.x - braco, canto.y if sy > 0 else canto.y - traco, braco, traco), Desenho.VERDE)
		draw_rect(Rect2(canto.x if sx > 0 else canto.x - traco, canto.y if sy > 0 else canto.y - braco, traco, braco), Desenho.VERDE)


## Onda que cresce de `c`: diz "toque aqui" sem palavra. Segurando, vira um anel fixo.
func _ondas(c: Vector2, raio: float, segura: bool) -> void:
	if segura:
		draw_arc(c, raio * 0.55, 0.0, TAU, 28, Color(Desenho.TEXTO, 0.9), 2.0)
		return
	var f := fposmod(_t * 1.1, 1.0)
	draw_arc(c, raio * (0.25 + 0.5 * f), 0.0, TAU, 28, Color(Desenho.TEXTO, 1.0 - f), 2.0)


# --- passo 1: a broca ------------------------------------------------------------

func _cena_broca(r: Rect2) -> void:
	var cx := r.get_center().x
	var topo_rocha := r.position.y + r.size.y * 0.52
	var base_rocha := r.end.y - 22.0
	var larg := r.size.x * 0.84
	var x0 := cx - larg / 2.0
	# A rocha: perfil irregular em cima, camadas por dentro.
	var pts := PackedVector2Array([
		Vector2(x0, base_rocha), Vector2(x0, topo_rocha + 5.0), Vector2(x0 + larg * 0.18, topo_rocha - 2.0),
		Vector2(x0 + larg * 0.38, topo_rocha + 2.0), Vector2(x0 + larg * 0.62, topo_rocha),
		Vector2(x0 + larg * 0.82, topo_rocha - 3.0), Vector2(x0 + larg, topo_rocha + 4.0), Vector2(x0 + larg, base_rocha)])
	draw_colored_polygon(pts, Desenho.BORDA)
	var alt := base_rocha - topo_rocha
	for k in 3:
		var yk := topo_rocha + alt * (0.38 + 0.26 * k)
		draw_line(Vector2(x0 + 3.0, yk), Vector2(x0 + larg - 3.0, yk), Desenho.TEXTO_SUAVE.darkened(0.35), 1.0)
	# O furo, mais fundo a cada instante.
	var fundo_max := alt * 0.78
	var furo := _prof * fundo_max
	var lf := maxf(5.0, r.size.x * 0.1)
	if furo > 0.0:
		draw_rect(Rect2(cx - lf / 2.0, topo_rocha, lf, furo), Desenho.MOLDURA)
	# A broca: haste com espiral, ponta e carro no mastro. Treme enquanto fura.
	var tremor := sin(_t * 70.0) * 1.2 if _segurando else 0.0
	var ponta := topo_rocha - 5.0 + (furo if _passo == Passo.BROCA else 0.0)
	var hh := r.size.y * 0.34
	var x := cx + tremor
	var lh := maxf(5.0, lf * 0.9)
	draw_line(Vector2(cx, r.position.y), Vector2(cx, ponta - hh - 10.0), Desenho.BORDA, 2.0)
	var carro := Rect2(x - lh * 1.4, ponta - hh - 12.0, lh * 2.8, 12.0)
	draw_rect(carro, Desenho.MOLDURA)
	draw_rect(carro.grow(-1.0), Desenho.TEXTO_SUAVE)
	draw_rect(Rect2(x - lh / 2.0, ponta - hh, lh, hh - 5.0), Desenho.TEXTO_SUAVE)
	var k := 0.0
	while k < hh - 6.0:
		draw_line(Vector2(x - lh / 2.0, ponta - hh + k), Vector2(x + lh / 2.0, ponta - hh + k + 4.0), Desenho.BORDA, 1.0)
		k += 6.0
	draw_colored_polygon(PackedVector2Array([Vector2(x - lh / 2.0, ponta - 5.0), Vector2(x + lh / 2.0, ponta - 5.0),
		Vector2(x, ponta + 3.0)]), Desenho.TEXTO)
	# Poeira saltando do furo enquanto fura.
	if _segurando:
		for j in 5:
			var u := fposmod(_t * 2.2 + j * 0.2, 1.0)
			var lado := -1.0 if j % 2 == 0 else 1.0
			draw_circle(Vector2(cx + lado * (lf * 0.6 + u * 14.0 * (0.6 + 0.2 * j)), topo_rocha - 2.0 - sin(u * PI) * 12.0),
				1.5, Color(Desenho.TEXTO, 1.0 - u))
	# A barra de profundidade, embaixo.
	Desenho.celulas(self, Rect2(r.position.x + r.size.x * 0.1, r.end.y - 16.0, r.size.x * 0.8, 9.0), _prof * 8.0, 8, Desenho.TEXTO)
	if _passo == Passo.BROCA:
		_ondas(Vector2(cx, topo_rocha - hh * 0.4), minf(r.size.x, r.size.y) * 0.7, _segurando)


# --- passo 2: o tubo -------------------------------------------------------------

## Geometria do tubo dentro da baia: [x do meio, topo, base, largura].
func _tubo_em(r: Rect2) -> Array:
	var tw := clampf(r.size.x * 0.32, 18.0, 56.0)
	return [r.get_center().x, r.position.y + r.size.y * 0.24, r.end.y - 24.0, tw]


func _tubo(r: Rect2, nivel: float) -> void:
	var g := _tubo_em(r)
	var cx: float = g[0]
	var topo: float = g[1]
	var base: float = g[2]
	var tw: float = g[3]
	var raio := tw / 2.0
	var corpo_base := base - raio
	# Vidro: corpo e fundo redondo.
	draw_rect(Rect2(cx - raio, topo, tw, corpo_base - topo), Desenho.FUNDO_TELA)
	draw_circle(Vector2(cx, corpo_base), raio, Desenho.FUNDO_TELA)
	# Pó: sobe do fundo, um terço por degrau.
	var cheio := (base - 3.0) - (topo + 4.0)
	var h := cheio * clampf(nivel / GRAUS, 0.0, 1.0)
	if nivel > 0.0:
		var y_nivel := base - 3.0 - h
		draw_circle(Vector2(cx, corpo_base), raio - 3.0, Desenho.TEXTO)
		draw_rect(Rect2(cx - raio + 3.0, y_nivel, tw - 6.0, maxf(0.0, corpo_base - y_nivel)), Desenho.TEXTO)
		draw_rect(Rect2(cx - raio + 3.0, y_nivel, tw - 6.0, 1.0), Desenho.TEXTO_SUAVE)
	# Contorno e marcas dos degraus.
	draw_line(Vector2(cx - raio, topo), Vector2(cx - raio, corpo_base), Desenho.TEXTO_SUAVE, 2.0)
	draw_line(Vector2(cx + raio, topo), Vector2(cx + raio, corpo_base), Desenho.TEXTO_SUAVE, 2.0)
	draw_arc(Vector2(cx, corpo_base), raio, 0.0, PI, 16, Desenho.TEXTO_SUAVE, 2.0)
	for k in range(1, GRAUS):
		var yk := (base - 3.0) - cheio * k / GRAUS
		draw_line(Vector2(cx + raio - 1.0, yk), Vector2(cx + raio + 5.0, yk), Desenho.TEXTO_SUAVE, 2.0)


func _cena_tubo(r: Rect2) -> void:
	var g := _tubo_em(r)
	_tubo(r, _nivel)
	# O pó cai da boca do tubo até o nível, logo depois de cada toque.
	if _t_toque < T_PO:
		var u := _t_toque / T_PO
		var cx: float = g[0]
		var topo: float = g[1]
		var base: float = g[2]
		var alvo_y := base - 3.0 - ((base - 3.0) - (topo + 4.0)) * float(_graus) / GRAUS
		for j in 4:
			var uj := clampf(u * 1.4 - j * 0.1, 0.0, 1.0)
			draw_circle(Vector2(cx + (j - 1.5) * 3.0, lerpf(topo - 14.0, alvo_y, uj)), 1.5, Color(Desenho.TEXTO, 1.0 - u * 0.6))
	Desenho.celulas(self, Rect2(r.position.x + r.size.x * 0.1, r.end.y - 16.0, r.size.x * 0.8, 9.0), float(_graus), GRAUS, Desenho.TEXTO)
	if _passo == Passo.TUBO:
		var cx2: float = g[0]
		_ondas(Vector2(cx2, (float(g[1]) + float(g[2])) / 2.0), minf(r.size.x, r.size.y) * 0.7, false)


# --- passo 3: a tampa ------------------------------------------------------------

func _cena_tampa(r: Rect2) -> void:
	var g := _tubo_em(r)
	var cx: float = g[0]
	var topo: float = g[1]
	var tw: float = g[3]
	_tubo(r, _nivel)
	# A tampa paira em cima do tubo e desce quando se toca; depois vem o selo.
	var alt_tampa := 9.0
	var paira := r.size.y * 0.2
	var desce := 0.0
	if _passo == Passo.SELANDO or _passo == Passo.CONCLUIDO:
		desce = smoothstep(0.0, 1.0, clampf(_t_tampa / T_TAMPA, 0.0, 1.0)) if _passo == Passo.SELANDO else 1.0
	var balanco := sin(_t * 4.0) * 2.0 if _passo == Passo.TAMPA else 0.0
	var y_tampa := topo - alt_tampa + 3.0 - paira * (1.0 - desce) + balanco
	var cw := tw + 8.0
	var tampa := Rect2(cx - cw / 2.0, y_tampa, cw, alt_tampa)
	draw_rect(tampa.grow(1.0), Desenho.MOLDURA)
	draw_rect(tampa, Desenho.TEXTO_SUAVE)
	for k in range(1, 5):
		draw_line(Vector2(tampa.position.x + k * cw / 5.0, tampa.position.y + 1.0), Vector2(tampa.position.x + k * cw / 5.0, tampa.end.y - 1.0), Desenho.BORDA, 1.0)
	# Selo de lacrado: faixa na boca do tubo e o carimbo que "bate" (cresce e assenta).
	if _passo == Passo.SELANDO or _passo == Passo.CONCLUIDO:
		var ts := (_t_tampa - T_TAMPA) if _passo == Passo.SELANDO else 99.0
		if ts >= 0.0:
			var faixa := Rect2(cx - cw / 2.0 - 1.0, topo + 6.0, cw + 2.0, 5.0)
			draw_rect(faixa, Desenho.TEXTO)
			var k := clampf(ts / T_SELO, 0.0, 1.0)
			var esc := lerpf(1.7, 1.0, smoothstep(0.0, 1.0, k))
			var raio := clampf(r.size.x * 0.17, 9.0, 24.0) * esc
			var c := Vector2(cx, (float(g[1]) + float(g[2])) / 2.0 + 6.0)
			draw_circle(c + Vector2(1.0, 2.0), raio, Color(0, 0, 0, 0.35 * k))
			_selo(c, raio, Desenho.TEXTO, Desenho.FUNDO_TERMINAL, k)
	elif _passo == Passo.TAMPA:
		_ondas(Vector2(cx, topo - paira * 0.4), minf(r.size.x, r.size.y) * 0.7, false)


# --- desenhos pequenos --------------------------------------------------------------

## Selo de lacrado: disco de borda recortada com um check dentro.
func _selo(c: Vector2, raio: float, cor: Color, fundo: Color, alfa: float = 1.0) -> void:
	var pts := PackedVector2Array()
	var dentes := 14
	for k in dentes * 2:
		pts.append(c + Vector2.from_angle(k * PI / dentes) * raio * (1.0 if k % 2 == 0 else 0.86))
	draw_circle(c, raio * 1.06, Color(Desenho.MOLDURA, alfa))
	draw_colored_polygon(pts, Color(cor, alfa))
	draw_circle(c, raio * 0.68, Color(fundo, alfa))
	var s := raio * 1.0
	Desenho.icone(self, "check", Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s)), Color(cor, alfa), fundo)


## Broca: haste com espiral e ponta.
func _icone_broca(r: Rect2, cor: Color, fundo: Color) -> void:
	var s := minf(r.size.x, r.size.y)
	var p := r.position
	draw_rect(Rect2(p.x + s * 0.36, p.y, s * 0.28, s * 0.66), cor)
	for k in 3:
		var yk := p.y + s * (0.10 + 0.17 * k)
		draw_line(Vector2(p.x + s * 0.36, yk + s * 0.1), Vector2(p.x + s * 0.64, yk), fundo, 1.0)
	draw_colored_polygon(PackedVector2Array([p + Vector2(s * 0.30, s * 0.62), p + Vector2(s * 0.70, s * 0.62),
		p + Vector2(s * 0.5, s * 1.0)]), cor)
