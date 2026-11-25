"""Junta os quadros de prévia do Gorila-rei (Blender não tem PIL) em uma folha por clipe. Uso: python3 tools/blender/folha_de_poses.py [clipe ...]"""
import os
import sys
from PIL import Image

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
PASTA = os.path.join(RAIZ, "art_src", "validation", "ilha_macacos", "gorila_rei")
Q = os.path.join(PASTA, "quadros")
tam = int(os.environ.get("TAM", "280"))
nomes = sys.argv[1:] or sorted({f.rsplit("_", 2)[0] for f in os.listdir(Q) if f.endswith(".png")})
for nome in nomes:
    folha = Image.new("RGB", (tam * 4, tam * 2), (30, 30, 34))
    for col in range(4):
        for lin in range(2):
            img = Image.open(os.path.join(Q, f"{nome}_{col}_{lin}.png")).convert("RGB").resize((tam, tam), Image.NEAREST)
            folha.paste(img, (tam * col, tam * lin))
    folha.save(os.path.join(PASTA, f"{nome}.png"))
    print("folha", nome)
