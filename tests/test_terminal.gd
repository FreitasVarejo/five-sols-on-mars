extends SceneTree
## Teste headless do terminal animado (scripts/terminal.gd), sem desenhar: a duração da URL, o easing, a
## animação de subir e descer (alvo, posição, inversão no meio, sons), o que tapa a sala e o conteúdo
## que fica para trás numa descida automática.
## Roda com: godot --headless --path . --script tests/test_terminal.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Terminal := preload("res://scripts/terminal.gd")
const Missao := preload("res://scripts/missao.gd")
const Modelo := preload("res://scripts/modelo.gd")
const Som := preload("res://scripts/som.gd")
const HudTurno := preload("res://scripts/hud_turno.gd")
const Desenho := preload("res://scripts/desenho.gd")
const Main := preload("res://scripts/main.gd")
const DadosDonki := preload("res://scripts/dados_donki.gd")
const ConsertarGerador := preload("res://scripts/minigames/consertar_gerador.gd")

const QUADRO := 1.0 / 60.0

var falhas := 0
var total := 0


func _init() -> void:
	_tudo()


func _tudo() -> void:
	_duracao_da_url()
	_easing()
	_botao_sobe_e_desce()
	_inverte_no_meio()
	_ultimo_passo_redesenha()
	_confirmar_plano_desce_com_o_plano()
	_fim_do_turno_sobe_depois_do_escurecimento()
	_cliques_so_quando_a_acao_acontece()
	_desligar_no_meio_do_turno()
	_desligar_pelo_relogio()
	_alarme_uma_vez_por_travessia()
	_alerta_por_cima_do_terminal()
	_linha_do_abrigo_fecha_o_terminal_e_pede_o_pan()
	_pan_ate_o_botao_do_abrigo()
	_da_noite_para_a_seguranca()
	_fila_de_cards()
	_cards_da_poeira_e_do_gerador()
	_cards_com_o_sol_em_seguranca()
	await _botoes_das_pecas_e_visor()
	_pecas_nas_cameras()
	_peca_conclui_abrigo_e_reinicio()
	await _cliques_chegam_ao_visor_e_a_peca()
	await _frase_com_o_contexto()
	await _cards_ao_lado_do_controle()
	await _card_do_aviso_cabe()
	await _aba_fontes_cabe()
	await _aba_fontes_rola()
	await _relatorio_cabe()
	_historia_do_sol_no_diario()
	_diario_cabe_no_pior_caso()
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


## Um terminal sobre uma missão, com um Som que só registra. Não entra na árvore: o teste chama _process.
func _montar(opcoes: Dictionary = {}) -> Array:
	var m := Missao.new(1, opcoes)
	var som := Som.new()
	var t: Control = Terminal.new()
	t.som = som
	t.iniciar(m, {})
	# O plano do sol 1 já abre com a fila de cards: o aviso da tempestade solar (agenda fixa: aviso desde o
	# sol 1) e os três do sol 1. Estes testes são do terminal sem card: a fila é fechada de uma vez, com o
	# som dos cliques de fechar apagado (o terminal começa sem som, como antes).
	_igual(_fechar_fila(t), 4, "o plano do sol 1 abre com quatro cards: o aviso e os três do sol 1")
	som.historico.clear()
	som.total = 0
	return [t, m, som]


## Fecha a fila de cards inteira, um "Fechar" por vez, e devolve quantos fechou.
func _fechar_fila(t: Control) -> int:
	var n := 0
	while t.card_aberto and n < 20:
		t._acionar("fechar_card")
		n += 1
	return n


## Roda `s` segundos de quadros: a missão avança e o terminal anda.
func _rodar(t: Control, m: Missao, s: float) -> void:
	var n := roundi(s / QUADRO)
	for i in n:
		m.avancar(QUADRO)
		t._process(QUADRO)


func _duracao_da_url() -> void:
	_igual(Terminal.duracao_da_url(null), 0.3, "sem parâmetro: o padrão")
	_igual(Terminal.duracao_da_url("0.25"), 0.25, "0,25")
	_igual(Terminal.duracao_da_url("0.4"), 0.4, "0,4")
	_igual(Terminal.duracao_da_url("0.6"), 0.6, "0,6")
	_igual(Terminal.duracao_da_url("0.15"), 0.15, "limite baixo")
	_igual(Terminal.duracao_da_url("1.5"), 1.5, "limite alto")
	_igual(Terminal.duracao_da_url("0.05"), 0.3, "abaixo da faixa: o padrão")
	_igual(Terminal.duracao_da_url("9"), 0.3, "acima da faixa: o padrão")
	_igual(Terminal.duracao_da_url("abc"), 0.3, "texto: o padrão")
	_igual(Terminal.duracao_da_url("0"), 0.3, "zero: o padrão")


func _easing() -> void:
	_igual(Terminal.suavizar(0.0), 0.0, "easing começa em 0")
	_igual(Terminal.suavizar(1.0), 1.0, "easing termina em 1")
	_igual(Terminal.suavizar(0.5), 0.5, "easing passa pelo meio")
	_verdade(Terminal.suavizar(0.1) < 0.1, "começa devagar")
	_verdade(Terminal.suavizar(0.9) > 0.9, "termina devagar")
	var anterior := -1.0
	var sobe := true
	for i in 101:
		var v := Terminal.suavizar(i / 100.0)
		sobe = sobe and v >= anterior
		anterior = v
	_verdade(sobe, "o easing nunca desce")
	_igual(Terminal.suavizar(-1.0), 0.0, "fora da faixa, preso em 0")
	_igual(Terminal.suavizar(2.0), 1.0, "fora da faixa, preso em 1")


func _botao_sobe_e_desce() -> void:
	var c := _montar()
	var t: Control = c[0]
	var m: Missao = c[1]
	var som: Som = c[2]
	_igual(t.aberto, true, "o plano começa com o terminal no alto")
	_igual(t.posicao(), 1.0, "começa no alto")
	_igual(t.animando(), false, "sem animação no começo")
	_igual(t.tapa_a_sala(), true, "aberto tapa a sala")
	# O botão abaixa: anima, e a sala segue tapada até chegar embaixo.
	t._acionar("terminal")
	_igual(t.aberto, false, "o botão abaixa")
	_igual(som.historico, ["terminal_desce"], "som de descer no começo")
	_verdade(t.animando(), "animando ao descer")
	_verdade(t.tapa_a_sala(), "tapa a sala no começo da descida")
	_rodar(t, m, t.duracao / 2.0)
	_verdade(t.animando(), "ainda descendo no meio")
	_verdade(t.tapa_a_sala(), "tapa a sala no meio da descida")
	_verdade(t.posicao() > 0.0 and t.posicao() < 1.0, "no meio do caminho")
	_rodar(t, m, t.duracao)
	_igual(t.posicao(), 0.0, "chegou embaixo")
	_igual(t.animando(), false, "parou embaixo")
	_igual(t.tapa_a_sala(), false, "abaixado libera a sala")
	# E sobe.
	t._acionar("terminal")
	_igual(som.historico, ["terminal_desce", "terminal_sobe"], "som de subir no começo")
	_verdade(t.tapa_a_sala(), "tapa a sala ao subir")
	_rodar(t, m, t.duracao * 2.0)
	_igual(t.posicao(), 1.0, "chegou no alto")
	_igual(t.animando(), false, "parou no alto")
	c[2].free()
	t.free()


func _inverte_no_meio() -> void:
	var c := _montar()
	var t: Control = c[0]
	var m: Missao = c[1]
	var som: Som = c[2]
	t._acionar("terminal")
	_rodar(t, m, t.duracao * 0.4)
	var antes: float = t._pos
	_verdade(antes > 0.0 and antes < 1.0, "no meio da descida")
	t._acionar("terminal")
	_igual(t.aberto, true, "inverteu: volta a subir")
	_igual(t._pos, antes, "a inversão parte do ponto em que está")
	_igual(som.historico, ["terminal_desce", "terminal_sobe"], "descer e, na inversão, subir")
	_verdade(t.tapa_a_sala(), "tapa a sala na inversão")
	_rodar(t, m, QUADRO * 3.0)
	_verdade(t._pos > antes, "passou a subir")
	_rodar(t, m, t.duracao)
	_igual(t.posicao(), 1.0, "terminou no alto")
	som.free()
	t.free()


## O passo que chega ao alvo também avisa que mudou: é o quadro que redesenha o terminal já parado (e com
## os botões do conteúdo de volta a ser clicáveis); sem ele a tela ficava no penúltimo passo.
func _ultimo_passo_redesenha() -> void:
	for sobe in [false, true]:
		var c := _montar()
		var t: Control = c[0]
		if sobe:
			t._acionar("terminal")
			for i in 200:
				t._animar(QUADRO)
		t._acionar("terminal")
		var alvo := 1.0 if t.aberto else 0.0
		var chegou_avisando := false
		for i in 200:
			var mudou: bool = t._animar(QUADRO)
			if t._pos == alvo and mudou:
				chegou_avisando = true
		_verdade(chegou_avisando, "o passo que chega ao alvo avisa que mudou (alvo %s)" % alvo)
		_igual(t._animar(QUADRO), false, "parado no alvo, _animar devolve falso")
		c[2].free()
		t.free()


func _confirmar_plano_desce_com_o_plano() -> void:
	var c := _montar({"turno_s": 30.0})
	var t: Control = c[0]
	var m: Missao = c[1]
	var som: Som = c[2]
	_igual(t.aba_na_tela(), "plano", "o plano na tela")
	m.confirmar_plano()
	_rodar(t, m, QUADRO * 2.0)
	_igual(t.aberto, false, "confirmar o plano abaixa o terminal")
	_igual(som.historico, ["terminal_desce"], "som de descer na descida automática")
	_igual(t.fase_ui, "turno", "a sala já vê o turno")
	_igual(t.aba_na_tela(), "plano", "descendo, o terminal ainda mostra o plano")
	_verdade(t.tapa_a_sala(), "a sala segue tapada enquanto desce")
	_rodar(t, m, t.duracao * 1.5)
	_igual(t.posicao(), 0.0, "embaixo")
	_igual(t.aba_na_tela(), "tarefas", "embaixo, o terminal passa a mostrar o turno")
	_igual(t.tapa_a_sala(), false, "a sala libera")
	som.free()
	t.free()


func _fim_do_turno_sobe_depois_do_escurecimento() -> void:
	var c := _montar({"turno_s": 10.0})
	var t: Control = c[0]
	var m: Missao = c[1]
	var som: Som = c[2]
	m.confirmar_plano()
	_rodar(t, m, t.duracao * 1.5)
	_igual(t.posicao(), 0.0, "turno com o terminal embaixo")
	som.historico.clear()
	# O relógio chega ao fim: a missão vai ao fim do sol e o terminal escurece antes de subir.
	var guarda := 0
	while m.fase == "turno" and guarda < 2000:
		_rodar(t, m, 0.1)
		guarda += 1
	_igual(m.fase, "fim_do_sol", "o relógio acabou o turno")
	_igual(t._fade_estado, "escurecendo", "escurecendo")
	_verdade(t.tapa_a_sala(), "tapa a sala escurecendo")
	_igual(t.aberto, false, "ainda não subiu")
	_igual(som.historico, [], "sem som de subir antes do escurecimento acabar")
	_rodar(t, m, Terminal.ESCURECER_S + 0.05)
	_igual(t.aberto, true, "subiu quando o escurecimento chegou ao máximo")
	_igual(som.historico, ["terminal_sobe"], "som de subir uma vez")
	_igual(t._fade_estado, "clareando", "subindo junto com o clarear")
	_verdade(t.animando() or t.posicao() > 0.0, "a subida começou")
	_igual(t.aba_na_tela(), "diario", "sobe com o diário do fim do sol")
	_rodar(t, m, t.duracao + 0.1)
	_igual(t.posicao(), 1.0, "no alto")
	som.free()
	t.free()


func _cliques_so_quando_a_acao_acontece() -> void:
	var c := _montar({"turno_s": 30.0})
	var t: Control = c[0]
	var m: Missao = c[1]
	var som: Som = c[2]
	# No plano: o mais e as teclas navegam; tarefa liga e desliga.
	t._acionar("o2_mais")
	t._acionar("aba_fontes")
	t._acionar("aba_fontes")
	t._acionar("tarefa_chemcam")
	_igual(som.historico, ["clique_navegar", "clique_navegar", "clique_navegar", "clique_navegar"], "navegar no plano")
	som.historico.clear()
	# O botão do terminal só tem o sobe e desce.
	t._acionar("terminal")
	t._acionar("terminal")
	_igual(som.historico, ["terminal_desce", "terminal_sobe"], "o botão TERMINAL não faz clique")
	som.historico.clear()
	# Com o card da Terra aberto (o aviso, que reabre com o plano), só o Fechar vale: o resto não faz som.
	t._mostrar_na_tela("plano")
	_verdade(t.card_aberto, "o plano reaberto traz o aviso")
	t._acionar("o2_mais")
	t._acionar("confirmar")
	_igual(som.historico, [], "bloqueado pelo card: sem som")
	_igual(m.fase, "plano", "o card barrou o confirmar")
	t._acionar("fechar_card")
	_igual(som.historico, ["clique_navegar"], "fechar o card navega")
	som.historico.clear()
	# O2 menos sem O2 no plano não acontece.
	m.plano_q = 0
	t._acionar("o2_menos")
	_igual(som.historico, [], "ação que não acontece não faz som")
	# Confirmar é do peso de confirmar, e o sol segue.
	t._acionar("confirmar")
	_rodar(t, m, QUADRO * 2.0)
	_igual(som.historico, ["clique_confirmar", "terminal_desce"], "confirmar: clique e a descida")
	som.historico.clear()
	# O terminal chega embaixo e o sol 1 abre o card do primeiro turno: o botão TERMINAL não vale, só o Fechar.
	_rodar(t, m, t.duracao * 1.5)
	_igual(t.card_id, "turno", "o card do primeiro turno abre embaixo")
	t._acionar("terminal")
	t._acionar("aba_cameras")
	_igual(som.historico, [], "com o card do turno aberto, só o Fechar faz algo")
	_igual(_fechar_fila(t), 1, "o card do turno fecha com um Fechar")
	som.historico.clear()
	# No turno, a tecla desabilitada (diário) não faz nada.
	t._acionar("aba_diario")
	_igual(som.historico, [], "tecla desabilitada: sem som")
	t._acionar("aba_cameras")
	_igual(som.historico, ["clique_navegar"], "tecla habilitada navega")
	som.free()
	t.free()


## A fila de cards do plano: a ordem no sol 1 (aviso, O2, ciência, confirmar), só "Fechar" age enquanto há
## card, os do sol 1 não voltam no reinício do sol 1 nem no freeplay, e o aviso volta no reinício.
func _fila_de_cards() -> void:
	var m := Missao.new(1, {"sol_solar": 3, "turno_s": 4.0})
	m.montar_sol(1, {"E": 6.0, "O": 1.0, "M": 12.0, "P": 1.0, "gerador_quebrado": false})
	var som := Som.new()
	var t: Control = Terminal.new()
	t.som = som
	t.iniciar(m, {})
	_verdade(t.card_aberto, "o plano do sol 1 abre com card")
	var ordem: Array = []
	var q0 := m.plano_q
	while t.card_aberto and ordem.size() < 10:
		ordem.append(t.card_id)
		# Enquanto há card, nada do plano age: só o "Fechar".
		for nome in ["o2_mais", "o2_menos", "tarefa_chemcam", "tarefa_amostra", "aba_fontes", "terminal", "confirmar", "reiniciar"]:
			t._acionar(nome)
		_igual(m.plano_q, q0, "card %s: o2 não mudou" % t.card_id)
		_igual(m.plano_tarefas.size(), 0, "card %s: nenhuma tarefa ligada" % t.card_id)
		_igual(m.fase, "plano", "card %s: a missão segue no plano" % t.card_id)
		_igual(t.aba_na_tela(), "plano", "card %s: a aba não mudou" % t.card_id)
		_igual(t.aberto, true, "card %s: o terminal não desceu" % t.card_id)
		t._acionar("fechar_card")
	_igual(ordem, ["aviso", "sol1_o2", "sol1_ciencia", "sol1_confirmar"], "a ordem da fila no sol 1")
	_igual(t.card_id, "", "a fila acabou")
	# Reinício do sol 1 (o2 1 sem produzir cai em segurança): volta só o aviso.
	t._acionar("confirmar")
	_igual(t.segura_o_relogio(), true, "o relógio espera o card do primeiro turno desde o Confirmar")
	_rodar(t, m, t.duracao * 1.5)
	_igual(_fechar_fila(t), 1, "o primeiro turno abre o card do turno")
	_igual(t.segura_o_relogio(), false, "fechado o card, o relógio corre")
	_ate_sair_do_turno(t, m)
	_igual(m.fase, "seguranca", "o sol 1 caiu em segurança")
	_rodar(t, m, QUADRO * 3.0)
	_igual(t.card_aberto, false, "a tela de segurança não leva card")
	t._acionar("reiniciar")
	_igual(m.fase, "plano", "reiniciou o sol 1")
	_rodar(t, m, QUADRO * 3.0)
	_igual(t.card_id, "aviso", "o aviso volta no reinício")
	_igual(_fechar_fila(t), 1, "no reinício do sol 1 só o aviso (os três do sol 1 não voltam)")
	som.free()
	t.free()
	# Freeplay: o sol 1 não leva os cards do sol 1, só o aviso.
	var l := Missao.new(3, {"livre": true})
	var t2: Control = Terminal.new()
	t2.som = Som.new()
	t2.iniciar(l, {})
	_verdade(l.livre, "freeplay")
	var ordem_livre: Array = []
	while t2.card_aberto and ordem_livre.size() < 10:
		ordem_livre.append(t2.card_id)
		t2._acionar("fechar_card")
	_igual(ordem_livre, ["aviso"], "no freeplay, só o aviso no plano do sol 1")
	t2.som.free()
	t2.free()
	# O mesmo terminal que viu os cards do sol 1 na missão fixa e depois entra no freeplay: sem repetir.
	var f := Missao.new(1, {"freeplay_aberto": true})
	var t3: Control = Terminal.new()
	t3.som = Som.new()
	t3.iniciar(f, {})
	_igual(_fechar_fila(t3), 4, "a missão fixa abre com os quatro cards")
	f.fase = "relatorio"
	t3._process(QUADRO)
	_verdade(f.jogar_de_novo(), "jogar de novo abre o freeplay")
	t3._process(QUADRO)
	_igual(t3.fase_ui, "plano", "o plano do freeplay")
	_igual(_fechar_fila(t3), 1 if f.aviso_ativo() else 0, "no freeplay do mesmo terminal, só o aviso (os do sol 1 não repetem)")
	t3.som.free()
	t3.free()


## Leva a missão e o terminal ao plano do sol `n` com o estado `estado`, pela noite (o terminal vê a troca de fase).
func _ir_ao_sol(t: Control, m: Missao, n: int, estado: Dictionary) -> void:
	m.fase = "noite"
	m.versao += 1
	t._process(QUADRO)
	m.montar_sol(n, estado)
	t._process(QUADRO)
	t._process(QUADRO)


## Os ids dos cards que a fila do plano atual abre, na ordem (fecha todos).
func _ordem_da_fila(t: Control) -> Array:
	var ordem: Array = []
	while t.card_aberto and ordem.size() < 10:
		ordem.append(t.card_id)
		t._acionar("fechar_card")
	return ordem


## Com a agenda fixa, a poeira abre no sol 3 (e não no 4), o gerador no sol 5; cada um uma vez só na sessão.
func _cards_da_poeira_e_do_gerador() -> void:
	var m := Missao.new(1)
	var som := Som.new()
	var t: Control = Terminal.new()
	t.som = som
	t.iniciar(m, {})
	var bom := {"E": 10.0, "O": 10.0, "M": 12.0, "P": 1.0, "gerador_quebrado": false}
	_igual(_ordem_da_fila(t), ["aviso", "sol1_o2", "sol1_ciencia", "sol1_confirmar"], "sol 1: sem poeira nem gerador")
	_ir_ao_sol(t, m, 2, bom)
	_igual(m.fase, "plano", "sol 2: plano")
	_igual(_ordem_da_fila(t), ["aviso"], "sol 2: só o aviso")
	_ir_ao_sol(t, m, 3, bom)
	_verdade(m.eh_poeira(), "sol 3: poeira")
	_igual(_ordem_da_fila(t), ["poeira"], "sol 3: o card da poeira abre (o aviso já acabou)")
	_ir_ao_sol(t, m, 4, bom)
	_verdade(m.eh_poeira(), "sol 4: ainda poeira")
	_igual(_ordem_da_fila(t), [], "sol 4: a poeira já foi vista, sem card")
	var quebrado := bom.duplicate()
	quebrado["gerador_quebrado"] = true
	_ir_ao_sol(t, m, 5, quebrado)
	_igual(m.fase, "plano", "sol 5: plano")
	_verdade(m.st_inicio["gerador_quebrado"], "sol 5: gerador quebrado")
	_igual(_ordem_da_fila(t), ["gerador"], "sol 5: o card do gerador abre")
	# Reiniciar o plano do sol 5 (ou jogá-lo de novo): os dois já foram vistos.
	_ir_ao_sol(t, m, 5, quebrado)
	_igual(_ordem_da_fila(t), [], "o gerador não volta")
	# Um freeplay depois na mesma sessão com poeira: os vistos valem para a sessão inteira.
	var l := Missao.new(1, {"livre": true, "sol_poeira": 2})
	l.montar_sol(2, bom)
	t.missao = l
	t._fase_logica = l.fase
	t._mostrar_fase("plano")
	_verdade(l.eh_poeira() and l.livre, "freeplay com poeira")
	_igual(_ordem_da_fila(t), ["aviso"] if l.aviso_ativo() else [], "o freeplay não repete o card da poeira")
	som.free()
	t.free()
	# No sol 3 de uma sessão nova o card do gerador não abre sem o gerador quebrado, e a poeira abre sozinha.
	var m2 := Missao.new(1)
	m2.montar_sol(3, bom)
	var t2: Control = Terminal.new()
	t2.som = Som.new()
	t2.iniciar(m2, {})
	_igual(_ordem_da_fila(t2), ["aviso", "poeira"] if m2.aviso_ativo() else ["poeira"], "sol 3 direto: a poeira")
	t2.som.free()
	t2.free()


## O sol que já começa em modo de segurança não monta plano: nenhum card abre por cima da tela de segurança,
## e o card fica para o plano seguinte que a criança vê (o reinício, ou o próximo sol em que o evento vale).
func _cards_com_o_sol_em_seguranca() -> void:
	# Poeira: o sol 3 começa em segurança (sem salvação).
	var m := Missao.new(1)
	m.montar_sol(3, _sem_salvacao())
	var t: Control = Terminal.new()
	t.som = Som.new()
	t.iniciar(m, {})
	_igual(m.fase, "seguranca", "poeira: o sol 3 começa em segurança")
	_igual(t.card_aberto, false, "poeira: nenhum card na tela de segurança")
	_igual(t._vistos.has("poeira"), false, "poeira: não conta como vista")
	_rodar(t, m, 0.5)
	_igual(t.card_aberto, false, "poeira: segue sem card na segurança")
	# Reiniciar o sol (o tem_conserto e o estado de partida são forçados: o jogo só dá conserto a um sol que
	# falhou no turno): o plano volta e o card abre ali.
	m.tem_conserto = true
	m.st_inicio = {"E": 10.0, "O": 10.0, "M": 12.0, "P": 1.0, "gerador_quebrado": false}
	t._acionar("reiniciar")
	_igual(m.fase, "plano", "poeira: o reinício volta ao plano")
	_rodar(t, m, QUADRO * 3.0)
	_igual(t.card_id, "poeira", "poeira: o card abre no plano do reinício")
	_igual(_ordem_da_fila(t), ["poeira"], "poeira: só ele")
	t.som.free()
	t.free()
	# Seguir em modo de segurança: o sol passa sem plano e o card abre no próximo plano em que a poeira vale (sol 4).
	var m2 := Missao.new(1)
	m2.montar_sol(3, _sem_salvacao())
	var t2: Control = Terminal.new()
	t2.som = Som.new()
	t2.iniciar(m2, {})
	_igual(m2.fase, "seguranca", "seguir: o sol 3 começa em segurança")
	t2._acionar("seguir")
	_igual(m2.fase, "fim_do_sol", "seguir: fim do sol")
	_rodar(t2, m2, t2.duracao * 1.5)
	_igual(t2.card_aberto, false, "seguir: sem card no fim do sol")
	_igual(t2._vistos.has("poeira"), false, "seguir: a poeira segue não vista")
	_ir_ao_sol(t2, m2, 4, {"E": 10.0, "O": 10.0, "M": 12.0, "P": 1.0, "gerador_quebrado": false})
	_verdade(m2.eh_poeira(), "sol 4: poeira")
	_igual(_ordem_da_fila(t2), ["poeira"], "seguir: o card da poeira abre no sol 4, o próximo plano visto")
	t2.som.free()
	t2.free()
	# Gerador: o sol 5 começa em segurança e é o último; seguir leva ao relatório e o card nunca abre.
	var m3 := Missao.new(1)
	m3.montar_sol(5, {"E": 4.0, "O": 5.0, "M": 0.0, "P": 1.0, "gerador_quebrado": true})
	var t3: Control = Terminal.new()
	t3.som = Som.new()
	t3.iniciar(m3, {})
	_igual(m3.fase, "seguranca", "gerador: o sol 5 começa em segurança")
	_igual(t3.card_aberto, false, "gerador: nenhum card na tela de segurança")
	t3._acionar("seguir")
	_rodar(t3, m3, t3.duracao * 1.5)
	t3._acionar("enviar")
	_igual(m3.fase, "relatorio", "gerador: depois do sol 5, o relatório")
	_rodar(t3, m3, t3.duracao * 1.5)
	_igual(t3.card_aberto, false, "gerador: o relatório não leva o card")
	_igual(t3._vistos.has("gerador"), false, "gerador: nunca abriu")
	t3.som.free()
	t3.free()


## Joga o turno até a missão sair dele (o terminal anda junto).
func _ate_sair_do_turno(t: Control, m: Missao) -> void:
	var guarda := 0
	while m.fase == "turno" and guarda < 4000:
		_rodar(t, m, 0.05)
		guarda += 1


func _desligar_no_meio_do_turno() -> void:
	# Margem 4 exposta ao pico: a margem ao vivo zera e o modo de segurança entra no meio do turno.
	var m := Missao.new(21, {"sol_solar": 3, "sol_poeira": 5, "sol_quebra": 2})
	m.montar_sol(3, {"E": 6.0, "O": 4.0, "M": 4.0, "P": 1.0, "gerador_quebrado": false})
	var som := Som.new()
	var t: Control = Terminal.new()
	t.som = som
	t.iniciar(m, {})
	_igual(_fechar_fila(t), 1, "o sol 3 abre só com o aviso da Terra")
	t._acionar("confirmar")
	_rodar(t, m, t.duracao * 1.5)
	som.historico.clear()
	_ate_sair_do_turno(t, m)
	_igual(m.fase, "seguranca", "entrou no modo de segurança no meio do turno")
	_igual(m.modos, 1, "uma entrada")
	_rodar(t, m, QUADRO * 3.0)
	_igual(som.historico, ["alarme", "desligar", "terminal_sobe"], "meio do turno: o alarme do pico, o desligar na hora e a subida")
	_igual(t._fade_estado, "", "sem escurecimento no meio do turno")
	_rodar(t, m, 2.0)
	_igual(som.historico, ["alarme", "desligar", "terminal_sobe"], "o desligar não repete enquanto fica no modo de segurança")
	som.free()
	t.free()


func _desligar_pelo_relogio() -> void:
	# O2 1 sem produzir: a falha vem no fim do turno, com o escurecimento.
	var m := Missao.new(1, {"sol_solar": 3, "turno_s": 4.0})
	m.montar_sol(1, {"E": 6.0, "O": 1.0, "M": 12.0, "P": 1.0, "gerador_quebrado": false})
	var som := Som.new()
	var t: Control = Terminal.new()
	t.som = som
	t.iniciar(m, {})
	_igual(_fechar_fila(t), 4, "o sol 1 abre com o aviso da Terra e os três cards do sol 1")
	t._acionar("confirmar")
	_rodar(t, m, t.duracao * 1.5)
	_igual(_fechar_fila(t), 1, "o primeiro turno abre o card do turno")
	som.historico.clear()
	_ate_sair_do_turno(t, m)
	_igual(m.fase, "seguranca", "entrou no modo de segurança no fim do turno")
	_rodar(t, m, QUADRO * 3.0)
	_igual(t._fade_estado, "escurecendo", "escurecendo")
	_igual(som.historico, ["desligar"], "relógio: o desligar toca no começo do escurecimento, sem subir ainda")
	_rodar(t, m, Terminal.ESCURECER_S + 0.05)
	_igual(som.historico, ["desligar", "terminal_sobe"], "depois do escurecimento, a subida")
	# Reiniciar o sol não conta como entrada; entrar de novo toca de novo.
	som.historico.clear()
	t._acionar("reiniciar")
	_igual(m.fase, "plano", "reiniciou")
	_rodar(t, m, QUADRO * 3.0)
	_igual(som.historico, ["clique_confirmar"], "reiniciar toca o clique e não o desligar")
	_igual(_fechar_fila(t), 1, "o plano reiniciado abre só com o aviso de novo (os do sol 1 não voltam)")
	t._acionar("confirmar")
	_rodar(t, m, t.duracao * 1.5)
	_igual(t.card_aberto, false, "o card do turno não volta no reinício do sol 1")
	som.historico.clear()
	_ate_sair_do_turno(t, m)
	_rodar(t, m, QUADRO * 3.0)
	_igual(m.modos, 2, "segunda entrada")
	_igual(som.historico, ["desligar"], "cada entrada toca o desligar uma vez")
	som.free()
	t.free()


## Um turno do sol 3 com a tempestade solar (o medidor sobe até o limiar de abrigo no pico), com o terminal
## já embaixo e o histórico de sons limpo. Devolve [terminal, missão, som].
func _turno_de_tempestade() -> Array:
	var m := Missao.new(21, {"sol_solar": 3, "sol_poeira": 5, "sol_quebra": 2})
	m.montar_sol(3, {"E": 12.0, "O": 12.0, "M": 12.0, "P": 1.0, "gerador_quebrado": false})
	var som := Som.new()
	var t: Control = Terminal.new()
	t.som = som
	t.iniciar(m, {})
	_igual(_fechar_fila(t), 1, "o sol 3 abre só com o aviso da Terra")
	t._acionar("confirmar")
	_rodar(t, m, t.duracao * 1.5)
	som.historico.clear()
	return [t, m, som]


## Roda o turno até o medidor passar do limiar de abrigo.
func _ate_o_alarme(t: Control, m: Missao) -> void:
	var guarda := 0
	while m.medidor() <= Missao.LIMIAR_ABRIGO and m.fase == "turno" and guarda < 4000:
		_rodar(t, m, 0.05)
		guarda += 1


func _alarme_uma_vez_por_travessia() -> void:
	var c := _turno_de_tempestade()
	var t: Control = c[0]
	var m: Missao = c[1]
	var som: Som = c[2]
	_rodar(t, m, 1.0)
	_igual(som.historico, [], "medidor baixo: sem alarme")
	_ate_o_alarme(t, m)
	_verdade(m.medidor() > Missao.LIMIAR_ABRIGO, "o medidor passou do limiar")
	_rodar(t, m, QUADRO * 2.0)
	_igual(som.historico, ["alarme"], "passou do limiar: o alarme toca")
	_rodar(t, m, 3.0)
	_igual(som.historico, ["alarme"], "acima do limiar o alarme não repete")
	# Voltar ao limiar ou abaixo rearma: a travessia seguinte toca de novo (o relógio é forçado).
	var t_depois := m.t
	m.t = m.t_pico - 1.0
	_rodar(t, m, QUADRO * 2.0)
	_igual(som.historico, ["alarme"], "abaixo do limiar não toca")
	m.t = t_depois
	_rodar(t, m, QUADRO * 2.0)
	_igual(som.historico, ["alarme", "alarme"], "outra travessia, outro alarme")
	# Abrigado, o medidor segue alto e nada toca.
	_verdade(m.abrigar(), "abrigou")
	_rodar(t, m, 1.0)
	_igual(som.historico, ["alarme", "alarme"], "abrigado: sem alarme")
	som.free()
	t.free()
	# Com o terminal aberto o alarme toca igual.
	c = _turno_de_tempestade()
	t = c[0]
	m = c[1]
	som = c[2]
	t._acionar("terminal")
	_rodar(t, m, t.duracao * 1.5)
	_igual(t.aberto, true, "terminal aberto")
	som.historico.clear()
	_ate_o_alarme(t, m)
	_rodar(t, m, QUADRO * 2.0)
	_igual(som.historico.count("alarme"), 1, "com o terminal aberto o alarme toca uma vez")
	som.free()
	t.free()


func _alerta_por_cima_do_terminal() -> void:
	var c := _turno_de_tempestade()
	var t: Control = c[0]
	var m: Missao = c[1]
	var som: Som = c[2]
	_igual(t.alerta_sobre_o_terminal(), false, "terminal embaixo, medidor baixo: sem alerta por cima")
	t._acionar("terminal")
	_rodar(t, m, t.duracao * 1.5)
	_igual(t.alerta_sobre_o_terminal(), false, "terminal aberto, medidor baixo: sem alerta")
	_ate_o_alarme(t, m)
	_igual(t.alerta_sobre_o_terminal(), true, "terminal aberto, medidor no abrigo: o alerta fica por cima")
	_igual(HudTurno.cor_do_alerta(m), Desenho.VERMELHO, "vermelho acima do limiar de abrigo")
	t._acionar("terminal")
	_verdade(t.alerta_sobre_o_terminal(), "descendo, o alerta segue por cima")
	_rodar(t, m, t.duracao * 1.5)
	_igual(t.alerta_sobre_o_terminal(), false, "embaixo o alerta é o do HUD do turno")
	_verdade(HudTurno.cor_do_alerta(m).a > 0.0, "e o HUD tem o alerta")
	t._acionar("terminal")
	_rodar(t, m, t.duracao * 1.5)
	m.abrigar()
	_igual(t.alerta_sobre_o_terminal(), false, "abrigado: sem alerta")
	# O alerta não cobre tecla nem botão do terminal.
	for r: Rect2 in t._retangulos_das_teclas():
		_verdade(not Terminal.ALERTA.intersects(r), "o alerta não cobre uma tecla")
	_verdade(not Terminal.ALERTA.intersects(Terminal.BOTAO), "o alerta não cobre o botão TERMINAL")
	_verdade(not Terminal.ALERTA.intersects(t._retangulo_da_tela()), "o alerta não cobre a tela do terminal")
	som.free()
	t.free()


func _linha_do_abrigo_fecha_o_terminal_e_pede_o_pan() -> void:
	var c := _turno_de_tempestade()
	var t: Control = c[0]
	var m: Missao = c[1]
	var som: Som = c[2]
	var pedidos := [0]
	t.pediu_abrigo.connect(func() -> void: pedidos[0] += 1)
	t._acionar("terminal")
	_rodar(t, m, t.duracao * 1.5)
	_ate_o_alarme(t, m)
	som.historico.clear()
	t._acionar("ir_ao_abrigo")
	_igual(t.aberto, false, "tocar a linha do abrigo fecha o terminal")
	_igual(pedidos[0], 1, "e pede o pan uma vez")
	_igual(m.abrigado, false, "a linha não abriga")
	_igual(som.historico, ["terminal_desce", "clique_navegar"], "som: a descida e o clique de navegar")
	_rodar(t, m, t.duracao * 1.5)
	_igual(m.abrigado, false, "terminal embaixo, ainda sem abrigar")
	# Abrigado, a linha é só informativa.
	m.abrigar()
	som.historico.clear()
	t._acionar("terminal")
	t._acionar("ir_ao_abrigo")
	_igual(pedidos[0], 1, "abrigado: a linha não pede o pan")
	_igual(som.historico, ["terminal_sobe"], "abrigado: a linha não faz clique")
	_igual(t.aberto, true, "abrigado: a linha não fecha o terminal")
	som.free()
	t.free()
	# Fora do turno a ação não vale.
	c = _montar()
	t = c[0]
	pedidos = [0]
	t.pediu_abrigo.connect(func() -> void: pedidos[0] += 1)
	t._acionar("ir_ao_abrigo")
	_igual(pedidos[0], 0, "no plano a ação não vale")
	c[2].free()
	t.free()


func _pan_ate_o_botao_do_abrigo() -> void:
	# O botão do abrigo (regioes.json) está em x 168..258, y 153..243 do panorama de 1280.
	var botao := Rect2(168, 153, 90, 90)
	var alcance := 640.0
	_igual(Main.pan_para_ver(botao, 640.0, alcance), 0.0, "o botão do abrigo pede o pan na ponta esquerda")
	_igual(Main.pan_para_ver(Rect2(900, 100, 100, 100), 640.0, alcance), 630.0, "um botão no meio: centrado")
	_igual(Main.pan_para_ver(Rect2(1200, 100, 80, 100), 640.0, alcance), 640.0, "preso ao alcance")
	# Do repouso (320) o pan chega ao alvo andando, sem salto seco, e não passa dele.
	var pan := 320.0
	var passos := 0
	while pan > 0.0 and passos < 100:
		pan = Main.passo_do_pan(pan, 0.0, Main.VELOCIDADE_VIRAR / 60.0)
		passos += 1
	_igual(pan, 0.0, "chegou ao alvo")
	_verdade(passos > 5 and passos < 60, "levou de 0,1 s a 1 s (%d quadros)" % passos)
	_igual(Main.passo_do_pan(3.0, 0.0, 17.0), 0.0, "não passa do alvo")


# --- a aba câmeras: o visor e as peças (ChemCam, gerador) ---------------------------------------------

## Um turno do sol 2 com o ChemCam escolhido e, se `quebrado`, o gerador na lista, o terminal no alto na aba
## câmeras e o relógio andando (cards fechados). Devolve [terminal, missão, som] com o histórico de sons limpo.
func _turno_nas_cameras(quebrado: bool, na_arvore: bool = false) -> Array:
	var m := Missao.new(1, {"sol_solar": 3, "sol_poeira": 5, "sol_quebra": 2})
	m.montar_sol(2, {"E": 12.0, "O": 12.0, "M": 12.0, "P": 1.0, "gerador_quebrado": quebrado})
	var som := Som.new()
	var t: Control = Terminal.new()
	t.som = som
	t.iniciar(m, {})
	_fechar_fila(t)
	m.alternar_tarefa("chemcam")
	t._acionar("confirmar")
	_rodar(t, m, t.duracao * 1.5)  # o terminal desce com o turno
	t._acionar("terminal")
	_rodar(t, m, t.duracao * 1.5)
	_igual(m.fase, "turno", "turno nas câmeras: no turno")
	_igual(t.posicao(), 1.0, "turno nas câmeras: o terminal no alto")
	if na_arvore:
		t.gravar_textos = true
		root.add_child(t)
	t._acionar("aba_cameras")
	_rodar(t, m, QUADRO * 2.0)
	som.historico.clear()
	return [t, m, som]


func _botoes_das_pecas_e_visor() -> void:
	var c := _turno_nas_cameras(true, true)
	var t: Control = c[0]
	var m: Missao = c[1]
	var som: Som = c[2]
	_igual(t.aba_na_tela(), "cameras", "a aba câmeras na tela")
	_verdade(t._visor.visible, "o visor aparece com a aba câmeras, o terminal no alto e sem card")
	_igual(t._visor.get_parent(), t, "o visor é filho do terminal")
	_igual(t._visor.get_global_rect(), Rect2(Terminal.X0, Terminal.Y_CORPO, Terminal.X1 - Terminal.X0, Terminal.Y_FIM - Terminal.Y_CORPO),
		"o visor cobre o corpo da aba")
	# O mapa entra em ui() como cam_<nome>, em px da tela, e não é botão do terminal.
	var ui: Dictionary = t.ui()
	for cam in ["painel", "rocha", "moxie", "visao_geral"]:
		_verdade(ui.has("cam_" + cam), "ui: cam_" + cam)
		var r: Array = ui["cam_" + cam]
		_verdade(Rect2(Terminal.X0, Terminal.Y_CORPO, Terminal.X1 - Terminal.X0, Terminal.Y_FIM - Terminal.Y_CORPO).encloses(Rect2(r[0], r[1], r[2], r[3])),
			"cam_%s fica dentro do corpo da aba" % cam)
		_verdade(r[2] >= 24 and r[3] >= 24, "cam_%s é um alvo de 24 px ou mais" % cam)
		_igual(t._botoes.has("cam_" + cam), false, "cam_%s não é botão do terminal" % cam)
	_igual(t.minigame(), {}, "sem peça à vista, nada para a sonda")
	# Sol, clima e pendências chegam ao visor: ChemCam rodando e gerador pendente.
	_igual(t._visor_pend, {"rocha": true, "moxie": true}, "pendências: as duas câmeras com tarefa")
	# Escondido com o terminal animando.
	t._acionar("terminal")
	_rodar(t, m, QUADRO * 3.0)
	_verdade(t.animando(), "o terminal desce")
	_igual(t._visor.visible, false, "o visor some com o terminal em movimento")
	_igual(t.ui().keys().filter(func(k): return k.begins_with("cam_")), [], "e os cam_ saem de ui()")
	_rodar(t, m, t.duracao * 1.5)
	t._acionar("terminal")
	_rodar(t, m, QUADRO * 3.0)
	_igual(t._visor.visible, false, "subindo: ainda escondido")
	_rodar(t, m, t.duracao * 1.5)
	_igual(t._visor.visible, true, "parado no alto: o visor volta")
	# Escondido com card (o aviso reaberto por cima da tela do plano) e de outra aba.
	t.card_id = "aviso"
	t._fase_tela = "plano"
	_rodar(t, m, QUADRO * 2.0)
	_igual(t._visor.visible, false, "o visor some com o card à vista")
	t.card_id = ""
	t._fase_tela = "turno"
	_rodar(t, m, QUADRO * 2.0)
	_igual(t._visor.visible, true, "sem card, volta")
	t._acionar("aba_tarefas")
	_rodar(t, m, QUADRO * 2.0)
	_igual(t._visor.visible, false, "o visor só aparece na aba câmeras")
	await process_frame
	await process_frame
	# Os botões novos da aba tarefas (no lugar de iniciar_chemcam e consertar_gerador).
	var ui2: Dictionary = t.ui()
	_verdade(ui2.has("ir_chemcam"), "tarefas: ir_chemcam")
	_verdade(ui2.has("ir_gerador"), "tarefas: ir_gerador, com as duas pendentes e nada rodando")
	_igual(ui2.has("iniciar_chemcam") or ui2.has("consertar_gerador"), false, "os botões provisórios saíram")
	var rb: Array = ui2["ir_chemcam"]
	_igual(rb[2], 122, "ir_chemcam: mesma largura")
	_igual(rb[3], 30, "ir_chemcam: mesma altura")
	_verdade(rb[2] >= 24 and rb[3] >= 24, "ir_chemcam: alvo de 24 px ou mais")
	var tem_rotulo := false
	for linha in t.textos():
		if linha[0] == t.tr("ABA_CAMERAS") and linha[3] == 12:
			tem_rotulo = true
	_verdade(tem_rotulo, "ir_chemcam: o rótulo é Câmeras")
	# Com o ChemCam rodando, o do gerador fica apagado (uma tarefa por vez) e o do ChemCam segue valendo.
	t._acionar("ir_chemcam")
	_igual(t.aba, "cameras", "ir_chemcam abre a aba câmeras")
	_igual(t._visor.camera_atual(), "rocha", "na câmera da rocha")
	_igual(m.tarefas["chemcam"], "rodando", "e a tarefa começou")
	t._acionar("aba_tarefas")
	await process_frame
	await process_frame
	_verdade(t.ui().has("ir_chemcam"), "tarefa rodando: ir_chemcam vale")
	_igual(t.ui().has("ir_gerador"), false, "ChemCam rodando: ir_gerador apagado")
	_igual(t._acionar("ir_gerador"), null, "e a ação não faz nada")
	_igual(m.tarefas["gerador"], "pendente", "o gerador segue pendente")
	root.remove_child(t)
	som.free()
	t.free()


func _pecas_nas_cameras() -> void:
	var c := _turno_nas_cameras(true)
	var t: Control = c[0]
	var m: Missao = c[1]
	var som: Som = c[2]
	var visor = t._visor
	# Nada roda no turno recém-aberto: a criança é quem escolhe a câmera.
	_igual(m.tarefas, {"chemcam": "pendente", "gerador": "pendente"}, "turno: as duas tarefas pendentes")
	som.historico.clear()
	_igual(visor.peca("rocha"), null, "sem peça antes de escolher a câmera")
	# Escolher a câmera da rocha (tarefa pendente, nada rodando) inicia o ChemCam e hospeda a peça.
	visor.escolher("rocha")
	_igual(m.tarefas["chemcam"], "rodando", "escolher a rocha inicia o ChemCam")
	_igual(m.tarefa_rodando, "chemcam", "ele é a tarefa que roda")
	var peca = visor.peca("rocha")
	_verdade(peca != null, "a peça do ChemCam foi hospedada na rocha")
	_verdade(peca.get_script() == Terminal.Chemcam, "e é o minigame do ChemCam")
	_igual(som.historico, ["clique_confirmar"], "começar pela câmera toca o clique de iniciar_chemcam")
	_rodar(t, m, QUADRO * 2.0)
	_verdade(peca.visible, "a peça aparece (a câmera da rocha está escolhida)")
	var mg: Dictionary = t.minigame()
	_igual(mg["tipo"], "chemcam", "a sonda vê o ChemCam")
	_igual(mg["alvos"].size(), 4, "quatro alvos pendentes")
	var visor_r: Rect2 = visor.get_global_rect()
	for a in mg["alvos"]:
		_verdade(visor_r.has_point(Vector2(a[0], a[1])), "o alvo %s está na área do visor, em px da tela" % str(a))
	# Escolher de novo a câmera de uma tarefa que roda só mostra: a mesma peça, sem recriar.
	visor.escolher("visao_geral")
	_igual(peca.visible, false, "outra câmera: a peça se esconde")
	visor.escolher("rocha")
	_verdade(visor.peca("rocha") == peca, "voltar à rocha mostra a mesma peça (não recria)")
	_verdade(peca.visible, "e ela aparece")
	_igual(som.historico, ["clique_confirmar"], "voltar não toca o som de iniciar de novo")
	# Com o ChemCam rodando, o MOXIE (pendente) não começa: uma tarefa por vez.
	visor.escolher("moxie")
	_igual(m.tarefas["gerador"], "pendente", "o gerador não começa com o ChemCam rodando")
	_igual(visor.peca("moxie"), null, "e a câmera do MOXIE fica sem peça")
	# A barra da linha mostra a peça, não o relógio.
	t._acionar("aba_tarefas")
	m.avancar(5.0)  # o relógio anda; a peça não
	_rodar(t, m, QUADRO * 2.0)
	_igual(t._progresso_da_linha("chemcam"), peca.progresso(), "a barra é a da peça")
	_igual(t._progresso_da_linha("chemcam"), 0.0, "a peça parada: 0 mesmo com o relógio andando")
	_verdade(m.progresso_tarefa("chemcam") > 0.4, "enquanto o relógio da missão já andou")
	peca.tocar(peca.alvos_na_area()[0])
	peca.avancar(0.3)
	_verdade(peca.progresso() > 0.0, "a peça andou")
	_igual(t._progresso_da_linha("chemcam"), peca.progresso(), "a barra acompanha a peça")
	_igual(t._progresso_da_linha("amostra"), 0.0, "sem peça hospedada: 0, não o relógio")
	# A peça conclui: a tarefa fica feita e a peça sai no quadro seguinte.
	peca.concluido.emit()
	_igual(m.tarefas["chemcam"], "feita", "concluido da peça marca a tarefa feita")
	_igual(m.tarefa_rodando, "", "nada roda")
	_igual(m.ciencia_do_sol(), 1, "o ChemCam rende ciência")
	_rodar(t, m, QUADRO * 2.0)
	_igual(visor.peca("rocha"), null, "a peça sai quando a tarefa deixa de rodar")
	_igual(t._visor_pend, {"rocha": false, "moxie": true}, "a rocha deixa de ser pendência")
	# Agora o gerador: escolher o MOXIE o inicia, com a semente sol*100 + modos.
	t._acionar("aba_cameras")
	som.historico.clear()
	visor.escolher("moxie")
	_igual(m.tarefas["gerador"], "rodando", "escolher o MOXIE inicia o conserto")
	var g = visor.peca("moxie")
	_verdade(g != null and g.get_script() == ConsertarGerador, "a peça do gerador foi hospedada no MOXIE")
	_igual(g.sorteio_atual(), ConsertarGerador.sorteio(m.sol * 100 + m.modos), "semente = sol * 100 + modos")
	_igual(m.sol * 100 + m.modos, 200, "no sol 2 sem modos: 200")
	_igual(som.historico, ["clique_confirmar"], "o conserto também toca o clique de começar")
	_rodar(t, m, QUADRO * 2.0)
	var mg2: Dictionary = t.minigame()
	_igual(mg2["tipo"], "gerador", "a sonda vê o gerador")
	_igual(mg2["pecas"].size(), 3, "três peças na bandeja")
	_igual(mg2["certa"], g.sorteio_atual()["certa"], "a sonda diz qual é a certa")
	_verdade(visor_r.has_point(Vector2(mg2["encaixe"][0], mg2["encaixe"][1])), "o encaixe está na área do visor")
	for r in mg2["pecas"]:
		_verdade(r[2] >= 24 and r[3] >= 24, "a peça da bandeja é um alvo de 24 px ou mais")
	# A semente muda com os modos de segurança: outro modo, outro sorteio.
	_igual(ConsertarGerador.sorteio(200) == ConsertarGerador.sorteio(201), false, "outro número, outro sorteio")
	som.free()
	t.free()


## A peça sai quando a tarefa deixa de rodar por outro motivo (abrigo, fim do turno, reinício), e o
## semente leva os modos de segurança.
func _peca_conclui_abrigo_e_reinicio() -> void:
	# Abrigar tira a peça e a tarefa volta a pendente (cancelada).
	var c := _turno_nas_cameras(false)
	var t: Control = c[0]
	var m: Missao = c[1]
	var som: Som = c[2]
	t._visor.escolher("rocha")
	_verdade(t._visor.peca("rocha") != null, "abrigo: o ChemCam tem peça")
	m.abrigar()
	_rodar(t, m, QUADRO * 2.0)
	_igual(t._visor.peca("rocha"), null, "abrigar tira a peça")
	_igual(m.tarefas["chemcam"], "pendente", "a tarefa volta a pendente")
	_igual(t._visor_pend, {"rocha": false, "moxie": false}, "abrigado: nenhuma pendência no mapa")
	t._visor.escolher("rocha")
	_igual(t._visor.peca("rocha"), null, "abrigado: escolher a câmera não inicia nem hospeda")
	_igual(m.tarefas["chemcam"], "pendente", "abrigado: a tarefa segue pendente")
	som.free()
	t.free()
	# O fim do turno tira a peça.
	c = _turno_nas_cameras(false)
	t = c[0]
	m = c[1]
	som = c[2]
	t._visor.escolher("rocha")
	_verdade(t._visor.peca("rocha") != null, "fim do turno: o ChemCam tem peça")
	m.avancar(m.turno_s)
	_igual(m.fase, "fim_do_sol", "o turno acabou")
	t._process(QUADRO)
	_igual(t._visor.peca("rocha"), null, "o fim do turno tira a peça")
	_igual(t._visor_pend, {"rocha": false, "moxie": false}, "fora do turno: sem pendência")
	som.free()
	t.free()
	# O modo de segurança (a peça não concluiu e o oxigênio acaba) e o reinício do sol tiram a peça.
	var ms := Missao.new(1, {"sol_solar": 3, "sol_poeira": 5, "sol_quebra": 2})
	ms.montar_sol(2, {"E": 6.0, "O": 0.0, "M": 12.0, "P": 1.0, "gerador_quebrado": true})
	var som_s := Som.new()
	var ts: Control = Terminal.new()
	ts.som = som_s
	ts.iniciar(ms, {})
	_fechar_fila(ts)
	ts._acionar("confirmar")
	_rodar(ts, ms, ts.duracao * 1.5)
	ts._acionar("terminal")
	_rodar(ts, ms, ts.duracao * 1.5)
	ts._acionar("aba_cameras")
	_rodar(ts, ms, QUADRO * 2.0)
	ts._visor.escolher("moxie")
	_verdade(ts._visor.peca("moxie") != null, "segurança: o gerador tem peça")
	ms.avancar(ms.turno_s)
	_igual(ms.fase, "seguranca", "o conserto não concluído e sem O2: modo de segurança")
	ts._process(QUADRO)
	_igual(ts._visor.peca("moxie"), null, "o modo de segurança tira a peça")
	_verdade(ms.reiniciar_sol(), "o simulador reinicia o sol")
	_rodar(ts, ms, QUADRO * 3.0)
	_igual(ts._visor.peca("moxie"), null, "no sol reiniciado não há peça")
	_igual(ts._visor_pend, {"rocha": false, "moxie": false}, "no plano reiniciado, sem pendência no mapa")
	som_s.free()
	ts.free()
	# Semente com modos: monta um sol 2 com a missão já com 3 modos de segurança.
	var m2 := Missao.new(1, {"sol_solar": 3, "sol_poeira": 5, "sol_quebra": 2})
	m2.montar_sol(2, {"E": 12.0, "O": 12.0, "M": 12.0, "P": 1.0, "gerador_quebrado": true})
	m2.modos = 3
	var som2 := Som.new()
	var t2: Control = Terminal.new()
	t2.som = som2
	t2.iniciar(m2, {})
	_fechar_fila(t2)
	t2._acionar("confirmar")
	_rodar(t2, m2, t2.duracao * 1.5)
	t2._acionar("terminal")
	_rodar(t2, m2, t2.duracao * 1.5)
	t2._acionar("aba_cameras")
	_rodar(t2, m2, QUADRO * 2.0)
	t2._visor.escolher("moxie")
	var g = t2._visor.peca("moxie")
	_verdade(g != null, "semente com modos: o gerador tem peça")
	_igual(g.sorteio_atual(), ConsertarGerador.sorteio(2 * 100 + 3), "semente = sol * 100 + modos, com 3 modos")
	# Reiniciar o sol (volta ao plano do mesmo sol): a peça sai.
	m2.avancar(m2.turno_s)
	t2._process(QUADRO)
	_igual(t2._visor.peca("moxie"), null, "depois do turno a peça do gerador saiu")
	# A peça do gerador conclui pelo concluido e a tarefa vira feita.
	var m3 := Missao.new(1, {"sol_solar": 3, "sol_poeira": 5, "sol_quebra": 2})
	m3.montar_sol(2, {"E": 12.0, "O": 12.0, "M": 12.0, "P": 1.0, "gerador_quebrado": true})
	var t3: Control = Terminal.new()
	t3.iniciar(m3, {})
	_fechar_fila(t3)
	t3._acionar("confirmar")
	_rodar(t3, m3, t3.duracao * 1.5)
	t3._acionar("terminal")
	_rodar(t3, m3, t3.duracao * 1.5)
	t3._acionar("aba_cameras")
	_rodar(t3, m3, QUADRO * 2.0)
	t3._acionar("aba_tarefas")
	_verdade(t3._pode_ir_a_camera("gerador"), "tarefas: ir_gerador habilitado com o gerador pendente")
	t3._acionar("ir_gerador")
	_igual(t3.aba, "cameras", "ir_gerador abre a aba câmeras")
	_igual(t3._visor.camera_atual(), "moxie", "na câmera do MOXIE")
	_igual(m3.tarefas["gerador"], "rodando", "e o conserto começou")
	var g3 = t3._visor.peca("moxie")
	g3.concluido.emit()
	_igual(m3.tarefas["gerador"], "feita", "o concluido do gerador marca a tarefa feita")
	_igual(m3.gerador_quebrado_agora(), false, "o gerador está consertado")
	_rodar(t3, m3, QUADRO * 2.0)
	_igual(t3._visor.peca("moxie"), null, "a peça do gerador sai")
	m3.avancar(m3.turno_s)
	_igual(m3.registros[0]["o2_produzido"] > 0 or m3.registros[0]["consertou"], true, "o conserto vale no fim do sol")
	t3.free()
	t2.free()
	som2.free()


## Com a peça à vista, o clique no visor chega ao `_gui_input` do visor e da peça (pelo viewport de verdade),
## e o arrasto do gerador (pressionar, mover com o botão, soltar) chega inteiro.
func _cliques_chegam_ao_visor_e_a_peca() -> void:
	var c := _turno_nas_cameras(true, true)
	var t: Control = c[0]
	var m: Missao = c[1]
	var som: Som = c[2]
	await process_frame
	await process_frame
	# Fora do visor o terminal ainda consome o clique (a sala não o recebe).
	root.push_input(_mouse(Vector2(5, 5), true), true)
	_verdade(root.is_input_handled(), "fora do visor o terminal consome o clique")
	root.push_input(_mouse(Vector2(5, 5), false), true)
	# Dentro do visor, no botão da câmera do MOXIE: o visor recebe e a câmera muda.
	var ui: Dictionary = t.ui()
	var cam: Array = ui["cam_moxie"]
	var ctr := Vector2(cam[0] + cam[2] / 2.0, cam[1] + cam[3] / 2.0)
	_igual(t._visor.camera_atual(), "visao_geral", "a câmera começa na visão geral")
	root.push_input(_mouse(ctr, true), true)
	_igual(t._visor.camera_atual(), "moxie", "o clique no mapa chega ao visor (o terminal não o consome)")
	root.push_input(_mouse(ctr, false), true)
	_igual(m.tarefas.get("gerador", ""), "rodando", "e a câmera do MOXIE inicia o conserto")
	await process_frame
	var mg: Dictionary = t.minigame()
	_igual(mg.get("tipo", ""), "gerador", "o gerador está à vista")
	var g = t._visor.peca("moxie")
	# Arrasto: a peça certa, do centro da bandeja ao centro do encaixe, com o botão apertado nos movimentos.
	var r: Array = mg["pecas"][mg["certa"]]
	var de := Vector2(r[0] + r[2] / 2.0, r[1] + r[3] / 2.0)
	var para := Vector2(mg["encaixe"][0], mg["encaixe"][1])
	root.push_input(_mouse(de, true), true)
	_verdade(root.is_input_handled(), "o toque na peça é tratado")
	var passos := 6
	for i in range(1, passos + 1):
		root.push_input(_movimento(de.lerp(para, float(i) / passos), true), true)
	_verdade(g.posicao_da_peca(mg["certa"]).distance_to(para - g.global_position) < 2.0, "a peça seguiu o arrasto até o encaixe")
	root.push_input(_mouse(para, false), true)
	_verdade(g.ocupada(), "soltar no encaixe a põe em voo")
	g.avancar(5.0)
	_verdade(g.concluida(), "o arrasto inteiro conclui o conserto")
	_igual(m.tarefas["gerador"], "feita", "e a tarefa do gerador fica feita pelo concluido")
	_igual(m.gerador_quebrado_agora(), false, "o gerador está consertado")
	# O ChemCam: o clique no alvo, dentro da vista, dispara.
	t._visor.escolher("rocha")
	_igual(m.tarefas["chemcam"], "rodando", "a câmera da rocha inicia o ChemCam")
	await process_frame
	var mc: Dictionary = t.minigame()
	_igual(mc.get("tipo", ""), "chemcam", "o ChemCam está à vista")
	var a: Array = mc["alvos"][0]
	root.push_input(_mouse(Vector2(a[0], a[1]), true), true)
	_verdade(root.is_input_handled(), "o toque no alvo é tratado")
	root.push_input(_mouse(Vector2(a[0], a[1]), false), true)
	_igual(t._visor.peca("rocha").estado_alvo(0) != "pendente" or t._visor.peca("rocha").estado_alvo(1) != "pendente"
		or t._visor.peca("rocha").estado_alvo(2) != "pendente" or t._visor.peca("rocha").estado_alvo(3) != "pendente", true,
		"o alvo tocado dispara")
	_igual(t.minigame()["alvos"].size(), 3, "um alvo a menos pendente")
	root.remove_child(t)
	som.free()
	t.free()


func _mouse(pos: Vector2, apertado: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = apertado
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if apertado else 0
	return e


func _movimento(pos: Vector2, apertado: bool) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if apertado else 0
	return e



## Estado de bateria e oxigênio sem salvação no sol de poeira (o plano de emergência falha).
func _sem_salvacao(e: float = 2.0) -> Dictionary:
	return {"E": e, "O": 0.0, "M": 12.0, "P": 1.0, "gerador_quebrado": false}


## A tela do modo de segurança que nasce da noite (e de "seguir" de um sol anterior): sem travar, sem
## o card do aviso por cima, e o desligar toca uma vez por entrada.
func _da_noite_para_a_seguranca() -> void:
	# Sol 3 já perdido (O2 0, poeira): a tela abre no sol 3; o terminal já a vê como entrada de partida.
	var m := Missao.new(1)
	m.montar_sol(3, _sem_salvacao())
	var som := Som.new()
	var t: Control = Terminal.new()
	t.som = som
	t.iniciar(m, {})
	_igual(m.fase, "seguranca", "noite: o sol 3 abre em segurança")
	_igual(t.fase_ui, "seguranca", "noite: o terminal mostra a segurança")
	_igual(t.card_aberto, false, "noite: sem card do aviso")
	_rodar(t, m, 0.5)
	_igual(som.historico, [], "a partida já em segurança não toca o desligar")
	# Seguir, enviar à Terra: fim do sol e noite; da noite, o sol 4 abre direto na segurança.
	t._acionar("seguir")
	_igual(m.fase, "fim_do_sol", "seguir: fim do sol")
	_rodar(t, m, t.duracao * 1.5)
	_igual(t.fase_ui, "fim_do_sol", "seguir: o terminal mostra o fim do sol")
	t._acionar("enviar")
	_igual(m.fase, "noite", "enviar: a noite")
	_rodar(t, m, 0.1)
	_igual(t.fase_ui, "noite", "a noite aparece")
	_igual(t.aberto, true, "a noite fica com o terminal aberto")
	som.historico.clear()
	_rodar(t, m, Missao.NOITE_S + 0.2)
	_igual(m.sol, 4, "a noite passou para o sol 4")
	_igual(m.fase, "seguranca", "o sol 4 abre em segurança (nenhum plano salva)")
	_igual(m.modos, 2, "duas entradas")
	_igual(t.fase_ui, "seguranca", "noite para segurança: o terminal mostra a tela")
	_igual(t._fase_tela, "seguranca", "noite para segurança: a tela já é a da segurança")
	_igual(t.aberto, true, "noite para segurança: o terminal fica aberto")
	_igual(t.card_aberto, false, "noite para segurança: sem card do aviso por cima")
	_igual(t._fade_estado, "", "noite para segurança: sem escurecimento")
	_igual(som.historico.count("desligar"), 1, "noite para segurança: o desligar toca uma vez")
	_igual(som.historico.count("terminal_desce"), 0, "noite para segurança: o terminal não desce")
	_rodar(t, m, 2.0)
	_igual(som.historico.count("desligar"), 1, "noite para segurança: o desligar não repete")
	_igual(m.reiniciar_sol(), false, "noite para segurança: sem reinício possível")
	t._acionar("reiniciar")
	_igual(m.fase, "seguranca", "noite para segurança: o botão de reiniciar não faz nada")
	# E ainda sai: seguir leva ao fim do sol de novo.
	t._acionar("seguir")
	_igual(m.fase, "fim_do_sol", "a segurança do sol 4 também segue")
	som.free()
	t.free()


## Cada card do sol 1 é desenhado ao lado do controle que nomeia, sem cobri-lo: o "Fechar" dele (que está
## dentro do card) fica na outra coluna, e só ele se clica. Nos dois idiomas.
func _cards_ao_lado_do_controle() -> void:
	var idioma := TranslationServer.get_locale()
	var alvos := {"sol1_o2": "o2", "sol1_ciencia": "ciencia", "sol1_confirmar": "confirmar"}
	for loc in ["en", "pt"]:
		TranslationServer.set_locale(loc)
		var m := Missao.new(1)
		var t: Control = Terminal.new()
		t.gravar_textos = true
		t.iniciar(m, {})
		root.add_child(t)
		await process_frame
		await process_frame
		_igual(t.card_id, "aviso", "%s: o aviso abre primeiro" % loc)
		_igual(t.ui().keys(), ["fechar_card"], "%s: com o aviso, só o Fechar se clica" % loc)
		t._acionar("fechar_card")
		for id: String in ["sol1_o2", "sol1_ciencia", "sol1_confirmar"]:
			await process_frame
			await process_frame
			_igual(t.card_id, id, "%s: o card %s abre na ordem" % [loc, id])
			var alvo: Rect2 = t._alvos[alvos[id]]
			_verdade(alvo.size.x >= 24.0 and alvo.size.y >= 24.0, "%s: o controle %s foi registrado" % [loc, alvos[id]])
			_igual(t.ui().keys(), ["fechar_card"], "%s: card %s: só o Fechar se clica" % [loc, id])
			var fechar := Rect2(t.ui()["fechar_card"][0], t.ui()["fechar_card"][1], t.ui()["fechar_card"][2], t.ui()["fechar_card"][3])
			_verdade(not fechar.intersects(alvo), "%s: o card %s não cobre o controle (Fechar %s, controle %s)" % [loc, id, str(fechar), str(alvo)])
			_verdade(fechar.size.x >= 24.0 and fechar.size.y >= 24.0, "%s: o Fechar é um alvo de 24x24 ou mais" % loc)
			# O card tem o texto do idioma, uma frase por linha, e cabe na tela do terminal.
			var tem_texto := false
			for linha in t.textos():
				if t.tr(Terminal.CARD_TEXTO[id]).begins_with(linha[0]) and linha[0] != "":
					tem_texto = true
			_verdade(tem_texto, "%s: o card %s desenha o texto" % [loc, id])
			_verdade(Rect2(0, 0, 640, 360).encloses(fechar), "%s: o card %s cabe na tela" % [loc, id])
			t._acionar("fechar_card")
		_igual(t.card_id, "", "%s: a fila acabou" % loc)
		root.remove_child(t)
		t.free()
	TranslationServer.set_locale(idioma)


## O retângulo que um texto recortado por textos() ocupa: [texto, x, y, tam, largura, alinhamento, negrito].
func _rect_do_texto(l: Array) -> Rect2:
	var tam: int = l[3]
	var larg: float = l[4]
	var negrito: bool = l[6]
	var f: Font = l[7] if l[7] != null else (Desenho.fonte_negrito() if negrito else Desenho.fonte())
	var w := f.get_multiline_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, larg, tam).x
	var h := f.get_multiline_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, larg, tam).y
	var x: float = l[1]
	if larg > 0.0 and l[5] == HORIZONTAL_ALIGNMENT_RIGHT:
		x += larg - w
	elif larg > 0.0 and l[5] == HORIZONTAL_ALIGNMENT_CENTER:
		x += (larg - w) / 2.0
	return Rect2(x, l[2], w, h)


## Um retângulo por linha de um texto que quebra (a última linha costuma ser mais curta: a fonte de um fato da aba
## fontes vai ao lado dela).
func _rects_das_linhas(l: Array) -> Array:
	var tam: int = l[3]
	var f: Font = l[7] if l[7] != null else (Desenho.fonte_negrito() if l[6] else Desenho.fonte())
	var par := TextParagraph.new()
	par.add_string(l[0], f, tam)
	par.width = l[4]
	var lista: Array = []
	var altura := f.get_height(tam)
	for i in par.get_line_count():
		lista.append(Rect2(l[1], l[2] + i * altura, par.get_line_width(i), altura))
	return lista


## O card do aviso: as três partes (o aviso, a frase do histórico e, com o dado do build, a frase do dado de
## hoje) e o rodapé não se sobrepõem nem pisam no "Fechar", e o card inteiro cabe na tela do terminal, nos
## dois idiomas, com o dado atual e só com o histórico.
func _card_do_aviso_cabe() -> void:
	var idioma := TranslationServer.get_locale()
	var real := DadosDonki.carregar()
	_verdade(not real["historico"], "o dado do build existe (a frase do dado de hoje depende dele)")
	for loc in ["en", "pt"]:
		TranslationServer.set_locale(loc)
		for historico in [true, false]:
			var dado := real.duplicate()
			dado["historico"] = historico
			var rotulo := "%s, %s" % [loc, "histórico" if historico else "atual"]
			var m := Missao.new(1)
			var t: Control = Terminal.new()
			t.gravar_textos = true
			t.iniciar(m, dado)
			root.add_child(t)
			await process_frame
			await process_frame
			_igual(t.card_id, "aviso", "%s: o aviso abre" % rotulo)
			var f_atual: String = t._frase_donki_atual()
			_igual(f_atual == "", historico, "%s: a frase do dado de hoje só existe com o dado do build" % rotulo)
			var partes := {"aviso": t.tr("AVISO_TEMPESTADE"), "hist": t.tr("DONKI_FRASE_HISTORICO")}
			if not historico:
				partes["atual"] = f_atual
			var rects := {}
			var rodape := Rect2()
			var tem_rodape := false
			for linha in t.textos():
				for k: String in partes:
					if linha[0] == partes[k]:
						rects[k] = _rect_do_texto(linha)
				if linha[0].begins_with(t.tr("ENVIADO_DA_TERRA").substr(0, 8)):
					rodape = _rect_do_texto(linha)
					tem_rodape = true
				_verdade(not linha[0].begins_with("DONKI_"), "%s: nenhuma chave sem tradução na tela (%s)" % [rotulo, linha[0]])
				_verdade(linha[0] != t.tr("DONKI_DADO_HISTORICO") and linha[0] != t.tr("DONKI_DADO_DE") % ("14 November 2026" if loc == "en" else "14/11/2026"),
					"%s: a segunda linha do rodapé saiu" % rotulo)
			_igual(rects.size(), partes.size(), "%s: as partes do card foram desenhadas" % rotulo)
			_verdade(tem_rodape, "%s: o rodapé foi desenhado" % rotulo)
			var fechar_a: Array = t.ui().get("fechar_card", [])
			_verdade(not fechar_a.is_empty(), "%s: o Fechar está na tela" % rotulo)
			if rects.size() != partes.size() or not tem_rodape or fechar_a.is_empty():
				root.remove_child(t)
				t.free()
				continue
			var fechar := Rect2(fechar_a[0], fechar_a[1], fechar_a[2], fechar_a[3])
			var ordem := ["aviso", "hist"] + (["atual"] if not historico else [])
			for i in ordem.size():
				var r: Rect2 = rects[ordem[i]]
				for j in range(i + 1, ordem.size()):
					_verdade(not r.intersects(rects[ordem[j]]), "%s: %s e %s não se sobrepõem" % [rotulo, ordem[i], ordem[j]])
				_verdade(not r.intersects(rodape), "%s: %s não pisa no rodapé" % [rotulo, ordem[i]])
				_verdade(not r.intersects(fechar), "%s: %s não pisa no Fechar (%s, %s)" % [rotulo, ordem[i], str(r), str(fechar)])
				_verdade(r.end.y + 8.0 <= fechar.position.y, "%s: %s acaba 8 px ou mais acima do Fechar" % [rotulo, ordem[i]])
			_verdade(not rodape.intersects(fechar), "%s: o rodapé não pisa no Fechar" % rotulo)
			# O card: do 12 acima do aviso até 12 abaixo do Fechar; dentro do corpo do terminal (42 a 314).
			var topo: float = rects["aviso"].position.y - 12.0
			var base := fechar.end.y + 12.0
			_verdade(topo >= Terminal.Y_CORPO, "%s: o card começa dentro do corpo (topo %d)" % [rotulo, topo])
			_verdade(base <= Terminal.Y_FIM, "%s: o card cabe na tela do terminal (base %d)" % [rotulo, base])
			if not historico:
				# Tudo derivado do dado do build, que o publicar.sh recoleta.
				_verdade(f_atual.contains(str(real["chegadas_marte"].size())), "%s: a frase traz quantas chegadas há na janela" % rotulo)
				_verdade(f_atual.contains(DadosDonki.data_texto(str(real["coletado_em"]), loc)), "%s: a data da coleta, no formato do idioma" % rotulo)
				_verdade(f_atual.contains(" km/s"), "%s: a frase traz a velocidade" % rotulo)
			root.remove_child(t)
			t.free()
	TranslationServer.set_locale(idioma)


## A aba fontes (o par do histórico, os números do jogo e os créditos por último) cabe na caixa da direita, sem
## sobreposição e sem rolagem, nos dois idiomas, com e sem o dado do build. O dado do build não aparece nela (é o
## card do aviso que o mostra).
func _aba_fontes_cabe() -> void:
	var idioma := TranslationServer.get_locale()
	var real := DadosDonki.carregar()
	for loc in ["en", "pt"]:
		TranslationServer.set_locale(loc)
		for historico in [true, false]:
			var dado := real.duplicate()
			dado["historico"] = historico
			var rotulo := "fontes, %s, %s" % [loc, "histórico" if historico else "atual"]
			var m := Missao.new(1)
			var t: Control = Terminal.new()
			t.gravar_textos = true
			t.iniciar(m, dado)
			_fechar_fila(t)
			t._acionar("aba_fontes")
			root.add_child(t)
			await process_frame
			await process_frame
			_igual(t.aba_na_tela(), "fontes", "%s: a aba abre" % rotulo)
			var caixa := Rect2(Terminal.X0 + 186.0, Terminal.Y_CORPO, Terminal.X1 - Terminal.X0 - 186.0, Terminal.Y_FIM - Terminal.Y_CORPO)
			var rects: Array = []
			var tem_hist := false
			var tem_atual := false
			var tam_fato := 0
			var fim := 0.0
			var fim_creditos := 0.0
			var y_mais_baixo := -1.0
			var texto_mais_baixo := ""
			var antes: Array = t.textos()
			for linha in t.textos():
				var r := _rect_do_texto(linha)
				if r.position.x < caixa.position.x or r.position.y < Terminal.Y_CORPO or linha[0] == t.tr("TERMINAL"):
					continue
				if linha[0] == t.tr("FONTE_DONKI_HIST_FATO"):
					tem_hist = true
					tam_fato = linha[3]
				if linha[0] == t._frase_donki_atual() and linha[0] != "":
					tem_atual = true
				if linha[2] > y_mais_baixo:
					y_mais_baixo = linha[2]
					texto_mais_baixo = linha[0]
				if linha[0] == t.tr("CREDITOS") or linha[0] == t.tr("CREDITOS_README"):
					fim_creditos = maxf(fim_creditos, r.end.y)
				rects.append_array(_rects_das_linhas(linha))
				fim = maxf(fim, r.end.y)
				_verdade(caixa.encloses(r), "%s: cabe na caixa (%s em %s)" % [rotulo, linha[0].substr(0, 20), str(r)])
			_verdade(tem_hist, "%s: o par do histórico de maio de 2024 está sempre" % rotulo)
			_verdade(not tem_atual, "%s: o par do dado de hoje não aparece na aba" % rotulo)
			_verdade(not t._pares_fontes().any(func(par): return par[1] == "NASA DONKI (CCMC), WSA-ENLIL."),
				"%s: nenhum par traz a fonte do dado de hoje" % rotulo)
			_igual(t._pares_fontes().back(), [t.tr("CREDITOS"), t.tr("CREDITOS_README")], "%s: os créditos são o último par" % rotulo)
			_verdade(texto_mais_baixo == t.tr("CREDITOS") or texto_mais_baixo == t.tr("CREDITOS_README"),
				"%s: o texto mais baixo da coluna é o dos créditos (%s)" % [rotulo, texto_mais_baixo.substr(0, 20)])
			_igual(fim_creditos, fim, "%s: os créditos acabam na base da coluna" % rotulo)
			var rolagem: Dictionary = t.rolagem_fontes()
			_igual(rolagem["ligada"], false, "%s: a lista cabe, a rolagem está desligada" % rotulo)
			_igual(rolagem["recorte"], [], "%s: sem rolagem, sem recorte" % rotulo)
			_igual(rolagem["mais_embaixo"], false, "%s: sem rolagem, sem indicador" % rotulo)
			_igual(t._coluna.visible, false, "%s: o filho da rolagem fica escondido" % rotulo)
			_roda(t._coluna, true)
			_roda(t._coluna, true)
			await process_frame
			await process_frame
			_igual(t.rolagem_fontes()["rolagem"], 0.0, "%s: a roda não rola o que cabe" % rotulo)
			_igual(t.textos(), antes, "%s: a roda não muda o desenho" % rotulo)
			_verdade(not t._pares_fontes().any(func(par): return par[0].contains("%s") or par[0].begins_with("FONTE_")),
				"%s: os fatos não têm chave nem %%s soltos" % rotulo)
			for i in rects.size():
				for j in range(i + 1, rects.size()):
					_verdade(not rects[i].intersects(rects[j]), "%s: duas linhas da lista não se sobrepõem (%s, %s)" % [rotulo, str(rects[i]), str(rects[j])])
			root.remove_child(t)
			t.free()
	TranslationServer.set_locale(idioma)


## Um evento de roda, de mouse e de toque no filho `c` (a coluna das fontes), do jeito de tests/test_abertura.gd.
func _roda(c: Control, baixo: bool) -> void:
	_botao_mouse(c, Vector2(100, 100), true, MOUSE_BUTTON_WHEEL_DOWN if baixo else MOUSE_BUTTON_WHEEL_UP)
	_botao_mouse(c, Vector2(100, 100), false, MOUSE_BUTTON_WHEEL_DOWN if baixo else MOUSE_BUTTON_WHEEL_UP)


func _botao_mouse(c: Control, pos: Vector2, apertado: bool, botao: int = MOUSE_BUTTON_LEFT, emulado: bool = false) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = botao
	e.pressed = apertado
	e.position = pos
	if emulado:
		e.device = InputEvent.DEVICE_ID_EMULATION
	c._gui_input(e)


func _mouse_move(c: Control, pos: Vector2, emulado: bool = false) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	if emulado:
		e.device = InputEvent.DEVICE_ID_EMULATION
	c._gui_input(e)


func _toque(c: Control, pos: Vector2, apertado: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = apertado
	e.position = pos
	c._gui_input(e)


func _arrasta_dedo(c: Control, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = pos
	c._gui_input(e)


## Uma tradução de teste (locale "fr", que o jogo não tem) com todos os textos do CSV em inglês e os créditos
## repetidos 4 vezes: a lista passa da altura da caixa sem mexer no código de produção.
func _traducao_longa() -> Translation:
	var tr_ := Translation.new()
	tr_.locale = "fr"
	var arq := FileAccess.open("res://textos/textos.csv", FileAccess.READ)
	arq.get_csv_line()  # keys,en,pt
	while not arq.eof_reached():
		var l := arq.get_csv_line()
		if l.size() >= 2 and l[0] != "":
			tr_.add_message(l[0], l[1])
			if l[0] == "CREDITOS":
				tr_.add_message("CREDITOS", " ".join([l[1], l[1], l[1], l[1]]))
	return tr_


## Quando a lista não cabe nem na fonte compacta, a coluna da direita rola: o filho recorta no interior da caixa, o
## indicador de "mais embaixo" acende, a roda, o arrasto do mouse e o do dedo levam ao fim, o mouse emulado do
## toque não soma, e mudar de aba volta ao alto.
func _aba_fontes_rola() -> void:
	var idioma := TranslationServer.get_locale()
	var traducao := _traducao_longa()
	TranslationServer.add_translation(traducao)
	TranslationServer.set_locale("fr")
	_igual(TranslationServer.get_locale(), "fr", "rola: o idioma de teste entrou")
	var m := Missao.new(1)
	var t: Control = Terminal.new()
	t.gravar_textos = true
	t.iniciar(m, {})
	_fechar_fila(t)
	t._acionar("aba_fontes")
	root.add_child(t)
	await process_frame
	await process_frame
	var c: Control = t._coluna
	var caixa := Rect2(Terminal.X0 + 186.0, Terminal.Y_CORPO, Terminal.X1 - Terminal.X0 - 186.0, Terminal.Y_FIM - Terminal.Y_CORPO)
	var info: Dictionary = t.rolagem_fontes()
	_igual(info["ligada"], true, "rola: a lista passou da altura, a rolagem liga")
	_verdade(c.visible, "rola: o filho está à vista")
	_verdade(c.clip_contents, "rola: o filho recorta")
	_igual(c.mouse_filter, Control.MOUSE_FILTER_STOP, "rola: o filho pega o mouse")
	var recorte := Rect2(info["recorte"][0], info["recorte"][1], info["recorte"][2], info["recorte"][3])
	_igual(recorte, caixa.grow(-1.0), "rola: o recorte é o interior da caixa")
	_igual(c.get_global_rect(), recorte, "rola: o filho ocupa o recorte")
	_igual(info["rolagem"], 0.0, "rola: começa no alto")
	_verdade(info["maximo"] > 0.0, "rola: há o que rolar")
	_igual(info["mais_embaixo"], true, "rola: o indicador de mais embaixo acende")
	var maximo: float = info["maximo"]

	# Rolagem 0: o primeiro fato fica onde ficaria sem rolagem, e há texto da coluna além do recorte (recortado, não sumido).
	var primeiro := true
	var passa := false
	for linha in t.textos():
		var r := _rect_do_texto(linha)
		if r.position.x < caixa.position.x or r.position.y < Terminal.Y_CORPO or linha[0] == t.tr("TERMINAL"):
			continue
		if primeiro:
			primeiro = false
			_igual([linha[1], linha[2]], [roundi(caixa.position.x + 8.0), roundi(caixa.position.y + 7.0)], "rola: o primeiro fato fica no mesmo lugar de sem rolagem")
		if r.end.y > recorte.end.y:
			passa = true
	_verdade(passa, "rola: na rolagem 0 há texto da coluna além do recorte")

	# A roda para baixo chega ao máximo.
	for i in 100:
		if c.rolagem >= maximo:
			break
		_roda(c, true)
	_igual(c.rolagem, maximo, "rola: a roda chega ao máximo")
	_roda(c, true)
	_igual(c.rolagem, maximo, "rola: a roda não passa do máximo")
	await process_frame
	await process_frame
	info = t.rolagem_fontes()
	_igual(info["rolagem"], maximo, "rola: a sonda lê a rolagem")
	_igual(info["mais_embaixo"], false, "rola: no fim o indicador apaga")
	var fim_lista := 0.0
	var achou := 0
	for linha in t.textos():
		if linha[0] == t.tr("CREDITOS") or linha[0] == t.tr("CREDITOS_README"):
			achou += 1
			for r: Rect2 in _rects_das_linhas(linha):
				_verdade(recorte.encloses(r), "rola: no fim os créditos ficam dentro do recorte (%s em %s)" % [str(r), str(recorte)])
				fim_lista = maxf(fim_lista, r.end.y)
	_igual(achou, 2, "rola: os dois textos dos créditos estão na lista")
	_verdade(fim_lista <= recorte.end.y - 5.0, "rola: sobra margem embaixo dos créditos (%f)" % (recorte.end.y - fim_lista))
	for i in 100:
		if c.rolagem <= 0.0:
			break
		_roda(c, false)
	_igual(c.rolagem, 0.0, "rola: a roda para cima volta ao alto")

	# Arrasto do mouse: aperta, move para cima, solta.
	_botao_mouse(c, Vector2(100, 200), true)
	_mouse_move(c, Vector2(100, 160))
	_igual(c.rolagem, minf(40.0, maximo), "rola: o conteúdo acompanha o mouse 1 para 1")
	for i in 20:
		_mouse_move(c, Vector2(100, 160 - 40 * (i + 1)))
	_botao_mouse(c, Vector2(100, -600), false)
	_igual(c.rolagem, maximo, "rola: o arrasto do mouse chega ao máximo")
	_mouse_move(c, Vector2(100, 0))
	_mouse_move(c, Vector2(100, 100))
	_igual(c.rolagem, maximo, "rola: solto o botão, o mouse não rola mais")
	c.zerar()

	# Arrasto de um dedo.
	_toque(c, Vector2(100, 200), true)
	for i in 20:
		_arrasta_dedo(c, Vector2(100, 200 - 40 * (i + 1)))
	_toque(c, Vector2(100, -600), false)
	_igual(c.rolagem, maximo, "rola: o arrasto de um dedo chega ao máximo")
	c.zerar()

	# O mouse emulado do toque, durante o gesto do dedo, não soma.
	var passo := minf(40.0, maximo / 2.0)
	_toque(c, Vector2(100, 200), true)
	_botao_mouse(c, Vector2(100, 200), true, MOUSE_BUTTON_LEFT, true)
	_arrasta_dedo(c, Vector2(100, 200 - passo))
	_mouse_move(c, Vector2(100, 200 - passo), true)
	_igual(c.rolagem, passo, "rola: o toque rola uma vez só, com o mouse emulado junto")
	_botao_mouse(c, Vector2(100, 200 - passo), false, MOUSE_BUTTON_LEFT, true)
	_toque(c, Vector2(100, 200 - passo), false)
	_igual(c.rolagem, passo, "rola: soltar o mouse emulado e o dedo não muda nada")
	c.zerar()

	# Mudar de aba volta ao alto: o plano e reabrir, e outra aba.
	_roda(c, true)
	_verdade(c.rolagem > 0.0, "rola: rolou antes de sair")
	t._acionar("voltar_plano")
	_igual(c.rolagem, 0.0, "rola: voltar ao plano zera a rolagem")
	_igual(t.rolagem_fontes()["ligada"], false, "rola: fora da aba fontes a rolagem desliga")
	t._acionar("aba_fontes")
	await process_frame
	await process_frame
	_igual(t.rolagem_fontes()["ligada"], true, "rola: reabrir a aba liga de novo")
	_igual(t.rolagem_fontes()["rolagem"], 0.0, "rola: reabrir a aba começa no alto")
	_roda(c, true)
	t._acionar("aba_diario")
	_igual(c.rolagem, 0.0, "rola: trocar de aba zera a rolagem")
	t._acionar("aba_fontes")
	_igual(t.rolagem_fontes()["rolagem"], 0.0, "rola: voltar às fontes começa no alto")
	await process_frame
	await process_frame

	# Descendo o terminal: só aceita gesto parado no alto, e o filho não cobre o botão TERMINAL.
	_roda(c, true)
	var antes: float = c.rolagem
	t._acionar("terminal")
	_rodar(t, m, 0.1)
	await process_frame
	await process_frame
	_verdade(t.animando(), "rola: o terminal está descendo")
	_verdade(c.visible, "rola: o filho acompanha a descida")
	_verdade(c.get_global_rect().position.y > recorte.position.y, "rola: o filho desce junto")
	_verdade(c.get_global_rect().end.y <= Terminal.BOTAO.position.y, "rola: o fundo do filho não passa do botão TERMINAL (%f)" % c.get_global_rect().end.y)
	_roda(c, true)
	_igual(c.rolagem, antes, "rola: com o terminal em movimento a roda não rola")
	_rodar(t, m, 1.0)
	await process_frame
	_igual(c.visible, false, "rola: o terminal embaixo, o filho some")
	root.remove_child(t)
	t.free()
	TranslationServer.remove_translation(traducao)
	TranslationServer.set_locale(idioma)


## Um relatório de fim de missão: `modos` modos de segurança, `ciencia` pontos (espalhados pelos sóis) e, em cada
## sol, os ícones que mais ocupam a faixa (modo de segurança com tempestade ou poeira).
func _missao_do_relatorio(modos: int, ciencia: int) -> Missao:
	var m := Missao.new(1)
	m.modos = modos
	m.st = {"E": 6.0, "O": 6.0, "M": 9.0, "P": 1.0, "gerador_quebrado": false}
	m.ciencia_por_sol = []
	m.registros = []
	var resto := ciencia
	for i in 5:
		var c := mini(resto, 2 if i < 4 else 3)
		resto -= c
		m.ciencia_por_sol.append(c)
		m.registros.append({"sol": i + 1, "ciencia": c, "seguranca": i < modos, "tempestade": i < 3, "poeira": i >= 3})
	m.fase = "relatorio"
	return m


## O relatório, nos dois idiomas e em três desfechos: tudo o que ele diz está na tela, nada abaixo de 12 px,
## nenhum texto se sobrepõe a outro nem ao botão, tudo em x 0 a 640 e y 0 a 320 (a faixa de baixo começa em
## 328). A linha do que faltou para a estrela seguinte fica na caixa das estrelas, com o texto de cada desfecho.
func _relatorio_cabe() -> void:
	var idioma := TranslationServer.get_locale()
	var tela := Rect2(0, 0, 640, 320)
	var casos := [[0, 7], [0, 4], [2, 0]]
	for loc in ["en", "pt"]:
		TranslationServer.set_locale(loc)
		for caso in casos:
			var modos: int = caso[0]
			var ciencia: int = caso[1]
			var rotulo := "relatório, %s, %d modos, ciência %d" % [loc, modos, ciencia]
			var m := _missao_do_relatorio(modos, ciencia)
			var t: Control = Terminal.new()
			t.gravar_textos = true
			t.iniciar(m, {})
			root.add_child(t)
			await process_frame
			await process_frame
			_igual(t.fase_ui, "relatorio", "%s: a fase" % rotulo)
			var estrelas := m.estrelas()
			var faltou_texto: String = {[0, 7]: t.tr("ESTRELAS_MAXIMO"), [0, 4]: t.tr("ESTRELAS_FALTA_CIENCIA") % 1,
				[2, 0]: t.tr("ESTRELAS_FALTA_MODO")}[caso]
			_igual(estrelas, {[0, 7]: 3, [0, 4]: 2, [2, 0]: 1}[caso], "%s: estrelas" % rotulo)
			var esperados := [
				t.tr("RELATORIO_NAVE"), t.tr("RELATORIO_TITULO"), t.tr("RELATORIO_SUB") % 5,
				t.tr("N_DE_3_ESTRELAS") % estrelas, t.tr("ESTRELAS_NOTA"), faltou_texto,
				t.tr("RELATORIO_CIENCIA_ENVIADA") % [ciencia, 7],
				t.tr("MARGEM_FINAL"), t.tr("N_DE_12") % 9, t.tr("MODOS_SEGURANCA"), str(modos),
				t.tr("RELATORIO_26_MESES"), t.tr("FONTE_ESCALA_FATO"),
				t.tr("DE_VERDADE"), t.tr("DE_VERDADE_DATA"), t.tr("DE_VERDADE_TEXTO"), t.tr("JOGAR_DE_NOVO"),
			]
			for i in 5:
				esperados.append(t.tr("SOL_N") % (i + 1))
				esperados.append("+%d" % m.ciencia_por_sol[i])
			var textos: Array = []
			for linha in t.textos():
				if linha[0] != t.tr("TERMINAL"):  # o botão do terminal é da faixa de baixo, não do relatório
					textos.append(linha)
			var desenhados: Array = []
			for linha in textos:
				desenhados.append(linha[0])
			for e: String in esperados:
				_verdade(desenhados.has(e), "%s: aparece \"%s\"" % [rotulo, e.substr(0, 30)])
			_verdade(not textos.is_empty() and textos[0][0] == t.tr("RELATORIO_NAVE"), "%s: a manchete é a primeira linha" % rotulo)
			var botao_a: Array = t.ui().get("jogar_de_novo", [])
			_verdade(not botao_a.is_empty(), "%s: o botão jogar de novo" % rotulo)
			var botao := Rect2(botao_a[0], botao_a[1], botao_a[2], botao_a[3]) if not botao_a.is_empty() else Rect2()
			_verdade(botao.size.x >= 24.0 and botao.size.y >= 24.0 and tela.encloses(botao), "%s: o botão é grande e cabe" % rotulo)
			var rects: Array = []
			var nomes: Array = []
			for linha in textos:
				_verdade(linha[3] >= 12, "%s: nenhum texto abaixo de 12 px (%s a %d px)" % [rotulo, linha[0].substr(0, 20), linha[3]])
				var r := _rect_do_texto(linha)
				_verdade(tela.encloses(r), "%s: cabe em 640x320 (%s em %s)" % [rotulo, linha[0].substr(0, 20), str(r)])
				_verdade(r.end.y <= Terminal.REL_Y_FIM, "%s: acaba até y 314 (%s, fim %d)" % [rotulo, linha[0].substr(0, 20), r.end.y])
				if botao.encloses(r):
					continue  # o rótulo do botão
				_verdade(not r.intersects(botao), "%s: não pisa no botão (%s)" % [rotulo, linha[0].substr(0, 20)])
				rects.append(r)
				nomes.append(linha[0].substr(0, 20))
			# A linha do que faltou: na caixa das estrelas, numa linha só (o rect dela já entrou na conta da sobreposição).
			for linha in textos:
				if linha[0] == faltou_texto:
					var rf := _rect_do_texto(linha)
					_verdade(Terminal.REL_ESTRELAS.encloses(rf), "%s: o que faltou fica na caixa das estrelas (%s)" % [rotulo, str(rf)])
					_verdade(Desenho.largura_texto(faltou_texto, 12, true) <= Terminal.REL_FALTOU.size.x,
						"%s: o que faltou cabe numa linha (%d de %d px)" % [rotulo, Desenho.largura_texto(faltou_texto, 12, true), Terminal.REL_FALTOU.size.x])
			for i in rects.size():
				for j in range(i + 1, rects.size()):
					_verdade(not rects[i].intersects(rects[j]), "%s: sem sobreposição (%s %s, %s %s)" % [rotulo, nomes[i], str(rects[i]), nomes[j], str(rects[j])])
			# A faixa dos sóis: o "+N" acaba antes da zona dos ícones (dois ícones de 14 px, a partir de 36 px da borda).
			for i in 5:
				for linha in textos:
					if linha[0] == "+%d" % m.ciencia_por_sol[i] and linha[3] == 14 and absf(linha[2] - (Terminal.REL_Y_SOIS + 2.0)) < 1.0 \
							and linha[1] > 14 + i * 123 and linha[1] < 14 + (i + 1) * 123:
						_verdade(_rect_do_texto(linha).end.x <= 14 + i * 123 + 119 - 40, "%s: o +N do sol %d fica antes dos ícones" % [rotulo, i + 1])
			root.remove_child(t)
			t.free()
	TranslationServer.set_locale(idioma)


## Um sol jogado até o fim do sol (ou, se o estado cair em segurança, seguido em segurança): devolve o
## terminal sobre a missão, com o registro do sol feito.
func _terminal_no_fim_do_sol(sol_n: int, opcoes: Dictionary) -> Array:
	opcoes["turno_s"] = 2.0
	var m := Missao.new(1, opcoes)
	m.montar_sol(sol_n, Modelo.estado_inicial())
	m.confirmar_plano()
	var guarda := 0
	while m.fase == "turno" and guarda < 200:
		m.abrigar()  # no sol da tempestade, para o sol não cair em segurança por radiação
		m.avancar(0.1)
		guarda += 1
	if m.fase == "seguranca":
		m.seguir_em_seguranca()
	var t: Control = Terminal.new()
	t.som = Som.new()
	t.iniciar(m, {})
	return [t, m]


## O diário do sol N abre com a história N, em cinza suave, antes de "o que aconteceu"; no modo livre não
## há história, e o primeiro item é o de sempre.
func _historia_do_sol_no_diario() -> void:
	var idioma := TranslationServer.get_locale()
	var textos_hist := {
		"en": [
			"First sol in Gale Crater. The sky is the color of rust.",
			"Gale was a lake billions of years ago. The rocks still keep that story.",
			"Halfway through the mission. Dust gets into everything, even the boots.",
			"Only one sol left. Every result counts now.",
			"Last sol. The ship is already a bright dot in the sky.",
		],
		"pt": [
			"Primeiro sol na cratera Gale. O céu tem cor de ferrugem.",
			"A cratera Gale já foi um lago, bilhões de anos atrás. As rochas guardam essa história.",
			"Metade da missão. A poeira entra em tudo, até nas botas.",
			"Falta só um sol. Agora cada resultado conta.",
			"Último sol. A nave já é um pontinho no céu.",
		],
	}
	for loc in ["en", "pt"]:
		TranslationServer.set_locale(loc)
		for n in range(1, 6):
			var rotulo := "%s, sol %d" % [loc, n]
			var c := _terminal_no_fim_do_sol(n, {})
			var t: Control = c[0]
			var m: Missao = c[1]
			_igual(m.registros.size(), 1, "%s: o sol deixou um registro" % rotulo)
			var itens: Array = t._itens_diario(m.registros[0])
			_igual(itens[0]["texto"], textos_hist[loc][n - 1], "%s: o primeiro item do diário é a história" % rotulo)
			_igual(itens[0]["cor"], Desenho.TEXTO_SUAVE, "%s: a história é em cinza suave" % rotulo)
			_verdade(itens[1]["texto"] != itens[0]["texto"], "%s: o segundo item é o que aconteceu" % rotulo)
			t.som.free()
			t.free()

			# Modo livre: a mesma missão, sem história.
			var cl := _terminal_no_fim_do_sol(n, {"livre": true})
			var tl: Control = cl[0]
			var ml: Missao = cl[1]
			var itens_livre: Array = tl._itens_diario(ml.registros[0])
			var achou := false
			for it in itens_livre:
				achou = achou or it["texto"] in textos_hist[loc]
			_igual(achou, false, "%s, modo livre: sem história no diário" % rotulo)
			_verdade(itens_livre[0].get("negrito", false), "%s, modo livre: o primeiro item é o que aconteceu" % rotulo)
			tl.som.free()
			tl.free()
	TranslationServer.set_locale(idioma)


## O pior caso da coluna esquerda do diário em cada sol da missão fixa (a única que mostra a história), em
## português e em inglês: o que o sol traz de verdade (tempestade sem abrigo, poeira, gerador quebrado e a
## mensagem da Terra, conforme a agenda) mais tarefas não feitas e energia perdida no teto. Tudo cabe entre o
## topo da caixa e a base, ao menos com o 1 px a menos que `_pintar_itens` aplica. Largura e altura são as de
## `_desenhar_diario`.
func _diario_cabe_no_pior_caso() -> void:
	var idioma := TranslationServer.get_locale()
	var larg := 306.0 - 20.0
	var altura := (Terminal.Y_FIM - 6.0) - (Terminal.Y_CORPO + 9.0)
	for loc in ["pt", "en"]:
		TranslationServer.set_locale(loc)
		for n in range(1, 6):
			var c := _terminal_no_fim_do_sol(n, {})
			var t: Control = c[0]
			var m: Missao = c[1]
			var reg: Dictionary = m.registros[0].duplicate()
			reg.merge({"seguranca": false, "tempestade": m.eh_sol_solar(), "abrigou": false, "dose": 12.0,
				"f_exposto": 0.5, "poeira": m.eh_poeira(), "nao_feitas": ["chemcam", "amostra", "planta"],
				"perdida_no_teto": 6.0, "gerador_quebrado": n >= m.sol_quebra, "consertou": false,
				"aviso": m.aviso_ativo()}, true)
			var itens: Array = t._itens_diario(reg)
			var h: float = t._altura_itens(itens, larg, 0)
			var h1: float = t._altura_itens(itens, larg, 1)
			_verdade(h1 <= altura, "%s, sol %d: o pior caso cabe (%d px, ou %d com 1 px a menos, de %d)" % [loc, n, h, h1, altura])
			t.som.free()
			t.free()
	TranslationServer.set_locale(idioma)


## O texto da tela traz a frase da barra e a do contexto; o quadro do caso real cabe até o botão, no
## pior caso de cada contexto, em português e em inglês.
func _frase_com_o_contexto() -> void:
	var casos := {}
	# O contexto da poeira, sem conserto (a antecipada).
	var a := Missao.new(1)
	a.montar_sol(4, _sem_salvacao())
	casos["poeira"] = [a, "CAUSA_OXIGENIO", "CAUSA_POEIRA", "CASO_REAL_ENERGIA", "CASO_TEXTO_ENERGIA", "seguir"]
	# Poeira com a causa energia, sem conserto: é o maior texto em português.
	var b := Missao.new(1)
	b.montar_sol(3, {"E": 0.0, "O": 10.0, "M": 8.0, "P": 0.0, "gerador_quebrado": false})
	casos["poeira_energia"] = [b, "CAUSA_ENERGIA", "CAUSA_POEIRA", "CASO_REAL_ENERGIA", "CASO_TEXTO_ENERGIA", "seguir"]
	# O gerador quebrado e não consertado, com conserto: reinicia.
	var c := Missao.new(1, {"sol_solar": 3, "sol_poeira": 5, "sol_quebra": 2})
	c.montar_sol(2, {"E": 6.0, "O": 0.0, "M": 12.0, "P": 1.0, "gerador_quebrado": true})
	c.confirmar_plano()
	c.avancar(c.turno_s)
	casos["gerador"] = [c, "CAUSA_OXIGENIO", "CAUSA_GERADOR", "CASO_REAL_OXIGENIO", "CASO_TEXTO_OXIGENIO", "reiniciar"]
	# O abrigo tardio (margem 4: o abrigo salvaria, então há conserto): a frase mais longa da radiação.
	var d := Missao.new(1, {"sol_solar": 3, "sol_poeira": 5, "sol_quebra": 2})
	d.montar_sol(3, {"E": 6.0, "O": 4.0, "M": 4.0, "P": 1.0, "gerador_quebrado": false})
	d.confirmar_plano()
	for i in 4000:
		if d.fase != "turno":
			break
		d.avancar(0.05)
	casos["sem_abrigo"] = [d, "CAUSA_RADIACAO", "CAUSA_SEM_ABRIGO", "CASO_REAL_RADIACAO", "CASO_TEXTO_RADIACAO", "reiniciar"]
	# Sem contexto: só a frase da barra, e o caso real é o da barra.
	var e := Missao.new(1, {"sol_solar": 3})
	e.montar_sol(1, {"E": 6.0, "O": 1.0, "M": 12.0, "P": 1.0, "gerador_quebrado": false})
	e.confirmar_plano()
	e.avancar(e.turno_s)
	casos["vazio"] = [e, "CAUSA_OXIGENIO", "", "CASO_REAL_OXIGENIO", "CASO_TEXTO_OXIGENIO", "reiniciar"]
	var idioma := TranslationServer.get_locale()
	for loc in ["pt", "en"]:
		TranslationServer.set_locale(loc)
		for nome in casos:
			var k: Array = casos[nome]
			var m: Missao = k[0]
			_igual(m.fase, "seguranca", "%s (%s): em segurança" % [nome, loc])
			var t: Control = Terminal.new()
			t.gravar_textos = true
			t.iniciar(m, {})
			root.add_child(t)
			await process_frame
			await process_frame
			var textos: Array = t.textos()
			var desenhados: Array = []
			for linha in textos:
				desenhados.append(linha[0])
			var esperada: String = t.tr(k[1])
			if k[2] != "":
				esperada += " " + t.tr(k[2])
			_verdade(desenhados.has(esperada), "%s (%s): a frase da barra e a do contexto" % [nome, loc])
			_verdade(desenhados.has(t.tr(k[3])) and desenhados.has(t.tr(k[4])), "%s (%s): o caso real que acompanha o contexto" % [nome, loc])
			if k[2] == "":
				_igual(desenhados.has(t.tr(k[1]) + " "), false, "%s (%s): sem contexto, sem sobra de espaço" % [nome, loc])
			# O quadro do caso real (62 px, a partir do rótulo menos 6) acaba acima do botão.
			var y_rotulo := -1
			for linha in textos:
				if linha[0] == t.tr(k[3]):
					y_rotulo = linha[2]
			var botao: Array = t.ui().get(k[5], [])
			_verdade(not botao.is_empty(), "%s (%s): o botão %s está na tela" % [nome, loc, k[5]])
			if not botao.is_empty():
				_verdade(y_rotulo - 6 + 62 <= botao[1] - 4, "%s (%s): o caso real cabe acima do botão (fim %d, botão %d)" % [nome, loc, y_rotulo - 6 + 62, botao[1]])
			# O texto da causa acaba antes do quadro.
			root.remove_child(t)
			t.free()
	TranslationServer.set_locale(idioma)
