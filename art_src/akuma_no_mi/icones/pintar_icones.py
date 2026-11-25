#!/usr/bin/env python3
"""Renderiza ícones pixelados 3/4 a partir dos voxels e atlas reais.

    python3 art_src/akuma_no_mi/icones/pintar_icones.py --lote 1
    python3 art_src/akuma_no_mi/icones/pintar_icones.py --lote 2
    python3 art_src/akuma_no_mi/icones/pintar_icones.py --folha

Usa projeção ortográfica e as cores dos próprios atlas; não altera os modelos.
"""
import argparse
import json
import math
import sys
import textwrap
import types
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[3]
ARTE = ROOT / 'art_src/akuma_no_mi'
OUT = Path(__file__).resolve().parent
N = 32
SUPER = 4


def geometria():
    """Carrega apenas definições do gerador, sem inicializar Blender/exportar."""
    path = ROOT / 'tools/akuma_no_mi/gerar_frutas.py'
    code = path.read_text().rsplit('\nmain()', 1)[0]
    sys.modules.setdefault('bpy', types.ModuleType('bpy'))
    ns = {'__file__': str(path), '__name__': 'geometria_akuma'}
    exec(compile(code, str(path), 'exec'), ns)
    return ns


def project(p):
    x, y, z = p
    # Câmera em +X, +Y, -Z: frente e lado com um pouco de topo.
    horizontal = (x + z) / math.sqrt(2)
    proximity = (x - z) / math.sqrt(2)
    pitch = math.radians(20)
    return horizontal, y * math.cos(pitch) - proximity * math.sin(pitch), proximity * math.cos(pitch) + y * math.sin(pitch)


def render(fid, forma, g):
    voxels = g['voxels'](forma)
    tex = Image.open(ARTE / 'texturas' / (fid + '.png')).convert('RGBA')
    if tex.size != (72, 48):
        raise ValueError(fid + ': atlas precisa ter 72x48')
    visible = ((0, 0, -1), (1, 0, 0), (0, 1, 0))
    faces = []
    for idx in voxels:
        for v in g['VISTAS']:
            normal = v[0]
            if normal not in visible:
                continue
            nxt = tuple(idx[k] + normal[k] for k in range(3))
            if nxt in voxels:
                continue
            tx, ty = g['texel'](v, idx)
            color = tex.getpixel((tx, ty))
            if color[3] != 255:
                raise ValueError(f'{fid}: texel vazio {tx},{ty}')
            points = [project(tuple(idx[i] + offset[i] for i in range(3))) for offset in g['QUAD'][normal]]
            faces.append((sum(p[2] for p in points) / 4, points, color, normal))
    if not faces:
        raise ValueError(fid + ': modelo vazio')
    minx = min(pt[0] for _, pts, _, _ in faces for pt in pts)
    maxx = max(pt[0] for _, pts, _, _ in faces for pt in pts)
    miny = min(pt[1] for _, pts, _, _ in faces for pt in pts)
    maxy = max(pt[1] for _, pts, _, _ in faces for pt in pts)
    scale = 27 * SUPER / max(maxx-minx, maxy-miny)
    centerx, centery = (minx+maxx)/2, (miny+maxy)/2
    art = Image.new('RGBA', (N*SUPER, N*SUPER), (0,0,0,0))
    draw = ImageDraw.Draw(art)
    # Faces distantes primeiro; o deslocamento de luz mantém a cor do atlas.
    for _, pts, color, normal in sorted(faces, key=lambda face: face[0]):
        mod = {(0,0,-1):1.0, (1,0,0):.88, (0,1,0):1.07}[normal]
        shade = tuple(min(255, round(v*mod)) for v in color[:3]) + (255,)
        poly = [(round(N*SUPER/2 + (x-centerx)*scale), round(N*SUPER/2 - (y-centery)*scale)) for x,y,_ in pts]
        draw.polygon(poly, fill=shade)
    art = art.resize((N,N), Image.Resampling.NEAREST)
    alpha = art.getchannel('A')
    outline = alpha.filter(ImageFilter.MaxFilter(3))
    result = Image.new('RGBA', (N,N), (22,20,27,0))
    result.putalpha(outline)
    result.alpha_composite(art)
    result.save(OUT / (fid + '.png'))


def folha(ids):
    cols = 11
    cell_w, cell_h = 120, 138
    image = Image.new('RGBA', (cols*cell_w, math.ceil(len(ids)/cols)*cell_h), (24,34,40,255))
    draw = ImageDraw.Draw(image)
    font = ImageFont.load_default()
    for i, fid in enumerate(ids):
        file = OUT / (fid + '.png')
        if not file.exists():
            raise FileNotFoundError(file)
        x = i%cols*cell_w
        y = i//cols*cell_h
        icon = Image.open(file).convert('RGBA').resize((96,96), Image.Resampling.NEAREST)
        image.alpha_composite(icon, (x+12,y))
        label = '\n'.join(textwrap.wrap(fid, width=19, break_long_words=True, break_on_hyphens=False))
        draw.multiline_text((x+3,y+98), label, font=font, fill=(238,238,232,255), spacing=1)
    image.save(OUT / '_folha.png')


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--lote', choices=('1','2'))
    parser.add_argument('--folha', action='store_true')
    args=parser.parse_args()
    ids=[f['id'] for f in json.loads((ARTE/'manifesto.json').read_text())['frutas']]
    if len(ids) != len(set(ids)):
        raise ValueError('manifesto contém IDs duplicados')
    if args.folha:
        folha(ids)
        print('folha:', len(ids), 'ícones')
    if args.lote or not args.folha:
        forms=json.loads((ARTE/'formas.json').read_text())['frutas']
        g=geometria()
        selected=ids[:22] if args.lote=='1' else ids[22:] if args.lote=='2' else ids
        for fid in selected:
            render(fid, forms.get(fid, forms['_padrao']), g)
            print('OK',fid,flush=True)


if __name__=='__main__':
    main()
