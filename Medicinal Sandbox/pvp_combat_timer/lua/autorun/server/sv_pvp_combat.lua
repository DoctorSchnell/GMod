-- =============================================================================
--  PVP Combat Timer - Server Core
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Combat detection, spawn/pickup restriction, and config sync.
-- =============================================================================

PVPCombat = PVPCombat or {}

-- =============================================================================
-- NETWORKING
-- =============================================================================

util.AddNetworkString("PVPCombat_ConfigChange")
util.AddNetworkString("PVPCombat_DenyNotify")
util.AddNetworkString("PVPCombat_PickupDeny")

-- =============================================================================
-- DENY NOTIFICATION RATE LIMITING
-- =============================================================================

-- Per-player cooldown for deny messages. Shared across spawn and pickup
-- denies to prevent chat flood from any combination of blocked actions.
local DENY_NOTIFY_COOLDOWN = 3
local lastDenyNotify = {}

--- Send a deny notification if the per-player cooldown has elapsed.
-- @param ply Player to notify
-- @param netMsg string - net message name to send
-- @param class string - entity class that was blocked
-- @return boolean - true if notification was sent
local function SendDenyNotify(ply, netMsg, class)
	local sid = ply:SteamID()
	local now = CurTime()
	local last = lastDenyNotify[sid] or 0

	if (now - last) < DENY_NOTIFY_COOLDOWN then return false end
	lastDenyNotify[sid] = now

	local remaining = math.ceil(PVPCombat.GetTimeRemaining(ply))
	net.Start(netMsg)
		net.WriteString(class)
		net.WriteUInt(remaining, 8)
	net.Send(ply)

	return true
end

-- =============================================================================
-- COMBAT DETECTION
-- =============================================================================

--- Tag an attacker as in-combat.
-- Skips the NWFloat write if the existing expiry is close to the new one,
-- avoiding redundant network updates under rapid/multi-hit weapons
-- (shotguns, explosions, ACF bursts).
local function TagAttacker(attacker)
	local now = CurTime()
	local expiresAt = now + PVPCombat.Config.Cooldown
	local current = attacker:GetNWFloat(PVPCombat.NW_KEY, 0)

	-- If already tagged and the new expiry is within 0.5s of current, skip the write
	if current > now and (expiresAt - current) < 0.5 then return end

	attacker:SetNWFloat(PVPCombat.NW_KEY, expiresAt)
end

--- Check if a player is in buildmode (compatible with Buildmode-ULX / kythre)
local function IsInBuildmode(ply)
	return ply:GetNWBool("BuildMode", false) or ply.InBuildMode == true
end

hook.Add("EntityTakeDamage", "PVPCombat_DetectCombat", function(target, dmginfo)
	if not PVPCombat.Config.Enabled then return end

	local attacker = dmginfo:GetAttacker()

	-- Trace indirect damage to the owning player (vehicles, CPPI props)
	if IsValid(attacker) and not attacker:IsPlayer() then
		if attacker.CPPIGetOwner then
			attacker = attacker:CPPIGetOwner() or attacker
		end
		if IsValid(attacker) and attacker:IsVehicle() then
			attacker = attacker:GetDriver()
		end
	end

	-- Bail if not player-on-player
	if not IsValid(attacker) or not attacker:IsPlayer() then return end
	if not IsValid(target) or not target:IsPlayer() then return end
	if attacker == target then return end

	-- Buildmode exemption
	if IsInBuildmode(attacker) then return end

	TagAttacker(attacker)
end)

-- =============================================================================
-- SPAWN RESTRICTION
-- =============================================================================

--- Check if a spawn should be blocked. Always blocks if matched,
-- but the chat notification is rate-limited via SendDenyNotify.
local function CheckSpawnRestriction(ply, class)
	if not PVPCombat.Config.Enabled then return end
	if not PVPCombat.IsInCombat(ply) then return end

	-- Some addons (e.g. Glide) pass a table instead of a string
	if type(class) ~= "string" then return end

	if not PVPCombat.Config.Blocklist[string.lower(class)] then return end

	SendDenyNotify(ply, "PVPCombat_DenyNotify", class)
	return false
end

hook.Add("PlayerSpawnSENT", "PVPCombat_BlockSENT", function(ply, class)
	return CheckSpawnRestriction(ply, class)
end)

hook.Add("PlayerSpawnSWEP", "PVPCombat_BlockSWEP", function(ply, class)
	return CheckSpawnRestriction(ply, class)
end)

hook.Add("PlayerSpawnVehicle", "PVPCombat_BlockVehicle", function(ply, _, _, class)
	return CheckSpawnRestriction(ply, class)
end)

-- PlayerSpawnProp doesn't provide a class. If "prop_physics" is on the
-- blocklist, all props are blocked during combat.
hook.Add("PlayerSpawnProp", "PVPCombat_BlockProp", function(ply, model)
	if not PVPCombat.Config.Enabled then return end
	if not PVPCombat.IsInCombat(ply) then return end

	if PVPCombat.Config.Blocklist["prop_physics"] then
		SendDenyNotify(ply, "PVPCombat_DenyNotify", "prop_physics")
		return false
	end
end)

-- =============================================================================
-- PICKUP RESTRICTION
-- =============================================================================

--- Block pickup of ground items during combat.
-- Uses PlayerCanPickupItem which fires when walking over HL2 items.
hook.Add("PlayerCanPickupItem", "PVPCombat_BlockPickup", function(ply, item)
	if not PVPCombat.Config.Enabled then return end
	if not PVPCombat.Config.BlockPickup then return end
	if not PVPCombat.IsInCombat(ply) then return end
	if not IsValid(item) then return end

	local class = item:GetClass()
	if not PVPCombat.Config.Blocklist[string.lower(class)] then return end

	SendDenyNotify(ply, "PVPCombat_PickupDeny", class)
	return false
end)

--- Block E-key use on blocklisted entities during combat.
-- PlayerCanPickupItem only covers HL2 walk-over items. Pressing E on
-- SENTs (e.g. sent_ball) goes through PlayerUse instead.
hook.Add("PlayerUse", "PVPCombat_BlockUse", function(ply, ent)
	if not PVPCombat.Config.Enabled then return end
	if not PVPCombat.Config.BlockPickup then return end
	if not PVPCombat.IsInCombat(ply) then return end
	if not IsValid(ent) then return end

	local class = ent:GetClass()
	if not PVPCombat.Config.Blocklist[string.lower(class)] then return end

	SendDenyNotify(ply, "PVPCombat_PickupDeny", class)
	return false
end)

-- =============================================================================
-- CLEANUP
-- =============================================================================

-- Remove deny tracking on disconnect
hook.Add("PlayerDisconnected", "PVPCombat_CleanupDisconnect", function(ply)
	if ply:IsBot() then return end
	lastDenyNotify[ply:SteamID()] = nil
end)

-- =============================================================================
-- ADMIN CONFIG CHANGES (from XGUI panel)
-- =============================================================================

-- Whitelist of ConVars that admins can change via XGUI.
-- Values: "admin" or "superadmin" -- the minimum rank required.
local allowedConVars = {
	["pvpcombat_enabled"]      = "superadmin",
	["pvpcombat_cooldown"]     = "superadmin",
	["pvpcombat_blocklist"]    = "superadmin",
	["pvpcombat_block_pickup"] = "superadmin",
}

-- Safety limits for blocklist ConVars
local MAX_BLOCKLIST_LENGTH  = 1024
local MAX_BLOCKLIST_ENTRIES = 50

local blocklistConVars = {
	["pvpcombat_blocklist"] = true,
}

net.Receive("PVPCombat_ConfigChange", function(len, ply)
	if not IsValid(ply) then return end

	local cvarName = net.ReadString()
	local cvarValue = net.ReadString()

	local requiredRank = allowedConVars[cvarName]
	if not requiredRank then return end

	-- Permission check: tier-based
	if requiredRank == "superadmin" then
		if not ply:IsSuperAdmin() then return end
	else
		if not ply:IsAdmin() then return end
	end

	local cv = GetConVar(cvarName)
	if not cv then return end

	-- Validate blocklist length and entry count
	if blocklistConVars[cvarName] then
		if string.len(cvarValue) > MAX_BLOCKLIST_LENGTH then
			ServerLog(string.format("[PVP Combat Timer] %s tried to set %s exceeding %d chars, rejected.\n",
				ply:Nick(), cvarName, MAX_BLOCKLIST_LENGTH))
			return
		end

		local count = 0
		for _ in string.gmatch(cvarValue, "([^;]+)") do count = count + 1 end
		if count > MAX_BLOCKLIST_ENTRIES then
			ServerLog(string.format("[PVP Combat Timer] %s tried to set %s with %d entries (max %d), rejected.\n",
				ply:Nick(), cvarName, count, MAX_BLOCKLIST_ENTRIES))
			return
		end
	end

	RunConsoleCommand(cvarName, cvarValue)
	ServerLog(string.format("[PVP Combat Timer] %s changed %s to: %s\n", ply:Nick(), cvarName, cvarValue))
end)

-- =============================================================================
-- CHAT COMMAND: !pvpstatus
-- =============================================================================

hook.Add("PlayerSay", "PVPCombat_ChatCommand", function(ply, text)
	local cmd = string.lower(string.Trim(text))
	if cmd ~= "!pvpstatus" then return end

	if not PVPCombat.Config.Enabled then
		ply:ChatPrint("[PVP Combat Timer] System is currently disabled.")
		return ""
	end

	if PVPCombat.IsInCombat(ply) then
		local remaining = math.ceil(PVPCombat.GetTimeRemaining(ply))
		ply:ChatPrint(string.format("[PVP Combat Timer] You are in combat! %d second%s remaining.",
			remaining, remaining == 1 and "" or "s"))
	else
		ply:ChatPrint("[PVP Combat Timer] You are not in combat. All spawning is unrestricted.")
	end

	return ""
end)
