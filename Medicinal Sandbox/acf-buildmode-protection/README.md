# ACF Buildmode Protection

A server-side Garry's Mod addon that protects buildmode players from ACF (Armoured Combat Framework) damage. Prevents ACF weapons from damaging props owned by buildmode players, and prevents buildmode players from dealing ACF damage to other players' props.

## Features

- **Incoming Damage Protection** — Props owned by buildmode players are immune to ACF damage.
- **Outgoing Damage Prevention** — Buildmode players cannot deal ACF damage to other players' props.
- **CPPI Ownership Detection** — Uses the Community Property Protection Interface to identify prop owners, with fallback to `buildOwner` if CPPI is unavailable.
- **Attacker Tracing** — Identifies damage sources through direct player attackers, inflictor ownership, and prop-to-owner relationships.

## Requirements

- [ACF 2](https://github.com/Storont/ACF-3) (Armoured Combat Framework)
- Buildmode-ULX (by kythre)
- CPPI-compatible prop protection addon (optional, has fallback)

## Installation

Drop the `acf-buildmode-protection` folder into your server's `garrysmod/addons/` directory:

```
garrysmod/addons/acf-buildmode-protection/
├── addon.json
└── lua/
    └── autorun/
        └── server/
            └── sv_acf_buildmode_protect.lua
```

## Configuration

None. Protection is automatic and always active when the addon is installed. If ACF is not present, the addon silently does nothing.

## Author

Doctor Schnell
