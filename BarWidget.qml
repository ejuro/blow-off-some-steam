import QtQuick
import Quickshell.Io
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.ejuro.blow-off-some-steam"

  readonly property bool opened: caseLoader.item ? caseLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: caseLoader.item ? caseLoader.item.popoutSwitchClosing === true : false

  function inject() {
    if (caseLoader.item) {
      caseLoader.item.bar = root.bar
      caseLoader.item.anchorItem = button
      caseLoader.item.hostWidget = root
      caseLoader.item.arena = arenaLoader.item
    }
  }
  function open() { if (caseLoader.item) caseLoader.item.open() }
  function close() { if (caseLoader.item) caseLoader.item.close() }
  function toggle() { if (caseLoader.item) caseLoader.item.toggle() }
  function closeForPopoutSwitch() { close() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: inject()

  Loader {
    id: arenaLoader
    active: true
    source: Qt.resolvedUrl("Arena.qml")
    visible: false
    onLoaded: root.inject()
  }

  Binding {
    target: arenaLoader.item
    property: "audioPreviewActive"
    value: root.opened
    when: !!arenaLoader.item
  }

  Loader {
    id: caseLoader
    active: true
    source: Qt.resolvedUrl("WeaponCase.qml")
    visible: false
    onLoaded: {
      root.inject()
      Qt.callLater(root.inject)
    }
  }

  IpcHandler {
    target: "io.github.ejuro.blow-off-some-steam"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function audioStatus(): string {
      var audio = arenaLoader.item ? arenaLoader.item.audio : null
      if (!audio) return JSON.stringify({active: false, ready: false})
      return JSON.stringify({active: audio.active, ready: audio.ready, failed: audio.failed,
        workerPid: audio.workerPid, voices: Object.keys(audio.voices).length,
        loaded: Object.keys(audio.voices).filter(function(key) { return audio.voices[key].status === RemoteSound.Ready }).length})
    }
    function holster(): void { if (arenaLoader.item) arenaLoader.item.holster() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰜃"
    tooltipText: arenaLoader.item && arenaLoader.item.armed
      ? "Blow off some steam · " + arenaLoader.item.weaponName + " armed · Esc to holster"
      : "Blow off some steam"
    active: arenaLoader.item ? arenaLoader.item.armed : false
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton && arenaLoader.item) arenaLoader.item.holster()
      else root.toggle()
    }
  }
}
