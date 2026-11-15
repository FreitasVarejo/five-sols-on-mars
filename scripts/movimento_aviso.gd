extends RefCounted
## O movimento dos avisos pop-up: funções puras de tempo (segundos desde que o aviso apareceu) em
## deslocamento, escala, tremor e flash. Quem desenha (terminal.gd) aplica o resultado.
##
## Port do movimento do banner da versão do primo (`_show_banner`): entrada com TRANS_BACK/EASE_OUT em 0,3 s, escala de 0,7 a 1 com TRANS_ELASTIC/EASE_OUT em
## 0,35 s e, no alerta, 6 tremidas de 0,05 s. As curvas são as do próprio Tween do Godot (Tween.interpolate_value),
## as mesmas que a versão dele usa. O resto do banner dele (fundo que pisca, sumir sozinho, cobrir o HUD, verde de
## sucesso) não entra: ver o briefing.
##
## A tela do primo tem 1280 px de largura e a nossa, 640: as distâncias em px valem a metade.

const ENTRADA_S := 0.3          # o deslocamento (TRANS_BACK, EASE_OUT)
const ESCALA_S := 0.35          # a escala (TRANS_ELASTIC, EASE_OUT)
const ESCALA_INICIAL := 0.7
## A entrada inteira acaba quando as duas curvas acabam.
const DURACAO_ENTRADA_S := 0.35

const TREMOR_N := 6             # tremidas, como as do primo
const TREMOR_PASSO_S := 0.05    # cada tremida
const TREMOR_AMPLITUDE := 7.0   # ±14 px na tela de 1280 do primo, ±7 na de 640
## 6 tremidas e a volta ao repouso.
const DURACAO_TREMOR_S := TREMOR_PASSO_S * (TREMOR_N + 1)

const FLASH_S := 0.4            # um flash só, curto
const FLASH_ALFA := 0.3         # translúcido: no pico, 30% de vermelho sobre a tela

const SELO_S := 1.5             # o selo "+N ciência" sobe e some neste tempo
const SELO_SOBE := 10.0         # quanto ele sobe, em px, depois de entrar
const SELO_ENTRA := 14.0        # de quantos px abaixo ele entra
const SELO_FADE_S := 0.4        # some nos últimos 0,4 s


static func _t(t: float, ate: float) -> float:
	return clampf(t, 0.0, ate)


## De 0 a 1 (e um pouco além de 1, o overshoot do TRANS_BACK): quanto do caminho a entrada já andou.
static func progresso_da_entrada(t: float) -> float:
	return Tween.interpolate_value(0.0, 1.0, _t(t, ENTRADA_S), ENTRADA_S, Tween.TRANS_BACK, Tween.EASE_OUT)


## O deslocamento em x de um card que entra pela esquerda e anda `distancia` px até o lugar: começa em
## -distancia (fora), passa um pouco do lugar (overshoot, positivo) e termina em 0.
static func deslocamento(t: float, distancia: float) -> float:
	return -distancia * (1.0 - progresso_da_entrada(t))


## A escala do aviso: de 0,7 a 1, elástica (passa de 1 e volta).
static func escala(t: float) -> float:
	return Tween.interpolate_value(ESCALA_INICIAL, 1.0 - ESCALA_INICIAL, _t(t, ESCALA_S), ESCALA_S,
		Tween.TRANS_ELASTIC, Tween.EASE_OUT)


## A entrada acabou (deslocamento e escala parados no lugar)?
static func entrada_terminou(t: float) -> bool:
	return t >= DURACAO_ENTRADA_S


## A transformação do card em `t`: escala `escala(t)` em torno de `pivo` e deslocamento em x. Com `t` depois
## da entrada, é a identidade. `pivo` e `distancia` são em px da tela.
static func transformacao(t: float, pivo: Vector2, distancia: float) -> Transform2D:
	var s := escala(t)
	return Transform2D.IDENTITY.translated(-pivo).scaled(Vector2(s, s)).translated(pivo + Vector2(deslocamento(t, distancia), 0.0))


## O tremor em x do alerta: TREMOR_N tremidas de TREMOR_PASSO_S entre +A e -A (interpolação linear, como os
## tweens do primo) e a volta a 0. Antes de 0 e depois de DURACAO_TREMOR_S é 0.
static func tremor(t: float) -> float:
	if t <= 0.0 or t >= DURACAO_TREMOR_S:
		return 0.0
	var pontos: Array[float] = [0.0]
	for i in TREMOR_N:
		pontos.append(TREMOR_AMPLITUDE if i % 2 == 0 else -TREMOR_AMPLITUDE)
	pontos.append(0.0)
	var k := mini(int(t / TREMOR_PASSO_S), pontos.size() - 2)
	var f := (t - k * TREMOR_PASSO_S) / TREMOR_PASSO_S
	return lerpf(pontos[k], pontos[k + 1], f)


## A opacidade do flash de tela em `t`: no pico FLASH_ALFA, depois cai em linha reta a 0 em FLASH_S. Um flash só.
static func flash_alfa(t: float) -> float:
	if t < 0.0 or t >= FLASH_S:
		return 0.0
	return FLASH_ALFA * (1.0 - t / FLASH_S)


## O selo "+N ciência": quanto ele subiu em px em `t` (negativo = para cima). Entra de baixo com o TRANS_BACK
## da entrada e depois sobe devagar até o fim.
static func selo_dy(t: float) -> float:
	var entra := SELO_ENTRA * (1.0 - progresso_da_entrada(t))
	var sobe := -SELO_SOBE * clampf((t - ENTRADA_S) / (SELO_S - ENTRADA_S), 0.0, 1.0)
	return entra + sobe


## A opacidade do selo: inteiro até os últimos SELO_FADE_S, some linearmente e vale 0 a partir de SELO_S.
static func selo_alfa(t: float) -> float:
	if t < 0.0 or t >= SELO_S:
		return 0.0
	return clampf((SELO_S - t) / SELO_FADE_S, 0.0, 1.0)
