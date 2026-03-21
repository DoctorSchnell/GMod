--[[
    AFK System - Autorun Loader
    Handles file inclusion for server and client realms
]]--

local function IncludeClient(path)
    if SERVER then
        AddCSLuaFile(path)
    end
    if CLIENT then
        include(path)
    end
end

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
IncludeShared("afk_system/sh_config.lua")
IncludeShared("afk_system/sh_convars.lua")

-- Server
IncludeServer("afk_system/sv_core.lua")

-- Client
IncludeClient("afk_system/cl_input.lua")
IncludeClient("afk_system/cl_overhead.lua")
IncludeClient("afk_system/cl_scoreboard.lua")
