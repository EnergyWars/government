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
  root.append(header, h("div", { class: "workspace" }, main, inspector));

  app.setTab = (next) => {
    tab = next;
    writeStored("upgrade-editor.tab", next);
    renderAll();
  };
  app.rerender = () => renderMain();
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

  function renderHeader() {
    const dirty = store.isDirty();
    header.replaceChildren(
      h("h1", {}, i18n.t("app.title")),
      h("nav", { class: "tabs", role: "tablist" }, Object.keys(TABS).map((id) => h("button", { type: "button", role: "tab", class: "tab" + (id === tab ? " active" : ""), "aria-selected": id === tab, onClick: () => app.setTab(id) }, i18n.t("tab." + id)))),
      h("span", { class: "grow" }),
      h("span", { class: "source" + (dirty ? " dirty" : "") }, dirty ? i18n.t("toolbar.dirty") : i18n.t("toolbar.source." + store.state.source)),
      h("button", { type: "button", disabled: !store.canUndo(), onClick: () => store.undo(), title: "Ctrl+Z" }, "↶ " + i18n.t("toolbar.undo")),
      h("button", { type: "button", disabled: !store.canRedo(), onClick: () => store.redo(), title: "Ctrl+Shift+Z" }, "↷ " + i18n.t("toolbar.redo")),
      h("button", { type: "button", class: "primary", disabled: !dirty, onClick: save, title: "Ctrl+S" }, i18n.t("toolbar.save")),
      h("button", { type: "button", onClick: reset }, i18n.t("toolbar.reset")),
      h("select", { "aria-label": i18n.t("toolbar.language"), onChange: (event) => { i18n.setLanguage(event.target.value); writeStored("upgrade-editor.language", i18n.language); document.documentElement.lang = i18n.language; document.title = i18n.t("app.title"); renderAll(); } },
        LANGUAGES.map((code) => h("option", { value: code, selected: code === i18n.language }, code.toUpperCase()))),
    );
  }

  function scrollPositions() {
    return [...document.querySelectorAll("[data-scroll]")].map((node) => [node.dataset.scroll, node.scrollTop, node.scrollLeft]);
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
    renderHeader();
    renderMain();
    renderInspectorPane();
  }

  store.subscribe((state, meta) => {
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
    if (modifier && event.key.toLowerCase() === "s") {
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
