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

    return value, label
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

local GRID_WIDTH = 25
local GRID_HEIGHT = 25
local VIEWPORT_WIDTH = 13
local VIEWPORT_HEIGHT = 13
local START_X = 7
local START_Y = 7
local EXIT_X = 23
local EXIT_Y = 23
local VISION_RADIUS = 4
local ENEMY_VISION_RADIUS = 6
local KOBOLD_MAX_HP = 36
local KOBOLD_DAMAGE_MIN = 4
local KOBOLD_DAMAGE_MAX = 7

local STATIC_WALLS = {
    ["4:3"] = true, ["4:4"] = true, ["4:5"] = true,
    ["9:2"] = true, ["9:3"] = true,
    ["3:9"] = true, ["4:9"] = true, ["5:9"] = true,
    ["10:8"] = true, ["10:9"] = true, ["10:10"] = true,

    ["14:5"] = true, ["14:6"] = true, ["14:7"] = true, ["14:8"] = true,
    ["15:12"] = true, ["16:12"] = true, ["17:12"] = true, ["18:12"] = true,
    ["7:15"] = true, ["8:15"] = true, ["9:15"] = true, ["10:15"] = true,
    ["19:16"] = true, ["19:17"] = true, ["19:18"] = true, ["19:19"] = true,
    ["12:20"] = true, ["13:20"] = true, ["14:20"] = true,
    ["21:9"] = true, ["22:9"] = true,
}

local STATIC_MARKERS = {
    ["3:6"] = { text = "S", color = "muted" },
    ["9:11"] = { text = "$", color = "gold" },
    ["17:15"] = { text = "$", color = "gold" },
    ["21:20"] = { text = "S", color = "muted" },
    ["23:23"] = { text = ">", color = "green" },
}

local KOBOLD_START_X = 11
local KOBOLD_START_Y = 4
local KOBOLD_TEXTURE = "Interface\\AddOns\\GoblinArcade\\Media\\Monsters\\kobold"
local KOBOLD_PORTRAIT_ICON = "Interface\\Icons\\inv_misc_candlekobold_color1"

local CHEST_LOOT = {
    ["9:11"] = {
        name = "Candlekeeper's Charm",
        icon = KOBOLD_PORTRAIT_ICON,
        itemLevel = 18,
        quality = 2,
        itemType = "Armor",
        itemSubType = "Miscellaneous",
        equipLoc = "INVTYPE_TRINKET",
        compatibleSlots = { trinket1 = true, trinket2 = true },
        slotLabel = "Trinket",
        description = "Warm wax hums faintly in your palm. Prototype dungeon loot.",
        source = "dungeon",
    },
    ["17:15"] = {
        name = "Waxbound Ring",
        icon = "Interface\\Icons\\INV_Jewelry_Ring_03",
        itemLevel = 18,
        quality = 2,
        itemType = "Armor",
        itemSubType = "Miscellaneous",
        equipLoc = "INVTYPE_FINGER",
        compatibleSlots = { finger1 = true, finger2 = true },
        slotLabel = "Finger",
        description = "A crude ring sealed with kobold wax. Prototype dungeon loot.",
        source = "dungeon",
    },
}

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

local function HasLineOfSight(fromX, fromY, toX, toY)
    if fromX == toX and fromY == toY then
        return true
    end

    local x = fromX
    local y = fromY
    local dx = math.abs(toX - fromX)
    local dy = math.abs(toY - fromY)
    local stepX = fromX < toX and 1 or -1
    local stepY = fromY < toY and 1 or -1
    local errorValue = dx - dy

    while not (x == toX and y == toY) do
        local doubledError = errorValue * 2

        if doubledError > -dy then
            errorValue = errorValue - dy
            x = x + stepX
        end

        if doubledError < dx then
            errorValue = errorValue + dx
            y = y + stepY
        end

        -- A wall tile itself is visible, but it blocks everything behind it.
        if x == toX and y == toY then
            return true
        end

        if IsDungeonWall(x, y) then
            return false
        end
    end

    return true
end

local function IsWithinRadius(fromX, fromY, toX, toY, radius)
    local dx = toX - fromX
    local dy = toY - fromY
    return (dx * dx) + (dy * dy) <= (radius * radius)
end

local function IsWithinVisionRadius(fromX, fromY, toX, toY)
    return IsWithinRadius(fromX, fromY, toX, toY, VISION_RADIUS)
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

local function SetCharacterVisual(texture, character)
    if not texture then
        return
    end

    local currentKey = GA.GetCurrentCharacterKey and GA:GetCurrentCharacterKey()
    if character and character.key == currentKey then
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        SetPortraitTexture(texture, "player")
        return
    end

    local coords = character and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[character.classFile]
    if coords then
        texture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        texture:SetTexCoord(0, 1, 0, 1)
    end
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

    for row = 1, VIEWPORT_HEIGHT do
        for col = 1, VIEWPORT_WIDTH do
            local cell = CreateFrame("Frame", nil, grid, "BackdropTemplate")
            cell:SetSize(size, size)
            cell:SetPoint("TOPLEFT", (col - 1) * stride, -((row - 1) * stride))

            ApplyBackdrop(cell, { 0.055, 0.048, 0.038, 1 }, { 0.09, 0.075, 0.055, 1 })

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
                worldX = col,
                worldY = row,
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

    local subtitle = CreateText(page, "GameFontHighlightSmall", "TURN-BASED ROGUELIKE  -  INVENTORY + COMBAT UI")
    subtitle:SetPoint("TOPRIGHT", -18, -22)
    subtitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local body = CreateFrame("Frame", nil, page)
    body:SetPoint("TOPLEFT", 18, -58)
    body:SetPoint("BOTTOMRIGHT", -18, 100)

    local left = CreateFrame("Frame", nil, body, "BackdropTemplate")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(182)
    ApplyBackdrop(left, { 0.050, 0.043, 0.034, 1 }, COLORS.goldDim)

    local statsTitle = CreateText(left, "GameFontNormalSmall", "RUN STATS")
    statsTitle:SetPoint("TOPLEFT", 12, -14)
    statsTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.DungeonStatsTitle = statsTitle

    self.DungeonHealth, self.DungeonHealthLabel = CreateStatRow(left, "HEALTH", "--", -38)
    self.DungeonPower, self.DungeonPowerLabel = CreateStatRow(left, "WEAPON", "--", -62)
    self.DungeonDodge, self.DungeonDodgeLabel = CreateStatRow(left, "DODGE", "--", -86)

    local gearTitle = CreateText(left, "GameFontNormalSmall", "WOW GEAR INPUT")
    gearTitle:SetPoint("TOPLEFT", 12, -126)
    gearTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local runPortraitFrame = CreateFrame("Frame", nil, left, "BackdropTemplate")
    runPortraitFrame:SetSize(158, 92)
    runPortraitFrame:SetPoint("TOPLEFT", 12, -14)
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

    self.DungeonRelicWidgets = { relicTitle }

    for i = 1, 6 do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local relicSlot = CreateRelicSlot(right, i, 12 + col * 58, -38 - row * 58)
        self.DungeonRelicWidgets[#self.DungeonRelicWidgets + 1] = relicSlot
    end

    local enemyCard = CreateFrame("Frame", nil, right, "BackdropTemplate")
    enemyCard:SetPoint("TOPLEFT", 10, -10)
    enemyCard:SetSize(118, 202)
    ApplyBackdrop(enemyCard, { 0.080, 0.035, 0.030, 1 }, COLORS.red)
    enemyCard:Hide()
    self.DungeonEnemyCard = enemyCard

    local enemyTitle = CreateText(enemyCard, "GameFontNormalSmall", "COMBAT TARGET")
    enemyTitle:SetPoint("TOP", 0, -10)
    enemyTitle:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])

    local enemyIconBorder = CreateFrame("Frame", nil, enemyCard, "BackdropTemplate")
    enemyIconBorder:SetSize(76, 76)
    enemyIconBorder:SetPoint("TOP", 0, -34)
    ApplyBackdrop(enemyIconBorder, { 0.02, 0.02, 0.02, 1 }, COLORS.red)

    local enemyPortrait = enemyIconBorder:CreateTexture(nil, "ARTWORK")
    enemyPortrait:SetPoint("TOPLEFT", 3, -3)
    enemyPortrait:SetPoint("BOTTOMRIGHT", -3, 3)
    enemyPortrait:SetTexture(KOBOLD_PORTRAIT_ICON)
    self.DungeonEnemyPortrait = enemyPortrait

    local enemyName = CreateText(enemyCard, "GameFontNormal", "Kobold")
    enemyName:SetPoint("TOP", enemyIconBorder, "BOTTOM", 0, -8)
    enemyName:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    self.DungeonEnemyName = enemyName

    local enemyHealth = CreateText(enemyCard, "GameFontHighlightSmall", "")
    enemyHealth:SetPoint("TOP", enemyName, "BOTTOM", 0, -7)
    enemyHealth:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
    self.DungeonEnemyHealth = enemyHealth

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

    local floor = CreateText(center, "GameFontNormalSmall", "FLOOR 1  -  THE TEST CELLAR  -  25x25")
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
    actionBar:SetHeight(72)
    ApplyBackdrop(actionBar, { 0.050, 0.043, 0.034, 1 }, COLORS.goldDim)

    local actionLabel = CreateText(actionBar, "GameFontNormalSmall", "ACTIONS")
    actionLabel:SetPoint("BOTTOMLEFT", 12, 14)
    actionLabel:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local actions = {
        { "1", "ATTACK" },
        { "2", "ABILITY" },
        { "3", "ABILITY" },
        { "4", "POTION" },
    }

    self.DungeonActionButtons = {}

    for i, action in ipairs(actions) do
        local button = CreateFlatButton(actionBar, action[1] .. "  " .. action[2], 116, 32)
        button:SetPoint("BOTTOMLEFT", 88 + (i - 1) * 124, 8)
        button:SetEnabled(false)
        button.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        self.DungeonActionButtons[i] = button

        if i == 1 then
            self.DungeonAttackButton = button
            button:SetScript("OnClick", function()
                GA:PlayerAttackEnemy()
            end)
        end
    end

    local state = CreateText(actionBar, "GameFontDisableSmall", "READY - BEGIN A RUN")
    state:SetPoint("TOPLEFT", 12, -8)
    state:SetPoint("TOPRIGHT", -12, -8)
    state:SetJustifyH("RIGHT")
    state:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonRunStateText = state

    local setup = CreateFrame("Frame", nil, page, "BackdropTemplate")
    setup:SetPoint("TOPLEFT", 1, -1)
    setup:SetPoint("BOTTOMRIGHT", -1, 1)
    setup:SetFrameLevel(page:GetFrameLevel() + 20)
    ApplyBackdrop(setup, { 0.040, 0.034, 0.027, 1 }, COLORS.goldDim)
    self.DungeonSetupFrame = setup

    local setupTitle = CreateText(setup, "GameFontNormalHuge", "DUNGEON RUN")
    setupTitle:SetPoint("TOPLEFT", 26, -22)
    setupTitle:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

    local setupSubtitle = CreateText(setup, "GameFontNormal", "CHOOSE A HERO")
    setupSubtitle:SetPoint("TOPLEFT", setupTitle, "BOTTOMLEFT", 0, -10)
    setupSubtitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local setupHint = CreateText(setup, "GameFontHighlightSmall",
        "Characters are remembered after you log into them once. Offline alts use their last synced GoblinArcade loadout.")
    setupHint:SetPoint("TOPLEFT", setupSubtitle, "BOTTOMLEFT", 0, -8)
    setupHint:SetWidth(670)
    setupHint:SetJustifyH("LEFT")
    setupHint:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local rosterPanel = CreateFrame("Frame", nil, setup, "BackdropTemplate")
    rosterPanel:SetPoint("TOPLEFT", 26, -112)
    rosterPanel:SetSize(330, 392)
    ApplyBackdrop(rosterPanel, { 0.050, 0.043, 0.034, 1 }, COLORS.goldDim)
    rosterPanel:EnableMouseWheel(true)
    self.DungeonRosterPanel = rosterPanel

    local rosterTitle = CreateText(rosterPanel, "GameFontNormalSmall", "CHARACTERS")
    rosterTitle:SetPoint("TOPLEFT", 12, -12)
    rosterTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    self.DungeonCharacterRows = {}
    for i = 1, 6 do
        local row = CreateFrame("Button", nil, rosterPanel, "BackdropTemplate")
        row:SetSize(304, 50)
        row:SetPoint("TOPLEFT", 12, -38 - ((i - 1) * 56))
        ApplyBackdrop(row, { 0.060, 0.052, 0.042, 1 }, COLORS.goldDim)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(36, 36)
        icon:SetPoint("LEFT", 7, 0)

        local nameText = CreateText(row, "GameFontNormal", "")
        nameText:SetPoint("TOPLEFT", 52, -8)
        nameText:SetPoint("RIGHT", -8, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

        local metaText = CreateText(row, "GameFontHighlightSmall", "")
        metaText:SetPoint("BOTTOMLEFT", 52, 8)
        metaText:SetPoint("RIGHT", -8, 0)
        metaText:SetJustifyH("LEFT")
        metaText:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

        row.icon = icon
        row.nameText = nameText
        row.metaText = metaText
        row:SetScript("OnClick", function(button)
            if button.characterKey then
                GA:SelectDungeonCharacter(button.characterKey)
            end
        end)
        self.DungeonCharacterRows[i] = row
    end

    rosterPanel:SetScript("OnMouseWheel", function(_, delta)
        local roster = GA:GetCharacterRoster()
        local maxOffset = math.max(0, #roster - #GA.DungeonCharacterRows)
        GA.DungeonRosterOffset = math.max(0, math.min(maxOffset, (GA.DungeonRosterOffset or 0) - delta))
        GA:RefreshDungeonCharacterSelection()
    end)

    local selectedPanel = CreateFrame("Frame", nil, setup, "BackdropTemplate")
    selectedPanel:SetPoint("TOPLEFT", rosterPanel, "TOPRIGHT", 14, 0)
    selectedPanel:SetSize(330, 392)
    ApplyBackdrop(selectedPanel, { 0.050, 0.043, 0.034, 1 }, COLORS.goldDim)

    local selectedTitle = CreateText(selectedPanel, "GameFontNormalSmall", "SELECTED HERO")
    selectedTitle:SetPoint("TOPLEFT", 16, -14)
    selectedTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local selectedIconBorder = CreateFrame("Frame", nil, selectedPanel, "BackdropTemplate")
    selectedIconBorder:SetSize(82, 82)
    selectedIconBorder:SetPoint("TOPLEFT", 16, -42)
    ApplyBackdrop(selectedIconBorder, { 0.02, 0.02, 0.02, 1 }, COLORS.gold)

    local selectedIcon = selectedIconBorder:CreateTexture(nil, "ARTWORK")
    selectedIcon:SetPoint("TOPLEFT", 3, -3)
    selectedIcon:SetPoint("BOTTOMRIGHT", -3, 3)
    self.DungeonSelectedCharacterIcon = selectedIcon

    local selectedName = CreateText(selectedPanel, "GameFontNormalLarge", "")
    selectedName:SetPoint("TOPLEFT", selectedIconBorder, "TOPRIGHT", 14, -7)
    selectedName:SetPoint("RIGHT", -16, 0)
    selectedName:SetJustifyH("LEFT")
    selectedName:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    self.DungeonSelectedCharacterName = selectedName

    local selectedMeta = CreateText(selectedPanel, "GameFontHighlightSmall", "")
    selectedMeta:SetPoint("TOPLEFT", selectedName, "BOTTOMLEFT", 0, -7)
    selectedMeta:SetPoint("RIGHT", -16, 0)
    selectedMeta:SetJustifyH("LEFT")
    selectedMeta:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonSelectedCharacterMeta = selectedMeta

    local selectedSource = CreateText(selectedPanel, "GameFontDisableSmall", "")
    selectedSource:SetPoint("TOPLEFT", selectedMeta, "BOTTOMLEFT", 0, -8)
    selectedSource:SetPoint("RIGHT", -16, 0)
    selectedSource:SetJustifyH("LEFT")
    selectedSource:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.DungeonSelectedCharacterSource = selectedSource

    local loadoutTitle = CreateText(selectedPanel, "GameFontNormalSmall", "CACHED LOADOUT")
    loadoutTitle:SetPoint("TOPLEFT", 16, -146)
    loadoutTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local loadoutWeapon = CreateText(selectedPanel, "GameFontNormal", "")
    loadoutWeapon:SetPoint("TOPLEFT", 16, -174)
    loadoutWeapon:SetPoint("RIGHT", -16, 0)
    loadoutWeapon:SetJustifyH("LEFT")
    loadoutWeapon:SetWordWrap(true)
    loadoutWeapon:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    self.DungeonSelectedWeaponName = loadoutWeapon

    local loadoutStats = CreateText(selectedPanel, "GameFontHighlightSmall", "")
    loadoutStats:SetPoint("TOPLEFT", loadoutWeapon, "BOTTOMLEFT", 0, -8)
    loadoutStats:SetPoint("RIGHT", -16, 0)
    loadoutStats:SetJustifyH("LEFT")
    loadoutStats:SetWordWrap(true)
    loadoutStats:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonSelectedWeaponStats = loadoutStats

    local loadoutTrait = CreateText(selectedPanel, "GameFontNormalSmall", "")
    loadoutTrait:SetPoint("TOPLEFT", loadoutStats, "BOTTOMLEFT", 0, -14)
    loadoutTrait:SetPoint("RIGHT", -16, 0)
    loadoutTrait:SetJustifyH("LEFT")
    loadoutTrait:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.DungeonSelectedWeaponTrait = loadoutTrait

    local selectedNote = CreateText(selectedPanel, "GameFontDisableSmall",
        "To refresh an alt's gear, log into that character once and open GoblinArcade.")
    selectedNote:SetPoint("BOTTOMLEFT", 16, 76)
    selectedNote:SetPoint("RIGHT", -16, 0)
    selectedNote:SetJustifyH("LEFT")
    selectedNote:SetWordWrap(true)
    selectedNote:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local setupBegin = CreateFlatButton(selectedPanel, "BEGIN RUN", 180, 42)
    setupBegin:SetPoint("BOTTOMRIGHT", -16, 16)
    setupBegin:SetEnabled(false)
    setupBegin.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    setupBegin:SetScript("OnClick", function()
        GA:BeginDungeonRun()
    end)
    self.DungeonSetupBeginButton = setupBegin

    if self.CreateCharacterSheet then
        self:CreateCharacterSheet(page)
    end

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

        if key == "C" then
            GA:ToggleCharacterSheet()
            return
        end

        if GA.CharacterSheetFrame and GA.CharacterSheetFrame:IsShown() then
            if key == "ESCAPE" then
                GA.CharacterSheetFrame:Hide()
                GA:CancelCharacterItemDrag()
            end
            return
        end

        if key == "ESCAPE" then
            if GA.MainFrame then
                GA.MainFrame:Hide()
            end
            return
        end

        if key == "1" then
            GA:PlayerAttackEnemy()
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
    self:SetDungeonSetupMode(true)
    return page
end

function GA:SetDungeonSetupMode(active)
    if not self.DungeonSetupFrame then
        return
    end

    if active then
        self.DungeonSetupFrame:Show()
        self:SetRunMode(false)
        self:RefreshDungeonCharacterSelection()
    else
        self.DungeonSetupFrame:Hide()
    end
end

function GA:RefreshDungeonCharacterSelection()
    if not self.DungeonSetupFrame or not self.GetCharacterRoster then
        return
    end

    local roster = self:GetCharacterRoster()
    local currentKey = self:GetCurrentCharacterKey()
    local selected = self:GetSelectedDungeonCharacter()

    if not selected and #roster > 0 then
        self:SelectDungeonCharacter(roster[1].key)
        return
    end

    local offset = self.DungeonRosterOffset or 0
    local maxOffset = math.max(0, #roster - #self.DungeonCharacterRows)
    if offset > maxOffset then
        offset = maxOffset
        self.DungeonRosterOffset = offset
    end

    for i, row in ipairs(self.DungeonCharacterRows or {}) do
        local character = roster[offset + i]
        if character then
            row.characterKey = character.key
            row:Show()
            SetCharacterVisual(row.icon, character)
            row.nameText:SetText(character.name or "Unknown")
            row.metaText:SetText(string.format(
                "Level %d %s %s%s",
                character.level or 0,
                character.raceName or "",
                character.className or "Adventurer",
                character.key == currentKey and "  -  CURRENT" or ""
            ))

            if selected and character.key == selected.key then
                row:SetBackdropColor(0.15, 0.105, 0.045, 1)
                row:SetBackdropBorderColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1)
            else
                row:SetBackdropColor(0.060, 0.052, 0.042, 1)
                row:SetBackdropBorderColor(COLORS.goldDim[1], COLORS.goldDim[2], COLORS.goldDim[3], 1)
            end
        else
            row.characterKey = nil
            row:Hide()
        end
    end

    if not selected then
        return
    end

    SetCharacterVisual(self.DungeonSelectedCharacterIcon, selected)
    self.DungeonSelectedCharacterName:SetText(selected.name or "Unknown")
    self.DungeonSelectedCharacterMeta:SetText(string.format(
        "Level %d %s %s  -  %s",
        selected.level or 0,
        selected.raceName or "",
        selected.className or "Adventurer",
        selected.realm or "Unknown Realm"
    ))
    self.DungeonSelectedCharacterSource:SetText(
        selected.key == currentKey and "CURRENT CHARACTER - LIVE DATA" or "ALT - LAST SYNCED DATA"
    )

    local weapon = selected.weapon
    if weapon then
        self.DungeonSelectedWeaponName:SetText(selected.weaponName or weapon.sourceName or "Cached main hand")
        self.DungeonSelectedWeaponStats:SetText(string.format(
            "%s  -  Damage %d-%d  -  %s  -  Range %d",
            weapon.style or "Weapon",
            weapon.damageMin or 0,
            weapon.damageMax or 0,
            weapon.speed or "NORMAL",
            weapon.range or 1
        ))
        if weapon.traitName then
            self.DungeonSelectedWeaponTrait:SetText(weapon.traitName .. "  -  " .. (weapon.traitDescription or ""))
        else
            self.DungeonSelectedWeaponTrait:SetText("NO SIGNATURE TRAIT")
        end

        self.DungeonSetupBeginButton:SetEnabled(true)
        self.DungeonSetupBeginButton.label:SetText("BEGIN RUN")
        self.DungeonSetupBeginButton.label:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    else
        self.DungeonSelectedWeaponName:SetText("No cached main-hand weapon")
        self.DungeonSelectedWeaponStats:SetText("Log into this character and equip a weapon to sync it.")
        self.DungeonSelectedWeaponTrait:SetText("")
        self.DungeonSetupBeginButton:SetEnabled(false)
        self.DungeonSetupBeginButton.label:SetText("NO LOADOUT")
        self.DungeonSetupBeginButton.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    end
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

    local function PositionStatRow(label, value, y)
        if label then
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", 12, y)
        end
        if value then
            value:ClearAllPoints()
            value:SetPoint("TOPRIGHT", -12, y)
        end
    end

    if active then
        if self.DungeonStatsTitle then
            self.DungeonStatsTitle:ClearAllPoints()
            self.DungeonStatsTitle:SetPoint("TOPLEFT", 12, -120)
        end
        PositionStatRow(self.DungeonHealthLabel, self.DungeonHealth, -144)
        PositionStatRow(self.DungeonPowerLabel, self.DungeonPower, -168)
        PositionStatRow(self.DungeonDodgeLabel, self.DungeonDodge, -192)
    else
        if self.DungeonStatsTitle then
            self.DungeonStatsTitle:ClearAllPoints()
            self.DungeonStatsTitle:SetPoint("TOPLEFT", 12, -14)
        end
        PositionStatRow(self.DungeonHealthLabel, self.DungeonHealth, -38)
        PositionStatRow(self.DungeonPowerLabel, self.DungeonPower, -62)
        PositionStatRow(self.DungeonDodgeLabel, self.DungeonDodge, -86)
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
                SetCharacterVisual(self.DungeonRunPortrait, {
                    key = snapshot and snapshot.characterKey,
                    classFile = snapshot and snapshot.classFile,
                })
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

        if self.SyncCurrentCharacterRoster then
            self:SyncCurrentCharacterRoster(nil, { clearWeapon = true })
        end

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

            if self.SyncCurrentCharacterRoster then
                self:SyncCurrentCharacterRoster(weapon, {
                    weaponName = name,
                    weaponIcon = texture,
                    weaponLink = itemLink,
                    weaponItemLevel = itemLevel,
                    weaponQuality = quality,
                    weaponSubtype = itemSubType or itemType,
                })
            end

            if self.DungeonBeginButton and not (self.RunState and self.RunState.active) then
                self.DungeonBeginButton:SetEnabled(true)
                self.DungeonBeginButton.label:SetText(self.RunState and self.RunState.completed and "BEGIN AGAIN" or "BEGIN RUN")
                self.DungeonBeginButton.label:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
            end
        end
    end
end

function GA:RefreshEnemyCombatCard()
    local run = self.RunState
    local enemy = run and run.enemy
    local inCombat = run
        and run.active
        and enemy
        and enemy.alive ~= false
        and IsAdjacent(run.playerX, run.playerY, enemy.x, enemy.y)

    if self.DungeonEnemyCard then
        if inCombat then
            self.DungeonEnemyCard:Show()
            self.DungeonEnemyName:SetText(enemy.name or "Kobold")
            self.DungeonEnemyHealth:SetText(
                string.format("%d / %d HP", enemy.hp or 0, enemy.maxHp or 0)
            )
        else
            self.DungeonEnemyCard:Hide()
        end
    end

    for _, widget in ipairs(self.DungeonRelicWidgets or {}) do
        if inCombat then
            widget:Hide()
        else
            widget:Show()
        end
    end
end

function GA:RefreshActionButtons()
    local run = self.RunState
    local enemy = run and run.enemy
    local canAttack = run
        and run.active
        and enemy
        and enemy.alive ~= false
        and IsAdjacent(run.playerX, run.playerY, enemy.x, enemy.y)

    if self.DungeonAttackButton then
        self.DungeonAttackButton:SetEnabled(canAttack and true or false)

        if canAttack then
            self.DungeonAttackButton.label:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
        else
            self.DungeonAttackButton.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        end
    end
end

function GA:UpdateRunHealth()
    local run = self.RunState
    if not run or not self.DungeonHealth then
        return
    end

    self.DungeonHealth:SetText(
        string.format("%d / %d", math.max(0, run.playerHealth or 0), run.playerMaxHealth or 0)
    )
end

function GA:FailDungeonRun(reason)
    local run = self.RunState
    if not run then
        return
    end

    run.active = false
    run.failed = true

    self:AddCombatLog(reason or "The run is over.", "warning")

    if self.DungeonRunStateText then
        self.DungeonRunStateText:SetText("RUN ENDED")
        self.DungeonRunStateText:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
    end

    if self.DungeonRunPage and self.DungeonRunPage.SetPropagateKeyboardInput then
        self.DungeonRunPage:SetPropagateKeyboardInput(true)
    end

    if self.CharacterSheetFrame then
        self.CharacterSheetFrame:Hide()
    end
    self:CancelCharacterItemDrag()
    self:RefreshActionButtons()
    self:SetDungeonRunPortraitMode(false)
    self:SetRunMode(false)
    self:RefreshMainHandInfo(true)
    self:SetDungeonSetupMode(true)
end

function GA:PlayerAttackEnemy()
    local run = self.RunState
    if not run or not run.active or not run.enemy or run.enemy.alive == false then
        return false
    end

    local enemy = run.enemy
    if not IsAdjacent(run.playerX, run.playerY, enemy.x, enemy.y) then
        if self.DungeonRunStateText then
            self.DungeonRunStateText:SetText("NO TARGET IN MELEE RANGE")
            self.DungeonRunStateText:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
        end
        return false
    end

    local weapon = self:GetCurrentRunWeapon()
    local minimum = weapon and math.max(1, tonumber(weapon.damageMin) or 1) or 1
    local maximum = weapon and math.max(minimum, tonumber(weapon.damageMax) or minimum) or 2
    local damage = math.random(minimum, maximum)
    local critChance = run.arcadeStats and run.arcadeStats.crit or 0
    local critical = critChance > 0
        and math.random(1, 1000) <= math.floor(critChance * 10)

    if critical then
        damage = math.max(1, math.floor(damage * 1.5 + 0.5))
    end

    enemy.hp = math.max(0, (enemy.hp or enemy.maxHp or 1) - damage)
    run.turns = run.turns + 1

    self:AddCombatLog(
        string.format("%sYou hit the %s for %d damage. (%d/%d HP)",
            critical and "CRITICAL! " or "",
            enemy.name or "enemy",
            damage,
            enemy.hp,
            enemy.maxHp or enemy.hp),
        "player"
    )

    local staggered = false
    if enemy.hp > 0 and weapon and weapon.traitName == "STAGGER" then
        local staggerChance = tonumber(weapon.traitValue) or 0
        if staggerChance > 0 and math.random(1, 100) <= staggerChance then
            enemy.skipTurn = true
            staggered = true
            self:AddCombatLog(
                string.format("STAGGER! The %s loses its next action.", enemy.name or "enemy"),
                "system"
            )
        end
    end

    if enemy.hp <= 0 then
        enemy.alive = false
        run.score = (run.score or 0) + 100
        self:AddCombatLog("Kobold defeated. +100 score.", "system")

        if self.DungeonRunStateText then
            self.DungeonRunStateText:SetText("PLAYER TURN - KOBOLD DEFEATED")
            self.DungeonRunStateText:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
        end

        self:RefreshRunCounters()
        self:RenderDungeonGrid()
        self:RefreshActionButtons()
        return true
    end

    self:RefreshRunCounters()
    self:RenderDungeonGrid()
    self:RefreshActionButtons()
    self:RunEnemyTurn()
    return true
end

function GA:UpdateDungeonVisibility()
    local run = self.RunState
    if not run or not run.active then
        return
    end

    run.explored = run.explored or {}
    run.visible = {}

    local minX = math.max(1, run.playerX - VISION_RADIUS)
    local maxX = math.min(GRID_WIDTH, run.playerX + VISION_RADIUS)
    local minY = math.max(1, run.playerY - VISION_RADIUS)
    local maxY = math.min(GRID_HEIGHT, run.playerY + VISION_RADIUS)

    for worldY = minY, maxY do
        for worldX = minX, maxX do
            if IsWithinVisionRadius(run.playerX, run.playerY, worldX, worldY)
                and HasLineOfSight(run.playerX, run.playerY, worldX, worldY) then

                local key = CellKey(worldX, worldY)
                run.visible[key] = true
                run.explored[key] = true
            end
        end
    end

    run.visible[CellKey(run.playerX, run.playerY)] = true
    run.explored[CellKey(run.playerX, run.playerY)] = true
end

function GA:IsDungeonCellVisible(worldX, worldY)
    local run = self.RunState
    if not run or not run.active then
        return true
    end

    return run.visible and run.visible[CellKey(worldX, worldY)] == true
end

function GA:IsDungeonCellExplored(worldX, worldY)
    local run = self.RunState
    if not run or not run.active then
        return true
    end

    return run.explored and run.explored[CellKey(worldX, worldY)] == true
end

local function Clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

function GA:UpdateDungeonCamera()
    local run = self.RunState
    local focusX = run and run.playerX or START_X
    local focusY = run and run.playerY or START_Y

    local halfW = math.floor(VIEWPORT_WIDTH / 2)
    local halfH = math.floor(VIEWPORT_HEIGHT / 2)
    local maxCameraX = GRID_WIDTH - VIEWPORT_WIDTH + 1
    local maxCameraY = GRID_HEIGHT - VIEWPORT_HEIGHT + 1

    self.DungeonCameraX = Clamp(focusX - halfW, 1, maxCameraX)
    self.DungeonCameraY = Clamp(focusY - halfH, 1, maxCameraY)
end

function GA:RenderDungeonGrid()
    if not self.DungeonGrid or not self.DungeonGrid.cells then
        return
    end

    local run = self.RunState
    if run and run.active then
        self:UpdateDungeonVisibility()
    end

    self:UpdateDungeonCamera()

    local cameraX = self.DungeonCameraX or 1
    local cameraY = self.DungeonCameraY or 1

    for viewY = 1, VIEWPORT_HEIGHT do
        for viewX = 1, VIEWPORT_WIDTH do
            local entry = self.DungeonGrid.cells[CellKey(viewX, viewY)]
            if entry then
                local worldX = cameraX + viewX - 1
                local worldY = cameraY + viewY - 1
                local wall = IsDungeonWall(worldX, worldY)
                local visible = self:IsDungeonCellVisible(worldX, worldY)
                local explored = self:IsDungeonCellExplored(worldX, worldY)

                entry.worldX = worldX
                entry.worldY = worldY
                entry.wall = wall

                entry.marker:SetText("")
                if entry.enemyIcon then
                    entry.enemyIcon:Hide()
                end

                if not explored then
                    -- Unseen: almost completely black. The player has no map
                    -- knowledge of either walls or floor here yet.
                    entry.frame:SetBackdropColor(0.008, 0.007, 0.006, 1)
                    entry.frame:SetBackdropBorderColor(0.015, 0.013, 0.010, 1)
                elseif not visible then
                    -- Explored memory: preserve terrain shape, but strongly dim it.
                    if wall then
                        entry.frame:SetBackdropColor(0.045, 0.038, 0.028, 1)
                        entry.frame:SetBackdropBorderColor(0.070, 0.058, 0.040, 1)
                    else
                        entry.frame:SetBackdropColor(0.020, 0.018, 0.015, 1)
                        entry.frame:SetBackdropBorderColor(0.038, 0.032, 0.025, 1)
                    end
                else
                    -- Currently visible.
                    if wall then
                        entry.frame:SetBackdropColor(0.12, 0.095, 0.06, 1)
                        entry.frame:SetBackdropBorderColor(0.20, 0.16, 0.09, 1)
                    else
                        entry.frame:SetBackdropColor(0.055, 0.048, 0.038, 1)
                        entry.frame:SetBackdropBorderColor(0.09, 0.075, 0.055, 1)
                    end
                end

                -- Static landmarks are remembered after discovery. They are
                -- bright while visible and muted when only remembered.
                if explored then
                    local worldKey = CellKey(worldX, worldY)
                    local staticMarker = STATIC_MARKERS[worldKey]
                    local chestOpened = run
                        and run.openedChests
                        and run.openedChests[worldKey]

                    if staticMarker and not (staticMarker.text == "$" and chestOpened) then
                        entry.marker:SetText(staticMarker.text)

                        if not visible then
                            entry.marker:SetTextColor(0.24, 0.22, 0.18)
                        elseif staticMarker.color == "red" then
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
    end

    local enemy = run and run.enemy or {
        x = KOBOLD_START_X,
        y = KOBOLD_START_Y,
        texture = KOBOLD_TEXTURE,
    }

    -- Creatures are not remembered through fog. They render only when the
    -- player can currently see their world cell.
    if enemy and enemy.alive ~= false and self:IsDungeonCellVisible(enemy.x, enemy.y) then
        local enemyViewX = enemy.x - cameraX + 1
        local enemyViewY = enemy.y - cameraY + 1

        if enemyViewX >= 1 and enemyViewX <= VIEWPORT_WIDTH
            and enemyViewY >= 1 and enemyViewY <= VIEWPORT_HEIGHT then

            local enemyCell = self.DungeonGrid.cells[CellKey(enemyViewX, enemyViewY)]
            if enemyCell and enemyCell.enemyIcon then
                enemyCell.frame:SetBackdropColor(0.16, 0.055, 0.045, 1)
                enemyCell.frame:SetBackdropBorderColor(COLORS.red[1], COLORS.red[2], COLORS.red[3], 1)
                enemyCell.marker:SetText("")
                enemyCell.enemyIcon:SetTexture(enemy.texture or KOBOLD_TEXTURE)
                enemyCell.enemyIcon:Show()
            end
        end
    end

    local playerX = run and run.playerX or START_X
    local playerY = run and run.playerY or START_Y
    local playerViewX = playerX - cameraX + 1
    local playerViewY = playerY - cameraY + 1

    if playerViewX >= 1 and playerViewX <= VIEWPORT_WIDTH
        and playerViewY >= 1 and playerViewY <= VIEWPORT_HEIGHT then

        local playerCell = self.DungeonGrid.cells[CellKey(playerViewX, playerViewY)]
        if playerCell then
            playerCell.frame:SetBackdropColor(0.11, 0.20, 0.08, 1)
            playerCell.frame:SetBackdropBorderColor(COLORS.green[1], COLORS.green[2], COLORS.green[3], 1)
            playerCell.marker:SetText("@")
            playerCell.marker:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
        end
    end

    self:RefreshActionButtons()
    self:RefreshEnemyCombatCard()

    if self.CharacterSheetFrame and self.CharacterSheetFrame:IsShown() then
        self:RefreshCharacterSheet()
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

    local currentKey = self.GetCurrentCharacterKey and self:GetCurrentCharacterKey()
    local selected = self.GetSelectedDungeonCharacter and self:GetSelectedDungeonCharacter()

    if selected and selected.key == currentKey then
        self:RefreshMainHandInfo(true)
        selected = self:GetSelectedDungeonCharacter()
    end

    if not selected or not selected.weapon then
        if self.DungeonRunStateText then
            self.DungeonRunStateText:SetText("SELECT A CHARACTER WITH A CACHED LOADOUT")
            self.DungeonRunStateText:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
        end
        return
    end

    local name = selected.name or "Unknown"
    local level = selected.level or 0
    local className = selected.className or "Adventurer"
    local maxHealth = selected.maxHealth or 0
    local selectedWeapon = CopyTable(selected.weapon)

    self.RunState = {
        active = true,
        completed = false,
        floor = 1,
        score = 0,
        turns = 0,
        playerX = START_X,
        playerY = START_Y,
        playerHealth = maxHealth,
        playerMaxHealth = maxHealth,
        baseMaxHealth = maxHealth,
        equipment = CopyTable(selected.equipment or {}),
        backpack = {},
        openedChests = {},
        explored = {},
        visible = {},
        enemy = {
            id = "kobold",
            name = "Kobold",
            x = KOBOLD_START_X,
            y = KOBOLD_START_Y,
            texture = KOBOLD_TEXTURE,
            hp = KOBOLD_MAX_HP,
            maxHp = KOBOLD_MAX_HP,
            damageMin = KOBOLD_DAMAGE_MIN,
            damageMax = KOBOLD_DAMAGE_MAX,
            alive = true,
            alerted = false,
            skipTurn = false,
        },
        snapshot = {
            characterKey = selected.key,
            name = name,
            level = level,
            className = className,
            classFile = selected.classFile,
            raceName = selected.raceName,
            realm = selected.realm,
            maxHealth = maxHealth,
            mainHandLink = selected.weaponLink,
            weaponIcon = selected.weaponIcon,
            weapon = selectedWeapon,
        },
    }

    if self.RunState.equipment and self.RunState.equipment.mainhand then
        self.RunState.equipment.mainhand.arcadeWeapon = CopyTable(selectedWeapon)
    end

    self:UpdateRunHealth()
    self:RefreshRunWeaponFromEquipment()
    self:RecalculateRunGearStats()
    self.DungeonArcadeDamage:SetText(string.format("Damage %d - %d", selectedWeapon.damageMin, selectedWeapon.damageMax))
    self.DungeonArcadeStyle:SetText(string.format(
        "%s  -  %s  -  Range %d",
        selectedWeapon.style or "Weapon",
        selectedWeapon.speed or "NORMAL",
        selectedWeapon.range or 1
    ))
    self.DungeonArcadeTraitName:SetText(selectedWeapon.traitName or "NO SIGNATURE TRAIT")
    self.DungeonArcadeTraitDesc:SetText(selectedWeapon.traitDescription or "")

    if self.DungeonBeginButton then
        self.DungeonBeginButton:SetEnabled(false)
        self.DungeonBeginButton.label:SetText("RUNNING")
        self.DungeonBeginButton.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    end

    if self.DungeonFloorTitle then
        self.DungeonFloorTitle:SetText("FLOOR 1  -  THE TEST CELLAR  -  25x25")
    end

    if self.DungeonRunStateText then
        self.DungeonRunStateText:SetText("PLAYER TURN - WASD / ARROWS")
        self.DungeonRunStateText:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
    end

    if self.DungeonRunPage and self.DungeonRunPage.SetPropagateKeyboardInput then
        self.DungeonRunPage:SetPropagateKeyboardInput(false)
    end

    self:SetDungeonSetupMode(false)
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
    self:AddCombatLog("A kobold is somewhere in the cellar.", "enemy")
    self:AddCombatLog("Vision radius: 4. Walls block line of sight.", "system")
    self:AddCombatLog(
        string.format("Kobold combat profile: %d HP, %d-%d damage.",
            KOBOLD_MAX_HP,
            KOBOLD_DAMAGE_MIN,
            KOBOLD_DAMAGE_MAX),
        "system"
    )
    self:AddCombatLog("Press C for character sheet and backpack.", "system")

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

    if self.CharacterSheetFrame then
        self.CharacterSheetFrame:Hide()
    end
    self:CancelCharacterItemDrag()

    if self.DungeonRunPage and self.DungeonRunPage.SetPropagateKeyboardInput then
        self.DungeonRunPage:SetPropagateKeyboardInput(true)
    end

    self:SetDungeonRunPortraitMode(false)
    self:SetRunMode(false)
    self:RefreshMainHandInfo(true)
    self:SetDungeonSetupMode(true)
    self:RefreshRunCounters()
    self:RenderDungeonGrid()
end

function GA:RunEnemyTurn()
    local run = self.RunState
    if not run or not run.active or not run.enemy or run.enemy.alive == false then
        self:RefreshActionButtons()
        return
    end

    local enemy = run.enemy

    if enemy.skipTurn then
        enemy.skipTurn = false
        self:AddCombatLog("The staggered kobold loses its turn.", "enemy")

        if self.DungeonRunStateText then
            self.DungeonRunStateText:SetText("PLAYER TURN - KOBOLD STAGGERED")
            self.DungeonRunStateText:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
        end

        self:RenderDungeonGrid()
        return
    end

    local seesPlayer = IsWithinRadius(
        enemy.x,
        enemy.y,
        run.playerX,
        run.playerY,
        ENEMY_VISION_RADIUS
    ) and HasLineOfSight(enemy.x, enemy.y, run.playerX, run.playerY)

    if seesPlayer and not enemy.alerted then
        enemy.alerted = true

        if self:IsDungeonCellVisible(enemy.x, enemy.y) then
            self:AddCombatLog("The kobold spots you!", "enemy")
        end
    end

    if IsAdjacent(enemy.x, enemy.y, run.playerX, run.playerY) then
        local stats = run.arcadeStats or {}
        local dodgeChance = stats.dodge or 0

        if dodgeChance > 0
            and math.random(1, 1000) <= math.floor(dodgeChance * 10) then

            self:AddCombatLog("You dodge the kobold's attack.", "player")

            if self.DungeonRunStateText then
                self.DungeonRunStateText:SetText(
                    string.format("PLAYER TURN - KOBOLD %d/%d HP", enemy.hp or 0, enemy.maxHp or 0)
                )
                self.DungeonRunStateText:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
            end

            self:RenderDungeonGrid()
            return
        end

        local rawDamage = math.random(enemy.damageMin or 1, enemy.damageMax or enemy.damageMin or 1)
        local armor = stats.armor or 0
        local mitigation = math.min(0.55, armor / (armor + 100))
        local damage = math.max(1, math.floor(rawDamage * (1 - mitigation) + 0.5))

        local blockChance = stats.block or 0
        local blocked = blockChance > 0
            and math.random(1, 1000) <= math.floor(blockChance * 10)

        if blocked then
            damage = math.max(1, math.floor(damage * 0.5 + 0.5))
        end

        run.playerHealth = math.max(0, (run.playerHealth or run.playerMaxHealth or 1) - damage)

        self:AddCombatLog(
            string.format("%sKobold hits you for %d damage. (%d/%d HP)",
                blocked and "BLOCK! " or "",
                damage,
                run.playerHealth,
                run.playerMaxHealth or run.playerHealth),
            "enemy"
        )

        self:UpdateRunHealth()

        if run.playerHealth <= 0 then
            self:FailDungeonRun("The kobold killed " .. (run.snapshot.name or "your hero") .. ".")
            return
        end

        if self.DungeonRunStateText then
            self.DungeonRunStateText:SetText(
                string.format("PLAYER TURN - KOBOLD %d/%d HP", enemy.hp or 0, enemy.maxHp or 0)
            )
            self.DungeonRunStateText:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
        end

        self:RenderDungeonGrid()
        return
    end

    if not enemy.alerted then
        self:RenderDungeonGrid()
        return
    end

    if self.DungeonRunStateText then
        self.DungeonRunStateText:SetText("ENEMY TURN - KOBOLD")
        self.DungeonRunStateText:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    end

    local wasVisible = self:IsDungeonCellVisible(enemy.x, enemy.y)
    local nextX, nextY = FindNextStep(enemy.x, enemy.y, run.playerX, run.playerY)

    if nextX and nextY and not (nextX == run.playerX and nextY == run.playerY) then
        enemy.x = nextX
        enemy.y = nextY

        local nowVisible = self:IsDungeonCellVisible(enemy.x, enemy.y)
        if wasVisible or nowVisible then
            self:AddCombatLog("Kobold moves closer.", "enemy")
        end
    end

    self:RenderDungeonGrid()

    if self.DungeonRunStateText then
        if IsAdjacent(enemy.x, enemy.y, run.playerX, run.playerY) then
            self.DungeonRunStateText:SetText(
                string.format("PLAYER TURN - KOBOLD %d/%d HP", enemy.hp or 0, enemy.maxHp or 0)
            )
            self.DungeonRunStateText:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
        else
            self.DungeonRunStateText:SetText("PLAYER TURN")
            self.DungeonRunStateText:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
        end
    end
end

function GA:TryLootChest(x, y)
    local run = self.RunState
    if not run or not run.active then
        return false
    end

    local key = CellKey(x, y)
    local loot = CHEST_LOOT[key]
    if not loot or (run.openedChests and run.openedChests[key]) then
        return false
    end

    if not self:AddItemToBackpack(loot) then
        self:AddCombatLog("Your backpack is full. The chest remains unopened.", "warning")
        return false
    end

    run.openedChests = run.openedChests or {}
    run.openedChests[key] = true
    run.score = (run.score or 0) + 25

    self:AddCombatLog("Chest opened: " .. loot.name .. " added to your backpack.", "system")
    self:AddCombatLog("Press C to open your character sheet.", "system")
    self:RefreshRunCounters()
    self:RenderDungeonGrid()
    return true
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

    if run.enemy
        and run.enemy.alive ~= false
        and nextX == run.enemy.x
        and nextY == run.enemy.y then

        self:PlayerAttackEnemy()
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
    self:TryLootChest(nextX, nextY)

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
        self:SetDungeonSetupMode(false)
        self:SetRunMode(true)
        self:SetDungeonRunPortraitMode(true)

        if self.DungeonRunPage and self.DungeonRunPage.SetPropagateKeyboardInput then
            self.DungeonRunPage:SetPropagateKeyboardInput(false)
        end

        self:UpdateRunHealth()

        self:RefreshRunWeaponFromEquipment()
        self:RecalculateRunGearStats()

        self:RefreshRunCounters()
        self:RenderDungeonGrid()
        return
    end

    self:SetRunMode(false)
    self:SetDungeonRunPortraitMode(false)
    self:SetDungeonSetupMode(true)

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

itemEventFrame:SetScript("OnEvent", function()
    if GA.RefreshMainHandInfo then
        GA:RefreshMainHandInfo()
    end
end)
