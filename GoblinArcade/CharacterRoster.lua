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

local LOADOUT_SLOT_COMPATIBILITY = {
    head = { INVTYPE_HEAD = true },
    neck = { INVTYPE_NECK = true },
    shoulder = { INVTYPE_SHOULDER = true },
    chest = { INVTYPE_CHEST = true, INVTYPE_ROBE = true },
    waist = { INVTYPE_WAIST = true },
    legs = { INVTYPE_LEGS = true },
    feet = { INVTYPE_FEET = true },
    wrist = { INVTYPE_WRIST = true },
    hands = { INVTYPE_HAND = true },
    finger1 = { INVTYPE_FINGER = true },
    finger2 = { INVTYPE_FINGER = true },
    trinket1 = { INVTYPE_TRINKET = true },
    trinket2 = { INVTYPE_TRINKET = true },
    back = { INVTYPE_CLOAK = true },
    mainhand = {
        INVTYPE_WEAPON = true,
        INVTYPE_WEAPONMAINHAND = true,
        INVTYPE_2HWEAPON = true,
        INVTYPE_RANGED = true,
        INVTYPE_RANGEDRIGHT = true,
    },
    offhand = {
        INVTYPE_WEAPON = true,
        INVTYPE_WEAPONOFFHAND = true,
        INVTYPE_SHIELD = true,
        INVTYPE_HOLDABLE = true,
    },
}

local LOADOUT_SLOT_PRIORITY = {
    "head", "neck", "shoulder", "chest",
    "waist", "legs", "feet", "wrist",
    "hands", "finger1", "finger2", "trinket1",
    "trinket2", "back", "mainhand", "offhand",
}

local PRE_RUN_SUPPLY_SLOTS = 3

local function IsConsumableItem(item)
    return item and (
        string.upper(tostring(item.category or "")) == "CONSUMABLE"
        or tostring(item.itemType or "") == "Consumable"
    )
end

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

    local itemStats
    if type(GetItemStats) == "function" then
        local ok, stats = pcall(GetItemStats, itemLink)
        if ok and type(stats) == "table" then itemStats = stats end
    elseif C_Item and type(C_Item.GetItemStats) == "function" then
        local ok, stats = pcall(C_Item.GetItemStats, itemLink)
        if ok and type(stats) == "table" then itemStats = stats end
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
        baselineLocked = true,
        stashEligible = false,
        ownershipSource = "baseline",
        itemStats = itemStats,
    }

    local metadata = {
        itemID = itemID,
        name = snapshot.name,
        itemLevel = itemLevel,
        quality = quality,
        itemType = itemType,
        itemSubType = itemSubType,
        equipLoc = equipLoc,
        itemStats = itemStats,
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

function GA:CreateArcadeCharacter(name, raceId, classId, hardcore, difficulty)
    local db = GetDB()
    name = Trim(name)
    raceId = string.lower(tostring(raceId or ""))
    classId = string.lower(tostring(classId or ""))
    hardcore = hardcore == true
    difficulty = self.NormalizeDifficulty and self:NormalizeDifficulty(difficulty) or "NORMAL"

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
            mainHand.baselineLocked = true
            mainHand.stashEligible = false
            mainHand.ownershipSource = "baseline"
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
            baselineLocked = true,
            stashEligible = false,
            ownershipSource = "baseline",
            arcadeWeapon = CopyTable(weapon),
        }
    end

    local character = {
        key = key,
        sourceType = "arcade",
        isArcadeGenerated = true,
        hardcore = hardcore,
        difficulty = difficulty,
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
        arcadeLoadout = {},
        arcadeSupplies = {},
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
    if db.suspendedRuns then
        db.suspendedRuns[key] = nil
    end

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
    if db.suspendedRuns and db.suspendedRuns[key] then
        return false, "Resume or abandon the saved run before deleting this hero."
    end

    for slotKey, item in pairs(character.arcadeLoadout or {}) do
        if item and item.stashEligible == true and item.baselineLocked ~= true then
            local stored = CopyTable(item)
            stored.loadoutOverride = nil
            stored.loadoutOwnerKey = nil
            stored.acquiredRunId = nil
            self:DepositCentralStashItem(stored)
        end
        character.arcadeLoadout[slotKey] = nil
    end
    for slotIndex, item in pairs(character.arcadeSupplies or {}) do
        if item and item.stashEligible == true and item.baselineLocked ~= true then
            local stored = CopyTable(item)
            stored.supplyLoadout = nil
            stored.supplyOwnerKey = nil
            stored.acquiredRunId = nil
            stored.stackCount = 1
            self:DepositCentralStashItem(stored)
        end
        character.arcadeSupplies[slotIndex] = nil
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
    GoblinArcadeDB.centralStash = GoblinArcadeDB.centralStash or {}
    GoblinArcadeDB.suspendedRuns = GoblinArcadeDB.suspendedRuns or {}

    for _, item in ipairs(GoblinArcadeDB.centralStash) do
        if item and item.extractedAt then
            item.stashEligible = true
            item.ownershipSource = item.ownershipSource or "extracted"
        end
    end

    for _, character in pairs(GoblinArcadeDB.characters) do
        if character then
            character.arcadeLoadout = character.arcadeLoadout or {}
            character.arcadeSupplies = character.arcadeSupplies or {}
            character.difficulty = GA.NormalizeDifficulty and GA:NormalizeDifficulty(character.difficulty) or "NORMAL"
            for _, item in pairs(character.equipment or {}) do
                if item then
                    item.baselineLocked = true
                    item.stashEligible = false
                    item.ownershipSource = "baseline"
                    item.acquiredRunId = nil
                end
            end
            for _, item in pairs(character.arcadeLoadout) do
                if item then
                    item.stashEligible = true
                    item.ownershipSource = item.ownershipSource or "extracted"
                    item.acquiredRunId = nil
                end
            end
            for _, item in pairs(character.arcadeSupplies) do
                if item then
                    item.stashEligible = true
                    item.baselineLocked = nil
                    item.ownershipSource = "extracted"
                    item.acquiredRunId = nil
                    item.supplyLoadout = true
                    item.stackCount = 1
                end
            end
        end
    end

    return GoblinArcadeDB
end

local function PrepareExtractedItem(item, run)
    local stored = CopyTable(item)
    stored.acquiredRunId = nil
    stored.sourceSlot = nil
    stored.baselineLocked = nil
    stored.stashEligible = true
    stored.ownershipSource = "extracted"
    stored.extractedAt = time and time() or 0
    stored.extractedFloor = run and run.floor or 9
    stored.extractedFromCharacter = run and run.snapshot and run.snapshot.name or nil
    stored.extractedFromCharacterKey = run and run.snapshot and run.snapshot.characterKey or nil
    return stored
end

function GA:GetSuspendedRun(characterKey)
    local db = GetDB()
    local saved = characterKey and db.suspendedRuns[characterKey]
    return saved and CopyTable(saved) or nil
end

function GA:HasSuspendedRun(characterKey)
    local db = GetDB()
    return characterKey ~= nil and db.suspendedRuns[characterKey] ~= nil
end

function GA:StoreSuspendedRun(characterKey, runState)
    if not characterKey or not runState then
        return false, "No character or run state to save."
    end

    local db = GetDB()
    local stored = CopyTable(runState)
    stored.active = true
    stored.suspended = true
    stored.suspendedAt = time and time() or 0
    db.suspendedRuns[characterKey] = stored
    return true
end

function GA:TakeSuspendedRun(characterKey)
    local db = GetDB()
    local stored = characterKey and db.suspendedRuns[characterKey]
    if not stored then return nil end

    db.suspendedRuns[characterKey] = nil
    local resumed = CopyTable(stored)
    resumed.active = true
    resumed.suspended = nil
    resumed.resumedAt = time and time() or 0
    return resumed
end

function GA:ClearSuspendedRun(characterKey)
    local db = GetDB()
    if characterKey then
        db.suspendedRuns[characterKey] = nil
    end
end

function GA:GetCentralStash()
    local db = GetDB()
    db.centralStash = db.centralStash or {}
    return db.centralStash
end

function GA:GetCentralStashSlotCount()
    return #(self:GetCentralStash() or {})
end

function GA:GetCentralStashItemCount()
    local total = 0
    for _, item in ipairs(self:GetCentralStash() or {}) do
        total = total + math.max(1, math.floor(tonumber(item.stackCount) or 1))
    end
    return total
end

function GA:DepositCentralStashItem(item)
    if not item or item.stashEligible ~= true or item.baselineLocked == true then
        return false
    end

    local stash = self:GetCentralStash()
    local stored = CopyTable(item)
    local amount = math.max(1, math.floor(tonumber(stored.stackCount) or 1))
    local stackMax = math.max(1, math.floor(tonumber(stored.stackMax) or 1))
    local stackable = stored.studioItemId and stackMax > 1

    if stackable then
        for _, existing in ipairs(stash) do
            if amount <= 0 then break end
            if existing.studioItemId == stored.studioItemId then
                local current = math.max(1, math.floor(tonumber(existing.stackCount) or 1))
                local existingMax = math.max(1, math.floor(tonumber(existing.stackMax) or stackMax))
                local add = math.min(amount, math.max(0, existingMax - current))
                if add > 0 then
                    existing.stackCount = current + add
                    amount = amount - add
                end
            end
        end
    end

    while amount > 0 do
        local entry = CopyTable(stored)
        entry.stackCount = stackable and math.min(amount, stackMax) or 1
        stash[#stash + 1] = entry
        amount = amount - entry.stackCount
        if not stackable then break end
    end

    return true
end

function GA:ExtractRunLootToCentralStash(run)
    if not run or run.extractionDone then
        return run and run.extractedLootCount or 0, run and run.extractedItemTypes or 0
    end

    local runId = run.runId
    if not runId then
        run.extractionDone = true
        run.extractedLootCount = 0
        run.extractedItemTypes = 0
        return 0, 0
    end

    local extractedCount = 0
    local extractedTypes = 0
    local seenTypes = {}
    run.extractedLootSummary = {}

    local function Extract(item)
        if not item or item.acquiredRunId ~= runId then return end

        local stored = PrepareExtractedItem(item, run)
        if self:DepositCentralStashItem(stored) then
            local count = math.max(1, math.floor(tonumber(stored.stackCount) or 1))
            extractedCount = extractedCount + count
            local typeKey = tostring(stored.studioItemId or stored.name or stored.itemID or extractedCount)
            local summary = run.extractedLootSummary[typeKey]
            if not summary then
                summary = {
                    name = stored.name or stored.studioItemId or "Unknown Item",
                    count = 0,
                }
                run.extractedLootSummary[typeKey] = summary
            end
            summary.count = summary.count + count

            if not seenTypes[typeKey] then
                seenTypes[typeKey] = true
                extractedTypes = extractedTypes + 1
            end
        end
    end

    for _, item in pairs(run.equipment or {}) do
        Extract(item)
    end
    for _, item in pairs(run.backpack or {}) do
        Extract(item)
    end

    run.extractionDone = true
    run.extractedLootCount = extractedCount
    run.extractedItemTypes = extractedTypes
    run.centralStashSlotsAfterRun = self:GetCentralStashSlotCount()
    return extractedCount, extractedTypes
end

function GA:GetCharacterArcadeLoadout(characterOrKey)
    local db = GetDB()
    local character = type(characterOrKey) == "table"
        and characterOrKey
        or db.characters[characterOrKey]
    if not character then return nil end

    character.arcadeLoadout = character.arcadeLoadout or {}
    return character.arcadeLoadout
end

function GA:GetCharacterArcadeSupplies(characterOrKey)
    local db = GetDB()
    local character = type(characterOrKey) == "table"
        and characterOrKey
        or db.characters[characterOrKey]
    if not character then return nil end

    character.arcadeSupplies = character.arcadeSupplies or {}
    return character.arcadeSupplies
end

function GA:GetPreRunSupplySlotCount()
    return PRE_RUN_SUPPLY_SLOTS
end

function GA:AssignCentralStashSupply(characterKey, stashIndex)
    local db = GetDB()
    local character = db.characters[characterKey]
    local index = math.floor(tonumber(stashIndex) or 0)
    local item = db.centralStash[index]

    if not character or not item then
        return false, "Select a valid character and stash item."
    end
    if character.dead and character.hardcore then
        return false, "A dead Hardcore hero cannot prepare supplies."
    end
    if db.suspendedRuns[characterKey] then
        return false, "Resume or abandon this character's saved run before changing supplies."
    end
    if item.baselineLocked == true or item.stashEligible ~= true then
        return false, "Only extracted stash items can be prepared as supplies."
    end
    if not IsConsumableItem(item) then
        return false, "Only consumables can be placed in supply slots."
    end

    local supplies = self:GetCharacterArcadeSupplies(character)
    local slotIndex
    for i = 1, PRE_RUN_SUPPLY_SLOTS do
        if not supplies[i] then
            slotIndex = i
            break
        end
    end
    if not slotIndex then
        return false, "All 3 pre-run supply slots are full."
    end

    local prepared = CopyTable(item)
    prepared.stackCount = 1
    prepared.acquiredRunId = nil
    prepared.baselineLocked = nil
    prepared.stashEligible = true
    prepared.ownershipSource = "extracted"
    prepared.supplyLoadout = true
    prepared.supplyOwnerKey = characterKey

    local stackCount = math.max(1, math.floor(tonumber(item.stackCount) or 1))
    if stackCount > 1 then
        item.stackCount = stackCount - 1
    else
        table.remove(db.centralStash, index)
    end

    supplies[slotIndex] = prepared
    db.characters[characterKey] = character
    return true, slotIndex
end

function GA:ReturnCharacterSupplyToStash(characterKey, slotIndex)
    local db = GetDB()
    local character = db.characters[characterKey]
    local index = math.floor(tonumber(slotIndex) or 0)
    if not character or index < 1 or index > PRE_RUN_SUPPLY_SLOTS then
        return false, "Invalid supply slot."
    end
    if db.suspendedRuns[characterKey] then
        return false, "Resume or abandon this character's saved run before changing supplies."
    end

    local supplies = self:GetCharacterArcadeSupplies(character)
    local item = supplies[index]
    if not item then return false, "That supply slot is empty." end

    local stored = CopyTable(item)
    stored.supplyLoadout = nil
    stored.supplyOwnerKey = nil
    stored.acquiredRunId = nil
    stored.stackCount = 1
    stored.ownershipSource = "extracted"
    if not self:DepositCentralStashItem(stored) then
        return false, "Could not return that supply to the Central Stash."
    end

    supplies[index] = nil
    db.characters[characterKey] = character
    return true
end

function GA:TakeCharacterSuppliesForRun(characterKey)
    local db = GetDB()
    local character = db.characters[characterKey]
    if not character then return {} end

    local supplies = self:GetCharacterArcadeSupplies(character)
    local result = {}
    for i = 1, PRE_RUN_SUPPLY_SLOTS do
        local item = supplies[i]
        if item then
            local runItem = CopyTable(item)
            runItem.stackCount = 1
            runItem.acquiredRunId = nil
            runItem.baselineLocked = nil
            runItem.stashEligible = true
            runItem.ownershipSource = "loadout"
            runItem.supplyLoadout = true
            runItem.supplyOwnerKey = characterKey
            result[#result + 1] = runItem
            supplies[i] = nil
        end
    end

    db.characters[characterKey] = character
    return result
end

function GA:RecoverRunSuppliesToCentralStash(run)
    if not run or run.suppliesRecovered then
        return run and run.suppliesRecoveredCount or 0
    end

    local recovered = 0
    for slotIndex, item in pairs(run.backpack or {}) do
        if item and item.supplyLoadout == true and item.acquiredRunId == nil then
            local stored = CopyTable(item)
            stored.supplyLoadout = nil
            stored.supplyOwnerKey = nil
            stored.ownershipSource = "extracted"
            stored.stackCount = math.max(1, math.floor(tonumber(stored.stackCount) or 1))
            if self:DepositCentralStashItem(stored) then
                recovered = recovered + stored.stackCount
                run.backpack[slotIndex] = nil
            end
        end
    end

    run.suppliesRecovered = true
    run.suppliesRecoveredCount = recovered
    return recovered
end


function GA:GetEffectiveCharacterEquipment(character)
    if not character then return {} end

    local equipment = CopyTable(character.equipment or {})
    for slotKey, item in pairs(character.arcadeLoadout or {}) do
        if item then
            local override = CopyTable(item)
            override.acquiredRunId = nil
            override.loadoutOverride = true
            override.stashEligible = true
            override.ownershipSource = "loadout"
            equipment[slotKey] = override
        end
    end

    local mainHand = equipment.mainhand
    if mainHand and mainHand.equipLoc == "INVTYPE_2HWEAPON" then
        equipment.offhand = nil
    end

    return equipment
end

function GA:IsCentralStashItemCompatible(character, item, slotKey)
    if not character or not item or not slotKey then return false end
    if item.baselineLocked == true or item.stashEligible ~= true then return false end
    if item.category == "CONSUMABLE" or item.itemType == "Consumable" then return false end

    local classId = string.lower(tostring(character.classId or character.classFile or character.className or ""))
    if self.ItemDatabase and item.studioDefined
        and not self.ItemDatabase:IsItemAllowedForClass(item, classId) then
        return false
    end

    local allowed = LOADOUT_SLOT_COMPATIBILITY[slotKey]
    return allowed and item.equipLoc and allowed[item.equipLoc] == true or false
end

function GA:GetPreferredCentralStashLoadoutSlot(character, item)
    if not character or not item then return nil end
    local loadout = self:GetCharacterArcadeLoadout(character) or {}

    if item.equipLoc == "INVTYPE_FINGER" then
        if not loadout.finger1 then return "finger1" end
        if not loadout.finger2 then return "finger2" end
        return "finger1"
    end
    if item.equipLoc == "INVTYPE_TRINKET" then
        if not loadout.trinket1 then return "trinket1" end
        if not loadout.trinket2 then return "trinket2" end
        return "trinket1"
    end
    if item.equipLoc == "INVTYPE_SHIELD" or item.equipLoc == "INVTYPE_HOLDABLE"
        or item.equipLoc == "INVTYPE_WEAPONOFFHAND" then
        return "offhand"
    end

    for _, slotKey in ipairs(LOADOUT_SLOT_PRIORITY) do
        if self:IsCentralStashItemCompatible(character, item, slotKey) then
            return slotKey
        end
    end
    return nil
end

function GA:EquipCentralStashItem(characterKey, stashIndex)
    local db = GetDB()
    local character = db.characters[characterKey]
    local index = math.floor(tonumber(stashIndex) or 0)
    local item = db.centralStash[index]

    if not character or not item then
        return false, "Select a valid character and stash item."
    end
    if character.dead and character.hardcore then
        return false, "A dead Hardcore hero cannot change loadout."
    end
    if db.suspendedRuns[characterKey] then
        return false, "Resume or abandon this character's saved run before changing its loadout."
    end
    if item.baselineLocked == true or item.stashEligible ~= true then
        return false, "Baseline items cannot be moved into or out of the Central Stash."
    end

    local slotKey = self:GetPreferredCentralStashLoadoutSlot(character, item)
    if not slotKey or not self:IsCentralStashItemCompatible(character, item, slotKey) then
        return false, "That item cannot be equipped by this character."
    end

    local loadout = self:GetCharacterArcadeLoadout(character)

    if slotKey == "offhand" then
        local effectiveMainHand = loadout.mainhand or (character.equipment and character.equipment.mainhand)
        if effectiveMainHand and effectiveMainHand.equipLoc == "INVTYPE_2HWEAPON" then
            return false, "Equip a one-handed main-hand weapon before adding an off-hand item."
        end
    elseif slotKey == "mainhand" and item.equipLoc == "INVTYPE_2HWEAPON" and loadout.offhand then
        local oldOffhand = CopyTable(loadout.offhand)
        oldOffhand.loadoutOverride = nil
        oldOffhand.loadoutOwnerKey = nil
        oldOffhand.acquiredRunId = nil
        if not self:DepositCentralStashItem(oldOffhand) then
            return false, "The off-hand item could not be returned to the stash."
        end
        loadout.offhand = nil
    end

    local replaced = loadout[slotKey]
    if replaced and not self:DepositCentralStashItem(replaced) then
        return false, "The replaced loadout item could not be returned to the stash."
    end

    local equipped = table.remove(db.centralStash, index)
    equipped.acquiredRunId = nil
    equipped.baselineLocked = nil
    equipped.stashEligible = true
    equipped.ownershipSource = "extracted"
    equipped.loadoutOverride = true
    equipped.loadoutOwnerKey = characterKey
    loadout[slotKey] = equipped
    db.characters[characterKey] = character
    return true, slotKey
end

function GA:ReturnCharacterLoadoutItemToStash(characterKey, slotKey)
    local db = GetDB()
    local character = db.characters[characterKey]
    if not character then return false, "Character not found." end

    if db.suspendedRuns[characterKey] then
        return false, "Resume or abandon this character's saved run before changing its loadout."
    end

    local loadout = self:GetCharacterArcadeLoadout(character)
    local item = loadout and loadout[slotKey]
    if not item then
        return false, "This slot is using the locked baseline item."
    end
    if item.baselineLocked == true or item.stashEligible ~= true then
        return false, "Baseline items can never be deposited into the Central Stash."
    end

    local stored = CopyTable(item)
    stored.loadoutOverride = nil
    stored.loadoutOwnerKey = nil
    stored.acquiredRunId = nil
    if not self:DepositCentralStashItem(stored) then
        return false, "Could not return that item to the Central Stash."
    end

    loadout[slotKey] = nil
    db.characters[characterKey] = character
    return true
end

function GA:GetLoadoutSlotDefinitions()
    return EQUIPMENT_SLOTS
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
    character.arcadeLoadout = character.arcadeLoadout or {}
    character.arcadeSupplies = character.arcadeSupplies or {}
    character.difficulty = self.NormalizeDifficulty and self:NormalizeDifficulty(character.difficulty) or "NORMAL"

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
    character.arcadeLoadout = character.arcadeLoadout or {}
    character.arcadeSupplies = character.arcadeSupplies or {}
    character.difficulty = self.NormalizeDifficulty and self:NormalizeDifficulty(character.difficulty) or "NORMAL"

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
    self.PendingAbandonSavedKey = nil
    if key and db.characters[key] then
        self.SelectedCharacterKey = key
        db.selectedCharacterKey = key
    end

    if self.RefreshDungeonCharacterSelection then
        self:RefreshDungeonCharacterSelection()
    end
end

function GA:SetCharacterDifficulty(key, difficulty)
    local db = GetDB()
    local character = key and db.characters[key]
    if not character then
        return false, "Character not found."
    end

    if self.RunState and self.RunState.active and self.RunState.snapshot
        and self.RunState.snapshot.characterKey == key then
        return false, "Difficulty is locked while a run is active."
    end

    if db.suspendedRuns and db.suspendedRuns[key] then
        return false, "Resume or abandon the saved run before changing difficulty."
    end

    character.difficulty = self.NormalizeDifficulty and self:NormalizeDifficulty(difficulty) or "NORMAL"
    character.updatedAt = time and time() or character.updatedAt or 0
    db.characters[key] = character

    if self.RefreshDungeonCharacterSelection then
        self:RefreshDungeonCharacterSelection()
    end
    return true
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
