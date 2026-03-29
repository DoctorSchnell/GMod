-- =============================================================================
--  Persistent Punishments - Autorun Loader
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Handles file inclusion for server and client realms.
-- =============================================================================

PPunish = PPunish or {}

PPunish.TYPES = {
    gag    = "Gag",
    mute   = "Mute",
    freeze = "Freeze",
    jail   = "Jail",
}

local function IncludeServer(path)
    if SERVER then
        include(path)
    end
end

local function IncludeShared(path)
    if SERVER then
        AddCSLuaFile(path)
    end
    include(path)
end

-- Shared (defaults, then ConVars override)
IncludeShared("persistent_punishments/sh_config.lua")
IncludeShared("persistent_punishments/sh_convars.lua")

-- Server
IncludeServer("persistent_punishments/sv_database.lua")
IncludeServer("persistent_punishments/sv_core.lua")
