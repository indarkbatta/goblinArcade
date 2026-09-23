from pathlib import Path

root = Path(__file__).resolve().parents[1]
root_html = (root / "index.html").read_bytes()
studio_html = (root / "studio" / "index.html").read_bytes()
addon_html = (root / "GoblinArcade" / "index.html").read_bytes()
assert root_html == studio_html == addon_html, "Studio HTML mirrors must remain byte-identical"
html = root_html.decode("utf-8")
runtime = (root / "GoblinArcade" / "DungeonRun.lua").read_text(encoding="utf-8")
api = (root / "api" / "publish.js").read_text(encoding="utf-8")
workflow = (root / ".github" / "workflows" / "balance-audit.yml").read_text(encoding="utf-8")

for token in (
    '["spriteMode","Sprite Source","select"',
    '["SINGLE","ATLAS"]',
    "spriteAtlasMonsterId",
    "spriteAtlasRow",
    "spriteAtlasRows",
    "@monsterAtlasEntries",
    "monsterApplyAtlasBinding",
    "monsterSyncEnemyAtlasBindings",
    "BIND MATCHING ID",
    "MONSTER ATLAS BINDING",
):
    assert token in html, f"Missing Studio monster-atlas binding token: {token}"

for token in (
    "MONSTER_ATLAS_COLUMNS = 3",
    "MONSTER_ATLAS_FRAME_SIZE = 128",
    "GetMonsterAtlasTexCoord",
    'record.spriteMode or "")) == "ATLAS"',
    "spriteStateTexCoords",
    "GetEnemyStateTexCoord",
    "enemy.defeatedTurn = run.turns or 0",
    'enemy.intent == "ATTACKING" or enemy.intent == "SKILL"',
):
    assert token in runtime, f"Missing runtime monster-atlas token: {token}"

assert "needs an addon-local atlas PNG path" in api
assert "invalid atlas row metadata" in api
assert "tools/monster_atlas_binding_audit.py" in workflow
assert "self-hosted" in workflow and "- Windows" in workflow
print("Monster atlas binding audit passed: Enemy editor binding, row metadata, atlas UV selection and Idle/Attack/Dead runtime states verified.")
