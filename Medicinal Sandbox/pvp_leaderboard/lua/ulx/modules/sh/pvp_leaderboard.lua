--[[
	PVP Leaderboard - ULX Commands
	Chat commands for viewing and managing PVP leaderboard stats.
	Author: Doctor Schnell

	Commands:
		!pvpstats [player]  - View a player's stats (or your own). All players for self, admin for others.
		!pvpreset <player>  - Reset a specific player's stats. SuperAdmin only.
		!pvpresetall        - Wipe the entire leaderboard. SuperAdmin only.
]]

-------------------------------------------------
-- !pvpstats [player] - View PVP stats
-------------------------------------------------

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

-------------------------------------------------
-- !pvpreset <player> - Reset one player's stats
-------------------------------------------------

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

-------------------------------------------------
-- !pvpresetall - Wipe the entire leaderboard
-------------------------------------------------

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
