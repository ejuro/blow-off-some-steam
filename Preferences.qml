import QtQuick
import Quickshell
import Quickshell.Io

// Small settings that outlast the session, next to the Fly Hunt records.
Item {
  id: root
  visible: false
  property bool muted: false
  property bool ready: false
  property bool changedBeforeLoad: false
  readonly property string stateRoot: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/blow-off-some-steam"
  function load(content) {
    if (ready) return
    ready = true
    // A click that beat the file wins, and is saved now.
    if (changedBeforeLoad) { save(); return }
    try {
      var data = JSON.parse(content)
      if (data && data.version === 1 && typeof data.muted === "boolean") muted = data.muted
    } catch (e) { /* A missing or broken file keeps the defaults. */ }
  }
  function setMuted(value) {
    muted = value
    if (ready) save()
    else changedBeforeLoad = true
  }
  function save() { file.setText(JSON.stringify({ version: 1, muted: muted }) + "\n") }
  readonly property string settingsPath: stateRoot + "/settings.json"
  // Same cleared, fixed environment as the other desktop helpers.
  DesktopProcess {
    id: directory
    command: ["/usr/bin/mkdir", "-p", "--", root.stateRoot]
    onExited: function(code) { if (code === 0) sizeCheck.running = true }
  }
  // The file holds one switch. One much bigger than that is not read into
  // the shell; the defaults apply and the next change replaces it.
  DesktopProcess {
    id: sizeCheck
    command: ["/usr/bin/stat", "-L", "-c", "%s", "--", root.settingsPath]
    stdout: StdioCollector { id: size; waitForEnd: true }
    onExited: function(code) {
      if (code === 0 && !(Number(size.text.trim()) <= 4096)) {
        // Still the place to save to, but never read.
        file.preload = false
        root.load("")
      }
      file.path = root.settingsPath
    }
  }
  FileView {
    id: file
    path: ""
    atomicWrites: true
    printErrors: false
    onLoaded: root.load(text())
    onLoadFailed: { if (path.length) root.load("") }
  }
  Component.onCompleted: directory.running = true
}
