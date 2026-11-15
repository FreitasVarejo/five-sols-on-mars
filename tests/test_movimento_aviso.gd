extends SceneTree
## Teste headless do movimento dos avisos (scripts/movimento_aviso.gd): as funções puras de tempo em
## deslocamento, escala, tremor, flash e selo.
## Roda com: godot --headless --path . --script tests/test_movimento_aviso.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Mov := preload("res://scripts/movimento_aviso.gd")

var falhas := 0
var total := 0


func _init() -> void:
	_entrada()
	_escala()
	_transformacao()
	_tremor()
	_flash()
	_selo()
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)


func _igual(obtido, esperado, nome: String) -> void:
	total += 1
	var bate := false
	if (obtido is float or obtido is int) and (esperado is float or esperado is int):
		bate = absf(float(obtido) - float(esperado)) < 1e-6
	else:
		bate = obtido == esperado
	if not bate:
		falhas += 1
		printerr("FALHOU: %s (obtido %s, esperado %s)" % [nome, str(obtido), str(esperado)])


func _verdade(valor: bool, nome: String) -> void:
	_igual(valor, true, nome)


## O card vem da esquerda: começa fora (a distância inteira para trás), passa um pouco do lugar e termina nele.
func _entrada() -> void:
	var dist := 300.0
	_igual(Mov.deslocamento(0.0, dist), -dist, "entrada: em t=0 o card está a uma distância inteira fora")
	_igual(Mov.deslocamento(Mov.ENTRADA_S, dist), 0.0, "entrada: em ENTRADA_S está no lugar")
	_igual(Mov.deslocamento(5.0, dist), 0.0, "entrada: muito depois, continua no lugar")
	_igual(Mov.deslocamento(-1.0, dist), -dist, "entrada: tempo negativo vale t=0")
	var passou := false
	var antes_do_fim := true
	var anterior := -INF
	for i in 31:
		var d := Mov.deslocamento(i * 0.01, dist)
		if d > 0.0:
			passou = true  # o overshoot do TRANS_BACK passa do lugar
		if i * 0.01 < 0.1 and d < anterior:
			antes_do_fim = false  # na primeira parte só anda para frente
		anterior = d
	_verdade(passou, "entrada: tem overshoot (passa do lugar antes de assentar)")
	_verdade(antes_do_fim, "entrada: no começo só avança")
	_verdade(Mov.deslocamento(0.05, dist) > -dist * 0.5, "entrada: EASE_OUT, aos 0,05 s já andou mais da metade")


## A escala começa em 0,7, é elástica (passa de 1) e termina em 1.
func _escala() -> void:
	_igual(Mov.escala(0.0), Mov.ESCALA_INICIAL, "escala: começa em 0,7")
	_igual(Mov.escala(Mov.ESCALA_S), 1.0, "escala: termina em 1")
	_igual(Mov.escala(3.0), 1.0, "escala: depois de acabar, 1")
	var max_escala := 0.0
	for i in 36:
		max_escala = maxf(max_escala, Mov.escala(i * 0.01))
	_verdade(max_escala > 1.0, "escala: o elástico passa de 1")
	_verdade(max_escala < 1.3, "escala: o elástico não exagera")
	_verdade(Mov.entrada_terminou(Mov.DURACAO_ENTRADA_S), "entrada_terminou: no tempo")
	_verdade(not Mov.entrada_terminou(Mov.DURACAO_ENTRADA_S - 0.01), "entrada_terminou: antes não")


## A transformação: no começo põe o card fora e menor; no fim é a identidade; o pivô fica parado.
func _transformacao() -> void:
	var pivo := Vector2(200.0, 100.0)
	var fim := Mov.transformacao(Mov.DURACAO_ENTRADA_S, pivo, 300.0)
	_verdade(fim.is_equal_approx(Transform2D.IDENTITY), "transformacao: no fim é a identidade")
	var ini := Mov.transformacao(0.0, pivo, 300.0)
	var centro := ini * pivo
	_igual(centro.x, pivo.x - 300.0, "transformacao: o pivô começa 300 px à esquerda")
	_igual(centro.y, pivo.y, "transformacao: o pivô não sobe nem desce")
	var canto := ini * (pivo + Vector2(100.0, 0.0))
	_igual(canto.x - centro.x, 70.0, "transformacao: um ponto a 100 px do pivô fica a 70 px (escala 0,7)")
	# Com a distância igual ao x do fim do card, em t=0 ele está todo à esquerda da tela (x < 0).
	var r := Rect2(372.0, 70.0, 236.0, 100.0)
	var t0 := Mov.transformacao(0.0, r.get_center(), r.end.x)
	_verdade((t0 * r.end).x < 0.0, "transformacao: em t=0 o card está todo fora, à esquerda da tela")


## O tremor: 6 tremidas de ±7 px em 0,05 s, sempre voltando a 0.
func _tremor() -> void:
	_igual(Mov.tremor(0.0), 0.0, "tremor: começa em 0")
	_igual(Mov.tremor(-0.1), 0.0, "tremor: antes de começar, 0")
	_igual(Mov.tremor(Mov.DURACAO_TREMOR_S), 0.0, "tremor: acabou, 0")
	_igual(Mov.tremor(Mov.DURACAO_TREMOR_S + 1.0), 0.0, "tremor: muito depois, 0")
	_igual(Mov.DURACAO_TREMOR_S, 0.35, "tremor: dura 7 passos de 0,05 s")
	var cruzamentos := 0
	var maior := 0.0
	var anterior := 0.0
	for i in 351:
		var x := Mov.tremor(i * 0.001)
		maior = maxf(maior, absf(x))
		if i > 0 and signf(x) != 0.0 and signf(anterior) != 0.0 and signf(x) != signf(anterior):
			cruzamentos += 1
		if signf(x) != 0.0:
			anterior = x
	_igual(maior, Mov.TREMOR_AMPLITUDE, "tremor: o pico é a amplitude")
	_igual(cruzamentos, 5, "tremor: 6 tremidas trocam de lado 5 vezes")
	# Os pontos de virada: +A em 0,05; -A em 0,10; +A em 0,15; ... -A em 0,30; 0 em 0,35.
	_igual(Mov.tremor(0.05), Mov.TREMOR_AMPLITUDE, "tremor: 1ª virada em +A")
	_igual(Mov.tremor(0.10), -Mov.TREMOR_AMPLITUDE, "tremor: 2ª virada em -A")
	_igual(Mov.tremor(0.30), -Mov.TREMOR_AMPLITUDE, "tremor: 6ª virada em -A")
	_igual(Mov.tremor(0.325), -Mov.TREMOR_AMPLITUDE / 2.0, "tremor: voltando ao repouso")


## Um flash só: no pico FLASH_ALFA, depois cai a 0, e nunca passa do translúcido.
func _flash() -> void:
	_igual(Mov.flash_alfa(0.0), Mov.FLASH_ALFA, "flash: o pico é FLASH_ALFA")
	_verdade(Mov.FLASH_ALFA <= 0.35, "flash: translúcido")
	_verdade(Mov.FLASH_S <= 0.5, "flash: curto")
	_igual(Mov.flash_alfa(Mov.FLASH_S), 0.0, "flash: acabou")
	_igual(Mov.flash_alfa(Mov.FLASH_S + 1.0), 0.0, "flash: depois, nada")
	_igual(Mov.flash_alfa(-0.1), 0.0, "flash: antes, nada")
	var anterior := 2.0
	var cai := true
	var subidas := 0
	for i in 41:
		var a := Mov.flash_alfa(i * 0.01)
		if a > anterior + 1e-9:
			cai = false
			subidas += 1
		anterior = a
	_verdade(cai, "flash: só cai, não repica (um flash só, bem abaixo de 3 por segundo)")
	_igual(subidas, 0, "flash: nenhuma subida depois do pico")


## O selo: entra de baixo, sobe e some em ~1,5 s; no fim está invisível e no alto.
func _selo() -> void:
	_igual(Mov.SELO_S, 1.5, "selo: dura 1,5 s")
	_igual(Mov.selo_alfa(0.0), 1.0, "selo: nasce inteiro")
	_igual(Mov.selo_alfa(1.0), 1.0, "selo: aos 1,0 s ainda inteiro")
	_verdade(Mov.selo_alfa(1.3) > 0.0 and Mov.selo_alfa(1.3) < 1.0, "selo: aos 1,3 s está sumindo")
	_igual(Mov.selo_alfa(Mov.SELO_S), 0.0, "selo: some em 1,5 s")
	_igual(Mov.selo_alfa(2.0), 0.0, "selo: depois de 1,5 s, nada")
	_igual(Mov.selo_dy(0.0), Mov.SELO_ENTRA, "selo: entra de baixo")
	_igual(Mov.selo_dy(Mov.SELO_S), -Mov.SELO_SOBE, "selo: termina em cima")
	_verdade(Mov.selo_dy(1.0) < Mov.selo_dy(Mov.ENTRADA_S), "selo: depois de entrar, sobe")
	var anterior := Mov.selo_dy(Mov.ENTRADA_S)
	var sobe := true
	for i in range(31, 151):
		var dy := Mov.selo_dy(i * 0.01)
		if dy > anterior + 1e-9:
			sobe = false
		anterior = dy
	_verdade(sobe, "selo: depois da entrada só sobe")
