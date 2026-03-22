-- =============================================================================
--  AFK System - ULX Module
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Adds AFK commands to the ULX admin mod:
--  !afk (self-toggle), !forceafk (admin), !unafk (admin), !afktime (superadmin)
-- =============================================================================

-- =============================================================================
-- !afk - Self-toggle (available to all players)
-- =============================================================================

function ulx.afk(calling_ply)
    if not IsValid(calling_ply) then return end

    if not AFK then
        ULib.tsayError(calling_ply, "AFK system is not loaded.")
        return
    end

    local isAFK = calling_ply:GetNWBool(AFK.NW_IS_AFK, false)
    AFK.SetPlayerAFK(calling_ply, not isAFK, "manual")
    -- No fancyLogAdmin here — SetPlayerAFK already broadcasts the chat message.
    -- Admin commands (forceafk, unafk) use fancyLogAdmin since the action is notable.
end

local afk_cmd = ulx.command("AFK", "ulx afk", ulx.afk, "!afk")
afk_cmd:defaultAccess(ULib.ACCESS_ALL)
afk_cmd:help("Toggle your AFK status.")

-- =============================================================================
-- !forceafk - Admin force-AFK a player
-- =============================================================================

function ulx.forceafk(calling_ply, target_ply)
    if not IsValid(target_ply) then return end

    if not AFK then
        ULib.tsayError(calling_ply, "AFK system is not loaded.")
        return
    end

    if target_ply:GetNWBool(AFK.NW_IS_AFK, false) then
        ULib.tsayError(calling_ply, target_ply:Nick() .. " is already AFK.")
        return
    end

    AFK.SetPlayerAFK(target_ply, true, "admin")
    ulx.fancyLogAdmin(calling_ply, "#A forced #T into AFK mode.", target_ply)
end

local forceafk_cmd = ulx.command("AFK", "ulx forceafk", ulx.forceafk, "!forceafk")
forceafk_cmd:addParam{type = ULib.cmds.PlayerArg}
forceafk_cmd:defaultAccess(ULib.ACCESS_ADMIN)
forceafk_cmd:help("Force a player into AFK mode.")

-- =============================================================================
-- !unafk - Admin remove AFK from a player
-- =============================================================================

function ulx.unafk(calling_ply, target_ply)
    if not IsValid(target_ply) then return end

    if not AFK then
        ULib.tsayError(calling_ply, "AFK system is not loaded.")
        return
    end

    if not target_ply:GetNWBool(AFK.NW_IS_AFK, false) then
        ULib.tsayError(calling_ply, target_ply:Nick() .. " is not AFK.")
        return
    end

    AFK.SetPlayerAFK(target_ply, false, "admin")
    ulx.fancyLogAdmin(calling_ply, "#A removed #T from AFK mode.", target_ply)
end

local unafk_cmd = ulx.command("AFK", "ulx unafk", ulx.unafk, "!unafk")
unafk_cmd:addParam{type = ULib.cmds.PlayerArg}
unafk_cmd:defaultAccess(ULib.ACCESS_ADMIN)
unafk_cmd:help("Remove a player from AFK mode.")

-- =============================================================================
-- !afktime - Set auto-AFK timeout (superadmin)
-- =============================================================================

function ulx.afktime(calling_ply, seconds)
    if not AFK then
        ULib.tsayError(calling_ply, "AFK system is not loaded.")
        return
    end

    -- Set the ConVar (persists across map changes, syncs to AFK.Config via callback)
    RunConsoleCommand("afk_auto_timeout", tostring(seconds))

    if seconds <= 0 then
        ulx.fancyLogAdmin(calling_ply, "#A disabled auto-AFK timeout.")
    else
        local mins = math.floor(seconds / 60)
        local secs = seconds % 60
        local timeStr = ""
        if mins > 0 then timeStr = mins .. " minute(s)" end
        if secs > 0 then
            if timeStr ~= "" then timeStr = timeStr .. " " end
            timeStr = timeStr .. secs .. " second(s)"
        end
        ulx.fancyLogAdmin(calling_ply, "#A set auto-AFK timeout to " .. timeStr .. ".")
    end
end

local afktime_cmd = ulx.command("AFK", "ulx afktime", ulx.afktime, "!afktime")
afktime_cmd:addParam{type = ULib.cmds.NumArg, min = 0, max = 3600, default = 300, hint = "seconds (0 = disable)", ULib.cmds.round}
afktime_cmd:defaultAccess(ULib.ACCESS_SUPERADMIN)
afktime_cmd:help("Set the auto-AFK idle timeout in seconds. 0 to disable.")
