#!/usr/bin/env python3
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
data = json.loads((ROOT / "studio-data.json").read_text(encoding="utf-8"))

required = ("eventRules", "events", "eventFlags", "eventOptions")
for key in required:
    assert isinstance(data.get(key), list), f"Missing array: {key}"

rooms = {str(x.get("id", "")) for x in data.get("rooms", [])}
loot_tables = {str(x.get("id", "")) for x in data.get("lootTables", [])}
items = {str(x.get("id", "")) for x in data.get("items", [])}
classes = {str(x.get("id", "")) for x in data.get("classes", [])}
flags = {str(x.get("id", "")) for x in data["eventFlags"]}
assert "" not in flags and len(flags) == len(data["eventFlags"]), "Duplicate/empty Event Flag ID"

events = data["events"]
event_ids = {str(x.get("id", "")) for x in events}
assert "" not in event_ids and len(event_ids) == len(events), "Duplicate/empty Event ID"

valid_effects = {
    "NONE", "HEAL_PERCENT", "DAMAGE_PERCENT", "HP_FOR_SCORE",
    "DAMAGE_BONUS", "MAX_HP_PERCENT", "COPPER", "SCORE", "LOOT_TABLE",
}
valid_gear = {"NONE","SHIELD","TWO_HAND","ONE_HAND","WEAPON","ARMOR","PLATE","MAIL","LEATHER","CLOTH"}
valid_modes = {"DISABLE","HIDE"}

option_counts = {event_id: 0 for event_id in event_ids}
fallback_counts = {event_id: 0 for event_id in event_ids}

for event in events:
    eid = str(event["id"])
    icon = str(event.get("icon", "")).strip()
    assert not re.match(r"^https?://", icon, re.I), f"{eid}: event icon cannot be a web URL"
    assert str(event.get("randomSpawn", "YES")).upper() in {"YES","NO"}, f"{eid}: invalid randomSpawn"
    min_floor = int(event.get("minFloor", 1))
    max_floor = int(event.get("maxFloor", 9))
    assert min_floor >= 1 and max_floor >= min_floor, f"{eid}: invalid floor range"
    assert float(event.get("weight", 0)) > 0, f"{eid}: weight must be positive"
    roles = event.get("roomRoleIds", [])
    assert isinstance(roles, list) and roles, f"{eid}: no allowed room roles"
    assert not [role for role in roles if str(role) not in rooms], f"{eid}: unknown room role"

option_ids = set()
for option in data["eventOptions"]:
    oid = str(option.get("id", ""))
    assert oid and oid not in option_ids, f"Duplicate/empty Event Option ID: {oid}"
    option_ids.add(oid)
    event_id = str(option.get("eventId", ""))
    assert event_id in event_ids, f"{oid}: unknown event {event_id}"
    option_counts[event_id] += 1
    assert float(option.get("sortOrder", 0)) >= 0, f"{oid}: negative sortOrder"

    effect = str(option.get("effect", "NONE")).upper()
    assert effect in valid_effects, f"{oid}: unsupported effect {effect}"
    if effect == "LOOT_TABLE":
        assert str(option.get("lootTableId", "")) in loot_tables, f"{oid}: unknown loot table"

    min_hp = float(option.get("minHpPercent", 0))
    req_min_floor = int(option.get("requiredMinFloor", 0))
    req_max_floor = int(option.get("requiredMaxFloor", 0))
    req_copper = int(option.get("requiredCopper", 0))
    cost_hp = float(option.get("costHpPercent", 0))
    cost_copper = int(option.get("costCopper", 0))
    req_qty = int(option.get("requiredItemQuantity", 1))
    cost_qty = int(option.get("costItemQuantity", 1))
    delay = int(option.get("queueAfterFloors", 1))
    assert 0 <= min_hp <= 100, f"{oid}: invalid minHpPercent"
    assert req_min_floor >= 0 and req_max_floor >= 0 and not (req_min_floor and req_max_floor and req_max_floor < req_min_floor), f"{oid}: invalid floor requirement"
    assert req_copper >= 0 and cost_copper >= 0, f"{oid}: negative Copper value"
    assert 0 <= cost_hp < 100, f"{oid}: invalid HP cost"
    assert req_qty >= 1 and cost_qty >= 1, f"{oid}: invalid item quantity"
    assert delay >= 1, f"{oid}: invalid queue delay"
    assert str(option.get("requiredGearType", "NONE")).upper() in valid_gear, f"{oid}: invalid gear requirement"
    assert str(option.get("unavailableMode", "DISABLE")).upper() in valid_modes, f"{oid}: invalid unavailable mode"

    for class_id in option.get("requiredClassIds", []):
        assert str(class_id) in classes, f"{oid}: unknown class {class_id}"
    for item_id in option.get("requiredItemIds", []) + option.get("costItemIds", []):
        assert str(item_id) in items, f"{oid}: unknown item {item_id}"
    for flag_id in option.get("requiredFlagIds", []) + option.get("forbiddenFlagIds", []) + option.get("setFlagIds", []) + option.get("clearFlagIds", []):
        assert str(flag_id) in flags, f"{oid}: unknown flag {flag_id}"
    for followup_id in option.get("queueEventIds", []):
        assert str(followup_id) in event_ids, f"{oid}: unknown follow-up {followup_id}"
        assert str(followup_id) != event_id, f"{oid}: self-queue is not allowed"

    fallback = (
        min_hp <= 0 and req_min_floor <= 0 and req_max_floor <= 0
        and not option.get("requiredClassIds", [])
        and str(option.get("requiredGearType", "NONE")).upper() == "NONE"
        and req_copper <= 0 and not option.get("requiredItemIds", [])
        and not option.get("requiredFlagIds", []) and not option.get("forbiddenFlagIds", [])
        and cost_hp <= 0 and cost_copper <= 0 and not option.get("costItemIds", [])
    )
    if fallback:
        fallback_counts[event_id] += 1

for event_id, count in option_counts.items():
    assert 1 <= count <= 4, f"{event_id}: expected 1-4 options, got {count}"
    assert fallback_counts[event_id] >= 1, f"{event_id}: no unconditional fallback option"

rule = next((x for x in data["eventRules"] if x.get("id") == "dungeon_events"), None)
assert rule is not None, "Missing dungeon_events rule"
base = int(rule.get("basePerFloor", 0))
every = int(rule.get("extraEveryFloors", 0))
maximum = int(rule.get("maxPerFloor", 0))
assert base >= 0 and every >= 0 and maximum >= base, "Invalid dungeon_events placement rule"

chain_only = [x["id"] for x in events if str(x.get("randomSpawn", "YES")).upper() == "NO"]
assert "goblin_smugglers" in chain_only, "Expected authored chain-only Goblin Smugglers event"
help_option = next(x for x in data["eventOptions"] if x["id"] == "wounded_goblin_help")
assert help_option["setFlagIds"] == ["helped_griznak"], "Wounded Goblin chain must set helped_griznak"
assert help_option["queueEventIds"] == ["goblin_smugglers"], "Wounded Goblin chain target mismatch"
assert int(help_option["queueAfterFloors"]) == 2, "Wounded Goblin chain delay mismatch"

print(
    f"Event audit OK: {len(events)} events, {len(data['eventFlags'])} flags, "
    f"{len(data['eventOptions'])} options, {len(chain_only)} chain-only event(s)."
)
