#!/usr/bin/env python3
"""Synthesises the Concept 011 intro audio.

Everything here is generated from scratch — no sampled or licensed material —
so the app ships nothing it does not own.

On the swell: the brief was "THX style, not the actual THX". The THX Deep Note
is trademarked and its specific voicing is protected, so this is *not* a
reconstruction of it. What it borrows is the dramatic idea both share and
neither owns: many voices starting scattered and sliding into one consonant
stack. That idea also happens to suit this app, where the opening line is
"we're gathering a community" — the sound does what the sentence says.

The voicing is deliberately different from Deep Note: a stack of octaves and
fifths on E, converging over 3.5s, rather than Deep Note's cluster spread.

    python3 Tools/generate_audio.py

Writes to SharedVisionsConcepts01/Resources/Audio/.
"""

import math
import os
import random
import struct
import wave

RATE = 48_000
OUT = "SharedVisionsConcepts01/Resources/Audio"

random.seed(20_261_105)  # reproducible renders


# ---------------------------------------------------------------- helpers

def write_wav(name, samples):
    """16-bit mono WAV. Mono matters: RealityKit needs mono for a point source."""
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)

    peak = max(abs(s) for s in samples) or 1.0
    # Leave 1.5 dB of headroom so the device mixer has somewhere to go.
    scale = 0.84 / peak

    frames = bytearray()
    for s in samples:
        v = int(max(-1.0, min(1.0, s * scale)) * 32_767)
        frames += struct.pack("<h", v)

    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(bytes(frames))

    print(f"  {name}: {len(samples) / RATE:.2f}s, {len(frames) // 1024} KB")


def lowpass(samples, cutoff):
    """One-pole lowpass. Enough to take the edge off synthetic noise."""
    a = 1 - math.exp(-2 * math.pi * cutoff / RATE)
    out, y = [], 0.0
    for x in samples:
        y += a * (x - y)
        out.append(y)
    return out


def highpass(samples, cutoff):
    low = lowpass(samples, cutoff)
    return [x - l for x, l in zip(samples, low)]


def white(n):
    return [random.uniform(-1, 1) for _ in range(n)]


def brown(n, leak=0.996):
    """Integrated noise — the 1/f tilt that makes rumble sound like weather."""
    out, y = [], 0.0
    for x in white(n):
        y = y * leak + x * 0.02
        out.append(y)
    return out


# ---------------------------------------------------------------- the swell

def swell(duration=5.0):
    n = int(RATE * duration)

    # Octaves and fifths on E. Stacked this way the arrival reads as one
    # enormous note rather than a chord, which is what gives it the weight.
    targets = [41.2, 61.7, 82.4, 123.5, 164.8, 246.9, 329.6, 494.0]

    voices = []
    for i in range(20):
        target = targets[i % len(targets)]
        voices.append({
            "start": random.uniform(85, 330),      # scattered, unsettled
            "target": target,
            "detune": random.uniform(-0.6, 0.6),   # cents of spread on arrival
            "phase": random.uniform(0, 2 * math.pi),
            "pan_gain": random.uniform(0.55, 1.0),
            # Voices arrive at slightly different moments so the convergence
            # lands as a gathering rather than a gear change.
            "arrive": random.uniform(0.62, 0.84),
            "drift_rate": random.uniform(0.12, 0.5),
            "drift_depth": random.uniform(1.5, 7.0),
        })

    out = [0.0] * n

    for v in voices:
        phase = v["phase"]
        for i in range(n):
            t = i / n

            # Glide, eased so it creeps then rushes.
            g = min(1.0, t / v["arrive"])
            g = g * g * (3 - 2 * g)

            drift = math.sin(2 * math.pi * v["drift_rate"] * (i / RATE)) * v["drift_depth"] * (1 - g)
            freq = v["start"] + (v["target"] + v["detune"] - v["start"]) * g + drift

            phase += 2 * math.pi * freq / RATE

            # A few harmonics give it body; weight drops with harmonic number
            # so it stays warm rather than buzzy.
            s = math.sin(phase) + 0.42 * math.sin(2 * phase) + 0.17 * math.sin(3 * phase)

            # Swell: near-silent start, steep climb, short plateau, quick fall.
            if t < 0.80:
                env = (t / 0.80) ** 2.4
            elif t < 0.92:
                env = 1.0
            else:
                env = max(0.0, 1 - (t - 0.92) / 0.08)

            out[i] += s * env * v["pan_gain"] * 0.05

    # Sub reinforcement under the arrival, so it is felt as well as heard.
    for i in range(n):
        t = i / n
        env = 0.0 if t < 0.45 else ((t - 0.45) / 0.35) ** 2
        env = min(env, 1.0)
        if t > 0.92:
            env *= max(0.0, 1 - (t - 0.92) / 0.08)
        out[i] += math.sin(2 * math.pi * 41.2 * i / RATE) * env * 0.5

    return lowpass(out, 7_000)


# ---------------------------------------------------------------- thunder

def thunder(duration, cutoff, body_hz, sharpness):
    """A crack over a decaying rumble.

    `sharpness` sets how fast the initial transient collapses — a near strike
    cracks, a distant one just rolls.
    """
    n = int(RATE * duration)
    noise = lowpass(white(n), cutoff)
    noise = highpass(noise, 70)
    rumble = brown(n)

    out = []
    for i in range(n):
        t = i / n
        crack = math.exp(-t * sharpness)
        tail = math.exp(-t * 3.2)
        body = math.sin(2 * math.pi * body_hz * i / RATE) * math.exp(-t * 9) * 0.5
        out.append(noise[i] * crack * 0.9 + rumble[i] * tail * 1.4 + body)

    # Fade the last 40ms so looping or truncation never clicks.
    fade = int(RATE * 0.04)
    for i in range(fade):
        out[n - 1 - i] *= i / fade

    return out


def rumble_bed(duration=4.0):
    """Quiet loopable weather bed for under the storm."""
    n = int(RATE * duration)
    out = lowpass(brown(n), 220)

    # Equal-power crossfade across the seam so it loops without a bump.
    seam = int(RATE * 0.5)
    for i in range(seam):
        a = i / seam
        out[i] = out[i] * a + out[n - seam + i] * (1 - a)
    return out[: n - seam]


# ---------------------------------------------------------------- main

if __name__ == "__main__":
    print("generating intro audio:")
    write_wav("intro-swell.wav", swell())
    write_wav("thunder-near.wav", thunder(0.75, 3_200, 58, 26))
    write_wav("thunder-far.wav", thunder(1.30, 900, 42, 7))
    write_wav("storm-bed.wav", rumble_bed())
    print("done")
