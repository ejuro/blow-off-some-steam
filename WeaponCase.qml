import QtQuick
import qs.Commons
import qs.Ui
import "FlyRound.js" as Rules

Panel {
  id: root
  moduleName: "io.github.ejuro.blow-off-some-steam"
  ipcTarget: "io.github.ejuro.blow-off-some-steam"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var arena: null
  property bool doorsOpen: false
  property bool doorAnimationEnabled: true
  property bool launching: false
  property bool recordsTab: false
  property string pendingWeapon: ""
  readonly property string mode: arena ? arena.mode : "free"
  readonly property var bests: arena ? arena.flyRecords.bests : ({})
  readonly property bool soundMuted: arena ? arena.soundMuted : false
  readonly property var modes: [
    { id: "free", label: "Free play", detail: "no goal, just steam" },
    { id: "targets", label: "Targets", detail: "roaming bullseye" },
    { id: "hunt", label: "Fly Hunt", detail: "40 s · one weapon" },
    { id: "destruction", label: "Destruction", detail: "wreck a frozen desktop" }
  ]
  readonly property var weaponTitles: [
    { id: "glock", title: "GLOCK P80" }, { id: "revolver", title: "COLT 45" },
    { id: "ak47", title: "AK-47" }, { id: "mp5a3", title: "MP5A3" },
    { id: "bazooka", title: "M20" }, { id: "lightsaber", title: "LIGHTSABER" }
  ]
  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: Color.accent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function open() {
    cabinetScroll.contentY = 0
    doorAnimationEnabled = false
    doorsOpen = false
    root.controller.show()
    // The doors swing open right away; nothing waits on audio.
    Qt.callLater(function() {
      if (!root.opened) return
      doorAnimationEnabled = true
      doorsOpen = true
    })
  }
  function close() {
    launchTimer.stop()
    launching = false
    pendingWeapon = ""
    doorsOpen = false
    root.controller.hide()
  }
  function toggle() { if (root.opened) close(); else open() }
  function playWeaponHover() {
    weaponHoverSound.stop()
    weaponHoverSound.play()
  }
  // The medal a weapon's Fly Hunt best has earned (-1 for none); shown only in Fly Hunt.
  function medalRank(id) {
    var best = mode === "hunt" ? bests[id] : null
    return best ? Rules.medal(id, best.score) : -1
  }
  function toggleSound() {
    if (!arena) return
    arena.setSoundMuted(!soundMuted)
    // Turning it back on answers with the hover sound once the audio is up.
    if (!soundMuted) playWeaponHover()
  }
  function choose(id) {
    if (launching) return
    if (arena) {
      arena.targetScreen = panel.screen
      arena.barPosition = bar ? String(bar.position || "top") : "top"
      arena.barThickness = bar ? Number(bar.barSize || 30) : 30
    }
    if (arena && arena.destructionEnabled) {
      // Close the cabinet around the selection so capture preparation feels
      // like an arming sequence instead of an unexplained pause.
      pendingWeapon = id
      launching = true
      doorAnimationEnabled = true
      doorsOpen = false
      launchTimer.restart()
    } else {
      close()
      if (arena) Qt.callLater(function() { arena.arm(id) })
    }
  }
  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function") return bar.switchPanelFrom(barIdentity, direction)
    return false
  }

  component WeaponCard: Rectangle {
    id: card
    required property string weaponId
    required property string title
    required property string subtitle
    required property url artSource
    required property rect artClip
    property var ui
    width: parent ? (parent.width - Style.space(10)) / 2 : Style.space(145)
    // The cabinet scrolls when its contents exceed the display height.
    height: Style.space(94)
    radius: Style.cornerRadius
    color: hover.containsMouse ? Qt.rgba(ui.accent.r, ui.accent.g, ui.accent.b, 0.16) : Qt.rgba(ui.foreground.r, ui.foreground.g, ui.foreground.b, 0.055)
    border.width: 1
    border.color: hover.containsMouse ? ui.accent : Qt.rgba(ui.foreground.r, ui.foreground.g, ui.foreground.b, 0.15)

    Column {
      anchors.centerIn: parent
      spacing: Style.space(5)
      Image {
        visible: card.weaponId !== "lightsaber"
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(card.width - Style.space(24), card.artClip.width * 1.5)
        height: Style.space(40)
        source: card.artSource
        sourceClipRect: card.artClip
        fillMode: Image.PreserveAspectFit
        smooth: false
      }
      Loader {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(card.width - Style.space(24), 115)
        height: Style.space(40)
        active: card.weaponId === "lightsaber"
        visible: active
        sourceComponent: LightsaberArt {}
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: card.title
        color: card.ui.foreground
        font.family: card.ui.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
      // In Fly Hunt the card shows the score to beat with this weapon.
      Text {
        readonly property var best: card.ui.mode === "hunt" ? card.ui.bests[card.weaponId] : null
        anchors.horizontalCenter: parent.horizontalCenter
        text: card.ui.mode !== "hunt" ? card.subtitle : best ? "Best " + best.score : "No score yet"
        color: best ? card.ui.accent : Qt.rgba(card.ui.foreground.r, card.ui.foreground.g, card.ui.foreground.b, 0.55)
        font.bold: !!best
        font.family: card.ui.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
    // In Fly Hunt, the medal this weapon's best has earned sits in the corner.
    Medal {
      rank: card.ui.medalRank(card.weaponId)
      visible: rank >= 0
      anchors.left: parent.left; anchors.bottom: parent.bottom
      anchors.margins: Style.space(6)
      width: Style.space(14); height: width
    }
    MouseArea {
      id: hover
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: card.ui.playWeaponHover()
      onClicked: card.ui.choose(card.weaponId)
    }
  }

  // Tabs and mode buttons hover like the weapon cards: an accent outline and the hover sound.
  component MenuButton: Rectangle {
    id: menuButton
    property var ui
    property bool selected: false
    readonly property bool hovered: menuHover.containsMouse
    signal clicked()
    radius: Style.cornerRadius
    color: selected ? Qt.rgba(ui.accent.r, ui.accent.g, ui.accent.b, 0.22)
      : hovered ? Qt.rgba(ui.accent.r, ui.accent.g, ui.accent.b, 0.16)
      : Qt.rgba(ui.foreground.r, ui.foreground.g, ui.foreground.b, 0.045)
    border.width: selected ? 2 : 1
    border.color: selected || hovered ? ui.accent : Qt.rgba(ui.foreground.r, ui.foreground.g, ui.foreground.b, 0.16)
    MouseArea {
      id: menuHover
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: menuButton.ui.playWeaponHover()
      onClicked: menuButton.clicked()
    }
  }

  component SectionTitle: Text {
    property var ui
    color: Qt.rgba(ui.foreground.r, ui.foreground.g, ui.foreground.b, 0.55)
    font.family: ui.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    font.letterSpacing: 1.5
  }

  component WardrobeDoor: Rectangle {
    id: door
    required property bool leftDoor
    width: parent.width / 2
    height: parent.height
    x: root.doorsOpen ? (leftDoor ? -width : parent.width) : (leftDoor ? 0 : parent.width - width)
    z: 20
    color: leftDoor
      ? Qt.darker(root.accent, 1.55)
      : Qt.darker(root.accent, 1.75)
    border.width: 3
    border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.48)

    Behavior on x {
      enabled: root.doorAnimationEnabled
      NumberAnimation { duration: root.launching ? 260 : 1050; easing.type: Easing.InOutCubic }
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: Style.space(10)
      color: "transparent"
      border.width: 2
      border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.30)
      radius: 3
    }

    Repeater {
      model: 4
      Rectangle {
        required property int index
        x: (index + 1) * door.width / 5
        y: Style.space(13)
        width: 1
        height: door.height - Style.space(26)
        color: index % 2
          ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)
          : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)
      }
    }

    Rectangle {
      width: Style.space(10)
      height: Style.space(10)
      radius: width / 2
      x: door.leftDoor ? door.width - width - Style.space(9) : Style.space(9)
      anchors.verticalCenter: parent.verticalCenter
      color: root.accent
      border.width: 2
      border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.65)
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
      hoverEnabled: true
      cursorShape: Qt.ArrowCursor
    }
  }

  Timer {
    id: launchTimer
    interval: 280
    repeat: false
    onTriggered: {
      var id = root.pendingWeapon
      root.pendingWeapon = ""
      root.launching = false
      root.controller.hide()
      if (root.arena) Qt.callLater(function() { root.arena.arm(id) })
    }
  }

  RemoteSound {
    audio: root.arena ? root.arena.audio : null
    id: weaponHoverSound
    source: Qt.resolvedUrl("sounds/weapon-hover.wav")
    volume: 0.22
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: cabinetScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
          id: content
          width: parent.width
          spacing: Style.space(12)
          // Title and tagline sit close together, apart from the sections below.
          Column {
            width: parent.width
            spacing: Style.space(2)
            Item {
              width: parent.width
              height: Math.max(title.implicitHeight, soundButton.height)
              Text {
                id: title
                anchors.centerIn: parent
                text: "BLOW OFF SOME STEAM"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                font.bold: true
                font.letterSpacing: 1.5
              }
              // Sound on/off; remembered between sessions.
              MenuButton {
                id: soundButton
                objectName: "soundButton"
                ui: root
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(28); height: Style.space(28)
                Accessible.name: root.soundMuted ? "Turn sound on" : "Mute sound"
                onClicked: root.toggleSound()
                Text {
                  anchors.centerIn: parent
                  text: root.soundMuted ? "󰖁" : "󰕾"
                  color: root.soundMuted ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.5) : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.heading
                }
              }
            }
            // The tagline never changes; each section says what to do in it.
            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              text: "Stress relief, now with\nrockets and lightsabers"
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.55)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
          Row {
            width: parent.width; spacing: Style.space(8)
            Repeater {
              model: ["Play", "High scores"]
              delegate: MenuButton {
                required property int index
                required property string modelData
                ui: root
                selected: root.recordsTab === (index === 1)
                width: (parent.width - Style.space(8)) / 2; height: Style.space(32)
                onClicked: { root.recordsTab = index === 1; cabinetScroll.contentY = 0 }
                Text { anchors.centerIn: parent; text: modelData; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              }
            }
          }
          SectionTitle { ui: root; text: "BEST FLY HUNT PER WEAPON"; visible: root.recordsTab }
          // One row per weapon; the full history stays in the records file.
          Column {
            id: highScores
            width: parent.width; spacing: Style.space(6); visible: root.recordsTab
            Text {
              width: parent.width; wrapMode: Text.WordWrap
              visible: !!(root.arena && root.arena.flyRecords.error)
              text: visible ? root.arena.flyRecords.error : ""
              color: Color.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.caption
            }
            Repeater {
              // Highest score first; weapons without a completed hunt keep case order below.
              model: root.weaponTitles.slice().sort(function(a, b) {
                var sa = root.bests[a.id] ? root.bests[a.id].score : -1
                var sb = root.bests[b.id] ? root.bests[b.id].score : -1
                return sb - sa || root.weaponTitles.indexOf(a) - root.weaponTitles.indexOf(b)
              })
              delegate: Rectangle {
                id: scoreRow
                required property var modelData
                required property int index
                readonly property var best: root.bests[modelData.id] || null
                readonly property bool champion: !!best && index === 0
                width: parent.width; height: Style.space(44)
                radius: Style.cornerRadius
                color: champion ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.14) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
                border.width: 1
                border.color: champion ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                Column {
                  anchors.left: parent.left; anchors.leftMargin: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  Text { text: scoreRow.modelData.title; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
                  Text {
                    text: scoreRow.best ? scoreRow.best.kills + " flies · " + new Date(scoreRow.best.date).toLocaleDateString(Qt.locale(), Locale.ShortFormat) : "No completed hunt yet"
                    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.5)
                    font.family: root.fontFamily; font.pixelSize: Math.max(9, Style.font.caption - 2)
                  }
                }
                Text {
                  anchors.right: parent.right; anchors.rightMargin: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  text: scoreRow.best ? scoreRow.best.score : "—"
                  color: scoreRow.best ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.35)
                  font.family: root.fontFamily; font.pixelSize: Style.font.heading; font.bold: true
                }
              }
            }
          }
          SectionTitle { ui: root; text: "GAME MODE"; visible: !root.recordsTab }
          // One game mode at a time, chosen before the weapon.
          Grid {
            id: modeGrid
            visible: !root.recordsTab
            width: parent.width
            columns: 2; spacing: Style.space(8)
            Repeater {
              model: root.modes
              delegate: MenuButton {
                id: modeButton
                required property var modelData
                ui: root
                selected: root.mode === modelData.id
                width: (modeGrid.width - modeGrid.spacing) / 2; height: Style.space(42)
                onClicked: if (root.arena) root.arena.setMode(modelData.id)
                Column {
                  anchors.centerIn: parent
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: modeButton.modelData.label; color: modeButton.selected ? root.accent : root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: modeButton.modelData.detail; color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.5); font.family: root.fontFamily; font.pixelSize: Math.max(9, Style.font.caption - 2) }
                }
              }
            }
          }
          Row {
            visible: !root.recordsTab
            spacing: Style.space(6)
            SectionTitle { ui: root; text: "ARMORY" }
            Text {
              anchors.baseline: parent.children[0].baseline
              text: "· " + (root.mode === "hunt" ? "pick one to hunt with" : "pick your troublemaker")
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.42)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
          Item {
            id: wardrobe
            visible: !root.recordsTab
            width: parent.width
            height: weaponGrid.implicitHeight + Style.space(20)
            clip: true

            Rectangle {
              anchors.fill: parent
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.045)
              border.width: 4
              border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.42)
              radius: 5
            }

            Column {
              id: weaponGrid
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(8)

              Row {
                width: parent.width
                spacing: Style.space(10)
                WeaponCard { ui: root; weaponId: "glock"; title: "GLOCK P80"; subtitle: "quick single shots"; artSource: Qt.resolvedUrl("assets/glock-p80.png"); artClip: Qt.rect(18, 8, 30, 20) }
                WeaponCard { ui: root; weaponId: "revolver"; title: "COLT 45"; subtitle: "punches through"; artSource: Qt.resolvedUrl("assets/revolver-colt45.png"); artClip: Qt.rect(2, 11, 45, 18) }
              }
              Row {
                width: parent.width
                spacing: Style.space(10)
                WeaponCard { ui: root; weaponId: "ak47"; title: "AK-47"; subtitle: "full auto, climbs"; artSource: Qt.resolvedUrl("assets/ak47.png"); artClip: Qt.rect(3, 5, 76, 22) }
                WeaponCard { ui: root; weaponId: "mp5a3"; title: "MP5A3"; subtitle: "3-round bursts"; artSource: Qt.resolvedUrl("assets/mp5a3.png"); artClip: Qt.rect(3, 3, 57, 27) }
              }
              Row {
                width: parent.width
                spacing: Style.space(10)
                WeaponCard { ui: root; weaponId: "bazooka"; title: "M20"; subtitle: "boom + shockwave"; artSource: Qt.resolvedUrl("assets/bazooka-m20.png"); artClip: Qt.rect(3, 7, 112, 24) }
                WeaponCard { ui: root; weaponId: "lightsaber"; title: "LIGHTSABER"; subtitle: "hold to ignite"; artSource: ""; artClip: Qt.rect(0, 0, 96, 24) }
              }
            }

            WardrobeDoor { leftDoor: true }
            WardrobeDoor { leftDoor: false }

            Rectangle {
              anchors.fill: parent
              z: 30
              color: "transparent"
              border.width: 4
              border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.34)
              radius: 5
            }
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.recordsTab ? "Saved on this device · completed rounds only" : "Esc or right-click the bar icon to holster"
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.42)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
