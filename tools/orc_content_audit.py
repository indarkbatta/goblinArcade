#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = json.loads((ROOT / "studio-data.json").read_text(encoding="utf-8"))

EXPECTED = {
    "orc_raider": "Media/Monsters/ork_raider_128x128.png",
    "orc_berserker": "Media/Monsters/ork_berserker_128x128.png",
    "orc_bonebreaker": "Media/Monsters/ork_bonebreaker_128x128.png",
    "orc_bonepicker": "Media/Monsters/ork_bonepicker_128x128.png",
    "orc_grave_champion": "Media/Monsters/ork_grave_champion_128x128.png",
    "orc_gravedigger": "Media/Monsters/ork_gravedigger_128x128.png",
    "orc_hexer": "Media/Monsters/ork_hexer_128x128.png",
    "orc_plague_eater": "Media/Monsters/ork_plague_eater_128x128.png",
    "orc_tomb_sentinel": "Media/Monsters/ork_tomb_sentinel_128x128.png",
    "orc_warcaller": "Media/Monsters/ork_warcaller_128x128.png",
}
SUPPORTED_EFFECTS = {"DAMAGE","DAMAGE_DOT","ROOT","SLOW","HEAL","BUFF_DAMAGE"}
SUPPORTED_CONDITIONS = {"ALWAYS","ADJACENT","RANGE_MIN","SELF_HP_BELOW","TARGET_HP_BELOW","EVERY_N_TURNS","ONCE_PER_COMBAT"}

enemies = {row["id"]: row for row in DATA.get("enemies", [])}
skills = {row["id"]: row for row in DATA.get("monsterSkills", [])}

for enemy_id, sprite in EXPECTED.items():
    assert enemy_id in enemies, f"Missing enemy: {enemy_id}"
    row = enemies[enemy_id]
    assert row.get("sprite") == sprite, f"{enemy_id}: wrong sprite path"
    assert (ROOT / "GoblinArcade" / sprite).is_file(), f"{enemy_id}: sprite file missing"
    assigned = row.get("skillIds") or []
    assert len(assigned) == 3, f"{enemy_id}: expected exactly 3 authored skills"
    assert len(set(assigned)) == 3, f"{enemy_id}: duplicate skill assignment"
    for skill_id in assigned:
        assert skill_id in skills, f"{enemy_id}: missing skill {skill_id}"
        assert skill_id.startswith(enemy_id + "_"), f"{enemy_id}: skill is not enemy-specific: {skill_id}"
        skill = skills[skill_id]
        assert skill.get("effect") in SUPPORTED_EFFECTS, f"{skill_id}: unsupported effect"
        assert skill.get("condition") in SUPPORTED_CONDITIONS, f"{skill_id}: unsupported condition"
        assert 0 <= int(skill.get("minFloor", 0)) <= 9, f"{skill_id}: invalid minFloor"
        assert int(skill.get("cooldownTurns", 0)) >= 0, f"{skill_id}: invalid cooldown"
        assert int(skill.get("range", 0)) >= 0, f"{skill_id}: invalid range"
        assert int(skill.get("priority", 0)) > 0, f"{skill_id}: priority must be positive"

print(f"Orc content audit OK: {len(EXPECTED)} enemies, {sum(len(enemies[e]['skillIds']) for e in EXPECTED)} unique authored skill assignments, all sprite files present.")
