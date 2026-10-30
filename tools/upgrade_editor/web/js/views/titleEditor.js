import { h } from "../dom.js";
import { setText } from "../model.js";
import { iconButton } from "./components.js";

export function titleEditor(app, key, currentText) {
  const holder = h("div", { class: "title-editor" });
  const show = () => {
    holder.replaceChildren(
      h("h3", {}, currentText),
      iconButton(app.t("action.rename"), "✎", (event) => { event.stopPropagation(); edit(); }),
    );
  };
  const edit = () => {
    const language = app.i18n.language;
    const { texts } = app.derived();
    const input = h("input", { type: "text", value: currentText, "aria-label": app.t("action.rename") });
    const finish = (commit) => {
      const value = input.value.trim();
      if (commit && value && value !== currentText) {
        app.edit((document) => ({ document: setText(document, key, language, value, texts.baseText(key, language)) }), { origin: "text" });
      } else {
        show();
      }
    };
    input.addEventListener("keydown", (event) => {
      if (event.key === "Enter") finish(true);
      if (event.key === "Escape") finish(false);
    });
    input.addEventListener("blur", () => finish(true));
    holder.replaceChildren(input);
    input.focus();
    input.select();
  };
  show();
  return holder;
}
