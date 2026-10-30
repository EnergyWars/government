import { h } from "../dom.js";
import { setSystemValue } from "../model.js";

const DEPARTMENT_FIELDS = ["unlock_cost", "unlock_reputation", "cost_multiplier", "staff_multiplier"];
const KIND_FIELDS = ["desk_cost", "hire_cost"];

function numberInput(app, label, value, original, onValue) {
  const input = h("input", { type: "number", step: "any", min: 0, value, "aria-label": label, onInput: (event) => {
    const parsed = Number(event.target.value);
    if (event.target.value.trim() === "" || !Number.isFinite(parsed) || parsed < 0) {
      event.target.classList.add("invalid");
      return;
    }
    event.target.classList.remove("invalid");
    onValue(parsed);
  } });
  const changed = original !== undefined && original !== value;
  return h("span", { class: "system-input" + (changed ? " changed" : "") }, input, changed ? h("span", { class: "original", title: app.t("system.original") }, "↺ " + original) : null);
}

function commit(app, section, id, field, value) {
  app.edit((document) => ({ document: setSystemValue(document, section, id, field, value) }), { origin: "system", keepTab: true });
}

export function renderSystemTab(container, app) {
  const { document, original } = app.store.state;
  const { texts } = app.derived();
  const system = document.system ?? {};
  const base = original.system ?? {};
  const constants = Object.keys(system.constants ?? {});
  const constantRows = constants.map((name) => h("tr", {}, h("td", {}, h("code", {}, name)), h("td", {}, app.i18n.has("const." + name) ? app.t("const." + name) : ""),
    h("td", {}, numberInput(app, name, system.constants[name], base.constants?.[name], (value) => commit(app, "constants", name, "", value)))));
  const kindRows = Object.entries(system.station_kinds ?? {}).map(([kind, fields]) => h("tr", {}, h("td", {}, h("code", {}, kind)),
    KIND_FIELDS.map((field) => h("td", {}, numberInput(app, `${kind} ${field}`, fields[field], base.station_kinds?.[kind]?.[field], (value) => commit(app, "station_kinds", kind, field, value))))));
  const departmentRows = Object.entries(system.departments ?? {}).map(([id, fields]) => h("tr", {}, h("td", {}, texts.roomTitle(id)),
    DEPARTMENT_FIELDS.map((field) => h("td", {}, numberInput(app, `${id} ${field}`, fields[field], base.departments?.[id]?.[field], (value) => commit(app, "departments", id, field, value))))));
  container.append(h("div", { class: "system", dataset: { scroll: "system" } },
    h("h2", {}, app.t("system.title")), h("p", { class: "hint" }, app.t("system.hint")),
    h("section", {}, h("h3", {}, app.t("system.constants")), h("table", { class: "data-table" }, h("thead", {}, h("tr", {}, h("th", {}, app.t("system.col.name")), h("th", {}, app.t("system.col.meaning")), h("th", {}, app.t("system.col.value")))), h("tbody", {}, constantRows))),
    h("section", {}, h("h3", {}, app.t("system.stationKinds")), h("table", { class: "data-table" }, h("thead", {}, h("tr", {}, h("th", {}, app.t("system.col.name")), KIND_FIELDS.map((field) => h("th", {}, app.t("system.field." + field))))), h("tbody", {}, kindRows))),
    h("section", {}, h("h3", {}, app.t("system.departments")), h("table", { class: "data-table" }, h("thead", {}, h("tr", {}, h("th", {}, app.t("system.col.name")), DEPARTMENT_FIELDS.map((field) => h("th", {}, app.t("system.field." + field))))), h("tbody", {}, departmentRows))),
  ));
}
