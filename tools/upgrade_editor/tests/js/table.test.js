import test from "node:test";
import assert from "node:assert/strict";
import { loadReal } from "./data.js";
import { effectiveConstants } from "../../web/js/formulas.js";
import { COLUMNS, appendLevel, buildRows, changedRows, clean, dropLevel, editRow, effectiveTable, incrementCell, metricValue, valueBefore, visibleColumns, withCost, withIncrement, withValue } from "../../web/js/table.js";
import { cumulativeRatioOf } from "../../web/js/benefit.js";
import { CHART, highlightState, nearestIndex, polylinePoints, scaleSeries, xOf } from "../../web/js/chartMath.js";

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

test("series are scaled linearly from zero and skip missing values", () => {
  const points = scaleSeries([0, 50, 100]);
  assert.equal(points[0].y, CHART.height - CHART.pad);
  assert.equal(points[2].y, CHART.pad);
  assert.equal(points[1].y, CHART.height / 2);
  assert.equal(scaleSeries([null, undefined, NaN]), null);
  const gap = scaleSeries([1, null, 10]);
  assert.equal(gap[1], null);
  assert.equal(polylinePoints(gap).split(" ").length, 2);
  const flat = scaleSeries([5, 5]);
  assert.equal(flat[0].y, flat[1].y);
  assert.ok(Number.isFinite(scaleSeries([0, 0])[0].y));
  assert.equal(scaleSeries([-10, 10])[0].y, CHART.height - CHART.pad);
});

test("hovering a legend entry focuses its line and dims all others", () => {
  assert.equal(highlightState(null, "cost"), "");
  assert.equal(highlightState("cost", "cost"), "focus");
  assert.equal(highlightState("cost", "sum"), "dim");
});

test("hidden series disappear from the table columns but level stays", () => {
  assert.deepEqual(visibleColumns({}), COLUMNS);
  const columns = visibleColumns({ sum: true, factor: true, level: true });
  assert.ok(columns.includes("level"));
  assert.ok(!columns.includes("sum") && !columns.includes("factor"));
  assert.equal(columns.length, COLUMNS.length - 2);
});

test("rows differing from the applied table are marked as changed", () => {
  const applied = { cost: [1, 2, 3], value: [1, 1, 1] };
  assert.deepEqual(changedRows({ cost: [1, 2, 3], value: [1, 1, 1 + 1e-12] }, applied), [false, false, false]);
  assert.deepEqual(changedRows({ cost: [1, 5, 3], value: [1, 1, 2] }, applied), [false, true, true]);
  assert.deepEqual(changedRows({ cost: [1, 2, 3, 4], value: [1, 1, 1, 1] }, applied), [false, false, false, true]);
});

test("levels can be appended and dropped but never below one", () => {
  const draft = { cost: [1, 2], value: [3, 4], formula: {}, dirty: false };
  const longer = appendLevel(draft);
  assert.deepEqual(longer.cost, [1, 2, 2]);
  assert.deepEqual(longer.value, [3, 4, 4]);
  assert.deepEqual(dropLevel(longer).cost, [1, 2]);
  assert.equal(dropLevel({ cost: [1], value: [1] }).cost.length, 1);
  assert.deepEqual(appendLevel({ cost: [], value: [] }).cost, [0]);
  assert.deepEqual(draft.cost, [1, 2]);
});

const table = () => ({ cost: [10, 8, 16], value: [0, 4, 4] });
const context10 = { base: 10, reference: 10 };

test("rows carry cost factors and effect", () => {
  const rows = buildRows(10, [10, 8, 16], [0, 4, 4], 1, 10);
  assert.deepEqual(rows.map((row) => row.costFactor), [1, 0.8, 1.6]);
  assert.deepEqual(rows.map((row) => row.sumFactor), [1, 1.8, 3.4]);
  assert.deepEqual(rows.map((row) => row.effect), [1, 1.4, 1.8]);
  assert.equal(buildRows(0, [1], [1], 1, 0)[0].effect, null);
  assert.equal(buildRows(10, [1], [1], 1, 0)[0].costFactor, null);
  assert.equal(metricValue(rows[1], "gain", "absolute"), rows[1].gain * 100);
  assert.equal(metricValue(rows[1], "increment", "factor"), 1.4 / 1);
});

test("editing any cost based metric recalculates the cost", () => {
  assert.equal(editRow(table(), 1, "cost", 20, context10).cost[1], 20);
  assert.equal(editRow(table(), 1, "costFactor", 2, context10).cost[1], 20);
  assert.equal(editRow(table(), 1, "sum", 40, context10).cost[1], 30);
  assert.equal(editRow(table(), 1, "sumFactor", 4, context10).cost[1], 30);
  assert.equal(editRow(table(), 1, "stepRatio", 100, context10).cost[1], 4);
  const factor = rowsOf(editRow(table(), 1, "factor", 500, context10))[1].factor;
  assert.ok(Math.abs(factor - 500) < 1e-6);
  assert.deepEqual(editRow(table(), 1, "cost", 20, context10).value, table().value);
});

const rowsOf = (data) => buildRows(10, data.cost, data.value, 1, 10);

test("editing a metric reproduces the entered value in the rebuilt rows", () => {
  for (const column of ["cost", "costFactor", "sum", "sumFactor", "increment", "value", "effect", "gain", "factor", "stepRatio", "totalRatio"]) {
    const input = { cost: 12, costFactor: 1.5, sum: 30, sumFactor: 3, increment: 3, value: 16, effect: 1.6, gain: 20, factor: 300, stepRatio: 80, totalRatio: 60 }[column];
    const next = editRow(table(), 1, column, input, context10);
    const row = rowsOf(next)[1];
    assert.ok(Math.abs(metricValue(row, column, "absolute") - input) < 1e-6, `${column}: ${metricValue(row, column, "absolute")}`);
  }
});

test("editing the increment as a factor multiplies the value before", () => {
  const next = editRow(table(), 2, "increment", 1.5, { ...context10, mode: "factor" });
  assert.equal(rowsOf(next)[2].value, 21);
});

test("dependent rows shift while earlier rows stay", () => {
  const next = editRow(table(), 1, "value", 20, context10);
  assert.equal(rowsOf(next)[0].value, 10);
  assert.equal(rowsOf(next)[1].value, 20);
  assert.equal(rowsOf(next)[2].value, 24);
});

test("impossible edits leave the table untouched", () => {
  const same = table();
  assert.equal(editRow(same, 1, "cost", Number.NaN, context10), same);
  assert.equal(editRow(same, 9, "cost", 1, context10), same);
  assert.equal(editRow(same, 1, "cost", -5, context10), same);
  assert.equal(editRow(same, 1, "unknown", 5, context10), same);
  assert.equal(editRow(same, 1, "stepRatio", 0, context10), same);
  assert.equal(editRow(same, 0, "stepRatio", 50, context10), same);
  assert.equal(editRow(same, 1, "costFactor", 2, { base: 10, reference: 0 }), same);
  assert.equal(editRow(same, 1, "effect", 2, { base: 0, reference: 10 }), same);
  assert.equal(editRow(same, 1, "gain", 150, context10), same);
  assert.equal(editRow(same, 1, "sum", 5, context10), same);
});
