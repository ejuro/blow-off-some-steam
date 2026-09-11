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
    // damageScale is enemy damage only; `power` drives hole size, spread and
    // recoil, so the hand cannon hits hard without carving three times wider.
    case "revolver": return { name: "Colt 45", image: "assets/revolver-colt45.png", width: 64, height: 32, scale: 2.2, gripX: 20, gripY: 25, muzzleX: 47, muzzleY: 12.5, automatic: false, interval: 280, recoil: 19, particles: 25, power: 1.25, damageScale: 3, ejectsCase: false, flashStyle: "revolver" }
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
  property bool clownSiegeEnabled: false
  property var clowns: []
  property int clownSerial: 0
  property int baseHealth: 100
  property int score: 0
  property int clownsDefeated: 0
  property bool bossPending: false
  property int bossQuoteIndex: 0
  property int omaCoins: 0
  property int magTier: 0
  property int waveIndex: 0
  property int waveSpawned: 0
  property bool waveResting: false
  property bool siegeWon: false
  property var powerups: []
  property int powerupSerial: 0
  property var spawnQueue: []
  property var pendingPowerups: []
  property real damageBoostUntil: 0
  property real slowUntil: 0
  property int siegeClock: 0
  property real baseRadius: 26
  readonly property int airdropCost: 15
  readonly property int powerupCap: 8
  readonly property int baseHealthCap: 160
  readonly property int reinforceCost: 10
  readonly property int extendedMagCost: 30
  // Capped so reloading stays part of the mode; without a ceiling a few
  // purchases would retire the mechanic entirely.
  readonly property int magTierCap: 3
  // Wave pacing trim: every speed below is written at its original value and
  // scaled here, so the types keep their relative feel. Screen and wave
  // multipliers compose on top at spawn time.
  readonly property real enemySpeedScale: 0.95
  // Five waves, then the bar is yours. mix is weighted, not cumulative.
  readonly property var wavePlan: [
    { count: 8,  interval: 1800, hp: 1.00, speed: 1.00, boss: false, mix: [
      { type: "clown", w: 70 }, { type: "runner", w: 22 }, { type: "bomber", w: 8 }
    ]},
    { count: 10, interval: 1550, hp: 1.08, speed: 1.04, boss: false, mix: [
      { type: "clown", w: 40 }, { type: "runner", w: 28 }, { type: "bomber", w: 16 }, { type: "splitter", w: 16 }
    ]},
    { count: 12, interval: 1350, hp: 1.16, speed: 1.08, boss: true, mix: [
      { type: "clown", w: 22 }, { type: "runner", w: 18 }, { type: "bruiser", w: 14 }, { type: "robot", w: 10 },
      { type: "medic", w: 14 }, { type: "bomber", w: 12 }, { type: "splitter", w: 10 }
    ]},
    { count: 14, interval: 1150, hp: 1.24, speed: 1.12, boss: false, mix: [
      { type: "clown", w: 14 }, { type: "runner", w: 14 }, { type: "bruiser", w: 12 }, { type: "robot", w: 12 },
      { type: "medic", w: 12 }, { type: "bomber", w: 12 }, { type: "splitter", w: 12 }, { type: "blinker", w: 12 }
    ]},
    { count: 16, interval: 950, hp: 1.35, speed: 1.18, boss: true, last: true, mix: [
      { type: "clown", w: 10 }, { type: "runner", w: 12 }, { type: "bruiser", w: 12 }, { type: "robot", w: 14 },
      { type: "medic", w: 10 }, { type: "bomber", w: 14 }, { type: "splitter", w: 14 }, { type: "blinker", w: 14 }
    ]}
  ]
  readonly property var enemySpriteFiles: ({
    "clown": "assets/enemies/clown.png",
    "runner": "assets/enemies/runner.png",
    "bruiser": "assets/enemies/bruiser.png",
    "robot": "assets/enemies/robot.png",
    "boss": "assets/enemies/boss.png",
    "bomber": "assets/enemies/bomber.png",
    "medic": "assets/enemies/medic.png",
    "splitter": "assets/enemies/splitter.png",
    "blinker": "assets/enemies/blinker.png",
    "splinter": "assets/enemies/runner.png"
  })
  readonly property var powerupSpriteFiles: ({
    "medkit": "assets/powerups/medkit.png",
    "ammo": "assets/powerups/ammo.png",
    "overclock": "assets/powerups/overclock.png",
    "slow": "assets/powerups/slow.png",
    "coins": "assets/powerups/coins.png",
    "nuke": "assets/powerups/nuke.png"
  })
  readonly property var powerupWeights: [
    { id: "medkit", w: 28 }, { id: "ammo", w: 24 }, { id: "overclock", w: 16 },
    { id: "slow", w: 16 }, { id: "coins", w: 12 }, { id: "nuke", w: 4 }
  ]
  readonly property var currentWave: {
    if (waveIndex < 0 || waveIndex >= wavePlan.length) return null
    return wavePlan[waveIndex]
  }
  readonly property int currentWaveInterval: currentWave ? currentWave.interval : 1800
  // Later waves are allowed more simultaneous attackers so the jam is the
  // player's problem, not a spawn-queue that never drains.
  readonly property int clownLimit: 6 + Math.min(4, waveIndex)
  readonly property bool canReinforce: clownSiegeEnabled && baseHealth > 0 && !siegeWon
    && baseHealth < baseHealthCap && omaCoins >= reinforceCost
  readonly property bool canBuyMag: clownSiegeEnabled && baseHealth > 0 && !siegeWon
    && magTier < magTierCap && omaCoins >= extendedMagCost
  readonly property bool canAirdrop: clownSiegeEnabled && baseHealth > 0 && !siegeWon
    && omaCoins >= airdropCost
  property var ammo: ({})
  property bool reloadPending: false
  property string reloadTarget: ""
  property int reloadCursor: 0
  // Real magazine/cylinder capacities, except the M20s: two rockets rather than
  // a true breech load, because one shot per typed phrase played miserably.
  readonly property var magazineSizes: ({
    "glock": 17, "revolver": 6, "ak47": 30, "mp5a3": 30, "bazooka": 2, "thick-bazooka": 2
  })
  readonly property int currentAmmo: {
    if (!clownSiegeEnabled) return -1
    var held = ammo[weapon]
    return held === undefined ? 0 : held
  }
  readonly property bool bossAlive: {
    for (var i = 0; i < clowns.length; i++)
      if (clowns[i].boss) return true
    return false
  }
  // Pre-split into bubble lines so the boss never needs a text layout pass.
  readonly property var nerdQuotes: [
    { who: "Donald Knuth", lines: ["Premature optimization", "is the root of all evil."] },
    { who: "Linus Torvalds", lines: ["Talk is cheap.", "Show me the code."] },
    { who: "Edsger Dijkstra", lines: ["The competent programmer is fully aware", "of the strictly limited size of his own skull."] },
    { who: "Harold Abelson", lines: ["Programs must be written for people to read,", "and only incidentally for machines to execute."] },
    { who: "Edsger Dijkstra", lines: ["Simplicity is a", "prerequisite for reliability."] },
    { who: "programmer folklore", lines: ["It's not a bug,", "it's an undocumented feature."] },
    { who: "Ken Thompson", lines: ["One of my most productive days was", "throwing away 1000 lines of code."] },
    { who: "Grace Hopper", lines: ["It's easier to ask forgiveness", "than it is to get permission."] },
    { who: "Alan Turing", lines: ["We can only see a short distance ahead,", "but we can see plenty there", "that needs to be done."] },
    { who: "Robert C. Martin", lines: ["The only way to go fast", "is to go well."] },
    { who: "Edsger Dijkstra", lines: ["Testing shows the presence,", "not the absence of bugs."] },
    { who: "C.A.R. Hoare", lines: ["There are two ways of constructing", "a software design."] },
    { who: "Fred Brooks", lines: ["Adding manpower to a late project", "makes it later."] },
    { who: "Fred Brooks", lines: ["There is no silver bullet."] },
    { who: "Brian Kernighan", lines: ["Debugging is twice as hard", "as writing the code."] },
    { who: "Jeff Sickel", lines: ["Deleted code is", "debugged code."] },
    { who: "Martin Fowler", lines: ["Any fool can write code", "that a computer can understand."] },
    { who: "Martin Fowler", lines: ["Good programmers write code", "that humans can understand."] },
    { who: "Bjarne Stroustrup", lines: ["There are only two kinds of languages:", "the ones people complain about", "and the ones nobody uses."] },
    { who: "Alan Kay", lines: ["The best way to predict", "the future is to invent it."] },
    { who: "John Johnson", lines: ["First, solve the problem.", "Then, write the code."] },
    { who: "Kent Beck", lines: ["Make it work.", "Make it right.", "Make it fast."] },
    { who: "Phil Karlton", lines: ["There are only two hard things:", "cache invalidation", "and naming things."] },
    { who: "Rob Pike", lines: ["A little copying is better", "than a little dependency."] },
    { who: "Larry Wall", lines: ["The three chief virtues of a programmer", "are laziness, impatience, and hubris."] },
    { who: "programmer folklore", lines: ["It's always DNS."] },
    { who: "programmer folklore", lines: ["Works on my machine."] },
    { who: "programmer folklore", lines: ["Have you tried turning it", "off and on again?"] },
    { who: "Jamie Zawinski", lines: ["Now you have two problems."] },
    { who: "Tim Peters", lines: ["Explicit is better than implicit.", "Simple is better than complex."] },
    { who: "Linus's Law", lines: ["Given enough eyeballs,", "all bugs are shallow."] },
    { who: "Margaret Hamilton", lines: ["There was no second chance."] }
  ]
  readonly property var extraReloadPhrases: [
    "It's always DNS", "Works on my machine", "off by one",
    "use the source Luke", "There is no silver bullet",
    "Deleted code is debugged code", "Make it work then make it right",
    "undefined is not a function", "Have you tried turning it off",
    "Code never lies", "Keep it simple stupid", "Don't repeat yourself",
    "Fail fast", "Read the fine manual", "Cache invalidation is hard",
    "Naming things is hard", "It compiles ship it", "Segmentation fault",
    "Hello world", "To iterate is human", "to recurse divine",
    "Adding manpower makes it later", "No such file or directory",
    "Permission denied", "Connection refused", "Core dumped",
    "Null pointer exception", "Stack overflow", "Out of memory",
    "This should never happen", "Beware of bugs", "I have not tried it",
    "if both are frozen", "Show me the code", "Talk is cheap",
    "Now you have two problems", "sudo make me a sandwich",
    "commit early commit often", "never force push main",
    "chmod 777 is not a fix", "cannot reproduce",
    "Parse don't validate", "all bugs are shallow",
    "the cake is a lie", "todo fix later"
  ]
  // Boss lines plus a dedicated pool of short typeable clauses.
  readonly property var reloadPhrases: {
    var phrases = extraReloadPhrases.slice()
    for (var i = 0; i < nerdQuotes.length; i++) {
      for (var j = 0; j < nerdQuotes[i].lines.length; j++) {
        var line = nerdQuotes[i].lines[j].replace(/[,.?]+$/, "")
        if (line.length >= 8 && line.length <= 32) phrases.push(line)
      }
    }
    return phrases
  }
  // Drawn as the bar's midpoint so the siege line still reads as "the bar".
  // Each clown marches at its own gate along that same edge, so they don't
  // stack into a single file.
  readonly property point basePoint: {
    if (barPosition === "bottom") return Qt.point(window.width / 2, window.height - baseRadius)
    if (barPosition === "left") return Qt.point(baseRadius, window.height / 2)
    if (barPosition === "right") return Qt.point(window.width - baseRadius, window.height / 2)
    return Qt.point(window.width / 2, baseRadius)
  }
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

  component ShopButton: Item {
    id: shopButton
    required property string label
    required property bool available
    property int price: 0
    signal activated()
    height: 24

    Rectangle {
      anchors.fill: parent
      radius: 4
      opacity: shopButton.available ? 1 : 0.45
      color: shopHover.containsMouse && shopButton.available ? "#33ffffff" : "#1fffffff"
      border.width: 1
      border.color: shopButton.available
        ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.9)
        : "#44ffffff"

      Row {
        anchors.centerIn: parent
        spacing: 5
        Text {
          text: shopButton.label
          textFormat: Text.PlainText
          color: "#d9ffffff"
          font.pixelSize: 11
        }
        Image {
          visible: shopButton.price > 0
          width: 12
          height: 12
          anchors.verticalCenter: parent.verticalCenter
          source: Qt.resolvedUrl("assets/powerups/coins.png")
          fillMode: Image.PreserveAspectFit
          smooth: false
        }
        Text {
          visible: shopButton.price > 0
          text: "" + shopButton.price
          textFormat: Text.PlainText
          color: "#9ECE6A"
          font.pixelSize: 11
          font.bold: true
        }
      }
    }

    // The HUD panel's z puts this whole subtree above the arena-wide firing
    // MouseArea, so the press is consumed here instead of pulling the trigger.
    // Never disable it for affordability either: a disabled MouseArea would let
    // the click through to the gun, so it stays live and the purchase handler
    // ignores what cannot be bought.
    MouseArea {
      id: shopHover
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton
      cursorShape: shopButton.available ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: shopButton.activated()
    }
  }

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
  // One extra rocket is worth as much as fifteen rifle rounds, so the M20s take
  // a smaller step per extended-magazine tier.
  function magStep(id) {
    return (id === "bazooka" || id === "thick-bazooka") ? 1 : 15
  }
  function magSize(id) {
    var size = magazineSizes[id]
    if (size === undefined) size = 1
    return size + magStep(id) * magTier
  }
  function setAmmo(id, count) {
    // Replace the map rather than mutating it: the HUD binding only re-runs
    // when the property itself changes.
    var next = {}
    for (var key in ammo) next[key] = ammo[key]
    next[id] = count
    ammo = next
  }
  function resetAmmo() {
    var next = {}
    for (var i = 0; i < weaponOptions.length; i++)
      next[weaponOptions[i].id] = magSize(weaponOptions[i].id)
    ammo = next
  }
  function beginReload() {
    if (!clownSiegeEnabled || reloadPending || !armed || siegeWon) return
    automaticHoldEngaged = false
    automaticHoldTimer.stop()
    fireTimer.stop()
    automaticSound.stop()
    mp5AutomaticSound.stop()
    reloadTarget = reloadPhrases[Math.floor(Math.random() * reloadPhrases.length)]
    reloadCursor = 0
    reloadPending = true
    canvas.requestPaint()
  }
  function cancelReload() {
    reloadPending = false
    reloadTarget = ""
    reloadCursor = 0
  }
  function typeReload(text) {
    if (!reloadPending || reloadCursor >= reloadTarget.length) return
    // Forgiving on purpose: case is ignored and a wrong key does nothing, so
    // this stays a pause in the action rather than a typing test.
    if (text.toLowerCase() !== reloadTarget.charAt(reloadCursor).toLowerCase()) return
    reloadCursor += 1
    if (reloadCursor >= reloadTarget.length) {
      setAmmo(weapon, magSize(weapon))
      cancelReload()
      weaponReadySound.stop()
      weaponReadySound.play()
    }
    canvas.requestPaint()
  }
  function resetSiege() {
    clowns = []
    clownSerial = 0
    baseHealth = 100
    score = 0
    clownsDefeated = 0
    bossPending = false
    bossQuoteIndex = 0
    omaCoins = 0
    // Before resetAmmo: the tier decides what a full magazine is.
    magTier = 0
    waveIndex = 0
    waveSpawned = 0
    waveResting = false
    siegeWon = false
    powerups = []
    pendingPowerups = []
    spawnQueue = []
    damageBoostUntil = 0
    slowUntil = 0
    siegeClock = 0
    waveRestTimer.stop()
    cancelReload()
    resetAmmo()
  }
  function artUrl(rel) {
    return Qt.resolvedUrl(rel).toString()
  }
  function preloadSiegeArt() {
    if (!canvas.available) return
    var k
    for (k in enemySpriteFiles) canvas.loadImage(artUrl(enemySpriteFiles[k]))
    for (k in powerupSpriteFiles) canvas.loadImage(artUrl(powerupSpriteFiles[k]))
  }
  function rollWeighted(list) {
    var total = 0
    for (var i = 0; i < list.length; i++) total += list[i].w
    var roll = Math.random() * total
    for (var j = 0; j < list.length; j++) {
      roll -= list[j].w
      if (roll <= 0) return list[j]
    }
    return list[list.length - 1]
  }
  function rollEnemyType(wave) {
    if (!wave || !wave.mix || !wave.mix.length) return "clown"
    return rollWeighted(wave.mix).type
  }
  function siegeDamage(amount) {
    if (Date.now() < damageBoostUntil) return amount * 2
    return amount
  }
  function enqueueEnemy(type, x, y) {
    if (spawnQueue.length >= 12) return
    spawnQueue = spawnQueue.concat([{ type: type, x: x, y: y }])
  }
  function flushSpawnQueue() {
    var q = spawnQueue
    if (!q.length) return
    spawnQueue = []
    for (var i = 0; i < q.length; i++)
      spawnSiegeEnemy(q[i].type, q[i].x, q[i].y)
  }
  function rollPowerupKind(excludeNuke) {
    var list = []
    for (var i = 0; i < powerupWeights.length; i++) {
      if (excludeNuke && powerupWeights[i].id === "nuke") continue
      list.push(powerupWeights[i])
    }
    return rollWeighted(list).id
  }
  function spawnPowerup(x, y, kind) {
    if (!clownSiegeEnabled || siegeWon) return
    if (powerups.length + pendingPowerups.length >= powerupCap) return
    pendingPowerups = pendingPowerups.concat([{
      id: ++powerupSerial,
      x: x, y: y,
      kind: kind || rollPowerupKind(false),
      born: Date.now(),
      phase: Math.random() * Math.PI * 2
    }])
  }
  function flushPowerups() {
    if (!pendingPowerups.length) return
    var extra = pendingPowerups
    pendingPowerups = []
    var next = powerups.slice()
    for (var i = 0; i < extra.length && next.length < powerupCap; i++)
      next.push(extra[i])
    powerups = next
  }
  function applyPowerup(kind) {
    var now = Date.now()
    if (kind === "medkit") {
      baseHealth = Math.min(baseHealthCap, baseHealth + 25)
    } else if (kind === "ammo") {
      var full = {}
      for (var a = 0; a < weaponOptions.length; a++) {
        var id = weaponOptions[a].id
        full[id] = magSize(id)
      }
      ammo = full
      cancelReload()
    } else if (kind === "overclock") {
      damageBoostUntil = Math.max(damageBoostUntil, now) + 7000
    } else if (kind === "slow") {
      slowUntil = Math.max(slowUntil, now) + 6000
    } else if (kind === "coins") {
      omaCoins += 8
    } else if (kind === "nuke") {
      splashClowns(window.width / 2, window.height / 2, 4000, 90)
      playRocketExplosion({ boomScale: 2.2 })
    }
    weaponReadySound.stop()
    weaponReadySound.play()
  }
  function collectPowerupAt(index) {
    if (index < 0 || index >= powerups.length) return
    var kind = powerups[index].kind
    var next = powerups.slice()
    next.splice(index, 1)
    powerups = next
    applyPowerup(kind)
  }
  function powerupAt(x, y, radius) {
    for (var i = 0; i < powerups.length; i++) {
      var p = powerups[i]
      var dx = x - p.x
      var dy = y - p.y
      if (dx * dx + dy * dy <= Math.pow(28 + radius, 2)) return i
    }
    return -1
  }
  function advancePowerups() {
    if (!clownSiegeEnabled || powerups.length === 0) return
    var now = Date.now()
    var next = []
    for (var i = 0; i < powerups.length; i++) {
      var p = powerups[i]
      if (now - p.born > 10000) continue
      p.phase += 0.14
      p.y += Math.sin(p.phase) * 0.35
      var dx = pointerX - p.x
      var dy = pointerY - p.y
      if (dx * dx + dy * dy <= 42 * 42) {
        applyPowerup(p.kind)
        continue
      }
      next.push(p)
    }
    powerups = next
  }
  function buyAirdrop() {
    if (!canAirdrop) return
    omaCoins -= airdropCost
    var x = gunPositioned ? pointerX : window.width / 2
    var y = gunPositioned ? pointerY : window.height / 2
    spawnPowerup(x, y, "ammo")
  }
  function explodeBomber(clown, fromDeath) {
    var dx = clown.gateX - clown.x
    var dy = clown.gateY - clown.y
    var dist = Math.sqrt(dx * dx + dy * dy)
    if (!fromDeath || dist < 240) damageBase(fromDeath ? 12 : 22)
    playRocketExplosion({ boomScale: fromDeath ? 1.15 : 1.7 })
    return rocketBlastParticles({
      x: clown.x, y: clown.y, boomScale: fromDeath ? 1.1 : 1.6
    })
  }
  function medicHeal(medic) {
    var best = -1
    var bestMissing = 0
    for (var i = 0; i < clowns.length; i++) {
      var ally = clowns[i]
      if (!ally || ally.id === medic.id) continue
      var missing = ally.maxHp - ally.hp
      if (missing > bestMissing) {
        bestMissing = missing
        best = i
      }
    }
    if (best < 0) return
    var target = clowns[best]
    var hx = target.x - medic.x
    var hy = target.y - medic.y
    if (hx * hx + hy * hy > 240 * 240) return
    target.hp = Math.min(target.maxHp, target.hp + 28)
    pendingEffects = pendingEffects.concat([{
      x: target.x, y: target.y, vx: 0, vy: -1.4, life: 0.85, size: 9, kind: 5
    }])
  }
  // Speeds are authored for a 1080px march. Scale with the attack axis so a
  // 4K bar doesn't play in slow motion, then clamp so an ultrawide side-bar
  // doesn't teleport robots.
  function siegeSpeedFactor() {
    var march = (barPosition === "left" || barPosition === "right") ? window.width : window.height
    var screen = Math.max(0.7, Math.min(2.0, march / 1080))
    var wave = currentWave
    var waveSpeed = wave && wave.speed ? wave.speed : 1
    return enemySpeedScale * screen * waveSpeed
  }
  function gateAlongBar(t, lane) {
    var w = window.width
    var h = window.height
    if (barPosition === "bottom") return { x: w * t, y: h - baseRadius, lane: lane }
    if (barPosition === "left") return { x: baseRadius, y: h * t, lane: lane }
    if (barPosition === "right") return { x: w - baseRadius, y: h * t, lane: lane }
    return { x: w * t, y: baseRadius, lane: lane }
  }
  function centerGate() {
    return gateAlongBar(0.5, 3)
  }
  function pickGate() {
    var lanes = 7
    var used = []
    for (var i = 0; i < lanes; i++) used.push(0)
    for (var j = 0; j < clowns.length; j++) {
      var lane = clowns[j].lane
      if (lane >= 0 && lane < lanes) used[lane] += 1
    }
    var best = Math.floor(Math.random() * lanes)
    var bestUsed = used[best]
    for (var k = 0; k < lanes; k++) {
      if (used[k] < bestUsed || (used[k] === bestUsed && Math.random() < 0.35)) {
        best = k
        bestUsed = used[k]
      }
    }
    return gateAlongBar(0.14 + (best + 0.5) / lanes * 0.72, best)
  }
  function checkWaveClear() {
    if (!clownSiegeEnabled || siegeWon || baseHealth <= 0 || waveResting) return
    var wave = currentWave
    if (!wave) return
    if (waveSpawned < wave.count) return
    if (wave.boss && (bossPending || bossAlive)) return
    if (clowns.length > 0) return
    if (wave.last) {
      celebrateVictory()
      return
    }
    waveResting = true
    waveRestTimer.restart()
    canvas.requestPaint()
  }
  function startNextWave() {
    if (!armed || !clownSiegeEnabled || siegeWon || baseHealth <= 0) return
    waveResting = false
    waveIndex += 1
    waveSpawned = 0
    bossPending = false
    spawnClown()
    canvas.requestPaint()
  }
  function celebrateVictory() {
    siegeWon = true
    waveResting = false
    waveRestTimer.stop()
    cancelReload()
    automaticHoldEngaged = false
    automaticHoldTimer.stop()
    fireTimer.stop()
    automaticSound.stop()
    mp5AutomaticSound.stop()
    playWindowBreak()
    weaponReadySound.stop()
    weaponReadySound.play()
    canvas.requestPaint()
  }
  function buyExtendedMag() {
    if (!canBuyMag) return
    omaCoins -= extendedMagCost
    magTier += 1
    // Hand over the new capacity as live rounds so the upgrade is felt at once,
    // without also granting a free top-up of what was already spent.
    var next = {}
    for (var i = 0; i < weaponOptions.length; i++) {
      var id = weaponOptions[i].id
      var held = ammo[id] === undefined ? 0 : ammo[id]
      next[id] = Math.min(magSize(id), held + magStep(id))
    }
    ammo = next
    if (reloadPending && next[weapon] > 0) cancelReload()
    weaponReadySound.stop()
    weaponReadySound.play()
  }
  function reinforceBase() {
    if (!canReinforce) return
    omaCoins -= reinforceCost
    // Overheal stacks as shield up to the cap; the last purchase before the cap
    // deliberately wastes its remainder rather than being refused.
    baseHealth = Math.min(baseHealthCap, baseHealth + 15)
    weaponReadySound.stop()
    weaponReadySound.play()
  }
  function spawnClown() {
    if (!armed || !clownSiegeEnabled || baseHealth <= 0 || siegeWon || waveResting) return
    // A boss owns the arena while it lives: regular spawns pause so the fight
    // never becomes a damage sponge plus an unbounded crowd.
    if (bossAlive) return
    if (bossPending) {
      // The boss is allowed to exceed the simultaneous cap so a full field
      // cannot stall the wave's end beat.
      bossPending = false
      spawnSiegeEnemy("boss")
      return
    }
    var wave = currentWave
    if (!wave || waveSpawned >= wave.count) return
    if (clowns.length >= clownLimit) return
    spawnSiegeEnemy(rollEnemyType(wave))
    waveSpawned += 1
    if (waveSpawned >= wave.count && wave.boss) bossPending = true
  }
  function spawnSiegeEnemy(type, atX, atY) {
    var radius = 21 + Math.random() * 9
    var maxHp = 55 + Math.round(Math.random() * 65)
    var speed = 0.55 + Math.random() * 0.8
    if (type === "boss") {
      radius = 54
      maxHp = 900
      speed = 0.34
    } else if (type === "runner") {
      radius = 16 + Math.random() * 4
      maxHp = 30 + Math.round(Math.random() * 20)
      speed = 1.7 + Math.random() * 0.6
    } else if (type === "bruiser") {
      radius = 34 + Math.random() * 8
      maxHp = 210 + Math.round(Math.random() * 60)
      speed = 0.3 + Math.random() * 0.2
    } else if (type === "robot") {
      radius = 26
      maxHp = 320
      speed = 2.6
    } else if (type === "bomber") {
      radius = 24 + Math.random() * 4
      maxHp = 75 + Math.round(Math.random() * 25)
      speed = 0.72 + Math.random() * 0.2
    } else if (type === "medic") {
      radius = 22
      maxHp = 95 + Math.round(Math.random() * 25)
      speed = 0.42 + Math.random() * 0.12
    } else if (type === "splitter") {
      radius = 23
      maxHp = 80 + Math.round(Math.random() * 20)
      speed = 0.8 + Math.random() * 0.2
    } else if (type === "blinker") {
      radius = 20
      maxHp = 50 + Math.round(Math.random() * 20)
      speed = 0.9 + Math.random() * 0.25
    } else if (type === "splinter") {
      radius = 13 + Math.random() * 3
      maxHp = 20 + Math.round(Math.random() * 10)
      speed = 1.85 + Math.random() * 0.3
    }
    var wave = currentWave
    var hpScale = wave && wave.hp ? wave.hp : 1
    maxHp = Math.round(maxHp * hpScale)
    speed *= siegeSpeedFactor()
    var gate = type === "boss" ? centerGate() : pickGate()
    var x = 0
    var y = 0
    if (atX !== undefined && atY !== undefined) {
      x = atX
      y = atY
    } else if (barPosition === "bottom") {
      x = radius + Math.random() * Math.max(1, window.width - radius * 2)
      y = -radius
    } else if (barPosition === "left") {
      x = window.width + radius
      y = radius + Math.random() * Math.max(1, window.height - radius * 2)
    } else if (barPosition === "right") {
      x = -radius
      y = radius + Math.random() * Math.max(1, window.height - radius * 2)
    } else {
      x = radius + Math.random() * Math.max(1, window.width - radius * 2)
      y = window.height + radius
    }
    var now = Date.now()
    clowns = clowns.concat([{
      id: ++clownSerial, x: x, y: y,
      hp: maxHp, maxHp: maxHp,
      speed: speed,
      radius: radius,
      type: type,
      boss: type === "boss",
      splinter: type === "splinter",
      gateX: gate.x,
      gateY: gate.y,
      lane: gate.lane,
      wobble: (type === "boss" ? 0.08 : 0.22 + Math.random() * 0.3) * siegeSpeedFactor(),
      // The first shot comes early so a robot always beams at least once before
      // it crosses a short screen; after that it settles into the 12s cadence.
      beamAt: type === "robot" ? now + 3500 : 0,
      healAt: type === "medic" ? now + 1800 : 0,
      blinkAt: type === "blinker" ? now + 2200 : 0,
      summonAt: type === "boss" ? now + 5000 : 0,
      phase: Math.random() * Math.PI * 2
    }])
    if (type === "boss") {
      bossQuoteIndex = Math.floor(Math.random() * nerdQuotes.length)
      playWindowBreak()
    }
    canvas.requestPaint()
  }
  function advanceClowns() {
    if (!armed || !clownSiegeEnabled || clowns.length === 0) return
    var now = Date.now()
    var slowMul = now < slowUntil ? 0.4 : 1
    var next = clowns.slice()
    var breaches = 0
    var beamDamage = 0
    for (var i = next.length - 1; i >= 0; i--) {
      var clown = next[i]
      var gx = clown.gateX
      var gy = clown.gateY
      var dx = gx - clown.x
      var dy = gy - clown.y
      var distance = Math.max(0.001, Math.sqrt(dx * dx + dy * dy))
      clown.phase += 0.19
      if (clown.type === "robot" && now >= clown.beamAt) {
        clown.beamAt = now + 12000
        beamDamage += 9
        fireBeam(clown.x, clown.y, gx, gy)
      }
      if (clown.type === "medic" && now >= clown.healAt) {
        clown.healAt = now + 2500
        medicHeal(clown)
      }
      if (clown.type === "boss" && now >= clown.summonAt) {
        clown.summonAt = now + 8000
        enqueueEnemy("splinter", clown.x + 36, clown.y)
        enqueueEnemy("splinter", clown.x - 36, clown.y)
      }
      if (distance <= clown.radius + baseRadius) {
        if (clown.type === "bomber")
          pendingEffects = pendingEffects.concat(explodeBomber(clown, false))
        else breaches += 1
        next.splice(i, 1)
        continue
      }
      var nx = dx / distance
      var ny = dy / distance
      if (clown.type === "blinker" && now >= clown.blinkAt) {
        clown.blinkAt = now + 2800
        var jump = Math.min(distance - clown.radius - baseRadius - 8, 110 * siegeSpeedFactor())
        if (jump > 8) {
          pendingEffects = pendingEffects.concat([{
            x: clown.x, y: clown.y, vx: 0, vy: 0, life: 0.55, size: clown.radius, kind: 5
          }])
          clown.x += nx * jump
          clown.y += ny * jump
        }
      }
      // Lateral wobble fades as they close so the breach test still matches
      // the path they were actually walking.
      var step = clown.speed * slowMul
      var wobble = Math.sin(clown.phase * 0.7) * (clown.wobble || 0) * Math.min(1, distance / 180)
      clown.x += nx * step - ny * wobble
      clown.y += ny * step + nx * wobble
    }
    clowns = next
    if (breaches > 0) breachBase(breaches)
    if (beamDamage > 0) damageBase(beamDamage)
  }
  function fireBeam(x, y, targetX, targetY) {
    pendingEffects = pendingEffects.concat([{ x: x, y: y, beamX: targetX, beamY: targetY, life: 1, size: 4, kind: 8 }])
    bazookaLaunchSound.stop()
    bazookaLaunchSound.volume = 0.55
    bazookaLaunchSound.play()
  }
  function damageBase(amount) {
    baseHealth = Math.max(0, baseHealth - amount)
    if (baseHealth <= 0) clowns = []
  }
  function breachBase(count) {
    playWindowBreak()
    damageBase(12 * count)
  }
  function clownAt(x, y, radius) {
    for (var i = 0; i < clowns.length; i++) {
      var clown = clowns[i]
      var dx = x - clown.x
      var dy = y - clown.y
      if (dx * dx + dy * dy <= Math.pow(clown.radius + radius, 2)) return i
    }
    return -1
  }
  function damageClown(index, amount) {
    var next = clowns.slice()
    var clown = next[index]
    if (!clown) return
    clown.hp -= amount
    targetHitSound.stop()
    targetHitSound.play()
    var burst = pendingEffects.slice()
    for (var i = 0; i < 9; i++) {
      var sprayAngle = Math.random() * Math.PI * 2
      var spraySpeed = 1 + Math.random() * 3.4
      burst.push({ x: clown.x, y: clown.y, vx: Math.cos(sprayAngle) * spraySpeed, vy: Math.sin(sprayAngle) * spraySpeed - 1, life: 0.5 + Math.random() * 0.35, size: 3 + Math.random() * 5, kind: 5 })
    }
    if (clown.hp <= 0) {
      for (var puff = 0; puff < (clown.boss ? 54 : 22); puff++) {
        var puffAngle = Math.random() * Math.PI * 2
        var puffSpeed = 1.5 + Math.random() * (clown.boss ? 9 : 5)
        burst.push({ x: clown.x, y: clown.y, vx: Math.cos(puffAngle) * puffSpeed, vy: Math.sin(puffAngle) * puffSpeed - 1.4, life: 0.6 + Math.random() * 0.4, size: 4 + Math.random() * (clown.boss ? 12 : 7), kind: 7 })
      }
      next.splice(index, 1)
      omaCoins += 1
      if (clown.boss) {
        score += 10
        burst = burst.concat(rocketBlastParticles({ x: clown.x, y: clown.y, boomScale: 2.4 }))
        playRocketExplosion({ boomScale: 2.4 })
        playWindowBreak()
      } else {
        score += 1
        clownsDefeated += 1
      }
      if (clown.type === "bomber") burst = burst.concat(explodeBomber(clown, true))
      if (clown.type === "splitter" && !clown.splinter) {
        enqueueEnemy("splinter", clown.x + 18, clown.y - 8)
        enqueueEnemy("splinter", clown.x - 18, clown.y + 8)
      }
      if (Math.random() < (clown.boss ? 0.55 : 0.22)) spawnPowerup(clown.x, clown.y)
    }
    pendingEffects = burst
    clowns = next
    canvas.requestPaint()
  }
  function splashClowns(x, y, radius, amount) {
    // Back to front: damageClown can drop the entry it was handed, and removing
    // at a higher index never shifts the ones still to be tested.
    for (var i = clowns.length - 1; i >= 0; i--) {
      var clown = clowns[i]
      if (!clown) continue
      var dx = x - clown.x
      var dy = y - clown.y
      if (dx * dx + dy * dy <= Math.pow(radius + clown.radius, 2)) damageClown(i, amount)
    }
  }
  function setTargetsEnabled(enabled) {
    targetsEnabled = enabled
    if (enabled) {
      destructionEnabled = false
      setClownSiegeEnabled(false)
    }
    targetRespawnTimer.stop()
    targetVisible = false
    canvas.requestPaint()
    if (targetsEnabled && armed) spawnTarget()
  }
  function setDestructionEnabled(enabled) {
    destructionEnabled = enabled
    if (enabled) {
      setTargetsEnabled(false)
      setClownSiegeEnabled(false)
    }
  }
  // The three modes each own the whole arena, so enabling one always stands the
  // others down. Only the `enabled` branches cross-call, which is what keeps
  // this trio from recursing.
  function setClownSiegeEnabled(enabled) {
    clownSiegeEnabled = enabled
    if (enabled) {
      setTargetsEnabled(false)
      setDestructionEnabled(false)
      preloadSiegeArt()
    }
    resetSiege()
    canvas.requestPaint()
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
    // The new weapon carries its own magazine, so a reload aimed at the old one
    // no longer applies. Swapping is a legitimate way to duck out of typing mid
    // fight, but an empty gun still owes its magazine the moment it comes back
    // up, so re-open the prompt immediately instead of waiting for a dry click.
    // Read the map rather than currentAmmo: `weapon` changed on the line above.
    cancelReload()
    var held = ammo[id]
    if (!siegeWon && clownSiegeEnabled && (held === undefined || held <= 0)) Qt.callLater(root.beginReload)
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
    resetSiege()
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
    resetSiege()
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
    if (clownSiegeEnabled && !siegeWon) {
      if (reloadPending) return
      if (currentAmmo <= 0) {
        dryFireSound.stop()
        dryFireSound.play()
        beginReload()
        return
      }
      var remaining = currentAmmo - 1
      setAmmo(weapon, remaining)
      if (remaining <= 0) Qt.callLater(root.beginReload)
    }
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
        impactPower: power, impactDamage: power * (spec.damageScale || 1),
        impacted: impact === null
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
        // A pending reload owns the keyboard so the phrase can use any letter,
        // Q included. Escape above still gets out first.
        if (root.reloadPending) {
          if (event.text && event.text.length === 1) root.typeReload(event.text)
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

        if (root.armed && root.clownSiegeEnabled) {
          var base = root.basePoint
          c.globalAlpha = root.baseHealth > 0 ? 0.8 : 0.3
          c.strokeStyle = root.baseHealth > 40 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 1) : "#c92f35"
          c.lineWidth = 6
          c.beginPath()
          if (root.barPosition === "left" || root.barPosition === "right") {
            c.moveTo(base.x, 0); c.lineTo(base.x, height)
          } else {
            c.moveTo(0, base.y); c.lineTo(width, base.y)
          }
          c.stroke()
          c.globalAlpha = 1

          for (var ci = 0; ci < root.clowns.length; ci++) {
            var clown = root.clowns[ci]
            var cr = clown.radius
            var kind = clown.type || "clown"
            var isBoss = kind === "boss"
            var bob = Math.sin(clown.phase) * cr * 0.1
            var spriteRel = root.enemySpriteFiles[kind] || root.enemySpriteFiles.clown
            var spriteSrc = root.artUrl(spriteRel)
            var rw = cr * 2.15
            var rh = cr * 2.7
            if (canvas.isImageLoaded(spriteSrc)) {
              c.drawImage(spriteSrc, clown.x - rw / 2, clown.y - rh + cr * 0.55 + bob, rw, rh)
            } else {
              c.fillStyle = isBoss ? "#3b2a5a" : "#2f3a66"
              c.beginPath(); c.arc(clown.x, clown.y + bob, cr, 0, Math.PI * 2); c.fill()
            }

            // Bar hangs off the un-waddled position so it stays easy to read.
            var barWidth = cr * 2.2
            var barHeight = Math.max(5, cr * 0.26)
            var barX = clown.x - barWidth / 2
            var barY = clown.y - cr * 2.3
            var fraction = Math.max(0, Math.min(1, clown.hp / clown.maxHp))
            c.fillStyle = "#12151b"
            c.fillRect(barX - 2, barY - 2, barWidth + 4, barHeight + 4)
            c.fillStyle = fraction > 0.6 ? "#4ccf6a" : (fraction > 0.3 ? "#ffd24a" : "#ff4d2e")
            c.fillRect(barX, barY, barWidth * fraction, barHeight)

            if (!isBoss) continue

            var quote = root.nerdQuotes[root.bossQuoteIndex % root.nerdQuotes.length]
            var credit = "— " + quote.who
            var lineHeight = 17
            var bubblePad = 11
            var textWidth = 0
            c.font = "13px sans-serif"
            for (var qi = 0; qi < quote.lines.length; qi++)
              textWidth = Math.max(textWidth, c.measureText(quote.lines[qi]).width)
            c.font = "italic 11px sans-serif"
            textWidth = Math.max(textWidth, c.measureText(credit).width)
            var bubbleWidth = textWidth + bubblePad * 2
            var bubbleHeight = quote.lines.length * lineHeight + 17 + bubblePad * 2
            var bubbleX = Math.max(8, Math.min(width - bubbleWidth - 8, clown.x - bubbleWidth / 2))
            var bubbleY = Math.max(8, barY - 16 - bubbleHeight)

            c.fillStyle = "#f2ece1"
            c.fillRect(bubbleX, bubbleY, bubbleWidth, bubbleHeight)
            c.beginPath()
            c.moveTo(clown.x - 10, bubbleY + bubbleHeight)
            c.lineTo(clown.x + 10, bubbleY + bubbleHeight)
            c.lineTo(clown.x, bubbleY + bubbleHeight + 14)
            c.closePath(); c.fill()

            c.textAlign = "center"
            c.fillStyle = "#1b1d22"
            c.font = "13px sans-serif"
            for (qi = 0; qi < quote.lines.length; qi++)
              c.fillText(quote.lines[qi], bubbleX + bubbleWidth / 2, bubbleY + bubblePad + lineHeight * (qi + 1) - 4)
            c.fillStyle = "#6d6a63"
            c.font = "italic 11px sans-serif"
            c.fillText(credit, bubbleX + bubbleWidth / 2, bubbleY + bubblePad + lineHeight * quote.lines.length + 12)
            c.textAlign = "left"
          }

          for (var pi = 0; pi < root.powerups.length; pi++) {
            var pack = root.powerups[pi]
            var packRel = root.powerupSpriteFiles[pack.kind] || root.powerupSpriteFiles.medkit
            var packSrc = root.artUrl(packRel)
            var packSize = 44
            var packBob = Math.sin(pack.phase) * 3
            var age = root.siegeClock - pack.born
            c.globalAlpha = age > 8000 ? 0.45 : 1
            if (canvas.isImageLoaded(packSrc))
              c.drawImage(packSrc, pack.x - packSize / 2, pack.y - packSize / 2 + packBob, packSize, packSize)
            else {
              c.fillStyle = "#ffd24a"
              c.beginPath(); c.arc(pack.x, pack.y + packBob, 16, 0, Math.PI * 2); c.fill()
            }
            c.globalAlpha = 1
          }
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
          } else if (p.kind === 8) {
            c.globalAlpha = Math.max(0, p.life) * 0.9
            c.strokeStyle = "#ff4d2e"
            c.lineWidth = Math.max(1, 10 * p.life)
            c.beginPath(); c.moveTo(p.x, p.y); c.lineTo(p.beamX, p.beamY); c.stroke()
            c.strokeStyle = "#fff4ad"
            c.lineWidth = Math.max(1, 3.5 * p.life)
            c.beginPath(); c.moveTo(p.x, p.y); c.lineTo(p.beamX, p.beamY); c.stroke()
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

        if (root.armed && root.siegeWon) {
          var winCaption = "SIEGE BROKEN"
          var winScore = "score " + root.score + "  ·  Esc holsters"
          c.font = "bold 28px sans-serif"
          var winWidth = Math.max(c.measureText(winCaption).width, 280)
          c.font = "14px sans-serif"
          winWidth = Math.max(winWidth, c.measureText(winScore).width) + 64
          var winHeight = 96
          var winX = (width - winWidth) / 2
          var winY = height * 0.38
          c.globalAlpha = 0.93
          c.fillStyle = "#12151b"
          c.fillRect(winX, winY, winWidth, winHeight)
          c.globalAlpha = 1
          c.strokeStyle = Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 1)
          c.lineWidth = 2
          c.strokeRect(winX, winY, winWidth, winHeight)
          c.textAlign = "center"
          c.fillStyle = "#f2ece1"
          c.font = "bold 28px sans-serif"
          c.fillText(winCaption, width / 2, winY + 42)
          c.fillStyle = "#9da2a0"
          c.font = "14px sans-serif"
          c.fillText(winScore, width / 2, winY + 72)
          c.textAlign = "left"
        }

        if (root.armed && root.reloadPending) {
          var phrase = root.reloadTarget
          var caption = "RELOAD — type the line"
          // Monospace so the per-character advances sum to the measured width and
          // the caret cannot drift off the text.
          c.font = "bold 22px monospace"
          var phraseWidth = c.measureText(phrase).width
          c.font = "12px sans-serif"
          var panelWidth = Math.max(phraseWidth, c.measureText(caption).width) + 56
          var panelHeight = 92
          var panelX = (width - panelWidth) / 2
          var panelY = height * 0.7

          c.globalAlpha = 0.93
          c.fillStyle = "#12151b"
          c.fillRect(panelX, panelY, panelWidth, panelHeight)
          c.globalAlpha = 1
          c.strokeStyle = Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 1)
          c.lineWidth = 2
          c.strokeRect(panelX, panelY, panelWidth, panelHeight)

          c.textAlign = "center"
          c.fillStyle = "#9da2a0"
          c.font = "12px sans-serif"
          c.fillText(caption, width / 2, panelY + 27)

          c.textAlign = "left"
          c.font = "bold 22px monospace"
          var penX = (width - phraseWidth) / 2
          for (var pi = 0; pi < phrase.length; pi++) {
            var glyph = phrase.charAt(pi)
            c.fillStyle = pi < root.reloadCursor
              ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 1)
              : "#6d6a63"
            c.fillText(glyph, penX, panelY + 66)
            penX += c.measureText(glyph).width
          }
          if (root.reloadCursor < phrase.length) {
            c.fillStyle = "#f2ece1"
            c.fillRect(penX, panelY + 47, 2, 23)
          }
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
        text: root.weaponName
          + (root.clownSiegeEnabled && !root.siegeWon ? " · " + root.currentAmmo + "/" + root.magSize(root.weapon) : "")
          + (root.spec.automatic ? " · click/hold to fire" : " · click to fire")
          + " · middle/Q-hold weapon wheel · right-click spin · Esc holster"
        textFormat: Text.PlainText
        color: "#d9ffffff"
        font.pixelSize: 12
      }
    }

    Rectangle {
      id: siegePanel
      // One explicit content width: the children size from this rather than from
      // the Column, which would bind their width back to their own contents.
      readonly property int contentWidth: Math.max(siegeHud.implicitWidth, 310)
      visible: root.armed && root.clownSiegeEnabled
      z: 35
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: 18
      width: contentWidth + 24
      height: siegeColumn.implicitHeight + 16
      radius: 8
      color: "#b3151719"

      Column {
        id: siegeColumn
        anchors.centerIn: parent
        width: siegePanel.contentWidth
        spacing: 7

        Row {
          id: siegeHud
          spacing: 6

          Text {
            text: {
              if (root.siegeWon)
                return "SIEGE BROKEN  ·  SCORE " + root.score + "  ·  Esc holsters"
              if (root.baseHealth <= 0)
                return "BASE OVERRUN  ·  SCORE " + root.score + "  ·  Esc holsters"
              var wave = "WAVE " + (root.waveIndex + 1) + "/" + root.wavePlan.length
              if (root.waveResting)
                return wave + " CLEAR  ·  NEXT WAVE INCOMING"
              var extra = ""
              if (root.damageBoostUntil > root.siegeClock)
                extra += "  ·  OVERCLOCK " + Math.ceil((root.damageBoostUntil - root.siegeClock) / 1000) + "s"
              if (root.slowUntil > root.siegeClock)
                extra += "  ·  SLOW " + Math.ceil((root.slowUntil - root.siegeClock) / 1000) + "s"
              return wave
                + "  ·  BASE " + root.baseHealth + "/" + root.baseHealthCap
                + "  ·  SCORE " + root.score
                + (root.magTier > 0 ? "  ·  MAG+" + root.magTier : "")
                + (root.bossAlive ? "  ·  BOSS FIGHT"
                  : root.bossPending ? "  ·  BOSS INBOUND" : "")
                + extra
            }
            textFormat: Text.PlainText
            color: root.siegeWon ? "#8fd8d5" : root.baseHealth > 30 ? "#d9ffffff" : "#ffb4a8"
            font.pixelSize: 12
          }

          Image {
            visible: root.baseHealth > 0
            width: 14
            height: 14
            anchors.verticalCenter: parent.verticalCenter
            source: Qt.resolvedUrl("assets/powerups/coins.png")
            fillMode: Image.PreserveAspectFit
            smooth: false
          }

          Text {
            visible: root.baseHealth > 0
            anchors.verticalCenter: parent.verticalCenter
            text: "" + root.omaCoins
            textFormat: Text.PlainText
            color: "#9ECE6A"
            font.pixelSize: 12
            font.bold: true
          }
        }

        Rectangle {
          width: parent.width
          height: 9
          radius: 2
          color: "#26ffffff"

          Rectangle {
            width: parent.width * Math.min(root.baseHealth, 100) / root.baseHealthCap
            height: parent.height
            radius: 2
            color: root.baseHealth > 60 ? "#4ccf6a" : root.baseHealth > 30 ? "#ffd24a" : "#ff4d2e"
          }

          // Everything past 100 is shield, so it gets its own colour instead of
          // stretching the health scale.
          Rectangle {
            x: parent.width * 100 / root.baseHealthCap
            width: parent.width * Math.max(0, root.baseHealth - 100) / root.baseHealthCap
            height: parent.height
            radius: 2
            color: "#8fd8d5"
            visible: width > 0
          }

          Rectangle {
            x: parent.width * 100 / root.baseHealthCap
            width: 1
            height: parent.height
            color: "#99151719"
          }
        }

        ShopButton {
          width: parent.width
          visible: root.baseHealth > 0 && !root.siegeWon
          available: root.canReinforce
          label: root.baseHealth >= root.baseHealthCap
            ? "BASE FULLY REINFORCED"
            : "REINFORCE BASE  ·  +15 HP"
          price: root.baseHealth >= root.baseHealthCap ? 0 : root.reinforceCost
          onActivated: root.reinforceBase()
        }

        ShopButton {
          width: parent.width
          visible: root.baseHealth > 0 && !root.siegeWon
          available: root.canBuyMag
          label: root.magTier >= root.magTierCap
            ? "MAGS FULLY EXTENDED"
            : "EXTENDED MAG  ·  +15 ROUNDS / +1 ROCKET"
          price: root.magTier >= root.magTierCap ? 0 : root.extendedMagCost
          onActivated: root.buyExtendedMag()
        }

        ShopButton {
          width: parent.width
          visible: root.baseHealth > 0 && !root.siegeWon
          available: root.canAirdrop
          label: "AIRDROP  ·  MAX AMMO"
          price: root.airdropCost
          onActivated: root.buyAirdrop()
        }
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
      if (root.reloadPending) return
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

  SoundEffect {
    id: dryFireSound
    source: Qt.resolvedUrl("sounds/weapon-hover.wav")
    volume: 0.16
  }

  Timer {
    id: targetRespawnTimer
    interval: 700
    onTriggered: if (root.armed && root.targetsEnabled) root.spawnTarget()
  }

  // Declarative `running` means the wave stops itself the moment the mode is
  // switched off, the weapon is holstered, the base falls, a rest starts, or
  // the siege is won.
  Timer {
    interval: root.currentWaveInterval
    repeat: true
    running: root.armed && root.clownSiegeEnabled && root.baseHealth > 0
      && !root.siegeWon && !root.waveResting
    onTriggered: root.spawnClown()
  }

  Timer {
    id: waveRestTimer
    interval: 2800
    repeat: false
    onTriggered: root.startNextWave()
  }

  Timer {
    interval: 4200
    repeat: true
    running: root.armed && root.clownSiegeEnabled && root.bossAlive
    onTriggered: {
      root.bossQuoteIndex = (root.bossQuoteIndex + 1) % root.nerdQuotes.length
      canvas.requestPaint()
    }
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
      var clownsMarching = root.clownSiegeEnabled && root.clowns.length > 0
      var packsOut = root.clownSiegeEnabled && root.powerups.length > 0
      if (root.clownSiegeEnabled) {
        root.siegeClock = Date.now()
        root.advanceClowns()
      }
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
          if (root.clownSiegeEnabled) {
            var clownHit = root.clownAt(p.x, p.y, bulletRadius)
            if (clownHit >= 0) {
              root.damageClown(clownHit, root.siegeDamage(Math.round(22 * (p.impactDamage || 1))))
              continue
            }
            var packHit = root.powerupAt(p.x, p.y, bulletRadius)
            if (packHit >= 0) {
              root.collectPowerupAt(packHit)
              continue
            }
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
        if (p.kind === 8) {
          p.life -= 0.055
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
              if (root.clownSiegeEnabled)
                root.splashClowns(p.x, p.y, impactBlastRadius, root.siegeDamage(Math.round(70 * impactBoomScale)))
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
          if (root.clownSiegeEnabled && root.clownAt(p.x, p.y, rocketRadius) >= 0) {
            root.splashClowns(p.x, p.y, 180 * (p.boomScale || 1), root.siegeDamage(Math.round(70 * (p.boomScale || 1))))
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
            if (root.clownSiegeEnabled)
              root.splashClowns(p.x, p.y, blastRadius, root.siegeDamage(Math.round(70 * boomScale)))
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
      if (hadParticleWork || (root.clownSiegeEnabled && root.pendingEffects.length > 0)) {
        root.particles = next.concat(root.pendingEffects)
        root.pendingEffects = []
      }
      if (root.clownSiegeEnabled) {
        root.flushSpawnQueue()
        root.advancePowerups()
        root.flushPowerups()
        root.flushSpawnQueue()
        if (root.baseHealth <= 0) root.clowns = []
        root.checkWaveClear()
      }
      var gunMoved = Math.abs(root.gunX - oldGunX) > 0.01 || Math.abs(root.gunY - oldGunY) > 0.01
      if (hadParticleWork || gunMoved || oldRecoil > 0 || oldFlash > 0
          || (root.clownSiegeEnabled && (clownsMarching || packsOut)))
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
