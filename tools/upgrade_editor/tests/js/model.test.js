import test from "node:test";
import assert from "node:assert/strict";
import { consistency, loadReal } from "./data.js";
import * as model from "../../web/js/model.js";

const real = loadReal();
const { context } = real;
const fresh = () => structuredClone(real.document);

test("the real document is consistent", () => {
  assert.deepEqual(consistency(real.document, context), []);
});

test("every menu reference becomes exactly one entry", () => {
  const entries = model.buildEntries(real.document, context);
  const refs = real.document.menu.rooms.flatMap((room) => room.groups.flatMap((group) => group.entries));
  assert.equal(entries.length, refs.length);
  assert.equal(new Set(entries.map((entry) => entry.id)).size, entries.length);
});

test("visibility of every spot matches the game", () => {
  const entries = model.buildEntries(real.document, context);
  let checked = 0;
  for (const [spot, info] of Object.entries(context.spots)) {
    assert.deepEqual(model.visibleAt(entries, spot).map((entry) => entry.id), info.visible, spot);
    checked += 1;
  }
  assert.ok(checked > 100);
});

test("entries know their room, spot, topic and fixed state", () => {
  const entries = model.buildEntries(real.document, context);
  const briefcase = entries.find((entry) => entry.id === "track:briefcase");
  assert.deepEqual({ room: briefcase.room, spot: briefcase.spot, topic: briefcase.topic, kind: briefcase.kind, fixed: briefcase.fixed }, { room: "player", spot: "player", topic: "player", kind: "track", fixed: undefined });
  const desk = entries.find((entry) => entry.kind === "desk");
  assert.equal(desk.fixed, true);
  assert.ok(desk.topic);
  const lead = entries.find((entry) => entry.id === "track:team_lead@intake");
  assert.equal(lead.room, "hall");
  assert.equal(lead.roomId, "intake");
});

test("groups follow the entry order", () => {
  const groups = model.groupsOf(model.visibleAt(model.buildEntries(real.document, context), "room:hall"));
  assert.ok(groups.length > 3);
  assert.equal(new Set(groups.map((group) => group.spot)).size, groups.length);
});

test("ref helpers", () => {
  assert.deepEqual(model.parseRef("track:room_speed@hall"), { kind: "track", target: "room_speed", upgradeId: "room_speed", roomId: "hall" });
  assert.deepEqual(model.parseRef("desk:a/b"), { kind: "desk", target: "a/b", upgradeId: null, roomId: "" });
  assert.deepEqual(model.parseRef("plain"), { kind: "plain", target: "", upgradeId: null, roomId: "" });
  assert.equal(model.refOf("a", "b"), "track:a@b");
  assert.equal(model.refOf("a", ""), "track:a");
  assert.equal(model.defRef("track", "room_speed@hall"), "track:room_speed");
  assert.equal(model.defRef("staff", "runners"), "sys:staff:runners");
  assert.equal(model.defRef("desk", "x"), "sys:desk");
});

test("spot rooms for static and dynamic spots", () => {
  assert.equal(model.spotRoom("coffee_machine", context), "kitchen");
  assert.equal(model.spotRoom("dept:housing", context), "housing");
  assert.equal(model.spotRoom("tube:mail", context), "mail");
  assert.equal(model.spotRoom("shredder:housing", context), "housing");
  assert.equal(model.spotRoom("station:shared/mailroom", context), "mail");
  assert.equal(model.spotRoom("trays:tax_services/review", context), "tax_services");
  assert.equal(model.spotRoom("lead:intake", { ...context, spots: {} }), "hall");
  assert.equal(model.spotRoom("lead:housing", { ...context, spots: {} }), "housing");
  assert.equal(model.spotRoom("room:player", { ...context, spots: {} }), "player");
  assert.equal(model.spotRoom("unknown", { ...context, spots: {} }), "");
});

test("template spots", () => {
  const speed = real.document.upgrades.room_speed;
  assert.equal(model.templateSpot(speed, "housing", context), "dept:housing");
  assert.equal(model.templateSpot(speed, "hall", context), "room:hall");
  assert.equal(model.templateSpot(real.document.upgrades.shredder, "housing", context), "shredder:housing");
  assert.equal(model.templateSpot(real.document.upgrades.briefcase, "", context), "player");
  assert.equal(model.menuRoomOf(real.document.upgrades.team_lead, "pickup", context), "hall");
});

test("allowed rooms prefer the context and fall back to the current list", () => {
  assert.ok(model.allowedRooms("room_speed", real.document.upgrades.room_speed, context).includes("customs"));
  assert.deepEqual(model.allowedRooms("x", { rooms: ["a"] }, context), ["a"]);
  assert.deepEqual(model.allowedRooms("x", {}, context), []);
  assert.deepEqual(model.roomCandidates("team_lead", real.document.upgrades.team_lead, "hall", context), ["intake", "pickup"].filter((room) => context.allowed_rooms.team_lead.includes(room)));
});

test("moving a global upgrade into another room's group", () => {
  const result = model.moveEntry(fresh(), context, "track:briefcase", { room: "kitchen", spot: "kitchen", index: 0 });
  assert.equal(result.error, undefined);
  assert.equal(result.document.upgrades.briefcase.spot, "kitchen");
  const location = model.findLocation(result.document, "track:briefcase");
  assert.deepEqual([location.room, location.spot, location.index], ["kitchen", "kitchen", 0]);
  assert.deepEqual(consistency(result.document, context), []);
});

test("moving into a group of the wrong room fails", () => {
  const result = model.moveEntry(fresh(), context, "track:briefcase", { room: "kitchen", spot: "tickets", index: 0 });
  assert.equal(result.error, "SPOT_ROOM_MISMATCH");
});

test("reordering inside a group", () => {
  const document = fresh();
  const group = document.menu.rooms.find((room) => room.id === "player").groups[0];
  const [first, second, third] = group.entries;
  const forward = model.moveEntry(document, context, first, { room: "player", spot: group.spot, index: 3 });
  assert.deepEqual(forward.document.menu.rooms.find((room) => room.id === "player").groups[0].entries.slice(0, 3), [second, third, first]);
  const backward = model.moveEntry(document, context, third, { room: "player", spot: group.spot, index: 0 });
  assert.deepEqual(backward.document.menu.rooms.find((room) => room.id === "player").groups[0].entries.slice(0, 3), [third, first, second]);
});

test("moving a room upgrade to another room changes its instance", () => {
  const document = fresh();
  document.upgrades.room_speed.rooms = document.upgrades.room_speed.rooms.filter((room) => room !== "housing");
  const stripped = model.removeEntry(real.document, "track:room_speed@housing").document;
  const moved = model.moveEntry(stripped, context, "track:room_speed@tax_services", { room: "housing", spot: "dept:housing", index: 0 });
  assert.equal(moved.ref, "track:room_speed@housing");
  assert.ok(!moved.document.upgrades.room_speed.rooms.includes("tax_services"));
  assert.ok(moved.document.upgrades.room_speed.rooms.includes("housing"));
  assert.deepEqual(consistency(moved.document, context), []);
});

test("moving a room upgrade into a room it already serves fails", () => {
  const result = model.moveEntry(fresh(), context, "track:room_speed@tax_services", { room: "housing", spot: "dept:housing", index: 0 });
  assert.equal(result.error, "ROOM_NOT_AVAILABLE");
});

test("reordering a room upgrade inside its room keeps the instance", () => {
  const document = fresh();
  const location = model.findLocation(document, "track:room_speed@tax_services");
  const result = model.moveEntry(document, context, "track:room_speed@tax_services", { room: "tax_services", spot: location.spot, index: 0 });
  assert.equal(result.ref, "track:room_speed@tax_services");
  assert.equal(model.findLocation(result.document, result.ref).index, 0);
});

test("system entries can only be reordered inside their group", () => {
  const document = fresh();
  const desk = model.buildEntries(document, context).find((entry) => entry.kind === "desk");
  const location = model.findLocation(document, desk.id);
  assert.equal(model.moveEntry(document, context, desk.id, { room: "player", spot: "player", index: 0 }).error, "SYSTEM_FIXED");
  const reordered = model.moveEntry(document, context, desk.id, { room: location.room, spot: location.spot, index: 0 });
  assert.equal(model.findLocation(reordered.document, desk.id).index, 0);
  assert.equal(model.removeEntry(document, desk.id).error, "SYSTEM_FIXED");
});

test("unknown references report errors", () => {
  assert.equal(model.moveEntry(fresh(), context, "track:ghost", { room: "player", spot: "player", index: 0 }).error, "NOT_PLACED");
  assert.equal(model.removeEntry(fresh(), "track:ghost").error, "NOT_PLACED");
  assert.equal(model.addEntry(fresh(), context, "ghost", { room: "player", spot: "player", index: 0 }).error, "UNKNOWN_UPGRADE");
});

test("removing a global upgrade disables it", () => {
  const result = model.removeEntry(fresh(), "track:briefcase");
  assert.equal(result.document.upgrades.briefcase.enabled, false);
  assert.equal(model.findLocation(result.document, "track:briefcase"), null);
  assert.deepEqual(consistency(result.document, context), []);
  assert.ok(model.unplacedUpgrades(result.document).includes("briefcase"));
});

test("removing a room instance drops the room from the list", () => {
  const result = model.removeEntry(fresh(), "track:room_speed@housing");
  assert.ok(!result.document.upgrades.room_speed.rooms.includes("housing"));
  assert.deepEqual(consistency(result.document, context), []);
});

test("adding back a disabled global upgrade", () => {
  const removed = model.removeEntry(fresh(), "track:briefcase").document;
  const added = model.addEntry(removed, context, "briefcase", { room: "kitchen", spot: "coffee_machine", index: 1 });
  assert.equal(added.document.upgrades.briefcase.spot, "coffee_machine");
  assert.equal(added.document.upgrades.briefcase.enabled, undefined);
  assert.equal(model.findLocation(added.document, "track:briefcase").index, 1);
  assert.deepEqual(consistency(added.document, context), []);
});

test("adding an already placed global upgrade adds a second placement", () => {
  const added = model.addEntry(fresh(), context, "briefcase", { room: "kitchen", spot: "kitchen", index: 0 });
  assert.deepEqual(model.occurrences(added.document, "track:briefcase").map((item) => item.room).sort(), ["kitchen", "player"]);
});

test("adding a global upgrade to a mismatching spot fails", () => {
  const removed = model.removeEntry(fresh(), "track:briefcase").document;
  assert.equal(model.addEntry(removed, context, "briefcase", { room: "kitchen", spot: "tickets", index: 0 }).error, "SPOT_ROOM_MISMATCH");
});

test("adding a room upgrade picks a free room of the target menu room", () => {
  const removed = model.removeEntry(fresh(), "track:room_speed@housing").document;
  const added = model.addEntry(removed, context, "room_speed", { room: "housing", spot: "dept:housing", index: 0 });
  assert.equal(added.ref, "track:room_speed@housing");
  assert.ok(added.document.upgrades.room_speed.rooms.includes("housing"));
  assert.deepEqual(consistency(added.document, context), []);
  assert.equal(model.addEntry(added.document, context, "room_speed", { room: "housing", spot: "dept:housing", index: 0 }).error, "ROOM_NOT_AVAILABLE");
  assert.equal(model.addEntry(removed, context, "room_speed", { room: "player", spot: "room:player", index: 0 }).error, "ROOM_NOT_AVAILABLE");
});

test("lead upgrades choose between intake and pickup inside the hall", () => {
  const removed = model.removeEntry(model.removeEntry(fresh(), "track:team_lead@intake").document, "track:team_lead@pickup").document;
  const first = model.addEntry(removed, context, "team_lead", { room: "hall", spot: "lead:intake", index: 0 });
  assert.equal(first.ref, "track:team_lead@intake");
  const second = model.addEntry(first.document, context, "team_lead", { room: "hall", spot: "lead:pickup", index: 0 });
  assert.equal(second.ref, "track:team_lead@pickup");
  assert.equal(model.addEntry(second.document, context, "team_lead", { room: "hall", spot: "lead:pickup", index: 0 }).error, "ROOM_NOT_AVAILABLE");
});

test("operations never modify their input", () => {
  const document = fresh();
  const before = JSON.stringify(document);
  model.moveEntry(document, context, "track:briefcase", { room: "kitchen", spot: "kitchen", index: 0 });
  model.removeEntry(document, "track:briefcase");
  model.addEntry(document, context, "sneakers", { room: "kitchen", spot: "kitchen", index: 0 });
  model.moveGroup(document, "hall", "tickets", 0);
  model.moveRoom(document, "hall", 0);
  model.moveTopic(document, "speed", 0);
  model.moveTopicItem(document, "track:briefcase", "speed", 0);
  model.updateUpgrade(document, "briefcase", { cost: 1 });
  model.setSystemValue(document, "constants", "DESK_GROWTH", "", 9);
  model.setText(document, "A", "de", "x", "y");
  assert.equal(JSON.stringify(document), before);
});

test("moving groups and rooms", () => {
  const document = fresh();
  const hall = document.menu.rooms.find((room) => room.id === "hall");
  const spots = hall.groups.map((group) => group.spot);
  const moved = model.moveGroup(document, "hall", spots[0], spots.length);
  assert.deepEqual(moved.document.menu.rooms.find((room) => room.id === "hall").groups.map((group) => group.spot), [...spots.slice(1), spots[0]]);
  assert.equal(model.moveGroup(document, "hall", "nowhere", 0).error, "NOT_PLACED");
  assert.equal(model.moveGroup(document, "ghost", "x", 0).error, "NOT_PLACED");
  const rooms = document.menu.rooms.map((room) => room.id);
  assert.deepEqual(model.moveRoom(document, rooms[2], 0).document.menu.rooms.map((room) => room.id).slice(0, 3), [rooms[2], rooms[0], rooms[1]]);
  assert.equal(model.moveRoom(document, "ghost", 0).error, "NOT_PLACED");
});

test("moving topics and topic items", () => {
  const document = fresh();
  const topics = document.menu.topics.map((topic) => topic.id);
  assert.deepEqual(model.moveTopic(document, topics[3], 0).document.menu.topics.map((topic) => topic.id).slice(0, 2), [topics[3], topics[0]]);
  assert.equal(model.moveTopic(document, "ghost", 0).error, "NOT_PLACED");
  const moved = model.moveTopicItem(document, "track:briefcase", "speed", 1);
  assert.equal(moved.document.upgrades.briefcase.topic, "speed");
  assert.equal(moved.document.menu.topics.find((topic) => topic.id === "speed").items[1], "track:briefcase");
  assert.ok(!moved.document.menu.topics.find((topic) => topic.id === "player").items.includes("track:briefcase"));
  assert.deepEqual(consistency(moved.document, context), []);
  assert.equal(model.moveTopicItem(document, "track:briefcase", "ghost", 0).error, "NOT_PLACED");
});

test("reordering an item inside one topic", () => {
  const document = fresh();
  const items = document.menu.topics.find((topic) => topic.id === "player").items;
  const result = model.moveTopicItem(document, items[0], "player", items.length);
  const next = result.document.menu.topics.find((topic) => topic.id === "player").items;
  assert.equal(next[next.length - 1], items[0]);
  assert.equal(next.length, items.length);
  const appended = model.moveTopicItem(document, "sys:desk", "player");
  assert.equal(appended.document.menu.topics.find((topic) => topic.id === "player").items.at(-1), "sys:desk");
});

test("moveInList semantics", () => {
  assert.deepEqual(model.moveInList([1, 2, 3, 4], 0, 3), [2, 3, 1, 4]);
  assert.deepEqual(model.moveInList([1, 2, 3, 4], 3, 1), [1, 4, 2, 3]);
  assert.deepEqual(model.moveInList([1, 2, 3], 1, 99), [1, 3, 2]);
});

test("updating upgrades, system values and texts", () => {
  const document = fresh();
  const changed = model.updateUpgrade(document, "briefcase", { cost: 99, reputation: 3 });
  assert.equal(changed.upgrades.briefcase.cost, 99);
  assert.equal(changed.upgrades.briefcase.reputation, 3);
  const cleared = model.updateUpgrade(changed, "briefcase", { reputation: undefined });
  assert.ok(!("reputation" in cleared.upgrades.briefcase));
  assert.equal(model.setSystemValue(document, "constants", "DESK_GROWTH", "", 3).system.constants.DESK_GROWTH, 3);
  assert.equal(model.setSystemValue(document, "departments", "housing", "unlock_cost", 5).system.departments.housing.unlock_cost, 5);
  const blank = { ...document, system: undefined };
  assert.equal(model.setSystemValue(blank, "station_kinds", "review", "desk_cost", 7).system.station_kinds.review.desk_cost, 7);
  assert.equal(model.setSystemValue(blank, "constants", "A", "", 1).system.constants.A, 1);
  const withText = model.setText(document, "TRACK_BRIEFCASE", "de", "Koffer", "Aktentasche");
  assert.deepEqual(withText.text_overrides, { TRACK_BRIEFCASE: { de: "Koffer" } });
  const both = model.setText(withText, "TRACK_BRIEFCASE", "en", "Case", "Briefcase");
  assert.deepEqual(both.text_overrides.TRACK_BRIEFCASE, { de: "Koffer", en: "Case" });
  const reverted = model.setText(both, "TRACK_BRIEFCASE", "de", "Aktentasche", "Aktentasche");
  assert.deepEqual(reverted.text_overrides.TRACK_BRIEFCASE, { en: "Case" });
  const empty = model.setText(reverted, "TRACK_BRIEFCASE", "en", "Briefcase", "Briefcase");
  assert.deepEqual(empty.text_overrides, {});
  const missing = model.setText({ schema: 1 }, "A", "de", "x", "y");
  assert.deepEqual(missing.text_overrides, { A: { de: "x" } });
});

test("placementOf is findLocation", () => {
  assert.equal(model.placementOf(real.document, "track:briefcase").room, "player");
  assert.equal(model.placementOf(real.document, "track:ghost"), null);
});

test("isRoomUpgrade and topicOfRef", () => {
  assert.equal(model.isRoomUpgrade(real.document.upgrades.room_speed), true);
  assert.equal(model.isRoomUpgrade(real.document.upgrades.briefcase), false);
  assert.equal(model.topicOfRef(real.document, "track:briefcase"), "player");
  assert.equal(model.topicOfRef(real.document, "track:ghost"), "");
});

test("adding a room instance for a specific room", () => {
  const removed = model.removeEntry(fresh(), "track:team_lead@pickup").document;
  const added = model.addRoomInstance(removed, context, "team_lead", "pickup");
  assert.equal(added.ref, "track:team_lead@pickup");
  assert.ok(added.document.upgrades.team_lead.rooms.includes("pickup"));
  assert.equal(model.findLocation(added.document, added.ref).room, "hall");
  assert.deepEqual(consistency(added.document, context), []);
  assert.equal(model.addRoomInstance(added.document, context, "team_lead", "pickup").error, "ROOM_NOT_AVAILABLE");
  assert.equal(model.addRoomInstance(removed, context, "team_lead", "player").error, "ROOM_NOT_AVAILABLE");
  assert.equal(model.addRoomInstance(removed, context, "briefcase", "hall").error, "UNKNOWN_UPGRADE");
  assert.equal(model.addRoomInstance(removed, context, "ghost", "hall").error, "UNKNOWN_UPGRADE");
});

test("adding a room instance to a room whose group does not exist yet creates it", () => {
  const removed = model.removeEntry(fresh(), "track:shredder@housing").document;
  const room = removed.menu.rooms.find((candidate) => candidate.id === "housing");
  room.groups = room.groups.filter((group) => group.spot !== "shredder:housing");
  const added = model.addRoomInstance(removed, context, "shredder", "housing");
  assert.ok(added.document.menu.rooms.find((candidate) => candidate.id === "housing").groups.some((group) => group.spot === "shredder:housing"));
});

test("every spot of the game has a menu group in its room", () => {
  const groups = new Map(real.document.menu.rooms.flatMap((room) => room.groups.map((group) => [group.spot, room.id])));
  for (const [spot, info] of Object.entries(context.spots)) assert.equal(groups.get(spot), info.room, spot);
});

test("required clickable areas have groups", () => {
  const spots = new Set(real.document.menu.rooms.flatMap((room) => room.groups.map((group) => group.spot)));
  const required = ["player", "tickets", "seating", "pickup_seating", "runners", "shredder", "room:hall", "room:staff_room", "room:player_office"];
  for (const key of Object.keys(context.spots)) if (/^(room|dept|station|lead|shredder):/.test(key)) required.push(key);
  for (const spot of required) assert.ok(spots.has(spot), spot);
});

test("adding into an empty group of a spot without entries works", () => {
  const added = model.addEntry(model.removeEntry(fresh(), "track:briefcase").document, context, "briefcase", { room: "staff_room", spot: "room:staff_room", index: 0 });
  assert.equal(added.error, undefined);
  assert.equal(model.findLocation(added.document, "track:briefcase").spot, "room:staff_room");
  assert.deepEqual(consistency(added.document, context), []);
});

test("areas are added with a group and merged into the context", () => {
  const result = model.addArea(fresh(), { id: "lab", room: "kitchen", rect: [10, 20, 100, 50] });
  assert.equal(result.spot, "area:lab");
  assert.deepEqual(result.document.areas.lab, { room: "kitchen", rects: [[10, 20, 100, 50]] });
  assert.ok(result.document.menu.rooms.find((room) => room.id === "kitchen").groups.some((group) => group.spot === "area:lab"));
  const merged = model.withAreas(context, result.document);
  assert.equal(merged.spots["area:lab"].room, "kitchen");
  assert.equal(model.withAreas(context, result.document), merged);
  assert.equal(model.withAreas(context, fresh()), context);
  assert.equal(model.spotRoom("area:lab", merged), "kitchen");
  assert.equal(model.addArea(result.document, { id: "lab", room: "kitchen", rect: [0, 0, 1, 1] }).error, "AREA_EXISTS");
  assert.equal(model.addArea(fresh(), { id: "x", room: "nowhere", rect: [0, 0, 1, 1] }).error, "AREA_ROOM");
});

test("upgrades can be moved into a new area and the area is protected while used", () => {
  const added = model.addArea(fresh(), { id: "lab", room: "kitchen", rect: [0, 0, 50, 50] }).document;
  const merged = model.withAreas(context, added);
  const moved = model.moveEntry(added, merged, "track:briefcase", { room: "kitchen", spot: "area:lab", index: 0 });
  assert.equal(moved.error, undefined);
  assert.equal(moved.document.upgrades.briefcase.spot, "area:lab");
  assert.deepEqual(model.visibleAt(model.buildEntries(moved.document, merged), "area:lab").map((entry) => entry.id), ["track:briefcase"]);
  assert.equal(model.removeArea(moved.document, "lab").error, "AREA_NOT_EMPTY");
  const freed = model.moveEntry(moved.document, merged, "track:briefcase", { room: "player", spot: "player", index: 0 }).document;
  const removed = model.removeArea(freed, "lab");
  assert.equal(removed.document.areas.lab, undefined);
  assert.ok(!removed.document.menu.rooms.some((room) => room.groups.some((group) => group.spot === "area:lab")));
  assert.equal(model.removeArea(removed.document, "lab").error, "AREA_UNKNOWN");
});

test("area boxes can be edited", () => {
  const added = model.addArea(fresh(), { id: "lab", room: "kitchen", rect: [0, 0, 50, 50] }).document;
  const resized = model.setAreaRect(added, "lab", 0, [5, 5, 60, 60]);
  assert.deepEqual(resized.document.areas.lab.rects, [[5, 5, 60, 60]]);
  const two = model.addAreaRect(resized.document, "lab", [100, 100, 10, 10]);
  assert.equal(two.document.areas.lab.rects.length, 2);
  assert.equal(model.removeAreaRect(two.document, "lab", 0).document.areas.lab.rects.length, 1);
  assert.equal(model.removeAreaRect(added, "lab", 0).error, "AREA_LAST_RECT");
  assert.equal(model.setAreaRect(added, "nope", 0, [0, 0, 1, 1]).error, "AREA_UNKNOWN");
  assert.equal(model.setAreaRect(added, "lab", 3, [0, 0, 1, 1]).error, "AREA_UNKNOWN");
  assert.equal(model.addAreaRect(added, "nope", [0, 0, 1, 1]).error, "AREA_UNKNOWN");
  assert.equal(model.removeAreaRect(added, "nope", 0).error, "AREA_UNKNOWN");
});

test("area slugs and rectangles", () => {
  assert.equal(model.areaSlug("Café Ünit 7!", []), "cafe_unit_7");
  assert.equal(model.areaSlug("123", []), "area");
  assert.equal(model.areaSlug("!!!", []), "area");
  assert.equal(model.areaSlug("Lab", ["lab", "lab_2"]), "lab_3");
  assert.deepEqual(model.normaliseRect({ x: 50.4, y: 10 }, { x: 10, y: 30.6 }), [10, 10, 40, 21]);
  assert.deepEqual(model.normaliseRect({ x: 5, y: 5 }, { x: 5, y: 5 }), [5, 5, 1, 1]);
});

test("removing an area deletes its title override", () => {
  const added = model.addArea(fresh(), { id: "lab", room: "kitchen", rect: [0, 0, 5, 5] }).document;
  const titled = model.setText(added, "SPOT_AREA_LAB", "de", "Labor", "");
  assert.equal(model.removeArea(titled, "lab").document.text_overrides.SPOT_AREA_LAB, undefined);
});

import { effectiveConstants, trackCost as modelTrackCost, trackValue as modelTrackValue } from "../../web/js/formulas.js";

const constants = effectiveConstants(context, real.document);

const draftOf = (id = "briefcase") => ({
  cost: model.tableFromParameters(real.document.upgrades[id], "cost", constants),
  value: model.tableFromParameters(real.document.upgrades[id], "value", constants),
  formula: {},
});

test("applying an unchanged table keeps the parametric upgrade clean", () => {
  const result = model.applyTables(fresh(), "briefcase", draftOf(), constants);
  assert.ok(!("cost_model" in result.document.upgrades.briefcase));
  assert.ok(!("value_model" in result.document.upgrades.briefcase));
});

test("applying an edited table writes table models that reproduce the draft", () => {
  const draft = draftOf();
  draft.cost[2] = 777;
  draft.value[1] += 5;
  draft.formula = { cost: "3 * level" };
  const edited = model.applyTables(fresh(), "briefcase", draft, constants).document.upgrades.briefcase;
  assert.deepEqual(edited.cost_model, { mode: "table", levels: draft.cost, formula: "3 * level" });
  assert.deepEqual(edited.value_model, { mode: "table", increments: draft.value });
  assert.equal(modelTrackCost(edited, 2, 1, constants), 777);
  assert.ok(Math.abs(modelTrackValue(edited, 2, constants) - (modelTrackValue(real.document.upgrades.briefcase, 2, constants) + 5)) < 1e-9);
});

test("applying the parametric table again removes a table model", () => {
  const draft = draftOf();
  draft.cost[0] = 1;
  const edited = model.applyTables(fresh(), "briefcase", draft, constants).document;
  assert.ok("cost_model" in edited.upgrades.briefcase);
  const back = model.applyTables(edited, "briefcase", draftOf(), constants).document.upgrades.briefcase;
  assert.ok(!("cost_model" in back));
});

test("applying a longer or shorter table changes the maximum", () => {
  const max = real.document.upgrades.briefcase.max;
  const longer = draftOf();
  longer.cost.push(500);
  longer.value.push(12345);
  const grown = model.applyTables(fresh(), "briefcase", longer, constants).document.upgrades.briefcase;
  assert.equal(grown.max, max + 1);
  assert.equal(grown.cost_model.levels.at(-1), 500);
  assert.equal(grown.value_model.increments.length, max + 1);
  const shorter = draftOf();
  shorter.cost.pop();
  shorter.value.pop();
  const cut = model.applyTables(fresh(), "briefcase", shorter, constants).document.upgrades.briefcase;
  assert.equal(cut.max, max - 1);
  assert.equal(model.applyTables(fresh(), "briefcase", { cost: [], value: [], formula: {} }, constants).error, "TABLE_LENGTH");
});

test("applying rejects broken tables", () => {
  const short = draftOf();
  short.cost = short.cost.slice(1);
  assert.equal(model.applyTables(fresh(), "briefcase", short, constants).error, "TABLE_LENGTH");
  const negative = draftOf();
  negative.cost[0] = -1;
  assert.equal(model.applyTables(fresh(), "briefcase", negative, constants).error, "TABLE_VALUE");
  const infinite = draftOf();
  infinite.value[0] = Infinity;
  assert.equal(model.applyTables(fresh(), "briefcase", infinite, constants).error, "TABLE_VALUE");
  assert.equal(model.applyTables(fresh(), "ghost", draftOf(), constants).error, "UNKNOWN_UPGRADE");
});

test("parametric tables reproduce the upgrade for every curve", () => {
  for (const [id, definition] of Object.entries(real.document.upgrades)) {
    const increments = model.tableFromParameters(definition, "value", constants);
    let total = modelTrackValue(definition, 0, constants);
    increments.forEach((increment, index) => {
      total += increment;
      const expected = modelTrackValue(definition, index + 1, constants);
      assert.ok(Math.abs(total - expected) <= 1e-9 * Math.max(1, Math.abs(expected)), `${id} ${index}`);
    });
  }
});

test("fill operations work on plain lists", () => {
  assert.deepEqual(model.fillValues([1, 2, 3], { type: "same", value: 9 }), [9, 9, 9]);
  assert.deepEqual(model.fillValues([1, 2, 3], { type: "from", index: 1, value: 9 }), [1, 9, 9]);
  assert.deepEqual(model.fillValues([1, 2, 3], { type: "scale", index: 1, factor: 2 }), [1, 4, 6]);
});

test("closeTables compares with a relative tolerance", () => {
  assert.ok(model.closeTables([1, 2], [1, 2 + 1e-12]));
  assert.ok(!model.closeTables([1, 2], [1, 2.1]));
  assert.ok(!model.closeTables([1], [1, 1]));
});

test("changing the maximum resizes tables", () => {
  const document = model.applyTables(fresh(), "briefcase", (() => { const draft = draftOf(); draft.cost[0] = 1; draft.value[0] += 1; return draft; })(), constants).document;
  const smaller = model.updateUpgrade(document, "briefcase", { max: 5 });
  assert.equal(smaller.upgrades.briefcase.cost_model.levels.length, 5);
  assert.equal(smaller.upgrades.briefcase.value_model.increments.length, 5);
  const grown = model.updateUpgrade(smaller, "briefcase", { max: 8 }).upgrades.briefcase;
  assert.equal(grown.cost_model.levels.length, 8);
  assert.equal(grown.cost_model.levels[7], grown.cost_model.levels[4]);
  const blank = structuredClone(smaller);
  blank.upgrades.briefcase.cost_model.levels = [];
  assert.deepEqual(model.updateUpgrade(blank, "briefcase", { max: 2 }).upgrades.briefcase.cost_model.levels, [0, 0]);
});

test("a formula fills a table without touching the document models", () => {
  const plain = fresh().upgrades.briefcase;
  const cost = model.tableFromFormula(plain, "cost", "10 * level + 5");
  assert.deepEqual(cost.values, Array.from({ length: plain.max }, (_, level) => 10 * level + 5));
  const value = model.tableFromFormula(plain, "value", "base + 2 * level");
  assert.deepEqual(value.values, Array.from({ length: plain.max }, () => 2));
  assert.equal(model.tableFromFormula(plain, "cost", "nope").error, "UNKNOWN_IDENTIFIER");
  assert.equal(model.tableFromFormula(plain, "cost", "").error, "EMPTY");
  assert.equal(model.tableFromFormula(plain, "cost", "level - 5").error, "NEGATIVE");
});

test("remembering a formula records it in the history only", () => {
  const result = model.rememberFormula(fresh(), "briefcase", "cost", " 10 * level + 5 ");
  assert.equal(result.formula, "10 * level + 5");
  assert.equal(result.values.length, real.document.upgrades.briefcase.max);
  const definition = result.document.upgrades.briefcase;
  assert.deepEqual(definition.formula_history, { cost: ["10 * level + 5"] });
  assert.ok(!("cost_model" in definition));
  assert.deepEqual(model.formulaHistory(definition, "cost"), ["10 * level + 5"]);
  assert.deepEqual(model.formulaHistory(definition, "value"), []);
  assert.deepEqual(model.formulaHistory(undefined, "cost"), []);
  assert.equal(model.rememberFormula(fresh(), "briefcase", "cost", "nope").error, "UNKNOWN_IDENTIFIER");
  assert.equal(model.rememberFormula(fresh(), "ghost", "cost", "1").error, "UNKNOWN_UPGRADE");
});

test("history keeps newest first without duplicates and respects the limit", () => {
  let document = fresh();
  for (const formula of ["level", "2 * level", "level"]) document = model.rememberFormula(document, "briefcase", "cost", formula).document;
  assert.deepEqual(document.upgrades.briefcase.formula_history.cost, ["level", "2 * level"]);
  for (let index = 0; index < model.FORMULA_HISTORY_LIMIT + 5; index += 1) document = model.rememberFormula(document, "briefcase", "cost", `level + ${index}`).document;
  assert.equal(document.upgrades.briefcase.formula_history.cost.length, model.FORMULA_HISTORY_LIMIT);
});

test("history entries can be deleted and the field disappears when empty", () => {
  let document = model.rememberFormula(fresh(), "briefcase", "cost", "level").document;
  document = model.rememberFormula(document, "briefcase", "value", "base + level").document;
  document = model.rememberFormula(document, "briefcase", "cost", "2 * level").document;
  document = model.deleteFormulaFromHistory(document, "briefcase", "cost", "level").document;
  assert.deepEqual(document.upgrades.briefcase.formula_history, { cost: ["2 * level"], value: ["base + level"] });
  document = model.deleteFormulaFromHistory(document, "briefcase", "cost", "2 * level").document;
  assert.deepEqual(document.upgrades.briefcase.formula_history, { value: ["base + level"] });
  document = model.deleteFormulaFromHistory(document, "briefcase", "value", "base + level").document;
  assert.ok(!("formula_history" in document.upgrades.briefcase));
  assert.equal(model.deleteFormulaFromHistory(fresh(), "ghost", "cost", "x").error, "UNKNOWN_UPGRADE");
});

test("an upgrade can be placed in several areas at once", () => {
  const added = model.addPlacement(fresh(), context, "track:briefcase", KITCHEN);
  assert.equal(added.ref, "track:briefcase");
  const found = model.occurrences(added.document, "track:briefcase");
  assert.equal(found.length, 2);
  assert.equal(added.document.upgrades.briefcase.spot, real.document.upgrades.briefcase.spot);
  const again = model.addPlacement(added.document, context, "track:briefcase", { ...KITCHEN, spot: "kitchen" });
  assert.equal(again.error, "ALREADY_PLACED");
  assert.equal(model.addPlacement(fresh(), context, "track:briefcase", { room: "kitchen", spot: "tickets", index: 0 }).error, "SPOT_ROOM_MISMATCH");
  assert.equal(model.addPlacement(fresh(), context, "track:ghost", KITCHEN).error, "UNKNOWN_UPGRADE");
  assert.equal(model.addPlacement(fresh(), context, "desk:x", KITCHEN).error, "SYSTEM_FIXED");
  const removed = model.removeEntry(fresh(), "track:briefcase").document;
  assert.equal(model.addPlacement(removed, context, "track:briefcase", KITCHEN).error, "NOT_PLACED");
});

test("adding a placed global upgrade through the palette adds a second area", () => {
  const result = model.addEntry(fresh(), context, "briefcase", KITCHEN);
  assert.equal(model.occurrences(result.document, "track:briefcase").length, 2);
  assert.equal(result.document.upgrades.briefcase.spot, real.document.upgrades.briefcase.spot);
});

test("entries are built once per placement and carry their group", () => {
  const document = model.addPlacement(fresh(), context, "track:briefcase", KITCHEN).document;
  const entries = model.buildEntries(document, context).filter((entry) => entry.id === "track:briefcase");
  assert.deepEqual(entries.map((entry) => entry.room).sort(), ["kitchen", "player"]);
  assert.ok(entries.every((entry) => entry.group === ""));
});

test("moving an extra placement keeps the primary area", () => {
  const document = model.addPlacement(fresh(), context, "track:briefcase", KITCHEN).document;
  const primarySpot = document.upgrades.briefcase.spot;
  const moved = model.moveEntry(document, context, "track:briefcase", COFFEE, { room: "kitchen", spot: "kitchen", group: "" });
  assert.equal(moved.error, undefined);
  assert.equal(moved.document.upgrades.briefcase.spot, primarySpot);
  assert.deepEqual(model.occurrences(moved.document, "track:briefcase").map((item) => item.spot).sort(), [primarySpot, "coffee_machine"].sort());
  const clash = model.moveEntry(document, context, "track:briefcase", { room: real.document.menu.rooms.find((room) => room.groups.some((group) => group.entries.includes("track:briefcase"))).id, spot: primarySpot, index: 0 }, { room: "kitchen", spot: "kitchen", group: "" });
  assert.equal(clash.error, "ALREADY_PLACED");
});

test("moving the primary placement updates the upgrade spot", () => {
  const document = model.addPlacement(fresh(), context, "track:briefcase", KITCHEN).document;
  const origin = model.occurrences(document, "track:briefcase").find((item) => item.spot === document.upgrades.briefcase.spot);
  const moved = model.moveEntry(document, context, "track:briefcase", COFFEE, origin);
  assert.equal(moved.document.upgrades.briefcase.spot, "coffee_machine");
  assert.equal(model.occurrences(moved.document, "track:briefcase").length, 2);
});

test("removing one placement keeps the upgrade enabled and fixes the primary spot", () => {
  const added = model.addPlacement(fresh(), context, "track:briefcase", KITCHEN).document;
  const origin = model.occurrences(added, "track:briefcase").find((item) => item.spot === added.upgrades.briefcase.spot);
  const removed = model.removeEntry(added, "track:briefcase", origin).document;
  assert.equal(removed.upgrades.briefcase.spot, "kitchen");
  assert.notEqual(removed.upgrades.briefcase.enabled, false);
  const last = model.removeEntry(removed, "track:briefcase").document;
  assert.equal(last.upgrades.briefcase.enabled, false);
  assert.equal(model.occurrences(last, "track:briefcase").length, 0);
});

test("removing all placements disables the upgrade or frees the room", () => {
  const added = model.addPlacement(fresh(), context, "track:briefcase", KITCHEN).document;
  const none = model.removeAllPlacements(added, "track:briefcase").document;
  assert.equal(model.occurrences(none, "track:briefcase").length, 0);
  assert.equal(none.upgrades.briefcase.enabled, false);
  const room = model.removeAllPlacements(fresh(), "track:room_speed@housing").document;
  assert.ok(!room.upgrades.room_speed.rooms.includes("housing"));
  assert.deepEqual(model.removeAllPlacements(fresh(), "track:ghost").document, fresh());
});

test("room upgrade instances can appear in more areas", () => {
  const document = model.addPlacement(fresh(), context, "track:room_speed@housing", { room: "player", spot: "room:player", index: 0 }).document;
  assert.equal(model.occurrences(document, "track:room_speed@housing").length, 2);
  assert.deepEqual(document.upgrades.room_speed.rooms, real.document.upgrades.room_speed.rooms);
  const extra = model.occurrences(document, "track:room_speed@housing").find((item) => item.room === "player");
  const moved = model.moveEntry(document, context, "track:room_speed@housing", { room: "kitchen", spot: "kitchen", index: 0 }, extra);
  assert.equal(moved.error, undefined);
  assert.deepEqual(moved.document.upgrades.room_speed.rooms, real.document.upgrades.room_speed.rooms);
  const removed = model.removeEntry(moved.document, "track:room_speed@housing", { room: "kitchen", spot: "kitchen", group: "" }).document;
  assert.deepEqual(removed.upgrades.room_speed.rooms, real.document.upgrades.room_speed.rooms);
});

test("subgroups can be added, filled, renamed, ordered and removed", () => {
  const created = model.addSubgroup(fresh(), context, "kitchen", "kitchen", { de: " Pausen ", en: "Breaks" });
  assert.equal(created.groupId, "breaks");
  const room = created.document.menu.rooms.find((candidate) => candidate.id === "kitchen");
  const group = room.groups.find((candidate) => candidate.id === "breaks");
  assert.deepEqual(group, { spot: "kitchen", id: "breaks", title: { de: "Pausen", en: "Breaks" }, entries: [] });
  assert.equal(room.groups.indexOf(group), room.groups.map((item) => item.spot).lastIndexOf("kitchen"));
  const second = model.addSubgroup(created.document, context, "kitchen", "kitchen", { de: "Pausen", en: "Breaks" });
  assert.equal(second.groupId, "breaks_2");
  const filled = model.addEntry(created.document, context, "briefcase", { room: "kitchen", spot: "kitchen", group: "breaks", index: 0 }).document;
  assert.deepEqual(model.findLocation(filled, "track:briefcase", { room: "kitchen", spot: "kitchen", group: "breaks" }).group, "breaks");
  const renamed = model.setSubgroupTitle(filled, "kitchen", "kitchen", "breaks", { de: "Kaffee", en: "Coffee" });
  assert.equal(renamed.document.menu.rooms.find((candidate) => candidate.id === "kitchen").groups.find((item) => item.id === "breaks").title.en, "Coffee");
  const order = renamed.document.menu.rooms.find((candidate) => candidate.id === "kitchen").groups.length;
  const moved = model.moveGroup(renamed.document, "kitchen", "kitchen", 0, "breaks");
  assert.equal(moved.document.menu.rooms.find((candidate) => candidate.id === "kitchen").groups[0].id, "breaks");
  assert.equal(moved.document.menu.rooms.find((candidate) => candidate.id === "kitchen").groups.length, order);
  const removed = model.removeSubgroup(renamed.document, context, "kitchen", "kitchen", "breaks").document;
  assert.ok(!removed.menu.rooms.find((candidate) => candidate.id === "kitchen").groups.some((item) => item.id === "breaks"));
  assert.equal(model.findLocation(removed, "track:briefcase").group, "");
});

test("subgroup edits validate their input", () => {
  assert.equal(model.addSubgroup(fresh(), context, "kitchen", "kitchen", { de: "", en: "x" }).error, "GROUP_TITLE");
  assert.equal(model.addSubgroup(fresh(), context, "kitchen", "tickets", { de: "a", en: "b" }).error, "SPOT_ROOM_MISMATCH");
  assert.equal(model.addSubgroup(fresh(), context, "ghost", "kitchen", { de: "a", en: "b" }).error, "SPOT_ROOM_MISMATCH");
  assert.equal(model.setSubgroupTitle(fresh(), "kitchen", "kitchen", "nope", { de: "a", en: "b" }).error, "NOT_PLACED");
  assert.equal(model.setSubgroupTitle(fresh(), "kitchen", "kitchen", "", { de: "a", en: "b" }).error, "NOT_PLACED");
  assert.equal(model.setSubgroupTitle(fresh(), "kitchen", "kitchen", "x", { de: "", en: "b" }).error, "GROUP_TITLE");
  assert.equal(model.removeSubgroup(fresh(), context, "kitchen", "kitchen", "nope").error, "NOT_PLACED");
  assert.equal(model.removeSubgroup(fresh(), context, "kitchen", "kitchen", "").error, "NOT_PLACED");
});

test("group slugs are unique, ascii and start with a letter", () => {
  assert.equal(model.groupSlug("Küche & Co", []), "kuche_co");
  assert.equal(model.groupSlug("123", []), "g_123");
  assert.equal(model.groupSlug("!!!", []), "group");
  assert.equal(model.groupSlug("a", ["a", "a_2"]), "a_3");
});

test("entries in subgroups keep their group when listed per spot", () => {
  const created = model.addSubgroup(fresh(), context, "kitchen", "kitchen", { de: "A", en: "A" }).document;
  const filled = model.addEntry(created, context, "briefcase", { room: "kitchen", spot: "kitchen", group: "a", index: 0 }).document;
  const groups = model.groupsOf(model.visibleAt(model.buildEntries(filled, context), "kitchen"));
  assert.ok(groups.some((group) => group.group === "a" && group.entries.some((entry) => entry.id === "track:briefcase")));
});

test("moving between subgroups of the same spot is allowed", () => {
  const created = model.addSubgroup(fresh(), context, "kitchen", "kitchen", { de: "A", en: "A" }).document;
  const filled = model.addEntry(created, context, "briefcase", { room: "kitchen", spot: "kitchen", group: "a", index: 0 }).document;
  const moved = model.moveEntry(filled, context, "track:briefcase", { room: "kitchen", spot: "kitchen", group: "", index: 0 }, { room: "kitchen", spot: "kitchen", group: "a" });
  assert.equal(moved.error, undefined);
  assert.equal(model.findLocation(moved.document, "track:briefcase").group, "");
});

test("a room scope reads the default merged with its own override", () => {
  const document = model.updateUpgrade(fresh(), "room_speed", { cost: 999, max: 12 }, "hall");
  const base = document.upgrades.room_speed;
  assert.equal(base.cost, real.document.upgrades.room_speed.cost);
  assert.deepEqual(base.room_overrides, { hall: { cost: 999, max: 12 } });
  const hall = model.scopedDefinition(document, "room_speed", "hall");
  assert.equal(hall.cost, 999);
  assert.equal(hall.max, 12);
  assert.equal(hall.growth, base.growth);
  assert.ok(!("room_overrides" in hall));
  assert.equal(model.scopedDefinition(document, "room_speed", "mail").cost, base.cost);
  assert.equal(model.scopedDefinition(document, "room_speed", "").cost, base.cost);
  assert.equal(model.scopedDefinition(document, "ghost", "hall"), undefined);
  assert.ok(model.hasRoomOverride(document, "room_speed", "hall"));
  assert.ok(!model.hasRoomOverride(document, "room_speed", "mail"));
});

test("rooms are configured independently of each other", () => {
  let document = model.updateUpgrade(fresh(), "room_speed", { cost: 10 }, "hall");
  document = model.updateUpgrade(document, "room_speed", { cost: 20, step: 0.5 }, "mail");
  assert.equal(model.scopedDefinition(document, "room_speed", "hall").cost, 10);
  assert.equal(model.scopedDefinition(document, "room_speed", "mail").cost, 20);
  assert.equal(model.scopedDefinition(document, "room_speed", "hall").step, real.document.upgrades.room_speed.step);
});

test("removing the last override field removes the override", () => {
  let document = model.updateUpgrade(fresh(), "room_speed", { cost: 10 }, "hall");
  document = model.updateUpgrade(document, "room_speed", { cost: undefined }, "hall");
  assert.ok(!("room_overrides" in document.upgrades.room_speed));
  document = model.updateUpgrade(model.updateUpgrade(fresh(), "room_speed", { cost: 10 }, "hall"), "room_speed", { cost: 11 }, "mail");
  document = model.clearRoomOverride(document, "room_speed", "hall").document;
  assert.deepEqual(Object.keys(document.upgrades.room_speed.room_overrides), ["mail"]);
  document = model.clearRoomOverride(document, "room_speed", "mail").document;
  assert.ok(!("room_overrides" in document.upgrades.room_speed));
  assert.equal(model.clearRoomOverride(fresh(), "ghost", "hall").error, "UNKNOWN_UPGRADE");
  assert.ok(!("room_overrides" in model.clearRoomOverride(fresh(), "room_speed", "hall").document.upgrades.room_speed));
});

test("changing the maximum of a room resizes its own tables only", () => {
  const draft = { cost: Array(100).fill(5), value: Array(100).fill(0.1), formula: {} };
  let document = model.applyTables(fresh(), "room_speed", draft, constants, "hall").document;
  const hall = model.scopedDefinition(document, "room_speed", "hall");
  assert.equal(hall.cost_model.levels.length, 100);
  document = model.updateUpgrade(document, "room_speed", { max: 40 }, "hall");
  const shrunk = model.scopedDefinition(document, "room_speed", "hall");
  assert.equal(shrunk.max, 40);
  assert.equal(shrunk.cost_model.levels.length, 40);
  assert.equal(shrunk.value_model.increments.length, 40);
  assert.equal(document.upgrades.room_speed.max, real.document.upgrades.room_speed.max);
  assert.ok(!("cost_model" in document.upgrades.room_speed));
});

test("applying a table for a room leaves the default and other rooms alone", () => {
  const draft = { cost: model.tableFromParameters(real.document.upgrades.room_speed, "cost", constants), value: model.tableFromParameters(real.document.upgrades.room_speed, "value", constants), formula: {} };
  draft.cost[0] = 1;
  const document = model.applyTables(fresh(), "room_speed", draft, constants, "hall").document;
  assert.equal(document.upgrades.room_speed.room_overrides.hall.cost_model.levels[0], 1);
  assert.ok(!("cost_model" in document.upgrades.room_speed));
  assert.ok(!("cost_model" in model.scopedDefinition(document, "room_speed", "mail")));
  assert.equal(model.applyTables(fresh(), "ghost", draft, constants, "hall").error, "UNKNOWN_UPGRADE");
});

test("a room can switch an inherited table model back to parameters", () => {
  const base = fresh();
  const tableDraft = { cost: model.tableFromParameters(base.upgrades.room_speed, "cost", constants), value: model.tableFromParameters(base.upgrades.room_speed, "value", constants), formula: {} };
  tableDraft.cost[1] = 7;
  const withTable = model.applyTables(base, "room_speed", tableDraft, constants).document;
  const plain = { cost: model.tableFromParameters(withTable.upgrades.room_speed, "cost", constants), value: model.tableFromParameters(withTable.upgrades.room_speed, "value", constants), formula: {} };
  const document = model.applyTables(withTable, "room_speed", plain, constants, "hall").document;
  assert.deepEqual(document.upgrades.room_speed.room_overrides.hall.cost_model, {});
  assert.ok(!("cost_model" in model.scopedDefinition(document, "room_speed", "hall")));
  assert.ok("cost_model" in model.scopedDefinition(document, "room_speed", "mail"));
});

test("remembering a formula for a room evaluates it against the room", () => {
  const document = model.updateUpgrade(fresh(), "room_speed", { max: 3 }, "hall");
  const result = model.rememberFormula(document, "room_speed", "cost", "10 * level", "hall");
  assert.equal(result.values.length, 3);
  assert.deepEqual(model.formulaHistory(result.document.upgrades.room_speed, "cost"), ["10 * level"]);
});
