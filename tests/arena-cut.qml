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
  Timer { interval: 150; running: true; onTriggered: {
    for (var i = 0; i < arena.data.length; i++)
      if (String(arena.data[i]).indexOf("WaylandPanelInterface") >= 0) arena.data[i].visible = false
    arena.audio.active = false
    arena.arm("lightsaber")
    // A frozen desktop with a 200 × 200 window at (400, 300) and a 60 × 60 one at (800, 300); no real capture.
    arena.captureWidth = 1920; arena.captureHeight = 1080; arena.activeWorkspaceId = -1
    arena.prepareDestructibles(JSON.stringify([{ address: "0xw1", at: [407, 307], size: [186, 186], mapped: true, workspace: { id: 1 } },
                                                 { address: "0xw2", at: [807, 307], size: [46, 46], mapped: true, workspace: { id: 1 } }]))
    arena.destructionEnabled = true
    var win = arena.destructibles[1]
    check(win.id === "0xw1" && area(win.poly) === 40000, "window prepared as a polygon")

    // The tip sweeps straight through at y = 350: the top 50 px falls, the rest stands.
    var contact = arena.saberCutDesktop({ tip: { x: 350, y: 350 } }, { tip: { x: 700, y: 350 } })
    check(contact !== null, "the sweep touched the window")
    win = arena.destructibles[1]
    check(!win.destroyed && Math.abs(area(win.poly) - 30000) < 1, "cut off the smaller part")
    check(marks("cut") === 1 && marks("slit") === 1 && marks("scorch") === 1 && marks("ember") === 1, "cut and groove marks recorded")
    check(arena.saberHeat.length === 2, "the groove and the cut edge glow")

    // Shots pass through where the piece used to be.
    check(arena.firstDesktopImpact(800, 320, -1, 0, false) === null, "removed corner is empty")
    var hit = arena.firstDesktopImpact(800, 400, -1, 0, false)
    check(hit && Math.abs(hit.x - 600) < 0.5, "the standing part still stops shots")

    // A stroke that starts inside only grooves the window, even when it leaves.
    check(arena.saberCutDesktop({ tip: { x: 450, y: 450 } }, { tip: { x: 500, y: 460 } }) !== null, "groove contact")
    arena.saberCutDesktop({ tip: { x: 500, y: 460 } }, { tip: { x: 650, y: 460 } })
    check(Math.abs(area(arena.destructibles[1].poly) - 30000) < 1 && marks("slit") === 3, "grooves without a cut")

    // Halving the small window leaves under 2500 px² standing, so that falls too.
    arena.saberCutDesktop({ tip: { x: 830, y: 250 } }, { tip: { x: 830, y: 400 } })
    check(arena.destructibles[2].destroyed && !arena.destructibles[1].destroyed, "a sliver under 2500 px² falls")
    // Heat cools away and the strokes reset when the blade goes out.
    arena.cancelSaber()
    check(arena.saberHeat.length === 0, "putting the saber away clears the glow")
    console.log("ARENA_CUT_OK"); done.start()
  } }
  Timer { id: done; interval: 150; onTriggered: Qt.quit() }
}
