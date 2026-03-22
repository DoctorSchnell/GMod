-- =============================================================================
--  PVP Leaderboard - ULX Commands
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  !pvpstats [player]  - View stats (all players for self, admin for others)
--  !pvpboard           - Open on-screen leaderboard panel
--  !pvpsort <mode>     - Set the sort mode for all clients (Admin)
--  !pvpreset <player>  - Reset a player's stats (SuperAdmin)
--  !pvpresetall        - Wipe the entire leaderboard (SuperAdmin)
-- =============================================================================

-- =============================================================================
-- !pvpstats [player] - View PVP stats
-- =============================================================================

function ulx.pvpstats(calling_ply, target_ply)
	-- Default to the calling player if no target specified
	if not IsValid(target_ply) then
		target_ply = calling_ply
	end

	-- Console cannot view stats (no chat output target)
	if not IsValid(calling_ply) then
		ULib.tsayError(calling_ply, "This command must be run by a player.")
		return
	end

	-- Check if tracking is enabled
	if not PVPLeaderboard or not PVPLeaderboard.Config.Enabled then
		ULib.tsayError(calling_ply, "PVP Leaderboard tracking is currently disabled.")
		return
	end

	-- Look up the target's stats from the database
	local stats = PVPLeaderboard.GetPlayerStats(target_ply:SteamID64())

	if not stats then
		-- Player has no recorded PVP events yet
		ULib.tsayError(calling_ply, target_ply:Nick() .. " has no PVP stats recorded.")
		return
	end

	-- Send the stats to the requesting player's chat via net message
	PVPLeaderboard.SendPlayerStats(calling_ply, stats)
end

local pvpstats = ulx.command("PVP Leaderboard", "ulx pvpstats", ulx.pvpstats, "!pvpstats")
pvpstats:addParam{type = ULib.cmds.PlayerArg, ULib.cmds.optional}
pvpstats:defaultAccess(ULib.ACCESS_ALL)
pvpstats:help("View a player's PVP stats (or your own if no player specified).")

-- =============================================================================
-- !pvpboard - Open the leaderboard panel on screen
-- =============================================================================

function ulx.pvpboard(calling_ply)
	if not IsValid(calling_ply) then
		ULib.tsayError(calling_ply, "This command must be run by a player.")
		return
	end

	net.Start("PVPLeaderboard_OpenBoard")
	net.Send(calling_ply)
end

local pvpboard = ulx.command("PVP Leaderboard", "ulx pvpboard", ulx.pvpboard, "!pvpboard")
pvpboard:defaultAccess(ULib.ACCESS_ALL)
pvpboard:help("Open the PVP leaderboard panel on screen.")

-- =============================================================================
-- !pvpsort <mode> - Set leaderboard sort mode for all clients
-- =============================================================================

-- Maps user-friendly names to sort mode indices (matching SORT_MODES in cl_pvp_leaderboard.lua)
local SORT_MODE_MAP = {
	kills     = 1,
	kd        = 2,
	ks        = 3,
	hs        = 4,
	streak    = 3,  -- alias
	headshots = 4,  -- alias
}

function ulx.pvpsort(calling_ply, mode)
	mode = string.lower(string.Trim(mode))

	local index = SORT_MODE_MAP[mode]
	if not index then
		local valid = "kills, kd, ks, hs"
		ULib.tsayError(calling_ply, "Invalid sort mode. Valid options: " .. valid)
		return
	end

	-- Broadcast the sort mode to all connected clients
	net.Start("PVPLeaderboard_SetSort")
		net.WriteUInt(index, 3)
	net.Broadcast()

	local labels = {"kills", "K/D", "KS", "HS"}
	ulx.fancyLogAdmin(calling_ply, "#A set the PVP leaderboard sort to #s.", labels[index])
end

local pvpsort = ulx.command("PVP Leaderboard", "ulx pvpsort", ulx.pvpsort, "!pvpsort")
pvpsort:addParam{type = ULib.cmds.StringArg, hint = "kills|kd|ks|hs"}
pvpsort:defaultAccess(ULib.ACCESS_ADMIN)
pvpsort:help("Set the leaderboard sort mode for all players.")

-- =============================================================================
-- !pvpreset <player> - Reset one player's stats
-- =============================================================================

function ulx.pvpreset(calling_ply, target_ply)
	if not IsValid(target_ply) then
		ULib.tsayError(calling_ply, "Invalid player.")
		return
	end

	if not PVPLeaderboard then
		ULib.tsayError(calling_ply, "PVP Leaderboard is not loaded.")
		return
	end

	-- Reset the target's stats in the database
	PVPLeaderboard.ResetPlayerStats(target_ply:SteamID64())

	-- Refresh the cache so the leaderboard entities update immediately
	PVPLeaderboard.RefreshAndBroadcast()

	ulx.fancyLogAdmin(calling_ply, "#A reset PVP stats for #T.", target_ply)
end

local pvpreset = ulx.command("PVP Leaderboard", "ulx pvpreset", ulx.pvpreset, "!pvpreset")
pvpreset:addParam{type = ULib.cmds.PlayerArg}
pvpreset:defaultAccess(ULib.ACCESS_SUPERADMIN)
pvpreset:help("Reset a player's PVP leaderboard stats to zero.")

-- =============================================================================
-- !pvpresetall - Wipe the entire leaderboard
-- =============================================================================

function ulx.pvpresetall(calling_ply)
	if not PVPLeaderboard then
		ULib.tsayError(calling_ply, "PVP Leaderboard is not loaded.")
		return
	end

	-- Delete all rows from the leaderboard table
	PVPLeaderboard.ResetAllStats()

	-- Refresh the cache so entities show the empty state
	PVPLeaderboard.RefreshAndBroadcast()

	ulx.fancyLogAdmin(calling_ply, "#A wiped the entire PVP leaderboard.")
end

local pvpresetall = ulx.command("PVP Leaderboard", "ulx pvpresetall", ulx.pvpresetall, "!pvpresetall")
pvpresetall:defaultAccess(ULib.ACCESS_SUPERADMIN)
pvpresetall:help("Wipe all PVP leaderboard stats. This cannot be undone.")
