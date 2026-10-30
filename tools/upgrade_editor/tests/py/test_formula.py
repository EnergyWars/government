import json
import math
import unittest
from pathlib import Path

from upgrade_editor import formula

VECTORS = json.loads((Path(__file__).resolve().parents[1] / "shared" / "formula_vectors.json").read_text(encoding="utf-8"))


class FormulaVectorsTest(unittest.TestCase):
    def test_all_shared_vectors(self):
        for vector in VECTORS:
            with self.subTest(expr=vector["expr"], vars=vector["vars"]):
                result = formula.evaluate(vector["expr"], vector["vars"])
                if "error" in vector:
                    self.assertEqual(result, {"ok": False, "code": vector["error"]})
                else:
                    self.assertTrue(result["ok"], result)
                    self.assertTrue(math.isclose(result["value"], vector["value"], rel_tol=1e-9, abs_tol=1e-12))

    def test_compile_reuse(self):
        run = formula.compile_formula("level * 2", ["level"])
        self.assertEqual(run({"level": 3}), 6)
        self.assertEqual(run({"level": 5}), 10)

    def test_compile_errors_raise(self):
        with self.assertRaises(formula.FormulaError) as context:
            formula.compile_formula("1 +")
        self.assertEqual(context.exception.code, "SYNTAX")
        with self.assertRaises(formula.FormulaError):
            formula.compile_formula(None)

    def test_edge_functions(self):
        self.assertEqual(formula.evaluate("floor(2.7)")["value"], 2)
        self.assertEqual(formula.evaluate("exp(1000)")["code"], "NOT_FINITE")
        self.assertEqual(formula.evaluate("ln(-1)")["code"], "NOT_FINITE")
        self.assertEqual(formula.evaluate("1 / 0")["code"], "NOT_FINITE")
        self.assertEqual(formula.evaluate("-1 / 0")["code"], "NOT_FINITE")
        self.assertEqual(formula.evaluate("pow(0, -1)")["code"], "NOT_FINITE")
        self.assertEqual(formula.evaluate("pow(-8, 0.5)")["code"], "NOT_FINITE")


if __name__ == "__main__":
    unittest.main()
