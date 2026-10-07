import QtQuick
import QtQuick.Effects
import "FlyRound.js" as Rules
import "SaberGeometry.js" as Saber

Item {
  id: hunt
  required property var arena
  readonly property int flyCount: 4
  property real wingTime: 0
  // The whole round is played with the weapon it was started with.
  readonly property string weapon: arena.weapon
  property var round: Rules.fresh(Date.now(), weapon)
  property int score: 0
  property int kills: 0
  property int combo: 0
  property int bestCombo: 0
  property int secondsLeft: Rules.roundSeconds
  property bool finished: false
  property bool personalBest: false
  // The weapon's best before this round, for the result screen.
  property var previousBest: null
  // Share of the current combo window left; drives the combo timer bar.
  property real comboLeft: 0
  // The combo that just ran out, shown greyed while the break animation plays.
  property int lostCombo: 0
  property bool comboBreaking: false
  // Kills from one rocket blast or one continuous saber sweep form a burst.
  property string burstSource: ""
  property real burstLast: 0
  property int burstCount: 0
  // 3 · 2 · 1 · GO before each round; flies stay away and the clock waits.
  property bool countingDown: false
  property int countdownStep: 0
  readonly property var multiKillNames: ["", "", "DOUBLE!", "TRIPLE!", "QUAD!"]
  // Time's up plays out in slow motion before the results: flies, splats and
  // shots slow to timeScale, and a kill in the last moment is called out.
  property bool ending: false
  property real timeScale: 1
  property real lastKillTime: 0
  property real lastKillX: 0
  property real lastKillY: 0
  // The HUD score counts up to each new total instead of jumping to it;
  // a reset to zero is instant.
  property real hudScore: 0
  Behavior on hudScore { id: countUp; NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
  onScoreChanged: {
    countUp.enabled = score > 0
    hudScore = score
    if (score > 0) scorePunch.restart()
  }
  // This round's medal (-1 for none), the weapon's medal before it, and the next one up.
  property int medal: -1
  property int previousMedal: -1
  property var nextMedal: null
  readonly property color gold: "#ffc93c"
  // Hit feel: each kill briefly freezes the flies and projectiles (hit-stop) and
  // adds shake "trauma" to the play area. The weapon and HUD never shake.
  property real hitStop: 0
  property real trauma: 0
  property real shakeTime: 0
  readonly property real shakeX: 16 * trauma * trauma * (Math.sin(shakeTime * 71) + 0.5 * Math.sin(shakeTime * 113 + 1.7)) / 1.5
  readonly property real shakeY: 16 * trauma * trauma * (Math.sin(shakeTime * 83 + 0.6) + 0.5 * Math.sin(shakeTime * 127 + 3.1)) / 1.5
  Translate { id: worldShake; x: hunt.shakeX; y: hunt.shakeY }
  // Heavier guns land harder: the weapon's stopScale stretches the hit-stop.
  function impact() {
    var burst = Math.max(1, burstCount)
    var feel = arena.spec && arena.spec.stopScale !== undefined ? arena.spec.stopScale : 1
    var stop = (burst >= 2 ? Math.min(0.13, 0.09 + 0.02 * (burst - 2)) : 0.035 + 0.008 * combo) * feel
    hitStop = Math.max(hitStop, stop)
    trauma = Math.min(1, trauma + (0.12 + 0.05 * combo + (burst >= 2 ? 0.2 : 0)) * (0.7 + 0.3 * feel))
  }
  // Each shot nudges the play area by the weapon's kick: a thump for the Colt, a tick for the MP5.
  function kick(amount) {
    if (amount > 0 && acceptHits()) trauma = Math.min(1, trauma + amount)
  }
  // A new hunt opens on a briefing card; the first left-click starts the countdown.
  property bool briefing: false
  function startCountdown() {
    briefing = false
    countingDown = true
    countdownStep = 3
    countdownTimer.restart()
    countdownCue()
    countdownText.pop()
  }
  // A beep on 3 · 2 · 1 and a higher, longer one on GO.
  function countdownCue() {
    var cue = countdownStep > 0 ? countdownBeep : countdownGo
    cue.stop(); cue.play()
  }
  RemoteSound { id: countdownBeep; audio: hunt.arena.audio; source: Qt.resolvedUrl("sounds/countdown-beep.wav"); volume: 0.62 }
  RemoteSound { id: countdownGo; audio: hunt.arena.audio; source: Qt.resolvedUrl("sounds/countdown-go.wav"); volume: 0.37 }
  Timer {
    id: countdownTimer
    interval: 650; repeat: true
    onTriggered: {
      // Cancelled (or skipped) from outside: leave the running round alone.
      if (!hunt.countingDown) { stop(); return }
      hunt.countdownStep--
      if (hunt.countdownStep === 0) {
        hunt.round = Rules.fresh(Date.now(), hunt.weapon)
        hunt.countingDown = false
      }
      if (hunt.countdownStep < 0) { stop(); return }
      hunt.countdownCue()
      countdownText.pop()
    }
  }
  Component.onCompleted: briefing = true
  function acceptHits() {
    if (finished || ending || countingDown || briefing) return false
    if (!lastShot && Date.now() >= round.deadline) beginLastShot()
    return true
  }
  function recordKill(x, y, source, weapon, golden) {
    var now = Date.now()
    var before = round.score
    if (!lastShot && now >= round.deadline) beginLastShot()
    if (lastShot) {
      if (!Rules.finalKill(round, now, golden)) return
      // The first kill ends bullet time; the rest of the same blast or sweep still counts.
      if (!finalKill) {
        finalKill = true
        lastShotLeft = 0; lastShotClock.stop()
        finalKillMark.show(x, y)
        timeCallout.hide()
        lastShotClose.restart()
      }
    } else if (!Rules.kill(round, now, golden)) return
    lastKillTime = now; lastKillX = x; lastKillY = y
    score = round.score; kills = round.kills
    combo = round.combo; bestCombo = round.bestCombo
    if (comboBreaking) { comboBreak.stop(); comboValue.shake = 0; comboBreaking = false }
    showPopup(x, y, round.score - before, round.combo, golden)
    // Blasts, saber sweeps and one piercing Colt round ("pierce:<serial>") can multi-kill.
    var piercing = source.indexOf("pierce:") === 0
    var window = source === "saber" ? 250 : source === "blast" ? 40 : piercing ? 5000 : -1
    if (source === burstSource && now - burstLast <= window) burstCount++
    else burstCount = 1
    burstSource = source; burstLast = now
    if (burstCount >= 2) multiKillText.show(piercing ? (burstCount > 2 ? "COLLATERAL ×" + burstCount + "!" : "COLLATERAL!")
                                            : multiKillNames[Math.min(4, burstCount)])
    impact()
  }
  function breakCombo() {
    if (combo >= 2) { lostCombo = combo; comboBreaking = true; comboBreak.restart() }
    combo = 0
  }
  property int popupCursor: 0
  function showPopup(x, y, points, multiplier, golden) {
    popups.itemAt(popupCursor).start(x, y, points, multiplier, golden)
    popupCursor = (popupCursor + 1) % popups.count
  }
  // Time's up is bullet time: TIME!, the world slows to a crawl, and the
  // player keeps firing until a kill (FINAL KILL!) or lastShotSeconds pass.
  // A final kill scores at the combo held at the buzzer. The round is saved
  // and the results shown once bullet time and its linger are over.
  readonly property real lastShotSeconds: 4
  property bool lastShot: false
  property bool finalKill: false
  // Share of the bullet-time allowance left; drives the LAST SHOT bar.
  property real lastShotLeft: 0
  function beginLastShot() {
    if (lastShot || ending || finished) return
    lastShot = true
    secondsLeft = 0
    hitStop = 0
    finalPulse.stop(); halfTick.stop()
    slowmoSound.stop(); slowmoSound.play()
    timeCallout.show()
    slowDown.to = 0.2; slowDown.restart()
    lastShotLeft = 1; lastShotClock.restart()
  }
  NumberAnimation { id: slowDown; target: hunt; property: "timeScale"; duration: 220; easing.type: Easing.OutQuad }
  NumberAnimation {
    id: lastShotClock
    target: hunt; property: "lastShotLeft"; to: 0
    duration: hunt.lastShotSeconds * 1000
    // No kill in time: a short pause, then the results.
    onFinished: if (hunt.lastShot && !hunt.finalKill) hunt.endLastShot(500)
  }
  // Lets the rest of a rocket blast or saber sweep land after the first final kill.
  Timer { id: lastShotClose; interval: 120; onTriggered: hunt.endLastShot(1700) }
  function endLastShot(linger) {
    if (!lastShot) return
    lastShot = false
    ending = true
    // Linger on the kill even slower.
    slowDown.to = 0.1; slowDown.restart()
    lingerTimer.interval = linger; lingerTimer.restart()
  }
  Timer { id: lingerTimer; onTriggered: hunt.finishRound() }
  // Saves the round once; also used when it is left mid bullet time.
  function saveRound() {
    var record = Rules.finish(round, Math.max(Date.now(), round.deadline))
    if (!record) return false
    previousBest = arena.flyRecords.bests[round.weapon] || null
    personalBest = record.score > 0 && (!previousBest || record.score > previousBest.score)
    var weaponId = round.weapon || weapon
    medal = Rules.medal(weaponId, record.score)
    previousMedal = previousBest ? Rules.medal(weaponId, previousBest.score) : -1
    nextMedal = Rules.nextMedal(weaponId, record.score)
    arena.flyRecords.add(record)
    return true
  }
  function finishRound() {
    if (!saveRound()) return
    secondsLeft = 0
    lastShot = false; lastShotClock.stop(); lastShotClose.stop(); lingerTimer.stop(); slowDown.stop()
    ending = false; timeScale = 1; trauma = 0; hitStop = 0
    finished = true
    resultReveal.restart()
  }
  Component.onDestruction: if (!finished && (lastShot || ending)) saveRound()
  function restart() {
    // A round left in bullet time still counts.
    if (!finished && (lastShot || ending)) saveRound()
    arena.clearRoundEffects()
    round = Rules.fresh(Date.now(), weapon)
    score = 0; kills = 0; combo = 0; bestCombo = 0
    secondsLeft = Rules.roundSeconds; personalBest = false; previousBest = null
    finalPulse.stop(); edgeGlow.pulse = 0; halfTick.stop()
    comboBreaking = false; comboBreak.stop(); burstSource = ""; burstCount = 0
    multiKillText.opacity = 0
    for (var i = 0; i < flies.count; i++) flies.itemAt(i).reset()
    for (var j = 0; j < fragments.count; j++) fragments.itemAt(j).active = false
    for (var k = 0; k < popups.count; k++) popups.itemAt(k).stop()
    comboLeft = 0
    hitStop = 0; trauma = 0
    for (var d = 0; d < droplets.count; d++) droplets.itemAt(d).active = false
    resultReveal.stop(); shownScore = 0; revealed = false
    lastShotClock.stop(); lastShotClose.stop(); lingerTimer.stop(); slowDown.stop()
    lastShot = false; lastShotLeft = 0; ending = false; timeScale = 1; lastKillTime = 0; finalKill = false
    finalKillPop.stop(); finalKillMark.opacity = 0
    medal = -1; previousMedal = -1; nextMedal = null
    medalCoin.opacity = 0; medalCoin.shine = -1
    for (var w = 0; w < wings.count; w++) wings.itemAt(w).active = false
    for (var g = 0; g < coins.count; g++) coins.itemAt(g).active = false
    for (var p = 0; p < sparkles.count; p++) sparkles.itemAt(p).active = false
    for (var c = 0; c < confetti.count; c++) confetti.itemAt(c).active = false
    confettiFlying = false
    finished = false
    startCountdown()
  }
  Timer {
    interval: 50; running: !hunt.finished; repeat: true
    onTriggered: {
      // The combo clock stops at the buzzer, through bullet time.
      if (hunt.countingDown || hunt.lastShot || hunt.ending) return
      var now = Date.now()
      hunt.secondsLeft = Rules.remaining(hunt.round, now)
      if (hunt.combo > 0 && hunt.round.lastKill !== null && now - hunt.round.lastKill > Rules.comboWindow(hunt.round.combo)) hunt.breakCombo()
      if (now >= hunt.round.deadline) hunt.beginLastShot()
    }
  }
  // One preloaded voice also avoids stacking four identical sounds on a blast.
  RemoteSound {
    audio: hunt.arena.audio
    id: splatSound
    source: Qt.resolvedUrl("sounds/bug-splat.wav")
    volume: 0.67
  }

  // A bullet's path this step against every fly. Ordinary rounds stop in the
  // first fly; a piercing round (pierceSerial > 0) kills each fly on its path
  // and is not stopped, so it can line up more on later steps and bounces.
  function hitProjectile(x0, y0, x1, y1, radius, weapon, pierceSerial) {
    var dx = x1 - x0, dy = y1 - y0
    var lengthSquared = dx * dx + dy * dy
    if (!hunt.acceptHits()) return false
    if (pierceSerial > 0) {
      for (var p = 0; p < flies.count; p++) {
        var target = flies.itemAt(p)
        if (!target || !target.alive) continue
        var u = lengthSquared ? Math.max(0, Math.min(1, ((target.x - x0) * dx + (target.y - y0) * dy) / lengthSquared)) : 0
        var px = x0 + u * dx - target.x, py = y0 + u * dy - target.y
        if (px * px + py * py <= Math.pow(radius + 19, 2)) target.hit("pierce:" + pierceSerial, weapon, dx, dy)
      }
      return false
    }
    var nearest = null, nearestT = 2
    for (var i = 0; i < flies.count; i++) {
      var fly = flies.itemAt(i)
      if (!fly || !fly.alive) continue
      var t = lengthSquared ? Math.max(0, Math.min(1, ((fly.x - x0) * dx + (fly.y - y0) * dy) / lengthSquared)) : 0
      var ex = x0 + t * dx - fly.x, ey = y0 + t * dy - fly.y
      if (ex * ex + ey * ey <= Math.pow(radius + 19, 2) && t < nearestT) { nearest = fly; nearestT = t }
    }
    if (!nearest) return false
    nearest.hit("projectile", weapon, dx, dy)
    return true
  }

  function hitBlast(x, y, radius, weapon) {
    if (!hunt.acceptHits()) return
    for (var i = 0; i < flies.count; i++) {
      var fly = flies.itemAt(i)
      if (fly && fly.alive && Math.pow(fly.x - x, 2) + Math.pow(fly.y - y, 2) <= Math.pow(radius + 19, 2)) fly.hit("blast", weapon, fly.x - x, fly.y - y)
    }
    // The M20's shockwave flings the flies just outside it, spinning.
    if (weapon !== "bazooka") return
    for (var j = 0; j < flies.count; j++) {
      var near = flies.itemAt(j)
      if (!near || !near.alive) continue
      var ox = near.x - x, oy = near.y - y, distance = Math.sqrt(ox * ox + oy * oy)
      var reach = (radius + 19) * 2.2
      if (distance > reach) continue
      var push = 1 - distance / reach
      near.fling(ox / Math.max(1, distance), oy / Math.max(1, distance), 600 + 1100 * push)
    }
  }

  property int fragmentCursor: 0
  function hitSaber(previous, current) {
    if (!acceptHits()) return false
    var struck = false
    var angle = Math.atan2(current.tip.y - current.base.y, current.tip.x - current.base.x)
    // Spray follows the swing; a still blade sprays across itself.
    var swingX = current.tip.x - previous.tip.x, swingY = current.tip.y - previous.tip.y
    if (swingX * swingX + swingY * swingY < 1) { swingX = -Math.sin(angle); swingY = Math.cos(angle) }
    for (var i = 0; i < flies.count; i++) {
      var fly = flies.itemAt(i)
      if (!fly || !fly.alive || !Saber.hits(fly.x, fly.y, 25, previous, current)) continue
      var frame = Math.floor(wingTime * (28 + fly.index * 2)) % 8
      for (var side = -1; side <= 1; side += 2) {
        fragments.itemAt(fragmentCursor).start(fly.x, fly.y, angle, side, frame, fly.facingLeft, fly.golden)
        fragmentCursor = (fragmentCursor + 1) % fragments.count
      }
      fly.hit("saber", "lightsaber", swingX, swingY)
      struck = true
    }
    return struck
  }
  Repeater { id: fragments; model: 32; delegate: FlyFragment { transform: worldShake } }

  // A shot or blast sends the body tumbling along the hit (blasts fling it
  // hard), and every kill sheds both wings, which flutter down like leaves.
  property int wingCursor: 0
  function shatter(fly, source, dirX, dirY) {
    var length = Math.sqrt(dirX * dirX + dirY * dirY)
    var heading = length > 0.001 ? Math.atan2(dirY, dirX) : -Math.PI / 2
    if (source !== "saber") {
      var blast = source === "blast"
      var speed = blast ? 520 + Math.random() * 300 : 170 + Math.random() * 110
      var turn = (Math.random() < 0.5 ? -1 : 1) * (blast ? 650 + Math.random() * 500 : 220 + Math.random() * 280)
      fragments.itemAt(fragmentCursor).tumble(fly.x, fly.y, fly.frame(), fly.facingLeft, fly.golden,
        Math.cos(heading) * speed, Math.sin(heading) * speed - (blast ? 240 : 150), turn)
      fragmentCursor = (fragmentCursor + 1) % fragments.count
    }
    for (var side = -1; side <= 1; side += 2) {
      wings.itemAt(wingCursor).start(fly.x + side * 9, fly.y - 14, side, heading, fly.golden)
      wingCursor = (wingCursor + 1) % wings.count
    }
  }
  Repeater {
    id: wings
    model: 24
    delegate: Rectangle {
      property bool active: false
      property real vx: 0
      property real vy: 0
      property real age: 0
      property real phase: 0
      property real tilt: 0
      visible: active
      transform: worldShake
      width: 20; height: 9; radius: height / 2
      color: golden ? Qt.rgba(1, 0.86, 0.45, 0.55) : Qt.rgba(0.86, 0.93, 0.97, 0.5)
      border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.7)
      property bool golden: false
      opacity: Math.max(0, Math.min(1, (1.3 - age) / 0.35))
      function start(px, py, side, heading, isGolden) {
        x = px - width / 2; y = py - height / 2; age = 0; golden = !!isGolden
        vx = side * (70 + Math.random() * 90) + Math.cos(heading) * 60
        vy = -(80 + Math.random() * 90) + Math.sin(heading) * 40
        phase = Math.random() * 6.28; tilt = side * (20 + Math.random() * 30)
        active = true
      }
      function advance(dt) {
        if (!active) return
        age += dt
        if (age >= 1.3) { active = false; return }
        // Heavy drag, light gravity and a sideways sway: they float, not fall.
        vx *= Math.exp(-dt * 2.6); vy = vy * Math.exp(-dt * 2.6) + 260 * dt
        x += (vx + Math.sin(age * 9 + phase) * 45) * dt; y += vy * dt
        rotation = tilt + 40 * Math.sin(age * 13 + phase)
      }
    }
  }

  // Golden flies: rare, fast, worth ×3, and gone after a few seconds. One at a time.
  readonly property real goldenChance: 0.05
  readonly property real goldenLife: 5
  function goldenAllowed() {
    if (ending || countingDown || briefing || finished) return false
    if (Date.now() - (round.deadline - Rules.roundSeconds * 1000) < 4000 || secondsLeft <= 3) return false
    for (var i = 0; i < flies.count; i++) if (flies.itemAt(i).golden && flies.itemAt(i).alive) return false
    return true
  }
  RemoteSound { id: goldenChime; audio: hunt.arena.audio; source: Qt.resolvedUrl("sounds/golden-chime.wav"); volume: 0.43 }
  RemoteSound { id: goldenKill; audio: hunt.arena.audio; source: Qt.resolvedUrl("sounds/golden-kill.wav"); volume: 0.5 }
  RemoteSound { id: slowmoSound; audio: hunt.arena.audio; source: Qt.resolvedUrl("sounds/slowmo.wav"); volume: 0.6 }
  RemoteSound { id: medalThud; audio: hunt.arena.audio; source: Qt.resolvedUrl("sounds/medal-thud.wav"); volume: 0.6 }
  // A ding a step higher for each medal the results track passes.
  RemoteSound { id: medalPass0; audio: hunt.arena.audio; source: Qt.resolvedUrl("sounds/medal-pass-1.wav"); volume: 0.45 }
  RemoteSound { id: medalPass1; audio: hunt.arena.audio; source: Qt.resolvedUrl("sounds/medal-pass-2.wav"); volume: 0.45 }
  RemoteSound { id: medalPass2; audio: hunt.arena.audio; source: Qt.resolvedUrl("sounds/medal-pass-3.wav"); volume: 0.45 }
  RemoteSound { id: medalPass3; audio: hunt.arena.audio; source: Qt.resolvedUrl("sounds/medal-pass-4.wav"); volume: 0.45 }
  function medalPassed(rank) {
    var ding = [medalPass0, medalPass1, medalPass2, medalPass3][rank]
    if (ding) { ding.stop(); ding.play() }
  }
  // A golden kill: coins burst out, the screen flashes gold, the hit lands harder.
  property int coinCursor: 0
  function goldenBurst(px, py) {
    goldenKill.stop(); goldenKill.play()
    for (var i = 0; i < 22; i++) {
      coins.itemAt(coinCursor).start(px, py)
      coinCursor = (coinCursor + 1) % coins.count
    }
    goldFlash.restart()
    hitStop = Math.max(hitStop, 0.13)
    trauma = Math.min(1, trauma + 0.35)
  }
  Repeater {
    id: coins
    model: 44
    delegate: Rectangle {
      property bool active: false
      property real vx: 0
      property real vy: 0
      property real age: 0
      property real flip: 0
      property real flipRate: 0
      readonly property real size: 9 + index % 4 * 1.5
      visible: active
      transform: worldShake
      z: 3
      // Edge-on and face-on in turn, like a spinning coin.
      width: size * Math.max(0.18, Math.abs(Math.cos(flip))); height: size; radius: height / 2
      color: Math.cos(flip) > 0 ? hunt.gold : "#e0a521"
      border.width: 1; border.color: "#9c700e"
      opacity: Math.max(0, Math.min(1, (1.2 - age) / 0.3))
      property real cx: 0
      property real cy: 0
      x: cx - width / 2; y: cy - height / 2
      function start(px, py) {
        cx = px; cy = py; age = 0; flip = Math.random() * 3
        var heading = -Math.PI / 2 + (Math.random() - 0.5) * 2.4, speed = 260 + Math.random() * 380
        vx = Math.cos(heading) * speed; vy = Math.sin(heading) * speed
        flipRate = 10 + Math.random() * 12
        active = true
      }
      function advance(dt) {
        if (!active) return
        age += dt
        if (age >= 1.2) { active = false; return }
        cx += vx * dt; cy += vy * dt
        vx *= Math.exp(-dt * 1.2); vy += 1100 * dt
        flip += flipRate * dt
      }
    }
  }
  // Gold dust trailing a golden fly.
  property int sparkleCursor: 0
  function sparkle(px, py) {
    sparkles.itemAt(sparkleCursor).start(px, py)
    sparkleCursor = (sparkleCursor + 1) % sparkles.count
  }
  Repeater {
    id: sparkles
    model: 40
    delegate: Rectangle {
      property bool active: false
      property real age: 0
      property real life: 0.6
      property real vy: 0
      visible: active
      transform: worldShake
      width: 3 + index % 4 * 1.5; height: width
      rotation: 45
      color: index % 3 ? hunt.gold : "#fff4c8"
      opacity: Math.max(0, 1 - age / life)
      scale: 1 - 0.6 * age / life
      function start(px, py) {
        x = px - width / 2 + (Math.random() - 0.5) * 22; y = py - height / 2 + (Math.random() - 0.5) * 18
        age = 0; life = 0.4 + Math.random() * 0.35; vy = 20 + Math.random() * 40
        active = true
      }
      function advance(dt) {
        if (!active) return
        age += dt
        if (age >= life) { active = false; return }
        y += vy * dt
      }
    }
  }
  Rectangle {
    id: goldFlashLayer
    anchors.fill: parent
    z: 1
    color: hunt.gold
    opacity: 0
    visible: opacity > 0
    NumberAnimation { id: goldFlash; target: goldFlashLayer; property: "opacity"; from: 0.2; to: 0; duration: 320; easing.type: Easing.OutQuad }
  }

  // Drops sprayed along the hit direction; a fixed pool, recycled round-robin.
  property int dropletCursor: 0
  function spray(px, py, dirX, dirY, count) {
    var length = Math.sqrt(dirX * dirX + dirY * dirY)
    var heading = length > 0.001 ? Math.atan2(dirY, dirX) : -Math.PI / 2
    for (var i = 0; i < count; i++) {
      droplets.itemAt(dropletCursor).start(px, py, heading + (Math.random() - 0.5) * 1.1, 260 + Math.random() * 380)
      dropletCursor = (dropletCursor + 1) % droplets.count
    }
  }
  Repeater {
    id: droplets
    model: 64
    delegate: Rectangle {
      property bool active: false
      property real vx: 0
      property real vy: 0
      property real age: 0
      property real life: 0.6
      visible: active
      transform: worldShake
      width: 4 + (index % 4) * 1.5; height: width; radius: width / 2
      color: hunt.arena.accent
      opacity: Math.max(0, 1 - age / life)
      function start(px, py, heading, speed) {
        x = px - width / 2; y = py - height / 2; age = 0
        life = 0.45 + Math.random() * 0.3
        vx = Math.cos(heading) * speed; vy = Math.sin(heading) * speed - 60
        active = true
      }
      function advance(dt) {
        if (!active) return
        age += dt
        if (age >= life) { active = false; return }
        x += vx * dt; y += vy * dt
        vx *= Math.exp(-dt * 3); vy += 900 * dt
      }
    }
  }

  // One shared movement callback; four persistent sprites and four small splats.
  FrameAnimation {
    running: hunt.visible && hunt.arena.armed && !hunt.finished
    onTriggered: {
      var dt = Math.min(frameTime, 0.05) * hunt.timeScale
      hunt.shakeTime += dt
      hunt.trauma = Math.max(0, hunt.trauma - dt * 2.2)
      if (hunt.hitStop > 0) { hunt.hitStop = Math.max(0, hunt.hitStop - dt); return }
      hunt.wingTime += dt
      hunt.comboLeft = hunt.combo > 0 && hunt.round.lastKill !== null
        ? Math.max(0, 1 - (Math.min(Date.now(), hunt.round.deadline) - hunt.round.lastKill) / Rules.comboWindow(hunt.round.combo)) : 0
      for (var j = 0; j < fragments.count; j++) fragments.itemAt(j).advance(dt)
      for (var k = 0; k < droplets.count; k++) droplets.itemAt(k).advance(dt)
      for (var w = 0; w < wings.count; w++) wings.itemAt(w).advance(dt)
      for (var g = 0; g < coins.count; g++) coins.itemAt(g).advance(dt)
      for (var p = 0; p < sparkles.count; p++) sparkles.itemAt(p).advance(dt)
      if (!hunt.ending && !hunt.acceptHits()) return
      for (var i = 0; i < flies.count; i++) flies.itemAt(i).advance(dt)
    }
  }

  Repeater {
    id: flies
    model: hunt.flyCount
    delegate: Item {
      id: fly
      required property int index
      property bool alive: false
      property real vx: 0
      property real vy: 0
      property real destinationX: 0
      property real destinationY: 0
      property real steeringTime: 0
      property real respawnTime: 0
      property real splatX: 0
      property real splatY: 0
      property bool facingLeft: false
      property real speed: 100
      property real baseSpeed: 100
      // True while flying in from off screen; the edge clamp waits until it is inside.
      property bool entering: false
      property real splatScale: 1
      property bool golden: false
      property real goldenAge: 0
      property real sparkleClock: 0
      // A golden fly that outlived goldenLife heads off screen and is gone.
      property bool leaving: false
      // Flung by a rocket's shockwave: it tumbles out of control for `stun` seconds.
      property real stun: 0
      property real wobble: 0
      property real wobbleRate: 0
      function fling(nx, ny, speed) {
        vx = nx * speed; vy = ny * speed - 120
        stun = 0.55; wobbleRate = (Math.random() < 0.5 ? -1 : 1) * (700 + Math.random() * 500)
      }
      transform: worldShake

      function frame() { return Math.floor(hunt.wingTime * (28 + index * 2)) % 8 }
      function reset() {
        alive = false; respawnTime = index * 0.12; golden = false; leaving = false; stun = 0; wobble = 0
        splatFade.stop(); splat.opacity = 0
      }
      function randomX() { return Math.min(hunt.width / 2, 65) + Math.random() * Math.max(0, hunt.width - 130) }
      function randomY() { return Math.min(hunt.height / 2, 65) + Math.random() * Math.max(0, hunt.height - 130) }
      function chooseDestination() {
        destinationX = randomX(); destinationY = randomY()
        steeringTime = 0.7 + Math.random() * 1.5
        speed = baseSpeed * (0.85 + Math.random() * 0.3)
      }
      function spawn() {
        // Arrive from just past a random screen edge instead of appearing in place.
        var edge = Math.floor(Math.random() * 4)
        x = edge === 0 ? -50 : edge === 1 ? hunt.width + 50 : randomX()
        y = edge === 2 ? -50 : edge === 3 ? hunt.height + 50 : randomY()
        entering = true
        // Keep a mix of speeds on screen; reroll within each tier on respawn.
        var minimum = [90, 180, 340, 560]
        var spread = [80, 130, 190, 240]
        baseSpeed = minimum[index] + Math.random() * spread[index]
        leaving = false
        golden = hunt.goldenAllowed() && Math.random() < hunt.goldenChance
        if (golden) {
          goldenAge = 0
          baseSpeed = 520 + Math.random() * 200
          goldenChime.stop(); goldenChime.play()
        }
        chooseDestination()
        var dx = destinationX - x, dy = destinationY - y, distance = Math.max(1, Math.sqrt(dx * dx + dy * dy))
        vx = dx / distance * speed; vy = dy / distance * speed
        steeringTime = Math.max(steeringTime, Math.min(2.5, distance / speed))
        alive = true
      }
      function advance(dt) {
        if (!alive) {
          respawnTime -= dt
          if (respawnTime <= 0) spawn()
          return
        }
        if (stun > 0) {
          // No steering: drag, a bounce off the screen edges, and a spin that unwinds.
          stun -= dt
          vx *= Math.exp(-dt * 3.2); vy *= Math.exp(-dt * 3.2)
          x += vx * dt; y += vy * dt
          if ((x < 35 && vx < 0) || (x > hunt.width - 35 && vx > 0)) vx = -vx * 0.6
          if ((y < 45 && vy < 0) || (y > hunt.height - 35 && vy > 0)) vy = -vy * 0.6
          x = Math.max(35, Math.min(hunt.width - 35, x)); y = Math.max(45, Math.min(hunt.height - 35, y))
          wobble += wobbleRate * dt
          if (stun <= 0) { entering = false; chooseDestination() }
          return
        }
        if (wobble !== 0) {
          var unwound = wobble % 360
          wobble = Math.abs(unwound) < 8 ? 0 : unwound * Math.exp(-dt * 10)
        }
        if (golden) {
          goldenAge += dt
          sparkleClock += dt
          while (sparkleClock > 0.03) { sparkleClock -= 0.03; hunt.sparkle(x, y - 10) }
          if (goldenAge > hunt.goldenLife && !leaving) {
            // Out past the nearest side edge.
            leaving = true
            destinationX = x < hunt.width / 2 ? -120 : hunt.width + 120
            destinationY = y; steeringTime = 99
          }
          if (leaving && (x < -60 || x > hunt.width + 60)) {
            alive = false; golden = false; leaving = false
            respawnTime = 0.4
            return
          }
        }
        steeringTime -= dt
        var dx = destinationX - x, dy = destinationY - y
        var distance = Math.sqrt(dx * dx + dy * dy)
        if (!leaving && (steeringTime <= 0 || distance < 25)) { chooseDestination(); dx = destinationX - x; dy = destinationY - y; distance = Math.sqrt(dx * dx + dy * dy) }
        var blend = 1 - Math.exp(-dt * (index >= 2 ? 7 : 4))
        vx += (dx / Math.max(1, distance) * speed - vx) * blend
        vy += (dy / Math.max(1, distance) * speed - vy) * blend
        x += vx * dt; y += vy * dt
        var minX = 35, maxX = Math.max(35, hunt.width - 35), minY = 45, maxY = Math.max(45, hunt.height - 35)
        if (entering && x >= minX && x <= maxX && y >= minY && y <= maxY) entering = false
        if (!entering && !leaving) {
          x = Math.max(minX, Math.min(maxX, x))
          y = Math.max(minY, Math.min(maxY, y))
        }
        if (vx < -12) facingLeft = true
        else if (vx > 12) facingLeft = false
      }
      function hit(source, weapon, dirX, dirY) {
        if (!alive || !hunt.acceptHits()) return
        alive = false
        splatSound.stop()
        splatSound.play()
        respawnTime = 0.25 + Math.random() * 0.30
        var wasGolden = golden
        hunt.recordKill(x, y, source, weapon, wasGolden)
        hunt.shatter(fly, source, dirX || 0, dirY || 0)
        golden = false; leaving = false
        // Splats and sprays grow with the combo.
        splatScale = 0.85 + 0.15 * hunt.combo
        splatX = x; splatY = y
        splat.gold = wasGolden
        splatFade.stop(); splat.opacity = 1; splat.requestPaint(); splatFade.start()
        hunt.spray(x, y, dirX || 0, dirY || 0, 4 + 2 * hunt.combo)
        if (wasGolden) hunt.goldenBurst(x, y)
      }
      Component.onCompleted: respawnTime = index * 0.12

      // A warm halo that breathes behind a golden fly.
      Canvas {
        visible: fly.alive && fly.golden
        x: -49; y: -59; width: 90; height: 90
        scale: 1 + 0.12 * Math.sin(hunt.wingTime * 9)
        onPaint: {
          var c = getContext("2d"), glow = c.createRadialGradient(45, 45, 0, 45, 45, 45)
          glow.addColorStop(0, "rgba(255, 214, 90, 0.55)"); glow.addColorStop(1, "rgba(255, 200, 60, 0)")
          c.fillStyle = glow; c.fillRect(0, 0, 90, 90)
        }
      }
      AnimatedSprite {
        x: -44; y: -54
        layer.enabled: fly.golden
        layer.effect: MultiEffect { colorization: 0.85; colorizationColor: "#ffc02e"; brightness: 0.2 }
        width: 80; height: 80
        source: Qt.resolvedUrl("assets/fly-spritesheet.png")
        // Source is 1774 x 887: four columns, two rows, with spare edge pixels.
        frameWidth: 443; frameHeight: 443; frameCount: 8
        frameRate: 28 + fly.index * 2
        interpolate: true
        // Avoid intermittent blank frames from automatic sprite advancement.
        // Drive valid frames from the shared flight clock instead.
        paused: true
        currentFrame: Math.floor(hunt.wingTime * frameRate) % frameCount
        running: fly.alive && hunt.visible
        visible: fly.alive
        rotation: fly.wobble
        opacity: 1
        transform: Scale { origin.x: 44; origin.y: 54; xScale: fly.facingLeft ? -1 : 1 }
      }

      Canvas {
        id: splat
        // Keep the mark at the impact point while this slot respawns elsewhere.
        x: fly.splatX - fly.x - 48; y: fly.splatY - fly.y - 48
        width: 96; height: 96
        scale: fly.splatScale
        opacity: 0
        visible: opacity > 0
        property bool gold: false
        readonly property color ink: gold ? hunt.gold : hunt.arena.accent
        onInkChanged: if (visible) requestPaint()
        onPaint: {
          var c = getContext("2d")
          c.reset(); c.clearRect(0, 0, width, height)
          c.fillStyle = ink
          var points = []
          for (var n = 0; n < 24; n++) {
            var a0 = n * Math.PI / 12
            var r0 = n % 2 ? 13 + (n % 5) : 25 + (n % 7)
            points.push({x: 48 + Math.cos(a0) * r0, y: 48 + Math.sin(a0) * r0})
          }
          c.beginPath()
          c.moveTo((points[23].x + points[0].x) / 2, (points[23].y + points[0].y) / 2)
          for (var i = 0; i < 24; i++) {
            var next = points[(i + 1) % 24]
            c.quadraticCurveTo(points[i].x, points[i].y, (points[i].x + next.x) / 2, (points[i].y + next.y) / 2)
          }
          c.closePath(); c.fill()
          for (var j = 0; j < 7; j++) {
            var a = j * 2.399 + fly.index
            c.beginPath(); c.arc(48 + Math.cos(a) * 39, 48 + Math.sin(a) * 37, 2 + j % 3, 0, Math.PI * 2); c.fill()
          }
        }
      }
      SequentialAnimation {
        id: splatFade
        PauseAnimation { duration: 1400 }
        NumberAnimation { target: splat; property: "opacity"; to: 0; duration: 800 }
      }
    }
  }

  // HUD and results use the active theme, like the weapon case.
  readonly property var ui: hunt.arena
  component HudValue: Row {
    property string label
    property string value
    property color valueColor: hunt.ui.foreground
    spacing: 7
    Text { anchors.baseline: valueText.baseline; text: parent.label; color: hunt.ui.muted; font.family: hunt.ui.fontFamily; font.pixelSize: 13; font.bold: true }
    Text { id: valueText; text: parent.value; color: parent.valueColor; font.family: hunt.ui.fontFamily; font.pixelSize: 22; font.bold: true }
  }
  Rectangle {
    id: hudBox
    anchors.top: parent.top; anchors.topMargin: 48
    anchors.horizontalCenter: parent.horizontalCenter
    width: hud.implicitWidth + 44; height: 58; radius: hunt.ui.cornerRadius
    color: hunt.ui.tint(hunt.ui.background, 0.88)
    border.width: 1; border.color: hunt.ui.tint(hunt.ui.accent, 0.55)
    visible: !hunt.finished && !hunt.briefing
    Row {
      id: hud; anchors.centerIn: parent; spacing: 26
      HudValue {
        id: timeValue
        label: "TIME"; value: hunt.secondsLeft + "s"
        valueColor: hunt.secondsLeft <= 10 ? hunt.ui.urgent : hunt.ui.foreground
        SequentialAnimation {
          id: timePop
          NumberAnimation { target: timeValue; property: "scale"; to: 1.3; duration: 70; easing.type: Easing.OutQuad }
          NumberAnimation { target: timeValue; property: "scale"; to: 1; duration: 260; easing.type: Easing.OutBack }
        }
      }
      HudValue { label: "BEST"; value: hunt.arena.flyRecords.bests[hunt.weapon] ? hunt.arena.flyRecords.bests[hunt.weapon].score : "—"; valueColor: hunt.ui.muted }
      HudValue {
        id: scoreValue
        label: "SCORE"; value: Math.round(hunt.hudScore)
        valueColor: scorePunch.running ? hunt.ui.accent : hunt.ui.foreground
        SequentialAnimation {
          id: scorePunch
          NumberAnimation { target: scoreValue; property: "scale"; to: 1.28; duration: 60; easing.type: Easing.OutQuad }
          NumberAnimation { target: scoreValue; property: "scale"; to: 1; duration: 240; easing.type: Easing.OutBack }
        }
      }
      HudValue { label: "FLIES"; value: hunt.kills }
      HudValue {
        id: comboValue
        property real shake: 0
        label: "COMBO"
        value: "×" + (hunt.comboBreaking ? hunt.lostCombo : Math.max(1, hunt.combo))
        valueColor: hunt.comboBreaking ? hunt.ui.muted : hunt.combo > 1 ? hunt.ui.accent : hunt.ui.foreground
        opacity: hunt.comboBreaking ? 0.7 : 1
        transform: Translate { x: comboValue.shake }
        // A short shake and grey-out when a combo runs out.
        SequentialAnimation {
          id: comboBreak
          NumberAnimation { target: comboValue; property: "shake"; to: -7; duration: 40 }
          NumberAnimation { target: comboValue; property: "shake"; to: 6; duration: 60 }
          NumberAnimation { target: comboValue; property: "shake"; to: -4; duration: 60 }
          NumberAnimation { target: comboValue; property: "shake"; to: 2; duration: 60 }
          NumberAnimation { target: comboValue; property: "shake"; to: 0; duration: 50 }
          PauseAnimation { duration: 450 }
          ScriptAction { script: hunt.comboBreaking = false }
        }
        SequentialAnimation {
          id: comboPunch
          NumberAnimation { target: comboValue; property: "scale"; to: 1.35; duration: 70; easing.type: Easing.OutQuad }
          NumberAnimation { target: comboValue; property: "scale"; to: 1; duration: 220; easing.type: Easing.OutBack }
        }
        Connections {
          target: hunt
          function onComboChanged() { if (hunt.combo > 1) comboPunch.restart() }
        }
      }
    }
  }
  // Drains from both ends over the combo window; kill again before it empties.
  Rectangle {
    anchors.top: hudBox.bottom; anchors.topMargin: 6
    anchors.horizontalCenter: hudBox.horizontalCenter
    width: hudBox.width; height: 4; radius: 2
    // Flashes the urgent colour once when the combo breaks.
    color: hunt.comboBreaking ? hunt.ui.tint(hunt.ui.urgent, 0.7) : hunt.ui.tint(hunt.ui.foreground, 0.12)
    Behavior on color { ColorAnimation { duration: 120 } }
    visible: hudBox.visible && (hunt.combo > 0 || hunt.comboBreaking)
    Rectangle {
      anchors.centerIn: parent
      width: parent.width * hunt.comboLeft; height: parent.height; radius: parent.radius
      color: hunt.ui.accent
    }
  }

  // "DOUBLE!" etc. under the HUD when one blast or sweep kills several flies.
  Text {
    id: multiKillText
    anchors.horizontalCenter: hudBox.horizontalCenter
    y: hudBox.y + hudBox.height + 26
    z: 6
    opacity: 0
    color: hunt.ui.accent
    style: Text.Outline; styleColor: hunt.ui.tint(hunt.ui.background, 0.85)
    font.family: hunt.ui.fontFamily; font.pixelSize: 34; font.bold: true
    function show(label) { text = label; multiKillPop.restart() }
    SequentialAnimation {
      id: multiKillPop
      PropertyAction { target: multiKillText; property: "opacity"; value: 1 }
      NumberAnimation { target: multiKillText; property: "scale"; from: 0.6; to: 1.25; duration: 90; easing.type: Easing.OutQuad }
      NumberAnimation { target: multiKillText; property: "scale"; to: 1; duration: 160 }
      PauseAnimation { duration: 550 }
      NumberAnimation { target: multiKillText; property: "opacity"; to: 0; duration: 350 }
    }
  }

  Text {
    id: countdownText
    anchors.centerIn: parent
    z: 7
    visible: hunt.countingDown || countdownPop.running
    text: hunt.countdownStep > 0 ? hunt.countdownStep : "GO!"
    color: hunt.countdownStep > 0 ? hunt.ui.foreground : hunt.ui.accent
    style: Text.Outline; styleColor: hunt.ui.tint(hunt.ui.background, 0.85)
    font.family: hunt.ui.fontFamily; font.pixelSize: 120; font.bold: true
    function pop() { countdownPop.restart() }
    ParallelAnimation {
      id: countdownPop
      NumberAnimation { target: countdownText; property: "scale"; from: 1.6; to: 1; duration: 260; easing.type: Easing.OutBack }
      SequentialAnimation {
        PropertyAction { target: countdownText; property: "opacity"; value: 1 }
        PauseAnimation { duration: hunt.countdownStep > 0 ? 330 : 380 }
        NumberAnimation { target: countdownText; property: "opacity"; to: 0; duration: 260 }
      }
    }
  }

  // Floating "+points ×combo" at each kill.
  Repeater {
    id: popups
    model: 12
    delegate: Item {
      id: popup
      property int points: 0
      property int multiplier: 1
      property bool golden: false
      property real startY: 0
      visible: false
      z: 5
      function start(px, py, gained, combo, isGolden) {
        points = gained; multiplier = combo; golden = !!isGolden
        x = px; startY = py - 34
        rise.restart()
      }
      function stop() { rise.stop(); visible = false }
      Row {
        x: -width / 2; y: -height / 2
        spacing: 5
        Text {
          text: "+" + popup.points
          color: popup.golden ? hunt.gold : hunt.ui.accent
          style: Text.Outline; styleColor: hunt.ui.tint(hunt.ui.background, 0.85)
          font.family: hunt.ui.fontFamily; font.pixelSize: 20 + popup.multiplier * 3; font.bold: true
        }
        Text {
          visible: popup.multiplier > 1 || popup.golden
          anchors.baseline: parent.children[0].baseline
          text: popup.golden ? "GOLD ×" + Rules.goldenValue : "×" + popup.multiplier
          color: popup.golden ? hunt.gold : hunt.ui.foreground
          style: Text.Outline; styleColor: hunt.ui.tint(hunt.ui.background, 0.85)
          font.family: hunt.ui.fontFamily; font.pixelSize: 15; font.bold: true
        }
      }
      ParallelAnimation {
        id: rise
        onStarted: { popup.opacity = 1; popup.visible = true }
        onFinished: popup.visible = false
        NumberAnimation { target: popup; property: "y"; from: popup.startY; to: popup.startY - 60; duration: 950; easing.type: Easing.OutCubic }
        SequentialAnimation {
          NumberAnimation { target: popup; property: "scale"; from: 0.5; to: 1.2; duration: 90; easing.type: Easing.OutQuad }
          NumberAnimation { target: popup; property: "scale"; to: 1; duration: 160 }
        }
        SequentialAnimation {
          PauseAnimation { duration: 500 }
          NumberAnimation { target: popup; property: "opacity"; to: 0; duration: 450 }
        }
      }
    }
  }
  Rectangle {
    anchors.fill: parent; color: hunt.ui.tint(hunt.ui.background, 0.78); visible: hunt.finished
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
    Rectangle {
      anchors.centerIn: parent; width: Math.min(460, parent.width - 32)
      height: results.implicitHeight + 48; radius: hunt.ui.cornerRadius
      color: hunt.ui.tint(hunt.ui.background, 0.96)
      border.width: 2; border.color: hunt.ui.accent
      Column {
        id: results; anchors.centerIn: parent; width: parent.width - 48; spacing: 18
        Text {
          id: resultTitle
          width: parent.width; horizontalAlignment: Text.AlignHCenter
          text: hunt.revealed && hunt.personalBest ? "NEW PERSONAL BEST!" : "TIME’S UP!"
          color: hunt.ui.accent; font.family: hunt.ui.fontFamily; font.pixelSize: 24; font.bold: true
        }
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: Math.round(hunt.shownScore) + " points"; color: hunt.ui.foreground; font.family: hunt.ui.fontFamily; font.pixelSize: 36; font.bold: true }
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: hunt.kills + (hunt.kills === 1 ? " fly" : " flies"); color: hunt.ui.tint(hunt.ui.foreground, 0.85); font.family: hunt.ui.fontFamily; font.pixelSize: 18 }
        // The round on a track from 0 to platinum: the fill follows the count-up,
        // the medal coins above light up as it passes them, and the previous
        // best sits underneath.
        Item {
          id: timeline
          readonly property var ladder: Rules.medalScores[hunt.round.weapon || hunt.weapon] || null
          readonly property real bestScore: hunt.previousBest ? hunt.previousBest.score : -1
          readonly property real highest: ladder ? Math.max(ladder[3], bestScore, hunt.score) : 1
          // Room past platinum when a score goes beyond it.
          readonly property real span: ladder && highest > ladder[3] ? highest * 1.05 : highest
          function at(value) { return track.x + track.width * Math.max(0, Math.min(1, value / span)) }
          visible: !!ladder
          width: parent.width; height: 60
          Rectangle {
            id: track
            x: 10; y: 26; width: parent.width - 20; height: 8; radius: 4
            color: hunt.ui.tint(hunt.ui.foreground, 0.12)
            Rectangle {
              width: Math.max(height, parent.width * Math.min(1, hunt.shownScore / timeline.span))
              visible: hunt.shownScore > 0
              height: parent.height; radius: parent.radius
              color: hunt.ui.accent
            }
          }
          Repeater {
            model: timeline.ladder || []
            delegate: Item {
              id: medalStop
              required property int index
              required property var modelData
              readonly property bool reached: hunt.shownScore >= modelData
              x: timeline.at(modelData); y: 0
              onReachedChanged: if (reached && hunt.finished) hunt.medalPassed(index)
              Rectangle { x: -0.5; y: 18; width: 1; height: 8; color: hunt.ui.tint(hunt.ui.foreground, medalStop.reached ? 0.5 : 0.2) }
              Medal {
                x: -8; y: 0; width: 16; height: 16
                rank: medalStop.index
                opacity: medalStop.reached ? 1 : 0.3
                scale: medalStop.reached ? 1.15 : 0.85
                Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 3 } }
                Behavior on opacity { NumberAnimation { duration: 120 } }
              }
            }
          }
          Item {
            id: bestMark
            readonly property bool beaten: hunt.shownScore > timeline.bestScore
            visible: timeline.bestScore >= 0
            x: timeline.at(timeline.bestScore); y: track.y + track.height + 3
            Canvas {
              x: -5; y: 0; width: 10; height: 7
              readonly property color ink: bestMark.beaten ? hunt.ui.accent : hunt.ui.muted
              onInkChanged: requestPaint()
              onPaint: {
                var c = getContext("2d"); c.reset()
                c.beginPath(); c.moveTo(5, 0); c.lineTo(10, 7); c.lineTo(0, 7); c.closePath()
                c.fillStyle = ink; c.fill()
              }
            }
            Text {
              anchors.horizontalCenter: parent.left
              y: 8
              text: "BEST"
              color: bestMark.beaten ? hunt.ui.accent : hunt.ui.muted
              font.family: hunt.ui.fontFamily; font.pixelSize: 10; font.bold: true
            }
          }
        }
        // The medal slams in once the score has counted up, with the next one to aim for.
        Item {
          width: parent.width; height: 56
          Row {
            anchors.centerIn: parent; spacing: 14
            Medal { id: medalCoin; rank: Math.max(0, hunt.medal); visible: hunt.medal >= 0; width: 52; height: 52; opacity: 0 }
            Column {
              anchors.verticalCenter: parent.verticalCenter
              opacity: hunt.medal >= 0 ? medalCoin.opacity : hunt.revealed ? 1 : 0
              Text {
                visible: hunt.medal >= 0
                text: hunt.medal < 0 ? "" : (hunt.medal > hunt.previousMedal ? "NEW " : "") + Rules.medalNames[hunt.medal].toUpperCase() + " MEDAL"
                color: medalCoin.faces[Math.max(0, hunt.medal)]
                font.family: hunt.ui.fontFamily; font.pixelSize: 20; font.bold: true
              }
              Text {
                text: hunt.nextMedal ? hunt.nextMedal.name + " at " + hunt.nextMedal.score : "Top medal with this weapon"
                color: hunt.ui.muted; font.family: hunt.ui.fontFamily; font.pixelSize: 14
              }
            }
          }
        }
        // How this round compares with the weapon's previous best.
        Text {
          id: verdict
          width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
          opacity: 0
          readonly property string weaponName: hunt.arena.weaponNames([hunt.round.weapon || hunt.weapon])
          text: !hunt.previousBest ? "First completed hunt with the " + weaponName
            : hunt.personalBest ? "+" + (hunt.score - hunt.previousBest.score) + " over your " + weaponName + " best of " + hunt.previousBest.score
            : (hunt.previousBest.score - hunt.score) + " short of your " + weaponName + " best of " + hunt.previousBest.score
          color: hunt.personalBest ? hunt.ui.accent : hunt.ui.muted
          font.family: hunt.ui.fontFamily; font.pixelSize: 15; font.bold: hunt.personalBest
        }
        Text { width: parent.width; visible: text.length > 0; wrapMode: Text.WordWrap; text: hunt.arena.flyRecords.error; color: hunt.ui.urgent; font.family: hunt.ui.fontFamily }
        // Hover like the weapon case: an outline and the hover sound.
        Rectangle {
          width: parent.width; height: 46; radius: hunt.ui.cornerRadius; color: againHover.containsMouse ? Qt.lighter(hunt.ui.accent, 1.12) : hunt.ui.accent
          border.width: 2; border.color: againHover.containsMouse ? hunt.ui.foreground : hunt.ui.accent
          Text { anchors.centerIn: parent; text: "Play again"; color: hunt.ui.background; font.family: hunt.ui.fontFamily; font.pixelSize: 18; font.bold: true }
          MouseArea { id: againHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: hunt.playMenuHover(); onClicked: hunt.restart() }
        }
        Rectangle {
          width: parent.width; height: 40; radius: hunt.ui.cornerRadius
          color: closeHover.containsMouse ? hunt.ui.tint(hunt.ui.accent, 0.16) : hunt.ui.tint(hunt.ui.foreground, 0.06)
          border.width: 1; border.color: closeHover.containsMouse ? hunt.ui.accent : hunt.ui.tint(hunt.ui.foreground, 0.18)
          Text { anchors.centerIn: parent; text: "Close · Esc"; color: hunt.ui.foreground; font.family: hunt.ui.fontFamily; font.pixelSize: 16 }
          MouseArea { id: closeHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: hunt.playMenuHover(); onClicked: hunt.arena.holster() }
        }
      }
    }
  }

  // Results: the score counts up, then the comparison appears; a new best
  // bursts confetti with a fanfare.
  property real shownScore: 0
  property bool revealed: false
  SequentialAnimation {
    id: resultReveal
    ScriptAction { script: { hunt.shownScore = 0; hunt.revealed = false; verdict.opacity = 0; medalCoin.opacity = 0; medalCoin.shine = -1 } }
    PauseAnimation { duration: 250 }
    NumberAnimation { target: hunt; property: "shownScore"; from: 0; to: hunt.score; duration: Math.min(1900, 700 + hunt.score / 25); easing.type: Easing.OutCubic }
    ParallelAnimation {
      NumberAnimation { target: medalCoin; property: "scale"; from: 2.8; to: 1; duration: hunt.medal >= 0 ? 210 : 0; easing.type: Easing.InQuad }
      NumberAnimation { target: medalCoin; property: "opacity"; from: 0; to: 1; duration: hunt.medal >= 0 ? 110 : 0 }
    }
    ScriptAction { script: if (hunt.medal >= 0) { medalThud.stop(); medalThud.play() } }
    PauseAnimation { duration: hunt.medal >= 0 ? 160 : 0 }
    ScriptAction { script: {
      hunt.revealed = true
      if (hunt.personalBest) { fanfare.stop(); fanfare.play(); hunt.launchConfetti() }
    } }
    ParallelAnimation {
      NumberAnimation { target: medalCoin; property: "shine"; from: 0; to: 1; duration: hunt.medal >= 0 ? 520 : 0; easing.type: Easing.InOutQuad }
      NumberAnimation { target: verdict; property: "opacity"; from: 0; to: 1; duration: 300 }
      SequentialAnimation {
        NumberAnimation { target: resultTitle; property: "scale"; to: hunt.personalBest ? 1.3 : 1; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: resultTitle; property: "scale"; to: 1; duration: 260; easing.type: Easing.OutBack }
      }
    }
  }
  RemoteSound {
    id: menuHoverSound
    audio: hunt.arena.audio
    source: Qt.resolvedUrl("sounds/weapon-hover.wav")
    volume: 0.22
  }
  function playMenuHover() { menuHoverSound.stop(); menuHoverSound.play() }
  RemoteSound {
    id: fanfare
    audio: hunt.arena.audio
    source: Qt.resolvedUrl("sounds/new-best-fanfare.wav")
    volume: 0.5
  }
  property bool confettiFlying: false
  function launchConfetti() {
    for (var i = 0; i < confetti.count; i++) confetti.itemAt(i).start()
    confettiFlying = true
  }
  Item {
    anchors.fill: parent
    z: 50
    visible: hunt.finished
    Repeater {
      id: confetti
      model: 90
      delegate: Rectangle {
        id: piece
        property bool active: false
        property real vx: 0
        property real vy: 0
        property real spin: 0
        property real age: 0
        visible: active
        width: 7 + index % 5; height: 4 + index % 3
        color: [hunt.ui.accent, hunt.ui.foreground, hunt.ui.urgent, hunt.ui.muted][Math.floor(index / 2) % 4]
        opacity: Math.max(0, Math.min(1, (3.2 - age) / 0.6))
        function start() {
          // Two cannons in the lower corners, aimed up and inward.
          var left = index % 2 === 0
          x = left ? -10 : hunt.width + 10; y = hunt.height * 0.9
          var heading = (left ? -60 : -120) * Math.PI / 180 + (Math.random() - 0.5) * 0.6
          var speed = 700 + Math.random() * 650
          vx = Math.cos(heading) * speed; vy = Math.sin(heading) * speed
          spin = (Math.random() - 0.5) * 900; rotation = Math.random() * 360; age = 0
          active = true
        }
        function advance(dt) {
          age += dt
          if (age >= 3.2 || y > hunt.height + 40) { active = false; return }
          x += vx * dt; y += vy * dt
          vx *= Math.exp(-dt * 1.4); vy = vy * Math.exp(-dt * 1.4) + 700 * dt
          rotation += spin * dt
        }
      }
    }
    FrameAnimation {
      running: hunt.finished && hunt.confettiFlying
      onTriggered: {
        var dt = Math.min(frameTime, 0.05), any = false
        for (var i = 0; i < confetti.count; i++) {
          var piece = confetti.itemAt(i)
          if (piece.active) { piece.advance(dt); any = true }
        }
        if (!any) hunt.confettiFlying = false
      }
    }
  }

  // Last ten seconds: a callout at 10, then every second the timer pops, the
  // clock ticks, and the red edge glow pulses a little stronger. The final
  // three seconds tick twice as fast on a higher tick.
  onSecondsLeftChanged: {
    if (countingDown || finished || secondsLeft < 1 || secondsLeft > 10) return
    var last = secondsLeft <= 3
    var tick = last ? finalTick : clockTick
    tick.stop(); tick.play()
    if (last) halfTick.restart()
    timePop.restart()
    edgeGlow.base = (11 - secondsLeft) / 10
    finalPulse.restart()
    if (secondsLeft === 10) finalCallout.show()
  }
  Timer { id: halfTick; interval: 500; onTriggered: if (!hunt.finished) { finalTick.stop(); finalTick.play() } }
  RemoteSound { id: clockTick; audio: hunt.arena.audio; source: Qt.resolvedUrl("sounds/clock-tick.wav"); volume: 0.78 }
  RemoteSound { id: finalTick; audio: hunt.arena.audio; source: Qt.resolvedUrl("sounds/clock-tick-final.wav"); volume: 0.64 }

  // A colour fading in from all four screen edges.
  component EdgeShade: Item {
    id: shade
    property color tone
    property real depth: 90
    readonly property color glow: hunt.ui.tint(tone, 0.55)
    readonly property color clear: hunt.ui.tint(tone, 0)
    Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: shade.depth
      gradient: Gradient { GradientStop { position: 0; color: shade.glow } GradientStop { position: 1; color: shade.clear } } }
    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: shade.depth
      gradient: Gradient { GradientStop { position: 0; color: shade.clear } GradientStop { position: 1; color: shade.glow } } }
    Rectangle { anchors { top: parent.top; bottom: parent.bottom; left: parent.left } width: shade.depth
      gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: shade.glow } GradientStop { position: 1; color: shade.clear } } }
    Rectangle { anchors { top: parent.top; bottom: parent.bottom; right: parent.right } width: shade.depth
      gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: shade.clear } GradientStop { position: 1; color: shade.glow } } }
  }
  EdgeShade {
    id: edgeGlow
    anchors.fill: parent
    z: 4  // over every game piece, like the slow-motion shade below
    // base climbs from 0.1 at ten seconds to 1 at the last; pulse flares on each tick.
    property real base: 0
    property real pulse: 0
    visible: !hunt.finished && !hunt.lastShot && !hunt.ending && !hunt.countingDown && hunt.secondsLeft <= 10 && opacity > 0
    opacity: Math.min(1, 0.25 + 0.45 * base + 0.4 * pulse)
    tone: hunt.ui.urgent
    depth: 90 + 70 * base
  }
  // Slow motion darkens the edges as time stretches. It sits over every
  // game piece (flies z 0, bodies z 2, coins z 3) so they all dim alike,
  // under the popups and callouts.
  EdgeShade {
    anchors.fill: parent
    z: 4
    tone: hunt.ui.background
    depth: Math.min(width, height) * 0.28
    opacity: hunt.lastShot || hunt.ending ? Math.min(1, (1 - hunt.timeScale) * 1.4) : 0
    visible: opacity > 0
  }
  Text {
    id: timeCallout
    anchors.horizontalCenter: parent.horizontalCenter
    y: parent.height * 0.26
    z: 7
    opacity: 0
    text: "TIME!"
    color: hunt.ui.urgent
    style: Text.Outline; styleColor: hunt.ui.tint(hunt.ui.background, 0.85)
    font.family: hunt.ui.fontFamily; font.pixelSize: 84; font.bold: true; font.letterSpacing: 4
    function show() { timeCalloutHide.stop(); timeCalloutPop.restart() }
    // Out of the way once the final kill lands.
    function hide() { if (opacity > 0) { timeCalloutPop.stop(); timeCalloutHide.restart() } }
    NumberAnimation { id: timeCalloutHide; target: timeCallout; property: "opacity"; to: 0; duration: 160 }
    SequentialAnimation {
      id: timeCalloutPop
      PropertyAction { target: timeCallout; property: "opacity"; value: 1 }
      NumberAnimation { target: timeCallout; property: "scale"; from: 2.2; to: 1; duration: 200; easing.type: Easing.InQuad }
      NumberAnimation { target: timeCallout; property: "scale"; to: 1.06; duration: 900 }
      NumberAnimation { target: timeCallout; property: "opacity"; to: 0; duration: 250 }
    }
  }
  // Under TIME!: one last kill still counts, and a bar shows how long bullet time lasts.
  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    y: timeCallout.y + timeCallout.height + 14
    z: 7
    spacing: 8
    visible: hunt.lastShot && !hunt.finalKill
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "LAST SHOT"
      color: hunt.ui.accent
      style: Text.Outline; styleColor: hunt.ui.tint(hunt.ui.background, 0.85)
      font.family: hunt.ui.fontFamily; font.pixelSize: 26; font.bold: true; font.letterSpacing: 3
      SequentialAnimation on opacity {
        running: hunt.lastShot; loops: Animation.Infinite
        NumberAnimation { to: 0.45; duration: 380; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 380; easing.type: Easing.InOutSine }
      }
    }
    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      width: 180; height: 4; radius: 2
      color: hunt.ui.tint(hunt.ui.foreground, 0.15)
      Rectangle {
        anchors.centerIn: parent
        width: parent.width * hunt.lastShotLeft; height: parent.height; radius: parent.radius
        color: hunt.ui.accent
      }
    }
  }
  // A ring closes in on the kill that ends bullet time.
  Item {
    id: finalKillMark
    z: 7
    opacity: 0
    // Kept on screen; the label sits under the ring, clear of the rising points.
    function show(px, py) {
      x = Math.max(110, Math.min(hunt.width - 110, px)); y = Math.max(80, Math.min(hunt.height - 110, py))
      finalKillPop.restart()
    }
    Rectangle {
      id: finalKillRing
      x: -width / 2; y: -height / 2 - 10
      width: 120; height: 120; radius: 60
      color: "transparent"
      border.width: 4; border.color: hunt.ui.accent
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      y: 58
      text: "FINAL KILL!"
      color: hunt.ui.accent
      style: Text.Outline; styleColor: hunt.ui.tint(hunt.ui.background, 0.85)
      font.family: hunt.ui.fontFamily; font.pixelSize: 30; font.bold: true
    }
    SequentialAnimation {
      id: finalKillPop
      PropertyAction { target: finalKillMark; property: "opacity"; value: 1 }
      ParallelAnimation {
        NumberAnimation { target: finalKillRing; property: "scale"; from: 2.6; to: 1; duration: 260; easing.type: Easing.OutCubic }
        NumberAnimation { target: finalKillMark; property: "scale"; from: 0.6; to: 1; duration: 260; easing.type: Easing.OutBack }
      }
      PauseAnimation { duration: 1300 }
      NumberAnimation { target: finalKillMark; property: "opacity"; to: 0; duration: 250 }
    }
  }
  NumberAnimation { id: finalPulse; target: edgeGlow; property: "pulse"; from: 1; to: 0; duration: 650; easing.type: Easing.OutCubic }

  Text {
    id: finalCallout
    anchors.horizontalCenter: parent.horizontalCenter
    y: parent.height * 0.3
    z: 7
    opacity: 0
    text: "10 SECONDS!"
    color: hunt.ui.urgent
    style: Text.Outline; styleColor: hunt.ui.tint(hunt.ui.background, 0.85)
    font.family: hunt.ui.fontFamily; font.pixelSize: 56; font.bold: true
    function show() { finalCalloutPop.restart() }
    SequentialAnimation {
      id: finalCalloutPop
      PropertyAction { target: finalCallout; property: "opacity"; value: 1 }
      NumberAnimation { target: finalCallout; property: "scale"; from: 0.5; to: 1.2; duration: 110; easing.type: Easing.OutQuad }
      NumberAnimation { target: finalCallout; property: "scale"; to: 1; duration: 180 }
      PauseAnimation { duration: 700 }
      NumberAnimation { target: finalCallout; property: "opacity"; to: 0; duration: 400 }
    }
  }

  // The briefing: the goal, how scoring works, and the score to beat.
  Rectangle {
    id: briefingCard
    visible: hunt.briefing
    z: 8
    anchors.centerIn: parent
    width: Math.min(660, parent.width - 32); height: briefingColumn.implicitHeight + 56
    radius: hunt.ui.cornerRadius
    color: hunt.ui.tint(hunt.ui.background, 0.94)
    border.width: 2; border.color: hunt.ui.accent
    Column {
      id: briefingColumn
      anchors.centerIn: parent
      width: parent.width - 56; spacing: 14
      Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "FLY HUNT"; color: hunt.ui.accent; font.family: hunt.ui.fontFamily; font.pixelSize: 34; font.bold: true; font.letterSpacing: 2 }
      Text {
        readonly property var best: hunt.arena.flyRecords.bests[hunt.weapon]
        readonly property string weaponName: hunt.arena.weaponName || hunt.arena.weaponNames([hunt.weapon])
        width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
        textFormat: Text.StyledText
        text: best ? "Your current best with the " + weaponName + " is <b><font color=\"" + hunt.ui.accent + "\">" + best.score + "</font></b>"
          : "No best score with the " + weaponName + " yet"
        color: hunt.ui.foreground; font.family: hunt.ui.fontFamily; font.pixelSize: 16
      }
      Rectangle { width: parent.width; height: 1; color: hunt.ui.tint(hunt.ui.foreground, 0.14) }
      Repeater {
        model: [
          "Kill as many flies as you can in " + Rules.roundSeconds + " seconds",
          "Quick kills in a row multiply points, up to ×5",
          "Golden flies are worth ×" + Rules.goldenValue + ", but they don't stay long"
        ]
        delegate: Row {
          required property string modelData
          width: briefingColumn.width; spacing: 10
          Text { text: "›"; color: hunt.ui.accent; font.family: hunt.ui.fontFamily; font.pixelSize: 17; font.bold: true }
          Text { width: parent.width - 22; wrapMode: Text.WordWrap; text: modelData; color: hunt.ui.foreground; font.family: hunt.ui.fontFamily; font.pixelSize: 16 }
        }
      }
      Rectangle { width: parent.width; height: 1; color: hunt.ui.tint(hunt.ui.foreground, 0.14) }
      Text {
        id: startPrompt
        width: parent.width; horizontalAlignment: Text.AlignHCenter
        text: "LEFT-CLICK TO START"
        color: hunt.ui.accent; font.family: hunt.ui.fontFamily; font.pixelSize: 22; font.bold: true; font.letterSpacing: 1.5
        SequentialAnimation on opacity {
          running: hunt.briefing; loops: Animation.Infinite
          NumberAnimation { to: 0.35; duration: 650; easing.type: Easing.InOutSine }
          NumberAnimation { to: 1; duration: 650; easing.type: Easing.InOutSine }
        }
      }
      Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "Esc quits"; color: hunt.ui.muted; font.family: hunt.ui.fontFamily; font.pixelSize: 13 }
    }
  }
}
