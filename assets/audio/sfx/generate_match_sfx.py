"""Create original, short cartoon match cues as 44.1 kHz PCM WAV files."""

from math import exp, pi, sin
from pathlib import Path
import random
import struct
import wave


RATE = 44100
HERE = Path(__file__).parent


def write(name: str, seconds: float, voice) -> None:
    samples = [voice(index / RATE) for index in range(int(seconds * RATE))]
    peak = max(abs(sample) for sample in samples)
    gain = 0.66 / peak
    with wave.open(str(HERE / name), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, sample * gain)) * 32767)) for sample in samples))


rng = random.Random(472)


def tick(t: float) -> float:
    envelope = min(1.0, t / 0.004) * exp(-17.0 * t)
    return envelope * (sin(2 * pi * 740 * t) + 0.28 * sin(2 * pi * 1480 * t))


def title(t: float) -> float:
    slide = min(1.0, t / 0.84)
    whoosh = rng.uniform(-1.0, 1.0) * 0.2 * sin(pi * slide) if t < 0.84 else 0.0
    impact_time = max(0.0, t - 0.84)
    impact = 0.0 if t < 0.84 else exp(-8.5 * impact_time) * (
        0.85 * sin(2 * pi * (205 * impact_time + 150 * impact_time * impact_time))
        + 0.28 * sin(2 * pi * 515 * impact_time)
    )
    sparkle_time = max(0.0, t - 1.00)
    sparkle = 0.0 if t < 1.00 else 0.22 * exp(-10.0 * sparkle_time) * sin(2 * pi * 930 * sparkle_time)
    return whoosh + impact + sparkle


def go(t: float) -> float:
    rise = min(1.0, t / 0.02) * exp(-4.8 * t)
    tone = sin(2 * pi * (410 * t + 380 * t * t)) + 0.3 * sin(2 * pi * (820 * t + 760 * t * t))
    snap = rng.uniform(-1.0, 1.0) * exp(-38.0 * t) * 0.25
    return rise * tone + snap


def can_hit(t: float) -> float:
    strike = rng.uniform(-1.0, 1.0) * exp(-60.0 * t) * 0.45
    hollow = exp(-8.0 * t) * (
        0.72 * sin(2 * pi * 188 * t)
        + 0.38 * sin(2 * pi * 317 * t)
        + 0.26 * sin(2 * pi * 563 * t)
        + 0.17 * sin(2 * pi * 901 * t)
    )
    rattle = rng.uniform(-1.0, 1.0) * exp(-12.0 * t) * 0.075 * (1.0 + sin(2 * pi * 37 * t))
    return strike + hollow + rattle


write("throwoff_title.wav", 1.35, title)
write("throwoff_tick.wav", 0.20, tick)
write("throwoff_go.wav", 0.52, go)
write("can_hit.wav", 0.48, can_hit)
