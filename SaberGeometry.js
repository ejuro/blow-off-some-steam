// The blade's swept surface, including rounded edges; catches fast drags.
function segmentDistanceSquared(x, y, a, b) {
  var dx = b.x - a.x, dy = b.y - a.y
  var length = dx * dx + dy * dy
  var t = length ? Math.max(0, Math.min(1, ((x - a.x) * dx + (y - a.y) * dy) / length)) : 0
  return Math.pow(x - a.x - t * dx, 2) + Math.pow(y - a.y - t * dy, 2)
}
function cross(a, b, c) { return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) }
function triangle(p, a, b, c) {
  if (Math.abs(cross(a, b, c)) < 0.0001) return false
  var u = cross(a, b, p), v = cross(b, c, p), w = cross(c, a, p)
  return (u >= 0 && v >= 0 && w >= 0) || (u <= 0 && v <= 0 && w <= 0)
}
function hits(x, y, radius, previous, current) {
  var p = {x: x, y: y}, a = previous.base, b = previous.tip, c = current.tip, d = current.base
  return triangle(p, a, b, c) || triangle(p, a, c, d)
    || segmentDistanceSquared(x, y, a, b) <= radius * radius
    || segmentDistanceSquared(x, y, b, c) <= radius * radius
    || segmentDistanceSquared(x, y, c, d) <= radius * radius
    || segmentDistanceSquared(x, y, d, a) <= radius * radius
}
// ignition (0–1) extends the blade out of the emitter; it defaults to fully lit.
function blade(x, y, degrees, scale, ignition) {
  var a = degrees * Math.PI / 180, dx = Math.cos(a), dy = Math.sin(a)
  var reach = 16 + 64 * (ignition === undefined ? 1 : ignition)
  return { base: {x: x + 16 * scale * dx, y: y + 16 * scale * dy},
           tip: {x: x + reach * scale * dx, y: y + reach * scale * dy} }
}
