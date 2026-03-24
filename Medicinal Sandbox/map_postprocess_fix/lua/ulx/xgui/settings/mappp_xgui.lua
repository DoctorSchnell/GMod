-- Map Post-Process Fix - XGUI Settings Panel
-- Addon by Doctor Schnell
--
-- Provides an admin panel inside XGUI for viewing, adding, editing,
-- and removing per-map post-processing configs. The layout is a map
-- list on the left with a settings form on the right.
--
-- Panel placement follows the convention: lua/ulx/xgui/settings/
-- so XGUI loads it after its own initialization is complete.
-- Uses xlib.makepanel with xgui.null as the parent, then registers
-- via xgui.addSettingModule at the bottom.

local PANEL_W = 585  -- Standard XGUI settings panel width.
local PANEL_H = 322  -- Standard XGUI settings panel height.
local BLACK = Color(0, 0, 0, 255)

local mapPPPanel = xlib.makepanel{parent = xgui.null}

-- ============================================================
-- State tracking
-- ============================================================

-- Holds the full config table received from the server.
local cachedConfigs = {}

-- The map name currently selected in the list (lowercase).
local selectedMap = nil

-- Forward declarations for functions that reference each other.
local RefreshMapList, PopulateForm, ClearForm

-- ============================================================
-- Helper: apply black text to a DNumSlider
-- ============================================================

-- DNumSlider has child elements (Label, TextArea) that inherit the
-- default grey skin color. This helper digs in and forces black text
-- on both the label and the numeric entry field.
local function StyleSliderBlack(slider)
    if IsValid(slider.Label) then
        slider.Label:SetTextColor(BLACK)
    end
    if IsValid(slider.TextArea) then
        slider.TextArea:SetTextColor(BLACK)
    end
end

-- ============================================================
-- Master toggle
-- ============================================================

-- We intentionally do NOT bind this checkbox to the ConVar with
-- the convar parameter. mappp_enabled is FCVAR_REPLICATED, which
-- means only the server can change it. Binding via convar would
-- cause "Can't change replicated ConVar from console of client"
-- errors. Instead we read the ConVar for display and send a net
-- message to the server when the admin clicks it.
local enableCheck = vgui.Create("DCheckBoxLabel", mapPPPanel)
enableCheck:SetPos(10, 8)
enableCheck:SetSize(300, 20)
enableCheck:SetText("Enable Map Post-Processing Overrides")
enableCheck:SetTextColor(BLACK)

-- Guard flag so OnChange doesn't fire net messages when we call
-- SetValue programmatically (e.g. on panel open or ConVar sync).
local settingCheckboxProgrammatically = false

-- Read the current server value for the initial checkbox state.
local cv_enabled = GetConVar("mappp_enabled")
if cv_enabled then
    settingCheckboxProgrammatically = true
    enableCheck:SetValue(cv_enabled:GetBool() and 1 or 0)
    settingCheckboxProgrammatically = false
end

-- When the admin clicks the checkbox, tell the server to flip it.
-- The guard flag prevents this from firing during programmatic updates.
enableCheck.OnChange = function(self, val)
    if settingCheckboxProgrammatically then return end

    net.Start("MapPP_SetEnabled")
        net.WriteBool(val)
    net.SendToServer()
end

-- Keep the checkbox in sync if another admin changes it while the
-- panel is open. The replicated ConVar updates on all clients when
-- the server changes it, so we just watch for that.
cvars.AddChangeCallback("mappp_enabled", function(name, oldVal, newVal)
    if IsValid(enableCheck) then
        settingCheckboxProgrammatically = true
        enableCheck:SetValue(tonumber(newVal) == 1 and 1 or 0)
        settingCheckboxProgrammatically = false
    end
end, "MapPP_XGUISync")

-- ============================================================
-- Map list (left side)
-- ============================================================

local listLabel = xlib.makelabel{
    label  = "Configured Maps:",
    parent = mapPPPanel
}
listLabel:SetPos(10, 36)

local mapList = vgui.Create("DListView", mapPPPanel)
mapList:SetPos(10, 52)
mapList:SetSize(200, 230)
mapList:AddColumn("Map Name")
mapList:SetMultiSelect(false)

-- When a row is selected, load its settings into the form.
mapList.OnRowSelected = function(self, index, row)
    local mapName = row:GetColumnText(1)
    selectedMap = mapName
    PopulateForm(mapName)
end

-- ============================================================
-- Settings form (right side)
-- ============================================================

-- Leave a comfortable gap between the map list and the form so
-- slider labels don't bleed into the list area. The map list ends
-- at x=210, so starting at 225 gives a 15px gutter.
local formX = 225
local sliderW = 340  -- Width of DNumSlider controls.

local formLabel = xlib.makelabel{label = "Map Settings:", parent = mapPPPanel}
formLabel:SetPos(formX, 36)

-- Map name entry. Editable so admins can type a new map name when adding.
local nameLabel = xlib.makelabel{label = "Map Name:", parent = mapPPPanel}
nameLabel:SetPos(formX, 56)

local nameEntry = vgui.Create("DTextEntry", mapPPPanel)
nameEntry:SetPos(formX + 75, 54)
nameEntry:SetSize(200, 20)
nameEntry:SetPlaceholderText("e.g. gm_blackmesa_sigma")

-- Tonemap Scale: the primary fix for overbright HDR.
-- 0 = engine auto (map-controlled), 0.5 to 1.0 tames most problem maps.
local tonemapCheck = vgui.Create("DCheckBoxLabel", mapPPPanel)
tonemapCheck:SetPos(formX, 86)
tonemapCheck:SetSize(200, 20)
tonemapCheck:SetText("Override Tonemap Scale")
tonemapCheck:SetTextColor(BLACK)
tonemapCheck:SetValue(0)

local tonemapSlider = vgui.Create("DNumSlider", mapPPPanel)
tonemapSlider:SetPos(formX, 106)
tonemapSlider:SetSize(sliderW, 30)
tonemapSlider:SetText("Tonemap Scale")
tonemapSlider:SetMin(0)
tonemapSlider:SetMax(3)
tonemapSlider:SetDecimals(2)
tonemapSlider:SetValue(0.7)
StyleSliderBlack(tonemapSlider)

-- Bloom Scale: engine-level bloom. 0 kills bloom entirely.
local bloomCheck = vgui.Create("DCheckBoxLabel", mapPPPanel)
bloomCheck:SetPos(formX, 140)
bloomCheck:SetSize(200, 20)
bloomCheck:SetText("Override Bloom Scale")
bloomCheck:SetTextColor(BLACK)
bloomCheck:SetValue(0)

local bloomSlider = vgui.Create("DNumSlider", mapPPPanel)
bloomSlider:SetPos(formX, 160)
bloomSlider:SetSize(sliderW, 30)
bloomSlider:SetText("Bloom Scale")
bloomSlider:SetMin(0)
bloomSlider:SetMax(3)
bloomSlider:SetDecimals(2)
bloomSlider:SetValue(0.0)
StyleSliderBlack(bloomSlider)

-- Specular: whether shiny reflections appear on world brushes.
local specularCheck = vgui.Create("DCheckBoxLabel", mapPPPanel)
specularCheck:SetPos(formX, 198)
specularCheck:SetSize(200, 20)
specularCheck:SetText("Override Specular")
specularCheck:SetTextColor(BLACK)
specularCheck:SetValue(0)

local specularEnabled = vgui.Create("DCheckBoxLabel", mapPPPanel)
specularEnabled:SetPos(formX + 20, 218)
specularEnabled:SetSize(200, 20)
specularEnabled:SetText("Specular Enabled")
specularEnabled:SetTextColor(BLACK)
specularEnabled:SetValue(1)

-- ============================================================
-- Action buttons
-- ============================================================

-- Save: sends the form values to the server for the named map.
local saveBtn = vgui.Create("DButton", mapPPPanel)
saveBtn:SetPos(formX, 252)
saveBtn:SetSize(100, 25)
saveBtn:SetText("Save")
saveBtn:SetEnabled(true)

saveBtn.DoClick = function()
    local mapName = string.lower(string.Trim(nameEntry:GetValue()))

    if mapName == "" then
        Derma_Message("Enter a map name before saving.", "Map Post-Process Fix", "OK")
        return
    end

    if not string.match(mapName, "^[%w_%-]+$") then
        Derma_Message("Map name can only contain letters, numbers, underscores, and hyphens.", "Map Post-Process Fix", "OK")
        return
    end

    -- Build the values. Unchecked override checkboxes send -1 (don't touch).
    local tonemapVal = tonemapCheck:GetChecked() and tonemapSlider:GetValue() or -1
    local bloomVal   = bloomCheck:GetChecked() and bloomSlider:GetValue() or -1
    local specVal    = specularCheck:GetChecked() and (specularEnabled:GetChecked() and 1 or 0) or -1

    net.Start("MapPP_UpdateMapConfig")
        net.WriteString(mapName)
        net.WriteFloat(tonemapVal)
        net.WriteFloat(bloomVal)
        net.WriteFloat(specVal)
    net.SendToServer()

    -- Optimistically update our local cache so the list refreshes
    -- without waiting for a full round-trip.
    cachedConfigs[mapName] = {
        tonemap_scale = tonemapVal,
        bloom_scale   = bloomVal,
        mat_specular  = specVal
    }

    RefreshMapList()
end

-- Remove: deletes the selected map's config entry.
local removeBtn = vgui.Create("DButton", mapPPPanel)
removeBtn:SetPos(formX + 110, 252)
removeBtn:SetSize(100, 25)
removeBtn:SetText("Remove")
removeBtn:SetEnabled(true)

removeBtn.DoClick = function()
    local mapName = string.lower(string.Trim(nameEntry:GetValue()))

    if mapName == "" then return end

    Derma_Query(
        "Remove config for " .. mapName .. "?",
        "Confirm Removal",
        "Yes", function()
            net.Start("MapPP_RemoveMapConfig")
                net.WriteString(mapName)
            net.SendToServer()

            cachedConfigs[mapName] = nil
            selectedMap = nil
            RefreshMapList()
            ClearForm()
        end,
        "No", function() end
    )
end

-- Refresh: re-fetches the full config table from the server.
local refreshBtn = vgui.Create("DButton", mapPPPanel)
refreshBtn:SetPos(10, 286)
refreshBtn:SetSize(200, 25)
refreshBtn:SetText("Refresh from Server")
refreshBtn:SetEnabled(true)

refreshBtn.DoClick = function()
    net.Start("MapPP_RequestFullConfig")
    net.SendToServer()
end

-- ============================================================
-- Form population helpers
-- ============================================================

-- Fills the right-side form controls with a map's stored settings.
PopulateForm = function(mapName)
    local config = cachedConfigs[string.lower(mapName)]
    nameEntry:SetValue(mapName)

    if not config then
        ClearForm()
        nameEntry:SetValue(mapName)
        return
    end

    -- Tonemap: check the override box if the value is not -1.
    local hasTonemapOverride = (config.tonemap_scale and config.tonemap_scale >= 0)
    tonemapCheck:SetValue(hasTonemapOverride and 1 or 0)
    tonemapSlider:SetValue(hasTonemapOverride and config.tonemap_scale or 0.7)

    -- Bloom: same logic.
    local hasBloomOverride = (config.bloom_scale and config.bloom_scale >= 0)
    bloomCheck:SetValue(hasBloomOverride and 1 or 0)
    bloomSlider:SetValue(hasBloomOverride and config.bloom_scale or 0.0)

    -- Specular: the override checkbox gates the inner enable/disable checkbox.
    local hasSpecOverride = (config.mat_specular and config.mat_specular >= 0)
    specularCheck:SetValue(hasSpecOverride and 1 or 0)
    specularEnabled:SetValue(hasSpecOverride and config.mat_specular or 1)
end

-- Resets all form controls to their empty/default state.
ClearForm = function()
    nameEntry:SetValue("")
    tonemapCheck:SetValue(0)
    tonemapSlider:SetValue(0.7)
    bloomCheck:SetValue(0)
    bloomSlider:SetValue(0.0)
    specularCheck:SetValue(0)
    specularEnabled:SetValue(1)
end

-- ============================================================
-- Map list population
-- ============================================================

-- Rebuilds the DListView rows from the cached config table.
RefreshMapList = function()
    mapList:Clear()

    for mapName, _ in SortedPairs(cachedConfigs) do
        mapList:AddLine(mapName)
    end

    -- Re-select the previously selected map if it still exists.
    if selectedMap and cachedConfigs[selectedMap] then
        for _, line in ipairs(mapList:GetLines()) do
            if line:GetColumnText(1) == selectedMap then
                mapList:SelectItem(line)
                break
            end
        end
    end
end

-- ============================================================
-- Server response handler
-- ============================================================

-- When the server sends back the full config table, parse it and
-- rebuild the list. This fires on panel open and on manual refresh.
net.Receive("MapPP_FullConfig", function()
    local encoded = net.ReadString()
    local decoded = util.JSONToTable(encoded)

    if decoded then
        cachedConfigs = decoded
    else
        cachedConfigs = {}
    end

    RefreshMapList()
end)

-- ============================================================
-- Panel open behavior
-- ============================================================

-- Every time the panel becomes visible, request fresh data from
-- the server so we're never looking at stale settings. Also sync
-- the master toggle checkbox with the current ConVar value.
mapPPPanel.onOpen = function()
    local cv = GetConVar("mappp_enabled")
    if cv and IsValid(enableCheck) then
        settingCheckboxProgrammatically = true
        enableCheck:SetValue(cv:GetBool() and 1 or 0)
        settingCheckboxProgrammatically = false
    end

    net.Start("MapPP_RequestFullConfig")
    net.SendToServer()
end

-- Also request once at load time so the cache is pre-populated.
-- If the player opens XGUI before the onOpen fires (or if XGUI
-- doesn't call onOpen reliably), this ensures data is available.
timer.Simple(3, function()
    net.Start("MapPP_RequestFullConfig")
    net.SendToServer()
end)

-- ============================================================
-- Register with XGUI
-- ============================================================

xgui.addSettingModule("Map Post-Process", mapPPPanel, "icon16/picture_edit.png")
