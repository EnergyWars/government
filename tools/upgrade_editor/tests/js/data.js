import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../../../..");
const read = (relative) => JSON.parse(readFileSync(path.join(root, relative), "utf8"));

export function loadReal() {
  return {
    document: read("data/upgrades.json"),
    context: read("tools/upgrade_editor/data/app_context.json"),
    translations: read("tools/upgrade_editor/data/game_translations.json"),
  };
}

export function consistency(document, context) {
  const problems = [];
  const seen = new Map();
  for (const room of document.menu.rooms) {
    for (const group of room.groups) {
      for (const ref of group.entries) {
        if (seen.has(ref)) problems.push("duplicate " + ref);
        seen.set(ref, { room: room.id, spot: group.spot });
      }
    }
  }
  for (const [id, definition] of Object.entries(document.upgrades)) {
    if (Array.isArray(definition.rooms)) {
      for (const roomId of definition.rooms) if (!seen.has(`track:${id}@${roomId}`)) problems.push(`missing ${id}@${roomId}`);
    } else if (seen.has("track:" + id)) {
      if (seen.get("track:" + id).spot !== definition.spot) problems.push("spot " + id);
      if (definition.enabled === false) problems.push("enabled " + id);
    } else if (definition.enabled !== false) {
      problems.push("unplaced " + id);
    }
  }
  for (const ref of seen.keys()) {
    const match = /^track:([^@]+)(?:@(.+))?$/.exec(ref);
    if (match && !document.upgrades[match[1]]) problems.push("unknown " + ref);
    if (match && match[2] && !document.upgrades[match[1]].rooms.includes(match[2])) problems.push("not listed " + ref);
  }
  const topics = new Map();
  for (const topic of document.menu.topics) for (const item of topic.items) topics.set(item, topic.id);
  for (const [id, definition] of Object.entries(document.upgrades)) {
    if (topics.get("track:" + id) !== definition.topic) problems.push("topic " + id);
  }
  return problems;
}
