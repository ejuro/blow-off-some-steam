import QtQuick
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
  // Hit feel: each kill briefly freezes the flies and projectiles (hit-stop) and
  // adds shake "trauma" to the play area. The weapon and HUD never shake.
  property real hitStop: 0
  property real trauma: 0
  property real shakeTime: 0
  readonly property real shakeX: 16 * trauma * trauma * (Math.sin(shakeTime * 71) + 0.5 * Math.sin(shakeTime * 113 + 1.7)) / 1.5
  readonly property real shakeY: 16 * trauma * trauma * (Math.sin(shakeTime * 83 + 0.6) + 0.5 * Math.sin(shakeTime * 127 + 3.1)) / 1.5
  Translate { id: worldShake; x: hunt.shakeX; y: hunt.shakeY }
  function impact() {
    var burst = Math.max(1, burstCount)
    var stop = burst >= 2 ? Math.min(0.13, 0.09 + 0.02 * (burst - 2)) : 0.035 + 0.008 * combo
    hitStop = Math.max(hitStop, stop)
    trauma = Math.min(1, trauma + 0.12 + 0.05 * combo + (burst >= 2 ? 0.2 : 0))
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
  RemoteSound { id: countdownBeep; audio: hunt.arena.audio; source: Qt.resolvedUrl("sounds/countdown-beep.wav"); volume: 0.5 }
  RemoteSound { id: countdownGo; audio: hunt.arena.audio; source: Qt.resolvedUrl("sounds/countdown-go.wav"); volume: 0.55 }
  Timer {
    id: countdownTimer
    interval: 650; repeat: true
    onTriggered: {
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
    if (finished || countingDown || briefing) return false
    if (Date.now() >= round.deadline) { finishRound(); return false }
    return true
  }
  function recordKill(x, y, source, weapon) {
    var now = Date.now()
    var before = round.score
    if (!Rules.kill(round, now)) { finishRound(); return }
    score = round.score; kills = round.kills
    combo = round.combo; bestCombo = round.bestCombo
    if (comboBreaking) { comboBreak.stop(); comboValue.shake = 0; comboBreaking = false }
    showPopup(x, y, round.score - before, round.combo)
    // Bullets hit one fly each, so only blasts and saber sweeps can multi-kill.
    var window = source === "saber" ? 250 : source === "blast" ? 40 : -1
    if (source === burstSource && now - burstLast <= window) burstCount++
    else burstCount = 1
    burstSource = source; burstLast = now
    if (burstCount >= 2) multiKillText.show(multiKillNames[Math.min(4, burstCount)])
    impact()
  }
  function breakCombo() {
    if (combo >= 2) { lostCombo = combo; comboBreaking = true; comboBreak.restart() }
    combo = 0
  }
  property int popupCursor: 0
  function showPopup(x, y, points, multiplier) {
    popups.itemAt(popupCursor).start(x, y, points, multiplier)
    popupCursor = (popupCursor + 1) % popups.count
  }
  function finishRound() {
    var record = Rules.finish(round, Date.now())
    if (!record) return
    secondsLeft = 0
    previousBest = arena.flyRecords.bests[round.weapon] || null
    personalBest = record.score > 0 && (!previousBest || record.score > previousBest.score)
    hitStop = 0; trauma = 0
    finished = true
    resultReveal.restart()
    arena.flyRecords.add(record)
  }
  function restart() {
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
    for (var c = 0; c < confetti.count; c++) confetti.itemAt(c).active = false
    confettiFlying = false
    finished = false
    startCountdown()
  }
  Timer {
    interval: 50; running: !hunt.finished; repeat: true
    onTriggered: {
      if (hunt.countingDown) return
      var now = Date.now()
      hunt.secondsLeft = Rules.remaining(hunt.round, now)
      if (hunt.combo > 0 && hunt.round.lastKill !== null && now - hunt.round.lastKill > Rules.comboWindow(hunt.round.combo)) hunt.breakCombo()
      if (now >= hunt.round.deadline) hunt.finishRound()
    }
  }
  // One preloaded voice also avoids stacking four identical sounds on a blast.
  RemoteSound {
    audio: hunt.arena.audio
    id: splatSound
    source: Qt.resolvedUrl("sounds/bug-splat.wav")
    volume: 0.45
  }

  function hitProjectile(x0, y0, x1, y1, radius, weapon) {
    var dx = x1 - x0, dy = y1 - y0
    var lengthSquared = dx * dx + dy * dy
    if (!hunt.acceptHits()) return false
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
        fragments.itemAt(fragmentCursor).start(fly.x, fly.y, angle, side, frame, fly.facingLeft)
        fragmentCursor = (fragmentCursor + 1) % fragments.count
      }
      fly.hit("saber", "lightsaber", swingX, swingY)
      struck = true
    }
    return struck
  }
  Repeater { id: fragments; model: 32; delegate: FlyFragment { transform: worldShake } }

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
      var dt = Math.min(frameTime, 0.05)
      hunt.shakeTime += dt
      hunt.trauma = Math.max(0, hunt.trauma - dt * 2.2)
      if (hunt.hitStop > 0) { hunt.hitStop = Math.max(0, hunt.hitStop - dt); return }
      hunt.wingTime += dt
      hunt.comboLeft = hunt.combo > 0 && hunt.round.lastKill !== null
        ? Math.max(0, 1 - (Date.now() - hunt.round.lastKill) / Rules.comboWindow(hunt.round.combo)) : 0
      for (var j = 0; j < fragments.count; j++) fragments.itemAt(j).advance(dt)
      for (var k = 0; k < droplets.count; k++) droplets.itemAt(k).advance(dt)
      if (!hunt.acceptHits()) return
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
      transform: worldShake

      function reset() {
        alive = false; respawnTime = index * 0.12
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
        steeringTime -= dt
        var dx = destinationX - x, dy = destinationY - y
        var distance = Math.sqrt(dx * dx + dy * dy)
        if (steeringTime <= 0 || distance < 25) { chooseDestination(); dx = destinationX - x; dy = destinationY - y; distance = Math.sqrt(dx * dx + dy * dy) }
        var blend = 1 - Math.exp(-dt * (index >= 2 ? 7 : 4))
        vx += (dx / Math.max(1, distance) * speed - vx) * blend
        vy += (dy / Math.max(1, distance) * speed - vy) * blend
        x += vx * dt; y += vy * dt
        var minX = 35, maxX = Math.max(35, hunt.width - 35), minY = 45, maxY = Math.max(45, hunt.height - 35)
        if (entering && x >= minX && x <= maxX && y >= minY && y <= maxY) entering = false
        if (!entering) {
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
        hunt.recordKill(x, y, source, weapon)
        // Splats and sprays grow with the combo.
        splatScale = 0.85 + 0.15 * hunt.combo
        splatX = x; splatY = y
        splatFade.stop(); splat.opacity = 1; splat.requestPaint(); splatFade.start()
        hunt.spray(x, y, dirX || 0, dirY || 0, 4 + 2 * hunt.combo)
      }
      Component.onCompleted: respawnTime = index * 0.12

      AnimatedSprite {
        x: -44; y: -54
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
        readonly property color ink: hunt.arena.accent
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
      HudValue { label: "SCORE"; value: hunt.score }
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
      property real startY: 0
      visible: false
      z: 5
      function start(px, py, gained, combo) {
        points = gained; multiplier = combo
        x = px; startY = py - 34
        rise.restart()
      }
      function stop() { rise.stop(); visible = false }
      Row {
        x: -width / 2; y: -height / 2
        spacing: 5
        Text {
          text: "+" + popup.points
          color: hunt.ui.accent
          style: Text.Outline; styleColor: hunt.ui.tint(hunt.ui.background, 0.85)
          font.family: hunt.ui.fontFamily; font.pixelSize: 20 + popup.multiplier * 3; font.bold: true
        }
        Text {
          visible: popup.multiplier > 1
          anchors.baseline: parent.children[0].baseline
          text: "×" + popup.multiplier
          color: hunt.ui.foreground
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
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: hunt.kills + " flies · best combo ×" + hunt.bestCombo; color: hunt.ui.tint(hunt.ui.foreground, 0.85); font.family: hunt.ui.fontFamily; font.pixelSize: 18 }
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
    ScriptAction { script: { hunt.shownScore = 0; hunt.revealed = false; verdict.opacity = 0 } }
    PauseAnimation { duration: 250 }
    NumberAnimation { target: hunt; property: "shownScore"; from: 0; to: hunt.score; duration: Math.min(1400, 500 + hunt.score / 40); easing.type: Easing.OutCubic }
    ScriptAction { script: {
      hunt.revealed = true
      if (hunt.personalBest) { fanfare.stop(); fanfare.play(); hunt.launchConfetti() }
    } }
    ParallelAnimation {
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
  RemoteSound { id: clockTick; audio: hunt.arena.audio; source: Qt.resolvedUrl("sounds/clock-tick.wav"); volume: 0.55 }
  RemoteSound { id: finalTick; audio: hunt.arena.audio; source: Qt.resolvedUrl("sounds/clock-tick-final.wav"); volume: 0.6 }

  Item {
    id: edgeGlow
    anchors.fill: parent
    z: 1
    // base climbs from 0.1 at ten seconds to 1 at the last; pulse flares on each tick.
    property real base: 0
    property real pulse: 0
    visible: !hunt.finished && !hunt.countingDown && hunt.secondsLeft <= 10 && opacity > 0
    opacity: Math.min(1, 0.25 + 0.45 * base + 0.4 * pulse)
    readonly property real depth: 90 + 70 * base
    readonly property color glow: hunt.ui.tint(hunt.ui.urgent, 0.55)
    readonly property color clear: hunt.ui.tint(hunt.ui.urgent, 0)
    Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: edgeGlow.depth
      gradient: Gradient { GradientStop { position: 0; color: edgeGlow.glow } GradientStop { position: 1; color: edgeGlow.clear } } }
    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: edgeGlow.depth
      gradient: Gradient { GradientStop { position: 0; color: edgeGlow.clear } GradientStop { position: 1; color: edgeGlow.glow } } }
    Rectangle { anchors { top: parent.top; bottom: parent.bottom; left: parent.left } width: edgeGlow.depth
      gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: edgeGlow.glow } GradientStop { position: 1; color: edgeGlow.clear } } }
    Rectangle { anchors { top: parent.top; bottom: parent.bottom; right: parent.right } width: edgeGlow.depth
      gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: edgeGlow.clear } GradientStop { position: 1; color: edgeGlow.glow } } }
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
          "Quick kills in a row multiply points, up to ×5"
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
