# CW 2.0 Extra Ammo

A server-side Garry's Mod addon that grants players additional reserve ammunition on weapon pickup. Designed for CW 2.0 (Customizable Weaponry 2.0) but works with any weapon that follows standard GMod ammo conventions (HL2 weapons, other SWEPs, etc.).

## Features

- **Magazine-Based Ammo** — Primary and clipped secondary ammo is calculated from the weapon's max clip size multiplied by a configurable magazine count.
- **Clipless Secondary Support** — Weapons with non-clipped secondary ammo (SMG1 grenades, AR2 orbs, etc.) receive a flat bonus amount.
- **Dual Ammo Types** — Handles both primary and secondary ammo slots independently.
- **Deferred Processing** — Uses a one-frame defer to ensure weapons are fully initialized before reading ammo properties.

## Installation

Drop the `cw_extra_ammo` folder into your server's `garrysmod/addons/` directory:

```
garrysmod/addons/cw_extra_ammo/
├── addon.json
└── lua/
    └── autorun/
        └── server/
            └── sv_cw_extra_ammo.lua
```

## Configuration

Edit the constants at the top of `sv_cw_extra_ammo.lua`:

| Constant | Default | Description |
|---|---|---|
| `EXTRA_MAGAZINES` | 20 | Number of extra magazines for primary and clipped secondary ammo (rounds = clip size x this value) |
| `EXTRA_SECONDARY` | 25 | Flat amount of clipless secondary ammo (grenades, orbs, etc.) |

## Author

Doctor Schnell
