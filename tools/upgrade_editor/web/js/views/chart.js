import { h, svg } from "../dom.js";
import { CHART, highlightState, nearestIndex, polylinePoints, scaleSeries, xOf } from "../chartMath.js";
import { percent, significant } from "../format.js";
import { COLUMNS, metricValue } from "../table.js";

const PERCENT = { gain: 1, stepRatio: 1, totalRatio: 1 };
const PREFIX = { costFactor: "×", sumFactor: "×", effect: "×" };
const CLASSES = { stepRatio: "line-step", totalRatio: "line-total" };

const SERIES = COLUMNS.filter((column) => column !== "level").map((key) => ({
  key,
  className: CLASSES[key] ?? `line-${key}`,
  get: (row, mode) => metricValue(row, key, mode),
  percent: PERCENT[key],
  prefix: PREFIX[key] ?? "",
}));

export function setIncrementMode(app, mode) {
  app.ui.incrementMode = mode;
  app.redrawInspector();
}

export function incrementModeToggle(app) {
  const mode = app.ui.incrementMode ?? "absolute";
  return h("div", { class: "mode-toggle", role: "group", "aria-label": app.t("table.incrementMode") },
    h("span", { class: "label" }, app.t("table.incrementMode")),
    ["absolute", "factor"].map((id) => h("button", { type: "button", class: "segment" + (mode === id ? " active" : ""), "aria-pressed": mode === id ? "true" : "false", onClick: () => { if (mode !== id) setIncrementMode(app, id); } }, app.t("table.mode." + id))));
}

function formatValue(app, entry, value) {
  if (typeof value !== "number" || !Number.isFinite(value)) return null;
  const language = app.i18n.language;
  return entry.percent ? percent(value, language) : entry.prefix + significant(value, language);
}

export function renderChart(app, rows) {
  const figure = h("figure", { class: "chart" });
  if (rows.filter((row) => row.cost > 0).length < 2) return h("div", {});
  const hidden = (app.ui.chartHidden ??= {});

  const draw = () => {
    const label = (series) => (series.key === "increment" ? app.t(`table.increment.${app.ui.incrementMode ?? "absolute"}`) : app.t(`table.col.${series.key}`));
    const mode = app.ui.incrementMode ?? "absolute";
    const available = SERIES.map((series) => { const values = rows.map((row) => series.get(row, mode)); return { series, values, points: scaleSeries(values) }; }).filter((item) => item.points);
    const visible = available.filter((item) => !hidden[item.series.key]);
    const guide = svg("line", { class: "chart-guide", y1: 0, y2: CHART.height, x1: 0, x2: 0, visibility: "hidden" });
    const marks = visible.flatMap((item) => item.points.flatMap((point, index) => (point ? [svg("circle", { class: "chart-point " + item.series.className, "data-key": item.series.key, "data-index": index, cx: point.x, cy: point.y, r: 3.5 })] : [])));
    const tooltip = h("div", { class: "chart-tooltip", hidden: true });
    const overlay = svg("rect", { x: 0, y: 0, width: CHART.width, height: CHART.height, fill: "transparent" });
    const canvas = svg("svg", { viewBox: `0 0 ${CHART.width} ${CHART.height}`, role: "img", "aria-label": app.t("preview.chart") },
      visible.map((item) => svg("polyline", { points: polylinePoints(item.points), class: item.series.className, "data-key": item.series.key, fill: "none" })),
      guide, marks, overlay);
    const focus = (key) => {
      for (const node of canvas.querySelectorAll("[data-key]")) {
        const state = highlightState(key, node.getAttribute("data-key"));
        node.classList.toggle("focus", state === "focus");
        node.classList.toggle("dim", state === "dim");
      }
    };
    const hide = () => {
      tooltip.hidden = true;
      guide.setAttribute("visibility", "hidden");
      marks.forEach((mark) => mark.classList.remove("active"));
    };
    const show = (event) => {
      const box = canvas.getBoundingClientRect();
      if (box.width === 0) return;
      const index = nearestIndex(((event.clientX - box.left) / box.width) * CHART.width, CHART.width, rows.length);
      const column = xOf(index, rows.length);
      guide.setAttribute("x1", column);
      guide.setAttribute("x2", column);
      guide.setAttribute("visibility", "visible");
      marks.forEach((mark) => mark.classList.toggle("active", Number(mark.getAttribute("data-index")) === index));
      const row = rows[index];
      tooltip.replaceChildren(
        h("strong", {}, `${app.t("preview.level")} ${row.level}`),
        h("dl", {}, visible.flatMap((item) => {
          const text = formatValue(app, item.series, item.series.get(row, mode));
          return text === null ? [] : [h("dt", {}, label(item.series)), h("dd", {}, text)];
        })));
      tooltip.style.left = `${Math.max(18, Math.min(82, (column / CHART.width) * 100))}%`;
      tooltip.hidden = false;
    };
    overlay.addEventListener("pointermove", show);
    overlay.addEventListener("pointerleave", hide);
    const legend = h("div", { class: "chart-legend" }, available.map((item) => h("button", {
      type: "button",
      class: "legend-toggle " + item.series.className + (hidden[item.series.key] ? " off" : ""),
      "aria-pressed": hidden[item.series.key] ? "false" : "true",
      title: app.t(hidden[item.series.key] ? "chart.show" : "chart.hide"),
      onClick: () => { hidden[item.series.key] = !hidden[item.series.key]; app.redrawInspector(); },
      onPointerenter: () => focus(item.series.key),
      onPointerleave: () => focus(null),
      onFocus: () => focus(item.series.key),
      onBlur: () => focus(null),
    }, `${label(item.series)} · ${app.t("chart.peak")} ${formatValue(app, item.series, Math.max(...item.values.filter((value) => Number.isFinite(value))))}`)));
    figure.replaceChildren(h("div", { class: "chart-frame" }, canvas, tooltip), legend, incrementModeToggle(app), h("p", { class: "hint small" }, app.t("preview.chartNote")));
  };
  draw();
  return figure;
}
