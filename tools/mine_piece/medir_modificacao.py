#!/usr/bin/env python3
"""Mede quanto cada personagem `mp_*` já se afastou da arte original do Mine Piece.

Para cada ficha de mapas/east_blue/personagens.json:
  - origem da malha: "mod" (gerada por geo_para_glb.py a partir do .geo.json do mod) ou
    "propria" (existe mapas/modelos/pi_<id>.glb, construída por nós);
  - textura: diferença média (0..1) entre a original do mod (build/mine_piece/texturas_originais)
    e a atual, comparadas na resolução da atual. Só reduzir/quantizar dá valor baixo;
    repintar de verdade dá valor alto;
  - veredito: PRONTO (malha própria + textura repintada), PROVISORIO (convertido do mod),
    AUSENTE (sem .glb local).
Uso: python3 -I tools/mine_piece/medir_modificacao.py [--md docs/MINE_PIECE_MEDICAO_MODIFICACAO.md]
"""
import json, os, struct, sys
from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODELOS = os.path.join(RAIZ, "mapas/modelos")
ORIG = os.path.join(RAIZ, "build/mine_piece/texturas_originais")
LIMIAR_TEXTURA = 0.20  # abaixo disso a textura segue sendo a do mod, só reduzida


def json_do_glb(caminho):
    with open(caminho, "rb") as f:
        f.read(12)
        n, _ = struct.unpack("<II", f.read(8))
        return json.loads(f.read(n))


def resumo_glb(caminho):
    j = json_do_glb(caminho)
    verts = sum(j["accessors"][p["attributes"]["POSITION"]]["count"]
                for m in j.get("meshes", []) for p in m["primitives"])
    return {"ossos": len(j.get("nodes", [])), "vertices": verts}


def diferenca(atual, original):
    a = Image.open(atual).convert("RGBA")
    o = Image.open(original).convert("RGBA").resize(a.size, Image.BOX)
    pa, po = a.tobytes(), o.tobytes()
    return sum(abs(x - y) for x, y in zip(pa, po)) / (255.0 * len(pa))


def medir(ficha):
    mid = ficha["modelo"]
    glb = os.path.join(MODELOS, mid + ".glb")
    proprio = os.path.join(MODELOS, "pi_" + ficha["id"] + ".glb")
    r = {"id": ficha["id"], "zona": ficha.get("zona", ""), "modelo": mid}
    if os.path.exists(proprio):
        r["origem"] = "propria"; glb = proprio
    elif os.path.exists(glb):
        r["origem"] = "mod"
    else:
        r.update(origem="-", veredito="AUSENTE"); return r
    r.update(resumo_glb(glb))
    tex = os.path.join(MODELOS, mid + "_corpo.png")
    org = os.path.join(ORIG, mid + "_corpo.png")
    r["dif_textura"] = round(diferenca(tex, org), 3) if os.path.exists(tex) and os.path.exists(org) else None
    if r["origem"] == "propria":
        do_codex = os.path.exists(os.path.join(RAIZ, "art_src/reconstrucao/texturas", ficha["id"] + ".png"))
        r["dif_textura"] = "codex" if do_codex else "reserva lisa"
        r["veredito"] = "PRONTO" if do_codex else "MALHA_PROPRIA_SEM_TEXTURA"
    else:
        r["veredito"] = "PROVISORIO"
    return r


def main():
    fichas = json.load(open(os.path.join(RAIZ, "mapas/east_blue/personagens.json")))
    fichas = fichas.get("personagens", fichas)
    if isinstance(fichas, dict):
        fichas = list(fichas.values())
    res = [medir(f) for f in fichas]
    cont = {}
    for r in res:
        cont[r["veredito"]] = cont.get(r["veredito"], 0) + 1
    print(cont)
    if "--md" in sys.argv:
        dest = os.path.join(RAIZ, sys.argv[sys.argv.index("--md") + 1])
        with open(dest, "w") as f:
            f.write("# Medição: Mine Piece x arte própria\n\nGerado por `tools/mine_piece/medir_modificacao.py`.\n\n")
            f.write(f"Totais: {cont}\n\n| id | zona | origem | ossos | vértices | dif. textura | veredito |\n|---|---|---|---|---|---|---|\n")
            for r in res:
                f.write(f"| {r['id']} | {r['zona']} | {r['origem']} | {r.get('ossos','')} | {r.get('vertices','')} | {r.get('dif_textura','')} | {r['veredito']} |\n")
    for r in res:
        if r["id"] in ("pirate", "bandit", "chouchou", "suzume"):
            print(r)


if __name__ == "__main__":
    main()
