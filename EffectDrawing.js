// Preserve the original Canvas geometry and source-over drawing order.
function particle(c, p, i) {
  if (p.kind === 1) {
    c.fillStyle = i % 3 === 0 ? "#ff4d2e" : (i % 2 === 0 ? "#ffd24a" : "#ff8a2a")
    c.beginPath(); c.arc(p.x, p.y, p.size * p.life, 0, Math.PI * 2); c.fill()
  } else if (p.kind === 3) {
    var rocketAngle = Math.atan2(p.vy, p.vx)
    c.save()
    c.translate(p.x, p.y)
    c.rotate(rocketAngle)
    c.fillStyle = "#ffb52e"
    c.beginPath(); c.moveTo(-22, 0); c.lineTo(-34, -7); c.lineTo(-30, 0); c.lineTo(-34, 7); c.closePath(); c.fill()
    c.fillStyle = "#d7d9d2"
    c.fillRect(-18, -3, 25, 6)
    c.fillStyle = "#79806f"
    c.beginPath(); c.moveTo(12, 0); c.lineTo(5, -5); c.lineTo(5, 5); c.closePath(); c.fill()
    c.restore()
  } else if (p.kind === 4) {
    c.globalAlpha = Math.max(0, p.life) * 0.85
    c.strokeStyle = p.life > 0.55 ? "#fff4ad" : "#ff6a2b"
    c.lineWidth = Math.max(2, 14 * p.life)
    c.beginPath(); c.arc(p.x, p.y, p.maxRadius * (1 - p.life), 0, Math.PI * 2); c.stroke()
  } else if (p.kind === 5) {
    c.fillStyle = "#8fd8d5cc"
    c.beginPath(); c.arc(p.x, p.y, p.size * (1.3 - p.life), 0, Math.PI * 2); c.fill()
  } else if (p.kind === 6) {
    var bulletAngle = Math.atan2(p.vy, p.vx)
    c.save()
    c.translate(p.x, p.y)
    c.rotate(bulletAngle)
    c.fillStyle = "#efe0a4"
    c.fillRect(-p.size * 1.8, -p.size * 0.52, p.size * 2.3, p.size * 1.04)
    c.fillStyle = "#bf7b2d"
    c.beginPath()
    c.moveTo(p.size * 1.45, 0)
    c.lineTo(p.size * 0.45, -p.size * 0.52)
    c.lineTo(p.size * 0.45, p.size * 0.52)
    c.closePath()
    c.fill()
    c.restore()
  } else if (p.kind === 7) {
    c.fillStyle = "#9da2a0"
    c.beginPath(); c.arc(p.x, p.y, p.size * (1.35 - p.life * 0.35), 0, Math.PI * 2); c.fill()
  } else if (p.kind === 2) {
    c.fillStyle = "#d6a84b"
    c.save()
    c.translate(p.x, p.y)
    c.rotate(p.angle)
    c.fillRect(-p.size * 0.9, -p.size * 0.5, p.size * 1.8, p.size)
    c.restore()
  }
}
function flash(c, root) {
if (root.flash > 0) {
  var angle = root.aimAngle * Math.PI / 180
  var cosA = Math.cos(angle)
  var sinA = Math.sin(angle)
  var localX = (root.spec.muzzleX - root.spec.gripX) * root.spec.scale
  var localY = (root.spec.muzzleY - root.spec.gripY) * root.spec.scale * (root.aimFlipped ? -1 : 1)
  var mx = root.gunX - root.recoil * cosA + localX * cosA - localY * sinA
  var my = root.gunY - root.recoil * sinA + localX * sinA + localY * cosA
  c.globalAlpha = root.flash
  c.save()
  c.translate(mx, my)
  c.rotate(angle)
  if (root.spec.flashStyle === "revolver") {
    c.fillStyle = "#fff2a0"
    c.beginPath()
    c.moveTo(-5, 0); c.lineTo(9, -7); c.lineTo(13, -20); c.lineTo(19, -8)
    c.lineTo(38, -13); c.lineTo(27, 0); c.lineTo(39, 13); c.lineTo(18, 8)
    c.lineTo(12, 21); c.lineTo(8, 7); c.closePath(); c.fill()
    c.globalAlpha = root.flash * 0.8
    c.fillStyle = "#ff762b"
    c.beginPath(); c.moveTo(0, 0); c.lineTo(27, -6); c.lineTo(20, 0); c.lineTo(28, 6); c.closePath(); c.fill()
  } else {
    c.fillStyle = "#ffe86b"
    c.beginPath(); c.moveTo(0,0); c.lineTo(29,-10); c.lineTo(20,0); c.lineTo(33,9); c.closePath(); c.fill()
  }
  c.restore()
}
}
