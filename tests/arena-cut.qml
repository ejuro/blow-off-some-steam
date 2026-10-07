import QtQuick
import Quickshell
import ".." as Steam
ShellRoot {
  Steam.Arena { id: arena }
  // A failed check reports and quits, so the runner shows why instead of timing out.
  function check(ok, message) { if (!ok) { console.log("FAILED: " + message); Qt.quit(); throw new Error(message) } }
  function area(poly) {
    var sum = 0
    for (var i = 0; i < poly.length; i++) { var a = poly[i], b = poly[(i + 1) % poly.length]; sum += a.x * b.y - b.x * a.y }
    return Math.abs(sum) / 2
  }
  function contains(poly, x, y) {
    var inside = false
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++)
      if ((poly[i].y > y) !== (poly[j].y > y) && x < (poly[j].x - poly[i].x) * (y - poly[i].y) / (poly[j].y - poly[i].y) + poly[i].x) inside = !inside
    return inside
  }
  function marks(type) { return arena.carveMarks.filter(function(m) { return m.type === type }).length }
  function sweep(points) {
    for (var i = 0; i + 1 < points.length; i++)
      arena.saberCutDesktop({ tip: { x: points[i][0], y: points[i][1] } }, { tip: { x: points[i + 1][0], y: points[i + 1][1] } })
  }
  Timer { interval: 150; running: true; onTriggered: {
    for (var i = 0; i < arena.data.length; i++)
      if (String(arena.data[i]).indexOf("WaylandPanelInterface") >= 0) arena.data[i].visible = false
    arena.audio.active = false
    arena.arm("lightsaber")
    // A frozen desktop, no real capture: a 200 × 200 window at (400, 300), a
    // 60 × 60 one at (800, 300), a 700 × 700 one at (1000, 150), and a
    // 400 × 400 one at (200, 600).
    arena.captureWidth = 1920; arena.captureHeight = 1080; arena.activeWorkspaceId = -1
    arena.prepareDestructibles(JSON.stringify([
      { address: "0xw1", at: [407, 307], size: [186, 186], mapped: true, workspace: { id: 1 } },
      { address: "0xw2", at: [807, 307], size: [46, 46], mapped: true, workspace: { id: 1 } },
      { address: "0xw3", at: [1007, 157], size: [686, 686], mapped: true, workspace: { id: 1 } },
      { address: "0xw4", at: [207, 607], size: [386, 386], mapped: true, workspace: { id: 1 } }]))
    arena.destructionEnabled = true
    var win = arena.destructibles[1]
    check(win.id === "0xw1" && area(win.poly) === 40000 && win.holes.length === 0, "window prepared as a shape")

    // Straight through at y = 350: the top 50 px falls, the rest stands.
    check(arena.saberCutDesktop({ tip: { x: 350, y: 350 } }, { tip: { x: 700, y: 350 } }) !== null, "the sweep touched the window")
    win = arena.destructibles[1]
    check(!win.destroyed && Math.abs(area(win.poly) - 30000) < 1, "edge-to-edge cut drops the smaller side")
    check(marks("cut") === 1 && marks("slit") === 1 && marks("scorch") === 1 && marks("ember") === 1, "cut and groove marks")
    check(arena.firstDesktopImpact(800, 320, -1, 0, false) === null, "shots pass where the piece was")
    var hit = arena.firstDesktopImpact(800, 400, -1, 0, false)
    check(hit && Math.abs(hit.x - 600) < 0.5, "the standing part still stops shots")

    // A stroke that starts inside only grooves, even when it leaves.
    sweep([[450, 450], [500, 460], [650, 460]])
    check(Math.abs(area(arena.destructibles[1].poly) - 30000) < 1 && arena.destructibles[1].holes.length === 0, "grooves without a cut")

    // Drawing a closed loop drops it out as a hole.
    sweep([[430, 380], [520, 380], [520, 470], [430, 470], [440, 370]])
    win = arena.destructibles[1]
    check(win.holes.length === 1 && area(win.holes[0]) > 5000, "a loop falls out as a hole")
    hit = arena.firstDesktopImpact(480, 425, 1, 0, false)
    check(hit && Math.abs(hit.x - 520) < 1, "shots fly through the hole to its far edge: " + (hit && hit.x))
    var left = arena.firstDesktopImpact(300, 425, 1, 0, false)
    check(left && Math.abs(left.x - 400) < 0.5, "the rim around the hole is still solid")

    // Out of the hole and back into it: the strip between falls and the hole grows.
    var holeArea = area(win.holes[0])
    sweep([[475, 425], [540, 425], [540, 460], [500, 460]])
    win = arena.destructibles[1]
    check(win.holes.length === 1 && Math.abs(area(win.holes[0]) - holeArea - 700) < 2, "the strip joins the hole: " + (area(win.holes[0]) - holeArea))
    hit = arena.firstDesktopImpact(480, 440, 1, 0, false)
    check(hit && Math.abs(hit.x - 540) < 1, "shots fly through the grown hole: " + (hit && hit.x))

    // Separate strokes on the 400 × 400 window (200..600, 600..1000) with a
    // hole at 300..500 × 700..900. Edge into the hole: nothing falls yet.
    sweep([[300, 700], [500, 700], [500, 900], [300, 900], [310, 690]])
    var fourth = arena.destructibles[4]
    check(fourth.id === "0xw4" && fourth.holes.length === 1, "fourth window has a hole")
    var fourthArea = area(fourth.poly) - area(fourth.holes[0])
    sweep([[150, 750], [400, 750]])
    fourth = arena.destructibles[4]
    check(fourth.holes.length === 0 && Math.abs(area(fourth.poly) - fourthArea) < 1 && !contains(fourth.poly, 400, 800),
          "an edge-to-hole cut joins the hole to the outline")
    // Down across the slit that cut left: the top-left corner falls where it
    // meets the slit, and the blade carries on through to drop the strip below.
    sweep([[250, 550], [250, 1050]])
    fourth = arena.destructibles[4]
    check(!contains(fourth.poly, 225, 650) && !contains(fourth.poly, 225, 900) && contains(fourth.poly, 275, 650) && contains(fourth.poly, 275, 900),
          "crossing the slit cuts on both sides of it")
    // Hole to the far edge: the smaller top part falls. What stands is
    // 350 × 250 less the hole's lower part (its left side leans a little,
    // since the loop closed at (310, 690)): 87500 − (30000 − 535.7).
    sweep([[400, 750], [650, 750]])
    fourth = arena.destructibles[4]
    check(!fourth.destroyed && !contains(fourth.poly, 550, 650) && contains(fourth.poly, 550, 950) && !contains(fourth.poly, 400, 800)
          && Math.abs(area(fourth.poly) - 58035.7) < 1, "hole-to-edge cut splits the window: " + area(fourth.poly))

    // A lit right-click spin carves a circle around the hilt.
    var big = arena.destructibles[3]
    arena.igniteSaber(); arena.gunPositioned = false
    arena.gunX = 1350; arena.gunY = 500; arena.aimAngle = 0; arena.saberIgnition = 1; arena.saberPrevious = null
    for (var step = 0; step <= 36; step++) { arena.trickAngle = step * 10; arena.advanceSaber(0.016) }
    big = arena.destructibles[3]
    check(big.holes.length === 1 && area(big.holes[0]) > 60000, "a spin drops a circle: " + big.holes.length + " " + (big.holes[0] ? Math.round(area(big.holes[0])) : 0))
    arena.trickAngle = 0
    arena.retractSaber()

    // After a spin, a sweep from the edge through the hole and out the far
    // edge still splits the window: the hole joins the outline, then the top falls.
    var sweepPoints = []
    for (var sx = 960; sx <= 1740; sx += 20) sweepPoints.push([sx, 420])
    sweep(sweepPoints)
    big = arena.destructibles[3]
    check(!big.destroyed && big.holes.length === 0, "the hole became part of the cut: " + big.holes.length)
    check(contains(big.poly, 1350, 800) && !contains(big.poly, 1350, 300) && !contains(big.poly, 1350, 500),
          "the top fell, the bottom stands, and the hole stays open")

    // Halving the small window leaves under 2500 px² standing, so that falls too.
    sweep([[830, 250], [830, 400]])
    check(arena.destructibles[2].destroyed && !arena.destructibles[1].destroyed, "a sliver under 2500 px² falls")
    arena.cancelSaber()
    check(arena.saberHeat.length === 0, "putting the saber away clears the glow")
    console.log("ARENA_CUT_OK"); done.start()
  } }
  Timer { id: done; interval: 150; onTriggered: Qt.quit() }
}
