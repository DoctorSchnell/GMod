-- Map Post-Process Fix - Server Core
-- Addon by Doctor Schnell
--
-- Owns the per-map config table, persists it to disk as JSON, and
-- handles all communication with clients. When the current map has
-- a config entry, the server pushes those values to every player
-- on join and whenever an admin changes the config.
--
-- Config lives at garrysmod/data/mappp_config.json. Each key is a
-- lowercase map name, each value is a table:
--   {
--     tonemap_scale  = <float>  -- mat_force_tonemap_scale (0 = auto, >0 = forced)
--     bloom_scale    = <float>  -- mat_bloomscale (0 = off, 1 = normal, -1 = don't touch)
--     mat_specular   = <float>  -- 0 = off, 1 = on, -1 = don't touch
--   }
--
-- The sentinel value -1 means "don't override this setting."

local TAG = "[MapPP]"

-- ============================================================
-- Config storage
-- ============================================================

local mapConfigs = {}
local CONFIG_PATH = "mappp_config.json"

-- Reads the JSON file from disk into the in-memory table.
-- Falls back to a seeded default if no file exists yet.
local function LoadConfig()
    if file.Exists(CONFIG_PATH, "DATA") then
        local raw = file.Read(CONFIG_PATH, "DATA")
        local decoded = util.JSONToTable(raw)

        if decoded then
            mapConfigs = decoded
            print(TAG .. " Loaded config with " .. table.Count(mapConfigs) .. " map(s)")
        else
            print(TAG .. " WARNING: Could not parse " .. CONFIG_PATH .. ", starting empty")
            mapConfigs = {}
        end
    else
        -- Seed a default entry for a known problem map so the addon
        -- does something useful right out of the box.
        mapConfigs = {
            ["gm_blackmesa_sigma"] = {
                tonemap_scale = 0.7,
                bloom_scale   = 0.0,
                mat_specular  = -1
            }
        }

        print(TAG .. " No config file found, seeded defaults")
    end
end

-- Serializes the in-memory table back to the JSON file.
local function SaveConfig()
    local encoded = util.TableToJSON(mapConfigs, true)
    file.Write(CONFIG_PATH, encoded)
end

-- Run on server start.
LoadConfig()
SaveConfig()  -- Ensure the file exists on disk even if we just seeded.

-- ============================================================
-- Config accessors
-- ============================================================

-- Returns the settings table for a map, or nil if unconfigured.
local function GetMapConfig(mapName)
    return mapConfigs[string.lower(mapName)]
end

-- Stores (or overwrites) settings for a map and writes to disk.
local function SetMapConfig(mapName, config)
    mapConfigs[string.lower(mapName)] = config
    SaveConfig()
end

-- Deletes a map entry and writes to disk.
local function RemoveMapConfig(mapName)
    mapConfigs[string.lower(mapName)] = nil
    SaveConfig()
end

-- Returns the full config table. Used by ULX list command and XGUI panel.
local function GetAllConfigs()
    return mapConfigs
end

-- ============================================================
-- Sync to clients
-- ============================================================

-- Sends the current map's config (or a "no config" flag) to one player.
local function SyncConfigToPlayer(ply)
    local currentMap = string.lower(game.GetMap())
    local config = mapConfigs[currentMap]

    net.Start("MapPP_SyncConfig")

    if config then
        net.WriteBool(true)
        net.WriteFloat(config.tonemap_scale or 0)
        net.WriteFloat(config.bloom_scale or -1)
        net.WriteFloat(config.mat_specular or -1)
    else
        -- Tell the client there's nothing to override on this map.
        net.WriteBool(false)
    end

    net.Send(ply)
end

-- Pushes the current map's config to every connected player.
local function SyncConfigToAll()
    for _, ply in ipairs(player.GetAll()) do
        SyncConfigToPlayer(ply)
    end
end

-- ============================================================
-- Rate limiting for net receivers
-- ============================================================

local lastRequest = {}
local RATE_LIMIT = 1  -- seconds between allowed requests per player

-- Returns true if the player is sending requests too fast.
local function IsRateLimited(ply)
    local now = CurTime()
    local sid = ply:SteamID()

    if lastRequest[sid] and (now - lastRequest[sid]) < RATE_LIMIT then
        return true
    end

    lastRequest[sid] = now
    return false
end

-- When a client finishes loading the map (InitPostEntity on their end),
-- they send this message to ask for the current map's config.
net.Receive("MapPP_ClientReady", function(len, ply)
    if not IsValid(ply) then return end
    if IsRateLimited(ply) then return end

    SyncConfigToPlayer(ply)
end)

-- Server-side fallback: push config when the player finishes loading.
-- InitPostEntity doesn't fire reliably on map change in all scenarios,
-- so this ensures every player receives the config even if the client
-- never sends MapPP_ClientReady.
hook.Add("PlayerFullLoad", "MapPP_SyncOnFullLoad", function(ply)
    timer.Simple(1, function()
        if IsValid(ply) then
            SyncConfigToPlayer(ply)
        end
    end)
end)

-- ============================================================
-- XGUI panel net handlers
-- ============================================================

-- Admin toggles the master enable/disable switch. Since mappp_enabled
-- is a replicated ConVar, clients can't set it directly. The XGUI
-- checkbox sends this message instead and we set it here on the server.
net.Receive("MapPP_SetEnabled", function(len, ply)
    if not IsValid(ply) then return end
    if IsRateLimited(ply) then return end
    if not ply:IsSuperAdmin() then return end

    local enabled = net.ReadBool()
    RunConsoleCommand("mappp_enabled", enabled and "1" or "0")
    print(TAG .. " " .. ply:Nick() .. " set mappp_enabled to " .. (enabled and "1" or "0"))
end)

-- Admin requests the full config table to populate the XGUI map list.
net.Receive("MapPP_RequestFullConfig", function(len, ply)
    if not IsValid(ply) then return end
    if IsRateLimited(ply) then return end
    if not ply:IsAdmin() then return end

    local encoded = util.TableToJSON(mapConfigs)

    net.Start("MapPP_FullConfig")
    net.WriteString(encoded)
    net.Send(ply)
end)

-- SuperAdmin submits new or updated settings for a map.
net.Receive("MapPP_UpdateMapConfig", function(len, ply)
    if not IsValid(ply) then return end
    if IsRateLimited(ply) then return end
    if not ply:IsSuperAdmin() then return end

    local mapName = net.ReadString()
    local tonemapScale = net.ReadFloat()
    local bloomScale = net.ReadFloat()
    local matSpecular = net.ReadFloat()

    -- Validate map name: letters, numbers, underscores, and hyphens only.
    if not mapName or #mapName == 0 or #mapName > 64 then return end
    if not string.match(mapName, "^[%w_%-]+$") then return end

    -- Clamp everything to sane ranges.
    tonemapScale = math.Clamp(tonemapScale, -1, 5)
    bloomScale   = math.Clamp(bloomScale, -1, 5)
    matSpecular  = math.Clamp(matSpecular, -1, 1)

    local config = {
        tonemap_scale = tonemapScale,
        bloom_scale   = bloomScale,
        mat_specular  = matSpecular
    }

    SetMapConfig(mapName, config)
    print(TAG .. " " .. ply:Nick() .. " updated config for " .. mapName)

    -- If we just changed the active map's config, push the new
    -- settings to everyone immediately.
    if string.lower(game.GetMap()) == string.lower(mapName) then
        SyncConfigToAll()
    end
end)

-- SuperAdmin removes a map's config entry entirely.
net.Receive("MapPP_RemoveMapConfig", function(len, ply)
    if not IsValid(ply) then return end
    if IsRateLimited(ply) then return end
    if not ply:IsSuperAdmin() then return end

    local mapName = net.ReadString()

    if not mapName or #mapName == 0 or #mapName > 64 then return end
    if not string.match(mapName, "^[%w_%-]+$") then return end

    RemoveMapConfig(mapName)
    print(TAG .. " " .. ply:Nick() .. " removed config for " .. mapName)

    -- If we just removed the active map's config, tell clients
    -- to restore their defaults.
    if string.lower(game.GetMap()) == string.lower(mapName) then
        SyncConfigToAll()
    end
end)

-- ============================================================
-- Public API for ULX module
-- ============================================================

-- Expose functions globally so the ULX command file can call them
-- without needing to share locals across files.
MapPP = MapPP or {}
MapPP.GetMapConfig    = GetMapConfig
MapPP.SetMapConfig    = SetMapConfig
MapPP.RemoveMapConfig = RemoveMapConfig
MapPP.GetAllConfigs   = GetAllConfigs
MapPP.SyncConfigToAll = SyncConfigToAll
MapPP.LoadConfig      = function()
    LoadConfig()
    -- After reloading from disk, push any changes for the current map.
    SyncConfigToAll()
end
