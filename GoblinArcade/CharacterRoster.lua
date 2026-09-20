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
    local itemLevel
    local itemType
    local itemSubType
    local itemID
    local equipLoc

    if C_Item and C_Item.GetItemInfo then
        local a, _, c, d, _, f, g = C_Item.GetItemInfo(itemLink)

        if type(a) == "table" then
            name = a.itemName or a.name
            quality = a.itemQuality or a.quality
            itemLevel = a.itemLevel or a.level
            itemType = a.itemType or a.type
            itemSubType = a.itemSubType or a.subType
        else
            name = a
            quality = c
            itemLevel = d
            itemType = f
            itemSubType = g
        end
    elseif type(GetItemInfo) == "function" then
        local a, _, c, d, _, f, g = GetItemInfo(itemLink)
        name = a
        quality = c
        itemLevel = d
        itemType = f
        itemSubType = g
    end

    if C_Item and C_Item.GetItemInfoInstant then
        local instantID, instantType, instantSubType, instantEquipLoc = C_Item.GetItemInfoInstant(itemLink)
        itemID = instantID
        itemType = itemType or instantType
        itemSubType = itemSubType or instantSubType
        equipLoc = instantEquipLoc
    elseif type(GetItemInfoInstant) == "function" then
        local instantID, instantType, instantSubType, instantEquipLoc = GetItemInfoInstant(itemLink)
        itemID = instantID
        itemType = itemType or instantType
        itemSubType = itemSubType or instantSubType
        equipLoc = instantEquipLoc
    end

    if not itemLevel and C_Item and C_Item.GetDetailedItemLevelInfo then
        itemLevel = C_Item.GetDetailedItemLevelInfo(itemLink)
    end

    local snapshot = {
        source = "wow",
        sourceSlot = slotKey,
        name = name or itemLink:match("%[(.-)%]") or "Equipped item",
        link = itemLink,
        icon = icon,
        itemID = itemID,
        itemLevel = itemLevel,
        quality = quality,
        itemType = itemType,
        itemSubType = itemSubType,
        equipLoc = equipLoc,
    }

    local metadata = {
        itemID = itemID,
        name = snapshot.name,
        itemLevel = itemLevel,
        quality = quality,
        itemType = itemType,
        itemSubType = itemSubType,
        equipLoc = equipLoc,
    }

    local weaponEquipLoc = equipLoc == "INVTYPE_WEAPON"
        or equipLoc == "INVTYPE_WEAPONMAINHAND"
        or equipLoc == "INVTYPE_WEAPONOFFHAND"
        or equipLoc == "INVTYPE_2HWEAPON"
        or equipLoc == "INVTYPE_RANGED"
        or equipLoc == "INVTYPE_RANGEDRIGHT"

    if weaponEquipLoc and GA.WeaponGenerator and GA.WeaponGenerator.Convert then
        snapshot.arcadeWeapon = GA.WeaponGenerator:Convert(metadata)
    elseif GA.ItemGenerator and GA.ItemGenerator.Convert then
        snapshot.arcadeItem = GA.ItemGenerator:Convert(metadata)
    end

    return snapshot
end

local GetDB

local function Trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$") or ""
end

function GA:GetStudioClassDefinition(classId)
    local wanted = string.lower(tostring(classId or ""))
    for _, record in ipairs(self.StudioData and self.StudioData.classes or {}) do
        if string.lower(tostring(record.id or "")) == wanted then
            return record
        end
    end
    return nil
end

function GA:GetStudioRaceDefinition(raceId)
    local wanted = string.lower(tostring(raceId or ""))
    for _, record in ipairs(self.StudioData and self.StudioData.races or {}) do
        if string.lower(tostring(record.id or "")) == wanted then
            return record
        end
    end
    return nil
end

function GA:GetStudioClasses()
    return self.StudioData and self.StudioData.classes or {}
end

function GA:GetStudioRaces()
    return self.StudioData and self.StudioData.races or {}
end

function GA:IsStudioClassPlayable(classId)
    local definition = self:GetStudioClassDefinition(classId)
    if not definition then
        return false
    end

    local value = definition.playable
    if value == true or value == 1 then
        return true
    end

    value = string.upper(tostring(value or ""))
    return value == "YES" or value == "TRUE" or value == "READY" or value == "1"
end

function GA:ResolveStudioIconTexture(icon, fallback)
    if icon ~= nil and tostring(icon) ~= "" then
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

    return fallback or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function BuildArcadeStarterWeapon(classId)
    if classId == "warrior" then
        return {
            sourceName = "Recruit's Longsword",
            style = "SWORD",
            speed = "NORMAL",
            range = 1,
            damageMin = 1,
            damageMax = 2,
            itemLevel = 1,
            quality = 1,
        }
    end

    return {
        sourceName = "Training Weapon",
        style = "WEAPON",
        speed = "NORMAL",
        range = 1,
        damageMin = 1,
        damageMax = 2,
        itemLevel = 1,
        quality = 1,
    }
end

function GA:CreateArcadeCharacter(name, raceId, classId, hardcore)
    local db = GetDB()
    name = Trim(name)
    raceId = string.lower(tostring(raceId or ""))
    classId = string.lower(tostring(classId or ""))
    hardcore = hardcore == true

    if name == "" then
        return nil, "Enter a character name."
    end

    local race = self:GetStudioRaceDefinition(raceId)
    local class = self:GetStudioClassDefinition(classId)
    if not race then
        return nil, "Select a race."
    end
    if not class then
        return nil, "Select a class."
    end
    if not self:IsStudioClassPlayable(classId) then
        return nil, (class.name or classId) .. " is not ready yet."
    end

    db.arcadeCharacterSequence = (tonumber(db.arcadeCharacterSequence) or 0) + 1
    local key = "arcade:" .. tostring(db.arcadeCharacterSequence)
    local classFile = string.upper(classId)
    local weapon = BuildArcadeStarterWeapon(classId)
    local weaponIcon = "Interface\\Icons\\INV_Sword_04"
    local mainHand

    if classId == "warrior" and self.BuildStudioItem then
        local studioStarter = self:BuildStudioItem("recruits_longsword", { source = "arcade" })
        if studioStarter and studioStarter.arcadeWeapon then
            mainHand = studioStarter
            mainHand.sourceSlot = "mainhand"
            weapon = CopyTable(studioStarter.arcadeWeapon)
            weaponIcon = studioStarter.icon or weaponIcon
        end
    end

    if not mainHand then
        mainHand = {
            source = "arcade",
            sourceSlot = "mainhand",
            name = weapon.sourceName,
            icon = weaponIcon,
            itemLevel = 1,
            quality = 1,
            itemType = "Weapon",
            itemSubType = "Sword",
            equipLoc = "INVTYPE_WEAPON",
            arcadeWeapon = CopyTable(weapon),
        }
    end

    local character = {
        key = key,
        sourceType = "arcade",
        isArcadeGenerated = true,
        hardcore = hardcore,
        dead = false,
        name = name,
        realm = "GoblinArcade",
        level = 1,
        classId = classId,
        className = class.name or classId,
        classFile = classFile,
        raceId = raceId,
        raceName = race.name or raceId,
        maxHealth = 100,
        updatedAt = time and time() or 0,
        equipment = {
            mainhand = mainHand,
        },
        weapon = CopyTable(weapon),
        weaponName = weapon.sourceName,
        weaponIcon = weaponIcon,
        weaponItemLevel = 1,
        weaponQuality = 1,
        weaponSubtype = "Sword",
    }

    db.characters[key] = character
    db.selectedCharacterKey = key
    self.SelectedCharacterKey = key

    if self.RefreshDungeonCharacterSelection then
        self:RefreshDungeonCharacterSelection()
    end
    if self.RefreshCharacterGenerator then
        self:RefreshCharacterGenerator()
    end

    return character
end

function GA:IsArcadeCharacterDead(character)
    return character
        and (character.isArcadeGenerated or character.sourceType == "arcade")
        and character.hardcore == true
        and character.dead == true
end

function GA:MarkArcadeCharacterDead(key, reason, floor, score)
    local db = GetDB()
    local character = key and db.characters[key]
    if not character
        or not (character.isArcadeGenerated or character.sourceType == "arcade")
        or character.hardcore ~= true
        or character.dead == true then
        return false
    end

    character.dead = true
    character.deadAt = time and time() or 0
    character.deathReason = tostring(reason or "Fell in the dungeon.")
    character.deathFloor = math.max(1, math.floor(tonumber(floor) or 1))
    character.deathScore = math.max(0, math.floor(tonumber(score) or 0))
    db.characters[key] = character

    if self.RefreshDungeonCharacterSelection then
        self:RefreshDungeonCharacterSelection()
    end
    return true
end

function GA:DeleteArcadeCharacter(key)
    local db = GetDB()
    local character = key and db.characters[key]
    if not character or not (character.isArcadeGenerated or character.sourceType == "arcade") then
        return false, "Only generated Arcade heroes can be deleted."
    end

    if self.RunState and self.RunState.active and self.RunState.snapshot
        and self.RunState.snapshot.characterKey == key then
        return false, "Cannot delete the hero while its run is active."
    end

    db.characters[key] = nil
    if db.actionBars then
        db.actionBars[key] = nil
    end
    if db.actionBarVersions then
        db.actionBarVersions[key] = nil
    end

    local currentKey = self:GetCurrentCharacterKey()
    local nextKey = db.characters[currentKey] and currentKey or nil
    if not nextKey then
        for candidateKey, candidate in pairs(db.characters) do
            if candidate and candidate.name then
                nextKey = candidateKey
                break
            end
        end
    end

    db.selectedCharacterKey = nextKey
    self.SelectedCharacterKey = nextKey
    self.PendingDeleteArcadeKey = nil

    if self.RefreshDungeonCharacterSelection then
        self:RefreshDungeonCharacterSelection()
    end
    return true
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

GetDB = function()
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
    self.PendingDeleteArcadeKey = nil
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
