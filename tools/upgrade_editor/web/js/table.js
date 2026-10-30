import { PER_COST, cumulativeRatioOf, factorOf, ratioOf, relativeGain } from "./benefit.js";
import { trackCost, trackValue } from "./formulas.js";

export const clean = (value) => Number(value.toPrecision(12));

export function effectiveTable(definition, kind, constants) {
  const levels = Array.from({ length: definition.max }, (_, level) => level);
  if (kind === "cost") return levels.map((level) => trackCost(definition, level, 1, constants));
  return levels.map((level) => trackValue(definition, level + 1, constants) - trackValue(definition, level, constants));
}

export function valueBefore(base, increments, index) {
  let total = base;
  for (let position = 0; position < index; position += 1) total += increments[position];
  return total;
}

export function buildRows(base, costs, increments, factor = 1, reference = (costs[0] ?? 0) * factor) {
  const baseGain = Math.abs(base);
  let value = base;
  let sum = 0;
  return costs.map((rawCost, index) => {
    const cost = rawCost * factor;
    const previous = value;
    const increment = increments[index] ?? 0;
    value = previous + increment;
    sum += cost;
    const gain = relativeGain(previous, value);
    const known = reference > 0;
    return {
      level: index + 1,
      cost,
      costFactor: known ? cost / reference : null,
      sum,
      sumFactor: known ? sum / reference : null,
      increment,
      incrementFactor: previous !== 0 ? value / previous : null,
      value,
      effect: base !== 0 ? value / base : null,
      gain,
      factor: factorOf(gain, cost),
      stepRatio: ratioOf(Math.abs(increment), baseGain, cost, reference),
      totalRatio: cumulativeRatioOf(baseGain, Math.abs(value - base), reference, sum),
    };
  });
}

function replaced(list, index, value) {
  const next = [...list];
  next[index] = value;
  return next;
}

export function withCost(costs, index, input) {
  return replaced(costs, index, clean(input));
}

export function withIncrement(increments, index, input, mode, base) {
  const previous = valueBefore(base, increments, index);
  return replaced(increments, index, clean(mode === "factor" ? previous * (input - 1) : input));
}

export function withValue(increments, index, input, base) {
  return replaced(increments, index, clean(input - valueBefore(base, increments, index)));
}

export function incrementCell(row, mode) {
  return mode === "factor" ? row.incrementFactor : row.increment;
}

export const COLUMNS = ["level", "cost", "costFactor", "sum", "sumFactor", "increment", "value", "effect", "gain", "factor", "stepRatio", "totalRatio"];

export function metricValue(row, column, mode) {
  if (column === "increment") return mode === "factor" ? row.incrementFactor : row.increment;
  if (column === "gain") return row.gain === null ? null : row.gain * 100;
  return row[column] ?? null;
}

export function editRow(table, index, column, input, { base, reference, mode = "absolute" }) {
  if (!Number.isFinite(input) || index < 0 || index >= table.cost.length) return table;
  const before = valueBefore(base, table.value, index);
  const sumBefore = table.cost.slice(0, index).reduce((total, cost) => total + cost, 0);
  const increment = table.value[index];
  const absBase = Math.abs(base);
  const known = reference > 0;
  const gainNow = relativeGain(before, before + increment);
  const cost = (amount) => (Number.isFinite(amount) && amount >= 0 ? { cost: amount } : null);
  const delta = (amount) => (Number.isFinite(amount) ? { value: amount } : null);
  const sign = increment < 0 ? -1 : 1;
  const afterGain = (fraction) => (before !== 0 && fraction >= 0 && fraction < 1 ? delta(sign * fraction * Math.abs(before)) : null);
  const targets = {
    cost: () => cost(input),
    costFactor: () => (known ? cost(input * reference) : null),
    sum: () => cost(input - sumBefore),
    sumFactor: () => (known ? cost(input * reference - sumBefore) : null),
    increment: () => (mode === "factor" ? delta(before * (input - 1)) : delta(input)),
    value: () => delta(input - before),
    effect: () => (absBase > 0 ? delta(input * base - before) : null),
    gain: () => afterGain(input / 100),
    factor: () => (input > 0 && gainNow > 0 ? cost((gainNow * 100 * PER_COST) / input) : null),
    stepRatio: () => (input > 0 && known && absBase > 0 && increment !== 0 ? cost((Math.abs(increment) / absBase) * reference * 100 / input) : null),
    totalRatio: () => {
      if (!(input > 0 && known && absBase > 0)) return null;
      const total = reference * ((1 + Math.abs(before + increment - base) / absBase) * 100 / input - 1);
      return cost(total - sumBefore);
    },
  };
  const change = targets[column]?.();
  if (!change) return table;
  const next = { cost: [...table.cost], value: [...table.value] };
  if ("cost" in change) next.cost[index] = clean(change.cost);
  if ("value" in change) next.value[index] = clean(change.value);
  return next;
}

export function visibleColumns(hidden) {
  return COLUMNS.filter((column) => column === "level" || !hidden[column]);
}

export function changedRows(draft, applied) {
  return draft.cost.map((cost, index) => index >= applied.cost.length || !same(cost, applied.cost[index]) || !same(draft.value[index], applied.value[index]));
}

function same(a, b) {
  return Math.abs(a - b) <= 1e-9 * Math.max(1, Math.abs(a), Math.abs(b));
}

export function appendLevel(draft) {
  return { ...draft, cost: [...draft.cost, draft.cost.at(-1) ?? 0], value: [...draft.value, draft.value.at(-1) ?? 0] };
}

export function dropLevel(draft) {
  if (draft.cost.length <= 1) return draft;
  return { ...draft, cost: draft.cost.slice(0, -1), value: draft.value.slice(0, -1) };
}
