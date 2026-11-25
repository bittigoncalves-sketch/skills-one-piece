#!/usr/bin/env python3
"""Pinta os atlas originais sobre os retângulos UV da reconstrução.

Execute na raiz do projeto: python3 art_src/reconstrucao/texturas/pintar_atlas.py
Cada pixel é opaco ou transparente; não usa imagens do mod.
"""
import hashlib
import json
import random
from pathlib import Path

from PIL import Image, ImageColor, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = Path(__file__).resolve().parent


def rgb(color):
    return ImageColor.getrgb(color)


def shade(color, amount):
    return tuple(max(0, min(255, c + amount)) for c in rgb(color)) + (255,)


def pixel(draw, rect, x, y, color):
    x0, y0, x1, y1 = rect
    if 0 <= x < x1 - x0 and 0 <= y < y1 - y0:
        draw.point((x0 + x, y0 + y), fill=color)


def build(mob, variant=1):
    data = json.loads((ROOT / f'{mob}.uv.json').read_text())
    image = Image.new('RGBA', tuple(data['atlas']), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    replacements = {
        2: {'camisa': '#335d70', 'braco_d': '#335d70', 'braco_e': '#335d70',
            'perna_d': '#4d403b', 'perna_e': '#4d403b', 'gola': '#ddd0ab'},
        3: {'camisa': '#794e82', 'braco_d': '#794e82', 'braco_e': '#794e82',
            'perna_d': '#354f46', 'perna_e': '#354f46', 'gola': '#d5c3a3'},
    }.get(variant, {}) if mob == 'pirate' else {}
    for part in data['cubos']:
        name = part['cubo']
        color = replacements.get(name, part['cor_sugerida'])
        for face, r in part['faces'].items():
            x0, y0, x1, y1 = r
            w, h = x1-x0, y1-y0
            if not w or not h:
                continue
            d.rectangle((x0, y0, x1-1, y1-1), fill=shade(color, 0))
            seed = int.from_bytes(hashlib.sha256(f'{mob}/{name}/{face}'.encode()).digest()[:8], 'big')
            rng = random.Random(seed)
            # The flecks represent material, not lighting on the whole face.
            for y in range(h):
                for x in range(w):
                    v = rng.random()
                    if mob == 'chouchou' and name in ('tronco', 'juba', 'cranio', 'bochechas', 'rabo_base', 'rabo_curva'):
                        if v < .12: pixel(d, r, x, y, shade(color, -19))
                        elif v > .91: pixel(d, r, x, y, shade(color, 17))
                    elif mob == 'suzume' and name in ('corpo', 'peito', 'pescoco', 'asa_d', 'asa_e'):
                        if v < .10: pixel(d, r, x, y, shade(color, -20))
                        elif v > .92: pixel(d, r, x, y, shade(color, 20))
                    elif mob == 'pirate' and name in ('camisa', 'braco_d', 'braco_e', 'perna_d', 'perna_e'):
                        if v < .045: pixel(d, r, x, y, shade(color, -15))
                        elif v > .97: pixel(d, r, x, y, shade(color, 12))
            if mob == 'pirate':
                pirate_detail(d, name, face, r, color)
            elif mob == 'chouchou':
                dog_detail(d, name, face, r, color)
            else:
                rooster_detail(d, name, face, r, color)
    filename = mob if variant == 1 else f'{mob}_v{variant}'
    image.save(OUT / f'{filename}.png')


def pirate_detail(d, name, face, r, color):
    w, h = r[2]-r[0], r[3]-r[1]
    p = lambda x, y, c: pixel(d, r, x, y, rgb(c) + (255,))
    if name == 'cabeca':
        if face == 'frente':
            # The separate eyepatch mesh covers the other eye.
            p(5, 2, '#f2e4cf'); p(5, 3, '#272221')
            for x in range(2, 6): p(x, 5, '#70483b')
            p(3, 6, '#8b5442'); p(4, 6, '#8b5442')
            for x, y in ((0,1),(1,1),(2,2),(3,2)): p(x,y,'#2a2528')
        elif face in ('direita', 'esquerda', 'tras'):
            for x in range(w): p(x, 0, '#332922')
    if name == 'camisa' and face == 'frente':
        for y in range(2, min(h, 10)):
            p(w//2, y, shade_hex(color, -24))
            if y % 3 == 0: p(w//2, y, '#d8b673')
        for x, y in ((1, 4),(2,5),(7,7),(6,8)): p(x,y,shade_hex(color,-17))
    if name.startswith('braco_') and face in ('frente', 'tras', 'direita', 'esquerda'):
        for x in range(w): p(x, h-3, shade_hex(color, -26))
    if name == 'cinto' and face == 'frente':
        for x in (w//2-1, w//2):
            p(x, 0, '#e6bd58'); p(x, 1, '#ad7d2c')
    if name.startswith('chapeu_') and face in ('frente', 'tras', 'direita', 'esquerda'):
        for x in range(w): p(x, h-1, '#a88039')
        if name == 'chapeu_copa' and face == 'frente':
            p(w//2, 0, '#e7d7a3'); p(w//2-1, 1, '#e7d7a3'); p(w//2+1, 1, '#e7d7a3')
    if name.startswith('bota_') and face in ('frente', 'direita', 'esquerda', 'tras'):
        for x in range(w): p(x, h-1, '#21170f')
        if h >= 3:
            for x in range(w): p(x, 0, '#573d29')
    if name == 'sabre_lamina' and face in ('direita', 'esquerda'):
        for x in range(w): p(x, 0, '#f1f3e9'); p(x, h-1, '#899ba8')


def shade_hex(color, offset):
    return '#%02x%02x%02x' % shade(color, offset)[:3]


def dog_detail(d, name, face, r, color):
    w, h = r[2]-r[0], r[3]-r[1]
    p = lambda x, y, c: pixel(d, r, x, y, rgb(c) + (255,))
    if name == 'cranio' and face == 'frente':
        for x in (1, 5):
            p(x, 1, '#714015'); p(x, 2, '#241c18'); p(x, 3, '#f1bf79')
    if name == 'juba' and face in ('frente', 'direita', 'esquerda', 'tras'):
        for x in range(0, w, 3):
            for y in range(2 + x % 2, h, 4):
                p(x, y, '#a8561b'); p(x+1, y+1, '#e49a43')
    if name == 'focinho' and face == 'frente':
        p(0, 2, '#7c3c17'); p(w-1, 2, '#7c3c17')
    if name == 'nariz' and face in ('frente', 'topo'):
        p(0, 0, '#48413b')
    if name == 'lingua' and face in ('frente', 'direita', 'esquerda'):
        p(0, h-1, '#202955')
    if name.startswith('pata_') and face in ('frente', 'direita', 'esquerda'):
        for x in range(w): p(x, h-1, '#804018')


def rooster_detail(d, name, face, r, color):
    w, h = r[2]-r[0], r[3]-r[1]
    p = lambda x, y, c: pixel(d, r, x, y, rgb(c) + (255,))
    if name == 'cabeca' and face in ('direita', 'esquerda'):
        p(1 if face == 'direita' else w-2, 1, '#271d19')
    if name == 'cabeca' and face == 'frente':
        p(0, 1, '#291e1a'); p(w-1, 1, '#291e1a')
    if name.startswith('asa_') and face in ('direita', 'esquerda'):
        for y in (1, 3):
            for x in range(1 + y % 2, w, 3):
                p(x, y, '#c05b26'); p(x+1, y+1, '#6c2916')
    if name in ('peito','pescoco') and face in ('frente','direita','esquerda'):
        for y in range(1,h,2):
            for x in range(y % 3,w,3): p(x,y,'#f1ae49')
    if name.startswith('cauda_') and not name.startswith('cauda_lado'):
        for y in range(h): p(y % w, y, '#153f36')
    if name in ('crista','barbela'):
        p(0, 0, '#ec3940')


if __name__ == '__main__':
    for item in ('pirate', 'chouchou', 'suzume'):
        build(item)
    build('pirate', 2)
    build('pirate', 3)
