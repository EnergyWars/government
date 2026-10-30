const MIME = "application/x-upgrade-editor";
let current = null;

export function currentDrag() {
  return current;
}

export function makeDraggable(element, payload, handle = element) {
  handle.draggable = true;
  handle.addEventListener("dragstart", (event) => {
    current = payload;
    event.dataTransfer.effectAllowed = "move";
    event.dataTransfer.setData(MIME, JSON.stringify(payload));
    element.classList.add("dragging");
  });
  handle.addEventListener("dragend", () => {
    current = null;
    element.classList.remove("dragging");
    document.querySelectorAll(".drop-before, .drop-after, .drop-into").forEach((node) => node.classList.remove("drop-before", "drop-after", "drop-into"));
  });
}

function clearMarks(element) {
  element.classList.remove("drop-before", "drop-after", "drop-into");
}

export function dropItem(element, { accept, onDrop, index, axis = "y" }) {
  element.addEventListener("dragover", (event) => {
    if (!current || !accept(current)) return;
    event.preventDefault();
    event.stopPropagation();
    const after = isAfter(element, event, axis);
    element.classList.toggle("drop-before", !after);
    element.classList.toggle("drop-after", after);
  });
  element.addEventListener("dragleave", () => clearMarks(element));
  element.addEventListener("drop", (event) => {
    if (!current || !accept(current)) return;
    event.preventDefault();
    event.stopPropagation();
    const after = isAfter(element, event, axis);
    clearMarks(element);
    onDrop(current, index + (after ? 1 : 0));
  });
}

export function dropInto(element, { accept, onDrop }) {
  element.addEventListener("dragover", (event) => {
    if (!current || !accept(current)) return;
    event.preventDefault();
    element.classList.add("drop-into");
  });
  element.addEventListener("dragleave", (event) => {
    if (!element.contains(event.relatedTarget)) clearMarks(element);
  });
  element.addEventListener("drop", (event) => {
    if (!current || !accept(current)) return;
    event.preventDefault();
    clearMarks(element);
    onDrop(current);
  });
}

export function isAfter(element, event, axis) {
  const box = element.getBoundingClientRect();
  return axis === "y" ? event.clientY > box.top + box.height / 2 : event.clientX > box.left + box.width / 2;
}
