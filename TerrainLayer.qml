import QtQuick

Item {
  id: terrain
  required property var arena
  readonly property int tileSize: 256
  readonly property int columns: Math.ceil(width / tileSize)
  readonly property int rows: Math.ceil(height / tileSize)
  property int readyTiles: 0
  property int tileCount: 0

  function rebuild() {
    tileCount = 0
    readyTiles = 0
    arena.terrainReady = false
    arena.paintedCarveCount = 0
    Qt.callLater(populate)
  }
  function populate() {
    tileCount = columns * rows
    applyDamage(Qt.rect(0, 0, width, height))
  }
  onWidthChanged: rebuild()
  onHeightChanged: rebuild()

  function applyDamage(dirtyArea) {
    // Dispatch each new mark once. Tile queues own their references, so
    // pruning a fallen region cannot skip marks still awaiting a paint.
    for (var i = arena.paintedCarveCount; i < arena.carveMarks.length; i++) {
      var mark = arena.carveMarks[i]
      var left = Math.max(0, Math.floor(Math.max(mark.clipX, mark.x - mark.radius - 1) / tileSize))
      var top = Math.max(0, Math.floor(Math.max(mark.clipY, mark.y - mark.radius - 1) / tileSize))
      var right = Math.min(columns - 1, Math.floor(Math.min(mark.clipX + mark.clipWidth, mark.x + mark.radius + 1) / tileSize))
      var bottom = Math.min(rows - 1, Math.floor(Math.min(mark.clipY + mark.clipHeight, mark.y + mark.radius + 1) / tileSize))
      for (var row = top; row <= bottom; row++) {
        for (var column = left; column <= right; column++) {
          var tile = tiles.itemAt(row * columns + column)
          if (tile) {
            tile.pending.push(mark)
            tile.requestPaint()
          }
        }
      }
    }
    arena.paintedCarveCount = arena.carveMarks.length
  }

  Repeater {
    id: tiles
    model: terrain.tileCount
    delegate: Canvas {
      id: tile
      required property int index
      property bool initialized: false
      property var pending: []
      x: (index % terrain.columns) * terrain.tileSize
      y: Math.floor(index / terrain.columns) * terrain.tileSize
      width: Math.min(terrain.tileSize, terrain.width - x)
      height: Math.min(terrain.tileSize, terrain.height - y)
      renderStrategy: Canvas.Immediate
      Component.onCompleted: loadImage(String(arena.desktopSnapshot))
      onImageLoaded: requestPaint()
      onPaint: {
        var source = String(arena.desktopSnapshot)
        if (!arena.armed || !isImageLoaded(source)) return
        var c = getContext("2d")
        if (!initialized) {
          c.reset()
          c.clearRect(0, 0, width, height)
          c.translate(-x, -y)
          c.drawImage(source, 0, 0, terrain.width, terrain.height)
        }
        c.globalCompositeOperation = "destination-out"
        for (var i = 0; i < pending.length; i++) {
          var mark = pending[i]
          c.save()
          c.beginPath()
          c.rect(mark.clipX, mark.clipY, mark.clipWidth, mark.clipHeight)
          c.clip()
          c.beginPath()
          c.arc(mark.x, mark.y, mark.radius, 0, Math.PI * 2)
          c.fill()
          c.restore()
        }
        pending = []
        c.globalCompositeOperation = "source-over"
        if (!initialized) {
          initialized = true
          terrain.readyTiles++
          if (terrain.readyTiles === tiles.count) {
            arena.terrainNeedsReset = false
            arena.terrainReady = true
          }
        }
      }
    }
  }

  Component.onCompleted: rebuild()
}
