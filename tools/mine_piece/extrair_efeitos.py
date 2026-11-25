"""GANCHOS dos efeitos do Mine Piece v14 → mapas/east_blue/efeitos_do_mod.json (23/10/2026, E1).

Efeito do MCreator chama procedure: `applyEffectTick` (a cada tick em que `isDurationEffectTick` deixa),
`addAttributeModifiers` (ao começar) e `removeAttributeModifiers` (ao acabar). É assim que as técnicas
rodam: a IA aplica `minepiece:skill` e o tick dele (`CursedTechniqueOnPotionActiveTickProcedure`) executa
a técnica escolhida. Por efeito: procedures de tick/início/fim e a frequência do tick.

    python3 -I tools/mine_piece/extrair_efeitos.py
"""
import json
import os
import re
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
from srg_oficial import mapa, traduzir  # noqa: E402
from extrair_entidades import corpo_do_metodo  # noqa: E402

MOD = os.path.expanduser("~/dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14")
SRC = os.path.join(MOD, "net/mcreator/minepiece")
SAIDA = os.path.join(AQUI, "..", "..", "mapas", "east_blue", "efeitos_do_mod.json")


def main() -> None:
    srg = mapa()
    registro = {}
    texto = open(os.path.join(SRC, "init/MinepieceModMobEffects.java"), encoding="utf-8", errors="replace").read()
    for m in re.finditer(r'register\(\s*"([a-z0-9_]+)",\s*\(\)\s*->\s*new (\w+)\(', texto):
        registro[m.group(2)] = m.group(1)
    efeitos = {}
    for f in sorted(os.listdir(os.path.join(SRC, "potion"))):
        classe = f[:-5]
        if classe not in registro:
            continue
        t = traduzir(open(os.path.join(SRC, "potion", f), encoding="utf-8", errors="replace").read(), srg)
        freq = corpo_do_metodo(t, r"boolean isDurationEffectTick\(int \w+, int \w+\)\s*\{")
        periodo = 1
        if freq and "return true" not in freq:
            m = re.search(r"% (\d+) == 0", freq)
            periodo = int(m.group(1)) if m else 0          # 0 = nunca (sem tick)
        if not freq:
            periodo = 0                                   # MobEffect padrão: sem tick
        efeitos["minepiece:" + registro[classe]] = {
            "classe": classe,
            "tick": re.findall(r"(\w+Procedure)\.execute", corpo_do_metodo(t, r"void applyEffectTick\(")),
            "periodo": periodo,
            "ao_comecar": re.findall(r"(\w+Procedure)\.execute", corpo_do_metodo(t, r"void addAttributeModifiers\(")),
            "ao_acabar": re.findall(r"(\w+Procedure)\.execute", corpo_do_metodo(t, r"void removeAttributeModifiers\(")),
        }
    sha = open(os.path.join(MOD, "ORIGEM.sha256")).read().split()[0]
    json.dump({"formato": "skills-one-piece/efeitos-mine-piece", "versao": 1,
               "origem": {"mod": "MinePiece-ver14-forge-1.20.1.jar", "sha256": sha,
                          "extraido_por": "tools/mine_piece/extrair_efeitos.py"}, "efeitos": efeitos},
              open(SAIDA, "w"), ensure_ascii=False, indent=1)
    com = sum(1 for e in efeitos.values() if e["tick"] or e["ao_comecar"] or e["ao_acabar"])
    print(f"{len(efeitos)} efeitos, {com} com procedure → {os.path.normpath(SAIDA)}")
    for k in ("minepiece:skill", "minepiece:mamaragan", "minepiece:stun", "minepiece:earthquake"):
        print(f"  {k}: {efeitos.get(k)}")


if __name__ == "__main__":
    main()
