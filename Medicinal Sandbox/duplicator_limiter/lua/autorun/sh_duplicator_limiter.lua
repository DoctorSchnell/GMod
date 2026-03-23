-- =============================================================================
--  Duplicator Limiter — Shared ConVars
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Creates replicated, archived ConVars for all Duplicator Limiter settings.
--  MUST run on both server and client so replicated ConVars register in both
--  realms.  The XGUI panel reads these; changes are applied via net message.
-- =============================================================================

DupLimiter = DupLimiter or {}
DupLimiter.Config = DupLimiter.Config or {}

-- =============================================================================
-- CONVAR DEFINITIONS
-- =============================================================================

local FLAGS = bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY)

CreateConVar("duplimiter_enabled",      "1",   FLAGS, "Enable Duplicator Limiter.", 0, 1)
CreateConVar("duplimiter_batch_size",   "10",  FLAGS, "Entities spawned per batch.", 1, 100)
CreateConVar("duplimiter_delay",        "0.1", FLAGS, "Seconds between batches.", 0.05, 2)
CreateConVar("duplimiter_max_entities", "150", FLAGS, "Max entities per paste. 0 = no limit.", 0, 1000)
CreateConVar("duplimiter_cooldown",     "2",   FLAGS, "Seconds between pastes per player.", 0, 30)
CreateConVar("duplimiter_admin_bypass", "0",   FLAGS, "Admins bypass all limits.", 0, 1)

-- =============================================================================
-- SYNC CONVARS -> DupLimiter.Config
-- =============================================================================

local function SyncConfig()
    DupLimiter.Config.Enabled     = GetConVar("duplimiter_enabled"):GetBool()
    DupLimiter.Config.BatchSize   = GetConVar("duplimiter_batch_size"):GetInt()
    DupLimiter.Config.Delay       = GetConVar("duplimiter_delay"):GetFloat()
    DupLimiter.Config.MaxEntities = GetConVar("duplimiter_max_entities"):GetInt()
    DupLimiter.Config.Cooldown    = GetConVar("duplimiter_cooldown"):GetFloat()
    DupLimiter.Config.AdminBypass = GetConVar("duplimiter_admin_bypass"):GetBool()
end

SyncConfig()

cvars.AddChangeCallback("duplimiter_enabled",      function() SyncConfig() end, "duplimiter_sync")
cvars.AddChangeCallback("duplimiter_batch_size",   function() SyncConfig() end, "duplimiter_sync")
cvars.AddChangeCallback("duplimiter_delay",        function() SyncConfig() end, "duplimiter_sync")
cvars.AddChangeCallback("duplimiter_max_entities", function() SyncConfig() end, "duplimiter_sync")
cvars.AddChangeCallback("duplimiter_cooldown",     function() SyncConfig() end, "duplimiter_sync")
cvars.AddChangeCallback("duplimiter_admin_bypass", function() SyncConfig() end, "duplimiter_sync")
