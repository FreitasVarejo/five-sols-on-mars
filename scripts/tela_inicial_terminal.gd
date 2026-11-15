extends RefCounted
## A tela inicial do terminal: blocos grandes (o maior é a ação da fase, os outros quatro são as abas) que a
## criança vê ao abrir o plano e o fim do sol, antes de entrar numa tela. Cada aba traz uma linha que diz para
## que ela serve e uma linha de estado ao vivo, tirada da missão (nada inventado).
##
## Aqui moram a geometria e os textos (funções puras, testadas em tests/test_tela_inicial_terminal.gd). Quem
## desenha e trata o clique é o terminal.gd (`_desenhar_inicio`, `_sair_do_inicio`).
##
## Coordenadas da tela de 640x360, dentro do corpo do terminal com teclas (x 90 a 624, y 42 a 314).

const X0 := 90.0
const X1 := 624.0
const FASE := Rect2(90.0, 46.0, 534.0, 92.0)  # o bloco da ação da fase
const ABA_W := 263.0
const ABA_H := 76.0
const ABAS := ["cameras", "tarefas", "diario", "fontes"]  # na ordem das teclas da moldura
const FASES := ["plano", "fim_do_sol"]  # onde a tela inicial aparece (nunca no turno)


## A tela inicial vale nesta fase?
static func vale_na_fase(fase: String) -> bool:
	return fase in FASES


## O retângulo de cada bloco: "fase" e uma entrada por aba, numa grade de 2 por 2.
static func blocos() -> Dictionary:
	var d := {"fase": FASE}
	for i in ABAS.size():
		var x := X0 + (ABA_W + 8.0) * (i % 2)
		var y := FASE.end.y + 8.0 + (ABA_H + 8.0) * (i / 2)
		d[ABAS[i]] = Rect2(x, y, ABA_W, ABA_H)
	return d


static func _tr(chave: String) -> String:
	return TranslationServer.translate(chave)


## O título do bloco da fase: "Planejar o sol N" no plano, "Fechar o sol N" no fim do sol.
static func titulo_da_fase(fase: String, sol: int) -> String:
	return _tr("INICIO_FASE_FIM" if fase == "fim_do_sol" else "INICIO_FASE_PLANO") % sol


static func dica_da_fase(fase: String) -> String:
	return _tr("INICIO_DICA_FASE_FIM" if fase == "fim_do_sol" else "INICIO_DICA_FASE_PLANO")


## A linha que diz para que serve a aba (no máximo 8 palavras).
static func dica_da_aba(aba: String) -> String:
	return _tr("INICIO_DICA_" + aba.to_upper())


## A linha de estado ao vivo da aba. `m` é a Missao; `dado_atual` diz se o dado recente da NASA está no jogo.
static func estado_da_aba(aba: String, fase: String, m, dado_atual: bool) -> String:
	match aba:
		"cameras":
			return _tr("INICIO_ST_POEIRA" if m.eh_poeira() else "INICIO_ST_LIMPO")
		"tarefas":
			if fase == "fim_do_sol":
				var feitas := 0
				for nome in m.tarefas:
					if m.tarefas[nome] == "feita":
						feitas += 1
				return _tr("INICIO_ST_TAREFAS_FIM") % [feitas, m.tarefas.size()]
			return _tr("INICIO_ST_TAREFAS_PLANO") % m.lista_do_turno().size()
		"diario":
			return _tr("INICIO_ST_DIARIO") % [m.registros.size(), 5]
		"fontes":
			return _tr("INICIO_ST_FONTES_ATUAL" if dado_atual else "INICIO_ST_FONTES_HIST")
	return ""
