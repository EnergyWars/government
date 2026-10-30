import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { createI18n, detectLanguage } from "../../web/js/i18n.js";

const read = (name) => JSON.parse(readFileSync(new URL(`../../web/i18n/${name}.json`, import.meta.url), "utf8"));
const de = read("de");
const en = read("en");

function sources(directory) {
  const base = new URL("../../web/js/", import.meta.url).pathname;
  const walk = (path) => readdirSync(path).flatMap((name) => (statSync(join(path, name)).isDirectory() ? walk(join(path, name)) : name.endsWith(".js") ? [readFileSync(join(path, name), "utf8")] : []));
  return walk(directory ?? base).join("\n");
}

test("german and english define the same keys", () => {
  assert.deepEqual(Object.keys(de).sort(), Object.keys(en).sort());
});

test("no empty translations", () => {
  for (const dictionary of [de, en]) for (const [key, value] of Object.entries(dictionary)) assert.ok(value.trim(), key);
});

test("placeholders match between languages", () => {
  const names = (text) => [...text.matchAll(/\{(\w+)\}/g)].map((match) => match[1]).sort();
  for (const key of Object.keys(de)) assert.deepEqual(names(de[key]), names(en[key]), key);
});

test("every statically used key exists", () => {
  const code = sources();
  const used = new Set([...code.matchAll(/\bt\("([a-zA-Z_.]+)"/g)].map((match) => match[1]).filter((key) => !key.endsWith(".")));
  const missing = [...used].filter((key) => !(key in en));
  assert.deepEqual(missing, []);
});

test("dynamic key families exist", () => {
  const families = {
    "curve.": ["linear", "decay", "unlock", "unlock_decay", "milestone", "chance"],
    "field.": ["max", "cost", "growth", "price_offset", "base", "step", "rate", "neutral", "reputation", "unit"],
    "fieldHelp.": ["max", "cost", "growth", "price_offset", "base", "step", "rate", "neutral", "reputation"],
    "error.": ["AREA_EXISTS", "AREA_ROOM", "AREA_UNKNOWN", "AREA_NOT_EMPTY", "AREA_LAST_RECT", "NOT_PLACED", "ROOM_NOT_AVAILABLE", "SPOT_ROOM_MISMATCH", "SYSTEM_FIXED", "UNKNOWN_UPGRADE", "ALREADY_PLACED", "GROUP_TITLE", "ROOM_OVERRIDE"],
    "menu.mode.": ["rooms", "topics"],
    "menu.hint.": ["rooms", "topics"],
    "system.": ["hire", "staff_runners", "staff_coffee_interns", "staff_hr", "segment", "storage", "rank", "desk", "reject_pile"],
    "overview.col.": ["title", "topic", "levels", "firstCost", "totalCost", "firstGain", "firstFactor", "totalFactor"],
    "system.field.": ["desk_cost", "hire_cost", "unlock_cost", "unlock_reputation", "cost_multiplier", "staff_multiplier"],
    "model.mode.": ["params", "formula", "table"], "model.var.": ["level", "max", "cost", "growth", "price_offset", "base", "step", "rate", "neutral"], "model.formulaNote.": ["cost", "value"], "model.params.": ["cost", "value"], "model.": ["cost.title", "value.title"], "formula.err.": ["EMPTY", "SYNTAX", "UNKNOWN_IDENTIFIER", "UNKNOWN_FUNCTION", "ARITY", "NOT_FINITE", "NEGATIVE"], "tab.": ["map", "menu", "overview", "system", "changes"],
    "toolbar.source.": ["original", "edited"],
    "table.col.": ["level", "cost", "costFactor", "sum", "sumFactor", "increment", "value", "effect", "gain", "factor", "stepRatio", "totalRatio"], "table.desc.": ["level", "cost", "costFactor", "sum", "sumFactor", "increment", "value", "effect", "gain", "factor", "stepRatio", "totalRatio"], "table.increment.": ["absolute", "factor"], "table.mode.": ["absolute", "factor"],
    "compare.group.": ["topic", "unit", "curve", "all"], "compare.col.": ["title", "levels", "totalCost", "gain", "factor", "totalRatio", "relCost", "relGain", "relFactor", "relRatio"], "compare.desc.": ["levels", "totalCost", "gain", "factor", "totalRatio", "relCost", "relGain", "relFactor", "relRatio"],
    "theme.": ["auto", "light", "dark"],
    "change.roomOverride.": ["added", "changed", "removed"],
    "fill.tab.": ["params", "formula", "tools"], "fill.title.": ["cost", "value"], "fill.params.hint.": ["cost", "value"],
  };
  for (const [prefix, names] of Object.entries(families)) for (const name of names) assert.ok(prefix + name in en, prefix + name);
});

test("constants of the game have names", async () => {
  const document = JSON.parse(readFileSync(new URL("../../../../data/upgrades.json", import.meta.url), "utf8"));
  for (const name of Object.keys(document.system.constants)) assert.ok("const." + name in en, name);
});

test("language lookup and fallback", () => {
  const i18n = createI18n({ de: { a: "A {x}" }, en: { a: "a", b: "b" } }, "de");
  assert.equal(i18n.t("a", { x: 1 }), "A 1");
  assert.equal(i18n.t("b"), "b");
  assert.equal(i18n.t("c"), "c");
  assert.equal(i18n.t("a"), "A {x}");
  assert.equal(i18n.has("b"), true);
  assert.equal(i18n.has("c"), false);
  i18n.setLanguage("fr");
  assert.equal(i18n.language, "en");
  assert.equal(detectLanguage("en", "de"), "en");
  assert.equal(detectLanguage(null, "en-US"), "en");
  assert.equal(detectLanguage(null, "de-DE"), "de");
  assert.equal(detectLanguage(null, undefined), "de");
});
