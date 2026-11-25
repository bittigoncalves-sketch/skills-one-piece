"""EVENTOS do Forge que o Mine Piece v14 escuta → mapas/east_blue/eventos_do_mod.json (23/10/2026, E1).

As técnicas não rodam no `baseTick`: a IA só grava `skill` e quem executa é a `EntityActiveProcedure`,
ligada ao `LivingTickEvent` (todo ser vivo, todo tick). Aqui sai, por tipo de evento, a lista
(procedure, método que recebe o evento). Eventos de cliente/renderização/registro ficam de fora.

    python3 -I tools/mine_piece/extrair_eventos.py
"""
import json
import os
import re

MOD = os.path.expanduser("~/dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14")
PASTA = os.path.join(MOD, "net/mcreator/minepiece/procedures")
SAIDA = os.path.join(os.path.dirname(__file__), "..", "..", "mapas", "east_blue", "eventos_do_mod.json")
FORA = ("Render", "FMLCommonSetup", "FMLClientSetup", "RegisterDimension", "ClientTick", "InputEvent")


def main() -> None:
    eventos = {}
    for f in sorted(os.listdir(PASTA)):
        t = open(os.path.join(PASTA, f), encoding="utf-8", errors="replace").read()
        for m in re.finditer(r"@SubscribeEvent\s+public static void (\w+)\(([\w.$]+) \w+\)", t):
            tipo = m.group(2).split(".")[-1].split("$")[-1]
            if any(tipo.startswith(x) or x in tipo for x in FORA):
                continue
            eventos.setdefault(tipo, []).append([f[:-5], m.group(1)])
    sha = open(os.path.join(MOD, "ORIGEM.sha256")).read().split()[0]
    json.dump({"formato": "skills-one-piece/eventos-mine-piece", "versao": 1,
               "origem": {"mod": "MinePiece-ver14-forge-1.20.1.jar", "sha256": sha,
                          "extraido_por": "tools/mine_piece/extrair_eventos.py"}, "eventos": eventos},
              open(SAIDA, "w"), ensure_ascii=False, indent=1)
    print(f"{sum(len(v) for v in eventos.values())} handlers em {len(eventos)} eventos → {os.path.normpath(SAIDA)}")
    for tipo in ("LivingTickEvent", "LivingAttackEvent", "LivingHurtEvent", "LivingDamageEvent", "LivingDeathEvent"):
        print(f"  {tipo}: {eventos.get(tipo)}")


if __name__ == "__main__":
    main()
