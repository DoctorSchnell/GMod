# AFK System v1.0.0

A full-featured AFK system for Garry's Mod servers with ULX/XGUI integration.

## Features

- **3D Overhead Sign** — Metal-framed spinning sign above AFK players' heads with elapsed time. True 3D mesh geometry visible from all angles. Synced rotation across all clients. Shows on ragdolls when dead, and optionally on yourself.
- **Sui Scoreboard Integration** — AFK badge next to player name with elapsed time. Row dimming for AFK players. Non-invasive, doesn't modify Sui Scoreboard files.
- **Auto-AFK Timeout** — Configurable idle timer. Monitors WASD, mouse movement, attack buttons, menus, and chat.
- **ULX Commands** — `!afk` (self-toggle), `!forceafk` (admin), `!unafk` (admin), `!afktime` (superadmin).
- **XGUI Settings Panel** — Full settings panel under the Settings tab. All changes persist across map changes and server restarts via archived ConVars. Apply/Reset workflow to avoid console spam.
- **Chat Notifications** — Configurable broadcast messages when players go AFK or return.

## Requirements

- [ULX](https://github.com/TeamUlysses/ulx) v3
- [ULib](https://github.com/TeamUlysses/ulib)
- [Sui Scoreboard](https://github.com/ZionDevelopers/sui-scoreboard) (optional, for scoreboard integration)

## Installation

Extract the `afk_system` folder into your server's `garrysmod/addons/` directory:

```
garrysmod/addons/afk_system/
├── addon.json
└── lua/
    ├── autorun/
    │   └── afk_system_init.lua
    ├── afk_system/
    │   ├── sh_config.lua
    │   ├── sh_convars.lua
    │   ├── sv_core.lua
    │   ├── cl_input.lua
    │   ├── cl_overhead.lua
    │   └── cl_scoreboard.lua
    └── ulx/
        ├── modules/sh/
        │   └── sh_afk.lua
        └── xgui/settings/
            └── cl_afk_settings.lua
```

## Configuration

All settings are configurable via the XGUI panel (Settings > AFK System) or via console ConVars:

| ConVar | Default | Description |
|--------|---------|-------------|
| `afk_auto_timeout` | 300 | Seconds idle before auto-AFK (0 = disable) |
| `afk_broadcast` | 1 | Broadcast chat messages on AFK changes |
| `afk_overhead_enabled` | 1 | Show 3D sign above AFK players |
| `afk_overhead_self` | 1 | Show sign above yourself |
| `afk_overhead_spin` | 30 | Sign spin speed (degrees/sec) |
| `afk_overhead_scale` | 0.08 | Sign size |
| `afk_scoreboard_dim` | 120 | Scoreboard row dim intensity |

Additional ConVars available for sign colors (`afk_sign_bg_r/g/b/a`, `afk_sign_text_r/g/b`), render distance, height offset, check intervals, and more.

## ULX Commands

| Command | Access | Description |
|---------|--------|-------------|
| `!afk` | All players | Toggle your own AFK status |
| `!forceafk <player>` | Admin | Force a player into AFK mode |
| `!unafk <player>` | Admin | Remove a player from AFK mode |
| `!afktime <seconds>` | Superadmin | Set auto-AFK timeout (persists) |

## License

Free to use and modify for your server.
