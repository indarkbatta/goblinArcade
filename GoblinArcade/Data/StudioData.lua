local _, GA = ...

-- Generated-data foundation for GoblinArcade Studio.
-- The web editor exports this same table shape. Runtime systems may migrate
-- toward these records incrementally without making the editor itself a WoW UI.

GA.StudioData = {
    schemaVersion = 1,
    studioVersion = "0.1.0",

    classes = {
        {
            id = "warrior",
            name = "Warrior",
            resource = "RAGE",
            resourceMax = 3,
            description = "Front-line martial class. Rage is intentionally small and readable.",
        },
    },

    abilities = {
        { id = "attack", name = "Attack", classId = "warrior", slot = 1, resourceCost = 0, cooldown = 0, range = 1, target = "ENEMY", effect = "DAMAGE", power = 100, secondaryPower = 0, description = "Basic weapon attack." },
        { id = "cleave", name = "Cleave", classId = "warrior", slot = 2, resourceCost = 1, cooldown = 0, range = 1, target = "ADJACENT_ENEMIES", effect = "CLEAVE", power = 100, secondaryPower = 50, description = "Strike the primary target and splash half damage to one adjacent enemy." },
        { id = "brace", name = "Brace", classId = "warrior", slot = 3, resourceCost = 0, cooldown = 2, range = 0, target = "SELF", effect = "DEFEND", power = 50, secondaryPower = 0, description = "Reduce incoming damage during the next enemy phase." },
        { id = "potion", name = "Potion", classId = "warrior", slot = 4, resourceCost = 0, cooldown = 0, range = 0, target = "SELF", effect = "HEAL", power = 30, secondaryPower = 0, description = "Consume one potion charge to restore a percentage of maximum HP." },
    },

    enemies = {
        { id = "kobold", name = "Kobold", hpMultiplier = 0.95, damageMultiplier = 0.90, visionRadius = 6, movement = "NORMAL", baseScore = 100, sprite = "Media/Monsters/kobold" },
        { id = "spider", name = "Spider", hpMultiplier = 0.70, damageMultiplier = 0.80, visionRadius = 7, movement = "QUICK", baseScore = 90, sprite = "Media/Monsters/spider" },
        { id = "skeleton", name = "Skeleton", hpMultiplier = 1.20, damageMultiplier = 1.00, visionRadius = 5, movement = "SLOW", baseScore = 125, sprite = "Media/Monsters/skeleton" },
        { id = "brute", name = "Brute", hpMultiplier = 1.50, damageMultiplier = 1.25, visionRadius = 5, movement = "NORMAL", baseScore = 160, sprite = "" },
    },

    ranks = {
        { id = "normal", name = "Normal", levelBonus = 0, hpMultiplier = 1.00, damageMultiplier = 1.00, scoreMultiplier = 1.00 },
        { id = "veteran", name = "Veteran", levelBonus = 1, hpMultiplier = 1.25, damageMultiplier = 1.10, scoreMultiplier = 1.30 },
        { id = "elite", name = "Elite", levelBonus = 2, hpMultiplier = 1.60, damageMultiplier = 1.25, scoreMultiplier = 1.80 },
        { id = "boss", name = "Boss", levelBonus = 3, hpMultiplier = 2.80, damageMultiplier = 1.45, scoreMultiplier = 3.00 },
    },

    rooms = {
        { id = "START", name = "Start", enemyPolicy = "NONE", doorLimit = 2, marker = "<", reward = "NONE" },
        { id = "COMBAT", name = "Combat", enemyPolicy = "NORMAL", doorLimit = 2, marker = "", reward = "NONE" },
        { id = "TREASURE", name = "Treasure", enemyPolicy = "NONE", doorLimit = 1, marker = "$", reward = "CHEST" },
        { id = "SHRINE", name = "Shrine", enemyPolicy = "NONE", doorLimit = 1, marker = "S", reward = "SHRINE" },
        { id = "ELITE", name = "Elite", enemyPolicy = "ELITE", doorLimit = 1, marker = "!", reward = "ELITE_CACHE" },
        { id = "BOSS", name = "Boss", enemyPolicy = "BOSS", doorLimit = 1, marker = "B", reward = "EXIT" },
        { id = "EXIT", name = "Exit", enemyPolicy = "NONE", doorLimit = 2, marker = ">", reward = "EXIT" },
    },

    loot = {
        { id = "candlekeepers_charm", name = "Candlekeeper's Charm", slot = "NECK", quality = 2, itemLevel = 18, source = "TREASURE" },
        { id = "waxbound_ring", name = "Waxbound Ring", slot = "FINGER", quality = 2, itemLevel = 18, source = "TREASURE" },
    },

    shrines = {
        { id = "restore", name = "Restore", effect = "HEAL_PERCENT", value = 25, secondaryValue = 0 },
        { id = "blessing", name = "Blessing", effect = "DAMAGE_BONUS", value = 5, secondaryValue = 25 },
        { id = "sacrifice", name = "Sacrifice", effect = "HP_FOR_SCORE", value = 15, secondaryValue = 150 },
    },
}
