#!/usr/bin/env python3
"""Synthesize one looping chiptune track per act into assets/music.

Two voices: triangle bass on roots and fifths, square lead arpeggiating
chord tones with a fixed rhythm mask. Deterministic; 22050 Hz mono 16-bit.
Each track is 8 bars and loops cleanly (every note decays inside its slot).
"""

import math
import struct
import wave
from pathlib import Path

RATE = 22050
DEST = Path(__file__).resolve().parent.parent / "assets" / "music"


def freq(semi_from_c4: float) -> float:
    return 261.6256 * 2 ** (semi_from_c4 / 12.0)


def square(t, f):
    return 1.0 if math.sin(2 * math.pi * f * t) >= 0 else -1.0


def triangle(t, f):
    return 2.0 / math.pi * math.asin(math.sin(2 * math.pi * f * t))


# Chord tone offsets relative to the chord root.
MAJ = [0, 4, 7, 12]
MIN = [0, 3, 7, 12]

# Per act: bpm, progression of (root semitone from C4, chord), lead octave
# shift, and an 8-slot rhythm mask (1 = play the arp step, 0 = rest).
TRACKS = {
    "act1": {
        "bpm": 116,
        "prog": [(0, MAJ), (5, MAJ), (7, MAJ), (0, MAJ)] * 2,
        "lead_oct": 12,
        "mask": [1, 1, 1, 0, 1, 1, 0, 1],
        "arp": [0, 1, 2, 1, 0, 1, 3, 2],
    },
    "act2": {
        "bpm": 108,
        "prog": [(9 - 12, MIN), (5, MAJ), (0, MAJ), (7, MAJ)] * 2,
        "lead_oct": 12,
        "mask": [1, 0, 1, 1, 1, 0, 1, 0],
        "arp": [0, 2, 1, 2, 0, 2, 3, 1],
    },
    "act3": {
        "bpm": 100,
        "prog": [(2, MIN), (10 - 12, MAJ), (5, MAJ), (0, MAJ)] * 2,
        "lead_oct": 12,
        "mask": [1, 0, 0, 1, 0, 1, 0, 1],
        "arp": [0, 1, 2, 3, 2, 1, 2, 0],
    },
    "act4": {
        "bpm": 92,
        "prog": [(4 - 12, MIN), (0, MAJ), (7 - 12, MAJ), (2, MAJ)] * 2,
        "lead_oct": 0,
        "mask": [1, 0, 1, 0, 1, 0, 1, 1],
        "arp": [0, 2, 1, 3, 0, 2, 3, 2],
    },
}

BASS_PATTERN = [0, None, 7, None, 0, None, 7, 0]  # offsets, None = rest


def render(spec):
    bpm = spec["bpm"]
    slot = 60.0 / bpm / 2.0            # eighth note seconds
    slots_per_bar = 8
    bars = len(spec["prog"])
    total = int(round(bars * slots_per_bar * slot * RATE))
    samples = [0.0] * total

    def add_note(start_s, dur_s, f, voice, amp):
        n0 = int(start_s * RATE)
        n = int(dur_s * RATE)
        for i in range(n):
            if n0 + i >= total:
                break
            t = i / RATE
            env = min(1.0, i / 200.0) * (1.0 - i / n) ** 0.6
            samples[n0 + i] += voice(t, f) * env * amp

    for bar, (root, chord) in enumerate(spec["prog"]):
        bar_start = bar * slots_per_bar * slot
        for s in range(slots_per_bar):
            t0 = bar_start + s * slot
            b = BASS_PATTERN[s]
            if b is not None:
                add_note(t0, slot * 0.95, freq(root + b - 24), triangle, 0.30)
            if spec["mask"][s]:
                tone = chord[spec["arp"][s]]
                add_note(t0, slot * 0.9, freq(root + tone + spec["lead_oct"]),
                         square, 0.14)

    peak = max(abs(s) for s in samples) or 1.0
    return [s / peak * 0.85 for s in samples]


DEST.mkdir(parents=True, exist_ok=True)
for name, spec in TRACKS.items():
    samples = render(spec)
    path = DEST / f"{name}.wav"
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767))
            for s in samples))
    print(f"wrote {path} ({len(samples) / RATE:.1f}s)")
