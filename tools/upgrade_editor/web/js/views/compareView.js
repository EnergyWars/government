import { h } from "../dom.js";
import { compact, percent } from "../format.js";
import { GROUPS, compareRows, comparisonItems } from "../compare.js";

const relative = (app, value) => (value === null ? "–" : percent(value, app.i18n.language));

function summaryCells(app, summary) {
  const language = app.i18n.language;
  return [
    h("td", { class: "num" }, summary.levels),
    h("td", { class: "num" }, compact(summary.totalCost, language)),
    h("td", { class: "num" }, percent(summary.gain * 100, language)),
    h("td", { class: "num" }, summary.factor === null ? "–" : compact(summary.factor, language)),
    h("td", { class: "num" }, summary.totalRatio === null ? "–" : percent(summary.totalRatio, language)),
  ];
}

export function renderCompare(app, upgradeId) {
  const root = h("div", { class: "compare" });
  const draw = () => {
    const group = GROUPS.includes(app.ui.compareGroup) ? app.ui.compareGroup : "topic";
    const { document } = app.store.state;
    const { entries, texts, constants } = app.derived();
    const { own, rows } = compareRows(comparisonItems(entries, document, texts), upgradeId, group, constants);
    const strip = h("div", { class: "segments", role: "group", "aria-label": app.t("compare.group") }, GROUPS.map((id) => h("button", { type: "button", class: "segment" + (group === id ? " active" : ""), "aria-pressed": group === id ? "true" : "false", onClick: () => { app.ui.compareGroup = id; draw(); } }, app.t(`compare.group.${id}`))));
    const columns = ["levels", "totalCost", "gain", "factor", "totalRatio", "relCost", "relGain", "relFactor", "relRatio"];
    const head = h("tr", {}, h("th", {}, app.t("compare.col.title")), columns.map((column) => h("th", { "data-tip": app.t(`compare.desc.${column}`), tabindex: "0" }, app.t(`compare.col.${column}`))));
    const body = own?.summary ? [
      h("tr", { class: "own-row" }, h("td", {}, own.title), summaryCells(app, own.summary), [1, 2, 3, 4].map(() => h("td", { class: "num" }, "100 %"))),
      rows.map((row) => h("tr", { class: "link-row", onClick: () => app.store.select({ ref: row.ref }) },
        h("td", {}, row.title), summaryCells(app, row.summary),
        h("td", { class: "num" }, relative(app, row.relative.cost)),
        h("td", { class: "num" }, relative(app, row.relative.gain)),
        h("td", { class: "num" }, relative(app, row.relative.factor)),
        h("td", { class: "num" }, relative(app, row.relative.totalRatio)))),
    ] : [];
    root.replaceChildren(
      h("p", { class: "hint small" }, app.t("compare.hint")),
      strip,
      rows.length === 0 ? h("p", { class: "hint" }, app.t("compare.empty")) : h("table", { class: "preview-table values-table compare-table" }, h("thead", {}, head), h("tbody", {}, body)));
  };
  draw();
  return root;
}
