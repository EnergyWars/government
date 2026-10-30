import { h } from "../dom.js";
import { dropInto, dropItem } from "../dnd.js";
import { addAreaRect, addEntry, removeArea, removeAreaRect, setAreaRect, findLocation, groupIdOf, groupsOf, isRoomUpgrade, moveEntry, occurrences, removeEntry, roomCandidates, spotRoom, visibleAt, refOf } from "../model.js";
import { entryCard, iconButton, select } from "./components.js";
import { titleEditor } from "./titleEditor.js";
import { groupChoices, parseTarget, subgroupForm, subgroupHeader, targetValue } from "./groupTools.js";

const ENTRY_TYPES = ["entry", "palette"];

export function applyDrop(app, payload, target) {
  const { context } = app.store.state;
  if (payload.type === "entry") {
    const result = app.edit((document) => moveEntry(document, context, payload.ref, target, payload.from));
    if (result.ref) app.store.select({ ref: result.ref });
    return;
  }
  if (payload.type === "palette") {
    const result = app.edit((document) => addEntry(document, context, payload.upgradeId, target));
    if (result.ref) app.store.select({ ref: result.ref });
  }
}

export function groupTarget(app, spot, index, group = "") {
  return { room: spotRoom(spot, app.store.state.context), spot, index, group };
}

const fromOf = (entry) => ({ room: entry.room, spot: entry.spot, group: entry.group ?? "" });

export function neighbourMove(app, entry, direction) {
  const { document, context } = app.store.state;
  const from = fromOf(entry);
  const location = findLocation(document, entry.id, from);
  if (!location) return;
  const target = { room: location.room, spot: location.spot, group: location.group, index: direction < 0 ? location.index - 1 : location.index + 2 };
  if (target.index < 0) return;
  app.edit((current) => moveEntry(current, context, entry.id, target, from));
}

export function removeAction(app, entry) {
  if (entry.fixed) return null;
  return () => {
    app.edit((document) => removeEntry(document, entry.id, fromOf(entry)));
    if (app.store.state.selection?.ref === entry.id) app.store.select(null);
  };
}

export function renderGroupCards(app, group, container, visibleIds = null) {
  const { document } = app.store.state;
  const members = visibleIds ? group.entries.filter((entry) => visibleIds.has(entry.id)) : group.entries;
  members.forEach((entry) => {
    const location = findLocation(document, entry.id, fromOf(entry));
    const card = entryCard(app, entry, {
      onUp: () => neighbourMove(app, entry, -1),
      onDown: () => neighbourMove(app, entry, 1),
      onRemove: removeAction(app, entry),
    });
    dropItem(card, {
      accept: (payload) => ENTRY_TYPES.includes(payload.type),
      index: location?.index ?? 0,
      onDrop: (payload, index) => applyDrop(app, payload, groupTarget(app, entry.spot, index, entry.group ?? "")),
    });
    container.append(card);
  });
}

function eligibleUpgrades(app, target) {
  const { document, context } = app.store.state;
  const { texts } = app.derived();
  const menuRoom = target.room;
  const options = [];
  for (const [id, definition] of Object.entries(document.upgrades)) {
    if (isRoomUpgrade(definition)) {
      const free = roomCandidates(id, definition, menuRoom, context).some((roomId) => !definition.rooms.includes(roomId));
      if (free) options.push({ value: id, label: texts.text(texts.upgradeTitleKey(id)) });
      continue;
    }
    const found = occurrences(document, refOf(id, ""));
    if (found.some((location) => location.spot === target.spot && location.room === menuRoom)) continue;
    const suffix = found.length ? ` (${app.t("hint.alsoHere")})` : ` (${app.t("hint.unplaced")})`;
    options.push({ value: id, label: texts.text(texts.upgradeTitleKey(id)) + suffix, keywords: id });
  }
  return options.sort((a, b) => a.label.localeCompare(b.label, app.i18n.language));
}

function addControl(app, spot) {
  const room = spotRoom(spot, app.store.state.context);
  const choices = groupChoices(app, room);
  if (choices.length === 0) return null;
  const wanted = choices.find((choice) => choice.value === targetValue(room, spot, ""));
  let target = (wanted ?? choices[0]).value;
  let upgradeId = "";
  const holder = h("div", { class: "add-control" });
  const draw = () => {
    const options = eligibleUpgrades(app, parseTarget(target));
    if (!options.some((option) => option.value === upgradeId)) upgradeId = options[0]?.value ?? "";
    holder.replaceChildren(
      h("label", {}, app.t("panel.addTitle")),
      choices.length > 1 ? select(choices, target, (value) => { target = value; draw(); }, { label: app.t("panel.addTarget") }) : null,
      select(options, upgradeId, (value) => { upgradeId = value; }, { label: app.t("panel.addUpgrade") }),
      h("button", { type: "button", class: "primary", disabled: !upgradeId, onClick: () => {
        const { spot: targetSpot, group } = parseTarget(target);
        applyDrop(app, { type: "palette", upgradeId }, groupTarget(app, targetSpot, undefined, group));
      } }, app.t("action.add")),
    );
  };
  draw();
  return holder;
}

function areaEditor(app, spot) {
  const id = spot.slice(5);
  const area = app.store.state.document.areas?.[id];
  if (!area) return null;
  const labels = ["x", "y", "width", "height"];
  const rows = area.rects.map((rect, index) => h("div", { class: "row rect-row" },
    labels.map((label, position) => h("input", { type: "number", min: position > 1 ? 1 : undefined, value: rect[position], "aria-label": app.t("area.rect." + label), title: app.t("area.rect." + label), onChange: (event) => {
      const value = Number(event.target.value);
      if (!Number.isFinite(value) || (position > 1 && value < 1)) {
        event.target.classList.add("invalid");
        return;
      }
      const next = [...rect];
      next[position] = value;
      app.edit((document) => setAreaRect(document, id, index, next), { origin: "area" });
    } })),
    iconButton(app.t("area.removeRect"), "✕", () => app.edit((document) => removeAreaRect(document, id, index), { origin: "area" }), { class: "danger" })));
  const add = h("button", { type: "button", onClick: () => app.edit((document) => addAreaRect(document, id, [...area.rects[0].slice(0, 2).map((value) => value + 20), ...area.rects[0].slice(2)]), { origin: "area" }) }, "＋ " + app.t("area.addRect"));
  const remove = h("button", { type: "button", class: "danger-button", onClick: () => {
    if (!window.confirm(app.t("area.confirmDelete"))) return;
    const result = app.edit((document) => removeArea(document, id), { origin: "area" });
    if (!result.error) app.ui.spot = null;
  } }, app.t("area.delete"));
  return h("section", { class: "area-editor" }, h("h3", {}, app.t("area.custom")), rows, h("div", { class: "row" }, add, remove));
}

function documentGroup(app, group) {
  const { document, context } = app.store.state;
  const room = spotRoom(group.spot, context);
  const found = document.menu.rooms.find((candidate) => candidate.id === room)?.groups.find((candidate) => candidate.spot === group.spot && groupIdOf(candidate) === group.group);
  return { room, group: found ?? { spot: group.spot, id: group.group, entries: [] } };
}

function withEmptySubgroups(app, groups, spot) {
  const { document, context } = app.store.state;
  const result = [...groups];
  const room = document.menu.rooms.find((candidate) => candidate.id === spotRoom(spot, context));
  const spots = new Set([spot, ...groups.map((group) => group.spot)]);
  for (const candidate of room?.groups ?? []) {
    if (!candidate.id || !spots.has(candidate.spot)) continue;
    if (!result.some((group) => group.spot === candidate.spot && group.group === candidate.id)) result.push({ spot: candidate.spot, group: candidate.id, entries: [] });
  }
  const position = (group) => room?.groups.findIndex((candidate) => candidate.spot === group.spot && groupIdOf(candidate) === group.group) ?? -1;
  return result.sort((a, b) => position(a) - position(b));
}

export function renderSpotPanel(app, spot) {
  const panel = h("div", { class: "spot-panel", dataset: { scroll: "spot" } });
  if (!spot) {
    panel.append(h("p", { class: "hint" }, app.t("panel.empty")));
    return panel;
  }
  const { texts, entries } = app.derived();
  const { context } = app.store.state;
  const visible = visibleAt(entries, spot);
  const groups = groupsOf(visible);
  const room = spotRoom(spot, context);
  panel.append(h("div", { class: "intro" },
    room && room !== spot.replace(/^(room|dept):/, "") ? h("div", { class: "intro-room" }, texts.roomTitle(room)) : null,
    h("h2", {}, texts.spotTitle(spot)),
    h("p", {}, texts.spotDescription(spot)),
    h("div", { class: "intro-meta" }, app.t("panel.entryCount", { count: visible.length }), " · ", h("code", {}, spot)),
  ));
  panel.append(spot.startsWith("area:") ? areaEditor(app, spot) : null);
  const showHeaders = !(spot.startsWith("station:") || spot.startsWith("trays:")) && groups.length > 1;
  const visibleIds = new Set(visible.map((entry) => entry.id));
  const ordered = withEmptySubgroups(app, groups, spot);
  for (const group of ordered) {
    const list = h("div", { class: "card-list" });
    renderGroupCards(app, group, list, visibleIds);
    dropInto(list, { accept: (payload) => ENTRY_TYPES.includes(payload.type), onDrop: (payload) => applyDrop(app, payload, groupTarget(app, group.spot, undefined, group.group)) });
    const doc = documentGroup(app, group);
    const header = group.group ? subgroupHeader(app, doc.room, doc.group) : showHeaders ? groupHeader(app, group.spot) : null;
    panel.append(h("section", { class: "group" + (group.group ? " subgroup" : "") }, header, list));
  }
  if (ordered.length === 0) {
    const list = h("div", { class: "card-list" });
    dropInto(list, { accept: (payload) => ENTRY_TYPES.includes(payload.type), onDrop: (payload) => applyDrop(app, payload, groupTarget(app, spot, undefined)) });
    panel.append(h("section", { class: "group" }, groupHeader(app, spot), list), h("p", { class: "hint" }, app.t("panel.noEntries")));
  }
  const adder = addControl(app, spot);
  if (adder) panel.append(adder);
  if (room && !spot.startsWith("station:") && !spot.startsWith("trays:")) panel.append(subgroupForm(app, room, [spot]));
  return panel;
}

export function groupHeader(app, spot, extra = []) {
  const { texts } = app.derived();
  const key = texts.spotTitleKey(spot);
  return h("header", { class: "group-header" },
    key ? titleEditor(app, key, texts.spotTitle(spot)) : h("h3", {}, texts.spotTitle(spot)),
    ...extra,
  );
}

export { iconButton };
