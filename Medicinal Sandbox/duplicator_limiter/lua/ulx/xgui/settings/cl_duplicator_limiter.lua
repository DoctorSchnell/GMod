-- =============================================================================
--  Duplicator Limiter — XGUI Settings Panel
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  SuperAdmin-only settings panel for tuning the Duplicator Limiter.
--  Changes are staged locally and sent to the server on Apply.
-- =============================================================================

local function SendConfigChange(cvarName, value)
    net.Start("DupLimiter_ConfigUpdate")
    net.WriteString(cvarName)
    net.WriteString(tostring(value))
    net.SendToServer()
end

local panel = xlib.makepanel{parent = xgui.null}

local scroll = vgui.Create("DScrollPanel", panel)
scroll:SetPos(0, 0)

panel.PerformLayout = function(self, w, h)
    scroll:SetSize(w, h)
end

local canvas = scroll:GetCanvas()

local stagedChanges = {}
local y = 5
local cv

-- =============================================================================
-- GENERAL
-- =============================================================================

xlib.makelabel{x = 5, y = y, label = "— General —", textcolor = Color(200, 140, 0), parent = canvas}
y = y + 18

local cbEnabled = xlib.makecheckbox{x = 5, y = y, label = "Enable Duplicator Limiter", parent = canvas, textcolor = color_black}
cv = GetConVar("duplimiter_enabled")
if cv then cbEnabled:SetChecked(cv:GetBool()) end
cbEnabled.OnChange = function(self, val) stagedChanges["duplimiter_enabled"] = val and "1" or "0" end
y = y + 22

local cbBypass = xlib.makecheckbox{x = 5, y = y, label = "Admins Bypass All Limits", parent = canvas, textcolor = color_black}
cv = GetConVar("duplimiter_admin_bypass")
if cv then cbBypass:SetChecked(cv:GetBool()) end
cbBypass.OnChange = function(self, val) stagedChanges["duplimiter_admin_bypass"] = val and "1" or "0" end
y = y + 28

-- =============================================================================
-- BATCHING
-- =============================================================================

xlib.makelabel{x = 5, y = y, label = "— Batching —", textcolor = Color(200, 140, 0), parent = canvas}
y = y + 18

local sBatch = xlib.makeslider{x = 5, y = y, w = 545, label = "Batch Size (entities per tick)", min = 1, max = 100, decimal = 0, parent = canvas, textcolor = color_black}
cv = GetConVar("duplimiter_batch_size")
if cv then sBatch:SetValue(cv:GetFloat()) end
sBatch.OnValueChanged = function(self, val) stagedChanges["duplimiter_batch_size"] = math.Round(val) end
y = y + 22

local sDelay = xlib.makeslider{x = 5, y = y, w = 545, label = "Delay Between Batches (sec)", min = 0.05, max = 2, decimal = 2, parent = canvas, textcolor = color_black}
cv = GetConVar("duplimiter_delay")
if cv then sDelay:SetValue(cv:GetFloat()) end
sDelay.OnValueChanged = function(self, val) stagedChanges["duplimiter_delay"] = math.Round(val, 2) end
y = y + 28

-- =============================================================================
-- LIMITS
-- =============================================================================

xlib.makelabel{x = 5, y = y, label = "— Limits —", textcolor = Color(200, 140, 0), parent = canvas}
y = y + 18

local sMax = xlib.makeslider{x = 5, y = y, w = 545, label = "Max Entities Per Paste (0 = no limit)", min = 0, max = 1000, decimal = 0, parent = canvas, textcolor = color_black}
cv = GetConVar("duplimiter_max_entities")
if cv then sMax:SetValue(cv:GetFloat()) end
sMax.OnValueChanged = function(self, val) stagedChanges["duplimiter_max_entities"] = math.Round(val) end
y = y + 22

local sCooldown = xlib.makeslider{x = 5, y = y, w = 545, label = "Cooldown Between Pastes (sec)", min = 0, max = 30, decimal = 1, parent = canvas, textcolor = color_black}
cv = GetConVar("duplimiter_cooldown")
if cv then sCooldown:SetValue(cv:GetFloat()) end
sCooldown.OnValueChanged = function(self, val) stagedChanges["duplimiter_cooldown"] = math.Round(val, 1) end
y = y + 28

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

canvas:SetTall(y)

-- =============================================================================
-- REGISTER
-- =============================================================================

xgui.addSettingModule("Duplicator Limiter", panel, "icon16/bricks.png")
