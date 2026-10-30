import { h } from "../dom.js";
import { compact, percent } from "../format.js";
import { trackValue } from "../formulas.js";
import { applyTables } from "../model.js";
import { buildRows, clean, incrementCell, withCost, withIncrement, withValue } from "../table.js";
import { discardDraft, getDraft } from "../draft.js";
import { incrementModeToggle } from "./chart.js";

const COLUMNS = ["level", "cost", "sum", "increment", "value", "gain", "factor", "stepRatio", "totalRatio"];

function numberCell(app, value, label, onCommit, { minimum = null, disabled = false } = {}) {
  return h("input", {
    type: "number",
    step: "any",
    value: value === null || value === undefined ? "" : clean(value),
    disabled,
    "aria-label": label,
    onChange: (event) => {
      const parsed = Number(event.target.value);
      if (event.target.value.trim() === "" || !Number.isFinite(parsed) || (minimum !== null && parsed < minimum)) {
        event.target.classList.add("invalid");
        return;
      }
      event.target.classList.remove("invalid");
      onCommit(parsed);
    },
  });
}

export function renderValueTable(app, upgradeId, definition, roomFactor) {
  const { constants } = app.derived();
  const root = h("div", { class: "value-table" });

  const apply = (draft) => {
    const snapshot = { cost: [...draft.cost], value: [...draft.value], formula: { ...draft.formula } };
    draft.dirty = false;
    const result = app.edit((document) => applyTables(document, upgradeId, snapshot, constants), { origin: "inspector" });
    if (result.error) draft.dirty = true;
  };

  const draw = () => {
    const draft = getDraft(app, upgradeId, definition);
    const mode = app.ui.incrementMode ?? "absolute";
    const base = trackValue(definition, 0, constants);
    const language = app.i18n.language;
    const rows = buildRows(base, draft.cost, draft.value);
    const touch = (kind, values) => {
      draft[kind] = values;
      draft.dirty = true;
      draw();
    };
    const head = h("tr", {}, COLUMNS.map((column) => h("th", { class: ["cost", "increment", "value"].includes(column) ? "editable" : "" }, column === "increment" ? app.t(`table.increment.${mode}`) : app.t(`table.col.${column}`))));
    const baseRow = h("tr", { class: "base-row" }, h("td", {}, "0"), h("td", { colSpan: 3 }, app.t("table.baseRow")), h("td", {}, compact(base, language)), h("td", { colSpan: 4 }));
    const body = rows.map((row, index) => {
      const previousValue = index === 0 ? base : rows[index - 1].value;
      return h("tr", {},
        h("td", {}, row.level),
        h("td", {}, numberCell(app, draft.cost[index], app.t("table.cellCost", { level: row.level }), (value) => touch("cost", withCost(draft.cost, index, value)), { minimum: 0 })),
        h("td", { class: "num" }, compact(row.sum, language)),
        h("td", {}, numberCell(app, incrementCell(row, mode), app.t("table.cellIncrement", { level: row.level }), (value) => touch("value", withIncrement(draft.value, index, value, mode, base)), { disabled: mode === "factor" && previousValue === 0 })),
        h("td", {}, numberCell(app, row.value, app.t("table.cellValue", { level: row.level }), (value) => touch("value", withValue(draft.value, index, value, base)))),
        h("td", { class: "num" }, percent(row.gain * 100, language)),
        h("td", { class: "num" }, row.factor === null ? "–" : compact(row.factor, language)),
        h("td", { class: "num" }, row.stepRatio === null ? "–" : percent(row.stepRatio, language)),
        h("td", { class: "num" }, row.totalRatio === null ? "–" : percent(row.totalRatio, language)));
    });
    root.replaceChildren(
      h("div", { class: "table-head" }, incrementModeToggle(app)),
      roomFactor !== 1 ? h("p", { class: "hint small" }, app.t("table.roomNote", { factor: compact(roomFactor, language) })) : null,
      draft.dirty ? h("div", { class: "dirty-banner" },
        h("span", {}, app.t("table.dirty")),
        h("button", { type: "button", class: "primary", onClick: () => apply(draft) }, app.t("table.apply")),
        h("button", { type: "button", onClick: () => { discardDraft(app, upgradeId); app.redrawInspector(); } }, app.t("table.discard"))) : h("p", { class: "hint small" }, app.t("table.clean")),
      h("table", { class: "preview-table values-table" }, h("thead", {}, head), h("tbody", {}, baseRow, body)));
  };
  draw();
  return root;
}
