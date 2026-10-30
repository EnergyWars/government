import { h } from "../dom.js";
import { COST_VARIABLES, VALUE_VARIABLES, checkFormula } from "../formulas.js";
import { FUNCTIONS } from "../formula.js";
import { deleteFormulaFromHistory, fillValues, formulaHistory, rememberFormula, tableFromFormula, tableFromParameters } from "../model.js";
import { fillDraft, getDraft } from "../draft.js";
import { select } from "./components.js";

const TABS = ["params", "formula", "tools"];

function statusText(app, result) {
  if (result.ok) return app.t("formula.ok");
  const detail = result.level === undefined ? "" : " " + app.t("formula.atLevel", { level: result.level });
  return app.t("formula.err." + result.code) + detail;
}

function paramsPane(app, upgradeId, kind, definition, draft) {
  const { constants } = app.derived();
  return h("div", { class: "fill-pane" },
    h("p", { class: "hint small" }, app.t(`fill.params.hint.${kind}`)),
    h("button", { type: "button", onClick: () => {
      fillDraft(draft, kind, tableFromParameters(definition, kind, constants), undefined);
      app.redrawInspector();
    } }, app.t("fill.params.apply")));
}

function formulaPane(app, upgradeId, kind, definition, draft) {
  const history = formulaHistory(definition, kind);
  const draftKey = `${upgradeId}:${kind}`;
  const drafts = (app.ui.formulaDrafts ??= {});
  const input = h("input", { type: "text", class: "formula-input", spellcheck: false, value: drafts[draftKey] ?? draft.formula?.[kind] ?? "", "aria-label": app.t("model.formula") });
  input.addEventListener("input", () => { drafts[draftKey] = input.value; });
  const status = h("div", { class: "formula-status" });
  const show = () => {
    const result = checkFormula(kind, app.store.state.document.upgrades[upgradeId], input.value);
    status.textContent = statusText(app, result);
    status.className = "formula-status " + (result.ok ? "ok" : "bad");
    return result;
  };
  input.addEventListener("input", show);
  show();
  const fill = (text) => {
    if (!show().ok) return;
    const filled = tableFromFormula(app.store.state.document.upgrades[upgradeId], kind, text.trim());
    if (filled.error) return;
    drafts[draftKey] = text.trim();
    fillDraft(draft, kind, filled.values, text.trim());
    app.edit((document) => rememberFormula(document, upgradeId, kind, text), { origin: "inspector" });
  };
  const names = kind === "cost" ? COST_VARIABLES : VALUE_VARIABLES;
  const insert = (name) => {
    const start = input.selectionStart ?? input.value.length;
    input.setRangeText(name, start, input.selectionEnd ?? start, "end");
    input.dispatchEvent(new Event("input"));
    input.focus();
  };
  const picker = history.length === 0 ? null : h("div", { class: "formula-history" },
    h("label", { class: "field" }, h("span", {}, app.t("model.history")),
      select([{ value: "", label: app.t("model.history.choose") }, ...history.map((entry) => ({ value: entry, label: entry }))], history.includes(input.value) ? input.value : "", (value) => {
        if (value === "") return;
        input.value = value;
        drafts[draftKey] = value;
        show();
      }, { label: app.t("model.history") })),
    h("button", { type: "button", onClick: () => {
      if (history.includes(input.value)) app.edit((document) => deleteFormulaFromHistory(document, upgradeId, kind, input.value), { origin: "inspector" });
    } }, app.t("model.history.delete")));
  const remembered = draft.formula?.[kind];
  return h("div", { class: "fill-pane formula-tool" },
    input,
    status,
    h("div", { class: "chips" }, h("span", { class: "label" }, app.t("model.variables")), names.map((name) => h("button", { type: "button", class: "chip action", title: app.t("model.var." + name), onClick: () => insert(name) }, name))),
    h("div", { class: "hint small" }, app.t("model.functions") + " " + Object.entries(FUNCTIONS).map(([name, arity]) => `${name}/${arity}`).join(", ") + " · pi, e · + − * / % ^ < <= > >= == !="),
    h("div", { class: "hint small" }, app.t("model.formulaNote." + kind)),
    h("div", { class: "hint small" }, app.t("fill.formula.hint")),
    h("div", { class: "button-row" },
      h("button", { type: "button", onClick: () => fill(input.value) }, app.t("fill.formula.apply")),
      h("button", { type: "button", disabled: !remembered, title: remembered ?? "", onClick: () => fill(remembered) }, app.t("model.formula.reset"))),
    picker);
}

function numberInput(label, onCommit, value) {
  return h("input", { type: "number", step: "any", value, "aria-label": label, onChange: (event) => {
    const parsed = Number(event.target.value);
    if (event.target.value.trim() === "" || !Number.isFinite(parsed)) {
      event.target.classList.add("invalid");
      return;
    }
    event.target.classList.remove("invalid");
    onCommit(parsed);
  } });
}

function toolsPane(app, upgradeId, kind, definition, draft) {
  const state = { value: 0, index: 1, factor: 1 };
  const apply = (spec) => {
    draft[kind] = fillValues(draft[kind], spec);
    draft.dirty = true;
    app.redrawInspector();
  };
  return h("div", { class: "fill-pane table-tools" },
    h("label", { class: "field" }, h("span", {}, app.t("model.fill.level")), h("input", { type: "number", min: 1, max: definition.max, value: state.index, onInput: (event) => { state.index = Math.max(1, Math.round(Number(event.target.value) || 1)); } })),
    h("label", { class: "field" }, h("span", {}, app.t(kind === "cost" ? "model.table.cost" : "model.table.increment")), numberInput(app.t("model.fill.value"), (value) => { state.value = value; }, state.value)),
    h("button", { type: "button", onClick: () => apply({ type: "same", value: state.value }) }, app.t("model.fill.same")),
    h("button", { type: "button", onClick: () => apply({ type: "from", index: state.index - 1, value: state.value }) }, app.t("model.fill.from")),
    h("label", { class: "field" }, h("span", {}, app.t("model.fill.factor")), numberInput(app.t("model.fill.factor"), (value) => { state.factor = value; }, state.factor)),
    h("button", { type: "button", onClick: () => apply({ type: "scale", index: state.index - 1, factor: state.factor }) }, app.t("model.fill.scale")));
}

const PANES = { params: paramsPane, formula: formulaPane, tools: toolsPane };

export function renderFillEditor(app, upgradeId, kind) {
  const definition = app.store.state.document.upgrades[upgradeId];
  const draft = getDraft(app, upgradeId, definition);
  const tabs = (app.ui.fillTab ??= {});
  const active = TABS.includes(tabs[kind]) ? tabs[kind] : "params";
  const strip = h("div", { class: "segments", role: "tablist" }, TABS.map((id) => h("button", { type: "button", role: "tab", class: "segment" + (active === id ? " active" : ""), "aria-selected": active === id ? "true" : "false", onClick: () => { tabs[kind] = id; app.redrawInspector(); } }, app.t("fill.tab." + id))));
  return h("div", { class: "model-editor" }, h("h4", {}, app.t(`fill.title.${kind}`)), strip, PANES[active](app, upgradeId, kind, definition, draft));
}
