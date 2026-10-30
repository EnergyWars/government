export function normalise(text) {
  return String(text ?? "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().trim();
}

export function filterOptions(options, query) {
  const tokens = normalise(query).split(/\s+/).filter(Boolean);
  if (tokens.length === 0) return options.map((option, index) => ({ option, index }));
  const scored = [];
  options.forEach((option, index) => {
    const label = normalise(option.label);
    const hay = label + " " + normalise(option.value) + " " + normalise(option.keywords);
    if (!tokens.every((token) => hay.includes(token))) return;
    const rank = label.startsWith(tokens[0]) ? 0 : label.split(/[\s·/_-]+/).some((word) => word.startsWith(tokens[0])) ? 1 : 2;
    scored.push({ option, index, rank });
  });
  scored.sort((a, b) => a.rank - b.rank || a.index - b.index);
  return scored.map(({ option, index }) => ({ option, index }));
}

export function stepActive(active, delta, length) {
  if (length <= 0) return -1;
  if (active < 0) return delta > 0 ? 0 : length - 1;
  return (active + delta + length) % length;
}
