export function h(tag, props = {}, ...children) {
  const element = document.createElement(tag);
  for (const [name, value] of Object.entries(props ?? {})) {
    if (value === undefined || value === null || value === false) continue;
    if (name === "class") element.className = value;
    else if (name === "dataset") Object.assign(element.dataset, value);
    else if (name === "style") element.style.cssText = value;
    else if (name.startsWith("on")) element.addEventListener(name.slice(2).toLowerCase(), value);
    else if (name in element && name !== "list") element[name] = value;
    else element.setAttribute(name, value === true ? "" : value);
  }
  append(element, children);
  return element;
}

export function append(element, children) {
  for (const child of children.flat(Infinity)) {
    if (child === null || child === undefined || child === false) continue;
    element.append(child instanceof Node ? child : document.createTextNode(String(child)));
  }
  return element;
}

export function clear(element) {
  element.replaceChildren();
  return element;
}

export function svg(tag, props = {}, ...children) {
  const element = document.createElementNS("http://www.w3.org/2000/svg", tag);
  for (const [name, value] of Object.entries(props)) {
    if (value === undefined || value === null) continue;
    if (name.startsWith("on")) element.addEventListener(name.slice(2).toLowerCase(), value);
    else element.setAttribute(name, value);
  }
  append(element, children);
  return element;
}
