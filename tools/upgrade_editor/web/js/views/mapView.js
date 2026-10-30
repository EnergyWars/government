import { h, svg } from "../dom.js";
import { iconButton, select } from "./components.js";
import { renderSpotPanel } from "./spotPanel.js";
import { addArea, areaSlug, normaliseRect, setText, visibleAt } from "../model.js";

const KIND_CLASSES = { department: "map-department", room: "map-room", waiting: "map-waiting", area: "map-area" };

export function hitSpot(spots, x, y) {
  let best = null;
  let bestArea = Infinity;
  for (const [spot, info] of Object.entries(spots)) {
    for (const [left, top, width, height] of info.rects) {
      if (x >= left && x <= left + width && y >= top && y <= top + height && width * height < bestArea) {
        best = spot;
        bestArea = width * height;
      }
    }
  }
  return best;
}

function mapLabel(app, rect) {
  const { texts } = app.derived();
  if (rect.kind === "area") return texts.stationLabel(rect.id);
  return texts.roomTitle(rect.room ?? rect.id);
}

function drawBackground(app, context) {
  const group = svg("g", { class: "map-background" });
  for (const rect of context.map.rects) {
    const [x, y, width, height] = rect.rect;
    group.append(svg("rect", { x, y, width, height, rx: 14, class: KIND_CLASSES[rect.kind] ?? "map-room" }));
    group.append(svg("text", { x: x + 12, y: y + (rect.kind === "area" ? 22 : 34), class: "map-label " + rect.kind }, mapLabel(app, rect)));
  }
  return group;
}

function mapImage(width, height) {
  return svg("image", { href: MAP_IMAGE, x: 0, y: 0, width, height, preserveAspectRatio: "none", class: "map-image" });
}

function highlight(context, spot, className) {
  const group = svg("g", { class: className });
  for (const [x, y, width, height] of context.spots[spot]?.rects ?? []) group.append(svg("rect", { x, y, width, height, rx: 10 }));
  return group;
}

export const MAP_IMAGE = "assets/map.png";
const MIN_DRAW_SIZE = 12;

export function roomHue(rooms, roomId) {
  const index = Math.max(0, rooms.indexOf(roomId));
  return Math.round((index * 137.508) % 360);
}

export function paintOrder(spots) {
  const items = [];
  for (const [spot, info] of Object.entries(spots)) for (const rect of info.rects) items.push({ spot, room: info.room, rect, custom: Boolean(info.custom) });
  return items.sort((a, b) => b.rect[2] * b.rect[3] - a.rect[2] * a.rect[3]);
}

function drawAllAreas(context, rooms) {
  const group = svg("g", { class: "map-all" });
  for (const item of paintOrder(context.spots)) {
    const hue = roomHue(rooms, item.room);
    const [x, y, width, height] = item.rect;
    group.append(svg("rect", { x, y, width, height, rx: 6, class: "all-box" + (item.custom ? " custom" : ""), style: `fill:hsla(${hue},70%,50%,0.2);stroke:hsl(${hue},70%,42%)`, "pointer-events": "none" }));
  }
  return group;
}

function legend(app, rooms) {
  const { texts } = app.derived();
  return h("div", { class: "map-legend" }, rooms.map((roomId) => h("span", { class: "legend-item" }, h("span", { class: "swatch", style: `background:hsl(${roomHue(rooms, roomId)},70%,45%)` }), texts.roomTitle(roomId))));
}

function draftForm(app, draft) {
  const { document, context } = app.store.state;
  const { texts } = app.derived();
  const language = app.i18n.language;
  const centre = { x: draft.rect[0] + draft.rect[2] / 2, y: draft.rect[1] + draft.rect[3] / 2 };
  const hit = hitSpot(context.spots, centre.x, centre.y);
  const rooms = document.menu.rooms.map((room) => room.id);
  const initial = hit ? context.spots[hit].room : rooms[0];
  const state = { de: "", en: "", room: rooms.includes(initial) ? initial : rooms[0] };
  const create = () => {
    const fallback = state.de.trim() || state.en.trim();
    if (!fallback) {
      app.notify(app.t("area.titleRequired"), "error");
      return;
    }
    const de = state.de.trim() || fallback;
    const en = state.en.trim() || fallback;
    const id = areaSlug(state.en.trim() || state.de.trim(), Object.keys(document.areas ?? {}));
    const result = app.edit((current) => addArea(current, { id, room: state.room, rect: draft.rect }), { origin: "area" });
    if (result.error) return;
    const key = texts.areaTitleKey(id);
    app.edit((current) => ({ document: setText(setText(current, key, "de", de, ""), key, "en", en, "") }), { origin: "text" });
    app.ui.draft = null;
    app.ui.spot = result.spot;
    app.rerender();
  };
  const cancel = () => {
    app.ui.draft = null;
    app.rerender();
  };
  return h("form", { class: "draft-form", onSubmit: (event) => { event.preventDefault(); create(); } },
    h("strong", {}, app.t("area.new")),
    h("span", { class: "hint" }, app.t("area.size", { x: draft.rect[0], y: draft.rect[1], width: draft.rect[2], height: draft.rect[3] })),
    h("label", { class: "field" }, h("span", {}, app.t("area.titleDe")), h("input", { type: "text", autofocus: language === "de", "aria-label": app.t("area.titleDe"), onInput: (event) => { state.de = event.target.value; } })),
    h("label", { class: "field" }, h("span", {}, app.t("area.titleEn")), h("input", { type: "text", "aria-label": app.t("area.titleEn"), onInput: (event) => { state.en = event.target.value; } })),
    h("label", { class: "field" }, h("span", {}, app.t("area.room")), select(rooms.map((roomId) => ({ value: roomId, label: texts.roomTitle(roomId) })), state.room, (value) => { state.room = value; }, { label: app.t("area.room") })),
    h("div", { class: "row" }, h("button", { type: "submit", class: "primary" }, app.t("area.create")), h("button", { type: "button", onClick: cancel }, app.t("action.cancel"))),
  );
}

export function renderMapTab(container, app) {
  const { context } = app.store.state;
  const { entries, texts } = app.derived();
  const [width, height] = context.map.size;
  const rooms = [...new Set([...Object.values(context.spots).map((info) => info.room), ...app.store.state.document.menu.rooms.map((room) => room.id)])];
  const root = svg("svg", { viewBox: `0 0 ${width} ${height}`, width: width * app.ui.zoom, height: height * app.ui.zoom, class: "map-svg" + (app.ui.drawMode ? " drawing" : ""), role: "img", "aria-label": app.t("map.title") });
  const hover = svg("g", { class: "map-hover" });
  const draftLayer = svg("g", { class: "map-draft" });
  const overlay = svg("rect", { x: 0, y: 0, width, height, fill: "transparent" });
  const status = h("div", { class: "map-status" }, app.t(app.ui.drawMode ? "map.drawHint" : "map.hint"));
  const toPoint = (event) => {
    const point = root.createSVGPoint();
    point.x = event.clientX;
    point.y = event.clientY;
    return point.matrixTransform(root.getScreenCTM().inverse());
  };
  const locate = (event) => {
    const local = toPoint(event);
    return hitSpot(context.spots, local.x, local.y);
  };
  const showDraft = (rect) => draftLayer.replaceChildren(svg("rect", { x: rect[0], y: rect[1], width: rect[2], height: rect[3], rx: 6, class: "draft-box" }));
  let anchor = null;
  overlay.addEventListener("mousedown", (event) => {
    if (!app.ui.drawMode || event.button !== 0) return;
    event.preventDefault();
    anchor = toPoint(event);
  });
  overlay.addEventListener("mousemove", (event) => {
    if (app.ui.drawMode) {
      if (anchor) {
        const rect = normaliseRect(anchor, toPoint(event));
        showDraft(rect);
        status.textContent = app.t("area.size", { x: rect[0], y: rect[1], width: rect[2], height: rect[3] });
      }
      return;
    }
    const spot = locate(event);
    hover.replaceChildren(spot ? highlight(context, spot, "hover") : "");
    status.textContent = spot ? `${texts.spotTitle(spot)} · ${app.t("panel.entryCount", { count: visibleAt(entries, spot).length })}` : app.t("map.hint");
  });
  const finish = (event) => {
    if (!anchor) return;
    const rect = normaliseRect(anchor, toPoint(event));
    anchor = null;
    if (rect[2] < MIN_DRAW_SIZE || rect[3] < MIN_DRAW_SIZE) {
      draftLayer.replaceChildren();
      return;
    }
    app.ui.draft = { rect };
    app.ui.drawMode = false;
    app.rerender();
  };
  overlay.addEventListener("mouseup", finish);
  overlay.addEventListener("mouseleave", () => {
    hover.replaceChildren();
    if (anchor) {
      anchor = null;
      draftLayer.replaceChildren();
    }
    status.textContent = app.t(app.ui.drawMode ? "map.drawHint" : "map.hint");
  });
  overlay.addEventListener("click", (event) => {
    if (app.ui.drawMode) return;
    app.ui.spot = locate(event);
    app.rerender();
  });
  root.append(app.ui.mapImage ? mapImage(width, height) : drawBackground(app, context));
  if (app.ui.showAll) root.append(drawAllAreas(context, rooms));
  if (app.ui.spot) root.append(highlight(context, app.ui.spot, "selected"));
  root.append(hover, draftLayer);
  if (app.ui.draft) {
    showDraft(app.ui.draft.rect);
  }
  root.append(overlay);
  const unmapped = Object.entries(context.spots)
    .filter(([spot, info]) => info.rects.length === 0 && visibleAt(entries, spot).length > 0)
    .map(([spot]) => h("button", { type: "button", class: "chip action" + (app.ui.spot === spot ? " active" : ""), onClick: () => { app.ui.spot = spot; app.rerender(); } }, texts.spotTitle(spot)));
  const toolbar = h("div", { class: "map-toolbar" },
    iconButton(app.t("map.zoomOut"), "−", () => zoom(app, 0.8)),
    iconButton(app.t("map.zoomIn"), "+", () => zoom(app, 1.25)),
    iconButton(app.t("map.zoomFit"), "⤢", () => { app.ui.zoom = 0.42; app.rerender(); }),
    h("button", { type: "button", class: "segment" + (app.ui.drawMode ? " active" : ""), "aria-pressed": Boolean(app.ui.drawMode), onClick: () => { app.ui.drawMode = !app.ui.drawMode; app.ui.draft = null; app.rerender(); } }, "▭ " + app.t("map.draw")),
    h("button", { type: "button", class: "segment" + (app.ui.showAll ? " active" : ""), "aria-pressed": Boolean(app.ui.showAll), onClick: () => { app.ui.showAll = !app.ui.showAll; app.rerender(); } }, "◩ " + app.t("map.showAll")),
    status,
  );
  container.append(h("div", { class: "map-layout" + (app.ui.spot ? " detail" : "") },
    h("section", { class: "map-pane" }, toolbar, app.ui.draft ? draftForm(app, app.ui.draft) : null, app.ui.showAll ? legend(app, rooms) : null, h("div", { class: "map-scroll", dataset: { scroll: "map" } }, root), unmapped.length ? h("div", { class: "unmapped" }, h("span", {}, app.t("map.unmapped")), unmapped) : null),
    h("aside", { class: "spot-pane" }, renderSpotPanel(app, app.ui.spot)),
  ));
}

function zoom(app, factor) {
  app.ui.zoom = Math.min(1.2, Math.max(0.15, app.ui.zoom * factor));
  app.rerender();
}
