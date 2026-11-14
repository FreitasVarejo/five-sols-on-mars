extends Control
## Terminal: o computador da base. Camada de tela por cima do panorama, depois do shader (não curva).
##
## Desenho imediato: tudo sai de _draw() a partir do estado da Missao (scripts/missao.gd), e cada
## controle que se clica é registrado em _botoes no momento em que é desenhado. Assim a lista de
## controles visíveis (ui()) e o que responde ao clique são sempre a mesma coisa.
##
## O botão único fica fixo embaixo, no centro, sempre no mesmo lugar: sobe o terminal e o mesmo
## botão o abaixa. Aberto, o terminal ocupa a tela inteira (decisão do P0) e tapa o clique da sala.
## O botão só vale no plano e no turno; nas outras fases o terminal fica aberto e o botão apagado.
##
## Conteúdo por fase: plano -> a tela do plano; turno -> a lista de tarefas; fim_do_sol -> o diário;
## seguranca -> a tela do modo de segurança; noite -> a noite; relatorio -> o relatório.
##
## Cores [R]: verde só no que se clica; vermelho e amarelo só em alerta; azul só no que vem da Terra.

const Missao := preload("res://scripts/missao.gd")
const Modelo := preload("res://scripts/modelo.gd")
const Desenho := preload("res://scripts/desenho.gd")
const DadosDonki := preload("res://scripts/dados_donki.gd")

## Avisa que acabou de desenhar (a sonda de teste lê ui() depois disso).
signal desenhou

const BOTAO := Rect2(260, 328, 120, 28)
const TELA := Rect2(0, 0, 640, 360)
const ESCURECER_S := 0.8   # fim do turno: escurece para um cinza neutro
const CLAREAR_S := 0.5

# Colunas e linhas da tela do plano.
const X_ESQ := 14.0
const X_CEN := 208.0
const X_DIR := 438.0
const L_ESQ := 188.0
const L_CEN := 224.0
const L_DIR := 188.0
const Y_CORPO := 42.0

const ROTULOS_TAREFA := {"chemcam": "TAREFA_CHEMCAM", "amostra": "TAREFA_AMOSTRA", "planta": "TAREFA_PLANTA"}

var missao: Missao
var donki := {}
var aberto := false
var fase_ui := "plano"      # a fase que a tela mostra (atrasa o fim do turno, por causa da transição)

var _fase_logica := "plano"
var _fade := 0.0
var _fade_estado := ""      # "", "escurecendo" ou "clareando"
var _botoes := {}           # nome -> Rect2, só o que se clica agora
var _mouse := Vector2(-100, -100)
var _hover := ""
var _versao_vista := -1


func iniciar(m: Missao, dado_donki: Dictionary) -> void:
	missao = m
	donki = dado_donki
	_fase_logica = m.fase
	fase_ui = m.fase
	aberto = _abre_na_fase(m.fase)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Nome -> [x, y, w, h] do que se clica agora no terminal (px da tela de 640x360).
func ui() -> Dictionary:
	var d := {}
	for nome: String in _botoes:
		var r: Rect2 = _botoes[nome]
		d[nome] = [roundi(r.position.x), roundi(r.position.y), roundi(r.size.x), roundi(r.size.y)]
	return d


## O terminal tapa a sala (pan parado, sem clique) enquanto estiver aberto ou em transição.
func tapa_a_sala() -> bool:
	return aberto or _fade_estado == "escurecendo"


static func _abre_na_fase(fase: String) -> bool:
	return fase != "turno"


func _process(delta: float) -> void:
	if missao == null:
		return
	if missao.fase != _fase_logica:
		_ao_mudar_de_fase(_fase_logica, missao.fase)
	match _fade_estado:
		"escurecendo":
			_fade = minf(1.0, _fade + delta / ESCURECER_S)
			if _fade >= 1.0:
				fase_ui = missao.fase
				aberto = _abre_na_fase(fase_ui)
				_fade_estado = "clareando"
		"clareando":
			_fade = maxf(0.0, _fade - delta / CLAREAR_S)
			if _fade <= 0.0:
				_fade_estado = ""
	var precisa := missao.fase == "turno" or _fade_estado != "" or missao.versao != _versao_vista
	if precisa:
		queue_redraw()


func _ao_mudar_de_fase(de: String, para: String) -> void:
	_fase_logica = para
	# O turno que acaba pelo relógio escurece para um cinza neutro antes do terminal subir.
	# O modo de segurança no meio do turno entra direto.
	if de == "turno" and (para == "fim_do_sol" or para == "seguranca") and missao.t >= missao.turno_s - 1e-6:
		_fade_estado = "escurecendo"
		_fade = 0.0
		return
	fase_ui = para
	aberto = _abre_na_fase(para)
	_fade_estado = ""
	_fade = 0.0
	queue_redraw()


# --- entrada -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if missao == null:
		return
	if event is InputEventMouse:
		_mouse = event.position
		var h := _botao_em(_mouse)
		if h != _hover:
			_hover = h
			queue_redraw()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var nome := _botao_em(event.position)
		if nome != "":
			_acionar(nome)
			get_viewport().set_input_as_handled()
		elif tapa_a_sala():
			get_viewport().set_input_as_handled()


func _botao_em(p: Vector2) -> String:
	for nome: String in _botoes:
		if _botoes[nome].has_point(p):
			return nome
	return ""


func _acionar(nome: String) -> void:
	match nome:
		"terminal":
			aberto = not aberto
		"o2_menos":
			missao.mudar_q(-1)
		"o2_mais":
			missao.mudar_q(1)
		"tarefa_chemcam", "tarefa_amostra", "tarefa_planta":
			missao.alternar_tarefa(nome.trim_prefix("tarefa_"))
		"confirmar":
			missao.confirmar_plano()
		"iniciar_chemcam":
			missao.iniciar_tarefa("chemcam")
		"enviar":
			missao.enviar_a_terra()
		"reiniciar":
			missao.reiniciar_sol()
		"seguir":
			missao.seguir_em_seguranca()
		"jogar_de_novo":
			missao.jogar_de_novo()
	queue_redraw()


# --- desenho: peças ------------------------------------------------------------

func _t(s: String, x: float, y: float, tam: int = 11, cor: Color = Desenho.TEXTO, largura: float = -1.0,
		alinh: int = HORIZONTAL_ALIGNMENT_LEFT, negrito: bool = false) -> float:
	return Desenho.texto(self, s, Vector2(x, y), tam, cor, largura, alinh, negrito)


func _caixa(r: Rect2, fundo: Color = Desenho.FUNDO_TELA, borda: Color = Desenho.BORDA) -> void:
	draw_rect(r, fundo)
	draw_rect(r, borda, false, 1.0)


## Botão verde (todo botão é verde). Desabilitado fica apagado e não entra em ui().
func _botao(nome: String, r: Rect2, rotulo: String, icone: String = "", habilitado: bool = true,
		tam: int = 12, apertado: bool = false) -> void:
	var fundo: Color
	var borda: Color
	var cor_texto: Color
	if habilitado:
		_botoes[nome] = r
		var hover := r.has_point(_mouse)
		fundo = Desenho.VERDE_CLARO if hover else Desenho.VERDE
		borda = Desenho.VERDE_ESCURO
		cor_texto = Desenho.TEXTO_ESCURO
		if apertado:
			fundo = Desenho.VERDE_ESCURO
			borda = Desenho.VERDE
			cor_texto = Desenho.TEXTO
	else:
		fundo = Color("#27343d")
		borda = Color("#1c262d")
		cor_texto = Color("#6f8089")
	draw_rect(r, borda)
	draw_rect(r.grow(-2.0), fundo)
	var lado := float(tam + 2)
	var larg_texto := Desenho.largura_texto(rotulo, tam, true)
	var total := larg_texto + (lado + 5.0 if icone != "" else 0.0)
	var x := r.position.x + (r.size.x - total) / 2.0
	var y_meio := r.position.y + r.size.y / 2.0
	if icone != "":
		Desenho.icone(self, icone, Rect2(x, y_meio - lado / 2.0, lado, lado), cor_texto, fundo)
		x += lado + 5.0
	_t(rotulo, x, y_meio - Desenho.fonte().get_height(tam) / 2.0, tam, cor_texto, -1.0,
		HORIZONTAL_ALIGNMENT_LEFT, true)


## Uma barra do cabeçalho: ícone, nome, número e células. Com `falha`, leva moldura vermelha e o ícone de alerta.
func _barra(x: float, y: float, w: float, icone: String, nome: String, valor: float, maximo: int,
		falha: bool = false, fundo: Color = Desenho.FUNDO_TERMINAL) -> void:
	if falha:
		draw_rect(Rect2(x - 4, y - 4, w + 8, 33), Desenho.VERMELHO, false, 2.0)
	Desenho.icone(self, icone, Rect2(x, y + 1, 12, 12), Desenho.TEXTO, fundo)
	_t(nome, x + 16, y, 11, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	var rot := "%d/%d" % [roundi(valor), maximo]
	_t(rot, x, y - 1, 12, Desenho.TEXTO, w - (16.0 if falha else 0.0), HORIZONTAL_ALIGNMENT_RIGHT, true)
	if falha:
		Desenho.icone(self, "alerta", Rect2(x + w - 13, y, 13, 13), Desenho.VERMELHO, fundo)
	Desenho.celulas(self, Rect2(x, y + 17, w, 7), valor, maximo)


## "a → b" alinhado à direita em [x, x+w], com a seta desenhada (a fonte padrão não tem "→").
func _de_para(x: float, y: float, w: float, a: String, b: String, cor: Color, tam: int = 12) -> void:
	var lb := Desenho.largura_texto(b, tam, true)
	var la := Desenho.largura_texto(a, tam, true)
	var xr := x + w
	_t(b, xr - lb, y, tam, cor, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	var xs := xr - lb - 17.0
	var ys := y + Desenho.fonte().get_height(tam) * 0.55
	draw_line(Vector2(xs, ys), Vector2(xs + 11, ys), cor, 1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(xs + 13, ys), Vector2(xs + 8, ys - 3), Vector2(xs + 8, ys + 3)]), cor)
	_t(a, xs - 4.0 - la, y, tam, cor, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)


func _numero(x: float) -> String:
	var n := roundi(x)
	return ("−%d" % -n) if n < 0 else str(n)


func _nome_tarefa(nome: String) -> String:
	return tr(ROTULOS_TAREFA[nome])


# --- desenho: o quadro -----------------------------------------------------------

func _draw() -> void:
	_botoes.clear()
	if missao == null:
		return
	_versao_vista = missao.versao
	if aberto:
		_desenhar_terminal()
	var no_jogo := fase_ui == "plano" or fase_ui == "turno"
	var livre := _fade_estado != "escurecendo"
	_botao("terminal", BOTAO, tr("TERMINAL"), "terminal", no_jogo and livre, 12, aberto)
	if _fade > 0.0:
		draw_rect(TELA, Color(Desenho.NOITE, _fade))
	desenhou.emit()


func _desenhar_terminal() -> void:
	if fase_ui == "seguranca":
		# O modo de segurança é um painel central sobre a sala (no estado modo_seguranca).
		draw_rect(TELA, Color(Desenho.NOITE, 0.62))
		draw_rect(Rect2(0, 326, 640, 34), Desenho.MOLDURA)
		_desenhar_seguranca()
		return
	draw_rect(TELA, Desenho.MOLDURA)
	draw_rect(Rect2(6, 6, 628, 316), Desenho.FUNDO_TERMINAL)
	draw_rect(Rect2(6, 6, 628, 316), Desenho.BORDA, false, 2.0)
	match fase_ui:
		"plano":
			_desenhar_plano()
		"turno":
			_desenhar_turno()
		"fim_do_sol":
			_desenhar_diario()
		"noite":
			_desenhar_noite()
		"relatorio":
			_desenhar_relatorio()


# --- plano -----------------------------------------------------------------------

func _cabecalho(titulo: String, sub: String, barras: Dictionary, falha: String = "") -> void:
	Desenho.icone(self, "sol", Rect2(X_ESQ, 14, 14, 14), Desenho.TEXTO, Desenho.FUNDO_TERMINAL)
	var larg := _t(titulo, X_ESQ + 20, 12, 14, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	var x_sub := X_ESQ + 20 + Desenho.largura_texto(titulo, 14, true) + 6
	_t(sub, x_sub, 14, 12, Desenho.TEXTO_SUAVE)
	var x := 270.0
	_barra(x, 12, 116, "energia", tr("ENERGIA"), barras["E"], 12, falha == "energia")
	_barra(x + 120, 12, 116, "oxigenio", tr("OXIGENIO"), barras["O"], 12, falha == "oxigenio")
	_barra(x + 240, 12, 116, "radiacao", tr("MARGEM"), barras["M"], 12, falha == "radiacao")


func _desenhar_plano() -> void:
	var st := missao.st
	var m := Modelo.manha(st, false)
	var p := missao.previsao()
	_cabecalho(tr("CAB_SOL") % [missao.sol, Modelo.N.SOLS], tr("CAB_PLANO"),
		{"E": st["E"], "O": st["O"], "M": st["M"]})

	# Esquerda: o card da Terra (só com aviso) e o tanque de O2.
	var y := Y_CORPO
	if missao.aviso_ativo():
		_card_da_terra(Rect2(X_ESQ, y, L_ESQ, 140))
		y += 146
	_tanque(Rect2(X_ESQ, y, L_ESQ, 134), p)

	# Centro: a energia do sol.
	_centro_plano(Rect2(X_CEN, Y_CORPO, L_CEN, 280), m, p)

	# Direita: o que acontece se confirmar.
	_previsao(Rect2(X_DIR, Y_CORPO, L_DIR, 280), p)


## O aviso da Terra: retângulo azul simples, sem destaque, seta nem animação.
func _card_da_terra(r: Rect2) -> void:
	draw_rect(r, Desenho.AZUL)
	var x := r.position.x + 8
	var larg := r.size.x - 16
	var y := r.position.y + 6
	y += _t(tr("AVISO_TEMPESTADE"), x, y, 12, Desenho.TEXTO_ESCURO, larg, HORIZONTAL_ALIGNMENT_LEFT, true) + 3
	if donki.get("historico", true):
		y += _t(tr("DONKI_FRASE_HISTORICO"), x, y, 10, Desenho.TEXTO_ESCURO, larg) + 3
	else:
		var chegada := _chegada_mais_recente()
		y += _t(tr("DONKI_FRASE_ATUAL") % DadosDonki.data_br(chegada), x, y, 10, Desenho.TEXTO_ESCURO, larg) + 3
	var rodape := r.end.y - 6 - 12 * 2
	Desenho.icone(self, "terra", Rect2(x, rodape + 1, 11, 11), Desenho.TEXTO_ESCURO, Desenho.AZUL)
	_t(tr("ENVIADO_DA_TERRA") % missao.atraso_min, x + 15, rodape, 10, Desenho.TEXTO_ESCURO, larg - 15)
	if donki.get("historico", true):
		_t(tr("DONKI_DADO_HISTORICO"), x, rodape + 12, 10, Desenho.TEXTO_ESCURO, larg)
	else:
		_t(tr("DONKI_DADO_DE") % DadosDonki.data_br(str(donki.get("coletado_em", ""))), x, rodape + 12, 10,
			Desenho.TEXTO_ESCURO, larg)


## A chegada a Marte com `chegada_prevista` mais recente (dado atual do DONKI).
func _chegada_mais_recente() -> String:
	var melhor := ""
	for c in donki.get("chegadas_marte", []):
		var quando = c.get("chegada_prevista")
		if quando is String and quando > melhor:
			melhor = quando
	return melhor


func _tanque(r: Rect2, p: Dictionary) -> void:
	_caixa(r)
	var depois: float = p["st"]["O"]
	var agora: float = missao.st["O"]
	# O tanque na vertical: 12 faixas, cheio é bom; a linha tracejada é o que fica depois do plano.
	var g := Rect2(r.position.x + 10, r.position.y + 10, 28, r.size.y - 20)
	draw_rect(g, Desenho.FUNDO_TERMINAL)
	var faixa := g.size.y / 12.0
	var cheias := clampi(roundi(agora), 0, 12)
	for i in 12:
		var rf := Rect2(g.position.x + 2, g.end.y - (i + 1) * faixa + 1, g.size.x - 4, faixa - 1)
		draw_rect(rf, Desenho.TEXTO if i < cheias else Desenho.CELULA_VAZIA)
	draw_rect(g, Desenho.TEXTO_SUAVE, false, 1.0)
	var y_depois := g.end.y - clampf(depois, 0.0, 12.0) * faixa
	var x := g.position.x - 3
	while x < g.end.x + 3:
		draw_line(Vector2(x, y_depois), Vector2(minf(x + 3, g.end.x + 3), y_depois), Desenho.FUNDO_TERMINAL, 2.0)
		draw_line(Vector2(x, y_depois), Vector2(minf(x + 3, g.end.x + 3), y_depois), Desenho.TEXTO_SUAVE, 1.0)
		x += 6
	# Chave de "1 sol de ar" (o que a tripulação respira num sol).
	var h_sol := Modelo.N.CREW_O2 * faixa
	var xc := g.end.x + 3
	draw_line(Vector2(xc, g.end.y), Vector2(xc, g.end.y - h_sol), Desenho.TEXTO_SUAVE, 1.0)
	_t(tr("UM_SOL"), xc + 4, g.end.y - 12, 10, Desenho.TEXTO_SUAVE)

	var tx := r.position.x + 78
	var lw := r.size.x - 84
	var y := r.position.y + 8
	Desenho.icone(self, "oxigenio", Rect2(tx, y + 1, 12, 12), Desenho.TEXTO, Desenho.FUNDO_TELA)
	_t(tr("TANQUE_O2"), tx + 16, y, 11, Desenho.TEXTO, lw - 16, HORIZONTAL_ALIGNMENT_LEFT, true)
	y += 20
	y += _t(tr("TANQUE_AGORA") % [roundi(agora), 12], tx, y, 11, Desenho.TEXTO, lw) + 2
	y += _t(tr("TANQUE_DEPOIS") % _numero(depois), tx, y, 11, Desenho.TEXTO, lw) + 6
	var sois := maxi(0, floori(maxf(0.0, depois) / Modelo.N.CREW_O2 + 1e-9))
	var ar := tr("AR_PARA_1") if sois == 1 else (tr("AR_PARA_N") % sois)
	y += _t(ar, tx, y, 12, Desenho.TEXTO, lw, HORIZONTAL_ALIGNMENT_LEFT, true) + 4
	_t(tr("TRIPULACAO_RESPIRA") % roundi(Modelo.N.CREW_O2), tx, y, 10, Desenho.TEXTO_SUAVE, lw)


func _centro_plano(r: Rect2, m: Dictionary, p: Dictionary) -> void:
	_caixa(r)
	var x := r.position.x + 8
	var w := r.size.x - 16
	var y := r.position.y + 7
	Desenho.icone(self, "energia", Rect2(x, y + 1, 12, 12), Desenho.TEXTO, Desenho.FUNDO_TELA)
	_t(tr("ENERGIA_DO_SOL") % missao.sol, x + 16, y, 12, Desenho.TEXTO, w - 16, HORIZONTAL_ALIGNMENT_LEFT, true)
	y += 22
	var linhas := [
		[tr("LINHA_BATERIA"), roundi(missao.st["E"]), false],
		[tr("LINHA_PAINEL"), roundi(m["renda"]), false],
		[tr("LINHA_AQUECIMENTO"), roundi(Modelo.N.AQUEC), false],
	]
	for l in linhas:
		_t(l[0], x, y, 11, Desenho.TEXTO, w - 24)
		_t(str(l[1]), x, y, 11, Desenho.TEXTO, w, HORIZONTAL_ALIGNMENT_RIGHT, true)
		y += 14
	draw_line(Vector2(x, y + 1), Vector2(x + w, y + 1), Desenho.BORDA, 1.0)
	y += 4
	_t(tr("LINHA_PARA_DIVIDIR"), x, y, 12, Desenho.TEXTO, w - 24, HORIZONTAL_ALIGNMENT_LEFT, true)
	_t(str(roundi(m["para_dividir"])), x, y, 12, Desenho.TEXTO, w, HORIZONTAL_ALIGNMENT_RIGHT, true)
	y += 22

	# Oxigênio: − q +.
	Desenho.icone(self, "oxigenio", Rect2(x, y + 10, 12, 12), Desenho.TEXTO, Desenho.FUNDO_TELA)
	_t("O2", x + 15, y + 9, 11, Desenho.TEXTO, 24, HORIZONTAL_ALIGNMENT_LEFT, true)
	var q := missao.plano_q
	var n := missao.plano_tarefas.size()
	_botao("o2_menos", Rect2(x + 42, y, 32, 32), "−", "", q > 0, 16)
	_t(str(q), x + 74, y + 5, 20, Desenho.TEXTO, 28, HORIZONTAL_ALIGNMENT_CENTER, true)
	_botao("o2_mais", Rect2(x + 102, y, 32, 32), "+", "", missao.plano_cabe(q + 1, n), 16)
	_t(tr("O2_CUSTO") % roundi(Modelo.N.GEN_CUSTO), x + 142, y + 3, 10, Desenho.TEXTO_SUAVE, w - 142)
	y += 36
	if missao.st["gerador_quebrado"]:
		Desenho.icone(self, "alerta", Rect2(x, y + 1, 12, 12), Desenho.AMARELO, Desenho.FUNDO_TELA)
		y += _t(tr("GERADOR_QUEBRADO"), x + 16, y, 10, Desenho.AMARELO, w - 16) + 4
	else:
		y += 2

	# Ciência: três cartões liga/desliga.
	Desenho.icone(self, "ciencia", Rect2(x, y + 1, 12, 12), Desenho.TEXTO, Desenho.FUNDO_TELA)
	_t(tr("CIENCIA"), x + 16, y, 11, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	y += 17
	var cx := x
	for nome in Missao.TAREFAS:
		_cartao_tarefa(nome, Rect2(cx, y, 68, 48))
		cx += 72
	y += 52
	_t(tr("TAREFAS_RESUMO") % [n, Missao.TAREFAS.size(), n], x, y, 10, Desenho.TEXTO_SUAVE, w)
	y += 16

	# O que sobra vai sozinho para a bateria.
	draw_line(Vector2(x, y), Vector2(x + w, y), Desenho.BORDA, 1.0)
	y += 5
	_t(tr("VAI_PARA_BATERIA"), x, y, 11, Desenho.TEXTO, w, HORIZONTAL_ALIGNMENT_LEFT, true)
	y += 15
	var sobra: float = p["bateria_apos_plano"]
	_t(tr("SOBRA_BATERIA") % [roundi(sobra + p["perdida_no_teto"]), roundi(sobra), roundi(Modelo.N.TETO)], x, y, 11,
		Desenho.TEXTO, w)
	y += 14
	if p["perdida_no_teto"] > 0.0:
		_t(tr("SE_PERDE") % roundi(p["perdida_no_teto"]), x, y, 11, Desenho.TEXTO, w, HORIZONTAL_ALIGNMENT_LEFT, true)
	y += 17
	Desenho.celulas(self, Rect2(x, y, w, 6), sobra, 12)


func _cartao_tarefa(nome: String, r: Rect2) -> void:
	var ligada: bool = nome in missao.plano_tarefas
	var habilitado := ligada or missao.plano_cabe(missao.plano_q, missao.plano_tarefas.size() + 1)
	var fundo: Color
	var cor: Color
	var borda: Color
	if habilitado:
		_botoes["tarefa_" + nome] = r
		var hover := r.has_point(_mouse)
		borda = Desenho.VERDE_ESCURO
		if ligada:
			fundo = Desenho.VERDE_CLARO if hover else Desenho.VERDE
			cor = Desenho.TEXTO_ESCURO
		else:
			fundo = Color("#2a3b2a") if not hover else Color("#35503a")
			cor = Desenho.VERDE
			borda = Desenho.VERDE
	else:
		fundo = Color("#27343d")
		cor = Color("#6f8089")
		borda = Color("#1c262d")
	draw_rect(r, borda)
	draw_rect(r.grow(-2), fundo)
	Desenho.icone(self, nome, Rect2(r.position.x + 6, r.position.y + 5, 14, 14), cor, fundo)
	if ligada:
		Desenho.icone(self, "check", Rect2(r.end.x - 20, r.position.y + 5, 13, 13), cor, fundo)
	_t(_nome_tarefa(nome), r.position.x + 6, r.position.y + 19, 10, cor, r.size.x - 8, HORIZONTAL_ALIGNMENT_LEFT, true)
	var custo := "−%d" % roundi(Modelo.N.CIENCIA_CUSTO)
	_t(custo, r.position.x + 6, r.position.y + 31, 10, cor, r.size.x - 22, HORIZONTAL_ALIGNMENT_LEFT, true)
	Desenho.icone(self, "energia", Rect2(r.position.x + 24, r.position.y + 32, 9, 9), cor, fundo)


func _previsao(r: Rect2, p: Dictionary) -> void:
	_caixa(r)
	var x := r.position.x + 8
	var w := r.size.x - 16
	var y := r.position.y + 7
	_t(tr("SE_CONFIRMAR"), x, y, 12, Desenho.TEXTO, w, HORIZONTAL_ALIGNMENT_LEFT, true)
	y += 20
	var st := missao.st
	var falhas: Array = p["falhas"]
	var fim: Dictionary = p["st"]
	var o2_zero: bool = roundi(fim["O"]) == 0
	_linha_previsao(x, y, w, "energia", tr("ENERGIA"), st["E"], fim["E"], "energia" in falhas, tr("FALHA_ENERGIA"), false)
	y += 42
	_linha_previsao(x, y, w, "oxigenio", tr("OXIGENIO"), st["O"], fim["O"], "oxigenio" in falhas, tr("FALHA_OXIGENIO"),
		o2_zero, tr("ATENCAO_OXIGENIO"))
	y += 42
	_linha_previsao(x, y, w, "radiacao", tr("MARGEM"), st["M"], fim["M"], "radiacao" in falhas, tr("FALHA_MARGEM"), false,
		"", tr("SOL_SEM_TEMPESTADE"))
	y += 52
	Desenho.icone(self, "ciencia", Rect2(x, y + 1, 12, 12), Desenho.TEXTO, Desenho.FUNDO_TELA)
	_t(tr("CIENCIA"), x + 16, y, 11, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	_t("+%d" % int(p["ciencia"]), x, y - 1, 13, Desenho.TEXTO, w, HORIZONTAL_ALIGNMENT_RIGHT, true)
	_botao("confirmar", Rect2(x - 2, r.end.y - 52, w + 4, 46), tr("CONFIRMAR_PLANO"), "check", true, 13)


func _linha_previsao(x: float, y: float, w: float, icone: String, nome: String, antes: float, depois: float,
		falha: bool, texto_falha: String, atencao: bool, texto_atencao: String = "", nota: String = "") -> void:
	var cor := Desenho.TEXTO
	if falha:
		cor = Desenho.VERMELHO
	elif atencao:
		cor = Desenho.AMARELO
	Desenho.icone(self, icone, Rect2(x, y + 1, 12, 12), cor, Desenho.FUNDO_TELA)
	_t(nome, x + 16, y, 11, cor, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	_de_para(x, y - 1, w, _numero(antes), "%s/12" % _numero(maxf(0.0, depois)), cor)  # a barra não mostra número negativo
	Desenho.celulas(self, Rect2(x, y + 17, w, 6), maxf(0.0, depois), 12, cor)
	if falha or atencao:
		var txt := texto_falha if falha else texto_atencao
		Desenho.icone(self, "alerta", Rect2(x, y + 26, 11, 11), cor, Desenho.FUNDO_TELA)
		_t(txt, x + 15, y + 26, 10, cor, w - 15, HORIZONTAL_ALIGNMENT_LEFT, true)
	elif nota != "":
		_t(nota, x, y + 26, 10, Desenho.TEXTO_SUAVE, w)


# --- turno -----------------------------------------------------------------------

## A lista de tarefas do sol, estilo Among Us: ícone, uma palavra, estado.
func _desenhar_turno() -> void:
	_cabecalho(tr("CAB_SOL") % [missao.sol, Modelo.N.SOLS], tr("CAB_TURNO"), missao.barras_na_fase("turno"))
	var r := Rect2(X_ESQ, Y_CORPO, 612, 280)
	_caixa(r)
	var x := r.position.x + 10
	var y := r.position.y + 8
	_t(tr("LISTA_TAREFAS"), x, y, 13, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	y += 24
	if missao.medidor() > Missao.LIMIAR_ABRIGO:
		_linha_abrigo(Rect2(x, y, r.size.x - 20, 40))
		y += 46
	for nome in missao.plano_tarefas:
		_linha_tarefa(nome, Rect2(x, y, r.size.x - 20, 40))
		y += 46
	if missao.plano_tarefas.is_empty() and missao.medidor() <= Missao.LIMIAR_ABRIGO:
		_t(tr("SEM_TAREFAS"), x, y + 6, 12, Desenho.TEXTO_SUAVE)


func _linha_base(r: Rect2) -> void:
	draw_rect(r, Desenho.FUNDO_TERMINAL)
	draw_rect(r, Desenho.BORDA, false, 1.0)


func _estado_texto(estado: String) -> String:
	return tr("ESTADO_" + estado.to_upper())


func _linha_tarefa(nome: String, r: Rect2) -> void:
	_linha_base(r)
	var estado: String = missao.tarefas.get(nome, "pendente")
	Desenho.icone(self, nome, Rect2(r.position.x + 10, r.position.y + 10, 20, 20), Desenho.TEXTO, Desenho.FUNDO_TERMINAL)
	_t(_nome_tarefa(nome), r.position.x + 40, r.position.y + 12, 14, Desenho.TEXTO, 120, HORIZONTAL_ALIGNMENT_LEFT, true)
	var xe := r.position.x + 170
	match estado:
		"feita":
			Desenho.icone(self, "check", Rect2(xe, r.position.y + 12, 16, 16), Desenho.TEXTO, Desenho.FUNDO_TERMINAL)
			_t(_estado_texto("feita"), xe + 22, r.position.y + 13, 13, Desenho.TEXTO, 120)
		"rodando":
			var f := missao.progresso_tarefa(nome)
			_t(_estado_texto("rodando"), xe, r.position.y + 5, 11, Desenho.TEXTO)
			var rb := Rect2(xe, r.position.y + 22, 150, 10)
			draw_rect(rb, Desenho.CELULA_VAZIA)
			draw_rect(Rect2(rb.position, Vector2(rb.size.x * f, rb.size.y)), Desenho.TEXTO)
			_t("%d%%" % roundi(f * 100.0), rb.end.x + 8, rb.position.y - 3, 12, Desenho.TEXTO, 40, HORIZONTAL_ALIGNMENT_LEFT, true)
		_:
			Desenho.icone(self, "circulo", Rect2(xe, r.position.y + 12, 16, 16), Desenho.TEXTO_SUAVE, Desenho.FUNDO_TERMINAL)
			_t(_estado_texto("pendente"), xe + 22, r.position.y + 13, 13, Desenho.TEXTO_SUAVE, 120)
	if nome == "chemcam":
		# Placeholder: o ChemCam de verdade se faz pelas câmeras do terminal (P1).
		_botao("iniciar_chemcam", Rect2(r.end.x - 130, r.position.y + 5, 122, 30), tr("INICIAR"), "",
			missao.fase == "turno" and estado == "pendente" and not missao.abrigado and missao.tarefa_rodando == "", 12)


func _linha_abrigo(r: Rect2) -> void:
	_linha_base(r)
	var feita := missao.abrigado
	var cor := Desenho.TEXTO if feita else Desenho.VERMELHO
	draw_rect(r, cor, false, 2.0)
	Desenho.icone(self, "alerta", Rect2(r.position.x + 10, r.position.y + 10, 20, 20), cor, Desenho.FUNDO_TERMINAL)
	_t(tr("ABRIGO"), r.position.x + 40, r.position.y + 12, 14, cor, 120, HORIZONTAL_ALIGNMENT_LEFT, true)
	var xe := r.position.x + 170
	if feita:
		Desenho.icone(self, "check", Rect2(xe, r.position.y + 12, 16, 16), cor, Desenho.FUNDO_TERMINAL)
		_t(_estado_texto("feita"), xe + 22, r.position.y + 13, 13, cor, 120)
	else:
		Desenho.icone(self, "circulo", Rect2(xe, r.position.y + 12, 16, 16), cor, Desenho.FUNDO_TERMINAL)
		_t(_estado_texto("pendente"), xe + 22, r.position.y + 13, 13, cor, 120)


# --- fim do sol: o diário --------------------------------------------------------

func _registro_atual() -> Dictionary:
	if missao.registros.is_empty():
		return {}
	return missao.registros[missao.registros.size() - 1]


func _desenhar_diario() -> void:
	var reg := _registro_atual()
	if reg.is_empty():
		return
	Desenho.icone(self, "sol", Rect2(X_ESQ, 14, 14, 14), Desenho.TEXTO, Desenho.FUNDO_TERMINAL)
	_t(tr("DIARIO_DO_SOL") % reg["sol"], X_ESQ + 20, 12, 14, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	_t(tr("CAB_SOL") % [reg["sol"], Modelo.N.SOLS], 470, 14, 12, Desenho.TEXTO_SUAVE, 156, HORIZONTAL_ALIGNMENT_RIGHT)

	# Esquerda: o que se escreveu sozinho.
	var r := Rect2(X_ESQ, Y_CORPO - 4, 372, 280)
	_caixa(r)
	var x := r.position.x + 10
	var w := r.size.x - 20
	var y := r.position.y + 9
	# 1. O que aconteceu.
	if reg["seguranca"]:
		Desenho.icone(self, "alerta", Rect2(x, y + 1, 12, 12), Desenho.AMARELO, Desenho.FUNDO_TELA)
		y += _t(tr("DIARIO_SEGURANCA"), x + 16, y, 12, Desenho.AMARELO, w - 16, HORIZONTAL_ALIGNMENT_LEFT, true) + 6
	elif reg["tempestade"]:
		y += _t(tr("DIARIO_TEMPESTADE"), x, y, 12, Desenho.TEXTO, w, HORIZONTAL_ALIGNMENT_LEFT, true) + 2
		var chave := "DIARIO_ABRIGO_A_TEMPO"
		if not reg["abrigou"]:
			chave = "DIARIO_SEM_ABRIGO"
		elif reg["f_exposto"] > 0.0:
			chave = "DIARIO_ABRIGO_TARDE"
		y += _t(tr(chave) % roundi(reg["dose"]), x, y, 12, Desenho.TEXTO, w) + 6
	else:
		y += _t(tr("DIARIO_CALMO"), x, y, 12, Desenho.TEXTO, w, HORIZONTAL_ALIGNMENT_LEFT, true) + 6
	# 2. Ciência.
	if not reg["seguranca"]:
		Desenho.icone(self, "ciencia", Rect2(x, y + 1, 12, 12), Desenho.TEXTO, Desenho.FUNDO_TELA)
		y += _t(tr("DIARIO_CIENCIA") % [reg["ciencia"], missao.ciencia_total()], x + 16, y, 12, Desenho.TEXTO, w - 16) + 4
		# 3. Tarefa não feita: a reserva volta à bateria (e o que passou do teto se perdeu).
		for nome in reg["nao_feitas"]:
			y += _t(tr("DIARIO_NAO_FEITA") % [_nome_tarefa(nome), roundi(Modelo.N.CIENCIA_CUSTO)], x, y, 11,
				Desenho.TEXTO, w) + 2
		if reg["perdida_no_teto"] > 0.0:
			y += _t(tr("DIARIO_PERDIDA") % roundi(reg["perdida_no_teto"]), x, y, 11, Desenho.TEXTO, w) + 2
		y += 4
	# 4. A mensagem recebida.
	if reg["aviso"]:
		draw_line(Vector2(x, y), Vector2(x + w, y), Desenho.BORDA, 1.0)
		y += 6
		Desenho.icone(self, "terra", Rect2(x, y, 12, 12), Desenho.AZUL, Desenho.FUNDO_TELA)
		_t(tr("DIARIO_MENSAGEM"), x + 16, y, 11, Desenho.AZUL, w - 16, HORIZONTAL_ALIGNMENT_LEFT, true)
		y += 14
		_t(tr("AVISO_TEMPESTADE"), x + 16, y, 11, Desenho.TEXTO, w - 16)

	# Direita: as barras, antes e depois.
	var rb := Rect2(X_ESQ + 378, Y_CORPO - 4, 234, 222)
	_caixa(rb)
	var bx := rb.position.x + 10
	var bw := rb.size.x - 20
	var by := rb.position.y + 9
	_t(tr("DIARIO_BARRAS"), bx, by, 11, Desenho.TEXTO_SUAVE, bw)
	by += 20
	var nomes := {"E": ["energia", tr("ENERGIA")], "O": ["oxigenio", tr("OXIGENIO")], "M": ["radiacao", tr("MARGEM")]}
	for k in ["E", "O", "M"]:
		var a: float = reg["antes"][k]
		var d: float = reg["depois"][k]
		Desenho.icone(self, nomes[k][0], Rect2(bx, by + 1, 12, 12), Desenho.TEXTO, Desenho.FUNDO_TELA)
		_t(nomes[k][1], bx + 16, by, 11, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
		_de_para(bx, by - 1, bw, _numero(a), "%s/12" % _numero(d), Desenho.TEXTO)
		Desenho.celulas(self, Rect2(bx, by + 17, bw, 6), maxf(0.0, d), 12)
		by += 44
	_botao("enviar", Rect2(X_ESQ + 378, r.end.y - 50, 234, 50), tr("ENVIAR_A_TERRA"), "terra", true, 14)


# --- noite -----------------------------------------------------------------------

func _desenhar_noite() -> void:
	draw_rect(TELA, Desenho.NOITE)
	Desenho.icone(self, "noite", Rect2(304, 124, 32, 32), Desenho.TEXTO, Desenho.NOITE)
	_t(tr("NOITE_AQUECIMENTO") % roundi(Modelo.N.AQUEC), 120, 170, 16, Desenho.TEXTO, 400, HORIZONTAL_ALIGNMENT_CENTER, true)


# --- modo de segurança -----------------------------------------------------------

func _desenhar_seguranca() -> void:
	var r := Rect2(40, 10, 560, 310)
	draw_rect(r, Desenho.FUNDO_TERMINAL)
	draw_rect(r, Desenho.BORDA, false, 2.0)
	var x := r.position.x + 16
	var w := r.size.x - 32
	var y := r.position.y + 12
	Desenho.icone(self, "alerta", Rect2(x, y + 1, 20, 20), Desenho.AMARELO, Desenho.FUNDO_TERMINAL)
	_t(tr("MODO_SEGURANCA"), x + 28, y, 18, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	Desenho.icone(self, "sol", Rect2(r.end.x - 90, y + 3, 14, 14), Desenho.TEXTO, Desenho.FUNDO_TERMINAL)
	_t(tr("SOL_N") % missao.sol, r.end.x - 70, y + 2, 14, Desenho.TEXTO, 56, HORIZONTAL_ALIGNMENT_LEFT, true)
	y += 36
	var b := missao.barras_falha
	var causa := missao.causa
	var larg_barra := (w - 40.0) / 3.0
	_barra(x + 4, y + 4, larg_barra - 8, "energia", tr("ENERGIA"), b["E"], 12, causa == "energia")
	_barra(x + larg_barra + 24, y + 4, larg_barra - 8, "oxigenio", tr("OXIGENIO"), b["O"], 12, causa == "oxigenio")
	_barra(x + 2 * larg_barra + 44, y + 4, larg_barra - 8, "radiacao", tr("MARGEM"), b["M"], 12, causa == "radiacao")
	y += 42

	# A causa em 1 a 2 frases.
	var frase := tr("CAUSA_" + causa.to_upper())
	if missao.causa_sem_abrigo:
		frase += " " + tr("CAUSA_SEM_ABRIGO")
	y += _t(frase, x, y, 14, Desenho.TEXTO, w, HORIZONTAL_ALIGNMENT_LEFT, true) + 4
	if not missao.tem_conserto:
		y += _t(tr("SEM_CONSERTO"), x, y, 13, Desenho.TEXTO, w) + 4
	y += 4

	# O caso real.
	var h_caso := 62.0
	var rc := Rect2(x, y, w, h_caso)
	_caixa(rc, Desenho.FUNDO_TELA)
	_t(tr("CASO_REAL_" + causa.to_upper()), rc.position.x + 10, rc.position.y + 6, 11, Desenho.TEXTO_SUAVE, w - 20,
		HORIZONTAL_ALIGNMENT_LEFT, true)
	_t(tr("CASO_TEXTO_" + causa.to_upper()), rc.position.x + 10, rc.position.y + 22, 12, Desenho.TEXTO, w - 20)
	y += h_caso + 8

	Desenho.icone(self, "alerta", Rect2(x, y + 1, 12, 12), Desenho.TEXTO, Desenho.FUNDO_TERMINAL)
	_t(tr("MODOS_NA_MISSAO") % missao.modos, x + 18, y, 12, Desenho.TEXTO, w - 18)

	# Um botão só: reinicia (há conserto) ou segue (não há).
	var rb := Rect2(x, r.end.y - 66, 260, 46)
	if missao.tem_conserto:
		_botao("reiniciar", rb, tr("REINICIA_O_SOL"), "", true, 13)
		_t(tr("VOLTA_AO_PLANO") % missao.sol, rb.end.x + 14, rb.position.y + 14, 12, Desenho.TEXTO_SUAVE, w - 280)
	else:
		_botao("seguir", Rect2(x, r.end.y - 66, 300, 46), tr("SEGUIR_EM_SEGURANCA"), "", true, 13)
		_t(tr("SEGUIR_NOTA"), x + 314, rb.position.y + 6, 11, Desenho.TEXTO_SUAVE, w - 314)


# --- relatório -------------------------------------------------------------------

func _desenhar_relatorio() -> void:
	var x := X_ESQ
	_t(tr("RELATORIO_TITULO"), x, 12, 16, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	_t(tr("RELATORIO_SUB") % Modelo.N.SOLS, x, 31, 11, Desenho.TEXTO_SUAVE)
	# Estrelas.
	var estrelas := missao.estrelas()
	for i in 3:
		Desenho.icone(self, "estrela" if i < estrelas else "estrela_vazia", Rect2(544 + i * 27, 11, 22, 22),
			Desenho.TEXTO, Desenho.FUNDO_TERMINAL)
	_t(tr("N_DE_3_ESTRELAS") % estrelas, 280, 11, 14, Desenho.TEXTO, 254, HORIZONTAL_ALIGNMENT_RIGHT, true)
	_t(tr("ESTRELAS_NOTA"), 280, 34, 10, Desenho.TEXTO_SUAVE, 346, HORIZONTAL_ALIGNMENT_RIGHT)

	# Três blocos.
	var y := 52.0
	var bw := 196.0
	var rects := [Rect2(x, y, bw, 52), Rect2(x + bw + 12, y, bw, 52), Rect2(x + 2 * (bw + 12), y, bw, 52)]
	_caixa(rects[0])
	Desenho.icone(self, "ciencia", Rect2(rects[0].position.x + 10, y + 14, 22, 22), Desenho.TEXTO, Desenho.FUNDO_TELA)
	_t(tr("CIENCIA"), rects[0].position.x + 42, y + 8, 11, Desenho.TEXTO_SUAVE)
	_t(tr("N_PONTOS") % missao.ciencia_total(), rects[0].position.x + 42, y + 22, 18, Desenho.TEXTO, bw - 50,
		HORIZONTAL_ALIGNMENT_LEFT, true)
	_caixa(rects[1])
	Desenho.icone(self, "radiacao", Rect2(rects[1].position.x + 10, y + 14, 22, 22), Desenho.TEXTO, Desenho.FUNDO_TELA)
	_t(tr("MARGEM_FINAL"), rects[1].position.x + 42, y + 8, 11, Desenho.TEXTO_SUAVE)
	_t(tr("N_DE_12") % roundi(missao.st["M"]), rects[1].position.x + 42, y + 22, 18, Desenho.TEXTO, 90,
		HORIZONTAL_ALIGNMENT_LEFT, true)
	Desenho.celulas(self, Rect2(rects[1].position.x + 118, y + 28, 68, 8), missao.st["M"], 12)
	_caixa(rects[2])
	Desenho.icone(self, "alerta", Rect2(rects[2].position.x + 10, y + 14, 22, 22), Desenho.TEXTO, Desenho.FUNDO_TELA)
	_t(tr("MODOS_SEGURANCA"), rects[2].position.x + 42, y + 8, 11, Desenho.TEXTO_SUAVE, bw - 50)
	_t(str(missao.modos), rects[2].position.x + 42, y + 22, 18, Desenho.TEXTO, 60, HORIZONTAL_ALIGNMENT_LEFT, true)

	# A faixa dos 5 sóis.
	y = 114.0
	var sw := 116.0
	for i in missao.registros.size():
		var reg: Dictionary = missao.registros[i]
		var rs := Rect2(x + i * (sw + 8), y, sw, 40)
		_caixa(rs)
		Desenho.icone(self, "sol", Rect2(rs.position.x + 8, y + 8, 14, 14), Desenho.TEXTO, Desenho.FUNDO_TELA)
		_t(tr("SOL_N") % reg["sol"], rs.position.x + 26, y + 6, 11, Desenho.TEXTO_SUAVE)
		_t("+%d" % reg["ciencia"], rs.position.x + 8, y + 22, 14, Desenho.TEXTO, 60, HORIZONTAL_ALIGNMENT_LEFT, true)
		var xi := rs.end.x - 22
		if reg["seguranca"]:
			Desenho.icone(self, "alerta", Rect2(xi, y + 20, 16, 16), Desenho.AMARELO, Desenho.FUNDO_TELA)
			xi -= 20
		if reg["tempestade"]:
			Desenho.icone(self, "tempestade", Rect2(xi, y + 20, 16, 16), Desenho.TEXTO, Desenho.FUNDO_TELA)

	# O que aconteceu de verdade.
	y = 166.0
	_t(tr("DE_VERDADE"), x, y, 13, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	var rv := Rect2(x, y + 22, 612, 62)
	_caixa(rv)
	_t(tr("DE_VERDADE_DATA"), rv.position.x + 10, rv.position.y + 7, 11, Desenho.TEXTO_SUAVE, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	_t(tr("DE_VERDADE_TEXTO"), rv.position.x + 10, rv.position.y + 24, 13, Desenho.TEXTO, rv.size.x - 20)
	_botao("jogar_de_novo", Rect2(220, 264, 200, 50), tr("JOGAR_DE_NOVO"), "", true, 14)
