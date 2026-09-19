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

local function CreateGrid(parent)
    local grid = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    grid:SetSize(363, 363)
    grid:SetPoint("TOP", 0, -32)
    ApplyBackdrop(grid, { 0.025, 0.022, 0.018, 1 }, COLORS.goldDim)

    local size = 27
    local gap = 1
    local stride = size + gap

    local staticWalls = {
        ["4:3"] = true, ["4:4"] = true, ["4:5"] = true,
        ["9:2"] = true, ["9:3"] = true,
        ["3:9"] = true, ["4:9"] = true, ["5:9"] = true,
        ["10:8"] = true, ["10:9"] = true, ["10:10"] = true,
    }

    for row = 1, 13 do
        for col = 1, 13 do
            local cell = CreateFrame("Frame", nil, grid, "BackdropTemplate")
            cell:SetSize(size, size)
            cell:SetPoint("TOPLEFT", (col - 1) * stride, -((row - 1) * stride))

            local edge = row == 1 or row == 13 or col == 1 or col == 13
            local wall = edge or staticWalls[col .. ":" .. row]

            if wall then
                ApplyBackdrop(cell, { 0.12, 0.095, 0.06, 1 }, { 0.20, 0.16, 0.09, 1 })
            else
                ApplyBackdrop(cell, { 0.055, 0.048, 0.038, 1 }, { 0.09, 0.075, 0.055, 1 })
            end

            if col == 7 and row == 7 then
                cell:SetBackdropColor(0.11, 0.20, 0.08, 1)
                cell:SetBackdropBorderColor(COLORS.green[1], COLORS.green[2], COLORS.green[3], 1)
                local marker = CreateText(cell, "GameFontNormalLarge", "@")
                marker:SetPoint("CENTER", 0, 1)
                marker:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
            elseif col == 11 and row == 4 then
                local marker = CreateText(cell, "GameFontNormal", "K")
                marker:SetPoint("CENTER")
                marker:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
            elseif col == 3 and row == 6 then
                local marker = CreateText(cell, "GameFontNormal", "S")
                marker:SetPoint("CENTER")
                marker:SetTextColor(0.72, 0.72, 0.70)
            elseif col == 9 and row == 11 then
                local marker = CreateText(cell, "GameFontNormal", "$")
                marker:SetPoint("CENTER")
                marker:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
            elseif col == 12 and row == 11 then
                local marker = CreateText(cell, "GameFontNormal", ">")
                marker:SetPoint("CENTER")
                marker:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
            end
        end
    end

    return grid
end

function GA:CreateDungeonRunPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)
    page:Hide()

    local title = CreateText(page, "GameFontNormalHuge", "DUNGEON RUN")
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

    local subtitle = CreateText(page, "GameFontHighlightSmall", "TURN-BASED ROGUELIKE  -  LAYOUT PROTOTYPE")
    subtitle:SetPoint("TOPRIGHT", -18, -22)
    subtitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local body = CreateFrame("Frame", nil, page)
    body:SetPoint("TOPLEFT", 18, -58)
    body:SetPoint("BOTTOMRIGHT", -18, 78)

    local left = CreateFrame("Frame", nil, body, "BackdropTemplate")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(150)
    ApplyBackdrop(left, { 0.050, 0.043, 0.034, 1 }, COLORS.goldDim)

    local portraitBorder = CreateFrame("Frame", nil, left, "BackdropTemplate")
    portraitBorder:SetSize(58, 58)
    portraitBorder:SetPoint("TOPLEFT", 12, -12)
    ApplyBackdrop(portraitBorder, { 0.02, 0.02, 0.02, 1 }, COLORS.gold)

    local portrait = portraitBorder:CreateTexture(nil, "ARTWORK")
    portrait:SetPoint("TOPLEFT", 2, -2)
    portrait:SetPoint("BOTTOMRIGHT", -2, 2)
    portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    self.DungeonPortrait = portrait

    local playerName = CreateText(left, "GameFontNormal", "")
    playerName:SetPoint("TOPLEFT", portraitBorder, "BOTTOMLEFT", 0, -8)
    playerName:SetPoint("RIGHT", left, "RIGHT", -10, 0)
    playerName:SetJustifyH("LEFT")
    playerName:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    self.DungeonPlayerName = playerName

    local playerMeta = CreateText(left, "GameFontHighlightSmall", "")
    playerMeta:SetPoint("TOPLEFT", playerName, "BOTTOMLEFT", 0, -4)
    playerMeta:SetPoint("RIGHT", left, "RIGHT", -10, 0)
    playerMeta:SetJustifyH("LEFT")
    playerMeta:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonPlayerMeta = playerMeta

    local statsTitle = CreateText(left, "GameFontNormalSmall", "RUN STATS")
    statsTitle:SetPoint("TOPLEFT", 12, -128)
    statsTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    self.DungeonHealth = CreateStatRow(left, "HEALTH", "--", -152)
    self.DungeonPower = CreateStatRow(left, "POWER", "--", -176)
    self.DungeonDodge = CreateStatRow(left, "DODGE", "--", -200)

    local gearTitle = CreateText(left, "GameFontNormalSmall", "GEAR INPUT")
    gearTitle:SetPoint("TOPLEFT", 12, -244)
    gearTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local gearHint = CreateText(left, "GameFontHighlightSmall", "Main hand")
    gearHint:SetPoint("TOPLEFT", 12, -268)
    gearHint:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local gearValue = CreateText(left, "GameFontDisableSmall", "scan coming next")
    gearValue:SetPoint("TOPLEFT", 12, -286)
    gearValue:SetPoint("RIGHT", left, "RIGHT", -10, 0)
    gearValue:SetJustifyH("LEFT")
    gearValue:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

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

    CreateStatRow(right, "FLOOR", "1 / 9", -252)
    CreateStatRow(right, "SCORE", "0", -276)
    CreateStatRow(right, "TURNS", "0", -300)

    local begin = CreateFlatButton(right, "BEGIN RUN", 114, 36)
    begin:SetPoint("BOTTOM", 0, 12)
    begin:SetEnabled(false)
    begin.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local center = CreateFrame("Frame", nil, body, "BackdropTemplate")
    center:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0)
    center:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", -8, 0)
    ApplyBackdrop(center, { 0.040, 0.035, 0.028, 1 }, COLORS.goldDim)

    local floor = CreateText(center, "GameFontNormalSmall", "FLOOR 1  -  THE TEST CELLAR")
    floor:SetPoint("TOP", 0, -10)
    floor:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    self.DungeonGrid = CreateGrid(center)

    local legend = CreateText(center, "GameFontDisableSmall", "@ YOU    K ENEMY    S ENEMY    $ CHEST    > EXIT")
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

    local state = CreateText(actionBar, "GameFontDisableSmall", "NO ACTIVE RUN")
    state:SetPoint("RIGHT", -12, 0)
    state:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    return page
end

function GA:RefreshDungeonSummary()
    if not self.DungeonPlayerName then
        return
    end

    local name = UnitName("player") or "Unknown"
    local level = UnitLevel("player") or 0
    local className = UnitClass("player") or "Adventurer"
    local maxHealth = UnitHealthMax("player") or 0

    self.DungeonPlayerName:SetText(name)
    self.DungeonPlayerMeta:SetText(string.format("Level %d %s", level, className))
    self.DungeonHealth:SetText(tostring(maxHealth))

    if self.DungeonPortrait then
        SetPortraitTexture(self.DungeonPortrait, "player")
    end
end
