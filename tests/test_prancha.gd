extends SceneTree
## Teste headless da aparência de prancha do terminal (scripts/prancha.gd): o contraste de cada par de cores
## usado no terminal (texto >= 4,5:1, elemento gráfico >= 3:1), a conta do contraste e o lugar do selo.
## Roda com: godot --headless --path . --script tests/test_prancha.gd
## Sai com código 1 se algo falhar e imprime cada falha.

const Prancha := preload("res://scripts/prancha.gd")
const Desenho := preload("res://scripts/desenho.gd")

var falhas := 0
var total := 0


func _init() -> void:
	_conta()
	_contraste_do_texto()
	_contraste_dos_graficos()
	_selo()
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


func _no_minimo(a: Color, b: Color, minimo: float, nome: String) -> void:
	var c := Prancha.contraste(a, b)
	_verdade(c >= minimo, "%s: %.2f:1 (mínimo %.1f)" % [nome, c, minimo])


func _conta() -> void:
	_igual(Prancha.contraste(Color.WHITE, Color.BLACK), 21.0, "contraste: branco sobre preto é 21:1")
	_igual(Prancha.contraste(Color.WHITE, Color.WHITE), 1.0, "contraste: igual é 1:1")
	_igual(Prancha.contraste(Color.BLACK, Color.WHITE), 21.0, "contraste: a ordem não importa")
	# Os números medidos no briefing (fundo #122a4a): vermelho 3,9, energia 5,2, suave 7,1; card da Terra 6,9.
	_verdade(absf(Prancha.contraste(Desenho.VERMELHO, Prancha.FUNDO) - 3.9) < 0.05, "contraste: vermelho sobre o fundo, 3,9")
	_verdade(absf(Prancha.contraste(Desenho.ENERGIA, Prancha.FUNDO) - 5.23) < 0.05, "contraste: energia sobre o fundo, 5,2")
	_verdade(absf(Prancha.contraste(Desenho.TEXTO_SUAVE, Prancha.FUNDO) - 7.07) < 0.05, "contraste: suave sobre o fundo, 7,1")
	_verdade(absf(Prancha.contraste(Desenho.AZUL, Prancha.FUNDO) - 6.89) < 0.05, "contraste: card da Terra sobre o fundo, 6,9")
	_igual(Prancha.FUNDO, Color("#122a4a"), "o fundo é o azul-marinho #122a4a")
	_igual(Prancha.FUNDO_MAPA, Color("#0c1f38"), "o fundo do mapa das câmeras é #0c1f38")
	_verdade(Prancha.luminancia(Prancha.FUNDO_MAPA) < Prancha.luminancia(Prancha.FUNDO), "o fundo do mapa é mais escuro que o papel")


## Todo texto do terminal, sobre o fundo da tela e sobre as caixas.
func _contraste_do_texto() -> void:
	for par in [["FUNDO", Prancha.FUNDO], ["CAIXA", Prancha.CAIXA]]:
		var fundo: Color = par[1]
		var onde: String = par[0]
		_no_minimo(Desenho.TEXTO, fundo, 4.5, "texto sobre " + onde)
		_no_minimo(Desenho.TEXTO_SUAVE, fundo, 4.5, "texto suave sobre " + onde)
		_no_minimo(Desenho.AMARELO, fundo, 4.5, "amarelo de alerta (texto) sobre " + onde)
		_no_minimo(Prancha.VERMELHO_TEXTO, fundo, 4.5, "vermelho de alerta (texto) sobre " + onde)
		_no_minimo(Desenho.AZUL, fundo, 4.5, "azul da Terra (texto no diário) sobre " + onde)
		_no_minimo(Desenho.VERDE, fundo, 4.5, "verde (texto do cartão desligado) sobre " + onde)
	_no_minimo(Prancha.SELO_TEXTO, Prancha.CAIXA, 4.5, "texto do selo sobre a caixa")
	_no_minimo(Desenho.TEXTO_ESCURO, Desenho.AZUL, 4.5, "texto escuro sobre o card da Terra")
	_no_minimo(Desenho.TEXTO_ESCURO, Desenho.VERDE, 4.5, "texto escuro sobre o botão verde (sala e cards da Terra)")
	_no_minimo(Desenho.TEXTO_ESCURO, Desenho.VERDE_CLARO, 4.5, "texto escuro sobre o botão verde em hover")
	_botoes_da_prancha()


## Os botões do painel (estilo do primo): cada estado, sobre o fundo da tela e sobre as caixas. Texto >= 4,5:1 sobre o
## fundo do botão (a camada translúcida somada ao que está embaixo) e contorno >= 3:1 sobre esse fundo. O desligado
## fica de fora da regra (WCAG): só confere que o texto dele segue legível e que o contorno é mais fraco que o do ligado.
func _botoes_da_prancha() -> void:
	for par in [["FUNDO", Prancha.FUNDO], ["CAIXA", Prancha.CAIXA]]:
		var base: Color = par[1]
		var onde: String = par[0]
		var estados := {
			"normal": [Prancha.BTN_FUNDO, Desenho.TEXTO],
			"hover": [Prancha.BTN_FUNDO_HOVER, Desenho.TEXTO],
			"apertado ou selecionado": [Prancha.BTN_FUNDO_ATIVO, Prancha.BTN_TEXTO_ATIVO],
		}
		for estado: String in estados:
			var fundo := base.blend(estados[estado][0])
			_no_minimo(estados[estado][1], fundo, 4.5, "botão %s: texto sobre %s" % [estado, onde])
			_no_minimo(Prancha.BTN_CONTORNO, fundo, 3.0, "botão %s: contorno sobre o próprio fundo (%s)" % [estado, onde])
		_no_minimo(Prancha.BTN_CONTORNO, base, 3.0, "botão: contorno sobre %s" % onde)
		var desab := base.blend(Prancha.BTN_DESAB_FUNDO)
		_no_minimo(Prancha.DESAB_TEXTO, desab, 4.5, "botão desligado: texto sobre " + onde)
		_verdade(Prancha.contraste(base.blend(Prancha.BTN_DESAB_CONTORNO), base) < Prancha.contraste(Prancha.BTN_CONTORNO, base),
			"botão desligado: contorno mais apagado que o do ligado (%s)" % onde)
	_igual(Prancha.BTN_LARG, 2.0, "o contorno do botão é de 2 px")
	_verdade(Prancha.BTN_LARG_DESTAQUE > Prancha.BTN_LARG, "a ação principal tem contorno maior")


## Elementos gráficos: ícones e células dos recursos, o vermelho e o amarelo de alerta, as linhas e as bordas.
func _contraste_dos_graficos() -> void:
	for par in [["FUNDO", Prancha.FUNDO], ["CAIXA", Prancha.CAIXA]]:
		var fundo: Color = par[1]
		var onde: String = par[0]
		_no_minimo(Desenho.ENERGIA, fundo, 3.0, "energia sobre " + onde)
		_no_minimo(Desenho.OXIGENIO, fundo, 3.0, "oxigênio sobre " + onde)
		_no_minimo(Desenho.RADIACAO, fundo, 3.0, "radiação sobre " + onde)
		_no_minimo(Desenho.VERMELHO, fundo, 3.0, "vermelho de alerta (moldura e ícone) sobre " + onde)
		_no_minimo(Desenho.AMARELO, fundo, 3.0, "amarelo de alerta (ícone) sobre " + onde)
		_no_minimo(Prancha.BORDA, fundo, 3.0, "borda das caixas sobre " + onde)
		_no_minimo(Prancha.LINHA, fundo, 3.0, "borda externa sobre " + onde)
		_no_minimo(Desenho.AZUL, fundo, 3.0, "borda do card da Terra sobre " + onde)
		_no_minimo(Desenho.TEXTO, fundo, 3.0, "ícone claro sobre " + onde)
	_no_minimo(Prancha.LINHA, Prancha.MOLDURA, 3.0, "a borda externa sobre o aro")
	# O compartimento vazio das células não carrega informação sozinho (o N/12 ao lado repete o que a barra mostra).
	_verdade(Prancha.contraste(Prancha.CELULA_VAZIA, Prancha.CAIXA) < 3.0, "a célula vazia é só um compartimento, mais apagada que a cheia")
	for cor: Color in [Desenho.ENERGIA, Desenho.OXIGENIO, Desenho.RADIACAO]:
		_verdade(Prancha.contraste(cor, Prancha.CELULA_VAZIA) >= 3.0, "a célula cheia se distingue da vazia")


func _selo() -> void:
	var tela := Rect2(80, 6, 554, 316)
	_igual(Prancha.retangulo_do_selo(tela, ""), Rect2(), "selo: sem texto, sem retângulo")
	for texto in ["SHEET 01 · GALE · SOL 5", "PRANCHA 01 · GALE · SOL 5"]:
		var s := Prancha.retangulo_do_selo(tela, texto)
		_verdade(s.size.x > 60.0 and s.size.y >= Prancha.SELO_TAM + 2, "selo: cabe o texto de 9 px: " + texto)
		_verdade(s.position.y >= 314.0, "selo: abaixo do corpo (y >= 314), sem cobrir aba, barra nem texto")
		_verdade(s.end.y <= 328.0, "selo: acima da faixa do botão de mudo (y 328)")
		_verdade(s.end.x <= tela.end.x, "selo: dentro da largura da tela")
