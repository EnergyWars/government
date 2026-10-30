export const CHART = { width: 320, height: 150, pad: 6 };

export function nearestIndex(x, width, count) {
  if (count <= 1) return 0;
  const span = width - CHART.pad * 2;
  const index = Math.round(((x - CHART.pad) / span) * (count - 1));
  return Math.max(0, Math.min(count - 1, index));
}

export function xOf(index, count) {
  if (count <= 1) return CHART.width / 2;
  return (index / (count - 1)) * (CHART.width - CHART.pad * 2) + CHART.pad;
}

export function scaleSeries(values) {
  const finite = values.filter((value) => Number.isFinite(value));
  if (finite.length === 0) return null;
  const low = Math.min(0, ...finite);
  const spread = Math.max(...finite, low + 1e-9) - low;
  return values.map((value, index) => (Number.isFinite(value) ? { x: xOf(index, values.length), y: CHART.height - CHART.pad - ((value - low) / spread) * (CHART.height - CHART.pad * 2) } : null));
}

export function highlightState(focusKey, key) {
  if (!focusKey) return "";
  return focusKey === key ? "focus" : "dim";
}

export function polylinePoints(points) {
  return points.filter(Boolean).map((point) => `${point.x.toFixed(1)},${point.y.toFixed(1)}`).join(" ");
}
