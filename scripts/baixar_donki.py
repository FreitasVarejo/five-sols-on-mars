#!/usr/bin/env python3
"""Baixa do DONKI (NASA/CCMC) as chegadas de CME a Marte e grava dados/donki.json.

Roda na hora do export (scripts/publicar.sh); o jogo nunca chama a NASA, ele lê
o JSON embutido no build (coleta zero). Só biblioteca padrão, sem chave de API.

Uso:
    scripts/baixar_donki.py                 # últimos 60 dias (UTC) -> dados/donki.json
    scripts/baixar_donki.py --historico     # maio de 2024 + RadLab
                                            #   -> dados/donki_historico_2024-05.json
    scripts/baixar_donki.py --historico --sem-radlab
    scripts/baixar_donki.py --saida OUTRO.json

Fonte: WSA-ENLIL, simulações do DONKI. O pedido filtra pela data de conclusão
do modelo (modelCompletionTime), e o máximo é 60 dias entre startDate e endDate.
    https://ccmc.gsfc.nasa.gov/DONKI/WS/get/WSAEnlilSimulations?startDate=&endDate=

O que o script faz com a resposta:
  1. fica só com os itens de impactList cuja location é "Mars";
  2. agrupa por CME e fica com a simulação mais recente de cada grupo.
     Uma simulação pode ter várias CMEs (cmeInputs). A chave do grupo é a
     cmeStartTime da CME mais recente da simulação, a que disparou a rodada.
     Simulação sem nenhuma CME em cmeInputs (acontece) não tem chave de CME e
     é agrupada pelo dia UTC da chegada prevista;
  3. ordena pela chegada prevista (sem data de chegada vai para o fim).

Formato da saída (datas em ISO 8601 UTC; ausente vira null):
    {
      "fonte": "NASA DONKI (CCMC), simulações WSA-ENLIL",
      "url": "<pedido feito>",
      "coletado_em": "AAAA-MM-DD",        # dia UTC da coleta
      "janela": {"inicio": "AAAA-MM-DD", "fim": "AAAA-MM-DD"},
      "historico": false,                 # true só no recorte de maio de 2024
      "simulacoes_na_janela": 110,        # simulações que vieram, de qualquer destino
      "chegadas_marte": [
        {
          "cme_inicio": "AAAA-MM-DDTHH:MM:00Z",  # início da CME-chave; null se a simulação não tem CME
          "cme_id": "2026-09-24T14:45:00-CME-001",
          "chegada_prevista": "AAAA-MM-DDTHH:MM:00Z",
          "raspao": false,                # isGlancingBlow: a CME só raspa
          "impacto_menor": false,         # isMinorImpact
          "velocidade_kms": 493.0,        # speed da CME-chave, km/s
          "cmes_na_simulacao": 1,         # tamanho de cmeInputs
          "simulacao_id": "WSA-ENLIL/48799/1",
          "link": "https://ccmc.gsfc.nasa.gov/DONKI/view/WSA-ENLIL/48799/-1"
        }
      ],
      "radlab": {                         # só com --historico, e só se a API responder
        "fonte": "NASA OSDR RadLab, MSL-RAD-Surface (Curiosity RAD)",
        "url": "<documentação da API>",
        "consulta": "<pedido feito>",
        "unidade": "µGy/h (taxa de dose absorvida)",
        "amostras": 1898,
        "dias": [{"dia": "AAAA-MM-DD", "media": 3.79, "maximo": 4.62, "amostras": 84}]
      }
    }

O timestamp do RadLab vem sem fuso; o script o trata como UTC (a doc não diz).

Falhas: rede ou API com erro, ou resposta que não é a esperada, saem com código 1
e uma mensagem no stderr, sem tocar no arquivo que já existe (a gravação é
atômica). Janela sem chegada a Marte grava chegadas_marte: []; trocar pelo
recorte histórico é decisão do jogo, não do script.
"""

import argparse
import datetime as dt
import json
import os
import statistics
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

URL_DONKI = "https://ccmc.gsfc.nasa.gov/DONKI/WS/get/WSAEnlilSimulations"
URL_RADLAB = "https://visualization.osdr.nasa.gov/radlab/api/"
URL_RADLAB_DOC = "https://visualization.osdr.nasa.gov/radlab/gui/data-api/"
FONTE = "NASA DONKI (CCMC), simulações WSA-ENLIL"
JANELA_DIAS = 60  # máximo entre startDate e endDate
HISTORICO_INICIO = dt.date(2024, 5, 10)
HISTORICO_FIM = dt.date(2024, 5, 31)
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAIDA_ATUAL = os.path.join(RAIZ, "dados", "donki.json")
SAIDA_HISTORICO = os.path.join(RAIZ, "dados", "donki_historico_2024-05.json")


class ErroDeColeta(Exception):
    """Rede, API ou formato de resposta fora do esperado."""


# --- rede --------------------------------------------------------------------

def _baixar_json(url, tentativas=3, espera=3.0):
    ultimo = None
    for n in range(tentativas):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "five-sols-on-mars-build"})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            ultimo = f"HTTP {e.code} em {url}"
            if e.code < 500:
                break  # 4xx não melhora tentando de novo
        except (urllib.error.URLError, TimeoutError, OSError, ValueError) as e:
            ultimo = f"{type(e).__name__}: {e} em {url}"
        if n < tentativas - 1:
            time.sleep(espera)
    raise ErroDeColeta(ultimo)


# --- DONKI ---------------------------------------------------------------------

def normalizar_data(valor):
    """'2026-09-24T14:45Z' -> '2026-09-24T14:45:00Z'. Vazio ou ilegível -> None."""
    if not isinstance(valor, str) or not valor:
        return None
    try:
        d = dt.datetime.fromisoformat(valor.strip().replace("Z", "+00:00"))
    except ValueError:
        return None
    if d.tzinfo is None:
        d = d.replace(tzinfo=dt.timezone.utc)
    return d.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _numero(valor):
    if isinstance(valor, bool) or not isinstance(valor, (int, float)):
        return None
    return float(valor)


def _cme_chave(simulacao):
    """(início normalizado, CME) da CME mais recente de cmeInputs; (None, None) se não há."""
    cmes = [c for c in (simulacao.get("cmeInputs") or []) if isinstance(c, dict)]
    com_inicio = [(normalizar_data(c.get("cmeStartTime")), c) for c in cmes]
    com_inicio = [(i, c) for i, c in com_inicio if i]
    if com_inicio:
        return max(com_inicio, key=lambda par: par[0])
    return (None, cmes[0]) if cmes else (None, None)


def _impacto_marte(simulacao):
    """O item de impactList em Marte de chegada mais cedo, ou None."""
    itens = [i for i in (simulacao.get("impactList") or [])
             if isinstance(i, dict) and i.get("location") == "Mars"]
    if not itens:
        return None
    return min(itens, key=lambda i: normalizar_data(i.get("arrivalTime")) or "9999")


def _ordem_da_simulacao(simulacao):
    """Mais recente = conclusão do modelo mais tarde; empate pelo número do id."""
    numero = 0
    partes = str(simulacao.get("simulationID") or "").split("/")
    if len(partes) >= 2 and partes[1].isdigit():
        numero = int(partes[1])
    return (normalizar_data(simulacao.get("modelCompletionTime")) or "", numero)


def extrair_chegadas_marte(simulacoes):
    """Lista de simulações do DONKI -> chegadas a Marte, uma por CME, em ordem de chegada."""
    grupos = {}
    for sim in simulacoes:
        if not isinstance(sim, dict):
            continue
        impacto = _impacto_marte(sim)
        if impacto is None:
            continue
        inicio, cme = _cme_chave(sim)
        chegada = normalizar_data(impacto.get("arrivalTime"))
        if inicio:
            chave = ("cme", inicio)
        elif chegada:
            chave = ("dia", chegada[:10])
        else:
            chave = ("sim", sim.get("simulationID"))
        atual = grupos.get(chave)
        if atual is None or _ordem_da_simulacao(sim) > _ordem_da_simulacao(atual[0]):
            grupos[chave] = (sim, impacto, inicio, cme, chegada)

    chegadas = []
    for sim, impacto, inicio, cme, chegada in grupos.values():
        cme = cme or {}
        chegadas.append({
            "cme_inicio": inicio,
            "cme_id": cme.get("CMEID") or None,
            "chegada_prevista": chegada,
            "raspao": bool(impacto.get("isGlancingBlow")),
            "impacto_menor": bool(impacto.get("isMinorImpact")),
            "velocidade_kms": _numero(cme.get("speed")),
            "cmes_na_simulacao": len(sim.get("cmeInputs") or []),
            "simulacao_id": sim.get("simulationID") or None,
            "link": sim.get("link") or None,
        })
    chegadas.sort(key=lambda c: (c["chegada_prevista"] is None, c["chegada_prevista"] or "",
                                 c["cme_inicio"] or ""))
    return chegadas


def montar_donki(simulacoes, inicio, fim, hoje, url, historico=False):
    return {
        "fonte": FONTE,
        "url": url,
        "coletado_em": hoje.isoformat(),
        "janela": {"inicio": inicio.isoformat(), "fim": fim.isoformat()},
        "historico": historico,
        "simulacoes_na_janela": len(simulacoes),
        "chegadas_marte": extrair_chegadas_marte(simulacoes),
    }


def url_donki(inicio, fim):
    consulta = urllib.parse.urlencode({"startDate": inicio.isoformat(), "endDate": fim.isoformat()})
    return f"{URL_DONKI}?{consulta}"


def baixar_simulacoes(url):
    dados = _baixar_json(url)
    if not isinstance(dados, list):
        raise ErroDeColeta(f"resposta do DONKI não é uma lista (veio {type(dados).__name__}) em {url}")
    return dados


# --- RadLab ----------------------------------------------------------------------

def url_radlab(inicio, fim):
    """Dose absorvida do Curiosity RAD de inicio até fim, inclusive. O RadLab quer o
    operador colado ao nome do parâmetro (timestamp>=...), sem codificar < e >."""
    de = f"{inicio.isoformat()}T00:00:00"
    ate = f"{(fim + dt.timedelta(days=1)).isoformat()}T00:00:00"
    return (f"{URL_RADLAB}?spacecraft=Curiosity&timestamp>={de}&timestamp<{ate}"
            "&absorbed_dose_rate&format=json")


def resumir_radlab(resposta, url):
    """Resposta do RadLab (columns/data) -> média e máximo por dia, em µGy/h."""
    if not isinstance(resposta, dict) or "columns" not in resposta or "data" not in resposta:
        raise ErroDeColeta("resposta do RadLab sem columns/data")
    colunas = resposta["columns"]
    try:
        i_t = colunas.index("timestamp")
        i_v = colunas.index("absorbed_dose_rate")
    except ValueError:
        raise ErroDeColeta(f"resposta do RadLab sem as colunas esperadas: {colunas}")
    por_dia = {}
    for linha in resposta["data"]:
        valor = _numero(linha[i_v])
        if valor is None or not isinstance(linha[i_t], str):
            continue
        por_dia.setdefault(linha[i_t][:10], []).append(valor)
    if not por_dia:
        raise ErroDeColeta("RadLab respondeu sem nenhuma amostra")
    return {
        "fonte": "NASA OSDR RadLab, MSL-RAD-Surface (Curiosity RAD)",
        "url": URL_RADLAB_DOC,
        "consulta": url,
        "unidade": "µGy/h (taxa de dose absorvida)",
        "amostras": sum(len(v) for v in por_dia.values()),
        "dias": [
            {"dia": dia, "media": round(statistics.fmean(v), 2), "maximo": round(max(v), 2),
             "amostras": len(v)}
            for dia, v in sorted(por_dia.items())
        ],
    }


# --- saída -------------------------------------------------------------------------

def gravar_atomico(caminho, dados):
    """Grava em arquivo temporário e troca; se algo falhar, o arquivo antigo fica."""
    pasta = os.path.dirname(caminho) or "."
    os.makedirs(pasta, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=pasta, prefix=".donki-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(dados, f, ensure_ascii=False, indent=2)
            f.write("\n")
        os.chmod(tmp, 0o644)  # mkstemp cria 0600
        os.replace(tmp, caminho)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def main(argv=None):
    ap = argparse.ArgumentParser(description="Baixa as chegadas de CME a Marte do DONKI.")
    ap.add_argument("--historico", action="store_true",
                    help="recorte de maio de 2024 (com RadLab) em vez dos últimos 60 dias")
    ap.add_argument("--sem-radlab", action="store_true",
                    help="com --historico, grava mesmo sem o bloco radlab")
    ap.add_argument("--saida", help="caminho do JSON de saída")
    args = ap.parse_args(argv)

    hoje = dt.datetime.now(dt.timezone.utc).date()
    if args.historico:
        inicio, fim = HISTORICO_INICIO, HISTORICO_FIM
        saida = args.saida or SAIDA_HISTORICO
    else:
        inicio, fim = hoje - dt.timedelta(days=JANELA_DIAS), hoje
        saida = args.saida or SAIDA_ATUAL

    try:
        url = url_donki(inicio, fim)
        simulacoes = baixar_simulacoes(url)
        dados = montar_donki(simulacoes, inicio, fim, hoje, url, historico=args.historico)
        if args.historico and not args.sem_radlab:
            url_r = url_radlab(inicio, fim)
            dados["radlab"] = resumir_radlab(_baixar_json(url_r), url_r)
    except ErroDeColeta as e:
        print(f"baixar_donki: FALHOU: {e}", file=sys.stderr)
        print(f"baixar_donki: {saida} não foi alterado.", file=sys.stderr)
        return 1

    gravar_atomico(saida, dados)
    n = len(dados["chegadas_marte"])
    print(f"baixar_donki: {len(simulacoes)} simulações de {inicio} a {fim}, "
          f"{n} chegada(s) a Marte -> {os.path.relpath(saida, RAIZ)}")
    if n:
        print(f"baixar_donki: primeira {dados['chegadas_marte'][0]['chegada_prevista']}, "
              f"última {dados['chegadas_marte'][-1]['chegada_prevista']}")
    if "radlab" in dados:
        print(f"baixar_donki: RadLab {dados['radlab']['amostras']} amostras em "
              f"{len(dados['radlab']['dias'])} dias")
    return 0


if __name__ == "__main__":
    sys.exit(main())
