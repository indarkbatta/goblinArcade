local _, GA = ...

GA.FloorGenerator = GA.FloorGenerator or {}
local FG = GA.FloorGenerator

FG.VERSION = 4

local DENSITY_PROFILES = {
    {
        key = "QUIET",
        multiplier = 0.90,
        minRoll = 1,
        maxRoll = 20,
    },
    {
        key = "STANDARD",
        multiplier = 1.00,
        minRoll = 21,
        maxRoll = 80,
    },
    {
        key = "CROWDED",
        multiplier = 1.10,
        minRoll = 81,
        maxRoll = 100,
    },
}

local ARCHETYPE_MIXES = {
    {
        minFloor = 1,
        maxFloor = 2,
        weights = {
            kobold = 80,
            spider = 20,
            skeleton = 0,
        },
    },
    {
        minFloor = 3,
        maxFloor = 4,
        weights = {
            kobold = 60,
            spider = 30,
            skeleton = 10,
        },
    },
    {
        minFloor = 5,
        maxFloor = 6,
        weights = {
            kobold = 45,
            spider = 30,
            skeleton = 25,
        },
    },
    {
        minFloor = 7,
        maxFloor = 8,
        weights = {
            kobold = 35,
            spider = 30,
            skeleton = 35,
        },
    },
    {
        minFloor = 9,
        maxFloor = 9,
        weights = {
            kobold = 25,
            spider = 25,
            skeleton = 50,
        },
    },
}

local ARCHETYPE_ORDER = {
    "kobold",
    "spider",
    "skeleton",
}

local RANK_MIXES = {
    {
        minFloor = 1,
        maxFloor = 2,
        weights = {
            normal = 100,
            veteran = 0,
            elite = 0,
        },
    },
    {
        minFloor = 3,
        maxFloor = 4,
        weights = {
            normal = 80,
            veteran = 20,
            elite = 0,
        },
    },
    {
        minFloor = 5,
        maxFloor = 6,
        weights = {
            normal = 75,
            veteran = 25,
            elite = 0,
        },
    },
    {
        minFloor = 7,
        maxFloor = 8,
        weights = {
            normal = 60,
            veteran = 30,
            elite = 10,
        },
    },
    {
        minFloor = 9,
        maxFloor = 9,
        weights = {
            normal = 45,
            veteran = 35,
            elite = 20,
        },
    },
}

local RANK_ORDER = {
    "normal",
    "veteran",
    "elite",
}

local function Round(value)
    return math.floor(value + 0.5)
end

local function Shuffle(values)
    for index = #values, 2, -1 do
        local swapIndex = math.random(1, index)
        values[index], values[swapIndex] = values[swapIndex], values[index]
    end
end

local function GetMixForFloor(floor)
    local floorNumber = math.max(1, tonumber(floor) or 1)

    for _, mix in ipairs(ARCHETYPE_MIXES) do
        if floorNumber >= mix.minFloor and floorNumber <= mix.maxFloor then
            return mix.weights
        end
    end

    return ARCHETYPE_MIXES[#ARCHETYPE_MIXES].weights
end

local function GetRankMixForFloor(floor)
    local floorNumber = math.max(1, tonumber(floor) or 1)

    for _, mix in ipairs(RANK_MIXES) do
        if floorNumber >= mix.minFloor and floorNumber <= mix.maxFloor then
            return mix.weights
        end
    end

    return RANK_MIXES[#RANK_MIXES].weights
end

function FG:RollDensityProfile()
    local roll = math.random(1, 100)

    for _, profile in ipairs(DENSITY_PROFILES) do
        if roll >= profile.minRoll and roll <= profile.maxRoll then
            return {
                key = profile.key,
                multiplier = profile.multiplier,
                roll = roll,
            }
        end
    end

    return {
        key = "STANDARD",
        multiplier = 1.00,
        roll = roll,
    }
end

local FLOOR_BASE_ENEMY_COUNT = {
    [1] = 6,
    [2] = 6,
    [3] = 7,
    [4] = 7,
    [5] = 8,
    [6] = 8,
    [7] = 9,
    [8] = 9,
    [9] = 10,
}

function FG:CalculateBaseEnemyCount(walkableTiles, floor)
    local floorNumber = math.max(1, math.floor(tonumber(floor) or 1))
    local base = FLOOR_BASE_ENEMY_COUNT[math.min(9, floorNumber)]
        or FLOOR_BASE_ENEMY_COUNT[9]

    -- The current dungeon footprint is fixed at 25x25. Keep encounter count
    -- tied to depth rather than room/corridor RNG so two layouts on the same
    -- floor remain in the same difficulty band. walkableTiles stays in the
    -- signature for future map-size scaling.
    return base
end

function FG:CalculateEnemyCount(walkableTiles, floor, densityProfile)
    local baseCount = self:CalculateBaseEnemyCount(walkableTiles, floor)
    local multiplier = densityProfile and densityProfile.multiplier or 1.00

    return math.max(1, Round(baseCount * multiplier)), baseCount
end


function FG:GetArchetypeWeights(floor)
    local weights = GetMixForFloor(floor)

    return {
        kobold = weights.kobold or 0,
        spider = weights.spider or 0,
        skeleton = weights.skeleton or 0,
    }
end

function FG:CreateArchetypePlan(enemyCount, floor)
    local count = math.max(1, tonumber(enemyCount) or 1)
    local weights = GetMixForFloor(floor)
    local counts = {}
    local remainders = {}
    local assigned = 0

    for _, archetype in ipairs(ARCHETYPE_ORDER) do
        local raw = count * ((weights[archetype] or 0) / 100)
        local whole = math.floor(raw)

        counts[archetype] = whole
        assigned = assigned + whole
        remainders[#remainders + 1] = {
            archetype = archetype,
            remainder = raw - whole,
        }
    end

    table.sort(remainders, function(a, b)
        if a.remainder == b.remainder then
            return a.archetype < b.archetype
        end
        return a.remainder > b.remainder
    end)

    local remaining = count - assigned
    local index = 1

    while remaining > 0 do
        local target = remainders[index]
        counts[target.archetype] = (counts[target.archetype] or 0) + 1
        remaining = remaining - 1
        index = index + 1

        if index > #remainders then
            index = 1
        end
    end

    local plan = {}

    for _, archetype in ipairs(ARCHETYPE_ORDER) do
        for _ = 1, counts[archetype] or 0 do
            plan[#plan + 1] = archetype
        end
    end

    Shuffle(plan)
    return plan, counts
end


function FG:GetRankWeights(floor)
    local weights = GetRankMixForFloor(floor)

    return {
        normal = weights.normal or 0,
        veteran = weights.veteran or 0,
        elite = weights.elite or 0,
    }
end

function FG:CreateRankPlan(enemyCount, floor)
    local count = math.max(1, tonumber(enemyCount) or 1)
    local weights = GetRankMixForFloor(floor)
    local counts = {}
    local remainders = {}
    local assigned = 0

    for orderIndex, rank in ipairs(RANK_ORDER) do
        local raw = count * ((weights[rank] or 0) / 100)
        local whole = math.floor(raw)

        counts[rank] = whole
        assigned = assigned + whole
        remainders[#remainders + 1] = {
            rank = rank,
            orderIndex = orderIndex,
            remainder = raw - whole,
        }
    end

    table.sort(remainders, function(a, b)
        if a.remainder == b.remainder then
            return a.orderIndex < b.orderIndex
        end
        return a.remainder > b.remainder
    end)

    local remaining = count - assigned
    local index = 1

    while remaining > 0 do
        local target = remainders[index]
        counts[target.rank] = (counts[target.rank] or 0) + 1
        remaining = remaining - 1
        index = index + 1

        if index > #remainders then
            index = 1
        end
    end

    local plan = {}

    for _, rank in ipairs(RANK_ORDER) do
        for _ = 1, counts[rank] or 0 do
            plan[#plan + 1] = rank
        end
    end

    Shuffle(plan)
    return plan, counts
end
