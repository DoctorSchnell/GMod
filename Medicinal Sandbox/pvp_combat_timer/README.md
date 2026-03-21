# PVP Combat Timer

A Garry's Mod addon that detects player-vs-player combat and temporarily restricts spawning and pickup of configurable entities during a cooldown period. Built for sandbox/build servers where you want to prevent players from spawning or grabbing healing items (or other entities) immediately after attacking someone.

## Features

- Automatic combat tagging when a player damages another player (attacker only)
- Configurable cooldown duration (5-30 seconds)
- Configurable blocklist of entity classes restricted during combat
- Pickup blocking toggle (uses the same blocklist, independently enabled/disabled)
- HUD countdown indicator with progress bar and fade animation
- Chat notifications when a blocked action is attempted (rate-limited to prevent spam)
- `!pvpstatus` chat command for players to check their combat status
- Full ULX integration with admin commands for managing the system
- XGUI settings panel for visual configuration
- Buildmode exemption (compatible with Buildmode-ULX / kythre)
- Prop protection compatibility (CPPI owner resolution for indirect damage)

## Installation

Drop the `pvp_combat_timer` folder into your server's `garrysmod/addons/` directory.

### Requirements

- ULX and ULib (for admin commands and XGUI panel)
- Optional: Buildmode-ULX by kythre (buildmode players are exempt from tagging)

## Configuration

All settings are managed through replicated ConVars that persist across map changes and server restarts. You can change them through the XGUI panel, ULX commands, or the server console.

### ConVars

| ConVar | Default | Range | Description |
|---|---|---|---|
| `pvpcombat_enabled` | `1` | 0-1 | Enable or disable the system |
| `pvpcombat_cooldown` | `10` | 5-30 | Seconds after attacking before restrictions lift |
| `pvpcombat_blocklist` | `item_healthkit;item_battery` | string | Semicolon-delimited list of entity classes blocked during combat |
| `pvpcombat_block_pickup` | `1` | 0-1 | Block pickup of ground items during combat (uses same blocklist) |

### ULX Commands

| Command | Access | Description |
|---|---|---|
| `!pvpcombattest` | Admin | Tag yourself as in-combat for testing |
| `!pvpcombatclear <player>` | SuperAdmin | Manually clear a player's combat tag |

### Chat Commands

| Command | Access | Description |
|---|---|---|
| `!pvpstatus` | All players | Check your current combat timer status |

## How It Works

When player A damages player B, player A is tagged as "in combat" for the configured cooldown duration. While tagged, player A cannot spawn or pick up any entity whose class is on the blocklist. Pickup blocking can be independently toggled. The tag refreshes on each hit, so sustained combat keeps the timer running.

Only the attacker is tagged. The victim is not restricted. In mutual combat (both players shooting), both get tagged because both are attackers.

Damage from vehicles and CPPI-owned entities (props, etc.) is traced back to the owning player. Buildmode players are fully exempt from combat tagging.

## File Structure

```
pvp_combat_timer/
  addon.json
  README.md
  lua/
    autorun/
      sh_pvp_combat_config.lua      -- Shared ConVars, config sync, utility functions
      client/
        cl_pvp_combat_hud.lua       -- HUD countdown and deny notifications
      server/
        sv_pvp_combat.lua           -- Combat detection, spawn/pickup blocking, admin config
    ulx/
      modules/sh/
        sh_pvp_combat_ulx.lua       -- ULX admin commands
      xgui/settings/
        pvp_combat_timer.lua        -- XGUI settings panel
```

## Notes

- The blocklist is capped at 50 entries and 1024 characters for safety.
- Deny notifications to players are rate-limited (3 seconds) to prevent chat flood.
- TagAttacker deduplicates rapid NWFloat writes under multi-hit weapons (shotguns, explosions).
- ACF 2 may route some damage through its own internal functions rather than EntityTakeDamage. If you find certain ACF weapons don't trigger combat tags, you may need a supplementary hook into ACF's damage pipeline.

## Version History

- **2.1.0** - Added PlayerUse hook to block E-key interaction with blocklisted entities (e.g. sent_ball). Pickup toggle controls both walk-over and E-use blocking.
- **2.0.0** - Merged spawn and pickup blocklists into a single shared list. Moved all config management to XGUI, stripped redundant ULX config commands. Added `!pvpcombattest` command for self-tagging during testing.
- **1.1.0** - Added pickup blocking with independent toggle. Security and performance audit: deny notification rate limiting, blocklist size validation, TagAttacker NWFloat deduplication for rapid-fire weapons.
- **1.0.0** - Initial release.

## Author

Doctor Schnell
