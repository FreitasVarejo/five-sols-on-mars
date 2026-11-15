extends Control
## Cena de teste da viagem (scripts/abertura/viagem.gd): hospeda a peça em tela cheia. As strings vêm da
## tabela do jogo (textos/textos.csv, chaves VIAGEM_*).
## Roda com display: godot --path . res://tests/cena_viagem.tscn
## Capturas: godot --path . res://tests/cena_viagem.tscn -- --capturar=<pasta> [--lang=pt|en]
## (sem --lang, os dois idiomas; três momentos: começo, meio e pouso). O tempo passa por `avancar`.

const Viagem := preload("res://scripts/abertura/viagem.gd")

const PASTA_PADRAO := "/home/freitaspinhe/Pictures/five-sols-on-mars/pecas-do-primo/viagem/"

## Os momentos das capturas: nome -> segundo da viagem.
const MOMENTOS := {"comeco": 0.6, "meio": 3.6, "pouso": 7.2}

var _viagem: Viagem


func _ready() -> void:
	var pasta := ""
	var langs: Array[String] = ["en", "pt"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturar="):
			pasta = arg.trim_prefix("--capturar=").path_join("")
		elif arg == "--capturar":
			pasta = PASTA_PADRAO
		elif arg.begins_with("--lang="):
			langs = [arg.trim_prefix("--lang=")]
	if pasta == "":
		TranslationServer.set_locale(langs[0])
		_viagem = _nova()
		_viagem.concluida.connect(func() -> void: print("concluida emitido"))
		return
	DirAccess.make_dir_recursive_absolute(pasta)
	for lang in langs:
		TranslationServer.set_locale(lang)
		_viagem = _nova()
		_viagem.set_process(false)
		for momento in MOMENTOS:
			# Anda em passos curtos: a viagem não depende do tamanho do passo, mas o flash e o fim sim.
			while _viagem.tempo() < MOMENTOS[momento] - 0.001:
				_viagem.avancar(minf(0.1, MOMENTOS[momento] - _viagem.tempo()))
			await _salvar("%s%s_%s.png" % [pasta, momento, lang])
		_viagem.queue_free()
	get_tree().quit()


func _nova() -> Viagem:
	var v := Viagem.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	return v


func _salvar(caminho: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(caminho)
	print("%s (%dx%d)" % [caminho, img.get_width(), img.get_height()])
