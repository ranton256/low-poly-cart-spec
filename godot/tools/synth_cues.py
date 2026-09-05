#!/usr/bin/env python3
"""Render the game's cue set to WAVs — the committed generator (proposal decision 3).

    .venv/bin/python tools/synth_cues.py            # write assets/audio/
    .venv/bin/python tools/synth_cues.py --out DIR  # write somewhere else
    .venv/bin/python tools/synth_cues.py --check    # committed set == this tool's output

THE ASSETS ARE THE TOOL'S OUTPUT, and that is the whole point of shipping the
tool: a WAV nobody can regenerate is a binary blob with a story attached. The
seven supplied models are the owner's and are committed by hand (CONSTRAINTS §9
Assets says no tool generates one); the cue set is the port's own and is
generated here, the way the shipped circuit is baked by tools/author_first_light.gd.

DETERMINISTIC BY CONSTRUCTION. Nothing here reads a clock, an environment
variable, or an unseeded RNG. The one stochastic ingredient — the noise in the
impact — comes from an explicit linear congruential generator with a fixed seed,
written out longhand rather than taken from `random`, so the bytes cannot move
under a Python release that reshuffles its own generator. Two runs are byte
identical, and tests/audio_view_test.gd asserts exactly that by running this
tool into a scratch directory and comparing against the committed files.

STDLIB ONLY — `wave`, `struct`, `math`. The suite's .venv exists for gdtoolkit,
Pillow and numpy; adding a synthesis dependency for nine small files would put a
package in requirements.txt that only ever runs once.

THE FORMAT: mono, 22.05 kHz, 16-bit PCM. Mono because eight of the nine cues are
either non-spatial or positioned by the engine — a stereo source cannot be
panned in 3D and Godot downmixes it anyway. 22.05 kHz because these are short
chiptune-adjacent blips whose content is under 8 kHz, and the whole set is then
small enough to be invisible against the web payload budget (CONSTRAINTS §8
Performance and size budgets).

THE ENGINE LOOP IS RECORDED AT PITCH 1 and is loop-clean by construction: it is
a whole number of cycles of a waveform whose period divides the sample count
exactly, so the last sample runs into the first with no discontinuity that is not
already inside the loop. All pitch variation is the view's `pitch_scale` on the
speed ratio — recording a pitch sweep here would fight the curve the design
document specifies.
"""
import argparse
import math
import struct
import sys
import tempfile
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = ROOT / "assets" / "audio"

SAMPLE_RATE = 22050
CHANNELS = 1
SAMPLE_WIDTH = 2  # 16-bit PCM
FULL_SCALE = 32767

# The noise generator, longhand. Numerical Recipes' LCG constants; the seed is
# this project's and is fixed forever — changing it rerecords the impact.
NOISE_SEED = 20260904
LCG_MULTIPLIER = 1664525
LCG_INCREMENT = 1013904223
LCG_MODULUS = 1 << 32

# The engine loop's fundamental, expressed as a whole number of SAMPLES per
# cycle rather than as a frequency: that is what makes the loop seamless, and a
# frequency in Hz would only be a rounded name for it. 280 samples at 22050 Hz
# is 78.75 Hz — a low four-stroke idle, which the view then pitches from 0.8 to
# 1.5 across the speed ratio (63 Hz to 118 Hz).
ENGINE_PERIOD_SAMPLES = 280
ENGINE_CYCLES = 8

# Equal-tempered pitches, by name. Written out rather than computed from a
# reference so the file records the notes it plays.
C5, E5, G5 = 523.25, 659.25, 783.99
C6, E6, G6, C7 = 1046.50, 1318.51, 1567.98, 2093.00
A5, D6 = 880.00, 1174.66
BLIP, BLIP_OCTAVE_UP = 660.00, 1320.00


class Noise:
    """A seeded LCG in [-1, 1). Explicit so the bytes never move under Python."""

    def __init__(self, seed: int) -> None:
        self.state = seed

    def next(self) -> float:
        self.state = (self.state * LCG_MULTIPLIER + LCG_INCREMENT) % LCG_MODULUS
        return (self.state / float(LCG_MODULUS)) * 2.0 - 1.0


def seconds_to_samples(seconds: float) -> int:
    return int(round(seconds * SAMPLE_RATE))


def square(phase: float, duty: float = 0.5) -> float:
    """A square/pulse wave. `phase` is in cycles; only its fraction matters."""
    return 1.0 if (phase % 1.0) < duty else -1.0


def saw(phase: float) -> float:
    return (phase % 1.0) * 2.0 - 1.0


def sine(phase: float) -> float:
    return math.sin(phase * 2.0 * math.pi)


def envelope(index: int, total: int, attack_s: float, decay_tau_s: float) -> float:
    """Linear attack into an exponential decay, forced to zero on the last sample.

    The forced zero is not cosmetic: a one-shot that stops mid-swing clicks, and
    a click is exactly the kind of defect that survives every headless assertion
    and is obvious the moment anyone listens.
    """
    t = index / float(SAMPLE_RATE)
    attack = 1.0 if attack_s <= 0.0 else min(1.0, t / attack_s)
    decay = math.exp(-t / decay_tau_s)
    tail = 1.0 - (index / float(max(total - 1, 1))) ** 8
    return attack * decay * tail


def normalise(samples: list, peak: float) -> list:
    """Scale to an exact peak. Used where a sum of parts has no analytic bound.

    Deterministic — a pure function of the samples — and it is what keeps the
    impact off the clipper: noise plus a thump has no amplitude ceiling that can
    be reasoned about in advance, and two clipped samples in a 6615-sample burst
    are inaudible but are still a defect written into a committed asset.
    """
    loudest = max((abs(value) for value in samples), default=0.0)
    if loudest <= 0.0:
        return samples
    scale = peak / loudest
    return [value * scale for value in samples]


def glide(start_hz: float, end_hz: float, fraction: float) -> float:
    """Exponential pitch glide — the shape a falling pitch actually has."""
    return start_hz * ((end_hz / start_hz) ** fraction)


def write_wav(path: Path, samples: list) -> None:
    """Clamp, quantise, and write. The only place a float becomes a byte."""
    frames = bytearray()
    for value in samples:
        clamped = max(-1.0, min(1.0, value))
        frames += struct.pack("<h", int(round(clamped * FULL_SCALE)))
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as out:
        out.setnchannels(CHANNELS)
        out.setsampwidth(SAMPLE_WIDTH)
        out.setframerate(SAMPLE_RATE)
        out.writeframes(bytes(frames))


# --- the cues ----------------------------------------------------------------
#
# One function per cue id, named for it. The design document names the events;
# the sound design is this port's, and each function's docstring says what the
# ear is meant to get out of it.


def impact() -> list:
    """A filtered noise burst with a pitch drop — something solid, hit hard.

    Noise through a one-pole lowpass whose cutoff collapses, over a sine thump
    falling 180 Hz to 55 Hz. The two together read as a hit rather than as a
    hiss or a thud alone.
    """
    total = seconds_to_samples(0.30)
    noise = Noise(NOISE_SEED)
    lowpassed = 0.0
    out = []
    for i in range(total):
        fraction = i / float(total)
        cutoff_hz = glide(6000.0, 400.0, fraction)
        alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff_hz / SAMPLE_RATE)
        lowpassed += alpha * (noise.next() - lowpassed)
        thump_hz = glide(180.0, 55.0, fraction)
        thump = sine(thump_hz * i / float(SAMPLE_RATE))
        out.append((lowpassed * 0.78 + thump * 0.42) * envelope(i, total, 0.002, 0.070))
    return normalise(out, 0.92)


def rebound() -> list:
    """A softer, rounder boing — the fence, and audibly NOT the impact.

    The design document makes telling these two apart normative. This one is
    pure tone with a vibrato and a slow attack: no noise anywhere in it, which
    is the single largest difference the ear can be handed.
    """
    total = seconds_to_samples(0.36)
    out = []
    phase = 0.0
    for i in range(total):
        fraction = i / float(total)
        base_hz = glide(340.0, 150.0, fraction)
        vibrato = 1.0 + 0.05 * sine(6.0 * i / float(SAMPLE_RATE))
        phase += base_hz * vibrato / float(SAMPLE_RATE)
        body = sine(phase) + 0.22 * sine(phase * 2.0)
        out.append(body * 0.55 * envelope(i, total, 0.012, 0.120))
    return out


def countdown_tick() -> list:
    """A clean square blip. Three of these, one per countdown step."""
    return _blip(BLIP, 0.10, 0.030, 0.50)


def countdown_go() -> list:
    """The same blip an octave up and longer — GO! is the same voice, raised."""
    return _blip(BLIP_OCTAVE_UP, 0.26, 0.090, 0.55)


def _blip(freq_hz: float, length_s: float, decay_tau_s: float, amplitude: float) -> list:
    total = seconds_to_samples(length_s)
    out = []
    for i in range(total):
        wave_value = square(freq_hz * i / float(SAMPLE_RATE))
        out.append(wave_value * amplitude * envelope(i, total, 0.002, decay_tau_s))
    return out


def gate_passed() -> list:
    """A quick two-note rise — progress, and out of the way fast."""
    return _melody([A5, D6], 0.075, 0.45, duty=0.5)


def lap_banked() -> list:
    """A three-note fanfare. The lap is the thing the game is about."""
    return _melody([C5, E5, G5], 0.115, 0.50, duty=0.5)


def new_best() -> list:
    """Brighter and longer than the bank it rides on — four notes, thinner pulse.

    It plays with `lap_banked`, never instead of it, so it has to sit ON that
    fanfare and still be recognisable: an octave up and a narrower duty cycle
    put it in a different part of the spectrum rather than merely louder.
    """
    return _melody([C6, E6, G6, C7], 0.135, 0.42, duty=0.25)


def _melody(notes: list, note_s: float, amplitude: float, duty: float) -> list:
    out = []
    for freq_hz in notes:
        total = seconds_to_samples(note_s)
        for i in range(total):
            value = square(freq_hz * i / float(SAMPLE_RATE), duty)
            out.append(value * amplitude * envelope(i, total, 0.003, note_s * 0.55))
    return out


def medal() -> list:
    """A chord — four notes at once, held. A verdict, not an event."""
    total = seconds_to_samples(0.60)
    notes = [C5, E5, G5, C6]
    out = []
    for i in range(total):
        t = i / float(SAMPLE_RATE)
        stack = sum(square(freq_hz * t, 0.5) for freq_hz in notes) / float(len(notes))
        out.append(stack * 0.55 * envelope(i, total, 0.015, 0.250))
    return out


def engine_loop() -> list:
    """A low saw/pulse blend, a whole number of cycles long, at pitch 1.

    Constant amplitude and no envelope: an envelope would make the loop point
    audible, and the volume curve belongs to the view. The second harmonic is
    also periodic over the same window, so the whole file is one period repeated
    and the seam is a seam the ear already hears seven times inside the file.
    """
    total = ENGINE_PERIOD_SAMPLES * ENGINE_CYCLES
    out = []
    for i in range(total):
        phase = i / float(ENGINE_PERIOD_SAMPLES)
        body = 0.58 * saw(phase) + 0.42 * square(phase, 0.30)
        harmonic = 0.24 * saw(phase * 2.0)
        out.append((body + harmonic) * 0.42)
    return out


# The shipped set, id -> generator. The eight one-shots are the cue ids
# scripts/core/audio_cues.gd declares, spelled identically on purpose: the view
# resolves a stream by cue id and a rename here would be a silent miss.
CUES = {
    "impact": impact,
    "rebound": rebound,
    "countdown_tick": countdown_tick,
    "countdown_go": countdown_go,
    "gate_passed": gate_passed,
    "lap_banked": lap_banked,
    "new_best": new_best,
    "medal": medal,
    "engine_loop": engine_loop,
}


def render(out_dir: Path) -> list:
    written = []
    for name in sorted(CUES):
        path = out_dir / f"{name}.wav"
        write_wav(path, CUES[name]())
        written.append(path)
    return written


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default=str(DEFAULT_OUT),
                        help="directory to write the WAVs into")
    parser.add_argument("--check", action="store_true",
                        help="render to a temporary directory and compare against --out")
    args = parser.parse_args()

    target = Path(args.out)
    if not args.check:
        written = render(target)
        total = sum(p.stat().st_size for p in written)
        print(f"synth_cues: {len(written)} cues written to {target} "
              f"({total / 1024.0:.1f} KiB, {SAMPLE_RATE} Hz mono 16-bit)")
        return 0

    with tempfile.TemporaryDirectory() as scratch:
        fresh = render(Path(scratch))
        drifted, absent = [], []
        for path in fresh:
            committed = target / path.name
            if not committed.exists():
                absent.append(path.name)
            elif committed.read_bytes() != path.read_bytes():
                drifted.append(path.name)
        stale = sorted(p.name for p in target.glob("*.wav")
                       if p.name not in {f.name for f in fresh})
    problems = []
    if absent:
        problems.append(f"absent from {target}: {', '.join(absent)}")
    if drifted:
        problems.append(f"differ from this tool's output: {', '.join(drifted)}")
    if stale:
        problems.append(f"not produced by this tool: {', '.join(stale)}")
    if problems:
        for problem in problems:
            print(f"synth_cues: {problem}", file=sys.stderr)
        print("synth_cues: the committed set is not this tool's output — "
              "re-run without --check, or explain the difference", file=sys.stderr)
        return 1
    print(f"synth_cues: the {len(fresh)} committed cues are byte-identical to a "
          f"fresh render")
    return 0


if __name__ == "__main__":
    sys.exit(main())
