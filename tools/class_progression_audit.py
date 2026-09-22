#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
data = json.loads((root / "studio-data.json").read_text(encoding="utf-8"))
warrior = next(x for x in data["classes"] if x["id"] == "warrior")
races = {x["id"]: x for x in data["races"]}
rows = {}
for raw in warrior["levelStatTable"].splitlines():
    cols = [int(float(x.strip())) for x in raw.split(",")]
    assert len(cols) == 8
    rows[cols[0]] = cols

assert data["schemaVersion"] == 18
assert data["studioVersion"] == "1.18.0"
assert len(rows) == 60 and set(rows) == set(range(1, 61))
assert rows[1] == [1,20,0,23,20,22,20,20]
assert rows[5] == [5,56,0,28,23,26,20,21]
assert rows[10] == [10,97,0,33,26,31,21,23]
assert rows[20] == [20,199,0,47,35,43,22,26]
assert rows[60] == [60,1689,0,120,80,110,30,45]

for key, expected in {
    "meleeApPerLevel": 3, "meleeApPerStrength": 2, "meleeApOffset": -20,
    "rangedApPerLevel": 1, "rangedApPerAgility": 1, "rangedApOffset": -10,
    "critAgiPerPercent": 20, "dodgeAgiPerPercent": 20, "baseDodge": 0,
    "healthPerStaminaFirst20": 1, "healthPerStaminaAfter20": 10,
    "manaPerIntellectFirst20": 1, "manaPerIntellectAfter20": 15, "armorPerAgility": 2,
    "blockValuePerStrength": 0.05, "defenseSkillPerLevel": 5,
    "weaponSkillPerLevel": 5, "referenceWeaponBaseDamage": 1.5,
    "referenceWeaponSpeedSeconds": 2.4,
}.items():
    assert warrior[key] == expected, (key, warrior[key])

classic_offsets = {
    "human": (0,0,0,0,0),
    "dwarf": (5,-4,1,-1,-1),
    "night_elf": (-4,4,0,0,0),
    "gnome": (-5,2,0,4,0),
    "orc": (3,-3,1,-3,2),
    "undead": (-1,-2,0,-2,5),
    "tauren": (5,-4,1,-4,2),
    "troll": (1,2,0,-4,1),
}
fields = ("strengthOffset","agilityOffset","staminaOffset","intellectOffset","spiritOffset")
for race_id, expected in classic_offsets.items():
    race = races[race_id]
    assert tuple(race[k] for k in fields) == expected
    assert race["statOffsetModel"] == "CLASSIC_STARTING_OFFSET"
    assert race["statOffsetSource"].strip()

for race_id in ("skyborne_high_order", "skyborne_windshaper"):
    race = races[race_id]
    assert tuple(race[k] for k in fields) == (0,0,0,0,0)
    assert race["statOffsetModel"] == "UNVERIFIED_NEUTRAL"
    assert "not claimed Forever data" in race["statOffsetSource"]

fr = (root/"GoblinArcade"/"ForeverRules.lua").read_text(encoding="utf-8")
eg = (root/"GoblinArcade"/"EnemyGenerator.lua").read_text(encoding="utf-8")
run = (root/"GoblinArcade"/"DungeonRun.lua").read_text(encoding="utf-8")
sheet = (root/"GoblinArcade"/"CharacterSheet.lua").read_text(encoding="utf-8")
roster = (root/"GoblinArcade"/"CharacterRoster.lua").read_text(encoding="utf-8")
studio = (root/"index.html").read_text(encoding="utf-8")
studio_mirror = (root/"studio"/"index.html").read_text(encoding="utf-8")
addon_mirror = (root/"GoblinArcade"/"index.html").read_text(encoding="utf-8")
publish = (root/"api"/"publish.js").read_text(encoding="utf-8")

assert studio == studio_mirror == addon_mirror
for token in (
    "GetClassProfile", "GetRaceProfile", "GetClassLevelStats", "ApplyRaceOffsets",
    "HealthFromStamina", "ManaFromIntellect", "GetReferencePlayerCombatProfile", "rawMaxHealth",
    "healthPerStaminaAfter20", "referenceWeaponSpeedSeconds",
):
    assert token in fr, token
assert "5 + effectiveLevel * 0.90" not in eg
assert "100 + effectiveLevel * 20" not in eg
assert "reference.rawReferenceDamage" in eg and "reference.rawMaxHealth" in eg
assert "hpPerLevel" not in run
assert "beforeHealth + hpGain" in run
assert "GetReferencePlayerCombatProfile(classId, level, selected.raceId)" in run
assert "BuildDerivedStats(level, classFile, gear, run.snapshot and run.snapshot.raceId)" in sheet
assert "GetReferencePlayerCombatProfile(classId, 1, raceId)" in roster
for token in (
    "Identity & Availability", "Level 1 Class Baseline", "Exact Level Progression",
    "Derived Stat Rules", "Enemy Reference Profile", "Starting Primary-Stat Offsets",
    "Stat Source / Provenance",
):
    assert token in studio, token
for token in ("schemaVersion must be 18", "UNVERIFIED_NEUTRAL", "statOffsetSource", "integer -20..20"):
    assert token in publish, token

print("Class progression audit OK: exact Warrior L1/L5/L10/L20/L60 curve, Classic race offsets, Studio source-of-truth, race-aware runtime and enemy reference scaling verified.")
