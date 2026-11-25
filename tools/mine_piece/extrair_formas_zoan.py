#!/usr/bin/env python3 -I
"""Formas Zoan do Mine Piece (jogador transformado) → `mapas/east_blue/formas_zoan.json` + texturas.

No mod, quem desenha a forma é `KleidersRenderEventProcedure` (evento `RenderLivingEvent`): com `player_form == 1` e a fruta
na mão, esconde peças do corpo e desenha classes `Model*_humanbeast` (rig do jogador: Head/Body/RightArm/LeftArm/RightLeg/
LeftLeg + extras: cauda, asas, chifres) com a textura da fruta. Aqui:
  1. lê a tabela fruta → [(modelo, textura)] do próprio procedure (a fruta vale até o próximo `ITEM_DEVIL_FRUIT_*`);
  2. extrai as peças/caixas de cada `Model*` com o parser de `extrair_modelos_java.py` (com `mirror` — UV espelhada);
  3. copia as texturas do jar para `assets/mine_piece/visual/entidades/`.

Escolhas (documentadas em docs/FORMAS_ZOAN.md): variantes `_slim` e `_fly` ficam de fora (o jogo só tem um corpo; voo = pendente);
`Modelfeather_robe` (manto condicional) também; `Modeloverlay` (a "pele" do híbrido) entra, `Modeloverlay_slim` não.

Uso:  python3 -I tools/mine_piece/extrair_formas_zoan.py
"""
import json
import re
import sys
import types
import zipfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
sys.dont_write_bytecode = True
_src = (RAIZ / "tools/mine_piece/extrair_modelos_java.py").read_text()
EX = types.ModuleType("extrair_modelos_java")
EX.__file__ = str(RAIZ / "tools/mine_piece/extrair_modelos_java.py")
exec(compile(_src, "extrair_modelos_java", "exec"), EX.__dict__)

PROCEDURE = EX.FONTE.parent / "procedures/KleidersRenderEventProcedure.java"
SAIDA = RAIZ / "mapas/east_blue/formas_zoan.json"
PASTA_TEX = EX.PASTA_TEX
# Tag `minepiece:can_transform` do mod (data/minepiece/tags/items/can_transform.json).
FRUTAS = ["ryu_ryu_pachycephalosaurus", "inu_inu_wolf", "neko_neko_leopard", "batto_batto", "inu_inu_okuchi_no_makami",
          "hito_hito_daibutsu", "ushi_ushi_giraffe", "tori_tori_phoenix", "kira_kira", "supa_supa", "uo_uo_seiryu",
          "ryu_ryu_brachiosaurus", "ryu_ryu_pteranodon", "neko_neko_sabertiger"]
FORA = ("_slim", "_fly", "feather_robe", "overlay_slim")


def tabela():
    """fruta → [(classe do modelo, textura)] na ordem em que o mod desenha (forma 1)."""
    fruta, textura, res = None, None, {}
    for linha in PROCEDURE.read_text().split("\n"):
        m = re.search(r"ITEM_DEVIL_FRUIT_(\w+)\.get\(\)", linha)
        if m and "m_41720_()" in linha and "==" in linha:
            fruta = m.group(1).lower()
        m = re.search(r'_texture = new ResourceLocation\("minepiece:textures/entities/(\w+)\.png"\)', linha)
        if m:
            textura = m.group(1)
        m = re.search(r"new (Model\w+)\(\s*(?:context)?", linha)
        if m and fruta in FRUTAS and textura and "KleidersSkinRenderer" not in linha:
            modelo = m.group(1)
            if modelo.startswith("Model") and not any(f in modelo for f in FORA) and (modelo, textura) not in res.setdefault(fruta, []):
                res[fruta].append((modelo, textura))
    return res


def main():
    z = zipfile.ZipFile(EX.JAR)
    PASTA_TEX.mkdir(parents=True, exist_ok=True)
    saida = {}
    for fruta, itens in tabela().items():
        camadas = []
        for modelo, textura in itens:
            fonte = EX.FONTE / "model" / f"{modelo}.java"
            d = EX.analisar_camada(fonte.read_text(), com_espelho=True)
            d["modelo"], d["textura"] = modelo, textura
            camadas.append(d)
            (PASTA_TEX / f"{textura}.png").write_bytes(z.read(f"assets/minepiece/textures/entities/{textura}.png"))
        saida[fruta] = camadas
        caixas = [sum(len(p["caixas"]) for p in c["partes"]) for c in camadas]
        print(f"{fruta}: " + ", ".join(f"{c['modelo']}({n} caixas, {c['textura']})" for c, n in zip(camadas, caixas)))
    SAIDA.write_text(json.dumps(saida, ensure_ascii=False, separators=(",", ":")))
    print(f"→ {SAIDA.relative_to(RAIZ)} ({SAIDA.stat().st_size // 1024} KB), {len(saida)} frutas")


if __name__ == "__main__":
    main()
