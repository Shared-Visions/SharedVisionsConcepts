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

def swell(duration=4.6):
    """Dramatic build for the intro.

    **Deliberately not a converging glissando.** The first version had many
    voices sliding from scattered pitches into a stacked chord, and on device
    it was recognisable as the THX Deep Note — which is a registered
    trademark. Different pitch content was not enough protection, because the
    glide *is* the recognisable gesture, not the voicing.

    This replaces it with a different gesture entirely:

      - voices **enter at their final pitches**, staggered, so the chord
        assembles like an organ stop being pulled rather than sliding into
        focus. Nothing glides.
      - the voicing is **quartal** — fourths, fifths and a ninth on E — rather
        than the octave-and-fifth power stack. Open and unresolved instead of
        monolithic, which also suits "we're gathering a community" better.
      - tension comes from a **filtered noise riser**, a standard cinematic
        device that belongs to nobody, rather than from pitch movement.
      - it lands on an **impact**, not an arrival of travel.
    """
    n = int(RATE * duration)

    # Quartal stack on E: root, fourth, fifth, octave, then upper fourths and
    # a ninth. No bare octave doubling of the root, which is what makes a
    # power stack sound monolithic.
    voicing = [41.2, 55.0, 61.7, 82.4, 110.0, 123.5, 164.8, 220.0, 246.9, 277.2]

    out = [0.0] * n

    for index, base in enumerate(voicing):
        # Staggered entries: low voices first, so the chord builds upward.
        entry = 0.08 + (index / len(voicing)) * 0.54
        # Two slightly detuned copies per pitch for width, without glide.
        for copy in range(2):
            freq = base * (1 + random.uniform(-0.0016, 0.0016))
            phase = random.uniform(0, 2 * math.pi)
            # Slow amplitude shimmer, so a held chord is not static.
            trem_rate = random.uniform(0.3, 1.1)
            trem_depth = random.uniform(0.05, 0.16)

            for i in range(n):
                t = i / n
                if t < entry:
                    continue

                # Each voice fades in over its own short ramp.
                ramp = min(1.0, (t - entry) / 0.22)
                ramp = ramp * ramp * (3 - 2 * ramp)

                phase += 2 * math.pi * freq / RATE
                s = math.sin(phase) + 0.34 * math.sin(2 * phase) + 0.12 * math.sin(3 * phase)
                trem = 1 - trem_depth + trem_depth * math.sin(2 * math.pi * trem_rate * (i / RATE))

                # Overall shape: steady climb, brief plateau, quick release.
                if t < 0.86:
                    env = (t / 0.86) ** 1.9
                elif t < 0.94:
                    env = 1.0
                else:
                    env = max(0.0, 1 - (t - 0.94) / 0.06)

                out[i] += s * ramp * trem * env * 0.042

    # Filtered noise riser. Sweeping a lowpass upward reads as rising tension
    # without moving any pitch, which is the whole point here.
    riser = white(n)
    swept = [0.0] * n
    y = 0.0
    for i in range(n):
        t = i / n
        cutoff = 180 + (t ** 2.2) * 5_200
        a = 1 - math.exp(-2 * math.pi * cutoff / RATE)
        y += a * (riser[i] - y)
        env = 0.0 if t > 0.94 else (t ** 2.6)
        swept[i] = y * env * 0.30
    for i in range(n):
        out[i] += swept[i]

    # Sub and impact at the landing, so the arrival is felt.
    impact_at = 0.86
    for i in range(n):
        t = i / n
        sub_env = 0.0 if t < 0.3 else min(1.0, ((t - 0.3) / 0.5) ** 2)
        if t > 0.94:
            sub_env *= max(0.0, 1 - (t - 0.94) / 0.06)
        out[i] += math.sin(2 * math.pi * 41.2 * i / RATE) * sub_env * 0.46

        if t >= impact_at:
            # Short decaying thump on the downbeat of the plateau.
            k = (t - impact_at) * n / RATE
            out[i] += math.sin(2 * math.pi * 58 * k) * math.exp(-k * 7) * 0.5

    return lowpass(out, 8_000)


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
