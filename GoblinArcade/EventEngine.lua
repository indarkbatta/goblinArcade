local _, GA = ...

GA.EventEngine = GA.EventEngine or {}
local EE = GA.EventEngine

EE.VERSION = 1

local function AsList(value)
    return type(value) == "table" and value or {}
end

local function NormalizeId(value)
    return string.lower(tostring(value or ""))
end

local function GetItemId(item)
    return item and tostring(item.studioItemId or item.id or "") or ""
end

local WEAPON_EQUIP_LOCS = {
    INVTYPE_WEAPON = true,
    INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_2HWEAPON = true,
    INVTYPE_RANGED = true,
    INVTYPE_RANGEDRIGHT = true,
}

function EE:EnsureRunState(run)
    if not run then return nil end
    run.eventFlags = run.eventFlags or {}
    run.eventQueue = run.eventQueue or {}
    return run
end

function EE:CountBackpackItem(run, itemId)
    local target = tostring(itemId or "")
    if target == "" then return 0 end

    local count = 0
    for _, item in pairs(run and run.backpack or {}) do
        if GetItemId(item) == target then
            count = count + math.max(1, math.floor(tonumber(item.stackCount) or 1))
        end
    end
    return count
end

function EE:ConsumeBackpackItem(run, itemId, quantity)
    quantity = math.max(1, math.floor(tonumber(quantity) or 1))
    if self:CountBackpackItem(run, itemId) < quantity then
        return false
    end

    local remaining = quantity
    for slot, item in pairs(run.backpack or {}) do
        if remaining <= 0 then break end
        if GetItemId(item) == tostring(itemId or "") then
            local count = math.max(1, math.floor(tonumber(item.stackCount) or 1))
            local used = math.min(count, remaining)
            count = count - used
            remaining = remaining - used
            if count <= 0 then
                run.backpack[slot] = nil
            else
                item.stackCount = count
            end
        end
    end

    return remaining <= 0
end

function EE:HasRequiredGear(run, gearType)
    local required = string.upper(tostring(gearType or "NONE"))
    if required == "" or required == "NONE" then return true end

    for _, item in pairs(run and run.equipment or {}) do
        local equipLoc = string.upper(tostring(item and item.equipLoc or ""))
        local category = string.upper(tostring(item and item.category or item and item.itemType or ""))
        local subtype = string.upper(tostring(item and item.itemSubType or ""))

        if required == "SHIELD" and equipLoc == "INVTYPE_SHIELD" then return true end
        if required == "TWO_HAND" and equipLoc == "INVTYPE_2HWEAPON" then return true end
        if required == "ONE_HAND"
            and (equipLoc == "INVTYPE_WEAPON"
                or equipLoc == "INVTYPE_WEAPONMAINHAND"
                or equipLoc == "INVTYPE_WEAPONOFFHAND") then
            return true
        end
        if required == "WEAPON" and WEAPON_EQUIP_LOCS[equipLoc] then return true end
        if required == "ARMOR" and category == "ARMOR" then return true end
        if (required == "PLATE" or required == "MAIL" or required == "LEATHER" or required == "CLOTH")
            and string.find(subtype, required, 1, true) then
            return true
        end
    end

    return false
end

local function ContainsNormalized(values, needle)
    needle = NormalizeId(needle)
    for _, value in ipairs(AsList(values)) do
        if NormalizeId(value) == needle then return true end
    end
    return false
end

local function HpPercent(run)
    local maximum = math.max(1, tonumber(run and run.playerMaxHealth) or 1)
    local current = math.max(0, tonumber(run and run.playerHealth) or 0)
    return (current / maximum) * 100
end

local function HpCostAmount(run, option)
    local percent = math.max(0, tonumber(option and option.costHpPercent) or 0)
    if percent <= 0 then return 0 end
    return math.max(1, math.floor((math.max(1, tonumber(run.playerMaxHealth) or 1) * percent / 100) + 0.5))
end

function EE:EvaluateOption(run, option, ignoreCosts)
    if not run or not option then
        return false, { "Invalid event option." }
    end
    self:EnsureRunState(run)

    local reasons = {}
    local floor = math.max(1, math.floor(tonumber(run.floor) or 1))
    local minFloor = math.max(0, math.floor(tonumber(option.requiredMinFloor) or 0))
    local maxFloor = math.max(0, math.floor(tonumber(option.requiredMaxFloor) or 0))
    local minHp = math.max(0, tonumber(option.minHpPercent) or 0)
    local requiredCopper = math.max(0, math.floor(tonumber(option.requiredCopper) or 0))
    local itemQty = math.max(1, math.floor(tonumber(option.requiredItemQuantity) or 1))

    if minFloor > 0 and floor < minFloor then
        reasons[#reasons + 1] = "Requires Floor " .. tostring(minFloor) .. "+."
    end
    if maxFloor > 0 and floor > maxFloor then
        reasons[#reasons + 1] = "Only available through Floor " .. tostring(maxFloor) .. "."
    end
    if minHp > 0 and HpPercent(run) + 0.0001 < minHp then
        reasons[#reasons + 1] = string.format("Requires at least %.0f%% current HP.", minHp)
    end

    local classes = AsList(option.requiredClassIds)
    if #classes > 0 and not ContainsNormalized(classes, run.classId) then
        reasons[#reasons + 1] = "Your class cannot use this option."
    end

    local gearType = string.upper(tostring(option.requiredGearType or "NONE"))
    if gearType ~= "" and gearType ~= "NONE" and not self:HasRequiredGear(run, gearType) then
        reasons[#reasons + 1] = "Requires equipped " .. string.gsub(gearType, "_", " ") .. "."
    end

    if requiredCopper > 0 and (tonumber(run.copper) or 0) < requiredCopper then
        reasons[#reasons + 1] = "Requires " .. tostring(requiredCopper) .. " Copper."
    end

    for _, itemId in ipairs(AsList(option.requiredItemIds)) do
        if self:CountBackpackItem(run, itemId) < itemQty then
            reasons[#reasons + 1] = "Requires " .. tostring(itemQty) .. "x " .. tostring(itemId) .. " in backpack."
        end
    end

    for _, flagId in ipairs(AsList(option.requiredFlagIds)) do
        if not run.eventFlags[tostring(flagId)] then
            reasons[#reasons + 1] = "Requires run flag: " .. tostring(flagId) .. "."
        end
    end
    for _, flagId in ipairs(AsList(option.forbiddenFlagIds)) do
        if run.eventFlags[tostring(flagId)] then
            reasons[#reasons + 1] = "Unavailable after run flag: " .. tostring(flagId) .. "."
        end
    end

    if not ignoreCosts then
        local hpCost = HpCostAmount(run, option)
        if hpCost > 0 and (tonumber(run.playerHealth) or 0) <= hpCost then
            reasons[#reasons + 1] = "Not enough HP to pay the cost safely."
        end

        local copperCost = math.max(0, math.floor(tonumber(option.costCopper) or 0))
        if copperCost > 0 and (tonumber(run.copper) or 0) < copperCost then
            reasons[#reasons + 1] = "Costs " .. tostring(copperCost) .. " Copper."
        end

        local costQty = math.max(1, math.floor(tonumber(option.costItemQuantity) or 1))
        for _, itemId in ipairs(AsList(option.costItemIds)) do
            if self:CountBackpackItem(run, itemId) < costQty then
                reasons[#reasons + 1] = "Costs " .. tostring(costQty) .. "x " .. tostring(itemId) .. "."
            end
        end
    end

    return #reasons == 0, reasons
end

function EE:DescribeCosts(run, option)
    local parts = {}
    local hpCost = HpCostAmount(run or {}, option or {})
    if hpCost > 0 then parts[#parts + 1] = tostring(hpCost) .. " HP" end

    local copper = math.max(0, math.floor(tonumber(option and option.costCopper) or 0))
    if copper > 0 then parts[#parts + 1] = tostring(copper) .. " Copper" end

    local quantity = math.max(1, math.floor(tonumber(option and option.costItemQuantity) or 1))
    for _, itemId in ipairs(AsList(option and option.costItemIds)) do
        parts[#parts + 1] = tostring(quantity) .. "x " .. tostring(itemId)
    end

    if #parts == 0 then return "" end
    return "Cost: " .. table.concat(parts, ", ")
end

function EE:ApplyCosts(run, option)
    local available, reasons = self:EvaluateOption(run, option, false)
    if not available then return false, nil, reasons end

    local result = {
        hp = 0,
        copper = 0,
        items = {},
    }

    local hpCost = HpCostAmount(run, option)
    if hpCost > 0 then
        run.playerHealth = math.max(1, (tonumber(run.playerHealth) or 1) - hpCost)
        result.hp = hpCost
    end

    local copperCost = math.max(0, math.floor(tonumber(option.costCopper) or 0))
    if copperCost > 0 then
        run.copper = math.max(0, (tonumber(run.copper) or 0) - copperCost)
        result.copper = copperCost
        if run.stats then
            run.stats.copperSpent = (run.stats.copperSpent or 0) + copperCost
        end
    end

    local quantity = math.max(1, math.floor(tonumber(option.costItemQuantity) or 1))
    for _, itemId in ipairs(AsList(option.costItemIds)) do
        if not self:ConsumeBackpackItem(run, itemId, quantity) then
            return false, nil, { "Could not consume required event item: " .. tostring(itemId) }
        end
        result.items[#result.items + 1] = { itemId = itemId, quantity = quantity }
    end

    return true, result, {}
end

function EE:ApplyFlagChanges(run, option)
    self:EnsureRunState(run)
    local result = { set = {}, cleared = {} }

    for _, flagId in ipairs(AsList(option and option.clearFlagIds)) do
        flagId = tostring(flagId)
        if flagId ~= "" and run.eventFlags[flagId] then
            run.eventFlags[flagId] = nil
            result.cleared[#result.cleared + 1] = flagId
        end
    end
    for _, flagId in ipairs(AsList(option and option.setFlagIds)) do
        flagId = tostring(flagId)
        if flagId ~= "" then
            run.eventFlags[flagId] = true
            result.set[#result.set + 1] = flagId
        end
    end

    return result
end

function EE:QueueFollowups(run, option, sourceEventId)
    self:EnsureRunState(run)
    local queued = {}
    local delay = math.max(1, math.floor(tonumber(option and option.queueAfterFloors) or 1))
    local earliestFloor = math.max(1, math.floor(tonumber(run.floor) or 1)) + delay

    if earliestFloor > 9 then return queued end

    for _, eventId in ipairs(AsList(option and option.queueEventIds)) do
        eventId = tostring(eventId)
        local exists = false
        for _, entry in ipairs(run.eventQueue) do
            if entry.eventId == eventId then exists = true break end
        end
        if not exists then
            for _, history in ipairs(run.eventHistory or {}) do
                if history.eventId == eventId then exists = true break end
            end
        end

        if eventId ~= "" and not exists then
            run.eventQueue[#run.eventQueue + 1] = {
                eventId = eventId,
                earliestFloor = earliestFloor,
                sourceEventId = sourceEventId,
                sourceOptionId = option and option.id,
            }
            queued[#queued + 1] = eventId
        end
    end

    return queued
end
