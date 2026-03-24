# Map Post-Process Fix

Server-enforced per-map post-processing overrides for Garry's Mod. Fixes overbright HDR, excessive bloom, and harsh specular reflections on older or poorly-tuned maps without requiring any action from players.

**Author:** Doctor Schnell  
**Version:** 1.2.0  
**Requires:** ULX, ULib, XGUI

## The Problem

Some maps (particularly older ones compiled with aggressive HDR settings) look blown out in modern GMod. Everything is too bright, contrast is extreme, and detail gets lost. The standard fix is for each player to manually adjust post-processing settings every time they join, which is not realistic on a public server.

## How It Works

The addon maintains a JSON config file (`garrysmod/data/mappp_config.json`) mapping map names to override values for three engine settings:

| Setting | Mechanism | Effect |
|---------|-----------|--------|
| Tonemap Scale | `render.SetToneMappingScaleLinear()` | Controls HDR brightness. Applied per-frame via a render hook, bypassing the cheat-protected ConVar. Values around 0.5 to 1.0 tame extreme brightness. |
| Bloom Scale | `mat_bloomscale` | Controls engine bloom glow. 0 = disabled, 1.0 = normal. |
| Specular | `mat_specular` | Controls shiny reflections on world surfaces. 0 = off, 1 = on. |

When a player joins or the map changes, the server pushes the appropriate overrides to every client automatically. Players see a corrected image without touching a single setting.

Tonemap is enforced every frame by the render hook, so the map's `env_tonemap_controller` entity can never reassert its own values. Bloom and specular are checked every 2 seconds via a lightweight timer that detects and corrects drift from other addons (like FPS Booster).

A value of **-1** in any field means "don't override this setting." Only the settings you explicitly configure will be changed.

## Installation

1. Extract the `map_postprocess_fix` folder into your server's `garrysmod/addons/` directory.
2. Restart the server (or change map).
3. The addon ships with a default config entry for `gm_blackmesa_sigma`. Edit or remove it as needed.

## Configuration

### XGUI Panel

Open the XGUI settings menu and find the **Map Post-Process** tab. From there you can:

- Toggle the master enable/disable switch
- View all configured maps in the list
- Select a map to see and edit its settings
- Add new map entries by typing a map name and clicking Save
- Remove entries with the Remove button

Changes take effect immediately if the configured map is the one currently running.

### Chat Commands

All commands are also available through the console by prefixing with `ulx` (e.g., `ulx mappp_set`).

| Command | Access | Description |
|---------|--------|-------------|
| `!mappp_set <map> <tonemap> <bloom> <specular>` | SuperAdmin | Set overrides for a map. Use -1 for any value you want to leave alone. |
| `!mappp_remove <map>` | SuperAdmin | Delete a map's config entry. |
| `!mappp_list` | Admin | Print all configured maps and their settings to chat. |
| `!mappp_reload` | SuperAdmin | Reload the config file from disk (useful after manual JSON edits). |

### Examples

Fix an overbright map with toned-down HDR and no bloom:
```
!mappp_set gm_blackmesa_sigma 0.7 0 -1
```

Disable specular reflections on a map but leave HDR and bloom alone:
```
!mappp_set gm_somemap -1 -1 0
```

Remove a map's overrides entirely:
```
!mappp_remove gm_blackmesa_sigma
```

### Editing the JSON Directly

The config file lives at `garrysmod/data/mappp_config.json`. You can edit it by hand while the server is running, then use `!mappp_reload` to pick up the changes. The format:

```json
{
    "gm_blackmesa_sigma": {
        "tonemap_scale": 0.7,
        "bloom_scale": 0.0,
        "mat_specular": -1
    }
}
```

## Tuning Tips

There is no universal "right" set of values. Every map is different. Here is a rough starting point for maps that look too bright:

- **Tonemap 0.5 to 0.8** brings down extreme HDR without making things too dark.
- **Bloom 0.0 to 0.3** kills or reduces the glow halo around bright areas.
- **Specular 0** helps on maps where every surface looks wet or glaring.

The fastest way to dial things in is to be on the map and use `!mappp_set` with different values. Changes push to all players in real time, so you can iterate quickly.

## File Structure

```
map_postprocess_fix/
  addon.json
  lua/
    autorun/
      sh_mappp_config.lua           -- Shared ConVars and net string registration
    autorun/server/
      sv_mappp_core.lua             -- Config storage, sync, net handlers, public API
    autorun/client/
      cl_mappp_core.lua             -- Receives config, applies overrides via render hook and ConVars
    ulx/modules/sh/
      sh_mappp_ulx.lua              -- ULX chat/console commands
    ulx/xgui/settings/
      mappp_xgui.lua                -- XGUI admin panel
```

## Notes

- Tonemap scale is applied via `render.SetToneMappingScaleLinear()` in a per-frame render hook. This bypasses `mat_force_tonemap_scale` (which is cheat-protected in multiplayer) and also prevents the map's `env_tonemap_controller` entity from fighting back.
- Bloom and specular are applied via `mat_bloomscale` and `mat_specular` ConVars, which are not cheat-protected. A timer checks every 2 seconds for drift from other addons (e.g. FPS Booster) and re-applies if needed.
- When the addon is disabled or a map has no config entry, bloom and specular are restored to engine defaults. Tonemap returns to auto-exposure automatically when the render hook stops overriding.
- Config changes for the currently running map take effect immediately for all connected players. Changes for other maps take effect the next time that map is loaded.
- The master toggle (`mappp_enabled`) is a replicated ConVar. Toggling it off restores defaults for everyone without removing any saved configs.
