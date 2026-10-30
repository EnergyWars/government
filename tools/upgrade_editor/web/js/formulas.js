import { compile, evaluate } from "./formula.js";
export function effectiveConstants(context, document) {
  return { ...context.constants, ...(document.system?.constants ?? {}) };
}

export function departmentSettings(departmentId, context, document) {
  const base = context.departments.find((entry) => entry.id === departmentId);
  if (!base) return null;
  return { ...base, ...(document.system?.departments?.[departmentId] ?? {}) };
}

export function stationKindSettings(kind, document) {
  return document.system?.station_kinds?.[kind] ?? { desk_cost: 0, hire_cost: 0 };
}

export function earlyDiscount(level, constants) {
  const levels = constants.EARLY_DISCOUNT_LEVELS;
  if (level >= levels) return 1;
  const start = constants.EARLY_DISCOUNT_START;
  return start + (1 - start) * (Math.max(0, level) / levels);
}

export function levelSpeed(level, constants) {
  const milestones = Math.floor(level / constants.LEVEL_MILESTONE_STEP);
  return (1 + constants.LEVEL_SPEED_BONUS * (level - 1)) * constants.LEVEL_MILESTONE_BONUS ** milestones;
}

export const COST_VARIABLES = ["level", "max", "cost", "growth", "price_offset"];
export const VALUE_VARIABLES = ["level", "max", "base", "step", "rate", "neutral"];

export function costVariables(definition, level) {
  return { level, max: definition.max ?? 0, cost: definition.cost, growth: definition.growth, price_offset: definition.price_offset ?? 0 };
}

export function valueVariables(definition, level) {
  const base = definition.base ?? 0;
  return { level, max: definition.max ?? 0, base, step: definition.step ?? 0, rate: definition.rate ?? 1, neutral: definition.neutral ?? base };
}

export function checkFormula(kind, definition, text) {
  const names = kind === "cost" ? COST_VARIABLES : VALUE_VARIABLES;
  const compiled = compile(text ?? "", names);
  if (!compiled.ok) return { ok: false, code: compiled.code };
  const last = kind === "cost" ? definition.max - 1 : definition.max;
  for (let level = 0; level <= last; level += 1) {
    const value = compiled.run(kind === "cost" ? costVariables(definition, level) : valueVariables(definition, level));
    if (!Number.isFinite(value)) return { ok: false, code: "NOT_FINITE", level };
    if (kind === "cost" && value < 0) return { ok: false, code: "NEGATIVE", level };
  }
  return { ok: true };
}

export function trackValue(definition, level, constants) {
  const capped = Math.min(Math.max(level, 0), definition.max ?? 0);
  const model = definition.value_model;
  if (model) return modelValue(definition, model, capped, constants);
  return parametricValue(definition, capped, constants);
}

function modelValue(definition, model, capped, constants) {
  const base = definition.base ?? 0;
  if (model.mode === "table") {
    let total = base;
    const increments = model.increments ?? [];
    for (let index = 0; index < Math.min(capped, increments.length); index += 1) total += increments[index];
    return total;
  }
  const result = evaluate(model.formula ?? "", valueVariables(definition, capped));
  return result.ok ? result.value : parametricValue(definition, capped, constants);
}

function parametricValue(definition, capped, constants) {
  const base = definition.base ?? 0;
  switch (definition.curve) {
    case "decay":
      return base * (definition.rate ?? 1) ** capped;
    case "unlock_decay":
      return capped <= 0 ? -1 : base * (definition.rate ?? 1) ** (capped - 1);
    case "chance":
      return 1 - (1 - base) * (definition.rate ?? 1) ** capped;
    case "unlock":
      return capped > 0 ? 1 : 0;
    case "milestone":
      return levelSpeed(capped + 1, constants);
    default:
      return base + (definition.step ?? 0) * capped;
  }
}

export function shareMultiplier(key, context) {
  return context.shared_stations?.[key]?.cost_multiplier ?? 1;
}

export function trackRoomFactor(upgradeId, definition, roomId, context, document, constants) {
  if (!roomId) return 1;
  const settings = departmentSettings(roomId, context, document);
  if (upgradeId === "tube_station") {
    if (roomId === "inspection") return constants.TUBE_STATION_INSPECTION_FACTOR;
    const unlock = settings?.unlock_cost ?? 0;
    return Math.max(1, (unlock * constants.TUBE_STATION_FACTOR) / constants.TUBE_STATION_MIN_COST);
  }
  if (roomId === "inspection") return shareMultiplier("shared/inspection", context);
  if (!settings) return 1;
  if (definition.staff_cost) return settings.staff_multiplier ?? settings.cost_multiplier ?? 1;
  return settings.cost_multiplier ?? 1;
}

export function modelCost(definition, level) {
  const model = definition.cost_model;
  if (model.mode === "table") {
    const levels = model.levels ?? [];
    return levels.length === 0 ? 0 : Math.max(0, levels[Math.min(Math.max(level, 0), levels.length - 1)]);
  }
  const result = evaluate(model.formula ?? "", costVariables(definition, level));
  return Math.max(0, result.ok ? result.value : definition.cost * definition.growth ** level);
}

export function trackCost(definition, level, factor, constants) {
  if (definition.cost_model) return modelCost(definition, level) * factor;
  const priceLevel = level + (definition.price_offset ?? 0);
  return definition.cost * factor * definition.growth ** level * earlyDiscount(priceLevel, constants);
}

export function geometricSum(first, growth, count) {
  if (count <= 0) return 0;
  if (Math.abs(growth - 1) < 1e-9) return first * count;
  return (first * (growth ** count - 1)) / (growth - 1);
}

export function rankLadderCost(index, context, document, constants) {
  const ids = context.departments.map((entry) => entry.id);
  const last = ids.length - 1;
  const position = Math.max(0, index);
  if (position <= last) return departmentSettings(ids[position], context, document).unlock_cost;
  return departmentSettings(ids[last], context, document).unlock_cost * constants.RANK_LADDER_GROWTH ** (position - last);
}

export function rankBaseCost(departmentId, context, document, constants) {
  const ids = context.departments.map((entry) => entry.id);
  const firstBlock = geometricSum(1, constants.RANK_LEVEL_COST_GROWTH, constants.RANK_MILESTONE_STEP - 1);
  return rankLadderCost(Math.max(0, ids.indexOf(departmentId)) + 1, context, document, constants) / firstBlock;
}

export function rankFeeFactor(level, constants) {
  const capped = Math.min(Math.max(level, 1), constants.MAX_DEPARTMENT_RANK);
  const factors = constants.RANK_MILESTONE_FACTORS;
  const milestones = Math.min(Math.floor(capped / constants.RANK_MILESTONE_STEP), factors.length);
  let factor = constants.RANK_LEVEL_FEE_FACTOR ** (capped - 1);
  for (let index = 0; index < milestones; index += 1) factor *= factors[index];
  return factor;
}

export function stationCostMultiplier(station, context, document) {
  if (station.shared) return shareMultiplier(station.key, context);
  return departmentSettings(station.department, context, document)?.cost_multiplier ?? 1;
}

export function stationStaffMultiplier(station, context, document) {
  if (station.shared) return shareMultiplier(station.key, context);
  const settings = departmentSettings(station.department, context, document);
  return settings?.staff_multiplier ?? settings?.cost_multiplier ?? 1;
}

export function finalDesks(context) {
  return Math.max(...context.building_stages.map((stage) => stage.max_desks));
}

const STAFF_CONSTANTS = {
  runners: ["RUNNER_COST", "RUNNER_GROWTH", "MAX_RUNNERS"],
  coffee_interns: ["COFFEE_INTERN_COST", "COFFEE_INTERN_GROWTH", "MAX_COFFEE_INTERNS"],
  hr: ["HR_COST", "HR_GROWTH", "MAX_HR"],
};

function stationOf(target, context) {
  const station = context.stations[target];
  return station ? { key: target, ...station } : null;
}

export function systemModel(entry, context, document, constants) {
  const priced = (fields) => ({ discount: true, shift: 0, minLevel: 0, single: false, ...fields });
  switch (entry.kind) {
    case "desk": {
      const station = stationOf(entry.target, context);
      if (!station) return null;
      const base = stationKindSettings(station.kind, document).desk_cost * stationCostMultiplier(station, context, document);
      return priced({ base, growth: constants.DESK_GROWTH, shift: -1, minLevel: 1, maxLevel: finalDesks(context) });
    }
    case "hire": {
      const station = stationOf(entry.target, context);
      if (!station) return null;
      const base = stationKindSettings(station.kind, document).hire_cost * stationStaffMultiplier(station, context, document);
      return priced({ base, growth: constants.HIRE_GROWTH, maxLevel: finalDesks(context) });
    }
    case "reject_pile": {
      const station = stationOf(entry.target, context);
      if (!station) return null;
      const base = stationKindSettings(station.kind, document).desk_cost * stationCostMultiplier(station, context, document) * constants.REJECT_PILE_COST_FACTOR;
      return priced({ base, growth: constants.REJECT_PILE_GROWTH, maxLevel: constants.MAX_REJECT_LEVEL });
    }
    case "staff": {
      const names = STAFF_CONSTANTS[entry.target];
      if (!names) return null;
      return priced({ base: constants[names[0]], growth: constants[names[1]], maxLevel: constants[names[2]] });
    }
    case "segment":
      return priced({ base: constants.TUBE_SEGMENT_COST, growth: constants.TUBE_SEGMENT_GROWTH, maxLevel: constants.TUBE_SEGMENT_MAX_LEVEL });
    case "storage":
      return priced({ base: constants.MAIL_STORAGE_COST, growth: constants.MAIL_STORAGE_GROWTH, maxLevel: constants.MAIL_STORAGE_MAX_LEVEL });
    case "rank":
      return priced({ base: rankBaseCost(entry.target, context, document, constants), growth: constants.RANK_LEVEL_COST_GROWTH, shift: -1, minLevel: 1, maxLevel: constants.MAX_DEPARTMENT_RANK, discount: false });
    case "unlock":
      return priced({ base: departmentSettings(entry.target, context, document)?.unlock_cost ?? 0, growth: 1, minLevel: 0, maxLevel: 1, single: true, discount: false });
    default:
      return null;
  }
}

export function systemCost(model, level, constants) {
  const index = level + model.shift;
  return model.base * model.growth ** index * (model.discount ? earlyDiscount(index, constants) : 1);
}
