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
    // No path: the saved file was too large to read, so it is left alone.
    if (ready && file.path.length) file.setText(JSON.stringify({ version: 1, records: records }) + "\n")
  }
  readonly property string recordsPath: stateRoot + "/fly-records.json"
  // A normal file is a few kilobytes (the top 20 per weapon). One far bigger
  // is not read into the shell, nor overwritten, in case it matters to someone.
  readonly property int maximumBytes: 1048576
  // Same cleared, fixed environment as the other desktop helpers.
  DesktopProcess {
    id: directory
    command: ["/usr/bin/mkdir", "-p", "--", root.stateRoot]
    onExited: function(code) {
      if (code === 0) sizeCheck.running = true
      else root.error = "Records cannot be saved on this device."
    }
  }
  DesktopProcess {
    id: sizeCheck
    command: ["/usr/bin/stat", "-L", "-c", "%s", "--", root.recordsPath]
    stdout: StdioCollector { id: size; waitForEnd: true }
    onExited: function(code) {
      // No file yet (stat fails) is fine: FileView starts a new one.
      if (code === 0 && !(Number(size.text.trim()) <= root.maximumBytes)) {
        root.error = "Saved records are too large to read: " + root.recordsPath
        root.load("")
      } else file.path = root.recordsPath
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
