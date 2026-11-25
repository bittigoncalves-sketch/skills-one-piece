"""Biblioteca de síntese das logias (só biblioteca padrão): filtros, envelopes, parciais, estalos.

Usada por `tools/generate_<fruta>_audio.py`. Mono, 48 kHz / 16 bit, pico -3 dBFS, fades curtos contra clique.
Criada em 24/11/2026 ao extrair o que era interno do gerador da Hie Hie, para a Moku e as próximas logias
repetirem a receita (ruído passa-banda varrendo + parciais inarmônicos + estalos) sem copiar código.
"""
from array import array
from pathlib import Path
import math
import random
import wave

RATE = 48000
TAU = math.tau


def n_amostras(seg):
    return int(seg * RATE)


def banda(entrada, corte, q=4.0, estagios=2):
    """Passa-banda ressonante (Chamberlin) com corte por amostra (lista) — o corte VARRE."""
    for _ in range(estagios):
        baixo = bnd = 0.0
        saida = []
        inv_q = 1.0 / q
        for x, fc in zip(entrada, corte):
            f = 2.0 * math.sin(math.pi * min(fc, RATE / 6.0) / RATE)
            alto = x - baixo - inv_q * bnd
            bnd += f * alto
            baixo += f * bnd
            saida.append(bnd)
        entrada = saida
    return entrada


def passa_baixa(entrada, fc, polos=2):
    a = 1.0 - math.exp(-TAU * fc / RATE)
    for _ in range(polos):
        y = 0.0
        saida = []
        for x in entrada:
            y += a * (x - y)
            saida.append(y)
        entrada = saida
    return entrada


def passa_alta(entrada, fc, polos=2):
    base = passa_baixa(entrada, fc, polos)
    return [x - b for x, b in zip(entrada, base)]


def ruido(rng, n):
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def varredura(n, de, ate, curva=1.0):
    return [de + (ate - de) * ((i / max(n - 1, 1)) ** curva) for i in range(n)]


def env_ad(n, ataque, queda):
    """Ataque linear curto, queda exponencial (queda = constante de tempo em s)."""
    na = max(1, n_amostras(ataque))
    saida = []
    for i in range(n):
        a = min(1.0, i / na)
        saida.append(a * math.exp(-(i / RATE) / queda))
    return saida


def tilintar(n, freqs, queda, ganho=1.0, atraso=0.0):
    """Parciais senoidais com queda exponencial: o 'ding' do cristal."""
    saida = [0.0] * n
    ini = n_amostras(atraso)
    for f, g in freqs:
        for i in range(ini, n):
            t = (i - ini) / RATE
            saida[i] += g * ganho * math.sin(TAU * f * t) * math.exp(-t / queda)
    return saida


def estalos(rng, n, quantos, ganho=0.8, minimo=0.0, maximo=None):
    """Estalos curtos de gelo rachando (cliques filtrados)."""
    saida = [0.0] * n
    fim = n if maximo is None else min(n, n_amostras(maximo))
    for _ in range(quantos):
        pos = rng.randint(n_amostras(minimo), max(n_amostras(minimo) + 1, fim - 400))
        f = rng.uniform(2500, 7000)
        g = rng.uniform(0.4, 1.0) * ganho
        for k in range(300):
            if pos + k < n:
                saida[pos + k] += g * math.sin(TAU * f * k / RATE) * math.exp(-k / 40.0)
    return saida


def somar(*trilhas):
    n = max(len(t) for t in trilhas)
    saida = [0.0] * n
    for t in trilhas:
        for i, v in enumerate(t):
            saida[i] += v
    return saida


def multiplicar(a, b):
    return [x * y for x, y in zip(a, b)]


def escalar(a, g):
    return [x * g for x in a]


def corpo_grave(n, f0, f1, queda, ganho=1.0):
    """Baque grave com a frequência caindo (f0 → f1)."""
    saida = []
    fase = 0.0
    for i in range(n):
        t = i / RATE
        f = f1 + (f0 - f1) * math.exp(-t / (queda * 0.5))
        fase += TAU * f / RATE
        saida.append(ganho * math.sin(fase) * math.exp(-t / queda))
    return saida


def normalizar(trilha, pico_db=-3.0, fade=0.004):
    pico = max(max(abs(v) for v in trilha), 1e-9)
    alvo = 10 ** (pico_db / 20.0)
    g = alvo / pico
    n = len(trilha)
    nf = max(1, n_amostras(fade))
    saida = []
    for i, v in enumerate(trilha):
        f = min(1.0, i / nf, (n - 1 - i) / nf)
        saida.append(v * g * f)
    return saida


def salvar(caminho, trilha):
    """Grava `trilha` normalizada (pico -3 dBFS) em `caminho` (WAV mono 48 kHz / 16 bit)."""
    Path(caminho).parent.mkdir(parents=True, exist_ok=True)
    pcm = array("h", [int(max(-1.0, min(1.0, v)) * 32767) for v in normalizar(trilha)])
    with wave.open(str(caminho), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


