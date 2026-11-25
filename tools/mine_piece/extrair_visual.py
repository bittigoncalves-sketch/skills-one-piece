"""SONS e PARTÍCULAS do Mine Piece v14 → assets/mine_piece/visual/ + mapas/east_blue/visual_do_mod.json (23/10/2026, fatia 3).

Sons: `sounds.json` (evento → arquivo) e os .ogg. Partículas: cada `particles/particle_X.json` lista quadros
(`textures/particle/*.png`); os quadros viram UMA tira horizontal (a animação do `CPUParticles3D` usa
`anim_h_frames`). Os assets saem do git (`assets/mine_piece/visual/`); refazer com este script.

    python3 -I tools/mine_piece/extrair_visual.py
"""
import json
import os
import zipfile

from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.join(AQUI, "..", "..")
JAR = os.path.expanduser("~/server_onepiece/mods/MinePiece-ver14-forge-1.20.1.jar")
SAIDA_ASSETS = os.path.join(RAIZ, "assets", "mine_piece", "visual")
SAIDA_JSON = os.path.join(RAIZ, "mapas", "east_blue", "visual_do_mod.json")


def main() -> None:
    os.makedirs(os.path.join(SAIDA_ASSETS, "sons"), exist_ok=True)
    os.makedirs(os.path.join(SAIDA_ASSETS, "particulas"), exist_ok=True)
    z = zipfile.ZipFile(JAR)
    nomes = set(z.namelist())

    # --- sons: evento → [arquivos]
    sons = {}
    for evento, d in json.loads(z.read("assets/minepiece/sounds.json")).items():
        arqs = []
        for s in d.get("sounds", []):
            n = (s["name"] if isinstance(s, dict) else s).split(":")[-1]
            if "assets/minepiece/sounds/%s.ogg" % n in nomes:
                arqs.append(n)
        if arqs:
            sons["minepiece:" + evento] = arqs
    for n in sorted({a for v in sons.values() for a in v}):
        open(os.path.join(SAIDA_ASSETS, "sons", n + ".ogg"), "wb").write(
            z.read("assets/minepiece/sounds/%s.ogg" % n))

    # --- partículas: nome → tira horizontal
    particulas = {}
    for caminho in sorted(n for n in nomes if n.startswith("assets/minepiece/particles/particle_")):
        nome = os.path.basename(caminho)[:-5]
        quadros = []
        for t in json.loads(z.read(caminho)).get("textures", []):
            p = "assets/minepiece/textures/particle/%s.png" % t.split(":")[-1]
            if p in nomes:
                quadros.append(Image.open(z.open(p)).convert("RGBA"))
        if not quadros:
            continue
        w = max(q.width for q in quadros)
        h = max(q.height for q in quadros)
        tira = Image.new("RGBA", (w * len(quadros), h), (0, 0, 0, 0))
        for i, q in enumerate(quadros):
            tira.paste(q, (i * w + (w - q.width) // 2, (h - q.height) // 2))
        tira.save(os.path.join(SAIDA_ASSETS, "particulas", nome + ".png"))
        particulas["minepiece:" + nome] = {"quadros": len(quadros), "w": w, "h": h}

    # --- texturas das entidades de golpe (slash_*, projectile_*): o corpo é um plano duplo com elas
    os.makedirs(os.path.join(SAIDA_ASSETS, "entidades"), exist_ok=True)
    for n in sorted(nomes):
        b = os.path.basename(n)
        if n.startswith("assets/minepiece/textures/entities/") and (b.startswith("slash_") or b.startswith("projectile_")):
            open(os.path.join(SAIDA_ASSETS, "entidades", b), "wb").write(z.read(n))

    json.dump({"formato": "skills-one-piece/visual-mine-piece", "versao": 1,
               "origem": {"mod": "MinePiece-ver14-forge-1.20.1.jar", "extraido_por": "tools/mine_piece/extrair_visual.py"},
               "sons": sons, "particulas": particulas},
              open(SAIDA_JSON, "w"), ensure_ascii=False, indent=1)
    print(f"{len(sons)} eventos de som, {len(particulas)} partículas → {os.path.normpath(SAIDA_JSON)}")


if __name__ == "__main__":
    main()
