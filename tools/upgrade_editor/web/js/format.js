const SUFFIXES = [
  [1e15, "Q"],
  [1e12, "T"],
  [1e9, "B"],
  [1e6, "M"],
  [1e3, "K"],
];

export function compact(value, locale = "de") {
  if (!Number.isFinite(value)) return "–";
  const sign = value < 0 ? "-" : "";
  const absolute = Math.abs(value);
  for (const [limit, suffix] of SUFFIXES) {
    if (absolute >= limit) return sign + decimal(absolute / limit, absolute / limit >= 100 ? 0 : absolute / limit >= 10 ? 1 : 2, locale) + suffix;
  }
  return sign + decimal(absolute, absolute >= 100 ? 0 : absolute >= 10 ? 1 : 2, locale);
}

export function decimal(value, digits, locale = "de") {
  if (!Number.isFinite(value)) return "–";
  const text = value.toFixed(digits);
  const trimmed = digits > 0 ? text.replace(/\.?0+$/, "") : text;
  return locale === "de" ? trimmed.replace(".", ",") : trimmed;
}

export function percent(value, locale = "de") {
  if (!Number.isFinite(value)) return "–";
  const digits = Math.abs(value) >= 100 ? 0 : Math.abs(value) >= 10 ? 1 : 2;
  return decimal(value, digits, locale) + " %";
}

export function significant(value, locale = "de") {
  if (!Number.isFinite(value)) return "–";
  const absolute = Math.abs(value);
  if (absolute === 0) return "0";
  if (absolute >= 1000) return decimal(value, 0, locale);
  if (absolute >= 10) return decimal(value, 2, locale);
  if (absolute >= 0.01) return decimal(value, 4, locale);
  return value.toExponential(2);
}

export function sprintf(template, ...values) {
  let index = 0;
  return String(template).replace(/%([sd%])/g, (match, type) => {
    if (type === "%") return "%";
    const value = values[index++];
    return type === "d" ? String(Math.trunc(Number(value))) : String(value ?? "");
  });
}
