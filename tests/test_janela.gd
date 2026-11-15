extends SceneTree
## Teste headless das funções puras da janela (scripts/janela.gd): a hora do dia e a luz da sala.
## Roda com: godot --headless --path . --script tests/test_janela.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Janela := preload("res://scripts/janela.gd")

var falhas := 0
var total := 0


func _init() -> void:
	_hora()
	_luz()
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)


func _igual(obtido, esperado, nome: String) -> void:
	total += 1
	if obtido != esperado:
		falhas += 1
		printerr("FALHOU: %s (obtido %s, esperado %s)" % [nome, str(obtido), str(esperado)])


func _perto(obtido: float, esperado: float, nome: String) -> void:
	total += 1
	if absf(obtido - esperado) > 1e-5:
		falhas += 1
		printerr("FALHOU: %s (obtido %s, esperado %s)" % [nome, str(obtido), str(esperado)])


func _hora() -> void:
	_igual(Janela.hora_da_fase("turno", 0.0, 0.5), 0.0, "turno no começo")
	_igual(Janela.hora_da_fase("turno", 0.42, 0.9), 0.42, "turno segue o relógio")
	_igual(Janela.hora_da_fase("turno", 1.0, 0.0), 1.0, "turno no fim")
	_igual(Janela.hora_da_fase("plano", 0.7, 1.0), 0.0, "plano é amanhecer")
	for fase in ["fim_do_sol", "noite", "relatorio"]:
		_igual(Janela.hora_da_fase(fase, 0.3, 0.0), 1.0, "%s é noite" % fase)
	_igual(Janela.hora_da_fase("seguranca", 0.9, 0.37), 0.37, "segurança mantém a anterior")
	_igual(Janela.hora_da_fase("qualquer", 0.9, 0.5), 0.5, "fase desconhecida mantém a anterior")


func _luz() -> void:
	# Turno de 60 s: a luz começa a subir aos 50 s (relógio 5/6) e chega a 1 no fim.
	_igual(Janela.luz_da_fase("turno", 0.0, 60.0, 0.5), 0.0, "turno no começo")
	_igual(Janela.luz_da_fase("turno", 0.5, 60.0, 0.5), 0.0, "meio do turno")
	_igual(Janela.luz_da_fase("turno", 1.0 - 10.0 / 60.0, 60.0, 0.5), 0.0, "10 s antes do fim")
	_perto(Janela.luz_da_fase("turno", 1.0 - 5.0 / 60.0, 60.0, 0.0), 0.5, "5 s antes do fim é metade")
	_igual(Janela.luz_da_fase("turno", 1.0, 60.0, 0.0), 1.0, "fim do turno")
	# Suave e crescente: nunca diminui ao andar o relógio, e nenhum passo de 1/60 s dá salto grande.
	var anterior := 0.0
	var maior_passo := 0.0
	var decresceu := false
	for i in 601:
		var k := Janela.luz_da_fase("turno", i / 600.0, 60.0, 0.0)
		if k < anterior:
			decresceu = true
		maior_passo = maxf(maior_passo, k - anterior)
		anterior = k
	_igual(decresceu, false, "luz nunca diminui no turno")
	_igual(maior_passo < 0.05, true, "luz sobe em passos pequenos")
	# Turno curto (8 s, como em ?turno=8): a conta não explode e termina em 1.
	_igual(Janela.luz_da_fase("turno", 0.0, 8.0, 0.0) >= 0.0, true, "turno curto no começo")
	_igual(Janela.luz_da_fase("turno", 1.0, 8.0, 0.0), 1.0, "turno curto no fim")
	_igual(Janela.luz_da_fase("plano", 0.9, 60.0, 1.0), 0.0, "plano apaga a luz fria")
	for fase in ["fim_do_sol", "noite", "relatorio"]:
		_igual(Janela.luz_da_fase(fase, 0.0, 60.0, 0.0), 1.0, "%s é luz fria" % fase)
	_igual(Janela.luz_da_fase("seguranca", 0.0, 60.0, 0.63), 0.63, "segurança mantém a anterior")
