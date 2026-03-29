-- =============================================================================
--  Persistent Punishments - XGUI Settings Panel
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  ConVar settings for the Persistent Punishments addon.
--  Punishment management is in the top-level "Punishments" XGUI tab.
-- =============================================================================

local function SendConfigChange(cvarName, value)
    net.Start("PPunish_ConfigChange")
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

-- =============================================================================
-- SETTINGS
-- =============================================================================

xlib.makelabel{x = 5, y = y, label = "— Settings —", textcolor = Color(200, 140, 0), parent = canvas}
y = y + 18

local cbEnabled = xlib.makecheckbox{x = 5, y = y, label = "Enable Persistent Punishments", parent = canvas, textcolor = color_black}
local cv = GetConVar("ppunish_enabled")
if cv then cbEnabled:SetChecked(cv:GetBool()) end
cbEnabled.OnChange = function(self, val) stagedChanges["ppunish_enabled"] = val and "1" or "0" end
y = y + 20

local cbNotify = xlib.makecheckbox{x = 5, y = y, label = "Notify admins on punished player join", parent = canvas, textcolor = color_black}
cv = GetConVar("ppunish_notify_admins")
if cv then cbNotify:SetChecked(cv:GetBool()) end
cbNotify.OnChange = function(self, val) stagedChanges["ppunish_notify_admins"] = val and "1" or "0" end
y = y + 22

local sInterval = xlib.makeslider{x = 5, y = y, w = 545, label = "Expiry Check Interval (sec)", min = 5, max = 120, decimal = 0, parent = canvas, textcolor = color_black}
cv = GetConVar("ppunish_check_interval")
if cv then sInterval:SetValue(cv:GetFloat()) end
sInterval.OnValueChanged = function(self, val) stagedChanges["ppunish_check_interval"] = math.Round(val) end
y = y + 28

-- Apply / Reset
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

y = y + 30

-- Set canvas height
canvas:SetTall(y)

-- =============================================================================
-- REGISTER
-- =============================================================================

xgui.addSettingModule("Persistent Punishments", panel, "icon16/lock.png")
