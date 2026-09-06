# Final rapid-click stress test

## Cooldown follow-up

The final candidate now enforces each launcher's configured interval at the
start of `shoot`: 550 ms for the thick launcher and 500 ms for the regular one.
Clicks during cooldown are discarded before sound, recoil, flash, or particles
are generated. A shared one-shot timer prevents bypassing the cooldown by
swapping launchers or briefly holstering. Other weapons remain unaffected.
Existing rocket/explosion visuals and physics are unchanged; firing cadence is
an intentional gameplay change. Missed clicks are not queued.

Repeated the same 4K, 12-second stress workload after this change:

| Scenario | Attempts / accepted shots | Peak particles / rings | Animation interval median / p95 / max | CPU, one core = 100% |
| --- | --- | --- | --- | --- |
| Default rockets | 119 / 20 | 203 / 1 | 16 / 17 / 17 ms | 45.6% |
| Default destruction | 119 / 20 | 234 / 1 | 16 / 17 / 41 ms | 43.2% |
| Isolated Vulkan rockets | 119 / 20 | 204 / 1 | 8 / 9 / 15 ms | 85.5% |

The destruction maximum was its first recorded interval during initialization;
only that interval exceeded 33 ms. All runs cleared particles, stopped animation,
and holstered without QML errors. Whole-GPU peaks were 42%, 43%, and 57%,
respectively; these remain whole-device readings at variable clocks.

Accepted thick-launcher shots were at least 574 ms apart across the runs.
With clicks offered every 100 ms, most accepted gaps were approximately 600 ms.
The targeted cooldown regression also checks side-effect-free rejection, shared
launcher cooldown, unchanged other-weapon access, and configured intervals.
The existing 600-step physics regression passes. Audio was muted in GUI tests.
These are animation callback timings, not measured presentation latency or a
guarantee for untested laptops. The live backend was not changed.

Current harness results: `rocket-cooldown-measurements.json`. Run
`node performance-review/rocket-cooldown-regression.js` and
`python performance-review/rocket-stress.py` to repeat the checks.

## Before cooldown (historical)

Tested the current production candidate on 2026-09-06 at the existing 4K display
resolution. Requested ten thick-launcher shots per second for 12 seconds with
stationary aim, producing closely overlapping explosions. Isolated processes,
muted audio, real simulation and renderer, six seconds of cooldown before holster.
Destruction used a synthetic desktop/window fixture; it destroyed one window.

| Default backend scenario | Shots | Peak particles / rings | Animation interval median / p95 / max | CPU, one core = 100% | Whole-GPU peak |
| --- | --- | --- | --- | --- | --- |
| Rockets | 119 | 1,082 / 7 | 37 / 54 / 64 ms | 98.8% | 54% |
| Rockets with destruction | 119 | 1,081 / 7 | 33 / 53 / 60 ms | 99.0% | 61% |

Both runs completed without QML errors, cleared all particles, stopped the
simulation roughly 2.1 seconds after the firing period, and holstered correctly.
**They did not sustain smooth animation during rapid rocket spam.** CPU rendering
is still a bottleneck at this particle density. This is materially heavier than
the earlier 550 ms rocket interval, and limits the earlier smoothness conclusions.

An initial isolated Vulkan run delivered only 79 shots, with median/p95/max
callback intervals of 12/34/41 ms and CPU 143.4%. The harness originally required
at least 80 shots and therefore flagged this run. That threshold mixed input
delivery with cleanup correctness; the harness now reports the actual shot rate
separately and asserts cleanup/error conditions. A Vulkan-only repeat recorded
73 shots, 916 peak particles, 12/31/42 ms callback intervals,
144.6% CPU, and 55% whole-GPU peak. Cleanup and error checks passed. Vulkan
results are not equal-work comparisons because its
QML firing timer missed events under load. The live shell backend was not changed.

Callback intervals include initial aiming and cooldown while animation is awake;
intentional sleep gaps are excluded. They are not direct screen-presentation
measurements. CPU samples cover seconds 5–15. GPU readings cover the whole device,
with variable clocks and other desktop activity, and are not plugin GPU timings.
Sound and real mouse-event delivery were not tested; the timer invokes the same
shooting function as clicks. No laptop performance claims follow from this test.

The validated improvements are suitable for a development branch. Heavy rocket
spam remains an explicitly documented performance limitation; no experimental
pool or visual-quality reduction was added to production for this checkpoint.

The test opens visible click-through overlays and requires desktop/NVIDIA access.
The historical harness overwrote its output on the Vulkan-only repeat:
`rocket-stress-measurements.json` contains that repeat's raw samples. The earlier
default-backend summaries above were retained from test output. The current
harness writes the cooldown results to a separate file.
