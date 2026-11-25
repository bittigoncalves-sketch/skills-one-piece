#!/usr/bin/env python3
"""Gera texturas pixel art da luta do Buggy. Requer Pillow."""
from pathlib import Path
import random
from PIL import Image, ImageDraw

DESTINO = Path(__file__).resolve().parents[2] / "assets/textures/luta_do_buggy"
DESTINO.mkdir(parents=True, exist_ok=True)


def lona():
    rng = random.Random(4001)
    im = Image.new("RGBA", (32, 32))
    for y in range(32):
        for x in range(32):
            # A faixa cruza o tile inteiro e continuará alinhada ao repetir no eixo X.
            faixa = 4 if 14 <= y <= 16 else 0
            trama = 1 if (x + y) % 2 else -1
            desgaste = rng.choice((0, 0, 0, 0, -1, -2, 1))
            v = trama + desgaste - faixa
            im.putpixel((x, y), (240 + v, 232 + v, 211 + v, 255))
    return im


def corda():
    im = Image.new("RGBA", (16, 16))
    for y in range(16):
        for x in range(16):
            # Trança diagonal periódica para repetição nas duas direções.
            fase = (x + y) % 8
            cor = (174, 40, 46, 255) if fase in (0, 1) else (196, 49, 54, 255)
            if fase == 4:
                cor = (218, 69, 70, 255)
            im.putpixel((x, y), cor)
    return im


def poste():
    im = Image.new("RGBA", (16, 16), (148, 155, 159, 255))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 15, 3), fill=(190, 47, 53, 255))
    d.line((0, 1, 15, 1), fill=(222, 70, 73, 255))
    d.line((2, 4, 2, 15), fill=(174, 181, 184, 255))
    d.line((12, 4, 12, 15), fill=(129, 138, 143, 255))
    d.point([(5, 7), (10, 11), (6, 14)], fill=(160, 168, 171, 255))
    return im


LETRAS = {
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    "G": ["01111", "10000", "10000", "10111", "10001", "10001", "01111"],
    "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
}


def saia():
    im = Image.new("RGBA", (64, 16), (133, 28, 39, 255))
    d = ImageDraw.Draw(im)
    d.line((0, 0, 63, 0), fill=(165, 43, 48, 255))
    d.line((0, 15, 63, 15), fill=(108, 23, 34, 255))
    # Fonte bitmap 5x7 ampliada 2x; a palavra ocupa 58x14 pixels.
    for i, letra in enumerate("BUGGY"):
        for y, linha in enumerate(LETRAS[letra]):
            for x, ligado in enumerate(linha):
                if ligado == "1":
                    d.rectangle((3 + i * 12 + x * 2, 1 + y * 2,
                                 4 + i * 12 + x * 2, 2 + y * 2), fill=(251, 205, 76, 255))
    return im


def luva():
    im = Image.new("RGBA", (16, 16), (189, 35, 45, 255))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 15, 2), fill=(204, 45, 52, 255))
    d.rectangle((2, 3, 5, 4), fill=(244, 105, 101, 255))
    d.rectangle((1, 5, 3, 6), fill=(230, 76, 77, 255))
    d.rectangle((11, 4, 14, 9), fill=(174, 29, 42, 255))
    d.line((4, 10, 13, 10), fill=(167, 29, 42, 255))
    d.rectangle((0, 12, 15, 15), fill=(239, 234, 220, 255))
    d.line((0, 12, 15, 12), fill=(255, 251, 240, 255))
    d.line((0, 15, 15, 15), fill=(212, 208, 199, 255))
    return im


def selo():
    im = Image.new("RGBA", (32, 32))
    d = ImageDraw.Draw(im)
    d.polygon([(16, 2), (27, 6), (27, 17), (24, 23), (16, 29), (8, 23), (5, 17), (5, 6)], fill=(180, 45, 53, 255))
    d.polygon([(16, 5), (24, 8), (24, 17), (21, 21), (16, 25), (11, 21), (8, 17), (8, 8)], fill=(241, 205, 102, 255))
    d.polygon([(16, 7), (22, 9), (22, 17), (20, 20), (16, 23), (12, 20), (10, 17), (10, 9)], fill=(231, 225, 204, 255))
    # Letra F nativa em pixels, contrastante em fundo claro.
    d.rectangle((13, 10, 19, 11), fill=(159, 37, 46, 255))
    d.rectangle((13, 10, 14, 20), fill=(159, 37, 46, 255))
    d.rectangle((13, 14, 18, 15), fill=(159, 37, 46, 255))
    return im


for nome, imagem in (
    ("ringue_lona.png", lona()), ("ringue_corda.png", corda()),
    ("ringue_poste.png", poste()), ("ringue_saia.png", saia()),
    ("luva_vermelha.png", luva()), ("luta_selo_f.png", selo()),
):
    imagem.save(DESTINO / nome, optimize=True)
    print(f"{nome}: {imagem.size}, {imagem.mode}")
