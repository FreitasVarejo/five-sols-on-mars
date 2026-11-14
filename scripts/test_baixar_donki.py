"""Testes do baixar_donki.py, sem rede.

Os fixtures em scripts/fixtures/ são recortes da resposta real:
  - wsaenlil_2026-09_2026-11.json: simulações WSA-ENLIL do DONKI baixadas em 14/11/2026;
  - radlab_curiosity_2024-05.json: amostras do Curiosity RAD no RadLab, de 19 e 20/05/2024.

Rodar da raiz do repo:  python3 -m unittest discover -s scripts -p 'test_*.py'
"""

import copy
import datetime as dt
import json
import os
import statistics
import sys
import tempfile
import unittest
from unittest import mock

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import baixar_donki as bd  # noqa: E402


def _fixture(nome):
    with open(os.path.join(AQUI, "fixtures", nome), encoding="utf-8") as f:
        return json.load(f)


class FiltroDeMarte(unittest.TestCase):
    def setUp(self):
        self.sims = _fixture("wsaenlil_2026-09_2026-11.json")

    def test_so_ficam_simulacoes_com_marte_no_impactlist(self):
        ids = {c["simulacao_id"] for c in bd.extrair_chegadas_marte(self.sims)}
        # 48734 (sem Marte), 48737 (impactList null) e 48740 (só BepiColombo) ficam de fora
        self.assertTrue(ids.isdisjoint({"WSA-ENLIL/48734/1", "WSA-ENLIL/48737/1", "WSA-ENLIL/48740/1"}))
        self.assertIn("WSA-ENLIL/48799/1", ids)

    def test_a_chegada_e_a_de_marte_e_nao_a_de_outro_destino(self):
        # 48799 também prevê STEREO A e Psyche, com horários diferentes
        c = next(c for c in bd.extrair_chegadas_marte(self.sims) if c["simulacao_id"] == "WSA-ENLIL/48799/1")
        self.assertEqual(c["chegada_prevista"], "2026-09-29T18:00:00Z")
        self.assertEqual(c["cme_inicio"], "2026-09-24T14:45:00Z")
        self.assertEqual(c["velocidade_kms"], 493.0)
        self.assertTrue(c["raspao"])
        self.assertFalse(c["impacto_menor"])
        self.assertEqual(c["link"], "https://ccmc.gsfc.nasa.gov/DONKI/view/WSA-ENLIL/48799/-1")

    def test_impacto_menor(self):
        c = next(c for c in bd.extrair_chegadas_marte(self.sims) if c["simulacao_id"] == "WSA-ENLIL/48984/1")
        self.assertTrue(c["impacto_menor"])
        self.assertFalse(c["raspao"])

    def test_janela_sem_marte_da_lista_vazia(self):
        sem_marte = [s for s in self.sims if s["simulationID"] in ("WSA-ENLIL/48734/1", "WSA-ENLIL/48737/1")]
        self.assertEqual(bd.extrair_chegadas_marte(sem_marte), [])
        dados = bd.montar_donki(sem_marte, dt.date(2026, 9, 15), dt.date(2026, 11, 14),
                                dt.date(2026, 11, 14), "u")
        self.assertEqual(dados["chegadas_marte"], [])
        self.assertEqual(dados["simulacoes_na_janela"], 2)
        self.assertFalse(dados["historico"])

    def test_lista_vazia_da_API(self):
        self.assertEqual(bd.extrair_chegadas_marte([]), [])


class Deduplicacao(unittest.TestCase):
    def setUp(self):
        self.sims = _fixture("wsaenlil_2026-09_2026-11.json")
        self.chegadas = bd.extrair_chegadas_marte(self.sims)
        self.ids = [c["simulacao_id"] for c in self.chegadas]

    def test_mesma_cme_fica_com_a_simulacao_mais_recente(self):
        # 49472 e 49473 são a mesma CME (09/11 18:15); 49473 concluiu depois
        self.assertIn("WSA-ENLIL/49473/1", self.ids)
        self.assertNotIn("WSA-ENLIL/49472/1", self.ids)

    def test_simulacao_com_varias_cmes_usa_a_mais_recente_como_chave(self):
        # 49251 e 49252: CME de 26/10 09:48. 49259 tem 09:00 e 09:48 (chave 09:48) e é a mais nova
        self.assertIn("WSA-ENLIL/49259/1", self.ids)
        self.assertNotIn("WSA-ENLIL/49251/1", self.ids)
        self.assertNotIn("WSA-ENLIL/49252/1", self.ids)
        c = next(c for c in self.chegadas if c["simulacao_id"] == "WSA-ENLIL/49259/1")
        self.assertEqual(c["cme_inicio"], "2026-10-26T09:48:00Z")
        self.assertEqual(c["cmes_na_simulacao"], 2)
        self.assertEqual(c["velocidade_kms"], 681.0)
        # a de 09:00 sozinha (49257) é outro evento e continua
        self.assertIn("WSA-ENLIL/49257/1", self.ids)

    def test_cmes_diferentes_nao_se_fundem(self):
        # 49028 (CME 16:24) e 49030 (CMEs 16:24 e 16:53, chave 16:53)
        self.assertIn("WSA-ENLIL/49028/1", self.ids)
        self.assertIn("WSA-ENLIL/49030/1", self.ids)

    def test_sem_cme_agrupa_pelo_dia_da_chegada(self):
        # 48993 e 48994 não têm CME e chegam em 11/10 06:00: ficam com a mais recente
        self.assertIn("WSA-ENLIL/48994/1", self.ids)
        self.assertNotIn("WSA-ENLIL/48993/1", self.ids)
        c = next(c for c in self.chegadas if c["simulacao_id"] == "WSA-ENLIL/48994/1")
        self.assertIsNone(c["cme_inicio"])
        self.assertIsNone(c["cme_id"])
        self.assertIsNone(c["velocidade_kms"])
        self.assertEqual(c["cmes_na_simulacao"], 0)

    def test_total_do_fixture(self):
        self.assertEqual(len(self.chegadas), 10)


class Ordenacao(unittest.TestCase):
    def test_ordem_pela_chegada_prevista(self):
        sims = _fixture("wsaenlil_2026-09_2026-11.json")
        sims.reverse()
        chegadas = bd.extrair_chegadas_marte(sims)
        datas = [c["chegada_prevista"] for c in chegadas]
        self.assertEqual(datas, sorted(datas))
        self.assertEqual(datas[0], "2026-09-29T18:00:00Z")
        self.assertEqual(datas[-1], "2026-11-13T12:00:00Z")

    def test_sem_data_de_chegada_vai_para_o_fim(self):
        sims = [
            _sim(1, cme="2026-10-01T00:00Z", chegada="2026-10-05T00:00Z"),
            _sim(2, cme="2026-10-02T00:00Z", chegada=None),
            _sim(3, cme="2026-10-03T00:00Z", chegada="2026-10-04T00:00Z"),
        ]
        chegadas = bd.extrair_chegadas_marte(sims)
        self.assertEqual([c["simulacao_id"] for c in chegadas],
                         ["WSA-ENLIL/3/1", "WSA-ENLIL/1/1", "WSA-ENLIL/2/1"])
        self.assertIsNone(chegadas[-1]["chegada_prevista"])


def _sim(n, cme="2026-10-01T00:00Z", chegada="2026-10-05T00:00Z", velocidade=400.0,
         completou="2026-10-01T12:00Z", marte=True):
    impactos = [{"location": "STEREO A", "arrivalTime": "2026-10-02T00:00Z",
                 "isGlancingBlow": False, "isMinorImpact": False}]
    if marte:
        item = {"location": "Mars", "isGlancingBlow": False, "isMinorImpact": False}
        if chegada is not None:
            item["arrivalTime"] = chegada
        impactos.append(item)
    cmes = [] if cme is None else [{"cmeStartTime": cme, "speed": velocidade, "CMEID": f"{cme}-CME-001"}]
    return {"simulationID": f"WSA-ENLIL/{n}/1", "modelCompletionTime": completou,
            "cmeInputs": cmes, "impactList": impactos, "link": f"https://exemplo/{n}"}


class CamposNulos(unittest.TestCase):
    def test_campos_ausentes_viram_null(self):
        sim = {"simulationID": "WSA-ENLIL/9/1",
               "cmeInputs": [{"cmeStartTime": "2026-10-01T00:00Z"}],
               "impactList": [{"location": "Mars"}]}
        (c,) = bd.extrair_chegadas_marte([sim])
        self.assertEqual(c["cme_inicio"], "2026-10-01T00:00:00Z")
        self.assertIsNone(c["chegada_prevista"])
        self.assertIsNone(c["velocidade_kms"])
        self.assertIsNone(c["cme_id"])
        self.assertIsNone(c["link"])
        self.assertFalse(c["raspao"])
        self.assertFalse(c["impacto_menor"])

    def test_cmeinputs_e_impactlist_nulos(self):
        self.assertEqual(bd.extrair_chegadas_marte(
            [{"simulationID": "x", "cmeInputs": None, "impactList": None}]), [])
        (c,) = bd.extrair_chegadas_marte(
            [{"simulationID": "WSA-ENLIL/1/1", "cmeInputs": None,
              "impactList": [{"location": "Mars", "arrivalTime": "2026-10-05T00:00Z"}]}])
        self.assertIsNone(c["cme_inicio"])
        self.assertEqual(c["cmes_na_simulacao"], 0)

    def test_velocidade_nao_numerica_vira_null(self):
        (c,) = bd.extrair_chegadas_marte([_sim(1, velocidade="abc")])
        self.assertIsNone(c["velocidade_kms"])

    def test_itens_estranhos_na_lista_sao_ignorados(self):
        self.assertEqual(bd.extrair_chegadas_marte([None, "x", 3, {}]), [])

    def test_normalizar_data(self):
        self.assertEqual(bd.normalizar_data("2026-09-24T14:45Z"), "2026-09-24T14:45:00Z")
        self.assertEqual(bd.normalizar_data("2024-05-20T06:15:19"), "2024-05-20T06:15:19Z")
        self.assertIsNone(bd.normalizar_data(None))
        self.assertIsNone(bd.normalizar_data(""))
        self.assertIsNone(bd.normalizar_data("ontem"))


class RadLab(unittest.TestCase):
    def test_media_e_maximo_por_dia(self):
        resposta = _fixture("radlab_curiosity_2024-05.json")
        r = bd.resumir_radlab(resposta, "consulta")
        por_dia = {}
        for ts, _, v, _ in resposta["data"]:
            por_dia.setdefault(ts[:10], []).append(v)
        self.assertEqual([d["dia"] for d in r["dias"]], ["2024-05-19", "2024-05-20"])
        for d in r["dias"]:
            v = por_dia[d["dia"]]
            self.assertEqual(d["media"], round(statistics.fmean(v), 2))
            self.assertEqual(d["maximo"], round(max(v), 2))
            self.assertEqual(d["amostras"], len(v))
        self.assertEqual(r["dias"][1]["maximo"], 303.99)
        self.assertEqual(r["amostras"], len(resposta["data"]))
        self.assertIn("µGy/h", r["unidade"])
        self.assertEqual(r["consulta"], "consulta")

    def test_resposta_estranha_da_erro(self):
        with self.assertRaises(bd.ErroDeColeta):
            bd.resumir_radlab({"erro": "500"}, "u")
        with self.assertRaises(bd.ErroDeColeta):
            bd.resumir_radlab({"columns": ["timestamp"], "data": []}, "u")
        with self.assertRaises(bd.ErroDeColeta):
            bd.resumir_radlab({"columns": ["timestamp", "absorbed_dose_rate"], "data": []}, "u")

    def test_url_cobre_o_ultimo_dia_inteiro(self):
        url = bd.url_radlab(dt.date(2024, 5, 10), dt.date(2024, 5, 31))
        self.assertIn("timestamp>=2024-05-10T00:00:00", url)
        self.assertIn("timestamp<2024-06-01T00:00:00", url)


class Falhas(unittest.TestCase):
    def setUp(self):
        self.pasta = tempfile.TemporaryDirectory()
        self.addCleanup(self.pasta.cleanup)
        self.saida = os.path.join(self.pasta.name, "donki.json")
        with open(self.saida, "w", encoding="utf-8") as f:
            f.write('{"antigo": true}\n')

    def _antigo_intacto(self):
        with open(self.saida, encoding="utf-8") as f:
            self.assertEqual(f.read(), '{"antigo": true}\n')
        self.assertEqual(os.listdir(self.pasta.name), ["donki.json"])  # sem .tmp sobrando

    def test_falha_de_rede_sai_com_1_e_preserva_o_arquivo(self):
        with mock.patch.object(bd, "_baixar_json", side_effect=bd.ErroDeColeta("sem rede")):
            with mock.patch("sys.stderr"):
                self.assertEqual(bd.main(["--saida", self.saida]), 1)
        self._antigo_intacto()

    def test_resposta_que_nao_e_lista_sai_com_1(self):
        with mock.patch.object(bd, "_baixar_json", return_value={"erro": "x"}):
            with mock.patch("sys.stderr"):
                self.assertEqual(bd.main(["--saida", self.saida]), 1)
        self._antigo_intacto()

    def test_falha_do_radlab_no_historico_nao_grava_sem_pedir(self):
        def falso(url, *a, **k):
            if "radlab" in url:
                raise bd.ErroDeColeta("radlab fora")
            return []
        with mock.patch.object(bd, "_baixar_json", side_effect=falso):
            with mock.patch("sys.stderr"):
                self.assertEqual(bd.main(["--historico", "--saida", self.saida]), 1)
                self._antigo_intacto()
            with mock.patch("sys.stdout"):
                self.assertEqual(bd.main(["--historico", "--sem-radlab", "--saida", self.saida]), 0)
        with open(self.saida, encoding="utf-8") as f:
            dados = json.load(f)
        self.assertTrue(dados["historico"])
        self.assertNotIn("radlab", dados)

    def test_janela_vazia_grava_lista_vazia(self):
        with mock.patch.object(bd, "_baixar_json", return_value=[]):
            with mock.patch("sys.stdout"):
                self.assertEqual(bd.main(["--saida", self.saida]), 0)
        with open(self.saida, encoding="utf-8") as f:
            dados = json.load(f)
        self.assertEqual(dados["chegadas_marte"], [])
        self.assertFalse(dados["historico"])

    def test_janela_de_60_dias_em_utc(self):
        with mock.patch.object(bd, "_baixar_json", return_value=[]) as m:
            with mock.patch("sys.stdout"):
                bd.main(["--saida", self.saida])
        hoje = dt.datetime.now(dt.timezone.utc).date()
        url = m.call_args[0][0]
        self.assertIn(f"endDate={hoje.isoformat()}", url)
        self.assertIn(f"startDate={(hoje - dt.timedelta(days=60)).isoformat()}", url)


class Formato(unittest.TestCase):
    def test_chaves_do_json(self):
        dados = bd.montar_donki(_fixture("wsaenlil_2026-09_2026-11.json"), dt.date(2026, 9, 15),
                                dt.date(2026, 11, 14), dt.date(2026, 11, 14), "u", historico=True)
        self.assertEqual(set(dados), {"fonte", "url", "coletado_em", "janela", "historico",
                                      "simulacoes_na_janela", "chegadas_marte"})
        self.assertEqual(dados["janela"], {"inicio": "2026-09-15", "fim": "2026-11-14"})
        self.assertTrue(dados["historico"])
        self.assertEqual(set(dados["chegadas_marte"][0]),
                         {"cme_inicio", "cme_id", "chegada_prevista", "raspao", "impacto_menor",
                          "velocidade_kms", "cmes_na_simulacao", "simulacao_id", "link"})
        json.dumps(copy.deepcopy(dados))


if __name__ == "__main__":
    unittest.main()
