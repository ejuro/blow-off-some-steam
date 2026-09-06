import QtQuick
import "EffectDrawing.js" as Drawing

Canvas {
  id: sprite
  property var particle: null
  property int particleIndex: 0
  property real paintAlpha: 1
  visible: false
  // Small surfaces paint on the GUI thread so geometry and texture are
  // submitted together. No fullscreen raster buffer or delayed moving texture.
  renderStrategy: Canvas.Immediate

  function sync(state, index, alpha, blend) {
    if (!particle) particle = ({})
    var p = particle
    p.kind = state.kind; p.size = state.size; p.maxRadius = state.maxRadius
    p.vx = state.vx; p.vy = state.vy
    p.x = state.previousX === undefined ? state.x : state.previousX + (state.x - state.previousX) * blend
    p.y = state.previousY === undefined ? state.y : state.previousY + (state.y - state.previousY) * blend
    p.life = state.previousLife === undefined ? state.life : state.previousLife + (state.life - state.previousLife) * blend
    p.angle = state.previousAngle === undefined ? state.angle : state.previousAngle + (state.angle - state.previousAngle) * blend
    particleIndex = index
    paintAlpha = alpha
    var radius = p.kind === 3 ? 36
      : p.kind === 4 ? p.maxRadius + 8
      : p.kind === 6 ? p.size * 2
      : p.kind === 2 ? p.size * 1.1
      : p.kind === 1 ? p.size * p.life
      : p.kind === 5 ? p.size * (1.3 - p.life)
      : p.size * (1.35 - p.life * 0.35)
    // Integer origins retain the original raster phase. Quantized dimensions
    // avoid reallocating a texture for every tiny change in particle radius.
    var extent = Math.ceil((radius + 2) / 8) * 8
    width = extent * 2
    height = width
    x = Math.floor(p.x) - extent
    y = Math.floor(p.y) - extent
    z = index
    visible = true
    requestPaint()
  }

  onPaint: {
    if (!particle) return
    var c = getContext("2d")
    c.reset()
    c.clearRect(0, 0, width, height)
    c.translate(-x, -y)
    c.globalAlpha = paintAlpha
    Drawing.particle(c, particle, particleIndex)
  }
}
