import copy

SCHEMA = 1
CURVES = ("linear", "decay", "unlock", "unlock_decay", "milestone", "chance")
FLOAT_FIELDS = ("cost", "growth", "base", "step", "rate", "neutral", "reputation")
INT_FIELDS = ("max", "price_offset")
TEMPLATE_SPOTS = ("@room",)


def parse_ref(ref):
    kind, _, target = ref.partition(":")
    if kind != "track":
        return None, ""
    upgrade_id, _, room_id = target.partition("@")
    return upgrade_id, room_id


def is_room_upgrade(definition):
    return "rooms" in definition


def iter_groups(document):
    for room in document.get("menu", {}).get("rooms", []):
        for group in room.get("groups", []):
            yield room["id"], group


def group_id(group):
    return group.get("id", "") if isinstance(group, dict) else ""


def group_key(group):
    return group["spot"] + ("#" + group["id"] if group.get("id") else "")


def placements(document):
    result = {}
    for room_id, group in iter_groups(document):
        for index, ref in enumerate(group.get("entries", [])):
            result.setdefault(ref, []).append((room_id, group["spot"], index))
    return result


def topic_of_items(document):
    result = {}
    for topic in document.get("menu", {}).get("topics", []):
        for ref in topic.get("items", []):
            result.setdefault(ref, []).append(topic["id"])
    return result


def normalise(document):
    result = copy.deepcopy(document)
    result.setdefault("system", {})
    result.setdefault("text_overrides", {})
    topics = topic_of_items(result)
    placed = placements(result)
    for upgrade_id, definition in result.get("upgrades", {}).items():
        _normalise_numbers(definition)
        topic_ids = topics.get("track:" + upgrade_id, [])
        if topic_ids:
            definition["topic"] = topic_ids[0]
        if is_room_upgrade(definition):
            _normalise_room_upgrade(definition, upgrade_id, placed)
        else:
            _normalise_global_upgrade(definition, upgrade_id, placed)
    return result


def _normalise_numbers(definition):
    for field in FLOAT_FIELDS:
        if field in definition:
            definition[field] = float(definition[field])
    for field in INT_FIELDS:
        if field in definition:
            definition[field] = int(definition[field])
    if "requires" in definition:
        definition["requires"] = {key: int(value) for key, value in definition["requires"].items()}
    for model_key, table_key in (("cost_model", "levels"), ("value_model", "increments")):
        table = definition.get(model_key, {}).get(table_key) if isinstance(definition.get(model_key), dict) else None
        if isinstance(table, list):
            definition[model_key][table_key] = [float(value) for value in table]


def _normalise_room_upgrade(definition, upgrade_id, placed):
    rooms = []
    for ref, spots in placed.items():
        found_id, room_id = parse_ref(ref)
        if found_id == upgrade_id and room_id:
            rooms.append((spots[0][0], room_id))
    kept = [room for room in definition.get("rooms", []) if any(room == entry[1] for entry in rooms)]
    for _, room_id in rooms:
        if room_id not in kept:
            kept.append(room_id)
    definition["rooms"] = kept
    definition.pop("enabled", None)


def _normalise_global_upgrade(definition, upgrade_id, placed):
    spots = placed.get("track:" + upgrade_id, [])
    if spots:
        if all(entry[1] != definition.get("spot") for entry in spots):
            definition["spot"] = spots[0][1]
        definition.pop("enabled", None)
    else:
        definition["enabled"] = False
