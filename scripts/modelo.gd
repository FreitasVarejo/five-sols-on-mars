extends RefCounted
## Modelo do jogo como lógica pura: sem nó, sem cena, sem UI.
##
## É o simSol de calibracao/sim.js (mesma conta, mesmos números) mais as regras de tarefa
## que a spec ganhou em 14/11 e o sim não tem (a energia da ciência só é gasta quando a tarefa
## roda; gerador quebrado produz zero). A UI chama estas funções e guarda o estado.
##
## O estado é um Dictionary, sempre neste formato:
##   {"E": float (bateria), "O": float (oxigênio), "M": float (margem de radiação),
##    "P": float (fator do painel, 1 = limpo), "gerador_quebrado": bool}
## Nenhuma função muda o `st` que recebe: devolve um estado novo.
##
## `st` é sempre o estado no começo do sol, ANTES do aquecimento da noite. `poeira` diz se o sol
## está dentro da tempestade de poeira; `solar`, se é o sol da tempestade solar.
##
## O jogo P0 não tem tempestade de poeira nem acúmulo de poeira (são P1), mas o modelo já leva
## `poeira` e `P` para o P1 só ligar.
##
## Não há assert nas entradas: plano_cabe() diz se o plano cabe, e a UI só confirma plano que cabe.
## Um plano que não cabe dá bateria negativa, e o estado de falha sai como a conta deu
## (O pode sair negativo). O piso em 0 é só de seguir_em_seguranca().

## Números do jogo, todos [P] da calibração (calibracao/sim.js, SIM_PADRAO), num lugar só.
const N := {
	"SOLAR": 8.0,           # energia que o painel limpo rende por sol
	"GEN_CUSTO": 2.0,       # energia por 1 de O2 no gerador
	"CREW_O2": 2.0,         # O2 que a tripulação respira por sol
	"CIENCIA_CUSTO": 2.0,   # energia de cada tarefa de ciência
	"VAGAS_TURNO": 3,       # tarefas de ciência que cabem num turno
	"E0": 6.0,              # bateria no começo da missão
	"O0": 4.0,              # oxigênio no começo da missão
	"M0": 12.0,             # margem de radiação no começo da missão
	"DOSE_NORMAL": 2.0,     # dose de um sol comum
	"DOSE_TEMPESTADE": 6.0, # dose do sol da tempestade solar, sem abrigo
	"FATOR_ABRIGO": 1.0 / 3.0, # parte da dose da tempestade que nem o abrigo tira
	"AQUEC": 1.0,           # aquecimento da noite, sai antes do plano
	"TETO": 12.0,           # teto da bateria
	"TANQUE_O2": 12.0,      # máximo do tanque de O2
	"FATOR_POEIRA": 0.1,    # fração do painel que rende na tempestade de poeira
	"PISO_P": 0.3,          # o painel nunca rende menos que isso
	# No sim é 0.05. No P0 fica desligado; o P1 liga junto com "limpar o painel", que devolve P.
	"ACUMULO": 0.0,         # quanto P cai por sol
	"SOLS": 5,              # sóis da missão
	# Máximo teórico de ciência: simTeorico do sim.js (coluna "tudo em ciência", sem poeira e
	# sem tempestade solar) com ACUMULO 0. Se os números acima mudarem, recalcule rodando o sim.
	"TEORICO": 14,
	"ESTRELAS_PCT": 0.7,    # fração do TEORICO que a ciência precisa atingir para 3 estrelas
}

const EPS := 1e-9


## Arredonda em 6 casas, como o simRnd do sim.
static func _rnd(x: float) -> float:
	return round(x * 1e6) / 1e6


static func estado_inicial() -> Dictionary:
	return {
		"E": minf(N.TETO, N.E0),
		"O": N.O0,
		"M": N.M0,
		"P": 1.0,
		"gerador_quebrado": false,
	}


## Conta da manhã sem arredondar (é a que o fechar_sol usa, como o sim).
static func _manha_bruta(st: Dictionary, poeira: bool) -> Dictionary:
	var renda: float = N.SOLAR * st["P"] * (N.FATOR_POEIRA if poeira else 1.0)
	var bruto: float = st["E"] + renda
	return {
		"renda": renda,
		"falta_aquecimento": bruto < N.AQUEC - EPS,
		"para_dividir": maxf(0.0, bruto - N.AQUEC),
	}


## O aquecimento da noite sai antes do plano. Devolve a renda do painel, se falta energia
## para o aquecimento e quanto sobra para dividir no plano.
static func manha(st: Dictionary, poeira: bool) -> Dictionary:
	var m := _manha_bruta(st, poeira)
	return {
		"renda": _rnd(m["renda"]),
		"falta_aquecimento": m["falta_aquecimento"],
		"para_dividir": _rnd(m["para_dividir"]),
	}


## Dose do sol. Sol comum: DOSE_NORMAL. Sol da tempestade solar: a parte que nem o abrigo tira
## mais o resto, na proporção do tempo exposto depois do pico, arredondado para inteiro.
## f_exposto 0 = abrigou na hora; 1 = não abrigou.
static func dose(solar: bool, f_exposto: float) -> float:
	if not solar:
		return N.DOSE_NORMAL
	var fixa: float = N.DOSE_TEMPESTADE * N.FATOR_ABRIGO
	var resto: float = N.DOSE_TEMPESTADE - fixa
	return _rnd(fixa + round(resto * clampf(f_exposto, 0.0, 1.0)))


## Um sol inteiro a partir de `st` (antes do aquecimento).
## q = unidades de O2 pedidas no plano; n_ciencia = tarefas de ciência escolhidas no plano;
## n_feitas = quantas rodaram no turno (<= n_ciencia).
static func fechar_sol(st: Dictionary, poeira: bool, q: int, n_ciencia: int, n_feitas: int,
		dose_do_sol: float, consertou_gerador: bool) -> Dictionary:
	var falhas: Array = []

	# 1. Manhã. Sem energia para o aquecimento o sol falha, e a conta segue com 0 para dividir.
	var m := _manha_bruta(st, poeira)
	var para_dividir: float = m["para_dividir"]
	if m["falta_aquecimento"]:
		falhas.append("energia")

	# 2. A sobra do plano vai sozinha para a bateria.
	var sobra: float = para_dividir - q * N.GEN_CUSTO - n_ciencia * N.CIENCIA_CUSTO

	# 3. [R] O plano só reserva a energia da ciência; a tarefa a gasta quando roda.
	# A reserva de cada tarefa não feita volta à bateria.
	var devolvida: float = (n_ciencia - n_feitas) * N.CIENCIA_CUSTO

	# 4. Gerador. Quebrado e não consertado: não roda, produz 0.
	var o2_produzido := q
	var gerador_quebrado: bool = st["gerador_quebrado"]
	if gerador_quebrado and not consertou_gerador:
		# [P] inferência: confirmar com o dono. Por analogia com a ciência não feita e com
		# "a consequência vem pela própria barra", a energia que o plano deu ao gerador
		# parado também volta à bateria.
		o2_produzido = 0
		devolvida += q * N.GEN_CUSTO
	else:
		gerador_quebrado = false

	# 5. Bateria nova, cortada no teto.
	var bateria: float = sobra + devolvida
	var perdida_no_teto: float = maxf(0.0, bateria - N.TETO)
	var E: float = minf(N.TETO, bateria)

	# 6. Oxigênio: o que passa do estoque vai para o tanque, até o máximo dele.
	var O: float = st["O"]
	var liquido: float = O + o2_produzido - N.CREW_O2
	if liquido > O + EPS:
		O = minf(liquido, maxf(N.TANQUE_O2, O))
	else:
		O = liquido
	if O < -EPS:
		falhas.append("oxigenio")

	# 7. Margem de radiação.
	var M: float = st["M"] - dose_do_sol
	if M <= EPS:
		falhas.append("radiacao")

	# 8. Painel.
	var P: float = maxf(N.PISO_P, st["P"] - N.ACUMULO)

	return {
		"st": {
			"E": _rnd(E),
			"O": _rnd(O),
			"M": _rnd(M),
			"P": _rnd(P),
			"gerador_quebrado": gerador_quebrado,
		},
		"falhas": falhas,
		"ciencia": n_feitas,
		"o2_produzido": o2_produzido,
		"devolvida": _rnd(devolvida),
		"perdida_no_teto": _rnd(perdida_no_teto),
		"renda": _rnd(m["renda"]),
		"para_dividir": _rnd(para_dividir),
	}


## O plano de emergência da spec: tudo ao gerador, zero ciência, abrigo o tempo todo no sol da
## tempestade solar e conserto de tudo que estiver quebrado. Mesmo formato do fechar_sol, mais "q".
static func emergencia(st: Dictionary, poeira: bool, solar: bool) -> Dictionary:
	var m := _manha_bruta(st, poeira)
	var q := int(floor(m["para_dividir"] / N.GEN_CUSTO + EPS))
	var r := fechar_sol(st, poeira, q, 0, 0, dose(solar, 0.0), true)
	r["q"] = q
	return r


## Algum plano salva o sol? É o que decide entre "o simulador reinicia o sol" e
## "seguir em modo de segurança".
static func algum_plano_salva(st: Dictionary, poeira: bool, solar: bool) -> bool:
	return emergencia(st, poeira, solar)["falhas"].is_empty()


## Estado depois de "seguir em modo de segurança": o do plano de emergência, com O e M em piso 0.
static func seguir_em_seguranca(st: Dictionary, poeira: bool, solar: bool) -> Dictionary:
	var novo: Dictionary = emergencia(st, poeira, solar)["st"]
	novo["O"] = maxf(0.0, novo["O"])
	novo["M"] = maxf(0.0, novo["M"])
	return novo


## O que o plano mostra antes de confirmar, supondo toda tarefa feita e sol sem tempestade.
## "bateria_apos_plano" e "perdida_no_teto" são do momento da confirmação (a sobra do plano,
## antes de qualquer devolução); o resto é o do fim do sol. Com gerador quebrado, mostra 0 de O2.
static func previsao(st: Dictionary, poeira: bool, q: int, n_ciencia: int) -> Dictionary:
	var r := fechar_sol(st, poeira, q, n_ciencia, n_ciencia, N.DOSE_NORMAL, false)
	var sobra: float = r["para_dividir"] - q * N.GEN_CUSTO - n_ciencia * N.CIENCIA_CUSTO
	r["bateria_apos_plano"] = _rnd(minf(N.TETO, sobra))
	r["perdida_no_teto"] = _rnd(maxf(0.0, sobra - N.TETO))
	return r


## O plano cabe na energia que há para dividir e nas vagas do turno?
static func plano_cabe(st: Dictionary, poeira: bool, q: int, n_ciencia: int) -> bool:
	if q < 0 or n_ciencia < 0 or n_ciencia > N.VAGAS_TURNO:
		return false
	var m := _manha_bruta(st, poeira)
	return q * N.GEN_CUSTO + n_ciencia * N.CIENCIA_CUSTO <= m["para_dividir"] + EPS


## Estrelas do relatório (regra de partida da calibração, [P]).
static func estrelas(modos: int, ciencia: int) -> int:
	if modos == 0 and ciencia >= N.ESTRELAS_PCT * N.TEORICO - EPS:
		return 3
	if modos <= 2:
		return 2
	return 1
