from pathlib import Path
import json

root = Path(__file__).resolve().parents[1]
root_html = (root / "index.html").read_bytes()
studio_html = (root / "studio" / "index.html").read_bytes()
addon_html = (root / "GoblinArcade" / "index.html").read_bytes()
assert root_html == studio_html == addon_html, "Studio HTML mirrors must remain byte-identical"
html = root_html.decode("utf-8")

for token in (
    "monsterPublishedManifestUrl",
    "monsterPublishedAtlasUrl",
    "monsterFetchPublishedManifest",
    "monsterApplyPublishedManifestBinding",
    "monsterSyncPublishedAtlasFamily",
    "monsterRenderPublishedAtlasPreview",
    "SYNC PUBLISHED FAMILY",
    "ATLAS READY",
    "monster-binding-preview",
):
    assert token in html, f"Missing published-atlas editor token: {token}"

manifest_path = root / "GoblinArcade" / "Media" / "Monsters" / "Atlases" / "orc_monster_states.json"
png_path = root / "GoblinArcade" / "Media" / "Monsters" / "Atlases" / "orc_monster_states.png"
assert manifest_path.exists(), "Published Orc atlas manifest is missing"
assert png_path.exists(), "Published Orc atlas PNG is missing"

manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
assert manifest["family"] == "orc"
assert manifest["columns"] == ["idle", "attack", "dead"]
assert manifest["atlasWidth"] == 384
assert manifest["atlasHeight"] == len(manifest["monsters"]) * 128
assert [m["id"] for m in manifest["monsters"]] == ["orc_raider", "orc_berserker"], "Unexpected currently published Orc atlas rows"

data = json.loads((root / "studio-data.json").read_text(encoding="utf-8"))
enemies = {enemy["id"]: enemy for enemy in data["enemies"]}
for row, monster_id in enumerate(("orc_raider", "orc_berserker")):
    enemy = enemies[monster_id]
    assert enemy["spriteMode"] == "ATLAS"
    assert enemy["spriteAtlas"] == "Media/Monsters/Atlases/orc_monster_states.png"
    assert enemy["spriteAtlasFamily"] == "orc"
    assert enemy["spriteAtlasMonsterId"] == monster_id
    assert enemy["spriteAtlasRow"] == row
    assert enemy["spriteAtlasRows"] == 2

lua = (root / "GoblinArcade" / "Data" / "StudioData.lua").read_text(encoding="utf-8")
for monster_id in ("orc_raider", "orc_berserker"):
    assert f'spriteAtlasMonsterId = "{monster_id}"' in lua
assert lua.count('spriteAtlas = "Media/Monsters/Atlases/orc_monster_states.png"') >= 2

workflow = (root / ".github" / "workflows" / "balance-audit.yml").read_text(encoding="utf-8")
assert 'GoblinArcade/Media/Monsters/Atlases/**' in workflow
assert "tools/monster_atlas_editor_audit.py" in workflow
print("Monster atlas editor audit passed: published preview/sync UI and canonical Orc atlas bindings verified.")
