#!/usr/bin/env python3
"""Generate every sound in the game, from scratch.

There is no audio in the repo that did not come out of this script, and no
network fetch to get any. Run it and assets/audio/ is rebuilt byte for byte:

    python3 tool/make_sounds.py

These are placeholders and they sound like it - a handheld console, not a
rover. They exist so the game is audible and so every trigger is wired and
provably firing. Replacing one is a straight file swap: keep the name, keep
the sample rate, and nothing in lib/ needs to change.

Deliberately stdlib only (wave, math, struct, random). The container that
builds this has no numpy and no way to install one.

Two constraints worth knowing before editing:

1. `engine.wav` LOOPS. Its length must be a whole number of periods of its
   fundamental or the seam clicks once per loop, which at ~9 Hz is a rattle
   rather than a click. _cycle_exact() picks the nearest length that
   divides evenly; do not hand it a duration and expect it back.
2. Every clip starts and ends at zero amplitude. A waveform cut off mid-swing
   pops when it starts and pops again when it stops, and on a one-shot fired
   at every coin that is the loudest thing in the mix.
"""

import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   'assets', 'audio')


# --- helpers ---------------------------------------------------------------

def _write(name, samples, peak=0.62):
    """Normalise to `peak`, then write 16-bit mono PCM."""
    high = max(abs(s) for s in samples) or 1.0
    scale = (peak / high) * 32767
    frames = b''.join(struct.pack('<h', int(max(-32768, min(32767, s * scale))))
                      for s in samples)
    path = os.path.join(OUT, name)
    with wave.open(path, 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(frames)
    print(f'{name:16s} {len(samples) / RATE:5.2f}s  {len(frames) + 44:7d} bytes')


def _cycle_exact(duration, freq):
    """A sample count near `duration` holding a whole number of cycles.

    A looping tone whose buffer ends part-way through a cycle jumps
    discontinuously back to the start, and that discontinuity is a click on
    every single loop.
    """
    period = RATE / freq
    return int(round(duration * RATE / period)) * period


def _fade(samples, ms_in=4, ms_out=12):
    """Ramp both ends to silence so nothing starts or stops mid-swing."""
    n_in = min(int(RATE * ms_in / 1000), len(samples) // 2)
    n_out = min(int(RATE * ms_out / 1000), len(samples) // 2)
    for i in range(n_in):
        samples[i] *= i / n_in
    for i in range(n_out):
        samples[-1 - i] *= i / n_out
    return samples


def _adsr(i, n, attack=0.01, decay=0.6):
    """Percussive envelope: near-instant attack, exponential tail."""
    t = i / RATE
    total = n / RATE
    if t < attack:
        return t / attack
    return math.exp(-(t - attack) / (decay * total))


# --- the sounds ------------------------------------------------------------

def engine():
    """A small, unhappy single-cylinder motor, as a seamless loop.

    Built from a pulse train rather than a sine: each cycle gets a sharp
    attack and a decay, which is what makes an engine read as an engine
    instead of as a hum. The game plays this at a variable rate, so the
    pitch here is only the idle - keep the fundamental low or speeding it
    up runs it into a whine.
    """
    freq = 42.0
    n = int(_cycle_exact(0.75, freq))
    period = RATE / freq
    out = []
    for i in range(n):
        phase = (i % period) / period          # 0..1 within one firing cycle
        # Sharp attack, exponential decay - one combustion event.
        pulse = math.exp(-phase * 7.0) * (1 - phase)
        body = (math.sin(2 * math.pi * phase)
                + 0.55 * math.sin(4 * math.pi * phase)
                + 0.30 * math.sin(6 * math.pi * phase)
                + 0.18 * math.sin(10 * math.pi * phase))
        # Combustion is not tidy. A little noise stops it sounding like an
        # organ. Two constraints on it: it must be periodic (seeded off the
        # phase, not the sample) or the loop seam is audible, and it must
        # be windowed to zero at both ends of the cycle - at phase 0 the
        # pulse envelope is at full height, so raw noise there is a step
        # discontinuity across the seam, which is a click on every loop.
        random.seed(int(phase * 512))
        grit = (random.random() - 0.5) * 0.22 * math.sin(math.pi * phase)
        out.append(pulse * (body + grit))

    # A pulse train is not symmetric about zero, and the DC offset it
    # leaves both eats headroom and thumps when the loop starts and stops.
    mean = sum(out) / len(out)
    return [s - mean for s in out]
    # NOT faded: fading a loop would put a hole in it on every cycle.


def coin():
    """Pickup: two quick rising notes. Short, because it fires a lot."""
    n = int(RATE * 0.16)
    out = []
    for i in range(n):
        t = i / RATE
        freq = 988 if t < 0.055 else 1319       # B5 then E6
        # Re-triggered envelope, so the second note has its own attack.
        local = i if t < 0.055 else i - int(RATE * 0.055)
        env = _adsr(local, n, attack=0.004, decay=0.35)
        out.append(env * (math.sin(2 * math.pi * freq * t)
                          + 0.3 * math.sin(4 * math.pi * freq * t)))
    return _fade(out)


def crash():
    """Impact: a noise burst over a falling thud."""
    n = int(RATE * 0.45)
    out = []
    random.seed(7)
    noise = [random.random() * 2 - 1 for _ in range(n)]
    # One-pole low-pass, so it reads as debris rather than as static.
    filtered, prev = [], 0.0
    for s in noise:
        prev = prev + 0.22 * (s - prev)
        filtered.append(prev)
    for i in range(n):
        t = i / RATE
        env = math.exp(-t * 9)
        thud = math.sin(2 * math.pi * (90 - 55 * t) * t) * math.exp(-t * 14)
        out.append(env * filtered[i] * 1.4 + thud)
    return _fade(out)


def finish():
    """Course cleared: a four-note rise. The only long sound in the set."""
    notes = [523.25, 659.25, 783.99, 1046.50]   # C5 E5 G5 C6
    step = int(RATE * 0.13)
    n = step * len(notes) + int(RATE * 0.35)
    out = [0.0] * n
    for k, freq in enumerate(notes):
        start = k * step
        # The last note rings on; the others are clipped by the next.
        length = n - start if k == len(notes) - 1 else int(RATE * 0.42)
        for i in range(min(length, n - start)):
            t = i / RATE
            env = _adsr(i, length, attack=0.006, decay=0.42)
            out[start + i] += env * (math.sin(2 * math.pi * freq * t)
                                     + 0.35 * math.sin(4 * math.pi * freq * t)
                                     + 0.12 * math.sin(6 * math.pi * freq * t))
    return _fade(out)


def fail():
    """Run over: the finish jingle's opposite, falling and detuned."""
    notes = [392.00, 329.63, 261.63]            # G4 E4 C4
    step = int(RATE * 0.16)
    n = step * len(notes) + int(RATE * 0.4)
    out = [0.0] * n
    for k, freq in enumerate(notes):
        start = k * step
        length = n - start
        for i in range(length):
            t = i / RATE
            env = _adsr(i, length, attack=0.008, decay=0.4)
            # A slightly flat second voice - the sourness is the point.
            out[start + i] += env * (math.sin(2 * math.pi * freq * t)
                                     + 0.5 * math.sin(2 * math.pi * freq * 0.99 * t))
    return _fade(out)


def tap():
    """UI press. Very short and fairly quiet - it fires on every button."""
    n = int(RATE * 0.05)
    out = []
    for i in range(n):
        t = i / RATE
        env = math.exp(-t * 90)
        out.append(env * math.sin(2 * math.pi * 1400 * t))
    return _fade(_scale(out, 0.55), ms_in=1, ms_out=6)


def purchase():
    """Something was bought. Richer than a tap, shorter than the finish."""
    notes = [659.25, 880.00, 1174.66]           # E5 A5 D6
    step = int(RATE * 0.07)
    n = step * len(notes) + int(RATE * 0.22)
    out = [0.0] * n
    for k, freq in enumerate(notes):
        start = k * step
        length = n - start
        for i in range(length):
            t = i / RATE
            env = _adsr(i, length, attack=0.004, decay=0.3)
            out[start + i] += env * math.sin(2 * math.pi * freq * t)
    return _fade(out)


def warning():
    """Oxygen low. Two flat beeps, deliberately unpleasant."""
    n = int(RATE * 0.34)
    out = []
    for i in range(n):
        t = i / RATE
        on = t < 0.1 or (0.17 < t < 0.27)
        if not on:
            out.append(0.0)
            continue
        # Square-ish, because a sine is too polite for an alarm.
        s = math.sin(2 * math.pi * 640 * t)
        out.append((1 if s > 0 else -1) * 0.7 + s * 0.3)
    return _fade(out)


def _scale(samples, factor):
    return [s * factor for s in samples]


SOUNDS = {
    'engine.wav': (engine, 0.5),      # quieter: it plays continuously
    'coin.wav': (coin, 0.55),
    'crash.wav': (crash, 0.7),
    'finish.wav': (finish, 0.6),
    'fail.wav': (fail, 0.55),
    'tap.wav': (tap, 0.4),
    'purchase.wav': (purchase, 0.55),
    'warning.wav': (warning, 0.45),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, (fn, peak) in SOUNDS.items():
        _write(name, fn(), peak=peak)


if __name__ == '__main__':
    main()
