extends Control
## Cena de conferência do visor de câmeras (scripts/cameras/visor_cameras.gd), fora do jogo: imita o corpo
## do terminal e põe o visor nele, com uma peça falsa na câmera do MOXIE.
## Interativa: godot --path . tests/cena_visor_cameras.tscn
## Captura:    godot --path . tests/cena_visor_cameras.tscn -- --capturar=<pasta>
## (sem --headless: precisa de tela). Grava as cinco vistas em 640x360 e em x3, e sai.

const Desenho := preload("res://scripts/desenho.gd")
const Visor := preload("res://scripts/cameras/visor_cameras.gd")

const CORPO := Rect2(80, 6, 554, 316)
const AREA := Rect2(90, 42, 534, 272)
const AREA_MENOR := Rect2(120, 60, 400, 220)

var _visor: Control
var _falsa: Control


## Peça falsa: um painel semitransparente com um círculo verde grande; tocar nele conclui.
class Toque extends Control:
	signal concluido
	var _poeira := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func configurar(area: Rect2, _duracao: float, poeira: bool) -> void:
		position = area.position
		size = area.size
		_poeira = poeira
		queue_redraw()

	func progresso() -> float:
		return 0.0

	func _centro() -> Vector2:
		return (size / 2.0).round()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(Desenho.NOITE, 0.7))
		draw_circle(_centro(), 24.0, Desenho.VERDE_ESCURO)
		draw_circle(_centro(), 21.0, Desenho.VERDE)
		var rot := "toque aqui"
		var larg := Desenho.largura_texto(rot, 12, true)
		Desenho.texto(self, rot, Vector2(_centro().x - larg / 2.0, _centro().y + 32.0), 12, Desenho.TEXTO, -1.0,
			HORIZONTAL_ALIGNMENT_LEFT, true)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			if ev.position.distance_to(_centro()) <= 28.0:
				accept_event()
				concluido.emit()


func _ready() -> void:
	_visor = Visor.new()
	add_child(_visor)
	_visor.configurar(AREA, 60.0, false)
	_visor.sol(3, 5)
	_falsa = Toque.new()
	_visor.hospedar("moxie", _falsa)
	_falsa.concluido.connect(_ao_tocar)
	_pendentes()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capturar="):
			_capturar(a.trim_prefix("--capturar="))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Desenho.NOITE)
	draw_rect(CORPO, Desenho.FUNDO_TERMINAL)
	draw_rect(CORPO, Desenho.BORDA, false, 1.0)


func _pendentes() -> void:
	_visor.pendencias({"rocha": true, "moxie": true})


func _ao_tocar() -> void:
	_visor.pendencias({"rocha": true, "moxie": false})


func _quadros(n: int = 4) -> void:
	for i in n:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _salvar(pasta: String, nome: String) -> void:
	await _quadros()
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [pasta, nome])
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s_x3.png" % [pasta, nome])
	print("capturada: %s (%dx%d)" % [nome, img.get_width() / 3, img.get_height() / 3])


func _capturar(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	await _salvar(pasta, "01_visao_geral_normal")
	_visor.configurar(AREA, 60.0, true)
	_pendentes()
	_visor.escolher("rocha")
	await _salvar(pasta, "02_rocha_poeira")
	_visor.escolher("moxie")
	await _salvar(pasta, "03_moxie_peca_hospedada")
	_visor.configurar(AREA, 60.0, false)
	_visor.pendencias({"rocha": false, "moxie": false})
	_visor.escolher("painel")
	await _salvar(pasta, "04_painel_normal")
	_visor.configurar(AREA_MENOR, 60.0, false)
	_pendentes()
	_visor.escolher("rocha")
	await _salvar(pasta, "05_area_menor")
	get_tree().quit()
