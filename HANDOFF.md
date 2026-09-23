# GoblinArcade — Handoff

> **Maintenance rule:** Keep this file updated with every meaningful development change. Any change to version, UI, controls, combat, gear conversion, inventory, dungeon systems, deployment behavior, known issues, or next-step priorities must be reflected here in the same development cycle.

Last updated: 2026-09-22  
Current addon version: **0.71.2**  
Repository: `indarkbatta/goblinArcade`  
Default branch: `main`



## Published monster atlas integration — Enemy editor + first live Orc bindings

- The first real published atlas is now live: `orc_monster_states.png` contains **orc_raider row 0** and **orc_berserker row 1**, with Idle / Attack / Dead columns.
- Canonical `studio-data.json` and generated `StudioData.lua` now bind those two Enemy records to `Media/Monsters/Atlases/orc_monster_states.png`; their legacy single-PNG `sprite` values remain as fallback data.
- Enemy Editor atlas card now renders the **actual published PNG** as three cropped Idle / Attack / Dead previews, rather than relying only on browser-local IndexedDB source art.
- Added **SYNC PUBLISHED FAMILY**. It loads `/GoblinArcade/Media/Monsters/Atlases/<family>_monster_states.json`, finds matching Enemy IDs, and synchronizes atlas path/family/monster/row/row-count for the entire family.
- Atlas Family / Row / Row Count are read-only generated metadata in the editor. The binding card shows `ATLAS READY`, `ATLAS INCOMPLETE`, or `SINGLE SPRITE` state.
- Monster atlas asset changes now trigger the self-hosted balance audit through `GoblinArcade/Media/Monsters/Atlases/**`.
- Added `tools/monster_atlas_editor_audit.py`, which verifies HTML mirror identity, published-preview/sync hooks, the live Orc manifest, canonical JSON bindings and generated Lua bindings.
- Studio schema/version remain **18 / 1.18.0**; these are additive editor/runtime-content changes.
## Monster Sprite Studio — direct GitHub atlas publish

- Added **PUBLISH ATLAS TO WOW** to Monster Sprite Studio. It renders the current deterministic PNG atlas in-browser and publishes it directly to GitHub through protected `/api/publish-atlas`.
- The endpoint reuses the existing `GITHUB_TOKEN` and `STUDIO_PUBLISH_KEY`; the GitHub token never reaches the browser.
- A successful publish commits both `GoblinArcade/Media/Monsters/Atlases/<family>_monster_states.png` and the matching manifest JSON in one Git commit, then the existing push deployment can copy the asset into WoW.
- Runtime path returned to Studio is `Media/Monsters/Atlases/<family>_monster_states.png`, and matching local Enemy atlas bindings are synchronized to that path.
- GitHub publish is blocked if any Idle / Attack / Dead source image is missing. Local PNG/WebP export remains available for work-in-progress art.
- Server validation verifies PNG signature/IHDR, exact 384 px width, height as a positive multiple of 128, max 64 rows / 3 MiB, manifest dimensions, fixed Idle/Attack/Dead columns, unique monster IDs and sequential row mapping.
- Added `tools/monster_atlas_publish_audit.py`; the CI also runs `node --check` on both Vercel publish functions.
## Monster atlas binding — Enemy editor + runtime

- The **Enemies** editor now supports `Sprite Source = SINGLE | ATLAS`. Existing records transparently migrate to `SINGLE`; no existing monster art is broken.
- In `ATLAS` mode the editor exposes **Atlas PNG Path**, **Atlas Family**, **Atlas Monster**, **Atlas Row**, and **Atlas Row Count**. `Atlas Monster` is populated from the current browser-local **Monster Sprite Studio** family.
- Selecting an Atlas Monster (or pressing **BIND MATCHING ID**) automatically writes the monster row and total row count. The default runtime path is `Media/Monsters/Atlases/<family>_monster_states.png`.
- Row metadata stays synchronized when rows are added/deleted in Monster Sprite Studio and when a bound monster ID is renamed.
- Publish validation rejects remote atlas URLs and invalid row metadata.
- `DungeonRun.lua` now resolves atlas-backed enemies before legacy hardcoded/single-file fallbacks. The 384px-wide atlas is interpreted as fixed columns **Idle / Attack / Dead**, with 0.5 texel UV insets.
- Grid sprites and the enemy combat portrait use the current state: normal states use **Idle**, `ATTACKING` / `SKILL` use **Attack**, and a defeated atlas-backed enemy shows its **Dead** frame for the defeat turn before disappearing.
- Added `tools/monster_atlas_binding_audit.py` and wired it into the self-hosted Windows audit workflow.
- Studio schema/version remain **18 / 1.18.0** because the atlas fields are additive and optional; old published data remains compatible.
## Studio 1.18.0 — grouped navigation + Monster Sprite Studio

- Reorganized the formerly flat Studio navigation into collapsible editor groups: **Characters & Combat**, **Monsters & AI**, **Items & Loot**, **Dungeon**, **Events**, plus **Art & Asset Tools**.
- Added **Monster Sprite Studio** as a standalone art utility. It accepts large transparent PNG/WebP source artwork instead of requiring pre-sized 128×128 assets.
- Every monster has three fixed state slots: **Idle / Attack / Dead**. Source images are stored persistently in browser **IndexedDB** while transform/FX settings are stored in local storage.
- The 128×128 frame composer supports alpha-bound auto-fit into a 112×112 safe area, drag positioning, mouse-wheel/slider scaling, X/Y offsets, contrast, saturation, final-pixel outline width/color, and configurable drop shadow.
- Final frames are rendered at 4× working resolution and reduced with multi-pass high-quality downscaling before outline/shadow compositing, so large master artwork remains readable at game scale.
- A monster family exports as a deterministic atlas with **columns = Idle / Attack / Dead** and **rows = monsters**. Exports include runtime-oriented PNG, optional WebP, individual 128×128 frame PNG, and JSON manifest with pixel rectangles plus normalized UV coordinates.
- The existing **Wall Autotile Builder** is now also directly accessible under **Art & Asset Tools**, while its ecosystem-specific entry point remains available.
- Studio version **1.18.0**, schema remains **18**. Addon runtime version remains **0.71.2**; monster-state runtime switching is intentionally a separate follow-up after the first atlas is authored and committed.

## 0.71.2 — empty-state reset after hero deletion

- Fixed the Selected Hero screen after deleting the final generated hero. The **RUN LOADOUT** card no longer keeps stale weapon or Hardcore memorial text from the deleted character.
- The no-selection path now clears the weapon card payload/text, resets **HERO STATUS**, clears pending delete/abandon confirmations, neutralizes and disables difficulty buttons, and restores the normal empty pre-selection presentation.
- Added a generated-character regression audit for the full no-selection loadout/status reset.
- No Studio schema/data change. Addon version **0.71.2**.

## 0.71.1 — Classic dodge and mana correctness patch

- Corrected the Warrior class-base Dodge value from 3% to **0%**. The Classic/Vanilla baseline adds Warrior Dodge from Agility; CMaNGOS/VMaNGOS player stat logic uses no additional Warrior class-base Dodge.
- Replaced the oversimplified `INT × 15` mana rule with the Classic split: first 20 Intellect = **1 Mana each**, Intellect above 20 = **15 Mana each**.
- Classes with zero class base Mana now remain at **0 Max Mana**, so the Rage-based Warrior no longer receives an unused hidden mana pool from Intellect.
- Class Editor now exposes `manaPerIntellectFirst20` and `manaPerIntellectAfter20` separately. Studio schema is **18**, Studio version **1.17.0**, draft key **v32**.
- ForeverRules is ruleset **V4**; static/runtime audits cover the corrected Warrior Dodge and mana behavior. Addon version **0.71.1**.

## 0.71.0 — Race-aware Classic stat source of truth

### Research result and provenance

- **Forever-specific evidence:** the public WoW Forever stat guide describes the game as using the WoW Classic primary-stat model with Forever-specific changes, including Warrior Strength/Agility relationships and race-dependent starting attributes. Public Forever race documentation also confirms the current Warrior-compatible Classic races plus the two Skyborne variants.
- **Classic-compatible baseline:** the exact Warrior Level 1-60 class table remains the Studio-authored Vanilla/Classic progression table. The melee AP rule is `3 × Level + 2 × STR - 20`; ranged AP is `Level + AGI - 10`. The runtime uses the Classic old-world Stamina health split (first 20 STA at 1 HP each, later STA at 10 HP each), 2 Armor/AGI, 15 Mana/INT, 1 Block Value per 20 STR, and Level × 5 Defense/Weapon Skill.
- **Race correctness:** Classic starting primary attributes are not represented as a fake class-only fact. Human Warrior is the canonical class-table baseline and the Race Editor now applies editable starting offsets to STR/AGI/STA/INT/SPI:
  - Human `0/0/0/0/0`
  - Dwarf `+5/-4/+1/-1/-1`
  - Night Elf `-4/+4/0/0/0`
  - Gnome `-5/+2/0/+4/0`
  - Orc `+3/-3/+1/-3/+2`
  - Undead `-1/-2/0/-2/+5`
  - Tauren `+5/-4/+1/-4/+2`
  - Troll `+1/+2/0/-4/+1`
- **Skyborne limitation:** no reliable public numeric starting-stat offsets were found for Skyborne High Order or Skyborne Windshaper. They therefore use explicit zero offsets with `UNVERIFIED_NEUTRAL` provenance. This is a GoblinArcade fallback, **not** claimed WoW Forever data.
- Research references used for this implementation: WoW Forever / Warcraft Tavern **Stats & Attributes Guide**; Classic/Vanilla primary-stat data and formulas cross-checked against CMaNGOS Classic `StatSystem.cpp`, VMaNGOS `player_levelstats` corrections, and Classic Warrior starting-attribute references.

### Data model / Studio

- Studio schema **17**, Studio **1.16.0**, browser draft key **v31**.
- Class Editor is now visibly grouped into Identity/Availability, Resource, Level-1 Class Baseline, Exact Level Progression, Derived Stat Rules, Enemy Reference Profile and Notes.
- Warrior's additional editable mechanics are now data-authored instead of being active hardcoded class logic:
  - HP per Stamina for first 20 / after 20
  - Mana per Intellect
  - Armor per Agility
  - Block Value per Strength
  - Defense Skill per level
  - Weapon Skill per level
  - reference weapon base damage / speed for enemy-scaling baseline
  - Rage cap remains the class `resourceMax` (100)
- Race Editor now exposes five starting-stat offsets plus `statOffsetModel` and `statOffsetSource` provenance.
- Publish validation requires schema/version correctness, valid class progression values, bounded integer race offsets, provenance text, and enforces zero offsets for `UNVERIFIED_NEUTRAL` races.
- All three Studio HTML mirrors remain required to be byte-identical.

### Runtime

- `ForeverRules.lua` is ruleset **V3**. `GA.StudioData.classes` is the active class source of truth and `GA.StudioData.races` is the active race-offset source.
- Main entry points are `GetClassProfile(classId)`, `GetRaceProfile(raceId)`, `GetClassLevelStats(classId, level, raceId?)`, `GetBasePrimaryStats(classId, level, raceId?)`, `BuildDerivedStats(..., raceId?)` and `GetReferencePlayerCombatProfile(..., raceId?)`.
- Generated heroes now receive their race-adjusted Level-1 HP/stats at creation and at run start. Character Sheet recalculation keeps using the selected race at every run level.
- Level-up no longer has an independent HP-per-level track. It recalculates the new class/race row plus derived stats. The only level-up heal is exactly the stat-derived max-HP increase, preserving absolute missing HP rather than fully healing or applying a second progression.
- Rage cap is read from the class record instead of being reset to a separate hardcoded 100 inside Character Sheet recalculation.

### Enemy scaling / balance

- Enemy HP remains anchored to the canonical class reference offense: class level row -> AP -> reference weapon swing -> desired HP envelope, then archetype/rank/floor/gear/difficulty modifiers.
- Enemy damage remains anchored to canonical class reference durability: class base HP + Stamina-derived HP -> incoming-pressure fraction, then archetype/rank/floor/gear/difficulty modifiers.
- The enemy reference intentionally uses the **race-neutral class baseline** so choosing a stronger/weaker race does not silently rescale the dungeon against that same racial benefit. Editing Warrior class STR/STA/progression still moves enemy HP/damage consistently.
- Removed the last legacy independent fallbacks `5 + level × 0.90` and `100 + level × 20` from EnemyGenerator.
- `tools/balance_audit.py` now reads the same Studio-authored Stamina-health and reference-weapon coefficients as runtime.

### Automated coverage

- Static audit validates exact Warrior L1/L5/L10/L20/L60 rows, all eight Classic race offsets, explicit neutral Skyborne handling, editor/publish hooks, mirror identity, race-aware runtime call sites and absence of the old enemy proxies.
- Executable Lua audit validates L1/L5/L10 Human Warrior snapshots, Orc L1 stats/AP/HP, derived Armor/Defense/Weapon Skill, editable class coefficient reaction, editable exact-table reaction, editable race-offset reaction, enemy HP response to offense changes, enemy damage response to durability changes, and rank/difficulty multipliers.
- EASY/NORMAL/HARD full-run balance simulations continue to use the same canonical Warrior class source via `tools/balance_audit.py`.



## 0.70.0 — Classic/Forever class-level stat progression

- Replaced the old linear primary-stat approximation with Studio-authored per-level class progression.
- Class Editor now exposes Level-1 Base HP/Mana, STR/AGI/STA/INT/SPI, melee/ranged AP coefficients, agility-per-crit/dodge, base Dodge/Parry/Block, and an exact Level 1-60 Stat Table.
- Warrior is populated with the Classic class table. Key rows: L1 = 20 BaseHP / 23 STR / 20 AGI / 22 STA / 20 INT / 20 SPI; L20 = 199 / 47 / 35 / 43 / 22 / 26; L60 = 1689 / 120 / 80 / 110 / 30 / 45.
- Warrior AP is data-authored as melee AP = 3*Level + 2*STR - 20 and ranged AP = Level + AGI - 10.
- Stamina health follows Classic old-world behavior: first 20 STA = 1 HP each, later STA = 10 HP each.
- Run HP and Character Sheet stats now derive from the exact current-level class row plus equipment. Fixed HP-per-level growth is removed.
- EnemyGenerator v13 anchors enemy HP to reference player swing damage and enemy damage to reference player max HP from the same class-level curve, before existing archetype/rank/floor/gear/difficulty multipliers.
- Balance QA uses the same Warrior class curve and AP/HP rules as runtime.
- Studio schema 16, Studio 1.15.0, draft v30. Addon version 0.70.0.
- Added static and executable class progression audits.

## 0.69.0 — Generated-only GoblinArcade characters

- Removed the WoW-character-as-roguelike-character model. **Only characters created inside GoblinArcade can appear in the roster or start/resume a dungeon run.**
- Every newly generated hero has authoritative `level = 1` / `startingLevel = 1`, independent of the logged-in WoW character.
- Login initialization no longer snapshots `UnitName`, `UnitLevel`, `UnitClass`, `UnitRace`, health, inventory links or equipped gear.
- Added a generated-only SavedVariables migration:
  - legacy WoW-imported roster entries are removed;
  - suspended runs and action-bar records belonging to those imported entries are removed;
  - real GoblinArcade-generated heroes, Central Stash contents and their saved runs/loadouts are preserved.
- Character selection and difficulty changes reject non-generated records; selection falls back only to another generated hero or to the **Create New Character** slot.
- The empty-roster UI now explicitly says **GENERATED CHARACTERS ONLY** and disables Begin Run until a hero is created.
- Removed the **WoW Gear Input / Arcade Conversion** flow from active runtime behavior. The left-side pre-run panel now explains that WoW level, stats and equipment are ignored.
- Removed live `PLAYER_EQUIPMENT_CHANGED` / item-info listeners and all main-hand scanning/conversion from DungeonRun.
- `CharacterSheet:EnsureArcadeItemConversion()` is now a compatibility no-op; runtime gear must already be native GoblinArcade item data.
- `WeaponGenerator.lua` and `ItemGenerator.lua` remain in repository history but are no longer loaded by either TOC.
- In-run level progression remains the existing GoblinArcade run progression system; this change only removes WoW character conversion and establishes Level 1 as the generated-character starting point.
- Added static + executable generated-character audits proving that legacy WoW roster entries are purged and a newly created hero starts at Level 1.
- Addon version **0.69.0**.

## 0.68.0 — Item / Affix System v2 foundation

- Rebuilt Studio-authored dungeon equipment around **Base Item -> Prefix -> Suffix**.
- Added `AffixSystem.lua` v1 / Itemization v2 with quality-based affix counts and item-level/quality/slot/tier budget scaling.
- Secondary stats now come from data-authored Offense, Defense, Magic and Resistance affixes; Item Bases keep primary stats, HP/Armor, weapon damage/speed/range and signature traits.
- New items persist resolved affix IDs/stat values and never reroll on refresh. Runtime names compose automatically, e.g. **Savage Iron Breastplate of Precision**.
- Tooltips render base primary stats and resolved Prefix/Suffix stat lines.
- Studio **Items** became **Item Bases** and gained separate **Prefixes** and **Suffixes** sections.
- Studio schema **15**, Studio **1.14.0**, local draft **v29**; publish validates/persists both affix arrays.
- ItemDatabase bumped to **v7**. Added static and executable affix audits.
- Existing saved items and WoW-imported equipment retain compatibility; Itemization v2 governs newly built Studio dungeon gear.
- Addon version **0.68.0**.

## 0.67.2 — Full-width Character Stats lower band

- Expanded **CHARACTER STATS** to use the entire lower band, from the paper-doll panel's left edge to the Character Sheet's right margin.
- The screenshot-driven follow-up fixes the cramped right-side resistance layout from 0.67.1.
- The upper portion of the lower band now uses three generous 330px groups: **PRIMARY ATTRIBUTES**, **OFFENSE**, and **DEFENSE**.
- **MAGIC** moved to its own lower-left section with Spell Power, Healing Power and MP5.
- Added a dedicated **RESISTANCES** strip across the rest of the lower band. Arcane, Fire, Frost, Nature and Shadow each render in their own framed cell with a short label and separately aligned value.
- This avoids long "Arcane Resist / Shadow Resist" labels colliding with values and uses the previously empty area below the gear panel.
- Updated the self-hosted UI regression audit for the full-width lower band and dedicated resistance strip.
- Addon version **0.67.2**.

## 0.67.1 — Move Character Stats below Backpack

- Moved the **CHARACTER STATS** panel from underneath the narrow 396px equipment/paper-doll column to underneath the much wider **Backpack** column.
- Backpack is now explicitly the same 446px height as the paper-doll panel, creating a clean aligned upper row.
- The stat panel spans the full right-hand width from the Backpack's left edge to the Character Sheet's right margin.
- Primary, Offense, Defense and Magic/Resistances now sit **side by side in four columns**, giving long labels and derived values substantially more horizontal room while keeping all groups above the sheet bottom.
- The paper-doll column no longer needs to reserve any vertical space for stats.
- Updated the self-hosted UI regression audit to require the Backpack-relative stat placement and four-column layout.
- Addon version **0.67.1**.

## 0.67.0 — Character sheet stat layout redesign

- Reworked the in-run Character Sheet so derived/secondary stats no longer occupy the portrait/paper-doll area between equipment slots.
- The original 396×446 equipment box is now reserved for the portrait, character identity/HP and the two equipment-slot columns.
- Added a separate full-width **CHARACTER STATS** panel directly below the equipment box.
- Stats are presented as proper label/value rows instead of compressed combined strings, with four character-sheet-style groups:
  - **PRIMARY ATTRIBUTES:** Strength, Agility, Stamina, Intellect, Spirit
  - **OFFENSE:** Attack Power, Ranged Attack Power, Weapon Skill, Hit, Critical Strike, Expertise
  - **DEFENSE:** Armor, Defense Skill, Dodge, Parry, Block, Block Value
  - **MAGIC / RESISTANCES:** Spell Power, Healing Power, MP5, Arcane/Fire/Frost/Nature/Shadow Resistance
- Percentage and integer values are formatted independently and stay aligned in their own value column.
- Added self-hosted UI regression checks requiring the lower stat panel and preventing the legacy 156×144 centered stat stack from returning.
- Addon version **0.67.0**.

## 0.66.2 — Fix invisible lighting FX assets

- Fixed the reason the 0.66.1 light sources could be completely invisible in WoW: all three new FX assets are PNG files, but their runtime texture constants omitted the `.png` extension.
- Runtime paths are now explicit:
  - `Media/FX/soft_radial.png`
  - `Media/FX/soft_corner.png`
  - `Media/FX/wall_torch.png`
- This restores the bilinear corner light surface, wall-torch halo/orb, torch sprite and the radial enemy ground shadow, all of which depend on those FX textures.
- Expanded the self-hosted ecosystem tile audit so the FX files must be PNGs and the runtime constants must contain the explicit `.png` paths. This prevents the same silent asset-resolution regression from returning.
- Addon version **0.66.2**.

## 0.66.1 — Smooth light surface + torch light orbs

- Reworked the 0.66.0 dynamic-light presentation to remove the visibly square tile-to-tile transitions.
- The LOS/light calculations still happen on dungeon cells, but the renderer now builds a padded light field and reconstructs the visible result from **shared corner samples**. Four additive corner gradients per tile form a bilinear light surface, so neighboring floor cells meet continuously instead of changing brightness in 96×96 blocks.
- Corner smoothing only averages samples with the same wall/floor state. This keeps floor-to-floor gradients soft while retaining a deliberate visual break at wall boundaries; the underlying LOS and closed-door blocking rules remain authoritative.
- Visible cells now use a consistent ecosystem ambient-darkness layer; the interpolated light surface restores illumination above it. Explored-memory and unseen-cell darkness behavior is unchanged.
- Added `Media/FX/soft_corner.png`, a 64×64 bilinear corner-weight texture used by the four-way interpolation.
- Wall torches now have a distinct **bright emissive light orb** centered on the fixture in addition to the larger soft halo and torch sprite. Both orb and halo inherit deterministic flicker.
- Player light uses the same smoothed light surface as torch light, removing the previous square transition around the character.
- Existing Blob47 wall geometry, contact shadows, procedural torch placement, enemy drop shadows and LOS rules remain unchanged.
- Expanded the self-hosted renderer audit to require the smooth-light pipeline, torch orb, new FX asset and removal of the old single per-tile tint overlay.
- Addon version **0.66.1**.

## 0.66.0 — Dynamic dungeon lighting, wall torches and creature shadows

- Added a lightweight **2D dynamic lighting engine** for the 7×7 dungeon viewport. Visible cells receive ecosystem-specific ambient darkness plus distance falloff from the player and mounted wall torches.
- Light propagation uses the existing dungeon **line-of-sight / closed-door blocking**, so illumination does not simply pass through walls.
- Added deterministic procedural **wall-torch placement** in DungeonGenerator v18. Torches only mount on clean straight wall faces that look onto walkable floor, avoid nearby landmarks/doors/events, and enforce a minimum **5-tile spacing** so fixtures do not pile up.
- Each generated torch stores its floor-side light origin, facing, deterministic flicker phase and small strength variation. A floor normally receives only a small handful of fixtures, scaled by dungeon walkable area and capped at seven.
- Added animated torch flicker at a throttled 0.12 s update cadence without re-rendering the whole dungeon.
- Added authored addon FX assets: `Media/FX/wall_torch.png` and `Media/FX/soft_radial.png`. The radial asset provides local torch bloom and is also reused as a soft elliptical creature ground shadow.
- Every visible living enemy now renders a **soft drop shadow** underneath its sprite.
- Dynamic lighting does not expand player vision or reveal fogged cells; explored memory remains deliberately subdued.
- Existing Blob47 wall autotiling, floor underlay, wall contact shadow and legacy wall fallback remain intact.
- Expanded self-hosted ecosystem/runtime audits for torch placement, spacing, legal floor-facing light origins, lighting hooks, FX assets and WoW texture-sublevel safety.
- Addon version **0.66.0**.

## 0.65.1 — WoW texture sublevel compatibility fix

- Fixed the Orc wall contact-shadow startup error: WoW only permits `Frame:CreateTexture()` sublevels from **-8 through 7**.
- Floor underlay now renders on `BACKGROUND` sublevel `7`, contact-shadow passes on `BORDER` sublevel `7`, and the existing terrain/wall texture remains on `ARTWORK` sublevel `-8`, preserving the intended floor → shadow → wall order without invalid sublevels.
- Extended `tools/ecosystem_tile_audit.py` to verify the runtime layer hooks and reject numeric `CreateTexture()` sublevels outside WoW's legal range.
- Addon version **0.65.1**.

## 0.65.0 — Orc floor material + soft wall contact shadow

- Added the authored Orc-Occupied Crypt floor texture at `Media/Tiles/Floors/orc_occupied_crypt/orc_occupied_crypt_floor01.png`.
- The uploaded `floor01.png` was moved out of the wall-autotile directory into a dedicated per-ecosystem `Media/Tiles/Floors/` layout.
- Orc-Occupied Crypt now sets `floorTexture` to the new floor material in Studio JSON, generated Lua and all three Studio HTML mirrors.
- Autotiled wall cells now render the ecosystem floor underneath the transparent wall atlas, so the wall material sits on the same real floor texture seen in walkable cells.
- Added a **three-pass soft contact shadow** under the exact wall atlas alpha silhouette. Each pass is slightly larger and lower-alpha, creating a feathered AO/shadow transition that follows corners, ends, T-junctions and other Blob47 shapes instead of using rectangular edge strips.
- Memory/fog rendering keeps the effect subdued.
- Legacy `wallTexture` ecosystems are unchanged.
- Addon version **0.65.0**.

## CI runner policy — Windows self-hosted only

- The GoblinArcade audit workflow no longer uses GitHub-hosted `ubuntu-latest` runners.
- `.github/workflows/balance-audit.yml` now targets the same `self-hosted` + `Windows` runner class used by the desktop WoW deployment.
- Lua syntax/runtime audits, Studio JavaScript validation, content audits and all EASY/NORMAL/HARD balance simulations run on the local Windows runner.
- The former multi-job Linux matrix was consolidated into one local audit job to avoid repeating checkout/tool setup and to prevent multiple local jobs from contending for the single desktop runner.
- Python and Node use the desktop runner itself: existing installations are preferred; if Python is absent, a portable official Python 3.12.10 embeddable build is cached locally without an installer, and Node can fall back to the runner's own embedded Node 24. Lua 5.1.5 is built directly from the official Lua source with the desktop Visual Studio C++ toolchain and cached in the runner tool-cache; no Lua setup action or symlink is required.
- GitHub still orchestrates the workflow and stores its logs/status, but no GitHub-hosted runner compute is requested by this audit workflow.

## 0.64.0 — Forever Classic rules engine

- Added central `GoblinArcade/ForeverRules.lua` rules engine (ruleset ID `FOREVER_CLASSIC_BETA`) instead of spreading combat formulas across UI/runtime files.
- Active Warrior gameplay now uses primary **STR / AGI / STA / INT / SPI** and derived Attack Power, Armor, Hit, Crit, Expertise, Weapon Skill, Defense Skill, Dodge, Parry, Block and Block Value.
- Physical Armor now uses the Classic level-based formula `Armor / (Armor + 400 + 85 × attacker level)`, capped at 75%; the old `armor/(armor+100)` arcade formula is removed from active combat.
- Player melee attacks use a single attack table with **Miss → Dodge → Parry → Glancing → Block → Crit → Hit**. Glancing is restricted to basic white attacks.
- Enemy physical attacks use **Miss → Dodge → Parry → Block → Crit → Crushing → Hit** and therefore react to player Defense Skill and shield stats.
- Crit physical damage is 200%; Crushing is 150%; Block subtracts flat Block Value instead of halving all incoming damage.
- Sunder Armor now reduces enemy Armor before mitigation rather than acting as a generic incoming-damage multiplier.
- Rend periodic ticks can critically strike.
- Warrior resource scale is now **0–100 Rage**. Basic attacks generate normalized Rage from weapon speed; 1H and 2H weapons produce different amounts and avoided swings generate none.
- Existing Warrior ability costs/gains were migrated to the 100-Rage scale (e.g. Heroic Strike 15, Charge +15, Bloodrage +20).
- Old suspended runs with the former tiny Rage scale are upgraded on resume.
- Live WoW item snapshots now capture `GetItemStats` when available. Item/weapon conversion emits Forever primary and secondary stats; old extracted gear remains readable through compatibility aliases.
- Studio Items now expose Strength, Agility, Stamina, Intellect, Spirit, Hit, Expertise, Defense, Parry, Block Value, Weapon Skill, Spell Power, Healing Power, MP5 and five magic resistances.
- Character Sheet now shows primary stats, AP, Armor, Weapon/Defense Skill, Hit/Crit, Expertise, Dodge/Parry and Block/Block Value.
- EnemyGenerator v12 attaches level-based Armor/Weapon Skill/Defense and avoidance values through the same rules engine.
- ItemGenerator v5, WeaponGenerator v3 and ItemDatabase v6 use the new stat model.
- Studio schema **14**, Studio **1.13.0**, browser draft key **v28**.
- Added `tools/forever_rules_audit.lua` for formula tests and `tools/forever_runtime_audit.py` for integration/schema/CI regression checks.
- All CI/deploy workflows remain restricted to the user's **self-hosted Windows** runner; no GitHub-hosted runner label is introduced.
- The self-hosted audit provisions `fengari-node-cli` + `luaparse` locally through Node, avoiding any dependency on GitHub-hosted runners or the desktop Visual Studio CRT libraries.
- Runtime audit output is explicitly checked for Lua stack traces because Fengari's Windows wrapper may not propagate every script assertion as a non-zero process exit code; event placement tests validate portable cadence bounds rather than VM-specific seeded room ordering.
- Current scope: the complete active **physical/Warrior combat path** is on the new engine. Resistance, Spell Power and Healing Power are represented in the engine/data model, while future playable caster classes still need their individual spell-resolution/coefficient logic wired when those classes are enabled.
- Addon version **0.64.0**.

## 0.63.0 — Runtime Blob47 wall autotiling

- Wired the Studio-generated **47-tile Blob47 wall atlas** into `DungeonRun`.
- Orc-Occupied Crypt now uses `Media/Tiles/Autotiles/orc_occupied_crypt/orc_occupied_crypt_wall_autotile_47.png`.
- The uploaded atlas + mapping were moved into `GoblinArcade/Media/Tiles/Autotiles/orc_occupied_crypt/` for a stable per-ecosystem asset layout.
- Each rendered wall tile computes an **8-neighbor N/NE/E/SE/S/SW/W/NW mask** from the full dungeon map, applies the same diagonal filtering used by the Studio builder, then selects the matching atlas slot.
- Runtime atlas order is the builder's deterministic **ascending normalized mask** order (47 used cells in the 8×8 / 1024×1024 atlas).
- `SetTexCoord` selects the appropriate 128×128 atlas cell with a half-texel inset to reduce sampling bleed.
- Existing `wallTexture` remains a fallback when `wallAutotileTexture` is empty; floor texture/palette fallback is unchanged.
- Added Studio ecosystem field **Wall Autotile Atlas** and publish validation.
- Studio schema **13**, Studio **1.12.0**, browser draft key **v27**.
- DungeonGenerator **v17** propagates the wall autotile path into every floor map.
- Expanded ecosystem tile CI to validate the physical 1024×1024 PNG, the 47-entry mapping JSON, normalized mask order, runtime hooks and fallback contract.
- Addon version **0.63.0**.

## Studio utility — Procedural wall autotile builder

- Added a **Wall Autotile Builder** directly to each Studio **Ecosystem** editor.
- The builder accepts one isolated **A1 wall source image** and treats it as material input only; tile topology and edge treatment are generated mathematically.
- Default canonical geometry is **80 px / 62.5% wall thickness** in a 128×128 source tile, with a centered 24 px margin.
- Generates all **47 normalized 8-neighbor blob masks** from the standard bit layout N=1, NE=2, E=4, SE=8, S=16, SW=32, W=64, NW=128; invalid diagonals are cleared unless both adjacent cardinal neighbors exist.
- Wall silhouettes are exact binary masks. A padded continuation mask prevents false borders on tile edges where walls connect into neighboring tiles.
- Edge presentation is procedural: configurable stone lip/bevel, dark outer edge and external AO shadow are derived from a chamfer distance field rather than painted into every source tile.
- Edge wear changes shading only and deliberately does **not** perturb the binary wall silhouette, preserving exact seams.
- The uploaded A1 artwork has its edge area inset/cropped and is mirrored into a reusable material field, so painted source borders do not get stretched into internal wall connections.
- The A1 material crop is now permanently anchored to the canonical **80×80** source region at **x/y 24..104**; changing output Wall Thickness no longer moves or enlarges the source crop.
- Source upload now enforces an exact **128×128 PNG** at load time instead of silently rescaling arbitrary dimensions/formats.
- Mapping JSON now includes explicit atlas/source/generator metadata (47 used + 17 reserved slots, ordering, source footprint and edge settings) in addition to per-mask coordinates.\n- Live preview renders a power-of-two **8×8 / 1024×1024** atlas: 47 used slots in ascending normalized-mask order and 17 transparent reserved slots.
- The editor can download both the atlas PNG and a JSON mapping containing mask → atlas index/coordinates and bit definitions.
- If no source image is loaded, a deterministic debug-stone material is used so geometry can be inspected immediately.
- This is currently an **editor asset-generation utility only**; existing runtime wallTexture behavior is unchanged until the atlas consumer is wired into DungeonRun.
- No Studio schema or addon-version bump was required for this editor-only tool.

## 0.62.0 — Ecosystem floor & wall textures

- Added optional **Floor Texture** and **Wall Texture** fields to Studio Ecosystems.
- Paths are addon-local, e.g. `Media/Tiles/orc_crypt_floor.png`; remote HTTP/Cloudflare URLs are rejected because WoW cannot load them at runtime.
- Studio schema **12**, Studio **1.11.0**, browser draft key **v26**.
- Existing ecosystems keep blank texture paths and therefore retain the current palette-only fallback until tile art is assigned.
- DungeonGenerator **v16** propagates the selected ecosystem's floor/wall texture paths into every floor map for the full 9-floor run.
- Dungeon grid cells now have a dedicated terrain texture layer below monsters, loot, events and markers.
- Visible tiles render at full alpha; explored-memory tiles at reduced alpha; unseen tiles reveal no terrain art.
- Existing ecosystem palettes remain as backdrop/border fallback.
- Added Studio/publish validation for local texture paths and CI coverage via `tools/ecosystem_tile_audit.py`.
- Updated the legacy event runtime audit to expect DungeonGenerator v16 so the ecosystem tile release remains fully green in CI.
- Addon version **0.62.0**.

## 0.61.1 — Run-end dungeon visual cleanup

- Fixed stale dungeon enemy sprites / HP bars remaining visible over the character-selection screen after a run ended in death.
- Added `GA:ClearDungeonGridVisuals()`, which explicitly hides all rendered enemy sprites, enemy HP bars, monster skill telegraphs, loot/event icons and the adjacent-enemy combat card.
- `FailDungeonRun()` and `CompleteDungeonRun()` now clear rendered dungeon entities as soon as the run becomes inactive.
- `ReturnToDungeonCharacters()` also clears the render state before restoring setup mode.
- Setup mode now hides the **entire DungeonGrid and spriteLayer**, preventing high-frame-level creature textures from bleeding through the setup overlay. Leaving setup mode restores both layers before the run renders.
- This also hardens abandon / killswitch / suspend return paths because they all converge on setup mode or the direct character-selection helper.
- Added `tools/ui_cleanup_audit.py` to CI to verify the cleanup hooks and setup/run layer visibility contract.
- Addon version is **0.61.1**.

## 0.61.0 — Single-ecosystem dungeon runs

- Added a first-class, Studio-authored **Ecosystem** system. A dungeon run selects exactly **one ecosystem at BEGIN RUN and keeps it for all nine floors**; ecosystems never change between floors.
- Studio schema is now **11**, Studio version **1.10.0**, local draft key **v25**.
- Added Studio sections:
  - **Ecosystems** — dungeon title, enabled state, run-selection weight and visual style preset;
  - **Ecosystem Monsters** — ecosystem/enemy relationship, floor band and relative spawn weight.
- Added three initial ecosystem definitions:
  - **Orc-Occupied Crypt** — enabled, 70 run weight, `ORC_CRYPT` style;
  - **Kobold Warrens** — enabled, 30 run weight, `WARREN` style;
  - **Haunted Catacombs** — authored but disabled until the undead roster is broad enough for a full 9-floor run.
- Orc-Occupied Crypt has four depth bands. Early floors favor Raiders, Bonepickers and Gravediggers; mid floors introduce Berserkers, Bonebreakers, Hexers, Warcallers and Tomb Sentinels; deep floors introduce Plague Eaters and Grave Champions; Floor 9 strongly favors the high-tier crypt orcs.
- The existing Spider and Skeleton can appear as low-weight native crypt fauna where appropriate instead of every monster pool being an unrelated global mix.
- Kobold Warrens retains Kobold + Spider ecology and introduces Brutes from Floor 4 onward, with Brutes becoming more common at depth.
- Events now have **Allowed Ecosystems**. Random event selection filters by the run ecosystem, and chained event injection rejects cross-ecosystem events.
- Existing events are mapped coherently:
  - Abandoned Camp → Orc Crypt / Kobold Warrens;
  - Bloodstained Altar → Orc Crypt / Haunted Catacombs;
  - Forgotten Cache → all currently authored ecosystems;
  - Wounded Goblin → Orc Crypt / Kobold Warrens;
  - Goblin Smugglers → Orc Crypt / Kobold Warrens.
- DungeonGenerator is now **v15**. It deterministically selects the run ecosystem from the dungeon seed, exposes ecosystem metadata on every floor map, and uses the ecosystem dungeon title instead of the old universal `THE SHIFTING CELLAR` title.
- FloorGenerator is now **v5**. Enemy composition comes from the selected ecosystem's depth-band records; the old Kobold/Spider/Skeleton mix remains only as a compatibility fallback for old/malformed data.
- DungeonRun persists `ecosystemId`, `ecosystemName` and style for the run and passes the same ecosystem to every newly generated floor, including after backtracking.
- Added ecosystem-specific dungeon palettes. The main grid now uses a warm rust/bone crypt palette for Orc Crypt, earthy warren palette for Kobolds, and has cold haunted / plague presets ready for future ecosystems.
- The headless balance simulator now selects one enabled ecosystem per simulated run and holds it across all nine floors instead of using the old global archetype mix.
- Added `tools/ecosystem_audit.py` and `tools/ecosystem_runtime_audit.lua`. CI verifies:
  - every enabled ecosystem has a non-empty monster pool on Floors 1–9;
  - every enabled ecosystem has enough eligible random event definitions for the configured event cadence;
  - monster/event references are valid;
  - ecosystem choice is deterministic per run seed;
  - an explicit ecosystem remains unchanged across all nine generated floors;
  - enemy plans contain only ecosystem-legal monsters;
  - cross-ecosystem chained events are rejected.
- Addon version is **0.61.0**.

## 0.60.1 — Orc monster pack

- Added the ten uploaded crypt-orc sprites as first-class Studio **Enemies**:
  - Orc Raider
  - Orc Berserker
  - Orc Bonebreaker
  - Orc Bonepicker
  - Orc Grave Champion
  - Orc Gravedigger
  - Orc Hexer
  - Orc Plague Eater
  - Orc Tomb Sentinel
  - Orc Warcaller
- Every orc has an individual three-skill kit (30 new Monster Skills total) built only from the already-supported, headless-tested monster effect system.
- Roles are intentionally differentiated: skirmisher, frenzy melee, heavy control, scavenger, miniboss champion, space-control bruiser, ranged hexer, disease attrition, defensive sentinel and warcaller.
- Uploaded PNG files remain the canonical sprite assets; enemy records point directly at their exact `Media/Monsters/*_128x128.png` paths.
- Dungeon enemy visuals are now **data-driven** for non-hardcoded enemies: `DungeonRun.lua` resolves the Studio Enemy `sprite` path for both grid sprite and target portrait. Kobold / Spider / Skeleton keep their existing visual overrides.
- Studio stays on schema **10**, advances to version **1.9.1**, and local draft key is now **v24** so existing browser drafts cannot hide the newly published enemy/skill defaults.
- Addon version is **0.60.1**.
- Added `tools/orc_content_audit.py` plus a CI **Monster content** job. It verifies all ten enemy records, all 30 assignments, supported skill effects/conditions and the physical sprite files.
- This release deliberately does **not** add the orcs to the current floor spawn mix yet. They are data/runtime-ready for the upcoming dungeon-biome population pass, avoiding an accidental balance change before biome rules are authored.

## 0.60.0 — Event Conditions, Costs, Run Flags & Chains

- Added a dedicated pure-Lua **EventEngine v1** so event decision logic is data-driven and headless-testable instead of being hardcoded into the dungeon UI.
- Studio schema is now **10**, Studio version **1.9.0**, local draft key **v23**.
- Added a first-class **Event Flags** editor. Event Options can require, forbid, set and clear run-scoped flags through relation-list controls.
- Event Options now support availability requirements for:
  - current HP percentage;
  - minimum / maximum dungeon floor;
  - one or more classes;
  - equipped gear type (shield, 2H, 1H, weapon, armor or armor family);
  - minimum Copper;
  - one or more backpack items and quantities;
  - required and forbidden run flags.
- Unavailable choices can be authored as **DISABLE** (visible with the reason in the tooltip) or **HIDE**.
- Event Options now support transactional costs:
  - HP percentage;
  - run Copper;
  - backpack items / quantities.
- Costs are paid only once when a choice is committed. A loot reward blocked by a full backpack keeps the exact pinned reward and does not charge the cost again on retry.
- Every authored Event must keep at least one unconditional fallback choice, preventing a data-authored event from soft-locking the run.
- Added follow-up Event queues. An option can queue one or more future Events with a floor delay; queued encounters are run-level state and survive backtracking and suspend/resume.
- Events now have **Random Spawn = YES/NO**. NO makes an event chain-only while still allowing deterministic injection by a queued consequence.
- DungeonGenerator is now **v14** and exposes deterministic chain-event injection while preserving one-event-per-room and START / EXIT / SHOP / BOSS protection.
- Added the first authored chain:
  - **Wounded Goblin** can be helped for a 10% max-HP cost;
  - helping sets `helped_griznak` and queues **Goblin Smugglers** two floors later;
  - Goblin Smugglers is chain-only, and **Griznak Sent Me** is hidden unless the required run flag exists;
  - resolving that response clears the flag and awards run Copper.
- Added server-side publish validation for all new references/ranges and self-queue prevention.
- CI now includes:
  - Event data/reference audit;
  - DungeonGenerator random-vs-chain injection audit;
  - EventEngine headless requirement/cost/flag/queue audit;
  - existing Lua syntax, Studio mirror/JS syntax and Easy/Normal/Hard balance audits.
- Baseline combat balance formulas, loot tables, item stats and difficulty multipliers are unchanged by this release.

## 0.59.1 — dungeon event hardening

- Fixed Event Rules cadence so `extraEveryFloors = 5` starts the second event on **Floor 5**, not Floor 6.
- Event placement now hard-protects **START / EXIT / SHOP / BOSS** rooms in the first framework even if an event is accidentally related to one of those roles. `floorMap` also records explicit `eventPlacements` metadata.
- Added explicit per-floor `eventStates` with resolved state, selected option ID, result metadata and pending loot reward state. Floor capture/restore, backtracking and suspended runs preserve it; older saved runs lazily reconstruct event state from their existing markers.
- Event option execution now goes through the generic `GA:ResolveDungeonEventOption(optionId)` resolver.
- `DAMAGE_PERCENT` and `HP_FOR_SCORE` are now genuine risks and may kill the hero through the normal `FailDungeonRun` path. The old 1-HP clamp/free-score edge case is removed.
- `DAMAGE_BONUS` now has its own run-wide `eventDamageBonus` state and stacks with shrine damage bonuses without sharing the shrine cap.
- `LOOT_TABLE` choices pin the exact rolled reward when the backpack is full. The event stays unresolved and retries the same item after space is made instead of rerolling or silently losing it.
- An opened Event is now a committed decision point: **ESC and the Options menu cannot dismiss it**. Authors who want a safe exit provide a Studio `NONE` option such as **Turn Away**.
- Server-side Studio publishing and the event-data audit now also reject HTTP event icons and negative Event Option sort order values.
- Added a Lua 5.1 generator runtime audit covering Floors 1-9 event cadence, placement metadata, one-event-per-room behavior and protected structural room roles.
- Studio stays at **1.8.0 / schema 9**. The existing balance simulator still does not model event-choice rewards; baseline enemy HP/damage/XP, loot and shop balance formulas are unchanged.

## 0.59.0 — data-driven dungeon event system

- Added a complete **Dungeon Event** system. Events are authored in GoblinArcade Studio; event identities and choices are not hardcoded into `DungeonRun.lua`.
- Studio schema is now **9**, Studio version **1.8.0**, with three new editable datasets:
  - `Event Rules`: controls base events per floor, progression cadence and the per-floor cap;
  - `Events`: name, WoW icon, fallback marker, map color, enabled state, floor range, spawn weight and allowed room roles;
  - `Event Options`: parent event, order, generic effect, values, optional loot table, result text and tooltip hint.
- Event placement is deterministic from the dungeon floor seed and uses the configured weighted pool. Event definitions are unique within a floor and are placed only in allowed room roles on free interior tiles.
- Current published placement rule: **1 event per floor**, increasing to **2 from Floor 5**, capped at 2.
- Added three initial Studio-authored events:
  - **Abandoned Camp** — rest for healing or search its packs for treasure loot;
  - **Bloodstained Altar** — trade current HP for score or walk away;
  - **Forgotten Cache** — roll treasure loot or salvage it for Copper.
- Runtime supports generic event-option effects: `NONE`, `HEAL_PERCENT`, `DAMAGE_PERCENT`, `HP_FOR_SCORE`, `DAMAGE_BONUS`, `MAX_HP_PERCENT`, `COPPER`, `SCORE`, and `LOOT_TABLE`.
- Event tiles render their Studio-configured WoW icon, remain dimly visible after discovery through Fog of War, and appear on the minimap using the configured event color.
- Stepping onto an event advances the enemy phase before the event choice opens, matching shrine/shop turn semantics.
- The event modal supports up to four data-authored choices and keyboard shortcuts 1-4. ESC closes it without consuming the event; returning to the tile reopens it.
- A resolved event removes its marker from the floor. Loot-table choices do not resolve if the backpack is full, so the reward is not silently lost.
- Run statistics now track resolved Events, and Event score has its own score-breakdown bucket.
- Event placement survives floor backtracking/suspension because it is part of the generated/stored `floorMap`.
- Publishing validates event references, room-role references, loot-table references and the 1-4 option limit server-side.
- Added `tools/event_audit.py` and a dedicated **Event data** GitHub Actions job.
- The existing balance simulator does not model event rewards yet; combat difficulty formulas themselves are unchanged in this release.

## 0.58.1 — dungeon loot item icons

- Unopened dungeon loot/cache tiles now render the **actual rolled item's own icon** instead of the generic `$` glyph.
- The icon is sourced from the item instance already rolled into `run.chestLoot`, so Studio item icons are used directly.
- Discovered loot remains visible through Fog of War memory at reduced opacity.
- Empty/fallback containers keep their existing marker behavior.
- Opening the container still removes the dungeon marker/icon exactly as before.
- Enemy sprites remain above loot icons when they occupy the same visible tile.
- No loot tables, drop rates, inventory rules or chest interaction behavior changed.

## 0.58.0 — monster identity mechanics pass

- Authored complete first-pass skillsets for every current enemy archetype.
- **Kobold**
  - Sling Stone: ranged chip damage from Floor 3;
  - Desperate Slash: stronger melee strike below 40% HP from Floor 3;
  - Pocket Sand: short movement slow from Floor 5.
- **Spider**
  - Venom Bite: melee damage + short poison DoT from Floor 4;
  - Web: ranged one-turn root from Floor 4;
  - Venom Spit: weaker ranged poison DoT from Floor 6.
- **Skeleton**
  - Heavy Swing: one-turn telegraphed heavy strike from Floor 5;
  - Grave Chill: ranged movement slow from Floor 6;
  - Reassemble: telegraphed 16% self-heal below 30% HP from Floor 7, effectively once per encounter via a 99-turn cooldown.
- **Brute**
  - Crushing Blow: telegraphed high-damage attack from Floor 5;
  - Headbutt: immediate lighter melee attack from Floor 6;
  - Ground Tremor: telegraphed short movement slow from Floor 7;
  - Second Wind: telegraphed 14% self-heal below 28% HP from Floor 8, effectively once per encounter.
- Veteran / Elite / Boss ranks inherit the archetype skillset and combine it with their normal rank stat scaling.
- Raw enemy HP and base damage formulas are unchanged in this content pass.
- Studio local draft key bumped to **v21** so an older v20 browser draft cannot silently overwrite the new published skillsets.
- Studio publish validation now rejects enemy records that reference missing Monster Skills.
- Studio version = **1.7.1**.

## 0.57.1 — Monster Skill floor gating + Studio QA

- Added **Min Floor** to Monster Skills so mechanics can be introduced progressively instead of overloading early floors.
- Current authored unlock floors:
  - Kobold Desperate Slash: Floor 3+
  - Spider Venom Bite: Floor 4+
  - Spider Web: Floor 4+
  - Skeleton Heavy Swing: Floor 5+
  - Brute Crushing Blow: Floor 5+
- This follows the first 0.57 headless audit, where immediate skill access pushed Normal Floor 3 clear rate down to roughly 76%.
- Added automated **Studio syntax** CI:
  - verifies all three Studio HTML mirrors are byte-identical;
  - extracts inline JavaScript and runs `node --check`.
- Lua 5.1 syntax validation and Easy/Normal/Hard balance audits remain mandatory.

## 0.57.0 — Monster Skill System + Studio editor

- Added a new Studio **Monster Skills** section using the same data-driven philosophy as player abilities.
- Monster Skill fields include:
  - ID, name and WoW icon;
  - effect type and target;
  - damage multiplier / effect values;
  - duration, cooldown and range;
  - AI weight;
  - use condition + condition value;
  - optional telegraph turns.
- Supported runtime effects in the first pass:
  - **DAMAGE**
  - **DAMAGE_DOT**
  - **ROOT**
  - **SLOW**
  - **HEAL**
  - **BUFF_DAMAGE**
- Supported AI conditions:
  - ALWAYS
  - ADJACENT
  - RANGE_MIN
  - SELF_HP_BELOW
  - TARGET_HP_BELOW
  - EVERY_N_TURNS
  - ONCE_PER_COMBAT
- Enemy records now contain an **Abilities** relation list. Studio uses a dropdown + ADD flow and removable rows rather than a wall of checkboxes.
- Initial authored skills:
  - Kobold: **Desperate Slash**
  - Spider: **Venom Bite**, **Web**
  - Skeleton: **Heavy Swing**
  - Brute: **Crushing Blow**
- Telegraph skills consume their wind-up enemy action and show the skill's WoW icon on the monster tile. If the player moves out of range before resolution, the attack loses its opening.
- Monster cooldowns, pending telegraphs and skill use counts are part of the enemy runtime state and therefore persist with floor backtracking/saved floor state.
- Web-style root blocks movement for the configured duration but still allows non-movement player actions.
- Monster DoTs are tracked separately from player ability effects and tick on subsequent player turns.
- Difficulty scaling continues to apply underneath Monster Skills because damage skills scale from the enemy's already-difficulty-scaled damage profile.
- Headless balance QA now reads `monsterSkills` and enemy skill assignments, and models direct/DoT/telegraphed combat pressure.
- Studio schema = **8**, Studio version = **1.7.0**, local draft key = **v20**.
- EnemyGenerator version = **11**.

## 0.56.0 — independent difficulty + Hardcore modes

- Hardcore/permadeath and combat difficulty are now **independent settings**.
- Difficulty choices:
  - **Easy**: enemy HP ×0.85, enemy damage ×0.85, score ×0.80.
  - **Normal**: enemy HP ×1.00, enemy damage ×1.00, score ×1.00.
  - **Hard**: enemy HP ×1.12, enemy damage ×1.10, score ×1.25.
- Normal keeps the accepted 0.55.0 baseline unchanged.
- Difficulty does **not** change XP, Copper rewards, loot tables, potion drops or shop prices.
- Headless Warrior audit (2,500 runs per build/scenario) produced:
  - Easy PRESSURE completion ≈ **84.5% shield / 84.9% 2H**.
  - Normal PRESSURE completion ≈ **71.7% shield / 72.5% 2H**.
  - Hard PRESSURE completion ≈ **39.2% shield / 45.0% 2H**.
  - Floor 6 shop affordability stayed around **3.3–3.4 / 4** offers on every difficulty.
  - End-of-run temporary level stayed around **12** on every difficulty.
- Character creator now separates **PERMADEATH** (Standard / Hardcore) from **DIFFICULTY** (Easy / Normal / Hard).
- Difficulty can also be changed from the selected-hero panel before a run, including for cached WoW characters and older generated heroes.
- Difficulty cannot be changed while a run is active or saved; suspended runs preserve their original difficulty.
- Existing characters migrate to **Normal** automatically.
- Run metadata, saved runs, enemy generation, run summary and score calculation now persist/use the selected difficulty.
- EnemyGenerator version = **10**.
- Automated balance workflow now audits Easy, Normal and Hard in parallel.

## 0.55.0 — automated Warrior balance pass

- Automated headless QA showed the 0.54.1 durability curve was too forgiving:
  - clean 1v1 completion was about **99.5%**;
  - even HEAVY_PRESSURE remained about **98%**;
  - enemies commonly died in only **1–2 player attacks**.
- A flat **5.0×** base-HP candidate was tested and rejected because it made the opening disproportionately punishing:
  - Floor 1 clear fell to about **82%**;
  - Floor 2 conditional clear fell to roughly **17% shield / 30% 2H**.
- The accepted tuning changes enemy durability only:
  - Base Enemy HP = `Reference Damage × 3.25` (was ×2.50);
  - Floor HP Multiplier = `1 + 0.15 × (Floor - 1)` (was +0.07/floor);
  - EnemyGenerator version = **9**.
- Enemy damage remains unchanged at **4% Reference Player HP** before existing archetype/rank/floor/gear modifiers.
- Accepted candidate audit:
  - Floor 1–2 clear remains effectively **100%** for both Warrior profiles;
  - PRESSURE full-run completion is about **71–74%**;
  - HEAVY_PRESSURE completion is about **69–71%**;
  - shield vs 2H completion gap is about **2.5 percentage points**;
  - Floor 6 entry wallet stays around **3.4k–3.8k Copper (p10–p90)**;
  - about **3.36 / 4** Floor 6 shop offers are affordable at entry;
  - the run still finishes around temporary **Level 12**.
- XP, Copper rewards, potion drop chance, item stats and shop prices are unchanged.

## Automated balance QA

- Manual balance playthroughs are no longer required from the user as the primary tuning loop.
- `tools/balance_audit.py` runs deterministic Monte Carlo balance checks directly from `studio-data.json` and mirrors the live enemy, XP, Copper, loot, equipment and potion formulas.
- The audit reports both:
  - **SEQUENTIAL**: optimistic clean one-on-one combat;
  - **PRESSURE**: a bounded multi-aggro sensitivity test so balance is not tuned only around sterile duels.
- The audit compares 1H+shield and 2H Warrior profiles, floor-by-floor damage, attacks-per-kill, potion use, temporary levels, Floor 6 shop Copper and affordability.
- GitHub workflow `.github/workflows/balance-audit.yml` reruns the audit automatically when relevant runtime/Studio balance files change, and can also be triggered manually.
- The audit is a headless balance/logic model, not a replacement for WoW rendering/API integration; visual regressions still require screenshot/static UI inspection when relevant.

## 0.54.1 — viewport spacing and manual stair travel

- The dungeon body now extends slightly farther downward so the 7×7 viewport no longer sits on top of the lower gold separator/border.
- Floor transitions are no longer triggered automatically by stepping onto the start/exit stair tile.
- Standing on a valid stair tile now reveals a third **Quick Access** icon:
  - **ASCEND** on the entrance stairs of Floors 2–9;
  - **DESCEND** on the exit stairs of Floors 1–8;
  - **EXIT** on the final Floor 9 exit after the boss seal is cleared.
- The stair button uses a WoW dungeon icon and a dynamic tooltip showing the target floor.
- Moving onto a stair tile remains a normal movement turn; using the Quick Access stair button itself does not add a second turn.
- Floor 9's boss-gated exit remains sealed until the Boss-rank enemy is defeated.
- Existing bidirectional floor-state persistence is unchanged: returning to a visited floor restores its exact saved exploration, enemies, room rewards and objects.

## 0.54.0 — cleaner combat HUD and in-world enemy HP bars

- Addon **0.54.0** removes presentation-only enemy intent text from the combat UI.
- Enemy AI still keeps its internal intent state for behavior, stagger/fear/movement logic, but WATCHING / ALERTED / MOVING / ATTACKING / STAGGERED are no longer printed to the player.
- The right-side adjacent-enemy card now shows:
  - enemy name + level;
  - numeric HP;
  - Danger Rating only.
- Every currently visible living enemy now has a compact red HP bar directly above its sprite on the dungeon grid.
- Enemy HP bars:
  - render only while the enemy itself is visible through Fog of War;
  - update from the live `hp / maxHp` values every grid render;
  - disappear automatically when the enemy leaves vision, moves off-camera or dies.
- Routine `PLAYER TURN` / `ENEMY TURN` status text has been removed from the run HUD.
  - after an ordinary enemy phase the state line is blank;
  - meaningful one-shot messages such as level-up, blocked movement, sealed boss exit and errors remain;
  - `KOBOLDBOYS DEFEATED`, `DOOR OPENED`, `POTION USED`, etc. no longer carry turn-prefix noise.
- The active-run bottom button is now labeled **OPTIONS** instead of **RUN MENU**.
- The run-control modal title is also **OPTIONS**.
- Run lifecycle behavior is unchanged: Abandon Run, Save & Switch and Killswitch still work exactly as before.
- Studio data is unchanged from 1.6.2: **100 items / 366 Loot Entries**, Warrior `HP / Level = 3`, single Floor 6 Shop.

## 0.53.0 — first full Warrior Floor 1-9 balance pass

- Addon **0.53.0** is the first coherent end-to-end balance pass for the 9-floor Warrior run.
- Studio data moves to **1.6.2 / schema 7** and the Studio browser cache key moves to `goblinArcadeStudio.v19`.
- Canonical Studio HTML files remain byte-identical.
- The published catalog remains **100 items / 366 Loot Entries**; this pass changes progression and weights rather than adding item quantity.
- Warrior `HP / Level` remains exactly **3**.

### Run XP / tier timing

Goal: a fresh level-1 Arcade Warrior should naturally reach the item gates during the same 9-floor run instead of finding late-tier gear that can never become usable.

Published progression:

```
XP per Danger: 9

Level-up costs:
80, 90, 100, 110, 125, 140, 155, 175
then ×1.10 per additional level
```

With a standard-density run and the new rank curve, the approximate level cadence for a level-1 Arcade Warrior is:

```
after F1  -> Level 2
after F2  -> Level 3   (T2 usable)
after F3  -> Level 4
after F4  -> Level 5
after F5  -> Level 7   (T3 usable)
after F6  -> Level 8
after F7  -> Level 9   (T4 usable)
after F8  -> Level 11
during F9 -> Level 12  (T5 usable)
```

This is an expected standard-run cadence, not a guaranteed fixed level, because density/archetype/rank composition still varies inside bounded limits.

### Encounter population

`FloorGenerator.VERSION = 4`.

Base enemy count is now depth-driven rather than derived from procedural walkable-tile count:

```
F1 6
F2 6
F3 7
F4 7
F5 8
F6 8
F7 9
F8 9
F9 10
```

Density remains a one-time per-floor roll but has been tightened:

```
QUIET     20% -> ×0.90
STANDARD  60% -> ×1.00
CROWDED   20% -> ×1.10
```

This keeps different layouts on the same floor in the same encounter band instead of letting room/corridor RNG indirectly change combat volume.

### Rank ramp

Normal/Veteran/Elite mix:

```
F1-2: 100 / 0  / 0
F3-4:  80 / 20 / 0
F5-6:  75 / 25 / 0
F7-8:  60 / 30 / 10
F9:    45 / 35 / 20
```

The dedicated Elite room on Floors 5-9 still forces an Elite anchor, and Floor 9 still forces its Boss anchor. Random Elite weight was removed from F5-6 specifically so the first elite encounter is a readable dungeon event rather than background rank noise.

Studio/runtime rank stats are now:

- Normal: HP ×1.00 / damage ×1.00
- Veteran: HP ×1.30 / damage ×1.12
- Elite: HP ×1.80 / damage ×1.30
- Boss: HP ×3.60 / damage ×1.60

Rank XP multipliers remain 1.00 / 1.35 / 2.00 / 5.00.

### Enemy pressure

`EnemyGenerator.VERSION = 8`.

Base formulas:

```
Reference Damage = 5 + Effective Enemy Level × 0.90
Base Enemy HP = Reference Damage × 3.25

Reference Player HP = 100 + Effective Enemy Level × 20
Average Enemy Damage = Reference Player HP × 4.0%
Damage roll = 80%-120% of that deterministic average
```

Floor pressure:

```
HP multiplier     = 1 + 0.15 × (Floor - 1)
Damage multiplier = 1 + 0.05 × (Floor - 1)
```

Reference:
- F1: HP 1.00 / damage 1.00
- F5: HP 1.28 / damage 1.20
- F9: HP 1.56 / damage 1.40

The target shape is readable F1-2 normals, a clear mid-run step at the first Elite room, and genuinely threatening F7-9 Veterans/Elites/Boss without changing the global combat-number divisor.

### Copper / Floor 6 shop

Kill Copper is reduced from `floor × 40 + danger × 25` to:

```
floor × 20 + danger × 15
```

Copper rank multipliers are now:

- Normal 1.00
- Veteran 1.40
- Elite 2.25
- Boss 5.00

A standard expected run now reaches Floor 6 with roughly **5.1k Copper before sales**, instead of enough raw kill Copper to trivialize most shop decisions. The intent is:
- T3 purchases are realistic;
- a T4 purchase is a meaningful spend;
- premium T4 / 2H offers may require selling carried loot;
- Copper remains run-only.

The Floor 6 shop itself remains the single merchant and retains its existing T3-majority / T4-preview stock weights.

### Potion pressure

`common_enemy_drops` drop chance is reduced from **15% to 10%**. The table still drops only the floor-appropriate healing potion.

Potion healing values are unchanged:
25% / 35% / 45% / 55% / 70%.

This is tuned around the new three-item pre-run supply system: preparation matters, but dungeon potion drops are still common enough to support recovery across nine floors.

### Treasure tier pacing

Treasure-room tier mixes now are:

```
F1  T1 100%
F2  T1 80% / T2 20%
F3  T2 100%
F4  T2 70% / T3 30%
F5  T3 100%
F6  T3 70% / T4 30%
F7  T4 100%
F8  T4 85% / T5 15%
F9  T4 50% / T5 50%
```

This makes late T5 finds relevant to the new level-12 endgame cadence rather than being almost entirely Boss-Cache-only.

Elite Cache, Boss Cache and Shop item pools are intentionally unchanged in this first pass so not every reward axis is moved at once.

### 1H + shield versus 2H

No raw weapon/shield item stats were rewritten in 0.53.0. This is deliberate because extracted Studio items persist their generated stat payloads; silently changing item definitions would create old/new versions of the same named item in existing stashes.

The current tradeoff remains:
- 2H = substantially higher per-hit damage and stronger AP conversion from slow weapon speed;
- 1H + shield = armor, block, an occupied defensive slot, and access to shield-required Warrior abilities.

The next playtest should compare actual damage taken / turns-to-kill for both builds on Floors 5-9. If the gap is too wide, do a versioned item-stat migration rather than creating invisible legacy-item discrepancies.

### Validation target

- 100 items
- 366 Loot Entries
- single Floor 6 Shop
- Warrior `HP / Level = 3`
- combat divisor remains 10
- existing Central Stash / BASELINE / LOADOUT / FOUND ownership rules unchanged
- existing 3-slot pre-run supply system unchanged

**Next priority after 0.53.0:** playtest one fresh/generated Warrior run and one geared WoW Warrior run through at least Floor 6, then tune based on observed HP loss, potion use, level timing, Copper at merchant, and 1H+shield versus 2H performance.

## 0.52.0 — pre-run supplies, ownership states and Misc-item clarity

- Addon **0.52.0** completes the first pre-run consumable/supply loop.
- Every persistent character now has `arcadeSupplies` with exactly **3 pre-run supply slots**.
- Central Stash consumables can be clicked to prepare them for the selected hero:
  - one click moves **one consumable unit**, not a whole stack;
  - maximum **3 total supply items**;
  - prepared items physically leave the Central Stash, so there is no duplication.
- Prepared supplies can be clicked in the loadout UI to return them to the Central Stash before the run starts.
- The Central Stash modal is taller and now has three explicit sections on the right:
  - selected hero;
  - **PRE-RUN SUPPLIES 0/3**;
  - **GEAR LOADOUT**.
- Starting a fresh run commits prepared supplies:
  - prepared supply slots are emptied from the persistent character record;
  - the items are inserted into the first available run-backpack positions;
  - each supply remains a single unit;
  - they are tagged as `ownershipSource = "loadout"`, `supplyLoadout = true`, with no current `acquiredRunId`.
- Run outcome rules for committed supplies:
  - consumed supplies are gone;
  - unused supplies return to Central Stash on successful Floor 9 extraction;
  - failed, abandoned or Killswitch runs lose committed supplies along with found run loot;
  - SAVE & SWITCH preserves them because the exact run backpack is suspended.
- Successful extraction reports how many unused supply items were returned separately from newly extracted found loot.
- Character deletion returns any still-prepared pre-run supplies to Central Stash before deleting the hero.
- Suspended-run anti-dupe locking also applies to supply changes.
- Runtime item ownership is now explicit:
  - `baseline` = WoW/starter gear;
  - `loadout` = persistent extracted gear or supplies brought into the run;
  - `found` = loot acquired during the current run;
  - successful extraction converts FOUND items to persistent `extracted` stash ownership.
- `AddItemToBackpack()` now marks newly acquired run items as **FOUND** without altering baseline/loadout items moved directly between inventory slots.
- MISC investigation:
  - the current 100-item Studio catalog contains **no standalone `MISC` category items**;
  - there are 15 jewelry/trinket items whose subtype is `Miscellaneous`;
  - all 15 have valid equip locations: Finger, Neck or Trinket;
  - therefore `Miscellaneous` in the old tooltip was a subtype label, not an equipment destination.
- Character Sheet tooltips now explicitly show the equipment slot (for example Finger / Neck / Trinket) and `Requires Run Level X`.
- If a found Studio item cannot be equipped because the current temporary Run Level is too low, the combat log now states the exact required Run Level instead of only saying the placement is invalid.
- Truly non-equippable future items now produce an explicit `not equippable; keep it as loot or sell it` message.
- Central Stash tooltips also show equipment slot and required Run Level, reducing ambiguity around `Miscellaneous` jewelry.
- Studio data itself is unchanged: **100 items**, **366 Loot Entries**, one Shop on Floor 6, Warrior `HP / Level = 3`.
- Next major step: full Warrior Floor 1-9 balance pass across enemy scaling, XP, item tiers, Copper/shop affordability, potion pressure and 1H+shield vs 2H builds.

## 0.51.0 — branded Home screen and UI media folder

- Addon **0.51.0** adds the new GoblinArcade Home branding.
- The uploaded `GoblinArcade/Media/Monsters/ga_logo.png` asset is copied into a new UI media folder at:
  - `GoblinArcade/Media/UI/ga_logo.png`
- The original Monsters copy is intentionally left in place because this change is a copy/reorganization rather than a destructive move.
- Home no longer shows:
  - `Goblin Arcade - created by Midnight Traveler.`
- Home now shows:
  - the new `ga_logo` centered in the content area;
  - `created by Nightstrider` centered directly underneath.
- The logo is rendered at **520 x 520** and uses the UI-media path rather than the Monsters path.
- The main application header and navigation are otherwise unchanged.
- Gameplay, itemization, Central Stash, suspend/resume and 2H inventory mechanics are unchanged.

## 0.50.0 — in-run two-handed weapon hand management

- Addon **0.50.0** adds correct in-run hand occupancy for two-handed weapons.
- Equipping an `INVTYPE_2HWEAPON` into **Main Hand** now automatically unequips the current **Off Hand** item.
- The displaced Off Hand item can be any valid off-hand type:
  - one-handed weapon;
  - off-hand-only weapon;
  - shield;
  - holdable.
- The displaced Off Hand item is moved into the run backpack instead of being destroyed.
- The move is transactional:
  - if the incoming 2H weapon comes from a backpack slot and Main Hand is empty, that newly freed source slot can receive the Off Hand;
  - if Main Hand already contains an item, that old Main Hand swaps into the incoming weapon's backpack slot and the Off Hand requires another empty backpack slot;
  - if there is no valid backpack slot, the 2H equip is rejected before any inventory state changes.
- A full-backpack failure logs: `Backpack full: free a slot before equipping a two-handed weapon.`
- While a 2H weapon is equipped in Main Hand, dropping a weapon/shield/holdable into Off Hand is rejected and logs a dedicated warning.
- Forced Off Hand movement preserves the original item object and ownership metadata exactly:
  - baseline/starter gear stays baseline;
  - extracted/run-acquired gear keeps its existing acquisition state;
  - moving baseline gear to the backpack does **not** falsely convert it into extractable run loot.
- Gear stats, current weapon display, Character Sheet and action buttons are recalculated immediately after the successful 2H equip.
- Pre-run Central Stash loadout behavior remains unchanged: a 2H stash loadout still suppresses / returns extracted Off Hand overrides according to the persistent-loadout rules.
- Item data remains **100 items**, **366 Loot Entries**, single Floor 6 Shop, Warrior `HP / Level = 3`.

## 0.49.0 — centered character-select UI and WoW-style weapon presentation

- Addon **0.49.0** is a focused presentation pass for the Dungeon Run character-selection screen.
- The setup UI now uses a fixed **900 px centered content frame** instead of placing the roster against the far-left edge of the full overlay.
- Character roster and Selected Hero panels are now a balanced two-column composition:
  - Characters: **410 x 480**;
  - Selected Hero: **470 x 480**;
  - 20 px gap;
  - both panels share the same top alignment and height.
- Character rows are wider and slightly taller for cleaner name/meta spacing.
- Central Stash is now a **220 x 44** top-right button inside the centered content header.
- Central Stash button now includes a real WoW bag icon (`INV_Misc_Bag_10`) and keeps the live stash item count in its label.
- Selected Hero header spacing was tightened and cleaned up.
- Run Loadout is now a dedicated **item card** rather than three loose text lines.
- The visible weapon card shows:
  - item icon;
  - quality-colored item name;
  - item level;
  - hand/type;
  - damage;
  - WoW-like numeric weapon speed;
  - range;
  - Attack Power when present;
  - green `Equip:` trait text.
- Hovering the weapon card opens a structured WoW-style GameTooltip:
  - quality-colored name;
  - Item Level;
  - hand/type on a double line;
  - damage and numeric speed on a double line;
  - range;
  - Attack Power;
  - green Equip trait and description;
  - build profile;
  - Run Level requirement;
  - baseline/extracted ownership state;
  - sell value.
- Saved-run / hero-state messaging now lives in its own bordered status box instead of floating above the action buttons.
- Saved runs display Floor, HP and Score in the status box and use a highlighted **SAVED RUN** header.
- Dead Hardcore heroes use a red **HARDCORE MEMORIAL** status treatment.
- The two Selected Hero action buttons are now exactly the same size: **212 x 42**.
  - Left: Delete Hero or Abandon Saved depending on state.
  - Right: Begin Run / Resume Floor / disabled state.
- Existing mechanics are unchanged: suspend/resume, Killswitch, Central Stash ownership rules, 100 items, 366 Loot Entries, single Floor 6 Shop, Warrior `HP / Level = 3`.
- The consumable/supply rule is implemented in 0.52.0; next major step is the full Warrior Floor 1-9 balance pass.

## 0.48.0 — active-run exit controls, suspend/resume and Killswitch

- Addon **0.48.0** adds a dedicated **RUN CONTROL** menu available from the active run's bottom button or by pressing **Escape**.
- The active-run button now becomes **RUN MENU** instead of a disabled `RUNNING` button.
- The Run Control menu exposes three distinct lifecycle actions:
  1. **ABANDON RUN** — two-click confirmation; the run ends as a failure, all unextracted run loot is discarded, and the character survives.
  2. **SAVE & SWITCH** — persists the exact run state for that character and returns directly to character selection with no extraction.
  3. **KILLSWITCH** — two-click confirmation; sets run HP to 0, discards unextracted run loot and returns directly to character selection. Hardcore generated heroes are permanently killed through the existing HC death system; non-HC / WoW-synced heroes only lose the run.
- Suspended runs are persisted account-wide in `GoblinArcadeDB.suspendedRuns`, keyed by character key.
- Multiple characters can each hold one suspended run.
- SAVE & SWITCH stores:
  - current floor and exact generated floor map;
  - player position, HP/resources, Run XP/temporary level, score and Copper;
  - enemies and encounter state;
  - opened chests, doors, exploration/FoW and room states;
  - floor backtracking states;
  - backpack, in-run equipment, potions, shop stock, cooldowns/buffs/reactives and action slots.
- Resuming restores the saved run rather than generating a new dungeon. Character rows show **SAVED F#**, the selected hero shows saved Floor/HP/Score, and the start button becomes **RESUME FLOOR #**.
- A selected saved run can also be discarded directly from character selection with **ABANDON SAVED** / **CONFIRM ABANDON**, without first resuming.
- Suspended-run ownership is anti-dupe protected:
  - a character with a suspended run cannot change its Central Stash loadout;
  - extracted loadout items therefore cannot be returned to stash and equipped by another character while a copied suspended run still references them;
  - a generated hero with a suspended run cannot be deleted until the run is resumed or abandoned.
- Resuming consumes the saved-run record from `suspendedRuns`; saving again writes the latest exact state back.
- Run-control actions return directly to the character selector rather than routing through the normal end-of-run summary.
- Successful Floor 9 extraction and ordinary combat death behavior remain unchanged.
- Studio remains **1.6.1 / schema 7**, with **100 items**, **366 Loot Entries**, one Shop on Floor 6, and Warrior `HP / Level = 3`.
- Next major step remains deciding the pre-run consumable/supply rule, followed by a full Warrior Floor 1-9 balance pass.

## 0.47.0 — persistent stash loadouts with baseline anti-exploit rules

- Addon **0.47.0** adds persistent pre-run equipment loadouts backed by the account-wide Central Stash.
- Character equipment is now modeled as two layers:
  - **baseline gear** = WoW-synced gear or Arcade starter gear;
  - **Arcade loadout overrides** = extracted items withdrawn from the Central Stash.
- Baseline gear is permanently marked `baselineLocked = true`, `stashEligible = false`, `ownershipSource = "baseline"`.
- Existing saved characters are migrated on DB access so old starter / WoW equipment receives the same baseline lock.
- Central Stash deposits now reject any item that is not explicitly `stashEligible = true` or is `baselineLocked`.
- Successfully extracted items are marked `stashEligible = true`, so only legitimate extracted ownership can circulate between stash and loadouts.
- Existing 0.46 extracted stash items are migrated to the new ownership marker from their `extractedAt` metadata.
- Each character gets a persistent `arcadeLoadout` table.
- Equipping from the Central Stash:
  - physically removes that item from the account-wide stash;
  - stores it in the selected character's `arcadeLoadout`;
  - replaces only the override layer, never the baseline item;
  - returns an existing extracted override to the stash before replacing it.
- Removing an extracted loadout override returns it to the Central Stash and reveals the untouched baseline item below it.
- Baseline items have no action that can return them to the stash.
- Deleting an Arcade-generated hero returns all legitimate extracted loadout overrides to the Central Stash before deleting the character; starter items are not returned.
- Effective run equipment is baseline + stash overrides. Enemy gear-pressure calculation and main-hand selection now use that effective equipment.
- Loadout items enter a run with no current `acquiredRunId`, so they cannot be re-extracted and duplicated at the end of the same run.
- In-run loot keeps the current run id and is still the only gear eligible for new extraction.
- Two-handed main-hand overrides suppress the off-hand in effective equipment. Equipping a two-handed loadout weapon returns any extracted off-hand override to stash; an off-hand cannot be equipped while the effective main hand is two-handed.
- Central Stash UI now doubles as the pre-run loadout manager:
  - left side = extracted stash inventory;
  - right side = all 16 equipment slots for the selected character;
  - dim slots = baseline / locked items;
  - bright slots = extracted loadout overrides;
  - click stash gear to equip it;
  - click an extracted override to return it to the stash.
- Consumables remain stash-visible but are not part of the pre-run equipment loadout yet.
- Studio data remains **1.6.1 / schema 7** with **100 items**, **366 Loot Entries**, one Shop on Floor 6, and Warrior `HP / Level = 3`.
- Next major step: decide whether stash consumables get dedicated pre-run supply slots, then run the full Warrior Floor 1-9 economy / difficulty balance pass.

## 0.46.0 — looter extraction loop and Central Stash

- Addon **0.46.0**, Studio **1.6.1**, schema **7**, DungeonGenerator **v11**.
- The dungeon loop is now explicitly a **looter roguelike**:
  - loot acquired during a run is tagged with that run's unique `runId`;
  - only loot actually still carried at successful completion is extracted;
  - extracted loot includes both backpack items and run-acquired items currently equipped;
  - starting WoW gear / Arcade starter gear is never copied into the stash;
  - consumed potions and sold items are naturally absent from extraction;
  - failed runs extract nothing and their run-acquired loot is lost.
- Added account-wide persistent **Central Stash** in `GoblinArcadeDB.centralStash`.
- Central Stash is shared by all WoW-synced and Arcade-generated characters.
- Successful Floor 9 completion automatically deposits extracted loot into the Central Stash and records extraction totals in the run summary.
- Stackable Studio consumables merge in the Central Stash up to their normal `stackMax`; equipment remains individual.
- Added a Central Stash browser to the pre-run character setup:
  - paged 30-slot visual grid;
  - item icons and stack counts;
  - tooltips show tier, item level, build profile, stats, traits and extracting character;
  - the setup button displays the total stored item count.
- Run summary now distinguishes **EXTRACTED TO CENTRAL STASH** from **UNEXTRACTED LOOT - LOST**.
- Shop frequency changed from four merchants to exactly **one merchant on Floor 6**.
- Shrine rooms remain on Floors **3, 5, 7 and 9**.
- The Floor 6 shop uses a smaller mid/late-run stock pool:
  - T3 is the main stock band;
  - T4 appears at lower weight as a preview;
  - T1, T2 and T5 are not sold there.
- Published shop loot entries reduced from 95 to **38**; total Loot Entries are now **366**.
- Studio browser draft key bumped to `goblinArcadeStudio.v18`.
- The 100-item catalog and Warrior `HP / Level = 3` remain unchanged.
- The next major itemization step should make Central Stash gear usable as a persistent pre-run loadout, so extracted items become true meta-progression rather than storage-only trophies.

## 0.45.0 — item identities, build traits and run economy

- Addon **0.45.0**, Studio schema **7**, Studio **1.6.0**, DungeonGenerator **v10**, ItemDatabase **v5**.
- Weapon archetypes now have runtime gameplay identities on T2+ Studio weapons and imported Uncommon+ WoW weapons:
  - **Sword / GUARD**: after attacking, grants a Parry chance for the following enemy phase; a successful parry prevents the hit and readies Revenge.
  - **Axe / CLEAVE**: weapon attacks splash a percentage of dealt damage to one additional adjacent enemy.
  - **Mace / STAGGER**: keeps the existing chance to make the target lose its next action.
- T2/T3/T4/T5 weapon-trait scaling:
  - Sword GUARD: 8 / 12 / 16 / 20%;
  - Axe CLEAVE: 15 / 20 / 25 / 30%;
  - Mace STAGGER: 10 / 15 / 20 / 25%.
- Added first-class Item **Build Profile** metadata:
  - VANGUARD;
  - BERSERKER;
  - BREAKER;
  - BULWARK;
  - EXECUTIONER;
  - SUPPORT.
- Character Sheet runtime now aggregates equipped active item traits.
- Added functional build traits on named jewelry/trinkets:
  - **BLOOD_FURY**: bonus damage at or below 50% HP;
  - **VANGUARD**: bonus damage at or above 80% HP;
  - **EXECUTIONER**: bonus damage against enemies at or below 35% HP;
  - **LAST_STAND**: increases Armor while at or below 35% HP.
- Build traits stack additively by trait name, capped at 50% per trait.
- Existing T2-T5 named jewelry was assigned to Bulwark/Berserker/Vanguard/Executioner identities rather than creating another parallel item set.
- Added a separate **run Copper** economy. Copper is independent of both Score and Run XP.
- Enemy Copper rewards are deterministic from floor + Danger Rating and multiplied by rank:
  - Normal 1.00x;
  - Veteran 1.50x;
  - Elite 2.50x;
  - Boss 6.00x.
- Added **SHOP** room role with marker **M**.
- Service rooms alternate:
  - even Floors 2/4/6/8 use a Shop;
  - odd Floors 3/5/7/9 use a Shrine.
- Shop rooms are safe rooms and do not join the enemy-spawn budget.
- The quartermaster rolls **4 unique stock items** when first opened on that floor; the exact stock and sold-out state persist through floor backtracking.
- Shop stock bands:
  - Floor 2: T1;
  - Floor 4: T2;
  - Floor 6: T3;
  - Floor 8: T4 with a low-weight T5 preview.
- Buying uses the authoritative Item `price` value.
- Selling removes the selected backpack stack and pays **50%** of its base value.
- Shop UI includes buy stock, paged backpack selling, live Copper balance, item stats/build profile/trait tooltips, and keyboard shortcuts 1-4 for purchases.
- Run HUD now shows Copper; the run-end summary records balance and bought/sold counts.
- Added the Studio `shop_inventory` Loot Table with **95** floor-banded entries. Total published Loot Entries are now **423**.
- Studio browser draft key bumped to `goblinArcadeStudio.v17`.
- The 100-item catalog remains intact and Warrior `HP / Level = 3` remains unchanged.
- Next major step should be a full Warrior Floor 1-9 balance/playtest pass, tuning Copper income, prices, trait strengths and tier power before adding more item quantity.

## 0.44.0 — Attack Power and first complete Warrior item progression

- Studio schema **6**, Studio **1.5.0**, addon **0.44.0**.
- Added first-class Item `tier` values: **T0-T5**.
- Added first-class **Attack Power** to Studio Items, runtime item instances, converted WoW gear, tooltips and Character Sheet totals.
- Attack Power is functional combat power, not display-only:
  - 14 AP = 1 DPS-equivalent;
  - FAST/NORMAL/SLOW use 1.8/2.4/3.2 weapon-speed factors;
  - per-hit AP bonus = round((AP / 14) × weapon speed);
  - AP bonus is added before ability damage multipliers, so weapon-based Warrior abilities scale with AP.
- The run Power display shows effective weapon damage after AP; the detailed weapon line shows the AP contribution separately.
- Studio weapon records gained `traitValue`; Studio Maces use the already-supported STAGGER runtime mechanic.
- Imported real WoW non-weapon gear receives deterministic AP through ItemGenerator v4; explicit Studio item AP remains authoritative for dungeon-created items.
- New Arcade Warriors use the Studio-defined **T0 Recruit's Longsword** when available.
- Added a complete first-pass **100-item** progression:
  - T0: 5 starter items;
  - T1-T5: 19 items per tier;
  - each T1-T5 tier contains 8 Plate pieces, 6 weapons, 1 shield, 3 jewelry/trinket items and 1 healing potion.
- Warrior gear families:
  - T1 Rusted Iron;
  - T2 Ironbound;
  - T3 Blacksteel;
  - T4 Grimforged;
  - T5 Warlord's.
- Healing Potion ladder: 25% / 35% / 45% / 55% / 70% max HP from T1 through T5.
- Treasure Chest progression:
  - Floor 1: T1;
  - Floor 2: 85% T1 / 15% T2;
  - Floor 3: T2;
  - Floor 4: 75% T2 / 25% T3;
  - Floor 5: T3;
  - Floor 6: 75% T3 / 25% T4;
  - Floor 7: T4;
  - Floor 8: 95% T4 / 5% T5;
  - Floor 9: 70% T4 / 30% T5.
- Elite Cache jumps forward: T4 on Floors 5-7 and T5 on Floors 8-9, with a small 1.05 power multiplier.
- Boss Cache is fully T5; Epic T5 jewelry has higher weight and Boss drops use a 1.10 power multiplier.
- Common enemy drops remain 15% at the loot-table level; the healing potion tier advances by floor band.
- Existing Candlekeeper's Charm and Waxbound Ring remain in the catalog as T3 items.
- Studio browser draft key bumped to `goblinArcadeStudio.v16` so old local drafts cannot silently hide the new catalog.
- Warrior `HP / Level = 3` remains unchanged.
- Next itemization block: playtest the T1-T5 curve, then add the Shop/economy loop using authoritative Item `price` values.

## 0.43.0 — run end, score framework and boss reward

- Added a real end-of-run overlay instead of immediately throwing the player back to setup.
- Success and death summaries show:
  - total score;
  - floor reached;
  - kills;
  - Elite kills;
  - Boss kills;
  - chests/caches opened;
  - shrines used;
  - turns;
  - temporary levels gained;
  - loot acquired during the run;
  - score-category breakdown.
- Hardcore Arcade death is called out explicitly as **HARDCORE - CHARACTER DIED** on the summary.
- Ended runs now transition through an explicit **BACK TO CHARACTERS** button.
- Score is still completely separate from Run XP.
- New score framework:
  - enemy base score remains data-driven through EnemyGenerator;
  - Elite kill bonus: +100;
  - Boss kill bonus: +300;
  - normal chest: +25;
  - Elite Cache: +75;
  - Boss Cache: +150;
  - first clear of each floor: +100;
  - full dungeon completion: +1000;
  - Shrine Sacrifice continues to add its Studio-defined score reward.
- Floor-clear scoring is guarded per floor, so backtracking cannot repeatedly farm the same floor bonus.
- Run tracking now records score breakdown, encounter statistics and an acquired-loot summary.
- Added `boss_cache_loot` and `boss_cache`.
- Killing the actual Boss-rank enemy spawns the Boss Cache and opens the Floor 9 exit; the Boss Cache resolves through the same Dungeon Object -> Loot Table -> Loot Entry -> Item pipeline as other containers.
- Default Boss Cache entries:
  - Candlekeeper's Charm: +4 item level, 1.30 power multiplier;
  - Waxbound Ring: +4 item level, 1.30 power multiplier;
  - Minor Healing Potion x2.
- Studio remains schema **5** and is bumped to **1.4.1** for the published Boss Cache defaults.
- Re-audited the Berserker Rage resource path: `GainRunResource` is already lexically declared before `GA:RunEnemyTurn()` on current main, so no forward-declaration fix was required.
- The published Warrior `HP / Level = 3` remains preserved.
- Next major product block: **Shop / economy loop**, using the existing authoritative Item `price` values and the now-complete run-end/reward loop.

## 0.42.0 — attachable named loot tables

- Studio schema bumped to **5** and Studio version to **1.4.0**.
- Reworked loot architecture into three explicit data layers:
  - **Loot Tables**: named reusable weighted tables;
  - **Loot Entries**: Item references belonging to a Loot Table;
  - **Dungeon Objects**: world/container definitions such as Treasure Chest and Elite Cache that point to a Loot Table.
- Loot Table records expose:
  - stable ID;
  - name;
  - Drop Chance % (0-100);
  - description.
- Loot Entry records expose:
  - Loot Table reference;
  - Item reference;
  - min/max floor;
  - relative weight;
  - item-level bonus;
  - power multiplier;
  - quantity;
  - enabled state.
- Enemy records now expose a **Loot Table** selector.
- Dungeon Object records expose:
  - stable ID;
  - name;
  - type;
  - map marker;
  - WoW icon;
  - Loot Table reference;
  - description.
- Initial Dungeon Objects:
  - `treasure_chest` -> `treasure_chest_loot`;
  - `elite_cache` -> `elite_cache_loot`.
- Existing Treasure/Elite loot entries were migrated from source-based routing to explicit `tableId` references.
- Added `common_enemy_drops` with a 15% table drop chance and attached it to the current enemy archetypes.
- The first common enemy drop entry is Minor Healing Potion; this makes enemy loot observable without flooding the backpack.
- EnemyGenerator bumped to **v7** and carries the Studio enemy's `lootTableId` into each generated enemy instance.
- DungeonGenerator bumped to **v9** and generated Treasure Chest markers now carry `objectId = "treasure_chest"`.
- ItemDatabase bumped to **v3**.
- Runtime loot resolution is now ID-based:
  - enemy death -> Enemy `lootTableId` -> Loot Table -> weighted Loot Entry -> Item;
  - chest open -> marker `objectId` -> Dungeon Object -> Loot Table -> weighted Loot Entry -> Item;
  - Elite Cache uses the same object-driven path.
- Enemy drops are auto-added to the run backpack when space is available; a full backpack logs a warning instead of silently adding the item.
- Object tables may intentionally roll no item through Drop Chance. Such containers still open and correctly report **empty**.
- The emergency fallback item is now reserved for invalid/missing object configuration, not for legitimate empty rolls.
- Studio and publish validation now reject missing Loot Table / Item references and invalid drop chances.
- The published Warrior `HP / Level = 3` remains preserved.

## 0.41.0 — item prices + finite potion runtime

- Studio schema bumped to **4** and Studio version to **1.3.0**.
- Every Studio Item now has required **Price (Copper)**.
- Price is stored directly on the runtime item instance and is intended as the shared base value for the future shop / buy / sell economy.
- GoblinArcade item tooltips now display the item's formatted value in copper/silver/gold notation.
- Current migrated default values:
  - Candlekeeper's Charm: 750 copper;
  - Waxbound Ring: 650 copper;
  - Minor Healing Potion: 100 copper.
- New Item records default to price 0 and Studio validation rejects negative prices.
- Added a Treasure loot entry for Minor Healing Potion so the finite potion loop can be tested through normal Dungeon play.
- Action-bar slot **0** is now a live Potion slot.
- Potion slot behavior:
  - scans the run backpack for Potion subtype consumables;
  - prefers the first potion that currently has a useful effect;
  - shows the real item icon;
  - shows the total count of that potion across backpack stacks;
  - remains visible but disabled/grey when a potion exists but would currently have no effect;
  - shows the reason in its tooltip.
- Supported consumable effects in the potion runtime:
  - `HEAL_PERCENT`;
  - `HEAL_FLAT`;
  - `RESOURCE`.
- Healing potions cannot be wasted at full HP.
- Resource potions cannot be wasted at full resource.
- Using a potion:
  - consumes exactly one stack unit;
  - removes the backpack stack when the final unit is consumed;
  - applies its Studio-defined effect;
  - updates health/resource/backpack/action bar UI immediately;
  - consumes one player turn;
  - then runs the normal enemy phase.
- Potion use is available both by clicking slot 0 and pressing keyboard **0**.
- Backpack item slots now render stack counts for stackable consumables.
- ItemDatabase bumped to v2 for runtime price propagation.
- The published Warrior `HP / Level = 3` remains preserved.

## 0.40.0 — Studio item database + data-driven dungeon loot

- Studio schema bumped to **3** and Studio version to **1.2.0**.
- Added a first-class **Items** section to GoblinArcade Studio.
- Item definitions are now separate from loot-table entries.
- Item records support:
  - stable ID and display name;
  - WoW icon texture / FileDataID;
  - category: Armor, Weapon, Shield, Offhand, Jewelry, Trinket or Consumable;
  - WoW-style equip location;
  - subtype/style;
  - quality and item level;
  - required temporary Run Level;
  - class restriction via ANY or comma-separated class IDs;
  - stack size;
  - explicit GoblinArcade HP, Armor, Dodge, Crit and Block;
  - explicit weapon min/max damage, speed and range;
  - optional trait name/description;
  - consumable effect/value;
  - description.
- Studio item fields are context-sensitive:
  - weapon-only fields appear only for Weapon items;
  - direct armor/stat fields are hidden for Weapons and Consumables;
  - consumable fields appear only for Consumables.
- Studio validation now checks item quality, levels, stack size, damage ranges, class IDs, equip-location consistency and icon format.
- Added a separate **Loot Tables** section.
- Loot entries reference Item IDs and configure:
  - source (Treasure / Elite / Boss / Shrine / Enemy / Shop);
  - floor range;
  - relative weight;
  - item-level bonus;
  - power multiplier;
  - quantity;
  - enabled state.
- The Studio publish API now validates/persists the new `items` array.
- Added `ItemDatabase.lua` as the runtime bridge between Studio definitions and actual Dungeon items.
- Studio-defined items use their explicit GoblinArcade stats directly and are never passed through the WoW ItemGenerator/WeaponGenerator conversion pipeline.
- WoW-imported equipment continues to use the existing converters unchanged.
- Treasure chests now roll from Studio Loot Tables with source `TREASURE`.
- Elite reward caches now roll from source `ELITE`, falling back to Treasure loot only if the Elite table is empty.
- The old rotating hard-coded chest template table has been removed; one emergency fallback item remains only for invalid/missing published loot data.
- The existing Candlekeeper's Charm and Waxbound Ring were migrated into the new Item database with roughly equivalent current GoblinArcade stats.
- Added a starter **Minor Healing Potion** item definition so the upcoming finite-potion system does not require another item-schema redesign.
- Consumable stacks are supported in the run backpack; identical Studio consumables can fill existing stacks before consuming new backpack cells.
- Consumable tooltips now show their effect and stack count.
- Potion activation itself is **not wired yet**; action slot `0` remains the next gameplay step.
- The published Warrior `HP / Level = 3` remains preserved.

## 0.39.0 — Hardcore Arcade heroes + generated-character deletion

- Generated Arcade heroes can now be created in either **NORMAL** or **HARDCORE** mode.
- The Create Character modal exposes explicit NORMAL / HARDCORE buttons; Hardcore shows a permanent-death warning.
- Generated character records persist `hardcore` and `dead` state in `GoblinArcadeDB.characters`.
- Hardcore death is real permadeath:
  - when a generated Hardcore hero reaches 0 HP and the run fails, the roster record is marked `dead = true`;
  - death timestamp, reason, floor and score are stored;
  - the dead hero remains visible in the roster as a memorial;
  - the roster card receives **HC - DEAD** metadata and a red visual state;
  - selecting a dead HC hero shows its death information;
  - BEGIN RUN is disabled and the runtime independently rejects any attempt to start another run with that hero.
- Normal generated heroes remain reusable after failed runs.
- Generated heroes now expose **DELETE HERO** on the Selected Hero panel.
- Deletion is intentionally two-step:
  - first click arms **CONFIRM DELETE**;
  - second click permanently removes the generated hero;
  - changing character clears the pending confirmation.
- Only generated Arcade heroes can be deleted. Synced real WoW characters never show the delete control and cannot be deleted through GoblinArcade.
- Deleting a generated hero also removes its saved action-bar layout/version and selects a safe remaining roster entry.
- A generated hero cannot be deleted while its own run is active.
- Hardcore state does not alter race/class stats; it only changes character mortality.

## 0.38.0 — modal character creation UX

- The Arcade Character Generator no longer occupies a permanent third column on the Dungeon setup screen.
- The **CHARACTERS** box now keeps six normal roster-sized slots.
- The first virtual slot after the existing characters is a special **+ CREATE NEW CHARACTER** roster card:
  - same size and visual language as a normal character entry;
  - uses a plus icon;
  - scrolls together with the roster;
  - always lives at the logical end of the character list rather than as a separate footer button.
- Clicking that create slot opens a true modal over the setup screen with a dimmed blocking backdrop.
- The modal contains:
  - character name input;
  - all 10 race choices with WoW icons;
  - all 9 class choices with class icons;
  - READY/locked class behavior unchanged;
  - CANCEL and CREATE HERO actions.
- ESC closes the character-creation modal without leaving the Dungeon setup.
- Successful creation closes the modal, refreshes the roster and selects the newly created Arcade hero.
- The modal is automatically closed whenever Dungeon setup mode is entered or exited.
- Existing class readiness, race data, persistence and generated-character rules from 0.37.0 remain unchanged.

## 0.37.0 — Arcade Character Generator + race data

- Added an **Arcade Character Generator** directly to the Dungeon character-selection screen.
- Players can still use synced real WoW characters, but can now create a persistent GoblinArcade-only fallback hero when they do not own a supported class.
- Generated heroes are stored separately in `GoblinArcadeDB.characters` with `sourceType = "arcade"`; they never modify or impersonate a real WoW character.
- Generated heroes currently:
  - start at level 1;
  - receive a basic starter main-hand weapon;
  - use the same run XP / temporary level system as real characters;
  - use race only as a cosmetic identity for now.
- Character generation exposes:
  - editable name;
  - all current Forever races as icon buttons;
  - all current Forever classes as icon buttons.
- Class availability is data-driven:
  - Studio Classes now expose `Playable / Ready = YES/NO`;
  - only `YES` classes can be selected or generated;
  - the runtime BEGIN RUN path independently re-checks readiness, so unsupported real characters cannot accidentally enter with the Warrior ruleset.
- Current ready class: **Warrior only**.
- Current locked classes are present for future work: Paladin, Hunter, Rogue, Priest, Shaman, Mage, Warlock and Druid.
- Studio schema bumped to **2** and Studio version to **1.1.0**.
- Added a first-class **Races** editor section to Studio.
- Race records contain stable ID, name, short generator label, faction, editable WoW icon texture/FileDataID and description.
- Added all 10 current Forever race choices:
  - Alliance: Human, Dwarf, Night Elf, Gnome, Skyborne - High Order;
  - Horde: Orc, Undead, Tauren, Troll, Skyborne - Windshaper.
- Racials intentionally have **no GoblinArcade gameplay effect yet**.
- Generated hero portraits use the selected race icon; synced real alts keep class icons and the currently logged-in character keeps the live WoW portrait.
- The Studio publish API now validates and persists the new `races` array.
- The published Warrior `HP / Level = 3` remains preserved.

## 0.36.0 — strict room-threshold door topology

- Fixed a remaining procedural door-placement bug visible in-game where a door marker could appear on an ordinary corridor tile.
- Root cause: the previous threshold test confirmed room -> wall-band -> walkable continuity, but did not reject wall-band cells that also belonged to a parallel corridor or junction.
- DungeonGenerator bumped to v8.
- A generated door is now valid only when:
  - the door tile is walkable and outside every room;
  - the inward neighbor is inside the owning room;
  - the outward neighbor is a corridor tile outside every room;
  - the door tile has **exactly two orthogonally walkable neighbors**: room interior and outward corridor.
- Parallel corridors, T-junctions, intersections and open-area cells can no longer become doors.
- Door candidates at room corners are now excluded entirely.
- Existing rules remain intact:
  - no orthogonally adjacent doors;
  - small rooms (w*h <= 25) hard-cap at one door;
  - Studio-driven room door limits still apply.
- This affects newly generated floors only; start a NEW RUN after /reload to validate the fix.

## 0.35.0 — right-rail navigation + action-bar slot swapping

- The right-hand dungeon rail now includes a **QUICK ACCESS** section.
- QUICK ACCESS contains two icon buttons:
  - **CHARACTER** opens the GoblinArcade Character Sheet;
  - **SPELLBOOK** opens the paged Spellbook.
- Both quick-access entries use built-in WoW icon textures and tooltips.
- Character Sheet and Spellbook are mutually exclusive overlays: opening one closes/hides the other.
- The former text `B SPELLBOOK` button above the action bar was removed; `B` remains the keyboard shortcut while the right-rail icon is the visual entry point.
- Action-bar spell slots now support true slot-to-slot drag-and-drop.
- Dragging an occupied slot shows the same cursor-following spell icon used by Spellbook drag.
- Dropping onto an empty slot moves the spell.
- Dropping onto another occupied slot **swaps the two spells** rather than deleting/duplicating either one.
- Dropping back on the source slot or outside the bar leaves the loadout unchanged.
- The source slot dims during a drag and all valid destination slots remain highlighted.
- Right-click-to-clear and per-character persistence remain unchanged.
- Slot rearrangement does not consume a combat turn.

## 0.34.0 — WoW-style action bar + paged icon Spellbook

- The run action bar is now a horizontal WoW-style icon bar instead of wide text buttons.
- Layout:
  - `1` fixed Basic Attack;
  - `2-9` eight configurable spell slots;
  - `0` reserved Potion;
  - `B` opens the Spellbook.
- Action slots are square 48x48 icon buttons with hotkey labels and cooldown turn counters.
- Ability icons dim when the spell is currently unusable because of Rage/cooldown/unlock state.
- Spellbook entries are now icon-based cards with spell name and learned/locked metadata.
- Spellbook is paginated at 12 spells per page (2 columns x 6 rows); the current 29 Warrior spells span three pages.
- PREV/NEXT page controls and page counter are built in.
- Dragging from the Spellbook is now true drag-and-drop:
  - the selected spell icon follows the mouse cursor;
  - all valid action slots 2-9 highlight;
  - releasing over a slot assigns the spell;
  - releasing elsewhere cancels without changing the bar.
- Locked spells remain visible in the Spellbook with their required Run Level but cannot be dragged.
- Right-click still clears an action slot.
- Existing four-slot per-character loadouts migrate to the eight-slot format without changing slots 2-5; newly added positions are filled only during the one-time migration.
- Per-character action-bar format version is stored in `GoblinArcadeDB.actionBarVersions`.
- Ability records now support a Studio-driven `icon` field.
- Studio **WoW Icon** accepts:
  - a WoW texture shorthand such as `Ability_Warrior_Charge`;
  - a full `Interface\\Icons\\...` path;
  - a numeric FileDataID.
- Blank icon values automatically resolve the live WoW spell texture from the spell name.
- Web URLs are rejected for ability icons.
- Existing combat mechanics and the published Warrior `HP / Level = 3` remain unchanged.

## 0.33.0 — Spellbook + configurable action bar

- The old direct-cast ability panel is replaced by a real run Spellbook.
- Press `B` or click `B SPELLBOOK` to open it.
- The Spellbook lists all 29 retained Warrior abilities in spellbook order.
- Learned abilities are active; locked abilities remain visible and show their required Run Level.
- Learned abilities can be dragged from the Spellbook onto four configurable active ability slots.
- Click-to-pick + click-slot is also supported as a robust fallback to drag-and-drop.
- Drag/drop targets visibly highlight while an ability is held.
- The combat action bar is now:
  - `1` fixed Basic Attack
  - `2-5` configurable ability slots
  - `6` reserved Potion slot
  - `B` Spellbook
- Right-clicking an ability slot clears it.
- Action slots remain interactive while the assigned ability is on cooldown or lacks Rage; the spell is shown muted and runtime validation reports why it cannot fire.
- Duplicate action-bar assignments are prevented: assigning a spell to another slot removes its old assignment.
- Loadouts are persisted per character in `GoblinArcadeDB.actionBars[characterKey]`.
- New characters/runs without a saved bar receive a sensible initial loadout from already unlocked abilities.
- Run-level unlocks immediately appear in the Spellbook and can be assigned without restarting the run.
- Saved abilities that are not yet unlocked at the beginning of a run are not activated.
- Assigning, clearing, or rearranging the action bar does not consume a combat turn.
- Existing Warrior combat mechanics and the published `HP / Level = 3` remain unchanged.

## 0.32.0 — complete Warrior ability runtime

All 29 retained Warrior abilities are now represented by the runtime ability system. The previously excluded Taunt, Mocking Blow and Challenging Shout remain intentionally omitted because their core threat-only mechanics do not translate cleanly to the solo roguelike.

New level 22-50 runtime abilities:
- Intimidating Shout: adjacent enemies lose actions for 2 enemy phases; 2 Rage, 6-turn cooldown.
- Execute: adjacent-target finisher usable at or below 20% HP; 2.5x weapon damage, 2 Rage.
- Shield Wall: requires a shield; -60% incoming damage for 2 enemy phases; 10-turn cooldown.
- Berserker Stance: +10% crit chance, +15% incoming damage until another stance is chosen.
- Intercept: range 2-4 mobility strike with one-turn stagger; 1 Rage, 4-turn cooldown.
- Berserker Rage: +1 Rage immediately and +1 Rage whenever damaged for 4 enemy phases; 6-turn cooldown.
- Whirlwind: 1.0x weapon damage to every adjacent enemy; 2 Rage, 2-turn cooldown.
- Pummel: 0.75x weapon damage plus one-turn stagger; 1 Rage, 2-turn cooldown.
- Recklessness: +50% crit chance and +25% incoming damage for 3 turns; 10-turn cooldown.

The ability panel now exposes all 29 supported Warrior abilities. The first ten retain numeric panel hotkeys; later abilities are clickable. The panel is a compact 3-column layout and remains level-gated by Run Level.

The shared engine now covers:
- Rage generation/spending and resource caps;
- cooldowns and duration ticking;
- DoTs;
- player buffs and enemy debuffs;
- movement abilities;
- AoE;
- reactive windows;
- stances;
- shield requirements;
- control/stagger/fear;
- damage-taken and damage-done modifiers;
- temporary crit modifiers;
- stackable vulnerability;
- kill-triggered Victory Rush;
- retaliation/counter damage;
- level-up kills from direct, AoE and DoT damage.

The user's published Warrior HP / Level = 3 remains preserved.

## 0.31.0 — Warrior level 12-20 combat package

The shared Warrior combat engine now covers the complete level 1-20 band.

New runtime-wired abilities:
- Overpower: reactive for one player turn after a dodge; 1.6x weapon damage.
- Shield Bash: requires a shield; 1.0x weapon damage plus one-turn stagger; 1 Rage, 2-turn cooldown.
- Demoralizing Shout: adjacent enemies deal -20% damage for 4 turns; 1 Rage, 3-turn cooldown.
- Revenge: reactive for one player turn after a dodge or block; 1.5x weapon damage, 1 Rage.
- Shield Block: requires a shield; +50% block chance for 2 enemy phases; 1 Rage, 3-turn cooldown.
- Disarm: one adjacent enemy deals -50% damage for 3 turns; 1 Rage, 4-turn cooldown.
- Retaliation: melee attackers are counter-hit at 0.75x weapon damage for 3 enemy phases; 8-turn cooldown.
- Victory Rush: available briefly after a kill; 1.25x weapon damage and restores 20% max HP.
- Cleave: primary melee hit plus one additional adjacent enemy; 1.0x weapon damage, 2 Rage.
- Slam: 1.75x single-target weapon damage, 2 Rage.

Reactive combat state now includes Overpower, Revenge and Victory Rush windows. Shield-aware abilities inspect the run's equipped off-hand. The ability panel now contains all twenty supported abilities in a 3-column layout; the first ten retain numeric panel hotkeys and later abilities remain clickable.

The user's published Warrior HP / Level = 3 remains preserved.

## 0.30.0 — Warrior level 1-10 combat package

The Warrior is no longer being wired one spell at a time. A shared ability runtime now covers the first full level band.

Runtime-wired Warrior abilities through level 10:
- Battle Stance
- Heroic Strike
- Battle Shout
- Charge
- Rend
- Thunder Clap
- Hamstring
- Bloodrage
- Defensive Stance
- Sunder Armor

Shared combat infrastructure:
- ability panel opened with action button 3 / B;
- all supported abilities auto-appear when the current Run Level unlocks them;
- panel hotkeys 1-0 activate the ten current abilities;
- Studio-driven Resource Cost, Damage Multiplier, Cooldown Turns, Duration Turns, Range, Effect Value, Secondary Value and Resource Gain;
- shared run cooldown table;
- timed player buffs and enemy debuffs;
- enemy damage-over-time ticking;
- stance state;
- deterministic movement slow;
- enemy damage reduction debuff;
- stacking vulnerability;
- mobility targeting for Charge;
- AoE resolution for Thunder Clap;
- level-up feedback survives the enemy phase, including DoT/AoE kills.

Current default translations:
- Battle Shout: +15% damage for 6 turns, 8-turn cooldown, 1 Rage;
- Charge: visible target at range 2-4, 1.0x weapon damage, +2 Rage, one-turn stagger, 4-turn cooldown;
- Rend: 0.4x weapon strike plus the same bleed tick for 3 turns, 1 Rage;
- Thunder Clap: 0.75x weapon AoE to adjacent enemies and -20% enemy damage for 3 turns, 2 Rage, 3-turn cooldown;
- Hamstring: 0.75x weapon damage and 50% deterministic movement slow for 3 turns, 1 Rage;
- Bloodrage: trades 10% max HP for +2 Rage, 6-turn cooldown and cannot self-kill;
- Defensive Stance: -20% incoming damage / -10% outgoing damage until Battle Stance is activated;
- Sunder Armor: 0.5x weapon damage, +10% incoming damage per stack, max 3 stacks, 5-turn duration, 1 Rage.

The user's published Warrior HP / Level = 3 remains preserved.

## 0.29.0 — Warrior Rage + Heroic Strike

- Warrior Rage is now a real run resource.
- The left run card displays current/max class resource (for Warrior: RAGE).
- Successful basic ATTACK actions generate the class's Studio-driven `Basic Attack Resource Gain`; Warrior default is 1.
- Heroic Strike is wired as the first executable Studio ability on action slot / hotkey 2.
- Heroic Strike requires its normal level unlock, an adjacent enemy, and enough resource.
- Ability `Resource Cost` and `Damage Multiplier` are editable in Studio; Heroic Strike defaults to 2 Rage and 1.5x weapon damage.
- Resource is spent only after a valid melee target is confirmed; failed/locked/no-resource attempts do not consume a turn.
- Basic attacks generate resource after a valid strike and respect the current resource cap.
- Studio local draft namespace bumped to v7.
- The user's published Warrior `HP / Level = 3` is preserved.

## 0.28.0 — class run-level stat growth

- Classes now expose editable `HP / Level` and `Resource / Level` values in GoblinArcade Studio.
- `Base Resource Max` remains the class's starting run resource cap; `Resource / Level` adds to that cap for every temporary run level gained.
- `HP / Level` increases both run max HP and current HP by that amount on each temporary level-up; this is an incremental gain, not a full heal.
- Class growth settings are snapshotted at BEGIN RUN, matching the existing run-progression model.
- Run state now carries `resourceType`, `baseResourceMax`, `resourceMax`, and `resource` so ability execution can consume the same resource system when it is wired.
- Defaults are deliberately 0 HP / level and 0 Resource / level until balancing is set in Studio.
- Level-up combat log reports class stat growth alongside newly unlocked abilities.
- Studio local draft namespace bumped to v6.

## 0.27.1 — XP curve / level-up feedback polish

- Corrected the first eight temporary run-level thresholds to the approved curve: 100 / 125 / 155 / 190 / 230 / 275 / 325 / 380 XP.
- Added editable Studio `XP Curve` text; values after the explicit curve continue from its last cost using `Level Growth`.
- LEVEL UP feedback now survives the killing-blow status update and logs the exact old/new level plus any newly unlocked abilities.
- Enemy Studio preview now shows calculated Normal / Veteran / Elite / Boss XP from Danger Rating, XP per Danger and rank XP multipliers.
- Studio local draft namespace bumped to v5 so older browser drafts cannot silently drop the new XP Curve field.

## 0.27.0 — temporary run levels / Danger XP

- Added live enemy Danger Rating and rank XP multipliers.
- Kill XP is generated from Danger × XP-per-Danger × rank multiplier.
- Added temporary run XP/level progression: 100 XP first threshold, 1.22x growth, max 60.
- Run level starts at the character's real WoW level and resets on the next run.
- Player max HP is deliberately unchanged by level-up.
- New floors use the current run level for enemy generation; visited floors are not retroactively rescaled.
- HUD now shows LEVEL and XP; enemy card shows DANGER.
- Ability unlock state is automatically expanded when the temporary run level reaches an ability's learn level.

## 1. Project goal

GoblinArcade is a WoW Forever addon that provides small arcade-style games for downtime inside World of Warcraft.

The current flagship mode is a **turn-based roguelike dungeon crawler** where the player's real WoW character matters:

- a synced WoW character or a separately generated Arcade hero is snapshotted into the run;
- equipped WoW gear is converted into deterministic roguelike gear;
- dungeon loot can be equipped inside GoblinArcade;
- the real WoW character and equipment are never modified by GoblinArcade;
- movement, combat, fog of war, inventory and enemy interaction all happen inside the addon UI.

The core product principle is:

> **Your WoW character matters.**

Do not replace this with a generic roguelike character progression system.

---

## 2. WoW / deployment environment

WoW Forever beta:

- Interface: `16001`
- around WoW Forever 1.60.x
- beta client folder commonly: `_classic_beta_`
- addon target folder:
  `World of Warcraft\_classic_beta_\Interface\AddOns\GoblinArcade`

Deployment is automatic through GitHub Actions.

### GoblinArcade Studio / Vercel

Studio v1.4.0 keeps a **static-first** architecture for Vercel cost efficiency:

- no npm build is required;
- no database is used;
- no serverless functions run during normal editing;
- editor drafts live in browser localStorage;
- canonical published data is mirrored at `/studio-data.json`;
- JSON/Lua export remain available as portable backups;
- one protected `/api/publish` function runs only when PUBLISH TO WOW is pressed;
- publish commits `studio-data.json` and `GoblinArcade/Data/StudioData.lua` to GitHub, which triggers the existing Windows self-hosted WoW deployment.

The repo-level `vercel.json` keeps `/` as a real static `index.html` entrypoint and rewrites only `/studio` to that file. 0.24.1 also mirrors the same static entrypoint to `GoblinArcade/index.html` so the page still works if the Vercel project's Root Directory is configured as `GoblinArcade`. WoW ignores the HTML file.

Direct **PUBLISH TO WOW** is implemented in Studio v0.2.0 through an on-demand Vercel Function. It requires two Vercel environment variables: `GITHUB_TOKEN` (fine-grained token restricted to this repository, Contents read/write) and `STUDIO_PUBLISH_KEY` (a private editor password). The GitHub token never reaches the browser; the Studio key is stored only in browser sessionStorage.

The Vercel connector still does not list the newly imported GoblinArcade project, but the user confirmed the production domain is `goblin-arcade.vercel.app`. The initial 0.24.0 deployment returned Vercel 404 at the root despite being Ready; 0.24.1 fixes this by deploying a real root `index.html` instead of relying on a root rewrite. Do not touch the unrelated `liminal-space` Vercel project.

Deployment is automatic through GitHub Actions.

Workflow:

- `.github/workflows/deploy.yml`
- runs on Windows self-hosted runner
- runner name: `DESKTOP-C573AAV`
- main branch push triggers deployment
- deploy mirrors `GoblinArcade/` into the live WoW AddOns folder
- do not ask the user to manually copy files
- after deploy, user typically tests with `/reload`

The user prefers:
- direct implementation;
- small iterative changes;
- no long implementation plans unless explicitly requested;
- screenshots/errors after each iteration;
- automatic deploy rather than manual build/copy steps.

---

## 3. Current file layout

Important addon files:

- `GoblinArcade/Core.lua`
  - addon bootstrap
  - slash commands
  - version
  - player login setup

- `GoblinArcade/Data/StudioData.lua`
  - Studio schema/data foundation loaded by the addon
  - contains 29 Warrior spellbook abilities with minimum trainer unlock levels and Arms/Fury/Protection category; pure threat/aggro skills Taunt, Mocking Blow and Challenging Shout are intentionally excluded because the current GoblinArcade dungeon is solo
  - Warrior source baseline: WoW Forever beta client build 1.60.1.69893 spellbook data, checked 2026-09-20
  - classes (including run-level HP/resource growth), enemies, ranks, room settings, shrine values, run-XP progression, Items and Treasure/Elite loot tables are runtime-driven; Warrior ability execution is also runtime-wired
  - enemy archetypes now carry Danger Rating (1-10); current defaults: Spider 2, Kobold 2, Skeleton 3, Brute 4
  - rank XP multipliers: Normal 1.00, Veteran 1.35, Elite 2.00, Boss 5.00
  - kill XP = Danger Rating × 8 × Rank XP Multiplier by default
  - temporary run-level XP uses the explicit first-eight curve 100 / 125 / 155 / 190 / 230 / 275 / 325 / 380; later thresholds grow from the last explicit value by the Studio Level Growth setting; maximum run level 60

- `GoblinArcade/UI.lua`
  - main shell
  - Home
  - navigation rail
  - combat log rail
  - global UI helpers/colors

- `GoblinArcade/DungeonRun.lua`
  - main dungeon mode
  - lobby
  - grid / camera
  - movement
  - LOS / fog of war
  - enemy AI
  - combat
  - chest loot
  - run state
  - dungeon UI

- `GoblinArcade/WeaponGenerator.lua`
  - deterministic weapon conversion

- `GoblinArcade/ItemGenerator.lua`
  - deterministic armor/jewelry/offhand conversion

- `GoblinArcade/EnemyGenerator.lua`
  - deterministic enemy effective level
  - BEGIN RUN Gear Pressure calculation
  - HP / damage / score budgets
  - enemy archetype + rank profiles

- `GoblinArcade/FloorGenerator.lua`
  - bounded QUIET / STANDARD / CROWDED density roll
  - walkable-tile-based base enemy budget
  - floor-depth density growth

- `GoblinArcade/DungeonGenerator.lua`
  - procedural 25×25 floor layout generation
  - local seeded PRNG that does not disturb combat RNG
  - non-overlapping rooms + connected L-corridors
  - extra loop connections on deeper floors
  - generated start, exit and chest positions
  - generated room/corridor threshold doors
  - deterministic per-floor START / COMBAT / TREASURE / ELITE / SHRINE / EXIT / BOSS room roles

- `GoblinArcade/CharacterRoster.lua`
  - account-wide character roster
  - snapshots current character and equipment
  - SavedVariables integration

- `GoblinArcade/CharacterSheet.lua`
  - `C` character sheet
  - equipment slots
  - backpack
  - drag & drop
  - converted gear stats
  - tooltip rendering

- `GoblinArcade/GoblinArcade.toc`
- `GoblinArcade/GoblinArcade_Camelot.toc`

Studio / web tooling:

- 0.25.1 fixes the Studio interaction regression: the shared `render()` coordinator was missing, so buttons/list navigation called an undefined function after the initial static paint. All three served HTML entrypoints now include the coordinator plus a visible runtime-error status fallback.
- `index.html` and `studio/index.html`
  - GoblinArcade Studio v0.4.0
  - root `index.html` is the canonical Vercel entrypoint; `/studio` rewrites to it
  - single-file static editor with no framework/build step
  - edits Classes, Abilities, Enemies, Ranks, Room Roles, Loot and Shrines
  - browser-local autosave via localStorage
  - LOAD PUBLISHED reads canonical `/studio-data.json`
  - PUBLISH TO WOW uses protected `/api/publish`
  - JSON import/export, validation, live preview and Lua export
- `vercel.json`
  - routes the Vercel project root and /studio to the static Studio page
  - no database or always-on backend
- `api/publish.js`
  - protected on-demand GitHub publisher
  - invoked only on explicit PUBLISH TO WOW

Media:

- `GoblinArcade/Media/Monsters/kobold.tga`
  - current Kobold grid sprite
  - 128×128 custom TGA
- `GoblinArcade/Media/Monsters/spider.tga`
  - current Spider grid + target-card sprite
  - 128×128 custom TGA
- `GoblinArcade/Media/Monsters/skeleton.tga`
  - current Skeleton grid + target-card sprite
  - 128×128 custom TGA

SavedVariables:

- `GoblinArcadeDB`

---

## 4. Current UI state

Main window:

- current size: **1384 × 944**
- resized in 0.16.7 for the 7×7 viewport using 96×96 physical tiles
- dark brown / black / gold visual language
- flat UI, no rounded-corner aesthetic

Header:

- `GOBLIN ARCADE`
- subtitle:
  `Azeroth's least responsible use of downtime.`

### Home

Home deliberately contains **only** the centered GoblinArcade logo and the creator credit underneath:

> created by Nightstrider

Logo asset:

- `GoblinArcade/Media/UI/ga_logo.png`

Do not add status cards, explanatory text, launch buttons, feature lists, etc. unless the user explicitly asks.

### Main navigation

Left navigation rail contains:

- HOME
- DUNGEON RUN
- SCORES (disabled)
- SETTINGS (disabled)

The character portrait was intentionally removed from the main navigation rail.

---

## 5. Dungeon Run lobby

Choosing DUNGEON RUN first opens a lobby rather than the dungeon itself.

Lobby:

- heading: `DUNGEON RUN`
- `CHOOSE A HERO`
- left panel: `CHARACTERS`
- right panel: `SELECTED HERO`
- the two panels are intentionally the **same size: 330 × 392**
- `BEGIN RUN` lives inside the Selected Hero panel

Character roster behavior:

- WoW addons cannot inspect arbitrary offline alts.
- a character appears after the user logs into that character at least once with GoblinArcade loaded.
- the addon caches that character's last synced data in `GoblinArcadeDB`.
- current character shows live data.
- offline alts use cached data.

Labels:

- current character:
  `CURRENT CHARACTER - LIVE DATA`
- alt:
  `ALT - LAST SYNCED DATA`

---

## 6. Dungeon world / camera

World size:

- **25 × 25**

Viewport:

- **7 × 7**
- logical tile size: **96 × 96 px**
- tile gap: **1 px**
- rendered grid: **678 × 678 px**
- creature sprite source-art standard: **128 × 128 px**
- creature sprite render size: **96 × 96 px**
- static/player markers use the huge game font for readability at the larger scale

The viewport is a camera into the larger 25×25 world, not a scrollbar.

Important visual rule: the user explicitly wants **sprites fully contained inside their own cells**. The current 0.16.7 baseline uses 96×96 physical tiles with 128×128 source art rendered at 96×96 inside a 7×7 viewport. Every creature texture remains fully contained inside its own tile.

Player starts around:

- `7,7`

Exit:

- `23,23`
- on Floors 1–8, stepping on the exit advances to the next floor;
- on Floor 9, stepping on the exit completes the run.

The camera follows the player and clamps at world boundaries.

Current run length is **9 floors**. In 0.18.0 each floor receives a fresh procedural 25×25 layout from DungeonGenerator v1.

The generator creates non-overlapping rooms, connects every room into one reachable dungeon, adds limited extra corridor loops on deeper floors, chooses a north-west-biased start room, places the exit in the most distant room by path distance, and places up to two chests in other distant rooms.

A run has one dungeon seed; each floor derives its own deterministic layout seed from it. Re-rendering the UI never rerolls the floor.

Static marker meanings:

- `S` = current prototype/test marker
- `$` = chest
- `>` = exit

The map is still a prototype layout and should eventually be replaced by dungeon generation / floor templates.

---

## 7. Fog of War / LOS

Current player vision radius:

- **4 tiles**

This was explicitly requested by the user.

Rules:

- walls block LOS;
- currently visible terrain is fully rendered;
- previously explored terrain remains dimmed;
- never-seen terrain is almost black;
- unseen cells have **no visible border** to avoid the dotted/grid artifact;
- enemies are drawn only when currently visible;
- visible enemy cells keep the normal terrain background; only the cell border turns red;
- static discovered landmarks may remain visible in dim form as memory.

LOS currently uses deterministic line tracing.

---

## 8. Keyboard behavior

During an active run:

- GoblinArcade takes keyboard focus;
- movement keys do not move the real WoW character.

Movement keys:

- WASD
- arrow keys

Other controls:

- `1` = Attack
- `C` = character sheet
- `ESC` closes character sheet first; otherwise closes addon

Do not allow movement input to propagate to WoW while a run is active.

---

## 9. Combat log

During a run, the normal left navigation rail disappears and is replaced by a Combat Log.

Combat log includes:

- run started;
- loadout locked;
- movement;
- blocked movement;
- enemy movement;
- aggro;
- damage;
- dodge;
- block;
- critical hits;
- stagger;
- chest loot;
- kill score;
- run end.

The combat log is intentionally part of the run-mode presentation.

---

## 10. Player card / enemy card layout

### Player card

Inside Dungeon Run, left side:

- **158 × 92**
- portrait: **64 × 64**
- portrait left
- name + metadata right

Player card appears at the top of the left run panel.

### Enemy card

The user explicitly wants the enemy card on the **right side**, not left.

Current right run panel width:

- **182 px**

This intentionally matches the left run panel width.

Kobold combat target card:

- **158 × 92**
- same horizontal visual rhythm as the player card
- portrait left
- name + HP right
- gold frame style, not a giant red standalone card
- HP text may stay red

When there is no adjacent active enemy:

- target card hides
- RUN / FLOOR / SCORE / TURNS move up to the top of the right panel

When combat starts:

- enemy card appears at the top
- RUN stats shift below it
- the card shows enemy name/level, numeric HP and Danger Rating
- intent labels are intentionally hidden from the player

Relic slots were explicitly removed and should **not** be reintroduced unless requested.

Enemy visuals currently use:

- Kobold portrait: Blizzard candle-kobold icon
- Kobold grid sprite: custom `Media/Monsters/kobold`
- Spider: custom `Media/Monsters/spider` for grid + target card
- Skeleton: custom `Media/Monsters/skeleton` for grid + target card

All three active archetypes now have dedicated custom grid artwork. Spider and Skeleton use their custom sprite art in the right-side target card as well.

---

## 11. Current combat prototype

Current floor enemies:

- Floor 1 spawns a bounded mixed population rather than one fixed Kobold
- level, HP and damage are generated deterministically by `EnemyGenerator.lua`
- Kobold is the baseline pursuer
- Spider is a low-HP, high-vision quick pursuer
- Skeleton is a higher-HP, lower-vision slow pursuer
- effective level depends on selected character level + floor + rank
- HP and damage also receive frozen BEGIN RUN Gear Pressure
- the target card displays the generated enemy level

Enemy awareness:

- the kobold does not automatically know the player across the entire map;
- it can detect the player within enemy vision range + line of sight;
- after alerting, it chases using deterministic BFS pathfinding.

Player combat:

- moving into the enemy tile triggers bump attack;
- `1 ATTACK` also attacks if adjacent;
- each attack costs one turn;
- damage uses the active GoblinArcade weapon;
- no weapon = unarmed fallback damage.

Every living enemy gets an enemy-turn opportunity after a player action. Unalerted enemies stay inactive until they detect the player; alerted enemies chase without stacking. Multiple adjacent enemies can attack in the same enemy phase.

Death ends the run.

A normal Kobold kill currently gives:

- **+100 score**

Chest loot currently gives:

- **+25 score**

Combat randomness is allowed in actual combat rolls. The user's objection to randomness was specifically about **gear conversion**.

---

## 12. Weapon conversion

File:

- `WeaponGenerator.lua`

Critical design rule:

> **Gear conversion must never use RNG.**

The user explicitly rejected seeded/hash-based or reroll-like generation.

Conversion is deterministic and transparent:

- same WoW item metadata → same GoblinArcade item;
- subtype defines fixed archetype;
- item level defines power budget;
- rarity strengthens the predefined behavior;
- no rolled affixes.

Examples:

- Dagger → fast / backstab
- Sword → balanced / guard
- Axe → cleave
- Mace → stagger
- Staff → reach / sweep
- Polearm → reach / impale
- Bow → ranged / precise
- Gun → ranged / impact
- Crossbow → ranged / puncture
- Wand → ranged / focus
- Fist → fast / flurry

Current user's main weapon example:

Heavy Copper Maul:

- Two-Handed Mace
- Damage 14–19
- Slow
- Range 1
- STAGGER
- 15% chance to delay target's next action

STAGGER is an in-combat probability, not a conversion reroll.

---

## 13. Armor / item conversion

File:

- `ItemGenerator.lua`

Current generator version:

- **2**

Armor/jewelry conversion is also fully deterministic.

Converted stats include:

- Health
- Armor
- Dodge
- Crit
- Block

Current slot philosophy:

- Chest → strongest HP source + armor
- Legs → strong HP + armor
- Head → moderate HP + armor
- Shoulders → moderate HP + armor
- Feet → Dodge focus
- Wrist → Dodge
- Hands → Crit
- Rings → Crit / Dodge
- Trinkets → mixed Crit / Dodge
- Cloak → Dodge
- Shield → Armor + Block
- caster off-hand / holdable → Focus / Crit

Main armor HP sources are explicitly:

- Head
- Shoulders
- Chest
- Legs

HP scales deterministically with:

- item level;
- rarity;
- armor material.

Gear conversion must remain fixed and explainable.

---

## 14. Converted stats affect combat

Current aggregate GoblinArcade stats:

- bonus HP
- Armor
- Dodge
- Crit
- Block

Effects:

- Health increases run max HP;
- Armor mitigates incoming damage;
- Dodge can avoid an enemy attack;
- Crit causes 150% player damage;
- Block can halve an incoming hit.

Health equipment swapping preserves health ratio.

Important:

Changing gear must **not** allow free healing.

Example:

- 50% current health before gear change
- new max HP after gear change
- current HP becomes approximately 50% of the new max HP

---

## 15. Character sheet

Hotkey:

- `C`

The sheet resembles a WoW character + backpack arrangement.

It contains:

- character portrait
- character name / level / race / class
- current health
- converted aggregate stats
- equipment slots
- backpack

Aggregate stats are deliberately stacked vertically to avoid overlap:

- Health x / y
- HP Bonus +N
- Armor N
- Dodge N%
- Crit N%
- Block N%

Do not return these to one wide horizontal line.

---

## 16. Item tooltips

Inside GoblinArcade character sheet, item tooltips intentionally show **only GoblinArcade stats**.

Do not show the normal WoW stat tooltip there.

Tooltip should include:

- item name in rarity color
- GoblinArcade role/style
- converted stats
- trait if available

Example armor tooltip:

```
Chainmail Vest
Bulwark
Health +12
Armor +6

BULWARK
+6 Armor.
```

Example weapon tooltip:

```
Heavy Copper Maul
Weapon
Damage 14 - 19
Two-Handed Mace - SLOW - Range 1

STAGGER
15% chance to delay the target's next action.
```

---

## 17. Inventory / drag and drop

The run snapshots the character's actual equipped WoW items into an internal GoblinArcade inventory.

This inventory is separate from real WoW equipment.

Character sheet supports drag & drop:

- equipment → backpack
- backpack → equipment
- equipment → compatible equipment slot

Slot compatibility is enforced.

When dragging:

- valid equipment slots glow **green**
- valid backpack cells glow **gold**
- invalid equipment slots are dimmed

This highlighting behavior was explicitly requested and should be preserved.

Changing main hand updates:

- run damage
- weapon archetype
- weapon trait

Removing the main hand results in unarmed fallback.

---

## 18. Dungeon loot

Current prototype chest loot includes:

### Candlekeeper's Charm

- Trinket
- GoblinArcade-converted
- goes into backpack

### Waxbound Ring

- Ring
- GoblinArcade-converted
- goes into backpack

Chest marker disappears after opening.

Loot can be equipped via the `C` character sheet.

Future dungeon loot should follow the same deterministic conversion system.

---

## 19. Run snapshot behavior

At BEGIN RUN:

- selected character snapshot is frozen;
- WoW gear changes outside GoblinArcade should not alter an active run;
- run maintains its own equipment state.

The active run keeps:

- character snapshot
- equipment
- backpack
- current/max HP
- converted stats
- exploration
- visibility
- score
- turn count
- enemy state
- opened chests

### Floor transitions / backtracking (0.20.0)

The Dungeon Run spans **Floor 1 → Floor 9**, and visited floors are now traversable in both directions during the active run.

Navigation:

- `>` descends to the next floor;
- `<` appears in the START room on Floors 2-9 and returns to the previous floor;
- returning to a previous floor restores its existing state rather than regenerating it;
- returning upward places the player on that floor's `>` exit;
- descending into an already visited floor places the player on its `<` entrance.

When moving between floors, the run preserves:

- current HP and max HP;
- GoblinArcade equipment;
- backpack and dungeon loot;
- score;
- total turn count;
- original character snapshot;
- frozen BEGIN RUN Gear Pressure.

A floor is generated only on its first visit. First-time generation creates its layout, room roles, doors, chest placement, density, enemies and rank mix. After that, its state is stored in `run.floorStates[floor]`.

Per-floor state preserved across backtracking includes:

- generated floor map and room roles;
- room clear / shrine used / Elite reward state;
- explored Fog of War;
- opened doors;
- opened chests;
- living/dead enemies, HP, positions and alert state;
- enemy phase counter;
- density profile and composition.

The player's HP, equipment, backpack, score and total turn count remain run-global and continue changing while moving between floors.

Dungeon loot found on earlier floors does **not** recalculate Gear Pressure. This preserves the value of upgrades found during the run.

Current prototype limitation: the same static chest locations and prototype chest items exist on every floor until the loot/floor-template system is expanded.

---

## 20. Recent UI fixes

Latest visual changes before this handoff:

1. Main window is currently **1384 × 944** to support the 7×7 viewport with 96×96 tiles.
2. Right combat panel widened to **182 px**, matching left run panel.
3. Kobold card moved back to the **right side** at user's request.
4. Kobold card uses the same horizontal dimensions as player card.
5. Relic UI removed completely.
6. Fog-of-war unseen borders set transparent to eliminate visible dots around the map.
7. Remembered floor borders made subtler.

Latest code version at handoff:

- **0.26.1**

Recent gameplay foundation:

- deterministic `EnemyGenerator.lua` added
- hardcoded kobold HP/damage removed
- BEGIN RUN now freezes player level + Gear Pressure for enemy scaling
- EnemyGenerator v2 applies Character-Level Pressure to both HP and damage
- EnemyGenerator v2 applies separate Floor HP (+6% per floor after Floor 1) and Floor Damage (+4% per floor after Floor 1) pressure
- FloorGenerator v1 rolls bounded QUIET / STANDARD / CROWDED population profiles
- DungeonRun now supports multiple simultaneously living enemies with collision-aware movement
- Floor 1 currently generates roughly 6–8 total enemies on the current 25×25 test map
- FloorGenerator v2 assigns bounded Kobold / Spider / Skeleton compositions within the same density budget
- EnemyGenerator v3 exposes deterministic movement patterns for enemy archetypes
- Spider moves 1 tile normally and 2 tiles on every second enemy phase
- Skeleton attacks every phase in melee but only advances on every second enemy phase
- Brute remains generator-only / future content
- Dungeon Run now advances through all 9 floors
- Floors 1–8 regenerate density, composition, enemies and Fog of War on exit
- Floor 9 exit completes the run
- HP, equipment, backpack, score and total turns persist across floor transitions
- frozen BEGIN RUN Gear Pressure persists across the entire 9-floor run
- dungeon logical tiles are now 96×96 px
- viewport remains 7×7
- creature source-art standard remains 128×128 px
- creature sprites render at 96×96 px inside 96×96 tiles and remain fully contained inside their own tile
- main window is now 1384×944 to accommodate the 678×678 grid
- Kobold grid art uses the 128×128 custom `kobold.tga`
- Spider and Skeleton now use dedicated 128×128 custom sprites for grid + target card
- temporary upload names `spider01_128x128.tga` and `skeleton01_128x128.tga` were normalized to `spider.tga` and `skeleton.tga`
- enemy tile backgrounds are no longer tinted red; only the enemy tile border is red
- FloorGenerator v3 now creates bounded Normal / Veteran / Elite rank compositions without increasing enemy count
- the target card prefixes Veteran / Elite ranks so stronger enemies are identifiable
- enemy intent remains internal AI state only; the right-side target card no longer exposes intent labels
- intent state is updated explicitly once per enemy phase; terrain rendering does not mutate enemy state
- ordinary killing blows now still trigger the enemy phase for other surviving enemies, closing the free-kill turn exploit
- DungeonGenerator v1 now generates a new connected room-and-corridor layout for every floor
- a single run seed produces deterministic per-floor layout seeds without calling math.randomseed
- start, exit and two chest locations are generated dynamically and enemy spawning respects those reserved cells
- chest loot templates are now assigned to generated chest positions instead of fixed map coordinates
- a 150×150 Fog-of-War-aware minimap now occupies the previously empty lower-right run panel
- minimap shows remembered terrain, brighter currently visible terrain, visible enemies in red, the player in green, discovered chests in gold and the discovered exit in green
- DungeonGenerator v2 detects room/corridor thresholds and creates real door cells
- closed doors display as +, block line of sight and enemy pathfinding, and open when the player bumps into them
- opening a door costs one player turn and triggers the normal enemy phase; opened doors display as / and remain open for the floor
- DungeonGenerator v3 assigns room roles: START / COMBAT / TREASURE / ELITE / SHRINE / EXIT / BOSS
- DungeonGenerator v4 fixes door placement: doors are now true room/corridor thresholds in the one-tile wall band outside rooms, not arbitrary room-edge contacts
- threshold detection requires room interior -> doorway -> continuing corridor, and contiguous doorway candidates collapse to one centered door
- DungeonGenerator v8 makes adjacent doors illegal: no two generated doors may share an orthogonal edge
- door counts are bounded by room: small rooms get at most 1 door; TREASURE / SHRINE / ELITE / BOSS rooms get at most 1; ordinary larger rooms get at most 2
- door selection prefers the center of a valid threshold segment, then searches outward for a non-adjacent candidate
- DungeonGenerator v5 adds a < stairs-up marker to the START room on Floors 2-9
- floors are now bidirectionally traversable during a run: > descends, < returns to the previous floor
- visited floor state is preserved in-memory per floor, including generated layout, enemies/deaths/positions, opened doors, opened chests and explored Fog of War
- returning upward places the player on the previous floor's > exit; descending again places the player on the deeper floor's < entrance without rerolling anything
- 0.20.1 fixes floor-state helper declaration order so restore/capture functions are in lexical scope before ApplyDungeonFloor
- 0.21.0 adds persistent per-room state for cleared encounters, shrine use and Elite rewards
- COMBAT / ELITE / BOSS rooms become cleared when every enemy assigned to that room is dead
- ELITE room clear replaces the ! marker with an Elite Cache chest containing a slightly stronger prototype loot item
- Floor 9 exit is sealed while the Boss encounter is alive; the exit renders as X/red and unlocks immediately when the Boss room is cleared
- Shrine rooms are interactive once per floor: RESTORE heals 25% max HP, BLESSING adds +5% run damage up to +25%, SACRIFICE costs 15% max HP (cannot kill) for +150 score
- Shrine choices use a compact modal with mouse buttons and 1/2/3 keyboard shortcuts; used shrines remain visually dimmed
- room state is included in bidirectional floor persistence, while Shrine damage blessing is run-global
- Floor 1-2 use START + COMBAT + TREASURE + EXIT; Shrine appears from Floor 3, Elite from Floor 5, Boss from Floor 9 when room count allows
- enemy spawning is now room-based: ordinary enemies spawn only in COMBAT / ELITE / BOSS rooms, leaving START / TREASURE / SHRINE / EXIT rooms clear
- ELITE rooms guarantee one Elite-ranked encounter anchor; BOSS rooms guarantee one Boss-ranked encounter anchor without increasing total enemy count
- Treasure rooms contain the generated chest markers; Shrine / Elite / Boss room centers use S / ! / B discovery markers
- Spider/Skeleton custom target-card art now uses full-frame portrait coordinates instead of Blizzard-icon cropping

---

## 21. Important UX decisions from the user

Preserve these unless user explicitly changes direction:

- UI should be compact and game-like.
- No giant input fields.
- No unnecessary rounded corners.
- Avoid duplicate portraits.
- Dungeon should feel like a real roguelike, not a debug grid.
- The character should matter.
- Gear conversion must be deterministic.
- Dungeon randomness belongs in gameplay, not conversion.
- Character selection belongs before BEGIN RUN.
- Home should remain minimal.
- Relic slots are currently unwanted.
- Enemy combat card belongs on the **right**.
- The lower-right run panel contains the dungeon minimap.
- Vision radius is **4**.
- Fog of war and LOS are important.
- User prefers screenshot-driven iteration.

---

## 22. Known technical debt / cautions

### DungeonRun.lua is very large

It currently contains:

- map/world logic;
- UI construction;
- combat;
- LOS;
- camera;
- loot;
- run lifecycle;
- enemy AI.

It is now ~70k bytes and is becoming a maintenance risk.

A later refactor should split it into modules such as:

- `DungeonWorld.lua`
- `DungeonUI.lua`
- `DungeonCombat.lua`
- `DungeonAI.lua`
- `DungeonLoot.lua`

Do **not** perform a large refactor without preserving current behavior and testing via /reload.

### Current enemy system

Multi-enemy support is now active in 0.14.2:

- run state uses `run.enemies` rather than one `run.enemy`;
- every enemy has a stable run-local UID;
- bump combat targets the enemy occupying the destination tile;
- the attack button targets the active/adjacent enemy;
- all living enemies receive a turn after the player acts;
- alerted enemies use occupancy-aware BFS and cannot stack on one tile;
- multiple adjacent enemies can each attack during the enemy turn;
- the right combat card follows the active adjacent target.

0.15.0 adds active Kobold + Spider + Skeleton archetypes to the multi-enemy framework. Floor composition is budgeted rather than additive, so archetype variety does not increase total density.

### Current map

DungeonGenerator v8 is active in 0.23.0.

- map dimensions remain 25×25;
- rooms are procedurally placed with one-cell separation;
- all rooms are connected by carved L-corridors;
- deeper floors receive a small number of extra loop connections;
- genuine corridor crossings through the one-tile wall band around a room become generated door cells;
- corridors merely running alongside a room no longer create false doors;
- contiguous threshold candidates collapse to one centered doorway;
- doors can never be orthogonally adjacent to another generated door;
- small and special-purpose rooms are capped at 1 door; larger ordinary rooms are capped at 2;
- closed doors block LOS and enemy pathfinding until the player opens them;
- opening a door is a one-turn bump action;
- every generated room receives one gameplay role;
- START, TREASURE, SHRINE and EXIT rooms are protected from ordinary enemy spawning;
- COMBAT rooms host ordinary encounters;
- ELITE rooms force one Elite encounter anchor;
- BOSS rooms force one Boss encounter anchor;
- Treasure rooms own the generated chest positions rather than using arbitrary map cells;
- room-role markers remain Fog-of-War gated;
- Floors 2-9 add a < stairs-up marker at the START room so visited floors can be traversed backward;
- the old static Test Cellar data remains only as a non-run fallback/preview.

The current generator is intentionally room-and-corridor based rather than full BSP/cellular generation so its output stays readable in the 7×7 camera.

---

## 23. Deterministic enemy scaling

**Implemented via `EnemyGenerator.lua`: base level + Gear Pressure in 0.14.0; Character-Level Pressure + Floor Pressure in 0.14.1.**

### Combat number compression (0.22.0)

All GoblinArcade combat-facing HP and damage values now use a global **10:1 compression**:

```
Compressed Value = round(Raw Value / 10)
```

Any positive HP or damage value has a minimum of **1** after compression.

Compressed values include:

- player base HP imported from WoW at BEGIN RUN;
- weapon min/max damage from WeaponGenerator v2;
- gear HP bonuses from ItemGenerator v3;
- enemy max HP and min/max damage from EnemyGenerator v5;
- percentage-based heals and HP costs automatically operate on the smaller run HP pool.

Unrelated systems are not divided: Armor, Dodge/Crit/Block percentages, score, movement, enemy count, item level and Gear Pressure multipliers stay unchanged.

The intent is readability and smaller RPG-style numbers, not a difficulty redesign. Level, floor, rank, archetype and Gear Pressure calculations still happen normally before final HP/damage compression.

Cached equipment is re-converted when generator versions are stale. Dungeon character selection and BEGIN RUN also resolve the main-hand weapon through the current generator so offline alts do not keep legacy 10x weapon values.

Enemy strength must be deterministic and should depend on both **character level** and the character's **starting WoW gear quality**.

### Character level component

Base enemy level starts from the selected character's WoW level.

Floor bonus:

- Floor 1-2: +0
- Floor 3-4: +1
- Floor 5-6: +2
- Floor 7-8: +3
- Floor 9: +4

Rank bonus:

- Normal: +0
- Veteran: +1
- Elite: +2
- Boss: +3

Base effective enemy level:

```
Player Level + Floor Bonus + Rank Bonus
```

Do not clamp internal effective level to 60. A level-60 character can face enemies with higher internal effective levels on later floors / higher ranks.

### Gear Pressure component

The starting WoW equipment also affects challenge.

Eligible gear slots are the GoblinArcade equipment slots:

- head
- neck
- shoulder
- chest
- waist
- legs
- feet
- wrist
- hands
- finger1
- finger2
- trinket1
- trinket2
- back
- mainhand
- offhand

Use the **sum of item levels**, normalized against the character level.

For two-handed and ranged weapons that consume the off-hand budget, the main-hand item level also fills the virtual off-hand budget when no actual off-hand is equipped.

Baseline expected item level:

```
Expected Average Item Level = Player Level + 3
Expected Gear Sum = 16 × Expected Average Item Level
```

Then:

```
Gear Index = Actual Gear Sum / Expected Gear Sum
Overgear = clamp(Gear Index - 1.0, 0.0, 0.50)
```

Example:

- Level 60 baseline average ilvl: 63
- Expected Gear Sum: 16 × 63 = 1008
- Actual Gear Sum: 1260
- Gear Index: 1.25
- Overgear: 0.25

Enemy scaling from Overgear:

```
Enemy HP multiplier     = 1 + Overgear × 0.70
Enemy Damage multiplier = 1 + Overgear × 0.35
```

At 25% overgear:

- enemy HP: +17.5%
- enemy damage: +8.75%

This is deliberately **partial scaling**, not full matching. Better gear must still make the player stronger overall.

Do not scale enemies downward for weak gear. This avoids intentional gear-stripping exploits.

### Freeze rule

Gear Pressure is calculated from the selected character's **starting WoW gear snapshot at BEGIN RUN** and is frozen for the run.

Dungeon loot found during the run must **not** increase enemy scaling.

This is essential so dungeon upgrades remain meaningful.

### Character-level pressure

Character level already increases the base enemy stats through Effective Enemy Level, but higher-level characters should also face a slightly higher **relative** challenge.

Use:

```
Level Pressure =
1 + 0.15 × ((Player Level - 1) / 59)
```

Reference values:

```
Level 1  → 1.00x
Level 10 → ~1.02x
Level 20 → ~1.05x
Level 40 → ~1.10x
Level 60 → 1.15x
```

This pressure is intentionally mild. Leveling a character must not feel like punishment, but a level-60 character should not face exactly the same relative difficulty as a level-1 character.

**Implementation status: active; current EnemyGenerator is v10 after the 0.56.0 difficulty pass.**

### Floor progression pressure

Dungeon depth is a separate difficulty axis from character level.

Use:

```
Floor HP Multiplier =
1 + 0.15 × (Floor - 1)

Floor Damage Multiplier =
1 + 0.05 × (Floor - 1)
```

Reference progression:

```
Floor 1 → HP 1.00x / Damage 1.00x
Floor 2 → HP 1.15x / Damage 1.05x
Floor 3 → HP 1.30x / Damage 1.10x
Floor 5 → HP 1.60x / Damage 1.20x
Floor 7 → HP 1.90x / Damage 1.30x
Floor 9 → HP 2.20x / Damage 1.40x
```

This is deliberately stronger than the character-level pressure. The run should become meaningfully more dangerous as the player descends through floors.

**Implementation status: active in EnemyGenerator v2 (addon 0.14.1).**

### Final enemy formulas

Effective Enemy Level remains:

```
Effective Enemy Level =
Player Level + Floor Level Bonus + Rank Bonus
```

The final deterministic stat pipeline should be:

```
Raw Enemy HP =
Base HP from Effective Enemy Level
× Enemy Archetype HP Multiplier
× Enemy Rank HP Multiplier
× Level Pressure
× Floor HP Multiplier
× Gear Pressure HP Multiplier

Final Enemy HP = round(Raw Enemy HP / 10), minimum 1
```

```
Raw Enemy Damage =
Base Damage from Effective Enemy Level
× Enemy Archetype Damage Multiplier
× Enemy Rank Damage Multiplier
× Level Pressure
× Floor Damage Multiplier
× Gear Pressure Damage Multiplier

Final Enemy Damage = round(Raw Enemy Damage / 10), minimum 1
```

The design intent is:

- Character level sets the main power band.
- Floor progression raises difficulty over the course of a run.
- Rank differentiates Normal / Veteran / Elite / Boss.
- Archetype creates enemy identity.
- Gear Pressure prevents highly geared characters from trivializing the dungeon.
- Gear Pressure remains partial scaling, so better gear is still a real advantage.
- All of these values are deterministic.
- Randomness belongs only in combat rolls inside fixed generated ranges.

### Enemy archetype layer

After level and Gear Pressure are calculated, individual enemy archetypes modify final stats.

Current generator profiles:

- Kobold: HP ×0.95, damage ×1.00, vision 6, NORMAL movement
- Spider: HP ×0.70, damage ×0.80, vision 7, QUICK movement
- Skeleton: HP ×1.20, damage ×1.00, vision 5, SLOW movement
- Brute: HP ×1.50, damage ×1.25, vision 5, generator-only future content

Movement behavior:

- NORMAL: 1 movement tile per enemy phase while alerted.
- QUICK: 1 movement tile normally, 2 tiles on every second enemy phase.
- SLOW: 0 movement tiles on one phase, 1 tile on the next; melee attacks are not slowed.

Current ranks:

- Normal: level +0, HP ×1.00, damage ×1.00
- Veteran: level +1, HP ×1.30, damage ×1.12
- Elite: level +2, HP ×1.80, damage ×1.30
- Boss: level +3, HP ×3.60, damage ×1.60

Base formulas currently implemented:

```
Reference Damage = 5 + Effective Enemy Level × 0.90
Base Enemy HP = Reference Damage × 3.25

Reference Player HP = 100 + Effective Enemy Level × 20
Average Enemy Damage = Reference Player HP × 4.0%
Damage range = 80%–120% of that deterministic average
```

Archetype, rank, Character-Level Pressure, Floor Pressure and frozen Gear Pressure multipliers are applied afterward.

Enemy level, base HP, base damage, archetype multipliers and Gear Pressure must all be deterministic. Randomness may exist only in individual combat rolls such as exact damage within a fixed range.

---

## 24. Planned bounded monster density

Monster density should vary from floor to floor, but only inside controlled, human-scale limits.

**Implemented in 0.14.2 via `FloorGenerator.lua` plus multi-enemy support in `DungeonRun.lua`.**

### Base enemy count

The current fixed 25×25 dungeon uses a depth table so procedural room/corridor RNG cannot accidentally change the combat budget:

```
Floor 1  → 6
Floor 2  → 6
Floor 3  → 7
Floor 4  → 7
Floor 5  → 8
Floor 6  → 8
Floor 7  → 9
Floor 8  → 9
Floor 9  → 10
```

`walkableTiles` remains in the FloorGenerator API for future map-size scaling, but does not currently change this base count.

### Random density profile

Each floor rolls exactly one bounded density profile when the floor is created:

```
QUIET      20% → ×0.90
STANDARD   60% → ×1.00
CROWDED    20% → ×1.10
```

Expected practical range on the current map is roughly:

- Floor 1: about 5–7 enemies
- Floor 9: about 9–11 enemies

The goal is noticeable variation without empty floors or excessive swarms.

### Persistence rule

The density profile is rolled **once when the floor/run is created** and stored in run state. UI rerenders, movement, combat and opening the character sheet do not reroll it.

Important current limitation: GoblinArcade does not yet persist an active Dungeon Run across a full WoW `/reload`. A reload ends the in-memory run itself, so true cross-reload floor persistence belongs to a future run-save system.

### Spawn safety rules

Initial floor generation should enforce:

- no enemy on the player start tile;
- no enemy inside a small safe radius around the player start;
- no enemy on walls or occupied cells;
- no enemy directly on exit/chest/objective cells unless intentionally designed;
- avoid extreme initial clusters of many enemies in a tiny area;
- normal floor generation should not create unavoidable instant swarms.

Current implementation uses:

- player-start safe radius: **4 tiles**;
- preferred minimum initial enemy-to-enemy spawn distance: **3 tiles**;
- randomized candidate order;
- a uniqueness-preserving fallback if a future map is too constrained for the preferred spacing;
- all static marker cells are reserved from ordinary enemy spawning.

### Archetype composition

Implemented in FloorGenerator v2. Enemy archetypes **share the existing density budget**.

Current floor weights:

```
Floor 1–2:
Kobold 80%
Spider 20%
Skeleton 0%

Floor 3–4:
Kobold 60%
Spider 30%
Skeleton 10%

Floor 5–6:
Kobold 45%
Spider 30%
Skeleton 25%

Floor 7–8:
Kobold 35%
Spider 30%
Skeleton 35%

Floor 9:
Kobold 25%
Spider 25%
Skeleton 50%
```

The generator converts these weights into bounded integer counts for the floor, then shuffles the archetype plan before assigning spawn locations. This prevents extreme rolls such as an early floor accidentally becoming all Spiders.

### Rank interaction

**Originally implemented in FloorGenerator v3 / GoblinArcade 0.17.0; current tuned generator is FloorGenerator v4 in 0.53.0.**

Veteran and Elite enemies replace Normal enemies inside the existing population budget; they do **not** add extra bodies. Boss remains reserved for objective-specific encounters.

Current floor rank weights:

```
Floor 1–2:
Normal 100%
Veteran 0%
Elite 0%

Floor 3–4:
Normal 80%
Veteran 20%
Elite 0%

Floor 5–6:
Normal 75%
Veteran 25%
Elite 0%

Floor 7–8:
Normal 60%
Veteran 30%
Elite 10%

Floor 9:
Normal 45%
Veteran 35%
Elite 20%
```

Weights are converted into bounded integer counts for the actual floor population and the resulting rank plan is shuffled before assignment. Existing deterministic rank stat multipliers in EnemyGenerator remain authoritative.

### Difficulty axes

Floor difficulty should eventually come from several partially independent systems:

1. deterministic character-level scaling;
2. deterministic floor HP/damage pressure;
3. bounded random density profile;
4. enemy archetype composition;
5. rank mix.

Randomness is appropriate in floor composition/density. It must remain bounded. Gear conversion and enemy stat formulas themselves remain deterministic.

---

## 25. Recommended next development steps

Deterministic scaling, bounded density, multi-enemy support, three active archetypes, the 9-floor run loop, bounded rank composition, enemy intent presentation, combat turn cleanup, and procedural room-and-corridor generation are complete.

Recommended order:

**Current priority after 0.53.0:** playtest the new balance curve through Floor 6+ with both a fresh Arcade Warrior and a geared WoW Warrior; tune observed pain points before adding more item quantity or starting Rogue.

1. **Studio data migration**
   - configure the two Vercel publish secrets once
   - EnemyGenerator v5 reads enemy archetypes and ranks from GA.StudioData
   - DungeonGenerator v8 reads room door limits and map markers from GA.StudioData
   - Shrine effects and Shrine UI values read from GA.StudioData
   - Warrior spellbook data is populated and all 29 retained abilities are runtime-wired. Next priorities are in-game combat testing/balance, finite potion handling and Studio/runtime loot-table migration

2. **Room-role gameplay polish**
   - test the stricter door rules, Shrine modal, Elite Cache and Floor 9 exit lock in-game
   - cleared COMBAT / BOSS rooms now receive a green * center marker; Elite rooms show the same marker after the Elite Cache is claimed
   - tune room counts / sizes from screenshots
   - later add more reward tables / Shrine choices

3. **Abilities / combat validation**
   - all 29 retained Warrior abilities are runtime-wired
   - the right rail exposes icon buttons for Character Sheet and the paged Spellbook; B remains the Spellbook shortcut
   - learned abilities use true drag-and-drop onto configurable slots 2-9, and occupied action slots can be dragged to move/swap
   - slot 1 is fixed Basic Attack; slot 0 is reserved for Potion
   - per-character action-bar loadouts persist in SavedVariables
   - next: in-game validation and balance pass, then finite potion handling

4. **Potions / consumables**
   - finite potion use is active on slot 0
   - potion stacks, heal/resource effects and enemy-turn consumption are wired
   - next: tune potion availability/effect values from playtesting and add additional consumables only when needed

5. **Floor objectives**
   - exit
   - elite
   - chest
   - shrine/shop
   - boss

6. **More deterministic loot**
   - Studio Items + named Loot Tables + Loot Entries + Dungeon Objects are active; Treasure/Elite containers and enemy archetypes resolve loot through reusable Loot Table IDs
   - add more armor / jewelry / weapons and Boss/Enemy/Shop loot entries
   - keep clear archetype-based differences

7. **Scores**
   - run score summary
   - eventual local/group sharing

---

## 26. Development workflow for the next context

When modifying code:

1. Fetch the current file from `main` before editing.
2. Use the current SHA for `update_file`.
3. Prefer atomic multi-file commits when possible to avoid multiple redundant deployments.
4. Push to `main`.
5. GitHub Actions deploys automatically.
6. Tell the user to test with `/reload`.
7. Ask for a screenshot/error only after implementation if needed.

Do not assume an earlier file snapshot is still current.

---

## 27. Current test character

Current frequently tested character:

- **Max Carnage**
- Orc Warrior
- Level 13

Known example run values after 0.22.0 combat-number compression:

- raw WoW health around 358 → GoblinArcade base HP around 36
- Heavy Copper Maul
- previous GoblinArcade damage 14–19 → compressed damage around 1–2
- STAGGER 15%

These are useful sanity checks, not hard-coded gameplay requirements.

---

## 28. Product direction

Long-term dungeon concept:

- 9 floors (**run progression implemented in 0.16.0**)
- 7×7 camera viewport
- larger dungeon world underneath
- movement consumes turns
- bump combat
- class abilities
- enemy AI variety
- persistent HP during run
- limited potion
- dungeon loot
- character gear conversion
- chest / shrine / shop / elite / boss layers
- score summary on death / completion

There should be no separate roguelike XP system replacing WoW progression.

Synced WoW character level and WoW gear remain the primary foundation; generated Arcade heroes are an explicitly separate supported-class fallback.

---

## 29. Final reminder

This project is being built by rapid visual iteration.

Before changing layout conventions, remember the user's current preferences:

- enemy card on the right;
- player card on the left;
- both use matching horizontal card proportions;
- right and left side panels are 182 px;
- Home is minimal;
- no relic panel;
- vision radius = 4;
- map should not visually overlap side panels;
- dungeon logical tile baseline is 96×96 px;
- viewport baseline is 7×7 visible tiles;
- creature art baseline is 128×128 source rendered at 96×96 px with no tile overflow;
- enemy cells keep the terrain background and use only a red border for hostile highlighting;
- active floors use the procedural DungeonGenerator; do not restore fixed start/exit/chest coordinates;
- generated rooms use strict room-to-corridor threshold doors in the wall band outside the room; a door tile must have exactly two orthogonally walkable neighbors (room interior + outward corridor), can never be a corner/junction/parallel-corridor cell, blocks LOS while closed, and opens on bump for one turn;
- two generated doors must never be orthogonally adjacent; small rooms remain hard-capped at 1 door, while larger room-role door limits are Studio-driven;
- generated rooms have gameplay roles; START / TREASURE / SHRINE / EXIT stay free of ordinary enemy spawns;
- dungeon floors are bidirectional inside an active run: > descends and < returns, with visited floor state restored rather than regenerated;
- Floor 9 exit stays locked while its Boss room still has a living boss;
- Shrine / room-clear / Elite reward state must persist with the floor across backtracking;
- minimap belongs in the lower-right run panel and respects Fog of War instead of revealing unexplored rooms;
- fog should not show dotted borders;
- item tooltips should show GoblinArcade stats, not WoW stats;
- dungeon-created equipment/consumables are defined in Studio Items; reusable Studio Loot Tables own weighted Loot Entries, and both Enemy records and Dungeon Object records attach to those tables by ID; explicit Studio item stats and Price (Copper) are authoritative, while real WoW gear still uses ItemGenerator/WeaponGenerator conversion;
- action slot 0 is the finite Potion slot: it uses real backpack Potion consumables, consumes one stack and one player turn, then advances the enemy phase;
- all GoblinArcade HP and damage values use the global 10:1 compression; do not restore the older large-number scale;
- GoblinArcade Studio stays static-first; the only backend is the on-demand publish request, so avoid database/always-on Vercel spend;
- Warrior ability names and minimum unlock levels should track the current Forever spellbook rather than invented class skills;
- a dungeon run starts at the real WoW level, then can gain temporary run levels up to 60; temporary levels and XP reset next run;
- run level-up may increase max/current HP and resource cap according to the selected class's Studio-driven HP / Level and Resource / Level values; gear bonuses remain separate and continue to recalculate from the run's equipment;
- newly generated floors scale enemies from the current temporary run level; already generated floors retain their existing encounter state;
- omit WoW abilities whose core mechanic has no meaningful solo-roguelike translation; currently Taunt, Mocking Blow and Challenging Shout are excluded;
- do not modify or deploy the unrelated liminal-space Vercel project while working on GoblinArcade;
- drag targets must visually highlight;
- the run combat bar uses fixed Basic Attack on 1, eight configurable WoW-style icon spell slots on 2-9, Potion on 0, and B for the paged Spellbook;
- the right dungeon rail provides icon-based Character Sheet and Spellbook quick access;
- action-bar spell icons can be dragged between slots; occupied targets swap positions;
- Spellbook/action-bar loadouts persist per character in GoblinArcadeDB;
- Spellbook spells use WoW icons, with an optional Studio-driven icon override via texture shorthand/path/FileDataID;
- the Dungeon setup CHARACTER roster ends with a roster-sized + CREATE NEW CHARACTER slot that opens the modal Arcade Character Generator; generated heroes may be NORMAL or HARDCORE, dead Hardcore heroes remain in the roster but can never start another run, and generated heroes can be deleted with two-step confirmation; class availability is controlled by Studio Classes -> Playable / Ready, while race records/icons live in the Studio Races section and have no gameplay bonus yet.

Preserve those decisions unless the user explicitly asks to change them.
