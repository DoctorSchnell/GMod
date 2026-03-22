# Buildmode Enhancements v1.1.0

A server-side Garry's Mod addon that protects buildmode players' props and entities from all damage sources. Companion addon for [Buildmode-ULX](https://steamcommunity.com/sharedfiles/filedetails/?id=1308900979) by kythre.

## Features

- **Full Damage Protection** — Props and entities owned by buildmode players are immune to all damage: ACF weapons, HL2 weapons (RPG, grenades), physics impacts, and any other Source engine damage.
- **Outgoing ACF Damage Prevention** — Buildmode players cannot deal ACF damage to other players' props.
- **CPPI Ownership Detection** — Uses the Community Property Protection Interface to identify prop owners, with fallback to `buildOwner` if CPPI is unavailable.
- **Attacker Tracing** — Identifies damage sources through direct player attackers, inflictor ownership, and prop-to-owner relationships.

## Requirements

- [Buildmode-ULX](https://steamcommunity.com/sharedfiles/filedetails/?id=1308900979) (by kythre)
- [ACF Unofficial](https://steamcommunity.com/sharedfiles/filedetails/?id=1538829125) (Armoured Combat Framework) — optional, ACF protection is skipped if not present
- CPPI-compatible prop protection addon (optional, has fallback)

## Installation

Drop the `buildmode-enhancements` folder into your server's `garrysmod/addons/` directory.

## Configuration

None. Protection is automatic and always active when the addon is installed.

## File Structure

```
garrysmod/addons/buildmode-enhancements/
├── addon.json
├── README.md
└── lua/
    └── autorun/
        └── server/
            └── sv_buildmode_enhancements.lua
```

## Version History

- **1.1.0** — Added general damage protection via `EntityTakeDamage` hook (covers HL2 weapons, physics, explosions, etc.). Renamed addon from "ACF Buildmode Protection" to "Buildmode Enhancements".
- **1.0.0** — Initial release. ACF-only damage protection.

## Author

Doctor Schnell & Claude (Anthropic)
