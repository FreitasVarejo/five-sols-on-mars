extends Control
## Cena de teste do diário do terminal (scripts/terminal.gd, aba do diário): monta o fim do sol com o
## registro que se pede e salva a tela. Sem main.tscn.
## Roda com: godot --path . res://tests/cena_diario.tscn -- --capturar=<pasta> [--lang=pt|en]
## (sem --lang, os dois idiomas). Cada captura sai em 640x360 e ampliada 3x (nearest).
## Casos: "pior_sol2" (o pior caso real da missão fixa: tempestade sem abrigo, aviso da Terra, três tarefas
## não feitas e energia perdida no teto), "sol1" (um sol calmo normal) e "extremo" (tudo junto, o que a
## agenda da missão fixa nunca junta: tempestade, poeira, gerador quebrado e aviso).

const Terminal := preload("res://scripts/terminal.gd")
const Missao := preload("res://scripts/missao.gd")
const Modelo := preload("res://scripts/modelo.gd")

const PASTA_PADRAO := "/home/freitaspinhe/Pictures/five-sols-on-mars/diario-historia/"

## nome -> [sol, o que mudar no registro]
const CASOS := {
	"sol1": [1, {}],
	"pior_sol2": [2, {"abrigou": false, "dose": 12.0, "f_exposto": 0.5, "nao_feitas": ["chemcam", "amostra", "planta"],
		"perdida_no_teto": 6.0}],
	"extremo": [1, {"tempestade": true, "abrigou": false, "dose": 12.0, "f_exposto": 0.5, "poeira": true,
		"nao_feitas": ["chemcam", "amostra", "planta"], "perdida_no_teto": 6.0, "gerador_quebrado": true,
		"consertou": false, "aviso": true}],
}


func _ready() -> void:
	var pasta := PASTA_PADRAO
	var langs: Array[String] = ["pt", "en"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturar="):
			pasta = arg.trim_prefix("--capturar=").path_join("")
		elif arg.begins_with("--lang="):
			langs = [arg.trim_prefix("--lang=")]
	DirAccess.make_dir_recursive_absolute(pasta)
	for lang in langs:
		TranslationServer.set_locale(lang)
		for nome in CASOS:
			var t := _terminal(CASOS[nome][0], CASOS[nome][1])
			add_child(t)
			await get_tree().process_frame
			await get_tree().process_frame
			await _salvar("%s%s_%s" % [pasta, nome, lang])
			remove_child(t)
			t.free()
	get_tree().quit()


## Um terminal no fim do sol `sol_n`, com o registro do sol mudado pelo que `mudar` pede.
func _terminal(sol_n: int, mudar: Dictionary) -> Control:
	var m := Missao.new(1, {"turno_s": 2.0})
	m.montar_sol(sol_n, Modelo.estado_inicial())
	m.confirmar_plano()
	var guarda := 0
	while m.fase == "turno" and guarda < 200:
		m.abrigar()
		m.avancar(0.1)
		guarda += 1
	m.registros[0].merge(mudar, true)
	m.registros[0]["aviso"] = m.registros[0]["aviso"] or m.aviso_ativo()
	var t: Control = Terminal.new()
	t.iniciar(m, {})
	return t


func _salvar(base: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(base + ".png")
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(base + "_x3.png")
	print("%s (%dx%d)" % [base, img.get_width(), img.get_height()])
