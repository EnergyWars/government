import { compact, decimal, percent } from "../format.js";
import { h } from "../dom.js";
import { makeDraggable } from "../dnd.js";
import { filterOptions, stepActive } from "../search.js";

export function chip(text, tone = "", title = "") {
  return h("span", { class: "chip " + tone, title }, text);
}

export function collapsible(app, id, title, content, { open = true } = {}) {
  const state = (app.ui.sections ??= {});
  const details = h("details", { class: "fold", open: state[id] ?? open }, h("summary", {}, h("h3", {}, title)), h("div", { class: "fold-body" }, content));
  details.addEventListener("toggle", () => { state[id] = details.open; });
  return details;
}

export function iconButton(label, glyph, onClick, extra = {}) {
  return h("button", { type: "button", class: "icon-button " + (extra.class ?? ""), title: label, "aria-label": label, disabled: extra.disabled, onClick }, glyph);
}

export function formatNumber(app, value) {
  return compact(value, app.i18n.language);
}

export function formatFactor(app, value) {
  if (value === null || value === undefined) return "–";
  return decimal(value, value >= 100 ? 0 : value >= 10 ? 1 : 2, app.i18n.language);
}

export function factorBar(factor) {
  const scale = factor && factor > 0 ? Math.min(1, Math.max(0.04, (Math.log10(factor) + 3) / 6)) : 0;
  return h("span", { class: "factor-bar" }, h("span", { style: `width:${(scale * 100).toFixed(0)}%` }));
}

export function factorBlock(app, step, totals) {
  const language = app.i18n.language;
  const body = [
    h("span", { class: "factor-main" }, formatFactor(app, step?.factor ?? null)),
    h("span", { class: "factor-unit" }, app.t("metric.factorUnit")),
    factorBar(step?.factor ?? null),
  ];
  const detail = totals?.factor === null || totals?.factor === undefined ? "" : app.t("metric.factorTotal", { value: formatFactor(app, totals.factor) });
  const gain = step?.gain === null || step?.gain === undefined ? "" : app.t("metric.gainFirst", { value: percent(step.gain * 100, language) });
  return h("div", { class: "factor", title: app.t("metric.factorHelp") }, h("div", { class: "factor-line" }, body), h("div", { class: "factor-sub" }, [gain, detail].filter(Boolean).join(" · ")));
}

export function requirementChips(app, definition) {
  const { texts } = app.derived();
  const chips = [];
  for (const [id, level] of Object.entries(definition?.requires ?? {})) {
    chips.push(chip(app.t("chip.requires", { name: texts.text(texts.upgradeTitleKey(id)), level }), "warn"));
  }
  if (definition?.reputation) chips.push(chip(app.t("chip.reputation", { value: compact(definition.reputation, app.i18n.language) }), "warn"));
  return chips;
}

export function entryCard(app, entry, options = {}) {
  const { texts } = app.derived();
  const state = app.store.state;
  const definition = entry.kind === "track" ? state.document.upgrades[entry.target] : null;
  const metrics = app.metrics(entry);
  const selected = state.selection?.ref === entry.id;
  const card = h("div", { class: "card" + (selected ? " selected" : "") + (entry.fixed ? " fixed" : ""), dataset: { ref: entry.id }, onClick: () => app.store.select({ ref: entry.id }) });
  const handle = h("span", { class: "handle", title: app.t("action.drag") }, "⠿");
  makeDraggable(card, { type: "entry", ref: entry.id, from: { room: entry.room, spot: entry.spot, group: entry.group ?? "" } }, handle);
  const actions = h("div", { class: "card-actions" },
    options.onUp ? iconButton(app.t("action.up"), "▲", (event) => { event.stopPropagation(); options.onUp(); }) : null,
    options.onDown ? iconButton(app.t("action.down"), "▼", (event) => { event.stopPropagation(); options.onDown(); }) : null,
    options.onRemove ? iconButton(app.t("action.remove"), "✕", (event) => { event.stopPropagation(); options.onRemove(); }, { class: "danger" }) : null,
  );
  card.append(h("div", { class: "card-head" }, handle, h("div", { class: "card-title" }, texts.entryTitle(entry), entry.fixed ? h("span", { class: "lock", title: app.t("hint.fixedEntry") }, " 🔒") : null), actions));
  const chips = [chip(texts.topicTitle(entry.topic), "topic")];
  if (metrics) chips.push(chip(app.t(metrics.single ? "chip.single" : "chip.levels", { max: metrics.max }), ""));
  chips.push(...requirementChips(app, definition));
  card.append(h("div", { class: "chips" }, chips));
  if (metrics) card.append(metricsRow(app, metrics));
  return card;
}

export function metricsRow(app, metrics) {
  return h("div", { class: "metrics" },
    h("div", { class: "cost" },
      h("span", { class: "label" }, app.t("metric.cost")),
      h("span", {}, `${formatNumber(app, metrics.first?.cost ?? 0)} → ${formatNumber(app, metrics.lastCost)}`),
      h("span", { class: "label" }, app.t("metric.total")),
      h("span", {}, formatNumber(app, metrics.totals.cost)),
    ),
    factorBlock(app, metrics.first, metrics.totals),
  );
}

let selectTexts = (key) => key;

export function setSelectTexts(translate) {
  selectTexts = translate;
}

export function select(options, value, onChange, extra = {}) {
  let current = value;
  let active = -1;
  let shown = [];
  const labelOf = (id) => options.find((option) => option.value === id)?.label ?? "";
  const root = h("div", { class: "combo " + (extra.class ?? "") });
  const caption = h("span", { class: "combo-label" }, labelOf(current));
  const button = h("button", { type: "button", class: "combo-button", "aria-haspopup": "listbox", "aria-expanded": "false", "aria-label": extra.label, title: extra.label }, caption, h("span", { class: "combo-arrow", "aria-hidden": "true" }, "▾"));
  const search = h("input", { type: "search", class: "combo-search", autocomplete: "off", spellcheck: false, "aria-label": extra.label, placeholder: selectTexts("select.search") });
  const list = h("ul", { class: "combo-list", role: "listbox" });
  const panel = h("div", { class: "combo-panel", hidden: true }, search, list);
  root.append(button, panel);

  const draw = () => {
    shown = filterOptions(options, search.value);
    if (active >= shown.length) active = shown.length - 1;
    list.replaceChildren(...(shown.length === 0
      ? [h("li", { class: "combo-empty" }, selectTexts("select.empty"))]
      : shown.map(({ option }, position) => h("li", { class: "combo-option" + (position === active ? " active" : "") + (option.value === current ? " chosen" : ""), role: "option", "aria-selected": option.value === current ? "true" : "false", onMouseDown: (event) => { event.preventDefault(); choose(option); }, onMouseMove: () => { if (active !== position) { active = position; mark(); } } }, option.label))));
    list.querySelector(".active")?.scrollIntoView({ block: "nearest" });
  };
  const mark = () => {
    list.querySelectorAll(".combo-option").forEach((node, position) => node.classList.toggle("active", position === active));
    list.querySelector(".active")?.scrollIntoView({ block: "nearest" });
  };
  const outside = (event) => {
    if (!root.isConnected || !root.contains(event.target)) close();
  };
  const open = () => {
    if (!panel.hidden) return;
    panel.hidden = false;
    button.setAttribute("aria-expanded", "true");
    search.value = "";
    shown = filterOptions(options, "");
    active = Math.max(0, shown.findIndex(({ option }) => option.value === current));
    draw();
    document.addEventListener("mousedown", outside, true);
    search.focus();
  };
  function close() {
    panel.hidden = true;
    button.setAttribute("aria-expanded", "false");
    document.removeEventListener("mousedown", outside, true);
  }
  function choose(option) {
    const changed = option.value !== current;
    current = option.value;
    caption.textContent = option.label;
    close();
    button.focus();
    if (changed) onChange(option.value);
  }

  button.addEventListener("click", () => (panel.hidden ? open() : close()));
  button.addEventListener("keydown", (event) => {
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      open();
    }
  });
  search.addEventListener("input", () => {
    active = 0;
    draw();
  });
  search.addEventListener("keydown", (event) => {
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      active = stepActive(active, event.key === "ArrowDown" ? 1 : -1, shown.length);
      mark();
    } else if (event.key === "Enter") {
      event.preventDefault();
      if (shown[active]) choose(shown[active].option);
    } else if (event.key === "Escape") {
      event.preventDefault();
      event.stopPropagation();
      close();
      button.focus();
    } else if (event.key === "Tab") {
      close();
    }
  });
  Object.defineProperty(root, "value", {
    get: () => current,
    set: (next) => {
      current = next;
      caption.textContent = labelOf(next);
    },
  });
  return root;
}
