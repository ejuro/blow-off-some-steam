import QtQuick
import Quickshell
import ".." as Steam
ShellRoot {
  Steam.Arena { id: arena }
  // A failed check reports and quits, so the runner shows why instead of timing out.
  function check(ok, message) { if (!ok) { console.log("FAILED: " + message); Qt.quit(); throw new Error(message) } }
  function findHunt(item) {
    if (typeof item.hitSaber === "function") return item
    if (item.item) { var loaded = findHunt(item.item); if (loaded) return loaded }
    if (item.children) for (var i = 0; i < item.children.length; i++) {
      var found = findHunt(item.children[i]); if (found) return found
    }
    return null
  }
  Timer { interval: 150; running: true; onTriggered: {
    var surface = null
    for (var i = 0; i < arena.data.length; i++) {
      var object = arena.data[i]
      if (String(object).indexOf("WaylandPanelInterface") >= 0) { surface = object; surface.visible = false }
    }
    check(surface !== null, "hidden arena surface")
    arena.audio.active = false
    arena.setBugHuntEnabled(true)
    arena.arm("lightsaber")
    var hunt = findHunt(surface.contentItem)
    check(hunt !== null, "fly layer loaded")
    check(arena.huntBriefing && !hunt.acceptHits(), "a hunt opens on the briefing")
    hunt.startCountdown()
    check(!arena.huntBriefing && hunt.countingDown, "starting leaves the briefing")
    // Skip the 3 · 2 · 1 countdown; hits are refused until it ends.
    hunt.countingDown = false
    var flies = []
    for (var j = 0; j < hunt.children.length; j++) if (typeof hunt.children[j].spawn === "function") flies.push(hunt.children[j])
    arena.gunX = 500; arena.gunY = 350; arena.gunPositioned = true; arena.aimAngle = 0
    for (var k = 0; k < flies.length; k++) { flies[k].spawn(); flies[k].x = 640; flies[k].y = 350 }
    check(arena.shoot(false), "saber ignites through attack path")
    for (var n = 0; n < 18; n++) arena.advanceSaber(.016)
    check(hunt.kills === 4 && hunt.score === 1000, "extending blade hits and scores")
    check(hunt.round.weapon === "lightsaber", "round belongs to the saber")
    check(arena.particles.length === 0, "saber creates no bullets")
    check(arena.saberHeld && arena.saberIgnition === 1, "held saber stays lit")
    // A lit spin cuts: flies below the hilt are swept as the blade turns.
    for (var m = 0; m < flies.length; m++) { flies[m].spawn(); flies[m].x = 500; flies[m].y = 520 }
    arena.trickAngle = 90
    arena.advanceSaber(.016)
    check(hunt.kills === 8, "lit spin cuts")
    arena.trickAngle = 0
    arena.retractSaber()
    for (var r = 0; r < 30; r++) arena.advanceSaber(.016)
    check(!arena.saberHeld && arena.saberIgnition === 0, "release retracts the blade")
    arena.shoot(false)
    arena.swapWeapon("glock")
    check(!arena.saberHeld && arena.saberIgnition === 0 && arena.saberTrail.length === 0, "switch puts the saber out")
    check(arena.shoot(false) && arena.particles.length > 0, "guns still fire")
    arena.swapWeapon("lightsaber")
    arena.shoot(false)
    arena.openWeaponWheel(500, 350)
    check(!arena.weaponWheelOpen && arena.saberHeld, "Fly Hunt keeps the wheel shut")
    arena.retractSaber()
    hunt.round.deadline = Date.now() - 1; hunt.finishRound()
    check(!arena.igniteSaber(), "round cutoff blocks saber")
    hunt.restart()
    check(arena.igniteSaber(), "replay restores saber")
    hunt.countingDown = false; hunt.recordKill(10, 10, "saber")
    arena.arm("glock")
    check(hunt.weapon === "glock" && hunt.round.weapon === "glock" && hunt.score === 0 && hunt.countingDown, "picking another weapon restarts the hunt with it")
    arena.setMode("free")
    check(arena.mode === "free" && !arena.bugHuntEnabled, "free play")
    arena.swapWeapon("lightsaber")
    arena.shoot(false)
    arena.openWeaponWheel(500, 350)
    check(arena.weaponWheelOpen && !arena.saberHeld && arena.saberIgnition === 0, "wheel puts the saber out")
    arena.closeWeaponWheel(false)
    arena.holster()
    check(!arena.saberHeld && arena.saberIgnition === 0 && !arena.armed, "holster puts the saber out")
    console.log("ARENA_SABER_OK"); done.start()
  } }
  Timer { id: done; interval: 150; onTriggered: Qt.quit() }
}
