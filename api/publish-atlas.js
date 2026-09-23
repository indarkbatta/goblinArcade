const crypto = require("node:crypto");

const REPOSITORY = process.env.GITHUB_REPOSITORY || "indarkbatta/goblinArcade";
const BRANCH = process.env.GITHUB_BRANCH || "main";
const API = "https://api.github.com";
const MAX_PNG_BYTES = 3 * 1024 * 1024;

function safeEqual(left, right) {
  const a = Buffer.from(String(left || ""));
  const b = Buffer.from(String(right || ""));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

function slug(value) {
  return String(value || "monsters").trim().toLowerCase()
    .replace(/[^a-z0-9_-]+/g, "_")
    .replace(/^_+|_+$/g, "") || "monsters";
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

async function createBlob(content, token, encoding) {
  const result = await github("/repos/" + REPOSITORY + "/git/blobs", token, {
    method: "POST",
    body: JSON.stringify({ content, encoding: encoding || "utf-8" }),
  });
  return result.sha;
}

function parsePng(buffer) {
  const signature = Buffer.from([0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a]);
  if (buffer.length < 24 || !buffer.subarray(0, 8).equals(signature)) {
    throw new Error("Atlas payload is not a valid PNG.");
  }
  if (buffer.toString("ascii", 12, 16) !== "IHDR") {
    throw new Error("PNG IHDR header is missing.");
  }
  return { width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20) };
}

function validateManifest(manifest, family, width, height) {
  if (!manifest || typeof manifest !== "object") throw new Error("Manifest is missing.");
  if (String(manifest.family || "") !== family) throw new Error("Manifest family does not match the atlas family.");
  if (Number(manifest.frameWidth) !== 128 || Number(manifest.frameHeight) !== 128) throw new Error("Manifest frame size must be 128x128.");
  if (Number(manifest.atlasWidth) !== width || Number(manifest.atlasHeight) !== height) throw new Error("Manifest atlas dimensions do not match the PNG.");
  const columns = Array.isArray(manifest.columns) ? manifest.columns.map(x => String(x)) : [];
  if (columns.join(",") !== "idle,attack,dead") throw new Error("Manifest columns must be idle, attack, dead.");
  const rows = height / 128;
  if (!Array.isArray(manifest.monsters) || manifest.monsters.length !== rows) throw new Error("Manifest monster count does not match atlas rows.");
  const ids = new Set();
  manifest.monsters.forEach((monster, index) => {
    const id = String(monster && monster.id || "").trim();
    if (!id || ids.has(id)) throw new Error("Manifest contains a missing or duplicate monster ID.");
    ids.add(id);
    if (Number(monster.row) !== index) throw new Error("Manifest rows must be sequential and match atlas order.");
  });
}

module.exports = async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ ok: false, error: "Method not allowed." });

  const githubToken = process.env.GITHUB_TOKEN;
  const publishKey = process.env.STUDIO_PUBLISH_KEY;
  if (!githubToken || !publishKey) {
    return res.status(503).json({
      ok: false,
      setupRequired: true,
      error: "Atlas publish is not configured. Add GITHUB_TOKEN and STUDIO_PUBLISH_KEY in Vercel.",
    });
  }
  if (!safeEqual(req.headers["x-studio-key"], publishKey)) {
    return res.status(401).json({ ok: false, error: "Invalid Studio publish key." });
  }

  try {
    const body = typeof req.body === "string" ? JSON.parse(req.body) : (req.body || {});
    const requestedFamily = String(body.family || "");
    const family = slug(requestedFamily);
    if (!requestedFamily.trim() || family !== requestedFamily.trim().toLowerCase()) {
      throw new Error("Family ID must already be a safe lowercase slug using letters, numbers, _ or -.");
    }

    const base64 = String(body.pngBase64 || "").replace(/^data:image\/png;base64,/, "");
    if (!base64 || !/^[A-Za-z0-9+/=\r\n]+$/.test(base64)) throw new Error("PNG payload is missing or invalid.");
    const png = Buffer.from(base64, "base64");
    if (!png.length || png.length > MAX_PNG_BYTES) throw new Error("Atlas PNG must be 3 MiB or smaller.");

    const dimensions = parsePng(png);
    if (dimensions.width !== 384) throw new Error("Atlas PNG width must be exactly 384 px.");
    if (dimensions.height < 128 || dimensions.height % 128 !== 0) throw new Error("Atlas PNG height must be a positive multiple of 128 px.");
    if (dimensions.height > 8192) throw new Error("Atlas PNG supports at most 64 monster rows.");

    validateManifest(body.manifest, family, dimensions.width, dimensions.height);

    const ref = await github("/repos/" + REPOSITORY + "/git/ref/heads/" + BRANCH, githubToken);
    const parentSha = ref.object.sha;
    const parent = await github("/repos/" + REPOSITORY + "/git/commits/" + parentSha, githubToken);

    const pngPath = "GoblinArcade/Media/Monsters/Atlases/" + family + "_monster_states.png";
    const manifestPath = "GoblinArcade/Media/Monsters/Atlases/" + family + "_monster_states.json";
    const [pngBlob, manifestBlob] = await Promise.all([
      createBlob(png.toString("base64"), githubToken, "base64"),
      createBlob(JSON.stringify(body.manifest, null, 2) + "\n", githubToken, "utf-8"),
    ]);

    const tree = await github("/repos/" + REPOSITORY + "/git/trees", githubToken, {
      method: "POST",
      body: JSON.stringify({
        base_tree: parent.tree.sha,
        tree: [
          { path: pngPath, mode: "100644", type: "blob", sha: pngBlob },
          { path: manifestPath, mode: "100644", type: "blob", sha: manifestBlob },
        ],
      }),
    });

    const commit = await github("/repos/" + REPOSITORY + "/git/commits", githubToken, {
      method: "POST",
      body: JSON.stringify({
        message: "Publish " + family + " monster sprite atlas",
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
      runtimePath: "Media/Monsters/Atlases/" + family + "_monster_states.png",
      pngPath,
      manifestPath,
      width: dimensions.width,
      height: dimensions.height,
      rows: dimensions.height / 128,
      message: "Atlas and manifest published. GitHub Actions deployment has started.",
    });
  } catch (error) {
    return res.status(400).json({ ok: false, error: error.message || String(error) });
  }
};
