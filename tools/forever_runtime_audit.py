#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
data = json.loads((root / "studio-data.json").read_text(encoding="utf-8"))
run = (root / "GoblinArcade" / "DungeonRun.lua").read_text(encoding="utf-8")
sheet = (root / "GoblinArcade" / "CharacterSheet.lua").read_text(encoding="utf-8")
roster = (root / "GoblinArcade" / "CharacterRoster.lua").read_text(encoding="utf-8")
database = (root / "GoblinArcade" / "ItemDatabase.lua").read_text(encoding="utf-8")
affixes = (root / "GoblinArcade" / "AffixSystem.lua").read_text(encoding="utf-8")
enemy = (root / "GoblinArcade" / "EnemyGenerator.lua").read_text(encoding="utf-8")
toc = (root / "GoblinArcade" / "GoblinArcade.toc").read_text(encoding="utf-8")
workflow = (root / ".github" / "workflows" / "balance-audit.yml").read_text(encoding="utf-8")
studio = (root / "index.html").read_bytes()
studio_mirror = (root / "studio" / "index.html").read_bytes()
addon_mirror = (root / "GoblinArcade" / "index.html").read_bytes()

assert data["schemaVersion"] == 18
assert data["studioVersion"] == "1.18.0"
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
assert toc.index("Data/StudioData.lua") < toc.index("AffixSystem.lua") < toc.index("ItemDatabase.lua")
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
assert "classDefinition.resourceMax" in sheet
assert "run.resourceMax = rageCap" in sheet
for token in ("strength", "agility", "stamina", "hit", "expertise", "defense", "blockValue", "weaponSkill"):
    assert token in database, f"ItemDatabase missing {token}"
assert "BuildEnemyCombatStats" in enemy
assert "GetReferencePlayerCombatProfile" in (root / "GoblinArcade" / "ForeverRules.lua").read_text(encoding="utf-8")
assert "reference.rawReferenceDamage" in enemy and "reference.rawMaxHealth" in enemy
assert "WeaponGenerator.lua" not in toc and "ItemGenerator.lua" not in toc
assert 'characterRosterMode = "generated_only_v1"' in roster
assert 'level = 1' in roster and 'startingLevel = 1' in roster
for forbidden in ('GetInventoryItemLink("player"', 'UnitLevel("player")', 'UnitHealthMax("player")', "SnapshotCurrentEquipment", "SyncCurrentCharacterRoster", "GetCurrentCharacterKey"):
    assert forbidden not in roster, f"WoW character import hook remains in CharacterRoster: {forbidden}"
assert "DB.VERSION = 7" in database and "GA.AffixSystem:ApplyToItem" in database
for token in ("ITEMIZATION_VERSION = 2","GetAffixCount","BuildAffix","ApplyToItem","STAT_META"): assert token in affixes
assert len(data["prefixes"]) >= 8 and len(data["suffixes"]) >= 8

assert "runs-on:" in workflow and "- self-hosted" in workflow and "- Windows" in workflow
for hosted in ("ubuntu-latest", "windows-latest", "macos-latest"):
    assert hosted not in workflow, f"Paid/hosted runner reintroduced: {hosted}"

print("Forever runtime audit OK: generated-only heroes, Warrior combat, derived stats, Affix Itemization v2, 100 Rage and self-hosted CI hooks verified.")
