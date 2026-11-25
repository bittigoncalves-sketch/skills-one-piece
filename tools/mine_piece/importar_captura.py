#!/usr/bin/env python3
"""Poses do jogador para o LANÇAMENTO da pokébola (30/10/2026): `right_arm_up` (o braço sobe enquanto puxa) e
`right_arm_front` (o braço vai à frente ao soltar), do `player_animation` do Mine Piece v14, no mesmo formato de
`importar_nikyu.py`. Arte do mod fica fora do git (assets/mine_piece é ignorado)."""
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from geo_para_glb import FONTE
from importar_combate import clipe_bedrock

RAIZ = Path(__file__).resolve().parents[2]
ORIGEM = Path(FONTE) / "assets/minepiece"
DESTINO = RAIZ / "assets/mine_piece/captura"
POSES = ["right_arm_up", "right_arm_front"]


def main():
    DESTINO.mkdir(parents=True, exist_ok=True)
    clipes = {}
    for nome in POSES:
        data = json.loads((ORIGEM / f"player_animation/{nome}.json").read_text())["animations"][nome]
        clipes[nome] = clipe_bedrock(data, fps=60, ate=3.0)
    (DESTINO / "poses.json").write_text(json.dumps(clipes, separators=(",", ":")))
    print(f"Captura: {len(clipes)} poses em {DESTINO}")


if __name__ == "__main__":
    main()
