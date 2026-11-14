extends RefCounted
## Máquina da missão em lógica pura: sem nó, sem cena, sem UI.
##
## Dona do estado do jogo: o sol, a fase, o estado do modelo, o plano em edição, o relógio do
## turno, o abrigo, a exposição, as tarefas de ciência, os modos de segurança e o registro de cada
## sol (que alimenta o diário e o relatório). Toda conta de recurso vem de modelo.gd; aqui só mora
## a ordem das coisas e as regras do turno.
##
## Fases: "plano" -> "turno" -> "fim_do_sol" -> "noite" -> "plano" do sol seguinte; depois do sol 5,
## "relatorio". Falha leva a "seguranca" (ver _entrar_seguranca).
##
## A UI chama as ações (mudar_q, alternar_tarefa, confirmar_plano, iniciar_tarefa, alternar_abrigo,
## enviar_a_terra, reiniciar_sol, seguir_em_seguranca, jogar_de_novo) e avancar(delta), e lê o estado.
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
const SOLS_SOLAR := [3, 4]  # sóis em que pode cair a tempestade solar (um por missão)
const ATRASO_MIN := 3       # o "há N min" do card da Terra, sorteado por missão
const ATRASO_MAX := 22
const SOL_AVISO := 2        # sol do primeiro aviso da tempestade solar

# Medidor de radiação (0..1) e seus dois limiares.
const LIMIAR_ATENCAO := 0.4
const LIMIAR_ABRIGO := 0.7
const MEDIDOR_BAIXO := 0.15
const MEDIDOR_ALTO := 0.9

const TAREFAS := ["chemcam", "amostra", "planta"]
const EPS := 1e-9

var rng := RandomNumberGenerator.new()
var turno_s := TURNO_S
var tarefa_s := TAREFA_S
var forcar_sol_solar := 0   # 3 ou 4 força o sol da tempestade; 0 sorteia

var sol_solar := 3
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
var tarefas := {}          # nome -> "pendente" | "rodando" | "feita"
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


## `opcoes`: turno_s, tarefa_s, sol_solar (3 ou 4, força o sol da tempestade).
func _init(semente: int = -1, opcoes: Dictionary = {}) -> void:
	if semente >= 0:
		rng.seed = semente
	else:
		rng.randomize()
	turno_s = float(opcoes.get("turno_s", TURNO_S))
	tarefa_s = float(opcoes.get("tarefa_s", TAREFA_S))
	forcar_sol_solar = int(opcoes.get("sol_solar", 0))
	nova_missao()


## Começa uma missão nova, com novo sorteio.
func nova_missao() -> void:
	var sorteado: int = SOLS_SOLAR[rng.randi_range(0, SOLS_SOLAR.size() - 1)]
	sol_solar = forcar_sol_solar if forcar_sol_solar in SOLS_SOLAR else sorteado
	atraso_min = rng.randi_range(ATRASO_MIN, ATRASO_MAX)
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


## Aviso da tempestade solar nos planos do sol 2 até o sol da tempestade, inclusive.
func aviso_ativo() -> bool:
	return sol >= SOL_AVISO and sol <= sol_solar


func para_dividir() -> float:
	return Modelo.manha(st, false)["para_dividir"]


func previsao() -> Dictionary:
	return Modelo.previsao(st, false, plano_q, plano_tarefas.size())


func plano_cabe(q: int, n: int) -> bool:
	return Modelo.plano_cabe(st, false, q, n)


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
			var bateria: float = Modelo.previsao(st, false, plano_q, plano_tarefas.size())["bateria_apos_plano"]
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


func ciencia_do_sol() -> int:
	var n := 0
	for nome in tarefas:
		if tarefas[nome] == "feita":
			n += 1
	return n


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


# --- plano -------------------------------------------------------------------

## Muda o O2 do plano em `delta`. Só vale se o plano novo cabe.
func mudar_q(delta: int) -> bool:
	if fase != "plano":
		return false
	var novo := plano_q + delta
	if not Modelo.plano_cabe(st, false, novo, plano_tarefas.size()):
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
	if not Modelo.plano_cabe(st, false, plano_q, novas.size()):
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
	tarefas = {}
	for nome in plano_tarefas:
		tarefas[nome] = "pendente"
	# O pico é sorteado de novo a cada turno (inclusive quando o sol reinicia).
	t_pico = -1.0
	if eh_sol_solar():
		t_pico = rng.randf_range(PICO_MIN, PICO_MAX) * turno_s
	versao += 1
	return true


# --- turno -------------------------------------------------------------------

## Inicia uma tarefa de ciência: escolhida no plano, pendente, sem outra rodando e fora do abrigo.
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


## O abrigo vale a qualquer momento do turno. Abrigar interrompe a tarefa que rodava: ela volta a
## pendente e perde o andamento. É assim que o abrigo custa tempo, não energia.
func alternar_abrigo() -> bool:
	if fase != "turno":
		return false
	abrigado = not abrigado
	if abrigado and tarefa_rodando != "":
		tarefas[tarefa_rodando] = "pendente"
		tarefa_rodando = ""
		tarefa_t = 0.0
	versao += 1
	return true


## Avança o relógio do jogo `delta` segundos (só mexe no turno e na noite).
func avancar(delta: float) -> void:
	match fase:
		"turno":
			_avancar_turno(delta)
		"noite":
			t_noite += delta
			if t_noite >= NOITE_S - EPS:
				_terminar_noite()


func _avancar_turno(delta: float) -> void:
	var dt := minf(maxf(delta, 0.0), turno_s - t)
	var t1 := t + dt
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
	var r := Modelo.fechar_sol(st_inicio, false, plano_q, plano_tarefas.size(), feitas.size(), dose, false)
	if not r["falhas"].is_empty():
		_entrar_seguranca(r["falhas"], r["st"])
		return
	st_fim = r["st"]
	ciencia_por_sol.append(feitas.size())
	registros.append({
		"sol": sol, "tempestade": solar, "aviso": aviso_ativo(), "atraso_min": atraso_min,
		"antes": _barras(st_inicio), "depois": _barras(st_fim),
		"q": plano_q, "escolhidas": plano_tarefas.duplicate(), "feitas": feitas, "nao_feitas": nao_feitas,
		"ciencia": feitas.size(), "devolvida": r["devolvida"], "perdida_no_teto": r["perdida_no_teto"],
		"o2_produzido": r["o2_produzido"], "dose": dose, "f_exposto": f, "abrigou": t_abrigado > 0.0,
		"seguranca": false, "causa": "",
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
	tem_conserto = Modelo.algum_plano_salva(st_inicio, false, eh_sol_solar())
	fase = "seguranca"
	abrigado = false
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
	st_fim = Modelo.seguir_em_seguranca(st_inicio, false, eh_sol_solar())
	ciencia_por_sol.append(0)
	registros.append({
		"sol": sol, "tempestade": eh_sol_solar(), "aviso": aviso_ativo(), "atraso_min": atraso_min,
		"antes": _barras(st_inicio), "depois": _barras(st_fim),
		"q": 0, "escolhidas": [], "feitas": [], "nao_feitas": [],
		"ciencia": 0, "devolvida": 0.0, "perdida_no_teto": 0.0, "o2_produzido": 0,
		"dose": 0.0, "f_exposto": 0.0, "abrigou": false,
		"seguranca": true, "causa": causa,
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
	else:
		fase = "noite"
		t_noite = 0.0
	versao += 1
	return true


func _terminar_noite() -> void:
	sol += 1
	_comecar_sol()


func jogar_de_novo() -> bool:
	if fase != "relatorio":
		return false
	nova_missao()
	return true


# --- interno -----------------------------------------------------------------

## Começa o plano do sol `sol` com o estado `st`. Sem energia para o aquecimento da noite, o sol
## já começa em modo de segurança (no P0 isso não acontece em jogo; os testes montam o estado).
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
	causa = ""
	causas = []
	causa_sem_abrigo = false
	tem_conserto = false
	barras_falha = {}
	fase = "plano"
	versao += 1
	if Modelo.manha(st, false)["falta_aquecimento"]:
		_entrar_seguranca(["energia"], {"E": 0.0, "O": st["O"], "M": st["M"]})


func _barras(s: Dictionary) -> Dictionary:
	return {"E": s["E"], "O": s["O"], "M": s["M"]}
