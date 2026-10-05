const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const geometry = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../CutGeometry.js'), 'utf8'), geometry);
const square = geometry.rect(0, 0, 100, 100);
assert.equal(geometry.area(square), 10000);
assert(geometry.contains(square, 50, 50));
assert(!geometry.contains(square, 150, 50));
assert(geometry.contains([...square].reverse(), 50, 50), 'winding does not matter');
// A diagonal cut through opposite corners halves the window.
let [left, right] = geometry.split(square, {x: 0, y: 0}, {x: 100, y: 100});
assert.equal(geometry.area(left) + geometry.area(right), 10000);
assert.equal(geometry.area(left), 5000);
// Cutting off a corner leaves a small triangle and a pentagon.
[left, right] = geometry.split(square, {x: 80, y: 0}, {x: 100, y: 20});
const pieces = [left, right].sort((a, b) => geometry.area(a) - geometry.area(b));
assert.equal(geometry.area(pieces[0]), 200);
assert.equal(pieces[1].length, 5);
assert(!geometry.contains(pieces[1], 95, 2), 'the cut-off corner is gone');
// A line that misses leaves one side empty.
[left, right] = geometry.split(square, {x: 200, y: 0}, {x: 200, y: 100});
assert.equal(Math.min(left.length, right.length), 0);
// Segment clipping finds entry and exit along the tip path.
const hit = geometry.clipLine(square, -50, 50, 1, 0, 0, 200);
assert.equal(hit.enter, 50); assert.equal(hit.exit, 150);
assert.equal(geometry.clipLine(square, -50, 150, 1, 0, 0, 200), null);
assert.equal(geometry.clipLine(square, -50, 50, 1, 0, 0, 20), null, 'a short segment outside misses');
// Rays respect earlier cuts: after removing the right half, a ray from the right enters at x = 50.
const half = geometry.split(square, {x: 50, y: 0}, {x: 50, y: 100}).find((p) => geometry.contains(p, 25, 50));
const ray = geometry.clipLine(half, 300, 50, -1, 0, 0, Infinity);
assert.equal(300 - ray.enter, 50);
const box = geometry.bounds(pieces[0]);
assert.deepEqual([box.x, box.y, box.width, box.height], [80, 0, 20, 20]);
console.log('Cut geometry: areas, containment, splits, misses, and line clipping passed.');
