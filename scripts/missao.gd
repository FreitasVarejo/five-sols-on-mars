extends RefCounted
## Máquina da missão em lógica pura: sem nó, sem cena, sem UI.
##
## Dona do estado do jogo: o sol, a fase, o estado do modelo, o plano em edição, o relógio do
## turno, o abrigo, a exposição, as tarefas (de ciência e de manutenção), os eventos sorteados da
## missão (tempestade solar, tempestade de poeira, quebra do gerador), os modos de segurança e o
## registro de cada sol (que alimenta o diário e o relatório). Toda conta de recurso vem de
## modelo.gd; aqui só mora a ordem das coisas e as regras do turno.
##
## Fases: "plano" -> "turno" -> "fim_do_sol" -> "noite" -> "plano" do sol seguinte; depois do sol 5,
## "relatorio". Falha leva a "seguranca" (ver _entrar_seguranca).
##
## A UI chama as ações (mudar_q, alternar_tarefa, confirmar_plano, iniciar_tarefa, abrigar,
## encerrar_sol, enviar_a_terra, reiniciar_sol, seguir_em_seguranca, jogar_de_novo) e avancar(delta),
## e lê o estado.
## `versao` sobe a cada mudança, para a UI redesenhar só quando precisa.
##
## O sorteio vem de um gerador próprio: a semente pode ser injetada (testes e ?semente= na URL).

const Modelo := preload("res://scripts/modelo.gd")

# Números do turno, todos [P], num lugar só.
const TURNO_S := 60.0       # duração do turno; 1 s = 1 min
const TAREFA_S := 10.0      # duração de cada tarefa de ciência (placeholder do minigame)
const PICO_MIN := 0.15      # o pico da tempestade solar é sorteado entre estas frações do turno
const PICO_MAX := 0.70      # nunca depois de 70%: não coincide com o fim do turno
const RAMPA_S := 3.0        # o medidor sobe de baixo até "abrigo" nos segundos antes do pico
const NOITE_S := 1.2        # a noite, entre o envio à Terra e o plano seguinte
const SOLS_SOLAR := [2, 3, 4]  # sóis em que a tempestade solar pode cair (um por missão); a URL aceita estes
const ATRASO_MIN := 3       # o "há N min" do card da Terra: no freeplay, sorteado por missão entre estes
const ATRASO_MAX := 22
const SOL_AVISO := 1        # sol do primeiro aviso da tempestade solar (o plano do sol 1)
const SOLS_EVENTO := [2, 3, 4, 5]  # sóis em que podem começar a tempestade de poeira e a quebra do gerador
const DURACAO_POEIRA := 2   # sóis da tempestade de poeira (encurtada: a de início no sol 5 fica só nele)
# A missão fixa (a primeira): a mesma para o jurado, o vídeo e a calibração (spec, "Missão e sol").
const FIXA_SOL_SOLAR := 2
const FIXA_SOL_POEIRA := 3     # a poeira cobre os sóis 3 e 4 (DURACAO_POEIRA)
const FIXA_SOL_QUEBRA := 5
const FIXA_ATRASO_MIN := 12    # o "há N min" do card da Terra na missão fixa
const FIXA_PICO_S := 25.0      # pico da tempestade solar, em segundos de um turno de TURNO_S
# O freeplay versão zero: as seis agendas de 5 sóis com um evento por sol, [solar, poeira (início), quebra].
const AGENDAS_LIVRES := [
	[3, 4, 2],  # quebra 2, solar 3, poeira 4 e 5
	[3, 5, 2],  # quebra 2, solar 3, poeira 5
	[3, 5, 4],  # solar 3, quebra 4, poeira 5
	[4, 2, 5],  # poeira 2 e 3, solar 4, quebra 5
	[4, 5, 2],  # quebra 2, solar 4, poeira 5
	[4, 5, 3],  # quebra 3, solar 4, poeira 5
]
const ACELERAR := 8.0       # "Encerrar o sol": o relógio do turno corre tantas vezes mais rápido

# Medidor de radiação (0..1) e seus dois limiares.
const LIMIAR_ATENCAO := 0.4
const LIMIAR_ABRIGO := 0.7
const MEDIDOR_BAIXO := 0.15
const MEDIDOR_ALTO := 0.9

const TAREFAS := ["chemcam", "amostra", "planta"]  # as de ciência, escolhidas no plano
const MANUTENCAO := ["gerador"]  # as que a base pede; não contam como ciência
const EPS := 1e-9

var rng := RandomNumberGenerator.new()
var turno_s := TURNO_S
var tarefa_s := TAREFA_S
var forcar_sol_solar := 0   # 2, 3 ou 4 força o sol da tempestade; 0 deixa a agenda
var forcar_sol_poeira := 0  # 2 a 5 força o sol de início da poeira; 0 deixa a agenda
var forcar_sol_quebra := 0  # 2 a 5 (e diferente de sol_solar) força o sol da quebra; 0 deixa a agenda
var livre := false          # esta missão é o freeplay (eventos e pico sorteados); false = a missão fixa
var freeplay_aberto := false  # o "Jogar de novo" abre o freeplay (a missão fixa já chegou ao relatório)
var fixa_concluida := false   # a missão fixa chegou ao relatório nesta sessão (a main grava no navegador)

var sol_solar := 3
var sol_poeira := 2         # sol em que a tempestade de poeira começa (dura DURACAO_POEIRA)
var sol_quebra := 5         # sol em que o gerador quebra (uma vez por missão, nunca no sol_solar)
var atraso_min := 3
var sol := 1
var fase := "plano"
var versao := 0

var st := {}         # estado no começo do sol, antes do aquecimento (formato do Modelo)
var st_inicio := {}  # instantâneo do começo do sol, para reiniciar
var st_fim := {}     # estado depois do sol (valendo em "fim_do_sol")

# Plano em edição (e, no turno, o plano confirmado).
var plano_q := 0
var plano_tarefas: Array = []

# Turno.
var t := 0.0
var t_pico := -1.0         # < 0: sem pico neste turno
var abrigado := false
var t_exposto := 0.0       # tempo fora do abrigo depois do pico
var t_abrigado := 0.0      # tempo abrigado no turno
var tarefas := {}          # nome -> "pendente" | "rodando" | "feita" (ciência escolhida e manutenção)
var acelerado := false     # "Encerrar o sol": o relógio corre ACELERAR vezes até o pôr do Sol
var tarefa_rodando := ""
var tarefa_t := 0.0

# Segurança.
var causa := ""            # "energia" | "oxigenio" | "radiacao"
var causas: Array = []
var causa_sem_abrigo := false
var tem_conserto := false
var barras_falha := {}     # E, O, M no momento da falha (nunca abaixo de 0), para a tela do modo de segurança

var t_noite := 0.0

# Missão.
var modos := 0
var ciencia_por_sol: Array = []
var registros: Array = []


## `opcoes`: turno_s, tarefa_s, sol_solar (2, 3 ou 4, força o sol da tempestade), sol_poeira (2 a 5) e
## sol_quebra (2 a 5, diferente de sol_solar); valor inválido ou ausente = a agenda da missão (a fixa,
## ou uma das sorteadas no freeplay). `freeplay_aberto`: o "Jogar de novo" abre o freeplay. `livre`:
## já começa em freeplay (testes). A semente só serve ao sorteio do freeplay.
func _init(semente: int = -1, opcoes: Dictionary = {}) -> void:
	if semente >= 0:
		rng.seed = semente
	else:
		rng.randomize()
	turno_s = float(opcoes.get("turno_s", TURNO_S))
	tarefa_s = float(opcoes.get("tarefa_s", TAREFA_S))
	forcar_sol_solar = int(opcoes.get("sol_solar", 0))
	forcar_sol_poeira = int(opcoes.get("sol_poeira", 0))
	forcar_sol_quebra = int(opcoes.get("sol_quebra", 0))
	freeplay_aberto = bool(opcoes.get("freeplay_aberto", false))
	livre = bool(opcoes.get("livre", false))
	nova_missao()


## Começa uma missão nova. A fixa tem a agenda da spec e não sorteia nada; o freeplay sorteia uma das
## AGENDAS_LIVRES e o atraso do card da Terra (o pico se sorteia no turno). As opções da URL valem por
## cima da agenda. Os eventos são da missão: o reinício de um sol não sorteia de novo.
func nova_missao() -> void:
	var agenda := [FIXA_SOL_SOLAR, FIXA_SOL_POEIRA, FIXA_SOL_QUEBRA]
	atraso_min = FIXA_ATRASO_MIN
	if livre:
		agenda = AGENDAS_LIVRES[rng.randi_range(0, AGENDAS_LIVRES.size() - 1)]
		atraso_min = rng.randi_range(ATRASO_MIN, ATRASO_MAX)
	sol_solar = forcar_sol_solar if forcar_sol_solar in SOLS_SOLAR else agenda[0]
	sol_poeira = forcar_sol_poeira if forcar_sol_poeira in SOLS_EVENTO else agenda[1]
	# A quebra nunca cai no sol da tempestade solar, nem quando a URL força esse sol.
	sol_quebra = forcar_sol_quebra if (forcar_sol_quebra in SOLS_EVENTO and forcar_sol_quebra != sol_solar) else agenda[2]
	fixa_concluida = false
	modos = 0
	ciencia_por_sol = []
	registros = []
	sol = 1
	st = Modelo.estado_inicial()
	_comecar_sol()


## Para testes: põe a missão num sol e num estado montados à mão, e começa o plano dali.
func montar_sol(sol_n: int, estado: Dictionary) -> void:
	sol = sol_n
	st = estado.duplicate()
	_comecar_sol()


# --- consultas ---------------------------------------------------------------

func eh_sol_solar() -> bool:
	return sol == sol_solar


## O sol está dentro da tempestade de poeira (só efeito na energia: o painel rende FATOR_POEIRA)?
func eh_poeira() -> bool:
	return sol >= sol_poeira and sol < sol_poeira + DURACAO_POEIRA


## Aviso da tempestade solar nos planos do sol 1 (SOL_AVISO) até o sol da tempestade, inclusive.
func aviso_ativo() -> bool:
	return sol >= SOL_AVISO and sol <= sol_solar


func para_dividir() -> float:
	return Modelo.manha(st, eh_poeira())["para_dividir"]


func previsao() -> Dictionary:
	return Modelo.previsao(st, eh_poeira(), plano_q, plano_tarefas.size())


func plano_cabe(q: int, n: int) -> bool:
	return Modelo.plano_cabe(st, eh_poeira(), q, n)


func relogio() -> float:
	return clampf(t / turno_s, 0.0, 1.0)


## Fração do turno exposta à tempestade depois do pico, fora do abrigo.
func f_exposto() -> float:
	if t_pico < 0.0:
		return 0.0
	return clampf(t_exposto / (turno_s - t_pico), 0.0, 1.0)


## Quanto a margem cai ao vivo: a parte da dose acima do mínimo, em unidades inteiras.
func queda_ao_vivo() -> int:
	var fixa: float = Modelo.N.DOSE_TEMPESTADE * Modelo.N.FATOR_ABRIGO
	var resto: float = Modelo.N.DOSE_TEMPESTADE - fixa
	return roundi(resto * f_exposto())


## Margem mostrada. No turno cai ao vivo; fora dele é a do estado.
func margem_ao_vivo() -> float:
	if fase == "turno":
		return st["M"] - queda_ao_vivo()
	return st["M"]


func medidor() -> float:
	if fase != "turno" or not eh_sol_solar() or t_pico < 0.0:
		return MEDIDOR_BAIXO
	if t >= t_pico:
		return MEDIDOR_ALTO
	var f := clampf((t - (t_pico - RAMPA_S)) / RAMPA_S, 0.0, 1.0)
	return lerpf(MEDIDOR_BAIXO, LIMIAR_ABRIGO, f)


## A tempestade está em curso (do pico em diante)?
func tempestade_em_curso() -> bool:
	return fase == "turno" and t_pico >= 0.0 and t >= t_pico


## As três barras como a tela as mostra na fase `f`: no plano, o estado do começo do sol; no turno, a
## bateria depois do plano, o O2 de agora e a margem ao vivo; no fim do sol, o estado depois dele;
## no modo de segurança, as barras da falha.
func barras_na_fase(f: String) -> Dictionary:
	match f:
		"turno":
			var bateria: float = Modelo.previsao(st, eh_poeira(), plano_q, plano_tarefas.size())["bateria_apos_plano"]
			return {"E": bateria, "O": st["O"], "M": margem_ao_vivo()}
		"fim_do_sol":
			if not st_fim.is_empty():
				return _barras(st_fim)
		"seguranca":
			if not barras_falha.is_empty():
				return barras_falha.duplicate()
	return _barras(st)


## Ciência da missão até agora (inclui as tarefas já feitas no turno em curso).
func ciencia_ate_agora() -> int:
	return ciencia_total() + (ciencia_do_sol() if fase == "turno" else 0)


## Ciência feita no sol: só as tarefas de ciência. A manutenção não conta.
func ciencia_do_sol() -> int:
	var n := 0
	for nome in tarefas:
		if nome in TAREFAS and tarefas[nome] == "feita":
			n += 1
	return n


## A lista do turno na ordem em que a tela a mostra: a ciência escolhida e, depois, a manutenção que a
## base pede (o gerador, enquanto o sol começou com ele quebrado).
func lista_do_turno() -> Array:
	var lista: Array = plano_tarefas.duplicate()
	for nome in MANUTENCAO:
		if _manutencao_pedida(nome):
			lista.append(nome)
	return lista


## A base pede esta manutenção neste sol? (A próxima parte acrescenta o painel sujo.)
func _manutencao_pedida(nome: String) -> bool:
	match nome:
		"gerador":
			return st_inicio.get("gerador_quebrado", false)
	return false


## O gerador está quebrado e ainda não foi consertado neste turno?
func gerador_quebrado_agora() -> bool:
	return fase == "turno" and st_inicio.get("gerador_quebrado", false) and tarefas.get("gerador", "") != "feita"


## A lista acabou: abrigado (a tripulação não faz mais nada), ou toda tarefa da lista (ciência e
## manutenção) feita. Lista vazia conta como acabada.
func lista_acabou() -> bool:
	if abrigado:
		return true
	for nome in tarefas:
		if tarefas[nome] != "feita":
			return false
	return true


## O medidor está em "atenção" ou acima.
func em_atencao() -> bool:
	return medidor() >= LIMIAR_ATENCAO - EPS


## "Encerrar o sol" valeria agora? Só no turno e só uma vez, com a lista acabada, e recusa enquanto
## o medidor pede atenção e a tripulação está fora do abrigo (aí a criança decide: abrigar).
func pode_encerrar_sol() -> bool:
	if fase != "turno" or acelerado or not lista_acabou():
		return false
	return abrigado or not em_atencao()


## Instante do turno em que o medidor chega a "atenção", pela rampa antes do pico. -1 sem pico.
func t_atencao() -> float:
	if not eh_sol_solar() or t_pico < 0.0:
		return -1.0
	var f := (LIMIAR_ATENCAO - MEDIDOR_BAIXO) / (LIMIAR_ABRIGO - MEDIDOR_BAIXO)
	return t_pico - RAMPA_S + RAMPA_S * f


func ciencia_total() -> int:
	var n := 0
	for c in ciencia_por_sol:
		n += int(c)
	return n


func progresso_tarefa(nome: String) -> float:
	match tarefas.get(nome, ""):
		"feita":
			return 1.0
		"rodando":
			return clampf(tarefa_t / tarefa_s, 0.0, 1.0)
	return 0.0


func estrelas() -> int:
	return Modelo.estrelas(modos, ciencia_total())


## A causa pelo contexto do sol que falhou, além da barra que zerou (spec, "Falha e relatório"):
## "sem_abrigo" (a radiação veio do abrigo tardio), "gerador" (oxigênio com o gerador quebrado no começo
## do sol e sem conserto, quando consertar salvava: falha no turno, com `tem_conserto`) ou "poeira"
## (oxigênio ou energia num sol de poeira). "" quando não há contexto. Na tela antecipada (nenhum plano
## salva, nem com o conserto), "aperte Consertar" não vale, e o gerador não entra.
func causa_contexto() -> String:
	if causa_sem_abrigo:
		return "sem_abrigo"
	if causa == "oxigenio" and tem_conserto and st_inicio.get("gerador_quebrado", false) and tarefas.get("gerador", "") != "feita":
		return "gerador"
	if eh_poeira() and (causa == "oxigenio" or causa == "energia"):
		return "poeira"
	return ""


## A chave (minúscula) do caso real da tela do modo de segurança: acompanha o contexto (poeira: o da
## energia; gerador: o do oxigênio; sem abrigo: o da radiação); sem contexto, o da barra que zerou.
func caso_real() -> String:
	match causa_contexto():
		"poeira":
			return "energia"
		"gerador":
			return "oxigenio"
		"sem_abrigo":
			return "radiacao"
	return causa


# --- plano -------------------------------------------------------------------

## Muda o O2 do plano em `delta`. Só vale se o plano novo cabe.
func mudar_q(delta: int) -> bool:
	if fase != "plano":
		return false
	var novo := plano_q + delta
	if not Modelo.plano_cabe(st, eh_poeira(), novo, plano_tarefas.size()):
		return false
	plano_q = novo
	versao += 1
	return true


## Liga ou desliga uma tarefa de ciência. Só vale se o plano novo cabe.
func alternar_tarefa(nome: String) -> bool:
	if fase != "plano" or not (nome in TAREFAS):
		return false
	var novas: Array = []
	for n in TAREFAS:
		if (n in plano_tarefas) != (n == nome):
			novas.append(n)
	if not Modelo.plano_cabe(st, eh_poeira(), plano_q, novas.size()):
		return false
	plano_tarefas = novas
	versao += 1
	return true


## "Confirmar plano" é sempre permitido, mesmo que a previsão mostre falha.
## Começa o turno e o relógio.
func confirmar_plano() -> bool:
	if fase != "plano":
		return false
	fase = "turno"
	t = 0.0
	abrigado = false
	t_exposto = 0.0
	t_abrigado = 0.0
	tarefa_rodando = ""
	tarefa_t = 0.0
	acelerado = false
	tarefas = {}
	for nome in plano_tarefas:
		tarefas[nome] = "pendente"
	# A manutenção que a base pede entra na lista (o gerador, enquanto estiver quebrado).
	for nome in MANUTENCAO:
		if _manutencao_pedida(nome):
			tarefas[nome] = "pendente"
	# Missão fixa: o pico cai sempre no mesmo instante (FIXA_PICO_S de TURNO_S, na mesma fração se o
	# turno muda). Freeplay: sorteado de novo a cada turno (inclusive quando o sol reinicia).
	t_pico = -1.0
	if eh_sol_solar():
		if livre:
			t_pico = rng.randf_range(PICO_MIN, PICO_MAX) * turno_s
		else:
			t_pico = turno_s * FIXA_PICO_S / TURNO_S
	versao += 1
	return true


# --- turno -------------------------------------------------------------------

## Inicia uma tarefa da lista (ciência escolhida ou manutenção): pendente, sem outra rodando e fora
## do abrigo.
func iniciar_tarefa(nome: String) -> bool:
	if fase != "turno" or abrigado or tarefa_rodando != "":
		return false
	if tarefas.get(nome, "") != "pendente":
		return false
	tarefas[nome] = "rodando"
	tarefa_rodando = nome
	tarefa_t = 0.0
	versao += 1
	return true


## O abrigo é de mão única: vale só no turno e só uma vez, em qualquer sol. Depois dele a tripulação
## não faz mais tarefa nenhuma (nem ciência, nem manutenção) e não sai do abrigo. A ciência já feita
## conta; a tarefa que rodava volta a pendente, perde o andamento e não conta. É assim que o abrigo
## custa tempo, não energia.
func abrigar() -> bool:
	if fase != "turno" or abrigado:
		return false
	abrigado = true
	if tarefa_rodando != "":
		tarefas[tarefa_rodando] = "pendente"
		tarefa_rodando = ""
		tarefa_t = 0.0
	versao += 1
	return true


## "Encerrar o sol": o relógio do turno corre ACELERAR vezes até o pôr do Sol. A exposição e a dose
## seguem contando em tempo de jogo (o relógio do turno), não em tempo real. No sol da tempestade, o
## relógio acelerado para quando o medidor chega a "atenção" (ver _avancar_turno), e a criança decide.
func encerrar_sol() -> bool:
	if not pode_encerrar_sol():
		return false
	acelerado = true
	versao += 1
	return true


## Avança o relógio do jogo `delta` segundos (só mexe no turno e na noite).
func avancar(delta: float) -> void:
	match fase:
		"turno":
			_avancar_turno(delta * (ACELERAR if acelerado else 1.0))
		"noite":
			t_noite += delta
			if t_noite >= NOITE_S - EPS:
				_terminar_noite()


func _avancar_turno(delta: float) -> void:
	var dt := minf(maxf(delta, 0.0), turno_s - t)
	var t1 := t + dt
	# Acelerado fora do abrigo no sol da tempestade: nunca passa de "atenção" (o pico segue surpresa).
	if acelerado and not abrigado and t_atencao() >= 0.0 and t1 >= t_atencao() - EPS:
		t1 = maxf(t, minf(t1, t_atencao()))
		dt = t1 - t
		acelerado = false
		versao += 1
	if dt > 0.0:
		if eh_sol_solar() and t_pico >= 0.0 and not abrigado:
			t_exposto += maxf(0.0, t1 - maxf(t, t_pico))
		if abrigado:
			t_abrigado += dt
		elif tarefa_rodando != "":
			tarefa_t += dt
			if tarefa_t >= tarefa_s - EPS:
				tarefas[tarefa_rodando] = "feita"
				tarefa_rodando = ""
				tarefa_t = 0.0
		t = t1
		versao += 1
	# A margem ao vivo chegou a zero por causa da exposição: o modo de segurança entra ali.
	if queda_ao_vivo() > 0 and margem_ao_vivo() <= 0.0:
		_entrar_seguranca(["radiacao"], {"E": st_inicio["E"], "O": st_inicio["O"], "M": 0.0})
		return
	if t >= turno_s - EPS:
		_fechar_turno()


func _fechar_turno() -> void:
	var solar := eh_sol_solar()
	var f := f_exposto()
	var dose: float = Modelo.dose(solar, f)
	var feitas: Array = []
	var nao_feitas: Array = []
	for nome in plano_tarefas:
		if tarefas.get(nome, "") == "feita":
			feitas.append(nome)
		else:
			nao_feitas.append(nome)
	var quebrado: bool = st_inicio["gerador_quebrado"]
	var consertou: bool = tarefas.get("gerador", "") == "feita"
	var r := Modelo.fechar_sol(st_inicio, eh_poeira(), plano_q, plano_tarefas.size(), feitas.size(), dose, consertou)
	acelerado = false
	if not r["falhas"].is_empty():
		_entrar_seguranca(r["falhas"], r["st"])
		return
	st_fim = r["st"]
	ciencia_por_sol.append(feitas.size())
	registros.append({
		"sol": sol, "tempestade": solar, "poeira": eh_poeira(), "aviso": aviso_ativo(), "atraso_min": atraso_min,
		"gerador_quebrado": quebrado, "consertou": consertou,
		"antes": _barras(st_inicio), "depois": _barras(st_fim),
		"q": plano_q, "escolhidas": plano_tarefas.duplicate(), "feitas": feitas, "nao_feitas": nao_feitas,
		"ciencia": feitas.size(), "devolvida": r["devolvida"], "perdida_no_teto": r["perdida_no_teto"],
		"o2_produzido": r["o2_produzido"], "dose": dose, "f_exposto": f, "abrigou": t_abrigado > 0.0,
		"seguranca": false, "causa": "", "causa_contexto": "",
	})
	fase = "fim_do_sol"
	versao += 1


# --- segurança ---------------------------------------------------------------

## Cada entrada soma 1 em `modos`. Se algum plano salva o sol (inclui consertar o que está
## quebrado), a saída é reiniciar o sol; senão, seguir em modo de segurança.
func _entrar_seguranca(lista: Array, barras: Dictionary) -> void:
	modos += 1
	barras_falha = {"E": maxf(0.0, barras["E"]), "O": maxf(0.0, barras["O"]), "M": maxf(0.0, barras["M"])}
	causas = lista.duplicate()
	causa = String(lista[0])
	causa_sem_abrigo = causa == "radiacao" and eh_sol_solar() and t_exposto > 0.0
	tem_conserto = Modelo.algum_plano_salva(st_inicio, eh_poeira(), eh_sol_solar())
	fase = "seguranca"
	abrigado = false
	acelerado = false
	tarefa_rodando = ""
	versao += 1


## Volta ao começo do plano do mesmo sol, com o instantâneo. Só se algum plano salva.
func reiniciar_sol() -> bool:
	if fase != "seguranca" or not tem_conserto:
		return false
	st = st_inicio.duplicate()
	_comecar_sol()
	return true


## A base sobrevive com o mínimo: o sol passa sem ciência e conta como modo de segurança.
## Só se nenhum plano salva.
func seguir_em_seguranca() -> bool:
	if fase != "seguranca" or tem_conserto:
		return false
	st_fim = Modelo.seguir_em_seguranca(st_inicio, eh_poeira(), eh_sol_solar())
	ciencia_por_sol.append(0)
	registros.append({
		"sol": sol, "tempestade": eh_sol_solar(), "poeira": eh_poeira(), "aviso": aviso_ativo(), "atraso_min": atraso_min,
		"gerador_quebrado": st_inicio["gerador_quebrado"], "consertou": false,
		"antes": _barras(st_inicio), "depois": _barras(st_fim),
		"q": 0, "escolhidas": [], "feitas": [], "nao_feitas": [],
		"ciencia": 0, "devolvida": 0.0, "perdida_no_teto": 0.0, "o2_produzido": 0,
		"dose": 0.0, "f_exposto": 0.0, "abrigou": false,
		"seguranca": true, "causa": causa, "causa_contexto": causa_contexto(),
	})
	fase = "fim_do_sol"
	versao += 1
	return true


# --- fim do sol, noite, relatório ---------------------------------------------

## "Enviar à Terra": vem a noite e o plano seguinte; depois do último sol, o relatório.
func enviar_a_terra() -> bool:
	if fase != "fim_do_sol":
		return false
	st = st_fim.duplicate()
	if sol >= Modelo.N.SOLS:
		fase = "relatorio"
		# Só a missão fixa sem agenda forçada pela URL destrava o freeplay.
		if not livre and not _agenda_forcada():
			fixa_concluida = true
			freeplay_aberto = true
	else:
		fase = "noite"
		t_noite = 0.0
	versao += 1
	return true


func _terminar_noite() -> void:
	sol += 1
	# O gerador quebra ao entrar no sol sorteado; o instantâneo do sol já o leva quebrado, e o
	# reinício do sol volta a ele.
	if sol == sol_quebra:
		st["gerador_quebrado"] = true
	_comecar_sol()


## A missão tem um evento forçado pela URL (playtest)? Então não é a missão fixa.
func _agenda_forcada() -> bool:
	return forcar_sol_solar in SOLS_SOLAR or forcar_sol_poeira in SOLS_EVENTO or forcar_sol_quebra in SOLS_EVENTO


## "Jogar de novo": depois da missão fixa concluída (nesta sessão ou numa anterior), abre o freeplay.
func jogar_de_novo() -> bool:
	if fase != "relatorio":
		return false
	if freeplay_aberto:
		livre = true
	nova_missao()
	return true


# --- interno -----------------------------------------------------------------

## Começa o plano do sol `sol` com o estado `st`. Sem energia para o aquecimento da noite, ou quando
## nenhum plano salva o sol (a causa veio dos sóis anteriores), o sol já começa em modo de segurança:
## a criança não joga um sol perdido (spec, "Falha e relatório"). Acontece depois da noite.
func _comecar_sol() -> void:
	st_inicio = st.duplicate()
	st_fim = {}
	plano_q = 0
	plano_tarefas = []
	t = 0.0
	t_pico = -1.0
	abrigado = false
	t_exposto = 0.0
	t_abrigado = 0.0
	tarefas = {}
	tarefa_rodando = ""
	tarefa_t = 0.0
	acelerado = false
	causa = ""
	causas = []
	causa_sem_abrigo = false
	tem_conserto = false
	barras_falha = {}
	fase = "plano"
	versao += 1
	if Modelo.manha(st, eh_poeira())["falta_aquecimento"]:
		_entrar_seguranca(["energia"], {"E": 0.0, "O": st["O"], "M": st["M"]})
		return
	# Nenhum plano salva: as falhas e as barras são as do plano de emergência.
	var e := Modelo.emergencia(st, eh_poeira(), eh_sol_solar())
	if not e["falhas"].is_empty():
		_entrar_seguranca(e["falhas"], e["st"])


func _barras(s: Dictionary) -> Dictionary:
	return {"E": s["E"], "O": s["O"], "M": s["M"]}
