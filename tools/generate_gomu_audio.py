"""Author deterministic Gomu Gomu no Mi & Gear 2 / Gear 3 sound assets.
Standard library only, no samples or external dependencies.

Run: python3 tools/generate_gomu_audio.py
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
    phase2 = 0.0

    for i in range(int(RATE * duration)):
        t = i / RATE
        u = t / duration
        noise = rng.uniform(-1.0, 1.0)
        low += (noise - low) * (0.04 + 0.12 * (1.0 - u))

        signal = 0.0

        if cue == "stretch":
            # Rubber tension: rising pitch wobble with friction harmonics
            freq = 90.0 + 340.0 * (t / duration) ** 1.8 + 15.0 * math.sin(TAU * 18.0 * t)
            phase += TAU * freq / RATE
            tension = math.sin(phase) * (0.4 + 0.3 * math.sin(phase * 2.02))
            friction = (noise - low) * 0.25 * math.sin(TAU * 12.0 * t) ** 2
            env = math.sin(math.pi * u) ** 0.8
            signal = (tension + friction) * env

        elif cue == "pistol":
            # Elastic whip & crack: fast whoosh ending in a sharp sonic slap
            hit_t = 0.09
            if t < hit_t:
                whoosh_p = t / hit_t
                freq = 140.0 + 480.0 * whoosh_p
                phase += TAU * freq / RATE
                signal = 0.35 * math.sin(phase) * (whoosh_p ** 1.5)
                signal += 0.2 * low * (whoosh_p ** 2)
            else:
                dt = t - hit_t
                phase += TAU * (65.0 + 380.0 * math.exp(-dt * 25.0)) / RATE
                crack = 0.65 * math.sin(phase) * math.exp(-dt * 20.0)
                crack += 0.45 * noise * math.exp(-dt * 45.0)
                signal = crack

        elif cue == "bazooka":
            # Double palm air compression blast: swelling tension + explosive concussive burst
            hit_t = 0.10
            if t < hit_t:
                p = t / hit_t
                phase += TAU * (120.0 + 600.0 * p**2) / RATE
                signal = 0.4 * math.sin(phase) * p
            else:
                dt = t - hit_t
                # Heavy air burst
                phase += TAU * (50.0 + 180.0 * math.exp(-dt * 15.0)) / RATE
                boom = 0.7 * math.sin(phase) * math.exp(-dt * 8.0)
                wind = 0.5 * low * math.exp(-dt * 14.0)
                signal = boom + wind

        elif cue == "gatling":
            # Barrage: rapid fire alternating punches with punchy rhythmic snaps
            rep_interval = 0.08
            rep_idx = int(t / rep_interval)
            sub_t = t - rep_idx * rep_interval
            side_mult = 1.0 if rep_idx % 2 == 0 else 1.25
            freq = 110.0 * side_mult + 220.0 * math.exp(-sub_t * 50.0)
            phase += TAU * freq / RATE
            snap = math.sin(phase) * math.exp(-sub_t * 30.0)
            air = (noise - low) * 0.4 * math.exp(-sub_t * 60.0)
            signal = (0.5 * snap + 0.3 * air) * (1.0 + 0.04 * rep_idx)

        elif cue == "gear2_steam":
            # Gear 2: High pressure steam jet with double cardiovascular heartbeat
            # Heartbeats at 0.15s and 0.45s
            heartbeat = 0.0
            for beat_t in (0.12, 0.48):
                if 0 <= t - beat_t < 0.22:
                    dt = t - beat_t
                    heartbeat += 0.65 * math.sin(TAU * 55.0 * dt) * math.exp(-dt * 18.0)
            # Rising steam hiss
            steam = (noise * 0.6 + low * 0.4) * (0.3 + 0.5 * math.sin(math.pi * u) ** 1.2)
            phase += TAU * (280.0 + 40.0 * math.sin(TAU * 6.0 * t)) / RATE
            steam += 0.2 * math.sin(phase) * math.sin(math.pi * u)
            signal = steam * 0.6 + heartbeat * 0.7

        elif cue == "jet_pistol":
            # Jet Pistol: Supersonic boom - instantaneous shock wave + razor air slice
            shock = math.exp(-t * 22.0)
            phase += TAU * (450.0 + 800.0 * math.exp(-t * 40.0)) / RATE
            sonic_slice = 0.55 * math.sin(phase) * shock
            boom = 0.65 * math.sin(TAU * 75.0 * t) * math.exp(-t * 12.0)
            puff = (noise - low) * 0.5 * math.exp(-t * 35.0)
            signal = sonic_slice + boom + puff

        elif cue == "gear3_inflate":
            # Hone Fuusen: Air forced into bone, rising whoosh and deep expansion
            p = t / duration
            phase += TAU * (80.0 + 160.0 * math.sin(p * math.pi)) / RATE
            air_rush = 0.45 * math.sin(phase) * (p ** 0.6)
            flesh = low * 0.6 * math.sin(math.pi * u)
            signal = air_rush + flesh

        elif cue == "gear3_impact":
            # Gigant Pistol Impact: Earth-shattering massive bass impact + debris crunch
            phase += TAU * (38.0 + 95.0 * math.exp(-t * 5.0)) / RATE
            sub_bass = 0.85 * math.sin(phase) * math.exp(-t * 4.0)
            sub_bass += 0.35 * math.sin(phase * 1.98) * math.exp(-t * 6.0)
            crunch = (noise * 0.4 + low * 0.6) * math.exp(-t * 16.0)
            rumble = 0.3 * math.sin(TAU * 24.0 * t) * math.exp(-t * 2.5)
            signal = sub_bass + crunch + rumble

        fade = min(1.0, t / 0.005) * min(1.0, (duration - t) / 0.035)
        samples.append(signal * fade)

    # Reverb reflections
    original = samples[:]
    for delay, gain in ((0.052, 0.12), (0.098, 0.07)):
        shift = int(RATE * delay)
        for i in range(shift, len(samples)):
            samples[i] += original[i - shift] * gain * min(1.0, (len(samples) - i) / (RATE * 0.035))

    peak = max(abs(x) for x in samples) or 1.0
    pcm = array("h", (int(x / peak * 22937) for x in samples))
    if sys.byteorder != "little":
        pcm.byteswap()
    destination = OUT / f"gomu_{cue}.wav"
    with wave.open(str(destination), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    print(f"{destination.name}: {duration:.2f}s, {len(pcm)} samples, peak -3.1 dBFS")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    cues = [
        ("stretch", 0.45),
        ("pistol", 0.38),
        ("bazooka", 0.65),
        ("gatling", 0.95),
        ("gear2_steam", 1.25),
        ("jet_pistol", 0.42),
        ("gear3_inflate", 0.85),
        ("gear3_impact", 1.45),
    ]
    for n, (cue, seconds) in enumerate(cues):
        generate(cue, seconds, 20260908 + n * 17)
