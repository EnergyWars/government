import test from "node:test";
import assert from "node:assert/strict";
import { loadReal } from "./data.js";
import { createTexts, splitSpot, stationRoom } from "../../web/js/texts.js";
import { compact, decimal, percent, significant, sprintf } from "../../web/js/format.js";

const { document, context, translations } = loadReal();
const build = (language, override = document) => createTexts({ translations, context, document: override, language });

test("sprintf supports strings, integers and percent signs", () => {
  assert.equal(sprintf("%s · %s", "a", "b"), "a · b");
  assert.equal(sprintf("%d%%", 7.9), "7%");
  assert.equal(sprintf("%s", undefined), "");
});

test("number formatting", () => {
  assert.equal(compact(1500, "de"), "1,5K");
  assert.equal(compact(1500, "en"), "1.5K");
  assert.equal(compact(2.5e9, "en"), "2.5B");
  assert.equal(compact(12, "en"), "12");
  assert.equal(compact(123.4, "en"), "123");
  assert.equal(compact(-2000, "en"), "-2K");
  assert.equal(compact(Number.NaN), "–");
  assert.equal(compact(3e15, "en"), "3Q");
  assert.equal(decimal(1.5, 2, "de"), "1,5");
  assert.equal(decimal(2, 2, "en"), "2");
  assert.equal(decimal(Infinity, 2), "–");
  assert.equal(percent(12.345, "en"), "12.3 %");
  assert.equal(percent(150, "en"), "150 %");
  assert.equal(percent(0.5, "de"), "0,5 %");
  assert.equal(percent(Number.NaN), "–");
  assert.equal(significant(0, "en"), "0");
  assert.equal(significant(1234.5, "en"), "1235");
  assert.equal(significant(12.345, "en"), "12.35");
  assert.equal(significant(0.5, "en"), "0.5");
  assert.equal(significant(0.0004, "en"), "4.00e-4");
  assert.equal(significant(Number.NaN), "–");
});

test("room, spot and station helpers", () => {
  assert.deepEqual(splitSpot("dept:tax_services"), { kind: "dept", target: "tax_services" });
  assert.deepEqual(splitSpot("player"), { kind: "", target: "" });
  assert.equal(stationRoom("shared/reception"), "hall");
  assert.equal(stationRoom("shared/mailroom"), "mail");
  assert.equal(stationRoom("shared/inspection"), "inspection");
  assert.equal(stationRoom("tax_services/review"), "tax_services");
});

test("texts come in german and english", () => {
  assert.equal(build("de").upgradeTitleKey("briefcase"), "TRACK_BRIEFCASE");
  assert.equal(build("de").text("TRACK_BRIEFCASE"), "Größere Aktentasche");
  assert.equal(build("en").text("TRACK_BRIEFCASE"), "Bigger briefcase");
  assert.equal(build("de").text("TRACK_BRIEFCASE", "en"), "Bigger briefcase");
  assert.equal(build("de").baseText("TRACK_BRIEFCASE", "en"), "Bigger briefcase");
});

test("missing translations fall back to english and then to the key", () => {
  const sparse = createTexts({ translations: { A: { en: "Only english" } }, context, document, language: "de" });
  assert.equal(sparse.text("A"), "Only english");
  assert.equal(sparse.text("B"), "B");
  assert.equal(sparse.baseText("B"), "");
  assert.equal(sparse.hasKey("A"), true);
  assert.equal(sparse.hasKey("B"), false);
});

test("overrides win over the game texts", () => {
  const edited = structuredClone(document);
  edited.text_overrides = { TRACK_BRIEFCASE: { de: "Koffer" } };
  assert.equal(build("de", edited).text("TRACK_BRIEFCASE"), "Koffer");
  assert.equal(build("en", edited).text("TRACK_BRIEFCASE"), "Bigger briefcase");
  assert.equal(build("de", edited).hasKey("TRACK_BRIEFCASE"), true);
});

test("room and station titles", () => {
  const texts = build("de");
  assert.equal(texts.roomTitle("hall"), translations.ROOM_HALL.de);
  assert.equal(texts.roomTitle("tax_services"), translations.DEPT_TAX_SERVICES.de);
  assert.equal(texts.stationLabel("tax_services/signature"), translations.STATION_TAX_SERVICES_SIGNATURE.de);
  assert.equal(texts.stationLabel("shared/reception"), translations.STATION_RECEPTION.de);
  assert.equal(texts.stationLabel("ghost"), "ghost");
  assert.equal(texts.topicTitle("speed"), translations.TOPIC_SPEED.de);
});

test("spot titles by kind", () => {
  const texts = build("en");
  assert.equal(texts.spotTitle("room:hall"), translations.ROOM_HALL.en);
  assert.equal(texts.spotTitle("dept:housing"), translations.DEPT_HOUSING.en);
  assert.equal(texts.spotTitle("station:tax_services/review"), texts.stationLabel("tax_services/review"));
  assert.equal(texts.spotTitle("trays:tax_services/review"), sprintfOf("FMT_SPOT_TRAYS", texts.stationLabel("tax_services/review")));
  assert.equal(texts.spotTitle("tube:hall"), sprintfOf("FMT_SPOT_TUBE_STATION", texts.roomTitle("hall")));
  assert.equal(texts.spotTitle("shredder:housing"), sprintfOf("FMT_SPOT_SHREDDER", texts.roomTitle("housing")));
  assert.equal(texts.spotTitle("lead:intake"), sprintfOf("FMT_SPOT_LEAD", texts.roomTitle("intake")));
  assert.equal(texts.spotTitle("tickets"), translations.SPOT_TICKETS.en);
  assert.equal(texts.spotTitleKey("tickets"), "SPOT_TICKETS");
  assert.equal(texts.spotTitleKey("dept:housing"), null);
});

function sprintfOf(key, ...values) {
  return sprintf(translations[key].en, ...values);
}

test("spot descriptions", () => {
  const texts = build("de");
  assert.equal(texts.spotDescriptionKey("room:hall"), "ROOM_DESC_HALL");
  assert.equal(texts.spotDescriptionKey("dept:housing"), "DEPT_DESC_HOUSING");
  assert.equal(texts.spotDescriptionKey("station:x"), "SPOT_DESC_STATION");
  assert.equal(texts.spotDescriptionKey("trays:x"), "SPOT_DESC_TRAYS");
  assert.equal(texts.spotDescriptionKey("tube:x"), "SPOT_DESC_TUBE_STATION");
  assert.equal(texts.spotDescriptionKey("shredder:x"), "SPOT_DESC_DEPT_SHREDDER");
  assert.equal(texts.spotDescriptionKey("lead:x"), "SPOT_DESC_LEAD");
  assert.equal(texts.spotDescriptionKey("tickets"), "SPOT_DESC_TICKETS");
  assert.equal(texts.spotDescription("tickets"), translations.SPOT_DESC_TICKETS.de);
});

test("entry titles by kind", () => {
  const texts = build("en");
  assert.equal(texts.entryTitle({ kind: "track", target: "briefcase", roomId: "" }), "Bigger briefcase");
  assert.equal(texts.entryTitle({ kind: "track", target: "room_speed", roomId: "hall" }), sprintf("%s · %s", translations.TRACK_ROOM_SPEED.en, translations.ROOM_HALL.en));
  const review = "tax_services/review";
  assert.equal(texts.entryTitle({ kind: "desk", target: review }), sprintf(translations.FMT_ENTRY_DESK.en, texts.stationLabel(review)));
  assert.equal(texts.entryTitle({ kind: "desk", target: "tax_services/signature" }), sprintf(translations.FMT_ENTRY_MACHINE.en, texts.stationLabel("tax_services/signature")));
  assert.equal(texts.entryTitle({ kind: "hire", target: review }), sprintf(translations.FMT_ENTRY_HIRE.en, texts.stationLabel(review)));
  assert.equal(texts.entryTitle({ kind: "reject_pile", target: review }), sprintf(translations.FMT_ENTRY_REJECT_PILE.en, texts.stationLabel(review)));
  assert.equal(texts.entryTitle({ kind: "staff", target: "runners" }), translations.STAFF_RUNNERS.en);
  assert.equal(texts.entryTitle({ kind: "segment", target: "shared/reception>tax_services/review" }), sprintf(translations.FMT_TUBE_SEGMENT.en, texts.stationLabel("shared/reception"), texts.stationLabel(review)));
  assert.equal(texts.entryTitle({ kind: "storage", target: "x" }), translations.MAIL_STORAGE_TITLE.en);
  assert.equal(texts.entryTitle({ kind: "unlock", target: "housing" }), sprintf(translations.FMT_ENTRY_UNLOCK.en, texts.roomTitle("housing")));
  assert.equal(texts.entryTitle({ kind: "rank", target: "housing" }), sprintf(translations.FMT_ENTRY_RANK.en, texts.roomTitle("housing")));
  assert.equal(texts.entryTitle({ kind: "mystery", id: "m" }), "m");
});

test("custom area titles come from overrides", () => {
  const edited = structuredClone(document);
  edited.text_overrides = { SPOT_AREA_LAB: { de: "Labor", en: "Lab" } };
  assert.equal(build("de", edited).spotTitle("area:lab"), "Labor");
  assert.equal(build("en", edited).spotTitle("area:lab"), "Lab");
  assert.equal(build("de").spotTitle("area:lab"), "lab");
  assert.equal(build("de").spotTitleKey("area:lab"), "SPOT_AREA_LAB");
  assert.equal(build("de").spotDescriptionKey("area:lab"), "SPOT_DESC_AREA");
});
