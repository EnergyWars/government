import { factorOf, systemStep, systemTotals, trackStep, trackTotals } from "./benefit.js";
import { effectiveConstants, systemCost, systemModel, trackCost, trackRoomFactor } from "./formulas.js";
import { buildEntries, parseRef, scopedDefinition } from "./model.js";
import { createTexts } from "./texts.js";

export function createApp({ store, i18n, notify }) {
  let derivedCache = null;
  let metricCache = new Map();

  function derived() {
    const { document, context, translations } = store.state;
    if (!derivedCache || derivedCache.document !== document || derivedCache.language !== i18n.language) {
      const entries = buildEntries(document, context);
      derivedCache = {
        document,
        language: i18n.language,
        constants: effectiveConstants(context, document),
        entries,
        byId: new Map(entries.map((entry) => [entry.id, entry])),
        texts: createTexts({ translations, context, document, language: i18n.language }),
      };
      metricCache = new Map();
    }
    return derivedCache;
  }

  function metrics(entry) {
    derived();
    if (!metricCache.has(entry.id)) metricCache.set(entry.id, computeMetrics(entry));
    return metricCache.get(entry.id);
  }

  function computeMetrics(entry) {
    const { document, context } = store.state;
    const { constants } = derived();
    if (entry.kind === "track") return trackMetrics(entry, document, context, constants);
    const model = systemModel(entry, context, document, constants);
    if (!model) return null;
    const first = systemStep(entry, model, model.minLevel, constants);
    return {
      type: "system",
      max: model.maxLevel - model.minLevel,
      single: model.single,
      first,
      lastCost: systemCost(model, model.maxLevel - 1, constants),
      totals: systemTotals(entry, model, constants),
    };
  }

  function trackMetrics(entry, document, context, constants) {
    const definition = scopedDefinition(document, entry.target, entry.roomId);
    if (!definition) return null;
    const factor = trackRoomFactor(entry.target, definition, entry.roomId, context, document, constants);
    return {
      type: "track",
      max: definition.max,
      single: definition.max === 1,
      factor,
      first: trackStep(definition, 0, factor, constants),
      lastCost: trackCost(definition, definition.max - 1, factor, constants),
      totals: trackTotals(definition, factor, constants),
    };
  }

  function edit(operation, meta = { origin: "edit" }) {
    const result = operation(store.state.document);
    if (result.error) {
      notify(i18n.t("error." + result.error), "error");
      return result;
    }
    store.commit(result.document, meta);
    return result;
  }

  function selectedUpgradeId() {
    const selection = store.state.selection;
    if (!selection?.ref) return null;
    const parsed = parseRef(selection.ref);
    return parsed.kind === "track" ? parsed.upgradeId : null;
  }

  return { store, i18n, t: (key, params) => i18n.t(key, params), derived, metrics, edit, notify, selectedUpgradeId, factorOf, ui: { zoom: 0.42, spot: null, menuMode: "rooms", expanded: {}, search: "", formulaDrafts: {}, tableDrafts: {}, scopes: {}, scopeRef: null, chartHidden: {}, sections: {}, fillTab: {}, incrementMode: "absolute" } };
}
