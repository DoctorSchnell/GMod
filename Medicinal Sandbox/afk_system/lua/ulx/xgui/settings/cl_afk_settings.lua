-- =============================================================================
--  AFK System - XGUI Settings Panel
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Uses a DScrollPanel for scrolling since we have more controls
--  than fit in the default XGUI settings panel height.
-- =============================================================================

local function SendConfigChange(cvarName, value)
    net.Start("AFK_ConfigChange")
    net.WriteString(cvarName)
    net.WriteString(tostring(value))
    net.SendToServer()
end

local panel = xlib.makepanel{parent = xgui.null}

-- Scroll panel fills the main panel
local scroll = vgui.Create("DScrollPanel", panel)
scroll:SetPos(0, 0)

-- Resize scroll panel to fill the parent whenever the panel is laid out
panel.PerformLayout = function(self, w, h)
    scroll:SetSize(w, h)
end

-- Canvas inside the scroll panel - all controls are parented to this
local canvas = scroll:GetCanvas()

local stagedChanges = {}
local y = 5

-- =============================================================================
-- TIMING
-- =============================================================================

xlib.makelabel{x = 5, y = y, label = "— Timing —", textcolor = Color(200, 140, 0), parent = canvas}
y = y + 18

local sTimeout = xlib.makeslider{x = 5, y = y, w = 545, label = "Auto-AFK Timeout (sec, 0=off)", min = 0, max = 3600, decimal = 0, parent = canvas, textcolor = color_black}
local cv = GetConVar("afk_auto_timeout")
if cv then sTimeout:SetValue(cv:GetFloat()) end
sTimeout.OnValueChanged = function(self, val) stagedChanges["afk_auto_timeout"] = math.Round(val) end
y = y + 22

local sCheck = xlib.makeslider{x = 5, y = y, w = 545, label = "Server Check Interval (sec)", min = 1, max = 30, decimal = 0, parent = canvas, textcolor = color_black}
cv = GetConVar("afk_check_interval")
if cv then sCheck:SetValue(cv:GetFloat()) end
sCheck.OnValueChanged = function(self, val) stagedChanges["afk_check_interval"] = math.Round(val) end
y = y + 22

local sPing = xlib.makeslider{x = 5, y = y, w = 545, label = "Client Ping Rate (sec)", min = 0.5, max = 5, decimal = 1, parent = canvas, textcolor = color_black}
cv = GetConVar("afk_ping_rate")
if cv then sPing:SetValue(cv:GetFloat()) end
sPing.OnValueChanged = function(self, val) stagedChanges["afk_ping_rate"] = math.Round(val, 1) end
y = y + 28

-- =============================================================================
-- CHAT
-- =============================================================================

xlib.makelabel{x = 5, y = y, label = "— Chat —", textcolor = Color(200, 140, 0), parent = canvas}
y = y + 18

local cbBroadcast = xlib.makecheckbox{x = 5, y = y, label = "Broadcast AFK status in chat", parent = canvas, textcolor = color_black}
cv = GetConVar("afk_broadcast")
if cv then cbBroadcast:SetChecked(cv:GetBool()) end
cbBroadcast.OnChange = function(self, val) stagedChanges["afk_broadcast"] = val and "1" or "0" end
y = y + 28

-- =============================================================================
-- OVERHEAD SIGN
-- =============================================================================

xlib.makelabel{x = 5, y = y, label = "— 3D Overhead Sign —", textcolor = Color(200, 140, 0), parent = canvas}
y = y + 18

local cbOverhead = xlib.makecheckbox{x = 5, y = y, label = "Show overhead AFK sign", parent = canvas, textcolor = color_black}
cv = GetConVar("afk_overhead_enabled")
if cv then cbOverhead:SetChecked(cv:GetBool()) end
cbOverhead.OnChange = function(self, val) stagedChanges["afk_overhead_enabled"] = val and "1" or "0" end
y = y + 20

local cbSelf = xlib.makecheckbox{x = 5, y = y, label = "Show sign above yourself", parent = canvas, textcolor = color_black}
cv = GetConVar("afk_overhead_self")
if cv then cbSelf:SetChecked(cv:GetBool()) end
cbSelf.OnChange = function(self, val) stagedChanges["afk_overhead_self"] = val and "1" or "0" end
y = y + 22

local sDist = xlib.makeslider{x = 5, y = y, w = 545, label = "Render Distance", min = 500, max = 10000, decimal = 0, parent = canvas, textcolor = color_black}
cv = GetConVar("afk_overhead_maxdist")
if cv then sDist:SetValue(cv:GetFloat()) end
sDist.OnValueChanged = function(self, val) stagedChanges["afk_overhead_maxdist"] = math.Round(val) end
y = y + 22

local sOffset = xlib.makeslider{x = 5, y = y, w = 545, label = "Height Above Head", min = 5, max = 50, decimal = 0, parent = canvas, textcolor = color_black}
cv = GetConVar("afk_overhead_offset")
if cv then sOffset:SetValue(cv:GetFloat()) end
sOffset.OnValueChanged = function(self, val) stagedChanges["afk_overhead_offset"] = math.Round(val) end
y = y + 22

local sScale = xlib.makeslider{x = 5, y = y, w = 545, label = "Sign Scale", min = 0.03, max = 0.15, decimal = 2, parent = canvas, textcolor = color_black}
cv = GetConVar("afk_overhead_scale")
if cv then sScale:SetValue(cv:GetFloat()) end
sScale.OnValueChanged = function(self, val) stagedChanges["afk_overhead_scale"] = math.Round(val, 2) end
y = y + 22

local sSpin = xlib.makeslider{x = 5, y = y, w = 545, label = "Spin Speed (deg/sec)", min = 0, max = 120, decimal = 0, parent = canvas, textcolor = color_black}
cv = GetConVar("afk_overhead_spin")
if cv then sSpin:SetValue(cv:GetFloat()) end
sSpin.OnValueChanged = function(self, val) stagedChanges["afk_overhead_spin"] = math.Round(val) end
y = y + 28

-- =============================================================================
-- SIGN COLORS
-- =============================================================================

xlib.makelabel{x = 5, y = y, label = "— Sign Colors (BG: R/G/B/A, Text: R/G/B) —", textcolor = Color(200, 140, 0), parent = canvas}
y = y + 18

local colorConvars = {
    {name = "afk_sign_bg_r", label = "BG Red"},
    {name = "afk_sign_bg_g", label = "BG Green"},
    {name = "afk_sign_bg_b", label = "BG Blue"},
    {name = "afk_sign_bg_a", label = "BG Alpha"},
    {name = "afk_sign_text_r", label = "Text Red"},
    {name = "afk_sign_text_g", label = "Text Green"},
    {name = "afk_sign_text_b", label = "Text Blue"},
}

for _, cc in ipairs(colorConvars) do
    local s = xlib.makeslider{x = 5, y = y, w = 545, label = cc.label, min = 0, max = 255, decimal = 0, parent = canvas, textcolor = color_black}
    cv = GetConVar(cc.name)
    if cv then s:SetValue(cv:GetFloat()) end
    s.OnValueChanged = function(self, val) stagedChanges[cc.name] = math.Round(val) end
    y = y + 20
end
y = y + 8

-- =============================================================================
-- SCOREBOARD
-- =============================================================================

xlib.makelabel{x = 5, y = y, label = "— Scoreboard —", textcolor = Color(200, 140, 0), parent = canvas}
y = y + 18

local sDim = xlib.makeslider{x = 5, y = y, w = 545, label = "Row Dim Intensity", min = 0, max = 255, decimal = 0, parent = canvas, textcolor = color_black}
cv = GetConVar("afk_scoreboard_dim")
if cv then sDim:SetValue(cv:GetFloat()) end
sDim.OnValueChanged = function(self, val) stagedChanges["afk_scoreboard_dim"] = math.Round(val) end
y = y + 28

-- =============================================================================
-- COLOR PREVIEW
-- =============================================================================

xlib.makelabel{x = 5, y = y, label = "— Color Preview —", textcolor = Color(200, 140, 0), parent = canvas}
y = y + 18

local preview = vgui.Create("DPanel", canvas)
preview:SetPos(5, y)
preview:SetSize(545, 50)
preview.Paint = function(self, w, h)
    local function getVal(cvarName)
        local staged = stagedChanges[cvarName]
        if staged ~= nil then return tonumber(staged) end
        local cvar = GetConVar(cvarName)
        return cvar and cvar:GetInt() or 0
    end

    local bgR = getVal("afk_sign_bg_r")
    local bgG = getVal("afk_sign_bg_g")
    local bgB = getVal("afk_sign_bg_b")
    local bgA = getVal("afk_sign_bg_a")
    local tR  = getVal("afk_sign_text_r")
    local tG  = getVal("afk_sign_text_g")
    local tB  = getVal("afk_sign_text_b")

    draw.RoundedBox(6, 0, 0, w, h, Color(bgR, bgG, bgB, bgA))
    draw.SimpleText("AFK  3m 25s", "DermaDefaultBold", w / 2, h / 2,
        Color(tR, tG, tB, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end
y = y + 58

-- =============================================================================
-- APPLY / RESET
-- =============================================================================

local btnApply = xlib.makebutton{x = 445, y = y, w = 100, h = 25, label = "Apply", parent = canvas}
btnApply.DoClick = function()
    for cvarName, val in pairs(stagedChanges) do
        SendConfigChange(cvarName, val)
    end
    stagedChanges = {}
    surface.PlaySound("buttons/button14.wav")
end

local btnReset = xlib.makebutton{x = 335, y = y, w = 100, h = 25, label = "Reset", parent = canvas}
btnReset.DoClick = function()
    stagedChanges = {}
    surface.PlaySound("buttons/button14.wav")
end

y = y + 40

-- Set canvas height so scroll panel knows the content size
canvas:SetTall(y)

-- =============================================================================
-- REGISTER
-- =============================================================================

xgui.addSettingModule("AFK System", panel, "icon16/clock.png")
