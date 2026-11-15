extends Control
## Minigame "ChemCam com mira": a vista pelo telescópio do ChemCam, com a rocha ampliada até a área.
## A criança toca (ou clica) nos alvos verdes; cada toque dispara o laser naquele ponto. Sem precisão e
## sem reflexo: o alvo tem raio de toque generoso e os toques durante um disparo entram na fila.
##
## Quem hospeda faz `preload`, põe a peça na árvore e chama `configurar(area, duracao_s, poeira)`.
## Não lê nem escreve estado da missão, não toca som, não usa texto (só números) e não sorteia nada.
## A entrada vem em `_input` (não `_gui_input`) para chegar antes do terminal, que é o pai e consome
## todo clique quando aberto. O toque chega como mouse emulado: só `InputEventMouse*` é tratado.

## Emitido uma vez, quando o último alvo termina de disparar.
signal concluido

const Desenho := preload("res://scripts/desenho.gd")
const TEX_NORMAL := preload("res://assets/exterior/rocha_normal.png")
const TEX_POEIRA := preload("res://assets/exterior/rocha_poeira.png")

# Coordenadas do render (px do PNG de 640x360).
const RENDER := Vector2(640, 360)
const ROCHA := Rect2(470, 124, 168, 94)  # caixa da rocha
const FOLGA := 12.0  # a região que precisa caber é a ROCHA crescida disto de cada lado
const MASTRO := Vector2(156, 18)  # cabeça do mastro, de onde sai o laser (fora do recorte)
const ALVOS: Array[Vector2] = [
	Vector2(497, 178), Vector2(528, 152), Vector2(566, 186), Vector2(603, 164)]

const PULSOS := 30  # os pulsos reais do ChemCam por ponto: aparecem só como número
const RAIO_TOQUE_MIN := 24.0  # px de raio de toque, no mínimo
const ALVO_MIN := 16.0  # tamanho visual mínimo do alvo, px

var _tex: Texture2D = TEX_NORMAL
var _duracao_s := 10.0
var _tiro_s := 1.5
var _escala := 1.0
var _recorte := Rect2(Vector2.ZERO, RENDER)
var _raio := RAIO_TOQUE_MIN
var _locais := PackedVector2Array()  # centro de cada alvo, em coordenadas locais

var _estados: Array[String] = []
var _fila: Array[int] = []
var _atual := -1
var _t := 0.0  # tempo do disparo em curso
var _feitos := 0
var _concluido := false
var _mira := Vector2.ZERO
var _mira_movida := false


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reiniciar()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_recalcular()


## `area` vem de quem hospeda (coordenadas do pai). `poeira` troca o fundo para o render com poeira.
func configurar(area: Rect2, duracao_s: float, poeira: bool) -> void:
	position = area.position
	size = area.size
	_duracao_s = duracao_s
	_tex = TEX_POEIRA if poeira else TEX_NORMAL
	_reiniciar()
	_recalcular()
	queue_redraw()


func textura() -> Texture2D:
	return _tex


## De 0 a 1: alvos feitos mais a fração do disparo em curso. Nunca cai.
func progresso() -> float:
	var n := ALVOS.size()
	if _concluido:
		return 1.0
	var fracao := _t / _tiro_s if _atual >= 0 else 0.0
	return clampf((_feitos + fracao) / n, 0.0, 1.0)


func raio_toque() -> float:
	return _raio


## Centro de cada alvo, em coordenadas locais da peça.
func alvos_na_area() -> PackedVector2Array:
	return _locais


## "pendente", "fila", "disparando" ou "feito".
func estado_alvo(i: int) -> String:
	return _estados[i]


## Move a mira (coordenadas locais).
func apontar(pos_local: Vector2) -> void:
	_mira = pos_local
	_mira_movida = true
	queue_redraw()


## O que um clique faz: dispara no alvo pendente mais próximo dentro do raio de toque (ou o põe na
## fila, se há disparo em curso). Devolve se acertou um alvo pendente. Fora disso não faz nada.
func tocar(pos_local: Vector2) -> bool:
	if _concluido:
		return false
	var i := _alvo_pendente_perto(pos_local)
	if i < 0:
		return false
	_estados[i] = "fila"
	_fila.append(i)
	if _atual < 0:
		_iniciar(_fila.pop_front())
	queue_redraw()
	return true


## Passa o tempo: é o que `_process` chama. O que sobra de um disparo segue para o próximo da fila.
func avancar(delta: float) -> void:
	if _concluido:
		return
	var resto := maxf(delta, 0.0)
	while not _concluido:
		if _atual < 0:
			if _fila.is_empty():
				break
			_iniciar(_fila.pop_front())
		var falta := _tiro_s - _t
		if resto < falta:
			_t += resto
			break
		resto -= falta
		_estados[_atual] = "feito"
		_atual = -1
		_t = 0.0
		_feitos += 1
		if _feitos >= ALVOS.size():
			_concluido = true
			queue_redraw()
			concluido.emit()
	queue_redraw()


func _process(delta: float) -> void:
	avancar(delta)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseMotion:
		var p := _para_local(event.position)
		if _dentro(p):
			apontar(p)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p := _para_local(event.position)
		if _dentro(p):
			if not _concluido:
				apontar(p)
			tocar(p)
			# Todo clique dentro da área, acertando ou não: o terminal não deve tratá-lo.
			get_viewport().set_input_as_handled()


# --- estado ------------------------------------------------------------------

func _reiniciar() -> void:
	var n := ALVOS.size()
	_estados.clear()
	for i in n:
		_estados.append("pendente")
	_fila.clear()
	_atual = -1
	_t = 0.0
	_feitos = 0
	_concluido = false
	_mira_movida = false
	_tiro_s = clampf(_duracao_s * 0.6 / n, 0.5, 2.0)


func _iniciar(i: int) -> void:
	_atual = i
	_t = 0.0
	_estados[i] = "disparando"


func _alvo_pendente_perto(p: Vector2) -> int:
	var melhor := -1
	var dmin := _raio
	for i in _locais.size():
		if _estados[i] != "pendente":
			continue
		var d := p.distance_to(_locais[i])
		if d <= dmin:
			dmin = d
			melhor = i
	return melhor


func _dentro(p: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(p)


func _para_local(p: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * p


# --- enquadramento -----------------------------------------------------------

## Recorta o render em volta da rocha e amplia até a área: a região (ROCHA + folga) sempre cabe.
func _recalcular() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var regiao := ROCHA.grow(FOLGA).intersection(Rect2(Vector2.ZERO, RENDER))
	_escala = minf(size.x / regiao.size.x, size.y / regiao.size.y)
	var tam := size / _escala
	if tam.x > RENDER.x or tam.y > RENDER.y:
		# Área muito esticada: o recorte passaria do PNG. Cobre o PNG inteiro no eixo apertado.
		_escala = maxf(size.x / RENDER.x, size.y / RENDER.y)
		tam = size / _escala
	var pos := regiao.get_center() - tam / 2.0
	pos.x = clampf(pos.x, 0.0, maxf(0.0, RENDER.x - tam.x))
	pos.y = clampf(pos.y, 0.0, maxf(0.0, RENDER.y - tam.y))
	_recorte = Rect2(pos, tam)
	_locais = PackedVector2Array()
	for a in ALVOS:
		_locais.append(_render_para_local(a))
	var dmin := INF
	for i in ALVOS.size():
		for j in range(i + 1, ALVOS.size()):
			dmin = minf(dmin, _locais[i].distance_to(_locais[j]))
	_raio = maxf(RAIO_TOQUE_MIN, dmin * 0.45)
	queue_redraw()


func _render_para_local(p: Vector2) -> Vector2:
	return (p - _recorte.position) * _escala


# --- desenho -----------------------------------------------------------------

func _draw() -> void:
	draw_texture_rect_region(_tex, Rect2(Vector2.ZERO, size), _recorte)
	for i in ALVOS.size():
		_desenhar_alvo(i)
	if _atual >= 0:
		_desenhar_disparo()
	_desenhar_contador()
	if not _concluido:
		_desenhar_mira()


func _tam_icone() -> float:
	return maxf(ALVO_MIN + 4.0, minf(_escala * 9.0, 28.0))


func _desenhar_alvo(i: int) -> void:
	var c := _locais[i]
	var tam := _tam_icone()
	var r := tam * 0.75
	match _estados[i]:
		"pendente":
			draw_circle(c, r, Color(Desenho.FUNDO_TERMINAL, 0.6))
			draw_arc(c, r, 0.0, TAU, 24, Desenho.VERDE, 2.0)
			Desenho.icone(self, "chemcam", Rect2(c - Vector2.ONE * tam / 2.0, Vector2.ONE * tam),
				Desenho.VERDE, Desenho.FUNDO_TERMINAL)
		"fila":
			# Anel tracejado em TEXTO: espera a vez.
			draw_circle(c, r, Color(Desenho.FUNDO_TERMINAL, 0.6))
			for k in 8:
				var a0 := k * TAU / 8.0
				draw_arc(c, r, a0, a0 + TAU / 16.0, 4, Desenho.TEXTO, 2.0)
			Desenho.icone(self, "chemcam", Rect2(c - Vector2.ONE * tam / 2.0, Vector2.ONE * tam),
				Desenho.TEXTO, Desenho.FUNDO_TERMINAL)
		"disparando":
			draw_circle(c, r, Color(Desenho.FUNDO_TERMINAL, 0.6))
			draw_arc(c, r, 0.0, TAU, 24, Desenho.TEXTO, 2.0)
			Desenho.icone(self, "chemcam", Rect2(c - Vector2.ONE * tam / 2.0, Vector2.ONE * tam),
				Desenho.TEXTO, Desenho.FUNDO_TERMINAL)
		"feito":
			draw_circle(c, r, Desenho.TEXTO)
			var ti := tam * 0.8
			Desenho.icone(self, "check", Rect2(c - Vector2.ONE * ti / 2.0, Vector2.ONE * ti),
				Desenho.TEXTO_ESCURO, Desenho.TEXTO)


## O traço do laser (linha fixa, vem de fora da área), a faísca e o contador de pulsos.
func _desenhar_disparo() -> void:
	var c := _locais[_atual]
	var fracao := clampf(_t / _tiro_s, 0.0, 1.0)
	var mastro := _render_para_local(MASTRO)
	# Contorno escuro por baixo: o traço branco some no fundo claro do painel.
	draw_line(mastro, c, Color(Desenho.MOLDURA, 0.7), 4.0)
	draw_line(mastro, c, Desenho.TEXTO, 2.0)
	# Faísca: cresce e some uma vez (seno de 0 a pi), sem piscar.
	var k := sin(PI * fracao)
	var comp := (_tam_icone() * 0.5 + 4.0) + 14.0 * k
	var de := _tam_icone() * 0.5 + 2.0
	for j in 8:
		var d := Vector2.from_angle(j * TAU / 8.0 + 0.2)
		draw_line(c + d * de, c + d * comp, Color(Desenho.MOLDURA, 0.7), 4.0)
	for j in 8:
		var d := Vector2.from_angle(j * TAU / 8.0 + 0.2)
		draw_line(c + d * de, c + d * comp, Color(Color.WHITE, 0.25 + 0.75 * k), 2.0)
	# Contador de pulsos, de 0 a 30, ao lado do ponto (do outro lado se faltar espaço).
	var s := str(floori(PULSOS * fracao))
	var tam_f := 12
	var larg := Desenho.largura_texto(s, tam_f, true) + 8.0
	var alt := 16.0
	var x := c.x + _tam_icone() + 6.0
	if x + larg > size.x - 2.0:
		x = c.x - _tam_icone() - 6.0 - larg
	var rc := Rect2(x, c.y - alt / 2.0 - _tam_icone() * 0.9, larg, alt)
	draw_rect(rc, Color(Desenho.FUNDO_TERMINAL, 0.85))
	Desenho.moldura(self, rc, Desenho.MOLDURA)
	Desenho.texto(self, s, rc.position + Vector2(4.0, 1.0), tam_f, Desenho.TEXTO, -1.0,
		HORIZONTAL_ALIGNMENT_LEFT, true)


## Plaquinha fixa no canto superior esquerdo: ícone da mira e "feitos/total".
func _desenhar_contador() -> void:
	var s := "%d/%d" % [_feitos, ALVOS.size()]
	var tam_f := 14
	var ic := 16.0
	var larg := 8.0 + ic + 5.0 + Desenho.largura_texto(s, tam_f, true) + 8.0
	var rc := Rect2(6.0, 6.0, larg, 24.0)
	draw_rect(rc, Color(Desenho.FUNDO_TERMINAL, 0.8))
	Desenho.moldura(self, rc, Desenho.MOLDURA, 2.0)
	Desenho.icone(self, "chemcam", Rect2(rc.position + Vector2(8.0, 4.0), Vector2.ONE * ic),
		Desenho.TEXTO, Desenho.FUNDO_TERMINAL)
	Desenho.texto(self, s, rc.position + Vector2(8.0 + ic + 5.0, 3.0), tam_f, Desenho.TEXTO, -1.0,
		HORIZONTAL_ALIGNMENT_LEFT, true)


## A mira (cruz fina em TEXTO_SUAVE) segue o ponteiro. Perto de um alvo pendente ela gruda no centro e
## abre para fora do anel do alvo, para mostrar que o toque vai acertar.
func _desenhar_mira() -> void:
	var p := _mira if _mira_movida else size / 2.0
	var i := _alvo_pendente_perto(p)
	var de := 4.0
	var ate := 11.0
	if i >= 0:
		p = _locais[i]
		de = _tam_icone() * 0.75 + 3.0
		ate = de + 8.0
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		draw_line(p + d * de, p + d * ate, Color(Desenho.MOLDURA, 0.7), 3.0)
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		draw_line(p + d * de, p + d * ate, Desenho.TEXTO_SUAVE, 1.0)
