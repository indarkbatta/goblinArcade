local _, GA = ...

GA.ItemDatabase = GA.ItemDatabase or {}
local DB = GA.ItemDatabase

DB.VERSION = 1

local SLOT_LABELS = {
    INVTYPE_HEAD = "Head",
    INVTYPE_NECK = "Neck",
    INVTYPE_SHOULDER = "Shoulder",
    INVTYPE_CHEST = "Chest",
    INVTYPE_ROBE = "Chest",
    INVTYPE_WAIST = "Waist",
    INVTYPE_LEGS = "Legs",
    INVTYPE_FEET = "Feet",
    INVTYPE_WRIST = "Wrist",
    INVTYPE_HAND = "Hands",
    INVTYPE_FINGER = "Finger",
    INVTYPE_TRINKET = "Trinket",
    INVTYPE_CLOAK = "Back",
    INVTYPE_WEAPON = "Weapon",
    INVTYPE_WEAPONMAINHAND = "Main Hand",
    INVTYPE_WEAPONOFFHAND = "Off Hand",
    INVTYPE_2HWEAPON = "Two-Hand",
    INVTYPE_RANGED = "Ranged",
    INVTYPE_RANGEDRIGHT = "Ranged",
    INVTYPE_SHIELD = "Shield",
    INVTYPE_HOLDABLE = "Off Hand",
}

local function Round(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

local function Round1(value)
    return math.floor(((tonumber(value) or 0) * 10) + 0.5) / 10
end

local function NormalizeIcon(icon)
    if icon == nil or tostring(icon) == "" then
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    end

    local numeric = tonumber(icon)
    if numeric then
        return numeric
    end

    local path = tostring(icon)
    if string.find(path, "\\", 1, true) then
        return path
    end

    return "Interface\\Icons\\" .. path
end

local function ParseAllowedClasses(value)
    local result = {}
    local raw = string.upper(tostring(value or "ANY"))

    if raw == "" or raw == "ANY" then
        result.ANY = true
        return result
    end

    for token in string.gmatch(raw, "[^,%s]+") do
        result[token] = true
    end

    return result
end

function DB:GetItemDefinition(itemId)
    for _, item in ipairs(GA.StudioData and GA.StudioData.items or {}) do
        if item.id == itemId then
            return item
        end
    end
    return nil
end

function DB:GetLootEntries(source, floorNumber)
    local result = {}
    local wantedSource = string.upper(tostring(source or "TREASURE"))
    local floor = math.max(1, math.floor(tonumber(floorNumber) or 1))

    for _, entry in ipairs(GA.StudioData and GA.StudioData.loot or {}) do
        local enabled = string.upper(tostring(entry.enabled or "YES")) ~= "NO"
        local minFloor = math.max(1, math.floor(tonumber(entry.minFloor) or 1))
        local maxFloor = math.max(minFloor, math.floor(tonumber(entry.maxFloor) or 9))

        if enabled
            and string.upper(tostring(entry.source or "")) == wantedSource
            and floor >= minFloor
            and floor <= maxFloor
            and self:GetItemDefinition(entry.itemId) then
            result[#result + 1] = entry
        end
    end

    return result
end

function DB:IsItemAllowedForClass(item, classId)
    if not item then return false end

    local allowed = ParseAllowedClasses(item.allowedClasses)
    if allowed.ANY then return true end

    local wanted = string.upper(tostring(classId or ""))
    return wanted ~= "" and allowed[wanted] == true
end

function DB:BuildItemInstance(itemId, options)
    local definition = self:GetItemDefinition(itemId)
    if not definition then return nil end

    options = type(options) == "table" and options or {}
    local category = string.upper(tostring(definition.category or "ARMOR"))
    local equipLoc = tostring(definition.equipLoc or "NONE")
    local powerMultiplier = math.max(0.01, tonumber(options.powerMultiplier) or 1)
    local itemLevel = math.max(
        1,
        math.floor((tonumber(definition.itemLevel) or 1) + (tonumber(options.itemLevelBonus) or 0))
    )

    local item = {
        source = options.source or "dungeon",
        studioDefined = true,
        studioItemId = definition.id,
        itemDatabaseVersion = self.VERSION,
        name = definition.name or definition.id or "Dungeon Item",
        icon = NormalizeIcon(definition.icon),
        itemLevel = itemLevel,
        quality = math.max(0, math.floor(tonumber(definition.quality) or 1)),
        requiredLevel = math.max(1, math.floor(tonumber(definition.requiredLevel) or 1)),
        allowedClasses = tostring(definition.allowedClasses or "ANY"),
        category = category,
        itemSubType = definition.itemSubType or category,
        equipLoc = equipLoc ~= "NONE" and equipLoc or nil,
        slotLabel = SLOT_LABELS[equipLoc] or category,
        stackCount = math.max(1, math.floor(tonumber(options.quantity) or 1)),
        stackMax = math.max(1, math.floor(tonumber(definition.stackMax) or 1)),
        description = definition.description or "",
        consumableEffect = tostring(definition.consumableEffect or "NONE"),
        effectValue = tonumber(definition.effectValue) or 0,
    }

    if category == "WEAPON" then
        item.itemType = "Weapon"
        item.arcadeWeapon = {
            generatorVersion = "studio",
            sourceName = item.name,
            itemLevel = itemLevel,
            quality = item.quality,
            style = definition.itemSubType or "Weapon",
            damageMin = math.max(1, Round((tonumber(definition.damageMin) or 1) * powerMultiplier)),
            damageMax = math.max(1, Round((tonumber(definition.damageMax) or 1) * powerMultiplier)),
            speed = tostring(definition.weaponSpeed or "NORMAL"),
            range = math.max(1, math.floor(tonumber(definition.range) or 1)),
            traitName = definition.traitName ~= "" and definition.traitName or nil,
            traitDescription = definition.traitDescription ~= "" and definition.traitDescription or nil,
        }
        if item.arcadeWeapon.damageMax < item.arcadeWeapon.damageMin then
            item.arcadeWeapon.damageMax = item.arcadeWeapon.damageMin
        end
    elseif category == "CONSUMABLE" then
        item.itemType = "Consumable"
    else
        item.itemType = "Armor"
        item.arcadeItem = {
            generatorVersion = "studio",
            sourceName = item.name,
            itemLevel = itemLevel,
            quality = item.quality,
            style = definition.itemSubType or category,
            equipLoc = item.equipLoc,
            health = math.max(0, Round((tonumber(definition.health) or 0) * powerMultiplier)),
            armor = math.max(0, Round((tonumber(definition.armor) or 0) * powerMultiplier)),
            dodge = math.max(0, Round1((tonumber(definition.dodge) or 0) * powerMultiplier)),
            crit = math.max(0, Round1((tonumber(definition.crit) or 0) * powerMultiplier)),
            block = math.max(0, Round1((tonumber(definition.block) or 0) * powerMultiplier)),
            traitName = definition.traitName ~= "" and definition.traitName or nil,
            traitDescription = definition.traitDescription ~= "" and definition.traitDescription or nil,
        }
    end

    return item
end

function DB:RollLoot(source, floorNumber)
    local entries = self:GetLootEntries(source, floorNumber)
    if #entries == 0 then return nil end

    local totalWeight = 0
    for _, entry in ipairs(entries) do
        totalWeight = totalWeight + math.max(0, tonumber(entry.weight) or 0)
    end

    if totalWeight <= 0 then
        return nil
    end

    local roll = math.random() * totalWeight
    local cursor = 0
    local selected = entries[#entries]

    for _, entry in ipairs(entries) do
        cursor = cursor + math.max(0, tonumber(entry.weight) or 0)
        if roll <= cursor then
            selected = entry
            break
        end
    end

    return self:BuildItemInstance(selected.itemId, {
        source = string.lower(tostring(source or "dungeon")),
        itemLevelBonus = tonumber(selected.itemLevelBonus) or 0,
        powerMultiplier = tonumber(selected.powerMultiplier) or 1,
        quantity = tonumber(selected.quantity) or 1,
    })
end

function GA:GetStudioItemDefinition(itemId)
    return self.ItemDatabase and self.ItemDatabase:GetItemDefinition(itemId) or nil
end

function GA:BuildStudioItem(itemId, options)
    return self.ItemDatabase and self.ItemDatabase:BuildItemInstance(itemId, options) or nil
end

function GA:RollStudioLoot(source, floorNumber)
    return self.ItemDatabase and self.ItemDatabase:RollLoot(source, floorNumber) or nil
end
