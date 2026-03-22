-- =============================================================================
--  PVP Leaderboard - Database & Cache Management
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  SQLite storage via GMod's built-in sql.* library (sv.db).
--  Maintains an in-memory cache of the top N players for fast entity rendering.
--  Handles net sync to clients and admin config changes from XGUI.
-- =============================================================================

PVPLeaderboard = PVPLeaderboard or {}

-- =============================================================================
-- NETWORKING
-- =============================================================================

-- Cache broadcast: sends the full top-N leaderboard to clients
util.AddNetworkString("PVPLeaderboard_SyncCache")

-- Client request: player asks for the current cache (on join, entity spawn)
util.AddNetworkString("PVPLeaderboard_RequestSync")

-- Open leaderboard panel: signals a client to open the VGUI leaderboard
util.AddNetworkString("PVPLeaderboard_OpenBoard")

-- Individual stats: server sends one player's full stats (for !pvpstats)
util.AddNetworkString("PVPLeaderboard_PlayerStats")

-- Config change: XGUI panel sends a ConVar update to the server
util.AddNetworkString("PVPLeaderboard_ConfigChange")

-- =============================================================================
-- ENTITY PHYSICS
-- =============================================================================

-- Leaderboard sign classes that use frozen physics for stable placement.
local SIGN_CLASSES = {
	pvp_leaderboard = true,
}

-- Re-freeze leaderboard signs after physgun placement.
-- The backing plate model wants to settle flat; freezing prevents that.
hook.Add("PhysgunDrop", "PVPLeaderboard_FreezeOnDrop", function(ply, ent)
	if not SIGN_CLASSES[ent:GetClass()] then return end

	local phys = ent:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
	end
end)

-- =============================================================================
-- DATABASE SCHEMA
-- =============================================================================

-- Table name prefixed to avoid namespace collisions with other addons.
local TABLE_NAME = "pvp_leaderboard_stats"

-- Create the stats table if it does not already exist.
-- One row per unique player, keyed by SteamID64.
local function InitDatabase()
	local query = string.format([[
		CREATE TABLE IF NOT EXISTS %s (
			steamid64 TEXT PRIMARY KEY,
			name TEXT NOT NULL DEFAULT 'Unknown',
			kills INTEGER NOT NULL DEFAULT 0,
			deaths INTEGER NOT NULL DEFAULT 0,
			current_streak INTEGER NOT NULL DEFAULT 0,
			best_streak INTEGER NOT NULL DEFAULT 0,
			headshots INTEGER NOT NULL DEFAULT 0
		)
	]], TABLE_NAME)

	local result = sql.Query(query)
	if result == false then
		ServerLog("[PVP Leaderboard] ERROR: Failed to create database table: " .. (sql.LastError() or "unknown") .. "\n")
	else
		ServerLog("[PVP Leaderboard] Database table initialized.\n")
	end
end

-- Run schema creation immediately on load
InitDatabase()

-- =============================================================================
-- CRUD OPERATIONS
-- =============================================================================

--- Fetch a single player's stats from the database.
-- @param steamid64 string - the player's SteamID64
-- @return table with kills, deaths, current_streak, best_streak, headshots, name
--         or nil if the player has no record
function PVPLeaderboard.GetPlayerStats(steamid64)
	local query = string.format(
		"SELECT * FROM %s WHERE steamid64 = %s",
		TABLE_NAME, sql.SQLStr(steamid64)
	)

	local result = sql.Query(query)
	if not result or #result == 0 then return nil end

	local row = result[1]
	return {
		steamid64      = row.steamid64,
		name           = row.name,
		kills          = tonumber(row.kills) or 0,
		deaths         = tonumber(row.deaths) or 0,
		current_streak = tonumber(row.current_streak) or 0,
		best_streak    = tonumber(row.best_streak) or 0,
		headshots      = tonumber(row.headshots) or 0,
	}
end

--- Ensure a player has a row in the database. Creates one if missing.
-- Also updates the stored display name to keep it current.
-- @param ply Player entity
function PVPLeaderboard.EnsurePlayer(ply)
	local sid = ply:SteamID64()
	local name = ply:Nick()
	local existing = PVPLeaderboard.GetPlayerStats(sid)

	if existing then
		-- Update stored name if it changed since last recorded event
		if existing.name ~= name then
			sql.Query(string.format(
				"UPDATE %s SET name = %s WHERE steamid64 = %s",
				TABLE_NAME, sql.SQLStr(name), sql.SQLStr(sid)
			))
		end
	else
		-- First time this player has been involved in a PVP event
		sql.Query(string.format(
			"INSERT INTO %s (steamid64, name) VALUES (%s, %s)",
			TABLE_NAME, sql.SQLStr(sid), sql.SQLStr(name)
		))
	end
end

--- Record a kill for the attacker. Increments kills, updates streak
-- and best streak, and optionally increments headshots.
-- @param ply Player entity (the attacker)
-- @param isHeadshot boolean - whether this kill was a headshot
function PVPLeaderboard.RecordKill(ply, isHeadshot)
	local sid = ply:SteamID64()
	PVPLeaderboard.EnsurePlayer(ply)

	local stats = PVPLeaderboard.GetPlayerStats(sid)
	if not stats then return end

	local newKills = stats.kills + 1
	local newStreak = stats.current_streak + 1
	local newBestStreak = math.max(stats.best_streak, newStreak)
	local newHeadshots = stats.headshots + (isHeadshot and 1 or 0)

	sql.Query(string.format(
		"UPDATE %s SET kills = %d, current_streak = %d, best_streak = %d, headshots = %d, name = %s WHERE steamid64 = %s",
		TABLE_NAME, newKills, newStreak, newBestStreak, newHeadshots,
		sql.SQLStr(ply:Nick()), sql.SQLStr(sid)
	))
end

--- Record a death for the victim. Increments deaths and resets current streak.
-- @param ply Player entity (the victim)
function PVPLeaderboard.RecordDeath(ply)
	local sid = ply:SteamID64()
	PVPLeaderboard.EnsurePlayer(ply)

	sql.Query(string.format(
		"UPDATE %s SET deaths = deaths + 1, current_streak = 0, name = %s WHERE steamid64 = %s",
		TABLE_NAME, sql.SQLStr(ply:Nick()), sql.SQLStr(sid)
	))
end

--- Reset a single player's stats to zero.
-- @param steamid64 string - the player's SteamID64
function PVPLeaderboard.ResetPlayerStats(steamid64)
	sql.Query(string.format(
		"UPDATE %s SET kills = 0, deaths = 0, current_streak = 0, best_streak = 0, headshots = 0 WHERE steamid64 = %s",
		TABLE_NAME, sql.SQLStr(steamid64)
	))
end

--- Wipe the entire leaderboard (delete all rows).
function PVPLeaderboard.ResetAllStats()
	sql.Query(string.format("DELETE FROM %s", TABLE_NAME))
end

-- =============================================================================
-- CACHE MANAGEMENT
-- =============================================================================

-- The in-memory cache holds the top N players sorted by kills (descending).
-- Entities never query the database directly; they read from this cache
-- delivered to clients via net messages.
PVPLeaderboard.CachedBoard = PVPLeaderboard.CachedBoard or {}

--- Rebuild the cache from the database. Reads the top N rows sorted by
-- kills descending, with best streak and headshots as tiebreakers.
function PVPLeaderboard.RefreshCache()
	local maxEntries = PVPLeaderboard.Config.MaxEntries or 10

	local query = string.format(
		"SELECT * FROM %s ORDER BY kills DESC, best_streak DESC, headshots DESC LIMIT %d",
		TABLE_NAME, maxEntries
	)

	local result = sql.Query(query)
	local board = {}

	if result then
		for i, row in ipairs(result) do
			local kills = tonumber(row.kills) or 0
			local deaths = tonumber(row.deaths) or 0

			board[i] = {
				steamid64      = row.steamid64,
				name           = row.name,
				kills          = kills,
				deaths         = deaths,
				kd             = deaths > 0 and math.Round(kills / deaths, 2) or kills,
				current_streak = tonumber(row.current_streak) or 0,
				best_streak    = tonumber(row.best_streak) or 0,
				headshots      = tonumber(row.headshots) or 0,
			}
		end
	end

	PVPLeaderboard.CachedBoard = board
end

-- =============================================================================
-- NET SYNC: SERVER -> CLIENT
-- =============================================================================

--- Send the cached leaderboard to a specific player, or broadcast to all.
-- @param target Player entity (optional) - if nil, broadcasts to everyone
function PVPLeaderboard.SendCache(target)
	local board = PVPLeaderboard.CachedBoard

	net.Start("PVPLeaderboard_SyncCache")
		net.WriteUInt(#board, 8)
		for _, entry in ipairs(board) do
			net.WriteString(entry.name)
			net.WriteUInt(entry.kills, 16)
			net.WriteUInt(entry.deaths, 16)
			net.WriteUInt(entry.current_streak, 16)
			net.WriteUInt(entry.best_streak, 16)
			net.WriteUInt(entry.headshots, 16)
			net.WriteString(entry.steamid64)
		end
	if target then
		net.Send(target)
	else
		net.Broadcast()
	end
end

--- Send a specific player's full stats to a requesting client.
-- Used for the !pvpstats command response.
-- @param target Player entity - the client to receive the stats
-- @param stats table - the player stats table from GetPlayerStats
function PVPLeaderboard.SendPlayerStats(target, stats)
	net.Start("PVPLeaderboard_PlayerStats")
		net.WriteString(stats.name)
		net.WriteUInt(stats.kills, 16)
		net.WriteUInt(stats.deaths, 16)
		net.WriteUInt(stats.current_streak, 16)
		net.WriteUInt(stats.best_streak, 16)
		net.WriteUInt(stats.headshots, 16)
	net.Send(target)
end

--- Refresh cache and broadcast the updated leaderboard to all connected clients.
-- Called after every kill event and on the periodic timer.
function PVPLeaderboard.RefreshAndBroadcast()
	PVPLeaderboard.RefreshCache()
	PVPLeaderboard.SendCache()
end

-- =============================================================================
-- CLIENT SYNC REQUEST (rate-limited)
-- =============================================================================

-- Per-player cooldown to prevent request spam
local REQUEST_COOLDOWN = 5
local lastRequest = {}

net.Receive("PVPLeaderboard_RequestSync", function(len, ply)
	if not IsValid(ply) then return end

	-- Rate limit: one request per player every 5 seconds
	local sid = ply:SteamID()
	local now = CurTime()
	if (lastRequest[sid] or 0) + REQUEST_COOLDOWN > now then return end
	lastRequest[sid] = now

	PVPLeaderboard.SendCache(ply)
end)

-- Clean up rate limit tracking on disconnect
hook.Add("PlayerDisconnected", "PVPLeaderboard_CleanupRequest", function(ply)
	if ply:IsBot() then return end
	lastRequest[ply:SteamID()] = nil
end)

-- =============================================================================
-- ADMIN CONFIG CHANGES (from XGUI panel)
-- =============================================================================

-- Whitelist of ConVars that admins can change via XGUI.
-- Values: the minimum rank required to change each ConVar.
local allowedConVars = {
	["pvplb_enabled"]        = "superadmin",
	["pvplb_max_entries"]    = "superadmin",
	["pvplb_cache_interval"] = "superadmin",
	["pvplb_sort_interval"]  = "superadmin",
}

net.Receive("PVPLeaderboard_ConfigChange", function(len, ply)
	if not IsValid(ply) then return end

	local cvarName = net.ReadString()
	local cvarValue = net.ReadString()

	-- Reject unknown ConVars silently
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

	RunConsoleCommand(cvarName, cvarValue)
	ServerLog(string.format("[PVP Leaderboard] %s changed %s to: %s\n", ply:Nick(), cvarName, cvarValue))
end)

-- =============================================================================
-- INITIALIZATION & PERIODIC REFRESH
-- =============================================================================

-- Populate the cache immediately on server start.
-- This ensures Perm Props entities have data as soon as they spawn on map load.
hook.Add("InitPostEntity", "PVPLeaderboard_InitCache", function()
	PVPLeaderboard.RefreshCache()
	ServerLog("[PVP Leaderboard] Cache populated with " .. #PVPLeaderboard.CachedBoard .. " entries.\n")
end)

-- Send the current cache to each player when they finish loading.
-- Small delay ensures the client's net receivers are registered.
hook.Add("PlayerInitialSpawn", "PVPLeaderboard_SendOnJoin", function(ply)
	timer.Simple(2, function()
		if IsValid(ply) then
			PVPLeaderboard.SendCache(ply)
		end
	end)
end)

--- Create (or restart) the periodic cache refresh timer.
-- Called on load and whenever the cache interval ConVar changes.
local function StartCacheTimer()
	local interval = PVPLeaderboard.Config.CacheInterval or 60

	-- Remove existing timer before creating a new one
	if timer.Exists("PVPLeaderboard_CacheRefresh") then
		timer.Remove("PVPLeaderboard_CacheRefresh")
	end

	timer.Create("PVPLeaderboard_CacheRefresh", interval, 0, function()
		PVPLeaderboard.RefreshAndBroadcast()
	end)
end

-- Start the periodic timer on load
StartCacheTimer()

-- Restart the timer when the cache interval ConVar changes
cvars.AddChangeCallback("pvplb_cache_interval", function()
	timer.Simple(0, StartCacheTimer)
end, "pvplb_cache_timer")

-- Re-query the database when max_entries changes (cache size changed)
cvars.AddChangeCallback("pvplb_max_entries", function()
	timer.Simple(0, function()
		PVPLeaderboard.RefreshAndBroadcast()
	end)
end, "pvplb_cache_entries")
