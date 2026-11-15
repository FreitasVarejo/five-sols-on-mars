extends Control
## Minigame "Cultivar a planta": regular a luz e a água até os dois medidores caírem na faixa verde.
## Sem texto: o controle da luz tem uma lâmpada, o da água, uma gota; cada um tem um medidor com a faixa
## verde e dois botões grandes, − e + (o mesmo gesto do O2 −/+ do plano). Não há falha: passar da faixa
## só pede um toque para voltar. Com os dois na faixa, a planta cresce um degrau e a peça termina.
##
## Base real: Veggie e APH na ISS, em que a luz e a água se regulam para a planta crescer.
##
## Interface (comum aos minigames da noite): `signal concluido` (uma vez), `configurar(area, duracao_s,
## poeira)`, `progresso()` (0 a 1) e `semente(n)`. Esta peça só mostra e anima: não lê nem escreve o
## estado da missão. Quem hospeda liga `concluido` ao fim da tarefa da planta na missão.
##
## Calibração: cada controle parte de 2 ou 3 toques da faixa (INICIOS), então a peça pede de 4 a 6 toques
## e cabe em ≤10 s para um adulto (teto da calibração, que supõe a tarefa feita).

signal concluido

const Desenho := preload("res://scripts/desenho.gd")

const LUZ := 0
const AGUA := 1
const NIVEIS := 9  # cada medidor tem 9 casas, de 0 (embaixo) a 8
const FAIXA_DE := 4  # a faixa verde são as casas 4 e 5, no meio
const FAIXA_ATE := 5
const INICIOS := [1, 2, 7, 8]  # onde cada controle pode começar: sempre fora da faixa, a 2 ou 3 toques dela

const T_CRESCER := 1.2  # a planta cresce o degrau
const T_NIVEL := 0.1  # o medidor leva isto para andar uma casa
const T_APERTO := 0.14  # o botão fica apertado por este tempo
const LADO_MIN := 24.0  # lado mínimo do botão (o desenho nunca passa abaixo disto)
const FOLGA_TOQUE := 2.0  # o teste de acerto cresce o botão nesta folga

# Cores da ilustração (a planta, a terra). A interface usa só a paleta de desenho.gd.
const TERRA_SECA := Color("#7a5a48")
const TERRA_MOLHADA := Color("#3c2c26")
const VASO := Color("#a9b8bf")

enum Estado { LIVRE, CRESCENDO, CONCLUIDO }

var _sorteio := {}
var _nivel: Array[int] = [0, 0]
var _vis: Array[float] = [0.0, 0.0]  # a casa mostrada: anda até o nível, suave
var _estado := Estado.LIVRE
var _t := 0.0
var _tempo := 0.0  # relógio da animação (gotas, brilho)
var _emitido := false
var _aperto := Vector2i(-1, -1)  # (controle, 0 menos / 1 mais) do botão apertado agora
var _t_aperto := 0.0
var _mouse := Vector2(-1000.0, -1000.0)

# Layout, recalculado a partir do tamanho.
var _painel := Rect2()
var _colunas: Array[Rect2] = [Rect2(), Rect2()]
var _cena := Rect2()
var _icones: Array[Rect2] = [Rect2(), Rect2()]
var _medidores: Array[Rect2] = [Rect2(), Rect2()]
var _botoes: Array = [[Rect2(), Rect2()], [Rect2(), Rect2()]]
var _casa_h := 10.0


func _init() -> void:
	_sorteio = sorteio(0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	size = Vector2(640, 360)
	_calcular_layout()
	_reiniciar()


## Sorteio puro: a casa de partida da luz e a da água, ambas fora da faixa. Mesmo `n`, mesmo resultado.
static func sorteio(n: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = n
	return {"luz": INICIOS[rng.randi_range(0, INICIOS.size() - 1)], "agua": INICIOS[rng.randi_range(0, INICIOS.size() - 1)]}


func configurar(area: Rect2, _duracao_s: float, _poeira: bool) -> void:
	position = area.position
	size = area.size
	_calcular_layout()
	_reiniciar()


func semente(n: int) -> void:
	_sorteio = sorteio(n)
	_reiniciar()


func progresso() -> float:
	match _estado:
		Estado.CRESCENDO:
			return clampf(_t / T_CRESCER, 0.0, 1.0)
		Estado.CONCLUIDO:
			return 1.0
	return 0.0


## Toda a lógica de tempo. `_process` só chama isto; o teste anda o tempo à mão.
func avancar(delta: float) -> void:
	_tempo += delta
	for c in 2:
		_vis[c] = move_toward(_vis[c], float(_nivel[c]), delta / T_NIVEL)
	if _t_aperto > 0.0:
		_t_aperto = maxf(0.0, _t_aperto - delta)
		if _t_aperto <= 0.0:
			_aperto = Vector2i(-1, -1)
	if _estado == Estado.CRESCENDO:
		_t += delta
		if _t >= T_CRESCER:
			_t = T_CRESCER
			_estado = Estado.CONCLUIDO
			if not _emitido:
				_emitido = true
				concluido.emit()


## O botão do controle `c` (LUZ ou AGUA), com `passo` -1 (menos) ou +1 (mais). Devolve se mexeu no nível:
## travado enquanto a planta cresce, e parado nas pontas do medidor.
func apertar(c: int, passo: int) -> bool:
	if _estado != Estado.LIVRE:
		return false
	_aperto = Vector2i(c, 1 if passo > 0 else 0)
	_t_aperto = T_APERTO
	var novo := clampi(_nivel[c] + passo, 0, NIVEIS - 1)
	if novo == _nivel[c]:
		return false
	_nivel[c] = novo
	if na_faixa(LUZ) and na_faixa(AGUA):
		_estado = Estado.CRESCENDO
		_t = 0.0
	return true


func nivel(c: int) -> int:
	return _nivel[c]


func na_faixa(c: int) -> bool:
	return _nivel[c] >= FAIXA_DE and _nivel[c] <= FAIXA_ATE


## O retângulo do botão (`mais` falso é o −), nas coordenadas desta peça.
func retangulo_do_botao(c: int, mais: bool) -> Rect2:
	return _botoes[c][1 if mais else 0]


## O retângulo do medidor do controle `c`, nas coordenadas desta peça.
func retangulo_do_medidor(c: int) -> Rect2:
	return _medidores[c]


## O sorteio em uso: `luz` e `agua` (as casas de partida).
func sorteio_atual() -> Dictionary:
	return _sorteio


## A planta está crescendo ou já cresceu: toques são ignorados.
func ocupada() -> bool:
	return _estado != Estado.LIVRE


func concluida() -> bool:
	return _estado == Estado.CONCLUIDO


func _process(delta: float) -> void:
	avancar(delta)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_calcular_layout()


# --- estado --------------------------------------------------------------------

func _reiniciar() -> void:
	_estado = Estado.LIVRE
	_t = 0.0
	_emitido = false
	_aperto = Vector2i(-1, -1)
	_t_aperto = 0.0
	_nivel = [int(_sorteio["luz"]), int(_sorteio["agua"])]
	_vis = [float(_nivel[LUZ]), float(_nivel[AGUA])]


# --- toque ---------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_mouse = event.position
		for c in 2:
			for mais in [false, true]:
				if retangulo_do_botao(c, mais).grow(FOLGA_TOQUE).has_point(event.position):
					apertar(c, 1 if mais else -1)
					accept_event()
					return


# --- layout --------------------------------------------------------------------

func _calcular_layout() -> void:
	var w := size.x
	var h := size.y
	var m := roundf(clampf(minf(w, h) * 0.04, 4.0, 12.0))
	_painel = Rect2(m, m, w - 2.0 * m, h - 2.0 * m)
	var pad := 6.0
	var pw := roundf(clampf(_painel.size.x * 0.27, 72.0, 124.0))
	var ph := _painel.size.y - 2.0 * pad
	_colunas[LUZ] = Rect2(_painel.position.x + pad, _painel.position.y + pad, pw, ph)
	_colunas[AGUA] = Rect2(_painel.end.x - pad - pw, _painel.position.y + pad, pw, ph)
	_cena = Rect2(_colunas[LUZ].end.x + pad, _painel.position.y + pad,
		_colunas[AGUA].position.x - _colunas[LUZ].end.x - 2.0 * pad, ph)
	for c in 2:
		var r: Rect2 = _colunas[c]
		var lado := roundf(clampf(minf(r.size.x * 0.28, r.size.y * 0.15), 16.0, 28.0))
		_icones[c] = Rect2(roundf(r.get_center().x - lado / 2.0), r.position.y + 8.0, lado, lado)
		var bh := roundf(clampf(r.size.y * 0.22, LADO_MIN, 46.0))
		var bw := roundf(clampf((r.size.x - 18.0) / 2.0, LADO_MIN, 56.0))
		var vao := roundf(clampf(r.size.x - 2.0 * bw - 12.0, 4.0, 12.0))
		var x0 := roundf(r.get_center().x - (2.0 * bw + vao) / 2.0)
		var y_btn := r.end.y - 8.0 - bh
		_botoes[c] = [Rect2(x0, y_btn, bw, bh), Rect2(x0 + bw + vao, y_btn, bw, bh)]
		var topo := _icones[c].end.y + 8.0
		var livre := y_btn - 8.0 - topo
		_casa_h = floorf(maxf(livre, float(NIVEIS) * 4.0) / float(NIVEIS))
		var mh := _casa_h * NIVEIS + 4.0
		var mw := roundf(clampf(r.size.x * 0.30, 22.0, 34.0))
		_medidores[c] = Rect2(roundf(r.get_center().x - mw / 2.0), roundf(topo + (livre - mh) / 2.0), mw, mh)


# --- desenho -------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Desenho.MOLDURA)
	draw_rect(_painel, Desenho.FUNDO_TELA)
	Desenho.moldura(self, _painel, Desenho.BORDA, 2.0)
	_desenhar_cena()
	for c in 2:
		_desenhar_coluna(c)


func _desenhar_coluna(c: int) -> void:
	var r: Rect2 = _colunas[c]
	draw_rect(r, Desenho.FUNDO_TERMINAL)
	Desenho.moldura(self, r, Desenho.BORDA, 1.0)
	var ri: Rect2 = _icones[c]
	var cor_icone := Desenho.TEXTO
	if c == LUZ:
		_icone_lampada(ri, cor_icone, Desenho.FUNDO_TERMINAL)
	else:
		_icone_gota(ri, cor_icone)
	if na_faixa(c):
		var rc := Rect2(ri.end.x + 4.0, ri.position.y + ri.size.y * 0.15, ri.size.y * 0.7, ri.size.y * 0.7)
		Desenho.icone(self, "check", rc, Desenho.TEXTO, Desenho.FUNDO_TERMINAL)
	_desenhar_medidor(c)
	for mais in [false, true]:
		_desenhar_botao(c, mais)


func _desenhar_medidor(c: int) -> void:
	var r: Rect2 = _medidores[c]
	var dentro := na_faixa(c)
	var x0 := r.position.x
	var base := r.end.y - 2.0  # a casa 0 fica embaixo
	# A faixa verde: uma régua mais larga que o medidor, atrás das casas.
	var y_faixa := base - (FAIXA_ATE + 1) * _casa_h
	var faixa := Rect2(x0 - 6.0, y_faixa, r.size.x + 12.0, (FAIXA_ATE - FAIXA_DE + 1) * _casa_h)
	draw_rect(faixa.grow(1.0), Desenho.MOLDURA)
	draw_rect(faixa, Desenho.VERDE if dentro else Desenho.VERDE_ESCURO)
	draw_rect(r, Desenho.FUNDO_TELA)
	Desenho.moldura(self, r, Desenho.BORDA, 1.0)
	var topo_vis := clampi(roundi(_vis[c]), 0, NIVEIS - 1)
	for i in NIVEIS:
		var y := base - (i + 1) * _casa_h
		var na_f := i >= FAIXA_DE and i <= FAIXA_ATE
		var cor := Desenho.FUNDO_TERMINAL
		if i <= topo_vis:
			cor = Desenho.TEXTO if i == topo_vis else Desenho.TEXTO_SUAVE
		elif na_f:
			cor = Desenho.VERDE_ESCURO
		draw_rect(Rect2(x0 + 3.0, y + 1.0, r.size.x - 6.0, _casa_h - 1.0), cor)
	# Ponteiros nos dois lados da casa atual.
	var yc := base - (_vis[c] + 0.5) * _casa_h
	for lado in [-1.0, 1.0]:
		var xb := x0 - 8.0 if lado < 0.0 else r.end.x + 8.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(xb, yc), Vector2(xb - lado * 6.0, yc - 4.0), Vector2(xb - lado * 6.0, yc + 4.0)]), Desenho.TEXTO)


## Botão − ou +, no estilo dos botões verdes do terminal (verde é o que se clica).
func _desenhar_botao(c: int, mais: bool) -> void:
	var r := retangulo_do_botao(c, mais)
	var apertado := _aperto == Vector2i(c, 1 if mais else 0) and _t_aperto > 0.0
	var parado := _estado != Estado.LIVRE
	var sob := r.grow(FOLGA_TOQUE).has_point(_mouse) and not parado
	var fundo := Desenho.VERDE_CLARO if sob else Desenho.VERDE
	var borda := Desenho.VERDE_ESCURO
	var cor := Desenho.TEXTO_ESCURO
	if apertado:
		fundo = Desenho.VERDE_ESCURO
		borda = Desenho.VERDE
		cor = Desenho.TEXTO
	elif parado:
		fundo = Desenho.CELULA_VAZIA
		borda = Desenho.MOLDURA
		cor = Desenho.TEXTO_SUAVE
	draw_rect(r, borda)
	draw_rect(r.grow(-2.0), fundo)
	var ctr := r.get_center()
	var meio := roundf(minf(r.size.x, r.size.y) * 0.24)
	var esp := maxf(2.0, roundf(minf(r.size.x, r.size.y) / 9.0))
	draw_rect(Rect2(ctr.x - meio, roundf(ctr.y - esp / 2.0), meio * 2.0, esp), cor)
	if mais:
		draw_rect(Rect2(roundf(ctr.x - esp / 2.0), ctr.y - meio, esp, meio * 2.0), cor)


## Lâmpada: bulbo redondo, colar e base.
func _icone_lampada(r: Rect2, cor: Color, fundo: Color) -> void:
	var s := minf(r.size.x, r.size.y)
	var p := r.position
	var w := maxf(1.0, roundf(s / 9.0))
	var bulbo := p + Vector2(s * 0.5, s * 0.36)
	draw_circle(bulbo, s * 0.34, cor)
	draw_circle(bulbo, s * 0.34 - w, fundo)
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(s * 0.34, s * 0.60), p + Vector2(s * 0.66, s * 0.60),
		p + Vector2(s * 0.60, s * 0.74), p + Vector2(s * 0.40, s * 0.74)]), cor)
	draw_rect(Rect2(p.x + s * 0.36, p.y + s * 0.78, s * 0.28, maxf(2.0, s * 0.08)), cor)
	draw_rect(Rect2(p.x + s * 0.42, p.y + s * 0.90, s * 0.16, maxf(2.0, s * 0.08)), cor)
	# O filamento.
	draw_polyline(PackedVector2Array([
		p + Vector2(s * 0.40, s * 0.58), p + Vector2(s * 0.44, s * 0.40), p + Vector2(s * 0.56, s * 0.40),
		p + Vector2(s * 0.60, s * 0.58)]), cor, maxf(1.0, w * 0.7))


## Gota d'água: ponta em cima, barriga redonda.
func _icone_gota(r: Rect2, cor: Color) -> void:
	var s := minf(r.size.x, r.size.y)
	var p := r.position
	draw_colored_polygon(_poligono_gota(p + Vector2(s * 0.5, s * 0.64), s * 0.30, s * 0.60), cor)


## Polígono da gota centrado em `c`: `raio` na barriga, ponta `alt` acima do centro.
func _poligono_gota(c: Vector2, raio: float, alt: float) -> PackedVector2Array:
	var pts := PackedVector2Array([c + Vector2(0.0, -alt)])
	for k in 17:
		var a := deg_to_rad(-60.0 + 300.0 * k / 16.0)  # y da tela cresce para baixo: de cima à direita, por baixo, até cima à esquerda
		pts.append(c + Vector2(cos(a), sin(a)) * raio)
	return pts


func _desenhar_cena() -> void:
	var r := _cena
	draw_rect(r, Desenho.FUNDO_TERMINAL)
	Desenho.moldura(self, r, Desenho.BORDA, 1.0)
	# Painéis da parede da estufa.
	var k := 1
	while r.position.x + k * 26.0 < r.end.x:
		draw_line(Vector2(r.position.x + k * 26.0, r.position.y + 1.0), Vector2(r.position.x + k * 26.0, r.end.y - 1.0),
			Color(Desenho.BORDA, 0.35), 1.0)
		k += 1
	var cx := roundf(r.get_center().x)
	var u := clampf(minf(r.size.x / 105.0, r.size.y / 150.0), 0.6, 1.6)
	var luz := float(_vis[LUZ]) / float(NIVEIS - 1)
	var agua := float(_vis[AGUA]) / float(NIVEIS - 1)
	# O vaso e a terra.
	var y_vaso := r.end.y - 10.0 * u
	var larg_topo := 56.0 * u
	var larg_base := 40.0 * u
	var alt_vaso := 26.0 * u
	var topo_vaso := y_vaso - alt_vaso
	# A lâmpada de cultivo no teto, com o cone de luz.
	var y_lamp := r.position.y + 8.0 * u
	var lamp := Rect2(cx - 22.0 * u, y_lamp, 44.0 * u, 8.0 * u)
	var cone := PackedVector2Array([
		Vector2(cx - 18.0 * u, lamp.end.y), Vector2(cx + 18.0 * u, lamp.end.y),
		Vector2(cx + 50.0 * u, topo_vaso), Vector2(cx - 50.0 * u, topo_vaso)])
	draw_colored_polygon(cone, Color(Desenho.TEXTO, 0.02 + 0.22 * luz))
	draw_rect(lamp, Desenho.TEXTO_SUAVE)
	draw_rect(lamp, Desenho.MOLDURA, false, 1.0)
	draw_rect(Rect2(lamp.position.x + 4.0 * u, lamp.end.y - 2.0, lamp.size.x - 8.0 * u, 3.0), Color(Desenho.TEXTO, 0.25 + 0.75 * luz))
	# Gotas caindo de um bico no alto à direita, tantas quanto a água.
	var bico := Vector2(cx + 38.0 * u, y_lamp + 4.0 * u)
	draw_line(Vector2(bico.x, r.position.y + 1.0), bico, Desenho.BORDA, 3.0)
	draw_rect(Rect2(bico.x - 4.0 * u, bico.y, 8.0 * u, 3.0 * u), Desenho.TEXTO_SUAVE)
	var gotas := roundi(agua * 4.0)
	for i in gotas:
		var fase := fposmod(_tempo * 0.9 + float(i) / 4.0, 1.0)
		var gy := lerpf(bico.y + 5.0 * u, topo_vaso - 2.0 * u, fase)
		draw_colored_polygon(_poligono_gota(Vector2(bico.x - 2.0 * u + (i % 2) * 4.0 * u, gy), 2.2 * u, 4.0 * u),
			Color(Desenho.TEXTO, 0.85))
	# Vaso.
	var vaso := PackedVector2Array([
		Vector2(cx - larg_topo / 2.0, topo_vaso), Vector2(cx + larg_topo / 2.0, topo_vaso),
		Vector2(cx + larg_base / 2.0, y_vaso), Vector2(cx - larg_base / 2.0, y_vaso)])
	draw_colored_polygon(vaso, VASO)
	var contorno := vaso.duplicate()
	contorno.append(vaso[0])
	draw_polyline(contorno, Desenho.BORDA, 2.0)
	var terra := Rect2(cx - larg_topo / 2.0 + 3.0, topo_vaso - 4.0 * u, larg_topo - 6.0, 7.0 * u)
	draw_rect(terra, TERRA_SECA.lerp(TERRA_MOLHADA, agua))
	_desenhar_planta(Vector2(cx, topo_vaso - 3.0 * u), u)


## A planta, com a base em `b`. `g` (0 a 1) é o degrau: o broto cresce e ganha folhas e um botão.
func _desenhar_planta(b: Vector2, u: float) -> void:
	var g := 0.0
	match _estado:
		Estado.CRESCENDO:
			g = smoothstep(0.0, 1.0, clampf(_t / T_CRESCER, 0.0, 1.0))
		Estado.CONCLUIDO:
			g = 1.0
	var alt := lerpf(24.0, 64.0, g) * u
	var topo := b + Vector2(0.0, -alt)
	draw_line(b, topo, Desenho.VERDE_ESCURO, maxf(2.0, 3.0 * u))
	# Duas folhas de baixo, que já existem no broto e crescem.
	var f1 := lerpf(9.0, 15.0, g) * u
	var y1 := b.y - alt * 0.5
	_folha(Vector2(b.x, y1), -1.0, f1)
	_folha(Vector2(b.x, y1 - 2.0 * u), 1.0, f1)
	# A de cima nasce com o degrau.
	if g > 0.0:
		var f2 := 12.0 * u * g
		var y2 := b.y - alt * 0.78
		_folha(Vector2(b.x, y2), -1.0, f2)
		_folha(Vector2(b.x, y2 - 2.0 * u), 1.0, f2)
		# Botão de flor no alto.
		draw_circle(topo + Vector2(0.0, -2.0 * u), 4.5 * u * g, Desenho.TEXTO)
		draw_circle(topo + Vector2(0.0, -2.0 * u), 2.0 * u * g, Desenho.TEXTO_SUAVE)
	else:
		_folha(topo + Vector2(0.0, 6.0 * u), -1.0, 6.0 * u)
	# Brilhos enquanto cresce.
	if _estado == Estado.CRESCENDO:
		var a := sin(clampf(_t / T_CRESCER, 0.0, 1.0) * PI)
		for i in 4:
			var ang := TAU * i / 4.0 + _t * 2.0
			var p := b + Vector2(0.0, -alt * 0.6) + Vector2.from_angle(ang) * (26.0 + 6.0 * sin(_t * 8.0 + i)) * u
			var arm := 3.0 * u
			var cor := Color(Desenho.TEXTO, a)
			draw_line(p - Vector2(arm, 0.0), p + Vector2(arm, 0.0), cor, 1.0)
			draw_line(p - Vector2(0.0, arm), p + Vector2(0.0, arm), cor, 1.0)


## Uma folha saindo do caule em `o`, para o lado `lado` (-1 esquerda, 1 direita), de comprimento `comp`.
func _folha(o: Vector2, lado: float, comp: float) -> void:
	var pts := PackedVector2Array([
		o, o + Vector2(lado * comp * 0.5, -comp * 0.45), o + Vector2(lado * comp, -comp * 0.35),
		o + Vector2(lado * comp * 0.6, comp * 0.12)])
	draw_colored_polygon(pts, Desenho.VERDE)
	var fecho := pts.duplicate()
	fecho.append(pts[0])
	draw_polyline(fecho, Desenho.VERDE_ESCURO, 1.0)
