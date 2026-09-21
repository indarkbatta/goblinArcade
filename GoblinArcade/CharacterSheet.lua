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

local EQUIP_LOCATION_LABELS = {
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
    INVTYPE_WEAPON = "One-Hand",
    INVTYPE_WEAPONMAINHAND = "Main Hand",
    INVTYPE_WEAPONOFFHAND = "Off Hand",
    INVTYPE_2HWEAPON = "Two-Hand",
    INVTYPE_RANGED = "Ranged",
    INVTYPE_RANGEDRIGHT = "Ranged",
    INVTYPE_SHIELD = "Off Hand / Shield",
    INVTYPE_HOLDABLE = "Off Hand",
}

local function IsTwoHandedWeapon(item)
    return item and item.equipLoc == "INVTYPE_2HWEAPON"
end

local function FindEmptyBackpackSlot(run, ignoredSlot)
    if not run then return nil end
    run.backpack = run.backpack or {}

    for i = 1, BACKPACK_SLOTS do
        if i ~= ignoredSlot and not run.backpack[i] then
            return i
        end
    end

    return nil
end

local function FindForcedOffhandBackpackSlot(run, drag, mainHandTargetItem)
    if not run then return nil end

    -- When a 2H weapon comes from the backpack, its source slot becomes
    -- available only if there is no displaced main-hand item to swap back.
    if drag and drag.sourceType == "backpack" and not mainHandTargetItem then
        return drag.sourceKey
    end

    local ignoredSlot = drag and drag.sourceType == "backpack" and drag.sourceKey or nil
    return FindEmptyBackpackSlot(run, ignoredSlot)
end

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

    if snapshot and (snapshot.isArcadeGenerated or snapshot.sourceType == "arcade") then
        local race = GA.GetStudioRaceDefinition and GA:GetStudioRaceDefinition(snapshot.raceId)
        texture:SetTexture(
            GA.ResolveStudioIconTexture
                and GA:ResolveStudioIconTexture(race and race.icon, "Interface\\Icons\\INV_Misc_QuestionMark")
                or "Interface\\Icons\\INV_Misc_QuestionMark"
        )
        texture:SetTexCoord(0.06, 0.94, 0.06, 0.94)
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

    if item.studioDefined then
        local run = self.RunState
        if self.ItemDatabase and not self.ItemDatabase:IsItemAllowedForClass(item, run and run.classId) then
            return false
        end
        if run and (tonumber(item.requiredLevel) or 1) > (tonumber(run.runLevel) or 1) then
            return false
        end
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

function GA:GetRunAttackPowerDamageBonus(weapon)
    local run = self.RunState
    local attackPower = run and run.arcadeStats and run.arcadeStats.attackPower or 0
    return self:CalculateAttackPowerDamageBonus(attackPower, weapon or { speed = "FAST" })
end
function GA:RefreshRunWeaponFromEquipment()
    local weapon = self:GetCurrentRunWeapon()
    local baseMin = weapon and (weapon.damageMin or 1) or 1
    local baseMax = weapon and (weapon.damageMax or baseMin) or 2
    local attackPowerBonus = self:GetRunAttackPowerDamageBonus(weapon)
    local effectiveMin = baseMin + attackPowerBonus
    local effectiveMax = baseMax + attackPowerBonus

    if self.DungeonPower then
        self.DungeonPower:SetText(string.format("%d-%d", effectiveMin, effectiveMax))
    end

    if self.DungeonArcadeDamage then
        if weapon then
            if attackPowerBonus > 0 then
                self.DungeonArcadeDamage:SetText(string.format("Damage %d - %d  (+%d from AP)", baseMin, baseMax, attackPowerBonus))
            else
                self.DungeonArcadeDamage:SetText(string.format("Damage %d - %d", baseMin, baseMax))
            end
            self.DungeonArcadeStyle:SetText(string.format("%s  -  %s  -  Range %d", weapon.style or "Weapon", weapon.speed or "NORMAL", weapon.range or 1))
            self.DungeonArcadeTraitName:SetText(weapon.traitName or "NO SIGNATURE TRAIT")
            self.DungeonArcadeTraitDesc:SetText(weapon.traitDescription or "")
        else
            self.DungeonArcadeDamage:SetText(string.format("Damage 1 - 2%s", attackPowerBonus > 0 and string.format("  (+%d from AP)", attackPowerBonus) or ""))
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

    -- Studio-defined dungeon items already carry their authoritative
    -- GoblinArcade stats. Never run them through the WoW import converters.
    if item.studioDefined then
        return item
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
    if not run then return end

    local gear = {
        strength = 0, agility = 0, stamina = 0, intellect = 0, spirit = 0,
        directHealth = 0, armor = 0, attackPower = 0, rangedAttackPower = 0,
        hit = 0, crit = 0, expertise = 0, defense = 0,
        dodge = 0, parry = 0, block = 0, blockValue = 0, weaponSkill = 0,
        spellPower = 0, healingPower = 0, mp5 = 0,
        arcaneResistance = 0, fireResistance = 0, frostResistance = 0,
        natureResistance = 0, shadowResistance = 0,
        hasShield = false,
        traits = {}, buildProfiles = {},
    }

    local numericKeys = {
        "strength", "agility", "stamina", "intellect", "spirit",
        "armor", "attackPower", "rangedAttackPower", "hit", "crit", "expertise",
        "defense", "dodge", "parry", "block", "blockValue", "weaponSkill",
        "spellPower", "healingPower", "mp5",
        "arcaneResistance", "fireResistance", "frostResistance",
        "natureResistance", "shadowResistance",
    }

    for slotKey, item in pairs(run.equipment or {}) do
        self:EnsureArcadeItemConversion(item)
        local converted = item and item.arcadeItem
        local weapon = item and item.arcadeWeapon

        for _, source in ipairs({ converted, weapon }) do
            if source then
                for _, key in ipairs(numericKeys) do
                    gear[key] = (gear[key] or 0) + (tonumber(source[key]) or 0)
                end

                -- Old extracted/stashed items can pre-date the Forever ruleset.
                -- Keep their direct HP bonus until they are replaced, but do not
                -- double-count the compatibility health alias on new STA gear.
                if source.stamina == nil and (tonumber(source.health) or 0) > 0 then
                    gear.directHealth = gear.directHealth + (tonumber(source.health) or 0)
                end

                if source.traitName and (tonumber(source.traitValue) or 0) > 0 then
                    local traitKey = string.upper(tostring(source.traitName))
                    gear.traits[traitKey] = math.min(50,
                        (gear.traits[traitKey] or 0) + (tonumber(source.traitValue) or 0))
                end

                local profile = string.upper(tostring(item and item.buildProfile or source.buildProfile or "NONE"))
                if profile ~= "" and profile ~= "NONE" then
                    gear.buildProfiles[profile] = (gear.buildProfiles[profile] or 0) + 1
                end
            end
        end

        if slotKey == "offhand" and item and item.equipLoc == "INVTYPE_SHIELD" then
            gear.hasShield = true
        end
    end

    local level = math.max(1, tonumber(run.runLevel or (run.snapshot and run.snapshot.level)) or 1)
    local classFile = run.snapshot and run.snapshot.classFile or run.classId or "WARRIOR"
    local stats
    if self.ForeverRules and self.ForeverRules.BuildDerivedStats then
        stats = self.ForeverRules:BuildDerivedStats(level, classFile, gear)
    else
        stats = gear
    end
    stats.level = level
    stats.traits = gear.traits
    stats.buildProfiles = gear.buildProfiles
    stats.hasShield = gear.hasShield

    run.arcadeStats = stats
    run.arcadeTraits = gear.traits
    run.ruleset = self.ForeverRules and self.ForeverRules.ID or run.ruleset

    local oldMaxHealth = math.max(1, run.playerMaxHealth or run.baseMaxHealth or 1)
    local oldHealth = math.max(0, run.playerHealth or oldMaxHealth)
    local healthRatio = math.min(1, oldHealth / oldMaxHealth)
    local baseMaxHealth = run.rulesBaseHealth
        or run.baseMaxHealth
        or (run.snapshot and run.snapshot.maxHealth)
        or oldMaxHealth
    run.rulesBaseHealth = math.max(1, baseMaxHealth)
    run.baseMaxHealth = run.rulesBaseHealth
    run.playerMaxHealth = math.max(1, math.floor(run.rulesBaseHealth + (tonumber(stats.health) or 0) + 0.5))
    run.playerHealth = math.max(0, math.floor(run.playerMaxHealth * healthRatio + 0.5))

    if string.upper(tostring(run.resourceType or "")) == "RAGE" then
        if (tonumber(run.resourceMax) or 0) <= 10 then
            run.resource = math.min(100, math.max(0, (tonumber(run.resource) or 0) * 20))
        end
        run.baseResourceMax = 100
        run.resourceMax = 100
    end

    if self.UpdateRunHealth then self:UpdateRunHealth() end
    if self.UpdateRunResource then self:UpdateRunResource() end

    if self.DungeonDodge then
        self.DungeonDodge:SetText(string.format("D %.1f  P %.1f  B %.1f",
            tonumber(stats.dodge) or 0,
            tonumber(stats.parry) or 0,
            tonumber(stats.block) or 0))
    end

    if self.CharacterSheetStatRows then
        local rows = self.CharacterSheetStatRows
        if rows.primary then rows.primary:SetText(string.format("STR %d  AGI %d  STA %d",
            math.floor(stats.strength or 0), math.floor(stats.agility or 0), math.floor(stats.stamina or 0))) end
        if rows.attackPower then rows.attackPower:SetText(string.format("Attack Power %d", math.floor(stats.attackPower or 0))) end
        if rows.armor then rows.armor:SetText(string.format("Armor %d", math.floor(stats.armor or 0))) end
        if rows.skills then rows.skills:SetText(string.format("Weapon %d  Defense %d",
            math.floor(stats.weaponSkill or 0), math.floor(stats.defenseSkill or 0))) end
        if rows.hitCrit then rows.hitCrit:SetText(string.format("Hit %.1f%%  Crit %.1f%%",
            stats.hit or 0, stats.crit or 0)) end
        if rows.expertise then rows.expertise:SetText(string.format("Expertise %.1f%%", stats.expertise or 0)) end
        if rows.avoidance then rows.avoidance:SetText(string.format("Dodge %.1f%%  Parry %.1f%%",
            stats.dodge or 0, stats.parry or 0)) end
        if rows.block then rows.block:SetText(string.format("Block %.1f%%  Value %d",
            stats.block or 0, math.floor(stats.blockValue or 0))) end
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

    local run = self.RunState
    if targetType == "equipment" and targetKey == "offhand" then
        local mainHand = run and run.equipment and run.equipment.mainhand
        if IsTwoHandedWeapon(mainHand) then
            return false
        end
    end

    if targetType == "equipment" and targetKey == "mainhand"
        and IsTwoHandedWeapon(drag.item) then
        local offHand = run and run.equipment and run.equipment.offhand
        if offHand and not FindForcedOffhandBackpackSlot(run, drag, targetItem) then
            return false
        end
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
        local run = self.RunState
        local targetItem = self:GetCharacterInventoryItem(targetType, targetKey)

        if targetType == "equipment" and targetKey == "mainhand"
            and IsTwoHandedWeapon(drag.item)
            and run and run.equipment and run.equipment.offhand
            and not FindForcedOffhandBackpackSlot(run, drag, targetItem) then
            self:AddCombatLog(
                "Backpack full: free a slot before equipping a two-handed weapon.",
                "warning"
            )
        elseif targetType == "equipment" and targetKey == "offhand"
            and run and run.equipment and IsTwoHandedWeapon(run.equipment.mainhand) then
            self:AddCombatLog(
                "You cannot equip an off-hand item while using a two-handed weapon.",
                "warning"
            )
        elseif targetType == "equipment"
            and drag.item.studioDefined
            and (tonumber(drag.item.requiredLevel) or 1) > (tonumber(run and run.runLevel) or 1) then
            self:AddCombatLog(
                string.format(
                    "%s requires Run Level %d.",
                    drag.item.name or "That item",
                    tonumber(drag.item.requiredLevel) or 1
                ),
                "warning"
            )
        elseif targetType == "equipment" and not drag.item.equipLoc then
            self:AddCombatLog(
                (drag.item.name or "That item") .. " is not equippable. Keep it as loot or sell it.",
                "warning"
            )
        else
            self:AddCombatLog("That item cannot be placed there.", "warning")
        end

        self:CancelCharacterItemDrag()
        return false
    end

    if drag.sourceType == targetType and drag.sourceKey == targetKey then
        self:CancelCharacterItemDrag()
        return true
    end

    local run = self.RunState
    local sourceItem = drag.item
    local targetItem = self:GetCharacterInventoryItem(targetType, targetKey)
    local forcedOffHand
    local forcedBackpackSlot

    if targetType == "equipment" and targetKey == "mainhand"
        and IsTwoHandedWeapon(sourceItem)
        and run and run.equipment and run.equipment.offhand then
        forcedOffHand = run.equipment.offhand
        forcedBackpackSlot = FindForcedOffhandBackpackSlot(run, drag, targetItem)

        if not forcedBackpackSlot then
            self:AddCombatLog(
                "Backpack full: free a slot before equipping a two-handed weapon.",
                "warning"
            )
            self:CancelCharacterItemDrag()
            return false
        end
    end

    -- Perform the normal source/target swap first.
    self:SetCharacterInventoryItem(drag.sourceType, drag.sourceKey, targetItem)
    self:SetCharacterInventoryItem(targetType, targetKey, sourceItem)

    -- A 2H main hand owns both hands. Preserve the displaced off-hand exactly
    -- as-is (including baseline/extraction ownership metadata) and move it to
    -- the backpack instead of deleting or re-tagging it as new run loot.
    if forcedOffHand and forcedBackpackSlot then
        run.equipment.offhand = nil
        run.backpack = run.backpack or {}
        run.backpack[forcedBackpackSlot] = forcedOffHand

        self:AddCombatLog(
            string.format(
                "%s moved to the backpack because %s is two-handed.",
                forcedOffHand.name or "Off-hand item",
                sourceItem.name or "the equipped weapon"
            ),
            "system"
        )
    end

    self:CancelCharacterItemDrag()

    self:RecalculateRunGearStats()
    self:RefreshRunWeaponFromEquipment()
    self:RefreshCharacterSheet()
    self:RefreshActionButtons()

    return true
end
local function GetQualityColor(quality)
    local colors = {
        [0] = { 0.62, 0.62, 0.62 },
        [1] = { 1.00, 1.00, 1.00 },
        [2] = { 0.12, 1.00, 0.00 },
        [3] = { 0.00, 0.44, 0.87 },
        [4] = { 0.64, 0.21, 0.93 },
        [5] = { 1.00, 0.50, 0.00 },
        [6] = { 0.90, 0.80, 0.50 },
        [7] = { 0.00, 0.80, 1.00 },
    }

    local color = colors[tonumber(quality) or 1] or colors[1]
    return color[1], color[2], color[3]
end

local function FormatCopperValue(copper)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local remainingCopper = copper % 100

    if gold > 0 then
        return string.format("%dg %ds %dc", gold, silver, remainingCopper)
    end
    if silver > 0 then
        return string.format("%ds %dc", silver, remainingCopper)
    end
    return string.format("%dc", remainingCopper)
end

local function AddArcadeConversionToTooltip(item)
    if not item then
        return
    end

    GA:EnsureArcadeItemConversion(item)

    local weapon = item.arcadeWeapon
    local converted = item.arcadeItem

    if item.tier then
        GameTooltip:AddLine(string.format("%s  -  Item Level %d", tostring(item.tier), tonumber(item.itemLevel) or 1), 0.75, 0.70, 0.62)
        if item.buildProfile and item.buildProfile ~= "" and item.buildProfile ~= "NONE" then
            GameTooltip:AddLine("Build: " .. tostring(item.buildProfile), 1.00, 0.72, 0.12)
        end
    elseif item.itemLevel then
        GameTooltip:AddLine(string.format("Item Level %d", tonumber(item.itemLevel) or 1), 0.75, 0.70, 0.62)
    end

    if item.equipLoc then
        GameTooltip:AddLine(
            "Slot: " .. tostring(item.slotLabel or EQUIP_LOCATION_LABELS[item.equipLoc] or item.equipLoc),
            0.92, 0.89, 0.82
        )
    elseif item.category and string.upper(tostring(item.category)) ~= "CONSUMABLE" then
        GameTooltip:AddLine("Not equippable", 0.75, 0.75, 0.75)
    end

    local requiredLevel = math.max(1, math.floor(tonumber(item.requiredLevel) or 1))
    if requiredLevel > 1 then
        local runLevel = GA.RunState and tonumber(GA.RunState.runLevel) or 0
        local allowed = runLevel >= requiredLevel
        GameTooltip:AddLine(
            string.format("Requires Run Level %d", requiredLevel),
            allowed and 0.75 or 1.00,
            allowed and 0.75 or 0.20,
            allowed and 0.75 or 0.20
        )
    end

    if weapon then
        GameTooltip:AddLine("Weapon", 0.65, 0.60, 0.52)
        GameTooltip:AddLine(
            string.format("Damage %d - %d", weapon.damageMin or 0, weapon.damageMax or 0),
            0.92, 0.89, 0.82
        )
        if (weapon.attackPower or 0) > 0 then
            GameTooltip:AddLine(string.format("Attack Power +%d", weapon.attackPower), 1.00, 0.72, 0.12)
        end
        GameTooltip:AddLine(
            string.format("%s  -  %s  -  Range %d",
                weapon.style or "Weapon",
                weapon.speed or "NORMAL",
                weapon.range or 1),
            0.92, 0.89, 0.82,
            true
        )

        if weapon.traitName then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(weapon.traitName, 1, 0.72, 0.12)
            GameTooltip:AddLine(weapon.traitDescription or "", 0.82, 0.79, 0.72, true)
        end
        if item.price ~= nil then
            GameTooltip:AddLine("Value " .. FormatCopperValue(item.price), 1.00, 0.82, 0.20)
        end

        return
    end

    if converted then
        GameTooltip:AddLine(converted.style or "Gear", 0.65, 0.60, 0.52)

        if (converted.health or 0) > 0 then
            GameTooltip:AddLine(string.format("Health +%d", converted.health), 0.30, 1.00, 0.38)
        end

        if (converted.attackPower or 0) > 0 then
            GameTooltip:AddLine(string.format("Attack Power +%d", converted.attackPower), 1.00, 0.72, 0.12)
        end

        if (converted.armor or 0) > 0 then
            GameTooltip:AddLine(string.format("Armor +%d", converted.armor), 0.92, 0.89, 0.82)
        end

        if (converted.dodge or 0) > 0 then
            GameTooltip:AddLine(string.format("Dodge +%.1f%%", converted.dodge), 0.92, 0.89, 0.82)
        end

        if (converted.crit or 0) > 0 then
            GameTooltip:AddLine(string.format("Crit +%.1f%%", converted.crit), 0.92, 0.89, 0.82)
        end

        if (converted.block or 0) > 0 then
            GameTooltip:AddLine(string.format("Block +%.1f%%", converted.block), 0.92, 0.89, 0.82)
        end

        if converted.traitName then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(converted.traitName, 1, 0.72, 0.12)
            GameTooltip:AddLine(converted.traitDescription or "", 0.82, 0.79, 0.72, true)
        end
        if item.price ~= nil then
            GameTooltip:AddLine("Value " .. FormatCopperValue(item.price), 1.00, 0.82, 0.20)
        end

        return
    end

    if item.category == "CONSUMABLE" or item.itemType == "Consumable" then
        GameTooltip:AddLine("Consumable", 0.65, 0.60, 0.52)
        local effect = tostring(item.consumableEffect or "NONE")
        local value = tonumber(item.effectValue) or 0

        if effect == "HEAL_PERCENT" then
            GameTooltip:AddLine(string.format("Restores %.0f%% of maximum HP.", value), 0.30, 1.00, 0.38)
        elseif effect == "HEAL_FLAT" then
            GameTooltip:AddLine(string.format("Restores %d HP.", math.floor(value + 0.5)), 0.30, 1.00, 0.38)
        elseif effect == "RESOURCE" then
            GameTooltip:AddLine(string.format("Restores %d class resource.", math.floor(value + 0.5)), 0.30, 1.00, 0.38)
        end

        if (tonumber(item.stackMax) or 1) > 1 then
            GameTooltip:AddLine(
                string.format("Stack %d / %d", tonumber(item.stackCount) or 1, tonumber(item.stackMax) or 1),
                0.75, 0.75, 0.75
            )
        end
        if item.price ~= nil then
            GameTooltip:AddLine("Value " .. FormatCopperValue(item.price), 1.00, 0.82, 0.20)
        end
        return
    end

    if item.price ~= nil then
        GameTooltip:AddLine("Value " .. FormatCopperValue(item.price), 1.00, 0.82, 0.20)
    end
    GameTooltip:AddLine("No GoblinArcade conversion available.", 0.60, 0.58, 0.54, true)
end

local function ShowItemTooltip(button)
    local item = button.gaItem
    if not item then
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()

    local r, g, b = GetQualityColor(item.quality)
    GameTooltip:SetText(item.name or "Dungeon item", r, g, b)

    AddArcadeConversionToTooltip(item)
    if item.ownershipSource == "baseline" then
        GameTooltip:AddLine("BASELINE", 0.65, 0.65, 0.65)
    elseif item.ownershipSource == "loadout" then
        GameTooltip:AddLine("LOADOUT", 0.35, 0.85, 1.00)
    elseif item.ownershipSource == "found" then
        GameTooltip:AddLine("FOUND THIS RUN", 1.00, 0.82, 0.20)
    end
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

    local countText = CreateText(button, "GameFontNormalSmall", "")
    countText:SetPoint("BOTTOMRIGHT", -4, 3)
    countText:SetTextColor(1, 1, 1)
    button.countText = countText

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

    local statsFrame = CreateFrame("Frame", nil, gearPanel)
    statsFrame:SetSize(156, 144)
    statsFrame:SetPoint("TOP", health, "BOTTOM", 0, -6)
    self.CharacterSheetStatsFrame = statsFrame
    self.CharacterSheetStatRows = {}

    local statLabels = {
        { key = "primary", label = "Primary" },
        { key = "attackPower", label = "Attack Power" },
        { key = "armor", label = "Armor" },
        { key = "skills", label = "Weapon / Defense" },
        { key = "hitCrit", label = "Hit / Crit" },
        { key = "expertise", label = "Expertise" },
        { key = "avoidance", label = "Dodge / Parry" },
        { key = "block", label = "Block / Value" },
    }

    for i, definition in ipairs(statLabels) do
        local row = CreateText(statsFrame, "GameFontHighlightSmall", "")
        row:SetPoint("TOP", 0, -((i - 1) * 17))
        row:SetWidth(156)
        row:SetJustifyH("CENTER")
        row:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
        self.CharacterSheetStatRows[definition.key] = row
    end

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
            if button.countText then
                local count = math.max(1, math.floor(tonumber(item.stackCount) or 1))
                button.countText:SetText(count > 1 and tostring(count) or "")
            end
        else
            button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            button.icon:SetAlpha(0.16)
            if button.countText then button.countText:SetText("") end
        end
    end

    for i, button in ipairs(self.CharacterBackpackButtons or {}) do
        local item = run.backpack and run.backpack[i]
        button.gaItem = item

        if item then
            button.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            button.icon:SetAlpha(1)
            if button.countText then
                local count = math.max(1, math.floor(tonumber(item.stackCount) or 1))
                button.countText:SetText(count > 1 and tostring(count) or "")
            end
        else
            button.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
            button.icon:SetAlpha(0.12)
            if button.countText then button.countText:SetText("") end
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
    if not run or not item then
        return false
    end

    run.backpack = run.backpack or {}
    local incoming = CopyTable(item)
    incoming.acquiredRunId = incoming.acquiredRunId or run.runId
    if incoming.acquiredRunId == run.runId then
        incoming.ownershipSource = "found"
    end
    local amount = math.max(1, math.floor(tonumber(incoming.stackCount) or 1))
    local stackMax = math.max(1, math.floor(tonumber(incoming.stackMax) or 1))
    local stackable = incoming.studioItemId and stackMax > 1

    if stackable then
        local capacity = 0
        for i = 1, BACKPACK_SLOTS do
            local existing = run.backpack[i]
            if existing and existing.studioItemId == incoming.studioItemId
                and existing.acquiredRunId == incoming.acquiredRunId then
                local current = math.max(1, math.floor(tonumber(existing.stackCount) or 1))
                local existingMax = math.max(1, math.floor(tonumber(existing.stackMax) or stackMax))
                capacity = capacity + math.max(0, existingMax - current)
            elseif not existing then
                capacity = capacity + stackMax
            end
        end

        if capacity < amount then
            return false
        end

        for i = 1, BACKPACK_SLOTS do
            if amount <= 0 then break end
            local existing = run.backpack[i]
            if existing and existing.studioItemId == incoming.studioItemId
                and existing.acquiredRunId == incoming.acquiredRunId then
                local current = math.max(1, math.floor(tonumber(existing.stackCount) or 1))
                local existingMax = math.max(1, math.floor(tonumber(existing.stackMax) or stackMax))
                local add = math.min(amount, math.max(0, existingMax - current))
                if add > 0 then
                    existing.stackCount = current + add
                    amount = amount - add
                end
            end
        end

        for i = 1, BACKPACK_SLOTS do
            if amount <= 0 then break end
            if not run.backpack[i] then
                local storedItem = CopyTable(incoming)
                storedItem.stackCount = math.min(amount, stackMax)
                self:EnsureArcadeItemConversion(storedItem)
                run.backpack[i] = storedItem
                amount = amount - storedItem.stackCount
            end
        end
    else
        for i = 1, BACKPACK_SLOTS do
            if not run.backpack[i] then
                local storedItem = CopyTable(incoming)
                self:EnsureArcadeItemConversion(storedItem)
                run.backpack[i] = storedItem
                amount = 0
                break
            end
        end

        if amount > 0 then
            return false
        end
    end

    if self.CharacterSheetFrame and self.CharacterSheetFrame:IsShown() then
        self:RefreshCharacterSheet()
    end
    return true
end
