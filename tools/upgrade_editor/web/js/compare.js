import { factorOf, relativeGain } from "./benefit.js";
import { trackValue } from "./formulas.js";
import { buildRows, effectiveTable } from "./table.js";

export const GROUPS = ["topic", "unit", "curve", "all"];

export function summarize(definition, constants) {
  const base = trackValue(definition, 0, constants);
  const costs = effectiveTable(definition, "cost", constants);
  const rows = buildRows(base, costs, effectiveTable(definition, "value", constants));
  const last = rows.at(-1);
  if (!last) return null;
  const gain = relativeGain(base, last.value);
  return { levels: rows.length, firstCost: costs[0], totalCost: last.sum, gain, factor: factorOf(gain, last.sum), totalRatio: last.totalRatio };
}

export function ratio(own, other) {
  if (typeof own !== "number" || typeof other !== "number" || !Number.isFinite(own) || !Number.isFinite(other) || !(own > 0)) return null;
  return (other / own) * 100;
}

export function isComparable(group, own, other) {
  if (group === "all") return true;
  if (group === "topic") return own.topic === other.topic;
  if (group === "unit") return (own.definition.unit ?? "") === (other.definition.unit ?? "");
  return own.definition.curve === other.definition.curve;
}

export function compareRows(items, ownKey, group, constants) {
  const own = items.find((item) => item.key === ownKey);
  if (!own) return { own: null, rows: [] };
  const ownSummary = summarize(own.definition, constants);
  const rows = items
    .filter((item) => item.key !== ownKey && isComparable(group, own, item))
    .map((item) => ({ item, summary: summarize(item.definition, constants) }))
    .filter((entry) => entry.summary)
    .map(({ item, summary }) => ({
      ...item,
      summary,
      relative: {
        cost: ratio(ownSummary?.totalCost, summary.totalCost),
        gain: ratio(ownSummary?.gain, summary.gain),
        factor: ratio(ownSummary?.factor, summary.factor),
        totalRatio: ratio(ownSummary?.totalRatio, summary.totalRatio),
      },
    }));
  rows.sort((a, b) => (b.relative.factor ?? -Infinity) - (a.relative.factor ?? -Infinity));
  return { own: { ...own, summary: ownSummary }, rows };
}

export function comparisonItems(entries, document, texts) {
  const seen = new Map();
  for (const entry of entries) {
    if (entry.kind !== "track" || seen.has(entry.target) || !document.upgrades[entry.target]) continue;
    seen.set(entry.target, { key: entry.target, ref: entry.id, title: texts.entryTitle(entry), topic: entry.topic, definition: document.upgrades[entry.target] });
  }
  return [...seen.values()];
}
