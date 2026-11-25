#!/usr/bin/env python3
"""Gera as skins pixel-art 64×64 (layout do Minecraft) dos MACACOS HUMANOIDES da Ilha dos Macacos (18/11/2026). Autoria própria, determinística.
Saída: assets/textures/macacos/pelagem_macaco.png (comum) e pelagem_macaco_rei.png (o chefe, pelagem escura com juba dourada).
    python3 -I tools/mine_piece/gerar_skin_macaco.py
"""
import random
from pathlib import Path
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
SAIDA = RAIZ / "assets" / "textures" / "macacos"

def caixa(u, v, w, h, d):
    """Retângulos (x, y, largura, altura) das 6 faces de uma caixa no layout do Minecraft."""
    return {
        "topo": (u + d, v, w, d), "baixo": (u + d + w, v, w, d),
        "direita": (u, v + d, d, h), "frente": (u + d, v + d, w, h),
        "esquerda": (u + d + w, v + d, d, h), "costas": (u + d + w + d, v + d, w, h),
    }

PARTES = {
    "cabeca": caixa(0, 0, 8, 8, 8), "corpo": caixa(16, 16, 8, 12, 4),
    "braco_d": caixa(40, 16, 4, 12, 4), "perna_d": caixa(0, 16, 4, 12, 4),
    "braco_e": caixa(32, 48, 4, 12, 4), "perna_e": caixa(16, 48, 4, 12, 4),
}

def mistura(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def gerar(nome, pelo, pelo_claro, rosto, pelo_escuro, juba=None, semente=1):
    rng = random.Random(semente)
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    px = img.load()

    def preencher(ret, base, ruido=0.18, claro=None):
        x0, y0, w, h = ret
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                t = rng.random()
                cor = mistura(base, pelo_escuro if t < ruido else (claro or pelo_claro), 0.5 if t < ruido * 2 else 0.0) if t < ruido * 2 else base
                px[x, y] = cor + (255,)

    for parte, faces in PARTES.items():
        for face, ret in faces.items():
            preencher(ret, pelo)
    # barriga e peito mais claros
    c = PARTES["corpo"]
    preencher(c["frente"], pelo_claro, 0.1)
    for y in range(c["frente"][1], c["frente"][1] + 3):                       # ombros escuros
        for x in range(c["frente"][0], c["frente"][0] + 8):
            px[x, y] = mistura(pelo, pelo_escuro, 0.5) + (255,)
    # mãos e pés (a ponta de braço e perna) escuros e nus
    for p in ("braco_d", "braco_e"):
        f = PARTES[p]
        for face in ("frente", "costas", "direita", "esquerda"):
            x0, y0, w, h = f[face]
            for y in range(y0 + h - 3, y0 + h):
                for x in range(x0, x0 + w):
                    px[x, y] = rosto + (255,)
    for p in ("perna_d", "perna_e"):
        f = PARTES[p]
        for face in ("frente", "costas", "direita", "esquerda"):
            x0, y0, w, h = f[face]
            for y in range(y0 + h - 2, y0 + h):
                for x in range(x0, x0 + w):
                    px[x, y] = pelo_escuro + (255,)
    # cabeça: máscara de rosto clara (frente), orelhas (laterais), olhos, focinho e boca
    h = PARTES["cabeca"]
    fx, fy = h["frente"][0], h["frente"][1]
    for y in range(fy + 2, fy + 8):
        for x in range(fx + 1, fx + 7):
            if y >= fy + 3 or x in (fx + 2, fx + 3, fx + 4, fx + 5):
                px[x, y] = rosto + (255,)
    for y in range(fy + 5, fy + 8):                                            # focinho
        for x in range(fx + 2, fx + 6):
            px[x, y] = mistura(rosto, (255, 255, 255), 0.18) + (255,)
    for x in (fx + 2, fx + 5):                                                 # olhos: branco + pupila
        px[x, fy + 3] = (20, 14, 10, 255)
        px[x, fy + 2] = pelo_escuro + (255,)
    px[fx + 3, fy + 5] = (40, 26, 20, 255)                                      # narinas
    px[fx + 4, fy + 5] = (40, 26, 20, 255)
    for x in range(fx + 2, fx + 6):                                            # boca
        px[x, fy + 7] = (90, 48, 40, 255)
    for lado in ("direita", "esquerda"):                                       # orelhas
        ex, ey, ew, eh = h[lado]
        for y in range(ey + 2, ey + 5):
            for x in range(ex + 2, ex + 6):
                px[x, y] = mistura(rosto, pelo, 0.35) + (255,)
    if juba:                                                                    # juba (chefe): topo, costas da cabeça e ombros
        for ret in (h["topo"], h["costas"], h["direita"], h["esquerda"]):
            x0, y0, w, hh = ret
            for y in range(y0, y0 + max(2, hh // 2) if ret is not h["topo"] else y0 + hh):
                for x in range(x0, x0 + w):
                    px[x, y] = juba + (255,) if rng.random() > 0.25 else mistura(juba, pelo_escuro, 0.4) + (255,)
        for y in range(fy - 0, fy + 1):
            for x in range(fx, fx + 8):
                px[x, y] = juba + (255,)
        for p in ("braco_d", "braco_e"):
            x0, y0, w, hh = PARTES[p]["frente"]
            for x in range(x0, x0 + w):
                px[x, y0] = juba + (255,)
    SAIDA.mkdir(parents=True, exist_ok=True)
    img.save(SAIDA / nome, optimize=True)

gerar("pelagem_macaco.png", (150, 102, 56), (208, 160, 104), (232, 188, 140), (84, 52, 28), semente=7)
gerar("pelagem_macaco_rei.png", (86, 60, 44), (128, 94, 68), (210, 164, 124), (40, 28, 20), juba=(214, 168, 54), semente=11)
print("skins dos macacos gravadas em", SAIDA)
