#!/usr/bin/env python3
"""Assets de StoneOpeOpe/AIRubble do v14. Não publica nem usa Skills Builder."""
import hashlib
import json
from pathlib import Path
import shutil
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from geo_para_glb import converter, FONTE
from importar_combate import clipe_bedrock

RAIZ = Path(__file__).resolve().parents[2]
ORIGEM = Path(FONTE) / "assets/minepiece"
DESTINO = RAIZ / "assets/mine_piece/frutas/ope"
FONTE_ARTE = RAIZ / "art_src/mine_piece/frutas/ope"


def main():
    DESTINO.mkdir(parents=True, exist_ok=True)
    FONTE_ARTE.mkdir(parents=True, exist_ok=True)
    manifesto = {"obra": "Mine Piece v14", "autor": "orca", "licenca": "All Rights Reserved",
                 "origem_jar": (Path(FONTE) / "ORIGEM.sha256").read_text(), "arquivos": {}}
    arquivos = ["geo/rubble.geo.json", "animations/rubble.animation.json",
                "player_animation/punch_right.json"]
    texturas = ["tex_stone", "tex_oak_planks", "tex_oak_log"]
    arquivos += [f"textures/entities/{t}.png" for t in texturas]
    for relativo in arquivos:
        src = ORIGEM / relativo
        dst = FONTE_ARTE / relativo
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)
        manifesto["arquivos"][relativo] = hashlib.sha256(src.read_bytes()).hexdigest()
    for textura in texturas:
        converter(FONTE, {"id": textura, "classe": "Rubble", "modelo": {
            "geo": arquivos[0], "animacao": arquivos[1],
            "textura": f"textures/entities/{textura}.png"}}, str(DESTINO))
    animacao = json.loads((ORIGEM / arquivos[2]).read_text())["animations"]["punch_right"]
    (DESTINO / "poses.json").write_text(json.dumps({"punch_right": clipe_bedrock(animacao, fps=60)}))
    (FONTE_ARTE / "ORIGEM.json").write_text(json.dumps(manifesto, ensure_ascii=False, indent=2) + "\n")
    print("Ope: 3 modelos de entulho e 1 pose convertidos; origem preservada.")


if __name__ == "__main__":
    main()
