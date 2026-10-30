import unittest

from upgrade_editor import validation
from .fixtures import make_document


def codes(document):
    return [error["code"] for error in validation.validate(document)]


class ValidationTest(unittest.TestCase):
    def test_valid_document_has_no_errors(self):
        self.assertEqual(validation.validate(make_document()), [])

    def test_non_object_is_rejected(self):
        self.assertEqual(codes([]), ["NOT_AN_OBJECT"])

    def test_wrong_schema(self):
        document = make_document()
        document["schema"] = 2
        self.assertIn("SCHEMA", codes(document))

    def test_missing_sections(self):
        self.assertEqual(codes({"schema": 1}).count("MISSING_SECTION"), 2)

    def test_definition_must_be_an_object(self):
        document = make_document()
        document["upgrades"]["briefcase"] = 5
        self.assertIn("NOT_AN_OBJECT", codes(document))

    def test_cost_must_be_a_number(self):
        document = make_document()
        document["upgrades"]["briefcase"]["cost"] = "cheap"
        self.assertIn("NUMBER", codes(document))

    def test_bool_is_not_a_number(self):
        document = make_document()
        document["upgrades"]["briefcase"]["cost"] = True
        self.assertIn("NUMBER", codes(document))

    def test_ranges(self):
        document = make_document()
        definition = document["upgrades"]["briefcase"]
        definition.update({"cost": -1, "growth": 0.5, "max": 0, "reputation": -2})
        self.assertEqual(codes(document).count("RANGE"), 4)

    def test_rate_range_for_decay(self):
        document = make_document()
        document["upgrades"]["coffee"]["rate"] = 1.5
        self.assertIn("RANGE", codes(document))

    def test_unknown_curve(self):
        document = make_document()
        document["upgrades"]["briefcase"]["curve"] = "wobbly"
        self.assertIn("CURVE", codes(document))

    def test_missing_spot(self):
        document = make_document()
        document["upgrades"]["briefcase"]["spot"] = ""
        self.assertIn("SPOT", codes(document))

    def test_unknown_topic(self):
        document = make_document()
        document["upgrades"]["briefcase"]["topic"] = "nowhere"
        self.assertIn("TOPIC", codes(document))

    def test_rooms_must_be_strings(self):
        document = make_document()
        document["upgrades"]["room_speed"]["rooms"] = [1]
        self.assertIn("ROOMS", codes(document))

    def test_requires_unknown_upgrade(self):
        document = make_document()
        document["upgrades"]["work_ethic"]["requires"] = {"ghost": 1}
        self.assertIn("REQUIRES_UNKNOWN", codes(document))

    def test_requires_itself(self):
        document = make_document()
        document["upgrades"]["work_ethic"]["requires"] = {"work_ethic": 1}
        self.assertIn("REQUIRES_UNKNOWN", codes(document))

    def test_requires_level_beyond_maximum(self):
        document = make_document()
        document["upgrades"]["work_ethic"]["requires"] = {"briefcase": 99}
        self.assertIn("REQUIRES_LEVEL", codes(document))

    def test_requires_must_be_an_object(self):
        document = make_document()
        document["upgrades"]["work_ethic"]["requires"] = []
        self.assertIn("REQUIRES", codes(document))

    def test_duplicate_instance(self):
        document = make_document()
        document["menu"]["rooms"][0]["groups"][0]["entries"].append("track:briefcase")
        self.assertIn("DUPLICATE_REF", codes(document))

    def test_unknown_instance(self):
        document = make_document()
        document["menu"]["rooms"][2]["groups"][0]["entries"].append("track:ghost")
        self.assertIn("UNKNOWN_REF", codes(document))

    def test_room_upgrade_needs_a_room(self):
        document = make_document()
        document["menu"]["rooms"][1]["groups"][0]["entries"].append("track:room_speed")
        self.assertIn("ROOM_REF_NEEDED", codes(document))

    def test_global_upgrade_must_not_have_a_room(self):
        document = make_document()
        document["menu"]["rooms"][1]["groups"][0]["entries"].append("track:briefcase@hall")
        self.assertIn("GLOBAL_REF_WITH_ROOM", codes(document))

    def test_system_entries_are_not_checked_against_upgrades(self):
        self.assertEqual(validation.validate(make_document()), [])

    def test_malformed_menu_shapes(self):
        for broken in ("x", [1], [{"id": "a"}], [{"id": "a", "groups": [{"spot": 1, "entries": []}]}], [{"id": "a", "groups": [{"spot": "s", "entries": [3]}]}]):
            document = make_document()
            document["menu"]["rooms"] = broken
            self.assertIn("MENU_SHAPE", codes(document))
        document = make_document()
        document["menu"]["topics"] = [{"id": "a", "items": "x"}]
        self.assertIn("MENU_SHAPE", codes(document))

    def test_non_object_definition_does_not_break_other_checks(self):
        document = make_document()
        document["upgrades"]["briefcase"] = 5
        document["upgrades"]["work_ethic"]["requires"] = {"briefcase": 1}
        found = codes(document)
        self.assertIn("NOT_AN_OBJECT", found)
        self.assertIn("REQUIRES_LEVEL", found)

    def test_topics_missing_do_not_crash(self):
        document = make_document()
        document["menu"]["topics"] = "x"
        self.assertIn("MENU_SHAPE", codes(document))

    def test_duplicate_topic_item(self):
        document = make_document()
        document["menu"]["topics"][2]["items"].append("track:briefcase")
        self.assertIn("DUPLICATE_TOPIC_ITEM", codes(document))

    def test_unknown_topic_item(self):
        document = make_document()
        document["menu"]["topics"][2]["items"].append("track:ghost")
        self.assertIn("UNKNOWN_REF", codes(document))

    def test_every_upgrade_needs_a_topic_item(self):
        document = make_document()
        document["menu"]["topics"][2]["items"].remove("track:coffee")
        self.assertIn("TOPIC_MISSING", codes(document))

    def test_room_without_placement(self):
        document = make_document()
        document["menu"]["rooms"][3]["groups"][0]["entries"].remove("track:room_speed@tax_services")
        self.assertIn("ROOM_WITHOUT_PLACEMENT", codes(document))

    def test_system_values_must_be_non_negative_numbers(self):
        document = make_document()
        document["system"]["constants"]["DESK_GROWTH"] = -1
        document["system"]["station_kinds"]["review"]["desk_cost"] = "x"
        document["system"]["departments"]["tax_services"]["unlock_cost"] = None
        self.assertEqual(codes(document).count("NUMBER"), 3)

    def test_system_must_be_an_object(self):
        document = make_document()
        document["system"] = []
        self.assertIn("NOT_AN_OBJECT", codes(document))

    def test_text_overrides(self):
        document = make_document()
        document["text_overrides"] = {"A": {"de": "ok"}, "B": {"fr": "non"}, "C": {"de": 5}, "D": "x", "E": {"en": "x" * 5000}}
        self.assertEqual(codes(document).count("TEXT"), 4)

    def test_text_overrides_must_be_an_object(self):
        document = make_document()
        document["text_overrides"] = []
        self.assertIn("NOT_AN_OBJECT", codes(document))


    def area_document(self):
        document = make_document()
        room = document["menu"]["rooms"][0]
        document["areas"] = {"lab": {"room": room["id"], "rects": [[10, 20, 100, 50]]}}
        room["groups"].append({"spot": "area:lab", "entries": []})
        return document

    def test_valid_area(self):
        self.assertEqual(validation.validate(self.area_document()), [])

    def test_area_id_room_and_rect_are_checked(self):
        for mutate, code in (
            (lambda d: d["areas"].update({"Bad Id": d["areas"].pop("lab")}), "AREA_ID"),
            (lambda d: d["areas"]["lab"].update(room="nowhere"), "AREA_ROOM"),
            (lambda d: d["areas"]["lab"].update(rects=[]), "AREA_RECT"),
            (lambda d: d["areas"]["lab"].update(rects=[[0, 0, 0, 5]]), "AREA_RECT"),
            (lambda d: d["areas"]["lab"].update(rects=[[0, 0, "x", 5]]), "AREA_RECT"),
            (lambda d: d["areas"].update(lab=3), "AREA_SHAPE"),
            (lambda d: d.update(areas=[]), "AREA_SHAPE"),
        ):
            document = self.area_document()
            mutate(document)
            self.assertIn(code, codes(document), code)

    def test_spot_of_unknown_area_is_rejected(self):
        document = self.area_document()
        del document["areas"]["lab"]
        self.assertIn("AREA_UNKNOWN", codes(document))
        document = make_document()
        document["upgrades"]["briefcase"]["spot"] = "area:ghost"
        self.assertIn("AREA_UNKNOWN", codes(document))


    def test_valid_models(self):
        document = make_document()
        document["upgrades"]["briefcase"]["cost_model"] = {"mode": "formula", "formula": "cost * growth ^ level"}
        document["upgrades"]["briefcase"]["value_model"] = {"mode": "formula", "formula": "base + step * level"}
        document["upgrades"]["work_ethic"]["cost_model"] = {"mode": "table", "levels": [1.0] * 20}
        document["upgrades"]["work_ethic"]["value_model"] = {"mode": "table", "increments": [0.5] * 20}
        self.assertEqual(validation.validate(document), [])

    def test_model_problems_are_reported(self):
        cases = (
            ({"cost_model": 3}, "MODEL_MODE"),
            ({"cost_model": {"mode": "other"}}, "MODEL_MODE"),
            ({"value_model": {"mode": "formula", "formula": "1 +"}}, "FORMULA"),
            ({"value_model": {"mode": "formula", "formula": "nope"}}, "FORMULA"),
            ({"cost_model": {"mode": "formula", "formula": "1 / (level - 3)"}}, "FORMULA"),
            ({"cost_model": {"mode": "formula", "formula": "level - 5"}}, "FORMULA"),
            ({"cost_model": {"mode": "formula"}}, "FORMULA"),
            ({"cost_model": {"mode": "table", "levels": [1.0, 2.0]}}, "TABLE_LENGTH"),
            ({"cost_model": {"mode": "table", "levels": "x"}}, "TABLE_LENGTH"),
            ({"cost_model": {"mode": "table", "levels": [-1.0] * 10}}, "TABLE_VALUE"),
            ({"value_model": {"mode": "table", "increments": ["a"] * 10}}, "TABLE_VALUE"),
            ({"value_model": {"mode": "table", "increments": [1.0] * 9}}, "TABLE_LENGTH"),
        )
        for patch, code in cases:
            document = make_document()
            document["upgrades"]["briefcase"].update(patch)
            self.assertIn(code, codes(document), patch)

    def test_remembered_formulas_and_history(self):
        document = make_document()
        definition = document["upgrades"]["briefcase"]
        definition["cost_model"] = {"mode": "table", "levels": [1.0] * 10, "formula": "cost * 2 ^ level"}
        definition["formula_history"] = {"cost": ["cost * 2 ^ level", "level"], "value": ["base + level"]}
        self.assertEqual(validation.validate(document), [])

    def test_formula_history_problems_are_reported(self):
        cases = (
            ({"formula_history": []}, "FORMULA_HISTORY"),
            ({"formula_history": {"other": []}}, "FORMULA_HISTORY"),
            ({"formula_history": {"cost": "x"}}, "FORMULA_HISTORY"),
            ({"formula_history": {"cost": [1]}}, "FORMULA_HISTORY"),
            ({"formula_history": {"value": ["  "]}}, "FORMULA_HISTORY"),
            ({"cost_model": {"mode": "table", "levels": [1.0] * 10, "formula": 5}}, "FORMULA"),
        )
        for patch, code in cases:
            document = make_document()
            document["upgrades"]["briefcase"].update(patch)
            self.assertIn(code, codes(document), patch)

    def test_value_table_may_hold_negative_increments(self):
        document = make_document()
        document["upgrades"]["briefcase"]["value_model"] = {"mode": "table", "increments": [-1.0] * 10}
        self.assertEqual(validation.validate(document), [])

    def test_models_are_skipped_when_numbers_are_broken(self):
        document = make_document()
        document["upgrades"]["briefcase"]["cost"] = "x"
        document["upgrades"]["briefcase"]["cost_model"] = {"mode": "table", "levels": []}
        self.assertEqual(codes(document), ["NUMBER"])


class MultiPlacementTests(unittest.TestCase):
    def document_with_group(self, **group):
        document = make_document()
        room = document["menu"]["rooms"][0]
        room["groups"].append({"spot": room["groups"][0]["spot"], "entries": [], **group})
        return document

    def test_valid_subgroup(self):
        document = self.document_with_group(id="extras", title={"de": "Extras", "en": "Extras"})
        self.assertEqual(validation.validate(document), [])

    def test_invalid_subgroups(self):
        cases = (
            {"id": "Bad Id", "title": {"de": "a", "en": "b"}},
            {"id": "ok"},
            {"title": {"de": "a", "en": "b"}},
            {"id": "ok", "title": {"de": "", "en": "b"}},
            {"id": "ok", "title": {"de": "a"}},
            {"id": "ok", "title": "x"},
        )
        for group in cases:
            self.assertIn("MENU_SHAPE", codes(self.document_with_group(**group)), group)

    def test_duplicate_subgroup(self):
        document = self.document_with_group(id="dup", title={"de": "a", "en": "b"})
        room = document["menu"]["rooms"][0]
        room["groups"].append({"spot": room["groups"][0]["spot"], "id": "dup", "title": {"de": "a", "en": "b"}, "entries": []})
        self.assertIn("GROUP_DUPLICATE", codes(document))

    def test_same_upgrade_in_two_rooms_is_allowed(self):
        document = make_document()
        ref = document["menu"]["rooms"][0]["groups"][0]["entries"][0]
        other = document["menu"]["rooms"][1]
        other["groups"][0]["entries"].append(ref)
        self.assertNotIn("DUPLICATE_REF", codes(document))

    def test_same_upgrade_twice_in_one_area_is_rejected(self):
        document = self.document_with_group(id="again", title={"de": "a", "en": "b"})
        ref = document["menu"]["rooms"][0]["groups"][0]["entries"][0]
        document["menu"]["rooms"][0]["groups"][-1]["entries"].append(ref)
        self.assertIn("DUPLICATE_REF", codes(document))


if __name__ == "__main__":
    unittest.main()
