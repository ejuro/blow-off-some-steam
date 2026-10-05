import QtQuick
import Quickshell
import ".." as Steam
ShellRoot {
  Steam.Arena { id: arena }
  function check(ok, message) { if (!ok) throw new Error(message) }
  function area(poly) {
    var sum = 0
    for (var i = 0; i < poly.length; i++) { var a = poly[i], b = poly[(i + 1) % poly.length]; sum += a.x * b.y - b.x * a.y }
    return Math.abs(sum) / 2
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
    // 60 × 60 one at (800, 300), and a 700 × 700 one at (1000, 150).
    arena.captureWidth = 1920; arena.captureHeight = 1080; arena.activeWorkspaceId = -1
    arena.prepareDestructibles(JSON.stringify([
      { address: "0xw1", at: [407, 307], size: [186, 186], mapped: true, workspace: { id: 1 } },
      { address: "0xw2", at: [807, 307], size: [46, 46], mapped: true, workspace: { id: 1 } },
      { address: "0xw3", at: [1007, 157], size: [686, 686], mapped: true, workspace: { id: 1 } }]))
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

    // A lit right-click spin carves a circle around the hilt.
    var big = arena.destructibles[3]
    arena.igniteSaber(); arena.gunPositioned = false
    arena.gunX = 1350; arena.gunY = 500; arena.aimAngle = 0; arena.saberIgnition = 1; arena.saberPrevious = null
    for (var step = 0; step <= 36; step++) { arena.trickAngle = step * 10; arena.advanceSaber(0.016) }
    big = arena.destructibles[3]
    check(big.holes.length === 1 && area(big.holes[0]) > 100000, "a spin drops a circle: " + big.holes.length)
    arena.trickAngle = 0
    arena.retractSaber()

    // Halving the small window leaves under 2500 px² standing, so that falls too.
    sweep([[830, 250], [830, 400]])
    check(arena.destructibles[2].destroyed && !arena.destructibles[1].destroyed, "a sliver under 2500 px² falls")
    arena.cancelSaber()
    check(arena.saberHeat.length === 0, "putting the saber away clears the glow")
    console.log("ARENA_CUT_OK"); done.start()
  } }
  Timer { id: done; interval: 150; onTriggered: Qt.quit() }
}
