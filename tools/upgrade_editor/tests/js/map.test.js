import test from "node:test";
import assert from "node:assert/strict";
import { hitSpot, paintOrder, roomHue } from "../../web/js/views/mapView.js";
import { loadReal } from "./data.js";

const { context } = loadReal();

test("hit test picks the smallest area", () => {
  const spots = { big: { rects: [[0, 0, 100, 100]] }, small: { rects: [[10, 10, 10, 10]] } };
  assert.equal(hitSpot(spots, 15, 15), "small");
  assert.equal(hitSpot(spots, 50, 50), "big");
  assert.equal(hitSpot(spots, 500, 500), null);
});

test("hit test of the real map finds the spots of the game", () => {
  let checked = 0;
  for (const [spot, info] of Object.entries(context.spots)) {
    if (info.rects.length === 0) continue;
    const [x, y, width, height] = info.rects[0];
    assert.ok(hitSpot(context.spots, x + width / 2, y + height / 2), spot);
    checked += 1;
  }
  assert.ok(checked > 80);
});

test("paint order draws large boxes first", () => {
  const order = paintOrder({ a: { room: "r", rects: [[0, 0, 5, 5]] }, b: { room: "r", rects: [[0, 0, 50, 50]], custom: true } });
  assert.deepEqual(order.map((item) => item.spot), ["b", "a"]);
  assert.equal(order[0].custom, true);
});

test("room hues are stable and distinct", () => {
  const rooms = ["a", "b", "c", "d"];
  assert.equal(roomHue(rooms, "a"), 0);
  assert.equal(new Set(rooms.map((room) => roomHue(rooms, room))).size, 4);
  assert.equal(roomHue(rooms, "unknown"), 0);
});
