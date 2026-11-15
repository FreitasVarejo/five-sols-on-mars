extends SceneTree
## Teste headless da geometria e dos textos da tela inicial do terminal (scripts/tela_inicial_terminal.gd):
## blocos grandes, sem sobreposição, dentro do corpo do terminal, e as linhas de cada aba em en e pt (no máximo
## 8 palavras a dica, estado tirado da missão).
## Roda com: godot --headless --path . --script tests/test_tela_inicial_terminal.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Tela := preload("res://scripts/tela_inicial_terminal.gd")
const Missao := preload("res://scripts/missao.gd")

var falhas := 0
var total := 0


func _init() -> void:
	_fases()
	_geometria()
	_textos()
	_estado()
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)


func _igual(obtido, esperado, nome: String) -> void:
	total += 1
	if obtido != esperado:
		falhas += 1
		printerr("FALHOU: %s (obtido %s, esperado %s)" % [nome, str(obtido), str(esperado)])


func _verdade(valor: bool, nome: String) -> void:
	_igual(valor, true, nome)


func _fases() -> void:
	_verdade(Tela.vale_na_fase("plano"), "vale no plano")
	_verdade(Tela.vale_na_fase("fim_do_sol"), "vale no fim do sol")
	_igual(Tela.vale_na_fase("turno"), false, "nunca no turno")
	_igual(Tela.vale_na_fase("seguranca"), false, "nem no modo de segurança")
	_igual(Tela.vale_na_fase("relatorio"), false, "nem no relatório")


func _geometria() -> void:
	var b := Tela.blocos()
	_igual(b.keys().size(), 5, "cinco blocos: a fase e as quatro abas")
	var corpo := Rect2(90.0, 42.0, 534.0, 272.0)
	var lista: Array = b.values()
	for nome: String in b:
		var r: Rect2 = b[nome]
		_verdade(corpo.encloses(r), "%s: dentro do corpo do terminal" % nome)
		_verdade(r.size.x >= 44.0 and r.size.y >= 44.0, "%s: alvo de toque de 44 px ou mais" % nome)
	for i in lista.size():
		for j in range(i + 1, lista.size()):
			_verdade(not (lista[i] as Rect2).intersects(lista[j]), "blocos %d e %d não se sobrepõem" % [i, j])
	for a: String in Tela.ABAS:
		_verdade((b["fase"] as Rect2).size.y > (b[a] as Rect2).size.y, "o bloco da fase é o maior (altura) vs %s" % a)
		_verdade((b["fase"] as Rect2).get_area() > (b[a] as Rect2).get_area(), "o bloco da fase é o maior (área) vs %s" % a)
	_verdade((b["cameras"] as Rect2).position.y == (b["tarefas"] as Rect2).position.y, "câmeras e tarefas na mesma linha")
	_verdade((b["diario"] as Rect2).position.y > (b["cameras"] as Rect2).position.y, "diário e fontes na linha de baixo")


func _palavras(s: String) -> int:
	return s.split(" ", false).size()


func _textos() -> void:
	var idioma := TranslationServer.get_locale()
	for loc in ["en", "pt"]:
		TranslationServer.set_locale(loc)
		var titulo := TranslationServer.translate("INICIO_TITULO")
		_verdade(titulo != "INICIO_TITULO" and titulo.begins_with("PANEL" if loc == "en" else "PAINEL"), "%s: o título existe" % loc)
		for a: String in Tela.ABAS:
			var d := Tela.dica_da_aba(a)
			_verdade(d != "INICIO_DICA_" + a.to_upper(), "%s: %s tem dica traduzida" % [loc, a])
			_verdade(_palavras(d) <= 8, "%s: a dica de %s tem no máximo 8 palavras (%d)" % [loc, a, _palavras(d)])
		for f: String in Tela.FASES:
			var d := Tela.dica_da_fase(f)
			_verdade(d != "INICIO_DICA_FASE_PLANO" and d != "INICIO_DICA_FASE_FIM", "%s: %s tem dica traduzida" % [loc, f])
			_verdade(_palavras(d) <= 8, "%s: a dica da fase %s tem no máximo 8 palavras" % [loc, f])
			_verdade("3" in Tela.titulo_da_fase(f, 3), "%s: o título da fase %s leva o número do sol" % [loc, f])
	TranslationServer.set_locale(idioma)


func _estado() -> void:
	var idioma := TranslationServer.get_locale()
	TranslationServer.set_locale("pt")
	# Missão fixa: poeira nos sóis 3 e 4.
	var m := Missao.new(1)
	m.montar_sol(2, {"E": 12.0, "O": 12.0, "M": 12.0, "P": 1.0, "gerador_quebrado": false})
	_igual(Tela.estado_da_aba("cameras", "plano", m, false), "Céu limpo hoje", "câmeras: sol 2, céu limpo")
	m.montar_sol(3, {"E": 12.0, "O": 12.0, "M": 12.0, "P": 0.5, "gerador_quebrado": false})
	_igual(m.eh_poeira(), true, "o sol 3 da missão fixa tem poeira")
	_igual(Tela.estado_da_aba("cameras", "plano", m, false), "Poeira no ar hoje", "câmeras: poeira")
	_igual(Tela.estado_da_aba("tarefas", "plano", m, false), "0 no plano de hoje", "tarefas: nada escolhido")
	m.alternar_tarefa("planta")
	m.alternar_tarefa("amostra")
	_igual(Tela.estado_da_aba("tarefas", "plano", m, false), "2 no plano de hoje", "tarefas: duas escolhidas")
	_igual(Tela.estado_da_aba("tarefas", "fim_do_sol", m, false), "0 de 0 feitas", "tarefas no fim: a missão ainda não rodou")
	m.tarefas = {"planta": "feita", "amostra": "pendente"}
	_igual(Tela.estado_da_aba("tarefas", "fim_do_sol", m, false), "1 de 2 feitas", "tarefas no fim: 1 de 2")
	_igual(Tela.estado_da_aba("diario", "plano", m, false), "0 de 5 sóis no diário", "diário vazio")
	m.registros.append({"sol": 1})
	_igual(Tela.estado_da_aba("diario", "plano", m, false), "1 de 5 sóis no diário", "diário com 1 registro")
	_igual(Tela.estado_da_aba("fontes", "plano", m, true), "Com dado recente da NASA", "fontes: dado recente")
	_igual(Tela.estado_da_aba("fontes", "plano", m, false), "Dados de maio de 2024", "fontes: histórico")
	_igual(Tela.estado_da_aba("xyz", "plano", m, false), "", "aba desconhecida: vazio")
	TranslationServer.set_locale(idioma)
