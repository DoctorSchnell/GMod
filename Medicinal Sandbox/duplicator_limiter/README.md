# Duplicator Limiter v1.0.0

Rate-limits the built-in Duplicator tool by batching entity creation across multiple server ticks. Prevents server crashes from large workshop duplications that would otherwise spawn hundreds of entities in a single frame.

## Features

- **Batched Pasting** — Large duplications are split into configurable batches with a delay between each, spreading the load across multiple server ticks instead of a single frame spike.
- **Entity Cap** — Configurable maximum entity count per paste. Dupes exceeding the limit are denied outright with a chat notification.
- **Per-Player Cooldown** — Enforces a minimum delay between paste operations per player.
- **Admin Bypass** — Optional toggle to let admins paste without limits.
- **Small Paste Passthrough** — Pastes with fewer entities than the batch size go through the original `duplicator.Paste` unmodified for full compatibility.
- **Constraint & Undo Support** — Constraints and `PostEntityPaste` hooks are applied after all batches complete. A single undo entry covers the entire paste.
- **XGUI Settings Panel** — All settings configurable live under Settings > Duplicator Limiter. Changes require SuperAdmin.
- **Chat Feedback** — Players see status messages for throttled, denied, and completed pastes.

## Requirements

- [ULX](https://github.com/TeamUlysses/ulx) v3
- [ULib](https://github.com/TeamUlysses/ulib)

## Installation

Extract the `duplicator_limiter` folder into your server's `garrysmod/addons/` directory.

## Configuration

All settings are configurable via the XGUI panel (Settings > Duplicator Limiter) or via console ConVars:

| ConVar | Default | Description |
|--------|---------|-------------|
| `duplimiter_enabled` | 1 | Enable/disable the limiter |
| `duplimiter_batch_size` | 10 | Entities spawned per batch |
| `duplimiter_delay` | 0.1 | Seconds between batches |
| `duplimiter_max_entities` | 150 | Max entities per paste (0 = no limit) |
| `duplimiter_cooldown` | 2 | Seconds between pastes per player |
| `duplimiter_admin_bypass` | 0 | Admins bypass all limits |

### Tuning Guide

With the defaults (batch size 10, delay 0.1s), a 100-entity dupe takes ~1 second to fully paste. Adjust to taste:

- **Laggy server?** Lower `duplimiter_batch_size` or increase `duplimiter_delay`.
- **Players complaining about slow pastes?** Raise `duplimiter_batch_size`.
- **Want a hard cap?** Set `duplimiter_max_entities` to your desired limit.
- **Admins need full speed?** Set `duplimiter_admin_bypass` to 1.

## How It Works

The addon wraps `duplicator.Paste` at the Lua level:

1. If the entity count is within the batch size, the original function runs unmodified.
2. For larger pastes, the entity list is split into batches. Batch 1 spawns immediately; subsequent batches are deferred via `timer.Create` with the configured delay.
3. After all entities are created, `PostEntityPaste` callbacks run, constraints are applied, and a single undo entry is registered.
4. Players who disconnect mid-paste have their pending timers cleaned up automatically.

This only affects the built-in Duplicator tool. Advanced Duplicator 2 uses its own paste implementation and is not affected.

## File Structure

```
garrysmod/addons/duplicator_limiter/
├── addon.json
├── README.md
└── lua/
    ├── autorun/
    │   ├── sh_duplicator_limiter.lua
    │   └── server/
    │       └── sv_duplicator_limiter.lua
    └── ulx/
        └── xgui/settings/
            └── cl_duplicator_limiter.lua
```

## Version History

- **1.0.0** — Initial release.

## Author

Doctor Schnell & Claude (Anthropic)
