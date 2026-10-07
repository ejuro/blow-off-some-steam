#!/usr/bin/env python3
"""Isolated QML round lifecycle and records persistence checks; no desktop/audio use."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="steam-fly-test-") as folder:
    base = Path(folder)
    runtime = base / "runtime"
    runtime.mkdir(mode=0o700)
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), XDG_STATE_HOME=str(base / "state"),
               QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="basic", QT_QUICK_CONTROLS_STYLE="Basic")
    env.pop("DISPLAY", None)
    env.pop("WAYLAND_DISPLAY", None)
    preamble = f'import QtQuick\nimport Quickshell\nimport "{ROOT.as_uri()}" as Steam\n'

    def run(source, marker):
        (base / "shell.qml").write_text(preamble + source)
        process = subprocess.run(["/usr/bin/qs", "-p", str(base), "--no-color"], env=env,
                                 capture_output=True, text=True, timeout=10)
        log = process.stdout + process.stderr
        assert process.returncode == 0 and marker in log, log
        assert not any(word in log for word in ["ReferenceError", "TypeError", "Failed to load configuration"]), log

    run('''ShellRoot {
      Steam.FlyRecords { id: records }
      Item {
        id: fake
        property bool armed: false
        property var audio: null
        property color accent: "#55ddbb"
        property color foreground: "#e0e0e0"
        property color background: "#101315"
        property color muted: "#707880"
        property color urgent: "#a55555"
        property string fontFamily: "monospace"
        property int cornerRadius: 0
        property string weapon: "glock"
        property bool saberHeld: false
        function tint(color, alpha) { return Qt.rgba(color.r, color.g, color.b, alpha) }
        property var flyRecords: records
        property int clears: 0
        function clearRoundEffects() { clears++ }
        function weaponNames(ids) { return ids.join(" · ") }
        function holster() {}
      }
      Steam.BugHuntLayer { id: hunt; width: 1280; height: 720; arena: fake }
      function check(ok, message) { if (!ok) throw new Error(message) }
      Timer {
        interval: 250; running: true
        onTriggered: {
          check(records.ready, "records loaded")
          check(hunt.briefing && !hunt.countingDown && !hunt.acceptHits(), "a new hunt opens on the briefing")
          hunt.startCountdown()
          check(!hunt.briefing && hunt.countingDown && !hunt.acceptHits(), "countdown refuses hits")
          hunt.countingDown = false
          check(hunt.round.weapon === "glock", "round belongs to the armed weapon")
          hunt.recordKill(100, 100, "projectile"); hunt.recordKill(200, 100, "projectile")
          check(hunt.score === 300 && hunt.bestCombo === 2, "QML scoring")
          check(hunt.hitStop > 0 && hunt.trauma > 0, "kills cause hit-stop and shake")
          // One rocket blast catching every fly counts as a single multi-kill.
          var grouped = []
          for (var f = 0; f < hunt.children.length; f++) if (typeof hunt.children[f].spawn === "function") grouped.push(hunt.children[f])
          for (var g = 0; g < grouped.length; g++) { grouped[g].spawn(); grouped[g].x = 600 + g * 20; grouped[g].y = 400 }
          hunt.hitBlast(630, 400, 180)
          check(hunt.kills === 6 && hunt.burstCount === 4, "blast is one multi-kill")
          check(hunt.hitStop >= 0.12, "a quad kill holds the hit-stop longer")
          var drops = 0
          for (var d = 0; d < hunt.children.length; d++) if (typeof hunt.children[d].start === "function" && hunt.children[d].active && hunt.children[d].life) drops++
          check(drops > 0, "kills spray drops")
          hunt.round.deadline = Date.now() + 80
          expired.start()
        }
      }
      Timer {
        id: expired; interval: 200
        onTriggered: {
          check(hunt.ending && !hunt.finished && hunt.secondsLeft === 0 && hunt.timeScale < 1, "time's up slows down before the results")
          check(records.records.length === 1, "saved as soon as time is up")
          slowed.start()
        }
      }
      Timer {
        id: slowed; interval: 1500
        onTriggered: {
          check(hunt.finished && !hunt.ending && hunt.timeScale === 1 && hunt.secondsLeft === 0, "timer finished the round")
          check(Math.round(hunt.hudScore) === hunt.score, "the HUD score counted up to the total")
          check(hunt.medal === -1 && hunt.nextMedal.name === "Bronze" && hunt.nextMedal.score === 4000, "2000 with the Glock earns no medal yet")
          hunt.finishRound()
          check(records.records.length === 1, "saved exactly once")
          check(hunt.personalBest && !hunt.revealed, "first round is a best, revealed after the count-up")
          revealed.start()
        }
      }
      Timer {
        id: revealed; interval: 2200
        onTriggered: {
          check(hunt.revealed && Math.round(hunt.shownScore) === hunt.score, "score counted up")
          check(hunt.confettiFlying, "a new best launches confetti")
          check(!hunt.hitProjectile(0, 0, 1280, 720, 1000), "late projectile rejected")
          hunt.hitBlast(640, 360, 2000)
          check(hunt.score === 2000, "late blast rejected")
          hunt.restart()
          check(!hunt.finished && hunt.score === 0 && hunt.secondsLeft === 40 && fake.clears === 1, "replay reset")
          check(hunt.round.weapon === "glock" && hunt.bestCombo === 0, "replay keeps the weapon and resets stats")
          check(hunt.countingDown && !hunt.briefing, "replay skips the briefing and counts down")
          // An abandoned second round must not create a record.
          hunt.recordKill(100, 100, "projectile")
          done.start()
        }
      }
      Timer { id: done; interval: 250; onTriggered: { console.log("ROUND_OK"); Qt.quit() } }
    }''', "ROUND_OK")
    saved = json.loads((base / "state/blow-off-some-steam/fly-records.json").read_text())
    assert len(saved["records"]) == 1, saved
    record = saved["records"][0]
    assert (record["score"], record["kills"], record["bestCombo"], record["weapon"], record["weapons"], record["seconds"]) == (2000, 6, 5, "glock", ["glock"], 40), record
    run('''ShellRoot {
      Steam.FlyRecords { id: records }
      Timer { interval: 300; running: true; onTriggered: {
        if (!records.ready || records.records.length !== 1 || records.bests.glock.score !== 2000)
          throw new Error("Records failed to survive restart")
        console.log("RELOAD_OK"); Qt.quit()
      } }
    }''', "RELOAD_OK")
print("QML round timer, late hits, replay, abandoned round, and records reload passed.")
