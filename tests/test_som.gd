extends SceneTree
## Teste headless do som (scripts/som.gd): o barramento SFX, o volume geral e o mudo.
## Roda com: godot --headless --path . --script tests/test_som.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Som := preload("res://scripts/som.gd")

var falhas := 0
var total := 0


func _init() -> void:
	_barramento()
	_mudo()
	_tocar()
	_peso_dos_cliques()
	_squeak()
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)


func _igual(obtido, esperado, nome: String) -> void:
	total += 1
	if obtido != esperado:
		falhas += 1
		printerr("FALHOU: %s (obtido %s, esperado %s)" % [nome, str(obtido), str(esperado)])


func _barramento() -> void:
	# O barramento vem do default_bus_layout.tres: criado só em tempo de execução, o Web fica mudo.
	_igual(AudioServer.get_bus_index(Som.BARRAMENTO), 1, "o barramento já vem do layout do projeto")
	var i := Som.garantir_barramento()
	_igual(AudioServer.get_bus_name(i), "SFX", "nome do barramento")
	_igual(AudioServer.get_bus_send(i), &"Master", "envia ao Master")
	_igual(AudioServer.get_bus_volume_db(i), Som.VOLUME_GERAL_DB, "volume geral no barramento")
	var n := AudioServer.bus_count
	_igual(Som.garantir_barramento(), i, "garantir de novo devolve o mesmo")
	_igual(AudioServer.bus_count, n, "garantir de novo não cria outro")


func _mudo() -> void:
	var som := Som.new()
	som.definir_mudo(false)
	_igual(som.esta_mudo(), false, "começa sem mudo")
	som.alternar_mudo()
	_igual(som.esta_mudo(), true, "alternar liga")
	_igual(AudioServer.is_bus_mute(AudioServer.get_bus_index(Som.BARRAMENTO)), true, "o mudo é o do barramento")
	som.alternar_mudo()
	_igual(som.esta_mudo(), false, "alternar desliga")
	_igual(Som.mudo_de_texto("1"), true, "texto 1 é mudo")
	_igual(Som.mudo_de_texto("0"), false, "texto 0 não é")
	_igual(Som.mudo_de_texto(null), false, "nulo não é")
	_igual(Som.mudo_de_texto("lixo"), false, "lixo não é")
	som.free()


func _tocar() -> void:
	var som := Som.new()
	som.tocar("terminal_sobe")
	som.tocar("não_existe")
	som.tocar("desligar")
	_igual(som.historico, ["terminal_sobe", "desligar"], "histórico dos sons pedidos")
	_igual(som.total, 2, "contagem")
	som.tocar("alarme")
	_igual(som.historico, ["terminal_sobe", "desligar", "alarme"], "o alarme entra no histórico")
	_igual(Som.SONS["alarme"].get_length() <= 1.2, true, "o alarme é curto")
	_igual(Som.SONS["alarme"].get_length() > 0.5, true, "e dura o bastante para dois tons")
	_igual(Som.clique_da_acao("alarme"), "", "o alarme não é clique de ação")
	som.tocar("viagem_ignicao")
	som.tocar("viagem_pouso")
	_igual(som.historico.slice(-2), ["viagem_ignicao", "viagem_pouso"], "os sons da viagem entram no histórico")
	_igual(Som.SONS["viagem_ignicao"].get_length() > 2.0 and Som.SONS["viagem_ignicao"].get_length() < 3.0, true, "a ignição dura uns 2,5 s")
	_igual(Som.SONS["viagem_pouso"].get_length() > 0.5 and Som.SONS["viagem_pouso"].get_length() < 1.0, true, "o pouso dura uns 0,7 s")
	_igual(Som.clique_da_acao("viagem_pouso"), "", "os sons da viagem não são clique de ação")
	for nome: String in Som.SONS:
		_igual(Som.SONS[nome] is AudioStream, true, "som carregado: " + nome)
	som.free()


func _peso_dos_cliques() -> void:
	var navegar := ["aba_cameras", "aba_tarefas", "aba_diario", "aba_fontes", "voltar_plano", "fechar_card",
		"o2_menos", "o2_mais", "tarefa_chemcam", "tarefa_amostra", "tarefa_planta", "ir_chemcam", "ir_gerador",
		"card_cancelar"]
	var confirmar := ["confirmar", "enviar", "iniciar_chemcam", "consertar_gerador", "reiniciar", "seguir",
		"jogar_de_novo", "estufa", "glovebox", "porta", "card_confirmar"]
	for acao: String in navegar:
		_igual(Som.clique_da_acao(acao), "clique_navegar", "navegar: " + acao)
	for acao: String in confirmar:
		_igual(Som.clique_da_acao(acao), "clique_confirmar", "confirmar: " + acao)
	_igual(Som.clique_da_acao("abrigo"), "clique_abrigo", "o botão do abrigo na sala")
	_igual(Som.clique_da_acao("encerrar_sol"), "", "o botão saiu do terminal: a ação não existe mais")
	# Sem clique: o botão do terminal (tem o sobe e desce), as setas e o mudo.
	for acao: String in ["terminal", "seta_esq", "seta_dir", "mudo", "", "não_existe"]:
		_igual(Som.clique_da_acao(acao), "", "sem clique: " + acao)
	# Todo clique do mapa existe como som.
	for acao: String in Som.CLIQUE_DA_ACAO:
		_igual(Som.SONS.has(Som.CLIQUE_DA_ACAO[acao]), true, "o som de " + acao + " existe")
	var som := Som.new()
	som.clique("o2_mais")
	som.clique("terminal")
	som.clique("abrigo")
	_igual(som.historico, ["clique_navegar", "clique_abrigo"], "clique() toca só o que faz som")
	_igual(Som.clique_da_acao("ir_ao_abrigo"), "clique_navegar", "a linha do abrigo no terminal navega")
	som.free()


func _squeak() -> void:
	var dur: float = Som.SONS["squeak"].get_length()
	_igual(dur > 0.2 and dur < 0.3, true, "o squeak dura uns 0,25 s")
	_igual(Som.clique_da_acao("pato"), "", "o pato não é clique de ação: tem o squeak dele")
	_igual(is_equal_approx(Som.pitch_do_squeak(0.0), 0.9), true, "pitch mínimo: -10%")
	_igual(is_equal_approx(Som.pitch_do_squeak(0.5), 1.0), true, "pitch do meio: 1")
	_igual(is_equal_approx(Som.pitch_do_squeak(1.0), 1.1), true, "pitch máximo: +10%")
	_igual(is_equal_approx(Som.pitch_do_squeak(7.0), 1.1), true, "o sorteio fora de 0..1 fica preso")
	# Dois toques seguidos diferem de pelo menos o passo: o sorteio repete até se afastar do anterior.
	var fila := [0.5, 0.51, 0.52, 0.9]
	var sorteio := func() -> float: return fila.pop_front()
	var p: float = Som.proximo_pitch(1.0, sorteio)
	_igual(is_equal_approx(p, 1.08), true, "o pitch perto demais do anterior é sorteado de novo")
	_igual(fila.is_empty(), true, "e usou os sorteios até se afastar")
	# Sem tocador (fora da árvore), squeak() só registra: pitch dentro da faixa e diferente do anterior.
	var som := Som.new()
	var ultimo := 0.0
	var todos_diferentes := true
	var na_faixa := true
	for i in 50:
		som.squeak()
		var atual: float = som.pitches_squeak[-1]
		na_faixa = na_faixa and atual >= 0.9 - 0.0001 and atual <= 1.1 + 0.0001
		todos_diferentes = todos_diferentes and absf(atual - ultimo) >= Som.PASSO_PITCH_SQUEAK - 0.0001
		ultimo = atual
	_igual(na_faixa, true, "todo pitch fica em 1 ± 10%")
	_igual(todos_diferentes, true, "toques seguidos têm pitches diferentes")
	_igual(som.total, 50, "cada squeak conta")
	_igual(som.historico.slice(-3), ["squeak", "squeak", "squeak"], "o squeak entra no histórico")
	_igual(som.pitches_squeak.size() <= Som.MAX_HISTORICO, true, "o histórico de pitches é limitado")
	som.free()
