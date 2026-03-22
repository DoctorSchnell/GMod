-- =============================================================================
--  PVP Combat Timer - XGUI Settings Panel
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Uses xlib helpers and xgui.null parent pattern (matching AFK System addon).
-- =============================================================================

-- Helper to send a config change to the server via net message
local function SendConfigChange(cvarName, value)
	net.Start("PVPCombat_ConfigChange")
	net.WriteString(cvarName)
	net.WriteString(tostring(value))
	net.SendToServer()
end

local panel = xlib.makepanel{parent = xgui.null}

-- Scroll panel fills the main panel
local scroll = vgui.Create("DScrollPanel", panel)
scroll:SetPos(0, 0)

panel.PerformLayout = function(self, w, h)
	scroll:SetSize(w, h)
end

local canvas = scroll:GetCanvas()
local stagedChanges = {}
local y = 5

-- =============================================================================
-- GENERAL
-- =============================================================================

xlib.makelabel{x = 5, y = y, label = "-- General --", textcolor = Color(200, 140, 0), parent = canvas}
y = y + 18

local cbEnabled = xlib.makecheckbox{x = 5, y = y, label = "System Enabled", parent = canvas, textcolor = color_black}
local cv = GetConVar("pvpcombat_enabled")
if cv then cbEnabled:SetChecked(cv:GetBool()) end
cbEnabled.OnChange = function(self, val) stagedChanges["pvpcombat_enabled"] = val and "1" or "0" end
y = y + 22

local sCooldown = xlib.makeslider{x = 5, y = y, w = 545, label = "Combat Cooldown (seconds)", min = 5, max = 30, decimal = 0, parent = canvas, textcolor = color_black}
cv = GetConVar("pvpcombat_cooldown")
if cv then sCooldown:SetValue(cv:GetFloat()) end
sCooldown.OnValueChanged = function(self, val) stagedChanges["pvpcombat_cooldown"] = math.Round(val) end
y = y + 28

-- =============================================================================
-- SPAWN BLOCKLIST
-- =============================================================================

xlib.makelabel{x = 5, y = y, label = "-- Blocked Entities (restricted during combat) --", textcolor = Color(200, 140, 0), parent = canvas}
y = y + 18

-- DListView for the blocklist (no xlib equivalent)
local blockList = vgui.Create("DListView", canvas)
blockList:SetPos(5, y)
blockList:SetSize(545, 150)
blockList:SetMultiSelect(false)
blockList:AddColumn("Entity Class")
y = y + 155

--- Refresh the blocklist from its ConVar
local function RefreshBlocklist()
	blockList:Clear()
	local cvar = GetConVar("pvpcombat_blocklist")
	if not cvar then return end

	for entry in string.gmatch(cvar:GetString(), "([^;]+)") do
		entry = string.Trim(entry)
		if entry ~= "" then blockList:AddLine(entry) end
	end
end

--- Build the blocklist string from the DListView rows
local function BuildBlocklistString()
	local entries = {}
	for _, line in ipairs(blockList:GetLines()) do
		local val = line:GetColumnText(1)
		if val and val ~= "" then table.insert(entries, val) end
	end
	return table.concat(entries, ";")
end

-- Text entry + Add button
local addEntry = vgui.Create("DTextEntry", canvas)
addEntry:SetPos(5, y)
addEntry:SetSize(440, 24)
addEntry:SetPlaceholderText("Entity class name (e.g. item_healthkit)")

local btnAdd = xlib.makebutton{x = 450, y = y, w = 100, h = 24, label = "Add", parent = canvas}
btnAdd.DoClick = function()
	local class = string.Trim(string.lower(addEntry:GetValue()))
	if class == "" then return end

	for _, line in ipairs(blockList:GetLines()) do
		if string.lower(line:GetColumnText(1)) == class then
			Derma_Message(class .. " is already in the blocklist.", "Duplicate Entry", "OK")
			return
		end
	end

	blockList:AddLine(class)
	addEntry:SetValue("")
	stagedChanges["pvpcombat_blocklist"] = BuildBlocklistString()
end
y = y + 30

-- Remove / Reset buttons
local btnRemove = xlib.makebutton{x = 5, y = y, w = 268, h = 24, label = "Remove Selected", parent = canvas}
btnRemove.DoClick = function()
	local selected = blockList:GetSelectedLine()
	if not selected then
		Derma_Message("Select an entry to remove.", "No Selection", "OK")
		return
	end

	blockList:RemoveLine(selected)
	stagedChanges["pvpcombat_blocklist"] = BuildBlocklistString()
end

local btnReset = xlib.makebutton{x = 282, y = y, w = 268, h = 24, label = "Reset to Defaults", parent = canvas}
btnReset.DoClick = function()
	Derma_Query(
		"Reset the blocklist to defaults (item_healthkit, item_battery)?",
		"Confirm Reset",
		"Yes", function()
			blockList:Clear()
			blockList:AddLine("item_healthkit")
			blockList:AddLine("item_battery")
			stagedChanges["pvpcombat_blocklist"] = "item_healthkit;item_battery"
		end,
		"No", function() end
	)
end
y = y + 34

-- =============================================================================
-- PICKUP BLOCKING
-- =============================================================================

xlib.makelabel{x = 5, y = y, label = "-- Pickup Blocking --", textcolor = Color(200, 140, 0), parent = canvas}
y = y + 18

local cbPickup = xlib.makecheckbox{x = 5, y = y, label = "Block Pickup During Combat (uses the same blocklist above)", parent = canvas, textcolor = color_black}
cv = GetConVar("pvpcombat_block_pickup")
if cv then cbPickup:SetChecked(cv:GetBool()) end
cbPickup.OnChange = function(self, val) stagedChanges["pvpcombat_block_pickup"] = val and "1" or "0" end
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

local btnRevert = xlib.makebutton{x = 335, y = y, w = 100, h = 25, label = "Reset", parent = canvas}
btnRevert.DoClick = function()
	stagedChanges = {}
	RefreshBlocklist()

	-- Reset controls to current ConVar values
	local cvE = GetConVar("pvpcombat_enabled")
	if cvE then cbEnabled:SetChecked(cvE:GetBool()) end
	local cvC = GetConVar("pvpcombat_cooldown")
	if cvC then sCooldown:SetValue(cvC:GetFloat()) end
	local cvP = GetConVar("pvpcombat_block_pickup")
	if cvP then cbPickup:SetChecked(cvP:GetBool()) end

	surface.PlaySound("buttons/button14.wav")
end

y = y + 40

-- Set canvas height so scroll panel knows content size
canvas:SetTall(y)

-- Initial populate
RefreshBlocklist()

-- =============================================================================
-- REGISTER
-- =============================================================================

xgui.addSettingModule("PVP Combat Timer", panel, "icon16/shield.png")
