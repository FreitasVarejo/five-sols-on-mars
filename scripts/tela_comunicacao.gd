extends Control
## A tela de comunicação com a Terra, na sala, em espera: o fundo das telas e, no centro, o ícone da
## Terra apagado (BORDA). Sem texto e sem mensagem. A tela de verdade é de outra fatia.
## Fica dentro da Sala, antes do shader, e curva junto com a parede.

const Desenho := preload("res://scripts/desenho.gd")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Desenho.FUNDO_TELA)
	var lado := floorf(minf(size.x, size.y) * 0.5)
	var origem := Vector2(roundf((size.x - lado) / 2.0), roundf((size.y - lado) / 2.0))
	Desenho.icone(self, "terra", Rect2(origem, Vector2(lado, lado)), Desenho.BORDA, Desenho.FUNDO_TELA)
