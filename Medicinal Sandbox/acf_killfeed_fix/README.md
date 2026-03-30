# ACF Killfeed Fix v2.0.0 (Deprecated)

> **Deprecated**: This addon was built for [ACF Unofficial (ACF2)](https://steamcommunity.com/sharedfiles/filedetails/?id=1538829125). The server has migrated to [ACF-3](https://steamcommunity.com/sharedfiles/filedetails/?id=3248769787), which does not have the duplicate killfeed issue. This addon is no longer needed and should be removed.

A lightweight server-side fix for Garry's Mod that resolved duplicate killfeed entries caused by ACF2 (Armoured Combat Framework). Removed ACF's custom killfeed hooks after initialization so the base gamemode handled killfeed entries cleanly.

## Features

- **Duplicate Prevention** — Removed ACF's `PlayerDeath` and `OnNPCKilled` hooks that fired alongside the base gamemode's killfeed logic.
- **Automatic** — Hooked into `InitPostEntity` to remove the offending hooks after ACF loaded. No configuration needed.

## Requirements

- [ACF Unofficial (ACF2)](https://steamcommunity.com/sharedfiles/filedetails/?id=1538829125) — **no longer in use**

## Installation

Drop the `acf_killfeed_fix` folder into your server's `garrysmod/addons/` directory.

## Configuration

None. The fix is automatic.

## File Structure

```
garrysmod/addons/acf_killfeed_fix/
├── addon.json
├── README.md
└── lua/
    └── autorun/
        └── server/
            └── _acf_killfeed_fix.lua
```

## Version History

- **2.0.0** — Deprecated. Server migrated from ACF2 to ACF-3, which does not have this issue.
- **1.0.0** — Initial release. Removes ACF's custom killfeed hooks after initialization to prevent duplicate death notices.

## Author

Doctor Schnell & Claude (Anthropic)
