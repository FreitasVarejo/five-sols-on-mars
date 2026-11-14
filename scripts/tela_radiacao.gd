extends Control
## Tela de radiação do cômodo (129x77 px): a margem de radiação (barra de recurso, ícone, texto e
## número) e, separado dela, o medidor de radiação com as duas marcas (atenção e abrigo).
## Fica dentro da Sala, antes do shader, para curvar com a parede.
##
## O medidor só ganha cor quando está nas zonas: acima de "atenção" o trecho é amarelo, acima de
## "abrigo" é vermelho. O ponteiro e as marcas dão a leitura sem depender da cor.

const Desenho := preload("res://scripts/desenho.gd")
const Missao := preload("res://scripts/missao.gd")

var margem := 12.0
var maximo := 12
var medidor := 0.15
var _desenhado := ""


## Redesenha só quando o que se vê mudou.
func atualizar(nova_margem: float, novo_medidor: float) -> void:
	var chave := "%d/%d" % [roundi(nova_margem), roundi(novo_medidor * 100.0)]
	margem = nova_margem
	medidor = novo_medidor
	if chave != _desenhado:
		_desenhado = chave
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Desenho.FUNDO_TELA)
	var m := 7.0
	var larg := size.x - m * 2.0

	# Margem: ícone, "MARGEM", n/12 e a barra de células.
	Desenho.icone(self, "radiacao", Rect2(m, 5, 12, 12), Desenho.TEXTO, Desenho.FUNDO_TELA)
	Desenho.texto(self, tr("MARGEM").to_upper(), Vector2(m + 16, 5), 10, Desenho.TEXTO)
	Desenho.texto(self, "%d/%d" % [roundi(margem), maximo], Vector2(m, 2), 14, Desenho.TEXTO, larg,
		HORIZONTAL_ALIGNMENT_RIGHT, true)
	Desenho.celulas(self, Rect2(m, 20, larg, 7), margem, maximo)
	draw_line(Vector2(m, 31), Vector2(size.x - m, 31), Desenho.BORDA, 1.0)

	# Medidor: rótulo, trilho com as duas marcas, ponteiro.
	Desenho.texto(self, tr("MEDIDOR").to_upper(), Vector2(m, 32), 10, Desenho.TEXTO_SUAVE)
	var trilho := Rect2(m, 56, larg, 8)
	draw_rect(trilho, Desenho.CELULA_VAZIA)
	var x_valor := trilho.position.x + trilho.size.x * clampf(medidor, 0.0, 1.0)
	var x_atencao := trilho.position.x + trilho.size.x * Missao.LIMIAR_ATENCAO
	var x_abrigo := trilho.position.x + trilho.size.x * Missao.LIMIAR_ABRIGO
	# Preenchimento: neutro até "atenção"; amarelo de "atenção" a "abrigo"; vermelho acima.
	draw_rect(Rect2(trilho.position, Vector2(minf(x_valor, x_atencao) - trilho.position.x, trilho.size.y)), Desenho.TEXTO)
	if medidor > Missao.LIMIAR_ATENCAO:
		draw_rect(Rect2(Vector2(x_atencao, trilho.position.y), Vector2(minf(x_valor, x_abrigo) - x_atencao, trilho.size.y)),
			Desenho.AMARELO)
	if medidor > Missao.LIMIAR_ABRIGO:
		draw_rect(Rect2(Vector2(x_abrigo, trilho.position.y), Vector2(x_valor - x_abrigo, trilho.size.y)), Desenho.VERMELHO)
	# Marcas: uma risca em "atenção", duas em "abrigo".
	draw_line(Vector2(x_atencao, trilho.position.y - 3), Vector2(x_atencao, trilho.end.y + 3), Desenho.TEXTO, 1.0)
	draw_line(Vector2(x_abrigo - 1, trilho.position.y - 3), Vector2(x_abrigo - 1, trilho.end.y + 3), Desenho.TEXTO, 1.0)
	draw_line(Vector2(x_abrigo + 1, trilho.position.y - 3), Vector2(x_abrigo + 1, trilho.end.y + 3), Desenho.TEXTO, 1.0)
	# Ponteiro: triângulo em cima do trilho.
	draw_colored_polygon(PackedVector2Array([
		Vector2(x_valor - 4, trilho.position.y - 8), Vector2(x_valor + 4, trilho.position.y - 8),
		Vector2(x_valor, trilho.position.y - 1)]), Desenho.TEXTO)
	# Rótulos das marcas: "!" e "!!".
	Desenho.texto(self, "!", Vector2(x_atencao - 6, trilho.end.y + 1), 10, Desenho.TEXTO_SUAVE, 12, HORIZONTAL_ALIGNMENT_CENTER, true)
	Desenho.texto(self, "!!", Vector2(x_abrigo - 8, trilho.end.y + 1), 10, Desenho.TEXTO_SUAVE, 16, HORIZONTAL_ALIGNMENT_CENTER, true)
