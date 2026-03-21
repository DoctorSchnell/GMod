# Spawn Protection ULX Patch

Companion addon for the [Spawn Protection](https://steamcommunity.com/sharedfiles/filedetails/?id=3401291379) Workshop addon. Adds an XGUI settings panel for server configuration on dedicated servers.

## Problem

The original addon creates all of its ConVars server-side only and provides a spawnmenu panel that tries to set them from the client console. This does not work on dedicated servers. The client gets "Unknown command" errors for every ConVar except `sv_spawnprotection_bubble`, which instead fails with a "Can't change replicated ConVar from console of client" error.

## Solution

This patch addon syncs ConVar values to connected clients via lightweight net messages (11 bits per sync) and provides an XGUI settings panel that sends changes back to the server through a validated, rate-limited net channel.

No files in the original addon are modified.

Also includes a client-side compatibility fix for a CW 2.0 race condition that the spawn protection addon's load timing can expose (flashbang property nil comparison in `cl_hooks.lua`).

## Requirements

- [ULX/ULib](https://github.com/TeamUlysses/ulx)
- XGUI (included with ULX)
- [Spawn Protection](https://steamcommunity.com/sharedfiles/filedetails/?id=3401291379) Workshop addon

## Installation

Extract the `spawnprotection_ulx` folder into your server's `garrysmod/addons/` directory.

```
garrysmod/addons/spawnprotection_ulx/
    addon.json
    lua/
        autorun/
            sh_spawnprotection_ulx.lua
        ulx/
            xgui/settings/
                spawnprotection.lua
```

## XGUI Panel

Open XGUI (default: `!xgui` or the ULX menu) and navigate to **Settings > Spawn Protection**. The panel is divided into two sections with tiered permissions:

**Core Settings (SuperAdmin):** Enable/disable spawn protection, protection duration, damage prevention for protected players, NPC no-target toggle.

**Visual / Notification (Admin):** Chat notifications, protection bubble effect.

Changes are staged and applied with the **Apply** button. The **Reset** button reverts to the current server values. The panel auto-refreshes when the server pushes updated values, as long as there are no unsaved local changes.

## Version History

- **2.0.2** - XGUI panel now requests a fresh config sync from the server each time the tab is opened, instead of relying on the initial push arriving before panel construction.
- **2.0.1** - Fixed XGUI settings not applying. Batched all changes into a single net message (rate limiter was dropping messages in the per-change loop). Added callback suppression so SetValue during init/reset/refresh does not pollute the staged changes table.
- **2.0.0** - Removed ULX chat/console commands (XGUI settings panel is the sole interface). Updated documentation.
- **1.0.1** - Fixed XGUI panel crash (was passing a builder function to addSettingModule instead of a panel object, which broke all XGUI settings tabs). Fixed startup errors from ConVar change callbacks firing during original addon initialization. Added CW 2.0 compatibility fix for flashbang property race condition.
- **1.0.0** - Initial release
