#!/usr/bin/env python3
import json
import re
import struct
from pathlib import Path

root = Path(__file__).resolve().parents[1]
data = json.loads((root / "studio-data.json").read_text(encoding="utf-8"))
run = (root / "GoblinArcade" / "DungeonRun.lua").read_text(encoding="utf-8")
generator = (root / "GoblinArcade" / "DungeonGenerator.lua").read_text(encoding="utf-8")
studio = (root / "index.html").read_text(encoding="utf-8")
api = (root / "api" / "publish.js").read_text(encoding="utf-8")

assert data.get("schemaVersion") == 18
assert data.get("studioVersion") == "1.17.0"

for eco in data.get("ecosystems", []):
    for key in ("floorTexture", "wallTexture", "wallAutotileTexture"):
        assert key in eco, f"{eco.get('id')}: {key} missing"
        value = str(eco.get(key, "") or "").lower()
        assert not value.startswith(("http://", "https://")), f"{eco.get('id')}: remote texture URL"

orc = next(eco for eco in data["ecosystems"] if eco["id"] == "orc_occupied_crypt")
floor_rel = orc["floorTexture"]
assert floor_rel == "Media/Tiles/Floors/orc_occupied_crypt/orc_occupied_crypt_floor01.png"
floor = root / "GoblinArcade" / floor_rel
assert floor.exists(), f"Missing Orc floor texture: {floor}"
floor_raw = floor.read_bytes()[:24]
assert floor_raw[:8] == b"\x89PNG\r\n\x1a\n", "Orc floor texture must be PNG"
floor_width, floor_height = struct.unpack(">II", floor_raw[16:24])
assert floor_width == floor_height and floor_width >= 128, f"Expected square floor texture >=128px, got {floor_width}x{floor_height}"

fx_assets = {
    "soft radial FX": (root / "GoblinArcade" / "Media" / "FX" / "soft_radial.png", (64, 64)),
    "wall torch FX": (root / "GoblinArcade" / "Media" / "FX" / "wall_torch.png", (32, 48)),
    "soft corner FX": (root / "GoblinArcade" / "Media" / "FX" / "soft_corner.png", (64, 64)),
}
for label, (path, expected_size) in fx_assets.items():
    assert path.exists(), f"Missing {label}: {path}"
    assert path.suffix.lower() == ".png", f"{label} must use an explicit .png asset"
    header = path.read_bytes()[:24]
    assert header[:8] == b"\x89PNG\r\n\x1a\n", f"{label} must be PNG"
    asset_width, asset_height = struct.unpack(">II", header[16:24])
    assert (asset_width, asset_height) == expected_size, f"{label} expected {expected_size}, got {(asset_width, asset_height)}"

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
    "goblinArcadeStudio.v32",
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
    "WALL_CONTACT_SHADOW_PASSES",
    "local function CreateWallContactShadowTextures",
    "floorUnderlayTexture",
    "wallContactShadows",
    "shadow.gaContactShadowAlpha",
    "entry.floorUnderlayTexture:SetTexture(floorPath)",
    "DUNGEON_LIGHTING_PRESETS",
    "GetDungeonLightingAt",
    "GetTorchFlickerScale",
    "BuildDungeonLightField",
    "GetSmoothedLightCorner",
    "ApplySmoothCellLight",
    "CreateLightCornerOverlays",
    "UpdateDungeonLightingAnimation",
    "darknessOverlay",
    "lightCornerOverlays",
    "torchGlow",
    "torchOrb",
    "torchIcon",
    "enemyShadow",
    'SOFT_RADIAL_TEXTURE = "Interface\\\\AddOns\\\\GoblinArcade\\\\Media\\\\FX\\\\soft_radial.png"',
    'SOFT_CORNER_TEXTURE = "Interface\\\\AddOns\\\\GoblinArcade\\\\Media\\\\FX\\\\soft_corner.png"',
    'WALL_TORCH_TEXTURE = "Interface\\\\AddOns\\\\GoblinArcade\\\\Media\\\\FX\\\\wall_torch.png"',
    "self:UpdateDungeonLightingAnimation()",
    'cell:CreateTexture(nil, "BACKGROUND", nil, 7)',
    'cell:CreateTexture(nil, "BORDER", nil, 7)',
    'cell:CreateTexture(nil, "ARTWORK", nil, -8)',
):
    assert token in run, f"Renderer hook missing: {token}"

assert "lightTintOverlay" not in run, "Legacy per-tile light tint overlay should be removed"
assert 'entry.darknessOverlay:SetAlpha(lighting.ambientDarkness)' in run, "Visible ambient darkness should be uniform before smooth light reconstruction"
assert 'overlay:SetTexture(SOFT_CORNER_TEXTURE)' in run, "Corner interpolation texture not wired"

for match in re.finditer(r'CreateTexture\([^\n]*?,\s*"[^"]+"\s*,\s*nil\s*,\s*(-?\d+)\s*\)', run):
    sublevel = int(match.group(1))
    assert -8 <= sublevel <= 7, f"Invalid CreateTexture sublevel {sublevel}: WoW requires -8..7"

assert 'for (const textureKey of ["floorTexture", "wallTexture", "wallAutotileTexture"])' in api
print("Ecosystem tile audit OK: Orc floor, Blob47 walls, contact shadow, bilinear LOS lighting, explicit PNG FX paths, torch orb/halo and enemy drop shadow verified.")
