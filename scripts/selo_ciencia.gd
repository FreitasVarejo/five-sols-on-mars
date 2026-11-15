extends RefCounted
## O selo "+N" de ciência: aparece quando uma tarefa de ciência termina. É só o ícone de ciência e o número que
## a tarefa rendeu, sem palavra nenhuma, porque o turno não tem texto para ler (por isso, e só por isso, ele
## pode sumir sozinho). Entra com o movimento do primo (scripts/movimento_aviso.gd), sobe e some em ~1,5 s.
##
## Cores neutras de Desenho (nada de verde, vermelho, amarelo nem azul: [R] da spec). O terminal chama
## `desenhar` no fim do quadro, com o desenho em coordenadas de tela (sem a transformação do terminal).
##
## Onde fica: perto das notificações do canto superior esquerdo (o HUD do turno), logo abaixo delas, quando o
## terminal está embaixo; com o terminal no alto o HUD some e as teclas ocupam o canto, então o selo fica na
## faixa de baixo, ao lado do alerta do medidor e longe do botão TERMINAL. Nos dois lugares, não cobre o
## medidor nem as barras do cabeçalho (x 284 a 624, y 12 a 36).

const Desenho := preload("res://scripts/desenho.gd")
const Mov := preload("res://scripts/movimento_aviso.gd")

const ALTURA := 22.0
const ORIGEM_HUD := Vector2(6.0, 42.0)       # embaixo dos chips do HUD do turno (y 6 a 28), no canto
const ORIGEM_FAIXA := Vector2(50.0, 334.0)   # com o terminal no alto: faixa de baixo, depois do alerta
const ICONE := 16.0


## O lugar do selo em repouso (canto superior esquerdo do chip).
static func origem(terminal_no_alto: bool) -> Vector2:
	return ORIGEM_FAIXA if terminal_no_alto else ORIGEM_HUD


static func rotulo(n: int) -> String:
	return "+%d" % n


## O tamanho do chip: o ícone, o número e os espaços.
static func tamanho(n: int) -> Vector2:
	return Vector2(ICONE + 21.0 + Desenho.largura_texto(rotulo(n), 15, true), ALTURA)


## O retângulo do chip em `t` (já com a subida), em px de tela; vazio depois que o selo some.
static func retangulo(n: int, t: float, terminal_no_alto: bool) -> Rect2:
	if Mov.selo_alfa(t) <= 0.0:
		return Rect2()
	return Rect2(origem(terminal_no_alto) + Vector2(0.0, Mov.selo_dy(t)), tamanho(n))


## Desenha o selo de `n` pontos de ciência, nascido há `t` segundos. Devolve o retângulo que ocupou (vazio se
## já sumiu). Deixa a transformação do desenho na identidade.
static func desenhar(ci: CanvasItem, n: int, t: float, terminal_no_alto: bool) -> Rect2:
	var r := retangulo(n, t, terminal_no_alto)
	if r.size.x <= 0.0:
		return r
	var a := Mov.selo_alfa(t)
	var s := Mov.escala(t)
	var c := r.get_center()
	ci.draw_set_transform_matrix(Transform2D.IDENTITY.translated(-c).scaled(Vector2(s, s)).translated(c))
	ci.draw_rect(r, Color(Desenho.NOITE, 0.85 * a))
	ci.draw_rect(r, Color(Desenho.BORDA, a), false, 1.0)
	ci.draw_rect(Rect2(r.position.x + 1.0, r.position.y + 1.0, r.size.x - 2.0, 1.0), Color(Desenho.TEXTO, 0.12 * a))
	Desenho.icone(ci, "ciencia", Rect2(r.position.x + 6.0, r.position.y + (ALTURA - ICONE) / 2.0, ICONE, ICONE),
		Color(Desenho.TEXTO, a), Desenho.NOITE)
	Desenho.texto(ci, rotulo(n), Vector2(r.position.x + 6.0 + ICONE + 6.0, r.position.y + 3.0), 15,
		Color(Desenho.TEXTO, a), -1.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	return r
