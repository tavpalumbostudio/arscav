#!/usr/bin/env python3
"""Generate short hunt sound-effect WAV files for the app bundle."""

from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44_100
OUT_DIR = Path(__file__).resolve().parent.parent / "Resources" / "Sounds"


def write_tone(path: Path, notes: list[tuple[float, float]], volume: float = 0.85) -> None:
    samples: list[int] = []
    for index, (frequency, duration) in enumerate(notes):
        frame_count = int(SAMPLE_RATE * duration)
        for frame in range(frame_count):
            time = frame / SAMPLE_RATE
            attack = min(1.0, time * 40.0)
            release = min(1.0, (duration - time) * 40.0)
            envelope = attack * release
            wave_value = math.sin(2.0 * math.pi * frequency * time)
            sample = max(-1.0, min(1.0, volume * envelope * wave_value))
            samples.append(int(sample * 32767.0))
        if index + 1 < len(notes):
            gap = int(SAMPLE_RATE * 0.025)
            samples.extend([0] * gap)

    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        frames = b"".join(struct.pack("<h", sample) for sample in samples)
        wav.writeframes(frames)


def main() -> None:
    write_tone(OUT_DIR / "flip.wav", [(640, 0.06)], volume=0.8)
    write_tone(OUT_DIR / "success.wav", [(523, 0.09), (659, 0.11)], volume=0.85)
    write_tone(OUT_DIR / "miss.wav", [(260, 0.12)], volume=0.75)
    write_tone(OUT_DIR / "complete.wav", [(392, 0.08), (494, 0.08), (587, 0.12)], volume=0.82)
    print(f"Wrote hunt SFX to {OUT_DIR}")


if __name__ == "__main__":
    main()
