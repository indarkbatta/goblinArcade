local _, GA = ...

local UI = GA.UI
local COLORS = UI.COLORS
local ApplyBackdrop = UI.ApplyBackdrop
local CreateText = UI.CreateText

local BACKPACK_SLOTS = 20

local SLOT_COMPATIBILITY = {
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

local function SetCharacterVisual(texture, snapshot)
    if not texture then
        return
    end

    local currentKey = GA.GetCurrentCharacterKey and GA:GetCurrentCharacterKey()
    if snapshot and snapshot.characterKey == currentKey then
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        SetPortraitTexture(texture, "player")
        return
    end

    local coords = snapshot and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[snapshot.classFile]
    if coords then
        texture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

local function GetMouseFocusCompat()
    if type(GetMouseFoci) == "function" then
        local foci = GetMouseFoci()
        if foci and foci[1] then
            return foci[1]
        end
    end

    if type(GetMouseFocus) == "function" then
        return GetMouseFocus()
    end

    return nil
end

function GA:IsArcadeItemCompatible(item, slotKey)
    if not item or not slotKey then
        return false
    end

    if item.compatibleSlots and item.compatibleSlots[slotKey] then
        return true
    end

    local allowed = SLOT_COMPATIBILITY[slotKey]
    if not allowed then
        return false
    end

    return item.equipLoc and allowed[item.equipLoc] == true
end

function GA:GetCharacterInventoryItem(sourceType, sourceKey)
    local run = self.RunState
    if not run then
        return nil
    end

    if sourceType == "equipment" then
        return run.equipment and run.equipment[sourceKey]
    end

    if sourceType == "backpack" then
        return run.backpack and run.backpack[sourceKey]
    end

    return nil
end

function GA:SetCharacterInventoryItem(sourceType, sourceKey, item)
    local run = self.RunState
    if not run then
        return
    end

    if sourceType == "equipment" then
        run.equipment = run.equipment or {}
        run.equipment[sourceKey] = item
    elseif sourceType == "backpack" then
        run.backpack = run.backpack or {}
        run.backpack[sourceKey] = item
    end
end

function GA:GetCurrentRunWeapon()
    local run = self.RunState
    if not run then
        return nil
    end

    local mainHand = run.equipment and run.equipment.mainhand
    return mainHand and mainHand.arcadeWeapon or nil
end

function GA:RefreshRunWeaponFromEquipment()
    local weapon = self:GetCurrentRunWeapon()

    if self.DungeonPower then
        if weapon then
            self.DungeonPower:SetText(string.format("%d-%d", weapon.damageMin or 0, weapon.damageMax or 0))
        else
            self.DungeonPower:SetText("1-2")
        end
    end

    if self.DungeonArcadeDamage then
        if weapon then
            self.DungeonArcadeDamage:SetText(string.format("Damage %d - %d", weapon.damageMin or 0, weapon.damageMax or 0))
            self.DungeonArcadeStyle:SetText(
                string.format("%s  -  %s  -  Range %d",
                    weapon.style or "Weapon",
                    weapon.speed or "NORMAL",
                    weapon.range or 1)
            )
            self.DungeonArcadeTraitName:SetText(weapon.traitName or "NO SIGNATURE TRAIT")
            self.DungeonArcadeTraitDesc:SetText(weapon.traitDescription or "")
        else
            self.DungeonArcadeDamage:SetText("Damage 1 - 2")
            self.DungeonArcadeStyle:SetText("Unarmed  -  FAST  -  Range 1")
            self.DungeonArcadeTraitName:SetText("UNARMED")
            self.DungeonArcadeTraitDesc:SetText("Equip a weapon from your backpack.")
        end
    end
end

function GA:EnsureArcadeItemConversion(item)
    if not item then
        return nil
    end

    local itemGeneratorVersion = self.ItemGenerator and self.ItemGenerator.VERSION
    local weaponGeneratorVersion = self.WeaponGenerator and self.WeaponGenerator.VERSION

    if item.arcadeItem
        and item.arcadeItem.generatorVersion == itemGeneratorVersion then
        return item
    end

    if item.arcadeWeapon
        and item.arcadeWeapon.generatorVersion == weaponGeneratorVersion then
        return item
    end

    local metadata = {
        itemID = item.itemID,
        name = item.name,
        itemLevel = item.itemLevel,
        quality = item.quality,
        itemType = item.itemType,
        itemSubType = item.itemSubType,
        equipLoc = item.equipLoc,
    }

    local weaponEquipLoc = item.equipLoc == "INVTYPE_WEAPON"
        or item.equipLoc == "INVTYPE_WEAPONMAINHAND"
        or item.equipLoc == "INVTYPE_WEAPONOFFHAND"
        or item.equipLoc == "INVTYPE_2HWEAPON"
        or item.equipLoc == "INVTYPE_RANGED"
        or item.equipLoc == "INVTYPE_RANGEDRIGHT"

    if weaponEquipLoc and self.WeaponGenerator and self.WeaponGenerator.Convert then
        item.arcadeWeapon = self.WeaponGenerator:Convert(metadata)
    elseif self.ItemGenerator and self.ItemGenerator.Convert then
        item.arcadeItem = self.ItemGenerator:Convert(metadata)
    end

    return item
end

function GA:RecalculateRunGearStats()
    local run = self.RunState
    if not run then
        return
    end

    local stats = {
        health = 0,
        armor = 0,
        dodge = 0,
        crit = 0,
        block = 0,
    }

    for _, item in pairs(run.equipment or {}) do
        self:EnsureArcadeItemConversion(item)
        local converted = item and item.arcadeItem

        if converted then
            stats.health = stats.health + (converted.health or 0)
            stats.armor = stats.armor + (converted.armor or 0)
            stats.dodge = stats.dodge + (converted.dodge or 0)
            stats.crit = stats.crit + (converted.crit or 0)
            stats.block = stats.block + (converted.block or 0)
        end
    end

    stats.dodge = math.min(35, stats.dodge)
    stats.crit = math.min(50, stats.crit)
    stats.block = math.min(40, stats.block)
    run.arcadeStats = stats

    local oldMaxHealth = math.max(1, run.playerMaxHealth or run.baseMaxHealth or 1)
    local oldHealth = math.max(0, run.playerHealth or oldMaxHealth)
    local healthRatio = math.min(1, oldHealth / oldMaxHealth)
    local baseMaxHealth = run.baseMaxHealth
        or (run.snapshot and run.snapshot.maxHealth)
        or oldMaxHealth

    run.baseMaxHealth = baseMaxHealth
    run.playerMaxHealth = math.max(1, baseMaxHealth + stats.health)
    run.playerHealth = math.max(0, math.floor(run.playerMaxHealth * healthRatio + 0.5))

    if self.UpdateRunHealth then
        self:UpdateRunHealth()
    end

    if self.DungeonDodge then
        self.DungeonDodge:SetText(string.format("%.1f%%", stats.dodge))
    end

    if self.CharacterSheetStats then
        self.CharacterSheetStats:SetText(
            string.format(
                "HP +%d   Armor %d   Dodge %.1f%%   Crit %.1f%%   Block %.1f%%",
                stats.health,
                stats.armor,
                stats.dodge,
                stats.crit,
                stats.block
            )
        )
    end
end

function GA:CanDropCharacterItem(drag, targetType, targetKey)
    if not drag or not drag.item then
        return false
    end

    if drag.sourceType == targetType and drag.sourceKey == targetKey then
        return true
    end

    local targetItem = self:GetCharacterInventoryItem(targetType, targetKey)

    if targetType == "equipment"
        and not self:IsArcadeItemCompatible(drag.item, targetKey) then
        return false
    end

    if targetItem
        and drag.sourceType == "equipment"
        and not self:IsArcadeItemCompatible(targetItem, drag.sourceKey) then
        return false
    end

    return true
end

function GA:ClearCharacterDropHighlights()
    for _, button in pairs(self.CharacterEquipmentButtons or {}) do
        button:SetBackdropColor(0.035, 0.030, 0.024, 1)
        button:SetBackdropBorderColor(COLORS.goldDim[1], COLORS.goldDim[2], COLORS.goldDim[3], 1)
    end

    for _, button in ipairs(self.CharacterBackpackButtons or {}) do
        button:SetBackdropColor(0.035, 0.030, 0.024, 1)
        button:SetBackdropBorderColor(COLORS.goldDim[1], COLORS.goldDim[2], COLORS.goldDim[3], 1)
    end
end

function GA:HighlightCharacterDropTargets()
    local drag = self.CharacterDragState
    if not drag then
        return
    end

    for key, button in pairs(self.CharacterEquipmentButtons or {}) do
        local valid = self:CanDropCharacterItem(drag, "equipment", key)

        if valid then
            button:SetBackdropColor(0.055, 0.16, 0.065, 1)
            button:SetBackdropBorderColor(COLORS.green[1], COLORS.green[2], COLORS.green[3], 1)
        else
            button:SetBackdropColor(0.022, 0.020, 0.018, 1)
            button:SetBackdropBorderColor(0.15, 0.13, 0.10, 1)
        end
    end

    for i, button in ipairs(self.CharacterBackpackButtons or {}) do
        local valid = self:CanDropCharacterItem(drag, "backpack", i)

        if valid then
            button:SetBackdropColor(0.11, 0.085, 0.035, 1)
            button:SetBackdropBorderColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1)
        else
            button:SetBackdropColor(0.022, 0.020, 0.018, 1)
            button:SetBackdropBorderColor(0.15, 0.13, 0.10, 1)
        end
    end
end

function GA:BeginCharacterItemDrag(sourceType, sourceKey)
    local item = self:GetCharacterInventoryItem(sourceType, sourceKey)
    if not item then
        return
    end

    self.CharacterDragState = {
        sourceType = sourceType,
        sourceKey = sourceKey,
        item = item,
        wasMouseDown = true,
    }

    if self.CharacterDragGhost then
        self.CharacterDragGhost.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        self.CharacterDragGhost:Show()
    end

    self:HighlightCharacterDropTargets()
end

function GA:CancelCharacterItemDrag()
    self.CharacterDragState = nil

    if self.CharacterDragGhost then
        self.CharacterDragGhost:Hide()
    end

    self:ClearCharacterDropHighlights()
end

function GA:DropCharacterItem(targetType, targetKey)
    local drag = self.CharacterDragState
    if not drag then
        return false
    end

    if not self:CanDropCharacterItem(drag, targetType, targetKey) then
        self:AddCombatLog("That item cannot be placed there.", "warning")
        self:CancelCharacterItemDrag()
        return false
    end

    if drag.sourceType == targetType and drag.sourceKey == targetKey then
        self:CancelCharacterItemDrag()
        return true
    end

    local sourceItem = drag.item
    local targetItem = self:GetCharacterInventoryItem(targetType, targetKey)

    self:SetCharacterInventoryItem(drag.sourceType, drag.sourceKey, targetItem)
    self:SetCharacterInventoryItem(targetType, targetKey, sourceItem)
    self:CancelCharacterItemDrag()

    self:RefreshRunWeaponFromEquipment()
    self:RecalculateRunGearStats()
    self:RefreshCharacterSheet()
    self:RefreshActionButtons()

    return true
end

local function AddArcadeConversionToTooltip(item)
    if not item then
        return
    end

    GA:EnsureArcadeItemConversion(item)

    local weapon = item.arcadeWeapon
    local converted = item.arcadeItem

    if not weapon and not converted then
        return
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("GoblinArcade Conversion", 1, 0.72, 0.12)

    if weapon then
        GameTooltip:AddLine(
            string.format(
                "%s  |  Damage %d-%d  |  %s  |  Range %d",
                weapon.style or "Weapon",
                weapon.damageMin or 0,
                weapon.damageMax or 0,
                weapon.speed or "NORMAL",
                weapon.range or 1
            ),
            0.92, 0.89, 0.82,
            true
        )

        if weapon.traitName then
            GameTooltip:AddLine(
                weapon.traitName .. " - " .. (weapon.traitDescription or ""),
                1, 0.72, 0.12,
                true
            )
        end

        return
    end

    GameTooltip:AddLine(
        string.format(
            "%s  |  HP +%d  |  Armor %d  |  Dodge %.1f%%  |  Crit %.1f%%  |  Block %.1f%%",
            converted.style or "Gear",
            converted.health or 0,
            converted.armor or 0,
            converted.dodge or 0,
            converted.crit or 0,
            converted.block or 0
        ),
        0.92, 0.89, 0.82,
        true
    )

    if converted.traitName then
        GameTooltip:AddLine(
            converted.traitName .. " - " .. (converted.traitDescription or ""),
            1, 0.72, 0.12,
            true
        )
    end
end

local function ShowItemTooltip(button)
    local item = button.gaItem
    if not item then
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")

    if item.link then
        GameTooltip:SetHyperlink(item.link)
    else
        GameTooltip:SetText(item.name or "Dungeon item", 1, 0.82, 0.22)

        if item.description then
            GameTooltip:AddLine(item.description, 0.8, 0.8, 0.8, true)
        end

        if item.equipLoc then
            GameTooltip:AddLine(item.slotLabel or item.equipLoc, 0.6, 0.6, 0.6, true)
        end
    end

    AddArcadeConversionToTooltip(item)
    GameTooltip:Show()
end

local function CreateItemSlot(parent, size)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(size, size)
    ApplyBackdrop(button, { 0.035, 0.030, 0.024, 1 }, COLORS.goldDim)
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    icon:SetAlpha(0.22)
    button.icon = icon

    button:SetScript("OnEnter", ShowItemTooltip)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnDragStart", function(self)
        if self.gaItem then
            GA:BeginCharacterItemDrag(self.gaSourceType, self.gaSourceKey)
        end
    end)

    return button
end

function GA:CreateCharacterSheet(parent)
    if self.CharacterSheetFrame then
        return
    end

    local sheet = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    sheet:SetPoint("TOPLEFT", 1, -1)
    sheet:SetPoint("BOTTOMRIGHT", -1, 1)
    sheet:SetFrameLevel(parent:GetFrameLevel() + 30)
    ApplyBackdrop(sheet, { 0.035, 0.030, 0.024, 0.995 }, COLORS.goldDim)
    sheet:EnableMouse(true)
    sheet:Hide()
    self.CharacterSheetFrame = sheet

    local title = CreateText(sheet, "GameFontNormalHuge", "CHARACTER")
    title:SetPoint("TOPLEFT", 22, -18)
    title:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

    local hint = CreateText(sheet, "GameFontDisableSmall", "C TO CLOSE  -  DRAG ITEMS TO EQUIP")
    hint:SetPoint("TOPRIGHT", -22, -26)
    hint:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local gearPanel = CreateFrame("Frame", nil, sheet, "BackdropTemplate")
    gearPanel:SetPoint("TOPLEFT", 22, -58)
    gearPanel:SetSize(396, 446)
    ApplyBackdrop(gearPanel, { 0.050, 0.043, 0.034, 1 }, COLORS.goldDim)

    local backpackPanel = CreateFrame("Frame", nil, sheet, "BackdropTemplate")
    backpackPanel:SetPoint("TOPLEFT", gearPanel, "TOPRIGHT", 14, 0)
    backpackPanel:SetPoint("BOTTOMRIGHT", -22, 20)
    ApplyBackdrop(backpackPanel, { 0.050, 0.043, 0.034, 1 }, COLORS.goldDim)

    local portraitBorder = CreateFrame("Frame", nil, gearPanel, "BackdropTemplate")
    portraitBorder:SetSize(118, 118)
    portraitBorder:SetPoint("TOP", 0, -64)
    ApplyBackdrop(portraitBorder, { 0.02, 0.02, 0.02, 1 }, COLORS.gold)

    local portrait = portraitBorder:CreateTexture(nil, "ARTWORK")
    portrait:SetPoint("TOPLEFT", 3, -3)
    portrait:SetPoint("BOTTOMRIGHT", -3, 3)
    self.CharacterSheetPortrait = portrait

    local charName = CreateText(gearPanel, "GameFontNormalLarge", "")
    charName:SetPoint("TOP", portraitBorder, "BOTTOM", 0, -12)
    charName:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    self.CharacterSheetName = charName

    local charMeta = CreateText(gearPanel, "GameFontHighlightSmall", "")
    charMeta:SetPoint("TOP", charName, "BOTTOM", 0, -6)
    charMeta:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.CharacterSheetMeta = charMeta

    local health = CreateText(gearPanel, "GameFontNormalSmall", "")
    health:SetPoint("TOP", charMeta, "BOTTOM", 0, -18)
    health:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
    self.CharacterSheetHealth = health

    local arcadeStats = CreateText(gearPanel, "GameFontHighlightSmall", "")
    arcadeStats:SetPoint("TOP", health, "BOTTOM", 0, -6)
    arcadeStats:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.CharacterSheetStats = arcadeStats

    local leftSlots = { "head", "neck", "shoulder", "back", "chest", "wrist", "hands", "waist" }
    local rightSlots = { "legs", "feet", "finger1", "finger2", "trinket1", "trinket2", "mainhand", "offhand" }

    self.CharacterEquipmentButtons = {}

    local function BuildGearColumn(keys, x)
        for i, key in ipairs(keys) do
            local slot = CreateItemSlot(gearPanel, 42)
            slot:SetPoint("TOPLEFT", x, -32 - ((i - 1) * 50))
            slot.gaSourceType = "equipment"
            slot.gaSourceKey = key
            slot.gaDropType = "equipment"
            slot.gaDropKey = key
            self.CharacterEquipmentButtons[key] = slot

            local slotName = CreateText(slot, "GameFontDisableSmall", string.upper(key))
            slotName:SetPoint(x < 100 and "LEFT" or "RIGHT", slot, x < 100 and "RIGHT" or "LEFT", x < 100 and 6 or -6, 0)
            slotName:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        end
    end

    BuildGearColumn(leftSlots, 18)
    BuildGearColumn(rightSlots, 336)

    local packTitle = CreateText(backpackPanel, "GameFontNormalLarge", "BACKPACK")
    packTitle:SetPoint("TOPLEFT", 14, -14)
    packTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local packHint = CreateText(backpackPanel, "GameFontDisableSmall", "Dungeon loot and unequipped gear")
    packHint:SetPoint("TOPLEFT", packTitle, "BOTTOMLEFT", 0, -4)
    packHint:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    self.CharacterBackpackButtons = {}
    for i = 1, BACKPACK_SLOTS do
        local col = (i - 1) % 5
        local row = math.floor((i - 1) / 5)
        local slot = CreateItemSlot(backpackPanel, 44)
        slot:SetPoint("TOPLEFT", 14 + col * 50, -66 - row * 50)
        slot.gaSourceType = "backpack"
        slot.gaSourceKey = i
        slot.gaDropType = "backpack"
        slot.gaDropKey = i
        self.CharacterBackpackButtons[i] = slot
    end

    local packNote = CreateText(
        backpackPanel,
        "GameFontHighlightSmall",
        "Items moved here belong only to this Dungeon Run. Your real WoW equipment is never changed."
    )
    packNote:SetPoint("BOTTOMLEFT", 14, 18)
    packNote:SetPoint("RIGHT", -14, 0)
    packNote:SetJustifyH("LEFT")
    packNote:SetWordWrap(true)
    packNote:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local ghost = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    ghost:SetSize(42, 42)
    ghost:SetFrameStrata("TOOLTIP")
    ApplyBackdrop(ghost, { 0.02, 0.02, 0.02, 0.90 }, COLORS.gold)

    local ghostIcon = ghost:CreateTexture(nil, "ARTWORK")
    ghostIcon:SetPoint("TOPLEFT", 2, -2)
    ghostIcon:SetPoint("BOTTOMRIGHT", -2, 2)
    ghost.icon = ghostIcon
    ghost:Hide()
    self.CharacterDragGhost = ghost

    sheet:SetScript("OnUpdate", function()
        local drag = GA.CharacterDragState
        if not drag then
            return
        end

        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        ghost:ClearAllPoints()
        ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)

        local mouseDown = IsMouseButtonDown and IsMouseButtonDown("LeftButton")
        if drag.wasMouseDown and not mouseDown then
            local focus = GetMouseFocusCompat()
            if focus and focus.gaDropType then
                GA:DropCharacterItem(focus.gaDropType, focus.gaDropKey)
            else
                GA:CancelCharacterItemDrag()
            end
        else
            drag.wasMouseDown = mouseDown
        end
    end)
end

function GA:RefreshCharacterSheet()
    local sheet = self.CharacterSheetFrame
    local run = self.RunState

    if not sheet or not run or not run.snapshot then
        return
    end

    SetCharacterVisual(self.CharacterSheetPortrait, run.snapshot)
    self.CharacterSheetName:SetText(run.snapshot.name or "Unknown")
    self.CharacterSheetMeta:SetText(
        string.format("Level %d %s %s",
            run.snapshot.level or 0,
            run.snapshot.raceName or "",
            run.snapshot.className or "Adventurer")
    )
    self.CharacterSheetHealth:SetText(
        string.format("Health %d / %d", run.playerHealth or 0, run.playerMaxHealth or 0)
    )

    self:RecalculateRunGearStats()

    for key, button in pairs(self.CharacterEquipmentButtons or {}) do
        local item = run.equipment and run.equipment[key]
        button.gaItem = item

        if item then
            button.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            button.icon:SetAlpha(1)
        else
            button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            button.icon:SetAlpha(0.16)
        end
    end

    for i, button in ipairs(self.CharacterBackpackButtons or {}) do
        local item = run.backpack and run.backpack[i]
        button.gaItem = item

        if item then
            button.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            button.icon:SetAlpha(1)
        else
            button.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
            button.icon:SetAlpha(0.12)
        end
    end
end

function GA:ToggleCharacterSheet()
    if not self.RunState or not self.RunState.active or not self.CharacterSheetFrame then
        return
    end

    if self.CharacterSheetFrame:IsShown() then
        self.CharacterSheetFrame:Hide()
        self:CancelCharacterItemDrag()
    else
        self:RefreshCharacterSheet()
        self.CharacterSheetFrame:Show()
    end
end

function GA:AddItemToBackpack(item)
    local run = self.RunState
    if not run then
        return false
    end

    run.backpack = run.backpack or {}

    for i = 1, BACKPACK_SLOTS do
        if not run.backpack[i] then
            local storedItem = CopyTable(item)
            self:EnsureArcadeItemConversion(storedItem)
            run.backpack[i] = storedItem

            if self.CharacterSheetFrame and self.CharacterSheetFrame:IsShown() then
                self:RefreshCharacterSheet()
            end
            return true
        end
    end

    return false
end
