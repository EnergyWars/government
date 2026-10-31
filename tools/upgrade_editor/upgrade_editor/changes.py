from . import model

PARAM_SECTIONS = ("system",)


def diff(original, edited):
    result = []
    result += _upgrade_changes(original, edited)
    result += _placement_changes(original, edited)
    result += _order_changes(original, edited)
    result += _group_changes(original, edited)
    result += _topic_changes(original, edited)
    result += _area_changes(original, edited)
    result += _spot_rect_changes(original, edited)
    result += _system_changes(original, edited)
    result += _text_changes(original, edited)
    return result


def _upgrade_changes(original, edited):
    result = []
    before_all = original.get("upgrades", {})
    after_all = edited.get("upgrades", {})
    for upgrade_id in after_all:
        before = before_all.get(upgrade_id, {})
        after = after_all[upgrade_id]
        for field in sorted(set(before) | set(after)):
            if field in ("spot", "topic", "rooms", "enabled", "room_overrides"):
                continue
            if before.get(field) != after.get(field):
                result.append({"kind": "param", "id": upgrade_id, "field": field, "before": before.get(field), "after": after.get(field)})
        result += _override_changes(upgrade_id, before.get("room_overrides", {}), after.get("room_overrides", {}))
        if before.get("enabled", True) != after.get("enabled", True):
            result.append({"kind": "enabled", "id": upgrade_id, "before": before.get("enabled", True), "after": after.get("enabled", True)})
    for upgrade_id in before_all:
        if upgrade_id not in after_all:
            result.append({"kind": "removed_upgrade", "id": upgrade_id})
    return result


def _override_changes(upgrade_id, before, after):
    result = []
    for room_id in sorted(set(before) | set(after)):
        old, new = before.get(room_id), after.get(room_id)
        if old == new:
            continue
        state = "added" if old is None else "removed" if new is None else "changed"
        result.append({"kind": "room_override", "id": upgrade_id, "room": room_id, "state": state})
    return result


def _location(placed, ref):
    spots = placed.get(ref)
    return {"room": spots[0][0], "spot": spots[0][1]} if spots else None


def _locations(placed, ref):
    return sorted({(room, spot) for room, spot, _ in placed.get(ref, [])})


def _placement_changes(original, edited):
    result = []
    before_placed = model.placements(original)
    after_placed = model.placements(edited)
    for ref in sorted(set(before_placed) | set(after_placed)):
        before = _location(before_placed, ref)
        after = _location(after_placed, ref)
        if before != after:
            result.append({"kind": "placement", "ref": ref, "before": before, "after": after})
        before_all = _locations(before_placed, ref)
        after_all = _locations(after_placed, ref)
        added = [item for item in after_all if item not in before_all]
        removed = [item for item in before_all if item not in after_all]
        if (len(before_all) > 1 or len(after_all) > 1) and (added or removed):
            result.append({"kind": "placements", "ref": ref, "added": [{"room": room, "spot": spot} for room, spot in added], "removed": [{"room": room, "spot": spot} for room, spot in removed]})
    return result


def _order_changes(original, edited):
    result = []
    before_rooms = [room["id"] for room in original.get("menu", {}).get("rooms", [])]
    after_rooms = [room["id"] for room in edited.get("menu", {}).get("rooms", [])]
    if before_rooms != after_rooms:
        result.append({"kind": "room_order", "before": before_rooms, "after": after_rooms})
    before_groups = _group_map(original)
    after_groups = _group_map(edited)
    for room_id in after_groups:
        before_spots = [spot for spot in before_groups.get(room_id, {}) if spot in after_groups[room_id]]
        after_spots = [spot for spot in after_groups[room_id] if spot in before_groups.get(room_id, {})]
        if before_spots != after_spots:
            result.append({"kind": "group_order", "room": room_id, "before": before_spots, "after": after_spots})
        for spot, entries in after_groups[room_id].items():
            previous = before_groups.get(room_id, {}).get(spot, [])
            common_before = [ref for ref in previous if ref in entries]
            common_after = [ref for ref in entries if ref in previous]
            if common_before != common_after:
                result.append({"kind": "entry_order", "room": room_id, "spot": spot, "before": common_before, "after": common_after})
    return result


def _group_map(document):
    result = {}
    for room_id, group in model.iter_groups(document):
        result.setdefault(room_id, {})[model.group_key(group)] = list(group.get("entries", []))
    return result


def _group_titles(document):
    return {(room_id, model.group_key(group)): group.get("title") for room_id, group in model.iter_groups(document) if group.get("id")}


def _group_changes(original, edited):
    result = []
    before = _group_titles(original)
    after = _group_titles(edited)
    for key in sorted(set(before) | set(after)):
        if before.get(key) != after.get(key):
            result.append({"kind": "group", "room": key[0], "key": key[1], "before": before.get(key), "after": after.get(key)})
    return result


def _topic_changes(original, edited):
    result = []
    before = model.topic_of_items(original)
    after = model.topic_of_items(edited)
    for ref in sorted(set(before) | set(after)):
        if before.get(ref) != after.get(ref):
            result.append({"kind": "topic", "ref": ref, "before": (before.get(ref) or [None])[0], "after": (after.get(ref) or [None])[0]})
    before_topics = [topic["id"] for topic in original.get("menu", {}).get("topics", [])]
    after_topics = [topic["id"] for topic in edited.get("menu", {}).get("topics", [])]
    if before_topics != after_topics:
        result.append({"kind": "topic_order", "before": before_topics, "after": after_topics})
    return result


def _area_changes(original, edited):
    result = []
    before = original.get("areas", {})
    after = edited.get("areas", {})
    for area_id in sorted(set(before) | set(after)):
        if area_id not in before:
            result.append({"kind": "area_added", "id": area_id, "after": after[area_id]})
        elif area_id not in after:
            result.append({"kind": "area_removed", "id": area_id, "before": before[area_id]})
        elif before[area_id] != after[area_id]:
            result.append({"kind": "area_changed", "id": area_id, "before": before[area_id], "after": after[area_id]})
    return result


def _spot_rect_changes(original, edited):
    result = []
    before = original.get("spot_rects", {})
    after = edited.get("spot_rects", {})
    for spot in sorted(set(before) | set(after)):
        if before.get(spot, {}) != after.get(spot, {}):
            result.append({"kind": "spot_rects", "spot": spot, "before": before.get(spot), "after": after.get(spot)})
    return result


def _system_changes(original, edited):
    result = []
    before_system = original.get("system", {})
    after_system = edited.get("system", {})
    for name, value in after_system.get("constants", {}).items():
        previous = before_system.get("constants", {}).get(name)
        if previous != value:
            result.append({"kind": "system", "section": "constants", "id": name, "field": "", "before": previous, "after": value})
    for section in ("station_kinds", "departments"):
        for key, fields in after_system.get(section, {}).items():
            for field, value in fields.items():
                previous = before_system.get(section, {}).get(key, {}).get(field)
                if previous != value:
                    result.append({"kind": "system", "section": section, "id": key, "field": field, "before": previous, "after": value})
    return result


def _text_changes(original, edited):
    result = []
    before = original.get("text_overrides", {})
    after = edited.get("text_overrides", {})
    for key in sorted(set(before) | set(after)):
        for language in ("de", "en"):
            previous = before.get(key, {}).get(language)
            value = after.get(key, {}).get(language)
            if previous != value:
                result.append({"kind": "text", "key": key, "language": language, "before": previous, "after": value})
    return result
