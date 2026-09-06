"""Author deterministic Ope Ope sound assets. Standard library only, no samples.

Run: python3 tools/generate_ope_audio.py
Spatial mono, 48 kHz / 16 bit, peak -3.1 dBFS, short fades to prevent clicks.
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


def generate(cue, duration, seed):
    rng = random.Random(seed)
    samples = []
    low = phase = 0.0
    for i in range(int(RATE * duration)):
        t = i / RATE
        u = t / duration
        noise = rng.uniform(-1.0, 1.0)
        low += (noise - low) * (0.035 + 0.14 * (1.0 - u))
        if cue == "room":
            # Expanding glass chamber: phase coherent downward harmonic sweep.
            phase += TAU * (155.0 + 580.0 * math.exp(-t * 4.0)) / RATE
            swell = (1.0 - math.exp(-t * 18)) * math.exp(-t * 2.5)
            signal = swell * (0.5 * math.sin(phase) + 0.18 * math.sin(phase * 2.005))
            signal += 0.7 * low * math.sin(math.pi * u) ** 2
            signal += 0.16 * math.sin(TAU * 1320 * t) * math.exp(-t * 12)
        elif cue == "shambles":
            # Suction, crystalline transient, and very short displaced echo.
            hit = max(0.0, t - 0.13)
            phase += TAU * (420.0 + 1500.0 * math.exp(-hit * 22)) / RATE
            before = min(1.0, t / 0.13) ** 3 if t < 0.13 else math.exp(-hit * 22)
            signal = low * 1.4 * before
            if t >= 0.13:
                signal += (0.35 * math.sin(phase) + 0.2 * noise) * math.exp(-hit * 20)
            if t > 0.22:
                signal += 0.12 * math.sin(TAU * 950 * (t - 0.22)) * math.exp(-(t - 0.22) * 30)
        elif cue == "takt":
            # Stone mass under tension, accented by five restrained lift ticks.
            signal = (0.5 * math.sin(TAU * 63 * t) + low) * math.sin(math.pi * u) ** 1.4
            for j in range(5):
                dt = t - (0.07 + j * 0.13)
                if dt >= 0:
                    signal += 0.13 * math.sin(TAU * (520 + j * 110) * dt) * math.exp(-dt * 30)
        elif cue == "gamma":
            # Tension rise resolves into a focused electrical needle at .35s.
            strike = max(0.0, t - 0.35)
            phase += TAU * (380.0 + 1150.0 * min(t / 0.35, 1.0)) / RATE
            charge = (t / 0.35) ** 2 if t < 0.35 else math.exp(-strike * 10)
            signal = charge * (0.25 * math.sin(phase) + 0.2 * low)
            if t >= 0.35:
                signal += (0.55 * noise + 0.6 * math.sin(TAU * 90 * strike)) * math.exp(-strike * 19)
        else:
            # Dry incision with body; deliberately no long explosive rumble.
            phase += TAU * (72.0 + 140.0 * math.exp(-t * 22)) / RATE
            signal = 0.5 * math.sin(phase) * math.exp(-t * 13)
            signal += (noise - low) * 0.25 * math.exp(-t * 60)
        fade = min(1.0, t / 0.004) * min(1.0, (duration - t) / 0.035)
        samples.append(signal * fade)
    # Two diffuse reflections retain attack clarity without an external bus.
    original = samples[:]
    for delay, gain in ((0.047, 0.10), (0.089, 0.055)):
        shift = int(RATE * delay)
        for i in range(shift, len(samples)):
            samples[i] += original[i - shift] * gain * min(1.0, (len(samples) - i) / (RATE * 0.035))
    peak = max(abs(x) for x in samples) or 1.0
    pcm = array("h", (int(x / peak * 22937) for x in samples))
    if sys.byteorder != "little":
        pcm.byteswap()
    destination = OUT / f"ope_{cue}.wav"
    with wave.open(str(destination), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    print(f"{destination.name}: {duration:.2f}s, {len(pcm)} samples, peak -3.1 dBFS")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for n, (cue, seconds) in enumerate((('room', 1.65), ('shambles', 0.55), ('takt', 1.15), ('gamma', 1.15), ('impact', 0.45))):
        generate(cue, seconds, 18092026 + n)
