#!/usr/bin/env python3
"""Original synthesized lightsaber effects; no third-party recordings.

The hum is two projector-motor-like tones (94 Hz and 76.5 Hz) whose harmonics
roll off steeply, lightly saturated so they intermodulate. Ignition and
retraction are bright noise sweeps, swings are bass-heavy swells with a small
Doppler dip, and the clash is a sustained electrical fizz.

Writes mono 48 kHz WAVs into sounds/, all at one shared gain so they can be
played at the same volume and keep their relative loudness:
  saber-ignite.wav      bright snap-hiss settling into the hum
  saber-hum.wav         idle hum loop
  saber-swing-low.wav   bass-heavy, phasing swell loop
  saber-swing-high.wav  bright buzzing overtone loop for fast swings
  saber-retract.wav     rising hiss with a falling hum, cut off at the end
  saber-clash.wav       crackling clash fizz with a hum surge
  saber-clash-2.wav     shorter, brighter clash variant
  saber-sizzle.wav      crackling burn loop while the blade cuts into a window
  saber-cut.wav         bright hiss as the blade severs a piece of a window

The three loops are two seconds long and seamless; the game keeps them running
while the blade is lit and sets their volumes every frame from blade speed,
the way smooth-swing saber sound boards do.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 48000
SOUNDS = Path(__file__).resolve().parents[1] / 'sounds'
# Both motors complete whole cycles in two seconds, so the loop is phase-exact.
MOTOR_A = 94.0
MOTOR_B = 76.5
HARMONICS_A = [10 ** (db / 20) for db in (0, -8, -13, -16.5, -17, -19, -24, -27, -29, -30)]
HARMONICS_B = [10 ** (db / 20) for db in (-10.7, -30, -26, -30)]


class Lowpass:
    def __init__(self, cutoff):
        self.value = 0.0
        self.set(cutoff)

    def set(self, cutoff):
        self.alpha = 1 - math.exp(-2 * math.pi * cutoff / RATE)

    def __call__(self, sample):
        self.value += self.alpha * (sample - self.value)
        return self.value


class Rolloff:
    """Two cascaded one-pole lowpasses: tames the airy top end above the hiss."""

    def __init__(self, cutoff):
        self.stages = (Lowpass(cutoff), Lowpass(cutoff))

    def __call__(self, sample, cutoff=None):
        for stage in self.stages:
            if cutoff:
                stage.set(cutoff)
            sample = stage(sample)
        return sample


class Highpass:
    def __init__(self, cutoff):
        self.low = Lowpass(cutoff)

    def __call__(self, sample):
        return sample - self.low(sample)


class Bandpass:
    """Chamberlin state-variable filter; the centre can move per sample."""

    def __init__(self, q):
        self.damping = 1 / q
        self.low = 0.0
        self.band = 0.0

    def __call__(self, sample, centre):
        f = 2 * math.sin(math.pi * min(centre, RATE / 6) / RATE)
        self.low += f * self.band
        high = sample - self.low - self.damping * self.band
        self.band += f * high
        return self.band


class Hum:
    """The idle blade: two saturated harmonic motors and a faint hum-synced fizz."""

    def __init__(self, seed, motors=(MOTOR_A, MOTOR_B)):
        self.rng = random.Random(seed)
        self.motors = motors
        self.phase_a = 0.0
        self.phase_b = 0.0
        self.time = 0.0
        self.fizz_band = Bandpass(.8)
        self.flutter = Lowpass(5)

    def __call__(self, pitch=1.0, fizz=1.0):
        self.time += 1 / RATE
        self.phase_a += 2 * math.pi * self.motors[0] * pitch / RATE
        self.phase_b += 2 * math.pi * self.motors[1] * pitch / RATE
        a = sum(w * math.sin(n * self.phase_a) for n, w in enumerate(HARMONICS_A, 1))
        b = sum(w * math.sin(n * self.phase_b + .4 * n) for n, w in enumerate(HARMONICS_B, 1))
        motors = math.tanh(1.3 * (a + b) * .55) / .55
        noise = self.rng.uniform(-1, 1)
        texture = self.fizz_band(noise, 2400) * (.6 + .4 * a) * .05 * fizz
        # Slow swells (whole cycles per two-second loop) plus random flutter keep it alive.
        wobble = (1 + .07 * math.sin(math.pi * self.time) + .04 * math.sin(3 * math.pi * self.time + 1)
                  + 6 * self.flutter(noise))
        return (motors + texture) * wobble


class Crackle:
    """Random gate that gives hiss its electric, grainy texture."""

    def __init__(self, seed, hold):
        self.rng = random.Random(seed)
        self.hold = hold
        self.left = 0
        self.level = 1.0

    def __call__(self, depth):
        if self.left <= 0:
            self.left = int(RATE * self.hold * self.rng.uniform(.3, 1.7))
            self.level = self.rng.random()
        self.left -= 1
        return 1 - depth + depth * self.level


def smooth(edge0, edge1, x):
    x = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return x * x * (3 - 2 * x)


IDLE = .2  # hum amplitude every effect is mixed against


def ignite():
    rng = random.Random(11)
    hum = Hum(12)
    grain = Crackle(13, .0015)
    hiss_band = Bandpass(.7)
    hiss_high = Highpass(1500)
    hiss_top = Rolloff(9000)
    length = 1.1
    out = []
    for i in range(int(RATE * length)):
        t = i / RATE
        onset = smooth(0, .004, t)
        # Brightest just after the snap, then the fizz darkens as the blade settles.
        centre = 4500 + 3500 * smooth(0, .09, t) if t < .09 else 2500 + 5500 * math.exp(-(t - .09) / .4)
        hiss = hiss_top(hiss_high(hiss_band(rng.uniform(-1, 1), centre)) * grain(.55), centre * 1.7)
        # The filter passes less noise as its centre falls; keep the hiss level steady.
        hiss *= 1.7 * (6000 / centre) * math.exp(-t / 1.4) * (1 - smooth(.75, length, t))
        pitch = 1 - .07 * math.exp(-t / .3)
        body = hum(pitch) * IDLE * (1.3 - .3 * smooth(.1, .5, t)) * (1 - smooth(.55, 1.05, t))
        out.append(onset * (hiss + body))
    return out


def loop(sample):
    """Two seconds of sample(); tones repeat exactly, so the seam only blends noise."""
    period, overlap = RATE * 2, int(RATE * .25)
    raw = [sample(i / RATE) for i in range(period + overlap)]
    for i in range(overlap):
        w = i / overlap
        raw[i] = raw[i] * w + raw[period + i] * (1 - w)
    return raw[:period]


def hum_loop():
    hum = Hum(21)
    return loop(lambda t: hum() * IDLE)


def swing_low_loop():
    # Slightly lower motors (still whole cycles per loop) beat against the idle hum.
    hum = Hum(71, motors=(89.0, 72.5))
    weight = Lowpass(260)
    delay = [0.0] * 512
    out = []

    def sample(t):
        x = hum()
        body = weight(x) * 1.6 + x * .4
        # A sweeping comb filter: the phasing of a blade passing the microphone.
        delay.append(body)
        del delay[0]
        lag = RATE * (.0012 + .0025 * (.5 + .5 * math.sin(math.pi * t)))
        whole = int(lag)
        echo = delay[-1 - whole] + (delay[-2 - whole] - delay[-1 - whole]) * (lag - whole)
        return (body + .55 * echo) * IDLE * 2.2
    return loop(sample)


def swing_high_loop():
    rng = random.Random(81)
    phases = [rng.uniform(0, 2 * math.pi) for _ in range(60)]
    air = Bandpass(1.2)
    air_top = Rolloff(7000)
    # Harmonics of the main motor centred near 2.8 kHz: the bright buzz of a fast swing.
    weights = {n: math.exp(-(math.log(n * MOTOR_A / 2800) / .45) ** 2) for n in range(10, 60)}

    def sample(t):
        buzz = sum(w * math.sin(2 * math.pi * n * MOTOR_A * t + phases[n]) for n, w in weights.items())
        buzz = math.tanh(.5 * buzz) * (1 + .3 * math.sin(math.pi * t) * math.sin(4 * math.pi * t))
        whoosh = air_top(air(rng.uniform(-1, 1), 3000)) * .5
        return (buzz * .35 + whoosh) * IDLE * 5
    return loop(sample)


def retract():
    rng = random.Random(31)
    hum = Hum(32)
    grain = Crackle(33, .0015)
    hiss_band = Bandpass(.8)
    hiss_high = Highpass(1200)
    hiss_top = Rolloff(8000)
    length = .6
    out = []
    for i in range(int(RATE * length)):
        t = i / RATE
        p = t / length
        centre = 1500 + 3500 * p ** 1.3
        hiss = hiss_top(hiss_high(hiss_band(rng.uniform(-1, 1), centre)) * grain(.5), centre * 1.7)
        hiss *= 3 * p ** 1.4
        body = hum(1 - .12 * p ** 1.5) * IDLE * (1 - .4 * p)
        out.append((hiss + body) * (1 - smooth(length - .025, length, t)))
    return out


def clash(seed, length, hold, centre):
    rng = random.Random(seed)
    hum = Hum(seed + 1)
    grain = Crackle(seed + 2, .001)
    fizz_band = Bandpass(.5)
    fizz_high = Highpass(900)
    fizz_top = Rolloff(9500)
    chirp_phase = [0.0, 0.0]
    out = []
    for i in range(int(RATE * length)):
        t = i / RATE
        onset = smooth(0, .002, t)
        level = 1 if t < hold else math.exp(-(t - hold) / (length * .3))
        fizz = fizz_high(fizz_band(rng.uniform(-1, 1), centre - 800 * smooth(0, .5, t)))
        fizz = fizz_top(fizz * grain(.7)) * 5.5 * level
        # Faint falling whistles, like the arcing lines in a real clash.
        chirps = 0.0
        for n, (start, end) in enumerate(((2900, 1700), (4300, 2900))):
            chirp_phase[n] += 2 * math.pi * (start + (end - start) * smooth(0, .6, t)) / RATE
            chirps += math.sin(chirp_phase[n] + 2 * math.sin(chirp_phase[n] * .013)) * .09 * level
        surge = math.tanh(2.2 * hum(.93 + .07 * smooth(0, .4, t), fizz=3)) * IDLE * 3 * math.exp(-t / .35)
        out.append(onset * (fizz + chirps + surge) * (1 - smooth(length - .05, length, t)))
    return out


def sizzle_loop():
    """The blade burning into a captured window: gated fizz over a strained hum."""
    rng = random.Random(51)
    grain = Crackle(52, .0012)
    band = Bandpass(.9)
    high = Highpass(1800)
    top = Rolloff(9000)
    hum = Hum(53)

    def sample(t):
        # Six whole wobble cycles per two-second loop keep the seam exact.
        centre = 3600 + 900 * math.sin(6 * math.pi * t)
        fizz = top(high(band(rng.uniform(-1, 1), centre)) * grain(.8), centre * 1.8) * 4
        buzz = math.tanh(2 * hum(fizz=4)) * IDLE * .8
        return fizz + buzz
    return loop(sample)


def cut():
    """A quick falling hiss with a hum surge: a piece of window sliced off."""
    rng = random.Random(61)
    grain = Crackle(62, .001)
    band = Bandpass(.7)
    high = Highpass(1500)
    top = Rolloff(9500)
    hum = Hum(63)
    length = .55
    out = []
    for i in range(int(RATE * length)):
        t = i / RATE
        envelope = smooth(0, .015, t) * math.exp(-t / .16)
        centre = 5200 - 2600 * smooth(0, .4, t)
        hiss = top(high(band(rng.uniform(-1, 1), centre)) * grain(.6), centre * 1.7) * 6 * envelope
        surge = math.tanh(2 * hum(1.05 - .12 * smooth(0, .4, t), fizz=3)) * IDLE * 2.2 * math.exp(-t / .2)
        out.append((hiss + surge) * (1 - smooth(length - .05, length, t)))
    return out


def write(effects):
    scale = .89 * 32767 / max(abs(s) for samples in effects.values() for s in samples)
    for name, samples in effects.items():
        frames = struct.pack('<' + 'h' * len(samples), *(int(s * scale) for s in samples))
        with wave.open(str(SOUNDS / name), 'wb') as output:
            output.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
            output.writeframes(frames)


write({
    'saber-ignite.wav': ignite(),
    'saber-hum.wav': hum_loop(),
    'saber-swing-low.wav': swing_low_loop(),
    'saber-swing-high.wav': swing_high_loop(),
    'saber-retract.wav': retract(),
    'saber-clash.wav': clash(41, .9, .35, 3400),
    'saber-clash-2.wav': clash(91, .65, .18, 4200),
    'saber-sizzle.wav': sizzle_loop(),
    'saber-cut.wav': cut(),
})
