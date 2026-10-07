import QtQuick

// A medal coin with a star: 0 bronze, 1 silver, 2 gold, 3 platinum.
// `shine` sweeps a highlight across it from 0 to 1; outside that range it rests.
Canvas {
  id: medal
  property int rank: 0
  property real shine: -1
  readonly property var faces: ["#cd8448", "#d3d8dc", "#f4c542", "#c4eef3"]
  readonly property var rims: ["#7e4620", "#7f888f", "#9c700e", "#5e9aa6"]
  width: 16; height: 16
  onRankChanged: requestPaint()
  onShineChanged: requestPaint()
  onWidthChanged: requestPaint()
  onPaint: {
    var c = getContext("2d")
    c.reset(); c.clearRect(0, 0, width, height)
    var r = Math.min(width, height) / 2, cx = width / 2, cy = height / 2
    var face = faces[Math.max(0, Math.min(3, rank))], rim = rims[Math.max(0, Math.min(3, rank))]
    c.beginPath(); c.arc(cx, cy, r - 0.5, 0, Math.PI * 2); c.fillStyle = rim; c.fill()
    // Lit from the top left.
    var light = c.createRadialGradient(cx - r * 0.35, cy - r * 0.4, r * 0.1, cx, cy, r)
    light.addColorStop(0, Qt.lighter(face, 1.25)); light.addColorStop(1, face)
    c.beginPath(); c.arc(cx, cy, r * 0.8, 0, Math.PI * 2); c.fillStyle = light; c.fill()
    c.beginPath()
    for (var i = 0; i < 10; i++) {
      var a = -Math.PI / 2 + i * Math.PI / 5, d = (i % 2 ? 0.22 : 0.5) * r
      if (i === 0) c.moveTo(cx + Math.cos(a) * d, cy + Math.sin(a) * d)
      else c.lineTo(cx + Math.cos(a) * d, cy + Math.sin(a) * d)
    }
    c.closePath(); c.fillStyle = rim; c.fill()
    if (shine >= 0 && shine <= 1) {
      c.save()
      c.beginPath(); c.arc(cx, cy, r - 0.5, 0, Math.PI * 2); c.clip()
      var x = -r + shine * 4 * r
      var band = c.createLinearGradient(x - r * 0.5, 0, x + r * 0.5, 0)
      band.addColorStop(0, "rgba(255,255,255,0)"); band.addColorStop(0.5, "rgba(255,255,255,0.85)"); band.addColorStop(1, "rgba(255,255,255,0)")
      c.translate(cx, cy); c.rotate(-0.5); c.translate(-cx, -cy)
      c.fillStyle = band; c.fillRect(x - r * 0.5, -r, r, height + 2 * r)
      c.restore()
    }
  }
}
