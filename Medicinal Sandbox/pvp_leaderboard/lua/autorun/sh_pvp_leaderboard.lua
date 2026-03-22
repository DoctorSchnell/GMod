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
end

-- Initial sync on file load
SyncConfig()

-- Re-sync on any ConVar change
local syncCvars = {"pvplb_enabled", "pvplb_max_entries", "pvplb_cache_interval"}
for _, name in ipairs(syncCvars) do
	cvars.AddChangeCallback(name, function() SyncConfig() end, "pvplb_sync")
end
