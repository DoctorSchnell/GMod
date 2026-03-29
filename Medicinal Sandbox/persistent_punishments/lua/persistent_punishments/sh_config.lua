-- =============================================================================
--  Persistent Punishments - Shared Configuration
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Default values and color constants for the persistent punishment system.
--  ConVars in sh_convars.lua override these defaults at runtime.
-- =============================================================================

PPunish = PPunish or {}
PPunish.Config = PPunish.Config or {}

-- =============================================================================
-- DEFAULTS (overridden by ConVars)
-- =============================================================================

PPunish.Config.Enabled        = true
PPunish.Config.NotifyAdmins   = true
PPunish.Config.CheckInterval  = 30

-- =============================================================================
-- CHAT MESSAGE COLORS
-- =============================================================================

-- =============================================================================
-- HELPERS
-- =============================================================================

--- Call a ULX function while suppressing its internal fancyLogAdmin broadcast.
-- Prevents double-notification when our addon logs its own persistent message.
-- @param fn function - the ULX function to call (e.g., ulx.gag)
-- @param ... - arguments to pass to fn
function PPunish.CallULXSilent(fn, ...)
    local originalLog = ulx.fancyLogAdmin
    ulx.fancyLogAdmin = function() end
    local ok, err = pcall(fn, ...)
    ulx.fancyLogAdmin = originalLog
    if not ok then
        ErrorNoHalt("[Persistent Punishments] Error in ULX call: " .. tostring(err) .. "\n")
    end
end

-- =============================================================================
-- CHAT MESSAGE COLORS
-- =============================================================================

PPunish.Colors = {
    Header   = Color(255, 160, 0),      -- Orange/gold: "[Persistent Punishment]"
    Type     = Color(255, 80, 80),       -- Red: punishment type name
    Reason   = Color(255, 255, 255),     -- White: reason text
    Duration = Color(255, 220, 50),      -- Yellow: time remaining
    Admin    = Color(100, 180, 255),     -- Light blue: admin notification
    Removed  = Color(100, 255, 100),     -- Green: punishment removed/expired
}
