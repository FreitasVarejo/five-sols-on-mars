extends Control
## Visor da aba câmeras: à esquerda o mapa esquemático de Gale, com um botão por câmera; à direita a vista
## da câmera escolhida (o render do Blender) com a sobreposição de alvo e, embaixo, a faixa de telemetria.
## Desenha tudo em _draw() e trata o próprio toque. Não lê nem escreve estado da missão: quem hospeda
## entrega a duração, o clima, o sol, as pendências e as peças (as tarefas de cada câmera).
##
## Cores (spec, "Terminal"): verde só no que se clica (os botões do mapa); sem vermelho, amarelo nem azul.
## O alerta de pendência vai por forma e posição (chevron e anel tracejado), não por cor.

const Desenho := preload("res://scripts/desenho.gd")

signal concluido
signal camera_escolhida(nome: String)

const CAMERAS := ["painel", "rocha", "moxie", "visao_geral"]  # a câmera do céu é P2 e fica fora
# Estações da sala (não são câmeras do mapa, sem botão): hospedam a peça de uma tarefa que se faz lá (a estufa, a glovebox).
const ESTACOES := ["estufa", "glovebox"]

const GAP := 6
const TELEM_H := 30
const FRACAO_MAPA := 0.3
const LADO_ALVO := 28.0  # lado do botão de cada câmera no mapa
const FOLGA_ALVO := 4.0  # o teste de acerto cresce o botão nesta folga
const MARGEM_MAPA := 4.0  # entre o desenho do mundo e a borda do mapa
const RECUO_ALVO := 5.0  # o botão e o anel de pendência ficam a esta distância da borda do mapa
const ALTURA_CHIP := 26.0

# Números do mundo: vêm de arte/blender/exterior.py (CAMERAS, habitat(), COLUNAS, LINHAS, ROVER, ROCHA,
# MOXIE_O) e são só leitura aqui. Metros: +x leste, +y norte (rumo ao Monte Sharp). O campo de visão é o
# HORIZONTAL: o do Blender é vertical e foi convertido por 2·atan(tan(v/2)·16/9).
const POSICAO := {
	"painel": Vector2(-9.0, 9.0),
	"rocha": Vector2(0.2, 7.6),
	"moxie": Vector2(4.2, -5.6),
	"visao_geral": Vector2(-13.0, -10.5),
}
const ALVO_NO_MUNDO := {
	"painel": Vector2(-2.6, 15.0),
	"rocha": Vector2(-0.3, 13.0),
	"moxie": Vector2(9.5, -2.2),
	"visao_geral": Vector2(1.0, 12.0),
}
const CAMPO_DE_VISAO := {"painel": 46.0, "rocha": 63.0, "moxie": 52.0, "visao_geral": 85.0}
const HABITAT := Rect2(-2.8, -1.4, 5.6, 3.8)  # x −2.8..2.8, y −1.4..2.4
const ABRIGO_CENTRO := Vector2(-4.0, 0.95)
const ABRIGO_TAM := Vector2(2.4, 2.1)
const COLUNAS := [-9.3, -6.2, -3.1, 0.0, 3.1, 6.2, 9.3]
const LINHAS := [15.5, 18.5, 21.5, 24.5]
const PAINEL_TAM := Vector2(3.0, 1.5)  # largura × fundo (projeção dos 1.7 inclinados)
const ROVER_POS := Vector2(-2.5, 12.3)
const ROVER_TAM := Vector2(1.4, 2.0)
const ROCHA_POS := Vector2(2.1, 13.2)
const ROCHA_RAIO := 1.0
const MOXIE_POS := Vector2(8.7, -2.05)
const MOXIE_TAM := Vector2(1.4, 1.4)
const X_MIN := -14.5
const X_MAX := 11.5
const Y_MIN := -12.0
const Y_MAX := 29.0
const Y_MONTE := 26.0  # a faixa y 26..29 é o Monte Sharp

const CHAVE_CAMERA := {
	"painel": "CAM_PAINEL", "rocha": "CAM_ROCHA", "moxie": "CAM_MOXIE", "visao_geral": "CAM_VISAO_GERAL"}
# Perfil irregular da rocha do ChemCam: fator do raio a cada 40 graus.
const FORMA_ROCHA := [1.0, 0.8, 0.95, 0.7, 1.0, 0.85, 0.75, 0.95, 0.8]

var _mapa := Rect2()
var _vista := Rect2()
var _telem := Rect2()
var _escala := 1.0
var _origem := Vector2.ZERO
var _alvos: Dictionary = {}  # câmera -> Rect2 do botão

var _atual := "visao_geral"
var _estacao := ""  # a estação cuja peça está na vista agora; "" = a da câmera atual
var _duracao := 0.0
var _poeira := false
var _pecas: Dictionary = {}  # câmera -> Control
var _pend: Dictionary = {}  # câmera -> true, só as pendentes agora
var _lembradas: Dictionary = {}  # câmera -> true, toda a que já esteve pendente desde o último configurar
var _concluido_emitido := false
var _tem_sol := false
var _sol_n := 0
var _sol_total := 0
var _mouse := Vector2(-1000.0, -1000.0)
var _texturas: Dictionary = {}  # caminho -> Texture2D (ou null se não existe)
var _caixa_tanque := StyleBoxFlat.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_caixa_tanque.bg_color = Desenho.CELULA_VAZIA
	_caixa_tanque.border_color = Desenho.TEXTO_SUAVE
	_caixa_tanque.set_border_width_all(1)
	_caixa_tanque.set_corner_radius_all(3)
	_caixa_tanque.anti_aliasing = false
	set_process(false)
	resized.connect(_refazer_layout)
	_refazer_layout()


## `tr(chave)`, ou "" se a chave não tem tradução (aí o rótulo some e fica só o ícone).
static func palavra(chave: String) -> String:
	var s := str(TranslationServer.translate(chave))
	return "" if s == chave or s == "" else s


# --- API -------------------------------------------------------------------------

## `area` está nas coordenadas do pai; o resto é local. Zera o acompanhamento de pendências.
func configurar(area: Rect2, duracao_s: float, poeira: bool) -> void:
	position = area.position
	size = area.size
	_duracao = duracao_s
	_poeira = poeira
	_pend.clear()
	_lembradas.clear()
	_concluido_emitido = false
	set_process(false)
	_refazer_layout()
	for c in _pecas:
		var p: Control = _pecas[c]
		p.configurar(_vista, _duracao, _poeira)
	queue_redraw()


## Fração das câmeras que já tiveram tarefa e agora não têm: 0 se nenhuma foi lembrada.
func progresso() -> float:
	if _lembradas.is_empty():
		return 0.0
	var feitas := 0
	for c in _lembradas:
		if not _pend.has(c):
			feitas += 1
	return float(feitas) / float(_lembradas.size())


## `mapa`: câmera -> há tarefa pendente. Chaves fora de CAMERAS são ignoradas; a câmera que não aparece
## no mapa conta como sem pendência. O visor nunca muda pendência sozinho.
func pendencias(mapa: Dictionary) -> void:
	_pend.clear()
	for c in mapa:
		if not CAMERAS.has(c):
			continue
		if mapa[c]:
			_pend[c] = true
			_lembradas[c] = true
	set_process(not _pend.is_empty())
	queue_redraw()
	if not _concluido_emitido and not _lembradas.is_empty() and _pend.is_empty():
		_concluido_emitido = true
		concluido.emit()


## Põe `peca` na câmera `camera` (cobre a vista). `null` tira e libera a que estava lá.
func hospedar(camera: String, peca: Control) -> void:
	if not CAMERAS.has(camera) and not ESTACOES.has(camera):
		push_warning("visor_cameras: câmera desconhecida '%s'" % camera)
		return
	var antiga: Control = _pecas.get(camera)
	if peca == null and _estacao == camera:
		_estacao = ""  # a vista volta à câmera atual
	if antiga != null and antiga != peca:
		_pecas.erase(camera)
		if is_instance_valid(antiga):
			if antiga.get_parent() == self:
				remove_child(antiga)
			antiga.queue_free()
	if peca == null:
		queue_redraw()
		return
	if peca.get_parent() != self:
		if peca.get_parent() != null:
			peca.get_parent().remove_child(peca)
		add_child(peca)
	_pecas[camera] = peca
	peca.configurar(_vista, _duracao, _poeira)
	peca.visible = camera == vista_atual()
	queue_redraw()


## Telemetria: o sol atual e quantos tem a missão.
func sol(n: int, total: int) -> void:
	_tem_sol = true
	_sol_n = n
	_sol_total = total
	queue_redraw()


## Seleciona a câmera e avisa (mesmo se já era ela). Nome fora de CAMERAS: false, nada muda.
func escolher(nome: String) -> bool:
	if ESTACOES.has(nome):
		_estacao = nome  # a vista mostra a peça da estação; a câmera atual do mapa não muda
	elif CAMERAS.has(nome):
		_estacao = ""
		_atual = nome
	else:
		return false
	_atualizar_visibilidade()
	queue_redraw()
	camera_escolhida.emit(nome)
	return true


func camera_atual() -> String:
	return _atual


## O que a vista mostra: a estação escolhida ou, sem ela, a câmera atual.
func vista_atual() -> String:
	return _estacao if _estacao != "" else _atual


func alvos() -> Dictionary:
	return _alvos.duplicate()


func retangulo_vista() -> Rect2:
	return _vista


func retangulo_mapa() -> Rect2:
	return _mapa


func peca(camera: String) -> Control:
	var p: Control = _pecas.get(camera)
	return p if is_instance_valid(p) else null


# --- layout ----------------------------------------------------------------------

func _refazer_layout() -> void:
	var larg_mapa := roundf(size.x * FRACAO_MAPA)
	var vw := maxf(size.x - larg_mapa - GAP, 0.0)
	var vh := roundf(vw * 9.0 / 16.0)
	var limite := maxf(size.y - TELEM_H - GAP, 0.0)
	if vh > limite:
		vh = floorf(limite)
		vw = roundf(vh * 16.0 / 9.0)
		larg_mapa = maxf(size.x - GAP - vw, 0.0)
	_mapa = Rect2(0.0, 0.0, larg_mapa, size.y)
	_vista = Rect2(larg_mapa + GAP, 0.0, vw, vh)
	_telem = Rect2(_vista.position.x, vh + GAP, vw, TELEM_H)
	# Escala do mapa: cabe o mundo inteiro com a margem, centrado.
	var util := _mapa.size - Vector2.ONE * (MARGEM_MAPA * 2.0)
	_escala = maxf(minf(util.x / (X_MAX - X_MIN), util.y / (Y_MAX - Y_MIN)), 0.1)
	var conteudo := Vector2(X_MAX - X_MIN, Y_MAX - Y_MIN) * _escala
	_origem = (_mapa.position + (_mapa.size - conteudo) / 2.0).round()
	_alvos.clear()
	var dentro := _mapa.grow(-RECUO_ALVO)
	for c in CAMERAS:
		var ctr := _p(POSICAO[c])
		var r := Rect2(ctr - Vector2.ONE * LADO_ALVO / 2.0, Vector2.ONE * LADO_ALVO)
		r.position.x = clampf(r.position.x, dentro.position.x, maxf(dentro.end.x - LADO_ALVO, dentro.position.x))
		r.position.y = clampf(r.position.y, dentro.position.y, maxf(dentro.end.y - LADO_ALVO, dentro.position.y))
		_alvos[c] = r
	queue_redraw()


## Ponto do mundo (metros) na tela, em pixel inteiro.
func _p(w: Vector2) -> Vector2:
	return Vector2(_origem.x + (w.x - X_MIN) * _escala, _origem.y + (Y_MAX - w.y) * _escala).round()


## Retângulo do mundo (x0, y0 = canto sudoeste) na tela, em pixels inteiros e com ao menos 1 px.
func _rc(x0: float, y0: float, x1: float, y1: float) -> Rect2:
	var a := _p(Vector2(x0, y1))
	var b := _p(Vector2(x1, y0))
	return Rect2(a, Vector2(maxf(b.x - a.x, 1.0), maxf(b.y - a.y, 1.0)))


func _atualizar_visibilidade() -> void:
	for c in _pecas:
		var p: Control = _pecas[c]
		if is_instance_valid(p):
			p.visible = c == vista_atual()


func _peca_visivel() -> bool:
	var p := peca(vista_atual())
	return p != null and p.visible


func _contar_pendentes() -> int:
	return _pend.size()


# --- entrada ---------------------------------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_mouse = Vector2(-1000.0, -1000.0)
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND if _alvo_em(_mouse) != "" else Control.CURSOR_ARROW)
		queue_redraw()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		var nome := _alvo_em(ev.position)
		if nome != "":
			escolher(nome)
			accept_event()


## O alvo sob o ponto `p`: o botão crescido FOLGA_ALVO px de cada lado (alvos generosos).
func _alvo_em(p: Vector2) -> String:
	for c in CAMERAS:
		if (_alvos[c] as Rect2).grow(FOLGA_ALVO).has_point(p):
			return c
	return ""


func _process(_delta: float) -> void:
	# O marcador de pendência balança: só redesenha enquanto há pendência.
	if not _pend.is_empty() and is_visible_in_tree():
		queue_redraw()


# --- desenho: base ---------------------------------------------------------------

func _draw() -> void:
	_desenhar_mapa()
	_desenhar_vista()
	_desenhar_telemetria()


## Chip do HUD do turno (hud_turno.gd): NOITE com 0,85, borda BORDA e 1 px de relevo no topo.
func _chip(r: Rect2) -> void:
	draw_rect(r, Color(Desenho.NOITE, 0.85))
	draw_rect(r, Desenho.BORDA, false, 1.0)
	draw_rect(Rect2(r.position.x + 1, r.position.y + 1, r.size.x - 2, 1), Color(Desenho.TEXTO, 0.12))


## Linha de 1 px em pixel certo: os pontos ganham meio pixel.
func _linhas(pts: PackedVector2Array, cor: Color, grossura: float = 1.0) -> void:
	if pts.size() < 2:
		return
	var m := PackedVector2Array()
	for q in pts:
		m.append(q + Vector2(0.5, 0.5))
	draw_polyline(m, cor, grossura)


# --- desenho: ícones locais ------------------------------------------------------

## O ícone da câmera `cam` no quadrado `r`: o painel e o olho são locais; o resto vem do Desenho.
func _icone_camera(cam: String, r: Rect2, cor: Color, fundo: Color) -> void:
	match cam:
		"painel":
			_icone_painel_solar(r, cor)
		"rocha":
			Desenho.icone(self, "chemcam", r, cor, fundo)
		"moxie":
			Desenho.icone(self, "gerador", r, cor, fundo)
		"visao_geral":
			_icone_olho(r, cor, fundo)


func _icone_painel_solar(r: Rect2, cor: Color) -> void:
	var s := minf(r.size.x, r.size.y)
	var p := r.position
	var w := maxf(1.0, roundf(s / 9.0))
	var x0 := p.x + s * 0.06
	var y0 := p.y + s * 0.14
	var larg := s * 0.88
	var alt := s * 0.54
	draw_rect(Rect2(x0, y0, larg, alt), cor, false, w)
	for k in [1, 2]:
		var x: float = x0 + larg * k / 3.0
		draw_line(Vector2(x, y0), Vector2(x, y0 + alt), cor, w)
	draw_line(Vector2(x0, y0 + alt / 2.0), Vector2(x0 + larg, y0 + alt / 2.0), cor, w)
	draw_line(Vector2(p.x + s * 0.5, y0 + alt), Vector2(p.x + s * 0.5, p.y + s * 0.88), cor, w)
	draw_line(Vector2(p.x + s * 0.28, p.y + s * 0.9), Vector2(p.x + s * 0.72, p.y + s * 0.9), cor, w)


func _icone_olho(r: Rect2, cor: Color, fundo: Color) -> void:
	var s := minf(r.size.x, r.size.y)
	var p := r.position
	var w := maxf(1.0, roundf(s / 9.0))
	var c := r.get_center()
	var cima := PackedVector2Array()
	var baixo := PackedVector2Array()
	for j in 9:
		var t := j / 8.0
		var x := p.x + s * (0.04 + 0.92 * t)
		var dy := s * 0.30 * sin(PI * t)
		cima.append(Vector2(x, c.y - dy))
		baixo.append(Vector2(x, c.y + dy))
	baixo.reverse()
	cima.append_array(baixo)
	cima.append(cima[0])
	draw_polyline(cima, cor, w)
	draw_circle(c, s * 0.2, cor)
	draw_circle(c, s * 0.07, fundo)


## Céu limpo: meio Sol nascendo sobre uma linha de horizonte, com raios (não é o ícone "sol").
func _icone_ceu_limpo(r: Rect2, cor: Color) -> void:
	var s := minf(r.size.x, r.size.y)
	var p := r.position
	var w := maxf(1.0, roundf(s / 9.0))
	var hy := p.y + s * 0.74
	var cx := p.x + s * 0.5
	draw_rect(Rect2(p.x + s * 0.04, hy, s * 0.92, w), cor)
	var meio := PackedVector2Array()
	for j in 9:
		var a := PI + PI * j / 8.0
		meio.append(Vector2(cx + cos(a) * s * 0.24, hy + sin(a) * s * 0.24))
	draw_colored_polygon(meio, cor)
	for k in 5:
		var d := Vector2.from_angle(PI + PI * (k + 0.5) / 5.0)
		draw_line(Vector2(cx, hy) + d * s * 0.34, Vector2(cx, hy) + d * s * 0.50, cor, w)


# --- desenho: mapa ---------------------------------------------------------------

func _desenhar_mapa() -> void:
	draw_rect(_mapa, Desenho.FUNDO_TELA)
	_desenhar_monte()
	_desenhar_habitat()
	_desenhar_campo_de_paineis()
	_desenhar_rover_e_rocha()
	_desenhar_moxie()
	for c in CAMERAS:
		if c != _atual:
			_desenhar_cunha(c)
	_desenhar_cunha(_atual)
	_desenhar_bussola_e_escala()
	draw_rect(_mapa, Desenho.BORDA, false, 1.0)
	for c in CAMERAS:
		_desenhar_botao(c)
	for c in CAMERAS:
		if _pend.has(c):
			_desenhar_pendencia(c)


## Monte Sharp: três linhas de estrato onduladas ao longo da largura e um pequeno contorno de montanha.
func _desenhar_monte() -> void:
	_linhas(PackedVector2Array([_p(Vector2(X_MIN, Y_MONTE)), _p(Vector2(X_MAX, Y_MONTE))]), Desenho.BORDA)
	for k in 3:
		var base := Y_MONTE + 0.7 + 0.8 * k
		var pts := PackedVector2Array()
		var n := 26
		for i in n + 1:
			var x := X_MIN + (X_MAX - X_MIN) * i / n
			pts.append(_p(Vector2(x, base + 0.22 * sin(x * 0.9 + k * 1.3))))
		_linhas(pts, Color(Desenho.TEXTO_SUAVE, 0.5))
	var monte := PackedVector2Array()
	for q in [Vector2(-5.0, 26.0), Vector2(-2.6, 28.2), Vector2(-1.6, 27.5), Vector2(-0.4, 28.9),
			Vector2(2.6, 26.0)]:
		monte.append(_p(q))
	_linhas(monte, Desenho.TEXTO_SUAVE)


func _desenhar_habitat() -> void:
	var abrigo := _rc(ABRIGO_CENTRO.x - ABRIGO_TAM.x / 2.0, ABRIGO_CENTRO.y - ABRIGO_TAM.y / 2.0,
		ABRIGO_CENTRO.x + ABRIGO_TAM.x / 2.0, ABRIGO_CENTRO.y + ABRIGO_TAM.y / 2.0)
	draw_rect(abrigo, Desenho.BORDA)
	draw_rect(abrigo, Desenho.TEXTO_SUAVE, false, 1.0)
	var h := _rc(HABITAT.position.x, HABITAT.position.y, HABITAT.end.x, HABITAT.end.y)
	draw_rect(h, Desenho.CELULA_VAZIA)
	draw_rect(h, Desenho.TEXTO_SUAVE, false, 1.0)


func _desenhar_campo_de_paineis() -> void:
	for cy in LINHAS:
		for cx in COLUNAS:
			var r := _rc(cx - PAINEL_TAM.x / 2.0, cy - PAINEL_TAM.y / 2.0,
				cx + PAINEL_TAM.x / 2.0, cy + PAINEL_TAM.y / 2.0)
			r.size = (r.size - Vector2.ONE).max(Vector2.ONE)  # 1 px de vão entre os painéis
			draw_rect(r, Desenho.CELULA_VAZIA)
			draw_rect(r, Color(Desenho.TEXTO_SUAVE, 0.45), false, 1.0)


func _desenhar_rover_e_rocha() -> void:
	var rv := _rc(ROVER_POS.x - ROVER_TAM.x / 2.0, ROVER_POS.y - ROVER_TAM.y / 2.0,
		ROVER_POS.x + ROVER_TAM.x / 2.0, ROVER_POS.y + ROVER_TAM.y / 2.0)
	for k in 3:  # rodas: três de cada lado
		var y := rv.position.y + 1.0 + k * (rv.size.y - 4.0) / 2.0
		draw_rect(Rect2(rv.position.x - 2.0, roundf(y), 2.0, 3.0), Desenho.TEXTO_SUAVE)
		draw_rect(Rect2(rv.end.x, roundf(y), 2.0, 3.0), Desenho.TEXTO_SUAVE)
	draw_rect(rv, Desenho.TEXTO_SUAVE)
	var forma := PackedVector2Array()
	for k in FORMA_ROCHA.size():
		var a := TAU * k / FORMA_ROCHA.size()
		forma.append(_p(ROCHA_POS + Vector2(cos(a), sin(a)) * ROCHA_RAIO * FORMA_ROCHA[k]))
	draw_colored_polygon(forma, Desenho.BORDA)
	forma.append(forma[0])
	_linhas(forma, Desenho.TEXTO_SUAVE)


func _desenhar_moxie() -> void:
	var cx := MOXIE_POS.x
	var cy := MOXIE_POS.y
	var caixa := _rc(cx - MOXIE_TAM.x / 2.0, cy - MOXIE_TAM.y / 2.0, cx + MOXIE_TAM.x / 2.0, cy + MOXIE_TAM.y / 2.0)
	draw_rect(caixa, Desenho.CELULA_VAZIA)
	draw_rect(caixa, Desenho.TEXTO_SUAVE, false, 1.0)
	# Dois tanques cilíndricos a leste (retângulos arredondados).
	var x0 := cx + MOXIE_TAM.x / 2.0 + 0.2
	draw_style_box(_caixa_tanque, _rc(x0, cy + 0.1, x0 + 1.0, cy + 0.9))
	draw_style_box(_caixa_tanque, _rc(x0, cy - 0.9, x0 + 1.0, cy - 0.1))


## A cunha do campo de visão de `cam`: da posição rumo ao alvo, com o comprimento da distância até ele
## (no mínimo 4 m). Recortada pelo mapa. A da câmera atual é preenchida e leva contorno claro.
func _desenhar_cunha(cam: String) -> void:
	var d: Vector2 = ALVO_NO_MUNDO[cam] - POSICAO[cam]
	var comprimento := maxf(d.length(), 4.0) * _escala
	var rumo := atan2(-d.y, d.x)  # y da tela cresce para baixo
	var meio := deg_to_rad(CAMPO_DE_VISAO[cam]) / 2.0
	var origem := _p(POSICAO[cam]) + Vector2(0.5, 0.5)
	var cunha := PackedVector2Array([origem])
	var n := 16
	for i in n + 1:
		cunha.append((origem + Vector2.from_angle(rumo - meio + 2.0 * meio * i / n) * comprimento).round())
	var janela := _mapa.grow(-1.0)
	var moldura := PackedVector2Array([janela.position, Vector2(janela.end.x, janela.position.y),
		janela.end, Vector2(janela.position.x, janela.end.y)])
	var atual := cam == _atual
	if atual:
		for poli in Geometry2D.intersect_polygons(cunha, moldura):
			if poli.size() >= 3:
				draw_colored_polygon(poli, Color(Desenho.TEXTO, 0.18))
	var contorno := cunha.duplicate()
	contorno.append(cunha[0])
	var cor := Desenho.TEXTO if atual else Color(Desenho.TEXTO_SUAVE, 0.4)
	for linha in Geometry2D.intersect_polyline_with_polygon(contorno, moldura):
		draw_polyline(linha, cor, 1.0)


## Seta do norte (com a palavra, se houver tradução) e barra de escala de 10 m, no canto inferior direito.
func _desenhar_bussola_e_escala() -> void:
	var cor := Desenho.TEXTO_SUAVE
	var dir := _mapa.end.x - 8.0
	var fundo := _mapa.end.y - 6.0
	# Barra de 10 m, com "10 m" por cima.
	var comp := roundf(10.0 * _escala)
	draw_rect(Rect2(dir - comp, fundo - 1.0, comp, 2.0), cor)
	draw_rect(Rect2(dir - comp, fundo - 5.0, 1.0, 5.0), cor)
	draw_rect(Rect2(dir - 1.0, fundo - 5.0, 1.0, 5.0), cor)
	var rot := "10 m"
	var lt := Desenho.largura_texto(rot, 10, true)
	Desenho.texto(self, rot, Vector2(roundf(dir - comp / 2.0 - lt / 2.0), fundo - 17.0), 10, cor, -1.0,
		HORIZONTAL_ALIGNMENT_LEFT, true)
	# Seta do norte, acima do texto.
	var topo := fundo - 41.0
	var ax := dir - 4.0
	draw_rect(Rect2(ax, topo + 5.0, 1.0, 11.0), cor)
	draw_colored_polygon(PackedVector2Array([
		Vector2(ax + 0.5, topo), Vector2(ax - 3.5, topo + 6.0), Vector2(ax + 4.5, topo + 6.0)]), cor)
	var norte := palavra("MAPA_NORTE")
	if norte != "":
		var ln := Desenho.largura_texto(norte, 10, true)
		Desenho.texto(self, norte, Vector2(roundf(ax - 7.0 - ln), topo + 3.0), 10, cor, -1.0,
			HORIZONTAL_ALIGNMENT_LEFT, true)


## O botão da câmera, no estilo de _pintar_botao do terminal: borda VERDE_ESCURO de 2 px, fundo VERDE,
## VERDE_CLARO com o ponteiro em cima; o da câmera atual fica apertado (fundo VERDE_ESCURO, borda VERDE).
func _desenhar_botao(cam: String) -> void:
	var r: Rect2 = _alvos[cam]
	var apertado := cam == _atual
	var fundo := Desenho.VERDE_CLARO if _alvo_em(_mouse) == cam else Desenho.VERDE
	var borda := Desenho.VERDE_ESCURO
	var cor := Desenho.TEXTO_ESCURO
	if apertado:
		fundo = Desenho.VERDE_ESCURO
		borda = Desenho.VERDE
		cor = Desenho.TEXTO
	draw_rect(r, borda)
	draw_rect(r.grow(-2.0), fundo)
	_icone_camera(cam, Rect2(r.position + Vector2(5, 5), Vector2(18, 18)), cor, fundo)


## Pendência: chevron para baixo logo acima do botão (balança ±2 px a 1 Hz, sem piscar) e anel quadrado
## tracejado 3 px fora. Forma e posição, sem cor de alerta.
func _desenhar_pendencia(cam: String) -> void:
	var r: Rect2 = _alvos[cam]
	var anel := r.grow(3.0)
	var traco := 4.0
	var vao := 3.0
	var x := anel.position.x
	while x < anel.end.x:
		var l := minf(traco, anel.end.x - x)
		draw_rect(Rect2(x, anel.position.y - 1.0, l, 2.0), Desenho.TEXTO)
		draw_rect(Rect2(x, anel.end.y - 1.0, l, 2.0), Desenho.TEXTO)
		x += traco + vao
	var y := anel.position.y
	while y < anel.end.y:
		var l := minf(traco, anel.end.y - y)
		draw_rect(Rect2(anel.position.x - 1.0, y, 2.0, l), Desenho.TEXTO)
		draw_rect(Rect2(anel.end.x - 1.0, y, 2.0, l), Desenho.TEXTO)
		y += traco + vao
	var balanco := roundf(sin(Time.get_ticks_msec() / 1000.0 * TAU) * 2.0)
	var cx := roundf(r.get_center().x)
	var ponta := anel.position.y - 5.0 + balanco
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx, ponta + 2.0), Vector2(cx - 8.0, ponta - 8.0), Vector2(cx + 8.0, ponta - 8.0)]), Desenho.NOITE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx, ponta), Vector2(cx - 6.0, ponta - 6.0), Vector2(cx + 6.0, ponta - 6.0)]), Desenho.TEXTO)


# --- desenho: vista --------------------------------------------------------------

func _textura(cam: String) -> Texture2D:
	var caminho := "res://assets/exterior/%s_%s.png" % [cam, "poeira" if _poeira else "normal"]
	if not _texturas.has(caminho):
		_texturas[caminho] = load(caminho) if ResourceLoader.exists(caminho) else null
	return _texturas[caminho]


func _desenhar_vista() -> void:
	var v := _vista
	# Moldura: 2 px BORDA por fora e um aro de 1 px MOLDURA fora dela.
	draw_rect(v.grow(3.0), Desenho.MOLDURA)
	draw_rect(v.grow(2.0), Desenho.BORDA)
	var tex := _textura(_atual)
	if tex != null:
		draw_texture_rect(tex, v, false)
	else:
		draw_rect(v, Desenho.FUNDO_TERMINAL)
	if _peca_visivel():
		return  # a peça cobre a vista
	_desenhar_mira(v)
	# Chip da câmera, no canto superior esquerdo de dentro da vista.
	var txt := palavra(CHAVE_CAMERA[_atual])
	var larg := 5.0 + 16.0 + 5.0
	if txt != "":
		larg += 4.0 + Desenho.largura_texto(txt, 12, true)
	var rc := Rect2(v.position + Vector2(10, 10), Vector2(ceilf(larg), 22.0))
	_chip(rc)
	_icone_camera(_atual, Rect2(rc.position + Vector2(5, 3), Vector2(16, 16)), Desenho.TEXTO, Desenho.NOITE)
	if txt != "":
		Desenho.texto(self, txt, Vector2(rc.position.x + 25.0, rc.position.y + 11.0 - Desenho.fonte().get_height(12) / 2.0),
			12, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)


## Sobreposição de alvo, como as vistas da estação robótica da ISS: cantoneiras, retícula e régua de
## tiques nas bordas de cima e da esquerda. Sem número nenhum: telemetria inventada é proibida.
func _desenhar_mira(v: Rect2) -> void:
	var sombra := Vector2(1, 1)
	var cor := Desenho.TEXTO
	var noite := Desenho.NOITE
	# Régua: a cada 16 px um tique de 3 px; a cada 4º, de 6 px.
	var k := 0
	while k * 16 < v.size.x:
		var h := 6.0 if k % 4 == 0 else 3.0
		draw_rect(Rect2(v.position.x + k * 16 + 1, v.position.y + 1, 1, h), noite)
		draw_rect(Rect2(v.position.x + k * 16, v.position.y, 1, h), cor)
		k += 1
	k = 0
	while k * 16 < v.size.y:
		var h := 6.0 if k % 4 == 0 else 3.0
		draw_rect(Rect2(v.position.x + 1, v.position.y + k * 16 + 1, h, 1), noite)
		draw_rect(Rect2(v.position.x, v.position.y + k * 16, h, 1), cor)
		k += 1
	# Cantoneiras: pernas de 12 px com 2 px, e a sombra deslocada 1 px.
	var perna := 12.0
	var e := 2.0
	var a := v.position + Vector2(4, 4)
	var b := v.end - Vector2(4, 4)
	for passo in 2:
		var d := sombra if passo == 0 else Vector2.ZERO
		var c := noite if passo == 0 else cor
		draw_rect(Rect2(a + d, Vector2(perna, e)), c)
		draw_rect(Rect2(a + d, Vector2(e, perna)), c)
		draw_rect(Rect2(Vector2(b.x - perna, a.y) + d, Vector2(perna, e)), c)
		draw_rect(Rect2(Vector2(b.x - e, a.y) + d, Vector2(e, perna)), c)
		draw_rect(Rect2(Vector2(a.x, b.y - e) + d, Vector2(perna, e)), c)
		draw_rect(Rect2(Vector2(a.x, b.y - perna) + d, Vector2(e, perna)), c)
		draw_rect(Rect2(Vector2(b.x - perna, b.y - e) + d, Vector2(perna, e)), c)
		draw_rect(Rect2(Vector2(b.x - e, b.y - perna) + d, Vector2(e, perna)), c)
	# Retícula no centro: quatro traços de 10 px com 6 px de vão e um ponto de 2 px.
	var m := (v.position + v.size / 2.0).round()
	for passo in 2:
		var d := sombra if passo == 0 else Vector2.ZERO
		var c := noite if passo == 0 else cor
		draw_rect(Rect2(m + Vector2(-13, 0) + d, Vector2(10, 1)), c)
		draw_rect(Rect2(m + Vector2(3, 0) + d, Vector2(10, 1)), c)
		draw_rect(Rect2(m + Vector2(0, -13) + d, Vector2(1, 10)), c)
		draw_rect(Rect2(m + Vector2(0, 3) + d, Vector2(1, 10)), c)
		draw_rect(Rect2(m + Vector2(-1, -1) + d, Vector2(2, 2)), c)


# --- desenho: telemetria ---------------------------------------------------------

## Os chips da telemetria: [ícone, texto]. Só o que o visor sabe; nada inventado. O nome da câmera não entra:
## já está no rótulo do canto da vista (dono, 15/11).
func _itens_telemetria(com_palavras: bool) -> Array:
	var itens := []
	if _tem_sol:
		itens.append(["sol", "%d/%d" % [_sol_n, _sol_total]])
	if _poeira:
		itens.append(["poeira", palavra("TEL_POEIRA") if com_palavras else ""])
	else:
		itens.append(["limpo", palavra("TEL_LIMPO") if com_palavras else ""])
	itens.append(["lista", str(_contar_pendentes())])
	return itens


func _largura_chip(item: Array) -> float:
	var larg := 6.0 + 16.0 + 6.0
	if item[1] != "":
		larg += 4.0 + Desenho.largura_texto(item[1], 12, true)
	return ceilf(larg)


func _desenhar_telemetria() -> void:
	var itens := _itens_telemetria(true)
	var total := 0.0
	for it in itens:
		total += _largura_chip(it) + 4.0
	if total - 4.0 > _telem.size.x:
		itens = _itens_telemetria(false)  # não coube: tira as palavras, fica ícone e número
	var x := _telem.position.x
	var y := _telem.position.y + (_telem.size.y - ALTURA_CHIP) / 2.0
	for it in itens:
		var larg := _largura_chip(it)
		var rc := Rect2(x, y, larg, ALTURA_CHIP)
		_chip(rc)
		var ri := Rect2(x + 6.0, y + (ALTURA_CHIP - 16.0) / 2.0, 16.0, 16.0)
		var ic: String = it[0]
		if CAMERAS.has(ic):
			_icone_camera(ic, ri, Desenho.TEXTO, Desenho.NOITE)
		elif ic == "limpo":
			_icone_ceu_limpo(ri, Desenho.TEXTO)
		else:
			Desenho.icone(self, ic, ri, Desenho.TEXTO, Desenho.NOITE)
		if it[1] != "":
			Desenho.texto(self, it[1], Vector2(x + 26.0, y + ALTURA_CHIP / 2.0 - Desenho.fonte().get_height(12) / 2.0),
				12, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
		x += larg + 4.0
