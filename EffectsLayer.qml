import QtQuick
import "EffectDrawing.js" as Drawing

Item {
  id: effects
  required property var arena
  readonly property var gunFrame: ({ armed: arena.armed, spec: arena.spec,
    gunX: arena.renderGunX, gunY: arena.renderGunY, aimAngle: arena.renderAimAngle,
    aimFlipped: arena.aimFlipped, recoil: arena.renderRecoil, flash: arena.renderFlash })
  property var pool: []
  property int used: 0

  function clear() {
    for (var i = 0; i < pool.length; i++) pool[i].destroy()
    pool = []
    used = 0
  }

  // Retain slots throughout an armed session, in original particle order.
  // Expired particles hide their slots; bursts reuse them without rebuilding
  // a Repeater model or allocating a new QML object per simulation update.
  function requestPaint() {
    var particles = arena.particles
    var alpha = 1
    for (var i = 0; i < particles.length; i++) {
      if (i >= pool.length) pool.push(particleComponent.createObject(particleLayer))
      var p = particles[i]
      // Canvas ignores alpha values above one. Preserve that behavior, even
      // for the few newly spawned sparks whose initial life exceeds one.
      var blend = arena.simulationBlend
      var life = p.previousLife === undefined ? p.life : p.previousLife + (p.life - p.previousLife) * blend
      if (life <= 1) alpha = Math.max(0, life)
      if (p.kind === 4) alpha = Math.max(0, life) * 0.85
      pool[i].sync(p, i, alpha, blend)
    }
    for (var j = particles.length; j < used; j++) pool[j].visible = false
    used = particles.length
    shadow.requestPaint()
    muzzle.requestPaint()
  }

  Component { id: particleComponent; EffectParticle {} }

  Canvas {
    id: target
    x: Math.floor(arena.targetX - arena.targetRadius - 2)
    y: Math.floor(arena.targetY - arena.targetRadius - 2)
    width: Math.ceil(arena.targetRadius * 2 + 4)
    height: width
    visible: arena.armed && arena.targetVisible
    onXChanged: requestPaint()
    onYChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()
    onPaint: {
      var c = getContext("2d")
      c.reset()
      c.clearRect(0, 0, width, height)
      c.translate(-x, -y)
      var radii = [1, 0.72, 0.43, 0.18]
      for (var i = 0; i < radii.length; i++) {
        c.fillStyle = i % 2 ? "#c92f35" : "#eee9df"
        c.beginPath()
        c.arc(arena.targetX, arena.targetY, arena.targetRadius * radii[i], 0, Math.PI * 2)
        c.fill()
      }
    }
  }

  Item { id: particleLayer; anchors.fill: parent; z: 1 }

  Canvas {
    id: shadow
    z: 2
    readonly property real radiusX: arena.spec.width * arena.spec.scale * 0.32
    x: Math.floor(arena.renderGunX - radiusX - 2)
    y: Math.floor(arena.renderGunY + 35)
    width: Math.ceil(radiusX * 2 + 4)
    height: 20
    visible: arena.armed
    onPaint: {
      var c = getContext("2d")
      c.reset()
      c.clearRect(0, 0, width, height)
      c.globalAlpha = 0.22
      c.fillStyle = "#000000"
      c.beginPath()
      c.ellipse(arena.renderGunX - x, arena.renderGunY + 45 - y, radiusX, 8, 0, 0, Math.PI * 2)
      c.fill()
    }
  }

  Canvas {
    id: muzzle
    z: 3
    readonly property real angle: arena.renderAimAngle * Math.PI / 180
    readonly property real localX: (arena.spec.muzzleX - arena.spec.gripX) * arena.spec.scale
    readonly property real localY: (arena.spec.muzzleY - arena.spec.gripY) * arena.spec.scale * (arena.aimFlipped ? -1 : 1)
    x: Math.floor(arena.renderGunX - arena.renderRecoil * Math.cos(angle) + localX * Math.cos(angle) - localY * Math.sin(angle)) - 48
    y: Math.floor(arena.renderGunY - arena.renderRecoil * Math.sin(angle) + localX * Math.sin(angle) + localY * Math.cos(angle)) - 48
    width: 96
    height: 96
    visible: arena.armed && arena.renderFlash > 0
    onPaint: {
      var c = getContext("2d")
      c.reset()
      c.clearRect(0, 0, width, height)
      c.translate(-x, -y)
      Drawing.flash(c, effects.gunFrame)
    }
  }
}
