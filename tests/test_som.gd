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
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)


func _igual(obtido, esperado, nome: String) -> void:
	total += 1
	if obtido != esperado:
		falhas += 1
		printerr("FALHOU: %s (obtido %s, esperado %s)" % [nome, str(obtido), str(esperado)])


func _barramento() -> void:
	_igual(AudioServer.get_bus_index(Som.BARRAMENTO), -1, "sem o barramento antes")
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
	for nome: String in Som.SONS:
		_igual(Som.SONS[nome] is AudioStream, true, "som carregado: " + nome)
	som.free()
