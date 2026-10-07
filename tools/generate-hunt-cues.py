#!/usr/bin/env python3
"""Original synthesized Fly Hunt cues; no third-party recordings.

Writes mono 48 kHz WAVs into sounds/. Each group shares one gain, so the files
in it keep their relative loudness:
  countdown-beep.wav     the 3 · 2 · 1 beeps before a round
  countdown-go.wav       the higher, longer GO
  clock-tick.wav         last-ten-seconds ticks from 10 down to 4
  clock-tick-final.wav   the urgent ticks for the last three seconds
  new-best-fanfare.wav   a rising arpeggio into a held chord for a new best
  golden-chime.wav       a quick sparkling bell run when a golden fly appears
  golden-kill.wav        a "cha-ching": a noise swipe, two bright bell hits and a coin jingle
  medal-thud.wav         a medal slamming onto the results card: low thump and a metal ring
  slowmo.wav             time's up: a low boom and a tone sliding down under a falling whoosh
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


def bell(freq, t, length, brightness=1.0):
    """Struck metal: inharmonic partials, the higher ones dying first."""
    if t < 0 or t > length:
        return 0.0
    partials = [(1.0, 1.0, 1.0), (2.0, .55, .7), (2.76, .45 * brightness, .5), (5.4, .3 * brightness, .3), (8.93, .18 * brightness, .18)]
    edge = min(1.0, t / 0.002) * min(1.0, (length - t) / 0.03)
    return edge * sum(level * math.sin(2 * math.pi * freq * ratio * t) * math.exp(-t / (length * decay * 0.45))
                      for ratio, level, decay in partials)


def golden_chime():
    steps = [(0.00, 84), (0.05, 88), (0.10, 91), (0.15, 96), (0.22, 100)]
    return render(0.85, lambda t: sum(bell(note(m), t - start, 0.6) for start, m in steps))


def golden_kill():
    rng = random.Random(11)
    jingles = [(0.22 + rng.random() * 0.45, 2600 + rng.random() * 2600) for _ in range(9)]
    state = {'last': 0.0}

    def sample(t):
        # The "cha": bright noise (differenced to tilt it high), gone in 60 ms.
        noise = rng.uniform(-1, 1)
        swipe = (noise - state['last']) * 0.35 * math.exp(-t / 0.02) if t < 0.07 else 0.0
        state['last'] = noise
        ching = bell(1580, t - 0.07, 0.75, 1.3) + 0.9 * bell(2370, t - 0.15, 0.7, 1.3)
        coins = sum(0.18 * bell(f, t - start, 0.18, 0.6) for start, f in jingles)
        return swipe + ching + coins
    return render(1.0, sample)


def medal_thud():
    rng = random.Random(21)

    def sample(t):
        # Pitch drops as the thump decays, like a heavy object landing.
        thump = math.sin(2 * math.pi * (75 * t - 12 * t * t)) * math.exp(-t / 0.09) * 1.4
        knock = rng.uniform(-1, 1) * math.exp(-t / 0.006) * 0.5
        ring = 0.45 * bell(880, t - 0.005, 0.9, 0.9) + 0.25 * bell(1320, t - 0.005, 0.7, 0.8)
        return thump + knock + ring
    return render(1.0, sample)


def slowmo():
    rng = random.Random(31)
    state = {'low': 0.0, 'phase': 0.0}
    length = 1.35

    def sample(t):
        # A low boom, then a tone gliding from 330 Hz down to 50 Hz.
        boom = math.sin(2 * math.pi * 48 * t) * math.exp(-t / 0.25) * 0.9
        freq = 50 + 280 * math.exp(-t / 0.35)
        state['phase'] += 2 * math.pi * freq / RATE
        p = state['phase']
        glide = (math.sin(p) + 0.3 * math.sin(2 * p) + 0.12 * math.sin(3 * p)) * 0.45 * math.exp(-t / 0.9)
        # Noise through a low-pass whose cutoff falls with the glide: the whoosh.
        cutoff = 0.02 + 0.25 * math.exp(-t / 0.3)
        state['low'] += cutoff * (rng.uniform(-1, 1) - state['low'])
        whoosh = state['low'] * 1.6 * min(1.0, t / 0.04) * math.exp(-t / 0.6)
        return (boom + glide + whoosh) * min(1.0, (length - t) / 0.15)
    return render(length, sample)


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
write({'golden-chime.wav': [v * .7 for v in golden_chime()], 'golden-kill.wav': golden_kill()})
write({'medal-thud.wav': medal_thud()})
write({'slowmo.wav': slowmo()})
with wave.open(str(SOUNDS / 'silence.wav'), 'wb') as output:
    output.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
    output.writeframes(b'\0\0' * (RATE // 2))
