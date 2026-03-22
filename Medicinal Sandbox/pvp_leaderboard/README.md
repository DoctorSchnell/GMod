# PVP Leaderboard

Persistent PVP leaderboard for Garry's Mod sandbox servers. Tracks kills, deaths, K/D ratio, kill streaks, and headshots across server reboots. Displays stats on spawnable floating sign entities (small, medium, large) with metal-framed 3D mesh rendering and leaderboard content on both faces. Works immediately on spawn, including after Perm Props re-creation.

## Requirements

- **Garry's Mod** dedicated server
- **ULX / ULib** + **XGUI** (admin framework, commands, settings panel)
- **PVP Combat Timer** addon by Doctor Schnell (provides `PVPCombat.IsInCombat()` used to validate kills)

Optional:
- **Perm Props** (third-party) for saving entity placement across map changes

## Installation

1. Copy the `pvp_leaderboard` folder into your server's `garrysmod/addons/` directory.
2. Restart the server (or change map).
3. The SQLite database table is created automatically on first load.

## Configuration

### XGUI Settings Panel

Open XGUI (Settings tab) and select **PVP Leaderboard**. All settings require SuperAdmin and use staged Apply/Reset buttons.

| Setting | ConVar | Default | Range |
|---|---|---|---|
| Tracking Enabled | `pvplb_enabled` | `1` | 0-1 |
| Leaderboard Entries | `pvplb_max_entries` | `10` | 5-25 |
| Cache Refresh Interval (sec) | `pvplb_cache_interval` | `60` | 15-300 |

### ConVars

All ConVars use `FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY` flags. They persist across map changes and replicate to clients.

## Commands

| Command | Access | Description |
|---|---|---|
| `!pvpstats` | All | View your own PVP stats in chat |
| `!pvpstats <player>` | Admin | View another player's PVP stats |
| `!pvpreset <player>` | SuperAdmin | Reset a player's stats to zero |
| `!pvpresetall` | SuperAdmin | Wipe the entire leaderboard (cannot be undone) |

## Entities

All three sizes are spawnable from the Entities tab in the spawn menu under the **PVP Leaderboard** category.

| Entity | Approximate Sign Width | Approximate Sign Height |
|---|---|---|
| PVP Leaderboard (Small) | ~47 units / 4 ft | ~30 units / 2.5 ft |
| PVP Leaderboard (Medium) | ~94 units / 8 ft | ~60 units / 5 ft |
| PVP Leaderboard (Large) | ~188 units / 16 ft | ~120 units / 10 ft |

All entities:
- Render as metal-framed floating signs (dark gunmetal frame, charcoal panel) using custom 3D mesh — same style as the AFK System overhead sign
- Display the leaderboard on both the front and back faces
- Have solid collision via `PhysicsInitBox` matching the sign dimensions
- Display data immediately on spawn by reading from the client-side cache
- Work with Perm Props (data loads from the database on server start, before entities spawn)
- Skip 3D2D rendering beyond a size-appropriate distance for performance

Place with the physgun like any prop. The sign renders vertically and follows the entity's yaw orientation.

### Adjusting Sign Appearance

Per-size constants at the top of each entity's `cl_init.lua`:
- `SCALE` - 3D2D-to-world-unit scale factor (determines sign size)
- `BORDER_SIZE` - metal frame border width in world units
- `RENDER_DIST_SQ` - squared distance cutoff for rendering

These may need fine-tuning in-game after first deployment.

## Stats Tracked

| Stat | Description |
|---|---|
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

## Data Storage

- SQLite via GMod's `sql.*` library (stored in `sv.db`)
- Table: `pvp_leaderboard_stats`, one row per player keyed by SteamID64
- Writes only on kill/death events (low frequency)
- No external dependencies or binary modules

## Architecture

```
Server: SQLite DB --> In-memory cache --> Net broadcast --> Clients
                         ^                                    |
                         |                                    v
                    PlayerDeath hook              Entity 3D2D rendering
                    (with PVPCombat gate)         (reads client cache)
```

The server maintains a cached copy of the top N players. This cache refreshes after every kill and on a configurable periodic timer. Entities never query the database directly. Clients receive the cache via net messages and store a local copy that entities read during 3D2D rendering.

## Version History

- **1.1.0** - Replaced PHX plate backing props with metal-framed floating sign rendering (AFK System style). Signs are solid with custom collision, display leaderboard on both faces.
- **1.0.0** - Initial release
