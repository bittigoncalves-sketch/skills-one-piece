#!/usr/bin/env python3
"""Importa os assets da Goro Goro no Mi do Mine Piece v14 local (sem loja, sem Builder).
Arte do mod (orca): All Rights Reserved — provisória, fora do git (ver .gitignore).
Não copia código Java: a tradução das técnicas mora em src/combat/goro_mine_piece/.
python3 -I tools/mine_piece/importar_goro.py
"""
import hashlib
import json
from pathlib import Path
import shutil
import sys

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from geo_para_glb import converter, FONTE
from importar_combate import clipe_bedrock

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "assets/mine_piece/goro"
SOURCE = ROOT / "art_src/mine_piece/goro"
ICONE = ROOT / "assets/ui/frutas/goro_goro_mine_piece.png"
MOD = Path(FONTE) / "assets/minepiece"

SONS = ["electric_short", "electric_shock", "thunder_impact", "guard_just"]
# Partículas animadas do mod: N quadros viram UMA tira horizontal (flipbook no Godot).
PARTICULAS = {"particle_thunder_light_blue": 22, "particle_big_smoke": 12}
# Os clipes que as técnicas pedem (PlayAnimationPlayerProcedure: ANIMATION_1/ANIMATION_2).
POSES = ["right_arm_front2", "energy_charge", "punch_right_jinbe", "punch_overhead",
         "right_arm_up", "right_arm_front", "both_arm_up", "fly_front", "fly_back"]
# Clipes de 60–360 s só seguram a pose: amostra os primeiros segundos.
CORTE_DAS_POSES = 3.0


def main():
    for pasta in (DEST, SOURCE):
        pasta.mkdir(parents=True, exist_ok=True)
    manifest = {"obra": "Mine Piece v14", "autor": "orca", "licenca": "All Rights Reserved",
                "pagina": "https://www.curseforge.com/minecraft/mc-mods/mine-piece",
                "origem_jar": (Path(FONTE) / "ORIGEM.sha256").read_text(), "arquivos": {}}

    def copiar(rel):
        src = MOD / rel
        dst = SOURCE / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)
        manifest["arquivos"][rel] = hashlib.sha256(src.read_bytes()).hexdigest()
        return src

    for som in SONS:
        shutil.copyfile(copiar(f"sounds/{som}.ogg"), DEST / f"{som}.ogg")

    for nome, quadros in PARTICULAS.items():
        imagens = [Image.open(copiar(f"textures/particle/{nome}_{i}.png")).convert("RGBA")
                   for i in range(1, quadros + 1)]
        lado = imagens[0].size[0]
        tira = Image.new("RGBA", (lado * quadros, lado))
        for i, im in enumerate(imagens):
            tira.paste(im.resize((lado, lado), Image.NEAREST), (i * lado, 0))
        tira.save(DEST / f"{nome}.png")

    clips = {}
    for nome in POSES:
        data = json.loads(copiar(f"player_animation/{nome}.json").read_text())["animations"][nome]
        clips[nome] = clipe_bedrock(data, fps=60, ate=CORTE_DAS_POSES)
    (DEST / "poses.json").write_text(json.dumps(clips, separators=(",", ":")))

    # Raigo: MeteorEntity (geo ball_maximum, textura tex_white2 no modo 1).
    for rel in ("geo/ball_maximum.geo.json", "animations/ball_maximum.animation.json",
                "textures/entities/tex_white2.png"):
        copiar(rel)
    converter(FONTE, {"id": "goro_meteoro", "classe": "Meteor", "modelo": {
        "geo": "geo/ball_maximum.geo.json", "animacao": "animations/ball_maximum.animation.json",
        "textura": "textures/entities/tex_white2.png"}}, str(DEST))

    # Ícone do vendedor: o item do mod (16 px) ampliado sem filtro.
    item = Image.open(copiar("textures/item/devil_fruit_goro_goro.png")).convert("RGBA")
    item.resize((128, 128), Image.NEAREST).save(ICONE)

    (SOURCE / "ORIGEM.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(f"Importados {len(manifest['arquivos'])} arquivos; {len(clips)} poses, meteoro e ícone em {DEST}")


if __name__ == "__main__":
    main()
