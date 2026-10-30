import { effectiveTable } from "./table.js";

export function getDraft(app, upgradeId, definition) {
  const drafts = (app.ui.tableDrafts ??= {});
  const current = drafts[upgradeId];
  if (current?.dirty && current.cost.length === definition.max && current.value.length === definition.max) return current;
  const { constants } = app.derived();
  drafts[upgradeId] = {
    cost: effectiveTable(definition, "cost", constants),
    value: effectiveTable(definition, "value", constants),
    formula: { cost: definition.cost_model?.formula, value: definition.value_model?.formula },
    dirty: false,
  };
  return drafts[upgradeId];
}

export function discardDraft(app, upgradeId) {
  delete (app.ui.tableDrafts ??= {})[upgradeId];
}

export function fillDraft(draft, kind, values, formula) {
  draft[kind] = values;
  draft.formula = { ...draft.formula, [kind]: formula };
  draft.dirty = true;
}
