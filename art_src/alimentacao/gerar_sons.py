#!/usr/bin/env python3
"""Sons de comer e beber SINTETIZADOS (25/11/2026, decisão do dono: "sons próprios sintetizados"): Python puro, sem dependências.
    python3 art_src/alimentacao/gerar_sons.py        → assets/audio/alimentacao/*.wav  (mono, 22,05 kHz, 16 bit)
Famílias: morder_crocante (maçã), mastigar_macio (pão, refeição), rasgar (carne, peixe), sorver (sopa), gole (bebidas), engolir,
akuma_mordida (denso, com pancada grave) e akuma_arrepio (o poder subindo depois de engolir a Akuma no Mi). Variações _1.._3 para não repetir.
"""
import math
import os
import random
import struct
import wave

TAXA = 22050
SAIDA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "audio", "alimentacao")


def gravar(nome, amostras):
    pico = max(1e-9, max(abs(a) for a in amostras))
    g = 0.85 / pico if pico > 0.85 else 1.0
    with wave.open(os.path.join(SAIDA, nome + ".wav"), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(TAXA)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, a * g)) * 32767)) for a in amostras))


def ruido(n, rng):
    return [rng.uniform(-1, 1) for _ in range(n)]


def passa_baixa(x, fc):
    a = min(1.0, 2 * math.pi * fc / TAXA)
    y, s = [], 0.0
    for v in x:
        s += a * (v - s)
        y.append(s)
    return y


def passa_alta(x, fc):
    b = passa_baixa(x, fc)
    return [v - w for v, w in zip(x, b)]


def env(n, ataque, queda):
    return [min(1.0, i / max(1, ataque)) * math.exp(-i / max(1, queda)) for i in range(n)]


def soma(*faixas):
    n = max(len(f) for f in faixas)
    return [sum(f[i] if i < len(f) else 0.0 for f in faixas) for i in range(n)]


def atrasar(x, seg):
    return [0.0] * int(seg * TAXA) + x


def estalo(rng, dur=0.16, brilho=2500, forca=1.0):
    n = int(dur * TAXA)
    r = passa_alta(ruido(n, rng), brilho)
    e = env(n, int(0.002 * TAXA), int(0.035 * TAXA))
    return [v * k * forca for v, k in zip(r, e)]


def morder_crocante(sem):
    rng = random.Random(sem)
    base = estalo(rng, 0.20, 1800)
    micro = soma(*[atrasar(estalo(rng, 0.06, 3200, 0.5), 0.015 + 0.02 * i) for i in range(1 + rng.randint(1, 3))])
    return soma(base, micro)


def mastigar_macio(sem):
    rng = random.Random(sem)
    saida = []
    for i in range(2):
        n = int(0.16 * TAXA)
        r = passa_baixa(ruido(n, rng), 900 + 200 * rng.random())
        e = env(n, int(0.03 * TAXA), int(0.06 * TAXA))
        saida.append(atrasar([v * k for v, k in zip(r, e)], 0.15 * i))
    return soma(*saida)


def rasgar(sem):
    rng = random.Random(sem)
    n = int(0.34 * TAXA)
    r = passa_alta(passa_baixa(ruido(n, rng), 3200), 500)
    e = env(n, int(0.06 * TAXA), int(0.11 * TAXA))
    umido = [math.sin(2 * math.pi * (180 + 40 * rng.random()) * i / TAXA) * 0.15 * e[i] for i in range(n)]
    return soma([v * k for v, k in zip(r, e)], umido, atrasar(estalo(rng, 0.08, 1500, 0.5), 0.1))


def sorver(sem):
    rng = random.Random(sem)
    n = int(0.42 * TAXA)
    r = passa_alta(passa_baixa(ruido(n, rng), 2500), 700)
    e = [math.sin(math.pi * i / n) ** 1.5 for i in range(n)]
    gorgolejo = [math.sin(2 * math.pi * (300 + 220 * i / n) * i / TAXA + 4 * math.sin(2 * math.pi * 14 * i / TAXA)) * 0.12 * e[i] for i in range(n)]
    return soma([v * k * 0.8 for v, k in zip(r, e)], gorgolejo)


def gole(sem):
    rng = random.Random(sem)
    n = int(0.24 * TAXA)
    f0, f1 = 170 + 25 * rng.random(), 85 + 10 * rng.random()
    fase, saida = 0.0, []
    for i in range(n):
        f = f0 + (f1 - f0) * i / n
        fase += 2 * math.pi * f / TAXA
        saida.append(math.sin(fase) * math.sin(math.pi * i / n) ** 1.2)
    agua = passa_baixa(ruido(n, rng), 1400)
    return soma(saida, [v * 0.25 * math.sin(math.pi * i / n) for i, v in enumerate(agua)])


def engolir(sem):
    rng = random.Random(sem)
    n = int(0.30 * TAXA)
    fase, saida = 0.0, []
    for i in range(n):
        f = 260 - 150 * (i / n) ** 0.7
        fase += 2 * math.pi * f / TAXA
        saida.append(math.sin(fase) * math.sin(math.pi * (i / n) ** 0.6) )
    baixo = passa_baixa(ruido(n, rng), 600)
    return soma(saida, [v * 0.3 * math.sin(math.pi * i / n) for i, v in enumerate(baixo)])


def akuma_mordida(sem):
    rng = random.Random(sem)
    n = int(0.28 * TAXA)
    grave = [math.sin(2 * math.pi * 62 * i / TAXA) * math.exp(-i / (0.07 * TAXA)) for i in range(n)]
    return soma(estalo(rng, 0.26, 900, 1.2), grave, atrasar(estalo(rng, 0.12, 2500, 0.6), 0.04))


def akuma_arrepio(sem):
    n = int(1.1 * TAXA)
    fase, saida = 0.0, []
    for i in range(n):
        t = i / n
        f = 150 + 260 * t ** 1.5
        fase += 2 * math.pi * f / TAXA
        trem = 0.65 + 0.35 * math.sin(2 * math.pi * (7 + 8 * t) * i / TAXA)
        saida.append((math.sin(fase) + 0.4 * math.sin(2.01 * fase)) * trem * math.sin(math.pi * t) ** 1.4 * 0.5)
    return saida


FAMILIAS = {"morder_crocante": (morder_crocante, 3), "mastigar_macio": (mastigar_macio, 3), "rasgar": (rasgar, 2), "sorver": (sorver, 2),
            "gole": (gole, 3), "engolir": (engolir, 2), "akuma_mordida": (akuma_mordida, 2), "akuma_arrepio": (akuma_arrepio, 1)}

if __name__ == "__main__":
    os.makedirs(SAIDA, exist_ok=True)
    for nome, (fn, n) in FAMILIAS.items():
        for v in range(1, n + 1):
            gravar(f"{nome}_{v}", fn(v * 101 + len(nome)))
    print(len(os.listdir(SAIDA)), "arquivos em", os.path.normpath(SAIDA))
