#!/usr/bin/env python3
"""Texturas dos PROJÉTEIS do Mine Piece que o jogo não desenhava (30/10/2026): `bullet`, `heart_bullet`, `booger`, `missile`.
No mod: `bullet` e `heart_bullet` são `ThrownItemRenderer` (sprite do item: `item_bullet` → item/bullet.png, `item_heart` →
item/heart.png); `booger` também, com o botão de blackstone polido (vanilla); `missile` tem o modelo `Modelmissile` com
`textures/entities/missile.png`. Copia as PNGs para `assets/mine_piece/visual/entidades/` (gitignored: arte do mod e do
Minecraft nunca vai ao repositório). Sem Pillow: só copia bytes.

    python3 tools/mine_piece/extrair_projeteis.py [--jar CAMINHO_DO_MINECRAFT_1.20.1.jar]"""
import os
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from geo_para_glb import FONTE

RAIZ = Path(__file__).resolve().parents[2]
SAIDA = RAIZ / "assets/mine_piece/visual/entidades"
MOD = Path(FONTE) / "assets/minepiece/textures"
JAR = os.path.expanduser("~/Documents/curseforge/minecraft/Install/versions/1.20.1/1.20.1.jar")
DO_MOD = {"bullet.png": "item/bullet.png", "heart.png": "item/heart.png", "missile.png": "entities/missile.png"}
DO_MINECRAFT = {"booger.png": "assets/minecraft/textures/block/polished_blackstone.png"}


def main():
    jar = sys.argv[sys.argv.index("--jar") + 1] if "--jar" in sys.argv else JAR
    SAIDA.mkdir(parents=True, exist_ok=True)
    for destino, origem in DO_MOD.items():
        (SAIDA / destino).write_bytes((MOD / origem).read_bytes())
    with zipfile.ZipFile(jar) as z:
        for destino, origem in DO_MINECRAFT.items():
            (SAIDA / destino).write_bytes(z.read(origem))
    print("projéteis:", sorted(p.name for p in SAIDA.glob("*.png") if p.name in {*DO_MOD, *DO_MINECRAFT}))


if __name__ == "__main__":
    main()
