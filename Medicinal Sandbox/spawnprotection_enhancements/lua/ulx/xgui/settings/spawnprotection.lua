-- =============================================================================
--  Spawn Protection Enhancements - XGUI Settings Panel
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  XGUI settings tab for the Spawn Protection Workshop addon. Reads config
--  values synced from the server via net message (see
--  sh_spawnprotection_enhancements.lua) and sends changes back through the
--  same channel with server-side permission validation.
-- =============================================================================

local function GetConfig()
    return SpawnProtEnh and SpawnProtEnh.Config or {}
end

-- =============================================================================
-- Build the panel at file scope (xgui.null is a placeholder parent that
-- XGUI reparents when the settings tab is opened)
-- =============================================================================
local panel = xlib.makepanel{parent = xgui.null}

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

local chkEnable = xlib.makecheckbox{label = "Enable Spawn Protection", parent = canvas}
chkEnable:SetPos(0, y)
chkEnable.OnChange = function(self, val)
    if suppressCallbacks then return end
    stagedChanges["sv_spawnprotection_enable"] = val and "1" or "0"
end
y = y + 25

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

local chkNoDamage = xlib.makecheckbox{label = "Prevent Protected Players Dealing Damage", parent = canvas}
chkNoDamage:SetPos(0, y)
chkNoDamage.OnChange = function(self, val)
    if suppressCallbacks then return end
    stagedChanges["sv_spawnprotection_no_damage"] = val and "1" or "0"
end
y = y + 25

local chkNoTarget = xlib.makecheckbox{label = "NPCs Ignore Protected Players", parent = canvas}
chkNoTarget:SetPos(0, y)
chkNoTarget.OnChange = function(self, val)
    if suppressCallbacks then return end
    stagedChanges["sv_spawnprotection_no_target"] = val and "1" or "0"
end
y = y + 25

local chkCancelOnFire = xlib.makecheckbox{label = "Cancel Protection When Player Fires", parent = canvas}
chkCancelOnFire:SetPos(0, y)
chkCancelOnFire.OnChange = function(self, val)
    if suppressCallbacks then return end
    stagedChanges["sv_spawnprotection_cancel_on_fire"] = val and "1" or "0"
end
y = y + 30

-- =============================================================================
-- Visual / Notification Settings (Admin)
-- =============================================================================

local headerVisual = xlib.makelabel{label = "Visual / Notification (Admin)", parent = canvas}
headerVisual:SetPos(0, y)
headerVisual:SetFont("DermaDefaultBold")
y = y + 20

local chkNotify = xlib.makecheckbox{label = "Enable Chat Notifications", parent = canvas}
chkNotify:SetPos(0, y)
chkNotify.OnChange = function(self, val)
    if suppressCallbacks then return end
    stagedChanges["sv_spawnprotection_notification"] = val and "1" or "0"
end
y = y + 25

local chkBubble = xlib.makecheckbox{label = "Enable Protection Bubble", parent = canvas}
chkBubble:SetPos(0, y)
chkBubble.OnChange = function(self, val)
    if suppressCallbacks then return end
    stagedChanges["sv_spawnprotection_bubble"] = val and "1" or "0"
end
y = y + 35

-- =============================================================================
-- Helper to populate all controls from the server config table.
-- =============================================================================
local function PopulateControls()
    local cfg = GetConfig()
    suppressCallbacks = true

    chkEnable:SetValue(cfg.enable or false)
    sliderDuration:SetValue(cfg.duration or 5)
    chkNoDamage:SetValue(cfg.no_damage or false)
    chkNoTarget:SetValue(cfg.no_target or false)
    chkCancelOnFire:SetValue(cfg.cancel_on_fire == nil and true or cfg.cancel_on_fire)
    chkNotify:SetValue(cfg.notification or false)
    chkBubble:SetValue(cfg.bubble or false)

    suppressCallbacks = false
end

PopulateControls()

-- =============================================================================
-- Apply / Reset
-- =============================================================================

local btnApply = xlib.makebutton{label = "Apply", parent = canvas, w = 80, h = 28}
btnApply:SetPos(0, y)
btnApply.DoClick = function()
    local count = 0
    for _ in pairs(stagedChanges) do
        count = count + 1
    end

    if count == 0 then return end

    net.Start("SpawnProtEnh_Update")
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
-- =============================================================================

local wasVisible = false

panel.Think = function(self)
    local nowVisible = self:IsVisible()

    if nowVisible and not wasVisible then
        net.Start("SpawnProtEnh_RequestSync")
        net.SendToServer()
    end

    wasVisible = nowVisible
end

hook.Add("SpawnProtEnh_ConfigUpdated", "SpawnProtEnh_XGUIRefresh", function()
    if not IsValid(panel) then return end

    if next(stagedChanges) ~= nil then return end

    PopulateControls()
end)

xgui.addSettingModule("Spawn Protection", panel, "icon16/shield.png")

-- End of spawnprotection.lua (XGUI settings panel)
