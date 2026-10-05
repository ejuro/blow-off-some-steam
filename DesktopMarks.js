.import "CutGeometry.js" as Cut

// Draws one damage mark onto a captured-desktop canvas, offset by (dx, dy).
// Untyped marks are bullet and blast circles; saber cuts add "cut" (a removed
// polygon), "slit" (a thin groove through the window), "scorch" (the charred
// halo around a groove), and "ember" (a dim warm rim along it). Each mark is
// clipped to its window's shape.
function draw(c, mark, dx, dy) {
  c.save()
  if (mark.clipPoly) Cut.path(c, mark.clipPoly, dx, dy)
  else { c.beginPath(); c.rect(mark.clipX + dx, mark.clipY + dy, mark.clipWidth, mark.clipHeight) }
  c.clip()
  if (mark.type === "scorch" || mark.type === "ember") {
    c.globalCompositeOperation = "source-over"
    // A dark char reads on light windows; the dim ember rim on dark ones.
    c.strokeStyle = mark.type === "scorch" ? "rgba(24, 12, 6, 0.55)" : "rgba(255, 122, 52, 0.32)"
  } else c.globalCompositeOperation = "destination-out"
  if (mark.type === "cut") {
    Cut.path(c, mark.points, dx, dy)
    c.fill()
  } else if (mark.type === "slit" || mark.type === "scorch" || mark.type === "ember") {
    c.lineWidth = mark.width
    // Grooves are drawn a frame at a time; flat ends keep the translucent char
    // and ember from doubling up into beads where segments meet.
    c.lineCap = mark.type === "slit" ? "round" : "butt"
    c.beginPath()
    c.moveTo(mark.x0 + dx, mark.y0 + dy)
    c.lineTo(mark.x1 + dx, mark.y1 + dy)
    c.stroke()
  } else {
    c.beginPath()
    c.arc(mark.x + dx, mark.y + dy, mark.radius, 0, Math.PI * 2)
    c.fill()
  }
  c.restore()
}
