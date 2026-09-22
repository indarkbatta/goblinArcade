local _, GA = ...

GA.ItemDatabase = GA.ItemDatabase or {}
local DB = GA.ItemDatabase

DB.VERSION = 7

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

function DB:GetLootTableDefinition(tableId)
    for _, record in ipairs(GA.StudioData and GA.StudioData.lootTables or {}) do
        if record.id == tableId then
            return record
        end
    end
    return nil
end

function DB:GetObjectDefinition(objectId)
    for _, record in ipairs(GA.StudioData and GA.StudioData.objects or {}) do
        if record.id == objectId then
            return record
        end
    end
    return nil
end

function DB:GetLootEntries(tableId, floorNumber)
    local result = {}
    local floor = math.max(1, math.floor(tonumber(floorNumber) or 1))

    for _, entry in ipairs(GA.StudioData and GA.StudioData.loot or {}) do
        local enabled = string.upper(tostring(entry.enabled or "YES")) ~= "NO"
        local minFloor = math.max(1, math.floor(tonumber(entry.minFloor) or 1))
        local maxFloor = math.max(minFloor, math.floor(tonumber(entry.maxFloor) or 9))

        if enabled
            and entry.tableId == tableId
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
        baseName = definition.name or definition.id or "Dungeon Item",
        itemizationVersion = 2,
        icon = NormalizeIcon(definition.icon),
        itemLevel = itemLevel,
        tier = tostring(definition.tier or "T0"),
        buildProfile = tostring(definition.buildProfile or "NONE"),
        quality = math.max(0, math.floor(tonumber(definition.quality) or 1)),
        requiredLevel = math.max(1, math.floor(tonumber(definition.requiredLevel) or 1)),
        price = math.max(0, math.floor(tonumber(definition.price) or 0)),
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
            generatorVersion="studio", itemizationVersion=2, sourceName=item.baseName, itemLevel=itemLevel, quality=item.quality,
            style=definition.itemSubType or "Weapon", damageMin=math.max(1,Round((tonumber(definition.damageMin)or 1)*powerMultiplier)),
            damageMax=math.max(1,Round((tonumber(definition.damageMax)or 1)*powerMultiplier)), speed=tostring(definition.weaponSpeed or "NORMAL"),
            range=math.max(1,math.floor(tonumber(definition.range)or 1)),
            strength=math.max(0,Round((tonumber(definition.strength)or 0)*powerMultiplier)), agility=math.max(0,Round((tonumber(definition.agility)or 0)*powerMultiplier)),
            stamina=math.max(0,Round((tonumber(definition.stamina)or 0)*powerMultiplier)), intellect=math.max(0,Round((tonumber(definition.intellect)or 0)*powerMultiplier)), spirit=math.max(0,Round((tonumber(definition.spirit)or 0)*powerMultiplier)),
            attackPower=0,hit=0,crit=0,expertise=0,weaponSkill=0,spellPower=0,healingPower=0,
            weaponSpeedSeconds=tonumber(definition.weaponSpeedSeconds)or nil,traitName=definition.traitName~="" and definition.traitName or nil,
            traitValue=math.max(0,tonumber(definition.traitValue)or 0),buildProfile=tostring(definition.buildProfile or "NONE"),
            traitDescription=definition.traitDescription~="" and definition.traitDescription or nil,
        }
        if item.arcadeWeapon.damageMax < item.arcadeWeapon.damageMin then item.arcadeWeapon.damageMax=item.arcadeWeapon.damageMin end
    elseif category == "CONSUMABLE" then
        item.itemType = "Consumable"
    else
        item.itemType = "Armor"
        item.arcadeItem = {
            generatorVersion="studio",itemizationVersion=2,sourceName=item.baseName,itemLevel=itemLevel,quality=item.quality,style=definition.itemSubType or category,equipLoc=item.equipLoc,
            health=math.max(0,Round((tonumber(definition.health)or 0)*powerMultiplier)),strength=math.max(0,Round((tonumber(definition.strength)or 0)*powerMultiplier)),
            agility=math.max(0,Round((tonumber(definition.agility)or 0)*powerMultiplier)),stamina=math.max(0,Round((tonumber(definition.stamina)or 0)*powerMultiplier)),
            intellect=math.max(0,Round((tonumber(definition.intellect)or 0)*powerMultiplier)),spirit=math.max(0,Round((tonumber(definition.spirit)or 0)*powerMultiplier)),
            armor=math.max(0,Round((tonumber(definition.armor)or 0)*powerMultiplier)),
            attackPower=0,hit=0,dodge=0,parry=0,crit=0,expertise=0,defense=0,block=0,blockValue=0,weaponSkill=0,spellPower=0,healingPower=0,mp5=0,
            arcaneResistance=0,fireResistance=0,frostResistance=0,natureResistance=0,shadowResistance=0,
            traitName=definition.traitName~="" and definition.traitName or nil,traitValue=math.max(0,tonumber(definition.traitValue)or 0),
            buildProfile=tostring(definition.buildProfile or "NONE"),traitDescription=definition.traitDescription~="" and definition.traitDescription or nil,
        }
    end
    if item.equipLoc and GA.AffixSystem and GA.AffixSystem.ApplyToItem then
        GA.AffixSystem:ApplyToItem(item,{classId=options.classId or(GA.RunState and(GA.RunState.classId or(GA.RunState.snapshot and GA.RunState.snapshot.classFile))),prefixId=options.prefixId,suffixId=options.suffixId})
    end
    return item
end

function DB:RollLootTable(tableId, floorNumber, sourceLabel)
    local definition = self:GetLootTableDefinition(tableId)
    if not definition then return nil end

    local dropChance = math.max(0, math.min(100, tonumber(definition.dropChance) or 100))
    if dropChance <= 0 then
        return nil
    end
    if dropChance < 100 and math.random() * 100 >= dropChance then
        return nil
    end

    local entries = self:GetLootEntries(tableId, floorNumber)
    if #entries == 0 then return nil end

    local totalWeight = 0
    for _, entry in ipairs(entries) do
        totalWeight = totalWeight + math.max(0, tonumber(entry.weight) or 0)
    end
    if totalWeight <= 0 then return nil end

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
        source = sourceLabel or tableId or "dungeon",
        itemLevelBonus = tonumber(selected.itemLevelBonus) or 0,
        powerMultiplier = tonumber(selected.powerMultiplier) or 1,
        quantity = tonumber(selected.quantity) or 1,
    })
end

function DB:BuildShopStock(tableId, floorNumber, classId, runLevel, count)
    local entries = self:GetLootEntries(tableId, floorNumber)
    local candidates = {}
    for _, entry in ipairs(entries) do
        local definition = self:GetItemDefinition(entry.itemId)
        if definition and self:IsItemAllowedForClass(definition, classId) then
            candidates[#candidates + 1] = entry
        end
    end

    local result = {}
    local wanted = math.max(1, math.floor(tonumber(count) or 4))

    while #result < wanted and #candidates > 0 do
        local totalWeight = 0
        for _, entry in ipairs(candidates) do
            totalWeight = totalWeight + math.max(0, tonumber(entry.weight) or 0)
        end
        if totalWeight <= 0 then break end

        local roll = math.random() * totalWeight
        local cursor = 0
        local selectedIndex = #candidates
        for index, entry in ipairs(candidates) do
            cursor = cursor + math.max(0, tonumber(entry.weight) or 0)
            if roll <= cursor then
                selectedIndex = index
                break
            end
        end

        local selected = table.remove(candidates, selectedIndex)
        local item = self:BuildItemInstance(selected.itemId, {
            source = "shop",
            itemLevelBonus = tonumber(selected.itemLevelBonus) or 0,
            powerMultiplier = tonumber(selected.powerMultiplier) or 1,
            quantity = tonumber(selected.quantity) or 1,
        })
        if item then
            result[#result + 1] = item
        end
    end

    return result
end

function DB:RollObjectLoot(objectId, floorNumber)
    local object = self:GetObjectDefinition(objectId)
    if not object or not object.lootTableId or object.lootTableId == "" then
        return nil
    end

    return self:RollLootTable(object.lootTableId, floorNumber, objectId)
end

function DB:GetEnemyLootTableId(enemyId)
    for _, record in ipairs(GA.StudioData and GA.StudioData.enemies or {}) do
        if record.id == enemyId then
            return record.lootTableId
        end
    end
    return nil
end

-- Temporary compatibility for any older call sites while the runtime migrates.
function DB:RollLoot(source, floorNumber)
    local map = {
        TREASURE = "treasure_chest",
        ELITE = "elite_cache",
    }
    local objectId = map[string.upper(tostring(source or ""))]
    return objectId and self:RollObjectLoot(objectId, floorNumber) or nil
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

function GA:RollLootTable(tableId, floorNumber, sourceLabel)
    return self.ItemDatabase
        and self.ItemDatabase:RollLootTable(tableId, floorNumber, sourceLabel)
        or nil
end

function GA:BuildDungeonShopStock(floorNumber, classId, runLevel, count)
    return self.ItemDatabase
        and self.ItemDatabase:BuildShopStock("shop_inventory", floorNumber, classId, runLevel, count)
        or {}
end

function GA:RollDungeonObjectLoot(objectId, floorNumber)
    return self.ItemDatabase
        and self.ItemDatabase:RollObjectLoot(objectId, floorNumber)
        or nil
end

function GA:GetDungeonObjectDefinition(objectId)
    return self.ItemDatabase
        and self.ItemDatabase:GetObjectDefinition(objectId)
        or nil
end
