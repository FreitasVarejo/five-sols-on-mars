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

	var historico := _ler(caminho_historico)
	if historico.is_empty():
		historico = {"chegadas_marte": [], "motivo_historico": motivo + "+historico_ausente"}
	else:
		historico["motivo_historico"] = motivo
	historico["historico"] = true
	return historico


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


## Linha de depuração: "DONKI: N chegadas a Marte, dados de DD/MM/AAAA" ou o histórico.
static func resumo(dado: Dictionary) -> String:
	if dado["historico"]:
		return "DONKI: histórico de maio de 2024"
	return "DONKI: %d chegadas a Marte, dados de %s" % [dado["chegadas_marte"].size(), data_br(str(dado.get("coletado_em", "")))]
