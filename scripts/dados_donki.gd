extends RefCounted
## Dado do DONKI embutido no build (scripts/baixar_donki.py; formato no docstring dele).
##
## O jogo nunca chama a NASA: lê o JSON que foi empacotado. carregar() devolve o dado
## atual, ou o recorte histórico de maio de 2024 se o arquivo atual faltar, não ler ou
## vier sem nenhuma chegada a Marte. No histórico, "historico" é sempre true, para o jogo
## nunca mostrar dado estático como se fosse ao vivo.
##
## O Dictionary devolvido sempre tem "historico" (bool) e "chegadas_marte" (Array); o resto
## é o que o JSON trouxe. Só no histórico por queda vem também "motivo_historico".

const ATUAL := "res://dados/donki.json"
const HISTORICO := "res://dados/donki_historico_2024-05.json"


static func carregar(caminho_atual: String = ATUAL, caminho_historico: String = HISTORICO) -> Dictionary:
	var motivo := "sem_arquivo"
	if FileAccess.file_exists(caminho_atual):
		var atual := _ler(caminho_atual)
		if atual.is_empty():
			motivo = "ilegivel"
		elif atual["chegadas_marte"].is_empty():
			motivo = "lista_vazia"
		else:
			atual["historico"] = atual.get("historico", false) == true
			return atual

	return historico(caminho_historico, motivo)


## O recorte de maio de 2024, com "historico" true (o jogo nunca o mostra como dado de hoje). Se o arquivo
## faltar ou não for legível, devolve o dicionário vazio com "chegadas_marte": [] e o motivo.
## `motivo`, se vier, entra em "motivo_historico" (carregar() diz por que caiu no histórico).
static func historico(caminho: String = HISTORICO, motivo: String = "") -> Dictionary:
	var dado := _ler(caminho)
	if dado.is_empty():
		dado = {"chegadas_marte": []}
		if motivo != "":
			dado["motivo_historico"] = motivo + "+historico_ausente"
	elif motivo != "":
		dado["motivo_historico"] = motivo
	dado["historico"] = true
	return dado


## A chegada com `chegada_prevista` mais recente, ou {} se não houver nenhuma.
static func mais_recente(dado: Dictionary) -> Dictionary:
	var melhor := {}
	var data_melhor := ""
	for c in dado.get("chegadas_marte", []):
		if not (c is Dictionary):
			continue
		var quando = c.get("chegada_prevista")
		if quando is String and quando > data_melhor:
			data_melhor = quando
			melhor = c
	return melhor


## As chegadas cuja `chegada_prevista` cai de `inicio_iso` a `fim_iso` ("AAAA-MM-DD"), os dois dias inclusos.
static func chegadas_entre(dado: Dictionary, inicio_iso: String, fim_iso: String) -> Array:
	var lista := []
	for c in dado.get("chegadas_marte", []):
		if not (c is Dictionary):
			continue
		var quando = c.get("chegada_prevista")
		if quando is String:
			var dia: String = quando.substr(0, 10)
			if dia >= inicio_iso and dia <= fim_iso:
				lista.append(c)
	return lista


## Lê um JSON do DONKI. Vazio se faltar, não for JSON ou não tiver chegadas_marte (Array).
static func _ler(caminho: String) -> Dictionary:
	if not FileAccess.file_exists(caminho):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(caminho)) != OK:
		return {}
	var dados = json.data
	if not (dados is Dictionary) or not (dados.get("chegadas_marte") is Array):
		return {}
	return dados


## "AAAA-MM-DD" -> "DD/MM/AAAA" (o que o jogo mostra). Qualquer outra coisa volta como veio.
static func data_br(iso: String) -> String:
	var p := iso.substr(0, 10).split("-")
	if p.size() != 3:
		return iso
	return "%s/%s/%s" % [p[2], p[1], p[0]]


const MESES_EN := ["January", "February", "March", "April", "May", "June", "July", "August", "September",
	"October", "November", "December"]


## A data como o jogo a mostra: em português "14/11/2026"; em inglês por extenso, "14 November 2026" (a data
## numérica é ambígua para quem lê o mês primeiro). Entrada que não é data volta como veio.
static func data_texto(iso: String, locale: String) -> String:
	var p := iso.substr(0, 10).split("-")
	if p.size() != 3 or not (p[0].is_valid_int() and p[1].is_valid_int() and p[2].is_valid_int()):
		return iso
	var mes := p[1].to_int()
	if mes < 1 or mes > 12:
		return iso
	if locale.begins_with("pt"):
		return data_br(iso)
	return "%d %s %s" % [p[2].to_int(), MESES_EN[mes - 1], p[0]]


## Linha de depuração: "DONKI: N chegadas a Marte, dados de DD/MM/AAAA" ou o histórico.
static func resumo(dado: Dictionary) -> String:
	if dado["historico"]:
		return "DONKI: histórico de maio de 2024"
	return "DONKI: %d chegadas a Marte, dados de %s" % [dado["chegadas_marte"].size(), data_br(str(dado.get("coletado_em", "")))]
