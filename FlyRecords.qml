import QtQuick
import Quickshell
import Quickshell.Io
import "FlyRound.js" as Rules

Item {
  id: root
  visible: false
  property var records: []
  // Best completed round per weapon id, for the weapon cards and high scores.
  readonly property var bests: Rules.bests(records)
  property var pending: []
  property bool ready: false
  property string error: ""
  readonly property string stateRoot: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/blow-off-some-steam"
  function load(content) {
    if (ready) return
    var saved = []
    if (content.length) {
      try { saved = Rules.restore(content) }
      catch (e) { error = "Saved records could not be read." }
    }
    records = Rules.ranked(saved.concat(pending))
    ready = true
    if (pending.length) flush()
    pending = []
  }
  function add(record) {
    records = Rules.ranked(records.concat([record]))
    if (!ready) pending = pending.concat([record])
    else flush()
  }
  function flush() {
    if (ready) file.setText(JSON.stringify({ version: 1, records: records }) + "\n")
  }
  // Same cleared, fixed environment as the other desktop helpers.
  DesktopProcess {
    id: directory
    command: ["/usr/bin/mkdir", "-p", "--", root.stateRoot]
    onExited: function(code) {
      if (code === 0) file.path = root.stateRoot + "/fly-records.json"
      else root.error = "Records cannot be saved on this device."
    }
  }
  FileView {
    id: file
    path: ""
    atomicWrites: true
    printErrors: false
    onLoaded: root.load(text())
    onLoadFailed: { if (path.length) root.load("") }
    onSaveFailed: root.error = "Records could not be saved."
  }
  Component.onCompleted: directory.running = true
}
