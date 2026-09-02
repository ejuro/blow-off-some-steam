import QtQuick
import QtMultimedia
import qs.Commons
import qs.Ui

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
  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: Color.accent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function open() {
    doorOpenTimer.stop()
    doorOpenSound.stop()
    doorAnimationEnabled = false
    doorsOpen = false
    root.controller.show()
    Qt.callLater(function() {
      doorAnimationEnabled = true
      doorOpenTimer.restart()
    })
  }
  function close() {
    doorOpenTimer.stop()
    doorOpenSound.stop()
    doorsOpen = false
    root.controller.hide()
  }
  function toggle() { if (root.opened) close(); else open() }
  function playWeaponHover() {
    weaponHoverSound.stop()
    weaponHoverSound.play()
  }
  function choose(id) {
    close()
    if (arena) Qt.callLater(function() { arena.arm(id) })
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
    // Keep all three weapon rows and the target toggle visible on shorter displays.
    height: Style.space(94)
    radius: Style.cornerRadius
    color: hover.containsMouse ? Qt.rgba(ui.accent.r, ui.accent.g, ui.accent.b, 0.16) : Qt.rgba(ui.foreground.r, ui.foreground.g, ui.foreground.b, 0.055)
    border.width: 1
    border.color: hover.containsMouse ? ui.accent : Qt.rgba(ui.foreground.r, ui.foreground.g, ui.foreground.b, 0.15)

    Column {
      anchors.centerIn: parent
      spacing: Style.space(5)
      Image {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(card.width - Style.space(24), card.artClip.width * 1.5)
        height: Style.space(40)
        source: card.artSource
        sourceClipRect: card.artClip
        fillMode: Image.PreserveAspectFit
        smooth: false
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: card.title
        color: card.ui.foreground
        font.family: card.ui.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: card.subtitle
        color: Qt.rgba(card.ui.foreground.r, card.ui.foreground.g, card.ui.foreground.b, 0.55)
        font.family: card.ui.fontFamily
        font.pixelSize: Style.font.caption
      }
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
      NumberAnimation { duration: 1050; easing.type: Easing.InOutCubic }
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
    id: doorOpenTimer
    interval: 45
    onTriggered: {
      root.doorsOpen = true
      doorOpenSound.stop()
      doorOpenSound.play()
    }
  }

  SoundEffect {
    id: weaponHoverSound
    source: Qt.resolvedUrl("sounds/weapon-hover.wav")
    volume: 0.22
  }

  SoundEffect {
    id: doorOpenSound
    source: Qt.resolvedUrl("sounds/doors-open.wav")
    volume: 0.30
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

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "BLOW OFF SOME STEAM"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.heading
          font.bold: true
          font.letterSpacing: 1.5
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Choose your harmless troublemaker"
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.55)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
        Item {
          id: wardrobe
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
              WeaponCard { ui: root; weaponId: "revolver"; title: "COLT 45"; subtitle: "heavy single shots"; artSource: Qt.resolvedUrl("assets/revolver-colt45.png"); artClip: Qt.rect(2, 11, 45, 18) }
            }
            Row {
              width: parent.width
              spacing: Style.space(10)
              WeaponCard { ui: root; weaponId: "ak47"; title: "AK-47"; subtitle: "hold for full auto"; artSource: Qt.resolvedUrl("assets/ak47.png"); artClip: Qt.rect(3, 5, 76, 22) }
              WeaponCard { ui: root; weaponId: "mp5a3"; title: "MP5A3"; subtitle: "fast full auto"; artSource: Qt.resolvedUrl("assets/mp5a3.png"); artClip: Qt.rect(3, 3, 57, 27) }
            }
            Row {
              width: parent.width
              spacing: Style.space(10)
              WeaponCard { ui: root; weaponId: "bazooka"; title: "M20"; subtitle: "one enormous boom"; artSource: Qt.resolvedUrl("assets/bazooka-m20.png"); artClip: Qt.rect(3, 7, 112, 24) }
              WeaponCard { ui: root; weaponId: "thick-bazooka"; title: "THICK M20"; subtitle: "maximum overkill"; artSource: Qt.resolvedUrl("assets/bazooka-m20-thick.png"); artClip: Qt.rect(35, 3, 112, 28) }
            }
            Rectangle {
              id: targetToggle
              width: parent.width
              height: Style.space(26)
              radius: Style.cornerRadius
              color: targetHover.containsMouse
                ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.09)
                : "transparent"
              border.width: 1
              border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)

              Row {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(6)
                Rectangle {
                  width: Style.space(14)
                  height: width
                  radius: Style.space(2)
                  color: root.arena && root.arena.targetsEnabled ? root.accent : "transparent"
                  border.width: 1
                  border.color: root.arena && root.arena.targetsEnabled
                    ? root.accent
                    : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.55)
                  Text {
                    anchors.centerIn: parent
                    text: "✓"
                    visible: root.arena && root.arena.targetsEnabled
                    color: "white"
                    font.pixelSize: Style.space(10)
                    font.bold: true
                  }
                }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Target practice"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              MouseArea {
                id: targetHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.arena) root.arena.setTargetsEnabled(!root.arena.targetsEnabled)
              }
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
          text: "Esc holsters · right-click the bar icon also quits"
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.42)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
