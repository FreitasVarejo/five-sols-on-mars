extends SceneTree
## Teste headless do terminal animado (scripts/terminal.gd), sem desenhar: a duração da URL, o easing, a
## animação de subir e descer (alvo, posição, inversão no meio, sons), o que tapa a sala e o conteúdo
## que fica para trás numa descida automática.
## Roda com: godot --headless --path . --script tests/test_terminal.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Terminal := preload("res://scripts/terminal.gd")
const Missao := preload("res://scripts/missao.gd")
const Som := preload("res://scripts/som.gd")

const QUADRO := 1.0 / 60.0

var falhas := 0
var total := 0


func _init() -> void:
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
	return [t, m, som]


## Roda `s` segundos de quadros: a missão avança e o terminal anda.
func _rodar(t: Control, m: Missao, s: float) -> void:
	var n := roundi(s / QUADRO)
	for i in n:
		m.avancar(QUADRO)
		t._process(QUADRO)


func _duracao_da_url() -> void:
	_igual(Terminal.duracao_da_url(null), 0.4, "sem parâmetro: o padrão")
	_igual(Terminal.duracao_da_url("0.25"), 0.25, "0,25")
	_igual(Terminal.duracao_da_url("0.4"), 0.4, "0,4")
	_igual(Terminal.duracao_da_url("0.6"), 0.6, "0,6")
	_igual(Terminal.duracao_da_url("0.15"), 0.15, "limite baixo")
	_igual(Terminal.duracao_da_url("1.5"), 1.5, "limite alto")
	_igual(Terminal.duracao_da_url("0.05"), 0.4, "abaixo da faixa: o padrão")
	_igual(Terminal.duracao_da_url("9"), 0.4, "acima da faixa: o padrão")
	_igual(Terminal.duracao_da_url("abc"), 0.4, "texto: o padrão")
	_igual(Terminal.duracao_da_url("0"), 0.4, "zero: o padrão")


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
	# Com o card da Terra aberto, só o Fechar vale: o resto não faz som.
	t.card_aberto = true
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
	# No turno, a tecla desabilitada (diário) não faz nada.
	_rodar(t, m, t.duracao * 1.5)
	t._acionar("aba_diario")
	_igual(som.historico, [], "tecla desabilitada: sem som")
	t._acionar("aba_cameras")
	_igual(som.historico, ["clique_navegar"], "tecla habilitada navega")
	som.free()
	t.free()


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
	t._acionar("fechar_card")  # o sol 3 abre com o aviso da Terra
	t._acionar("confirmar")
	_rodar(t, m, t.duracao * 1.5)
	som.historico.clear()
	_ate_sair_do_turno(t, m)
	_igual(m.fase, "seguranca", "entrou no modo de segurança no meio do turno")
	_igual(m.modos, 1, "uma entrada")
	_rodar(t, m, QUADRO * 3.0)
	_igual(som.historico, ["desligar", "terminal_sobe"], "meio do turno: desligar na hora, junto com a subida")
	_igual(t._fade_estado, "", "sem escurecimento no meio do turno")
	_rodar(t, m, 2.0)
	_igual(som.historico, ["desligar", "terminal_sobe"], "o desligar não repete enquanto fica no modo de segurança")
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
	t._acionar("confirmar")
	_rodar(t, m, t.duracao * 1.5)
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
	t._acionar("confirmar")
	_rodar(t, m, t.duracao * 1.5)
	som.historico.clear()
	_ate_sair_do_turno(t, m)
	_rodar(t, m, QUADRO * 3.0)
	_igual(m.modos, 2, "segunda entrada")
	_igual(som.historico, ["desligar"], "cada entrada toca o desligar uma vez")
	som.free()
	t.free()
