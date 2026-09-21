#!/usr/bin/env python3
from pathlib import Path

source = Path("GoblinArcade/DungeonRun.lua").read_text(encoding="utf-8")

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
