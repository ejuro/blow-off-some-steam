# Performance implementation and verification

Implemented on 2026-09-06, against the original cb8747d arena.

## Changes

- EffectsLayer and EffectParticle replace the fullscreen effects Canvas with pooled, bounded surfaces. EffectDrawing retains the original paths, colors, and compositing order. All particle counts, artwork, and sound definitions remain intact.
- TerrainLayer partitions the frozen image into 256-pixel tiles. New damage marks are queued only on intersecting tiles. Queues retain references independently of region cleanup; the initial snapshot bridge stays visible until every tile initializes.
- FrameAnimation drives rendering. The original 16 ms physics step is retained, with bounded catch-up and interpolated visual positions/lifetimes. The simulation stops when settled and wakes on input or new effects. Particle output arrays are reused.
- Holstering releases the effect pool. Destruction delegate visibility now belongs on the delegates themselves.

This implementation deliberately retains Canvas rasterization for matching the original shapes. It removes the fullscreen effects backing surface; it does not claim to eliminate all per-frame texture uploads. Large explosion rings remain the most expensive effects. A GPU ring experiment was rejected because it changed edge rendering.

## Repeated runtime measurements

Same 4K/120 Hz display at scale 1.25; two six-second samples per scenario after warmup, in fresh isolated Quickshell processes. CPU is the test process's percentage of one core, excluding compositor CPU. See the original review for baseline method details.

| Scenario | Original CPU | New CPU | Approximate reduction |
|---|---:|---:|---:|
| Aiming | 60.4–62.4% | 5.5–5.8% | 91% |
| Automatic fire | 62.9–66.1% | 17.4–18.1% | 73% |
| Repeated large rockets | 77.3–77.8% | 46.4–47.1% | 40% |
| Destruction shooting | 93.0–96.5% | 14.4–15.5% | 84% |
| Forced falling windows | No accepted baseline | 17.5–17.6% | — |

The new destruction samples had a 17 ms maximum animation callback interval, compared with 82–87 ms maximum simulation-timer gaps in the original. The new samples also performed 375 animation callbacks per six seconds. Thus this setup's Qt animation driver delivered approximately 62.5 callbacks/sec; these results do **not** demonstrate 120 presented FPS. Presentation timing and input latency were not measured.

Armed-idle samples had zero simulation animation callbacks after warmup. Whole-process CPU remained 1.8–3.0%; idle gating does not imply every Qt subsystem becomes idle.

`implementation-measurements.json` contains raw summaries. Its legacy `ticks` field counts FrameAnimation callbacks, not individual fixed physics steps. Legacy paint counters are not instrumented in the split renderer and must not be interpreted as zero actual paints.

## Visual verification

Captured the original and new effects at fixed state: all seven particle kinds, varied angles/lifetimes, overlapping transparency, target, shadow, normal and revolver flashes. Captured tiled damage against a textured synthetic desktop with marks crossing tile boundaries. Captures are 3840×2160 and remain under `/tmp/steam-visual` for this run.

The images are not byte-identical. Against black and white backgrounds, effects comparisons had at most 194 pixels with a channel difference above 8/255 (under 0.003% of the frame); differences were confined to raster edges. The textured terrain comparison had no pixels above that threshold, with a maximum channel difference of 6/255. The earlier solid-background terrain test was pixel-identical. Raw results are in `visual-measurements.json`.

Artwork, paths, colors, counts, and stacking are preserved. These comparisons support close visual fidelity, not a guarantee of pixel identity across GPUs and display scales. A human check of moving effects is still appropriate.

## Other checks

- `omarchy plugin validate .` passed.
- `qmllint EffectsLayer.qml EffectParticle.qml TerrainLayer.qml` passed.
- Physics regression: 600 fixed steps matched the original positions, bounces, recoil, aim, lifetimes, pending effects, and explosion events across all seven particle kinds. The test stubs target collision and explosion particle generation to make the comparison deterministic; it is not a complete gameplay test.
- Isolated lifecycle tests passed actual grim capture and terrain readiness, forced capture failure/fallback, weapon swaps preserving the session, weapon wheel selection, holster/pool cleanup, rearming, target effects, and screenshot file deletion.
- Sound playback was muted during runtime tests. Drawer visuals and real audio playback still need manual verification. The drawer source and sound definitions were not changed.
- The live shell's plugin registry was reloaded after installing the validated files.

## Repeating checks

The GUI scripts open silent click-through test overlays; run them only when that is acceptable. Lifecycle testing briefly captures the actual monitor, then holsters and verifies deletion of the temporary capture. The scripts require the existing Quickshell/Omarchy tools; no production dependency was added.

```sh
node performance-review/physics-regression.js
python performance-review/implementation-benchmark.py --scenarios aim,auto,rockets,destruction --output rerun.json
python performance-review/visual-regression.py
python performance-review/lifecycle-test.py
```

The visual and physics regressions read the original Arena.qml from Git revision cb8747d. The visual script saves before/after PNGs for comparison; it does not automatically assert pixel equivalence. Synthetic benchmark scenarios do not reproduce every possible desktop layout.

## Manual test

Open the drawer, try aiming and sustained MP5/AK fire, then use both launchers. Check muzzle flashes, smoke, target hits, the weapon wheel, and spinning. In destruction mode, shoot through window edges and tile boundaries, destroy a complete window, then holster and rearm. Check that effects keep their familiar appearance and that sound remains synchronized.

## Refresh-rate follow-up

An isolated aiming test with Qt renderer diagnostics identified the default limit:

| Process configuration | Qt loop | Animation callbacks / 6 seconds | Aiming CPU |
|---|---|---:|---:|
| Default NVIDIA OpenGL | basic | 375 (62.5/sec) | 5.2% |
| QSG_RENDER_LOOP=threaded | threaded | 720 (120/sec) | 6.8% |
| QSG_RHI_BACKEND=vulkan | threaded | 720 (120/sec) | 7.4% |

Both threaded runs reported `Animation Driver: using vsync: 8.33 ms`. This demonstrates that the plugin's animation callback supports 120 Hz without changing its physics constants. It is not a direct measurement of presented frames. The tests changed only the environment of isolated processes; the live shell configuration was not changed.

The NVIDIA/Wayland basic-loop selection is documented in [Omarchy issue 7268](https://github.com/omacom/omarchy/issues/7268). Vulkan is the proposed workaround; forcing threaded OpenGL bypasses a Qt driver workaround. Full-shell compatibility and heavy-fire performance at 120 Hz have not yet been tested. Raw summaries are in `refresh-rate-measurements.json`.

## Fast-input follow-up

After manual feedback about stuttering during quick mouse movements, replaced the slow sinusoidal aiming test with 6000 logical-pixel/sec horizontal sweeps, abrupt reversals, and a 3 Hz vertical oscillation. This is still synthetic input, not a recording of the user's mouse or an end-to-end latency measurement.

The tests did not reproduce long update stalls: default animation callback intervals remained at 16–17 ms; Vulkan at 8–10 ms. QQuickWindow frameSwapped signals arrived around 120/sec even in the default test, while animation updates were still around 62.5/sec. Swap callbacks therefore must not be equated with distinct movement updates or physical screen presentation.

The previous gun interpolation introduced an additional display offset behind the calculated gun position: the default fast-sweep sample reached 104.6 logical pixels, with a median of 71.9 pixels. This offset is separate from the intentional weapon-follow distance. It supports removing unnecessary input delay, but does not prove it caused all of the user's perceived stutter.

The weapon now follows the latest pointer on every animation update, using an elapsed-time-adjusted exponential response. It retains the old 0.16 response at a 16 ms update and the same 135-pixel follow distance. Gun position and aim no longer render a historical physics state. Autonomous projectiles retain fixed-step physics and interpolation. Artwork and effect rendering are unchanged.

The 600-step regression passed with only floating-point tolerance needed for the follower calculation. A separate check confirmed equivalent stationary-target follow response for one 16 ms update versus two 8 ms updates. Runtime samples remained low: aiming 4.9%, automatic fire 17.5%, destruction 13.9% of one CPU core. Callback intervals stayed within 17 ms in these default-backend samples. See `input-motion-measurements.json` and `input-fix-performance.json`.

The live shell backend was not changed. Under the default NVIDIA basic loop, fast motion can still show the approximately 62.5 Hz movement cadence; the input fix does not unlock 120 Hz. Manual fast-mouse validation remains necessary.
