#!/usr/bin/env python3
"""Assets da Nikyu Nikyu (Mine Piece v14): as POSES do jogador e a PATA (`pad.geo.json`). A textura-base da PadEntity é "clear",
MAS o `PadLayer` redesenha o modelo inteiro com `tex_white.png` em RenderType.eyes (brilho, sem luz): a pata é VISÍVEL, uma
pata branca luminosa. (Antes este importador a tratava como invisível — era o bug "só som, sem projétil".) Arte do mod fora do git."""
import json
import shutil
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from geo_para_glb import FONTE, converter
from importar_combate import clipe_bedrock

RAIZ = Path(__file__).resolve().parents[2]
ORIGEM = Path(FONTE) / "assets/minepiece"
DESTINO = RAIZ / "assets/mine_piece/frutas/nikyu"
# PlayAnimationPlayerProcedure: -7/6 → punch_right (Pad Ho), -22 → ursus_shock, -4/0 → both_arm_front (Ursus, segurando),
# -7/1 → punch_gomu_pistol1 (recuo ao fim da investida do Kuma Punch), -7/5 → punch_right_jinbe (o soco do Kuma Punch).
POSES = ["punch_right", "ursus_shock", "both_arm_front", "punch_gomu_pistol1", "punch_right_jinbe"]
CORTE_DAS_POSES = 3.0


def main():
    DESTINO.mkdir(parents=True, exist_ok=True)
    clipes = {}
    for nome in POSES:
        data = json.loads((ORIGEM / f"player_animation/{nome}.json").read_text())["animations"][nome]
        clipes[nome] = clipe_bedrock(data, fps=60, ate=CORTE_DAS_POSES)
    converter(FONTE, {"id": "pata", "classe": "Pad", "modelo": {
        "geo": "geo/pad.geo.json", "animacao": "animations/pad.animation.json",
        "textura": "textures/entities/tex_white.png"}}, str(DESTINO))
    (DESTINO / "poses.json").write_text(json.dumps(clipes, separators=(",", ":")))
    print(f"Nikyu: {len(clipes)} poses e a pata em {DESTINO}")


if __name__ == "__main__":
    main()
