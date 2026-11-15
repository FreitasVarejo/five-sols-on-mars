extends Control
## A abertura do jogo: oito quadros da altura do Control, empilhados numa rolagem vertical própria,
## que dizem onde a criança está, para que serve cada barra e o que vem nos 5 sóis.
## Quem hospeda liga `concluida` (emitido uma vez só, pelo botão final ou pelo "Pular") ao plano do sol 1.
##
## Rola com a roda do mouse (um quadro por passo), com o arrasto do mouse e com um dedo (o arrasto
## segue o dedo e, ao soltar, encaixa no quadro mais próximo, ou no seguinte se o gesto foi rápido).
## Toque sem arrasto não rola. Sem teclado. Todo texto vem de tr() (chaves ABERTURA_*, mais SOL_N).
##
## O tempo passa por `avancar(delta)`, que o _process chama: uma cena de captura ou um teste desliga o
## _process e conduz o relógio.

signal concluida

const Desenho := preload("res://scripts/desenho.gd")

const N_QUADROS := 8
const ULTIMO := N_QUADROS - 1

## As chaves de cada quadro, na ordem em que aparecem. O texto do quadro 8 inclui o botão.
const CHAVES_DOS_QUADROS: Array = [
	["ABERTURA_1_TITULO", "ABERTURA_1_A", "ABERTURA_1_B", "ABERTURA_ROLAR"],
	["ABERTURA_2_A", "ABERTURA_2_B", "ABERTURA_2_C"],
	["ABERTURA_O2_ROTULO", "ABERTURA_O2_A", "ABERTURA_O2_B", "ABERTURA_O2_C"],
	["ABERTURA_EN_ROTULO", "ABERTURA_EN_A", "ABERTURA_EN_B", "ABERTURA_EN_C"],
	["ABERTURA_RAD_ROTULO", "ABERTURA_RAD_A", "ABERTURA_RAD_B", "ABERTURA_RAD_C", "ABERTURA_RAD_D"],
	["ABERTURA_CI_ROTULO", "ABERTURA_CI_A", "ABERTURA_CI_B", "ABERTURA_CI_C", "ABERTURA_CI_D"],
	["ABERTURA_PR_NAVE", "ABERTURA_PR_LIVRE", "ABERTURA_PR_A", "ABERTURA_PR_B", "ABERTURA_PR_C", "ABERTURA_PR_D"],
	["ABERTURA_FIM_A", "ABERTURA_FIM_B", "ABERTURA_FIM_BOTAO"],
]
## Chaves que valem em todos os quadros (o "Pular") e a que a abertura pede além das ABERTURA_*.
const CHAVES_GERAIS: Array = ["ABERTURA_PULAR", "SOL_N"]

const VISAO_GERAL := preload("res://assets/exterior/visao_geral_normal.png")
const VISTA_JANELA := preload("res://assets/exterior/vista_janela_normal.png")
const MOXIE := preload("res://assets/exterior/moxie_normal.png")
const PAINEL := preload("res://assets/exterior/painel_normal.png")
const ROCHA := preload("res://assets/exterior/rocha_normal.png")
const COMODO_NORMAL := preload("res://assets/comodo/normal.png")
const COMODO_TEMPESTADE := preload("res://assets/comodo/tempestade.png")
## A janela do cômodo (1280x360, com a vista renderizada à parte): o jogo mostra x = 320 a 960.
const RECORTE_JANELA := Rect2(320, 0, 640, 360)

# Texto
const MARGEM_X := 24.0
const MARGEM_BAIXO := 20.0
const RESERVA_DIREITA := 44.0   # a coluna das bolinhas e a folga até o texto
const TAM_CORPO := 20
const TAM_TITULO := 30
const TAM_ROTULO := 16
const TAM_PEQUENO := 14
const SOMBRA_TEXTO := Color(0, 0, 0, 0.7)

# Degradê dos quadros de foto: transparente em DEGRADE_TOPO, 88% de MOLDURA em DEGRADE_MEIO e daí ao pé.
const DEGRADE_TOPO := 0.26
const DEGRADE_MEIO := 0.60
const DEGRADE_ALFA := 0.88

# Rolagem
const DURACAO_ENCAIXE := 0.25
const LIMIAR_ARRASTO := 8.0       # px até um toque virar arrasto
const GESTO_RAPIDO_S := 0.35
const GESTO_RAPIDO_PX := 24.0
const PAUSA_DA_RODA := 0.3        # s sem aceitar outro passo da roda: o trackpad manda dezenas de passos
const GESTO_VELHO_MS := 1500      # um gesto parado há tanto tempo perde a posse para a outra fonte

# Bolinhas e Pular
const BOLINHA_X := 11.0
const BOLINHA_PASSO := 15.0
const PULAR_MIN := Vector2(60, 28)
const BOTAO_FINAL := Vector2(200, 44)
const BOTAO_BASE := 4.0

# Quadro 7
const SOL_D := 48.0
const CAIXA_W := 78.0
const LIGACAO := 14.0

## A bolinha da seta balança com este período (s): bem acima do limite de 3 piscadas por segundo.
const PERIODO_SETA := 1.8

## Opcional: o nó Som (scripts/som.gd), injetado por quem hospeda. Só precisa de `tocar(nome)`.
var som = null

var _altura := 360.0            # a altura do Control quando a rolagem foi calculada
var _rolagem := 0.0             # px, de 0 a ULTIMO * altura de um quadro
var _indice := 0                # o quadro de repouso (o alvo do encaixe)
var _animando := false
var _de := 0.0
var _para := 0.0
var _anim_t := 0.0
var _relogio := 0.0
var _pausa_roda := 0.0
var _emitida := false
var _botao_apertado := false

# Gesto (mouse ou um dedo)
var _fonte := ""                # "" sem gesto; "mouse" ou "toque": a fonte que tem a posse do gesto
var _g_inicio := Vector2.ZERO
var _g_ultimo := Vector2.ZERO
var _g_ms := 0
var _g_ultimo_ms := 0
var _g_arrastou := false
var _g_quadro0 := 0
var _g_alvo := ""               # o que o gesto apertou: "", "pular" ou "final"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	avancar(delta)


# --- interface para quem hospeda e para o teste -------------------------------

## O quadro em que a rolagem está, de 0 a N_QUADROS - 1 (o mais próximo da posição atual).
func quadro_atual() -> int:
	_sincronizar_altura()
	return clampi(roundi(_rolagem / maxf(size.y, 1.0)), 0, ULTIMO)


## A rolagem atual em px (0 no quadro 1; (N_QUADROS - 1) * altura no último).
func rolagem() -> float:
	_sincronizar_altura()
	return _rolagem


## Põe a rolagem em `px`, sem animar e sem gesto (para a cena de captura e para o teste).
func definir_rolagem(px: float) -> void:
	_animando = false
	_rolagem = clampf(px, 0.0, ULTIMO * size.y)
	_indice = quadro_atual()
	queue_redraw()


## Rola até o quadro `q` (0 a N_QUADROS - 1) com um encaixe curto.
func ir_para(q: int) -> void:
	_indice = clampi(q, 0, ULTIMO)
	_de = _rolagem
	_para = _indice * size.y
	_anim_t = 0.0
	_animando = not is_equal_approx(_de, _para)
	if not _animando:
		_rolagem = _para
	queue_redraw()


## Passa o tempo: o encaixe, a pausa da roda e o balanço da seta.
func avancar(delta: float) -> void:
	_sincronizar_altura()
	_relogio += delta
	_pausa_roda = maxf(_pausa_roda - delta, 0.0)
	if _animando:
		_anim_t = minf(_anim_t + delta / DURACAO_ENCAIXE, 1.0)
		var e := 1.0 - pow(1.0 - _anim_t, 3.0)
		_rolagem = lerpf(_de, _para, e)
		if _anim_t >= 1.0:
			_animando = false
			_rolagem = _para
		queue_redraw()
	elif _rolagem < size.y:
		queue_redraw()  # o quadro 1 está à vista: a seta balança


## O botão "Começar a missão" em coordenadas do Control, já com a rolagem (fora da tela quando o
## último quadro não está à vista).
func rect_botao_final() -> Rect2:
	var r := _rect_botao_local()
	return Rect2(r.position + Vector2(0.0, roundf(ULTIMO * size.y - _rolagem)), r.size)


## O "Pular", em coordenadas do Control (fixo: aparece em todos os quadros).
func rect_pular() -> Rect2:
	var larg := maxf(PULAR_MIN.x, Desenho.largura_texto(tr("ABERTURA_PULAR"), TAM_PEQUENO) + 24.0)
	return Rect2(size.x - larg - 10.0, 8.0, larg, PULAR_MIN.y)


## Os centros das bolinhas, uma por quadro, na borda direita e centradas na vertical.
func centros_das_bolinhas() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var y0 := size.y / 2.0 - (N_QUADROS - 1) * BOLINHA_PASSO / 2.0
	for i in N_QUADROS:
		pts.append(Vector2(size.x - BOLINHA_X, y0 + i * BOLINHA_PASSO))
	return pts


func ja_concluiu() -> bool:
	return _emitida


## A largura que o texto pode ocupar nos quadros 1 a 6 (até a coluna das bolinhas).
func largura_util() -> float:
	return size.x - MARGEM_X - RESERVA_DIREITA


## A linha mais larga de todos os quadros, no idioma atual, na fonte e no tamanho em que é desenhada.
func maior_linha() -> float:
	var maior := 0.0
	for q in N_QUADROS:
		for l in _linhas(q):
			maior = maxf(maior, l["largura"])
	return maior


## Divide `s` em frases: um ". " seguido de maiúscula começa uma frase nova ("Aquece à noite. Sem
## energia, sem ar." vira duas). Abreviação seguida de minúscula não corta.
static func frases(s: String) -> PackedStringArray:
	var saida := PackedStringArray()
	var ini := 0
	for i in range(s.length() - 2):
		if s[i] == "." and s[i + 1] == " ":
			var c := s[i + 2]
			if c != c.to_lower() and c == c.to_upper():
				saida.append(s.substr(ini, i + 1 - ini))
				ini = i + 2
	saida.append(s.substr(ini))
	return saida


## Com outra altura (a janela mudou), o quadro de repouso é o que vale e a rolagem acompanha. Durante um
## gesto não mexe: o dedo manda.
func _sincronizar_altura() -> void:
	if is_equal_approx(_altura, size.y):
		return
	_altura = size.y
	if _fonte == "":
		_animando = false
		_rolagem = _indice * size.y
		queue_redraw()


# --- entrada ---------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN or mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			if mb.pressed:
				_passo_da_roda(1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_gesto_inicio("mouse", mb.position)
			else:
				_gesto_fim("mouse", mb.position, false)
			accept_event()
	elif event is InputEventMouseMotion:
		_gesto_move("mouse", (event as InputEventMouseMotion).position)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.index == 0:
			if st.pressed:
				_gesto_inicio("toque", st.position)
			else:
				_gesto_fim("toque", st.position, st.canceled)
			accept_event()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == 0:
			_gesto_move("toque", sd.position)


func _passo_da_roda(sentido: int) -> void:
	if _pausa_roda > 0.0:
		return
	_pausa_roda = PAUSA_DA_RODA
	ir_para(_indice + sentido)


## No Web o toque chega como ScreenTouch e também como mouse emulado: o gesto pertence à fonte que o
## abriu, e a outra, enquanto ele dura, é ignorada. Assim o mesmo arrasto não conta duas vezes.
func _gesto_inicio(fonte: String, pos: Vector2) -> void:
	if _fonte != "" and _fonte != fonte and Time.get_ticks_msec() - _g_ultimo_ms < GESTO_VELHO_MS:
		return
	_fonte = fonte
	_g_inicio = pos
	_g_ultimo = pos
	_g_ms = Time.get_ticks_msec()
	_g_ultimo_ms = _g_ms
	_g_arrastou = false
	_g_quadro0 = quadro_atual()
	_g_alvo = ""
	if rect_pular().has_point(pos):
		_g_alvo = "pular"
	elif rect_botao_final().has_point(pos):
		_g_alvo = "final"
		_botao_apertado = true
		queue_redraw()


func _gesto_move(fonte: String, pos: Vector2) -> void:
	if _fonte != fonte:
		return
	_g_ultimo_ms = Time.get_ticks_msec()
	if not _g_arrastou:
		if absf(pos.y - _g_inicio.y) < LIMIAR_ARRASTO:
			return
		_g_arrastou = true
		_animando = false  # o dedo pega a rolagem onde ela está
		_botao_apertado = false
		_g_quadro0 = quadro_atual()
		_g_ultimo = _g_inicio  # o conteúdo acompanha o dedo desde onde ele pousou
	_rolagem = clampf(_rolagem - (pos.y - _g_ultimo.y), 0.0, ULTIMO * size.y)
	_g_ultimo = pos
	queue_redraw()


func _gesto_fim(fonte: String, pos: Vector2, cancelado: bool) -> void:
	if _fonte != fonte:
		return
	_fonte = ""
	_botao_apertado = false
	var alvo := _g_alvo
	_g_alvo = ""
	if _g_arrastou:
		var dist := _g_inicio.y - pos.y   # > 0: o gesto subiu, a rolagem desce
		var dur := float(Time.get_ticks_msec() - _g_ms) / 1000.0
		var q := roundi(_rolagem / maxf(size.y, 1.0))
		if absf(dist) > GESTO_RAPIDO_PX and dur < GESTO_RAPIDO_S:
			q = _g_quadro0 + (1 if dist > 0.0 else -1)
		ir_para(q)
		return
	queue_redraw()
	if cancelado:
		return
	# Toque sem arrasto: vale só se começou e terminou no mesmo botão.
	if alvo == "pular" and rect_pular().has_point(pos):
		_concluir()
	elif alvo == "final" and rect_botao_final().has_point(pos):
		_concluir()


## Os dois botões passam por aqui: emite uma vez só, e o clique soa só quando emite.
func _concluir() -> void:
	if _emitida:
		return
	_emitida = true
	if som != null:
		som.tocar("clique_confirmar")
	concluida.emit()


# --- desenho ---------------------------------------------------------------------

func _draw() -> void:
	_sincronizar_altura()
	var h := size.y
	for i in N_QUADROS:
		var oy := roundf(i * h - _rolagem)
		if oy >= h or oy <= -h:
			continue
		draw_set_transform(Vector2(0.0, oy))
		_desenhar_quadro(i)
	draw_set_transform(Vector2.ZERO)
	_desenhar_bolinhas()
	_desenhar_pular()


func _desenhar_quadro(q: int) -> void:
	if q >= 6:
		draw_rect(Rect2(Vector2.ZERO, size), Desenho.FUNDO_TERMINAL)
		if q == 6:
			_desenhar_progressao()
		else:
			_desenhar_final()
		return
	match q:
		0:
			_cobrir(VISAO_GERAL, Rect2(Vector2.ZERO, VISAO_GERAL.get_size()))
		1:
			_cobrir(VISTA_JANELA, RECORTE_JANELA)
			_cobrir(COMODO_NORMAL, RECORTE_JANELA)
		2:
			_cobrir(MOXIE, Rect2(Vector2.ZERO, MOXIE.get_size()))
		3:
			_cobrir(PAINEL, Rect2(Vector2.ZERO, PAINEL.get_size()))
		4:
			_cobrir(VISTA_JANELA, RECORTE_JANELA)
			_cobrir(COMODO_TEMPESTADE, RECORTE_JANELA)
		5:
			_cobrir(ROCHA, Rect2(Vector2.ZERO, ROCHA.get_size()))
	_desenhar_degrade()
	_desenhar_texto_de_foto(q)
	if q == 0:
		_desenhar_dica()


## Preenche o quadro com a região `src` da textura, cortando o excesso do lado que sobra (sem esticar).
func _cobrir(tex: Texture2D, src: Rect2) -> void:
	var dst := Rect2(Vector2.ZERO, size)
	var asp := size.x / maxf(size.y, 1.0)
	var r := src
	if asp > src.size.x / src.size.y:
		r.size.y = src.size.x / asp
		r.position.y += (src.size.y - r.size.y) / 2.0
	else:
		r.size.x = src.size.y * asp
		r.position.x += (src.size.x - r.size.x) / 2.0
	draw_texture_rect_region(tex, dst, r)


func _desenhar_degrade() -> void:
	var w := size.x
	var topo := size.y * DEGRADE_TOPO
	var meio := size.y * DEGRADE_MEIO
	var c0 := Color(Desenho.MOLDURA, 0.0)
	var c1 := Color(Desenho.MOLDURA, DEGRADE_ALFA)
	draw_polygon(PackedVector2Array([Vector2(0, topo), Vector2(w, topo), Vector2(w, meio), Vector2(0, meio)]),
		PackedColorArray([c0, c0, c1, c1]))
	draw_rect(Rect2(0.0, meio, w, size.y - meio), c1)


## Texto com sombra de 1 a 2 px embaixo. Devolve a altura.
func _t(s: String, pos: Vector2, tam: int, cor: Color, largura: float = -1.0,
		alinh: int = HORIZONTAL_ALIGNMENT_LEFT, negrito: bool = false) -> float:
	var sombra := 2.0 if tam >= 18 else 1.0
	Desenho.texto(self, s, pos + Vector2(0.0, sombra), tam, SOMBRA_TEXTO, largura, alinh, negrito)
	return Desenho.texto(self, s, pos, tam, cor, largura, alinh, negrito)


## As linhas do texto dos quadros 1 a 6, de cima para baixo: {s, tam, cor, neg, largura, rotulo}.
## O rótulo (quadros 3 a 6) vem em maiúsculas e leva a cor do recurso; a largura já conta a barrinha.
func _linhas(q: int) -> Array:
	var saida: Array = []
	var chaves: Array = CHAVES_DOS_QUADROS[q]
	for k in chaves:
		var chave: String = k
		if chave == "ABERTURA_ROLAR" or q >= 6:
			continue
		var cor := Desenho.TEXTO
		var tam := TAM_CORPO
		var neg := false
		var s := tr(chave)
		var rotulo := false
		if chave.ends_with("_ROTULO"):
			rotulo = true
			s = s.to_upper()
			tam = TAM_ROTULO
			neg = true
			cor = _cor_do_rotulo(q)
		elif chave == "ABERTURA_1_TITULO":
			tam = TAM_TITULO
			neg = true
		if rotulo or tam == TAM_TITULO:
			saida.append(_linha(s, tam, cor, neg, rotulo, q))
		else:
			for f in frases(s):
				saida.append(_linha(f, tam, cor, neg, false, q))
	return saida


func _linha(s: String, tam: int, cor: Color, neg: bool, rotulo: bool, q: int) -> Dictionary:
	var larg := Desenho.largura_texto(s, tam, neg)
	if rotulo and q != 5:
		larg += 44.0 + 8.0
	return {"s": s, "tam": tam, "cor": cor, "neg": neg, "largura": larg, "rotulo": rotulo}


## Oxigênio 3 de 4, energia 2 de 4, radiação 4 de 4 (só desce); ciência sem cor própria e sem barra.
func _cor_do_rotulo(q: int) -> Color:
	match q:
		2:
			return Desenho.OXIGENIO
		3:
			return Desenho.ENERGIA
		4:
			return Desenho.RADIACAO
	return Desenho.TEXTO


func _valor_da_barra(q: int) -> int:
	match q:
		2:
			return 3
		3:
			return 2
		4:
			return 4
	return 0


## Texto embaixo, à esquerda, uma frase por linha.
func _desenhar_texto_de_foto(q: int) -> void:
	var linhas := _linhas(q)
	var total := 0.0
	for l in linhas:
		total += Desenho.fonte().get_height(l["tam"]) + _folga(l)
	var y := size.y - MARGEM_BAIXO - total + 2.0
	for l in linhas:
		var x := MARGEM_X
		var tam: int = l["tam"]
		if l["rotulo"]:
			if q != 5:
				var barra := Rect2(x, y + (Desenho.fonte().get_height(tam) - 12.0) / 2.0, 44.0, 12.0)
				Desenho.celulas(self, barra, _valor_da_barra(q), 4, l["cor"])
				x += 44.0 + 8.0
			_t(l["s"], Vector2(x, y), tam, l["cor"], -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
		else:
			_t(l["s"], Vector2(x, y), tam, l["cor"], size.x - x - RESERVA_DIREITA,
				HORIZONTAL_ALIGNMENT_LEFT, l["neg"])
		y += Desenho.fonte().get_height(tam) + _folga(l)


func _folga(l: Dictionary) -> float:
	return 6.0 if l["rotulo"] else 2.0


## A dica "role" com a seta para baixo, centralizada embaixo do quadro 1. A seta balança devagar.
func _desenhar_dica() -> void:
	var cx := size.x / 2.0
	var s := tr("ABERTURA_ROLAR")
	var h := Desenho.fonte().get_height(TAM_PEQUENO)
	var y := size.y - 46.0
	_t(s, Vector2(cx - Desenho.largura_texto(s, TAM_PEQUENO) / 2.0, y), TAM_PEQUENO, Desenho.TEXTO_SUAVE)
	var bal := roundf(sin(_relogio * TAU / PERIODO_SETA) * 3.0)
	var ys := y + h + 6.0 + bal
	var seta := PackedVector2Array([Vector2(cx - 9.0, ys), Vector2(cx, ys + 8.0), Vector2(cx + 9.0, ys)])
	draw_polyline(PackedVector2Array([seta[0] + Vector2(0, 2), seta[1] + Vector2(0, 2), seta[2] + Vector2(0, 2)]),
		SOMBRA_TEXTO, 3.0)
	draw_polyline(seta, Desenho.TEXTO_SUAVE, 3.0)


func _desenhar_bolinhas() -> void:
	var pts := centros_das_bolinhas()
	var atual := quadro_atual()
	for i in N_QUADROS:
		var raio := 4.0 if i == atual else 3.0
		draw_circle(pts[i], raio + 1.5, Color(Desenho.MOLDURA, 0.8))
		draw_circle(pts[i], raio, Desenho.TEXTO if i == atual else Desenho.BORDA)


func _desenhar_pular() -> void:
	var r := rect_pular()
	_pastilha(r, 6.0, Color(Desenho.MOLDURA, 0.6), Color(Desenho.BORDA, 0.0), 0.0)
	var s := tr("ABERTURA_PULAR")
	var ty := r.position.y + (r.size.y - Desenho.fonte().get_height(TAM_PEQUENO)) / 2.0
	Desenho.texto(self, s, Vector2(r.position.x, ty), TAM_PEQUENO, Desenho.TEXTO_SUAVE, r.size.x,
		HORIZONTAL_ALIGNMENT_CENTER)


# --- quadros 7 e 8 -----------------------------------------------------------------

func _desenhar_progressao() -> void:
	var w := size.x
	var total := 5.0 * SOL_D + 2.0 * CAIXA_W + 6.0 * LIGACAO
	var x := (w - total) / 2.0
	var cy := 92.0
	var fonte_n := TAM_CORPO + 2
	var fh := Desenho.fonte_negrito().get_height(fonte_n)
	var formato := tr("SOL_N")
	for n in range(1, 6):
		var c := Vector2(x + SOL_D / 2.0, cy)
		draw_circle(c, SOL_D / 2.0, Desenho.FUNDO_TELA)
		draw_arc(c, SOL_D / 2.0 - 1.0, 0.0, TAU, 32, Desenho.TEXTO, 2.0)
		Desenho.texto(self, str(n), Vector2(x, cy - fh / 2.0), fonte_n, Desenho.TEXTO, SOL_D,
			HORIZONTAL_ALIGNMENT_CENTER, true)
		var rotulo := (formato % n) if formato.contains("%") else "%s %d" % [formato, n]
		Desenho.texto(self, rotulo, Vector2(x - 10.0, cy + SOL_D / 2.0 + 6.0), TAM_PEQUENO, Desenho.TEXTO_SUAVE,
			SOL_D + 20.0, HORIZONTAL_ALIGNMENT_CENTER)
		x += SOL_D
		draw_line(Vector2(x + 1.0, cy), Vector2(x + LIGACAO - 1.0, cy), Desenho.BORDA, 2.0)
		x += LIGACAO
	# NAVE: a nave liga a base à Terra, então a borda é azul. LIVRE: tracejada e apagada.
	var caixa_h := SOL_D
	var nave := Rect2(x, cy - caixa_h / 2.0, CAIXA_W, caixa_h)
	_pastilha(nave, 8.0, Desenho.FUNDO_TELA, Desenho.AZUL, 2.0)
	_texto_na_caixa(tr("ABERTURA_PR_NAVE"), nave, Desenho.TEXTO)
	x += CAIXA_W
	draw_line(Vector2(x + 1.0, cy), Vector2(x + LIGACAO - 1.0, cy), Desenho.BORDA, 2.0)
	x += LIGACAO
	var livre := Rect2(x, cy - caixa_h / 2.0, CAIXA_W, caixa_h)
	_pastilha(livre, 8.0, Desenho.FUNDO_TELA, Desenho.BORDA, 2.0, true)
	_texto_na_caixa(tr("ABERTURA_PR_LIVRE"), livre, Desenho.TEXTO_SUAVE)

	# O que vem depois dos sóis, centralizado embaixo.
	var largura := w - 2.0 * (MARGEM_X + RESERVA_DIREITA)
	var y := 172.0
	for k in ["ABERTURA_PR_A", "ABERTURA_PR_B", "ABERTURA_PR_C"]:
		for f in frases(tr(k)):
			y += _t(f, Vector2(MARGEM_X + RESERVA_DIREITA, y), TAM_CORPO, Desenho.TEXTO, largura,
				HORIZONTAL_ALIGNMENT_CENTER) + 4.0
	y += 8.0
	_t(tr("ABERTURA_PR_D"), Vector2(MARGEM_X + RESERVA_DIREITA, y), TAM_PEQUENO, Desenho.TEXTO_SUAVE, largura,
		HORIZONTAL_ALIGNMENT_CENTER)


func _texto_na_caixa(s: String, r: Rect2, cor: Color) -> void:
	var tam := TAM_ROTULO
	var ty := r.position.y + (r.size.y - Desenho.fonte_negrito().get_height(tam)) / 2.0
	Desenho.texto(self, s, Vector2(r.position.x, ty), tam, cor, r.size.x, HORIZONTAL_ALIGNMENT_CENTER, true)


## O botão fica abaixo das duas frases, e o bloco todo centrado na vertical.
func _rect_botao_local() -> Rect2:
	var th := Desenho.fonte_negrito().get_height(TAM_TITULO)
	var bloco := 2.0 * th + 6.0 + 30.0 + BOTAO_FINAL.y + BOTAO_BASE
	var topo := (size.y - bloco) / 2.0
	var y := topo + 2.0 * th + 6.0 + 30.0
	return Rect2(roundf((size.x - BOTAO_FINAL.x) / 2.0), roundf(y), BOTAO_FINAL.x, BOTAO_FINAL.y)


func _desenhar_final() -> void:
	var th := Desenho.fonte_negrito().get_height(TAM_TITULO)
	var bloco := 2.0 * th + 6.0 + 30.0 + BOTAO_FINAL.y + BOTAO_BASE
	var y := (size.y - bloco) / 2.0
	for k in ["ABERTURA_FIM_A", "ABERTURA_FIM_B"]:
		y += _t(tr(k), Vector2(MARGEM_X, y), TAM_TITULO, Desenho.TEXTO, size.x - 2.0 * MARGEM_X,
			HORIZONTAL_ALIGNMENT_CENTER, true) + 3.0
	var r := _rect_botao_local()
	_pastilha(Rect2(r.position + Vector2(0.0, BOTAO_BASE), r.size), 8.0, Desenho.VERDE_ESCURO, Color.TRANSPARENT, 0.0)
	var face := Rect2(r.position + (Vector2(0.0, BOTAO_BASE - 1.0) if _botao_apertado else Vector2.ZERO), r.size)
	_pastilha(face, 8.0, Desenho.VERDE, Color.TRANSPARENT, 0.0)
	var tam := TAM_CORPO
	var ty := face.position.y + (face.size.y - Desenho.fonte_negrito().get_height(tam)) / 2.0
	Desenho.texto(self, tr("ABERTURA_FIM_BOTAO"), Vector2(face.position.x, ty), tam, Desenho.TEXTO_ESCURO,
		face.size.x, HORIZONTAL_ALIGNMENT_CENTER, true)


# --- formas ------------------------------------------------------------------------

## Retângulo de cantos arredondados: preenchido com `fundo` e, com `grossura` > 0, contornado (inteiro ou
## tracejado).
func _pastilha(r: Rect2, raio: float, fundo: Color, borda: Color, grossura: float, tracejada: bool = false) -> void:
	var caminho := _caminho_arredondado(r, raio)
	draw_colored_polygon(caminho, fundo)
	if grossura <= 0.0:
		return
	var contorno := caminho.duplicate()
	contorno.append(caminho[0])
	if tracejada:
		_tracejar(contorno, borda, grossura, 6.0, 4.0)
	else:
		draw_polyline(contorno, borda, grossura)


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


func _tracejar(pts: PackedVector2Array, cor: Color, grossura: float, traco: float, vao: float) -> void:
	var desenhando := true
	var resta := traco
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		if seg <= 0.0:
			continue
		var dir := (b - a) / seg
		var pos := 0.0
		while pos < seg:
			var passo := minf(resta, seg - pos)
			if desenhando:
				draw_line(a + dir * pos, a + dir * (pos + passo), cor, grossura)
			pos += passo
			resta -= passo
			if resta <= 0.001:
				desenhando = not desenhando
				resta = traco if desenhando else vao
