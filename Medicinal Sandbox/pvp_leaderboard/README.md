# PVP Leaderboard v2.2.2

Persistent PVP leaderboard for Garry's Mod sandbox servers. Tracks kills, deaths, K/D ratio, kill streaks, and headshots across server reboots. Displays stats on a spawnable metal-framed floating sign entity with 3D2D rendering on both faces.

## Features

- **Persistent Stats** — SQLite storage survives server reboots and map changes.
- **Spawnable Entity** — Metal-framed floating sign with 3D2D content on both faces. Always shows 10 rows. Perm Props compatible.
- **On-Screen Panel** — `!pvpboard` opens a draggable leaderboard overlay.
- **Auto-Cycling Sort** — Leaderboard rotates through Kills, K/D, Best Streak, and Headshots with a split-flap transition animation.
- **XGUI Settings Panel** — Configure tracking, display entries, sort cycle speed, and cache intervals.
- **Kill Validation** — Only counts kills where the attacker is tagged by the PVP Combat Timer addon.
- **Headshot Tracking** — Detects headshots via `LastHitGroup()` (works for bullet weapons including CW 2.0).

## Requirements

- [ULX](https://github.com/TeamUlysses/ulx) / [ULib](https://github.com/TeamUlysses/ulib) + XGUI (admin framework, commands, settings panel)
- PVP Combat Timer addon by Doctor Schnell (provides `PVPCombat.IsInCombat()` for kill validation)
- Perm Props (optional, for saving entity placement across map changes)

## Installation

1. Copy the `pvp_leaderboard` folder into your server's `garrysmod/addons/` directory.
2. Restart the server (or change map).
3. The SQLite database table is created automatically on first load.

## Configuration

All settings are managed via the XGUI panel (Settings > PVP Leaderboard) or console ConVars. All require SuperAdmin.

| ConVar | Default | Range | Description |
|--------|---------|-------|-------------|
| `pvplb_enabled` | `1` | 0-1 | Enable/disable PVP leaderboard stat tracking |
| `pvplb_max_entries` | `10` | 5-25 | Maximum number of players shown on leaderboard displays |
| `pvplb_cache_interval` | `60` | 15-300 | Seconds between automatic cache refreshes from database |
| `pvplb_sort_interval` | `20` | 10-120 | Seconds between automatic sort column cycling on displays |

## Commands

| Command | Access | Description |
|---------|--------|-------------|
| `!pvpstats` | All | View your own PVP stats in chat |
| `!pvpstats <player>` | Admin | View another player's PVP stats |
| `!pvpboard` | All | Open the leaderboard as a draggable on-screen panel |
| `!pvpsort <mode>` | Admin | Set the sort mode for all players (kills, kd, streak, headshots) |
| `!pvpreset <player>` | SuperAdmin | Reset a player's stats to zero |
| `!pvpresetall` | SuperAdmin | Wipe the entire leaderboard (cannot be undone) |

## Entity

Spawn from the Entities tab in the spawn menu under the **PVP Leaderboard** category.

| Entity | Backing Model | Display Size |
|--------|---------------|--------------|
| PVP Leaderboard | `plate3x5.mdl` | ~235 x 144 game units |

The entity renders as a metal-framed floating sign (dark gunmetal frame, charcoal panel), displays on both faces, has solid collision via a hidden PHX plate, and re-freezes after physgun placement. The entity is invulnerable to all damage including ACF projectiles.

## Stats Tracked

| Stat | Description |
|------|-------------|
| Kills | Total PVP kills (attacker must be combat-tagged) |
| Deaths | Deaths where the killer was a combat-tagged player |
| K/D Ratio | Calculated at display time (kills / deaths) |
| Current Streak | Consecutive kills without dying (resets on death) |
| Best Streak | Highest kill streak ever achieved (persistent) |
| Headshots | Kills where the final hit was to the head |

### Kill Counting Rules

- Only counts when the attacker is tagged by the PVP Combat Timer (`PVPCombat.IsInCombat(attacker)`)
- Buildmode players are excluded at the combat timer level (never tagged)
- Self-kills (suicide, fall damage) are ignored
- Bot kills/deaths are excluded
- Headshot detection uses `LastHitGroup() == HITGROUP_HEAD` (works for bullet weapons including CW 2.0; may miss some ACF projectile kills)

## File Structure

```
garrysmod/addons/pvp_leaderboard/
├── addon.json
├── README.md
└── lua/
    ├── autorun/
    │   ├── sh_pvp_leaderboard.lua                -- Shared ConVars, namespace, config sync
    │   ├── client/
    │   │   └── cl_pvp_leaderboard.lua            -- Client cache, rendering, net receivers
    │   └── server/
    │       ├── sv_pvp_leaderboard_db.lua          -- Database, cache, net sync, admin config
    │       └── sv_pvp_leaderboard_tracking.lua    -- Kill tracking via PlayerDeath hook
    ├── entities/pvp_leaderboard/
    │   ├── shared.lua                             -- Entity registration
    │   ├── init.lua                               -- Server physics, damage protection
    │   └── cl_init.lua                            -- Client 3D rendering
    └── ulx/
        ├── modules/sh/
        │   └── pvp_leaderboard.lua                -- ULX commands
        └── xgui/settings/
            └── pvp_leaderboard.lua                -- XGUI settings panel
```

## Version History

- **2.2.2** — Fix leaderboard entity being unfrozen by explosive blast force.
- **2.2.1** — 2x text resolution rendering, row/border alignment fixes, vertical spacing tuning.
- **2.2.0** — Auto-cycling sort mode (Kills → K/D → Best Streak → Headshots) with split-flap transition animation. Active sort column highlighted in header. Configurable cycle interval via `pvplb_sort_interval`.
- **2.1.0** — Entity is now invulnerable to all damage including ACF projectiles.
- **2.0.0** — Consolidated three entity sizes (small/medium/large) into a single `pvp_leaderboard` entity backed by a hidden PHX 3x5 plate. Added `!pvpboard` command. Signs re-freeze after physgun placement.
- **1.1.0** — Replaced PHX plate backing props with metal-framed floating sign rendering.
- **1.0.0** — Initial release.

## Author

Doctor Schnell & Claude (Anthropic)
