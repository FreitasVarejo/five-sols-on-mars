extends Control
## A viagem Terra -> Marte: entre o "Jogar" da tela inicial e o primeiro quadro da abertura. A Terra à
## esquerda, Marte à direita crescendo, a órbita tracejada, o foguete com chama e rastro, o registro da
## missão com 7 passos, a barra de progresso e um flash no pouso. Dura 7 s, mais 1 s de "pouso confirmado".
##
## Port da `LoadingView` da versão do primo: a
## composição, os planetas, a órbita, o foguete, o rastro, o registro, a barra e o flash são dele. O que
## mudou, e por quê: 1280x720 para 640x360 (o jogo é pixel art), texto de tr() em vez de português fixo,
## sem as dicas rotativas (texto com tempo limite), dia e idade da viagem do Curiosity (254 dias, os
## números reais) no lugar dos inventados, cores pela regra da spec (verde só no que se clica, azul só
## no que vem da Terra), nada piscando mais de 3 vezes por segundo.
##
## Quem hospeda liga `concluida` (emitido uma vez só: no fim, ou no toque e no "Pular" depois de 1,5 s)
## ao que vem depois. O tempo passa por `avancar(delta)`, que o _process chama: uma cena de captura ou um
## teste desliga o _process e conduz o relógio. Tudo é desenhado em _draw(), em coordenadas de 640x360.

signal concluida

const Desenho := preload("res://scripts/desenho.gd")

const DURACAO := 7.0          # s de viagem: o pouso é aqui
const POUSO_S := 1.0          # s de "pouso confirmado" e flash, depois do pouso, antes de emitir
const PULAR_APOS_S := 1.5     # s até o toque e o "Pular" valerem
const DIAS := 254             # a viagem do Curiosity: lançado em 26/11/2011, pousou em 06/08/2012
const FLASH_S := 0.8          # o flash do pouso: sobe em FLASH_SOBE_S e some até aqui
const FLASH_SOBE_S := 0.15
const FLASH_ALFA := 0.45

## A chama oscila com este período: 2 Hz, abaixo do limite de 3 piscadas por segundo da spec.
const CHAMA_HZ := 2.0
## O cintilar de uma estrela é |sin(w * t)|: com w <= 4 rad/s são no máximo ~1,3 piscadas por segundo.
const CINTILAR_MAX_RAD := 4.0

const N_ESTRELAS := 90
const TRILHA_PONTOS := 60
const TRILHA_PASSO := 0.005   # parâmetro da curva entre um ponto do rastro e o seguinte

# Posições (640x360)
const TERRA_C := Vector2(125, 250)
const TERRA_R := 47.5
const MARTE_C := Vector2(515, 225)
const MARTE_R := 37.5         # cresce até MARTE_R + MARTE_CRESCE
const MARTE_CRESCE := 12.5
const ORBITA_CONTROLE := Vector2(320, 60)
const REGISTRO := Rect2(15, 68, 200, 124)
const BARRA := Rect2(145, 318, 350, 12)

# Texto
const TAM_TITULO := 24
const TAM_DIA := 13
const TAM_REGISTRO_TITULO := 12
const TAM_PASSO := 11
const TAM_BARRA := 12
const TAM_PULAR := 14
const PULAR_MIN := Vector2(60, 28)
const PASSO_LINHA := 13.0
const ICONE := 10.0

## Os 7 passos do registro: [fração da viagem em que entra, chave]. Cada um ganha o visto 6% depois; no
## pouso todos o têm.
const PASSOS: Array = [
	[0.00, "VIAGEM_P1"],
	[0.10, "VIAGEM_P2"],
	[0.25, "VIAGEM_P3"],
	[0.50, "VIAGEM_P4"],
	[0.75, "VIAGEM_P5"],
	[0.88, "VIAGEM_P6"],
	[0.96, "VIAGEM_P7"],
]
const PASSO_DEMORA := 0.06

## Todas as chaves de tradução que a peça usa (o teste confere cada uma em en e pt).
const CHAVES: Array = [
	"VIAGEM_TITULO", "VIAGEM_POUSO", "VIAGEM_DIA", "VIAGEM_REGISTRO", "VIAGEM_PROGRESSO", "VIAGEM_PULAR",
	"VIAGEM_P1", "VIAGEM_P2", "VIAGEM_P3", "VIAGEM_P4", "VIAGEM_P5", "VIAGEM_P6", "VIAGEM_P7",
]

## Opcional: o nó Som (scripts/som.gd), injetado por quem hospeda. Só precisa de `tocar(nome)`.
var som = null

var _t := 0.0
var _emitida := false
## Por estrela: x, y e um número de 0 a 1 que decide o tamanho, a velocidade e o ritmo do cintilar.
var _estrelas: Array[Vector3] = []


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in N_ESTRELAS:
		_estrelas.append(Vector3(rng.randf() * 640.0, rng.randf() * 360.0, rng.randf()))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	avancar(delta)


# --- interface para quem hospeda e para o teste -------------------------------

## Passa o tempo e emite `concluida` quando o pouso e o "pouso confirmado" acabam.
func avancar(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= DURACAO + POUSO_S:
		_emitir(false)


## Segundos desde o começo.
func tempo() -> float:
	return _t


## Quanto da viagem já passou, de 0 a 1.
func progresso() -> float:
	return clampf(_t / DURACAO, 0.0, 1.0)


## O dia da viagem (0 a DIAS): a viagem do Curiosity, com a mesma suavização da nave.
func dia() -> int:
	return int(_suave(progresso()) * DIAS)


func pode_pular() -> bool:
	return _t >= PULAR_APOS_S and not _emitida


func ja_concluiu() -> bool:
	return _emitida


## O "Pular", em coordenadas do Control: no mesmo canto e com o mesmo tamanho do da abertura.
func rect_pular() -> Rect2:
	var larg := maxf(PULAR_MIN.x, Desenho.largura_texto(tr("VIAGEM_PULAR"), TAM_PULAR) + 24.0)
	return Rect2(size.x - larg - 10.0, 8.0, larg, PULAR_MIN.y)


## Pula a viagem (só vale depois de PULAR_APOS_S). Devolve se pulou.
func pular() -> bool:
	if not pode_pular():
		return false
	_emitir(true)
	return true


## Quantos passos do registro já aparecem e quantos já têm o visto, nesta fração da viagem.
func passos_visiveis(p: float) -> int:
	var n := 0
	for e in PASSOS:
		if p >= float(e[0]):
			n += 1
	return n


func passos_feitos(p: float) -> int:
	var n := 0
	for e in PASSOS:
		if p >= float(e[0]) + PASSO_DEMORA or p >= 1.0:
			n += 1
	return n


## A linha do dia, no idioma atual ("Day 152 of 254 · like Curiosity, landed in Gale").
func texto_do_dia() -> String:
	var s := tr("VIAGEM_DIA")
	return (s % dia()) if s.contains("%") else s


## Uma só emissão: o toque ou o "Pular" fazem o clique de confirmar (o do "Pular" da abertura); o fim da
## viagem, não.
func _emitir(por_toque: bool) -> void:
	if _emitida:
		return
	_emitida = true
	if por_toque and som != null:
		som.tocar("clique_confirmar")
	concluida.emit()


# --- entrada ---------------------------------------------------------------------

## Um toque ou clique em qualquer lugar pula, depois de PULAR_APOS_S (antes, só não deixa passar para o
## que está embaixo). No Web o toque chega também como mouse emulado: a guarda de emissão cobre os dois.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			pular()
		accept_event()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			pular()
		accept_event()


# --- desenho ---------------------------------------------------------------------

static func _suave(p: float) -> float:
	return p * p * (3.0 - 2.0 * p)


## A órbita: uma bezier de grau 2 da Terra a Marte.
static func orbita(p: float) -> Vector2:
	return TERRA_C.lerp(ORBITA_CONTROLE, p).lerp(ORBITA_CONTROLE.lerp(MARTE_C, p), p)


func _draw() -> void:
	var p := progresso()
	var e := _suave(p)
	_desenhar_fundo()
	_desenhar_estrelas()
	_desenhar_planeta(TERRA_C, TERRA_R, Color("2f6fc0"),
		[[0.0, -0.3, 0.35], [2.0, 0.25, 0.3], [4.0, 0.0, 0.25]], _t * 0.6, Color(0.5, 0.75, 1.0))
	var marte_r := MARTE_R + e * MARTE_CRESCE
	_desenhar_planeta(MARTE_C, marte_r, Color("c1552d"),
		[[0.5, -0.2, 0.22], [2.5, 0.3, 0.16], [4.5, 0.05, 0.2]], _t * 0.4, Color(1.0, 0.55, 0.3))
	# Uma das luas de Marte.
	var lua := MARTE_C + Vector2(cos(_t * 1.3), sin(_t * 1.3) * 0.35) * 70.0
	draw_circle(lua, 3.0, Color("9a8f86"))
	for i in 40:
		if i % 2 == 0:
			draw_line(orbita(i / 40.0), orbita((i + 1) / 40.0), Color(Desenho.TEXTO, 0.25), 1.0)
	_desenhar_foguete(e)
	_desenhar_titulo_e_dia(p)
	_desenhar_registro(p)
	_desenhar_barra(p)
	if _t >= PULAR_APOS_S:
		_desenhar_pular()
	_desenhar_flash()


func _desenhar_fundo() -> void:
	var faixas := 12
	var h := size.y / faixas
	for i in faixas:
		draw_rect(Rect2(0.0, floorf(i * h), size.x, ceilf(h) + 1.0),
			Color("04070f").lerp(Color("141f3d"), i / float(faixas - 1)))
	# Nebulosa.
	draw_circle(Vector2(320, 150), 210.0, Color(0.35, 0.2, 0.55, 0.06))
	draw_circle(Vector2(410, 110), 130.0, Color(0.2, 0.35, 0.6, 0.05))


func _desenhar_estrelas() -> void:
	for s in _estrelas:
		var a := 0.35 + 0.65 * absf(sin(_t * (1.0 + s.z * (CINTILAR_MAX_RAD - 1.0)) + s.x))
		var sx := fmod(s.x - _t * 20.0 * (0.2 + s.z), 640.0)
		if sx < 0.0:
			sx += 640.0
		var lado := 1.0 + roundf(s.z * 1.5)
		draw_rect(Rect2(floorf(sx), floorf(s.y), lado, lado), Color(1, 1, 1, a))


## Um planeta com brilho, manchas que giram e o lado da noite.
func _desenhar_planeta(c: Vector2, r: float, base: Color, manchas: Array, giro: float, brilho: Color) -> void:
	c = c.round()
	for i in 6:
		draw_circle(c, r + 4.0 + i * 3.0, Color(brilho.r, brilho.g, brilho.b, 0.06 - i * 0.008))
	draw_circle(c, r, base)
	for m in manchas:
		var ang: float = m[0] + giro
		if cos(ang) > -0.2:
			var cor := base.darkened(0.3) if base.b < 0.5 else Color("4f9a4a")
			draw_circle(c + Vector2(sin(ang) * r * 0.6, m[1] * r), m[2] * r * (0.6 + 0.4 * absf(cos(ang))), cor)
	# O lado da noite.
	for i in 10:
		draw_circle(c + Vector2(r * 0.25 + i * 0.75, 0.0), r - i * 0.6, Color(0, 0, 0.05, 0.05))
	draw_arc(c, r + 1.5, 0.0, TAU, 64, Color(brilho.r, brilho.g, brilho.b, 0.5), 2.0)


func _desenhar_foguete(e: float) -> void:
	var pos := orbita(e).round()
	# O rastro segue a curva para trás a partir do foguete: não depende de quantos quadros se desenharam.
	for i in TRILHA_PONTOS:
		var k := float(i) / TRILHA_PONTOS
		var pe := e - (TRILHA_PONTOS - i) * TRILHA_PASSO
		if pe < 0.0:
			continue
		draw_circle(orbita(pe), 1.0 + k * 2.5, Color(1.0, 0.6 + 0.3 * k, 0.2, k * 0.5))
	var dir := (orbita(minf(e + 0.01, 1.0)) - orbita(maxf(e - 0.01, 0.0))).normalized()
	var nrm := Vector2(-dir.y, dir.x)
	var chama := 11.0 + sin(_t * TAU * CHAMA_HZ) * 4.0
	draw_colored_polygon(PackedVector2Array([pos - dir * 8.0 + nrm * 4.0, pos - dir * (8.0 + chama),
		pos - dir * 8.0 - nrm * 4.0]), Color("ffb627"))
	draw_colored_polygon(PackedVector2Array([pos - dir * 8.0 + nrm * 2.0, pos - dir * (8.0 + chama * 0.6),
		pos - dir * 8.0 - nrm * 2.0]), Color("fff1c0"))
	draw_colored_polygon(PackedVector2Array([pos + dir * 15.0, pos - dir * 8.0 + nrm * 5.5,
		pos - dir * 8.0 - nrm * 5.5]), Color("f1ebdc"))
	draw_circle(pos + dir * 2.5, 2.0, Color("5ec8f0"))


func _desenhar_titulo_e_dia(p: float) -> void:
	var titulo := tr("VIAGEM_TITULO") if p < 1.0 else tr("VIAGEM_POUSO")
	Desenho.texto(self, titulo.to_upper(), Vector2(0.0, 8.0), TAM_TITULO, Desenho.TEXTO, size.x,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	Desenho.texto(self, texto_do_dia(), Vector2(0.0, 42.0), TAM_DIA, Desenho.TEXTO_SUAVE, size.x,
		HORIZONTAL_ALIGNMENT_CENTER)


## O registro da missão: o passo concluído leva o visto e texto claro; o que está em curso, um círculo
## vazio e texto suave.
func _desenhar_registro(p: float) -> void:
	draw_rect(REGISTRO, Color(0, 0, 0, 0.5))
	draw_rect(REGISTRO, Desenho.BORDA, false, 1.0)
	var x := REGISTRO.position.x + 8.0
	Desenho.texto(self, tr("VIAGEM_REGISTRO").to_upper(), Vector2(x, REGISTRO.position.y + 6.0),
		TAM_REGISTRO_TITULO, Desenho.TEXTO_SUAVE, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	var visiveis := passos_visiveis(p)
	var feitos := passos_feitos(p)
	var y := REGISTRO.position.y + 26.0
	for i in visiveis:
		var feito := i < feitos
		var cor := Desenho.TEXTO if feito else Desenho.TEXTO_SUAVE
		var altura := Desenho.fonte().get_height(TAM_PASSO)
		var ic := Rect2(x, y + (altura - ICONE) / 2.0, ICONE, ICONE)
		Desenho.icone(self, "check" if feito else "circulo", ic, cor, Color(0, 0, 0, 0.5))
		Desenho.texto(self, tr(PASSOS[i][1]), Vector2(x + ICONE + 6.0, y), TAM_PASSO, cor)
		y += PASSO_LINHA


func _desenhar_barra(p: float) -> void:
	var rotulo := "%s   %d%%" % [tr("VIAGEM_PROGRESSO").to_upper(), int(p * 100.0)]
	Desenho.texto(self, rotulo, Vector2(0.0, BARRA.position.y - 17.0), TAM_BARRA, Desenho.TEXTO, size.x,
		HORIZONTAL_ALIGNMENT_CENTER)
	draw_rect(BARRA, Color(0, 0, 0, 0.5))
	draw_rect(Rect2(BARRA.position, Vector2(roundf(BARRA.size.x * p), BARRA.size.y)), Desenho.TEXTO)
	for i in range(1, 10):
		var xx := BARRA.position.x + i * BARRA.size.x / 10.0
		draw_line(Vector2(xx, BARRA.position.y), Vector2(xx, BARRA.end.y), Color(0, 0, 0, 0.35), 1.0)
	draw_rect(BARRA, Desenho.TEXTO_SUAVE, false, 1.0)


## O mesmo botão da abertura: pastilha escura e translúcida, "Pular" em texto suave, no canto de cima à direita.
func _desenhar_pular() -> void:
	var r := rect_pular()
	var a := clampf((_t - PULAR_APOS_S) / 0.3, 0.0, 1.0)
	draw_colored_polygon(_caminho_arredondado(r, 6.0), Color(Desenho.MOLDURA, 0.6 * a))
	var ty := r.position.y + (r.size.y - Desenho.fonte().get_height(TAM_PULAR)) / 2.0
	Desenho.texto(self, tr("VIAGEM_PULAR"), Vector2(r.position.x, ty), TAM_PULAR,
		Color(Desenho.TEXTO_SUAVE, a), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


## O flash do pouso: um só, claro e neutro, que sobe depressa e some em FLASH_S.
func _desenhar_flash() -> void:
	var u := _t - DURACAO
	if u < 0.0:
		return
	var a := FLASH_ALFA * minf(u / FLASH_SOBE_S, 1.0) * clampf(1.0 - u / FLASH_S, 0.0, 1.0)
	if a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(Desenho.TEXTO, a))


static func _caminho_arredondado(r: Rect2, raio: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var centros := [
		Vector2(r.end.x - raio, r.position.y + raio),
		Vector2(r.end.x - raio, r.end.y - raio),
		Vector2(r.position.x + raio, r.end.y - raio),
		Vector2(r.position.x + raio, r.position.y + raio),
	]
	for k in 4:
		var a0 := deg_to_rad(-90.0 + 90.0 * k)
		for j in 6:
			pts.append(centros[k] + Vector2.from_angle(a0 + deg_to_rad(90.0) * j / 5.0) * raio)
	return pts
