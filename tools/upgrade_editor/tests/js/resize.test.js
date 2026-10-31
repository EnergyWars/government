import test from "node:test";
import assert from "node:assert/strict";
import { HANDLE_CURSORS, MIN_RECT_SIZE, ZOOM_LIMITS, boundingBox, clampZoom, fitZoom, handleLayout, isSameRect, moveRect, resizeRect, zoomedBy } from "../../web/js/resize.js";

const rect = [100, 200, 300, 400];
const bounds = { minX: 0, minY: 0, maxX: 1000, maxY: 1000 };

test("every handle moves only its own edges", () => {
  assert.deepEqual(resizeRect(rect, "e", 50, 99), [100, 200, 350, 400]);
  assert.deepEqual(resizeRect(rect, "w", 50, 99), [150, 200, 250, 400]);
  assert.deepEqual(resizeRect(rect, "s", 99, 50), [100, 200, 300, 450]);
  assert.deepEqual(resizeRect(rect, "n", 99, 50), [100, 250, 300, 350]);
  assert.deepEqual(resizeRect(rect, "se", 10, 20), [100, 200, 310, 420]);
  assert.deepEqual(resizeRect(rect, "nw", 10, 20), [110, 220, 290, 380]);
  assert.deepEqual(resizeRect(rect, "ne", 10, 20), [100, 220, 310, 380]);
  assert.deepEqual(resizeRect(rect, "sw", 10, 20), [110, 200, 290, 420]);
});

test("shrinking stops at the minimum size and never flips the box", () => {
  assert.deepEqual(resizeRect(rect, "e", -1000, 0), [100, 200, MIN_RECT_SIZE, 400]);
  assert.deepEqual(resizeRect(rect, "w", 1000, 0), [392, 200, MIN_RECT_SIZE, 400]);
  assert.deepEqual(resizeRect(rect, "s", 0, -1000), [100, 200, 300, MIN_RECT_SIZE]);
  assert.deepEqual(resizeRect(rect, "n", 0, 1000), [100, 592, 300, MIN_RECT_SIZE]);
  assert.deepEqual(resizeRect(rect, "se", -1000, -1000, null, 20), [100, 200, 20, 20]);
});

test("growing stops at the map border", () => {
  assert.deepEqual(resizeRect(rect, "e", 5000, 0, bounds), [100, 200, 900, 400]);
  assert.deepEqual(resizeRect(rect, "w", -5000, 0, bounds), [0, 200, 400, 400]);
  assert.deepEqual(resizeRect(rect, "s", 0, 5000, bounds), [100, 200, 300, 800]);
  assert.deepEqual(resizeRect(rect, "n", 0, -5000, bounds), [100, 0, 300, 600]);
  assert.deepEqual(resizeRect(rect, "e", 5000, 0), [100, 200, 5300, 400]);
});

test("results are whole numbers with a size of at least the minimum", () => {
  for (const [dx, dy] of [[0.4, 0.6], [-0.5, 0.5], [7.49, -7.51], [-292.3, -392.7]]) {
    for (const handle of Object.keys(HANDLE_CURSORS)) {
      const result = resizeRect(rect, handle, dx, dy, bounds);
      assert.ok(result.every(Number.isInteger), `${handle} ${dx} ${dy}`);
      assert.ok(result[2] >= MIN_RECT_SIZE && result[3] >= MIN_RECT_SIZE, `${handle} ${dx} ${dy}`);
    }
  }
});

test("a zero drag keeps the box", () => {
  for (const handle of Object.keys(HANDLE_CURSORS)) assert.deepEqual(resizeRect(rect, handle, 0, 0, bounds), rect);
});

test("handles sit on the corners and, when there is room, on the edges", () => {
  const large = handleLayout([0, 0, 400, 400], 0.5);
  assert.deepEqual(large.map((handle) => handle.id).sort(), ["e", "n", "ne", "nw", "s", "se", "sw", "w"]);
  const northWest = large.find((handle) => handle.id === "nw");
  assert.equal(northWest.size, 20);
  assert.equal(northWest.x + northWest.size / 2, 0);
  assert.equal(northWest.y + northWest.size / 2, 0);
  const east = large.find((handle) => handle.id === "e");
  assert.equal(east.x + east.size / 2, 400);
  assert.equal(east.y + east.size / 2, 200);
});

test("small boxes only get corner handles on the short side", () => {
  const flat = handleLayout([0, 0, 400, 20], 0.5).map((handle) => handle.id).sort();
  assert.deepEqual(flat, ["n", "ne", "nw", "s", "se", "sw"]);
  const narrow = handleLayout([0, 0, 20, 400], 0.5).map((handle) => handle.id).sort();
  assert.deepEqual(narrow, ["e", "ne", "nw", "se", "sw", "w"]);
  assert.deepEqual(handleLayout([0, 0, 10, 10], 0.5).map((handle) => handle.id).sort(), ["ne", "nw", "se", "sw"]);
});

test("handle size follows the zoom so it stays the same on screen", () => {
  assert.equal(handleLayout([0, 0, 100, 100], 1)[0].size, 10);
  assert.equal(handleLayout([0, 0, 100, 100], 0.25)[0].size, 40);
});

test("every handle has a cursor", () => {
  assert.deepEqual(Object.keys(HANDLE_CURSORS).sort(), ["e", "n", "ne", "nw", "s", "se", "sw", "w"]);
});

test("moving keeps the size and stays inside the bounds", () => {
  assert.deepEqual(moveRect(rect, 10.4, -20.6), [110, 179, 300, 400]);
  assert.deepEqual(moveRect(rect, 5000, 5000, bounds), [700, 600, 300, 400]);
  assert.deepEqual(moveRect(rect, -5000, -5000, bounds), [0, 0, 300, 400]);
  assert.deepEqual(moveRect(rect, 0, 0, bounds), rect);
  assert.deepEqual(moveRect(rect, 50, 60), [150, 260, 300, 400]);
});

test("the bounding box covers all boxes", () => {
  assert.equal(boundingBox([]), null);
  assert.deepEqual(boundingBox([[10, 20, 30, 40]]), [10, 20, 30, 40]);
  assert.deepEqual(boundingBox([[10, 20, 30, 40], [100, 5, 10, 10]]), [10, 5, 100, 55]);
});

test("zoom is limited and fits the box into a share of the viewport", () => {
  assert.equal(clampZoom(0.001), ZOOM_LIMITS.min);
  assert.equal(clampZoom(99), ZOOM_LIMITS.max);
  assert.equal(clampZoom(1), 1);
  assert.equal(zoomedBy(1, 1.25), 1.25);
  assert.equal(zoomedBy(ZOOM_LIMITS.max, 2), ZOOM_LIMITS.max);
  assert.equal(fitZoom(null, { width: 1000, height: 800 }), null);
  assert.equal(fitZoom([0, 0, 500, 100], { width: 1000, height: 800 }), 1);
  assert.equal(fitZoom([0, 0, 100, 400], { width: 1000, height: 800 }), 1);
  assert.equal(fitZoom([0, 0, 10, 10], { width: 1000, height: 800 }), ZOOM_LIMITS.max);
  assert.equal(fitZoom([0, 0, 100000, 100000], { width: 1000, height: 800 }), ZOOM_LIMITS.min);
  assert.equal(fitZoom([0, 0, 1000, 800], { width: 1000, height: 800 }, 1), 1);
});

test("boxes compare by value", () => {
  assert.equal(isSameRect([1, 2, 3, 4], [1, 2, 3, 4]), true);
  assert.equal(isSameRect([1, 2, 3, 4], [1, 2, 3, 5]), false);
  assert.equal(isSameRect([1, 2, 3], [1, 2, 3, 4]), false);
});
