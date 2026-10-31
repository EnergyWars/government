import copy
import unittest

from upgrade_editor import changes
from .fixtures import make_document


def kinds(result):
    return [change["kind"] for change in result]


class ChangesTest(unittest.TestCase):
    def setUp(self):
        self.original = make_document()
        self.edited = make_document()

    def test_identical_documents_have_no_changes(self):
        self.assertEqual(changes.diff(self.original, self.edited), [])

    def test_parameter_change(self):
        self.edited["upgrades"]["briefcase"]["cost"] = 99.0
        result = changes.diff(self.original, self.edited)
        self.assertEqual(result, [{"kind": "param", "id": "briefcase", "field": "cost", "before": 150.0, "after": 99.0}])

    def test_added_parameter(self):
        self.edited["upgrades"]["briefcase"]["reputation"] = 4.0
        self.assertEqual(changes.diff(self.original, self.edited)[0]["before"], None)

    def test_integer_and_float_are_equal(self):
        self.edited["upgrades"]["briefcase"]["cost"] = 150
        self.assertEqual(changes.diff(self.original, self.edited), [])

    def test_enabled_change(self):
        self.edited["upgrades"]["coffee"]["enabled"] = False
        self.assertEqual(kinds(changes.diff(self.original, self.edited)), ["enabled"])

    def test_removed_upgrade(self):
        del self.edited["upgrades"]["coffee"]
        self.assertIn("removed_upgrade", kinds(changes.diff(self.original, self.edited)))

    def test_placement_move(self):
        self.edited["menu"]["rooms"][2]["groups"][0]["entries"].remove("track:coffee")
        self.edited["menu"]["rooms"][1]["groups"][0]["entries"].append("track:coffee")
        result = [change for change in changes.diff(self.original, self.edited) if change["kind"] == "placement"]
        self.assertEqual(result[0]["before"], {"room": "kitchen", "spot": "coffee_machine"})
        self.assertEqual(result[0]["after"], {"room": "hall", "spot": "dept:hall"})

    def test_placement_removed(self):
        self.edited["menu"]["rooms"][2]["groups"][0]["entries"].clear()
        result = [change for change in changes.diff(self.original, self.edited) if change["kind"] == "placement"]
        self.assertIsNone(result[0]["after"])

    def test_room_order(self):
        self.edited["menu"]["rooms"].reverse()
        self.assertIn("room_order", kinds(changes.diff(self.original, self.edited)))

    def test_group_order(self):
        self.original["menu"]["rooms"][1]["groups"].append({"spot": "entrance", "entries": []})
        self.edited = __import__("copy").deepcopy(self.original)
        self.edited["menu"]["rooms"][1]["groups"].reverse()
        self.assertIn("group_order", kinds(changes.diff(self.original, self.edited)))

    def test_entry_order(self):
        self.edited["menu"]["rooms"][0]["groups"][0]["entries"].reverse()
        result = changes.diff(self.original, self.edited)
        self.assertEqual(kinds(result), ["entry_order"])
        self.assertEqual(result[0]["after"], ["track:work_ethic", "track:briefcase"])

    def test_topic_move_and_order(self):
        self.edited["menu"]["topics"][2]["items"].remove("track:coffee")
        self.edited["menu"]["topics"][1]["items"].append("track:coffee")
        self.edited["menu"]["topics"].reverse()
        result = changes.diff(self.original, self.edited)
        self.assertIn("topic", kinds(result))
        self.assertIn("topic_order", kinds(result))

    def test_system_changes(self):
        self.edited["system"]["constants"]["DESK_GROWTH"] = 3.0
        self.edited["system"]["station_kinds"]["review"]["desk_cost"] = 130.0
        self.edited["system"]["departments"]["tax_services"]["unlock_cost"] = 900.0
        result = changes.diff(self.original, self.edited)
        self.assertEqual([change["section"] for change in result], ["constants", "station_kinds", "departments"])

    def test_text_changes(self):
        self.original["text_overrides"] = {"TRACK_COFFEE": {"de": "Alt"}}
        self.edited["text_overrides"] = {"TRACK_COFFEE": {"de": "Neu", "en": "New"}}
        result = changes.diff(self.original, self.edited)
        self.assertEqual([(change["language"], change["before"], change["after"]) for change in result], [("de", "Alt", "Neu"), ("en", None, "New")])


    def test_area_changes(self):
        base = make_document()
        edited = copy.deepcopy(base)
        edited["areas"] = {"lab": {"room": "player", "rects": [[0, 0, 5, 5]]}}
        self.assertEqual(changes.diff(base, edited), [{"kind": "area_added", "id": "lab", "after": edited["areas"]["lab"]}])
        self.assertEqual(changes.diff(edited, base), [{"kind": "area_removed", "id": "lab", "before": edited["areas"]["lab"]}])
        moved = copy.deepcopy(edited)
        moved["areas"]["lab"]["rects"] = [[1, 1, 5, 5]]
        self.assertEqual(changes.diff(edited, moved)[0]["kind"], "area_changed")


    def test_spot_rect_changes(self):
        base = make_document()
        edited = copy.deepcopy(base)
        edited["spot_rects"] = {"seating": [[1, 2, 3, 4]]}
        self.assertEqual(changes.diff(base, edited), [{"kind": "spot_rects", "spot": "seating", "before": None, "after": [[1, 2, 3, 4]]}])
        self.assertEqual(changes.diff(edited, base), [{"kind": "spot_rects", "spot": "seating", "before": [[1, 2, 3, 4]], "after": None}])
        moved = copy.deepcopy(edited)
        moved["spot_rects"]["seating"][0] = [5, 2, 3, 4]
        self.assertEqual(changes.diff(edited, moved)[0]["after"], [[5, 2, 3, 4]])
        removed = copy.deepcopy(edited)
        removed["spot_rects"]["seating"] = []
        self.assertEqual(changes.diff(edited, removed)[0]["after"], [])
        self.assertEqual(changes.diff(edited, copy.deepcopy(edited)), [])


class MultiPlacementChangesTest(unittest.TestCase):
    def test_extra_placement_is_reported(self):
        original = make_document()
        edited = make_document()
        edited["menu"]["rooms"][2]["groups"][0]["entries"].append("track:briefcase")
        result = changes.diff(original, edited)
        self.assertEqual(kinds(result), ["placements"])
        self.assertEqual(result[0]["added"], [{"room": "kitchen", "spot": "coffee_machine"}])
        self.assertEqual(result[0]["removed"], [])

    def test_removed_extra_placement_is_reported(self):
        original = make_document()
        original["menu"]["rooms"][2]["groups"][0]["entries"].append("track:briefcase")
        edited = make_document()
        result = changes.diff(original, edited)
        self.assertEqual(kinds(result), ["placements"])
        self.assertEqual(result[0]["removed"], [{"room": "kitchen", "spot": "coffee_machine"}])

    def test_subgroup_changes_are_reported(self):
        original = make_document()
        edited = make_document()
        edited["menu"]["rooms"][2]["groups"].append({"spot": "coffee_machine", "id": "extras", "title": {"de": "A", "en": "B"}, "entries": []})
        added = [change for change in changes.diff(original, edited) if change["kind"] == "group"]
        self.assertEqual(added, [{"kind": "group", "room": "kitchen", "key": "coffee_machine#extras", "before": None, "after": {"de": "A", "en": "B"}}])
        again = copy.deepcopy(edited)
        again["menu"]["rooms"][2]["groups"][-1]["title"] = {"de": "A", "en": "C"}
        renamed = [change for change in changes.diff(edited, again) if change["kind"] == "group"]
        self.assertEqual(renamed[0]["before"], {"de": "A", "en": "B"})
        self.assertEqual(renamed[0]["after"], {"de": "A", "en": "C"})
        removed = [change for change in changes.diff(edited, original) if change["kind"] == "group"]
        self.assertEqual(removed[0]["after"], None)

    def test_subgroup_order_is_tracked_by_key(self):
        original = make_document()
        original["menu"]["rooms"][2]["groups"].append({"spot": "coffee_machine", "id": "a", "title": {"de": "A", "en": "A"}, "entries": []})
        edited = copy.deepcopy(original)
        edited["menu"]["rooms"][2]["groups"].reverse()
        self.assertIn("group_order", kinds(changes.diff(original, edited)))


if __name__ == "__main__":
    unittest.main()


class RoomOverrideChangesTest(unittest.TestCase):
    def test_override_states(self):
        original = make_document()
        edited = make_document()
        edited["upgrades"]["room_speed"]["room_overrides"] = {"hall": {"cost": 9.0}}
        self.assertEqual(changes.diff(original, edited), [{"kind": "room_override", "id": "room_speed", "room": "hall", "state": "added"}])
        changed = copy.deepcopy(edited)
        changed["upgrades"]["room_speed"]["room_overrides"]["hall"]["cost"] = 10.0
        self.assertEqual(changes.diff(edited, changed)[0]["state"], "changed")
        self.assertEqual(changes.diff(edited, original)[0]["state"], "removed")
