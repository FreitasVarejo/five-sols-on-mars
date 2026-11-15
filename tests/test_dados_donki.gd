extends SceneTree
## Teste headless de scripts/dados_donki.gd: o histórico direto, a chegada mais recente, as chegadas de um
## intervalo e a data por idioma.
## Roda com: godot --headless --path . --script tests/test_dados_donki.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const DadosDonki := preload("res://scripts/dados_donki.gd")

var falhas := 0
var total := 0


func _init() -> void:
	_historico()
	_carregar_cai_no_historico()
	_mais_recente()
	_chegadas_entre()
	_data_texto()
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)


func _igual(obtido, esperado, nome: String) -> void:
	total += 1
	if obtido != esperado:
		falhas += 1
		printerr("FALHOU: %s (obtido %s, esperado %s)" % [nome, str(obtido), str(esperado)])


func _verdade(valor: bool, nome: String) -> void:
	_igual(valor, true, nome)


func _historico() -> void:
	var h := DadosDonki.historico()
	_igual(h["historico"], true, "o histórico se diz histórico")
	_verdade(h["chegadas_marte"].size() > 0, "o histórico traz chegadas")
	_igual(h.has("motivo_historico"), false, "lido direto, sem motivo de queda")
	var vazio := DadosDonki.historico("res://dados/nao_existe.json")
	_igual(vazio["historico"], true, "arquivo ausente: ainda histórico")
	_igual(vazio["chegadas_marte"], [], "arquivo ausente: sem chegadas")


func _carregar_cai_no_historico() -> void:
	var d := DadosDonki.carregar("res://dados/nao_existe.json")
	_igual(d["historico"], true, "sem o arquivo atual, carregar() devolve o histórico")
	_igual(d["motivo_historico"], "sem_arquivo", "o motivo da queda")
	_igual(d["chegadas_marte"].size(), DadosDonki.historico()["chegadas_marte"].size(), "as mesmas chegadas do histórico")
	var v := DadosDonki.carregar("res://dados/nao_existe.json", "res://dados/nao_existe_tambem.json")
	_igual(v["chegadas_marte"], [], "nenhum dos dois: lista vazia")
	_igual(v["motivo_historico"], "sem_arquivo+historico_ausente", "o motivo, com o histórico ausente")
	_igual(DadosDonki.carregar()["historico"], false, "o dado do build é lido como atual")


func _mais_recente() -> void:
	var dado := {"chegadas_marte": [
		{"chegada_prevista": "2026-10-01T12:00:00Z", "id": "a"},
		{"chegada_prevista": "2026-11-13T12:00:00Z", "id": "c"},
		{"chegada_prevista": "2026-10-20T00:00:00Z", "id": "b"},
		{"chegada_prevista": null, "id": "sem data"},
	]}
	_igual(DadosDonki.mais_recente(dado)["id"], "c", "a chegada com a data mais recente, fora de ordem")
	_igual(DadosDonki.mais_recente({"chegadas_marte": []}), {}, "sem chegadas: {}")
	_igual(DadosDonki.mais_recente({}), {}, "sem a chave: {}")
	_igual(DadosDonki.mais_recente(DadosDonki.historico())["chegada_prevista"], "2024-05-29T12:00:00Z", "a mais recente do histórico")


func _chegadas_entre() -> void:
	# O texto DONKI_FRASE_HISTORICO afirma 5 tempestades previstas entre 19 e 21 de maio de 2024.
	_igual(DadosDonki.chegadas_entre(DadosDonki.historico(), "2024-05-19", "2024-05-21").size(), 5,
		"a frase do histórico diz 5 chegadas entre 19 e 21/05/2024")
	var h := DadosDonki.historico()
	_igual(DadosDonki.chegadas_entre(h, "2024-05-19", "2024-05-19").size(), 2, "um dia só, inclusivo")
	_igual(DadosDonki.chegadas_entre(h, "2024-05-21", "2024-05-21").size(), 1, "o último dia entra (18h)")
	_igual(DadosDonki.chegadas_entre(h, "2024-06-01", "2024-06-30").size(), 0, "intervalo sem chegadas")
	_igual(DadosDonki.chegadas_entre(h, "2024-05-01", "2024-05-31").size(), h["chegadas_marte"].size(), "o recorte inteiro")
	_igual(DadosDonki.chegadas_entre(h, "2024-05-21", "2024-05-19").size(), 0, "intervalo invertido: nada")
	_igual(DadosDonki.chegadas_entre({}, "2024-05-19", "2024-05-21"), [], "sem dado: []")


func _data_texto() -> void:
	_igual(DadosDonki.data_texto("2026-11-14", "en"), "14 November 2026", "inglês por extenso")
	_igual(DadosDonki.data_texto("2024-05-19T09:15:00Z", "en"), "19 May 2024", "com hora, só o dia")
	_igual(DadosDonki.data_texto("2024-05-05", "en"), "5 May 2024", "dia sem zero à esquerda")
	_igual(DadosDonki.data_texto("2026-11-14", "en_US"), "14 November 2026", "variante do inglês")
	_igual(DadosDonki.data_texto("2026-11-14", "pt"), "14/11/2026", "português numérico")
	_igual(DadosDonki.data_texto("2026-11-14", "pt_BR"), "14/11/2026", "variante do português")
	_igual(DadosDonki.data_texto("2026-01-02", "pt"), "02/01/2026", "português mantém o zero")
	_igual(DadosDonki.data_texto("2026-12-31", "en"), "31 December 2026", "dezembro")
	_igual(DadosDonki.data_texto("", "en"), "", "vazio volta vazio")
	_igual(DadosDonki.data_texto("amanhã", "pt"), "amanhã", "texto volta como veio (pt)")
	_igual(DadosDonki.data_texto("amanhã", "en"), "amanhã", "texto volta como veio (en)")
	_igual(DadosDonki.data_texto("2026-13-01", "en"), "2026-13-01", "mês inválido volta como veio")
	_igual(DadosDonki.data_texto("a-b-c", "en"), "a-b-c", "três partes que não são número voltam como vieram")
