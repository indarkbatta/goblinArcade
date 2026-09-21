#!/usr/bin/env lua5.1

local GA = {}
GA.StudioData = {
    rooms = {
        { id = "START", doorLimit = 2 }, { id = "COMBAT", doorLimit = 2 },
        { id = "TREASURE", doorLimit = 1 }, { id = "ELITE", doorLimit = 1 },
        { id = "SHRINE", doorLimit = 1 }, { id = "SHOP", doorLimit = 1 },
        { id = "EXIT", doorLimit = 1 }, { id = "BOSS", doorLimit = 1 },
    },
    eventRules = {
        { id = "dungeon_events", basePerFloor = 1, extraEveryFloors = 5, maxPerFloor = 2 },
    },
    events = {
        { id = "audit_a", enabled = "YES", randomSpawn = "YES", minFloor = 1, maxFloor = 9, weight = 100, roomRoleIds = { "COMBAT" }, marker = "?", mapColor = "GOLD" },
        { id = "audit_b", enabled = "YES", randomSpawn = "YES", minFloor = 1, maxFloor = 9, weight = 100, roomRoleIds = { "COMBAT" }, marker = "!", mapColor = "RED" },
        { id = "chain_only", enabled = "YES", randomSpawn = "NO", minFloor = 3, maxFloor = 9, weight = 1, roomRoleIds = { "COMBAT", "TREASURE" }, marker = "C", mapColor = "GREEN" },
    },
}

local chunk = assert(loadfile("GoblinArcade/DungeonGenerator.lua"))
chunk("GoblinArcade", GA)
assert(GA.DungeonGenerator.VERSION == 14, "Unexpected DungeonGenerator version")

local floorThree
for floor = 1, 9 do
    local map = assert(GA.DungeonGenerator:GenerateFloor(25, 25, floor, 424242))
    local expected = floor < 5 and 1 or 2
    assert(map.eventCount == expected, string.format("Floor %d: expected %d events, got %d", floor, expected, map.eventCount or -1))
    assert(type(map.eventPlacements) == "table" and #map.eventPlacements == expected, "eventPlacements mismatch")

    local usedRooms = {}
    for _, placement in ipairs(map.eventPlacements) do
        assert(placement.eventId ~= "chain_only", "Chain-only event entered the random pool")
        local marker = map.markers and map.markers[placement.key]
        assert(marker and marker.kind == "event", "Event placement is missing its marker")
        assert(not usedRooms[placement.roomIndex], "Two random events used the same room")
        usedRooms[placement.roomIndex] = true
        local role = map.rooms[placement.roomIndex] and map.rooms[placement.roomIndex].role or ""
        assert(role ~= "START" and role ~= "EXIT" and role ~= "SHOP" and role ~= "BOSS", "Event entered protected room")
    end
    if floor == 3 then floorThree = map end
end

assert(floorThree, "Floor 3 audit map missing")
local injected, key, reason = GA.DungeonGenerator:InjectEvent(floorThree, "chain_only", 7)
assert(injected and key and reason == "injected", "Chain-only event injection failed: " .. tostring(reason))
assert(floorThree.markers[key].eventId == "chain_only" and floorThree.markers[key].chained == true, "Injected chain marker metadata missing")
local injectedAgain, sameKey, secondReason = GA.DungeonGenerator:InjectEvent(floorThree, "chain_only", 8)
assert(injectedAgain and sameKey == key and secondReason == "already_placed", "Chain event duplicate protection failed")

GA.StudioData.eventRules = {
    { id = "dungeon_events", basePerFloor = 1, extraEveryFloors = 0, maxPerFloor = 1 },
}
GA.StudioData.events = {
    { id = "boss_only", enabled = "YES", randomSpawn = "YES", minFloor = 9, maxFloor = 9, weight = 100, roomRoleIds = { "BOSS" }, marker = "!", mapColor = "RED" },
}
local blocked = assert(GA.DungeonGenerator:GenerateFloor(25, 25, 9, 424242))
assert(blocked.eventCount == 0, "Protected BOSS room accepted an event")

print("Event runtime audit OK: cadence, random/chain separation, injection, duplicate protection and protected rooms.")
