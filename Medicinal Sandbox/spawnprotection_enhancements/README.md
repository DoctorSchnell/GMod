# Spawn Protection Enhancements v3.0.0

Companion addon for the [Spawn Protection](https://steamcommunity.com/sharedfiles/filedetails/?id=3401291379) Workshop addon. Adds an XGUI settings panel, cancel-on-fire behavior, and dedicated server fixes.

## Features

- **Cancel-on-Fire** — Automatically cancels spawn protection when a protected player fires a weapon. Detects HL2 weapons, CW 2.0 weapons, and ACF 2 guns (MGs via bullet detection, cannons/shells via damage tracing). Togglable via ConVar.
- **XGUI Settings Panel** — Full configuration through XGUI with tiered permissions (SuperAdmin for core settings, Admin for visuals).
- **Net-Based ConVar Sync** — Bridges the gap between the original addon's server-only ConVars and the client UI. Compact 12-bit binary format.
- **CW 2.0 Compatibility Fix** — Prevents flashbang property nil comparison errors caused by a load-timing race condition.

## Requirements

- [ULX/ULib](https://github.com/TeamUlysses/ulx) + XGUI
- [Spawn Protection](https://steamcommunity.com/sharedfiles/filedetails/?id=3401291379) Workshop addon

## Installation

Extract the `spawnprotection_enhancements` folder into your server's `garrysmod/addons/` directory.

> **Upgrading from v2.x (spawnprotection_ulx):** Remove the old `spawnprotection_ulx` folder before installing. The addon has been renamed.

## Configuration

Open XGUI (default: `!xgui` or the ULX menu) and navigate to **Settings > Spawn Protection**.

### ConVars

| ConVar | Default | Permission | Description |
|--------|---------|------------|-------------|
| `sv_spawnprotection_enable` | `1` | SuperAdmin | Enable/disable spawn protection |
| `sv_spawnprotection_duration` | `5` | SuperAdmin | Protection duration in seconds (1-60) |
| `sv_spawnprotection_no_damage` | `0` | SuperAdmin | Prevent protected players from dealing damage |
| `sv_spawnprotection_no_target` | `0` | SuperAdmin | NPCs ignore protected players |
| `sv_spawnprotection_cancel_on_fire` | `1` | SuperAdmin | Cancel protection when player fires a weapon |
| `sv_spawnprotection_notification` | `1` | Admin | Enable chat notifications |
| `sv_spawnprotection_bubble` | `1` | Admin | Enable protection bubble effect |

### Cancel-on-Fire Detection

The cancel-on-fire feature detects weapon fire through two mechanisms:

- **EntityFireBullets hook** — Catches HL2 weapons, CW 2.0 weapons, and ACF MG-type weapons that fire bullets through the standard bullet system.
- **EntityTakeDamage tracing** — Catches ACF cannon/shell weapons by tracing entity-based damage back to the owning player via `GetOwner()` and CPPI ownership.

When a protected player fires, their protection is immediately cancelled: they become vulnerable to damage, the bubble is removed, and they receive a chat notification.

## File Structure

```
garrysmod/addons/spawnprotection_enhancements/
├── addon.json
├── README.md
└── lua/
    ├── autorun/
    │   └── sh_spawnprotection_enhancements.lua    -- Shared sync, cancel-on-fire, hook patches
    └── ulx/
        └── xgui/settings/
            └── spawnprotection.lua                -- XGUI settings panel
```

## Version History

- **3.0.0** — Renamed from Spawn Protection ULX Patch to Spawn Protection Enhancements. Added cancel-on-fire feature with HL2, CW 2.0, and ACF 2 detection.
- **2.0.2** — XGUI panel now requests a fresh config sync from the server each time the tab is opened.
- **2.0.1** — Fixed XGUI settings not applying. Batched all changes into a single net message. Added callback suppression during init/reset/refresh.
- **2.0.0** — Removed ULX chat/console commands (XGUI panel is the sole interface).
- **1.0.1** — Fixed XGUI panel crash. Fixed startup errors from ConVar callbacks. Added CW 2.0 compatibility fix.
- **1.0.0** — Initial release.

## Author

Doctor Schnell & Claude (Anthropic)
