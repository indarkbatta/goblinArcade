#!/usr/bin/env lua5.1

local GA = {}
local chunk = assert(loadfile("GoblinArcade/EventEngine.lua"))
chunk("GoblinArcade", GA)
local EE = assert(GA.EventEngine)
assert(EE.VERSION == 1, "Unexpected EventEngine version")

local run = {
    floor = 3,
    classId = "warrior",
    playerHealth = 80,
    playerMaxHealth = 100,
    copper = 200,
    equipment = {
        offhand = { equipLoc = "INVTYPE_SHIELD", itemSubType = "Shield", category = "SHIELD" },
    },
    backpack = {
        [1] = { studioItemId = "key_fragment", stackCount = 2 },
    },
    eventFlags = { met_old_goblin = true },
    eventQueue = {},
    eventHistory = {},
    stats = { copperSpent = 0 },
}

local option = {
    id = "audit_choice",
    requiredMinFloor = 3,
    requiredMaxFloor = 8,
    minHpPercent = 50,
    requiredClassIds = { "warrior" },
    requiredGearType = "SHIELD",
    requiredCopper = 100,
    requiredItemIds = { "key_fragment" },
    requiredItemQuantity = 1,
    requiredFlagIds = { "met_old_goblin" },
    forbiddenFlagIds = {},
    costHpPercent = 10,
    costCopper = 50,
    costItemIds = { "key_fragment" },
    costItemQuantity = 1,
    setFlagIds = { "helped_goblin" },
    clearFlagIds = { "met_old_goblin" },
    queueEventIds = { "smugglers" },
    queueAfterFloors = 2,
}

local available, reasons = EE:EvaluateOption(run, option, false)
assert(available and #reasons == 0, "Valid option was rejected")

local paid, cost = EE:ApplyCosts(run, option)
assert(paid, "Event costs failed")
assert(run.playerHealth == 70, "HP cost mismatch")
assert(run.copper == 150 and run.stats.copperSpent == 50, "Copper cost mismatch")
assert(EE:CountBackpackItem(run, "key_fragment") == 1, "Item cost mismatch")
assert(cost.hp == 10 and cost.copper == 50, "Cost metadata mismatch")

local flags = EE:ApplyFlagChanges(run, option)
assert(run.eventFlags.helped_goblin == true and run.eventFlags.met_old_goblin == nil, "Flag mutation failed")
assert(#flags.set == 1 and #flags.cleared == 1, "Flag metadata mismatch")

local queued = EE:QueueFollowups(run, option, "wounded_goblin")
assert(#queued == 1 and #run.eventQueue == 1, "Follow-up was not queued")
assert(run.eventQueue[1].eventId == "smugglers" and run.eventQueue[1].earliestFloor == 5, "Follow-up scheduling mismatch")
EE:QueueFollowups(run, option, "wounded_goblin")
assert(#run.eventQueue == 1, "Duplicate follow-up queue entry created")

local flagAvailable = EE:EvaluateOption(run, option, true)
assert(flagAvailable == false, "Cleared required flag did not lock the option")

local forbidden = {
    requiredGearType = "NONE",
    forbiddenFlagIds = { "helped_goblin" },
}
local forbiddenAvailable = EE:EvaluateOption(run, forbidden, true)
assert(forbiddenAvailable == false, "Forbidden flag did not lock the option")

print("Event logic audit OK: requirements, gear, item/copper/HP costs, flags and follow-up queue.")
