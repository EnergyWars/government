import copy


def make_document():
    return copy.deepcopy({
        "schema": 1,
        "upgrades": {
            "briefcase": {"spot": "player", "topic": "player", "max": 10, "cost": 150.0, "growth": 1.15, "curve": "linear", "base": 6.0, "step": 1.0, "unit": "count"},
            "work_ethic": {"spot": "player", "topic": "player", "max": 20, "cost": 200.0, "growth": 1.08, "curve": "linear", "base": 1.0, "step": 0.025, "unit": "bonus", "requires": {"briefcase": 2}},
            "room_speed": {"spot": "@room", "topic": "speed", "max": 100, "cost": 150.0, "growth": 1.35, "curve": "milestone", "base": 1.0, "step": 0.06, "unit": "factor", "rooms": ["hall", "tax_services"]},
            "coffee": {"spot": "coffee_machine", "topic": "comfort", "max": 30, "cost": 500.0, "growth": 1.045, "curve": "decay", "base": 1.0, "rate": 0.99, "unit": "reduction", "reputation": 5.0},
        },
        "system": {"constants": {"DESK_GROWTH": 2.2}, "station_kinds": {"review": {"desk_cost": 120.0}}, "departments": {"tax_services": {"unlock_cost": 800.0}}},
        "menu": {
            "rooms": [
                {"id": "player", "groups": [{"spot": "player", "entries": ["track:briefcase", "track:work_ethic"]}]},
                {"id": "hall", "groups": [{"spot": "dept:hall", "entries": ["track:room_speed@hall"]}]},
                {"id": "kitchen", "groups": [{"spot": "coffee_machine", "entries": ["track:coffee"]}]},
                {"id": "tax_services", "groups": [{"spot": "dept:tax_services", "entries": ["track:room_speed@tax_services", "desk:tax_services/review"]}]},
            ],
            "topics": [
                {"id": "player", "items": ["track:briefcase", "track:work_ethic"]},
                {"id": "speed", "items": ["track:room_speed", "sys:desk"]},
                {"id": "comfort", "items": ["track:coffee"]},
            ],
        },
        "text_overrides": {},
    })
