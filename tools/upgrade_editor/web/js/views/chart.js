import { h, svg } from "../dom.js";
import { CHART, nearestIndex, polylinePoints, scaleSeries, xOf } from "../chartMath.js";
import { percent, significant } from "../format.js";
import { incrementCell } from "../table.js";

const SERIES = [
  { key: "cost", className: "line-cost", legend: "preview.legendCost", get: (row) => row.cost },
  { key: "sum", className: "line-sum", legend: "preview.legendSum", get: (row) => row.sum },
  { key: "value", className: "line-value", legend: "preview.legendValue", get: (row) => row.value },
  { key: "increment", className: "line-increment", legend: "preview.legendIncrement", get: (row, mode) => incrementCell(row, mode) },
  { key: "factor", className: "line-factor", legend: "preview.legendFactor", get: (row) => row.factor },
  { key: "stepRatio", className: "line-step", legend: "preview.legendStepRatio", get: (row) => row.stepRatio },
  { key: "totalRatio", className: "line-total", legend: "preview.legendTotalRatio", get: (row) => row.totalRatio },
];

const TOOLTIP = [
  { label: "preview.cost", get: (row) => row.cost },
  { label: "preview.sum", get: (row) => row.sum },
  { label: "table.value", get: (row) => row.value },
  { label: "table.incrementAbsolute", get: (row) => row.increment },
  { label: "table.incrementFactor", get: (row) => row.incrementFactor },
  { label: "preview.gain", get: (row) => row.gain, percent: 100 },
  { label: "preview.factor", get: (row) => row.factor },
  { label: "preview.stepRatio", get: (row) => row.stepRatio, percent: 1 },
  { label: "preview.totalRatio", get: (row) => row.totalRatio, percent: 1 },
];

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

function formatted(app, entry, row) {
  const value = entry.get(row);
  if (typeof value !== "number" || !Number.isFinite(value)) return null;
  const language = app.i18n.language;
  return entry.percent ? percent(value * entry.percent, language) : significant(value, language);
}

export function renderChart(app, rows) {
  const figure = h("figure", { class: "chart" });
  if (rows.filter((row) => row.cost > 0).length < 2) return h("div", {});
  const hidden = (app.ui.chartHidden ??= {});

  const draw = () => {
    const mode = app.ui.incrementMode ?? "absolute";
    const available = SERIES.map((series) => ({ series, points: scaleSeries(rows.map((row) => series.get(row, mode))) })).filter((item) => item.points);
    const visible = available.filter((item) => !hidden[item.series.key]);
    const guide = svg("line", { class: "chart-guide", y1: 0, y2: CHART.height, x1: 0, x2: 0, visibility: "hidden" });
    const dots = visible.map((item) => svg("circle", { class: "chart-dot " + item.series.className, r: 3.5, cx: 0, cy: 0, visibility: "hidden" }));
    const tooltip = h("div", { class: "chart-tooltip", hidden: true });
    const overlay = svg("rect", { x: 0, y: 0, width: CHART.width, height: CHART.height, fill: "transparent" });
    const canvas = svg("svg", { viewBox: `0 0 ${CHART.width} ${CHART.height}`, role: "img", "aria-label": app.t("preview.chart") },
      visible.map((item) => svg("polyline", { points: polylinePoints(item.points), class: item.series.className, fill: "none" })),
      guide, dots, overlay);
    const hide = () => {
      tooltip.hidden = true;
      guide.setAttribute("visibility", "hidden");
      dots.forEach((dot) => dot.setAttribute("visibility", "hidden"));
    };
    const show = (event) => {
      const box = canvas.getBoundingClientRect();
      if (box.width === 0) return;
      const index = nearestIndex(((event.clientX - box.left) / box.width) * CHART.width, CHART.width, rows.length);
      const column = xOf(index, rows.length);
      guide.setAttribute("x1", column);
      guide.setAttribute("x2", column);
      guide.setAttribute("visibility", "visible");
      visible.forEach((item, position) => {
        const point = item.points[index];
        dots[position].setAttribute("visibility", point ? "visible" : "hidden");
        if (point) {
          dots[position].setAttribute("cx", point.x);
          dots[position].setAttribute("cy", point.y);
        }
      });
      const row = rows[index];
      tooltip.replaceChildren(
        h("strong", {}, `${app.t("preview.level")} ${row.level}`),
        h("dl", {}, TOOLTIP.flatMap((entry) => {
          const text = formatted(app, entry, row);
          return text === null ? [] : [h("dt", {}, app.t(entry.label)), h("dd", {}, text)];
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
      onClick: () => { hidden[item.series.key] = !hidden[item.series.key]; draw(); },
    }, app.t(item.series.legend))));
    figure.replaceChildren(h("div", { class: "chart-frame" }, canvas, tooltip), legend, incrementModeToggle(app), h("p", { class: "hint small" }, app.t("preview.chartNote")));
  };
  draw();
  return figure;
}
