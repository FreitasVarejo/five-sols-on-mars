extends Control
## A vista de perto: a peça da planta (estufa) e a da amostra (glovebox) abrem aqui, numa imagem da estação
## renderizada no Blender (assets/comodo/perto_<estacao>.png, de arte/blender/comodo.py --perto), e não no visor
## do terminal. O vidro da câmara sai com alpha 0 no PNG: a peça fica ATRÁS dele, no retângulo que o
## regioes.json guarda em "perto" (o maior retângulo inscrito no vidro), como a vista de Marte atrás da janela.
##
## Camada nova da main, entre o terminal e o botão de mudo. NÃO é a `_sobreposicao` dela: o relógio do turno
## segue correndo, o HUD do turno fica por cima (a main o sobe de z enquanto a vista está à mostra) e o
## terminal fica abaixado e bloqueado (terminal.bloqueado). A main lê `fase`, `zoom()` e `ui()`.
##
## Fases: "" (fechada), "zoom" (a sala se aproxima da estação, em ZOOM_S; a main aplica `zoom()` na Sala, e esta
## camada aparece no fim), "aberta" (a peça e o botão de voltar respondem) e "voltando" (VOLTAR_S, ou
## VOLTAR_RAPIDO_S quando a tarefa para por fora). Fora de "aberta" nada aqui recebe toque, e a main não deixa
## a sala responder.
##
## A peça nasce no primeiro toque na estação (missao.iniciar_tarefa) e fica MANTIDA, escondida, enquanto a
## tarefa roda: voltar para a sala não a recria, e tocar de novo na estação traz a mesma instância, no mesmo
## estado (ela segue andando escondida, como a do visor). Quando a tarefa deixa de rodar (fim do turno, abrigo,
## modo de segurança, reinício), a peça é liberada e, se a vista estava à mostra, volta-se à sala na hora. Ao
## `concluido` da peça: missao.concluir_tarefa e, depois de CONCLUIR_S, volta sozinha.

const Desenho := preload("res://scripts/desenho.gd")
const Missao := preload("res://scripts/missao.gd")
const SondaDaPeca := preload("res://scripts/minigames/sonda_da_peca.gd")
const CultivarPlanta := preload("res://scripts/minigames/cultivar_planta.gd")
const SelarAmostra := preload("res://scripts/minigames/selar_amostra.gd")

const JSON_REGIOES := "res://assets/comodo/regioes.json"
# Tarefa -> estação da sala (o botão de regioes.json), a peça e a imagem de perto de cada uma.
const ESTACAO_DA_TAREFA := {"planta": "estufa", "amostra": "glovebox"}
const PECAS := {"planta": CultivarPlanta, "amostra": SelarAmostra}
const IMAGENS := {
	"estufa": preload("res://assets/comodo/perto_estufa.png"),
	"glovebox": preload("res://assets/comodo/perto_glovebox.png"),
}
const TELA := Vector2(640, 360)
const ZOOM_S := 0.45           # a sala até a estação (spec do dono: no máximo 0,5 s)
const VOLTAR_S := 0.3          # de volta à sala (no máximo 0,3 s)
const VOLTAR_RAPIDO_S := 0.12  # a tarefa parou por fora: sem animação longa
const CONCLUIR_S := 0.5        # a peça concluída fica à vista antes de voltar sozinha
const APARECE_DE := 0.6        # a camada começa a aparecer neste ponto do zoom (0 a 1) e está inteira em 1
# O botão de voltar: canto de cima à direita, longe do HUD do turno (faixa do topo, à esquerda e no centro) e do
# botão de mudo (canto de baixo à direita). O retângulo da peça (perto em regioes.json) não o cobre.
const BOTAO_VOLTAR := Rect2(562, 6, 72, 32)

var missao: Missao
var som = null              # o nó Som: as peças tocam os sons delas
var fase := ""              # "", "zoom", "aberta" ou "voltando"
var tarefa := ""            # a tarefa na tela agora ("" com a vista fechada)

var _t := 0.0               # 0 = a sala, 1 = a vista de perto
var _duracao_volta := VOLTAR_S
var _regioes := {}          # estação -> Rect2 da peça, em px da imagem (= da tela)
var _pecas := {}            # tarefa -> peça, enquanto a tarefa roda
var _concluindo := ""       # a tarefa que acabou de concluir com a vista aberta: espera CONCLUIR_S e volta
var _t_concluir := 0.0
var _imagem: TextureRect
var _voltar: BotaoVoltar


## O botão de voltar: verde (é o que se clica), seta para a esquerda e a palavra. Só responde com a vista aberta.
class BotaoVoltar extends Control:
	signal pedido

	var _sob := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func() -> void: _sob = true; queue_redraw())
		mouse_exited.connect(func() -> void: _sob = false; queue_redraw())

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			pedido.emit()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Desenho.VERDE_ESCURO)
		var fundo := Desenho.VERDE_CLARO if _sob else Desenho.VERDE
		draw_rect(r.grow(-2.0), fundo)
		var rotulo := tr("VOLTAR_DA_ESTACAO")
		var tam := 12
		var lado := 14.0
		var total := lado + 5.0 + Desenho.largura_texto(rotulo, tam, true)
		var x := (size.x - total) / 2.0
		var ym := size.y / 2.0
		# A seta para a esquerda.
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, ym), Vector2(x + lado * 0.6, ym - lado * 0.5), Vector2(x + lado * 0.6, ym + lado * 0.5)]),
			Desenho.TEXTO_ESCURO)
		draw_rect(Rect2(x + lado * 0.55, ym - 1.5, lado * 0.45, 3.0), Desenho.TEXTO_ESCURO)
		Desenho.texto(self, rotulo, Vector2(x + lado + 5.0, ym - Desenho.fonte().get_height(tam) / 2.0), tam,
			Desenho.TEXTO_ESCURO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # com a camada à mostra, nada passa para a sala
	visible = false
	modulate.a = 0.0
	_carregar_regioes()
	_imagem = TextureRect.new()
	_imagem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_imagem.size = TELA
	add_child(_imagem)
	_voltar = BotaoVoltar.new()
	_voltar.position = BOTAO_VOLTAR.position
	_voltar.size = BOTAO_VOLTAR.size
	_voltar.pedido.connect(func() -> void: voltar())
	add_child(_voltar)
	_atualizar()


func _carregar_regioes() -> void:
	var dados = JSON.parse_string(FileAccess.get_file_as_string(JSON_REGIOES))
	assert(dados is Dictionary and dados.has("perto"), "regioes.json sem a chave perto")
	for estacao: String in IMAGENS:
		var r: Dictionary = dados["perto"][estacao]
		_regioes[estacao] = Rect2(r["x"], r["y"], r["w"], r["h"])


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, TELA), Desenho.MOLDURA)  # o que o vidro transparente deixa ver, fora da peça


# --- o que a main lê ---------------------------------------------------------------

## Há vista (em zoom, aberta ou voltando)? A sala não responde, o terminal fica bloqueado e o pan para.
func aberta() -> bool:
	return fase != ""


## O zoom da sala, de 0 (a sala inteira) a 1 (a estação à frente), já suavizado. A main o aplica na Sala.
func zoom() -> float:
	return _suavizar(_t)


## O botão de voltar (em px da tela), quando a vista está aberta e responde.
func rect_voltar() -> Rect2:
	return BOTAO_VOLTAR


## Nome -> [x, y, w, h] do que se clica agora aqui (a sonda lê): só o botão de voltar, com a vista aberta.
func ui() -> Dictionary:
	if fase != "aberta":
		return {}
	var r := BOTAO_VOLTAR
	return {"voltar": [roundi(r.position.x), roundi(r.position.y), roundi(r.size.x), roundi(r.size.y)]}


## A sonda: a tarefa na tela e a fase.
func perto() -> Dictionary:
	return {"tarefa": tarefa, "fase": fase}


## A peça na tela agora (nula com a vista fechada).
func peca_atual() -> Control:
	return _pecas.get(tarefa) if fase != "" else null


## A peça da tarefa, esteja à vista ou escondida (nula se a tarefa não tem peça).
func peca_da_tarefa(nome: String) -> Control:
	var p: Control = _pecas.get(nome)
	return p if is_instance_valid(p) else null


## O que a peça à vista oferece à sonda (veja sonda_da_peca.gd); vazio fora da fase aberta.
func minigame() -> Dictionary:
	if fase != "aberta":
		return {}
	return SondaDaPeca.descrever(peca_atual())


## O andamento da peça da tarefa (0 a 1); 0 sem peça. A barra da estação na sala e a linha do terminal leem.
func progresso_da_tarefa(nome: String) -> float:
	var p := peca_da_tarefa(nome)
	return clampf(p.progresso(), 0.0, 1.0) if p != null else 0.0


## O retângulo da peça da estação (px da tela): o `perto` do regioes.json.
func retangulo_da_peca(estacao: String) -> Rect2:
	return _regioes[estacao]


## Está andando (zoom ou voltando)? A sonda se atualiza a cada quadro.
func animando() -> bool:
	return fase == "zoom" or fase == "voltando"


# --- abrir e voltar -----------------------------------------------------------------

## Tocar na estação: a tarefa começa se ainda não roda (a peça nasce com ela), e a sala faz o zoom até a estação
## e mostra a vista. Se a tarefa já roda, a mesma peça volta à vista, no estado em que ficou. Devolve se abriu.
## Vale quando o terminal poderia levar à tarefa: no turno, fora do abrigo, com a tarefa rodando ou pendente e
## nenhuma outra rodando.
func abrir(nome: String) -> bool:
	if missao == null or fase != "" or not ESTACAO_DA_TAREFA.has(nome) or not _pode(nome):
		return false
	if missao.tarefa_rodando != nome:
		if not missao.iniciar_tarefa(nome):
			return false
		_liberar(nome)  # sobra de uma tarefa que já parou, se houver
		_hospedar(nome)
	elif peca_da_tarefa(nome) == null:
		_hospedar(nome)  # rodando sem peça (não deveria): só então se cria
	tarefa = nome
	fase = "zoom"
	_t = 0.0
	_concluindo = ""
	_imagem.texture = IMAGENS[ESTACAO_DA_TAREFA[nome]]
	_atualizar()
	return true


## Volta para a sala: a peça fica escondida, a tarefa segue. Sem efeito com a vista fechada ou já voltando.
func voltar(duracao: float = VOLTAR_S) -> void:
	if fase != "zoom" and fase != "aberta":
		return
	fase = "voltando"
	_duracao_volta = maxf(duracao, 0.001)
	_concluindo = ""
	_atualizar()


func _pode(nome: String) -> bool:
	if missao.fase != "turno" or missao.abrigado:
		return false
	if missao.tarefa_rodando == nome:
		return true
	return missao.tarefas.get(nome, "") == "pendente" and missao.tarefa_rodando == ""


func _rodando(nome: String) -> bool:
	return missao.fase == "turno" and not missao.abrigado and missao.tarefa_rodando == nome


func _hospedar(nome: String) -> void:
	var peca: Control = PECAS[nome].new()
	if nome == "planta":
		# O problema da estufa é o do sol na missão (fixo na fixa, sorteado e fixo no freeplay): o `modos` não entra.
		peca.definir_problema(missao.problema_da_planta())
	if "som" in peca:
		peca.som = som
	peca.concluido.connect(_ao_concluir.bind(nome))
	add_child(peca)
	move_child(peca, _imagem.get_index())  # a imagem vai por cima: a peça fica atrás do vidro
	peca.configurar(_regioes[ESTACAO_DA_TAREFA[nome]], missao.tarefa_s, missao.eh_poeira())
	_pecas[nome] = peca


func _liberar(nome: String) -> void:
	var peca: Control = _pecas.get(nome)
	_pecas.erase(nome)
	if is_instance_valid(peca):
		remove_child(peca)
		peca.queue_free()


## A peça terminou: a tarefa vira feita. Com a vista aberta, a peça pronta fica à vista por CONCLUIR_S e a vista volta
## sozinha; escondida, só se libera no quadro seguinte (a tarefa não roda mais).
func _ao_concluir(nome: String) -> void:
	missao.concluir_tarefa(nome)
	if fase == "aberta" and nome == tarefa:
		_concluindo = nome
		_t_concluir = CONCLUIR_S


# --- quadro a quadro ----------------------------------------------------------------

func _process(delta: float) -> void:
	if missao == null:
		return
	# A tarefa que parou de rodar (fim do turno, abrigo, modo de segurança, reinício, concluída) perde a peça. A da
	# vista só sai quando a vista fecha; se a vista está à mostra e a tarefa parou por fora, volta na hora.
	for nome: String in _pecas.keys():
		if _rodando(nome):
			continue
		if nome == tarefa and fase != "":
			if fase != "voltando" and _concluindo != nome:
				voltar(VOLTAR_RAPIDO_S)
			continue
		_liberar(nome)
	match fase:
		"zoom":
			_t = minf(_t + delta / ZOOM_S, 1.0)
			if _t >= 1.0:
				fase = "aberta"
		"aberta":
			if _concluindo != "":
				_t_concluir -= delta
				if _t_concluir <= 0.0:
					voltar()
		"voltando":
			_t = maxf(_t - delta / _duracao_volta, 0.0)
			if _t <= 0.0:
				fase = ""
				tarefa = ""
				_concluindo = ""
	_atualizar()


## Visibilidade, transparência e quem recebe toque, a partir da fase e do ponto do zoom.
func _atualizar() -> void:
	var e := _suavizar(_t)
	modulate.a = clampf((e - APARECE_DE) / (1.0 - APARECE_DE), 0.0, 1.0)
	visible = fase != "" and modulate.a > 0.0
	var responde := fase == "aberta"
	_voltar.mouse_filter = Control.MOUSE_FILTER_STOP if responde else Control.MOUSE_FILTER_IGNORE
	for nome: String in _pecas:
		var p: Control = _pecas[nome]
		var daqui := nome == tarefa and fase != ""
		p.visible = daqui
		p.mouse_filter = Control.MOUSE_FILTER_STOP if daqui and responde else Control.MOUSE_FILTER_IGNORE


static func _suavizar(p: float) -> float:
	var x := clampf(p, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
