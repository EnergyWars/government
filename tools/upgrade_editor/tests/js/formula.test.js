import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { compile, evaluate } from "../../web/js/formula.js";

const vectors = JSON.parse(readFileSync(new URL("../shared/formula_vectors.json", import.meta.url), "utf8"));

for (const vector of vectors) {
  test(`vector ${JSON.stringify(vector.expr)} ${JSON.stringify(vector.vars)}`, () => {
    const result = evaluate(vector.expr, vector.vars);
    if ("error" in vector) {
      assert.equal(result.ok, false);
      assert.equal(result.code, vector.error);
    } else {
      assert.equal(result.ok, true, result.code);
      assert.ok(Math.abs(result.value - vector.value) <= 1e-9 * Math.max(1, Math.abs(vector.value)), `${result.value} != ${vector.value}`);
    }
  });
}

test("compiled formulas can be reused with different variables", () => {
  const compiled = compile("level * 2", ["level"]);
  assert.equal(compiled.run({ level: 3 }), 6);
  assert.equal(compiled.run({ level: 5 }), 10);
  assert.equal(compile("level * 2", ["level"]), compiled);
});

test("compile reports errors without throwing", () => {
  assert.deepEqual(compile("1 +", []), { ok: false, code: "SYNTAX" });
  assert.equal(compile("x", []).code, "UNKNOWN_IDENTIFIER");
  assert.equal(compile("x", ["x"]).ok, true);
});

test("the cache stays bounded", () => {
  for (let index = 0; index < 700; index += 1) compile(`${index} + 1`, []);
  assert.equal(compile("1 + 1", []).ok, true);
});
