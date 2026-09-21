local _, GA = ...

GA.ItemGenerator = GA.ItemGenerator or {}
local IG = GA.ItemGenerator

IG.VERSION = 5

local QUALITY_MULTIPLIER = {
    [0] = 0.80, [1] = 1.00, [2] = 1.15, [3] = 1.30,
    [4] = 1.50, [5] = 1.75, [6] = 2.00, [7] = 1.40,
}

local SLOT = {
    INVTYPE_HEAD =      { armor = 1.00, sta = 0.70, primary = 0.55, defense = 0.20, crit = 0.10 },
    INVTYPE_NECK =      { armor = 0.00, sta = 0.30, primary = 0.45, hit = 0.35, crit = 0.35, expertise = 0.15 },
    INVTYPE_SHOULDER =  { armor = 0.85, sta = 0.55, primary = 0.50, defense = 0.20 },
    INVTYPE_CHEST =     { armor = 1.45, sta = 1.00, primary = 0.65, defense = 0.35 },
    INVTYPE_ROBE =      { armor = 1.45, sta = 0.75, primary = 0.70, crit = 0.20 },
    INVTYPE_WAIST =     { armor = 0.70, sta = 0.50, primary = 0.45, hit = 0.15 },
    INVTYPE_LEGS =      { armor = 1.20, sta = 0.85, primary = 0.60, defense = 0.25 },
    INVTYPE_FEET =      { armor = 0.65, sta = 0.40, primary = 0.40, dodge = 0.35 },
    INVTYPE_WRIST =     { armor = 0.45, sta = 0.35, primary = 0.35, hit = 0.15 },
    INVTYPE_HAND =      { armor = 0.55, sta = 0.35, primary = 0.55, hit = 0.20, crit = 0.25, expertise = 0.15 },
    INVTYPE_FINGER =    { armor = 0.00, sta = 0.25, primary = 0.35, hit = 0.25, crit = 0.30, expertise = 0.15 },
    INVTYPE_TRINKET =   { armor = 0.00, sta = 0.35, primary = 0.40, hit = 0.20, crit = 0.25 },
    INVTYPE_CLOAK =     { armor = 0.35, sta = 0.35, primary = 0.35, dodge = 0.25, defense = 0.15 },
    INVTYPE_SHIELD =    { armor = 1.80, sta = 0.80, primary = 0.35, block = 0.65, defense = 0.45, blockValue = 1.00 },
    INVTYPE_HOLDABLE =  { armor = 0.00, sta = 0.20, primary = 0.55, hit = 0.20, crit = 0.30 },
}

local function Contains(text, needle)
    return text and string.find(string.lower(text), needle, 1, true) ~= nil
end

local function Round(value) return math.floor((tonumber(value) or 0) + 0.5) end
local function Round1(value) return math.floor((tonumber(value) or 0) * 10 + 0.5) / 10 end

local function ReadItemStat(metadata, key)
    local stats = metadata and metadata.itemStats
    return stats and tonumber(stats[key]) or nil
end

local function Material(metadata)
    local subtype = tostring(metadata and metadata.itemSubType or "")
    if Contains(subtype, "plate") then return "PLATE", 1.20 end
    if Contains(subtype, "mail") then return "MAIL", 1.10 end
    if Contains(subtype, "leather") then return "LEATHER", 1.00 end
    if Contains(subtype, "cloth") then return "CLOTH", 0.90 end
    if Contains(subtype, "shield") then return "SHIELD", 1.30 end
    return "OTHER", 1.00
end

local function PrimaryWeights(material)
    if material == "PLATE" or material == "SHIELD" then return 0.65, 0.10, 0.10, 0.15 end
    if material == "MAIL" then return 0.35, 0.35, 0.15, 0.15 end
    if material == "LEATHER" then return 0.15, 0.60, 0.10, 0.15 end
    if material == "CLOTH" then return 0.05, 0.10, 0.60, 0.25 end
    return 0.30, 0.30, 0.20, 0.20
end

function IG:Convert(metadata)
    if not metadata or not metadata.equipLoc then return nil end
    local profile = SLOT[metadata.equipLoc]
    if not profile then return nil end

    local itemLevel = math.max(1, tonumber(metadata.itemLevel) or 1)
    local quality = tonumber(metadata.quality) or 1
    local q = QUALITY_MULTIPLIER[quality] or 1
    local material, materialArmor = Material(metadata)
    local strWeight, agiWeight, intWeight, spiWeight = PrimaryWeights(material)

    local primaryBudget = (1.5 + itemLevel * 0.12) * q * (profile.primary or 0)
    local staminaBudget = (1.5 + itemLevel * 0.11) * q * (profile.sta or 0)
    local strength = ReadItemStat(metadata, "ITEM_MOD_STRENGTH_SHORT") or Round(primaryBudget * strWeight)
    local agility = ReadItemStat(metadata, "ITEM_MOD_AGILITY_SHORT") or Round(primaryBudget * agiWeight)
    local intellect = ReadItemStat(metadata, "ITEM_MOD_INTELLECT_SHORT") or Round(primaryBudget * intWeight)
    local spirit = ReadItemStat(metadata, "ITEM_MOD_SPIRIT_SHORT") or Round(primaryBudget * spiWeight)
    local stamina = ReadItemStat(metadata, "ITEM_MOD_STAMINA_SHORT") or Round(staminaBudget)

    local armor = ReadItemStat(metadata, "ITEM_MOD_ARMOR_SHORT")
        or Round((8 + itemLevel * 1.8) * (profile.armor or 0) * materialArmor * q)
    local attackPower = ReadItemStat(metadata, "ITEM_MOD_ATTACK_POWER_SHORT") or 0

    local secondaryBase = math.max(0.10, 0.18 + itemLevel * 0.012) * q
    local hit = Round1(secondaryBase * (profile.hit or 0))
    local crit = Round1(secondaryBase * (profile.crit or 0))
    local expertise = Round1(secondaryBase * (profile.expertise or 0))
    local dodge = Round1(secondaryBase * (profile.dodge or 0))
    local defense = Round(secondaryBase * 5 * (profile.defense or 0))
    local block = Round1(secondaryBase * (profile.block or 0))
    local blockValue = Round((1 + itemLevel * 0.08) * q * (profile.blockValue or 0))

    local health = GA.ScaleCombatValue and GA:ScaleCombatValue(stamina * 10, false) or stamina
    return {
        generatorVersion = self.VERSION,
        ruleset = GA.ForeverRules and GA.ForeverRules.ID or "FOREVER_CLASSIC_BETA",
        sourceItemID = metadata.itemID,
        sourceName = metadata.name,
        itemLevel = itemLevel,
        quality = quality,
        style = material,
        equipLoc = metadata.equipLoc,
        strength = math.max(0, strength),
        agility = math.max(0, agility),
        stamina = math.max(0, stamina),
        intellect = math.max(0, intellect),
        spirit = math.max(0, spirit),
        armor = math.max(0, armor),
        attackPower = math.max(0, attackPower),
        hit = hit,
        crit = crit,
        expertise = expertise,
        defense = math.max(0, defense),
        dodge = dodge,
        parry = 0,
        block = block,
        blockValue = math.max(0, blockValue),
        weaponSkill = 0,
        spellPower = 0,
        healingPower = 0,
        health = health,
    }
end
