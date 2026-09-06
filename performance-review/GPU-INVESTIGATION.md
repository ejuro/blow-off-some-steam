# GPU investigation — 2026-09-06

User reported 30–40% GPU utilization during autofire, roughly 50% with rockets,
and occasional 90% after releasing fire. The tests reproduced the lower ranges,
but **did not reproduce 90% or establish its cause**. Production files were not
changed during this investigation.

## Method and limitations

Fresh, muted, click-through Quickshell test processes on the existing desktop,
using the current repository sources and default process backend. Stationary aim,
MP5 shots every 66 ms or thick launcher shots every 550 ms; 3 seconds initial
idle/setup, 8 seconds firing, 6 seconds release, then 4 seconds holstered.
Destruction mode was off. This does not reproduce every live-shell interaction,
fast aiming, sound playback, or desktop destruction.

NVIDIA-SMI sampled whole-device utilization, graphics clock, memory utilization,
and power every 100 ms. These are not per-plugin GPU timings, and polling faster
does not increase the driver's underlying utilization sample resolution. Other
desktop processes and the measurement UI remained present. QML state and GPU
samples were paired by the latest available entries, approximately rather than
with precise GPU timestamp synchronization. Phase boundaries therefore include
sampling lag. Means below summarize collected samples, not isolated GPU cost.

## Results

| Run | Firing GPU mean / max | Release GPU mean / max |
| --- | --- | --- |
| Autofire | 25.7% / 36% | 26.7% / 38% |
| Rockets, first run | 27.4% / 42% | 24.6% / 38% |
| Rockets, instrumented repeat | 30.1% / 47% | 26.1% / 44% |
| Rockets, effect drawing disabled, repeat | 22.4% / 42% | 28.4% / 45% |
| Rockets, stable-slot prototype | 27.4% / 42% | 27.7% / 43% |

In the autofire run the clock fell from about 1,800 MHz early in firing to
300 MHz around release. The highest utilization was 38% at 270 MHz, with only
four bullets remaining. Thus higher percentage did not coincide with more
particles. This supports considering clock changes when interpreting utilization;
it does not explain or dismiss the user's unobserved 90% peak.

The animation stopped roughly 2.4 seconds after releasing autofire and 1.8–1.9
seconds after rockets. Instrumented paint-area and size-change counters stopped
increasing once settled. Whole-GPU utilization remained nonzero even holstered
with no animation or particle paints, so it cannot all be attributed to this
renderer. The benchmark's `maxFrameGap` includes intentional animation sleep and
wake gaps and **must not be interpreted as stutter or frame latency**.

## Confirmed rendering costs

The instrumented rocket run requested about 51.5 million logical particle-canvas
pixels of painting per second during firing. This is a sum of requested surface
areas, not measured GPU transfer bytes. A thick rocket ring has a 928 × 928
logical-pixel surface; two simultaneous rings account for 1.72 million logical
pixels per update, including their transparent interiors. Qt documents that
updating Canvas.Image entails texture uploading with accelerated graphics APIs.

The current index-based particle pool also changed canvas dimensions roughly
1,099 times per second during firing. As particles expire, survivors move into
slots previously used by different particles, causing avoidable size changes.
The counter measures property size changes, not driver allocation calls.

An isolated prototype retained each particle's slot and reused free slots by
kind, preserving the drawing function and index-based stacking/color inputs.
Size changes fell to 427/sec (about 61% lower), but process CPU was 39.9% versus
39.3%, and repaint area remained 50.8 versus 51.5 megapixels/sec. These single
runs do not demonstrate a performance improvement. The prototype was not
installed or visually validated; shrinking spark canvases still change size.

## Next steps

Prioritize reducing repeated raster work and uploads for shockwaves and other
particles. Stable allocation alone is insufficient based on this experiment.
Any cached-raster or GPU-rendered replacement needs the existing visual comparison
suite: a previous ring experiment changed antialiasing and was rejected.

To diagnose the exact 90% event, capture the live workload with its destruction
setting, clock/power readings and timing relative to the last visible effect.
Do not infer a rendering leak, GPU saturation, or a need to lower visual quality
from this percentage alone.

Raw samples: `gpu-investigation-measurements.json`. Repeat the isolated tests
with `python performance-review/gpu-investigation.py`. Optional scenarios include
`rockets_stable`; `--output` selects the JSON destination. This script opens
visible test overlays and requires the NVIDIA tools and desktop access.

References: [Qt Canvas](https://doc.qt.io/qt-6/qml-qtquick-canvas.html),
[NVIDIA-SMI utilization and clocks](https://docs.nvidia.com/deploy/nvidia-smi/index.html).
