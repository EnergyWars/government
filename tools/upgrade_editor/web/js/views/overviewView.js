import { h } from "../dom.js";
import { percent } from "../format.js";
import { formatFactor, formatNumber } from "./components.js";

const COLUMNS = [
  { key: "title", numeric: false },
  { key: "topic", numeric: false },
  { key: "levels", numeric: true },
  { key: "firstCost", numeric: true },
  { key: "totalCost", numeric: true },
  { key: "firstGain", numeric: true },
  { key: "firstFactor", numeric: true },
  { key: "totalFactor", numeric: true },
];

export function overviewRows(app) {
  const { entries, texts } = app.derived();
  const unique = [...new Map(entries.map((entry) => [entry.id, entry])).values()];
  return unique.map((entry) => {
    const metrics = app.metrics(entry);
    return {
      entry,
      title: texts.entryTitle(entry),
      topic: texts.topicTitle(entry.topic),
      levels: metrics?.max ?? null,
      firstCost: metrics?.first?.cost ?? null,
      totalCost: metrics?.totals.cost ?? null,
      firstGain: metrics?.first?.gain ?? null,
      firstFactor: metrics?.first?.factor ?? null,
      totalFactor: metrics?.totals.factor ?? null,
    };
  });
}

export function sortRows(rows, key, direction, language) {
  const numeric = COLUMNS.find((column) => column.key === key)?.numeric;
  return [...rows].sort((a, b) => {
    const left = a[key];
    const right = b[key];
    if (left === null && right === null) return 0;
    if (left === null) return 1;
    if (right === null) return -1;
    return (numeric ? left - right : String(left).localeCompare(String(right), language)) * direction;
  });
}

export function renderOverviewTab(container, app) {
  const view = (app.ui.overview ??= { key: "totalFactor", direction: -1, filter: "" });
  const rows = overviewRows(app);
  const body = h("tbody", {});
  const draw = () => {
    const needle = view.filter.trim().toLowerCase();
    const shown = sortRows(rows.filter((row) => !needle || row.title.toLowerCase().includes(needle) || row.topic.toLowerCase().includes(needle)), view.key, view.direction, app.i18n.language);
    body.replaceChildren(...shown.map((row) => h("tr", { class: app.store.state.selection?.ref === row.entry.id ? "selected" : "", onClick: () => app.store.select({ ref: row.entry.id }) },
      h("td", {}, row.title), h("td", {}, row.topic), h("td", { class: "num" }, row.levels ?? "–"), h("td", { class: "num" }, row.firstCost === null ? "–" : formatNumber(app, row.firstCost)),
      h("td", { class: "num" }, row.totalCost === null ? "–" : formatNumber(app, row.totalCost)), h("td", { class: "num" }, row.firstGain === null ? "–" : percent(row.firstGain * 100, app.i18n.language)),
      h("td", { class: "num strong" }, formatFactor(app, row.firstFactor)), h("td", { class: "num strong" }, formatFactor(app, row.totalFactor)))));
  };
  const head = h("tr", {}, COLUMNS.map((column) => h("th", { class: "sortable" + (view.key === column.key ? " active" : ""), onClick: () => { view.direction = view.key === column.key ? -view.direction : column.numeric ? -1 : 1; view.key = column.key; app.rerender(); } },
    app.t("overview.col." + column.key), view.key === column.key ? (view.direction > 0 ? " ▲" : " ▼") : "")));
  const filter = h("input", { type: "search", value: view.filter, placeholder: app.t("overview.filter"), "aria-label": app.t("overview.filter"), onInput: (event) => { view.filter = event.target.value; draw(); } });
  draw();
  container.append(h("div", { class: "overview" }, h("div", { class: "overview-head" }, h("h2", {}, app.t("overview.title")), filter), h("p", { class: "hint" }, app.t("metric.factorHelp")), h("div", { class: "table-wrap", dataset: { scroll: "overview" } }, h("table", { class: "data-table" }, h("thead", {}, head), body))));
}
