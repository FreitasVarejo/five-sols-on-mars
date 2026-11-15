extends SceneTree
## Teste headless da viagem Terra -> Marte (scripts/abertura/viagem.gd): `concluida` emitida uma vez só ao
## fim (e nunca antes), o toque e o "Pular" só valendo depois de 1,5 s, o som do clique, o dia da viagem do
## Curiosity (0 a 254), os passos do registro, a chama e as estrelas abaixo de 3 piscadas por segundo e o
## texto: toda chave VIAGEM_* em inglês e português, com no máximo 8 palavras por frase.
## Roda com: godot --headless --path . --script tests/test_viagem.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Viagem := preload("res://scripts/abertura/viagem.gd")
const Abertura := preload("res://scripts/abertura/abertura.gd")
const CSV := "res://textos/textos.csv"

var falhas := 0
var total := 0
var emitidos := 0


class SomFalso:
	extends RefCounted
	var tocados: Array = []

	func tocar(nome: String) -> void:
		tocados.append(nome)


func _init() -> void:
	TranslationServer.set_locale("en")
	_fim_emite_uma_vez()
	_pular_so_depois_de_1_5_s()
	_pular_pelo_botao_e_pelo_toque()
	_som()
	_dia()
	_passos()
	_nada_pisca_demais()
	_botao_igual_ao_da_abertura()
	_textos()
	_chaves_no_csv()
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)


func _igual(obtido, esperado, nome: String) -> void:
	total += 1
	var bate := false
	if (obtido is float or obtido is int) and (esperado is float or esperado is int):
		bate = absf(float(obtido) - float(esperado)) < 1e-4
	else:
		bate = obtido == esperado
	if not bate:
		falhas += 1
		printerr("FALHOU: %s (obtido %s, esperado %s)" % [nome, str(obtido), str(esperado)])


func _verdade(cond: bool, nome: String) -> void:
	_igual(cond, true, nome)


func _contar() -> void:
	emitidos += 1


## Uma viagem de 640x360 que conta as emissões de `concluida`.
func _nova() -> Viagem:
	var v := Viagem.new()
	v.size = Vector2(640, 360)
	emitidos = 0
	v.concluida.connect(_contar)
	return v


## Passa `s` segundos em passos de 0,1 s.
func _passa(v: Viagem, s: float) -> void:
	var resta := s
	while resta > 1e-6:
		var d := minf(0.1, resta)
		v.avancar(d)
		resta -= d


func _clique(v: Viagem, pos: Vector2 = Vector2(320, 180)) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = pos
	v._gui_input(e)
	e = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	e.position = pos
	v._gui_input(e)


func _toque(v: Viagem, pos: Vector2 = Vector2(320, 180)) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = true
	e.position = pos
	v._gui_input(e)


func _fim_emite_uma_vez() -> void:
	var v := _nova()
	_passa(v, Viagem.DURACAO + Viagem.POUSO_S - 0.2)
	_igual(emitidos, 0, "não emite antes do fim do pouso")
	_verdade(not v.ja_concluiu(), "ainda não concluiu")
	_passa(v, 0.3)
	_igual(emitidos, 1, "emite ao fim")
	_verdade(v.ja_concluiu(), "ja_concluiu depois do fim")
	_passa(v, 5.0)
	_igual(emitidos, 1, "continuar passando o tempo não emite de novo")
	_clique(v)
	_igual(emitidos, 1, "o toque depois do fim não emite de novo")
	_igual(v.progresso(), 1.0, "o progresso para em 1")
	v.free()
	# Um passo grande atravessa o fim e emite uma vez só.
	var g := _nova()
	g.avancar(30.0)
	_igual(emitidos, 1, "um passo de 30 s emite uma vez")
	g.free()


func _pular_so_depois_de_1_5_s() -> void:
	var v := _nova()
	_verdade(not v.pode_pular(), "no começo não pode pular")
	_clique(v)
	_toque(v)
	_igual(emitidos, 0, "toque no começo não pula")
	_passa(v, 1.4)
	_clique(v)
	_igual(emitidos, 0, "toque antes de 1,5 s não pula")
	_verdade(not v.pular(), "pular() antes de 1,5 s devolve falso")
	_igual(Viagem.PULAR_APOS_S, 1.5, "o toque vale depois de 1,5 s")
	_passa(v, 0.2)
	_verdade(v.pode_pular(), "depois de 1,5 s pode pular")
	_clique(v)
	_igual(emitidos, 1, "toque depois de 1,5 s pula")
	_clique(v)
	_toque(v)
	_igual(emitidos, 1, "pular emite uma vez só")
	_verdade(not v.pode_pular(), "depois de concluir não pode pular")
	v.free()


func _pular_pelo_botao_e_pelo_toque() -> void:
	var v := _nova()
	_passa(v, 2.0)
	_clique(v, v.rect_pular().get_center())
	_igual(emitidos, 1, "o botão Pular pula")
	v.free()
	var t := _nova()
	_passa(t, 2.0)
	_toque(t)
	_igual(emitidos, 1, "um toque de dedo pula")
	t.free()
	# Botão direito e solto não contam.
	var d := _nova()
	_passa(d, 2.0)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = true
	d._gui_input(e)
	e = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	d._gui_input(e)
	_igual(emitidos, 0, "botão direito e soltar não pulam")
	d.free()


func _som() -> void:
	var s := SomFalso.new()
	var v := _nova()
	v.som = s
	_passa(v, 2.0)
	_clique(v)
	_clique(v)
	_igual(s.tocados, ["clique_confirmar"], "pular faz o clique de confirmar, uma vez")
	v.free()
	var f := SomFalso.new()
	var w := _nova()
	w.som = f
	_passa(w, 9.0)
	_igual(emitidos, 1, "o fim emite")
	_igual(f.tocados.size(), 0, "o fim da viagem não faz som")
	w.free()


func _dia() -> void:
	var v := _nova()
	_igual(v.dia(), 0, "dia 0 no começo")
	var anterior := -1
	var cresce := true
	for i in 70:
		v.avancar(0.1)
		if v.dia() < anterior:
			cresce = false
		anterior = v.dia()
	_verdade(cresce, "o dia nunca volta")
	_igual(v.dia(), 254, "dia 254 no pouso")
	_igual(Viagem.DIAS, 254, "a viagem do Curiosity: 254 dias")
	# 26/11/2011 a 06/08/2012.
	var dias := (Time.get_unix_time_from_datetime_string("2012-08-06") - Time.get_unix_time_from_datetime_string("2011-11-26")) / 86400
	_igual(dias, 254, "de 26/11/2011 a 06/08/2012 são 254 dias")
	TranslationServer.set_locale("en")
	_igual(v.texto_do_dia(), "Day 254 of 254 · like Curiosity, landed in Gale", "linha do dia em inglês")
	TranslationServer.set_locale("pt")
	_igual(v.texto_do_dia(), "Dia 254 de 254 · como o Curiosity, que pousou em Gale", "linha do dia em português")
	TranslationServer.set_locale("en")
	v.free()


func _passos() -> void:
	var v := _nova()
	_igual(Viagem.PASSOS.size(), 7, "7 passos")
	_igual(v.passos_visiveis(0.0), 1, "no começo, 1 passo à vista")
	_igual(v.passos_feitos(0.0), 0, "no começo, nenhum feito")
	_igual(v.passos_feitos(0.07), 1, "o primeiro ganha o visto logo")
	_igual(v.passos_visiveis(0.5), 4, "na metade, 4 à vista")
	_igual(v.passos_visiveis(0.99), 7, "perto do fim, 7 à vista")
	_igual(v.passos_feitos(0.99), 6, "perto do fim, o último ainda em curso")
	_igual(v.passos_feitos(1.0), 7, "no pouso, todos feitos")
	var ordem := true
	for i in range(1, Viagem.PASSOS.size()):
		if Viagem.PASSOS[i][0] <= Viagem.PASSOS[i - 1][0]:
			ordem = false
	_verdade(ordem, "os passos entram em ordem")
	v.free()


func _nada_pisca_demais() -> void:
	# Spec: no máximo 3 flashes por segundo. A chama é sin(2 pi f t): uma oscilação por período.
	_verdade(Viagem.CHAMA_HZ <= 3.0, "a chama oscila a no máximo 3 Hz (%s)" % Viagem.CHAMA_HZ)
	# Uma estrela é |sin(w t)|: w / pi piscadas por segundo (o w mais alto é CINTILAR_MAX_RAD).
	_verdade(Viagem.CINTILAR_MAX_RAD / PI <= 3.0, "o cintilar das estrelas passa de 3 por segundo")
	# O flash do pouso é um só e dura menos de 1 s.
	_verdade(Viagem.FLASH_S < Viagem.POUSO_S, "o flash acaba antes de a viagem concluir")


func _botao_igual_ao_da_abertura() -> void:
	TranslationServer.set_locale("en")
	var v := _nova()
	var a := Abertura.new()
	a.size = Vector2(640, 360)
	_igual(v.rect_pular(), a.rect_pular(), "o Pular tem o lugar e o tamanho do da abertura")
	var r := v.rect_pular()
	_verdade(r.size.x >= 24.0 and r.size.y >= 24.0, "alvo de pelo menos 24x24")
	_verdade(Rect2(Vector2.ZERO, v.size).encloses(r), "o Pular está dentro da tela")
	v.free()
	a.free()


func _palavras(frase: String) -> int:
	var n := 0
	for w in frase.split(" ", false):
		if w != "·":
			n += 1
	return n


func _textos() -> void:
	for lang in ["en", "pt"]:
		TranslationServer.set_locale(lang)
		for chave: String in Viagem.CHAVES:
			var s := TranslationServer.translate(chave)
			_verdade(s != chave and s != "", "%s existe em %s" % [chave, lang])
			# No máximo 8 palavras por frase: o ponto médio separa as duas frases da linha do dia.
			for parte in s.split("·"):
				for f in Abertura.frases(parte.strip_edges()):
					_verdade(_palavras(f) <= 8, "%s (%s): no máximo 8 palavras: '%s'" % [chave, lang, f])
	TranslationServer.set_locale("en")


## O CSV tem as chaves VIAGEM_ da peça, nem mais nem menos, cada uma com inglês e português preenchidos.
func _chaves_no_csv() -> void:
	var f := FileAccess.open(CSV, FileAccess.READ)
	_verdade(f != null, "abre o CSV de textos")
	if f == null:
		return
	var achadas: Array = []
	while not f.eof_reached():
		var linha := f.get_csv_line()
		if linha.size() >= 3 and linha[0].begins_with("VIAGEM_"):
			achadas.append(linha[0])
			_verdade(linha[1] != "" and linha[2] != "", "%s: en e pt preenchidos no CSV" % linha[0])
	achadas.sort()
	var esperadas := Viagem.CHAVES.duplicate()
	esperadas.sort()
	_igual(achadas, esperadas, "o CSV tem exatamente as chaves VIAGEM_ da peça")
