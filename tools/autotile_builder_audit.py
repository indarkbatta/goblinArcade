from pathlib import Path

root = Path(__file__).resolve().parents[1]
index = (root / "index.html").read_text(encoding="utf-8")
studio = (root / "studio" / "index.html").read_text(encoding="utf-8")
addon = (root / "GoblinArcade" / "index.html").read_text(encoding="utf-8")
assert index == studio == addon, "Studio HTML mirrors must remain byte-identical"

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
    'masks.length!==47',
    'wall/128*100',
]
for token in required:
    assert token in index, f"Autotile Builder hook missing: {token}"

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
print("Autotile Builder audit passed: 47 normalized masks, mirrored Studio files, required hooks present.")
