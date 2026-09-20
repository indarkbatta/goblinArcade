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

local CHEST_LOOT_TEMPLATES = {
    {
        name = "Candlekeeper's Charm",
        icon = KOBOLD_PORTRAIT_ICON,
        itemLevel = 18,
        quality = 2,
        itemType = "Armor",
        itemSubType = "Miscellaneous",
        equipLoc = "INVTYPE_TRINKET",
        compatibleSlots = { trinket1 = true, trinket2 = true },
        slotLabel = "Trinket",
        description = "Warm wax hums faintly in your palm. Prototype dungeon loot.",
        source = "dungeon",
    },
    {
        name = "Waxbound Ring",
        icon = "Interface\\Icons\\INV_Jewelry_Ring_03",
        itemLevel = 18,
        quality = 2,
        itemType = "Armor",
        itemSubType = "Miscellaneous",
        equipLoc = "INVTYPE_FINGER",
        compatibleSlots = { finger1 = true, finger2 = true },
        slotLabel = "Finger",
        description = "A crude ring sealed with kobold wax. Prototype dungeon loot.",
        source = "dungeon",
    },
}

local function CellKey(x, y)
    return tostring(x) .. ":" .. tostring(y)
end

local function ResolveCharacterWeapon(self, character)
    if not character then
        return nil
    end

    local mainHand = character.equipment and character.equipment.mainhand
    if mainHand and self.EnsureArcadeItemConversion then
        self:EnsureArcadeItemConversion(mainHand)
        if mainHand.arcadeWeapon then
            return CopyTable(mainHand.arcadeWeapon)
        end
    end

    return character.weapon and CopyTable(character.weapon) or nil
end

local ACTIVE_FLOOR_MAP = nil

local function SetActiveFloorMap(floorMap)
    ACTIVE_FLOOR_MAP = floorMap
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

local function BuildFloorChestLoot(floorMap)
    local loot = {}
    local chestKeys = floorMap and floorMap.chestKeys or {}

    for index, key in ipairs(chestKeys) do
        local templateIndex = ((index - 1) % #CHEST_LOOT_TEMPLATES) + 1
        loot[key] = CopyTable(CHEST_LOOT_TEMPLATES[templateIndex])
    end

    return loot
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

local function CreateFloorEnemies(enemyGenerator, playerLevel, floor, gearPressure, archetypePlan, rankPlan, floorMap)
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
        local visual = ENEMY_VISUALS[archetype] or ENEMY_VISUALS.kobold

        local enemy = enemyGenerator:CreateEnemy({
            archetype = archetype,
            rank = rank,
            playerLevel = playerLevel,
            floor = floor,
            gearPressure = gearPressure,
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

local DEFAULT_RUN_XP_CURVE = { 100, 125, 155, 190, 230, 275, 325, 380 }

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
        xpPerDanger = 8,
        firstLevelXp = 100,
        levelGrowth = 1.22,
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
    local templateIndex = (((run.floor or 1) + roomIndex - 2) % #CHEST_LOOT_TEMPLATES) + 1
    local loot = CopyTable(CHEST_LOOT_TEMPLATES[templateIndex])

    loot.itemLevel = (loot.itemLevel or 1) + 2
    loot.name = "Elite Cache: " .. (loot.name or "Dungeon Reward")

    run.floorMap.markers[key] = {
        text = "$",
        color = "gold",
        kind = "chest",
        roomIndex = roomIndex,
        rewardType = "elite",
    }
    run.chestLoot = run.chestLoot or {}
    run.chestLoot[key] = loot
    state.eliteRewardSpawned = true
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
        MarkRoomCleared(run, roomIndex)
        self:AddCombatLog("BOSS DEFEATED - THE WAY OUT OPENS.", "system")
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

local ENEMY_INTENT_LABELS = {
    IDLE = "WATCHING",
    ALERTED = "ALERTED",
    MOVING = "MOVING",
    ATTACKING = "ATTACKING",
    STAGGERED = "STAGGERED",
}

local function GetEnemyIntentLabel(enemy)
    local intent = enemy and enemy.intent or "IDLE"
    return ENEMY_INTENT_LABELS[intent] or tostring(intent)
end

local function GenerateFloorSetup(floorGenerator, enemyGenerator, playerLevel, floorNumber, gearPressure, floorMap)
    local walkableTiles = CountWalkableTiles()
    local densityProfile = floorGenerator:RollDensityProfile()
    local enemyCount, baseEnemyCount = floorGenerator:CalculateEnemyCount(
        walkableTiles,
        floorNumber,
        densityProfile
    )

    local archetypePlan, archetypeCounts = floorGenerator:CreateArchetypePlan(
        enemyCount,
        floorNumber
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
        floorMap
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

    local coords = character and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[character.classFile]
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

            local enemyIcon = spriteLayer:CreateTexture(nil, "OVERLAY", nil, 2)
            enemyIcon:SetSize(CREATURE_SPRITE_RENDER_SIZE, CREATURE_SPRITE_RENDER_SIZE)
            enemyIcon:SetPoint("CENTER", cell, "CENTER", 0, 0)
            enemyIcon:SetTexture(KOBOLD_TEXTURE)
            enemyIcon:SetTexCoord(0, 1, 0, 1)
            enemyIcon:Hide()

            local marker = CreateText(cell, "GameFontNormalHuge", "")
            marker:SetPoint("CENTER")

            grid.cells[CellKey(col, row)] = {
                frame = cell,
                marker = marker,
                enemyIcon = enemyIcon,
                worldX = col,
                worldY = row,
            }
        end
    end

    return grid
end

function GA:CreateDungeonRunPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)
    page:Hide()
    self.DungeonRunPage = page

    local title = CreateText(page, "GameFontNormalHuge", "DUNGEON RUN")
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

    local subtitle = CreateText(page, "GameFontHighlightSmall", "TURN-BASED ROGUELIKE  -  9 FLOOR DUNGEON RUN")
    subtitle:SetPoint("TOPRIGHT", -18, -22)
    subtitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local body = CreateFrame("Frame", nil, page)
    body:SetPoint("TOPLEFT", 18, -58)
    body:SetPoint("BOTTOMRIGHT", -18, 100)

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

    local enemyIntent = CreateText(enemyCard, "GameFontDisableSmall", "")
    enemyIntent:SetPoint("TOPLEFT", enemyHealth, "BOTTOMLEFT", 0, -4)
    enemyIntent:SetPoint("RIGHT", enemyCard, "RIGHT", -8, 0)
    enemyIntent:SetJustifyH("LEFT")
    enemyIntent:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonEnemyIntent = enemyIntent

    local runTitle = CreateText(right, "GameFontNormalSmall", "RUN")
    runTitle:SetPoint("TOPLEFT", 12, -126)
    runTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.DungeonRunTitle = runTitle

    self.DungeonFloorValue, self.DungeonFloorLabel = CreateStatRow(right, "FLOOR", "1 / 9", -150)
    self.DungeonLevelValue, self.DungeonLevelLabel = CreateStatRow(right, "LEVEL", "--", -174)
    self.DungeonXpValue, self.DungeonXpLabel = CreateStatRow(right, "XP", "--", -198)
    self.DungeonScoreValue, self.DungeonScoreLabel = CreateStatRow(right, "SCORE", "0", -222)
    self.DungeonTurnsValue, self.DungeonTurnsLabel = CreateStatRow(right, "TURNS", "0", -246)

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
        GA:BeginDungeonRun()
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

    local abilityFrame = CreateFrame("Frame", nil, center, "BackdropTemplate")
    abilityFrame:SetSize(558, 470)
    abilityFrame:SetPoint("CENTER", center, "CENTER", 0, 0)
    abilityFrame:SetFrameLevel(center:GetFrameLevel() + 55)
    abilityFrame:EnableMouse(true)
    ApplyBackdrop(abilityFrame, { 0.025, 0.021, 0.017, 0.985 }, COLORS.gold)
    abilityFrame:Hide()
    self.DungeonAbilityFrame = abilityFrame

    local abilityTitle = CreateText(abilityFrame, "GameFontNormalLarge", "WARRIOR ABILITIES")
    abilityTitle:SetPoint("TOP", 0, -16)
    abilityTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local abilityHint = CreateText(abilityFrame, "GameFontHighlightSmall", "Unlocked abilities from your current Run Level")
    abilityHint:SetPoint("TOP", abilityTitle, "BOTTOM", 0, -7)
    abilityHint:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    self.DungeonAbilityButtons = {}
    for i = 1, #RUN_ABILITY_IDS do
        local col = (i - 1) % 3
        local row = math.floor((i - 1) / 3)
        local hotkey = i <= 9 and tostring(i) or (i == 10 and "0" or "•")
        local abilityButton = CreateFlatButton(abilityFrame, hotkey .. "  --", 166, 30)
        abilityButton:SetPoint("TOPLEFT", 16 + col * 174, -62 - row * 34)
        abilityButton.gaAbilityIndex = i
        abilityButton:SetScript("OnClick", function(button)
            GA:UseAbilityPanelIndex(button.gaAbilityIndex)
        end)
        self.DungeonAbilityButtons[i] = abilityButton
    end

    local abilityClose = CreateFlatButton(abilityFrame, "B / ESC  CLOSE", 160, 30)
    abilityClose:SetPoint("BOTTOM", 0, 12)
    abilityClose:SetScript("OnClick", function()
        GA:CloseAbilityPanel()
    end)

    local legend = CreateText(center, "GameFontDisableSmall", "@ YOU    ENEMY SPRITE    * CLEARED    S SHRINE    $ CHEST    < / > STAIRS")
    legend:SetPoint("BOTTOM", 0, 9)
    legend:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local actionBar = CreateFrame("Frame", nil, page, "BackdropTemplate")
    actionBar:SetPoint("BOTTOMLEFT", 18, 16)
    actionBar:SetPoint("BOTTOMRIGHT", -18, 16)
    actionBar:SetHeight(72)
    ApplyBackdrop(actionBar, { 0.050, 0.043, 0.034, 1 }, COLORS.goldDim)

    local actionLabel = CreateText(actionBar, "GameFontNormalSmall", "ACTIONS")
    actionLabel:SetPoint("BOTTOMLEFT", 12, 14)
    actionLabel:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local actions = {
        { "1", "ATTACK" },
        { "2", "HEROIC STRIKE" },
        { "3", "ABILITIES" },
        { "4", "POTION" },
    }

    self.DungeonActionButtons = {}

    for i, action in ipairs(actions) do
        local button = CreateFlatButton(actionBar, action[1] .. "  " .. action[2], 116, 32)
        button:SetPoint("BOTTOMLEFT", 88 + (i - 1) * 124, 8)
        button:SetEnabled(false)
        button.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        self.DungeonActionButtons[i] = button

        if i == 1 then
            self.DungeonAttackButton = button
            button:SetScript("OnClick", function()
                GA:PlayerAttackEnemy()
            end)
        elseif i == 2 then
            self.DungeonHeroicStrikeButton = button
            button:SetScript("OnClick", function()
                GA:UseRunAbility("heroic_strike")
            end)
        elseif i == 3 then
            self.DungeonAbilitiesButton = button
            button:SetScript("OnClick", function()
                GA:ToggleAbilityPanel()
            end)
        end
    end

    local state = CreateText(actionBar, "GameFontDisableSmall", "READY - BEGIN A RUN")
    state:SetPoint("TOPLEFT", 12, -8)
    state:SetPoint("TOPRIGHT", -12, -8)
    state:SetJustifyH("RIGHT")
    state:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonRunStateText = state

    local setup = CreateFrame("Frame", nil, page, "BackdropTemplate")
    setup:SetPoint("TOPLEFT", 1, -1)
    setup:SetPoint("BOTTOMRIGHT", -1, 1)
    setup:SetFrameLevel(page:GetFrameLevel() + 20)
    ApplyBackdrop(setup, { 0.040, 0.034, 0.027, 1 }, COLORS.goldDim)
    self.DungeonSetupFrame = setup

    local setupTitle = CreateText(setup, "GameFontNormalHuge", "DUNGEON RUN")
    setupTitle:SetPoint("TOPLEFT", 26, -22)
    setupTitle:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

    local setupSubtitle = CreateText(setup, "GameFontNormal", "CHOOSE A HERO")
    setupSubtitle:SetPoint("TOPLEFT", setupTitle, "BOTTOMLEFT", 0, -10)
    setupSubtitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local setupHint = CreateText(setup, "GameFontHighlightSmall",
        "Characters are remembered after you log into them once. Offline alts use their last synced GoblinArcade loadout.")
    setupHint:SetPoint("TOPLEFT", setupSubtitle, "BOTTOMLEFT", 0, -8)
    setupHint:SetWidth(670)
    setupHint:SetJustifyH("LEFT")
    setupHint:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local rosterPanel = CreateFrame("Frame", nil, setup, "BackdropTemplate")
    rosterPanel:SetPoint("TOPLEFT", 26, -112)
    rosterPanel:SetSize(330, 392)
    ApplyBackdrop(rosterPanel, { 0.050, 0.043, 0.034, 1 }, COLORS.goldDim)
    rosterPanel:EnableMouseWheel(true)
    self.DungeonRosterPanel = rosterPanel

    local rosterTitle = CreateText(rosterPanel, "GameFontNormalSmall", "CHARACTERS")
    rosterTitle:SetPoint("TOPLEFT", 12, -12)
    rosterTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    self.DungeonCharacterRows = {}
    for i = 1, 6 do
        local row = CreateFrame("Button", nil, rosterPanel, "BackdropTemplate")
        row:SetSize(304, 50)
        row:SetPoint("TOPLEFT", 12, -38 - ((i - 1) * 56))
        ApplyBackdrop(row, { 0.060, 0.052, 0.042, 1 }, COLORS.goldDim)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(36, 36)
        icon:SetPoint("LEFT", 7, 0)

        local nameText = CreateText(row, "GameFontNormal", "")
        nameText:SetPoint("TOPLEFT", 52, -8)
        nameText:SetPoint("RIGHT", -8, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

        local metaText = CreateText(row, "GameFontHighlightSmall", "")
        metaText:SetPoint("BOTTOMLEFT", 52, 8)
        metaText:SetPoint("RIGHT", -8, 0)
        metaText:SetJustifyH("LEFT")
        metaText:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

        row.icon = icon
        row.nameText = nameText
        row.metaText = metaText
        row:SetScript("OnClick", function(button)
            if button.characterKey then
                GA:SelectDungeonCharacter(button.characterKey)
            end
        end)
        self.DungeonCharacterRows[i] = row
    end

    rosterPanel:SetScript("OnMouseWheel", function(_, delta)
        local roster = GA:GetCharacterRoster()
        local maxOffset = math.max(0, #roster - #GA.DungeonCharacterRows)
        GA.DungeonRosterOffset = math.max(0, math.min(maxOffset, (GA.DungeonRosterOffset or 0) - delta))
        GA:RefreshDungeonCharacterSelection()
    end)

    local selectedPanel = CreateFrame("Frame", nil, setup, "BackdropTemplate")
    selectedPanel:SetPoint("TOPLEFT", rosterPanel, "TOPRIGHT", 14, 0)
    selectedPanel:SetSize(330, 392)
    ApplyBackdrop(selectedPanel, { 0.050, 0.043, 0.034, 1 }, COLORS.goldDim)

    local selectedTitle = CreateText(selectedPanel, "GameFontNormalSmall", "SELECTED HERO")
    selectedTitle:SetPoint("TOPLEFT", 16, -14)
    selectedTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local selectedIconBorder = CreateFrame("Frame", nil, selectedPanel, "BackdropTemplate")
    selectedIconBorder:SetSize(82, 82)
    selectedIconBorder:SetPoint("TOPLEFT", 16, -42)
    ApplyBackdrop(selectedIconBorder, { 0.02, 0.02, 0.02, 1 }, COLORS.gold)

    local selectedIcon = selectedIconBorder:CreateTexture(nil, "ARTWORK")
    selectedIcon:SetPoint("TOPLEFT", 3, -3)
    selectedIcon:SetPoint("BOTTOMRIGHT", -3, 3)
    self.DungeonSelectedCharacterIcon = selectedIcon

    local selectedName = CreateText(selectedPanel, "GameFontNormalLarge", "")
    selectedName:SetPoint("TOPLEFT", selectedIconBorder, "TOPRIGHT", 14, -7)
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
    selectedSource:SetPoint("TOPLEFT", selectedMeta, "BOTTOMLEFT", 0, -8)
    selectedSource:SetPoint("RIGHT", -16, 0)
    selectedSource:SetJustifyH("LEFT")
    selectedSource:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.DungeonSelectedCharacterSource = selectedSource

    local loadoutTitle = CreateText(selectedPanel, "GameFontNormalSmall", "CACHED LOADOUT")
    loadoutTitle:SetPoint("TOPLEFT", 16, -146)
    loadoutTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local loadoutWeapon = CreateText(selectedPanel, "GameFontNormal", "")
    loadoutWeapon:SetPoint("TOPLEFT", 16, -174)
    loadoutWeapon:SetPoint("RIGHT", -16, 0)
    loadoutWeapon:SetJustifyH("LEFT")
    loadoutWeapon:SetWordWrap(true)
    loadoutWeapon:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    self.DungeonSelectedWeaponName = loadoutWeapon

    local loadoutStats = CreateText(selectedPanel, "GameFontHighlightSmall", "")
    loadoutStats:SetPoint("TOPLEFT", loadoutWeapon, "BOTTOMLEFT", 0, -8)
    loadoutStats:SetPoint("RIGHT", -16, 0)
    loadoutStats:SetJustifyH("LEFT")
    loadoutStats:SetWordWrap(true)
    loadoutStats:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.DungeonSelectedWeaponStats = loadoutStats

    local loadoutTrait = CreateText(selectedPanel, "GameFontNormalSmall", "")
    loadoutTrait:SetPoint("TOPLEFT", loadoutStats, "BOTTOMLEFT", 0, -14)
    loadoutTrait:SetPoint("RIGHT", -16, 0)
    loadoutTrait:SetJustifyH("LEFT")
    loadoutTrait:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.DungeonSelectedWeaponTrait = loadoutTrait

    local selectedNote = CreateText(selectedPanel, "GameFontDisableSmall",
        "To refresh an alt's gear, log into that character once and open GoblinArcade.")
    selectedNote:SetPoint("BOTTOMLEFT", 16, 76)
    selectedNote:SetPoint("RIGHT", -16, 0)
    selectedNote:SetJustifyH("LEFT")
    selectedNote:SetWordWrap(true)
    selectedNote:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    local setupBegin = CreateFlatButton(selectedPanel, "BEGIN RUN", 180, 42)
    setupBegin:SetPoint("BOTTOMRIGHT", -16, 16)
    setupBegin:SetEnabled(false)
    setupBegin.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    setupBegin:SetScript("OnClick", function()
        GA:BeginDungeonRun()
    end)
    self.DungeonSetupBeginButton = setupBegin

    if self.CreateCharacterSheet then
        self:CreateCharacterSheet(page)
    end

    page:EnableKeyboard(true)
    if page.SetPropagateKeyboardInput then
        page:SetPropagateKeyboardInput(true)
    end

    page:SetScript("OnKeyDown", function(pageFrame, key)
        local runActive = GA.RunState and GA.RunState.active

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

        if GA.DungeonAbilityFrame and GA.DungeonAbilityFrame:IsShown() then
            if key == "ESCAPE" or key == "B" then
                GA:CloseAbilityPanel()
            else
                local abilityIndex = key == "0" and 10 or tonumber(key)
                if abilityIndex then
                    GA:UseAbilityPanelIndex(abilityIndex)
                end
            end
            return
        end

        if key == "B" or key == "3" then
            GA:ToggleAbilityPanel()
            return
        end

        if key == "C" then
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
            if GA.MainFrame then
                GA.MainFrame:Hide()
            end
            return
        end

        if key == "1" then
            GA:PlayerAttackEnemy()
            return
        elseif key == "2" then
            GA:UseRunAbility("heroic_strike")
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

function GA:SetDungeonSetupMode(active)
    if not self.DungeonSetupFrame then
        return
    end

    if active then
        self.DungeonSetupFrame:Show()
        self:SetRunMode(false)
        self:RefreshDungeonCharacterSelection()
    else
        self.DungeonSetupFrame:Hide()
    end
end

function GA:RefreshDungeonCharacterSelection()
    if not self.DungeonSetupFrame or not self.GetCharacterRoster then
        return
    end

    local roster = self:GetCharacterRoster()
    local currentKey = self:GetCurrentCharacterKey()
    local selected = self:GetSelectedDungeonCharacter()

    if not selected and #roster > 0 then
        self:SelectDungeonCharacter(roster[1].key)
        return
    end

    local offset = self.DungeonRosterOffset or 0
    local maxOffset = math.max(0, #roster - #self.DungeonCharacterRows)
    if offset > maxOffset then
        offset = maxOffset
        self.DungeonRosterOffset = offset
    end

    for i, row in ipairs(self.DungeonCharacterRows or {}) do
        local character = roster[offset + i]
        if character then
            row.characterKey = character.key
            row:Show()
            SetCharacterVisual(row.icon, character)
            row.nameText:SetText(character.name or "Unknown")
            row.metaText:SetText(string.format(
                "Level %d %s %s%s",
                character.level or 0,
                character.raceName or "",
                character.className or "Adventurer",
                character.key == currentKey and "  -  CURRENT" or ""
            ))

            if selected and character.key == selected.key then
                row:SetBackdropColor(0.15, 0.105, 0.045, 1)
                row:SetBackdropBorderColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1)
            else
                row:SetBackdropColor(0.060, 0.052, 0.042, 1)
                row:SetBackdropBorderColor(COLORS.goldDim[1], COLORS.goldDim[2], COLORS.goldDim[3], 1)
            end
        else
            row.characterKey = nil
            row:Hide()
        end
    end

    if not selected then
        return
    end

    SetCharacterVisual(self.DungeonSelectedCharacterIcon, selected)
    self.DungeonSelectedCharacterName:SetText(selected.name or "Unknown")
    self.DungeonSelectedCharacterMeta:SetText(string.format(
        "Level %d %s %s  -  %s",
        selected.level or 0,
        selected.raceName or "",
        selected.className or "Adventurer",
        selected.realm or "Unknown Realm"
    ))
    self.DungeonSelectedCharacterSource:SetText(
        selected.key == currentKey and "CURRENT CHARACTER - LIVE DATA" or "ALT - LAST SYNCED DATA"
    )

    local weapon = ResolveCharacterWeapon(self, selected)
    if weapon then
        self.DungeonSelectedWeaponName:SetText(selected.weaponName or weapon.sourceName or "Cached main hand")
        self.DungeonSelectedWeaponStats:SetText(string.format(
            "%s  -  Damage %d-%d  -  %s  -  Range %d",
            weapon.style or "Weapon",
            weapon.damageMin or 0,
            weapon.damageMax or 0,
            weapon.speed or "NORMAL",
            weapon.range or 1
        ))
        if weapon.traitName then
            self.DungeonSelectedWeaponTrait:SetText(weapon.traitName .. "  -  " .. (weapon.traitDescription or ""))
        else
            self.DungeonSelectedWeaponTrait:SetText("NO SIGNATURE TRAIT")
        end

        self.DungeonSetupBeginButton:SetEnabled(true)
        self.DungeonSetupBeginButton.label:SetText("BEGIN RUN")
        self.DungeonSetupBeginButton.label:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    else
        self.DungeonSelectedWeaponName:SetText("No cached main-hand weapon")
        self.DungeonSelectedWeaponStats:SetText("Log into this character and equip a weapon to sync it.")
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

            if self.DungeonEnemyIntent then
                local intent = enemy.intent or "IDLE"
                self.DungeonEnemyIntent:SetText(string.format(
                    "DANGER %d  %s",
                    enemy.dangerRating or 1,
                    GetEnemyIntentLabel(enemy)
                ))

                if intent == "ATTACKING" then
                    self.DungeonEnemyIntent:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
                elseif intent == "STAGGERED" or intent == "ALERTED" then
                    self.DungeonEnemyIntent:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
                else
                    self.DungeonEnemyIntent:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
                end
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
        else
            self.DungeonRunTitle:SetPoint("TOPLEFT", 12, -14)
            PositionRunRow(self.DungeonFloorLabel, self.DungeonFloorValue, -38)
            PositionRunRow(self.DungeonLevelLabel, self.DungeonLevelValue, -62)
            PositionRunRow(self.DungeonXpLabel, self.DungeonXpValue, -86)
            PositionRunRow(self.DungeonScoreLabel, self.DungeonScoreValue, -110)
            PositionRunRow(self.DungeonTurnsLabel, self.DungeonTurnsValue, -134)
        end
    end
end

function GA:RefreshActionButtons()
    local run = self.RunState
    local enemy = run and run.active and GetAdjacentEnemy(run) or nil
    local canAttack = enemy ~= nil

    if self.DungeonAttackButton then
        self.DungeonAttackButton:SetEnabled(canAttack and true or false)
        self.DungeonAttackButton.label:SetTextColor(
            canAttack and COLORS.gold[1] or COLORS.muted[1],
            canAttack and COLORS.gold[2] or COLORS.muted[2],
            canAttack and COLORS.gold[3] or COLORS.muted[3]
        )
    end

    if self.DungeonHeroicStrikeButton then
        local heroic = GetStudioAbilityById("heroic_strike")
        local cost = math.max(0, tonumber(heroic and heroic.resourceCost) or 0)
        local cooldown = run and run.cooldowns and (run.cooldowns.heroic_strike or 0) or 0
        local unlocked = run and run.unlockedAbilities and run.unlockedAbilities.heroic_strike
        local enoughResource = run and (run.resource or 0) >= cost
        local usable = canAttack and unlocked and enoughResource and cooldown <= 0

        self.DungeonHeroicStrikeButton.label:SetText("2  HEROIC STRIKE")
        self.DungeonHeroicStrikeButton:SetEnabled(usable and true or false)
        self.DungeonHeroicStrikeButton.label:SetTextColor(
            usable and COLORS.gold[1] or COLORS.muted[1],
            usable and COLORS.gold[2] or COLORS.muted[2],
            usable and COLORS.gold[3] or COLORS.muted[3]
        )
    end

    if self.DungeonAbilitiesButton then
        local hasAbility = false
        if run and run.active then
            for _, abilityId in ipairs(RUN_ABILITY_IDS) do
                if run.unlockedAbilities and run.unlockedAbilities[abilityId] then
                    hasAbility = true
                    break
                end
            end
        end
        self.DungeonAbilitiesButton:SetEnabled(hasAbility)
        self.DungeonAbilitiesButton.label:SetTextColor(
            hasAbility and COLORS.gold[1] or COLORS.muted[1],
            hasAbility and COLORS.gold[2] or COLORS.muted[2],
            hasAbility and COLORS.gold[3] or COLORS.muted[3]
        )
    end

    if self.DungeonAbilityFrame and self.DungeonAbilityFrame:IsShown() then
        self:RefreshAbilityPanel()
    end
end

function GA:RefreshAbilityPanel()
    local run = self.RunState
    for i, button in ipairs(self.DungeonAbilityButtons or {}) do
        local abilityId = RUN_ABILITY_IDS[i]
        local ability = GetStudioAbilityById(abilityId)
        local unlocked = run and run.active and run.unlockedAbilities and run.unlockedAbilities[abilityId]

        if ability and unlocked then
            local hotkey = i <= 9 and tostring(i) or (i == 10 and "0" or "•")
            local cost = math.max(0, tonumber(ability.resourceCost) or 0)
            local cooldown = run.cooldowns and math.max(0, run.cooldowns[abilityId] or 0) or 0
            local enoughResource = (run.resource or 0) >= cost
            local suffix = ""
            if cooldown > 0 then
                suffix = string.format("  CD:%d", cooldown)
            elseif cost > 0 then
                suffix = string.format("  %d %s", cost, run.resourceType or "RESOURCE")
            end

            button.gaAbilityId = abilityId
            button.label:SetText(hotkey .. "  " .. string.upper(ability.name or abilityId) .. suffix)
            button:SetEnabled(enoughResource and cooldown <= 0)
            button.label:SetTextColor(
                enoughResource and cooldown <= 0 and COLORS.gold[1] or COLORS.muted[1],
                enoughResource and cooldown <= 0 and COLORS.gold[2] or COLORS.muted[2],
                enoughResource and cooldown <= 0 and COLORS.gold[3] or COLORS.muted[3]
            )
            button:Show()
        else
            button.gaAbilityId = nil
            button:Hide()
        end
    end
end

function GA:OpenAbilityPanel()
    if not self.RunState or not self.RunState.active or not self.DungeonAbilityFrame then
        return
    end
    if self.CharacterSheetFrame then
        self.CharacterSheetFrame:Hide()
    end
    self:CloseShrineChoice()
    self:RefreshAbilityPanel()
    self.DungeonAbilityFrame:Show()
end

function GA:CloseAbilityPanel()
    if self.DungeonAbilityFrame then
        self.DungeonAbilityFrame:Hide()
    end
end

function GA:ToggleAbilityPanel()
    if not self.DungeonAbilityFrame then return end
    if self.DungeonAbilityFrame:IsShown() then
        self:CloseAbilityPanel()
    else
        self:OpenAbilityPanel()
    end
end

function GA:UseAbilityPanelIndex(index)
    local button = self.DungeonAbilityButtons and self.DungeonAbilityButtons[index]
    local abilityId = button and button.gaAbilityId
    if not abilityId then return false end

    self:CloseAbilityPanel()
    return self:UseRunAbility(abilityId)
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

function GA:FailDungeonRun(reason)
    local run = self.RunState
    if not run then
        return
    end

    run.active = false
    run.failed = true
    self:CloseShrineChoice()
    self:CloseAbilityPanel()

    self:AddCombatLog(reason or "The run is over.", "warning")

    if self.DungeonRunStateText then
        self.DungeonRunStateText:SetText("RUN ENDED")
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
    self:SetDungeonRunPortraitMode(false)
    self:SetRunMode(false)
    self:RefreshMainHandInfo(true)
    self:SetDungeonSetupMode(true)
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

local function GetRunDamageDoneMultiplier(run)
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

    local abilityMultiplier = ability and math.max(0.01, tonumber(ability.damageMultiplier) or 1) or 1
    damage = math.max(1, math.floor(damage * abilityMultiplier + 0.5))
    damage = math.max(1, math.floor(damage * GetRunDamageDoneMultiplier(run) + 0.5))
    damage = math.max(1, math.floor(damage * GetEnemyIncomingDamageMultiplier(enemy) + 0.5))

    local shrineDamageBonus = math.max(0, tonumber(run.shrineDamageBonus) or 0)
    if shrineDamageBonus > 0 then
        damage = math.max(1, math.floor(damage * (1 + shrineDamageBonus) + 0.5))
    end

    local critChance = run.arcadeStats and run.arcadeStats.crit or 0
    if run.stance == "berserker" then
        local berserker = GetStudioAbilityById("berserker_stance") or {}
        critChance = critChance + math.max(0, tonumber(berserker.effectValue) or 0)
    end
    local recklessness = run.buffs and run.buffs.recklessness
    if recklessness and (recklessness.turns or 0) > 0 then
        critChance = critChance + math.max(0, tonumber(recklessness.critBonus) or 0)
    end
    critChance = math.min(100, critChance)
    local critical = critChance > 0 and math.random(1, 1000) <= math.floor(critChance * 10)
    if critical then
        damage = math.max(1, math.floor(damage * 1.5 + 0.5))
    end

    return damage, critical, weapon
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
    run.score = (run.score or 0) + scoreValue

    self:AddCombatLog(
        string.format("%s defeated. +%d score, +%d XP.", GetEnemyDisplayName(enemy), scoreValue, xpValue),
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
    UpdateEncounterRoomClear(self, run, enemy)
    return leveledUp, previousRunLevel, currentRunLevel
end

function GA:DealRunDamage(enemy, ability, options)
    local run = self.RunState
    if not run or not run.active or not enemy or enemy.alive == false then
        return false
    end

    options = type(options) == "table" and options or {}
    local damage, critical, weapon = RollRunWeaponDamage(self, run, enemy, ability)
    enemy.hp = math.max(0, (enemy.hp or enemy.maxHp or 1) - damage)

    local sourceName = ability and (ability.name or ability.id) or "You"
    self:AddCombatLog(
        string.format("%s%s %s the %s for %d damage. (%d/%d HP)",
            critical and "CRITICAL! " or "",
            sourceName,
            ability and "hits" or "hit",
            string.lower(GetEnemyDisplayName(enemy)),
            damage,
            enemy.hp,
            enemy.maxHp or enemy.hp),
        "player"
    )

    if enemy.hp > 0 and options.allowWeaponTrait ~= false and weapon and weapon.traitName == "STAGGER" then
        local staggerChance = tonumber(weapon.traitValue) or 0
        if staggerChance > 0 and math.random(1, 100) <= staggerChance then
            enemy.skipTurn = true
            enemy.intent = "STAGGERED"
            self:AddCombatLog(
                string.format("STAGGER! The %s loses its next action.", string.lower(GetEnemyDisplayName(enemy))),
                "system"
            )
        end
    end

    if enemy.hp > 0 and ability then
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
                damage = damage,
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
        return true, true, leveledUp, previousRunLevel, currentRunLevel
    end

    return true, false
end

function GA:AdvanceCombatEffects()
    local run = self.RunState
    if not run or not run.active then return end

    for _, enemy in ipairs(run.enemies or {}) do
        if enemy.alive ~= false and enemy.statuses then
            local rend = enemy.statuses.rend
            if rend and (rend.turns or 0) > 0 then
                local tick = math.max(1, math.floor(tonumber(rend.damage) or 1))
                enemy.hp = math.max(0, (enemy.hp or 1) - tick)
                self:AddCombatLog(
                    string.format("Rend bleeds %s for %d damage. (%d/%d HP)",
                        string.lower(GetEnemyDisplayName(enemy)),
                        tick,
                        enemy.hp,
                        enemy.maxHp or enemy.hp),
                    "player"
                )
                rend.turns = rend.turns - 1
                if enemy.hp <= 0 then
                    self:HandleEnemyDefeat(enemy)
                elseif rend.turns <= 0 then
                    enemy.statuses.rend = nil
                end
            end

            for _, statusId in ipairs({ "hamstring", "weakened", "sunder", "disarmed", "feared" }) do
                local status = enemy.statuses[statusId]
                if status then
                    status.turns = (status.turns or 1) - 1
                    if status.turns <= 0 then
                        enemy.statuses[statusId] = nil
                    end
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
            if reactive.turns <= 0 then
                run.reactive[reactiveId] = nil
            end
        end
    end

    for abilityId, turns in pairs(run.cooldowns or {}) do
        turns = math.max(0, (tonumber(turns) or 0) - 1)
        if turns <= 0 then
            run.cooldowns[abilityId] = nil
        else
            run.cooldowns[abilityId] = turns
        end
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
    if not run or not run.active then
        return false
    end

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
    else
        GainRunResource(run, run.classGrowth and run.classGrowth.basicAttackResourceGain or 0)
    end

    run.turns = run.turns + 1
    self:UpdateRunResource()

    if ability and run.reactive then
        if ability.id == "overpower" then
            run.reactive.overpower = nil
        elseif ability.id == "revenge" then
            run.reactive.revenge = nil
        elseif ability.id == "victory_rush" then
            run.reactive.victory_rush = nil
        end
    end

    local _, defeated, leveledUp, previousRunLevel, currentRunLevel = self:DealRunDamage(enemy, ability)

    if ability and ability.id == "victory_rush" then
        local healPercent = math.max(0, tonumber(ability.effectValue) or 0)
        local healAmount = math.max(1, math.floor((run.playerMaxHealth or 1) * healPercent / 100 + 0.5))
        local before = run.playerHealth or 0
        run.playerHealth = math.min(run.playerMaxHealth or before, before + healAmount)
        local restored = math.max(0, run.playerHealth - before)
        self:AddCombatLog(string.format("Victory Rush restores %d HP.", restored), "player")
        self:UpdateRunHealth()
    elseif ability and ability.id == "cleave" then
        local extraTarget
        for _, candidate in ipairs(GetAdjacentEnemies(run)) do
            if candidate.uid ~= enemy.uid then
                extraTarget = candidate
                break
            end
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
            self.DungeonRunStateText:SetText("PLAYER TURN - " .. string.upper(GetEnemyDisplayName(enemy)) .. " DEFEATED")
            self.DungeonRunStateText:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
        end
    end

    self:RefreshRunCounters()
    self:RenderDungeonGrid()
    self:RefreshActionButtons()

    -- Every valid attack, including a killing blow, consumes the player's action.
    if run.active then
        self:RunEnemyTurn()
    end
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
                if entry.enemyIcon then
                    entry.enemyIcon:Hide()
                end

                if not explored then
                    -- Unseen: almost completely black. The player has no map
                    -- knowledge of either walls or floor here yet.
                    entry.frame:SetBackdropColor(0.008, 0.007, 0.006, 1)
                    entry.frame:SetBackdropBorderColor(0, 0, 0, 0)
                elseif not visible then
                    -- Explored memory: preserve terrain shape, but strongly dim it.
                    if wall then
                        entry.frame:SetBackdropColor(0.045, 0.038, 0.028, 1)
                        entry.frame:SetBackdropBorderColor(0.070, 0.058, 0.040, 1)
                    else
                        entry.frame:SetBackdropColor(0.020, 0.018, 0.015, 1)
                        entry.frame:SetBackdropBorderColor(0.026, 0.023, 0.019, 0.55)
                    end
                else
                    -- Currently visible.
                    if wall then
                        entry.frame:SetBackdropColor(0.12, 0.095, 0.06, 1)
                        entry.frame:SetBackdropBorderColor(0.20, 0.16, 0.09, 1)
                    else
                        entry.frame:SetBackdropColor(0.055, 0.048, 0.038, 1)
                        entry.frame:SetBackdropBorderColor(0.09, 0.075, 0.055, 1)
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

                    if staticMarker and not (staticMarker.text == "$" and chestOpened) then
                        if staticMarker.kind == "door" then
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
end

function GA:BeginDungeonRun()
    if self.RunState and self.RunState.active then
        return
    end

    local currentKey = self.GetCurrentCharacterKey and self:GetCurrentCharacterKey()
    local selected = self.GetSelectedDungeonCharacter and self:GetSelectedDungeonCharacter()

    if selected and selected.key == currentKey then
        self:RefreshMainHandInfo(true)
        selected = self:GetSelectedDungeonCharacter()
    end

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
    local classId = string.lower(tostring(selected.classFile or className or ""))
    local progression = GetRunProgression()
    local classGrowth = GetClassRunGrowth(classId)
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
        selected.equipment or {}
    )

    local dungeonSeed = math.random(1, 2147483646)
    local floorMap = self.DungeonGenerator:GenerateFloor(
        GRID_WIDTH,
        GRID_HEIGHT,
        floor,
        dungeonSeed
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
        floorMap
    )

    local walkableTiles = floorSetup.walkableTiles
    local densityProfile = floorSetup.densityProfile
    local baseEnemyCount = floorSetup.baseEnemyCount
    local archetypeCounts = floorSetup.enemyComposition
    local rankCounts = floorSetup.enemyRankComposition
    local roomRoleCounts = floorMap.roomRoleCounts or {}
    local floorEnemies = floorSetup.enemies
    local sampleEnemy = floorEnemies[1]

    self.RunState = {
        active = true,
        completed = false,
        floor = floor,
        score = 0,
        turns = 0,
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
        stance = "battle",
        unlockedAbilities = GetClassAbilityIdSet(classId, level),
        playerX = startX,
        playerY = startY,
        playerHealth = maxHealth,
        playerMaxHealth = maxHealth,
        baseMaxHealth = maxHealth,
        equipment = CopyTable(selected.equipment or {}),
        backpack = {},
        openedChests = {},
        openDoors = {},
        explored = {},
        visible = {},
        gearPressure = CopyTable(gearPressure),
        dungeonSeed = dungeonSeed,
        floorMap = floorMap,
        floorStates = {},
        roomRoleCounts = CopyTable(roomRoleCounts),
        roomStates = BuildInitialRoomStates(floorMap),
        shrineDamageBonus = 0,
        chestLoot = BuildFloorChestLoot(floorMap),
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
            realm = selected.realm,
            maxHealth = maxHealth,
            mainHandLink = selected.weaponLink,
            weaponIcon = selected.weaponIcon,
            weapon = selectedWeapon,
        },
    }

    if self.RunState.equipment and self.RunState.equipment.mainhand then
        self.RunState.equipment.mainhand.arcadeWeapon = CopyTable(selectedWeapon)
    end

    self:UpdateRunHealth()
    self:UpdateRunResource()
    self:RefreshRunWeaponFromEquipment()
    self:RecalculateRunGearStats()
    self.DungeonArcadeDamage:SetText(string.format("Damage %d - %d", selectedWeapon.damageMin, selectedWeapon.damageMax))
    self.DungeonArcadeStyle:SetText(string.format(
        "%s  -  %s  -  Range %d",
        selectedWeapon.style or "Weapon",
        selectedWeapon.speed or "NORMAL",
        selectedWeapon.range or 1
    ))
    self.DungeonArcadeTraitName:SetText(selectedWeapon.traitName or "NO SIGNATURE TRAIT")
    self.DungeonArcadeTraitDesc:SetText(selectedWeapon.traitDescription or "")

    if self.DungeonBeginButton then
        self.DungeonBeginButton:SetEnabled(false)
        self.DungeonBeginButton.label:SetText("RUNNING")
        self.DungeonBeginButton.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
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
        self.DungeonRunStateText:SetText("PLAYER TURN - WASD / ARROWS")
        self.DungeonRunStateText:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
    end

    if self.DungeonRunPage and self.DungeonRunPage.SetPropagateKeyboardInput then
        self.DungeonRunPage:SetPropagateKeyboardInput(false)
    end

    self:SetDungeonSetupMode(false)
    self:SetRunMode(true)
    self:SetDungeonRunPortraitMode(true)
    self:ResetCombatLog()
    self:AddCombatLog("Dungeon Run started.", "system")
    self:AddCombatLog(
        string.format("Loadout locked: %s  %d-%d damage.",
            self.RunState.snapshot.weapon.sourceName or "Main hand",
            self.RunState.snapshot.weapon.damageMin,
            self.RunState.snapshot.weapon.damageMax),
        "player"
    )
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
        string.format(
            "Class growth: +%d HP / level, +%d %s cap / level. Basic attack: +%d %s.",
            classGrowth.hpPerLevel or 0,
            classGrowth.resourcePerLevel or 0,
            classGrowth.resourceType or "RESOURCE",
            classGrowth.basicAttackResourceGain or 0,
            classGrowth.resourceType or "RESOURCE"
        ),
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
        chestLoot = CopyTable(run.chestLoot or {}),
        openedChests = CopyTable(run.openedChests or {}),
        openDoors = CopyTable(run.openDoors or {}),
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

local function ApplyStoredFloorState(run, floorNumber, stored, entryDirection)
    run.floor = floorNumber
    run.floorMap = CopyTable(stored.floorMap)
    run.roomRoleCounts = CopyTable(stored.roomRoleCounts or {})
    run.roomStates = CopyTable(stored.roomStates or {})
    run.chestLoot = CopyTable(stored.chestLoot or {})
    run.openedChests = CopyTable(stored.openedChests or {})
    run.openDoors = CopyTable(stored.openDoors or {})
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
    self:CloseShrineChoice()
    self:CloseAbilityPanel()

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
        floorMap = run.floorMap
    else
        floorMap = self.DungeonGenerator and self.DungeonGenerator:GenerateFloor(
            GRID_WIDTH,
            GRID_HEIGHT,
            floorNumber,
            run.dungeonSeed
        )

        if not floorMap then
            self:AddCombatLog("Dungeon generation failed for the target floor.", "warning")
            return false
        end

        SetActiveFloorMap(floorMap)
        local startX, startY = GetDungeonStart()

        floorSetup = GenerateFloorSetup(
            self.FloorGenerator,
            self.EnemyGenerator,
            run.runLevel or run.snapshot.level or 1,
            floorNumber,
            run.gearPressure or {},
            floorMap
        )

        run.floor = floorNumber
        run.floorMap = floorMap
        run.roomRoleCounts = CopyTable(floorMap.roomRoleCounts or {})
        run.roomStates = BuildInitialRoomStates(floorMap)
        run.chestLoot = BuildFloorChestLoot(floorMap)
        run.playerX = startX
        run.playerY = startY
        run.openedChests = {}
        run.openDoors = {}
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
            string.format("FLOOR %d - PLAYER TURN", floorNumber)
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

    run.active = false
    run.completed = true
    self:CloseShrineChoice()
    self:CloseAbilityPanel()

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

    if self.CharacterSheetFrame then
        self.CharacterSheetFrame:Hide()
    end
    self:CancelCharacterItemDrag()

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

function GA:AdvanceDungeonFloor()
    local run = self.RunState
    if not run or not run.active then
        return
    end

    local clearedFloor = run.floor or 1

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

function GA:RunEnemyTurn()
    local run = self.RunState
    if not run or not run.active or not run.enemies then
        self:RefreshActionButtons()
        return
    end

    local stats = run.arcadeStats or {}
    run.enemyPhase = (run.enemyPhase or 0) + 1
    local enemyPhase = run.enemyPhase

    for _, enemy in ipairs(run.enemies) do
        if enemy.alive ~= false and run.active then
            local feared = enemy.statuses and enemy.statuses.feared
            if feared and (feared.turns or 0) > 0 then
                enemy.intent = "FEARED"
                if self:IsDungeonCellVisible(enemy.x, enemy.y) then
                    self:AddCombatLog(
                        "The feared " .. string.lower(GetEnemyDisplayName(enemy)) .. " loses its action.",
                        "enemy"
                    )
                end
            elseif enemy.skipTurn then
                enemy.intent = "STAGGERED"
                enemy.skipTurn = false

                if self:IsDungeonCellVisible(enemy.x, enemy.y) then
                    self:AddCombatLog(
                        "The staggered " .. string.lower(GetEnemyDisplayName(enemy)) .. " loses its turn.",
                        "enemy"
                    )
                end
            else
                local seesPlayer = IsWithinRadius(
                    enemy.x,
                    enemy.y,
                    run.playerX,
                    run.playerY,
                    enemy.visionRadius or 6
                ) and HasLineOfSight(enemy.x, enemy.y, run.playerX, run.playerY)

                if seesPlayer and not enemy.alerted then
                    enemy.alerted = true
                    enemy.intent = "ALERTED"

                    if self:IsDungeonCellVisible(enemy.x, enemy.y) then
                        self:AddCombatLog(
                            "The " .. string.lower(GetEnemyDisplayName(enemy)) .. " spots you!",
                            "enemy"
                        )
                    end
                end

                if IsAdjacent(enemy.x, enemy.y, run.playerX, run.playerY) then
                    enemy.intent = "ATTACKING"
                    run.activeEnemyId = run.activeEnemyId or enemy.uid

                    local dodgeChance = stats.dodge or 0
                    local dodged = dodgeChance > 0
                        and math.random(1, 1000) <= math.floor(dodgeChance * 10)

                    if dodged then
                        run.reactive = run.reactive or {}
                        run.reactive.overpower = { turns = 2 }
                        run.reactive.revenge = { turns = 2 }
                        self:AddCombatLog(
                            "You dodge the " .. string.lower(GetEnemyDisplayName(enemy)) .. "'s attack. Overpower and Revenge are ready.",
                            "player"
                        )
                    else
                        local rawDamage = math.random(
                            enemy.damageMin or 1,
                            enemy.damageMax or enemy.damageMin or 1
                        )

                        local enemyDamageMultiplier = 1
                        local weakened = enemy.statuses and enemy.statuses.weakened
                        if weakened and (weakened.turns or 0) > 0 then
                            enemyDamageMultiplier = enemyDamageMultiplier
                                * (1 - math.max(0, math.min(90, tonumber(weakened.percent) or 0)) / 100)
                        end

                        local disarmed = enemy.statuses and enemy.statuses.disarmed
                        if disarmed and (disarmed.turns or 0) > 0 then
                            enemyDamageMultiplier = enemyDamageMultiplier
                                * (1 - math.max(0, math.min(90, tonumber(disarmed.percent) or 0)) / 100)
                        end

                        if run.stance == "defensive" then
                            local defensive = GetStudioAbilityById("defensive_stance") or {}
                            local reduction = math.max(0, math.min(90, tonumber(defensive.effectValue) or 0))
                            enemyDamageMultiplier = enemyDamageMultiplier * (1 - reduction / 100)
                        elseif run.stance == "berserker" then
                            local berserker = GetStudioAbilityById("berserker_stance") or {}
                            local penalty = math.max(0, tonumber(berserker.secondaryValue) or 0)
                            enemyDamageMultiplier = enemyDamageMultiplier * (1 + penalty / 100)
                        end

                        local shieldWall = run.buffs and run.buffs.shield_wall
                        if shieldWall and (shieldWall.turns or 0) > 0 then
                            enemyDamageMultiplier = enemyDamageMultiplier
                                * (1 - math.max(0, math.min(90, tonumber(shieldWall.reduction) or 0)) / 100)
                        end

                        local recklessness = run.buffs and run.buffs.recklessness
                        if recklessness and (recklessness.turns or 0) > 0 then
                            enemyDamageMultiplier = enemyDamageMultiplier
                                * (1 + math.max(0, tonumber(recklessness.damageTaken) or 0) / 100)
                        end

                        rawDamage = math.max(1, math.floor(rawDamage * enemyDamageMultiplier + 0.5))

                        local armor = stats.armor or 0
                        local mitigation = math.min(0.55, armor / (armor + 100))
                        local damage = math.max(
                            1,
                            math.floor(rawDamage * (1 - mitigation) + 0.5)
                        )

                        local blockChance = stats.block or 0
                        local shieldBlock = run.buffs and run.buffs.shield_block
                        if shieldBlock and (shieldBlock.turns or 0) > 0 then
                            blockChance = math.min(100, blockChance + math.max(0, tonumber(shieldBlock.percent) or 0))
                        end

                        local blocked = blockChance > 0
                            and math.random(1, 1000) <= math.floor(blockChance * 10)

                        if blocked then
                            damage = math.max(1, math.floor(damage * 0.5 + 0.5))
                            run.reactive = run.reactive or {}
                            run.reactive.revenge = { turns = 2 }
                        end

                        run.playerHealth = math.max(
                            0,
                            (run.playerHealth or run.playerMaxHealth or 1) - damage
                        )

                        self:AddCombatLog(
                            string.format(
                                "%s%s hits you for %d damage. (%d/%d HP)",
                                blocked and "BLOCK! " or "",
                                GetEnemyDisplayName(enemy),
                                damage,
                                run.playerHealth,
                                run.playerMaxHealth or run.playerHealth
                            ),
                            "enemy"
                        )

                        self:UpdateRunHealth()

                        local berserkerRage = run.buffs and run.buffs.berserker_rage
                        if run.playerHealth > 0 and berserkerRage and (berserkerRage.turns or 0) > 0 then
                            GainRunResource(run, berserkerRage.resourcePerHit or 0)
                            self:UpdateRunResource()
                        end

                        if run.playerHealth > 0 and run.buffs and run.buffs.retaliation and enemy.alive ~= false then
                            local retaliationAbility = GetStudioAbilityById("retaliation")
                            if retaliationAbility then
                                self:DealRunDamage(enemy, retaliationAbility, { allowWeaponTrait = false })
                            end
                        end

                        if run.playerHealth <= 0 then
                            self:FailDungeonRun(
                                GetEnemyDisplayName(enemy)
                                .. " killed "
                                .. (run.snapshot.name or "your hero")
                                .. "."
                            )
                            return
                        end
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
                        if IsAdjacent(enemy.x, enemy.y, run.playerX, run.playerY) then
                            break
                        end

                        local occupied = BuildOccupiedEnemyCells(run, enemy.uid)
                        local nextX, nextY = FindNextStep(
                            enemy.x,
                            enemy.y,
                            run.playerX,
                            run.playerY,
                            occupied
                        )

                        if not nextX or not nextY
                            or (nextX == run.playerX and nextY == run.playerY)
                            or occupied[CellKey(nextX, nextY)] then
                            break
                        end

                        enemy.x = nextX
                        enemy.y = nextY
                        movedSteps = movedSteps + 1

                        if self:IsDungeonCellVisible(enemy.x, enemy.y) then
                            visibleDuringMove = true
                        end
                    end

                    if movedSteps > 0 then
                        enemy.intent = "MOVING"
                    end

                    if movedSteps > 0 and visibleDuringMove then
                        if enemy.movementPattern == "quick" and movedSteps > 1 then
                            self:AddCombatLog(
                                GetEnemyDisplayName(enemy) .. " scuttles quickly closer.",
                                "enemy"
                            )
                        else
                            self:AddCombatLog(
                                GetEnemyDisplayName(enemy) .. " moves closer.",
                                "enemy"
                            )
                        end
                    end
                else
                    enemy.intent = "IDLE"
                end
            end
        end
    end

    self:AdvanceCombatEffects()
    self:RenderDungeonGrid()

    if self.DungeonRunStateText and run.active then
        local adjacent = GetAdjacentEnemy(run)

        if run.justLeveledUp then
            self.DungeonRunStateText:SetText(
                string.format("LEVEL UP!  %d -> %d", run.justLeveledUp.from or run.runLevel, run.justLeveledUp.to or run.runLevel)
            )
            self.DungeonRunStateText:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
            run.justLeveledUp = nil
        elseif adjacent then
            self.DungeonRunStateText:SetText(
                string.format(
                    "PLAYER TURN - %s %d/%d HP",
                    string.upper(GetEnemyDisplayName(adjacent)),
                    adjacent.hp or 0,
                    adjacent.maxHp or 0
                )
            )
            self.DungeonRunStateText:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
        else
            self.DungeonRunStateText:SetText("PLAYER TURN")
            self.DungeonRunStateText:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
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

    if not self:AddItemToBackpack(loot) then
        self:AddCombatLog("Your backpack is full. The chest remains unopened.", "warning")
        return false
    end

    run.openedChests = run.openedChests or {}
    run.openedChests[key] = true
    run.score = (run.score or 0) + 25

    local marker = GetDungeonMarkers()[key]
    if marker and marker.rewardType == "elite" and marker.roomIndex then
        run.roomStates = run.roomStates or {}
        local state = run.roomStates[marker.roomIndex]
        if state then
            state.eliteRewardClaimed = true
            MarkRoomCleared(run, marker.roomIndex)
        end
    end

    self:AddCombatLog("Chest opened: " .. loot.name .. " added to your backpack.", "system")
    self:AddCombatLog("Press C to open your character sheet.", "system")
    self:RefreshRunCounters()
    self:RenderDungeonGrid()
    return true
end

function GA:CloseShrineChoice()
    if self.DungeonShrineFrame then
        self.DungeonShrineFrame:Hide()
    end
    self.PendingShrineRoomIndex = nil
end

function GA:OpenShrineChoice(roomIndex)
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
        run.score = (run.score or 0) + scoreReward
        self:AddCombatLog(
            string.format("SHRINE - SACRIFICE: -%d HP, +%d score.", cost, scoreReward),
            "system"
        )
    else
        return false
    end

    state.shrineUsed = true
    state.shrineChoice = choice

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
            self.DungeonRunStateText:SetText("PLAYER TURN - DOOR OPENED")
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

    local startX, startY = GetDungeonStart()
    if (run.floor or 1) > 1 and nextX == startX and nextY == startY then
        self:ReturnDungeonFloor()
        return
    end

    if nextX == exitX and nextY == exitY then
        self:AdvanceDungeonFloor()
        return
    end

    local marker = GetDungeonMarkers()[CellKey(nextX, nextY)]
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

        self:RefreshRunWeaponFromEquipment()
        self:RecalculateRunGearStats()

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
