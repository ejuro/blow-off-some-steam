#!/usr/bin/env python3
"""Original synthesized Fly Hunt cues; no third-party recordings.

Writes mono 48 kHz WAVs into sounds/. Each group shares one gain, so the files
in it keep their relative loudness:
  countdown-beep.wav     the 3 · 2 · 1 beeps before a round
  countdown-go.wav       the higher, longer GO
  clock-tick.wav         last-ten-seconds ticks from 10 down to 4
  clock-tick-final.wav   the urgent ticks for the last three seconds
  new-best-fanfare.wav   a rising arpeggio into a held chord for a new best
  silence.wav            half a second of digital silence; the audio worker loops
                         it to keep the output device awake while it runs

Tones are a few soft square-ish harmonics; ticks are a noise click into two
damped resonances, like a wooden clock.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 48000
SOUNDS = Path(__file__).resolve().parents[1] / 'sounds'


def note(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def voice(freq, t, length):
    """A bright but rounded tone: odd harmonics rolled off, short attack, exponential decay."""
    if t < 0 or t > length:
        return 0.0
    attack = min(1.0, t / 0.008)
    release = min(1.0, (length - t) / 0.06)
    decay = math.exp(-t / (0.9 * length))
    vibrato = 1 + 0.004 * math.sin(2 * math.pi * 5.5 * t) * min(1.0, t / 0.3)
    phase = 2 * math.pi * freq * vibrato * t
    tone = sum(math.sin(n * phase) / n ** 1.6 for n in (1, 3, 5, 7)) + 0.35 * math.sin(2 * phase)
    return tone * attack * release * decay


def render(length, sample):
    return [sample(i / RATE) for i in range(int(RATE * length))]


def beep(midi, length, octave_below=0.0):
    return render(length + 0.01, lambda t: voice(note(midi), t, length)
                  + octave_below * voice(note(midi - 12), t, length))


def tick(seed, partials, length, click):
    rng = random.Random(seed)

    def sample(t):
        noise = rng.uniform(-1, 1) * click * math.exp(-t / 0.0015)
        body = sum(level * math.sin(2 * math.pi * freq * t) * math.exp(-t / decay)
                   for freq, level, decay in partials)
        return (noise + body) * min(1.0, t / 0.0004) * min(1.0, (length - t) / 0.005)
    return render(length, sample)


def fanfare():
    # (start, midi, length): the arpeggio steps, then the chord lands on the last one.
    steps = [(0.00, 67, 0.16), (0.09, 72, 0.16), (0.18, 76, 0.16), (0.27, 79, 0.18)]
    chord_start, chord_length = 0.36, 1.05
    chord = [72, 76, 79, 84]

    def sample(t):
        value = sum(voice(note(m), t - start, dur) for start, m, dur in steps)
        # Slightly detuned pairs give the held chord its shimmer.
        for m in chord:
            for detune in (-0.0025, 0.0025):
                value += 0.42 * voice(note(m) * (1 + detune), t - chord_start, chord_length)
        return value
    return render(chord_start + chord_length + 0.05, sample)


def write(effects):
    scale = .89 * 32767 / max(abs(s) for samples in effects.values() for s in samples)
    for name, samples in effects.items():
        with wave.open(str(SOUNDS / name), 'wb') as output:
            output.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
            output.writeframes(struct.pack('<' + 'h' * len(samples), *(int(s * scale) for s in samples)))


write({
    # Race-start style: three short E5 beeps, then GO an octave up and held.
    'countdown-beep.wav': [s * .75 for s in beep(76, .18)],
    'countdown-go.wav': beep(88, .5, octave_below=.6),
})
write({
    # The regular tick sits a little below the final one so the last three stand out.
    'clock-tick.wav': [s * .7 for s in tick(5, [(1900, 1, .018), (3150, .45, .010), (720, .3, .025)], .09, .6)],
    'clock-tick-final.wav': tick(6, [(2600, 1, .024), (4100, .5, .012), (1300, .35, .03)], .12, .8),
})
write({'new-best-fanfare.wav': fanfare()})
with wave.open(str(SOUNDS / 'silence.wav'), 'wb') as output:
    output.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
    output.writeframes(b'\0\0' * (RATE // 2))
