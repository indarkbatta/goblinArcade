local _, GA = ...

GA.ForeverRules = GA.ForeverRules or {}
local FR = GA.ForeverRules

FR.VERSION = 1
FR.ID = "FOREVER_CLASSIC_BETA"
FR.STAMINA_HP = 10
FR.INTELLECT_MANA = 15
FR.AGILITY_ARMOR = 2
FR.AP_PER_DPS = 14
FR.DEFENSE_PER_PERCENT = 25
FR.MAX_ARMOR_REDUCTION = 0.75
FR.MAX_RESIST_REDUCTION = 0.75
FR.MELEE_CRIT_MULTIPLIER = 2.0
FR.CRUSHING_MULTIPLIER = 1.5

local CLASS = {
    WARRIOR = { strAP = 2, agiAP = 0, rangedAgiAP = 1, critPerAgi = 20, dodgePerAgi = 20, baseDodge = 3, baseParry = 5, baseBlock = 5, blockFromStrength = true,
        base = { str = 23, agi = 20, sta = 22, int = 10, spi = 15 }, growth = { str = 1.7, agi = 1.0, sta = 1.5, int = 0.2, spi = 0.7 } },
    PALADIN = { strAP = 2, agiAP = 0, rangedAgiAP = 0, critPerAgi = 20, dodgePerAgi = 20, baseDodge = 3, baseParry = 5, baseBlock = 5, blockFromStrength = true,
        base = { str = 22, agi = 17, sta = 22, int = 17, spi = 20 }, growth = { str = 1.5, agi = 0.7, sta = 1.4, int = 0.8, spi = 0.9 } },
    HUNTER = { strAP = 1, agiAP = 1, rangedAgiAP = 2, critPerAgi = 53, dodgePerAgi = 26, baseDodge = 5, baseParry = 5, baseBlock = 0,
        base = { str = 17, agi = 23, sta = 20, int = 19, spi = 20 }, growth = { str = 0.6, agi = 1.7, sta = 1.2, int = 0.8, spi = 0.8 } },
    ROGUE = { strAP = 1, agiAP = 1, rangedAgiAP = 1, critPerAgi = 29, dodgePerAgi = 14.5, baseDodge = 5, baseParry = 5, baseBlock = 0,
        base = { str = 18, agi = 26, sta = 20, int = 10, spi = 15 }, growth = { str = 0.8, agi = 2.0, sta = 1.1, int = 0.2, spi = 0.5 } },
    PRIEST = { strAP = 1, agiAP = 0, rangedAgiAP = 0, critPerAgi = 20, dodgePerAgi = 20, baseDodge = 3, baseParry = 0, baseBlock = 0,
        base = { str = 14, agi = 15, sta = 18, int = 24, spi = 25 }, growth = { str = 0.2, agi = 0.3, sta = 0.8, int = 1.8, spi = 1.8 } },
    SHAMAN = { strAP = 2, agiAP = 0, rangedAgiAP = 0, critPerAgi = 20, dodgePerAgi = 20, baseDodge = 3, baseParry = 5, baseBlock = 5, blockFromStrength = true,
        base = { str = 21, agi = 17, sta = 21, int = 20, spi = 22 }, growth = { str = 1.1, agi = 0.7, sta = 1.2, int = 1.1, spi = 1.1 } },
    MAGE = { strAP = 1, agiAP = 0, rangedAgiAP = 0, critPerAgi = 20, dodgePerAgi = 20, baseDodge = 3, baseParry = 0, baseBlock = 0,
        base = { str = 12, agi = 14, sta = 16, int = 27, spi = 24 }, growth = { str = 0.2, agi = 0.3, sta = 0.7, int = 2.0, spi = 1.5 } },
    WARLOCK = { strAP = 1, agiAP = 0, rangedAgiAP = 0, critPerAgi = 20, dodgePerAgi = 20, baseDodge = 3, baseParry = 0, baseBlock = 0,
        base = { str = 13, agi = 14, sta = 20, int = 25, spi = 22 }, growth = { str = 0.2, agi = 0.3, sta = 1.1, int = 1.8, spi = 1.3 } },
    DRUID = { strAP = 2, agiAP = 1, rangedAgiAP = 0, critPerAgi = 20, dodgePerAgi = 20, baseDodge = 3, baseParry = 0, baseBlock = 0,
        base = { str = 20, agi = 18, sta = 21, int = 22, spi = 24 }, growth = { str = 1.0, agi = 1.0, sta = 1.2, int = 1.2, spi = 1.2 } },
}

local function Clamp(value, minimum, maximum)
    value = tonumber(value) or 0
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function Round(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

local function ClassProfile(classFile)
    return CLASS[string.upper(tostring(classFile or "WARRIOR"))] or CLASS.WARRIOR
end

function FR:GetWeaponSpeedSeconds(weapon)
    if weapon and tonumber(weapon.weaponSpeedSeconds) then
        return math.max(0.5, tonumber(weapon.weaponSpeedSeconds))
    end
    local key = string.upper(tostring(weapon and weapon.speed or "NORMAL"))
    local speeds = GA.WEAPON_SPEED_SECONDS or { FAST = 1.8, NORMAL = 2.4, SLOW = 3.2 }
    return tonumber(speeds[key]) or 2.4
end

function FR:GetBasePrimaryStats(classFile, level)
    local profile = ClassProfile(classFile)
    local lvl = math.max(1, math.floor(tonumber(level) or 1))
    local steps = lvl - 1
    return {
        strength = Round(profile.base.str + profile.growth.str * steps),
        agility = Round(profile.base.agi + profile.growth.agi * steps),
        stamina = Round(profile.base.sta + profile.growth.sta * steps),
        intellect = Round(profile.base.int + profile.growth.int * steps),
        spirit = Round(profile.base.spi + profile.growth.spi * steps),
    }
end

function FR:CalculateAttackPowerDamageBonus(attackPower, weapon)
    local ap = math.max(0, tonumber(attackPower) or 0)
    if ap <= 0 then return 0 end
    local raw = (ap / FR.AP_PER_DPS) * self:GetWeaponSpeedSeconds(weapon)
    if GA.ScaleCombatValue then
        return GA:ScaleCombatValue(raw, false)
    end
    return math.max(0, Round(raw / 10))
end

function FR:CalculateArmorReduction(armor, attackerLevel)
    local a = math.max(0, tonumber(armor) or 0)
    local level = math.max(1, tonumber(attackerLevel) or 1)
    local denominator = a + 400 + 85 * level
    if denominator <= 0 then return 0 end
    return Clamp(a / denominator, 0, FR.MAX_ARMOR_REDUCTION)
end

function FR:CalculateResistanceReduction(resistance, casterLevel)
    local r = math.max(0, tonumber(resistance) or 0)
    local level = math.max(1, tonumber(casterLevel) or 1)
    return Clamp(0.75 * r / (level * 5), 0, FR.MAX_RESIST_REDUCTION)
end

function FR:BuildDerivedStats(level, classFile, gear)
    gear = gear or {}
    local profile = ClassProfile(classFile)
    local base = self:GetBasePrimaryStats(classFile, level)

    local strength = base.strength + math.max(0, tonumber(gear.strength) or 0)
    local agility = base.agility + math.max(0, tonumber(gear.agility) or 0)
    local stamina = base.stamina + math.max(0, tonumber(gear.stamina) or 0)
    local intellect = base.intellect + math.max(0, tonumber(gear.intellect) or 0)
    local spirit = base.spirit + math.max(0, tonumber(gear.spirit) or 0)

    local attackPower = math.max(0,
        (tonumber(gear.attackPower) or 0)
        + strength * (profile.strAP or 1)
        + agility * (profile.agiAP or 0)
    )
    local rangedAttackPower = math.max(0,
        (tonumber(gear.rangedAttackPower) or 0)
        + agility * (profile.rangedAgiAP or 0)
    )
    local armor = math.max(0, (tonumber(gear.armor) or 0) + agility * FR.AGILITY_ARMOR)
    local crit = math.max(0, (tonumber(gear.crit) or 0) + agility / math.max(1, profile.critPerAgi or 20))
    local dodge = math.max(0, (profile.baseDodge or 0) + (tonumber(gear.dodge) or 0) + agility / math.max(1, profile.dodgePerAgi or 20))
    local parry = math.max(0, (profile.baseParry or 0) + (tonumber(gear.parry) or 0))
    local hasShield = gear.hasShield == true
    local block = hasShield and math.max(0, (profile.baseBlock or 0) + (tonumber(gear.block) or 0)) or 0
    local blockValue = hasShield and math.max(0, tonumber(gear.blockValue) or 0) or 0
    if hasShield and profile.blockFromStrength then
        blockValue = blockValue + strength / 20
    end

    local gearStamina = math.max(0, tonumber(gear.stamina) or 0)
    local staminaHealthRaw = gearStamina * FR.STAMINA_HP
    local staminaHealth = GA.ScaleCombatValue and GA:ScaleCombatValue(staminaHealthRaw, false) or Round(staminaHealthRaw / 10)
    local healingPower = math.max(0, tonumber(gear.healingPower) or 0)
    local spellPower = math.max(0, tonumber(gear.spellPower) or 0) + healingPower / 3

    local lvl = math.max(1, math.floor(tonumber(level) or 1))
    return {
        ruleset = FR.ID,
        strength = strength,
        agility = agility,
        stamina = stamina,
        intellect = intellect,
        spirit = spirit,
        health = math.max(0, tonumber(gear.directHealth) or 0) + staminaHealth,
        maxMana = intellect * FR.INTELLECT_MANA,
        armor = armor,
        attackPower = attackPower,
        rangedAttackPower = rangedAttackPower,
        hit = math.max(0, tonumber(gear.hit) or 0),
        crit = crit,
        expertise = math.max(0, tonumber(gear.expertise) or 0),
        defense = math.max(0, tonumber(gear.defense) or 0),
        defenseSkill = lvl * 5 + math.max(0, tonumber(gear.defense) or 0),
        weaponSkill = lvl * 5 + math.max(0, tonumber(gear.weaponSkill) or 0),
        dodge = dodge,
        parry = parry,
        block = block,
        blockValue = blockValue,
        spellPower = spellPower,
        healingPower = healingPower,
        mp5 = math.max(0, tonumber(gear.mp5) or 0),
        hasShield = hasShield,
        arcaneResistance = math.max(0, tonumber(gear.arcaneResistance) or 0),
        fireResistance = math.max(0, tonumber(gear.fireResistance) or 0),
        frostResistance = math.max(0, tonumber(gear.frostResistance) or 0),
        natureResistance = math.max(0, tonumber(gear.natureResistance) or 0),
        shadowResistance = math.max(0, tonumber(gear.shadowResistance) or 0),
    }
end

function FR:BuildEnemyCombatStats(enemy)
    enemy = enemy or {}
    local level = math.max(1, math.floor(tonumber(enemy.level) or 1))
    local danger = math.max(1, tonumber(enemy.dangerRating) or 1)
    local id = string.lower(tostring(enemy.id or enemy.archetype or ""))
    local rank = string.lower(tostring(enemy.rank or "normal"))
    local rankArmor = rank == "boss" and 1.35 or rank == "elite" and 1.20 or rank == "veteran" and 1.10 or 1.00
    local armor = tonumber(enemy.armor)
    if not armor then
        armor = Round((20 + level * 18 + danger * 12) * rankArmor)
    end
    local isSpider = string.find(id, "spider", 1, true) ~= nil
    local isSentinel = string.find(id, "sentinel", 1, true) ~= nil
    return {
        level = level,
        weaponSkill = tonumber(enemy.weaponSkill) or level * 5,
        defenseSkill = tonumber(enemy.defenseSkill) or level * 5,
        armor = math.max(0, armor),
        hit = math.max(0, tonumber(enemy.hit) or 0),
        crit = math.max(0, tonumber(enemy.crit) or 5),
        expertise = math.max(0, tonumber(enemy.expertise) or 0),
        dodge = math.max(0, tonumber(enemy.dodge) or (isSpider and 8 or 5)),
        parry = math.max(0, tonumber(enemy.parry) or (isSpider and 0 or 5)),
        block = math.max(0, tonumber(enemy.block) or (isSentinel and 10 or 0)),
        blockValue = math.max(0, tonumber(enemy.blockValue) or (isSentinel and math.max(1, Round(level / 4)) or 0)),
    }
end

local function RollPercent()
    return math.random(1, 10000) / 100
end

function FR:ResolvePlayerMeleeAttack(playerStats, enemy, weapon, ability)
    playerStats = playerStats or {}
    local defender = self:BuildEnemyCombatStats(enemy)
    local level = math.max(1, tonumber(playerStats.level) or tonumber(enemy and enemy.playerLevel) or 1)
    local weaponSkill = tonumber(playerStats.weaponSkill) or level * 5
    local diff = defender.defenseSkill - weaponSkill
    local positiveDiff = math.max(0, diff)

    local miss = Clamp(5 + positiveDiff * 0.20 - (tonumber(playerStats.hit) or 0), 0, 100)
    local dodge = Clamp(defender.dodge + positiveDiff * 0.04 - (tonumber(playerStats.expertise) or 0), 0, 100)
    local parry = Clamp(defender.parry + positiveDiff * 0.04 - (tonumber(playerStats.expertise) or 0), 0, 100)
    local block = Clamp(defender.block, 0, 100)
    if ability and tostring(ability.id) == "overpower" then
        dodge, parry = 0, 0
    end
    local glancing = ability and 0 or Clamp(10 + positiveDiff * 2, 0, 40)
    local crit = Clamp((tonumber(playerStats.crit) or 0) - positiveDiff * 0.04, 0, 100)

    local roll = RollPercent()
    local cursor = miss
    if roll <= cursor then return { kind = "MISS", multiplier = 0, roll = roll } end
    cursor = cursor + dodge
    if roll <= cursor then return { kind = "DODGE", multiplier = 0, roll = roll } end
    cursor = cursor + parry
    if roll <= cursor then return { kind = "PARRY", multiplier = 0, roll = roll } end
    cursor = cursor + glancing
    if roll <= cursor then
        return { kind = "GLANCING", multiplier = Clamp(1 - positiveDiff * 0.02, 0.65, 0.95), roll = roll, glancing = true }
    end
    cursor = cursor + block
    if roll <= cursor then return { kind = "BLOCK", multiplier = 1, roll = roll, blocked = true, blockValue = defender.blockValue } end
    cursor = cursor + crit
    if roll <= cursor then return { kind = "CRIT", multiplier = FR.MELEE_CRIT_MULTIPLIER, roll = roll, critical = true } end
    return { kind = "HIT", multiplier = 1, roll = roll }
end

function FR:ResolveEnemyMeleeAttack(enemy, playerStats)
    playerStats = playerStats or {}
    local attacker = self:BuildEnemyCombatStats(enemy)
    local defenseSkill = tonumber(playerStats.defenseSkill) or math.max(1, tonumber(playerStats.level) or 1) * 5
    local skillDiff = attacker.weaponSkill - defenseSkill
    local positiveDiff = math.max(0, skillDiff)

    local miss = Clamp(5 - skillDiff * 0.04, 0, 100)
    local dodge = Clamp((tonumber(playerStats.dodge) or 0) - positiveDiff * 0.04, 0, 100)
    local parry = Clamp((tonumber(playerStats.parry) or 0) - positiveDiff * 0.04, 0, 100)
    local block = playerStats.hasShield and Clamp((tonumber(playerStats.block) or 0) - positiveDiff * 0.04, 0, 100) or 0
    local crit = Clamp(5 + skillDiff * 0.04, 0, 100)
    local crushing = skillDiff >= 15 and Clamp(15 + (skillDiff - 15) * 2, 0, 25) or 0

    local roll = RollPercent()
    local cursor = miss
    if roll <= cursor then return { kind = "MISS", multiplier = 0, roll = roll } end
    cursor = cursor + dodge
    if roll <= cursor then return { kind = "DODGE", multiplier = 0, roll = roll } end
    cursor = cursor + parry
    if roll <= cursor then return { kind = "PARRY", multiplier = 0, roll = roll } end
    cursor = cursor + block
    if roll <= cursor then return { kind = "BLOCK", multiplier = 1, roll = roll, blocked = true, blockValue = tonumber(playerStats.blockValue) or 0 } end
    cursor = cursor + crit
    if roll <= cursor then return { kind = "CRIT", multiplier = FR.MELEE_CRIT_MULTIPLIER, roll = roll, critical = true } end
    cursor = cursor + crushing
    if roll <= cursor then return { kind = "CRUSHING", multiplier = FR.CRUSHING_MULTIPLIER, roll = roll, crushing = true } end
    return { kind = "HIT", multiplier = 1, roll = roll }
end

function FR:ApplyPhysicalMitigation(rawDamage, armor, attackerLevel, outcome)
    local raw = math.max(0, tonumber(rawDamage) or 0)
    outcome = outcome or { kind = "HIT", multiplier = 1 }
    if (tonumber(outcome.multiplier) or 0) <= 0 then return 0, 0 end
    raw = raw * (tonumber(outcome.multiplier) or 1)
    local reduction = self:CalculateArmorReduction(armor, attackerLevel)
    local damage = math.max(0, Round(raw * (1 - reduction)))
    if outcome.blocked then
        damage = math.max(0, damage - math.max(0, Round(outcome.blockValue or 0)))
    end
    if damage <= 0 and not outcome.blocked then damage = 1 end
    return damage, reduction
end

function FR:CalculateRageFromSwing(weapon, outcome)
    outcome = outcome or {}
    if outcome.kind == "MISS" or outcome.kind == "DODGE" or outcome.kind == "PARRY" then
        return 0
    end
    local speed = self:GetWeaponSpeedSeconds(weapon)
    local handed = string.upper(tostring(weapon and weapon.handedness or ""))
    local twoHand = handed == "TWO-HANDED" or handed == "TWO_HANDED"
    local rage = speed * (twoHand and 4.5 or 3.4)
    return math.max(1, Round(rage))
end

function FR:FormatOutcome(outcome)
    return outcome and tostring(outcome.kind or "HIT") or "HIT"
end
