#!/usr/bin/env python3
"""Gera materiais autorais em pixel art; Pillow, sem fontes externas."""
from pathlib import Path
import math
import random
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'assets/textures/ilha_macacos'
OUT.mkdir(parents=True, exist_ok=True)
N = 32


def tile(seed, palette, kind):
    rng = random.Random(seed)
    image = Image.new('RGBA', (N, N))
    p = image.load()
    # A topologia de desenho é toroidal. A última linha/coluna duplicam a
    # primeira, evitando mudanças abruptas também ao copiar para um atlas.
    noise = [[rng.random() for _ in range(31)] for _ in range(31)]
    for y in range(31):
        for x in range(31):
            n = noise[y][x]
            k = 1 if n < .14 else 2 if n > .92 else 0
            if kind == 'fur':
                k = 1 if (x + 2 * (y // 4)) % 9 in (0, 1) and y % 5 < 4 else k
            elif kind == 'skin':
                k = 1 if (y % 8 == 0 and x % 11 < 7) else k
            elif kind == 'bone':
                k = 1 if x % 13 == 0 and y % 7 < 4 else k
            elif kind == 'wood':
                k = 1 if (y % 8 == 0 or (x + y // 8 * 9) % 19 == 0 and y % 8 < 4) else (2 if y % 8 == 1 else k)
            elif kind == 'bamboo':
                k = 1 if x % 10 in (0, 1) or (y + (x // 10) * 6) % 15 == 0 else (2 if x % 10 == 3 else k)
            elif kind == 'thatch':
                k = 1 if (x + y * 2) % 7 == 0 or y % 10 == 0 else (2 if (x + 2*y) % 7 == 1 else k)
            elif kind == 'rope':
                k = 1 if (x + y) % 9 in (0, 1) or (x - y) % 9 == 0 else (2 if (x + y) % 9 == 2 else k)
            elif kind == 'stone':
                line = y % 10 == 0 or (x + (y // 10 % 2) * 8) % 16 == 0
                k = 1 if line else (2 if n > .82 else 0)
            elif kind == 'moss':
                line = y % 10 == 0 or (x + (y // 10 % 2) * 8) % 16 == 0
                moss = ((x * 7 + y * 11 + (x // 4) * 13) % 37 < 6 and y % 10 < 7)
                k = 1 if line else (3 if moss else 2 if n > .86 else 0)
            elif kind == 'teeth':
                k = 2 if 8 <= y % 16 <= 11 and x % 5 != 0 else 0
            p[x, y] = (*palette[k], 255)
    for i in range(31):
        p[31, i] = p[0, i]
        p[i, 31] = p[i, 0]
    p[31, 31] = p[0, 0]
    return image


def colors(*hexes):
    return [tuple(bytes.fromhex(h.lstrip('#'))) for h in hexes]


# Cada variação é cor local e granulação do material, sem sombras direcionais.
specs = [
 ('pelagem_preta_azulada', 'fur', ['1d263b','141c2c','2b3853']),
 ('pelagem_azulada', 'fur', ['303e58','202e47','41516c']),
 ('dorso_prateado_claro', 'fur', ['aeb3bf','8c94a4','c5c9d1']),
 ('dorso_prateado_escuro', 'fur', ['777f8e','616b7c','959dab']),
 ('pele_rosto', 'skin', ['484652','3b3945','5c5964']),
 ('focinho_nariz', 'skin', ['35333c','292832','494750']),
 ('palma_sola', 'skin', ['605a60','4c484f','746d72']),
 ('unha', 'bone', ['858080','6f6969','999392']),
 ('coroa_madeira', 'wood', ['6e4e31','4e3728','876642']),
 ('osso', 'bone', ['d3c8a5','b2a482','e5dbbf']),
 ('pedra_ombreira', 'stone', ['777b79','5e6260','898c85']),
 ('pedra_musgo', 'moss', ['747a6d','555c52','899080','71834c']),
 ('olho_branco', 'skin', ['e9e6d2','d6d0ba','f5f1e1']),
 ('olho_vermelho', 'skin', ['b8242b','821c24','ed4a3e']),
 ('boca_dentes', 'teeth', ['483138','34262c','dcd0ae']),
 ('reserva', 'skin', ['798542','5c6933','98a958']),
]

atlas = Image.new('RGBA', (128, 128))
for i, (_, kind, palette) in enumerate(specs):
    atlas.paste(tile(1900 + i, colors(*palette), kind), ((i % 4) * 32, (i // 4) * 32))
atlas.save(OUT / 'gorila_rei_atlas.png')

materials = [
 ('terra_batida', 'skin', ['806344','6d523a','927554']),
 ('grama_praca', 'fur', ['69844a','58713f','7d9757']),
 ('calcamento_musgoso', 'moss', ['787a6c','595e55','8b8e80','7f934d']),
 ('madeira_tabua', 'wood', ['886442','65492f','a78054']),
 ('bambu', 'bamboo', ['a69a56','7b7545','c0b472']),
 ('palha_telhado', 'thatch', ['b29a60','8f794a','d0b878']),
 ('corda', 'rope', ['b59969','8a704b','d2bb86']),
 ('pedra_trono', 'moss', ['686d68','4b514c','80867b','72834c']),
 ('areia_praia', 'skin', ['d8c497','c5af82','e5d4ad']),
]
for i, (name, kind, palette) in enumerate(materials):
    tile(2900+i, colors(*palette), kind).save(OUT / f'{name}.png')
print('Gerados: atlas 128x128 e', len(materials), 'texturas 32x32.')
