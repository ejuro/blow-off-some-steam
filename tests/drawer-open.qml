import QtQuick
import Quickshell
import ".." as Steam
ShellRoot {
  QtObject {
    id: audio
    property bool failed: false
    property var voices: []
    property int plays: 0
    function registerVoice(voice) { voices.push(voice); return "voice-" + voices.length }
    function unregisterVoice(key) {}
    function command(message) { if (message.op === "play") plays++ }
  }
  QtObject { id: records; property var records: []; property var bests: ({}); property string error: "" }
  Item {
    id: fake
    property var audio: audio
    property var flyRecords: records
    property bool destructionEnabled: false
    property bool targetsEnabled: false
    property bool bugHuntEnabled: false
    property string mode: "free"
    property bool soundMuted: false
    function setSoundMuted(muted) { soundMuted = muted }
    function setMode(name) { mode = name }
    function weaponNames(ids) { return ids.join() }
  }
  Steam.WeaponCase { id: drawer; arena: fake }
  function check(ok, message) { if (!ok) throw new Error(message) }
  Timer {
    interval: 100; running: true
    onTriggered: {
      for (var i = 0; i < drawer.data.length; i++) {
        var object = drawer.data[i]
        if (typeof object.fittedContentWidth === "function") object.open = false
      }
      // Audio is cold and never becomes ready: the doors must not wait for it.
      drawer.open(); prompt.start()
    }
  }
  Timer { id: prompt; interval: 50; onTriggered: {
    check(drawer.opened && drawer.doorsOpen, "doors open promptly without audio")
    check(audio.plays === 0, "opening plays no sound")
    // The sound button mutes quietly and answers with a sound when turned back on.
    drawer.toggleSound()
    check(fake.soundMuted && audio.plays === 0, "muting plays nothing")
    drawer.toggleSound()
    check(!fake.soundMuted && audio.plays === 1, "unmuting plays the hover sound")
    drawer.close()
    check(!drawer.doorsOpen, "closing shuts the doors")
    // Fly Hunt shows each weapon's best on its card and in the high scores list.
    records.bests = { lightsaber: { score: 52000, kills: 106, bestCombo: 5, date: "2026-10-04T15:59:23.686Z", weapons: ["lightsaber"] } }
    fake.setMode("hunt")
    drawer.recordsTab = true
    drawer.open(); drawer.close(); late.start()
  } }
  Timer { id: late; interval: 50; onTriggered: {
    check(!drawer.opened && !drawer.doorsOpen, "a quick open and close leaves the doors shut")
    console.log("DRAWER_OPEN_OK"); Qt.quit()
  } }
}
