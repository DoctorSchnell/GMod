# Medicinal Sandbox

Custom Garry's Mod server addons by **Doctor Schnell & Claude (Anthropic)**.

A collection of 8 production-ready addons built for a public sandbox server (5-10 players). These fill gaps and resolve conflicts between third-party mods, with a focus on clean architecture, security, and good UX.

## Addons

| Addon | Version | Type | Description |
|-------|---------|------|-------------|
| [ACF Killfeed Fix](Medicinal%20Sandbox/acf_killfeed_fix/) | 3.0.0 | serveronly | Removes duplicate killfeed entries caused by ACF |
| [AFK System](Medicinal%20Sandbox/afk_system/) | 1.0.0 | servercontent | AFK detection with 3D overhead sign, ULX commands, XGUI panel |
| [Buildmode Enhancements](Medicinal%20Sandbox/buildmode-enhancements/) | 1.1.0 | serveronly | Protects buildmode players' props from all damage sources |
| [CW 2.0 Extra Ammo](Medicinal%20Sandbox/cw_extra_ammo/) | 1.0.0 | serveronly | Grants extra reserve ammo on spawn for CW 2.0 and other weapons |
| [Duplicator Limiter](Medicinal%20Sandbox/duplicator_limiter/) | 1.1.1 | serveronly | Rate-limits Duplicator tool by batching entity creation |
| [PVP Combat Timer](Medicinal%20Sandbox/pvp_combat_timer/) | 2.1.0 | servercontent | Restricts entity spawning/pickup during PVP combat cooldown |
| [PVP Leaderboard](Medicinal%20Sandbox/pvp_leaderboard/) | 2.2.2 | servercontent | Persistent PVP stats on a spawnable 3D2D floating sign |
| [Spawn Protection ULX Patch](Medicinal%20Sandbox/spawnprotection_ulx/) | 2.0.2 | serveronly | XGUI settings panel for Workshop Spawn Protection addon |

### ACF Killfeed Fix

Removes ACF's custom killfeed hooks after initialization to prevent duplicate death notices. Fully automatic — no configuration needed.

### AFK System

Full-featured AFK system with a 3D spinning metal-framed overhead sign, Sui Scoreboard integration (row dimming), auto-AFK timeout with activity monitoring, and ULX commands (`!afk`, `!forceafk`, `!unafk`, `!afktime`). Configurable via XGUI settings panel.

### Buildmode Enhancements

Protects buildmode players' props and entities from all damage sources — ACF, HL2 weapons, physics, and more. Also prevents buildmode players from dealing ACF damage to others. Works automatically alongside Buildmode-ULX.

### CW 2.0 Extra Ammo

Grants players additional reserve ammo on spawn for CW 2.0 and other weapons using standard GMod ammo conventions. Calculates reserve ammo based on magazine capacity with configurable multipliers.

### Duplicator Limiter

Rate-limits the Duplicator tool by batching entity creation across multiple server ticks, preventing crashes from large workshop duplications. Features entity caps, per-player cooldowns, admin bypass, and an XGUI settings panel.

### PVP Combat Timer

Detects PVP combat and restricts spawning/pickup of configurable entities during a cooldown period. Includes a HUD countdown with progress bar, configurable blocklist, buildmode exemption, and XGUI settings. ULX commands for testing and clearing combat state.

### PVP Leaderboard

Persistent PVP leaderboard tracking kills, deaths, K/D ratio, streaks, and headshots. Displays on a spawnable metal-framed floating sign with 3D2D rendering and split-flap animation. Data stored in SQLite. Includes a draggable on-screen panel (`!pvpboard`) and auto-cycling sort modes.

### Spawn Protection ULX Patch

Companion addon for the Workshop Spawn Protection addon (ID: 3401291379). Provides an XGUI settings panel for dedicated server configuration, plus a CW 2.0 flashbang compatibility fix. Does not modify the original Workshop addon.

## Dependencies

These addons are built to work with the following third-party addons:

- **ULX/ULib + XGUI** — admin framework and settings UI
- **Sui Scoreboard** (ZionDevelopers) — custom scoreboard
- **ACF 2** (nrlulz/ACF) — armoured combat framework
- **CW 2.0** — Customizable Weaponry
- **PAC3** — player appearance customizer
- **Buildmode-ULX** (kythre) — build mode system

Not all dependencies are required by every addon — see individual README files for specific requirements.

## Installation

Each addon folder is structured for direct extraction into your server's `garrysmod/addons/` directory:

```
garrysmod/addons/
├── acf_killfeed_fix/
├── afk_system/
├── buildmode-enhancements/
├── cw_extra_ammo/
├── duplicator_limiter/
├── pvp_combat_timer/
├── pvp_leaderboard/
└── spawnprotection_ulx/
```

Copy the desired addon folders from `Medicinal Sandbox/` into your server's `addons/` directory and restart the server.

## License

Public domain — use, modify, and distribute freely. No attribution required.
