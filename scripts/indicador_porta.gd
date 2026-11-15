extends Control
## Indicador de "pode dormir" da porta do dormitório. Fica na camada da sala (antes do shader), no
## sistema de coordenadas do panorama, para curvar com a parede como as telas.
##
## O render já traz a lâmpada da porta pintada (verde, âmbar ou vermelha, conforme o estado do
## panorama). Aqui ela é sempre repintada por cima: apagada quando não dá para ir dormir, e acesa em
## verde, com um brilho firme (sem piscar: [R] no máximo 3 flashes por segundo), quando dá. Quando
## dá, uma lua aparece sobre a folha da porta.
##
## As regiões vêm de assets/comodo/regioes.json (gerado pelo arte/blender/comodo.py).

const Desenho := preload("res://scripts/desenho.gd")

const LAMPADA_APAGADA := Color("#151d28")
const LAMPADA_APAGADA_BORDA := Color("#10141f")
const LAMPADA_ACESA := Desenho.VERDE_CLARO
const BRILHO := Desenho.VERDE
const LUA := Desenho.TEXTO
const LUA_CONTORNO := Desenho.NOITE  # contorno escuro de 2 px: a lua se lê sobre a madeira e a faixa da porta

var lampada := Rect2()  # "desenho.porta_lampada" do regioes.json
var porta := Rect2()    # "botoes.porta" do regioes.json
var aceso := false


## Acende ou apaga o indicador.
func atualizar(pode: bool) -> void:
	if pode != aceso:
		aceso = pode
		queue_redraw()


## O retângulo da lua: sobre a folha da porta, na altura em que a lâmpada pode ficar cortada pela
## curva do shader. Quadrado, centrado em x na porta e no terço de cima dela.
func retangulo_da_lua() -> Rect2:
	var lado := clampf(porta.size.x * 0.38, 24.0, 56.0)
	return Rect2(porta.position.x + (porta.size.x - lado) / 2.0, porta.position.y + porta.size.y * 0.24, lado, lado)


func _draw() -> void:
	if lampada.size == Vector2.ZERO:
		return
	if not aceso:
		draw_rect(lampada, LAMPADA_APAGADA)
		draw_rect(lampada, LAMPADA_APAGADA_BORDA, false, 1.0)
		return
	# Brilho firme: dois halos translúcidos em volta e o corpo aceso.
	draw_rect(lampada.grow(4.0), Color(BRILHO, 0.18))
	draw_rect(lampada.grow(2.0), Color(BRILHO, 0.34))
	draw_rect(lampada, LAMPADA_ACESA)
	var lua := retangulo_da_lua()
	for d: Vector2 in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2), Vector2(-1.5, -1.5),
			Vector2(1.5, -1.5), Vector2(-1.5, 1.5), Vector2(1.5, 1.5)]:
		Desenho.icone(self, "lua", Rect2(lua.position + d, lua.size), LUA_CONTORNO)
	Desenho.icone(self, "lua", lua, LUA)
