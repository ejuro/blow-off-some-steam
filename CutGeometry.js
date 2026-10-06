// Polygon helpers for lightsaber cuts in desktop destruction.
// A window is an outline polygon plus holes ("loops": [outline, hole, ...]);
// points are {x, y}, any winding, and shapes may be concave after cuts.
function rect(x, y, width, height) {
  return [{x: x, y: y}, {x: x + width, y: y}, {x: x + width, y: y + height}, {x: x, y: y + height}]
}
// Positive or negative depending on winding.
function signedArea(poly) {
  var sum = 0
  for (var i = 0; i < poly.length; i++) {
    var a = poly[i], b = poly[(i + 1) % poly.length]
    sum += a.x * b.y - b.x * a.y
  }
  return sum / 2
}
function area(poly) { return Math.abs(signedArea(poly)) }
function bounds(poly) {
  var left = Infinity, top = Infinity, right = -Infinity, bottom = -Infinity
  for (var i = 0; i < poly.length; i++) {
    left = Math.min(left, poly[i].x); right = Math.max(right, poly[i].x)
    top = Math.min(top, poly[i].y); bottom = Math.max(bottom, poly[i].y)
  }
  return {x: left, y: top, width: right - left, height: bottom - top}
}
// Even–odd point test; works for concave shapes.
function contains(poly, x, y) {
  var inside = false
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    var a = poly[i], b = poly[j]
    if ((a.y > y) !== (b.y > y) && x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x) inside = !inside
  }
  return inside
}
// Inside the outline and not in any hole.
function solid(loops, x, y) {
  if (!contains(loops[0], x, y)) return false
  for (var i = 1; i < loops.length; i++) if (contains(loops[i], x, y)) return false
  return true
}
// Where p + t·(q − p) crosses edge a → b: {t, u} with u ∈ [0, 1) along the edge.
function cross(p, q, a, b) {
  var rx = q.x - p.x, ry = q.y - p.y, sx = b.x - a.x, sy = b.y - a.y
  var denominator = rx * sy - ry * sx
  // Parallel, or near enough that rounding would put the hit anywhere.
  if (Math.abs(denominator) <= 1e-9 * Math.hypot(rx, ry) * Math.hypot(sx, sy)) return null
  var t = ((a.x - p.x) * sy - (a.y - p.y) * sx) / denominator
  var u = ((a.x - p.x) * ry - (a.y - p.y) * rx) / denominator
  // Half-open edges, so a line through a shared corner counts it once.
  if (u < 0 || u >= 1) return null
  return {t: t, u: u}
}
// Every boundary crossing of the line p → q with t in [tMin, tMax], in order.
// `enter` says whether p → q passes into the solid there (loop 0 is the
// outline, the rest are holes). Joined loops have zero-width slits whose two
// sides cross at the same point; leaving sorts first, so the line leaves the
// solid through one side and comes back in through the other.
function crossings(loops, p, q, tMin, tMax) {
  var found = [], rx = q.x - p.x, ry = q.y - p.y
  for (var l = 0; l < loops.length; l++) {
    var loop = loops[l]
    // The solid lies on this side of every edge: left of it for a positive winding.
    var side = (signedArea(loop) > 0 ? 1 : -1) * (l === 0 ? 1 : -1)
    for (var e = 0; e < loop.length; e++) {
      var a = loop[e], b = loop[(e + 1) % loop.length]
      var hit = cross(p, q, a, b)
      if (hit && hit.t >= tMin && hit.t <= tMax)
        found.push({t: hit.t, u: hit.u, loop: l, edge: e, x: p.x + rx * hit.t, y: p.y + ry * hit.t,
                    enter: side * ((b.x - a.x) * ry - (b.y - a.y) * rx) > 0})
    }
  }
  return found.sort(function(a, b) { return Math.abs(a.t - b.t) > 1e-9 ? a.t - b.t : a.enter - b.enter })
}
// Solid stretches along an infinite line, as [enter, exit] pairs of t.
function spans(loops, p, q) {
  var hits = crossings(loops, p, q, -Infinity, Infinity), result = []
  for (var i = 0; i + 1 < hits.length; i += 2) result.push([hits[i].t, hits[i + 1].t])
  return result
}
// Splits an outline along a cut path that enters at one edge and leaves at
// another (entry/exit: {edge, u}); path runs from the entry to the exit point.
// Returns both sides; together they cover the outline.
function splitAlong(outline, path, entry, exit) {
  var n = outline.length
  var ahead = [], behind = []
  // Ahead: from the exit, forward around the outline back to the entry.
  if (!(entry.edge === exit.edge && entry.u > exit.u)) {
    var i = exit.edge
    do { i = (i + 1) % n; ahead.push(outline[i]) } while (i !== entry.edge)
  }
  // Behind: from the exit, backward around the outline back to the entry.
  if (!(entry.edge === exit.edge && entry.u < exit.u)) {
    var k = exit.edge
    behind.push(outline[k])
    while (k !== (entry.edge + 1) % n) { k = (k - 1 + n) % n; behind.push(outline[k]) }
  }
  return [path.concat(ahead), path.concat(behind)]
}
// Joins two loops with a cut path that runs from `from` on `base` to `to` on
// `other` ({edge, u} each): the result follows base up to the path, along it,
// all the way round other, back along the path, and on round base. That leaves
// a zero-width slit where the path ran. An outline joined with a hole must wind
// against it so the hole's area subtracts; two holes joined wind the same way.
function bridge(base, other, path, from, to, sameWinding) {
  var n = other.length
  var forward = (signedArea(base) > 0) === (signedArea(other) > 0) ? sameWinding : !sameWinding
  var around = []
  for (var i = 1; i <= n; i++) around.push(other[forward ? (to.edge + i) % n : (to.edge + 1 - i + n) % n])
  return base.slice(0, from.edge + 1).concat(path, around, path.slice().reverse(), base.slice(from.edge + 1))
}
// Where a path's newest segment closes a loop, as {index, x, y}: the loop
// runs from that point through path[index + 1 …]. It closes by crossing an
// earlier segment, or by coming back within `snap` px of an earlier point that
// is at least `travel` px back along the path (a spin ends where it started).
function selfCrossing(path, snap, travel) {
  var n = path.length
  if (n < 4) return null
  var p = path[n - 2], q = path[n - 1]
  for (var i = 0; i < n - 3; i++) {
    var hit = cross(p, q, path[i], path[i + 1])
    if (hit && hit.t >= -1e-9 && hit.t <= 1 + 1e-9)
      return {index: i, x: p.x + (q.x - p.x) * hit.t, y: p.y + (q.y - p.y) * hit.t}
  }
  if (!snap) return null
  var along = 0
  for (var k = n - 2; k >= 0; k--) {
    along += Math.hypot(path[k + 1].x - path[k].x, path[k + 1].y - path[k].y)
    if (along >= travel && Math.hypot(q.x - path[k].x, q.y - path[k].y) <= snap)
      return {index: k, x: path[k].x, y: path[k].y}
  }
  return null
}
function translate(poly, dx, dy) { return poly.map(function(v) { return {x: v.x + dx, y: v.y + dy} }) }
function path(c, poly, dx, dy) {
  c.beginPath()
  c.moveTo(poly[0].x + dx, poly[0].y + dy)
  for (var i = 1; i < poly.length; i++) c.lineTo(poly[i].x + dx, poly[i].y + dy)
  c.closePath()
}
