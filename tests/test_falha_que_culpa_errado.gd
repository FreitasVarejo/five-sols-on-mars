extends SceneTree
## Teste de aceite da task "falha-que-culpa-errado" (spec, "Falha e relatório").
## Roda com: godot --headless --path . --script tests/test_falha_que_culpa_errado.gd
## Joga a missão pela API de scripts/missao.gd e lê textos/textos.csv direto. Sai com código 1 se algo
## falhar e imprime cada falha. Os números estão feitos à mão a partir de modelo.gd: 13 para dividir no
## sol 1, O2 e ciência a 2 de energia cada, aquecimento 1, painel a 10% na poeira (sóis 3 e 4), dose 1
## no sol comum e, no sol da tempestade solar, 3 + round(12 * exposição / 35) com o pico aos 25 s de 60 s.
##
## Caso 1: a causa pelo contexto ("plano" quando havia plano que salvava; "poeira" só sem conserto).
## Caso 2: previsao()["sem_reserva"], o aviso de bateria abaixo do aquecimento da noite.
## Caso 3: o abrigo tardio falha no próprio sol da tempestade solar.

const Missao := preload("res://scripts/missao.gd")
const Modelo := preload("res://scripts/modelo.gd")

const PASSO := 0.25  # exato em binário: o relógio cai em cima do pico (25 s) e de cada atraso inteiro
const CSV := "res://textos/textos.csv"
const MAX_PALAVRAS := 8

var falhas := 0
var total := 0
var _caso := ""
var _por_caso := {}  # caso -> [verificações, falhas]


func _init() -> void:
	_caso = "caso 1"
	_c1_plano_em_sol_de_poeira()
	_c1_plano_na_missao_jogada()
	_c1_plano_fora_da_poeira()
	_c1_gerador_continua()
	_c1_poeira_continua()
	_c1_sem_contexto_continua()
	_c1_sem_abrigo_continua()
	_c1_textos()
	_caso = "caso 2"
	_c2_sol_1_nenhum_plano_avisa()
	_c2_sol_2_na_missao_jogada()
	_c2_limiar_na_poeira()
	_c2_ultimo_sol()
	_c2_texto()
	_c2_tarefa_nao_feita_volta_a_bateria()
	_caso = "caso 3"
	_c3_abrigo_13_s_passa()
	for atraso in [14.0, 17.0, 20.0]:
		_c3_abrigo_tardio(atraso)
	_c3_abrigo_22_s_continua()
	_c3_abrigo_na_hora_nao_dispara()
	_c3_conta_os_sois_que_faltam()
	_c3_sol_comum_nao_dispara()
	_c3_calibracao()
	for c in _por_caso:
		print("%s: %d verificações, %d falhas" % [c, _por_caso[c][0], _por_caso[c][1]])
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)


# --- helpers -------------------------------------------------------------------

func _igual(obtido, esperado, nome: String) -> void:
	total += 1
	if not _por_caso.has(_caso):
		_por_caso[_caso] = [0, 0]
	_por_caso[_caso][0] += 1
	var bate := false
	if (obtido is float or obtido is int) and (esperado is float or esperado is int):
		bate = absf(float(obtido) - float(esperado)) < 1e-6
	elif typeof(obtido) == typeof(esperado):
		bate = obtido == esperado
	if not bate:
		falhas += 1
		_por_caso[_caso][1] += 1
		printerr("FALHOU [%s]: %s (obtido %s, esperado %s)" % [_caso, nome, str(obtido), str(esperado)])


func _verdade(valor: bool, nome: String) -> void:
	_igual(valor, true, nome)


func _st(e: float, o: float, m: float, p: float = 1.0, quebrado: bool = false) -> Dictionary:
	return {"E": e, "O": o, "M": m, "P": p, "gerador_quebrado": quebrado}


## Monta o plano pela API (como a tela faz): `q` de O2 e as `n` primeiras tarefas de ciência.
func _planejar(m, q: int, n: int) -> void:
	for i in q:
		m.mudar_q(1)
	for i in n:
		m.alternar_tarefa(Missao.TAREFAS[i])


## Joga o turno até a fase mudar. `feitas`: quantas tarefas de ciência do plano a peça conclui (no
## começo do turno). `atraso`: segundos depois do pico até o toque no abrigo (0 = na hora; < 0 = nunca
## abriga). `consertar`: faz o conserto do gerador, se a base pedir.
func _turno(m, feitas: int, atraso: float, consertar: bool = true) -> void:
	if consertar and m.tarefas.has("gerador"):
		m.iniciar_tarefa("gerador")
		m.concluir_tarefa("gerador")
	var k := 0
	for nome in m.plano_tarefas:
		if k >= feitas:
			break
		m.iniciar_tarefa(nome)
		m.concluir_tarefa(nome)
		k += 1
	var guarda := 0
	while m.fase == "turno" and guarda < 100000:
		guarda += 1
		if m.eh_sol_solar() and atraso >= 0.0 and not m.abrigado and m.t >= m.t_pico + atraso:
			m.abrigar()
		m.avancar(PASSO)


## Plano, "Confirmar plano" e o turno inteiro.
func _sol(m, q: int, n: int, feitas: int, atraso: float, consertar: bool = true) -> void:
	_planejar(m, q, n)
	m.confirmar_plano()
	_turno(m, feitas, atraso, consertar)


## "Enviar à Terra" e a noite, até o plano (ou o modo de segurança antecipado) do sol seguinte.
func _noite(m) -> void:
	m.enviar_a_terra()
	var guarda := 0
	while m.fase == "noite" and guarda < 1000:
		guarda += 1
		m.avancar(0.5)


## Leva a missão até o relatório com um plano que só sobrevive (O2 +2, sem ciência, conserto do gerador
## e abrigo na hora). Cada entrada em modo de segurança no caminho vai para `entradas`, como
## [sol, causa, contexto]; com conserto reinicia o sol, sem conserto segue em modo de segurança.
func _seguir_ate_relatorio(m, entradas: Array) -> void:
	var guarda := 0
	while m.fase != "relatorio" and guarda < 60:
		guarda += 1
		match m.fase:
			"seguranca":
				entradas.append([m.sol, m.causa, m.causa_contexto()])
				if m.tem_conserto:
					m.reiniciar_sol()
				else:
					m.seguir_em_seguranca()
			"plano":
				_sol(m, 2, 0, 0, 0.0)
			"turno":
				_turno(m, 0, 0.0)
			"fim_do_sol", "noite":
				_noite(m)


## A missão fixa no plano do sol 2, com o sol 1 jogado em `q` de O2 e `n` tarefas, todas feitas.
func _no_plano_do_sol_2(q: int, n: int):
	var m = Missao.new(1, {})
	_sol(m, q, n, n, 0.0)
	_noite(m)
	return m


func _ler_textos() -> Dictionary:
	var d := {}
	var f := FileAccess.open(CSV, FileAccess.READ)
	if f == null:
		return d
	var cab := f.get_csv_line()
	var i_en := cab.find("en")
	var i_pt := cab.find("pt")
	if i_en < 0 or i_pt < 0:
		return d
	while not f.eof_reached():
		var l := f.get_csv_line()
		if l.size() <= maxi(i_en, i_pt) or l[0] == "":
			continue
		d[l[0]] = {"en": l[i_en], "pt": l[i_pt]}
	return d


## Palavras de um texto: os pedaços entre espaços que têm ao menos uma letra ou um algarismo.
func _palavras(texto: String) -> int:
	var n := 0
	for pedaco in texto.replace("\n", " ").replace("\t", " ").split(" ", false):
		for c in pedaco:
			if c.to_lower() != c.to_upper() or (c >= "0" and c <= "9"):
				n += 1
				break
	return n


## A frase mais comprida do texto, em palavras (frases separadas por ponto; "!" e "?" também fecham frase).
func _maior_frase(texto: String) -> int:
	var maior := 0
	for frase in texto.replace("!", ".").replace("?", ".").split(".", false):
		maior = maxi(maior, _palavras(frase))
	return maior


func _texto(textos: Dictionary, chave: String, lingua: String) -> String:
	return String(textos.get(chave, {}).get(lingua, "")).strip_edges()


# --- caso 1: o contexto da causa ----------------------------------------------

## O cenário do erro: sol de poeira com a bateria em 8 (7,8 para dividir), plano sem O2. Havia plano
## que salvava (O2 +2), então a causa é o plano, e não a poeira.
func _c1_plano_em_sol_de_poeira() -> void:
	var m = Missao.new(1, {})
	m.montar_sol(3, _st(8.0, 0.0, 8.0))
	_verdade(m.eh_poeira(), "c1 poeira: o sol 3 da missão fixa é de poeira")
	_igual(m.fase, "plano", "c1 poeira: o sol montado começa no plano (algum plano salva)")
	_igual(m.para_dividir(), 7.8, "c1 poeira: 7,8 para dividir")
	_sol(m, 0, 0, 0, -1.0)
	_igual(m.fase, "seguranca", "c1 poeira: plano sem O2 leva ao modo de segurança")
	_igual(m.causa, "oxigenio", "c1 poeira: a barra que zerou é o oxigênio")
	_igual(m.tem_conserto, true, "c1 poeira: havia plano que salvava")
	_igual(m.causa_contexto(), "plano", "c1 poeira: com conserto, o contexto é o plano, não a poeira")
	_igual(m.caso_real(), "oxigenio", "c1 poeira: o caso real do contexto plano é o do oxigênio")
	# "Havia conserto" é verdade: o mesmo sol, reiniciado, passa com O2 +2.
	_verdade(m.reiniciar_sol(), "c1 poeira: o sol reinicia")
	_sol(m, 2, 0, 0, -1.0)
	_igual(m.fase, "fim_do_sol", "c1 poeira: reiniciado com O2 +2, o sol passa")


## O mesmo erro chegando pela missão fixa jogada: tudo em ciência e O2 zero nos sóis 1 e 2 (abrigo na
## hora), O2 zero de novo no sol 3.
func _c1_plano_na_missao_jogada() -> void:
	var m = _no_plano_do_sol_2(0, 3)
	_sol(m, 0, 3, 3, 0.0)
	_noite(m)
	_igual(m.sol, 3, "c1 jogada: chegou ao sol 3")
	_igual(m.fase, "plano", "c1 jogada: o sol 3 começa no plano")
	_igual(m.st["E"], 8.0, "c1 jogada: bateria 8 no começo do sol 3")
	_igual(m.st["O"], 0.0, "c1 jogada: oxigênio 0 no começo do sol 3")
	_sol(m, 0, 0, 0, -1.0)
	_igual(m.fase, "seguranca", "c1 jogada: sem O2 no sol 3, modo de segurança")
	_igual(m.causa, "oxigenio", "c1 jogada: causa oxigênio")
	_igual(m.tem_conserto, true, "c1 jogada: havia conserto")
	_igual(m.causa_contexto(), "plano", "c1 jogada: contexto plano")


## "plano" vale em qualquer sol, com ou sem poeira, e também com o gerador já consertado.
func _c1_plano_fora_da_poeira() -> void:
	var m = Missao.new(1, {})
	m.montar_sol(1, _st(6.0, 0.0, 12.0))
	_verdade(not m.eh_poeira(), "c1 sem poeira: o sol 1 não é de poeira")
	_igual(m.fase, "plano", "c1 sem poeira: começa no plano")
	_sol(m, 0, 0, 0, -1.0)
	_igual(m.fase, "seguranca", "c1 sem poeira: plano sem O2 leva ao modo de segurança")
	_igual(m.causa, "oxigenio", "c1 sem poeira: causa oxigênio")
	_igual(m.tem_conserto, true, "c1 sem poeira: havia conserto")
	_igual(m.causa_contexto(), "plano", "c1 sem poeira: contexto plano fora da poeira")
	_igual(m.caso_real(), "oxigenio", "c1 sem poeira: caso real do oxigênio")
	# Gerador quebrado no começo do sol, consertado no turno, e o plano sem O2: a culpa é do plano.
	var g = Missao.new(1, {})
	g.montar_sol(5, _st(8.0, 1.0, 6.0, 1.0, true))
	_igual(g.fase, "plano", "c1 consertado: começa no plano")
	_sol(g, 0, 0, 0, -1.0, true)
	_igual(g.tarefas.get("gerador", ""), "feita", "c1 consertado: o gerador foi consertado no turno")
	_igual(g.fase, "seguranca", "c1 consertado: sem O2 no plano, modo de segurança")
	_igual(g.causa, "oxigenio", "c1 consertado: causa oxigênio")
	_igual(g.tem_conserto, true, "c1 consertado: havia conserto")
	_igual(g.causa_contexto(), "plano", "c1 consertado: com o gerador consertado, o contexto é o plano")


## O gerador quebrado que ninguém consertou continua "gerador", fora e dentro da poeira.
func _c1_gerador_continua() -> void:
	var m = Missao.new(1, {})
	m.montar_sol(5, _st(8.0, 1.0, 6.0, 1.0, true))
	_sol(m, 1, 0, 0, -1.0, false)
	_igual(m.fase, "seguranca", "c1 gerador: sem o conserto, modo de segurança")
	_igual(m.causa, "oxigenio", "c1 gerador: causa oxigênio")
	_igual(m.tem_conserto, true, "c1 gerador: consertar salvava")
	_igual(m.causa_contexto(), "gerador", "c1 gerador: contexto gerador")
	_igual(m.caso_real(), "oxigenio", "c1 gerador: caso real do oxigênio")
	var p = Missao.new(1, {})
	p.montar_sol(3, _st(8.0, 1.0, 8.0, 1.0, true))
	_verdade(p.eh_poeira(), "c1 gerador na poeira: sol de poeira")
	_igual(p.fase, "plano", "c1 gerador na poeira: começa no plano")
	_sol(p, 1, 0, 0, -1.0, false)
	_igual(p.fase, "seguranca", "c1 gerador na poeira: sem o conserto, modo de segurança")
	_igual(p.tem_conserto, true, "c1 gerador na poeira: consertar salvava")
	_igual(p.causa_contexto(), "gerador", "c1 gerador na poeira: contexto gerador, nem plano nem poeira")


## "poeira" continua quando nenhum plano salvava o sol de poeira: bateria vazia (energia) e oxigênio
## que nem o plano de emergência cobre.
func _c1_poeira_continua() -> void:
	var m = Missao.new(1, {})
	m.montar_sol(4, _st(0.0, 4.0, 12.0))
	_igual(m.fase, "seguranca", "c1 poeira/energia: bateria vazia na poeira falha na manhã")
	_igual(m.causa, "energia", "c1 poeira/energia: causa energia")
	_igual(m.tem_conserto, false, "c1 poeira/energia: nenhum plano salva")
	_igual(m.causa_contexto(), "poeira", "c1 poeira/energia: contexto poeira")
	_igual(m.caso_real(), "energia", "c1 poeira/energia: caso real da energia")
	var o = Missao.new(1, {})
	o.montar_sol(3, _st(1.0, 0.0, 8.0))
	_igual(o.fase, "seguranca", "c1 poeira/oxigênio: 0,8 para dividir e O2 zero falha antes do plano")
	_igual(o.causa, "oxigenio", "c1 poeira/oxigênio: causa oxigênio")
	_igual(o.tem_conserto, false, "c1 poeira/oxigênio: nem o plano de emergência salva")
	_igual(o.causa_contexto(), "poeira", "c1 poeira/oxigênio: sem conserto, o contexto continua poeira")
	# Pela missão fixa jogada: O2 +2 e as 3 tarefas feitas nos sóis 1 e 2 zeram a bateria antes da poeira.
	var j = _no_plano_do_sol_2(2, 3)
	_sol(j, 2, 3, 3, 0.0)
	_noite(j)
	_igual(j.sol, 3, "c1 poeira/jogada: chegou ao sol 3")
	_igual(j.fase, "seguranca", "c1 poeira/jogada: o sol 3 abre em modo de segurança")
	_igual(j.causa, "energia", "c1 poeira/jogada: causa energia")
	_igual(j.tem_conserto, false, "c1 poeira/jogada: nenhum plano salva")
	_igual(j.causa_contexto(), "poeira", "c1 poeira/jogada: contexto poeira")


## Oxigênio sem conserto fora da poeira: nem "poeira" (o sol não é de poeira), nem "plano" (não havia plano).
func _c1_sem_contexto_continua() -> void:
	var m = Missao.new(1, {})
	m.montar_sol(1, _st(0.0, 0.0, 12.0, 0.3))
	_igual(m.fase, "seguranca", "c1 sem contexto: 1,4 para dividir e O2 zero falha antes do plano")
	_igual(m.causa, "oxigenio", "c1 sem contexto: causa oxigênio")
	_igual(m.tem_conserto, false, "c1 sem contexto: nenhum plano salva")
	_igual(m.causa_contexto(), "", "c1 sem contexto: fora da poeira e sem conserto, não há contexto")


## "sem_abrigo" continua: sem abrigo nenhum no sol da tempestade solar, a margem zera no meio do turno.
func _c1_sem_abrigo_continua() -> void:
	var m = _no_plano_do_sol_2(1, 1)
	_sol(m, 1, 1, 1, -1.0)
	_igual(m.sol, 2, "c1 sem abrigo: ainda no sol 2")
	_igual(m.fase, "seguranca", "c1 sem abrigo: modo de segurança")
	_verdade(m.t < m.turno_s - 1.0, "c1 sem abrigo: entrou no meio do turno")
	_igual(m.causa, "radiacao", "c1 sem abrigo: causa radiação")
	_igual(m.causa_contexto(), "sem_abrigo", "c1 sem abrigo: contexto sem_abrigo")
	_igual(m.caso_real(), "radiacao", "c1 sem abrigo: caso real da radiação")
	_igual(m.tem_conserto, true, "c1 sem abrigo: reinicia o sol")


func _c1_textos() -> void:
	var textos := _ler_textos()
	_verdade(not textos.is_empty(), "c1 textos: o CSV foi lido")
	for lingua in ["en", "pt"]:
		_verdade(_texto(textos, "CAUSA_PLANO", lingua) != "", "c1 textos: CAUSA_PLANO existe e não é vazio (%s)" % lingua)
		_verdade(_texto(textos, "CAUSA_POEIRA", lingua) != "", "c1 textos: CAUSA_POEIRA existe e não é vazio (%s)" % lingua)
		for chave in ["CAUSA_PLANO", "CAUSA_POEIRA"]:
			_verdade(_maior_frase(_texto(textos, chave, lingua)) <= MAX_PALAVRAS,
				"c1 textos: %s (%s) tem no máximo %d palavras por frase (a maior tem %d)" % [chave, lingua, MAX_PALAVRAS, _maior_frase(_texto(textos, chave, lingua))])
	var poeira_en := _texto(textos, "CAUSA_POEIRA", "en").to_lower()
	var poeira_pt := _texto(textos, "CAUSA_POEIRA", "pt").to_lower()
	_verdade(not poeira_en.contains("generator"), "c1 textos: CAUSA_POEIRA (en) não fala do gerador")
	_verdade(not poeira_en.contains("oxygen"), "c1 textos: CAUSA_POEIRA (en) não fala de oxigênio")
	_verdade(not poeira_pt.contains("gerador"), "c1 textos: CAUSA_POEIRA (pt) não fala do gerador")
	_verdade(not poeira_pt.contains("oxigênio") and not poeira_pt.contains("oxigenio"), "c1 textos: CAUSA_POEIRA (pt) não fala de oxigênio")
	# Spec, "Missão e sol" (dono, 15/11): no inglês, "energy" também nas causas, nunca "power".
	for chave in ["CAUSA_PLANO", "CAUSA_POEIRA"]:
		_verdade(not _texto(textos, chave, "en").to_lower().contains("power"), "c1 textos: %s (en) diz energy, nunca power" % chave)


# --- caso 2: bateria sem reserva -----------------------------------------------

## No plano do sol 1 (13 para dividir), nenhum plano que cabe deixa a bateria abaixo do aquecimento:
## o gasto máximo é 12, e sobrar exatamente o aquecimento (1) não é "sem reserva".
func _c2_sol_1_nenhum_plano_avisa() -> void:
	var cabem := 0
	for q in 8:
		for n in 4:
			var m = Missao.new(1, {})
			if not m.plano_cabe(q, n):
				continue
			cabem += 1
			_planejar(m, q, n)
			_igual(m.previsao().get("sem_reserva", null), false, "c2 sol 1: plano q%d com %d tarefas não avisa" % [q, n])
	_verdade(cabem > 0, "c2 sol 1: há planos que cabem")
	var limite = Missao.new(1, {})
	_planejar(limite, 6, 0)
	_igual(limite.plano_q, 6, "c2 sol 1: o plano de O2 +6 cabe")
	_igual(limite.previsao()["bateria_apos_plano"], 1.0, "c2 sol 1: com O2 +6 sobra 1, o aquecimento da noite")
	_igual(limite.previsao().get("sem_reserva", null), false, "c2 sol 1: sobrar o aquecimento exato não é sem reserva")


## A missão fixa jogada: sol 1 com O2 +2 e as 3 tarefas feitas deixa a bateria em 3; o sol 2 tem 10
## para dividir.
func _c2_sol_2_na_missao_jogada() -> void:
	var m = _no_plano_do_sol_2(2, 3)
	_igual(m.sol, 2, "c2 sol 2: chegou ao sol 2")
	_igual(m.fase, "plano", "c2 sol 2: no plano")
	_igual(m.st["E"], 3.0, "c2 sol 2: a bateria ficou em 3 depois do sol 1")
	_igual(m.para_dividir(), 10.0, "c2 sol 2: 10 para dividir")
	_igual(m.previsao().get("sem_reserva", null), false, "c2 sol 2: plano vazio não avisa")
	_planejar(m, 2, 2)
	_igual(m.previsao()["bateria_apos_plano"], 2.0, "c2 sol 2: O2 +2 e 2 tarefas deixam 2 na bateria")
	_igual(m.previsao().get("sem_reserva", null), false, "c2 sol 2: com 2 na bateria, não avisa")
	_verdade(m.alternar_tarefa(Missao.TAREFAS[2]), "c2 sol 2: a 3ª tarefa cabe no plano")
	var p: Dictionary = m.previsao()
	_igual(p["bateria_apos_plano"], 0.0, "c2 sol 2: O2 +2 e 3 tarefas zeram a bateria")
	_igual(p.get("sem_reserva", null), true, "c2 sol 2: com a bateria zerada, avisa")
	# O aviso não muda nenhum número: a previsão do fim do sol é a mesma, e o plano ainda se confirma.
	_igual(p["st"]["E"], 0.0, "c2 sol 2: a previsão da bateria no fim do sol segue 0")
	_igual(p["st"]["O"], 4.0, "c2 sol 2: a previsão do oxigênio segue 4")
	_verdade(p["falhas"].is_empty(), "c2 sol 2: a previsão do sol segue sem falha")
	_verdade(m.plano_cabe(2, 3), "c2 sol 2: o plano sem reserva continua cabendo")
	_verdade(m.confirmar_plano(), "c2 sol 2: o plano sem reserva ainda se confirma")
	# A outra divisão que zera a bateria (O2 +3 e 2 tarefas) avisa igual; O2 +1 e 3 tarefas (sobra 2), não.
	var a = _no_plano_do_sol_2(2, 3)
	_planejar(a, 3, 2)
	_igual(a.previsao()["bateria_apos_plano"], 0.0, "c2 sol 2: O2 +3 e 2 tarefas zeram a bateria")
	_igual(a.previsao().get("sem_reserva", null), true, "c2 sol 2: O2 +3 e 2 tarefas avisam")
	var b = _no_plano_do_sol_2(2, 3)
	_planejar(b, 1, 3)
	_igual(b.previsao()["bateria_apos_plano"], 2.0, "c2 sol 2: O2 +1 e 3 tarefas deixam 2")
	_igual(b.previsao().get("sem_reserva", null), false, "c2 sol 2: O2 +1 e 3 tarefas não avisam")


## O limiar é o aquecimento da noite, não o zero: 0,8 na bateria já é sem reserva.
func _c2_limiar_na_poeira() -> void:
	var m = Missao.new(1, {})
	m.montar_sol(3, _st(3.0, 4.0, 8.0))
	_igual(m.para_dividir(), 2.8, "c2 limiar: 2,8 para dividir no sol de poeira")
	_igual(m.previsao().get("sem_reserva", null), false, "c2 limiar: com 2,8 na bateria, não avisa")
	_planejar(m, 1, 0)
	_igual(m.previsao()["bateria_apos_plano"], 0.8, "c2 limiar: O2 +1 deixa 0,8")
	_verdade(m.previsao()["bateria_apos_plano"] < Modelo.N.AQUEC, "c2 limiar: 0,8 é menos que o aquecimento da noite")
	_igual(m.previsao().get("sem_reserva", null), true, "c2 limiar: abaixo do aquecimento, avisa")


## No último sol não há noite seguinte a aquecer: nunca avisa, nem zerando a bateria.
func _c2_ultimo_sol() -> void:
	var m = Missao.new(1, {})
	m.montar_sol(Modelo.N.SOLS, _st(1.0, 4.0, 6.0))
	_igual(m.fase, "plano", "c2 sol 5: começa no plano")
	_igual(m.para_dividir(), 8.0, "c2 sol 5: 8 para dividir")
	_planejar(m, 1, 3)
	_igual(m.previsao()["bateria_apos_plano"], 0.0, "c2 sol 5: O2 +1 e 3 tarefas zeram a bateria")
	_igual(m.previsao().get("sem_reserva", null), false, "c2 sol 5: no último sol não avisa, mesmo com a bateria zerada")


func _c2_texto() -> void:
	var textos := _ler_textos()
	for lingua in ["en", "pt"]:
		var texto := _texto(textos, "BATERIA_SEM_RESERVA", lingua)
		_verdade(texto != "", "c2 texto: BATERIA_SEM_RESERVA existe e não é vazio (%s)" % lingua)
		_verdade(_palavras(texto) <= MAX_PALAVRAS, "c2 texto: BATERIA_SEM_RESERVA (%s) tem até %d palavras (tem %d)" % [lingua, MAX_PALAVRAS, _palavras(texto)])


## [R] A energia da tarefa não feita volta à bateria: o mesmo plano sem reserva do sol 2, com só 2 das
## 3 tarefas feitas, deixa 2 na bateria depois do sol.
func _c2_tarefa_nao_feita_volta_a_bateria() -> void:
	var m = _no_plano_do_sol_2(2, 3)
	_sol(m, 2, 3, 2, 0.0)
	_igual(m.fase, "fim_do_sol", "c2 [R]: o sol 2 passa")
	_igual(m.ciencia_do_sol(), 2, "c2 [R]: 2 de ciência feitas")
	_igual(m.st_fim.get("E", null), 2.0, "c2 [R]: a reserva da tarefa não feita voltou: bateria 2 depois do sol")
	_noite(m)
	_igual(m.sol, 3, "c2 [R]: chegou ao sol 3")
	_igual(m.st["E"], 2.0, "c2 [R]: o sol 3 começa com 2 na bateria")
	_igual(m.fase, "plano", "c2 [R]: com 2 na bateria, o sol 3 não abre em modo de segurança")


# --- caso 3: o abrigo tardio ---------------------------------------------------

## A missão fixa com o plano equilibrado (O2 +1 e 1 tarefa) nos sóis 1 e 2, e o abrigo `atraso` s depois
## do pico no sol 2. Devolve a missão no fim do turno do sol 2.
func _sol_2_equilibrado(atraso: float):
	var m = _no_plano_do_sol_2(1, 1)
	_igual(m.sol, 2, "c3 %ds: chegou ao sol 2" % atraso)
	_igual(m.st["M"], 11.0, "c3 %ds: margem 11 no começo do sol 2" % atraso)
	_planejar(m, 1, 1)
	m.confirmar_plano()
	_igual(m.t_pico, 25.0, "c3 %ds: o pico da missão fixa cai aos 25 s" % atraso)
	_turno(m, 1, atraso)
	return m


## 13 s de atraso: dose 3 + round(12 * 13 / 35) = 7; a margem fica 4 e cobre os 3 sóis que faltam.
func _c3_abrigo_13_s_passa() -> void:
	var m = _sol_2_equilibrado(13.0)
	_igual(m.t_exposto, 13.0, "c3 13s: 13 s de exposição")
	_igual(m.fase, "fim_do_sol", "c3 13s: o sol 2 passa")
	_igual(m.modos, 0, "c3 13s: nenhum modo de segurança no sol 2")
	_igual(m.st_fim.get("M", null), 4.0, "c3 13s: a margem fica 4")
	var entradas: Array = []
	_seguir_ate_relatorio(m, entradas)
	_igual(m.fase, "relatorio", "c3 13s: a missão chega ao relatório")
	var por_radiacao := 0
	for e in entradas:
		if e[1] == "radiacao":
			por_radiacao += 1
	_igual(por_radiacao, 0, "c3 13s: nenhum modo de segurança por radiação até o relatório")
	_igual(m.modos, 0, "c3 13s: nenhum modo de segurança na missão")


## 14, 17 e 20 s de atraso: a margem que sobra (3, 2 e 1) não cobre os 3 sóis que faltam, e o sol 2
## entra em modo de segurança ao fechar o turno, com a causa do abrigo tardio e o reinício do sol.
func _c3_abrigo_tardio(atraso: float) -> void:
	var r := "c3 %ds" % atraso
	var m = _sol_2_equilibrado(atraso)
	_igual(m.t_exposto, atraso, "%s: %d s de exposição" % [r, atraso])
	_igual(m.sol, 2, "%s: a falha é no próprio sol 2" % r)
	_igual(m.fase, "seguranca", "%s: o sol 2 entra em modo de segurança" % r)
	_verdade(m.t >= m.turno_s - 1e-6, "%s: no fim do turno, não no meio" % r)
	_igual(m.causa, "radiacao", "%s: causa radiação" % r)
	_igual(m.causa_contexto(), "sem_abrigo", "%s: contexto do abrigo tardio" % r)
	_igual(m.caso_real(), "radiacao", "%s: caso real da radiação" % r)
	_igual(m.tem_conserto, true, "%s: o simulador reinicia o sol" % r)
	_igual(m.modos, 1, "%s: conta 1 modo de segurança" % r)
	_igual(m.ciencia_total(), 1, "%s: o sol que falhou não soma ciência (só a do sol 1)" % r)
	# Reinicia o sol 2 e abriga na hora: o sol passa.
	var reiniciou: bool = m.reiniciar_sol()
	_verdade(reiniciou, "%s: reiniciar_sol vale" % r)
	if reiniciou:
		_igual(m.sol, 2, "%s: o reinício volta ao sol 2" % r)
		_igual(m.fase, "plano", "%s: o reinício volta ao plano" % r)
		_igual(m.st["M"], 11.0, "%s: o reinício devolve a margem do começo do sol" % r)
		_sol(m, 1, 1, 1, 0.0)
		_igual(m.t_exposto, 0.0, "%s: no reinício, abrigo na hora" % r)
		_igual(m.fase, "fim_do_sol", "%s: reiniciado com abrigo na hora, o sol 2 passa" % r)
		_igual(m.st_fim.get("M", null), 8.0, "%s: a margem fica 8 depois do sol 2" % r)
	var entradas: Array = []
	_seguir_ate_relatorio(m, entradas)
	_igual(m.fase, "relatorio", "%s: a missão segue até o relatório" % r)
	_igual(entradas.size(), 0, "%s: nenhum modo de segurança nos sóis 3 a 5" % r)
	_igual(m.modos, 1, "%s: a missão fecha com 1 modo de segurança" % r)


## 22 s de atraso já falhava no sol 2 (a margem zera) e continua igual.
func _c3_abrigo_22_s_continua() -> void:
	var m = _sol_2_equilibrado(22.0)
	_igual(m.sol, 2, "c3 22s: a falha é no sol 2")
	_igual(m.fase, "seguranca", "c3 22s: modo de segurança")
	_igual(m.causa, "radiacao", "c3 22s: causa radiação")
	_igual(m.causa_contexto(), "sem_abrigo", "c3 22s: contexto do abrigo tardio")
	_igual(m.tem_conserto, true, "c3 22s: reinicia o sol")
	_igual(m.modos, 1, "c3 22s: conta 1 modo de segurança")


## Abrigo na hora nunca dispara a regra, mesmo que a margem não cubra o resto: com margem 5 no começo do
## sol 2, o plano de emergência salva (fica 2), e 2 não cobre os 3 sóis que faltam. Não é culpa do abrigo.
func _c3_abrigo_na_hora_nao_dispara() -> void:
	var m = Missao.new(1, {})
	m.montar_sol(2, _st(6.0, 4.0, 5.0))
	_verdade(m.eh_sol_solar(), "c3 na hora: o sol 2 é o da tempestade solar")
	_igual(m.fase, "plano", "c3 na hora: o plano de emergência salva, o sol começa no plano")
	_sol(m, 1, 0, 0, 0.0)
	_verdade(m.t_abrigado > 0.0, "c3 na hora: a tripulação abrigou")
	_igual(m.t_exposto, 0.0, "c3 na hora: exposição zero")
	_igual(m.fase, "fim_do_sol", "c3 na hora: o sol passa, sem modo de segurança")
	_igual(m.modos, 0, "c3 na hora: nenhum modo de segurança")
	_igual(m.st_fim.get("M", null), 2.0, "c3 na hora: a margem fica 2 (menos que os 3 sóis que faltam)")


## A conta é a dos sóis que faltam, (SOLS - sol) * DOSE_NORMAL, e não um número fixo: com a tempestade
## solar no sol 4 falta 1 sol. Margem 6: 5 s de atraso dão dose 5 e sobra 1 (não cobre); 2 s dão dose 4
## e sobram 2 (cobre).
func _c3_conta_os_sois_que_faltam() -> void:
	var opcoes := {"sol_solar": 4, "sol_poeira": 2}
	var tarde = Missao.new(1, opcoes)
	tarde.montar_sol(4, _st(8.0, 4.0, 6.0))
	_verdade(tarde.eh_sol_solar(), "c3 sol 4: a tempestade solar foi para o sol 4")
	_igual(tarde.fase, "plano", "c3 sol 4: começa no plano")
	_sol(tarde, 1, 0, 0, 5.0)
	_igual(tarde.t_exposto, 5.0, "c3 sol 4: 5 s de exposição")
	_igual(tarde.sol, 4, "c3 sol 4/5s: a falha é no próprio sol 4")
	_igual(tarde.fase, "seguranca", "c3 sol 4/5s: sobra 1 de margem para 1 sol, modo de segurança")
	_igual(tarde.causa, "radiacao", "c3 sol 4/5s: causa radiação")
	_igual(tarde.causa_contexto(), "sem_abrigo", "c3 sol 4/5s: contexto do abrigo tardio")
	_igual(tarde.tem_conserto, true, "c3 sol 4/5s: reinicia o sol")
	_igual(tarde.modos, 1, "c3 sol 4/5s: conta 1 modo de segurança")
	var cedo = Missao.new(1, opcoes)
	cedo.montar_sol(4, _st(8.0, 4.0, 6.0))
	_sol(cedo, 1, 0, 0, 2.0)
	_igual(cedo.t_exposto, 2.0, "c3 sol 4: 2 s de exposição")
	_igual(cedo.fase, "fim_do_sol", "c3 sol 4/2s: sobram 2 de margem para 1 sol, o sol passa")
	_igual(cedo.modos, 0, "c3 sol 4/2s: nenhum modo de segurança")
	_igual(cedo.st_fim.get("M", null), 2.0, "c3 sol 4/2s: a margem fica 2")


## A regra é do sol da tempestade solar: num sol comum, margem curta para o resto da missão não dispara nada.
func _c3_sol_comum_nao_dispara() -> void:
	var m = Missao.new(1, {})
	m.montar_sol(3, _st(8.0, 4.0, 2.0))
	_verdade(not m.eh_sol_solar(), "c3 sol comum: o sol 3 não é o da tempestade solar")
	_igual(m.fase, "plano", "c3 sol comum: começa no plano")
	_sol(m, 1, 0, 0, -1.0)
	_igual(m.fase, "fim_do_sol", "c3 sol comum: o sol passa")
	_igual(m.modos, 0, "c3 sol comum: nenhum modo de segurança")
	_igual(m.st_fim.get("M", null), 1.0, "c3 sol comum: a margem fica 1")


## A receita "O2 +2 e todas as tarefas que couberem", com a peça levando `peca_s` segundos, o gerador
## consertado primeiro e o abrigo `atraso` s depois do pico (no sol 2, no máximo `k2` tarefas).
func _receita(k2: int, atraso: float, peca_s: float):
	var m = Missao.new(1, {})
	var guarda := 0
	while m.fase != "relatorio" and guarda < 60:
		guarda += 1
		match m.fase:
			"seguranca":
				if m.tem_conserto:
					m.reiniciar_sol()
				else:
					m.seguir_em_seguranca()
			"plano":
				var teto := k2 if m.sol == 2 else 3
				for i in 2:
					m.mudar_q(1)
				for nome in Missao.TAREFAS:
					if m.plano_tarefas.size() < teto:
						m.alternar_tarefa(nome)
				m.confirmar_plano()
				var fila: Array = []
				for nome in m.lista_do_turno():
					if nome == "gerador":
						fila.push_front(nome)
					else:
						fila.append(nome)
				var rodou := 0.0
				var passos := 0
				while m.fase == "turno" and passos < 100000:
					passos += 1
					if m.eh_sol_solar() and not m.abrigado and m.t >= m.t_pico + atraso:
						m.abrigar()
					if m.tarefa_rodando == "" and not m.abrigado:
						for nome in fila:
							if m.tarefas.get(nome, "") == "pendente":
								m.iniciar_tarefa(nome)
								rodou = 0.0
								break
					m.avancar(PASSO)
					if m.fase == "turno" and m.tarefa_rodando != "":
						rodou += PASSO
						if rodou >= peca_s - 1e-6:
							m.concluir_tarefa(m.tarefa_rodando)
			"turno":
				_turno(m, 0, 0.0)
			"fim_do_sol", "noite":
				_noite(m)
	return m


## Calibração: com abrigo na hora (ou com 5 s de atraso, que deixa margem 6) e planos sensatos, a missão
## fixa dá o mesmo de antes: 7 de ciência, nenhum modo de segurança, 3 estrelas.
func _c3_calibracao() -> void:
	var m = _receita(3, 0.0, 10.0)
	_igual(m.fase, "relatorio", "c3 calibração: a receita chega ao relatório")
	_igual(m.ciencia_total(), 7, "c3 calibração: 7 de ciência")
	_igual(m.ciencia_por_sol, [3, 2, 0, 0, 2], "c3 calibração: a ciência de cada sol")
	_igual(m.modos, 0, "c3 calibração: nenhum modo de segurança")
	_igual(m.estrelas(), 3, "c3 calibração: 3 estrelas")
	_igual(m.st["M"], 5.0, "c3 calibração: margem final 5")
	var a = _receita(2, 5.0, 10.0)
	_igual(a.fase, "relatorio", "c3 calibração/5s: chega ao relatório")
	_igual(a.ciencia_total(), 7, "c3 calibração/5s: 7 de ciência")
	_igual(a.modos, 0, "c3 calibração/5s: 5 s de atraso não disparam a regra (margem 6 depois do sol 2)")
	_igual(a.estrelas(), 3, "c3 calibração/5s: 3 estrelas")
	_igual(a.st["M"], 3.0, "c3 calibração/5s: margem final 3")
