"""Sons da PIKA PIKA NO MI (Mine Piece), um conjunto por técnica. Só biblioteca padrão.

    python3 tools/generate_pika_mp_audio.py

Saída: assets/mine_piece/frutas/pika/sons/pika_<cue>.wav (mono 48 kHz / 16 bit, pico -3 dBFS).
Lei da fruta (medida em `tools/generate_pika_audio.py`, do vídeo de referência do dono): LUZ NÃO TEM GRAVE —
tudo passa por passa-alta de 300 Hz. Timbre = ruído passa-banda que VARRE entre 2 e 10 kHz + "glints" tonais.
Diferença para o arquivo da arena: aqui há um cue por técnica do Mine Piece (Laser, Amano-Iwato, Espelho,
Aceleração, Yasakani, Espada, passiva do toque duplo).
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "audio"))
from sintese import *   # noqa: F401,F403

OUT = Path(__file__).resolve().parents[1] / "assets" / "mine_piece" / "frutas" / "pika" / "sons"
PISO = 300.0


def luz(rng, n, de, ate, q=5.0, curva=1.0):
    return passa_alta(banda(ruido(rng, n), varredura(n, de, ate, curva), q=q), PISO)


def glints(n, freqs, queda, ganho, atraso=0.0):
    return passa_alta(tilintar(n, [(f, g) for f, g in freqs], queda, ganho, atraso), PISO)


def laser_carga(rng):
    n = n_amostras(0.8)
    v = multiplicar(luz(rng, n, 2000, 5800, 6.0, 1.3), [min(1.0, i / n_amostras(0.6)) ** 1.5 for i in range(n)])
    return somar(escalar(v, 1.0), glints(n, [(4200, 0.7), (6300, 0.4)], 0.5, 0.25, 0.1))


def laser_feixe(rng):
    n = n_amostras(1.1)
    v = luz(rng, n, 5200, 9000, 7.0, 0.7)
    v = multiplicar(v, env_ad(n, 0.02, 0.55))
    tremor = [0.75 + 0.25 * math.sin(TAU * 38 * i / RATE) for i in range(n)]
    return somar(escalar(multiplicar(v, tremor), 1.1), glints(n, [(7200, 0.5)], 0.4, 0.2))


def laser_explosao(rng):
    n = n_amostras(0.9)
    estouro = multiplicar(passa_alta(ruido(rng, n), 600), env_ad(n, 0.001, 0.12))
    corpo = multiplicar(luz(rng, n, 4500, 2200, 2.5, 0.6), env_ad(n, 0.004, 0.3))
    return somar(escalar(estouro, 1.0), escalar(corpo, 0.9), glints(n, [(3300, 0.8), (5100, 0.5), (8200, 0.3)], 0.35, 0.02))


def espelho_salto(rng):
    n = n_amostras(0.45)
    zip_ = multiplicar(luz(rng, n, 9000, 2400, 4.0, 0.5), env_ad(n, 0.003, 0.14))
    return somar(escalar(zip_, 1.2), glints(n, [(6800, 0.5)], 0.12, 0.3, 0.0))


def espelho_chute(rng):
    n = n_amostras(0.4)
    crack = multiplicar(passa_alta(ruido(rng, n), 1800), env_ad(n, 0.001, 0.04))
    return somar(escalar(crack, 1.0), glints(n, [(2800, 1.0), (4400, 0.6), (7000, 0.4)], 0.1, 0.5))


def velocidade_soco(rng):
    n = n_amostras(0.5)
    ticks = [0.0] * n
    for k in range(5):   # cinco socos de luz em rajada
        t0 = n_amostras(0.02 + 0.07 * k)
        for j in range(380):
            if t0 + j < n:
                ticks[t0 + j] += math.sin(TAU * (2600 + 350 * k) * j / RATE) * math.exp(-j / 70.0) + rng.uniform(-0.3, 0.3) * math.exp(-j / 40.0)
    return passa_alta(ticks, 800)


def velocidade_passo(rng):
    n = n_amostras(0.35)
    v = multiplicar(luz(rng, n, 7000, 3000, 3.0, 0.6), env_ad(n, 0.002, 0.09))
    return escalar(v, 1.1)


def yasakani_disparo(rng):
    n = n_amostras(0.9)
    chuva = [0.0] * n
    for _ in range(26):   # as joias lançadas, cada uma um tilintar
        f = rng.uniform(3000, 8500)
        t0 = rng.uniform(0.0, 0.5)
        chuva = somar(chuva, tilintar(n, [(f, 1.0), (f * 1.5, 0.3)], rng.uniform(0.04, 0.12), 0.2, t0))
    v = multiplicar(luz(rng, n, 3000, 7500, 4.0), env_ad(n, 0.01, 0.35))
    return passa_alta(somar(chuva, escalar(v, 0.7)), PISO)


def yasakani_final(rng):
    n = n_amostras(1.0)
    acorde = glints(n, [(2400, 1.0), (3600, 0.8), (4800, 0.7), (7200, 0.5)], 0.45, 0.3, 0.0)
    brilho = multiplicar(luz(rng, n, 4000, 9000, 5.0), env_ad(n, 0.03, 0.4))
    return somar(acorde, escalar(brilho, 0.6))


def espada_saca(rng):
    n = n_amostras(0.9)
    metal = glints(n, [(2500, 1.0), (3720, 0.8), (5900, 0.6), (8100, 0.35)], 0.5, 0.35)
    raspar = multiplicar(luz(rng, n, 3000, 8000, 3.0, 0.7), env_ad(n, 0.002, 0.1))
    return somar(metal, escalar(raspar, 0.9))


def espada_brilho(rng):
    n = n_amostras(0.9)
    shimmer = multiplicar(luz(rng, n, 3500, 9000, 8.0, 1.0), [math.sin(math.pi * i / n) for i in range(n)])
    return somar(escalar(tremolo_(shimmer, 24, 0.5), 1.0), glints(n, [(5400, 0.5)], 0.7, 0.2, 0.2))


def tremolo_(trilha, hz, prof):
    return [v * (1.0 - prof + prof * 0.5 * (1 + math.sin(TAU * hz * i / RATE))) for i, v in enumerate(trilha)]


def passiva_ida(rng):
    n = n_amostras(0.3)
    v = multiplicar(luz(rng, n, 2500, 9500, 4.0, 0.5), env_ad(n, 0.002, 0.09))
    return escalar(v, 1.2)


def passiva_chegada(rng):
    n = n_amostras(0.4)
    v = multiplicar(luz(rng, n, 9000, 3000, 4.0, 0.6), env_ad(n, 0.002, 0.11))
    return somar(escalar(v, 1.0), glints(n, [(5200, 0.7), (7800, 0.4)], 0.15, 0.3, 0.02))


def luz_estouro(rng):
    n = n_amostras(0.25)
    return somar(glints(n, [(4400, 1.0), (6600, 0.6)], 0.06, 0.6), escalar(multiplicar(passa_alta(ruido(rng, n), 2500), env_ad(n, 0.001, 0.025)), 0.6))


CUES = {
    "laser_carga": laser_carga, "laser_feixe": laser_feixe, "laser_explosao": laser_explosao,
    "espelho_salto": espelho_salto, "espelho_chute": espelho_chute,
    "velocidade_soco": velocidade_soco, "velocidade_passo": velocidade_passo,
    "yasakani_disparo": yasakani_disparo, "yasakani_final": yasakani_final,
    "espada_saca": espada_saca, "espada_brilho": espada_brilho,
    "passiva_ida": passiva_ida, "passiva_chegada": passiva_chegada, "luz_estouro": luz_estouro,
}


def main():
    for i, (nome, fn) in enumerate(CUES.items()):
        salvar(OUT / f"pika_{nome}.wav", fn(random.Random(2611 + i)))
        print("ok", nome)


if __name__ == "__main__":
    main()
