import { h } from "../dom.js";
import { dropInto, dropItem, makeDraggable } from "../dnd.js";
import { findLocation, groupIdOf, isRoomUpgrade, moveGroup, moveRoom, moveTopic, moveTopicItem, parseRef, refOf } from "../model.js";
import { chip, iconButton, metricsRow } from "./components.js";
import { applyDrop, groupHeader, groupTarget, renderGroupCards } from "./spotPanel.js";
import { subgroupForm, subgroupHeader } from "./groupTools.js";

const ENTRY_TYPES = ["entry", "palette"];

function expandedKey(mode, id) {
  return `${mode}:${id}`;
}

function toggle(app, key) {
  app.ui.expanded[key] = !app.ui.expanded[key];
  app.rerender();
}

function dropOnRoom(app, payload, room) {
  const { document } = app.store.state;
  const upgradeId = payload.type === "palette" ? payload.upgradeId : parseRef(payload.ref).upgradeId;
  const definition = upgradeId ? document.upgrades[upgradeId] : null;
  const first = room.groups[0]?.spot;
  if (definition && !isRoomUpgrade(definition) && !first) {
    app.notify(app.t("error.NO_GROUP"), "error");
    return;
  }
  applyDrop(app, payload, { room: room.id, spot: first ?? "", index: undefined });
}

function roomSection(app, room, index) {
  const { texts, entries } = app.derived();
  const key = expandedKey("rooms", room.id);
  const open = Boolean(app.ui.expanded[key]);
  const count = room.groups.reduce((sum, group) => sum + group.entries.length, 0);
  const handle = h("span", { class: "handle", title: app.t("action.drag") }, "⠿");
  const header = h("header", { class: "section-header", onClick: () => toggle(app, key) },
    handle,
    h("span", { class: "chevron" }, open ? "▼" : "▶"),
    h("h2", {}, texts.roomTitle(room.id)),
    h("span", { class: "count" }, app.t("menu.count", { count })),
    h("span", { class: "grow" }),
    iconButton(app.t("action.up"), "▲", (event) => { event.stopPropagation(); app.edit((document) => moveRoom(document, room.id, index - 1)); }, { disabled: index === 0 }),
    iconButton(app.t("action.down"), "▼", (event) => { event.stopPropagation(); app.edit((document) => moveRoom(document, room.id, index + 2)); }),
  );
  const section = h("section", { class: "room-section" }, header);
  makeDraggable(section, { type: "room", id: room.id }, handle);
  dropItem(section, { accept: (payload) => payload.type === "room", index, onDrop: (payload, target) => app.edit((document) => moveRoom(document, payload.id, target)) });
  dropInto(header, { accept: (payload) => ENTRY_TYPES.includes(payload.type), onDrop: (payload) => dropOnRoom(app, payload, room) });
  if (!open) return section;
  const body = h("div", { class: "section-body" });
  room.groups.forEach((group, groupIndex) => body.append(groupSection(app, room, group, groupIndex, entries)));
  if (room.groups.length === 0) body.append(h("p", { class: "hint" }, app.t("menu.noGroups")));
  const form = subgroupForm(app, room.id, [...new Set(room.groups.map((group) => group.spot))]);
  if (form) body.append(form);
  section.append(body);
  return section;
}

function groupSection(app, room, group, groupIndex, entries) {
  const groupId = groupIdOf(group);
  const members = entries.filter((entry) => entry.room === room.id && entry.spot === group.spot && (entry.group ?? "") === groupId && group.entries.includes(entry.id));
  members.sort((a, b) => group.entries.indexOf(a.id) - group.entries.indexOf(b.id));
  const handle = h("span", { class: "handle", title: app.t("action.drag") }, "⠿");
  const controls = [
    h("span", { class: "count" }, app.t("menu.count", { count: members.length })),
    h("span", { class: "grow" }),
    iconButton(app.t("action.up"), "▲", () => app.edit((document) => moveGroup(document, room.id, group.spot, groupIndex - 1, groupId)), { disabled: groupIndex === 0 }),
    iconButton(app.t("action.down"), "▼", () => app.edit((document) => moveGroup(document, room.id, group.spot, groupIndex + 2, groupId))),
  ];
  const header = groupId ? subgroupHeader(app, room.id, group, controls) : groupHeader(app, group.spot, controls);
  header.prepend(handle);
  const list = h("div", { class: "card-list" });
  renderGroupCards(app, { entries: members }, list);
  dropInto(list, { accept: (payload) => ENTRY_TYPES.includes(payload.type), onDrop: (payload) => applyDrop(app, payload, groupTarget(app, group.spot, undefined, groupId)) });
  const section = h("section", { class: "group" + (groupId ? " subgroup" : "") }, header, list);
  makeDraggable(section, { type: "group", room: room.id, spot: group.spot, group: groupId }, handle);
  dropItem(section, { accept: (payload) => payload.type === "group" && payload.room === room.id, index: groupIndex, onDrop: (payload, target) => app.edit((document) => moveGroup(document, room.id, payload.spot, target, payload.group ?? "")) });
  return section;
}

function topicItemCard(app, topicId, ref, index) {
  const { texts, entries } = app.derived();
  const parsed = parseRef(ref);
  const handle = h("span", { class: "handle", title: app.t("action.drag") }, "⠿");
  const card = h("div", { class: "card", dataset: { ref } });
  makeDraggable(card, { type: "topicItem", ref }, handle);
  if (parsed.kind === "track") {
    const instances = entries.filter((entry) => entry.kind === "track" && entry.target === parsed.upgradeId);
    const entry = instances[0] ?? { id: ref, kind: "track", target: parsed.upgradeId, roomId: "", topic: topicId, room: "", spot: "" };
    const metrics = app.metrics(entry);
    card.classList.toggle("selected", app.store.state.selection?.ref === ref || instances.some((candidate) => candidate.id === app.store.state.selection?.ref));
    card.addEventListener("click", () => app.store.select({ ref: entry.id }));
    card.append(h("div", { class: "card-head" }, handle, h("div", { class: "card-title" }, texts.text(texts.upgradeTitleKey(parsed.upgradeId))),
      h("div", { class: "card-actions" }, chip(instances.length > 1 ? app.t("chip.instances", { count: instances.length }) : app.t("chip.instance"), ""))));
    if (metrics) card.append(metricsRow(app, metrics));
  } else {
    card.append(h("div", { class: "card-head" }, handle, h("div", { class: "card-title" }, app.t("system." + ref.slice(4).replace(/:/g, "_"))), h("div", { class: "card-actions" }, chip(app.t("chip.system"), "topic"))));
  }
  dropItem(card, { accept: (payload) => payload.type === "topicItem", index, onDrop: (payload, target) => app.edit((document) => moveTopicItem(document, payload.ref, topicId, target)) });
  return card;
}

function topicSection(app, topic, index) {
  const { texts } = app.derived();
  const key = expandedKey("topics", topic.id);
  const open = Boolean(app.ui.expanded[key]);
  const handle = h("span", { class: "handle", title: app.t("action.drag") }, "⠿");
  const header = h("header", { class: "section-header", onClick: () => toggle(app, key) },
    handle, h("span", { class: "chevron" }, open ? "▼" : "▶"), h("h2", {}, texts.topicTitle(topic.id)),
    h("span", { class: "count" }, app.t("menu.count", { count: topic.items.length })), h("span", { class: "grow" }),
    iconButton(app.t("action.up"), "▲", (event) => { event.stopPropagation(); app.edit((document) => moveTopic(document, topic.id, index - 1)); }, { disabled: index === 0 }),
    iconButton(app.t("action.down"), "▼", (event) => { event.stopPropagation(); app.edit((document) => moveTopic(document, topic.id, index + 2)); }),
  );
  const section = h("section", { class: "room-section" }, header);
  makeDraggable(section, { type: "topic", id: topic.id }, handle);
  dropItem(section, { accept: (payload) => payload.type === "topic", index, onDrop: (payload, target) => app.edit((document) => moveTopic(document, payload.id, target)) });
  dropInto(header, { accept: (payload) => payload.type === "topicItem", onDrop: (payload) => app.edit((document) => moveTopicItem(document, payload.ref, topic.id, undefined)) });
  if (!open) return section;
  const list = h("div", { class: "card-list section-body" });
  topic.items.forEach((ref, itemIndex) => list.append(topicItemCard(app, topic.id, ref, itemIndex)));
  dropInto(list, { accept: (payload) => payload.type === "topicItem", onDrop: (payload) => app.edit((document) => moveTopicItem(document, payload.ref, topic.id, undefined)) });
  section.append(list);
  return section;
}

function paletteRows(app, filter, onlyUnplaced) {
  const { document } = app.store.state;
  const { texts } = app.derived();
  const needle = filter.trim().toLowerCase();
  const rows = [];
  for (const [id, definition] of Object.entries(document.upgrades)) {
    const title = texts.text(texts.upgradeTitleKey(id));
    if (needle && !(title.toLowerCase().includes(needle) || id.includes(needle))) continue;
    const location = isRoomUpgrade(definition) ? null : findLocation(document, refOf(id, ""));
    const unplaced = isRoomUpgrade(definition) ? definition.rooms.length === 0 : !location;
    if (onlyUnplaced && !unplaced) continue;
    const status = isRoomUpgrade(definition) ? app.t("palette.rooms", { count: definition.rooms.length }) : location ? texts.roomTitle(location.room) : app.t("hint.unplaced");
    const row = h("div", { class: "palette-row" + (unplaced ? " unplaced" : ""), onClick: () => app.store.select({ ref: refOf(id, "") }) },
      h("span", { class: "handle" }, "⠿"), h("span", { class: "grow" }, title), chip(status, unplaced ? "warn" : ""));
    makeDraggable(row, { type: "palette", upgradeId: id });
    rows.push(row);
  }
  rows.sort((a, b) => a.textContent.localeCompare(b.textContent, app.i18n.language));
  return rows;
}

function palette(app) {
  const list = h("div", { class: "palette-list", dataset: { scroll: "palette" } });
  let onlyUnplaced = false;
  const draw = () => list.replaceChildren(...paletteRows(app, input.value, onlyUnplaced));
  const input = h("input", { type: "search", placeholder: app.t("palette.search"), "aria-label": app.t("palette.search"), onInput: draw });
  const toggleUnplaced = h("label", { class: "check" }, h("input", { type: "checkbox", onChange: (event) => { onlyUnplaced = event.target.checked; draw(); } }), app.t("palette.onlyUnplaced"));
  draw();
  return h("aside", { class: "palette" }, h("h2", {}, app.t("palette.title")), h("p", { class: "hint" }, app.t("palette.hint")), input, toggleUnplaced, list);
}

export function renderMenuTab(container, app) {
  const { document } = app.store.state;
  const mode = app.ui.menuMode;
  const modes = ["rooms", "topics"].map((id) => h("button", { type: "button", class: "segment" + (mode === id ? " active" : ""), onClick: () => { app.ui.menuMode = id; app.rerender(); } }, app.t("menu.mode." + id)));
  const keys = mode === "rooms" ? document.menu.rooms.map((room) => expandedKey("rooms", room.id)) : document.menu.topics.map((topic) => expandedKey("topics", topic.id));
  const setAll = (open) => { keys.forEach((key) => { app.ui.expanded[key] = open; }); app.rerender(); };
  const toolbar = h("div", { class: "menu-toolbar" }, h("div", { class: "segments" }, modes),
    h("button", { type: "button", onClick: () => setAll(true) }, app.t("menu.expandAll")),
    h("button", { type: "button", onClick: () => setAll(false) }, app.t("menu.collapseAll")));
  const lists = h("div", { class: "menu-lists", dataset: { scroll: "menu" } },
    h("p", { class: "hint" }, app.t("menu.hint." + mode)),
    mode === "rooms" ? document.menu.rooms.map((room, index) => roomSection(app, room, index)) : document.menu.topics.map((topic, index) => topicSection(app, topic, index)));
  container.append(h("div", { class: "menu-layout" }, h("section", { class: "menu-main" }, toolbar, lists), palette(app)));
}
