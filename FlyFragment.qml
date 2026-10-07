import QtQuick
import QtQuick.Effects

// A frozen frame of a killed fly. Saber kills split it along the blade angle
// into two halves with their own physics; a shot or blast sends the whole
// body tumbling (side 0), squashed flat for an instant on impact.
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
  property bool golden: false
  // Squash on impact for whole bodies: wide and flat, springing back in 0.14 s.
  readonly property real squash: side === 0 ? Math.max(0, 1 - age / 0.14) : 0
  z: 2
  visible: active
  opacity: Math.min(1, Math.max(0, (1.2 - age) / 0.3))
  function start(px, py, angle, half, frozenFrame, flipped, isGolden) {
    x = px; y = py; rotation = 0; age = 0
    cutAngle = angle; side = half; frame = frozenFrame; mirrored = flipped; golden = !!isGolden
    vx = -Math.sin(angle) * half * 130
    vy = Math.cos(angle) * half * 100 - 95
    spin = half * (100 + Math.random() * 110)
    active = true; sprite.requestPaint()
  }
  function tumble(px, py, frozenFrame, flipped, isGolden, velocityX, velocityY, spinRate) {
    x = px; y = py; rotation = 0; age = 0
    cutAngle = 0; side = 0; frame = frozenFrame; mirrored = flipped; golden = !!isGolden
    vx = velocityX; vy = velocityY; spin = spinRate
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
    transform: Scale { origin.x: 56; origin.y: 56; xScale: 1 + 0.5 * piece.squash; yScale: 1 - 0.45 * piece.squash }
    layer.enabled: piece.golden
    layer.effect: MultiEffect { colorization: 0.85; colorizationColor: "#ffc02e"; brightness: 0.15 }
    readonly property url sheet: Qt.resolvedUrl("assets/fly-spritesheet.png")
    Component.onCompleted: loadImage(sheet)
    onImageLoaded: requestPaint()
    onPaint: {
      var c = getContext("2d"); c.reset(); c.clearRect(0, 0, width, height)
      if (!piece.active || !isImageLoaded(sheet)) return
      c.translate(56, 50)
      if (piece.side !== 0) {
        c.rotate(piece.cutAngle)
        c.beginPath(); c.rect(-160, piece.side > 0 ? 0 : -160, 320, 160); c.clip()
        c.rotate(-piece.cutAngle)
      }
      c.translate(0, 6)
      c.scale(piece.mirrored ? -1 : 1, 1)
      c.drawImage(sheet, (piece.frame % 4) * 443, Math.floor(piece.frame / 4) * 443, 443, 443, -44, -54, 80, 80)
    }
  }
}
