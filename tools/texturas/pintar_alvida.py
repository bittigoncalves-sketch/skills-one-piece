#!/usr/bin/env python3
"""Textura nova da Alvida (22/11/2026): o atlas original (mapas/modelos/mp_alvida_corpo.png) tem 64×64 e o rosto da Alvida é um borrão de ~4 px.
Aqui o atlas sobe 4× (256×256; as UVs são normalizadas, o modelo não muda) e o ROSTO é repintado com olhos, sobrancelhas, nariz, bochechas e boca (tile 32×32 em vez de 8×8).
O rosto da camada de cabelo/chapéu (`armorHead`, a que aparece) fica no tile (8..16, 8..16) do atlas 64 = (32..64, 32..64) no 256.
Rodar da raiz:  python3 tools/texturas/pintar_alvida.py     Saída: assets/textures/desafio_buggy/mp_alvida_corpo.png (+ prévia em art_src/validation/alvida/)
"""
from PIL import Image
import os

ORIGEM = "mapas/modelos/mp_alvida_corpo.png"
SAIDA = "assets/textures/desafio_buggy/mp_alvida_corpo.png"
PREVIA = "art_src/validation/alvida/rosto_alvida.png"
ESC = 4
X0, Y0 = 8 * ESC, 8 * ESC          # tile do rosto (camada que aparece)

CABELO = (24, 20, 30, 255)
CABELO_LUZ = (58, 50, 72, 255)
PELE = (238, 198, 166, 255)
PELE_SOMBRA = (214, 166, 136, 255)
PELE_LUZ = (248, 214, 186, 255)
BRANCO = (250, 250, 252, 255)
ESCURO = (28, 18, 20, 255)
IRIS = (86, 70, 170, 255)
IRIS_ESCURA = (48, 38, 110, 255)
BROW = (50, 30, 26, 255)
BLUSH = (236, 140, 150, 255)
LABIO = (206, 62, 88, 255)
LABIO_ESCURO = (132, 28, 52, 255)
LABIO_LUZ = (236, 118, 136, 255)


def main():
    im = Image.open(ORIGEM).convert("RGBA")
    im = im.resize((im.width * ESC, im.height * ESC), Image.NEAREST)
    px = im.load()

    def p(c, r, cor):
        if 0 <= c < 32 and 0 <= r < 32:
            px[X0 + c, Y0 + r] = cor

    def rect(c0, r0, c1, r1, cor):
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                p(c, r, cor)

    # fundo: pele em tudo, depois o cabelo por cima
    rect(0, 0, 31, 31, PELE)
    # sombra suave nas laterais e queixo; luz na testa/bochecha
    rect(4, 10, 5, 31, PELE_SOMBRA); rect(26, 10, 27, 31, PELE_SOMBRA)
    rect(6, 28, 25, 31, PELE_SOMBRA)
    rect(11, 11, 20, 13, PELE_LUZ)
    # cabelo: topo + franja repartida ao meio + laterais
    rect(0, 0, 31, 9, CABELO)
    for c in (3, 8, 14, 19, 25, 29):                                   # fios de brilho (curtos, desencontrados)
        p(c, 2, CABELO_LUZ); p(c + 1, 3, CABELO_LUZ); p(c + 1, 7, CABELO_LUZ); p(c + 2, 8, CABELO_LUZ)
    rect(0, 10, 9, 12, CABELO); rect(22, 10, 31, 12, CABELO)          # franja
    rect(0, 13, 7, 14, CABELO); rect(24, 13, 31, 14, CABELO)
    rect(10, 10, 12, 10, CABELO); rect(19, 10, 21, 10, CABELO)        # risca ao meio
    rect(0, 15, 3, 24, CABELO); rect(28, 15, 31, 24, CABELO)          # laterais
    rect(0, 25, 1, 31, CABELO); rect(30, 25, 31, 31, CABELO)
    for r in range(15, 24, 3):
        p(1, r, CABELO_LUZ); p(30, r, CABELO_LUZ)
    # sobrancelhas (firmes, levemente inclinadas: personagem brava)
    rect(7, 15, 8, 15, BROW); rect(9, 14, 13, 14, BROW)
    rect(23, 15, 24, 15, BROW); rect(18, 14, 22, 14, BROW)
    # olhos: cílio superior grosso, esclera, íris roxa com pupila e brilho, sombra embaixo
    for ec in (7, 19):
        rect(ec, 17, ec + 5, 17, ESCURO)                               # cílio
        p(ec - 1, 17, ESCURO); p(ec + 6, 17, ESCURO)                   # canto marcado
        rect(ec, 18, ec + 5, 21, BRANCO)
        rect(ec + 2, 18, ec + 4, 21, IRIS)
        rect(ec + 3, 19, ec + 4, 20, ESCURO)                          # pupila
        p(ec + 2, 18, IRIS_ESCURA); p(ec + 3, 18, IRIS_ESCURA); p(ec + 4, 18, IRIS_ESCURA)
        p(ec + 2, 19, BRANCO)                                          # brilho
        rect(ec, 22, ec + 5, 22, PELE_SOMBRA)                          # bolsa/sombra
    # nariz: ponte sutil e narinas
    rect(15, 20, 16, 23, PELE_SOMBRA)
    p(14, 24, PELE_SOMBRA); p(17, 24, PELE_SOMBRA); p(15, 24, ESCURO); p(16, 24, ESCURO)
    p(15, 22, PELE_LUZ); p(16, 21, PELE_LUZ)
    # bochechas
    rect(6, 23, 9, 25, BLUSH); rect(22, 23, 25, 25, BLUSH)
    # boca (em repouso): batom rosa-escuro, sorriso de canto
    rect(12, 27, 19, 27, LABIO_ESCURO)
    rect(13, 26, 18, 26, LABIO); rect(13, 28, 18, 28, LABIO); rect(14, 29, 17, 29, LABIO)
    p(11, 26, LABIO_ESCURO); p(20, 26, LABIO_ESCURO)
    p(15, 26, LABIO_LUZ); p(16, 26, LABIO_LUZ); p(15, 28, LABIO_LUZ)
    os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
    im.save(SAIDA)
    os.makedirs(os.path.dirname(PREVIA), exist_ok=True)
    im.crop((X0, Y0, X0 + 32, Y0 + 32)).resize((384, 384), Image.NEAREST).save(PREVIA)
    print("ok", SAIDA, im.size)


if __name__ == "__main__":
    main()
