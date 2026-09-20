local _, GA = ...

GA.ItemGenerator = GA.ItemGenerator or {}
local IG = GA.ItemGenerator

IG.VERSION = 4

local QUALITY_MULTIPLIER = {
    [0] = 0.80,
    [1] = 1.00,
    [2] = 1.15,
    [3] = 1.30,
    [4] = 1.50,
    [5] = 1.75,
    [6] = 2.00,
    [7] = 1.40,
}

local PROFILES = {
    INVTYPE_HEAD =      { style = "Guard",     armor = 1.00, health = 0.55, dodge = 0.10, crit = 0.00, attackPower = 0.10, trait = "WATCHFUL" },
    INVTYPE_NECK =      { style = "Charm",     armor = 0.00, dodge = 0.35, crit = 0.45, attackPower = 0.45, trait = "BALANCE" },
    INVTYPE_SHOULDER =  { style = "Guard",     armor = 0.85, health = 0.45, dodge = 0.10, crit = 0.00, attackPower = 0.20, trait = "FORTIFIED" },
    INVTYPE_CHEST =     { style = "Bulwark",   armor = 1.45, health = 1.00, dodge = 0.00, crit = 0.00, attackPower = 0.15, trait = "BULWARK" },
    INVTYPE_ROBE =      { style = "Bulwark",   armor = 1.45, health = 1.00, dodge = 0.00, crit = 0.00, attackPower = 0.15, trait = "BULWARK" },
    INVTYPE_WAIST =     { style = "Guard",     armor = 0.70, dodge = 0.10, crit = 0.00, attackPower = 0.30, trait = "FORTIFIED" },
    INVTYPE_LEGS =      { style = "Bulwark",   armor = 1.20, health = 0.80, dodge = 0.00, crit = 0.00, attackPower = 0.15, trait = "BULWARK" },
    INVTYPE_FEET =      { style = "Footwork",  armor = 0.65, dodge = 1.00, crit = 0.00, attackPower = 0.15, trait = "FOOTWORK" },
    INVTYPE_WRIST =     { style = "Reflex",    armor = 0.45, dodge = 0.65, crit = 0.00, attackPower = 0.35, trait = "REFLEX" },
    INVTYPE_HAND =      { style = "Precision", armor = 0.55, dodge = 0.00, crit = 1.00, attackPower = 0.75, trait = "PRECISION" },
    INVTYPE_FINGER =    { style = "Luck",      armor = 0.00, dodge = 0.35, crit = 0.85, attackPower = 0.65, trait = "LUCK" },
    INVTYPE_TRINKET =   { style = "Charm",     armor = 0.00, dodge = 0.65, crit = 0.65, attackPower = 1.00, trait = "CHARMED" },
    INVTYPE_CLOAK =     { style = "Evasion",   armor = 0.35, dodge = 1.10, crit = 0.20, attackPower = 0.30, trait = "EVASION" },
    INVTYPE_SHIELD =    { style = "Shield",    armor = 1.55, dodge = 0.10, crit = 0.00, block = 1.00, attackPower = 0.00, trait = "BLOCK" },
    INVTYPE_HOLDABLE =  { style = "Focus",     armor = 0.00, dodge = 0.20, crit = 1.10, attackPower = 0.65, trait = "FOCUS" },
}

local function Contains(text, needle)
    return text and string.find(string.lower(text), needle, 1, true) ~= nil
end

local function MaterialMultiplier(itemSubType)
    if Contains(itemSubType, "plate") then return 1.20 end
    if Contains(itemSubType, "mail") then return 1.10 end
    if Contains(itemSubType, "leather") then return 1.00 end
    if Contains(itemSubType, "cloth") then return 0.90 end
    if Contains(itemSubType, "shield") then return 1.25 end
    return 1.00
end

local function Round(value)
    return math.floor(value + 0.5)
end

local function Round1(value)
    return math.floor(value * 10 + 0.5) / 10
end

local function BuildTrait(profile, armor, dodge, crit, block, quality)
    if not profile.trait or quality < 2 then
        return nil, nil
    end

    local primaryText

    if (block or 0) > 0 then
        primaryText = string.format("+%.1f%% Block.", block)
    elseif (dodge or 0) >= (crit or 0) and (dodge or 0) > 0 then
        primaryText = string.format("+%.1f%% Dodge.", dodge)
    elseif (crit or 0) > 0 then
        primaryText = string.format("+%.1f%% Critical Strike.", crit)
    else
        primaryText = string.format("+%d Armor.", armor or 0)
    end

    return profile.trait, primaryText
end

function IG:Convert(metadata)
    if not metadata or not metadata.equipLoc then
        return nil
    end

    local profile = PROFILES[metadata.equipLoc]
    if not profile then
        return nil
    end

    local itemLevel = math.max(1, tonumber(metadata.itemLevel) or 1)
    local quality = tonumber(metadata.quality) or 1
    local qualityMultiplier = QUALITY_MULTIPLIER[quality] or 1.00
    local materialMultiplier = MaterialMultiplier(metadata.itemSubType)

    local armorBase = 1 + itemLevel * 0.12
    local healthBase = 3 + itemLevel * 0.65
    local secondaryBase = 0.25 + itemLevel * 0.02
    local blockBase = 0.35 + itemLevel * 0.025
    local attackPowerBase = 1 + itemLevel * 0.10

    local armor = math.max(0, Round(
        armorBase * (profile.armor or 0) * materialMultiplier * qualityMultiplier
    ))

    local rawHealth = math.max(0, Round(
        healthBase * (profile.health or 0) * materialMultiplier * qualityMultiplier
    ))
    local health = rawHealth > 0 and GA:ScaleCombatValue(rawHealth) or 0

    local dodge = math.max(0, Round1(
        secondaryBase * (profile.dodge or 0) * qualityMultiplier
    ))

    local crit = math.max(0, Round1(
        secondaryBase * (profile.crit or 0) * qualityMultiplier
    ))

    local block = math.max(0, Round1(
        blockBase * (profile.block or 0) * qualityMultiplier
    ))

    local attackPower = math.max(0, Round(
        attackPowerBase * (profile.attackPower or 0) * qualityMultiplier
    ))

    local traitName, traitDescription = BuildTrait(
        profile, armor, dodge, crit, block, quality
    )

    return {
        generatorVersion = self.VERSION,
        sourceItemID = metadata.itemID,
        sourceName = metadata.name,
        itemLevel = itemLevel,
        quality = quality,
        style = profile.style,
        equipLoc = metadata.equipLoc,
        armor = armor,
        health = health,
        dodge = dodge,
        crit = crit,
        block = block,
        attackPower = attackPower,
        traitName = traitName,
        traitDescription = traitDescription,
    }
end
