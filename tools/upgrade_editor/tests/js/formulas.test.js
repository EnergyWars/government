import test from "node:test";
import assert from "node:assert/strict";
import { loadReal } from "./data.js";
import { earlyDiscount, effectiveConstants, geometricSum, levelSpeed, rankBaseCost, rankFeeFactor, systemCost, systemModel, trackCost, trackRoomFactor, trackValue } from "../../web/js/formulas.js";

const { document, context } = loadReal();
const constants = effectiveConstants(context, document);
const close = (actual, expected, label) => assert.ok(Math.abs(actual - expected) <= Math.abs(expected) * 1e-9 + 1e-9, `${label}: ${actual} vs ${expected}`);

test("early discount ramps from the start value to one", () => {
  assert.equal(earlyDiscount(0, constants), constants.EARLY_DISCOUNT_START);
  assert.equal(earlyDiscount(constants.EARLY_DISCOUNT_LEVELS, constants), 1);
  assert.equal(earlyDiscount(99, constants), 1);
  assert.ok(Math.abs(earlyDiscount(5, constants) - 0.625) < 1e-12);
  assert.equal(earlyDiscount(-3, constants), constants.EARLY_DISCOUNT_START);
});

test("every track cost and value matches the game for every room", () => {
  let checked = 0;
  for (const [key, samples] of Object.entries(context.check.track_costs)) {
    const [upgradeId, roomId = ""] = key.split("@");
    const definition = document.upgrades[upgradeId];
    const factor = trackRoomFactor(upgradeId, definition, roomId, context, document, constants);
    for (const [level, cost, value] of samples) {
      close(trackCost(definition, level, factor, constants), cost, `${key} cost L${level}`);
      close(trackValue(definition, level, constants), value, `${key} value L${level}`);
      checked += 1;
    }
  }
  assert.ok(checked > 500);
});

test("track value covers every curve", () => {
  const base = { base: 2, max: 10, rate: 0.5, step: 3 };
  assert.equal(trackValue({ ...base, curve: "linear" }, 4, constants), 14);
  assert.equal(trackValue({ ...base, curve: "linear" }, 40, constants), 32);
  assert.equal(trackValue({ ...base, curve: "linear" }, -1, constants), 2);
  assert.equal(trackValue({ ...base, curve: "decay" }, 2, constants), 0.5);
  assert.equal(trackValue({ ...base, curve: "unlock_decay" }, 0, constants), -1);
  assert.equal(trackValue({ ...base, curve: "unlock_decay" }, 3, constants), 0.5);
  assert.equal(trackValue({ ...base, curve: "unlock" }, 0, constants), 0);
  assert.equal(trackValue({ ...base, curve: "unlock" }, 1, constants), 1);
  assert.equal(trackValue({ base: 0.25, rate: 0.5, max: 4, curve: "chance" }, 1, constants), 0.625);
  assert.equal(trackValue({ max: 4, curve: "linear" }, 2, constants), 0);
  assert.equal(trackValue({ base: 2, max: 4, curve: "decay" }, 2, constants), 2);
});

test("level speed uses milestones", () => {
  assert.equal(levelSpeed(1, constants), 1);
  close(levelSpeed(10, constants), (1 + constants.LEVEL_SPEED_BONUS * 9) * constants.LEVEL_MILESTONE_BONUS, "milestone");
});

test("geometric sum handles growth of one", () => {
  assert.equal(geometricSum(5, 1, 4), 20);
  assert.equal(geometricSum(5, 2, 0), 0);
  assert.equal(geometricSum(1, 2, 3), 7);
});

test("room factor rules", () => {
  const speed = document.upgrades.room_speed;
  assert.equal(trackRoomFactor("room_speed", speed, "", context, document, constants), 1);
  assert.equal(trackRoomFactor("room_speed", speed, "hall", context, document, constants), 1);
  assert.equal(trackRoomFactor("room_speed", speed, "inspection", context, document, constants), 10);
  const lead = document.upgrades.lead_breaks;
  assert.equal(lead.staff_cost, true);
  const tax = context.departments.find((entry) => entry.id === "tax_services");
  assert.equal(trackRoomFactor("room_speed", speed, "tax_services", context, document, constants), tax.cost_multiplier);
  assert.equal(trackRoomFactor("lead_breaks", lead, "tax_services", context, document, constants), tax.staff_multiplier);
  assert.equal(trackRoomFactor("tube_station", document.upgrades.tube_station, "inspection", context, document, constants), constants.TUBE_STATION_INSPECTION_FACTOR);
  assert.equal(trackRoomFactor("tube_station", document.upgrades.tube_station, "hall", context, document, constants), 1);
});

test("live edits change the room factor", () => {
  const edited = structuredClone(document);
  edited.system.departments.tax_services.cost_multiplier = 7;
  assert.equal(trackRoomFactor("room_speed", document.upgrades.room_speed, "tax_services", context, edited, constants), 7);
});

test("system entry costs match the game at their first level", () => {
  let checked = 0;
  for (const [id, entry] of Object.entries(context.system_entries)) {
    const model = systemModel(entry, context, document, constants);
    assert.ok(model, id);
    close(systemCost(model, model.minLevel, constants), context.check.entry_costs[id], id);
    checked += 1;
  }
  assert.ok(checked > 50);
});

test("rank costs and fee factors match the game", () => {
  for (const [dept, [first, fiftieth, fee]] of Object.entries(context.check.rank_costs)) {
    close(rankBaseCost(dept, context, document, constants), first, dept + " base");
    close(rankBaseCost(dept, context, document, constants) * constants.RANK_LEVEL_COST_GROWTH ** 49, fiftieth, dept + " L50");
    close(rankFeeFactor(26, constants), fee, "fee");
  }
});

test("unknown station or kind yields no model", () => {
  assert.equal(systemModel({ kind: "desk", target: "ghost" }, context, document, constants), null);
  assert.equal(systemModel({ kind: "hire", target: "ghost" }, context, document, constants), null);
  assert.equal(systemModel({ kind: "reject_pile", target: "ghost" }, context, document, constants), null);
  assert.equal(systemModel({ kind: "staff", target: "ghost" }, context, document, constants), null);
  assert.equal(systemModel({ kind: "mystery", target: "" }, context, document, constants), null);
});

test("edited system constants flow into the costs", () => {
  const edited = structuredClone(document);
  edited.system.constants.RUNNER_COST = 1000;
  const changed = effectiveConstants(context, edited);
  const model = systemModel({ kind: "staff", target: "runners" }, context, edited, changed);
  close(systemCost(model, 0, changed), 1000 * earlyDiscount(0, changed), "runner");
});

import { modelCost as customModelCost, trackCost as customTrackCost, trackValue as customTrackValue } from "../../web/js/formulas.js";

const sample = { max: 5, cost: 100, growth: 2, base: 10, step: 1, rate: 0.9, curve: "linear" };

test("cost formulas replace the curve and keep the room factor", () => {
  const definition = { ...sample, cost_model: { mode: "formula", formula: "cost + level * 10" } };
  assert.equal(customTrackCost(definition, 3, 1, {}), 130);
  assert.equal(customTrackCost(definition, 3, 2, {}), 260);
});

test("cost tables clamp to their length and ignore negative values", () => {
  const definition = { ...sample, cost_model: { mode: "table", levels: [5, -3, 9] } };
  assert.equal(customModelCost(definition, 0), 5);
  assert.equal(customModelCost(definition, 1), 0);
  assert.equal(customModelCost(definition, 99), 9);
  assert.equal(customModelCost({ ...sample, cost_model: { mode: "table", levels: [] } }, 0), 0);
});

test("invalid cost formulas fall back to the curve", () => {
  const definition = { ...sample, cost_model: { mode: "formula", formula: "1 +" } };
  assert.equal(customModelCost(definition, 3), 800);
  assert.equal(customModelCost({ ...sample, cost_model: { mode: "formula", formula: "0 - 4" } }, 1), 0);
});

test("value formulas see all variables", () => {
  const definition = { ...sample, value_model: { mode: "formula", formula: "base + level * step + max - rate * 0" } };
  assert.equal(customTrackValue(definition, 3, {}), 10 + 3 + 5);
  assert.equal(customTrackValue(definition, 999, {}), 10 + 5 + 5);
});

test("value tables accumulate increments", () => {
  const definition = { ...sample, value_model: { mode: "table", increments: [1, 2, 4] } };
  assert.equal(customTrackValue(definition, 0, {}), 10);
  assert.equal(customTrackValue(definition, 2, {}), 13);
  assert.equal(customTrackValue(definition, 5, {}), 17);
});

test("invalid value formulas fall back to the curve", () => {
  const definition = { ...sample, value_model: { mode: "formula", formula: "nope" } };
  assert.equal(customTrackValue(definition, 3, {}), 13);
});

import { checkFormula } from "../../web/js/formulas.js";

test("formula checks cover every level", () => {
  assert.deepEqual(checkFormula("cost", sample, "cost * growth ^ level"), { ok: true });
  assert.deepEqual(checkFormula("value", sample, "base + step * level"), { ok: true });
  assert.deepEqual(checkFormula("cost", sample, "1 +"), { ok: false, code: "SYNTAX" });
  assert.deepEqual(checkFormula("cost", sample, "1 / (level - 2) + 5"), { ok: false, code: "NOT_FINITE", level: 2 });
  assert.deepEqual(checkFormula("cost", sample, "level - 2"), { ok: false, code: "NEGATIVE", level: 0 });
  assert.equal(checkFormula("value", sample, "level - 2").ok, true);
  assert.equal(checkFormula("value", sample, "1 / (level - 5)").code, "NOT_FINITE");
  assert.equal(checkFormula("cost", sample, "neutral").code, "UNKNOWN_IDENTIFIER");
  assert.equal(checkFormula("value", sample, "neutral + rate").ok, true);
  assert.equal(checkFormula("cost", sample, undefined).code, "EMPTY");
});
