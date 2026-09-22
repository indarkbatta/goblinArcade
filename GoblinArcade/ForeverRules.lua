local _, GA = ...

GA.ForeverRules = GA.ForeverRules or {}
local FR = GA.ForeverRules

FR.VERSION = 3
FR.ID = "FOREVER_CLASSIC_BETA_V3"
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
    WARRIOR = {
        strAP = 2, agiAP = 0, rangedAgiAP = 1,
        meleeApPerLevel = 3, meleeApOffset = -20,
        rangedApPerLevel = 1, rangedApOffset = -10,
        critPerAgi = 20, dodgePerAgi = 20,
        baseDodge = 3, baseParry = 5, baseBlock = 5,
        healthPerStaminaFirst20 = 1, healthPerStaminaAfter20 = 10,
        manaPerIntellect = 15, armorPerAgility = 2, blockValuePerStrength = 0.05,
        defenseSkillPerLevel = 5, weaponSkillPerLevel = 5,
        referenceWeaponBaseDamage = 1.5, referenceWeaponSpeedSeconds = 2.4,
        base = { hp = 20, mana = 0, str = 23, agi = 20, sta = 22, int = 20, spi = 20 },
        growth = { hp = 28.29, mana = 0, str = 1.65, agi = 1.02, sta = 1.49, int = 0.17, spi = 0.42 },
    },
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

local LEVEL_TABLE_CACHE = {}

local function GetStudioClass(classFile)
    local wanted = string.lower(tostring(classFile or "warrior"))
    for _, record in ipairs(GA.StudioData and GA.StudioData.classes or {}) do
        if string.lower(tostring(record.id or "")) == wanted then
            return record
        end
    end
    return nil
end

local function GetStudioRace(raceId)
    local wanted = string.lower(tostring(raceId or ""))
    if wanted == "" then return nil end
    for _, record in ipairs(GA.StudioData and GA.StudioData.races or {}) do
        if string.lower(tostring(record.id or "")) == wanted then
            return record
        end
    end
    return nil
end

local function ApplyRaceOffsets(row, raceId)
    local race = GetStudioRace(raceId)
    if not race then return row end
    return {
        level = row.level,
        baseHealth = row.baseHealth,
        baseMana = row.baseMana,
        strength = math.max(0, (row.strength or 0) + (tonumber(race.strengthOffset) or 0)),
        agility = math.max(0, (row.agility or 0) + (tonumber(race.agilityOffset) or 0)),
        stamina = math.max(0, (row.stamina or 0) + (tonumber(race.staminaOffset) or 0)),
        intellect = math.max(0, (row.intellect or 0) + (tonumber(race.intellectOffset) or 0)),
        spirit = math.max(0, (row.spirit or 0) + (tonumber(race.spiritOffset) or 0)),
        raceId = race.id,
        raceStatOffsetModel = race.statOffsetModel,
    }
end

local function ParseLevelTable(record)
    if not record then return nil end
    local cacheKey = tostring(record.id or "")
    local source = tostring(record.levelStatTable or "")
    local cached = LEVEL_TABLE_CACHE[cacheKey]
    if cached and cached.source == source then return cached.rows end

    local rows = {}
    for line in string.gmatch(source .. "\n", "([^\n]*)\n") do
        if string.match(line, "%S") then
            local values = {}
            for token in string.gmatch(line, "[^,]+") do
                values[#values + 1] = tonumber((token:gsub("^%s*(.-)%s*$", "%1")))
            end
            if #values == 8 and values[1] then
                local lvl = math.max(1, math.floor(values[1]))
                rows[lvl] = {
                    level = lvl,
                    baseHealth = values[2] or 0,
                    baseMana = values[3] or 0,
                    strength = values[4] or 0,
                    agility = values[5] or 0,
                    stamina = values[6] or 0,
                    intellect = values[7] or 0,
                    spirit = values[8] or 0,
                }
            end
        end
    end
    LEVEL_TABLE_CACHE[cacheKey] = { source = source, rows = rows }
    return rows
end

local function ClassProfile(classFile)
    local fallback = CLASS[string.upper(tostring(classFile or "WARRIOR"))] or CLASS.WARRIOR
    local studio = GetStudioClass(classFile)
    if not studio then return fallback end
    return {
        strAP = tonumber(studio.meleeApPerStrength) or fallback.strAP or 1,
        agiAP = tonumber(studio.meleeApPerAgility) or fallback.agiAP or 0,
        rangedAgiAP = tonumber(studio.rangedApPerAgility) or fallback.rangedAgiAP or 0,
        meleeApPerLevel = tonumber(studio.meleeApPerLevel) or fallback.meleeApPerLevel or 0,
        meleeApOffset = tonumber(studio.meleeApOffset) or fallback.meleeApOffset or 0,
        rangedApPerLevel = tonumber(studio.rangedApPerLevel) or fallback.rangedApPerLevel or 0,
        rangedApOffset = tonumber(studio.rangedApOffset) or fallback.rangedApOffset or 0,
        critPerAgi = tonumber(studio.critAgiPerPercent) or fallback.critPerAgi or 20,
        dodgePerAgi = tonumber(studio.dodgeAgiPerPercent) or fallback.dodgePerAgi or 20,
        baseDodge = tonumber(studio.baseDodge) or fallback.baseDodge or 0,
        baseParry = tonumber(studio.baseParry) or fallback.baseParry or 0,
        baseBlock = tonumber(studio.baseBlock) or fallback.baseBlock or 0,
        healthPerStaminaFirst20 = tonumber(studio.healthPerStaminaFirst20) or fallback.healthPerStaminaFirst20 or 1,
        healthPerStaminaAfter20 = tonumber(studio.healthPerStaminaAfter20) or fallback.healthPerStaminaAfter20 or FR.STAMINA_HP,
        manaPerIntellect = tonumber(studio.manaPerIntellect) or fallback.manaPerIntellect or FR.INTELLECT_MANA,
        armorPerAgility = tonumber(studio.armorPerAgility) or fallback.armorPerAgility or FR.AGILITY_ARMOR,
        blockValuePerStrength = tonumber(studio.blockValuePerStrength) or fallback.blockValuePerStrength or 0,
        defenseSkillPerLevel = tonumber(studio.defenseSkillPerLevel) or fallback.defenseSkillPerLevel or 5,
        weaponSkillPerLevel = tonumber(studio.weaponSkillPerLevel) or fallback.weaponSkillPerLevel or 5,
        referenceWeaponBaseDamage = tonumber(studio.referenceWeaponBaseDamage) or fallback.referenceWeaponBaseDamage or 1.5,
        referenceWeaponSpeedSeconds = tonumber(studio.referenceWeaponSpeedSeconds) or fallback.referenceWeaponSpeedSeconds or 2.4,
        base = {
            hp = tonumber(studio.baseHealth) or fallback.base.hp or 1,
            mana = tonumber(studio.baseMana) or fallback.base.mana or 0,
            str = tonumber(studio.baseStrength) or fallback.base.str or 0,
            agi = tonumber(studio.baseAgility) or fallback.base.agi or 0,
            sta = tonumber(studio.baseStamina) or fallback.base.sta or 0,
            int = tonumber(studio.baseIntellect) or fallback.base.int or 0,
            spi = tonumber(studio.baseSpirit) or fallback.base.spi or 0,
        },
        growth = fallback.growth or {},
        studio = studio,
    }
end

function FR:GetWeaponSpeedSeconds(weapon)
    if weapon and tonumber(weapon.weaponSpeedSeconds) then
        return math.max(0.5, tonumber(weapon.weaponSpeedSeconds))
    end
    local key = string.upper(tostring(weapon and weapon.speed or "NORMAL"))
    local speeds = GA.WEAPON_SPEED_SECONDS or { FAST = 1.8, NORMAL = 2.4, SLOW = 3.2 }
    return tonumber(speeds[key]) or 2.4
end

function FR:GetClassProfile(classFile)
    return ClassProfile(classFile)
end

function FR:GetRaceProfile(raceId)
    return GetStudioRace(raceId)
end

function FR:GetClassLevelStats(classFile, level, raceId)
    local profile = ClassProfile(classFile)
    local lvl = math.max(1, math.floor(tonumber(level) or 1))
    local rows = ParseLevelTable(profile.studio)
    local baseRow

    if rows and rows[lvl] then
        local row = rows[lvl]
        baseRow = {
            level = lvl, baseHealth = row.baseHealth, baseMana = row.baseMana,
            strength = row.strength, agility = row.agility, stamina = row.stamina,
            intellect = row.intellect, spirit = row.spirit,
        }
    else
        local steps = lvl - 1
        local growth = profile.growth or {}
        baseRow = {
            level = lvl,
            baseHealth = Round((profile.base.hp or 1) + (growth.hp or 0) * steps),
            baseMana = Round((profile.base.mana or 0) + (growth.mana or 0) * steps),
            strength = Round(profile.base.str + (growth.str or 0) * steps),
            agility = Round(profile.base.agi + (growth.agi or 0) * steps),
            stamina = Round(profile.base.sta + (growth.sta or 0) * steps),
            intellect = Round(profile.base.int + (growth.int or 0) * steps),
            spirit = Round(profile.base.spi + (growth.spi or 0) * steps),
        }
    end

    return ApplyRaceOffsets(baseRow, raceId)
end

function FR:GetBasePrimaryStats(classFile, level, raceId)
    local row = self:GetClassLevelStats(classFile, level, raceId)
    return {
        strength = row.strength, agility = row.agility, stamina = row.stamina,
        intellect = row.intellect, spirit = row.spirit,
    }
end

function FR:HealthFromStamina(stamina, classFile)
    local value = math.max(0, tonumber(stamina) or 0)
    local profile = ClassProfile(classFile)
    local first = math.max(0, tonumber(profile.healthPerStaminaFirst20) or 1)
    local after = math.max(0, tonumber(profile.healthPerStaminaAfter20) or FR.STAMINA_HP)
    return math.min(20, value) * first + math.max(0, value - 20) * after
end

function FR:GetReferencePlayerCombatProfile(classFile, level, raceId)
    local lvl = math.max(1, math.floor(tonumber(level) or 1))
    local profile = ClassProfile(classFile)
    local row = self:GetClassLevelStats(classFile, lvl, raceId)
    local attackPower = math.max(0,
        lvl * (profile.meleeApPerLevel or 0)
        + row.strength * (profile.strAP or 1)
        + row.agility * (profile.agiAP or 0)
        + (profile.meleeApOffset or 0)
    )
    local rawMaxHealth = math.max(1, row.baseHealth + self:HealthFromStamina(row.stamina, classFile))
    local rawReferenceDamage = math.max(1,
        (profile.referenceWeaponBaseDamage or 1.5)
        + (attackPower / FR.AP_PER_DPS) * (profile.referenceWeaponSpeedSeconds or 2.4)
    )
    return {
        level = lvl,
        raceId = raceId,
        attackPower = attackPower,
        rawMaxHealth = rawMaxHealth,
        maxHealth = GA.ScaleCombatValue and GA:ScaleCombatValue(rawMaxHealth) or math.max(1, Round(rawMaxHealth / 10)),
        rawReferenceDamage = rawReferenceDamage,
        referenceDamage = GA.ScaleCombatValue and GA:ScaleCombatValue(rawReferenceDamage) or math.max(1, Round(rawReferenceDamage / 10)),
        stats = row,
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

function FR:BuildDerivedStats(level, classFile, gear, raceId)
    gear = gear or {}
    local profile = ClassProfile(classFile)
    local row = self:GetClassLevelStats(classFile, level, raceId)
    local lvl = math.max(1, math.floor(tonumber(level) or 1))

    local strength = row.strength + math.max(0, tonumber(gear.strength) or 0)
    local agility = row.agility + math.max(0, tonumber(gear.agility) or 0)
    local stamina = row.stamina + math.max(0, tonumber(gear.stamina) or 0)
    local intellect = row.intellect + math.max(0, tonumber(gear.intellect) or 0)
    local spirit = row.spirit + math.max(0, tonumber(gear.spirit) or 0)

    local attackPower = math.max(0,
        (tonumber(gear.attackPower) or 0)
        + lvl * (profile.meleeApPerLevel or 0)
        + strength * (profile.strAP or 1)
        + agility * (profile.agiAP or 0)
        + (profile.meleeApOffset or 0)
    )
    local rangedAttackPower = math.max(0,
        (tonumber(gear.rangedAttackPower) or 0)
        + lvl * (profile.rangedApPerLevel or 0)
        + agility * (profile.rangedAgiAP or 0)
        + (profile.rangedApOffset or 0)
    )
    local armor = math.max(0, (tonumber(gear.armor) or 0) + agility * (profile.armorPerAgility or FR.AGILITY_ARMOR))
    local crit = math.max(0, (tonumber(gear.crit) or 0) + agility / math.max(1, profile.critPerAgi or 20))
    local dodge = math.max(0, (profile.baseDodge or 0) + (tonumber(gear.dodge) or 0) + agility / math.max(1, profile.dodgePerAgi or 20))
    local parry = math.max(0, (profile.baseParry or 0) + (tonumber(gear.parry) or 0))
    local hasShield = gear.hasShield == true
    local block = hasShield and math.max(0, (profile.baseBlock or 0) + (tonumber(gear.block) or 0)) or 0
    local blockValue = hasShield and math.max(0, tonumber(gear.blockValue) or 0) or 0
    if hasShield and (profile.blockValuePerStrength or 0) > 0 then
        blockValue = blockValue + strength * profile.blockValuePerStrength
    end

    local rawMaxHealth = math.max(1,
        (tonumber(row.baseHealth) or 1)
        + self:HealthFromStamina(stamina, classFile)
        + math.max(0, tonumber(gear.directHealth) or 0)
    )
    local scaledMaxHealth = GA.ScaleCombatValue and GA:ScaleCombatValue(rawMaxHealth) or math.max(1, Round(rawMaxHealth / 10))
    local healingPower = math.max(0, tonumber(gear.healingPower) or 0)
    local spellPower = math.max(0, tonumber(gear.spellPower) or 0) + healingPower / 3

    return {
        ruleset = FR.ID,
        raceId = raceId,
        strength = strength,
        agility = agility,
        stamina = stamina,
        intellect = intellect,
        spirit = spirit,
        baseHealth = tonumber(row.baseHealth) or 1,
        rawMaxHealth = rawMaxHealth,
        maxHealth = scaledMaxHealth,
        health = scaledMaxHealth,
        baseMana = tonumber(row.baseMana) or 0,
        maxMana = (tonumber(row.baseMana) or 0) + intellect * (profile.manaPerIntellect or FR.INTELLECT_MANA),
        armor = armor,
        attackPower = attackPower,
        rangedAttackPower = rangedAttackPower,
        hit = math.max(0, tonumber(gear.hit) or 0),
        crit = crit,
        expertise = math.max(0, tonumber(gear.expertise) or 0),
        defense = math.max(0, tonumber(gear.defense) or 0),
        defenseSkill = lvl * (profile.defenseSkillPerLevel or 5) + math.max(0, tonumber(gear.defense) or 0),
        weaponSkill = lvl * (profile.weaponSkillPerLevel or 5) + math.max(0, tonumber(gear.weaponSkill) or 0),
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
