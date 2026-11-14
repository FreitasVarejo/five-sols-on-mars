extends SceneTree
## Teste headless do modelo (scripts/modelo.gd).
## Roda com: godot --headless --path . --script tests/test_modelo.gd
## Sai com código 1 se algo falhar e imprime cada falha. Os números esperados foram feitos à mão
## a partir dos números de partida (SOLAR 8, GEN_CUSTO 2, CREW_O2 2, CIENCIA_CUSTO 2, E0 6,
## O0 4, M0 12, AQUEC 1, TETO 12, TANQUE_O2 12), não calculados pela fórmula do modelo.

const Modelo := preload("res://scripts/modelo.gd")

var falhas := 0
var total := 0


func _init() -> void:
	_estado_e_manha()
	_energia_e_teto()
	_ciencia_nao_feita()
	_oxigenio()
	_radiacao()
	_poeira_e_painel()
	_gerador()
	_emergencia()
	_dose_e_estrelas()
	_previsao_e_plano_cabe()
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)


func _igual(obtido, esperado, nome: String) -> void:
	total += 1
	var bate := false
	if (obtido is float or obtido is int) and (esperado is float or esperado is int):
		bate = absf(float(obtido) - float(esperado)) < 1e-9
	else:
		bate = obtido == esperado
	if not bate:
		falhas += 1
		printerr("FALHOU: %s (obtido %s, esperado %s)" % [nome, str(obtido), str(esperado)])


func _estado(st: Dictionary, e: float, o: float, m: float, p: float, quebrado: bool, nome: String) -> void:
	_igual(st["E"], e, nome + ": E")
	_igual(st["O"], o, nome + ": O")
	_igual(st["M"], m, nome + ": M")
	_igual(st["P"], p, nome + ": P")
	_igual(st["gerador_quebrado"], quebrado, nome + ": gerador_quebrado")


func _st(e: float, o: float, m: float, p: float = 1.0, quebrado: bool = false) -> Dictionary:
	return {"E": e, "O": o, "M": m, "P": p, "gerador_quebrado": quebrado}


func _estado_e_manha() -> void:
	var ini := Modelo.estado_inicial()
	_estado(ini, 6.0, 4.0, 12.0, 1.0, false, "estado inicial")
	# Sol 1: painel 8 + bateria 6 = 14, menos 1 de aquecimento = 13.
	var m := Modelo.manha(ini, false)
	_igual(m["renda"], 8.0, "manha sol 1: renda")
	_igual(m["falta_aquecimento"], false, "manha sol 1: falta_aquecimento")
	_igual(m["para_dividir"], 13.0, "manha sol 1: para_dividir")
	# Painel a 0,5: renda 4, 6 + 4 - 1 = 9.
	var m2 := Modelo.manha(_st(6, 4, 12, 0.5), false)
	_igual(m2["renda"], 4.0, "manha painel 0,5: renda")
	_igual(m2["para_dividir"], 9.0, "manha painel 0,5: para_dividir")


func _energia_e_teto() -> void:
	var ini := Modelo.estado_inicial()
	# Nada no plano: sobram 13, o teto corta em 12 e perde 1. O: 4 - 2 = 2. M: 12 - 2 = 10.
	var r := Modelo.fechar_sol(ini, false, 0, 0, 0, 2.0, false)
	_estado(r["st"], 12.0, 2.0, 10.0, 1.0, false, "plano vazio")
	_igual(r["perdida_no_teto"], 1.0, "plano vazio: perdida_no_teto")
	_igual(r["falhas"].size(), 0, "plano vazio: sem falhas")
	_igual(r["para_dividir"], 13.0, "plano vazio: para_dividir")
	_igual(r["renda"], 8.0, "plano vazio: renda")
	# 2 de O2 (4 de energia) e 3 tarefas feitas (6): sobram 3 na bateria. O: 4 + 2 - 2 = 4.
	var r2 := Modelo.fechar_sol(ini, false, 2, 3, 3, 2.0, false)
	_estado(r2["st"], 3.0, 4.0, 10.0, 1.0, false, "q 2, ciência 3 feita")
	_igual(r2["ciencia"], 3, "q 2, ciência 3 feita: ciencia")
	_igual(r2["o2_produzido"], 2, "q 2, ciência 3 feita: o2_produzido")
	_igual(r2["devolvida"], 0.0, "q 2, ciência 3 feita: devolvida")
	_igual(r2["perdida_no_teto"], 0.0, "q 2, ciência 3 feita: perdida_no_teto")


func _ciencia_nao_feita() -> void:
	var ini := Modelo.estado_inicial()
	# q 2, 3 tarefas escolhidas, 1 feita: sobra 3 + devolve 2 * 2 = 4, bateria 7.
	var r := Modelo.fechar_sol(ini, false, 2, 3, 1, 2.0, false)
	_estado(r["st"], 7.0, 4.0, 10.0, 1.0, false, "ciência 1 de 3")
	_igual(r["devolvida"], 4.0, "ciência 1 de 3: devolvida")
	_igual(r["ciencia"], 1, "ciência 1 de 3: ciencia")
	# 3 tarefas escolhidas e nenhuma feita (abrigo): sobra 13 - 6 = 7, devolve 6, dá 13; teto 12, perde 1.
	var r2 := Modelo.fechar_sol(ini, false, 0, 3, 0, 2.0, false)
	_estado(r2["st"], 12.0, 2.0, 10.0, 1.0, false, "ciência 0 de 3")
	_igual(r2["devolvida"], 6.0, "ciência 0 de 3: devolvida")
	_igual(r2["perdida_no_teto"], 1.0, "ciência 0 de 3: perdida_no_teto respeita o teto")
	_igual(r2["ciencia"], 0, "ciência 0 de 3: ciencia")


func _oxigenio() -> void:
	# No tanque até o máximo: O 10 + 6 - 2 = 14, mas o tanque guarda 12.
	var r := Modelo.fechar_sol(_st(6, 10, 12), false, 6, 0, 0, 2.0, false)
	_estado(r["st"], 1.0, 12.0, 10.0, 1.0, false, "tanque cheio")
	# Se já está acima do máximo, não perde o que tem: O 13 + 4 - 2 = 15, fica em 13.
	var r2 := Modelo.fechar_sol(_st(6, 13, 12), false, 4, 0, 0, 2.0, false)
	_igual(r2["st"]["O"], 13.0, "tanque acima do máximo não cai")
	# Dentro do tanque: O 4 + 4 - 2 = 6.
	var r3 := Modelo.fechar_sol(_st(6, 4, 12), false, 4, 0, 0, 2.0, false)
	_igual(r3["st"]["O"], 6.0, "tanque: 4 + 4 - 2 = 6")
	# Falha de oxigênio: O 1 sem produzir, 1 - 2 = -1.
	var f := Modelo.fechar_sol(_st(6, 1, 12), false, 0, 0, 0, 2.0, false)
	_igual(f["st"]["O"], -1.0, "falha de O2: O sai negativo")
	_igual(f["falhas"], ["oxigenio"], "falha de O2: falhas")
	# O 2 sem produzir: chega a 0, não é falha.
	var z := Modelo.fechar_sol(_st(6, 2, 12), false, 0, 0, 0, 2.0, false)
	_igual(z["st"]["O"], 0.0, "O2 chega a 0")
	_igual(z["falhas"].size(), 0, "O2 em 0 não é falha")


func _radiacao() -> void:
	# Margem 2 com dose 2: chega a 0, e 0 já é falha.
	var r := Modelo.fechar_sol(_st(6, 4, 2), false, 0, 0, 0, 2.0, false)
	_igual(r["st"]["M"], 0.0, "margem chega a 0")
	_igual(r["falhas"], ["radiacao"], "margem 0 é falha de radiação")
	# Margem 3: sobra 1, sem falha.
	var s := Modelo.fechar_sol(_st(6, 4, 3), false, 0, 0, 0, 2.0, false)
	_igual(s["st"]["M"], 1.0, "margem 3 - 2 = 1")
	_igual(s["falhas"].size(), 0, "margem 1 sem falha")
	# Dose da tempestade sem abrigo: 12 - 6 = 6.
	var t := Modelo.fechar_sol(_st(6, 4, 12), false, 0, 0, 0, Modelo.dose(true, 1.0), false)
	_igual(t["st"]["M"], 6.0, "tempestade sem abrigo: 12 - 6")


func _poeira_e_painel() -> void:
	# Poeira com bateria vazia: renda 8 * 0,1 = 0,8 < 1 de aquecimento.
	var st := _st(0, 4, 12)
	var m := Modelo.manha(st, true)
	_igual(m["renda"], 0.8, "poeira: renda 0,8")
	_igual(m["falta_aquecimento"], true, "poeira, bateria 0: falta aquecimento")
	_igual(m["para_dividir"], 0.0, "poeira, bateria 0: para_dividir 0")
	var r := Modelo.fechar_sol(st, true, 0, 0, 0, 2.0, false)
	_igual(r["falhas"], ["energia"], "poeira, bateria 0: falha de energia")
	_igual(r["st"]["E"], 0.0, "poeira, bateria 0: E fica 0")
	# Bateria 0,2 + renda 0,8 = 1: cobre o aquecimento, sobra 0.
	var m2 := Modelo.manha(_st(0.2, 4, 12), true)
	_igual(m2["falta_aquecimento"], false, "poeira, bateria 0,2: cobre o aquecimento")
	_igual(m2["para_dividir"], 0.0, "poeira, bateria 0,2: para_dividir 0")
	# Bateria cheia na poeira: 12 + 0,8 - 1 = 11,8.
	var m3 := Modelo.manha(_st(12, 4, 12), true)
	_igual(m3["para_dividir"], 11.8, "poeira, bateria 12: para_dividir 11,8")
	# ACUMULO desligado no P0: o painel não muda.
	var p := Modelo.fechar_sol(_st(6, 4, 12, 0.5), false, 0, 0, 0, 2.0, false)
	_igual(p["st"]["P"], 0.5, "P não muda com ACUMULO 0")


func _gerador() -> void:
	# Quebrado e não consertado, E 2: renda 8, para dividir 9. q 2 reserva 4, sobra 5, e a energia
	# do gerador parado (4) volta: bateria 9. O2 produzido 0, então O = 4 - 2 = 2.
	var quebrado := _st(2, 4, 12, 1.0, true)
	var r := Modelo.fechar_sol(quebrado, false, 2, 0, 0, 2.0, false)
	_estado(r["st"], 9.0, 2.0, 10.0, 1.0, true, "gerador quebrado não consertado")
	_igual(r["o2_produzido"], 0, "gerador quebrado: o2_produzido 0")
	_igual(r["devolvida"], 4.0, "gerador quebrado: devolvida")
	# Consertado no turno: o O2 do mesmo sol sai. Bateria 5, O = 4 + 2 - 2 = 4, gerador volta a funcionar.
	var c := Modelo.fechar_sol(quebrado, false, 2, 0, 0, 2.0, true)
	_estado(c["st"], 5.0, 4.0, 10.0, 1.0, false, "gerador consertado")
	_igual(c["o2_produzido"], 2, "gerador consertado: o2_produzido 2")
	_igual(c["devolvida"], 0.0, "gerador consertado: devolvida 0")
	# Gerador que não estava quebrado: segue sem quebrar, mesmo com consertou = false.
	var ok := Modelo.fechar_sol(_st(2, 4, 12), false, 2, 0, 0, 2.0, false)
	_igual(ok["o2_produzido"], 2, "gerador inteiro produz")
	_igual(ok["st"]["gerador_quebrado"], false, "gerador inteiro segue inteiro")


func _emergencia() -> void:
	# Sol sem ar com gerador quebrado: O 0, 13 para dividir, q = 6. O conserto está no teste:
	# O = 0 + 6 - 2 = 4. Bateria 13 - 12 = 1. Margem 12 - 2 = 10.
	var sem_ar := _st(6, 0, 12, 1.0, true)
	var e := Modelo.emergencia(sem_ar, false, false)
	_igual(e["q"], 6, "emergência: q = 6")
	_igual(e["falhas"].size(), 0, "emergência: sem falhas")
	_estado(e["st"], 1.0, 4.0, 10.0, 1.0, false, "emergência com conserto")
	_igual(Modelo.algum_plano_salva(sem_ar, false, false), true, "sol sem ar com gerador quebrado tem salvação")
	# Sem o conserto o mesmo sol falharia por oxigênio (é o que a spec evita no teste).
	var sem_conserto := Modelo.fechar_sol(sem_ar, false, 6, 0, 0, 2.0, false)
	_igual(sem_conserto["falhas"], ["oxigenio"], "sem conserto o mesmo sol falha por O2")
	# Tempestade solar com abrigo o tempo todo: dose 2. Margem 2.5 -> 0.5, salva.
	_igual(Modelo.algum_plano_salva(_st(6, 4, 2.5), false, true), true, "tempestade, margem 2,5: abrigo salva")
	# Margem 2 não aguenta nem a dose do abrigo (2): zera.
	_igual(Modelo.algum_plano_salva(_st(6, 4, 2), false, true), false, "tempestade, margem 2: nem o abrigo salva")
	_igual(Modelo.emergencia(_st(6, 4, 2), false, true)["falhas"], ["radiacao"], "tempestade, margem 2: falha de radiação")
	# Poeira com bateria vazia: nenhum plano paga o aquecimento.
	_igual(Modelo.algum_plano_salva(_st(0, 4, 12), true, false), false, "poeira, bateria 0: nenhum plano salva")
	# Seguir em segurança: bateria 0 na poeira, O 1 -> -1, M 1 - 2 = -1; os dois sobem ao piso 0.
	var seg := Modelo.seguir_em_seguranca(_st(0, 1, 1), true, false)
	_estado(seg, 0.0, 0.0, 0.0, 1.0, false, "seguir em segurança com piso 0")
	# Sem negativo, o piso não muda nada: o estado é o da emergência.
	var seg2 := Modelo.seguir_em_seguranca(sem_ar, false, false)
	_estado(seg2, 1.0, 4.0, 10.0, 1.0, false, "seguir em segurança sem piso")


func _dose_e_estrelas() -> void:
	_igual(Modelo.dose(false, 0.0), 2.0, "dose sol comum")
	_igual(Modelo.dose(false, 1.0), 2.0, "dose sol comum ignora exposição")
	_igual(Modelo.dose(true, 0.0), 2.0, "dose tempestade abrigada na hora")
	_igual(Modelo.dose(true, 0.5), 4.0, "dose tempestade, meio")
	_igual(Modelo.dose(true, 1.0), 6.0, "dose tempestade sem abrigo")
	_igual(Modelo.dose(true, 0.1), 2.0, "dose tempestade 0,1: 2 + round(0,4)")
	_igual(Modelo.dose(true, 0.2), 3.0, "dose tempestade 0,2: 2 + round(0,8)")
	_igual(Modelo.dose(true, -1.0), 2.0, "dose tempestade limita em 0")
	_igual(Modelo.dose(true, 2.0), 6.0, "dose tempestade limita em 1")
	# 70% de 14 = 9,8: precisa de 10.
	_igual(Modelo.estrelas(0, 10), 3, "estrelas: 0 modos, ciência 10")
	_igual(Modelo.estrelas(0, 9), 2, "estrelas: 0 modos, ciência 9")
	_igual(Modelo.estrelas(0, 14), 3, "estrelas: 0 modos, ciência 14")
	_igual(Modelo.estrelas(1, 14), 2, "estrelas: 1 modo")
	_igual(Modelo.estrelas(2, 0), 2, "estrelas: 2 modos")
	_igual(Modelo.estrelas(3, 14), 1, "estrelas: 3 modos")


func _previsao_e_plano_cabe() -> void:
	var ini := Modelo.estado_inicial()
	# q 2, 3 tarefas: bateria depois do plano 13 - 4 - 6 = 3, nada perdido.
	var p := Modelo.previsao(ini, false, 2, 3)
	_igual(p["bateria_apos_plano"], 3.0, "previsão q 2, ciência 3: bateria")
	_igual(p["perdida_no_teto"], 0.0, "previsão q 2, ciência 3: perdida")
	_estado(p["st"], 3.0, 4.0, 10.0, 1.0, false, "previsão q 2, ciência 3: estado")
	_igual(p["ciencia"], 3, "previsão q 2, ciência 3: ciencia")
	# Plano vazio: 13 depois do plano, o teto guarda 12 e perde 1.
	var v := Modelo.previsao(ini, false, 0, 0)
	_igual(v["bateria_apos_plano"], 12.0, "previsão vazia: bateria")
	_igual(v["perdida_no_teto"], 1.0, "previsão vazia: perdida")
	# Gerador quebrado: mostra 0 de O2; a bateria do plano tira os 4 do gerador (9 - 4 = 5).
	var g := Modelo.previsao(_st(2, 4, 12, 1.0, true), false, 2, 0)
	_igual(g["o2_produzido"], 0, "previsão com gerador quebrado: 0 de O2")
	_igual(g["bateria_apos_plano"], 5.0, "previsão com gerador quebrado: bateria do plano")
	# plano_cabe: 13 para dividir.
	_igual(Modelo.plano_cabe(ini, false, 6, 0), true, "cabe: q 6 (12 de 13)")
	_igual(Modelo.plano_cabe(ini, false, 6, 1), false, "não cabe: q 6 e 1 tarefa (14 de 13)")
	_igual(Modelo.plano_cabe(ini, false, 2, 3), true, "cabe: q 2 e 3 tarefas (10 de 13)")
	_igual(Modelo.plano_cabe(ini, false, 0, 4), false, "não cabe: 4 tarefas passam das vagas")
	_igual(Modelo.plano_cabe(ini, false, -1, 0), false, "não cabe: q negativo")
	_igual(Modelo.plano_cabe(ini, false, 0, -1), false, "não cabe: ciência negativa")
	_igual(Modelo.plano_cabe(_st(0, 4, 12), true, 1, 0), false, "poeira, bateria 0: q 1 não cabe")
	_igual(Modelo.plano_cabe(_st(0, 4, 12), true, 0, 0), true, "poeira, bateria 0: plano vazio cabe")
