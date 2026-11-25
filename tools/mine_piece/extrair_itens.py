"""ITENS do Mine Piece v14 → mapas/east_blue/itens_do_mod.json (23/10/2026, E1).

Por item: a classe e a classe-BASE do Minecraft (SwordItem, ArmorItem, TieredItem, ShieldItem, Item…) —
a IA pergunta `item instanceof SwordItem` para escolher o golpe de espada. Também a classe → id, para
`new XEntity(...)`/`XItem` virar o registro certo.

    python3 -I tools/mine_piece/extrair_itens.py
"""
import json
import os
import re

MOD = os.path.expanduser("~/dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14")
SRC = os.path.join(MOD, "net/mcreator/minepiece")
SAIDA = os.path.join(os.path.dirname(__file__), "..", "..", "mapas", "east_blue", "itens_do_mod.json")


def main() -> None:
    texto = open(os.path.join(SRC, "init/MinepieceModItems.java"), encoding="utf-8", errors="replace").read()
    itens = {}
    for m in re.finditer(r'register\("([a-z0-9_]+)", \(\) -> new (\w+)', texto):
        ident, classe = m.group(1), m.group(2)
        base = "Item"
        caminho = os.path.join(SRC, "item", classe + ".java")
        if os.path.exists(caminho):
            b = re.search(r"public class \w+ extends (\w+)", open(caminho, encoding="utf-8", errors="replace").read())
            base = b.group(1) if b else "Item"
        elif "SpawnEgg" in classe:
            base = "ForgeSpawnEggItem"
        itens[ident] = {"classe": classe, "base": base}
    sha = open(os.path.join(MOD, "ORIGEM.sha256")).read().split()[0]
    json.dump({"formato": "skills-one-piece/itens-mine-piece", "versao": 1,
               "origem": {"mod": "MinePiece-ver14-forge-1.20.1.jar", "sha256": sha,
                          "extraido_por": "tools/mine_piece/extrair_itens.py"}, "itens": itens},
              open(SAIDA, "w"), ensure_ascii=False, indent=1)
    bases = {}
    for i in itens.values():
        bases[i["base"]] = bases.get(i["base"], 0) + 1
    print(f"{len(itens)} itens → {os.path.normpath(SAIDA)}; bases {bases}; kiribachi {itens.get('kiribachi')}")


if __name__ == "__main__":
    main()
