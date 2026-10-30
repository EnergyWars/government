import json
import unittest
from pathlib import Path

from upgrade_editor import model, validation
from .fixtures import make_document

REAL_DOCUMENT = Path(__file__).resolve().parents[4] / "data" / "upgrades.json"


class ParseRefTest(unittest.TestCase):
    def test_global_track(self):
        self.assertEqual(model.parse_ref("track:briefcase"), ("briefcase", ""))

    def test_room_track(self):
        self.assertEqual(model.parse_ref("track:room_speed@hall"), ("room_speed", "hall"))

    def test_system_entry_is_not_a_track(self):
        self.assertEqual(model.parse_ref("desk:a/b"), (None, ""))


class PlacementTest(unittest.TestCase):
    def test_placements_hold_room_spot_and_index(self):
        placed = model.placements(make_document())
        self.assertEqual(placed["track:work_ethic"], [("player", "player", 1)])
        self.assertEqual(placed["track:room_speed@tax_services"], [("tax_services", "dept:tax_services", 0)])

    def test_topic_items(self):
        topics = model.topic_of_items(make_document())
        self.assertEqual(topics["sys:desk"], ["speed"])


class MultiPlacementModelTest(unittest.TestCase):
    def extra(self):
        document = make_document()
        document["menu"]["rooms"][2]["groups"][0]["entries"].append("track:briefcase")
        return document

    def test_group_keys_include_the_subgroup_id(self):
        self.assertEqual(model.group_key({"spot": "a", "entries": []}), "a")
        self.assertEqual(model.group_key({"spot": "a", "id": "x", "entries": []}), "a#x")
        self.assertEqual(model.group_id({"id": "x"}), "x")
        self.assertEqual(model.group_id({}), "")
        self.assertEqual(model.group_id(None), "")

    def test_one_upgrade_has_several_placements(self):
        placed = model.placements(self.extra())
        self.assertEqual(len(placed["track:briefcase"]), 2)

    def test_normalise_keeps_the_primary_spot(self):
        document = self.extra()
        result = model.normalise(document)
        self.assertEqual(result["upgrades"]["briefcase"]["spot"], "player")
        self.assertNotIn("enabled", result["upgrades"]["briefcase"])

    def test_normalise_moves_the_spot_to_a_remaining_placement(self):
        document = self.extra()
        document["menu"]["rooms"][0]["groups"][0]["entries"].remove("track:briefcase")
        result = model.normalise(document)
        self.assertEqual(result["upgrades"]["briefcase"]["spot"], "coffee_machine")

    def test_unplaced_upgrade_is_disabled(self):
        document = make_document()
        document["menu"]["rooms"][0]["groups"][0]["entries"].remove("track:briefcase")
        self.assertIs(model.normalise(document)["upgrades"]["briefcase"]["enabled"], False)


class NormaliseTest(unittest.TestCase):
    def test_numbers_get_canonical_types(self):
        document = make_document()
        document["upgrades"]["briefcase"]["cost"] = 150
        document["upgrades"]["briefcase"]["max"] = 10.0
        document["upgrades"]["work_ethic"]["requires"] = {"briefcase": 2.0}
        result = model.normalise(document)
        self.assertIsInstance(result["upgrades"]["briefcase"]["cost"], float)
        self.assertIsInstance(result["upgrades"]["briefcase"]["max"], int)
        self.assertIsInstance(result["upgrades"]["work_ethic"]["requires"]["briefcase"], int)

    def test_input_is_not_modified(self):
        document = make_document()
        before = json.dumps(document)
        model.normalise(document)
        self.assertEqual(json.dumps(document), before)

    def test_topic_follows_the_topic_tree(self):
        document = make_document()
        document["menu"]["topics"][2]["items"].remove("track:coffee")
        document["menu"]["topics"][1]["items"].append("track:coffee")
        self.assertEqual(model.normalise(document)["upgrades"]["coffee"]["topic"], "speed")

    def test_global_spot_follows_its_group(self):
        document = make_document()
        document["menu"]["rooms"][2]["groups"][0]["entries"].remove("track:coffee")
        document["menu"]["rooms"][1]["groups"].append({"spot": "entrance", "entries": ["track:coffee"]})
        result = model.normalise(document)
        self.assertEqual(result["upgrades"]["coffee"]["spot"], "entrance")
        self.assertNotIn("enabled", result["upgrades"]["coffee"])

    def test_unplaced_global_upgrade_is_disabled(self):
        document = make_document()
        document["menu"]["rooms"][2]["groups"][0]["entries"].clear()
        self.assertFalse(model.normalise(document)["upgrades"]["coffee"]["enabled"])

    def test_replaced_upgrade_is_enabled_again(self):
        document = make_document()
        document["upgrades"]["coffee"]["enabled"] = False
        self.assertNotIn("enabled", model.normalise(document)["upgrades"]["coffee"])

    def test_room_list_follows_the_instances(self):
        document = make_document()
        document["menu"]["rooms"][3]["groups"][0]["entries"].remove("track:room_speed@tax_services")
        document["menu"]["rooms"][2]["groups"].append({"spot": "dept:kitchen", "entries": ["track:room_speed@kitchen"]})
        self.assertEqual(model.normalise(document)["upgrades"]["room_speed"]["rooms"], ["hall", "kitchen"])

    def test_room_upgrade_without_instances_keeps_an_empty_room_list(self):
        document = make_document()
        for room in document["menu"]["rooms"]:
            for group in room["groups"]:
                group["entries"] = [ref for ref in group["entries"] if not ref.startswith("track:room_speed")]
        result = model.normalise(document)
        self.assertEqual(result["upgrades"]["room_speed"]["rooms"], [])
        self.assertNotIn("enabled", result["upgrades"]["room_speed"])

    def test_defaults_are_added(self):
        document = make_document()
        del document["system"]
        del document["text_overrides"]
        result = model.normalise(document)
        self.assertEqual(result["system"], {})
        self.assertEqual(result["text_overrides"], {})

    def test_normalise_is_idempotent(self):
        once = model.normalise(make_document())
        self.assertEqual(model.normalise(once), once)


@unittest.skipUnless(REAL_DOCUMENT.is_file(), "game document missing")
class RealDocumentTest(unittest.TestCase):
    def setUp(self):
        self.document = json.loads(REAL_DOCUMENT.read_text(encoding="utf-8"))

    def test_real_document_is_valid(self):
        self.assertEqual(validation.validate(self.document), [])

    def test_real_document_is_already_normalised(self):
        self.assertEqual(model.normalise(self.document), self.document)


    def test_normalise_converts_table_values_to_floats(self):
        document = make_document()
        document["upgrades"]["briefcase"]["cost_model"] = {"mode": "table", "levels": [1] * 10}
        document["upgrades"]["briefcase"]["value_model"] = {"mode": "table", "increments": [2] * 10}
        result = model.normalise(document)
        self.assertTrue(all(isinstance(value, float) for value in result["upgrades"]["briefcase"]["cost_model"]["levels"]))
        self.assertTrue(all(isinstance(value, float) for value in result["upgrades"]["briefcase"]["value_model"]["increments"]))
        document["upgrades"]["briefcase"]["cost_model"] = {"mode": "formula", "formula": "1"}
        self.assertEqual(model.normalise(document)["upgrades"]["briefcase"]["cost_model"], {"mode": "formula", "formula": "1"})


class RoomOverrideNormaliseTest(unittest.TestCase):
    def test_overrides_are_normalised_and_pruned(self):
        document = make_document()
        document["upgrades"]["room_speed"]["room_overrides"] = {"hall": {"max": 5.0, "cost": 3}, "gone": {"cost": 1.0}}
        normalised = model.normalise(document)
        overrides = normalised["upgrades"]["room_speed"]["room_overrides"]
        self.assertEqual(overrides, {"hall": {"max": 5, "cost": 3.0}})
        self.assertIsInstance(overrides["hall"]["max"], int)
        self.assertIsInstance(overrides["hall"]["cost"], float)

    def test_empty_overrides_disappear(self):
        document = make_document()
        document["upgrades"]["room_speed"]["room_overrides"] = {"gone": {"cost": 1.0}}
        self.assertNotIn("room_overrides", model.normalise(document)["upgrades"]["room_speed"])
