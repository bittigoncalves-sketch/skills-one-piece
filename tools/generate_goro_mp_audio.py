"""Sons da GORO GORO NO MI (Mine Piece), um conjunto por técnica. Só biblioteca padrão.

    python3 tools/generate_goro_mp_audio.py

Saída: assets/mine_piece/goro/sons/goro_<cue>.wav (mono 48 kHz / 16 bit, pico -3 dBFS).
Receita (`tools/audio/sintese.py`): eletricidade = crepitar denso (cliques aleatórios + ruído passa-banda 2–8 kHz
modulado a 100/120 Hz = zumbido de rede) e trovão = ruído passa-baixa com cauda longa + baque que cai de frequência.
Cada técnica tem o seu: Vari (estalo-relâmpago), El Thor (feixe grosso), Sango (vários raios), Mamaragan (trovão),
Raigo (chamado + impacto do meteoro), passiva (zap), Kari Krash (contra-golpe).
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "audio"))
from sintese import *   # noqa: F401,F403

OUT = Path(__file__).resolve().parents[1] / "assets" / "mine_piece" / "goro" / "sons"


def crepitar(rng, n, densidade, ganho=1.0, de=1500, ate=6500):
    saida = [0.0] * n
    for _ in range(int(densidade * n / RATE)):
        pos = rng.randrange(0, max(1, n - 200))
        f = rng.uniform(de, ate)
        g = rng.uniform(0.3, 1.0) * ganho
        for k in range(160):
            saida[pos + k] += g * math.sin(TAU * f * k / RATE) * math.exp(-k / 22.0)
    return saida


def zumbido(n, hz, ganho=1.0, harmonicos=6, queda=None):
    saida = []
    for i in range(n):
        t = i / RATE
        v = sum(math.sin(TAU * hz * h * t) / h for h in range(1, harmonicos + 1))
        saida.append(ganho * v * (math.exp(-t / queda) if queda else 1.0))
    return saida


def arco(rng, n, de, ate, am_hz=100, q=3.0):
    r = banda(ruido(rng, n), varredura(n, de, ate, 1.0), q=q)
    return [v * (0.55 + 0.45 * math.sin(TAU * am_hz * i / RATE)) for i, v in enumerate(r)]


def trovao(rng, n, grave=60, duracao_queda=0.9, lp=600):
    rumor = multiplicar(passa_baixa(ruido(rng, n), lp), env_ad(n, 0.03, duracao_queda))
    baque = corpo_grave(n, grave * 2.2, grave * 0.7, duracao_queda * 0.5, 1.0)
    return somar(escalar(rumor, 1.1), escalar(baque, 0.7))


def carga(rng):
    n = n_amostras(0.75)
    z = multiplicar(zumbido(n, 120, 0.12, 5), [(i / n) ** 1.3 for i in range(n)])
    return somar(z, multiplicar(arco(rng, n, 1800, 6000), [0.4 + 0.6 * i / n for i in range(n)]), crepitar(rng, n, 140, 0.35))


def estalo(rng):
    n = n_amostras(0.3)
    return somar(multiplicar(passa_alta(ruido(rng, n), 1500), env_ad(n, 0.0005, 0.03)), crepitar(rng, n, 120, 0.4))


def vari_trovao(rng):
    n = n_amostras(0.95)
    zip_ = multiplicar(arco(rng, n, 7500, 1800, 120), env_ad(n, 0.002, 0.18))
    return somar(escalar(zip_, 1.0), trovao(rng, n, 70, 0.35, 900), crepitar(rng, n, 200, 0.45))


def el_thor_feixe(rng):
    n = n_amostras(1.5)
    feixe = multiplicar(somar(zumbido(n, 95, 0.1, 8), arco(rng, n, 1200, 5200, 95, 2.2)), env_ad(n, 0.01, 0.7))
    return somar(escalar(feixe, 1.0), trovao(rng, n, 55, 0.5, 700), crepitar(rng, n, 260, 0.4))


def el_thor_queda(rng):
    n = n_amostras(1.9)
    estouro = trovao(rng, n, 48, 1.0, 500)
    raio = multiplicar(arco(rng, n, 5000, 900, 110), env_ad(n, 0.002, 0.25))
    return somar(estouro, escalar(raio, 1.1), crepitar(rng, n, 160, 0.4))


def sango_raio(rng):
    n = n_amostras(1.0)
    trilhas = []
    for k in range(7):   # vários raios curtos em sequência
        t0 = n_amostras(0.02 + 0.11 * k)
        m = n - t0
        zap = multiplicar(arco(rng, m, rng.uniform(4000, 7000), 1500, 100 + 10 * k), env_ad(m, 0.001, 0.07))
        trilhas.append([0.0] * t0 + zap)
    return somar(*trilhas, crepitar(rng, n, 220, 0.35), trovao(rng, n, 80, 0.3, 800))


def mamaragan_trovao(rng):
    n = n_amostras(2.3)
    return somar(trovao(rng, n, 42, 1.2, 450), multiplicar(arco(rng, n, 3000, 700, 90), env_ad(n, 0.01, 0.5)), crepitar(rng, n, 120, 0.3))


def raigo_chamado(rng):
    n = n_amostras(1.1)
    sub = [0.5 * math.sin(TAU * (34 + 30 * (i / n) ** 2) * i / RATE) * (i / n) ** 1.2 for i in range(n)]
    return somar(sub, multiplicar(passa_baixa(ruido(rng, n), 500), [0.8 * (i / n) ** 1.8 for i in range(n)]), crepitar(rng, n, 100, 0.25))


def raigo_impacto(rng):
    n = n_amostras(2.8)
    return somar(trovao(rng, n, 36, 1.5, 400), multiplicar(arco(rng, n, 6500, 600, 100), env_ad(n, 0.001, 0.4)), crepitar(rng, n, 280, 0.5))


def kari_krash(rng):
    n = n_amostras(0.85)
    bate = multiplicar(passa_alta(ruido(rng, n), 900), env_ad(n, 0.001, 0.07))
    return somar(escalar(bate, 1.0), trovao(rng, n, 90, 0.25, 1000), crepitar(rng, n, 240, 0.5), tilintar(n, [(2200, 0.6), (3300, 0.4)], 0.2, 0.3))


def passiva(rng):
    n = n_amostras(0.45)
    return somar(multiplicar(arco(rng, n, 7000, 2000, 130), env_ad(n, 0.002, 0.1)), crepitar(rng, n, 200, 0.4))


CUES = {
    "carga": carga, "estalo": estalo, "vari_trovao": vari_trovao,
    "el_thor_feixe": el_thor_feixe, "el_thor_queda": el_thor_queda, "sango_raio": sango_raio,
    "mamaragan_trovao": mamaragan_trovao, "raigo_chamado": raigo_chamado, "raigo_impacto": raigo_impacto,
    "kari_krash": kari_krash, "passiva": passiva,
}


def main():
    for i, (nome, fn) in enumerate(CUES.items()):
        salvar(OUT / f"goro_{nome}.wav", fn(random.Random(2711 + i)))
        print("ok", nome)


if __name__ == "__main__":
    main()
