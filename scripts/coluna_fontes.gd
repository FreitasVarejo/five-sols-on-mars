extends Control
## A coluna "de onde vêm os números" da aba fontes, quando a lista não cabe na caixa: um filho do terminal
## que recorta (clip_contents) e rola. Só existe à vista nesse caso (terminal.gd liga e desliga). Quem
## desenha a lista é o terminal (terminal._desenhar_coluna), com o mesmo _par_fonte de quando ela cabe;
## aqui ficam o valor da rolagem e a entrada.
##
## Entrada, no jeito da abertura (scripts/abertura/abertura.gd): roda do mouse (passo fixo), arrasto com o
## botão esquerdo e arrasto de um dedo. O conteúdo acompanha o dedo 1:1, sem inércia nem encaixe, preso entre
## 0 e `maximo`. O gesto pertence à fonte que o abriu ("mouse" ou "toque"); a outra é ignorada enquanto ele
## dura (no Web o toque chega também como mouse emulado). Só vale com o terminal parado no alto e sem card
## (terminal._coluna_aceita).

## A rolagem mudou: o terminal se redesenha (e manda este nó redesenhar).
signal rolou

const PASSO_RODA := 24.0
const GESTO_VELHO_MS := 1500  # um gesto parado há tanto tempo perde a posse para a outra fonte

var terminal: Control       # quem desenha a lista e diz se aceita gesto
var rolagem := 0.0          # px que a lista subiu
var maximo := 0.0           # até onde ela rola (altura da lista − altura visível)

var _fonte := ""            # "", "mouse" ou "toque": quem abriu o gesto em curso
var _g_ultimo := Vector2.ZERO
var _g_ultimo_ms := 0


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _draw() -> void:
	if terminal != null:
		terminal._desenhar_coluna(self)


## Volta ao alto e larga o gesto em curso (a aba mudou).
func zerar() -> void:
	rolagem = 0.0
	_fonte = ""


## Novo limite de rolagem (a lista ou o idioma mudou): a rolagem não passa dele.
func limitar(novo_maximo: float) -> void:
	maximo = novo_maximo
	rolagem = clampf(rolagem, 0.0, maximo)


func _mover(delta: float) -> void:
	var nova := clampf(rolagem + delta, 0.0, maximo)
	if nova != rolagem:
		rolagem = nova
		rolou.emit()


func _aceita() -> bool:
	return terminal != null and terminal._coluna_aceita()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN or mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			if mb.pressed and _aceita():
				_mover(PASSO_RODA if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -PASSO_RODA)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_gesto_inicio("mouse", mb.position)
			else:
				_gesto_fim("mouse")
			accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _fonte == "mouse" and not (mm.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_gesto_fim("mouse")  # o botão foi solto fora e o soltar não chegou
		else:
			_gesto_move("mouse", mm.position)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.index == 0:
			if st.pressed:
				_gesto_inicio("toque", st.position)
			else:
				_gesto_fim("toque")
			accept_event()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == 0:
			_gesto_move("toque", sd.position)


## No Web o toque chega como ScreenTouch e também como mouse emulado: o gesto pertence à fonte que o
## abriu, e a outra, enquanto ele dura, é ignorada. Assim o mesmo arrasto não conta duas vezes.
func _gesto_inicio(fonte: String, pos: Vector2) -> void:
	if _fonte != "" and _fonte != fonte and Time.get_ticks_msec() - _g_ultimo_ms < GESTO_VELHO_MS:
		return
	if not _aceita():
		_fonte = ""
		return
	_fonte = fonte
	_g_ultimo = pos
	_g_ultimo_ms = Time.get_ticks_msec()


func _gesto_move(fonte: String, pos: Vector2) -> void:
	if _fonte != fonte or not _aceita():
		return
	_g_ultimo_ms = Time.get_ticks_msec()
	_mover(_g_ultimo.y - pos.y)  # o conteúdo acompanha o dedo: o dedo sobe, a lista sobe
	_g_ultimo = pos


func _gesto_fim(fonte: String) -> void:
	if _fonte == fonte:
		_fonte = ""
