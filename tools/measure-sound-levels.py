#!/usr/bin/env python3
"""How loud each sound plays in game: the file's loudness plus its RemoteSound volume.

Reads every `RemoteSound { source: ...; volume: ... }` in the plugin's QML and
prints, loudest first:
  peak 100 ms   the loudest 100 ms of the file (lightly K-weighted RMS, dB),
                which tracks how loud short shots and clicks feel
  momentary     ffmpeg's EBU R128 momentary maximum (400 ms window, LUFS),
                which also counts a sound's tail (a revolver's boom)
both shifted by the volume set in QML. Sounds with a computed volume (the
saber's mix at `saberVolume`, the rocket's boom size) are listed at file loudness.
Needs ffmpeg. Nothing is played.
"""
import math
from pathlib import Path
import re
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
RATE = 48000


def volumes():
    found = {}
    for qml in sorted(ROOT.glob('*.qml')):
        for block in re.findall(r'RemoteSound\s*\{([^{}]*)\}', qml.read_text(), re.S):
            source = re.search(r'sounds/([\w.-]+\.wav)', block)
            volume = re.search(r'volume:\s*([0-9.]+)\s*(?:$|;|\})', block, re.M)
            if source:
                # A 0 start volume means the level is mixed live (the saber's loops).
                level = float(volume.group(1)) if volume else 0
                found.setdefault(source.group(1), level or None)
    return found


def peak_100ms(path):
    raw = subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-i', str(path), '-af',
                          'highpass=f=60,treble=g=4:f=1500,aformat=channel_layouts=mono',
                          '-f', 'f32le', '-ar', str(RATE), '-'], capture_output=True, check=True).stdout
    samples = struct.unpack(f'{len(raw) // 4}f', raw)
    window = RATE // 10
    energy = best = sum(v * v for v in samples[:window])
    for i in range(window, len(samples)):
        energy += samples[i] * samples[i] - samples[i - window] * samples[i - window]
        best = max(best, energy)
    return 10 * math.log10(best / window + 1e-12)


def momentary(path):
    log = subprocess.run(['ffmpeg', '-hide_banner', '-nostats', '-i', str(path), '-af', 'apad=pad_dur=0.5,ebur128',
                          '-f', 'null', '-'], capture_output=True, text=True).stderr
    values = [float(v) for v in re.findall(r' M:\s*(-?[0-9.]+)', log)]
    return max(values) if values else float('-inf')


rows = []
for name, volume in volumes().items():
    path = ROOT / 'sounds' / name
    gain = 20 * math.log10(volume) if volume else 0.0
    rows.append((peak_100ms(path) + gain, momentary(path) + gain, name, volume))
rows.sort(key=lambda row: (row[3] is not None, row[0]), reverse=True)
print(f"{'sound':28}{'volume':>8}{'peak 100 ms':>13}{'momentary':>11}")
for peak, moment, name, volume in rows:
    shown = f'{volume:.2f}' if volume is not None else 'mixed'
    print(f'{name:28}{shown:>8}{peak:13.1f}{moment:11.1f}')
