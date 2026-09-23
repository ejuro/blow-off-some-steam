import QtQuick
import Quickshell.Io

Item {
  id: bridge
  property bool active: false
  property bool ready: false
  property bool failed: false
  property bool stopping: false
  property var voices: ({})
  property int serial: 0
  property var pending: []
  readonly property int workerPid: Number(worker.processId || 0)

  function registerVoice(voice) {
    var key = 'voice-' + (++serial)
    voices[key] = voice
    if (ready) send(voice.definition(key))
    return key
  }
  function unregisterVoice(key) {
    delete voices[key]
    pending = pending.filter(function(message) { return message.key !== key })
    if (ready) send({op: 'remove', key: key})
  }
  function send(message) {
    if (ready) worker.write(JSON.stringify(message) + '\n')
  }
  function command(message) {
    if (!active || failed) return
    if (ready) send(message)
    else if (pending.length < 128) pending.push(message)
  }
  function resetVoices() {
    Object.keys(voices).forEach(function(key) { voices[key].status = 0; voices[key].playing = false })
  }
  onActiveChanged: {
    if (active) {
      shutdownDelay.stop()
      failed = false
      if (!worker.running && !stopping) worker.running = true
    } else {
      pending = []
      Object.keys(voices).forEach(function(key) { send({op: 'stop', key: key}) })
      shutdownDelay.restart()
    }
  }
  Timer {
    id: shutdownDelay
    interval: 350
    onTriggered: {
      if (worker.running) { bridge.stopping = true; worker.running = false }
    }
  }
  Component.onDestruction: worker.running = false

  Process {
    id: worker
    command: ['/usr/bin/python3', '-I', '-S', decodeURIComponent(Qt.resolvedUrl('audio_worker.py').toString().replace(/^file:\/\//, ''))]
    // Clear before interpreter startup: filtering inside Python is too late for
    // loader/Python startup hooks. Only audio connection settings are inherited.
    clearEnvironment: true
    environment: ({
      PATH: '/usr/bin',
      LANG: 'C.UTF-8',
      XDG_RUNTIME_DIR: null,
      PIPEWIRE_RUNTIME_DIR: null,
      PULSE_SERVER: null
    })
    stdinEnabled: true
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var message = JSON.parse(line)
          if (!message || typeof message !== 'object' || Array.isArray(message)) return
          if (message.event === 'ready' && !bridge.stopping) {
            bridge.ready = true
            Object.keys(bridge.voices).forEach(function(key) { bridge.send(bridge.voices[key].definition(key)) })
            var queue = bridge.pending
            bridge.pending = []
            queue.forEach(function(item) { bridge.send(item) })
          } else if (message.event === 'state' && typeof message.key === 'string'
                     && Object.prototype.hasOwnProperty.call(bridge.voices, message.key)
                     && Number.isInteger(message.status) && message.status >= 0 && message.status <= 3
                     && typeof message.playing === 'boolean') {
            var voice = bridge.voices[message.key]
            voice.status = message.status
            voice.playing = message.playing
          }
        } catch (error) { /* Ignore incomplete or invalid worker output. */ }
      }
    }
    onExited: {
      bridge.ready = false
      bridge.resetVoices()
      if (bridge.stopping) {
        bridge.stopping = false
        if (bridge.active) { worker.running = true; return }
      }
      bridge.pending = []
      // Do not restart repeatedly if the audio backend crashes. A new session retries.
      if (bridge.active) bridge.failed = true
    }
  }
  Timer {
    interval: 1000
    repeat: true
    running: worker.running
    onTriggered: worker.write('{"op":"ping"}\n')
  }
}
