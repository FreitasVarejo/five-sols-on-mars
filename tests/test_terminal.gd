extends SceneTree
## Teste headless do terminal animado (scripts/terminal.gd), sem desenhar: a duração da URL, o easing, a
## animação de subir e descer (alvo, posição, inversão no meio, sons), o que tapa a sala e o conteúdo
## que fica para trás numa descida automática.
## Roda com: godot --headless --path . --script tests/test_terminal.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Terminal := preload("res://scripts/terminal.gd")
const Missao := preload("res://scripts/missao.gd")
const Som := preload("res://scripts/som.gd")
const HudTurno := preload("res://scripts/hud_turno.gd")
const Desenho := preload("res://scripts/desenho.gd")
const Main := preload("res://scripts/main.gd")

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
	await _frase_com_o_contexto()
	await _cards_ao_lado_do_controle()
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
