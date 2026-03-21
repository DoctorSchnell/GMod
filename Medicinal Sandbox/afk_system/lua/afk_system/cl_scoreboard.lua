--[[
    AFK System - Sui Scoreboard Integration
    Hooks into Sui Scoreboard's player row panels to add:
    - Row dimming for AFK players
    - "AFK" badge right of the player name
    Works non-invasively without modifying Sui Scoreboard source files.
]]--

-------------------------------------------------
-- FONTS
-------------------------------------------------

surface.CreateFont("AFK_ScoreboardBadge", {
    font = "Roboto",
    size = 14,
    weight = 700,
    antialias = true,
})

surface.CreateFont("AFK_ScoreboardTime", {
    font = "Roboto",
    size = 11,
    weight = 400,
    antialias = true,
})

-------------------------------------------------
-- HELPERS
-------------------------------------------------

--- Check if a panel looks like a Sui Scoreboard player row
-- (as opposed to the expanded info card or other panels that also have .Player).
-- Player rows are short (~30-40px) and have name-related child labels.
local function IsPlayerRow(panel)
    if not IsValid(panel) then return false end
    if not panel.Player then return false end
    if not IsValid(panel.Player) then return false end
    if not panel.Player:IsPlayer() then return false end

    -- Player rows in Sui are short. The info card at the bottom is ~150px+.
    local tall = panel:GetTall()
    if tall > 60 then return false end

    -- Sui player rows have lblName, lblKills, etc. Check for at least lblName.
    if panel.lblName then return true end

    -- Fallback: if it has a reasonable height and .Player, it's likely a row
    -- from a different scoreboard version. Accept it.
    if tall > 10 and tall <= 60 then return true end

    return false
end

--- Find the X position where the player name label ends.
-- Returns the X coordinate right after the name text, or nil if not found.
local function GetNameEndX(panel)
    if not IsValid(panel) then return nil end

    -- Try Sui's lblName field directly
    if panel.lblName and IsValid(panel.lblName) then
        local lbl = panel.lblName
        local lblX, lblY = lbl:GetPos()
        local lblW = lbl:GetWide()

        -- Get the actual text width rather than the full label width
        -- (the label may be wider than the text it contains)
        local font = lbl:GetFont()
        local text = lbl:GetText()
        if font and text and text ~= "" then
            surface.SetFont(font)
            local textW, _ = surface.GetTextSize(text)
            return lblX + textW
        end

        -- Fallback: use full label width
        return lblX + lblW
    end

    -- Fallback: search children for a DLabel containing the player's name
    if IsValid(panel.Player) then
        local plyName = panel.Player:Nick()
        for _, child in ipairs(panel:GetChildren()) do
            if IsValid(child) and child.GetText and child:GetText() == plyName then
                local cx, cy = child:GetPos()
                local font = child.GetFont and child:GetFont()
                if font then
                    surface.SetFont(font)
                    local textW, _ = surface.GetTextSize(plyName)
                    return cx + textW
                end
                return cx + child:GetWide()
            end
        end
    end

    return nil
end

-------------------------------------------------
-- PANEL HOOKING
-------------------------------------------------

--- Recursively find player row panels.
local function FindPlayerRows(panel, results)
    if not IsValid(panel) then return end

    if IsPlayerRow(panel) then
        table.insert(results, panel)
    end

    for _, child in ipairs(panel:GetChildren()) do
        FindPlayerRows(child, results)
    end
end

--- Hook a player row panel's PaintOver to add AFK visuals.
local function HookPlayerRow(panel)
    if not IsValid(panel) then return end

    -- Flag on the panel itself to prevent double-hooking across
    -- scoreboard open/close cycles where Sui reuses panel objects.
    if panel._AFK_Hooked then return end
    panel._AFK_Hooked = true

    local originalPaintOver = panel.PaintOver

    panel.PaintOver = function(self, w, h)
        if originalPaintOver then
            originalPaintOver(self, w, h)
        end

        if not IsValid(self.Player) then return end
        if not self.Player:GetNWBool(AFK.NW_IS_AFK, false) then return end

        -- Match Sui Scoreboard's exact row drawing bounds:
        -- player_row.lua line 81: draw.RoundedBox( 4, 18, 0, self:GetWide()-36, 38, color )
        -- So the visible row starts at x=18 with 18px margin on each side.
        local rowX = 18
        local rowW = w - 36

        local dimColor = Color(0, 0, 0, AFK.Config.ScoreboardDimAlpha)
        draw.RoundedBox(4, rowX, 0, rowW, h, dimColor)

        -- AFK badge — positioned right of the player name
        local badgeText = "AFK"
        surface.SetFont("AFK_ScoreboardBadge")
        local btw, bth = surface.GetTextSize(badgeText)

        local badgePadX = 5
        local badgePadY = 2
        local badgeW = btw + badgePadX * 2
        local badgeH = bth + badgePadY * 2

        -- Find where the player name ends
        local nameEndX = GetNameEndX(self)
        local badgeX = (nameEndX or 150) + 8  -- 8px gap after name; fallback to 150px
        local badgeY = (h - badgeH) / 2

        -- Badge background
        draw.RoundedBox(4, badgeX, badgeY, badgeW, badgeH, AFK.Config.ScoreboardBadgeBgColor)

        -- Badge text
        draw.SimpleText(badgeText, "AFK_ScoreboardBadge", badgeX + badgeW / 2, badgeY + badgeH / 2,
            AFK.Config.ScoreboardBadgeColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Elapsed time (inline, right of badge)
        local since = self.Player:GetNWFloat(AFK.NW_SINCE, 0)
        if since > 0 then
            local secs = math.floor(CurTime() - since)
            local mins = math.floor(secs / 60)
            secs = secs % 60
            local timeStr
            if mins > 0 then
                timeStr = string.format("%dm", mins)
            else
                timeStr = string.format("%ds", secs)
            end

            draw.SimpleText(timeStr, "AFK_ScoreboardTime",
                badgeX + badgeW + 4, badgeY + badgeH / 2,
                Color(255, 255, 255, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

    end
end

-------------------------------------------------
-- SCANNER
-------------------------------------------------

local nextScan = 0

hook.Add("Think", "AFK_ScoreboardScanner", function()
    if CurTime() < nextScan then return end
    nextScan = CurTime() + 0.5

    local worldPanel = vgui.GetWorldPanel()
    if not IsValid(worldPanel) then return end

    local rows = {}
    for _, topPanel in ipairs(worldPanel:GetChildren()) do
        if IsValid(topPanel) and topPanel:IsVisible() then
            FindPlayerRows(topPanel, rows)
        end
    end

    for _, row in ipairs(rows) do
        HookPlayerRow(row)
    end
end)
