# Spawn Protection ULX Patch v2.0.2

Companion addon for the [Spawn Protection](https://steamcommunity.com/sharedfiles/filedetails/?id=3401291379) Workshop addon. Adds an XGUI settings panel for server configuration on dedicated servers.

## Features

- **XGUI Settings Panel** — Full configuration through XGUI with tiered permissions (SuperAdmin for core settings, Admin for visuals).
- **Net-Based ConVar Sync** — Bridges the gap between the original addon's server-only ConVars and the client UI. Compact 11-bit binary format.
- **CW 2.0 Compatibility Fix** — Prevents flashbang property nil comparison errors caused by a load-timing race condition.
- **No File Modifications** — Does not modify any files in the original Workshop addon.

## Requirements

- [ULX/ULib](https://github.com/TeamUlysses/ulx) + XGUI
- [Spawn Protection](https://steamcommunity.com/sharedfiles/filedetails/?id=3401291379) Workshop addon

## Installation

Extract the `spawnprotection_ulx` folder into your server's `garrysmod/addons/` directory.

## Configuration

Open XGUI (default: `!xgui` or the ULX menu) and navigate to **Settings > Spawn Protection**. The panel is divided into two sections with tiered permissions:

**Core Settings (SuperAdmin):** Enable/disable spawn protection, protection duration, damage prevention for protected players, NPC no-target toggle.

**Visual / Notification (Admin):** Chat notifications, protection bubble effect.

Changes are staged and applied with the **Apply** button. The **Reset** button reverts to the current server values. The panel auto-refreshes when the server pushes updated values, as long as there are no unsaved local changes.

## File Structure

```
garrysmod/addons/spawnprotection_ulx/
├── addon.json
├── README.md
└── lua/
    ├── autorun/
    │   └── sh_spawnprotection_ulx.lua    -- Shared sync logic and net handling
    └── ulx/
        └── xgui/settings/
            └── spawnprotection.lua       -- XGUI settings panel
```

## Version History

- **2.0.2** — XGUI panel now requests a fresh config sync from the server each time the tab is opened.
- **2.0.1** — Fixed XGUI settings not applying. Batched all changes into a single net message. Added callback suppression during init/reset/refresh.
- **2.0.0** — Removed ULX chat/console commands (XGUI panel is the sole interface).
- **1.0.1** — Fixed XGUI panel crash. Fixed startup errors from ConVar callbacks. Added CW 2.0 compatibility fix.
- **1.0.0** — Initial release.

## Author

Doctor Schnell & Claude (Anthropic)
