import QtQuick

Item {
  id: sound
  enum Status { Null, Loading, Ready, Error }
  enum LoopCount { Infinite = -2 }
  property var audio: null
  property var registeredAudio: null
  property bool complete: false
  property url source
  property real volume: 1
  property int loops: 1
  property bool music: false
  property bool playing: false
  property int status: 0
  property string key: ''
  property bool playWhenRegistered: false
  function definition(id) { return {op: 'create', key: id, source: String(source), volume: volume, loops: loops, music: music} }
  function play() {
    if (key) audio.command({op: 'play', key: key})
    else playWhenRegistered = true
  }
  function stop() {
    playWhenRegistered = false
    if (key) audio.command({op: 'stop', key: key})
  }
  function update() { if (key) audio.command({op: 'update', key: key, volume: volume, loops: loops}) }
  onVolumeChanged: update()
  onLoopsChanged: update()
  function attach() {
    if (!complete || audio === registeredAudio) return
    if (registeredAudio && key) registeredAudio.unregisterVoice(key)
    registeredAudio = audio
    key = audio ? audio.registerVoice(sound) : ''
    if (key && playWhenRegistered) { playWhenRegistered = false; play() }
  }
  onAudioChanged: attach()
  Component.onCompleted: { complete = true; attach() }
  Component.onDestruction: if (registeredAudio && key) registeredAudio.unregisterVoice(key)
}
