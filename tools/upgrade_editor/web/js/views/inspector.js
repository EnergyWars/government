import { h } from "../dom.js";
import { decimal, percent, significant } from "../format.js";
import { factorOf, relativeGain, systemStep } from "../benefit.js";
import { systemCost, systemModel, trackRoomFactor, trackValue } from "../formulas.js";
import { clearRoomOverride, hasRoomOverride, addEntry, addRoomInstance, allowedRooms, isRoomUpgrade, menuRoomOf, moveTopicItem, occurrences, parseRef, refOf, removeAllPlacements, setText, updateUpgrade } from "../model.js";
import { groupChoices, parseTarget, placementList } from "./groupTools.js";
import { renderFillEditor } from "./modelEditor.js";
import { renderChart } from "./chart.js";
import { renderValueTable } from "./valueTable.js";
import { renderCompare } from "./compareView.js";
import { definitionOf, scopeOf } from "../scope.js";
import { buildRows, effectiveTable } from "../table.js";
import { chip, collapsible, formatFactor, formatNumber, iconButton, select } from "./components.js";

const CURVES = ["linear", "decay", "unlock", "unlock_decay", "milestone", "chance"];
const FIELD_RELEVANCE = {
  base: ["linear", "decay", "unlock_decay", "chance"],
  step: ["linear"],
  rate: ["decay", "unlock_decay", "chance"],
};
const NUMBER_FIELDS = [
  { name: "max", integer: true, required: true, min: 1 },
  { name: "cost", required: true, min: 0 },
  { name: "growth", required: true, min: 1, step: 0.001 },
  { name: "price_offset", integer: true, min: 0 },
  { name: "base" },
  { name: "step" },
  { name: "rate", min: 0, max: 1, step: 0.0005 },
  { name: "neutral" },
  { name: "reputation", min: 0 },
];
const SAMPLE_LEVELS = [1, 2, 3, 5, 10, 25, 50, 100, 150, 200, 300];

function inspect(app, patchFor, input, field) {
  const raw = input.value.trim();
  if (raw === "") {
    if (field.required) {
      input.classList.add("invalid");
      return;
    }
    input.classList.remove("invalid");
    app.edit((document) => ({ document: patchFor(document, undefined) }), { origin: "inspector", keepInspector: true });
    return;
  }
  const parsed = Number(raw);
  if (!Number.isFinite(parsed) || (field.min !== undefined && parsed < field.min) || (field.max !== undefined && parsed > field.max)) {
    input.classList.add("invalid");
    return;
  }
  input.classList.remove("invalid");
  const value = field.integer ? Math.round(parsed) : parsed;
  app.edit((document) => ({ document: patchFor(document, value) }), { origin: "inspector", keepInspector: true });
}

function numberField(app, upgradeId, definition, field) {
  const relevant = !FIELD_RELEVANCE[field.name] || FIELD_RELEVANCE[field.name].includes(definition.curve);
  const input = h("input", { type: "number", step: field.step ?? (field.integer ? 1 : "any"), min: field.min, max: field.max, value: definition[field.name] ?? "", "aria-label": app.t("field." + field.name), onInput: (event) => inspect(app, (document, value) => patchOf(app, document, upgradeId, { [field.name]: value }), event.target, field) });
  return h("label", { class: "field" + (relevant ? "" : " dim"), title: app.t("fieldHelp." + field.name) }, h("span", {}, app.t("field." + field.name)), input);
}

function textFields(app, upgradeId) {
  const { texts } = app.derived();
  const titleKey = texts.upgradeTitleKey(upgradeId);
  const descriptionKey = texts.upgradeDescriptionKey(upgradeId);
  const rows = [];
  for (const language of ["de", "en"]) {
    for (const [key, tag] of [[titleKey, "input"], [descriptionKey, "textarea"]]) {
      const label = app.t(key === titleKey ? "field.title" : "field.description") + " (" + language.toUpperCase() + ")";
      const control = h(tag, { value: texts.text(key, language), rows: tag === "textarea" ? 3 : undefined, "aria-label": label, onInput: (event) => app.edit((document) => ({ document: setText(document, key, language, event.target.value, texts.baseText(key, language)) }), { origin: "inspector", keepInspector: true }) });
      if (tag === "textarea") control.value = texts.text(key, language);
      rows.push(h("label", { class: "field wide" }, h("span", {}, label), control));
    }
  }
  return h("div", { class: "field-grid" }, rows);
}

function placementGlobal(app, upgradeId) {
  const { context } = app.store.state;
  const ref = refOf(upgradeId, "");
  const found = occurrences(app.store.state.document, ref);
  const options = groupChoices(app);
  let chosen = options[0]?.value ?? "";
  const picker = found.length > 0 ? null : select(options, chosen, (value) => { chosen = value; }, { label: app.t("inspector.place") });
  const enabled = h("label", { class: "check" }, h("input", { type: "checkbox", checked: found.length > 0, onChange: (event) => {
    app.edit((doc) => (event.target.checked ? addEntry(doc, context, upgradeId, { ...parseTarget(chosen), index: undefined }) : removeAllPlacements(doc, ref)), { origin: "inspector" });
  } }), app.t("inspector.enabled"));
  return h("div", { class: "placement" }, enabled, picker, found.length > 0 ? placementList(app, ref) : h("p", { class: "hint warn" }, app.t("inspector.disabledHint")));
}

function placementRooms(app, upgradeId, definition) {
  const { context } = app.store.state;
  const { texts } = app.derived();
  const chips = definition.rooms.map((roomId) => h("span", { class: "chip removable" }, texts.roomTitle(roomId),
    iconButton(app.t("action.remove"), "✕", () => app.edit((doc) => removeAllPlacements(doc, refOf(upgradeId, roomId)), { origin: "inspector" }), { class: "danger" })));
  const free = allowedRooms(upgradeId, definition, context).filter((roomId) => !definition.rooms.includes(roomId));
  const options = free.map((roomId) => ({ value: roomId, label: texts.roomTitle(roomId) }));
  let chosen = options[0]?.value ?? "";
  const picker = options.length ? h("div", { class: "row" }, select(options, chosen, (value) => { chosen = value; }, { label: app.t("inspector.addRoom") }),
    h("button", { type: "button", onClick: () => app.edit((doc) => addRoomInstance(doc, context, upgradeId, chosen), { origin: "inspector" }) }, app.t("action.add"))) : null;
  const instances = definition.rooms.map((roomId) => h("details", { class: "instance-placements" }, h("summary", {}, texts.roomTitle(roomId)), placementList(app, refOf(upgradeId, roomId))));
  return h("div", { class: "placement" }, h("div", { class: "chips" }, chips.length ? chips : h("span", { class: "hint" }, app.t("inspector.noRooms"))), picker, instances);
}

function requirements(app, upgradeId, definition) {
  const { document } = app.store.state;
  const { texts } = app.derived();
  const requires = definition.requires ?? {};
  const write = (next) => app.edit((doc) => ({ document: updateUpgrade(doc, upgradeId, { requires: Object.keys(next).length ? next : undefined }) }), { origin: "inspector" });
  const rows = Object.entries(requires).map(([id, level]) => h("div", { class: "row" },
    select(Object.keys(document.upgrades).filter((candidate) => candidate !== upgradeId && (candidate === id || !(candidate in requires))).map((candidate) => ({ value: candidate, label: texts.text(texts.upgradeTitleKey(candidate)) })), id, (value) => {
      const next = {};
      for (const [key, current] of Object.entries(requires)) next[key === id ? value : key] = current;
      write(next);
    }, { label: app.t("inspector.requiresUpgrade") }),
    h("input", { type: "number", min: 1, max: document.upgrades[id]?.max ?? 1, value: level, "aria-label": app.t("inspector.requiresLevel"), onChange: (event) => write({ ...requires, [id]: Math.max(1, Math.round(Number(event.target.value) || 1)) }) }),
    iconButton(app.t("action.remove"), "✕", () => { const next = { ...requires }; delete next[id]; write(next); }, { class: "danger" })));
  const candidates = Object.keys(document.upgrades).filter((candidate) => candidate !== upgradeId && !(candidate in requires));
  const add = candidates.length ? h("button", { type: "button", onClick: () => write({ ...requires, [candidates[0]]: 1 }) }, "＋ " + app.t("inspector.addRequirement")) : null;
  return h("div", { class: "requirements" }, rows.length ? rows : h("span", { class: "hint" }, app.t("inspector.noRequirements")), add);
}

function scopePicker(app, upgradeId, baseDefinition) {
  const rooms = baseDefinition.rooms ?? [];
  if (rooms.length === 0) return null;
  const { texts } = app.derived();
  const document = app.store.state.document;
  const scope = scopeOf(app, upgradeId);
  const options = [{ value: "", label: app.t("scope.all") }, ...rooms.map((roomId) => ({ value: roomId, label: texts.roomTitle(roomId) + (hasRoomOverride(document, upgradeId, roomId) ? " •" : "") }))];
  return h("section", { class: "scope-picker" },
    h("label", { class: "field" }, h("span", {}, app.t("scope.label")),
      select(options, scope, (value) => { app.ui.scopes[upgradeId] = value; app.redrawInspector(); }, { label: app.t("scope.label") })),
    h("p", { class: "hint small" }, app.t(scope ? "scope.roomHint" : "scope.allHint")),
    scope && hasRoomOverride(document, upgradeId, scope) ? h("button", { type: "button", onClick: () => app.edit((doc) => clearRoomOverride(doc, upgradeId, scope), { origin: "inspector" }) }, app.t("scope.reset")) : null);
}

function previewLevels(max) {
  const levels = SAMPLE_LEVELS.filter((level) => level < max);
  levels.push(max);
  return levels;
}

function ratioText(app, value) {
  return value === null || value === undefined ? "–" : percent(value, app.i18n.language);
}

function previewTable(app, rows) {
  const language = app.i18n.language;
  return h("table", { class: "preview-table" },
    h("thead", {}, h("tr", {}, ["preview.level", "preview.cost", "preview.sum", "preview.value", "preview.gain", "preview.factor", "preview.stepRatio", "preview.totalRatio"].map((key) => h("th", {}, app.t(key))))),
    h("tbody", {}, rows.map((row) => h("tr", {}, h("td", {}, row.level), h("td", {}, formatNumber(app, row.cost)), h("td", {}, formatNumber(app, row.sum)), h("td", {}, row.value === null ? "–" : significant(row.value, language)), h("td", {}, row.gain === null ? "–" : percent(row.gain * 100, language)), h("td", { class: "num strong" }, formatFactor(app, row.factor)), h("td", { class: "num" }, ratioText(app, row.stepRatio)), h("td", { class: "num" }, ratioText(app, row.totalRatio))))),
  );
}

function trackPreview(app, upgradeId, definition, roomId) {
  const { document, context } = app.store.state;
  const { constants } = app.derived();
  const factor = trackRoomFactor(upgradeId, definition, roomId, context, document, constants);
  const base = trackValue(definition, 0, constants);
  const rows = buildRows(base, effectiveTable(definition, "cost", constants), effectiveTable(definition, "value", constants), factor);
  const totalGain = relativeGain(base, trackValue(definition, definition.max, constants));
  const totalCost = rows.length ? rows[rows.length - 1].sum : 0;
  return { rows, factor, totalCost, totalGain, totalFactor: factorOf(totalGain, totalCost) };
}

function summary(app, preview) {
  const language = app.i18n.language;
  return h("div", { class: "summary" },
    summaryItem(app.t("preview.totalCost"), formatNumber(app, preview.totalCost)),
    summaryItem(app.t("preview.totalGain"), preview.totalGain === null ? "–" : percent(preview.totalGain * 100, language)),
    summaryItem(app.t("preview.totalFactor"), formatFactor(app, preview.totalFactor), true),
    preview.factor !== undefined && preview.factor !== 1 ? summaryItem(app.t("preview.roomFactor"), "×" + decimal(preview.factor, 2, language)) : null,
  );
}

function summaryItem(label, value, strong = false) {
  return h("div", { class: "summary-item" + (strong ? " strong" : "") }, h("span", { class: "label" }, label), h("span", { class: "value" }, value));
}

function buildTrackPreview(app, upgradeId, definition, state) {
  const { texts } = app.derived();
  const scope = scopeOf(app, upgradeId);
  const rooms = scope ? [scope] : isRoomUpgrade(definition) ? (definition.rooms.length ? definition.rooms : allowedRooms(upgradeId, definition, app.store.state.context).slice(0, 1)) : [""];
  if (!rooms.includes(state.room)) state.room = rooms[0];
  const preview = trackPreview(app, upgradeId, definition, state.room);
  const picker = !scope && isRoomUpgrade(definition) ? h("label", { class: "field" }, h("span", {}, app.t("preview.room")),
    select(rooms.map((roomId) => ({ value: roomId, label: texts.roomTitle(roomId) })), state.room, (value) => { state.room = value; state.redraw(); }, { label: app.t("preview.room") })) : null;
  return {
    chart: renderChart(app, preview.rows),
    body: h("div", { class: "preview" }, h("p", { class: "hint" }, app.t("metric.factorHelp")), picker, summary(app, preview)),
    table: renderValueTable(app, upgradeId, definition, preview.factor),
  };
}

function buildSystemPreview(app, entry) {
  const { document, context } = app.store.state;
  const { constants } = app.derived();
  const model = systemModel(entry, context, document, constants);
  if (!model) return { chart: h("div", {}), body: h("p", { class: "hint" }, app.t("inspector.noModel")) };
  const steps = [];
  for (let level = model.minLevel; level < model.maxLevel; level += 1) steps.push(systemStep(entry, model, level, constants));
  const rows = [];
  let running = 0;
  const wanted = new Set(previewLevels(steps.length));
  steps.forEach((step, index) => {
    running += step.cost;
    if (wanted.has(index + 1)) rows.push({ level: step.level, cost: step.cost, sum: running, value: null, gain: step.gain, factor: step.factor });
  });
  const totalCost = running;
  let cumulative = 0;
  const chartRows = steps.map((step) => {
    cumulative += step.cost;
    return { level: step.level, cost: step.cost, sum: cumulative, gain: step.gain ?? undefined, factor: step.factor ?? undefined };
  });
  const first = steps[0];
  const totalFactor = factorOf(first?.gain ?? null, first?.cost ?? 0);
  return {
    chart: renderChart(app, chartRows),
    body: h("div", { class: "preview" }, h("h3", {}, app.t("preview.title")), h("p", { class: "hint" }, app.t("metric.factorHelp")),
      h("div", { class: "summary" }, summaryItem(app.t("preview.totalCost"), formatNumber(app, totalCost)), summaryItem(app.t("preview.firstFactor"), formatFactor(app, totalFactor), true), summaryItem(app.t("preview.baseCost"), formatNumber(app, model.base))),
      previewTable(app, rows)),
  };
}

function modelInfo(app, entry) {
  const { document, context } = app.store.state;
  const { constants, texts } = app.derived();
  const model = systemModel(entry, context, document, constants);
  return h("div", { class: "card model-info" },
    h("p", {}, app.t("inspector.systemInfo")),
    model ? h("dl", {}, h("dt", {}, app.t("preview.baseCost")), h("dd", {}, formatNumber(app, model.base)), h("dt", {}, app.t("field.growth")), h("dd", {}, decimal(model.growth, 3, app.i18n.language)), h("dt", {}, app.t("preview.levels")), h("dd", {}, `${model.minLevel} – ${model.maxLevel}`)) : null,
    h("button", { type: "button", onClick: () => { app.setTab("system"); } }, app.t("inspector.openSystem")),
    h("p", { class: "hint" }, texts.entryTitle(entry)));
}

export function renderInspector(container, app) {
  container.replaceChildren();
  const selection = app.store.state.selection;
  const handle = { refresh() {} };
  if (!selection?.ref) {
    container.append(h("p", { class: "hint" }, app.t("inspector.empty")));
    return handle;
  }
  const { document } = app.store.state;
  const { byId, texts } = app.derived();
  const parsed = parseRef(selection.ref);
  const state = { room: byId.get(selection.ref)?.roomId ?? "", redraw: () => {} };
  if (parsed.kind !== "track") {
    const entry = byId.get(selection.ref);
    if (!entry) {
      container.append(h("p", { class: "hint" }, app.t("inspector.empty")));
      return handle;
    }
    const preview = buildSystemPreview(app, entry);
    container.append(h("div", { class: "chart-top" }, collapsible(app, "chart", app.t("preview.chartTitle"), preview.chart)), h("h2", {}, texts.entryTitle(entry)), modelInfo(app, entry), preview.body);
    handle.refresh = () => renderInspector(container, app);
    return handle;
  }
  const upgradeId = parsed.upgradeId;
  const baseDefinition = document.upgrades[upgradeId];
  if (!baseDefinition) {
    container.append(h("p", { class: "hint" }, app.t("inspector.empty")));
    return handle;
  }
  const scopes = (app.ui.scopes ??= {});
  if (app.ui.scopeRef !== selection.ref) {
    const clicked = byId.get(selection.ref)?.roomId ?? "";
    scopes[upgradeId] = (baseDefinition.rooms ?? []).includes(clicked) ? clicked : "";
    app.ui.scopeRef = selection.ref;
  }
  const definition = definitionOf(app, upgradeId);
  const previewHolder = h("div", {});
  const chartHolder = h("div", {});
  const tableHolder = h("div", {});
  state.redraw = () => {
    const preview = buildTrackPreview(app, upgradeId, definitionOf(app, upgradeId), state);
    chartHolder.replaceChildren(preview.chart);
    previewHolder.replaceChildren(preview.body);
    tableHolder.replaceChildren(preview.table);
  };
  state.redraw();
  const topics = document.menu.topics.map((topic) => ({ value: topic.id, label: texts.topicTitle(topic.id) }));
  container.append(
    h("div", { class: "chart-top" }, collapsible(app, "chart", app.t("preview.chartTitle"), chartHolder)),
    h("div", { class: "inspector-head" }, h("h2", {}, texts.text(texts.upgradeTitleKey(upgradeId))), h("code", {}, upgradeId), chip(texts.topicTitle(definition.topic), "topic")),
    scopePicker(app, upgradeId, baseDefinition),
    collapsible(app, "texts", app.t("inspector.texts"), textFields(app, upgradeId)),
    collapsible(app, "placement", app.t("inspector.placement"), [isRoomUpgrade(definition) ? placementRooms(app, upgradeId, definition) : placementGlobal(app, upgradeId),
      h("label", { class: "field" }, h("span", {}, app.t("field.topic")), select(topics, definition.topic, (value) => app.edit((doc) => moveTopicItem(doc, refOf(upgradeId, ""), value, undefined), { origin: "inspector" }), { label: app.t("field.topic") }))]),
    collapsible(app, "parameters", app.t("inspector.parameters"),
      h("div", { class: "field-grid" },
        NUMBER_FIELDS.slice(0, 4).map((field) => numberField(app, upgradeId, definition, field)),
        h("label", { class: "field", title: app.t("fieldHelp.curve") }, h("span", {}, app.t("field.curve")), select(CURVES.map((curve) => ({ value: curve, label: app.t("curve." + curve) })), definition.curve, (value) => app.edit((doc) => ({ document: patchOf(app, doc, upgradeId, { curve: value }) }), { origin: "inspector" }), { label: app.t("field.curve") })),
        NUMBER_FIELDS.slice(4).map((field) => numberField(app, upgradeId, definition, field)),
        h("label", { class: "field", title: app.t("fieldHelp.unit") }, h("span", {}, app.t("field.unit")), h("input", { type: "text", value: definition.unit ?? "", "aria-label": app.t("field.unit"), onInput: (event) => app.edit((doc) => ({ document: patchOf(app, doc, upgradeId, { unit: event.target.value || undefined }) }), { origin: "inspector", keepInspector: true }) })),
        h("label", { class: "check", title: app.t("fieldHelp.staff_cost") }, h("input", { type: "checkbox", checked: Boolean(definition.staff_cost), onChange: (event) => app.edit((doc) => ({ document: patchOf(app, doc, upgradeId, { staff_cost: event.target.checked ? true : undefined }) }), { origin: "inspector" }) }), app.t("field.staff_cost")),
      )),
    collapsible(app, "models", app.t("inspector.models"), [renderFillEditor(app, upgradeId, "cost"), renderFillEditor(app, upgradeId, "value")]),
    collapsible(app, "requires", app.t("inspector.requires"), requirements(app, upgradeId, definition)),
    collapsible(app, "preview", app.t("preview.title"), previewHolder),
    collapsible(app, "table", app.t("table.title"), tableHolder),
    collapsible(app, "compare", app.t("compare.title"), renderCompare(app, upgradeId)),
  );
  handle.refresh = state.redraw;
  return handle;
}

export { menuRoomOf };
