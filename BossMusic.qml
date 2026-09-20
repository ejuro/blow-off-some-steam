import QtQuick

Item {
  id: music
  required property var audio
  property bool ending: false
  readonly property bool playing: player.playing

  function fadeAway() {
    fadeIn.stop()
    fadeOut.restart()
  }
  onEndingChanged: if (ending) fadeAway()
  Component.onCompleted: player.play()
  Component.onDestruction: {
    fadeIn.stop(); fadeOut.stop(); player.stop()
  }

  RemoteSound {
    id: player
    audio: music.audio
    source: Qt.resolvedUrl("sounds/giant-wings.mp3")
    music: true
    loops: -1
    volume: 0
    onPlayingChanged: {
      if (playing) {
        if (music.ending) player.stop()
        else fadeIn.restart()
      }
    }
  }
  NumberAnimation {
    id: fadeIn
    target: player; property: "volume"
    to: 0.38; duration: 1600
    easing.type: Easing.InOutQuad
  }
  NumberAnimation {
    id: fadeOut
    target: player; property: "volume"
    to: 0; duration: 1200
    onFinished: player.stop()
  }
}
