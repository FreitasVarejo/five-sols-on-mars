extends SceneTree
## Teste headless do visor da aba câmeras (scripts/cameras/visor_cameras.gd): layout (mapa, vista, alvos),
## escolher e o clique, o acompanhamento de pendências, as peças hospedadas, os renders e a palavra sem
## tradução. No fim põe o visor na árvore e deixa desenhar uns quadros, para o _draw rodar de verdade.
## Roda com: godot --headless --path . --script tests/test_visor_cameras.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Visor := preload("res://scripts/cameras/visor_cameras.gd")
const Prancha := preload("res://scripts/prancha.gd")
const Desenho := preload("res://scripts/desenho.gd")

const AREA := Rect2(90, 42, 534, 272)
const AREA_MENOR := Rect2(120, 60, 400, 220)
const AREA_BAIXA := Rect2(0, 0, 534, 200)  # a vista de 16:9 passaria da altura: o limite manda

var falhas := 0
var total := 0


## Peça falsa: grava o que recebeu em configurar.
class Falsa extends Control:
	signal concluido
	var area := Rect2()
	var duracao := -1.0
	var poeira := false
	var chamadas := 0

	func configurar(a: Rect2, d: float, p: bool) -> void:
		area = a
		duracao = d
		poeira = p
		chamadas += 1
		position = a.position
		size = a.size

	func progresso() -> float:
		return 0.5


func _init() -> void:
	_rodar_tudo()


func _rodar_tudo() -> void:
	for area in [AREA, AREA_MENOR]:
		_layout(area)
		_escolher(area)
		_pendencias(area)
		_hospedar(area)
	_layout_com_limite_de_altura()
	_renders()
	_palavra()
	_contraste_do_mapa()
	_botoes_sem_verde()
	await _desenha_na_arvore()
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)


func _igual(obtido, esperado, nome: String) -> void:
	total += 1
	var bate := false
	if (obtido is float or obtido is int) and (esperado is float or esperado is int):
		bate = absf(float(obtido) - float(esperado)) < 1e-6
	else:
		bate = obtido == esperado
	if not bate:
		falhas += 1
		printerr("FALHOU: %s (obtido %s, esperado %s)" % [nome, str(obtido), str(esperado)])


func _verdade(valor: bool, nome: String) -> void:
	_igual(valor, true, nome)


func _novo(area: Rect2, duracao: float = 60.0, poeira: bool = false) -> Control:
	var v: Control = Visor.new()
	v.configurar(area, duracao, poeira)
	return v


func _contador(v: Control, sinal: String) -> Array:
	var contagem := [0]
	v.connect(sinal, func(): contagem[0] += 1)
	return contagem


func _layout(area: Rect2) -> void:
	var rot := "[%dx%d] " % [int(area.size.x), int(area.size.y)]
	var v := _novo(area)
	_igual(v.position, area.position, rot + "a posição vem da área")
	_igual(v.size, area.size, rot + "o tamanho vem da área")
	var local := Rect2(Vector2.ZERO, area.size)
	var mapa: Rect2 = v.retangulo_mapa()
	var vista: Rect2 = v.retangulo_vista()
	_verdade(local.encloses(mapa), rot + "o mapa cabe na área")
	_verdade(local.encloses(vista), rot + "a vista cabe na área")
	_verdade(not mapa.intersects(vista), rot + "mapa e vista não se sobrepõem")
	_verdade(absf(vista.size.x * 9.0 / 16.0 - vista.size.y) <= 1.0, rot + "a vista é 16:9")
	var al: Dictionary = v.alvos()
	_igual(al.size(), 4, rot + "quatro alvos")
	for c in Visor.CAMERAS:
		_verdade(al.has(c), rot + "alvo de " + c)
		var r: Rect2 = al[c]
		_verdade(r.size.x >= 24.0 and r.size.y >= 24.0, rot + "alvo grande o bastante: " + c)
		_verdade(mapa.encloses(r), rot + "alvo dentro do mapa: " + c)
		_verdade(not r.intersects(vista), rot + "alvo fora da vista: " + c)
	for i in Visor.CAMERAS.size():
		for j in range(i + 1, Visor.CAMERAS.size()):
			var a: Rect2 = al[Visor.CAMERAS[i]]
			var b: Rect2 = al[Visor.CAMERAS[j]]
			_verdade(not a.intersects(b), rot + "alvos não se sobrepõem: %s e %s" % [Visor.CAMERAS[i], Visor.CAMERAS[j]])
			_verdade(not a.grow(Visor.FOLGA_ALVO).intersects(b.grow(Visor.FOLGA_ALVO)),
				rot + "a folga de acerto não invade o vizinho: %s e %s" % [Visor.CAMERAS[i], Visor.CAMERAS[j]])
	if area == AREA:
		_igual(mapa, Rect2(0, 0, 160, 272), "534x272: mapa 160x272")
		_igual(vista, Rect2(166, 0, 368, 207), "534x272: vista 368x207")
	v.free()


func _layout_com_limite_de_altura() -> void:
	var v := _novo(AREA_BAIXA)
	var mapa: Rect2 = v.retangulo_mapa()
	var vista: Rect2 = v.retangulo_vista()
	_verdade(vista.size.y <= AREA_BAIXA.size.y - Visor.TELEM_H - Visor.GAP, "com pouca altura, a vista respeita o limite")
	_verdade(absf(vista.size.x * 9.0 / 16.0 - vista.size.y) <= 1.0, "com pouca altura, a vista segue 16:9")
	_igual(mapa.end.x + Visor.GAP, vista.position.x, "o mapa cresce e ocupa a sobra")
	_igual(vista.end.x, AREA_BAIXA.size.x, "a vista vai até a borda da direita")
	for c in Visor.CAMERAS:
		_verdade(mapa.encloses(v.alvos()[c]), "com pouca altura, alvo dentro do mapa: " + c)
	v.free()


func _escolher(area: Rect2) -> void:
	var rot := "[%dx%d] " % [int(area.size.x), int(area.size.y)]
	var v := _novo(area)
	var nomes := []
	v.camera_escolhida.connect(func(n): nomes.append(n))
	_igual(v.camera_atual(), "visao_geral", rot + "começa na visão geral")
	_igual(v.escolher("rocha"), true, rot + "escolher rocha")
	_igual(v.camera_atual(), "rocha", rot + "a atual vira rocha")
	_igual(nomes, ["rocha"], rot + "emite camera_escolhida")
	_igual(v.escolher("rocha"), true, rot + "escolher a mesma de novo")
	_igual(nomes, ["rocha", "rocha"], rot + "a mesma câmera emite de novo")
	_igual(v.escolher("ceu"), false, rot + "nome inválido devolve falso")
	_igual(v.camera_atual(), "rocha", rot + "nome inválido não muda nada")
	_igual(nomes.size(), 2, rot + "nome inválido não emite")
	# Um clique no centro de cada alvo escolhe aquela câmera.
	for c in Visor.CAMERAS:
		nomes.clear()
		v._gui_input(_clique((v.alvos()[c] as Rect2).get_center()))
		_igual(v.camera_atual(), c, rot + "o clique escolhe " + c)
		_igual(nomes, [c], rot + "o clique emite " + c)
	# Perto, mas fora: a folga de 4 px acerta, 6 px não.
	nomes.clear()
	var r: Rect2 = v.alvos()["moxie"]
	v._gui_input(_clique(Vector2(r.end.x + 3.0, r.get_center().y)))
	_igual(nomes, ["moxie"], rot + "a folga de acerto de 4 px")
	nomes.clear()
	v._gui_input(_clique(Vector2(r.end.x + 6.0, r.get_center().y)))
	_igual(nomes, [], rot + "fora da folga não escolhe")
	# Só o botão esquerdo, e só ao apertar.
	var ev := _clique((v.alvos()["painel"] as Rect2).get_center())
	ev.button_index = MOUSE_BUTTON_RIGHT
	v._gui_input(ev)
	ev = _clique((v.alvos()["painel"] as Rect2).get_center())
	ev.pressed = false
	v._gui_input(ev)
	_igual(nomes, [], rot + "botão direito e soltar não escolhem")
	# Movimento só guarda o hover e não escolhe.
	var mov := InputEventMouseMotion.new()
	mov.position = (v.alvos()["painel"] as Rect2).get_center()
	v._gui_input(mov)
	_igual(nomes, [], rot + "mover não escolhe")
	v.free()


func _clique(p: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = p
	return ev


func _pendencias(area: Rect2) -> void:
	var rot := "[%dx%d] " % [int(area.size.x), int(area.size.y)]
	var v := _novo(area)
	var fim := _contador(v, "concluido")
	_igual(v.progresso(), 0.0, rot + "sem pendência, progresso 0")
	v.pendencias({})
	_igual(v.progresso(), 0.0, rot + "mapa vazio, progresso 0")
	_igual(fim[0], 0, rot + "mapa vazio não conclui")
	v.pendencias({"rocha": true, "moxie": true})
	_igual(v.progresso(), 0.0, rot + "duas pendentes: 0")
	v.pendencias({"rocha": false, "moxie": true})
	_igual(v.progresso(), 0.5, rot + "uma feita: 0,5")
	_igual(fim[0], 0, rot + "ainda não concluiu")
	v.pendencias({"rocha": false, "moxie": false})
	_igual(v.progresso(), 1.0, rot + "as duas feitas: 1")
	_igual(fim[0], 1, rot + "concluiu")
	v.pendencias({"rocha": false, "moxie": false})
	v.pendencias({"rocha": false, "moxie": false})
	_igual(fim[0], 1, rot + "concluido sai uma vez só, mesmo com chamadas repetidas")
	# Chave desconhecida é ignorada: não entra no acompanhamento nem conclui.
	v.configurar(area, 60.0, false)
	_igual(v.progresso(), 0.0, rot + "configurar zera o progresso")
	v.pendencias({"ceu": true})
	_igual(v.progresso(), 0.0, rot + "chave desconhecida é ignorada")
	v.pendencias({"ceu": false})
	_igual(fim[0], 1, rot + "chave desconhecida não conclui")
	# Novo configurar permite novo concluido.
	v.pendencias({"painel": true, "ceu": true})
	v.pendencias({"painel": false})
	_igual(v.progresso(), 1.0, rot + "depois do configurar, de novo 1")
	_igual(fim[0], 2, rot + "novo configurar permite novo concluido")
	# Uma câmera lembrada que volta a ficar pendente baixa o progresso, e concluir de novo não repete.
	v.pendencias({"painel": true})
	_igual(v.progresso(), 0.0, rot + "voltou a ficar pendente")
	v.pendencias({"painel": false})
	_igual(fim[0], 2, rot + "já concluiu nesta configuração: não repete")
	v.free()


func _hospedar(area: Rect2) -> void:
	var rot := "[%dx%d] " % [int(area.size.x), int(area.size.y)]
	var v := _novo(area, 75.0, false)
	var fim := _contador(v, "concluido")
	var a := Falsa.new()
	v.hospedar("moxie", a)
	_igual(a.get_parent(), v, rot + "a peça vira filha do visor")
	_igual(a.chamadas, 1, rot + "a peça recebe configurar")
	_igual(a.area, v.retangulo_vista(), rot + "com a área da vista")
	_igual(a.duracao, 75.0, rot + "com a duração")
	_igual(a.poeira, false, rot + "com o clima")
	_igual(v.peca("moxie"), a, rot + "peca() devolve a hospedada")
	_igual(v.peca("rocha"), null, rot + "peca() sem peça: null")
	_igual(a.visible, false, rot + "invisível enquanto a câmera dela não é a atual")
	v.escolher("moxie")
	_igual(a.visible, true, rot + "visível com a câmera dela escolhida")
	v.escolher("rocha")
	_igual(a.visible, false, rot + "some ao escolher outra")
	v.escolher("moxie")
	# Outra peça na mesma câmera: a antiga sai e é liberada.
	var b := Falsa.new()
	v.hospedar("moxie", b)
	_verdade(a.is_queued_for_deletion(), rot + "a antiga foi liberada")
	_verdade(a.get_parent() == null, rot + "a antiga saiu do visor")
	_igual(v.peca("moxie"), b, rot + "a nova é a hospedada")
	_igual(b.visible, true, rot + "a nova nasce visível na câmera atual")
	# Peça numa câmera que não é a atual nasce invisível.
	var c := Falsa.new()
	v.hospedar("painel", c)
	_igual(c.visible, false, rot + "peça de outra câmera nasce invisível")
	# Câmera inválida é recusada.
	var d := Falsa.new()
	v.hospedar("ceu", d)
	_verdade(d.get_parent() == null, rot + "câmera inválida: a peça não entra")
	_igual(v.peca("ceu"), null, rot + "câmera inválida: nada guardado")
	d.free()
	# null tira e libera.
	v.hospedar("painel", null)
	_verdade(c.is_queued_for_deletion(), rot + "null libera a peça")
	_igual(v.peca("painel"), null, rot + "null deixa a câmera sem peça")
	# Reconfigurar reconfigura as hospedadas, com a nova área e o novo clima.
	var nova := Rect2(10, 20, 400, 220)
	v.configurar(nova, 30.0, true)
	_igual(b.chamadas, 2, rot + "configurar reconfigura a peça")
	_igual(b.area, v.retangulo_vista(), rot + "com a nova vista")
	_igual(b.duracao, 30.0, rot + "com a nova duração")
	_igual(b.poeira, true, rot + "com poeira")
	_igual(v.position, nova.position, rot + "o visor foi para a nova área")
	# O concluido da peça não mexe no progresso: quem hospeda é quem avisa.
	v.pendencias({"moxie": true})
	b.concluido.emit()
	_igual(v.progresso(), 0.0, rot + "o concluido da peça não mexe no progresso")
	_igual(fim[0], 0, rot + "nem faz o visor concluir")
	v.pendencias({"moxie": false})
	_igual(fim[0], 1, rot + "quem hospeda chama pendencias")
	v.free()
	# Os liberados com queue_free só somem no fim do quadro; no teste, libera na mão o que sobrou.
	for p in [a, c]:
		if is_instance_valid(p):
			p.free()


func _no_minimo(a: Color, b: Color, minimo: float, nome: String) -> void:
	var c := Prancha.contraste(a, b)
	_verdade(c >= minimo, "%s: %.2f:1 (mínimo %.1f)" % [nome, c, minimo])


## O contraste de cada par do mapa e da telemetria, como o _draw os pinta (WCAG): texto >= 4,5:1; traço, forma e
## borda que dizem algo >= 3:1. As superfícies do mapa são o fundo (FUNDO_MAPA) e a cunha ativa (CAIXA), que vai por
## baixo das formas. A grade do papel fica fora da conta.
func _contraste_do_mapa() -> void:
	_igual(Prancha.FUNDO_MAPA, Color("#0c1f38"), "o fundo do mapa é #0c1f38")
	_verdade(Prancha.luminancia(Prancha.FUNDO_MAPA) < Prancha.luminancia(Prancha.FUNDO), "o fundo do mapa é mais escuro que o papel")
	for par in [["o fundo do mapa", Prancha.FUNDO_MAPA], ["a cunha ativa", Prancha.CAIXA]]:
		var fundo: Color = par[1]
		var onde: String = par[0]
		# Texto: o rótulo da escala e o "N" (TEXTO_SUAVE, 10 px).
		_no_minimo(Desenho.TEXTO_SUAVE, fundo, 4.5, "rótulo da escala e N sobre " + onde)
		# Forma e traço: monte, habitat, painéis, rocha, MOXIE e tanques (Prancha.BORDA); rover, bússola, escala e
		# contornos das formas (TEXTO_SUAVE); estratos e cunhas das outras câmeras (TEXTO_SUAVE com alfa); cunha atual.
		_no_minimo(Prancha.BORDA, fundo, 3.0, "monte, habitat, painéis, rocha, MOXIE e a borda do mapa sobre " + onde)
		_no_minimo(Desenho.TEXTO_SUAVE, fundo, 3.0, "rover, bússola, escala e contornos sobre " + onde)
		_no_minimo(fundo.blend(Color(Desenho.TEXTO_SUAVE, Visor.ALFA_ESTRATO)), fundo, 3.0, "estratos do monte sobre " + onde)
		_no_minimo(fundo.blend(Color(Desenho.TEXTO_SUAVE, Visor.ALFA_CUNHA)), fundo, 3.0, "linhas das câmeras fora de foco sobre " + onde)
		_no_minimo(Desenho.TEXTO, fundo, 3.0, "linhas da câmera atual sobre " + onde)
		_no_minimo(Desenho.TEXTO, fundo, 3.0, "anel e chevron de pendência sobre " + onde)
	# A borda do mapa também encosta no papel, por fora.
	_no_minimo(Prancha.BORDA, Prancha.FUNDO, 3.0, "borda do mapa sobre o papel")
	# Chips da telemetria: texto e ícone TEXTO sobre o fundo do chip; borda sobre o chip e sobre o papel.
	_no_minimo(Desenho.TEXTO, Prancha.FUNDO_MAPA, 4.5, "números e palavras dos chips sobre o chip")
	_no_minimo(Prancha.BORDA, Prancha.FUNDO_MAPA, 3.0, "borda dos chips sobre o chip")
	_no_minimo(Prancha.BORDA, Prancha.FUNDO, 3.0, "borda dos chips sobre o papel")
	# A borda da vista: o anel de 2 px entre o aro escuro de fora e o papel.
	_no_minimo(Prancha.BORDA, Desenho.MOLDURA, 3.0, "borda da vista sobre o aro")
	_no_minimo(Prancha.BORDA, Prancha.FUNDO, 3.0, "borda da vista sobre o papel")
	# Botões: o contorno e o ícone de cada estado sobre o fundo que o _draw usa (cores do próprio visor).
	var v: Control = _novo(AREA)
	var normal: Array = v._cores_do_botao("painel")  # a atual é a visão geral; o mouse está longe
	v._mouse = (v.alvos()["painel"] as Rect2).get_center()
	var hover: Array = v._cores_do_botao("painel")
	var atual: Array = v._cores_do_botao(v.camera_atual())
	v.free()
	for par in [["normal", normal], ["hover", hover], ["atual", atual]]:
		var estado: String = par[0]
		var fundo: Color = par[1][0]
		_no_minimo(Prancha.LINHA, fundo, 3.0, "botão %s: contorno sobre o fundo" % estado)
		_no_minimo(par[1][1], fundo, 4.5, "botão %s: ícone sobre o fundo" % estado)
		_no_minimo(Prancha.LINHA, Prancha.FUNDO_MAPA, 3.0, "botão %s: contorno sobre o mapa" % estado)
		_no_minimo(Prancha.LINHA, Prancha.CAIXA, 3.0, "botão %s: contorno sobre a cunha" % estado)
	_igual(normal[0], Prancha.FUNDO_MAPA.blend(Prancha.BTN_FUNDO), "botão normal: BTN_FUNDO")
	_igual(hover[0], Prancha.FUNDO_MAPA.blend(Prancha.BTN_FUNDO_HOVER), "botão em hover: BTN_FUNDO_HOVER")
	_igual(atual[0], Prancha.FUNDO_MAPA.blend(Prancha.BTN_FUNDO_ATIVO), "botão da câmera atual: BTN_FUNDO_ATIVO")
	_igual(atual[1], Prancha.BTN_TEXTO_ATIVO, "botão da câmera atual: ícone BTN_TEXTO_ATIVO")


## Sem verde nos botões: nenhum estado usa uma cor da família verde do Desenho (regra [R] de cores da spec).
func _botoes_sem_verde() -> void:
	var v: Control = _novo(AREA)
	var verdes := [Desenho.VERDE, Desenho.VERDE_ESCURO, Desenho.VERDE_CLARO]
	for c in Visor.CAMERAS:
		v._mouse = (v.alvos()[c] as Rect2).get_center()
		for cam in Visor.CAMERAS:
			for cor: Color in v._cores_do_botao(cam):
				_verdade(not verdes.has(cor), "botão %s com o ponteiro em %s: sem verde" % [cam, c])
	v.free()


func _renders() -> void:
	for c in Visor.CAMERAS:
		for clima in ["normal", "poeira"]:
			var caminho := "res://assets/exterior/%s_%s.png" % [c, clima]
			_verdade(load(caminho) != null, "o render carrega: " + caminho)


func _palavra() -> void:
	_igual(Visor.palavra("CHAVE_QUE_NAO_EXISTE"), "", "chave sem tradução: vazio")
	_igual(Visor.palavra("CAM_PAINEL") == "CAM_PAINEL", false, "nunca devolve a chave crua")


## O _draw só roda com o visor na árvore: põe um, com pendência, sol, peça e o clima de poeira, e deixa
## passar uns quadros. Um erro de script no _draw aparece no log e derruba o teste.
func _desenha_na_arvore() -> void:
	var v := _novo(AREA, 60.0, true)
	root.add_child(v)
	v.sol(3, 5)
	v.pendencias({"rocha": true, "moxie": true})
	v.hospedar("painel", Falsa.new())
	await process_frame
	await process_frame
	v.escolher("rocha")
	await process_frame
	v.escolher("painel")
	await process_frame
	v._gui_input(_clique((v.alvos()["rocha"] as Rect2).get_center()))
	_igual(v.camera_atual(), "rocha", "na árvore: o clique escolhe")
	v.configurar(AREA_MENOR, 60.0, false)
	await process_frame
	v.queue_free()
	await process_frame
