// Convex-polygon helpers for lightsaber cuts in desktop destruction.
// Polygons are arrays of {x, y} in either winding; cuts keep them convex.
function rect(x, y, width, height) {
  return [{x: x, y: y}, {x: x + width, y: y}, {x: x + width, y: y + height}, {x: x, y: y + height}]
}
function area(poly) {
  var sum = 0
  for (var i = 0; i < poly.length; i++) {
    var a = poly[i], b = poly[(i + 1) % poly.length]
    sum += a.x * b.y - b.x * a.y
  }
  return Math.abs(sum) / 2
}
function bounds(poly) {
  var left = Infinity, top = Infinity, right = -Infinity, bottom = -Infinity
  for (var i = 0; i < poly.length; i++) {
    left = Math.min(left, poly[i].x); right = Math.max(right, poly[i].x)
    top = Math.min(top, poly[i].y); bottom = Math.max(bottom, poly[i].y)
  }
  return {x: left, y: top, width: right - left, height: bottom - top}
}
function winding(poly) {
  var sum = 0
  for (var i = 0; i < poly.length; i++) {
    var a = poly[i], b = poly[(i + 1) % poly.length]
    sum += a.x * b.y - b.x * a.y
  }
  return sum < 0 ? -1 : 1
}
function contains(poly, x, y) {
  var sign = winding(poly)
  for (var i = 0; i < poly.length; i++) {
    var a = poly[i], b = poly[(i + 1) % poly.length]
    if (((b.x - a.x) * (y - a.y) - (b.y - a.y) * (x - a.x)) * sign < 0) return false
  }
  return true
}
// Cyrus–Beck: the part of origin + t·direction inside the polygon, as
// {enter, exit} parameters, or null when the line misses it.
function clipLine(poly, ox, oy, dx, dy, tMin, tMax) {
  var enter = tMin, exit = tMax, sign = winding(poly)
  for (var i = 0; i < poly.length; i++) {
    var a = poly[i], b = poly[(i + 1) % poly.length]
    // Inward-facing edge normal.
    var nx = -(b.y - a.y) * sign, ny = (b.x - a.x) * sign
    var denominator = nx * dx + ny * dy
    var numerator = nx * (ox - a.x) + ny * (oy - a.y)
    if (Math.abs(denominator) < 1e-9) {
      if (numerator < 0) return null
      continue
    }
    var t = -numerator / denominator
    if (denominator > 0) enter = Math.max(enter, t)
    else exit = Math.min(exit, t)
    if (enter > exit) return null
  }
  return {enter: enter, exit: exit}
}
// Splits along the infinite line through p and q; returns [left, right], with
// an empty array for a side the line does not reach.
function split(poly, p, q) {
  var left = [], right = []
  var dx = q.x - p.x, dy = q.y - p.y
  function side(v) { return dx * (v.y - p.y) - dy * (v.x - p.x) }
  for (var i = 0; i < poly.length; i++) {
    var a = poly[i], b = poly[(i + 1) % poly.length]
    var sa = side(a), sb = side(b)
    if (sa >= 0) left.push(a)
    if (sa <= 0) right.push(a)
    if ((sa > 0 && sb < 0) || (sa < 0 && sb > 0)) {
      var t = sa / (sa - sb)
      var crossing = {x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t}
      left.push(crossing); right.push(crossing)
    }
  }
  return [left.length >= 3 ? left : [], right.length >= 3 ? right : []]
}
function copy(poly) { return poly.map(function(v) { return {x: v.x, y: v.y} }) }
function translate(poly, dx, dy) { return poly.map(function(v) { return {x: v.x + dx, y: v.y + dy} }) }
function path(c, poly, dx, dy) {
  c.beginPath()
  c.moveTo(poly[0].x + dx, poly[0].y + dy)
  for (var i = 1; i < poly.length; i++) c.lineTo(poly[i].x + dx, poly[i].y + dy)
  c.closePath()
}
