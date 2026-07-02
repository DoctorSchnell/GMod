# PVP Leaderboard v2.3.3

Persistent PVP leaderboard for Garry's Mod sandbox servers. Tracks kills, deaths, K/D ratio, kill streaks, and headshots across server reboots, over **four time windows**: all-time, the last 24 hours, the last 7 days, and the last 30 days. Each window has its own spawnable metal-framed floating sign entity with 3D2D rendering on both faces, and the `!pvpboard` panel switches between them.

## Features

- **Four Time Windows** — All-time, rolling 24-hour, rolling 7-day, and rolling 30-day boards. All-time keeps cumulative history; the windowed boards reflect recent activity.
- **Persistent Stats** — SQLite storage survives server reboots and map changes. A timestamped kill event log powers the rolling windows and is retained indefinitely.
- **Spawnable Entities** — One metal-framed floating sign per time window, each with 3D2D content on both faces. Always shows 10 rows. Perm Props compatible.
- **On-Screen Panel** — `!pvpboard` opens a draggable leaderboard overlay with tabs to switch between the four windows.
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
| `!pvpstats` | All | View your own (all-time) PVP stats in chat |
| `!pvpstats <player>` | Admin | View another player's PVP stats |
| `!pvpboard` | All | Open the leaderboard panel (with tabs for each window) |
| `!pvpboard <period>` | All | Open the panel on a specific tab (`alltime`, `24h`, `7d`, `30d`) |
| `!pvpsort <mode>` | Admin | Set the sort mode for all players (kills, kd, streak, headshots) |
| `!pvpreset <player>` | SuperAdmin | Reset a player's stats to zero (also removes their kills from the windowed boards) |
| `!pvpresetall` | SuperAdmin | Wipe the entire leaderboard incl. the event log (cannot be undone) |

## Entities

Spawn from the Entities tab in the spawn menu under the **PVP Leaderboard** category. There is one entity per time window — pick the board you want and spawn it directly. The time window is baked into the entity class, so a Perm Prop restores the correct board after a map change.

| Entity (class) | Board shown | Backing Model | Display Size |
|----------------|-------------|---------------|--------------|
| PVP Leaderboard (All Time) (`pvp_leaderboard`) | All-time | `plate3x5.mdl` | ~235 x 144 game units |
| PVP Leaderboard (24 Hour) (`pvp_leaderboard_24h`) | Rolling 24h | `plate3x5.mdl` | ~235 x 144 game units |
| PVP Leaderboard (7 Day) (`pvp_leaderboard_7d`) | Rolling 7d | `plate3x5.mdl` | ~235 x 144 game units |
| PVP Leaderboard (30 Day) (`pvp_leaderboard_30d`) | Rolling 30d | `plate3x5.mdl` | ~235 x 144 game units |

Every entity renders as a metal-framed floating sign (dark gunmetal frame, charcoal panel), displays on both faces, has solid collision via a hidden PHX plate, and re-freezes after physgun placement. All are invulnerable to all damage including ACF projectiles. The windowed variants inherit their behaviour from the base `pvp_leaderboard` entity; only the board they display differs.

### Window behaviour

- **Rolling windows** — 24h/7d/30d show kills from the trailing 24 hours / 7 days / 30 days, sliding continuously.
- **Instant on new kills** — a new kill appears on every board (including the windowed ones) immediately.
- **Aging out** — kills that fall outside a window drop off it on the next cache refresh (`pvplb_cache_interval`, default 60s), so a windowed board lags at most that interval on its trailing edge.
- **Best streak** in a windowed board counts the longest run of consecutive kills *within that window*.

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
- The same rules apply to every time window — each validated kill counts toward all-time and is logged to the event table for the rolling windows
- The all-time board lists all players (padding with zero-kill players if few exist); the windowed boards list only players with at least one kill inside that window

## File Structure

```
garrysmod/addons/pvp_leaderboard/
├── addon.json
├── README.md
└── lua/
    ├── autorun/
    │   ├── sh_pvp_leaderboard.lua                -- Shared ConVars, period definitions, namespace, config sync
    │   ├── client/
    │   │   └── cl_pvp_leaderboard.lua            -- Client cache, rendering, net receivers
    │   └── server/
    │       ├── sv_pvp_leaderboard_db.lua          -- Stats + event log, windowed aggregates, caches, net sync
    │       └── sv_pvp_leaderboard_tracking.lua    -- Kill tracking via PlayerDeath hook
    ├── entities/
    │   ├── pvp_leaderboard/                       -- Base (All Time) entity
    │   │   ├── shared.lua                         -- Entity registration (ENT.Period = "alltime")
    │   │   ├── init.lua                           -- Server physics, damage protection
    │   │   └── cl_init.lua                        -- Client 3D rendering
    │   ├── pvp_leaderboard_24h/                   -- 24-hour variant (init/cl_init/shared, inherits base)
    │   ├── pvp_leaderboard_7d/                    -- 7-day variant (init/cl_init/shared, inherits base)
    │   └── pvp_leaderboard_30d/                   -- 30-day variant (init/cl_init/shared, inherits base)
    └── ulx/
        ├── modules/sh/
        │   └── pvp_leaderboard.lua                -- ULX commands
        └── xgui/settings/
            └── pvp_leaderboard.lua                -- XGUI settings panel
```

## Version History

- **2.3.3** — Restored the `init.lua`/`cl_init.lua` files on the 24h/7d/30d entity variants. The 2.3.2 change to a single `shared.lua` per variant is theoretically supported by GMod but, on this server, left the windowed variants absent from the Q menu (only the all-time board registered). The thin init/cl_init/shared trio is required here, not just convention.
- **2.3.2** — Internal optimization and cleanup pass (no config/command changes). Fixed ACF protection: the signs used an ACF2-era `ACF_Damage` global wrapper that no longer exists on ACF-3, so they were unprotected against ACF weapons — now vetoed via the native `ACF_PreDamageEntity` hook. Per-kill database writes cut from 6–8 queries to 3 (in-SQL arithmetic, `INSERT OR IGNORE`). Rolling-window recompute now does a single indexed pass over the widest window instead of one scan per window (and orders by the indexed `ts` column). Per-kill leaderboard broadcasts are coalesced (kill bursts collapse into one sync). Client signs now draw a cached static mesh through a model matrix instead of rebuilding the mesh and allocating dozens of vectors every frame; display rows are re-sorted on data/sort changes rather than every frame. Removed the redundant `init.lua`/`cl_init.lua` files from the 24h/7d/30d entity variants (each is now a single `shared.lua`).
- **2.3.1** — Fixed the leaderboard signs rendering behind translucent objects (chat bubbles, sprites, particles). The signs were `RENDERGROUP_TRANSLUCENT`, which skips depth-buffer writes and let those objects overdraw the board. They now render as `RENDERGROUP_OPAQUE` (the panel is effectively solid), so they write depth and translucent objects correctly sort behind them.
- **2.3.0** — Added rolling time-windowed boards (24h / 7d / 30d) alongside the existing all-time board. Each window has its own spawnable entity (`pvp_leaderboard_24h` / `_7d` / `_30d`), and the `!pvpboard` panel gained tabs to switch between windows (`!pvpboard <period>` opens a specific tab). Backed by a new timestamped kill event log with in-memory windowed aggregates updated per kill (O(1) hot path) and an indexed periodic replay to age out old kills — performance stays flat regardless of event-log size. Resets now also clear event-log data.
- **2.2.2** — Fix leaderboard entity being unfrozen by explosive blast force.
- **2.2.1** — 2x text resolution rendering, row/border alignment fixes, vertical spacing tuning.
- **2.2.0** — Auto-cycling sort mode (Kills → K/D → Best Streak → Headshots) with split-flap transition animation. Active sort column highlighted in header. Configurable cycle interval via `pvplb_sort_interval`.
- **2.1.0** — Entity is now invulnerable to all damage including ACF projectiles.
- **2.0.0** — Consolidated three entity sizes (small/medium/large) into a single `pvp_leaderboard` entity backed by a hidden PHX 3x5 plate. Added `!pvpboard` command. Signs re-freeze after physgun placement.
- **1.1.0** — Replaced PHX plate backing props with metal-framed floating sign rendering.
- **1.0.0** — Initial release.

## Author

Doctor Schnell & Claude (Anthropic)
