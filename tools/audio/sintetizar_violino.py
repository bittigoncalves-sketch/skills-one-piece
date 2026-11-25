#!/usr/bin/env python3
"""Música CALMA de violino do Desafio do Buggy (22/11/2026) — substitui buggy_chegada.ogg e buggy_copos_loop.ogg ("a atual ficou muito estranha").

Violino por síntese física simplificada, Python puro (+ ffmpeg só para o OGG), sem amostras nem rede:
  - fonte do arco: série harmônica com queda ~1/n^1,15 (dente de serra suavizada) + ruído de arco só no ataque;
  - vibrato TARDIO (começa ~0,3 s depois do ataque, 5,3 Hz, ±0,3 semitom), ataque macio e leve inflar da nota (messa di voce);
  - caixa do violino: ressonâncias de corpo (~290 Hz, ~520 Hz, ~2,9 kHz) por filtros passa-banda somados + corte agudo;
  - pad de cordas ao fundo (senoides suaves) e reverb de sala (Schroeder). Semente fixa: mesma execução, mesmo áudio.
Partitura: `art_src/audio/buggy_cutscene/PARTITURA_VIOLINO.json` se existir (do Codex: {"bpm","pecas":{"chegada":[{"t","d","midi","vel"}], "copos_loop":[...]}} e,
opcional, "pad":[{"t","d","midis":[...]}]); senão a partitura embutida abaixo (lá menor, 66 bpm, frases de 4 compassos).
Rodar da raiz:  python3 tools/audio/sintetizar_violino.py          Saída: assets/audio/musica/buggy_chegada.ogg e buggy_copos_loop.ogg
"""
import json, math, os, random, subprocess, sys, wave, struct

SR = 32000
SAIDA = "assets/audio/musica/"
PARTITURA = "art_src/audio/buggy_cutscene/PARTITURA_VIOLINO.json"
random.seed(20261122)

NOTAS = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def nota(nome):
    alt = 0
    resto = nome[1:]
    while resto and resto[0] in "b#":
        alt += -1 if resto[0] == "b" else 1
        resto = resto[1:]
    return 12 * (int(resto) + 1) + NOTAS[nome[0]] + alt


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


# ---------------------------------------------------------------- partitura embutida (beats; 4/4; 66 bpm)
BPM = 66.0


def _l(*itens):
    """[(nome, duração)] -> [{t,d,midi,vel}] em sequência (nome 'R' = pausa)."""
    t = 0.0
    saida = []
    for n, d in itens:
        if n != "R":
            saida.append({"t": t, "d": d, "midi": nota(n), "vel": 0.8})
        t += d
    return saida


CHEGADA = _l(
    ("R", 1), ("A4", 2), ("C5", 1),                      # 1  Am
    ("E5", 3), ("D5", 1),                                # 2  F
    ("C5", 2), ("E5", 1), ("G4", 1),                     # 3  C
    ("B4", 3), ("G#4", 1),                               # 4  E  (meia cadência: respira)
    ("A4", 2), ("C5", 1), ("E5", 1),                     # 5  Am
    ("A5", 3), ("G5", 1),                                # 6  F
    ("F5", 2), ("E5", 1), ("D5", 1),                     # 7  Dm
    ("B4", 1), ("G#4", 1), ("A4", 4), ("R", 2),          # 8  E -> Am (resolve e sustenta)
)
CHEGADA_PAD = [
    (0, 4, "A2 E3 A3 C4"), (4, 4, "F2 C3 F3 A3"), (8, 4, "C3 G3 C4 E4"), (12, 4, "E2 B2 E3 G#3"),
    (16, 4, "A2 E3 A3 C4"), (20, 4, "F2 C3 F3 A3"), (24, 4, "D3 A3 D4 F4"), (28, 1.5, "E2 B2 E3 G#3"), (29.5, 4.5, "A2 E3 A3 C4"),
]
# Loop do jogo dos copos: 4 compassos, harmonia que volta ao começo (Am F C E), melodia esparsa para não competir com a atenção do jogador.
COPOS = _l(
    ("E5", 3), ("D5", 1),                                # Am
    ("C5", 2), ("A4", 2),                                # F
    ("G4", 2), ("C5", 2),                                # C
    ("B4", 3), ("G#4", 1),                               # E  -> volta ao Am
)
COPOS_PAD = [(0, 4, "A2 E3 A3 C4"), (4, 4, "F2 C3 F3 A3"), (8, 4, "C3 G3 C4 E4"), (12, 4, "E2 B2 E3 G#3")]


def carregar():
    if os.path.exists(PARTITURA):
        d = json.load(open(PARTITURA))
        bpm = float(d.get("bpm", BPM))
        pecas = d["pecas"]
        pad = d.get("pad", {})
        return bpm, pecas.get("chegada", CHEGADA), pecas.get("copos_loop", COPOS), pad, True
    return BPM, CHEGADA, COPOS, {}, False


# ---------------------------------------------------------------- síntese
def violino(m, dur, vel, vib=None):
    """Uma nota: mono, `dur` s (a cauda de soltura é somada além disso)."""
    vib = vib or {}
    vhz = float(vib.get("hz", 5.3))
    vatraso = float(vib.get("atraso_s", 0.30))
    vprof = float(vib.get("profundidade_cents", 30)) / 1200.0 * math.log(2) * 1.0
    f0 = hz(m)
    solta = 0.35
    n = int((dur + solta) * SR)
    ataque = 0.11
    harm = max(2, min(16, int(0.45 * SR / f0)))
    amps = [1.0 / (k ** 1.15) for k in range(1, harm + 1)]
    amp_g = 0.34 * vel
    fase = 0.0
    saida = [0.0] * n
    ruido = 0.0
    for i in range(n):
        t = i / SR
        if t < ataque:
            e = 0.5 - 0.5 * math.cos(math.pi * t / ataque)
        elif t < dur:
            e = 1.0
        else:
            e = max(0.0, 1.0 - (t - dur) / solta) ** 1.6
        e *= 1.0 + 0.10 * math.sin(math.pi * min(1.0, t / max(dur, 0.1)))   # infla e murcha de leve
        v = min(1.0, max(0.0, (t - vatraso) / 0.45))                           # vibrato tardio
        f = f0 * (1.0 + vprof * v * math.sin(2 * math.pi * vhz * t))        # profundidade em cents
        fase += 2 * math.pi * f / SR
        s = 0.0
        for k in range(harm):
            s += amps[k] * math.sin((k + 1) * fase)
        if t < 0.09:                                                        # arranhar do arco no ataque
            ruido = 0.85 * ruido + 0.15 * random.uniform(-1, 1)
            s += 0.9 * ruido * (1.0 - t / 0.09)
        saida[i] = s * e * amp_g
    return saida


def pad_nota(m, dur, amp=0.05):
    f0 = hz(m)
    solta = 0.9
    ataque = 0.8
    n = int((dur + solta) * SR)
    saida = [0.0] * n
    for i in range(n):
        t = i / SR
        e = min(1.0, t / ataque) if t < dur else max(0.0, 1.0 - (t - dur) / solta)
        d = 1.0 + 0.002 * math.sin(2 * math.pi * 0.23 * t + m)
        saida[i] = amp * e * (math.sin(2 * math.pi * f0 * d * t) + 0.35 * math.sin(4 * math.pi * f0 * d * t))
    return saida


class Biquad:
    """Passa-banda (RBJ) para as ressonâncias do corpo."""
    def __init__(self, f, q):
        w = 2 * math.pi * f / SR
        a = math.sin(w) / (2 * q)
        a0 = 1 + a
        self.b0, self.b2 = a / a0, -a / a0
        self.a1, self.a2 = -2 * math.cos(w) / a0, (1 - a) / a0
        self.x1 = self.x2 = self.y1 = self.y2 = 0.0

    def passa(self, x):
        y = self.b0 * x + self.b2 * self.x2 - self.a1 * self.y1 - self.a2 * self.y2
        self.x2, self.x1, self.y2, self.y1 = self.x1, x, self.y1, y
        return y


def caixa(sinal):
    bandas = [(Biquad(290, 4), 0.55), (Biquad(520, 5), 0.45), (Biquad(2900, 3), 0.40)]
    lp = 0.0
    out = [0.0] * len(sinal)
    for i, x in enumerate(sinal):
        y = x
        for b, g in bandas:
            y += g * b.passa(x)
        lp += 0.42 * (y - lp)                        # corta o brilho áspero
        out[i] = lp
    return out


def reverb(sinal, mistura=0.30, fb=0.82):
    atrasos = [int(SR * s) for s in (0.0297, 0.0371, 0.0411, 0.0437)]
    cofres = [[0.0] * d for d in atrasos]
    pos = [0] * len(atrasos)
    amortec = [0.0] * len(atrasos)
    out = [0.0] * len(sinal)
    for i, x in enumerate(sinal):
        s = 0.0
        for j, buf in enumerate(cofres):
            y = buf[pos[j]]
            amortec[j] += 0.45 * (y - amortec[j])
            buf[pos[j]] = x + fb * amortec[j]
            pos[j] = (pos[j] + 1) % len(buf)
            s += y
        out[i] = x * (1 - mistura) + (s * 0.25) * mistura * 1.6
    return out


def montar(notas, pad, bpm, compassos_beats, loop=False):
    beat = 60.0 / bpm
    dur_total = compassos_beats * beat
    cauda = 3.0
    n = int((dur_total + cauda) * SR)
    vio = [0.0] * n
    pd = [0.0] * n
    for nt in notas:
        som = violino(nt["midi"], nt["d"] * beat + 0.06, float(nt.get("vel", 0.8)), nt.get("vibrato"))
        i0 = int(nt["t"] * beat * SR)
        for k, v in enumerate(som):
            if i0 + k < n:
                vio[i0 + k] += v
    for t0, d, midis in pad:
        for m in (midis if isinstance(midis, list) else [nota(x) for x in midis.split()]):
            som = pad_nota(m, d * beat)
            i0 = int(t0 * beat * SR)
            for k, v in enumerate(som):
                if i0 + k < n:
                    pd[i0 + k] += v
    vio = caixa(vio)
    mix = [a + b for a, b in zip(vio, pd)]
    mix = reverb(mix)
    corpo = int(dur_total * SR)
    if loop:                                          # emenda limpa: a cauda do reverb dobra sobre o começo
        out = mix[:corpo]
        for i in range(n - corpo):
            out[i] += mix[corpo + i]
        return out
    # fim da peça: fade-out curto sobre a cauda natural
    total = int((dur_total + 2.2) * SR)
    out = mix[:total]
    for i in range(int(1.2 * SR)):
        out[total - 1 - i] *= i / (1.2 * SR)
    return out


def exportar(mono, nome):
    pico = max(abs(x) for x in mono) or 1.0
    g = 0.80 / pico
    os.makedirs(SAIDA, exist_ok=True)
    wav = "/tmp/_%s.wav" % nome
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x * g)) * 32767)) for x in mono))
    ogg = SAIDA + nome + ".ogg"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-ac", "2", "-c:a", "libvorbis", "-q:a", "5", ogg], check=True)
    print("ok", ogg, round(len(mono) / SR, 1), "s", os.path.getsize(ogg) // 1024, "KB")
    os.remove(wav)


def main():
    bpm, chegada, copos, pad, do_codex = carregar()
    # partitura do Codex sem pad = violino solo; o pad embutido só acompanha a partitura embutida (a harmonia dele não vale para notas alheias)
    pad_c = pad.get("chegada") if pad.get("chegada") else ([] if do_codex else list(CHEGADA_PAD))
    pad_k = pad.get("copos_loop") if pad.get("copos_loop") else ([] if do_codex else list(COPOS_PAD))
    pad_c = [(p["t"], p["d"], p["midis"]) if isinstance(p, dict) else p for p in pad_c]
    pad_k = [(p["t"], p["d"], p["midis"]) if isinstance(p, dict) else p for p in pad_k]
    alvo = sys.argv[1:] or ["chegada", "copos_loop"]
    if "chegada" in alvo:
        exportar(montar(chegada, pad_c, bpm, 32), "buggy_chegada")
    if "copos_loop" in alvo:
        exportar(montar(copos, pad_k, bpm, 16, loop=True), "buggy_copos_loop")


if __name__ == "__main__":
    main()
