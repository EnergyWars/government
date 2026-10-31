import { h } from "../dom.js";
import { api } from "../api.js";
import { significant } from "../format.js";

export function describeChange(app, change) {
  const { texts } = app.derived();
  const language = app.i18n.language;
  const show = (value) => {
    if (value === null || value === undefined) return "–";
    if (typeof value === "number") return significant(value, language);
    if (typeof value === "object" && value.mode === "formula") return app.t("model.mode.formula") + ": " + value.formula;
    if (typeof value === "object" && value.mode === "table") return app.t("model.mode.table");
    if (typeof value === "object") return JSON.stringify(value);
    return String(value);
  };
  const upgrade = (id) => texts.text(texts.upgradeTitleKey(id));
  const place = (location) => (location ? `${texts.roomTitle(location.room)} · ${texts.spotTitle(location.spot)}` : "–");
  const groupName = (title) => (title ? title[language] ?? title.en ?? "" : "");
  switch (change.kind) {
    case "param":
      return app.t("change.param", { name: upgrade(change.id), field: app.t("field." + change.field), before: show(change.before), after: show(change.after) });
    case "room_override":
      return app.t("change.roomOverride." + change.state, { name: upgrade(change.id), room: texts.roomTitle(change.room) });
    case "enabled":
      return app.t(change.after === false ? "change.disabled" : "change.enabled", { name: upgrade(change.id) });
    case "removed_upgrade":
      return app.t("change.removed", { name: change.id });
    case "placement":
      return app.t("change.placement", { name: change.ref, before: place(change.before), after: place(change.after) });
    case "placements":
      return app.t("change.placements", { name: change.ref, added: change.added.map(place).join(", ") || "–", removed: change.removed.map(place).join(", ") || "–" });
    case "group":
      return app.t("change.group", { room: texts.roomTitle(change.room), name: groupName(change.after) || groupName(change.before) || change.key, before: groupName(change.before) || "–", after: groupName(change.after) || "–" });
    case "room_order":
      return app.t("change.roomOrder");
    case "group_order":
      return app.t("change.groupOrder", { room: texts.roomTitle(change.room) });
    case "entry_order":
      return app.t("change.entryOrder", { room: texts.roomTitle(change.room), spot: texts.spotTitle(change.spot) });
    case "topic":
      return app.t("change.topic", { name: change.ref, before: change.before ? texts.topicTitle(change.before) : "–", after: change.after ? texts.topicTitle(change.after) : "–" });
    case "topic_order":
      return app.t("change.topicOrder");
    case "system":
      return app.t("change.system", { name: [change.id, change.field].filter(Boolean).join("."), before: show(change.before), after: show(change.after) });
    case "area_added":
      return app.t("change.areaAdded", { name: texts.spotTitle("area:" + change.id) });
    case "area_removed":
      return app.t("change.areaRemoved", { name: change.id });
    case "area_changed":
      return app.t("change.areaChanged", { name: texts.spotTitle("area:" + change.id) });
    case "spot_rects":
      return app.t(!change.after ? "change.spotRectsReset" : change.after.length === 0 ? "change.spotRemoved" : "change.spotRects", { name: texts.spotTitle(change.spot) });
    case "text":
      return app.t("change.text", { key: change.key, language: change.language.toUpperCase(), before: show(change.before), after: show(change.after) });
    default:
      return JSON.stringify(change);
  }
}

export function renderChangesTab(container, app) {
  const list = h("ul", { class: "changes" }, h("li", { class: "hint" }, app.t("changes.loading")));
  const title = h("h2", {}, app.t("changes.title"));
  container.append(h("div", { class: "changes-view", dataset: { scroll: "changes" } }, title, h("p", { class: "hint" }, app.t("changes.hint")), list));
  const token = (app.ui.changesToken = (app.ui.changesToken ?? 0) + 1);
  api.diff(app.store.state.document).then(({ changes }) => {
    if (token !== app.ui.changesToken) return;
    title.textContent = app.t("changes.titleCount", { count: changes.length });
    list.replaceChildren(...(changes.length ? changes.map((change) => h("li", { class: "change " + change.kind }, describeChange(app, change))) : [h("li", { class: "hint" }, app.t("changes.none"))]));
  }).catch((error) => {
    if (token === app.ui.changesToken) list.replaceChildren(h("li", { class: "hint warn" }, app.t("error.validation", { count: error.errors?.length ?? 0 })));
  });
}
