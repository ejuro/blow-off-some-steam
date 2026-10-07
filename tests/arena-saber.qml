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
    // Every gun's shot leaves the muzzle on a line through the cursor, facing either way.
    var guns = ["glock", "revolver", "ak47", "mp5a3", "bazooka"]
    for (var gi = 0; gi < guns.length; gi++) {
      for (var side = 0; side < 2; side++) {
        arena.swapWeapon(guns[gi])
        arena.recoilClimb = 0
        arena.gunPositioned = true; arena.gunX = side ? 900 : 300; arena.gunY = 400
        arena.pointerX = side ? 600 : 600; arena.pointerY = side ? 330 : 470
        for (var settle = 0; settle < 120; settle++) arena.advanceWeapon(0.016)
        arena.particles = []
        var fired = arena.fire()
        var shot = arena.particles.filter(function(p) { return p.kind === 6 || p.kind === 3 })[0]
        check(fired && shot, guns[gi] + (side ? " facing left" : " facing right") + " fired: " + fired + " " + arena.particles.length)
        var ax = arena.pointerX - shot.x, ay = arena.pointerY - shot.y, speed = Math.sqrt(shot.vx * shot.vx + shot.vy * shot.vy)
        var miss = Math.abs(ax * shot.vy - ay * shot.vx) / speed
        check(miss < 2 && ax * shot.vx + ay * shot.vy > -1e9, guns[gi] + (side ? " facing left" : " facing right") + " shoots at the cursor (off by " + miss.toFixed(1) + " px)")
      }
    }
    // Sweeping the cursor from right of the gun to its left: the gun rolls over and
    // turns smoothly, never jumping more than 30 degrees or half a roll in one frame.
    arena.swapWeapon("glock")
    arena.gunPositioned = true; arena.gunX = 500; arena.gunY = 400; arena.pointerX = 640; arena.pointerY = 380
    for (var w0 = 0; w0 < 120; w0++) arena.advanceWeapon(0.016)
    var lastAngle = arena.renderAimAngle, lastRoll = arena.flipScale, worstTurn = 0, worstRoll = 0
    for (var f = 0; f < 90; f++) {
      arena.pointerX -= 12
      arena.advanceWeapon(0.016)
      worstTurn = Math.max(worstTurn, Math.abs(((arena.renderAimAngle - lastAngle) % 360 + 540) % 360 - 180))
      worstRoll = Math.max(worstRoll, Math.abs(arena.flipScale - lastRoll))
      lastAngle = arena.renderAimAngle; lastRoll = arena.flipScale
    }
    for (var w1 = 0; w1 < 60; w1++) arena.advanceWeapon(0.016)
    check(arena.aimFlipped && arena.flipScale === -1, "the gun ends up facing left")
    check(worstTurn < 30 && worstRoll < 0.5, "crossing over is smooth: " + worstTurn.toFixed(1) + " deg, roll " + worstRoll.toFixed(2))
    // The Colt is thrown back and its barrel flips up, for the look only, and it eases back.
    arena.swapWeapon("revolver")
    arena.gunPositioned = true; arena.gunX = 300; arena.gunY = 400; arena.pointerX = 600; arena.pointerY = 400
    for (var cs = 0; cs < 120; cs++) arena.advanceWeapon(0.016)
    var trueAim = arena.aimAngle
    check(arena.fire() && arena.recoil === 46 && arena.renderAimAngle < trueAim - 10 && arena.aimAngle === trueAim, "the Colt kicks back and flips up without moving the aim")
    for (var st = 0; st < 6; st++) arena.simulateStep()
    check(arena.recoil > 20, "the Colt slides back slowly: " + arena.recoil)
    arena.swapWeapon("glock")
    // Signatures. Colt: one round kills every fly on its path and keeps flying.
    arena.swapWeapon("revolver")
    var killsBefore = hunt.round.kills
    for (var c = 0; c < 3; c++) { flies[c].spawn(); flies[c].x = 700 + c * 120; flies[c].y = 300 }
    check(!arena.hitBug(600, 300, 1100, 300, 6, "revolver", 777), "a piercing round is not stopped")
    check(hunt.round.kills === killsBefore + 3 && hunt.burstCount === 3, "the Colt pierces every fly in line")
    // AK: holding climbs the muzzle and it settles when released.
    arena.swapWeapon("ak47")
    for (var a = 0; a < 6; a++) arena.shoot(false)
    check(arena.recoilClimb >= 8, "the AK climbs as it fires: " + arena.recoilClimb)
    arena.advanceWeapon(1)
    check(arena.recoilClimb === 0, "the climb settles once the trigger is released")
    // A first shot goes where it points; a long spray scatters widely.
    function scatter(climb) {
      var worst = 0
      for (var n = 0; n < 150; n++) {
        arena.recoilClimb = climb; arena.particles = []
        arena.shoot(false)
        var round = arena.particles.filter(function(p) { return p.kind === 6 })[0]
        var off = Math.abs(((Math.atan2(round.vy, round.vx) * 180 / Math.PI - arena.aimAngle) % 360 + 540) % 360 - 180)
        worst = Math.max(worst, off)
      }
      return worst
    }
    var tight = scatter(0), wide = scatter(22)
    arena.recoilClimb = 0
    check(tight < 0.5 && wide > 12 && wide < 16.5, "AK spread grows with the spray: " + tight.toFixed(2) + " / " + wide.toFixed(1) + " deg")
    // MP5: a click is a 3-round burst, and the next one waits for the cooldown.
    arena.swapWeapon("mp5a3")
    check(arena.fire() && arena.burstLeft === 2 && !arena.fire(), "the MP5 fires 3-round bursts")
    arena.swapWeapon("glock")
    check(arena.burstLeft === 0, "switching weapons ends a burst")
    // M20: the shockwave flings the flies just outside the blast.
    flies[3].spawn(); flies[3].x = 900; flies[3].y = 500
    hunt.hitBlast(900 - 280, 500, 180, "bazooka")
    check(flies[3].alive && flies[3].stun > 0, "the M20 flings a fly outside its blast")
    arena.swapWeapon("lightsaber")
    arena.shoot(false)
    arena.openWeaponWheel(500, 350)
    check(!arena.weaponWheelOpen && arena.saberHeld, "Fly Hunt keeps the wheel shut")
    arena.retractSaber()
    hunt.round.deadline = Date.now() - 1
    check(hunt.acceptHits() && hunt.lastShot && arena.igniteSaber(), "the saber still works in bullet time")
    arena.retractSaber()
    for (var b = 0; b < 30; b++) arena.advanceSaber(.016)
    hunt.endLastShot(0)
    check(hunt.ending && !arena.igniteSaber(), "nothing fires while the final kill lingers")
    hunt.finishRound()
    check(hunt.finished && !arena.igniteSaber(), "round cutoff blocks saber")
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
