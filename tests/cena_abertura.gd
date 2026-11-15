extends Control
## Cena de teste da abertura (scripts/abertura/abertura.gd): hospeda a peça em tela cheia e, só aqui,
## registra em código as strings da seção 3 do briefing da abertura (em inglês e português), porque a
## tabela do jogo (textos/textos.csv) só ganha essas chaves na parte B.
## Roda com display, para jogar com mouse ou toque: godot --path . res://tests/cena_abertura.tscn
## Capturas: godot --path . res://tests/cena_abertura.tscn -- --capturar=<pasta> [--lang=pt|en]
## (sem --lang, os dois idiomas). O tempo passa por `avancar`, não pelo relógio.

const Abertura := preload("res://scripts/abertura/abertura.gd")

const PASTA_PADRAO := "/home/freitaspinhe/Pictures/five-sols-on-mars/abertura/"

## chave -> [inglês, português]
const TEXTOS := {
	"ABERTURA_ROLAR": ["scroll", "role"],
	"ABERTURA_1_TITULO": ["Mars. Gale Crater.", "Marte. Cratera Gale."],
	"ABERTURA_1_A": ["This small base is yours.", "Esta pequena base é sua."],
	"ABERTURA_1_B": ["You are the commander.", "Você é o comandante."],
	"ABERTURA_2_A": ["Your crew lives inside.", "Sua tripulação mora aqui dentro."],
	"ABERTURA_2_B": ["Outside, there is no air to breathe.", "Lá fora, não há ar para respirar."],
	"ABERTURA_2_C": ["On Mars, a day is called a sol.", "Em Marte, um dia se chama sol."],
	"ABERTURA_O2_ROTULO": ["Oxygen", "Oxigênio"],
	"ABERTURA_O2_A": ["Your crew breathes it every sol.", "A tripulação respira oxigênio todo sol."],
	"ABERTURA_O2_B": ["This machine makes it from Mars air.", "Esta máquina faz oxigênio do ar de Marte."],
	"ABERTURA_O2_C": ["The machine needs energy to work.", "A máquina precisa de energia para funcionar."],
	"ABERTURA_EN_ROTULO": ["Energy", "Energia"],
	"ABERTURA_EN_A": ["Solar panels charge the battery.", "Os painéis solares carregam a bateria."],
	"ABERTURA_EN_B": ["Mars nights are very cold.", "As noites de Marte são muito frias."],
	"ABERTURA_EN_C": ["Heaters use energy every night. No energy, no oxygen.",
		"O aquecedor gasta energia toda noite. Sem energia, sem oxigênio."],
	"ABERTURA_RAD_ROTULO": ["Radiation", "Radiação"],
	"ABERTURA_RAD_A": ["Sometimes the Sun throws out storms.", "Às vezes, o Sol solta tempestades."],
	"ABERTURA_RAD_B": ["Fast, invisible particles reach the base.", "Partículas rápidas e invisíveis chegam à base."],
	"ABERTURA_RAD_C": ["Too much radiation makes the crew sick.", "Radiação demais deixa a tripulação doente."],
	"ABERTURA_RAD_D": ["This bar never fills back up.", "Esta barra nunca enche de novo."],
	"ABERTURA_CI_ROTULO": ["Science", "Ciência"],
	"ABERTURA_CI_A": ["Scientists on Earth ask for experiments.", "Cientistas na Terra pedem experimentos."],
	"ABERTURA_CI_B": ["Their messages take minutes to arrive.", "As mensagens levam minutos para chegar."],
	"ABERTURA_CI_C": ["Experiments use energy too.", "Experimentos também gastam energia."],
	"ABERTURA_CI_D": ["Every choice has a cost.", "Toda escolha tem um custo."],
	"ABERTURA_PR_NAVE": ["SHIP", "NAVE"],
	"ABERTURA_PR_LIVRE": ["FREE", "LIVRE"],
	"ABERTURA_PR_A": ["In 5 sols, a ship arrives.", "Em 5 sóis, uma nave chega."],
	"ABERTURA_PR_B": ["It takes your science to Earth.", "Ela leva sua ciência para a Terra."],
	"ABERTURA_PR_C": ["Each sol: plan, work, report.", "Cada sol: planejar, trabalhar, relatar."],
	"ABERTURA_PR_D": ["Real NASA data · May 2024", "Dados reais da NASA · maio de 2024"],
	"ABERTURA_FIM_A": ["Keep the base alive.", "Mantenha a base viva."],
	"ABERTURA_FIM_B": ["Send science home.", "Mande ciência para casa."],
	"ABERTURA_FIM_BOTAO": ["Start mission", "Começar a missão"],
	"ABERTURA_PULAR": ["Skip", "Pular"],
	"SOL_N": ["Sol %d", "Sol %d"],
}

var _abertura: Abertura


## Registra as strings acima como duas Translation (en e pt) no TranslationServer. Estática: o teste usa.
static func registrar_textos() -> void:
	for i in 2:
		var t := Translation.new()
		t.locale = "en" if i == 0 else "pt"
		for chave in TEXTOS:
			t.add_message(chave, TEXTOS[chave][i])
		TranslationServer.add_translation(t)


func _ready() -> void:
	registrar_textos()
	var pasta := ""
	var langs: Array[String] = ["en", "pt"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturar="):
			pasta = arg.trim_prefix("--capturar=").path_join("")
		elif arg == "--capturar":
			pasta = PASTA_PADRAO
		elif arg.begins_with("--lang="):
			langs = [arg.trim_prefix("--lang=")]
	_abertura = Abertura.new()
	_abertura.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_abertura)
	_abertura.concluida.connect(func() -> void: print("concluida emitido"))
	if pasta == "":
		TranslationServer.set_locale(langs[0])
		return
	DirAccess.make_dir_recursive_absolute(pasta)
	_abertura.set_process(false)
	for lang in langs:
		TranslationServer.set_locale(lang)
		for q in Abertura.N_QUADROS:
			_abertura.definir_rolagem(q * _abertura.size.y)
			_abertura.avancar(0.45)  # a seta do quadro 1 num ponto do balanço que se vê
			await _salvar("%sq%d_%s.png" % [pasta, q + 1, lang])
		# No meio de uma rolagem: o quadro 4 a 40% do caminho para o 5.
		_abertura.definir_rolagem(3.4 * _abertura.size.y)
		await _salvar("%srolagem_%s.png" % [pasta, lang])
	get_tree().quit()


func _salvar(caminho: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(caminho)
	print("%s (%dx%d)" % [caminho, img.get_width(), img.get_height()])
