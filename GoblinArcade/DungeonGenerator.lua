local _, GA = ...

GA.DungeonGenerator = GA.DungeonGenerator or {}
local DG = GA.DungeonGenerator

DG.VERSION = 18

local MODULUS = 2147483647
local MULTIPLIER = 48271

local function CellKey(x, y)
    return tostring(x) .. ":" .. tostring(y)
end

local function NormalizeSeed(seed)
    local value = math.floor(math.abs(tonumber(seed) or 1)) % MODULUS
    if value <= 0 then
        value = 1
    end
    return value
end

local function CreateRng(seed)
    local state = NormalizeSeed(seed)

    return function(minimum, maximum)
        state = (state * MULTIPLIER) % MODULUS

        if minimum == nil then
            return state / MODULUS
        end

        if maximum == nil then
            maximum = minimum
            minimum = 1
        end

        if maximum <= minimum then
            return minimum
        end

        return minimum + (state % (maximum - minimum + 1))
    end
end

local function RoomCenter(room)
    return {
        x = room.x + math.floor(room.w / 2),
        y = room.y + math.floor(room.h / 2),
    }
end

local function RoomsOverlapWithPadding(a, b)
    local aLeft = a.x - 1
    local aRight = a.x + a.w
    local aTop = a.y - 1
    local aBottom = a.y + a.h

    local bLeft = b.x - 1
    local bRight = b.x + b.w
    local bTop = b.y - 1
    local bBottom = b.y + b.h

    return not (
        aRight < bLeft
        or bRight < aLeft
        or aBottom < bTop
        or bBottom < aTop
    )
end

local function InitializeWalls(width, height)
    local walls = {}

    for y = 1, height do
        for x = 1, width do
            walls[CellKey(x, y)] = true
        end
    end

    return walls
end

local function CarveCell(walls, walkable, x, y, width, height)
    if x <= 1 or x >= width or y <= 1 or y >= height then
        return
    end

    local key = CellKey(x, y)
    walls[key] = nil
    walkable[key] = true
end

local function CarveRoom(walls, walkable, room, width, height)
    for y = room.y, room.y + room.h - 1 do
        for x = room.x, room.x + room.w - 1 do
            CarveCell(walls, walkable, x, y, width, height)
        end
    end
end

local function CarveHorizontal(walls, walkable, fromX, toX, y, width, height)
    local step = fromX <= toX and 1 or -1
    local x = fromX

    while true do
        CarveCell(walls, walkable, x, y, width, height)
        if x == toX then
            break
        end
        x = x + step
    end
end

local function CarveVertical(walls, walkable, fromY, toY, x, width, height)
    local step = fromY <= toY and 1 or -1
    local y = fromY

    while true do
        CarveCell(walls, walkable, x, y, width, height)
        if y == toY then
            break
        end
        y = y + step
    end
end

local function ConnectCenters(walls, walkable, fromPoint, toPoint, width, height, rng)
    if rng(0, 1) == 0 then
        CarveHorizontal(walls, walkable, fromPoint.x, toPoint.x, fromPoint.y, width, height)
        CarveVertical(walls, walkable, fromPoint.y, toPoint.y, toPoint.x, width, height)
    else
        CarveVertical(walls, walkable, fromPoint.y, toPoint.y, fromPoint.x, width, height)
        CarveHorizontal(walls, walkable, fromPoint.x, toPoint.x, toPoint.y, width, height)
    end
end

local function CreateFallbackRooms(width, height)
    return {
        { x = 3, y = 3, w = 5, h = 5 },
        { x = width - 7, y = 3, w = 5, h = 5 },
        { x = 3, y = height - 7, w = 5, h = 5 },
        { x = width - 7, y = height - 7, w = 5, h = 5 },
        {
            x = math.floor(width / 2) - 2,
            y = math.floor(height / 2) - 2,
            w = 5,
            h = 5,
        },
    }
end

local PATH_DIRECTIONS = {
    { 0, -1 },
    { 1, 0 },
    { 0, 1 },
    { -1, 0 },
}

local function CalculateDistances(walkable, start)
    local distances = {
        [CellKey(start.x, start.y)] = 0,
    }
    local queue = {
        { x = start.x, y = start.y },
    }
    local head = 1

    while head <= #queue do
        local current = queue[head]
        head = head + 1
        local currentKey = CellKey(current.x, current.y)
        local currentDistance = distances[currentKey] or 0

        for _, direction in ipairs(PATH_DIRECTIONS) do
            local nextX = current.x + direction[1]
            local nextY = current.y + direction[2]
            local nextKey = CellKey(nextX, nextY)

            if walkable[nextKey] and distances[nextKey] == nil then
                distances[nextKey] = currentDistance + 1
                queue[#queue + 1] = {
                    x = nextX,
                    y = nextY,
                }
            end
        end
    end

    return distances
end

local function CountKeys(values)
    local count = 0
    for _ in pairs(values or {}) do
        count = count + 1
    end
    return count
end

local function BuildRoomMembership(rooms)
    local membership = {}

    for roomIndex, room in ipairs(rooms) do
        for y = room.y, room.y + room.h - 1 do
            for x = room.x, room.x + room.w - 1 do
                membership[CellKey(x, y)] = roomIndex
            end
        end
    end

    return membership
end

local function GetStudioRoomDefinition(role)
    for _, record in ipairs(GA.StudioData and GA.StudioData.rooms or {}) do
        if record.id == role then
            return record
        end
    end
    return nil
end

local function GetStudioRoomMarker(role, fallback)
    local definition = GetStudioRoomDefinition(role)
    local marker = definition and definition.marker
    if marker ~= nil and tostring(marker) ~= "" then
        return tostring(marker)
    end
    return fallback
end

local function BuildDoorSet(rooms, walkable)
    local doors = {}
    local membership = BuildRoomMembership(rooms)
    local doorCountByRoom = {}

    local function IsDoorAdjacent(x, y)
        return doors[CellKey(x - 1, y)] == true
            or doors[CellKey(x + 1, y)] == true
            or doors[CellKey(x, y - 1)] == true
            or doors[CellKey(x, y + 1)] == true
    end

    local function GetDoorLimit(room)
        local role = room and room.role

        -- Small rooms remain hard-capped at one door for readability.
        if room and (room.w * room.h) <= 25 then
            return 1
        end

        local definition = GetStudioRoomDefinition(role)
        local configured = definition and tonumber(definition.doorLimit)
        if configured then
            return math.max(1, math.floor(configured + 0.5))
        end

        if role == "TREASURE"
            or role == "SHRINE"
            or role == "SHOP"
            or role == "ELITE"
            or role == "BOSS" then
            return 1
        end

        return 2
    end

    local function CountWalkableOrthogonalNeighbors(x, y)
        local count = 0
        for _, direction in ipairs(PATH_DIRECTIONS) do
            if walkable[CellKey(x + direction[1], y + direction[2])] == true then
                count = count + 1
            end
        end
        return count
    end

    local function IsValidThreshold(roomIndex, doorX, doorY, insideX, insideY, outsideX, outsideY)
        local doorKey = CellKey(doorX, doorY)
        local insideKey = CellKey(insideX, insideY)
        local outsideKey = CellKey(outsideX, outsideY)

        -- A real door is a one-tile threshold through the wall band:
        -- room interior <-> door <-> corridor. The door tile must not also
        -- participate in a parallel corridor, T-junction or open area.
        return walkable[doorKey] == true
            and membership[doorKey] == nil
            and walkable[insideKey] == true
            and membership[insideKey] == roomIndex
            and walkable[outsideKey] == true
            and membership[outsideKey] == nil
            and CountWalkableOrthogonalNeighbors(doorX, doorY) == 2
    end

    local function CommitSegment(roomIndex, room, segment)
        if #segment == 0 then
            return
        end

        local currentCount = doorCountByRoom[roomIndex] or 0
        if currentCount >= GetDoorLimit(room) then
            return
        end

        -- Try the center first, then walk outward deterministically until a
        -- candidate is found that is not orthogonally adjacent to an existing
        -- door. This makes "two doors next to each other" a hard rule.
        local middle = math.floor((#segment + 1) / 2)

        for step = 0, #segment - 1 do
            local offset
            if step == 0 then
                offset = 0
            else
                local distance = math.floor((step + 1) / 2)
                offset = (step % 2 == 1) and -distance or distance
            end

            local candidate = segment[middle + offset]
            if candidate then
                local key = CellKey(candidate.x, candidate.y)
                if not doors[key] and not IsDoorAdjacent(candidate.x, candidate.y) then
                    doors[key] = true
                    doorCountByRoom[roomIndex] = currentCount + 1
                    return
                end
            end
        end
    end

    local function ScanSide(roomIndex, room, startValue, endValue, candidateFactory)
        local segment = {}

        for value = startValue, endValue do
            local candidate = candidateFactory(value)

            if IsValidThreshold(
                roomIndex,
                candidate.doorX,
                candidate.doorY,
                candidate.insideX,
                candidate.insideY,
                candidate.outsideX,
                candidate.outsideY
            ) then
                segment[#segment + 1] = {
                    x = candidate.doorX,
                    y = candidate.doorY,
                }
            else
                CommitSegment(roomIndex, room, segment)
                segment = {}
            end
        end

        CommitSegment(roomIndex, room, segment)
    end

    for roomIndex, room in ipairs(rooms) do
        local left = room.x
        local right = room.x + room.w - 1
        local top = room.y
        local bottom = room.y + room.h - 1

        ScanSide(roomIndex, room, left + 1, right - 1, function(x)
            return {
                doorX = x,
                doorY = top - 1,
                insideX = x,
                insideY = top,
                outsideX = x,
                outsideY = top - 2,
            }
        end)

        ScanSide(roomIndex, room, left + 1, right - 1, function(x)
            return {
                doorX = x,
                doorY = bottom + 1,
                insideX = x,
                insideY = bottom,
                outsideX = x,
                outsideY = bottom + 2,
            }
        end)

        ScanSide(roomIndex, room, top + 1, bottom - 1, function(y)
            return {
                doorX = left - 1,
                doorY = y,
                insideX = left,
                insideY = y,
                outsideX = left - 2,
                outsideY = y,
            }
        end)

        ScanSide(roomIndex, room, top + 1, bottom - 1, function(y)
            return {
                doorX = right + 1,
                doorY = y,
                insideX = right,
                insideY = y,
                outsideX = right + 2,
                outsideY = y,
            }
        end)
    end

    return doors
end

local function AssignRoomRoles(rooms, startRoomIndex, exitRoomIndex, floor, distances)
    local roleCounts = {
        START = 0,
        COMBAT = 0,
        TREASURE = 0,
        ELITE = 0,
        SHRINE = 0,
        SHOP = 0,
        EXIT = 0,
        BOSS = 0,
    }

    local candidates = {}

    for index, room in ipairs(rooms) do
        room.index = index
        room.center = RoomCenter(room)
        room.distanceFromStart = distances[CellKey(room.center.x, room.center.y)] or 0
        room.role = "COMBAT"

        if index == startRoomIndex then
            room.role = "START"
        elseif index == exitRoomIndex then
            room.role = "EXIT"
        else
            candidates[#candidates + 1] = room
        end
    end

    table.sort(candidates, function(a, b)
        if a.distanceFromStart == b.distanceFromStart then
            return a.index < b.index
        end
        return a.distanceFromStart > b.distanceFromStart
    end)

    local nextCandidate = 1
    local function AssignNext(role)
        local room = candidates[nextCandidate]
        if not room then
            return nil
        end

        room.role = role
        nextCandidate = nextCandidate + 1
        return room
    end

    -- High-value rooms are deliberately bounded and replace ordinary combat
    -- rooms instead of increasing the room count.
    local bossRoom
    if floor >= 9 then
        bossRoom = AssignNext("BOSS")
    end

    local treasureRoom = AssignNext("TREASURE")

    local eliteRoom
    if floor >= 5 then
        eliteRoom = AssignNext("ELITE")
    end

    local shrineRoom
    local shopRoom
    if floor >= 3 and floor % 2 == 1 then
        shrineRoom = AssignNext("SHRINE")
    end
    if floor == 6 then
        shopRoom = AssignNext("SHOP")
    end

    for _, room in ipairs(rooms) do
        roleCounts[room.role] = (roleCounts[room.role] or 0) + 1
    end

    return {
        counts = roleCounts,
        treasureRoom = treasureRoom,
        shrineRoom = shrineRoom,
        shopRoom = shopRoom,
        eliteRoom = eliteRoom,
        bossRoom = bossRoom,
    }
end

local function AddRoomRoleMarker(markers, room, text, color, kind)
    if not room or not room.center then
        return
    end

    markers[CellKey(room.center.x, room.center.y)] = {
        text = text,
        color = color,
        kind = kind,
        roomIndex = room.index,
    }
end

local function IsStudioYes(value)
    local normalized = string.upper(tostring(value or "YES"))
    return normalized == "YES" or normalized == "TRUE" or normalized == "1"
end

local function GetStudioEcosystem(ecosystemId)
    if not ecosystemId then return nil end
    for _, ecosystem in ipairs(GA.StudioData and GA.StudioData.ecosystems or {}) do
        if tostring(ecosystem.id or "") == tostring(ecosystemId) then
            return ecosystem
        end
    end
    return nil
end

local function EventAllowsEcosystem(event, ecosystemId)
    local ids = type(event and event.ecosystemIds) == "table" and event.ecosystemIds or {}
    if #ids == 0 or not ecosystemId then
        return true
    end
    for _, allowed in ipairs(ids) do
        if tostring(allowed) == tostring(ecosystemId) then
            return true
        end
    end
    return false
end

function DG:SelectEcosystem(runSeed)
    local eligible = {}
    local totalWeight = 0

    for _, ecosystem in ipairs(GA.StudioData and GA.StudioData.ecosystems or {}) do
        local weight = math.max(0, tonumber(ecosystem.weight) or 0)
        if IsStudioYes(ecosystem.enabled) and weight > 0 then
            eligible[#eligible + 1] = { ecosystem = ecosystem, weight = weight }
            totalWeight = totalWeight + weight
        end
    end

    if #eligible == 0 or totalWeight <= 0 then
        return nil
    end

    local rng = CreateRng(NormalizeSeed((tonumber(runSeed) or 1) + 32452843))
    local roll = rng() * totalWeight
    local cursor = 0
    for _, entry in ipairs(eligible) do
        cursor = cursor + entry.weight
        if roll <= cursor then
            return entry.ecosystem
        end
    end

    return eligible[#eligible].ecosystem
end

local function GetStudioEventRule()
    local rules = GA.StudioData and GA.StudioData.eventRules or {}
    for _, record in ipairs(rules) do
        if record.id == "dungeon_events" then
            return record
        end
    end
    return rules[1]
end

local function GetEventTargetCount(floor)
    local rule = GetStudioEventRule() or {}
    local base = math.max(0, math.floor(tonumber(rule.basePerFloor) or 0))
    local every = math.max(0, math.floor(tonumber(rule.extraEveryFloors) or 0))
    local maximum = math.max(base, math.floor(tonumber(rule.maxPerFloor) or base))
    local extra = 0
    if every > 0 then
        -- "Every N floors" starts the first extra event on Floor N:
        -- N=5 => Floors 1-4 use the base count, Floor 5+ gets +1.
        extra = math.floor(math.max(1, floor) / every)
    end
    return math.min(maximum, base + extra)
end

local function GetEligibleStudioEvents(floor, ecosystemId)
    local result = {}
    for _, event in ipairs(GA.StudioData and GA.StudioData.events or {}) do
        local minFloor = math.max(1, math.floor(tonumber(event.minFloor) or 1))
        local maxFloor = math.max(minFloor, math.floor(tonumber(event.maxFloor) or 9))
        local roles = type(event.roomRoleIds) == "table" and event.roomRoleIds or {}
        if IsStudioYes(event.enabled)
            and string.upper(tostring(event.randomSpawn or "YES")) ~= "NO"
            and EventAllowsEcosystem(event, ecosystemId)
            and floor >= minFloor
            and floor <= maxFloor
            and (tonumber(event.weight) or 0) > 0
            and #roles > 0 then
            result[#result + 1] = event
        end
    end
    return result
end

local function EventAllowsRoomRole(event, role)
    for _, allowed in ipairs(event and event.roomRoleIds or {}) do
        if tostring(allowed) == tostring(role) then
            return true
        end
    end
    return false
end

-- Structural rooms are protected by the first event framework. A future
-- Studio placement policy can expose them explicitly without letting an
-- accidental relation overwrite stairs, exits, shops or boss landmarks.
local EVENT_BLOCKED_ROOM_ROLES = {
    START = true,
    EXIT = true,
    SHOP = true,
    BOSS = true,
}

local function GetRoomEventTiles(room, markers)
    local result = {}
    if not room then return result end

    local right = room.x + room.w - 1
    local bottom = room.y + room.h - 1
    local center = room.center or RoomCenter(room)

    for y = room.y + 1, bottom - 1 do
        for x = room.x + 1, right - 1 do
            local key = CellKey(x, y)
            if not markers[key]
                and not (center and x == center.x and y == center.y) then
                result[#result + 1] = { x = x, y = y, key = key }
            end
        end
    end

    return result
end

local function BuildEventPlacementCandidates(event, rooms, markers, usedRooms)
    local candidates = {}
    for _, room in ipairs(rooms or {}) do
        if not usedRooms[room.index]
            and not EVENT_BLOCKED_ROOM_ROLES[tostring(room.role or "")]
            and EventAllowsRoomRole(event, room.role) then
            local tiles = GetRoomEventTiles(room, markers)
            for _, tile in ipairs(tiles) do
                tile.roomIndex = room.index
                tile.roomRole = room.role
                candidates[#candidates + 1] = tile
            end
        end
    end
    return candidates
end

local function PickWeightedEvent(events, rooms, markers, usedRooms, rng)
    local eligible = {}
    local totalWeight = 0

    for _, event in ipairs(events) do
        local candidates = BuildEventPlacementCandidates(event, rooms, markers, usedRooms)
        if #candidates > 0 then
            local weight = math.max(0, tonumber(event.weight) or 0)
            if weight > 0 then
                eligible[#eligible + 1] = {
                    event = event,
                    candidates = candidates,
                    weight = weight,
                }
                totalWeight = totalWeight + weight
            end
        end
    end

    if #eligible == 0 or totalWeight <= 0 then
        return nil, nil
    end

    local roll = rng() * totalWeight
    local cursor = 0
    local selected = eligible[#eligible]
    for _, entry in ipairs(eligible) do
        cursor = cursor + entry.weight
        if roll <= cursor then
            selected = entry
            break
        end
    end

    return selected.event, selected.candidates
end

local function AddDungeonEvents(markers, rooms, floor, rng, ecosystemId)
    local eventKeys = {}
    local eventPlacements = {}
    local available = GetEligibleStudioEvents(floor, ecosystemId)
    local usedRooms = {}
    local targetCount = GetEventTargetCount(floor)

    for _ = 1, targetCount do
        local event, candidates = PickWeightedEvent(available, rooms, markers, usedRooms, rng)
        if not event or not candidates or #candidates == 0 then
            break
        end

        local tile = candidates[rng(1, #candidates)]
        local color = string.lower(tostring(event.mapColor or "GOLD"))
        if color ~= "gold" and color ~= "green" and color ~= "red" and color ~= "muted" then
            color = "gold"
        end

        markers[tile.key] = {
            text = tostring(event.marker or "?"),
            color = color,
            kind = "event",
            eventId = event.id,
            roomIndex = tile.roomIndex,
        }
        eventKeys[#eventKeys + 1] = tile.key
        eventPlacements[#eventPlacements + 1] = {
            key = tile.key,
            x = tile.x,
            y = tile.y,
            eventId = event.id,
            roomIndex = tile.roomIndex,
            roomRole = tile.roomRole,
        }
        usedRooms[tile.roomIndex] = true

        -- Event definitions are unique per floor. Authors can create multiple
        -- definitions if they want similar events to coexist on one floor.
        for index = #available, 1, -1 do
            if available[index].id == event.id then
                table.remove(available, index)
                break
            end
        end
    end

    return eventKeys, eventPlacements
end

function DG:InjectEvent(floorMap, eventId, salt)
    if not floorMap or not eventId then
        return false, nil, "invalid"
    end

    local event
    for _, record in ipairs(GA.StudioData and GA.StudioData.events or {}) do
        if record.id == eventId then event = record break end
    end
    if not event or not IsStudioYes(event.enabled) then
        return false, nil, "missing"
    end
    if not EventAllowsEcosystem(event, floorMap.ecosystemId) then
        return false, nil, "ecosystem"
    end

    local floor = math.max(1, math.floor(tonumber(floorMap.floor) or 1))
    local minFloor = math.max(1, math.floor(tonumber(event.minFloor) or 1))
    local maxFloor = math.max(minFloor, math.floor(tonumber(event.maxFloor) or 9))
    if floor < minFloor or floor > maxFloor then
        return false, nil, "floor"
    end

    floorMap.eventKeys = floorMap.eventKeys or {}
    floorMap.eventPlacements = floorMap.eventPlacements or {}
    floorMap.markers = floorMap.markers or {}

    local usedRooms = {}
    for _, placement in ipairs(floorMap.eventPlacements) do
        if placement.eventId == eventId then
            return true, placement.key, "already_placed"
        end
        if placement.roomIndex then usedRooms[placement.roomIndex] = true end
    end
    for _, marker in pairs(floorMap.markers) do
        if marker.kind == "event" and marker.roomIndex then
            usedRooms[marker.roomIndex] = true
        end
    end

    local candidates = BuildEventPlacementCandidates(event, floorMap.rooms, floorMap.markers, usedRooms)
    if #candidates == 0 then
        return false, nil, "no_room"
    end

    local hash = 0
    for index = 1, #tostring(eventId) do
        hash = (hash * 33 + string.byte(tostring(eventId), index)) % MODULUS
    end
    local rng = CreateRng(NormalizeSeed((tonumber(floorMap.seed) or 1) + hash + (tonumber(salt) or 0) * 7919))
    local tile = candidates[rng(1, #candidates)]
    local color = string.lower(tostring(event.mapColor or "GOLD"))
    if color ~= "gold" and color ~= "green" and color ~= "red" and color ~= "muted" then
        color = "gold"
    end

    floorMap.markers[tile.key] = {
        text = tostring(event.marker or "?"),
        color = color,
        kind = "event",
        eventId = event.id,
        roomIndex = tile.roomIndex,
        chained = true,
    }
    floorMap.eventKeys[#floorMap.eventKeys + 1] = tile.key
    floorMap.eventPlacements[#floorMap.eventPlacements + 1] = {
        key = tile.key,
        x = tile.x,
        y = tile.y,
        eventId = event.id,
        roomIndex = tile.roomIndex,
        roomRole = tile.roomRole,
        chained = true,
    }
    floorMap.eventCount = #floorMap.eventKeys
    return true, tile.key, "injected"
end

local function AddTreasureChests(markers, chestKeys, room, maximumChests, markerText)
    if not room or not room.center then
        return
    end

    local candidates = {
        { x = room.center.x, y = room.center.y },
        { x = room.center.x + 1, y = room.center.y },
        { x = room.center.x - 1, y = room.center.y },
        { x = room.center.x, y = room.center.y + 1 },
        { x = room.center.x, y = room.center.y - 1 },
    }

    local added = 0
    local right = room.x + room.w - 1
    local bottom = room.y + room.h - 1

    for _, candidate in ipairs(candidates) do
        if added >= maximumChests then
            break
        end

        if candidate.x > room.x
            and candidate.x < right
            and candidate.y > room.y
            and candidate.y < bottom then

            local key = CellKey(candidate.x, candidate.y)
            if not markers[key] then
                markers[key] = {
                    text = markerText or "$",
                    color = "gold",
                    kind = "chest",
                    objectId = "treasure_chest",
                    roomIndex = room.index,
                }
                chestKeys[#chestKeys + 1] = key
                added = added + 1
            end
        end
    end
end


local WALL_TORCH_MIN_SPACING = 5
local WALL_TORCH_MAX_COUNT = 7
local WALL_TORCH_DIRECTIONS = {
    { facing = "N", dx = 0, dy = -1, tangentX = 1, tangentY = 0 },
    { facing = "E", dx = 1, dy = 0, tangentX = 0, tangentY = 1 },
    { facing = "S", dx = 0, dy = 1, tangentX = 1, tangentY = 0 },
    { facing = "W", dx = -1, dy = 0, tangentX = 0, tangentY = 1 },
}

local function IsTorchMarkerNearby(markers, x, y)
    for offsetY = -1, 1 do
        for offsetX = -1, 1 do
            if markers[CellKey(x + offsetX, y + offsetY)] then
                return true
            end
        end
    end
    return false
end

local function GetWallTorchCandidate(walls, walkable, markers, x, y, width, height)
    if x <= 2 or x >= width - 1 or y <= 2 or y >= height - 1 then
        return nil
    end

    if walls[CellKey(x, y)] ~= true or IsTorchMarkerNearby(markers, x, y) then
        return nil
    end

    local openDirection
    local openCount = 0

    for _, direction in ipairs(WALL_TORCH_DIRECTIONS) do
        local neighborKey = CellKey(x + direction.dx, y + direction.dy)
        if walkable[neighborKey] == true then
            openDirection = direction
            openCount = openCount + 1
        end
    end

    -- Only use clean wall faces. Corners, junctions and wall ends are skipped
    -- so torches read as deliberately mounted fixtures instead of random noise.
    if openCount ~= 1 or not openDirection then
        return nil
    end

    local tangentX = openDirection.tangentX
    local tangentY = openDirection.tangentY
    if walls[CellKey(x + tangentX, y + tangentY)] ~= true
        or walls[CellKey(x - tangentX, y - tangentY)] ~= true then
        return nil
    end

    return {
        x = x,
        y = y,
        facing = openDirection.facing,
        lightX = x + openDirection.dx,
        lightY = y + openDirection.dy,
    }
end

local function IsTorchFarEnough(selected, candidate)
    local minimumSquared = WALL_TORCH_MIN_SPACING * WALL_TORCH_MIN_SPACING

    for _, torch in ipairs(selected) do
        local dx = torch.x - candidate.x
        local dy = torch.y - candidate.y
        if (dx * dx) + (dy * dy) < minimumSquared then
            return false
        end
    end

    return true
end

local function BuildWallTorches(walls, walkable, markers, width, height, rng)
    local candidates = {}

    for y = 3, height - 2 do
        for x = 3, width - 2 do
            local candidate = GetWallTorchCandidate(
                walls,
                walkable,
                markers,
                x,
                y,
                width,
                height
            )
            if candidate then
                candidates[#candidates + 1] = candidate
            end
        end
    end

    -- Seeded shuffle: same floor seed = same fixture layout.
    for index = #candidates, 2, -1 do
        local swapIndex = rng(1, index)
        candidates[index], candidates[swapIndex] = candidates[swapIndex], candidates[index]
    end

    local targetCount = math.max(
        3,
        math.min(WALL_TORCH_MAX_COUNT, math.floor(CountKeys(walkable) / 30))
    )
    local selected = {}
    local torches = {}

    for _, candidate in ipairs(candidates) do
        if #selected >= targetCount then
            break
        end

        if IsTorchFarEnough(selected, candidate) then
            candidate.phase = rng(0, 628) / 100
            candidate.strengthScale = 0.92 + (rng(0, 16) / 100)
            selected[#selected + 1] = candidate
            torches[CellKey(candidate.x, candidate.y)] = candidate
        end
    end

    return torches
end

function DG:GenerateFloor(width, height, floorNumber, runSeed, ecosystemId)
    local mapWidth = math.max(15, tonumber(width) or 25)
    local mapHeight = math.max(15, tonumber(height) or 25)
    local floor = math.max(1, tonumber(floorNumber) or 1)
    local baseSeed = NormalizeSeed(runSeed or math.random(1, MODULUS - 1))
    local floorSeed = NormalizeSeed(baseSeed + floor * 104729)
    local rng = CreateRng(floorSeed)
    local ecosystem = GetStudioEcosystem(ecosystemId) or self:SelectEcosystem(baseSeed)
    local resolvedEcosystemId = ecosystem and ecosystem.id or nil

    local walls = InitializeWalls(mapWidth, mapHeight)
    local walkable = {}
    local rooms = {}

    local targetRooms = 6 + math.min(2, math.floor((floor - 1) / 4))
    local attempts = targetRooms * 60

    for _ = 1, attempts do
        if #rooms >= targetRooms then
            break
        end

        local roomWidth = rng(4, 7)
        local roomHeight = rng(4, 7)
        local maxX = mapWidth - roomWidth
        local maxY = mapHeight - roomHeight

        if maxX >= 2 and maxY >= 2 then
            local candidate = {
                x = rng(2, maxX),
                y = rng(2, maxY),
                w = roomWidth,
                h = roomHeight,
            }

            local blocked = false
            for _, existing in ipairs(rooms) do
                if RoomsOverlapWithPadding(candidate, existing) then
                    blocked = true
                    break
                end
            end

            if not blocked then
                rooms[#rooms + 1] = candidate
                CarveRoom(walls, walkable, candidate, mapWidth, mapHeight)
            end
        end
    end

    if #rooms < 4 then
        walls = InitializeWalls(mapWidth, mapHeight)
        walkable = {}
        rooms = CreateFallbackRooms(mapWidth, mapHeight)

        for _, room in ipairs(rooms) do
            CarveRoom(walls, walkable, room, mapWidth, mapHeight)
        end
    end

    -- Connect every room to its closest already-connected room. This produces
    -- a fully connected backbone without forcing a single long snake corridor.
    for index = 2, #rooms do
        local currentCenter = RoomCenter(rooms[index])
        local bestCenter
        local bestDistance

        for previousIndex = 1, index - 1 do
            local previousCenter = RoomCenter(rooms[previousIndex])
            local distance = math.abs(currentCenter.x - previousCenter.x)
                + math.abs(currentCenter.y - previousCenter.y)

            if not bestDistance or distance < bestDistance then
                bestDistance = distance
                bestCenter = previousCenter
            end
        end

        if bestCenter then
            ConnectCenters(
                walls,
                walkable,
                currentCenter,
                bestCenter,
                mapWidth,
                mapHeight,
                rng
            )
        end
    end

    -- Later floors get a few extra links. These create loops and alternate
    -- approaches without making every layout completely open.
    local extraConnections = 1 + math.min(2, math.floor((floor - 1) / 3))
    for _ = 1, extraConnections do
        if #rooms >= 2 then
            local firstIndex = rng(1, #rooms)
            local secondIndex = rng(1, #rooms)

            if firstIndex ~= secondIndex then
                ConnectCenters(
                    walls,
                    walkable,
                    RoomCenter(rooms[firstIndex]),
                    RoomCenter(rooms[secondIndex]),
                    mapWidth,
                    mapHeight,
                    rng
                )
            end
        end
    end

    -- Prefer a start room toward the north-west so the run has a readable
    -- sense of direction, while the exact room layout remains procedural.
    local startRoomIndex = 1
    local bestStartScore

    for index, room in ipairs(rooms) do
        local center = RoomCenter(room)
        local score = center.x + center.y

        if not bestStartScore or score < bestStartScore then
            bestStartScore = score
            startRoomIndex = index
        end
    end

    local start = RoomCenter(rooms[startRoomIndex])
    local distances = CalculateDistances(walkable, start)

    local exitRoomIndex = startRoomIndex
    local exit = {
        x = start.x,
        y = start.y,
    }
    local farthestDistance = -1

    for index, room in ipairs(rooms) do
        local center = RoomCenter(room)
        local distance = distances[CellKey(center.x, center.y)] or -1

        if index ~= startRoomIndex and distance > farthestDistance then
            farthestDistance = distance
            exitRoomIndex = index
            exit = center
        end
    end

    local roleData = AssignRoomRoles(
        rooms,
        startRoomIndex,
        exitRoomIndex,
        floor,
        distances
    )

    local markers = {}
    local chestKeys = {}
    local doors = BuildDoorSet(rooms, walkable)

    for key in pairs(doors) do
        markers[key] = {
            text = "+",
            color = "muted",
            kind = "door",
        }
    end

    markers[CellKey(exit.x, exit.y)] = {
        text = GetStudioRoomMarker("EXIT", ">"),
        color = "green",
        kind = "exit",
        roomIndex = exitRoomIndex,
    }

    if floor > 1 then
        markers[CellKey(start.x, start.y)] = {
            text = GetStudioRoomMarker("START", "<"),
            color = "green",
            kind = "stairsUp",
            roomIndex = startRoomIndex,
        }
    end

    AddTreasureChests(markers, chestKeys, roleData.treasureRoom, 2, GetStudioRoomMarker("TREASURE", "$"))
    AddRoomRoleMarker(markers, roleData.shrineRoom, GetStudioRoomMarker("SHRINE", "S"), "green", "shrine")
    AddRoomRoleMarker(markers, roleData.shopRoom, GetStudioRoomMarker("SHOP", "M"), "gold", "shop")
    AddRoomRoleMarker(markers, roleData.eliteRoom, GetStudioRoomMarker("ELITE", "!"), "red", "elite")
    AddRoomRoleMarker(markers, roleData.bossRoom, GetStudioRoomMarker("BOSS", "B"), "red", "boss")

    local eventKeys, eventPlacements = AddDungeonEvents(markers, rooms, floor, rng, resolvedEcosystemId)
    local wallTorches = BuildWallTorches(walls, walkable, markers, mapWidth, mapHeight, rng)

    return {
        generatorVersion = self.VERSION,
        ecosystemId = resolvedEcosystemId,
        ecosystemName = ecosystem and ecosystem.name or "Legacy Dungeon",
        stylePreset = ecosystem and ecosystem.stylePreset or "WARREN",
        floorTexture = ecosystem and ecosystem.floorTexture or "",
        wallTexture = ecosystem and ecosystem.wallTexture or "",
        wallAutotileTexture = ecosystem and ecosystem.wallAutotileTexture or "",
        name = ecosystem and ecosystem.dungeonName or "THE SHIFTING CELLAR",
        width = mapWidth,
        height = mapHeight,
        floor = floor,
        runSeed = baseSeed,
        seed = floorSeed,
        walls = walls,
        walkable = walkable,
        walkableCount = CountKeys(walkable),
        rooms = rooms,
        roomCount = #rooms,
        roomRoleCounts = roleData.counts,
        markers = markers,
        chestKeys = chestKeys,
        eventKeys = eventKeys,
        eventPlacements = eventPlacements,
        eventCount = #eventKeys,
        doors = doors,
        doorCount = CountKeys(doors),
        wallTorches = wallTorches,
        wallTorchCount = CountKeys(wallTorches),
        start = start,
        exit = exit,
    }
end
