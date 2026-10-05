import QtQuick

// A frozen frame clipped along the actual blade angle. Each half has its own physics.
Item {
  id: piece
  property bool active: false
  property real age: 0
  property real vx: 0
  property real vy: 0
  property real spin: 0
  property real cutAngle: 0
  property int side: 1
  property int frame: 0
  property bool mirrored: false
  z: 2
  visible: active
  opacity: Math.min(1, Math.max(0, (1.2 - age) / 0.3))
  function start(px, py, angle, half, frozenFrame, flipped) {
    x = px; y = py; rotation = 0; age = 0
    cutAngle = angle; side = half; frame = frozenFrame; mirrored = flipped
    vx = -Math.sin(angle) * half * 130
    vy = Math.cos(angle) * half * 100 - 95
    spin = half * (100 + Math.random() * 110)
    active = true; sprite.requestPaint()
  }
  function advance(dt) {
    if (!active) return
    age += dt
    if (age >= 1.2) { active = false; return }
    x += vx * dt; y += vy * dt; vy += 780 * dt; rotation += spin * dt
  }
  Canvas {
    id: sprite
    x: -56; y: -56; width: 112; height: 112
    readonly property url sheet: Qt.resolvedUrl("assets/fly-spritesheet.png")
    Component.onCompleted: loadImage(sheet)
    onImageLoaded: requestPaint()
    onPaint: {
      var c = getContext("2d"); c.reset(); c.clearRect(0, 0, width, height)
      if (!piece.active || !isImageLoaded(sheet)) return
      c.translate(56, 50)
      c.rotate(piece.cutAngle)
      c.beginPath(); c.rect(-160, piece.side > 0 ? 0 : -160, 320, 160); c.clip()
      c.rotate(-piece.cutAngle)
      c.translate(0, 6)
      c.scale(piece.mirrored ? -1 : 1, 1)
      c.drawImage(sheet, (piece.frame % 4) * 443, Math.floor(piece.frame / 4) * 443, 443, 443, -44, -54, 80, 80)
    }
  }
}
