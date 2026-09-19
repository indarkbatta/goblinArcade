local _, GA = ...

local COLORS = {
    background = { 0.035, 0.030, 0.024, 0.98 },
    panel = { 0.065, 0.055, 0.043, 0.96 },
    panelAlt = { 0.095, 0.078, 0.052, 0.96 },
    gold = { 1.00, 0.72, 0.12, 1.00 },
    goldDim = { 0.46, 0.34, 0.12, 1.00 },
    text = { 0.92, 0.89, 0.82, 1.00 },
    muted = { 0.58, 0.55, 0.50, 1.00 },
    green = { 0.35, 0.90, 0.45, 1.00 },
    red = { 0.92, 0.26, 0.20, 1.00 },
}

local function ApplyBackdrop(frame, backgroundColor, borderColor)
    if not frame.SetBackdrop then
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })

    local bg = backgroundColor or COLORS.panel
    local border = borderColor or COLORS.goldDim
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
end

local function CreateText(parent, fontObject, text, r, g, b)
    local label = parent:CreateFontString(nil, "OVERLAY", fontObject)
    label:SetText(text or "")
    if r then
        label:SetTextColor(r, g, b)
    end
    return label
end

local function CreateFlatButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    ApplyBackdrop(button, COLORS.panelAlt, COLORS.goldDim)

    button.label = CreateText(button, "GameFontNormal", text)
    button.label:SetPoint("CENTER")
    button.label:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    button:SetScript("OnEnter", function(self)
        if self:IsEnabled() then
            self:SetBackdropBorderColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1)
            self:SetBackdropColor(0.13, 0.10, 0.055, 1)
        end
    end)

    button:SetScript("OnLeave", function(self)
        if not self.gaSelected then
            self:SetBackdropBorderColor(COLORS.goldDim[1], COLORS.goldDim[2], COLORS.goldDim[3], 1)
            self:SetBackdropColor(COLORS.panelAlt[1], COLORS.panelAlt[2], COLORS.panelAlt[3], COLORS.panelAlt[4])
        end
    end)

    return button
end

GA.UI = GA.UI or {}
GA.UI.COLORS = COLORS
GA.UI.ApplyBackdrop = ApplyBackdrop
GA.UI.CreateText = CreateText
GA.UI.CreateFlatButton = CreateFlatButton

local function SetNavSelected(button, selected)
    if not button then
        return
    end

    button.gaSelected = selected

    if selected then
        button:SetBackdropColor(0.15, 0.105, 0.045, 1)
        button:SetBackdropBorderColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1)
        button.label:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    else
        button:SetBackdropColor(COLORS.panelAlt[1], COLORS.panelAlt[2], COLORS.panelAlt[3], COLORS.panelAlt[4])
        button:SetBackdropBorderColor(COLORS.goldDim[1], COLORS.goldDim[2], COLORS.goldDim[3], 1)
        button.label:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    end
end

function GA:ResetCombatLog()
    self.CombatLogLines = {}

    if self.CombatLogText then
        self.CombatLogText:SetText("")
    end
end

function GA:AddCombatLog(message, kind)
    if not message then
        return
    end

    self.CombatLogLines = self.CombatLogLines or {}

    local color = "c8c0b2"
    if kind == "player" then
        color = "63dd72"
    elseif kind == "enemy" then
        color = "ef6253"
    elseif kind == "system" then
        color = "ffc21a"
    elseif kind == "warning" then
        color = "f3a447"
    end

    table.insert(self.CombatLogLines, "|cff" .. color .. message .. "|r")

    while #self.CombatLogLines > 17 do
        table.remove(self.CombatLogLines, 1)
    end

    if self.CombatLogText then
        self.CombatLogText:SetText(table.concat(self.CombatLogLines, "\n\n"))
    end
end

function GA:SetRunMode(active)
    if self.NavigationRail then
        if active then
            self.NavigationRail:Hide()
        else
            self.NavigationRail:Show()
        end
    end

    if self.CombatLogRail then
        if active then
            self.CombatLogRail:Show()
        else
            self.CombatLogRail:Hide()
        end
    end
end

function GA:ShowPage(pageName)
    if not self.Pages or not self.Pages[pageName] then
        return
    end

    for name, page in pairs(self.Pages) do
        if name == pageName then
            page:Show()
        else
            page:Hide()
        end
    end

    self.ActivePage = pageName
    SetNavSelected(self.NavButtons and self.NavButtons.home, pageName == "home")
    SetNavSelected(self.NavButtons and self.NavButtons.dungeon, pageName == "dungeon")

    if pageName == "dungeon" and self.RefreshDungeonSummary then
        self:RefreshDungeonSummary()
    end
end

function GA:CreateHomePage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)

    local welcome = CreateText(page, "GameFontNormalHuge", "Choose a cabinet.")
    welcome:SetPoint("TOPLEFT", 24, -24)
    welcome:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

    local intro = CreateText(page, "GameFontHighlight", "GoblinArcade turns the quiet minutes between adventures into tiny games inside WoW.")
    intro:SetPoint("TOPLEFT", welcome, "BOTTOMLEFT", 0, -10)
    intro:SetPoint("RIGHT", page, "RIGHT", -24, 0)
    intro:SetJustifyH("LEFT")
    intro:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local card = CreateFrame("Frame", nil, page, "BackdropTemplate")
    card:SetPoint("TOPLEFT", 24, -104)
    card:SetPoint("TOPRIGHT", -24, -104)
    card:SetHeight(300)
    ApplyBackdrop(card, { 0.085, 0.067, 0.042, 1 }, COLORS.gold)

    local eyebrow = CreateText(card, "GameFontNormalSmall", "FIRST CABINET  -  ROGUELIKE")
    eyebrow:SetPoint("TOPLEFT", 22, -20)
    eyebrow:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local gameTitle = CreateText(card, "GameFontNormalHuge", "DUNGEON RUN")
    gameTitle:SetPoint("TOPLEFT", eyebrow, "BOTTOMLEFT", 0, -12)
    gameTitle:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

    local gameDescription = CreateText(card, "GameFontHighlight", "Your WoW character becomes the hero. Gear will be translated into deterministic roguelike equipment, then the dungeon does its best to kill you.")
    gameDescription:SetPoint("TOPLEFT", gameTitle, "BOTTOMLEFT", 0, -14)
    gameDescription:SetWidth(570)
    gameDescription:SetJustifyH("LEFT")
    gameDescription:SetJustifyV("TOP")
    gameDescription:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local status = CreateText(card, "GameFontNormal", ">  CHARACTER ROSTER ONLINE")
    status:SetPoint("BOTTOMLEFT", 22, 22)
    status:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])

    local play = CreateFlatButton(card, "OPEN DUNGEON", 160, 42)
    play:SetPoint("BOTTOMRIGHT", -22, 20)
    play:SetScript("OnClick", function()
        GA:ShowPage("dungeon")
    end)

    local coming = CreateText(page, "GameFontHighlightSmall", "Choose the hero you want to send into the dungeon. Alts use their last synced GoblinArcade loadout.")
    coming:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -18)
    coming:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local creator = CreateText(page, "GameFontHighlightSmall", "Goblin Arcade - created by Midnight Traveler.")
    creator:SetPoint("BOTTOMLEFT", 24, 14)
    creator:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local version = CreateText(page, "GameFontDisableSmall", "GoblinArcade v" .. tostring(self.version or "0.9.1") .. "  -  WoW Forever")
    version:SetPoint("BOTTOMRIGHT", -16, 12)
    version:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    return page
end

function GA:CreateMainFrame()
    if self.MainFrame then
        return
    end

    local frame = CreateFrame("Frame", "GoblinArcadeMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(1020, 630)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    ApplyBackdrop(frame, COLORS.background, COLORS.goldDim)
    frame:Hide()

    self.MainFrame = frame

    if UISpecialFrames then
        table.insert(UISpecialFrames, "GoblinArcadeMainFrame")
    end

    local header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(58)
    ApplyBackdrop(header, { 0.075, 0.055, 0.027, 1 }, COLORS.goldDim)

    local headerAccent = header:CreateTexture(nil, "ARTWORK")
    headerAccent:SetColorTexture(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.75)
    headerAccent:SetPoint("BOTTOMLEFT", 0, 0)
    headerAccent:SetPoint("BOTTOMRIGHT", 0, 0)
    headerAccent:SetHeight(2)

    local title = CreateText(header, "GameFontNormalHuge", "GOBLIN ARCADE")
    title:SetPoint("TOPLEFT", 22, -10)
    title:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local subtitle = CreateText(header, "GameFontHighlightSmall", "Azeroth's least responsible use of downtime.")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -2)
    subtitle:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function()
        frame:Hide()
    end)

    local rail = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    rail:SetPoint("TOPLEFT", 14, -72)
    rail:SetPoint("BOTTOMLEFT", 14, 14)
    rail:SetWidth(232)
    ApplyBackdrop(rail, COLORS.panel, COLORS.goldDim)
    self.NavigationRail = rail

    local section = CreateText(rail, "GameFontNormalSmall", "ARCADE")
    section:SetPoint("TOPLEFT", 16, -22)
    section:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local divider = rail:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(COLORS.goldDim[1], COLORS.goldDim[2], COLORS.goldDim[3], 1)
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", 14, -44)
    divider:SetPoint("TOPRIGHT", -14, -44)

    local home = CreateFlatButton(rail, "HOME", 200, 36)
    home:SetPoint("TOPLEFT", 16, -60)
    home:SetScript("OnClick", function()
        GA:ShowPage("home")
    end)

    local dungeon = CreateFlatButton(rail, "DUNGEON RUN", 200, 36)
    dungeon:SetPoint("TOPLEFT", home, "BOTTOMLEFT", 0, -8)
    dungeon:SetScript("OnClick", function()
        GA:ShowPage("dungeon")
    end)

    local scores = CreateFlatButton(rail, "SCORES", 200, 36)
    scores:SetPoint("TOPLEFT", dungeon, "BOTTOMLEFT", 0, -8)
    scores:SetEnabled(false)
    scores.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local settings = CreateFlatButton(rail, "SETTINGS", 200, 36)
    settings:SetPoint("TOPLEFT", scores, "BOTTOMLEFT", 0, -8)
    settings:SetEnabled(false)
    settings.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    self.NavButtons = {
        home = home,
        dungeon = dungeon,
    }

    local hint = CreateText(rail, "GameFontDisableSmall", "/ga  -  /goblinarcade")
    hint:SetPoint("BOTTOMLEFT", 16, 14)
    hint:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local combatRail = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    combatRail:SetPoint("TOPLEFT", 14, -72)
    combatRail:SetPoint("BOTTOMLEFT", 14, 14)
    combatRail:SetWidth(232)
    ApplyBackdrop(combatRail, { 0.045, 0.038, 0.030, 0.98 }, COLORS.goldDim)
    combatRail:Hide()
    self.CombatLogRail = combatRail

    local combatTitle = CreateText(combatRail, "GameFontNormalLarge", "COMBAT LOG")
    combatTitle:SetPoint("TOPLEFT", 14, -14)
    combatTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local combatSubtitle = CreateText(combatRail, "GameFontDisableSmall", "RUN EVENT STREAM")
    combatSubtitle:SetPoint("TOPLEFT", combatTitle, "BOTTOMLEFT", 0, -4)
    combatSubtitle:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local combatDivider = combatRail:CreateTexture(nil, "ARTWORK")
    combatDivider:SetColorTexture(COLORS.goldDim[1], COLORS.goldDim[2], COLORS.goldDim[3], 1)
    combatDivider:SetHeight(1)
    combatDivider:SetPoint("TOPLEFT", 12, -62)
    combatDivider:SetPoint("TOPRIGHT", -12, -62)

    local combatText = CreateText(combatRail, "GameFontHighlightSmall", "")
    combatText:SetPoint("TOPLEFT", 14, -78)
    combatText:SetPoint("BOTTOMRIGHT", -14, 42)
    combatText:SetJustifyH("LEFT")
    combatText:SetJustifyV("TOP")
    combatText:SetWordWrap(true)
    combatText:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    self.CombatLogText = combatText

    local combatHint = CreateText(combatRail, "GameFontDisableSmall", "Dungeon controls have keyboard focus.")
    combatHint:SetPoint("BOTTOMLEFT", 14, 14)
    combatHint:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local content = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    content:SetPoint("TOPLEFT", rail, "TOPRIGHT", 12, 0)
    content:SetPoint("BOTTOMRIGHT", -14, 14)
    ApplyBackdrop(content, COLORS.panel, COLORS.goldDim)
    self.ContentFrame = content

    self.Pages = {}
    self.Pages.home = self:CreateHomePage(content)

    if self.CreateDungeonRunPage then
        self.Pages.dungeon = self:CreateDungeonRunPage(content)
    end

    self:ShowPage("home")

    frame:SetScript("OnShow", function()
        GA:RefreshPlayerSummary()
        GA:SetRunMode(GA.RunState and GA.RunState.active)

        if GA.ActivePage == "dungeon" and GA.RefreshDungeonSummary then
            GA:RefreshDungeonSummary()
        end
    end)
end

function GA:RefreshPlayerSummary()
    if not self.MainFrame then
        return
    end

    if self.RefreshDungeonSummary then
        self:RefreshDungeonSummary()
    end
end
