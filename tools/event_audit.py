#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
data = json.loads((ROOT / "studio-data.json").read_text(encoding="utf-8"))

required = ("eventRules", "events", "eventOptions")
for key in required:
    assert isinstance(data.get(key), list), f"Missing array: {key}"

rooms = {str(x.get("id", "")) for x in data.get("rooms", [])}
loot_tables = {str(x.get("id", "")) for x in data.get("lootTables", [])}
events = data["events"]
event_ids = {str(x.get("id", "")) for x in events}
assert "" not in event_ids, "Event without ID"
assert len(event_ids) == len(events), "Duplicate event ID"

valid_effects = {
    "NONE", "HEAL_PERCENT", "DAMAGE_PERCENT", "HP_FOR_SCORE",
    "DAMAGE_BONUS", "MAX_HP_PERCENT", "COPPER", "SCORE", "LOOT_TABLE",
}

option_counts = {event_id: 0 for event_id in event_ids}
for event in events:
    eid = str(event["id"])
    min_floor = int(event.get("minFloor", 1))
    max_floor = int(event.get("maxFloor", 9))
    assert min_floor >= 1 and max_floor >= min_floor, f"{eid}: invalid floor range"
    assert float(event.get("weight", 0)) > 0, f"{eid}: weight must be positive"
    roles = event.get("roomRoleIds", [])
    assert isinstance(roles, list) and roles, f"{eid}: no allowed room roles"
    unknown = [role for role in roles if str(role) not in rooms]
    assert not unknown, f"{eid}: unknown room roles {unknown}"

option_ids = set()
for option in data["eventOptions"]:
    oid = str(option.get("id", ""))
    assert oid and oid not in option_ids, f"Duplicate/empty event option ID: {oid}"
    option_ids.add(oid)
    event_id = str(option.get("eventId", ""))
    assert event_id in event_ids, f"{oid}: unknown event {event_id}"
    option_counts[event_id] += 1
    effect = str(option.get("effect", "NONE")).upper()
    assert effect in valid_effects, f"{oid}: unsupported effect {effect}"
    if effect == "LOOT_TABLE":
        table_id = str(option.get("lootTableId", ""))
        assert table_id in loot_tables, f"{oid}: unknown loot table {table_id}"

for event_id, count in option_counts.items():
    assert 1 <= count <= 4, f"{event_id}: expected 1-4 options, got {count}"

rule = next((x for x in data["eventRules"] if x.get("id") == "dungeon_events"), None)
assert rule is not None, "Missing dungeon_events rule"
base = int(rule.get("basePerFloor", 0))
every = int(rule.get("extraEveryFloors", 0))
maximum = int(rule.get("maxPerFloor", 0))
assert base >= 0 and every >= 0 and maximum >= base, "Invalid dungeon_events placement rule"

print(
    f"Event audit OK: {len(events)} events, {len(data['eventOptions'])} options, "
    f"placement {base} base / +1 every {every or 'disabled'} floors / max {maximum}."
)
