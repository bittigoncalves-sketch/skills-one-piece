#!/usr/bin/env python3
"""Assets da Hie Hie (Mine Piece v14): partisan, pássaro (geo do phoenix com tex_ice),
bola de gelo, partícula de gelo, som e poses. Arte do mod fica fora do git."""
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
DESTINO = RAIZ / "assets/mine_piece/frutas/hie"
FONTE_ARTE = RAIZ / "art_src/mine_piece/frutas/hie"
# Entidade → (geo, animação) do renderer do mod; todas com textures/entities/tex_ice.png.
MODELOS = {"partisan": ("partisan", "EntityPartisan"), "passaro": ("phoenix", "EntityBird"),
           "bola_de_gelo": ("ice_ball", "EntityIceBall")}
# PlayAnimationPlayerProcedure: -24 → yasakani_no_magatama, -19/0 → right_arm_front,
# -4/0 → both_arm_front, -7/6 → punch_right, -20/0 → yamiyami_blackhole.
POSES = ["yasakani_no_magatama", "right_arm_front", "both_arm_front", "punch_right", "yamiyami_blackhole"]
CORTE_DAS_POSES = 3.0


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

    copiar("textures/entities/tex_ice.png")
    for nome, (geo, classe) in MODELOS.items():
        copiar(f"geo/{geo}.geo.json")
        copiar(f"animations/{geo}.animation.json")
        converter(FONTE, {"id": nome, "classe": classe, "modelo": {
            "geo": f"geo/{geo}.geo.json", "animacao": f"animations/{geo}.animation.json",
            "textura": "textures/entities/tex_ice.png"}}, str(DESTINO))

    shutil.copyfile(copiar("sounds/ice_generate.ogg"), DESTINO / "ice_generate.ogg")

    # particle_ice: 12 quadros → uma tira horizontal (flipbook no Godot).
    quadros = [Image.open(copiar(f"textures/particle/particle_ice_{i}.png")).convert("RGBA")
               for i in range(1, 13)]
    lado = quadros[0].size[0]
    tira = Image.new("RGBA", (lado * len(quadros), lado))
    for i, im in enumerate(quadros):
        tira.paste(im.resize((lado, lado), Image.NEAREST), (i * lado, 0))
    tira.save(DESTINO / "particle_ice.png")

    clipes = {}
    for nome in POSES:
        data = json.loads(copiar(f"player_animation/{nome}.json").read_text())["animations"][nome]
        clipes[nome] = clipe_bedrock(data, fps=60, ate=CORTE_DAS_POSES)
    (DESTINO / "poses.json").write_text(json.dumps(clipes, separators=(",", ":")))
    (FONTE_ARTE / "ORIGEM.json").write_text(json.dumps(manifesto, ensure_ascii=False, indent=2) + "\n")
    print(f"Hie: {len(MODELOS)} modelos, partícula, som e {len(clipes)} poses em {DESTINO}")


if __name__ == "__main__":
    main()
