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

    return value, label
end

local GRID_WIDTH = 25
local GRID_HEIGHT = 25
local VIEWPORT_WIDTH = 7
local VIEWPORT_HEIGHT = 7
local START_X = 7
local START_Y = 7
local EXIT_X = 23
local EXIT_Y = 23
local VISION_RADIUS = 4

local DUNGEON_TILE_SIZE = 96
local DUNGEON_TILE_GAP = 1
local CREATURE_SPRITE_SOURCE_SIZE = 128
local CREATURE_SPRITE_RENDER_SIZE = 96

local STATIC_WALLS = {
    ["4:3"] = true, ["4:4"] = true, ["4:5"] = true,
    ["9:2"] = true, ["9:3"] = true,
    ["3:9"] = true, ["4:9"] = true, ["5:9"] = true,
    ["10:8"] = true, ["10:9"] = true, ["10:10"] = true,

    ["14:5"] = true, ["14:6"] = true, ["14:7"] = true, ["14:8"] = true,
    ["15:12"] = true, ["16:12"] = true, ["17:12"] = true, ["18:12"] = true,
    ["7:15"] = true, ["8:15"] = true, ["9:15"] = true, ["10:15"] = true,
    ["19:16"] = true, ["19:17"] = true, ["19:18"] = true, ["19:19"] = true,
    ["12:20"] = true, ["13:20"] = true, ["14:20"] = true,
    ["21:9"] = true, ["22:9"] = true,
}

local STATIC_MARKERS = {
    ["3:6"] = { text = "S", color = "muted" },
    ["9:11"] = { text = "$", color = "gold" },
    ["17:15"] = { text = "$", color = "gold" },
    ["21:20"] = { text = "S", color = "muted" },
    ["23:23"] = { text = ">", color = "green" },
}

local KOBOLD_TEXTURE = "Interface\\AddOns\\GoblinArcade\\Media\\Monsters\\kobold"
local SPIDER_TEXTURE = "Interface\\AddOns\\GoblinArcade\\Media\\Monsters\\spider"
local SKELETON_TEXTURE = "Interface\\AddOns\\GoblinArcade\\Media\\Monsters\\skeleton"
local KOBOLD_PORTRAIT_ICON = "Interface\\Icons\\inv_misc_candlekobold_color1"

local ENEMY_VISUALS = {
    kobold = {
        gridTexture = KOBOLD_TEXTURE,
        portraitIcon = KOBOLD_PORTRAIT_ICON,
        gridTexCoord = { 0, 1, 0, 1 },
        portraitTexCoord = { 0.08, 0.92, 0.08, 0.92 },
    },
    spider = {
        gridTexture = SPIDER_TEXTURE,
        portraitIcon = SPIDER_TEXTURE,
        gridTexCoord = { 0, 1, 0, 1 },
        portraitTexCoord = { 0, 1, 0, 1 },
    },
    skeleton = {
        gridTexture = SKELETON_TEXTURE,
        portraitIcon = SKELETON_TEXTURE,
        gridTexCoord = { 0, 1, 0, 1 },
        portraitTexCoord = { 0, 1, 0, 1 },
    },
}

local function ResolveEnemyVisual(archetype)
    local hardcoded = ENEMY_VISUALS[archetype]
    if hardcoded then
        return hardcoded
    end

    for _, record in ipairs(GA.StudioData and GA.StudioData.enemies or {}) do
        if record.id == archetype and record.sprite and record.sprite ~= "" then
            local texturePath = tostring(record.sprite):gsub("/", "\\")
            if not string.find(texturePath, "^Interface\\") then
                texturePath = "Interface\\AddOns\\GoblinArcade\\" .. texturePath
            end
            return {
                gridTexture = texturePath,
                portraitIcon = texturePath,
                gridTexCoord = { 0, 1, 0, 1 },
                portraitTexCoord = { 0, 1, 0, 1 },
            }
        end
    end

    return ENEMY_VISUALS.kobold
end

local RUN_ABILITY_IDS = {
    "battle_stance",
    "heroic_strike",
    "battle_shout",
    "charge",
    "rend",
    "thunder_clap",
    "hamstring",
    "bloodrage",
    "defensive_stance",
    "sunder_armor",
    "overpower",
    "shield_bash",
    "demoralizing_shout",
    "revenge",
    "shield_block",
    "disarm",
    "retaliation",
    "victory_rush",
    "cleave",
    "slam",
    "intimidating_shout",
    "execute",
    "shield_wall",
    "berserker_stance",
    "intercept",
    "berserker_rage",
    "whirlwind",
    "pummel",
    "recklessness",
}

local FALLBACK_CHEST_LOOT = {
    name = "Fallback Dungeon Charm",
    icon = KOBOLD_PORTRAIT_ICON,
    itemLevel = 1,
    quality = 1,
    itemType = "Armor",
    itemSubType = "Miscellaneous",
    equipLoc = "INVTYPE_TRINKET",
    compatibleSlots = { trinket1 = true, trinket2 = true },
    slotLabel = "Trinket",
    description = "Emergency fallback used only when Studio loot data is invalid.",
    source = "dungeon",
}

local function CellKey(x, y)
    return tostring(x) .. ":" .. tostring(y)
end

local function ResolveCharacterWeapon(self, character)
    if not character then
        return nil
    end

    local equipment = self.GetEffectiveCharacterEquipment
        and self:GetEffectiveCharacterEquipment(character)
        or character.equipment
    local mainHand = equipment and equipment.mainhand
    if mainHand and self.EnsureArcadeItemConversion then
        self:EnsureArcadeItemConversion(mainHand)
        if mainHand.arcadeWeapon then
            return CopyTable(mainHand.arcadeWeapon)
        end
    end

    return character.weapon and CopyTable(character.weapon) or nil
end

local ACTIVE_FLOOR_MAP = nil

local DUNGEON_STYLE_PALETTES = {
    ORC_CRYPT = {
        wallVisible = { 0.145, 0.082, 0.044, 1 },
        wallBorder = { 0.235, 0.135, 0.065, 1 },
        floorVisible = { 0.066, 0.046, 0.029, 1 },
        floorBorder = { 0.115, 0.076, 0.043, 1 },
        wallMemory = { 0.052, 0.031, 0.022, 1 },
        wallMemoryBorder = { 0.078, 0.047, 0.031, 1 },
        floorMemory = { 0.024, 0.019, 0.015, 1 },
        floorMemoryBorder = { 0.034, 0.027, 0.020, 0.55 },
    },
    WARREN = {
        wallVisible = { 0.12, 0.095, 0.06, 1 },
        wallBorder = { 0.20, 0.16, 0.09, 1 },
        floorVisible = { 0.055, 0.048, 0.038, 1 },
        floorBorder = { 0.09, 0.075, 0.055, 1 },
        wallMemory = { 0.045, 0.038, 0.028, 1 },
        wallMemoryBorder = { 0.070, 0.058, 0.040, 1 },
        floorMemory = { 0.020, 0.018, 0.015, 1 },
        floorMemoryBorder = { 0.026, 0.023, 0.019, 0.55 },
    },
    HAUNTED_CRYPT = {
        wallVisible = { 0.075, 0.090, 0.115, 1 },
        wallBorder = { 0.125, 0.155, 0.195, 1 },
        floorVisible = { 0.034, 0.043, 0.055, 1 },
        floorBorder = { 0.060, 0.078, 0.100, 1 },
        wallMemory = { 0.030, 0.038, 0.052, 1 },
        wallMemoryBorder = { 0.046, 0.058, 0.078, 1 },
        floorMemory = { 0.015, 0.020, 0.028, 1 },
        floorMemoryBorder = { 0.022, 0.029, 0.040, 0.55 },
    },
    PLAGUE_CRYPT = {
        wallVisible = { 0.090, 0.105, 0.050, 1 },
        wallBorder = { 0.145, 0.165, 0.072, 1 },
        floorVisible = { 0.042, 0.050, 0.027, 1 },
        floorBorder = { 0.070, 0.085, 0.040, 1 },
        wallMemory = { 0.036, 0.043, 0.024, 1 },
        wallMemoryBorder = { 0.052, 0.062, 0.032, 1 },
        floorMemory = { 0.018, 0.023, 0.014, 1 },
        floorMemoryBorder = { 0.025, 0.032, 0.018, 0.55 },
    },
}

local function SetActiveFloorMap(floorMap)
    ACTIVE_FLOOR_MAP = floorMap
end

local function GetActiveDungeonStyle()
    local preset = ACTIVE_FLOOR_MAP and ACTIVE_FLOOR_MAP.stylePreset or "WARREN"
    return DUNGEON_STYLE_PALETTES[preset] or DUNGEON_STYLE_PALETTES.WARREN
end

local function ResolveDungeonTileTexture(texturePath)
    local raw = tostring(texturePath or "")
    if raw == "" or string.find(raw, "^https?://") then return nil end
    local resolved = raw:gsub("/", "\\")
    if not string.find(resolved, "^Interface\\") then
        resolved = "Interface\\AddOns\\GoblinArcade\\" .. resolved
    end
    return resolved
end

local function GetActiveDungeonTileTexture(isWall)
    if not ACTIVE_FLOOR_MAP then return nil end
    return ResolveDungeonTileTexture(isWall and ACTIVE_FLOOR_MAP.wallTexture or ACTIVE_FLOOR_MAP.floorTexture)
end

local function GetActiveDungeonWallAutotileTexture()
    if not ACTIVE_FLOOR_MAP then return nil end
    return ResolveDungeonTileTexture(ACTIVE_FLOOR_MAP.wallAutotileTexture)
end

local WALL_AUTOTILE_MASKS = {
    0, 1, 4, 5, 7, 16, 17, 20, 21, 23, 28, 29, 31, 64, 65, 68,
    69, 71, 80, 81, 84, 85, 87, 92, 93, 95, 112, 113, 116, 117, 119,
    124, 125, 127, 193, 197, 199, 209, 213, 215, 221, 223, 241, 245,
    247, 253, 255,
}
local WALL_AUTOTILE_INDEX_BY_MASK = {}
for index, mask in ipairs(WALL_AUTOTILE_MASKS) do
    WALL_AUTOTILE_INDEX_BY_MASK[mask] = index - 1
end

local WALL_AUTOTILE_COLUMNS = 8
local WALL_AUTOTILE_PIXEL_SIZE = 1024
local WALL_AUTOTILE_CELL_SIZE = 128
local WALL_AUTOTILE_TEXEL_INSET = 0.5 / WALL_AUTOTILE_PIXEL_SIZE

local function HasWallAutotileBit(mask, bitValue)
    return math.floor((tonumber(mask) or 0) / bitValue) % 2 == 1
end

local function NormalizeWallAutotileMask(mask)
    local value = tonumber(mask) or 0
    if not (HasWallAutotileBit(value, 1) and HasWallAutotileBit(value, 4)) and HasWallAutotileBit(value, 2) then
        value = value - 2
    end
    if not (HasWallAutotileBit(value, 4) and HasWallAutotileBit(value, 16)) and HasWallAutotileBit(value, 8) then
        value = value - 8
    end
    if not (HasWallAutotileBit(value, 16) and HasWallAutotileBit(value, 64)) and HasWallAutotileBit(value, 32) then
        value = value - 32
    end
    if not (HasWallAutotileBit(value, 64) and HasWallAutotileBit(value, 1)) and HasWallAutotileBit(value, 128) then
        value = value - 128
    end
    return value
end

local function GetWallAutotileTexCoord(mask)
    local normalized = NormalizeWallAutotileMask(mask)
    local atlasIndex = WALL_AUTOTILE_INDEX_BY_MASK[normalized]
    if atlasIndex == nil then atlasIndex = 0 end
    local column = atlasIndex % WALL_AUTOTILE_COLUMNS
    local row = math.floor(atlasIndex / WALL_AUTOTILE_COLUMNS)
    local left = (column * WALL_AUTOTILE_CELL_SIZE) / WALL_AUTOTILE_PIXEL_SIZE + WALL_AUTOTILE_TEXEL_INSET
    local right = ((column + 1) * WALL_AUTOTILE_CELL_SIZE) / WALL_AUTOTILE_PIXEL_SIZE - WALL_AUTOTILE_TEXEL_INSET
    local top = (row * WALL_AUTOTILE_CELL_SIZE) / WALL_AUTOTILE_PIXEL_SIZE + WALL_AUTOTILE_TEXEL_INSET
    local bottom = ((row + 1) * WALL_AUTOTILE_CELL_SIZE) / WALL_AUTOTILE_PIXEL_SIZE - WALL_AUTOTILE_TEXEL_INSET
    return left, right, top, bottom
end

local function GetDungeonWalls()
    return ACTIVE_FLOOR_MAP and ACTIVE_FLOOR_MAP.walls or STATIC_WALLS
end

local function GetDungeonMarkers()
    return ACTIVE_FLOOR_MAP and ACTIVE_FLOOR_MAP.markers or STATIC_MARKERS
end

local function GetDungeonStart()
    local start = ACTIVE_FLOOR_MAP and ACTIVE_FLOOR_MAP.start
    if start then
        return start.x, start.y
    end

    return START_X, START_Y
end

local function GetDungeonExit()
    local exit = ACTIVE_FLOOR_MAP and ACTIVE_FLOOR_MAP.exit
    if exit then
        return exit.x, exit.y
    end

    return EXIT_X, EXIT_Y
end

local function IsDungeonDoor(x, y)
    local doors = ACTIVE_FLOOR_MAP and ACTIVE_FLOOR_MAP.doors
    return doors and doors[CellKey(x, y)] == true
end

local function IsDungeonDoorClosed(x, y)
    if not IsDungeonDoor(x, y) then
        return false
    end

    local run = GA.RunState
    return not (run and run.openDoors and run.openDoors[CellKey(x, y)])
end

local function IsDungeonWall(x, y)
    if x < 1 or x > GRID_WIDTH or y < 1 or y > GRID_HEIGHT then
        return true
    end

    if x == 1 or x == GRID_WIDTH or y == 1 or y == GRID_HEIGHT then
        return true
    end

    return GetDungeonWalls()[CellKey(x, y)] == true
end

local function GetDungeonWallAutotileMask(x, y)
    local mask = 0
    local north = IsDungeonWall(x, y - 1)
    local east = IsDungeonWall(x + 1, y)
    local south = IsDungeonWall(x, y + 1)
    local west = IsDungeonWall(x - 1, y)

    if north then mask = mask + 1 end
    if IsDungeonWall(x + 1, y - 1) then mask = mask + 2 end
    if east then mask = mask + 4 end
    if IsDungeonWall(x + 1, y + 1) then mask = mask + 8 end
    if south then mask = mask + 16 end
    if IsDungeonWall(x - 1, y + 1) then mask = mask + 32 end
    if west then mask = mask + 64 end
    if IsDungeonWall(x - 1, y - 1) then mask = mask + 128 end

    return NormalizeWallAutotileMask(mask)
end

local function HasLineOfSight(fromX, fromY, toX, toY)
    if fromX == toX and fromY == toY then
        return true
    end

    local x = fromX
    local y = fromY
    local dx = math.abs(toX - fromX)
    local dy = math.abs(toY - fromY)
    local stepX = fromX < toX and 1 or -1
    local stepY = fromY < toY and 1 or -1
    local errorValue = dx - dy

    while not (x == toX and y == toY) do
        local doubledError = errorValue * 2

        if doubledError > -dy then
            errorValue = errorValue - dy
            x = x + stepX
        end

        if doubledError < dx then
            errorValue = errorValue + dx
            y = y + stepY
        end

        -- A wall tile itself is visible, but it blocks everything behind it.
        if x == toX and y == toY then
            return true
        end

        if IsDungeonWall(x, y) or IsDungeonDoorClosed(x, y) then
            return false
        end
    end

    return true
end

local function IsWithinRadius(fromX, fromY, toX, toY, radius)
    local dx = toX - fromX
    local dy = toY - fromY
    return (dx * dx) + (dy * dy) <= (radius * radius)
end

local function IsWithinVisionRadius(fromX, fromY, toX, toY)
    return IsWithinRadius(fromX, fromY, toX, toY, VISION_RADIUS)
end

local function CopyTable(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, child in pairs(value) do
        copy[key] = CopyTable(child)
    end
    return copy
end

local function BuildFloorChestLoot(floorMap, floorNumber)
    local loot = {}
    local chestKeys = floorMap and floorMap.chestKeys or {}

    for _, key in ipairs(chestKeys) do
        local marker = floorMap and floorMap.markers and floorMap.markers[key]
        local objectId = marker and marker.objectId or "treasure_chest"
        local objectDefinition = GA.GetDungeonObjectDefinition and GA:GetDungeonObjectDefinition(objectId)
        local item = GA.RollDungeonObjectLoot and GA:RollDungeonObjectLoot(objectId, floorNumber)
        if item then
            loot[key] = item
        elseif objectDefinition and objectDefinition.lootTableId then
            loot[key] = {
                empty = true,
                name = objectDefinition.name or "Container",
                objectId = objectId,
            }
        else
            loot[key] = CopyTable(FALLBACK_CHEST_LOOT)
        end
    end

    return loot
end

local function GetDungeonLootIcon(run, key)
    local item = run and run.chestLoot and run.chestLoot[key]
    if not item or item.empty then
        return nil
    end

    local icon = item.icon
    if icon == nil or tostring(icon) == "" then
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    end

    local numeric = tonumber(icon)
    if numeric then
        return numeric
    end

    local path = tostring(icon)
    if string.find(path, "\\", 1, true) then
        return path
    end

    return "Interface\\Icons\\" .. path
end

local PATH_DIRECTIONS = {
    { 0, -1 },
    { 1, 0 },
    { 0, 1 },
    { -1, 0 },
}

local function FindNextStep(startX, startY, targetX, targetY, occupied)
    if startX == targetX and startY == targetY then
        return nil, nil
    end

    local queue = {
        { x = startX, y = startY },
    }
    local head = 1
    local visited = {
        [CellKey(startX, startY)] = true,
    }
    local parent = {}
    local foundKey

    while head <= #queue do
        local current = queue[head]
        head = head + 1

        for _, delta in ipairs(PATH_DIRECTIONS) do
            local nextX = current.x + delta[1]
            local nextY = current.y + delta[2]
            local nextKey = CellKey(nextX, nextY)

            local isTarget = nextX == targetX and nextY == targetY
            local isOccupied = occupied and occupied[nextKey]

            if not visited[nextKey]
                and not IsDungeonWall(nextX, nextY)
                and not IsDungeonDoorClosed(nextX, nextY)
                and (isTarget or not isOccupied) then

                visited[nextKey] = true
                parent[nextKey] = CellKey(current.x, current.y)

                if nextX == targetX and nextY == targetY then
                    foundKey = nextKey
                    head = #queue + 1
                    break
                end

                queue[#queue + 1] = { x = nextX, y = nextY }
            end
        end
    end

    if not foundKey then
        return nil, nil
    end

    local startKey = CellKey(startX, startY)
    local stepKey = foundKey

    while parent[stepKey] and parent[stepKey] ~= startKey do
        stepKey = parent[stepKey]
    end

    local stepX, stepY = string.match(stepKey, "^(%d+):(%d+)$")
    return tonumber(stepX), tonumber(stepY)
end

local function IsAdjacent(x1, y1, x2, y2)
    return math.abs(x1 - x2) + math.abs(y1 - y2) == 1
end

local ENEMY_START_SAFE_RADIUS = 4
local ENEMY_MIN_SPAWN_DISTANCE = 3

local function GetEnemyAt(run, x, y)
    if not run or not run.enemies then
        return nil
    end

    for _, enemy in ipairs(run.enemies) do
        if enemy.alive ~= false and enemy.x == x and enemy.y == y then
            return enemy
        end
    end

    return nil
end

local function GetEnemyByUID(run, uid)
    if not run or not run.enemies or not uid then
        return nil
    end

    for _, enemy in ipairs(run.enemies) do
        if enemy.uid == uid and enemy.alive ~= false then
            return enemy
        end
    end

    return nil
end

local function GetAdjacentEnemy(run)
    if not run or not run.enemies then
        return nil
    end

    local active = GetEnemyByUID(run, run.activeEnemyId)
    if active and IsAdjacent(run.playerX, run.playerY, active.x, active.y) then
        return active
    end

    for _, enemy in ipairs(run.enemies) do
        if enemy.alive ~= false
            and IsAdjacent(run.playerX, run.playerY, enemy.x, enemy.y) then

            run.activeEnemyId = enemy.uid
            return enemy
        end
    end

    run.activeEnemyId = nil
    return nil
end

local function BuildOccupiedEnemyCells(run, ignoreUID)
    local occupied = {}

    if not run or not run.enemies then
        return occupied
    end

    for _, enemy in ipairs(run.enemies) do
        if enemy.alive ~= false and enemy.uid ~= ignoreUID then
            occupied[CellKey(enemy.x, enemy.y)] = true
        end
    end

    return occupied
end

local function CountWalkableTiles()
    local count = 0

    for y = 1, GRID_HEIGHT do
        for x = 1, GRID_WIDTH do
            if not IsDungeonWall(x, y) then
                count = count + 1
            end
        end
    end

    return count
end

local function ShuffleArray(values)
    for i = #values, 2, -1 do
        local j = math.random(1, i)
        values[i], values[j] = values[j], values[i]
    end
end

local function IsReservedEnemySpawn(x, y)
    if IsDungeonWall(x, y) then
        return true
    end

    if GetDungeonMarkers()[CellKey(x, y)] then
        return true
    end

    local startX, startY = GetDungeonStart()
    if IsWithinRadius(startX, startY, x, y, ENEMY_START_SAFE_RADIUS) then
        return true
    end

    return false
end

local function IsTooCloseToSpawnedEnemy(enemies, x, y, minimumDistance)
    local minimumSquared = minimumDistance * minimumDistance

    for _, enemy in ipairs(enemies) do
        local dx = enemy.x - x
        local dy = enemy.y - y

        if (dx * dx) + (dy * dy) < minimumSquared then
            return true
        end
    end

    return false
end

local ENCOUNTER_ROOM_ROLES = {
    COMBAT = true,
    ELITE = true,
    BOSS = true,
}

local function BuildRoomEnemyCandidates(floorMap)
    local specialAnchors = {}
    local combatAnchors = {}
    local remaining = {}

    if not floorMap or not floorMap.rooms then
        return nil
    end

    for _, room in ipairs(floorMap.rooms) do
        if ENCOUNTER_ROOM_ROLES[room.role] then
            local roomCandidates = {}

            for y = room.y, room.y + room.h - 1 do
                for x = room.x, room.x + room.w - 1 do
                    if not IsReservedEnemySpawn(x, y) then
                        roomCandidates[#roomCandidates + 1] = {
                            x = x,
                            y = y,
                            roomIndex = room.index,
                            roomRole = room.role,
                        }
                    end
                end
            end

            ShuffleArray(roomCandidates)

            local anchor = roomCandidates[1]
            if anchor then
                if room.role == "BOSS" then
                    anchor.forceRank = "boss"
                    specialAnchors[#specialAnchors + 1] = anchor
                elseif room.role == "ELITE" then
                    anchor.forceRank = "elite"
                    specialAnchors[#specialAnchors + 1] = anchor
                else
                    combatAnchors[#combatAnchors + 1] = anchor
                end
            end

            for index = 2, #roomCandidates do
                remaining[#remaining + 1] = roomCandidates[index]
            end
        end
    end

    ShuffleArray(combatAnchors)
    ShuffleArray(remaining)

    local candidates = {}

    for _, candidate in ipairs(specialAnchors) do
        candidates[#candidates + 1] = candidate
    end
    for _, candidate in ipairs(combatAnchors) do
        candidates[#candidates + 1] = candidate
    end
    for _, candidate in ipairs(remaining) do
        candidates[#candidates + 1] = candidate
    end

    return candidates
end

local function CreateFloorEnemies(enemyGenerator, playerLevel, floor, gearPressure, archetypePlan, rankPlan, floorMap, difficulty)
    local candidates = BuildRoomEnemyCandidates(floorMap)

    if not candidates or #candidates == 0 then
        candidates = {}

        for y = 1, GRID_HEIGHT do
            for x = 1, GRID_WIDTH do
                if not IsReservedEnemySpawn(x, y) then
                    candidates[#candidates + 1] = { x = x, y = y }
                end
            end
        end

        ShuffleArray(candidates)
    end

    local enemies = {}
    local used = {}

    local function AddEnemyAt(candidate)
        local nextIndex = #enemies + 1
        local archetype = archetypePlan[nextIndex] or "kobold"
        local rank = candidate.forceRank
            or (rankPlan and rankPlan[nextIndex])
            or "normal"
        local visual = ResolveEnemyVisual(archetype)

        local enemy = enemyGenerator:CreateEnemy({
            archetype = archetype,
            rank = rank,
            playerLevel = playerLevel,
            floor = floor,
            gearPressure = gearPressure,
            difficulty = difficulty,
        })

        enemy.uid = "enemy-" .. tostring(nextIndex)
        enemy.x = candidate.x
        enemy.y = candidate.y
        enemy.texture = visual.gridTexture
        enemy.portraitIcon = visual.portraitIcon
        enemy.gridTexCoord = visual.gridTexCoord
        enemy.portraitTexCoord = visual.portraitTexCoord
        enemy.intent = "IDLE"
        enemy.roomIndex = candidate.roomIndex
        enemy.roomRole = candidate.roomRole

        enemies[#enemies + 1] = enemy
        used[CellKey(candidate.x, candidate.y)] = true
    end

    -- First pass keeps enemies comfortably separated.
    for _, candidate in ipairs(candidates) do
        if #enemies >= #archetypePlan then
            break
        end

        if not IsTooCloseToSpawnedEnemy(
            enemies,
            candidate.x,
            candidate.y,
            ENEMY_MIN_SPAWN_DISTANCE
        ) then
            AddEnemyAt(candidate)
        end
    end

    -- Fallback only matters on unusually constrained future maps. It preserves
    -- uniqueness and safety rules but relaxes anti-clustering before reducing
    -- the requested floor population.
    if #enemies < #archetypePlan then
        for _, candidate in ipairs(candidates) do
            if #enemies >= #archetypePlan then
                break
            end

            if not used[CellKey(candidate.x, candidate.y)] then
                AddEnemyAt(candidate)
            end
        end
    end

    return enemies
end

local function GetEnemyMovementSteps(enemy, enemyPhase)
    local pattern = enemy and enemy.movementPattern or "normal"

    if pattern == "quick" then
        -- Spider: always moves at least once, and gets a predictable second
        -- movement step every second enemy phase.
        return enemyPhase % 2 == 0 and 2 or 1
    end

    if pattern == "slow" then
        -- Skeleton: attacks normally in melee, but only advances every other
        -- enemy phase while chasing.
        return enemyPhase % 2 == 0 and 1 or 0
    end

    return 1
end

local function BuildCompositionText(counts)
    counts = counts or {}

    return string.format(
        "%d Kobold / %d Spider / %d Skeleton",
        counts.kobold or 0,
        counts.spider or 0,
        counts.skeleton or 0
    )
end

local function BuildRankCompositionText(counts)
    counts = counts or {}

    return string.format(
        "%d Normal / %d Veteran / %d Elite / %d Boss",
        counts.normal or 0,
        counts.veteran or 0,
        counts.elite or 0,
        counts.boss or 0
    )
end

local function CountEnemyRanks(enemies)
    local counts = {
        normal = 0,
        veteran = 0,
        elite = 0,
        boss = 0,
    }

    for _, enemy in ipairs(enemies or {}) do
        local rank = enemy.rank or "normal"
        counts[rank] = (counts[rank] or 0) + 1
    end

    return counts
end

local function GetStudioShrineChoice(choiceId)
    for _, record in ipairs(GA.StudioData and GA.StudioData.shrines or {}) do
        if record.id == choiceId then
            return record
        end
    end
    return nil
end

local function GetStudioDungeonEvent(eventId)
    for _, record in ipairs(GA.StudioData and GA.StudioData.events or {}) do
        if record.id == eventId then
            return record
        end
    end
    return nil
end

local function GetStudioDungeonEventOptions(eventId)
    local result = {}
    for _, record in ipairs(GA.StudioData and GA.StudioData.eventOptions or {}) do
        if record.eventId == eventId then
            result[#result + 1] = record
        end
    end
    table.sort(result, function(a, b)
        local left = tonumber(a.sortOrder) or 0
        local right = tonumber(b.sortOrder) or 0
        if left == right then
            return tostring(a.id or "") < tostring(b.id or "")
        end
        return left < right
    end)
    return result
end

local function GetStudioDungeonEventOption(optionId)
    for _, record in ipairs(GA.StudioData and GA.StudioData.eventOptions or {}) do
        if record.id == optionId then
            return record
        end
    end
    return nil
end

local function BuildInitialEventStates(floorMap)
    local states = {}
    if not floorMap then return states end

    local function AddState(key, eventId, roomIndex)
        if key and eventId and not states[key] then
            states[key] = {
                eventId = eventId,
                roomIndex = roomIndex,
                resolved = false,
                selectedOptionId = nil,
            }
        end
    end

    for _, placement in ipairs(floorMap.eventPlacements or {}) do
        AddState(placement.key, placement.eventId, placement.roomIndex)
    end

    -- Migration path for 0.59.0 floors: reconstruct state from event markers.
    for key, marker in pairs(floorMap.markers or {}) do
        if marker.kind == "event" then
            AddState(key, marker.eventId, marker.roomIndex)
        end
    end
    return states
end

local function EnsureDungeonEventStates(run)
    if not run then return {} end
    run.eventStates = run.eventStates or {}
    local initial = BuildInitialEventStates(run.floorMap)
    for key, state in pairs(initial) do
        if not run.eventStates[key] then
            run.eventStates[key] = state
        end
    end
    return run.eventStates
end

local function IsDungeonEventResolved(run, eventKey)
    local states = run and run.eventStates
    return states and states[eventKey] and states[eventKey].resolved == true
end

local function GetDungeonEventIcon(event)
    local fallback = "Interface\\Icons\\INV_Misc_QuestionMark"
    if GA.ResolveStudioIconTexture then
        return GA:ResolveStudioIconTexture(event and event.icon, fallback)
    end
    return fallback
end

local function GetDungeonEventOptionHint(option)
    if not option then return "" end
    local effect = string.upper(tostring(option.effect or "NONE"))
    local value = tonumber(option.value) or 0
    local secondary = tonumber(option.secondaryValue) or 0

    if effect == "HEAL_PERCENT" then
        return string.format("Restore %.0f%% of maximum health.", value)
    elseif effect == "DAMAGE_PERCENT" then
        return string.format("Lose %.0f%% of maximum health.", value)
    elseif effect == "HP_FOR_SCORE" then
        return string.format("Lose %.0f%% max HP as current health; gain %.0f base score.", value, secondary)
    elseif effect == "DAMAGE_BONUS" then
        return string.format("Gain +%.0f%% run damage.", value)
    elseif effect == "MAX_HP_PERCENT" then
        return string.format("Change maximum health by %+.0f%%.", value)
    elseif effect == "COPPER" then
        return string.format("Gain %.0f Copper.", value)
    elseif effect == "SCORE" then
        return string.format("Gain %.0f base score.", value)
    elseif effect == "LOOT_TABLE" then
        return "Roll loot table: " .. tostring(option.lootTableId or "none")
    end
    return "No mechanical effect."
end

local DEFAULT_RUN_XP_CURVE = { 80, 90, 100, 110, 125, 140, 155, 175 }

local RUN_SCORE = {
    ELITE_KILL_BONUS = 100,
    BOSS_KILL_BONUS = 300,
    CHEST = 25,
    ELITE_CACHE = 75,
    BOSS_CACHE = 150,
    FLOOR_CLEAR = 100,
    COMPLETION = 1000,
}

local RUN_COPPER_RANK_MULTIPLIER = {
    normal = 1.00,
    veteran = 1.40,
    elite = 2.25,
    boss = 5.00,
}

local function FormatCopperValue(copper)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local remainingCopper = copper % 100

    if gold > 0 then
        return string.format("%dg %ds %dc", gold, silver, remainingCopper)
    end
    if silver > 0 then
        return string.format("%ds %dc", silver, remainingCopper)
    end
    return string.format("%dc", remainingCopper)
end

local function EnsureRunTracking(run)
    if not run then return nil end

    run.stats = run.stats or {}
    run.stats.kills = run.stats.kills or 0
    run.stats.eliteKills = run.stats.eliteKills or 0
    run.stats.bossKills = run.stats.bossKills or 0
    run.stats.chests = run.stats.chests or 0
    run.stats.shrines = run.stats.shrines or 0
    run.stats.events = run.stats.events or 0
    run.stats.floorsCleared = run.stats.floorsCleared or 0
    run.stats.copperEarned = run.stats.copperEarned or 0
    run.stats.copperSpent = run.stats.copperSpent or 0
    run.stats.itemsBought = run.stats.itemsBought or 0
    run.stats.itemsSold = run.stats.itemsSold or 0

    run.scoreBreakdown = run.scoreBreakdown or {}
    run.scoreBreakdown.enemy = run.scoreBreakdown.enemy or 0
    run.scoreBreakdown.rankBonus = run.scoreBreakdown.rankBonus or 0
    run.scoreBreakdown.chest = run.scoreBreakdown.chest or 0
    run.scoreBreakdown.floor = run.scoreBreakdown.floor or 0
    run.scoreBreakdown.shrine = run.scoreBreakdown.shrine or 0
    run.scoreBreakdown.event = run.scoreBreakdown.event or 0
    run.scoreBreakdown.completion = run.scoreBreakdown.completion or 0

    run.lootSummary = run.lootSummary or {}
    run.clearedFloors = run.clearedFloors or {}
    return run.stats
end

local function AddRunScore(run, bucket, amount)
    if not run then return 0 end
    EnsureRunTracking(run)

    local scoreMultiplier = math.max(0.1, tonumber(run.difficultyScoreMultiplier) or 1)
    local value = math.max(0, math.floor(((tonumber(amount) or 0) * scoreMultiplier) + 0.5))
    if value <= 0 then return 0 end

    run.score = (run.score or 0) + value
    if bucket then
        run.scoreBreakdown[bucket] = (run.scoreBreakdown[bucket] or 0) + value
    end
    return value
end

local function AwardEnemyCopper(run, enemy)
    if not run or not enemy then return 0 end
    local stats = EnsureRunTracking(run)
    local floor = math.max(1, math.floor(tonumber(run.floor) or 1))
    local danger = math.max(1, tonumber(enemy.dangerRating) or 1)
    local rank = string.lower(tostring(enemy.rank or "normal"))
    local rankMultiplier = RUN_COPPER_RANK_MULTIPLIER[rank] or 1
    local reward = math.max(1, math.floor(((floor * 20) + (danger * 15)) * rankMultiplier + 0.5))

    run.copper = (run.copper or 0) + reward
    stats.copperEarned = stats.copperEarned + reward
    return reward
end

local function RecordRunLoot(run, item)
    if not run or not item or item.empty then return end
    EnsureRunTracking(run)

    local key = tostring(item.studioItemId or item.id or item.name or "unknown")
    local amount = math.max(1, math.floor(tonumber(item.stackCount or item.quantity) or 1))
    local entry = run.lootSummary[key]
    if not entry then
        entry = {
            name = item.name or item.studioItemId or item.id or "Unknown Item",
            count = 0,
        }
        run.lootSummary[key] = entry
    end
    entry.count = entry.count + amount
end

local function AwardFloorClear(run, floorNumber)
    if not run then return false end
    EnsureRunTracking(run)

    local floor = math.max(1, math.floor(tonumber(floorNumber) or 1))
    if run.clearedFloors[floor] then
        return false
    end

    run.clearedFloors[floor] = true
    run.stats.floorsCleared = run.stats.floorsCleared + 1
    AddRunScore(run, "floor", RUN_SCORE.FLOOR_CLEAR)
    return true
end

local function ParseRunXpCurve(value)
    local costs = {}
    for token in string.gmatch(tostring(value or ""), "[^,%s]+") do
        local amount = tonumber(token)
        if amount and amount > 0 then
            costs[#costs + 1] = math.max(1, math.floor(amount + 0.5))
        end
    end

    if #costs == 0 then
        return CopyTable(DEFAULT_RUN_XP_CURVE)
    end

    return costs
end

local function GetRunProgression()
    local fallback = {
        xpPerDanger = 9,
        firstLevelXp = 80,
        levelGrowth = 1.10,
        maxRunLevel = 60,
        levelCosts = CopyTable(DEFAULT_RUN_XP_CURVE),
    }
    for _, record in ipairs(GA.StudioData and GA.StudioData.progression or {}) do
        if record.id == "run_xp" then
            return {
                xpPerDanger = math.max(1, tonumber(record.xpPerDanger) or fallback.xpPerDanger),
                firstLevelXp = math.max(1, tonumber(record.firstLevelXp) or fallback.firstLevelXp),
                levelGrowth = math.max(1, tonumber(record.levelGrowth) or fallback.levelGrowth),
                maxRunLevel = math.max(1, math.floor(tonumber(record.maxRunLevel) or fallback.maxRunLevel)),
                levelCosts = ParseRunXpCurve(record.xpCurve),
            }
        end
    end
    return fallback
end

local function GetRunXpRequired(run)
    local progression = run and run.progression or GetRunProgression()
    local levelsGained = math.max(0, tonumber(run and run.levelsGained) or 0)
    local levelCosts = progression.levelCosts or {}

    if levelsGained < #levelCosts then
        return math.max(1, tonumber(levelCosts[levelsGained + 1]) or progression.firstLevelXp or 100)
    end

    local baseCost = progression.firstLevelXp or 100
    local extraSteps = levelsGained
    if #levelCosts > 0 then
        baseCost = tonumber(levelCosts[#levelCosts]) or baseCost
        extraSteps = levelsGained - #levelCosts + 1
    end

    return math.max(1, math.floor(baseCost * (progression.levelGrowth ^ extraSteps) + 0.5))
end

local function GetClassAbilityIdSet(classId, level)
    local result = {}
    local normalizedClass = string.lower(tostring(classId or ""))
    local currentLevel = math.max(1, tonumber(level) or 1)
    for _, ability in ipairs(GA.StudioData and GA.StudioData.abilities or {}) do
        if string.lower(tostring(ability.classId or "")) == normalizedClass
            and (tonumber(ability.learnLevel) or 1) <= currentLevel then
            result[ability.id] = true
        end
    end
    return result
end

local function GetClassRunGrowth(classId)
    local normalizedClass = string.lower(tostring(classId or ""))
    for _, class in ipairs(GA.StudioData and GA.StudioData.classes or {}) do
        if string.lower(tostring(class.id or "")) == normalizedClass then
            return {
                resourceType = string.upper(tostring(class.resource or "NONE")),
                baseResourceMax = math.max(0, tonumber(class.resourceMax) or 0),
                hpPerLevel = math.max(0, tonumber(class.hpPerLevel) or 0),
                resourcePerLevel = math.max(0, tonumber(class.resourcePerLevel) or 0),
                basicAttackResourceGain = math.max(0, tonumber(class.basicAttackResourceGain) or 0),
            }
        end
    end

    return {
        resourceType = "NONE",
        baseResourceMax = 0,
        hpPerLevel = 0,
        resourcePerLevel = 0,
        basicAttackResourceGain = 0,
    }
end

local function GetStudioAbilityById(abilityId)
    for _, ability in ipairs(GA.StudioData and GA.StudioData.abilities or {}) do
        if ability.id == abilityId then
            return ability
        end
    end
    return nil
end

local function GetAbilityIconTexture(ability)
    if not ability then
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    end

    local configured = ability.icon
    if configured ~= nil and tostring(configured) ~= "" then
        local numeric = tonumber(configured)
        if numeric then return numeric end
        configured = tostring(configured)
        if string.find(configured, "\\", 1, true) then return configured end
        return "Interface\\Icons\\" .. configured
    end

    local spellName = ability.name
    if spellName and C_Spell and C_Spell.GetSpellTexture then
        local ok, texture = pcall(C_Spell.GetSpellTexture, spellName)
        if ok and texture then return texture end
    end
    if spellName and type(GetSpellTexture) == "function" then
        local ok, texture = pcall(GetSpellTexture, spellName)
        if ok and texture then return texture end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local POTION_BACKPACK_SLOTS = 20

local function IsRunPotion(item)
    if not item then return false end
    if string.upper(tostring(item.category or "")) ~= "CONSUMABLE"
        and tostring(item.itemType or "") ~= "Consumable" then
        return false
    end

    local subtype = string.lower(tostring(item.itemSubType or ""))
    return string.find(subtype, "potion", 1, true) ~= nil
end

local function CanUseRunPotionItem(run, item)
    if not run or not run.active or not IsRunPotion(item) then
        return false
    end

    local effect = string.upper(tostring(item.consumableEffect or "NONE"))
    local value = tonumber(item.effectValue) or 0
    if value <= 0 then return false end

    if effect == "HEAL_PERCENT" or effect == "HEAL_FLAT" then
        return (run.playerHealth or 0) < (run.playerMaxHealth or 0)
    end

    if effect == "RESOURCE" then
        return (run.resourceMax or 0) > 0
            and (run.resource or 0) < (run.resourceMax or 0)
    end

    return false
end

local function FindRunPotion(run, usableOnly)
    local fallbackSlot
    local fallbackItem

    for slotIndex = 1, POTION_BACKPACK_SLOTS do
        local item = run and run.backpack and run.backpack[slotIndex]
        if IsRunPotion(item) then
            if not fallbackItem then
                fallbackSlot = slotIndex
                fallbackItem = item
            end
            if CanUseRunPotionItem(run, item) then
                return slotIndex, item
            end
        end
    end

    if usableOnly then
        return nil, nil
    end
    return fallbackSlot, fallbackItem
end

local function CountRunPotionStacks(run, studioItemId)
    if not run or not studioItemId then return 0 end

    local total = 0
    for slotIndex = 1, POTION_BACKPACK_SLOTS do
        local item = run.backpack and run.backpack[slotIndex]
        if item and item.studioItemId == studioItemId and IsRunPotion(item) then
            total = total + math.max(1, math.floor(tonumber(item.stackCount) or 1))
        end
    end
    return total
end

local function BuildRoomRoleText(counts)
    counts = counts or {}

    local parts = {
        string.format("%d Combat", counts.COMBAT or 0),
        string.format("%d Treasure", counts.TREASURE or 0),
    }

    if (counts.ELITE or 0) > 0 then
        parts[#parts + 1] = string.format("%d Elite", counts.ELITE)
    end
    if (counts.SHRINE or 0) > 0 then
        parts[#parts + 1] = string.format("%d Shrine", counts.SHRINE)
    end
    if (counts.SHOP or 0) > 0 then
        parts[#parts + 1] = string.format("%d Shop", counts.SHOP)
    end
    if (counts.BOSS or 0) > 0 then
        parts[#parts + 1] = string.format("%d Boss", counts.BOSS)
    end

    return table.concat(parts, " / ")
end

local function BuildInitialRoomStates(floorMap)
    local states = {}

    for _, room in ipairs(floorMap and floorMap.rooms or {}) do
        local encounterRoom = room.role == "COMBAT"
            or room.role == "ELITE"
            or room.role == "BOSS"

        states[room.index] = {
            role = room.role,
            cleared = not encounterRoom,
            shrineUsed = false,
            eliteRewardSpawned = false,
            eliteRewardClaimed = false,
            bossRewardSpawned = false,
            bossRewardClaimed = false,
        }
    end

    return states
end

local function GetRoomByIndex(floorMap, roomIndex)
    if not floorMap or not roomIndex then
        return nil
    end

    for _, room in ipairs(floorMap.rooms or {}) do
        if room.index == roomIndex then
            return room
        end
    end

    return nil
end

local function IsBossAlive(run)
    for _, enemy in ipairs(run and run.enemies or {}) do
        if enemy.alive ~= false
            and (enemy.rank == "boss" or enemy.roomRole == "BOSS") then
            return true
        end
    end

    return false
end

local function IsDungeonExitLocked(run)
    return run
        and (run.floor or 1) >= 9
        and IsBossAlive(run)
end

local function MarkRoomCleared(run, roomIndex)
    if not run or not run.floorMap or not roomIndex then
        return
    end

    local room = GetRoomByIndex(run.floorMap, roomIndex)
    if not room or not room.center then
        return
    end

    local key = CellKey(room.center.x, room.center.y)
    run.floorMap.markers[key] = {
        text = "*",
        color = "green",
        kind = "roomCleared",
        roomIndex = roomIndex,
    }
end

local function SpawnEliteReward(run, roomIndex)
    if not run or not run.floorMap or not roomIndex then
        return
    end

    run.roomStates = run.roomStates or {}
    local state = run.roomStates[roomIndex]
    if not state or state.eliteRewardSpawned then
        return
    end

    local room = GetRoomByIndex(run.floorMap, roomIndex)
    if not room or not room.center then
        return
    end

    local key = CellKey(room.center.x, room.center.y)
    local objectId = "elite_cache"
    local objectDefinition = GA.GetDungeonObjectDefinition and GA:GetDungeonObjectDefinition(objectId)
    local loot = GA.RollDungeonObjectLoot and GA:RollDungeonObjectLoot(objectId, run.floor)
    if not loot then
        if objectDefinition and objectDefinition.lootTableId then
            loot = {
                empty = true,
                name = objectDefinition.name or "Elite Cache",
                objectId = objectId,
            }
        else
            loot = CopyTable(FALLBACK_CHEST_LOOT)
        end
    end

    run.floorMap.markers[key] = {
        text = objectDefinition and objectDefinition.marker or "$",
        color = "gold",
        kind = "chest",
        objectId = objectId,
        roomIndex = roomIndex,
        rewardType = "elite",
    }
    run.chestLoot = run.chestLoot or {}
    run.chestLoot[key] = loot
    state.eliteRewardSpawned = true
end

local function SpawnBossReward(run, roomIndex)
    if not run or not run.floorMap or not roomIndex then
        return
    end

    run.roomStates = run.roomStates or {}
    local state = run.roomStates[roomIndex]
    if not state or state.bossRewardSpawned then
        return
    end

    local room = GetRoomByIndex(run.floorMap, roomIndex)
    if not room or not room.center then
        return
    end

    local key = CellKey(room.center.x, room.center.y)
    local objectId = "boss_cache"
    local objectDefinition = GA.GetDungeonObjectDefinition and GA:GetDungeonObjectDefinition(objectId)
    local loot = GA.RollDungeonObjectLoot and GA:RollDungeonObjectLoot(objectId, run.floor)
    if not loot then
        if objectDefinition and objectDefinition.lootTableId then
            loot = {
                empty = true,
                name = objectDefinition.name or "Boss Cache",
                objectId = objectId,
            }
        else
            loot = CopyTable(FALLBACK_CHEST_LOOT)
        end
    end

    run.floorMap.markers[key] = {
        text = objectDefinition and objectDefinition.marker or "$",
        color = "gold",
        kind = "chest",
        objectId = objectId,
        roomIndex = roomIndex,
        rewardType = "boss",
    }
    run.chestLoot = run.chestLoot or {}
    run.chestLoot[key] = loot
    state.bossRewardSpawned = true
end

local function UpdateEncounterRoomClear(self, run, defeatedEnemy)
    if not run or not defeatedEnemy or not defeatedEnemy.roomIndex then
        return
    end

    local roomIndex = defeatedEnemy.roomIndex
    local roomRole = defeatedEnemy.roomRole
    if roomRole ~= "COMBAT" and roomRole ~= "ELITE" and roomRole ~= "BOSS" then
        return
    end

    for _, enemy in ipairs(run.enemies or {}) do
        if enemy.alive ~= false and enemy.roomIndex == roomIndex then
            return
        end
    end

    run.roomStates = run.roomStates or {}
    local state = run.roomStates[roomIndex] or { role = roomRole }
    run.roomStates[roomIndex] = state

    if state.cleared then
        return
    end

    state.cleared = true

    if roomRole == "ELITE" then
        SpawnEliteReward(run, roomIndex)
        self:AddCombatLog("ELITE ROOM CLEARED - a reward cache appears.", "system")
    elseif roomRole == "BOSS" then
        self:AddCombatLog("BOSS ROOM CLEARED.", "system")
    else
        MarkRoomCleared(run, roomIndex)
        self:AddCombatLog("ROOM CLEARED.", "system")
    end
end

local function GetEnemyDisplayName(enemy)
    if not enemy then
        return "Enemy"
    end

    local name = enemy.name or "Enemy"
    local rank = enemy.rank or "normal"

    if rank == "veteran" then
        return "Veteran " .. name
    elseif rank == "elite" then
        return "Elite " .. name
    elseif rank == "boss" then
        return "Boss " .. name
    end

    return name
end

local function GenerateFloorSetup(floorGenerator, enemyGenerator, playerLevel, floorNumber, gearPressure, floorMap, difficulty)
    local walkableTiles = CountWalkableTiles()
    local densityProfile = floorGenerator:RollDensityProfile()
    local enemyCount, baseEnemyCount = floorGenerator:CalculateEnemyCount(
        walkableTiles,
        floorNumber,
        densityProfile
    )

    local archetypePlan, archetypeCounts = floorGenerator:CreateArchetypePlan(
        enemyCount,
        floorNumber,
        floorMap and floorMap.ecosystemId
    )
    local rankPlan, rankCounts = floorGenerator:CreateRankPlan(
        enemyCount,
        floorNumber
    )

    local floorEnemies = CreateFloorEnemies(
        enemyGenerator,
        playerLevel,
        floorNumber,
        gearPressure,
        archetypePlan,
        rankPlan,
        floorMap,
        difficulty
    )

    local actualRankCounts = CountEnemyRanks(floorEnemies)

    return {
        walkableTiles = walkableTiles,
        densityProfile = densityProfile,
        baseEnemyCount = baseEnemyCount,
        enemyCount = #floorEnemies,
        enemyComposition = archetypeCounts,
        enemyRankComposition = actualRankCounts,
        enemies = floorEnemies,
    }
end

local function SetCharacterVisual(texture, character)
    if not texture then
        return
    end

    local currentKey = GA.GetCurrentCharacterKey and GA:GetCurrentCharacterKey()
    if character and character.key == currentKey then
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        SetPortraitTexture(texture, "player")
        return
    end

    if character and (character.isArcadeGenerated or character.sourceType == "arcade") then
        local race = GA.GetStudioRaceDefinition and GA:GetStudioRaceDefinition(character.raceId)
        local raceIcon = race and race.icon
        texture:SetTexture(
            GA.ResolveStudioIconTexture
                and GA:ResolveStudioIconTexture(raceIcon, "Interface\\Icons\\INV_Misc_QuestionMark")
                or "Interface\\Icons\\INV_Misc_QuestionMark"
        )
        texture:SetTexCoord(0.06, 0.94, 0.06, 0.94)
        return
    end

    local coords = character and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[character.classFile]
    if coords then
        texture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

local function SetGeneratorClassVisual(texture, classId)
    if not texture then return end
    local classFile = string.upper(tostring(classId or ""))
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
    if coords then
        texture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

local function CreateGrid(parent)
    local size = DUNGEON_TILE_SIZE
    local gap = DUNGEON_TILE_GAP
    local stride = size + gap
    local gridWidth = (VIEWPORT_WIDTH * size) + ((VIEWPORT_WIDTH - 1) * gap)
    local gridHeight = (VIEWPORT_HEIGHT * size) + ((VIEWPORT_HEIGHT - 1) * gap)

    local grid = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    grid:SetSize(gridWidth, gridHeight)
    grid:SetPoint("TOP", 0, -28)
    ApplyBackdrop(grid, { 0.018, 0.016, 0.013, 1 }, { 0.16, 0.12, 0.05, 1 })

    -- Creature art lives on a dedicated overlay layer for clean z-order.
    -- Source art stays 128x128, while both physical tiles and rendered
    -- creature sprites are 96x96 so sprites remain fully contained.
    local spriteLayer = CreateFrame("Frame", nil, grid)
    spriteLayer:SetAllPoints(grid)
    spriteLayer:SetFrameLevel(grid:GetFrameLevel() + 20)
    grid.spriteLayer = spriteLayer
    grid.creatureSpriteSourceSize = CREATURE_SPRITE_SOURCE_SIZE
    grid.creatureSpriteRenderSize = CREATURE_SPRITE_RENDER_SIZE

    grid.cells = {}

    for row = 1, VIEWPORT_HEIGHT do
        for col = 1, VIEWPORT_WIDTH do
            local cell = CreateFrame("Frame", nil, grid, "BackdropTemplate")
            cell:SetSize(size, size)
            cell:SetPoint("TOPLEFT", (col - 1) * stride, -((row - 1) * stride))

            ApplyBackdrop(cell, { 0.055, 0.048, 0.038, 1 }, { 0.09, 0.075, 0.055, 1 })

            local terrainTexture = cell:CreateTexture(nil, "ARTWORK", nil, -8)
            terrainTexture:SetAllPoints(cell)
            terrainTexture:SetTexCoord(0, 1, 0, 1)
            terrainTexture:Hide()

            local lootIcon = spriteLayer:CreateTexture(nil, "OVERLAY", nil, 1)
            lootIcon:SetSize(50, 50)
            lootIcon:SetPoint("CENTER", cell, "CENTER", 0, 0)
            lootIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            lootIcon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
            lootIcon:Hide()

            local eventIcon = spriteLayer:CreateTexture(nil, "OVERLAY", nil, 1)
            eventIcon:SetSize(48, 48)
            eventIcon:SetPoint("CENTER", cell, "CENTER", 0, 0)
            eventIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            eventIcon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
            eventIcon:Hide()

            local enemyIcon = spriteLayer:CreateTexture(nil, "OVERLAY", nil, 2)
            enemyIcon:SetSize(CREATURE_SPRITE_RENDER_SIZE, CREATURE_SPRITE_RENDER_SIZE)
            enemyIcon:SetPoint("CENTER", cell, "CENTER", 0, 0)
            enemyIcon:SetTexture(KOBOLD_TEXTURE)
            enemyIcon:SetTexCoord(0, 1, 0, 1)
            enemyIcon:Hide()

            local enemyHealthBackdrop = CreateFrame("Frame", nil, spriteLayer, "BackdropTemplate")
            enemyHealthBackdrop:SetSize(74, 8)
            enemyHealthBackdrop:SetPoint("TOP", cell, "TOP", 0, -4)
            enemyHealthBackdrop:SetFrameLevel(spriteLayer:GetFrameLevel() + 8)
            ApplyBackdrop(enemyHealthBackdrop, { 0.015, 0.012, 0.010, 0.95 }, { 0.12, 0.09, 0.07, 1 })
            enemyHealthBackdrop:Hide()

            local enemyHealthBar = CreateFrame("StatusBar", nil, enemyHealthBackdrop)
            enemyHealthBar:SetPoint("TOPLEFT", 1, -1)
            enemyHealthBar:SetPoint("BOTTOMRIGHT", -1, 1)
            enemyHealthBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
            enemyHealthBar:SetStatusBarColor(COLORS.red[1], COLORS.red[2], COLORS.red[3], 1)
            enemyHealthBar:SetMinMaxValues(0, 1)
            enemyHealthBar:SetValue(1)

            local enemySkillIcon = spriteLayer:CreateTexture(nil, "OVERLAY", nil, 4)
            enemySkillIcon:SetSize(22, 22)
            enemySkillIcon:SetPoint("TOPRIGHT", cell, "TOPRIGHT", -5, -14)
            enemySkillIcon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
            enemySkillIcon:Hide()

            local marker = CreateText(cell, "GameFontNormalHuge", "")
            marker:SetPoint("CENTER")

            grid.cells[CellKey(col, row)] = {
                frame = cell,
                terrainTexture = terrainTexture,
                marker = marker,
                lootIcon = lootIcon,
                eventIcon = eventIcon,
                enemyIcon = enemyIcon,
                enemyHealthBackdrop = enemyHealthBackdrop,
                enemyHealthBar = enemyHealthBar,
                enemySkillIcon = enemySkillIcon,
                worldX = col,
                worldY = row,
            }
        end
    end

    return grid
end

local function GetSetupItemQualityColor(quality)
    local q = tonumber(quality) or 1
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if color then
        return color.r or 1, color.g or 1, color.b or 1
    end

    local fallback = {
        [0] = { 0.62, 0.62, 0.62 },
        [1] = { 1.00, 1.00, 1.00 },
        [2] = { 0.12, 1.00, 0.00 },
        [3] = { 0.00, 0.44, 0.87 },
        [4] = { 0.64, 0.21, 0.93 },
        [5] = { 1.00, 0.50, 0.00 },
        [6] = { 0.90, 0.80, 0.50 },
        [7] = { 0.00, 0.80, 1.00 },
    }
    local rgb = fallback[q] or fallback[1]
    return rgb[1], rgb[2], rgb[3]
end

local function GetSetupWeaponSlotLabel(item)
    local equipLoc = item and item.equipLoc
    if equipLoc == "INVTYPE_2HWEAPON" then return "Two-Hand" end
    if equipLoc == "INVTYPE_WEAPONMAINHAND" then return "Main Hand" end
    if equipLoc == "INVTYPE_WEAPONOFFHAND" then return "Off Hand" end
    if equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT" then return "Ranged" end
    return "One-Hand"
end

local function GetSetupWeaponTypeLabel(item, weapon)
    local subtype = item and item.itemSubType
    if subtype and subtype ~= "" then return subtype end

    local style = weapon and tostring(weapon.style or "")
    if style == "" then return "Weapon" end
    return style:sub(1, 1):upper() .. style:sub(2):lower()
end

local function GetSetupWeaponSpeedSeconds(weapon)
    local speedKey = string.upper(tostring(weapon and weapon.speed or "NORMAL"))
    return GA.WEAPON_SPEED_SECONDS and GA.WEAPON_SPEED_SECONDS[speedKey] or 2.4
end

local function ShowSetupWeaponTooltip(button)
    local item = button and button.gaItem
    local weapon = button and button.gaWeapon
    if not item or not weapon then return end

    local r, g, b = GetSetupItemQualityColor(item.quality)
    local name = item.name or weapon.sourceName or "Weapon"
    local itemLevel = tonumber(item.itemLevel or weapon.itemLevel) or 1
    local slotLabel = GetSetupWeaponSlotLabel(item)
    local typeLabel = GetSetupWeaponTypeLabel(item, weapon)
    local speed = GetSetupWeaponSpeedSeconds(weapon)

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(name, r, g, b)
    GameTooltip:AddLine("Item Level " .. tostring(itemLevel), 1.00, 0.82, 0.20)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(slotLabel, typeLabel, 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(
        string.format("%d - %d Damage", tonumber(weapon.damageMin) or 0, tonumber(weapon.damageMax) or 0),
        string.format("Speed %.2f", speed),
        1, 1, 1,
        1, 1, 1
    )
    GameTooltip:AddLine(string.format("Range %d", tonumber(weapon.range) or 1), 1, 1, 1)

    if (tonumber(weapon.attackPower) or 0) > 0 then
        GameTooltip:AddLine(string.format("+%d Attack Power", tonumber(weapon.attackPower) or 0), 0.15, 1.00, 0.15)
    end

    if weapon.traitName then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Equip: " .. tostring(weapon.traitName), 0.15, 1.00, 0.15)
        if weapon.traitDescription and weapon.traitDescription ~= "" then
            GameTooltip:AddLine(weapon.traitDescription, 0.15, 1.00, 0.15, true)
        end
    end

    if item.buildProfile and item.buildProfile ~= "" and item.buildProfile ~= "NONE" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Build: " .. tostring(item.buildProfile), 1.00, 0.82, 0.20)
    end

    if (tonumber(item.requiredLevel) or 1) > 1 then
        GameTooltip:AddLine(
            string.format("Requires Run Level %d", tonumber(item.requiredLevel) or 1),
            1.00, 0.35, 0.30
        )
    end

    if item.baselineLocked then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Baseline item - locked to this hero", 0.62, 0.62, 0.62)
    elseif item.loadoutOverride or item.stashEligible then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Extracted loadout item", 0.35, 0.85, 1.00)
    end

    if item.price ~= nil then
        GameTooltip:AddLine("Sell value " .. FormatCopperValue(math.floor((tonumber(item.price) or 0) * 0.5)), 1.00, 0.82, 0.20)
    end
    GameTooltip:Show()
end

function GA:CreateDungeonRunPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)
    page:Hide()
    self.DungeonRunPage = page

    local title = CreateText(page, "GameFontNormalHuge", "DUNGEON RUN")
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

    local subtitle = CreateText(page, "GameFontHighlightSmall", "LOOTER ROGUELIKE  -  9 FLOORS  -  EXTRACT LOOT ON VICTORY")
    subtitle:SetPoint("TOPRIGHT", -18, -22)
    subtitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local body = CreateFrame("Frame", nil, page)
    body:SetPoint("TOPLEFT", 18, -58)
    body:SetPoint("BOTTOMRIGHT", -18, 84)

    local left = CreateFrame("Frame", nil, body, "BackdropTemplate")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(182)
    ApplyBackdrop(left, { 0.050, 0.043, 0.034, 1 }, COLORS.goldDim)

    local statsTitle = CreateText(left, "GameFontNormalSmall", "RUN STATS")
    statsTitle:SetPoint("TOPLEFT", 12, -14)
    statsTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.DungeonStatsTitle = statsTitle

    self.DungeonHealth, self.DungeonHealthLabel = CreateStatRow(left, "HEALTH", "--", -38)
    self.DungeonPower, self.DungeonPowerLabel = CreateStatRow(left, "WEAPON", "--", -62)
    self.DungeonDodge, self.DungeonDodgeLabel = CreateStatRow(left, "DODGE", "--", -86)
    self.DungeonResource, self.DungeonResourceLabel = CreateStatRow(left, "RESOURCE", "--", -110)
    self.DungeonResource:Hide()
    self.DungeonResourceLabel:Hide()

    local gearTitle = CreateText(left, "GameFontNormalSmall", "WOW GEAR INPUT")
    gearTitle:SetPoint("TOPLEFT", 12, -126)
    gearTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local runPortraitFrame = CreateFrame("Frame", nil, left, "BackdropTemplate")
    runPortraitFrame:SetSize(158, 92)
    runPortraitFrame:SetPoint("TOPLEFT", 12, -14)
    ApplyBackdrop(runPortraitFrame, { 0.035, 0.030, 0.024, 1 }, COLORS.goldDim)
    runPortraitFrame:Hide()
    self.DungeonRunPortraitFrame = runPortraitFrame

    local runPortraitBorder = CreateFrame("Frame", nil, runPortraitFrame, "BackdropTemplate")
    runPortraitBorder:SetSize(64, 64)
    runPortraitBorder:SetPoint("LEFT", 10, 0)
    ApplyBackdrop(runPortraitBorder, { 0.02, 0.02, 0.02, 1 }, COLORS.gold)

    local runPortrait = runPortraitBorder:CreateTexture(nil, "ARTWORK")
    runPortrait:SetPoint("TOPLEFT", 2, -2)
    runPortrait:SetPoint("BOTTOMRIGHT", -2, 2)
    runPortrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    self.DungeonRunPortrait = runPortrait

    local runPortraitName = CreateText(runPortraitFrame, "GameFontNormal", "")
    runPortraitName:SetPoint("TOPLEFT", runPortraitBorder, "TOPRIGHT", 8, -8)
    runPortraitName:SetPoint("RIGHT", runPortraitFrame, "RIGHT", -8, 0)
    runPortraitName:SetJustifyH("LEFT")
    runPortraitName:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    self.DungeonRunPortraitName = runPortraitName

    local runPortraitMeta = CreateText(runPortraitFrame, "GameFontHighlightSmall", "")
    runPortraitMeta:SetPoint("TOPLEFT", runPortraitName, "BOTTOMLEFT", 0, -6)
    runPortraitMeta:SetPoint("RIGHT", runPortraitFrame, "RIGHT", -8, 0)
    runPortraitMeta:SetJustifyH("LEFT")
    runPortraitMeta:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonRunPortraitMeta = runPortraitMeta

    local gearHint = CreateText(left, "GameFontHighlightSmall", "Main hand")
    gearHint:SetPoint("TOPLEFT", 12, -148)
    gearHint:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local itemIconButton = CreateFrame("Button", nil, left, "BackdropTemplate")
    itemIconButton:SetSize(42, 42)
    itemIconButton:SetPoint("TOPLEFT", 12, -168)
    ApplyBackdrop(itemIconButton, { 0.025, 0.022, 0.018, 1 }, COLORS.goldDim)

    local itemIcon = itemIconButton:CreateTexture(nil, "ARTWORK")
    itemIcon:SetPoint("TOPLEFT", 2, -2)
    itemIcon:SetPoint("BOTTOMRIGHT", -2, 2)
    itemIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    self.DungeonMainHandIcon = itemIcon

    itemIconButton:SetScript("OnEnter", function(button)
        if GA.DungeonMainHandLink then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(GA.DungeonMainHandLink)
            GameTooltip:Show()
        end
    end)
    itemIconButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local itemName = CreateText(left, "GameFontNormalSmall", "Scanning...")
    itemName:SetPoint("TOPLEFT", itemIconButton, "TOPRIGHT", 8, -2)
    itemName:SetPoint("RIGHT", left, "RIGHT", -8, 0)
    itemName:SetJustifyH("LEFT")
    itemName:SetWordWrap(true)
    itemName:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    self.DungeonMainHandName = itemName

    local itemLevel = CreateText(left, "GameFontHighlightSmall", "")
    itemLevel:SetPoint("TOPLEFT", itemIconButton, "TOPRIGHT", 8, -22)
    itemLevel:SetPoint("RIGHT", left, "RIGHT", -8, 0)
    itemLevel:SetJustifyH("LEFT")
    itemLevel:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.DungeonMainHandLevel = itemLevel

    local itemMeta = CreateText(left, "GameFontDisableSmall", "")
    itemMeta:SetPoint("TOPLEFT", 12, -218)
    itemMeta:SetPoint("RIGHT", left, "RIGHT", -8, 0)
    itemMeta:SetJustifyH("LEFT")
    itemMeta:SetWordWrap(true)
    itemMeta:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonMainHandMeta = itemMeta
    self.DungeonGearWidgets = {
        gearTitle,
        gearHint,
        itemIconButton,
        itemName,
        itemLevel,
        itemMeta,
    }

    local conversionTitle = CreateText(left, "GameFontNormalSmall", "ARCADE CONVERSION")
    conversionTitle:SetPoint("TOPLEFT", 12, -252)
    conversionTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local arcadeDamage = CreateText(left, "GameFontNormal", "Damage --")
    arcadeDamage:SetPoint("TOPLEFT", 12, -276)
    arcadeDamage:SetPoint("RIGHT", left, "RIGHT", -10, 0)
    arcadeDamage:SetJustifyH("LEFT")
    arcadeDamage:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    self.DungeonArcadeDamage = arcadeDamage

    local arcadeStyle = CreateText(left, "GameFontHighlightSmall", "")
    arcadeStyle:SetPoint("TOPLEFT", 12, -298)
    arcadeStyle:SetPoint("RIGHT", left, "RIGHT", -10, 0)
    arcadeStyle:SetJustifyH("LEFT")
    arcadeStyle:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonArcadeStyle = arcadeStyle

    local arcadeTraitName = CreateText(left, "GameFontNormalSmall", "")
    arcadeTraitName:SetPoint("TOPLEFT", 12, -326)
    arcadeTraitName:SetPoint("RIGHT", left, "RIGHT", -10, 0)
    arcadeTraitName:SetJustifyH("LEFT")
    arcadeTraitName:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.DungeonArcadeTraitName = arcadeTraitName

    local arcadeTraitDesc = CreateText(left, "GameFontDisableSmall", "")
    arcadeTraitDesc:SetPoint("TOPLEFT", 12, -346)
    arcadeTraitDesc:SetWidth(156)
    arcadeTraitDesc:SetJustifyH("LEFT")
    arcadeTraitDesc:SetJustifyV("TOP")
    arcadeTraitDesc:SetWordWrap(true)
    arcadeTraitDesc:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonArcadeTraitDesc = arcadeTraitDesc
    self.DungeonConversionWidgets = {
        conversionTitle,
        arcadeDamage,
        arcadeStyle,
        arcadeTraitName,
        arcadeTraitDesc,
    }


    local right = CreateFrame("Frame", nil, body, "BackdropTemplate")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(182)
    ApplyBackdrop(right, { 0.050, 0.043, 0.034, 1 }, COLORS.goldDim)

    local enemyCard = CreateFrame("Frame", nil, right, "BackdropTemplate")
    enemyCard:SetSize(158, 92)
    enemyCard:SetPoint("TOPLEFT", 12, -14)
    ApplyBackdrop(enemyCard, { 0.035, 0.030, 0.024, 1 }, COLORS.goldDim)
    enemyCard:Hide()
    self.DungeonEnemyCard = enemyCard

    local enemyIconBorder = CreateFrame("Frame", nil, enemyCard, "BackdropTemplate")
    enemyIconBorder:SetSize(64, 64)
    enemyIconBorder:SetPoint("LEFT", 10, 0)
    ApplyBackdrop(enemyIconBorder, { 0.02, 0.02, 0.02, 1 }, COLORS.gold)

    local enemyPortrait = enemyIconBorder:CreateTexture(nil, "ARTWORK")
    enemyPortrait:SetPoint("TOPLEFT", 2, -2)
    enemyPortrait:SetPoint("BOTTOMRIGHT", -2, 2)
    enemyPortrait:SetTexture(KOBOLD_PORTRAIT_ICON)
    enemyPortrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    self.DungeonEnemyPortrait = enemyPortrait

    local enemyName = CreateText(enemyCard, "GameFontNormal", "Kobold")
    enemyName:SetPoint("TOPLEFT", enemyIconBorder, "TOPRIGHT", 8, -8)
    enemyName:SetPoint("RIGHT", enemyCard, "RIGHT", -8, 0)
    enemyName:SetJustifyH("LEFT")
    enemyName:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    self.DungeonEnemyName = enemyName

    local enemyHealth = CreateText(enemyCard, "GameFontHighlightSmall", "")
    enemyHealth:SetPoint("TOPLEFT", enemyName, "BOTTOMLEFT", 0, -6)
    enemyHealth:SetPoint("RIGHT", enemyCard, "RIGHT", -8, 0)
    enemyHealth:SetJustifyH("LEFT")
    enemyHealth:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
    self.DungeonEnemyHealth = enemyHealth

    local enemyDanger = CreateText(enemyCard, "GameFontDisableSmall", "")
    enemyDanger:SetPoint("TOPLEFT", enemyHealth, "BOTTOMLEFT", 0, -4)
    enemyDanger:SetPoint("RIGHT", enemyCard, "RIGHT", -8, 0)
    enemyDanger:SetJustifyH("LEFT")
    enemyDanger:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonEnemyDanger = enemyDanger

    local runTitle = CreateText(right, "GameFontNormalSmall", "RUN")
    runTitle:SetPoint("TOPLEFT", 12, -126)
    runTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.DungeonRunTitle = runTitle

    self.DungeonFloorValue, self.DungeonFloorLabel = CreateStatRow(right, "FLOOR", "1 / 9", -150)
    self.DungeonLevelValue, self.DungeonLevelLabel = CreateStatRow(right, "LEVEL", "--", -174)
    self.DungeonXpValue, self.DungeonXpLabel = CreateStatRow(right, "XP", "--", -198)
    self.DungeonScoreValue, self.DungeonScoreLabel = CreateStatRow(right, "SCORE", "0", -222)
    self.DungeonTurnsValue, self.DungeonTurnsLabel = CreateStatRow(right, "TURNS", "0", -246)
    self.DungeonCopperValue, self.DungeonCopperLabel = CreateStatRow(right, "COPPER", "0c", -270)

    local quickTitle = CreateText(right, "GameFontNormalSmall", "QUICK ACCESS")
    quickTitle:SetPoint("TOPLEFT", 12, -294)
    quickTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.DungeonQuickAccessTitle = quickTitle

    local function CreateQuickAccessButton(parent, x, iconTexture, labelText, tooltipText, onClick)
        local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
        button:SetSize(72, 62)
        button:SetPoint("TOPLEFT", x, -314)
        ApplyBackdrop(button, { 0.035, 0.030, 0.024, 1 }, COLORS.goldDim)

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetSize(38, 38)
        icon:SetPoint("TOP", 0, -6)
        icon:SetTexture(iconTexture)
        icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
        button.icon = icon

        local label = CreateText(button, "GameFontNormalSmall", labelText)
        label:SetPoint("BOTTOM", 0, 5)
        label:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
        button.label = label

        button:SetScript("OnClick", onClick)
        button:SetScript("OnEnter", function(selfButton)
            selfButton:SetBackdropBorderColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1)
            GameTooltip:SetOwner(selfButton, "ANCHOR_LEFT")
            GameTooltip:SetText(selfButton.gaTooltipTitle or labelText, 1, 0.82, 0.2)
            GameTooltip:AddLine(selfButton.gaTooltipText or tooltipText, 0.9, 0.9, 0.9, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function(selfButton)
            selfButton:SetBackdropBorderColor(COLORS.goldDim[1], COLORS.goldDim[2], COLORS.goldDim[3], 1)
            GameTooltip:Hide()
        end)
        return button
    end

    self.DungeonCharacterSheetButton = CreateQuickAccessButton(
        right,
        12,
        "Interface\\Icons\\INV_Misc_Book_09",
        "CHARACTER",
        "Open the GoblinArcade character sheet.",
        function()
            GA:CloseSpellbook()
            GA:ToggleCharacterSheet()
        end
    )

    self.DungeonQuickSpellbookButton = CreateQuickAccessButton(
        right,
        98,
        "Interface\\Icons\\INV_Misc_Book_11",
        "SPELLBOOK",
        "Open the paged GoblinArcade spellbook.",
        function()
            if GA.CharacterSheetFrame then
                GA.CharacterSheetFrame:Hide()
                GA:CancelCharacterItemDrag()
            end
            GA:ToggleSpellbook()
        end
    )
    self.DungeonSpellbookButton = self.DungeonQuickSpellbookButton

    self.DungeonFloorAccessButton = CreateQuickAccessButton(
        right,
        55,
        "Interface\\Icons\\Achievement_Dungeon_ClassicDungeonMaster",
        "STAIRS",
        "Use the stairs on the current tile.",
        function()
            GA:UseDungeonFloorAccess()
        end
    )
    self.DungeonFloorAccessButton:ClearAllPoints()
    self.DungeonFloorAccessButton:SetPoint("TOP", right, "TOP", 0, -384)
    self.DungeonFloorAccessButton:Hide()

    local miniMapLabel = CreateText(right, "GameFontNormalSmall", "MAP")
    miniMapLabel:SetPoint("BOTTOMLEFT", 12, 224)
    miniMapLabel:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    miniMapLabel:Hide()
    self.DungeonMiniMapLabel = miniMapLabel

    local miniMap = CreateFrame("Frame", nil, right, "BackdropTemplate")
    miniMap:SetSize(158, 158)
    miniMap:SetPoint("BOTTOM", 0, 60)
    ApplyBackdrop(miniMap, { 0.015, 0.013, 0.011, 1 }, COLORS.goldDim)
    miniMap:Hide()
    self.DungeonMiniMap = miniMap

    local miniGrid = CreateFrame("Frame", nil, miniMap)
    miniGrid:SetSize(150, 150)
    miniGrid:SetPoint("CENTER")
    miniMap.grid = miniGrid
    miniMap.cells = {}

    local miniCellSize = 6
    for mapY = 1, GRID_HEIGHT do
        for mapX = 1, GRID_WIDTH do
            local miniCell = miniGrid:CreateTexture(nil, "ARTWORK")
            miniCell:SetSize(miniCellSize, miniCellSize)
            miniCell:SetPoint(
                "TOPLEFT",
                (mapX - 1) * miniCellSize,
                -((mapY - 1) * miniCellSize)
            )
            miniCell:SetColorTexture(0.005, 0.005, 0.005, 1)
            miniMap.cells[CellKey(mapX, mapY)] = {
                texture = miniCell,
                state = "unseen",
            }
        end
    end

    local begin = CreateFlatButton(right, "BEGIN RUN", 158, 36)
    begin:SetPoint("BOTTOM", 0, 12)
    begin:SetEnabled(false)
    begin.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    begin:SetScript("OnClick", function()
        if GA.RunState and GA.RunState.active then
            GA:OpenRunControlMenu()
        else
            GA:BeginDungeonRun()
        end
    end)
    self.DungeonBeginButton = begin

    local center = CreateFrame("Frame", nil, body, "BackdropTemplate")
    center:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0)
    center:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", -8, 0)
    ApplyBackdrop(center, { 0.040, 0.035, 0.028, 1 }, COLORS.goldDim)

    local floor = CreateText(center, "GameFontNormalSmall", "FLOOR 1  -  THE TEST CELLAR  -  25x25")
    floor:SetPoint("TOP", 0, -10)
    floor:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.DungeonFloorTitle = floor

    self.DungeonGrid = CreateGrid(center)

    local eventFrame = CreateFrame("Frame", nil, center, "BackdropTemplate")
    eventFrame:SetSize(620, 360)
    eventFrame:SetPoint("CENTER", center, "CENTER", 0, 0)
    eventFrame:SetFrameLevel(center:GetFrameLevel() + 54)
    eventFrame:EnableMouse(true)
    ApplyBackdrop(eventFrame, { 0.025, 0.021, 0.017, 0.99 }, COLORS.gold)
    eventFrame:Hide()
    self.DungeonEventFrame = eventFrame

    local eventIcon = eventFrame:CreateTexture(nil, "ARTWORK")
    eventIcon:SetSize(52, 52)
    eventIcon:SetPoint("TOPLEFT", 18, -18)
    eventIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    eventIcon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    self.DungeonEventIcon = eventIcon

    local eventTitle = CreateText(eventFrame, "GameFontNormalLarge", "DUNGEON EVENT")
    eventTitle:SetPoint("TOPLEFT", 84, -20)
    eventTitle:SetPoint("TOPRIGHT", -18, -20)
    eventTitle:SetJustifyH("LEFT")
    eventTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.DungeonEventTitle = eventTitle

    local eventText = CreateText(eventFrame, "GameFontHighlightSmall", "")
    eventText:SetPoint("TOPLEFT", 84, -50)
    eventText:SetWidth(510)
    eventText:SetJustifyH("LEFT")
    eventText:SetJustifyV("TOP")
    eventText:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    self.DungeonEventText = eventText

    self.DungeonEventOptionButtons = {}
    for index = 1, 4 do
        local button = CreateFlatButton(eventFrame, tostring(index) .. "  OPTION", 570, 46)
        button:SetPoint("TOP", eventFrame, "TOP", 0, -120 - ((index - 1) * 54))
        button:SetScript("OnClick", function()
            GA:ChooseDungeonEventOption(index)
        end)
        button:SetScript("OnEnter", function(selfButton)
            local option = selfButton.gaEventOption
            if option then
                GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
                GameTooltip:SetText(option.name or "Event Option", 1, 0.82, 0.2)
                local hint = option.description
                if hint == nil or tostring(hint) == "" then
                    hint = GetDungeonEventOptionHint(option)
                end
                GameTooltip:AddLine(tostring(hint), 0.85, 0.82, 0.75, true)
                if selfButton.gaEventCostText and selfButton.gaEventCostText ~= "" then
                    GameTooltip:AddLine(selfButton.gaEventCostText, 1.00, 0.82, 0.20, true)
                end
                if selfButton.gaEventUnavailableReason and selfButton.gaEventUnavailableReason ~= "" then
                    GameTooltip:AddLine(selfButton.gaEventUnavailableReason, 1.00, 0.30, 0.25, true)
                end
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        button:Hide()
        self.DungeonEventOptionButtons[index] = button
    end

    local shrineFrame = CreateFrame("Frame", nil, center, "BackdropTemplate")
    shrineFrame:SetSize(520, 190)
    shrineFrame:SetPoint("CENTER", center, "CENTER", 0, 0)
    shrineFrame:SetFrameLevel(center:GetFrameLevel() + 50)
    shrineFrame:EnableMouse(true)
    ApplyBackdrop(shrineFrame, { 0.025, 0.021, 0.017, 0.98 }, COLORS.gold)
    shrineFrame:Hide()
    self.DungeonShrineFrame = shrineFrame

    local shrineTitle = CreateText(shrineFrame, "GameFontNormalLarge", "FORGOTTEN SHRINE")
    shrineTitle:SetPoint("TOP", 0, -18)
    shrineTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local shrineText = CreateText(
        shrineFrame,
        "GameFontHighlightSmall",
        "Choose one blessing. Each shrine can be used once."
    )
    shrineText:SetPoint("TOP", shrineTitle, "BOTTOM", 0, -10)
    shrineText:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

    local restoreDefinition = GetStudioShrineChoice("restore") or {}
    local blessingDefinition = GetStudioShrineChoice("blessing") or {}
    local sacrificeDefinition = GetStudioShrineChoice("sacrifice") or {}

    local restoreButton = CreateFlatButton(
        shrineFrame,
        "1  " .. string.upper(restoreDefinition.name or "RESTORE"),
        148,
        40
    )
    restoreButton:SetPoint("BOTTOMLEFT", 16, 18)
    restoreButton:SetScript("OnClick", function()
        GA:ChooseShrineGift("restore")
    end)

    local blessingButton = CreateFlatButton(
        shrineFrame,
        "2  " .. string.upper(blessingDefinition.name or "BLESSING"),
        148,
        40
    )
    blessingButton:SetPoint("BOTTOM", 0, 18)
    blessingButton:SetScript("OnClick", function()
        GA:ChooseShrineGift("blessing")
    end)

    local sacrificeButton = CreateFlatButton(
        shrineFrame,
        "3  " .. string.upper(sacrificeDefinition.name or "SACRIFICE"),
        148,
        40
    )
    sacrificeButton:SetPoint("BOTTOMRIGHT", -16, 18)
    sacrificeButton:SetScript("OnClick", function()
        GA:ChooseShrineGift("sacrifice")
    end)

    local restorePercent = tonumber(restoreDefinition.value) or 25
    local blessingPercent = tonumber(blessingDefinition.value) or 5
    local sacrificePercent = tonumber(sacrificeDefinition.value) or 15
    local sacrificeScore = tonumber(sacrificeDefinition.secondaryValue) or 150

    local restoreDesc = CreateText(
        shrineFrame,
        "GameFontDisableSmall",
        string.format("HEAL %d%% MAX HP", restorePercent)
    )
    restoreDesc:SetPoint("BOTTOM", restoreButton, "TOP", 0, 5)
    restoreDesc:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local blessingDesc = CreateText(
        shrineFrame,
        "GameFontDisableSmall",
        string.format("+%d%% RUN DAMAGE", blessingPercent)
    )
    blessingDesc:SetPoint("BOTTOM", blessingButton, "TOP", 0, 5)
    blessingDesc:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local sacrificeDesc = CreateText(
        shrineFrame,
        "GameFontDisableSmall",
        string.format("-%d%% MAX HP, +%d SCORE", sacrificePercent, sacrificeScore)
    )
    sacrificeDesc:SetPoint("BOTTOM", sacrificeButton, "TOP", 0, 5)
    sacrificeDesc:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local shopFrame = CreateFrame("Frame", nil, center, "BackdropTemplate")
    shopFrame:SetSize(560, 420)
    shopFrame:SetPoint("CENTER", center, "CENTER", 0, 0)
    shopFrame:SetFrameLevel(center:GetFrameLevel() + 52)
    shopFrame:EnableMouse(true)
    ApplyBackdrop(shopFrame, { 0.025, 0.021, 0.017, 0.99 }, COLORS.gold)
    shopFrame:Hide()
    self.DungeonShopFrame = shopFrame

    local shopTitle = CreateText(shopFrame, "GameFontNormalLarge", "GOBLIN QUARTERMASTER")
    shopTitle:SetPoint("TOPLEFT", 16, -16)
    shopTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local shopCopper = CreateText(shopFrame, "GameFontNormalSmall", "0c")
    shopCopper:SetPoint("TOPRIGHT", -16, -20)
    shopCopper:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.DungeonShopCopper = shopCopper

    local shopHint = CreateText(shopFrame, "GameFontHighlightSmall", "Buy with run Copper. Sell backpack items for 50% of base value.")
    shopHint:SetPoint("TOPLEFT", 16, -42)
    shopHint:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local buyTitle = CreateText(shopFrame, "GameFontNormalSmall", "BUY")
    buyTitle:SetPoint("TOPLEFT", 16, -68)
    buyTitle:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

    local sellTitle = CreateText(shopFrame, "GameFontNormalSmall", "SELL FROM BACKPACK")
    sellTitle:SetPoint("TOPLEFT", 294, -68)
    sellTitle:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

    self.DungeonShopBuyButtons = {}
    for i = 1, 4 do
        local button = CreateFlatButton(shopFrame, tostring(i) .. "  EMPTY", 250, 56)
        button:SetPoint("TOPLEFT", 16, -88 - ((i - 1) * 64))
        button:SetScript("OnClick", function()
            GA:BuyDungeonShopItem(i)
        end)
        button:SetScript("OnEnter", function(selfButton)
            if selfButton.gaShopItem then
                GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
                GameTooltip:SetText(selfButton.gaShopItem.name or "Shop Item", 1, 0.82, 0.2)
                GameTooltip:AddLine(
                    string.format("%s  -  Item Level %d", selfButton.gaShopItem.tier or "T0", selfButton.gaShopItem.itemLevel or 1),
                    0.85, 0.82, 0.75
                )
                if selfButton.gaShopItem.buildProfile and selfButton.gaShopItem.buildProfile ~= "NONE" then
                    GameTooltip:AddLine("Build: " .. selfButton.gaShopItem.buildProfile, 1, 0.72, 0.12)
                end
                local shopWeapon = selfButton.gaShopItem.arcadeWeapon
                local shopGear = selfButton.gaShopItem.arcadeItem
                if shopWeapon then
                    GameTooltip:AddLine(string.format("Damage %d - %d", shopWeapon.damageMin or 0, shopWeapon.damageMax or 0), 0.92, 0.89, 0.82)
                    if (shopWeapon.attackPower or 0) > 0 then
                        GameTooltip:AddLine(string.format("Attack Power +%d", shopWeapon.attackPower), 1.00, 0.72, 0.12)
                    end
                    if shopWeapon.traitName then
                        GameTooltip:AddLine(shopWeapon.traitName, 1, 0.72, 0.12)
                        GameTooltip:AddLine(shopWeapon.traitDescription or "", 0.82, 0.79, 0.72, true)
                    end
                elseif shopGear then
                    if (shopGear.health or 0) > 0 then GameTooltip:AddLine(string.format("Health +%d", shopGear.health), 0.30, 1.00, 0.38) end
                    if (shopGear.armor or 0) > 0 then GameTooltip:AddLine(string.format("Armor +%d", shopGear.armor), 0.92, 0.89, 0.82) end
                    if (shopGear.attackPower or 0) > 0 then GameTooltip:AddLine(string.format("Attack Power +%d", shopGear.attackPower), 1.00, 0.72, 0.12) end
                    if (shopGear.dodge or 0) > 0 then GameTooltip:AddLine(string.format("Dodge +%.1f%%", shopGear.dodge), 0.92, 0.89, 0.82) end
                    if (shopGear.crit or 0) > 0 then GameTooltip:AddLine(string.format("Crit +%.1f%%", shopGear.crit), 0.92, 0.89, 0.82) end
                    if (shopGear.block or 0) > 0 then GameTooltip:AddLine(string.format("Block +%.1f%%", shopGear.block), 0.92, 0.89, 0.82) end
                    if shopGear.traitName then
                        GameTooltip:AddLine(shopGear.traitName, 1, 0.72, 0.12)
                        GameTooltip:AddLine(shopGear.traitDescription or "", 0.82, 0.79, 0.72, true)
                    end
                end
                if (selfButton.gaShopItem.requiredLevel or 1) > (GA.RunState and GA.RunState.runLevel or 1) then
                    GameTooltip:AddLine(string.format("Requires Run Level %d", selfButton.gaShopItem.requiredLevel), 1.00, 0.35, 0.30)
                end
                GameTooltip:AddLine("Buy: " .. FormatCopperValue(selfButton.gaShopPrice or 0), 1, 0.82, 0.2)
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.DungeonShopBuyButtons[i] = button
    end

    self.DungeonShopSellButtons = {}
    for i = 1, 6 do
        local button = CreateFlatButton(shopFrame, "EMPTY", 250, 38)
        button:SetPoint("TOPLEFT", 294, -88 - ((i - 1) * 46))
        button:SetScript("OnClick", function(selfButton)
            if selfButton.gaBackpackSlot then
                GA:SellDungeonShopItem(selfButton.gaBackpackSlot)
            end
        end)
        self.DungeonShopSellButtons[i] = button
    end

    local shopPrev = CreateFlatButton(shopFrame, "<", 38, 28)
    shopPrev:SetPoint("BOTTOMLEFT", 294, 16)
    shopPrev:SetScript("OnClick", function() GA:ChangeDungeonShopSellPage(-1) end)
    self.DungeonShopPrev = shopPrev

    local shopPage = CreateText(shopFrame, "GameFontNormalSmall", "1 / 4")
    shopPage:SetPoint("BOTTOM", shopFrame, "BOTTOM", 150, 23)
    shopPage:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonShopPageText = shopPage

    local shopNext = CreateFlatButton(shopFrame, ">", 38, 28)
    shopNext:SetPoint("BOTTOMRIGHT", -16, 16)
    shopNext:SetScript("OnClick", function() GA:ChangeDungeonShopSellPage(1) end)
    self.DungeonShopNext = shopNext

    local shopClose = CreateFlatButton(shopFrame, "CLOSE", 120, 30)
    shopClose:SetPoint("BOTTOMLEFT", 16, 16)
    shopClose:SetScript("OnClick", function() GA:CloseDungeonShop() end)

    local runControl = CreateFrame("Frame", nil, center, "BackdropTemplate")
    runControl:SetSize(580, 390)
    runControl:SetPoint("CENTER", center, "CENTER", 0, 0)
    runControl:SetFrameLevel(center:GetFrameLevel() + 58)
    runControl:EnableMouse(true)
    ApplyBackdrop(runControl, { 0.025, 0.021, 0.017, 0.995 }, COLORS.gold)
    runControl:Hide()
    self.DungeonRunControlFrame = runControl

    local runControlTitle = CreateText(runControl, "GameFontNormalLarge", "OPTIONS")
    runControlTitle:SetPoint("TOPLEFT", 20, -18)
    runControlTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local runControlHint = CreateText(
        runControl,
        "GameFontHighlightSmall",
        "Choose what happens to the current run. Saving preserves the exact dungeon state for this character."
    )
    runControlHint:SetPoint("TOPLEFT", 20, -48)
    runControlHint:SetWidth(540)
    runControlHint:SetJustifyH("LEFT")
    runControlHint:SetWordWrap(true)
    runControlHint:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local abandonButton = CreateFlatButton(runControl, "ABANDON RUN", 170, 44)
    abandonButton:SetPoint("TOPLEFT", 20, -104)
    abandonButton:SetScript("OnClick", function()
        if GA.PendingRunControlAction == "abandon" then
            GA:AbandonDungeonRun()
        else
            GA.PendingRunControlAction = "abandon"
            GA:RefreshRunControlMenu()
        end
    end)
    self.DungeonRunAbandonButton = abandonButton

    local abandonDesc = CreateText(
        runControl,
        "GameFontDisableSmall",
        "End the run as a failure. Found loot and committed supplies are lost. The character survives."
    )
    abandonDesc:SetPoint("TOPLEFT", abandonButton, "TOPRIGHT", 16, -2)
    abandonDesc:SetWidth(350)
    abandonDesc:SetJustifyH("LEFT")
    abandonDesc:SetWordWrap(true)
    abandonDesc:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local suspendButton = CreateFlatButton(runControl, "SAVE & SWITCH", 170, 44)
    suspendButton:SetPoint("TOPLEFT", 20, -174)
    suspendButton:SetScript("OnClick", function()
        GA:SuspendDungeonRun()
    end)
    self.DungeonRunSuspendButton = suspendButton

    local suspendDesc = CreateText(
        runControl,
        "GameFontDisableSmall",
        "Suspend this exact run and return to character selection. Resume it later with the same hero."
    )
    suspendDesc:SetPoint("TOPLEFT", suspendButton, "TOPRIGHT", 16, -2)
    suspendDesc:SetWidth(350)
    suspendDesc:SetJustifyH("LEFT")
    suspendDesc:SetWordWrap(true)
    suspendDesc:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local killButton = CreateFlatButton(runControl, "KILLSWITCH", 170, 44)
    killButton:SetPoint("TOPLEFT", 20, -244)
    killButton:SetScript("OnClick", function()
        if GA.PendingRunControlAction == "kill" then
            GA:KillSwitchDungeonRun()
        else
            GA.PendingRunControlAction = "kill"
            GA:RefreshRunControlMenu()
        end
    end)
    self.DungeonRunKillButton = killButton

    local killDesc = CreateText(
        runControl,
        "GameFontDisableSmall",
        "Kill the run character immediately. Found loot and committed supplies are lost. For a Hardcore Arcade hero, death is permanent."
    )
    killDesc:SetPoint("TOPLEFT", killButton, "TOPRIGHT", 16, -2)
    killDesc:SetWidth(350)
    killDesc:SetJustifyH("LEFT")
    killDesc:SetWordWrap(true)
    killDesc:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])

    local runControlStatus = CreateText(runControl, "GameFontDisableSmall", "")
    runControlStatus:SetPoint("BOTTOMLEFT", 20, 62)
    runControlStatus:SetWidth(400)
    runControlStatus:SetJustifyH("LEFT")
    runControlStatus:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
    self.DungeonRunControlStatus = runControlStatus

    local runControlCancel = CreateFlatButton(runControl, "CANCEL", 120, 32)
    runControlCancel:SetPoint("BOTTOMRIGHT", -20, 18)
    runControlCancel:SetScript("OnClick", function()
        GA:CloseRunControlMenu()
    end)

    local spellbook = CreateFrame("Frame", nil, center, "BackdropTemplate")
    spellbook:SetSize(558, 470)
    spellbook:SetPoint("CENTER", center, "CENTER", 0, 0)
    spellbook:SetFrameLevel(center:GetFrameLevel() + 55)
    spellbook:EnableMouse(true)
    ApplyBackdrop(spellbook, { 0.025, 0.021, 0.017, 0.985 }, COLORS.gold)
    spellbook:Hide()
    self.DungeonSpellbookFrame = spellbook

    local spellbookTitle = CreateText(spellbook, "GameFontNormalLarge", "SPELLBOOK")
    spellbookTitle:SetPoint("TOP", 0, -16)
    spellbookTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local spellbookHint = CreateText(
        spellbook,
        "GameFontHighlightSmall",
        "Drag learned spells onto action slots 2-9. Locked spells show their required Run Level."
    )
    spellbookHint:SetPoint("TOP", spellbookTitle, "BOTTOM", 0, -7)
    spellbookHint:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local SPELLS_PER_PAGE = 12
    self.DungeonSpellbookPage = 1
    self.DungeonSpellbookButtons = {}

    for i = 1, SPELLS_PER_PAGE do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)

        local spellButton = CreateFrame("Button", nil, spellbook, "BackdropTemplate")
        spellButton:SetSize(250, 50)
        spellButton:SetPoint("TOPLEFT", 18 + col * 272, -66 - row * 56)
        ApplyBackdrop(spellButton, { 0.045, 0.039, 0.031, 1 }, COLORS.goldDim)
        spellButton:RegisterForDrag("LeftButton")

        local icon = spellButton:CreateTexture(nil, "ARTWORK")
        icon:SetSize(38, 38)
        icon:SetPoint("LEFT", 6, 0)
        icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
        spellButton.icon = icon

        local nameText = CreateText(spellButton, "GameFontNormalSmall", "")
        nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -3)
        nameText:SetPoint("RIGHT", -6, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
        spellButton.nameText = nameText

        local metaText = CreateText(spellButton, "GameFontDisableSmall", "")
        metaText:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, 3)
        metaText:SetPoint("RIGHT", -6, 0)
        metaText:SetJustifyH("LEFT")
        metaText:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        spellButton.metaText = metaText

        spellButton:SetScript("OnDragStart", function(button)
            if button.gaAbilityId and button.gaUnlocked then
                GA:BeginSpellbookDrag(button.gaAbilityId)
            end
        end)
        spellButton:SetScript("OnDragStop", function()
            GA:FinishSpellbookDrag()
        end)
        spellButton:SetScript("OnEnter", function(button)
            GA:ShowSpellbookAbilityTooltip(button)
        end)
        spellButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        self.DungeonSpellbookButtons[i] = spellButton
    end

    local prevPage = CreateFlatButton(spellbook, "<  PREV", 100, 28)
    prevPage:SetPoint("BOTTOMLEFT", 18, 12)
    prevPage:SetScript("OnClick", function()
        GA:ChangeSpellbookPage(-1)
    end)
    self.DungeonSpellbookPrev = prevPage

    local pageText = CreateText(spellbook, "GameFontNormalSmall", "PAGE 1 / 1")
    pageText:SetPoint("BOTTOM", 0, 42)
    pageText:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.DungeonSpellbookPageText = pageText

    local nextPage = CreateFlatButton(spellbook, "NEXT  >", 100, 28)
    nextPage:SetPoint("BOTTOMRIGHT", -18, 12)
    nextPage:SetScript("OnClick", function()
        GA:ChangeSpellbookPage(1)
    end)
    self.DungeonSpellbookNext = nextPage

    local spellbookClose = CreateFlatButton(spellbook, "B / ESC  CLOSE", 150, 28)
    spellbookClose:SetPoint("BOTTOM", 0, 8)
    spellbookClose:SetScript("OnClick", function()
        GA:CloseSpellbook()
    end)

    local dragFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    dragFrame:SetSize(46, 46)
    dragFrame:SetFrameStrata("TOOLTIP")
    dragFrame:EnableMouse(false)
    ApplyBackdrop(dragFrame, { 0.02, 0.02, 0.02, 0.9 }, COLORS.green)

    local dragIcon = dragFrame:CreateTexture(nil, "ARTWORK")
    dragIcon:SetPoint("TOPLEFT", 3, -3)
    dragIcon:SetPoint("BOTTOMRIGHT", -3, 3)
    dragIcon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    dragFrame.icon = dragIcon
    dragFrame:Hide()
    dragFrame:SetScript("OnUpdate", function(frame)
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale + 18, y / scale - 18)
    end)
    self.DungeonSpellDragFrame = dragFrame

    local legend = CreateText(center, "GameFontDisableSmall", "@ YOU    ENEMY SPRITE    * CLEARED    S SHRINE    $ CHEST    < / > STAIRS")
    legend:SetPoint("BOTTOM", 0, 9)
    legend:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local actionBar = CreateFrame("Frame", nil, page, "BackdropTemplate")
    actionBar:SetPoint("BOTTOMLEFT", 18, 16)
    actionBar:SetPoint("BOTTOMRIGHT", -18, 16)
    actionBar:SetHeight(86)
    ApplyBackdrop(actionBar, { 0.035, 0.031, 0.026, 0.98 }, COLORS.goldDim)

    local actionLabel = CreateText(actionBar, "GameFontNormalSmall", "ACTION BAR")
    actionLabel:SetPoint("TOPLEFT", 12, -9)
    actionLabel:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local function CreateActionIconButton(parent, hotkey, iconTexture)
        local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
        button:SetSize(48, 48)
        ApplyBackdrop(button, { 0.018, 0.016, 0.013, 1 }, COLORS.goldDim)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 3, -3)
        icon:SetPoint("BOTTOMRIGHT", -3, 3)
        icon:SetTexture(iconTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
        icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
        button.icon = icon

        local keyText = CreateText(button, "GameFontNormalSmall", hotkey)
        keyText:SetPoint("TOPRIGHT", -4, -3)
        keyText:SetTextColor(1, 1, 1)
        button.hotkeyText = keyText

        local cooldownText = CreateText(button, "GameFontNormal", "")
        cooldownText:SetPoint("CENTER", 0, 0)
        cooldownText:SetTextColor(1, 1, 1)
        button.cooldownText = cooldownText

        return button
    end

    self.DungeonActionButtons = {}
    self.DungeonAbilitySlotButtons = {}

    local barButtonSize = 48
    local barGap = 5
    local totalButtons = 10
    local totalWidth = (barButtonSize * totalButtons) + (barGap * (totalButtons - 1))
    local startX = -math.floor(totalWidth / 2)

    local attackButton = CreateActionIconButton(
        actionBar,
        "1",
        "Interface\\Icons\\INV_Sword_04"
    )
    attackButton:SetPoint("BOTTOM", actionBar, "BOTTOM", startX + 24, 7)
    attackButton:SetEnabled(false)
    attackButton:SetScript("OnClick", function()
        GA:PlayerAttackEnemy()
    end)
    attackButton:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_TOP")
        GameTooltip:SetText("Basic Attack", 1, 0.82, 0.2)
        GameTooltip:AddLine("Fixed basic melee attack. Generates class resource on a successful strike.", 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    attackButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.DungeonAttackButton = attackButton
    self.DungeonActionButtons[1] = attackButton

    for slotIndex = 1, 8 do
        local hotkey = tostring(slotIndex + 1)
        local button = CreateActionIconButton(
            actionBar,
            hotkey,
            "Interface\\Icons\\INV_Misc_QuestionMark"
        )
        local x = startX + ((slotIndex) * (barButtonSize + barGap)) + 24
        button:SetPoint("BOTTOM", actionBar, "BOTTOM", x, 7)
        button:SetEnabled(true)
        button.gaActionSlot = slotIndex
        button:RegisterForDrag("LeftButton")
        button:SetScript("OnDragStart", function(slotButton)
            GA:BeginActionSlotDrag(slotButton.gaActionSlot)
        end)
        button:SetScript("OnDragStop", function()
            GA:FinishSpellbookDrag()
        end)
        button:SetScript("OnClick", function(slotButton, mouseButton)
            if mouseButton == "RightButton" then
                GA:ClearRunActionSlot(slotButton.gaActionSlot)
            elseif GA.DungeonSpellDrag then
                GA:DropSpellOnActionSlot(slotButton.gaActionSlot)
            else
                GA:UseRunActionSlot(slotButton.gaActionSlot)
            end
        end)
        button:SetScript("OnReceiveDrag", function(slotButton)
            GA:DropSpellOnActionSlot(slotButton.gaActionSlot)
        end)
        button:HookScript("OnMouseUp", function(slotButton, mouseButton)
            if mouseButton == "LeftButton" and GA.DungeonSpellDrag then
                GA:DropSpellOnActionSlot(slotButton.gaActionSlot)
            end
        end)
        button:SetScript("OnEnter", function(slotButton)
            GA:SetActionSlotDropHighlight(slotButton, GA.DungeonSpellDrag ~= nil)
            GA:ShowActionSlotTooltip(slotButton)
        end)
        button:SetScript("OnLeave", function(slotButton)
            GA:SetActionSlotDropHighlight(slotButton, GA.DungeonSpellDrag ~= nil)
            GameTooltip:Hide()
        end)
        self.DungeonAbilitySlotButtons[slotIndex] = button
        self.DungeonActionButtons[slotIndex + 1] = button
    end

    local potionButton = CreateActionIconButton(
        actionBar,
        "0",
        "Interface\\Icons\\INV_Potion_54"
    )
    local potionX = startX + (9 * (barButtonSize + barGap)) + 24
    potionButton:SetPoint("BOTTOM", actionBar, "BOTTOM", potionX, 7)
    potionButton:SetEnabled(false)
    potionButton:SetScript("OnClick", function()
        GA:UseRunPotion()
    end)
    potionButton:SetScript("OnEnter", function(button)
        GA:ShowRunPotionTooltip(button)
    end)
    potionButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local potionCount = CreateText(potionButton, "GameFontNormalSmall", "")
    potionCount:SetPoint("BOTTOMRIGHT", -4, 3)
    potionCount:SetTextColor(1, 1, 1)
    potionButton.countText = potionCount

    self.DungeonPotionButton = potionButton
    self.DungeonActionButtons[10] = potionButton

    local state = CreateText(actionBar, "GameFontDisableSmall", "READY - BEGIN A RUN")
    state:SetPoint("TOPRIGHT", -12, -10)
    state:SetWidth(430)
    state:SetJustifyH("RIGHT")
    state:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonRunStateText = state

    local setup = CreateFrame("Frame", nil, page, "BackdropTemplate")
    setup:SetPoint("TOPLEFT", 1, -1)
    setup:SetPoint("BOTTOMRIGHT", -1, 1)
    setup:SetFrameLevel(page:GetFrameLevel() + 20)
    ApplyBackdrop(setup, { 0.040, 0.034, 0.027, 1 }, COLORS.goldDim)
    self.DungeonSetupFrame = setup

    local setupContent = CreateFrame("Frame", nil, setup)
    setupContent:SetSize(900, 650)
    setupContent:SetPoint("TOP", setup, "TOP", 0, -22)
    self.DungeonSetupContent = setupContent

    local setupTitle = CreateText(setupContent, "GameFontNormalHuge", "DUNGEON RUN")
    setupTitle:SetPoint("TOPLEFT", 0, 0)
    setupTitle:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

    local setupSubtitle = CreateText(setupContent, "GameFontNormal", "CHOOSE A HERO")
    setupSubtitle:SetPoint("TOPLEFT", setupTitle, "BOTTOMLEFT", 0, -10)
    setupSubtitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local setupHint = CreateText(
        setupContent,
        "GameFontHighlightSmall",
        "Choose a hero, enter the dungeon, and extract found gear into the account-wide Central Stash by completing the run."
    )
    setupHint:SetPoint("TOPLEFT", setupSubtitle, "BOTTOMLEFT", 0, -8)
    setupHint:SetWidth(625)
    setupHint:SetJustifyH("LEFT")
    setupHint:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local stashButton = CreateFlatButton(setupContent, "CENTRAL STASH  0", 220, 44)
    stashButton:SetPoint("TOPRIGHT", 0, -2)
    stashButton.label:ClearAllPoints()
    stashButton.label:SetPoint("CENTER", 13, 0)
    local stashButtonIcon = stashButton:CreateTexture(nil, "ARTWORK")
    stashButtonIcon:SetSize(26, 26)
    stashButtonIcon:SetPoint("LEFT", 16, 0)
    stashButtonIcon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
    stashButtonIcon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    stashButton.icon = stashButtonIcon
    stashButton:SetScript("OnClick", function()
        GA:OpenCentralStash()
    end)
    self.DungeonCentralStashButton = stashButton

    local rosterPanel = CreateFrame("Frame", nil, setupContent, "BackdropTemplate")
    rosterPanel:SetPoint("TOPLEFT", setupContent, "TOPLEFT", 0, -116)
    rosterPanel:SetSize(410, 480)
    ApplyBackdrop(rosterPanel, { 0.050, 0.043, 0.034, 1 }, COLORS.goldDim)
    rosterPanel:EnableMouseWheel(true)
    self.DungeonRosterPanel = rosterPanel

    local rosterTitle = CreateText(rosterPanel, "GameFontNormalSmall", "CHARACTERS")
    rosterTitle:SetPoint("TOPLEFT", 14, -14)
    rosterTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    self.DungeonCharacterRows = {}
    for i = 1, 6 do
        local row = CreateFrame("Button", nil, rosterPanel, "BackdropTemplate")
        row:SetSize(380, 56)
        row:SetPoint("TOPLEFT", 14, -42 - ((i - 1) * 62))
        ApplyBackdrop(row, { 0.060, 0.052, 0.042, 1 }, COLORS.goldDim)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(42, 42)
        icon:SetPoint("LEFT", 7, 0)

        local nameText = CreateText(row, "GameFontNormal", "")
        nameText:SetPoint("TOPLEFT", 58, -9)
        nameText:SetPoint("RIGHT", -10, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

        local metaText = CreateText(row, "GameFontHighlightSmall", "")
        metaText:SetPoint("BOTTOMLEFT", 58, 9)
        metaText:SetPoint("RIGHT", -10, 0)
        metaText:SetJustifyH("LEFT")
        metaText:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

        row.icon = icon
        row.nameText = nameText
        row.metaText = metaText
        row:SetScript("OnClick", function(button)
            if button.createCharacterSlot then
                GA:OpenCharacterGeneratorModal()
            elseif button.characterKey then
                GA:SelectDungeonCharacter(button.characterKey)
            end
        end)
        self.DungeonCharacterRows[i] = row
    end

    rosterPanel:SetScript("OnMouseWheel", function(_, delta)
        local roster = GA:GetCharacterRoster()
        local virtualCount = #roster + 1
        local maxOffset = math.max(0, virtualCount - #GA.DungeonCharacterRows)
        GA.DungeonRosterOffset = math.max(0, math.min(maxOffset, (GA.DungeonRosterOffset or 0) - delta))
        GA:RefreshDungeonCharacterSelection()
    end)

    local selectedPanel = CreateFrame("Frame", nil, setupContent, "BackdropTemplate")
    selectedPanel:SetPoint("TOPLEFT", rosterPanel, "TOPRIGHT", 20, 0)
    selectedPanel:SetSize(470, 480)
    ApplyBackdrop(selectedPanel, { 0.050, 0.043, 0.034, 1 }, COLORS.goldDim)
    self.DungeonSelectedPanel = selectedPanel

    local selectedTitle = CreateText(selectedPanel, "GameFontNormalSmall", "SELECTED HERO")
    selectedTitle:SetPoint("TOPLEFT", 16, -14)
    selectedTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local selectedIconBorder = CreateFrame("Frame", nil, selectedPanel, "BackdropTemplate")
    selectedIconBorder:SetSize(76, 76)
    selectedIconBorder:SetPoint("TOPLEFT", 16, -42)
    ApplyBackdrop(selectedIconBorder, { 0.02, 0.02, 0.02, 1 }, COLORS.gold)

    local selectedIcon = selectedIconBorder:CreateTexture(nil, "ARTWORK")
    selectedIcon:SetPoint("TOPLEFT", 3, -3)
    selectedIcon:SetPoint("BOTTOMRIGHT", -3, 3)
    self.DungeonSelectedCharacterIcon = selectedIcon

    local selectedName = CreateText(selectedPanel, "GameFontNormalLarge", "")
    selectedName:SetPoint("TOPLEFT", selectedIconBorder, "TOPRIGHT", 14, -4)
    selectedName:SetPoint("RIGHT", -16, 0)
    selectedName:SetJustifyH("LEFT")
    selectedName:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    self.DungeonSelectedCharacterName = selectedName

    local selectedMeta = CreateText(selectedPanel, "GameFontHighlightSmall", "")
    selectedMeta:SetPoint("TOPLEFT", selectedName, "BOTTOMLEFT", 0, -7)
    selectedMeta:SetPoint("RIGHT", -16, 0)
    selectedMeta:SetJustifyH("LEFT")
    selectedMeta:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonSelectedCharacterMeta = selectedMeta

    local selectedSource = CreateText(selectedPanel, "GameFontDisableSmall", "")
    selectedSource:SetPoint("TOPLEFT", selectedMeta, "BOTTOMLEFT", 0, -7)
    selectedSource:SetPoint("RIGHT", -16, 0)
    selectedSource:SetJustifyH("LEFT")
    selectedSource:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.DungeonSelectedCharacterSource = selectedSource

    local selectedDifficultyLabel = CreateText(selectedPanel, "GameFontNormalSmall", "DIFFICULTY")
    selectedDifficultyLabel:SetPoint("TOPLEFT", 16, -111)
    selectedDifficultyLabel:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.DungeonSelectedDifficultyLabel = selectedDifficultyLabel

    self.DungeonSelectedDifficultyButtons = {}
    local setupDifficultyIds = { "EASY", "NORMAL", "HARD" }
    for i, difficultyId in ipairs(setupDifficultyIds) do
        local button = CreateFlatButton(selectedPanel, difficultyId, 96, 24)
        button:SetPoint("TOPLEFT", 112 + ((i - 1) * 106), -105)
        button.difficultyId = difficultyId
        button:SetScript("OnClick", function(selfButton)
            local selectedCharacter = GA:GetSelectedDungeonCharacter()
            if not selectedCharacter then return end
            local ok, err = GA:SetCharacterDifficulty(selectedCharacter.key, selfButton.difficultyId)
            if not ok and GA.DungeonSelectedNote then
                GA.DungeonSelectedNote:SetText(err or "Could not change difficulty.")
                GA.DungeonSelectedNote:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
            end
        end)
        button:SetScript("OnEnter", function(selfButton)
            local definition = GA.GetDifficultyDefinition and GA:GetDifficultyDefinition(selfButton.difficultyId)
            if definition then
                GameTooltip:SetOwner(selfButton, "ANCHOR_TOP")
                GameTooltip:SetText(definition.label or selfButton.difficultyId, 1, 0.82, 0.2)
                GameTooltip:AddLine(definition.description or "", 0.85, 0.82, 0.75, true)
                GameTooltip:AddLine(string.format("Score multiplier: %.2fx", tonumber(definition.scoreMultiplier) or 1), 0.25, 1.00, 0.35)
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.DungeonSelectedDifficultyButtons[i] = button
    end

    local loadoutTitle = CreateText(selectedPanel, "GameFontNormalSmall", "RUN LOADOUT")
    loadoutTitle:SetPoint("TOPLEFT", 16, -136)
    loadoutTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local weaponCard = CreateFrame("Button", nil, selectedPanel, "BackdropTemplate")
    weaponCard:SetSize(438, 154)
    weaponCard:SetPoint("TOPLEFT", 16, -158)
    ApplyBackdrop(weaponCard, { 0.028, 0.024, 0.020, 1 }, COLORS.goldDim)
    weaponCard:SetScript("OnEnter", function(button)
        button:SetBackdropBorderColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1)
        ShowSetupWeaponTooltip(button)
    end)
    weaponCard:SetScript("OnLeave", function(button)
        button:SetBackdropBorderColor(COLORS.goldDim[1], COLORS.goldDim[2], COLORS.goldDim[3], 1)
        GameTooltip:Hide()
    end)
    self.DungeonSelectedWeaponCard = weaponCard

    local weaponIconBorder = CreateFrame("Frame", nil, weaponCard, "BackdropTemplate")
    weaponIconBorder:SetSize(58, 58)
    weaponIconBorder:SetPoint("TOPLEFT", 12, -12)
    ApplyBackdrop(weaponIconBorder, { 0.018, 0.016, 0.014, 1 }, COLORS.goldDim)

    local weaponIcon = weaponIconBorder:CreateTexture(nil, "ARTWORK")
    weaponIcon:SetPoint("TOPLEFT", 2, -2)
    weaponIcon:SetPoint("BOTTOMRIGHT", -2, 2)
    weaponIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    weaponIcon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    self.DungeonSelectedWeaponIcon = weaponIcon

    local loadoutWeapon = CreateText(weaponCard, "GameFontNormal", "")
    loadoutWeapon:SetPoint("TOPLEFT", weaponIconBorder, "TOPRIGHT", 10, -1)
    loadoutWeapon:SetPoint("RIGHT", -12, 0)
    loadoutWeapon:SetJustifyH("LEFT")
    loadoutWeapon:SetWordWrap(false)
    loadoutWeapon:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    self.DungeonSelectedWeaponName = loadoutWeapon

    local weaponItemLevel = CreateText(weaponCard, "GameFontHighlightSmall", "")
    weaponItemLevel:SetPoint("TOPLEFT", loadoutWeapon, "BOTTOMLEFT", 0, -5)
    weaponItemLevel:SetPoint("RIGHT", -12, 0)
    weaponItemLevel:SetJustifyH("LEFT")
    weaponItemLevel:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.DungeonSelectedWeaponItemLevel = weaponItemLevel

    local weaponType = CreateText(weaponCard, "GameFontHighlightSmall", "")
    weaponType:SetPoint("TOPLEFT", weaponItemLevel, "BOTTOMLEFT", 0, -5)
    weaponType:SetPoint("RIGHT", -12, 0)
    weaponType:SetJustifyH("LEFT")
    weaponType:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    self.DungeonSelectedWeaponType = weaponType

    local loadoutStats = CreateText(weaponCard, "GameFontNormalSmall", "")
    loadoutStats:SetPoint("TOPLEFT", 12, -82)
    loadoutStats:SetPoint("RIGHT", -12, 0)
    loadoutStats:SetJustifyH("LEFT")
    loadoutStats:SetWordWrap(false)
    loadoutStats:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    self.DungeonSelectedWeaponStats = loadoutStats

    local weaponPower = CreateText(weaponCard, "GameFontHighlightSmall", "")
    weaponPower:SetPoint("TOPLEFT", loadoutStats, "BOTTOMLEFT", 0, -5)
    weaponPower:SetPoint("RIGHT", -12, 0)
    weaponPower:SetJustifyH("LEFT")
    weaponPower:SetTextColor(0.25, 1.00, 0.35)
    self.DungeonSelectedWeaponPower = weaponPower

    local loadoutTrait = CreateText(weaponCard, "GameFontHighlightSmall", "")
    loadoutTrait:SetPoint("TOPLEFT", weaponPower, "BOTTOMLEFT", 0, -5)
    loadoutTrait:SetPoint("RIGHT", -12, 0)
    loadoutTrait:SetJustifyH("LEFT")
    loadoutTrait:SetWordWrap(true)
    loadoutTrait:SetTextColor(0.25, 1.00, 0.35)
    self.DungeonSelectedWeaponTrait = loadoutTrait

    local statusPanel = CreateFrame("Frame", nil, selectedPanel, "BackdropTemplate")
    statusPanel:SetSize(438, 82)
    statusPanel:SetPoint("TOPLEFT", 16, -324)
    ApplyBackdrop(statusPanel, { 0.032, 0.028, 0.023, 1 }, COLORS.goldDim)
    self.DungeonSelectedStatusPanel = statusPanel

    local statusTitle = CreateText(statusPanel, "GameFontNormalSmall", "HERO STATUS")
    statusTitle:SetPoint("TOPLEFT", 12, -10)
    statusTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.DungeonSelectedStatusTitle = statusTitle

    local selectedNote = CreateText(
        statusPanel,
        "GameFontDisableSmall",
        "To refresh an alt's gear, log into that character once and open GoblinArcade."
    )
    selectedNote:SetPoint("TOPLEFT", 12, -31)
    selectedNote:SetPoint("RIGHT", -12, 0)
    selectedNote:SetJustifyH("LEFT")
    selectedNote:SetJustifyV("TOP")
    selectedNote:SetWordWrap(true)
    selectedNote:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonSelectedNote = selectedNote

    local actionButtonWidth = 212
    local actionButtonHeight = 42

    local setupBegin = CreateFlatButton(selectedPanel, "BEGIN RUN", actionButtonWidth, actionButtonHeight)
    setupBegin:SetPoint("BOTTOMRIGHT", -16, 16)
    setupBegin:SetEnabled(false)
    setupBegin.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    setupBegin:SetScript("OnClick", function()
        GA:BeginDungeonRun()
    end)
    self.DungeonSetupBeginButton = setupBegin

    local deleteHero = CreateFlatButton(selectedPanel, "DELETE HERO", actionButtonWidth, actionButtonHeight)
    deleteHero:SetPoint("BOTTOMLEFT", 16, 16)
    deleteHero:SetScript("OnClick", function()
        local selected = GA:GetSelectedDungeonCharacter()
        if not selected or not (selected.isArcadeGenerated or selected.sourceType == "arcade") then
            return
        end

        if GA.PendingDeleteArcadeKey == selected.key then
            local ok, err = GA:DeleteArcadeCharacter(selected.key)
            if not ok and GA.DungeonSelectedNote then
                GA.DungeonSelectedNote:SetText(err or "Could not delete this hero.")
                GA.DungeonSelectedNote:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
            end
        else
            GA.PendingDeleteArcadeKey = selected.key
            GA:RefreshDungeonCharacterSelection()
        end
    end)
    deleteHero:Hide()
    self.DungeonDeleteHeroButton = deleteHero

    local abandonSaved = CreateFlatButton(selectedPanel, "ABANDON SAVED", actionButtonWidth, actionButtonHeight)
    abandonSaved:SetPoint("BOTTOMLEFT", 16, 16)
    abandonSaved:SetScript("OnClick", function()
        local selected = GA:GetSelectedDungeonCharacter()
        if not selected or not GA.HasSuspendedRun or not GA:HasSuspendedRun(selected.key) then
            return
        end

        if GA.PendingAbandonSavedKey == selected.key then
            GA:ClearSuspendedRun(selected.key)
            GA.PendingAbandonSavedKey = nil
            GA:RefreshDungeonCharacterSelection()
        else
            GA.PendingAbandonSavedKey = selected.key
            GA:RefreshDungeonCharacterSelection()
        end
    end)
    abandonSaved:Hide()
    self.DungeonAbandonSavedRunButton = abandonSaved

    local stashOverlay = CreateFrame("Frame", nil, setup, "BackdropTemplate")
    stashOverlay:SetAllPoints(setup)
    stashOverlay:SetFrameLevel(setup:GetFrameLevel() + 55)
    stashOverlay:EnableMouse(true)
    ApplyBackdrop(stashOverlay, { 0.005, 0.004, 0.003, 0.86 }, { 0, 0, 0, 0 })
    stashOverlay:Hide()
    self.DungeonCentralStashOverlay = stashOverlay

    local stashModal = CreateFrame("Frame", nil, stashOverlay, "BackdropTemplate")
    stashModal:SetSize(920, 650)
    stashModal:SetPoint("CENTER")
    ApplyBackdrop(stashModal, { 0.040, 0.034, 0.027, 1 }, COLORS.goldDim)

    local stashTitle = CreateText(stashModal, "GameFontNormalHuge", "CENTRAL STASH")
    stashTitle:SetPoint("TOPLEFT", 24, -20)
    stashTitle:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

    local stashCount = CreateText(stashModal, "GameFontNormalSmall", "0 ITEMS")
    stashCount:SetPoint("TOPRIGHT", -24, -26)
    stashCount:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.DungeonCentralStashCount = stashCount

    local stashHint = CreateText(
        stashModal,
        "GameFontHighlightSmall",
        "Account-wide extracted loot. Only items carried out of a successful run are stored here."
    )
    stashHint:SetPoint("TOPLEFT", stashTitle, "BOTTOMLEFT", 0, -8)
    stashHint:SetWidth(860)
    stashHint:SetJustifyH("LEFT")
    stashHint:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    self.DungeonCentralStashSlots = {}
    local stashColumns = 5
    local stashRows = 5
    local stashSlotSize = 58
    local stashGap = 10
    local stashGridWidth = stashColumns * stashSlotSize + (stashColumns - 1) * stashGap
    local stashStartX = 28

    for i = 1, stashColumns * stashRows do
        local col = (i - 1) % stashColumns
        local row = math.floor((i - 1) / stashColumns)
        local slot = CreateFrame("Button", nil, stashModal, "BackdropTemplate")
        slot:SetSize(stashSlotSize, stashSlotSize)
        slot:SetPoint("TOPLEFT", stashStartX + col * (stashSlotSize + stashGap), -92 - row * (stashSlotSize + stashGap))
        ApplyBackdrop(slot, { 0.025, 0.022, 0.018, 1 }, COLORS.goldDim)

        local icon = slot:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 4, -4)
        icon:SetPoint("BOTTOMRIGHT", -4, 4)
        icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
        icon:SetAlpha(0.12)
        slot.icon = icon

        local count = CreateText(slot, "GameFontNormalSmall", "")
        count:SetPoint("BOTTOMRIGHT", -4, 3)
        count:SetTextColor(1, 1, 1)
        slot.countText = count

        slot:SetScript("OnEnter", function(button)
            local item = button.gaStashItem
            if not item then return end
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText(item.name or "Extracted Item", 1, 0.82, 0.2)
            GameTooltip:AddLine(
                string.format("%s  -  Item Level %d", item.tier or "T0", tonumber(item.itemLevel) or 1),
                0.85, 0.82, 0.75
            )
            if item.equipLoc then
                GameTooltip:AddLine("Slot: " .. tostring(item.slotLabel or item.equipLoc), 0.92, 0.89, 0.82)
            end
            local requiredLevel = math.max(1, math.floor(tonumber(item.requiredLevel) or 1))
            if requiredLevel > 1 then
                GameTooltip:AddLine("Requires Run Level " .. tostring(requiredLevel), 0.85, 0.82, 0.75)
            end
            if item.buildProfile and item.buildProfile ~= "" and item.buildProfile ~= "NONE" then
                GameTooltip:AddLine("Build: " .. item.buildProfile, 1, 0.72, 0.12)
            end
            local weapon = item.arcadeWeapon
            local gear = item.arcadeItem
            if weapon then
                GameTooltip:AddLine(string.format("Damage %d - %d", weapon.damageMin or 0, weapon.damageMax or 0), 0.92, 0.89, 0.82)
                if (weapon.attackPower or 0) > 0 then GameTooltip:AddLine(string.format("Attack Power +%d", weapon.attackPower), 1, 0.72, 0.12) end
                if weapon.traitName then
                    GameTooltip:AddLine(weapon.traitName, 1, 0.72, 0.12)
                    GameTooltip:AddLine(weapon.traitDescription or "", 0.82, 0.79, 0.72, true)
                end
            elseif gear then
                if (gear.health or 0) > 0 then GameTooltip:AddLine(string.format("Health +%d", gear.health), 0.30, 1.00, 0.38) end
                if (gear.armor or 0) > 0 then GameTooltip:AddLine(string.format("Armor +%d", gear.armor), 0.92, 0.89, 0.82) end
                if (gear.attackPower or 0) > 0 then GameTooltip:AddLine(string.format("Attack Power +%d", gear.attackPower), 1, 0.72, 0.12) end
                if (gear.dodge or 0) > 0 then GameTooltip:AddLine(string.format("Dodge +%.1f%%", gear.dodge), 0.92, 0.89, 0.82) end
                if (gear.crit or 0) > 0 then GameTooltip:AddLine(string.format("Crit +%.1f%%", gear.crit), 0.92, 0.89, 0.82) end
                if (gear.block or 0) > 0 then GameTooltip:AddLine(string.format("Block +%.1f%%", gear.block), 0.92, 0.89, 0.82) end
                if gear.traitName then
                    GameTooltip:AddLine(gear.traitName, 1, 0.72, 0.12)
                    GameTooltip:AddLine(gear.traitDescription or "", 0.82, 0.79, 0.72, true)
                end
            elseif item.consumableEffect and item.consumableEffect ~= "NONE" then
                GameTooltip:AddLine(item.description or "", 0.82, 0.79, 0.72, true)
            end
            if item.extractedFromCharacter then
                GameTooltip:AddLine("Extracted by " .. item.extractedFromCharacter, 0.65, 0.65, 0.65)
            end
            if item.category == "CONSUMABLE" or item.itemType == "Consumable" then
                GameTooltip:AddLine("Click to prepare 1 as a pre-run supply.", 0.30, 1.00, 0.38, true)
                GameTooltip:AddLine("Maximum: 3 supply items. Prepared supplies are committed when the run starts.", 0.65, 0.65, 0.65, true)
            else
                GameTooltip:AddLine("Click to equip on the selected character.", 0.30, 1.00, 0.38, true)
            end
            GameTooltip:Show()
        end)
        slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
        slot:SetScript("OnClick", function(button)
            if not button.gaStashIndex or not button.gaStashItem then return end
            if button.gaStashItem.category == "CONSUMABLE"
                or button.gaStashItem.itemType == "Consumable" then
                GA:AssignSelectedCentralStashSupply(button.gaStashIndex)
            else
                GA:EquipSelectedCentralStashItem(button.gaStashIndex)
            end
        end)
        self.DungeonCentralStashSlots[i] = slot
    end

    local stashPrev = CreateFlatButton(stashModal, "<  PREV", 100, 30)
    stashPrev:SetPoint("BOTTOMLEFT", 28, 18)
    stashPrev:SetScript("OnClick", function() GA:ChangeCentralStashPage(-1) end)
    self.DungeonCentralStashPrev = stashPrev

    local stashPage = CreateText(stashModal, "GameFontNormalSmall", "PAGE 1 / 1")
    stashPage:SetPoint("BOTTOMLEFT", 160, 27)
    stashPage:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonCentralStashPageText = stashPage

    local stashNext = CreateFlatButton(stashModal, "NEXT  >", 100, 30)
    stashNext:SetPoint("BOTTOMLEFT", 280, 18)
    stashNext:SetScript("OnClick", function() GA:ChangeCentralStashPage(1) end)
    self.DungeonCentralStashNext = stashNext

    local stashClose = CreateFlatButton(stashModal, "CLOSE", 100, 30)
    stashClose:SetPoint("BOTTOMRIGHT", -24, 18)
    stashClose:SetScript("OnClick", function() GA:CloseCentralStash() end)

    local loadoutTitle = CreateText(stashModal, "GameFontNormalSmall", "SELECTED CHARACTER LOADOUT")
    loadoutTitle:SetPoint("TOPLEFT", 410, -92)
    loadoutTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local loadoutName = CreateText(stashModal, "GameFontNormal", "")
    loadoutName:SetPoint("TOPLEFT", 410, -114)
    loadoutName:SetWidth(460)
    loadoutName:SetJustifyH("LEFT")
    loadoutName:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    self.DungeonCentralLoadoutName = loadoutName

    local loadoutHint = CreateText(
        stashModal,
        "GameFontHighlightSmall",
        "Gear overrides baseline slots. Consumables use the 3 supply slots. Baseline gear is locked and can never enter the stash."
    )
    loadoutHint:SetPoint("TOPLEFT", 410, -138)
    loadoutHint:SetWidth(460)
    loadoutHint:SetJustifyH("LEFT")
    loadoutHint:SetWordWrap(true)
    loadoutHint:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local suppliesTitle = CreateText(stashModal, "GameFontNormalSmall", "PRE-RUN SUPPLIES  0 / 3")
    suppliesTitle:SetPoint("TOPLEFT", 410, -184)
    suppliesTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.DungeonCentralSuppliesTitle = suppliesTitle

    local suppliesHint = CreateText(stashModal, "GameFontDisableSmall", "One item per slot. Unused supplies return only after a successful extraction.")
    suppliesHint:SetPoint("TOPLEFT", 410, -202)
    suppliesHint:SetWidth(450)
    suppliesHint:SetJustifyH("LEFT")
    suppliesHint:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    self.DungeonCentralSupplySlots = {}
    for i = 1, 3 do
        local button = CreateFrame("Button", nil, stashModal, "BackdropTemplate")
        button:SetSize(58, 58)
        button:SetPoint("TOPLEFT", 410 + ((i - 1) * 70), -224)
        ApplyBackdrop(button, { 0.025, 0.022, 0.018, 1 }, COLORS.goldDim)
        button.supplySlotIndex = i

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 4, -4)
        icon:SetPoint("BOTTOMRIGHT", -4, 4)
        icon:SetTexture("Interface\\Icons\\INV_Potion_54")
        icon:SetAlpha(0.12)
        button.icon = icon

        local number = CreateText(button, "GameFontNormalSmall", tostring(i))
        number:SetPoint("TOPLEFT", 4, -3)
        number:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

        button:SetScript("OnClick", function(selfButton)
            if selfButton.gaSupplyItem then
                GA:ReturnSelectedSupplyItem(selfButton.supplySlotIndex)
            end
        end)
        button:SetScript("OnEnter", function(selfButton)
            GameTooltip:SetOwner(selfButton, "ANCHOR_LEFT")
            local item = selfButton.gaSupplyItem
            if item then
                GameTooltip:SetText(item.name or "Prepared Supply", 1, 0.82, 0.2)
                GameTooltip:AddLine(item.description or "Prepared consumable.", 0.82, 0.79, 0.72, true)
                GameTooltip:AddLine("PRE-RUN SUPPLY", 0.25, 1.00, 0.35)
                GameTooltip:AddLine("Click to return this item to the Central Stash.", 0.82, 0.79, 0.72, true)
            else
                GameTooltip:SetText("Supply Slot " .. tostring(selfButton.supplySlotIndex), 1, 0.82, 0.2)
                GameTooltip:AddLine("Click a consumable in the stash to prepare one item here.", 0.75, 0.75, 0.75, true)
            end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.DungeonCentralSupplySlots[i] = button
    end

    local gearTitle = CreateText(stashModal, "GameFontNormalSmall", "GEAR LOADOUT")
    gearTitle:SetPoint("TOPLEFT", 410, -294)
    gearTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    self.DungeonCentralLoadoutSlots = {}
    local loadoutDefs = self.GetLoadoutSlotDefinitions and self:GetLoadoutSlotDefinitions() or {}
    for index, definition in ipairs(loadoutDefs) do
        local col = (index - 1) % 4
        local row = math.floor((index - 1) / 4)
        local button = CreateFrame("Button", nil, stashModal, "BackdropTemplate")
        button:SetSize(92, 62)
        button:SetPoint("TOPLEFT", 410 + col * 112, -316 - row * 68)
        ApplyBackdrop(button, { 0.025, 0.022, 0.018, 1 }, COLORS.goldDim)
        button.slotKey = definition.key
        button.slotLabel = definition.label

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetSize(42, 42)
        icon:SetPoint("LEFT", 6, 0)
        icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        icon:SetAlpha(0.14)
        button.icon = icon

        local label = CreateText(button, "GameFontDisableSmall", definition.label or definition.key)
        label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        label:SetPoint("RIGHT", -4, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(true)
        label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        button.label = label

        button:SetScript("OnClick", function(selfButton)
            if selfButton.gaLoadoutOverride then
                GA:ReturnSelectedLoadoutItem(selfButton.slotKey)
            end
        end)
        button:SetScript("OnEnter", function(selfButton)
            local item = selfButton.gaItem
            GameTooltip:SetOwner(selfButton, "ANCHOR_LEFT")
            GameTooltip:SetText(selfButton.slotLabel or selfButton.slotKey, 1, 0.82, 0.2)
            if item then
                GameTooltip:AddLine(item.name or "Item", 0.92, 0.89, 0.82)
                if selfButton.gaLoadoutOverride then
                    GameTooltip:AddLine("EXTRACTED LOADOUT ITEM", 0.25, 1.00, 0.35)
                    GameTooltip:AddLine("Click to return this item to the Central Stash.", 0.82, 0.79, 0.72, true)
                else
                    GameTooltip:AddLine("BASELINE - LOCKED", 1.00, 0.45, 0.20)
                    GameTooltip:AddLine("Starter / WoW baseline gear cannot be deposited into the Central Stash.", 0.82, 0.79, 0.72, true)
                end
            else
                GameTooltip:AddLine("Empty slot.", 0.65, 0.65, 0.65)
            end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.DungeonCentralLoadoutSlots[#self.DungeonCentralLoadoutSlots + 1] = button
    end

    local loadoutStatus = CreateText(stashModal, "GameFontDisableSmall", "")
    loadoutStatus:SetPoint("BOTTOMLEFT", 410, 24)
    loadoutStatus:SetWidth(360)
    loadoutStatus:SetJustifyH("LEFT")
    loadoutStatus:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonCentralLoadoutStatus = loadoutStatus

    local generatorOverlay = CreateFrame("Frame", nil, setup, "BackdropTemplate")
    generatorOverlay:SetAllPoints(setup)
    generatorOverlay:SetFrameLevel(setup:GetFrameLevel() + 60)
    generatorOverlay:EnableMouse(true)
    ApplyBackdrop(generatorOverlay, { 0.005, 0.004, 0.003, 0.82 }, { 0, 0, 0, 0 })
    generatorOverlay:Hide()
    self.DungeonCharacterGeneratorOverlay = generatorOverlay

    local generatorModal = CreateFrame("Frame", nil, generatorOverlay, "BackdropTemplate")
    generatorModal:SetSize(760, 620)
    generatorModal:SetPoint("CENTER", generatorOverlay, "CENTER", 0, 0)
    generatorModal:SetFrameLevel(generatorOverlay:GetFrameLevel() + 1)
    generatorModal:EnableMouse(true)
    ApplyBackdrop(generatorModal, { 0.050, 0.043, 0.034, 1 }, COLORS.gold)
    self.DungeonCharacterGeneratorModal = generatorModal
    self.DungeonGeneratorPanel = generatorModal

    local modalTitle = CreateText(generatorModal, "GameFontNormalHuge", "CREATE NEW CHARACTER")
    modalTitle:SetPoint("TOPLEFT", 24, -20)
    modalTitle:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

    local modalHint = CreateText(
        generatorModal,
        "GameFontHighlightSmall",
        "Create a persistent GoblinArcade hero. Races are cosmetic for now; only READY classes are selectable."
    )
    modalHint:SetPoint("TOPLEFT", modalTitle, "BOTTOMLEFT", 0, -8)
    modalHint:SetWidth(700)
    modalHint:SetJustifyH("LEFT")
    modalHint:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local nameLabel = CreateText(generatorModal, "GameFontNormalSmall", "NAME")
    nameLabel:SetPoint("TOPLEFT", 24, -82)
    nameLabel:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local nameFrame = CreateFrame("Frame", nil, generatorModal, "BackdropTemplate")
    nameFrame:SetSize(340, 32)
    nameFrame:SetPoint("TOPLEFT", 24, -102)
    ApplyBackdrop(nameFrame, { 0.025, 0.022, 0.018, 1 }, COLORS.goldDim)

    local nameInput = CreateFrame("EditBox", nil, nameFrame)
    nameInput:SetPoint("TOPLEFT", 8, -4)
    nameInput:SetPoint("BOTTOMRIGHT", -8, 4)
    nameInput:SetAutoFocus(false)
    nameInput:SetFontObject("GameFontHighlight")
    nameInput:SetMaxLetters(18)
    nameInput:SetScript("OnTextChanged", function()
        GA:RefreshCharacterGenerator()
    end)
    nameInput:SetScript("OnEscapePressed", function(box)
        box:ClearFocus()
        GA:CloseCharacterGeneratorModal()
    end)
    nameInput:SetScript("OnEnterPressed", function(box)
        box:ClearFocus()
    end)
    self.DungeonGeneratorNameInput = nameInput

    local modeLabel = CreateText(generatorModal, "GameFontNormalSmall", "PERMADEATH")
    modeLabel:SetPoint("TOPLEFT", 390, -82)
    modeLabel:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local normalMode = CreateFlatButton(generatorModal, "STANDARD", 150, 32)
    normalMode:SetPoint("TOPLEFT", 390, -102)
    normalMode:SetScript("OnClick", function()
        GA.CharacterGeneratorHardcore = false
        GA:RefreshCharacterGenerator()
    end)
    self.DungeonGeneratorNormalButton = normalMode

    local hardcoreMode = CreateFlatButton(generatorModal, "HARDCORE", 150, 32)
    hardcoreMode:SetPoint("TOPLEFT", 550, -102)
    hardcoreMode:SetScript("OnClick", function()
        GA.CharacterGeneratorHardcore = true
        GA:RefreshCharacterGenerator()
    end)
    self.DungeonGeneratorHardcoreButton = hardcoreMode

    local modeHint = CreateText(generatorModal, "GameFontDisableSmall", "Hardcore controls permanent death only.")
    modeHint:SetPoint("TOPLEFT", 390, -140)
    modeHint:SetWidth(320)
    modeHint:SetJustifyH("LEFT")
    modeHint:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local difficultyLabel = CreateText(generatorModal, "GameFontNormalSmall", "DIFFICULTY")
    difficultyLabel:SetPoint("TOPLEFT", 24, -166)
    difficultyLabel:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    self.DungeonGeneratorDifficultyButtons = {}
    local generatorDifficultyIds = { "EASY", "NORMAL", "HARD" }
    for i, difficultyId in ipairs(generatorDifficultyIds) do
        local button = CreateFlatButton(generatorModal, difficultyId, 144, 32)
        button:SetPoint("TOPLEFT", 24 + ((i - 1) * 154), -186)
        button.difficultyId = difficultyId
        button:SetScript("OnClick", function(selfButton)
            GA.CharacterGeneratorDifficulty = selfButton.difficultyId
            GA:RefreshCharacterGenerator()
        end)
        button:SetScript("OnEnter", function(selfButton)
            local definition = GA.GetDifficultyDefinition and GA:GetDifficultyDefinition(selfButton.difficultyId)
            if definition then
                GameTooltip:SetOwner(selfButton, "ANCHOR_TOP")
                GameTooltip:SetText(definition.label or selfButton.difficultyId, 1, 0.82, 0.2)
                GameTooltip:AddLine(definition.description or "", 0.85, 0.82, 0.75, true)
                GameTooltip:AddLine(string.format("Score multiplier: %.2fx", tonumber(definition.scoreMultiplier) or 1), 0.25, 1.00, 0.35)
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.DungeonGeneratorDifficultyButtons[i] = button
    end

    local difficultyHint = CreateText(generatorModal, "GameFontDisableSmall", "Difficulty changes combat strength. Hardcore remains a separate choice.")
    difficultyHint:SetPoint("TOPLEFT", 494, -190)
    difficultyHint:SetWidth(235)
    difficultyHint:SetJustifyH("LEFT")
    difficultyHint:SetWordWrap(true)
    difficultyHint:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local raceLabel = CreateText(generatorModal, "GameFontNormalSmall", "RACE")
    raceLabel:SetPoint("TOPLEFT", 24, -236)
    raceLabel:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    self.DungeonGeneratorRaceButtons = {}
    for i = 1, 10 do
        local col = (i - 1) % 5
        local row = math.floor((i - 1) / 5)
        local button = CreateFrame("Button", nil, generatorModal, "BackdropTemplate")
        button:SetSize(132, 62)
        button:SetPoint("TOPLEFT", 24 + col * 142, -258 - row * 70)
        ApplyBackdrop(button, { 0.040, 0.035, 0.028, 1 }, COLORS.goldDim)

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetSize(38, 38)
        icon:SetPoint("LEFT", 8, 0)
        icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
        button.icon = icon

        local label = CreateText(button, "GameFontDisableSmall", "")
        label:SetPoint("LEFT", icon, "RIGHT", 7, 0)
        label:SetPoint("RIGHT", -6, 0)
        label:SetJustifyH("LEFT")
        button.label = label

        button:SetScript("OnClick", function(selfButton)
            if selfButton.raceId then
                GA.CharacterGeneratorRaceId = selfButton.raceId
                GA:RefreshCharacterGenerator()
            end
        end)
        button:SetScript("OnEnter", function(selfButton)
            if selfButton.raceName then
                GameTooltip:SetOwner(selfButton, "ANCHOR_TOP")
                GameTooltip:SetText(selfButton.raceName, 1, 0.82, 0.2)
                GameTooltip:AddLine("Cosmetic race choice. No racial bonus yet.", 0.9, 0.9, 0.9, true)
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.DungeonGeneratorRaceButtons[i] = button
    end

    local classLabel = CreateText(generatorModal, "GameFontNormalSmall", "CLASS")
    classLabel:SetPoint("TOPLEFT", 24, -412)
    classLabel:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    self.DungeonGeneratorClassButtons = {}
    for i = 1, 9 do
        local col = (i - 1) % 5
        local row = math.floor((i - 1) / 5)
        local button = CreateFrame("Button", nil, generatorModal, "BackdropTemplate")
        button:SetSize(132, 58)
        button:SetPoint("TOPLEFT", 24 + col * 142, -434 - row * 66)
        ApplyBackdrop(button, { 0.040, 0.035, 0.028, 1 }, COLORS.goldDim)

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetSize(36, 36)
        icon:SetPoint("LEFT", 8, 0)
        button.icon = icon

        local label = CreateText(button, "GameFontDisableSmall", "")
        label:SetPoint("LEFT", icon, "RIGHT", 7, 0)
        label:SetPoint("RIGHT", -6, 0)
        label:SetJustifyH("LEFT")
        button.label = label

        button:SetScript("OnClick", function(selfButton)
            if selfButton.classId and selfButton.playable then
                GA.CharacterGeneratorClassId = selfButton.classId
                GA:RefreshCharacterGenerator()
            end
        end)
        button:SetScript("OnEnter", function(selfButton)
            if selfButton.className then
                GameTooltip:SetOwner(selfButton, "ANCHOR_TOP")
                GameTooltip:SetText(selfButton.className, 1, 0.82, 0.2)
                if selfButton.playable then
                    GameTooltip:AddLine("Ready for GoblinArcade.", 0.35, 1, 0.35)
                else
                    GameTooltip:AddLine("Not implemented yet.", 1, 0.35, 0.35)
                end
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.DungeonGeneratorClassButtons[i] = button
    end

    local generatorStatus = CreateText(generatorModal, "GameFontDisableSmall", "")
    generatorStatus:SetPoint("BOTTOMLEFT", 24, 24)
    generatorStatus:SetWidth(360)
    generatorStatus:SetJustifyH("LEFT")
    generatorStatus:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonGeneratorStatus = generatorStatus

    local cancelHero = CreateFlatButton(generatorModal, "CANCEL", 130, 36)
    cancelHero:SetPoint("BOTTOMRIGHT", -184, 18)
    cancelHero:SetScript("OnClick", function()
        GA:CloseCharacterGeneratorModal()
    end)

    local createHero = CreateFlatButton(generatorModal, "CREATE HERO", 160, 36)
    createHero:SetPoint("BOTTOMRIGHT", -18, 18)
    createHero:SetScript("OnClick", function()
        local character, err = GA:CreateArcadeCharacter(
            GA.DungeonGeneratorNameInput and GA.DungeonGeneratorNameInput:GetText() or "",
            GA.CharacterGeneratorRaceId,
            GA.CharacterGeneratorClassId,
            GA.CharacterGeneratorHardcore == true,
            GA.CharacterGeneratorDifficulty
        )
        if character then
            if GA.DungeonGeneratorNameInput then
                GA.DungeonGeneratorNameInput:SetText("")
            end
            GA:CloseCharacterGeneratorModal()
            GA:RefreshDungeonCharacterSelection()
        elseif GA.DungeonGeneratorStatus then
            GA.DungeonGeneratorStatus:SetText(err or "Character creation failed.")
            GA.DungeonGeneratorStatus:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
        end
    end)
    self.DungeonGeneratorCreateButton = createHero

    local summaryOverlay = CreateFrame("Frame", nil, page, "BackdropTemplate")
    summaryOverlay:SetAllPoints(page)
    summaryOverlay:SetFrameLevel(page:GetFrameLevel() + 100)
    summaryOverlay:EnableMouse(true)
    ApplyBackdrop(summaryOverlay, { 0.005, 0.004, 0.003, 0.90 }, { 0, 0, 0, 0 })
    summaryOverlay:Hide()
    self.DungeonRunSummaryOverlay = summaryOverlay

    local summaryModal = CreateFrame("Frame", nil, summaryOverlay, "BackdropTemplate")
    summaryModal:SetSize(640, 560)
    summaryModal:SetPoint("CENTER")
    ApplyBackdrop(summaryModal, { 0.040, 0.034, 0.027, 1 }, COLORS.goldDim)

    local summaryTitle = CreateText(summaryModal, "GameFontNormalHuge", "RUN COMPLETE")
    summaryTitle:SetPoint("TOP", 0, -26)
    self.DungeonRunSummaryTitle = summaryTitle

    local summaryOutcome = CreateText(summaryModal, "GameFontNormalLarge", "")
    summaryOutcome:SetPoint("TOP", summaryTitle, "BOTTOM", 0, -10)
    self.DungeonRunSummaryOutcome = summaryOutcome

    local summaryReason = CreateText(summaryModal, "GameFontHighlightSmall", "")
    summaryReason:SetPoint("TOP", summaryOutcome, "BOTTOM", 0, -8)
    summaryReason:SetWidth(560)
    summaryReason:SetJustifyH("CENTER")
    summaryReason:SetWordWrap(true)
    summaryReason:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonRunSummaryReason = summaryReason

    local summaryStatsLabel = CreateText(summaryModal, "GameFontNormalSmall", "RUN SUMMARY")
    summaryStatsLabel:SetPoint("TOPLEFT", 34, -132)
    summaryStatsLabel:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local summaryStats = CreateText(summaryModal, "GameFontHighlight", "")
    summaryStats:SetPoint("TOPLEFT", 34, -158)
    summaryStats:SetWidth(250)
    summaryStats:SetJustifyH("LEFT")
    summaryStats:SetJustifyV("TOP")
    summaryStats:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    self.DungeonRunSummaryStats = summaryStats

    local summaryLootLabel = CreateText(summaryModal, "GameFontNormalSmall", "LOOT ACQUIRED")
    summaryLootLabel:SetPoint("TOPLEFT", 330, -132)
    summaryLootLabel:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.DungeonRunSummaryLootLabel = summaryLootLabel

    local summaryLoot = CreateText(summaryModal, "GameFontHighlight", "")
    summaryLoot:SetPoint("TOPLEFT", 330, -158)
    summaryLoot:SetWidth(270)
    summaryLoot:SetJustifyH("LEFT")
    summaryLoot:SetJustifyV("TOP")
    summaryLoot:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    self.DungeonRunSummaryLoot = summaryLoot

    local scoreLabel = CreateText(summaryModal, "GameFontNormalSmall", "SCORE BREAKDOWN")
    scoreLabel:SetPoint("BOTTOMLEFT", 34, 102)
    scoreLabel:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local summaryScore = CreateText(summaryModal, "GameFontHighlightSmall", "")
    summaryScore:SetPoint("BOTTOMLEFT", 34, 78)
    summaryScore:SetWidth(572)
    summaryScore:SetJustifyH("LEFT")
    summaryScore:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonRunSummaryScore = summaryScore

    local backToCharacters = CreateFlatButton(summaryModal, "BACK TO CHARACTERS", 220, 40)
    backToCharacters:SetPoint("BOTTOM", 0, 22)
    backToCharacters:SetScript("OnClick", function()
        GA:ReturnToDungeonCharacters()
    end)
    self.DungeonRunSummaryBackButton = backToCharacters

    if self.CreateCharacterSheet then
        self:CreateCharacterSheet(page)
    end

    page:EnableKeyboard(true)
    if page.SetPropagateKeyboardInput then
        page:SetPropagateKeyboardInput(true)
    end

    page:SetScript("OnKeyDown", function(pageFrame, key)
        local runActive = GA.RunState and GA.RunState.active

        if not runActive and GA.DungeonCentralStashOverlay and GA.DungeonCentralStashOverlay:IsShown() then
            if key == "ESCAPE" then
                GA:CloseCentralStash()
            end
            if pageFrame.SetPropagateKeyboardInput then
                pageFrame:SetPropagateKeyboardInput(false)
            end
            return
        end

        if not runActive and GA.DungeonCharacterGeneratorOverlay and GA.DungeonCharacterGeneratorOverlay:IsShown() then
            if key == "ESCAPE" then
                GA:CloseCharacterGeneratorModal()
            end
            if pageFrame.SetPropagateKeyboardInput then
                pageFrame:SetPropagateKeyboardInput(false)
            end
            return
        end

        if not runActive then
            if pageFrame.SetPropagateKeyboardInput then
                pageFrame:SetPropagateKeyboardInput(true)
            end
            return
        end

        -- The propagation state is already disabled when the run begins. Keep
        -- it disabled for the entire run so WoW never receives movement keys.
        if pageFrame.SetPropagateKeyboardInput then
            pageFrame:SetPropagateKeyboardInput(false)
        end

        if GA.DungeonRunControlFrame and GA.DungeonRunControlFrame:IsShown() then
            if key == "ESCAPE" then
                GA:CloseRunControlMenu()
            end
            return
        end

        if GA.DungeonShopFrame and GA.DungeonShopFrame:IsShown() then
            if key == "ESCAPE" then
                GA:CloseDungeonShop()
            elseif key == "1" or key == "2" or key == "3" or key == "4" then
                GA:BuyDungeonShopItem(tonumber(key))
            end
            return
        end

        if GA.DungeonEventFrame and GA.DungeonEventFrame:IsShown() then
            -- An Event must be resolved with a data-authored choice. ESC is
            -- consumed; use an explicit NONE / Turn Away option when desired.
            if key == "1" or key == "2" or key == "3" or key == "4" then
                GA:ChooseDungeonEventOption(tonumber(key))
            end
            return
        end

        if GA.DungeonShrineFrame and GA.DungeonShrineFrame:IsShown() then
            if key == "1" then
                GA:ChooseShrineGift("restore")
            elseif key == "2" then
                GA:ChooseShrineGift("blessing")
            elseif key == "3" then
                GA:ChooseShrineGift("sacrifice")
            elseif key == "ESCAPE" then
                GA:CloseShrineChoice()
            end
            return
        end

        if GA.DungeonSpellbookFrame and GA.DungeonSpellbookFrame:IsShown() then
            if key == "ESCAPE" or key == "B" then
                GA:CloseSpellbook()
            end
            return
        end

        if key == "B" then
            GA:ToggleSpellbook()
            return
        end

        if key == "C" then
            GA:CloseSpellbook()
            GA:ToggleCharacterSheet()
            return
        end

        if GA.CharacterSheetFrame and GA.CharacterSheetFrame:IsShown() then
            if key == "ESCAPE" then
                GA.CharacterSheetFrame:Hide()
                GA:CancelCharacterItemDrag()
            end
            return
        end

        if key == "ESCAPE" then
            GA:OpenRunControlMenu()
            return
        end

        if key == "1" then
            GA:PlayerAttackEnemy()
            return
        elseif key == "2" or key == "3" or key == "4" or key == "5"
            or key == "6" or key == "7" or key == "8" or key == "9" then
            GA:UseRunActionSlot(tonumber(key) - 1)
            return
        elseif key == "0" then
            GA:UseRunPotion()
            return
        end

        local movement = {
            W = { 0, -1 },
            UP = { 0, -1 },
            S = { 0, 1 },
            DOWN = { 0, 1 },
            A = { -1, 0 },
            LEFT = { -1, 0 },
            D = { 1, 0 },
            RIGHT = { 1, 0 },
        }

        local delta = movement[key]
        if delta then
            GA:MoveDungeonPlayer(delta[1], delta[2])
        end
    end)

    self:RenderDungeonGrid()
    self:SetDungeonSetupMode(true)
    return page
end

function GA:CloseCentralStash()
    if self.DungeonCentralStashOverlay then
        self.DungeonCentralStashOverlay:Hide()
    end
end

function GA:RefreshCentralStash()
    local stash = self.GetCentralStash and self:GetCentralStash() or {}
    local slotsPerPage = #(self.DungeonCentralStashSlots or {})
    if slotsPerPage <= 0 then return end

    local pageCount = math.max(1, math.ceil(#stash / slotsPerPage))
    self.DungeonCentralStashPage = math.max(1, math.min(pageCount, tonumber(self.DungeonCentralStashPage) or 1))
    local firstIndex = ((self.DungeonCentralStashPage - 1) * slotsPerPage) + 1

    for slotIndex, button in ipairs(self.DungeonCentralStashSlots or {}) do
        local absoluteIndex = firstIndex + slotIndex - 1
        local item = stash[absoluteIndex]
        button.gaStashItem = item
        button.gaStashIndex = item and absoluteIndex or nil
        if item then
            button.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            button.icon:SetAlpha(1)
            local count = math.max(1, math.floor(tonumber(item.stackCount) or 1))
            button.countText:SetText(count > 1 and tostring(count) or "")
        else
            button.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
            button.icon:SetAlpha(0.12)
            button.countText:SetText("")
        end
    end

    if self.DungeonCentralStashCount then
        local itemCount = self.GetCentralStashItemCount and self:GetCentralStashItemCount() or #stash
        self.DungeonCentralStashCount:SetText(
            string.format("%d ITEM%s  -  %d SLOT%s", itemCount, itemCount == 1 and "" or "S", #stash, #stash == 1 and "" or "S")
        )
    end
    if self.DungeonCentralStashButton and self.GetCentralStashItemCount then
        self.DungeonCentralStashButton.label:SetText(
            string.format("CENTRAL STASH  %d", self:GetCentralStashItemCount())
        )
    end
    if self.DungeonCentralStashPageText then
        self.DungeonCentralStashPageText:SetText(string.format("PAGE %d / %d", self.DungeonCentralStashPage, pageCount))
    end
    if self.DungeonCentralStashPrev then self.DungeonCentralStashPrev:SetEnabled(self.DungeonCentralStashPage > 1) end
    if self.DungeonCentralStashNext then self.DungeonCentralStashNext:SetEnabled(self.DungeonCentralStashPage < pageCount) end

    local selected = self.GetSelectedDungeonCharacter and self:GetSelectedDungeonCharacter()
    if self.DungeonCentralLoadoutName then
        self.DungeonCentralLoadoutName:SetText(
            selected and string.format("%s  -  %s", selected.name or "Unknown", selected.className or "Adventurer")
            or "No character selected"
        )
    end

    local loadout = selected and selected.arcadeLoadout or {}
    local baseline = selected and selected.equipment or {}
    for _, button in ipairs(self.DungeonCentralLoadoutSlots or {}) do
        local override = loadout and loadout[button.slotKey]
        local baseItem = baseline and baseline[button.slotKey]
        local item = override or baseItem
        button.gaItem = item
        button.gaLoadoutOverride = override ~= nil

        if item then
            button.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            button.icon:SetAlpha(override and 1 or 0.30)
            button.label:SetText(button.slotLabel or button.slotKey)
            button.label:SetTextColor(
                override and COLORS.text[1] or COLORS.muted[1],
                override and COLORS.text[2] or COLORS.muted[2],
                override and COLORS.text[3] or COLORS.muted[3]
            )
            button:SetBackdropBorderColor(
                override and COLORS.gold[1] or COLORS.goldDim[1],
                override and COLORS.gold[2] or COLORS.goldDim[2],
                override and COLORS.gold[3] or COLORS.goldDim[3],
                1
            )
        else
            button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            button.icon:SetAlpha(0.12)
            button.label:SetText(button.slotLabel or button.slotKey)
            button.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
            button:SetBackdropBorderColor(COLORS.goldDim[1], COLORS.goldDim[2], COLORS.goldDim[3], 1)
        end
    end

    local supplies = selected and selected.arcadeSupplies or {}
    local supplyCount = 0
    for i, button in ipairs(self.DungeonCentralSupplySlots or {}) do
        local item = supplies and supplies[i]
        button.gaSupplyItem = item
        if item then
            supplyCount = supplyCount + 1
            button.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Potion_54")
            button.icon:SetAlpha(1)
            button:SetBackdropBorderColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1)
        else
            button.icon:SetTexture("Interface\\Icons\\INV_Potion_54")
            button.icon:SetAlpha(0.12)
            button:SetBackdropBorderColor(COLORS.goldDim[1], COLORS.goldDim[2], COLORS.goldDim[3], 1)
        end
    end
    if self.DungeonCentralSuppliesTitle then
        self.DungeonCentralSuppliesTitle:SetText(string.format("PRE-RUN SUPPLIES  %d / 3", supplyCount))
    end
end

function GA:AssignSelectedCentralStashSupply(stashIndex)
    local selected = self.GetSelectedDungeonCharacter and self:GetSelectedDungeonCharacter()
    if not selected or not self.AssignCentralStashSupply then return false end

    local ok, result = self:AssignCentralStashSupply(selected.key, stashIndex)
    if self.DungeonCentralLoadoutStatus then
        self.DungeonCentralLoadoutStatus:SetText(
            ok
                and ("Prepared supply slot " .. tostring(result or "?") .. ".")
                or tostring(result or "Could not prepare that supply.")
        )
        self.DungeonCentralLoadoutStatus:SetTextColor(
            ok and COLORS.green[1] or COLORS.red[1],
            ok and COLORS.green[2] or COLORS.red[2],
            ok and COLORS.green[3] or COLORS.red[3]
        )
    end
    self:RefreshCentralStash()
    self:RefreshDungeonCharacterSelection()
    return ok
end

function GA:ReturnSelectedSupplyItem(slotIndex)
    local selected = self.GetSelectedDungeonCharacter and self:GetSelectedDungeonCharacter()
    if not selected or not self.ReturnCharacterSupplyToStash then return false end

    local ok, result = self:ReturnCharacterSupplyToStash(selected.key, slotIndex)
    if self.DungeonCentralLoadoutStatus then
        self.DungeonCentralLoadoutStatus:SetText(
            ok
                and ("Supply slot " .. tostring(slotIndex) .. " returned to Central Stash.")
                or tostring(result or "Could not return that supply.")
        )
        self.DungeonCentralLoadoutStatus:SetTextColor(
            ok and COLORS.green[1] or COLORS.red[1],
            ok and COLORS.green[2] or COLORS.red[2],
            ok and COLORS.green[3] or COLORS.red[3]
        )
    end
    self:RefreshCentralStash()
    self:RefreshDungeonCharacterSelection()
    return ok
end

function GA:EquipSelectedCentralStashItem(stashIndex)
    local selected = self.GetSelectedDungeonCharacter and self:GetSelectedDungeonCharacter()
    if not selected or not self.EquipCentralStashItem then return false end

    local ok, result = self:EquipCentralStashItem(selected.key, stashIndex)
    if self.DungeonCentralLoadoutStatus then
        self.DungeonCentralLoadoutStatus:SetText(
            ok
                and ("Equipped extracted item to " .. tostring(result or "loadout") .. ".")
                or tostring(result or "Could not equip that item.")
        )
        self.DungeonCentralLoadoutStatus:SetTextColor(
            ok and COLORS.green[1] or COLORS.red[1],
            ok and COLORS.green[2] or COLORS.red[2],
            ok and COLORS.green[3] or COLORS.red[3]
        )
    end
    self:RefreshCentralStash()
    self:RefreshDungeonCharacterSelection()
    return ok
end

function GA:ReturnSelectedLoadoutItem(slotKey)
    local selected = self.GetSelectedDungeonCharacter and self:GetSelectedDungeonCharacter()
    if not selected or not self.ReturnCharacterLoadoutItemToStash then return false end

    local ok, result = self:ReturnCharacterLoadoutItemToStash(selected.key, slotKey)
    if self.DungeonCentralLoadoutStatus then
        self.DungeonCentralLoadoutStatus:SetText(
            ok
                and ((tostring(slotKey or "Item")) .. " returned to Central Stash.")
                or tostring(result or "Could not return that item.")
        )
        self.DungeonCentralLoadoutStatus:SetTextColor(
            ok and COLORS.green[1] or COLORS.red[1],
            ok and COLORS.green[2] or COLORS.red[2],
            ok and COLORS.green[3] or COLORS.red[3]
        )
    end
    self:RefreshCentralStash()
    self:RefreshDungeonCharacterSelection()
    return ok
end

function GA:OpenCentralStash()
    if not self.DungeonCentralStashOverlay then return end
    self:CloseCharacterGeneratorModal()
    self.DungeonCentralStashPage = 1
    if self.DungeonCentralLoadoutStatus then self.DungeonCentralLoadoutStatus:SetText("") end
    self:RefreshCentralStash()
    self.DungeonCentralStashOverlay:Show()
end

function GA:ChangeCentralStashPage(delta)
    self.DungeonCentralStashPage = math.max(1, (tonumber(self.DungeonCentralStashPage) or 1) + (tonumber(delta) or 0))
    self:RefreshCentralStash()
end

function GA:ClearDungeonGridVisuals()
    local grid = self.DungeonGrid
    if not grid or not grid.cells then
        if self.DungeonEnemyCard then self.DungeonEnemyCard:Hide() end
        return
    end

    for _, entry in pairs(grid.cells) do
        if entry.enemyIcon then entry.enemyIcon:Hide() end
        if entry.enemyHealthBackdrop then entry.enemyHealthBackdrop:Hide() end
        if entry.enemySkillIcon then entry.enemySkillIcon:Hide() end
        if entry.lootIcon then entry.lootIcon:Hide() end
        if entry.eventIcon then entry.eventIcon:Hide() end
        if entry.marker then entry.marker:SetText("") end
    end

    if self.DungeonEnemyCard then
        self.DungeonEnemyCard:Hide()
    end
end

function GA:SetDungeonSetupMode(active)
    if not self.DungeonSetupFrame then
        return
    end

    if active then
        self:ClearDungeonGridVisuals()
        if self.DungeonGrid then
            self.DungeonGrid:Hide()
        end
        if self.DungeonGrid and self.DungeonGrid.spriteLayer then
            self.DungeonGrid.spriteLayer:Hide()
        end
        self:CloseCharacterGeneratorModal()
        self:CloseCentralStash()
        self.DungeonSetupFrame:Show()
        self:SetRunMode(false)
        self:RefreshDungeonCharacterSelection()
        if self.DungeonCentralStashButton and self.GetCentralStashItemCount then
            local count = self:GetCentralStashItemCount()
            self.DungeonCentralStashButton.label:SetText(string.format("CENTRAL STASH  %d", count))
        end
    else
        self:CloseCharacterGeneratorModal()
        self:CloseCentralStash()
        self.DungeonSetupFrame:Hide()
        if self.DungeonGrid then
            self.DungeonGrid:Show()
        end
        if self.DungeonGrid and self.DungeonGrid.spriteLayer then
            self.DungeonGrid.spriteLayer:Show()
        end
    end
end

function GA:OpenCharacterGeneratorModal()
    if not self.DungeonCharacterGeneratorOverlay then return end
    self.CharacterGeneratorRaceId = nil
    self.CharacterGeneratorClassId = nil
    self.CharacterGeneratorHardcore = false
    self.CharacterGeneratorDifficulty = "NORMAL"
    if self.DungeonGeneratorNameInput then
        self.DungeonGeneratorNameInput:SetText("")
        self.DungeonGeneratorNameInput:ClearFocus()
    end
    self:RefreshCharacterGenerator()
    self.DungeonCharacterGeneratorOverlay:Show()
end

function GA:CloseCharacterGeneratorModal()
    if self.DungeonGeneratorNameInput then
        self.DungeonGeneratorNameInput:ClearFocus()
    end
    if self.DungeonCharacterGeneratorOverlay then
        self.DungeonCharacterGeneratorOverlay:Hide()
    end
end

function GA:RefreshCharacterGenerator()
    if not self.DungeonCharacterGeneratorModal then return end

    local races = self.GetStudioRaces and self:GetStudioRaces() or {}
    local classes = self.GetStudioClasses and self:GetStudioClasses() or {}

    if not self.CharacterGeneratorRaceId and races[1] then
        self.CharacterGeneratorRaceId = races[1].id
    end

    if not self.CharacterGeneratorClassId
        or not (self.IsStudioClassPlayable and self:IsStudioClassPlayable(self.CharacterGeneratorClassId)) then
        self.CharacterGeneratorClassId = nil
        for _, class in ipairs(classes) do
            if self:IsStudioClassPlayable(class.id) then
                self.CharacterGeneratorClassId = class.id
                break
            end
        end
    end

    for i, button in ipairs(self.DungeonGeneratorRaceButtons or {}) do
        local race = races[i]
        if race then
            button.raceId = race.id
            button.raceName = race.name or race.id
            button.label:SetText(string.upper(race.shortName or race.name or race.id or "RACE"))
            button.icon:SetTexture(
                self:ResolveStudioIconTexture(race.icon, "Interface\\Icons\\INV_Misc_QuestionMark")
            )
            button.icon:SetVertexColor(1, 1, 1)
            button:Enable()
            button:Show()
            local selected = race.id == self.CharacterGeneratorRaceId
            button:SetBackdropColor(selected and 0.15 or 0.040, selected and 0.105 or 0.035, selected and 0.045 or 0.028, 1)
            button:SetBackdropBorderColor(
                selected and COLORS.gold[1] or COLORS.goldDim[1],
                selected and COLORS.gold[2] or COLORS.goldDim[2],
                selected and COLORS.gold[3] or COLORS.goldDim[3],
                1
            )
        else
            button.raceId = nil
            button.raceName = nil
            button:Hide()
        end
    end

    for i, button in ipairs(self.DungeonGeneratorClassButtons or {}) do
        local class = classes[i]
        if class then
            local playable = self:IsStudioClassPlayable(class.id)
            button.classId = class.id
            button.className = class.name or class.id
            button.playable = playable
            button.label:SetText(string.upper(class.shortName or class.name or class.id or "CLASS"))
            SetGeneratorClassVisual(button.icon, class.id)
            button.icon:SetVertexColor(playable and 1 or 0.25, playable and 1 or 0.25, playable and 1 or 0.25)
            button:SetEnabled(playable)
            button:Show()
            local selected = playable and class.id == self.CharacterGeneratorClassId
            button:SetBackdropColor(selected and 0.15 or 0.040, selected and 0.105 or 0.035, selected and 0.045 or 0.028, 1)
            button:SetBackdropBorderColor(
                selected and COLORS.gold[1] or COLORS.goldDim[1],
                selected and COLORS.gold[2] or COLORS.goldDim[2],
                selected and COLORS.gold[3] or COLORS.goldDim[3],
                1
            )
            button.label:SetTextColor(
                playable and COLORS.text[1] or COLORS.muted[1],
                playable and COLORS.text[2] or COLORS.muted[2],
                playable and COLORS.text[3] or COLORS.muted[3]
            )
        else
            button.classId = nil
            button:Hide()
        end
    end

    local hardcore = self.CharacterGeneratorHardcore == true
    if self.DungeonGeneratorNormalButton then
        self.DungeonGeneratorNormalButton:SetBackdropColor(
            hardcore and 0.040 or 0.15,
            hardcore and 0.035 or 0.105,
            hardcore and 0.028 or 0.045,
            1
        )
        self.DungeonGeneratorNormalButton:SetBackdropBorderColor(
            hardcore and COLORS.goldDim[1] or COLORS.gold[1],
            hardcore and COLORS.goldDim[2] or COLORS.gold[2],
            hardcore and COLORS.goldDim[3] or COLORS.gold[3],
            1
        )
    end
    if self.DungeonGeneratorHardcoreButton then
        self.DungeonGeneratorHardcoreButton:SetBackdropColor(
            hardcore and 0.20 or 0.040,
            hardcore and 0.045 or 0.035,
            hardcore and 0.035 or 0.028,
            1
        )
        self.DungeonGeneratorHardcoreButton:SetBackdropBorderColor(
            hardcore and COLORS.red[1] or COLORS.goldDim[1],
            hardcore and COLORS.red[2] or COLORS.goldDim[2],
            hardcore and COLORS.red[3] or COLORS.goldDim[3],
            1
        )
    end

    local generatorDifficulty = self.NormalizeDifficulty
        and self:NormalizeDifficulty(self.CharacterGeneratorDifficulty)
        or "NORMAL"
    self.CharacterGeneratorDifficulty = generatorDifficulty
    for _, button in ipairs(self.DungeonGeneratorDifficultyButtons or {}) do
        local selected = button.difficultyId == generatorDifficulty
        button:SetBackdropColor(
            selected and 0.15 or 0.040,
            selected and 0.105 or 0.035,
            selected and 0.045 or 0.028,
            1
        )
        button:SetBackdropBorderColor(
            selected and COLORS.gold[1] or COLORS.goldDim[1],
            selected and COLORS.gold[2] or COLORS.goldDim[2],
            selected and COLORS.gold[3] or COLORS.goldDim[3],
            1
        )
    end

    local name = self.DungeonGeneratorNameInput and self.DungeonGeneratorNameInput:GetText() or ""
    local canCreate = name:match("%S")
        and self.CharacterGeneratorRaceId
        and self.CharacterGeneratorClassId
        and self:IsStudioClassPlayable(self.CharacterGeneratorClassId)

    if self.DungeonGeneratorCreateButton then
        self.DungeonGeneratorCreateButton:SetEnabled(canCreate and true or false)
        self.DungeonGeneratorCreateButton.label:SetTextColor(
            canCreate and COLORS.gold[1] or COLORS.muted[1],
            canCreate and COLORS.gold[2] or COLORS.muted[2],
            canCreate and COLORS.gold[3] or COLORS.muted[3]
        )
    end

    if self.DungeonGeneratorStatus then
        local difficultyDefinition = self.GetDifficultyDefinition
            and self:GetDifficultyDefinition(generatorDifficulty)
            or { label = generatorDifficulty }
        self.DungeonGeneratorStatus:SetText(string.format(
            "%s  •  %s DIFFICULTY",
            hardcore and "HARDCORE PERMADEATH" or "STANDARD DEATH",
            string.upper(difficultyDefinition.label or generatorDifficulty)
        ))
        self.DungeonGeneratorStatus:SetTextColor(
            hardcore and COLORS.red[1] or COLORS.muted[1],
            hardcore and COLORS.red[2] or COLORS.muted[2],
            hardcore and COLORS.red[3] or COLORS.muted[3]
        )
    end
end

function GA:RefreshDungeonCharacterSelection()
    if not self.DungeonSetupFrame or not self.GetCharacterRoster then
        return
    end

    self:RefreshCharacterGenerator()

    local roster = self:GetCharacterRoster()
    local currentKey = self:GetCurrentCharacterKey()
    local selected = self:GetSelectedDungeonCharacter()

    if not selected and #roster > 0 then
        self:SelectDungeonCharacter(roster[1].key)
        return
    end

    local offset = self.DungeonRosterOffset or 0
    local virtualCount = #roster + 1
    local maxOffset = math.max(0, virtualCount - #self.DungeonCharacterRows)
    if offset > maxOffset then
        offset = maxOffset
        self.DungeonRosterOffset = offset
    end

    for i, row in ipairs(self.DungeonCharacterRows or {}) do
        local virtualIndex = offset + i
        local character = roster[virtualIndex]
        local isCreateSlot = virtualIndex == (#roster + 1)

        if character then
            row.characterKey = character.key
            row.createCharacterSlot = false
            row:Show()
            SetCharacterVisual(row.icon, character)
            row.nameText:SetText(character.name or "Unknown")
            local characterClassId = string.lower(tostring(character.classId or character.classFile or character.className or ""))
            local classReady = self:IsStudioClassPlayable(characterClassId)
            local difficultyId = self.NormalizeDifficulty and self:NormalizeDifficulty(character.difficulty) or "NORMAL"
            local difficultyTag = "  -  " .. difficultyId
            local hardcoreTag = character.hardcore and "  -  HC" or ""
            local deadTag = character.dead and "  -  DEAD" or ""
            local savedRun = self.GetSuspendedRun and self:GetSuspendedRun(character.key)
            local savedTag = savedRun and string.format("  -  SAVED F%d", tonumber(savedRun.floor) or 1) or ""
            row.metaText:SetText(string.format(
                "Level %d %s %s%s%s%s%s%s",
                character.level or 0,
                character.raceName or "",
                character.className or "Adventurer",
                character.key == currentKey and "  -  CURRENT" or "",
                difficultyTag,
                hardcoreTag,
                deadTag,
                savedTag,
                classReady and "" or "  -  NOT READY"
            ))
            local rowAvailable = classReady and not character.dead
            row.icon:SetVertexColor(
                rowAvailable and 1 or 0.25,
                rowAvailable and 1 or 0.25,
                rowAvailable and 1 or 0.25
            )

            if character.dead and character.hardcore then
                row:SetBackdropColor(0.16, 0.025, 0.020, 1)
                row:SetBackdropBorderColor(COLORS.red[1], COLORS.red[2], COLORS.red[3], 1)
            elseif selected and character.key == selected.key then
                row:SetBackdropColor(0.15, 0.105, 0.045, 1)
                row:SetBackdropBorderColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1)
            else
                row:SetBackdropColor(0.060, 0.052, 0.042, 1)
                row:SetBackdropBorderColor(COLORS.goldDim[1], COLORS.goldDim[2], COLORS.goldDim[3], 1)
            end
        elseif isCreateSlot then
            row.characterKey = nil
            row.createCharacterSlot = true
            row:Show()
            row.icon:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
            row.icon:SetTexCoord(0, 1, 0, 1)
            row.icon:SetVertexColor(1, 1, 1)
            row.nameText:SetText("+  CREATE NEW CHARACTER")
            row.metaText:SetText("Create a persistent GoblinArcade hero")
            row.nameText:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
            row.metaText:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
            row:SetBackdropColor(0.048, 0.043, 0.035, 1)
            row:SetBackdropBorderColor(COLORS.goldDim[1], COLORS.goldDim[2], COLORS.goldDim[3], 1)
        else
            row.characterKey = nil
            row.createCharacterSlot = false
            row:Hide()
        end
    end

    if not selected then
        return
    end

    SetCharacterVisual(self.DungeonSelectedCharacterIcon, selected)
    self.DungeonSelectedCharacterName:SetText(selected.name or "Unknown")
    self.DungeonSelectedCharacterMeta:SetText(string.format(
        "Level %d %s %s  -  %s  -  %s%s%s",
        selected.level or 0,
        selected.raceName or "",
        selected.className or "Adventurer",
        selected.realm or "Unknown Realm",
        self.NormalizeDifficulty and self:NormalizeDifficulty(selected.difficulty) or "NORMAL",
        selected.hardcore and "  -  HARDCORE" or "",
        selected.dead and "  -  DEAD" or ""
    ))
    if selected.isArcadeGenerated or selected.sourceType == "arcade" then
        if selected.dead and selected.hardcore then
            self.DungeonSelectedCharacterSource:SetText("HARDCORE HERO - DEAD")
            if self.DungeonSelectedNote then
                self.DungeonSelectedNote:SetText(
                    string.format(
                        "Died on Floor %d. %s",
                        tonumber(selected.deathFloor) or 1,
                        selected.deathReason or "This hero fell in the dungeon."
                    )
                )
                self.DungeonSelectedNote:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
            end
        else
            self.DungeonSelectedCharacterSource:SetText(
                selected.hardcore and "ARCADE HERO - HARDCORE" or "ARCADE HERO - NORMAL"
            )
            if self.DungeonSelectedNote then
                self.DungeonSelectedNote:SetText(
                    selected.hardcore
                        and "Hardcore hero: death in a run is permanent."
                        or "Generated hero: failed runs are not permanent."
                )
                self.DungeonSelectedNote:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
            end
        end
    elseif selected.key == currentKey then
        self.DungeonSelectedCharacterSource:SetText("CURRENT CHARACTER - LIVE DATA")
        if self.DungeonSelectedNote then
            self.DungeonSelectedNote:SetText("Current character data is read live from WoW.")
            self.DungeonSelectedNote:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        end
    else
        self.DungeonSelectedCharacterSource:SetText("ALT - LAST SYNCED DATA")
        if self.DungeonSelectedNote then
            self.DungeonSelectedNote:SetText("To refresh an alt's gear, log into that character once and open GoblinArcade.")
            self.DungeonSelectedNote:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        end
    end

    local generated = selected.isArcadeGenerated or selected.sourceType == "arcade"
    local hasSavedRun = self.HasSuspendedRun and self:HasSuspendedRun(selected.key)
    local selectedDifficulty = self.NormalizeDifficulty and self:NormalizeDifficulty(selected.difficulty) or "NORMAL"
    for _, button in ipairs(self.DungeonSelectedDifficultyButtons or {}) do
        local activeDifficulty = button.difficultyId == selectedDifficulty
        local locked = hasSavedRun or selected.dead
        button:SetEnabled(not locked)
        button:SetBackdropColor(
            activeDifficulty and 0.15 or 0.040,
            activeDifficulty and 0.105 or 0.035,
            activeDifficulty and 0.045 or 0.028,
            1
        )
        button:SetBackdropBorderColor(
            activeDifficulty and COLORS.gold[1] or COLORS.goldDim[1],
            activeDifficulty and COLORS.gold[2] or COLORS.goldDim[2],
            activeDifficulty and COLORS.gold[3] or COLORS.goldDim[3],
            1
        )
        button.label:SetTextColor(
            locked and COLORS.muted[1] or COLORS.gold[1],
            locked and COLORS.muted[2] or COLORS.gold[2],
            locked and COLORS.muted[3] or COLORS.gold[3]
        )
    end
    if self.DungeonDeleteHeroButton then
        if generated and not hasSavedRun then
            self.DungeonDeleteHeroButton:Show()
            local confirmDelete = self.PendingDeleteArcadeKey == selected.key
            self.DungeonDeleteHeroButton.label:SetText(confirmDelete and "CONFIRM DELETE" or "DELETE HERO")
            self.DungeonDeleteHeroButton.label:SetTextColor(
                confirmDelete and COLORS.red[1] or COLORS.muted[1],
                confirmDelete and COLORS.red[2] or COLORS.muted[2],
                confirmDelete and COLORS.red[3] or COLORS.muted[3]
            )
        else
            self.DungeonDeleteHeroButton:Hide()
            self.PendingDeleteArcadeKey = nil
        end
    end
    if self.DungeonAbandonSavedRunButton then
        if hasSavedRun then
            self.DungeonAbandonSavedRunButton:Show()
            local confirmAbandon = self.PendingAbandonSavedKey == selected.key
            self.DungeonAbandonSavedRunButton.label:SetText(confirmAbandon and "CONFIRM ABANDON" or "ABANDON SAVED")
            self.DungeonAbandonSavedRunButton.label:SetTextColor(
                confirmAbandon and COLORS.red[1] or COLORS.muted[1],
                confirmAbandon and COLORS.red[2] or COLORS.muted[2],
                confirmAbandon and COLORS.red[3] or COLORS.muted[3]
            )
        else
            self.DungeonAbandonSavedRunButton:Hide()
            self.PendingAbandonSavedKey = nil
        end
    end

    local selectedClassId = string.lower(tostring(selected.classId or selected.classFile or selected.className or ""))
    local classReady = self:IsStudioClassPlayable(selectedClassId)
    local savedRun = self.GetSuspendedRun and self:GetSuspendedRun(selected.key)
    local effectiveEquipment = savedRun and savedRun.equipment
        or (self.GetEffectiveCharacterEquipment and self:GetEffectiveCharacterEquipment(selected))
        or selected.equipment
    local effectiveMainHand = effectiveEquipment and effectiveEquipment.mainhand
    local weapon = effectiveMainHand and effectiveMainHand.arcadeWeapon
        and CopyTable(effectiveMainHand.arcadeWeapon)
        or ResolveCharacterWeapon(self, selected)
    local displayItem = effectiveMainHand
    if not displayItem and weapon then
        displayItem = {
            name = selected.weaponName or weapon.sourceName or "Cached main hand",
            icon = selected.weaponIcon,
            itemLevel = selected.weaponItemLevel or weapon.itemLevel or 1,
            quality = selected.weaponQuality or weapon.quality or 1,
            itemSubType = selected.weaponSubtype or weapon.style,
            equipLoc = "INVTYPE_WEAPONMAINHAND",
            baselineLocked = true,
        }
    end

    if self.DungeonSelectedStatusTitle then
        if savedRun then
            self.DungeonSelectedStatusTitle:SetText("SAVED RUN")
            self.DungeonSelectedStatusTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
            self.DungeonSelectedStatusPanel:SetBackdropBorderColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1)
        elseif selected.dead and selected.hardcore then
            self.DungeonSelectedStatusTitle:SetText("HARDCORE MEMORIAL")
            self.DungeonSelectedStatusTitle:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
            self.DungeonSelectedStatusPanel:SetBackdropBorderColor(COLORS.red[1], COLORS.red[2], COLORS.red[3], 1)
        else
            self.DungeonSelectedStatusTitle:SetText("HERO STATUS")
            self.DungeonSelectedStatusTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
            self.DungeonSelectedStatusPanel:SetBackdropBorderColor(
                COLORS.goldDim[1], COLORS.goldDim[2], COLORS.goldDim[3], 1
            )
        end
    end

    if self.DungeonSelectedWeaponCard then
        self.DungeonSelectedWeaponCard.gaItem = displayItem
        self.DungeonSelectedWeaponCard.gaWeapon = weapon
    end

    if selected.dead and selected.hardcore then
        self.DungeonSelectedWeaponIcon:SetTexture("Interface\\Icons\\Ability_Rogue_FeignDeath")
        self.DungeonSelectedWeaponIcon:SetAlpha(0.35)
        self.DungeonSelectedWeaponName:SetText("No active loadout")
        self.DungeonSelectedWeaponName:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        self.DungeonSelectedWeaponItemLevel:SetText("")
        self.DungeonSelectedWeaponType:SetText("Hardcore hero - permanently dead")
        self.DungeonSelectedWeaponStats:SetText("")
        self.DungeonSelectedWeaponPower:SetText("")
        self.DungeonSelectedWeaponTrait:SetText("")
        self.DungeonSetupBeginButton:SetEnabled(false)
        self.DungeonSetupBeginButton.label:SetText("DEAD")
        self.DungeonSetupBeginButton.label:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
    elseif not classReady then
        self.DungeonSelectedWeaponIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        self.DungeonSelectedWeaponIcon:SetAlpha(0.25)
        self.DungeonSelectedWeaponName:SetText((selected.className or "This class") .. " is not implemented yet")
        self.DungeonSelectedWeaponName:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        self.DungeonSelectedWeaponItemLevel:SetText("")
        self.DungeonSelectedWeaponType:SetText("Choose a READY class or create an Arcade hero.")
        self.DungeonSelectedWeaponStats:SetText("")
        self.DungeonSelectedWeaponPower:SetText("")
        self.DungeonSelectedWeaponTrait:SetText("")
        self.DungeonSetupBeginButton:SetEnabled(false)
        self.DungeonSetupBeginButton.label:SetText("CLASS NOT READY")
        self.DungeonSetupBeginButton.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    elseif weapon then
        local itemName = displayItem and displayItem.name
            or selected.weaponName
            or weapon.sourceName
            or "Cached main hand"
        local itemLevel = tonumber(displayItem and displayItem.itemLevel or selected.weaponItemLevel or weapon.itemLevel) or 1
        local quality = tonumber(displayItem and displayItem.quality or selected.weaponQuality or weapon.quality) or 1
        local qualityR, qualityG, qualityB = GetSetupItemQualityColor(quality)
        local speedSeconds = GetSetupWeaponSpeedSeconds(weapon)
        local slotLabel = GetSetupWeaponSlotLabel(displayItem)
        local typeLabel = GetSetupWeaponTypeLabel(displayItem, weapon)
        local attackPower = tonumber(weapon.attackPower) or 0

        self.DungeonSelectedWeaponIcon:SetTexture(
            (displayItem and displayItem.icon)
            or selected.weaponIcon
            or "Interface\\Icons\\INV_Misc_QuestionMark"
        )
        self.DungeonSelectedWeaponIcon:SetAlpha(1)
        self.DungeonSelectedWeaponName:SetText(itemName)
        self.DungeonSelectedWeaponName:SetTextColor(qualityR, qualityG, qualityB)
        self.DungeonSelectedWeaponItemLevel:SetText("Item Level " .. tostring(itemLevel))
        self.DungeonSelectedWeaponType:SetText(slotLabel .. "  -  " .. typeLabel)
        self.DungeonSelectedWeaponStats:SetText(string.format(
            "%d - %d Damage     Speed %.2f     Range %d",
            tonumber(weapon.damageMin) or 0,
            tonumber(weapon.damageMax) or 0,
            speedSeconds,
            tonumber(weapon.range) or 1
        ))

        if attackPower > 0 then
            self.DungeonSelectedWeaponPower:SetText(string.format("+%d Attack Power", attackPower))
            self.DungeonSelectedWeaponPower:SetTextColor(0.25, 1.00, 0.35)
        else
            self.DungeonSelectedWeaponPower:SetText("")
        end

        if weapon.traitName then
            self.DungeonSelectedWeaponTrait:SetText(
                "Equip: " .. tostring(weapon.traitName) .. " - " .. tostring(weapon.traitDescription or "")
            )
            self.DungeonSelectedWeaponTrait:SetTextColor(0.25, 1.00, 0.35)
        else
            self.DungeonSelectedWeaponTrait:SetText("No special equip effect.")
            self.DungeonSelectedWeaponTrait:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        end

        self.DungeonSetupBeginButton:SetEnabled(true)
        self.DungeonSetupBeginButton.label:SetText(
            savedRun and string.format("RESUME FLOOR %d", tonumber(savedRun.floor) or 1) or "BEGIN RUN"
        )
        self.DungeonSetupBeginButton.label:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

        if savedRun and self.DungeonSelectedNote then
            self.DungeonSelectedNote:SetText(string.format(
                "Floor %d    HP %d / %d    Score %d\nLoadout locked until this run is resumed or abandoned.",
                tonumber(savedRun.floor) or 1,
                tonumber(savedRun.playerHealth) or 0,
                tonumber(savedRun.playerMaxHealth) or 0,
                tonumber(savedRun.score) or 0
            ))
            self.DungeonSelectedNote:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
        end
    else
        self.DungeonSelectedWeaponIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        self.DungeonSelectedWeaponIcon:SetAlpha(0.25)
        self.DungeonSelectedWeaponName:SetText("No cached main-hand weapon")
        self.DungeonSelectedWeaponName:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        self.DungeonSelectedWeaponItemLevel:SetText("")
        self.DungeonSelectedWeaponType:SetText("Equip a weapon in WoW to sync it.")
        self.DungeonSelectedWeaponStats:SetText("")
        self.DungeonSelectedWeaponPower:SetText("")
        self.DungeonSelectedWeaponTrait:SetText("")
        self.DungeonSetupBeginButton:SetEnabled(false)
        self.DungeonSetupBeginButton.label:SetText("NO LOADOUT")
        self.DungeonSetupBeginButton.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    end
end

function GA:SetDungeonRunPortraitMode(active)
    if self.DungeonGearWidgets then
        for _, widget in ipairs(self.DungeonGearWidgets) do
            if active then
                widget:Hide()
            else
                widget:Show()
            end
        end
    end

    local function PositionStatRow(label, value, y)
        if label then
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", 12, y)
        end
        if value then
            value:ClearAllPoints()
            value:SetPoint("TOPRIGHT", -12, y)
        end
    end

    if active then
        if self.DungeonStatsTitle then
            self.DungeonStatsTitle:ClearAllPoints()
            self.DungeonStatsTitle:SetPoint("TOPLEFT", 12, -120)
        end
        PositionStatRow(self.DungeonHealthLabel, self.DungeonHealth, -144)
        PositionStatRow(self.DungeonPowerLabel, self.DungeonPower, -168)
        PositionStatRow(self.DungeonDodgeLabel, self.DungeonDodge, -192)
        PositionStatRow(self.DungeonResourceLabel, self.DungeonResource, -216)
        self:UpdateRunResource()
    else
        if self.DungeonStatsTitle then
            self.DungeonStatsTitle:ClearAllPoints()
            self.DungeonStatsTitle:SetPoint("TOPLEFT", 12, -14)
        end
        PositionStatRow(self.DungeonHealthLabel, self.DungeonHealth, -38)
        PositionStatRow(self.DungeonPowerLabel, self.DungeonPower, -62)
        PositionStatRow(self.DungeonDodgeLabel, self.DungeonDodge, -86)
        if self.DungeonResource then self.DungeonResource:Hide() end
        if self.DungeonResourceLabel then self.DungeonResourceLabel:Hide() end
    end

    if self.DungeonRunPortraitFrame then
        if active then
            local snapshot = self.RunState and self.RunState.snapshot
            local name = snapshot and snapshot.name or UnitName("player") or "Unknown"
            local level = self.RunState and self.RunState.runLevel or snapshot and snapshot.level or UnitLevel("player") or 0
            local className = snapshot and snapshot.className or UnitClass("player") or "Adventurer"

            self.DungeonRunPortraitName:SetText(name)
            self.DungeonRunPortraitMeta:SetText(string.format("Level %d %s", level, className))

            if self.DungeonRunPortrait then
                SetCharacterVisual(self.DungeonRunPortrait, {
                    key = snapshot and snapshot.characterKey,
                    classFile = snapshot and snapshot.classFile,
                    raceId = snapshot and snapshot.raceId,
                    sourceType = snapshot and snapshot.sourceType,
                    isArcadeGenerated = snapshot and snapshot.isArcadeGenerated,
                })
            end

            self.DungeonRunPortraitFrame:Show()
        else
            self.DungeonRunPortraitFrame:Hide()
        end
    end
end

local QUALITY_NAMES = {
    [0] = "Poor",
    [1] = "Common",
    [2] = "Uncommon",
    [3] = "Rare",
    [4] = "Epic",
    [5] = "Legendary",
    [6] = "Artifact",
    [7] = "Heirloom",
}

local function GetCompatItemInfo(itemInfo)
    if C_Item and C_Item.GetItemInfo then
        local a, b, c, d, e, f, g = C_Item.GetItemInfo(itemInfo)

        -- Some modern clients expose item info as a structured table.
        if type(a) == "table" then
            return a.itemName or a.name,
                a.itemLink or a.hyperlink,
                a.itemQuality or a.quality,
                a.itemLevel or a.level,
                a.itemMinLevel or a.minLevel,
                a.itemType or a.type,
                a.itemSubType or a.subType
        end

        return a, b, c, d, e, f, g
    end

    if type(GetItemInfo) == "function" then
        return GetItemInfo(itemInfo)
    end

    return nil
end

local function GetCompatItemInstant(itemInfo)
    if C_Item and C_Item.GetItemInfoInstant then
        local itemID, itemType, itemSubType, equipLoc = C_Item.GetItemInfoInstant(itemInfo)
        return itemID, itemType, itemSubType, equipLoc
    end

    if type(GetItemInfoInstant) == "function" then
        local itemID, itemType, itemSubType, equipLoc = GetItemInfoInstant(itemInfo)
        return itemID, itemType, itemSubType, equipLoc
    end

    return nil, nil, nil, nil
end

function GA:RefreshMainHandInfo(force)
    if not self.DungeonMainHandName then
        return
    end

    if self.RunState and self.RunState.active and not force then
        return
    end

    local slotID = 16
    local itemLink = GetInventoryItemLink("player", slotID)
    local texture = GetInventoryItemTexture("player", slotID)

    self.DungeonMainHandLink = itemLink

    if self.DungeonMainHandIcon then
        self.DungeonMainHandIcon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    end

    if not itemLink then
        self.DungeonMainHandName:SetText("No main hand")
        self.DungeonMainHandName:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        self.DungeonMainHandLevel:SetText("")
        self.DungeonMainHandMeta:SetText("Equip a weapon to scan it.")
        self.DungeonArcadeDamage:SetText("Damage --")
        self.DungeonArcadeStyle:SetText("")
        self.DungeonArcadeTraitName:SetText("")
        self.DungeonArcadeTraitDesc:SetText("")
        self.DungeonPower:SetText("--")
        self.ArcadeMainHand = nil

        if self.SyncCurrentCharacterRoster then
            self:SyncCurrentCharacterRoster(nil, { clearWeapon = true })
        end

        if self.DungeonBeginButton and not (self.RunState and self.RunState.active) then
            self.DungeonBeginButton:SetEnabled(false)
            self.DungeonBeginButton.label:SetText("BEGIN RUN")
            self.DungeonBeginButton.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        end
        return
    end

    local name, _, quality, itemLevel, _, itemType, itemSubType = GetCompatItemInfo(itemLink)
    local itemID, instantType, instantSubType, equipLoc = GetCompatItemInstant(itemLink)

    itemType = itemType or instantType
    itemSubType = itemSubType or instantSubType

    if not itemLevel and C_Item and C_Item.GetDetailedItemLevelInfo then
        itemLevel = C_Item.GetDetailedItemLevelInfo(itemLink)
    end

    if quality == nil and type(GetInventoryItemQuality) == "function" then
        quality = GetInventoryItemQuality("player", slotID)
    end

    if not name then
        -- Equipped item links already contain a readable name, so keep the UI
        -- useful even while the rest of the item data is still loading.
        name = itemLink:match("%[(.-)%]") or "Loading item..."
    end

    local qualityColor = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if qualityColor then
        self.DungeonMainHandName:SetTextColor(qualityColor.r, qualityColor.g, qualityColor.b)
    else
        self.DungeonMainHandName:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    end

    self.DungeonMainHandName:SetText(name)
    self.DungeonMainHandLevel:SetText("Item Level " .. tostring(itemLevel or "?"))

    local rarity = QUALITY_NAMES[quality] or "Unknown"
    local typeName = itemSubType or itemType or "Unknown type"
    self.DungeonMainHandMeta:SetText(rarity .. "  -  " .. typeName)

    if self.WeaponGenerator and self.WeaponGenerator.Convert then
        local weapon = self.WeaponGenerator:Convert({
            itemID = itemID,
            name = name,
            itemLevel = itemLevel,
            quality = quality,
            itemType = itemType,
            itemSubType = itemSubType,
            equipLoc = equipLoc,
        })

        self.ArcadeMainHand = weapon

        if weapon then
            self.DungeonArcadeDamage:SetText(string.format("Damage %d - %d", weapon.damageMin, weapon.damageMax))
            self.DungeonArcadeStyle:SetText(
                string.format("%s  -  %s  -  Range %d", weapon.style, weapon.speed, weapon.range)
            )
            self.DungeonPower:SetText(string.format("%d-%d", weapon.damageMin, weapon.damageMax))

            if weapon.traitName then
                self.DungeonArcadeTraitName:SetText(weapon.traitName)
                self.DungeonArcadeTraitDesc:SetText(weapon.traitDescription or "")
            else
                self.DungeonArcadeTraitName:SetText("NO SIGNATURE TRAIT")
                self.DungeonArcadeTraitDesc:SetText("Uncommon or better weapons unlock their archetype trait.")
            end

            if self.SyncCurrentCharacterRoster then
                self:SyncCurrentCharacterRoster(weapon, {
                    weaponName = name,
                    weaponIcon = texture,
                    weaponLink = itemLink,
                    weaponItemLevel = itemLevel,
                    weaponQuality = quality,
                    weaponSubtype = itemSubType or itemType,
                })
            end

            if self.DungeonBeginButton and not (self.RunState and self.RunState.active) then
                self.DungeonBeginButton:SetEnabled(true)
                self.DungeonBeginButton.label:SetText(self.RunState and self.RunState.completed and "BEGIN AGAIN" or "BEGIN RUN")
                self.DungeonBeginButton.label:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
            end
        end
    end
end

function GA:RefreshEnemyCombatCard()
    local run = self.RunState
    local enemy = run and run.active and GetAdjacentEnemy(run) or nil
    local inCombat = enemy ~= nil

    if self.DungeonEnemyCard then
        if inCombat then
            self.DungeonEnemyCard:Show()
            self.DungeonEnemyName:SetText(
                string.format("%s  Lv %d", GetEnemyDisplayName(enemy), enemy.level or 1)
            )
            self.DungeonEnemyHealth:SetText(
                string.format("%d / %d HP", enemy.hp or 0, enemy.maxHp or 0)
            )

            if self.DungeonEnemyDanger then
                self.DungeonEnemyDanger:SetText(
                    string.format("DANGER %d", enemy.dangerRating or 1)
                )
                self.DungeonEnemyDanger:SetTextColor(
                    COLORS.muted[1],
                    COLORS.muted[2],
                    COLORS.muted[3]
                )
            end

            if self.DungeonEnemyPortrait then
                self.DungeonEnemyPortrait:SetTexture(enemy.portraitIcon or KOBOLD_PORTRAIT_ICON)

                local portraitCoords = enemy.portraitTexCoord
                if portraitCoords then
                    self.DungeonEnemyPortrait:SetTexCoord(
                        portraitCoords[1],
                        portraitCoords[2],
                        portraitCoords[3],
                        portraitCoords[4]
                    )
                else
                    self.DungeonEnemyPortrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                end
            end
        else
            self.DungeonEnemyCard:Hide()
        end
    end

    local function PositionRunRow(label, value, y)
        if label then
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", 12, y)
        end

        if value then
            value:ClearAllPoints()
            value:SetPoint("TOPRIGHT", -12, y)
        end
    end

    if self.DungeonRunTitle then
        self.DungeonRunTitle:ClearAllPoints()

        if inCombat then
            self.DungeonRunTitle:SetPoint("TOPLEFT", 12, -126)
            PositionRunRow(self.DungeonFloorLabel, self.DungeonFloorValue, -150)
            PositionRunRow(self.DungeonLevelLabel, self.DungeonLevelValue, -174)
            PositionRunRow(self.DungeonXpLabel, self.DungeonXpValue, -198)
            PositionRunRow(self.DungeonScoreLabel, self.DungeonScoreValue, -222)
            PositionRunRow(self.DungeonTurnsLabel, self.DungeonTurnsValue, -246)
            PositionRunRow(self.DungeonCopperLabel, self.DungeonCopperValue, -270)
        else
            self.DungeonRunTitle:SetPoint("TOPLEFT", 12, -14)
            PositionRunRow(self.DungeonFloorLabel, self.DungeonFloorValue, -38)
            PositionRunRow(self.DungeonLevelLabel, self.DungeonLevelValue, -62)
            PositionRunRow(self.DungeonXpLabel, self.DungeonXpValue, -86)
            PositionRunRow(self.DungeonScoreLabel, self.DungeonScoreValue, -110)
            PositionRunRow(self.DungeonTurnsLabel, self.DungeonTurnsValue, -134)
            PositionRunRow(self.DungeonCopperLabel, self.DungeonCopperValue, -158)
        end
    end
end

local DEFAULT_ACTION_SLOT_PRIORITY = {
    "heroic_strike",
    "battle_shout",
    "charge",
    "rend",
    "thunder_clap",
    "hamstring",
    "bloodrage",
    "defensive_stance",
    "sunder_armor",
    "overpower",
    "revenge",
    "shield_block",
    "execute",
    "whirlwind",
}

function GA:LoadSavedActionSlots(characterKey, unlockedAbilities)
    GoblinArcadeDB = GoblinArcadeDB or {}
    GoblinArcadeDB.actionBars = GoblinArcadeDB.actionBars or {}
    GoblinArcadeDB.actionBarVersions = GoblinArcadeDB.actionBarVersions or {}

    local saved = characterKey and GoblinArcadeDB.actionBars[characterKey] or nil
    local savedVersion = characterKey and GoblinArcadeDB.actionBarVersions[characterKey] or 1
    local slots = {}
    local assigned = {}

    if saved then
        for i = 1, 8 do
            local abilityId = saved[i]
            if abilityId and GetStudioAbilityById(abilityId) then
                slots[i] = abilityId
                assigned[abilityId] = true
            end
        end

        if savedVersion < 2 then
            local nextSlot = 5
            for _, abilityId in ipairs(DEFAULT_ACTION_SLOT_PRIORITY) do
                if nextSlot > 8 then break end
                if unlockedAbilities and unlockedAbilities[abilityId] and not assigned[abilityId] then
                    while nextSlot <= 8 and slots[nextSlot] do
                        nextSlot = nextSlot + 1
                    end
                    if nextSlot <= 8 then
                        slots[nextSlot] = abilityId
                        assigned[abilityId] = true
                        nextSlot = nextSlot + 1
                    end
                end
            end
        end

        return slots
    end

    local nextSlot = 1
    for _, abilityId in ipairs(DEFAULT_ACTION_SLOT_PRIORITY) do
        if nextSlot > 8 then break end
        if unlockedAbilities and unlockedAbilities[abilityId] then
            slots[nextSlot] = abilityId
            assigned[abilityId] = true
            nextSlot = nextSlot + 1
        end
    end

    return slots
end

function GA:SaveRunActionSlots()
    local run = self.RunState
    if not run or not run.actionBarKey then return end

    GoblinArcadeDB = GoblinArcadeDB or {}
    GoblinArcadeDB.actionBars = GoblinArcadeDB.actionBars or {}
    GoblinArcadeDB.actionBarVersions = GoblinArcadeDB.actionBarVersions or {}
    GoblinArcadeDB.actionBars[run.actionBarKey] = {
        run.actionSlots and run.actionSlots[1] or nil,
        run.actionSlots and run.actionSlots[2] or nil,
        run.actionSlots and run.actionSlots[3] or nil,
        run.actionSlots and run.actionSlots[4] or nil,
        run.actionSlots and run.actionSlots[5] or nil,
        run.actionSlots and run.actionSlots[6] or nil,
        run.actionSlots and run.actionSlots[7] or nil,
        run.actionSlots and run.actionSlots[8] or nil,
    }
    GoblinArcadeDB.actionBarVersions[run.actionBarKey] = 2
end

function GA:SetActionSlotDropHighlight(button, active)
    if not button or not button.SetBackdropBorderColor then return end
    local color = active and COLORS.green or COLORS.goldDim
    button:SetBackdropBorderColor(color[1], color[2], color[3], color[4] or 1)
end

function GA:RefreshActionSlotDropHighlights(active)
    for _, button in ipairs(self.DungeonAbilitySlotButtons or {}) do
        self:SetActionSlotDropHighlight(button, active)
    end
end

function GA:BeginSpellbookDrag(abilityId)
    local run = self.RunState
    if not run or not run.active or not run.unlockedAbilities or not run.unlockedAbilities[abilityId] then
        return false
    end

    local ability = GetStudioAbilityById(abilityId)
    if not ability then return false end

    self.DungeonSpellDrag = {
        abilityId = abilityId,
        sourceSlot = nil,
    }

    if self.DungeonSpellDragFrame then
        self.DungeonSpellDragFrame.icon:SetTexture(GetAbilityIconTexture(ability))
        self.DungeonSpellDragFrame:Show()
    end

    self:RefreshActionSlotDropHighlights(true)
    self:RefreshActionButtons()
    return true
end

function GA:BeginActionSlotDrag(slotIndex)
    local run = self.RunState
    slotIndex = tonumber(slotIndex)
    local abilityId = run and run.actionSlots and run.actionSlots[slotIndex]
    if not run or not run.active or not abilityId then
        return false
    end

    local ability = GetStudioAbilityById(abilityId)
    if not ability then return false end

    self.DungeonSpellDrag = {
        abilityId = abilityId,
        sourceSlot = slotIndex,
    }

    if self.DungeonSpellDragFrame then
        self.DungeonSpellDragFrame.icon:SetTexture(GetAbilityIconTexture(ability))
        self.DungeonSpellDragFrame:Show()
    end

    self:RefreshActionSlotDropHighlights(true)
    self:RefreshActionButtons()
    return true
end

function GA:FinishSpellbookDrag()
    local drag = self.DungeonSpellDrag
    if not drag or not drag.abilityId then
        self:CancelSpellbookDrag()
        return false
    end

    for slotIndex, button in ipairs(self.DungeonAbilitySlotButtons or {}) do
        local over = false
        if button.IsMouseOver then
            over = button:IsMouseOver()
        elseif MouseIsOver then
            over = MouseIsOver(button)
        end

        if over then
            if drag.sourceSlot then
                return self:MoveRunActionSlot(drag.sourceSlot, slotIndex)
            end
            return self:AssignRunActionSlot(slotIndex, drag.abilityId)
        end
    end

    self:CancelSpellbookDrag()
    return false
end

function GA:CancelSpellbookDrag()
    self.DungeonSpellDrag = nil
    if self.DungeonSpellDragFrame then
        self.DungeonSpellDragFrame:Hide()
    end
    self:RefreshActionSlotDropHighlights(false)
    self:RefreshActionButtons()
end

function GA:MoveRunActionSlot(sourceSlot, targetSlot)
    local run = self.RunState
    sourceSlot = tonumber(sourceSlot)
    targetSlot = tonumber(targetSlot)

    if not run or not run.active
        or not sourceSlot or sourceSlot < 1 or sourceSlot > 8
        or not targetSlot or targetSlot < 1 or targetSlot > 8 then
        self:CancelSpellbookDrag()
        return false
    end

    if sourceSlot == targetSlot then
        self:CancelSpellbookDrag()
        return true
    end

    run.actionSlots = run.actionSlots or {}
    local sourceAbility = run.actionSlots[sourceSlot]
    if not sourceAbility then
        self:CancelSpellbookDrag()
        return false
    end

    local targetAbility = run.actionSlots[targetSlot]
    run.actionSlots[targetSlot] = sourceAbility
    run.actionSlots[sourceSlot] = targetAbility

    self:SaveRunActionSlots()
    self:CancelSpellbookDrag()
    self:RefreshActionButtons()
    self:RefreshSpellbook()
    return true
end

function GA:AssignRunActionSlot(slotIndex, abilityId)
    local run = self.RunState
    slotIndex = tonumber(slotIndex)

    if not run or not run.active
        or not slotIndex or slotIndex < 1 or slotIndex > 8
        or not run.unlockedAbilities or not run.unlockedAbilities[abilityId] then
        self:CancelSpellbookDrag()
        return false
    end

    run.actionSlots = run.actionSlots or {}

    for i = 1, 8 do
        if i ~= slotIndex and run.actionSlots[i] == abilityId then
            run.actionSlots[i] = nil
        end
    end

    run.actionSlots[slotIndex] = abilityId
    self:SaveRunActionSlots()
    self:CancelSpellbookDrag()
    self:RefreshActionButtons()
    self:RefreshSpellbook()

    local ability = GetStudioAbilityById(abilityId)
    self:AddCombatLog(
        string.format("%s assigned to action slot %d.", ability and ability.name or abilityId, slotIndex + 1),
        "system"
    )
    return true
end

function GA:DropSpellOnActionSlot(slotIndex)
    local drag = self.DungeonSpellDrag
    if not drag or not drag.abilityId then return false end
    if drag.sourceSlot then
        return self:MoveRunActionSlot(drag.sourceSlot, slotIndex)
    end
    return self:AssignRunActionSlot(slotIndex, drag.abilityId)
end

function GA:ClearRunActionSlot(slotIndex)
    local run = self.RunState
    slotIndex = tonumber(slotIndex)
    if not run or not run.active or not slotIndex or slotIndex < 1 or slotIndex > 8 then
        return false
    end

    run.actionSlots = run.actionSlots or {}
    run.actionSlots[slotIndex] = nil
    self:SaveRunActionSlots()
    self:CancelSpellbookDrag()
    self:RefreshActionButtons()
    self:RefreshSpellbook()
    return true
end

function GA:UseRunActionSlot(slotIndex)
    local run = self.RunState
    local abilityId = run and run.actionSlots and run.actionSlots[slotIndex]
    if not abilityId then
        if self.DungeonRunStateText then
            self.DungeonRunStateText:SetText("ACTION SLOT " .. tostring((tonumber(slotIndex) or 0) + 1) .. " IS EMPTY")
            self.DungeonRunStateText:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        end
        return false
    end

    return self:UseRunAbility(abilityId)
end

function GA:ShowSpellbookAbilityTooltip(button)
    if not button or not button.gaAbilityId then return end
    local ability = GetStudioAbilityById(button.gaAbilityId)
    if not ability then return end

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(ability.name or ability.id, 1, 0.82, 0.2)
    GameTooltip:AddLine("Learn Level " .. tostring(ability.learnLevel or 1), 0.75, 0.75, 0.75)
    if (tonumber(ability.resourceCost) or 0) > 0 then
        GameTooltip:AddLine(
            string.format("Cost: %d %s", tonumber(ability.resourceCost) or 0, self.RunState and self.RunState.resourceType or "RESOURCE"),
            0.85, 0.7, 0.25
        )
    end
    if (tonumber(ability.cooldownTurns) or 0) > 0 then
        GameTooltip:AddLine("Cooldown: " .. tostring(ability.cooldownTurns) .. " turns", 0.75, 0.75, 0.75)
    end
    GameTooltip:AddLine(ability.description or "", 0.9, 0.9, 0.9, true)

    if button.gaUnlocked then
        GameTooltip:AddLine("Drag to action slots 2-9.", 0.35, 1, 0.35)
    else
        GameTooltip:AddLine("Locked at current Run Level.", 1, 0.35, 0.35)
    end
    GameTooltip:Show()
end

function GA:ShowActionSlotTooltip(button)
    if not button or not button.gaActionSlot then return end
    local run = self.RunState
    local abilityId = run and run.actionSlots and run.actionSlots[button.gaActionSlot]
    if not abilityId then
        if self.DungeonSpellDrag then
            GameTooltip:SetOwner(button, "ANCHOR_TOP")
            GameTooltip:SetText("Drop ability here", 0.35, 1, 0.35)
            GameTooltip:Show()
        end
        return
    end

    button.gaAbilityId = abilityId
    button.gaUnlocked = true
    self:ShowSpellbookAbilityTooltip(button)
    GameTooltip:AddLine("Drag to another action slot to move or swap.", 0.35, 1, 0.35)
    GameTooltip:AddLine("Right-click to clear this slot.", 0.75, 0.75, 0.75)
    GameTooltip:Show()
end

function GA:RefreshSpellbook()
    local run = self.RunState
    if not self.DungeonSpellbookButtons then return end

    local spellsPerPage = #self.DungeonSpellbookButtons
    local pageCount = math.max(1, math.ceil(#RUN_ABILITY_IDS / spellsPerPage))
    self.DungeonSpellbookPage = math.max(1, math.min(pageCount, self.DungeonSpellbookPage or 1))

    local assigned = {}
    for slotIndex = 1, 8 do
        local abilityId = run and run.actionSlots and run.actionSlots[slotIndex]
        if abilityId then
            assigned[abilityId] = slotIndex + 1
        end
    end

    local firstIndex = ((self.DungeonSpellbookPage - 1) * spellsPerPage) + 1
    for buttonIndex, button in ipairs(self.DungeonSpellbookButtons) do
        local abilityIndex = firstIndex + buttonIndex - 1
        local abilityId = RUN_ABILITY_IDS[abilityIndex]
        local ability = abilityId and GetStudioAbilityById(abilityId) or nil
        local unlocked = abilityId
            and run
            and run.active
            and run.unlockedAbilities
            and run.unlockedAbilities[abilityId]

        button.gaAbilityId = abilityId
        button.gaUnlocked = unlocked and true or false

        if ability then
            local assignedKey = assigned[abilityId]
            button.nameText:SetText(string.upper(ability.name or abilityId))
            if unlocked then
                local meta = "LEARNED"
                if assignedKey then
                    meta = meta .. "  -  ACTION " .. tostring(assignedKey)
                end
                button.metaText:SetText(meta)
                button.nameText:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
                button.metaText:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
                button.icon:SetVertexColor(1, 1, 1)
            else
                button.metaText:SetText("LOCKED  -  LEVEL " .. tostring(ability.learnLevel or 1))
                button.nameText:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
                button.metaText:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
                button.icon:SetVertexColor(0.32, 0.32, 0.32)
            end
            button.icon:SetTexture(GetAbilityIconTexture(ability))
            button:Enable()
            button:Show()
        else
            button.gaAbilityId = nil
            button.gaUnlocked = false
            button:Hide()
        end
    end

    if self.DungeonSpellbookPageText then
        self.DungeonSpellbookPageText:SetText(
            string.format("PAGE %d / %d", self.DungeonSpellbookPage, pageCount)
        )
    end
    if self.DungeonSpellbookPrev then
        self.DungeonSpellbookPrev:SetEnabled(self.DungeonSpellbookPage > 1)
    end
    if self.DungeonSpellbookNext then
        self.DungeonSpellbookNext:SetEnabled(self.DungeonSpellbookPage < pageCount)
    end
end

function GA:ChangeSpellbookPage(delta)
    local spellsPerPage = #(self.DungeonSpellbookButtons or {})
    if spellsPerPage <= 0 then return end

    local pageCount = math.max(1, math.ceil(#RUN_ABILITY_IDS / spellsPerPage))
    self.DungeonSpellbookPage = math.max(
        1,
        math.min(pageCount, (self.DungeonSpellbookPage or 1) + (tonumber(delta) or 0))
    )
    self:CancelSpellbookDrag()
    self:RefreshSpellbook()
end

function GA:OpenSpellbook()
    if not self.RunState or not self.RunState.active or not self.DungeonSpellbookFrame then
        return
    end
    if self.CharacterSheetFrame then
        self.CharacterSheetFrame:Hide()
    end
    self:CloseShrineChoice()
    self:CloseDungeonEvent()
    self:CloseDungeonShop()
    self:CancelSpellbookDrag()
    self:RefreshSpellbook()
    self.DungeonSpellbookFrame:Show()
end

function GA:CloseSpellbook()
    self:CancelSpellbookDrag()
    if self.DungeonSpellbookFrame then
        self.DungeonSpellbookFrame:Hide()
    end
end

function GA:ToggleSpellbook()
    if not self.DungeonSpellbookFrame then return end
    if self.DungeonSpellbookFrame:IsShown() then
        self:CloseSpellbook()
    else
        self:OpenSpellbook()
    end
end

function GA:RefreshActionButtons()
    local run = self.RunState
    local enemy = run and run.active and GetAdjacentEnemy(run) or nil
    local canAttack = enemy ~= nil

    if self.DungeonAttackButton then
        self.DungeonAttackButton:SetEnabled(canAttack and true or false)
        if self.DungeonAttackButton.icon then
            self.DungeonAttackButton.icon:SetVertexColor(
                canAttack and 1 or 0.38,
                canAttack and 1 or 0.38,
                canAttack and 1 or 0.38
            )
        end
        self:SetActionSlotDropHighlight(self.DungeonAttackButton, false)
    end

    if self.DungeonSpellbookButton then
        local enabled = run and run.active
        self.DungeonSpellbookButton:SetEnabled(enabled and true or false)
        self.DungeonSpellbookButton.label:SetTextColor(
            enabled and COLORS.gold[1] or COLORS.muted[1],
            enabled and COLORS.gold[2] or COLORS.muted[2],
            enabled and COLORS.gold[3] or COLORS.muted[3]
        )
    end

    for slotIndex, button in ipairs(self.DungeonAbilitySlotButtons or {}) do
        local abilityId = run and run.actionSlots and run.actionSlots[slotIndex]
        local ability = abilityId and GetStudioAbilityById(abilityId) or nil

        button:SetEnabled(run and run.active and true or false)

        if ability then
            local cost = math.max(0, tonumber(ability.resourceCost) or 0)
            local cooldown = run.cooldowns and math.max(0, tonumber(run.cooldowns[abilityId]) or 0) or 0
            local enoughResource = (run.resource or 0) >= cost
            local unlocked = run.unlockedAbilities and run.unlockedAbilities[abilityId]
            local usable = run.active and unlocked and enoughResource and cooldown <= 0

            button.gaAbilityId = abilityId
            if button.icon then
                button.icon:SetTexture(GetAbilityIconTexture(ability))
                local draggingSource = self.DungeonSpellDrag
                    and self.DungeonSpellDrag.sourceSlot == slotIndex
                local tint = draggingSource and 0.18 or (usable and 1 or 0.38)
                button.icon:SetVertexColor(tint, tint, tint)
            end
            if button.cooldownText then
                button.cooldownText:SetText(cooldown > 0 and tostring(cooldown) or "")
            end
            self:SetActionSlotDropHighlight(button, self.DungeonSpellDrag ~= nil)
        else
            button.gaAbilityId = nil
            if button.icon then
                button.icon:SetColorTexture(0.035, 0.035, 0.035, 1)
                button.icon:SetVertexColor(1, 1, 1)
            end
            if button.cooldownText then
                button.cooldownText:SetText("")
            end
            self:SetActionSlotDropHighlight(button, self.DungeonSpellDrag ~= nil)
        end
    end

    if self.DungeonPotionButton then
        local usableSlot, usablePotion = FindRunPotion(run, true)
        local anySlot, anyPotion = FindRunPotion(run, false)
        local displayPotion = usablePotion or anyPotion
        local usable = run and run.active and usablePotion ~= nil

        self.DungeonPotionButton.gaPotionSlot = usableSlot or anySlot
        self.DungeonPotionButton.gaPotionItem = displayPotion
        self.DungeonPotionButton:SetEnabled(usable and true or false)

        if self.DungeonPotionButton.icon then
            self.DungeonPotionButton.icon:SetTexture(
                displayPotion and displayPotion.icon or "Interface\\Icons\\INV_Potion_54"
            )
            local tint = usable and 1 or 0.38
            self.DungeonPotionButton.icon:SetVertexColor(tint, tint, tint)
        end

        if self.DungeonPotionButton.countText then
            local count = displayPotion
                and CountRunPotionStacks(run, displayPotion.studioItemId)
                or 0
            self.DungeonPotionButton.countText:SetText(count > 0 and tostring(count) or "")
        end
    end

    if self.DungeonSpellbookFrame and self.DungeonSpellbookFrame:IsShown() then
        self:RefreshSpellbook()
    end
end

function GA:ShowRunPotionTooltip(button)
    local run = self.RunState
    local _, usablePotion = FindRunPotion(run, true)
    local _, anyPotion = FindRunPotion(run, false)
    local potion = usablePotion or anyPotion

    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    if not potion then
        GameTooltip:SetText("Potion", 1, 0.82, 0.2)
        GameTooltip:AddLine("No potion in your backpack.", 0.75, 0.75, 0.75, true)
        GameTooltip:Show()
        return
    end

    GameTooltip:SetText(potion.name or "Potion", 1, 0.82, 0.2)
    local effect = string.upper(tostring(potion.consumableEffect or "NONE"))
    local value = tonumber(potion.effectValue) or 0

    if effect == "HEAL_PERCENT" then
        GameTooltip:AddLine(string.format("Restores %.0f%% of maximum HP.", value), 0.35, 1, 0.35, true)
    elseif effect == "HEAL_FLAT" then
        GameTooltip:AddLine(string.format("Restores %d HP.", math.floor(value + 0.5)), 0.35, 1, 0.35, true)
    elseif effect == "RESOURCE" then
        GameTooltip:AddLine(string.format("Restores %d class resource.", math.floor(value + 0.5)), 0.35, 1, 0.35, true)
    end

    local count = CountRunPotionStacks(run, potion.studioItemId)
    GameTooltip:AddLine(string.format("%d available.", count), 0.9, 0.9, 0.9, true)
    if usablePotion then
        GameTooltip:AddLine("Using a potion consumes your turn.", 1, 0.72, 0.12, true)
    elseif effect == "HEAL_PERCENT" or effect == "HEAL_FLAT" then
        GameTooltip:AddLine("Cannot use at full health.", 0.75, 0.75, 0.75, true)
    elseif effect == "RESOURCE" then
        GameTooltip:AddLine("Cannot use while resource is full.", 0.75, 0.75, 0.75, true)
    end
    GameTooltip:Show()
end

function GA:UseRunPotion()
    local run = self.RunState
    if not run or not run.active then
        return false
    end

    local slotIndex, potion = FindRunPotion(run, true)
    if not potion then
        local _, ownedPotion = FindRunPotion(run, false)
        if self.DungeonRunStateText then
            self.DungeonRunStateText:SetText(
                ownedPotion and "POTION NOT NEEDED" or "NO POTION"
            )
            self.DungeonRunStateText:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        end
        self:AddCombatLog(
            ownedPotion and "You cannot use that potion right now." or "You have no potion.",
            "warning"
        )
        self:RefreshActionButtons()
        return false
    end

    local effect = string.upper(tostring(potion.consumableEffect or "NONE"))
    local value = tonumber(potion.effectValue) or 0
    local applied = 0

    if effect == "HEAL_PERCENT" then
        local amount = math.max(1, math.floor((run.playerMaxHealth or 1) * (value / 100) + 0.5))
        local before = run.playerHealth or 0
        run.playerHealth = math.min(run.playerMaxHealth or before, before + amount)
        applied = run.playerHealth - before
    elseif effect == "HEAL_FLAT" then
        local amount = math.max(1, math.floor(value + 0.5))
        local before = run.playerHealth or 0
        run.playerHealth = math.min(run.playerMaxHealth or before, before + amount)
        applied = run.playerHealth - before
    elseif effect == "RESOURCE" then
        local before = run.resource or 0
        run.resource = math.min(run.resourceMax or before, before + math.max(1, math.floor(value + 0.5)))
        applied = run.resource - before
    else
        self:AddCombatLog("That potion has no usable GoblinArcade effect.", "warning")
        return false
    end

    if applied <= 0 then
        self:AddCombatLog("The potion would have no effect right now.", "warning")
        self:RefreshActionButtons()
        return false
    end

    local stackCount = math.max(1, math.floor(tonumber(potion.stackCount) or 1))
    if stackCount > 1 then
        potion.stackCount = stackCount - 1
    else
        run.backpack[slotIndex] = nil
    end

    run.turns = (run.turns or 0) + 1

    if effect == "RESOURCE" then
        self:AddCombatLog(
            string.format("%s restores %d %s.", potion.name or "Potion", applied, run.resourceType or "resource"),
            "player"
        )
    else
        self:AddCombatLog(
            string.format("%s restores %d HP.", potion.name or "Potion", applied),
            "player"
        )
    end

    if self.DungeonRunStateText then
        self.DungeonRunStateText:SetText("POTION USED")
        self.DungeonRunStateText:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    end

    self:UpdateRunHealth()
    self:UpdateRunResource()
    self:RefreshRunCounters()
    self:RefreshActionButtons()

    if self.CharacterSheetFrame and self.CharacterSheetFrame:IsShown() then
        self:RefreshCharacterSheet()
    end

    self:RenderDungeonGrid()
    self:RunEnemyTurn()
    return true
end

function GA:UpdateRunResource()
    local run = self.RunState
    if not self.DungeonResource or not self.DungeonResourceLabel then
        return
    end

    local resourceType = run and run.resourceType or "NONE"
    local resourceMax = run and math.max(0, tonumber(run.resourceMax) or 0) or 0

    if not run or not run.active or resourceType == "NONE" or resourceMax <= 0 then
        self.DungeonResource:Hide()
        self.DungeonResourceLabel:Hide()
        return
    end

    run.resource = math.max(0, math.min(resourceMax, tonumber(run.resource) or 0))
    self.DungeonResourceLabel:SetText(resourceType)
    self.DungeonResource:SetText(string.format("%d / %d", run.resource, resourceMax))
    self.DungeonResource:Show()
    self.DungeonResourceLabel:Show()
end

function GA:UpdateRunHealth()
    local run = self.RunState
    if not run or not self.DungeonHealth then
        return
    end

    self.DungeonHealth:SetText(
        string.format("%d / %d", math.max(0, run.playerHealth or 0), run.playerMaxHealth or 0)
    )
end

local function BuildRunLootSummary(run)
    local entries = {}
    for _, entry in pairs(run and run.lootSummary or {}) do
        entries[#entries + 1] = {
            name = entry.name or "Unknown Item",
            count = math.max(1, tonumber(entry.count) or 1),
        }
    end

    table.sort(entries, function(a, b)
        return string.lower(a.name) < string.lower(b.name)
    end)

    if #entries == 0 then
        return "No loot acquired."
    end

    local lines = {}
    for index, entry in ipairs(entries) do
        if index > 8 then
            lines[#lines + 1] = string.format("+%d more item types", #entries - 8)
            break
        end
        lines[#lines + 1] = string.format("%s  x%d", entry.name, entry.count)
    end
    return table.concat(lines, "\n")
end

function GA:HideDungeonRunSummary()
    if self.DungeonRunSummaryOverlay then
        self.DungeonRunSummaryOverlay:Hide()
    end
end

function GA:ShowDungeonRunSummary(completed, reason, hardcoreDeath)
    local run = self.RunState
    if not run or not self.DungeonRunSummaryOverlay then
        return
    end

    local stats = EnsureRunTracking(run)
    local breakdown = run.scoreBreakdown or {}

    self.DungeonRunSummaryTitle:SetText(completed and "RUN COMPLETE" or "RUN ENDED")
    self.DungeonRunSummaryTitle:SetTextColor(
        completed and COLORS.green[1] or COLORS.red[1],
        completed and COLORS.green[2] or COLORS.red[2],
        completed and COLORS.green[3] or COLORS.red[3]
    )

    local outcome = completed and "DUNGEON CLEARED" or "DEFEAT"
    if hardcoreDeath then
        outcome = "HARDCORE - CHARACTER DIED"
    end
    self.DungeonRunSummaryOutcome:SetText(outcome)
    self.DungeonRunSummaryOutcome:SetTextColor(
        hardcoreDeath and COLORS.red[1] or COLORS.gold[1],
        hardcoreDeath and COLORS.red[2] or COLORS.gold[2],
        hardcoreDeath and COLORS.red[3] or COLORS.gold[3]
    )

    self.DungeonRunSummaryReason:SetText(reason or "")
    self.DungeonRunSummaryStats:SetText(string.format(
        "SCORE  %d\nDIFFICULTY  %s\nFLOOR  %d / 9\nKILLS  %d\nELITES  %d\nBOSSES  %d\nCHESTS  %d\nSHRINES  %d\nEVENTS  %d\nCOPPER  %s\nBOUGHT / SOLD  %d / %d\nEXTRACTED  %d ITEMS\nTURNS  %d\nTEMP LEVELS  +%d",
        run.score or 0,
        string.upper(run.difficultyLabel or run.difficulty or "NORMAL"),
        run.floor or 1,
        stats.kills or 0,
        stats.eliteKills or 0,
        stats.bossKills or 0,
        stats.chests or 0,
        stats.shrines or 0,
        stats.events or 0,
        FormatCopperValue(run.copper or 0),
        stats.itemsBought or 0,
        stats.itemsSold or 0,
        completed and (run.extractedLootCount or 0) or 0,
        run.turns or 0,
        run.levelsGained or 0
    ))
    self.DungeonRunSummaryScore:SetText(string.format(
        "Enemy %d   Rank %d   Chest %d   Floor %d   Shrine %d   Event %d   Completion %d",
        breakdown.enemy or 0,
        breakdown.rankBonus or 0,
        breakdown.chest or 0,
        breakdown.floor or 0,
        breakdown.shrine or 0,
        breakdown.event or 0,
        breakdown.completion or 0
    ))
    if self.DungeonRunSummaryLootLabel then
        self.DungeonRunSummaryLootLabel:SetText(
            completed and "EXTRACTED TO CENTRAL STASH" or "UNEXTRACTED LOOT - LOST"
        )
    end
    if completed and run.extractedLootSummary then
        local extractedView = { lootSummary = run.extractedLootSummary }
        self.DungeonRunSummaryLoot:SetText(BuildRunLootSummary(extractedView))
    else
        self.DungeonRunSummaryLoot:SetText(BuildRunLootSummary(run))
    end
    self.DungeonRunSummaryOverlay:Show()
end

function GA:ReturnToDungeonCharacters()
    self:HideDungeonRunSummary()
    self:ClearDungeonGridVisuals()
    if self.CharacterSheetFrame then
        self.CharacterSheetFrame:Hide()
    end
    self:CancelCharacterItemDrag()
    self:SetDungeonRunPortraitMode(false)
    self:SetRunMode(false)
    self:RefreshMainHandInfo(true)
    self:SetDungeonSetupMode(true)
    self:RefreshRunCounters()
end

function GA:FailDungeonRun(reason)
    local run = self.RunState
    if not run then
        return
    end

    run.active = false
    run.failed = true
    self:ClearDungeonGridVisuals()
    self:CloseRunControlMenu()
    self:CloseShrineChoice()
    self:CloseDungeonEvent()
    self:CloseDungeonShop()
    self:CloseSpellbook()

    local deathReason = reason or "The run is over."
    local hardcoreDeath = false
    if run.snapshot and run.snapshot.hardcore and run.snapshot.isArcadeGenerated
        and self.MarkArcadeCharacterDead then
        hardcoreDeath = self:MarkArcadeCharacterDead(
            run.snapshot.characterKey,
            deathReason,
            run.floor,
            run.score
        ) and true or false
    end

    self:AddCombatLog(deathReason, "warning")
    self:AddCombatLog("Extraction failed: all found loot and committed pre-run supplies are lost.", "warning")
    if hardcoreDeath then
        self:AddCombatLog("HARDCORE DEATH: this Arcade hero is permanently dead.", "warning")
    end

    if self.DungeonRunStateText then
        self.DungeonRunStateText:SetText(hardcoreDeath and "HARDCORE HERO DIED" or "RUN ENDED")
        self.DungeonRunStateText:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
    end

    if self.DungeonRunPage and self.DungeonRunPage.SetPropagateKeyboardInput then
        self.DungeonRunPage:SetPropagateKeyboardInput(true)
    end

    if self.CharacterSheetFrame then
        self.CharacterSheetFrame:Hide()
    end
    self:CancelCharacterItemDrag()
    self:RefreshActionButtons()
    self:ShowDungeonRunSummary(false, deathReason, hardcoreDeath)
end

function GA:GrantRunExperience(amount)
    local run = self.RunState
    if not run or not run.active then return false end
    local gainedXp = math.max(0, math.floor(tonumber(amount) or 0))
    if gainedXp <= 0 then return false end

    local initialLevel = run.runLevel or 1
    run.totalRunXp = (run.totalRunXp or 0) + gainedXp
    if initialLevel >= (run.progression and run.progression.maxRunLevel or 60) then
        self:RefreshRunCounters()
        return false, initialLevel, initialLevel
    end

    run.runXp = (run.runXp or 0) + gainedXp
    while run.runLevel < run.progression.maxRunLevel do
        local required = GetRunXpRequired(run)
        if run.runXp < required then break end

        local previousLevel = run.runLevel
        run.runXp = run.runXp - required
        run.runLevel = run.runLevel + 1
        run.levelsGained = (run.levelsGained or 0) + 1

        local previousAbilities = run.unlockedAbilities or {}
        local nextAbilities = GetClassAbilityIdSet(run.classId, run.runLevel)
        local unlockedNames = {}
        for _, ability in ipairs(GA.StudioData and GA.StudioData.abilities or {}) do
            if nextAbilities[ability.id] and not previousAbilities[ability.id] then
                unlockedNames[#unlockedNames + 1] = ability.name or ability.id
            end
        end
        run.unlockedAbilities = nextAbilities

        local growth = run.classGrowth or GetClassRunGrowth(run.classId)
        local hpGain = math.max(0, tonumber(growth.hpPerLevel) or 0)
        local resourceGain = math.max(0, tonumber(growth.resourcePerLevel) or 0)

        if hpGain > 0 then
            run.baseMaxHealth = math.max(1, (run.baseMaxHealth or run.playerMaxHealth or 1) + hpGain)
            run.playerMaxHealth = math.max(1, (run.playerMaxHealth or 1) + hpGain)
            run.playerHealth = math.min(run.playerMaxHealth, math.max(0, (run.playerHealth or 0) + hpGain))
        end

        if resourceGain > 0 then
            run.resourceMax = math.max(0, (run.resourceMax or 0) + resourceGain)
        end
        self:UpdateRunResource()

        self:AddCombatLog(string.format("LEVEL UP! %d -> %d", previousLevel, run.runLevel), "system")
        if hpGain > 0 or resourceGain > 0 then
            local growthParts = {}
            if hpGain > 0 then
                growthParts[#growthParts + 1] = string.format("+%d HP", hpGain)
            end
            if resourceGain > 0 then
                growthParts[#growthParts + 1] = string.format(
                    "+%d %s cap",
                    resourceGain,
                    growth.resourceType or "RESOURCE"
                )
            end
            self:AddCombatLog("Class growth: " .. table.concat(growthParts, ", "), "player")
        end
        if #unlockedNames > 0 then
            self:AddCombatLog("Unlocked: " .. table.concat(unlockedNames, ", "), "player")
        end
    end

    if run.runLevel >= run.progression.maxRunLevel then run.runXp = 0 end
    if self.DungeonRunPortraitMeta then
        self.DungeonRunPortraitMeta:SetText(string.format("Level %d %s", run.runLevel or run.snapshot.level or 1, run.snapshot.className or "Adventurer"))
    end

    local leveledUp = run.runLevel > initialLevel
    if leveledUp then
        if self.RecalculateRunGearStats then self:RecalculateRunGearStats() end
        self:UpdateRunHealth()
    end
    if leveledUp and self.DungeonRunStateText then
        self.DungeonRunStateText:SetText(string.format("LEVEL UP!  %d -> %d", initialLevel, run.runLevel))
        self.DungeonRunStateText:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    end

    self:RefreshRunCounters()
    return leveledUp, initialLevel, run.runLevel
end

local function GetRunAbilityCooldown(run, abilityId)
    return run and run.cooldowns and math.max(0, tonumber(run.cooldowns[abilityId]) or 0) or 0
end

local function SetRunAbilityCooldown(run, ability)
    local turns = math.max(0, math.floor(tonumber(ability and ability.cooldownTurns) or 0))
    if turns <= 0 then return end
    run.cooldowns = run.cooldowns or {}
    -- Combat effects tick after the enemy phase, so +1 preserves the configured
    -- number of future player turns.
    run.cooldowns[ability.id] = turns + 1
end

local function SpendRunResource(run, amount)
    amount = math.max(0, tonumber(amount) or 0)
    if (run.resource or 0) < amount then
        return false
    end
    run.resource = math.max(0, (run.resource or 0) - amount)
    return true
end

local function GainRunResource(run, amount)
    amount = math.max(0, tonumber(amount) or 0)
    if amount <= 0 or (run.resourceMax or 0) <= 0 then return end
    run.resource = math.min(run.resourceMax, (run.resource or 0) + amount)
end

local function HasRunShield(run)
    local offhand = run and run.equipment and run.equipment.offhand
    if not offhand then return false end

    local equipLoc = string.upper(tostring(offhand.equipLoc or ""))
    local subtype = string.lower(tostring(offhand.itemSubType or offhand.subType or ""))
    return equipLoc == "INVTYPE_SHIELD" or string.find(subtype, "shield", 1, true) ~= nil
end

local function GetAdjacentEnemies(run)
    local result = {}
    for _, enemy in ipairs(run and run.enemies or {}) do
        if enemy.alive ~= false and IsAdjacent(run.playerX, run.playerY, enemy.x, enemy.y) then
            result[#result + 1] = enemy
        end
    end
    return result
end

local function GetNearestVisibleEnemyInRange(run, range, minimumRange)
    local best
    local bestDistance
    minimumRange = math.max(0, tonumber(minimumRange) or 0)
    range = math.max(minimumRange, tonumber(range) or 1)

    for _, enemy in ipairs(run and run.enemies or {}) do
        if enemy.alive ~= false then
            local distance = math.abs(enemy.x - run.playerX) + math.abs(enemy.y - run.playerY)
            if distance >= minimumRange and distance <= range
                and HasLineOfSight(run.playerX, run.playerY, enemy.x, enemy.y)
                and (not bestDistance or distance < bestDistance) then
                best = enemy
                bestDistance = distance
            end
        end
    end

    return best
end

local function FindChargeDestination(run, enemy)
    local occupied = BuildOccupiedEnemyCells(run, enemy and enemy.uid)
    local bestX
    local bestY
    local bestDistance

    for _, delta in ipairs(PATH_DIRECTIONS) do
        local x = enemy.x + delta[1]
        local y = enemy.y + delta[2]
        local key = CellKey(x, y)
        if not IsDungeonWall(x, y)
            and not IsDungeonDoorClosed(x, y)
            and not occupied[key]
            and not (x == run.playerX and y == run.playerY) then
            local distance = math.abs(x - run.playerX) + math.abs(y - run.playerY)
            if not bestDistance or distance < bestDistance then
                bestX = x
                bestY = y
                bestDistance = distance
            end
        end
    end

    return bestX, bestY
end

local function GetRunDamageDoneMultiplier(run, enemy)
    local multiplier = 1

    local shout = run and run.buffs and run.buffs.battle_shout
    if shout and (shout.turns or 0) > 0 then
        multiplier = multiplier * (1 + math.max(0, tonumber(shout.percent) or 0) / 100)
    end

    if run and run.stance == "defensive" then
        local stance = GetStudioAbilityById("defensive_stance") or {}
        local penalty = math.max(0, math.min(90, tonumber(stance.secondaryValue) or 0))
        multiplier = multiplier * (1 - penalty / 100)
    end

    local traits = run and run.arcadeTraits or {}
    local hpRatio = run and (run.playerMaxHealth or 0) > 0
        and ((run.playerHealth or 0) / run.playerMaxHealth)
        or 1

    if hpRatio <= 0.50 and (traits.BLOOD_FURY or 0) > 0 then
        multiplier = multiplier * (1 + traits.BLOOD_FURY / 100)
    end
    if hpRatio >= 0.80 and (traits.VANGUARD or 0) > 0 then
        multiplier = multiplier * (1 + traits.VANGUARD / 100)
    end
    if enemy and (enemy.maxHp or 0) > 0 and (enemy.hp or 0) / enemy.maxHp <= 0.35
        and (traits.EXECUTIONER or 0) > 0 then
        multiplier = multiplier * (1 + traits.EXECUTIONER / 100)
    end

    return multiplier
end

local function GetEnemyIncomingDamageMultiplier(enemy)
    local multiplier = 1
    local sunder = enemy and enemy.statuses and enemy.statuses.sunder
    if sunder and (sunder.turns or 0) > 0 then
        multiplier = multiplier * (1 + math.max(0, tonumber(sunder.percent) or 0) * math.max(1, tonumber(sunder.stacks) or 1) / 100)
    end
    return multiplier
end

local function RollRunWeaponDamage(self, run, enemy, ability)
    local weapon = self:GetCurrentRunWeapon()
    local minimum = weapon and math.max(1, tonumber(weapon.damageMin) or 1) or 1
    local maximum = weapon and math.max(minimum, tonumber(weapon.damageMax) or minimum) or 2
    local damage = math.random(minimum, maximum)
    local attackPowerBonus = self.GetRunAttackPowerDamageBonus and self:GetRunAttackPowerDamageBonus(weapon) or 0
    damage = damage + attackPowerBonus

    local abilityMultiplier = ability and math.max(0.01, tonumber(ability.damageMultiplier) or 1) or 1
    damage = math.max(1, math.floor(damage * abilityMultiplier + 0.5))
    damage = math.max(1, math.floor(damage * GetRunDamageDoneMultiplier(run, enemy) + 0.5))

    local runDamageBonus = math.max(0, tonumber(run.shrineDamageBonus) or 0)
        + math.max(0, tonumber(run.eventDamageBonus) or 0)
    if runDamageBonus > 0 then
        damage = math.max(1, math.floor(damage * (1 + runDamageBonus) + 0.5))
    end

    local stats = run.arcadeStats or {}
    stats.level = math.max(1, tonumber(run.runLevel) or 1)
    local critBonus = 0
    if run.stance == "berserker" then
        local berserker = GetStudioAbilityById("berserker_stance") or {}
        critBonus = critBonus + math.max(0, tonumber(berserker.effectValue) or 0)
    end
    local recklessness = run.buffs and run.buffs.recklessness
    if recklessness and (recklessness.turns or 0) > 0 then
        critBonus = critBonus + math.max(0, tonumber(recklessness.critBonus) or 0)
    end

    local combatStats = {}
    for key, value in pairs(stats) do combatStats[key] = value end
    combatStats.crit = math.min(100, (tonumber(stats.crit) or 0) + critBonus)

    local outcome
    if GA.ForeverRules and GA.ForeverRules.ResolvePlayerMeleeAttack then
        outcome = GA.ForeverRules:ResolvePlayerMeleeAttack(combatStats, enemy, weapon, ability)
    else
        outcome = { kind = "HIT", multiplier = 1 }
    end

    if (tonumber(outcome.multiplier) or 0) <= 0 then
        return 0, outcome, weapon
    end

    local enemyStats = GA.ForeverRules and GA.ForeverRules:BuildEnemyCombatStats(enemy) or enemy
    local enemyArmor = math.max(0, tonumber(enemyStats and enemyStats.armor) or 0)
    local sunder = enemy and enemy.statuses and enemy.statuses.sunder
    if sunder and (sunder.turns or 0) > 0 then
        local percent = math.max(0, tonumber(sunder.percent) or 0)
        local stacks = math.max(1, tonumber(sunder.stacks) or 1)
        enemyArmor = enemyArmor * (1 - math.min(90, percent * stacks) / 100)
    end

    if GA.ForeverRules and GA.ForeverRules.ApplyPhysicalMitigation then
        damage = GA.ForeverRules:ApplyPhysicalMitigation(damage, enemyArmor, stats.level, outcome)
    else
        damage = math.max(1, math.floor(damage * (tonumber(outcome.multiplier) or 1) + 0.5))
    end

    return damage, outcome, weapon
end
function GA:HandleEnemyDefeat(enemy)
    local run = self.RunState
    if not run or not enemy or enemy.alive == false then
        return false, run and run.runLevel or 1, run and run.runLevel or 1
    end

    enemy.alive = false
    enemy.hp = 0
    if run.activeEnemyId == enemy.uid then
        run.activeEnemyId = nil
    end

    local scoreValue = enemy.scoreValue or 100
    local xpValue = enemy.xpValue or math.max(1, (enemy.dangerRating or 1) * 8)
    local stats = EnsureRunTracking(run)
    stats.kills = stats.kills + 1
    local awardedScore = AddRunScore(run, "enemy", scoreValue)

    local rankBonus = 0
    if enemy.rank == "elite" then
        stats.eliteKills = stats.eliteKills + 1
        rankBonus = RUN_SCORE.ELITE_KILL_BONUS
    elseif enemy.rank == "boss" then
        stats.bossKills = stats.bossKills + 1
        rankBonus = RUN_SCORE.BOSS_KILL_BONUS
        SpawnBossReward(run, enemy.roomIndex)
        self:AddCombatLog("BOSS DEFEATED - THE WAY OUT OPENS. A boss cache appears.", "system")
    end
    local awardedRankBonus = AddRunScore(run, "rankBonus", rankBonus)
    local copperReward = AwardEnemyCopper(run, enemy)

    self:AddCombatLog(
        string.format(
            "%s defeated. +%d score%s, +%d XP, +%s.",
            GetEnemyDisplayName(enemy),
            awardedScore,
            awardedRankBonus > 0 and string.format(" + %d rank bonus", awardedRankBonus) or "",
            xpValue,
            FormatCopperValue(copperReward)
        ),
        "system"
    )

    run.reactive = run.reactive or {}
    run.reactive.victory_rush = { turns = 3 }

    local leveledUp, previousRunLevel, currentRunLevel = self:GrantRunExperience(xpValue)
    if leveledUp then
        local pending = run.justLeveledUp
        run.justLeveledUp = {
            from = pending and pending.from or previousRunLevel,
            to = currentRunLevel,
        }
    end

    if enemy.lootTableId and enemy.lootTableId ~= "" and self.RollLootTable then
        local drop = self:RollLootTable(
            enemy.lootTableId,
            run.floor,
            "enemy:" .. tostring(enemy.id or enemy.archetype or "unknown")
        )
        if drop then
            if self:AddItemToBackpack(drop) then
                RecordRunLoot(run, drop)
                self:AddCombatLog(
                    string.format("%s dropped %s.", GetEnemyDisplayName(enemy), drop.name or "an item"),
                    "system"
                )
            else
                self:AddCombatLog(
                    string.format("%s dropped %s, but your backpack is full.", GetEnemyDisplayName(enemy), drop.name or "an item"),
                    "warning"
                )
            end
        end
    end

    UpdateEncounterRoomClear(self, run, enemy)
    return leveledUp, previousRunLevel, currentRunLevel
end

function GA:DealRunDamage(enemy, ability, options)
    local run = self.RunState
    if not run or not run.active or not enemy or enemy.alive == false then
        return false
    end

    options = type(options) == "table" and options or {}
    local damage, outcome, weapon = RollRunWeaponDamage(self, run, enemy, ability)
    outcome = outcome or { kind = "HIT", multiplier = 1 }
    local sourceName = ability and (ability.name or ability.id) or "You"
    local kind = tostring(outcome.kind or "HIT")

    if damage <= 0 and (kind == "MISS" or kind == "DODGE" or kind == "PARRY") then
        local text
        if kind == "MISS" then
            text = string.format("%s misses the %s.", sourceName, string.lower(GetEnemyDisplayName(enemy)))
        elseif kind == "DODGE" then
            text = string.format("The %s dodges %s.", string.lower(GetEnemyDisplayName(enemy)), sourceName)
        else
            text = string.format("The %s parries %s.", string.lower(GetEnemyDisplayName(enemy)), sourceName)
        end
        self:AddCombatLog(text, "player")
        return true, false, false, nil, nil, outcome, weapon
    end

    enemy.hp = math.max(0, (enemy.hp or enemy.maxHp or 1) - damage)
    local prefix = ""
    if kind == "CRIT" then prefix = "CRITICAL! "
    elseif kind == "GLANCING" then prefix = "GLANCING! "
    elseif kind == "BLOCK" then prefix = "BLOCKED! " end

    self:AddCombatLog(
        string.format("%s%s %s the %s for %d damage. (%d/%d HP)",
            prefix,
            sourceName,
            ability and "hits" or "hits",
            string.lower(GetEnemyDisplayName(enemy)),
            damage,
            enemy.hp,
            enemy.maxHp or enemy.hp),
        "player"
    )

    if damage > 0 and options.allowWeaponTrait ~= false and weapon and weapon.traitName then
        local traitName = string.upper(tostring(weapon.traitName))
        local traitValue = math.max(0, tonumber(weapon.traitValue) or 0)

        if traitName == "GUARD" and traitValue > 0 then
            run.weaponGuardChance = math.max(run.weaponGuardChance or 0, traitValue)
        elseif traitName == "CLEAVE" and traitValue > 0 then
            for _, secondary in ipairs(run.enemies or {}) do
                if secondary.alive ~= false
                    and secondary.uid ~= enemy.uid
                    and IsAdjacent(run.playerX, run.playerY, secondary.x, secondary.y) then
                    local cleaveDamage = math.max(1, math.floor(damage * (traitValue / 100) + 0.5))
                    secondary.hp = math.max(0, (secondary.hp or secondary.maxHp or 1) - cleaveDamage)
                    self:AddCombatLog(
                        string.format("CLEAVE! %s takes %d damage. (%d/%d HP)",
                            GetEnemyDisplayName(secondary), cleaveDamage,
                            secondary.hp, secondary.maxHp or secondary.hp),
                        "player"
                    )
                    if secondary.hp <= 0 then self:HandleEnemyDefeat(secondary) end
                    break
                end
            end
        elseif traitName == "STAGGER" and enemy.hp > 0 and traitValue > 0
            and math.random(1, 100) <= traitValue then
            enemy.skipTurn = true
            enemy.intent = "STAGGERED"
            self:AddCombatLog(
                string.format("STAGGER! The %s loses its next action.", string.lower(GetEnemyDisplayName(enemy))),
                "system"
            )
        end
    end

    if enemy.hp > 0 and ability and damage > 0 then
        enemy.statuses = enemy.statuses or {}
        local duration = math.max(0, math.floor(tonumber(ability.durationTurns) or 0))

        if ability.id == "charge"
            or ability.id == "shield_bash"
            or ability.id == "intercept"
            or ability.id == "pummel" then
            enemy.skipTurn = true
            enemy.intent = "STAGGERED"
        elseif ability.id == "rend" and duration > 0 then
            enemy.statuses.rend = {
                turns = duration,
                damage = math.max(1, math.floor(damage / math.max(1, duration) + 0.5)),
                canCrit = true,
            }
        elseif ability.id == "hamstring" and duration > 0 then
            enemy.statuses.hamstring = {
                turns = duration,
                percent = math.max(0, tonumber(ability.effectValue) or 0),
            }
        elseif ability.id == "sunder_armor" and duration > 0 then
            local current = enemy.statuses.sunder or {}
            local maxStacks = math.max(1, math.floor(tonumber(ability.secondaryValue) or 3))
            enemy.statuses.sunder = {
                turns = duration + 1,
                percent = math.max(0, tonumber(ability.effectValue) or 0),
                stacks = math.min(maxStacks, math.max(0, tonumber(current.stacks) or 0) + 1),
            }
            self:AddCombatLog(
                string.format("Sunder Armor: %d/%d stacks.", enemy.statuses.sunder.stacks, maxStacks),
                "system"
            )
        end
    end

    if enemy.hp <= 0 then
        local leveledUp, previousRunLevel, currentRunLevel = self:HandleEnemyDefeat(enemy)
        return true, true, leveledUp, previousRunLevel, currentRunLevel, outcome, weapon
    end

    return true, false, false, nil, nil, outcome, weapon
end
function GA:AdvanceCombatEffects()
    local run = self.RunState
    if not run or not run.active then return end

    for _, enemy in ipairs(run.enemies or {}) do
        if enemy.alive ~= false and enemy.statuses then
            local rend = enemy.statuses.rend
            if rend and (rend.turns or 0) > 0 then
                local tick = math.max(1, math.floor(tonumber(rend.damage) or 1))
                local critical = false
                if rend.canCrit and run.arcadeStats then
                    local chance = math.max(0, math.min(100, tonumber(run.arcadeStats.crit) or 0))
                    critical = chance > 0 and math.random(1, 10000) <= math.floor(chance * 100)
                    if critical then
                        tick = math.max(1, math.floor(tick * 2 + 0.5))
                    end
                end
                enemy.hp = math.max(0, (enemy.hp or 1) - tick)
                self:AddCombatLog(
                    string.format("%sRend bleeds %s for %d damage. (%d/%d HP)",
                        critical and "CRITICAL! " or "",
                        string.lower(GetEnemyDisplayName(enemy)),
                        tick, enemy.hp, enemy.maxHp or enemy.hp),
                    "player"
                )
                rend.turns = rend.turns - 1
                if enemy.hp <= 0 then
                    self:HandleEnemyDefeat(enemy)
                elseif rend.turns <= 0 then
                    enemy.statuses.rend = nil
                end
            end

            for _, statusId in ipairs({ "hamstring", "weakened", "sunder", "disarmed", "feared", "monsterDamageBuff" }) do
                local status = enemy.statuses[statusId]
                if status then
                    status.turns = (status.turns or 1) - 1
                    if status.turns <= 0 then enemy.statuses[statusId] = nil end
                end
            end
        end
    end

    local shout = run.buffs and run.buffs.battle_shout
    if shout then
        shout.turns = (shout.turns or 1) - 1
        if shout.turns <= 0 then
            run.buffs.battle_shout = nil
            self:AddCombatLog("Battle Shout fades.", "system")
        end
    end

    for _, buffId in ipairs({ "shield_block", "retaliation", "shield_wall", "berserker_rage", "recklessness" }) do
        local buff = run.buffs and run.buffs[buffId]
        if buff then
            buff.turns = (buff.turns or 1) - 1
            if buff.turns <= 0 then
                run.buffs[buffId] = nil
                self:AddCombatLog((buff.name or buffId) .. " fades.", "system")
            end
        end
    end

    for _, reactiveId in ipairs({ "overpower", "revenge", "victory_rush" }) do
        local reactive = run.reactive and run.reactive[reactiveId]
        if reactive then
            reactive.turns = (reactive.turns or 1) - 1
            if reactive.turns <= 0 then run.reactive[reactiveId] = nil end
        end
    end

    for abilityId, turns in pairs(run.cooldowns or {}) do
        turns = math.max(0, (tonumber(turns) or 0) - 1)
        if turns <= 0 then run.cooldowns[abilityId] = nil else run.cooldowns[abilityId] = turns end
    end

    self:UpdateRunResource()
    self:RefreshActionButtons()
end
function GA:UseRunAbility(abilityId)
    local run = self.RunState
    if not run or not run.active then
        return false
    end

    local ability = GetStudioAbilityById(abilityId)
    if not ability then
        self:AddCombatLog("Ability data not found: " .. tostring(abilityId), "warning")
        return false
    end

    if not (run.unlockedAbilities and run.unlockedAbilities[abilityId]) then
        if self.DungeonRunStateText then
            self.DungeonRunStateText:SetText(
                string.format("%s UNLOCKS AT LEVEL %d", string.upper(ability.name or abilityId), tonumber(ability.learnLevel) or 1)
            )
            self.DungeonRunStateText:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        end
        return false
    end

    local cooldown = GetRunAbilityCooldown(run, abilityId)
    if cooldown > 0 then
        self:AddCombatLog(string.format("%s is on cooldown for %d more turn(s).", ability.name or abilityId, cooldown), "warning")
        return false
    end

    local resourceCost = math.max(0, tonumber(ability.resourceCost) or 0)
    if (run.resource or 0) < resourceCost then
        if self.DungeonRunStateText then
            self.DungeonRunStateText:SetText(
                string.format("NEED %d %s FOR %s", resourceCost, run.resourceType or "RESOURCE", string.upper(ability.name or abilityId))
            )
            self.DungeonRunStateText:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
        end
        return false
    end

    if abilityId == "battle_stance"
        or abilityId == "defensive_stance"
        or abilityId == "berserker_stance" then
        SpendRunResource(run, resourceCost)
        GainRunResource(run, ability.resourceGain)
        SetRunAbilityCooldown(run, ability)
        if abilityId == "defensive_stance" then
            run.stance = "defensive"
        elseif abilityId == "berserker_stance" then
            run.stance = "berserker"
        else
            run.stance = "battle"
        end
        run.turns = run.turns + 1
        self:AddCombatLog((ability.name or abilityId) .. " activated.", "player")
        self:UpdateRunResource()
        self:RefreshRunCounters()
        self:RenderDungeonGrid()
        self:RunEnemyTurn()
        return true
    end

    if abilityId == "battle_shout" then
        SpendRunResource(run, resourceCost)
        GainRunResource(run, ability.resourceGain)
        SetRunAbilityCooldown(run, ability)
        run.buffs = run.buffs or {}
        run.buffs.battle_shout = {
            turns = math.max(1, math.floor(tonumber(ability.durationTurns) or 1)) + 1,
            percent = math.max(0, tonumber(ability.effectValue) or 0),
        }
        run.turns = run.turns + 1
        self:AddCombatLog(
            string.format("Battle Shout: +%d%% damage for %d turns.",
                run.buffs.battle_shout.percent,
                math.max(1, math.floor(tonumber(ability.durationTurns) or 1))),
            "player"
        )
        self:UpdateRunResource()
        self:RefreshRunCounters()
        self:RenderDungeonGrid()
        self:RunEnemyTurn()
        return true
    end

    if abilityId == "bloodrage" then
        local percent = math.max(0, tonumber(ability.effectValue) or 0)
        local hpCost = math.max(1, math.floor((run.playerMaxHealth or 1) * percent / 100 + 0.5))
        if (run.playerHealth or 0) <= hpCost then
            self:AddCombatLog("Not enough health to use Bloodrage safely.", "warning")
            return false
        end

        SpendRunResource(run, resourceCost)
        run.playerHealth = math.max(1, (run.playerHealth or 1) - hpCost)
        GainRunResource(run, ability.resourceGain)
        SetRunAbilityCooldown(run, ability)
        run.turns = run.turns + 1
        self:AddCombatLog(
            string.format("Bloodrage: -%d HP, +%d %s.", hpCost, tonumber(ability.resourceGain) or 0, run.resourceType or "RESOURCE"),
            "player"
        )
        self:UpdateRunHealth()
        self:UpdateRunResource()
        self:RefreshRunCounters()
        self:RenderDungeonGrid()
        self:RunEnemyTurn()
        return true
    end

    if abilityId == "charge" or abilityId == "intercept" then
        local target = GetNearestVisibleEnemyInRange(run, ability.range, 2)
        if not target then
            self:AddCombatLog("No visible enemy in Charge range.", "warning")
            return false
        end
        local destinationX, destinationY = FindChargeDestination(run, target)
        if not destinationX then
            self:AddCombatLog("No clear landing space for Charge.", "warning")
            return false
        end

        run.playerX = destinationX
        run.playerY = destinationY
        run.activeEnemyId = target.uid
        self:AddCombatLog("You " .. string.lower(ability.name or "charge") .. " toward " .. string.lower(GetEnemyDisplayName(target)) .. "!", "player")
        return self:PlayerAttackEnemy(target, { ability = ability })
    end

    if abilityId == "thunder_clap" then
        local targets = GetAdjacentEnemies(run)
        if #targets == 0 then
            self:AddCombatLog("No adjacent enemies for Thunder Clap.", "warning")
            return false
        end

        SpendRunResource(run, resourceCost)
        GainRunResource(run, ability.resourceGain)
        SetRunAbilityCooldown(run, ability)
        run.turns = run.turns + 1

        local duration = math.max(1, math.floor(tonumber(ability.durationTurns) or 1))
        local weaken = math.max(0, tonumber(ability.effectValue) or 0)
        self:AddCombatLog("Thunder Clap crashes through the nearby enemies!", "player")

        for _, enemy in ipairs(targets) do
            if enemy.alive ~= false then
                self:DealRunDamage(enemy, ability, { allowWeaponTrait = false })
                if enemy.alive ~= false then
                    enemy.statuses = enemy.statuses or {}
                    enemy.statuses.weakened = { turns = duration, percent = weaken }
                end
            end
        end

        self:UpdateRunResource()
        self:RefreshRunCounters()
        self:RenderDungeonGrid()
        self:RunEnemyTurn()
        return true
    end

    if abilityId == "intimidating_shout" then
        local targets = GetAdjacentEnemies(run)
        if #targets == 0 then
            self:AddCombatLog("No adjacent enemies for Intimidating Shout.", "warning")
            return false
        end

        SpendRunResource(run, resourceCost)
        GainRunResource(run, ability.resourceGain)
        SetRunAbilityCooldown(run, ability)
        run.turns = run.turns + 1
        local duration = math.max(1, math.floor(tonumber(ability.durationTurns) or 1))
        for _, enemy in ipairs(targets) do
            enemy.statuses = enemy.statuses or {}
            enemy.statuses.feared = { turns = duration }
        end
        self:AddCombatLog(
            string.format("Intimidating Shout: adjacent enemies are feared for %d turns.", duration),
            "player"
        )
        self:UpdateRunResource()
        self:RefreshRunCounters()
        self:RenderDungeonGrid()
        self:RunEnemyTurn()
        return true
    end

    if abilityId == "shield_wall" then
        if not HasRunShield(run) then
            self:AddCombatLog("Shield Wall requires an equipped shield.", "warning")
            return false
        end

        SpendRunResource(run, resourceCost)
        GainRunResource(run, ability.resourceGain)
        SetRunAbilityCooldown(run, ability)
        run.buffs = run.buffs or {}
        run.buffs.shield_wall = {
            turns = math.max(1, math.floor(tonumber(ability.durationTurns) or 1)),
            reduction = math.max(0, tonumber(ability.effectValue) or 0),
            name = ability.name or "Shield Wall",
        }
        run.turns = run.turns + 1
        self:AddCombatLog(
            string.format("Shield Wall: -%d%% incoming damage for %d turns.",
                run.buffs.shield_wall.reduction,
                run.buffs.shield_wall.turns),
            "player"
        )
        self:UpdateRunResource()
        self:RefreshRunCounters()
        self:RenderDungeonGrid()
        self:RunEnemyTurn()
        return true
    end

    if abilityId == "berserker_rage" then
        SpendRunResource(run, resourceCost)
        GainRunResource(run, ability.resourceGain)
        SetRunAbilityCooldown(run, ability)
        run.buffs = run.buffs or {}
        run.buffs.berserker_rage = {
            turns = math.max(1, math.floor(tonumber(ability.durationTurns) or 1)),
            resourcePerHit = math.max(0, tonumber(ability.effectValue) or 0),
            name = ability.name or "Berserker Rage",
        }
        run.turns = run.turns + 1
        self:AddCombatLog(
            string.format("Berserker Rage: +%d %s now and +%d when hit for %d turns.",
                tonumber(ability.resourceGain) or 0,
                run.resourceType or "RESOURCE",
                run.buffs.berserker_rage.resourcePerHit,
                run.buffs.berserker_rage.turns),
            "player"
        )
        self:UpdateRunResource()
        self:RefreshRunCounters()
        self:RenderDungeonGrid()
        self:RunEnemyTurn()
        return true
    end

    if abilityId == "recklessness" then
        SpendRunResource(run, resourceCost)
        GainRunResource(run, ability.resourceGain)
        SetRunAbilityCooldown(run, ability)
        run.buffs = run.buffs or {}
        run.buffs.recklessness = {
            turns = math.max(1, math.floor(tonumber(ability.durationTurns) or 1)),
            critBonus = math.max(0, tonumber(ability.effectValue) or 0),
            damageTaken = math.max(0, tonumber(ability.secondaryValue) or 0),
            name = ability.name or "Recklessness",
        }
        run.turns = run.turns + 1
        self:AddCombatLog(
            string.format("Recklessness: +%d%% crit, +%d%% damage taken for %d turns.",
                run.buffs.recklessness.critBonus,
                run.buffs.recklessness.damageTaken,
                run.buffs.recklessness.turns),
            "player"
        )
        self:UpdateRunResource()
        self:RefreshRunCounters()
        self:RenderDungeonGrid()
        self:RunEnemyTurn()
        return true
    end

    if abilityId == "whirlwind" then
        local targets = GetAdjacentEnemies(run)
        if #targets == 0 then
            self:AddCombatLog("No adjacent enemies for Whirlwind.", "warning")
            return false
        end

        SpendRunResource(run, resourceCost)
        GainRunResource(run, ability.resourceGain)
        SetRunAbilityCooldown(run, ability)
        run.turns = run.turns + 1
        self:AddCombatLog("Whirlwind strikes every adjacent enemy!", "player")
        for _, enemy in ipairs(targets) do
            if enemy.alive ~= false then
                self:DealRunDamage(enemy, ability, { allowWeaponTrait = false })
            end
        end
        self:UpdateRunResource()
        self:RefreshRunCounters()
        self:RenderDungeonGrid()
        self:RunEnemyTurn()
        return true
    end

    if abilityId == "execute" then
        local target = GetAdjacentEnemy(run)
        if not target then
            self:AddCombatLog("No adjacent enemy to Execute.", "warning")
            return false
        end
        local threshold = math.max(1, math.min(100, tonumber(ability.effectValue) or 20))
        local healthPercent = (target.hp or 0) * 100 / math.max(1, target.maxHp or 1)
        if healthPercent > threshold then
            self:AddCombatLog(
                string.format("Execute requires the target at or below %d%% health.", threshold),
                "warning"
            )
            return false
        end
        return self:PlayerAttackEnemy(target, { ability = ability })
    end

    if abilityId == "overpower" or abilityId == "revenge" then
        local reactive = run.reactive and run.reactive[abilityId]
        if not reactive or (reactive.turns or 0) <= 0 then
            self:AddCombatLog((ability.name or abilityId) .. " is not ready.", "warning")
            return false
        end
        return self:PlayerAttackEnemy(nil, { ability = ability })
    end

    if abilityId == "shield_bash" then
        if not HasRunShield(run) then
            self:AddCombatLog("Shield Bash requires an equipped shield.", "warning")
            return false
        end
        return self:PlayerAttackEnemy(nil, { ability = ability })
    end

    if abilityId == "demoralizing_shout" then
        local targets = GetAdjacentEnemies(run)
        if #targets == 0 then
            self:AddCombatLog("No adjacent enemies for Demoralizing Shout.", "warning")
            return false
        end

        SpendRunResource(run, resourceCost)
        GainRunResource(run, ability.resourceGain)
        SetRunAbilityCooldown(run, ability)
        run.turns = run.turns + 1

        local duration = math.max(1, math.floor(tonumber(ability.durationTurns) or 1))
        local weaken = math.max(0, tonumber(ability.effectValue) or 0)
        for _, enemy in ipairs(targets) do
            enemy.statuses = enemy.statuses or {}
            enemy.statuses.weakened = { turns = duration, percent = weaken }
        end

        self:AddCombatLog(
            string.format("Demoralizing Shout: adjacent enemies deal -%d%% damage for %d turns.", weaken, duration),
            "player"
        )
        self:UpdateRunResource()
        self:RefreshRunCounters()
        self:RenderDungeonGrid()
        self:RunEnemyTurn()
        return true
    end

    if abilityId == "shield_block" then
        if not HasRunShield(run) then
            self:AddCombatLog("Shield Block requires an equipped shield.", "warning")
            return false
        end

        SpendRunResource(run, resourceCost)
        GainRunResource(run, ability.resourceGain)
        SetRunAbilityCooldown(run, ability)
        run.buffs = run.buffs or {}
        run.buffs.shield_block = {
            turns = math.max(1, math.floor(tonumber(ability.durationTurns) or 1)),
            percent = math.max(0, tonumber(ability.effectValue) or 0),
            name = ability.name or "Shield Block",
        }
        run.turns = run.turns + 1
        self:AddCombatLog(
            string.format("Shield Block: +%d%% block chance for %d turns.",
                run.buffs.shield_block.percent,
                math.max(1, math.floor(tonumber(ability.durationTurns) or 1))),
            "player"
        )
        self:UpdateRunResource()
        self:RefreshRunCounters()
        self:RenderDungeonGrid()
        self:RunEnemyTurn()
        return true
    end

    if abilityId == "disarm" then
        local target = GetAdjacentEnemy(run)
        if not target then
            self:AddCombatLog("No adjacent enemy to Disarm.", "warning")
            return false
        end

        SpendRunResource(run, resourceCost)
        GainRunResource(run, ability.resourceGain)
        SetRunAbilityCooldown(run, ability)
        run.turns = run.turns + 1
        target.statuses = target.statuses or {}
        target.statuses.disarmed = {
            turns = math.max(1, math.floor(tonumber(ability.durationTurns) or 1)),
            percent = math.max(0, tonumber(ability.effectValue) or 0),
        }
        self:AddCombatLog(
            string.format("Disarm: %s deals -%d%% damage for %d turns.",
                GetEnemyDisplayName(target),
                target.statuses.disarmed.percent,
                target.statuses.disarmed.turns),
            "player"
        )
        self:UpdateRunResource()
        self:RefreshRunCounters()
        self:RenderDungeonGrid()
        self:RunEnemyTurn()
        return true
    end

    if abilityId == "retaliation" then
        SpendRunResource(run, resourceCost)
        GainRunResource(run, ability.resourceGain)
        SetRunAbilityCooldown(run, ability)
        run.buffs = run.buffs or {}
        run.buffs.retaliation = {
            turns = math.max(1, math.floor(tonumber(ability.durationTurns) or 1)),
            name = ability.name or "Retaliation",
        }
        run.turns = run.turns + 1
        self:AddCombatLog(
            string.format("Retaliation armed for %d turns.", math.max(1, math.floor(tonumber(ability.durationTurns) or 1))),
            "player"
        )
        self:UpdateRunResource()
        self:RefreshRunCounters()
        self:RenderDungeonGrid()
        self:RunEnemyTurn()
        return true
    end

    if abilityId == "victory_rush" then
        local reactive = run.reactive and run.reactive.victory_rush
        if not reactive or (reactive.turns or 0) <= 0 then
            self:AddCombatLog("Victory Rush is not ready. Defeat an enemy first.", "warning")
            return false
        end
        return self:PlayerAttackEnemy(nil, { ability = ability })
    end

    if abilityId == "heroic_strike"
        or abilityId == "rend"
        or abilityId == "hamstring"
        or abilityId == "sunder_armor"
        or abilityId == "cleave"
        or abilityId == "slam"
        or abilityId == "pummel" then
        return self:PlayerAttackEnemy(nil, { ability = ability })
    end

    self:AddCombatLog((ability.name or abilityId) .. " is not wired to the combat engine yet.", "warning")
    return false
end

function GA:PlayerAttackEnemy(targetEnemy, attackOptions)
    local run = self.RunState
    if not run or not run.active then return false end

    local enemy = targetEnemy or GetAdjacentEnemy(run)
    if not enemy or enemy.alive == false
        or not IsAdjacent(run.playerX, run.playerY, enemy.x, enemy.y) then
        if self.DungeonRunStateText then
            self.DungeonRunStateText:SetText("NO TARGET IN MELEE RANGE")
            self.DungeonRunStateText:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
        end
        return false
    end

    attackOptions = type(attackOptions) == "table" and attackOptions or {}
    local ability = attackOptions.ability
    local resourceCost = math.max(0, tonumber(ability and ability.resourceCost) or 0)

    if ability then
        local cooldown = GetRunAbilityCooldown(run, ability.id)
        if cooldown > 0 then
            self:AddCombatLog(string.format("%s is on cooldown for %d more turn(s).", ability.name or ability.id, cooldown), "warning")
            return false
        end
        if not SpendRunResource(run, resourceCost) then
            if self.DungeonRunStateText then
                self.DungeonRunStateText:SetText(
                    string.format("NEED %d %s FOR %s", resourceCost, run.resourceType or "RESOURCE", string.upper(ability.name or ability.id or "ABILITY"))
                )
                self.DungeonRunStateText:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
            end
            return false
        end
        GainRunResource(run, ability.resourceGain)
        SetRunAbilityCooldown(run, ability)
    end

    run.turns = run.turns + 1

    if ability and run.reactive then
        if ability.id == "overpower" then
            run.reactive.overpower = nil
        elseif ability.id == "revenge" then
            run.reactive.revenge = nil
        elseif ability.id == "victory_rush" then
            run.reactive.victory_rush = nil
        end
    end

    local _, defeated, leveledUp, previousRunLevel, currentRunLevel, outcome, weapon =
        self:DealRunDamage(enemy, ability)

    if not ability and string.upper(tostring(run.resourceType or "")) == "RAGE"
        and self.ForeverRules and self.ForeverRules.CalculateRageFromSwing then
        local rage = self.ForeverRules:CalculateRageFromSwing(weapon, outcome)
        if rage > 0 then
            GainRunResource(run, rage)
            self:AddCombatLog(string.format("+%d Rage from the weapon swing.", rage), "system")
        end
    elseif not ability then
        GainRunResource(run, run.classGrowth and run.classGrowth.basicAttackResourceGain or 0)
    end
    self:UpdateRunResource()

    if ability and ability.id == "victory_rush" and outcome and (outcome.multiplier or 0) > 0 then
        local healPercent = math.max(0, tonumber(ability.effectValue) or 0)
        local healAmount = math.max(1, math.floor((run.playerMaxHealth or 1) * healPercent / 100 + 0.5))
        local before = run.playerHealth or 0
        run.playerHealth = math.min(run.playerMaxHealth or before, before + healAmount)
        local restored = math.max(0, run.playerHealth - before)
        self:AddCombatLog(string.format("Victory Rush restores %d HP.", restored), "player")
        self:UpdateRunHealth()
    elseif ability and ability.id == "cleave" and outcome and (outcome.multiplier or 0) > 0 then
        local extraTarget
        for _, candidate in ipairs(GetAdjacentEnemies(run)) do
            if candidate.uid ~= enemy.uid then extraTarget = candidate break end
        end
        if extraTarget then
            self:AddCombatLog("Cleave catches " .. string.lower(GetEnemyDisplayName(extraTarget)) .. " as well.", "player")
            self:DealRunDamage(extraTarget, ability, { allowWeaponTrait = false })
        end
    end

    if defeated and self.DungeonRunStateText then
        if leveledUp then
            self.DungeonRunStateText:SetText(string.format("LEVEL UP!  %d -> %d", previousRunLevel, currentRunLevel))
            self.DungeonRunStateText:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
        else
            self.DungeonRunStateText:SetText(string.upper(GetEnemyDisplayName(enemy)) .. " DEFEATED")
            self.DungeonRunStateText:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
        end
    end

    self:RefreshRunCounters()
    self:RenderDungeonGrid()
    self:RefreshActionButtons()
    if run.active then self:RunEnemyTurn() end
    return true
end
function GA:UpdateDungeonVisibility()
    local run = self.RunState
    if not run or not run.active then
        return
    end

    run.explored = run.explored or {}
    run.visible = {}

    local minX = math.max(1, run.playerX - VISION_RADIUS)
    local maxX = math.min(GRID_WIDTH, run.playerX + VISION_RADIUS)
    local minY = math.max(1, run.playerY - VISION_RADIUS)
    local maxY = math.min(GRID_HEIGHT, run.playerY + VISION_RADIUS)

    for worldY = minY, maxY do
        for worldX = minX, maxX do
            if IsWithinVisionRadius(run.playerX, run.playerY, worldX, worldY)
                and HasLineOfSight(run.playerX, run.playerY, worldX, worldY) then

                local key = CellKey(worldX, worldY)
                run.visible[key] = true
                run.explored[key] = true
            end
        end
    end

    run.visible[CellKey(run.playerX, run.playerY)] = true
    run.explored[CellKey(run.playerX, run.playerY)] = true
end

function GA:IsDungeonCellVisible(worldX, worldY)
    local run = self.RunState
    if not run or not run.active then
        return true
    end

    return run.visible and run.visible[CellKey(worldX, worldY)] == true
end

function GA:IsDungeonCellExplored(worldX, worldY)
    local run = self.RunState
    if not run or not run.active then
        return true
    end

    return run.explored and run.explored[CellKey(worldX, worldY)] == true
end

local function Clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

function GA:UpdateDungeonCamera()
    local run = self.RunState
    local startX, startY = GetDungeonStart()
    local focusX = run and run.playerX or startX
    local focusY = run and run.playerY or startY

    local halfW = math.floor(VIEWPORT_WIDTH / 2)
    local halfH = math.floor(VIEWPORT_HEIGHT / 2)
    local maxCameraX = GRID_WIDTH - VIEWPORT_WIDTH + 1
    local maxCameraY = GRID_HEIGHT - VIEWPORT_HEIGHT + 1

    self.DungeonCameraX = Clamp(focusX - halfW, 1, maxCameraX)
    self.DungeonCameraY = Clamp(focusY - halfH, 1, maxCameraY)
end

function GA:RefreshDungeonMiniMap()
    local miniMap = self.DungeonMiniMap
    if not miniMap or not miniMap.cells then
        return
    end

    local run = self.RunState
    if not run or not run.active or not run.floorMap then
        miniMap:Hide()
        if self.DungeonMiniMapLabel then
            self.DungeonMiniMapLabel:Hide()
        end
        return
    end

    miniMap:Show()
    if self.DungeonMiniMapLabel then
        self.DungeonMiniMapLabel:Show()
    end

    local markers = GetDungeonMarkers()
    local visibleEnemies = {}

    for _, enemy in ipairs(run.enemies or {}) do
        if enemy.alive ~= false and self:IsDungeonCellVisible(enemy.x, enemy.y) then
            visibleEnemies[CellKey(enemy.x, enemy.y)] = true
        end
    end

    for y = 1, GRID_HEIGHT do
        for x = 1, GRID_WIDTH do
            local key = CellKey(x, y)
            local cell = miniMap.cells[key]

            if cell and cell.texture then
                local explored = self:IsDungeonCellExplored(x, y)
                local visible = self:IsDungeonCellVisible(x, y)
                local state = "unseen"
                local r, g, b, a = 0.005, 0.005, 0.005, 1

                if explored then
                    if IsDungeonWall(x, y) then
                        state = visible and "wall-visible" or "wall-memory"
                        if visible then
                            r, g, b, a = 0.31, 0.25, 0.14, 1
                        else
                            r, g, b, a = 0.13, 0.11, 0.075, 1
                        end
                    else
                        state = visible and "floor-visible" or "floor-memory"
                        if visible then
                            r, g, b, a = 0.16, 0.14, 0.10, 1
                        else
                            r, g, b, a = 0.07, 0.06, 0.045, 1
                        end
                    end

                    local marker = markers[key]
                    local chestOpened = run.openedChests and run.openedChests[key]
                    if marker and not (marker.kind == "chest" and chestOpened) then
                        if marker.kind == "exit" then
                            if IsDungeonExitLocked(run) then
                                state = "exit-locked"
                                r, g, b, a = COLORS.red[1], COLORS.red[2], COLORS.red[3], 1
                            else
                                state = "exit"
                                r, g, b, a = COLORS.green[1], COLORS.green[2], COLORS.green[3], 1
                            end
                        elseif marker.kind == "stairsUp" then
                            state = marker.kind
                            r, g, b, a = COLORS.green[1], COLORS.green[2], COLORS.green[3], 1
                        elseif marker.kind == "chest" then
                            state = "chest"
                            r, g, b, a = COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1
                        elseif marker.kind == "door" then
                            local doorOpen = run.openDoors and run.openDoors[key]
                            state = doorOpen and "door-open" or "door-closed"
                            if doorOpen then
                                r, g, b, a = 0.22, 0.19, 0.13, 1
                            else
                                r, g, b, a = COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1
                            end
                        elseif marker.kind == "shop" then
                            state = "shop"
                            r, g, b, a = COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1
                        elseif marker.kind == "shrine" then
                            local shrineUsed = marker.roomIndex
                                and run.roomStates
                                and run.roomStates[marker.roomIndex]
                                and run.roomStates[marker.roomIndex].shrineUsed
                            state = shrineUsed and "shrine-used" or "shrine"
                            if shrineUsed then
                                r, g, b, a = 0.18, 0.17, 0.12, 1
                            else
                                r, g, b, a = COLORS.green[1], COLORS.green[2], COLORS.green[3], 1
                            end
                        elseif marker.kind == "elite" or marker.kind == "boss" then
                            state = marker.kind
                            r, g, b, a = COLORS.red[1], COLORS.red[2], COLORS.red[3], 1
                        elseif marker.kind == "event" then
                            state = "event"
                            if marker.color == "red" then
                                r, g, b, a = COLORS.red[1], COLORS.red[2], COLORS.red[3], 1
                            elseif marker.color == "green" then
                                r, g, b, a = COLORS.green[1], COLORS.green[2], COLORS.green[3], 1
                            else
                                r, g, b, a = COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1
                            end
                        elseif marker.kind == "roomCleared" then
                            state = "room-cleared"
                            r, g, b, a = COLORS.green[1], COLORS.green[2], COLORS.green[3], 1
                        end
                    end
                end

                if visibleEnemies[key] then
                    state = "enemy"
                    r, g, b, a = COLORS.red[1], COLORS.red[2], COLORS.red[3], 1
                end

                if run.playerX == x and run.playerY == y then
                    state = "player"
                    r, g, b, a = COLORS.green[1], COLORS.green[2], COLORS.green[3], 1
                end

                if cell.state ~= state then
                    cell.texture:SetColorTexture(r, g, b, a)
                    cell.state = state
                end
            end
        end
    end
end


local function GetDungeonFloorAccess(run)
    if not run or not run.active then
        return nil, nil
    end

    local floorNumber = run.floor or 1
    local startX, startY = GetDungeonStart()
    if floorNumber > 1
        and run.playerX == startX
        and run.playerY == startY then
        return "up", floorNumber - 1
    end

    local exitX, exitY = GetDungeonExit()
    if run.playerX == exitX
        and run.playerY == exitY
        and not IsDungeonExitLocked(run) then
        if floorNumber >= 9 then
            return "complete", nil
        end

        return "down", floorNumber + 1
    end

    return nil, nil
end

function GA:RefreshDungeonFloorAccess()
    local button = self.DungeonFloorAccessButton
    if not button then
        return
    end

    local direction, targetFloor = GetDungeonFloorAccess(self.RunState)
    button.gaFloorDirection = direction
    button.gaFloorTarget = targetFloor

    if not direction then
        button:Hide()
        return
    end

    if direction == "up" then
        button.label:SetText("ASCEND")
        button.gaTooltipTitle = "ASCEND"
        button.gaTooltipText = string.format("Return to Floor %d.", targetFloor)
    elseif direction == "complete" then
        button.label:SetText("EXIT")
        button.gaTooltipTitle = "EXIT DUNGEON"
        button.gaTooltipText = "Leave the final floor and complete this dungeon run."
    else
        button.label:SetText("DESCEND")
        button.gaTooltipTitle = "DESCEND"
        button.gaTooltipText = string.format("Descend to Floor %d.", targetFloor)
    end

    button:Show()
end

function GA:UseDungeonFloorAccess()
    local direction = GetDungeonFloorAccess(self.RunState)

    if direction == "up" then
        self:ReturnDungeonFloor()
        return true
    elseif direction == "down" or direction == "complete" then
        self:AdvanceDungeonFloor()
        return true
    end

    self:RefreshDungeonFloorAccess()
    return false
end

function GA:RenderDungeonGrid()
    if not self.DungeonGrid or not self.DungeonGrid.cells then
        return
    end

    local run = self.RunState
    if run and run.active then
        self:UpdateDungeonVisibility()
    end

    self:UpdateDungeonCamera()

    local cameraX = self.DungeonCameraX or 1
    local cameraY = self.DungeonCameraY or 1
    local palette = GetActiveDungeonStyle()

    for viewY = 1, VIEWPORT_HEIGHT do
        for viewX = 1, VIEWPORT_WIDTH do
            local entry = self.DungeonGrid.cells[CellKey(viewX, viewY)]
            if entry then
                local worldX = cameraX + viewX - 1
                local worldY = cameraY + viewY - 1
                local wall = IsDungeonWall(worldX, worldY)
                local visible = self:IsDungeonCellVisible(worldX, worldY)
                local explored = self:IsDungeonCellExplored(worldX, worldY)

                entry.worldX = worldX
                entry.worldY = worldY
                entry.wall = wall

                entry.marker:SetText("")
                if entry.terrainTexture then
                    entry.terrainTexture:Hide()
                    entry.terrainTexture:SetAlpha(1)
                    entry.terrainTexture:SetTexCoord(0, 1, 0, 1)
                end
                if entry.lootIcon then
                    entry.lootIcon:Hide()
                    entry.lootIcon:SetAlpha(1)
                    entry.lootIcon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
                end
                if entry.eventIcon then
                    entry.eventIcon:Hide()
                    entry.eventIcon:SetAlpha(1)
                    entry.eventIcon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
                end
                if entry.enemyIcon then
                    entry.enemyIcon:Hide()
                end
                if entry.enemyHealthBackdrop then
                    entry.enemyHealthBackdrop:Hide()
                end
                if entry.enemySkillIcon then
                    entry.enemySkillIcon:Hide()
                end

                if not explored then
                    -- Unseen: almost completely black. The player has no map
                    -- knowledge of either walls or floor here yet.
                    entry.frame:SetBackdropColor(0.008, 0.007, 0.006, 1)
                    entry.frame:SetBackdropBorderColor(0, 0, 0, 0)
                elseif not visible then
                    -- Explored memory keeps the selected ecosystem palette,
                    -- but dims it heavily.
                    if wall then
                        entry.frame:SetBackdropColor(palette.wallMemory[1], palette.wallMemory[2], palette.wallMemory[3], palette.wallMemory[4])
                        entry.frame:SetBackdropBorderColor(palette.wallMemoryBorder[1], palette.wallMemoryBorder[2], palette.wallMemoryBorder[3], palette.wallMemoryBorder[4])
                    else
                        entry.frame:SetBackdropColor(palette.floorMemory[1], palette.floorMemory[2], palette.floorMemory[3], palette.floorMemory[4])
                        entry.frame:SetBackdropBorderColor(palette.floorMemoryBorder[1], palette.floorMemoryBorder[2], palette.floorMemoryBorder[3], palette.floorMemoryBorder[4])
                    end
                else
                    -- Currently visible: biome style is consistent for the
                    -- entire nine-floor run.
                    if wall then
                        entry.frame:SetBackdropColor(palette.wallVisible[1], palette.wallVisible[2], palette.wallVisible[3], palette.wallVisible[4])
                        entry.frame:SetBackdropBorderColor(palette.wallBorder[1], palette.wallBorder[2], palette.wallBorder[3], palette.wallBorder[4])
                    else
                        entry.frame:SetBackdropColor(palette.floorVisible[1], palette.floorVisible[2], palette.floorVisible[3], palette.floorVisible[4])
                        entry.frame:SetBackdropBorderColor(palette.floorBorder[1], palette.floorBorder[2], palette.floorBorder[3], palette.floorBorder[4])
                    end
                end

                if entry.terrainTexture and explored then
                    local terrainPath
                    local texLeft, texRight, texTop, texBottom

                    if wall then
                        terrainPath = GetActiveDungeonWallAutotileTexture()
                        if terrainPath then
                            local wallMask = GetDungeonWallAutotileMask(worldX, worldY)
                            texLeft, texRight, texTop, texBottom = GetWallAutotileTexCoord(wallMask)
                        else
                            terrainPath = GetActiveDungeonTileTexture(true)
                        end
                    else
                        terrainPath = GetActiveDungeonTileTexture(false)
                    end

                    if terrainPath then
                        entry.terrainTexture:SetTexture(terrainPath)
                        if texLeft then
                            entry.terrainTexture:SetTexCoord(texLeft, texRight, texTop, texBottom)
                        else
                            entry.terrainTexture:SetTexCoord(0, 1, 0, 1)
                        end
                        entry.terrainTexture:SetAlpha(visible and 1 or 0.24)
                        entry.terrainTexture:Show()
                    end
                end

                -- Static landmarks are remembered after discovery. They are
                -- bright while visible and muted when only remembered.
                if explored then
                    local worldKey = CellKey(worldX, worldY)
                    local staticMarker = GetDungeonMarkers()[worldKey]
                    local chestOpened = run
                        and run.openedChests
                        and run.openedChests[worldKey]

                    if staticMarker
                        and not (staticMarker.kind == "chest" and chestOpened)
                        and not (staticMarker.kind == "event" and IsDungeonEventResolved(run, worldKey)) then
                        local renderedMarkerIcon = false
                        if staticMarker.kind == "chest" and entry.lootIcon then
                            local lootIcon = GetDungeonLootIcon(run, worldKey)
                            if lootIcon then
                                entry.lootIcon:SetTexture(lootIcon)
                                entry.lootIcon:SetAlpha(visible and 1 or 0.32)
                                entry.lootIcon:Show()
                                renderedMarkerIcon = true
                            end
                        elseif staticMarker.kind == "event" and entry.eventIcon then
                            local event = GetStudioDungeonEvent(staticMarker.eventId)
                            entry.eventIcon:SetTexture(GetDungeonEventIcon(event))
                            entry.eventIcon:SetAlpha(visible and 1 or 0.32)
                            entry.eventIcon:Show()
                            renderedMarkerIcon = true
                        end

                        if renderedMarkerIcon then
                            entry.marker:SetText("")
                        elseif staticMarker.kind == "door" then
                            local doorOpen = run
                                and run.openDoors
                                and run.openDoors[worldKey]
                            entry.marker:SetText(doorOpen and "/" or "+")
                        elseif staticMarker.kind == "exit" and IsDungeonExitLocked(run) then
                            entry.marker:SetText("X")
                        elseif staticMarker.kind == "shrine"
                            and staticMarker.roomIndex
                            and run
                            and run.roomStates
                            and run.roomStates[staticMarker.roomIndex]
                            and run.roomStates[staticMarker.roomIndex].shrineUsed then
                            entry.marker:SetText("s")
                        else
                            entry.marker:SetText(staticMarker.text)
                        end

                        if not visible then
                            entry.marker:SetTextColor(0.24, 0.22, 0.18)
                        elseif staticMarker.color == "red" then
                            entry.marker:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
                        elseif staticMarker.color == "gold" then
                            entry.marker:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
                        elseif staticMarker.kind == "exit" and IsDungeonExitLocked(run) then
                            entry.marker:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
                        elseif staticMarker.kind == "shrine"
                            and staticMarker.roomIndex
                            and run
                            and run.roomStates
                            and run.roomStates[staticMarker.roomIndex]
                            and run.roomStates[staticMarker.roomIndex].shrineUsed then
                            entry.marker:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
                        elseif staticMarker.color == "green" then
                            entry.marker:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
                        elseif staticMarker.kind == "door" then
                            local doorOpen = run
                                and run.openDoors
                                and run.openDoors[worldKey]
                            if doorOpen then
                                entry.marker:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
                            else
                                entry.marker:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
                            end
                        else
                            entry.marker:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
                        end
                    end
                end
            end
        end
    end

    -- Creatures are not remembered through fog. Every living enemy renders
    -- only while its world cell is currently visible.
    for _, enemy in ipairs(run and run.enemies or {}) do
        if enemy.alive ~= false and self:IsDungeonCellVisible(enemy.x, enemy.y) then
            local enemyViewX = enemy.x - cameraX + 1
            local enemyViewY = enemy.y - cameraY + 1

            if enemyViewX >= 1 and enemyViewX <= VIEWPORT_WIDTH
                and enemyViewY >= 1 and enemyViewY <= VIEWPORT_HEIGHT then

                local enemyCell = self.DungeonGrid.cells[CellKey(enemyViewX, enemyViewY)]
                if enemyCell and enemyCell.enemyIcon then
                    enemyCell.frame:SetBackdropBorderColor(COLORS.red[1], COLORS.red[2], COLORS.red[3], 1)
                    enemyCell.marker:SetText("")
                    enemyCell.enemyIcon:SetTexture(enemy.texture or KOBOLD_TEXTURE)

                    local coords = enemy.gridTexCoord
                    if coords then
                        enemyCell.enemyIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                    else
                        enemyCell.enemyIcon:SetTexCoord(0, 1, 0, 1)
                    end

                    enemyCell.enemyIcon:Show()

                    if enemyCell.enemyHealthBackdrop and enemyCell.enemyHealthBar then
                        local maxHp = math.max(1, tonumber(enemy.maxHp) or 1)
                        local currentHp = math.max(0, math.min(maxHp, tonumber(enemy.hp) or maxHp))
                        enemyCell.enemyHealthBar:SetMinMaxValues(0, maxHp)
                        enemyCell.enemyHealthBar:SetValue(currentHp)
                        enemyCell.enemyHealthBackdrop:Show()
                    end

                    if enemyCell.enemySkillIcon and enemy.pendingSkill and enemy.pendingSkill.skillId then
                        local pendingSkill
                        for _, skill in ipairs(GA.StudioData and GA.StudioData.monsterSkills or {}) do
                            if skill.id == enemy.pendingSkill.skillId then
                                pendingSkill = skill
                                break
                            end
                        end
                        if pendingSkill then
                            local texture = GA.ResolveStudioIconTexture
                                and GA:ResolveStudioIconTexture(pendingSkill.icon, "Interface\\Icons\\INV_Misc_QuestionMark")
                                or "Interface\\Icons\\INV_Misc_QuestionMark"
                            enemyCell.enemySkillIcon:SetTexture(texture)
                            enemyCell.enemySkillIcon:Show()
                        end
                    end
                end
            end
        end
    end

    local startX, startY = GetDungeonStart()
    local playerX = run and run.playerX or startX
    local playerY = run and run.playerY or startY
    local playerViewX = playerX - cameraX + 1
    local playerViewY = playerY - cameraY + 1

    if playerViewX >= 1 and playerViewX <= VIEWPORT_WIDTH
        and playerViewY >= 1 and playerViewY <= VIEWPORT_HEIGHT then

        local playerCell = self.DungeonGrid.cells[CellKey(playerViewX, playerViewY)]
        if playerCell then
            playerCell.frame:SetBackdropColor(0.11, 0.20, 0.08, 1)
            playerCell.frame:SetBackdropBorderColor(COLORS.green[1], COLORS.green[2], COLORS.green[3], 1)
            playerCell.marker:SetText("@")
            playerCell.marker:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
        end
    end

    self:RefreshActionButtons()
    self:RefreshEnemyCombatCard()
    self:RefreshDungeonMiniMap()
    self:RefreshDungeonFloorAccess()

    if self.CharacterSheetFrame and self.CharacterSheetFrame:IsShown() then
        self:RefreshCharacterSheet()
    end
end

function GA:RefreshRunCounters()
    local run = self.RunState

    if self.DungeonFloorValue then
        self.DungeonFloorValue:SetText(string.format("%d / 9", run and run.floor or 1))
    end
    if self.DungeonLevelValue then
        self.DungeonLevelValue:SetText(tostring(run and run.runLevel or "--"))
    end
    if self.DungeonXpValue then
        if run and run.runLevel and run.progression and run.runLevel >= run.progression.maxRunLevel then
            self.DungeonXpValue:SetText("MAX")
        elseif run then
            self.DungeonXpValue:SetText(string.format("%d / %d", run.runXp or 0, GetRunXpRequired(run)))
        else
            self.DungeonXpValue:SetText("--")
        end
    end
    if self.DungeonScoreValue then
        self.DungeonScoreValue:SetText(tostring(run and run.score or 0))
    end
    if self.DungeonTurnsValue then
        self.DungeonTurnsValue:SetText(tostring(run and run.turns or 0))
    end
    if self.DungeonCopperValue then
        self.DungeonCopperValue:SetText(FormatCopperValue(run and run.copper or 0))
    end
end

function GA:BeginDungeonRun()
    self:HideDungeonRunSummary()
    if self.RunState and self.RunState.active then
        return
    end

    local currentKey = self.GetCurrentCharacterKey and self:GetCurrentCharacterKey()
    local selected = self.GetSelectedDungeonCharacter and self:GetSelectedDungeonCharacter()

    if selected and selected.key == currentKey then
        self:RefreshMainHandInfo(true)
        selected = self:GetSelectedDungeonCharacter()
    end

    if selected and self.HasSuspendedRun and self:HasSuspendedRun(selected.key) then
        return self:ResumeDungeonRun(selected.key)
    end

    if selected and selected.hardcore and selected.dead then
        if self.DungeonRunStateText then
            self.DungeonRunStateText:SetText("HARDCORE HERO IS DEAD")
            self.DungeonRunStateText:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
        end
        return
    end

    local effectiveEquipment = selected and self.GetEffectiveCharacterEquipment
        and self:GetEffectiveCharacterEquipment(selected)
        or (selected and selected.equipment or {})
    local selectedWeapon = ResolveCharacterWeapon(self, selected)
    if not selected or not selectedWeapon then
        if self.DungeonRunStateText then
            self.DungeonRunStateText:SetText("SELECT A CHARACTER WITH A CACHED LOADOUT")
            self.DungeonRunStateText:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
        end
        return
    end

    local name = selected.name or "Unknown"
    local level = selected.level or 0
    local className = selected.className or "Adventurer"
    local classId = string.lower(tostring(selected.classId or selected.classFile or className or ""))
    if not (self.IsStudioClassPlayable and self:IsStudioClassPlayable(classId)) then
        if self.DungeonRunStateText then
            self.DungeonRunStateText:SetText("CLASS NOT READY FOR GOBLINARCADE")
            self.DungeonRunStateText:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
        end
        return
    end
    local progression = GetRunProgression()
    local classGrowth = GetClassRunGrowth(classId)
    local difficulty = self.NormalizeDifficulty and self:NormalizeDifficulty(selected.difficulty) or "NORMAL"
    local difficultyDefinition = self.GetDifficultyDefinition
        and self:GetDifficultyDefinition(difficulty)
        or { id = difficulty, label = difficulty, hpMultiplier = 1, damageMultiplier = 1, scoreMultiplier = 1 }
    local maxHealth = self:ScaleCombatValue(selected.maxHealth or 0)
    local floor = 1

    if not self.EnemyGenerator or not self.FloorGenerator or not self.DungeonGenerator then
        if self.DungeonRunStateText then
            self.DungeonRunStateText:SetText("DUNGEON GENERATORS NOT LOADED")
            self.DungeonRunStateText:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
        end
        return
    end

    local gearPressure = self.EnemyGenerator:CalculateGearPressure(
        level,
        effectiveEquipment or {}
    )

    local dungeonSeed = math.random(1, 2147483646)
    local selectedEcosystem = self.DungeonGenerator.SelectEcosystem
        and self.DungeonGenerator:SelectEcosystem(dungeonSeed)
        or nil
    local ecosystemId = selectedEcosystem and selectedEcosystem.id or nil
    local floorMap = self.DungeonGenerator:GenerateFloor(
        GRID_WIDTH,
        GRID_HEIGHT,
        floor,
        dungeonSeed,
        ecosystemId
    )

    if not floorMap then
        if self.DungeonRunStateText then
            self.DungeonRunStateText:SetText("DUNGEON GENERATION FAILED")
            self.DungeonRunStateText:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
        end
        return
    end

    SetActiveFloorMap(floorMap)
    local startX, startY = GetDungeonStart()

    local floorSetup = GenerateFloorSetup(
        self.FloorGenerator,
        self.EnemyGenerator,
        level,
        floor,
        gearPressure,
        floorMap,
        difficulty
    )

    local walkableTiles = floorSetup.walkableTiles
    local densityProfile = floorSetup.densityProfile
    local baseEnemyCount = floorSetup.baseEnemyCount
    local archetypeCounts = floorSetup.enemyComposition
    local rankCounts = floorSetup.enemyRankComposition
    local roomRoleCounts = floorMap.roomRoleCounts or {}
    local floorEnemies = floorSetup.enemies
    local sampleEnemy = floorEnemies[1]
    local unlockedAbilities = GetClassAbilityIdSet(classId, level)
    local actionSlots = self:LoadSavedActionSlots(selected.key, unlockedAbilities)
    local preparedSupplies = self.TakeCharacterSuppliesForRun
        and self:TakeCharacterSuppliesForRun(selected.key)
        or {}
    local startingBackpack = {}
    for i, item in ipairs(preparedSupplies) do
        startingBackpack[i] = CopyTable(item)
    end

    self.RunState = {
        active = true,
        completed = false,
        ruleset = self.ForeverRules and self.ForeverRules.ID or "LEGACY",
        floor = floor,
        runId = tostring(dungeonSeed) .. ":" .. tostring(time and time() or 0),
        score = 0,
        copper = 0,
        turns = 0,
        difficulty = difficulty,
        difficultyLabel = difficultyDefinition.label or difficulty,
        difficultyScoreMultiplier = tonumber(difficultyDefinition.scoreMultiplier) or 1,
        stats = {
            kills = 0,
            eliteKills = 0,
            bossKills = 0,
            chests = 0,
            shrines = 0,
            events = 0,
            floorsCleared = 0,
            copperEarned = 0,
            copperSpent = 0,
            itemsBought = 0,
            itemsSold = 0,
        },
        scoreBreakdown = {
            enemy = 0,
            rankBonus = 0,
            chest = 0,
            floor = 0,
            shrine = 0,
            event = 0,
            completion = 0,
        },
        lootSummary = {},
        clearedFloors = {},
        startLevel = level,
        runLevel = level,
        runXp = 0,
        totalRunXp = 0,
        levelsGained = 0,
        progression = CopyTable(progression),
        classId = classId,
        classGrowth = CopyTable(classGrowth),
        resourceType = classGrowth.resourceType,
        baseResourceMax = classGrowth.baseResourceMax,
        resourceMax = classGrowth.baseResourceMax,
        resource = 0,
        cooldowns = {},
        buffs = {},
        reactive = {},
        monsterStatuses = {},
        stance = "battle",
        actionBarKey = selected.key,
        actionSlots = actionSlots,
        unlockedAbilities = unlockedAbilities,
        playerX = startX,
        playerY = startY,
        playerHealth = maxHealth,
        playerMaxHealth = maxHealth,
        baseMaxHealth = maxHealth,
        rulesBaseHealth = maxHealth,
        equipment = CopyTable(effectiveEquipment or {}),
        backpack = startingBackpack,
        preRunSupplyCount = #preparedSupplies,
        openedChests = {},
        openDoors = {},
        shopStock = nil,
        explored = {},
        visible = {},
        gearPressure = CopyTable(gearPressure),
        dungeonSeed = dungeonSeed,
        ecosystemId = floorMap.ecosystemId,
        ecosystemName = floorMap.ecosystemName,
        ecosystemStyle = floorMap.stylePreset,
        floorMap = floorMap,
        floorStates = {},
        roomRoleCounts = CopyTable(roomRoleCounts),
        roomStates = BuildInitialRoomStates(floorMap),
        shrineDamageBonus = 0,
        eventDamageBonus = 0,
        eventStates = BuildInitialEventStates(floorMap),
        eventFlags = {},
        eventQueue = {},
        eventHistory = {},
        chestLoot = BuildFloorChestLoot(floorMap, 1),
        densityProfile = CopyTable(densityProfile),
        walkableTiles = walkableTiles,
        baseEnemyCount = baseEnemyCount,
        enemyCount = #floorEnemies,
        enemyComposition = CopyTable(archetypeCounts),
        enemyRankComposition = CopyTable(rankCounts),
        enemies = floorEnemies,
        activeEnemyId = nil,
        enemyPhase = 0,
        snapshot = {
            characterKey = selected.key,
            name = name,
            level = level,
            className = className,
            classFile = selected.classFile,
            raceName = selected.raceName,
            raceId = selected.raceId,
            realm = selected.realm,
            sourceType = selected.sourceType,
            isArcadeGenerated = selected.isArcadeGenerated,
            hardcore = selected.hardcore == true,
            difficulty = difficulty,
            dead = selected.dead == true,
            maxHealth = maxHealth,
            mainHandLink = effectiveEquipment and effectiveEquipment.mainhand and effectiveEquipment.mainhand.link or selected.weaponLink,
            weaponIcon = effectiveEquipment and effectiveEquipment.mainhand and effectiveEquipment.mainhand.icon or selected.weaponIcon,
            weapon = selectedWeapon,
        },
    }

    if self.RunState.equipment and self.RunState.equipment.mainhand then
        self.RunState.equipment.mainhand.arcadeWeapon = CopyTable(selectedWeapon)
    end

    self:SaveRunActionSlots()
    self:UpdateRunHealth()
    self:UpdateRunResource()
    self:RecalculateRunGearStats()
    self:RefreshRunWeaponFromEquipment()

    if self.DungeonBeginButton then
        self.DungeonBeginButton:SetEnabled(true)
        self.DungeonBeginButton.label:SetText("OPTIONS")
        self.DungeonBeginButton.label:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    end

    if self.DungeonFloorTitle then
        self.DungeonFloorTitle:SetText(string.format(
            "FLOOR 1  -  %s  -  %d ROOMS  -  %d ENEMIES",
            floorMap.name or "DUNGEON",
            floorMap.roomCount or 0,
            #floorEnemies
        ))
    end

    if self.DungeonRunStateText then
        self.DungeonRunStateText:SetText("WASD / ARROWS")
        self.DungeonRunStateText:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
    end

    if self.DungeonRunPage and self.DungeonRunPage.SetPropagateKeyboardInput then
        self.DungeonRunPage:SetPropagateKeyboardInput(false)
    end

    self:SetDungeonSetupMode(false)
    self:SetRunMode(true)
    self:SetDungeonRunPortraitMode(true)
    self:ResetCombatLog()
    self:AddCombatLog(
        string.format(
            "Dungeon Run started. Difficulty: %s%s.",
            string.upper(self.RunState.difficultyLabel or self.RunState.difficulty or "NORMAL"),
            self.RunState.snapshot.hardcore and " / HARDCORE" or ""
        ),
        "system"
    )
    self:AddCombatLog(
        string.format("Loadout locked: %s  %d-%d damage.",
            self.RunState.snapshot.weapon.sourceName or "Main hand",
            self.RunState.snapshot.weapon.damageMin,
            self.RunState.snapshot.weapon.damageMax),
        "player"
    )

    if #preparedSupplies > 0 then
        self:AddCombatLog(
            string.format(
                "%d pre-run supply item%s committed to this run.",
                #preparedSupplies,
                #preparedSupplies == 1 and "" or "s"
            ),
            "system"
        )
    end
    self:AddCombatLog(
        string.format(
            "%s floor: %d enemies across %d walkable tiles.",
            densityProfile.key,
            #floorEnemies,
            walkableTiles
        ),
        "enemy"
    )
    self:AddCombatLog(
        string.format(
            "Layout: %s, %d rooms, %d doors, seed %d.",
            floorMap.name or "Dungeon",
            floorMap.roomCount or 0,
            floorMap.doorCount or 0,
            floorMap.seed or 0
        ),
        "system"
    )
    self:AddCombatLog(
        string.format(
            "Ecosystem: %s. This ecosystem remains active for all 9 floors.",
            floorMap.ecosystemName or self.RunState.ecosystemName or "Legacy Dungeon"
        ),
        "system"
    )
    self:AddCombatLog(
        "Rooms: " .. BuildRoomRoleText(roomRoleCounts) .. ".",
        "system"
    )
    self:AddCombatLog(
        "Composition: " .. BuildCompositionText(archetypeCounts) .. ".",
        "system"
    )
    self:AddCombatLog(
        "Ranks: " .. BuildRankCompositionText(rankCounts) .. ".",
        "system"
    )
    self:AddCombatLog("Vision radius: 4. Walls block line of sight.", "system")
    self:AddCombatLog(
        string.format(
            "Scaling starts at Lv %d, gear %d/%d (%.2fx), overgear %.0f%%.",
            level,
            gearPressure.actualGearSum,
            gearPressure.expectedGearSum,
            gearPressure.gearIndex,
            gearPressure.overgear * 100
        ),
        "system"
    )
    self:AddCombatLog(
        string.format("Run progression: Level %d, %d XP to next level. Run levels reset after the run.", level, GetRunXpRequired(self.RunState)),
        "system"
    )
    self:AddCombatLog(
        "Forever rules active: STR/AGI/STA derived stats, Weapon Skill vs Defense, Hit/Crit/Expertise, Classic armor, Block Value and normalized Rage.",
        "system"
    )
    if sampleEnemy then
        self:AddCombatLog(
            string.format(
                "%s Lv %d profile: %d HP, %d-%d damage.",
                GetEnemyDisplayName(sampleEnemy),
                sampleEnemy.level,
                sampleEnemy.maxHp,
                sampleEnemy.damageMin,
                sampleEnemy.damageMax
            ),
            "system"
        )
    end
    self:AddCombatLog("Press C for character sheet and backpack.", "system")

    self:RefreshRunCounters()
    self:RenderDungeonGrid()
end

local function CaptureCurrentFloorState(run)
    if not run or not run.floor or not run.floorMap then
        return nil
    end

    return {
        floorMap = CopyTable(run.floorMap),
        roomRoleCounts = CopyTable(run.roomRoleCounts or {}),
        roomStates = CopyTable(run.roomStates or {}),
        eventStates = CopyTable(run.eventStates or {}),
        chestLoot = CopyTable(run.chestLoot or {}),
        openedChests = CopyTable(run.openedChests or {}),
        openDoors = CopyTable(run.openDoors or {}),
        shopStock = run.shopStock and CopyTable(run.shopStock) or nil,
        explored = CopyTable(run.explored or {}),
        densityProfile = CopyTable(run.densityProfile or {}),
        walkableTiles = run.walkableTiles,
        baseEnemyCount = run.baseEnemyCount,
        enemyCount = run.enemyCount,
        enemyComposition = CopyTable(run.enemyComposition or {}),
        enemyRankComposition = CopyTable(run.enemyRankComposition or {}),
        enemies = CopyTable(run.enemies or {}),
        enemyPhase = run.enemyPhase or 0,
    }
end

local function SaveCurrentFloorState(run)
    if not run or not run.floor then
        return
    end

    run.floorStates = run.floorStates or {}
    run.floorStates[run.floor] = CaptureCurrentFloorState(run)
end

local function ReturnDirectlyToCharacterSelection(self)
    self:CloseRunControlMenu()
    self:CloseShrineChoice()
    self:CloseDungeonEvent()
    self:CloseDungeonShop()
    self:CloseSpellbook()
    if self.CharacterSheetFrame then self.CharacterSheetFrame:Hide() end
    self:CancelCharacterItemDrag()

    self.RunState = nil
    SetActiveFloorMap(nil)
    self.DungeonCameraX = nil
    self.DungeonCameraY = nil

    if self.DungeonRunPage and self.DungeonRunPage.SetPropagateKeyboardInput then
        self.DungeonRunPage:SetPropagateKeyboardInput(true)
    end

    self:SetDungeonRunPortraitMode(false)
    self:SetRunMode(false)
    self:RefreshMainHandInfo(true)
    self:SetDungeonSetupMode(true)
    self:RefreshRunCounters()
    self:RenderDungeonGrid()
end

function GA:SuspendDungeonRun()
    local run = self.RunState
    if not run or not run.active or not run.snapshot or not run.snapshot.characterKey then
        return false
    end

    SaveCurrentFloorState(run)
    self:SaveRunActionSlots()

    local ok
    local err
    if self.StoreSuspendedRun then
        ok, err = self:StoreSuspendedRun(run.snapshot.characterKey, run)
    else
        ok, err = false, "Suspended run storage is unavailable."
    end

    if not ok then
        if self.DungeonRunControlStatus then
            self.DungeonRunControlStatus:SetText(err or "Could not save this run.")
        end
        return false
    end

    run.active = false
    ReturnDirectlyToCharacterSelection(self)
    return true
end

function GA:ResumeDungeonRun(characterKey)
    if self.RunState and self.RunState.active then
        return false
    end

    local run = self.TakeSuspendedRun and self:TakeSuspendedRun(characterKey)
    if not run or not run.snapshot or not run.floorMap then
        return false
    end

    self.RunState = run
    run.active = true
    run.suspended = nil
    run.difficulty = self.NormalizeDifficulty and self:NormalizeDifficulty(
        run.difficulty or (run.snapshot and run.snapshot.difficulty)
    ) or "NORMAL"
    local resumedDifficulty = self.GetDifficultyDefinition
        and self:GetDifficultyDefinition(run.difficulty)
        or { label = run.difficulty, scoreMultiplier = 1 }
    run.difficultyLabel = run.difficultyLabel or resumedDifficulty.label or run.difficulty
    run.difficultyScoreMultiplier = tonumber(run.difficultyScoreMultiplier)
        or tonumber(resumedDifficulty.scoreMultiplier)
        or 1
    run.snapshot.difficulty = run.snapshot.difficulty or run.difficulty
    if self.ForeverRules then
        if run.ruleset ~= self.ForeverRules.ID and string.upper(tostring(run.resourceType or "")) == "RAGE"
            and (tonumber(run.resourceMax) or 0) <= 10 then
            run.resource = math.min(100, math.max(0, (tonumber(run.resource) or 0) * 20))
            run.resourceMax = 100
            run.baseResourceMax = 100
        end
        run.ruleset = self.ForeverRules.ID
    end
    run.rulesBaseHealth = run.rulesBaseHealth or run.baseMaxHealth or run.playerMaxHealth
    run.eventDamageBonus = math.max(0, tonumber(run.eventDamageBonus) or 0)
    run.eventHistory = run.eventHistory or {}
    if self.EventEngine then self.EventEngine:EnsureRunState(run) end
    EnsureRunTracking(run)
    EnsureDungeonEventStates(run)
    SetActiveFloorMap(run.floorMap)
    self.DungeonCameraX = nil
    self.DungeonCameraY = nil

    self:CloseRunControlMenu()
    self:SetDungeonSetupMode(false)
    self:SetRunMode(true)
    self:SetDungeonRunPortraitMode(true)

    if self.DungeonFloorTitle then
        self.DungeonFloorTitle:SetText(string.format(
            "FLOOR %d  -  %s  -  %d ROOMS  -  %d ENEMIES",
            run.floor or 1,
            run.floorMap.name or "DUNGEON",
            run.floorMap.roomCount or 0,
            run.enemyCount or #(run.enemies or {})
        ))
    end
    if self.DungeonRunStateText then
        self.DungeonRunStateText:SetText(string.format("FLOOR %d - RUN RESUMED", run.floor or 1))
        self.DungeonRunStateText:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
    end
    if self.DungeonBeginButton then
        self.DungeonBeginButton:SetEnabled(true)
        self.DungeonBeginButton.label:SetText("OPTIONS")
        self.DungeonBeginButton.label:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    end
    if self.DungeonRunPage and self.DungeonRunPage.SetPropagateKeyboardInput then
        self.DungeonRunPage:SetPropagateKeyboardInput(false)
    end

    self:UpdateRunHealth()
    self:UpdateRunResource()
    self:RecalculateRunGearStats()
    self:RefreshRunWeaponFromEquipment()
    self:RefreshRunCounters()
    self:RefreshActionButtons()
    self:ResetCombatLog()
    self:AddCombatLog(
        string.format(
            "Saved run resumed on Floor %d with %d/%d HP.",
            run.floor or 1,
            run.playerHealth or 0,
            run.playerMaxHealth or 0
        ),
        "system"
    )
    self:RenderDungeonGrid()
    return true
end

function GA:AbandonDungeonRun()
    local run = self.RunState
    if not run or not run.active then return false end

    local characterKey = run.snapshot and run.snapshot.characterKey
    if self.ClearSuspendedRun and characterKey then
        self:ClearSuspendedRun(characterKey)
    end

    run.active = false
    run.failed = true
    run.abandoned = true
    ReturnDirectlyToCharacterSelection(self)
    return true
end

function GA:KillSwitchDungeonRun()
    local run = self.RunState
    if not run or not run.active then return false end

    local characterKey = run.snapshot and run.snapshot.characterKey
    local hardcoreDeath = false
    if run.snapshot and run.snapshot.hardcore and run.snapshot.isArcadeGenerated
        and self.MarkArcadeCharacterDead then
        hardcoreDeath = self:MarkArcadeCharacterDead(
            characterKey,
            "Killswitch activated.",
            run.floor,
            run.score
        ) and true or false
    elseif self.ClearSuspendedRun and characterKey then
        self:ClearSuspendedRun(characterKey)
    end

    run.playerHealth = 0
    run.active = false
    run.failed = true
    run.killswitch = true
    run.hardcoreDeath = hardcoreDeath
    ReturnDirectlyToCharacterSelection(self)
    return true
end

function GA:ApplyQueuedDungeonEvents(floorMap, floorNumber)
    local run = self.RunState
    local engine = self.EventEngine or GA.EventEngine
    if not run or not floorMap or not engine or not self.DungeonGenerator
        or not self.DungeonGenerator.InjectEvent then
        return 0
    end

    engine:EnsureRunState(run)
    local floor = math.max(1, math.floor(tonumber(floorNumber) or 1))
    local index = 1

    while index <= #run.eventQueue do
        local entry = run.eventQueue[index]
        local event = entry and GetStudioDungeonEvent(entry.eventId)
        if not event then
            table.remove(run.eventQueue, index)
        else
            local maxFloor = math.max(1, math.floor(tonumber(event.maxFloor) or 9))
            if floor > maxFloor then
                table.remove(run.eventQueue, index)
            elseif floor >= math.max(1, math.floor(tonumber(entry.earliestFloor) or 1)) then
                local ok, key = self.DungeonGenerator:InjectEvent(
                    floorMap,
                    entry.eventId,
                    (#run.eventHistory or 0) + index
                )
                if ok then
                    table.remove(run.eventQueue, index)
                    self:AddCombatLog(
                        "EVENT CHAIN - " .. tostring(event.name or event.id)
                            .. " has surfaced on Floor " .. tostring(floor) .. ".",
                        "system"
                    )
                    return 1, key, event.id
                end
                index = index + 1
            else
                index = index + 1
            end
        end
    end

    return 0
end

local function ApplyStoredFloorState(run, floorNumber, stored, entryDirection)
    run.floor = floorNumber
    run.floorMap = CopyTable(stored.floorMap)
    run.roomRoleCounts = CopyTable(stored.roomRoleCounts or {})
    run.roomStates = CopyTable(stored.roomStates or {})
    run.eventStates = CopyTable(stored.eventStates or {})
    EnsureDungeonEventStates(run)
    run.chestLoot = CopyTable(stored.chestLoot or {})
    run.openedChests = CopyTable(stored.openedChests or {})
    run.openDoors = CopyTable(stored.openDoors or {})
    run.shopStock = stored.shopStock and CopyTable(stored.shopStock) or nil
    run.explored = CopyTable(stored.explored or {})
    run.visible = {}
    run.densityProfile = CopyTable(stored.densityProfile or {})
    run.walkableTiles = stored.walkableTiles
    run.baseEnemyCount = stored.baseEnemyCount
    run.enemyCount = stored.enemyCount
    run.enemyComposition = CopyTable(stored.enemyComposition or {})
    run.enemyRankComposition = CopyTable(stored.enemyRankComposition or {})
    run.enemies = CopyTable(stored.enemies or {})
    run.activeEnemyId = nil
    run.enemyPhase = stored.enemyPhase or 0

    SetActiveFloorMap(run.floorMap)

    if entryDirection == "up" then
        local exitX, exitY = GetDungeonExit()
        run.playerX = exitX
        run.playerY = exitY
    else
        local startX, startY = GetDungeonStart()
        run.playerX = startX
        run.playerY = startY
    end
end

function GA:ApplyDungeonFloor(floorNumber, entryDirection)
    self:CloseRunControlMenu()
    self:CloseShrineChoice()
    self:CloseDungeonEvent()
    self:CloseDungeonShop()
    self:CloseSpellbook()

    local run = self.RunState
    if not run or not run.active or not run.snapshot then
        return false
    end

    entryDirection = entryDirection or "down"
    run.floorStates = run.floorStates or {}

    local stored = run.floorStates[floorNumber]
    local floorMap
    local floorSetup
    local revisiting = stored ~= nil

    if stored then
        ApplyStoredFloorState(run, floorNumber, stored, entryDirection)
        self:ApplyQueuedDungeonEvents(run.floorMap, floorNumber)
        EnsureDungeonEventStates(run)
        floorMap = run.floorMap
    else
        if not run.ecosystemId and self.DungeonGenerator and self.DungeonGenerator.SelectEcosystem then
            local selectedEcosystem = self.DungeonGenerator:SelectEcosystem(run.dungeonSeed)
            run.ecosystemId = selectedEcosystem and selectedEcosystem.id or nil
            run.ecosystemName = selectedEcosystem and selectedEcosystem.name or run.ecosystemName
            run.ecosystemStyle = selectedEcosystem and selectedEcosystem.stylePreset or run.ecosystemStyle
        end

        floorMap = self.DungeonGenerator and self.DungeonGenerator:GenerateFloor(
            GRID_WIDTH,
            GRID_HEIGHT,
            floorNumber,
            run.dungeonSeed,
            run.ecosystemId
        )

        if not floorMap then
            self:AddCombatLog("Dungeon generation failed for the target floor.", "warning")
            return false
        end

        self:ApplyQueuedDungeonEvents(floorMap, floorNumber)
        SetActiveFloorMap(floorMap)
        local startX, startY = GetDungeonStart()

        floorSetup = GenerateFloorSetup(
            self.FloorGenerator,
            self.EnemyGenerator,
            run.runLevel or run.snapshot.level or 1,
            floorNumber,
            run.gearPressure or {},
            floorMap,
            run.difficulty or (run.snapshot and run.snapshot.difficulty) or "NORMAL"
        )

        run.floor = floorNumber
        run.ecosystemId = floorMap.ecosystemId or run.ecosystemId
        run.ecosystemName = floorMap.ecosystemName or run.ecosystemName
        run.ecosystemStyle = floorMap.stylePreset or run.ecosystemStyle
        run.floorMap = floorMap
        run.roomRoleCounts = CopyTable(floorMap.roomRoleCounts or {})
        run.roomStates = BuildInitialRoomStates(floorMap)
        run.eventStates = BuildInitialEventStates(floorMap)
        run.chestLoot = BuildFloorChestLoot(floorMap, floorNumber)
        run.playerX = startX
        run.playerY = startY
        run.openedChests = {}
        run.openDoors = {}
        run.shopStock = nil
        run.explored = {}
        run.visible = {}
        run.densityProfile = CopyTable(floorSetup.densityProfile)
        run.walkableTiles = floorSetup.walkableTiles
        run.baseEnemyCount = floorSetup.baseEnemyCount
        run.enemyCount = floorSetup.enemyCount
        run.enemyComposition = CopyTable(floorSetup.enemyComposition)
        run.enemyRankComposition = CopyTable(floorSetup.enemyRankComposition)
        run.enemies = floorSetup.enemies
        run.activeEnemyId = nil
        run.enemyPhase = 0

        -- Save the freshly created floor immediately so future backtracking
        -- always restores this exact layout and encounter state.
        run.floorStates[floorNumber] = CaptureCurrentFloorState(run)
    end

    self.DungeonCameraX = nil
    self.DungeonCameraY = nil

    if self.CharacterSheetFrame then
        self.CharacterSheetFrame:Hide()
    end
    self:CancelCharacterItemDrag()

    local enemyCount = run.enemyCount or #(run.enemies or {})

    if self.DungeonFloorTitle then
        self.DungeonFloorTitle:SetText(string.format(
            "FLOOR %d  -  %s  -  %d ROOMS  -  %d ENEMIES",
            floorNumber,
            floorMap.name or "DUNGEON",
            floorMap.roomCount or 0,
            enemyCount
        ))
    end

    if self.DungeonRunStateText then
        self.DungeonRunStateText:SetText(
            string.format("FLOOR %d", floorNumber)
        )
        self.DungeonRunStateText:SetTextColor(
            COLORS.green[1],
            COLORS.green[2],
            COLORS.green[3]
        )
    end

    if revisiting then
        self:AddCombatLog(
            string.format(
                "Returned to Floor %d. Previous exploration and encounters restored.",
                floorNumber
            ),
            "system"
        )
    else
        self:AddCombatLog(
            string.format(
                "Floor %d begins: %s, %d enemies.",
                floorNumber,
                run.densityProfile and run.densityProfile.key or "STANDARD",
                enemyCount
            ),
            "system"
        )
        self:AddCombatLog(
            string.format(
                "Layout: %s, %d rooms, %d doors, seed %d.",
                floorMap.name or "Dungeon",
                floorMap.roomCount or 0,
                floorMap.doorCount or 0,
                floorMap.seed or 0
            ),
            "system"
        )
        self:AddCombatLog(
            "Rooms: " .. BuildRoomRoleText(floorMap.roomRoleCounts) .. ".",
            "system"
        )
        self:AddCombatLog(
            "Composition: " .. BuildCompositionText(run.enemyComposition) .. ".",
            "system"
        )
        self:AddCombatLog(
            "Ranks: " .. BuildRankCompositionText(run.enemyRankComposition) .. ".",
            "system"
        )

        local sampleEnemy = run.enemies and run.enemies[1]
        if sampleEnemy then
            self:AddCombatLog(
                string.format(
                    "Floor %d scaling: %s Lv %d profile = %d HP, %d-%d damage.",
                    floorNumber,
                    GetEnemyDisplayName(sampleEnemy),
                    sampleEnemy.level or 1,
                    sampleEnemy.maxHp or 0,
                    sampleEnemy.damageMin or 0,
                    sampleEnemy.damageMax or 0
                ),
                "system"
            )
        end
    end

    self:RefreshRunCounters()
    self:RenderDungeonGrid()
    return true
end

function GA:CompleteDungeonRun()
    local run = self.RunState
    if not run or not run.active then
        return
    end

    AwardFloorClear(run, run.floor or 9)
    AddRunScore(run, "completion", RUN_SCORE.COMPLETION)
    local recoveredSupplies = 0
    if self.RecoverRunSuppliesToCentralStash then
        recoveredSupplies = self:RecoverRunSuppliesToCentralStash(run)
    end
    local extractedCount, extractedTypes = 0, 0
    if self.ExtractRunLootToCentralStash then
        extractedCount, extractedTypes = self:ExtractRunLootToCentralStash(run)
    end
    run.active = false
    run.completed = true
    self:ClearDungeonGridVisuals()
    self:CloseRunControlMenu()
    self:CloseShrineChoice()
    self:CloseDungeonEvent()
    self:CloseDungeonShop()
    self:CloseSpellbook()

    if self.DungeonFloorTitle then
        self.DungeonFloorTitle:SetText("RUN COMPLETE  -  FLOOR 9 CLEARED")
    end

    if self.DungeonRunStateText then
        self.DungeonRunStateText:SetText(
            string.format(
                "DUNGEON CLEARED - %d TURNS - SCORE %d",
                run.turns or 0,
                run.score or 0
            )
        )
        self.DungeonRunStateText:SetTextColor(
            COLORS.green[1],
            COLORS.green[2],
            COLORS.green[3]
        )
    end

    if self.DungeonBeginButton then
        self.DungeonBeginButton:SetEnabled(true)
        self.DungeonBeginButton.label:SetText("BEGIN AGAIN")
        self.DungeonBeginButton.label:SetTextColor(
            COLORS.gold[1],
            COLORS.gold[2],
            COLORS.gold[3]
        )
    end

    self:AddCombatLog(
        string.format(
            "Dungeon Run complete. Floor 9 cleared in %d turns with %d score.",
            run.turns or 0,
            run.score or 0
        ),
        "system"
    )
    self:AddCombatLog(
        string.format(
            "EXTRACTION COMPLETE: %d item%s across %d item type%s moved to the Central Stash.",
            extractedCount,
            extractedCount == 1 and "" or "s",
            extractedTypes,
            extractedTypes == 1 and "" or "s"
        ),
        "system"
    )

    if recoveredSupplies > 0 then
        self:AddCombatLog(
            string.format(
                "%d unused pre-run supply item%s returned to the Central Stash.",
                recoveredSupplies,
                recoveredSupplies == 1 and "" or "s"
            ),
            "system"
        )
    end

    if self.CharacterSheetFrame then
        self.CharacterSheetFrame:Hide()
    end
    self:CancelCharacterItemDrag()

    if self.DungeonRunPage and self.DungeonRunPage.SetPropagateKeyboardInput then
        self.DungeonRunPage:SetPropagateKeyboardInput(true)
    end

    self:RefreshRunCounters()
    self:RenderDungeonGrid()
    self:ShowDungeonRunSummary(
        true,
        string.format(
            "Extraction successful. %d found item%s secured; %d unused supply item%s returned.",
            run.extractedLootCount or 0,
            (run.extractedLootCount or 0) == 1 and "" or "s",
            recoveredSupplies,
            recoveredSupplies == 1 and "" or "s"
        ),
        false
    )
end

function GA:AdvanceDungeonFloor()
    local run = self.RunState
    if not run or not run.active then
        return
    end

    local clearedFloor = run.floor or 1
    AwardFloorClear(run, clearedFloor)

    if clearedFloor >= 9 then
        self:CompleteDungeonRun()
        return
    end

    local nextFloor = clearedFloor + 1
    SaveCurrentFloorState(run)

    self:AddCombatLog(
        string.format(
            "Floor %d cleared. Descending to Floor %d with %d/%d HP.",
            clearedFloor,
            nextFloor,
            run.playerHealth or 0,
            run.playerMaxHealth or 0
        ),
        "system"
    )

    self:ApplyDungeonFloor(nextFloor, "down")
end

function GA:ReturnDungeonFloor()
    local run = self.RunState
    if not run or not run.active then
        return
    end

    local currentFloor = run.floor or 1
    if currentFloor <= 1 then
        return
    end

    local previousFloor = currentFloor - 1
    SaveCurrentFloorState(run)

    self:AddCombatLog(
        string.format(
            "Returning from Floor %d to Floor %d with %d/%d HP.",
            currentFloor,
            previousFloor,
            run.playerHealth or 0,
            run.playerMaxHealth or 0
        ),
        "system"
    )

    self:ApplyDungeonFloor(previousFloor, "up")
end


local function GetMonsterSkillById(skillId)
    for _, skill in ipairs(GA.StudioData and GA.StudioData.monsterSkills or {}) do
        if skill.id == skillId then
            return skill
        end
    end
    return nil
end

local function GetMonsterSkillDistance(enemy, run)
    if not enemy or not run then return 999 end
    return math.abs((enemy.x or 0) - (run.playerX or 0))
        + math.abs((enemy.y or 0) - (run.playerY or 0))
end

local function TickMonsterSkillCooldowns(enemy)
    enemy.skillCooldowns = enemy.skillCooldowns or {}
    for skillId, turns in pairs(enemy.skillCooldowns) do
        turns = math.max(0, (tonumber(turns) or 0) - 1)
        if turns <= 0 then
            enemy.skillCooldowns[skillId] = nil
        else
            enemy.skillCooldowns[skillId] = turns
        end
    end
end

local function MonsterSkillConditionMet(skill, enemy, run, distance, enemyPhase)
    local condition = string.upper(tostring(skill.condition or "ALWAYS"))
    local value = tonumber(skill.conditionValue) or 0

    if condition == "ADJACENT" then
        return distance <= 1
    elseif condition == "RANGE_MIN" then
        return distance >= math.max(1, math.floor(value))
    elseif condition == "SELF_HP_BELOW" then
        local maxHp = math.max(1, tonumber(enemy.maxHp) or 1)
        return ((tonumber(enemy.hp) or maxHp) / maxHp) * 100 <= value
    elseif condition == "TARGET_HP_BELOW" then
        local maxHp = math.max(1, tonumber(run.playerMaxHealth) or 1)
        return ((tonumber(run.playerHealth) or maxHp) / maxHp) * 100 <= value
    elseif condition == "EVERY_N_TURNS" then
        local interval = math.max(1, math.floor(value))
        return (enemyPhase or 1) % interval == 0
    elseif condition == "ONCE_PER_COMBAT" then
        enemy.skillUseCounts = enemy.skillUseCounts or {}
        return (enemy.skillUseCounts[skill.id] or 0) <= 0
    end

    return true
end

local function ChooseMonsterSkill(enemy, run, enemyPhase)
    if not enemy or not run or not enemy.skillIds or #enemy.skillIds == 0 then
        return nil
    end

    local distance = GetMonsterSkillDistance(enemy, run)
    local candidates = {}
    local totalWeight = 0

    for _, skillId in ipairs(enemy.skillIds) do
        local skill = GetMonsterSkillById(skillId)
        if skill and (run.floor or 1) >= math.max(1, math.floor(tonumber(skill.minFloor) or 1)) then
            local target = string.upper(tostring(skill.target or "PLAYER"))
            local range = math.max(0, math.floor(tonumber(skill.range) or 1))
            local inRange = target == "SELF" or distance <= range
            local cooldownReady = not (enemy.skillCooldowns and enemy.skillCooldowns[skill.id])
            if inRange
                and cooldownReady
                and MonsterSkillConditionMet(skill, enemy, run, distance, enemyPhase) then
                local weight = math.max(0, tonumber(skill.priority) or 0)
                if weight > 0 then
                    candidates[#candidates + 1] = { skill = skill, weight = weight }
                    totalWeight = totalWeight + weight
                end
            end
        end
    end

    if totalWeight <= 0 or #candidates == 0 then
        return nil
    end

    local roll = math.random() * totalWeight
    local cursor = 0
    for _, candidate in ipairs(candidates) do
        cursor = cursor + candidate.weight
        if roll <= cursor then
            return candidate.skill
        end
    end
    return candidates[#candidates].skill
end

local function GetEnemyDamageMultiplier(run, enemy)
    local multiplier = 1
    local weakened = enemy.statuses and enemy.statuses.weakened
    if weakened and (weakened.turns or 0) > 0 then
        multiplier = multiplier * (1 - math.max(0, math.min(90, tonumber(weakened.percent) or 0)) / 100)
    end
    local disarmed = enemy.statuses and enemy.statuses.disarmed
    if disarmed and (disarmed.turns or 0) > 0 then
        multiplier = multiplier * (1 - math.max(0, math.min(90, tonumber(disarmed.percent) or 0)) / 100)
    end
    local monsterDamageBuff = enemy.statuses and enemy.statuses.monsterDamageBuff
    if monsterDamageBuff and (monsterDamageBuff.turns or 0) > 0 then
        multiplier = multiplier * (1 + math.max(0, tonumber(monsterDamageBuff.percent) or 0) / 100)
    end
    if run.stance == "defensive" then
        local defensive = GetStudioAbilityById("defensive_stance") or {}
        multiplier = multiplier * (1 - math.max(0, math.min(90, tonumber(defensive.effectValue) or 0)) / 100)
    elseif run.stance == "berserker" then
        local berserker = GetStudioAbilityById("berserker_stance") or {}
        multiplier = multiplier * (1 + math.max(0, tonumber(berserker.secondaryValue) or 0) / 100)
    end
    local shieldWall = run.buffs and run.buffs.shield_wall
    if shieldWall and (shieldWall.turns or 0) > 0 then
        multiplier = multiplier * (1 - math.max(0, math.min(90, tonumber(shieldWall.reduction) or 0)) / 100)
    end
    local recklessness = run.buffs and run.buffs.recklessness
    if recklessness and (recklessness.turns or 0) > 0 then
        multiplier = multiplier * (1 + math.max(0, tonumber(recklessness.damageTaken) or 0) / 100)
    end
    return multiplier
end

local function ResolveEnemyPhysicalAttack(self, run, enemy, rawDamage, attackName)
    local baseStats = run.arcadeStats or {}
    local stats = {}
    for key, value in pairs(baseStats) do stats[key] = value end
    stats.level = math.max(1, tonumber(run.runLevel) or 1)
    stats.parry = (tonumber(stats.parry) or 0) + math.max(0, tonumber(run.weaponGuardChance) or 0)

    local shieldBlock = run.buffs and run.buffs.shield_block
    if shieldBlock and (shieldBlock.turns or 0) > 0 then
        stats.block = math.min(100, (tonumber(stats.block) or 0) + math.max(0, tonumber(shieldBlock.percent) or 0))
    end

    local lastStand = run.arcadeTraits and (run.arcadeTraits.LAST_STAND or 0) or 0
    if lastStand > 0 and (run.playerMaxHealth or 0) > 0
        and (run.playerHealth or 0) / run.playerMaxHealth <= 0.35 then
        stats.armor = (tonumber(stats.armor) or 0) * (1 + lastStand / 100)
    end

    local outcome = self.ForeverRules and self.ForeverRules.ResolveEnemyMeleeAttack
        and self.ForeverRules:ResolveEnemyMeleeAttack(enemy, stats)
        or { kind = "HIT", multiplier = 1 }

    local kind = tostring(outcome.kind or "HIT")
    run.reactive = run.reactive or {}
    if kind == "DODGE" then
        run.reactive.overpower = { turns = 2 }
        run.reactive.revenge = { turns = 2 }
        self:AddCombatLog("DODGE! You avoid " .. tostring(attackName) .. ". Overpower and Revenge are ready.", "player")
        return true, outcome, 0
    elseif kind == "PARRY" then
        run.reactive.revenge = { turns = 2 }
        self:AddCombatLog("PARRY! You deflect " .. tostring(attackName) .. ". Revenge is ready.", "player")
        return true, outcome, 0
    elseif kind == "MISS" then
        self:AddCombatLog("MISS! " .. tostring(attackName) .. " misses you.", "enemy")
        return true, outcome, 0
    end

    rawDamage = math.max(1, math.floor((tonumber(rawDamage) or 1) * GetEnemyDamageMultiplier(run, enemy) + 0.5))
    local damage
    if self.ForeverRules and self.ForeverRules.ApplyPhysicalMitigation then
        damage = self.ForeverRules:ApplyPhysicalMitigation(
            rawDamage, stats.armor or 0, enemy.level or run.runLevel or 1, outcome)
    else
        damage = math.max(1, math.floor(rawDamage * (tonumber(outcome.multiplier) or 1) + 0.5))
    end

    if kind == "BLOCK" then run.reactive.revenge = { turns = 2 } end
    local prefix = kind == "BLOCK" and "BLOCK! "
        or kind == "CRIT" and "CRITICAL! "
        or kind == "CRUSHING" and "CRUSHING! "
        or ""

    run.playerHealth = math.max(0, (run.playerHealth or run.playerMaxHealth or 1) - damage)
    self:AddCombatLog(
        string.format("%s%s hits you for %d damage. (%d/%d HP)",
            prefix, tostring(attackName), damage,
            run.playerHealth, run.playerMaxHealth or run.playerHealth),
        "enemy"
    )
    self:UpdateRunHealth()

    local berserkerRage = run.buffs and run.buffs.berserker_rage
    if damage > 0 and run.playerHealth > 0 and berserkerRage and (berserkerRage.turns or 0) > 0 then
        GainRunResource(run, berserkerRage.resourcePerHit or 0)
        self:UpdateRunResource()
    end

    if run.playerHealth <= 0 then
        self:FailDungeonRun(tostring(attackName) .. " killed " .. (run.snapshot.name or "your hero") .. ".")
        return false, outcome, damage
    end
    return true, outcome, damage
end

function GA:ApplyMonsterSkillDamage(enemy, rawDamage, skillName)
    local run = self.RunState
    if not run or not run.active or not enemy then return false end
    local alive = ResolveEnemyPhysicalAttack(self, run, enemy, rawDamage, skillName or GetEnemyDisplayName(enemy))
    return alive
end
function GA:ResolveMonsterSkill(enemy, skill)
    local run = self.RunState
    if not run or not run.active or not enemy or not skill then
        return false
    end

    local effect = string.upper(tostring(skill.effect or "DAMAGE"))
    local skillName = skill.name or skill.id or "Monster Skill"
    local duration = math.max(0, math.floor(tonumber(skill.durationTurns) or 0))
    local effectValue = tonumber(skill.effectValue) or 0

    enemy.skillCooldowns = enemy.skillCooldowns or {}
    enemy.skillUseCounts = enemy.skillUseCounts or {}
    enemy.skillUseCounts[skill.id] = (enemy.skillUseCounts[skill.id] or 0) + 1
    local cooldown = math.max(0, math.floor(tonumber(skill.cooldownTurns) or 0))
    if cooldown > 0 then
        enemy.skillCooldowns[skill.id] = cooldown
    end

    if effect == "HEAL" then
        local amount = math.max(1, math.floor((enemy.maxHp or 1) * math.max(0, effectValue) / 100 + 0.5))
        local before = enemy.hp or enemy.maxHp or 1
        enemy.hp = math.min(enemy.maxHp or before, before + amount)
        self:AddCombatLog(
            string.format("%s uses %s and heals %d HP.", GetEnemyDisplayName(enemy), skillName, enemy.hp - before),
            "enemy"
        )
        return true
    elseif effect == "ROOT" then
        run.monsterStatuses = run.monsterStatuses or {}
        run.monsterStatuses.root = {
            turns = math.max(1, duration),
            name = skillName,
            source = enemy.uid,
        }
        self:AddCombatLog(
            string.format("%s uses %s. You are rooted for %d turn(s).",
                GetEnemyDisplayName(enemy), skillName, math.max(1, duration)),
            "enemy"
        )
        return true
    elseif effect == "SLOW" then
        run.monsterStatuses = run.monsterStatuses or {}
        run.monsterStatuses.slow = {
            turns = math.max(1, duration),
            percent = math.max(0, math.min(90, effectValue)),
            name = skillName,
            source = enemy.uid,
        }
        self:AddCombatLog(
            string.format("%s uses %s. Movement slowed by %d%%.",
                GetEnemyDisplayName(enemy), skillName, math.floor(math.max(0, effectValue))),
            "enemy"
        )
        return true
    elseif effect == "BUFF_DAMAGE" then
        enemy.statuses = enemy.statuses or {}
        enemy.statuses.monsterDamageBuff = {
            turns = math.max(1, duration) + 1,
            percent = math.max(0, effectValue),
        }
        self:AddCombatLog(
            string.format("%s uses %s and gains +%d%% damage.",
                GetEnemyDisplayName(enemy), skillName, math.floor(math.max(0, effectValue))),
            "enemy"
        )
        return true
    end

    local baseDamage = math.random(
        enemy.damageMin or 1,
        enemy.damageMax or enemy.damageMin or 1
    )
    local rawDamage = math.max(
        1,
        math.floor(baseDamage * math.max(0, tonumber(skill.damageMultiplier) or 1) + 0.5)
    )
    local survived = self:ApplyMonsterSkillDamage(enemy, rawDamage, skillName)
    if not survived or not run.active then
        return true
    end

    if effect == "DAMAGE_DOT" then
        run.monsterStatuses = run.monsterStatuses or {}
        run.monsterStatuses.poison = {
            turns = math.max(1, duration),
            damage = math.max(1, math.floor(math.max(0, effectValue) + 0.5)),
            name = skillName,
            source = enemy.uid,
        }
        self:AddCombatLog(
            string.format("%s leaves a %d-turn damage effect.", skillName, math.max(1, duration)),
            "enemy"
        )
    end

    return true
end

function GA:TryUseMonsterSkill(enemy, enemyPhase)
    local run = self.RunState
    if not run or not run.active or not enemy or enemy.alive == false then
        return false
    end

    TickMonsterSkillCooldowns(enemy)

    if enemy.pendingSkill and enemy.pendingSkill.skillId then
        local pending = enemy.pendingSkill
        local skill = GetMonsterSkillById(pending.skillId)
        if not skill then
            enemy.pendingSkill = nil
            return false
        end

        pending.turns = math.max(0, (tonumber(pending.turns) or 1) - 1)
        if pending.turns > 0 then
            return true
        end

        enemy.pendingSkill = nil
        local target = string.upper(tostring(skill.target or "PLAYER"))
        local range = math.max(0, math.floor(tonumber(skill.range) or 1))
        local distance = GetMonsterSkillDistance(enemy, run)
        local validTarget = target == "SELF"
            or (distance <= range and HasLineOfSight(enemy.x, enemy.y, run.playerX, run.playerY))

        if not validTarget then
            self:AddCombatLog(
                string.format("%s's %s misses its opening.", GetEnemyDisplayName(enemy), skill.name or skill.id),
                "enemy"
            )
            return true
        end

        return self:ResolveMonsterSkill(enemy, skill)
    end

    local skill = ChooseMonsterSkill(enemy, run, enemyPhase)
    if not skill then
        return false
    end

    local telegraphTurns = math.max(0, math.floor(tonumber(skill.telegraphTurns) or 0))
    if telegraphTurns > 0 then
        enemy.pendingSkill = {
            skillId = skill.id,
            turns = telegraphTurns,
        }
        self:AddCombatLog(
            string.format("%s prepares %s.", GetEnemyDisplayName(enemy), skill.name or skill.id),
            "enemy"
        )
        return true
    end

    return self:ResolveMonsterSkill(enemy, skill)
end

function GA:AdvanceMonsterPlayerStatuses()
    local run = self.RunState
    if not run or not run.active then
        return false
    end

    local statuses = run.monsterStatuses
    if not statuses then
        return true
    end

    local poison = statuses.poison
    if poison and (poison.turns or 0) > 0 then
        local damage = math.max(1, math.floor(tonumber(poison.damage) or 1))
        run.playerHealth = math.max(0, (run.playerHealth or run.playerMaxHealth or 1) - damage)
        self:AddCombatLog(
            string.format("%s deals %d lingering damage. (%d/%d HP)",
                poison.name or "Venom",
                damage,
                run.playerHealth,
                run.playerMaxHealth or run.playerHealth),
            "enemy"
        )
        self:UpdateRunHealth()
        poison.turns = poison.turns - 1
        if poison.turns <= 0 then
            statuses.poison = nil
        end
        if run.playerHealth <= 0 then
            self:FailDungeonRun(
                (poison.name or "A lingering monster effect")
                .. " killed "
                .. (run.snapshot.name or "your hero")
                .. "."
            )
            return false
        end
    end

    for _, statusId in ipairs({ "root", "slow" }) do
        local status = statuses[statusId]
        if status then
            status.turns = (status.turns or 1) - 1
            if status.turns <= 0 then
                statuses[statusId] = nil
            end
        end
    end

    return true
end

function GA:RunEnemyTurn()
    local run = self.RunState
    if not run or not run.active or not run.enemies then
        self:RefreshActionButtons()
        return
    end
    if not self:AdvanceMonsterPlayerStatuses() then return end

    run.enemyPhase = (run.enemyPhase or 0) + 1
    local enemyPhase = run.enemyPhase

    for _, enemy in ipairs(run.enemies) do
        if enemy.alive ~= false and run.active then
            local feared = enemy.statuses and enemy.statuses.feared
            if feared and (feared.turns or 0) > 0 then
                enemy.intent = "FEARED"
                if self:IsDungeonCellVisible(enemy.x, enemy.y) then
                    self:AddCombatLog("The feared " .. string.lower(GetEnemyDisplayName(enemy)) .. " loses its action.", "enemy")
                end
            elseif enemy.skipTurn then
                enemy.intent = "STAGGERED"
                enemy.skipTurn = false
                if self:IsDungeonCellVisible(enemy.x, enemy.y) then
                    self:AddCombatLog("The staggered " .. string.lower(GetEnemyDisplayName(enemy)) .. " loses its turn.", "enemy")
                end
            else
                local seesPlayer = IsWithinRadius(enemy.x, enemy.y, run.playerX, run.playerY, enemy.visionRadius or 6)
                    and HasLineOfSight(enemy.x, enemy.y, run.playerX, run.playerY)

                if seesPlayer and not enemy.alerted then
                    enemy.alerted = true
                    enemy.intent = "ALERTED"
                    if self:IsDungeonCellVisible(enemy.x, enemy.y) then
                        self:AddCombatLog("The " .. string.lower(GetEnemyDisplayName(enemy)) .. " spots you!", "enemy")
                    end
                end

                local usedMonsterSkill = false
                if enemy.alerted and seesPlayer then usedMonsterSkill = self:TryUseMonsterSkill(enemy, enemyPhase) end

                if usedMonsterSkill then
                    enemy.intent = "SKILL"
                elseif IsAdjacent(enemy.x, enemy.y, run.playerX, run.playerY) then
                    enemy.intent = "ATTACKING"
                    run.activeEnemyId = run.activeEnemyId or enemy.uid
                    local rawDamage = math.random(enemy.damageMin or 1, enemy.damageMax or enemy.damageMin or 1)
                    local survived = ResolveEnemyPhysicalAttack(self, run, enemy, rawDamage, GetEnemyDisplayName(enemy))
                    if not survived then return end

                    if run.playerHealth > 0 and run.buffs and run.buffs.retaliation and enemy.alive ~= false then
                        local retaliationAbility = GetStudioAbilityById("retaliation")
                        if retaliationAbility then self:DealRunDamage(enemy, retaliationAbility, { allowWeaponTrait = false }) end
                    end
                elseif enemy.alerted then
                    enemy.intent = "ALERTED"
                    local movementSteps = GetEnemyMovementSteps(enemy, enemyPhase)
                    local hamstring = enemy.statuses and enemy.statuses.hamstring
                    if hamstring and (hamstring.turns or 0) > 0 then
                        local slow = math.max(0, math.min(100, tonumber(hamstring.percent) or 0))
                        movementSteps = math.max(0, math.floor(movementSteps * (1 - slow / 100)))
                    end

                    local movedSteps = 0
                    local visibleDuringMove = self:IsDungeonCellVisible(enemy.x, enemy.y)
                    for _ = 1, movementSteps do
                        if IsAdjacent(enemy.x, enemy.y, run.playerX, run.playerY) then break end
                        local occupied = BuildOccupiedEnemyCells(run, enemy.uid)
                        local nextX, nextY = FindNextStep(enemy.x, enemy.y, run.playerX, run.playerY, occupied)
                        if not nextX or not nextY
                            or (nextX == run.playerX and nextY == run.playerY)
                            or occupied[CellKey(nextX, nextY)] then break end
                        enemy.x, enemy.y = nextX, nextY
                        movedSteps = movedSteps + 1
                        if self:IsDungeonCellVisible(enemy.x, enemy.y) then visibleDuringMove = true end
                    end

                    if movedSteps > 0 then enemy.intent = "MOVING" end
                    if movedSteps > 0 and visibleDuringMove then
                        if enemy.movementPattern == "quick" and movedSteps > 1 then
                            self:AddCombatLog(GetEnemyDisplayName(enemy) .. " scuttles quickly closer.", "enemy")
                        else
                            self:AddCombatLog(GetEnemyDisplayName(enemy) .. " moves closer.", "enemy")
                        end
                    end
                else
                    enemy.intent = "IDLE"
                end
            end
        end
    end

    run.weaponGuardChance = nil
    self:AdvanceCombatEffects()
    self:RenderDungeonGrid()

    if self.DungeonRunStateText and run.active then
        if run.justLeveledUp then
            self.DungeonRunStateText:SetText(
                string.format("LEVEL UP!  %d -> %d", run.justLeveledUp.from or run.runLevel, run.justLeveledUp.to or run.runLevel)
            )
            self.DungeonRunStateText:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
            run.justLeveledUp = nil
        else
            self.DungeonRunStateText:SetText("")
        end
    end
end
function GA:TryLootChest(x, y)
    local run = self.RunState
    if not run or not run.active then
        return false
    end

    local key = CellKey(x, y)
    local loot = run.chestLoot and run.chestLoot[key]
    if not loot or (run.openedChests and run.openedChests[key]) then
        return false
    end

    if not loot.empty and not self:AddItemToBackpack(loot) then
        self:AddCombatLog("Your backpack is full. The chest remains unopened.", "warning")
        return false
    end

    run.openedChests = run.openedChests or {}
    run.openedChests[key] = true

    local marker = GetDungeonMarkers()[key]
    local chestScore = RUN_SCORE.CHEST
    if marker and marker.rewardType == "elite" then
        chestScore = RUN_SCORE.ELITE_CACHE
    elseif marker and marker.rewardType == "boss" then
        chestScore = RUN_SCORE.BOSS_CACHE
    end

    local stats = EnsureRunTracking(run)
    stats.chests = stats.chests + 1
    AddRunScore(run, "chest", chestScore)
    if not loot.empty then
        RecordRunLoot(run, loot)
    end
    if marker and marker.roomIndex
        and (marker.rewardType == "elite" or marker.rewardType == "boss") then
        run.roomStates = run.roomStates or {}
        local state = run.roomStates[marker.roomIndex]
        if state then
            if marker.rewardType == "elite" then
                state.eliteRewardClaimed = true
            else
                state.bossRewardClaimed = true
            end
            MarkRoomCleared(run, marker.roomIndex)
        end
    end

    if loot.empty then
        self:AddCombatLog((loot.name or "Container") .. " opened: empty.", "system")
    else
        self:AddCombatLog("Chest opened: " .. loot.name .. " added to your backpack.", "system")
        self:AddCombatLog("Press C to open your character sheet.", "system")
    end
    self:RefreshRunCounters()
    self:RenderDungeonGrid()
    return true
end

function GA:RefreshRunControlMenu()
    local pending = self.PendingRunControlAction
    if self.DungeonRunAbandonButton then
        self.DungeonRunAbandonButton.label:SetText(
            pending == "abandon" and "CONFIRM ABANDON" or "ABANDON RUN"
        )
        self.DungeonRunAbandonButton.label:SetTextColor(
            pending == "abandon" and COLORS.red[1] or COLORS.text[1],
            pending == "abandon" and COLORS.red[2] or COLORS.text[2],
            pending == "abandon" and COLORS.red[3] or COLORS.text[3]
        )
    end
    if self.DungeonRunKillButton then
        self.DungeonRunKillButton.label:SetText(
            pending == "kill" and "CONFIRM KILL" or "KILLSWITCH"
        )
        self.DungeonRunKillButton.label:SetTextColor(
            pending == "kill" and COLORS.red[1] or COLORS.text[1],
            pending == "kill" and COLORS.red[2] or COLORS.text[2],
            pending == "kill" and COLORS.red[3] or COLORS.text[3]
        )
    end
    if self.DungeonRunControlStatus then
        if pending == "abandon" then
            self.DungeonRunControlStatus:SetText("Click CONFIRM ABANDON to destroy this run and its unextracted loot.")
        elseif pending == "kill" then
            self.DungeonRunControlStatus:SetText("Click CONFIRM KILL to trigger character death now.")
        else
            self.DungeonRunControlStatus:SetText("")
        end
    end
end

function GA:OpenRunControlMenu()
    local run = self.RunState
    if not run or not run.active or not self.DungeonRunControlFrame then return false end

    if self.PendingDungeonEvent
        or (self.DungeonEventFrame and self.DungeonEventFrame:IsShown()) then
        return false
    end

    self:CloseRunControlMenu()
    self:CloseShrineChoice()
    self:CloseDungeonEvent()
    self:CloseDungeonShop()
    self:CloseSpellbook()
    if self.CharacterSheetFrame then self.CharacterSheetFrame:Hide() end
    self:CancelCharacterItemDrag()
    self.PendingRunControlAction = nil
    self:RefreshRunControlMenu()
    self.DungeonRunControlFrame:Show()
    return true
end

function GA:CloseRunControlMenu()
    self.PendingRunControlAction = nil
    if self.DungeonRunControlFrame then
        self.DungeonRunControlFrame:Hide()
    end
    self:RefreshRunControlMenu()
end

function GA:CloseDungeonShop()
    if self.DungeonShopFrame then
        self.DungeonShopFrame:Hide()
    end
    self.PendingShopRoomIndex = nil
end

function GA:RefreshDungeonShop()
    local run = self.RunState
    if not run or not self.DungeonShopFrame then return end

    if self.DungeonShopCopper then
        self.DungeonShopCopper:SetText(FormatCopperValue(run.copper or 0))
    end

    for index = 1, 4 do
        local button = self.DungeonShopBuyButtons and self.DungeonShopBuyButtons[index]
        local item = run.shopStock and run.shopStock[index]
        if button then
            button.gaShopItem = type(item) == "table" and item or nil
            button.gaShopPrice = type(item) == "table" and math.max(0, math.floor(tonumber(item.price) or 0)) or 0

            if type(item) == "table" then
                local shortName = tostring(item.name or "Item")
                if #shortName > 24 then shortName = string.sub(shortName, 1, 23) .. "…" end
                button.label:SetText(string.format("%d  %s  -  %s", index, shortName, FormatCopperValue(button.gaShopPrice)))
                local affordable = (run.copper or 0) >= button.gaShopPrice
                button:SetEnabled(affordable)
                button.label:SetTextColor(
                    affordable and COLORS.text[1] or COLORS.muted[1],
                    affordable and COLORS.text[2] or COLORS.muted[2],
                    affordable and COLORS.text[3] or COLORS.muted[3]
                )
            else
                button.label:SetText(string.format("%d  SOLD", index))
                button:SetEnabled(false)
                button.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
            end
        end
    end

    self.DungeonShopSellPage = math.max(1, math.min(4, tonumber(self.DungeonShopSellPage) or 1))
    local firstSlot = ((self.DungeonShopSellPage - 1) * 6) + 1

    for index = 1, 6 do
        local slotIndex = firstSlot + index - 1
        local button = self.DungeonShopSellButtons and self.DungeonShopSellButtons[index]
        local item = run.backpack and run.backpack[slotIndex]
        if button then
            button.gaBackpackSlot = item and slotIndex or nil
            if item then
                local count = math.max(1, math.floor(tonumber(item.stackCount) or 1))
                local unitValue = math.max(0, math.floor((tonumber(item.price) or 0) * 0.5))
                local sellValue = unitValue * count
                local shortName = tostring(item.name or "Item")
                if #shortName > 21 then shortName = string.sub(shortName, 1, 20) .. "…" end
                button.label:SetText(string.format("%d. %s  +%s", slotIndex, shortName, FormatCopperValue(sellValue)))
                button:SetEnabled(sellValue > 0)
            else
                button.label:SetText(string.format("%d. EMPTY", slotIndex))
                button:SetEnabled(false)
            end
        end
    end

    if self.DungeonShopPageText then
        self.DungeonShopPageText:SetText(string.format("%d / 4", self.DungeonShopSellPage))
    end
    if self.DungeonShopPrev then self.DungeonShopPrev:SetEnabled(self.DungeonShopSellPage > 1) end
    if self.DungeonShopNext then self.DungeonShopNext:SetEnabled(self.DungeonShopSellPage < 4) end

    self:RefreshRunCounters()
end

function GA:OpenDungeonShop(roomIndex)
    self:CloseDungeonEvent()
    self:CloseShrineChoice()
    local run = self.RunState
    if not run or not run.active or not roomIndex or (run.floor or 1) ~= 6 then return false end

    if not run.shopStock then
        run.shopStock = self.BuildDungeonShopStock
            and self:BuildDungeonShopStock(run.floor, run.classId, run.runLevel, 4)
            or {}
    end

    self.PendingShopRoomIndex = roomIndex
    self.DungeonShopSellPage = 1
    if self.CharacterSheetFrame then self.CharacterSheetFrame:Hide() end
    self:CancelCharacterItemDrag()
    self:CloseSpellbook()
    self:CloseShrineChoice()
    self:RefreshDungeonShop()
    if self.DungeonShopFrame then self.DungeonShopFrame:Show() end
    self:AddCombatLog("A goblin quartermaster opens a battered ledger.", "system")
    return true
end

function GA:ChangeDungeonShopSellPage(delta)
    self.DungeonShopSellPage = math.max(1, math.min(4, (tonumber(self.DungeonShopSellPage) or 1) + (tonumber(delta) or 0)))
    self:RefreshDungeonShop()
end

function GA:BuyDungeonShopItem(index)
    local run = self.RunState
    index = tonumber(index)
    local item = run and run.shopStock and index and run.shopStock[index]
    if not run or not run.active or type(item) ~= "table" then return false end

    local price = math.max(0, math.floor(tonumber(item.price) or 0))
    if (run.copper or 0) < price then
        self:AddCombatLog("You cannot afford " .. (item.name or "that item") .. ".", "warning")
        return false
    end

    if not self:AddItemToBackpack(CopyTable(item)) then
        self:AddCombatLog("Your backpack is full. Nothing was purchased.", "warning")
        return false
    end

    run.copper = math.max(0, (run.copper or 0) - price)
    run.shopStock[index] = false
    local stats = EnsureRunTracking(run)
    stats.copperSpent = stats.copperSpent + price
    stats.itemsBought = stats.itemsBought + 1

    self:AddCombatLog(string.format("Bought %s for %s.", item.name or "item", FormatCopperValue(price)), "system")
    self:RefreshDungeonShop()
    return true
end

function GA:SellDungeonShopItem(slotIndex)
    local run = self.RunState
    slotIndex = tonumber(slotIndex)
    local item = run and run.backpack and slotIndex and run.backpack[slotIndex]
    if not run or not run.active or not item then return false end

    local count = math.max(1, math.floor(tonumber(item.stackCount) or 1))
    local unitValue = math.max(0, math.floor((tonumber(item.price) or 0) * 0.5))
    local sellValue = unitValue * count
    if sellValue <= 0 then
        self:AddCombatLog((item.name or "That item") .. " has no resale value.", "warning")
        return false
    end

    run.backpack[slotIndex] = nil
    run.copper = (run.copper or 0) + sellValue
    local stats = EnsureRunTracking(run)
    stats.copperEarned = stats.copperEarned + sellValue
    stats.itemsSold = stats.itemsSold + count

    self:AddCombatLog(string.format("Sold %s x%d for %s.", item.name or "item", count, FormatCopperValue(sellValue)), "system")
    self:RefreshDungeonShop()
    if self.CharacterSheetFrame and self.CharacterSheetFrame:IsShown() then
        self:RefreshCharacterSheet()
    end
    return true
end

function GA:CloseDungeonEvent()
    if self.DungeonEventFrame then
        self.DungeonEventFrame:Hide()
    end
    self.PendingDungeonEvent = nil
end

function GA:OpenDungeonEvent(marker, eventKey)
    local run = self.RunState
    local event = marker and GetStudioDungeonEvent(marker.eventId)
    if not run or not run.active or not marker or marker.kind ~= "event" or not event then
        return false
    end

    local options = GetStudioDungeonEventOptions(event.id)
    if #options == 0 then
        self:AddCombatLog("Event data error: " .. tostring(event.id) .. " has no options.", "warning")
        return false
    end

    local eventStates = EnsureDungeonEventStates(run)
    local eventState = eventStates[eventKey]
    if eventState and eventState.resolved then
        if run.floorMap and run.floorMap.markers then
            run.floorMap.markers[eventKey] = nil
        end
        return false
    end
    if not eventState then
        eventState = {
            eventId = event.id,
            roomIndex = marker.roomIndex,
            resolved = false,
        }
        eventStates[eventKey] = eventState
    end

    self:CloseShrineChoice()
    self:CloseDungeonEvent()
    self:CloseDungeonShop()
    self.PendingDungeonEvent = {
        key = eventKey,
        eventId = event.id,
        roomIndex = marker.roomIndex,
    }

    if self.DungeonEventTitle then
        self.DungeonEventTitle:SetText(string.upper(event.name or event.id or "DUNGEON EVENT"))
    end
    if self.DungeonEventText then
        self.DungeonEventText:SetText(event.description or "")
    end
    if self.DungeonEventIcon then
        self.DungeonEventIcon:SetTexture(GetDungeonEventIcon(event))
    end

    local visibleOptions = {}
    local engine = self.EventEngine or GA.EventEngine
    for _, option in ipairs(options) do
        local pendingRewardOptionId = eventState.pendingRewardOptionId
        local committedReward = pendingRewardOptionId and pendingRewardOptionId == option.id
        local available, reasons
        if engine then
            available, reasons = engine:EvaluateOption(run, option, committedReward)
        else
            available, reasons = true, {}
        end
        local mode = string.upper(tostring(option.unavailableMode or "DISABLE"))
        if available or mode ~= "HIDE" or committedReward then
            visibleOptions[#visibleOptions + 1] = {
                option = option,
                available = available or committedReward,
                reasons = reasons or {},
            }
        end
    end

    self.PendingDungeonEvent.optionIds = {}
    for index = 1, 4 do
        local button = self.DungeonEventOptionButtons and self.DungeonEventOptionButtons[index]
        local entry = visibleOptions[index]
        if button then
            local option = entry and entry.option
            button.gaEventOption = option
            button.gaEventUnavailableReason = entry and not entry.available
                and table.concat(entry.reasons or {}, " ")
                or ""
            button.gaEventCostText = option and engine and engine:DescribeCosts(run, option) or ""
            if option then
                self.PendingDungeonEvent.optionIds[index] = option.id
                button.label:SetText(string.format("%d  %s", index, string.upper(option.name or option.id or "OPTION")))
                button:SetEnabled(entry.available == true)
                button.label:SetTextColor(
                    entry.available and COLORS.text[1] or COLORS.muted[1],
                    entry.available and COLORS.text[2] or COLORS.muted[2],
                    entry.available and COLORS.text[3] or COLORS.muted[3]
                )
                button:Show()
            else
                button:Hide()
            end
        end
    end

    if self.DungeonEventFrame then
        self.DungeonEventFrame:Show()
    end
    self:AddCombatLog("EVENT - " .. tostring(event.name or event.id) .. ".", "system")
    return true
end

function GA:ResolveDungeonEventOption(optionId)
    local run = self.RunState
    local pending = self.PendingDungeonEvent
    if not run or not run.active or not pending then return false end

    local event = GetStudioDungeonEvent(pending.eventId)
    local option = GetStudioDungeonEventOption(optionId)
    if not event or not option or option.eventId ~= event.id then return false end

    local eventStates = EnsureDungeonEventStates(run)
    local eventState = eventStates[pending.key]
    if not eventState then
        eventState = {
            eventId = event.id,
            roomIndex = pending.roomIndex,
            resolved = false,
        }
        eventStates[pending.key] = eventState
    end
    if eventState.resolved then
        self:CloseDungeonEvent()
        return false
    end

    if eventState.pendingRewardOptionId
        and eventState.pendingRewardOptionId ~= option.id then
        self:AddCombatLog("Collect the pending event reward before choosing another option.", "warning")
        return false
    end

    local engine = self.EventEngine or GA.EventEngine
    local committedReward = eventState.pendingRewardOptionId == option.id
    if engine and not eventState.costsApplied then
        local available, reasons = engine:EvaluateOption(run, option, committedReward)
        if not available then
            self:AddCombatLog(
                "EVENT OPTION LOCKED - " .. table.concat(reasons or {}, " "),
                "warning"
            )
            return false
        end

        local paid, costResult, costReasons = engine:ApplyCosts(run, option)
        if not paid then
            self:AddCombatLog(
                "EVENT COST FAILED - " .. table.concat(costReasons or {}, " "),
                "warning"
            )
            return false
        end
        eventState.costsApplied = true
        eventState.costResult = costResult
    end

    local effect = string.upper(tostring(option.effect or "NONE"))
    local value = tonumber(option.value) or 0
    local secondary = tonumber(option.secondaryValue) or 0
    local effectMessage
    local fatal = false
    local resultMetadata = { effect = effect }

    if effect == "HEAL_PERCENT" then
        local amount = math.max(0, math.floor((run.playerMaxHealth or 1) * (math.max(0, value) / 100) + 0.5))
        local before = run.playerHealth or 0
        run.playerHealth = math.min(run.playerMaxHealth or before, before + amount)
        effectMessage = string.format("+%d HP.", run.playerHealth - before)
    elseif effect == "DAMAGE_PERCENT" then
        local amount = value > 0
            and math.max(1, math.floor((run.playerMaxHealth or 1) * (value / 100) + 0.5))
            or 0
        local before = run.playerHealth or 1
        run.playerHealth = math.max(0, before - amount)
        effectMessage = string.format("-%d HP.", before - run.playerHealth)
        fatal = run.playerHealth <= 0
    elseif effect == "HP_FOR_SCORE" then
        local amount = value > 0
            and math.max(1, math.floor((run.playerMaxHealth or 1) * (value / 100) + 0.5))
            or 0
        local before = run.playerHealth or 1
        run.playerHealth = math.max(0, before - amount)
        local awarded = AddRunScore(run, "event", math.max(0, secondary))
        effectMessage = string.format("-%d HP, +%d score.", before - run.playerHealth, awarded)
        resultMetadata.score = awarded
        fatal = run.playerHealth <= 0
    elseif effect == "DAMAGE_BONUS" then
        local bonus = math.max(0, value) / 100
        local capPercent = secondary > 0 and secondary or 100
        run.eventDamageBonus = math.min(capPercent / 100, (run.eventDamageBonus or 0) + bonus)
        effectMessage = string.format(
            "Event damage bonus is now +%d%%.",
            math.floor((run.eventDamageBonus or 0) * 100 + 0.5)
        )
    elseif effect == "MAX_HP_PERCENT" then
        local beforeMax = math.max(1, tonumber(run.playerMaxHealth) or 1)
        local rawDelta = beforeMax * (value / 100)
        local delta
        if rawDelta >= 0 then
            delta = math.floor(rawDelta + 0.5)
        else
            delta = math.ceil(rawDelta - 0.5)
        end
        local newMax = math.max(1, beforeMax + delta)
        local applied = newMax - beforeMax
        run.playerMaxHealth = newMax
        if applied >= 0 then
            run.playerHealth = math.min(newMax, (run.playerHealth or 1) + applied)
        else
            run.playerHealth = math.min(newMax, run.playerHealth or newMax)
        end
        effectMessage = string.format("%+d maximum HP.", applied)
    elseif effect == "COPPER" then
        local amount = math.max(0, math.floor(value + 0.5))
        run.copper = (run.copper or 0) + amount
        local stats = EnsureRunTracking(run)
        stats.copperEarned = stats.copperEarned + amount
        effectMessage = "+" .. FormatCopperValue(amount) .. "."
        resultMetadata.copper = amount
    elseif effect == "SCORE" then
        local awarded = AddRunScore(run, "event", math.max(0, value))
        effectMessage = string.format("+%d score.", awarded)
        resultMetadata.score = awarded
    elseif effect == "LOOT_TABLE" then
        local tableId = tostring(option.lootTableId or "")
        if tableId == "" or not self.RollLootTable then
            self:AddCombatLog("Event data error: no valid loot table.", "warning")
            return false
        end

        if not eventState.rewardRollComplete then
            local drop = self:RollLootTable(tableId, run.floor, "event:" .. tostring(event.id))
            eventState.rewardRollComplete = true
            eventState.pendingRewardOptionId = option.id
            eventState.pendingReward = drop and CopyTable(drop) or nil
        end

        local drop = eventState.pendingReward
        if drop then
            if not self:AddItemToBackpack(drop) then
                self:AddCombatLog(
                    "Your backpack is full. This exact event reward is held until you make room.",
                    "warning"
                )
                return false
            end
            RecordRunLoot(run, drop)
            resultMetadata.lootTableId = tableId
            resultMetadata.lootItemId = drop.studioItemId or drop.id
            resultMetadata.lootItemName = drop.name
            effectMessage = tostring(drop.name or "An item") .. " added to your backpack."
            eventState.pendingReward = nil
        else
            resultMetadata.lootTableId = tableId
            effectMessage = "Nothing useful was found."
        end
        eventState.pendingRewardOptionId = nil
    elseif effect ~= "NONE" then
        self:AddCombatLog("Event data error: unsupported effect " .. effect .. ".", "warning")
        return false
    end

    local resultText = tostring(option.resultText or "")
    if resultText ~= "" then self:AddCombatLog(resultText, "system") end
    if effectMessage and effectMessage ~= "" then
        self:AddCombatLog("EVENT RESULT - " .. effectMessage, "system")
    end

    if eventState.costResult then
        resultMetadata.costs = CopyTable(eventState.costResult)
    end
    if engine then
        local flagResult = engine:ApplyFlagChanges(run, option)
        local queuedEvents = engine:QueueFollowups(run, option, event.id)
        resultMetadata.flags = CopyTable(flagResult)
        resultMetadata.queuedEvents = CopyTable(queuedEvents)
        if #queuedEvents > 0 then
            self:AddCombatLog(
                "EVENT CHAIN - A future encounter has been set in motion.",
                "system"
            )
        end
    end

    resultMetadata.message = effectMessage
    resultMetadata.resultText = resultText
    eventState.resolved = true
    eventState.selectedOptionId = option.id
    eventState.resolvedTurn = run.turns or 0
    eventState.result = resultMetadata

    local stats = EnsureRunTracking(run)
    stats.events = stats.events + 1
    run.eventHistory = run.eventHistory or {}
    run.eventHistory[#run.eventHistory + 1] = {
        floor = run.floor,
        eventId = event.id,
        optionId = option.id,
        result = CopyTable(resultMetadata),
    }

    if run.floorMap and run.floorMap.markers and pending.key then
        local marker = run.floorMap.markers[pending.key]
        if marker and marker.kind == "event" then
            run.floorMap.markers[pending.key] = nil
        end
    end

    self:CloseDungeonEvent()
    self:UpdateRunHealth()
    self:RefreshRunCounters()

    if fatal then
        self:FailDungeonRun(
            tostring(event.name or event.id or "The dungeon event")
            .. " killed "
            .. (run.snapshot and run.snapshot.name or "your hero")
            .. "."
        )
        return true
    end

    self:RenderDungeonGrid()
    if self.CharacterSheetFrame and self.CharacterSheetFrame:IsShown() then
        self:RefreshCharacterSheet()
    end
    return true
end

function GA:ChooseDungeonEventOption(index)
    local run = self.RunState
    local pending = self.PendingDungeonEvent
    index = math.floor(tonumber(index) or 0)
    if not run or not run.active or not pending or index < 1 or index > 4 then return false end

    local optionId = pending.optionIds and pending.optionIds[index]
    if not optionId then return false end
    return self:ResolveDungeonEventOption(optionId)
end

function GA:CloseShrineChoice()
    if self.DungeonShrineFrame then
        self.DungeonShrineFrame:Hide()
    end
    self.PendingShrineRoomIndex = nil
end

function GA:OpenShrineChoice(roomIndex)
    self:CloseDungeonEvent()
    self:CloseDungeonShop()
    local run = self.RunState
    if not run or not run.active or not roomIndex then
        return false
    end

    run.roomStates = run.roomStates or {}
    local state = run.roomStates[roomIndex]
    if not state or state.shrineUsed then
        return false
    end

    self.PendingShrineRoomIndex = roomIndex
    if self.DungeonShrineFrame then
        self.DungeonShrineFrame:Show()
    end

    self:AddCombatLog("A forgotten shrine answers your presence.", "system")
    return true
end

function GA:ChooseShrineGift(choice)
    local run = self.RunState
    local roomIndex = self.PendingShrineRoomIndex
    if not run or not run.active or not roomIndex then
        self:CloseShrineChoice()
        return false
    end

    run.roomStates = run.roomStates or {}
    local state = run.roomStates[roomIndex]
    if not state or state.shrineUsed then
        self:CloseShrineChoice()
        return false
    end

    if choice == "restore" then
        local definition = GetStudioShrineChoice("restore")
        local percent = math.max(1, tonumber(definition and definition.value) or 25)
        local amount = math.max(1, math.floor((run.playerMaxHealth or 1) * (percent / 100) + 0.5))
        local before = run.playerHealth or 0
        run.playerHealth = math.min(run.playerMaxHealth or before, before + amount)
        local restored = run.playerHealth - before
        self:AddCombatLog(string.format("SHRINE - RESTORE: +%d HP.", restored), "system")
    elseif choice == "blessing" then
        local definition = GetStudioShrineChoice("blessing")
        local bonusPercent = math.max(0, tonumber(definition and definition.value) or 5)
        local capPercent = math.max(bonusPercent, tonumber(definition and definition.secondaryValue) or 25)
        run.shrineDamageBonus = math.min(capPercent / 100, (run.shrineDamageBonus or 0) + (bonusPercent / 100))
        self:AddCombatLog(
            string.format(
                "SHRINE - BLESSING: run damage bonus is now +%d%%.",
                math.floor((run.shrineDamageBonus or 0) * 100 + 0.5)
            ),
            "system"
        )
    elseif choice == "sacrifice" then
        local definition = GetStudioShrineChoice("sacrifice")
        local costPercent = math.max(1, tonumber(definition and definition.value) or 15)
        local scoreReward = math.max(0, math.floor((tonumber(definition and definition.secondaryValue) or 150) + 0.5))
        local cost = math.max(1, math.floor((run.playerMaxHealth or 1) * (costPercent / 100) + 0.5))
        run.playerHealth = math.max(1, (run.playerHealth or 1) - cost)
        AddRunScore(run, "shrine", scoreReward)
        self:AddCombatLog(
            string.format("SHRINE - SACRIFICE: -%d HP, +%d score.", cost, scoreReward),
            "system"
        )
    else
        return false
    end

    state.shrineUsed = true
    state.shrineChoice = choice
    local stats = EnsureRunTracking(run)
    stats.shrines = stats.shrines + 1

    local room = GetRoomByIndex(run.floorMap, roomIndex)
    if room and room.center then
        local key = CellKey(room.center.x, room.center.y)
        local marker = run.floorMap.markers and run.floorMap.markers[key]
        if marker and marker.kind == "shrine" then
            marker.text = "s"
            marker.color = "muted"
            marker.used = true
        end
    end

    self:CloseShrineChoice()
    self:UpdateRunHealth()
    self:RefreshRunCounters()
    self:RenderDungeonGrid()
    return true
end

function GA:MoveDungeonPlayer(dx, dy)
    local run = self.RunState
    if not run or not run.active then
        return
    end

    local root = run.monsterStatuses and run.monsterStatuses.root
    if root and (root.turns or 0) > 0 then
        run.turns = (run.turns or 0) + 1
        self:AddCombatLog(
            (root.name or "Web") .. " holds you in place.",
            "enemy"
        )
        self:RefreshRunCounters()
        self:RunEnemyTurn()
        return
    end

    local slow = run.monsterStatuses and run.monsterStatuses.slow
    if slow and (slow.turns or 0) > 0 then
        local percent = math.max(0, math.min(90, tonumber(slow.percent) or 0))
        if percent > 0 and math.random(1, 100) <= percent then
            run.turns = (run.turns or 0) + 1
            self:AddCombatLog(
                (slow.name or "Slow") .. " prevents your movement.",
                "enemy"
            )
            self:RefreshRunCounters()
            self:RunEnemyTurn()
            return
        end
    end

    local nextX = run.playerX + dx
    local nextY = run.playerY + dy

    if IsDungeonWall(nextX, nextY) then
        if self.DungeonRunStateText then
            self.DungeonRunStateText:SetText("BLOCKED - WALL")
            self.DungeonRunStateText:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
        end
        self:AddCombatLog("A wall blocks your path.", "warning")
        return
    end

    if IsDungeonDoorClosed(nextX, nextY) then
        local doorKey = CellKey(nextX, nextY)
        run.openDoors = run.openDoors or {}
        run.openDoors[doorKey] = true
        run.turns = run.turns + 1

        if self.DungeonRunStateText then
            self.DungeonRunStateText:SetText("DOOR OPENED")
            self.DungeonRunStateText:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
        end

        self:AddCombatLog("You open the door.", "player")
        self:RefreshRunCounters()
        self:RenderDungeonGrid()
        self:RunEnemyTurn()
        return
    end

    local exitX, exitY = GetDungeonExit()
    if nextX == exitX and nextY == exitY and IsDungeonExitLocked(run) then
        if self.DungeonRunStateText then
            self.DungeonRunStateText:SetText("SEALED - DEFEAT THE BOSS")
            self.DungeonRunStateText:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
        end
        self:AddCombatLog("The exit is sealed while the boss still lives.", "warning")
        return
    end

    local blockingEnemy = GetEnemyAt(run, nextX, nextY)
    if blockingEnemy then
        run.activeEnemyId = blockingEnemy.uid
        self:PlayerAttackEnemy(blockingEnemy)
        return
    end

    run.playerX = nextX
    run.playerY = nextY
    run.turns = run.turns + 1

    local direction = "move"
    if dx == 1 then
        direction = "east"
    elseif dx == -1 then
        direction = "west"
    elseif dy == 1 then
        direction = "south"
    elseif dy == -1 then
        direction = "north"
    end
    self:AddCombatLog("You move " .. direction .. ".", "player")

    self:RefreshRunCounters()
    self:RenderDungeonGrid()
    self:TryLootChest(nextX, nextY)

    local markerKey = CellKey(nextX, nextY)
    local marker = GetDungeonMarkers()[markerKey]

    if marker and marker.kind == "event" then
        self:RunEnemyTurn()
        if run.active then
            self:OpenDungeonEvent(marker, markerKey)
        end
        return
    end

    local shrineState = marker
        and marker.kind == "shrine"
        and marker.roomIndex
        and run.roomStates
        and run.roomStates[marker.roomIndex]

    if marker and marker.kind == "shrine" and (not shrineState or not shrineState.shrineUsed) then
        self:RunEnemyTurn()
        if run.active then
            self:OpenShrineChoice(marker.roomIndex)
        end
        return
    end

    if marker and marker.kind == "shop" and marker.roomIndex then
        self:RunEnemyTurn()
        if run.active then
            self:OpenDungeonShop(marker.roomIndex)
        end
        return
    end

    self:RunEnemyTurn()
end

function GA:RefreshDungeonSummary()
    if not self.DungeonHealth then
        return
    end

    if self.RunState and self.RunState.active and self.RunState.snapshot then
        SetActiveFloorMap(self.RunState.floorMap)
        self:SetDungeonSetupMode(false)
        self:SetRunMode(true)
        self:SetDungeonRunPortraitMode(true)

        if self.DungeonRunPage and self.DungeonRunPage.SetPropagateKeyboardInput then
            self.DungeonRunPage:SetPropagateKeyboardInput(false)
        end

        self:UpdateRunHealth()

        self:RecalculateRunGearStats()
        self:RefreshRunWeaponFromEquipment()

        self:RefreshRunCounters()
        self:RenderDungeonGrid()
        return
    end

    self:SetRunMode(false)
    self:SetDungeonRunPortraitMode(false)
    self:SetDungeonSetupMode(true)

    if self.DungeonRunPage and self.DungeonRunPage.SetPropagateKeyboardInput then
        self.DungeonRunPage:SetPropagateKeyboardInput(true)
    end

    local maxHealth = self:ScaleCombatValue(UnitHealthMax("player") or 0)
    self.DungeonHealth:SetText(tostring(maxHealth))
    self:RefreshMainHandInfo()
    self:RefreshRunCounters()
    self:RenderDungeonGrid()
end

local itemEventFrame = CreateFrame("Frame")
itemEventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
itemEventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

itemEventFrame:SetScript("OnEvent", function()
    if GA.RefreshMainHandInfo then
        GA:RefreshMainHandInfo()
    end
end)
