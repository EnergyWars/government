import { geometricSum, rankFeeFactor, systemCost, trackCost, trackValue } from "./formulas.js";

export const PER_COST = 1000;

export function relativeGain(before, after) {
  const delta = Math.abs(after - before);
  if (delta === 0) return 0;
  return delta / Math.max(Math.abs(before), delta);
}

export function factorOf(gain, cost) {
  if (gain === null || !(cost > 0)) return null;
  return ((gain * 100) / cost) * PER_COST;
}

export function trackStep(definition, level, factor, constants) {
  if (level < 0 || level >= definition.max) return null;
  const cost = trackCost(definition, level, factor, constants);
  const gain = relativeGain(trackValue(definition, level, constants), trackValue(definition, level + 1, constants));
  return { level: level + 1, cost, gain, factor: factorOf(gain, cost) };
}

export function trackSteps(definition, factor, constants) {
  const steps = [];
  for (let level = 0; level < definition.max; level += 1) steps.push(trackStep(definition, level, factor, constants));
  return steps;
}

export function ratioOf(gain, baseGain, cost, baseCost) {
  if (!(baseGain > 0) || !(baseCost > 0) || !(cost > 0)) return null;
  return ((gain / baseGain) / (cost / baseCost)) * 100;
}

export function cumulativeRatioOf(baseGain, gain, baseCost, cost) {
  if (!(baseGain > 0) || !(baseCost > 0) || !(cost >= 0)) return null;
  return ((1 + gain / baseGain) / (1 + cost / baseCost)) * 100;
}

export function trackTotals(definition, factor, constants) {
  let total = 0;
  for (let level = 0; level < definition.max; level += 1) total += trackCost(definition, level, factor, constants);
  const gain = relativeGain(trackValue(definition, 0, constants), trackValue(definition, definition.max, constants));
  return { cost: total, gain, factor: factorOf(gain, total) };
}

export function systemGain(entry, level, constants) {
  switch (entry.kind) {
    case "unlock":
      return null;
    case "rank":
      return rankFeeFactor(level + 1, constants) / rankFeeFactor(level, constants) - 1;
    default:
      return 1 / Math.max(level, 1);
  }
}

export function systemStep(entry, model, level, constants) {
  if (level < model.minLevel || level >= model.maxLevel) return null;
  const cost = systemCost(model, level, constants);
  const gain = systemGain(entry, level, constants);
  return { level: level + 1, cost, gain, factor: factorOf(gain, cost) };
}

export function systemTotals(entry, model, constants) {
  let cost = 0;
  for (let level = model.minLevel; level < model.maxLevel; level += 1) cost += systemCost(model, level, constants);
  if (entry.kind === "unlock") return { cost, gain: null, factor: null };
  if (entry.kind === "rank") {
    const gain = rankFeeFactor(model.maxLevel, constants) / rankFeeFactor(model.minLevel, constants) - 1;
    return { cost, gain, factor: factorOf(gain, cost) };
  }
  const gain = 1;
  return { cost, gain, factor: factorOf(gain, cost) };
}

export function levelTotal(model, from, to, constants) {
  let sum = 0;
  for (let level = from; level < to; level += 1) sum += systemCost(model, level, constants);
  return sum;
}

export { geometricSum };
