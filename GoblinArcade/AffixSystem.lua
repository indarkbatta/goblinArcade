local _, GA = ...

GA.AffixSystem = GA.AffixSystem or {}
local AS = GA.AffixSystem
AS.VERSION = 1
AS.ITEMIZATION_VERSION = 2

local STAT_META = {
 attackPower={label="Attack Power",scale=1.60,kind="integer"}, hit={label="Hit",scale=0.18,kind="percent"},
 crit={label="Critical Strike",scale=0.18,kind="percent"}, expertise={label="Expertise",scale=0.18,kind="percent"},
 weaponSkill={label="Weapon Skill",scale=0.45,kind="integer"}, armor={label="Armor",scale=4.00,kind="integer"},
 defense={label="Defense Skill",scale=0.60,kind="integer"}, dodge={label="Dodge",scale=0.18,kind="percent"},
 parry={label="Parry",scale=0.18,kind="percent"}, block={label="Block",scale=0.18,kind="percent"},
 blockValue={label="Block Value",scale=1.00,kind="integer"}, spellPower={label="Spell Power",scale=1.10,kind="integer"},
 healingPower={label="Healing Power",scale=1.20,kind="integer"}, mp5={label="MP5",scale=0.45,kind="integer"},
 arcaneResistance={label="Arcane Resistance",scale=0.90,kind="integer"}, fireResistance={label="Fire Resistance",scale=0.90,kind="integer"},
 frostResistance={label="Frost Resistance",scale=0.90,kind="integer"}, natureResistance={label="Nature Resistance",scale=0.90,kind="integer"},
 shadowResistance={label="Shadow Resistance",scale=0.90,kind="integer"},
}
AS.STAT_META = STAT_META
local QUALITY_BUDGET={[0]=0.85,[1]=0.90,[2]=1.00,[3]=1.15,[4]=1.35,[5]=1.60,[6]=1.85}
local SLOT_BUDGET={INVTYPE_HEAD=1.10,INVTYPE_NECK=0.85,INVTYPE_SHOULDER=1,INVTYPE_CHEST=1.18,INVTYPE_ROBE=1.18,INVTYPE_WAIST=0.95,INVTYPE_LEGS=1.15,INVTYPE_FEET=0.95,INVTYPE_WRIST=0.85,INVTYPE_HAND=0.95,INVTYPE_FINGER=0.82,INVTYPE_TRINKET=0.90,INVTYPE_CLOAK=0.88,INVTYPE_WEAPON=1,INVTYPE_WEAPONMAINHAND=1,INVTYPE_WEAPONOFFHAND=0.90,INVTYPE_2HWEAPON=1.18,INVTYPE_RANGED=1,INVTYPE_RANGEDRIGHT=1,INVTYPE_SHIELD=1.10,INVTYPE_HOLDABLE=0.90}
local function Round(v)return math.floor((tonumber(v)or 0)+0.5)end
local function Round1(v)return math.floor((tonumber(v)or 0)*10+0.5)/10 end
local function Set(v)local t=string.upper(tostring(v or "ANY"));if t=="" or t=="ANY" then return {ANY=true} end local r={} for x in string.gmatch(t,"[^,%s]+") do r[x]=true end return r end
local function Allows(v,w)local s=Set(v);return s.ANY or s[string.upper(tostring(w or ""))]==true end
local function MaxTier(q)q=math.max(0,math.floor(tonumber(q)or 1));if q<=2 then return 1 elseif q==3 then return 2 elseif q==4 then return 3 end return 4 end
function AS:GetAffixCount(q)q=math.max(0,math.floor(tonumber(q)or 1));if q<=1 then return 0 elseif q==2 then return 1 end return 2 end
function AS:GetDefinitions(k)local key=string.upper(tostring(k or ""))=="SUFFIX" and "suffixes" or "prefixes";return GA.StudioData and GA.StudioData[key] or {} end
function AS:IsCompatible(d,item,classId)
 if not d or not item or string.upper(tostring(d.enabled or "YES"))=="NO" or (tonumber(d.weight)or 0)<=0 then return false end
 if (tonumber(item.itemLevel)or 1)<math.max(1,tonumber(d.minItemLevel)or 1) or (tonumber(d.tier)or 1)>MaxTier(item.quality) then return false end
 return Allows(d.allowedSlots,item.equipLoc) and Allows(d.allowedItemTypes,item.category) and Allows(d.allowedClasses,classId or "ANY")
end
function AS:GetCandidates(k,item,classId)local r={} for _,d in ipairs(self:GetDefinitions(k)) do if self:IsCompatible(d,item,classId) then r[#r+1]=d end end return r end
local function Pick(list)local total=0 for _,d in ipairs(list or {})do total=total+math.max(0,tonumber(d.weight)or 0)end if total<=0 then return nil end local x,c=math.random()*total,0 for _,d in ipairs(list)do c=c+math.max(0,tonumber(d.weight)or 0) if x<=c then return d end end return list[#list] end
local function Find(list,id)if not id or tostring(id)=="" then return nil end for _,d in ipairs(list or {})do if tostring(d.id)==tostring(id)then return d end end end
function AS:GetBudget(item,d)local il=math.max(1,tonumber(item.itemLevel)or 1);local q=math.max(0,math.floor(tonumber(item.quality)or 1));local tier=math.max(1,math.floor(tonumber(d.tier)or 1));return(1.8+il*0.16)*(QUALITY_BUDGET[q]or 1.6)*(SLOT_BUDGET[item.equipLoc]or 1)*(1+(tier-1)*0.15)end
function AS:BuildAffix(d,k,item)
 if not d then return nil end local budget=self:GetBudget(item,d);local parts={{key=tostring(d.stat1 or ""),weight=math.max(0,tonumber(d.stat1Weight)or 0)},{key=tostring(d.stat2 or ""),weight=math.max(0,tonumber(d.stat2Weight)or 0)}};local total=0
 for _,p in ipairs(parts)do if STAT_META[p.key]then total=total+p.weight end end if total<=0 then return nil end
 local generated,stats={},{} for _,p in ipairs(parts)do local m=STAT_META[p.key] if m and p.weight>0 then local v=budget*(p.weight/total)*m.scale;v=m.kind=="percent" and Round1(v)or Round(v);if v>0 then generated[p.key]=(generated[p.key]or 0)+v;stats[#stats+1]={key=p.key,label=m.label,value=v,kind=m.kind}end end end
 if #stats==0 then return nil end return{id=tostring(d.id or ""),kind=string.upper(tostring(k or "PREFIX")),displayName=tostring(d.name or d.id or "Affix"),family=string.upper(tostring(d.family or "UTILITY")),tier=math.max(1,math.floor(tonumber(d.tier)or 1)),budget=math.floor(budget*100+0.5)/100,generatedStats=generated,stats=stats}
end
function AS:ApplyToItem(item,o)
 if not item or not item.equipLoc or item.category=="CONSUMABLE" then return item end if item.itemizationVersion==2 and item.affixesResolved then return item end o=type(o)=="table" and o or {}
 local classId=o.classId or(GA.RunState and(GA.RunState.classId or(GA.RunState.snapshot and GA.RunState.snapshot.classFile)))or"ANY";local selected={};local count=self:GetAffixCount(item.quality)
 local function add(kind,id) local defs=self:GetDefinitions(kind);local d=Find(defs,id);if d and not self:IsCompatible(d,item,classId)then d=nil end;d=d or Pick(self:GetCandidates(kind,item,classId));local a=self:BuildAffix(d,kind,item);if a then selected[#selected+1]=a end end
 if count>=1 then add("PREFIX",o.prefixId)end;if count>=2 then add("SUFFIX",o.suffixId)end
 local target=item.arcadeWeapon or item.arcadeItem;if target then for _,a in ipairs(selected)do for k,v in pairs(a.generatedStats or {})do target[k]=(tonumber(target[k])or 0)+v end end target.itemizationVersion=2 end
 item.baseName=item.baseName or item.name or item.studioItemId or"Dungeon Item";local pn,sn for _,a in ipairs(selected)do if a.kind=="PREFIX"then item.prefixId=a.id;pn=a.displayName else item.suffixId=a.id;sn=a.displayName end end
 local names={}if pn then names[#names+1]=pn end names[#names+1]=item.baseName if sn then names[#names+1]=sn end item.name=table.concat(names," ");item.affixes=selected;item.affixesResolved=true;item.itemizationVersion=2;if #selected>0 and item.price then item.price=Round((tonumber(item.price)or 0)*(1+#selected*0.12))end return item
end
