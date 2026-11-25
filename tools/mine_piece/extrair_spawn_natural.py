"""Regras de SPAWN NATURAL do Mine Piece v14 → mapas/east_blue/spawn_natural.json (23/10/2026).

Pedido do dono: "permitir spawn em todas as ilhas para verificação de spawn in game" — decidido:
os personagens do mod nascem pelas regras do PRÓPRIO mod. Lê, sem executar nada:
  • data/minepiece/forge/biome_modifier/*.json (forge:add_spawns): peso, mínimo, máximo, biomas;
  • entity/*Entity.java: `SpawnPlacements.register(..., (…) -> return XProcedure.execute(...))` → a regra
    de região, e a `MobCategory` do registro em init/MinepieceModEntities.java.

    python3 -I tools/mine_piece/extrair_spawn_natural.py
"""
import hashlib
import json
import os
import re

MOD = os.path.expanduser("~/dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14")
SRC = os.path.join(MOD, "net/mcreator/minepiece")
SAIDA = os.path.join(os.path.dirname(__file__), "..", "..", "mapas", "east_blue", "spawn_natural.json")
# Procedure de spawn → regra que o jogo entende (ver SpawnNaturalMinePiece.REGRAS).
REGRAS = {"SpawnEastBlue": "east_blue", "SpawnGrandLine": "grand_line", "SpawnNewWorld": "novo_mundo",
          "SpawnSurface": "superficie", "SpawnSurfaceRare": "superficie_rara", "SpawnRedLine": "red_line",
          "SpawnWestAndNewWorld": "west_e_novo_mundo", "SpawnMarineCorps": "corpo_marinha",
          "SpawnPirateCorps": "corpo_piratas"}


def main() -> None:
    categoria = {}
    texto = open(os.path.join(SRC, "init/MinepieceModEntities.java"), encoding="utf-8", errors="replace").read()
    for m in re.finditer(r'register\(\s*"([a-z0-9_]+)"[^;]*?MobCategory\.(\w+)', texto, re.S):
        categoria[m.group(1)] = m.group(2)
    regra = {}
    pasta = os.path.join(SRC, "entity")
    for f in os.listdir(pasta):
        caminho = os.path.join(pasta, f)
        if not os.path.isfile(caminho):
            continue
        t = open(caminho, encoding="utf-8", errors="replace").read()
        i = t.find("SpawnPlacements.m_21754_")
        if i < 0:
            continue
        ent = re.search(r"MinepieceModEntities\.(\w+)\.get", t[i:i + 400])
        proc = re.search(r"return (\w+)Procedure\.execute", t[i:i + 1200])
        if ent:
            regra[ent.group(1).lower()] = REGRAS.get(proc.group(1), proc.group(1)) if proc else "sem_regra"
    entradas = []
    pasta = os.path.join(MOD, "data/minepiece/forge/biome_modifier")
    for f in sorted(os.listdir(pasta)):
        d = json.load(open(os.path.join(pasta, f)))
        if d.get("type") != "forge:add_spawns":
            continue
        biomas = d.get("biomes")
        qualquer = isinstance(biomas, dict) and biomas.get("type") == "forge:any" or biomas == "#minecraft:is_overworld"
        for s in d["spawners"] if isinstance(d["spawners"], list) else [d["spawners"]]:
            ident = s["type"].split(":")[1]
            entradas.append({"id": ident, "peso": s["weight"], "minimo": s["minCount"], "maximo": s["maxCount"],
                             "qualquer_bioma": bool(qualquer), "biomas": biomas if not qualquer else None,
                             "regra": regra.get(ident, "sem_regra"), "categoria": categoria.get(ident, "?")})
    jar_sha = open(os.path.join(MOD, "ORIGEM.sha256")).read().split()[0]
    saida = {"formato": "skills-one-piece/spawn-natural-mine-piece", "versao": 1,
             "origem": {"mod": "MinePiece-ver14-forge-1.20.1.jar", "sha256": jar_sha,
                        "extraido_por": "tools/mine_piece/extrair_spawn_natural.py"},
             "entradas": entradas}
    json.dump(saida, open(SAIDA, "w"), ensure_ascii=False, indent=1)
    por_regra = {}
    for e in entradas:
        por_regra[e["regra"]] = por_regra.get(e["regra"], 0) + 1
    print(f"{len(entradas)} regras de spawn → {os.path.normpath(SAIDA)}  {por_regra}")
    print("categorias:", {c: sum(1 for e in entradas if e["categoria"] == c) for c in {e["categoria"] for e in entradas}})


if __name__ == "__main__":
    main()
