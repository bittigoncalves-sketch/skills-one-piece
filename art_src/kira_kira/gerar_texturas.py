#!/usr/bin/env python3
"""Gera as cinco texturas pixel art da Kira Kira (Pillow)."""
from pathlib import Path
import math
import random

from PIL import Image, ImageDraw

DESTINO = Path(__file__).resolve().parents[2] / "assets/textures/kira_kira"
DESTINO.mkdir(parents=True, exist_ok=True)


def pedra(tamanho, intensa):
    rng = random.Random(418 if not intensa else 427)
    # As distâncias usam a topologia de um toro: a composição continua na borda.
    n = 11 if not intensa else 18
    pontos = [(rng.randrange(tamanho), rng.randrange(tamanho), rng.randrange(-7, 8)) for _ in range(n)]
    imagem = Image.new("RGBA", (tamanho, tamanho))
    for y in range(tamanho):
        for x in range(tamanho):
            dist = []
            for px, py, tom in pontos:
                dx = min(abs(x - px), tamanho - abs(x - px))
                dy = min(abs(y - py), tamanho - abs(y - py))
                dist.append((dx * dx + dy * dy, tom))
            dist.sort()
            diferenca = math.sqrt(dist[1][0]) - math.sqrt(dist[0][0])
            ruido = rng.choice((-3, -2, -1, 0, 0, 1, 2, 3))
            junta = -12 if diferenca < (0.32 if not intensa else 0.43) else 0
            v = dist[0][1] + ruido + junta
            imagem.putpixel((x, y), (max(0, 113 + v), max(0, 132 + v), max(0, 145 + v), 255))
    if intensa:
        # Trincas descontínuas e finas, repetidas através das bordas.
        for _ in range(9):
            x, y = rng.randrange(tamanho), rng.randrange(tamanho)
            dx, dy = rng.choice(((1, 0), (-1, 0), (0, 1), (0, -1)))
            for passo in range(rng.randrange(3, 7)):
                p = (x % tamanho, y % tamanho)
                r, g, b, _ = imagem.getpixel(p)
                imagem.putpixel(p, (r - 13, g - 13, b - 13, 255))
                x += dx
                y += dy
                if passo % 2 and rng.randrange(2):
                    x += dy
                    y += dx
    return imagem


def cristal():
    im = Image.new("RGBA", (16, 16), (123, 224, 255, 255))
    d = ImageDraw.Draw(im)
    # Planos assimétricos, com arestas descontínuas e cores sem suavização.
    d.polygon([(0, 0), (8, 0), (5, 6), (0, 9)], fill="#dffaff")
    d.polygon([(8, 0), (15, 0), (12, 5), (5, 6)], fill="#a4edff")
    d.polygon([(15, 0), (15, 10), (12, 5)], fill="#79dbf6")
    d.polygon([(0, 9), (5, 6), (8, 11), (4, 15), (0, 15)], fill="#9ceaff")
    d.polygon([(5, 6), (12, 5), (8, 11)], fill="#c8f7ff")
    d.polygon([(12, 5), (15, 10), (15, 15), (8, 11)], fill="#abedff")
    d.polygon([(8, 11), (15, 15), (4, 15)], fill="#e5fcff")
    d.line([(0, 9), (5, 6), (8, 11), (4, 15)], fill="#f5ffff", width=1)
    d.line([(5, 6), (8, 0)], fill="#edffff", width=1)
    d.line([(5, 6), (12, 5), (15, 10)], fill="#f5ffff", width=1)
    return im


def faisca():
    im = Image.new("RGBA", (32, 32))
    d = ImageDraw.Draw(im)
    # Estrela de 4 pontas com pixels de cobertura discretos, sem contorno escuro.
    d.polygon([(15, 1), (17, 1), (18, 11), (20, 13), (30, 15), (30, 17),
               (20, 19), (18, 21), (17, 30), (15, 30), (13, 21), (11, 19),
               (1, 17), (1, 15), (11, 13), (13, 11)], fill=(123, 224, 255, 180))
    d.polygon([(16, 4), (17, 13), (19, 15), (27, 16), (19, 17), (17, 19),
               (16, 27), (15, 19), (13, 17), (5, 16), (13, 15), (15, 13)], fill=(222, 251, 255, 255))
    d.rectangle((14, 14, 18, 18), fill=(255, 255, 255, 255))
    return im


def rachadura():
    im = Image.new("RGBA", (64, 64))
    d = ImageDraw.Draw(im)
    # Rede radial irregular, própria para decalque visto de cima.
    linhas = [
        [(31, 31), (29, 26), (30, 22), (26, 17), (27, 12), (23, 8), (23, 3)],
        [(32, 31), (35, 25), (34, 20), (39, 16), (39, 10), (43, 6)],
        [(33, 31), (39, 29), (42, 25), (48, 25), (52, 21), (59, 20)],
        [(34, 32), (40, 34), (43, 38), (49, 37), (54, 41), (61, 41)],
        [(33, 33), (36, 39), (35, 44), (40, 48), (40, 54), (43, 60)],
        [(31, 33), (28, 38), (29, 44), (25, 48), (25, 53), (21, 59)],
        [(30, 32), (24, 34), (21, 39), (15, 39), (11, 43), (4, 44)],
        [(30, 31), (24, 28), (20, 29), (16, 24), (10, 24), (5, 20)],
        [(26, 17), (21, 17), (18, 13)], [(39, 16), (45, 17), (48, 14)],
        [(48, 25), (51, 29), (55, 29)], [(43, 38), (44, 43), (48, 46)],
        [(35, 44), (30, 47), (29, 51)], [(21, 39), (20, 44), (16, 47)],
        [(20, 29), (17, 33), (12, 34)], [(29, 22), (25, 22), (23, 20)],
    ]
    for linha in linhas:
        d.line(linha, fill=(42, 60, 70, 220), width=1)
    d.line([(30, 31), (32, 30), (34, 32), (32, 34), (30, 32)], fill=(42, 60, 70, 235), width=1)
    return im


for nome, imagem in (
    ("pedra_x.png", pedra(16, False)),
    ("pedra_c.png", pedra(32, True)),
    ("cristal_facetas.png", cristal()),
    ("faisca_diamante.png", faisca()),
    ("rachadura_impacto.png", rachadura()),
):
    imagem.save(DESTINO / nome, optimize=True)
    print(f"{nome}: {imagem.size}, {imagem.mode}")
