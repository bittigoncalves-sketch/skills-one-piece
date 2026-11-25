#!/usr/bin/env python3
"""Montagens de referência a partir da captura e da fonte bitmap locais do jogo."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
ASCII = Image.open(ROOT / 'assets/minecraft_local/gui/ascii.png').convert('RGBA')
ACCENT = Image.open(ROOT / 'assets/minecraft_local/gui/accented.png').convert('RGBA')
BASE = Image.open(ROOT / 'art_src/validation/treino/0_antes.png').convert('RGBA').resize((1280, 720), Image.Resampling.LANCZOS)
ACCENTS = ['ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏ', 'ÐÑÒÓÔÕÖÙÚÛÜÝàáâã', 'äåæçìíîïñòóôõöùú', 'ûüýÿ']


def glyph(ch):
    if ch == ' ':
        return None, 4
    if 0x20 <= ord(ch) <= 0x7e:
        col, row = ord(ch) & 15, ord(ch) >> 4
        img = ASCII.crop((col * 8, row * 8, col * 8 + 8, row * 8 + 8))
        dy = 3
    else:
        loc = next(((row, line.index(ch)) for row, line in enumerate(ACCENTS) if ch in line), None)
        if ch in 'èéêë':
            loc = (15, 12 + 'èéêë'.index(ch))
        if loc is None:
            return glyph('?')
        row, col = loc
        img = ACCENT.crop((col * 9, row * 12, col * 9 + 9, row * 12 + 12))
        dy = 0
    bbox = img.getchannel('A').getbbox()
    if bbox is None:
        return None, 4
    return (img.crop((0, 0, bbox[2], img.height)), dy), bbox[2] + 1


def pixel_text(canvas, text, x, y, scale, color):
    for ch in text:
        item, advance = glyph(ch)
        if item:
            image, dy = item
            mask = image.getchannel('A').resize((image.width * scale, image.height * scale), Image.Resampling.NEAREST)
            canvas.paste((0, 0, 0, 210), (x + scale, y + dy * scale + scale), mask)
            canvas.paste(color, (x, y + dy * scale), mask)
        x += advance * scale
    return x


def make(filename, text, hint):
    im = BASE.copy()
    overlay = Image.new('RGBA', im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    d.rectangle((0, 0, 1280, 38), fill=(3, 5, 9, 255))
    d.rectangle((0, 701, 1280, 720), fill=(3, 5, 9, 255))
    d.rectangle((103, 460, 1177, 591), fill=(9, 14, 22, 226), outline=(39, 47, 57, 255), width=2)
    d.rectangle((104, 460, 1176, 463), fill=(206, 166, 91, 255))
    im = Image.alpha_composite(im, overlay)
    pixel_text(im, 'Instrutor', 132, 472, 2, (246, 201, 112, 255))
    pixel_text(im, text, 132, 505, 3, (250, 248, 237, 255))
    pixel_text(im, hint, 132, 555, 2, (192, 197, 201, 255))
    im.convert('RGB').save(OUT / filename, optimize=True)


make('01_primeira_fala.png', 'Todo lutador começa pelo básico. Vamos treinar seus socos?', 'E / ENTER / CLIQUE: AVANÇAR     ESC: PULAR')
make('02_recusa_e_controles.png', 'Continue sua jornada e encontre desafios à sua altura.', 'E / ENTER / CLIQUE: AVANÇAR     ESC: PULAR')
