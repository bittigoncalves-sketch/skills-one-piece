#!/usr/bin/env python3
"""Texturas grandes em VRAM COMPRIMIDA (12/11/2026) — técnica do FerriteCore/ModernFix (cortar memória e carga sem mudar o que se vê), aplicada às texturas.
Medido (docs/ANALISE_SIMPLY_OPTIMIZED.md): 2945 dos 2974 `.import` do projeto estavam em `compress/mode=0` (sem perdas = RGBA8 + mipmaps na VRAM). 184 texturas de ≥ 1 MP
(Meshy, rochas, Yoru…) somavam ~1,8 GB de VRAM se carregadas; em BC7/ASTC (4×) caem para ~0,46 GB.
Uso: `python3 -I tools/otimizar_texturas.py` (só relata) · `--aplicar` (edita os `.import`; depois `godot --headless --path . --import`) · `--desfazer` (volta ao modo 0).
Regras: só imagens ≥ 1 MP em `CompressedTexture2D`; nunca `assets/minecraft_local` (pixel art 16×16 precisa de pixels exatos), `art_src`, `.godot`, `.claude`.
Mapas de normais (`normal` no nome ou `compress/normal_map` ligado) recebem `compress/normal_map=1`; os demais, `high_quality=true` (BC7 no desktop)."""
import re, sys, glob, os
from PIL import Image
Image.MAX_IMAGE_PIXELS = None
aplicar = "--aplicar" in sys.argv
desfazer = "--desfazer" in sys.argv
LIMITE = 1024 * 1024
alvos = []
for imp in sorted(glob.glob("**/*.import", recursive=True)):
    if imp.startswith((".godot", ".claude", "assets/minecraft_local", "art_src")):
        continue
    t = open(imp, errors="ignore").read()
    if 'type="CompressedTexture2D"' not in t:
        continue
    src = imp[:-7]
    try:
        w, h = Image.open(src).size
    except Exception:
        continue
    if w * h < LIMITE:
        continue
    alvos.append((imp, src, w, h, t))
mudou = 0
vram_antes = vram_depois = 0.0
for imp, src, w, h, t in alvos:
    modo = int(re.search(r"compress/mode=(\d)", t).group(1))
    mb = w * h * 4 * 1.333 / 1048576
    if desfazer:
        novo = re.sub(r"compress/mode=\d", "compress/mode=0", t)
        novo = re.sub(r"compress/high_quality=\w+", "compress/high_quality=false", novo)
    else:
        normal = "normal" in os.path.basename(src).lower()
        novo = re.sub(r"compress/mode=\d", "compress/mode=2", t)
        novo = re.sub(r"compress/high_quality=\w+", "compress/high_quality=true", novo)
        if normal:
            novo = re.sub(r"compress/normal_map=\d", "compress/normal_map=1", novo)
    if modo == 0:
        vram_antes += mb
        vram_depois += mb / 4
    else:
        vram_antes += mb / 4
        vram_depois += mb / 4
    if novo != t:
        mudou += 1
        if aplicar or desfazer:
            open(imp, "w").write(novo)
print("%d texturas >= 1 MP; VRAM estimada %.0f MB -> %.0f MB; %d arquivos .import %s" % (len(alvos), vram_antes, vram_depois, mudou, "EDITADOS" if (aplicar or desfazer) else "a editar (use --aplicar)"))
