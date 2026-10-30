import { cumulativeRatioOf, factorOf, ratioOf, relativeGain } from "./benefit.js";
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

export function buildRows(base, costs, increments, factor = 1) {
  const baseGain = Math.abs(base);
  const baseCost = (costs[0] ?? 0) * factor;
  let value = base;
  let sum = 0;
  return costs.map((rawCost, index) => {
    const cost = rawCost * factor;
    const previous = value;
    const increment = increments[index] ?? 0;
    value = previous + increment;
    sum += cost;
    const gain = relativeGain(previous, value);
    return {
      level: index + 1,
      cost,
      sum,
      increment,
      incrementFactor: previous !== 0 ? value / previous : null,
      value,
      gain,
      factor: factorOf(gain, cost),
      stepRatio: ratioOf(Math.abs(increment), baseGain, cost, baseCost),
      totalRatio: cumulativeRatioOf(baseGain, Math.abs(value - base), baseCost, sum),
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
