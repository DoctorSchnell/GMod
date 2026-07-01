-- =============================================================================
--  PVP Leaderboard - Shared Configuration
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Shared ConVars, namespace, and config sync.
--  MUST run on both server and client so replicated ConVars register in both
--  realms.
-- =============================================================================

PVPLeaderboard = PVPLeaderboard or {}

-- Flags: persists to cfg, replicates to clients, notifies on change
local FLAGS = bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY)

-- =============================================================================
-- CONVAR DEFINITIONS
-- =============================================================================

-- Master toggle for kill/death tracking
CreateConVar("pvplb_enabled", "1", FLAGS, "Enable/disable PVP leaderboard stat tracking.", 0, 1)

-- Number of players shown on leaderboard entities
CreateConVar("pvplb_max_entries", "10", FLAGS, "Maximum number of players shown on leaderboard displays.", 5, 25)

-- How often the cache refreshes from the database (seconds)
CreateConVar("pvplb_cache_interval", "60", FLAGS, "Seconds between automatic cache refreshes from database.", 15, 300)

-- How often the leaderboard cycles to the next sort column (seconds, client-side display)
CreateConVar("pvplb_sort_interval", "20", FLAGS, "Seconds between automatic sort column cycling on leaderboard displays.", 10, 120)

-- =============================================================================
-- RUNTIME CONFIG TABLE
-- =============================================================================

-- Synced from ConVars so we avoid calling GetConVar every frame.
PVPLeaderboard.Config = PVPLeaderboard.Config or {}

-- Called on load and whenever a ConVar changes.
local function SyncConfig()
	PVPLeaderboard.Config.Enabled       = GetConVar("pvplb_enabled"):GetBool()
	PVPLeaderboard.Config.MaxEntries    = GetConVar("pvplb_max_entries"):GetInt()
	PVPLeaderboard.Config.CacheInterval = GetConVar("pvplb_cache_interval"):GetInt()
	PVPLeaderboard.Config.SortInterval  = GetConVar("pvplb_sort_interval"):GetInt()
end

-- Initial sync on file load
SyncConfig()

-- Re-sync on any ConVar change
local syncCvars = {"pvplb_enabled", "pvplb_max_entries", "pvplb_cache_interval", "pvplb_sort_interval"}
for _, name in ipairs(syncCvars) do
	cvars.AddChangeCallback(name, function() SyncConfig() end, "pvplb_sync")
end

-- =============================================================================
-- LEADERBOARD PERIODS (time windows)
-- =============================================================================
--
-- Single source of truth for the four leaderboard variants. Shared so the
-- server (cache building), client (rendering + panel tabs), and entities
-- (which period a sign displays) all agree on ids, labels, and classes.
--
--   id      - stable identifier used as the cache key and in net messages
--   label   - shown on signs/panels as "<label> PVP RECORD" and on panel tabs
--   seconds - rolling window length; 0 means all-time (no time filter)
--   class   - the spawnable entity class that displays this period
--
-- All-time reads the cumulative aggregate table (preserving history from
-- before the event log existed); the windowed boards are computed from the
-- kill event log. This declaration order is also the tab/sync order.
PVPLeaderboard.Periods = {
	{id = "alltime", label = "ALL TIME", seconds = 0,       class = "pvp_leaderboard"},
	{id = "24h",     label = "24 HOUR",  seconds = 86400,   class = "pvp_leaderboard_24h"},
	{id = "7d",      label = "7 DAY",    seconds = 604800,  class = "pvp_leaderboard_7d"},
	{id = "30d",     label = "30 DAY",   seconds = 2592000, class = "pvp_leaderboard_30d"},
}

-- Look up a period table by id. Falls back to the first period (all-time)
-- for unknown ids so callers always receive a valid period.
function PVPLeaderboard.GetPeriod(id)
	for _, p in ipairs(PVPLeaderboard.Periods) do
		if p.id == id then return p end
	end
	return PVPLeaderboard.Periods[1]
end

-- Map of entity class -> period id, so the entity / physics / damage code can
-- recognise "is this one of our leaderboard signs?" across all four classes
-- without duplicating the class list in multiple files.
PVPLeaderboard.ClassToPeriod = {}
for _, p in ipairs(PVPLeaderboard.Periods) do
	PVPLeaderboard.ClassToPeriod[p.class] = p.id
end
