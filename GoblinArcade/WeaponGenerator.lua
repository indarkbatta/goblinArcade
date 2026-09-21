local _, GA = ...

GA.WeaponGenerator = GA.WeaponGenerator or {}
local WG = GA.WeaponGenerator

WG.VERSION = 3

local ARCHETYPES = {
    Dagger = { multiplier = 0.78, spread = 0.25, speed = "FAST", seconds = 1.8, range = 1, trait = "BACKSTAB", traitValues = { [2]=35,[3]=45,[4]=55,[5]=65,[6]=75 } },
    Sword = { multiplier = 0.95, spread = 0.30, speed = "NORMAL", seconds = 2.4, range = 1, trait = "GUARD", traitValues = { [2]=5,[3]=8,[4]=12,[5]=16,[6]=20 } },
    Axe = { multiplier = 1.02, spread = 0.38, speed = "NORMAL", seconds = 2.5, range = 1, trait = "CLEAVE", traitValues = { [2]=20,[3]=25,[4]=30,[5]=35,[6]=40 } },
    Mace = { multiplier = 1.05, spread = 0.35, speed = "NORMAL", seconds = 2.6, range = 1, trait = "STAGGER", traitValues = { [2]=15,[3]=20,[4]=25,[5]=30,[6]=35 } },
    Staff = { multiplier = 0.95, spread = 0.30, speed = "SLOW", seconds = 3.2, range = 2, trait = "SWEEP", traitValues = { [2]=25,[3]=35,[4]=45,[5]=55,[6]=65 } },
    Polearm = { multiplier = 1.08, spread = 0.35, speed = "SLOW", seconds = 3.4, range = 2, trait = "IMPALE", traitValues = { [2]=20,[3]=30,[4]=40,[5]=50,[6]=60 } },
    Bow = { multiplier = 0.92, spread = 0.28, speed = "NORMAL", seconds = 2.7, range = 4, trait = "PRECISE", traitValues = { [2]=6,[3]=9,[4]=12,[5]=15,[6]=18 } },
    Gun = { multiplier = 1.02, spread = 0.38, speed = "SLOW", seconds = 3.0, range = 4, trait = "IMPACT", traitValues = { [2]=20,[3]=30,[4]=40,[5]=50,[6]=60 } },
    Crossbow = { multiplier = 1.05, spread = 0.35, speed = "SLOW", seconds = 3.1, range = 4, trait = "PUNCTURE", traitValues = { [2]=10,[3]=15,[4]=20,[5]=25,[6]=30 } },
    Wand = { multiplier = 0.72, spread = 0.20, speed = "FAST", seconds = 1.8, range = 4, trait = "FOCUS", traitValues = { [2]=10,[3]=15,[4]=20,[5]=25,[6]=30 } },
    Fist = { multiplier = 0.82, spread = 0.25, speed = "FAST", seconds = 1.7, range = 1, trait = "FLURRY", traitValues = { [2]=15,[3]=20,[4]=25,[5]=30,[6]=35 } },
    Weapon = { multiplier = 0.95, spread = 0.30, speed = "NORMAL", seconds = 2.4, range = 1 },
}

local function Contains(text, needle) return text and string.find(string.lower(text), needle, 1, true) ~= nil end
local function Round(value) return math.floor((tonumber(value) or 0) + 0.5) end
local function Stat(metadata, key) local s=metadata and metadata.itemStats; return s and tonumber(s[key]) or nil end
local function ResolveArchetype(sub)
    if Contains(sub,"dagger") then return "Dagger" end
    if Contains(sub,"sword") then return "Sword" end
    if Contains(sub,"axe") then return "Axe" end
    if Contains(sub,"mace") then return "Mace" end
    if Contains(sub,"staff") or Contains(sub,"staves") then return "Staff" end
    if Contains(sub,"polearm") then return "Polearm" end
    if Contains(sub,"crossbow") then return "Crossbow" end
    if Contains(sub,"bow") then return "Bow" end
    if Contains(sub,"gun") then return "Gun" end
    if Contains(sub,"wand") then return "Wand" end
    if Contains(sub,"fist") then return "Fist" end
    return "Weapon"
end
local function Handed(archetype, sub, loc)
    if loc=="INVTYPE_2HWEAPON" or Contains(sub,"two-handed") or archetype=="Staff" or archetype=="Polearm" then return "Two-Handed" end
    if archetype=="Bow" or archetype=="Gun" or archetype=="Crossbow" or archetype=="Wand" then return "Ranged" end
    return "One-Handed"
end
local function TraitText(name,value)
    local text={
        BACKSTAB="+%d%% damage when attacking from behind.",
        GUARD="After attacking, gain +%d%% Parry until your next turn.",
        CLEAVE="An adjacent enemy takes %d%% of the attack's damage.",
        STAGGER="%d%% chance to delay the target's next action.",
        SWEEP="A second adjacent target takes %d%% damage.",
        IMPALE="Attacks at range 2 deal +%d%% damage.",
        PRECISE="+%d%% critical strike chance at maximum range.",
        IMPACT="Deal +%d%% damage to enemies at full health.",
        PUNCTURE="Ignore %d%% of the target's Armor.",
        FOCUS="Repeated attacks on the same target gain +%d%% damage.",
        FLURRY="%d%% chance for an immediate half-damage follow-up hit.",
    }
    return text[name] and string.format(text[name],value) or nil
end

function WG:Convert(metadata)
    if not metadata then return nil end
    local archetypeName=ResolveArchetype(metadata.itemSubType)
    local a=ARCHETYPES[archetypeName] or ARCHETYPES.Weapon
    local handed=Handed(archetypeName,metadata.itemSubType,metadata.equipLoc)
    local ilvl=math.max(1,tonumber(metadata.itemLevel) or 1)
    local quality=tonumber(metadata.quality) or 1
    local mult=a.multiplier * (handed=="Two-Handed" and 1.22 or 1)
    local base=3+math.floor(ilvl*0.55)
    local min=math.max(1,Round(base*mult))
    local max=math.max(min,min+math.max(2,Round(min*a.spread)))
    if GA.ScaleCombatValue then min=GA:ScaleCombatValue(min); max=math.max(min,GA:ScaleCombatValue(max)) end
    local seconds=a.seconds
    if handed=="Two-Handed" and seconds<3.0 then seconds=3.2 end
    local traitName,traitValue,traitDescription
    if quality>=2 and a.trait and a.traitValues then
        traitName=a.trait
        traitValue=a.traitValues[math.min(quality,6)] or a.traitValues[2]
        traitDescription=TraitText(traitName,traitValue)
    end
    local primaryBudget=(1+ilvl*0.06)*math.max(1,quality)
    return {
        generatorVersion=self.VERSION,
        ruleset=GA.ForeverRules and GA.ForeverRules.ID or "FOREVER_CLASSIC_BETA",
        sourceItemID=metadata.itemID, sourceName=metadata.name, itemLevel=ilvl, quality=quality,
        archetype=archetypeName, handedness=handed, style=handed.." "..archetypeName,
        damageMin=min, damageMax=max, speed=a.speed, weaponSpeedSeconds=seconds, range=a.range,
        strength=Stat(metadata,"ITEM_MOD_STRENGTH_SHORT") or (handed=="Two-Handed" and Round(primaryBudget*0.5) or 0),
        agility=Stat(metadata,"ITEM_MOD_AGILITY_SHORT") or ((archetypeName=="Dagger" or archetypeName=="Fist") and Round(primaryBudget*0.45) or 0),
        stamina=Stat(metadata,"ITEM_MOD_STAMINA_SHORT") or Round(primaryBudget*0.25),
        intellect=Stat(metadata,"ITEM_MOD_INTELLECT_SHORT") or 0,
        spirit=Stat(metadata,"ITEM_MOD_SPIRIT_SHORT") or 0,
        attackPower=Stat(metadata,"ITEM_MOD_ATTACK_POWER_SHORT") or 0,
        hit=quality>=3 and 0.5 or 0, crit=quality>=2 and 0.4 or 0, expertise=quality>=4 and 0.5 or 0,
        weaponSkill=0,
        traitName=traitName, traitValue=traitValue, traitDescription=traitDescription,
    }
end
