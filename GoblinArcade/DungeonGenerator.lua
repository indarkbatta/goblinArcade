local _, GA = ...

GA.DungeonGenerator = GA.DungeonGenerator or {}
local DG = GA.DungeonGenerator

DG.VERSION = 2

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

local function BuildDoorSet(rooms, walkable)
    local doors = {}

    local function MarkDoor(x, y, outsideX, outsideY)
        if walkable[CellKey(x, y)] and walkable[CellKey(outsideX, outsideY)] then
            doors[CellKey(x, y)] = true
        end
    end

    for _, room in ipairs(rooms) do
        local left = room.x
        local right = room.x + room.w - 1
        local top = room.y
        local bottom = room.y + room.h - 1

        for x = left + 1, right - 1 do
            MarkDoor(x, top, x, top - 1)
            MarkDoor(x, bottom, x, bottom + 1)
        end

        for y = top + 1, bottom - 1 do
            MarkDoor(left, y, left - 1, y)
            MarkDoor(right, y, right + 1, y)
        end
    end

    return doors
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

    local chestCandidates = {}
    for index, room in ipairs(rooms) do
        if index ~= startRoomIndex and index ~= exitRoomIndex then
            local center = RoomCenter(room)
            chestCandidates[#chestCandidates + 1] = {
                x = center.x,
                y = center.y,
                distance = distances[CellKey(center.x, center.y)] or 0,
            }
        end
    end

    table.sort(chestCandidates, function(a, b)
        if a.distance == b.distance then
            if a.y == b.y then
                return a.x < b.x
            end
            return a.y < b.y
        end
        return a.distance > b.distance
    end)

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
    }

    local chestCount = math.min(2, #chestCandidates)
    for index = 1, chestCount do
        local chest = chestCandidates[index]
        local key = CellKey(chest.x, chest.y)

        markers[key] = {
            text = "$",
            color = "gold",
            kind = "chest",
        }
        chestKeys[#chestKeys + 1] = key
    end

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
        markers = markers,
        chestKeys = chestKeys,
        doors = doors,
        doorCount = CountKeys(doors),
        start = start,
        exit = exit,
    }
end
