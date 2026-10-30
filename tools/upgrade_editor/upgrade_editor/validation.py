import math
import re

from . import formula, model

MAX_TEXT = 4000
MAX_LEVEL = 100000


def _error(code, path, **detail):
    return {"code": code, "path": path, "detail": detail}


def _is_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def validate(document):
    if not isinstance(document, dict):
        return [_error("NOT_AN_OBJECT", "")]
    errors = []
    if document.get("schema") != model.SCHEMA:
        errors.append(_error("SCHEMA", "schema", expected=model.SCHEMA))
    for section in ("upgrades", "menu"):
        if not isinstance(document.get(section), dict):
            errors.append(_error("MISSING_SECTION", section))
    if errors:
        return errors
    errors += _validate_upgrades(document)
    errors += _validate_menu(document)
    errors += _validate_areas(document)
    errors += _validate_system(document.get("system", {}))
    errors += _validate_texts(document.get("text_overrides", {}))
    return errors


AREA_ID = re.compile(r"^[a-z][a-z0-9_]{0,39}$")
GROUP_ID = re.compile(r"^[a-z][a-z0-9_]{0,39}$")
MAX_GROUP_TITLE = 120


def _validate_areas(document):
    areas = document.get("areas", {})
    if not isinstance(areas, dict):
        return [_error("AREA_SHAPE", "areas")]
    if _validate_menu_shape(document["menu"]):
        return []
    errors = []
    room_ids = {room.get("id") for room in document["menu"].get("rooms", []) if isinstance(room, dict)}
    for area_id, area in areas.items():
        path = "areas." + str(area_id)
        if not AREA_ID.match(str(area_id)):
            errors.append(_error("AREA_ID", path))
        if not isinstance(area, dict):
            errors.append(_error("AREA_SHAPE", path))
            continue
        if area.get("room") not in room_ids:
            errors.append(_error("AREA_ROOM", path + ".room"))
        rects = area.get("rects")
        if not _is_list_of(rects, _is_rect) or not rects:
            errors.append(_error("AREA_RECT", path + ".rects"))
    for _, group in model.iter_groups(document):
        spot = group.get("spot")
        if isinstance(spot, str) and spot.startswith("area:") and spot[5:] not in areas:
            errors.append(_error("AREA_UNKNOWN", "menu.rooms." + spot))
    for upgrade_id, definition in document["upgrades"].items():
        spot = definition.get("spot") if isinstance(definition, dict) else None
        if isinstance(spot, str) and spot.startswith("area:") and spot[5:] not in areas:
            errors.append(_error("AREA_UNKNOWN", f"upgrades.{upgrade_id}.spot"))
    return errors


def _is_rect(rect):
    return isinstance(rect, list) and len(rect) == 4 and all(_is_number(value) for value in rect) and rect[2] > 0 and rect[3] > 0


def _validate_upgrades(document):
    errors = []
    upgrades = document["upgrades"]
    topics = document["menu"].get("topics", [])
    topic_ids = {topic.get("id") for topic in topics if isinstance(topic, dict)} if isinstance(topics, list) else set()
    for upgrade_id, definition in upgrades.items():
        path = "upgrades." + upgrade_id
        if not isinstance(definition, dict):
            errors.append(_error("NOT_AN_OBJECT", path))
            continue
        number_errors = _validate_numbers(definition, path)
        errors += number_errors
        if not number_errors:
            errors += _validate_models(definition, path)
        errors += _validate_definition_fields(definition, path, topic_ids)
        errors += _validate_room_overrides(definition, path)
        errors += _validate_requires(definition, path, upgrades, upgrade_id)
    return errors


def _validate_numbers(definition, path):
    errors = []
    for field in model.FLOAT_FIELDS + model.INT_FIELDS:
        if field in definition and not _is_number(definition[field]):
            errors.append(_error("NUMBER", f"{path}.{field}"))
    if not errors:
        if definition.get("cost", 0) < 0:
            errors.append(_error("RANGE", path + ".cost", minimum=0))
        if definition.get("growth", 1) < 1:
            errors.append(_error("RANGE", path + ".growth", minimum=1))
        if not 1 <= definition.get("max", 1) <= MAX_LEVEL:
            errors.append(_error("RANGE", path + ".max", minimum=1, maximum=MAX_LEVEL))
        if definition.get("reputation", 0) < 0:
            errors.append(_error("RANGE", path + ".reputation", minimum=0))
        if definition.get("curve") in ("decay", "unlock_decay") and not 0 < definition.get("rate", 1) <= 1:
            errors.append(_error("RANGE", path + ".rate", minimum=0, maximum=1))
    return errors


OVERRIDE_FIELDS = set(model.FLOAT_FIELDS + model.INT_FIELDS) | {"curve", "unit", "staff_cost", "cost_model", "value_model"}


def merged_override(definition, override):
    merged = {key: value for key, value in definition.items() if key != "room_overrides"}
    merged.update(override)
    for field in ("cost_model", "value_model"):
        if merged.get(field) == {}:
            del merged[field]
    return merged


def _validate_room_overrides(definition, path):
    if "room_overrides" not in definition:
        return []
    overrides = definition["room_overrides"]
    rooms = definition.get("rooms", [])
    if not isinstance(overrides, dict) or not isinstance(rooms, list):
        return [_error("ROOM_OVERRIDE", path + ".room_overrides")]
    errors = []
    for room_id, override in overrides.items():
        target = f"{path}.room_overrides.{room_id}"
        if room_id not in rooms or not isinstance(override, dict) or set(override) - OVERRIDE_FIELDS:
            errors.append(_error("ROOM_OVERRIDE", target))
            continue
        merged = merged_override(definition, override)
        number_errors = _validate_numbers(merged, target)
        errors += number_errors
        if merged.get("curve") not in model.CURVES:
            errors.append(_error("CURVE", target + ".curve", allowed=list(model.CURVES)))
        if not number_errors:
            errors += _validate_models(merged, target)
    return errors


def _validate_definition_fields(definition, path, topic_ids):
    errors = []
    if definition.get("curve") not in model.CURVES:
        errors.append(_error("CURVE", path + ".curve", allowed=list(model.CURVES)))
    if not isinstance(definition.get("spot"), str) or not definition.get("spot"):
        errors.append(_error("SPOT", path + ".spot"))
    if definition.get("topic") not in topic_ids:
        errors.append(_error("TOPIC", path + ".topic"))
    if "rooms" in definition and not _is_list_of(definition["rooms"], lambda room: isinstance(room, str)):
        errors.append(_error("ROOMS", path + ".rooms"))
    return errors


def _validate_requires(definition, path, upgrades, upgrade_id):
    errors = []
    requires = definition.get("requires", {})
    if not isinstance(requires, dict):
        return [_error("REQUIRES", path + ".requires")]
    for required_id, level in requires.items():
        if required_id == upgrade_id or required_id not in upgrades:
            errors.append(_error("REQUIRES_UNKNOWN", f"{path}.requires.{required_id}"))
        elif not _is_number(level) or not 1 <= level <= _max_level(upgrades[required_id]):
            errors.append(_error("REQUIRES_LEVEL", f"{path}.requires.{required_id}"))
    return errors


COST_VARIABLES = ("level", "max", "cost", "growth", "price_offset")
VALUE_VARIABLES = ("level", "max", "base", "step", "rate", "neutral")
MAX_TABLE = 100000


def _validate_models(definition, path):
    errors = []
    maximum = definition.get("max", 1)
    if not isinstance(maximum, int) or maximum < 1 or maximum > MAX_TABLE:
        return errors
    if "formula_history" in definition:
        errors += _validate_formula_history(definition["formula_history"], path + ".formula_history")
    if "cost_model" in definition:
        errors += _validate_model(definition["cost_model"], path + ".cost_model", "levels", COST_VARIABLES, range(maximum), _cost_variables(definition), True)
    if "value_model" in definition:
        errors += _validate_model(definition["value_model"], path + ".value_model", "increments", VALUE_VARIABLES, range(maximum + 1), _value_variables(definition), False)
    return errors


def _validate_formula_history(history, path):
    if not isinstance(history, dict) or set(history) - {"cost", "value"}:
        return [_error("FORMULA_HISTORY", path)]
    for kind, entries in history.items():
        if not _is_list_of(entries, lambda entry: isinstance(entry, str) and entry.strip()):
            return [_error("FORMULA_HISTORY", f"{path}.{kind}")]
    return []


def _cost_variables(definition):
    return lambda level: {"level": float(level), "max": float(definition.get("max", 1)), "cost": float(definition.get("cost", 0)), "growth": float(definition.get("growth", 1)), "price_offset": float(definition.get("price_offset", 0))}


def _value_variables(definition):
    base = float(definition.get("base", 0))
    return lambda level: {"level": float(level), "max": float(definition.get("max", 1)), "base": base, "step": float(definition.get("step", 0)), "rate": float(definition.get("rate", 1)), "neutral": float(definition.get("neutral", base))}


def _validate_model(model_value, path, table_key, names, levels, variables, non_negative):
    if not isinstance(model_value, dict) or model_value.get("mode") not in ("formula", "table"):
        return [_error("MODEL_MODE", path)]
    if "formula" in model_value and not isinstance(model_value["formula"], str):
        return [_error("FORMULA", path + ".formula", reason="TYPE")]
    if model_value["mode"] == "table":
        return _validate_table(model_value.get(table_key), path + "." + table_key, len(levels) - (0 if non_negative else 1), non_negative)
    text = model_value.get("formula")
    try:
        run = formula.compile_formula(text, names)
    except formula.FormulaError as error:
        return [_error("FORMULA", path + ".formula", reason=error.code)]
    for level in levels:
        value = run(variables(level))
        if not math.isfinite(value):
            return [_error("FORMULA", path + ".formula", reason="NOT_FINITE", level=level)]
        if non_negative and value < 0:
            return [_error("FORMULA", path + ".formula", reason="NEGATIVE", level=level)]
    return []


def _validate_table(values, path, expected_length, non_negative):
    if not isinstance(values, list) or len(values) != expected_length:
        return [_error("TABLE_LENGTH", path, expected=expected_length)]
    for index, value in enumerate(values):
        if not _is_number(value) or (non_negative and value < 0):
            return [_error("TABLE_VALUE", f"{path}.{index}")]
    return []


def _max_level(definition):
    return definition.get("max", 1) if isinstance(definition, dict) else 0


def _is_list_of(value, predicate):
    return isinstance(value, list) and all(predicate(item) for item in value)


def _validate_menu_shape(menu):
    errors = []
    rooms = menu.get("rooms")
    valid_groups = lambda groups: _is_list_of(groups, lambda group: isinstance(group, dict) and isinstance(group.get("spot"), str) and _is_list_of(group.get("entries"), lambda ref: isinstance(ref, str)) and _valid_group_name(group))
    if not _is_list_of(rooms, lambda room: isinstance(room, dict) and isinstance(room.get("id"), str) and valid_groups(room.get("groups"))):
        errors.append(_error("MENU_SHAPE", "menu.rooms"))
    topics = menu.get("topics")
    if not _is_list_of(topics, lambda topic: isinstance(topic, dict) and isinstance(topic.get("id"), str) and _is_list_of(topic.get("items"), lambda ref: isinstance(ref, str))):
        errors.append(_error("MENU_SHAPE", "menu.topics"))
    return errors


def _valid_group_name(group):
    if "id" not in group and "title" not in group:
        return True
    title = group.get("title")
    return (
        isinstance(group.get("id"), str)
        and bool(GROUP_ID.match(group["id"]))
        and isinstance(title, dict)
        and all(isinstance(title.get(language), str) and 0 < len(title[language].strip()) <= MAX_GROUP_TITLE for language in ("de", "en"))
    )


def _validate_menu(document):
    errors = _validate_menu_shape(document["menu"])
    if errors:
        return errors
    upgrades = document["upgrades"]
    seen = {}
    groups_seen = set()
    refs_at = set()
    for room_id, group in model.iter_groups(document):
        key = (room_id, model.group_key(group))
        if key in groups_seen:
            errors.append(_error("GROUP_DUPLICATE", f"menu.rooms.{room_id}.{model.group_key(group)}"))
        groups_seen.add(key)
        for ref in group.get("entries", []):
            path = f"menu.rooms.{room_id}.{group.get('spot')}"
            if (room_id, group.get("spot"), ref) in refs_at:
                errors.append(_error("DUPLICATE_REF", path, ref=ref))
            refs_at.add((room_id, group.get("spot"), ref))
            seen[ref] = True
            errors += _validate_instance(ref, group.get("spot"), path, upgrades)
    errors += _validate_topics(document)
    errors += _validate_room_lists(document, seen)
    return errors


def _validate_instance(ref, spot, path, upgrades):
    upgrade_id, room_id = model.parse_ref(ref)
    if upgrade_id is None:
        return []
    definition = upgrades.get(upgrade_id)
    if definition is None:
        return [_error("UNKNOWN_REF", path, ref=ref)]
    if not isinstance(definition, dict):
        return []
    if model.is_room_upgrade(definition) and not room_id:
        return [_error("ROOM_REF_NEEDED", path, ref=ref)]
    if not model.is_room_upgrade(definition) and room_id:
        return [_error("GLOBAL_REF_WITH_ROOM", path, ref=ref)]
    return []


def _validate_topics(document):
    errors = []
    upgrades = document["upgrades"]
    seen = model.topic_of_items(document)
    for ref, topic_ids in seen.items():
        if len(topic_ids) > 1:
            errors.append(_error("DUPLICATE_TOPIC_ITEM", "menu.topics", ref=ref))
        upgrade_id, _ = model.parse_ref(ref)
        if upgrade_id is not None and upgrade_id not in upgrades:
            errors.append(_error("UNKNOWN_REF", "menu.topics", ref=ref))
    for upgrade_id in upgrades:
        if "track:" + upgrade_id not in seen:
            errors.append(_error("TOPIC_MISSING", "menu.topics", ref="track:" + upgrade_id))
    return errors


def _validate_room_lists(document, seen):
    errors = []
    for upgrade_id, definition in document["upgrades"].items():
        if isinstance(definition, dict) and model.is_room_upgrade(definition):
            for room_id in definition.get("rooms", []):
                if f"track:{upgrade_id}@{room_id}" not in seen:
                    errors.append(_error("ROOM_WITHOUT_PLACEMENT", f"upgrades.{upgrade_id}.rooms", room=room_id))
    return errors


def _validate_system(system):
    if not isinstance(system, dict):
        return [_error("NOT_AN_OBJECT", "system")]
    errors = []
    for name, value in system.get("constants", {}).items():
        if not _is_number(value) or value < 0:
            errors.append(_error("NUMBER", "system.constants." + name))
    for section in ("station_kinds", "departments"):
        for key, fields in system.get(section, {}).items():
            for field, value in fields.items():
                if not _is_number(value) or value < 0:
                    errors.append(_error("NUMBER", f"system.{section}.{key}.{field}"))
    return errors


def _validate_texts(texts):
    if not isinstance(texts, dict):
        return [_error("NOT_AN_OBJECT", "text_overrides")]
    errors = []
    for key, languages in texts.items():
        valid = isinstance(languages, dict) and all(
            language in ("de", "en") and isinstance(text, str) and len(text) <= MAX_TEXT
            for language, text in languages.items()
        )
        if not valid:
            errors.append(_error("TEXT", "text_overrides." + key))
    return errors
