import test from "node:test";
import assert from "node:assert/strict";
import { loadReal } from "./data.js";
import { effectiveConstants, systemModel } from "../../web/js/formulas.js";
import { cumulativeRatioOf, factorOf, levelTotal, ratioOf, PER_COST, relativeGain, systemGain, systemStep, systemTotals, trackSteps, trackStep, trackTotals } from "../../web/js/benefit.js";

const { document, context } = loadReal();
const constants = effectiveConstants(context, document);
const linear = { cost: 100, growth: 1, max: 5, curve: "linear", base: 10, step: 5, price_offset: 20 };

test("relative gain compares the change with the current value", () => {
  assert.equal(relativeGain(10, 12), 0.2);
  assert.equal(relativeGain(0, 5), 1);
  assert.equal(relativeGain(5, 5), 0);
  assert.ok(Math.abs(relativeGain(1, 0.99) - 0.01) < 1e-12);
  assert.equal(relativeGain(-1, 1), 1);
});

test("factor is percent gain per thousand cost", () => {
  assert.equal(PER_COST, 1000);
  assert.equal(factorOf(0.5, 100), 500);
  assert.equal(factorOf(null, 100), null);
  assert.equal(factorOf(0.5, 0), null);
});

test("track step reports cost, gain and factor", () => {
  const step = trackStep(linear, 0, 1, constants);
  assert.equal(step.level, 1);
  assert.equal(step.cost, 100);
  assert.equal(step.gain, 0.5);
  assert.equal(step.factor, 500);
  assert.equal(trackStep(linear, 5, 1, constants), null);
  assert.equal(trackStep(linear, -1, 1, constants), null);
});

test("halving the cost doubles the factor", () => {
  const expensive = trackStep(linear, 2, 1, constants);
  const cheap = trackStep({ ...linear, cost: 50 }, 2, 1, constants);
  assert.ok(Math.abs(cheap.factor / expensive.factor - 2) < 1e-12);
});

test("room factor raises cost and lowers the factor", () => {
  const one = trackStep(linear, 1, 1, constants);
  const ten = trackStep(linear, 1, 10, constants);
  assert.ok(Math.abs(one.factor / ten.factor - 10) < 1e-12);
});

test("steps and totals cover the whole track", () => {
  const steps = trackSteps(linear, 1, constants);
  assert.equal(steps.length, 5);
  const totals = trackTotals(linear, 1, constants);
  assert.equal(totals.cost, steps.reduce((sum, step) => sum + step.cost, 0));
  assert.equal(totals.gain, relativeGain(10, 35));
  assert.equal(totals.factor, factorOf(totals.gain, totals.cost));
});

test("real tracks never produce a negative or non-finite factor", () => {
  for (const [id, definition] of Object.entries(document.upgrades)) {
    for (const step of trackSteps(definition, 1, constants)) {
      assert.ok(step.cost > 0 && Number.isFinite(step.cost), id);
      assert.ok(step.gain >= 0 && step.gain <= 1.0000001, id);
      assert.ok(step.factor === null || step.factor >= 0, id);
    }
  }
});

test("unlock tracks gain everything with their single level", () => {
  const unlock = { cost: 1000, growth: 1, max: 1, curve: "unlock" };
  const step = trackStep(unlock, 0, 1, constants);
  assert.equal(step.gain, 1);
  assert.equal(step.cost, 1000 * constants.EARLY_DISCOUNT_START);
  assert.equal(step.factor, 100 / (1000 * constants.EARLY_DISCOUNT_START) * 1000);
});

test("system gains by kind", () => {
  assert.equal(systemGain({ kind: "unlock" }, 0, constants), null);
  assert.equal(systemGain({ kind: "desk" }, 1, constants), 1);
  assert.equal(systemGain({ kind: "desk" }, 4, constants), 0.25);
  assert.equal(systemGain({ kind: "hire" }, 0, constants), 1);
  const rank = systemGain({ kind: "rank" }, 1, constants);
  assert.ok(Math.abs(rank - (constants.RANK_LEVEL_FEE_FACTOR - 1)) < 1e-12);
  assert.ok(systemGain({ kind: "rank" }, 24, constants) > rank * 1.4);
});

test("system steps and totals", () => {
  const entry = { kind: "staff", target: "runners" };
  const model = systemModel(entry, context, document, constants);
  const first = systemStep(entry, model, 0, constants);
  assert.equal(first.level, 1);
  assert.equal(first.gain, 1);
  assert.equal(systemStep(entry, model, model.maxLevel, constants), null);
  assert.equal(systemStep(entry, model, -1, constants), null);
  const totals = systemTotals(entry, model, constants);
  assert.equal(totals.cost, levelTotal(model, 0, model.maxLevel, constants));
  assert.equal(totals.factor, factorOf(1, totals.cost));
});

test("unlock and rank totals", () => {
  const unlock = { kind: "unlock", target: "tax_services" };
  const unlockModel = systemModel(unlock, context, document, constants);
  const unlockTotals = systemTotals(unlock, unlockModel, constants);
  assert.equal(unlockTotals.gain, null);
  assert.equal(unlockTotals.factor, null);
  assert.equal(unlockTotals.cost, 800);
  const rank = { kind: "rank", target: "general_services" };
  const rankModel = systemModel(rank, context, document, constants);
  const rankTotals = systemTotals(rank, rankModel, constants);
  assert.ok(rankTotals.gain > 100);
  assert.ok(rankTotals.factor > 0);
});

test("ratio compares relative benefit with relative cost", () => {
  assert.equal(ratioOf(4, 10, 4, 10), 100);
  assert.equal(ratioOf(4, 10, 2, 10), 200);
  assert.equal(ratioOf(2, 10, 4, 10), 50);
  assert.equal(ratioOf(4, 0, 4, 10), null);
  assert.equal(ratioOf(4, 10, 0, 10), null);
  assert.equal(ratioOf(4, 10, 4, 0), null);
});

test("worked example: base 10 life for 10 cost, upgrades of 4 life for 8 and for 16", () => {
  assert.equal(ratioOf(4, 10, 8, 10), 50);
  assert.equal(ratioOf(4, 10, 16, 10), 25);
  assert.ok(Math.abs(cumulativeRatioOf(10, 4, 10, 8) - (14 / 18) * 100) < 1e-9);
  assert.ok(Math.abs(cumulativeRatioOf(10, 8, 10, 24) - (18 / 34) * 100) < 1e-9);
  assert.ok(Math.abs(cumulativeRatioOf(10, 8, 10, 24) - 52.941176) < 1e-6);
  assert.equal(cumulativeRatioOf(10, 0, 10, 0), 100);
  assert.equal(cumulativeRatioOf(0, 4, 10, 8), null);
  assert.equal(cumulativeRatioOf(10, 4, 0, 8), null);
  assert.equal(cumulativeRatioOf(10, 4, 10, -1), null);
});
