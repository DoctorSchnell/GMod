-- =============================================================================
-- Spawn Protection ULX Patch
-- XGUI settings panel
-- =============================================================================
-- Replaces the original addon's broken spawnmenu panel with an XGUI settings
-- tab. Reads config values synced from the server via net message (see
-- sh_spawnprotection_ulx.lua) and sends changes back through the same channel
-- with server-side permission validation.
--
-- Uses the standard XGUI pattern: panel created at file scope with xgui.null
-- as a placeholder parent, DScrollPanel with canvas, absolute y-positioning,
-- staged changes with Apply/Reset buttons.
--
-- Callbacks are suppressed during programmatic SetValue calls (init, reset,
-- live refresh) so only deliberate user interaction populates stagedChanges.
-- All staged changes are sent in a single bundled net message on Apply.
-- =============================================================================

-- Helper to get the current synced config from the server
local function GetConfig()
    return SpawnProtULX and SpawnProtULX.Config or {}
end

-- -------------------------------------------------------------------------
-- Build the panel at file scope (xgui.null is a placeholder parent that
-- XGUI reparents when the settings tab is opened)
-- -------------------------------------------------------------------------
local panel = xlib.makepanel{parent = xgui.null}

-- Scrollable container
local scroll = vgui.Create("DScrollPanel", panel)
scroll:Dock(FILL)
scroll:DockMargin(4, 4, 4, 4)

local canvas = scroll:GetCanvas()
canvas:DockPadding(8, 8, 8, 8)

local y = 0
local stagedChanges = {}

-- When true, OnChange/OnValueChanged callbacks will not write to
-- stagedChanges. Set during initialization, Reset, and live refresh.
local suppressCallbacks = true

-- =============================================================================
-- Core Settings (SuperAdmin)
-- =============================================================================

local headerCore = xlib.makelabel{label = "Core Settings (SuperAdmin)", parent = canvas}
headerCore:SetPos(0, y)
headerCore:SetFont("DermaDefaultBold")
y = y + 20

-- Enable spawn protection
local chkEnable = xlib.makecheckbox{label = "Enable Spawn Protection", parent = canvas}
chkEnable:SetPos(0, y)
chkEnable.OnChange = function(self, val)
    if suppressCallbacks then return end
    stagedChanges["sv_spawnprotection_enable"] = val and "1" or "0"
end
y = y + 25

-- Protection duration
local sliderDuration = xlib.makeslider{
    label = "Protection Duration (seconds)",
    parent = canvas,
    min = 1,
    max = 60,
    decimal = 0,
}
sliderDuration:SetPos(0, y)
sliderDuration:SetSize(300, 40)
sliderDuration.OnValueChanged = function(self, val)
    if suppressCallbacks then return end
    stagedChanges["sv_spawnprotection_duration"] = tostring(math.floor(val))
end
y = y + 45

-- Prevent protected players from dealing damage
local chkNoDamage = xlib.makecheckbox{label = "Prevent Protected Players Dealing Damage", parent = canvas}
chkNoDamage:SetPos(0, y)
chkNoDamage.OnChange = function(self, val)
    if suppressCallbacks then return end
    stagedChanges["sv_spawnprotection_no_damage"] = val and "1" or "0"
end
y = y + 25

-- NPCs ignore protected players
local chkNoTarget = xlib.makecheckbox{label = "NPCs Ignore Protected Players", parent = canvas}
chkNoTarget:SetPos(0, y)
chkNoTarget.OnChange = function(self, val)
    if suppressCallbacks then return end
    stagedChanges["sv_spawnprotection_no_target"] = val and "1" or "0"
end
y = y + 30

-- =============================================================================
-- Visual / Notification Settings (Admin)
-- =============================================================================

local headerVisual = xlib.makelabel{label = "Visual / Notification (Admin)", parent = canvas}
headerVisual:SetPos(0, y)
headerVisual:SetFont("DermaDefaultBold")
y = y + 20

-- Chat notifications
local chkNotify = xlib.makecheckbox{label = "Enable Chat Notifications", parent = canvas}
chkNotify:SetPos(0, y)
chkNotify.OnChange = function(self, val)
    if suppressCallbacks then return end
    stagedChanges["sv_spawnprotection_notification"] = val and "1" or "0"
end
y = y + 25

-- Bubble visual effect
local chkBubble = xlib.makecheckbox{label = "Enable Protection Bubble", parent = canvas}
chkBubble:SetPos(0, y)
chkBubble.OnChange = function(self, val)
    if suppressCallbacks then return end
    stagedChanges["sv_spawnprotection_bubble"] = val and "1" or "0"
end
y = y + 35

-- -------------------------------------------------------------------------
-- Helper to populate all controls from the server config table.
-- Wraps SetValue calls in suppressCallbacks so they do not generate
-- staged changes.
-- -------------------------------------------------------------------------
local function PopulateControls()
    local cfg = GetConfig()
    suppressCallbacks = true

    chkEnable:SetValue(cfg.enable or false)
    sliderDuration:SetValue(cfg.duration or 5)
    chkNoDamage:SetValue(cfg.no_damage or false)
    chkNoTarget:SetValue(cfg.no_target or false)
    chkNotify:SetValue(cfg.notification or false)
    chkBubble:SetValue(cfg.bubble or false)

    suppressCallbacks = false
end

-- Set initial values (suppressed, so stagedChanges stays empty)
PopulateControls()

-- =============================================================================
-- Apply / Reset
-- =============================================================================

local btnApply = xlib.makebutton{label = "Apply", parent = canvas, w = 80, h = 28}
btnApply:SetPos(0, y)
btnApply.DoClick = function()
    -- Count how many changes we have
    local count = 0
    for _ in pairs(stagedChanges) do
        count = count + 1
    end

    if count == 0 then return end

    -- Send all changes in a single net message
    net.Start("SpawnProtULX_Update")
        net.WriteUInt(count, 4)
        for cvarName, value in pairs(stagedChanges) do
            net.WriteString(cvarName)
            net.WriteString(value)
        end
    net.SendToServer()

    stagedChanges = {}
end

local btnReset = xlib.makebutton{label = "Reset", parent = canvas, w = 80, h = 28}
btnReset:SetPos(90, y)
btnReset.DoClick = function()
    PopulateControls()
    stagedChanges = {}
end

y = y + 35
canvas:SetTall(y)

-- =============================================================================
-- Auto-refresh when the panel becomes visible
-- The panel is built at file scope before the server sync arrives, so the
-- initial PopulateControls runs against an empty config table. When the user
-- opens the Spawn Protection settings tab, we request a fresh sync from the
-- server. The response arrives via SpawnProtULX_Sync, updates Config, fires
-- the ConfigUpdated hook, and the handler below repopulates the controls.
-- =============================================================================

local wasVisible = false

panel.Think = function(self)
    local nowVisible = self:IsVisible()

    -- On visibility transition (closed -> open), ask the server for
    -- the current config. The response will trigger ConfigUpdated.
    if nowVisible and not wasVisible then
        net.Start("SpawnProtULX_RequestSync")
        net.SendToServer()
    end

    wasVisible = nowVisible
end

hook.Add("SpawnProtULX_ConfigUpdated", "SpawnProtULX_XGUIRefresh", function()
    if not IsValid(panel) then return end

    -- Skip refresh if the user has unsaved changes
    if next(stagedChanges) ~= nil then return end

    PopulateControls()
end)

-- Register with XGUI (pass the panel object, not a builder function)
xgui.addSettingModule("Spawn Protection", panel, "icon16/shield.png")

-- End of spawnprotection.lua (XGUI settings panel)
