# Blow off some steam

A playful Omarchy Shell bar widget. Open the animated weapon wardrobe and choose one of six harmless weapons, with optional desktop destruction.

![Blow off some steam weapon drawer](preview.png)

## Requirements

- Omarchy with Quickshell plugin support.
- `grim` for capturing the monitor where the weapon case was opened (included with Omarchy).
- Python 3 and the `qs` executable for the isolated audio worker (included with the tested Omarchy installation). All artwork and sounds are bundled.

## Audio isolation

The audio launcher uses the system executables `/usr/bin/python3` and `/usr/bin/qs`, with no PATH-based fallback. Python starts in isolated mode with site initialization disabled. Both processes receive a minimal environment; only `XDG_RUNTIME_DIR`, `PIPEWIRE_RUNTIME_DIR`, and `PULSE_SERVER` are inherited to locate the audio service. The worker uses temporary private home/configuration/cache directories. Custom Python, Qt/QML, library, and PipeWire configuration overrides are not forwarded.

Sound effects and music run in a separate, supervised Qt process while the weapon case or game is open. Closing both shuts it down. Audio is not initialized in the shell by this plugin while idle.

If the audio process crashes, stops responding, or loses contact with the shell, it is terminated and the game continues without sound. Close the case and holster, then reopen to start a fresh audio session. A long suspend also invalidates the old session. The worker uses only packaged audio and a private local socket, with bounded message buffers and suppressed worker logging.

This contains failures related to [issue #4](https://github.com/ejuro/blow-off-some-steam/issues/4); it is not a confirmed fix for the underlying Qt/PipeWire suspend/resume crash.

## Desktop capture privacy

Desktop destruction is opt-in. Its helpers use absolute system executable paths and a minimal environment. A supervised capture helper requires a user-owned runtime directory with mode `0700`, creates an unpredictable snapshot exclusively with mode `0600`, and directs `grim` into that already-open file. It never follows or overwrites an existing snapshot. Capturing is limited to 15 seconds and 256 MiB. Holstering, cancellation, and normal shell termination remove the snapshot; forcibly killing the capture helper itself can leave a private file until the runtime directory is cleared at logout/reboot. The game does not delete or modify real windows or user documents.

## Controls

- Click the bar icon to open the weapon case.
- Choose the **Glock P80**, **Colt 45**, **AK-47**, **MP5A3**, **M20 Bazooka**, or **Thick M20**.
- Check **Desktop destruction** to freeze the current monitor into a safe, destructible playground after choosing a weapon. It is off by default, and your real windows and files remain untouched.
- Click to fire. Hold with the AK-47 or MP5A3 for automatic fire.
- Right-click while armed to spin the weapon once around its grip.
- Hold the middle mouse button, drag toward a weapon in the hexagonal wheel, and release to switch. Keyboard users can hold **Q**, select with arrow keys, and release; number keys **1–6** or **Enter** also choose while the wheel is open.
- Glock, Colt, AK-47, and MP5 rounds remain visible and ricochet off screen edges with damped momentum.
- Ejected casings tumble and bounce independently when they reach a screen edge.
- **Target practice** is off by default. Check it in the drawer to spawn a roaming bullseye; hit it to dissolve it into smoke and relocate it.
- **Fly Hunt** spawns four animated flies. Shoot them to leave a theme-colored splat; each fly returns after a short delay. Rocket blasts can hit several flies at once.
- Local video experiment: 20 fly kills summon **The Motherfly**, a giant boss with 120 health. Combat pauses for an ominous buzz and dramatic reveal. She enrages at 35% health with a brief pause, then darts across the screen with short shake pulses. She falters at 10%, and spirals into a giant splat on defeat. Boss splats sound every 30 health lost and on landing. Bullets deal one damage and blasts deal eight; direct rockets also register their projectile hit. Holstering or leaving Fly Hunt resets the encounter and stops its sounds.
- **Target practice**, **Fly Hunt**, and **Desktop destruction** are mutually exclusive; enabling one automatically disables the others.
- Rockets ricochet from screen edges and burst when the launcher recording reaches its explosion; direct hits detonate immediately, and the full blast radius can hit targets.
- Bullet impacts leave persistent holes and cracks; rocket explosions scorch much larger areas of the captured desktop.
- Press **Escape**, or right-click the bar icon after returning to it, to holster.

While armed, the fullscreen overlay intentionally captures pointer input so shots do not click the windows underneath it.

**Giant Wings**, the Motherfly soundtrack, fades in at her reveal, loops during the fight, and fades out during her death tumble. Holstering or leaving Fly Hunt stops the music immediately.

Desktop destruction stores its frozen frame as an owner-only temporary file under `$XDG_RUNTIME_DIR` (the private session directory). The file is removed when the weapon is holstered; an abnormal shell termination may leave it until session cleanup.

## Install

```bash
omarchy plugin add https://github.com/ejuro/blow-off-some-steam.git --enable
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

Weapon sprites are from [GUNS V1.01 by Arcade Island](https://arcadeisland.itch.io/guns-asset-pack-v1), used and modified under the terms published on that page. The sprites under `assets/` are not covered by this plugin's MIT license. Arcade Island permits use and modification in personal and commercial projects, but does not permit reselling the assets individually or redistributing them as your own creation.

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
- “Fly buzzing from left to right” by Kuzu420

These audio files are not covered by this plugin's MIT license. See `sounds/README.md` for source links and details.
