import { checkFormula, costVariables, trackCost, trackValue, valueVariables } from "./formulas.js";
import { evaluate } from "./formula.js";
import { splitSpot, stationRoom } from "./texts.js";

const ROOM_TRACKS = { station: ["room_speed"], trays: ["room_trays"] };
const HALL_LEAD_ROOMS = ["intake", "pickup"];

export const clone = (value) => structuredClone(value);

export function defRef(kind, target) {
  if (kind === "track") return "track:" + target.split("@")[0];
  if (kind === "staff") return "sys:staff:" + target;
  return "sys:" + kind;
}

export function parseRef(ref) {
  const separator = ref.indexOf(":");
  const kind = separator < 0 ? ref : ref.slice(0, separator);
  const rest = separator < 0 ? "" : ref.slice(separator + 1);
  if (kind !== "track") return { kind, target: rest, upgradeId: null, roomId: "" };
  const [upgradeId, roomId = ""] = rest.split("@");
  return { kind: "track", target: upgradeId, upgradeId, roomId };
}

export const refOf = (upgradeId, roomId) => (roomId ? `track:${upgradeId}@${roomId}` : `track:${upgradeId}`);

export function isRoomUpgrade(definition) {
  return Array.isArray(definition.rooms);
}

export function spotRoom(spot, context) {
  const known = context.spots[spot]?.room;
  if (known) return known;
  const { kind, target } = splitSpot(spot);
  switch (kind) {
    case "room":
    case "dept":
    case "tube":
    case "shredder":
      return target;
    case "station":
    case "trays":
      return stationRoom(target);
    case "lead":
      return HALL_LEAD_ROOMS.includes(target) ? "hall" : target;
    default:
      return "";
  }
}

export function templateSpot(definition, roomId, context) {
  const spot = definition.spot;
  if (spot === "@room") return (context.rooms.find((room) => room.id === roomId)?.department ? "dept:" : "room:") + roomId;
  return spot.includes("%s") ? spot.replace("%s", roomId) : spot;
}

export function menuRoomOf(definition, roomId, context) {
  return spotRoom(templateSpot(definition, roomId, context), context);
}

export function allowedRooms(upgradeId, definition, context) {
  return context.allowed_rooms?.[upgradeId] ?? definition.rooms ?? [];
}

export function roomCandidates(upgradeId, definition, menuRoom, context) {
  return allowedRooms(upgradeId, definition, context).filter((roomId) => menuRoomOf(definition, roomId, context) === menuRoom);
}

export function topicOfRef(document, ref) {
  return document.menu.topics.find((topic) => topic.items.includes(ref))?.id ?? "";
}

export function buildEntries(document, context) {
  const entries = [];
  for (const room of document.menu.rooms) {
    for (const group of room.groups) {
      for (const ref of group.entries) {
        entries.push({ ...buildEntry(document, context, ref, room.id, group.spot), group: groupIdOf(group) });
      }
    }
  }
  return entries;
}

function buildEntry(document, context, ref, menuRoom, spot) {
  const parsed = parseRef(ref);
  if (parsed.kind === "track") {
    return { id: ref, kind: "track", target: parsed.upgradeId, roomId: parsed.roomId, spot, room: menuRoom, topic: topicOfRef(document, defRef("track", parsed.upgradeId)) };
  }
  const system = context.system_entries[ref] ?? { kind: parsed.kind, target: parsed.target, topic: "" };
  return { id: ref, kind: system.kind, target: system.target, roomId: "", spot, room: menuRoom, topic: topicOfRef(document, defRef(system.kind, system.target)) || system.topic, fixed: true };
}

function roomTrackAt(entry, kind, key) {
  return entry.kind === "track" && ROOM_TRACKS[kind].includes(entry.target) && entry.roomId === stationRoom(key);
}

export function showsAt(entry, spot) {
  if (spot.startsWith("room:")) return entry.room === spot.slice(5);
  if (entry.spot === spot) return true;
  if (spot === "tube_hub") return entry.spot.startsWith("tube:");
  if (spot.startsWith("dept:")) return entry.room === spot.slice(5);
  if (spot.startsWith("station:")) return roomTrackAt(entry, "station", spot.slice(8));
  if (spot.startsWith("trays:")) return roomTrackAt(entry, "trays", spot.slice(6));
  return false;
}

export function visibleAt(entries, spot) {
  return entries.filter((entry) => showsAt(entry, spot));
}

export const groupIdOf = (group) => group.id ?? "";

export function groupsOf(entries) {
  const groups = [];
  for (const entry of entries) {
    const groupId = entry.group ?? "";
    let group = groups.find((candidate) => candidate.spot === entry.spot && candidate.group === groupId);
    if (!group) {
      group = { spot: entry.spot, group: groupId, entries: [] };
      groups.push(group);
    }
    group.entries.push(entry);
  }
  return groups;
}

export function occurrences(document, ref) {
  const result = [];
  for (const [roomIndex, room] of document.menu.rooms.entries()) {
    for (const [groupIndex, group] of room.groups.entries()) {
      const index = group.entries.indexOf(ref);
      if (index >= 0) result.push({ roomIndex, groupIndex, index, room: room.id, spot: group.spot, group: groupIdOf(group) });
    }
  }
  return result;
}

const sameOccurrence = (occurrence, from) => occurrence.room === from.room && occurrence.spot === from.spot && occurrence.group === (from.group ?? "");

export function findLocation(document, ref, from = null) {
  const found = occurrences(document, ref);
  return (from ? found.find((occurrence) => sameOccurrence(occurrence, from)) : found[0]) ?? null;
}

function ensureGroup(document, context, roomId, spot, groupId = "") {
  const room = document.menu.rooms.find((candidate) => candidate.id === roomId);
  if (!room || spotRoom(spot, context) !== roomId) return null;
  let group = room.groups.find((candidate) => candidate.spot === spot && groupIdOf(candidate) === groupId);
  if (!group && groupId === "") {
    group = { spot, entries: [] };
    room.groups.push(group);
  }
  return group ?? null;
}

function detach(document, ref, from = null) {
  const location = findLocation(document, ref, from);
  if (!location) return null;
  document.menu.rooms[location.roomIndex].groups[location.groupIndex].entries.splice(location.index, 1);
  return location;
}

function clampIndex(index, length) {
  return Math.max(0, Math.min(index ?? length, length));
}

function insertAt(group, ref, index) {
  group.entries.splice(clampIndex(index, group.entries.length), 0, ref);
}

function isPrimary(definition, parsed, occurrence, context) {
  if (!isRoomUpgrade(definition)) return occurrence.spot === definition.spot;
  return occurrence.spot === templateSpot(definition, parsed.roomId, context);
}

function alreadyAt(document, ref, target, origin) {
  return occurrences(document, ref).some((occurrence) => occurrence.room === target.room && occurrence.spot === target.spot && !(origin && occurrence.room === origin.room && occurrence.spot === origin.spot));
}

export function moveEntry(document, context, ref, target, from = null) {
  const next = clone(document);
  const parsed = parseRef(ref);
  const origin = findLocation(next, ref, from);
  if (!origin) return { error: "NOT_PLACED" };
  if (parsed.kind !== "track") return moveSystemEntry(next, ref, origin, target);
  const definition = next.upgrades[parsed.upgradeId];
  if (!isPrimary(definition, parsed, origin, context)) return moveExtraEntry(next, context, ref, origin, target);
  if (!isRoomUpgrade(definition)) return moveGlobalEntry(next, context, ref, parsed, definition, origin, target);
  return moveRoomEntry(next, context, ref, parsed, definition, origin, target);
}

function relocate(next, context, ref, origin, target) {
  const groupId = target.group ?? "";
  const group = ensureGroup(next, context, target.room, target.spot, groupId);
  if (!group) return { error: "SPOT_ROOM_MISMATCH" };
  if (alreadyAt(next, ref, target, origin)) return { error: "ALREADY_PLACED" };
  const sameGroup = origin.room === target.room && origin.spot === target.spot && origin.group === groupId;
  detach(next, ref, origin);
  insertAt(group, ref, sameGroup && target.index > origin.index ? target.index - 1 : target.index);
  return { ref };
}

function moveExtraEntry(next, context, ref, origin, target) {
  const result = relocate(next, context, ref, origin, target);
  return result.error ? result : { document: next, ref };
}

function moveSystemEntry(next, ref, origin, target) {
  if (target.room !== origin.room || target.spot !== origin.spot) return { error: "SYSTEM_FIXED" };
  const group = next.menu.rooms[origin.roomIndex].groups.find((candidate) => candidate.spot === target.spot && groupIdOf(candidate) === (target.group ?? origin.group));
  if (!group) return { error: "NOT_PLACED" };
  const sameGroup = (target.group ?? origin.group) === origin.group;
  if (sameGroup) {
    group.entries.splice(origin.index, 1);
    insertAt(group, ref, target.index > origin.index ? target.index - 1 : target.index);
  } else {
    next.menu.rooms[origin.roomIndex].groups[origin.groupIndex].entries.splice(origin.index, 1);
    insertAt(group, ref, target.index);
  }
  return { document: next, ref };
}

function moveGlobalEntry(next, context, ref, parsed, definition, origin, target) {
  const result = relocate(next, context, ref, origin, target);
  if (result.error) return result;
  definition.spot = target.spot;
  delete definition.enabled;
  return { document: next, ref };
}

function moveRoomEntry(next, context, ref, parsed, definition, origin, target) {
  const sameMenuRoom = origin.room === target.room;
  let roomId = parsed.roomId;
  if (!sameMenuRoom) {
    roomId = roomCandidates(parsed.upgradeId, definition, target.room, context).find((candidate) => !definition.rooms.includes(candidate));
    if (!roomId) return { error: "ROOM_NOT_AVAILABLE" };
  }
  const spot = templateSpot(definition, roomId, context);
  const groupId = target.group ?? "";
  const group = ensureGroup(next, context, target.room, spot, groupId);
  if (!group) return { error: "SPOT_ROOM_MISMATCH" };
  const sameGroup = sameMenuRoom && origin.spot === spot && origin.group === groupId;
  detach(next, ref, origin);
  const newRef = refOf(parsed.upgradeId, roomId);
  insertAt(group, newRef, sameGroup && target.index > origin.index ? target.index - 1 : target.index);
  definition.rooms = definition.rooms.map((room) => (room === parsed.roomId ? roomId : room));
  return { document: next, ref: newRef };
}

export function addPlacement(document, context, ref, target) {
  const parsed = parseRef(ref);
  if (parsed.kind !== "track") return { error: "SYSTEM_FIXED" };
  if (!document.upgrades[parsed.upgradeId]) return { error: "UNKNOWN_UPGRADE" };
  const next = clone(document);
  if (occurrences(next, ref).length === 0) return { error: "NOT_PLACED" };
  const group = ensureGroup(next, context, target.room, target.spot, target.group ?? "");
  if (!group) return { error: "SPOT_ROOM_MISMATCH" };
  if (alreadyAt(next, ref, target, null)) return { error: "ALREADY_PLACED" };
  insertAt(group, ref, target.index);
  return { document: next, ref };
}

export function addEntry(document, context, upgradeId, target) {
  const definition = document.upgrades[upgradeId];
  if (!definition) return { error: "UNKNOWN_UPGRADE" };
  const next = clone(document);
  const nextDefinition = next.upgrades[upgradeId];
  if (!isRoomUpgrade(nextDefinition)) {
    const ref = refOf(upgradeId, "");
    if (occurrences(next, ref).length > 0) return addPlacement(document, context, ref, target);
    const group = ensureGroup(next, context, target.room, target.spot, target.group ?? "");
    if (!group) return { error: "SPOT_ROOM_MISMATCH" };
    insertAt(group, ref, target.index);
    nextDefinition.spot = target.spot;
    delete nextDefinition.enabled;
    return { document: next, ref };
  }
  const roomId = roomCandidates(upgradeId, nextDefinition, target.room, context).find((candidate) => !nextDefinition.rooms.includes(candidate));
  if (!roomId) return { error: "ROOM_NOT_AVAILABLE" };
  const group = ensureGroup(next, context, target.room, templateSpot(nextDefinition, roomId, context), target.group ?? "");
  if (!group) return { error: "SPOT_ROOM_MISMATCH" };
  const ref = refOf(upgradeId, roomId);
  insertAt(group, ref, target.index);
  nextDefinition.rooms = [...nextDefinition.rooms, roomId];
  return { document: next, ref };
}

export function addRoomInstance(document, context, upgradeId, roomId) {
  const definition = document.upgrades[upgradeId];
  if (!definition || !isRoomUpgrade(definition)) return { error: "UNKNOWN_UPGRADE" };
  if (!allowedRooms(upgradeId, definition, context).includes(roomId) || definition.rooms.includes(roomId)) return { error: "ROOM_NOT_AVAILABLE" };
  const next = clone(document);
  const nextDefinition = next.upgrades[upgradeId];
  const spot = templateSpot(nextDefinition, roomId, context);
  const group = ensureGroup(next, context, spotRoom(spot, context), spot);
  if (!group) return { error: "SPOT_ROOM_MISMATCH" };
  const ref = refOf(upgradeId, roomId);
  group.entries.push(ref);
  nextDefinition.rooms = [...nextDefinition.rooms, roomId];
  return { document: next, ref };
}

export function removeEntry(document, ref, from = null) {
  const parsed = parseRef(ref);
  if (parsed.kind !== "track") return { error: "SYSTEM_FIXED" };
  const next = clone(document);
  if (!detach(next, ref, from)) return { error: "NOT_PLACED" };
  const definition = next.upgrades[parsed.upgradeId];
  const remaining = occurrences(next, ref);
  if (remaining.length > 0) {
    if (!isRoomUpgrade(definition) && remaining.every((occurrence) => occurrence.spot !== definition.spot)) definition.spot = remaining[0].spot;
    return { document: next };
  }
  if (isRoomUpgrade(definition)) definition.rooms = definition.rooms.filter((room) => room !== parsed.roomId);
  else definition.enabled = false;
  return { document: next };
}

export function removeAllPlacements(document, ref) {
  let next = document;
  for (let guard = 0; guard < 1000 && occurrences(next, ref).length > 0; guard += 1) {
    const result = removeEntry(next, ref);
    if (result.error) return result;
    next = result.document;
  }
  return { document: next };
}

export function placementOf(document, ref) {
  return findLocation(document, ref);
}

export function unplacedUpgrades(document) {
  const result = [];
  for (const [id, definition] of Object.entries(document.upgrades)) {
    if (!isRoomUpgrade(definition) && !findLocation(document, refOf(id, ""))) result.push(id);
  }
  return result;
}

export function moveInList(list, from, to) {
  const next = [...list];
  const [item] = next.splice(from, 1);
  next.splice(clampIndex(to > from ? to - 1 : to, next.length), 0, item);
  return next;
}

export function moveGroup(document, roomId, spot, toIndex, groupId = "") {
  const next = clone(document);
  const room = next.menu.rooms.find((candidate) => candidate.id === roomId);
  const from = room?.groups.findIndex((group) => group.spot === spot && groupIdOf(group) === groupId) ?? -1;
  if (from < 0) return { error: "NOT_PLACED" };
  room.groups = moveInList(room.groups, from, toIndex);
  return { document: next };
}

export function groupSlug(title, existing) {
  const base = String(title ?? "").toLowerCase().normalize("NFKD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "").slice(0, 30) || "group";
  const start = /^[a-z]/.test(base) ? base : "g_" + base;
  let id = start;
  for (let counter = 2; existing.includes(id); counter += 1) id = `${start}_${counter}`;
  return id;
}

function cleanTitle(title) {
  const de = String(title?.de ?? "").trim();
  const en = String(title?.en ?? "").trim();
  return de && en ? { de, en } : null;
}

export function addSubgroup(document, context, roomId, spot, title) {
  const clean = cleanTitle(title);
  if (!clean) return { error: "GROUP_TITLE" };
  const next = clone(document);
  const room = next.menu.rooms.find((candidate) => candidate.id === roomId);
  if (!room || spotRoom(spot, context) !== roomId) return { error: "SPOT_ROOM_MISMATCH" };
  const id = groupSlug(clean.en, room.groups.filter((group) => group.spot === spot).map(groupIdOf));
  let position = room.groups.length;
  room.groups.forEach((group, index) => {
    if (group.spot === spot) position = index + 1;
  });
  room.groups.splice(position, 0, { spot, id, title: clean, entries: [] });
  return { document: next, groupId: id };
}

export function setSubgroupTitle(document, roomId, spot, groupId, title) {
  const clean = cleanTitle(title);
  if (!clean) return { error: "GROUP_TITLE" };
  const next = clone(document);
  const group = next.menu.rooms.find((candidate) => candidate.id === roomId)?.groups.find((candidate) => candidate.spot === spot && groupId !== "" && groupIdOf(candidate) === groupId);
  if (!group) return { error: "NOT_PLACED" };
  group.title = clean;
  return { document: next };
}

export function removeSubgroup(document, context, roomId, spot, groupId) {
  const next = clone(document);
  const room = next.menu.rooms.find((candidate) => candidate.id === roomId);
  const index = room?.groups.findIndex((group) => group.spot === spot && groupId !== "" && groupIdOf(group) === groupId) ?? -1;
  if (index < 0) return { error: "NOT_PLACED" };
  const [removed] = room.groups.splice(index, 1);
  if (removed.entries.length > 0) {
    const target = ensureGroup(next, context, roomId, spot, "");
    target.entries.push(...removed.entries);
  }
  return { document: next };
}

export function moveRoom(document, roomId, toIndex) {
  const next = clone(document);
  const from = next.menu.rooms.findIndex((room) => room.id === roomId);
  if (from < 0) return { error: "NOT_PLACED" };
  next.menu.rooms = moveInList(next.menu.rooms, from, toIndex);
  return { document: next };
}

export function moveTopic(document, topicId, toIndex) {
  const next = clone(document);
  const from = next.menu.topics.findIndex((topic) => topic.id === topicId);
  if (from < 0) return { error: "NOT_PLACED" };
  next.menu.topics = moveInList(next.menu.topics, from, toIndex);
  return { document: next };
}

export function moveTopicItem(document, ref, toTopic, toIndex) {
  const next = clone(document);
  const target = next.menu.topics.find((topic) => topic.id === toTopic);
  if (!target) return { error: "NOT_PLACED" };
  let index = toIndex ?? target.items.length;
  for (const topic of next.menu.topics) {
    const position = topic.items.indexOf(ref);
    if (position < 0) continue;
    topic.items.splice(position, 1);
    if (topic === target && position < index) index -= 1;
  }
  target.items.splice(clampIndex(index, target.items.length), 0, ref);
  const parsed = parseRef(ref);
  if (parsed.kind === "track") next.upgrades[parsed.upgradeId].topic = toTopic;
  return { document: next };
}

const MODEL_FIELDS = ["cost_model", "value_model"];

export function scopedDefinition(document, upgradeId, scope = "") {
  const base = document.upgrades[upgradeId];
  if (!base || !scope) return base;
  const { room_overrides: overrides, ...rest } = base;
  const merged = { ...rest, ...(overrides?.[scope] ?? {}) };
  for (const field of MODEL_FIELDS) {
    if (merged[field] && Object.keys(merged[field]).length === 0) delete merged[field];
  }
  return merged;
}

export function hasRoomOverride(document, upgradeId, roomId) {
  return Object.keys(document.upgrades[upgradeId]?.room_overrides?.[roomId] ?? {}).length > 0;
}

export function updateUpgrade(document, upgradeId, patch, scope = "") {
  if (scope) return updateOverride(document, upgradeId, patch, scope);
  const next = clone(document);
  next.upgrades[upgradeId] = { ...next.upgrades[upgradeId], ...patch };
  for (const [key, value] of Object.entries(patch)) {
    if (value === undefined) delete next.upgrades[upgradeId][key];
  }
  if (patch.max !== undefined) resizeTables(next.upgrades[upgradeId]);
  return next;
}

function updateOverride(document, upgradeId, patch, scope) {
  const next = clone(document);
  const base = next.upgrades[upgradeId];
  const override = { ...(base.room_overrides?.[scope] ?? {}), ...patch };
  for (const [key, value] of Object.entries(patch)) {
    if (value === undefined) delete override[key];
  }
  if (patch.max !== undefined) {
    const merged = { ...base, ...override };
    resizeTables(merged);
    for (const field of MODEL_FIELDS) {
      if (merged[field] && Object.keys(merged[field]).length > 0) override[field] = merged[field];
    }
  }
  const overrides = { ...(base.room_overrides ?? {}), [scope]: override };
  if (Object.keys(override).length === 0) delete overrides[scope];
  if (Object.keys(overrides).length === 0) delete base.room_overrides;
  else base.room_overrides = overrides;
  return next;
}

export function clearRoomOverride(document, upgradeId, roomId) {
  if (!document.upgrades[upgradeId]) return { error: "UNKNOWN_UPGRADE" };
  const next = clone(document);
  const base = next.upgrades[upgradeId];
  if (base.room_overrides) {
    delete base.room_overrides[roomId];
    if (Object.keys(base.room_overrides).length === 0) delete base.room_overrides;
  }
  return { document: next };
}

function resizeList(list, length, fill) {
  const result = list.slice(0, length);
  while (result.length < length) result.push(result.length > 0 ? result[result.length - 1] : fill);
  return result;
}

function resizeTables(definition) {
  const max = definition.max;
  if (definition.cost_model?.mode === "table") definition.cost_model = { ...definition.cost_model, levels: resizeList(definition.cost_model.levels ?? [], max, 0) };
  if (definition.value_model?.mode === "table") definition.value_model = { ...definition.value_model, increments: resizeList(definition.value_model.increments ?? [], max, 0) };
}

export const MODEL_KINDS = { cost: { key: "cost_model", table: "levels" }, value: { key: "value_model", table: "increments" } };

function parametric(definition) {
  const { cost_model: _cost, value_model: _value, ...rest } = definition;
  return rest;
}

export function tableFromParameters(definition, kind, constants) {
  const plain = parametric(definition);
  if (kind === "cost") return Array.from({ length: definition.max }, (_, level) => trackCost(plain, level, 1, constants));
  return Array.from({ length: definition.max }, (_, level) => trackValue(plain, level + 1, constants) - trackValue(plain, level, constants));
}

export const FORMULA_HISTORY_LIMIT = 30;

export function formulaHistory(definition, kind) {
  return definition?.formula_history?.[kind] ?? [];
}

export function tableFromFormula(definition, kind, formula) {
  const check = checkFormula(kind, definition, formula);
  if (!check.ok) return { error: check.code, level: check.level };
  const value = (level) => evaluate(formula, kind === "cost" ? costVariables(definition, level) : valueVariables(definition, level)).value;
  const values = Array.from({ length: definition.max }, (_, level) => (kind === "cost" ? value(level) : value(level + 1) - value(level)));
  return { values };
}

export function rememberFormula(document, upgradeId, kind, text, scope = "") {
  const definition = document.upgrades[upgradeId];
  if (!definition) return { error: "UNKNOWN_UPGRADE" };
  const formula = String(text ?? "").trim();
  const result = tableFromFormula(scopedDefinition(document, upgradeId, scope), kind, formula);
  if (result.error) return result;
  const history = [formula, ...formulaHistory(definition, kind).filter((entry) => entry !== formula)].slice(0, FORMULA_HISTORY_LIMIT);
  return { document: updateUpgrade(document, upgradeId, { formula_history: { ...definition.formula_history, [kind]: history } }), values: result.values, formula };
}

export function deleteFormulaFromHistory(document, upgradeId, kind, formula) {
  const definition = document.upgrades[upgradeId];
  if (!definition) return { error: "UNKNOWN_UPGRADE" };
  const remaining = formulaHistory(definition, kind).filter((entry) => entry !== formula);
  const next = { ...definition.formula_history, [kind]: remaining };
  if (remaining.length === 0) delete next[kind];
  return { document: updateUpgrade(document, upgradeId, { formula_history: Object.keys(next).length === 0 ? undefined : next }) };
}

export function fillValues(values, fill) {
  if (fill.type === "same") return values.map(() => fill.value);
  if (fill.type === "from") return values.map((value, index) => (index >= fill.index ? fill.value : value));
  return values.map((value, index) => (index >= fill.index ? value * fill.factor : value));
}

export function closeTables(left, right) {
  return left.length === right.length && left.every((value, index) => Math.abs(value - right[index]) <= 1e-9 * Math.max(1, Math.abs(right[index])));
}

export const MAX_TABLE_LEVELS = 100000;

export function applyTables(document, upgradeId, draft, constants, scope = "") {
  if (!document.upgrades[upgradeId]) return { error: "UNKNOWN_UPGRADE" };
  const definition = scopedDefinition(document, upgradeId, scope);
  const length = draft.cost.length;
  if (length !== draft.value.length || length < 1 || length > MAX_TABLE_LEVELS) return { error: "TABLE_LENGTH" };
  if (draft.cost.some((value) => !Number.isFinite(value) || value < 0) || draft.value.some((value) => !Number.isFinite(value))) return { error: "TABLE_VALUE" };
  const sized = length === definition.max ? document : updateUpgrade(document, upgradeId, { max: length }, scope);
  const resized = scopedDefinition(sized, upgradeId, scope);
  const inherited = scope ? scopedDefinition(sized, upgradeId, "") : null;
  const patch = {};
  for (const kind of Object.keys(MODEL_KINDS)) {
    const { key, table } = MODEL_KINDS[kind];
    const formula = draft.formula?.[kind];
    if (closeTables(draft[kind], tableFromParameters(resized, kind, constants))) patch[key] = scope && inherited[key] ? {} : undefined;
    else patch[key] = { mode: "table", [table]: [...draft[kind]], ...(formula ? { formula } : {}) };
  }
  return { document: updateUpgrade(sized, upgradeId, patch, scope) };
}

export function setSystemValue(document, section, id, field, value) {
  const next = clone(document);
  next.system ??= {};
  if (section === "constants") {
    next.system.constants ??= {};
    next.system.constants[id] = value;
  } else {
    next.system[section] ??= {};
    next.system[section][id] ??= {};
    next.system[section][id][field] = value;
  }
  return next;
}

export function setText(document, key, language, value, baseValue) {
  const next = clone(document);
  next.text_overrides ??= {};
  const entry = { ...(next.text_overrides[key] ?? {}) };
  if (value === baseValue) delete entry[language];
  else entry[language] = value;
  if (Object.keys(entry).length === 0) delete next.text_overrides[key];
  else next.text_overrides[key] = entry;
  return next;
}

const mergedContexts = new WeakMap();

const isFilled = (value) => Boolean(value) && Object.keys(value).length > 0;

export function withAreas(context, document) {
  const areas = document.areas;
  const overrides = document.spot_rects;
  if (!isFilled(areas) && !isFilled(overrides)) return context;
  const cached = mergedContexts.get(context);
  if (cached && cached.areas === areas && cached.overrides === overrides) return cached.merged;
  const spots = { ...context.spots };
  for (const [spot, replacements] of Object.entries(overrides ?? {})) {
    const info = spots[spot];
    if (!info) continue;
    const edited = Object.keys(replacements).map(Number).filter((index) => index < info.rects.length);
    spots[spot] = { ...info, rects: info.rects.map((rect, index) => replacements[index] ?? rect), edited };
  }
  for (const [id, area] of Object.entries(areas ?? {})) spots["area:" + id] = { room: area.room, rects: area.rects, visible: [], custom: true };
  const merged = { ...context, spots };
  mergedContexts.set(context, { areas, overrides, merged });
  return merged;
}

export function areaSlug(title, existing) {
  const base = String(title).normalize("NFKD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "").replace(/^[^a-z]+/, "").slice(0, 32) || "area";
  let candidate = base;
  for (let counter = 2; existing.includes(candidate); counter += 1) candidate = `${base}_${counter}`;
  return candidate;
}

export function addArea(document, { id, room, rect }) {
  if (!document.menu.rooms.some((candidate) => candidate.id === room)) return { error: "AREA_ROOM" };
  if (document.areas?.[id]) return { error: "AREA_EXISTS" };
  const next = clone(document);
  next.areas = { ...(next.areas ?? {}), [id]: { room, rects: [rect] } };
  next.menu.rooms.find((candidate) => candidate.id === room).groups.push({ spot: "area:" + id, entries: [] });
  return { document: next, spot: "area:" + id };
}

export function areaContents(document, id) {
  const spot = "area:" + id;
  const refs = [];
  for (const room of document.menu.rooms) {
    for (const group of room.groups) {
      if (group.spot !== spot) continue;
      for (const ref of group.entries) if (!refs.includes(ref)) refs.push(ref);
    }
  }
  return refs;
}

function releaseFromArea(document, ref, spot) {
  let next = document;
  for (const where of occurrences(next, ref).filter((occurrence) => occurrence.spot === spot)) {
    const result = removeEntry(next, ref, where);
    if (!result.error) next = result.document;
  }
  return next;
}

export function removeArea(document, id) {
  const area = document.areas?.[id];
  if (!area) return { error: "AREA_UNKNOWN" };
  const spot = "area:" + id;
  const released = areaContents(document, id);
  let next = clone(document);
  for (const ref of released) next = releaseFromArea(next, ref, spot);
  const fallback = next.menu.rooms.find((room) => room.id === area.room)?.groups.find((group) => group.spot !== spot)?.spot ?? "player";
  for (const definition of Object.values(next.upgrades)) if (definition.spot === spot) definition.spot = fallback;
  delete next.areas[id];
  for (const room of next.menu.rooms) room.groups = room.groups.filter((group) => group.spot !== spot);
  const key = "SPOT_AREA_" + id.toUpperCase();
  if (next.text_overrides?.[key]) delete next.text_overrides[key];
  return { document: next, released: released.length };
}

export function isValidRect(rect) {
  return Array.isArray(rect) && rect.length === 4 && rect.every((value) => typeof value === "number" && Number.isFinite(value)) && rect[2] > 0 && rect[3] > 0;
}

const sameRect = (a, b) => a.length === b.length && a.every((value, position) => value === b[position]);

export function setAreaRect(document, id, index, rect) {
  if (!document.areas?.[id]?.rects[index]) return { error: "AREA_UNKNOWN" };
  if (!isValidRect(rect)) return { error: "RECT_INVALID" };
  const next = clone(document);
  next.areas[id].rects[index] = rect;
  return { document: next };
}

export function addAreaRect(document, id, rect) {
  if (!document.areas?.[id]) return { error: "AREA_UNKNOWN" };
  const next = clone(document);
  next.areas[id].rects.push(rect);
  return { document: next };
}

export function removeAreaRect(document, id, index) {
  const rects = document.areas?.[id]?.rects;
  if (!rects?.[index]) return { error: "AREA_UNKNOWN" };
  if (rects.length === 1) return { error: "AREA_LAST_RECT" };
  const next = clone(document);
  next.areas[id].rects.splice(index, 1);
  return { document: next };
}

export function resizeSpotRect(document, baseContext, spot, index, rect) {
  if (spot.startsWith("area:")) return setAreaRect(document, spot.slice(5), index, rect);
  const base = baseContext.spots[spot]?.rects[index];
  if (!base) return { error: "SPOT_RECT_UNKNOWN" };
  if (!isValidRect(rect)) return { error: "RECT_INVALID" };
  const edited = Boolean(document.spot_rects?.[spot]?.[String(index)]);
  if (sameRect(rect, base)) return { document: edited ? dropSpotRect(clone(document), spot, index) : document };
  const next = clone(document);
  next.spot_rects ??= {};
  next.spot_rects[spot] ??= {};
  next.spot_rects[spot][String(index)] = rect;
  return { document: next };
}

function dropSpotRect(next, spot, index) {
  const replacements = next.spot_rects?.[spot];
  if (!replacements) return next;
  if (index === null) delete next.spot_rects[spot];
  else delete replacements[String(index)];
  if (Object.keys(next.spot_rects[spot] ?? {}).length === 0) delete next.spot_rects[spot];
  if (Object.keys(next.spot_rects).length === 0) delete next.spot_rects;
  return next;
}

export function resetSpotRect(document, spot, index = null) {
  const replacements = document.spot_rects?.[spot];
  if (!replacements || (index !== null && !replacements[String(index)])) return { error: "SPOT_RECT_UNKNOWN" };
  return { document: dropSpotRect(clone(document), spot, index) };
}

export function isSpotRectEdited(document, spot, index) {
  return Boolean(document.spot_rects?.[spot]?.[String(index)]);
}

export function normaliseRect(a, b) {
  const x = Math.min(a.x, b.x);
  const y = Math.min(a.y, b.y);
  return [Math.round(x), Math.round(y), Math.max(1, Math.round(Math.abs(a.x - b.x))), Math.max(1, Math.round(Math.abs(a.y - b.y)))];
}
