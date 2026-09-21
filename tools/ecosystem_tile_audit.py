#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
data = json.loads((root / "studio-data.json").read_text(encoding="utf-8"))
run = (root / "GoblinArcade" / "DungeonRun.lua").read_text(encoding="utf-8")
generator = (root / "GoblinArcade" / "DungeonGenerator.lua").read_text(encoding="utf-8")
studio = (root / "index.html").read_text(encoding="utf-8")
api = (root / "api" / "publish.js").read_text(encoding="utf-8")

assert data.get("schemaVersion") == 12
assert data.get("studioVersion") == "1.11.0"

for eco in data.get("ecosystems", []):
    assert "floorTexture" in eco, f"{eco.get('id')}: floorTexture missing"
    assert "wallTexture" in eco, f"{eco.get('id')}: wallTexture missing"
    for key in ("floorTexture", "wallTexture"):
        value = str(eco.get(key, "") or "").lower()
        assert not value.startswith(("http://", "https://")), f"{eco.get('id')}: remote texture URL"

for token in ('["floorTexture","Floor Texture"', '["wallTexture","Wall Texture"', "goblinArcadeStudio.v26"):
    assert token in studio, f"Studio hook missing: {token}"

for token in ("floorTexture = ecosystem and ecosystem.floorTexture or", "wallTexture = ecosystem and ecosystem.wallTexture or"):
    assert token in generator, f"Generator hook missing: {token}"

for token in (
    "local function ResolveDungeonTileTexture",
    "local function GetActiveDungeonTileTexture",
    'local terrainTexture = cell:CreateTexture(nil, "ARTWORK", nil, -8)',
    "terrainTexture = terrainTexture",
    "entry.terrainTexture:SetTexture(terrainPath)",
    "entry.terrainTexture:SetAlpha(visible and 1 or 0.24)",
):
    assert token in run, f"Renderer hook missing: {token}"

assert 'for (const textureKey of ["floorTexture", "wallTexture"])' in api
print("Ecosystem tile audit OK.")
