const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const rules = vm.createContext({});
vm.runInContext(fs.readFileSync(require('node:path').join(__dirname, '../FlyRound.js'), 'utf8'), rules);
const start = 10000;
let round = rules.fresh(start, 'glock');
assert.equal(round.weapon, 'glock');
assert.equal(rules.fresh(start, 'ray-pistol').weapon, null);
const roundMs = rules.roundSeconds * 1000;
assert.equal(rules.roundSeconds, 40);
assert.equal(rules.remaining(round, start), 40);
assert.equal(rules.remaining(round, start + roundMs - 1), 1);
assert.equal(rules.remaining(round, start + roundMs), 0);
for (let i = 0; i < 7; i++) rules.kill(round, start + i * 100);
assert.equal(round.score, 2500); // 100 + 200 + 300 + 400 + 500 + 500 + 500
assert.equal(round.bestCombo, 5);
rules.kill(round, start + 1500); // Exactly the 0.9 s window at ×5 still chains.
assert.equal(round.combo, 5);
rules.kill(round, start + 2401); // 0.901 s later breaks it.
assert.equal(round.combo, 1);
assert.equal(rules.finish(round, start + roundMs - 1), null);
const before = round.score;
assert.equal(rules.kill(round, start + roundMs), false);
assert.equal(round.score, before);
const result = rules.finish(round, start + roundMs);
assert.equal(result.score, before);
assert.equal(result.kills, 9);
assert.equal(result.weapon, 'glock');
assert.equal(result.seconds, 40);
assert.deepEqual([...result.weapons], ['glock']);
assert.equal(rules.finish(round, start + roundMs + 1), null);
assert.equal(rules.kill(round, start + roundMs + 1), false);
round = rules.fresh(start + roundMs + 1000, 'bazooka');
assert.equal(round.score, 0);
assert.equal(round.bestCombo, 0);
for (let i = 0; i < 4; i++) rules.kill(round, start + roundMs + 1001); // Rocket multi-kill.
assert.equal(round.score, 1000);
const records = rules.restore(JSON.stringify({version: 1, records: [result]}));
assert.equal(JSON.stringify(records[0]), JSON.stringify(result));
assert.throws(() => rules.restore('broken'));
assert.throws(() => rules.restore('{"version":2,"records":[]}'));
assert.equal(rules.restore(JSON.stringify({version: 1, records: [{...result, score: -100}]})).length, 0);
assert.equal(rules.restore(JSON.stringify({version: 1, records: [{...result, weapon: 'laser-cannon'}]}))[0].weapon, undefined);
const windows = rules.fresh(0, 'glock');
rules.kill(windows, 0);
rules.kill(windows, 1800); // ×1 allows 1.8 s.
assert.equal(windows.combo, 2);
rules.kill(windows, 3301); // ×2 allows only 1.5 s.
assert.equal(windows.combo, 1);
// Each weapon keeps its own top 20, so a favourite cannot evict another weapon's best.
const saber = Array.from({length: 30}, (_, i) => ({...result, weapon: 'lightsaber', weapons: ['lightsaber'], score: 10000 + i}));
const kept = rules.ranked(saber.concat([{...result, score: 5}]));
assert.equal(kept.length, 21);
assert.equal(kept[0].score, 10029);
assert.equal(kept[20].weapon, 'glock');
// Bests per weapon; rounds without a weapon field count only when they used a single weapon.
const legacy = rules.restore(JSON.stringify({version: 1, records: [
  {score: 900, kills: 9, bestCombo: 2, weapons: ['ak47'], seconds: 40, date: '2026-10-04T15:00:00Z'},
  {score: 5000, kills: 50, bestCombo: 5, weapons: ['revolver', 'ak47'], seconds: 40, date: '2026-10-04T15:00:00Z'},
  {score: 4000, kills: 40, bestCombo: 5, weapons: [], seconds: 40, date: '2026-10-04T15:00:00Z'},
  {score: 700, kills: 7, bestCombo: 2, weapons: ['ray-pistol', 'glock'], seconds: 40, date: '2026-10-04T15:00:00Z'},
  // Rounds from the old 60-second length stay in the file but never count as bests.
  {score: 52000, kills: 106, bestCombo: 5, weapons: ['lightsaber'], date: '2026-10-04T15:59:23.686Z'},
  {score: 9000, kills: 90, bestCombo: 5, weapons: ['glock'], weapon: 'glock', seconds: 60, date: '2026-10-04T15:00:00Z'},
  {...result, score: 800},
  {...result, score: 300},
]}));
assert.equal(legacy.length, 8);
const bests = rules.bests(legacy);
assert.deepEqual(Object.keys(bests).sort(), ['ak47', 'glock'], 'only 40-second rounds count');
assert.equal(bests.ak47.score, 900);
assert.equal(bests.glock.score, 800);
// A golden fly triples the kill at its combo and still feeds the combo.
const golden = rules.fresh(0, 'glock');
rules.kill(golden, 0);
rules.kill(golden, 100, true);
assert.equal(golden.score, 100 + 600);
assert.equal(golden.combo, 2);
// Medals: each weapon has its own ladder; below bronze is -1.
assert.equal(rules.medal('glock', 3999), -1);
assert.equal(rules.medal('glock', 4000), 0);
assert.equal(rules.medal('glock', 20000), 3);
assert.equal(rules.medal('ray-pistol', 99999), -1);
for (const id of rules.weaponIds) {
  const ladder = rules.medalScores[id];
  assert.equal(ladder.length, 4, id);
  assert.ok(ladder.every((score, i) => i === 0 || score > ladder[i - 1]), id + ' ladder climbs');
}
assert.deepEqual({...rules.nextMedal('ak47', 20800)}, {medal: 2, name: 'Gold', score: 24000});
assert.equal(rules.nextMedal('ak47', 1).name, 'Bronze');
assert.equal(rules.nextMedal('ak47', 40000), null);
console.log('Fly Hunt rules: scoring, combos, golden flies, medals, cutoff, multi-kills, replay, per-weapon records passed.');
