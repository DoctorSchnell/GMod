--[[
    AFK System - Shared Configuration
    Edit these values to customize the AFK system for your server.
]]--

AFK = AFK or {}
AFK.Config = AFK.Config or {}

-------------------------------------------------
-- TIMING
-------------------------------------------------

-- Seconds of no input before a player is automatically marked AFK.
-- Set to 0 to disable auto-AFK (manual !afk only).
AFK.Config.AutoTimeout = 300 -- 5 minutes

-- How often (seconds) the server checks for idle players.
AFK.Config.CheckInterval = 5

-- How often (seconds) the client sends activity pings to the server.
-- Lower = more responsive but more network traffic. 1-2 is fine.
AFK.Config.ActivityPingRate = 1

-------------------------------------------------
-- CHAT MESSAGES
-------------------------------------------------

-- Broadcast a chat message when a player goes AFK or returns.
AFK.Config.BroadcastMessages = true

-- Prefix for chat messages.
AFK.Config.ChatPrefix = "[AFK] "

-------------------------------------------------
-- 3D OVERHEAD SIGN
-------------------------------------------------

-- Show floating "AFK" sign above AFK players' heads.
AFK.Config.ShowOverhead = true

-- Show the overhead sign on yourself (visible in third person / looking down in first person).
AFK.Config.ShowOverheadSelf = true

-- Maximum distance (units) to render the overhead sign.
AFK.Config.OverheadMaxDist = 2000

-- Height offset above the player model's head (units).
AFK.Config.OverheadOffset = 20

-- Background color of the sign.
AFK.Config.OverheadBgColor = Color(20, 20, 20, 200)

-- Text color of the sign.
AFK.Config.OverheadTextColor = Color(255, 180, 50, 255)

-- Scale of the overhead 3D sign.
AFK.Config.OverheadScale = 0.08

-- Spin speed in degrees per second. Synced across all clients.
-- Set to 0 to disable spinning (sign will face a fixed direction).
AFK.Config.OverheadSpinSpeed = 30

-------------------------------------------------
-- SCOREBOARD (Sui Scoreboard Integration)
-------------------------------------------------

-- Dim AFK player rows on the scoreboard.
AFK.Config.ScoreboardDimAlpha = 120

-- AFK indicator badge color on the scoreboard.
AFK.Config.ScoreboardBadgeColor = Color(255, 160, 0, 255)

-- AFK indicator background color on the scoreboard.
AFK.Config.ScoreboardBadgeBgColor = Color(40, 40, 40, 200)

-------------------------------------------------
-- NETWORK VARIABLE NAMES (don't change unless conflicts)
-------------------------------------------------

AFK.NW_IS_AFK = "AFK_IsAFK"
AFK.NW_SINCE  = "AFK_Since"
