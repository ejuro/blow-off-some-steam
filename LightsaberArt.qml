import QtQuick
import qs.Commons

// Same small logical sprite grid and dark outlines as the conventional guns.
Canvas {
  id: art
  property color accentColor: Color.accent
  // 0 shows the bare hilt; 1 is the fully extended blade.
  property real ignition: 1
  onIgnitionChanged: requestPaint()
  implicitWidth: 96
  implicitHeight: 24
  antialiasing: false
  onAccentColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  Component.onCompleted: requestPaint()
  onPaint: {
    var c = getContext("2d")
    c.reset(); c.clearRect(0, 0, width, height)
    var scale = Math.min(width / 96, height / 24)
    c.translate((width - 96 * scale) / 2, (height - 24 * scale) / 2)
    c.scale(scale, scale)
    var reach = Math.round(65 * Math.max(0, Math.min(1, ignition)))
    if (reach > 0) {
      c.fillStyle = accentColor; c.globalAlpha = 0.10; c.fillRect(27, 3, reach + 2, 18)
      c.globalAlpha = 0.22; c.fillRect(27, 6, reach + 2, 12)
      c.globalAlpha = 1; c.fillStyle = accentColor; c.fillRect(27, 9, reach, 6); c.fillRect(27 + reach, 10, 2, 4)
      c.fillStyle = "#f1fff8"; c.fillRect(28, 11, reach - 1, 2)
    }
    // Stepped steel emitter, ribbed grip, pommel, and an illuminated switch.
    c.fillStyle = "#171b24"; c.fillRect(2, 7, 25, 10); c.fillRect(21, 5, 8, 14)
    c.fillStyle = "#536170"; c.fillRect(3, 8, 19, 8); c.fillRect(22, 6, 6, 12)
    c.fillStyle = "#aebac2"; c.fillRect(4, 8, 17, 2); c.fillRect(22, 6, 6, 3)
    c.fillStyle = "#2b3341"; c.fillRect(5, 11, 14, 4)
    for (var i = 0; i < 4; i++) { c.fillStyle = "#8995a1"; c.fillRect(6 + i * 3, 10, 1, 5) }
    c.fillStyle = "#d7e1df"; c.fillRect(2, 8, 2, 7); c.fillRect(25, 7, 2, 9)
    c.fillStyle = accentColor; c.fillRect(18, 9, 3, 3)
    c.fillStyle = "#34414c"; c.fillRect(22, 15, 6, 2)
  }
}
