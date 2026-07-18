#!/usr/bin/env python3
"""Synthesize the chiptune SFX set into assets/sfx as tiny mono WAVs.

Square and triangle voices with simple decay envelopes, 22050 Hz, 16-bit.
Deterministic output; run again after tweaking and commit the results.
"""

import math
import struct
import wave
from pathlib import Path

RATE = 22050
DEST = Path(__file__).resolve().parent.parent / "assets" / "sfx"


def square(t, freq):
    return 1.0 if math.sin(2 * math.pi * freq * t) >= 0 else -1.0


def triangle(t, freq):
    return 2.0 / math.pi * math.asin(math.sin(2 * math.pi * freq * t))


def render(segments, voice=square, volume=0.4):
    """segments: list of (freq_start, freq_end, seconds). freq 0 = rest."""
    samples = []
    for f0, f1, dur in segments:
        n = int(RATE * dur)
        for i in range(n):
            t = i / RATE
            if f0 <= 0:
                samples.append(0.0)
                continue
            freq = f0 + (f1 - f0) * (i / n)
            env = 1.0 - (i / n) * 0.85
            samples.append(voice(t, freq) * env * volume)
    return samples


def write_wav(name, samples):
    DEST.mkdir(parents=True, exist_ok=True)
    path = DEST / f"{name}.wav"
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = b"".join(
            struct.pack("<h", max(-32767, min(32767, int(s * 32767))))
            for s in samples)
        w.writeframes(frames)
    print(f"wrote {path} ({len(samples) / RATE:.2f}s)")


# Note frequencies used below (equal temperament).
C5, E5, G5, C6, E6, G6 = 523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0
G4, A4, C4 = 392.0, 440.0, 261.63

write_wav("panel_open", render([(C5, G5, 0.06), (G5, C6, 0.06)], triangle, 0.35))
write_wav("page", render([(G5, E5, 0.05)], triangle, 0.3))
write_wav("correct", render([(C5, C5, 0.07), (E5, E5, 0.07), (G5, G5, 0.07),
                             (C6, C6, 0.12)], square, 0.3))
write_wav("wrong", render([(A4, G4, 0.12), (G4, C4, 0.18)], square, 0.32))
write_wav("blip", render([(C6, E6, 0.05)], square, 0.25))
write_wav("fanfare", render([(C5, C5, 0.09), (E5, E5, 0.09), (G5, G5, 0.09),
                             (C6, C6, 0.14), (G5, G5, 0.07), (C6, C6, 0.22)],
                            square, 0.3))
write_wav("glitch", render([(C6, G4, 0.05), (G5, E6, 0.05), (C5, C6, 0.05),
                            (E6, G6, 0.08)], square, 0.28))
