# Blow off some steam

A playful Omarchy Shell bar widget. Open the animated weapon wardrobe and choose one of six harmless weapons, with optional desktop destruction.

![Blow off some steam weapon drawer](preview.png)

## Requirements

- Omarchy with Quickshell plugin support.
- `grim` for capturing the monitor where the weapon case was opened (included with Omarchy).
- Python 3 and the `qs` executable for the isolated audio worker (included with the tested Omarchy installation). All artwork and sounds are bundled.

## Audio isolation

The audio launcher uses the system executables `/usr/bin/python3` and `/usr/bin/qs`, with no PATH-based fallback. Python starts in isolated mode with site initialization disabled. Both processes receive a minimal environment; only `XDG_RUNTIME_DIR`, `PIPEWIRE_RUNTIME_DIR`, and `PULSE_SERVER` are inherited to locate the audio service. The worker uses temporary private home/configuration/cache directories. Custom Python, Qt/QML, library, and PipeWire configuration overrides are not forwarded. Hardware video codec probing is switched off in the worker, since sound effects never need it and it would delay the first sound by about a second. While it runs, the worker also plays a loop of digital silence: many USB DACs, HDMI monitors, and amplifiers mute the first moment of sound after their output has been asleep, which would swallow the first hover sound.

Sound effects run in a separate, supervised Qt process. Hovering the bar icon prepares the audio before a click; it stays available while the weapon case or game is open. Leaving the icon with both closed shuts the worker down. The drawer opens immediately and never waits on audio. Audio is never initialized inside the shell process. The speaker button beside the drawer title mutes everything; while muted the worker is not started at all. The choice is saved in `settings.json` in the plugin's state folder.

Qt 6.11 silences every effect in the process while any playing effect sits at volume 0 (or muted), so the worker never lowers a playing effect below -80 dB.

If the audio process crashes, stops responding, or loses contact with the shell, it is terminated and the game continues without sound. Close the case and holster, then reopen to start a fresh audio session. A long suspend also invalidates the old session. The worker uses only packaged audio and a private local socket, with bounded message buffers and suppressed worker logging.

This contains failures related to [issue #4](https://github.com/erikrjohansson/blow-off-some-steam/issues/4); it is not a confirmed fix for the underlying Qt/PipeWire suspend/resume crash.

## Desktop capture privacy

Desktop destruction is opt-in. Its helpers use absolute system executable paths and a minimal environment. A supervised capture helper requires a user-owned runtime directory with mode `0700`, creates an unpredictable snapshot exclusively with mode `0600`, and directs `grim` into that already-open file. It never follows or overwrites an existing snapshot. Capturing is limited to 15 seconds and 256 MiB. Holstering, cancellation, and normal shell termination remove the snapshot; forcibly killing the capture helper itself can leave a private file until the runtime directory is cleared at logout/reboot. The game does not delete or modify real windows or user documents.

## Controls

- Click the bar icon to open the weapon case.
- Choose the **Glock P80**, **Colt 45**, **AK-47**, **MP5A3**, **M20 Bazooka**, or **Lightsaber**.
- Pick a mode above the weapons: **Free play** (the default), **Targets**, **Fly Hunt**, or **Destruction**. One mode is active at a time.
- **Destruction** freezes the current monitor into a safe, destructible playground after choosing a weapon. Your real windows and files remain untouched.
- Click to fire. Hold with the AK-47 or MP5A3 for automatic fire.
- Right-click while armed to spin the weapon once around its grip.
- Hold the middle mouse button, drag toward a weapon in the weapon wheel, and release to switch. Keyboard users can hold **Q**, select with arrow keys, and release; number keys **1–6** or **Enter** also choose while the wheel is open.
- Glock, Colt, AK-47, and MP5 rounds remain visible and ricochet off screen edges with damped momentum.
- **Lightsaber** uses a shaded pixel-style steel hilt and a theme-colored energy blade. It starts unlit: hold left-click to ignite it with a snap-hiss and steady hum, and release to retract it. While lit, the blade cuts whatever it sweeps through as you move the mouse, and its hum swells and brightens continuously with blade speed. Right-click spins the saber; a lit spin cuts too. The blade can cleave several flies at once, leaving a splat and two frozen sprite halves that separate, tumble, and fall, and crackles when it strikes a fly or practice target. In desktop destruction the blade tip cuts: where it travels inside a window it burns a groove (a thin slit, a charred rim, and an edge that glows white-hot in the theme color, then cools to orange) with sparks and a sizzle, and anything the cuts free from the rest of the window falls with a hiss: a closed loop drops out as a hole (a lit right-click spin carves a circle around the hilt), and a cut that enters and leaves through the window's edge, straight or curved, drops the smaller side. What remains stays up and can be cut again, and shots pass through holes and cut-away parts. Switching weapons, opening the wheel, and holstering put the blade out at once; losing focus retracts it.
- The weapon case scrolls when it is taller than the display.
- Ejected casings tumble and bounce independently when they reach a screen edge.
- **Targets** spawns a roaming bullseye; hit it to dissolve it into smoke and relocate it.
- **Fly Hunt** is a 40-second round with four animated flies at different speeds. A new hunt opens on a briefing card with the goal, how combos work, and your best with that weapon; left-click (or Space/Enter) starts a 3 · 2 · 1 · GO countdown with a beep on each step. **Play again** skips the briefing. After GO, and flies fly in from the screen edges, respawning 0.25–0.55 seconds after a kill. Each kill earns 100 points times your combo: each kill soon after the last increases the multiplier from ×1 to a maximum of ×5. The window tightens as the combo grows: 1.8 seconds at ×1, then 1.5, 1.25, 1.05, and 0.9 seconds at ×5. Multi-kills build the combo too. Misses do not penalize your score. Now and then a **golden fly** appears with a chime: it is fast, trails gold dust, and is worth ×3 points at your current combo, but it leaves after five seconds. Killing it bursts coins with a cha-ching. Each round is played with the one weapon you pick: in Fly Hunt mode every weapon card shows your best score with it, the weapon wheel is disabled during the round, and picking another weapon from the case starts a fresh round with it.
- Kills hit hard: flies and shots freeze for a split second (longer for multi-kills), the play area shakes harder as the combo climbs, and splats and their sprayed drops grow with the combo. The weapon and HUD stay steady.
- In the last ten seconds a **10 SECONDS!** callout appears, the timer pops on every second with a clock tick, and a red glow at the screen edges pulses stronger toward zero. The final three seconds tick twice as fast on a higher tick.
- The Fly Hunt HUD shows time, your best with the current weapon, score, kills, and the current multiplier. Each kill pops up its points where the fly died; they fly up into the HUD score, which rolls up and bumps as they land. Shot flies squash and tumble away (rockets fling them), and every kill sheds its wings. A bar under the HUD drains over the current combo window; when it runs out, the lost combo shakes and greys out. Killing several flies with one rocket blast or one saber sweep calls out DOUBLE, TRIPLE, or QUAD. At zero, shooting and scoring stop and the moment plays out in slow motion with a TIME! callout; a kill in the last 0.7 seconds is ringed as the FINAL KILL. The result screen then counts up your score, slams down the medal it earned, names the next medal to aim for, and shows how it compares with your best for that weapon; a new best gets confetti and a fanfare.
- **Medals:** each weapon has its own bronze, silver, gold, and platinum scores, since slow weapons score less in a round. Glock P80 4000 / 9000 / 14000 / 20000, Colt 45 5000 / 12000 / 18000 / 25000, MP5A3 6000 / 15000 / 22000 / 30000, AK-47 7000 / 15000 / 24000 / 32000, M20 2500 / 6000 / 10000 / 15000, Lightsaber 8000 / 16000 / 26000 / 36000. In Fly Hunt mode each weapon card shows its best medal in the lower-left corner. It offers **Play again**. Escape abandons an unfinished round without saving it.
- The weapon case has **Play** and **High scores** tabs. High scores lists your best completed round with each weapon (score, kills, best multiplier, and date) and highlights the overall best. Rounds from the earlier 60-second length, and older rounds that mixed several weapons, are kept in the file but do not count for any weapon. Rounds are stored locally in `$XDG_STATE_HOME/blow-off-some-steam/fly-records.json` (default `~/.local/state/blow-off-some-steam/fly-records.json`), which keeps the top 20 per weapon. There is no accuracy tracking.
- Rockets ricochet from screen edges and burst when the launcher recording reaches its explosion; direct hits detonate immediately, and the full blast radius can hit targets.
- Bullet impacts leave persistent holes and cracks; rocket explosions scorch much larger areas of the captured desktop.
- Press **Escape**, or right-click the bar icon after returning to it, to holster.

While armed, the fullscreen overlay intentionally captures pointer input so shots do not click the windows underneath it.

Desktop destruction stores its frozen frame as an owner-only temporary file under `$XDG_RUNTIME_DIR` (the private session directory). The file is removed when the weapon is holstered; an abnormal shell termination may leave it until session cleanup.

## Install

```bash
omarchy plugin add https://github.com/erikrjohansson/blow-off-some-steam.git --enable
```

## Remove

```bash
omarchy plugin remove io.github.ejuro.blow-off-some-steam
```

## Validate

```bash
omarchy plugin validate .
```

## Third-party artwork

The six conventional weapon sprites are from [GUNS V1.01 by Arcade Island](https://arcadeisland.itch.io/guns-asset-pack-v1), used and modified under the terms published on that page. The sprites under `assets/` are not covered by this plugin's MIT license. Arcade Island permits use and modification in personal and commercial projects, but does not permit reselling the assets individually or redistributing them as your own creation.

## Third-party sounds

The processed sounds under `sounds/` are derived from the following Pixabay downloads and are used under the [Pixabay Content License](https://pixabay.com/service/license-summary/):

- “FX GUN PISTOL Glock 19x” by Substancial
- “AK-47 Sound Effect” by Red_Army_Soviet
- “RPG-7 Sound Effect” by Sovetsky_Rastov72
- “Single Pistol Gunshot 3.3” by morganpurkis (via freesound_community)
- “MP5” by jigokukarano_sisya
- “Load Gun sound effect 5” by beetpro
- “Window Breaking” by m1a2t3z4 (via freesound_community)
- “Slime Impact” by Universfield

These audio files are not covered by this plugin's MIT license. See `sounds/README.md` for source links and details.

Fly Hunt checks: `node tests/fly-round.cjs` for scoring rules, and `python tests/fly-hunt.py` for the QML timer, replay, cutoff, and records persistence. The QML check runs offscreen with temporary state and no desktop/audio interaction.

Lightsaber collision and records checks: `node tests/saber.cjs`; cut geometry: `node tests/cut.cjs`. Silent hidden-window drawer and saber integration checks (requires the desktop session): `python tests/weapon-runtime.py`.
