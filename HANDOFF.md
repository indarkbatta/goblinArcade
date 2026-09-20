# GoblinArcade — Handoff

> **Maintenance rule:** Keep this file updated with every meaningful development change. Any change to version, UI, controls, combat, gear conversion, inventory, dungeon systems, deployment behavior, known issues, or next-step priorities must be reflected here in the same development cycle.

Last updated: 2026-09-20  
Current addon version: **0.38.0**  
Repository: `indarkbatta/goblinArcade`  
Default branch: `main`

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

Studio v1.1.0 keeps a **static-first** architecture for Vercel cost efficiency:

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
  - classes (including run-level HP/resource growth), enemies, ranks, room settings, shrine values and run-XP progression are runtime-driven; Warrior ability execution and loot remain to be migrated
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

Home deliberately contains **only**:

> Goblin Arcade - created by Midnight Traveler.

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
- the card shows a live intent line: WATCHING / ALERTED / MOVING / ATTACKING / STAGGERED

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
- enemy intent presentation is active on the right-side target card: WATCHING / ALERTED / MOVING / ATTACKING / STAGGERED
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

**Implementation status: active in EnemyGenerator v2 (addon 0.14.1).**

### Floor progression pressure

Dungeon depth is a separate difficulty axis from character level.

Use:

```
Floor HP Multiplier =
1 + 0.06 × (Floor - 1)

Floor Damage Multiplier =
1 + 0.04 × (Floor - 1)
```

Reference progression:

```
Floor 1 → HP 1.00x / Damage 1.00x
Floor 2 → HP 1.06x / Damage 1.04x
Floor 3 → HP 1.12x / Damage 1.08x
Floor 5 → HP 1.24x / Damage 1.16x
Floor 7 → HP 1.36x / Damage 1.24x
Floor 9 → HP 1.48x / Damage 1.32x
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

- Kobold: HP ×0.95, damage ×0.90, vision 6, NORMAL movement
- Spider: HP ×0.70, damage ×0.80, vision 7, QUICK movement
- Skeleton: HP ×1.20, damage ×1.00, vision 5, SLOW movement
- Brute: HP ×1.50, damage ×1.25, vision 5, generator-only future content

Movement behavior:

- NORMAL: 1 movement tile per enemy phase while alerted.
- QUICK: 1 movement tile normally, 2 tiles on every second enemy phase.
- SLOW: 0 movement tiles on one phase, 1 tile on the next; melee attacks are not slowed.

Current ranks:

- Normal: level +0, HP ×1.00, damage ×1.00
- Veteran: level +1, HP ×1.25, damage ×1.10
- Elite: level +2, HP ×1.60, damage ×1.25
- Boss: level +3, HP ×2.80, damage ×1.45

Base formulas currently implemented:

```
Reference Damage = 5 + Effective Enemy Level × 0.90
Base Enemy HP = Reference Damage × 2.20

Reference Player HP = 100 + Effective Enemy Level × 20
Average Enemy Damage = Reference Player HP × 3.5%
Damage range = 80%–120% of that deterministic average
```

Archetype, rank, Character-Level Pressure, Floor Pressure and frozen Gear Pressure multipliers are applied afterward.

Enemy level, base HP, base damage, archetype multipliers and Gear Pressure must all be deterministic. Randomness may exist only in individual combat rolls such as exact damage within a fixed range.

---

## 24. Planned bounded monster density

Monster density should vary from floor to floor, but only inside controlled, human-scale limits.

**Implemented in 0.14.2 via `FloorGenerator.lua` plus multi-enemy support in `DungeonRun.lua`.**

### Base enemy count

For a generated floor:

```
Base Enemy Count =
round((Walkable Tiles / 70) × (1 + 0.05 × (Floor - 1)))
```

The current 25×25 test map has roughly 497 walkable tiles, giving approximately:

```
Floor 1  → ~7 enemies
Floor 3  → ~8 enemies
Floor 5  → ~9 enemies
Floor 7  → ~9–10 enemies
Floor 9  → ~10 enemies
```

### Random density profile

Each floor rolls exactly one bounded density profile when the floor is created:

```
QUIET      20% → ×0.85
STANDARD   60% → ×1.00
CROWDED    20% → ×1.15
```

Expected practical range on the current map is roughly:

- Floor 1: about 6–8 enemies
- Floor 9: about 8–12 enemies

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

**Implemented in FloorGenerator v3 / GoblinArcade 0.17.0.**

Veteran and Elite enemies replace Normal enemies inside the existing population budget; they do **not** add extra bodies. Boss remains reserved for objective-specific encounters.

Current floor rank weights:

```
Floor 1–2:
Normal 100%
Veteran 0%
Elite 0%

Floor 3–4:
Normal 85%
Veteran 15%
Elite 0%

Floor 5–6:
Normal 70%
Veteran 25%
Elite 5%

Floor 7–8:
Normal 55%
Veteran 30%
Elite 15%

Floor 9:
Normal 40%
Veteran 35%
Elite 25%
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

4. **Potions**
   - finite run resource
   - no unlimited healing

5. **Floor objectives**
   - exit
   - elite
   - chest
   - shrine/shop
   - boss

6. **More deterministic loot**
   - armor
   - jewelry
   - weapons
   - clear archetype-based differences

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
- the Dungeon setup CHARACTER roster ends with a roster-sized + CREATE NEW CHARACTER slot that opens the modal Arcade Character Generator; class availability is controlled by Studio Classes -> Playable / Ready, while race records/icons live in the Studio Races section and have no gameplay bonus yet.

Preserve those decisions unless the user explicitly asks to change them.
