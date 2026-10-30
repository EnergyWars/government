import { sprintf } from "./format.js";

const SHARED_ROOMS = {
  "shared/reception": "hall",
  "shared/counter": "hall",
  "shared/mailroom": "mail",
  "shared/inspection": "inspection",
};

export function stationRoom(key) {
  return SHARED_ROOMS[key] ?? key.split("/")[0];
}

export function splitSpot(spot) {
  const index = spot.indexOf(":");
  return index < 0 ? { kind: "", target: "" } : { kind: spot.slice(0, index), target: spot.slice(index + 1) };
}

export function createTexts({ translations, context, document, language }) {
  const overrides = document.text_overrides ?? {};
  const stations = context.stations ?? {};
  const departments = new Set(context.departments.map((entry) => entry.id));

  function text(key, code = language) {
    return overrides[key]?.[code] ?? translations[key]?.[code] ?? translations[key]?.en ?? key;
  }

  function baseText(key, code = language) {
    return translations[key]?.[code] ?? translations[key]?.en ?? "";
  }

  function hasKey(key) {
    return key in translations || key in overrides;
  }

  function roomTitle(roomId) {
    return text((departments.has(roomId) ? "DEPT_" : "ROOM_") + roomId.toUpperCase());
  }

  function stationLabel(key) {
    const station = stations[key];
    if (!station) return key;
    const isDepartmentReview = station.kind === "review" && station.department;
    if (station.kind === "signature" || isDepartmentReview) return text(`STATION_${station.department}_${station.kind}`.toUpperCase());
    return text("STATION_" + station.kind.toUpperCase());
  }

  function spotTitle(spot) {
    const { kind, target } = splitSpot(spot);
    switch (kind) {
      case "room":
      case "dept":
        return roomTitle(target);
      case "station":
        return stationLabel(target);
      case "trays":
        return sprintf(text("FMT_SPOT_TRAYS"), stationLabel(target));
      case "tube":
        return sprintf(text("FMT_SPOT_TUBE_STATION"), roomTitle(target));
      case "shredder":
        return sprintf(text("FMT_SPOT_SHREDDER"), roomTitle(target));
      case "lead":
        return sprintf(text("FMT_SPOT_LEAD"), roomTitle(target));
      case "area":
        return hasKey(areaTitleKey(target)) ? text(areaTitleKey(target)) : target;
      default:
        return text("SPOT_" + spot.toUpperCase());
    }
  }

  const areaTitleKey = (id) => "SPOT_AREA_" + id.toUpperCase();

  function spotTitleKey(spot) {
    const { kind, target } = splitSpot(spot);
    if (kind === "area") return areaTitleKey(target);
    return kind === "" ? "SPOT_" + spot.toUpperCase() : null;
  }

  function spotDescriptionKey(spot) {
    const { kind, target } = splitSpot(spot);
    const keys = { room: "ROOM_DESC_" + target.toUpperCase(), dept: "DEPT_DESC_" + target.toUpperCase(), station: "SPOT_DESC_STATION", trays: "SPOT_DESC_TRAYS", tube: "SPOT_DESC_TUBE_STATION", shredder: "SPOT_DESC_DEPT_SHREDDER", lead: "SPOT_DESC_LEAD", area: "SPOT_DESC_AREA" };
    return keys[kind] ?? "SPOT_DESC_" + spot.toUpperCase();
  }

  function spotDescription(spot) {
    return text(spotDescriptionKey(spot));
  }

  const upgradeTitleKey = (id) => "TRACK_" + id.toUpperCase();
  const upgradeDescriptionKey = (id) => "TRACK_DESC_" + id.toUpperCase();

  function entryTitle(entry) {
    switch (entry.kind) {
      case "track": {
        const name = text(upgradeTitleKey(entry.target));
        return entry.roomId ? sprintf(text("FMT_ENTRY_IN_ROOM"), name, roomTitle(entry.roomId)) : name;
      }
      case "desk":
        return sprintf(text(stations[entry.target]?.machine ? "FMT_ENTRY_MACHINE" : "FMT_ENTRY_DESK"), stationLabel(entry.target));
      case "hire":
        return sprintf(text("FMT_ENTRY_HIRE"), stationLabel(entry.target));
      case "reject_pile":
        return sprintf(text("FMT_ENTRY_REJECT_PILE"), stationLabel(entry.target));
      case "staff":
        return text("STAFF_" + entry.target.toUpperCase());
      case "segment": {
        const ends = entry.target.split(">");
        return sprintf(text("FMT_TUBE_SEGMENT"), stationLabel(ends[0]), stationLabel(ends[1]));
      }
      case "storage":
        return text("MAIL_STORAGE_TITLE");
      case "unlock":
        return sprintf(text("FMT_ENTRY_UNLOCK"), roomTitle(entry.target));
      case "rank":
        return sprintf(text("FMT_ENTRY_RANK"), roomTitle(entry.target));
      default:
        return entry.id;
    }
  }

  const topicTitle = (id) => text("TOPIC_" + id.toUpperCase());

  return { areaTitleKey, text, baseText, hasKey, roomTitle, stationLabel, spotTitle, spotTitleKey, spotDescription, spotDescriptionKey, upgradeTitleKey, upgradeDescriptionKey, entryTitle, topicTitle };
}
