-- =============================================================================
--  AFK System - Shared ConVars
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Creates replicated, archived ConVars for all AFK settings.
--  MUST run on both server and client so replicated ConVars register in both
--  realms. These persist across map changes and server restarts.
--  The XGUI panel reads/writes these directly.
-- =============================================================================

-- =============================================================================
-- CONVAR DEFINITIONS
-- =============================================================================

-- Flags: persists to cfg, replicates to clients, notifies on change
local FLAGS = bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY)

-- Timing
CreateConVar("afk_auto_timeout",        "300",  FLAGS, "Seconds idle before auto-AFK. 0 = disable.", 0, 3600)
CreateConVar("afk_check_interval",      "5",    FLAGS, "How often (seconds) to check for idle players.", 1, 30)
CreateConVar("afk_ping_rate",           "1",    FLAGS, "Client activity ping rate in seconds.", 0.5, 5)

-- Chat
CreateConVar("afk_broadcast",           "1",    FLAGS, "Broadcast chat messages on AFK status changes.", 0, 1)
CreateConVar("afk_chat_prefix",         "[AFK] ", FLAGS, "Prefix for AFK chat messages.")

-- Overhead sign
CreateConVar("afk_overhead_enabled",    "1",    FLAGS, "Show 3D AFK sign above players.", 0, 1)
CreateConVar("afk_overhead_self",       "1",    FLAGS, "Show AFK sign above yourself.", 0, 1)
CreateConVar("afk_overhead_maxdist",    "2000", FLAGS, "Max render distance for overhead sign.", 500, 10000)
CreateConVar("afk_overhead_offset",     "20",   FLAGS, "Height offset above player head.", 5, 50)
CreateConVar("afk_overhead_scale",      "0.08", FLAGS, "Scale of the overhead sign.", 0.03, 0.15)
CreateConVar("afk_overhead_spin",       "30",   FLAGS, "Spin speed (degrees/sec). 0 = no spin.", 0, 120)

-- Overhead sign colors (RGBA)
CreateConVar("afk_sign_bg_r",           "20",   FLAGS, "Sign background red.", 0, 255)
CreateConVar("afk_sign_bg_g",           "20",   FLAGS, "Sign background green.", 0, 255)
CreateConVar("afk_sign_bg_b",           "20",   FLAGS, "Sign background blue.", 0, 255)
CreateConVar("afk_sign_bg_a",           "200",  FLAGS, "Sign background alpha.", 0, 255)
CreateConVar("afk_sign_text_r",         "255",  FLAGS, "Sign text red.", 0, 255)
CreateConVar("afk_sign_text_g",         "180",  FLAGS, "Sign text green.", 0, 255)
CreateConVar("afk_sign_text_b",         "50",   FLAGS, "Sign text blue.", 0, 255)

-- Scoreboard
CreateConVar("afk_scoreboard_dim",      "120",  FLAGS, "Scoreboard row dim alpha for AFK players.", 0, 255)

-- =============================================================================
-- SYNC CONVARS -> AFK.Config
-- =============================================================================

-- Called once on load and whenever a ConVar changes.
local function SyncConfig()
    AFK.Config.AutoTimeout      = GetConVar("afk_auto_timeout"):GetInt()
    AFK.Config.CheckInterval    = GetConVar("afk_check_interval"):GetInt()
    AFK.Config.ActivityPingRate = GetConVar("afk_ping_rate"):GetFloat()

    AFK.Config.BroadcastMessages = GetConVar("afk_broadcast"):GetBool()
    AFK.Config.ChatPrefix        = GetConVar("afk_chat_prefix"):GetString()

    AFK.Config.ShowOverhead      = GetConVar("afk_overhead_enabled"):GetBool()
    AFK.Config.ShowOverheadSelf  = GetConVar("afk_overhead_self"):GetBool()
    AFK.Config.OverheadMaxDist   = GetConVar("afk_overhead_maxdist"):GetInt()
    AFK.Config.OverheadOffset    = GetConVar("afk_overhead_offset"):GetInt()
    AFK.Config.OverheadScale     = GetConVar("afk_overhead_scale"):GetFloat()
    AFK.Config.OverheadSpinSpeed = GetConVar("afk_overhead_spin"):GetInt()

    AFK.Config.OverheadBgColor = Color(
        GetConVar("afk_sign_bg_r"):GetInt(),
        GetConVar("afk_sign_bg_g"):GetInt(),
        GetConVar("afk_sign_bg_b"):GetInt(),
        GetConVar("afk_sign_bg_a"):GetInt()
    )

    AFK.Config.OverheadTextColor = Color(
        GetConVar("afk_sign_text_r"):GetInt(),
        GetConVar("afk_sign_text_g"):GetInt(),
        GetConVar("afk_sign_text_b"):GetInt(),
        255
    )

    AFK.Config.ScoreboardDimAlpha = GetConVar("afk_scoreboard_dim"):GetInt()
end

-- Initial sync
SyncConfig()

-- Re-sync whenever any afk_ convar changes
cvars.AddChangeCallback("afk_auto_timeout",     function() SyncConfig() end, "afk_sync")
cvars.AddChangeCallback("afk_check_interval",   function() SyncConfig() end, "afk_sync")
cvars.AddChangeCallback("afk_ping_rate",        function() SyncConfig() end, "afk_sync")
cvars.AddChangeCallback("afk_broadcast",        function() SyncConfig() end, "afk_sync")
cvars.AddChangeCallback("afk_chat_prefix",      function() SyncConfig() end, "afk_sync")
cvars.AddChangeCallback("afk_overhead_enabled",  function() SyncConfig() end, "afk_sync")
cvars.AddChangeCallback("afk_overhead_self",     function() SyncConfig() end, "afk_sync")
cvars.AddChangeCallback("afk_overhead_maxdist",  function() SyncConfig() end, "afk_sync")
cvars.AddChangeCallback("afk_overhead_offset",   function() SyncConfig() end, "afk_sync")
cvars.AddChangeCallback("afk_overhead_scale",    function() SyncConfig() end, "afk_sync")
cvars.AddChangeCallback("afk_overhead_spin",     function() SyncConfig() end, "afk_sync")
cvars.AddChangeCallback("afk_sign_bg_r",        function() SyncConfig() end, "afk_sync")
cvars.AddChangeCallback("afk_sign_bg_g",        function() SyncConfig() end, "afk_sync")
cvars.AddChangeCallback("afk_sign_bg_b",        function() SyncConfig() end, "afk_sync")
cvars.AddChangeCallback("afk_sign_bg_a",        function() SyncConfig() end, "afk_sync")
cvars.AddChangeCallback("afk_sign_text_r",      function() SyncConfig() end, "afk_sync")
cvars.AddChangeCallback("afk_sign_text_g",      function() SyncConfig() end, "afk_sync")
cvars.AddChangeCallback("afk_sign_text_b",      function() SyncConfig() end, "afk_sync")
cvars.AddChangeCallback("afk_scoreboard_dim",   function() SyncConfig() end, "afk_sync")
