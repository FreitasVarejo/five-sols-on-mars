extends Control
## Andamento das tarefas de ciência nas estações da sala (estufa e glovebox): uma barra enquanto a
## tarefa roda e uma marca quando está feita. Fica dentro da Sala, antes do shader, para curvar com a
## parede. Verde só no que se clica: o anel verde marca a estação que dá para clicar agora.

const Desenho := preload("res://scripts/desenho.gd")

## nome da tarefa -> Rect2 da estação no panorama (planta: estufa; amostra: glovebox).
var regioes := {}
## nome da tarefa -> estado ("pendente", "rodando", "feita"); só as tarefas escolhidas no plano.
var estados := {}
var progresso := {}
## nome da tarefa -> true se dá para clicar agora.
var clicaveis := {}


func atualizar(novos_estados: Dictionary, novo_progresso: Dictionary, novos_clicaveis: Dictionary) -> void:
	if novos_estados != estados or novo_progresso != progresso or novos_clicaveis != clicaveis:
		estados = novos_estados.duplicate()
		progresso = novo_progresso.duplicate()
		clicaveis = novos_clicaveis.duplicate()
		queue_redraw()


func _draw() -> void:
	for nome: String in estados:
		if not regioes.has(nome):
			continue
		var r: Rect2 = regioes[nome]
		var fundo := Color(Desenho.NOITE, 0.82)
		match estados[nome]:
			"rodando":
				var barra := Rect2(r.position.x + 10, r.end.y - 22, r.size.x - 20, 10)
				draw_rect(Rect2(barra.position - Vector2(2, 2), barra.size + Vector2(4, 4)), fundo)
				draw_rect(barra, Desenho.CELULA_VAZIA)
				draw_rect(Rect2(barra.position, Vector2(barra.size.x * progresso.get(nome, 0.0), barra.size.y)), Desenho.TEXTO)
			"feita":
				var c := Vector2(r.get_center().x, r.position.y + 22)
				draw_circle(c, 13, fundo)
				Desenho.icone(self, "check", Rect2(c - Vector2(8, 8), Vector2(16, 16)), Desenho.TEXTO, fundo)
			_:
				if clicaveis.get(nome, false):
					var c := Vector2(r.get_center().x, r.position.y + 22)
					draw_circle(c, 13, fundo)
					draw_arc(c, 9, 0.0, TAU, 20, Desenho.VERDE, 3.0)
