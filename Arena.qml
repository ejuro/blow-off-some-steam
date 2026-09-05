import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtMultimedia
import qs.Commons

Item {
  id: root
  property bool armed: false
  property bool destructionEnabled: false
  property var targetScreen: null
  property bool captureInProgress: false
  property string pendingWeapon: ""
  property string capturePath: ""
  property int captureSerial: 0
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
    case "revolver": return { name: "Colt 45", image: "assets/revolver-colt45.png", width: 64, height: 32, scale: 2.2, gripX: 20, gripY: 25, muzzleX: 47, muzzleY: 12.5, automatic: false, interval: 280, recoil: 19, particles: 25, power: 1.25, ejectsCase: false, flashStyle: "revolver" }
    case "ak47": return { name: "AK-47", image: "assets/ak47.png", width: 96, height: 48, scale: 2, gripX: 35, gripY: 33, muzzleX: 79, muzzleY: 9.5, ejectX: 45, ejectY: 12, automatic: true, interval: 82, recoil: 10, particles: 7, power: 1 }
    case "mp5a3": return { name: "MP5A3", image: "assets/mp5a3.png", width: 80, height: 48, scale: 2.1, gripX: 33, gripY: 33, muzzleX: 60, muzzleY: 7.5, ejectX: 31, ejectY: 8, automatic: true, interval: 66, recoil: 7, particles: 6, power: 0.9 }
    case "bazooka": return { name: "M20 Bazooka", image: "assets/bazooka-m20.png", width: 128, height: 32, scale: 2, gripX: 46, gripY: 24, muzzleX: 115, muzzleY: 12.5, automatic: false, interval: 500, recoil: 28, particles: 42, power: 1.8 }
    case "thick-bazooka": return { name: "Thick M20", image: "assets/bazooka-m20-thick.png", width: 192, height: 32, scale: 1.65, gripX: 66, gripY: 24, muzzleX: 147, muzzleY: 10.5, automatic: false, interval: 550, recoil: 32, particles: 52, power: 2.1 }
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
  readonly property var weaponOptions: [
    { id: "glock", name: "GLOCK", image: "assets/glock-p80.png", clip: Qt.rect(18, 8, 30, 20) },
    { id: "revolver", name: "COLT", image: "assets/revolver-colt45.png", clip: Qt.rect(2, 11, 45, 18) },
    { id: "ak47", name: "AK-47", image: "assets/ak47.png", clip: Qt.rect(3, 5, 76, 22) },
    { id: "mp5a3", name: "MP5", image: "assets/mp5a3.png", clip: Qt.rect(3, 3, 57, 27) },
    { id: "bazooka", name: "M20", image: "assets/bazooka-m20.png", clip: Qt.rect(3, 7, 112, 24) },
    { id: "thick-bazooka", name: "THICK", image: "assets/bazooka-m20-thick.png", clip: Qt.rect(35, 3, 112, 28) }
  ]

  function openWeaponWheel(x, y) {
    var extent = 170
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
      nextSelection = Math.round(((degrees + 90 + 360) % 360) / 60) % 6
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
    targetRespawnTimer.restart()
  }
  function setTargetsEnabled(enabled) {
    targetsEnabled = enabled
    if (enabled) destructionEnabled = false
    targetRespawnTimer.stop()
    targetVisible = false
    canvas.requestPaint()
    if (targetsEnabled && armed) spawnTarget()
  }
  function setDestructionEnabled(enabled) {
    destructionEnabled = enabled
    if (enabled) setTargetsEnabled(false)
  }

  function arm(id) {
    if (armed) {
      swapWeapon(id)
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
    clientQueryProcess.exec(["hyprctl", "clients", "-j"])
    workspaceQueryProcess.exec(["hyprctl", "monitors", "-j"])
    wallpaperQueryProcess.exec(["readlink", "-f", Quickshell.env("HOME") + "/.local/state/omarchy/current/background"])
    captureDelay.restart()
  }
  function swapWeapon(id) {
    weaponWheelOpen = false
    weaponWheelSelection = -1
    automaticHoldEngaged = false
    automaticHoldTimer.stop()
    fireTimer.stop()
    automaticSound.stop()
    mp5AutomaticSound.stop()
    recoil = 0
    flash = 0
    weapon = id
    weaponReadySound.stop()
    weaponReadySound.play()
    canvas.requestPaint()
    // Deliberately preserve gunX/gunY, aimAngle, aimFlipped, particles,
    // targets, and destruction state during an in-arena wheel swap.
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }
  function equip(id, animateActivation) {
    weaponWheelOpen = false
    weaponWheelSelection = -1
    weapon = id
    activationShadeAnimation.stop()
    activationShade = animateActivation ? 1 : 0
    weaponReadySound.stop()
    weaponReadySound.play()
    armed = true
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
    var failedCapturePath = capturePath
    desktopSnapshot = ""
    capturePath = ""
    destructibles = []
    // Never cover the real workspace with the wallpaper fallback when a
    // screencopy cannot be decoded. Keep the selected weapon usable in the
    // ordinary transparent-overlay mode and make the checkbox reflect that.
    setDestructionEnabled(false)
    console.warn("Desktop destruction disabled: " + message)
    equip(id, false)
    if (failedCapturePath.indexOf("/tmp/blow-off-some-steam-") === 0)
      captureCleanupProcess.exec(["rm", "-f", failedCapturePath])
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
      if (region.destroyed || x < region.x || x > region.x + region.width || y < region.y || y > region.y + region.height) continue
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
      var minX = region.x
      var maxX = region.x + region.width
      var minY = region.y
      var maxY = region.y + region.height
      var inside = originX >= minX && originX <= maxX && originY >= minY && originY <= maxY
      // The weapon is visually floating above the captured desktop. Do not
      // let the window underneath it catch the bullet on the way out.
      if (inside && !includeContainingRegion) continue
      var nearX = -Infinity
      var farX = Infinity
      var nearY = -Infinity
      var farY = Infinity
      if (Math.abs(directionX) < 0.0001) {
        if (originX < minX || originX > maxX) continue
      } else {
        var tx1 = (minX - originX) / directionX
        var tx2 = (maxX - originX) / directionX
        nearX = Math.min(tx1, tx2)
        farX = Math.max(tx1, tx2)
      }
      if (Math.abs(directionY) < 0.0001) {
        if (originY < minY || originY > maxY) continue
      } else {
        var ty1 = (minY - originY) / directionY
        var ty2 = (maxY - originY) / directionY
        nearY = Math.min(ty1, ty2)
        farY = Math.max(ty1, ty2)
      }
      var entry = Math.max(nearX, nearY)
      var exit = Math.min(farX, farY)
      if (entry > exit || exit <= 4) continue
      var distance = Math.max(entry, 4.01)
      if (nearest && distance >= nearest.distance) continue

      // The rectangle only bounds the captured window. Its carved circles are
      // empty space, so let this shot travel through them until it reaches the
      // next intact pixel. Shooting the same line repeatedly therefore digs a
      // progressively deeper tunnel instead of re-hitting the original edge.
      while (distance <= exit) {
        var carvedExit = carvedExitDistance(region.id,
                                            originX + directionX * distance,
                                            originY + directionY * distance,
                                            directionX, directionY, distance)
        if (carvedExit < 0) break
        distance = Math.max(distance + 1, carvedExit + 0.5)
      }
      if (distance > exit || (nearest && distance >= nearest.distance)) continue
      nearest = {
        regionId: region.id,
        x: originX + directionX * distance,
        y: originY + directionY * distance,
        distance: distance
      }
    }
    return nearest
  }
  function destroyRegion(region) {
    region.destroyed = true
    playWindowBreak()
    destroyedRegions.append({
      patchX: region.x, patchY: region.y,
      patchWidth: region.width, patchHeight: region.height
    })
    fallingPieces.append({
      pieceToken: ++fallingSerial,
      pieceRegionId: region.id,
      pieceX: region.x, pieceY: region.y,
      pieceWidth: region.width, pieceHeight: region.height,
      direction: Math.random() < 0.5 ? -1 : 1,
      fallDuration: 850 + Math.random() * 450
    })
  }
  function removeFallingPiece(token) {
    for (var i = 0; i < fallingPieces.count; i++) {
      if (fallingPieces.get(i).pieceToken === token) {
        var regionId = fallingPieces.get(i).pieceRegionId
        fallingPieces.remove(i)
        pruneRegionMarks(regionId)
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
    var oldCapturePath = capturePath
    armed = false
    captureInProgress = false
    pendingWeapon = ""
    captureDelay.stop()
    if (captureProcess.running) captureProcess.running = false
    if (capturePermissionProcess.running) capturePermissionProcess.running = false
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
    capturePath = ""
    if (oldCapturePath.indexOf("/tmp/blow-off-some-steam-") === 0)
      captureCleanupProcess.exec(["rm", "-f", oldCapturePath])
  }
  function playWeaponSound() {
    if (weapon === "mp5a3") mp5SingleSound.play()
    else if (spec.automatic) akSingleSound.play()
    else if (weapon === "revolver") revolverSound.play()
    else if (weapon === "bazooka" || weapon === "thick-bazooka") {
      bazookaLaunchSound.volume = weapon === "thick-bazooka" ? 1.0 : 0.72
      bazookaLaunchSound.play()
    }
    else pistolSound.play()
  }
  function shoot(withSound) {
    if (!armed) return
    if (withSound === undefined || withSound) playWeaponSound()
    recoil = spec.recoil
    flash = 1
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
    if (weapon === "bazooka" || weapon === "thick-bazooka") {
      var rocketImpact = firstDesktopImpact(muzzleX, muzzleY, cosA, sinA)
      next.push({
        x: muzzleX, y: muzzleY, vx: 6 * power * cosA, vy: 6 * power * sinA,
        life: 1, age: 0, explodeAt: 1.52, size: 5 * power,
        boomScale: weapon === "thick-bazooka" ? 2.5 : 1, kind: 3,
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
        life: 1, size: 3.6 + power * 0.6, bounces: 0, kind: 6,
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
    if (spec.ejectsCase !== false && weapon !== "bazooka" && weapon !== "thick-bazooka") {
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
      visible: root.destructionEnabled && root.armed && root.desktopSnapshot !== ""
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
      color: "#15171b"
      visible: root.destructionEnabled && root.armed && root.desktopSnapshot === ""
    }

    Loader {
      id: terrainCanvasLoader
      anchors.fill: parent
      // Instantiate only once the layer is visible. Loading this threaded
      // Canvas while hidden can lose its first paint, leaving the intact
      // snapshot bridge visible underneath every transparent damage mark.
      active: root.destructionEnabled && root.armed && root.desktopSnapshot !== ""
      visible: active
      sourceComponent: Canvas {
        renderStrategy: Canvas.Threaded
        function applyDamage(dirtyArea) {
          markDirty(dirtyArea)
        }
        Component.onCompleted: {
          var source = String(root.desktopSnapshot)
          if (source) loadImage(source)
        }
        onImageLoaded: requestPaint()
        onPaint: {
          // The Loader is recreated for every captured frame. Never publish a
          // hidden threaded backing store as ready for the visible overlay.
          if (!root.armed) return
          var c = getContext("2d")
          var source = String(root.desktopSnapshot)
          if (!source || !isImageLoaded(source)) return
          if (root.terrainNeedsReset) {
            c.globalCompositeOperation = "source-over"
            c.clearRect(0, 0, width, height)
            c.drawImage(source, 0, 0, width, height)
            root.paintedCarveCount = 0
            root.terrainNeedsReset = false
          }
          c.globalCompositeOperation = "destination-out"
          for (var i = root.paintedCarveCount; i < root.carveMarks.length; i++) {
            var mark = root.carveMarks[i]
            c.save()
            c.beginPath()
            c.rect(mark.clipX, mark.clipY, mark.clipWidth, mark.clipHeight)
            c.clip()
            c.beginPath()
            c.arc(mark.x, mark.y, mark.radius, 0, Math.PI * 2)
            c.fill()
            c.restore()
          }
          root.paintedCarveCount = root.carveMarks.length
          c.globalCompositeOperation = "source-over"
          root.terrainReady = true
        }
      }
    }

    Repeater {
      model: destroyedRegions
      visible: root.destructionEnabled
      delegate: Item {
        required property real patchX
        required property real patchY
        required property real patchWidth
        required property real patchHeight
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
        required property int pieceToken
        required property string pieceRegionId
        required property real pieceX
        required property real pieceY
        required property real pieceWidth
        required property real pieceHeight
        required property real direction
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
            c.globalCompositeOperation = "source-over"
            c.clearRect(0, 0, width, height)
            c.drawImage(source,
                        fallingPiece.pieceX, fallingPiece.pieceY,
                        fallingPiece.pieceWidth, fallingPiece.pieceHeight,
                        0, 0, width, height)

            // Reapply this object's accumulated destruction to its private
            // texture so the holes travel and rotate with the falling piece.
            c.globalCompositeOperation = "destination-out"
            var pieceMarks = root.regionCarveMarks[fallingPiece.pieceRegionId] || []
            for (var i = 0; i < pieceMarks.length; i++) {
              var mark = pieceMarks[i]
              c.beginPath()
              c.arc(mark.x - fallingPiece.pieceX,
                    mark.y - fallingPiece.pieceY,
                    mark.radius, 0, Math.PI * 2)
              c.fill()
            }
            c.globalCompositeOperation = "source-over"
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
          to: fallingPiece.direction * 12
          duration: fallingPiece.fallDuration
          running: true
        }
      }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          if (root.weaponWheelOpen) {
            root.closeWeaponWheel(false)
            root.keyboardWeaponWheel = false
          } else root.holster()
          event.accepted = true
          return
        }
        if (event.key === Qt.Key_Q && !event.isAutoRepeat) {
          if (!root.weaponWheelOpen) {
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
          } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_6) {
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

    Canvas {
      id: canvas
      anchors.fill: parent
      z: 20
      renderStrategy: Canvas.Threaded
      onPaint: {
        var c = getContext("2d")
        c.clearRect(0, 0, width, height)
        c.globalAlpha = 1

        if (root.armed && root.targetVisible) {
          c.fillStyle = "#eee9df"
          c.beginPath(); c.arc(root.targetX, root.targetY, root.targetRadius, 0, Math.PI * 2); c.fill()
          c.fillStyle = "#c92f35"
          c.beginPath(); c.arc(root.targetX, root.targetY, root.targetRadius * 0.72, 0, Math.PI * 2); c.fill()
          c.fillStyle = "#eee9df"
          c.beginPath(); c.arc(root.targetX, root.targetY, root.targetRadius * 0.43, 0, Math.PI * 2); c.fill()
          c.fillStyle = "#c92f35"
          c.beginPath(); c.arc(root.targetX, root.targetY, root.targetRadius * 0.18, 0, Math.PI * 2); c.fill()
        }

        for (var i = 0; i < root.particles.length; i++) {
          var p = root.particles[i]
          c.globalAlpha = Math.max(0, p.life)
          if (p.kind === 1) {
            c.fillStyle = i % 3 === 0 ? "#ff4d2e" : (i % 2 === 0 ? "#ffd24a" : "#ff8a2a")
            c.beginPath(); c.arc(p.x, p.y, p.size * p.life, 0, Math.PI * 2); c.fill()
          } else if (p.kind === 3) {
            var rocketAngle = Math.atan2(p.vy, p.vx)
            c.save()
            c.translate(p.x, p.y)
            c.rotate(rocketAngle)
            c.fillStyle = "#ffb52e"
            c.beginPath(); c.moveTo(-22, 0); c.lineTo(-34, -7); c.lineTo(-30, 0); c.lineTo(-34, 7); c.closePath(); c.fill()
            c.fillStyle = "#d7d9d2"
            c.fillRect(-18, -3, 25, 6)
            c.fillStyle = "#79806f"
            c.beginPath(); c.moveTo(12, 0); c.lineTo(5, -5); c.lineTo(5, 5); c.closePath(); c.fill()
            c.restore()
          } else if (p.kind === 4) {
            c.globalAlpha = Math.max(0, p.life) * 0.85
            c.strokeStyle = p.life > 0.55 ? "#fff4ad" : "#ff6a2b"
            c.lineWidth = Math.max(2, 14 * p.life)
            c.beginPath(); c.arc(p.x, p.y, p.maxRadius * (1 - p.life), 0, Math.PI * 2); c.stroke()
          } else if (p.kind === 5) {
            c.fillStyle = "#8fd8d5cc"
            c.beginPath(); c.arc(p.x, p.y, p.size * (1.3 - p.life), 0, Math.PI * 2); c.fill()
          } else if (p.kind === 6) {
            var bulletAngle = Math.atan2(p.vy, p.vx)
            c.save()
            c.translate(p.x, p.y)
            c.rotate(bulletAngle)
            c.fillStyle = "#efe0a4"
            c.fillRect(-p.size * 1.8, -p.size * 0.52, p.size * 2.3, p.size * 1.04)
            c.fillStyle = "#bf7b2d"
            c.beginPath()
            c.moveTo(p.size * 1.45, 0)
            c.lineTo(p.size * 0.45, -p.size * 0.52)
            c.lineTo(p.size * 0.45, p.size * 0.52)
            c.closePath()
            c.fill()
            c.restore()
          } else if (p.kind === 7) {
            c.fillStyle = "#9da2a0"
            c.beginPath(); c.arc(p.x, p.y, p.size * (1.35 - p.life * 0.35), 0, Math.PI * 2); c.fill()
          } else if (p.kind === 2) {
            c.fillStyle = "#d6a84b"
            c.save()
            c.translate(p.x, p.y)
            c.rotate(p.angle)
            c.fillRect(-p.size * 0.9, -p.size * 0.5, p.size * 1.8, p.size)
            c.restore()
          }
        }

        c.globalAlpha = root.armed ? 0.22 : 0
        c.fillStyle = "#000000"
        c.beginPath(); c.ellipse(root.gunX, root.gunY + 45, root.spec.width * root.spec.scale * 0.32, 8, 0, 0, Math.PI * 2); c.fill()
        c.globalAlpha = 1

        if (root.flash > 0) {
          var angle = root.aimAngle * Math.PI / 180
          var cosA = Math.cos(angle)
          var sinA = Math.sin(angle)
          var localX = (root.spec.muzzleX - root.spec.gripX) * root.spec.scale
          var localY = (root.spec.muzzleY - root.spec.gripY) * root.spec.scale * (root.aimFlipped ? -1 : 1)
          var mx = root.gunX - root.recoil * cosA + localX * cosA - localY * sinA
          var my = root.gunY - root.recoil * sinA + localX * sinA + localY * cosA
          c.globalAlpha = root.flash
          c.save()
          c.translate(mx, my)
          c.rotate(angle)
          if (root.spec.flashStyle === "revolver") {
            c.fillStyle = "#fff2a0"
            c.beginPath()
            c.moveTo(-5, 0); c.lineTo(9, -7); c.lineTo(13, -20); c.lineTo(19, -8)
            c.lineTo(38, -13); c.lineTo(27, 0); c.lineTo(39, 13); c.lineTo(18, 8)
            c.lineTo(12, 21); c.lineTo(8, 7); c.closePath(); c.fill()
            c.globalAlpha = root.flash * 0.8
            c.fillStyle = "#ff762b"
            c.beginPath(); c.moveTo(0, 0); c.lineTo(27, -6); c.lineTo(20, 0); c.lineTo(28, 6); c.closePath(); c.fill()
          } else {
            c.fillStyle = "#ffe86b"
            c.beginPath(); c.moveTo(0,0); c.lineTo(29,-10); c.lineTo(20,0); c.lineTo(33,9); c.closePath(); c.fill()
          }
          c.restore()
        }
      }
    }

    Image {
      visible: root.armed
      z: 30
      x: root.gunX - root.spec.gripX * root.spec.scale - root.recoil * Math.cos(root.aimAngle * Math.PI / 180)
      y: root.gunY - root.spec.gripY * root.spec.scale - root.recoil * Math.sin(root.aimAngle * Math.PI / 180)
      width: root.spec.width * root.spec.scale
      height: root.spec.height * root.spec.scale
      source: Qt.resolvedUrl(root.spec.image)
      fillMode: Image.PreserveAspectFit
      smooth: false
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
          angle: root.aimAngle
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
          readonly property real tileAngle: (-90 + index * 60) * Math.PI / 180
          width: 94
          height: 82
          x: root.weaponWheelX + Math.cos(tileAngle) * 116 - width / 2
          y: root.weaponWheelY + Math.sin(tileAngle) * 116 - height / 2

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
                : "#292d38"
              c.fill()
              c.strokeStyle = root.weaponWheelSelection === wheelTile.index ? root.accent : "#75809a"
              c.lineWidth = root.weaponWheelSelection === wheelTile.index ? 3 : 2
              c.stroke()
            }
            Component.onCompleted: requestPaint()
            Connections {
              target: root
              function onWeaponWheelSelectionChanged() { hex.requestPaint() }
              function onAccentChanged() { hex.requestPaint() }
            }
          }

          Image {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 14
            width: Math.min(64, wheelTile.modelData.clip.width * 1.15)
            height: 30
            source: Qt.resolvedUrl(wheelTile.modelData.image)
            sourceClipRect: wheelTile.modelData.clip
            fillMode: Image.PreserveAspectFit
            smooth: false
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 52
            text: wheelTile.modelData.name
            color: root.weaponWheelSelection === wheelTile.index ? "#ffffff" : "#d4d8e3"
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
        color: "#d91b1e26"
        border.width: 2
        border.color: "#75809a"
        Text {
          anchors.centerIn: parent
          text: "󰜃"
          color: "#d4d8e3"
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
        root.pointerX = event.x
        root.pointerY = event.y
        if (event.button === Qt.MiddleButton) {
          root.keyboardWeaponWheel = false
          root.openWeaponWheel(event.x, event.y)
          return
        }
        if (event.button === Qt.RightButton) {
          weaponSpinSound.stop()
          weaponSpinSound.play()
          trickAnimation.restart()
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
        var pendingSingleShot = root.spec.automatic && !root.automaticHoldEngaged && automaticHoldTimer.running
        automaticHoldTimer.stop()
        fireTimer.stop()
        automaticSound.stop()
        mp5AutomaticSound.stop()
        if (pendingSingleShot) root.shoot()
      }
      onCanceled: {
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
      radius: 8
      color: "#b3151719"
      Text {
        id: hint
        anchors.centerIn: parent
        text: root.weaponName + (root.spec.automatic ? " · click/hold to fire" : " · click to fire") + " · middle/Q-hold weapon wheel · right-click spin · Esc holster"
        color: "#d9ffffff"
        font.pixelSize: 12
      }
    }

    // A brief cinematic veil makes the change from the live compositor to
    // its frozen game frame read as an intentional transition.
    Rectangle {
      anchors.fill: parent
      z: 29
      color: "#111419"
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
    id: fireTimer
    interval: root.spec.interval
    repeat: true
    onTriggered: root.shoot(false)
  }

  SoundEffect {
    id: pistolSound
    source: Qt.resolvedUrl("sounds/pistol-shot.wav")
    volume: 0.62
  }

  SoundEffect {
    id: akSingleSound
    source: Qt.resolvedUrl("sounds/ak-single-shot.wav")
    volume: 0.56
  }

  SoundEffect {
    id: mp5SingleSound
    source: Qt.resolvedUrl("sounds/mp5-single-shot.wav")
    volume: 0.56
  }

  SoundEffect {
    id: mp5AutomaticSound
    source: Qt.resolvedUrl("sounds/mp5-automatic-fire.wav")
    loops: SoundEffect.Infinite
    volume: 0.5
  }

  SoundEffect {
    id: automaticSound
    source: Qt.resolvedUrl("sounds/automatic-fire.wav")
    loops: SoundEffect.Infinite
    volume: 0.48
  }

  SoundEffect {
    id: revolverSound
    source: Qt.resolvedUrl("sounds/revolver-shot.wav")
    volume: 0.66
  }

  SoundEffect {
    id: bazookaLaunchSound
    source: Qt.resolvedUrl("sounds/bazooka-launch.wav")
    volume: 0.72
  }

  SoundEffect {
    id: rocketExplosionSound
    source: Qt.resolvedUrl("sounds/bazooka-explosion.wav")
    volume: 0.76
  }

  SoundEffect {
    id: targetHitSound
    source: Qt.resolvedUrl("sounds/target-hit.wav")
    volume: 0.34
  }

  SoundEffect {
    id: weaponSpinSound
    source: Qt.resolvedUrl("sounds/weapon-spin.wav")
    volume: 0.30
  }

  SoundEffect { id: windowBreak1; source: Qt.resolvedUrl("sounds/window-break-1.wav"); volume: 0.72 }
  SoundEffect { id: windowBreak2; source: Qt.resolvedUrl("sounds/window-break-2.wav"); volume: 0.72 }
  SoundEffect { id: windowBreak3; source: Qt.resolvedUrl("sounds/window-break-3.wav"); volume: 0.72 }
  SoundEffect { id: windowBreak4; source: Qt.resolvedUrl("sounds/window-break-4.wav"); volume: 0.72 }
  SoundEffect { id: windowBreak5; source: Qt.resolvedUrl("sounds/window-break-5.wav"); volume: 0.72 }
  SoundEffect { id: windowBreak6; source: Qt.resolvedUrl("sounds/window-break-6.wav"); volume: 0.72 }

  SoundEffect {
    id: weaponReadySound
    source: Qt.resolvedUrl("sounds/weapon-ready.wav")
    volume: 0.34
  }

  SoundEffect {
    id: weaponWheelHoverSound
    source: Qt.resolvedUrl("sounds/weapon-hover.wav")
    volume: 0.22
  }

  Timer {
    id: targetRespawnTimer
    interval: 700
    onTriggered: if (root.armed && root.targetsEnabled) root.spawnTarget()
  }

  Timer {
    interval: 16
    running: root.armed
    repeat: true
    onTriggered: {
      var oldGunX = root.gunX
      var oldGunY = root.gunY
      var oldRecoil = root.recoil
      var oldFlash = root.flash
      var hadParticleWork = root.particles.length > 0 || root.pendingEffects.length > 0
      if (root.gunPositioned) {
        var dx = root.pointerX - root.gunX
        var dy = root.pointerY - root.gunY
        var distance = Math.sqrt(dx * dx + dy * dy)
        if (distance > 0.001) {
          var unitX = dx / distance
          var unitY = dy / distance
          var targetX = root.pointerX - unitX * root.followDistance
          var targetY = root.pointerY - unitY * root.followDistance
          root.gunX += (targetX - root.gunX) * 0.16
          root.gunY += (targetY - root.gunY) * 0.16
          root.aimAngle = Math.atan2(root.pointerY - root.gunY, root.pointerX - root.gunX) * 180 / Math.PI
          // Hysteresis prevents rapid mirror-state chatter near vertical aim.
          if (!root.aimFlipped && (root.aimAngle > 100 || root.aimAngle < -100)) root.aimFlipped = true
          else if (root.aimFlipped && root.aimAngle > -80 && root.aimAngle < 80) root.aimFlipped = false
        }
      }
      root.recoil *= 0.72
      root.flash *= 0.56
      if (root.recoil < 0.05) root.recoil = 0
      if (root.flash < 0.02) root.flash = 0
      var next = []
      for (var i = 0; i < root.particles.length; i++) {
        var p = root.particles[i]
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
              next = next.concat(root.rocketBlastParticles(p))
              p.impacted = true
              continue
            }
          }
          if (root.projectileHitsTarget(p, rocketRadius)) {
            root.hitTarget()
            root.playRocketExplosion(p)
            root.damageDesktop(p.x, p.y, Math.round(40 * (p.boomScale || 1)), "blast", 115 * (p.boomScale || 1))
            next = next.concat(root.rocketBlastParticles(p))
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
            next = next.concat(root.rocketBlastParticles(p))
          } else if (p.x > -80 && p.x < window.width + 80 && p.y > -80 && p.y < window.height + 80) next.push(p)
          continue
        }
        p.x += p.vx; p.y += p.vy
        p.vx *= 0.985; p.vy += 0.12
        p.life -= 0.035
        if (p.life > 0 && p.x > -80 && p.x < window.width + 80 && p.y > -80 && p.y < window.height + 80) next.push(p)
      }
      if (hadParticleWork) {
        root.particles = next.concat(root.pendingEffects)
        root.pendingEffects = []
      }
      var gunMoved = Math.abs(root.gunX - oldGunX) > 0.01 || Math.abs(root.gunY - oldGunY) > 0.01
      if (hadParticleWork || gunMoved || oldRecoil > 0 || oldFlash > 0)
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
      var safeName = screenName.replace(/[^A-Za-z0-9_.-]/g, "_") || "default"
      root.captureSerial += 1
      // A unique URL is essential: Canvas.loadImage caches by URL even when
      // the file at that path has been replaced on another workspace.
      root.capturePath = "/tmp/blow-off-some-steam-" + safeName + "-" + root.captureSerial + "-" + Date.now() + ".ppm"
      var command = ["grim"]
      if (screenName !== "") command.push("-o", screenName)
      // PPM avoids the expensive full-resolution PNG compression/decode path.
      // The file lives only in /tmp and is never user-facing.
      command.push("-s", "1", "-t", "ppm")
      command.push(root.capturePath)
      captureProcess.exec(command)
    }
  }

  Process {
    id: captureProcess
    onExited: function(exitCode, exitStatus) {
      if (!root.captureInProgress) return
      if (exitCode === 0) {
        capturePermissionProcess.exec(["chmod", "600", root.capturePath])
      } else {
        root.abortCapture("Desktop capture failed")
      }
    }
  }

  Process {
    id: capturePermissionProcess
    onExited: function(exitCode, exitStatus) {
      if (!root.captureInProgress) return
      if (exitCode === 0)
        root.desktopSnapshot = "file://" + root.capturePath
      else
        root.abortCapture("Could not secure the desktop snapshot")
    }
  }

  Process { id: captureCleanupProcess }

  Process {
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

  Process {
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

  Process {
    id: wallpaperQueryProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.wallpaperSource = Util.fileUrl(String(text || "").trim())
    }
  }

  ListModel { id: fallingPieces }
  ListModel { id: destroyedRegions }
}
