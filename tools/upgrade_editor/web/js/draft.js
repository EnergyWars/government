import { scopeOf } from "./scope.js";
import { effectiveTable } from "./table.js";

const keyOf = (app, upgradeId) => `${upgradeId}@${scopeOf(app, upgradeId)}`;

export function getDraft(app, upgradeId, definition) {
  const drafts = (app.ui.tableDrafts ??= {});
  const key = keyOf(app, upgradeId);
  const current = drafts[key];
  if (current?.dirty && current.cost.length === current.value.length) return current;
  const { constants } = app.derived();
  const cost = effectiveTable(definition, "cost", constants);
  const value = effectiveTable(definition, "value", constants);
  const signature = JSON.stringify([cost, value]);
  if (current && current.signature === signature) return current;
  drafts[key] = { cost, value, formula: { cost: definition.cost_model?.formula, value: definition.value_model?.formula }, dirty: false, signature };
  return drafts[key];
}

export function discardDraft(app, upgradeId) {
  delete (app.ui.tableDrafts ??= {})[keyOf(app, upgradeId)];
}

export function fillDraft(draft, kind, values, formula) {
  draft[kind] = values;
  draft.formula = { ...draft.formula, [kind]: formula };
  draft.dirty = true;
}
