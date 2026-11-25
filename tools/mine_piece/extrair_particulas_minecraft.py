#!/usr/bin/env python3
"""Extrai do jar do Minecraft 1.20.1 LOCAL as texturas das partículas vanilla que as procedures do Mine Piece pedem
(`minecraft:crit`, `minecraft:cloud`...). Fidelidade (AUDITORIA_FIDELIDADE_MINE_PIECE, A7b): antes o jogo desenhava um
círculo suave colorido no lugar de cada uma.

Para cada partícula lê `assets/minecraft/particles/<nome>.json` (a lista de texturas, na ordem dos quadros), junta os
quadros numa TIRA horizontal (o mesmo formato das partículas do mod) em
`assets/mine_piece/visual/particulas/mc_<nome>.png` (gitignored: arte do Minecraft nunca vai ao repositório) e registra
`minecraft:<nome>` em `mapas/east_blue/visual_do_mod.json` → "particulas": {quadros, w, h}.

    python3 tools/mine_piece/extrair_particulas_minecraft.py   # (sem -I: precisa do Pillow do usuário) [--jar CAMINHO]
"""
import io
import json
import os
import re
import sys
import zipfile

from PIL import Image

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
JAR = os.path.expanduser("~/Documents/curseforge/minecraft/Install/versions/1.20.1/1.20.1.jar")
PROCEDURES = os.path.join(RAIZ, "src", "minecraft", "gerado", "procedures")
SAIDA = os.path.join(RAIZ, "assets", "mine_piece", "visual", "particulas")
VISUAL = os.path.join(RAIZ, "mapas", "east_blue", "visual_do_mod.json")


def pedidas():
    """Ids `minecraft:x` em linhas de sendParticles/addParticle das procedures geradas."""
    achadas = set()
    for nome in os.listdir(PROCEDURES):
        if not nome.endswith(".gd"):
            continue
        for linha in open(os.path.join(PROCEDURES, nome), encoding="utf-8"):
            if "sendParticles" not in linha and "addParticle" not in linha:
                continue
            for m in re.finditer(r'minecraft:([a-z_]+)', linha):
                achadas.add(m.group(1))
    return sorted(achadas)


def main():
    jar = JAR
    if "--jar" in sys.argv:
        jar = sys.argv[sys.argv.index("--jar") + 1]
    z = zipfile.ZipFile(jar)
    visual = json.load(open(VISUAL))
    os.makedirs(SAIDA, exist_ok=True)
    feitas, sem_def, sem_tex = [], [], []
    for nome in pedidas():
        try:
            d = json.loads(z.read("assets/minecraft/particles/%s.json" % nome))
        except KeyError:
            sem_def.append(nome)
            continue
        quadros = []
        for t in d.get("textures", []):
            caminho = "assets/minecraft/textures/particle/%s.png" % t.replace("minecraft:", "")
            try:
                quadros.append(Image.open(io.BytesIO(z.read(caminho))).convert("RGBA"))
            except KeyError:
                sem_tex.append(caminho)
        if not quadros:
            sem_def.append(nome + "(sem texturas)")
            continue
        w, h = quadros[0].size
        tira = Image.new("RGBA", (w * len(quadros), h))
        for i, q in enumerate(quadros):
            if q.size != (w, h):
                q = q.resize((w, h), Image.NEAREST)
            tira.paste(q, (i * w, 0))
        tira.save(os.path.join(SAIDA, "mc_%s.png" % nome))
        visual["particulas"]["minecraft:" + nome] = {"quadros": len(quadros), "w": w, "h": h}
        feitas.append("%s(%d×%dpx)" % (nome, len(quadros), w))
    json.dump(visual, open(VISUAL, "w"), indent=1, ensure_ascii=False)
    print("partículas do Minecraft extraídas (%d): %s" % (len(feitas), ", ".join(feitas)))
    print("sem definição:", ", ".join(sem_def) or "nenhuma")
    print("textura ausente:", ", ".join(sem_tex[:8]) or "nenhuma")


main()
