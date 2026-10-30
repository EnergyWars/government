import test from "node:test";
import assert from "node:assert/strict";
import { createStore } from "../../web/js/store.js";

const create = () => createStore({ document: { value: 1 }, original: { value: 1 }, source: "original", context: {}, translations: {} });

test("commit pushes history and notifies", () => {
  const store = create();
  const seen = [];
  store.subscribe((state, meta) => seen.push([state.document.value, meta.origin]));
  store.commit({ value: 2 }, { origin: "inspector" });
  assert.deepEqual(seen, [[2, "inspector"]]);
  assert.equal(store.canUndo(), true);
  assert.equal(store.isDirty(), true);
});

test("committing the same document is ignored", () => {
  const store = create();
  store.commit(store.state.document);
  assert.equal(store.canUndo(), false);
  assert.equal(store.isDirty(), false);
});

test("undo and redo walk the history", () => {
  const store = create();
  store.commit({ value: 2 });
  store.commit({ value: 3 });
  assert.equal(store.undo(), true);
  assert.equal(store.state.document.value, 2);
  assert.equal(store.canRedo(), true);
  assert.equal(store.redo(), true);
  assert.equal(store.state.document.value, 3);
  assert.equal(store.redo(), false);
  store.undo();
  store.undo();
  assert.equal(store.undo(), false);
  assert.equal(store.isDirty(), false);
});

test("a new commit clears the redo stack", () => {
  const store = create();
  store.commit({ value: 2 });
  store.undo();
  store.commit({ value: 5 });
  assert.equal(store.canRedo(), false);
});

test("history is limited", () => {
  const store = create();
  for (let value = 2; value < 200; value += 1) store.commit({ value });
  assert.equal(store.state.past.length, 100);
});

test("saving marks the document clean and keeps the history", () => {
  const store = create();
  store.commit({ value: 2 });
  store.markSaved({ value: 2 }, "edited");
  assert.equal(store.isDirty(), false);
  assert.equal(store.state.source, "edited");
  assert.equal(store.canUndo(), true);
});

test("reset clears the history", () => {
  const store = create();
  store.commit({ value: 2 });
  store.markReset({ value: 1 }, "original");
  assert.equal(store.canUndo(), false);
  assert.equal(store.canRedo(), false);
  assert.equal(store.isDirty(), false);
});

test("selection and errors notify with their origin", () => {
  const store = create();
  const origins = [];
  const unsubscribe = store.subscribe((state, meta) => origins.push(meta.origin));
  store.select({ ref: "track:a" });
  store.setErrors([{ code: "X" }]);
  unsubscribe();
  store.select(null);
  assert.deepEqual(origins, ["selection", "errors"]);
  assert.equal(store.state.errors.length, 1);
});
