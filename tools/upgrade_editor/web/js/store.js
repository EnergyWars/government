import { withAreas } from "./model.js";

const HISTORY_LIMIT = 100;

export function createStore(initial) {
  const listeners = new Set();
  const state = {
    document: initial.document,
    original: initial.original,
    source: initial.source,
    savedJson: JSON.stringify(initial.document),
    baseContext: initial.context,
    translations: initial.translations,
    past: [],
    future: [],
    selection: null,
    errors: [],
  };

  Object.defineProperty(state, "context", { get: () => withAreas(state.baseContext, state.document), enumerable: true });

  function notify(meta = {}) {
    for (const listener of listeners) listener(state, meta);
  }

  return {
    state,
    subscribe(listener) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    commit(document, meta = {}) {
      if (document === state.document) return;
      state.past.push(state.document);
      if (state.past.length > HISTORY_LIMIT) state.past.shift();
      state.future = [];
      state.document = document;
      notify(meta);
    },
    undo() {
      if (state.past.length === 0) return false;
      state.future.push(state.document);
      state.document = state.past.pop();
      notify({ origin: "history" });
      return true;
    },
    redo() {
      if (state.future.length === 0) return false;
      state.past.push(state.document);
      state.document = state.future.pop();
      notify({ origin: "history" });
      return true;
    },
    select(selection, meta = {}) {
      state.selection = selection;
      notify({ origin: "selection", ...meta });
    },
    setErrors(errors) {
      state.errors = errors;
      notify({ origin: "errors" });
    },
    markSaved(document, source) {
      state.document = document;
      state.source = source;
      state.savedJson = JSON.stringify(document);
      notify({ origin: "saved" });
    },
    markReset(document, source) {
      state.past = [];
      state.future = [];
      state.document = document;
      state.source = source;
      state.savedJson = JSON.stringify(document);
      notify({ origin: "saved" });
    },
    isDirty() {
      return JSON.stringify(state.document) !== state.savedJson;
    },
    canUndo: () => state.past.length > 0,
    canRedo: () => state.future.length > 0,
  };
}
