const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const geometry = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../CutGeometry.js'), 'utf8'), geometry);
const close = (a, b) => Math.abs(a - b) < 1e-6;
const square = geometry.rect(0, 0, 100, 100);
assert.equal(geometry.area(square), 10000);
assert(geometry.contains(square, 50, 50));
assert(!geometry.contains(square, 150, 50));
// Concave shapes: an L has a missing corner.
const ell = [{x: 0, y: 0}, {x: 100, y: 0}, {x: 100, y: 50}, {x: 50, y: 50}, {x: 50, y: 100}, {x: 0, y: 100}];
assert(geometry.contains(ell, 25, 75) && !geometry.contains(ell, 75, 75), 'concave containment');
// Holes are not solid.
const hole = geometry.rect(40, 40, 20, 20);
assert(geometry.solid([square, hole], 10, 10) && !geometry.solid([square, hole], 50, 50), 'holes');

// Crossings along a segment, in order, with the loop and edge they belong to.
const hits = geometry.crossings([square, hole], {x: -10, y: 50}, {x: 110, y: 50}, 0, 1);
assert.deepEqual([...hits.map((h) => h.loop)], [0, 1, 1, 0]);
assert(close(hits[1].x, 40) && close(hits[2].x, 60));
// Solid spans skip the hole: a shot from the left passes through it.
const spans = geometry.spans([square, hole], {x: -10, y: 50}, {x: 0, y: 50});
assert.equal(spans.length, 2);
assert(close(spans[0][0], 1) && close(spans[0][1], 5) && close(spans[1][0], 7) && close(spans[1][1], 11));
// A line through a shared corner counts it once.
assert.equal(geometry.crossings([square], {x: -50, y: -50}, {x: 150, y: 150}, -Infinity, Infinity).length, 2);

// Straight cut from the left edge to the right edge at y = 30.
const left = {edge: 3, u: 0.7}, right = {edge: 1, u: 0.3};
let [a, b] = geometry.splitAlong(square, [{x: 0, y: 30}, {x: 100, y: 30}], left, right);
assert.deepEqual([geometry.area(a), geometry.area(b)].sort((x, y) => x - y), [3000, 7000]);
// A curved cut that dips down and comes back out the top edge carves a bowl.
const bowl = [{x: 20, y: 0}, {x: 30, y: 40}, {x: 70, y: 40}, {x: 80, y: 0}];
[a, b] = geometry.splitAlong(square, bowl, {edge: 0, u: 0.2}, {edge: 0, u: 0.8});
const sizes = [geometry.area(a), geometry.area(b)].sort((x, y) => x - y);
assert(close(sizes[0] + sizes[1], 10000) && close(sizes[0], 2000), 'same-edge cut: ' + sizes);
// Entering and leaving the same edge the other way round.
[a, b] = geometry.splitAlong(square, bowl.slice().reverse(), {edge: 0, u: 0.8}, {edge: 0, u: 0.2});
assert(close(Math.min(geometry.area(a), geometry.area(b)), 2000));

// A path that crosses itself closes a loop.
const loop = [{x: 0, y: 0}, {x: 10, y: 0}, {x: 10, y: 10}, {x: 5, y: 10}, {x: 5, y: -5}];
const crossing = geometry.selfCrossing(loop);
assert(crossing && crossing.index === 0 && close(crossing.x, 5) && close(crossing.y, 0));
assert.equal(geometry.selfCrossing(loop.slice(0, 4)), null);
// A circle that ends exactly where it began (a spin) closes too, but only
// after travelling far enough; a slow wiggle does not close tiny loops.
const circle = Array.from({length: 37}, (_, i) => ({x: 100 * Math.cos(i * Math.PI / 18), y: 100 * Math.sin(i * Math.PI / 18) + 1e-9 * i}));
const closed = geometry.selfCrossing(circle, 8, 50);
assert(closed && closed.index === 0, 'spin loop closes at its start');
assert.equal(geometry.selfCrossing([{x: 0, y: 0}, {x: 3, y: 0}, {x: 6, y: 0}, {x: 4, y: 1}], 8, 50), null, 'no snap without travel');
const box = geometry.bounds(bowl);
assert.deepEqual([box.x, box.y, box.width, box.height], [20, 0, 60, 40]);
console.log('Cut geometry: concave shapes, holes, crossings, solid spans, path splits, and loops passed.');
