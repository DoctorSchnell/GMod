-- Map Post-Process Fix - Shared Configuration
-- Addon by Doctor Schnell
--
-- Creates the master toggle ConVar in a shared context so that
-- FCVAR_REPLICATED actually works (client-only creation would cause
-- "Unknown command" errors when XGUI tries to set it). Also registers
-- all network strings the addon uses for config sync and admin edits.

-- Master toggle for the entire addon. When disabled, clients restore
-- their engine defaults and no overrides are applied.
CreateConVar("mappp_enabled", "1",
    bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY),
    "Enable or disable map post-processing overrides", 0, 1)

-- Network strings need to be registered on the server before either
-- side can use them. Putting this in a shared file that gates on
-- SERVER keeps everything in one place.
if SERVER then
    -- Pushes the active map's PP settings to a single client (on join or config change).
    util.AddNetworkString("MapPP_SyncConfig")

    -- Client (XGUI panel) asks for the full config table to populate the map list.
    util.AddNetworkString("MapPP_RequestFullConfig")

    -- Server responds with the entire config table as a JSON string.
    util.AddNetworkString("MapPP_FullConfig")

    -- Admin submits new or updated settings for a specific map.
    util.AddNetworkString("MapPP_UpdateMapConfig")

    -- Admin requests deletion of a map's config entry.
    util.AddNetworkString("MapPP_RemoveMapConfig")

    -- Client signals it has fully loaded into the map and is ready
    -- to receive its config. This replaces the unreliable timer-based
    -- push from PlayerInitialSpawn.
    util.AddNetworkString("MapPP_ClientReady")

    -- Admin requests the master toggle be flipped. Replicated ConVars
    -- can only be changed server-side, so the XGUI checkbox routes
    -- through this instead of setting the ConVar directly.
    util.AddNetworkString("MapPP_SetEnabled")
end
