#!/usr/bin/env python3
"""Modelos GeckoLib das ENTIDADES do mod que não são personagens (tornado, zeus, bola de gelo, fênix…).

    python3 -I tools/mine_piece/extrair_modelos_de_efeito.py [--saida DIR] [--so ID ...] [--listar]

Para cada entidade registrada: id (`MinepieceModEntities`) → renderer (`MinepieceModEntityRenderers`) →
modelo (`new XModel()` no renderer) → geo/animação/textura (`XModel.java`). Entidade com textura fixa
`clear.png` é INVISÍVEL por desenho (ver `extrair_invisiveis.py`) e não gera modelo. O resultado:

  • `assets/mine_piece/visual/modelos/mpx_<id>.glb` (git-ignorado; mesma conversão do `geo_para_glb.py`: nós rígidos, animação por nó);
  • `mapas/east_blue/visual_do_mod.json: modelos` = {id: {"glb", "textura", "dinamica", "animacoes"}}.
`dinamica` = o mod escolhe a textura em tempo de execução (`entity.getTexture()` → `setTexture`).
Personagens (as fichas de `personagens.json`) ficam de fora: já têm `mp_<id>.glb`.
"""
import argparse
import json
import os
import re
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import geo_para_glb as g  # noqa: E402

RAIZ = os.path.join(AQUI, "..", "..")
JSON_VISUAL = os.path.join(RAIZ, "mapas", "east_blue", "visual_do_mod.json")


def ler(fonte, rel):
    return open(os.path.join(fonte, "net/mcreator/minepiece", rel), encoding="utf-8").read()


def descobrir(fonte):
    """[(id, renderer, modelo, geo, animacao, textura|None)] — textura None = dinâmica."""
    ents = ler(fonte, "init/MinepieceModEntities.java")
    nome_para_id = {m.group(1): m.group(2) for m in re.finditer(
        r"RegistryObject<EntityType<\w+>>\s+(\w+)\s*=\s*register\(\s*\"([^\"]+)\"", ents)}
    rend = ler(fonte, "init/MinepieceModEntityRenderers.java")
    saida = []
    for m in re.finditer(r"MinepieceModEntities\.(\w+)\.get\(\),\s*(\w+)::new", rend):
        eid = nome_para_id.get(m.group(1))
        classe = m.group(2)
        arq = os.path.join(fonte, f"net/mcreator/minepiece/client/renderer/{classe}.java")
        if not eid or not os.path.exists(arq):
            continue
        texto = open(arq, encoding="utf-8").read()
        mm = re.search(r"new (\w+Model)\(\)", texto)
        if not mm:
            continue
        marq = os.path.join(fonte, f"net/mcreator/minepiece/entity/model/{mm.group(1)}.java")
        if not os.path.exists(marq):
            continue
        modelo = open(marq, encoding="utf-8").read()
        rec = re.findall(r'new ResourceLocation\("minepiece", ("[^"]*"(?: \+ [^)]*)?)\)', modelo)
        geo = anim = tex = None
        for r in rec:
            if "geo/" in r:
                geo = r.strip('"')
            elif "animations/" in r:
                anim = r.strip('"')
            elif "textures/" in r:
                tex = None if "getTexture" in r else r.strip('"')
        if geo:
            saida.append((eid, classe, mm.group(1), geo, anim, tex))
    return saida


def copiar_texturas(fonte, destino):
    """Texturas que o mod troca em tempo de execução (`setTexture("x")`): o corpo as aplica sem recarregar o modelo."""
    import shutil
    nomes = set()
    pasta = os.path.join(fonte, "net/mcreator/minepiece")
    for sub in ("procedures", "entity"):
        for arq in os.listdir(os.path.join(pasta, sub)):
            if arq.endswith(".java"):
                nomes.update(re.findall(r'setTexture\("([^"]+)"\)', open(os.path.join(pasta, sub, arq), encoding="utf-8").read()))
    os.makedirs(destino, exist_ok=True)
    n = 0
    for nome in sorted(nomes):
        png = os.path.join(fonte, "assets/minepiece/textures/entities", nome + ".png")
        if os.path.exists(png):
            shutil.copyfile(png, os.path.join(destino, nome + ".png"))
            n += 1
    return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fonte", default=g.FONTE)
    ap.add_argument("--saida", default="assets/mine_piece/visual/modelos")
    ap.add_argument("--so", nargs="*", default=[])
    ap.add_argument("--listar", action="store_true")
    a = ap.parse_args()
    fichas = {f["id"] for f in g.ler_json("docs/referencias/mine_piece/east_blue/personagens.json")["personagens"]}
    todos = [t for t in descobrir(a.fonte) if t[0] not in fichas]
    if a.listar:
        for t in todos:
            print(t)
        print(len(todos), "entidades não-personagem com geo")
        return 0
    os.makedirs(a.saida, exist_ok=True)
    modelos = {}
    invisiveis = []
    for eid, rend, _m, geo, anim, tex in todos:
        if a.so and eid not in a.so:
            continue
        if tex and tex.endswith("clear.png"):
            print(f"INVISÍVEL {eid}")
            invisiveis.append(eid)
            continue
        padrao = tex or g.textura_padrao(a.fonte, re.sub(r"Renderer$", "", rend))
        if not padrao:
            print(f"SEM TEXTURA {eid}")
            continue
        ficha = {"id": "x_" + eid, "classe": "", "modelo": {"geo": geo, "animacao": anim, "textura": padrao}}
        try:
            destino, n, _ = g.converter(a.fonte, ficha, a.saida, sem_equipamento=True)
        except Exception as e:
            print(f"ERRO {eid}: {type(e).__name__}: {e}")
            continue
        final = os.path.join(a.saida, f"mpx_{eid}.glb")
        os.replace(destino, final)
        os.remove(os.path.join(a.saida, "mp_x_%s.glb" % eid)) if os.path.exists(os.path.join(a.saida, "mp_x_%s.glb" % eid)) else None
        modelos[eid] = {"glb": f"mpx_{eid}.glb", "textura": padrao, "dinamica": tex is None, "animacoes": n}
        print(f"OK   {eid:28} {n:3} animações  {'(textura dinâmica)' if tex is None else ''}")
    if modelos and not a.so:
        d = g.ler_json(JSON_VISUAL)
        d["modelos"] = modelos
        d["invisiveis"] = sorted(set(d.get("invisiveis", [])) | set(invisiveis))
        print(copiar_texturas(a.fonte, os.path.join(RAIZ, "assets", "mine_piece", "visual", "entidades")), "texturas alternativas copiadas")
        with open(JSON_VISUAL, "w", encoding="utf-8") as f:
            json.dump(d, f, ensure_ascii=False, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
