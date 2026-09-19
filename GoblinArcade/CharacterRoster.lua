local _, GA = ...

local function CopyTable(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, child in pairs(value) do
        copy[key] = CopyTable(child)
    end
    return copy
end

local EQUIPMENT_SLOTS = {
    { key = "head", slotID = 1, label = "Head" },
    { key = "neck", slotID = 2, label = "Neck" },
    { key = "shoulder", slotID = 3, label = "Shoulder" },
    { key = "chest", slotID = 5, label = "Chest" },
    { key = "waist", slotID = 6, label = "Waist" },
    { key = "legs", slotID = 7, label = "Legs" },
    { key = "feet", slotID = 8, label = "Feet" },
    { key = "wrist", slotID = 9, label = "Wrist" },
    { key = "hands", slotID = 10, label = "Hands" },
    { key = "finger1", slotID = 11, label = "Finger 1" },
    { key = "finger2", slotID = 12, label = "Finger 2" },
    { key = "trinket1", slotID = 13, label = "Trinket 1" },
    { key = "trinket2", slotID = 14, label = "Trinket 2" },
    { key = "back", slotID = 15, label = "Back" },
    { key = "mainhand", slotID = 16, label = "Main Hand" },
    { key = "offhand", slotID = 17, label = "Off Hand" },
}

local function GetItemSnapshot(itemLink, icon, slotKey)
    if not itemLink then
        return nil
    end

    local name
    local quality
    local equipLoc

    if C_Item and C_Item.GetItemInfo then
        local a, _, c = C_Item.GetItemInfo(itemLink)
        if type(a) == "table" then
            name = a.itemName or a.name
            quality = a.itemQuality or a.quality
        else
            name = a
            quality = c
        end
    elseif type(GetItemInfo) == "function" then
        local a, _, c = GetItemInfo(itemLink)
        name = a
        quality = c
    end

    if C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, instantEquipLoc = C_Item.GetItemInfoInstant(itemLink)
        equipLoc = instantEquipLoc
    elseif type(GetItemInfoInstant) == "function" then
        local _, _, _, instantEquipLoc = GetItemInfoInstant(itemLink)
        equipLoc = instantEquipLoc
    end

    return {
        source = "wow",
        sourceSlot = slotKey,
        name = name or itemLink:match("%[(.-)%]") or "Equipped item",
        link = itemLink,
        icon = icon,
        quality = quality,
        equipLoc = equipLoc,
    }
end

function GA:GetEquipmentSlotDefinitions()
    return EQUIPMENT_SLOTS
end

function GA:SnapshotCurrentEquipment()
    local equipment = {}

    for _, slot in ipairs(EQUIPMENT_SLOTS) do
        local link = GetInventoryItemLink("player", slot.slotID)
        local icon = GetInventoryItemTexture("player", slot.slotID)

        if link then
            equipment[slot.key] = GetItemSnapshot(link, icon, slot.key)
        end
    end

    return equipment
end

local function GetDB()
    GoblinArcadeDB = GoblinArcadeDB or {}
    GoblinArcadeDB.version = GoblinArcadeDB.version or 1
    GoblinArcadeDB.characters = GoblinArcadeDB.characters or {}
    return GoblinArcadeDB
end

function GA:GetCurrentCharacterKey()
    local realm = GetRealmName and GetRealmName() or "Unknown Realm"
    local name = UnitName("player") or "Unknown"
    return realm .. ":" .. name
end

function GA:InitializeCharacterRoster()
    local db = GetDB()
    local key = self:GetCurrentCharacterKey()
    local character = db.characters[key] or {}

    character.key = key
    character.name = UnitName("player") or "Unknown"
    character.realm = GetRealmName and GetRealmName() or "Unknown Realm"
    character.level = UnitLevel("player") or 0

    local className, classFile = UnitClass("player")
    character.className = className or "Adventurer"
    character.classFile = classFile or "WARRIOR"
    character.raceName = UnitRace("player") or ""
    character.maxHealth = UnitHealthMax("player") or character.maxHealth or 0
    character.updatedAt = time and time() or 0
    character.equipment = self:SnapshotCurrentEquipment()

    db.characters[key] = character
    db.lastCharacterKey = key

    if not db.selectedCharacterKey or not db.characters[db.selectedCharacterKey] then
        db.selectedCharacterKey = key
    end

    self.SelectedCharacterKey = db.selectedCharacterKey
end

function GA:SyncCurrentCharacterRoster(weapon, source)
    local db = GetDB()
    local key = self:GetCurrentCharacterKey()
    local character = db.characters[key] or {}

    character.key = key
    character.name = UnitName("player") or "Unknown"
    character.realm = GetRealmName and GetRealmName() or "Unknown Realm"
    character.level = UnitLevel("player") or 0

    local className, classFile = UnitClass("player")
    character.className = className or "Adventurer"
    character.classFile = classFile or "WARRIOR"
    character.raceName = UnitRace("player") or ""
    character.maxHealth = UnitHealthMax("player") or 0
    character.updatedAt = time and time() or 0
    character.equipment = self:SnapshotCurrentEquipment()

    source = source or {}

    if source.clearWeapon then
        character.weapon = nil
        character.weaponName = nil
        character.weaponIcon = nil
        character.weaponLink = nil
        character.weaponItemLevel = nil
        character.weaponQuality = nil
        character.weaponSubtype = nil
    elseif weapon then
        character.weapon = CopyTable(weapon)
        character.weaponName = source.weaponName or weapon.sourceName
        character.weaponIcon = source.weaponIcon
        character.weaponLink = source.weaponLink
        character.weaponItemLevel = source.weaponItemLevel or weapon.itemLevel
        character.weaponQuality = source.weaponQuality or weapon.quality
        character.weaponSubtype = source.weaponSubtype or weapon.style

        if character.equipment and character.equipment.mainhand then
            character.equipment.mainhand.arcadeWeapon = CopyTable(weapon)
        end
    end

    db.characters[key] = character
    db.lastCharacterKey = key

    if not self.SelectedCharacterKey then
        self.SelectedCharacterKey = db.selectedCharacterKey or key
    end

    if self.RefreshDungeonCharacterSelection then
        self:RefreshDungeonCharacterSelection()
    end
end

function GA:GetCharacterRoster()
    local db = GetDB()
    local currentKey = self:GetCurrentCharacterKey()
    local roster = {}

    for key, character in pairs(db.characters) do
        if character and character.name then
            character.key = key
            roster[#roster + 1] = character
        end
    end

    table.sort(roster, function(a, b)
        if a.key == currentKey and b.key ~= currentKey then
            return true
        end
        if b.key == currentKey and a.key ~= currentKey then
            return false
        end
        if (a.level or 0) ~= (b.level or 0) then
            return (a.level or 0) > (b.level or 0)
        end
        return string.lower(a.name or "") < string.lower(b.name or "")
    end)

    return roster
end

function GA:SelectDungeonCharacter(key)
    local db = GetDB()
    if key and db.characters[key] then
        self.SelectedCharacterKey = key
        db.selectedCharacterKey = key
    end

    if self.RefreshDungeonCharacterSelection then
        self:RefreshDungeonCharacterSelection()
    end
end

function GA:GetSelectedDungeonCharacter()
    local db = GetDB()
    local key = self.SelectedCharacterKey or db.selectedCharacterKey or self:GetCurrentCharacterKey()

    if not db.characters[key] then
        key = self:GetCurrentCharacterKey()
    end

    self.SelectedCharacterKey = key
    db.selectedCharacterKey = key
    return db.characters[key]
end
