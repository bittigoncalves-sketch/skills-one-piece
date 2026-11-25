"""Sons da MOKU MOKU NO MI (fumaça), um conjunto por técnica. Só biblioteca padrão.

    python3 tools/generate_moku_audio.py

Saída: assets/mine_piece/frutas/moku/sons/moku_<cue>.wav (mono 48 kHz / 16 bit, pico -3 dBFS).
Receita (`tools/audio/sintese.py`): oposto da Hie — nada de cristal. Fumaça = ruído passa-baixa/banda
macio (sopros, cortinas), baques graves que caem de frequência (o punho e a nuvem têm massa) e caudas
longas e arejadas; estalos só no impacto.

Cues por técnica:
  punho_carga, punho_soco        — White Fist
  cipo_carga, cipo_sobe          — White Vine (o corpo vira fumaça e sobe)
  lancador_carga, lancador_tiro  — White Launcher
  white_out_carga, white_out_nuvem — White Out
  impacto, fumaca                — comuns
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "audio"))
from sintese import *   # noqa: F401,F403

OUT = Path(__file__).resolve().parents[1] / "assets" / "mine_piece" / "frutas" / "moku" / "sons"


def sopro(rng, n, de, ate, q=1.6, curva=1.0):
    return banda(ruido(rng, n), varredura(n, de, ate, curva), q=q, estagios=2)


def rampa(n, expoente=1.0, fim=1.0):
    return [min(1.0, (i / max(1, int(n * fim)))) ** expoente for i in range(n)]


def tremolo(trilha, hz, prof=0.4):
    return [v * (1.0 - prof + prof * 0.5 * (1 + math.sin(TAU * hz * i / RATE))) for i, v in enumerate(trilha)]


def punho_carga(rng):
    n = n_amostras(0.6)
    ar = multiplicar(passa_baixa(sopro(rng, n, 300, 1100), 1800), [r ** 1.4 for r in rampa(n)])
    sub = [0.35 * math.sin(TAU * (55 + 40 * i / n) * i / RATE) * (i / n) for i in range(n)]
    return somar(escalar(ar, 1.1), sub)


def punho_soco(rng):
    n = n_amostras(0.55)
    baque = corpo_grave(n, 150, 46, 0.14, 1.0)
    rajada = multiplicar(passa_baixa(ruido(rng, n), 1600), env_ad(n, 0.002, 0.07))
    cauda = multiplicar(sopro(rng, n, 900, 300), env_ad(n, 0.03, 0.2))
    return somar(escalar(baque, 1.0), escalar(rajada, 0.9), escalar(cauda, 0.6))


def cipo_carga(rng):
    n = n_amostras(0.5)
    giro = tremolo(sopro(rng, n, 2200, 350, q=2.2, curva=0.6), 14, 0.5)
    giro = multiplicar(giro, env_ad(n, 0.02, 0.2))
    fup = corpo_grave(n, 220, 90, 0.07, 0.6)
    return somar(escalar(giro, 1.0), fup)


def cipo_sobe(rng):
    n = n_amostras(0.95)
    corda = tremolo(sopro(rng, n, 380, 2400, q=2.0, curva=1.3), 11, 0.45)
    corda = multiplicar(corda, [math.sin(math.pi * i / n) ** 0.7 for i in range(n)])
    ar = multiplicar(passa_baixa(ruido(rng, n), 900), [0.35 * math.sin(math.pi * i / n) for i in range(n)])
    return somar(escalar(corda, 1.0), ar)


def lancador_carga(rng):
    n = n_amostras(0.75)
    tom = [0.4 * math.sin(TAU * (60 + 90 * (i / n) ** 1.5) * i / RATE) * (0.3 + 0.7 * i / n) for i in range(n)]
    pressao = multiplicar(passa_baixa(sopro(rng, n, 250, 900), 1200), [r ** 1.6 for r in rampa(n)])
    return somar(tom, escalar(pressao, 1.0), estalos(rng, n, 4, 0.12, 0.3))


def lancador_tiro(rng):
    n = n_amostras(0.8)
    estouro = corpo_grave(n, 210, 44, 0.18, 1.0)
    jato = multiplicar(sopro(rng, n, 1700, 280, q=1.4, curva=0.5), env_ad(n, 0.005, 0.22))
    rastro = multiplicar(passa_baixa(ruido(rng, n), 700), env_ad(n, 0.05, 0.35))
    return somar(escalar(estouro, 1.0), escalar(jato, 1.2), escalar(rastro, 0.5))


def white_out_carga(rng):
    n = n_amostras(1.5)
    rugido = multiplicar(passa_baixa(ruido(rng, n), 500), [0.8 * r ** 1.8 for r in rampa(n)])
    sub = [0.45 * math.sin(TAU * (38 + 22 * i / n) * i / RATE) * (i / n) for i in range(n)]
    rocar = tremolo(multiplicar(sopro(rng, n, 500, 1500, q=1.2), [0.5 * r ** 1.2 for r in rampa(n)]), 7, 0.5)
    return somar(rugido, sub, rocar)


def white_out_nuvem(rng):
    n = n_amostras(2.0)
    estouro = corpo_grave(n, 110, 34, 0.55, 1.0)
    onda = multiplicar(passa_baixa(sopro(rng, n, 2800, 260, q=1.2, curva=0.45), 3500), env_ad(n, 0.02, 0.6))
    nuvem = tremolo(multiplicar(passa_baixa(ruido(rng, n), 600), env_ad(n, 0.1, 0.9)), 5, 0.4)
    return somar(escalar(estouro, 1.0), escalar(onda, 1.2), escalar(nuvem, 0.7))


def impacto(rng):
    n = n_amostras(0.3)
    baque = corpo_grave(n, 180, 60, 0.07, 1.0)
    pancada = multiplicar(passa_baixa(ruido(rng, n), 2200), env_ad(n, 0.001, 0.035))
    return somar(baque, escalar(pancada, 0.8))


def fumaca(rng):
    n = n_amostras(0.55)
    puf = multiplicar(passa_baixa(sopro(rng, n, 1300, 400, q=1.1), 2200), env_ad(n, 0.04, 0.17))
    return puf


CUES = {
    "punho_carga": punho_carga, "punho_soco": punho_soco,
    "cipo_carga": cipo_carga, "cipo_sobe": cipo_sobe,
    "lancador_carga": lancador_carga, "lancador_tiro": lancador_tiro,
    "white_out_carga": white_out_carga, "white_out_nuvem": white_out_nuvem,
    "impacto": impacto, "fumaca": fumaca,
}


def main():
    for i, (nome, fn) in enumerate(CUES.items()):
        salvar(OUT / f"moku_{nome}.wav", fn(random.Random(2511 + i)))
        print("ok", nome)


if __name__ == "__main__":
    main()
