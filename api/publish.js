const crypto = require("node:crypto");

const REPOSITORY = process.env.GITHUB_REPOSITORY || "indarkbatta/goblinArcade";
const BRANCH = process.env.GITHUB_BRANCH || "main";
const API = "https://api.github.com";

function safeEqual(left, right) {
  const a = Buffer.from(String(left || ""));
  const b = Buffer.from(String(right || ""));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

function assertStudioData(data) {
  if (!data || typeof data !== "object") throw new Error("Missing Studio data.");
  const arrays = ["classes", "races", "abilities", "monsterSkills", "items", "prefixes", "suffixes", "lootTables", "loot", "objects", "ecosystems", "ecosystemEnemies", "eventRules", "events", "eventFlags", "eventOptions", "enemies", "ranks", "progression", "rooms", "shrines"];
  for (const key of arrays) {
    if (!Array.isArray(data[key])) throw new Error("Missing array: " + key);
    const ids = new Set();
    for (const record of data[key]) {
      if (!record || typeof record !== "object") throw new Error(key + " contains an invalid record.");
      const id = String(record.id || "").trim();
      if (!id) throw new Error(key + " contains a record without an ID.");
      if (ids.has(id)) throw new Error("Duplicate " + key + " ID: " + id);
      ids.add(id);
    }
  }

  const ecosystemIds = new Set(data.ecosystems.map(x => String(x.id || "")));
  const enemyIds = new Set(data.enemies.map(x => String(x.id || "")));
  const eventIds = new Set(data.events.map(x => String(x.id || "")));
  const flagIds = new Set(data.eventFlags.map(x => String(x.id || "")));
  const roomIds = new Set(data.rooms.map(x => String(x.id || "")));
  const lootTableIds = new Set(data.lootTables.map(x => String(x.id || "")));
  const itemIds = new Set(data.items.map(x => String(x.id || "")));
  const classIds = new Set(data.classes.map(x => String(x.id || "")));
  if (Number(data.schemaVersion) !== 18) throw new Error("Studio schemaVersion must be 18.");
  if (String(data.studioVersion || "") !== "1.18.0") throw new Error("Studio version must be 1.18.0.");
  for (const cls of data.classes) {
    const nums = ["resourceMax","resourcePerLevel","basicAttackResourceGain","baseHealth","baseMana","baseStrength","baseAgility","baseStamina","baseIntellect","baseSpirit","meleeApPerLevel","meleeApPerStrength","meleeApPerAgility","meleeApOffset","rangedApPerLevel","rangedApPerAgility","rangedApOffset","critAgiPerPercent","dodgeAgiPerPercent","baseDodge","baseParry","baseBlock","healthPerStaminaFirst20","healthPerStaminaAfter20","manaPerIntellectFirst20","manaPerIntellectAfter20","armorPerAgility","blockValuePerStrength","defenseSkillPerLevel","weaponSkillPerLevel","referenceWeaponBaseDamage","referenceWeaponSpeedSeconds"];
    for (const key of nums) {
      if (cls[key] !== undefined && cls[key] !== "" && !Number.isFinite(Number(cls[key]))) throw new Error("Class " + cls.id + " has invalid " + key + ".");
    }
    const table = String(cls.levelStatTable || "").trim();
    if (table) {
      const seen = new Set();
      for (const raw of table.split(/\r?\n/)) {
        if (!raw.trim()) continue;
        const cols = raw.split(",").map(x => x.trim());
        if (cols.length !== 8 || cols.some(x => !Number.isFinite(Number(x)))) throw new Error("Class " + cls.id + " has an invalid Level Stat Table row: " + raw);
        const level = Number(cols[0]);
        if (level < 1 || level > 60 || Math.floor(level) !== level || seen.has(level)) throw new Error("Class " + cls.id + " has invalid/duplicate level " + level + ".");
        seen.add(level);
      }
      if (!seen.has(1)) throw new Error("Class " + cls.id + " Level Stat Table must include Level 1.");
      for (const raw of table.split(/\r?\n/)) {
        if (!raw.trim()) continue;
        const cols = raw.split(",").map(x => Number(x.trim()));
        if (cols.slice(1).some(x => x < 0)) throw new Error("Class " + cls.id + " Level Stat Table cannot contain negative stats.");
      }
    }
    for (const key of ["resourceMax","resourcePerLevel","basicAttackResourceGain","baseHealth","baseMana","baseStrength","baseAgility","baseStamina","baseIntellect","baseSpirit","meleeApPerLevel","meleeApPerStrength","meleeApPerAgility","rangedApPerLevel","rangedApPerAgility","baseDodge","baseParry","baseBlock","healthPerStaminaFirst20","healthPerStaminaAfter20","manaPerIntellectFirst20","manaPerIntellectAfter20","armorPerAgility","blockValuePerStrength","defenseSkillPerLevel","weaponSkillPerLevel","referenceWeaponBaseDamage","referenceWeaponSpeedSeconds"]) {
      if (cls[key] !== undefined && cls[key] !== "" && Number(cls[key]) < 0) throw new Error("Class " + cls.id + " has negative " + key + ".");
    }
    if (cls.critAgiPerPercent !== undefined && Number(cls.critAgiPerPercent) <= 0) throw new Error("Class " + cls.id + " critAgiPerPercent must be > 0.");
    if (cls.dodgeAgiPerPercent !== undefined && Number(cls.dodgeAgiPerPercent) <= 0) throw new Error("Class " + cls.id + " dodgeAgiPerPercent must be > 0.");
  }

  const raceModels = new Set(["CLASSIC_STARTING_OFFSET","UNVERIFIED_NEUTRAL"]);
  for (const race of data.races) {
    const offsets = ["strengthOffset","agilityOffset","staminaOffset","intellectOffset","spiritOffset"];
    for (const key of offsets) {
      if (!Number.isFinite(Number(race[key])) || Math.floor(Number(race[key])) !== Number(race[key]) || Math.abs(Number(race[key])) > 20) {
        throw new Error("Race " + race.id + " has invalid " + key + " (integer -20..20 required).");
      }
    }
    const model = String(race.statOffsetModel || "");
    if (!raceModels.has(model)) throw new Error("Race " + race.id + " has invalid statOffsetModel.");
    if (!String(race.statOffsetSource || "").trim()) throw new Error("Race " + race.id + " requires statOffsetSource provenance.");
    if (model === "UNVERIFIED_NEUTRAL" && offsets.some(key => Number(race[key]) !== 0)) {
      throw new Error("Race " + race.id + " is UNVERIFIED_NEUTRAL but has non-zero offsets.");
    }
  }

  const affixStats = new Set(["attackPower","hit","crit","expertise","weaponSkill","armor","defense","dodge","parry","block","blockValue","spellPower","healingPower","mp5","arcaneResistance","fireResistance","frostResistance","natureResistance","shadowResistance"]);
  const affixFamilies = new Set(["OFFENSE","DEFENSE","MAGIC","RESISTANCE","UTILITY"]);
  for (const [kind, records] of [["Prefix", data.prefixes], ["Suffix", data.suffixes]]) for (const affix of records) {
    if (!affixFamilies.has(String(affix.family || "").toUpperCase())) throw new Error(kind+" "+affix.id+" has invalid Family.");
    const tier=Number(affix.tier),weight=Number(affix.weight),minLevel=Number(affix.minItemLevel),w1=Number(affix.stat1Weight||0),w2=Number(affix.stat2Weight||0);
    if (!Number.isFinite(tier)||tier<1||tier>4||!(weight>0)||!Number.isFinite(minLevel)||minLevel<1) throw new Error(kind+" "+affix.id+" has invalid tier/weight/minimum.");
    if (!affixStats.has(String(affix.stat1||""))||(String(affix.stat2||"")&&!affixStats.has(String(affix.stat2)))) throw new Error(kind+" "+affix.id+" has invalid stat.");
    if (w1<0||w2<0||w1+w2<=0) throw new Error(kind+" "+affix.id+" needs positive stat budget.");
  }

  const validStyles = new Set(["ORC_CRYPT","WARREN","HAUNTED_CRYPT","PLAGUE_CRYPT"]);
  for (const ecosystem of data.ecosystems) {
    const enabled = String(ecosystem.enabled || "YES").toUpperCase();
    if (!["YES","NO"].includes(enabled)) throw new Error("Ecosystem " + ecosystem.id + " has invalid Enabled value.");
    if (!(Number(ecosystem.weight) > 0)) throw new Error("Ecosystem " + ecosystem.id + " needs a positive Run Weight.");
    if (!validStyles.has(String(ecosystem.stylePreset || ""))) throw new Error("Ecosystem " + ecosystem.id + " has invalid Style Preset.");
    if (!String(ecosystem.dungeonName || "").trim()) throw new Error("Ecosystem " + ecosystem.id + " needs a Dungeon Title.");
    for (const textureKey of ["floorTexture", "wallTexture", "wallAutotileTexture"]) {
      const texturePath = String(ecosystem[textureKey] || "").trim();
      if (/^https?:\/\//i.test(texturePath)) throw new Error("Ecosystem " + ecosystem.id + " " + textureKey + " must be an addon-local texture path.");
    }
  }

  for (const membership of data.ecosystemEnemies) {
    if (!ecosystemIds.has(String(membership.ecosystemId || ""))) throw new Error("Ecosystem Monster " + membership.id + " references unknown ecosystem.");
    if (!enemyIds.has(String(membership.enemyId || ""))) throw new Error("Ecosystem Monster " + membership.id + " references unknown enemy.");
    const minFloor = Number(membership.minFloor);
    const maxFloor = Number(membership.maxFloor);
    if (!Number.isFinite(minFloor) || minFloor < 1 || !Number.isFinite(maxFloor) || maxFloor < minFloor || maxFloor > 9) {
      throw new Error("Ecosystem Monster " + membership.id + " has invalid floor range.");
    }
    if (!(Number(membership.weight) > 0)) throw new Error("Ecosystem Monster " + membership.id + " needs positive Spawn Weight.");
  }

  for (const ecosystem of data.ecosystems) {
    if (String(ecosystem.enabled || "YES").toUpperCase() !== "YES") continue;
    for (let floor = 1; floor <= 9; floor++) {
      const available = data.ecosystemEnemies.some(row =>
        String(row.ecosystemId || "") === String(ecosystem.id || "")
        && floor >= Number(row.minFloor)
        && floor <= Number(row.maxFloor)
        && Number(row.weight) > 0
      );
      if (!available) throw new Error("Enabled ecosystem " + ecosystem.id + " has no monsters for Floor " + floor + ".");
    }
  }

  const validEventEffects = new Set([
    "NONE", "HEAL_PERCENT", "DAMAGE_PERCENT", "HP_FOR_SCORE",
    "DAMAGE_BONUS", "MAX_HP_PERCENT", "COPPER", "SCORE", "LOOT_TABLE",
  ]);
  const validGear = new Set(["NONE","SHIELD","TWO_HAND","ONE_HAND","WEAPON","ARMOR","PLATE","MAIL","LEATHER","CLOTH"]);
  const validUnavailable = new Set(["DISABLE","HIDE"]);

  const eventRule = data.eventRules.find(rule => String(rule.id || "") === "dungeon_events");
  if (!eventRule) throw new Error("Missing dungeon_events Event Rule.");
  const basePerFloor = Number(eventRule.basePerFloor);
  const extraEveryFloors = Number(eventRule.extraEveryFloors);
  const maxPerFloor = Number(eventRule.maxPerFloor);
  if (!Number.isFinite(basePerFloor) || basePerFloor < 0
      || !Number.isFinite(extraEveryFloors) || extraEveryFloors < 0
      || !Number.isFinite(maxPerFloor) || maxPerFloor < basePerFloor) {
    throw new Error("dungeon_events has invalid placement values.");
  }

  const optionCount = new Map();
  const fallbackCount = new Map();
  for (const event of data.events) {
    for (const ecosystemId of (Array.isArray(event.ecosystemIds) ? event.ecosystemIds : [])) {
      if (!ecosystemIds.has(String(ecosystemId))) throw new Error("Event " + event.id + " references unknown ecosystem: " + ecosystemId);
    }
    const icon = String(event.icon || "").trim();
    if (/^https?:\/\//i.test(icon)) throw new Error("Event " + event.id + " icon cannot be a web URL.");
    const randomSpawn = String(event.randomSpawn || "YES").toUpperCase();
    if (!["YES","NO"].includes(randomSpawn)) throw new Error("Event " + event.id + " has invalid Random Spawn.");
    const minFloor = Number(event.minFloor);
    const maxFloor = Number(event.maxFloor);
    if (!Number.isFinite(minFloor) || minFloor < 1 || !Number.isFinite(maxFloor) || maxFloor < minFloor) {
      throw new Error("Event " + event.id + " has an invalid floor range.");
    }
    if (!(Number(event.weight) > 0)) throw new Error("Event " + event.id + " needs a positive weight.");
    const roles = Array.isArray(event.roomRoleIds) ? event.roomRoleIds : [];
    if (!roles.length) throw new Error("Event " + event.id + " needs at least one room role.");
    for (const roleId of roles) {
      if (!roomIds.has(String(roleId))) throw new Error("Event " + event.id + " references unknown room role: " + roleId);
    }
  }

  for (const option of data.eventOptions) {
    const id = String(option.id || "");
    const eventId = String(option.eventId || "");
    if (!eventIds.has(eventId)) throw new Error("Event Option " + id + " references unknown event: " + eventId);
    if (!(Number(option.sortOrder) >= 0)) throw new Error("Event Option " + id + " has invalid Sort Order.");
    optionCount.set(eventId, (optionCount.get(eventId) || 0) + 1);

    const effect = String(option.effect || "NONE").toUpperCase();
    if (!validEventEffects.has(effect)) throw new Error("Event Option " + id + " uses unsupported effect: " + effect);
    if (effect === "LOOT_TABLE" && !lootTableIds.has(String(option.lootTableId || ""))) {
      throw new Error("Event Option " + id + " references unknown loot table: " + option.lootTableId);
    }

    const minHp = Number(option.minHpPercent || 0);
    const minFloor = Number(option.requiredMinFloor || 0);
    const maxFloor = Number(option.requiredMaxFloor || 0);
    const requiredCopper = Number(option.requiredCopper || 0);
    const costHp = Number(option.costHpPercent || 0);
    const costCopper = Number(option.costCopper || 0);
    const requiredQty = Number(option.requiredItemQuantity || 1);
    const costQty = Number(option.costItemQuantity || 1);
    const queueDelay = Number(option.queueAfterFloors || 1);
    if (!Number.isFinite(minHp) || minHp < 0 || minHp > 100) throw new Error(id + ": Min Current HP % must be 0-100.");
    if (!Number.isFinite(minFloor) || minFloor < 0 || !Number.isFinite(maxFloor) || maxFloor < 0
        || (minFloor > 0 && maxFloor > 0 && maxFloor < minFloor)) throw new Error(id + ": invalid floor requirement.");
    if (!Number.isFinite(requiredCopper) || requiredCopper < 0 || !Number.isFinite(costCopper) || costCopper < 0) throw new Error(id + ": Copper values cannot be negative.");
    if (!Number.isFinite(costHp) || costHp < 0 || costHp >= 100) throw new Error(id + ": HP Cost % must be 0-99.");
    if (!Number.isFinite(requiredQty) || requiredQty < 1 || !Number.isFinite(costQty) || costQty < 1) throw new Error(id + ": item quantities must be at least 1.");
    if (!Number.isFinite(queueDelay) || queueDelay < 1) throw new Error(id + ": Follow-up Delay must be at least 1 floor.");
    if (!validGear.has(String(option.requiredGearType || "NONE").toUpperCase())) throw new Error(id + ": invalid Required Equipped Gear.");
    if (!validUnavailable.has(String(option.unavailableMode || "DISABLE").toUpperCase())) throw new Error(id + ": invalid unavailable mode.");

    for (const classId of (Array.isArray(option.requiredClassIds) ? option.requiredClassIds : [])) {
      if (!classIds.has(String(classId))) throw new Error(id + ": unknown required Class " + classId);
    }
    for (const itemId of [
      ...(Array.isArray(option.requiredItemIds) ? option.requiredItemIds : []),
      ...(Array.isArray(option.costItemIds) ? option.costItemIds : []),
    ]) {
      if (!itemIds.has(String(itemId))) throw new Error(id + ": unknown Item " + itemId);
    }
    for (const flagId of [
      ...(Array.isArray(option.requiredFlagIds) ? option.requiredFlagIds : []),
      ...(Array.isArray(option.forbiddenFlagIds) ? option.forbiddenFlagIds : []),
      ...(Array.isArray(option.setFlagIds) ? option.setFlagIds : []),
      ...(Array.isArray(option.clearFlagIds) ? option.clearFlagIds : []),
    ]) {
      if (!flagIds.has(String(flagId))) throw new Error(id + ": unknown Event Flag " + flagId);
    }
    for (const followupId of (Array.isArray(option.queueEventIds) ? option.queueEventIds : [])) {
      if (!eventIds.has(String(followupId))) throw new Error(id + ": unknown follow-up Event " + followupId);
      if (String(followupId) === eventId) throw new Error(id + ": cannot queue its own parent Event.");
    }

    const fallback = minHp <= 0 && minFloor <= 0 && maxFloor <= 0
      && !(option.requiredClassIds || []).length
      && String(option.requiredGearType || "NONE").toUpperCase() === "NONE"
      && requiredCopper <= 0
      && !(option.requiredItemIds || []).length
      && !(option.requiredFlagIds || []).length
      && !(option.forbiddenFlagIds || []).length
      && costHp <= 0 && costCopper <= 0 && !(option.costItemIds || []).length;
    if (fallback) fallbackCount.set(eventId, (fallbackCount.get(eventId) || 0) + 1);
  }

  for (const eventId of eventIds) {
    const count = optionCount.get(eventId) || 0;
    if (count < 1 || count > 4) throw new Error("Event " + eventId + " must have 1-4 options.");
    if ((fallbackCount.get(eventId) || 0) < 1) throw new Error("Event " + eventId + " needs an unconditional fallback option.");
  }

  const monsterSkillIds = new Set(data.monsterSkills.map(skill => String(skill.id || "")));
  for (const enemy of data.enemies) {
    for (const skillId of (Array.isArray(enemy.skillIds) ? enemy.skillIds : [])) {
      if (!monsterSkillIds.has(String(skillId))) throw new Error("Enemy " + enemy.id + " references unknown Monster Skill: " + skillId);
    }
  }
}

function luaString(value) {
  return '"' + String(value ?? "")
    .replace(/\\/g, "\\\\")
    .replace(/"/g, '\\"')
    .replace(/\r/g, "")
    .replace(/\n/g, "\\n") + '"';
}

function luaValue(value, indent = 0) {
  if (value == null) return "nil";
  if (typeof value === "number") return Number.isFinite(value) ? String(value) : "0";
  if (typeof value === "boolean") return value ? "true" : "false";
  if (typeof value === "string") return luaString(value);

  const pad = " ".repeat(indent);
  const childPad = " ".repeat(indent + 4);

  if (Array.isArray(value)) {
    if (!value.length) return "{}";
    return "{\n" + value.map(item => childPad + luaValue(item, indent + 4) + ",").join("\n")
      + "\n" + pad + "}";
  }

  const entries = Object.entries(value);
  if (!entries.length) return "{}";
  return "{\n" + entries.map(([key, child]) => {
    const luaKey = /^[A-Za-z_][A-Za-z0-9_]*$/.test(key) ? key : "[" + luaString(key) + "]";
    return childPad + luaKey + " = " + luaValue(child, indent + 4) + ",";
  }).join("\n") + "\n" + pad + "}";
}

function buildLua(data) {
  return "local _, GA = ...\n\n"
    + "-- Generated by GoblinArcade Studio. Edit through the Studio whenever possible.\n"
    + "GA.StudioData = " + luaValue(data) + "\n";
}

async function github(path, token, options = {}) {
  const response = await fetch(API + path, {
    ...options,
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: "Bearer " + token,
      "X-GitHub-Api-Version": "2022-11-28",
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
  });

  const text = await response.text();
  let body = null;
  try { body = text ? JSON.parse(text) : null; } catch { body = text; }

  if (!response.ok) {
    const message = body && body.message ? body.message : String(body || response.statusText);
    throw new Error("GitHub " + response.status + ": " + message);
  }

  return body;
}

async function createBlob(content, token) {
  const result = await github("/repos/" + REPOSITORY + "/git/blobs", token, {
    method: "POST",
    body: JSON.stringify({
      content: Buffer.from(content, "utf8").toString("base64"),
      encoding: "base64",
    }),
  });
  return result.sha;
}

module.exports = async function handler(req, res) {
  res.setHeader("Cache-Control", "no-store");

  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    return res.status(405).json({ ok: false, error: "POST required." });
  }

  const githubToken = process.env.GITHUB_TOKEN;
  const publishKey = process.env.STUDIO_PUBLISH_KEY;

  if (!githubToken || !publishKey) {
    return res.status(503).json({
      ok: false,
      setupRequired: true,
      error: "Publish is not configured. Add GITHUB_TOKEN and STUDIO_PUBLISH_KEY in Vercel.",
    });
  }

  if (!safeEqual(req.headers["x-studio-key"], publishKey)) {
    return res.status(401).json({ ok: false, error: "Invalid Studio publish key." });
  }

  try {
    const data = typeof req.body === "string" ? JSON.parse(req.body) : req.body;
    assertStudioData(data);

    const studioData = {
      schemaVersion: Number(data.schemaVersion) || 1,
      studioVersion: String(data.studioVersion || "0.2.0"),
      classes: data.classes,
      races: data.races,
      abilities: data.abilities,
      monsterSkills: data.monsterSkills,
      items: data.items,
      prefixes: data.prefixes,
      suffixes: data.suffixes,
      lootTables: data.lootTables,
      loot: data.loot,
      objects: data.objects,
      ecosystems: data.ecosystems,
      ecosystemEnemies: data.ecosystemEnemies,
      eventRules: data.eventRules,
      events: data.events,
      eventFlags: data.eventFlags,
      eventOptions: data.eventOptions,
      enemies: data.enemies,
      ranks: data.ranks,
      progression: data.progression,
      rooms: data.rooms,
      shrines: data.shrines,
    };

    const ref = await github("/repos/" + REPOSITORY + "/git/ref/heads/" + BRANCH, githubToken);
    const parentSha = ref.object.sha;
    const parent = await github("/repos/" + REPOSITORY + "/git/commits/" + parentSha, githubToken);

    const jsonContent = JSON.stringify(studioData, null, 2) + "\n";
    const luaContent = buildLua(studioData);

    const [jsonBlob, luaBlob] = await Promise.all([
      createBlob(jsonContent, githubToken),
      createBlob(luaContent, githubToken),
    ]);

    const tree = await github("/repos/" + REPOSITORY + "/git/trees", githubToken, {
      method: "POST",
      body: JSON.stringify({
        base_tree: parent.tree.sha,
        tree: [
          { path: "studio-data.json", mode: "100644", type: "blob", sha: jsonBlob },
          { path: "GoblinArcade/Data/StudioData.lua", mode: "100644", type: "blob", sha: luaBlob },
        ],
      }),
    });

    const commit = await github("/repos/" + REPOSITORY + "/git/commits", githubToken, {
      method: "POST",
      body: JSON.stringify({
        message: "Publish GoblinArcade Studio data",
        tree: tree.sha,
        parents: [parentSha],
      }),
    });

    await github("/repos/" + REPOSITORY + "/git/refs/heads/" + BRANCH, githubToken, {
      method: "PATCH",
      body: JSON.stringify({ sha: commit.sha, force: false }),
    });

    return res.status(200).json({
      ok: true,
      sha: commit.sha,
      shortSha: commit.sha.slice(0, 7),
      message: "Published. GitHub Actions deployment has started.",
    });
  } catch (error) {
    return res.status(400).json({ ok: false, error: error.message || String(error) });
  }
}
