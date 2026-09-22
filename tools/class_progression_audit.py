#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
data = json.loads((root / "studio-data.json").read_text(encoding="utf-8"))
warrior = next(x for x in data["classes"] if x["id"] == "warrior")
rows = {}
for raw in warrior["levelStatTable"].splitlines():
    cols = [int(float(x.strip())) for x in raw.split(",")]
    assert len(cols) == 8
    rows[cols[0]] = cols

assert data["schemaVersion"] == 16
assert data["studioVersion"] == "1.15.0"
assert len(rows) == 60 and set(rows) == set(range(1, 61))
assert rows[1] == [1,20,0,23,20,22,20,20]
assert rows[20] == [20,199,0,47,35,43,22,26]
assert rows[60] == [60,1689,0,120,80,110,30,45]
assert warrior["meleeApPerLevel"] == 3
assert warrior["meleeApPerStrength"] == 2
assert warrior["meleeApOffset"] == -20
assert warrior["rangedApPerLevel"] == 1
assert warrior["rangedApPerAgility"] == 1
assert warrior["rangedApOffset"] == -10
assert warrior["critAgiPerPercent"] == 20
assert warrior["dodgeAgiPerPercent"] == 20

fr = (root/"GoblinArcade"/"ForeverRules.lua").read_text(encoding="utf-8")
eg = (root/"GoblinArcade"/"EnemyGenerator.lua").read_text(encoding="utf-8")
run = (root/"GoblinArcade"/"DungeonRun.lua").read_text(encoding="utf-8")
sheet = (root/"GoblinArcade"/"CharacterSheet.lua").read_text(encoding="utf-8")
studio = (root/"index.html").read_text(encoding="utf-8")
for token in ("GetClassLevelStats","HealthFromStamina","GetReferencePlayerCombatProfile","rawMaxHealth","meleeApPerLevel"):
    assert token in fr
assert "reference.rawReferenceDamage" in eg
assert "reference.rawMaxHealth" in eg
assert "classId = classId" in run
assert "stats.maxHealth" in sheet
assert "hpPerLevel" not in run
for token in ("Level 1 Base HP","Level 1-60 Stat Table","Melee AP / Level","Agility / 1% Crit"):
    assert token in studio
print("Class progression audit OK: Warrior Classic 1-60 table, AP coefficients, stamina health and class-anchored enemy scaling verified.")
