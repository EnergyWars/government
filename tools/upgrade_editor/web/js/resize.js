export const MIN_RECT_SIZE = 8;
export const HANDLE_PX = 10;
export const HANDLE_CURSORS = { nw: "nwse-resize", se: "nwse-resize", ne: "nesw-resize", sw: "nesw-resize", n: "ns-resize", s: "ns-resize", e: "ew-resize", w: "ew-resize" };

const limit = (value, low, high) => Math.min(high, Math.max(low, value));

export function resizeRect(rect, handle, dx, dy, bounds = null, min = MIN_RECT_SIZE) {
  const area = bounds ?? { minX: -Infinity, minY: -Infinity, maxX: Infinity, maxY: Infinity };
  let left = rect[0];
  let top = rect[1];
  let right = rect[0] + rect[2];
  let bottom = rect[1] + rect[3];
  if (handle.includes("w")) left = limit(left + dx, area.minX, right - min);
  if (handle.includes("e")) right = limit(right + dx, left + min, area.maxX);
  if (handle.includes("n")) top = limit(top + dy, area.minY, bottom - min);
  if (handle.includes("s")) bottom = limit(bottom + dy, top + min, area.maxY);
  return [Math.round(left), Math.round(top), Math.round(right) - Math.round(left), Math.round(bottom) - Math.round(top)];
}

export function handleLayout(rect, zoom, pixels = HANDLE_PX) {
  const size = pixels / zoom;
  const [x, y, width, height] = rect;
  const right = x + width;
  const bottom = y + height;
  const centreX = x + width / 2;
  const centreY = y + height / 2;
  const points = [["nw", x, y], ["ne", right, y], ["se", right, bottom], ["sw", x, bottom]];
  if (width * zoom >= pixels * 4) points.push(["n", centreX, y], ["s", centreX, bottom]);
  if (height * zoom >= pixels * 4) points.push(["e", right, centreY], ["w", x, centreY]);
  return points.map(([id, cx, cy]) => ({ id, x: cx - size / 2, y: cy - size / 2, size }));
}
