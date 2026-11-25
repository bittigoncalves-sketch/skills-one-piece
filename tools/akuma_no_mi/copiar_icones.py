#!/usr/bin/env python3
"""Copia os ícones 2D 32×32 do Codex (art_src/akuma_no_mi/icones/<id>.png) para assets/ui/frutas/akuma/ (onde `ItensDeFruta` os procura)
depois de conferir tamanho e canal alfa. Depois: "$(./find_godot.sh)" --headless --path . --import"""
import os, shutil, sys
from PIL import Image
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ORIGEM, DESTINO = os.path.join(RAIZ, "art_src/akuma_no_mi/icones"), os.path.join(RAIZ, "assets/ui/frutas/akuma")
os.makedirs(DESTINO, exist_ok=True)
n = ruins = 0
for f in sorted(os.listdir(ORIGEM)):
    if not f.endswith(".png") or f.startswith("_"):
        continue
    im = Image.open(os.path.join(ORIGEM, f))
    if im.size != (32, 32) or im.mode != "RGBA" or im.getchannel("A").getextrema()[0] != 0:
        print("REJEITADO", f, im.size, im.mode); ruins += 1; continue
    shutil.copyfile(os.path.join(ORIGEM, f), os.path.join(DESTINO, f)); n += 1
print(f"{n} ícones copiados, {ruins} rejeitados")
sys.exit(1 if ruins else 0)
