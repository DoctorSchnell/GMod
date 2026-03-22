-- =============================================================================
--  AFK System - Client Input Detection
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Monitors player input (movement, mouse, menus, attacks) and sends
--  activity pings to the server. Throttled to avoid network spam.
-- =============================================================================

AFK.Client = AFK.Client or {}

local lastPingSent = 0
local lastEyeAngles = Angle(0, 0, 0)
local hasActivity = false

-- =============================================================================
-- ACTIVITY PING
-- =============================================================================

--- Send an activity ping to the server (throttled).
local function SendActivityPing()
    local now = CurTime()
    if now - lastPingSent < AFK.Config.ActivityPingRate then return end
    lastPingSent = now

    net.Start("AFK_Activity")
    net.SendToServer()
end

--- Mark that activity was detected this frame.
local function MarkActive()
    hasActivity = true
end

-- =============================================================================
-- INPUT HOOKS
-- =============================================================================

-- CreateMove fires every tick with the player's input commands.
-- We check for movement keys, attack buttons, and mouse movement.
hook.Add("CreateMove", "AFK_InputDetection", function(cmd)
    -- Movement keys (forward, back, strafe left, strafe right, jump, duck)
    if cmd:GetForwardMove() ~= 0 or cmd:GetSideMove() ~= 0 or cmd:GetUpMove() ~= 0 then
        MarkActive()
        return
    end

    -- Attack buttons
    local buttons = cmd:GetButtons()
    if bit.band(buttons, IN_ATTACK) ~= 0 or
       bit.band(buttons, IN_ATTACK2) ~= 0 or
       bit.band(buttons, IN_USE) ~= 0 or
       bit.band(buttons, IN_RELOAD) ~= 0 or
       bit.band(buttons, IN_JUMP) ~= 0 or
       bit.band(buttons, IN_DUCK) ~= 0 then
        MarkActive()
        return
    end

    -- Mouse movement (eye angle change)
    local curAngles = cmd:GetViewAngles()
    if curAngles ~= lastEyeAngles then
        lastEyeAngles = Angle(curAngles.p, curAngles.y, curAngles.r)
        MarkActive()
        return
    end
end)

-- Spawn menu opened
hook.Add("OnSpawnMenuOpen", "AFK_SpawnMenuActivity", function()
    MarkActive()
end)

-- Context menu opened
hook.Add("OnContextMenuOpen", "AFK_ContextMenuActivity", function()
    MarkActive()
end)

-- Player started typing in chat
hook.Add("StartChat", "AFK_ChatActivity", function()
    MarkActive()
end)

-- =============================================================================
-- ACTIVITY FLUSH
-- =============================================================================

-- Once per frame, if we detected activity, send the throttled ping.
hook.Add("Think", "AFK_FlushActivity", function()
    if hasActivity then
        hasActivity = false
        SendActivityPing()
    end
end)
