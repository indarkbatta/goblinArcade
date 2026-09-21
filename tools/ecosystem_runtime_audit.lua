#!/usr/bin/env lua5.1

local GA = {}
GA.StudioData = {
    rooms = {
        { id = "START", doorLimit = 2 }, { id = "COMBAT", doorLimit = 2 },
        { id = "TREASURE", doorLimit = 1 }, { id = "ELITE", doorLimit = 1 },
        { id = "SHRINE", doorLimit = 1 }, { id = "SHOP", doorLimit = 1 },
        { id = "EXIT", doorLimit = 1 }, { id = "BOSS", doorLimit = 1 },
    },
    ecosystems = {
        { id = "orc", name = "Orc", dungeonName = "ORC CRYPT", enabled = "YES", weight = 70, stylePreset = "ORC_CRYPT", floorTexture = "Media/Tiles/orc_floor.png", wallTexture = "Media/Tiles/orc_wall.png" },
        { id = "kobold", name = "Kobold", dungeonName = "KOBOLD WARREN", enabled = "YES", weight = 30, stylePreset = "WARREN", floorTexture = "", wallTexture = "" },
    },
    ecosystemEnemies = {
        { id = "orc_a", ecosystemId = "orc", enemyId = "orc_raider", minFloor = 1, maxFloor = 9, weight = 70 },
        { id = "orc_b", ecosystemId = "orc", enemyId = "orc_hexer", minFloor = 1, maxFloor = 9, weight = 30 },
        { id = "kob_a", ecosystemId = "kobold", enemyId = "kobold", minFloor = 1, maxFloor = 9, weight = 80 },
        { id = "kob_b", ecosystemId = "kobold", enemyId = "spider", minFloor = 1, maxFloor = 9, weight = 20 },
    },
    eventRules = {
        { id = "dungeon_events", basePerFloor = 1, extraEveryFloors = 0, maxPerFloor = 1 },
    },
    events = {
        { id = "orc_event", enabled = "YES", randomSpawn = "YES", ecosystemIds = { "orc" }, minFloor = 1, maxFloor = 9, weight = 100, roomRoleIds = { "COMBAT" }, marker = "O", mapColor = "RED" },
        { id = "kobold_event", enabled = "YES", randomSpawn = "YES", ecosystemIds = { "kobold" }, minFloor = 1, maxFloor = 9, weight = 100, roomRoleIds = { "COMBAT" }, marker = "K", mapColor = "GOLD" },
    },
}

local dungeonChunk = assert(loadfile("GoblinArcade/DungeonGenerator.lua"))
dungeonChunk("GoblinArcade", GA)
local floorChunk = assert(loadfile("GoblinArcade/FloorGenerator.lua"))
floorChunk("GoblinArcade", GA)

assert(GA.DungeonGenerator.VERSION == 17, "Unexpected DungeonGenerator version")
assert(GA.FloorGenerator.VERSION == 5, "Unexpected FloorGenerator version")

local selectedA = assert(GA.DungeonGenerator:SelectEcosystem(424242))
local selectedB = assert(GA.DungeonGenerator:SelectEcosystem(424242))
assert(selectedA.id == selectedB.id, "Ecosystem selection must be deterministic for a run seed")

local allowed = {
    orc = { orc_raider = true, orc_hexer = true },
    kobold = { kobold = true, spider = true },
}

for floor = 1, 9 do
    local map = assert(GA.DungeonGenerator:GenerateFloor(25, 25, floor, 424242, selectedA.id))
    assert(map.ecosystemId == selectedA.id, "Ecosystem changed between floors")
    assert(map.ecosystemName == selectedA.name, "Ecosystem metadata missing")
    assert(map.name == selectedA.dungeonName, "Dungeon title did not follow ecosystem")
    assert(map.stylePreset == selectedA.stylePreset, "Style preset did not follow ecosystem")
    assert(map.floorTexture == (selectedA.floorTexture or ""), "Floor texture did not follow ecosystem")
    assert(map.wallTexture == (selectedA.wallTexture or ""), "Wall texture did not follow ecosystem")
    assert(map.wallAutotileTexture == (selectedA.wallAutotileTexture or ""), "Wall autotile texture did not follow ecosystem")
    for _, placement in ipairs(map.eventPlacements or {}) do
        if selectedA.id == "orc" then
            assert(placement.eventId == "orc_event", "Foreign event entered orc ecosystem")
        else
            assert(placement.eventId == "kobold_event", "Foreign event entered kobold ecosystem")
        end
    end

    local plan = GA.FloorGenerator:CreateArchetypePlan(10, floor, selectedA.id)
    assert(#plan == 10, "Ecosystem archetype plan size mismatch")
    for _, enemyId in ipairs(plan) do
        assert(allowed[selectedA.id][enemyId], "Foreign monster entered ecosystem: " .. tostring(enemyId))
    end
end

local explicitOrc = assert(GA.DungeonGenerator:GenerateFloor(25, 25, 3, 999, "orc"))
assert(explicitOrc.ecosystemId == "orc", "Explicit ecosystem was not preserved")
local ok, _, reason = GA.DungeonGenerator:InjectEvent(explicitOrc, "kobold_event", 1)
assert(ok == false and reason == "ecosystem", "Cross-ecosystem chained event was not rejected")

print("Ecosystem runtime audit OK: one deterministic ecosystem per 9-floor run, filtered monsters/events, style metadata and floor/wall textures.")
