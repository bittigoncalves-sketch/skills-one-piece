#!/usr/bin/env python3
"""Assets da Moku Moku (Mine Piece v14): punho de fumaça (FistEntity, fist_small +
feather_robe_white), tornado (tornado + slash_white), fumaça e poses. Arte fora do git."""
import hashlib
import json
from pathlib import Path
import shutil
import sys

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from geo_para_glb import converter, FONTE
from importar_combate import clipe_bedrock

RAIZ = Path(__file__).resolve().parents[2]
ORIGEM = Path(FONTE) / "assets/minepiece"
DESTINO = RAIZ / "assets/mine_piece/frutas/moku"
FONTE_ARTE = RAIZ / "art_src/mine_piece/frutas/moku"
# id → (geo/animação, classe Java, textura) do renderer do mod.
MODELOS = {"punho": ("fist_small", "Fist", "feather_robe_white"),
           "tornado": ("tornado", "Tornado", "slash_white")}
# PlayAnimationPlayerProcedure: -7/1 pistol1, -7/6 punch_right, -7/0 punch_right|left,
# -47/0 fly_front, -21/0 invisibility, -20/0 yamiyami_blackhole, -16/0 enkai.
POSES = ["punch_gomu_pistol1", "punch_right", "punch_left", "fly_front", "invisibility",
         "yamiyami_blackhole", "enkai"]
CORTE_DAS_POSES = 3.0
# A fumaça do mod (particle_big_smoke, 12 quadros) — o "cloud" vanilla não vem no JAR.
FUMACA = ("particle_big_smoke", 12)


def main():
    DESTINO.mkdir(parents=True, exist_ok=True)
    FONTE_ARTE.mkdir(parents=True, exist_ok=True)
    manifesto = {"obra": "Mine Piece v14", "autor": "orca", "licenca": "All Rights Reserved",
                 "origem_jar": (Path(FONTE) / "ORIGEM.sha256").read_text(), "arquivos": {}}

    def copiar(relativo):
        src = ORIGEM / relativo
        dst = FONTE_ARTE / relativo
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)
        manifesto["arquivos"][relativo] = hashlib.sha256(src.read_bytes()).hexdigest()
        return src

    for nome, (geo, classe, textura) in MODELOS.items():
        copiar(f"geo/{geo}.geo.json")
        copiar(f"animations/{geo}.animation.json")
        copiar(f"textures/entities/{textura}.png")
        converter(FONTE, {"id": nome, "classe": classe, "modelo": {
            "geo": f"geo/{geo}.geo.json", "animacao": f"animations/{geo}.animation.json",
            "textura": f"textures/entities/{textura}.png"}}, str(DESTINO))

    nome, n = FUMACA
    quadros = [Image.open(copiar(f"textures/particle/{nome}_{i}.png")).convert("RGBA") for i in range(1, n + 1)]
    lado = quadros[0].size[0]
    tira = Image.new("RGBA", (lado * n, lado))
    for i, im in enumerate(quadros):
        tira.paste(im.resize((lado, lado), Image.NEAREST), (i * lado, 0))
    tira.save(DESTINO / f"{nome}.png")

    clipes = {}
    for pose in POSES:
        data = json.loads(copiar(f"player_animation/{pose}.json").read_text())["animations"][pose]
        clipes[pose] = clipe_bedrock(data, fps=60, ate=CORTE_DAS_POSES)
    (DESTINO / "poses.json").write_text(json.dumps(clipes, separators=(",", ":")))
    (FONTE_ARTE / "ORIGEM.json").write_text(json.dumps(manifesto, ensure_ascii=False, indent=2) + "\n")
    print(f"Moku: {len(MODELOS)} modelos, fumaça e {len(clipes)} poses em {DESTINO}")


if __name__ == "__main__":
    main()
