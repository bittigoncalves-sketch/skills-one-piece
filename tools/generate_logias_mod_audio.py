"""Sons das LOGIAS DO FLUXO DO MOD (Mera, Magu, Suna, Yami, Mori): uma carga por fruta + um disparo por técnica. Só biblioteca padrão.

    python3 tools/generate_logias_mod_audio.py

Saída: assets/mine_piece/frutas/logias_mod/sons/<fruta>_carga.wav e <fruta>_<numero>.wav (mono 48 kHz / 16 bit, pico -3 dBFS).
Cada fruta tem uma família de timbre (`tools/audio/sintese.py`); cada técnica é uma variação dela (duração, brilho, grave, pitch):
  mera (fogo)   ruído passa-baixa/banda que ruge + estalos de brasa; mais técnica = mais longo e grave
  magu (magma)  rumor grave + bolhas (rajadas de seno grave) + estouro que cai de frequência
  suna (areia)  ruído seco passa-alta granulado (grãos = cliques) + vento que varre
  yami (trevas) drone grave desafinado + chupão (banda que sobe e corta) + baque surdo
  mori (madeira) rangido (banda ressonante com AM lenta) + batida de madeira (seno amortecido) + folhas (ruído agudo em rajadas)
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "audio"))
from sintese import *   # noqa: F401,F403

OUT = Path(__file__).resolve().parents[1] / "assets" / "mine_piece" / "frutas" / "logias_mod" / "sons"

# fruta → técnicas (números do mod, na ordem das teclas)
TECNICAS = {
    "mera": [21, 22, 23, 24, 25, 26],
    "magu": [21, 22, 23, 24],
    "suna": [21, 22, 23, 24, 25],
    "yami": [21, 22, 23, 28],
    "mori": [21, 22, 23, 24],
}


def tremolo(trilha, hz, prof):
    return [v * (1.0 - prof + prof * 0.5 * (1 + math.sin(TAU * hz * i / RATE))) for i, v in enumerate(trilha)]


def rampa(n, expoente=1.0):
    return [(i / max(1, n - 1)) ** expoente for i in range(n)]


# ------------------------------------------------------------------ fogo
def mera(rng, i, carga):
    dur = 0.7 if carga else 0.7 + 0.18 * i
    n = n_amostras(dur)
    base = 350 + 120 * i
    rugido = passa_baixa(banda(ruido(rng, n), varredura(n, base, base * 4.5, 0.8), q=1.6), 3500)
    rugido = multiplicar(rugido, rampa(n, 1.5) if carga else env_ad(n, 0.02, dur * 0.45))
    brasa = estalos(rng, n, 10 + 5 * i, 0.4, 0.0)
    corpo = corpo_grave(n, 150 - 8 * i, 55, 0.2 + 0.03 * i, 0.6 if not carga else 0.0)
    return somar(escalar(rugido, 1.2), brasa, corpo)


# ---------------------------------------------------------------- magma
def magu(rng, i, carga):
    dur = 0.9 if carga else 1.0 + 0.25 * i
    n = n_amostras(dur)
    rumor = multiplicar(passa_baixa(ruido(rng, n), 260 + 40 * i), rampa(n, 1.3) if carga else env_ad(n, 0.04, dur * 0.5))
    bolhas = [0.0] * n
    for _ in range(8 + 4 * i):   # bolhas de lava: seno grave curto que sobe
        t0 = rng.randrange(0, max(1, n - 5000))
        f0 = rng.uniform(70, 160)
        for k in range(4800):
            bolhas[t0 + k] += 0.3 * math.sin(TAU * (f0 + 90 * k / 4800) * k / RATE) * math.exp(-k / 900.0)
    estouro = corpo_grave(n, 140 - 10 * i, 36, 0.35 + 0.05 * i, 0.0 if carga else 1.0)
    return somar(escalar(rumor, 1.3), bolhas, estouro, estalos(rng, n, 5, 0.25))


# ---------------------------------------------------------------- areia
def suna(rng, i, carga):
    dur = 0.65 if carga else 0.6 + 0.15 * i
    n = n_amostras(dur)
    graos = passa_alta(ruido(rng, n), 2500 + 300 * i)
    graos = multiplicar(graos, [1.0 if rng.random() < 0.35 else 0.15 for _ in range(n)])   # granulado: grãos que pulam
    graos = passa_baixa(graos, 9000)
    graos = multiplicar(graos, rampa(n, 1.3) if carga else env_ad(n, 0.01, dur * 0.4))
    vento = multiplicar(banda(ruido(rng, n), varredura(n, 700 + 200 * i, 3500, 0.7), q=2.0), env_ad(n, 0.05, dur * 0.5))
    return somar(escalar(graos, 1.1), escalar(vento, 0.8), estalos(rng, n, 6, 0.2, 0.0))


# --------------------------------------------------------------- trevas
def yami(rng, i, carga):
    dur = 1.0 if carga else 1.0 + 0.3 * i
    n = n_amostras(dur)
    drone = [0.0] * n
    for desafino, g in ((1.0, 0.4), (1.012, 0.35), (0.5, 0.45)):
        f0 = (48 + 8 * i) * desafino
        for k in range(n):
            drone[k] += g * math.sin(TAU * f0 * k / RATE) * (0.4 + 0.6 * math.sin(math.pi * k / n))
    chupao = multiplicar(banda(ruido(rng, n), varredura(n, 300, 2600 + 400 * i, 2.0), q=3.0), [r ** 2 for r in rampa(n)])
    chupao = multiplicar(chupao, [1.0 if k < n - n_amostras(0.05) else 0.0 for k in range(n)])
    baque = corpo_grave(n, 90, 30, 0.5, 0.0 if carga else 1.0)
    return somar(escalar(drone, 0.8), escalar(chupao, 0.9), baque)


# -------------------------------------------------------------- madeira
def mori(rng, i, carga):
    dur = 0.7 if carga else 0.6 + 0.15 * i
    n = n_amostras(dur)
    range_ = tremolo(banda(ruido(rng, n), varredura(n, 400 + 80 * i, 900 + 150 * i, 1.0), q=9.0), 9 + i, 0.6)
    range_ = multiplicar(range_, rampa(n, 1.2) if carga else env_ad(n, 0.03, dur * 0.5))
    batida = [0.0] * n
    for k in range(n):
        t = k / RATE
        batida[k] = (0.0 if carga else 1.0) * (math.sin(TAU * (210 - 12 * i) * t) + 0.5 * math.sin(TAU * (420 - 24 * i) * t)) * math.exp(-t / 0.07)
    folhas = multiplicar(passa_alta(ruido(rng, n), 3200), [1.0 if rng.random() < 0.25 else 0.1 for _ in range(n)])
    folhas = multiplicar(passa_baixa(folhas, 8000), env_ad(n, 0.02, dur * 0.4))
    return somar(escalar(range_, 1.3), escalar(batida, 0.8), escalar(folhas, 0.5))


FAMILIAS = {"mera": mera, "magu": magu, "suna": suna, "yami": yami, "mori": mori}


def main():
    for fruta, numeros in TECNICAS.items():
        fn = FAMILIAS[fruta]
        salvar(OUT / f"{fruta}_carga.wav", fn(random.Random(sum(map(ord, fruta))), 0, True))
        print("ok", fruta, "carga")
        for i, numero in enumerate(numeros):
            salvar(OUT / f"{fruta}_{numero}.wav", fn(random.Random(numero * 31 + i), i, False))
            print("ok", fruta, numero)


if __name__ == "__main__":
    main()
