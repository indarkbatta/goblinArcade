#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
data = json.loads((root / "studio-data.json").read_text(encoding="utf-8"))
run = (root / "GoblinArcade" / "DungeonRun.lua").read_text(encoding="utf-8")
sheet = (root / "GoblinArcade" / "CharacterSheet.lua").read_text(encoding="utf-8")
roster = (root / "GoblinArcade" / "CharacterRoster.lua").read_text(encoding="utf-8")
items = (root / "GoblinArcade" / "ItemGenerator.lua").read_text(encoding="utf-8")
weapons = (root / "GoblinArcade" / "WeaponGenerator.lua").read_text(encoding="utf-8")
database = (root / "GoblinArcade" / "ItemDatabase.lua").read_text(encoding="utf-8")
enemy = (root / "GoblinArcade" / "EnemyGenerator.lua").read_text(encoding="utf-8")
toc = (root / "GoblinArcade" / "GoblinArcade.toc").read_text(encoding="utf-8")
workflow = (root / ".github" / "workflows" / "balance-audit.yml").read_text(encoding="utf-8")
studio = (root / "index.html").read_bytes()
studio_mirror = (root / "studio" / "index.html").read_bytes()
addon_mirror = (root / "GoblinArcade" / "index.html").read_bytes()

assert data["schemaVersion"] == 14
assert data["studioVersion"] == "1.13.0"
warrior = next(x for x in data["classes"] if x["id"] == "warrior")
assert warrior["resource"] == "RAGE"
assert warrior["resourceMax"] == 100
assert warrior["basicAttackResourceGain"] == 0
abilities = {x["id"]: x for x in data["abilities"]}
assert abilities["heroic_strike"]["resourceCost"] == 15
assert abilities["charge"]["resourceGain"] == 15
assert abilities["bloodrage"]["resourceGain"] == 20

assert "ForeverRules.lua" in toc
assert toc.index("ForeverRules.lua") < toc.index("DungeonRun.lua")
assert studio == studio_mirror == addon_mirror, "Studio mirrors are not byte-identical"

for token in (
    "ResolvePlayerMeleeAttack",
    "ResolveEnemyMeleeAttack",
    "ApplyPhysicalMitigation",
    "CalculateRageFromSwing",
    "CRUSHING",
    "GLANCING",
    "ruleset = self.ForeverRules",
):
    assert token in run, f"DungeonRun Forever hook missing: {token}"

assert "armor / (armor + 100)" not in run, "Legacy armor formula is still active in DungeonRun"
assert "BuildDerivedStats" in sheet
assert "run.resourceMax = 100" in sheet
assert "GetItemStats" in roster
for token in ("strength", "agility", "stamina", "hit", "expertise", "defense", "blockValue", "weaponSkill"):
    assert token in items, f"ItemGenerator missing {token}"
    assert token in database, f"ItemDatabase missing {token}"
for token in ("weaponSpeedSeconds", "expertise", "stamina"):
    assert token in weapons, f"WeaponGenerator missing {token}"
assert "BuildEnemyCombatStats" in enemy

assert "runs-on:" in workflow and "- self-hosted" in workflow and "- Windows" in workflow
for hosted in ("ubuntu-latest", "windows-latest", "macos-latest"):
    assert hosted not in workflow, f"Paid/hosted runner reintroduced: {hosted}"

print("Forever runtime audit OK: Warrior combat, derived stats, itemization, 100 Rage, attack tables and self-hosted CI hooks verified.")
