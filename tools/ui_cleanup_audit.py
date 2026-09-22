#!/usr/bin/env python3
from pathlib import Path

source = Path("GoblinArcade/DungeonRun.lua").read_text(encoding="utf-8")
character_sheet = Path("GoblinArcade/CharacterSheet.lua").read_text(encoding="utf-8")

required = [
    "function GA:ClearDungeonGridVisuals()",
    "self:ClearDungeonGridVisuals()",
    "self.DungeonGrid:Hide()",
    "self.DungeonGrid.spriteLayer:Hide()",
    "self.DungeonGrid:Show()",
    "self.DungeonGrid.spriteLayer:Show()",
]
for token in required:
    assert token in source, f"Missing dungeon cleanup token: {token}"

return_start = source.index("function GA:ReturnToDungeonCharacters()")
return_end = source.index("function GA:FailDungeonRun(", return_start)
return_block = source[return_start:return_end]
assert "self:ClearDungeonGridVisuals()" in return_block, "Character-selection return does not clear dungeon visuals"
assert "self:SetDungeonSetupMode(true)" in return_block, "Character-selection return does not activate setup mode"

fail_start = source.index("function GA:FailDungeonRun(")
fail_end = source.index("function GA:GrantRunExperience(", fail_start)
fail_block = source[fail_start:fail_end]
assert "run.active = false" in fail_block
assert "self:ClearDungeonGridVisuals()" in fail_block, "Death path does not clear dungeon visuals"

complete_start = source.index("function GA:CompleteDungeonRun()")
complete_end = source.index("function GA:AdvanceDungeonFloor()", complete_start)
complete_block = source[complete_start:complete_end]
assert "self:ClearDungeonGridVisuals()" in complete_block, "Successful completion does not clear dungeon visuals"

setup_start = source.index("function GA:SetDungeonSetupMode(active)")
setup_end = source.index("function GA:OpenCharacterGeneratorModal()", setup_start)
setup_block = source[setup_start:setup_end]
assert setup_block.index("self.DungeonGrid:Hide()") < setup_block.index("    else"), "Grid hide must be in setup-active branch"
assert setup_block.index("self.DungeonGrid:Show()") > setup_block.index("    else"), "Grid show must be in run-active branch"

print("Dungeon UI cleanup audit OK: death/completion clear entities and setup mode hides the entire grid/sprite layer.")


# Character sheet layout regression checks.
for token in (
    'backpackPanel:SetHeight(446)',
    'statsPanel:SetPoint("TOPLEFT", backpackPanel, "BOTTOMLEFT", 0, -12)',
    'statsPanel:SetPoint("BOTTOMRIGHT", sheet, "BOTTOMRIGHT", -22, 20)',
    'CreateStatGroup("OFFENSE", 182, -52, 158',
    'CreateStatGroup("DEFENSE", 350, -52, 158',
    'CreateStatGroup("MAGIC / RESISTANCES", 518, -52, 158',
    'CreateStatGroup("PRIMARY ATTRIBUTES"',
    'CreateStatGroup("OFFENSE"',
    'CreateStatGroup("DEFENSE"',
    'CreateStatGroup("MAGIC / RESISTANCES"',
    'self.CharacterSheetStatValues[definition.key] = value',
    'SetPercent("crit", stats.crit)',
    'SetInteger("shadowResistance", stats.shadowResistance)',
):
    assert token in character_sheet, f"Missing character-sheet stat layout hook: {token}"

assert 'self.CharacterSheetStatRows' not in character_sheet, "Legacy centered character-sheet stat stack still exists"
assert 'statsFrame:SetSize(156, 144)' not in character_sheet, "Legacy 156x144 overlapping stat frame still exists"

print("Character sheet audit OK: paper-doll and backpack share the upper row; derived stats render in four structured columns below the backpack.")
