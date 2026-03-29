-- =============================================================================
--  Persistent Punishments - XGUI Management Tab
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Top-level XGUI tab (next to Bans) for applying, viewing, editing, and
--  removing persistent punishments.
-- =============================================================================

local ppanel = xlib.makepanel{parent = xgui.null}

-- =============================================================================
-- APPLY PUNISHMENT — PLAYER LIST
-- =============================================================================

xlib.makelabel{x = 5, y = 5, label = "— Apply Punishment —", textcolor = Color(200, 140, 0), parent = ppanel}

-- Player list: click to select a target
ppanel.playerlist = xlib.makelistview{x = 5, y = 22, w = 350, h = 80, multiselect = false, parent = ppanel}
ppanel.playerlist:AddColumn("Player"):SetFixedWidth(150)
ppanel.playerlist:AddColumn("SteamID"):SetFixedWidth(140)

function ppanel.RefreshPlayerList()
    ppanel.playerlist:Clear()
    for _, ply in ipairs(player.GetAll()) do
        if not ply:IsBot() then
            ppanel.playerlist:AddLine(ply:Nick(), ply:SteamID())
        end
    end
end

-- Punishment controls next to player list
xlib.makelabel{x = 365, y = 22, label = "Type:", parent = ppanel}
ppanel.applyType = xlib.makecombobox{x = 365, y = 38, w = 95, choices = {"gag", "mute", "freeze", "jail"}, parent = ppanel}
ppanel.applyType:ChooseOptionID(1)

xlib.makelabel{x = 470, y = 22, label = "Duration:", parent = ppanel}
ppanel.applyDuration = xlib.maketextbox{x = 470, y = 38, w = 50, text = "0", selectall = true, parent = ppanel}
xlib.makelabel{x = 525, y = 41, label = "min", parent = ppanel}
xlib.makelabel{x = 470, y = 56, label = "(0 = permanent)", parent = ppanel}

xlib.makebutton{x = 365, y = 78, w = 212, h = 24, label = "Apply to Selected Player", parent = ppanel}.DoClick = function()
    local selected = ppanel.playerlist:GetSelectedLine()
    if not selected then
        Derma_Message("Select a player from the list.", "Error", "OK")
        return
    end

    local line = ppanel.playerlist:GetLine(selected)
    local playerName = line:GetValue(1)
    local punishType = ppanel.applyType:GetValue()
    local reason = ppanel.applyReason:GetText()
    local minutes = tonumber(ppanel.applyDuration:GetText())

    if not minutes or minutes < 0 then
        Derma_Message("Invalid duration.", "Error", "OK")
        return
    end
    if not reason or reason == "" then
        Derma_Message("Please provide a reason.", "Error", "OK")
        return
    end

    RunConsoleCommand("ulx", "p" .. punishType, playerName, tostring(math.Round(minutes)), reason)
    ppanel.applyReason:SetText("")
    ppanel.applyDuration:SetText("0")
    timer.Simple(1, function() ppanel.RequestList() end)
end

-- =============================================================================
-- APPLY BY STEAMID + REASON ROW
-- =============================================================================

xlib.makelabel{x = 5, y = 107, label = "SteamID:", parent = ppanel}
ppanel.applySteamID = xlib.maketextbox{x = 58, y = 104, w = 130, text = "", selectall = true, parent = ppanel}

xlib.makebutton{x = 193, y = 104, w = 100, h = 20, label = "Apply by SteamID", parent = ppanel}.DoClick = function()
    local steamid = ppanel.applySteamID:GetText()
    local punishType = ppanel.applyType:GetValue()
    local reason = ppanel.applyReason:GetText()
    local minutes = tonumber(ppanel.applyDuration:GetText())

    if steamid == "" then
        Derma_Message("Please enter a SteamID.", "Error", "OK")
        return
    end
    if not minutes or minutes < 0 then
        Derma_Message("Invalid duration.", "Error", "OK")
        return
    end
    if not reason or reason == "" then
        Derma_Message("Please provide a reason.", "Error", "OK")
        return
    end

    RunConsoleCommand("ulx", "p" .. punishType .. "id", steamid, tostring(math.Round(minutes)), reason)
    ppanel.applySteamID:SetText("")
    ppanel.applyReason:SetText("")
    ppanel.applyDuration:SetText("0")
    timer.Simple(1, function() ppanel.RequestList() end)
end

xlib.makelabel{x = 300, y = 107, label = "Reason:", parent = ppanel}
ppanel.applyReason = xlib.maketextbox{x = 345, y = 104, w = 232, selectall = true, parent = ppanel}

-- =============================================================================
-- ACTIVE PUNISHMENTS LIST
-- =============================================================================

xlib.makelabel{x = 5, y = 128, label = "— Active Punishments —", textcolor = Color(200, 140, 0), parent = ppanel}

ppanel.punishlist = xlib.makelistview{x = 5, y = 168, w = 572, h = 150, multiselect = false, parent = ppanel}
ppanel.punishlist:AddColumn("Player"):SetFixedWidth(110)
ppanel.punishlist:AddColumn("Type"):SetFixedWidth(55)
ppanel.punishlist:AddColumn("Reason"):SetFixedWidth(155)
ppanel.punishlist:AddColumn("Admin"):SetFixedWidth(85)
ppanel.punishlist:AddColumn("Expires"):SetFixedWidth(90)

-- Right-click context menu
ppanel.punishlist.OnRowRightClick = function(self, lineID, line)
    local menu = DermaMenu()
    menu:SetSkin(xgui.settings.skin)
    menu:AddOption("Edit...", function()
        if not line:IsValid() then return end
        ppanel.ShowEditWindow(line.punishData)
    end)
    menu:AddOption("Remove", function()
        if not line:IsValid() then return end
        ppanel.ConfirmRemove(line.punishData)
    end)
    menu:Open()
end

-- Double-click to edit
ppanel.punishlist.DoDoubleClick = function(self, lineID, line)
    ppanel.ShowEditWindow(line.punishData)
end

-- =============================================================================
-- SEARCH / FILTER / BUTTONS
-- =============================================================================

local searchFilter = ""
ppanel.searchbox = xlib.maketextbox{x = 5, y = 144, w = 175, text = "Search...", selectall = true, parent = ppanel}
local txtCol = ppanel.searchbox:GetTextColor() or Color(0, 0, 0, 255)
ppanel.searchbox:SetTextColor(Color(txtCol.r, txtCol.g, txtCol.b, 196))
ppanel.searchbox.OnChange = function(pnl)
    if pnl:GetText() == "" then
        pnl:SetText("Search...")
        pnl:SelectAll()
        pnl:SetTextColor(Color(txtCol.r, txtCol.g, txtCol.b, 196))
    else
        pnl:SetTextColor(Color(txtCol.r, txtCol.g, txtCol.b, 255))
    end
end
ppanel.searchbox.OnLoseFocus = function(pnl)
    if pnl:GetText() == "Search..." then
        searchFilter = ""
    else
        searchFilter = string.lower(pnl:GetText())
    end
    ppanel.FilterList()
    hook.Call("OnTextEntryLoseFocus", nil, pnl)
end

local typeFilter = "All"
ppanel.typefilter = xlib.makecombobox{x = 185, y = 144, w = 100, text = "Type: All", choices = {"All", "Gag", "Mute", "Freeze", "Jail"}, parent = ppanel}
function ppanel.typefilter:OnSelect(i, v)
    typeFilter = v
    self:SetValue("Type: " .. v)
    ppanel.FilterList()
end

xlib.makebutton{x = 290, y = 144, w = 70, label = "Refresh", parent = ppanel}.DoClick = function()
    ppanel.RequestList()
end

xlib.makelabel{x = 5, y = 322, label = "Right-click a punishment for more options", parent = ppanel}

local btnRemove = xlib.makebutton{x = 477, y = 320, w = 100, h = 25, label = "Remove", parent = ppanel}
btnRemove.DoClick = function()
    local selected = ppanel.punishlist:GetSelectedLine()
    if not selected then return end
    local line = ppanel.punishlist:GetLine(selected)
    if not line or not line.punishData then return end
    ppanel.ConfirmRemove(line.punishData)
end

-- =============================================================================
-- HELPERS
-- =============================================================================

local TYPE_NAMES = {gag = "Gag", mute = "Mute", freeze = "Freeze", jail = "Jail"}
local allPunishments = {} -- Full unfiltered list from server

local function FormatExpiry(expiresAt)
    if expiresAt == 0 then return "Permanent" end
    local remaining = expiresAt - os.time()
    if remaining <= 0 then return "Expired" end

    local days = math.floor(remaining / 86400)
    remaining = remaining % 86400
    local hours = math.floor(remaining / 3600)
    remaining = remaining % 3600
    local mins = math.floor(remaining / 60)

    local parts = {}
    if days > 0 then table.insert(parts, days .. "d") end
    if hours > 0 then table.insert(parts, hours .. "h") end
    if mins > 0 then table.insert(parts, mins .. "m") end

    if #parts == 0 then return "< 1m" end
    return table.concat(parts, " ")
end

function ppanel.FilterList()
    ppanel.punishlist:Clear()

    for _, p in ipairs(allPunishments) do
        local typeName = TYPE_NAMES[p.punishment_type] or p.punishment_type

        -- Type filter
        if typeFilter ~= "All" and typeName ~= typeFilter then continue end

        -- Search filter
        if searchFilter ~= "" then
            local haystack = string.lower(p.player_name .. " " .. p.punishment_type .. " " .. p.reason .. " " .. p.admin_name .. " " .. p.steamid64)
            if not string.find(haystack, searchFilter, 1, true) then continue end
        end

        local reason = p.reason ~= "" and p.reason or "—"
        local expiry = FormatExpiry(p.expires_at)

        local line = ppanel.punishlist:AddLine(p.player_name, typeName, reason, p.admin_name, expiry)
        line.punishData = p
    end
end

function ppanel.RequestList()
    net.Start("PPunish_RequestList")
    net.SendToServer()
end

-- =============================================================================
-- NET RECEIVE
-- =============================================================================

net.Receive("PPunish_SendList", function()
    local count = net.ReadUInt(10)
    local punishments = {}

    for i = 1, count do
        table.insert(punishments, {
            id              = net.ReadUInt(32),
            player_name     = net.ReadString(),
            steamid64       = net.ReadString(),
            punishment_type = net.ReadString(),
            reason          = net.ReadString(),
            admin_name      = net.ReadString(),
            applied_at      = net.ReadInt(32),
            expires_at      = net.ReadInt(32),
        })
    end

    allPunishments = punishments
    ppanel.FilterList()
end)

-- =============================================================================
-- REMOVE CONFIRMATION
-- =============================================================================

function ppanel.ConfirmRemove(data)
    local typeName = TYPE_NAMES[data.punishment_type] or data.punishment_type
    Derma_Query(
        "Remove persistent " .. typeName .. " from " .. data.player_name .. "?",
        "Confirm Removal",
        "Remove", function()
            net.Start("PPunish_RemovePunishment")
            net.WriteUInt(data.id, 32)
            net.SendToServer()
            timer.Simple(0.5, function() ppanel.RequestList() end)
        end,
        "Cancel", function() end
    )
end

-- =============================================================================
-- EDIT WINDOW
-- =============================================================================

function ppanel.ShowEditWindow(data)
    local typeName = TYPE_NAMES[data.punishment_type] or data.punishment_type

    local frame = xlib.makeframe{label = "Edit Punishment — " .. typeName .. " on " .. data.player_name, w = 340, h = 175, skin = xgui.settings.skin}

    xlib.makelabel{x = 10, y = 33, label = "Player:", parent = frame}
    xlib.makelabel{x = 75, y = 33, label = data.player_name .. " (" .. data.steamid64 .. ")", parent = frame}

    xlib.makelabel{x = 10, y = 53, label = "Type:", parent = frame}
    xlib.makelabel{x = 75, y = 53, label = typeName, parent = frame}

    xlib.makelabel{x = 10, y = 78, label = "Reason:", parent = frame}
    local reasonBox = xlib.maketextbox{x = 75, y = 75, w = 255, parent = frame, selectall = true}
    reasonBox:SetText(data.reason or "")

    xlib.makelabel{x = 10, y = 108, label = "Duration:", parent = frame}

    local durationBox = xlib.maketextbox{x = 75, y = 105, w = 80, parent = frame, selectall = true}
    if data.expires_at == 0 then
        durationBox:SetText("0")
    else
        local remaining = math.max(0, data.expires_at - os.time())
        durationBox:SetText(tostring(math.ceil(remaining / 60)))
    end
    xlib.makelabel{x = 160, y = 108, label = "minutes (0 = permanent)", parent = frame}

    xlib.makebutton{x = 165, y = 140, w = 75, label = "Cancel", parent = frame}.DoClick = function()
        frame:Remove()
    end

    xlib.makebutton{x = 80, y = 140, w = 75, label = "Save", parent = frame}.DoClick = function()
        local newMinutes = tonumber(durationBox:GetText())
        if not newMinutes or newMinutes < 0 then
            Derma_Message("Invalid duration. Enter 0 for permanent or a positive number of minutes.")
            return
        end

        local newReason = reasonBox:GetText()

        net.Start("PPunish_UpdatePunishment")
        net.WriteUInt(data.id, 32)
        net.WriteInt(math.Round(newMinutes), 32)
        net.WriteString(newReason)
        net.SendToServer()

        frame:Remove()
        timer.Simple(0.5, function() ppanel.RequestList() end)
    end
end

-- =============================================================================
-- AUTO-REFRESH
-- =============================================================================

xgui.hookEvent("onOpen", nil, function()
    ppanel.RefreshPlayerList()
    ppanel.RequestList()
end, "ppunishCheckCache")

-- Also request once at load time
timer.Simple(3, function()
    ppanel.RefreshPlayerList()
    ppanel.RequestList()
end)

-- =============================================================================
-- REGISTER AS TOP-LEVEL TAB
-- =============================================================================

xgui.addModule("Punishments", ppanel, "icon16/lock.png", "xgui_manageppunish")
