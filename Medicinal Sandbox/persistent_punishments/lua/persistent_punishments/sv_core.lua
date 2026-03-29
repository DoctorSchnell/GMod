-- =============================================================================
--  Persistent Punishments - Server Core
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Hooks into ULX at runtime to apply/remove punishments.
--  Handles re-application on rejoin, expiry timers, and XGUI net handlers.
-- =============================================================================

-- =============================================================================
-- NETWORKING
-- =============================================================================

util.AddNetworkString("PPunish_ConfigChange")
util.AddNetworkString("PPunish_RequestList")
util.AddNetworkString("PPunish_SendList")
util.AddNetworkString("PPunish_RemovePunishment")
util.AddNetworkString("PPunish_UpdatePunishment")

-- Register XGUI access string so the Punishments tab is visible to superadmins
-- Must be deferred — ULib.ucl.registerAccess isn't available during autorun
hook.Add("Initialize", "PPunish_RegisterAccess", function()
    ULib.ucl.registerAccess("xgui_manageppunish", "superadmin", "Allows viewing and managing persistent punishments in the XGUI Punishments tab.", "XGUI")
end)

-- =============================================================================
-- HELPERS
-- =============================================================================

--- Format remaining time as a human-readable string.
-- @param expiresAt number - Unix timestamp (0 = permanent)
-- @return string
local function FormatTimeRemaining(expiresAt)
    if expiresAt == 0 then return "Permanent" end

    local remaining = expiresAt - os.time()
    if remaining <= 0 then return "Expired" end

    -- Use ULib's formatter if available, otherwise build our own
    if ULib and ULib.secondsToStringTime then
        return ULib.secondsToStringTime(remaining)
    end

    local days = math.floor(remaining / 86400)
    remaining = remaining % 86400
    local hours = math.floor(remaining / 3600)
    remaining = remaining % 3600
    local mins = math.floor(remaining / 60)

    local parts = {}
    if days > 0 then table.insert(parts, days .. "d") end
    if hours > 0 then table.insert(parts, hours .. "h") end
    if mins > 0 then table.insert(parts, mins .. "m") end

    if #parts == 0 then return "< 1m" end
    return table.concat(parts, " ")
end

-- =============================================================================
-- APPLY / LIFT PUNISHMENTS VIA ULX
-- =============================================================================

--- Apply a punishment to a player by calling the corresponding ULX function.
-- @param ply Player entity
-- @param record table - punishment record from the database
-- @return boolean - true if applied successfully
function PPunish.ApplyPunishment(ply, record)
    if not IsValid(ply) then return false end
    if not ulx then
        ServerLog("[Persistent Punishments] ERROR: ULX not loaded, cannot apply punishment.\n")
        return false
    end

    local ptype = record.punishment_type

    if ptype == "gag" then
        if not ulx.gag then return false end
        PPunish.CallULXSilent(ulx.gag, nil, {ply}, false)

    elseif ptype == "mute" then
        if not ulx.mute then return false end
        PPunish.CallULXSilent(ulx.mute, nil, {ply}, false)

    elseif ptype == "freeze" then
        if not ulx.freeze then return false end
        -- Skip if player already has an exclusive state (e.g., already jailed)
        if ply.ULXExclusive then
            ServerLog("[Persistent Punishments] Skipping freeze for " .. ply:Nick() .. " (already in exclusive state: " .. tostring(ply.ULXExclusive) .. ").\n")
            return false
        end
        PPunish.CallULXSilent(ulx.freeze, nil, {ply}, false)

    elseif ptype == "jail" then
        if not ulx.jail then return false end
        -- Teleport to stored position first
        local jailPos = Vector(record.jail_pos_x or 0, record.jail_pos_y or 0, record.jail_pos_z or 0)

        -- Validate the stored position is in the world
        if not util.IsInWorld(jailPos) then
            -- Fall back to a spawn point
            local spawns = ents.FindByClass("info_player_start")
            if #spawns > 0 then
                jailPos = spawns[math.random(#spawns)]:GetPos()
            end
            ServerLog("[Persistent Punishments] WARNING: Stored jail position invalid for " .. ply:Nick() .. ", using spawn point.\n")
        end

        ply:SetPos(jailPos)

        -- Calculate remaining seconds for timed jail
        local remainingSeconds = 0
        if record.expires_at > 0 then
            remainingSeconds = math.max(0, record.expires_at - os.time())
        end

        -- Skip if player already has an exclusive state
        if ply.ULXExclusive then
            ServerLog("[Persistent Punishments] Skipping jail for " .. ply:Nick() .. " (already in exclusive state: " .. tostring(ply.ULXExclusive) .. ").\n")
            return false
        end

        PPunish.CallULXSilent(ulx.jail, nil, {ply}, remainingSeconds, false)
    else
        ServerLog("[Persistent Punishments] ERROR: Unknown punishment type: " .. tostring(ptype) .. "\n")
        return false
    end

    return true
end

--- Lift a punishment from a player by calling the corresponding ULX un-function.
-- @param ply Player entity
-- @param punishType string - "gag", "mute", "freeze", "jail"
function PPunish.LiftPunishment(ply, punishType)
    if not IsValid(ply) then return end
    if not ulx then return end

    if punishType == "gag" then
        if ulx.gag and ply.ulx_gagged then
            PPunish.CallULXSilent(ulx.gag, nil, {ply}, true)
        end

    elseif punishType == "mute" then
        if ulx.mute and ply.gimp then
            PPunish.CallULXSilent(ulx.mute, nil, {ply}, true)
        end

    elseif punishType == "freeze" then
        if ulx.freeze and ply.frozen then
            PPunish.CallULXSilent(ulx.freeze, nil, {ply}, true)
        end

    elseif punishType == "jail" then
        if ulx.jail and ply.jail then
            PPunish.CallULXSilent(ulx.jail, nil, {ply}, 0, true)
        end
    end
end

-- =============================================================================
-- NOTIFICATIONS
-- =============================================================================

--- Send colored chat notification to a punished player.
-- One message per active punishment showing type, reason, and duration.
-- @param ply Player entity
-- @param records table - array of punishment records
function PPunish.NotifyPlayer(ply, records)
    if not IsValid(ply) then return end

    for _, record in ipairs(records) do
        local typeName = PPunish.TYPES[record.punishment_type] or record.punishment_type
        local timeStr = FormatTimeRemaining(record.expires_at)
        local reason = record.reason
        if reason == "" then reason = "No reason given" end

        ULib.tsayColor(ply, false,
            PPunish.Colors.Header, "[Persistent Punishment] ",
            PPunish.Colors.Type, typeName,
            PPunish.Colors.Reason, " — Reason: \"" .. reason .. "\"",
            PPunish.Colors.Duration, " — Expires: " .. timeStr
        )
    end

end

--- Send the same colored notification to the admin who applied the punishment.
-- Skips if the admin is the target (they already get it) or is Console.
-- @param calling_ply Player entity or nil (the admin)
-- @param target_ply Player entity (the target)
-- @param record table - single punishment record with punishment_type, reason, expires_at
function PPunish.NotifyCallingAdmin(calling_ply, target_ply, record)
    if not IsValid(calling_ply) then return end
    if calling_ply == target_ply then return end

    local typeName = PPunish.TYPES[record.punishment_type] or record.punishment_type
    local timeStr = FormatTimeRemaining(record.expires_at)
    local reason = record.reason
    if reason == "" then reason = "No reason given" end

    ULib.tsayColor(calling_ply, false,
        PPunish.Colors.Header, "[Persistent Punishment] ",
        PPunish.Colors.Type, typeName,
        PPunish.Colors.Reason, " applied to " .. target_ply:Nick() .. " — Reason: \"" .. reason .. "\"",
        PPunish.Colors.Duration, " — Expires: " .. timeStr
    )
end

--- Notify all online admins that a punished player has joined.
-- @param ply Player entity (the punished player)
-- @param records table - array of punishment records
function PPunish.NotifyAdmins(ply, records)
    if not IsValid(ply) then return end
    if not PPunish.Config.NotifyAdmins then return end

    local typeNames = {}
    for _, record in ipairs(records) do
        table.insert(typeNames, PPunish.TYPES[record.punishment_type] or record.punishment_type)
    end

    local typeList = table.concat(typeNames, ", ")

    for _, admin in ipairs(player.GetAll()) do
        if admin:IsAdmin() and admin ~= ply then
            ULib.tsayColor(admin, false,
                PPunish.Colors.Header, "[Persistent Punishment] ",
                PPunish.Colors.Admin, ply:Nick() .. " joined with " .. #records .. " active punishment(s): " .. typeList
            )
        end
    end
end

-- =============================================================================
-- HOOKS: PLAYER JOIN / LEAVE
-- =============================================================================

hook.Add("PlayerInitialSpawn", "PPunish_OnJoin", function(ply)
    if ply:IsBot() then return end
    if not PPunish.Config.Enabled then return end

    -- Delay to ensure player is fully spawned and ULX is ready
    timer.Simple(3, function()
        if not IsValid(ply) then return end
        if not PPunish.Config.Enabled then return end

        -- Expire any overdue punishments first
        PPunish.ExpireOverdue()

        local records = PPunish.GetActivePunishments(ply:SteamID64())
        if #records == 0 then return end

        ServerLog("[Persistent Punishments] Re-applying " .. #records .. " punishment(s) for " .. ply:Nick() .. " (" .. ply:SteamID64() .. ").\n")

        -- Sort so jail/freeze (exclusive) come after gag/mute (non-exclusive)
        -- This ensures gag/mute are applied even if jail/freeze has exclusive conflict
        local order = { gag = 1, mute = 2, freeze = 3, jail = 4 }
        table.sort(records, function(a, b)
            return (order[a.punishment_type] or 99) < (order[b.punishment_type] or 99)
        end)

        for _, record in ipairs(records) do
            PPunish.ApplyPunishment(ply, record)
        end

        PPunish.NotifyPlayer(ply, records)
        PPunish.NotifyAdmins(ply, records)
    end)
end)

hook.Add("PlayerDisconnected", "PPunish_OnLeave", function(ply)
    -- ULX handles its own cleanup (jail walls, freeze state, etc.)
    -- Nothing addon-specific to clean up here
end)

-- =============================================================================
-- EXPIRY TIMER
-- =============================================================================

--- Check for expired punishments and lift them from online players.
local function CheckExpiredPunishments()
    if not PPunish.Config.Enabled then return end

    local expiredCount = PPunish.ExpireOverdue()

    if expiredCount > 0 then
        ServerLog("[Persistent Punishments] Expired " .. expiredCount .. " overdue punishment(s).\n")
    end

    -- Check each online player for punishments that just expired
    for _, ply in ipairs(player.GetAll()) do
        if ply:IsBot() then continue end

        -- For each punishment type, check if they still have an active record
        -- If ULX state is set but no active DB record exists, lift it
        for typeKey, _ in pairs(PPunish.TYPES) do
            local hasActive = PPunish.HasActivePunishment(ply:SteamID64(), typeKey)

            if not hasActive then
                -- Check if ULX state is still applied (meaning it just expired)
                local ulxActive = false
                if typeKey == "gag" and ply.ulx_gagged then ulxActive = true end
                if typeKey == "mute" and ply.gimp then ulxActive = true end
                if typeKey == "freeze" and ply.frozen then ulxActive = true end
                if typeKey == "jail" and ply.jail then ulxActive = true end

                -- Only lift if the punishment was originally persistent
                -- We track this by checking if it was recently in our DB
                -- For safety, we don't lift punishments that weren't ours
                -- This is handled by only expiring our own DB records
            end
        end
    end
end

local function StartExpiryTimer()
    local interval = PPunish.Config.CheckInterval or 30

    if timer.Exists("PPunish_ExpiryCheck") then
        timer.Remove("PPunish_ExpiryCheck")
    end

    timer.Create("PPunish_ExpiryCheck", interval, 0, function()
        if not PPunish.Config.Enabled then return end

        -- Snapshot which players have which active punishments BEFORE expiring
        local preExpiry = {}
        for _, ply in ipairs(player.GetAll()) do
            if ply:IsBot() then continue end
            local sid = ply:SteamID64()
            preExpiry[sid] = {}
            for typeKey, _ in pairs(PPunish.TYPES) do
                preExpiry[sid][typeKey] = PPunish.HasActivePunishment(sid, typeKey)
            end
        end

        -- Expire overdue punishments in the DB
        local expiredCount = PPunish.ExpireOverdue()

        if expiredCount > 0 then
            ServerLog("[Persistent Punishments] Expired " .. expiredCount .. " overdue punishment(s).\n")

            -- Check which online players lost punishments
            for _, ply in ipairs(player.GetAll()) do
                if not IsValid(ply) or ply:IsBot() then continue end
                local sid = ply:SteamID64()
                local pre = preExpiry[sid]
                if not pre then continue end

                for typeKey, typeName in pairs(PPunish.TYPES) do
                    if pre[typeKey] and not PPunish.HasActivePunishment(sid, typeKey) then
                        -- This punishment just expired — lift it
                        PPunish.LiftPunishment(ply, typeKey)

                        ULib.tsayColor(ply, false,
                            PPunish.Colors.Removed, "[Persistent Punishment] ",
                            PPunish.Colors.Reason, "Your persistent ",
                            PPunish.Colors.Type, typeName,
                            PPunish.Colors.Reason, " has expired."
                        )
                    end
                end
            end
        end
    end)
end

StartExpiryTimer()

-- Restart the timer when the check interval ConVar changes
cvars.AddChangeCallback("ppunish_check_interval", function()
    timer.Simple(0, StartExpiryTimer)
end, "ppunish_expiry_timer")

-- =============================================================================
-- ADMIN CONFIG CHANGES (from XGUI panel)
-- =============================================================================

local allowedConVars = {
    ["ppunish_enabled"]        = "superadmin",
    ["ppunish_notify_admins"]  = "admin",
    ["ppunish_check_interval"] = "superadmin",
}

net.Receive("PPunish_ConfigChange", function(len, ply)
    if not IsValid(ply) then return end

    local cvarName = net.ReadString()
    local cvarValue = net.ReadString()

    local requiredRank = allowedConVars[cvarName]
    if not requiredRank then return end

    if requiredRank == "superadmin" then
        if not ply:IsSuperAdmin() then return end
    else
        if not ply:IsAdmin() then return end
    end

    local cv = GetConVar(cvarName)
    if not cv then return end

    RunConsoleCommand(cvarName, cvarValue)
    ServerLog(string.format("[Persistent Punishments] %s changed %s to: %s\n", ply:Nick(), cvarName, cvarValue))
end)

-- =============================================================================
-- XGUI PANEL DATA: LIST / REMOVE
-- =============================================================================

local LIST_COOLDOWN = 2
local lastListRequest = {}

net.Receive("PPunish_RequestList", function(len, ply)
    if not IsValid(ply) then return end
    if not ply:IsAdmin() then return end

    -- Rate limit
    local sid = ply:SteamID()
    local now = CurTime()
    if (lastListRequest[sid] or 0) + LIST_COOLDOWN > now then return end
    lastListRequest[sid] = now

    local punishments = PPunish.GetAllActivePunishments()

    net.Start("PPunish_SendList")
        net.WriteUInt(#punishments, 10) -- up to 1023 entries
        for _, p in ipairs(punishments) do
            net.WriteUInt(p.id, 32)
            net.WriteString(p.player_name)
            net.WriteString(p.steamid64)
            net.WriteString(p.punishment_type)
            net.WriteString(p.reason)
            net.WriteString(p.admin_name)
            net.WriteInt(p.applied_at, 32)
            net.WriteInt(p.expires_at, 32)
        end
    net.Send(ply)
end)

net.Receive("PPunish_RemovePunishment", function(len, ply)
    if not IsValid(ply) then return end
    if not ply:IsAdmin() then return end

    local punishmentId = net.ReadUInt(32)
    if not punishmentId or punishmentId <= 0 then return end

    -- Look up the punishment to get details before removing
    local allActive = PPunish.GetAllActivePunishments()
    local targetRecord
    for _, p in ipairs(allActive) do
        if p.id == punishmentId then
            targetRecord = p
            break
        end
    end

    if not targetRecord then return end

    -- Deactivate in database
    PPunish.RemovePunishment(punishmentId)

    -- Lift the live ULX state if the player is online
    local targetPly = player.GetBySteamID64(targetRecord.steamid64)
    if IsValid(targetPly) then
        PPunish.LiftPunishment(targetPly, targetRecord.punishment_type)

        local typeName = PPunish.TYPES[targetRecord.punishment_type] or targetRecord.punishment_type
        ULib.tsayColor(targetPly, false,
            PPunish.Colors.Removed, "[Persistent Punishment] ",
            PPunish.Colors.Reason, "Your persistent ",
            PPunish.Colors.Type, typeName,
            PPunish.Colors.Reason, " has been removed by an admin."
        )
    end

    ServerLog(string.format("[Persistent Punishments] %s removed punishment #%d (%s on %s) via XGUI.\n",
        ply:Nick(), punishmentId, targetRecord.punishment_type, targetRecord.player_name))
end)

net.Receive("PPunish_UpdatePunishment", function(len, ply)
    if not IsValid(ply) then return end
    if not ply:IsAdmin() then return end

    local punishmentId = net.ReadUInt(32)
    local newMinutes = net.ReadInt(32)
    local newReason = net.ReadString()

    if not punishmentId or punishmentId <= 0 then return end

    local record = PPunish.GetPunishmentByID(punishmentId)
    if not record or record.active == 0 then return end

    local success = PPunish.UpdatePunishment(punishmentId, newMinutes, newReason)
    if not success then return end

    -- If the player is online and has a timed jail/freeze, we may need to re-apply
    -- with new timing. For simplicity, just notify — the new timing takes effect
    -- on the next expiry check or rejoin.
    local targetPly = player.GetBySteamID64(record.steamid64)
    if IsValid(targetPly) then
        local typeName = PPunish.TYPES[record.punishment_type] or record.punishment_type
        ULib.tsayColor(targetPly, false,
            PPunish.Colors.Header, "[Persistent Punishment] ",
            PPunish.Colors.Reason, "Your persistent ",
            PPunish.Colors.Type, typeName,
            PPunish.Colors.Reason, " has been updated by an admin."
        )
    end

    ServerLog(string.format("[Persistent Punishments] %s updated punishment #%d (%s on %s) via XGUI.\n",
        ply:Nick(), punishmentId, record.punishment_type, record.player_name))
end)

-- Clean up rate limit tracking on disconnect
hook.Add("PlayerDisconnected", "PPunish_CleanupRateLimit", function(ply)
    if ply:IsBot() then return end
    lastListRequest[ply:SteamID()] = nil
end)
