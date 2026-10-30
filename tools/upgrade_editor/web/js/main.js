import { api } from "./api.js";
import { createApp } from "./app.js";
import { h } from "./dom.js";
import { LANGUAGES, createI18n, detectLanguage } from "./i18n.js";
import { createStore } from "./store.js";
import { renderChangesTab } from "./views/changesView.js";
import { renderInspector } from "./views/inspector.js";
import { setSelectTexts } from "./views/components.js";
import { MAP_IMAGE, renderMapTab } from "./views/mapView.js";
import { renderMenuTab } from "./views/menuView.js";
import { renderOverviewTab } from "./views/overviewView.js";
import { renderSystemTab } from "./views/systemView.js";

const TABS = { map: renderMapTab, menu: renderMenuTab, overview: renderOverviewTab, system: renderSystemTab, changes: renderChangesTab };

function readStored(key) {
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

function writeStored(key, value) {
  try {
    window.localStorage.setItem(key, value);
  } catch {
    return;
  }
}

function toast(message, tone = "info") {
  const node = h("div", { class: "toast " + tone, role: "status" }, message);
  document.getElementById("toasts").append(node);
  window.setTimeout(() => node.remove(), 4500);
}

async function loadDictionaries() {
  const entries = await Promise.all(LANGUAGES.map(async (code) => [code, await (await fetch(`i18n/${code}.json`)).json()]));
  return Object.fromEntries(entries);
}

async function start() {
  const dictionaries = await loadDictionaries();
  const i18n = createI18n(dictionaries, detectLanguage(readStored("upgrade-editor.language"), navigator.language));
  setSelectTexts((key) => i18n.t(key));
  const THEMES = ["auto", "light", "dark"];
  let theme = THEMES.includes(readStored("upgrade-editor.theme")) ? readStored("upgrade-editor.theme") : "dark";
  const applyTheme = () => {
    if (theme === "auto") document.documentElement.removeAttribute("data-theme");
    else document.documentElement.setAttribute("data-theme", theme);
  };
  applyTheme();
  document.documentElement.lang = i18n.language;
  document.title = i18n.t("app.title");
  let loaded;
  try {
    const [documentPayload, context, translations] = await Promise.all([api.document(), api.context(), api.translations()]);
    loaded = { document: documentPayload.document, original: documentPayload.original ?? documentPayload.document, source: documentPayload.source, context, translations };
  } catch {
    document.getElementById("app").textContent = i18n.t("toast.loadFailed");
    return;
  }
  const store = createStore(loaded);
  const app = createApp({ store, i18n, notify: toast });
  app.ui.mapImage = await new Promise((resolve) => {
    const image = new Image();
    image.onload = () => resolve(true);
    image.onerror = () => resolve(false);
    image.src = MAP_IMAGE;
  });
  let tab = readStored("upgrade-editor.tab");
  if (!TABS[tab]) tab = "map";
  let inspectorHandle = null;

  const root = document.getElementById("app");
  const header = h("header", { class: "topbar" });
  const main = h("main", { class: "content" });
  const inspector = h("aside", { class: "inspector", "aria-label": i18n.t("inspector.parameters") });
  const workspace = h("div", { class: "workspace" }, main, inspector);
  root.append(header, workspace);

  app.setTab = (next) => {
    tab = next;
    writeStored("upgrade-editor.tab", next);
    renderAll();
  };
  app.rerender = () => {
    renderHeader();
    renderMain();
  };
  app.redrawInspector = () => renderInspectorPane();

  async function save() {
    try {
      const result = await api.save(store.state.document);
      store.markSaved(store.state.document, "edited");
      toast(i18n.t("toast.saved", { path: result.path ?? "data/upgrades.edited.json" }));
    } catch (error) {
      toast(error.errors?.length ? i18n.t("error.validation", { count: error.errors.length }) : i18n.t("toast.saveFailed"), "error");
    }
  }

  async function reset() {
    if (!window.confirm(i18n.t("confirm.reset"))) return;
    try {
      const result = await api.reset();
      app.ui.formulaDrafts = {};
      app.ui.tableDrafts = {};
      store.markReset(result.document, "original");
      toast(i18n.t("toast.reset"));
    } catch {
      toast(i18n.t("toast.saveFailed"), "error");
    }
  }

  function canGoBack() {
    return Boolean(store.state.selection?.ref) || (tab === "map" && Boolean(app.ui.spot));
  }

  function goBack() {
    if (store.state.selection?.ref) {
      store.select(null);
      return;
    }
    app.ui.spot = null;
    renderAll();
  }

  function syncDetail() {
    const detail = Boolean(store.state.selection?.ref);
    const was = workspace.classList.contains("detail");
    workspace.classList.toggle("detail", detail);
    if (detail && !was) inspector.scrollTop = 0;
  }

  function renderHeader() {
    const dirty = store.isDirty();
    header.replaceChildren(
      canGoBack() ? h("button", { type: "button", class: "back", onClick: goBack, title: "Esc" }, "← " + i18n.t("toolbar.back")) : null,
      h("h1", {}, i18n.t("app.title")),
      h("nav", { class: "tabs", role: "tablist" }, Object.keys(TABS).map((id) => h("button", { type: "button", role: "tab", class: "tab" + (id === tab ? " active" : ""), "aria-selected": id === tab, onClick: () => app.setTab(id) }, i18n.t("tab." + id)))),
      h("span", { class: "grow" }),
      h("span", { class: "source" + (dirty ? " dirty" : "") }, dirty ? i18n.t("toolbar.dirty") : i18n.t("toolbar.source." + store.state.source)),
      h("button", { type: "button", disabled: !store.canUndo(), onClick: () => store.undo(), title: "Ctrl+Z" }, "↶ " + i18n.t("toolbar.undo")),
      h("button", { type: "button", disabled: !store.canRedo(), onClick: () => store.redo(), title: "Ctrl+Shift+Z" }, "↷ " + i18n.t("toolbar.redo")),
      h("button", { type: "button", class: "primary", disabled: !dirty, onClick: save, title: "Ctrl+S" }, i18n.t("toolbar.save")),
      h("button", { type: "button", onClick: reset }, i18n.t("toolbar.reset")),
      h("select", { "aria-label": i18n.t("toolbar.theme"), onChange: (event) => { theme = event.target.value; writeStored("upgrade-editor.theme", theme); applyTheme(); } },
        THEMES.map((code) => h("option", { value: code, selected: code === theme }, i18n.t("theme." + code)))),
      h("select", { "aria-label": i18n.t("toolbar.language"), onChange: (event) => { i18n.setLanguage(event.target.value); writeStored("upgrade-editor.language", i18n.language); document.documentElement.lang = i18n.language; document.title = i18n.t("app.title"); renderAll(); } },
        LANGUAGES.map((code) => h("option", { value: code, selected: code === i18n.language }, code.toUpperCase()))),
    );
  }

  const savedScroll = new Map();

  function scrollPositions() {
    for (const node of document.querySelectorAll("[data-scroll]")) {
      if (node.offsetParent !== null) savedScroll.set(node.dataset.scroll, [node.dataset.scroll, node.scrollTop, node.scrollLeft]);
    }
    return [...savedScroll.values()];
  }

  function restoreScroll(positions) {
    for (const [key, top, left] of positions) {
      const node = document.querySelector(`[data-scroll="${key}"]`);
      if (node) {
        node.scrollTop = top;
        node.scrollLeft = left;
      }
    }
  }

  function renderMain() {
    const positions = scrollPositions();
    main.replaceChildren();
    TABS[tab](main, app);
    restoreScroll(positions);
  }

  function renderInspectorPane() {
    inspectorHandle = renderInspector(inspector, app);
  }

  function renderAll() {
    syncDetail();
    renderHeader();
    renderMain();
    renderInspectorPane();
  }

  store.subscribe((state, meta) => {
    syncDetail();
    renderHeader();
    if (meta.origin === "selection" && tab !== "map" && tab !== "menu" && tab !== "overview") {
      renderInspectorPane();
      return;
    }
    renderMain();
    if (meta.keepInspector && inspectorHandle) inspectorHandle.refresh();
    else renderInspectorPane();
  });

  window.addEventListener("keydown", (event) => {
    const modifier = event.ctrlKey || event.metaKey;
    const typing = ["INPUT", "TEXTAREA", "SELECT"].includes(document.activeElement?.tagName);
    if (event.key === "Escape" && !typing && canGoBack()) {
      goBack();
    } else if (modifier && event.key.toLowerCase() === "s") {
      event.preventDefault();
      if (store.isDirty()) save();
    } else if (modifier && event.key.toLowerCase() === "z" && !typing) {
      event.preventDefault();
      if (event.shiftKey) store.redo();
      else store.undo();
    }
  });
  window.addEventListener("beforeunload", (event) => {
    if (store.isDirty()) {
      event.preventDefault();
      event.returnValue = "";
    }
  });
  renderAll();
}

start();
