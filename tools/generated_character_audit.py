#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
roster = (root / "GoblinArcade" / "CharacterRoster.lua").read_text(encoding="utf-8")
run = (root / "GoblinArcade" / "DungeonRun.lua").read_text(encoding="utf-8")
sheet = (root / "GoblinArcade" / "CharacterSheet.lua").read_text(encoding="utf-8")
toc = (root / "GoblinArcade" / "GoblinArcade.toc").read_text(encoding="utf-8")
core = (root / "GoblinArcade" / "Core.lua").read_text(encoding="utf-8")

assert 'GA.version = "0.70.0"' in core
assert "## Version: 0.70.0" in toc
assert "WeaponGenerator.lua" not in toc
assert "ItemGenerator.lua" not in toc

for token in (
    'sourceType = "arcade"',
    "isArcadeGenerated = true",
    "level = 1",
    "startingLevel = 1",
    'db.characterRosterMode = "generated_only_v1"',
    "function GA:InitializeCharacterRoster()",
    "function GA:GetCharacterRoster()",
    "function GA:GetSelectedDungeonCharacter()",
):
    assert token in roster, f"Generated-only roster hook missing: {token}"

for forbidden in (
    'GetInventoryItemLink("player"',
    'GetInventoryItemTexture("player"',
    'UnitName("player")',
    'UnitLevel("player")',
    'UnitClass("player")',
    'UnitRace("player")',
    'UnitHealthMax("player")',
    "SnapshotCurrentEquipment",
    "SyncCurrentCharacterRoster",
    "GetCurrentCharacterKey",
    "GetItemStats",
):
    assert forbidden not in roster, f"WoW roster import path remains: {forbidden}"

for forbidden in (
    'GetInventoryItemLink("player"',
    'GetInventoryItemTexture("player"',
    'UnitLevel("player")',
    'UnitHealthMax("player")',
    "SyncCurrentCharacterRoster",
    "GetCurrentCharacterKey",
    "WOW GEAR INPUT",
    "ARCADE CONVERSION",
    "PLAYER_EQUIPMENT_CHANGED",
    "GET_ITEM_INFO_RECEIVED",
    "WeaponGenerator",
):
    assert forbidden not in run, f"WoW run conversion hook remains: {forbidden}"

for forbidden in ("GetCurrentCharacterKey", "WeaponGenerator", "ItemGenerator"):
    assert forbidden not in sheet, f"WoW item/portrait conversion hook remains in CharacterSheet: {forbidden}"

assert "CREATE A GOBLINARCADE HERO FIRST" in run
assert "GENERATED CHARACTERS ONLY" in run
assert "WoW characters, levels, stats and equipment are not imported." in run
assert "local level = math.max(1, math.floor(tonumber(selected.level) or 1))" in run

print("Generated character audit OK: only GoblinArcade heroes can enter runs; WoW character/gear conversion is disconnected; new heroes start at Level 1.")
