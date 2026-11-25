#!/usr/bin/env python3 -I
"""Extrai os clipes PlayerAnimator do mod (assets/minepiece/player_animation/*.json) para um JSON compacto:
assets/mine_piece/visual/animacoes_jogador.json (fora do git: derivado do mod, regerável).

Cada clipe: {"duracao": s, "segurar": bool, "ossos": {osso: {"rotation"|"position"|"scale": [[t, x, y, z, easing], ...]}}}.
Valores CRUS do mod (graus para rotação; unidades de modelo para posição) — a conversão para o rig fica em
`src/anim/pose_do_mod.gd`, onde é testada.

Uso:  python3 -I tools/mine_piece/extrair_animacoes_do_jogador.py [JAR]
"""
import json
import sys
import zipfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
JAR = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / "server_onepiece/mods/MinePiece-ver14-forge-1.20.1.jar"
SAIDA = RAIZ / "assets/mine_piece/visual/animacoes_jogador.json"
PREFIXO = "assets/minepiece/player_animation/"
# Ossos que o rig do jogador tem (o resto — capa, armadura — o mod desenha em modelos que o jogo não tem).
OSSOS_DO_CORPO = {"body", "torso", "head", "right_arm", "left_arm", "right_leg", "left_leg"}


def trilha(v):
    """Um canal: vetor fixo ou {tempo: {vector, easing}} → [[t, x, y, z, easing]] ordenado."""
    if isinstance(v, list):                      # vetor solto: [x, y, z]
        return [[0.0, *map(float, v), ""]]
    if isinstance(v, (int, float)):              # escala uniforme
        return [[0.0, float(v), float(v), float(v), ""]]
    if isinstance(v, dict) and "vector" in v:
        return [[0.0, *map(float, v["vector"]), ""]]
    saida = []
    for t, kf in v.items():
        vec = kf["vector"] if isinstance(kf, dict) else kf
        saida.append([float(t), *map(float, vec), str(kf.get("easing", "")) if isinstance(kf, dict) else ""])
    return sorted(saida, key=lambda k: k[0])


def main():
    z = zipfile.ZipFile(JAR)
    clipes, ignorados = {}, set()
    for n in sorted(z.namelist()):
        if not (n.startswith(PREFIXO) and n.endswith(".json")):
            continue
        for nome, a in json.loads(z.read(n))["animations"].items():
            ossos = {}
            for osso, canais in a.get("bones", {}).items():
                if osso not in OSSOS_DO_CORPO:
                    ignorados.add(osso)
                    continue
                ossos[osso] = {c: trilha(v) for c, v in canais.items()}
            clipes[nome] = {"duracao": float(a["animation_length"]), "segurar": a.get("loop") == "hold_on_last_frame", "ossos": ossos}
    SAIDA.parent.mkdir(parents=True, exist_ok=True)
    SAIDA.write_text(json.dumps(clipes, separators=(",", ":")))
    print(f"{len(clipes)} clipes → {SAIDA.relative_to(RAIZ)} ({SAIDA.stat().st_size // 1024} KB); ossos ignorados: {sorted(ignorados)}")


main()
