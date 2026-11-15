extends SceneTree
## Teste headless dos avisos com o movimento do primo ligados ao terminal (scripts/terminal.gd, gancho dos
## avisos): a entrada dos cards (alvos de clique só com o card parado), o tremor e o flash do alerta do
## medidor por cima do terminal (um flash só) e o selo "+N" quando uma tarefa de ciência termina.
## Roda com: godot --headless --path . --script tests/test_avisos_no_terminal.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Terminal := preload("res://scripts/terminal.gd")
const Missao := preload("res://scripts/missao.gd")
const Som := preload("res://scripts/som.gd")
const Mov := preload("res://scripts/movimento_aviso.gd")

const QUADRO := 1.0 / 60.0

var falhas := 0
var total := 0


func _init() -> void:
	_tudo()


func _tudo() -> void:
	await _card_entra_e_so_entao_se_clica()
	_selo_quando_a_ciencia_termina()
	_selo_nao_nasce_fora_da_ciencia_do_turno()
	_selo_some_em_um_segundo_e_meio()
	_alerta_treme_e_da_um_flash_so()
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


## Roda `s` segundos de quadros: a missão avança e o terminal anda.
func _rodar(t: Control, m: Missao, s: float) -> void:
	for i in roundi(s / QUADRO):
		m.avancar(QUADRO)
		t._process(QUADRO)


func _fechar_fila(t: Control) -> void:
	var n := 0
	while t.card_aberto and n < 20:
		t._acionar("fechar_card")
		n += 1


## Um turno do sol 2 com as tarefas `tarefas` de ciência no plano, o terminal embaixo e o relógio andando.
## Devolve [terminal, missão].
func _turno(tarefas: Array, quebrado: bool = false) -> Array:
	var m := Missao.new(1, {"sol_solar": 3, "sol_poeira": 5, "sol_quebra": 2})
	m.montar_sol(2, {"E": 12.0, "O": 12.0, "M": 12.0, "P": 1.0, "gerador_quebrado": quebrado})
	var t: Control = Terminal.new()
	t.som = Som.new()
	t.iniciar(m, {})
	_fechar_fila(t)
	for nome: String in tarefas:
		m.alternar_tarefa(nome)
	t._acionar("confirmar")
	_rodar(t, m, t.duracao * 1.5)
	_igual(m.fase, "turno", "o turno começou")
	return [t, m]


## O card entra com o movimento: até ele parar, nada nele se clica (os alvos de clique só batem com o que está
## desenhado quando o card está parado); depois, o "Fechar" aparece em ui().
func _card_entra_e_so_entao_se_clica() -> void:
	var m := Missao.new(1)
	var t: Control = Terminal.new()
	t.gravar_textos = true
	t.iniciar(m, {})
	root.add_child(t)
	await process_frame
	await process_frame
	_igual(t.card_id, "aviso", "o aviso abre")
	_verdade(not t._card_entrou(), "logo depois de abrir, o card ainda está entrando")
	_igual(t.ui().keys(), [], "durante a entrada nada se clica")
	for i in 600:
		await process_frame
		if t._card_entrou():
			break
	_verdade(t._card_entrou(), "a entrada termina")
	await process_frame
	_igual(t.ui().keys(), ["fechar_card"], "com o card parado só o Fechar se clica")
	# O card seguinte também entra do começo.
	t._acionar("fechar_card")
	await process_frame
	await process_frame
	_igual(t.card_id, "sol1_o2", "o próximo card abre")
	_verdade(not t._card_entrou(), "o card seguinte entra de novo")
	_igual(t.ui().keys(), [], "e durante a entrada dele nada se clica")
	root.remove_child(t)
	t.free()


## Uma tarefa de ciência que termina põe o selo com o que ela rendeu (1 de ciência por tarefa).
func _selo_quando_a_ciencia_termina() -> void:
	var c := _turno(["amostra", "planta"])
	var t: Control = c[0]
	var m: Missao = c[1]
	_rodar(t, m, 0.5)
	_igual(t.selo_ativo(), 0, "sem tarefa terminada, sem selo")
	_verdade(m.iniciar_tarefa("amostra"), "a amostra começa")
	_rodar(t, m, m.tarefa_s - 1.0)
	_igual(t.selo_ativo(), 0, "tarefa ainda rodando: sem selo")
	_verdade(m.concluir_tarefa("amostra"), "a peça conclui a amostra")  # ciência só acaba pela peça (POR_PECA)
	_rodar(t, m, QUADRO * 2.0)
	_igual(m.tarefas["amostra"], "feita", "a amostra terminou")
	_igual(t.selo_ativo(), 1, "terminou uma tarefa de ciência: o selo diz +1")
	_igual(m.ciencia_do_sol(), 1, "a tarefa rendeu 1 de ciência")
	# A segunda tarefa põe o selo de novo.
	_rodar(t, m, 2.0)
	_igual(t.selo_ativo(), 0, "o selo já sumiu")
	_verdade(m.iniciar_tarefa("planta"), "a planta começa")
	_rodar(t, m, 0.5)
	_verdade(m.concluir_tarefa("planta"), "a peça conclui a planta")
	_rodar(t, m, QUADRO * 2.0)
	_igual(t.selo_ativo(), 1, "a segunda tarefa terminada: de novo +1")
	t.som.free()
	t.free()
	# Uma tarefa por peça (ChemCam) termina por concluir_tarefa.
	c = _turno(["chemcam"])
	t = c[0]
	m = c[1]
	_verdade(m.iniciar_tarefa("chemcam"), "o ChemCam começa")
	_rodar(t, m, 0.5)
	_igual(t.selo_ativo(), 0, "ChemCam em andamento: sem selo")
	_verdade(m.concluir_tarefa("chemcam"), "a peça conclui o ChemCam")
	_rodar(t, m, QUADRO * 2.0)
	_igual(t.selo_ativo(), 1, "ChemCam concluído pela peça: +1")
	t.som.free()
	t.free()


## A manutenção (gerador) não é ciência, o abrigo não cria selo e fora do turno não há selo.
func _selo_nao_nasce_fora_da_ciencia_do_turno() -> void:
	var c := _turno([], true)
	var t: Control = c[0]
	var m: Missao = c[1]
	_verdade(m.iniciar_tarefa("gerador"), "o conserto começa")
	_rodar(t, m, 0.5)
	_verdade(m.concluir_tarefa("gerador"), "o conserto termina")
	_rodar(t, m, QUADRO * 2.0)
	_igual(m.tarefas["gerador"], "feita", "o gerador está consertado")
	_igual(t.selo_ativo(), 0, "manutenção não é ciência: sem selo")
	t.som.free()
	t.free()
	c = _turno(["amostra"])
	t = c[0]
	m = c[1]
	_verdade(m.iniciar_tarefa("amostra"), "a amostra começa")
	_rodar(t, m, 2.0)
	_verdade(m.abrigar(), "abrigou com a tarefa rodando")
	_rodar(t, m, 12.0)
	_igual(t.selo_ativo(), 0, "abrigado, a tarefa cancelada não rende selo")
	t.som.free()
	t.free()


func _selo_some_em_um_segundo_e_meio() -> void:
	var c := _turno(["amostra"])
	var t: Control = c[0]
	var m: Missao = c[1]
	_verdade(m.iniciar_tarefa("amostra"), "a amostra começa")
	_rodar(t, m, 0.5)
	_verdade(m.concluir_tarefa("amostra"), "a peça conclui a amostra")
	_rodar(t, m, 0.2)
	_igual(t.selo_ativo(), 1, "selo à vista")
	_rodar(t, m, 1.0)
	_igual(t.selo_ativo(), 1, "ainda à vista 1,2 s depois")
	_rodar(t, m, 0.6)
	_igual(t.selo_ativo(), 0, "some depois de 1,5 s")
	t.som.free()
	t.free()


## O alerta vermelho por cima do terminal treme quando aparece e dá um flash só por travessia do limiar.
func _alerta_treme_e_da_um_flash_so() -> void:
	var m := Missao.new(21, {"sol_solar": 3, "sol_poeira": 5, "sol_quebra": 2})
	m.montar_sol(3, {"E": 12.0, "O": 12.0, "M": 12.0, "P": 1.0, "gerador_quebrado": false})
	var t: Control = Terminal.new()
	t.som = Som.new()
	t.iniciar(m, {})
	_fechar_fila(t)
	t._acionar("confirmar")
	_rodar(t, m, t.duracao * 1.5)
	t._acionar("terminal")
	_rodar(t, m, t.duracao * 1.5)
	_verdade(Mov.flash_alfa(t._flash_t) == 0.0, "terminal aberto, medidor baixo: sem flash")
	var guarda := 0
	while m.medidor() <= Missao.LIMIAR_ABRIGO and m.fase == "turno" and guarda < 4000:
		_rodar(t, m, 0.05)
		guarda += 1
	_rodar(t, m, QUADRO * 2.0)
	_verdade(t.alerta_sobre_o_terminal(), "o alerta está por cima do terminal")
	_verdade(t._alerta_t < Mov.DURACAO_TREMOR_S, "o alerta acabou de aparecer: está tremendo")
	_verdade(Mov.tremor(t._alerta_t) != 0.0, "o tremor desloca o alerta")
	_verdade(Mov.flash_alfa(t._flash_t) > 0.0, "e dá o flash vermelho")
	_rodar(t, m, 1.0)
	_igual(Mov.tremor(t._alerta_t), 0.0, "1 s depois o alerta parou")
	_igual(Mov.flash_alfa(t._flash_t), 0.0, "e o flash acabou")
	# Fechar e abrir o terminal com o medidor ainda acima do limiar: o alerta treme de novo, sem outro flash.
	t._acionar("terminal")
	_rodar(t, m, t.duracao * 1.5)
	t._acionar("terminal")
	_rodar(t, m, QUADRO * 3.0)
	_verdade(t.alerta_sobre_o_terminal(), "o alerta voltou por cima do terminal")
	_verdade(t._alerta_t < Mov.DURACAO_TREMOR_S, "treme de novo ao reaparecer")
	_igual(Mov.flash_alfa(t._flash_t), 0.0, "mas o flash é um só por travessia")
	t.som.free()
	t.free()
