"""Erzeugt einen einfachen, nahtlos loopenden Chiptune-Platzhalter für die Musik (WAV, mono, 44,1 kHz).

Nur Standardbibliothek und numpy. Aufruf aus dem Projektordner:
    python tools/make_music.py   -> audio/music/bulbro_loop.wav

Aufbau: 8 Takte bei 120 BPM in a-Moll (Am - F - C - G, je zwei Takte) mit Bass, Arpeggio, Kick und Hi-Hat.
Gedacht als Platzhalter, bis CC0-Musik (z. B. von kenney.nl oder opengameart.org) eingesetzt wird.
"""
import os
import sys
import wave

import numpy as np

RATE = 44100
BPM = 120
BEAT = 60.0 / BPM
BARS = 8
STEPS_PER_BEAT = 4
PEAK = 0.8
RNG = np.random.default_rng(7)

# Grundton und Akkordtöne (Halbtöne über dem Grundton) pro zwei Takte
CHORDS = [("A2", [0, 3, 7]), ("F2", [0, 4, 7]), ("C3", [0, 4, 7]), ("G2", [0, 4, 7])]
NOTE_OFFSETS = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}


def freq(name: str, semitones: int = 0) -> float:
    base = NOTE_OFFSETS[name[0]] + 12 * (int(name[-1]) - 4)
    return 440.0 * 2 ** ((base + semitones) / 12)


def square(f: float, n: int, duty: float = 0.5) -> np.ndarray:
    phase = (np.arange(n) * f / RATE) % 1.0
    return np.where(phase < duty, 1.0, -1.0)


def envelope(n: int, decay_power: float) -> np.ndarray:
    return np.linspace(1.0, 0.0, n) ** decay_power


def main() -> None:
    step = int(RATE * BEAT / STEPS_PER_BEAT)
    total_steps = BARS * 4 * STEPS_PER_BEAT
    out = np.zeros(step * total_steps)
    for s in range(total_steps):
        start = s * step
        bar = s // (4 * STEPS_PER_BEAT)
        root, chord = CHORDS[(bar // 2) % len(CHORDS)]
        # Bass auf jeder Achtel, Oktave im Wechsel
        if s % 2 == 0:
            octave = 12 if (s // 2) % 4 == 3 else 0
            n = step * 2
            out[start:start + n] += square(freq(root, octave), n, 0.5) * envelope(n, 0.6) * 0.30
        # Arpeggio auf jeder Sechzehntel
        tone = chord[s % len(chord)] + 24
        out[start:start + step] += square(freq(root, tone), step, 0.25) * envelope(step, 1.5) * 0.14
        # Kick auf den Zählzeiten, Hi-Hat auf den Offbeats
        if s % STEPS_PER_BEAT == 0:
            t = np.arange(step) / RATE
            kick = np.sin(2 * np.pi * np.cumsum(120 * (40 / 120) ** (t / 0.12)) / RATE)
            out[start:start + step] += kick * envelope(step, 2.0) * 0.45
        if s % STEPS_PER_BEAT == 2:
            hat = RNG.uniform(-1, 1, step // 2) * envelope(step // 2, 4.0)
            out[start:start + step // 2] += hat * 0.10
    data = np.int16(out / (np.max(np.abs(out)) or 1.0) * PEAK * 32767)
    out_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join("audio", "music", "bulbro_loop.wav")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with wave.open(out_path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())
    print(f"Musik-Loop ({BARS} Takte, {total_steps * step / RATE:.1f} s) nach {out_path} geschrieben")


if __name__ == "__main__":
    main()
