"""Som de RECEPÇÃO DE DANO do jogador (23/10/2026, pedido do dono: "adicionar knockback e
som de recepção do dano no jogador", estilo Minecraft). Som próprio — o do Minecraft é da
Mojang. Duas camadas: impacto no corpo (baque grave) + grunhido curto "uh" (fonte glotal
passando por formantes da vogal ʌ). Python puro, sem numpy.

    python3 art_src/audio/gerar_dano_do_jogador.py   →   assets/audio/dano_do_jogador.wav
"""
import math, random, struct, wave, os

TAXA = 44100
DUR = 0.30
random.seed(23102026)


def biquad_passa_banda(f0, q):
    w = 2 * math.pi * f0 / TAXA
    alfa = math.sin(w) / (2 * q)
    b0, b1, b2 = alfa, 0.0, -alfa
    a0, a1, a2 = 1 + alfa, -2 * math.cos(w), 1 - alfa
    return (b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0)


def biquad_passa_alta(f0, q=0.707):
    w = 2 * math.pi * f0 / TAXA
    alfa = math.sin(w) / (2 * q)
    c = math.cos(w)
    b0, b1, b2 = (1 + c) / 2, -(1 + c), (1 + c) / 2
    a0, a1, a2 = 1 + alfa, -2 * c, 1 - alfa
    return (b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0)


def filtrar(x, c):
    b0, b1, b2, a1, a2 = c
    y = [0.0] * len(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o
        y[i] = o
    return y


n = int(TAXA * DUR)
# --- grunhido: pulso glotal (dente de serra suavizado) com f0 caindo, formantes de "ʌ"
fonte = []
fase = 0.0
for i in range(n):
    t = i / TAXA
    f0 = 190.0 - 70.0 * min(t / 0.20, 1.0) + 4.0 * math.sin(2 * math.pi * 23 * t)
    fase = (fase + f0 / TAXA) % 1.0
    glote = (1.0 - fase) ** 3 - 0.25                    # pulso agudo, cauda longa
    sopro = random.uniform(-1, 1) * 0.18
    fonte.append(glote + sopro)
voz = [0.0] * n
for f, q, g in [(650, 5.0, 1.0), (1150, 7.0, 0.55), (2600, 9.0, 0.22)]:
    for i, v in enumerate(filtrar(fonte, biquad_passa_banda(f, q))):
        voz[i] += v * g
# A fonte vaza grave pelos formantes e embola a voz (espectrograma de 23/10): passa-alta
# duas vezes (24 dB/oitava) em 170 Hz — o grave fica só com o impacto.
voz = filtrar(filtrar(voz, biquad_passa_alta(170)), biquad_passa_alta(170))
# --- impacto: seno grave descendo + estalo de ruído no começo
impacto = []
fase = 0.0
for i in range(n):
    t = i / TAXA
    f = 140.0 * (55.0 / 140.0) ** min(t / 0.09, 1.0)
    fase += 2 * math.pi * f / TAXA
    env = math.exp(-t / 0.035)
    estalo = random.uniform(-1, 1) * math.exp(-t / 0.006) * 0.5
    impacto.append(math.sin(fase) * env + estalo)
# --- envelope do grunhido: ataque 12 ms, sustenta, cai até 0,26 s
mix = []
for i in range(n):
    t = i / TAXA
    ataque = min(t / 0.012, 1.0)
    queda = 1.0 if t < 0.12 else max(0.0, 1.0 - (t - 0.12) / 0.14) ** 1.6
    mix.append(voz[i] * ataque * queda * 1.0 + impacto[i] * 0.9)
pico = max(abs(v) for v in mix) or 1.0
mix = [v / pico * 0.89 for v in mix]
# fade-out final de 8 ms (sem clique)
for i in range(int(TAXA * 0.008)):
    mix[-1 - i] *= i / (TAXA * 0.008)

saida = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "dano_do_jogador.wav")
with wave.open(os.path.normpath(saida), "w") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(TAXA)
    w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in mix))
print("gerado", os.path.normpath(saida), f"{DUR:.2f} s, pico 0.89")
