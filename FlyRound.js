// Shared rules for a completed, forty-second Fly Hunt played with one weapon.
var weaponIds = ["glock", "revolver", "ak47", "mp5a3", "bazooka", "lightsaber"]
var roundSeconds = 40
function fresh(now, weapon) {
  return { deadline: now + roundSeconds * 1000, score: 0, kills: 0, combo: 0, bestCombo: 0,
           lastKill: null, weapon: weaponIds.indexOf(weapon) >= 0 ? weapon : null, finished: false }
}
// Time allowed after a kill to keep the combo going; it tightens at each step
// so ×5 takes a steady stream of kills to hold.
var comboWindows = [1800, 1800, 1500, 1250, 1050, 900]
function comboWindow(combo) { return comboWindows[Math.max(0, Math.min(5, combo))] }
function remaining(round, now) { return Math.max(0, Math.ceil((round.deadline - now) / 1000)) }
function kill(round, now) {
  if (round.finished || now >= round.deadline) return false
  round.combo = round.lastKill !== null && now - round.lastKill <= comboWindow(round.combo)
    ? Math.min(5, round.combo + 1) : 1
  round.lastKill = now
  round.kills++
  round.score += 100 * round.combo
  round.bestCombo = Math.max(round.bestCombo, round.combo)
  return true
}
function finish(round, now) {
  if (round.finished || now < round.deadline) return null
  round.finished = true
  var record = { score: round.score, kills: round.kills, bestCombo: round.bestCombo,
                 weapons: round.weapon ? [round.weapon] : [], date: new Date(now).toISOString() }
  if (round.weapon) record.weapon = round.weapon
  record.seconds = roundSeconds
  return record
}
// The weapon a record counts for. Only rounds of the current length count;
// older 60-second rounds stay in the file but are not comparable. Rounds
// from before the one-weapon rule count only if they used a single weapon.
function weaponOf(record) {
  if (record.seconds !== roundSeconds) return null
  if (record.weapon) return record.weapon
  return record.weapons.length === 1 ? record.weapons[0] : null
}
// Best record per weapon id; weapons without a completed round are absent.
function bests(records) {
  var best = {}
  for (var i = 0; i < records.length; i++) {
    var id = weaponOf(records[i])
    if (id && !best[id]) best[id] = records[i]
  }
  return best
}
// Highest first; each weapon keeps its own top 20, so one favourite weapon
// can never push another weapon's best out of the file.
function ranked(records) {
  var kept = {}
  return records.slice().sort(function(a, b) {
    return b.score - a.score || b.kills - a.kills || b.bestCombo - a.bestCombo || b.date.localeCompare(a.date)
  }).filter(function(record) {
    var id = weaponOf(record) || (record.seconds === roundSeconds ? "mixed" : "older")
    kept[id] = (kept[id] || 0) + 1
    return kept[id] <= 20
  })
}
function restore(text) {
  var data = JSON.parse(text)
  if (data.version !== 1 || !Array.isArray(data.records)) throw new Error("Invalid records")
  return ranked(data.records.filter(function(r) {
    return r && Number.isInteger(r.score) && r.score >= 0 && r.score <= 100000000
      && Number.isInteger(r.kills) && r.kills >= 0 && r.kills <= 1000000
      && Number.isInteger(r.bestCombo) && r.bestCombo >= 0 && r.bestCombo <= 5
      && typeof r.date === "string" && isFinite(Date.parse(r.date))
      && Array.isArray(r.weapons) && r.weapons.length <= 16
      && r.weapons.every(function(w) { return typeof w === "string" })
  }).map(function(r) {
    // Keep rounds that used a since-removed weapon; only drop the unknown name.
    var record = { score: r.score, kills: r.kills, bestCombo: r.bestCombo,
                   weapons: r.weapons.filter(function(w) { return weaponIds.indexOf(w) >= 0 }), date: r.date }
    if (weaponIds.indexOf(r.weapon) >= 0) record.weapon = r.weapon
    if (Number.isInteger(r.seconds) && r.seconds > 0 && r.seconds <= 600) record.seconds = r.seconds
    return record
  }))
}
