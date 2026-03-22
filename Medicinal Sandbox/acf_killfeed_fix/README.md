# ACF Killfeed Fix v3.0.0

A lightweight server-side fix for Garry's Mod that resolves duplicate killfeed entries caused by ACF (Armoured Combat Framework). Removes ACF's custom killfeed hooks after initialization so the base gamemode handles killfeed entries cleanly.

## Features

- **Duplicate Prevention** — Removes ACF's `PlayerDeath` and `OnNPCKilled` hooks that fire alongside the base gamemode's killfeed logic.
- **Automatic** — Hooks into `InitPostEntity` to remove the offending hooks after ACF loads. No configuration needed.

## Requirements

- [ACF Unofficial](https://steamcommunity.com/sharedfiles/filedetails/?id=1538829125) (Armoured Combat Framework)

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

- **3.0.0** — Simplified to pure hook removal (previous versions used different approaches).
- **1.0.0** — Initial release.

## Author

Doctor Schnell & Claude (Anthropic)
