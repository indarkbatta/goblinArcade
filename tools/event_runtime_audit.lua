#!/usr/bin/env lua5.1

local GA = {}
GA.StudioData = {
    rooms = {
        { id = "START", doorLimit = 2 },
        { id = "COMBAT", doorLimit = 2 },
        { id = "TREASURE", doorLimit = 1 },
        { id = "ELITE", doorLimit = 1 },
        { id = "SHRINE", doorLimit = 1 },
        { id = "SHOP", doorLimit = 1 },
        { id = "EXIT", doorLimit = 1 },
        { id = "BOSS", doorLimit = 1 },
    },
    eventRules = {
        { id = "dungeon_events", basePerFloor = 1, extraEveryFloors = 5, maxPerFloor = 2 },
    },
    events = {
        {
            id = "audit_event_a", enabled = "YES", minFloor = 1, maxFloor = 9,
            weight = 100, roomRoleIds = { "COMBAT" }, marker = "?", mapColor = "GOLD",
        },
        {
            id = "audit_event_b", enabled = "YES", minFloor = 1, maxFloor = 9,
            weight = 100, roomRoleIds = { "COMBAT" }, marker = "!", mapColor = "RED",
        },
    },
}

local chunk = assert(loadfile("GoblinArcade/DungeonGenerator.lua"))
chunk("GoblinArcade", GA)

for floor = 1, 9 do
    local map = assert(GA.DungeonGenerator:GenerateFloor(25, 25, floor, 424242))
    local expected = floor < 5 and 1 or 2
    assert(
        map.eventCount == expected,
        string.format("Floor %d: expected %d events, got %d", floor, expected, map.eventCount or -1)
    )
    assert(
        type(map.eventPlacements) == "table" and #map.eventPlacements == expected,
        string.format("Floor %d: eventPlacements mismatch", floor)
    )

    local usedRooms = {}
    for _, placement in ipairs(map.eventPlacements) do
        local marker = map.markers and map.markers[placement.key]
        assert(marker and marker.kind == "event", "Event placement is missing its marker")
        assert(not usedRooms[placement.roomIndex], "Two events used the same room")
        usedRooms[placement.roomIndex] = true

        local room = map.rooms and map.rooms[placement.roomIndex]
        local role = room and room.role or ""
        assert(role ~= "START", "Event placed in START room")
        assert(role ~= "EXIT", "Event placed in EXIT room")
        assert(role ~= "SHOP", "Event placed in SHOP room")
        assert(role ~= "BOSS", "Event placed in BOSS room")
    end
end

GA.StudioData.eventRules = {
    { id = "dungeon_events", basePerFloor = 1, extraEveryFloors = 0, maxPerFloor = 1 },
}
GA.StudioData.events = {
    {
        id = "boss_only", enabled = "YES", minFloor = 9, maxFloor = 9,
        weight = 100, roomRoleIds = { "BOSS" }, marker = "!", mapColor = "RED",
    },
}
local blocked = assert(GA.DungeonGenerator:GenerateFloor(25, 25, 9, 424242))
assert(blocked.eventCount == 0, "Protected BOSS room accepted an event")

print("Event runtime audit OK: floor cadence, deterministic placements, and protected room roles.")
