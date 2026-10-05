import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io

Scope {
  id: root
  property var voices: ({})
  function reply(message) { connection.write(JSON.stringify(message) + '\n'); connection.flush() }
  // Qt 6.11: a playing SoundEffect at volume 0 (or muted) silences every other
  // effect in the process until it is raised again; it cut the start of the
  // saber ignition. -80 dB is inaudible and keeps the mix alive.
  function audible(volume, music) { return music ? Math.max(0, volume) : Math.max(0.0001, volume) }
  function state(key, voice) { reply({event: 'state', key: key, status: voice.status, playing: voice.playing}) }
  function receive(line) {
    var message
    try { message = JSON.parse(line) } catch (error) { return }
    if (!message || typeof message !== 'object' || Array.isArray(message)) return
    if (message.op === 'ping') { reply({event: 'pong'}); return }
    var key = message.key
    if (typeof key !== 'string' || !/^voice-[0-9]{1,26}$/.test(key)) return
    if (message.op === 'create' || message.op === 'update') {
      if (typeof message.volume !== 'number' || !isFinite(message.volume)
          || message.volume < 0 || message.volume > 1
          || !Number.isInteger(message.loops) || message.loops < -2 || message.loops > 1000) return
    }
    if (message.op === 'create') {
      if (voices[key] || Object.keys(voices).length >= 64) return
      // Only packaged audio can be opened; the bridge never accepts arbitrary media commands.
      var prefix = String(Qt.resolvedUrl('sounds/'))
      if (typeof message.music !== 'boolean' || typeof message.source !== 'string'
          || !message.source.startsWith(prefix)
          || !/^[A-Za-z0-9][A-Za-z0-9_-]*\.(wav|mp3)$/.test(message.source.slice(prefix.length))) return
      var component = message.music ? musicVoice : effectVoice
      voices[key] = component.createObject(root, {voiceKey: key, source: message.source, volume: audible(message.volume, message.music), loops: message.loops})
      if (voices[key]) state(key, voices[key])
      return
    }
    var voice = voices[key]
    if (!voice) return
    if (message.op === 'play') voice.play()
    else if (message.op === 'stop') voice.stop()
    else if (message.op === 'update') { voice.volume = audible(Math.min(1, message.volume), voice.isMusic); voice.loops = message.loops }
    else if (message.op === 'remove') { voice.stop(); voice.destroy(); delete voices[key] }
  }
  Socket {
    id: connection
    path: Quickshell.env('STEAM_AUDIO_SOCKET')
    connected: true
    onConnectionStateChanged: {
      if (connected) root.reply({event: 'ready'})
      else Qt.quit()
    }
    parser: SplitParser { onRead: line => root.receive(line) }
  }
  Component {
    id: effectVoice
    SoundEffect {
      readonly property bool isMusic: false
      property string voiceKey
      onStatusChanged: root.state(voiceKey, this)
      onPlayingChanged: root.state(voiceKey, this)
    }
  }
  Component {
    id: musicVoice
    Item {
      id: music
      readonly property bool isMusic: true
      property string voiceKey
      property alias source: player.source
      property alias volume: output.volume
      property alias loops: player.loops
      readonly property bool playing: player.playing
      readonly property int status: player.error !== MediaPlayer.NoError ? 3 : player.mediaStatus === MediaPlayer.LoadedMedia || player.mediaStatus === MediaPlayer.BufferedMedia ? 2 : 1
      function play() { player.play() }
      function stop() { player.stop() }
      onStatusChanged: root.state(voiceKey, music)
      onPlayingChanged: root.state(voiceKey, music)
      MediaPlayer { id: player; audioOutput: AudioOutput { id: output } }
    }
  }
}
