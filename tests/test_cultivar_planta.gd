extends SceneTree
## Teste headless do minigame "Cultivar a planta" (scripts/minigames/cultivar_planta.gd): diagnosticar e tratar.
## Roda com: godot --headless --path . --script tests/test_cultivar_planta.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Planta := preload("res://scripts/minigames/cultivar_planta.gd")
const Desenho := preload("res://scripts/desenho.gd")
const Som := preload("res://scripts/som.gd")

const AREAS := [Rect2(0, 0, 640, 360), Rect2(40, 30, 368, 207), Rect2(0, 0, 320, 180)]
## O caminho certo de cada problema (o mofo tem dois, em qualquer ordem).
const CERTO := {"seca": [["regador"]], "encharcada": [["ventilador"]],
	"mofo": [["tesoura", "ventilador"], ["ventilador", "tesoura"]]}

var falhas := 0
var total := 0
var _concluidos := 0


## Um som de mentira: guarda os nomes pedidos.
class SomFalso:
	var historico: Array = []

	func tocar(nome: String) -> void:
		historico.append(nome)


func _init() -> void:
	_tudo()


func _tudo() -> void:
	_sorteio()
	_estado_inicial()
	_caminho_certo_conclui()
	_mofo_nas_duas_ordens()
	_ventilador_a_mais_no_mofo()
	_erros_pioram_e_desfazem()
	_limites_e_a_planta_nunca_morre()
	_ferramenta_antes_da_luz()
	_luz_de_mao_unica()
	_tesoura_sem_mofo()
	_toques_ignorados_enquanto_cresce()
	_progresso_e_conclusao()
	_estado_no_quadro_do_toque()
	_retorno_visual()
	for area in AREAS:
		_toque_pelo_ponteiro(area)
		_botoes_grandes(area)
	_reinicio()
	_cabe_em_dez_segundos()
	_sons()
	await _cores()
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)


func _igual(obtido, esperado, nome: String) -> void:
	total += 1
	if obtido != esperado:
		falhas += 1
		printerr("FALHOU: %s (obtido %s, esperado %s)" % [nome, str(obtido), str(esperado)])


func _verdade(cond: bool, nome: String) -> void:
	_igual(cond, true, nome)


# --- ajudantes -----------------------------------------------------------------

## Uma peça nova com o problema `problema`, na área `area`. Fora da árvore: o tempo anda à mão.
func _nova(problema: String, area: Rect2 = Rect2(0, 0, 368, 207)) -> Control:
	var p: Control = Planta.new()
	p.configurar(area, 20.0, false)
	p.definir_problema(problema)
	_concluidos = 0
	p.concluido.connect(func() -> void: _concluidos += 1)
	return p


func _tempo(p: Control, segundos: float) -> void:
	var feito := 0.0
	while feito < segundos - 0.0001:
		p.avancar(1.0 / 60.0)
		feito += 1.0 / 60.0


## A peça com a luz acesa, pronta para as ferramentas.
func _acesa(problema: String, area: Rect2 = Rect2(0, 0, 368, 207)) -> Control:
	var p := _nova(problema, area)
	p.acender_luz()
	return p


func _clicar(p: Control, pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = pos
	p._gui_input(ev)


func _estado(p: Control) -> Array:
	return [p.umidade(), p.mofo()]


## Usa as ferramentas de `caminho` em ordem, com 0,3 s entre os toques.
func _usar_todas(p: Control, caminho: Array) -> void:
	for f: String in caminho:
		p.usar(f)
		_tempo(p, 0.3)


# --- casos ---------------------------------------------------------------------

func _sorteio() -> void:
	_igual(Planta.sorteio(7), Planta.sorteio(7), "sorteio: mesma semente, mesmo resultado")
	var vistos := {}
	for n in 60:
		var s := Planta.sorteio(n)
		_verdade(s["problema"] in Planta.PROBLEMAS, "sorteio %d: um problema da lista" % n)
		vistos[s["problema"]] = true
	_igual(vistos.size(), 3, "sorteio: os três problemas aparecem")
	# Mesma semente, mesmo problema na peça.
	var a: Control = Planta.new()
	var b: Control = Planta.new()
	a.semente(5)
	b.semente(5)
	_igual(a.problema(), b.problema(), "mesma semente: mesmo problema")
	_igual(a.problema(), Planta.sorteio(5)["problema"], "o problema é o do sorteio")
	_igual(a.sorteio_atual(), Planta.sorteio(5), "sorteio_atual é o do sorteio")
	a.free()
	b.free()


func _estado_inicial() -> void:
	var esperado := {"seca": [-1, 0], "encharcada": [1, 0], "mofo": [1, 1]}
	for nome: String in Planta.PROBLEMAS:
		var p := _nova(nome)
		_igual(p.problema(), nome, "%s: o problema" % nome)
		_igual(_estado(p), esperado[nome], "%s: umidade e mofo de partida" % nome)
		_verdade(not p.luz_acesa(), "%s: abre sob a luz rosa" % nome)
		_igual(p.progresso(), 0.0, "%s: progresso 0 no início" % nome)
		_verdade(not p.ocupada() and not p.concluida(), "%s: livre no início" % nome)
		p.free()


func _caminho_certo_conclui() -> void:
	for nome: String in Planta.PROBLEMAS:
		for caminho: Array in CERTO[nome]:
			var p := _acesa(nome)
			_usar_todas(p, caminho.slice(0, caminho.size() - 1))
			_igual(_concluidos, 0, "%s %s: antes do último passo, sem sinal" % [nome, caminho])
			p.usar(caminho[caminho.size() - 1])
			_tempo(p, Planta.T_ATRASO_CRESCER + Planta.T_CRESCER - 0.05)
			_igual(_concluidos, 0, "%s %s: o crescimento ainda não terminou" % [nome, caminho])
			_tempo(p, 0.2)
			_igual(_concluidos, 1, "%s %s: concluiu uma vez" % [nome, caminho])
			_verdade(p.concluida(), "%s %s: concluída" % [nome, caminho])
			_igual(_estado(p), [0, 0], "%s %s: curada" % [nome, caminho])
			_tempo(p, 3.0)
			_igual(_concluidos, 1, "%s %s: o sinal não se repete" % [nome, caminho])
			p.free()


func _mofo_nas_duas_ordens() -> void:
	# Tesoura primeiro: o mofo sai e sobra a encharcada.
	var a := _acesa("mofo")
	_igual(a.usar("tesoura"), "melhor", "mofo: a tesoura melhora")
	_igual(_estado(a), [1, 0], "mofo: cortado, sobra a encharcada")
	_verdade(not a.ocupada(), "mofo: ainda não é o fim")
	_igual(a.usar("ventilador"), "melhor", "mofo: o ventilador conclui")
	_verdade(a.ocupada(), "mofo: crescendo")
	# Ventilador primeiro: a umidade zera e o mofo fica (1), até a tesoura.
	var b := _acesa("mofo")
	_igual(b.usar("ventilador"), "melhor", "mofo: o ventilador melhora")
	_igual(_estado(b), [0, 1], "mofo: seca a umidade, o mofo fica")
	_verdade(not b.ocupada(), "mofo: com mofo a peça não termina")
	_igual(b.usar("tesoura"), "melhor", "mofo: a tesoura conclui")
	_verdade(b.ocupada(), "mofo: crescendo")
	a.free()
	b.free()


func _ventilador_a_mais_no_mofo() -> void:
	# A história das zínias de 2015-16: no mofo, ventilador e ventilador de novo seca demais; o regador desfaz.
	var p := _acesa("mofo")
	p.usar("ventilador")
	_igual(p.usar("ventilador"), "pior", "mofo: o ventilador a mais piora")
	_igual(_estado(p), [-1, 1], "mofo: secou demais, e o mofo ficou")
	_igual(p.usar("regador"), "melhor", "mofo: o regador desfaz")
	_igual(_estado(p), [0, 1], "mofo: de volta a um passo do fim")
	p.usar("tesoura")
	_verdade(p.ocupada(), "mofo: depois do erro desfeito, conclui")
	p.free()


func _erros_pioram_e_desfazem() -> void:
	# Seca: o ventilador piora (a seca de -2), o regador desfaz.
	var s := _acesa("seca")
	_igual(s.usar("ventilador"), "pior", "seca: o ventilador piora")
	_igual(_estado(s), [-2, 0], "seca: -2")
	_igual(s.usar("regador"), "melhor", "seca: o regador desfaz")
	_igual(_estado(s), [-1, 0], "seca: de volta")
	s.free()
	# Encharcada: o regador piora (+2), o ventilador desfaz.
	var e := _acesa("encharcada")
	_igual(e.usar("regador"), "pior", "encharcada: o regador piora")
	_igual(_estado(e), [2, 0], "encharcada: +2")
	_igual(e.usar("ventilador"), "melhor", "encharcada: o ventilador desfaz")
	_igual(_estado(e), [1, 0], "encharcada: de volta")
	e.free()
	# Mofo: o regador espalha (+2, mofo 2); o ventilador desfaz o espalhado, e a tesoura corta de uma vez.
	var m := _acesa("mofo")
	_igual(m.usar("regador"), "pior", "mofo: o regador espalha")
	_igual(_estado(m), [2, 2], "mofo: +2 e mofo 2")
	_igual(m.usar("ventilador"), "melhor", "mofo: o ventilador volta")
	_igual(_estado(m), [1, 1], "mofo: o espalhado volta a 1 quando seca")
	m.usar("regador")
	_igual(m.usar("tesoura"), "melhor", "mofo espalhado: a tesoura corta")
	_igual(_estado(m), [2, 0], "mofo espalhado: cortado fica a encharcada +2")
	_igual(m.usar("regador"), "nada", "encharcada +2: o regador não passa do limite")
	_igual(_estado(m), [2, 0], "o mofo cortado não volta (só espalha com mofo)")
	m.free()


func _limites_e_a_planta_nunca_morre() -> void:
	for nome: String in Planta.PROBLEMAS:
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for volta in 20:
			var p := _acesa(nome)
			var passos := 0
			# Toques ao acaso (a criança errando à vontade), sem nunca sair dos limites.
			while not p.ocupada() and passos < 60:
				p.usar(Planta.FERRAMENTAS[rng.randi_range(0, 2)])
				passos += 1
				_verdade(p.umidade() >= Planta.UMIDADE_MIN and p.umidade() <= Planta.UMIDADE_MAX, "%s: a umidade fica entre -2 e +2" % nome)
				_verdade(p.mofo() >= 0 and p.mofo() <= Planta.MOFO_MAX, "%s: o mofo fica entre 0 e 2" % nome)
				if p.mofo() > 0:
					_igual(p.mofo(), 2 if p.umidade() >= 2 else 1, "%s: com mofo, vale 2 só com a umidade em +2" % nome)
			# Em qualquer ponto o caminho certo chega ao fim: a planta nunca morre.
			var certos := 0
			while not p.ocupada() and certos < 8:
				if p.mofo() > 0:
					p.usar("tesoura")
				elif p.umidade() > 0:
					p.usar("ventilador")
				else:
					p.usar("regador")
				certos += 1
			_verdade(p.ocupada(), "%s: dos toques ao acaso, o caminho certo ainda conclui (%d passos)" % [nome, certos])
			p.free()


func _ferramenta_antes_da_luz() -> void:
	for nome: String in Planta.PROBLEMAS:
		var p := _nova(nome)
		var antes := _estado(p)
		for f: String in Planta.FERRAMENTAS:
			_igual(p.usar(f), "", "%s: %s antes da luz é ignorado" % [nome, f])
		_igual(_estado(p), antes, "%s: a planta não muda antes da luz" % nome)
		_verdade(not p.luz_acesa() and not p.ocupada(), "%s: segue sob a luz rosa" % nome)
		_igual(p.usar("martelo"), "", "%s: o que não é ferramenta é ignorado" % nome)
		p.acender_luz()
		_verdade(p.usar("regador") != "", "%s: com a luz, a ferramenta vale" % nome)
		p.free()


func _luz_de_mao_unica() -> void:
	var p := _nova("seca")
	_igual(p._luz, 0.0, "a luz começa apagada")
	_verdade(p.acender_luz(), "o botão da luz acende")
	_verdade(p.luz_acesa(), "luz acesa")
	_tempo(p, Planta.T_LUZ / 2.0)
	_verdade(absf(p._luz - 0.5) < 0.05, "a luz sobe em 0,35 s: metade no meio")
	_tempo(p, Planta.T_LUZ)
	_igual(p._luz, 1.0, "a luz chega ao branco")
	_verdade(not p.acender_luz(), "é de mão única: não se apaga nem se acende de novo")
	_verdade(p.luz_acesa(), "segue acesa")
	p.free()


func _tesoura_sem_mofo() -> void:
	for nome: String in ["seca", "encharcada"]:
		var p := _acesa(nome)
		var antes := _estado(p)
		_igual(p.usar("tesoura"), "nada", "%s: a tesoura sem mofo corta o ar" % nome)
		_igual(_estado(p), antes, "%s: nada muda" % nome)
		_verdade(not p.ocupada(), "%s: a peça segue livre" % nome)
		p.free()
	var m := _acesa("mofo")
	m.usar("tesoura")
	_igual(m.usar("tesoura"), "nada", "mofo já cortado: a tesoura corta o ar")
	_igual(_estado(m), [1, 0], "mofo já cortado: nada muda")
	m.free()


func _toques_ignorados_enquanto_cresce() -> void:
	var p := _acesa("encharcada")
	p.usar("ventilador")
	_verdade(p.ocupada(), "crescendo")
	_igual(p.usar("regador"), "", "enquanto cresce, a ferramenta é ignorada")
	_igual(p.usar("ventilador"), "", "enquanto cresce, outra ferramenta também")
	_verdade(not p.acender_luz(), "enquanto cresce, a luz também")
	_igual(_estado(p), [0, 0], "enquanto cresce, a planta não muda")
	_tempo(p, Planta.T_ATRASO_CRESCER + Planta.T_CRESCER + 0.1)
	_verdade(p.concluida(), "concluída")
	_igual(p.usar("regador"), "", "concluída, a ferramenta é ignorada")
	_igual(_estado(p), [0, 0], "concluída, a planta não muda")
	_igual(_concluidos, 1, "só um sinal")
	p.free()


func _progresso_e_conclusao() -> void:
	var p := _acesa("seca")
	_igual(p.progresso(), 0.0, "progresso 0 antes do acerto")
	p.usar("ventilador")  # erra
	_tempo(p, 1.0)
	_igual(p.progresso(), 0.0, "progresso 0 depois de um erro")
	p.usar("regador")  # -2 -> -1
	p.usar("regador")  # -1 -> 0: o acerto final
	_verdade(p.ocupada(), "acertou")
	_igual(p.progresso(), 0.0, "progresso 0 no quadro do acerto final")
	_tempo(p, Planta.T_ATRASO_CRESCER - 0.02)
	_igual(p.progresso(), 0.0, "progresso 0 enquanto a água cai")
	var antes := 0.0
	var crescente := true
	for i in 60:
		_tempo(p, 0.02)
		if p.progresso() < antes:
			crescente = false
		antes = p.progresso()
	_verdade(crescente, "o progresso só sobe durante o crescimento")
	_tempo(p, Planta.T_CRESCER)
	_igual(p.progresso(), 1.0, "progresso 1 no fim")
	p.free()


func _estado_no_quadro_do_toque() -> void:
	# Nenhum avancar entre o toque e a leitura: o estado e o retorno já mudaram.
	var p := _acesa("seca")
	var r: String = p.usar("ventilador")
	_igual(r, "pior", "o retorno vem no próprio toque")
	_igual(p.umidade(), -2, "a umidade mudou no quadro do toque")
	_verdade(not p._anim.is_empty() and p._anim["id"] == "ventilador", "a ferramenta já está animando")
	_verdade(not p._reacao.is_empty() and p._reacao["tipo"] == "pior", "a reação já começou")
	# O sintoma visível anda até o novo valor em 0,25 s.
	_tempo(p, Planta.T_VISIVEL + 0.02)
	_igual(p._u_vis, -2.0, "o sintoma chega ao novo valor em 0,25 s")
	p.free()
	var q := _acesa("encharcada")
	q.usar("ventilador")
	_igual(_estado(q), [0, 0], "o acerto final também muda no quadro do toque")
	_verdade(q.ocupada(), "e a peça já está ocupada")
	q.free()


func _retorno_visual() -> void:
	# melhor: as folhas dão o pulo; pior: a planta sacode; nada: a tesoura abre e fecha no ar. Tudo em 0,5 s.
	var a := _acesa("encharcada")
	a.usar("regador")
	_igual(a._reacao["tipo"], "pior", "pior: a reação")
	var m := _acesa("mofo")
	m.usar("tesoura")
	_igual(m._reacao["tipo"], "melhor", "melhor: a reação")
	_verdade(m._anim["cortou"], "a tesoura cortou o mofo")
	var s := _acesa("seca")
	s.usar("tesoura")
	_igual(s._reacao["tipo"], "nada", "nada: a reação")
	_igual(s._anim["id"], "tesoura", "nada: a tesoura anima no ar")
	_verdade(not s._anim["cortou"], "nada: sem corte")
	for p in [a, m, s]:
		_tempo(p, Planta.T_REACAO + 0.02)
		_verdade(p._reacao.is_empty(), "a reação acaba em 0,5 s")
		_verdade(p._anim.is_empty(), "a ferramenta acaba em 0,45 s")
		p.free()


func _toque_pelo_ponteiro(area: Rect2) -> void:
	var nome_area := "%dx%d" % [area.size.x, area.size.y]
	var p := _nova("mofo", area)
	# Uma ferramenta apagada ignora o toque.
	_clicar(p, p.retangulo_da_ferramenta("tesoura").get_center())
	_igual(_estado(p), [1, 1], "%s: toque na ferramenta apagada é ignorado" % nome_area)
	_clicar(p, Vector2(1.0, 1.0))
	_verdade(not p.luz_acesa(), "%s: toque fora dos botões não faz nada" % nome_area)
	_clicar(p, p.retangulo_da_luz().get_center())
	_verdade(p.luz_acesa(), "%s: toque na luz acende" % nome_area)
	_clicar(p, p.retangulo_da_ferramenta("tesoura").get_center())
	_igual(_estado(p), [1, 0], "%s: toque na tesoura corta o mofo" % nome_area)
	# A folga de 2 px: 1,5 px fora do botão ainda vale; 3 px fora, não.
	var rv: Rect2 = p.retangulo_da_ferramenta("ventilador")
	_clicar(p, Vector2(rv.position.x - 3.0, rv.get_center().y))
	_igual(_estado(p), [1, 0], "%s: 3 px fora do botão não vale" % nome_area)
	_clicar(p, Vector2(rv.position.x - 1.5, rv.get_center().y))
	_igual(_estado(p), [0, 0], "%s: 1,5 px fora do botão vale (folga de 2 px)" % nome_area)
	_verdade(p.ocupada(), "%s: a peça concluiu pelo ponteiro" % nome_area)
	p.free()
	# O regador, por toque, em outra peça.
	var q := _acesa("seca", area)
	_clicar(q, q.retangulo_da_ferramenta("regador").get_center())
	_verdade(q.ocupada(), "%s: o regador pelo ponteiro cura a seca" % nome_area)
	q.free()


func _botoes_grandes(area: Rect2) -> void:
	var nome_area := "%dx%d" % [area.size.x, area.size.y]
	var p := _nova("seca", area)
	var todos: Array = [["luz", p.retangulo_da_luz()]]
	for f: String in Planta.FERRAMENTAS:
		todos.append([f, p.retangulo_da_ferramenta(f)])
	var tela := Rect2(Vector2.ZERO, area.size)
	for par: Array in todos:
		var r: Rect2 = par[1]
		_verdade(r.size.x >= Planta.LADO_MIN and r.size.y >= Planta.LADO_MIN, "%s: o botão %s tem ao menos 24 px (%s)" % [nome_area, par[0], str(r.size)])
		_verdade(tela.encloses(r), "%s: o botão %s cabe na área" % [nome_area, par[0]])
		_verdade(not r.intersects(p.retangulo_da_camara()), "%s: o botão %s não cobre a câmara" % [nome_area, par[0]])
	for i in todos.size():
		for j in range(i + 1, todos.size()):
			_verdade(not todos[i][1].grow(Planta.FOLGA_TOQUE).intersects(todos[j][1].grow(Planta.FOLGA_TOQUE)), "%s: %s e %s não se sobrepõem, nem com a folga" % [nome_area, todos[i][0], todos[j][0]])
	if area.size == Vector2(368, 207):
		_igual(p.retangulo_da_luz().size, Vector2(50, 50), "área real: o botão da luz tem 50 px")
		for f: String in Planta.FERRAMENTAS:
			_igual(p.retangulo_da_ferramenta(f).size, Vector2(50, 50), "área real: o botão %s tem 50 px" % f)
	_verdade(p.retangulo_da_camara().size.x >= 100.0 and p.retangulo_da_camara().size.y >= 100.0, "%s: a câmara tem tamanho para a planta" % nome_area)
	p.free()


func _reinicio() -> void:
	var p := _acesa("mofo")
	p.usar("tesoura")
	p.usar("ventilador")
	_tempo(p, 3.0)
	_verdade(p.concluida() and _concluidos == 1, "concluída antes do reinício")
	p.configurar(Rect2(0, 0, 640, 360), 20.0, false)
	_verdade(not p.concluida() and not p.ocupada(), "o configurar reinicia a peça")
	_verdade(not p.luz_acesa(), "reiniciada: a luz apagada")
	_igual(p.problema(), "mofo", "reiniciada: o mesmo problema")
	_igual(_estado(p), [1, 1], "reiniciada: o estado de partida")
	_igual(p.progresso(), 0.0, "reiniciada: progresso 0")
	p.acender_luz()
	p.usar("tesoura")
	p.usar("ventilador")
	_tempo(p, 3.0)
	_igual(_concluidos, 2, "reiniciada, conclui e avisa de novo")
	# definir_problema reinicia com o problema novo; nome inválido não muda nada.
	p.definir_problema("seca")
	_igual(p.problema(), "seca", "definir_problema troca o problema")
	_igual(_estado(p), [-1, 0], "definir_problema reinicia")
	_verdade(not p.luz_acesa() and not p.concluida(), "definir_problema reinicia a luz e o fim")
	p.definir_problema("lava")
	_igual(p.problema(), "seca", "problema inválido é ignorado")
	p.free()


## Quantas ferramentas faltam no mínimo, depois da luz e de `prefixo` (toques já dados), em `nome`. Reproduz os
## toques em peças novas (o modelo é o da peça, não uma cópia).
func _minimo_restante(nome: String, prefixo: Array) -> int:
	for fundo in range(0, 7):
		var seqs: Array = [[]]
		for nivel in fundo:
			var novas: Array = []
			for sq: Array in seqs:
				for f: String in Planta.FERRAMENTAS:
					novas.append(sq + [f])
			seqs = novas
		for sq: Array in seqs:
			var p := _acesa(nome)
			for f: String in prefixo:
				p.usar(f)
			for f: String in sq:
				p.usar(f)
			var fim: bool = p.ocupada()
			p.free()
			if fim:
				return fundo
	return 99


func _cabe_em_dez_segundos() -> void:
	# O pior caminho certo: luz + ferramentas (0,6 s por toque), a espera da água e o crescimento. Vale para o
	# caminho sem erro e para o caminho depois de um erro (qualquer ferramenta que piora).
	var pior := 0
	for nome: String in Planta.PROBLEMAS:
		var sem_erro := _minimo_restante(nome, [])
		_verdade(sem_erro <= 2, "%s: sem erro, no máximo 2 ferramentas (%d)" % [nome, sem_erro])
		pior = maxi(pior, sem_erro)
		for f: String in Planta.FERRAMENTAS:
			var p := _acesa(nome)
			var r: String = p.usar(f)
			p.free()
			if r != "pior":
				continue
			var depois := 1 + _minimo_restante(nome, [f])
			pior = maxi(pior, depois)
			_verdade(depois <= 4, "%s: depois de errar com %s, no máximo 4 ferramentas (%d)" % [nome, f, depois])
	var segundos := 0.6 * (1 + pior) + Planta.T_ATRASO_CRESCER + Planta.T_CRESCER
	_verdade(segundos <= 10.0, "o pior caminho certo cabe em 10 s (%.2f s com %d ferramentas)" % [segundos, pior])


func _sons() -> void:
	# Os sons existem, são curtos e estão registrados.
	var nomes := ["estufa_luz", "estufa_regar", "estufa_ventilar", "estufa_cortar", "estufa_melhorou", "estufa_piorou", "estufa_ploc"]
	for n: String in nomes:
		_verdade(Som.SONS.has(n), "%s está em SONS" % n)
		var teto := 0.5 if n == "estufa_ploc" else 0.4
		_verdade(Som.SONS[n].get_length() <= teto + 0.001, "%s dura no máximo %.1f s" % [n, teto])
	# A peça toca o som de cada coisa (o som é injetado: `som`).
	var fs := SomFalso.new()
	var p := _nova("mofo")
	p.som = fs
	p.usar("tesoura")
	_igual(fs.historico, [], "ferramenta antes da luz: sem som")
	p.acender_luz()
	_igual(fs.historico, ["estufa_luz"], "a luz toca o som dela")
	p.usar("regador")  # pior
	_igual(fs.historico.slice(1), ["estufa_regar"], "o regador toca o som dele")
	_tempo(p, 0.2)
	_igual(fs.historico.slice(2), ["estufa_piorou"], "o erro toca o grave, logo depois")
	p.usar("ventilador")  # melhor
	_tempo(p, 0.2)
	_igual(fs.historico.slice(3), ["estufa_ventilar", "estufa_melhorou"], "o ventilador e o blip de melhor")
	p.usar("tesoura")  # corta e conclui? (2,2)->(1,1)->(1,0): ainda não
	_tempo(p, 0.2)
	_igual(fs.historico.slice(5), ["estufa_cortar", "estufa_melhorou"], "a tesoura e o blip de melhor")
	p.usar("tesoura")  # no ar
	_tempo(p, 0.2)
	_igual(fs.historico.slice(7), ["estufa_cortar"], "a tesoura no ar não toca melhor nem pior")
	p.usar("ventilador")  # o acerto final
	_igual(fs.historico.slice(8), ["estufa_ventilar"], "o acerto final toca a ferramenta na hora")
	_tempo(p, Planta.T_ATRASO_CRESCER - 0.05)
	_igual(fs.historico.slice(9), [], "o ploc espera a água cair")
	_tempo(p, 0.1)
	_igual(fs.historico.slice(9), ["estufa_ploc"], "o ploc toca no fim da espera")
	_tempo(p, 3.0)
	_igual(fs.historico.slice(10), [], "e só uma vez")
	p.free()
	# Dois toques seguidos, sem tempo entre eles: o som do primeiro não se perde.
	var r := _acesa("seca")
	var fr := SomFalso.new()
	r.som = fr
	r.usar("ventilador")  # pior
	r.usar("regador")  # melhor, logo em seguida
	_tempo(r, 0.2)
	_igual(fr.historico, ["estufa_ventilar", "estufa_piorou", "estufa_regar", "estufa_melhorou"], "toques rápidos: cada retorno toca")
	r.free()
	# Sem som injetado nada quebra.
	var q := _acesa("seca")
	q.usar("regador")
	_tempo(q, 3.0)
	_verdade(q.concluida(), "sem som, a peça funciona igual")
	q.free()


## Nenhum desenho usa cor reservada: vermelho, amarelo e azul nunca; verde só nos botões. A peça desenha de
## verdade (precisa do quadro), então este teste anda em quadros.
func _cores() -> void:
	var p: Control = Planta.new()
	p.registrar_cores = true
	p.set_process(false)
	root.add_child(p)
	for area in AREAS:
		p.configurar(area, 20.0, false)
		for nome: String in Planta.PROBLEMAS:
			p.definir_problema(nome)
			await _desenhar(p)  # sob a luz rosa
			p.acender_luz()
			_tempo(p, 0.6)
			await _desenhar(p)  # a luz branca, com o sintoma
			var erro: String = {"seca": "ventilador", "encharcada": "regador", "mofo": "regador"}[nome]
			p.usar(erro)
			_tempo(p, 0.1)
			await _desenhar(p)  # o erro, com a ferramenta em ação
			_tempo(p, 0.6)
			await _desenhar(p)  # o sintoma piorado (mofo espalhado, poça, seca)
			for f: String in ["tesoura", "ventilador", "regador"]:  # um pouco de cada ferramenta
				p.usar(f)
				_tempo(p, 0.2)
				await _desenhar(p)
			_usar_ate_curar(p)
			_tempo(p, 0.5)
			await _desenhar(p)  # crescendo
			_tempo(p, 2.0)
			await _desenhar(p)  # o fim, com o check
	var cores: Dictionary = p.cores_usadas()
	var reservadas_fora := {"vermelho": Desenho.VERMELHO, "amarelo": Desenho.AMARELO, "azul": Desenho.AZUL}
	var verdes := {"VERDE": Desenho.VERDE, "VERDE_ESCURO": Desenho.VERDE_ESCURO, "VERDE_CLARO": Desenho.VERDE_CLARO}
	_verdade(cores["cena"].size() > 20 and cores["botao"].size() > 5, "o desenho registrou as cores (%d da cena, %d dos botões)" % [cores["cena"].size(), cores["botao"].size()])
	for onde: String in ["cena", "botao"]:
		for c: Color in cores[onde]:
			for nome: String in reservadas_fora:
				_verdade(not c.is_equal_approx(reservadas_fora[nome]), "%s: nenhuma cor %s da paleta" % [onde, nome])
	for c: Color in cores["cena"]:
		for nome: String in verdes:
			_verdade(not c.is_equal_approx(verdes[nome]), "a cena (planta, câmara, LEDs, check) nunca usa Desenho.%s" % nome)
	var tem_verde := false
	for c: Color in cores["botao"]:
		if c.is_equal_approx(Desenho.VERDE):
			tem_verde = true
	_verdade(tem_verde, "o verde aparece nos botões")
	var tem_texto := false
	for c: Color in cores["cena"]:
		if c.is_equal_approx(Desenho.TEXTO):
			tem_texto = true  # o check do fim e as faíscas
	_verdade(tem_texto, "o check do fim é TEXTO")
	p.queue_free()


func _desenhar(p: Control) -> void:
	p.queue_redraw()
	await process_frame
	await process_frame


## Leva a planta ao fim pelo caminho certo (a partir de onde estiver).
func _usar_ate_curar(p: Control) -> void:
	var guarda := 0
	while not p.ocupada() and guarda < 10:
		if p.mofo() > 0:
			p.usar("tesoura")
		elif p.umidade() > 0:
			p.usar("ventilador")
		else:
			p.usar("regador")
		guarda += 1
