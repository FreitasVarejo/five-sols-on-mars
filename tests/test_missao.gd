extends SceneTree
## Teste headless da máquina da missão (scripts/missao.gd).
## Roda com: godot --headless --path . --script tests/test_missao.gd
## Joga a missão pela API, com avancar() em passos, e confere as regras. Sai com código 1 se algo
## falhar e imprime cada falha. Os números do modelo (13 para dividir no sol 1, dose 2 a 6, margem 12)
## estão feitos à mão, como em tests/test_modelo.gd.

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
	_tarefa_nao_feita_e_teto()
	_exposicao_e_dose()
	_seguranca_no_meio_do_turno()
	_seguranca_no_fim_do_turno()
	_seguranca_sem_conserto()
	_aquecimento_e_gerador()
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


## Missão em um sol de tempestade solar (3), com o estado dado, no plano.
func _solar(semente: int, estado: Dictionary):
	var m = Missao.new(semente, {"sol_solar": 3})
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
	# q 1: bateria 13 - 2 = 11; O 4 + 1 - 2 = 3; M 12 - 2 = 10.
	_igual(r["depois"], {"E": 11.0, "O": 3.0, "M": 10.0}, "registro: barras depois")
	_igual(r["dose"], 2.0, "registro: dose do sol comum")
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
	_igual(b.barras_na_fase("fim_do_sol"), {"E": 9.0, "O": 4.0, "M": 10.0}, "barras no fim do sol: o estado depois")
	_igual(b.ciencia_ate_agora(), 0, "ciência até agora sem tarefas")
	# Em fim_do_sol o relógio não anda e as ações do turno não valem.
	_igual(c.alternar_abrigo(), false, "fim do sol: abrigo não vale")
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
	m.alternar_abrigo()  # não deixa a margem zerar
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
	_igual(m.alternar_abrigo(), false, "abrigo não vale no plano")
	m.confirmar_plano()
	_igual(m.tarefas, {"chemcam": "pendente", "amostra": "pendente"}, "tarefas escolhidas começam pendentes")
	_igual(m.iniciar_tarefa("planta"), false, "tarefa não escolhida não inicia")
	_verdade(m.iniciar_tarefa("chemcam"), "tarefa escolhida inicia")
	_igual(m.tarefas["chemcam"], "rodando", "tarefa rodando")
	_igual(m.iniciar_tarefa("amostra"), false, "uma tarefa por vez")
	_igual(m.iniciar_tarefa("chemcam"), false, "tarefa rodando não inicia de novo")
	m.avancar(5.0)
	_igual(m.progresso_tarefa("chemcam"), 0.5, "andamento da tarefa")
	# Abrigo interrompe: volta a pendente e perde o andamento.
	_verdade(m.alternar_abrigo(), "abrigo vale no turno")
	_igual(m.abrigado, true, "abrigado")
	_igual(m.tarefas["chemcam"], "pendente", "abrigo interrompe a tarefa")
	_igual(m.tarefa_rodando, "", "nenhuma tarefa rodando abrigado")
	_igual(m.progresso_tarefa("chemcam"), 0.0, "abrigo zera o andamento")
	_igual(m.iniciar_tarefa("chemcam"), false, "abrigado não inicia tarefa")
	m.avancar(20.0)
	_igual(m.tarefas["chemcam"], "pendente", "abrigado o tempo passa e a tarefa não anda")
	# Fora do abrigo recomeça do zero: precisa dos TAREFA_S inteiros.
	m.alternar_abrigo()
	_igual(m.abrigado, false, "abrigo desfeito")
	_verdade(m.iniciar_tarefa("chemcam"), "depois do abrigo a tarefa inicia")
	m.avancar(9.9)
	_igual(m.tarefas["chemcam"], "rodando", "aos 9,9 s ainda roda")
	m.avancar(0.2)
	_igual(m.tarefas["chemcam"], "feita", "roda TAREFA_S e vira feita")
	_igual(m.ciencia_do_sol(), 1, "feita rende +1 de ciência")
	_igual(m.iniciar_tarefa("chemcam"), false, "tarefa feita não inicia de novo")
	_verdade(m.iniciar_tarefa("amostra"), "a outra inicia depois")
	# O abrigo é só tempo, não energia: a bateria do estado não muda no turno.
	_igual(m.st["E"], 6.0, "o turno não mexe no estado do sol")
	# Abrigo em sol comum também vale e é reversível a qualquer momento.
	_verdade(m.alternar_abrigo(), "abrigo no sol comum")
	_verdade(m.alternar_abrigo(), "abrigo desligado no sol comum")


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
	# Exposta o tempo todo: f = 1, dose 6. Margem 12 -> 6; ao vivo cai 4 (12 -> 8) e fecha em 6.
	var m = _solar(11, _st(6, 4, 12))
	m.confirmar_plano()
	var tp: float = m.t_pico
	_ate(m, tp - 0.05)
	_igual(m.f_exposto(), 0.0, "antes do pico não há exposição")
	_igual(m.margem_ao_vivo(), 12.0, "antes do pico a margem é a do estado")
	_ate(m, tp + (m.turno_s - tp) / 2.0)
	_igual(m.f_exposto(), 0.5, "meio do pós-pico exposto: f 0,5")
	_igual(m.queda_ao_vivo(), 2, "f 0,5: a margem ao vivo caiu round(4 * 0,5) = 2")
	_igual(m.margem_ao_vivo(), 10.0, "margem ao vivo 12 - 2")
	_ate_sair_do_turno(m, 0.05)
	_igual(m.fase, "fim_do_sol", "exposto o tempo todo com margem 12 passa")
	var r: Dictionary = m.registros[0]
	_igual(r["tempestade"], true, "registro: sol da tempestade")
	_igual(r["dose"], 6.0, "dose sem abrigo: 6")
	_igual(r["depois"]["M"], 6.0, "margem 12 - 6")
	_igual(r["abrigou"], false, "registro: não abrigou")
	# Abrigou antes do pico: f 0, dose 2.
	var a = _solar(11, _st(6, 4, 12))
	a.confirmar_plano()
	a.alternar_abrigo()
	_ate_sair_do_turno(a, 0.05)
	_igual(a.registros[0]["dose"], 2.0, "abrigado antes do pico: dose 2")
	_igual(a.registros[0]["depois"]["M"], 10.0, "abrigado antes do pico: margem 10")
	_igual(a.registros[0]["abrigou"], true, "registro: abrigou")
	_igual(a.registros[0]["f_exposto"], 0.0, "registro: f 0")
	# Abrigou na metade do pós-pico: f 0,5, dose 2 + round(2) = 4.
	var b = _solar(11, _st(6, 4, 12))
	b.confirmar_plano()
	_ate(b, b.t_pico + (b.turno_s - b.t_pico) / 2.0)
	b.alternar_abrigo()
	_ate_sair_do_turno(b, 0.05)
	_igual(b.registros[0]["dose"], 4.0, "abrigou no meio: dose 4")
	_igual(b.registros[0]["depois"]["M"], 8.0, "abrigou no meio: margem 8")
	# Só o tempo depois do pico conta: abrigar e desabrigar antes do pico não muda nada.
	var c = _solar(11, _st(6, 4, 12))
	c.confirmar_plano()
	c.alternar_abrigo()
	_ate(c, c.t_pico - 1.0)
	c.alternar_abrigo()  # sai do abrigo antes do pico
	_ate_sair_do_turno(c, 0.05)
	_igual(c.registros[0]["dose"], 6.0, "saiu do abrigo antes do pico: exposto depois dele, dose 6")
	# Passo grande que cruza o pico conta só a parte depois dele.
	var d = _solar(11, _st(6, 4, 12))
	d.confirmar_plano()
	var tpd: float = d.t_pico
	d.avancar(tpd + 3.0)
	_igual(d.t_exposto, 3.0, "o passo que cruza o pico conta só 3 s depois dele")
	# Sol comum: exposição não existe e a dose é 2 de qualquer jeito.
	var e = Missao.new(1, {"sol_solar": 3})
	e.confirmar_plano()
	e.avancar(100.0)
	_igual(e.registros[0]["dose"], 2.0, "sol comum: dose 2")
	_igual(e.f_exposto(), 0.0, "sol comum: f 0")


func _seguranca_no_meio_do_turno() -> void:
	# Margem 3 exposta: a margem ao vivo (3 - round(4 f)) zera em f 0,625 e o modo entra ali.
	var m = _solar(21, _st(6, 4, 3))
	m.confirmar_plano()
	_ate_sair_do_turno(m, 0.05)
	_igual(m.fase, "seguranca", "margem ao vivo zerada: modo de segurança no meio do turno")
	_verdade(m.t < m.turno_s - 1.0, "entrou antes do fim do turno")
	_igual(m.causa, "radiacao", "causa: radiação")
	_igual(m.modos, 1, "uma entrada soma 1 em modos")
	_igual(m.causa_sem_abrigo, true, "não abrigou a tempo")
	_igual(m.barras_falha, {"E": 6.0, "O": 4.0, "M": 0.0}, "barras da falha: margem em 0")
	_igual(m.tem_conserto, true, "margem 3: o abrigo salva, tem conserto")
	_igual(m.seguir_em_seguranca(), false, "com conserto não se segue")
	_igual(m.registros.size(), 0, "o sol que falhou não vira registro")
	_igual(m.ciencia_por_sol, [], "o sol que falhou não conta ciência")
	# Reinicia: volta ao plano do mesmo sol, com o instantâneo, e o modo fica contado.
	_verdade(m.reiniciar_sol(), "reiniciar o sol")
	_igual(m.fase, "plano", "reiniciou no plano")
	_igual(m.sol, 3, "reiniciou o mesmo sol")
	_igual(m.sol_solar, 3, "o sol da tempestade se mantém")
	_igual(m.st["M"], 3.0, "reiniciou com o instantâneo")
	_igual(m.modos, 1, "reiniciar não zera os modos")
	_igual(m.plano_q, 0, "reiniciou com plano limpo")
	_igual(m.t_pico, -1.0, "o pico só é sorteado ao confirmar")
	# Agora abriga na hora e passa: o pico é sorteado de novo.
	var picos := {}
	for i in 6:
		var n = _solar(21 + i, _st(6, 4, 3))
		n.confirmar_plano()
		_ate_sair_do_turno(n, 0.5)
		if n.fase == "seguranca":
			n.reiniciar_sol()
			n.confirmar_plano()
			picos[snappedf(n.t_pico, 0.001)] = true
			_verdade(n.t_pico >= Missao.PICO_MIN * n.turno_s - 1e-9 and n.t_pico <= Missao.PICO_MAX * n.turno_s + 1e-9, "pico re-sorteado dentro da faixa")
	_verdade(picos.size() > 1, "o pico é re-sorteado quando o sol reinicia")
	m.confirmar_plano()
	m.alternar_abrigo()
	_ate_sair_do_turno(m, 0.05)
	_igual(m.fase, "fim_do_sol", "abrigado, passa: margem 3 - 2 = 1")
	_igual(m.registros[0]["depois"]["M"], 1.0, "margem 1")
	_igual(m.modos, 1, "o sol que passou não soma modo")
	# O instantâneo é o do começo do sol, não o do plano: ciência de uma tentativa que falhou não vaza.
	var z = _solar(21, _st(6, 4, 3))
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
	# Radiação no fim do turno, sem queda ao vivo: margem 2 abrigado no sol da tempestade dá 0.
	var r = _solar(31, _st(6, 4, 2))
	r.confirmar_plano()
	r.alternar_abrigo()
	_ate_sair_do_turno(r, 0.05)
	_igual(r.fase, "seguranca", "margem 2 e dose 2 abrigado: falha de radiação no fim")
	_igual(r.causa, "radiacao", "causa radiação no fim do turno")
	_igual(r.causa_sem_abrigo, false, "abrigou: sem a frase do abrigo")
	_igual(r.tem_conserto, false, "margem 2: nem o abrigo salva")
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
	# Margem 2 no sol da tempestade exposta: a margem ao vivo zera no meio; não há plano que salve.
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
	# Estado = Modelo.seguir_em_seguranca do instantâneo: margem 2 - 2 = 0 (piso 0).
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
	# Nada quebra o gerador no P0: jogando normal, ele segue inteiro.
	var n = Missao.new(1, {"sol_solar": 3})
	n.mudar_q(2)
	n.confirmar_plano()
	n.avancar(n.turno_s)
	_igual(n.st_fim["gerador_quebrado"], false, "gerador não quebra sozinho")


func _fim_do_sol_noite_e_relatorio() -> void:
	var m = Missao.new(1, {"sol_solar": 3})
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
	# q 2: bateria 13 - 4 = 9; O 4 + 2 - 2 = 4; M 10.
	_igual(m.st["E"], 9.0, "o estado novo é o do fim do sol: bateria")
	_igual(m.st["O"], 4.0, "o estado novo: O2")
	_igual(m.st["M"], 10.0, "o estado novo: margem")
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


## Joga um sol com a estratégia: q 2, tantas tarefas quantas couberem, inicia as pendentes e abriga
## quando o medidor passa de "abrigo" (e fica abrigado).
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
			m.alternar_abrigo()
		if not m.abrigado and m.tarefa_rodando == "":
			for nome in m.plano_tarefas:
				if m.tarefas[nome] == "pendente":
					m.iniciar_tarefa(nome)
					break
		m.avancar(0.25)
		guarda += 1


func _missao_inteira() -> void:
	for sol_solar in [3, 4]:
		var m = Missao.new(9, {"sol_solar": sol_solar})
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
		# Dose: quatro sóis comuns de 2 e o da tempestade abrigado a tempo (2): 12 - 10 = 2.
		_igual(m.st["M"], 2.0, "margem final com abrigo a tempo")
		var solares := 0
		for r in m.registros:
			if r["tempestade"]:
				solares += 1
				_igual(r["sol"], sol_solar, "o registro da tempestade é do sol certo")
		_igual(solares, 1, "uma tempestade por missão")
