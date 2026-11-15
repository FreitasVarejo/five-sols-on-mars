extends Control
## Botão de mudo: no canto direito da faixa de baixo, na mesma linha do botão TERMINAL, fixo em
## todas as fases e clicável também com o card da Terra aberto. É o último nó da cena: fica por cima
## do terminal e recebe o clique antes dele. Não faz clique (o som é o próprio mudo).
##
## Ícone desenhado por código (alto-falante; riscado quando mudo). Cor [R]: verde só no que se clica.
## Fica longe da seta direita do pan (meio da borda, y 120 a 240) e do botão TERMINAL (x 260 a 380).

const Desenho := preload("res://scripts/desenho.gd")
const Som := preload("res://scripts/som.gd")

const BOTAO := Rect2(596, 328, 38, 28)

var som: Som

var _hover := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Nome -> [x, y, w, h], no formato do ui() do terminal (a sonda de teste lê).
func ui() -> Dictionary:
	return {"mudo": [roundi(BOTAO.position.x), roundi(BOTAO.position.y), roundi(BOTAO.size.x), roundi(BOTAO.size.y)]}


func _input(event: InputEvent) -> void:
	if som == null:
		return
	if event is InputEventMouse:
		var dentro := BOTAO.has_point(event.position)
		if dentro != _hover:
			_hover = dentro
			queue_redraw()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and BOTAO.has_point(event.position):
		som.alternar_mudo()
		queue_redraw()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if som == null:
		return
	var fundo := Desenho.VERDE_CLARO if _hover else Desenho.VERDE
	draw_rect(BOTAO, Desenho.VERDE_ESCURO)
	draw_rect(BOTAO.grow(-2.0), fundo)
	var lado := 20.0
	var icone := "alto_falante_mudo" if som.esta_mudo() else "alto_falante"
	Desenho.icone(self, icone, Rect2(BOTAO.get_center() - Vector2(lado, lado) / 2.0, Vector2(lado, lado)),
		Desenho.TEXTO_ESCURO, fundo)
