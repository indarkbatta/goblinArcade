local addonName, GA = ...

GA = GA or {}
_G.GoblinArcade = GA

GA.name = "GoblinArcade"
GA.version = "0.19.1"

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")

function GA:Toggle()
    if not self.MainFrame then
        self:CreateMainFrame()
    end

    if self.MainFrame:IsShown() then
        self.MainFrame:Hide()
    else
        self:RefreshPlayerSummary()
        self.MainFrame:Show()
    end
end

SLASH_GOBLINARCADE1 = "/ga"
SLASH_GOBLINARCADE2 = "/goblinarcade"
SlashCmdList.GOBLINARCADE = function()
    GA:Toggle()
end

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if GA.InitializeCharacterRoster then
            GA:InitializeCharacterRoster()
        end

        GA:CreateMainFrame()
        GA:RefreshPlayerSummary()
        print("|cffffc928GoblinArcade|r loaded. Type |cff7fd5ff/ga|r to open it.")
    end
end)
