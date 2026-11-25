#!/usr/bin/env python3
"""Copia do jar do Minecraft 1.20.1 (extraído pelo REA) só o que o inventário usa, para `assets/minecraft_local/` (fora do git: Mojang, All Rights Reserved).
Receita: REA `open_binary ~/Documents/curseforge/minecraft/Install/versions/1.20.1/1.20.1.jar` → `extract_artifact` (a resposta é grande demais para o MCP,
mas a pasta /tmp/rea-extracted-* é criada) → `python3 -I tools/minecraft/copiar_da_extracao.py /tmp/rea-extracted-XXXX`."""
import shutil, sys
from pathlib import Path
raiz = Path(sys.argv[1])
destino = Path(__file__).resolve().parents[2] / "assets/minecraft_local"
texturas = raiz / "assets/minecraft/textures"
for rel, dest in [("gui/container/inventory.png", "gui/inventory.png"), ("gui/widgets.png", "gui/widgets.png"), ("gui/icons.png", "gui/icons.png")]:
    (destino / dest).parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(texturas / rel, destino / dest)
for pasta in ("item", "block"):
    shutil.copytree(texturas / pasta, destino / pasta, dirs_exist_ok=True)
(destino / "recipes").mkdir(exist_ok=True)
for f in (raiz / "data/minecraft/recipes").glob("*.json"):
    shutil.copyfile(f, destino / "recipes" / f.name)
shutil.copytree(raiz / "data/minecraft/tags/items", destino / "tags/items", dirs_exist_ok=True)
shutil.copyfile(raiz / "assets/minecraft/lang/en_us.json", destino / "lang_en_us.json")
print("ok:", destino)
