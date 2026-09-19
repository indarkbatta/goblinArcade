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
