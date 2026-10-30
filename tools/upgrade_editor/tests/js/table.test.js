import test from "node:test";
import assert from "node:assert/strict";
import { loadReal } from "./data.js";
import { effectiveConstants } from "../../web/js/formulas.js";
import { buildRows, clean, effectiveTable, incrementCell, valueBefore, withCost, withIncrement, withValue } from "../../web/js/table.js";
import { cumulativeRatioOf } from "../../web/js/benefit.js";
import { CHART, nearestIndex, polylinePoints, scaleSeries, xOf } from "../../web/js/chartMath.js";

const { document, context } = loadReal();
const constants = effectiveConstants(context, document);

test("rows accumulate cost, value and ratios", () => {
  const rows = buildRows(10, [10, 8, 16], [0, 4, 4]);
  assert.deepEqual(rows.map((row) => row.sum), [10, 18, 34]);
  assert.deepEqual(rows.map((row) => row.value), [10, 14, 18]);
  assert.equal(rows[1].stepRatio, ((4 / 10) / (8 / 10)) * 100);
  assert.equal(rows[2].stepRatio, ((4 / 10) / (16 / 10)) * 100);
  assert.ok(Math.abs(rows[2].totalRatio - cumulativeRatioOf(10, 8, 10, 34)) < 1e-9);
  assert.equal(rows[1].incrementFactor, 14 / 10);
  assert.equal(rows[0].level, 1);
});

test("the room factor scales costs but not values", () => {
  const plain = buildRows(10, [10, 8], [1, 1]);
  const scaled = buildRows(10, [10, 8], [1, 1], 3);
  assert.equal(scaled[1].cost, 24);
  assert.equal(scaled[1].sum, 54);
  assert.equal(scaled[1].value, plain[1].value);
  assert.ok(Math.abs(scaled[1].stepRatio - plain[1].stepRatio) < 1e-9);
});

test("a zero base value yields no ratios and no increment factor", () => {
  const rows = buildRows(0, [5, 5], [1, 1]);
  assert.equal(rows[0].stepRatio, null);
  assert.equal(rows[0].totalRatio, null);
  assert.equal(rows[0].incrementFactor, null);
  assert.equal(rows[1].incrementFactor, 2);
});

test("editing a cost changes only that level", () => {
  assert.deepEqual(withCost([1, 2, 3], 1, 5), [1, 5, 3]);
  assert.deepEqual(withCost([1, 2, 3], 0, 0.1 + 0.2), [0.3, 2, 3]);
});

test("editing an absolute increment keeps the others and shifts later values", () => {
  const increments = withIncrement([1, 1, 1], 1, 4, "absolute", 10);
  assert.deepEqual(increments, [1, 4, 1]);
  assert.deepEqual(buildRows(10, [1, 1, 1], increments).map((row) => row.value), [11, 15, 16]);
});

test("editing a factor increment multiplies the value before it", () => {
  const increments = withIncrement([2, 2, 2], 2, 1.5, "factor", 10);
  assert.equal(valueBefore(10, [2, 2, 2], 2), 14);
  assert.deepEqual(increments, [2, 2, 7]);
  assert.equal(buildRows(10, [1, 1, 1], increments)[2].incrementFactor, 1.5);
});

test("editing a value changes its own increment so the value matches", () => {
  const increments = withValue([2, 2, 2], 1, 20, 10);
  assert.deepEqual(increments, [2, 8, 2]);
  assert.equal(buildRows(10, [1, 1, 1], increments)[1].value, 20);
  assert.equal(buildRows(10, [1, 1, 1], increments)[2].value, 22);
});

test("increment cell follows the mode", () => {
  const row = buildRows(10, [1], [5])[0];
  assert.equal(incrementCell(row, "absolute"), 5);
  assert.equal(incrementCell(row, "factor"), 1.5);
});

test("clean rounds floating point noise", () => {
  assert.equal(clean(0.1 + 0.2), 0.3);
  assert.equal(clean(123456789.123456789), 123456789.123);
});

test("the effective table reproduces every real upgrade", () => {
  for (const [id, definition] of Object.entries(document.upgrades)) {
    const costs = effectiveTable(definition, "cost", constants);
    const increments = effectiveTable(definition, "value", constants);
    assert.equal(costs.length, definition.max, id);
    assert.equal(increments.length, definition.max, id);
    assert.ok(costs.every((cost) => cost >= 0 && Number.isFinite(cost)), id);
  }
});

test("chart math maps indices and pointer positions", () => {
  assert.equal(xOf(0, 5), CHART.pad);
  assert.equal(xOf(4, 5), CHART.width - CHART.pad);
  assert.equal(xOf(0, 1), CHART.width / 2);
  assert.equal(nearestIndex(0, CHART.width, 5), 0);
  assert.equal(nearestIndex(CHART.width, CHART.width, 5), 4);
  assert.equal(nearestIndex(CHART.width / 2, CHART.width, 5), 2);
  assert.equal(nearestIndex(100, CHART.width, 1), 0);
});

test("series are scaled logarithmically and skip non-positive values", () => {
  const points = scaleSeries([1, 10, 100]);
  assert.equal(points[0].y, CHART.height - CHART.pad);
  assert.equal(points[2].y, CHART.pad);
  assert.equal(scaleSeries([0, -1, null]), null);
  const gap = scaleSeries([1, 0, 10]);
  assert.equal(gap[1], null);
  assert.equal(polylinePoints(gap).split(" ").length, 2);
  const flat = scaleSeries([5, 5]);
  assert.equal(flat[0].y, flat[1].y);
});
