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

-- Sort override: admin sets the sort mode for all clients (!pvpsort)
util.AddNetworkString("PVPLeaderboard_SetSort")

-- =============================================================================
-- ENTITY PHYSICS
-- =============================================================================

-- Re-freeze leaderboard signs after physgun placement.
-- The backing plate model wants to settle flat; freezing prevents that.
-- PVPLeaderboard.ClassToPeriod (from the shared file) covers all four sign
-- classes (all-time + 24h/7d/30d).
hook.Add("PhysgunDrop", "PVPLeaderboard_FreezeOnDrop", function(ply, ent)
	if not PVPLeaderboard.ClassToPeriod[ent:GetClass()] then return end

	local phys = ent:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
	end
end)

-- =============================================================================
-- DATABASE SCHEMA
-- =============================================================================

-- Table names prefixed to avoid namespace collisions with other addons.
-- TABLE_NAME  - cumulative all-time aggregates (one row per player).
-- EVENTS_TABLE - append-only kill event log (one row per validated kill),
--                the source for the rolling 24h/7d/30d windowed boards.
local TABLE_NAME   = "pvp_leaderboard_stats"
local EVENTS_TABLE = "pvp_leaderboard_events"

-- Create the schema if it does not already exist.
local function InitDatabase()
	-- All-time aggregate table: one row per unique player, keyed by SteamID64.
	local statsQuery = string.format([[
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

	if sql.Query(statsQuery) == false then
		ServerLog("[PVP Leaderboard] ERROR: Failed to create stats table: " .. (sql.LastError() or "unknown") .. "\n")
	end

	-- Event log: one row per validated kill, timestamped with os.time() (Unix
	-- epoch, stable across map changes). Retained indefinitely; windowed boards
	-- only ever range-query recent rows via the ts index below, so the table can
	-- grow without degrading query cost.
	local eventsQuery = string.format([[
		CREATE TABLE IF NOT EXISTS %s (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			ts INTEGER NOT NULL,
			attacker TEXT NOT NULL,
			victim TEXT NOT NULL,
			headshot INTEGER NOT NULL DEFAULT 0
		)
	]], EVENTS_TABLE)

	if sql.Query(eventsQuery) == false then
		ServerLog("[PVP Leaderboard] ERROR: Failed to create events table: " .. (sql.LastError() or "unknown") .. "\n")
	end

	-- Index on ts so windowed boards are a bounded range scan (cost scales with
	-- the window length, not the total table size). Critical for unbounded retention.
	sql.Query(string.format("CREATE INDEX IF NOT EXISTS idx_pvplb_events_ts ON %s (ts)", EVENTS_TABLE))

	ServerLog("[PVP Leaderboard] Database tables initialized.\n")
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
-- No-op (INSERT OR IGNORE) when the row already exists; the display name is
-- refreshed by the RecordKill/RecordDeath UPDATEs, so this never needs to read
-- or update an existing row.
-- @param ply Player entity
function PVPLeaderboard.EnsurePlayer(ply)
	sql.Query(string.format(
		"INSERT OR IGNORE INTO %s (steamid64, name) VALUES (%s, %s)",
		TABLE_NAME, sql.SQLStr(ply:SteamID64()), sql.SQLStr(ply:Nick())
	))
end

--- Record a kill for the attacker. Increments kills, updates streak
-- and best streak, and optionally increments headshots.
-- All arithmetic is done in SQL against the pre-update row (SQLite evaluates
-- every RHS before applying the row), so no read-back is needed.
-- @param ply Player entity (the attacker)
-- @param isHeadshot boolean - whether this kill was a headshot
function PVPLeaderboard.RecordKill(ply, isHeadshot)
	PVPLeaderboard.EnsurePlayer(ply)

	sql.Query(string.format(
		"UPDATE %s SET kills = kills + 1, current_streak = current_streak + 1, " ..
		"best_streak = MAX(best_streak, current_streak + 1), headshots = headshots + %d, " ..
		"name = %s WHERE steamid64 = %s",
		TABLE_NAME, isHeadshot and 1 or 0, sql.SQLStr(ply:Nick()), sql.SQLStr(ply:SteamID64())
	))
end

--- Record a death for the victim. Increments deaths and resets current streak.
-- @param ply Player entity (the victim)
function PVPLeaderboard.RecordDeath(ply)
	PVPLeaderboard.EnsurePlayer(ply)

	sql.Query(string.format(
		"UPDATE %s SET deaths = deaths + 1, current_streak = 0, name = %s WHERE steamid64 = %s",
		TABLE_NAME, sql.SQLStr(ply:Nick()), sql.SQLStr(ply:SteamID64())
	))
end

--- Reset a single player's stats to zero.
-- Zeroes the all-time aggregate row and deletes the player's *kill* events so
-- they also drop off the windowed boards. Events where this player was the
-- victim are kept, so other players retain their windowed kills against them.
-- @param steamid64 string - the player's SteamID64
function PVPLeaderboard.ResetPlayerStats(steamid64)
	sql.Query(string.format(
		"UPDATE %s SET kills = 0, deaths = 0, current_streak = 0, best_streak = 0, headshots = 0 WHERE steamid64 = %s",
		TABLE_NAME, sql.SQLStr(steamid64)
	))

	sql.Query(string.format(
		"DELETE FROM %s WHERE attacker = %s",
		EVENTS_TABLE, sql.SQLStr(steamid64)
	))

	-- Rebuild the windowed aggregates so the change is reflected immediately.
	PVPLeaderboard.RecomputeWindowAgg()
end

--- Wipe the entire leaderboard (delete all rows from both tables).
function PVPLeaderboard.ResetAllStats()
	sql.Query(string.format("DELETE FROM %s", TABLE_NAME))
	sql.Query(string.format("DELETE FROM %s", EVENTS_TABLE))

	-- Empty the in-memory windowed aggregates directly (the event log is now
	-- empty, so a replay would just rebuild the same empty tables).
	for periodId in pairs(PVPLeaderboard.WindowAgg) do
		PVPLeaderboard.WindowAgg[periodId] = {}
	end
end

-- =============================================================================
-- EVENT LOG & WINDOWED AGGREGATES
-- =============================================================================
--
-- The rolling 24h/7d/30d boards are driven by in-memory aggregates kept in
-- PVPLeaderboard.WindowAgg[periodId] = { steamid64 -> {kills, deaths, headshots,
-- current_streak, best_streak} }. New kills are applied incrementally (O(1)) so
-- the per-kill hot path never replays the event log; the authoritative replay
-- (RecomputeWindowAgg) runs only on the periodic timer + at startup to drop
-- kills that have aged out of each rolling window.

PVPLeaderboard.WindowAgg = PVPLeaderboard.WindowAgg or {}
for _, period in ipairs(PVPLeaderboard.Periods) do
	if period.seconds > 0 then
		PVPLeaderboard.WindowAgg[period.id] = PVPLeaderboard.WindowAgg[period.id] or {}
	end
end

-- Fetch (or lazily create) a player's record within one period's aggregate.
local function getRec(agg, sid)
	local r = agg[sid]
	if not r then
		r = {kills = 0, deaths = 0, headshots = 0, current_streak = 0, best_streak = 0}
		agg[sid] = r
	end
	return r
end

-- Apply one kill to a single period's aggregate (attacker +kill/+streak, victim
-- +death/streak reset). Used both incrementally and during full replay.
local function applyKill(agg, attackerSID, victimSID, isHeadshot)
	local a = getRec(agg, attackerSID)
	a.kills = a.kills + 1
	if isHeadshot then a.headshots = a.headshots + 1 end
	a.current_streak = a.current_streak + 1
	if a.current_streak > a.best_streak then a.best_streak = a.current_streak end

	local v = getRec(agg, victimSID)
	v.deaths = v.deaths + 1
	v.current_streak = 0
end

--- Record a validated kill in the event log and fold it into the windowed
-- aggregates. A kill that just happened falls inside every rolling window, so
-- it is applied to each one. No DB replay happens here (hot path stays O(1)).
-- @param attackerSID string - attacker SteamID64
-- @param victimSID string - victim SteamID64
-- @param isHeadshot boolean
function PVPLeaderboard.RecordEvent(attackerSID, victimSID, isHeadshot)
	local hs = isHeadshot and 1 or 0

	sql.Query(string.format(
		"INSERT INTO %s (ts, attacker, victim, headshot) VALUES (%d, %s, %s, %d)",
		EVENTS_TABLE, os.time(), sql.SQLStr(attackerSID), sql.SQLStr(victimSID), hs
	))

	-- WindowAgg only ever holds windowed periods (seeded above), so folding the
	-- kill into every aggregate covers exactly the rolling windows.
	for _, agg in pairs(PVPLeaderboard.WindowAgg) do
		applyKill(agg, attackerSID, victimSID, isHeadshot)
	end
end

--- Authoritative rebuild of every windowed aggregate from the event log.
-- The rolling windows are nested (24h ⊂ 7d ⊂ 30d), so a single ts-indexed range
-- scan over the *largest* window feeds all of them in one chronological pass —
-- each event is decoded once and folded into every window it still falls inside.
-- This both seeds the aggregates at startup and drops kills that have aged out.
-- Runs off the per-kill path. Ordering by ts (not id) lets the ts index satisfy
-- both the range filter and the sort; ts and id are both append-monotonic, so
-- chronological order (and thus streak correctness) is preserved.
function PVPLeaderboard.RecomputeWindowAgg()
	local now = os.time()

	-- Collect the windowed periods and a fresh aggregate for each; track the
	-- widest window so we scan the event log exactly once.
	local windows = {}
	local maxSeconds = 0
	for _, period in ipairs(PVPLeaderboard.Periods) do
		if period.seconds > 0 then
			local agg = {}
			windows[#windows + 1] = {cutoff = now - period.seconds, agg = agg}
			PVPLeaderboard.WindowAgg[period.id] = agg
			if period.seconds > maxSeconds then maxSeconds = period.seconds end
		end
	end

	if #windows == 0 then return end

	local rows = sql.Query(string.format(
		"SELECT ts, attacker, victim, headshot FROM %s WHERE ts >= %d ORDER BY ts ASC",
		EVENTS_TABLE, now - maxSeconds
	))
	if not rows then return end

	for _, ev in ipairs(rows) do
		local ts = tonumber(ev.ts)
		local hs = tonumber(ev.headshot) == 1
		for _, w in ipairs(windows) do
			if ts >= w.cutoff then
				applyKill(w.agg, ev.attacker, ev.victim, hs)
			end
		end
	end
end

-- =============================================================================
-- CACHE MANAGEMENT
-- =============================================================================
--
-- PVPLeaderboard.CachedBoards[periodId] holds the top-N display board for each
-- period. Entities/panels never query the database; they read net-synced copies
-- of these caches. All-time is read from the aggregate table; the windowed
-- boards are materialised from PVPLeaderboard.WindowAgg.
PVPLeaderboard.CachedBoards = PVPLeaderboard.CachedBoards or {}

--- Resolve current display names for a set of SteamID64s from the aggregate
-- table. Scoped to just the ids we are about to show (top N), so we never load
-- the full players table.
local function ResolveNames(sids)
	local names = {}
	if #sids == 0 then return names end

	local escaped = {}
	for _, sid in ipairs(sids) do
		escaped[#escaped + 1] = sql.SQLStr(sid)
	end

	local rows = sql.Query(string.format(
		"SELECT steamid64, name FROM %s WHERE steamid64 IN (%s)",
		TABLE_NAME, table.concat(escaped, ",")
	))

	if rows then
		for _, row in ipairs(rows) do
			names[row.steamid64] = row.name
		end
	end

	return names
end

--- Build the all-time board from the cumulative aggregate table.
local function BuildAllTimeBoard(maxEntries)
	local rows = sql.Query(string.format(
		"SELECT * FROM %s ORDER BY kills DESC, best_streak DESC, headshots DESC LIMIT %d",
		TABLE_NAME, maxEntries
	))

	local board = {}
	if rows then
		for i, row in ipairs(rows) do
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
	return board
end

--- Build a windowed board from its in-memory aggregate. Only players with at
-- least one kill in the window appear (windowed boards are kill leaderboards).
local function BuildWindowBoard(periodId, maxEntries)
	local agg = PVPLeaderboard.WindowAgg[periodId] or {}

	local board = {}
	for sid, r in pairs(agg) do
		if r.kills > 0 then
			board[#board + 1] = {
				steamid64      = sid,
				kills          = r.kills,
				deaths         = r.deaths,
				kd             = r.deaths > 0 and math.Round(r.kills / r.deaths, 2) or r.kills,
				current_streak = r.current_streak,
				best_streak    = r.best_streak,
				headshots      = r.headshots,
			}
		end
	end

	-- Same ordering as all-time: kills, then best streak, then headshots.
	table.sort(board, function(a, b)
		if a.kills ~= b.kills then return a.kills > b.kills end
		if a.best_streak ~= b.best_streak then return a.best_streak > b.best_streak end
		return a.headshots > b.headshots
	end)

	-- Trim to top N before resolving names (only look up names we will show).
	for i = #board, maxEntries + 1, -1 do
		board[i] = nil
	end

	local sids = {}
	for _, e in ipairs(board) do sids[#sids + 1] = e.steamid64 end
	local names = ResolveNames(sids)
	for _, e in ipairs(board) do
		e.name = names[e.steamid64] or "Unknown"
	end

	return board
end

--- Rebuild the display cache for every period. Cheap: all-time is one indexed
-- query on the small aggregate table; windowed boards read in-memory aggregates
-- (no event-log replay here — that is RecomputeWindowAgg's job).
function PVPLeaderboard.RefreshCache()
	local maxEntries = PVPLeaderboard.Config.MaxEntries or 10
	local boards = {}

	for _, period in ipairs(PVPLeaderboard.Periods) do
		if period.seconds > 0 then
			boards[period.id] = BuildWindowBoard(period.id, maxEntries)
		else
			boards[period.id] = BuildAllTimeBoard(maxEntries)
		end
	end

	PVPLeaderboard.CachedBoards = boards
end

-- =============================================================================
-- NET SYNC: SERVER -> CLIENT
-- =============================================================================

--- Send all cached period boards to a specific player, or broadcast to all.
-- Writes one block per period in PVPLeaderboard.Periods order; the client reads
-- them back in the same order.
-- @param target Player entity (optional) - if nil, broadcasts to everyone
function PVPLeaderboard.SendCache(target)
	local boards = PVPLeaderboard.CachedBoards or {}

	net.Start("PVPLeaderboard_SyncCache")
		net.WriteUInt(#PVPLeaderboard.Periods, 4)
		for _, period in ipairs(PVPLeaderboard.Periods) do
			local board = boards[period.id] or {}
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

--- Refresh the display caches and broadcast to all clients. This is the cheap
-- per-kill path: it reads the in-memory windowed aggregates (already updated by
-- RecordEvent) and the small all-time table — no event-log replay. The periodic
-- timer pairs this with RecomputeWindowAgg() to age out stale window data.
function PVPLeaderboard.RefreshAndBroadcast()
	PVPLeaderboard.RefreshCache()
	PVPLeaderboard.SendCache()
end

--- Coalescing broadcast for the per-kill path. A burst of kills (common in a
-- fast firefight) collapses into a single refresh+broadcast on a 1-second
-- 1-shot timer instead of one full 4-board broadcast per kill. Signs already
-- tolerate up to cache_interval of staleness, so ≤1s of latency is invisible.
function PVPLeaderboard.QueueBroadcast()
	if timer.Exists("PVPLeaderboard_KillBroadcast") then return end
	timer.Create("PVPLeaderboard_KillBroadcast", 1, 1, PVPLeaderboard.RefreshAndBroadcast)
end

-- =============================================================================
-- CLIENT SYNC REQUEST (rate-limited)
-- =============================================================================

-- Per-player cooldown to prevent request spam. State lives on the player entity
-- so it is cleaned up automatically on disconnect (no side table/hook to manage).
local REQUEST_COOLDOWN = 5

net.Receive("PVPLeaderboard_RequestSync", function(len, ply)
	if not IsValid(ply) then return end

	-- Rate limit: one request per player every REQUEST_COOLDOWN seconds
	local now = CurTime()
	if (ply.pvplb_lastSync or 0) + REQUEST_COOLDOWN > now then return end
	ply.pvplb_lastSync = now

	PVPLeaderboard.SendCache(ply)
end)

-- =============================================================================
-- ADMIN CONFIG CHANGES (from XGUI panel)
-- =============================================================================

-- Whitelist of ConVars that superadmins can change via XGUI.
local allowedConVars = {
	["pvplb_enabled"]        = true,
	["pvplb_max_entries"]    = true,
	["pvplb_cache_interval"] = true,
	["pvplb_sort_interval"]  = true,
}

net.Receive("PVPLeaderboard_ConfigChange", function(len, ply)
	if not IsValid(ply) or not ply:IsSuperAdmin() then return end

	local cvarName = net.ReadString()
	local cvarValue = net.ReadString()

	-- Reject unknown ConVars silently
	if not allowedConVars[cvarName] then return end

	-- Cap value length; all whitelisted ConVars are short numeric/boolean values.
	if #cvarValue > 32 then return end

	local cv = GetConVar(cvarName)
	if not cv then return end

	RunConsoleCommand(cvarName, cvarValue)
	ServerLog(string.format("[PVP Leaderboard] %s changed %s to: %s\n", ply:Nick(), cvarName, cvarValue))
end)

-- =============================================================================
-- INITIALIZATION & PERIODIC REFRESH
-- =============================================================================

-- Populate the caches immediately on server start.
-- Seeds the windowed aggregates from the persisted event log (restart recovery)
-- then builds every period board, so Perm Props entities have data the moment
-- they spawn on map load.
hook.Add("InitPostEntity", "PVPLeaderboard_InitCache", function()
	PVPLeaderboard.RecomputeWindowAgg()
	PVPLeaderboard.RefreshCache()
	local alltime = PVPLeaderboard.CachedBoards.alltime or {}
	ServerLog("[PVP Leaderboard] Caches populated (" .. #alltime .. " all-time entries).\n")
end)

-- Clients pull the cache themselves via PVPLeaderboard_RequestSync on their own
-- InitPostEntity (see cl_pvp_leaderboard.lua) once their receivers exist, so no
-- server-side timed push on join is needed.

--- Create (or restart) the periodic cache refresh timer.
-- Called on load and whenever the cache interval ConVar changes. Reads the
-- interval straight from the ConVar (not PVPLeaderboard.Config) so it does not
-- depend on the shared config callback having run first — timer.Create with the
-- same name replaces any existing timer.
local function StartCacheTimer()
	local interval = GetConVar("pvplb_cache_interval"):GetInt()

	timer.Create("PVPLeaderboard_CacheRefresh", interval, 0, function()
		-- Authoritative replay first (drops kills that have aged out of each
		-- rolling window), then rebuild + broadcast all boards.
		PVPLeaderboard.RecomputeWindowAgg()
		PVPLeaderboard.RefreshAndBroadcast()
	end)
end

-- Start the periodic timer on load
StartCacheTimer()

-- Restart the timer when the cache interval ConVar changes
cvars.AddChangeCallback("pvplb_cache_interval", StartCacheTimer, "pvplb_cache_timer")

-- Rebuild + rebroadcast when max_entries changes (cache size changed)
cvars.AddChangeCallback("pvplb_max_entries", function()
	PVPLeaderboard.RefreshAndBroadcast()
end, "pvplb_cache_entries")
