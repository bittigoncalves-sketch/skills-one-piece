#!/usr/bin/env python3 -I
"""Receitas, loot tables e TODOS os `Model*.java` do Mine Piece v14 → JSON do jogo (item 9 da auditoria, 09/11/2026).

Saídas (em mapas/east_blue/):
  receitas_do_mod.json   — as 31 receitas (`data/minepiece/recipes`), no formato do Minecraft, por id.
  loot_do_mod.json       — as 15 loot tables (`data/minepiece/loot_tables`), por id (`minepiece:chests/loot_treasure`…).
  modelos_java_todos.json — as peças/caixas (com `mirror`) dos 64 `Model*.java` + a textura quando o nome casa com um PNG do jar.
Fonte: ~/dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14 (o parser de caixas é o de `extrair_modelos_java.py`).

Uso:  python3 -I tools/mine_piece/extrair_dados_do_mod.py
"""
import json
import sys
import types
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
sys.dont_write_bytecode = True
_src = (RAIZ / "tools/mine_piece/extrair_modelos_java.py").read_text()
EX = types.ModuleType("extrair_modelos_java")
EX.__file__ = str(RAIZ / "tools/mine_piece/extrair_modelos_java.py")
exec(compile(_src, "extrair_modelos_java", "exec"), EX.__dict__)

FONTE = Path.home() / "dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14"
DADOS = FONTE / "data/minepiece"
SAIDA = RAIZ / "mapas/east_blue"


def por_id(pasta: Path, prefixo: str) -> dict:
    saida = {}
    for f in sorted(pasta.rglob("*.json")):
        rel = f.relative_to(pasta).with_suffix("")
        saida[f"minepiece:{rel.as_posix()}"] = json.loads(f.read_text())
    return saida


def main():
    receitas = por_id(DADOS / "recipes", "")
    loot = por_id(DADOS / "loot_tables", "")
    (SAIDA / "receitas_do_mod.json").write_text(json.dumps(receitas, ensure_ascii=False, separators=(",", ":")))
    (SAIDA / "loot_do_mod.json").write_text(json.dumps(loot, ensure_ascii=False, separators=(",", ":")))
    print(f"receitas: {len(receitas)}; loot tables: {len(loot)}")
    modelos, erros = {}, []
    for f in sorted((EX.FONTE / "model").glob("Model*.java")):
        try:
            d = EX.analisar_camada(f.read_text(), com_espelho=True)
        except Exception as e:                       # modelo sem createBodyLayer ou com sintaxe fora do parser
            erros.append(f"{f.stem}: {type(e).__name__}")
            continue
        d["pecas"] = len(d["partes"])
        d["caixas"] = sum(len(p["caixas"]) for p in d["partes"])
        modelos[f.stem] = d
    (SAIDA / "modelos_java_todos.json").write_text(json.dumps(modelos, ensure_ascii=False, separators=(",", ":")))
    print(f"modelos Java: {len(modelos)} lidos, {len(erros)} com erro {erros}")


if __name__ == "__main__":
    main()
