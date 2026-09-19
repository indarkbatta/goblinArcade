local _, GA = ...

GA.FloorGenerator = GA.FloorGenerator or {}
local FG = GA.FloorGenerator

FG.VERSION = 1

local DENSITY_PROFILES = {
    {
        key = "QUIET",
        multiplier = 0.85,
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
        multiplier = 1.15,
        minRoll = 81,
        maxRoll = 100,
    },
}

local function Round(value)
    return math.floor(value + 0.5)
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

function FG:CalculateBaseEnemyCount(walkableTiles, floor)
    local walkable = math.max(1, tonumber(walkableTiles) or 1)
    local floorNumber = math.max(1, tonumber(floor) or 1)

    return math.max(1, Round(
        (walkable / 70)
        * (1 + 0.05 * (floorNumber - 1))
    ))
end

function FG:CalculateEnemyCount(walkableTiles, floor, densityProfile)
    local baseCount = self:CalculateBaseEnemyCount(walkableTiles, floor)
    local multiplier = densityProfile and densityProfile.multiplier or 1.00

    return math.max(1, Round(baseCount * multiplier)), baseCount
end
