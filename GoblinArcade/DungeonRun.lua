local _, GA = ...

local UI = GA.UI
local COLORS = UI.COLORS
local ApplyBackdrop = UI.ApplyBackdrop
local CreateText = UI.CreateText
local CreateFlatButton = UI.CreateFlatButton

local function CreateStatRow(parent, labelText, valueText, y)
    local label = CreateText(parent, "GameFontHighlightSmall", labelText)
    label:SetPoint("TOPLEFT", 12, y)
    label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local value = CreateText(parent, "GameFontNormalSmall", valueText)
    value:SetPoint("TOPRIGHT", -12, y)
    value:SetJustifyH("RIGHT")
    value:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

    return value
end

local function CreateRelicSlot(parent, index, x, y)
    local slot = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    slot:SetSize(48, 48)
    slot:SetPoint("TOPLEFT", x, y)
    ApplyBackdrop(slot, { 0.035, 0.030, 0.024, 1 }, COLORS.goldDim)

    local number = CreateText(slot, "GameFontDisableSmall", tostring(index))
    number:SetPoint("TOPLEFT", 4, -3)
    number:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    return slot
end

local GRID_WIDTH = 13
local GRID_HEIGHT = 13
local START_X = 7
local START_Y = 7
local EXIT_X = 12
local EXIT_Y = 11

local STATIC_WALLS = {
    ["4:3"] = true, ["4:4"] = true, ["4:5"] = true,
    ["9:2"] = true, ["9:3"] = true,
    ["3:9"] = true, ["4:9"] = true, ["5:9"] = true,
    ["10:8"] = true, ["10:9"] = true, ["10:10"] = true,
}

local STATIC_MARKERS = {
    ["3:6"] = { text = "S", color = "muted" },
    ["9:11"] = { text = "$", color = "gold" },
    ["12:11"] = { text = ">", color = "green" },
}

local KOBOLD_START_X = 11
local KOBOLD_START_Y = 4
local KOBOLD_TEXTURE = "Interface\\AddOns\\GoblinArcade\\Media\\Monsters\\kobold"

local function CellKey(x, y)
    return tostring(x) .. ":" .. tostring(y)
end

local function IsDungeonWall(x, y)
    if x < 1 or x > GRID_WIDTH or y < 1 or y > GRID_HEIGHT then
        return true
    end

    if x == 1 or x == GRID_WIDTH or y == 1 or y == GRID_HEIGHT then
        return true
    end

    return STATIC_WALLS[CellKey(x, y)] == true
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

local PATH_DIRECTIONS = {
    { 0, -1 },
    { 1, 0 },
    { 0, 1 },
    { -1, 0 },
}

local function FindNextStep(startX, startY, targetX, targetY)
    if startX == targetX and startY == targetY then
        return nil, nil
    end

    local queue = {
        { x = startX, y = startY },
    }
    local head = 1
    local visited = {
        [CellKey(startX, startY)] = true,
    }
    local parent = {}
    local foundKey

    while head <= #queue do
        local current = queue[head]
        head = head + 1

        for _, delta in ipairs(PATH_DIRECTIONS) do
            local nextX = current.x + delta[1]
            local nextY = current.y + delta[2]
            local nextKey = CellKey(nextX, nextY)

            if not visited[nextKey] and not IsDungeonWall(nextX, nextY) then
                visited[nextKey] = true
                parent[nextKey] = CellKey(current.x, current.y)

                if nextX == targetX and nextY == targetY then
                    foundKey = nextKey
                    head = #queue + 1
                    break
                end

                queue[#queue + 1] = { x = nextX, y = nextY }
            end
        end
    end

    if not foundKey then
        return nil, nil
    end

    local startKey = CellKey(startX, startY)
    local stepKey = foundKey

    while parent[stepKey] and parent[stepKey] ~= startKey do
        stepKey = parent[stepKey]
    end

    local stepX, stepY = string.match(stepKey, "^(%d+):(%d+)$")
    return tonumber(stepX), tonumber(stepY)
end

local function IsAdjacent(x1, y1, x2, y2)
    return math.abs(x1 - x2) + math.abs(y1 - y2) == 1
end

local function CreateGrid(parent)
    local grid = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    grid:SetSize(350, 350)
    grid:SetPoint("TOP", 0, -32)
    ApplyBackdrop(grid, { 0.025, 0.022, 0.018, 1 }, COLORS.goldDim)

    local size = 26
    local gap = 1
    local stride = size + gap

    grid.cells = {}

    for row = 1, GRID_HEIGHT do
        for col = 1, GRID_WIDTH do
            local cell = CreateFrame("Frame", nil, grid, "BackdropTemplate")
            cell:SetSize(size, size)
            cell:SetPoint("TOPLEFT", (col - 1) * stride, -((row - 1) * stride))

            local wall = IsDungeonWall(col, row)
            if wall then
                ApplyBackdrop(cell, { 0.12, 0.095, 0.06, 1 }, { 0.20, 0.16, 0.09, 1 })
            else
                ApplyBackdrop(cell, { 0.055, 0.048, 0.038, 1 }, { 0.09, 0.075, 0.055, 1 })
            end

            local enemyIcon = cell:CreateTexture(nil, "OVERLAY")
            enemyIcon:SetSize(22, 22)
            enemyIcon:SetPoint("CENTER")
            enemyIcon:SetTexture(KOBOLD_TEXTURE)
            enemyIcon:SetTexCoord(0, 1, 0, 1)
            enemyIcon:Hide()

            local marker = CreateText(cell, "GameFontNormal", "")
            marker:SetPoint("CENTER")

            grid.cells[CellKey(col, row)] = {
                frame = cell,
                marker = marker,
                enemyIcon = enemyIcon,
                wall = wall,
            }
        end
    end

    return grid
end

function GA:CreateDungeonRunPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)
    page:Hide()
    self.DungeonRunPage = page

    local title = CreateText(page, "GameFontNormalHuge", "DUNGEON RUN")
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

    local subtitle = CreateText(page, "GameFontHighlightSmall", "TURN-BASED ROGUELIKE  -  RUN MODE PROTOTYPE")
    subtitle:SetPoint("TOPRIGHT", -18, -22)
    subtitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local body = CreateFrame("Frame", nil, page)
    body:SetPoint("TOPLEFT", 18, -58)
    body:SetPoint("BOTTOMRIGHT", -18, 78)

    local left = CreateFrame("Frame", nil, body, "BackdropTemplate")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(182)
    ApplyBackdrop(left, { 0.050, 0.043, 0.034, 1 }, COLORS.goldDim)

    local statsTitle = CreateText(left, "GameFontNormalSmall", "RUN STATS")
    statsTitle:SetPoint("TOPLEFT", 12, -14)
    statsTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    self.DungeonHealth = CreateStatRow(left, "HEALTH", "--", -38)
    self.DungeonPower = CreateStatRow(left, "WEAPON", "--", -62)
    self.DungeonDodge = CreateStatRow(left, "DODGE", "--", -86)

    local gearTitle = CreateText(left, "GameFontNormalSmall", "WOW GEAR INPUT")
    gearTitle:SetPoint("TOPLEFT", 12, -126)
    gearTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local runPortraitFrame = CreateFrame("Frame", nil, left, "BackdropTemplate")
    runPortraitFrame:SetSize(158, 92)
    runPortraitFrame:SetPoint("TOPLEFT", 12, -126)
    ApplyBackdrop(runPortraitFrame, { 0.035, 0.030, 0.024, 1 }, COLORS.goldDim)
    runPortraitFrame:Hide()
    self.DungeonRunPortraitFrame = runPortraitFrame

    local runPortraitBorder = CreateFrame("Frame", nil, runPortraitFrame, "BackdropTemplate")
    runPortraitBorder:SetSize(64, 64)
    runPortraitBorder:SetPoint("LEFT", 10, 0)
    ApplyBackdrop(runPortraitBorder, { 0.02, 0.02, 0.02, 1 }, COLORS.gold)

    local runPortrait = runPortraitBorder:CreateTexture(nil, "ARTWORK")
    runPortrait:SetPoint("TOPLEFT", 2, -2)
    runPortrait:SetPoint("BOTTOMRIGHT", -2, 2)
    runPortrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    self.DungeonRunPortrait = runPortrait

    local runPortraitName = CreateText(runPortraitFrame, "GameFontNormal", "")
    runPortraitName:SetPoint("TOPLEFT", runPortraitBorder, "TOPRIGHT", 8, -8)
    runPortraitName:SetPoint("RIGHT", runPortraitFrame, "RIGHT", -8, 0)
    runPortraitName:SetJustifyH("LEFT")
    runPortraitName:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    self.DungeonRunPortraitName = runPortraitName

    local runPortraitMeta = CreateText(runPortraitFrame, "GameFontHighlightSmall", "")
    runPortraitMeta:SetPoint("TOPLEFT", runPortraitName, "BOTTOMLEFT", 0, -6)
    runPortraitMeta:SetPoint("RIGHT", runPortraitFrame, "RIGHT", -8, 0)
    runPortraitMeta:SetJustifyH("LEFT")
    runPortraitMeta:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonRunPortraitMeta = runPortraitMeta

    local gearHint = CreateText(left, "GameFontHighlightSmall", "Main hand")
    gearHint:SetPoint("TOPLEFT", 12, -148)
    gearHint:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local itemIconButton = CreateFrame("Button", nil, left, "BackdropTemplate")
    itemIconButton:SetSize(42, 42)
    itemIconButton:SetPoint("TOPLEFT", 12, -168)
    ApplyBackdrop(itemIconButton, { 0.025, 0.022, 0.018, 1 }, COLORS.goldDim)

    local itemIcon = itemIconButton:CreateTexture(nil, "ARTWORK")
    itemIcon:SetPoint("TOPLEFT", 2, -2)
    itemIcon:SetPoint("BOTTOMRIGHT", -2, 2)
    itemIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    self.DungeonMainHandIcon = itemIcon

    itemIconButton:SetScript("OnEnter", function(button)
        if GA.DungeonMainHandLink then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(GA.DungeonMainHandLink)
            GameTooltip:Show()
        end
    end)
    itemIconButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local itemName = CreateText(left, "GameFontNormalSmall", "Scanning...")
    itemName:SetPoint("TOPLEFT", itemIconButton, "TOPRIGHT", 8, -2)
    itemName:SetPoint("RIGHT", left, "RIGHT", -8, 0)
    itemName:SetJustifyH("LEFT")
    itemName:SetWordWrap(true)
    itemName:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    self.DungeonMainHandName = itemName

    local itemLevel = CreateText(left, "GameFontHighlightSmall", "")
    itemLevel:SetPoint("TOPLEFT", itemIconButton, "TOPRIGHT", 8, -22)
    itemLevel:SetPoint("RIGHT", left, "RIGHT", -8, 0)
    itemLevel:SetJustifyH("LEFT")
    itemLevel:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.DungeonMainHandLevel = itemLevel

    local itemMeta = CreateText(left, "GameFontDisableSmall", "")
    itemMeta:SetPoint("TOPLEFT", 12, -218)
    itemMeta:SetPoint("RIGHT", left, "RIGHT", -8, 0)
    itemMeta:SetJustifyH("LEFT")
    itemMeta:SetWordWrap(true)
    itemMeta:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonMainHandMeta = itemMeta
    self.DungeonGearWidgets = {
        gearTitle,
        gearHint,
        itemIconButton,
        itemName,
        itemLevel,
        itemMeta,
    }

    local conversionTitle = CreateText(left, "GameFontNormalSmall", "ARCADE CONVERSION")
    conversionTitle:SetPoint("TOPLEFT", 12, -252)
    conversionTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local arcadeDamage = CreateText(left, "GameFontNormal", "Damage --")
    arcadeDamage:SetPoint("TOPLEFT", 12, -276)
    arcadeDamage:SetPoint("RIGHT", left, "RIGHT", -10, 0)
    arcadeDamage:SetJustifyH("LEFT")
    arcadeDamage:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    self.DungeonArcadeDamage = arcadeDamage

    local arcadeStyle = CreateText(left, "GameFontHighlightSmall", "")
    arcadeStyle:SetPoint("TOPLEFT", 12, -298)
    arcadeStyle:SetPoint("RIGHT", left, "RIGHT", -10, 0)
    arcadeStyle:SetJustifyH("LEFT")
    arcadeStyle:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonArcadeStyle = arcadeStyle

    local arcadeTraitName = CreateText(left, "GameFontNormalSmall", "")
    arcadeTraitName:SetPoint("TOPLEFT", 12, -326)
    arcadeTraitName:SetPoint("RIGHT", left, "RIGHT", -10, 0)
    arcadeTraitName:SetJustifyH("LEFT")
    arcadeTraitName:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.DungeonArcadeTraitName = arcadeTraitName

    local arcadeTraitDesc = CreateText(left, "GameFontDisableSmall", "")
    arcadeTraitDesc:SetPoint("TOPLEFT", 12, -346)
    arcadeTraitDesc:SetWidth(156)
    arcadeTraitDesc:SetJustifyH("LEFT")
    arcadeTraitDesc:SetJustifyV("TOP")
    arcadeTraitDesc:SetWordWrap(true)
    arcadeTraitDesc:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonArcadeTraitDesc = arcadeTraitDesc

    local right = CreateFrame("Frame", nil, body, "BackdropTemplate")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(138)
    ApplyBackdrop(right, { 0.050, 0.043, 0.034, 1 }, COLORS.goldDim)

    local relicTitle = CreateText(right, "GameFontNormalSmall", "RELICS  0 / 6")
    relicTitle:SetPoint("TOPLEFT", 12, -12)
    relicTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    for i = 1, 6 do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        CreateRelicSlot(right, i, 12 + col * 58, -38 - row * 58)
    end

    local runTitle = CreateText(right, "GameFontNormalSmall", "RUN")
    runTitle:SetPoint("TOPLEFT", 12, -228)
    runTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    self.DungeonFloorValue = CreateStatRow(right, "FLOOR", "1 / 9", -252)
    self.DungeonScoreValue = CreateStatRow(right, "SCORE", "0", -276)
    self.DungeonTurnsValue = CreateStatRow(right, "TURNS", "0", -300)

    local begin = CreateFlatButton(right, "BEGIN RUN", 114, 36)
    begin:SetPoint("BOTTOM", 0, 12)
    begin:SetEnabled(false)
    begin.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    begin:SetScript("OnClick", function()
        GA:BeginDungeonRun()
    end)
    self.DungeonBeginButton = begin

    local center = CreateFrame("Frame", nil, body, "BackdropTemplate")
    center:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0)
    center:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", -8, 0)
    ApplyBackdrop(center, { 0.040, 0.035, 0.028, 1 }, COLORS.goldDim)

    local floor = CreateText(center, "GameFontNormalSmall", "FLOOR 1  -  THE TEST CELLAR")
    floor:SetPoint("TOP", 0, -10)
    floor:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.DungeonFloorTitle = floor

    self.DungeonGrid = CreateGrid(center)

    local legend = CreateText(center, "GameFontDisableSmall", "@ YOU    KOBOLD ICON    S TEST    $ CHEST    > EXIT")
    legend:SetPoint("BOTTOM", 0, 9)
    legend:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local actionBar = CreateFrame("Frame", nil, page, "BackdropTemplate")
    actionBar:SetPoint("BOTTOMLEFT", 18, 16)
    actionBar:SetPoint("BOTTOMRIGHT", -18, 16)
    actionBar:SetHeight(50)
    ApplyBackdrop(actionBar, { 0.050, 0.043, 0.034, 1 }, COLORS.goldDim)

    local actionLabel = CreateText(actionBar, "GameFontNormalSmall", "ACTIONS")
    actionLabel:SetPoint("LEFT", 12, 0)
    actionLabel:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local actions = {
        { "1", "ATTACK" },
        { "2", "ABILITY" },
        { "3", "ABILITY" },
        { "4", "POTION" },
    }

    for i, action in ipairs(actions) do
        local button = CreateFlatButton(actionBar, action[1] .. "  " .. action[2], 116, 32)
        button:SetPoint("LEFT", 88 + (i - 1) * 124, 0)
        button:SetEnabled(false)
        button.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    end

    local state = CreateText(actionBar, "GameFontDisableSmall", "READY - BEGIN A RUN")
    state:SetPoint("RIGHT", -12, 0)
    state:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonRunStateText = state

    page:EnableKeyboard(true)
    if page.SetPropagateKeyboardInput then
        page:SetPropagateKeyboardInput(true)
    end

    page:SetScript("OnKeyDown", function(pageFrame, key)
        local runActive = GA.RunState and GA.RunState.active

        if not runActive then
            if pageFrame.SetPropagateKeyboardInput then
                pageFrame:SetPropagateKeyboardInput(true)
            end
            return
        end

        -- The propagation state is already disabled when the run begins. Keep
        -- it disabled for the entire run so WoW never receives movement keys.
        if pageFrame.SetPropagateKeyboardInput then
            pageFrame:SetPropagateKeyboardInput(false)
        end

        if key == "ESCAPE" then
            if GA.MainFrame then
                GA.MainFrame:Hide()
            end
            return
        end

        local movement = {
            W = { 0, -1 },
            UP = { 0, -1 },
            S = { 0, 1 },
            DOWN = { 0, 1 },
            A = { -1, 0 },
            LEFT = { -1, 0 },
            D = { 1, 0 },
            RIGHT = { 1, 0 },
        }

        local delta = movement[key]
        if delta then
            GA:MoveDungeonPlayer(delta[1], delta[2])
        end
    end)

    self:RenderDungeonGrid()
    return page
end

function GA:SetDungeonRunPortraitMode(active)
    if self.DungeonGearWidgets then
        for _, widget in ipairs(self.DungeonGearWidgets) do
            if active then
                widget:Hide()
            else
                widget:Show()
            end
        end
    end

    if self.DungeonRunPortraitFrame then
        if active then
            local snapshot = self.RunState and self.RunState.snapshot
            local name = snapshot and snapshot.name or UnitName("player") or "Unknown"
            local level = snapshot and snapshot.level or UnitLevel("player") or 0
            local className = snapshot and snapshot.className or UnitClass("player") or "Adventurer"

            self.DungeonRunPortraitName:SetText(name)
            self.DungeonRunPortraitMeta:SetText(string.format("Level %d %s", level, className))

            if self.DungeonRunPortrait then
                SetPortraitTexture(self.DungeonRunPortrait, "player")
            end

            self.DungeonRunPortraitFrame:Show()
        else
            self.DungeonRunPortraitFrame:Hide()
        end
    end
end

local QUALITY_NAMES = {
    [0] = "Poor",
    [1] = "Common",
    [2] = "Uncommon",
    [3] = "Rare",
    [4] = "Epic",
    [5] = "Legendary",
    [6] = "Artifact",
    [7] = "Heirloom",
}

local function GetCompatItemInfo(itemInfo)
    if C_Item and C_Item.GetItemInfo then
        local a, b, c, d, e, f, g = C_Item.GetItemInfo(itemInfo)

        -- Some modern clients expose item info as a structured table.
        if type(a) == "table" then
            return a.itemName or a.name,
                a.itemLink or a.hyperlink,
                a.itemQuality or a.quality,
                a.itemLevel or a.level,
                a.itemMinLevel or a.minLevel,
                a.itemType or a.type,
                a.itemSubType or a.subType
        end

        return a, b, c, d, e, f, g
    end

    if type(GetItemInfo) == "function" then
        return GetItemInfo(itemInfo)
    end

    return nil
end

local function GetCompatItemInstant(itemInfo)
    if C_Item and C_Item.GetItemInfoInstant then
        local itemID, itemType, itemSubType, equipLoc = C_Item.GetItemInfoInstant(itemInfo)
        return itemID, itemType, itemSubType, equipLoc
    end

    if type(GetItemInfoInstant) == "function" then
        local itemID, itemType, itemSubType, equipLoc = GetItemInfoInstant(itemInfo)
        return itemID, itemType, itemSubType, equipLoc
    end

    return nil, nil, nil, nil
end

function GA:RefreshMainHandInfo(force)
    if not self.DungeonMainHandName then
        return
    end

    if self.RunState and self.RunState.active and not force then
        return
    end

    local slotID = 16
    local itemLink = GetInventoryItemLink("player", slotID)
    local texture = GetInventoryItemTexture("player", slotID)

    self.DungeonMainHandLink = itemLink

    if self.DungeonMainHandIcon then
        self.DungeonMainHandIcon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    end

    if not itemLink then
        self.DungeonMainHandName:SetText("No main hand")
        self.DungeonMainHandName:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        self.DungeonMainHandLevel:SetText("")
        self.DungeonMainHandMeta:SetText("Equip a weapon to scan it.")
        self.DungeonArcadeDamage:SetText("Damage --")
        self.DungeonArcadeStyle:SetText("")
        self.DungeonArcadeTraitName:SetText("")
        self.DungeonArcadeTraitDesc:SetText("")
        self.DungeonPower:SetText("--")
        self.ArcadeMainHand = nil

        if self.DungeonBeginButton and not (self.RunState and self.RunState.active) then
            self.DungeonBeginButton:SetEnabled(false)
            self.DungeonBeginButton.label:SetText("BEGIN RUN")
            self.DungeonBeginButton.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        end
        return
    end

    local name, _, quality, itemLevel, _, itemType, itemSubType = GetCompatItemInfo(itemLink)
    local itemID, instantType, instantSubType, equipLoc = GetCompatItemInstant(itemLink)

    itemType = itemType or instantType
    itemSubType = itemSubType or instantSubType

    if not itemLevel and C_Item and C_Item.GetDetailedItemLevelInfo then
        itemLevel = C_Item.GetDetailedItemLevelInfo(itemLink)
    end

    if quality == nil and type(GetInventoryItemQuality) == "function" then
        quality = GetInventoryItemQuality("player", slotID)
    end

    if not name then
        -- Equipped item links already contain a readable name, so keep the UI
        -- useful even while the rest of the item data is still loading.
        name = itemLink:match("%[(.-)%]") or "Loading item..."
    end

    local qualityColor = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if qualityColor then
        self.DungeonMainHandName:SetTextColor(qualityColor.r, qualityColor.g, qualityColor.b)
    else
        self.DungeonMainHandName:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    end

    self.DungeonMainHandName:SetText(name)
    self.DungeonMainHandLevel:SetText("Item Level " .. tostring(itemLevel or "?"))

    local rarity = QUALITY_NAMES[quality] or "Unknown"
    local typeName = itemSubType or itemType or "Unknown type"
    self.DungeonMainHandMeta:SetText(rarity .. "  -  " .. typeName)

    if self.WeaponGenerator and self.WeaponGenerator.Convert then
        local weapon = self.WeaponGenerator:Convert({
            itemID = itemID,
            name = name,
            itemLevel = itemLevel,
            quality = quality,
            itemType = itemType,
            itemSubType = itemSubType,
            equipLoc = equipLoc,
        })

        self.ArcadeMainHand = weapon

        if weapon then
            self.DungeonArcadeDamage:SetText(string.format("Damage %d - %d", weapon.damageMin, weapon.damageMax))
            self.DungeonArcadeStyle:SetText(
                string.format("%s  -  %s  -  Range %d", weapon.style, weapon.speed, weapon.range)
            )
            self.DungeonPower:SetText(string.format("%d-%d", weapon.damageMin, weapon.damageMax))

            if weapon.traitName then
                self.DungeonArcadeTraitName:SetText(weapon.traitName)
                self.DungeonArcadeTraitDesc:SetText(weapon.traitDescription or "")
            else
                self.DungeonArcadeTraitName:SetText("NO SIGNATURE TRAIT")
                self.DungeonArcadeTraitDesc:SetText("Uncommon or better weapons unlock their archetype trait.")
            end

            if self.DungeonBeginButton and not (self.RunState and self.RunState.active) then
                self.DungeonBeginButton:SetEnabled(true)
                self.DungeonBeginButton.label:SetText(self.RunState and self.RunState.completed and "BEGIN AGAIN" or "BEGIN RUN")
                self.DungeonBeginButton.label:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
            end
        end
    end
end

function GA:RenderDungeonGrid()
    if not self.DungeonGrid or not self.DungeonGrid.cells then
        return
    end

    for y = 1, GRID_HEIGHT do
        for x = 1, GRID_WIDTH do
            local entry = self.DungeonGrid.cells[CellKey(x, y)]
            if entry then
                if entry.wall then
                    entry.frame:SetBackdropColor(0.12, 0.095, 0.06, 1)
                    entry.frame:SetBackdropBorderColor(0.20, 0.16, 0.09, 1)
                else
                    entry.frame:SetBackdropColor(0.055, 0.048, 0.038, 1)
                    entry.frame:SetBackdropBorderColor(0.09, 0.075, 0.055, 1)
                end

                entry.marker:SetText("")
                if entry.enemyIcon then
                    entry.enemyIcon:Hide()
                end

                local staticMarker = STATIC_MARKERS[CellKey(x, y)]
                if staticMarker then
                    entry.marker:SetText(staticMarker.text)

                    if staticMarker.color == "red" then
                        entry.marker:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
                    elseif staticMarker.color == "gold" then
                        entry.marker:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
                    elseif staticMarker.color == "green" then
                        entry.marker:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
                    else
                        entry.marker:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
                    end
                end
            end
        end
    end

    local run = self.RunState
    local enemy = run and run.enemy or {
        x = KOBOLD_START_X,
        y = KOBOLD_START_Y,
        texture = KOBOLD_TEXTURE,
    }

    if enemy then
        local enemyCell = self.DungeonGrid.cells[CellKey(enemy.x, enemy.y)]
        if enemyCell and enemyCell.enemyIcon then
            enemyCell.frame:SetBackdropColor(0.16, 0.055, 0.045, 1)
            enemyCell.frame:SetBackdropBorderColor(COLORS.red[1], COLORS.red[2], COLORS.red[3], 1)
            enemyCell.marker:SetText("")
            enemyCell.enemyIcon:SetTexture(enemy.texture or KOBOLD_TEXTURE)
            enemyCell.enemyIcon:Show()
        end
    end

    local playerX = run and run.playerX or START_X
    local playerY = run and run.playerY or START_Y
    local playerCell = self.DungeonGrid.cells[CellKey(playerX, playerY)]

    if playerCell then
        playerCell.frame:SetBackdropColor(0.11, 0.20, 0.08, 1)
        playerCell.frame:SetBackdropBorderColor(COLORS.green[1], COLORS.green[2], COLORS.green[3], 1)
        playerCell.marker:SetText("@")
        playerCell.marker:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
    end
end

function GA:RefreshRunCounters()
    local run = self.RunState

    if self.DungeonFloorValue then
        self.DungeonFloorValue:SetText(string.format("%d / 9", run and run.floor or 1))
    end
    if self.DungeonScoreValue then
        self.DungeonScoreValue:SetText(tostring(run and run.score or 0))
    end
    if self.DungeonTurnsValue then
        self.DungeonTurnsValue:SetText(tostring(run and run.turns or 0))
    end
end

function GA:BeginDungeonRun()
    if self.RunState and self.RunState.active then
        return
    end

    self:RefreshMainHandInfo(true)
    if not self.ArcadeMainHand then
        if self.DungeonRunStateText then
            self.DungeonRunStateText:SetText("EQUIP A MAIN-HAND WEAPON")
            self.DungeonRunStateText:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
        end
        return
    end

    local name = UnitName("player") or "Unknown"
    local level = UnitLevel("player") or 0
    local className = UnitClass("player") or "Adventurer"
    local maxHealth = UnitHealthMax("player") or 0

    self.RunState = {
        active = true,
        completed = false,
        floor = 1,
        score = 0,
        turns = 0,
        playerX = START_X,
        playerY = START_Y,
        enemy = {
            id = "kobold",
            name = "Kobold",
            x = KOBOLD_START_X,
            y = KOBOLD_START_Y,
            texture = KOBOLD_TEXTURE,
        },
        snapshot = {
            name = name,
            level = level,
            className = className,
            maxHealth = maxHealth,
            mainHandLink = self.DungeonMainHandLink,
            weapon = CopyTable(self.ArcadeMainHand),
        },
    }

    self.DungeonHealth:SetText(tostring(maxHealth))
    self.DungeonPower:SetText(string.format("%d-%d", self.RunState.snapshot.weapon.damageMin, self.RunState.snapshot.weapon.damageMax))

    if self.DungeonBeginButton then
        self.DungeonBeginButton:SetEnabled(false)
        self.DungeonBeginButton.label:SetText("RUNNING")
        self.DungeonBeginButton.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    end

    if self.DungeonFloorTitle then
        self.DungeonFloorTitle:SetText("FLOOR 1  -  THE TEST CELLAR")
    end

    if self.DungeonRunStateText then
        self.DungeonRunStateText:SetText("PLAYER TURN - WASD / ARROWS")
        self.DungeonRunStateText:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
    end

    if self.DungeonRunPage and self.DungeonRunPage.SetPropagateKeyboardInput then
        self.DungeonRunPage:SetPropagateKeyboardInput(false)
    end

    self:SetRunMode(true)
    self:SetDungeonRunPortraitMode(true)
    self:ResetCombatLog()
    self:AddCombatLog("Dungeon Run started.", "system")
    self:AddCombatLog(
        string.format("Loadout locked: %s  %d-%d damage.",
            self.RunState.snapshot.weapon.sourceName or "Main hand",
            self.RunState.snapshot.weapon.damageMin,
            self.RunState.snapshot.weapon.damageMax),
        "player"
    )
    self:AddCombatLog("A kobold is hunting you.", "enemy")

    self:RefreshRunCounters()
    self:RenderDungeonGrid()
end

function GA:CompleteTestFloor()
    local run = self.RunState
    if not run or not run.active then
        return
    end

    run.active = false
    run.completed = true

    if self.DungeonFloorTitle then
        self.DungeonFloorTitle:SetText("FLOOR 1  -  CLEARED")
    end

    if self.DungeonRunStateText then
        self.DungeonRunStateText:SetText(string.format("TEST FLOOR CLEARED - %d TURNS", run.turns))
        self.DungeonRunStateText:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
    end

    if self.DungeonBeginButton then
        self.DungeonBeginButton:SetEnabled(true)
        self.DungeonBeginButton.label:SetText("BEGIN AGAIN")
        self.DungeonBeginButton.label:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    end

    self:AddCombatLog(string.format("Test floor cleared in %d turns.", run.turns), "system")

    if self.DungeonRunPage and self.DungeonRunPage.SetPropagateKeyboardInput then
        self.DungeonRunPage:SetPropagateKeyboardInput(true)
    end

    self:SetDungeonRunPortraitMode(false)
    self:SetRunMode(false)
    self:RefreshMainHandInfo(true)
    self:RefreshRunCounters()
    self:RenderDungeonGrid()
end

function GA:RunEnemyTurn()
    local run = self.RunState
    if not run or not run.active or not run.enemy then
        return
    end

    local enemy = run.enemy

    if IsAdjacent(enemy.x, enemy.y, run.playerX, run.playerY) then
        if self.DungeonRunStateText then
            self.DungeonRunStateText:SetText("PLAYER TURN - KOBOLD ADJACENT")
            self.DungeonRunStateText:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
        end
        self:AddCombatLog("The kobold is already in striking distance.", "enemy")
        return
    end

    if self.DungeonRunStateText then
        self.DungeonRunStateText:SetText("ENEMY TURN - KOBOLD")
        self.DungeonRunStateText:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    end

    local nextX, nextY = FindNextStep(enemy.x, enemy.y, run.playerX, run.playerY)

    -- Combat is not implemented yet, so the kobold stops next to the player
    -- instead of entering the player's square.
    if nextX and nextY and not (nextX == run.playerX and nextY == run.playerY) then
        enemy.x = nextX
        enemy.y = nextY
        self:AddCombatLog("Kobold moves closer.", "enemy")
    end

    self:RenderDungeonGrid()

    if self.DungeonRunStateText then
        if IsAdjacent(enemy.x, enemy.y, run.playerX, run.playerY) then
            self.DungeonRunStateText:SetText("PLAYER TURN - KOBOLD ADJACENT")
            self.DungeonRunStateText:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
        else
            self.DungeonRunStateText:SetText("PLAYER TURN - KOBOLD MOVED")
            self.DungeonRunStateText:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
        end
    end
end

function GA:MoveDungeonPlayer(dx, dy)
    local run = self.RunState
    if not run or not run.active then
        return
    end

    local nextX = run.playerX + dx
    local nextY = run.playerY + dy

    if IsDungeonWall(nextX, nextY) then
        if self.DungeonRunStateText then
            self.DungeonRunStateText:SetText("BLOCKED - WALL")
            self.DungeonRunStateText:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
        end
        self:AddCombatLog("A wall blocks your path.", "warning")
        return
    end

    if run.enemy and nextX == run.enemy.x and nextY == run.enemy.y then
        if self.DungeonRunStateText then
            self.DungeonRunStateText:SetText("KOBOLD BLOCKS THE WAY - COMBAT NEXT")
            self.DungeonRunStateText:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
        end
        self:AddCombatLog("You square up with the kobold. Combat is the next milestone.", "warning")
        return
    end

    run.playerX = nextX
    run.playerY = nextY
    run.turns = run.turns + 1

    local direction = "move"
    if dx == 1 then
        direction = "east"
    elseif dx == -1 then
        direction = "west"
    elseif dy == 1 then
        direction = "south"
    elseif dy == -1 then
        direction = "north"
    end
    self:AddCombatLog("You move " .. direction .. ".", "player")

    self:RefreshRunCounters()
    self:RenderDungeonGrid()

    if nextX == EXIT_X and nextY == EXIT_Y then
        self:CompleteTestFloor()
        return
    end

    self:RunEnemyTurn()
end

function GA:RefreshDungeonSummary()
    if not self.DungeonHealth then
        return
    end

    if self.RunState and self.RunState.active and self.RunState.snapshot then
        self:SetRunMode(true)
        self:SetDungeonRunPortraitMode(true)

        if self.DungeonRunPage and self.DungeonRunPage.SetPropagateKeyboardInput then
            self.DungeonRunPage:SetPropagateKeyboardInput(false)
        end

        self.DungeonHealth:SetText(tostring(self.RunState.snapshot.maxHealth or 0))

        local weapon = self.RunState.snapshot.weapon
        if weapon then
            self.DungeonPower:SetText(string.format("%d-%d", weapon.damageMin, weapon.damageMax))
        end

        self:RefreshRunCounters()
        self:RenderDungeonGrid()
        return
    end

    self:SetRunMode(false)
    self:SetDungeonRunPortraitMode(false)

    if self.DungeonRunPage and self.DungeonRunPage.SetPropagateKeyboardInput then
        self.DungeonRunPage:SetPropagateKeyboardInput(true)
    end

    local maxHealth = UnitHealthMax("player") or 0
    self.DungeonHealth:SetText(tostring(maxHealth))
    self:RefreshMainHandInfo()
    self:RefreshRunCounters()
    self:RenderDungeonGrid()
end

local itemEventFrame = CreateFrame("Frame")
itemEventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
itemEventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

itemEventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_EQUIPMENT_CHANGED" and arg1 ~= 16 then
        return
    end

    if GA.RefreshMainHandInfo then
        GA:RefreshMainHandInfo()
    end
end)
