import { scopedDefinition, updateUpgrade } from "./model.js";

export function scopeOf(app, upgradeId) {
  return app.ui.scopes?.[upgradeId] ?? "";
}

export function definitionOf(app, upgradeId) {
  return scopedDefinition(app.store.state.document, upgradeId, scopeOf(app, upgradeId));
}

export function patchOf(app, document, upgradeId, patch) {
  return updateUpgrade(document, upgradeId, patch, scopeOf(app, upgradeId));
}
