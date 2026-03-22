-- =============================================================================
--  PVP Leaderboard - XGUI Settings Panel
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Uses xlib helpers and xgui.null parent pattern (matching AFK System and
--  PVP Combat Timer).
-- =============================================================================

-- Helper to send a config change to the server via net message.
-- The server validates permissions before applying the change.
local function SendConfigChange(cvarName, value)
	net.Start("PVPLeaderboard_ConfigChange")
	net.WriteString(cvarName)
	net.WriteString(tostring(value))
	net.SendToServer()
end

-- Create the main panel using the xgui.null parent pattern
local panel = xlib.makepanel{parent = xgui.null}

-- Scroll panel fills the main panel (handles overflow if controls exceed panel height)
local scroll = vgui.Create("DScrollPanel", panel)
scroll:SetPos(0, 0)

-- Resize scroll panel to fill the parent whenever the panel is laid out
panel.PerformLayout = function(self, w, h)
	scroll:SetSize(w, h)
end

-- Canvas inside the scroll panel - all controls are parented to this
local canvas = scroll:GetCanvas()

-- Staged changes accumulate until the user clicks Apply
local stagedChanges = {}
local y = 5

-- =============================================================================
-- GENERAL
-- =============================================================================

xlib.makelabel{x = 5, y = y, label = "-- General --", textcolor = Color(200, 140, 0), parent = canvas}
y = y + 18

-- Master toggle: enables/disables all kill/death tracking
local cbEnabled = xlib.makecheckbox{x = 5, y = y, label = "Tracking Enabled", parent = canvas, textcolor = color_black}
local cv = GetConVar("pvplb_enabled")
if cv then cbEnabled:SetChecked(cv:GetBool()) end
cbEnabled.OnChange = function(self, val) stagedChanges["pvplb_enabled"] = val and "1" or "0" end
y = y + 28

-- =============================================================================
-- DISPLAY
-- =============================================================================

xlib.makelabel{x = 5, y = y, label = "-- Display --", textcolor = Color(200, 140, 0), parent = canvas}
y = y + 18

-- Max entries: how many players appear on the leaderboard entities
local sMaxEntries = xlib.makeslider{x = 5, y = y, w = 545, label = "Leaderboard Entries (top N)", min = 5, max = 25, decimal = 0, parent = canvas, textcolor = color_black}
cv = GetConVar("pvplb_max_entries")
if cv then sMaxEntries:SetValue(cv:GetFloat()) end
sMaxEntries.OnValueChanged = function(self, val) stagedChanges["pvplb_max_entries"] = math.Round(val) end
y = y + 28

-- =============================================================================
-- PERFORMANCE
-- =============================================================================

xlib.makelabel{x = 5, y = y, label = "-- Performance --", textcolor = Color(200, 140, 0), parent = canvas}
y = y + 18

-- Cache refresh interval: how often the server re-queries the database
-- and broadcasts updated data to clients (in addition to per-kill refreshes)
local sCacheInterval = xlib.makeslider{x = 5, y = y, w = 545, label = "Cache Refresh Interval (seconds)", min = 15, max = 300, decimal = 0, parent = canvas, textcolor = color_black}
cv = GetConVar("pvplb_cache_interval")
if cv then sCacheInterval:SetValue(cv:GetFloat()) end
sCacheInterval.OnValueChanged = function(self, val) stagedChanges["pvplb_cache_interval"] = math.Round(val) end
y = y + 34

-- =============================================================================
-- APPLY / RESET
-- =============================================================================

-- Apply button: sends all staged changes to the server
local btnApply = xlib.makebutton{x = 445, y = y, w = 100, h = 25, label = "Apply", parent = canvas}
btnApply.DoClick = function()
	for cvarName, val in pairs(stagedChanges) do
		SendConfigChange(cvarName, val)
	end
	stagedChanges = {}
	surface.PlaySound("buttons/button14.wav")
end

-- Reset button: discards staged changes and reverts controls to current ConVar values
local btnReset = xlib.makebutton{x = 335, y = y, w = 100, h = 25, label = "Reset", parent = canvas}
btnReset.DoClick = function()
	stagedChanges = {}

	-- Revert each control to its current ConVar value
	local cvE = GetConVar("pvplb_enabled")
	if cvE then cbEnabled:SetChecked(cvE:GetBool()) end

	local cvM = GetConVar("pvplb_max_entries")
	if cvM then sMaxEntries:SetValue(cvM:GetFloat()) end

	local cvC = GetConVar("pvplb_cache_interval")
	if cvC then sCacheInterval:SetValue(cvC:GetFloat()) end

	surface.PlaySound("buttons/button14.wav")
end

y = y + 40

-- Set canvas height so the scroll panel knows the content size
canvas:SetTall(y)

-- =============================================================================
-- REGISTER
-- =============================================================================

-- Register this panel with XGUI under the Settings tab
xgui.addSettingModule("PVP Leaderboard", panel, "icon16/medal_gold_1.png")
