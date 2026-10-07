import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import "SaberGeometry.js" as Saber
import "CutGeometry.js" as Cut
import "DesktopMarks.js" as Marks

Item {
  id: root
  property bool armed: false
  readonly property var audio: audioBridge
  property bool audioPreviewActive: false
  // Muted from the drawer: the audio worker isn't started at all.
  AudioBridge { id: audioBridge; active: (root.armed || root.audioPreviewActive) && !root.soundMuted }
  Preferences { id: preferences }
  readonly property bool soundMuted: preferences.muted
  function setSoundMuted(muted) { preferences.setMuted(muted) }
  property bool destructionEnabled: false
  property var targetScreen: null
  property bool captureInProgress: false
  property string pendingWeapon: ""
  property url desktopSnapshot: ""
  property string captureError: ""
  property var destructibles: []
  property string barPosition: "top"
  property real barThickness: 30
  property string clientGeometryJson: "[]"
  property bool clientGeometryReady: false
  property int activeWorkspaceId: -1
  property bool activeWorkspaceReady: false
  property real captureOffsetX: 0
  property real captureOffsetY: 0
  property real captureWidth: 0
  property real captureHeight: 0
  property url wallpaperSource: ""
  property var carveMarks: []
  property var carveBuckets: ({})
  property var regionCarveMarks: ({})
  property bool terrainNeedsReset: true
  property bool terrainReady: false
  property int paintedCarveCount: 0
  property real activationShade: 0
  property int windowBreakVariant: -1
  property int fallingSerial: 0
  property string weapon: "glock"
  readonly property var spec: {
    switch (weapon) {
    case "lightsaber": return { name: "Lightsaber", image: "", width: 96, height: 24, scale: 2.6, gripX: 12, gripY: 12, muzzleX: 92, muzzleY: 12, automatic: false, interval: 460, recoil: 0, particles: 0, power: 1, ejectsCase: false }
    case "revolver": return { name: "Colt 45", image: "assets/revolver-colt45.png", width: 64, height: 32, scale: 2.2, gripX: 20, gripY: 25, muzzleX: 47, muzzleY: 12.5, automatic: false, interval: 280, recoil: 19, particles: 25, power: 1.25, ejectsCase: false, flashStyle: "revolver" }
    case "ak47": return { name: "AK-47", image: "assets/ak47.png", width: 96, height: 48, scale: 2, gripX: 35, gripY: 33, muzzleX: 79, muzzleY: 9.5, ejectX: 45, ejectY: 12, automatic: true, interval: 82, recoil: 10, particles: 7, power: 1 }
    case "mp5a3": return { name: "MP5A3", image: "assets/mp5a3.png", width: 80, height: 48, scale: 2.1, gripX: 33, gripY: 33, muzzleX: 60, muzzleY: 7.5, ejectX: 31, ejectY: 8, automatic: true, interval: 66, recoil: 7, particles: 6, power: 0.9 }
    case "bazooka": return { name: "M20 Bazooka", image: "assets/bazooka-m20.png", width: 128, height: 32, scale: 2, gripX: 46, gripY: 24, muzzleX: 115, muzzleY: 12.5, automatic: false, interval: 500, recoil: 28, particles: 42, power: 1.8 }
    default: return { name: "Glock P80", image: "assets/glock-p80.png", width: 64, height: 48, scale: 2.2, gripX: 22, gripY: 34, muzzleX: 48, muzzleY: 11.5, ejectX: 31, ejectY: 14, automatic: false, interval: 220, recoil: 15, particles: 19, power: 1 }
    }
  }
  readonly property string weaponName: spec.name
  property real pointerX: 0
  property real pointerY: 0
  property real gunX: 0
  property real gunY: 0
  property real aimAngle: 0
  property bool aimFlipped: false
  property bool gunPositioned: false
  property bool automaticHoldEngaged: false
  property real followDistance: 135
  property real recoil: 0
  property real flash: 0
  property real trickAngle: 0
  property var particles: []
  property var pendingEffects: []
  property bool targetVisible: false
  property bool targetsEnabled: false
  property bool bugHuntEnabled: false
  readonly property var flyRecords: records
  FlyRecords { id: records }
  readonly property bool roundFinished: bugHuntEnabled && !!bugLayerLoader.item && bugLayerLoader.item.finished
  readonly property bool huntBriefing: bugHuntEnabled && !!bugLayerLoader.item && bugLayerLoader.item.briefing
  function weaponNames(ids) {
    return ids.map(function(id) {
      for (var i = 0; i < weaponOptions.length; i++) if (weaponOptions[i].id === id) return weaponOptions[i].name
      return id
    }).join(" · ") || "No weapons fired"
  }
  function clearRoundEffects() {
    cancelSaber()
    automaticHoldTimer.stop(); fireTimer.stop(); automaticHoldEngaged = false
    automaticSound.stop(); mp5AutomaticSound.stop()
    pistolSound.stop(); akSingleSound.stop(); mp5SingleSound.stop()
    revolverSound.stop(); bazookaLaunchSound.stop(); rocketExplosionSound.stop()
    weaponSpinSound.stop(); trickAnimation.stop(); closeWeaponWheel(false)
    keyboardWeaponWheel = false
    rocketCooldown.stop()
    particles = []; pendingEffects = []; particleBuffer = []
    recoil = 0; flash = 0; canvas.clear()
  }
  onRoundFinishedChanged: {
    if (roundFinished) {
      // A hit can expire the round inside a physics step; clear after it returns.
      Qt.callLater(function() { if (root.roundFinished) root.clearRoundEffects() })
    } else if (armed) wakeSimulation()
  }
  property real targetX: 0
  property real targetY: 0
  property real targetRadius: 34
  property bool weaponWheelOpen: false
  property real weaponWheelX: 0
  property real weaponWheelY: 0
  property real weaponWheelOriginX: 0
  property real weaponWheelOriginY: 0
  property int weaponWheelSelection: -1
  property bool keyboardWeaponWheel: false
  readonly property color accent: Color.accent
  // Overlay UI follows the active Omarchy theme like the weapon case does.
  readonly property color foreground: Color.foreground
  readonly property color background: Color.background
  readonly property color muted: Color.muted
  readonly property color urgent: Color.urgent
  readonly property string fontFamily: Style.font.family
  readonly property int cornerRadius: Style.cornerRadius
  readonly property string themeSignature: [accent, foreground, background, muted].join(" ")
  function tint(color, alpha) { return Qt.rgba(color.r, color.g, color.b, alpha) }
  readonly property var weaponOptions: [
    { id: "glock", name: "GLOCK", image: "assets/glock-p80.png", clip: Qt.rect(18, 8, 30, 20) },
    { id: "revolver", name: "COLT", image: "assets/revolver-colt45.png", clip: Qt.rect(2, 11, 45, 18) },
    { id: "ak47", name: "AK-47", image: "assets/ak47.png", clip: Qt.rect(3, 5, 76, 22) },
    { id: "mp5a3", name: "MP5", image: "assets/mp5a3.png", clip: Qt.rect(3, 3, 57, 27) },
    { id: "bazooka", name: "M20", image: "assets/bazooka-m20.png", clip: Qt.rect(3, 7, 112, 24) },
    { id: "lightsaber", name: "SABER", image: "", clip: Qt.rect(0, 0, 96, 24) }
  ]

  // Fly Hunt rounds are played with one weapon, so the wheel stays shut.
  function openWeaponWheel(x, y) {
    if (roundFinished || bugHuntEnabled) return
    cancelSaber()
    var extent = 185
    weaponWheelOriginX = x
    weaponWheelOriginY = y
    weaponWheelX = Math.max(extent, Math.min(window.width - extent, x))
    weaponWheelY = Math.max(extent, Math.min(window.height - extent, y))
    weaponWheelSelection = -1
    weaponWheelOpen = true
  }
  function updateWeaponWheel(x, y) {
    if (!weaponWheelOpen) return
    var dx = x - weaponWheelOriginX
    var dy = y - weaponWheelOriginY
    var nextSelection = -1
    if (Math.sqrt(dx * dx + dy * dy) < 38) {
      nextSelection = -1
    } else {
      var degrees = Math.atan2(dy, dx) * 180 / Math.PI
      nextSelection = Math.round(((degrees + 90 + 360) % 360) / (360 / weaponOptions.length)) % weaponOptions.length
    }
    if (nextSelection !== weaponWheelSelection) {
      weaponWheelSelection = nextSelection
      if (nextSelection >= 0) {
        weaponWheelHoverSound.stop()
        weaponWheelHoverSound.play()
      }
    }
  }
  function closeWeaponWheel(chooseSelection) {
    var selection = weaponWheelSelection
    weaponWheelOpen = false
    weaponWheelSelection = -1
    if (chooseSelection && selection >= 0) arm(weaponOptions[selection].id)
  }
  function currentWeaponIndex() {
    for (var i = 0; i < weaponOptions.length; i++)
      if (weaponOptions[i].id === weapon) return i
    return 0
  }

  // Hold left-click to ignite; the lit blade cuts whatever it sweeps through.
  property bool saberHeld: false
  property real saberIgnition: 0
  property real saberSpeed: 0
  property real saberClashCooldown: 0
  property var saberPrevious: null
  property var saberTrail: []
  // Smooth swing: hum and two swing loops run together while lit, and blade
  // speed sets their mix every frame, so the sound follows the motion.
  property real saberSwing: 0
  property real saberHumLevel: 0
  property real saberMixClock: 0
  // The saber files share one mastering gain, so they all play at this volume.
  readonly property real saberVolume: 0.3
  readonly property real saberBladeAngle: aimAngle + trickAngle
  function igniteSaber() {
    if (!armed || roundFinished || weaponWheelOpen || weapon !== "lightsaber" || saberHeld) return false
    if (!gunPositioned) {
      gunX = pointerX - followDistance; gunY = pointerY
      aimAngle = 0; gunPositioned = true
    }
    saberHeld = true
    stopSaberLoops()
    saberRetractSound.stop(); saberIgniteSound.stop(); saberIgniteSound.play()
    saberSwingLowSound.play(); saberSwingHighSound.play(); saberSizzleSound.play()
    saberHumDelay.restart()
    wakeSimulation()
    return true
  }
  function retractSaber() {
    if (!saberHeld) return
    saberHeld = false
    stopSaberLoops()
    saberStrokes = ({})
    saberIgniteSound.stop(); saberRetractSound.stop(); saberRetractSound.play()
    wakeSimulation()
  }
  function stopSaberLoops() {
    saberHumDelay.stop(); saberHumFadeIn.stop()
    saberHumSound.stop(); saberSwingLowSound.stop(); saberSwingHighSound.stop(); saberSizzleSound.stop()
    saberSwing = 0; saberHumLevel = 0; saberMixClock = 0; saberContact = 0
    saberHumSound.volume = 0; saberSwingLowSound.volume = 0; saberSwingHighSound.volume = 0; saberSizzleSound.volume = 0
  }
  // Immediate and silent: weapon swaps, the wheel, focus loss, and holstering.
  function cancelSaber() {
    saberHeld = false; saberIgnition = 0; saberSpeed = 0
    saberClashCooldown = 0
    saberPrevious = null; saberTrail = []
    saberStrokes = ({}); saberHeat = []
    stopSaberLoops()
    saberIgniteSound.stop()
  }
  function mixSaber(dt) {
    var target = saberHeld ? Math.max(0, Math.min(1, (saberSpeed - 250) / 2600)) : 0
    // Swells rise quickly with the motion and settle a little more slowly.
    saberSwing += (target - saberSwing) * (1 - Math.exp(-dt / (target > saberSwing ? 0.035 : 0.14)))
    saberMixClock += dt
    if (saberMixClock < 0.022) return
    saberMixClock = 0
    setSaberVoice(saberHumSound, saberVolume * saberHumLevel * (1 - 0.3 * saberSwing))
    setSaberVoice(saberSwingLowSound, saberVolume * Math.min(1, saberSwing * 1.5))
    setSaberVoice(saberSwingHighSound, saberVolume * Math.pow(saberSwing, 2.2))
    setSaberVoice(saberSizzleSound, saberVolume * 0.6 * saberContact)
  }
  // Volume changes cross the audio bridge, so skip ones too small to hear.
  function setSaberVoice(sound, volume) {
    if (Math.abs(sound.volume - volume) > 0.01 || (volume === 0 && sound.volume !== 0)) sound.volume = volume
  }
  // Lightsaber cuts in desktop destruction. The blade tip is the cutting edge:
  // wherever it travels through a window it burns a groove (a thin slit, a
  // charred rim, and a glowing edge that cools). Anything the cuts free from
  // the rest of the window falls: a closed loop drops out as a hole (a spin
  // carves a circle), a cut that enters and leaves through the window's edge
  // drops the smaller side, and a cut that leaves a hole and comes back into
  // it drops the strip in between. A cut from the edge into a hole (or between
  // holes) frees nothing yet but joins them, so the next one can split across.
  // What remains stays up and can be cut again.
  property var saberStrokes: ({})
  property var saberHeat: []
  property real saberContact: 0
  readonly property real saberHeatLife: 1.5
  function regionLoops(region) { return [region.poly].concat(region.holes) }
  function saberCutDesktop(previous, blade) {
    var p = previous.tip, q = blade.tip
    var contact = null, changed = false
    var regions = destructibles
    for (var i = 0; i < regions.length; i++) {
      var region = regions[i]
      if (region.destroyed) { delete saberStrokes[region.id]; continue }
      var loops = regionLoops(region)
      var inside = Cut.solid(loops, p.x, p.y)
      // A tip already inside (lit there, or a hole opened under it) only grooves until it leaves.
      var stroke = inside ? (saberStrokes[region.id] || {entry: null, path: [{x: p.x, y: p.y}]}) : null
      var cursor = {x: p.x, y: p.y}
      var hits = Cut.crossings(loops, p, q, 0, 1)
      for (var h = 0; h < hits.length; h++) {
        var hit = hits[h]
        // Grazing a corner, or the far side of a slit already passed, changes nothing.
        if (hit.enter === inside) continue
        var point = {x: hit.x, y: hit.y}
        if (inside) {
          burnGroove(region, cursor, point); contact = point
          stroke.path.push(point)
          if (cutThrough(region, stroke, hit)) {
            changed = true
            if (region.destroyed) break
            // The shape changed under the blade, so find the rest of this sweep's crossings again.
            loops = regionLoops(region)
            hits = Cut.crossings(loops, p, q, hit.t - 1e-9, 1); h = -1
          }
          stroke = null; inside = false
        } else {
          stroke = {entry: {ring: loops[hit.loop], edge: hit.edge, u: hit.u}, path: [point]}
          inside = true
        }
        cursor = point
      }
      if (!inside || region.destroyed) { delete saberStrokes[region.id]; continue }
      burnGroove(region, cursor, q); contact = {x: q.x, y: q.y}
      if (extendStroke(region, stroke, {x: q.x, y: q.y})) changed = true
      saberStrokes[region.id] = stroke
    }
    if (changed) destructibles = destructibles.slice()
    return contact
  }
  // Adds the tip's new position to a stroke; a stroke that crosses itself
  // has closed a loop, which drops out of the window as a hole.
  function extendStroke(region, stroke, point) {
    var path = stroke.path, last = path[path.length - 1]
    if (Math.hypot(point.x - last.x, point.y - last.y) < 2) return false
    path.push(point)
    // Very long strokes forget their start; an edge-to-edge cut then needs a fresh entry.
    if (path.length > 900) { stroke.path = path = path.slice(path.length - 600); stroke.entry = null }
    var crossing = Cut.selfCrossing(path, 8, 50)
    if (!crossing) return false
    var corner = {x: crossing.x, y: crossing.y}
    var loop = [corner].concat(path.slice(crossing.index + 1, path.length - 1))
    stroke.path = path.slice(0, crossing.index + 1).concat([corner, point])
    return cutHole(region, loop)
  }
  function cutHole(region, loop) {
    if (Cut.area(loop) < 300) return false
    // Holes inside the new one fall out with it.
    region.holes = region.holes.filter(function(hole) { return !Cut.contains(loop, hole[0].x, hole[0].y) })
    dropPiece(region, loop, 0, (Math.random() < 0.5 ? -1 : 1) * (8 + Math.random() * 14),
              loop.concat([loop[0]]), false)
    region.holes = region.holes.concat([loop])
    finishCut(region, loop)
    return true
  }
  // A stroke leaving the solid through `exit`, after entering it through a
  // boundary (outline or hole) that is still there. Returns whether the shape changed.
  function cutThrough(region, stroke, exit) {
    if (!stroke.entry || stroke.path.length < 2) return false
    var from = regionLoops(region).indexOf(stroke.entry.ring)
    if (from < 0) return false
    if (from === 0 && exit.loop === 0) return cutAcross(region, stroke.path, stroke.entry, exit)
    if (from === exit.loop) return cutBesideHole(region, from - 1, stroke.path, stroke.entry, exit)
    return joinLoops(region, stroke.path, from, stroke.entry, exit.loop, exit)
  }
  // Edge to edge splits the window; the smaller side falls, drifting away from the cut.
  function cutAcross(region, path, entry, exit) {
    var halves = Cut.splitAlong(region.poly, path, entry, exit)
    var areas = [Cut.area(halves[0]), Cut.area(halves[1])]
    if (Math.min(areas[0], areas[1]) < 150) return false
    var piece = halves[areas[0] < areas[1] ? 0 : 1], keep = halves[areas[0] < areas[1] ? 1 : 0]
    var pieceBox = Cut.bounds(piece), keepBox = Cut.bounds(keep)
    var away = pieceBox.x + pieceBox.width / 2 >= keepBox.x + keepBox.width / 2 ? 1 : -1
    dropPiece(region, piece, away * (60 + Math.random() * 90), away * (14 + Math.random() * 22), path, false)
    region.poly = keep
    region.holes = region.holes.filter(function(hole) { return Cut.contains(keep, hole[0].x, hole[0].y) })
    finishCut(region, piece)
    return true
  }
  // Out of a hole and back into it: the strip between the cut and the hole's
  // rim falls, and the hole grows to take it in.
  function cutBesideHole(region, index, path, entry, exit) {
    var halves = Cut.splitAlong(region.holes[index], path, entry, exit)
    var areas = [Cut.area(halves[0]), Cut.area(halves[1])]
    if (Math.min(areas[0], areas[1]) < 150) return false
    var piece = halves[areas[0] < areas[1] ? 0 : 1], grown = halves[areas[0] < areas[1] ? 1 : 0]
    // Holes inside the strip fall with it.
    region.holes = region.holes.filter(function(hole, i) { return i !== index && !Cut.contains(grown, hole[0].x, hole[0].y) }).concat([grown])
    dropPiece(region, piece, 0, (Math.random() < 0.5 ? -1 : 1) * (8 + Math.random() * 14), path, false)
    finishCut(region, piece)
    return true
  }
  // Outline to hole, or hole to another hole: nothing is free yet, but the two
  // boundaries become one (with a slit along the cut).
  function joinLoops(region, path, a, entry, b, exit) {
    if (b < a) {
      path = path.slice().reverse()
      var swap = a; a = b; b = swap
      swap = entry; entry = exit; exit = swap
    }
    var loops = regionLoops(region)
    var joined = Cut.bridge(loops[a], loops[b], path, entry, exit, a > 0)
    var holes = region.holes.filter(function(hole, i) { return i !== b - 1 })
    if (a === 0) region.poly = joined
    else holes[a - 1] = joined
    region.holes = holes
    return true
  }
  function finishCut(region, piece) {
    var box = Cut.bounds(piece)
    addRegionMark({ type: "cut", regionId: region.id, points: piece,
      x: box.x + box.width / 2, y: box.y + box.height / 2, radius: Math.hypot(box.width, box.height) / 2 + 2,
      clipX: region.x, clipY: region.y, clipWidth: region.width, clipHeight: region.height })
    if (terrainCanvasLoader.item) terrainCanvasLoader.item.applyDamage(Qt.rect(box.x, box.y, box.width, box.height))
    saberCutSound.stop(); saberCutSound.play()
    // Too little left to stand on its own: the rest falls too.
    var solidArea = Cut.area(region.poly)
    for (var i = 0; i < region.holes.length; i++) solidArea -= Cut.area(region.holes[i])
    if (solidArea < 2500) destroyRegion(region, true)
  }
  function addRegionMark(mark) {
    carveMarks.push(mark)
    indexCarveMark(mark)
  }
  function burnGroove(region, p, q) {
    var length = Math.hypot(q.x - p.x, q.y - p.y)
    if (length < 0.75) return
    var centreX = (p.x + q.x) / 2, centreY = (p.y + q.y) / 2
    // A charred halo, a dim ember rim, then the slit through the window on top.
    var widths = [{type: "scorch", width: 9}, {type: "ember", width: 4.5}, {type: "slit", width: 2.5}]
    for (var i = 0; i < widths.length; i++) {
      // Outlines are replaced, never edited, so marks can share them.
      addRegionMark({ type: widths[i].type, regionId: region.id, width: widths[i].width,
        x0: p.x, y0: p.y, x1: q.x, y1: q.y, clipPoly: region.poly,
        x: centreX, y: centreY, radius: length / 2 + widths[i].width,
        clipX: region.x, clipY: region.y, clipWidth: region.width, clipHeight: region.height })
    }
    addHeat(p, q)
    if (terrainCanvasLoader.item)
      terrainCanvasLoader.item.applyDamage(Qt.rect(Math.min(p.x, q.x) - 10, Math.min(p.y, q.y) - 10,
                                                   Math.abs(q.x - p.x) + 20, Math.abs(q.y - p.y) + 20))
  }
  function addHeat(p, q) {
    var heat = saberHeat.length >= 96 ? saberHeat.slice(saberHeat.length - 95) : saberHeat.slice()
    heat.push({x0: p.x, y0: p.y, x1: q.x, y1: q.y, age: 0})
    saberHeat = heat
  }
  function saberSparks(point, swingX, swingY) {
    var sparks = []
    var swing = Math.max(1, Math.hypot(swingX, swingY))
    for (var i = 0; i < 2; i++) {
      // Thrown back against the swing, with some scatter and a little lift.
      var speed = 2 + Math.random() * 4.5
      var angle = Math.atan2(-swingY, -swingX) + (Math.random() - 0.5) * 1.6
      if (swing < 2) angle = -Math.PI / 2 + (Math.random() - 0.5) * 2.4
      sparks.push({ x: point.x, y: point.y, vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed - 1,
                    life: 0.45 + Math.random() * 0.35, size: 1.2 + Math.random() * 1.6, kind: 1 })
    }
    pendingEffects = pendingEffects.concat(sparks)
  }
  function advanceSaber(dt) {
    if (weapon !== "lightsaber" || dt <= 0) return
    saberClashCooldown = Math.max(0, saberClashCooldown - dt)
    if (saberHeld) saberIgnition = Math.min(1, saberIgnition + dt / 0.13)
    else saberIgnition = Math.max(0, saberIgnition - dt / 0.35)
    var trail = saberTrail.filter(function(sample) { sample.age += dt; return sample.age < 0.13 })
    if (saberHeat.length) saberHeat = saberHeat.filter(function(heat) { heat.age += dt; return heat.age < saberHeatLife })
    if (saberIgnition === 0) {
      saberPrevious = null; saberSpeed = 0
      saberTrail = trail
      return
    }
    var blade = Saber.blade(gunX, gunY, saberBladeAngle, spec.scale, saberIgnition)
    var previous = saberPrevious || blade
    var tipTravel = Math.hypot(blade.tip.x - previous.tip.x, blade.tip.y - previous.tip.y)
    saberSpeed += (tipTravel / dt - saberSpeed) * Math.min(1, dt * 30)
    if (saberHeld) mixSaber(dt)
    var struck = false
    if (bugHuntEnabled && bugLayerLoader.item && bugLayerLoader.item.hitSaber(previous, blade)) struck = true
    if (targetsEnabled && targetVisible && Saber.hits(targetX, targetY, targetRadius + 6, previous, blade)) { hitTarget(); struck = true }
    // Desktop windows are cut, not struck: grooves, sparks, and a sizzle instead of a clash.
    var contact = destructionEnabled && saberHeld ? saberCutDesktop(previous, blade) : null
    saberContact = contact ? 1 : Math.max(0, saberContact - dt / 0.08)
    if (contact) saberSparks(contact, blade.tip.x - previous.tip.x, blade.tip.y - previous.tip.y)
    // A short cooldown keeps one sweep through several flies to a single clash.
    if (struck && saberClashCooldown === 0) {
      var clash = Math.random() < 0.5 ? saberClashSound : saberClashSound2
      clash.stop(); clash.play()
      saberClashCooldown = 0.12
    }
    if (tipTravel > 4) trail.push({base: blade.base, tip: blade.tip, age: 0})
    saberPrevious = blade
    saberTrail = trail.slice(-8)
  }
  Timer {
    id: saberHumDelay
    // The ignition's own hum fades out as the loop fades in.
    interval: 500
    onTriggered: { saberHumSound.play(); saberHumFadeIn.restart() }
  }
  NumberAnimation {
    id: saberHumFadeIn
    target: root
    property: "saberHumLevel"
    from: 0
    to: 1
    duration: 500
  }
  RemoteSound {
    id: saberHumSound
    audio: root.audio
    source: Qt.resolvedUrl("sounds/saber-hum.wav")
    loops: RemoteSound.Infinite
    volume: 0
  }
  RemoteSound {
    id: saberSwingLowSound
    audio: root.audio
    source: Qt.resolvedUrl("sounds/saber-swing-low.wav")
    loops: RemoteSound.Infinite
    volume: 0
  }
  RemoteSound {
    id: saberSwingHighSound
    audio: root.audio
    source: Qt.resolvedUrl("sounds/saber-swing-high.wav")
    loops: RemoteSound.Infinite
    volume: 0
  }
  RemoteSound {
    id: saberRetractSound
    audio: root.audio
    source: Qt.resolvedUrl("sounds/saber-retract.wav")
    volume: root.saberVolume
  }
  RemoteSound {
    id: saberClashSound
    audio: root.audio
    source: Qt.resolvedUrl("sounds/saber-clash.wav")
    volume: root.saberVolume
  }
  RemoteSound {
    id: saberClashSound2
    audio: root.audio
    source: Qt.resolvedUrl("sounds/saber-clash-2.wav")
    volume: root.saberVolume
  }
  RemoteSound {
    id: saberSizzleSound
    audio: root.audio
    source: Qt.resolvedUrl("sounds/saber-sizzle.wav")
    loops: RemoteSound.Infinite
    volume: 0
  }
  RemoteSound {
    id: saberCutSound
    audio: root.audio
    source: Qt.resolvedUrl("sounds/saber-cut.wav")
    volume: root.saberVolume
  }
  RemoteSound {
    id: saberIgniteSound
    audio: root.audio
    source: Qt.resolvedUrl("sounds/saber-ignite.wav")
    volume: root.saberVolume
  }
  // The saber hilt arrives unlit; its ignition is the ready sound.
  function playEquipSound(id) {
    weaponReadySound.stop()
    if (id !== "lightsaber") weaponReadySound.play()
  }

  function spawnTarget() {
    if (!armed || !targetsEnabled) return
    var margin = targetRadius + 55
    var usableWidth = Math.max(1, window.width - margin * 2)
    var usableHeight = Math.max(1, window.height - margin * 2)
    targetX = margin + Math.random() * usableWidth
    targetY = margin + Math.random() * usableHeight
    targetVisible = true
    canvas.requestPaint()
  }
  function projectileHitsTarget(p, radius) {
    if (!targetVisible) return false
    var dx = p.x - targetX
    var dy = p.y - targetY
    return dx * dx + dy * dy <= Math.pow(targetRadius + radius, 2)
  }
  function segmentHitsTarget(x0, y0, x1, y1, radius) {
    if (!targetVisible) return false
    var dx = x1 - x0, dy = y1 - y0
    var lengthSquared = dx * dx + dy * dy
    var t = lengthSquared > 0 ? ((targetX - x0) * dx + (targetY - y0) * dy) / lengthSquared : 0
    t = Math.max(0, Math.min(1, t))
    return projectileHitsTarget({ x: x0 + t * dx, y: y0 + t * dy }, radius)
  }
  function targetWithinBlast(x, y, radius) {
    if (!targetVisible) return false
    var dx = x - targetX
    var dy = y - targetY
    return dx * dx + dy * dy <= Math.pow(radius + targetRadius, 2)
  }
  function rocketBlastParticles(p) {
    var effects = []
    var boomScale = p.boomScale || 1
    effects.push({ x: p.x, y: p.y, vx: 0, vy: 0, life: 1, size: 1, maxRadius: 180 * boomScale, kind: 4 })
    for (var burst = 0; burst < 72 * boomScale; burst++) {
      var burstAngle = Math.random() * Math.PI * 2
      var burstSpeed = (4 + Math.random() * 17) * Math.sqrt(boomScale)
      effects.push({ x: p.x, y: p.y, vx: Math.cos(burstAngle) * burstSpeed, vy: Math.sin(burstAngle) * burstSpeed, life: 0.65 + Math.random() * 0.55, size: (2 + Math.random() * 8) * Math.sqrt(boomScale), kind: 1 })
    }
    return effects
  }
  function playRocketExplosion(p) {
    if (bugHuntEnabled && bugLayerLoader.item)
      bugLayerLoader.item.hitBlast(p.x, p.y, 180 * (p.boomScale || 1), p.weapon)
    rocketExplosionSound.stop()
    rocketExplosionSound.volume = (p.boomScale || 1) > 1 ? 1.0 : 0.76
    rocketExplosionSound.play()
  }
  function hitTarget() {
    if (!targetVisible) return
    targetVisible = false
    canvas.requestPaint()
    targetHitSound.stop()
    targetHitSound.play()
    var smoke = pendingEffects.slice()
    for (var i = 0; i < 28; i++) {
      var smokeAngle = Math.random() * Math.PI * 2
      var smokeSpeed = 0.8 + Math.random() * 4.2
      smoke.push({ x: targetX, y: targetY, vx: Math.cos(smokeAngle) * smokeSpeed, vy: Math.sin(smokeAngle) * smokeSpeed - 1.2, life: 0.7 + Math.random() * 0.3, size: 7 + Math.random() * 12, kind: 7 })
    }
    pendingEffects = smoke
    wakeSimulation()
    targetRespawnTimer.restart()
  }
  function setTargetsEnabled(enabled) {
    targetsEnabled = enabled
    if (enabled) bugHuntEnabled = false
    if (enabled) destructionEnabled = false
    targetRespawnTimer.stop()
    targetVisible = false
    canvas.requestPaint()
    if (targetsEnabled && armed) spawnTarget()
  }
  function setDestructionEnabled(enabled) {
    destructionEnabled = enabled
    if (enabled) bugHuntEnabled = false
    if (enabled) setTargetsEnabled(false)
  }

  // The weapon case offers these as one choice: "free", "targets", "hunt", or "destruction".
  readonly property string mode: bugHuntEnabled ? "hunt" : targetsEnabled ? "targets" : destructionEnabled ? "destruction" : "free"
  function setMode(name) {
    setTargetsEnabled(name === "targets")
    setDestructionEnabled(name === "destruction")
    setBugHuntEnabled(name === "hunt")
  }
  function setBugHuntEnabled(enabled) {
    if (enabled) {
      setTargetsEnabled(false)
      setDestructionEnabled(false)
    }
    bugHuntEnabled = enabled
  }

  function hitBug(x0, y0, x1, y1, radius, weapon) {
    return bugLayerLoader.item ? bugLayerLoader.item.hitProjectile(x0, y0, x1, y1, radius, weapon) : false
  }

  function arm(id) {
    if (armed) {
      var huntWeaponChanged = bugHuntEnabled && id !== weapon
      swapWeapon(id)
      // Picking another weapon from the case mid-hunt starts a fresh round with it.
      if (huntWeaponChanged && bugLayerLoader.item) bugLayerLoader.item.restart()
      return
    }
    if (!destructionEnabled) {
      desktopSnapshot = ""
      destructibles = []
      carveMarks = []
      carveBuckets = ({})
      regionCarveMarks = ({})
      fallingPieces.clear()
      destroyedRegions.clear()
      terrainNeedsReset = true
      terrainReady = false
      paintedCarveCount = 0
      equip(id, false)
      return
    }
    pendingWeapon = id
    captureInProgress = true
    captureError = ""
    desktopSnapshot = ""
    destructibles = []
    fallingPieces.clear()
    destroyedRegions.clear()
    clientGeometryJson = "[]"
    clientGeometryReady = false
    activeWorkspaceId = -1
    activeWorkspaceReady = false
    captureOffsetX = 0
    captureOffsetY = 0
    captureWidth = 0
    captureHeight = 0
    carveMarks = []
    carveBuckets = ({})
    regionCarveMarks = ({})
    terrainNeedsReset = true
    terrainReady = false
    paintedCarveCount = 0
    // Geometry and wallpaper lookup can run while the compositor settles;
    // only the actual screenshot needs to wait for the drawer to disappear.
    clientQueryProcess.exec(["/usr/bin/hyprctl", "clients", "-j"])
    workspaceQueryProcess.exec(["/usr/bin/hyprctl", "monitors", "-j"])
    wallpaperQueryProcess.exec(["/usr/bin/readlink", "-f", "--", Quickshell.env("HOME") + "/.local/state/omarchy/current/background"])
    captureDelay.restart()
  }
  function swapWeapon(id) {
    cancelSaber()
    weaponWheelOpen = false
    weaponWheelSelection = -1
    automaticHoldEngaged = false
    automaticHoldTimer.stop()
    fireTimer.stop()
    automaticSound.stop()
    mp5AutomaticSound.stop()
    recoil = 0
    flash = 0
    previousRecoil = 0
    previousFlash = 0
    weapon = id
    playEquipSound(id)
    canvas.requestPaint()
    // Deliberately preserve gunX/gunY, aimAngle, aimFlipped, particles,
    // targets, and destruction state during an in-arena wheel swap.
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }
  function equip(id, animateActivation) {
    cancelSaber()
    weaponWheelOpen = false
    weaponWheelSelection = -1
    weapon = id
    activationShadeAnimation.stop()
    activationShade = animateActivation ? 1 : 0
    armed = true
    playEquipSound(id)
    if (animateActivation) activationShadeAnimation.start()
    gunPositioned = false
    aimFlipped = false
    trickAnimation.stop()
    trickAngle = 0
    weaponSpinSound.stop()
    particles = []
    pendingEffects = []
    targetVisible = false
    if (targetsEnabled) Qt.callLater(root.spawnTarget)
    canvas.requestPaint()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }
  function finishCapture() {
    if (!captureInProgress) return
    captureInProgress = false
    var id = pendingWeapon
    pendingWeapon = ""
    equip(id, true)
  }
  function abortCapture(message) {
    if (!captureInProgress) return
    captureInProgress = false
    captureDelay.stop()
    captureError = message
    var id = pendingWeapon
    pendingWeapon = ""
    captureProcess.running = false
    desktopSnapshot = ""
    destructibles = []
    // Never cover the real workspace with the wallpaper fallback when a
    // screencopy cannot be decoded. Keep the selected weapon usable in the
    // ordinary transparent-overlay mode and make the checkbox reflect that.
    setDestructionEnabled(false)
    console.warn("Desktop destruction disabled: " + message)
    equip(id, false)
  }
  function tryFinishCapture() {
    if (!captureInProgress || snapshotImage.status !== Image.Ready || !clientGeometryReady || !activeWorkspaceReady) return
    captureWidth = snapshotImage.sourceSize.width
    captureHeight = snapshotImage.sourceSize.height
    prepareDestructibles(clientGeometryJson)
    finishCapture()
  }
  function prepareDestructibles(clientJson) {
    var regions = []
    var arenaWidth = captureWidth
    var arenaHeight = captureHeight
    // barSize is the content box; include its border/shadow so no captured
    // rim is left behind after the bar falls.
    var thickness = Math.max(1, barThickness) + 12
    if (barPosition === "bottom")
      regions.push({ id: "bar", kind: "bar", x: 0, y: arenaHeight - thickness, width: arenaWidth, height: thickness, hits: 0, limit: 60, destroyed: false })
    else if (barPosition === "left")
      regions.push({ id: "bar", kind: "bar", x: 0, y: 0, width: thickness, height: arenaHeight, hits: 0, limit: 60, destroyed: false })
    else if (barPosition === "right")
      regions.push({ id: "bar", kind: "bar", x: arenaWidth - thickness, y: 0, width: thickness, height: arenaHeight, hits: 0, limit: 60, destroyed: false })
    else
      regions.push({ id: "bar", kind: "bar", x: 0, y: 0, width: arenaWidth, height: thickness, hits: 0, limit: 60, destroyed: false })

    try {
      var clients = JSON.parse(clientJson || "[]")
      for (var i = 0; i < clients.length; i++) {
        var client = clients[i]
        if (!client || client.mapped === false || client.hidden === true || !client.at || !client.size) continue
        if (activeWorkspaceId >= 0 && (!client.workspace || Number(client.workspace.id) !== activeWorkspaceId)) continue
        // Hyprland's client box can leave the compositor border/shadow just
        // outside it. Include that trim so a fallen window leaves no frame.
        var trim = 7
        var x = Number(client.at[0]) - captureOffsetX - trim
        var y = Number(client.at[1]) - captureOffsetY - trim
        var width = Number(client.size[0]) + trim * 2
        var height = Number(client.size[1]) + trim * 2
        if (width < 20 || height < 20 || x >= arenaWidth || y >= arenaHeight || x + width <= 0 || y + height <= 0) continue
        regions.push({
          id: String(client.address || "window-" + i),
          kind: "window",
          title: String(client.title || client.class || "window"),
          x: Math.max(0, x), y: Math.max(0, y),
          width: Math.min(width, arenaWidth - Math.max(0, x)),
          height: Math.min(height, arenaHeight - Math.max(0, y)),
          hits: 0, limit: 120, destroyed: false
        })
      }
    } catch (error) {
      console.warn("Blow off some steam: could not read window geometry", error)
    }
    for (var r = 0; r < regions.length; r++)
      regions[r].poly = Cut.rect(regions[r].x, regions[r].y, regions[r].width, regions[r].height), regions[r].holes = []
    destructibles = regions
    console.info("Desktop destruction prepared " + regions.length + " regions")
  }
  function damageDesktop(x, y, amount, style, radius) {
    var next = destructibles.slice()
    if (style === "blast") {
      var marks = carveMarks
      var dirtyLeft = x - radius
      var dirtyTop = y - radius
      var dirtyRight = x + radius
      var dirtyBottom = y + radius
      for (var blastIndex = 0; blastIndex < next.length; blastIndex++) {
        var blastRegion = next[blastIndex]
        if (blastRegion.destroyed) continue
        var closestX = Math.max(blastRegion.x, Math.min(x, blastRegion.x + blastRegion.width))
        var closestY = Math.max(blastRegion.y, Math.min(y, blastRegion.y + blastRegion.height))
        var blastDx = x - closestX
        var blastDy = y - closestY
        if (blastDx * blastDx + blastDy * blastDy > radius * radius) continue
        var blastMark = {
          regionId: blastRegion.id,
          x: x, y: y, radius: radius,
          clipX: blastRegion.x, clipY: blastRegion.y,
          clipWidth: blastRegion.width, clipHeight: blastRegion.height
        }
        marks.push(blastMark)
        indexCarveMark(blastMark)
        blastRegion.hits += amount
        if (blastRegion.hits >= blastRegion.limit) destroyRegion(blastRegion)
      }
      destructibles = next
      if (terrainCanvasLoader.item)
        terrainCanvasLoader.item.applyDamage(Qt.rect(dirtyLeft, dirtyTop,
                                                     dirtyRight - dirtyLeft, dirtyBottom - dirtyTop))
      return
    }
    for (var i = next.length - 1; i >= 0; i--) {
      var region = next[i]
      if (region.destroyed || !Cut.solid(regionLoops(region), x, y)) continue
      region.hits += amount
      if (region.hits >= region.limit) destroyRegion(region)
      destructibles = next
      return
    }
    destructibles = next
  }
  function carveRegion(regionId, x, y, directionX, directionY, power) {
    var next = destructibles.slice()
    for (var i = 0; i < next.length; i++) {
      var region = next[i]
      if (region.id !== regionId || region.destroyed) continue
      var marks = carveMarks
      var biteCount = 5 + Math.round(power * 2)
      var spacing = 4.5 + power
      var dirtyLeft = x
      var dirtyTop = y
      var dirtyRight = x
      var dirtyBottom = y
      for (var bite = 0; bite < biteCount; bite++) {
        var biteMark = {
          regionId: region.id,
          x: x + directionX * bite * spacing + (Math.random() - 0.5) * 2.5,
          y: y + directionY * bite * spacing + (Math.random() - 0.5) * 2.5,
          radius: 5.5 + power * 2.2 + Math.random() * 2.8,
          clipX: region.x, clipY: region.y,
          clipWidth: region.width, clipHeight: region.height
        }
        marks.push(biteMark)
        indexCarveMark(biteMark)
        dirtyLeft = Math.min(dirtyLeft, biteMark.x - biteMark.radius)
        dirtyTop = Math.min(dirtyTop, biteMark.y - biteMark.radius)
        dirtyRight = Math.max(dirtyRight, biteMark.x + biteMark.radius)
        dirtyBottom = Math.max(dirtyBottom, biteMark.y + biteMark.radius)
      }
      if (terrainCanvasLoader.item)
        terrainCanvasLoader.item.applyDamage(Qt.rect(dirtyLeft, dirtyTop,
                                                     dirtyRight - dirtyLeft, dirtyBottom - dirtyTop))
      region.hits += 1
      if (region.hits >= region.limit) destroyRegion(region)
      break
    }
    destructibles = next
  }
  function carveRicochetImpact(x, y, directionX, directionY, power) {
    if (!destructionEnabled) return
    var length = Math.max(0.001, Math.sqrt(directionX * directionX + directionY * directionY))
    var normalizedX = directionX / length
    var normalizedY = directionY / length
    var impact = firstDesktopImpact(x, y, normalizedX, normalizedY, true)
    if (impact)
      carveRegion(impact.regionId, impact.x, impact.y, normalizedX, normalizedY, power)
  }
  function carveBucketKey(regionId, cellX, cellY) {
    return regionId + ":" + cellX + ":" + cellY
  }
  function indexCarveMark(mark) {
    if (!regionCarveMarks[mark.regionId]) regionCarveMarks[mark.regionId] = []
    regionCarveMarks[mark.regionId].push(mark)
    // Only bullet and blast circles are holes that shots can tunnel through.
    if (mark.type) return
    var cellSize = 32
    var firstX = Math.floor((mark.x - mark.radius) / cellSize)
    var lastX = Math.floor((mark.x + mark.radius) / cellSize)
    var firstY = Math.floor((mark.y - mark.radius) / cellSize)
    var lastY = Math.floor((mark.y + mark.radius) / cellSize)
    for (var cellY = firstY; cellY <= lastY; cellY++) {
      for (var cellX = firstX; cellX <= lastX; cellX++) {
        var key = carveBucketKey(mark.regionId, cellX, cellY)
        if (!carveBuckets[key]) carveBuckets[key] = []
        carveBuckets[key].push(mark)
      }
    }
  }
  function carvedExitDistance(regionId, x, y, directionX, directionY, distance) {
    var cellSize = 32
    var nearby = carveBuckets[carveBucketKey(regionId,
                                             Math.floor(x / cellSize),
                                             Math.floor(y / cellSize))]
    if (!nearby) return -1
    var furthestExit = -1
    for (var i = nearby.length - 1; i >= 0; i--) {
      var mark = nearby[i]
      var dx = x - mark.x
      var dy = y - mark.y
      var radiusSquared = mark.radius * mark.radius
      if (dx * dx + dy * dy > radiusSquared) continue
      var centerAhead = (mark.x - x) * directionX + (mark.y - y) * directionY
      var centerPerpendicularX = mark.x - x - centerAhead * directionX
      var centerPerpendicularY = mark.y - y - centerAhead * directionY
      var halfChord = Math.sqrt(Math.max(0, radiusSquared
                                           - centerPerpendicularX * centerPerpendicularX
                                           - centerPerpendicularY * centerPerpendicularY))
      furthestExit = Math.max(furthestExit, distance + centerAhead + halfChord)
    }
    return furthestExit
  }
  function firstDesktopImpact(originX, originY, directionX, directionY, includeContainingRegion) {
    var nearest = null
    for (var i = 0; i < destructibles.length; i++) {
      var region = destructibles[i]
      if (region.destroyed) continue
      // Saber cuts leave concave outlines and holes, so test the actual shape.
      var loops = regionLoops(region)
      var inside = Cut.solid(loops, originX, originY)
      // The weapon is visually floating above the captured desktop. Do not
      // let the window underneath it catch the bullet on the way out.
      if (inside && !includeContainingRegion) continue
      var solidSpans = Cut.spans(loops, {x: originX, y: originY}, {x: originX + directionX, y: originY + directionY})
      var distance = -1, exit = -1
      for (var spanIndex = 0; spanIndex < solidSpans.length; spanIndex++) {
        exit = solidSpans[spanIndex][1]
        if (exit <= 4) continue
        distance = Math.max(solidSpans[spanIndex][0], 4.01)
        if (nearest && distance >= nearest.distance) break

        // Carved circles are empty space too, so let this shot travel through
        // them until it reaches the next intact pixel. Shooting the same line
        // repeatedly therefore digs a progressively deeper tunnel instead of
        // re-hitting the original edge.
        while (distance <= exit) {
          var carvedExit = carvedExitDistance(region.id,
                                              originX + directionX * distance,
                                              originY + directionY * distance,
                                              directionX, directionY, distance)
          if (carvedExit < 0) break
          distance = Math.max(distance + 1, carvedExit + 0.5)
        }
        if (distance <= exit) break
      }
      if (distance < 0 || distance > exit || (nearest && distance >= nearest.distance)) continue
      nearest = {
        regionId: region.id,
        x: originX + directionX * distance,
        y: originY + directionY * distance,
        distance: distance
      }
    }
    return nearest
  }
  // quiet: a saber cut already played its own sound.
  function destroyRegion(region, quiet) {
    region.destroyed = true
    if (!quiet) playWindowBreak()
    destroyedRegions.append({
      patchX: region.x, patchY: region.y,
      patchWidth: region.width, patchHeight: region.height
    })
    dropPiece(region, region.poly, 0, (Math.random() < 0.5 ? -1 : 1) * 12, [], true)
  }
  // A falling copy of part of a window: its outline, the marks it already
  // carries, a sideways drift and spin, and an optional glowing cut edge (a
  // polyline of points).
  function dropPiece(region, poly, drift, spin, edge, whole) {
    var box = Cut.bounds(poly)
    var glow = []
    for (var i = 0; i < edge.length; i++) glow.push(edge[i].x - box.x, edge[i].y - box.y)
    fallingPieces.append({
      pieceToken: ++fallingSerial,
      pieceRegionId: region.id,
      pieceX: box.x, pieceY: box.y,
      pieceWidth: Math.max(1, box.width), pieceHeight: Math.max(1, box.height),
      piecePoints: JSON.stringify(Cut.translate(poly, -box.x, -box.y)),
      pieceEdge: JSON.stringify(glow),
      pieceMarkLimit: (regionCarveMarks[region.id] || []).length,
      pieceDrift: drift, pieceSpin: spin, pieceWhole: whole,
      fallDuration: 850 + Math.random() * 450
    })
  }
  function removeFallingPiece(token) {
    for (var i = 0; i < fallingPieces.count; i++) {
      if (fallingPieces.get(i).pieceToken === token) {
        var regionId = fallingPieces.get(i).pieceRegionId
        var whole = fallingPieces.get(i).pieceWhole
        fallingPieces.remove(i)
        // A cut-off piece leaves its window standing, so its marks stay.
        if (whole) pruneRegionMarks(regionId)
        return
      }
    }
  }
  function pruneRegionMarks(regionId) {
    var retained = []
    for (var i = 0; i < carveMarks.length; i++) {
      if (carveMarks[i].regionId !== regionId) retained.push(carveMarks[i])
    }
    carveMarks = retained
    regionCarveMarks = ({})
    carveBuckets = ({})
    for (var markIndex = 0; markIndex < retained.length; markIndex++)
      indexCarveMark(retained[markIndex])
    // The surviving marks are already present in the persistent terrain
    // image; only subsequently appended marks need painting.
    paintedCarveCount = retained.length
  }
  function playWindowBreak() {
    windowBreakVariant = (windowBreakVariant + 1) % 6
    switch (windowBreakVariant) {
    case 0: windowBreak1.play(); break
    case 1: windowBreak2.play(); break
    case 2: windowBreak3.play(); break
    case 3: windowBreak4.play(); break
    case 4: windowBreak5.play(); break
    default: windowBreak6.play(); break
    }
  }
  function holster() {
    cancelSaber()
    armed = false
    canvas.clear()
    particleBuffer = []
    captureInProgress = false
    pendingWeapon = ""
    captureDelay.stop()
    if (captureProcess.running) captureProcess.running = false
    weaponWheelOpen = false
    weaponWheelSelection = -1
    keyboardWeaponWheel = false
    automaticHoldEngaged = false
    automaticHoldTimer.stop()
    fireTimer.stop()
    pistolSound.stop()
    akSingleSound.stop()
    automaticSound.stop()
    mp5SingleSound.stop()
    mp5AutomaticSound.stop()
    revolverSound.stop()
    bazookaLaunchSound.stop()
    rocketExplosionSound.stop()
    targetHitSound.stop()
    weaponReadySound.stop()
    saberClashSound.stop()
    saberClashSound2.stop()
    saberRetractSound.stop()
    windowBreak1.stop()
    windowBreak2.stop()
    windowBreak3.stop()
    windowBreak4.stop()
    windowBreak5.stop()
    windowBreak6.stop()
    trickAnimation.stop()
    trickAngle = 0
    weaponSpinSound.stop()
    particles = []
    pendingEffects = []
    targetVisible = false
    targetRespawnTimer.stop()
    destructibles = []
    fallingPieces.clear()
    destroyedRegions.clear()
    carveMarks = []
    carveBuckets = ({})
    regionCarveMarks = ({})
    paintedCarveCount = 0
    terrainNeedsReset = true
    terrainReady = false
    clientGeometryJson = "[]"
    clientGeometryReady = false
    activeWorkspaceReady = false
    desktopSnapshot = ""
  }
  function playWeaponSound() {
    if (weapon === "mp5a3") mp5SingleSound.play()
    else if (spec.automatic) akSingleSound.play()
    else if (weapon === "revolver") revolverSound.play()
    else if (weapon === "bazooka") bazookaLaunchSound.play()
    else pistolSound.play()
  }
  function shoot(withSound) {
    if (!armed || roundFinished) return false
    if (weapon === "lightsaber") return igniteSaber()
    if (weapon === "bazooka") {
      // Reject extra clicks before sound, recoil, flash, or particle creation.
      if (rocketCooldown.running) return false
      rocketCooldown.interval = spec.interval
      rocketCooldown.start()
    }
    if (bugHuntEnabled && bugLayerLoader.item && !bugLayerLoader.item.acceptHits()) return false
    if (withSound === undefined || withSound) playWeaponSound()
    recoil = spec.recoil
    flash = 1
    previousRecoil = recoil
    previousFlash = flash
    wakeSimulation()
    var angle = aimAngle * Math.PI / 180
    var cosA = Math.cos(angle)
    var sinA = Math.sin(angle)
    var localMuzzleX = (spec.muzzleX - spec.gripX) * spec.scale
    var localMuzzleY = (spec.muzzleY - spec.gripY) * spec.scale * (aimFlipped ? -1 : 1)
    var muzzleX = gunX - recoil * cosA + localMuzzleX * cosA - localMuzzleY * sinA
    var muzzleY = gunY - recoil * sinA + localMuzzleX * sinA + localMuzzleY * cosA
    var count = spec.particles
    var power = spec.power
    var next = particles.slice()
    var speed = (17 + Math.random() * 12) * power
    var spread = (Math.random() - 0.5) * 8 * power
    if (weapon === "bazooka") {
      var rocketImpact = firstDesktopImpact(muzzleX, muzzleY, cosA, sinA)
      next.push({
        x: muzzleX, y: muzzleY, vx: 6 * power * cosA, vy: 6 * power * sinA,
        life: 1, age: 0, explodeAt: 1.52, size: 5 * power,
        boomScale: 1, kind: 3, weapon: weapon,
        impactX: rocketImpact ? rocketImpact.x : 0,
        impactY: rocketImpact ? rocketImpact.y : 0,
        impactRegionId: rocketImpact ? rocketImpact.regionId : "",
        impacted: rocketImpact === null
      })
    }
    else {
      var impact = firstDesktopImpact(muzzleX, muzzleY, cosA, sinA)
      next.push({
        x: muzzleX, y: muzzleY,
        vx: speed * cosA, vy: speed * sinA,
        life: 1, size: 3.6 + spec.power * 0.6, bounces: 0, kind: 6, weapon: weapon,
        impactX: impact ? impact.x : 0,
        impactY: impact ? impact.y : 0,
        impactRegionId: impact ? impact.regionId : "",
        impactPower: power, impacted: impact === null
      })
    }
    for (var i = 0; i < count; i++) {
      speed = (7 + Math.random() * 17) * power
      spread = (Math.random() - 0.5) * 13 * power
      next.push({ x: muzzleX, y: muzzleY, vx: speed * cosA - spread * sinA, vy: speed * sinA + spread * cosA, life: 0.6 + Math.random() * 0.4, size: 1 + Math.random() * 4 * power, kind: 1 })
    }
    if (spec.ejectsCase !== false && weapon !== "bazooka") {
      var ejectLocalX = (spec.ejectX - spec.gripX) * spec.scale
      var ejectLocalY = (spec.ejectY - spec.gripY) * spec.scale * (aimFlipped ? -1 : 1)
      var ejectX = gunX + ejectLocalX * cosA - ejectLocalY * sinA
      var ejectY = gunY + ejectLocalX * sinA + ejectLocalY * cosA
      var ejectSpeed = 4.5 + Math.random() * 2.5
      var ejectSide = aimFlipped ? 1 : -1
      var ejectVelocityX = -ejectSide * ejectSpeed * sinA - cosA * 1.4
      var ejectVelocityY = ejectSide * ejectSpeed * cosA - sinA * 1.4
      next.push({ x: ejectX, y: ejectY, vx: ejectVelocityX, vy: ejectVelocityY, life: 1, size: 3, angle: Math.random() * Math.PI * 2, spin: (Math.random() - 0.5) * 0.5, bounces: 0, kind: 2 })
    }
    if (weapon === "revolver") {
      for (var smoke = 0; smoke < 7; smoke++)
        next.push({ x: muzzleX, y: muzzleY, vx: (1.2 + Math.random() * 2.6) * cosA + (Math.random() - 0.5) * 1.5, vy: (1.2 + Math.random() * 2.6) * sinA - Math.random() * 1.3, life: 0.55 + Math.random() * 0.3, size: 4 + Math.random() * 5, kind: 5 })
    }
    particles = next
    return true
  }

  PanelWindow {
    id: window
    visible: root.armed
    screen: root.targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "blow-off-some-steam"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    mask: Region {
      width: window.width
      height: window.height
    }

    Image {
      anchors.fill: parent
      source: root.wallpaperSource
      visible: root.destructionEnabled && root.armed && String(root.desktopSnapshot) !== ""
      asynchronous: true
      fillMode: Image.PreserveAspectCrop
      cache: true
      smooth: true
    }

    Image {
      id: snapshotImage
      anchors.fill: parent
      source: root.terrainReady ? "" : root.desktopSnapshot
      // This exact frame bridges activation until the destructible Canvas has
      // completed its first paint, avoiding a dark/wallpaper flash.
      visible: root.destructionEnabled && root.armed && !root.terrainReady
      fillMode: Image.Stretch
      cache: false
      asynchronous: true
      smooth: true
      onStatusChanged: {
        if (!root.captureInProgress) return
        if (status === Image.Ready) root.tryFinishCapture()
        else if (status === Image.Error) {
          root.abortCapture("Could not load the desktop snapshot")
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      color: root.background
      visible: root.destructionEnabled && root.armed && String(root.desktopSnapshot) === ""
    }

    Loader {
      id: terrainCanvasLoader
      anchors.fill: parent
      // Instantiate only once the layer is visible. Loading this threaded
      // Canvas while hidden can lose its first paint, leaving the intact
      // snapshot bridge visible underneath every transparent damage mark.
      active: root.destructionEnabled && root.armed && String(root.desktopSnapshot) !== ""
      visible: active
      sourceComponent: TerrainLayer { arena: root }
    }

    Repeater {
      model: destroyedRegions
      visible: root.destructionEnabled
      delegate: Item {
        required property real patchX
        required property real patchY
        required property real patchWidth
        required property real patchHeight
        visible: root.destructionEnabled
        x: patchX
        y: patchY
        width: patchWidth
        height: patchHeight
        clip: true
        z: 7

        Image {
          x: -parent.patchX
          y: -parent.patchY
          width: window.width
          height: window.height
          source: root.wallpaperSource
          fillMode: Image.PreserveAspectCrop
          cache: true
          smooth: true
        }
      }
    }

    Repeater {
      model: fallingPieces
      visible: root.destructionEnabled
      delegate: Item {
        id: fallingPiece
        visible: root.destructionEnabled
        required property int pieceToken
        required property string pieceRegionId
        required property real pieceX
        required property real pieceY
        required property real pieceWidth
        required property real pieceHeight
        required property string piecePoints
        required property string pieceEdge
        required property int pieceMarkLimit
        required property real pieceDrift
        required property real pieceSpin
        required property real fallDuration
        x: pieceX
        y: pieceY
        width: pieceWidth
        height: pieceHeight
        z: 8

        Canvas {
          id: fallingCanvas
          anchors.fill: parent
          renderStrategy: Canvas.Threaded
          Component.onCompleted: {
            var source = String(root.desktopSnapshot)
            if (source) loadImage(source)
          }
          onImageLoaded: requestPaint()
          onPaint: {
            var c = getContext("2d")
            var source = String(root.desktopSnapshot)
            if (!source || !isImageLoaded(source)) return
            c.reset()
            c.clearRect(0, 0, width, height)
            // Only this piece's shape: a whole window, or the part a saber cut off.
            c.save()
            Cut.path(c, JSON.parse(fallingPiece.piecePoints), 0, 0)
            c.clip()
            c.drawImage(source,
                        fallingPiece.pieceX, fallingPiece.pieceY,
                        fallingPiece.pieceWidth, fallingPiece.pieceHeight,
                        0, 0, width, height)

            // Reapply the destruction the window carried when this piece left
            // it, so holes, grooves, and earlier cuts travel with the piece.
            var pieceMarks = root.regionCarveMarks[fallingPiece.pieceRegionId] || []
            for (var i = 0; i < Math.min(fallingPiece.pieceMarkLimit, pieceMarks.length); i++)
              Marks.draw(c, pieceMarks[i], -fallingPiece.pieceX, -fallingPiece.pieceY)
            c.restore()
            // A freshly cut edge still glows.
            var edge = JSON.parse(fallingPiece.pieceEdge)
            if (edge.length >= 4) {
              c.lineCap = "round"; c.lineJoin = "round"
              var strokes = [[Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.85), 5], ["#fff6e0", 1.6]]
              for (var s = 0; s < strokes.length; s++) {
                c.strokeStyle = strokes[s][0]
                c.lineWidth = strokes[s][1]
                c.beginPath()
                c.moveTo(edge[0], edge[1])
                for (var e = 2; e + 1 < edge.length; e += 2) c.lineTo(edge[e], edge[e + 1])
                c.stroke()
              }
            }
          }
        }
        transform: Rotation {
          id: fallRotation
          origin.x: fallingPiece.width / 2
          origin.y: fallingPiece.height / 2
          angle: 0
        }
        NumberAnimation on y {
          from: fallingPiece.pieceY
          to: window.height + fallingPiece.height + 80
          duration: fallingPiece.fallDuration
          easing.type: Easing.InQuad
          running: true
          onFinished: root.removeFallingPiece(fallingPiece.pieceToken)
        }
        NumberAnimation {
          target: fallRotation
          property: "angle"
          from: 0
          to: fallingPiece.pieceSpin
          duration: fallingPiece.fallDuration
          running: true
        }
        NumberAnimation on x {
          from: fallingPiece.pieceX
          to: fallingPiece.pieceX + fallingPiece.pieceDrift
          duration: fallingPiece.fallDuration
          easing.type: Easing.OutQuad
          running: true
        }
      }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      onActiveFocusChanged: if (!activeFocus) root.retractSaber()
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          if (root.weaponWheelOpen) {
            root.closeWeaponWheel(false)
            root.keyboardWeaponWheel = false
          } else root.holster()
          event.accepted = true
          return
        }
        if (root.roundFinished) return
        if (root.huntBriefing && (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
          bugLayerLoader.item.startCountdown()
          event.accepted = true
          return
        }
        if (event.key === Qt.Key_Q && !event.isAutoRepeat) {
          if (!root.weaponWheelOpen && !root.bugHuntEnabled) {
            root.keyboardWeaponWheel = true
            root.openWeaponWheel(root.gunPositioned ? root.gunX : window.width / 2,
                                 root.gunPositioned ? root.gunY : window.height / 2)
            root.weaponWheelSelection = root.currentWeaponIndex()
          }
          event.accepted = true
          return
        }
        if (root.weaponWheelOpen && root.keyboardWeaponWheel) {
          if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
            root.weaponWheelSelection = (root.weaponWheelSelection + root.weaponOptions.length - 1) % root.weaponOptions.length
            event.accepted = true
          } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
            root.weaponWheelSelection = (root.weaponWheelSelection + 1) % root.weaponOptions.length
            event.accepted = true
          } else if (event.key >= Qt.Key_1 && event.key < Qt.Key_1 + root.weaponOptions.length) {
            root.weaponWheelSelection = event.key - Qt.Key_1
            root.closeWeaponWheel(true)
            root.keyboardWeaponWheel = false
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.closeWeaponWheel(true)
            root.keyboardWeaponWheel = false
            event.accepted = true
          }
        }
      }
      Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Q && root.keyboardWeaponWheel && !event.isAutoRepeat) {
          root.closeWeaponWheel(true)
          root.keyboardWeaponWheel = false
          event.accepted = true
        }
      }
    }

    Loader {
      id: bugLayerLoader
      anchors.fill: parent
      z: root.roundFinished ? 45 : 19
      active: root.armed && root.bugHuntEnabled
      sourceComponent: BugHuntLayer { arena: root }
    }

    EffectsLayer {
      id: canvas
      anchors.fill: parent
      z: 20
      arena: root
      // Shots and blasts shake with the flies during Fly Hunt.
      transform: Translate {
        x: bugLayerLoader.item ? bugLayerLoader.item.shakeX : 0
        y: bugLayerLoader.item ? bugLayerLoader.item.shakeY : 0
      }
    }

    // Saber grooves glow white-hot in the theme colour, then cool to orange and
    // fade, leaving the charred scorch painted into the desktop underneath.
    Repeater {
      model: 96
      delegate: Item {
        id: heatSegment
        required property int index
        readonly property var heat: root.saberHeat[index] || null
        readonly property real cooling: heat ? Math.min(1, heat.age / root.saberHeatLife) : 1
        readonly property real length: heat ? Math.hypot(heat.x1 - heat.x0, heat.y1 - heat.y0) : 0
        visible: !!heat && root.destructionEnabled
        z: 9
        x: heat ? heat.x0 : 0
        y: heat ? heat.y0 : 0
        transform: Rotation { angle: heatSegment.heat ? Math.atan2(heatSegment.heat.y1 - heatSegment.heat.y0, heatSegment.heat.x1 - heatSegment.heat.x0) * 180 / Math.PI : 0 }
        Rectangle {
          x: -height / 2; y: -height / 2
          width: heatSegment.length + height; height: 11; radius: height / 2
          color: root.accent
          opacity: 0.5 * Math.pow(1 - heatSegment.cooling, 1.5)
        }
        Rectangle {
          x: -height / 2; y: -height / 2
          width: heatSegment.length + height; height: 3; radius: height / 2
          color: heatSegment.cooling < 0.2 ? Qt.tint(root.accent, Qt.rgba(1, 1, 1, 1 - heatSegment.cooling / 0.2))
            : Qt.tint(root.accent, Qt.rgba(1, 0.42, 0.1, Math.min(1, (heatSegment.cooling - 0.2) / 0.4)))
          opacity: 1 - heatSegment.cooling
        }
      }
    }
    Repeater {
      model: 8
      delegate: Rectangle {
        required property int index
        readonly property var sample: root.saberTrail[index] || null
        visible: !!sample && root.weapon === "lightsaber"
        z: 29
        x: sample ? sample.base.x : 0
        y: sample ? sample.base.y - height / 2 : 0
        width: sample ? Math.hypot(sample.tip.x - sample.base.x, sample.tip.y - sample.base.y) : 0
        height: 9; radius: 4
        color: root.accent
        opacity: sample ? Math.max(0, 1 - sample.age / 0.13) * 0.25 : 0
        transform: Rotation {
          origin.x: 0; origin.y: 4.5
          angle: sample ? Math.atan2(sample.tip.y - sample.base.y, sample.tip.x - sample.base.x) * 180 / Math.PI : 0
        }
      }
    }
    Item {
      visible: root.armed
      z: 30
      x: root.renderGunX - root.spec.gripX * root.spec.scale - root.renderRecoil * Math.cos(root.renderAimAngle * Math.PI / 180)
      y: root.renderGunY - root.spec.gripY * root.spec.scale - root.renderRecoil * Math.sin(root.renderAimAngle * Math.PI / 180)
      width: root.spec.width * root.spec.scale
      height: root.spec.height * root.spec.scale
      Image {
        anchors.fill: parent
        visible: root.weapon !== "lightsaber"
        source: visible ? Qt.resolvedUrl(root.spec.image) : ""
        fillMode: Image.PreserveAspectFit
        smooth: false
      }
      Loader {
        anchors.fill: parent
        active: root.armed && root.weapon === "lightsaber"
        sourceComponent: LightsaberArt { ignition: root.saberIgnition }
      }
      transform: [
        Scale {
          origin.x: root.spec.gripX * root.spec.scale
          origin.y: root.spec.gripY * root.spec.scale
          yScale: root.aimFlipped ? -1 : 1
          Behavior on yScale {
            NumberAnimation { duration: 120; easing.type: Easing.InOutQuad }
          }
        },
        Rotation {
          origin.x: root.spec.gripX * root.spec.scale
          origin.y: root.spec.gripY * root.spec.scale
          axis.x: 0
          axis.y: 0
          axis.z: 1
          angle: root.trickAngle
        },
        Rotation {
          origin.x: root.spec.gripX * root.spec.scale
          origin.y: root.spec.gripY * root.spec.scale
          angle: root.renderAimAngle
        }
      ]
    }

    Item {
      visible: root.weaponWheelOpen
      anchors.fill: parent
      z: 40

      Repeater {
        model: root.weaponOptions
        delegate: Item {
          id: wheelTile
          required property int index
          required property var modelData
          readonly property real tileAngle: (-90 + index * (360 / root.weaponOptions.length)) * Math.PI / 180
          width: 94
          height: 82
          x: root.weaponWheelX + Math.cos(tileAngle) * 132 - width / 2
          y: root.weaponWheelY + Math.sin(tileAngle) * 132 - height / 2

          Canvas {
            id: hex
            anchors.fill: parent
            onPaint: {
              var c = getContext("2d")
              c.clearRect(0, 0, width, height)
              c.beginPath()
              c.moveTo(width * 0.25, 2)
              c.lineTo(width * 0.75, 2)
              c.lineTo(width - 2, height * 0.5)
              c.lineTo(width * 0.75, height - 2)
              c.lineTo(width * 0.25, height - 2)
              c.lineTo(2, height * 0.5)
              c.closePath()
              c.fillStyle = root.weaponWheelSelection === wheelTile.index
                ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.72)
                : root.tint(root.background, 0.92)
              c.fill()
              c.strokeStyle = root.weaponWheelSelection === wheelTile.index ? root.accent : root.muted
              c.lineWidth = root.weaponWheelSelection === wheelTile.index ? 3 : 2
              c.stroke()
            }
            Component.onCompleted: requestPaint()
            Connections {
              target: root
              function onWeaponWheelSelectionChanged() { hex.requestPaint() }
              function onThemeSignatureChanged() { hex.requestPaint() }
            }
          }

          Loader {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 22; width: 76; height: 28
            active: root.weaponWheelOpen && wheelTile.modelData.id === "lightsaber"
            sourceComponent: LightsaberArt {}
          }
          Image {
            visible: wheelTile.modelData.id !== "lightsaber"
            anchors.horizontalCenter: parent.horizontalCenter
            y: 14
            width: Math.min(64, wheelTile.modelData.clip.width * 1.15)
            height: 30
            source: visible ? Qt.resolvedUrl(wheelTile.modelData.image) : ""
            sourceClipRect: wheelTile.modelData.clip
            fillMode: Image.PreserveAspectFit
            smooth: false
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 52
            text: wheelTile.modelData.name
            color: root.weaponWheelSelection === wheelTile.index ? root.foreground : root.tint(root.foreground, 0.78)
            font.family: root.fontFamily
            font.pixelSize: 11
            font.bold: true
          }
        }
      }

      Rectangle {
        x: root.weaponWheelX - width / 2
        y: root.weaponWheelY - height / 2
        width: 56
        height: 56
        radius: width / 2
        color: root.tint(root.background, 0.85)
        border.width: 2
        border.color: root.muted
        Text {
          anchors.centerIn: parent
          text: "󰜃"
          color: root.foreground
          font.pixelSize: 22
        }
      }
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      enabled: root.armed
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      cursorShape: Qt.CrossCursor
      onPositionChanged: function(event) {
        if (root.weaponWheelOpen) {
          root.updateWeaponWheel(event.x, event.y)
          return
        }
        root.pointerX = event.x
        root.pointerY = event.y
        if (!root.gunPositioned) {
          root.gunX = event.x - root.followDistance
          root.gunY = event.y
          root.gunPositioned = true
          canvas.requestPaint()
        }
      }
      onPressed: function(event) {
        if (root.roundFinished) return
        root.pointerX = event.x
        root.pointerY = event.y
        // The first left-click on the Fly Hunt briefing starts the countdown instead of firing.
        if (event.button === Qt.LeftButton && root.huntBriefing) {
          bugLayerLoader.item.startCountdown()
          return
        }
        if (event.button === Qt.MiddleButton) {
          root.keyboardWeaponWheel = false
          root.openWeaponWheel(event.x, event.y)
          return
        }
        if (event.button === Qt.RightButton) {
          // A lit saber keeps burning through the spin, so the spin cuts too.
          weaponSpinSound.stop()
          if (root.weapon !== "lightsaber" || !root.saberHeld) weaponSpinSound.play()
          root.wakeSimulation()
          trickAnimation.restart()
          return
        }
        if (root.weapon === "lightsaber") {
          root.igniteSaber()
          return
        }
        root.automaticHoldEngaged = false
        if (root.spec.automatic) {
          automaticHoldTimer.restart()
        } else root.shoot()
      }
      onReleased: function(event) {
        if (event.button === Qt.MiddleButton) {
          root.closeWeaponWheel(true)
          return
        }
        if (event.button === Qt.RightButton) return
        if (root.weapon === "lightsaber") { root.retractSaber(); return }
        var pendingSingleShot = root.spec.automatic && !root.automaticHoldEngaged && automaticHoldTimer.running
        automaticHoldTimer.stop()
        fireTimer.stop()
        automaticSound.stop()
        mp5AutomaticSound.stop()
        if (pendingSingleShot) root.shoot()
      }
      onCanceled: {
        root.cancelSaber()
        root.closeWeaponWheel(false)
        automaticHoldTimer.stop()
        fireTimer.stop()
        automaticSound.stop()
        mp5AutomaticSound.stop()
      }
    }

    Rectangle {
      visible: root.armed
      z: 35
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      anchors.margins: 18
      width: hint.implicitWidth + 24
      height: hint.implicitHeight + 14
      radius: root.cornerRadius
      color: root.tint(root.background, 0.75)
      border.width: 1
      border.color: root.tint(root.foreground, 0.12)
      Text {
        id: hint
        anchors.centerIn: parent
        text: root.weaponName + (root.weapon === "lightsaber" ? " · hold left-click to ignite · move to cut · right-click spin" : (root.spec.automatic ? " · click/hold to fire" : " · click to fire")) + (root.bugHuntEnabled ? "" : " · middle/Q-hold weapon wheel") + " · right-click spin · Esc holster"
        color: root.tint(root.foreground, 0.88)
        font.family: root.fontFamily
        font.pixelSize: 12
      }
    }

    // A brief cinematic veil makes the change from the live compositor to
    // its frozen game frame read as an intentional transition.
    Rectangle {
      anchors.fill: parent
      z: 29
      color: root.background
      opacity: root.activationShade * 0.82
      visible: opacity > 0.001
    }
  }

  NumberAnimation {
    id: activationShadeAnimation
    target: root
    property: "activationShade"
    from: 1
    to: 0
    duration: 360
    easing.type: Easing.OutCubic
  }

  Timer {
    id: automaticHoldTimer
    interval: 190
    repeat: false
    onTriggered: {
      if (root.roundFinished) return
      root.automaticHoldEngaged = true
      root.shoot(false)
      if (root.weapon === "mp5a3") mp5AutomaticSound.play()
      else automaticSound.play()
      fireTimer.start()
    }
  }

  NumberAnimation {
    id: trickAnimation
    target: root
    property: "trickAngle"
    from: 0
    to: 360
    duration: 560
    easing.type: Easing.InOutCubic
    onStopped: root.trickAngle = 0
  }

  Timer {
    id: rocketCooldown
    interval: 550
    repeat: false
  }

  Timer {
    id: fireTimer
    interval: root.spec.interval
    repeat: true
    onTriggered: root.shoot(false)
  }


  RemoteSound {
    audio: root.audio
    id: pistolSound
    source: Qt.resolvedUrl("sounds/pistol-shot.wav")
    volume: 0.62
  }

  RemoteSound {
    audio: root.audio
    id: akSingleSound
    source: Qt.resolvedUrl("sounds/ak-single-shot.wav")
    volume: 0.56
  }

  RemoteSound {
    audio: root.audio
    id: mp5SingleSound
    source: Qt.resolvedUrl("sounds/mp5-single-shot.wav")
    volume: 0.56
  }

  RemoteSound {
    audio: root.audio
    id: mp5AutomaticSound
    source: Qt.resolvedUrl("sounds/mp5-automatic-fire.wav")
    loops: RemoteSound.Infinite
    volume: 0.5
  }

  RemoteSound {
    audio: root.audio
    id: automaticSound
    source: Qt.resolvedUrl("sounds/automatic-fire.wav")
    loops: RemoteSound.Infinite
    volume: 0.48
  }

  RemoteSound {
    audio: root.audio
    id: revolverSound
    source: Qt.resolvedUrl("sounds/revolver-shot.wav")
    volume: 0.66
  }

  RemoteSound {
    audio: root.audio
    id: bazookaLaunchSound
    source: Qt.resolvedUrl("sounds/bazooka-launch.wav")
    volume: 0.72
  }

  RemoteSound {
    audio: root.audio
    id: rocketExplosionSound
    source: Qt.resolvedUrl("sounds/bazooka-explosion.wav")
    volume: 0.76
  }

  RemoteSound {
    audio: root.audio
    id: targetHitSound
    source: Qt.resolvedUrl("sounds/target-hit.wav")
    volume: 0.34
  }

  RemoteSound {
    audio: root.audio
    id: weaponSpinSound
    source: Qt.resolvedUrl("sounds/weapon-spin.wav")
    volume: 0.30
  }

  RemoteSound { audio: root.audio; id: windowBreak1; source: Qt.resolvedUrl("sounds/window-break-1.wav"); volume: 0.72 }
  RemoteSound { audio: root.audio; id: windowBreak2; source: Qt.resolvedUrl("sounds/window-break-2.wav"); volume: 0.72 }
  RemoteSound { audio: root.audio; id: windowBreak3; source: Qt.resolvedUrl("sounds/window-break-3.wav"); volume: 0.72 }
  RemoteSound { audio: root.audio; id: windowBreak4; source: Qt.resolvedUrl("sounds/window-break-4.wav"); volume: 0.72 }
  RemoteSound { audio: root.audio; id: windowBreak5; source: Qt.resolvedUrl("sounds/window-break-5.wav"); volume: 0.72 }
  RemoteSound { audio: root.audio; id: windowBreak6; source: Qt.resolvedUrl("sounds/window-break-6.wav"); volume: 0.72 }

  RemoteSound {
    audio: root.audio
    id: weaponReadySound
    source: Qt.resolvedUrl("sounds/weapon-ready.wav")
    volume: 0.34
  }

  RemoteSound {
    audio: root.audio
    id: weaponWheelHoverSound
    source: Qt.resolvedUrl("sounds/weapon-hover.wav")
    volume: 0.22
  }

  Timer {
    id: targetRespawnTimer
    interval: 700
    onTriggered: if (root.armed && root.targetsEnabled) root.spawnTarget()
  }

  // Projectiles retain the original 16 ms step and interpolated rendering.
  // The input-controlled weapon follows the pointer on each animation frame.
  property bool simulationAwake: false
  property real simulationAccumulator: 0
  property real simulationBlend: 1
  property var particleBuffer: []
  property real previousRecoil: 0
  property real previousFlash: 0
  readonly property real renderGunX: gunX
  readonly property real renderGunY: gunY
  readonly property real renderAimAngle: aimAngle
  readonly property real renderRecoil: simulationAwake ? previousRecoil + (recoil - previousRecoil) * simulationBlend : recoil
  readonly property real renderFlash: simulationAwake ? previousFlash + (flash - previousFlash) * simulationBlend : flash

  onPointerXChanged: wakeSimulation()
  onPointerYChanged: wakeSimulation()
  onArmedChanged: {
    if (armed) wakeSimulation()
    else simulationAwake = false
  }

  function wakeSimulation() {
    if (!armed || simulationAwake) return
    previousRecoil = recoil
    previousFlash = flash
    simulationAccumulator = 0
    simulationBlend = 1
    simulationAwake = true
  }

  function appendParticles(destination, additions) {
    for (var i = 0; i < additions.length; i++) destination.push(additions[i])
  }

  // The input-controlled weapon follows the latest pointer every animation
  // frame. Preserve the original 16 ms response without the extra historical
  // interpolation delay used for autonomous particles.
  function advanceWeapon(deltaSeconds) {
    var followBlend = 1 - Math.pow(0.84, deltaSeconds / 0.016)
    if (root.gunPositioned) {
      var dx = root.pointerX - root.gunX
      var dy = root.pointerY - root.gunY
      var distance = Math.sqrt(dx * dx + dy * dy)
      if (distance > 0.001) {
        var unitX = dx / distance
        var unitY = dy / distance
        var targetX = root.pointerX - unitX * root.followDistance
        var targetY = root.pointerY - unitY * root.followDistance
        root.gunX += (targetX - root.gunX) * followBlend
        root.gunY += (targetY - root.gunY) * followBlend
        root.aimAngle = Math.atan2(root.pointerY - root.gunY, root.pointerX - root.gunX) * 180 / Math.PI
        // Hysteresis prevents rapid mirror-state chatter near vertical aim.
        if (!root.aimFlipped && (root.aimAngle > 100 || root.aimAngle < -100)) root.aimFlipped = true
        else if (root.aimFlipped && root.aimAngle > -80 && root.aimAngle < 80) root.aimFlipped = false
      }
    }
  }

  function simulateStep() {
    if (roundFinished) return
    previousRecoil = recoil
    previousFlash = flash
    var hadParticleWork = root.particles.length > 0 || root.pendingEffects.length > 0
    root.recoil *= 0.72
    root.flash *= 0.56
    if (root.recoil < 0.05) root.recoil = 0
    if (root.flash < 0.02) root.flash = 0
    var next = particleBuffer
    next.length = 0
    for (var i = 0; i < root.particles.length; i++) {
      if (roundFinished) break
      var p = root.particles[i]
      p.previousX = p.x
      p.previousY = p.y
      p.previousLife = p.life
      p.previousAngle = p.angle
      if (p.kind === 6) {
        var previousX = p.x
        var previousY = p.y
        p.x += p.vx
        p.y += p.vy
        // At desktop distances the initial trajectory should read as flat.
        // Apply only a subtle drop after the first ricochet.
        if (p.bounces > 0) p.vy += 0.025
        p.vx *= 0.998
        p.vy *= 0.998

        if (!p.impacted) {
          var segmentX = p.x - previousX
          var segmentY = p.y - previousY
          var segmentLengthSquared = segmentX * segmentX + segmentY * segmentY
          var projection = segmentLengthSquared > 0
            ? ((p.impactX - previousX) * segmentX + (p.impactY - previousY) * segmentY) / segmentLengthSquared
            : 0
          projection = Math.max(0, Math.min(1, projection))
          var nearestX = previousX + segmentX * projection
          var nearestY = previousY + segmentY * projection
          var impactDx = p.impactX - nearestX
          var impactDy = p.impactY - nearestY
          if (impactDx * impactDx + impactDy * impactDy <= 100) {
            var impactSpeed = Math.max(0.001, Math.sqrt(p.vx * p.vx + p.vy * p.vy))
            root.carveRegion(p.impactRegionId, p.impactX, p.impactY, p.vx / impactSpeed, p.vy / impactSpeed, p.impactPower)
            p.impacted = true
            continue
          }
        }

        var bulletRadius = p.size * 1.5
        if (root.bugHuntEnabled && root.hitBug(previousX, previousY, p.x, p.y, bulletRadius, p.weapon)) continue
        if (root.projectileHitsTarget(p, bulletRadius)) {
          root.hitTarget()
          continue
        }
        var bounced = false
        if (p.x <= bulletRadius && p.vx < 0) {
          p.x = bulletRadius
          p.vx = -p.vx * 0.78
          bounced = true
        } else if (p.x >= window.width - bulletRadius && p.vx > 0) {
          p.x = window.width - bulletRadius
          p.vx = -p.vx * 0.78
          bounced = true
        }
        if (p.y <= bulletRadius && p.vy < 0) {
          p.y = bulletRadius
          p.vy = -p.vy * 0.72
          bounced = true
        } else if (p.y >= window.height - bulletRadius && p.vy > 0) {
          p.y = window.height - bulletRadius
          p.vy = -p.vy * 0.68
          p.vx *= 0.88
          bounced = true
        }
        if (bounced) {
          p.bounces += 1
          root.carveRicochetImpact(p.x, p.y, p.vx, p.vy, p.impactPower)
        }
        p.life -= 0.006 + p.bounces * 0.0015
        if (p.life > 0 && p.bounces < 7) next.push(p)
        continue
      }
      if (p.kind === 2) {
        p.x += p.vx
        p.y += p.vy
        p.vy += 0.45
        p.angle += p.spin

        var caseRadius = p.size
        if (p.x <= caseRadius && p.vx < 0) {
          p.x = caseRadius
          p.vx = -p.vx * 0.58
          p.spin *= -0.8
          p.bounces += 1
        } else if (p.x >= window.width - caseRadius && p.vx > 0) {
          p.x = window.width - caseRadius
          p.vx = -p.vx * 0.58
          p.spin *= -0.8
          p.bounces += 1
        }
        if (p.y <= caseRadius && p.vy < 0) {
          p.y = caseRadius
          p.vy = -p.vy * 0.5
          p.bounces += 1
        } else if (p.y >= window.height - caseRadius && p.vy > 0) {
          p.y = window.height - caseRadius
          p.vy = -p.vy * 0.46
          p.vx *= 0.72
          p.spin *= 0.7
          p.bounces += 1
        }
        p.vx *= 0.992
        p.life -= 0.018 + p.bounces * 0.002
        if (p.life > 0 && p.bounces < 8) next.push(p)
        continue
      }
      if (p.kind === 4) {
        p.life -= 0.025
        if (p.life > 0) next.push(p)
        continue
      }
      if (p.kind === 3) {
        var rocketPreviousX = p.x
        var rocketPreviousY = p.y
        p.x += p.vx
        p.y += p.vy
        p.age += 0.016
        var rocketRadius = Math.max(8, p.size * 2)

        if (!p.impacted) {
          var rocketSegmentX = p.x - rocketPreviousX
          var rocketSegmentY = p.y - rocketPreviousY
          var rocketSegmentLengthSquared = rocketSegmentX * rocketSegmentX + rocketSegmentY * rocketSegmentY
          var rocketProjection = rocketSegmentLengthSquared > 0
            ? ((p.impactX - rocketPreviousX) * rocketSegmentX + (p.impactY - rocketPreviousY) * rocketSegmentY) / rocketSegmentLengthSquared
            : 0
          rocketProjection = Math.max(0, Math.min(1, rocketProjection))
          var rocketNearestX = rocketPreviousX + rocketSegmentX * rocketProjection
          var rocketNearestY = rocketPreviousY + rocketSegmentY * rocketProjection
          var rocketImpactDx = p.impactX - rocketNearestX
          var rocketImpactDy = p.impactY - rocketNearestY
          if (rocketImpactDx * rocketImpactDx + rocketImpactDy * rocketImpactDy <= rocketRadius * rocketRadius) {
            p.x = p.impactX
            p.y = p.impactY
            var impactBoomScale = p.boomScale || 1
            var impactBlastRadius = 180 * impactBoomScale
            if (root.targetWithinBlast(p.x, p.y, impactBlastRadius)) root.hitTarget()
            root.playRocketExplosion(p)
            root.damageDesktop(p.x, p.y, Math.round(40 * impactBoomScale), "blast", 115 * impactBoomScale)
            appendParticles(next, root.rocketBlastParticles(p))
            p.impacted = true
            continue
          }
        }
        if ((root.bugHuntEnabled && root.hitBug(rocketPreviousX, rocketPreviousY, p.x, p.y, rocketRadius, p.weapon)) || root.projectileHitsTarget(p, rocketRadius)) {
          root.hitTarget()
          root.playRocketExplosion(p)
          root.damageDesktop(p.x, p.y, Math.round(40 * (p.boomScale || 1)), "blast", 115 * (p.boomScale || 1))
          appendParticles(next, root.rocketBlastParticles(p))
          continue
        }
        if (p.x <= rocketRadius && p.vx < 0) {
          p.x = rocketRadius
          p.vx = -p.vx * 0.84
        } else if (p.x >= window.width - rocketRadius && p.vx > 0) {
          p.x = window.width - rocketRadius
          p.vx = -p.vx * 0.84
        }
        if (p.y <= rocketRadius && p.vy < 0) {
          p.y = rocketRadius
          p.vy = -p.vy * 0.84
        } else if (p.y >= window.height - rocketRadius && p.vy > 0) {
          p.y = window.height - rocketRadius
          p.vy = -p.vy * 0.84
        }
        if (p.age >= p.explodeAt) {
          var boomScale = p.boomScale || 1
          var blastRadius = 180 * boomScale
          if (root.targetWithinBlast(p.x, p.y, blastRadius)) root.hitTarget()
          root.playRocketExplosion(p)
          root.damageDesktop(p.x, p.y, Math.round(40 * boomScale), "blast", 115 * boomScale)
          appendParticles(next, root.rocketBlastParticles(p))
        } else if (p.x > -80 && p.x < window.width + 80 && p.y > -80 && p.y < window.height + 80) next.push(p)
        continue
      }
      p.x += p.vx; p.y += p.vy
      p.vx *= 0.985; p.vy += 0.12
      p.life -= 0.035
      if (p.life > 0 && p.x > -80 && p.x < window.width + 80 && p.y > -80 && p.y < window.height + 80) next.push(p)
    }
    if (hadParticleWork) {
      for (var pendingIndex = 0; pendingIndex < root.pendingEffects.length; pendingIndex++)
        next.push(root.pendingEffects[pendingIndex])
      particleBuffer = root.particles
      root.particles = next
      root.pendingEffects = []
    }

  }

  FrameAnimation {
    id: simulation
    running: root.armed && root.simulationAwake && !root.roundFinished
    onTriggered: {
      // Bound catch-up after a suspended compositor; ordinary missed frames
      // still advance every physics step instead of slowing the simulation.
      var elapsed = Math.min(frameTime, 0.064)
      root.advanceWeapon(elapsed)
      root.advanceSaber(elapsed)
      // Fly Hunt hit-stop holds projectiles still for a moment after a kill.
      if (!(root.bugHuntEnabled && bugLayerLoader.item && bugLayerLoader.item.hitStop > 0)) root.simulationAccumulator += elapsed
      while (root.simulationAccumulator >= 0.016) {
        root.simulateStep()
        root.simulationAccumulator -= 0.016
      }
      root.simulationBlend = root.simulationAccumulator / 0.016
      var dx = root.pointerX - root.gunX
      var dy = root.pointerY - root.gunY
      var distance = Math.sqrt(dx * dx + dy * dy)
      var settled = !root.gunPositioned || distance <= 0.001 || Math.abs(distance - root.followDistance) < 0.01
      if (settled && !root.saberHeld && root.saberIgnition === 0 && root.saberTrail.length === 0 && root.saberHeat.length === 0 && !trickAnimation.running && root.particles.length === 0 && root.pendingEffects.length === 0 && root.recoil === 0 && root.flash === 0) {
        root.simulationAwake = false
        root.simulationBlend = 1
      }
      canvas.requestPaint()
    }
  }

  Timer {
    id: captureDelay
    // The drawer's layer surface needs several compositor frames to be fully
    // unmapped before screencopy. The transition hides this preparation time.
    interval: 220
    repeat: false
    onTriggered: {
      var screenName = root.targetScreen ? String(root.targetScreen.name || "") : ""
      captureProcess.exec(['/usr/bin/python3', '-I', '-S',
        decodeURIComponent(Qt.resolvedUrl('capture_worker.py').toString().replace(/^file:\/\//, '')),
        screenName])
    }
  }

  DesktopProcess {
    id: captureProcess
    stdinEnabled: true
    stdout: SplitParser {
      onRead: function(line) {
        if (!root.captureInProgress) return
        try {
          var message = JSON.parse(line)
          if (typeof message.url === 'string' && message.url.indexOf('file:///') === 0)
            root.desktopSnapshot = message.url
          else root.abortCapture("Invalid desktop snapshot response")
        } catch (error) { root.abortCapture("Invalid desktop snapshot response") }
      }
    }
    onExited: function(exitCode, exitStatus) {
      if (root.captureInProgress) root.abortCapture("Desktop capture failed")
    }
  }

  DesktopProcess {
    id: clientQueryProcess
    stdout: StdioCollector {
      id: clientQueryOutput
      waitForEnd: true
    }
    onExited: function(exitCode, exitStatus) {
      root.clientGeometryJson = exitCode === 0 ? clientQueryOutput.text : "[]"
      root.clientGeometryReady = true
      root.tryFinishCapture()
    }
  }

  DesktopProcess {
    id: workspaceQueryProcess
    stdout: StdioCollector {
      id: workspaceQueryOutput
      waitForEnd: true
    }
    onExited: function(exitCode, exitStatus) {
      try {
        var monitors = exitCode === 0 ? JSON.parse(workspaceQueryOutput.text) : []
        var targetName = root.targetScreen ? String(root.targetScreen.name || "") : ""
        var monitor = null
        for (var i = 0; i < monitors.length; i++) {
          if (String(monitors[i].name || "") === targetName) {
            monitor = monitors[i]
            break
          }
        }
        if (!monitor && monitors.length === 1) monitor = monitors[0]
        root.activeWorkspaceId = monitor && monitor.activeWorkspace
          ? Number(monitor.activeWorkspace.id) : -1
        root.captureOffsetX = monitor ? Number(monitor.x || 0) : 0
        root.captureOffsetY = monitor ? Number(monitor.y || 0) : 0
      } catch (error) {
        root.activeWorkspaceId = -1
        root.captureOffsetX = 0
        root.captureOffsetY = 0
      }
      root.activeWorkspaceReady = true
      root.tryFinishCapture()
    }
  }

  DesktopProcess {
    id: wallpaperQueryProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.wallpaperSource = Util.fileUrl(String(text || "").trim())
    }
  }

  ListModel { id: fallingPieces }
  ListModel { id: destroyedRegions }
}
