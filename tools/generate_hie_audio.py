"""Sons da HIE HIE NO MI (gelo), um conjunto por técnica. Só biblioteca padrão.

    python3 tools/generate_hie_audio.py

Mono, 48 kHz / 16 bit, pico -3 dBFS, fades curtos contra clique. Determinístico (semente fixa).
Saída: assets/mine_piece/frutas/hie/sons/hie_<cue>.wav

Timbre (decisão de design, 24/11/2026 — o "ice_generate.ogg" do mod servia a tudo; agora cada ataque
tem assinatura própria, todas com a mesma família "vidro e geada"):
  * parciais inarmônicos curtos (1,8–6 kHz) = cristal tilintando;
  * ruído passa-banda com corte que VARRE = vento frio / lâmina cortando;
  * estalos esparsos = gelo rachando;
  * só a bola e a era têm corpo grave (o gelo grande pesa); lanças e pássaro são só agudo.

Cues por técnica:
  partisan_carga, partisan_lancas   — Ice Block: Partisan (lanças)
  bico_carga, bico_voo              — Ice Block: Pheasant Beak (pássaro)
  bola_carga, bola_rajada           — Ice Ball
  era_carga, era_expande            — Ice Age
  impacto, congelar, quebrar        — comuns: acerto do gelo, prender o alvo, o bloco se partindo
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "audio"))
from sintese import *   # noqa: F401,F403 — filtros, envelopes e salvar

OUT = Path(__file__).resolve().parents[1] / "assets" / "mine_piece" / "frutas" / "hie" / "sons"


# ----------------------------------------------------------------------------------- cues
def partisan_carga(rng):
    n = n_amostras(0.7)
    vento = banda(ruido(rng, n), varredura(n, 1800, 5200, 1.4), q=5.0)
    vento = multiplicar(vento, [min(1.0, i / n_amostras(0.5)) ** 1.5 * 0.9 for i in range(n)])
    pings = []
    for k in range(6):
        t0 = 0.08 + k * 0.1
        f = 2400 + k * 420
        pings.append(tilintar(n, [(f, 1.0), (f * 2.76, 0.5), (f * 5.4, 0.25)], 0.09, 0.35, t0))
    return somar(escalar(vento, 0.8), *pings)


def partisan_lancas(rng):
    n = n_amostras(0.6)
    trilhas = []
    for k in range(4):   # as quatro lanças, em sequência rápida
        t0 = k * 0.075
        i0 = n_amostras(t0)
        m = n - i0
        corte = varredura(m, 7500, 2200, 0.5)
        corte_n = banda(ruido(rng, m), corte, q=3.0)
        shink = multiplicar(corte_n, env_ad(m, 0.002, 0.07))
        ping = tilintar(m, [(3100 + k * 230, 1.0), (3100 * 2.4, 0.6), (3100 * 4.1, 0.3)], 0.2, 0.5)
        trilhas.append([0.0] * i0 + somar(escalar(shink, 1.2), ping))
    trilhas.append(estalos(rng, n, 7, 0.35, 0.05))
    return somar(*trilhas)


def bico_carga(rng):
    n = n_amostras(0.55)
    sopro = passa_alta(banda(ruido(rng, n), varredura(n, 900, 3200, 1.2), q=3.0), 500)
    sopro = multiplicar(sopro, [min(1.0, i / n_amostras(0.4)) for i in range(n)])
    # 'piado' de gelo: seno que sobe com vibrato
    pio = []
    fase = 0.0
    for i in range(n):
        t = i / RATE
        f = 2000 + 1500 * (t / 0.55) + 90 * math.sin(TAU * 18 * t)
        fase += TAU * f / RATE
        pio.append(0.22 * math.sin(fase) * min(1.0, t / 0.2))
    return somar(escalar(sopro, 0.9), pio)


def bico_voo(rng):
    n = n_amostras(0.8)
    whoosh = banda(ruido(rng, n), varredura(n, 600, 5500, 0.6), q=2.5)
    whoosh = multiplicar(whoosh, env_ad(n, 0.04, 0.28))
    pio = []
    fase = 0.0
    for i in range(n):
        t = i / RATE
        f = 4200 - 1800 * min(1.0, t / 0.5) + 160 * math.sin(TAU * 22 * t)
        fase += TAU * f / RATE
        pio.append(0.5 * math.sin(fase) * math.exp(-t / 0.22) * min(1.0, t / 0.01))
    glass = tilintar(n, [(5200, 0.6), (7300, 0.4)], 0.12, 0.35, 0.02)
    return somar(escalar(whoosh, 1.0), pio, glass)


def bola_carga(rng):
    n = n_amostras(0.8)
    frio = banda(ruido(rng, n), varredura(n, 300, 1500, 1.0), q=2.0)
    frio = multiplicar(frio, [min(1.0, i / n_amostras(0.7)) ** 2 for i in range(n)])
    zumbido = [0.25 * math.sin(TAU * (70 + 90 * (i / n)) * i / RATE) * (i / n) for i in range(n)]
    return somar(escalar(frio, 1.0), zumbido, estalos(rng, n, 9, 0.3, 0.2))


def bola_rajada(rng):
    n = n_amostras(1.1)
    baque = corpo_grave(n, 160, 48, 0.28, 1.0)
    rajada = passa_baixa(banda(ruido(rng, n), varredura(n, 2800, 500, 0.5), q=1.8), 5000)
    rajada = multiplicar(rajada, env_ad(n, 0.01, 0.35))
    cristais = tilintar(n, [(2600, 1.0), (3900, 0.6), (6100, 0.35)], 0.25, 0.3, 0.03)
    return somar(escalar(baque, 0.85), escalar(rajada, 1.1), cristais, estalos(rng, n, 14, 0.35, 0.05, 0.8))


def era_carga(rng):
    n = n_amostras(1.4)
    uivo = banda(ruido(rng, n), varredura(n, 400, 1900, 0.8), q=6.0)
    uivo = multiplicar(uivo, [(i / n) ** 1.3 for i in range(n)])
    rumor = passa_baixa(ruido(rng, n), 180)
    rumor = multiplicar(rumor, [0.5 * min(1.0, i / n_amostras(1.0)) for i in range(n)])
    return somar(escalar(uivo, 1.0), rumor, estalos(rng, n, 16, 0.3, 0.3))


def era_expande(rng):
    n = n_amostras(2.2)
    vento = banda(ruido(rng, n), varredura(n, 1200, 450, 0.7), q=2.2)
    vento = multiplicar(vento, env_ad(n, 0.05, 0.9))
    baque = corpo_grave(n, 120, 38, 0.5, 1.0)
    onda = tilintar(n, [(1500, 0.8), (2250, 0.6), (3700, 0.5), (5600, 0.3)], 0.6, 0.35, 0.02)
    geada = estalos(rng, n, 36, 0.4, 0.05)
    return somar(escalar(vento, 1.1), escalar(baque, 0.9), onda, geada)


def impacto(rng):
    n = n_amostras(0.4)
    lasca = passa_alta(ruido(rng, n), 2200)
    lasca = multiplicar(lasca, env_ad(n, 0.001, 0.05))
    cristal = tilintar(n, [(2900, 1.0), (4350, 0.7), (6900, 0.5), (9100, 0.25)], 0.14, 0.5)
    return somar(escalar(lasca, 1.0), cristal, estalos(rng, n, 5, 0.4, 0.0, 0.2))


def congelar(rng):
    n = n_amostras(0.55)
    geada = estalos(rng, n, 30, 0.7, 0.0)
    sopro = banda(ruido(rng, n), varredura(n, 6000, 2500, 0.6), q=4.0)
    sopro = multiplicar(sopro, env_ad(n, 0.01, 0.18))
    ding = tilintar(n, [(4800, 0.6), (7200, 0.4)], 0.2, 0.3, 0.15)
    return somar(geada, escalar(sopro, 0.8), ding)


def quebrar(rng):
    n = n_amostras(0.7)
    estouro = multiplicar(passa_alta(ruido(rng, n), 1500), env_ad(n, 0.001, 0.09))
    cacos = []
    for k in range(18):   # cacos de gelo caindo, cada um com seu tom
        t0 = 0.01 + rng.random() * 0.35
        f = rng.uniform(2200, 8000)
        cacos.append(tilintar(n, [(f, 1.0), (f * 1.9, 0.4)], rng.uniform(0.03, 0.11), 0.22, t0))
    return somar(escalar(estouro, 1.0), *cacos)


CUES = {
    "partisan_carga": partisan_carga, "partisan_lancas": partisan_lancas,
    "bico_carga": bico_carga, "bico_voo": bico_voo,
    "bola_carga": bola_carga, "bola_rajada": bola_rajada,
    "era_carga": era_carga, "era_expande": era_expande,
    "impacto": impacto, "congelar": congelar, "quebrar": quebrar,
}


def main():
    for i, (nome, fn) in enumerate(CUES.items()):
        salvar(OUT / f"hie_{nome}.wav", fn(random.Random(2411 + i)))
        print("ok", nome)


if __name__ == "__main__":
    main()
