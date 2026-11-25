#!/usr/bin/env python3
"""Importa poses e EntityStrike diretamente do Mine Piece v14 local, sem loja.
Arte do mod (orca): All Rights Reserved. Não copia código Java.
python3 tools/mine_piece/importar_combate.py
"""
import hashlib
import json
from pathlib import Path
import shutil
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from geo_para_glb import converter, amostrar, FONTE

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "assets/mine_piece/combate"
SOURCE = ROOT / "art_src/mine_piece/combate"


# Converte a convenção Bedrock para Godot como geo_para_glb: -X/-Y/+Z.
# Braços rígidos do Minecraft viram braço+antebraço alinhados no rig articulado.
PAPEIS = {"head": "Head", "right_arm": "UpperArm_R", "left_arm": "UpperArm_L",
          "right_leg": "Thigh_R", "left_leg": "Thigh_L"}


def clipe_bedrock(data, fps=120, ate=None):
    """Um clipe de player_animation → {duracao, fps, quadros, posicoes} (graus e blocos/16).
    `ate` corta a amostragem (clipes de 60–360 s seguram a última pose)."""
    duracao = data["animation_length"] if ate is None else min(data["animation_length"], ate)
    frames, positions = [], []
    for frame in range(round(duracao * fps) + 1):
        t = frame / fps
        pose = {}
        for source, role in PAPEIS.items():
            v = amostrar(data["bones"].get(source, {}).get("rotation", [0, 0, 0]), t)
            pose[role] = [-v[0], -v[1], v[2]]
        body = amostrar(data["bones"].get("body", {}).get("rotation", [0, 0, 0]), t)
        torso = amostrar(data["bones"].get("torso", {}).get("rotation", [0, 0, 0]), t)
        pose["Torso"] = [-body[0]-torso[0], -body[1]-torso[1], body[2]+torso[2]]
        for role in ("ForeArm_R", "ForeArm_L", "Shin_R", "Shin_L"):
            pose[role] = [0, 0, 0]
        frames.append(pose)
        offsets = {}
        for source, role in PAPEIS.items():
            v = amostrar(data["bones"].get(source, {}).get("position", [0, 0, 0]), t)
            offsets[role] = [-v[0]/16, v[1]/16, v[2]/16]
        v = amostrar(data["bones"].get("body", {}).get("position", [0, 0, 0]), t)
        offsets["Torso"] = [-v[0]/16, v[1]/16, v[2]/16]
        positions.append(offsets)
    return {"duracao": duracao, "fps": fps, "quadros": frames, "posicoes": positions}


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    SOURCE.mkdir(parents=True, exist_ok=True)
    files = ["geo/entity_strike.geo.json", "animations/entity_strike.animation.json",
             "textures/entities/slash_white.png", "sounds/punch_hit1.ogg", "sounds/hit_strong.ogg"]
    files += [f"player_animation/punch_{side}.json" for side in ("right", "left")]
    manifest = {"obra": "Mine Piece v14", "autor": "orca", "licenca": "All Rights Reserved",
                "pagina": "https://www.curseforge.com/minecraft/mc-mods/mine-piece",
                "origem_jar": (Path(FONTE) / "ORIGEM.sha256").read_text(), "arquivos": {}}
    for rel in files:
        src = Path(FONTE) / "assets/minepiece" / rel
        dst = SOURCE / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)
        manifest["arquivos"][rel] = hashlib.sha256(src.read_bytes()).hexdigest()
        if rel.startswith("sounds/"):
            shutil.copyfile(src, DEST / src.name)
    ficha = {"id": "impacto", "classe": "EntityStrike", "modelo": {
        "geo": files[0], "animacao": files[1], "textura": files[2]}}
    converter(FONTE, ficha, str(DEST))
    clips = {}
    for side in ("right", "left"):
        name = "punch_" + side
        data = json.loads((SOURCE / f"player_animation/{name}.json").read_text())["animations"][name]
        clips[name] = clipe_bedrock(data)
    (DEST / "poses.json").write_text(json.dumps(clips, separators=(",", ":")))
    (SOURCE / "ORIGEM.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(f"Importados {len(files)} assets; 2 poses e GLB de impacto em {DEST}")


if __name__ == "__main__":
    main()
