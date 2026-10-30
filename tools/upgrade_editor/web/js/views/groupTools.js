import { h } from "../dom.js";
import { addPlacement, addSubgroup, groupIdOf, occurrences, parseRef, removeEntry, removeSubgroup, setSubgroupTitle, spotRoom } from "../model.js";
import { iconButton, select } from "./components.js";

export const targetValue = (room, spot, group = "") => `${room}|${spot}|${group}`;

export function parseTarget(value) {
  const [room, spot, group = ""] = value.split("|");
  return { room, spot, group };
}

export function groupTitle(app, group) {
  return group.title ? group.title[app.i18n.language] ?? group.title.en ?? "" : "";
}

export function groupLabel(app, roomId, group) {
  const { texts } = app.derived();
  const base = `${texts.roomTitle(roomId)} · ${texts.spotTitle(group.spot)}`;
  return group.id ? `${base} · ${groupTitle(app, group)}` : base;
}

export function groupChoices(app, roomFilter = null) {
  const { document, context } = app.store.state;
  const options = [];
  for (const room of document.menu.rooms) {
    if (roomFilter && room.id !== roomFilter) continue;
    for (const group of room.groups) {
      if (spotRoom(group.spot, context) !== room.id) continue;
      options.push({ value: targetValue(room.id, group.spot, groupIdOf(group)), label: groupLabel(app, room.id, group) });
    }
  }
  return options;
}

export function subgroupHeader(app, roomId, group, extra = []) {
  const de = h("input", { type: "text", value: group.title?.de ?? "", maxLength: 120, "aria-label": app.t("subgroup.titleDe"), placeholder: app.t("subgroup.titleDe") });
  const en = h("input", { type: "text", value: group.title?.en ?? "", maxLength: 120, "aria-label": app.t("subgroup.titleEn"), placeholder: app.t("subgroup.titleEn") });
  const save = () => {
    if (de.value.trim() === (group.title?.de ?? "") && en.value.trim() === (group.title?.en ?? "")) return;
    const result = app.edit((document) => setSubgroupTitle(document, roomId, group.spot, group.id, { de: de.value, en: en.value }), { origin: "text" });
    if (result.error) {
      de.value = group.title?.de ?? "";
      en.value = group.title?.en ?? "";
    }
  };
  de.addEventListener("change", save);
  en.addEventListener("change", save);
  const remove = iconButton(app.t("subgroup.delete"), "✕", () => {
    if (window.confirm(app.t("subgroup.confirmDelete"))) app.edit((document) => removeSubgroup(document, app.store.state.context, roomId, group.spot, group.id), { origin: "text" });
  }, { class: "danger" });
  return h("header", { class: "group-header subgroup-header" }, h("span", { class: "chip topic" }, app.t("subgroup.badge")), de, en, ...extra, remove);
}

export function subgroupForm(app, roomId, spots) {
  const { texts } = app.derived();
  if (spots.length === 0) return null;
  let spot = spots[0];
  const de = h("input", { type: "text", maxLength: 120, "aria-label": app.t("subgroup.titleDe"), placeholder: app.t("subgroup.titleDe") });
  const en = h("input", { type: "text", maxLength: 120, "aria-label": app.t("subgroup.titleEn"), placeholder: app.t("subgroup.titleEn") });
  const add = () => {
    const result = app.edit((document) => addSubgroup(document, app.store.state.context, roomId, spot, { de: de.value, en: en.value }), { origin: "text" });
    if (!result.error) {
      de.value = "";
      en.value = "";
    }
  };
  return h("div", { class: "subgroup-form" },
    h("label", {}, app.t("subgroup.add")),
    spots.length > 1 ? select(spots.map((candidate) => ({ value: candidate, label: texts.spotTitle(candidate) })), spot, (value) => { spot = value; }, { label: app.t("subgroup.spot") }) : null,
    de, en,
    h("button", { type: "button", onClick: add }, "＋ " + app.t("subgroup.create")));
}

export function placementList(app, ref) {
  const { document, context } = app.store.state;
  const parsed = parseRef(ref);
  const found = occurrences(document, ref);
  const groupAt = (occurrence) => document.menu.rooms[occurrence.roomIndex].groups[occurrence.groupIndex];
  const rows = found.map((occurrence) => h("div", { class: "row placement-row" },
    h("span", { class: "grow" }, groupLabel(app, occurrence.room, groupAt(occurrence))),
    iconButton(app.t("placement.remove"), "✕", () => app.edit((doc) => removeEntry(doc, ref, occurrence), { origin: "inspector" }), { class: "danger" })));
  const taken = new Set(found.map((occurrence) => `${occurrence.room}|${occurrence.spot}`));
  const options = groupChoices(app).filter((option) => {
    const target = parseTarget(option.value);
    return !taken.has(`${target.room}|${target.spot}`);
  });
  let chosen = options[0]?.value ?? "";
  const add = options.length === 0 || found.length === 0 ? null : h("div", { class: "row" },
    select(options, chosen, (value) => { chosen = value; }, { label: app.t("placement.addArea") }),
    h("button", { type: "button", onClick: () => app.edit((doc) => addPlacement(doc, context, ref, { ...parseTarget(chosen), index: undefined }), { origin: "inspector" }) }, "＋ " + app.t("placement.add")));
  return h("div", { class: "placement-list" }, h("h4", {}, app.t("placement.title", { count: found.length })), rows.length ? rows : h("span", { class: "hint" }, app.t("placement.none")), add);
}
