import Quickshell
import Quickshell.Wayland
import QtQuick
import QtMultimedia
import qs.Commons

Item {
  id: root
  property bool armed: false
  property string weapon: "glock"
  readonly property var spec: {
    switch (weapon) {
    case "revolver": return { name: "Colt 45", image: "assets/revolver-colt45.png", width: 64, height: 32, scale: 2.2, gripX: 20, gripY: 25, muzzleX: 47, muzzleY: 12.5, automatic: false, interval: 280, recoil: 19, particles: 25, power: 1.25, ejectsCase: false, flashStyle: "revolver" }
    case "ak47": return { name: "AK-47", image: "assets/ak47.png", width: 96, height: 48, scale: 2, gripX: 35, gripY: 33, muzzleX: 79, muzzleY: 9.5, automatic: true, interval: 82, recoil: 10, particles: 14, power: 1 }
    case "mp5a3": return { name: "MP5A3", image: "assets/mp5a3.png", width: 80, height: 48, scale: 2.1, gripX: 33, gripY: 33, muzzleX: 60, muzzleY: 7.5, automatic: true, interval: 66, recoil: 7, particles: 11, power: 0.9 }
    case "bazooka": return { name: "M20 Bazooka", image: "assets/bazooka-m20.png", width: 128, height: 32, scale: 2, gripX: 46, gripY: 24, muzzleX: 115, muzzleY: 12.5, automatic: false, interval: 500, recoil: 28, particles: 42, power: 1.8 }
    case "thick-bazooka": return { name: "Thick M20", image: "assets/bazooka-m20-thick.png", width: 192, height: 32, scale: 1.65, gripX: 66, gripY: 24, muzzleX: 147, muzzleY: 10.5, automatic: false, interval: 550, recoil: 32, particles: 52, power: 2.1 }
    default: return { name: "Glock P80", image: "assets/glock-p80.png", width: 64, height: 48, scale: 2.2, gripX: 22, gripY: 34, muzzleX: 48, muzzleY: 11.5, automatic: false, interval: 220, recoil: 15, particles: 19, power: 1 }
    }
  }
  readonly property string weaponName: spec.name
  property real pointerX: 0
  property real pointerY: 0
  property real gunX: 0
  property real gunY: 0
  property real aimAngle: 0
  property bool aimFlipped: false
  property bool gunPositioned: false
  property bool automaticHoldEngaged: false
  property real followDistance: 135
  property real recoil: 0
  property real flash: 0
  property real trickAngle: 0
  property var particles: []
  property var pendingEffects: []
  property bool targetVisible: false
  property bool targetsEnabled: true
  property real targetX: 0
  property real targetY: 0
  property real targetRadius: 34
  property bool weaponWheelOpen: false
  property real weaponWheelX: 0
  property real weaponWheelY: 0
  property real weaponWheelOriginX: 0
  property real weaponWheelOriginY: 0
  property int weaponWheelSelection: -1
  readonly property color accent: Color.accent
  readonly property var weaponOptions: [
    { id: "glock", name: "GLOCK", image: "assets/glock-p80.png", clip: Qt.rect(18, 8, 30, 20) },
    { id: "revolver", name: "COLT", image: "assets/revolver-colt45.png", clip: Qt.rect(2, 11, 45, 18) },
    { id: "ak47", name: "AK-47", image: "assets/ak47.png", clip: Qt.rect(3, 5, 76, 22) },
    { id: "mp5a3", name: "MP5", image: "assets/mp5a3.png", clip: Qt.rect(3, 3, 57, 27) },
    { id: "bazooka", name: "M20", image: "assets/bazooka-m20.png", clip: Qt.rect(3, 7, 112, 24) },
    { id: "thick-bazooka", name: "THICK", image: "assets/bazooka-m20-thick.png", clip: Qt.rect(35, 3, 112, 28) }
  ]

  function openWeaponWheel(x, y) {
    var extent = 170
    weaponWheelOriginX = x
    weaponWheelOriginY = y
    weaponWheelX = Math.max(extent, Math.min(window.width - extent, x))
    weaponWheelY = Math.max(extent, Math.min(window.height - extent, y))
    weaponWheelSelection = -1
    weaponWheelOpen = true
  }
  function updateWeaponWheel(x, y) {
    if (!weaponWheelOpen) return
    var dx = x - weaponWheelOriginX
    var dy = y - weaponWheelOriginY
    var nextSelection = -1
    if (Math.sqrt(dx * dx + dy * dy) < 38) {
      nextSelection = -1
    } else {
      var degrees = Math.atan2(dy, dx) * 180 / Math.PI
      nextSelection = Math.round(((degrees + 90 + 360) % 360) / 60) % 6
    }
    if (nextSelection !== weaponWheelSelection) {
      weaponWheelSelection = nextSelection
      if (nextSelection >= 0) {
        weaponWheelHoverSound.stop()
        weaponWheelHoverSound.play()
      }
    }
  }
  function closeWeaponWheel(chooseSelection) {
    var selection = weaponWheelSelection
    weaponWheelOpen = false
    weaponWheelSelection = -1
    if (chooseSelection && selection >= 0) arm(weaponOptions[selection].id)
  }

  function spawnTarget() {
    if (!armed || !targetsEnabled) return
    var margin = targetRadius + 55
    var usableWidth = Math.max(1, window.width - margin * 2)
    var usableHeight = Math.max(1, window.height - margin * 2)
    targetX = margin + Math.random() * usableWidth
    targetY = margin + Math.random() * usableHeight
    targetVisible = true
  }
  function projectileHitsTarget(p, radius) {
    if (!targetVisible) return false
    var dx = p.x - targetX
    var dy = p.y - targetY
    return dx * dx + dy * dy <= Math.pow(targetRadius + radius, 2)
  }
  function targetWithinBlast(x, y, radius) {
    if (!targetVisible) return false
    var dx = x - targetX
    var dy = y - targetY
    return dx * dx + dy * dy <= Math.pow(radius + targetRadius, 2)
  }
  function rocketBlastParticles(p) {
    var effects = []
    var boomScale = p.boomScale || 1
    effects.push({ x: p.x, y: p.y, vx: 0, vy: 0, life: 1, size: 1, maxRadius: 180 * boomScale, kind: 4 })
    for (var burst = 0; burst < 72 * boomScale; burst++) {
      var burstAngle = Math.random() * Math.PI * 2
      var burstSpeed = (4 + Math.random() * 17) * Math.sqrt(boomScale)
      effects.push({ x: p.x, y: p.y, vx: Math.cos(burstAngle) * burstSpeed, vy: Math.sin(burstAngle) * burstSpeed, life: 0.65 + Math.random() * 0.55, size: (2 + Math.random() * 8) * Math.sqrt(boomScale), kind: 1 })
    }
    return effects
  }
  function playRocketExplosion(p) {
    rocketExplosionSound.stop()
    rocketExplosionSound.volume = (p.boomScale || 1) > 1 ? 1.0 : 0.76
    rocketExplosionSound.play()
  }
  function hitTarget() {
    if (!targetVisible) return
    targetVisible = false
    targetHitSound.stop()
    targetHitSound.play()
    var smoke = pendingEffects.slice()
    for (var i = 0; i < 28; i++) {
      var smokeAngle = Math.random() * Math.PI * 2
      var smokeSpeed = 0.8 + Math.random() * 4.2
      smoke.push({ x: targetX, y: targetY, vx: Math.cos(smokeAngle) * smokeSpeed, vy: Math.sin(smokeAngle) * smokeSpeed - 1.2, life: 0.7 + Math.random() * 0.3, size: 7 + Math.random() * 12, kind: 7 })
    }
    pendingEffects = smoke
    targetRespawnTimer.restart()
  }
  function setTargetsEnabled(enabled) {
    targetsEnabled = enabled
    targetRespawnTimer.stop()
    targetVisible = false
    if (targetsEnabled && armed) spawnTarget()
  }

  function arm(id) {
    weaponWheelOpen = false
    weaponWheelSelection = -1
    weapon = id
    weaponReadySound.stop()
    weaponReadySound.play()
    armed = true
    gunPositioned = false
    aimFlipped = false
    trickAnimation.stop()
    trickAngle = 0
    weaponSpinSound.stop()
    particles = []
    pendingEffects = []
    targetVisible = false
    if (targetsEnabled) Qt.callLater(root.spawnTarget)
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }
  function holster() {
    armed = false
    weaponWheelOpen = false
    weaponWheelSelection = -1
    automaticHoldEngaged = false
    automaticHoldTimer.stop()
    fireTimer.stop()
    pistolSound.stop()
    akSingleSound.stop()
    automaticSound.stop()
    mp5SingleSound.stop()
    mp5AutomaticSound.stop()
    revolverSound.stop()
    bazookaLaunchSound.stop()
    rocketExplosionSound.stop()
    targetHitSound.stop()
    weaponReadySound.stop()
    trickAnimation.stop()
    trickAngle = 0
    weaponSpinSound.stop()
    particles = []
    pendingEffects = []
    targetVisible = false
    targetRespawnTimer.stop()
  }
  function playWeaponSound() {
    if (weapon === "mp5a3") mp5SingleSound.play()
    else if (spec.automatic) akSingleSound.play()
    else if (weapon === "revolver") revolverSound.play()
    else if (weapon === "bazooka" || weapon === "thick-bazooka") {
      bazookaLaunchSound.volume = weapon === "thick-bazooka" ? 1.0 : 0.72
      bazookaLaunchSound.play()
    }
    else pistolSound.play()
  }
  function shoot(withSound) {
    if (!armed) return
    if (withSound === undefined || withSound) playWeaponSound()
    recoil = spec.recoil
    flash = 1
    var angle = aimAngle * Math.PI / 180
    var cosA = Math.cos(angle)
    var sinA = Math.sin(angle)
    var localMuzzleX = (spec.muzzleX - spec.gripX) * spec.scale
    var localMuzzleY = (spec.muzzleY - spec.gripY) * spec.scale * (aimFlipped ? -1 : 1)
    var muzzleX = gunX - recoil * cosA + localMuzzleX * cosA - localMuzzleY * sinA
    var muzzleY = gunY - recoil * sinA + localMuzzleX * sinA + localMuzzleY * cosA
    var count = spec.particles
    var power = spec.power
    var next = particles.slice()
    var speed = (17 + Math.random() * 12) * power
    var spread = (Math.random() - 0.5) * 8 * power
    if (weapon === "bazooka" || weapon === "thick-bazooka")
      next.push({ x: muzzleX, y: muzzleY, vx: 6 * power * cosA, vy: 6 * power * sinA, life: 1, age: 0, explodeAt: 1.52, size: 5 * power, boomScale: weapon === "thick-bazooka" ? 2.5 : 1, kind: 3 })
    else
      next.push({ x: muzzleX, y: muzzleY, vx: speed * cosA, vy: speed * sinA, life: 1, size: 3.6 + power * 0.6, bounces: 0, kind: 6 })
    for (var i = 0; i < count; i++) {
      speed = (7 + Math.random() * 17) * power
      spread = (Math.random() - 0.5) * 13 * power
      next.push({ x: muzzleX, y: muzzleY, vx: speed * cosA - spread * sinA, vy: speed * sinA + spread * cosA, life: 0.6 + Math.random() * 0.4, size: 1 + Math.random() * 4 * power, kind: 1 })
    }
    if (spec.ejectsCase !== false && weapon !== "bazooka" && weapon !== "thick-bazooka")
      next.push({ x: gunX - sinA * 18, y: gunY + cosA * 18, vx: -sinA * (4 + Math.random() * 3) - cosA * 2, vy: cosA * (4 + Math.random() * 3) - sinA * 2, life: 1, size: 3, angle: Math.random() * Math.PI * 2, spin: (Math.random() - 0.5) * 0.5, bounces: 0, kind: 2 })
    if (weapon === "revolver") {
      for (var smoke = 0; smoke < 7; smoke++)
        next.push({ x: muzzleX, y: muzzleY, vx: (1.2 + Math.random() * 2.6) * cosA + (Math.random() - 0.5) * 1.5, vy: (1.2 + Math.random() * 2.6) * sinA - Math.random() * 1.3, life: 0.55 + Math.random() * 0.3, size: 4 + Math.random() * 5, kind: 5 })
    }
    particles = next
  }

  PanelWindow {
    id: window
    visible: root.armed
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "blow-off-some-steam"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    mask: Region {
      width: window.width
      height: window.height
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          root.holster()
          event.accepted = true
        }
      }
    }

    Canvas {
      id: canvas
      anchors.fill: parent
      renderStrategy: Canvas.Threaded
      onPaint: {
        var c = getContext("2d")
        c.clearRect(0, 0, width, height)
        c.globalAlpha = 1

        if (root.armed && root.targetVisible) {
          c.fillStyle = "#eee9df"
          c.beginPath(); c.arc(root.targetX, root.targetY, root.targetRadius, 0, Math.PI * 2); c.fill()
          c.fillStyle = "#c92f35"
          c.beginPath(); c.arc(root.targetX, root.targetY, root.targetRadius * 0.72, 0, Math.PI * 2); c.fill()
          c.fillStyle = "#eee9df"
          c.beginPath(); c.arc(root.targetX, root.targetY, root.targetRadius * 0.43, 0, Math.PI * 2); c.fill()
          c.fillStyle = "#c92f35"
          c.beginPath(); c.arc(root.targetX, root.targetY, root.targetRadius * 0.18, 0, Math.PI * 2); c.fill()
        }

        for (var i = 0; i < root.particles.length; i++) {
          var p = root.particles[i]
          c.globalAlpha = Math.max(0, p.life)
          if (p.kind === 1) {
            c.fillStyle = i % 3 === 0 ? "#ff4d2e" : (i % 2 === 0 ? "#ffd24a" : "#ff8a2a")
            c.beginPath(); c.arc(p.x, p.y, p.size * p.life, 0, Math.PI * 2); c.fill()
          } else if (p.kind === 3) {
            var rocketAngle = Math.atan2(p.vy, p.vx)
            c.save()
            c.translate(p.x, p.y)
            c.rotate(rocketAngle)
            c.fillStyle = "#ffb52e"
            c.beginPath(); c.moveTo(-22, 0); c.lineTo(-34, -7); c.lineTo(-30, 0); c.lineTo(-34, 7); c.closePath(); c.fill()
            c.fillStyle = "#d7d9d2"
            c.fillRect(-18, -3, 25, 6)
            c.fillStyle = "#79806f"
            c.beginPath(); c.moveTo(12, 0); c.lineTo(5, -5); c.lineTo(5, 5); c.closePath(); c.fill()
            c.restore()
          } else if (p.kind === 4) {
            c.globalAlpha = Math.max(0, p.life) * 0.85
            c.strokeStyle = p.life > 0.55 ? "#fff4ad" : "#ff6a2b"
            c.lineWidth = Math.max(2, 14 * p.life)
            c.beginPath(); c.arc(p.x, p.y, p.maxRadius * (1 - p.life), 0, Math.PI * 2); c.stroke()
          } else if (p.kind === 5) {
            c.fillStyle = "#8fd8d5cc"
            c.beginPath(); c.arc(p.x, p.y, p.size * (1.3 - p.life), 0, Math.PI * 2); c.fill()
          } else if (p.kind === 6) {
            var bulletAngle = Math.atan2(p.vy, p.vx)
            c.save()
            c.translate(p.x, p.y)
            c.rotate(bulletAngle)
            c.fillStyle = "#efe0a4"
            c.fillRect(-p.size * 1.8, -p.size * 0.52, p.size * 2.3, p.size * 1.04)
            c.fillStyle = "#bf7b2d"
            c.beginPath()
            c.moveTo(p.size * 1.45, 0)
            c.lineTo(p.size * 0.45, -p.size * 0.52)
            c.lineTo(p.size * 0.45, p.size * 0.52)
            c.closePath()
            c.fill()
            c.restore()
          } else if (p.kind === 7) {
            c.fillStyle = "#9da2a0"
            c.beginPath(); c.arc(p.x, p.y, p.size * (1.35 - p.life * 0.35), 0, Math.PI * 2); c.fill()
          } else if (p.kind === 2) {
            c.fillStyle = "#d6a84b"
            c.save()
            c.translate(p.x, p.y)
            c.rotate(p.angle)
            c.fillRect(-p.size * 0.9, -p.size * 0.5, p.size * 1.8, p.size)
            c.restore()
          }
        }

        c.globalAlpha = root.armed ? 0.22 : 0
        c.fillStyle = "#000000"
        c.beginPath(); c.ellipse(root.gunX, root.gunY + 45, root.spec.width * root.spec.scale * 0.32, 8, 0, 0, Math.PI * 2); c.fill()
        c.globalAlpha = 1

        if (root.flash > 0) {
          var angle = root.aimAngle * Math.PI / 180
          var cosA = Math.cos(angle)
          var sinA = Math.sin(angle)
          var localX = (root.spec.muzzleX - root.spec.gripX) * root.spec.scale
          var localY = (root.spec.muzzleY - root.spec.gripY) * root.spec.scale * (root.aimFlipped ? -1 : 1)
          var mx = root.gunX - root.recoil * cosA + localX * cosA - localY * sinA
          var my = root.gunY - root.recoil * sinA + localX * sinA + localY * cosA
          c.globalAlpha = root.flash
          c.save()
          c.translate(mx, my)
          c.rotate(angle)
          if (root.spec.flashStyle === "revolver") {
            c.fillStyle = "#fff2a0"
            c.beginPath()
            c.moveTo(-5, 0); c.lineTo(9, -7); c.lineTo(13, -20); c.lineTo(19, -8)
            c.lineTo(38, -13); c.lineTo(27, 0); c.lineTo(39, 13); c.lineTo(18, 8)
            c.lineTo(12, 21); c.lineTo(8, 7); c.closePath(); c.fill()
            c.globalAlpha = root.flash * 0.8
            c.fillStyle = "#ff762b"
            c.beginPath(); c.moveTo(0, 0); c.lineTo(27, -6); c.lineTo(20, 0); c.lineTo(28, 6); c.closePath(); c.fill()
          } else {
            c.fillStyle = "#ffe86b"
            c.beginPath(); c.moveTo(0,0); c.lineTo(29,-10); c.lineTo(20,0); c.lineTo(33,9); c.closePath(); c.fill()
          }
          c.restore()
        }
      }
    }

    Image {
      visible: root.armed
      x: root.gunX - root.spec.gripX * root.spec.scale - root.recoil * Math.cos(root.aimAngle * Math.PI / 180)
      y: root.gunY - root.spec.gripY * root.spec.scale - root.recoil * Math.sin(root.aimAngle * Math.PI / 180)
      width: root.spec.width * root.spec.scale
      height: root.spec.height * root.spec.scale
      source: Qt.resolvedUrl(root.spec.image)
      fillMode: Image.PreserveAspectFit
      smooth: false
      transform: [
        Scale {
          origin.x: root.spec.gripX * root.spec.scale
          origin.y: root.spec.gripY * root.spec.scale
          yScale: root.aimFlipped ? -1 : 1
          Behavior on yScale {
            NumberAnimation { duration: 120; easing.type: Easing.InOutQuad }
          }
        },
        Rotation {
          origin.x: root.spec.gripX * root.spec.scale
          origin.y: root.spec.gripY * root.spec.scale
          axis.x: 0
          axis.y: 0
          axis.z: 1
          angle: root.trickAngle
        },
        Rotation {
          origin.x: root.spec.gripX * root.spec.scale
          origin.y: root.spec.gripY * root.spec.scale
          angle: root.aimAngle
        }
      ]
    }

    Item {
      visible: root.weaponWheelOpen
      anchors.fill: parent
      z: 40

      Repeater {
        model: root.weaponOptions
        delegate: Item {
          id: wheelTile
          required property int index
          required property var modelData
          readonly property real tileAngle: (-90 + index * 60) * Math.PI / 180
          width: 94
          height: 82
          x: root.weaponWheelX + Math.cos(tileAngle) * 116 - width / 2
          y: root.weaponWheelY + Math.sin(tileAngle) * 116 - height / 2

          Canvas {
            id: hex
            anchors.fill: parent
            onPaint: {
              var c = getContext("2d")
              c.clearRect(0, 0, width, height)
              c.beginPath()
              c.moveTo(width * 0.25, 2)
              c.lineTo(width * 0.75, 2)
              c.lineTo(width - 2, height * 0.5)
              c.lineTo(width * 0.75, height - 2)
              c.lineTo(width * 0.25, height - 2)
              c.lineTo(2, height * 0.5)
              c.closePath()
              c.fillStyle = root.weaponWheelSelection === wheelTile.index
                ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.72)
                : "#292d38"
              c.fill()
              c.strokeStyle = root.weaponWheelSelection === wheelTile.index ? root.accent : "#75809a"
              c.lineWidth = root.weaponWheelSelection === wheelTile.index ? 3 : 2
              c.stroke()
            }
            Component.onCompleted: requestPaint()
            Connections {
              target: root
              function onWeaponWheelSelectionChanged() { hex.requestPaint() }
              function onAccentChanged() { hex.requestPaint() }
            }
          }

          Image {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 14
            width: Math.min(64, wheelTile.modelData.clip.width * 1.15)
            height: 30
            source: Qt.resolvedUrl(wheelTile.modelData.image)
            sourceClipRect: wheelTile.modelData.clip
            fillMode: Image.PreserveAspectFit
            smooth: false
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 52
            text: wheelTile.modelData.name
            color: root.weaponWheelSelection === wheelTile.index ? "#ffffff" : "#d4d8e3"
            font.pixelSize: 11
            font.bold: true
          }
        }
      }

      Rectangle {
        x: root.weaponWheelX - width / 2
        y: root.weaponWheelY - height / 2
        width: 56
        height: 56
        radius: width / 2
        color: "#d91b1e26"
        border.width: 2
        border.color: "#75809a"
        Text {
          anchors.centerIn: parent
          text: "󰜃"
          color: "#d4d8e3"
          font.pixelSize: 22
        }
      }
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      enabled: root.armed
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      cursorShape: Qt.CrossCursor
      onPositionChanged: function(event) {
        if (root.weaponWheelOpen) {
          root.updateWeaponWheel(event.x, event.y)
          return
        }
        root.pointerX = event.x
        root.pointerY = event.y
        if (!root.gunPositioned) {
          root.gunX = event.x - root.followDistance
          root.gunY = event.y
          root.gunPositioned = true
        }
      }
      onPressed: function(event) {
        if (event.button === Qt.MiddleButton) {
          root.openWeaponWheel(event.x, event.y)
          return
        }
        if (event.button === Qt.RightButton) {
          weaponSpinSound.stop()
          weaponSpinSound.play()
          trickAnimation.restart()
          return
        }
        root.automaticHoldEngaged = false
        if (root.spec.automatic) {
          automaticHoldTimer.restart()
        } else root.shoot()
      }
      onReleased: function(event) {
        if (event.button === Qt.MiddleButton) {
          root.closeWeaponWheel(true)
          return
        }
        if (event.button === Qt.RightButton) return
        var pendingSingleShot = root.spec.automatic && !root.automaticHoldEngaged && automaticHoldTimer.running
        automaticHoldTimer.stop()
        fireTimer.stop()
        automaticSound.stop()
        mp5AutomaticSound.stop()
        if (pendingSingleShot) root.shoot()
      }
      onCanceled: {
        root.closeWeaponWheel(false)
        automaticHoldTimer.stop()
        fireTimer.stop()
        automaticSound.stop()
        mp5AutomaticSound.stop()
      }
    }

    Rectangle {
      visible: root.armed
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      anchors.margins: 18
      width: hint.implicitWidth + 24
      height: hint.implicitHeight + 14
      radius: 8
      color: "#b3151719"
      Text {
        id: hint
        anchors.centerIn: parent
        text: root.weaponName + (root.spec.automatic ? " · click/hold to fire" : " · click to fire") + " · middle-hold weapon wheel · right-click spin · Esc holster"
        color: "#d9ffffff"
        font.pixelSize: 12
      }
    }
  }

  Timer {
    id: automaticHoldTimer
    interval: 190
    repeat: false
    onTriggered: {
      root.automaticHoldEngaged = true
      root.shoot(false)
      if (root.weapon === "mp5a3") mp5AutomaticSound.play()
      else automaticSound.play()
      fireTimer.start()
    }
  }

  NumberAnimation {
    id: trickAnimation
    target: root
    property: "trickAngle"
    from: 0
    to: 360
    duration: 560
    easing.type: Easing.InOutCubic
    onStopped: root.trickAngle = 0
  }

  Timer {
    id: fireTimer
    interval: root.spec.interval
    repeat: true
    onTriggered: root.shoot(false)
  }

  SoundEffect {
    id: pistolSound
    source: Qt.resolvedUrl("sounds/pistol-shot.wav")
    volume: 0.62
  }

  SoundEffect {
    id: akSingleSound
    source: Qt.resolvedUrl("sounds/ak-single-shot.wav")
    volume: 0.56
  }

  SoundEffect {
    id: mp5SingleSound
    source: Qt.resolvedUrl("sounds/mp5-single-shot.wav")
    volume: 0.56
  }

  SoundEffect {
    id: mp5AutomaticSound
    source: Qt.resolvedUrl("sounds/mp5-automatic-fire.wav")
    loops: SoundEffect.Infinite
    volume: 0.5
  }

  SoundEffect {
    id: automaticSound
    source: Qt.resolvedUrl("sounds/automatic-fire.wav")
    loops: SoundEffect.Infinite
    volume: 0.48
  }

  SoundEffect {
    id: revolverSound
    source: Qt.resolvedUrl("sounds/revolver-shot.wav")
    volume: 0.66
  }

  SoundEffect {
    id: bazookaLaunchSound
    source: Qt.resolvedUrl("sounds/bazooka-launch.wav")
    volume: 0.72
  }

  SoundEffect {
    id: rocketExplosionSound
    source: Qt.resolvedUrl("sounds/bazooka-explosion.wav")
    volume: 0.76
  }

  SoundEffect {
    id: targetHitSound
    source: Qt.resolvedUrl("sounds/target-hit.wav")
    volume: 0.34
  }

  SoundEffect {
    id: weaponSpinSound
    source: Qt.resolvedUrl("sounds/weapon-spin.wav")
    volume: 0.30
  }

  SoundEffect {
    id: weaponReadySound
    source: Qt.resolvedUrl("sounds/weapon-ready.wav")
    volume: 0.34
  }

  SoundEffect {
    id: weaponWheelHoverSound
    source: Qt.resolvedUrl("sounds/weapon-hover.wav")
    volume: 0.22
  }

  Timer {
    id: targetRespawnTimer
    interval: 700
    onTriggered: if (root.armed && root.targetsEnabled) root.spawnTarget()
  }

  Timer {
    interval: 16
    running: root.armed
    repeat: true
    onTriggered: {
      if (root.gunPositioned) {
        var dx = root.pointerX - root.gunX
        var dy = root.pointerY - root.gunY
        var distance = Math.sqrt(dx * dx + dy * dy)
        if (distance > 0.001) {
          var unitX = dx / distance
          var unitY = dy / distance
          var targetX = root.pointerX - unitX * root.followDistance
          var targetY = root.pointerY - unitY * root.followDistance
          root.gunX += (targetX - root.gunX) * 0.16
          root.gunY += (targetY - root.gunY) * 0.16
          root.aimAngle = Math.atan2(root.pointerY - root.gunY, root.pointerX - root.gunX) * 180 / Math.PI
          // Hysteresis prevents rapid mirror-state chatter near vertical aim.
          if (!root.aimFlipped && (root.aimAngle > 100 || root.aimAngle < -100)) root.aimFlipped = true
          else if (root.aimFlipped && root.aimAngle > -80 && root.aimAngle < 80) root.aimFlipped = false
        }
      }
      root.recoil *= 0.72
      root.flash *= 0.56
      var next = []
      for (var i = 0; i < root.particles.length; i++) {
        var p = root.particles[i]
        if (p.kind === 6) {
          p.x += p.vx
          p.y += p.vy
          // At desktop distances the initial trajectory should read as flat.
          // Apply only a subtle drop after the first ricochet.
          if (p.bounces > 0) p.vy += 0.025
          p.vx *= 0.998
          p.vy *= 0.998

          var bulletRadius = p.size * 1.5
          if (root.projectileHitsTarget(p, bulletRadius)) {
            root.hitTarget()
            continue
          }
          var bounced = false
          if (p.x <= bulletRadius && p.vx < 0) {
            p.x = bulletRadius
            p.vx = -p.vx * 0.78
            bounced = true
          } else if (p.x >= window.width - bulletRadius && p.vx > 0) {
            p.x = window.width - bulletRadius
            p.vx = -p.vx * 0.78
            bounced = true
          }
          if (p.y <= bulletRadius && p.vy < 0) {
            p.y = bulletRadius
            p.vy = -p.vy * 0.72
            bounced = true
          } else if (p.y >= window.height - bulletRadius && p.vy > 0) {
            p.y = window.height - bulletRadius
            p.vy = -p.vy * 0.68
            p.vx *= 0.88
            bounced = true
          }
          if (bounced) p.bounces += 1
          p.life -= 0.006 + p.bounces * 0.0015
          if (p.life > 0 && p.bounces < 7) next.push(p)
          continue
        }
        if (p.kind === 2) {
          p.x += p.vx
          p.y += p.vy
          p.vy += 0.45
          p.angle += p.spin

          var caseRadius = p.size
          if (p.x <= caseRadius && p.vx < 0) {
            p.x = caseRadius
            p.vx = -p.vx * 0.58
            p.spin *= -0.8
            p.bounces += 1
          } else if (p.x >= window.width - caseRadius && p.vx > 0) {
            p.x = window.width - caseRadius
            p.vx = -p.vx * 0.58
            p.spin *= -0.8
            p.bounces += 1
          }
          if (p.y <= caseRadius && p.vy < 0) {
            p.y = caseRadius
            p.vy = -p.vy * 0.5
            p.bounces += 1
          } else if (p.y >= window.height - caseRadius && p.vy > 0) {
            p.y = window.height - caseRadius
            p.vy = -p.vy * 0.46
            p.vx *= 0.72
            p.spin *= 0.7
            p.bounces += 1
          }
          p.vx *= 0.992
          p.life -= 0.018 + p.bounces * 0.002
          if (p.life > 0 && p.bounces < 8) next.push(p)
          continue
        }
        if (p.kind === 4) {
          p.life -= 0.025
          if (p.life > 0) next.push(p)
          continue
        }
        if (p.kind === 3) {
          p.x += p.vx
          p.y += p.vy
          p.age += 0.016
          var rocketRadius = Math.max(8, p.size * 2)
          if (root.projectileHitsTarget(p, rocketRadius)) {
            root.hitTarget()
            root.playRocketExplosion(p)
            next = next.concat(root.rocketBlastParticles(p))
            continue
          }
          if (p.x <= rocketRadius && p.vx < 0) {
            p.x = rocketRadius
            p.vx = -p.vx * 0.84
          } else if (p.x >= window.width - rocketRadius && p.vx > 0) {
            p.x = window.width - rocketRadius
            p.vx = -p.vx * 0.84
          }
          if (p.y <= rocketRadius && p.vy < 0) {
            p.y = rocketRadius
            p.vy = -p.vy * 0.84
          } else if (p.y >= window.height - rocketRadius && p.vy > 0) {
            p.y = window.height - rocketRadius
            p.vy = -p.vy * 0.84
          }
          if (p.age >= p.explodeAt) {
            var boomScale = p.boomScale || 1
            var blastRadius = 180 * boomScale
            if (root.targetWithinBlast(p.x, p.y, blastRadius)) root.hitTarget()
            root.playRocketExplosion(p)
            next = next.concat(root.rocketBlastParticles(p))
          } else if (p.x > -80 && p.x < window.width + 80 && p.y > -80 && p.y < window.height + 80) next.push(p)
          continue
        }
        p.x += p.vx; p.y += p.vy
        p.vx *= 0.985; p.vy += 0.12
        p.life -= 0.035
        if (p.life > 0 && p.x > -80 && p.x < window.width + 80 && p.y > -80 && p.y < window.height + 80) next.push(p)
      }
      root.particles = next.concat(root.pendingEffects)
      root.pendingEffects = []
      canvas.requestPaint()
    }
  }
}
