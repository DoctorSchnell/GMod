# ACF Killfeed Fix v3.0

A lightweight server-side fix for Garry's Mod that resolves duplicate killfeed entries caused by ACF (Armoured Combat Framework). Removes ACF's custom killfeed hooks after initialization so the base gamemode handles killfeed entries cleanly.

## Problem

ACF registers its own `PlayerDeath` and `OnNPCKilled` hooks to write custom killfeed entries. These fire alongside the base gamemode's killfeed logic, resulting in duplicate death notifications appearing in the top-right corner.

## Solution

This addon hooks into `InitPostEntity` and removes the two offending ACF hooks (`ACF_PlayerDeath` and `ACF_OnNPCKilled`), letting the base gamemode handle all killfeed entries without duplication.

## Requirements

- [ACF 2](https://github.com/Storont/ACF-3) (Armoured Combat Framework)

## Installation

Drop the `acf_killfeed_fix` folder into your server's `garrysmod/addons/` directory:

```
garrysmod/addons/acf_killfeed_fix/
├── addon.json
└── lua/
    └── autorun/
        └── server/
            └── _acf_killfeed_fix.lua
```

## Configuration

None. The fix is automatic.

## Author

Doctor Schnell
