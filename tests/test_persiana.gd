extends SceneTree
## Teste headless da persiana (scripts/persiana.gd e os PNGs de scripts/gerar_persiana.py).
## Roda com: godot --headless --path . --script tests/test_persiana.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Persiana := preload("res://scripts/persiana.gd")
const COMODO := "res://assets/comodo/"
const N_LAMINAS_ESPERADAS := 10

var falhas := 0
var total := 0


func _init() -> void:
	_laminas_por_progresso()
	_duracao_da_url()
	_imagens()
	print("%d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)


func _igual(obtido, esperado, nome: String) -> void:
	total += 1
	if obtido != esperado:
		falhas += 1
		printerr("FALHOU: %s (obtido %s, esperado %s)" % [nome, str(obtido), str(esperado)])


func _laminas_por_progresso() -> void:
	# Fechar: a lâmina k aparece em p = k/10; a décima só no fim.
	_igual(Persiana.laminas_visiveis(0.0, true), 0, "fechando 0")
	_igual(Persiana.laminas_visiveis(0.099, true), 0, "fechando 0,099")
	_igual(Persiana.laminas_visiveis(0.1, true), 1, "fechando 0,1")
	_igual(Persiana.laminas_visiveis(0.55, true), 5, "fechando 0,55")
	_igual(Persiana.laminas_visiveis(0.999, true), 9, "fechando 0,999")
	_igual(Persiana.laminas_visiveis(1.0, true), 10, "fechando 1")
	# Abrir: com p = 1 aparecem as 10; a décima some logo abaixo de 1 e a primeira só em p = 0.
	_igual(Persiana.laminas_visiveis(1.0, false), 10, "abrindo 1")
	_igual(Persiana.laminas_visiveis(0.95, false), 10, "abrindo 0,95")
	_igual(Persiana.laminas_visiveis(0.9, false), 9, "abrindo 0,9")
	_igual(Persiana.laminas_visiveis(0.05, false), 1, "abrindo 0,05")
	_igual(Persiana.laminas_visiveis(0.0, false), 0, "abrindo 0")
	# Dez batidas: de 0 a 1 o contador passa por todos os valores de 0 a 10.
	var vistos := {}
	for i in 1001:
		vistos[Persiana.laminas_visiveis(i / 1000.0, true)] = true
	_igual(vistos.size(), 11, "fechando passa por 0 a 10")


func _duracao_da_url() -> void:
	_igual(Persiana.duracao_da_url(null), 1.5, "sem parâmetro")
	_igual(Persiana.duracao_da_url("1.0"), 1.0, "1,0")
	_igual(Persiana.duracao_da_url("2"), 2.0, "2")
	_igual(Persiana.duracao_da_url("0.5"), 0.5, "limite baixo")
	_igual(Persiana.duracao_da_url("3.0"), 3.0, "limite alto")
	_igual(Persiana.duracao_da_url("0.2"), 1.5, "abaixo do limite")
	_igual(Persiana.duracao_da_url("9"), 1.5, "acima do limite")
	_igual(Persiana.duracao_da_url("abc"), 1.5, "texto")


func _carregar(nome: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(COMODO + nome))


## A camada sobre o abrigo aberto refaz o abrigo.png original, e o índice tem as 10 lâminas.
func _imagens() -> void:
	var normal := _carregar("normal.png")
	var abrigo := _carregar("abrigo.png")
	var aberto := _carregar("abrigo_aberto.png")
	var camada := _carregar("persiana.png")
	var indice := _carregar("persiana_indice.png")
	for img: Image in [normal, abrigo, aberto, camada]:
		img.convert(Image.FORMAT_RGBA8)
	indice.convert(Image.FORMAT_RGBA8)
	var larg := normal.get_width()
	var alt := normal.get_height()
	var diferentes := 0
	var vidro := 0
	var laminas := {}
	for y in alt:
		for x in larg:
			var e_vidro := normal.get_pixel(x, y).a == 0.0
			var refeito := camada.get_pixel(x, y) if camada.get_pixel(x, y).a > 0.0 else aberto.get_pixel(x, y)
			if refeito != abrigo.get_pixel(x, y):
				diferentes += 1
			if e_vidro:
				vidro += 1
				laminas[roundi(indice.get_pixel(x, y).r8 / 20.0 - 0.5)] = true
			elif camada.get_pixel(x, y).a != 0.0 or aberto.get_pixel(x, y).a == 0.0 or indice.get_pixel(x, y).r8 != 255:
				diferentes += 1
	_igual(diferentes, 0, "camada + abrigo aberto refazem o abrigo")
	_igual(vidro, 58318, "pixels de vidro")
	_igual(laminas.size(), N_LAMINAS_ESPERADAS, "lâminas no índice")

