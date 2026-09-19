local _, GA = ...

GA.DungeonGenerator = GA.DungeonGenerator or {}
local DG = GA.DungeonGenerator

DG.VERSION = 6

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

        -- Special-purpose rooms should read as deliberate destinations rather
        -- than open junctions.
        if role == "TREASURE"
            or role == "SHRINE"
            or role == "ELITE"
            or role == "BOSS" then
            return 1
        end

        -- Small rooms stay visually simple.
        if room and (room.w * room.h) <= 25 then
            return 1
        end

        return 2
    end

    local function IsValidThreshold(roomIndex, doorX, doorY, insideX, insideY, outsideX, outsideY)
        local doorKey = CellKey(doorX, doorY)
        local insideKey = CellKey(insideX, insideY)
        local outsideKey = CellKey(outsideX, outsideY)

        return walkable[doorKey] == true
            and membership[doorKey] == nil
            and walkable[insideKey] == true
            and membership[insideKey] == roomIndex
            and walkable[outsideKey] == true
            and membership[outsideKey] ~= roomIndex
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

        ScanSide(roomIndex, room, left, right, function(x)
            return {
                doorX = x,
                doorY = top - 1,
                insideX = x,
                insideY = top,
                outsideX = x,
                outsideY = top - 2,
            }
        end)

        ScanSide(roomIndex, room, left, right, function(x)
            return {
                doorX = x,
                doorY = bottom + 1,
                insideX = x,
                insideY = bottom,
                outsideX = x,
                outsideY = bottom + 2,
            }
        end)

        ScanSide(roomIndex, room, top, bottom, function(y)
            return {
                doorX = left - 1,
                doorY = y,
                insideX = left,
                insideY = y,
                outsideX = left - 2,
                outsideY = y,
            }
        end)

        ScanSide(roomIndex, room, top, bottom, function(y)
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
    if floor >= 3 then
        shrineRoom = AssignNext("SHRINE")
    end

    for _, room in ipairs(rooms) do
        roleCounts[room.role] = (roleCounts[room.role] or 0) + 1
    end

    return {
        counts = roleCounts,
        treasureRoom = treasureRoom,
        shrineRoom = shrineRoom,
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

local function AddTreasureChests(markers, chestKeys, room, maximumChests)
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
                    text = "$",
                    color = "gold",
                    kind = "chest",
                    roomIndex = room.index,
                }
                chestKeys[#chestKeys + 1] = key
                added = added + 1
            end
        end
    end
end

function DG:GenerateFloor(width, height, floorNumber, runSeed)
    local mapWidth = math.max(15, tonumber(width) or 25)
    local mapHeight = math.max(15, tonumber(height) or 25)
    local floor = math.max(1, tonumber(floorNumber) or 1)
    local baseSeed = NormalizeSeed(runSeed or math.random(1, MODULUS - 1))
    local floorSeed = NormalizeSeed(baseSeed + floor * 104729)
    local rng = CreateRng(floorSeed)

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
        text = ">",
        color = "green",
        kind = "exit",
        roomIndex = exitRoomIndex,
    }

    if floor > 1 then
        markers[CellKey(start.x, start.y)] = {
            text = "<",
            color = "green",
            kind = "stairsUp",
            roomIndex = startRoomIndex,
        }
    end

    AddTreasureChests(markers, chestKeys, roleData.treasureRoom, 2)
    AddRoomRoleMarker(markers, roleData.shrineRoom, "S", "green", "shrine")
    AddRoomRoleMarker(markers, roleData.eliteRoom, "!", "red", "elite")
    AddRoomRoleMarker(markers, roleData.bossRoom, "B", "red", "boss")

    return {
        generatorVersion = self.VERSION,
        name = "THE SHIFTING CELLAR",
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
        doors = doors,
        doorCount = CountKeys(doors),
        start = start,
        exit = exit,
    }
end
