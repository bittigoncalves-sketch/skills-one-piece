#!/usr/bin/env python3 -I
"""As 123 conquistas do mod (data/minepiece/advancements/*.json) → mapas/east_blue/conquistas_do_mod.json.

Por conquista: critérios (nomes), pai, gatilho (`impossible` = só as procedures concedem; `tick` = concluída no primeiro tick),
título e descrição JÁ no texto em inglês do mod (en_us.json), ícone, moldura (task/goal/challenge), se mostra aviso.
Uso:  python3 -I tools/mine_piece/extrair_conquistas.py [JAR]
"""
import json
import sys
import zipfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
JAR = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / "server_onepiece/mods/MinePiece-ver14-forge-1.20.1.jar"
SAIDA = RAIZ / "mapas/east_blue/conquistas_do_mod.json"
PREFIXO = "data/minepiece/advancements/"


def main():
    z = zipfile.ZipFile(JAR)
    lang = json.loads(z.read("assets/minepiece/lang/en_us.json"))
    saida = {}
    for n in sorted(z.namelist()):
        if not (n.startswith(PREFIXO) and n.endswith(".json")):
            continue
        d = json.loads(z.read(n))
        id_ = "minepiece:" + n[len(PREFIXO):-5]
        disp = d.get("display", {})
        titulo = disp.get("title", {}).get("translate", "")
        descr = disp.get("description", {}).get("translate", "")
        gatilhos = sorted({c.get("trigger", "") for c in d.get("criteria", {}).values()})
        saida[id_] = {
            "criterios": list(d.get("criteria", {}).keys()),
            "pai": d.get("parent", ""),
            "gatilho": "tick" if gatilhos == ["minecraft:tick"] else "impossible",
            "titulo": lang.get(titulo, titulo),
            "descricao": lang.get(descr, descr),
            "icone": disp.get("icon", {}).get("item", ""),
            "moldura": disp.get("frame", "task"),
            "aviso": bool(disp.get("show_toast", False)) and bool(disp),
            "xp": int(d.get("rewards", {}).get("experience", 0)),
        }
    SAIDA.write_text(json.dumps({"formato": 1, "conquistas": saida}, indent=1, ensure_ascii=False))
    ticks = [k for k, v in saida.items() if v["gatilho"] == "tick"]
    print(f"{len(saida)} conquistas ({len(ticks)} por tick: {[k.split(':')[1] for k in ticks]}) → {SAIDA.relative_to(RAIZ)}")


main()
