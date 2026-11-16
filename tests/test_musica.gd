extends SceneTree
## Teste headless da trilha (scripts/musica.gd): a faixa de cada estado, o pedido repetido, a vinheta.
## Roda com: godot --headless --path . --script tests/test_musica.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Musica := preload("res://scripts/musica.gd")

var falhas := 0
var total := 0


func _init() -> void:
	_faixa_por_estado()
	_pedidos()
	_vinheta()
	_arquivos()
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)


func _igual(obtido, esperado, nome: String) -> void:
	total += 1
	if obtido != esperado:
		falhas += 1
		printerr("FALHOU: %s (obtido %s, esperado %s)" % [nome, str(obtido), str(esperado)])


func _faixa_por_estado() -> void:
	for tela in ["inicio", "viagem", "abertura", "pagina"]:
		_igual(Musica.faixa_do_estado(tela, "plano", false, false), "calma", "calma na tela " + tela)
	for fase in ["plano", "noite", "fim_do_sol"]:
		_igual(Musica.faixa_do_estado("jogo", fase, false, false), "calma", "calma na fase " + fase)
	_igual(Musica.faixa_do_estado("jogo", "turno", false, false), "turno", "turno sem tempestade")
	_igual(Musica.faixa_do_estado("jogo", "turno", true, false), "tensa", "turno com tempestade em curso")
	_igual(Musica.faixa_do_estado("jogo", "turno", false, true), "tensa", "turno com a criança abrigada")
	_igual(Musica.faixa_do_estado("jogo", "turno", true, true), "tensa", "abrigada na tempestade")
	_igual(Musica.faixa_do_estado("jogo", "seguranca", false, false), "", "modo de segurança: silêncio")
	_igual(Musica.faixa_do_estado("jogo", "seguranca", true, true), "", "modo de segurança cala mesmo na tempestade")
	_igual(Musica.faixa_do_estado("jogo", "relatorio", false, false), "relatorio", "relatório: a vinheta")
	# Fora do jogo a tempestade não conta (a sobreposição está por cima).
	_igual(Musica.faixa_do_estado("pagina", "turno", true, true), "calma", "sobreposição manda a calma")
	for nome: String in ["calma", "tensa", "turno", "relatorio"]:
		_igual(Musica.FAIXAS.has(nome), true, "há arquivo da faixa " + nome)


func _pedidos() -> void:
	var m := Musica.new()
	m.pedir("calma")
	_igual(m.atual, "calma", "pediu a calma")
	_igual(m.trocas, 1, "uma troca")
	for i in 30:
		m.pedir("calma")
		m.avancar(0.1)
	_igual(m.trocas, 1, "a mesma faixa pedida de novo não reinicia")
	m.pedir("tensa")
	_igual(m.atual, "tensa", "trocou para a tensa")
	_igual(m.trocas, 2, "duas trocas")
	m.pedir("")
	_igual(m.atual, "", "silêncio")
	m.pedir("")
	_igual(m.trocas, 3, "silêncio repetido não conta")
	m.free()


func _vinheta() -> void:
	var m := Musica.new()
	m.pedir("turno")
	m.pedir("relatorio")
	_igual(m.atual, "relatorio", "a vinheta entra")
	var dur: float = Musica.FAIXAS["relatorio"].get_length()
	_igual(dur > 4.0 and dur < 5.5, true, "a vinheta dura uns 4,6 s")
	m.avancar(dur - 0.5)
	_igual(m.atual, "relatorio", "a vinheta ainda toca")
	m.avancar(0.6)
	_igual(m.atual, "calma", "acabou a vinheta: volta a calma")
	var trocas := m.trocas
	for i in 20:
		m.pedir("relatorio")  # a main repete o pedido todo quadro
		m.avancar(0.1)
	_igual(m.trocas, trocas, "o pedido repetido do relatório não refaz a vinheta")
	_igual(m.atual, "calma", "segue a calma")
	m.pedir("turno")
	m.pedir("relatorio")
	_igual(m.atual, "relatorio", "um relatório novo toca a vinheta de novo")
	m.free()


func _arquivos() -> void:
	for nome: String in ["calma", "tensa", "turno"]:
		var f: AudioStreamOggVorbis = Musica.FAIXAS[nome]
		_igual(f.loop, true, "%s faz loop" % nome)
		_igual(f.get_length() > 60.0, true, "%s é um loop longo" % nome)
	_igual(Musica.FAIXAS["relatorio"].loop, false, "a vinheta não faz loop")
