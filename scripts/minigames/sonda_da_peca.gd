extends RefCounted
## O que uma peça (minigame) à vista oferece, em px da tela de 640x360, para o teste no navegador (a sonda de
## main.gd: window.fsom.minigame) e para os testes headless. Quem hospeda a peça (o visor do terminal ou a vista de
## perto) chama `descrever` com ela; a peça precisa estar na árvore, porque a posição vem da transformação global.
## ChemCam: "alvos" (o centro de cada alvo pendente) e "raio". Gerador: "pecas" (o retângulo de cada peça na bandeja),
## "certa" (o índice da peça que encaixa), "formas" e "encaixe" (o centro). Planta: "botoes" (luz, regador, ventilador
## e tesoura, em [x, y, w, h]), "problema", "umidade", "mofo" e "luz_acesa". Amostra: "passo", "alvo" (o botão do
## passo), "profundidade" e "graus". Todas levam "tipo" e "progresso".


## Vazio se `p` é nulo ou de um tipo que a sonda não conhece.
static func descrever(p: Control) -> Dictionary:
	if p == null:
		return {}
	var m := p.get_global_transform()
	if p.has_method("alvos_na_area"):
		var alvos: Array = []
		var locais: PackedVector2Array = p.alvos_na_area()
		for i in locais.size():
			if p.estado_alvo(i) == "pendente":
				var c: Vector2 = m * locais[i]
				alvos.append([roundi(c.x), roundi(c.y)])
		return {"tipo": "chemcam", "alvos": alvos, "raio": p.raio_toque(), "progresso": p.progresso()}
	if p.has_method("centro_do_encaixe"):
		var pecas: Array = []
		for i in 3:
			var r: Rect2 = p.alvo_da_peca(i)
			var o: Vector2 = m * r.position
			pecas.append([roundi(o.x), roundi(o.y), roundi(r.size.x), roundi(r.size.y)])
		var sorteio: Dictionary = p.sorteio_atual()
		var e: Vector2 = m * p.centro_do_encaixe()
		return {"tipo": "gerador", "pecas": pecas, "certa": sorteio["certa"], "formas": sorteio["formas"],
			"encaixe": [roundi(e.x), roundi(e.y)], "progresso": p.progresso()}
	if p.has_method("retangulo_da_luz"):
		var botoes := {}
		var rl: Rect2 = p.retangulo_da_luz()
		var ol: Vector2 = m * rl.position
		botoes["luz"] = [roundi(ol.x), roundi(ol.y), roundi(rl.size.x), roundi(rl.size.y)]
		for nome: String in p.FERRAMENTAS:
			var rb: Rect2 = p.retangulo_da_ferramenta(nome)
			var ob: Vector2 = m * rb.position
			botoes[nome] = [roundi(ob.x), roundi(ob.y), roundi(rb.size.x), roundi(rb.size.y)]
		return {"tipo": "planta", "botoes": botoes, "problema": p.problema(), "umidade": p.umidade(), "mofo": p.mofo(),
			"luz_acesa": p.luz_acesa(), "progresso": p.progresso()}
	if p.has_method("alvo_do_passo"):
		var a: Rect2 = p.alvo_do_passo()
		var o: Vector2 = m * a.position
		return {"tipo": "amostra", "passo": p.passo(), "alvo": [roundi(o.x), roundi(o.y), roundi(a.size.x), roundi(a.size.y)],
			"profundidade": p.profundidade(), "graus": p.graus(), "progresso": p.progresso()}
	return {}
