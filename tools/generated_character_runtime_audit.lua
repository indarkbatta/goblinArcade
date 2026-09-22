local GA = {
    StudioData = {
        classes = {
            { id = "warrior", name = "Warrior", playable = "YES" },
        },
        races = {
            { id = "orc", name = "Orc", icon = "Achievement_Character_Orc_Male" },
        },
    },
}

function GA:NormalizeDifficulty(value)
    local key = string.upper(tostring(value or "NORMAL"))
    if key ~= "EASY" and key ~= "NORMAL" and key ~= "HARD" then key = "NORMAL" end
    return key
end

time = function() return 123456 end

local chunk = assert(loadfile("GoblinArcade/CharacterRoster.lua"))
chunk("GoblinArcade", GA)

GoblinArcadeDB = {
    characters = {
        ["Realm:Livewarrior"] = {
            key = "Realm:Livewarrior",
            name = "Livewarrior",
            realm = "Realm",
            level = 60,
            className = "Warrior",
            classFile = "WARRIOR",
            equipment = {},
        },
        ["arcade:1"] = {
            key = "arcade:1",
            sourceType = "arcade",
            isArcadeGenerated = true,
            name = "Grak",
            realm = "GoblinArcade",
            level = 1,
            startingLevel = 1,
            classId = "warrior",
            className = "Warrior",
            classFile = "WARRIOR",
            raceId = "orc",
            raceName = "Orc",
            maxHealth = 100,
            equipment = {},
            arcadeLoadout = {},
            arcadeSupplies = {},
        },
    },
    suspendedRuns = {
        ["Realm:Livewarrior"] = { floor = 3 },
    },
    actionBars = {
        ["Realm:Livewarrior"] = { "heroic_strike" },
    },
    actionBarVersions = {
        ["Realm:Livewarrior"] = 2,
    },
    selectedCharacterKey = "Realm:Livewarrior",
}

GA:InitializeCharacterRoster()

assert(GoblinArcadeDB.characterRosterMode == "generated_only_v1")
assert(GoblinArcadeDB.characters["Realm:Livewarrior"] == nil)
assert(GoblinArcadeDB.suspendedRuns["Realm:Livewarrior"] == nil)
assert(GoblinArcadeDB.actionBars["Realm:Livewarrior"] == nil)
assert(GoblinArcadeDB.actionBarVersions["Realm:Livewarrior"] == nil)
assert(GoblinArcadeDB.selectedCharacterKey == "arcade:1")

local roster = GA:GetCharacterRoster()
assert(#roster == 1)
assert(roster[1].key == "arcade:1")
assert(roster[1].level == 1)

local created, err = GA:CreateArcadeCharacter("Mog", "orc", "warrior", false, "NORMAL")
assert(created, err)
assert(created.sourceType == "arcade")
assert(created.isArcadeGenerated == true)
assert(created.level == 1)
assert(created.startingLevel == 1)
assert(created.realm == "GoblinArcade")
assert(string.match(created.key, "^arcade:"))

local selected = GA:GetSelectedDungeonCharacter()
assert(selected and selected.key == created.key)

print("Generated character runtime audit OK: legacy WoW roster entries are purged and every newly generated hero starts at Level 1.")
