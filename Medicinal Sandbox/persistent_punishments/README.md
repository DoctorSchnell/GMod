# Persistent Punishments v1.0.0

A ULX extension that makes punishments (gag, mute, freeze, jail) persist across player disconnects and reconnects. Provides an alternative to banning by allowing admins to apply punishments with reasons and configurable durations that survive sessions.

## Features

- **Persistent Gag, Mute, Freeze, Jail** — Punishments are stored in SQLite and re-applied automatically when the player rejoins. No more evading punishment by reconnecting.
- **Reasons & Durations** — Each punishment includes an admin-provided reason and a duration in minutes (0 = permanent until manually removed).
- **SteamID Commands** — Punish or unpunish players by SteamID, even when they're offline. Punishments apply on their next join.
- **Player Notifications** — Punished players see a colored chat message on every join showing each active punishment, the reason, and time remaining.
- **Admin Notifications** — The applying admin receives a colored confirmation message. Online admins are alerted when a punished player joins the server.
- **Silent Operation** — Persistent punishment commands do not broadcast ULX echo messages to other players. Only the target and the applying admin see notifications.
- **Auto-Expiry** — Timed punishments expire automatically, even mid-session. The player is notified when a punishment expires.
- **XGUI Punishments Tab** — Top-level XGUI tab (next to Bans) for applying, viewing, searching, editing, and removing active punishments.
- **XGUI Settings Panel** — ConVar settings under Settings > Persistent Punishments.
- **ULX Integration** — Calls ULX functions at runtime to apply/remove punishments. No ULX code is extracted or reimplemented.

## Requirements

- [ULX](https://github.com/TeamUlysses/ulx) v3
- [ULib](https://github.com/TeamUlysses/ulib)

## Installation

Extract the `persistent_punishments` folder into your server's `garrysmod/addons/` directory.

```
garrysmod/addons/persistent_punishments/
├── addon.json
├── README.md
└── lua/
    ├── autorun/
    │   └── ppunish_init.lua
    ├── persistent_punishments/
    │   ├── sh_config.lua
    │   ├── sh_convars.lua
    │   ├── sv_database.lua
    │   └── sv_core.lua
    └── ulx/
        ├── modules/sh/
        │   └── sh_ppunish.lua
        └── xgui/
            ├── ppunish.lua
            └── settings/
                └── cl_ppunish_settings.lua
```

## Configuration

All settings are configurable via the XGUI panel (Settings > Persistent Punishments) or via console ConVars:

| ConVar | Default | Description |
|--------|---------|-------------|
| `ppunish_enabled` | 1 | Enable/disable the persistent punishment system |
| `ppunish_notify_admins` | 1 | Notify online admins when a punished player joins |
| `ppunish_check_interval` | 30 | Seconds between punishment expiry checks (5-120) |

## Commands

### Player Commands

| Command | Access | Description |
|---------|--------|-------------|
| `!pgag <player> [minutes] <reason>` | Admin | Persistently gag a player (blocks voice) |
| `!pmute <player> [minutes] <reason>` | Admin | Persistently mute a player (blocks chat) |
| `!pfreeze <player> [minutes] <reason>` | Admin | Persistently freeze a player |
| `!pjail <player> [minutes] <reason>` | Admin | Persistently jail a player |
| `!unpgag <player>` | Admin | Remove a persistent gag |
| `!unpmute <player>` | Admin | Remove a persistent mute |
| `!unpfreeze <player>` | Admin | Remove a persistent freeze |
| `!unpjail <player>` | Admin | Remove a persistent jail |
| `!ppunishments <player>` | Admin | View active persistent punishments on a player |

### SteamID Commands

| Command | Access | Description |
|---------|--------|-------------|
| `!pgagid <steamid> [minutes] <reason>` | Admin | Persistently gag by SteamID (works offline) |
| `!pmuteid <steamid> [minutes] <reason>` | Admin | Persistently mute by SteamID (works offline) |
| `!pfreezeid <steamid> [minutes] <reason>` | Admin | Persistently freeze by SteamID (works offline) |
| `!pjailid <steamid> [minutes] <reason>` | Admin | Persistently jail by SteamID (works offline) |
| `!unpgagid <steamid>` | Admin | Remove a persistent gag by SteamID |
| `!unpmuteid <steamid>` | Admin | Remove a persistent mute by SteamID |
| `!unpfreezeid <steamid>` | Admin | Remove a persistent freeze by SteamID |
| `!unpjailid <steamid>` | Admin | Remove a persistent jail by SteamID |

**Duration**: `0` = permanent (default), any positive number = minutes until auto-expiry.

**SteamID format**: `STEAM_X:X:XXXXXXXX` (e.g., `STEAM_0:1:12345678`).

## XGUI Punishments Tab

The top-level **Punishments** tab (next to Bans) provides:

- **Apply Punishment** — Select an online player from the list, choose type/duration/reason, and apply directly from the panel
- **Apply by SteamID** — Enter a SteamID to punish offline players from the panel
- **Active Punishments list** with Player, Type, Reason, Admin, and Expires columns
- **Search** across all fields (player name, SteamID, type, reason, admin)
- **Type filter** dropdown (All / Gag / Mute / Freeze / Jail)
- **Right-click context menu** to edit or remove punishments
- **Double-click** to edit a punishment's reason and duration
- **Auto-refresh** when the XGUI window is opened

The Punishments tab requires the `xgui_manageppunish` access string (defaults to superadmin, configurable via the XGUI Groups tab).

## How It Works

1. Admin runs `!pgag player 60 spamming voice chat`
2. The addon stores the punishment in SQLite with player ID, type, reason, admin, and expiry time
3. ULX's built-in `gag` function is called to apply the punishment immediately
4. Player sees: `[Persistent Punishment] Gag — Reason: "spamming voice chat" — Expires: 1 hour`
5. Admin sees a matching confirmation message (no broadcast to other players)
6. If the player disconnects and rejoins, the addon detects the active record and re-applies via ULX
7. When the duration expires (or an admin runs `!unpgag`), the punishment is lifted and the player is notified

## Notes

- Using vanilla `!ungag` on a persistently gagged player clears the live state but **not** the database record. The punishment will re-apply on next join. Use `!unpgag` to permanently remove.
- A player cannot have duplicate punishments of the same type. Use the corresponding `!unp*` command first, then re-apply with new reason/duration.
- Jail positions are stored per-punishment. If the map changes and the stored position is invalid, the player is jailed at a spawn point instead.
- Freeze and jail are exclusive states in ULX. If a player has both, only one can be active at a time.
- SteamID commands for jail use the player's current position if online, or a spawn point if offline.
- All persistent punishment actions are logged to the server console via `ServerLog`.

## Version History

- **1.0.0** — Initial release: persistent gag, mute, freeze, jail with SQLite storage, ULX commands, SteamID commands for offline punishment, XGUI Punishments tab with apply/search/filter/edit, XGUI settings panel, auto-expiry, silent notifications, player/admin notifications.
