#!/usr/bin/env python3
import json
from pathlib import Path
r=Path(__file__).resolve().parents[1]
d=json.loads((r/"studio-data.json").read_text(encoding="utf-8")); a=(r/"GoblinArcade"/"AffixSystem.lua").read_text(encoding="utf-8"); db=(r/"GoblinArcade"/"ItemDatabase.lua").read_text(encoding="utf-8"); s=(r/"index.html").read_text(encoding="utf-8")
assert d["schemaVersion"]==18 and d["studioVersion"]=="1.17.0" and len(d["prefixes"])>=8 and len(d["suffixes"])>=8
valid={"attackPower","hit","crit","expertise","weaponSkill","armor","defense","dodge","parry","block","blockValue","spellPower","healingPower","mp5","arcaneResistance","fireResistance","frostResistance","natureResistance","shadowResistance"}
for k in ("prefixes","suffixes"):
 ids=set()
 for x in d[k]:
  assert x["id"] not in ids;ids.add(x["id"]);assert x["stat1"] in valid and(not x.get("stat2")or x["stat2"] in valid);assert 1<=int(x["tier"])<=4 and float(x["weight"])>0
for t in ("AS.ITEMIZATION_VERSION = 2","QUALITY_BUDGET","SLOT_BUDGET","function AS:GetAffixCount","function AS:IsCompatible","function AS:GetBudget","function AS:BuildAffix","function AS:ApplyToItem"):assert t in a
assert "DB.VERSION = 7" in db and "GA.AffixSystem:ApplyToItem" in db and 'items:{label:"Item Bases"' in s and 'prefixes:{label:"Prefixes"' in s and 'suffixes:{label:"Suffixes"' in s
print("Affix system audit OK: Item Bases, Prefixes/Suffixes and budget runtime wiring verified.")
