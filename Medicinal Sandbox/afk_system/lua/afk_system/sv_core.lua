-- =============================================================================
--  AFK System - Server Core
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Manages AFK state, activity tracking, auto-AFK timeout, and chat commands.
-- =============================================================================

AFK.LastActivity = AFK.LastActivity or {}

-- =============================================================================
-- NETWORKING
-- =============================================================================

util.AddNetworkString("AFK_Activity")
util.AddNetworkString("AFK_ConfigChange")

-- =============================================================================
-- ACTIVITY RATE LIMITING (server-side)
-- =============================================================================

-- Tracks the last accepted ping time per player SteamID.
-- Pings arriving faster than the configured rate are silently dropped.
local lastPingAccepted = {}

-- =============================================================================
-- ADMIN CONFIG CHANGES (from XGUI panel)
-- =============================================================================

-- Whitelist of ConVars that admins can change via the XGUI panel.
-- Values: "admin" or "superadmin" — the minimum rank required.
local allowedConVars = {
    -- SuperAdmin-only: these affect server behavior / gameplay
    ["afk_auto_timeout"]       = "superadmin",
    ["afk_check_interval"]     = "superadmin",
    ["afk_ping_rate"]          = "superadmin",

    -- Admin: cosmetic / informational settings
    ["afk_broadcast"]          = "admin",
    ["afk_chat_prefix"]        = "admin",
    ["afk_overhead_enabled"]   = "admin",
    ["afk_overhead_self"]      = "admin",
    ["afk_overhead_maxdist"]   = "admin",
    ["afk_overhead_offset"]    = "admin",
    ["afk_overhead_scale"]     = "admin",
    ["afk_overhead_spin"]      = "admin",
    ["afk_sign_bg_r"]          = "admin",
    ["afk_sign_bg_g"]          = "admin",
    ["afk_sign_bg_b"]          = "admin",
    ["afk_sign_bg_a"]          = "admin",
    ["afk_sign_text_r"]        = "admin",
    ["afk_sign_text_g"]        = "admin",
    ["afk_sign_text_b"]        = "admin",
    ["afk_scoreboard_dim"]     = "admin",
}

-- Maximum allowed length for the chat prefix string.
local MAX_PREFIX_LENGTH = 32

net.Receive("AFK_ConfigChange", function(len, ply)
    if not IsValid(ply) then return end

    local cvarName = net.ReadString()
    local cvarValue = net.ReadString()

    local requiredRank = allowedConVars[cvarName]
    if not requiredRank then return end

    -- Permission check: superadmin-tier ConVars need IsSuperAdmin
    if requiredRank == "superadmin" then
        if not ply:IsSuperAdmin() then return end
    else
        if not ply:IsAdmin() then return end
    end

    local cv = GetConVar(cvarName)
    if not cv then return end

    -- Sanitize chat prefix length
    if cvarName == "afk_chat_prefix" then
        if string.len(cvarValue) > MAX_PREFIX_LENGTH then
            cvarValue = string.sub(cvarValue, 1, MAX_PREFIX_LENGTH)
        end
    end

    RunConsoleCommand(cvarName, cvarValue)
end)

-- =============================================================================
-- HELPERS
-- =============================================================================

--- Set a player's AFK status.
-- @param ply     Player entity
-- @param afk     boolean - true to go AFK, false to return
-- @param reason  string  - "manual", "auto", "admin"
function AFK.SetPlayerAFK(ply, afk, reason)
    if not IsValid(ply) or ply:IsBot() then return end

    local wasAFK = ply:GetNWBool(AFK.NW_IS_AFK, false)
    if wasAFK == afk then return end -- no change

    ply:SetNWBool(AFK.NW_IS_AFK, afk)

    if afk then
        ply:SetNWFloat(AFK.NW_SINCE, CurTime())
    else
        ply:SetNWFloat(AFK.NW_SINCE, 0)
        -- Reset activity timer so they don't immediately go AFK again
        AFK.LastActivity[ply:SteamID()] = CurTime()
    end

    -- Broadcast chat message
    if AFK.Config.BroadcastMessages then
        local prefix = AFK.Config.ChatPrefix
        local msg
        if afk then
            if reason == "admin" then
                msg = prefix .. ply:Nick() .. " was placed into AFK mode by an admin."
            elseif reason == "auto" then
                msg = prefix .. ply:Nick() .. " is now AFK (idle timeout)."
            else
                msg = prefix .. ply:Nick() .. " is now AFK."
            end
        else
            msg = prefix .. ply:Nick() .. " is no longer AFK."
        end

        for _, v in ipairs(player.GetAll()) do
            v:ChatPrint(msg)
        end
    end

    -- Fire a hook for other addons to listen to
    hook.Run("AFK_StatusChanged", ply, afk, reason)
end

--- Check if a player is AFK.
function AFK.IsPlayerAFK(ply)
    if not IsValid(ply) then return false end
    return ply:GetNWBool(AFK.NW_IS_AFK, false)
end

-- =============================================================================
-- ACTIVITY TRACKING
-- =============================================================================

-- Receive activity pings from clients (rate-limited server-side)
net.Receive("AFK_Activity", function(len, ply)
    if not IsValid(ply) then return end

    local sid = ply:SteamID()
    local now = CurTime()

    -- Server-side rate limit: ignore pings that arrive faster than the configured rate.
    -- This prevents net spam from modified clients and limits CPU work per player.
    local minInterval = AFK.Config.ActivityPingRate or 1
    local lastAccepted = lastPingAccepted[sid] or 0
    if (now - lastAccepted) < minInterval then return end
    lastPingAccepted[sid] = now

    AFK.LastActivity[sid] = now

    -- If this player was AFK, take them out of AFK
    if AFK.IsPlayerAFK(ply) then
        AFK.SetPlayerAFK(ply, false, "input")
    end
end)

-- Initialize activity timer when a player spawns
hook.Add("PlayerInitialSpawn", "AFK_InitActivity", function(ply)
    if ply:IsBot() then return end
    AFK.LastActivity[ply:SteamID()] = CurTime()
end)

-- Clean up on disconnect
hook.Add("PlayerDisconnected", "AFK_CleanupDisconnect", function(ply)
    if ply:IsBot() then return end
    local sid = ply:SteamID()
    AFK.LastActivity[sid] = nil
    lastPingAccepted[sid] = nil
end)

-- =============================================================================
-- AUTO-AFK TIMER
-- =============================================================================

local nextCheck = 0

hook.Add("Think", "AFK_AutoTimeout", function()
    if AFK.Config.AutoTimeout <= 0 then return end
    if CurTime() < nextCheck then return end
    nextCheck = CurTime() + AFK.Config.CheckInterval

    for _, ply in ipairs(player.GetAll()) do
        if ply:IsBot() then continue end
        if AFK.IsPlayerAFK(ply) then continue end

        local sid = ply:SteamID()
        local lastAct = AFK.LastActivity[sid]

        if lastAct and (CurTime() - lastAct) >= AFK.Config.AutoTimeout then
            AFK.SetPlayerAFK(ply, true, "auto")
        end
    end
end)

-- =============================================================================
-- CHAT COMMAND: !afk
-- Only handles !afk here if ULX is NOT loaded.
-- When ULX is present, the ULX module handles !afk to avoid double-toggle.
-- =============================================================================

hook.Add("PlayerSay", "AFK_ChatCommand", function(ply, text)
    local cmd = string.lower(string.Trim(text))

    if cmd == "!afk" then
        -- If ULX is loaded, it handles !afk via its own module — don't double-toggle
        if ulx then return "" end

        local isAFK = AFK.IsPlayerAFK(ply)
        AFK.SetPlayerAFK(ply, not isAFK, "manual")
        return "" -- suppress the chat message
    end
end)

-- Also count chat as activity (if they type anything else while AFK)
hook.Add("PlayerSay", "AFK_ChatActivity", function(ply, text)
    local cmd = string.lower(string.Trim(text))
    if cmd == "!afk" then return end -- handled above

    if AFK.IsPlayerAFK(ply) then
        AFK.SetPlayerAFK(ply, false, "input")
    end

    if not ply:IsBot() then
        AFK.LastActivity[ply:SteamID()] = CurTime()
    end
end)
