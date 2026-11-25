"""Author deterministic Goro Goro sound assets. Standard library only, no samples.

Run: python3 tools/generate_goro_audio.py
Spatial mono, 48 kHz / 16 bit, peak -3.1 dBFS, short fades to prevent clicks.

DIRECAO DE SOM — mesma regra de ouro da PALETA da Goro (docs/frutas/goro_goro.md):
o efeito vem do CONTRASTE entre duas camadas que nao se misturam.

    ESTALO  agudo, seco, curtissimo  -> e o raio, o que chega primeiro
    TROVAO  grave, longo, rolando    -> e a nuvem, o que chega depois

Som eletrico que so tem chiado agudo fica fino; so grave, fica surdo. Os dois
juntos, com o grave ATRASADO em relacao ao agudo, e o que o ouvido le como
"raio caiu longe". O atraso e proposital em `elthor` e `mamaragan` — sao os
golpes que acontecem A DISTANCIA depois da remodelacao de 2026-09-12.
"""
from array import array
from pathlib import Path
import math
import random
import sys
import wave

RATE = 48000
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
TAU = math.tau


def crepitar(rng, estado, taxa):
    """Ruido com 'grao' eletrico: passa-alta barato + faiscas aleatorias.

    Um raio nao e ruido branco liso; sao milhares de descargas curtas. As
    faiscas esparsas dao esse grao sem precisar de filtro de verdade.
    """
    ruido = rng.uniform(-1.0, 1.0)
    estado += (ruido - estado) * taxa
    agudo = ruido - estado                      # o que sobra do passa-baixa = passa-alta
    if rng.random() < 0.035:
        agudo *= 3.2                            # faisca isolada
    return agudo, estado


def generate(cue, duration, seed):
    rng = random.Random(seed)
    samples = []
    low = grao = phase = 0.0
    for i in range(int(RATE * duration)):
        t = i / RATE
        u = t / duration
        noise = rng.uniform(-1.0, 1.0)
        low += (noise - low) * (0.030 + 0.12 * (1.0 - u))
        agudo, grao = crepitar(rng, grao, 0.55)

        if cue == "sango":
            # Z — FEIXE continuo a frente: ataque imediato, corpo que sustenta e
            # corta seco. Sem cauda longa: o Z e a pressao do dia a dia.
            corpo = math.exp(-t * 7.0) * (1.0 - math.exp(-t * 400))
            phase += TAU * (240.0 + 90.0 * math.sin(TAU * 33 * t)) / RATE
            signal = corpo * (0.42 * agudo + 0.30 * math.sin(phase))
            signal += 0.22 * low * math.exp(-t * 9.0)

        elif cue == "elthor":
            # X — A COLUNA. Estalo seco na frente; o trovao grave entra 0,12 s
            # depois e rola por mais de um segundo.
            estalo = math.exp(-t * 26.0) * (1.0 - math.exp(-t * 900))
            signal = 0.85 * agudo * estalo
            dt = t - 0.12
            if dt > 0:
                # Duas grave proximas batendo entre si = o "rolar" do trovao.
                rolo = math.exp(-dt * 2.4) * (1.0 - math.exp(-dt * 30))
                signal += rolo * (0.55 * math.sin(TAU * 41 * dt)
                                  + 0.30 * math.sin(TAU * 57 * dt)
                                  + 0.60 * low)

        elif cue == "shunshin":
            # C — TELEPORTE: sumico e reaparecimento. Duas faiscas curtas com um
            # vazio entre elas; o vazio e o golpe.
            signal = 0.0
            for inicio, ganho in ((0.0, 1.0), (0.16, 0.8)):
                dt = t - inicio
                if dt >= 0:
                    env = math.exp(-dt * 34.0) * (1.0 - math.exp(-dt * 1200))
                    varre = 1800.0 * math.exp(-dt * 16) + 320.0
                    signal += ganho * env * (0.5 * agudo + 0.35 * math.sin(TAU * varre * dt))

        elif cue == "mamaragan":
            # V — A QUEDA E O ESTOURO (remodelado em 2026-09-12).
            # 0,00-0,38  assobio DESCENDENTE: a bola despencando
            # 0,38       impacto: estalo largo
            # 0,46       o trovao grave alcanca o ouvinte e rola ate o fim
            queda = min(t / 0.38, 1.0)
            if t < 0.38:
                # Frequencia CAINDO = objeto se aproximando do chao.
                phase += TAU * (900.0 - 640.0 * queda) / RATE
                env = (queda ** 2) * 0.55
                signal = env * (0.30 * math.sin(phase) + 0.35 * agudo)
            else:
                dt = t - 0.38
                signal = 1.0 * agudo * math.exp(-dt * 20.0) * (1.0 - math.exp(-dt * 800))
                db = t - 0.46
                if db > 0:
                    rolo = math.exp(-db * 1.9) * (1.0 - math.exp(-db * 26))
                    signal += rolo * (0.70 * math.sin(TAU * 34 * db)
                                      + 0.36 * math.sin(TAU * 48 * db)
                                      + 0.75 * low)

        else:
            # `carga` — a bola crescendo nas nuvens. Zumbido que SOBE de altura e
            # de grao; nao tem transiente porque nada acontece ainda.
            phase += TAU * (110.0 + 120.0 * u * u) / RATE
            tremor = 1.0 + 0.25 * math.sin(TAU * 7.5 * t)
            signal = (0.34 * math.sin(phase) + 0.10 * math.sin(phase * 2.01)) * tremor * u
            signal += 0.30 * agudo * (u ** 2)

        fade = min(1.0, t / 0.004) * min(1.0, (duration - t) / 0.035)
        samples.append(signal * fade)

    # Duas reflexoes difusas: espaco sem barramento externo, preservando o ataque.
    original = samples[:]
    for delay, gain in ((0.051, 0.11), (0.093, 0.06)):
        shift = int(RATE * delay)
        for i in range(shift, len(samples)):
            samples[i] += original[i - shift] * gain * min(1.0, (len(samples) - i) / (RATE * 0.035))

    peak = max(abs(x) for x in samples) or 1.0
    pcm = array("h", (int(x / peak * 22937) for x in samples))
    if sys.byteorder != "little":
        pcm.byteswap()
    destination = OUT / f"goro_{cue}.wav"
    with wave.open(str(destination), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    print(f"{destination.name}: {duration:.2f}s, {len(pcm)} samples, peak -3.1 dBFS")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for n, (cue, seconds) in enumerate((
            ("sango", 0.70),
            ("elthor", 1.70),
            ("shunshin", 0.52),
            ("mamaragan", 2.10),
            ("carga", 1.40))):
        generate(cue, seconds, 12092026 + n)
