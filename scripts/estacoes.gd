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
		var fundo := Color(Desenho.NOITE, 0.9)
		var c := Vector2(roundf(r.get_center().x), roundf(r.position.y) + 22.0)
		match estados[nome]:
			"rodando":
				# Barra com borda de 1 px; o andamento entra por dentro, em px inteiros.
				var barra := Rect2(roundf(r.position.x) + 10.0, roundf(r.end.y) - 22.0, roundf(r.size.x) - 20.0, 10.0)
				draw_rect(barra.grow(2.0), fundo)
				draw_rect(barra, Desenho.NOITE)
				var dentro := barra.grow(-1.0)
				var feito := roundf(dentro.size.x * clampf(progresso.get(nome, 0.0), 0.0, 1.0))
				draw_rect(Rect2(dentro.position, Vector2(feito, dentro.size.y)), Desenho.TEXTO)
				draw_rect(barra, Desenho.BORDA, false, 1.0)
			"feita":
				_disco(c, fundo)
				Desenho.icone(self, "check", Rect2(c - Vector2(8, 8), Vector2(16, 16)), Desenho.TEXTO, fundo)
			_:
				if clicaveis.get(nome, false):
					# Pode clicar: disco escuro com anel verde de 2 px, de raio inteiro.
					_disco(c, fundo)
					draw_arc(c, 10.0, 0.0, TAU, 64, Desenho.VERDE, 2.0, false)


## Disco escuro de raio 13, com a borda de 1 px.
func _disco(c: Vector2, fundo: Color) -> void:
	draw_circle(c, 13.0, fundo)
	draw_arc(c, 12.5, 0.0, TAU, 64, Desenho.BORDA, 1.0, false)
