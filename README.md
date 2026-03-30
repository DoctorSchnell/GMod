# Medicinal Sandbox

Custom Garry's Mod server addons by **Doctor Schnell & Claude (Anthropic)**.

9 addons for a public sandbox server (5-10 players). These fill gaps and resolve conflicts between third-party mods.

## Addons

| Addon | Version | Type | Description |
|-------|---------|------|-------------|
| [ACF Killfeed Fix](Medicinal%20Sandbox/acf_killfeed_fix/) | 2.0.0 | serveronly | ~~Removes duplicate killfeed entries caused by ACF~~ **(Deprecated — ACF2 replaced by ACF-3)** |
| [AFK System](Medicinal%20Sandbox/afk_system/) | 1.0.0 | servercontent | AFK detection with 3D overhead sign, ULX commands, XGUI panel |
| [Buildmode Enhancements](Medicinal%20Sandbox/buildmode-enhancements/) | 1.1.0 | serveronly | Protects buildmode players' props from all damage sources |
| [CW 2.0 Extra Ammo](Medicinal%20Sandbox/cw_extra_ammo/) | 1.0.0 | serveronly | Grants extra reserve ammo on spawn for CW 2.0 and other weapons |
| [Duplicator Limiter](Medicinal%20Sandbox/duplicator_limiter/) | 1.1.1 | serveronly | Rate-limits Duplicator tool by batching entity creation |
| [PVP Combat Timer](Medicinal%20Sandbox/pvp_combat_timer/) | 2.1.0 | servercontent | Restricts entity spawning/pickup during PVP combat cooldown |
| [Persistent Punishments](Medicinal%20Sandbox/persistent_punishments/) | 1.0.0 | serveronly | Persistent gag, mute, freeze, jail via ULX with XGUI management tab |
| [PVP Leaderboard](Medicinal%20Sandbox/pvp_leaderboard/) | 2.2.2 | servercontent | Persistent PVP stats on a spawnable 3D2D floating sign |
| [Spawn Protection ULX Patch](Medicinal%20Sandbox/spawnprotection_ulx/) | 2.0.2 | serveronly | XGUI settings panel for Workshop Spawn Protection addon |

### ACF Killfeed Fix (Deprecated)

~~Removes ACF's custom killfeed hooks after initialization to prevent duplicate death notices.~~ No longer needed after migrating from ACF2 to ACF-3.

### AFK System

3D spinning overhead sign, Sui Scoreboard integration (row dimming), auto-AFK timeout, and ULX commands (`!afk`, `!forceafk`, `!unafk`, `!afktime`). Configurable via XGUI.

### Buildmode Enhancements

Protects buildmode players' props and entities from all damage sources (ACF, HL2 weapons, physics). Also prevents buildmode players from dealing ACF damage. Works automatically alongside Buildmode-ULX.

### CW 2.0 Extra Ammo

Grants extra reserve ammo on spawn for CW 2.0 and other weapons. Calculates reserve ammo from magazine capacity with configurable multipliers.

### Duplicator Limiter

Batches Duplicator entity creation across multiple server ticks to prevent crashes from large workshop duplications. Entity caps, per-player cooldowns, admin bypass. XGUI settings panel.

### Persistent Punishments

ULX extension that makes punishments (gag, mute, freeze, jail) persist across disconnects via SQLite. Includes durations, reasons, SteamID commands for offline players, auto-expiry, and an XGUI Punishments tab for applying/managing punishments.

### PVP Combat Timer

Tags players in PVP combat and restricts entity spawning/pickup during a cooldown. HUD countdown, configurable blocklist, buildmode exemption. XGUI settings and ULX commands for testing/clearing state.

### PVP Leaderboard

Tracks kills, deaths, K/D, streaks, and headshots in SQLite. Displays on a spawnable 3D2D floating sign with split-flap animation. Also has a draggable on-screen panel (`!pvpboard`) with auto-cycling sort.

### Spawn Protection ULX Patch

XGUI settings panel for the Workshop Spawn Protection addon (ID: 3401291379). Includes a CW 2.0 flashbang compatibility fix. Does not modify the original Workshop addon.

## Dependencies

Not all dependencies are required by every addon. See individual READMEs for specific requirements.

- **ULX/ULib + XGUI** - admin framework and settings UI
- **Sui Scoreboard** (ZionDevelopers) - custom scoreboard
- **ACF-3** - armoured combat framework (migrated from ACF2)
- **CW 2.0** - Customizable Weaponry
- **PAC3** - player appearance customizer
- **Buildmode-ULX** (kythre) - build mode system

## Installation

Each addon folder is structured for direct extraction into your server's `garrysmod/addons/` directory:

```
garrysmod/addons/
├── acf_killfeed_fix/
├── afk_system/
├── buildmode-enhancements/
├── cw_extra_ammo/
├── duplicator_limiter/
├── persistent_punishments/
├── pvp_combat_timer/
├── pvp_leaderboard/
└── spawnprotection_ulx/
```

Copy the desired addon folders from `Medicinal Sandbox/` into your server's `addons/` directory and restart the server.

## License

Public domain - use, modify, and distribute freely. No attribution required.
