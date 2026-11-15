extends Control
## A tela inicial: o título, o seletor de idioma (EN | PT) e o botão "Jogar". Vem antes da abertura.
##
## Desenho imediato, como o resto: o fundo é a visão geral do posto escurecida, e cada botão que se clica
## sai de _draw() com o retângulo que também vale para o clique (rect_*, ui()). Verde só no que se clica;
## o idioma escolhido fica apertado (verde escuro) e com um visto. Funciona com mouse e com um dedo (o
## toque chega como mouse emulado), sem teclado. Os botões fazem o som de clique que já existe.
##
## Quem hospeda (main.gd) liga `idioma_escolhido` (troca o idioma) e `jogar` (vai à abertura). Esta peça
## só guarda qual idioma está marcado (`idioma`); quem decide o idioma de verdade é o hospedeiro.

signal idioma_escolhido(lang: String)
signal jogar

const Desenho := preload("res://scripts/desenho.gd")

const FUNDO := preload("res://assets/exterior/visao_geral_normal.png")
const ESCURECER := 0.62
const TAM_TITULO := 40
const BOTAO_IDIOMA := Vector2(76, 36)
const VAO_IDIOMA := 12.0
const BOTAO_JOGAR := Vector2(220, 52)
const Y_TITULO := 62.0
const Y_IDIOMA := 168.0
const Y_JOGAR := 238.0

## Opcional: o nó Som (scripts/som.gd), injetado por quem hospeda. Só precisa de `tocar(nome)`.
var som = null
## O idioma marcado: "en" ou "pt".
var idioma := "en"

var _hover := ""
var _emitido := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Marca o idioma sem emitir (o hospedeiro e o teste usam).
func marcar_idioma(lang: String) -> void:
	idioma = "pt" if lang == "pt" else "en"
	queue_redraw()


func rect_en() -> Rect2:
	var x := size.x / 2.0 - VAO_IDIOMA / 2.0 - BOTAO_IDIOMA.x
	return Rect2(roundf(x), Y_IDIOMA, BOTAO_IDIOMA.x, BOTAO_IDIOMA.y)


func rect_pt() -> Rect2:
	var x := size.x / 2.0 + VAO_IDIOMA / 2.0
	return Rect2(roundf(x), Y_IDIOMA, BOTAO_IDIOMA.x, BOTAO_IDIOMA.y)


func rect_jogar() -> Rect2:
	return Rect2(roundf((size.x - BOTAO_JOGAR.x) / 2.0), Y_JOGAR, BOTAO_JOGAR.x, BOTAO_JOGAR.y)


## O que se clica agora, nome -> [x, y, w, h] (a sonda de teste lê).
func ui() -> Dictionary:
	var d := {}
	for par in [["idioma_en", rect_en()], ["idioma_pt", rect_pt()], ["jogar", rect_jogar()]]:
		var r: Rect2 = par[1]
		d[par[0]] = [roundi(r.position.x), roundi(r.position.y), roundi(r.size.x), roundi(r.size.y)]
	return d


## O botão sob o ponto `p` ("" se nenhum).
func botao_em(p: Vector2) -> String:
	if rect_jogar().has_point(p):
		return "jogar"
	if rect_en().has_point(p):
		return "idioma_en"
	if rect_pt().has_point(p):
		return "idioma_pt"
	return ""


# --- entrada ---------------------------------------------------------------------

## Só o mouse (o toque chega como mouse emulado): conta o clique no botão e não deixa passar nada.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := botao_em((event as InputEventMouseMotion).position)
		if h != _hover:
			_hover = h
			queue_redraw()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			acionar(botao_em(mb.position))
		accept_event()


## Faz a ação do botão `nome`. O "Jogar" emite uma vez só.
func acionar(nome: String) -> void:
	match nome:
		"idioma_en", "idioma_pt":
			idioma = "pt" if nome == "idioma_pt" else "en"
			_tocar("clique_navegar")
			idioma_escolhido.emit(idioma)
			queue_redraw()
		"jogar":
			if _emitido:
				return
			_emitido = true
			_tocar("clique_confirmar")
			jogar.emit()


func _tocar(nome: String) -> void:
	if som != null:
		som.tocar(nome)


# --- desenho ---------------------------------------------------------------------

func _draw() -> void:
	var cheio := Rect2(Vector2.ZERO, size)
	draw_texture_rect(FUNDO, cheio, false)
	draw_rect(cheio, Color(Desenho.MOLDURA, ESCURECER))
	var titulo := "Five Sols on Mars"
	var larg := Desenho.largura_texto(titulo, TAM_TITULO, true)
	var x := roundf((size.x - larg) / 2.0)
	Desenho.texto(self, titulo, Vector2(x, Y_TITULO + 2.0), TAM_TITULO, Color(0, 0, 0, 0.7), -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	Desenho.texto(self, titulo, Vector2(x, Y_TITULO), TAM_TITULO, Desenho.TEXTO, -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	_botao_idioma("idioma_en", rect_en(), "EN", idioma == "en")
	_botao_idioma("idioma_pt", rect_pt(), "PT", idioma == "pt")
	_botao_jogar()


func _botao_idioma(nome: String, r: Rect2, rotulo: String, marcado: bool) -> void:
	var fundo := Desenho.VERDE_ESCURO if marcado else (Desenho.VERDE_CLARO if _hover == nome else Desenho.VERDE)
	var borda := Desenho.VERDE if marcado else Desenho.VERDE_ESCURO
	var cor := Desenho.TEXTO if marcado else Desenho.TEXTO_ESCURO
	draw_rect(r, borda)
	draw_rect(r.grow(-2.0), fundo)
	var tam := 16
	var larg := Desenho.largura_texto(rotulo, tam, true)
	var lado := 14.0
	var total := larg + (lado + 5.0 if marcado else 0.0)
	var xx := r.position.x + (r.size.x - total) / 2.0
	var ym := r.position.y + r.size.y / 2.0
	if marcado:
		Desenho.icone(self, "check", Rect2(xx, ym - lado / 2.0, lado, lado), cor, fundo)
		xx += lado + 5.0
	Desenho.texto(self, rotulo, Vector2(xx, ym - Desenho.fonte().get_height(tam) / 2.0), tam, cor, -1.0,
		HORIZONTAL_ALIGNMENT_LEFT, true)


func _botao_jogar() -> void:
	var r := rect_jogar()
	var fundo := Desenho.VERDE_CLARO if _hover == "jogar" else Desenho.VERDE
	draw_rect(r, Desenho.VERDE_ESCURO)
	draw_rect(r.grow(-2.0), fundo)
	var rotulo := tr("JOGAR")
	var tam := 22
	var larg := Desenho.largura_texto(rotulo, tam, true)
	Desenho.texto(self, rotulo, Vector2(r.position.x + (r.size.x - larg) / 2.0,
		r.position.y + (r.size.y - Desenho.fonte().get_height(tam)) / 2.0), tam, Desenho.TEXTO_ESCURO, -1.0,
		HORIZONTAL_ALIGNMENT_LEFT, true)
