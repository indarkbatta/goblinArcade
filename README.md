# GoblinArcade

A WoW Forever addon for tiny games during queues, raid downtime, summons, and all the other moments when Azeroth makes you wait.

## Current state

The first milestone is the addon shell:

- native WoW Forever UI
- draggable GoblinArcade window
- player portrait/name/level/class summary
- Dungeon Run placeholder
- slash commands: `/ga` and `/goblinarcade`

The first actual cabinet will be **Dungeon Run**, a turn-based roguelike that derives its starting equipment from the player's WoW gear metadata.

## WoW Forever target

Current beta target:

- WoW Forever 1.60.x
- Interface 16001
- `_classic_beta_`

## Local deployment

Pushes to `main` are deployed by the Windows self-hosted runner.

The workflow checks common WoW install locations first. If the Forever client is installed elsewhere, set `WOW_FOREVER_ADDONS` either as a runner environment variable or a GitHub repository variable, pointing to:

```
...\World of Warcraft\_classic_beta_\Interface\AddOns
```

No compilation or packaging is required.
