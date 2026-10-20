"""Synthetisiert die Retro-Soundeffekte von BULBRO als WAV (16 Bit, mono, 44,1 kHz).

Nur Standardbibliothek und numpy. Aufruf aus dem Projektordner:
    python tools/make_sfx.py            -> schreibt nach audio/sfx/
    python tools/make_sfx.py <ordner>   -> anderer Zielordner

Jeder Effekt ist eine kleine Funktion aus Oszillatoren, Rauschen, Hüllkurven und einfachen Filtern.
Der Zufallsgenerator hat einen festen Seed, damit die Dateien reproduzierbar sind.
"""
import os
import sys
import wave

import numpy as np

RATE = 44100
PEAK = 0.9  # Ziel-Lautstärke nach Normalisierung (Anteil von Vollaussteuerung)
RNG = np.random.default_rng(42)


# --- Bausteine ---------------------------------------------------------------

def t_axis(duration: float) -> np.ndarray:
    return np.arange(int(RATE * duration)) / RATE


def sweep(f_start: float, f_end: float, duration: float) -> np.ndarray:
    """Exponentieller Frequenzverlauf -> Phase (für Tonhöhen-Sweeps)."""
    t = t_axis(duration)
    freq = f_start * (f_end / f_start) ** (t / duration)
    return 2 * np.pi * np.cumsum(freq) / RATE


def sine(f_start: float, duration: float, f_end: float | None = None) -> np.ndarray:
    return np.sin(sweep(f_start, f_end or f_start, duration))


def square(f_start: float, duration: float, f_end: float | None = None, duty: float = 0.5) -> np.ndarray:
    phase = (sweep(f_start, f_end or f_start, duration) / (2 * np.pi)) % 1.0
    return np.where(phase < duty, 1.0, -1.0)


def saw(f_start: float, duration: float, f_end: float | None = None) -> np.ndarray:
    phase = (sweep(f_start, f_end or f_start, duration) / (2 * np.pi)) % 1.0
    return 2.0 * phase - 1.0


def noise(duration: float) -> np.ndarray:
    return RNG.uniform(-1.0, 1.0, int(RATE * duration))


def envelope(n: int, attack: float = 0.005, decay_power: float = 2.0) -> np.ndarray:
    """Kurzer Anstieg, dann abfallend (Potenzkurve) – typisch für Retro-Effekte."""
    env = np.ones(n)
    a = max(1, int(RATE * attack))
    env[:a] = np.linspace(0.0, 1.0, a)
    env[a:] = np.linspace(1.0, 0.0, n - a) ** decay_power
    return env


def lowpass(signal: np.ndarray, cutoff_start: float, cutoff_end: float | None = None) -> np.ndarray:
    """Einpoliger Tiefpass mit optional wanderndem Cutoff."""
    cutoffs = np.geomspace(cutoff_start, cutoff_end or cutoff_start, len(signal))
    alphas = 1.0 - np.exp(-2 * np.pi * cutoffs / RATE)
    out = np.empty_like(signal)
    y = 0.0
    for i, (x, a) in enumerate(zip(signal, alphas)):
        y += a * (x - y)
        out[i] = y
    return out


def shaped(signal: np.ndarray, **env_args) -> np.ndarray:
    return signal * envelope(len(signal), **env_args)


def mix(*parts: tuple[np.ndarray, float]) -> np.ndarray:
    length = max(len(p) for p, _ in parts)
    out = np.zeros(length)
    for part, gain in parts:
        out[: len(part)] += part * gain
    return out


def sequence(*parts: np.ndarray, gap: float = 0.0) -> np.ndarray:
    silence = np.zeros(int(RATE * gap))
    chunks = []
    for p in parts:
        chunks.extend([p, silence])
    return np.concatenate(chunks)


def note(name: str) -> float:
    """Notenname wie 'A4' oder 'C#5' -> Frequenz."""
    names = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((names[pitch] + 12 * (octave - 4)) / 12)


# --- Effekte -----------------------------------------------------------------

def sfx_shoot() -> np.ndarray:
    blip = shaped(square(900, 0.09, 420, duty=0.25), decay_power=2.5)
    click = shaped(lowpass(noise(0.02), 6000), decay_power=3)
    return mix((blip, 0.7), (click, 0.4))


def sfx_swing() -> np.ndarray:
    raw = noise(0.16)
    band = lowpass(raw, 2500, 900) - lowpass(raw, 500, 200)
    return shaped(band, attack=0.03, decay_power=1.5)


def sfx_hit() -> np.ndarray:
    thump = shaped(sine(240, 0.08, 90), decay_power=2)
    crack = shaped(lowpass(noise(0.05), 3500), decay_power=3)
    return mix((thump, 0.8), (crack, 0.6))


def sfx_hit_crit() -> np.ndarray:
    ping = shaped(square(1320, 0.12, 1760, duty=0.3), decay_power=2)
    return mix((sfx_hit(), 0.8), (ping, 0.35))


def sfx_enemy_death() -> np.ndarray:
    pop = shaped(sine(650, 0.16, 140), decay_power=1.8)
    puff = shaped(lowpass(noise(0.1), 2500, 600), decay_power=2)
    return mix((pop, 0.8), (puff, 0.5))


def sfx_spark() -> np.ndarray:
    a = shaped(sine(1320, 0.08), decay_power=2)
    b = shaped(sine(1980, 0.06), decay_power=2.5)
    return mix((a, 0.6), (b, 0.4))


def sfx_level_up() -> np.ndarray:
    tones = [shaped(square(note(n), 0.08, duty=0.25), decay_power=1.2) for n in ("C5", "E5", "G5")]
    final = shaped(mix((square(note("C6"), 0.35, duty=0.25), 0.6), (sine(note("C6") * 2, 0.35), 0.3)), decay_power=1.5)
    return sequence(*tones, final)


def sfx_buy() -> np.ndarray:
    first = shaped(square(988, 0.06, duty=0.25), decay_power=1)
    second = shaped(mix((square(1319, 0.28, duty=0.25), 0.6), (sine(2638, 0.28), 0.3)), decay_power=2)
    return sequence(first, second)


def sfx_reroll() -> np.ndarray:
    ticks = [shaped(lowpass(noise(0.025), 5000 - i * 700), decay_power=3) for i in range(5)]
    return sequence(*ticks, gap=0.035)


def sfx_player_hurt() -> np.ndarray:
    buzz = lowpass(saw(320, 0.28, 70), 2200, 500)
    crunch = lowpass(noise(0.12), 3000, 400)
    return shaped(mix((buzz, 0.8), (crunch, 0.4)), decay_power=1.5)


def sfx_boss_warning() -> np.ndarray:
    parts = []
    for i in range(4):
        freq = 440 if i % 2 == 0 else 330
        tone = square(freq, 0.28, duty=0.5) * (0.75 + 0.25 * np.sin(2 * np.pi * 18 * t_axis(0.28)))
        parts.append(shaped(tone, attack=0.01, decay_power=0.6))
    return sequence(*parts, gap=0.02)


def sfx_explosion() -> np.ndarray:
    rumble = lowpass(noise(0.55), 4500, 150)
    boom = shaped(sine(110, 0.4, 40), decay_power=1.5)
    return mix((shaped(rumble, attack=0.002, decay_power=1.6), 0.9), (boom, 0.8))


def sfx_wave_clear() -> np.ndarray:
    tones = [shaped(mix((square(note(n), 0.1, duty=0.25), 0.5), (sine(note(n), 0.1), 0.5)), decay_power=1.2)
             for n in ("G4", "C5", "E5")]
    final = shaped(mix((square(note("G5"), 0.4, duty=0.25), 0.5), (sine(note("G5"), 0.4), 0.5)), decay_power=1.8)
    return sequence(*tones, final)


def sfx_heal() -> np.ndarray:
    return shaped(mix((sine(660, 0.22, 990), 0.7), (sine(1320, 0.22, 1980), 0.2)), attack=0.02, decay_power=1.5)


def sfx_ui_click() -> np.ndarray:
    return shaped(square(1800, 0.025, 1200, duty=0.3), decay_power=3)


EFFECTS = {
    "shoot": sfx_shoot,
    "swing": sfx_swing,
    "hit": sfx_hit,
    "hit_crit": sfx_hit_crit,
    "enemy_death": sfx_enemy_death,
    "spark": sfx_spark,
    "level_up": sfx_level_up,
    "buy": sfx_buy,
    "reroll": sfx_reroll,
    "player_hurt": sfx_player_hurt,
    "boss_warning": sfx_boss_warning,
    "explosion": sfx_explosion,
    "wave_clear": sfx_wave_clear,
    "heal": sfx_heal,
    "ui_click": sfx_ui_click,
}


def write_wav(path: str, signal: np.ndarray) -> None:
    peak = np.max(np.abs(signal)) or 1.0
    data = np.int16(signal / peak * PEAK * 32767)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())


def main() -> None:
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join("audio", "sfx")
    os.makedirs(out_dir, exist_ok=True)
    for name, make in EFFECTS.items():
        write_wav(os.path.join(out_dir, f"{name}.wav"), make())
    print(f"{len(EFFECTS)} Effekte nach {out_dir} geschrieben")


if __name__ == "__main__":
    main()
