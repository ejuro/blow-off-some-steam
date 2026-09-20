import QtQuick

Item {
  id: hunt
  required property var arena
  readonly property int flyCount: 4
  property int kills: 0
  property bool bossTriggered: false
  property bool bossActive: false
  property bool bossDefeated: false
  readonly property int bossMaxHealth: 120
  property int bossHealth: bossMaxHealth
  property real bossX: width / 2
  property real bossY: -300
  property real bossTime: 0
  property real shakeTime: 0
  property real shakeX: 0
  property real shakeY: 0
  property real defeatTime: 0
  property real wingTime: 0
  readonly property real entranceDuration: 2.8
  readonly property real revealTime: 1.5
  readonly property int bossSplatInterval: 30
  property int nextSplatHealth: bossMaxHealth - bossSplatInterval
  property bool bossRevealed: false
  property bool bossEntering: false
  property bool bossEnraged: false
  property bool bossDying: false
  property real enrageTime: 0
  property real deathTime: 0
  property real deathX: 0
  property real deathY: 0
  property real bossWingPhase: 0
  property real bossTilt: 0
  property real bossKick: 0
  property real scatterTime: 0
  property bool dashActive: false
  property real dashElapsed: 0
  property real dashDuration: 0.26
  property real dashWait: 0
  property real dashStartX: 0
  property real dashStartY: 0
  property real dashTargetX: 0
  property real dashTargetY: 0
  readonly property bool bossFaltering: bossActive && bossHealth <= bossMaxHealth * 0.1
  readonly property real bossSize: Math.min(520, width * 0.45, height * 0.65)
  readonly property real bossRadius: bossSize * 0.25

  function recordKill() {
    kills++
    if (kills === 20 && !bossTriggered) {
      bossTriggered = true
      // Defer entry until the triggering bullet/blast has finished processing.
      bossEntrance.start()
    }
  }
  function beginBoss() {
    bossActive = true; bossHealth = bossMaxHealth
    bossEntering = true; bossEnraged = false; bossDying = false
    bossRevealed = false; nextSplatHealth = bossMaxHealth - bossSplatInterval
    bossTime = 0; bossX = -bossSize; bossY = height * 0.4
    bossWingPhase = 0; bossTilt = 0; bossKick = 0
    dashActive = false; dashWait = 0; dashElapsed = 0
    enrageTime = 0; scatterTime = 0.55
    shakeTime = 0.3
    arrivalDelay.start()
    for (var i = 0; i < flies.count; i++) {
      var fly = flies.itemAt(i)
      fly.scattering = fly.alive
      fly.alive = false
    }
  }
  function damageBoss(amount) {
    if (!bossActive || bossEntering) return
    bossHealth = Math.max(0, bossHealth - amount)
    bossKick = (bossX < width / 2 ? 1 : -1) * (amount >= 8 ? 28 : 9)
    if (bossHealth === 0) {
      // Keep the music loader alive while switching from combat to its fade-out.
      bossDying = true; bossActive = false; bossEntering = false
      deathTime = 0; deathX = bossX; deathY = bossY
      arrivalDelay.stop(); arrivalSound.stop(); enrageSound.stop(); buzzSound.stop()
    } else {
      if (bossHealth <= nextSplatHealth) {
        splatSound.stop(); splatSound.play()
        while (nextSplatHealth >= bossHealth) nextSplatHealth -= bossSplatInterval
      }
      if (!bossEnraged && bossHealth <= bossMaxHealth * 0.35) {
        bossEnraged = true; enrageTime = 1.3
        shakeTime = Math.max(shakeTime, 0.3)
        enrageSound.play()
      }
    }
  }
  function finishBossDeath() {
    bossDying = false; bossDefeated = true; defeatTime = 3.5
    shakeTime = 0.6; bossTilt = 0
    bossSplat.x = bossX - bossSplat.width / 2
    bossSplat.y = bossY - bossSplat.height / 2
    bossSplat.requestPaint()
    splatSound.stop(); splatSound.play()
  }
  function advanceDash(dt) {
    if (!dashActive) {
      dashWait = Math.max(0, dashWait - dt)
      bossTilt *= Math.exp(-dt * 15)
      if (dashWait > 0) return
      dashStartX = bossX; dashStartY = bossY
      var margin = Math.min(width * 0.25, bossSize * 0.55)
      var span = Math.max(0, width - margin * 2)
      // Cross to the opposite side; reroll height and distance once per dash.
      dashTargetX = margin + span * (bossX < width / 2 ? 0.72 + Math.random() * 0.28 : Math.random() * 0.28)
      var top = Math.min(height / 2, bossSize * 0.7 + 50)
      var bottom = Math.max(top, height - bossSize * 0.35)
      dashTargetY = top + Math.random() * (bottom - top)
      dashDuration = 0.22 + Math.random() * 0.10
      dashElapsed = 0; dashActive = true
      // A short ~6px jolt through the existing transform, not a new effect.
      shakeTime = Math.max(shakeTime, 0.13)
    }
    dashElapsed += dt
    var progress = Math.min(1, dashElapsed / dashDuration)
    var eased = progress * progress * (3 - 2 * progress)
    bossX = dashStartX + (dashTargetX - dashStartX) * eased
    bossY = dashStartY + (dashTargetY - dashStartY) * eased
    bossTilt = (dashTargetX > dashStartX ? 1 : -1) * Math.sin(progress * Math.PI) * 24
    if (progress >= 1) {
      dashActive = false
      dashWait = 0.10 + Math.random() * 0.10
    }
  }
  function advanceBoss(dt) {
    scatterTime = Math.max(0, scatterTime - dt)
    bossKick *= Math.exp(-dt * 12)
    enrageTime = Math.max(0, enrageTime - dt)
    if (bossDying) {
      deathTime += dt
      var fall = Math.min(1, deathTime / 1.8)
      bossX = deathX + Math.sin(fall * Math.PI * 4) * bossSize * 0.12 * fall
      bossY = deathY + (Math.max(deathY, height - bossSize * 0.22) - deathY) * fall * fall
      bossTilt = fall * 430
      bossWingPhase += dt * Math.max(0, 16 * (1 - fall))
      if (fall >= 1) finishBossDeath()
      return
    }
    if (!bossActive) return
    bossTime += dt
    // Weak wings intermittently stall, but the sprite itself never disappears.
    var wingRate = bossFaltering ? (Math.sin(bossTime * 23) > 0.25 ? 17 : 2) : (bossEnraged ? 42 : 32)
    bossWingPhase += dt * wingRate
    if (bossEntering) {
      if (bossTime >= revealTime && !bossRevealed) {
        bossRevealed = true
        shakeTime = 0.65
      }
      var settle = Math.max(0, Math.min(1, (bossTime - revealTime) / 0.4))
      settle = 1 - Math.pow(1 - settle, 3)
      bossX = width * 0.5
      bossY = -bossSize * (1 - settle) + height * 0.44 * settle
      bossTilt = -18 * (1 - settle)
      if (bossTime >= entranceDuration) {
        bossEntering = false; bossTime = 0; shakeTime = 0.4
        buzzSound.play()
      }
      return
    }
    if (bossEnraged && !bossFaltering && enrageTime === 0) {
      advanceDash(dt)
      return
    }
    dashActive = false
    var targetX = width / 2 + Math.sin(bossTime * 0.7) * width * 0.2
    var targetY = height * 0.42 + Math.sin(bossTime * 1.3) * height * 0.1
    var follow = 3
    bossTilt = Math.sin(bossTime * 1.3) * 5
    if (bossFaltering) {
      targetX = width * 0.5 + Math.sin(bossTime * 0.9) * width * 0.12
      targetY = height * 0.58 + Math.sin(bossTime * 5) * bossSize * 0.06
      bossTilt = Math.sin(bossTime * 9) * 11
      follow = 2
    }
    if (enrageTime > 0) follow = 0.4
    bossX += (targetX - bossX) * (1 - Math.exp(-dt * follow))
    bossY += (targetY - bossY) * (1 - Math.exp(-dt * follow))
  }
  Timer { id: bossEntrance; interval: 1; onTriggered: hunt.beginBoss() }
  function playArrival() {
    if (!bossEntering) return
    if (arrivalSound.status === RemoteSound.Ready) arrivalSound.play()
    if (buzzSound.status === RemoteSound.Ready) buzzSound.play()
  }
  Timer { id: arrivalDelay; interval: 150; onTriggered: hunt.playArrival() }

  Loader {
    id: musicLoader
    active: (hunt.bossActive && hunt.bossRevealed) || hunt.bossDying
    sourceComponent: BossMusic { audio: hunt.arena.audio; ending: hunt.bossDying }
  }

  RemoteSound {
    audio: hunt.arena.audio
    id: arrivalSound
    source: Qt.resolvedUrl("sounds/motherfly-arrival.wav")
    volume: 0.85
    onStatusChanged: if (status === RemoteSound.Ready && hunt.bossEntering && !arrivalDelay.running) play()
  }
  RemoteSound {
    audio: hunt.arena.audio
    id: buzzSound
    source: Qt.resolvedUrl("sounds/motherfly-buzz.wav")
    loops: RemoteSound.Infinite
    volume: hunt.bossEntering ? 0.32 : hunt.bossFaltering ? 0.06 + Math.max(0, Math.sin(hunt.bossTime * 23)) * 0.16 : (hunt.bossEnraged ? 0.25 : 0.14)
    onStatusChanged: if (status === RemoteSound.Ready && hunt.bossActive && !arrivalDelay.running) play()
  }
  RemoteSound {
    audio: hunt.arena.audio
    id: enrageSound
    source: Qt.resolvedUrl("sounds/motherfly-enrage.wav")
    volume: 0.65
  }
  Component.onDestruction: {
    arrivalSound.stop(); buzzSound.stop(); enrageSound.stop(); splatSound.stop()
  }


  // One preloaded voice also avoids stacking four identical sounds on a blast.
  RemoteSound {
    audio: hunt.arena.audio
    id: splatSound
    source: Qt.resolvedUrl("sounds/bug-splat.wav")
    volume: 0.45
  }

  function hitProjectile(x0, y0, x1, y1, radius) {
    var dx = x1 - x0, dy = y1 - y0
    var lengthSquared = dx * dx + dy * dy
    if (bossActive) {
      var bt = lengthSquared ? Math.max(0, Math.min(1, ((bossX - x0) * dx + (bossY - y0) * dy) / lengthSquared)) : 0
      if (Math.pow(x0 + bt * dx - bossX, 2) + Math.pow(y0 + bt * dy - bossY, 2) <= Math.pow(bossRadius + radius, 2)) { damageBoss(1); return true }
      return false
    }
    if (bossTriggered && !bossDefeated) return false
    var nearest = null, nearestT = 2
    for (var i = 0; i < flies.count; i++) {
      var fly = flies.itemAt(i)
      if (!fly || !fly.alive) continue
      var t = lengthSquared ? Math.max(0, Math.min(1, ((fly.x - x0) * dx + (fly.y - y0) * dy) / lengthSquared)) : 0
      var ex = x0 + t * dx - fly.x, ey = y0 + t * dy - fly.y
      if (ex * ex + ey * ey <= Math.pow(radius + 19, 2) && t < nearestT) { nearest = fly; nearestT = t }
    }
    if (!nearest) return false
    nearest.hit()
    return true
  }

  function hitBlast(x, y, radius) {
    if (bossActive) {
      if (Math.pow(bossX - x, 2) + Math.pow(bossY - y, 2) <= Math.pow(radius + bossRadius, 2)) damageBoss(8)
      return
    }
    if (bossTriggered && !bossDefeated) return
    for (var i = 0; i < flies.count; i++) {
      var fly = flies.itemAt(i)
      if (fly && fly.alive && Math.pow(fly.x - x, 2) + Math.pow(fly.y - y, 2) <= Math.pow(radius + 19, 2)) fly.hit()
    }
  }

  // One shared movement callback; four persistent sprites and four small splats.
  FrameAnimation {
    running: hunt.visible && hunt.arena.armed
    onTriggered: {
      var dt = Math.min(frameTime, 0.05)
      hunt.wingTime += dt
      hunt.advanceBoss(dt)
      if (hunt.shakeTime > 0) {
        hunt.shakeTime = Math.max(0, hunt.shakeTime - dt)
        var strength = 18 * Math.min(1, hunt.shakeTime / 0.4)
        hunt.shakeX = Math.sin(hunt.shakeTime * 83) * strength
        hunt.shakeY = Math.cos(hunt.shakeTime * 107) * strength * 0.65
      } else { hunt.shakeX = 0; hunt.shakeY = 0 }
      hunt.defeatTime = Math.max(0, hunt.defeatTime - dt)
      if (hunt.scatterTime > 0)
        for (var j = 0; j < flies.count; j++) {
          var fleeing = flies.itemAt(j)
          fleeing.x += (j % 2 ? 1 : -1) * dt * 1000
          fleeing.y -= dt * 600
        }
      if (!hunt.bossTriggered || hunt.bossDefeated)
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
      property bool scattering: false
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

      function randomX() { return Math.min(hunt.width / 2, 65) + Math.random() * Math.max(0, hunt.width - 130) }
      function randomY() { return Math.min(hunt.height / 2, 65) + Math.random() * Math.max(0, hunt.height - 130) }
      function chooseDestination() {
        destinationX = randomX(); destinationY = randomY()
        steeringTime = 0.7 + Math.random() * 1.5
        speed = baseSpeed * (0.85 + Math.random() * 0.3)
      }
      function spawn() {
        x = randomX(); y = randomY(); vx = 0; vy = 0
        // Keep a mix of speeds on screen; reroll within each tier on respawn.
        var minimum = [90, 180, 340, 560]
        var spread = [80, 130, 190, 240]
        baseSpeed = minimum[index] + Math.random() * spread[index]
        chooseDestination(); scattering = false; alive = true
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
        x = Math.max(35, Math.min(Math.max(35, hunt.width - 35), x + vx * dt))
        y = Math.max(45, Math.min(Math.max(45, hunt.height - 35), y + vy * dt))
        if (vx < -12) facingLeft = true
        else if (vx > 12) facingLeft = false
      }
      function hit() {
        if (!alive) return
        alive = false
        splatSound.stop()
        splatSound.play()
        respawnTime = 2.4 + Math.random() * 1.4
        splatX = x; splatY = y
        splatFade.stop(); splat.opacity = 1; splat.requestPaint(); splatFade.start()
        hunt.recordKill()
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
        running: (fly.alive || fly.scattering) && hunt.visible
        visible: fly.alive || (fly.scattering && hunt.scatterTime > 0)
        opacity: fly.alive ? 1 : hunt.scatterTime / 0.55
        transform: Scale { origin.x: 44; origin.y: 54; xScale: fly.facingLeft ? -1 : 1 }
      }

      Canvas {
        id: splat
        // Keep the mark at the impact point while this slot respawns elsewhere.
        x: fly.splatX - fly.x - 48; y: fly.splatY - fly.y - 48
        width: 96; height: 96
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

  Rectangle {
    anchors.fill: parent
    color: "#111018"
    opacity: hunt.bossActive || hunt.bossDying ? (hunt.bossEntering ? 0.36 : 0.2) : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 300 } }
  }
  Item {
    width: hunt.bossSize; height: width
    x: hunt.bossX - width * 0.55 + hunt.bossKick; y: hunt.bossY - height * 0.675
    visible: (hunt.bossActive && (!hunt.bossEntering || hunt.bossRevealed)) || hunt.bossDying
    transform: Rotation { origin.x: hunt.bossSize * 0.55; origin.y: hunt.bossSize * 0.675; angle: hunt.bossTilt }
    AnimatedSprite {
      anchors.fill: parent
      source: Qt.resolvedUrl("assets/fly-spritesheet.png")
      frameWidth: 443; frameHeight: 443; frameCount: 8
      frameRate: 32; interpolate: true
      paused: true
      currentFrame: Math.floor(hunt.bossWingPhase) % frameCount
      running: hunt.bossActive || hunt.bossDying
    }
    Rectangle {
      x: parent.width * 0.69; y: parent.height * 0.505
      width: parent.width * 0.12; height: parent.height * 0.16
      radius: width / 2
      color: "#ff493b"; border.color: "#ffb078"; border.width: 2
      opacity: hunt.bossEnraged && !hunt.bossDying ? 0.28 + Math.sin(hunt.bossTime * 7) * 0.08 : 0
      Behavior on opacity { NumberAnimation { duration: 120 } }
    }
  }
  Column {
    y: hunt.bossEntering || hunt.enrageTime > 0 ? hunt.height * 0.16 : 64
    Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.min(520, hunt.width * 0.7)
    spacing: 10
    visible: hunt.bossActive || hunt.bossDying || hunt.defeatTime > 0
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: hunt.bossDefeated ? "REVENGE. SERVED." : hunt.bossEntering && !hunt.bossRevealed ? "SOMETHING IS COMING…" : hunt.enrageTime > 0 ? "MOTHERFLY ENRAGED" : "THE MOTHERFLY"
      font.pixelSize: hunt.bossEntering || hunt.enrageTime > 0 ? 36 : 28; font.bold: true; font.letterSpacing: 4
      color: hunt.enrageTime > 0 ? "#ff795b" : "white"; style: Text.Outline; styleColor: "#111111"
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: hunt.bossDying ? "GOING DOWN." : hunt.bossEntering ? "SHE HEARD WHAT YOU DID." : hunt.bossFaltering ? "ONE LAST SWAT." : "NOW SHE'S ANGRY."
      visible: hunt.bossEntering || hunt.enrageTime > 0 || hunt.bossFaltering || hunt.bossDying
      color: hunt.bossEnraged ? "#ffad83" : "#dddddd"
      font.pixelSize: 13; font.letterSpacing: 2
      style: Text.Outline; styleColor: "#111111"
    }
    Rectangle {
      width: parent.width; height: 18; radius: 5
      color: "#dd141414"; border.color: "#bbffffff"; border.width: 1
      Rectangle {
        x: 3; y: 3; height: 12; radius: 3
        width: (parent.width - 6) * hunt.bossHealth / hunt.bossMaxHealth
        color: hunt.bossEnraged ? "#e75c48" : hunt.arena.accent
        Behavior on width { NumberAnimation { duration: 70 } }
      }
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: hunt.bossHealth + " / " + hunt.bossMaxHealth
      color: "white"; font.pixelSize: 14
      style: Text.Outline; styleColor: "#111111"
    }
  }
  Text {
    anchors.bottom: parent.bottom; anchors.bottomMargin: 48
    anchors.horizontalCenter: parent.horizontalCenter
    visible: !hunt.bossTriggered
    text: "FLIES  " + hunt.kills + " / 20"
    color: "white"; font.pixelSize: 18; font.bold: true
    style: Text.Outline; styleColor: "#111111"
  }
  Canvas {
    id: bossSplat
    width: 360; height: 360
    visible: hunt.defeatTime > 0
    opacity: Math.min(1, hunt.defeatTime)
    readonly property color ink: hunt.arena.accent
    onInkChanged: if (visible) requestPaint()
    onPaint: {
      var c = getContext("2d"); c.reset(); c.clearRect(0, 0, width, height)
      c.fillStyle = ink
      c.beginPath(); c.arc(180, 180, 65, 0, Math.PI * 2); c.fill()
      for (var i = 0; i < 18; i++) {
        var angle = i * 2.399, distance = 55 + (i % 5) * 22
        c.beginPath(); c.arc(180 + Math.cos(angle) * distance, 180 + Math.sin(angle) * distance, 9 + (i % 4) * 8, 0, Math.PI * 2); c.fill()
      }
    }
  }
}
