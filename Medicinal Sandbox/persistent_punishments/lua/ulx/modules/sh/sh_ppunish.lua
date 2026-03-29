-- =============================================================================
--  Persistent Punishments - ULX Command Module
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Adds persistent punishment commands to ULX:
--  !pgag, !pmute, !pfreeze, !pjail (and their !unp* counterparts)
--  !pgagid, !pmuteid, !pfreezeid, !pjailid (SteamID-based, works offline)
--  !unpgagid, !unpmuteid, !unpfreezeid, !unpjailid (SteamID-based removal)
--  !ppunishments - view active punishments on a player
-- =============================================================================

local CATEGORY = "Persistent Punishments"

-- =============================================================================
-- HELPER: Format remaining time
-- =============================================================================

local function FormatTimeRemaining(expiresAt)
    if expiresAt == 0 then return "permanent" end
    local remaining = expiresAt - os.time()
    if remaining <= 0 then return "expired" end
    if ULib and ULib.secondsToStringTime then
        return ULib.secondsToStringTime(remaining)
    end
    local mins = math.ceil(remaining / 60)
    return mins .. " minute(s)"
end

-- =============================================================================
-- !pgag - Persistent Gag (blocks voice)
-- =============================================================================

function ulx.pgag(calling_ply, target_ply, minutes, reason)
    if not PPunish or not PPunish.Config.Enabled then
        ULib.tsayError(calling_ply, "Persistent Punishments is not enabled.")
        return
    end

    local sid = target_ply:SteamID64()

    if PPunish.HasActivePunishment(sid, "gag") then
        ULib.tsayError(calling_ply, target_ply:Nick() .. " already has a persistent gag. Use !unpgag first.")
        return
    end

    local adminSid = IsValid(calling_ply) and calling_ply:SteamID64() or "CONSOLE"
    local adminName = IsValid(calling_ply) and calling_ply:Nick() or "Console"

    local id = PPunish.AddPunishment(sid, target_ply:Nick(), "gag", reason, adminSid, adminName, minutes, nil)
    PPunish.CallULXSilent(ulx.gag, calling_ply, {target_ply}, false)

    local records = PPunish.GetActivePunishments(sid)
    PPunish.NotifyPlayer(target_ply, records)

    local record = id and PPunish.GetPunishmentByID(id)
    if record then PPunish.NotifyCallingAdmin(calling_ply, target_ply, record) end

    local timeStr = minutes > 0 and (minutes .. " minute(s)") or "permanently"
    ServerLog("[Persistent Punishments] " .. adminName .. " persistently gagged " .. target_ply:Nick() .. " " .. timeStr .. ". Reason: " .. reason .. "\n")
end

local pgag = ulx.command(CATEGORY, "ulx pgag", ulx.pgag, "!pgag")
pgag:addParam{type = ULib.cmds.PlayerArg}
pgag:addParam{type = ULib.cmds.NumArg, min = 0, default = 0, hint = "minutes (0=permanent)", ULib.cmds.round}
pgag:addParam{type = ULib.cmds.StringArg, hint = "reason", ULib.cmds.takeRestOfLine}
pgag:defaultAccess(ULib.ACCESS_ADMIN)
pgag:help("Persistently gag a player (survives reconnect).")

-- =============================================================================
-- !unpgag - Remove Persistent Gag
-- =============================================================================

function ulx.unpgag(calling_ply, target_ply)
    if not PPunish or not PPunish.Config.Enabled then
        ULib.tsayError(calling_ply, "Persistent Punishments is not enabled.")
        return
    end

    local sid = target_ply:SteamID64()

    if not PPunish.HasActivePunishment(sid, "gag") then
        ULib.tsayError(calling_ply, target_ply:Nick() .. " does not have a persistent gag.")
        return
    end

    PPunish.RemovePunishmentByType(sid, "gag")
    PPunish.LiftPunishment(target_ply, "gag")

    ULib.tsayColor(target_ply, false,
        PPunish.Colors.Removed, "[Persistent Punishment] ",
        PPunish.Colors.Reason, "Your persistent gag has been removed."
    )

    ServerLog("[Persistent Punishments] " .. (IsValid(calling_ply) and calling_ply:Nick() or "Console") .. " removed persistent gag from " .. target_ply:Nick() .. ".\n")
end

local unpgag = ulx.command(CATEGORY, "ulx unpgag", ulx.unpgag, "!unpgag")
unpgag:addParam{type = ULib.cmds.PlayerArg}
unpgag:defaultAccess(ULib.ACCESS_ADMIN)
unpgag:help("Remove a persistent gag from a player.")

-- =============================================================================
-- !pmute - Persistent Mute (blocks chat)
-- =============================================================================

function ulx.pmute(calling_ply, target_ply, minutes, reason)
    if not PPunish or not PPunish.Config.Enabled then
        ULib.tsayError(calling_ply, "Persistent Punishments is not enabled.")
        return
    end

    local sid = target_ply:SteamID64()

    if PPunish.HasActivePunishment(sid, "mute") then
        ULib.tsayError(calling_ply, target_ply:Nick() .. " already has a persistent mute. Use !unpmute first.")
        return
    end

    local adminSid = IsValid(calling_ply) and calling_ply:SteamID64() or "CONSOLE"
    local adminName = IsValid(calling_ply) and calling_ply:Nick() or "Console"

    local id = PPunish.AddPunishment(sid, target_ply:Nick(), "mute", reason, adminSid, adminName, minutes, nil)
    PPunish.CallULXSilent(ulx.mute, calling_ply, {target_ply}, false)

    local records = PPunish.GetActivePunishments(sid)
    PPunish.NotifyPlayer(target_ply, records)

    local record = id and PPunish.GetPunishmentByID(id)
    if record then PPunish.NotifyCallingAdmin(calling_ply, target_ply, record) end

    local timeStr = minutes > 0 and (minutes .. " minute(s)") or "permanently"
    ServerLog("[Persistent Punishments] " .. adminName .. " persistently muted " .. target_ply:Nick() .. " " .. timeStr .. ". Reason: " .. reason .. "\n")
end

local pmute = ulx.command(CATEGORY, "ulx pmute", ulx.pmute, "!pmute")
pmute:addParam{type = ULib.cmds.PlayerArg}
pmute:addParam{type = ULib.cmds.NumArg, min = 0, default = 0, hint = "minutes (0=permanent)", ULib.cmds.round}
pmute:addParam{type = ULib.cmds.StringArg, hint = "reason", ULib.cmds.takeRestOfLine}
pmute:defaultAccess(ULib.ACCESS_ADMIN)
pmute:help("Persistently mute a player (survives reconnect).")

-- =============================================================================
-- !unpmute - Remove Persistent Mute
-- =============================================================================

function ulx.unpmute(calling_ply, target_ply)
    if not PPunish or not PPunish.Config.Enabled then
        ULib.tsayError(calling_ply, "Persistent Punishments is not enabled.")
        return
    end

    local sid = target_ply:SteamID64()

    if not PPunish.HasActivePunishment(sid, "mute") then
        ULib.tsayError(calling_ply, target_ply:Nick() .. " does not have a persistent mute.")
        return
    end

    PPunish.RemovePunishmentByType(sid, "mute")
    PPunish.LiftPunishment(target_ply, "mute")

    ULib.tsayColor(target_ply, false,
        PPunish.Colors.Removed, "[Persistent Punishment] ",
        PPunish.Colors.Reason, "Your persistent mute has been removed."
    )

    ServerLog("[Persistent Punishments] " .. (IsValid(calling_ply) and calling_ply:Nick() or "Console") .. " removed persistent mute from " .. target_ply:Nick() .. ".\n")
end

local unpmute = ulx.command(CATEGORY, "ulx unpmute", ulx.unpmute, "!unpmute")
unpmute:addParam{type = ULib.cmds.PlayerArg}
unpmute:defaultAccess(ULib.ACCESS_ADMIN)
unpmute:help("Remove a persistent mute from a player.")

-- =============================================================================
-- !pfreeze - Persistent Freeze
-- =============================================================================

function ulx.pfreeze(calling_ply, target_ply, minutes, reason)
    if not PPunish or not PPunish.Config.Enabled then
        ULib.tsayError(calling_ply, "Persistent Punishments is not enabled.")
        return
    end

    local sid = target_ply:SteamID64()

    if PPunish.HasActivePunishment(sid, "freeze") then
        ULib.tsayError(calling_ply, target_ply:Nick() .. " already has a persistent freeze. Use !unpfreeze first.")
        return
    end

    local exclusive = ulx.getExclusive(target_ply, calling_ply)
    if exclusive then
        ULib.tsayError(calling_ply, exclusive)
        return
    end

    local adminSid = IsValid(calling_ply) and calling_ply:SteamID64() or "CONSOLE"
    local adminName = IsValid(calling_ply) and calling_ply:Nick() or "Console"

    local id = PPunish.AddPunishment(sid, target_ply:Nick(), "freeze", reason, adminSid, adminName, minutes, nil)
    PPunish.CallULXSilent(ulx.freeze, calling_ply, {target_ply}, false)

    local records = PPunish.GetActivePunishments(sid)
    PPunish.NotifyPlayer(target_ply, records)

    local record = id and PPunish.GetPunishmentByID(id)
    if record then PPunish.NotifyCallingAdmin(calling_ply, target_ply, record) end

    local timeStr = minutes > 0 and (minutes .. " minute(s)") or "permanently"
    ServerLog("[Persistent Punishments] " .. adminName .. " persistently froze " .. target_ply:Nick() .. " " .. timeStr .. ". Reason: " .. reason .. "\n")
end

local pfreeze = ulx.command(CATEGORY, "ulx pfreeze", ulx.pfreeze, "!pfreeze")
pfreeze:addParam{type = ULib.cmds.PlayerArg}
pfreeze:addParam{type = ULib.cmds.NumArg, min = 0, default = 0, hint = "minutes (0=permanent)", ULib.cmds.round}
pfreeze:addParam{type = ULib.cmds.StringArg, hint = "reason", ULib.cmds.takeRestOfLine}
pfreeze:defaultAccess(ULib.ACCESS_ADMIN)
pfreeze:help("Persistently freeze a player (survives reconnect).")

-- =============================================================================
-- !unpfreeze - Remove Persistent Freeze
-- =============================================================================

function ulx.unpfreeze(calling_ply, target_ply)
    if not PPunish or not PPunish.Config.Enabled then
        ULib.tsayError(calling_ply, "Persistent Punishments is not enabled.")
        return
    end

    local sid = target_ply:SteamID64()

    if not PPunish.HasActivePunishment(sid, "freeze") then
        ULib.tsayError(calling_ply, target_ply:Nick() .. " does not have a persistent freeze.")
        return
    end

    PPunish.RemovePunishmentByType(sid, "freeze")
    PPunish.LiftPunishment(target_ply, "freeze")

    ULib.tsayColor(target_ply, false,
        PPunish.Colors.Removed, "[Persistent Punishment] ",
        PPunish.Colors.Reason, "Your persistent freeze has been removed."
    )

    ServerLog("[Persistent Punishments] " .. (IsValid(calling_ply) and calling_ply:Nick() or "Console") .. " removed persistent freeze from " .. target_ply:Nick() .. ".\n")
end

local unpfreeze = ulx.command(CATEGORY, "ulx unpfreeze", ulx.unpfreeze, "!unpfreeze")
unpfreeze:addParam{type = ULib.cmds.PlayerArg}
unpfreeze:defaultAccess(ULib.ACCESS_ADMIN)
unpfreeze:help("Remove a persistent freeze from a player.")

-- =============================================================================
-- !pjail - Persistent Jail
-- =============================================================================

function ulx.pjail(calling_ply, target_ply, minutes, reason)
    if not PPunish or not PPunish.Config.Enabled then
        ULib.tsayError(calling_ply, "Persistent Punishments is not enabled.")
        return
    end

    local sid = target_ply:SteamID64()

    if PPunish.HasActivePunishment(sid, "jail") then
        ULib.tsayError(calling_ply, target_ply:Nick() .. " already has a persistent jail. Use !unpjail first.")
        return
    end

    local exclusive = ulx.getExclusive(target_ply, calling_ply)
    if exclusive then
        ULib.tsayError(calling_ply, exclusive)
        return
    end

    local adminSid = IsValid(calling_ply) and calling_ply:SteamID64() or "CONSOLE"
    local adminName = IsValid(calling_ply) and calling_ply:Nick() or "Console"
    local jailPos = target_ply:GetPos()

    local id = PPunish.AddPunishment(sid, target_ply:Nick(), "jail", reason, adminSid, adminName, minutes, jailPos)

    -- ULX jail uses seconds, but our DB stores in minutes for the admin interface
    -- Pass 0 for permanent jail (ULX treats 0 as no auto-unjail)
    local jailSeconds = 0
    if minutes > 0 then
        jailSeconds = minutes * 60
    end
    PPunish.CallULXSilent(ulx.jail, calling_ply, {target_ply}, jailSeconds, false)

    local records = PPunish.GetActivePunishments(sid)
    PPunish.NotifyPlayer(target_ply, records)

    local record = id and PPunish.GetPunishmentByID(id)
    if record then PPunish.NotifyCallingAdmin(calling_ply, target_ply, record) end

    local timeStr = minutes > 0 and (minutes .. " minute(s)") or "permanently"
    ServerLog("[Persistent Punishments] " .. adminName .. " persistently jailed " .. target_ply:Nick() .. " " .. timeStr .. ". Reason: " .. reason .. "\n")
end

local pjail = ulx.command(CATEGORY, "ulx pjail", ulx.pjail, "!pjail")
pjail:addParam{type = ULib.cmds.PlayerArg}
pjail:addParam{type = ULib.cmds.NumArg, min = 0, default = 0, hint = "minutes (0=permanent)", ULib.cmds.round}
pjail:addParam{type = ULib.cmds.StringArg, hint = "reason", ULib.cmds.takeRestOfLine}
pjail:defaultAccess(ULib.ACCESS_ADMIN)
pjail:help("Persistently jail a player (survives reconnect).")

-- =============================================================================
-- !unpjail - Remove Persistent Jail
-- =============================================================================

function ulx.unpjail(calling_ply, target_ply)
    if not PPunish or not PPunish.Config.Enabled then
        ULib.tsayError(calling_ply, "Persistent Punishments is not enabled.")
        return
    end

    local sid = target_ply:SteamID64()

    if not PPunish.HasActivePunishment(sid, "jail") then
        ULib.tsayError(calling_ply, target_ply:Nick() .. " does not have a persistent jail.")
        return
    end

    PPunish.RemovePunishmentByType(sid, "jail")
    PPunish.LiftPunishment(target_ply, "jail")

    ULib.tsayColor(target_ply, false,
        PPunish.Colors.Removed, "[Persistent Punishment] ",
        PPunish.Colors.Reason, "Your persistent jail has been removed."
    )

    ServerLog("[Persistent Punishments] " .. (IsValid(calling_ply) and calling_ply:Nick() or "Console") .. " removed persistent jail from " .. target_ply:Nick() .. ".\n")
end

local unpjail = ulx.command(CATEGORY, "ulx unpjail", ulx.unpjail, "!unpjail")
unpjail:addParam{type = ULib.cmds.PlayerArg}
unpjail:defaultAccess(ULib.ACCESS_ADMIN)
unpjail:help("Remove a persistent jail from a player.")

-- =============================================================================
-- !ppunishments - View active persistent punishments on a player
-- =============================================================================

function ulx.ppunishments(calling_ply, target_ply)
    if not PPunish then
        ULib.tsayError(calling_ply, "Persistent Punishments is not loaded.")
        return
    end

    local sid = target_ply:SteamID64()
    local records = PPunish.GetActivePunishments(sid)

    if #records == 0 then
        ULib.tsayColor(calling_ply, false,
            PPunish.Colors.Header, "[Persistent Punishment] ",
            PPunish.Colors.Reason, target_ply:Nick() .. " has no active persistent punishments."
        )
        return
    end

    ULib.tsayColor(calling_ply, false,
        PPunish.Colors.Header, "[Persistent Punishment] ",
        PPunish.Colors.Reason, target_ply:Nick() .. " has " .. #records .. " active punishment(s):"
    )

    for _, record in ipairs(records) do
        local typeName = PPunish.TYPES[record.punishment_type] or record.punishment_type
        local timeStr = FormatTimeRemaining(record.expires_at)
        local reason = record.reason ~= "" and record.reason or "No reason given"

        ULib.tsayColor(calling_ply, false,
            PPunish.Colors.Type, "  " .. typeName,
            PPunish.Colors.Reason, " — " .. reason,
            PPunish.Colors.Duration, " — " .. timeStr,
            PPunish.Colors.Admin, " (by " .. record.admin_name .. ")"
        )
    end
end

local ppunishments = ulx.command(CATEGORY, "ulx ppunishments", ulx.ppunishments, "!ppunishments")
ppunishments:addParam{type = ULib.cmds.PlayerArg}
ppunishments:defaultAccess(ULib.ACCESS_ADMIN)
ppunishments:help("View active persistent punishments on a player.")

-- =============================================================================
-- STEAMID-BASED COMMANDS (offline punishment)
-- =============================================================================

-- Helper: validate SteamID and convert to SteamID64
local function ValidateSteamID(calling_ply, steamid)
    steamid = steamid:upper()
    if not ULib.isValidSteamID(steamid) then
        ULib.tsayError(calling_ply, "Invalid SteamID: " .. steamid)
        return nil, nil
    end
    local sid64 = util.SteamIDTo64(steamid)
    return steamid, sid64
end

-- Helper: get the name of a player by SteamID (online or from DB)
local function GetNameForSteamID(steamid, sid64)
    -- Check if player is online
    for _, ply in ipairs(player.GetAll()) do
        if ply:SteamID() == steamid then
            return ply:Nick(), ply
        end
    end
    -- Check if we have a name in our DB from a previous punishment
    local records = PPunish.GetActivePunishments(sid64)
    if #records > 0 then
        return records[1].player_name, nil
    end
    return steamid, nil -- Fall back to SteamID as name
end

-- =============================================================================
-- !pgagid / !pmuteid / !pfreezeid / !pjailid
-- =============================================================================

-- Generic function for SteamID-based punishment
local function ApplyPunishmentByID(calling_ply, steamid, minutes, reason, punishType)
    if not PPunish or not PPunish.Config.Enabled then
        ULib.tsayError(calling_ply, "Persistent Punishments is not enabled.")
        return
    end

    local validSteamID, sid64 = ValidateSteamID(calling_ply, steamid)
    if not validSteamID then return end

    if PPunish.HasActivePunishment(sid64, punishType) then
        ULib.tsayError(calling_ply, validSteamID .. " already has a persistent " .. punishType .. ". Use !unp" .. punishType .. "id first.")
        return
    end

    local adminSid = IsValid(calling_ply) and calling_ply:SteamID64() or "CONSOLE"
    local adminName = IsValid(calling_ply) and calling_ply:Nick() or "Console"
    local playerName, onlinePly = GetNameForSteamID(validSteamID, sid64)

    -- For jail, use spawn point if offline (no player position available)
    local jailPos = nil
    if punishType == "jail" then
        if IsValid(onlinePly) then
            jailPos = onlinePly:GetPos()
        end
        -- If offline, jailPos stays nil — sv_core will use a spawn point on join
    end

    local id = PPunish.AddPunishment(sid64, playerName, punishType, reason, adminSid, adminName, minutes, jailPos)

    -- If player is online, apply immediately via ULX
    if IsValid(onlinePly) then
        if punishType == "gag" then
            PPunish.CallULXSilent(ulx.gag, calling_ply, {onlinePly}, false)
        elseif punishType == "mute" then
            PPunish.CallULXSilent(ulx.mute, calling_ply, {onlinePly}, false)
        elseif punishType == "freeze" then
            local exclusive = ulx.getExclusive(onlinePly, calling_ply)
            if not exclusive then
                PPunish.CallULXSilent(ulx.freeze, calling_ply, {onlinePly}, false)
            end
        elseif punishType == "jail" then
            local exclusive = ulx.getExclusive(onlinePly, calling_ply)
            if not exclusive then
                local jailSeconds = minutes > 0 and (minutes * 60) or 0
                PPunish.CallULXSilent(ulx.jail, calling_ply, {onlinePly}, jailSeconds, false)
            end
        end

        local records = PPunish.GetActivePunishments(sid64)
        PPunish.NotifyPlayer(onlinePly, records)
    end

    -- Notify the admin who applied the punishment
    local record = id and PPunish.GetPunishmentByID(id)
    if record and IsValid(onlinePly) then
        PPunish.NotifyCallingAdmin(calling_ply, onlinePly, record)
    elseif record and IsValid(calling_ply) then
        -- Player is offline, still notify admin
        local typeName2 = PPunish.TYPES[punishType] or punishType
        local timeStr2 = minutes > 0 and (minutes .. " minute(s)") or "Permanent"
        ULib.tsayColor(calling_ply, false,
            PPunish.Colors.Header, "[Persistent Punishment] ",
            PPunish.Colors.Type, typeName2,
            PPunish.Colors.Reason, " queued for " .. playerName .. " (" .. validSteamID .. ")",
            PPunish.Colors.Duration, " — Expires: " .. timeStr2
        )
    end

    local typeName = PPunish.TYPES[punishType] or punishType
    local timeStr = minutes > 0 and (minutes .. " minute(s)") or "permanently"
    local status = IsValid(onlinePly) and " (applied now)" or " (will apply on join)"
    ServerLog("[Persistent Punishments] " .. adminName .. " persistently applied " .. typeName .. " to " .. playerName .. " (" .. validSteamID .. ") " .. timeStr .. ". Reason: " .. reason .. status .. "\n")
end

function ulx.pgagid(calling_ply, steamid, minutes, reason)
    ApplyPunishmentByID(calling_ply, steamid, minutes, reason, "gag")
end
local pgagid = ulx.command(CATEGORY, "ulx pgagid", ulx.pgagid, "!pgagid")
pgagid:addParam{type = ULib.cmds.StringArg, hint = "steamid"}
pgagid:addParam{type = ULib.cmds.NumArg, min = 0, default = 0, hint = "minutes (0=permanent)", ULib.cmds.round}
pgagid:addParam{type = ULib.cmds.StringArg, hint = "reason", ULib.cmds.takeRestOfLine}
pgagid:defaultAccess(ULib.ACCESS_ADMIN)
pgagid:help("Persistently gag a player by SteamID (works offline).")

function ulx.pmuteid(calling_ply, steamid, minutes, reason)
    ApplyPunishmentByID(calling_ply, steamid, minutes, reason, "mute")
end
local pmuteid = ulx.command(CATEGORY, "ulx pmuteid", ulx.pmuteid, "!pmuteid")
pmuteid:addParam{type = ULib.cmds.StringArg, hint = "steamid"}
pmuteid:addParam{type = ULib.cmds.NumArg, min = 0, default = 0, hint = "minutes (0=permanent)", ULib.cmds.round}
pmuteid:addParam{type = ULib.cmds.StringArg, hint = "reason", ULib.cmds.takeRestOfLine}
pmuteid:defaultAccess(ULib.ACCESS_ADMIN)
pmuteid:help("Persistently mute a player by SteamID (works offline).")

function ulx.pfreezeid(calling_ply, steamid, minutes, reason)
    ApplyPunishmentByID(calling_ply, steamid, minutes, reason, "freeze")
end
local pfreezeid = ulx.command(CATEGORY, "ulx pfreezeid", ulx.pfreezeid, "!pfreezeid")
pfreezeid:addParam{type = ULib.cmds.StringArg, hint = "steamid"}
pfreezeid:addParam{type = ULib.cmds.NumArg, min = 0, default = 0, hint = "minutes (0=permanent)", ULib.cmds.round}
pfreezeid:addParam{type = ULib.cmds.StringArg, hint = "reason", ULib.cmds.takeRestOfLine}
pfreezeid:defaultAccess(ULib.ACCESS_ADMIN)
pfreezeid:help("Persistently freeze a player by SteamID (works offline).")

function ulx.pjailid(calling_ply, steamid, minutes, reason)
    ApplyPunishmentByID(calling_ply, steamid, minutes, reason, "jail")
end
local pjailid = ulx.command(CATEGORY, "ulx pjailid", ulx.pjailid, "!pjailid")
pjailid:addParam{type = ULib.cmds.StringArg, hint = "steamid"}
pjailid:addParam{type = ULib.cmds.NumArg, min = 0, default = 0, hint = "minutes (0=permanent)", ULib.cmds.round}
pjailid:addParam{type = ULib.cmds.StringArg, hint = "reason", ULib.cmds.takeRestOfLine}
pjailid:defaultAccess(ULib.ACCESS_ADMIN)
pjailid:help("Persistently jail a player by SteamID (works offline, jails at spawn).")

-- =============================================================================
-- !unpgagid / !unpmuteid / !unpfreezeid / !unpjailid
-- =============================================================================

local function RemovePunishmentByID(calling_ply, steamid, punishType)
    if not PPunish or not PPunish.Config.Enabled then
        ULib.tsayError(calling_ply, "Persistent Punishments is not enabled.")
        return
    end

    local validSteamID, sid64 = ValidateSteamID(calling_ply, steamid)
    if not validSteamID then return end

    if not PPunish.HasActivePunishment(sid64, punishType) then
        ULib.tsayError(calling_ply, validSteamID .. " does not have a persistent " .. punishType .. ".")
        return
    end

    local playerName, onlinePly = GetNameForSteamID(validSteamID, sid64)

    PPunish.RemovePunishmentByType(sid64, punishType)

    if IsValid(onlinePly) then
        PPunish.LiftPunishment(onlinePly, punishType)
        ULib.tsayColor(onlinePly, false,
            PPunish.Colors.Removed, "[Persistent Punishment] ",
            PPunish.Colors.Reason, "Your persistent " .. punishType .. " has been removed."
        )
    end

    local typeName = PPunish.TYPES[punishType] or punishType
    ServerLog("[Persistent Punishments] " .. (IsValid(calling_ply) and calling_ply:Nick() or "Console") .. " removed persistent " .. typeName .. " from " .. playerName .. " (" .. validSteamID .. ").\n")
end

function ulx.unpgagid(calling_ply, steamid)
    RemovePunishmentByID(calling_ply, steamid, "gag")
end
local unpgagid = ulx.command(CATEGORY, "ulx unpgagid", ulx.unpgagid, "!unpgagid")
unpgagid:addParam{type = ULib.cmds.StringArg, hint = "steamid"}
unpgagid:defaultAccess(ULib.ACCESS_ADMIN)
unpgagid:help("Remove a persistent gag by SteamID.")

function ulx.unpmuteid(calling_ply, steamid)
    RemovePunishmentByID(calling_ply, steamid, "mute")
end
local unpmuteid = ulx.command(CATEGORY, "ulx unpmuteid", ulx.unpmuteid, "!unpmuteid")
unpmuteid:addParam{type = ULib.cmds.StringArg, hint = "steamid"}
unpmuteid:defaultAccess(ULib.ACCESS_ADMIN)
unpmuteid:help("Remove a persistent mute by SteamID.")

function ulx.unpfreezeid(calling_ply, steamid)
    RemovePunishmentByID(calling_ply, steamid, "freeze")
end
local unpfreezeid = ulx.command(CATEGORY, "ulx unpfreezeid", ulx.unpfreezeid, "!unpfreezeid")
unpfreezeid:addParam{type = ULib.cmds.StringArg, hint = "steamid"}
unpfreezeid:defaultAccess(ULib.ACCESS_ADMIN)
unpfreezeid:help("Remove a persistent freeze by SteamID.")

function ulx.unpjailid(calling_ply, steamid)
    RemovePunishmentByID(calling_ply, steamid, "jail")
end
local unpjailid = ulx.command(CATEGORY, "ulx unpjailid", ulx.unpjailid, "!unpjailid")
unpjailid:addParam{type = ULib.cmds.StringArg, hint = "steamid"}
unpjailid:defaultAccess(ULib.ACCESS_ADMIN)
unpjailid:help("Remove a persistent jail by SteamID.")
