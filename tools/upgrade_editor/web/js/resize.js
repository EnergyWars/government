export const MIN_RECT_SIZE = 8;
export const HANDLE_PX = 10;
export const ZOOM_LIMITS = { min: 0.15, max: 3 };
export const HANDLE_CURSORS = { nw: "nwse-resize", se: "nwse-resize", ne: "nesw-resize", sw: "nesw-resize", n: "ns-resize", s: "ns-resize", e: "ew-resize", w: "ew-resize" };

const limit = (value, low, high) => Math.min(high, Math.max(low, value));

export const clampZoom = (zoom) => limit(zoom, ZOOM_LIMITS.min, ZOOM_LIMITS.max);

export const zoomedBy = (zoom, factor) => clampZoom(zoom * factor);

export const isSameRect = (a, b) => a.length === b.length && a.every((value, position) => value === b[position]);

export function boundingBox(rects) {
  if (rects.length === 0) return null;
  const left = Math.min(...rects.map((rect) => rect[0]));
  const top = Math.min(...rects.map((rect) => rect[1]));
  const right = Math.max(...rects.map((rect) => rect[0] + rect[2]));
  const bottom = Math.max(...rects.map((rect) => rect[1] + rect[3]));
  return [left, top, right - left, bottom - top];
}

export function fitZoom(box, viewport, share = 0.5) {
  if (!box) return null;
  return clampZoom(Math.min((viewport.width * share) / box[2], (viewport.height * share) / box[3]));
}

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

export function moveRect(rect, dx, dy, bounds = null) {
  const area = bounds ?? { minX: -Infinity, minY: -Infinity, maxX: Infinity, maxY: Infinity };
  return [Math.round(limit(rect[0] + dx, area.minX, area.maxX - rect[2])), Math.round(limit(rect[1] + dy, area.minY, area.maxY - rect[3])), rect[2], rect[3]];
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
