import test from "node:test";
import assert from "node:assert/strict";
import { filterOptions, normalise, stepActive } from "../../web/js/search.js";

const options = [
  { value: "housing", label: "Wohnungsamt" },
  { value: "customs", label: "Zollamt" },
  { value: "tax_services", label: "Finanzamt · Steuern" },
  { value: "kitchen", label: "Küche", keywords: "kantine" },
  { value: "x", label: "Amt für Ämter" },
];

test("normalise ignores case and diacritics", () => {
  assert.equal(normalise("  KÜCHE "), "kuche");
  assert.equal(normalise(null), "");
});

test("an empty query keeps every option in order", () => {
  assert.deepEqual(filterOptions(options, "  ").map((item) => item.index), [0, 1, 2, 3, 4]);
});

test("all tokens must match, in any order", () => {
  assert.deepEqual(filterOptions(options, "steuern finanz").map((item) => item.option.value), ["tax_services"]);
  assert.deepEqual(filterOptions(options, "zzz"), []);
});

test("diacritics, values and keywords are searchable", () => {
  assert.deepEqual(filterOptions(options, "kuche").map((item) => item.option.value), ["kitchen"]);
  assert.deepEqual(filterOptions(options, "kantine").map((item) => item.option.value), ["kitchen"]);
  assert.deepEqual(filterOptions(options, "tax_serv").map((item) => item.option.value), ["tax_services"]);
});

test("prefix matches rank before inner matches", () => {
  const result = filterOptions(options, "amt").map((item) => item.option.value);
  assert.deepEqual(result, ["x", "housing", "customs", "tax_services"]);
});

test("active index wraps around", () => {
  assert.equal(stepActive(-1, 1, 3), 0);
  assert.equal(stepActive(-1, -1, 3), 2);
  assert.equal(stepActive(2, 1, 3), 0);
  assert.equal(stepActive(0, -1, 3), 2);
  assert.equal(stepActive(1, 1, 3), 2);
  assert.equal(stepActive(0, 1, 0), -1);
});
