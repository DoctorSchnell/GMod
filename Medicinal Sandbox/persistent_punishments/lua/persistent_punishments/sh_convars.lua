-- =============================================================================
--  Persistent Punishments - Shared ConVars
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Creates replicated, archived ConVars for all settings.
--  MUST run on both server and client so replicated ConVars register in both
--  realms. These persist across map changes and server restarts.
-- =============================================================================

-- =============================================================================
-- CONVAR DEFINITIONS
-- =============================================================================

local FLAGS = bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY)

CreateConVar("ppunish_enabled",        "1",  FLAGS, "Enable/disable the persistent punishment system.", 0, 1)
CreateConVar("ppunish_notify_admins",  "1",  FLAGS, "Notify online admins when a punished player joins.", 0, 1)
CreateConVar("ppunish_check_interval", "30", FLAGS, "Seconds between punishment expiry checks.", 5, 120)

-- =============================================================================
-- SYNC CONVARS -> PPunish.Config
-- =============================================================================

local function SyncConfig()
    PPunish.Config.Enabled       = GetConVar("ppunish_enabled"):GetBool()
    PPunish.Config.NotifyAdmins  = GetConVar("ppunish_notify_admins"):GetBool()
    PPunish.Config.CheckInterval = GetConVar("ppunish_check_interval"):GetInt()
end

SyncConfig()

cvars.AddChangeCallback("ppunish_enabled",        function() SyncConfig() end, "ppunish_sync")
cvars.AddChangeCallback("ppunish_notify_admins",  function() SyncConfig() end, "ppunish_sync")
cvars.AddChangeCallback("ppunish_check_interval", function() SyncConfig() end, "ppunish_sync")
