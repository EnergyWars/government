import { h, svg } from "../dom.js";
import { addSpotRect, areaContents, deleteSpot, isSpotEdited, normaliseRect, removeSpotRect, resetSpotRects, resizeSpotRect } from "../model.js";
import { HANDLE_CURSORS, boundingBox, fitZoom, handleLayout, isSameRect, moveRect, resizeRect, zoomedBy } from "../resize.js";
import { iconButton } from "./components.js";

const MIN_DRAW_SIZE = 12;
const DRAG_PIXELS = 3;
const RECT_LABELS = ["x", "y", "width", "height"];

export function startAreaEdit(app, spot) {
  const rects = app.store.state.context.spots[spot]?.rects ?? [];
  const zoom = fitZoom(boundingBox(rects), { width: window.innerWidth - 480, height: window.innerHeight - 260 });
  if (zoom) app.ui.zoom = zoom;
  Object.assign(app.ui, { editSpot: spot, editBox: rects.length ? 0 : null, editDraw: rects.length === 0, focusEdit: true, drawMode: false, draft: null });
  app.rerender();
}

export function stopAreaEdit(app) {
  Object.assign(app.ui, { editSpot: null, editBox: null, editDraw: false });
  app.rerender();
}

function rectInputs(app, spot, rect, index) {
  return RECT_LABELS.map((label, position) => h("input", { type: "number", min: position > 1 ? 1 : undefined, value: rect[position], "aria-label": app.t("area.rect." + label), title: app.t("area.rect." + label), onChange: (event) => {
    const next = [...rect];
    next[position] = Number(event.target.value);
    const result = event.target.value.trim() === "" ? { error: "RECT_INVALID" } : app.edit((document) => resizeSpotRect(document, app.store.state.baseContext, spot, index, next), { origin: "area" });
    if (result.error) event.target.classList.add("invalid");
  } }));
}

function dragSession(event, node, { toPoint, zoom, compute, preview, commit, click }) {
  if (event.button !== 0) return;
  event.preventDefault();
  event.stopPropagation();
  node.setPointerCapture(event.pointerId);
  const start = toPoint(event);
  let current = null;
  const move = (moveEvent) => {
    const point = toPoint(moveEvent);
    const dx = point.x - start.x;
    const dy = point.y - start.y;
    if (!current && Math.hypot(dx, dy) * zoom < DRAG_PIXELS) return;
    current = compute(dx, dy);
    preview(current);
  };
  const stop = () => {
    node.removeEventListener("pointermove", move);
    node.removeEventListener("pointerup", finish);
    node.removeEventListener("pointercancel", cancel);
  };
  const cancel = () => {
    stop();
    preview(null);
  };
  const finish = () => {
    stop();
    if (current) commit(current);
    else click?.();
  };
  node.addEventListener("pointermove", move);
  node.addEventListener("pointerup", finish);
  node.addEventListener("pointercancel", cancel);
}

export function renderAreaEdit(container, app, backdrop) {
  const spot = app.ui.editSpot;
  const { context, document, baseContext } = app.store.state;
  const rects = context.spots[spot]?.rects;
  if (!rects) {
    app.ui.editSpot = null;
    return false;
  }
  const { texts } = app.derived();
  const [width, height] = context.map.size;
  const zoom = app.ui.zoom;
  const bounds = { minX: 0, minY: 0, maxX: width, maxY: height };
  const custom = spot.startsWith("area:");
  const edited = isSpotEdited(document, spot);
  const active = Number.isInteger(app.ui.editBox) && rects[app.ui.editBox] ? app.ui.editBox : null;
  const drawing = Boolean(app.ui.editDraw);
  const sizeText = (rect) => app.t("area.size", { x: rect[0], y: rect[1], width: rect[2], height: rect[3] });
  const idleText = () => (drawing ? app.t("area.drawHint") : active !== null ? sizeText(rects[active]) : app.t("area.editHint"));
  const status = h("div", { class: "map-status" }, idleText());
  const root = svg("svg", { viewBox: `0 0 ${width} ${height}`, width: width * zoom, height: height * zoom, class: "map-svg editing", role: "img", "aria-label": app.t("map.title") });
  const toPoint = (event) => {
    const point = root.createSVGPoint();
    point.x = event.clientX;
    point.y = event.clientY;
    return point.matrixTransform(root.getScreenCTM().inverse());
  };
  const change = (operation, next = {}) => {
    Object.assign(app.ui, next);
    return app.edit(operation, { origin: "area" });
  };
  const select = (index) => {
    app.ui.editBox = index;
    app.rerender();
  };

  root.append(backdrop(), svg("rect", { x: 0, y: 0, width, height, class: "edit-dim" }));
  const ground = svg("rect", { x: 0, y: 0, width, height, fill: "transparent" });
  ground.addEventListener("click", () => {
    if (active !== null) select(null);
  });
  root.append(ground);

  const handleLayer = svg("g", { class: "map-resize" });
  const boxNodes = new Map();
  const previewBox = (index) => (rect) => {
    if (!rect) {
      app.rerender();
      return;
    }
    const node = boxNodes.get(index);
    node.setAttribute("x", rect[0]);
    node.setAttribute("y", rect[1]);
    node.setAttribute("width", rect[2]);
    node.setAttribute("height", rect[3]);
    handleLayer.setAttribute("visibility", "hidden");
    status.textContent = sizeText(rect);
  };
  const commitBox = (index) => (rect) => {
    if (isSameRect(rect, rects[index])) {
      app.rerender();
      return;
    }
    change((current) => resizeSpotRect(current, baseContext, spot, index, rect), { editBox: index });
  };

  const order = rects.map((_, index) => index).sort((a, b) => rects[b][2] * rects[b][3] - rects[a][2] * rects[a][3]);
  for (const index of order) {
    const rect = rects[index];
    const node = svg("rect", { x: rect[0], y: rect[1], width: rect[2], height: rect[3], rx: 6, class: "edit-box" + (index === active ? " active" : "") });
    node.addEventListener("pointerdown", (event) => dragSession(event, node, { toPoint, zoom, compute: (dx, dy) => moveRect(rect, dx, dy, bounds), preview: previewBox(index), commit: commitBox(index), click: () => select(index) }));
    boxNodes.set(index, node);
    root.append(node);
  }

  if (active !== null && !drawing) {
    const rect = rects[active];
    for (const handle of handleLayout(rect, zoom)) {
      const node = svg("rect", { x: handle.x, y: handle.y, width: handle.size, height: handle.size, rx: handle.size / 5, class: "resize-handle", style: `cursor:${HANDLE_CURSORS[handle.id]}`, "data-handle": handle.id });
      node.addEventListener("pointerdown", (event) => dragSession(event, node, { toPoint, zoom, compute: (dx, dy) => resizeRect(rect, handle.id, dx, dy, bounds), preview: previewBox(active), commit: commitBox(active) }));
      handleLayer.append(node);
    }
  }
  root.append(handleLayer);

  const draft = svg("g", { class: "map-draft" });
  if (drawing) {
    const overlay = svg("rect", { x: 0, y: 0, width, height, fill: "transparent", class: "edit-draw" });
    const inside = (event) => {
      const point = toPoint(event);
      return { x: Math.min(width, Math.max(0, point.x)), y: Math.min(height, Math.max(0, point.y)) };
    };
    overlay.addEventListener("pointerdown", (event) => {
      if (event.button !== 0) return;
      event.preventDefault();
      overlay.setPointerCapture(event.pointerId);
      const anchor = inside(event);
      const move = (moveEvent) => {
        const rect = normaliseRect(anchor, inside(moveEvent));
        draft.replaceChildren(svg("rect", { x: rect[0], y: rect[1], width: rect[2], height: rect[3], rx: 6, class: "draft-box" }));
        status.textContent = sizeText(rect);
      };
      const stop = () => {
        overlay.removeEventListener("pointermove", move);
        overlay.removeEventListener("pointerup", finish);
        overlay.removeEventListener("pointercancel", cancel);
        draft.replaceChildren();
      };
      const cancel = () => {
        stop();
        status.textContent = idleText();
      };
      const finish = (upEvent) => {
        const rect = normaliseRect(anchor, inside(upEvent));
        stop();
        if (rect[2] < MIN_DRAW_SIZE || rect[3] < MIN_DRAW_SIZE) {
          status.textContent = idleText();
          return;
        }
        change((current) => addSpotRect(current, baseContext, spot, rect), { editBox: rects.length, editDraw: false });
      };
      overlay.addEventListener("pointermove", move);
      overlay.addEventListener("pointerup", finish);
      overlay.addEventListener("pointercancel", cancel);
    });
    root.append(overlay);
  }
  root.append(draft);

  const removeBox = () => {
    if (active === null) return;
    change((current) => removeSpotRect(current, baseContext, spot, active), { editBox: null });
  };
  const resetArea = () => change((current) => resetSpotRects(current, spot), { editBox: null });
  const deleteArea = () => {
    const count = custom ? areaContents(document, spot.slice(5)).length : 0;
    const message = !custom ? app.t("area.confirmDeleteGame") : count ? app.t("area.confirmDeleteWith", { count }) : app.t("area.confirmDelete");
    if (!window.confirm(message)) return;
    const result = change((current) => deleteSpot(current, baseContext, spot), custom ? { editSpot: null, editBox: null, editDraw: false, spot: null } : { editBox: null, editDraw: false });
    if (result.error && custom) {
      Object.assign(app.ui, { editSpot: spot, spot });
      app.rerender();
    }
  };

  const toolbar = h("div", { class: "map-toolbar" },
    h("button", { type: "button", class: "primary", onClick: () => stopAreaEdit(app) }, "← " + app.t("area.adjustDone")),
    iconButton(app.t("map.zoomOut"), "−", () => { app.ui.zoom = zoomedBy(zoom, 0.8); app.rerender(); }),
    iconButton(app.t("map.zoomIn"), "+", () => { app.ui.zoom = zoomedBy(zoom, 1.25); app.rerender(); }),
    iconButton(app.t("map.zoomFit"), "⤢", () => { startAreaEdit(app, spot); }),
    h("button", { type: "button", class: "segment" + (drawing ? " active" : ""), "aria-pressed": drawing, onClick: () => { app.ui.editDraw = !drawing; app.rerender(); } }, "▭ " + app.t("area.addRect")),
    h("button", { type: "button", disabled: active === null || (custom && rects.length === 1), onClick: removeBox }, "✕ " + app.t("area.removeRect")),
    custom ? null : h("button", { type: "button", disabled: !edited, onClick: resetArea }, "↺ " + app.t("area.reset")),
    h("button", { type: "button", class: "danger-button", disabled: !custom && rects.length === 0, onClick: deleteArea }, app.t("area.delete")),
    status,
  );

  const rows = rects.map((rect, index) => h("div", { class: "row rect-row" + (index === active ? " active" : "") },
    h("button", { type: "button", class: "chip action" + (index === active ? " active" : ""), onClick: () => select(index) }, app.t("area.box", { number: index + 1 })),
    rectInputs(app, spot, rect, index),
    iconButton(app.t("area.removeRect"), "✕", () => change((current) => removeSpotRect(current, baseContext, spot, index), { editBox: null }), { class: "danger", disabled: custom && rects.length === 1 })));

  const scroller = h("div", { class: "map-scroll", dataset: { scroll: "map" } }, root);
  if (app.ui.focusEdit) {
    app.ui.focusEdit = false;
    const box = boundingBox(rects);
    if (box) window.requestAnimationFrame(() => scroller.scrollTo({ left: Math.max(0, (box[0] + box[2] / 2) * zoom - scroller.clientWidth / 2), top: Math.max(0, (box[1] + box[3] / 2) * zoom - scroller.clientHeight / 2) }));
  }

  container.append(h("div", { class: "map-layout editing" },
    h("section", { class: "map-pane" }, toolbar, scroller),
    h("aside", { class: "spot-pane" },
      h("div", { class: "intro" }, h("h2", {}, texts.spotTitle(spot)), h("div", { class: "intro-meta" }, custom ? app.t("area.custom") : app.t("area.existing") + (edited ? " · " + app.t("area.edited") : ""), " · ", h("code", {}, spot))),
      h("p", { class: "hint" }, app.t("area.editHelp")),
      rows.length ? h("section", { class: "area-editor" }, rows) : h("p", { class: "hint" }, app.t("area.noBoxes")),
    ),
  ));
  return true;
}
