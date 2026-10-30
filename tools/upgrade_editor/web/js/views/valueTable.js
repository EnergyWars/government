import { h } from "../dom.js";
import { compact } from "../format.js";
import { trackValue } from "../formulas.js";
import { applyTables } from "../model.js";
import { appendLevel, buildRows, changedRows, dropLevel, editRow, effectiveTable, metricValue, visibleColumns } from "../table.js";
import { discardDraft, getDraft } from "../draft.js";
import { scopeOf } from "../scope.js";
import { incrementModeToggle } from "./chart.js";

const display = (value) => Number(value.toPrecision(8));

function numberCell(app, value, label, onCommit, { minimum = null, disabled = false } = {}) {
  return h("input", {
    type: "number",
    step: "any",
    value: value === null || value === undefined ? "" : display(value),
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
    const result = app.edit((document) => applyTables(document, upgradeId, snapshot, constants, scopeOf(app, upgradeId)), { origin: "inspector" });
    if (result.error) draft.dirty = true;
  };

  const draw = () => {
    const draft = getDraft(app, upgradeId, definition);
    const mode = app.ui.incrementMode ?? "absolute";
    const base = trackValue(definition, 0, constants);
    const language = app.i18n.language;
    const applied = { cost: effectiveTable(definition, "cost", constants), value: effectiveTable(definition, "value", constants) };
    const reference = applied.cost[0] ?? 0;
    const rows = buildRows(base, draft.cost, draft.value, 1, reference);
    const touch = (next) => {
      draft.cost = next.cost;
      draft.value = next.value;
      draft.dirty = true;
      draw();
    };
    const hidden = app.ui.chartHidden ?? {};
    const columns = visibleColumns(hidden);
    const changed = changedRows(draft, applied);
    const tip = (column) => app.t(`table.desc.${column}`);
    const head = h("tr", {}, columns.map((column) => h("th", { "data-tip": tip(column), tabindex: "0" }, column === "increment" ? app.t(`table.increment.${mode}`) : app.t(`table.col.${column}`))));
    const baseRow = h("tr", { class: "base-row" }, columns.map((column) => h("td", { class: column === "level" ? "" : "num", "data-tip": column === "level" ? app.t("table.baseRow") : undefined }, column === "level" ? "0" : column === "value" ? compact(base, language) : column === "effect" ? "×1" : "")));
    const body = rows.map((row, index) => h("tr", { class: changed[index] ? "changed" : "" }, columns.map((column) => {
      if (column === "level") return h("td", {}, row.level);
      const value = metricValue(row, column, mode);
      if (value === null) return h("td", { class: "num" }, "–");
      return h("td", {}, numberCell(app, value, `${app.t(`table.col.${column}`)} ${row.level}`, (input) => touch(editRow({ cost: draft.cost, value: draft.value }, index, column, input, { base, reference, mode })), { minimum: column === "cost" ? 0 : null }));
    })));
    root.replaceChildren(...[
      h("div", { class: "table-head" }, incrementModeToggle(app)),
      roomFactor !== 1 ? h("p", { class: "hint small" }, app.t("table.roomNote", { factor: compact(roomFactor, language) })) : null,
      draft.dirty ? h("div", { class: "dirty-banner" },
        h("span", {}, app.t("table.dirty")),
        h("button", { type: "button", class: "primary", onClick: () => apply(draft) }, app.t("table.apply")),
        h("button", { type: "button", onClick: () => { discardDraft(app, upgradeId); app.redrawInspector(); } }, app.t("table.discard"))) : h("p", { class: "hint small" }, app.t("table.clean")),
      h("table", { class: "preview-table values-table" }, h("thead", {}, head), h("tbody", {}, baseRow, body)),
      h("div", { class: "button-row" },
        h("button", { type: "button", onClick: () => { Object.assign(draft, appendLevel(draft), { dirty: true }); draw(); } }, app.t("table.addLevel")),
        h("button", { type: "button", disabled: draft.cost.length <= 1, onClick: () => { Object.assign(draft, dropLevel(draft), { dirty: true }); draw(); } }, app.t("table.removeLevel"))),
    ].filter(Boolean));
  };
  draw();
  return root;
}
