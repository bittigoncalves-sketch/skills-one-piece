#!/usr/bin/env python3
"""Sintetiza a música instrumental do Desafio do Buggy (21/11/2026) a partir de art_src/audio/buggy_cutscene/BRIEFING.md.

Só instrumentos, sem voz nem amostras: tudo vem de ondas (aditivo/subtrativo simples), ruído e cordas dedilhadas (Karplus-Strong). Python puro (wave + math + random);
o OGG sai por ffmpeg. Rodar da raiz do projeto:   python3 tools/audio/sintetizar_buggy.py
Saídas em assets/audio/musica/: buggy_chegada.ogg (28 s), buggy_sting_riso.ogg (4 s), buggy_copos_loop.ogg (12 s, em loop).
O motivo A, os acordes e a estrutura são os do briefing; a orquestração (quem toca o quê) é nossa. Semente fixa: a mesma execução gera o mesmo áudio.
"""
import math, random, struct, subprocess, wave, os, sys

SR = 32000
BPM = 120.0
BEAT = 60.0 / BPM          # 0,5 s
BAR = 4 * BEAT             # 2 s
SAIDA = "assets/audio/musica/"

random.seed(20261121)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


NOTAS = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def nota(nome):
    """'D4' -> midi; 'Bb4' -> midi; 'C#5'."""
    letra = nome[0]
    resto = nome[1:]
    alt = 0
    while resto and resto[0] in "b#":
        alt += -1 if resto[0] == "b" else 1
        resto = resto[1:]
    return 12 * (int(resto) + 1) + NOTAS[letra] + alt


class Faixa:
    """Buffer estéreo; `tocar` soma um som mono com pan (-1 esq … 1 dir) e ganho."""
    def __init__(self, segundos):
        self.n = int(segundos * SR)
        self.L = [0.0] * self.n
        self.R = [0.0] * self.n

    def tocar(self, t0, som, ganho=1.0, pan=0.0):
        i0 = int(t0 * SR)
        gl = ganho * math.cos((pan + 1) * math.pi / 4)
        gr = ganho * math.sin((pan + 1) * math.pi / 4)
        L, R = self.L, self.R
        for k, v in enumerate(som):
            i = i0 + k
            if i >= self.n:
                break
            L[i] += v * gl
            R[i] += v * gr

    def eco(self, atraso, realim, mistura):
        d = int(atraso * SR)
        for canal in (self.L, self.R):
            ec = [0.0] * self.n
            for i in range(self.n):
                v = canal[i]
                if i >= d:
                    v += ec[i - d] * realim
                ec[i] = v
            for i in range(self.n):
                canal[i] += (ec[i] - canal[i]) * mistura

    def finalizar(self, pico=0.85):
        m = max(max(abs(v) for v in self.L), max(abs(v) for v in self.R), 1e-9)
        g = pico / m
        for canal in (self.L, self.R):
            for i in range(self.n):
                canal[i] = math.tanh(canal[i] * g * 1.15) / math.tanh(1.15)   # limitador suave

    def wav(self, caminho):
        with wave.open(caminho, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            quadros = bytearray()
            for a, b in zip(self.L, self.R):
                quadros += struct.pack("<hh", int(max(-1, min(1, a)) * 32000), int(max(-1, min(1, b)) * 32000))
            w.writeframes(bytes(quadros))


def env(n, ataque, solta, sust=1.0):
    a = max(1, int(ataque * SR))
    s = max(1, int(solta * SR))
    saida = []
    for i in range(n):
        e = min(1.0, i / a)
        r = n - i
        if r < s:
            e *= r / s
        saida.append(e * sust)
    return saida


def tom(freq, dur, harm, ataque, solta, vib=(0, 0), amp=1.0):
    """Soma de harmônicos `harm` = [(h, amplitude)…]; vibrato (Hz, profundidade em semitons)."""
    n = int(dur * SR)
    e = env(n, ataque, solta)
    saida = [0.0] * n
    vf, vd = vib
    fase_vib = random.random() * 6.28
    for i in range(n):
        t = i / SR
        f = freq * (2 ** ((vd * math.sin(6.2832 * vf * t + fase_vib)) / 12.0)) if vf else freq
        w = 6.2832 * f * t
        s = 0.0
        for h, a in harm:
            if f * h < SR * 0.45:
                s += a * math.sin(h * w)
        saida[i] = s * e[i] * amp
    return saida


# --- instrumentos -----------------------------------------------------------------------
H_FLAUTA = [(1, 1.0), (2, 0.18), (3, 0.06)]
H_CORDA = [(1, 1.0), (2, 0.55), (3, 0.38), (4, 0.25), (5, 0.16), (6, 0.1)]
H_METAL = [(1, 1.0), (2, 0.7), (3, 0.55), (4, 0.4), (5, 0.3), (6, 0.2), (7, 0.14), (8, 0.1)]
H_ACORDEAO = [(1, 1.0), (2, 0.5), (3, 0.5), (4, 0.2), (5, 0.25)]
H_BAIXO = [(1, 1.0), (2, 0.35), (3, 0.12)]


def flauta(n, dur, amp=0.5):
    return tom(midi(n), dur, H_FLAUTA, 0.04, 0.08, (5.2, 0.08), amp)


def corda_longa(n, dur, amp=0.3):
    a = tom(midi(n), dur, H_CORDA, 0.35, 0.4, (5.0, 0.06), amp)
    b = tom(midi(n) * 1.004, dur, H_CORDA, 0.35, 0.4, (4.6, 0.06), amp)      # dois "músicos" levemente desafinados = naipe
    return [x + y for x, y in zip(a, b)]


def metal(n, dur, amp=0.4, surdina=False):
    h = [(k, a * (0.45 if surdina and k > 2 else 1.0)) for k, a in H_METAL]
    return tom(midi(n), dur, h, 0.03 if not surdina else 0.015, 0.07, (5.0, 0.05) if not surdina else (0, 0), amp)


def acordeao(n, dur, amp=0.25):
    return tom(midi(n), dur, H_ACORDEAO, 0.06, 0.1, (6.0, 0.04), amp)


def baixo(n, dur, amp=0.55):
    return tom(midi(n), dur, H_BAIXO, 0.01, 0.12, (0, 0), amp)


def dedilhado(n, dur, amp=0.45, brilho=0.5):
    """Karplus-Strong: violão/pizzicato."""
    f = midi(n)
    N = max(2, int(SR / f))
    buf = [random.uniform(-1, 1) for _ in range(N)]
    saida = []
    total = int(dur * SR)
    k = 0
    for i in range(total):
        v = buf[k]
        nxt = buf[(k + 1) % N]
        buf[k] = (v + nxt) * 0.5 * (0.996 - 0.004 * (1 - brilho))
        saida.append(v * amp)
        k = (k + 1) % N
    fim = int(0.03 * SR)
    for i in range(min(fim, total)):
        saida[total - 1 - i] *= i / fim
    return saida


def bumbo(amp=0.9):
    n = int(0.42 * SR)
    saida = []
    ph = 0.0
    for i in range(n):
        t = i / SR
        f = 48 + 90 * math.exp(-t * 28)
        ph += 6.2832 * f / SR
        saida.append(math.sin(ph) * math.exp(-t * 9) * amp)
    return saida


def timpano(amp=0.8):
    n = int(1.2 * SR)
    saida = []
    ph = 0.0
    for i in range(n):
        t = i / SR
        f = midi(38) * (1 + 0.25 * math.exp(-t * 18))
        ph += 6.2832 * f / SR
        saida.append((math.sin(ph) + 0.4 * math.sin(2 * ph)) * math.exp(-t * 3.2) * amp * 0.6)
    return saida


def caixa(amp=0.5, longa=False):
    n = int((0.22 if not longa else 0.4) * SR)
    saida = []
    ph = 0.0
    for i in range(n):
        t = i / SR
        ph += 6.2832 * 190 / SR
        ruido = random.uniform(-1, 1)
        saida.append((ruido * 0.8 + math.sin(ph) * 0.3) * math.exp(-t * (22 if not longa else 12)) * amp)
    return saida


def prato(amp=0.3):
    n = int(1.2 * SR)
    return [random.uniform(-1, 1) * math.exp(-(i / SR) * 3.5) * amp * (1 - math.exp(-(i / SR) * 90)) for i in range(n)]


def glissando(n0, n1, dur, amp=0.4):
    """Trombone: desliza de n0 a n1 (midi)."""
    n = int(dur * SR)
    e = env(n, 0.03, 0.1)
    saida = []
    ph = 0.0
    for i in range(n):
        k = i / max(n - 1, 1)
        f = midi(n0 + (n1 - n0) * k * k)
        ph += 6.2832 * f / SR
        s = sum(a * math.sin(h * ph) for h, a in H_METAL[:6])
        saida.append(s * e[i] * amp)
    return saida


ACORDES = {
    "Dm": ([38, 50, 53, 57], 38),     # (vozes, fundamental do baixo em MIDI)
    "Bb": ([34, 46, 50, 53], 34),
    "F": ([41, 53, 57, 60], 41),
    "C": ([36, 48, 52, 55], 36),
    "A": ([33, 45, 49, 52], 33),
}


def motivo(f, t0, n_baixa=0, extra_oitava=0, instrumento=None, ganho=1.0, pan=0.0):
    """Motivo A do briefing (2 compassos): D4 F4 A4 A4 C5 A4 F4 D4 | F4 G4 A4 Bb4 A4 F4 D4 D4, colcheias de 0,25 s."""
    seq = ["D4", "F4", "A4", "A4", "C5", "A4", "F4", "D4", "F4", "G4", "A4", "Bb4", "A4", "F4", "D4", "D4"]
    for i, nm in enumerate(seq):
        f.tocar(t0 + i * BEAT / 2, instrumento(nota(nm) + 12 * extra_oitava, BEAT / 2 * 0.92), ganho, pan)


def chegada():
    t = Faixa(28.5)
    bar = lambda k: (k - 1) * BAR
    acordes = ["Dm", "Bb", "F", "C", "Dm", "A", "Dm", "Bb", "F", "C", "Bb", "C", "A", "Dm"]
    # camada de cordas sustentadas + baixo, o tempo todo (dinâmica por compasso)
    din = [0.55, 0.6, 0.65, 0.7, 0.75, 0.75, 0.9, 0.95, 1.0, 1.0, 0.8, 0.65, 0.7, 0.85]
    for k, ac in enumerate(acordes, start=1):
        vozes, raiz = ACORDES[ac]
        for j, v in enumerate(vozes[1:]):
            t.tocar(bar(k), corda_longa(v + 12, BAR * 1.02, 0.18 * din[k - 1]), 1.0, -0.5 + 0.5 * j)
        t.tocar(bar(k), baixo(raiz, BEAT * 1.8, 0.5 * din[k - 1]), 1.0, 0.0)
        if k >= 4:
            t.tocar(bar(k) + 2 * BEAT, baixo(raiz + (7 if ac != "A" else 7), BEAT * 1.6, 0.4 * din[k - 1]), 1.0, 0.0)
    # 1–3 (0–6 s): acordeão leve + pífaro (motivo nos compassos 1–2) + bumbo espaçado
    for k in (1, 2, 3):
        vozes, raiz = ACORDES[acordes[k - 1]]
        for j, v in enumerate(vozes[1:]):
            t.tocar(bar(k), acordeao(v + 12, BAR * 0.95, 0.12), 1.0, 0.3)
    motivo(t, bar(1), instrumento=lambda n, d: flauta(n + 12, d, 0.38), ganho=1.0, pan=0.35)
    t.tocar(bar(3), flauta(nota("A5"), BEAT * 2, 0.34), 1.0, 0.35)
    t.tocar(bar(3) + 2 * BEAT, flauta(nota("F5"), BEAT * 2, 0.3), 1.0, 0.35)
    t.tocar(bar(1), bumbo(0.55), 1.0, 0)
    t.tocar(bar(3), bumbo(0.55), 1.0, 0)
    # 4–6 (6–12 s): pizzicato + caixa de marcha + trompa em resposta
    for k in (4, 5, 6):
        vozes, raiz = ACORDES[acordes[k - 1]]
        for b in range(8):
            tt = bar(k) + b * BEAT / 2
            if b % 2 == 1:
                t.tocar(tt, dedilhado(vozes[1 + (b // 2) % 3] + 12, 0.35, 0.4), 1.0, -0.4 if b % 4 == 1 else 0.4)
        t.tocar(bar(k) + BEAT, caixa(0.28), 1.0, 0.2)
        t.tocar(bar(k) + 3 * BEAT, caixa(0.28), 1.0, 0.2)
        t.tocar(bar(k), bumbo(0.6), 1.0, 0)
    for i, nm in enumerate(["A3", "D4", "F4", "A4"]):
        t.tocar(bar(5) + 2 * BEAT + i * BEAT / 2, metal(nota(nm), BEAT * 0.45, 0.3), 1.0, -0.3)
    t.tocar(bar(6), prato(0.12), 1.0, 0.4)
    # 7–10 (12–20 s): metais apresentam o motivo (7–8), variação (9–10); cordas em arpejo, violão no contratempo, tambores marcados
    motivo(t, bar(7), instrumento=lambda n, d: metal(n, d, 0.36), ganho=1.0, pan=-0.2)
    var = ["A4", "C5", "F5", "F5", "E5", "C5", "G4", "C5", "G4", "A4", "C5", "C5", "E5", "G5", "E5", "C5"]       # variação original sobre F–C
    for i, nm in enumerate(var):
        t.tocar(bar(9) + i * BEAT / 2, metal(nota(nm), BEAT / 2 * 0.92, 0.34), 1.0, -0.2)
    for k in (7, 8, 9, 10):
        vozes, raiz = ACORDES[acordes[k - 1]]
        for b in range(8):
            t.tocar(bar(k) + b * BEAT / 2, dedilhado(vozes[1 + b % 3] + 12, 0.3, 0.42), 1.0, -0.5 if b % 2 else 0.5)
        for b in (0, 2):
            t.tocar(bar(k) + b * BEAT, bumbo(0.75), 1.0, 0)
        for b in (1, 3):
            t.tocar(bar(k) + b * BEAT, caixa(0.42), 1.0, 0.15)
        for b in (1, 3):                                       # acordeão no contratempo
            for v in vozes[1:]:
                t.tocar(bar(k) + (b + 0.5) * BEAT, acordeao(v + 12, BEAT * 0.4, 0.1), 1.0, 0.35)
    t.tocar(bar(10) + 3.5 * BEAT, caixa(0.5, True), 1.0, 0.2)          # rufo antes do close
    t.tocar(bar(11), prato(0.3), 1.0, 0.3)
    # 11–14 (20–28 s): motivo uma oitava acima (só o 1º compasso), pausa teatral, cadência; recua sob a fala
    motivo_curto = ["D4", "F4", "A4", "A4", "C5", "A4", "F4", "D4"]
    for i, nm in enumerate(motivo_curto):
        t.tocar(bar(11) + i * BEAT / 2, metal(nota(nm) + 12, BEAT / 2 * 0.92, 0.3), 1.0, -0.2)
        t.tocar(bar(11) + i * BEAT / 2, flauta(nota(nm) + 12, BEAT / 2 * 0.92, 0.22), 1.0, 0.35)
    # compasso 12: pausa teatral (só o 1º tempo soa)
    t.tocar(bar(12), caixa(0.3), 1.0, 0.2)
    t.tocar(bar(12) + 3 * BEAT, metal(nota("E4"), BEAT * 0.4, 0.25, True), 1.0, -0.3)
    t.tocar(bar(13), timpano(0.7), 1.0, 0)
    t.tocar(bar(13) + 3 * BEAT, metal(nota("C#5"), BEAT * 0.9, 0.22, True), 1.0, -0.3)
    # compasso 14: resolução em Dm
    for v in (nota("D3"), nota("A3"), nota("D4"), nota("F4")):
        t.tocar(bar(14), corda_longa(v, BAR * 1.2, 0.2), 1.0, 0)
    t.tocar(bar(14), metal(nota("D4"), BAR * 0.9, 0.25), 1.0, -0.2)
    t.tocar(bar(14), timpano(0.8), 1.0, 0)
    t.tocar(bar(14), prato(0.25), 1.0, 0.3)
    t.eco(0.19, 0.3, 0.22)
    t.finalizar(0.85)
    return t


def sting():
    t = Faixa(4.4)
    q = BEAT / 2
    # compasso 1 sobre Dm: A4 A4 _ A4 | C5 _ A4 _  (colcheias) · compasso 2: G4 G4 _ F4 | E4 _ D4 _ ; Dm → A → Dm (A no 1º meio compasso do 2º)
    seq = [("A4", 0), ("A4", 1), (None, 2), ("A4", 3), ("C5", 4), (None, 5), ("A4", 6), (None, 7),
           ("G4", 8), ("G4", 9), (None, 10), ("F4", 11), ("E4", 12), (None, 13), ("D4", 14), (None, 15)]
    for nm, i in seq:
        if nm:
            t.tocar(i * q, metal(nota(nm), q * 0.8, 0.5, True), 1.0, -0.15)
            t.tocar(i * q, flauta(nota(nm) + 12, q * 0.6, 0.12), 1.0, 0.3)
    for v in ("D3", "A3", "F4"):
        t.tocar(0, corda_longa(nota(v), BAR * 1.0, 0.16), 1.0, 0)
    for v in ("A2", "E3", "C#4"):
        t.tocar(BAR, corda_longa(nota(v), BAR * 0.5, 0.16), 1.0, 0)
    for v in ("D3", "A3", "F4"):
        t.tocar(BAR + BAR / 2, corda_longa(nota(v), BAR * 0.6, 0.18), 1.0, 0)
    t.tocar(0, baixo(nota("D2"), BEAT * 1.5, 0.5))
    t.tocar(BAR, baixo(nota("A1"), BEAT * 0.9, 0.5))
    t.tocar(BAR + BAR / 2, baixo(nota("D2"), BEAT * 1.5, 0.5))
    t.tocar(1 * BEAT, caixa(0.2), 1.0, 0.2)
    t.tocar(3 * BEAT, caixa(0.2), 1.0, 0.2)
    t.tocar(BAR + 3 * BEAT, glissando(nota("D3") + 7, nota("D3") - 5, BEAT * 1.0, 0.3), 1.0, -0.3)
    t.tocar(BAR + 3 * BEAT, caixa(0.3), 1.0, 0.2)
    t.eco(0.12, 0.2, 0.15)
    t.finalizar(0.8)
    return t


def copos():
    t = Faixa(12.0)
    acordes = ["Dm", "C", "Bb", "A", "Dm", "A"]
    for k, ac in enumerate(acordes):
        vozes, raiz = ACORDES[ac]
        t0 = k * BAR
        t.tocar(t0, baixo(raiz, BEAT * 1.4, 0.45))
        t.tocar(t0 + 2 * BEAT, baixo(raiz, BEAT * 1.4, 0.4))
        for b in range(8):
            if b % 2 == 1:
                t.tocar(t0 + b * BEAT / 2, dedilhado(vozes[1 + (b // 2) % 3] + 12, 0.3, 0.4), 1.0, -0.4 if b % 4 == 1 else 0.4)
        t.tocar(t0 + BEAT, caixa(0.16), 1.0, 0.2)
        t.tocar(t0 + 3 * BEAT, caixa(0.16), 1.0, 0.2)
        for v in vozes[1:]:
            t.tocar(t0, corda_longa(v + 12, BAR * 0.98, 0.07), 1.0, 0)
    cel = ["D5", None, "F5", None, "E5", None, "D5", None]
    for ponto, (base, alt) in enumerate([(0, 0), (2, 0), (4, 12)]):
        for i, nm in enumerate(cel):
            if nm and (ponto != 2 or i < 4):
                t.tocar((base) * BAR + i * BEAT / 2 + (0 if ponto != 1 else 0), flauta(nota(nm) + (7 if ponto == 1 else 0) - (0 if ponto != 2 else 0), BEAT * 0.35, 0.3), 1.0, 0.35)
    t.finalizar(0.7)
    # emenda do loop: o fim (A) já cai em volta de zero; aplica um fade curtíssimo nos últimos 15 ms e nos primeiros 5 ms
    for canal in (t.L, t.R):
        for i in range(int(0.015 * SR)):
            canal[t.n - 1 - i] *= i / (0.015 * SR)
        for i in range(int(0.005 * SR)):
            canal[i] *= i / (0.005 * SR)
    return t


def exportar(faixa, nome):
    os.makedirs(SAIDA, exist_ok=True)
    wav = SAIDA + nome + ".wav"
    ogg = SAIDA + nome + ".ogg"
    faixa.wav(wav)
    r = subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", ogg])
    os.remove(wav)
    print("ok", ogg, os.path.getsize(ogg) // 1024, "KB", "(ffmpeg %d)" % r.returncode)


if __name__ == "__main__":
    quais = sys.argv[1:] or ["chegada", "sting", "copos"]
    if "chegada" in quais:
        exportar(chegada(), "buggy_chegada")
    if "sting" in quais:
        exportar(sting(), "buggy_sting_riso")
    if "copos" in quais:
        exportar(copos(), "buggy_copos_loop")
