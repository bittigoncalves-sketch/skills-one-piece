#!/usr/bin/env python3
"""Complemento de `copiar_da_extracao.py`: copia do MESMO jar 1.20.1 (o que o REA abriu: `open_binary` + `extract_artifact`, SHA-256 56b71336…bb0f)
as texturas de GUI que a primeira extração não trouxe — fonte bitmap, fundo de menu, janelas de container e de conquistas.
Vão para `assets/minecraft_local/gui/` (fora do git: Mojang, All Rights Reserved). Uso: `python3 -I tools/minecraft/copiar_gui_do_jar.py [caminho do jar]`."""
import sys, zipfile
from pathlib import Path
jar = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / "Documents/curseforge/minecraft/Install/versions/1.20.1/1.20.1.jar"
destino = Path(__file__).resolve().parents[2] / "assets/minecraft_local/gui"
destino.mkdir(parents=True, exist_ok=True)
QUERO = {
    "assets/minecraft/textures/font/ascii.png": "ascii.png",
    "assets/minecraft/textures/font/accented.png": "accented.png",
    "assets/minecraft/textures/gui/options_background.png": "options_background.png",
    "assets/minecraft/textures/gui/container/generic_54.png": "generic_54.png",
    "assets/minecraft/textures/gui/container/crafting_table.png": "crafting_table.png",
    "assets/minecraft/textures/gui/advancements/window.png": "advancements_window.png",
    "assets/minecraft/textures/gui/advancements/widgets.png": "advancements_widgets.png",
    "assets/minecraft/textures/gui/advancements/backgrounds/stone.png": "advancements_stone.png",
    "assets/minecraft/textures/gui/advancements/tabs.png": "advancements_tabs.png",
    "assets/minecraft/textures/misc/vignette.png": "vignette.png",
}
with zipfile.ZipFile(jar) as z:
    for origem, nome in QUERO.items():
        (destino / nome).write_bytes(z.read(origem))
        print("ok:", nome)
