#!/usr/bin/env python3
import json
import struct
from pathlib import Path

root = Path(__file__).resolve().parents[1]
data = json.loads((root / "studio-data.json").read_text(encoding="utf-8"))
run = (root / "GoblinArcade" / "DungeonRun.lua").read_text(encoding="utf-8")
generator = (root / "GoblinArcade" / "DungeonGenerator.lua").read_text(encoding="utf-8")
studio = (root / "index.html").read_text(encoding="utf-8")
api = (root / "api" / "publish.js").read_text(encoding="utf-8")

assert data.get("schemaVersion") == 13
assert data.get("studioVersion") == "1.12.0"

for eco in data.get("ecosystems", []):
    for key in ("floorTexture", "wallTexture", "wallAutotileTexture"):
        assert key in eco, f"{eco.get('id')}: {key} missing"
        value = str(eco.get(key, "") or "").lower()
        assert not value.startswith(("http://", "https://")), f"{eco.get('id')}: remote texture URL"

orc = next(eco for eco in data["ecosystems"] if eco["id"] == "orc_occupied_crypt")
atlas_rel = orc["wallAutotileTexture"]
assert atlas_rel == "Media/Tiles/Autotiles/orc_occupied_crypt/orc_occupied_crypt_wall_autotile_47.png"
atlas = root / "GoblinArcade" / atlas_rel
mapping = atlas.with_suffix(".json")
assert atlas.exists(), f"Missing autotile atlas: {atlas}"
assert mapping.exists(), f"Missing autotile mapping: {mapping}"

raw = atlas.read_bytes()[:24]
assert raw[:8] == b"\x89PNG\r\n\x1a\n", "Autotile atlas must be PNG"
width, height = struct.unpack(">II", raw[16:24])
assert (width, height) == (1024, 1024), f"Expected 1024x1024 atlas, got {width}x{height}"

mapping_data = json.loads(mapping.read_text(encoding="utf-8"))
tiles = mapping_data.get("tiles", [])
assert len(tiles) == 47, f"Expected 47 mapping tiles, got {len(tiles)}"
masks = [int(tile["mask"]) for tile in tiles]
assert masks == sorted(masks), "Mapping masks must be ascending"
assert [int(tile["index"]) for tile in tiles] == list(range(47)), "Atlas indices must be 0..46"

def normalize(mask: int) -> int:
    if not ((mask & 1) and (mask & 4)): mask &= ~2
    if not ((mask & 4) and (mask & 16)): mask &= ~8
    if not ((mask & 16) and (mask & 64)): mask &= ~32
    if not ((mask & 64) and (mask & 1)): mask &= ~128
    return mask

assert masks == sorted({normalize(i) for i in range(256)})

for token in (
    '["floorTexture","Floor Texture"',
    '["wallTexture","Wall Texture"',
    '["wallAutotileTexture","Wall Autotile Atlas"',
    "goblinArcadeStudio.v27",
):
    assert token in studio, f"Studio hook missing: {token}"

for token in (
    "floorTexture = ecosystem and ecosystem.floorTexture or",
    "wallTexture = ecosystem and ecosystem.wallTexture or",
    "wallAutotileTexture = ecosystem and ecosystem.wallAutotileTexture or",
):
    assert token in generator, f"Generator hook missing: {token}"

for token in (
    "local function GetActiveDungeonWallAutotileTexture",
    "local function NormalizeWallAutotileMask",
    "local function GetDungeonWallAutotileMask",
    "local function GetWallAutotileTexCoord",
    "WALL_AUTOTILE_INDEX_BY_MASK",
    "entry.terrainTexture:SetTexCoord(texLeft, texRight, texTop, texBottom)",
):
    assert token in run, f"Renderer hook missing: {token}"

assert 'for (const textureKey of ["floorTexture", "wallTexture", "wallAutotileTexture"])' in api
print("Ecosystem tile audit OK: Blob47 wall autotile runtime, 1024 atlas, 47 masks and fallback verified.")
