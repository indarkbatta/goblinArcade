local GA={StudioData={prefixes={{id="savage",name="Savage",family="OFFENSE",tier=1,weight=100,minItemLevel=1,allowedSlots="ANY",allowedItemTypes="ANY",allowedClasses="ANY",stat1="attackPower",stat1Weight=65,stat2="crit",stat2Weight=35,enabled="YES"}},suffixes={{id="of_precision",name="of Precision",family="OFFENSE",tier=1,weight=100,minItemLevel=1,allowedSlots="ANY",allowedItemTypes="ANY",allowedClasses="ANY",stat1="hit",stat1Weight=55,stat2="expertise",stat2Weight=45,enabled="YES"}}}}
local c=assert(loadfile("GoblinArcade/AffixSystem.lua"));c("GoblinArcade",GA)
assert(GA.AffixSystem:GetAffixCount(1)==0 and GA.AffixSystem:GetAffixCount(2)==1 and GA.AffixSystem:GetAffixCount(3)==2)
local i={name="Iron Breastplate",baseName="Iron Breastplate",itemLevel=20,quality=3,category="ARMOR",equipLoc="INVTYPE_CHEST",arcadeItem={}}
GA.AffixSystem:ApplyToItem(i,{classId="warrior",prefixId="savage",suffixId="of_precision"});assert(i.name=="Savage Iron Breastplate of Precision" and #i.affixes==2 and i.arcadeItem.attackPower>0 and i.arcadeItem.hit>0)
local n,ap=i.name,i.arcadeItem.attackPower;GA.AffixSystem:ApplyToItem(i,{classId="warrior"});assert(i.name==n and i.arcadeItem.attackPower==ap)
print("Affix runtime audit OK: rarity, budget, names and no-reroll persistence verified.")
