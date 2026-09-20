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
  const arrays = ["classes", "races", "abilities", "monsterSkills", "items", "lootTables", "loot", "objects", "eventRules", "events", "eventOptions", "enemies", "ranks", "progression", "rooms", "shrines"];
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

  const eventIds = new Set(data.events.map(event => String(event.id || "")));
  const roomIds = new Set(data.rooms.map(room => String(room.id || "")));
  const lootTableIds = new Set(data.lootTables.map(table => String(table.id || "")));
  const validEventEffects = new Set([
    "NONE", "HEAL_PERCENT", "DAMAGE_PERCENT", "HP_FOR_SCORE",
    "DAMAGE_BONUS", "MAX_HP_PERCENT", "COPPER", "SCORE", "LOOT_TABLE",
  ]);

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
  for (const event of data.events) {
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
    const eventId = String(option.eventId || "");
    if (!eventIds.has(eventId)) throw new Error("Event Option " + option.id + " references unknown event: " + eventId);
    optionCount.set(eventId, (optionCount.get(eventId) || 0) + 1);
    const effect = String(option.effect || "NONE").toUpperCase();
    if (!validEventEffects.has(effect)) {
      throw new Error("Event Option " + option.id + " uses unsupported effect: " + effect);
    }
    if (effect === "LOOT_TABLE" && !lootTableIds.has(String(option.lootTableId || ""))) {
      throw new Error("Event Option " + option.id + " references unknown loot table: " + option.lootTableId);
    }
  }
  for (const eventId of eventIds) {
    const count = optionCount.get(eventId) || 0;
    if (count < 1 || count > 4) throw new Error("Event " + eventId + " must have 1-4 options.");
  }

  const monsterSkillIds = new Set(data.monsterSkills.map(skill => String(skill.id || "")));
  for (const enemy of data.enemies) {
    const skillIds = Array.isArray(enemy.skillIds) ? enemy.skillIds : [];
    for (const skillId of skillIds) {
      if (!monsterSkillIds.has(String(skillId))) {
        throw new Error("Enemy " + enemy.id + " references unknown Monster Skill: " + skillId);
      }
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
      lootTables: data.lootTables,
      loot: data.loot,
      objects: data.objects,
      eventRules: data.eventRules,
      events: data.events,
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
