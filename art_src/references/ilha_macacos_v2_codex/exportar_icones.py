#!/usr/bin/env python3
"""Exporta fontes RGBA para 128x128, preservando proporção e transparência."""
from pathlib import Path
from PIL import Image

refs = Path(__file__).resolve().parent
out = refs.parents[2] / 'assets/textures/ilha_macacos'
out.mkdir(parents=True, exist_ok=True)
for source in sorted(refs.glob('*_fonte.png')):
    if not source.name.startswith(('icone_', 'missao_')):
        continue
    image = Image.open(source).convert('RGBA')
    image.thumbnail((128, 128), Image.Resampling.NEAREST)
    canvas = Image.new('RGBA', (128, 128), (0, 0, 0, 0))
    canvas.alpha_composite(image, ((128-image.width)//2, (128-image.height)//2))
    dest = out / source.name.replace('_fonte.png', '.png')
    canvas.save(dest)
    print(dest.name, canvas.getchannel('A').getextrema())
