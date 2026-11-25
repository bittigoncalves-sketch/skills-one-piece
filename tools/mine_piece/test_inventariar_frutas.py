#!/usr/bin/env python3
"""Verifica extração contra casos sintáticos e contra a tag real do mod local."""
import importlib.util
import json
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("inventario", Path(__file__).with_name("inventariar_frutas.py"))
inv = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inv)


class ExtracaoJava(unittest.TestCase):
    def test_delimitadores_em_strings_e_comentarios(self):
        texto = '''if (fruta) { String s = "} ) {"; /* } */ if (numero) { usar(); } }'''
        blocos = list(inv.blocos_if(texto))
        self.assertEqual([b["condicao"] for b in blocos], ["fruta", "numero"])
        self.assertIn("usar();", blocos[0]["corpo"])

    def test_custo_condicional_nao_vira_constante(self):
        texto = '''if (x == MinepieceModItems.ITEM_DEVIL_FRUIT_GOMU_GOMU.get()) {
          if (p_selectNumber == 21.0 && gear > 0) {
            name = Component.m_237115_("golpe").getString();
            if (gear == 2) { cost = 400.0; } else { cost = 100.0; }
          }
        }'''
        dados = inv.selecoes(texto, "GOMU_GOMU")
        self.assertEqual(len(dados), 1)
        self.assertEqual(dados[0]["expressoes_custo"], ["400.0", "100.0"])
        self.assertIn("gear > 0", dados[0]["condicao_java"])

    def test_item_e_numero_no_mesmo_if(self):
        texto = '''if (x == MinepieceModItems.ITEM_DEVIL_FRUIT_IMU.get() && p_selectNumber == 25.0) {
          name = Component.m_237115_("imu").getString(); cost = 200.0;
        }'''
        self.assertEqual(inv.selecoes(texto, "IMU")[0]["numeros"], [25])
        self.assertEqual(inv.selecoes(texto, "GORO_GORO"), [])

    def test_nao_mistura_despachos(self):
        texto = '''if (entity != null) {
          if (x == MinepieceModItems.ITEM_DEVIL_FRUIT_HIE_HIE.get()) { SkillHieHieProcedure.execute(world, entity); }
          else if (x == MinepieceModItems.ITEM_DEVIL_FRUIT_MERA_MERA.get()) { SkillMeraMeraProcedure.execute(world, entity); }
        }'''
        self.assertEqual(inv.despachos(texto), {"HIE_HIE": "SkillHieHieProcedure", "MERA_MERA": "SkillMeraMeraProcedure"})


@unittest.skipUnless(inv.FONTE.exists(), "fonte local do mod ausente")
class FonteReal(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalogo = inv.inventariar(inv.FONTE)
        cls.frutas = {f["id"]: f for f in cls.catalogo["frutas"]}

    def test_cobertura_exata_da_tag_sem_goro(self):
        tag = json.loads((inv.FONTE / self.catalogo["tag_origem"]).read_text())["values"]
        esperado = set(tag) - {"minepiece:item_devil_fruit", "minepiece:item_devil_fruit_goro_goro"}
        self.assertEqual({f["item_origem"] for f in self.frutas.values()}, esperado)
        self.assertEqual(len(self.frutas), 39)
        self.assertNotIn("goro_goro_mine_piece", self.frutas)

    def test_moku_ciclo_e_custos_originais(self):
        fruta = self.frutas["moku_moku_mine_piece"]
        self.assertEqual([s["numeros"] for s in fruta["selecao"]], [[21], [23], [25], [30]])
        self.assertEqual([s["expressoes_custo"] for s in fruta["selecao"]], [["120.0"], ["250.0"], ["250.0"], ["300.0"]])
        self.assertEqual([r["procedimentos"] for r in fruta["rotas"]],
                         [["WhiteBlowProcedure"], ["WhiteVineProcedure"], ["WhiteLauncherProcedure"], ["WhiteOutProcedure"]])

    def test_condicoes_especiais_preservadas(self):
        uta = self.frutas["uta_uta_mine_piece"]
        musica = next(s for s in uta["selecao"] if s["numeros"] == [29])
        self.assertIn("FORBIDDEN_SCORE", musica["condicao_java"])
        phoenix = self.frutas["tori_tori_phoenix_mine_piece"]
        self.assertIn("form >= 1.0", next(s for s in phoenix["selecao"] if s["numeros"] == [28])["condicao_java"])

    def test_assets_e_nomes_distinguem_modelos(self):
        self.assertEqual(len({f["nome"] for f in self.frutas.values()}), 39)
        for f in self.frutas.values():
            self.assertTrue((inv.FONTE / f["textura_origem"]).is_file(), f["id"])
            self.assertTrue((inv.FONTE / inv.JAVA / "procedures" / (f["despacho"] + ".java")).is_file())
            self.assertEqual(f["estado"], "aguarda_traducao")
            self.assertEqual(f["preco"], 1)


if __name__ == "__main__":
    unittest.main()
