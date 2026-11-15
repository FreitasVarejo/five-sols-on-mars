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
	for nome: String in Som.SONS:
		_igual(Som.SONS[nome] is AudioStream, true, "som carregado: " + nome)
	som.free()


func _peso_dos_cliques() -> void:
	var navegar := ["aba_cameras", "aba_tarefas", "aba_diario", "aba_fontes", "voltar_plano", "fechar_card",
		"o2_menos", "o2_mais", "tarefa_chemcam", "tarefa_amostra", "tarefa_planta", "ir_chemcam", "ir_gerador"]
	var confirmar := ["confirmar", "enviar", "iniciar_chemcam", "consertar_gerador", "reiniciar", "seguir",
		"jogar_de_novo", "estufa", "glovebox", "porta"]
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
