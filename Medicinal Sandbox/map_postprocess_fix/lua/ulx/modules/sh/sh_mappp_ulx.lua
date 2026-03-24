-- Map Post-Process Fix - ULX Commands
-- Addon by Doctor Schnell
--
-- Provides chat/console commands for managing per-map configs without
-- needing to open the XGUI panel. Useful for quick in-game testing.
--
-- Commands:
--   !mappp_set <map> <tonemap> <bloom> <specular>
--       Sets all three override values for a map. Use -1 for any
--       setting you don't want to override.
--
--   !mappp_remove <map>
--       Deletes a map's config entry entirely.
--
--   !mappp_list
--       Prints all configured maps and their settings.
--
--   !mappp_reload
--       Reloads the config file from disk. Handy if someone edited
--       the JSON by hand.

-- ============================================================
-- mappp_set
-- ============================================================

function ulx.mappp_set(calling_ply, mapName, tonemapScale, bloomScale, matSpecular)
    mapName = string.lower(mapName)

    -- Basic format check. Map names are alphanumeric with underscores/hyphens.
    if not string.match(mapName, "^[%w_%-]+$") then
        ULib.tsayError(calling_ply, "Invalid map name. Use only letters, numbers, underscores, and hyphens.")
        return
    end

    local config = {
        tonemap_scale = math.Clamp(tonemapScale, -1, 5),
        bloom_scale   = math.Clamp(bloomScale, -1, 5),
        mat_specular  = math.Clamp(matSpecular, -1, 1)
    }

    MapPP.SetMapConfig(mapName, config)

    ulx.fancyLogAdmin(calling_ply, "#A set MapPP config for #s", mapName)

    -- Push changes now if we're currently on this map.
    if string.lower(game.GetMap()) == mapName then
        MapPP.SyncConfigToAll()
    end
end

local mappp_set = ulx.command("Map Post-Process", "ulx mappp_set", ulx.mappp_set, "!mappp_set")
mappp_set:addParam{type = ULib.cmds.StringArg, hint = "map name"}
mappp_set:addParam{type = ULib.cmds.NumArg, hint = "tonemap (0=auto, -1=skip)", ULib.cmds.allowTimeString}
mappp_set:addParam{type = ULib.cmds.NumArg, hint = "bloom (0=off, 1=normal, -1=skip)", ULib.cmds.allowTimeString}
mappp_set:addParam{type = ULib.cmds.NumArg, hint = "specular (0=off, 1=on, -1=skip)", ULib.cmds.allowTimeString}
mappp_set:defaultAccess(ULib.ACCESS_SUPERADMIN)
mappp_set:help("Set post-processing overrides for a map.")

-- ============================================================
-- mappp_remove
-- ============================================================

function ulx.mappp_remove(calling_ply, mapName)
    mapName = string.lower(mapName)

    if not MapPP.GetMapConfig(mapName) then
        ULib.tsayError(calling_ply, "No config found for " .. mapName)
        return
    end

    MapPP.RemoveMapConfig(mapName)

    ulx.fancyLogAdmin(calling_ply, "#A removed MapPP config for #s", mapName)

    -- If we just removed the current map's config, tell clients to reset.
    if string.lower(game.GetMap()) == mapName then
        MapPP.SyncConfigToAll()
    end
end

local mappp_remove = ulx.command("Map Post-Process", "ulx mappp_remove", ulx.mappp_remove, "!mappp_remove")
mappp_remove:addParam{type = ULib.cmds.StringArg, hint = "map name"}
mappp_remove:defaultAccess(ULib.ACCESS_SUPERADMIN)
mappp_remove:help("Remove post-processing overrides for a map.")

-- ============================================================
-- mappp_list
-- ============================================================

function ulx.mappp_list(calling_ply)
    local configs = MapPP.GetAllConfigs()
    local count = table.Count(configs)

    if count == 0 then
        ULib.tsayColor(calling_ply, false, Color(100, 200, 255), "[MapPP] ", Color(255, 255, 255), "No maps configured.")
        return
    end

    ULib.tsayColor(calling_ply, false, Color(100, 200, 255), "[MapPP] ", Color(255, 255, 255), count .. " map(s) configured:")

    for mapName, config in SortedPairs(configs) do
        local parts = {}

        -- Build a readable summary of each setting, skipping those set to -1.
        if config.tonemap_scale and config.tonemap_scale >= 0 then
            table.insert(parts, "tonemap=" .. config.tonemap_scale)
        end

        if config.bloom_scale and config.bloom_scale >= 0 then
            table.insert(parts, "bloom=" .. config.bloom_scale)
        end

        if config.mat_specular and config.mat_specular >= 0 then
            table.insert(parts, "specular=" .. config.mat_specular)
        end

        local summary = #parts > 0 and table.concat(parts, ", ") or "(all defaults)"

        ULib.tsayColor(calling_ply, false,
            Color(100, 200, 255), "  " .. mapName .. ": ",
            Color(255, 255, 255), summary)
    end
end

local mappp_list = ulx.command("Map Post-Process", "ulx mappp_list", ulx.mappp_list, "!mappp_list")
mappp_list:defaultAccess(ULib.ACCESS_ADMIN)
mappp_list:help("List all maps with post-processing overrides.")

-- ============================================================
-- mappp_reload
-- ============================================================

function ulx.mappp_reload(calling_ply)
    MapPP.LoadConfig()
    ulx.fancyLogAdmin(calling_ply, "#A reloaded the MapPP config from disk")
end

local mappp_reload = ulx.command("Map Post-Process", "ulx mappp_reload", ulx.mappp_reload, "!mappp_reload")
mappp_reload:defaultAccess(ULib.ACCESS_SUPERADMIN)
mappp_reload:help("Reload the post-processing config from disk.")
