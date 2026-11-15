extends SceneTree
## Teste headless da máquina da missão (scripts/missao.gd).
## Roda com: godot --headless --path . --script tests/test_missao.gd
## Joga a missão pela API, com avancar() em passos, e confere as regras. Sai com código 1 se algo
## falhar e imprime cada falha. Os números do modelo (13 para dividir no sol 1, dose 1 no sol comum,
## 3 a 15 na tempestade solar, margem 12, painel a 10% na poeira) estão feitos à mão, como em
## tests/test_modelo.gd.

const Missao := preload("res://scripts/missao.gd")
const Modelo := preload("res://scripts/modelo.gd")

var falhas := 0
var total := 0


func _init() -> void:
	_sorteios()
	_plano()
	_relogio_e_fim_do_turno()
	_pico_e_medidor()
	_abrigo_e_tarefas()
	_abrigo_de_mao_unica()
	_tarefa_nao_feita_e_teto()
	_exposicao_e_dose()
	_seguranca_no_meio_do_turno()
	_seguranca_no_fim_do_turno()
	_seguranca_sem_conserto()
	_aquecimento_e_gerador()
	_poeira()
	_quebra_do_gerador()
	_encerrar_sol()
	_fim_do_sol_noite_e_relatorio()
	_aviso()
	_missao_inteira()
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


func _st(e: float, o: float, m: float, p: float = 1.0, quebrado: bool = false) -> Dictionary:
	return {"E": e, "O": o, "M": m, "P": p, "gerador_quebrado": quebrado}


## Avança em passos até o relógio chegar a `t_alvo` (para no instante exato).
func _ate(m, t_alvo: float, passo: float = 0.05) -> void:
	while m.fase == "turno" and m.t < t_alvo - 1e-9:
		m.avancar(minf(passo, t_alvo - m.t))


## Avança até a fase mudar (turno acabando ou modo de segurança).
func _ate_sair_do_turno(m, passo: float = 0.25) -> void:
	var guarda := 0
	while m.fase == "turno" and guarda < 100000:
		m.avancar(passo)
		guarda += 1


## Missão em um sol de tempestade solar (3), com o estado dado, no plano. A poeira fica só no sol 5
## e a quebra no 2, para o sol 3 ter a energia cheia e o gerador inteiro.
func _solar(semente: int, estado: Dictionary):
	var m = Missao.new(semente, {"sol_solar": 3, "sol_poeira": 5, "sol_quebra": 2})
	m.montar_sol(3, estado)
	return m


func _sorteios() -> void:
	var solares := {}
	var atraso_min := 99
	var atraso_max := 0
	for semente in 200:
		var m = Missao.new(semente)
		solares[m.sol_solar] = true
		atraso_min = mini(atraso_min, m.atraso_min)
		atraso_max = maxi(atraso_max, m.atraso_min)
	_igual(solares.keys().size(), 2, "sorteio: os dois sóis de tempestade aparecem")
	_verdade(solares.has(3) and solares.has(4), "sorteio: sol da tempestade é 3 ou 4")
	_igual(atraso_min, 3, "sorteio: atraso mínimo 3")
	_igual(atraso_max, 22, "sorteio: atraso máximo 22")
	# Mesma semente, mesmo sorteio (inclusive o do pico).
	var a = Missao.new(42, {"sol_solar": 3})
	var b = Missao.new(42, {"sol_solar": 3})
	_igual(a.atraso_min, b.atraso_min, "semente: mesmo atraso")
	a.montar_sol(3, _st(6, 4, 12))
	b.montar_sol(3, _st(6, 4, 12))
	a.confirmar_plano()
	b.confirmar_plano()
	_igual(a.t_pico, b.t_pico, "semente: mesmo pico")
	_igual(Missao.new(1, {"sol_solar": 4}).sol_solar, 4, "sol_solar forçado em 4")
	_igual(Missao.new(1, {"sol_solar": 3}).sol_solar, 3, "sol_solar forçado em 3")
	# Poeira e quebra: sorteadas por missão em 2..5; a quebra nunca cai no sol da tempestade solar.
	var poeiras := {}
	var quebras := {}
	var quebra_no_solar := false
	var fora_da_faixa := false
	for semente in 200:
		var q = Missao.new(semente)
		poeiras[q.sol_poeira] = true
		quebras[q.sol_quebra] = true
		if q.sol_quebra == q.sol_solar:
			quebra_no_solar = true
		if q.sol_poeira < 2 or q.sol_poeira > 5 or q.sol_quebra < 2 or q.sol_quebra > 5:
			fora_da_faixa = true
	_igual(poeiras.keys().size(), 4, "sorteio: a poeira começa em qualquer sol de 2 a 5")
	_igual(quebras.keys().size(), 4, "sorteio: a quebra cai em qualquer sol de 2 a 5")
	_igual(fora_da_faixa, false, "sorteio: poeira e quebra só de 2 a 5")
	_igual(quebra_no_solar, false, "sorteio: a quebra nunca é no sol da tempestade solar")
	_igual(a.sol_poeira, b.sol_poeira, "semente: mesma poeira")
	_igual(a.sol_quebra, b.sol_quebra, "semente: mesma quebra")
	# Opções forçam; valor inválido, ou a quebra no sol da tempestade, volta ao sorteio.
	_igual(Missao.new(1, {"sol_poeira": 4}).sol_poeira, 4, "sol_poeira forçado em 4")
	_igual(Missao.new(1, {"sol_poeira": 5}).sol_poeira, 5, "sol_poeira forçado em 5")
	_igual(Missao.new(1, {"sol_solar": 3, "sol_quebra": 5}).sol_quebra, 5, "sol_quebra forçado em 5")
	_igual(Missao.new(1, {"sol_solar": 3, "sol_quebra": 2}).sol_quebra, 2, "sol_quebra forçado em 2")
	for ruim in [0, 1, 6, 9]:
		var rp = Missao.new(7, {"sol_poeira": ruim, "sol_quebra": ruim})
		_verdade(rp.sol_poeira >= 2 and rp.sol_poeira <= 5, "sol_poeira inválido (%d) volta ao sorteio" % ruim)
		_verdade(rp.sol_quebra >= 2 and rp.sol_quebra <= 5, "sol_quebra inválido (%d) volta ao sorteio" % ruim)
	for forcada in [3, 4]:
		var rq = Missao.new(7, {"sol_solar": forcada, "sol_quebra": forcada})
		_verdade(rq.sol_quebra != forcada, "sol_quebra forçado no sol da tempestade (%d) volta ao sorteio" % forcada)
	# Começo da missão.
	var m2 = Missao.new(1)
	_igual(m2.sol, 1, "começa no sol 1")
	_igual(m2.fase, "plano", "começa na fase de plano")
	_igual(m2.modos, 0, "começa sem modos de segurança")
	_igual(m2.st["E"], 6.0, "começa com a bateria do modelo")
	_igual(m2.para_dividir(), 13.0, "sol 1: 13 para dividir")
	_igual(m2.plano_q, 0, "plano começa com q 0")
	_igual(m2.plano_tarefas, [], "plano começa sem tarefas")


func _plano() -> void:
	var m = Missao.new(1, {"sol_solar": 3})
	_igual(m.mudar_q(-1), false, "plano: q não fica negativo")
	for i in 6:
		_verdade(m.mudar_q(1), "plano: q sobe até caber (%d)" % i)
	_igual(m.plano_q, 6, "plano: q 6 usa 12 de 13")
	_igual(m.mudar_q(1), false, "plano: q 7 não cabe")
	_igual(m.alternar_tarefa("chemcam"), false, "plano: q 6 e 1 tarefa não cabe (14 de 13)")
	_igual(m.plano_tarefas, [], "plano: o que não coube não entrou")
	m.mudar_q(-1)
	_verdade(m.alternar_tarefa("chemcam"), "plano: q 5 e chemcam cabe (12)")
	_igual(m.alternar_tarefa("amostra"), false, "plano: q 5 e 2 tarefas não cabe (14)")
	m.mudar_q(-1)
	_verdade(m.alternar_tarefa("amostra"), "plano: q 4 e 2 tarefas cabe (12)")
	_igual(m.alternar_tarefa("planta"), false, "plano: q 4 e 3 tarefas não cabe (14)")
	m.mudar_q(-1)
	_verdade(m.alternar_tarefa("planta"), "plano: q 3 e 3 tarefas cabe (12)")
	_igual(m.plano_tarefas, ["chemcam", "amostra", "planta"], "plano: tarefas na ordem fixa")
	_igual(m.mudar_q(1), false, "plano: q 4 e 3 tarefas não cabe")
	_igual(m.alternar_tarefa("laser"), false, "plano: tarefa desconhecida não entra")
	_verdade(m.alternar_tarefa("amostra"), "plano: desligar uma tarefa sempre vale")
	_igual(m.plano_tarefas, ["chemcam", "planta"], "plano: sobram chemcam e planta")
	# A previsão é a do modelo: q 3, 2 tarefas: 13 - 6 - 4 = 3 na bateria; ciência +2.
	var p: Dictionary = m.previsao()
	_igual(p["bateria_apos_plano"], 3.0, "previsão: bateria depois do plano")
	_igual(p["ciencia"], 2, "previsão: ciência")
	# Um plano que cabe nunca vira um que não cabe pelo caminho.
	_verdade(m.plano_cabe(m.plano_q, m.plano_tarefas.size()), "plano em edição sempre cabe")
	# Fora do plano, nada do plano muda.
	_verdade(m.confirmar_plano(), "confirmar plano")
	_igual(m.fase, "turno", "confirmado: turno")
	_igual(m.mudar_q(-1), false, "turno: q não muda")
	_igual(m.alternar_tarefa("amostra"), false, "turno: tarefa do plano não muda")
	_igual(m.confirmar_plano(), false, "turno: não se confirma duas vezes")
	_igual(m.plano_q, 3, "turno: q segue 3")
	# Confirmar é sempre permitido, mesmo com previsão de falha (O2 1, sem produzir).
	var f = Missao.new(1, {"sol_solar": 3})
	f.montar_sol(1, _st(6, 1, 12))
	_verdade(f.previsao()["falhas"].has("oxigenio"), "previsão mostra a falha de O2")
	_verdade(f.confirmar_plano(), "confirmar plano com previsão de falha")
	_igual(f.fase, "turno", "plano com falha prevista vai ao turno")


func _relogio_e_fim_do_turno() -> void:
	var m = Missao.new(1, {"sol_solar": 3})
	m.mudar_q(1)
	_igual(m.relogio(), 0.0, "relógio parado no plano")
	m.avancar(10.0)
	_igual(m.relogio(), 0.0, "o plano não tem relógio")
	_igual(m.fase, "plano", "avancar não tira do plano")
	m.confirmar_plano()
	_igual(m.relogio(), 0.0, "relógio começa em 0 ao confirmar")
	m.avancar(30.0)
	_igual(m.relogio(), 0.5, "relógio na metade")
	m.avancar(29.9)
	_igual(m.fase, "turno", "ainda no turno aos 59,9 s")
	m.avancar(0.2)
	_igual(m.fase, "fim_do_sol", "o turno acaba sozinho em TURNO_S")
	_verdade(m.t <= m.turno_s + 1e-9, "o relógio não passa de TURNO_S")
	_igual(m.registros.size(), 1, "fim do sol: um registro")
	var r: Dictionary = m.registros[0]
	_igual(r["sol"], 1, "registro: sol 1")
	_igual(r["antes"], {"E": 6.0, "O": 4.0, "M": 12.0}, "registro: barras antes")
	# q 1: bateria 13 - 2 = 11; O 4 + 1 - 2 = 3; M 12 - 1 = 11.
	_igual(r["depois"], {"E": 11.0, "O": 3.0, "M": 11.0}, "registro: barras depois")
	_igual(r["dose"], 1.0, "registro: dose do sol comum")
	_igual(r["tempestade"], false, "registro: sol calmo")
	# Um passo gigante também fecha o turno uma vez só.
	var g = Missao.new(1, {"sol_solar": 3})
	g.confirmar_plano()
	g.avancar(1000.0)
	_igual(g.fase, "fim_do_sol", "passo gigante fecha o turno")
	_igual(g.registros.size(), 1, "passo gigante: um registro só")
	# Turno encurtado pela opção.
	var c = Missao.new(1, {"sol_solar": 3, "turno_s": 8.0, "tarefa_s": 2.0})
	_igual(c.turno_s, 8.0, "opção turno_s")
	_igual(c.tarefa_s, 2.0, "opção tarefa_s")
	c.confirmar_plano()
	c.avancar(7.9)
	_igual(c.fase, "turno", "turno de 8 s: aos 7,9 s ainda corre")
	c.avancar(0.2)
	_igual(c.fase, "fim_do_sol", "turno de 8 s acaba aos 8 s")
	# As barras que a tela mostra em cada fase.
	var b = Missao.new(1, {"sol_solar": 3})
	_igual(b.barras_na_fase("plano"), {"E": 6.0, "O": 4.0, "M": 12.0}, "barras no plano: o estado do sol")
	b.mudar_q(2)
	b.confirmar_plano()
	_igual(b.barras_na_fase("turno"), {"E": 9.0, "O": 4.0, "M": 12.0}, "barras no turno: bateria depois do plano (13 - 4)")
	b.avancar(b.turno_s)
	_igual(b.barras_na_fase("fim_do_sol"), {"E": 9.0, "O": 4.0, "M": 11.0}, "barras no fim do sol: o estado depois")
	_igual(b.ciencia_ate_agora(), 0, "ciência até agora sem tarefas")
	# Em fim_do_sol o relógio não anda e as ações do turno não valem.
	_igual(c.abrigar(), false, "fim do sol: abrigo não vale")
	_igual(c.iniciar_tarefa("chemcam"), false, "fim do sol: tarefa não inicia")


func _pico_e_medidor() -> void:
	# Sol comum: sem pico e medidor baixo o turno inteiro.
	var c = Missao.new(3, {"sol_solar": 3})
	c.confirmar_plano()
	_igual(c.t_pico, -1.0, "sol comum: sem pico")
	var alto := false
	while c.fase == "turno":
		if c.medidor() != Missao.MEDIDOR_BAIXO:
			alto = true
		c.avancar(0.5)
	_igual(alto, false, "sol comum: medidor sempre baixo")
	# Sol da tempestade: pico dentro de [15%, 70%] do turno, em muitas sementes.
	var dentro := true
	var distintos := {}
	for semente in 100:
		var s = _solar(semente, _st(6, 4, 12))
		s.confirmar_plano()
		distintos[snappedf(s.t_pico, 0.001)] = true
		if s.t_pico < Missao.PICO_MIN * s.turno_s - 1e-9 or s.t_pico > Missao.PICO_MAX * s.turno_s + 1e-9:
			dentro = false
	_verdade(dentro, "pico sorteado só entre 15% e 70% do turno")
	_verdade(distintos.size() > 50, "pico varia de sorteio para sorteio")
	# Medidor: baixo antes da rampa, sobe linear, acima de "abrigo" do pico ao fim.
	var m = _solar(5, _st(6, 4, 12))
	m.confirmar_plano()
	var tp: float = m.t_pico
	_igual(m.medidor(), 0.15, "medidor baixo no começo")
	_ate(m, tp - 3.0 - 0.01)
	_igual(m.medidor(), 0.15, "medidor baixo antes da rampa")
	_ate(m, tp - 3.0)
	_igual(m.medidor(), 0.15, "medidor baixo no começo da rampa")
	_ate(m, tp - 1.5)
	_igual(m.medidor(), 0.425, "medidor na metade da rampa (0,15 -> 0,7)")
	_verdade(m.medidor() > Missao.LIMIAR_ATENCAO, "na metade da rampa passa de atenção")
	_verdade(m.medidor() < Missao.LIMIAR_ABRIGO, "na metade da rampa ainda não passa de abrigo")
	_igual(m.tempestade_em_curso(), false, "antes do pico não há tempestade em curso")
	_ate(m, tp + 0.001)  # a soma de passos em ponto flutuante pode parar um fio antes de tp
	_igual(m.medidor(), 0.9, "do pico em diante o medidor está em 0,9")
	_verdade(m.medidor() > Missao.LIMIAR_ABRIGO, "do pico em diante: acima de abrigo")
	_igual(m.tempestade_em_curso(), true, "do pico em diante: tempestade em curso")
	m.abrigar()  # não deixa a margem zerar
	_ate(m, m.turno_s - 0.05)
	_verdade(m.medidor() > Missao.LIMIAR_ABRIGO, "medidor acima de abrigo até o fim do turno")
	# Fora do turno o medidor é baixo.
	_ate_sair_do_turno(m)
	_igual(m.medidor(), 0.15, "medidor baixo fora do turno")
	# A rampa não passa do pico: um turno curto com pico perto do começo.
	var curto = Missao.new(2, {"sol_solar": 3, "turno_s": 8.0})
	curto.montar_sol(3, _st(6, 4, 12))
	curto.confirmar_plano()
	_verdade(curto.medidor() >= 0.15 and curto.medidor() <= 0.7, "turno curto: medidor entre baixo e abrigo antes do pico")


func _abrigo_e_tarefas() -> void:
	var m = Missao.new(1, {"sol_solar": 3})
	m.alternar_tarefa("chemcam")
	m.alternar_tarefa("amostra")
	_igual(m.iniciar_tarefa("chemcam"), false, "tarefa não inicia no plano")
	_igual(m.abrigar(), false, "abrigo não vale no plano")
	m.confirmar_plano()
	_igual(m.tarefas, {"chemcam": "pendente", "amostra": "pendente"}, "tarefas escolhidas começam pendentes")
	_igual(m.iniciar_tarefa("planta"), false, "tarefa não escolhida não inicia")
	_verdade(m.iniciar_tarefa("chemcam"), "tarefa escolhida inicia")
	_igual(m.tarefas["chemcam"], "rodando", "tarefa rodando")
	_igual(m.iniciar_tarefa("amostra"), false, "uma tarefa por vez")
	_igual(m.iniciar_tarefa("chemcam"), false, "tarefa rodando não inicia de novo")
	m.avancar(5.0)
	_igual(m.progresso_tarefa("chemcam"), 0.5, "andamento da tarefa")
	m.avancar(4.9)
	_igual(m.tarefas["chemcam"], "rodando", "aos 9,9 s ainda roda")
	m.avancar(0.2)
	_igual(m.tarefas["chemcam"], "feita", "roda TAREFA_S e vira feita")
	_igual(m.ciencia_do_sol(), 1, "feita rende +1 de ciência")
	_igual(m.iniciar_tarefa("chemcam"), false, "tarefa feita não inicia de novo")
	_verdade(m.iniciar_tarefa("amostra"), "a outra inicia depois")
	# O abrigo é só tempo, não energia: a bateria do estado não muda no turno.
	_igual(m.st["E"], 6.0, "o turno não mexe no estado do sol")


## O abrigo é de mão única: vale uma vez, no turno, e depois a tripulação não faz mais nada.
func _abrigo_de_mao_unica() -> void:
	# Abrigar com a tarefa rodando: ela volta a pendente, perde o andamento e não conta.
	var m = Missao.new(1, {"sol_solar": 3})
	m.alternar_tarefa("chemcam")
	m.alternar_tarefa("amostra")
	m.confirmar_plano()
	m.iniciar_tarefa("chemcam")
	m.avancar(5.0)
	_verdade(m.abrigar(), "abrigo vale no turno, no sol comum")
	_igual(m.abrigado, true, "abrigado")
	_igual(m.tarefas["chemcam"], "pendente", "abrigo interrompe a tarefa")
	_igual(m.tarefa_rodando, "", "nenhuma tarefa rodando abrigado")
	_igual(m.progresso_tarefa("chemcam"), 0.0, "abrigo zera o andamento")
	_igual(m.abrigar(), false, "o abrigo vale uma vez só")
	_igual(m.abrigado, true, "não há como sair do abrigo")
	_igual(m.iniciar_tarefa("chemcam"), false, "abrigado não inicia a tarefa que rodava")
	_igual(m.iniciar_tarefa("amostra"), false, "abrigado não inicia outra tarefa")
	m.avancar(20.0)
	_igual(m.tarefas["chemcam"], "pendente", "abrigado o tempo passa e a tarefa não anda")
	_igual(m.ciencia_do_sol(), 0, "a tarefa que rodava ao abrigar não conta")
	m.avancar(m.turno_s)
	_igual(m.fase, "fim_do_sol", "o turno acaba pelo relógio")
	var r: Dictionary = m.registros[0]
	_igual(r["ciencia"], 0, "registro: nada feito")
	_igual(r["abrigou"], true, "registro: abrigou")
	# q 0, 2 tarefas (4 de 13): sobram 9; nada feito devolve 4: 13, o teto guarda 12. Sol comum: dose 1.
	_igual(r["devolvida"], 4.0, "abrigado sem ciência: a reserva das duas volta")
	_igual(r["depois"], {"E": 12.0, "O": 2.0, "M": 11.0}, "abrigado no sol comum: barras depois")
	# A ciência feita antes de abrigar conta; a reserva da que não foi feita volta.
	var c = Missao.new(1, {"sol_solar": 3})
	c.alternar_tarefa("chemcam")
	c.alternar_tarefa("amostra")
	c.confirmar_plano()
	c.iniciar_tarefa("chemcam")
	c.avancar(10.0)
	_igual(c.tarefas["chemcam"], "feita", "chemcam feita antes do abrigo")
	_verdade(c.abrigar(), "abrigar depois de uma tarefa feita")
	_igual(c.tarefas["chemcam"], "feita", "a ciência feita não se perde ao abrigar")
	_igual(c.ciencia_do_sol(), 1, "a ciência feita conta")
	_igual(c.iniciar_tarefa("amostra"), false, "depois do abrigo nenhuma tarefa nova")
	c.avancar(c.turno_s)
	_igual(c.registros[0]["ciencia"], 1, "registro: a ciência feita antes do abrigo conta")
	_igual(c.registros[0]["feitas"], ["chemcam"], "registro: feitas")
	_igual(c.registros[0]["nao_feitas"], ["amostra"], "registro: não feitas")
	# 9 depois do plano + 2 devolvidos = 11.
	_igual(c.registros[0]["depois"]["E"], 11.0, "abrigado depois de 1 tarefa: bateria 9 + 2")
	# Abrigar vale em qualquer sol, também no da tempestade (não denuncia o sol).
	var s = _solar(3, _st(6, 4, 12))
	s.confirmar_plano()
	_verdade(s.abrigar(), "abrigo vale no sol da tempestade")
	_igual(s.abrigar(), false, "no sol da tempestade também vale uma vez só")
	# Com gerador quebrado: depois do abrigo, nem a manutenção.
	var g = Missao.new(1, {"sol_solar": 3})
	g.montar_sol(2, _st(6, 4, 12, 1.0, true))
	g.confirmar_plano()
	_igual(g.tarefas, {"gerador": "pendente"}, "gerador quebrado entra na lista")
	g.abrigar()
	_igual(g.iniciar_tarefa("gerador"), false, "abrigado não conserta o gerador")


func _tarefa_nao_feita_e_teto() -> void:
	# q 0 e 3 tarefas: sobram 13 - 6 = 7. Só chemcam feita: devolve 2 * 2 = 4, bateria 11.
	var m = Missao.new(1, {"sol_solar": 3})
	for n in ["chemcam", "amostra", "planta"]:
		m.alternar_tarefa(n)
	m.confirmar_plano()
	m.iniciar_tarefa("chemcam")
	m.avancar(10.0)
	m.iniciar_tarefa("amostra")
	_ate_sair_do_turno(m)  # a amostra roda até o fim do turno e termina; a planta nunca inicia
	var r: Dictionary = m.registros[0]
	_igual(r["feitas"], ["chemcam", "amostra"], "registro: feitas")
	_igual(r["nao_feitas"], ["planta"], "registro: não feitas")
	_igual(r["ciencia"], 2, "registro: ciência 2")
	_igual(r["devolvida"], 2.0, "registro: devolvida 2 (planta)")
	_igual(r["depois"]["E"], 9.0, "bateria: 7 + 2 devolvidos")
	_igual(m.ciencia_do_sol(), 2, "ciência do sol")
	_igual(m.ciencia_por_sol, [2], "ciência por sol")
	# Nenhuma feita: devolve 6, 13 passa do teto: perde 1.
	var z = Missao.new(1, {"sol_solar": 3})
	for n in ["chemcam", "amostra", "planta"]:
		z.alternar_tarefa(n)
	z.confirmar_plano()
	_ate_sair_do_turno(z)
	var rz: Dictionary = z.registros[0]
	_igual(rz["ciencia"], 0, "nada feito: ciência 0")
	_igual(rz["devolvida"], 6.0, "nada feito: devolve 6")
	_igual(rz["perdida_no_teto"], 1.0, "nada feito: o teto perde 1")
	_igual(rz["depois"]["E"], 12.0, "nada feito: bateria no teto")
	_igual(rz["nao_feitas"].size(), 3, "nada feito: três não feitas")
	# Tarefa rodando quando o turno acaba conta como não feita.
	var c = Missao.new(1, {"sol_solar": 3, "turno_s": 20.0})
	c.alternar_tarefa("planta")
	c.confirmar_plano()
	c.avancar(15.0)
	c.iniciar_tarefa("planta")
	c.avancar(5.0)  # só 5 de 10 s
	_igual(c.fase, "fim_do_sol", "turno de 20 s acabou")
	_igual(c.registros[0]["ciencia"], 0, "tarefa que não terminou não conta")
	_igual(c.registros[0]["nao_feitas"], ["planta"], "tarefa que não terminou é não feita")
	_igual(c.registros[0]["devolvida"], 2.0, "a reserva da que não terminou volta")


func _exposicao_e_dose() -> void:
	# Margem 20 (montada à mão), exposta o tempo todo: f = 1, dose 15. A margem ao vivo cai até 20 - 12 = 8
	# (a parte da dose acima do mínimo de 3) e fecha em 20 - 15 = 5.
	var m = _solar(11, _st(6, 4, 20))
	m.confirmar_plano()
	var tp: float = m.t_pico
	_ate(m, tp - 0.05)
	_igual(m.f_exposto(), 0.0, "antes do pico não há exposição")
	_igual(m.margem_ao_vivo(), 20.0, "antes do pico a margem é a do estado")
	_ate(m, tp + (m.turno_s - tp) / 2.0)
	_igual(m.f_exposto(), 0.5, "meio do pós-pico exposto: f 0,5")
	_igual(m.queda_ao_vivo(), 6, "f 0,5: a margem ao vivo caiu round(12 * 0,5) = 6")
	_igual(m.margem_ao_vivo(), 14.0, "margem ao vivo 20 - 6")
	_ate_sair_do_turno(m, 0.05)
	_igual(m.fase, "fim_do_sol", "exposta o tempo todo com margem 20 passa")
	var r: Dictionary = m.registros[0]
	_igual(r["tempestade"], true, "registro: sol da tempestade")
	_igual(r["dose"], 15.0, "dose sem abrigo: 15")
	_igual(r["depois"]["M"], 5.0, "margem 20 - 15")
	_igual(r["abrigou"], false, "registro: não abrigou")
	# Com a margem de partida (12), a tempestade sem abrigo zera a margem no meio do turno.
	var z = _solar(11, _st(6, 4, 12))
	z.confirmar_plano()
	_ate_sair_do_turno(z, 0.05)
	_igual(z.fase, "seguranca", "tempestade sem abrigo com margem 12: modo de segurança")
	_igual(z.causa, "radiacao", "tempestade sem abrigo: causa radiação")
	# Abrigou antes do pico: f 0, dose 3.
	var a = _solar(11, _st(6, 4, 12))
	a.confirmar_plano()
	a.abrigar()
	_ate_sair_do_turno(a, 0.05)
	_igual(a.registros[0]["dose"], 3.0, "abrigado antes do pico: dose 3")
	_igual(a.registros[0]["depois"]["M"], 9.0, "abrigado antes do pico: margem 9")
	_igual(a.registros[0]["abrigou"], true, "registro: abrigou")
	_igual(a.registros[0]["f_exposto"], 0.0, "registro: f 0")
	# Abrigou na metade do pós-pico: f 0,5, dose 3 + round(6) = 9.
	var b = _solar(11, _st(6, 4, 12))
	b.confirmar_plano()
	_ate(b, b.t_pico + (b.turno_s - b.t_pico) / 2.0)
	b.abrigar()
	_ate_sair_do_turno(b, 0.05)
	_igual(b.registros[0]["dose"], 9.0, "abrigou no meio: dose 9")
	_igual(b.registros[0]["depois"]["M"], 3.0, "abrigou no meio: margem 3")
	# Abrigou antes do pico não deixa exposição nenhuma, mesmo com o abrigo de mão única.
	var c = _solar(11, _st(6, 4, 12))
	c.confirmar_plano()
	_ate(c, c.t_pico - 1.0)
	c.abrigar()
	_ate_sair_do_turno(c, 0.05)
	_igual(c.registros[0]["dose"], 3.0, "abrigou 1 s antes do pico: dose 3")
	_igual(c.t_exposto, 0.0, "abrigado antes do pico: sem exposição")
	# Passo grande que cruza o pico conta só a parte depois dele.
	var d = _solar(11, _st(6, 4, 12))
	d.confirmar_plano()
	var tpd: float = d.t_pico
	d.avancar(tpd + 3.0)
	_igual(d.t_exposto, 3.0, "o passo que cruza o pico conta só 3 s depois dele")
	# Sol comum: exposição não existe e a dose é 1 de qualquer jeito.
	var e = Missao.new(1, {"sol_solar": 3})
	e.confirmar_plano()
	e.avancar(100.0)
	_igual(e.registros[0]["dose"], 1.0, "sol comum: dose 1")
	_igual(e.f_exposto(), 0.0, "sol comum: f 0")


func _seguranca_no_meio_do_turno() -> void:
	# Margem 4 exposta: a margem ao vivo (4 - round(12 f)) zera em f 0,29 e o modo entra ali.
	var m = _solar(21, _st(6, 4, 4))
	m.confirmar_plano()
	_ate_sair_do_turno(m, 0.05)
	_igual(m.fase, "seguranca", "margem ao vivo zerada: modo de segurança no meio do turno")
	_verdade(m.t < m.turno_s - 1.0, "entrou antes do fim do turno")
	_igual(m.causa, "radiacao", "causa: radiação")
	_igual(m.modos, 1, "uma entrada soma 1 em modos")
	_igual(m.causa_sem_abrigo, true, "não abrigou a tempo")
	_igual(m.barras_falha, {"E": 6.0, "O": 4.0, "M": 0.0}, "barras da falha: margem em 0")
	_igual(m.tem_conserto, true, "margem 4: o abrigo salva (4 - 3 = 1), tem conserto")
	_igual(m.seguir_em_seguranca(), false, "com conserto não se segue")
	_igual(m.registros.size(), 0, "o sol que falhou não vira registro")
	_igual(m.ciencia_por_sol, [], "o sol que falhou não conta ciência")
	# Reinicia: volta ao plano do mesmo sol, com o instantâneo, e o modo fica contado.
	_verdade(m.reiniciar_sol(), "reiniciar o sol")
	_igual(m.fase, "plano", "reiniciou no plano")
	_igual(m.sol, 3, "reiniciou o mesmo sol")
	_igual(m.sol_solar, 3, "o sol da tempestade se mantém")
	_igual(m.st["M"], 4.0, "reiniciou com o instantâneo")
	_igual(m.modos, 1, "reiniciar não zera os modos")
	_igual(m.plano_q, 0, "reiniciou com plano limpo")
	_igual(m.t_pico, -1.0, "o pico só é sorteado ao confirmar")
	# Agora abriga na hora e passa: o pico é sorteado de novo.
	var picos := {}
	for i in 6:
		var n = _solar(21 + i, _st(6, 4, 4))
		n.confirmar_plano()
		_ate_sair_do_turno(n, 0.5)
		if n.fase == "seguranca":
			n.reiniciar_sol()
			n.confirmar_plano()
			picos[snappedf(n.t_pico, 0.001)] = true
			_verdade(n.t_pico >= Missao.PICO_MIN * n.turno_s - 1e-9 and n.t_pico <= Missao.PICO_MAX * n.turno_s + 1e-9, "pico re-sorteado dentro da faixa")
	_verdade(picos.size() > 1, "o pico é re-sorteado quando o sol reinicia")
	m.confirmar_plano()
	m.abrigar()
	_ate_sair_do_turno(m, 0.05)
	_igual(m.fase, "fim_do_sol", "abrigado, passa: margem 4 - 3 = 1")
	_igual(m.registros[0]["depois"]["M"], 1.0, "margem 1")
	_igual(m.modos, 1, "o sol que passou não soma modo")
	# O instantâneo é o do começo do sol, não o do plano: ciência de uma tentativa que falhou não vaza.
	var z = _solar(21, _st(6, 4, 4))
	z.alternar_tarefa("amostra")
	z.confirmar_plano()
	z.iniciar_tarefa("amostra")
	_ate_sair_do_turno(z, 0.05)
	_igual(z.fase, "seguranca", "com tarefa rodando a margem também zera")
	z.reiniciar_sol()
	_igual(z.tarefas, {}, "reiniciar limpa as tarefas")
	_igual(z.plano_tarefas, [], "reiniciar limpa o plano")


func _seguranca_no_fim_do_turno() -> void:
	# O2 1 sem produzir: falha de oxigênio no fim do turno. A emergência (tudo ao gerador) salva.
	var m = Missao.new(1, {"sol_solar": 3})
	m.montar_sol(1, _st(6, 1, 12))
	m.confirmar_plano()
	m.avancar(m.turno_s)
	_igual(m.fase, "seguranca", "falhas no fim do turno: modo de segurança")
	_igual(m.causa, "oxigenio", "causa: oxigênio")
	_igual(m.causas, ["oxigenio"], "causas")
	_igual(m.barras_falha["O"], 0.0, "barras da falha: O2 negativo aparece como 0")
	_igual(m.causa_sem_abrigo, false, "oxigênio: sem a frase do abrigo")
	_igual(m.modos, 1, "modo contado")
	_igual(m.tem_conserto, true, "O2 1: a emergência salva")
	_igual(m.reiniciar_sol(), true, "reinicia")
	_igual(m.st["O"], 1.0, "voltou com O 1")
	m.mudar_q(1)  # O2 1 + 1 - 2 = 0: não é falha
	m.confirmar_plano()
	m.avancar(m.turno_s)
	_igual(m.fase, "fim_do_sol", "plano certo passa")
	_igual(m.modos, 1, "segundo try sem modo novo")
	# Radiação no fim do turno, sem queda ao vivo: margem 3 abrigado no sol da tempestade (dose 3) dá 0.
	var r = _solar(31, _st(6, 4, 3))
	r.confirmar_plano()
	r.abrigar()
	_ate_sair_do_turno(r, 0.05)
	_igual(r.fase, "seguranca", "margem 3 e dose 3 abrigado: falha de radiação no fim")
	_igual(r.causa, "radiacao", "causa radiação no fim do turno")
	_igual(r.causa_sem_abrigo, false, "abrigou: sem a frase do abrigo")
	_igual(r.tem_conserto, false, "margem 3: nem o abrigo salva")
	# Outro modo de segurança soma de novo.
	var s = Missao.new(1, {"sol_solar": 3})
	s.montar_sol(1, _st(6, 1, 12))
	s.confirmar_plano()
	s.avancar(s.turno_s)
	s.reiniciar_sol()
	s.confirmar_plano()
	s.avancar(s.turno_s)
	_igual(s.modos, 2, "cada entrada soma 1 (duas)")


func _seguranca_sem_conserto() -> void:
	# Margem 2 no sol da tempestade exposta: a margem ao vivo zera no meio; não há plano que salve
	# (nem o abrigo, de dose 3).
	var m = _solar(41, _st(6, 4, 2))
	m.confirmar_plano()
	_ate_sair_do_turno(m, 0.05)
	_igual(m.fase, "seguranca", "margem 2 exposta: segurança")
	_igual(m.tem_conserto, false, "sem conserto")
	_igual(m.reiniciar_sol(), false, "sem conserto não reinicia")
	_verdade(m.seguir_em_seguranca(), "seguir em segurança")
	_igual(m.fase, "fim_do_sol", "seguir leva ao fim do sol")
	_igual(m.modos, 1, "conta 1 modo de segurança")
	var r: Dictionary = m.registros[0]
	_igual(r["seguranca"], true, "registro marca o modo de segurança")
	_igual(r["ciencia"], 0, "o sol passa sem ciência")
	_igual(r["causa"], "radiacao", "registro guarda a causa")
	# Estado = Modelo.seguir_em_seguranca do instantâneo: margem 2 - 3 = -1, no piso 0.
	_igual(r["depois"]["M"], 0.0, "margem no piso 0")
	_igual(m.st_fim["O"], 8.0, "estado do plano de emergência: O2 4 + 6 - 2")
	_igual(m.ciencia_por_sol, [0], "ciência por sol: 0")
	_verdade(m.enviar_a_terra(), "enviar à Terra depois do modo de segurança")
	_igual(m.st["M"], 0.0, "o estado seguiu em frente")
	# Margem 0 no começo de um sol comum: a margem ao vivo não dispara (não houve exposição),
	# o sol falha no fim, e sem conserto a saída é seguir.
	var z = Missao.new(1, {"sol_solar": 3})
	z.montar_sol(1, _st(6, 4, 0))
	z.confirmar_plano()
	_ate(z, 10.0)
	_igual(z.fase, "turno", "margem 0 sem exposição: o turno corre")
	z.avancar(z.turno_s)
	_igual(z.fase, "seguranca", "margem 0: falha de radiação no fim")
	_igual(z.tem_conserto, false, "margem 0: sem conserto")


func _aquecimento_e_gerador() -> void:
	# Falta de energia para o aquecimento de manhã: antes do plano, sem conserto (montado à mão).
	var m = Missao.new(1, {"sol_solar": 3})
	m.montar_sol(2, _st(0, 4, 12, 0.0))
	_igual(m.fase, "seguranca", "falta aquecimento: segurança antes do plano")
	_igual(m.causa, "energia", "causa: energia")
	_igual(m.barras_falha["E"], 0.0, "barras da falha: bateria 0")
	_igual(m.modos, 1, "conta 1 modo")
	_igual(m.tem_conserto, false, "bateria vazia e sem painel: sem conserto")
	_igual(m.reiniciar_sol(), false, "sem conserto não reinicia")
	_igual(m.confirmar_plano(), false, "sem plano em segurança")
	_verdade(m.seguir_em_seguranca(), "seguir em segurança na manhã")
	_igual(m.registros[0]["causa"], "energia", "registro com a causa energia")
	_igual(m.registros[0]["seguranca"], true, "registro: segurança")
	_igual(m.st_fim["E"], 0.0, "bateria 0")
	# Sol com gerador quebrado e O2 0: o teste do modelo inclui consertar, então reinicia.
	var g = Missao.new(1, {"sol_solar": 3})
	g.montar_sol(2, _st(6, 0, 12, 1.0, true))
	_igual(g.fase, "plano", "gerador quebrado com bateria: plano normal")
	_igual(g.st["gerador_quebrado"], true, "gerador quebrado no estado")
	g.confirmar_plano()  # q 0: O2 0 - 2 = -2
	g.avancar(g.turno_s)
	_igual(g.fase, "seguranca", "O2 0 sem produzir: segurança")
	_igual(g.causa, "oxigenio", "causa oxigênio")
	_igual(g.tem_conserto, true, "gerador quebrado e O2 0: conserta no teste, reinicia")
	_igual(g.seguir_em_seguranca(), false, "não é caso de seguir")
	_verdade(g.reiniciar_sol(), "reinicia")
	_igual(g.st["gerador_quebrado"], true, "o instantâneo mantém o gerador quebrado")
	# O gerador só quebra no sol sorteado (nunca no 1): jogando o sol 1, ele segue inteiro.
	var n = Missao.new(1, {"sol_solar": 3})
	n.mudar_q(2)
	n.confirmar_plano()
	n.avancar(n.turno_s)
	_igual(n.st_fim["gerador_quebrado"], false, "gerador não quebra no sol 1")
	_igual(n.registros[0]["gerador_quebrado"], false, "registro: o gerador estava inteiro")
	_igual(n.registros[0]["consertou"], false, "registro: nada a consertar")


func _poeira() -> void:
	# A tempestade de poeira dura 2 sóis a partir do sol sorteado; a de início no sol 5 fica só nele.
	var esperado := {
		2: {1: false, 2: true, 3: true, 4: false, 5: false},
		3: {1: false, 2: false, 3: true, 4: true, 5: false},
		4: {1: false, 2: false, 3: false, 4: true, 5: true},
		5: {1: false, 2: false, 3: false, 4: false, 5: true},
	}
	for inicio in esperado:
		var p = Missao.new(1, {"sol_solar": 3, "sol_poeira": inicio})
		for s in esperado[inicio]:
			p.montar_sol(s, _st(6, 4, 12))
			_igual(p.eh_poeira(), esperado[inicio][s], "poeira começando no sol %d: sol %d" % [inicio, s])
	# No plano: o painel rende 10%. Bateria 6 + 0,8 - 1 = 5,8 para dividir (13 sem poeira).
	var m = Missao.new(1, {"sol_solar": 3, "sol_poeira": 2})
	m.montar_sol(2, _st(6, 4, 12))
	_igual(m.para_dividir(), 5.8, "poeira: 5,8 para dividir")
	_verdade(m.mudar_q(1), "poeira: q 1 cabe (2 de 5,8)")
	_verdade(m.mudar_q(1), "poeira: q 2 cabe (4 de 5,8)")
	_igual(m.mudar_q(1), false, "poeira: q 3 não cabe (6 de 5,8)")
	_igual(m.alternar_tarefa("chemcam"), false, "poeira: q 2 e 1 tarefa não cabe (6 de 5,8)")
	m.mudar_q(-1)
	_verdade(m.alternar_tarefa("chemcam"), "poeira: q 1 e 1 tarefa cabe (4 de 5,8)")
	_igual(m.alternar_tarefa("amostra"), false, "poeira: q 1 e 2 tarefas não cabe (6 de 5,8)")
	m.alternar_tarefa("chemcam")
	m.mudar_q(1)
	# q 2: depois do plano 5,8 - 4 = 1,8; a previsão e a barra do turno usam a poeira.
	_igual(m.previsao()["bateria_apos_plano"], 1.8, "poeira: previsão da bateria depois do plano")
	m.confirmar_plano()
	_igual(m.barras_na_fase("turno"), {"E": 1.8, "O": 4.0, "M": 12.0}, "poeira: barras do turno")
	m.avancar(m.turno_s)
	var r: Dictionary = m.registros[0]
	_igual(r["poeira"], true, "registro: sol de poeira")
	# O: 4 + 2 - 2 = 4; E 1,8; M 12 - 1 = 11.
	_igual(r["depois"], {"E": 1.8, "O": 4.0, "M": 11.0}, "poeira: barras depois")
	# O mesmo estado fora da poeira tem 13 para dividir.
	var n = Missao.new(1, {"sol_solar": 3, "sol_poeira": 2})
	n.montar_sol(4, _st(6, 4, 12))
	_igual(n.para_dividir(), 13.0, "fora da poeira: 13 para dividir")
	_igual(n.eh_poeira(), false, "sol 4 com a poeira no 2: fora")
	n.mudar_q(1)
	n.confirmar_plano()
	n.avancar(n.turno_s)
	_igual(n.registros[0]["poeira"], false, "registro: sol fora da poeira")
	# Bateria vazia na poeira: o sol já começa em modo de segurança por energia, e nenhum plano salva.
	var z = Missao.new(1, {"sol_solar": 3, "sol_poeira": 2})
	z.montar_sol(2, _st(0, 4, 12))
	_igual(z.fase, "seguranca", "poeira, bateria 0: segurança antes do plano")
	_igual(z.causa, "energia", "poeira, bateria 0: causa energia")
	_igual(z.tem_conserto, false, "poeira, bateria 0: nenhum plano salva")
	# Com bateria 0 fora da poeira o painel cobre o aquecimento.
	z.montar_sol(4, _st(0, 4, 12))
	_igual(z.fase, "plano", "sem poeira, bateria 0: o painel cobre o aquecimento")
	# Bateria 1,2 e O2 1 na poeira: 1,2 + 0,8 - 1 = 1 para dividir, q 0, O 1 - 2 = -1, e nenhum plano
	# salva (o plano de emergência também usa a poeira). Fora dela, a emergência (q 4) salva.
	var f = Missao.new(1, {"sol_solar": 3, "sol_poeira": 2})
	f.montar_sol(2, _st(1.2, 1, 12))
	f.confirmar_plano()
	f.avancar(f.turno_s)
	_igual(f.fase, "seguranca", "poeira, O2 1: falha de oxigênio")
	_igual(f.tem_conserto, false, "poeira: o plano de emergência também é o da poeira")
	_verdade(f.seguir_em_seguranca(), "poeira sem conserto: seguir em segurança")
	_igual(f.registros[0]["poeira"], true, "registro do modo de segurança: poeira")
	# Seguir: emergência q 0: E 1, O -1 -> piso 0, M 12 - 1 = 11.
	_igual(f.st_fim, {"E": 1.0, "O": 0.0, "M": 11.0, "P": 1.0, "gerador_quebrado": false}, "poeira: estado de seguir em segurança")
	var g = Missao.new(1, {"sol_solar": 3, "sol_poeira": 2})
	g.montar_sol(4, _st(1.2, 1, 12))
	g.confirmar_plano()
	g.avancar(g.turno_s)
	_igual(g.tem_conserto, true, "sem poeira o mesmo estado tem conserto")
	# Os eventos são da missão: o reinício do sol não sorteia de novo.
	var h = Missao.new(5, {"sol_solar": 4})
	var poeira_antes: int = h.sol_poeira
	var quebra_antes: int = h.sol_quebra
	var solar_antes: int = h.sol_solar
	h.montar_sol(1, _st(6, 1, 12))
	h.confirmar_plano()
	h.avancar(h.turno_s)
	_igual(h.fase, "seguranca", "reinício: o sol falhou")
	_verdade(h.reiniciar_sol(), "reinício: reinicia")
	_igual(h.sol_poeira, poeira_antes, "reinício: a poeira é a mesma")
	_igual(h.sol_quebra, quebra_antes, "reinício: a quebra é a mesma")
	_igual(h.sol_solar, solar_antes, "reinício: a tempestade solar é a mesma")


func _quebra_do_gerador() -> void:
	# Cada sol de quebra possível (nunca o da tempestade solar): o gerador quebra ao entrar nele, vindo da noite.
	for sol_q in [2, 4, 5]:
		var m = Missao.new(1, {"sol_solar": 3, "sol_poeira": 5, "sol_quebra": sol_q})
		var quebrou_em := 0
		var guarda := 0
		while m.fase != "relatorio" and guarda < 60:
			guarda += 1
			match m.fase:
				"plano":
					if m.st["gerador_quebrado"] and quebrou_em == 0:
						quebrou_em = m.sol
					m.mudar_q(1)
					m.mudar_q(1)
					m.confirmar_plano()
					if m.eh_sol_solar():
						m.abrigar()
					if m.tarefas.has("gerador"):
						m.iniciar_tarefa("gerador")
					m.avancar(m.turno_s)
				"fim_do_sol":
					m.enviar_a_terra()
				"noite":
					m.avancar(2.0)
		_igual(quebrou_em, sol_q, "a quebra entra no sol %d, e em nenhum antes" % sol_q)
		_igual(m.modos, 0, "quebra no sol %d, consertada: sem modo de segurança" % sol_q)
	# Na tempestade solar a quebra não cai: nem com a URL forçando.
	_igual(Missao.new(1, {"sol_solar": 3, "sol_quebra": 3}).sol_quebra != 3, true, "quebra nunca no sol da tempestade")

	# Sol 1 sem nada; sol 2 com o gerador quebrado.
	var q = Missao.new(1, {"sol_solar": 3, "sol_poeira": 5, "sol_quebra": 2})
	_igual(q.st["gerador_quebrado"], false, "sol 1: gerador inteiro")
	_igual(q.lista_do_turno(), [], "sol 1: lista sem manutenção")
	q.confirmar_plano()
	_igual(q.tarefas, {}, "sol 1: nenhuma tarefa na lista")
	q.avancar(q.turno_s)
	q.enviar_a_terra()
	q.avancar(2.0)
	_igual(q.sol, 2, "chegou ao sol 2")
	_igual(q.st["gerador_quebrado"], true, "sol 2: o gerador quebrou")
	_igual(q.st_inicio["gerador_quebrado"], true, "sol 2: o instantâneo do sol leva o gerador quebrado")
	_igual(q.lista_do_turno(), ["gerador"], "sol 2: o conserto está na lista")
	# A previsão supõe o conserto no turno: o O2 pedido, como com o gerador inteiro.
	q.mudar_q(1)
	_igual(q.previsao()["o2_produzido"], 1, "plano com gerador quebrado: a previsão supõe o conserto")
	q.confirmar_plano()
	_igual(q.tarefas, {"gerador": "pendente"}, "turno: o gerador é a tarefa pendente")
	_igual(q.gerador_quebrado_agora(), true, "gerador quebrado e não consertado")
	# O estado montado à mão (O 0) faz o sol falhar: o reinício volta ao instantâneo, ainda quebrado.
	q.st_inicio["O"] = 0.0
	q.avancar(q.turno_s)
	_igual(q.fase, "seguranca", "gerador não consertado e sem reserva: segurança")
	_igual(q.causa, "oxigenio", "causa: oxigênio")
	_verdade(q.reiniciar_sol(), "reinicia")
	_igual(q.st["gerador_quebrado"], true, "o reinício volta ao gerador quebrado")
	_igual(q.sol_quebra, 2, "o reinício não sorteia de novo")
	_igual(q.lista_do_turno(), ["gerador"], "depois do reinício o conserto segue na lista")

	# Consertado no turno: libera o O2 do mesmo sol, não gasta energia e não conta como ciência.
	# Sol 2, E 6: 6 + 8 - 1 = 13 para dividir; q 2 reserva 4; O = 0 + 2 - 2 = 0 (sem falha).
	var c = Missao.new(1, {"sol_solar": 3, "sol_poeira": 5, "sol_quebra": 2})
	c.montar_sol(2, _st(6, 0, 12, 1.0, true))
	c.mudar_q(1)
	c.mudar_q(1)
	c.confirmar_plano()
	_verdade(c.iniciar_tarefa("gerador"), "o conserto inicia")
	_igual(c.iniciar_tarefa("gerador"), false, "o conserto não inicia de novo")
	c.avancar(5.0)
	_igual(c.progresso_tarefa("gerador"), 0.5, "andamento do conserto")
	_igual(c.ciencia_do_sol(), 0, "consertar não conta como ciência")
	c.avancar(5.0)
	_igual(c.tarefas["gerador"], "feita", "o conserto leva TAREFA_S")
	_igual(c.ciencia_do_sol(), 0, "gerador feito: a ciência segue 0")
	_igual(c.ciencia_ate_agora(), 0, "gerador feito: ciência até agora 0")
	_igual(c.gerador_quebrado_agora(), false, "gerador consertado")
	_igual(c.st["E"], 6.0, "o conserto não gasta energia")
	c.avancar(c.turno_s)
	var rc: Dictionary = c.registros[0]
	_igual(rc["o2_produzido"], 2, "consertado: o O2 do mesmo sol sai")
	_igual(rc["gerador_quebrado"], true, "registro: o gerador estava quebrado")
	_igual(rc["consertou"], true, "registro: consertou")
	_igual(rc["ciencia"], 0, "registro: o conserto não é ciência")
	_igual(rc["feitas"], [], "registro: feitas só de ciência")
	_igual(rc["devolvida"], 0.0, "consertado: nada volta à bateria")
	_igual(rc["depois"], {"E": 9.0, "O": 0.0, "M": 11.0}, "consertado: 13 - 4 = 9 de bateria, O 0 + 2 - 2")
	_igual(c.st_fim["gerador_quebrado"], false, "consertado: o gerador volta a funcionar")
	_igual(c.ciencia_por_sol, [0], "ciência por sol: o conserto não entra")
	c.enviar_a_terra()
	c.avancar(2.0)
	_igual(c.lista_do_turno(), [], "sol seguinte: nada a consertar")
	c.confirmar_plano()
	_igual(c.tarefas, {}, "sol seguinte: a lista não tem o gerador")

	# Não consertado: produz 0, a energia do gerador parado volta e o gerador segue quebrado.
	# Sol 2, E 6, O 4: q 2 reserva 4, sobra 9, volta 4 = 13, o teto guarda 12 e perde 1. O = 4 + 0 - 2 = 2.
	var d = Missao.new(1, {"sol_solar": 3, "sol_poeira": 5, "sol_quebra": 2})
	d.montar_sol(2, _st(6, 4, 12, 1.0, true))
	d.mudar_q(1)
	d.mudar_q(1)
	d.confirmar_plano()
	d.avancar(d.turno_s)
	_igual(d.fase, "fim_do_sol", "gerador não consertado, com reserva: o sol passa")
	var rd: Dictionary = d.registros[0]
	_igual(rd["o2_produzido"], 0, "não consertado: 0 de O2")
	_igual(rd["gerador_quebrado"], true, "registro: gerador quebrado")
	_igual(rd["consertou"], false, "registro: não consertou")
	_igual(rd["devolvida"], 4.0, "não consertado: a energia do gerador parado volta")
	_igual(rd["perdida_no_teto"], 1.0, "não consertado: o teto perde 1")
	_igual(rd["depois"], {"E": 12.0, "O": 2.0, "M": 11.0}, "não consertado: barras depois")
	_igual(d.st_fim["gerador_quebrado"], true, "não consertado: o gerador segue quebrado")
	d.enviar_a_terra()
	d.avancar(2.0)
	_igual(d.sol, 3, "plano do sol 3")
	_igual(d.st["gerador_quebrado"], true, "sol 3: o gerador segue quebrado")
	_igual(d.lista_do_turno(), ["gerador"], "sol 3: o conserto volta à lista")
	d.confirmar_plano()
	_igual(d.tarefas, {"gerador": "pendente"}, "sol 3: o conserto volta à lista do turno")
	_igual(d.sol_quebra, 2, "a quebra é uma só por missão")


func _encerrar_sol() -> void:
	# Fora do turno não vale.
	var p = Missao.new(1, {"sol_solar": 3})
	_igual(p.encerrar_sol(), false, "encerrar: não vale no plano")
	_igual(p.pode_encerrar_sol(), false, "encerrar: o botão não aparece no plano")
	# Lista vazia conta como acabada. Acelera 8 vezes: 1 s de tempo real = 8 s do turno.
	var m = Missao.new(1, {"sol_solar": 3})
	m.confirmar_plano()
	_igual(m.lista_acabou(), true, "lista vazia: acabou")
	_igual(m.pode_encerrar_sol(), true, "lista vazia: dá para encerrar")
	_verdade(m.encerrar_sol(), "encerrar o sol")
	_igual(m.acelerado, true, "acelerado")
	_igual(m.encerrar_sol(), false, "enquanto acelerado, não encerra de novo")
	_igual(m.pode_encerrar_sol(), false, "enquanto acelerado, o botão some")
	m.avancar(0.25)
	_igual(m.t, 2.0, "0,25 s reais correm 2 s do turno (8x)")
	m.avancar(1.0)
	_igual(m.t, 10.0, "1 s real corre 8 s do turno")
	_igual(m.relogio(), 10.0 / 60.0, "o relógio do turno acompanha")
	m.avancar(6.0)
	_igual(m.t, 58.0, "7,25 s reais: 58 s do turno")
	_igual(m.fase, "turno", "ainda no turno aos 58 s")
	m.avancar(0.5)
	_igual(m.fase, "fim_do_sol", "o turno acaba no pôr do Sol, depois de 7,5 s reais")
	_igual(m.acelerado, false, "acelerado desliga no fim do turno")
	_igual(m.registros[0]["dose"], 1.0, "dose do sol comum, em tempo de jogo")
	_igual(m.registros[0]["depois"]["M"], 11.0, "margem 12 - 1")
	# Com tarefa pendente a lista não acabou; depois de feita, sim.
	var t = Missao.new(1, {"sol_solar": 3})
	t.alternar_tarefa("chemcam")
	t.confirmar_plano()
	_igual(t.lista_acabou(), false, "tarefa pendente: a lista não acabou")
	_igual(t.encerrar_sol(), false, "tarefa pendente: não encerra")
	t.iniciar_tarefa("chemcam")
	_igual(t.lista_acabou(), false, "tarefa rodando: a lista não acabou")
	_igual(t.encerrar_sol(), false, "tarefa rodando: não encerra")
	t.avancar(10.0)
	_igual(t.lista_acabou(), true, "tarefa feita: a lista acabou")
	_verdade(t.encerrar_sol(), "tarefa feita: encerra")
	t.avancar(7.0)
	_igual(t.registros[0]["ciencia"], 1, "encerrar cedo não perde a ciência feita")
	# O conserto do gerador também é da lista.
	var g = Missao.new(1, {"sol_solar": 3})
	g.montar_sol(2, _st(6, 4, 12, 1.0, true))
	g.alternar_tarefa("chemcam")
	g.confirmar_plano()
	g.iniciar_tarefa("chemcam")
	g.avancar(10.0)
	_igual(g.lista_acabou(), false, "ciência feita, gerador por consertar: a lista não acabou")
	_igual(g.encerrar_sol(), false, "gerador por consertar: não encerra")
	g.iniciar_tarefa("gerador")
	g.avancar(10.0)
	_igual(g.lista_acabou(), true, "ciência e gerador feitos: a lista acabou")
	_verdade(g.encerrar_sol(), "ciência e gerador feitos: encerra")
	# Abrigado, a lista acabou mesmo com tarefa pendente.
	var a = Missao.new(1, {"sol_solar": 3})
	a.alternar_tarefa("chemcam")
	a.confirmar_plano()
	a.abrigar()
	_igual(a.lista_acabou(), true, "abrigado: a lista acabou")
	_verdade(a.encerrar_sol(), "abrigado: encerra")

	# Sol da tempestade solar, sem tarefa. O medidor pede atenção a partir de 0,4: na rampa 0,15 -> 0,7 de
	# 3 s, isso é 0,25 / 0,55 = 5/11 dela, ou seja, 18/11 s (1,636 s) antes do pico.
	var s = _solar(5, _st(6, 4, 12))
	s.confirmar_plano()
	var tp: float = s.t_pico
	_ate(s, tp - 3.0)
	_igual(s.pode_encerrar_sol(), true, "no comecinho da rampa o medidor está baixo: dá para encerrar")
	_ate(s, tp - 1.5)
	_verdade(s.medidor() >= Missao.LIMIAR_ATENCAO, "a 1,5 s do pico o medidor passa de atenção")
	_igual(s.lista_acabou(), true, "lista vazia acabou")
	_igual(s.encerrar_sol(), false, "alarme fora do abrigo: não encerra")
	_igual(s.pode_encerrar_sol(), false, "alarme fora do abrigo: o botão não aparece")
	_ate(s, tp + 0.001)
	_igual(s.encerrar_sol(), false, "depois do pico, fora do abrigo: não encerra")
	_verdade(s.abrigar(), "abrigar")
	_verdade(s.encerrar_sol(), "abrigado, encerra mesmo com o medidor no alto")

	# Acelerado fora do abrigo: o relógio para quando o medidor chega a atenção, antes do pico.
	var u = _solar(5, _st(6, 4, 12))
	u.confirmar_plano()
	var tpu: float = u.t_pico
	_ate(u, 1.0)
	_verdade(u.encerrar_sol(), "sol da tempestade, medidor baixo: encerra")
	var voltas := 0
	while u.acelerado and voltas < 1000:
		u.avancar(0.25)
		voltas += 1
	_igual(u.acelerado, false, "o relógio acelerado para no limiar de atenção")
	_igual(u.fase, "turno", "parou no turno: o pico segue de surpresa")
	_igual(tpu - u.t, 18.0 / 11.0, "parou 18/11 s antes do pico")
	_igual(u.tempestade_em_curso(), false, "ainda não é o pico")
	_verdade(u.medidor() >= Missao.LIMIAR_ATENCAO - 1e-6, "parou com o medidor em atenção")
	_verdade(u.medidor() < Missao.LIMIAR_ABRIGO, "parou antes do alarme de abrigo")
	_igual(u.t_exposto, 0.0, "parou sem exposição")
	_igual(u.encerrar_sol(), false, "parado em atenção, fora do abrigo: não encerra de novo")
	# A criança decide: abriga e encerra de novo; a dose é a do abrigo na hora.
	_verdade(u.abrigar(), "a criança abriga")
	_verdade(u.encerrar_sol(), "abrigada, encerra de novo")
	u.avancar(100.0)
	_igual(u.fase, "fim_do_sol", "o resto do turno corre acelerado até o pôr do Sol")
	_igual(u.registros[0]["dose"], 3.0, "abrigou a tempo: dose 3")
	_igual(u.registros[0]["f_exposto"], 0.0, "abrigou a tempo: sem exposição")
	_igual(u.registros[0]["depois"]["M"], 9.0, "margem 12 - 3")
	_igual(u.modos, 0, "sem modo de segurança")
	# Um passo gigante acelerado também não passa do limiar.
	var w = _solar(9, _st(6, 4, 12))
	w.confirmar_plano()
	_ate(w, 1.0)
	w.encerrar_sol()
	w.avancar(1000.0)
	_igual(w.acelerado, false, "passo gigante: parou no limiar")
	_igual(w.fase, "turno", "passo gigante: o turno não acabou")
	_igual(w.t, w.t_atencao(), "passo gigante: o relógio parou exatamente no limiar")
	_verdade(w.t < w.t_pico, "passo gigante: antes do pico")
	# Abrigado antes do pico e acelerado: passa direto pelo pico, sem exposição.
	var x = _solar(9, _st(6, 4, 12))
	x.confirmar_plano()
	x.abrigar()
	x.encerrar_sol()
	x.avancar(100.0)
	_igual(x.fase, "fim_do_sol", "abrigado antes do pico: acelera até o fim")
	_igual(x.registros[0]["dose"], 3.0, "abrigado antes do pico e acelerado: dose 3")
	# Abrigou depois de meia exposição (tempo de jogo): a aceleração não muda a dose.
	var y = _solar(9, _st(6, 4, 12))
	y.confirmar_plano()
	_ate(y, y.t_pico + (y.turno_s - y.t_pico) / 2.0)
	y.abrigar()
	_verdade(y.encerrar_sol(), "abrigado depois do pico: encerra")
	y.avancar(100.0)
	_igual(y.registros[0]["dose"], 9.0, "meia exposição, acelerado depois: dose 9")
	_igual(y.registros[0]["depois"]["M"], 3.0, "meia exposição: margem 12 - 9")
	# Um sol sem pico (comum) nunca para a aceleração antes do fim.
	var v = Missao.new(1, {"sol_solar": 3})
	v.confirmar_plano()
	v.encerrar_sol()
	v.avancar(1000.0)
	_igual(v.fase, "fim_do_sol", "sol comum: a aceleração vai até o pôr do Sol")


func _fim_do_sol_noite_e_relatorio() -> void:
	var m = Missao.new(1, {"sol_solar": 3, "sol_poeira": 5, "sol_quebra": 5})
	m.mudar_q(2)
	m.confirmar_plano()
	m.avancar(m.turno_s)
	_igual(m.fase, "fim_do_sol", "fim do sol")
	_igual(m.sol, 1, "ainda é o sol 1")
	_verdade(m.enviar_a_terra(), "enviar à Terra")
	_igual(m.fase, "noite", "depois do envio vem a noite")
	_igual(m.sol, 1, "a noite ainda é do sol 1")
	_igual(m.enviar_a_terra(), false, "não se envia duas vezes")
	m.avancar(1.0)
	_igual(m.fase, "noite", "a noite dura ~1,2 s")
	m.avancar(0.3)
	_igual(m.fase, "plano", "depois da noite, o plano")
	_igual(m.sol, 2, "plano do sol 2")
	# q 2: bateria 13 - 4 = 9; O 4 + 2 - 2 = 4; M 12 - 1 = 11.
	_igual(m.st["E"], 9.0, "o estado novo é o do fim do sol: bateria")
	_igual(m.st["O"], 4.0, "o estado novo: O2")
	_igual(m.st["M"], 11.0, "o estado novo: margem")
	_igual(m.st["gerador_quebrado"], false, "o gerador só quebra no sol sorteado (5)")
	_igual(m.plano_q, 0, "o plano novo começa limpo")
	m.avancar(5.0)
	_igual(m.fase, "plano", "avancar no plano não faz nada")
	# Depois do sol 5, o relatório.
	var f = Missao.new(1, {"sol_solar": 3})
	f.montar_sol(5, _st(6, 4, 12))
	f.mudar_q(1)
	f.confirmar_plano()
	f.avancar(f.turno_s)
	_igual(f.fase, "fim_do_sol", "sol 5 fecha")
	f.enviar_a_terra()
	_igual(f.fase, "relatorio", "depois do sol 5, o relatório")
	_igual(f.jogar_de_novo(), true, "jogar de novo")
	_igual(f.fase, "plano", "missão nova: plano")
	_igual(f.sol, 1, "missão nova: sol 1")
	_igual(f.modos, 0, "missão nova: sem modos")
	_igual(f.registros.size(), 0, "missão nova: sem registros")
	_igual(f.ciencia_total(), 0, "missão nova: sem ciência")
	_igual(f.st["E"], 6.0, "missão nova: estado inicial")
	_verdade(f.sol_solar in [3, 4], "missão nova: novo sorteio válido")
	_verdade(f.sol_poeira in [2, 3, 4, 5] and f.sol_quebra in [2, 3, 4, 5], "missão nova: poeira e quebra sorteadas")
	_verdade(f.sol_quebra != f.sol_solar, "missão nova: a quebra não é no sol da tempestade")
	_igual(f.jogar_de_novo(), false, "só se joga de novo no relatório")


func _aviso() -> void:
	var m = Missao.new(1, {"sol_solar": 3})
	var esperado3 := {1: false, 2: true, 3: true, 4: false, 5: false}
	for s in esperado3:
		m.montar_sol(s, _st(6, 4, 12))
		_igual(m.aviso_ativo(), esperado3[s], "aviso com tempestade no sol 3: sol %d" % s)
	var n = Missao.new(1, {"sol_solar": 4})
	var esperado4 := {1: false, 2: true, 3: true, 4: true, 5: false}
	for s in esperado4:
		n.montar_sol(s, _st(6, 4, 12))
		_igual(n.aviso_ativo(), esperado4[s], "aviso com tempestade no sol 4: sol %d" % s)
	n.montar_sol(4, _st(6, 4, 12))
	_igual(n.eh_sol_solar(), true, "sol 4 é o da tempestade")
	n.montar_sol(3, _st(6, 4, 12))
	_igual(n.eh_sol_solar(), false, "sol 3 não é")


## Joga um sol com a estratégia: q 2, tantas tarefas de ciência quantas couberem, inicia as pendentes
## da lista (o conserto do gerador, se pedido, vem depois da ciência) e abriga quando o medidor passa
## de "abrigo" (e fica abrigado).
func _jogar_sol(m) -> void:
	m.plano_q = 0
	m.mudar_q(1)
	m.mudar_q(1)
	for nome in Missao.TAREFAS:
		m.alternar_tarefa(nome)
	m.confirmar_plano()
	var guarda := 0
	while m.fase == "turno" and guarda < 100000:
		if m.medidor() > Missao.LIMIAR_ABRIGO and not m.abrigado:
			m.abrigar()
		if not m.abrigado and m.tarefa_rodando == "":
			for nome in m.lista_do_turno():
				if m.tarefas[nome] == "pendente":
					m.iniciar_tarefa(nome)
					break
		m.avancar(0.25)
		guarda += 1


## Cinco sóis jogados com a estratégia de _jogar_sol, com os eventos forçados: poeira nos sóis 2 e 3,
## gerador quebrado no 5, tempestade solar no 3 ou no 4. Contas à mão (E, O, M no fim de cada sol):
##   sol 1: dividir 13, q 2 e 3 tarefas (10): E 3, O 4, M 11.
##   sol 2 (poeira): 3 + 0,8 - 1 = 2,8: q 1, nada de ciência: E 0,8, O 3, M 10.
##   sol 3 (poeira): 0,8 + 0,8 - 1 = 0,6: q 0: E 0,6, O 1, M 9 (ou 7, se a tempestade solar for aqui).
##   sol 4: 0,6 + 8 - 1 = 7,6: q 2 e 1 tarefa; O 1 + 2 - 2 = 1; M 8 (ou 6, se a tempestade solar for aqui).
##   sol 5 (gerador quebrado): a ciência cabe em 2 tarefas, o conserto vem depois e libera o O2: O 1.
## Margem final: 12 - 4 sóis comuns (1) - tempestade abrigada a tempo (3) = 5.
func _missao_inteira() -> void:
	for sol_solar in [3, 4]:
		var m = Missao.new(9, {"sol_solar": sol_solar, "sol_poeira": 2, "sol_quebra": 5})
		var sois := 0
		var guarda := 0
		while m.fase != "relatorio" and guarda < 50:
			guarda += 1
			match m.fase:
				"plano":
					_jogar_sol(m)
				"fim_do_sol":
					sois += 1
					m.enviar_a_terra()
				"noite":
					m.avancar(2.0)
				"seguranca":
					if m.tem_conserto:
						m.reiniciar_sol()
					else:
						m.seguir_em_seguranca()
		_igual(m.fase, "relatorio", "missão inteira (tempestade no sol %d) chega ao relatório" % sol_solar)
		_igual(sois, 5, "cinco sóis")
		_igual(m.registros.size(), 5, "cinco registros")
		_igual(m.modos, 0, "estratégia cuidadosa: sem modo de segurança")
		var soma := 0
		for r in m.registros:
			soma += r["ciencia"]
		_igual(m.ciencia_total(), soma, "ciência total é a soma dos sóis")
		_verdade(m.ciencia_total() > 0, "alguma ciência foi feita")
		_igual(m.estrelas(), Modelo.estrelas(0, m.ciencia_total()), "estrelas vêm do modelo")
		# Quatro sóis comuns de 1 e o da tempestade abrigado a tempo (3): 12 - 7 = 5.
		_igual(m.st["M"], 5.0, "margem final com abrigo a tempo")
		var solares := 0
		for r in m.registros:
			if r["tempestade"]:
				solares += 1
				_igual(r["sol"], sol_solar, "o registro da tempestade é do sol certo")
				_igual(r["dose"], 3.0, "abrigo a tempo: dose 3")
			_igual(r["poeira"], r["sol"] == 2 or r["sol"] == 3, "o registro marca a poeira nos sóis 2 e 3 (sol %d)" % r["sol"])
			_igual(r["gerador_quebrado"], r["sol"] == 5, "o registro marca o gerador quebrado no sol 5")
		_igual(solares, 1, "uma tempestade por missão")
		# Na poeira a ciência não cabe; no sol 3, também não.
		_igual(m.registros[1]["ciencia"], 0, "sol 2 (poeira): sem ciência")
		_igual(m.registros[2]["ciencia"], 0, "sol 3 (poeira): sem ciência")
		_igual(m.registros[0]["ciencia"], 3, "sol 1: as 3 tarefas")
		# Sol 5: 2 tarefas de ciência e o conserto, que não conta como ciência e libera o O2.
		_igual(m.registros[4]["ciencia"], 2, "sol 5: 2 de ciência, o conserto não conta")
		_igual(m.registros[4]["consertou"], true, "sol 5: consertou o gerador")
		_igual(m.registros[4]["o2_produzido"], 2, "sol 5: o conserto libera o O2 do mesmo sol")
