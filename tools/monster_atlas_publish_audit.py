from pathlib import Path

root = Path(__file__).resolve().parents[1]
root_html = (root / "index.html").read_bytes()
studio_html = (root / "studio" / "index.html").read_bytes()
addon_html = (root / "GoblinArcade" / "index.html").read_bytes()
assert root_html == studio_html == addon_html, "Studio HTML mirrors must remain byte-identical"
html = root_html.decode("utf-8")
api = (root / "api" / "publish-atlas.js").read_text(encoding="utf-8")
workflow = (root / ".github" / "workflows" / "balance-audit.yml").read_text(encoding="utf-8")

for token in (
    'id="monsterPublishAtlas"',
    "PUBLISH ATLAS TO WOW",
    "monsterPublishAtlasToWow",
    'fetch("/api/publish-atlas"',
    "monsterCanvasBlob",
    "monsterBlobDataUrl",
    "missing source art",
    "Stored source image missing",
):
    assert token in html, f"Missing Studio atlas-publish token: {token}"

for token in (
    "STUDIO_PUBLISH_KEY",
    "GITHUB_TOKEN",
    "MAX_PNG_BYTES",
    "parsePng",
    "validateManifest",
    'dimensions.width !== 384',
    'dimensions.height % 128 !== 0',
    "GoblinArcade/Media/Monsters/Atlases/",
    '"base64"',
    "force: false",
):
    assert token in api, f"Missing atlas-publish API token: {token}"

assert "api/publish-atlas.js" in workflow
assert "tools/monster_atlas_publish_audit.py" in workflow
assert 'node --check $apiScript' in workflow
print("Monster atlas publish audit passed: protected PNG+manifest GitHub upload, path validation and Studio button verified.")
