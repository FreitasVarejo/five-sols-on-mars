extends Control
## Cena de captura do minigame do ChemCam: hospeda a peça numa área como a de uma aba de câmera do
## terminal e roda um roteiro determinístico (o tempo passa por `avancar`, não pelo relógio), salvando
## PNGs do viewport em `_pasta` com o prefixo "chemcam_".
## Roda com display: godot --path . res://tests/cena_chemcam.tscn
## Um clima só: godot --path . res://tests/cena_chemcam.tscn -- poeira   (ou: -- normal)
## Outra pasta de saída: ... -- --pasta=/caminho/da/pasta/

const Desenho := preload("res://scripts/desenho.gd")
const ChemCam := preload("res://scripts/minigames/chemcam.gd")

const PASTA_PADRAO := "/home/freitaspinhe/Pictures/five-sols-on-mars/noite-15-11/"
const AREA := Rect2(24, 40, 420, 236)
const DURACAO := 10.0

var _peca: ChemCam
var _pasta := PASTA_PADRAO


func _ready() -> void:
	var climas: Array[String] = ["normal", "poeira"]
	for arg in OS.get_cmdline_user_args():
		if arg in climas:
			climas = [arg]
		elif arg.begins_with("--pasta="):
			_pasta = arg.trim_prefix("--pasta=").path_join("")
	DirAccess.make_dir_recursive_absolute(_pasta)
	for clima in climas:
		await _roteiro(clima)
	get_tree().quit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Desenho.FUNDO_TERMINAL)
	Desenho.moldura(self, AREA.grow(2.0), Desenho.BORDA, 2.0)
	draw_rect(Rect2(AREA.position.x - 2.0, AREA.end.y + 6.0, AREA.size.x + 4.0, 3.0), Desenho.BORDA)


func _roteiro(clima: String) -> void:
	if _peca != null:
		_peca.queue_free()
	_peca = ChemCam.new()
	add_child(_peca)
	_peca.set_process(false)  # o tempo passa só por avancar(): captura determinística
	_peca.configurar(AREA, DURACAO, clima == "poeira")
	var a := _peca.alvos_na_area()
	await _salvar("%s_1_inicio" % clima)
	# A mira passa perto do 1º alvo e gruda.
	_peca.apontar(a[0] + Vector2(14, -10))
	await _salvar("%s_2_mira_grudada" % clima)
	# Toca o 1º, e durante o disparo o 2º e o 3º entram na fila.
	_peca.tocar(a[0])
	_peca.avancar(0.5)
	_peca.apontar(a[1])
	_peca.tocar(a[1])
	_peca.avancar(0.2)
	_peca.apontar(a[2])
	_peca.tocar(a[2])
	_peca.apontar(a[3] + Vector2(-12, 14))
	_peca.avancar(0.45)
	await _salvar("%s_3_disparo_com_fila" % clima)
	if clima == "poeira":
		return
	_peca.apontar(a[3])
	_peca.tocar(a[3])
	_peca.avancar(4.45)  # 5,6 s: o último disparo está quase no fim
	await _salvar("%s_4_quase_no_fim" % clima)
	_peca.avancar(0.5)
	await _salvar("%s_5_concluido" % clima)


func _salvar(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var caminho := _pasta + "chemcam_%s.png" % nome
	img.save_png(caminho)
	print("%s (%dx%d)  progresso %.3f" % [caminho, img.get_width(), img.get_height(), _peca.progresso()])
