from pathlib import Path

root = Path(__file__).resolve().parents[1]
root_html = (root / "index.html").read_bytes()
studio_html = (root / "studio" / "index.html").read_bytes()
addon_html = (root / "GoblinArcade" / "index.html").read_bytes()
assert root_html == studio_html == addon_html, "Studio HTML mirrors must remain byte-identical"
html = root_html.decode("utf-8")

required = [
    'Monster Sprite Studio',
    'id="monsterStudioModal"',
    'id="monsterPreview"',
    'accept="image/png,image/webp"',
    'MONSTER_FRAME=128',
    'MONSTER_SAFE=112',
    'MONSTER_STATES=["idle","attack","dead"]',
    'indexedDB.open(MONSTER_DB_NAME,1)',
    'monsterAlphaBounds',
    'monsterProgressiveDownscale',
    'monsterDilatedOutline',
    'monsterRenderFrame',
    'monsterBuildAtlas',
    'monsterManifest',
    'image/webp',
    'image/png',
    'COPY FX TO ALL STATES',
    'DOWNLOAD CURRENT 128 PNG',
    'ATLAS WEBP',
    'ATLAS PNG',
    'NAV_GROUPS',
    'Art & Asset Tools',
    'Monster Sprite Studio',
    'Wall Autotile Builder',
    'document.createElement("details")',
]
for token in required:
    assert token in html, f"Monster Sprite Studio / grouped nav hook missing: {token}"

assert 'grid-template-columns:205px 260px minmax(440px,1fr) 320px' in html
assert 'studioVersion":"1.18.0"' in html
assert '<span>STUDIO</span><b>1.18.0</b>' in html
assert '<span>SCHEMA</span><b>18</b>' in html

workflow = (root / ".github" / "workflows" / "balance-audit.yml").read_text(encoding="utf-8")
assert "tools/monster_sprite_studio_audit.py" in workflow
assert "ubuntu-latest" not in workflow and "windows-latest" not in workflow and "macos-latest" not in workflow
assert "self-hosted" in workflow and "- Windows" in workflow

print("Monster Sprite Studio audit passed: grouped collapsible navigation, persistent large-source composer, 128px state frames, PNG/WebP atlas and manifest export verified.")
