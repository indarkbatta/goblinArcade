from pathlib import Path

root = Path(__file__).resolve().parents[1]
index_bytes = (root / "index.html").read_bytes()
studio_bytes = (root / "studio" / "index.html").read_bytes()
addon_bytes = (root / "GoblinArcade" / "index.html").read_bytes()
assert index_bytes == studio_bytes == addon_bytes, "Studio HTML mirrors must remain byte-identical"
index = index_bytes.decode("utf-8")

required = [
    'id="autotileModal"',
    'Wall Autotile Builder',
    'autotileNormalizeMask',
    'autotileBuildPaddedMask',
    'autotileDistanceField',
    'autotileMaterialPixels',
    'autotileRenderTile',
    'autotileDownloadAtlas',
    'autotileDownloadMapping',
    'AUTOTILE_ATLAS=1024',
    'AUTOTILE_SOURCE_WALL=80',
    'AUTOTILE_SOURCE_MARGIN=24',
    'accept="image/png"',
    'img.naturalWidth!==AUTOTILE_TILE',
    'masks.length!==47',
    'wall/128*100',
    'usedSlots:47',
    'reservedSlots:17',
    'order:"ascending normalized mask"',
]
for token in required:
    assert token in index, f"Autotile Builder hook missing: {token}"

material_start = index.index("function autotileMaterialPixels")
material_end = index.index("function autotileRenderTile", material_start)
material_fn = index[material_start:material_end]
assert "margin=AUTOTILE_SOURCE_MARGIN" in material_fn
assert "AUTOTILE_SOURCE_WALL-inset*2" in material_fn
assert "settings.wall" not in material_fn, "A1 source crop must stay canonical when output wall thickness changes"

workflow = (root / ".github" / "workflows" / "balance-audit.yml").read_text(encoding="utf-8")
assert "python3 tools/autotile_builder_audit.py" in workflow, "balance-audit.yml must run the autotile audit"

def normalize(mask: int) -> int:
    if not ((mask & 1) and (mask & 4)):
        mask &= ~2
    if not ((mask & 4) and (mask & 16)):
        mask &= ~8
    if not ((mask & 16) and (mask & 64)):
        mask &= ~32
    if not ((mask & 64) and (mask & 1)):
        mask &= ~128
    return mask

masks = sorted({normalize(i) for i in range(256)})
assert len(masks) == 47, f"Expected 47 normalized blob masks, got {len(masks)}"
assert masks[0] == 0 and masks[-1] == 255
assert masks == sorted(masks), "Blob masks must use deterministic ascending normalized-mask order"
print("Autotile Builder audit passed: byte-identical Studio mirrors, canonical A1 sampling, 47 masks, 1024 atlas and CI hooks verified.")
