#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
data = json.loads((ROOT / "studio-data.json").read_text(encoding="utf-8"))

for key in ("ecosystems", "ecosystemEnemies", "enemies", "events", "eventRules"):
    assert isinstance(data.get(key), list), f"Missing array: {key}"

ecosystems = {str(x["id"]): x for x in data["ecosystems"]}
enemies = {str(x["id"]): x for x in data["enemies"]}
assert ecosystems, "No ecosystems defined"
assert any(str(x.get("enabled", "YES")).upper() == "YES" for x in ecosystems.values()), "No enabled ecosystem"

valid_styles = {"ORC_CRYPT", "WARREN", "HAUNTED_CRYPT", "PLAGUE_CRYPT"}
for eco_id, eco in ecosystems.items():
    assert str(eco.get("enabled", "YES")).upper() in {"YES", "NO"}, f"{eco_id}: invalid enabled"
    assert float(eco.get("weight", 0)) > 0, f"{eco_id}: invalid run weight"
    assert str(eco.get("stylePreset", "")) in valid_styles, f"{eco_id}: invalid style preset"
    assert str(eco.get("dungeonName", "")).strip(), f"{eco_id}: missing dungeon title"

for row in data["ecosystemEnemies"]:
    rid = str(row.get("id", ""))
    eco_id = str(row.get("ecosystemId", ""))
    enemy_id = str(row.get("enemyId", ""))
    assert rid and eco_id in ecosystems, f"{rid}: unknown ecosystem"
    assert enemy_id in enemies, f"{rid}: unknown enemy"
    min_floor = int(row.get("minFloor", 1))
    max_floor = int(row.get("maxFloor", 9))
    assert 1 <= min_floor <= max_floor <= 9, f"{rid}: invalid floor range"
    assert float(row.get("weight", 0)) > 0, f"{rid}: invalid weight"

event_rule = next(x for x in data["eventRules"] if x.get("id") == "dungeon_events")
base = int(event_rule.get("basePerFloor", 0))
every = int(event_rule.get("extraEveryFloors", 0))
maximum = int(event_rule.get("maxPerFloor", base))

for event in data["events"]:
    for eco_id in event.get("ecosystemIds", []):
        assert str(eco_id) in ecosystems, f"{event['id']}: unknown ecosystem {eco_id}"

for eco_id, eco in ecosystems.items():
    if str(eco.get("enabled", "YES")).upper() != "YES":
        continue
    for floor in range(1, 10):
        monster_rows = [
            row for row in data["ecosystemEnemies"]
            if str(row.get("ecosystemId", "")) == eco_id
            and int(row.get("minFloor", 1)) <= floor <= int(row.get("maxFloor", 9))
            and float(row.get("weight", 0)) > 0
        ]
        assert monster_rows, f"{eco_id}: no monster pool on floor {floor}"

        target = min(maximum, base + (floor // every if every > 0 else 0))
        event_rows = [
            event for event in data["events"]
            if str(event.get("enabled", "YES")).upper() == "YES"
            and str(event.get("randomSpawn", "YES")).upper() != "NO"
            and int(event.get("minFloor", 1)) <= floor <= int(event.get("maxFloor", 9))
            and (
                not event.get("ecosystemIds")
                or eco_id in [str(x) for x in event.get("ecosystemIds", [])]
            )
        ]
        assert len(event_rows) >= target, f"{eco_id}: only {len(event_rows)} random events available on floor {floor}, need {target}"

orc_rows = [r for r in data["ecosystemEnemies"] if r.get("ecosystemId") == "orc_occupied_crypt"]
orc_enemy_ids = {str(r.get("enemyId")) for r in orc_rows}
expected_orcs = {
    "orc_raider","orc_berserker","orc_bonebreaker","orc_bonepicker","orc_grave_champion",
    "orc_gravedigger","orc_hexer","orc_plague_eater","orc_tomb_sentinel","orc_warcaller",
}
assert expected_orcs <= orc_enemy_ids, "Orc ecosystem does not contain all authored orc monsters"

print(f"Ecosystem audit OK: {len(ecosystems)} ecosystems, {len(data['ecosystemEnemies'])} depth-band memberships, single-biome 9-floor coverage validated.")
