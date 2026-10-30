export const FALLBACK_LANGUAGE = "en";
export const LANGUAGES = ["de", "en"];

export function createI18n(dictionaries, language = "de") {
  let current = LANGUAGES.includes(language) ? language : FALLBACK_LANGUAGE;
  const lookup = (key, code) => dictionaries[code]?.[key];
  return {
    get language() {
      return current;
    },
    setLanguage(code) {
      current = LANGUAGES.includes(code) ? code : FALLBACK_LANGUAGE;
    },
    t(key, params = {}) {
      const template = lookup(key, current) ?? lookup(key, FALLBACK_LANGUAGE) ?? key;
      return template.replace(/\{(\w+)\}/g, (match, name) => (name in params ? String(params[name]) : match));
    },
    has(key) {
      return lookup(key, current) !== undefined || lookup(key, FALLBACK_LANGUAGE) !== undefined;
    },
  };
}

export function detectLanguage(stored, navigatorLanguage) {
  if (LANGUAGES.includes(stored)) return stored;
  return String(navigatorLanguage ?? "").toLowerCase().startsWith("en") ? "en" : "de";
}
