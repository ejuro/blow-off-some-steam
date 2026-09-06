# Runtime performance review — 2026-09-06

Tested Arena.qml at cb8747d in isolated Quickshell processes on the user's actual Wayland display. Production QML, configuration, and the running shell were not modified. These measurements independently reproduce the main Canvas bottleneck described in the Downloads postmortem.

## Method and limits

- Display: 3840×2160 at 120 Hz, scale 1.25 (3072×1728 logical area); NVIDIA RTX 3080. The kernel reported a CPU maximum frequency of 3401000 kHz. This review did not diagnose firmware or measure CPU boost under load.
- Each scenario ran in a fresh process, with 2.3 seconds of startup/warmup and a six-second measurement window, repeated twice. CPU is process CPU time from `/proc/PID/stat` divided by elapsed wall time: 100% means one fully occupied core. It excludes the compositor and other processes.
- Copies of the real arena use its shooting, simulation, collision, and painting code. The harness substitutes a constant theme accent, mutes SoundEffects, removes keyboard capture, makes the surface click-through, disables real pointer input, and supplies scripted aiming/shooting. It counts effects/terrain paints, simulation ticks, maximum particle counts, and timer intervals.
- Destruction uses a synthetic PPM image and twelve synthetic window regions. It exercises terrain painting and real collision logic, but does not benchmark screenshot capture, real window geometry acquisition, or drawer opening. Audio playback cost is excluded. No personal desktop screenshot was captured.
- Timer interval statistics measure simulation scheduling, **not presentation frame times or input-to-display latency**. Counts of Canvas paints do not prove GPU uploads finished at that rate.
- Pointer motion is repeatable. Particles retain production randomness; counts and collisions therefore vary between passes. Runs were sequential on an active desktop, not a controlled idle lab machine.
- Disabling paint or reducing Canvas dimensions deliberately changes diagnostic output. These variants are cost-isolation experiments, not proposed production changes or visual-equivalence tests.

## Measurements

| Scenario | CPU %, pass 1 / 2 | Simulation interval p95, ms | Maximum interval, ms |
|---|---:|---:|---:|
| Holstered | 0.0 / 0.0 | — | — |
| Armed, stationary | 1.0 / 3.4 | 17 / 17 | 17 / 17 |
| Aiming | 62.4 / 60.4 | 18 / 17 | 21 / 18 |
| Aiming, effects requests disabled | 2.4 / 3.8 | 17 / 17 | 17 / 20 |
| Aiming, 300×300 dirty invalidation, original clear | 64.8 / 60.9 | 18 / 18 | 20 / 20 |
| Aiming, 300×300 dirty invalidation and partial clear | 56.5 / 55.3 | 18 / 18 | 22 / 21 |
| Aiming, effects Canvas reduced to 400×300 | 5.2 / 5.2 | 17 / 17 | 17 / 18 |
| MP5 automatic fire while aiming | 66.1 / 62.9 | 18 / 17 | 23 / 19 |
| Same firing, effects requests disabled | 3.0 / 4.5 | 17 / 17 | 17 / 18 |
| Thick M20 repeatedly firing | 77.3 / 77.8 | 19 / 18 | 21 / 21 |
| Destruction + MP5 + aiming | 96.5 / 93.0 | 31 / 26 | 87 / 82 |
| Destruction, effects requests disabled | 14.7 / 14.2 | 17 / 17 | 21 / 20 |
| Destruction, terrain damage invalidation disabled | 69.2 / 67.8 | 19 / 19 | 21 / 22 |

The last variant retains initial terrain painting and damage/collision bookkeeping, but suppresses subsequent `markDirty` calls. The effects-disabled variants retain the gun Image, simulation, and initial automatic Canvas paint.

Ordinary aiming/firing produced 375 simulation ticks per six seconds. Destruction fell to 332 / 355 ticks, with 313 / 341 effects paint callbacks and 77 / 72 terrain paint callbacks. Neither destruction pass destroyed a complete window. Consequently, the measured 82–87 ms stalls occurred without falling-piece creation or cleanup.

MP5 reached 92 live particles in both ordinary passes; rockets reached 236. Removing effects repaints while retaining MP5 simulation reduced CPU to 3.0–4.5%. Particle simulation and array allocation are therefore secondary under these tested loads.

## Conclusions and implementation priorities

1. **Remove fullscreen effects rasterization from aiming and firing.** This is the largest independently isolated cost. Keep existing visuals through reusable small graphics / scene-graph transforms, with careful preservation of shape, alpha, draw order, and motion. The small-Canvas result supports reducing backing surface area, but is not a benchmark of a complete replacement renderer.
2. **Treat simultaneous terrain and effects updates as a demonstrated stall trigger.** Suppressing either removes the long timer gaps in these samples. This implicates rendering work and scheduling interaction, rather than collision logic alone. These tests do not identify an exact internal Qt lock or upload operation; tracing would be needed for that attribution.
3. **Do not assume `markDirty` alone solves texture cost.** The partial-clear test still costs 55–57% of a core. It is a bounded-area diagnostic, not a production dirty-region implementation: it does not maintain old/new bounds or guarantee artifact-free clearing. It shows that this simple approach retains most of the observed cost on this backend.
4. **Address timing after reducing rendering cost.** Fixed per-tick motion/lifetime updates make missed simulation ticks change real-time behavior. Preserve existing physics with elapsed-time-aware scheduling and appropriate interpolation; don't simply double tick frequency on a 120 Hz screen.
5. **Idle gating and allocation improvements come later.** Armed-idle has no effects paint callbacks in the sample, while the timer still runs. Its measured cost is much smaller than active Canvas rendering.

## Reproducibility and exclusions

`measurements.json` contains the accepted raw summaries. `benchmark.py` creates copies and logs under `/tmp/steam-perf-review`; it contains machine-specific source and temporary paths. Run only when GUI overlays are acceptable. Default scenarios run twice; `--scenarios` and `--output` select follow-ups. For example:

```sh
python performance-review/benchmark.py --scenarios aim_dirty_clear,destruction_no_effects,destruction_no_terrain --output followup.json
```

The partial-clear harness emitted Qt's deprecated implicit signal-parameter warning for `region`; the handler executed and produced paint counts. All scenarios also emitted a desktop portal app-ID registration warning. Neither was a QML load failure.

An exploratory forced-fall stress test was **discarded**: its harness could destroy an already-destroyed region, so its results did not represent production behavior. The archived harness includes a guard fixing that test setup, but that corrected scenario has not been rerun. No conclusion about falling-piece performance is claimed here.

All test processes exited after holstering. No production performance patch was applied. A future implementation still needs visual comparison and end-to-end tests of the drawer, actual capture flow, audio, and presented frame timing.
