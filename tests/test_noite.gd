extends SceneTree
## Teste headless da noite (scripts/terminal.gd, `_desenhar_noite`): o ícone, o "−N" e a barra de energia caindo.
## O N e a barra saem da mesma conta que o plano seguinte usa (Modelo.manha), inclusive num sol de poeira; sem
## energia para o aquecimento a barra cai até zero e o modo de segurança vem depois; a noite dura Missao.NOITE_S
## (0,5 s parada, 0,8 s caindo, 0,7 s parada) e a barra perde uma célula por vez; sem cor de alerta.
## Roda com: godot --headless --path . --script tests/test_noite.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Terminal := preload("res://scripts/terminal.gd")
const Missao := preload("res://scripts/missao.gd")
const Modelo := preload("res://scripts/modelo.gd")
const Som := preload("res://scripts/som.gd")
const Desenho := preload("res://scripts/desenho.gd")

const QUADRO := 1.0 / 60.0

var falhas := 0
var total := 0


func _init() -> void:
	_tudo()


func _tudo() -> void:
	_duracao_e_tempos()
	_a_conta_da_noite()
	_a_barra_cai_uma_celula_por_vez()
	_sem_cor_de_alerta_no_codigo()
	await _o_aviso_na_tela()
	await _a_noite_bate_com_o_plano_seguinte()
	await _sol_de_poeira()
	await _sem_energia_para_o_aquecimento()
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)


func _igual(obtido, esperado, nome: String) -> void:
	total += 1
	if obtido != esperado:
		falhas += 1
		printerr("FALHOU: %s (obtido %s, esperado %s)" % [nome, str(obtido), str(esperado)])


func _verdade(valor: bool, nome: String) -> void:
	_igual(valor, true, nome)


func _perto(obtido: float, esperado: float, nome: String) -> void:
	total += 1
	if absf(obtido - esperado) > 1e-6:
		falhas += 1
		printerr("FALHOU: %s (obtido %s, esperado %s)" % [nome, str(obtido), str(esperado)])


func _quadros(n: int = 2) -> void:
	for i in n:
		await process_frame


## Uma missão no fim do sol `sol_n` com `st_fim` (o estado que "Enviar à Terra" leva para a noite), e o terminal dela.
func _no_fim_do_sol(sol_n: int, st_fim: Dictionary, opcoes: Dictionary = {}) -> Array:
	var m := Missao.new(1, opcoes)
	m.montar_sol(sol_n, {"E": 12.0, "O": 12.0, "M": 12.0, "P": 1.0, "gerador_quebrado": false})
	m.fase = "fim_do_sol"
	m.st_fim = st_fim.duplicate()
	var t: Control = Terminal.new()
	t.som = Som.new()
	t.gravar_textos = true
	t.iniciar(m, {})
	root.add_child(t)
	await _quadros(3)
	return [t, m]


func _liberar(t: Control) -> void:
	root.remove_child(t)
	t.free()


func _estado(e: float, p: float = 1.0) -> Dictionary:
	return {"E": e, "O": 12.0, "M": 12.0, "P": p, "gerador_quebrado": false}


## O texto da tela que começa com `inicio` (vazio se nenhum).
func _texto_da_tela(t: Control, inicio: String) -> String:
	for r: Array in t.textos():
		if str(r[0]).begins_with(inicio):
			return r[0]
	return ""


# --- o tempo ---------------------------------------------------------------------

func _duracao_e_tempos() -> void:
	_perto(Missao.NOITE_S, 2.0, "a noite dura 2,0 s")
	_perto(Terminal.NOITE_PARADA_S, 0.5, "0,5 s parada")
	_perto(Terminal.NOITE_QUEDA_S, 0.8, "0,8 s caindo")
	_perto(Missao.NOITE_S - Terminal.NOITE_PARADA_S - Terminal.NOITE_QUEDA_S, 0.7, "0,7 s parada no fim")
	_perto(Terminal.progresso_da_noite(0.0), 0.0, "progresso no começo")
	_perto(Terminal.progresso_da_noite(0.5), 0.0, "progresso ainda parado em 0,5 s")
	_perto(Terminal.progresso_da_noite(0.9), 0.5, "progresso na metade da queda")
	_perto(Terminal.progresso_da_noite(1.3), 1.0, "progresso no fim da queda")
	_perto(Terminal.progresso_da_noite(Missao.NOITE_S), 1.0, "progresso parado no fim")


# --- a conta ---------------------------------------------------------------------

func _a_conta_da_noite() -> void:
	# Sol comum: o N é o aquecimento que o plano seguinte desconta, e a barra perde N células.
	for e in [1.0, 6.0, 12.0]:
		var c := Terminal.conta_da_noite(_estado(e), false)
		var m := Modelo.manha(_estado(e), false)
		_igual(c["n"], roundi(e + m["renda"] - m["para_dividir"]), "E=%s: o N é o que a manhã desconta" % e)
		_igual(c["n"], 1, "E=%s: aquecimento de 1" % e)
		_perto(c["antes"], e, "E=%s: a barra parte da energia do fim do sol" % e)
		_perto(c["depois"], e - 1.0, "E=%s: e perde 1" % e)
		_verdade(not c["falta"], "E=%s: cobre o aquecimento" % e)
	# Sem energia para o aquecimento (poeira, painel a 10%): a barra cai até zero.
	var f := Terminal.conta_da_noite(_estado(0.0), true)
	_verdade(f["falta"], "E=0 na poeira: não cobre")
	_perto(f["depois"], 0.0, "E=0 na poeira: a barra zera")
	var g := Terminal.conta_da_noite(_estado(0.1), true)
	_verdade(g["falta"], "E=0,1 na poeira: 0,1 + 0,8 < 1, não cobre")
	_perto(g["antes"], 0.1, "E=0,1: parte de 0,1")
	_perto(g["depois"], 0.0, "E=0,1: cai até zero")
	_verdade(g["n"] >= 1, "o N nunca é 0")
	# Com o painel ajudando, a bateria baixa ainda cobre: 0,6 + 0,8 = 1,4.
	var h := Terminal.conta_da_noite(_estado(0.6), true)
	_verdade(not h["falta"], "E=0,6 na poeira: 0,6 + 0,8 cobre")
	_igual(h["falta"], Modelo.manha(_estado(0.6), true)["falta_aquecimento"], "a falta segue a conta da manhã")
	# A barra nunca passa dos limites.
	var topo := Terminal.conta_da_noite(_estado(12.0), false)
	_verdade(topo["antes"] <= Modelo.N.TETO and topo["depois"] >= 0.0, "dentro de 0 e do teto")


func _a_barra_cai_uma_celula_por_vez() -> void:
	# Um aquecimento de 3 (sintético: o jogo usa 1) cai uma célula de cada vez, do começo ao fim da queda.
	var c := {"n": 3, "antes": 6.0, "depois": 3.0, "falta": false}
	var anterior := roundi(Terminal.energia_na_noite(c, 0.0))
	_igual(anterior, 6, "começa cheia até a energia do fim do sol")
	var passos: Array = []
	var t := 0.0
	while t <= Missao.NOITE_S:
		var cel := roundi(Terminal.energia_na_noite(c, t))
		_verdade(anterior - cel in [0, 1], "t=%.2f: no máximo uma célula por quadro" % t)
		if cel != anterior:
			passos.append(t)
		anterior = cel
		t += QUADRO
	_igual(anterior, 3, "termina com N células a menos")
	_igual(passos.size(), 3, "três quedas, uma por vez")
	_verdade(passos[0] > Terminal.NOITE_PARADA_S, "nada cai antes de 0,5 s")
	_verdade(passos[2] <= Terminal.NOITE_PARADA_S + Terminal.NOITE_QUEDA_S + QUADRO, "tudo cai até 1,3 s")
	# Com N = 1, a célula cai no meio da queda e fica parada depois.
	var u := {"n": 1, "antes": 6.0, "depois": 5.0, "falta": false}
	_igual(roundi(Terminal.energia_na_noite(u, 0.4)), 6, "N=1 em 0,4 s: cheia")
	_igual(roundi(Terminal.energia_na_noite(u, 1.0)), 5, "N=1 em 1,0 s: caiu")
	_igual(roundi(Terminal.energia_na_noite(u, 1.9)), 5, "N=1 em 1,9 s: parada")


## A noite não usa vermelho nem amarelo: nem a conta, nem o desenho (o desenho não se inspeciona sem janela;
## aqui se lê o corpo de `_desenhar_noite` e das funções da conta).
func _sem_cor_de_alerta_no_codigo() -> void:
	var f := FileAccess.open("res://scripts/terminal.gd", FileAccess.READ)
	var fonte := f.get_as_text()
	f.close()
	var ini := fonte.find("static func conta_da_noite")
	var fim := fonte.find("# --- modo de segurança")
	_verdade(ini > 0 and fim > ini, "achou o trecho da noite")
	var trecho := fonte.substr(ini, fim - ini)
	for proibida in ["AMARELO", "VERMELHO", '"alerta"']:
		_verdade(not trecho.contains(proibida), "a noite não usa " + proibida)
	_verdade(trecho.contains('cor_recurso("energia")'), "a energia da noite é a cor do recurso")


# --- na tela -----------------------------------------------------------------------

func _o_aviso_na_tela() -> void:
	for lingua in ["en", "pt"]:
		TranslationServer.set_locale(lingua)
		var r := await _no_fim_do_sol(1, _estado(6.0))
		var t: Control = r[0]
		var m: Missao = r[1]
		_verdade(m.enviar_a_terra(), "[%s] enviar à Terra" % lingua)
		_igual(m.fase, "noite", "[%s] a fase é a noite" % lingua)
		await _quadros(3)
		_igual(t._fase_tela, "noite", "[%s] o terminal desenha a noite" % lingua)
		_igual(_texto_da_tela(t, "−"), "−1", "[%s] o −N" % lingua)
		_verdade(_texto_da_tela(t, tr("NOITE_AQUECIMENTO_A")) != "", "[%s] a frase começa com o aquecimento" % lingua)
		_verdade(_texto_da_tela(t, tr("NOITE_AQUECIMENTO_B")) != "", "[%s] e termina com a energia" % lingua)
		_verdade(_texto_da_tela(t, tr("ENERGIA")) != "", "[%s] a barra leva o nome da energia" % lingua)
		# A frase cabe na tela de 640 px, em cada língua.
		var x_min := 1000.0
		var x_max := 0.0
		for reg: Array in t.textos():
			if reg[3] == 16:
				x_min = minf(x_min, reg[1])
				x_max = maxf(x_max, reg[1] + Desenho.largura_texto(str(reg[0]), 16, true))
		_verdade(x_min >= 20.0 and x_max <= 620.0, "[%s] a frase cabe (%d a %d)" % [lingua, x_min, x_max])
		_liberar(t)
	TranslationServer.set_locale("en")


## A noite do sol 1 ao sol 4 (sóis de poeira incluídos): o N e a barra da noite são os do plano que abre depois.
func _a_noite_bate_com_o_plano_seguinte() -> void:
	for sol_n in range(1, 5):
		var r := await _no_fim_do_sol(sol_n, _estado(7.0))
		var t: Control = r[0]
		var m: Missao = r[1]
		m.enviar_a_terra()
		var poeira_da_noite: bool = t._poeira_da_manha()
		var conta := Terminal.conta_da_noite(m.st, poeira_da_noite)
		m.avancar(Missao.NOITE_S + 0.1)
		_igual(m.sol, sol_n + 1, "sol %d: a noite passou" % sol_n)
		_igual(m.fase, "plano", "sol %d: o plano seguinte abre" % sol_n)
		var manha := Modelo.manha(m.st, m.eh_poeira())
		_igual(poeira_da_noite, m.eh_poeira(), "sol %d: a noite sabe se o sol seguinte é de poeira" % sol_n)
		_igual(conta["n"], roundi(m.st["E"] + manha["renda"] - manha["para_dividir"]),
			"sol %d: o N da noite é o aquecimento que o plano seguinte desconta" % sol_n)
		_perto(conta["antes"], m.st["E"], "sol %d: a barra parte da bateria com que o plano abre" % sol_n)
		_perto(conta["depois"], m.st["E"] - conta["n"], "sol %d: e termina N células abaixo" % sol_n)
		_liberar(t)


## Antes do sol 3 (poeira) a noite já conta com o painel a 10%: com a bateria em zero, não cobre o aquecimento;
## o sol 2 e o sol 5 (não poeira) cobrem.
func _sol_de_poeira() -> void:
	var esperado := {1: false, 2: true, 3: true, 4: false}  # a noite do sol N é a manhã do sol N+1
	for sol_n: int in esperado:
		var r := await _no_fim_do_sol(sol_n, _estado(0.0))
		var t: Control = r[0]
		var m: Missao = r[1]
		m.enviar_a_terra()
		_igual(t._poeira_da_manha(), esperado[sol_n], "noite do sol %d: a manhã de poeira" % sol_n)
		var c := Terminal.conta_da_noite(m.st, t._poeira_da_manha())
		# Sem poeira, E=0 + painel 8 cobre; na poeira, 0 + 0,8 < 1 não cobre.
		_igual(c["falta"], esperado[sol_n], "noite do sol %d: falta energia só na poeira" % sol_n)
		_liberar(t)


## Terminar o sol sem energia para o aquecimento: a barra zera e o modo de segurança vem depois da noite.
func _sem_energia_para_o_aquecimento() -> void:
	var r := await _no_fim_do_sol(2, _estado(0.0))
	var t: Control = r[0]
	var m: Missao = r[1]
	m.enviar_a_terra()
	await _quadros(3)
	_igual(m.fase, "noite", "sem energia: a noite vem antes do modo de segurança")
	_igual(t._fase_tela, "noite", "sem energia: o terminal desenha a noite")
	var c := Terminal.conta_da_noite(m.st, t._poeira_da_manha())
	_verdade(c["falta"], "sem energia: a conta diz que não cobre")
	_perto(Terminal.energia_na_noite(c, Missao.NOITE_S), 0.0, "sem energia: a barra termina em zero")
	_verdade(_texto_da_tela(t, "−") != "", "sem energia: o −N continua na tela")
	m.avancar(Missao.NOITE_S + 0.1)
	_igual(m.fase, "seguranca", "sem energia: o modo de segurança vem depois")
	_igual(m.causa, "energia", "sem energia: a causa é a energia")
	_perto(m.barras_falha["E"], 0.0, "sem energia: a tela do modo de segurança também zera a barra")
	_liberar(t)
