-- =============================================================================
--  PVP Leaderboard - Client Cache, Rendering, & Net Receivers
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Receives leaderboard data from the server and stores it locally.
--  Provides DrawBoard() for 2D content rendering on entities and panels.
-- =============================================================================

PVPLeaderboard = PVPLeaderboard or {}

-- =============================================================================
-- CLIENT-SIDE CACHE
-- =============================================================================

-- The local copy of the leaderboard, updated by the server.
-- Entities read from this table for 3D2D rendering.
PVPLeaderboard.ClientCache = PVPLeaderboard.ClientCache or {}

--- Public accessor for entities to read the current leaderboard data.
-- @return table - array of leaderboard entries (may be empty)
function PVPLeaderboard.GetClientCache()
	return PVPLeaderboard.ClientCache
end

-- =============================================================================
-- FONTS
-- =============================================================================

-- Large bold font for the title bar
surface.CreateFont("PVPLeaderboard_Title", {
	font = "Roboto",
	size = 32,
	weight = 700,
	antialias = true,
})

-- Medium font for column headers
surface.CreateFont("PVPLeaderboard_Header", {
	font = "Roboto",
	size = 18,
	weight = 600,
	antialias = true,
})

-- Standard font for data rows
surface.CreateFont("PVPLeaderboard_Row", {
	font = "Roboto",
	size = 16,
	weight = 400,
	antialias = true,
})

-- Small font for the "no data" placeholder
surface.CreateFont("PVPLeaderboard_Empty", {
	font = "Roboto",
	size = 14,
	weight = 400,
	antialias = true,
})

-- =============================================================================
-- LEADERBOARD RENDERING
-- =============================================================================

-- Color palette for the leaderboard display
local COLOR_BG          = Color(15, 15, 20, 240)
local COLOR_TITLE_BG    = Color(140, 25, 25, 240)
local COLOR_HEADER_BG   = Color(35, 35, 40, 220)
local COLOR_ROW_EVEN    = Color(25, 25, 30, 200)
local COLOR_ROW_ODD     = Color(30, 30, 38, 200)
local COLOR_BORDER      = Color(100, 30, 30, 200)
local COLOR_WHITE       = Color(255, 255, 255, 255)
local COLOR_GRAY        = Color(180, 180, 180, 255)
local COLOR_GOLD        = Color(255, 215, 0, 255)
local COLOR_SILVER      = Color(192, 192, 192, 255)
local COLOR_BRONZE      = Color(205, 127, 50, 255)
local COLOR_HEADER_TEXT = Color(200, 200, 210, 255)
local COLOR_EMPTY       = Color(120, 120, 130, 255)

-- Layout constants (in 3D2D coordinate units)
local TITLE_H  = 36
local HEADER_H = 24
local ROW_H    = 22
local PAD      = 8

-- Column X positions for each data field
local COL_RANK  = 10
local COL_NAME  = 40
local COL_KILLS = 230
local COL_DEATH = 280
local COL_KD    = 330
local COL_BEST  = 385
local COL_HS    = 440

--- Draw the full leaderboard at the current 3D2D origin.
-- Called by the entity Draw function and the VGUI panel.
-- Drawing starts at (0, 0) and extends right/down.
-- Always reserves space for 10 rows regardless of entry count.
-- @param w number - screen width in 3D2D units
function PVPLeaderboard.DrawBoard(w)
	local board = PVPLeaderboard.ClientCache or {}
	local numEntries = #board

	-- Fixed height for 10 rows (matches plate3x5 dimensions)
	local h = TITLE_H + HEADER_H + ROW_H * 10 + PAD

	-- Background panel with thin border
	draw.RoundedBox(4, 0, 0, w, h, COLOR_BG)
	surface.SetDrawColor(COLOR_BORDER)
	surface.DrawOutlinedRect(0, 0, w, h, 1)

	-- Title bar (crimson red, rounded top corners only)
	draw.RoundedBoxEx(4, 0, 0, w, TITLE_H, COLOR_TITLE_BG, true, true, false, false)
	draw.SimpleText(
		"ALL TIME PVP RECORD", "PVPLeaderboard_Title",
		w / 2, TITLE_H / 2,
		COLOR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
	)

	-- Column headers
	local y = TITLE_H
	draw.RoundedBox(0, 0, y, w, HEADER_H, COLOR_HEADER_BG)

	draw.SimpleText("#",      "PVPLeaderboard_Header", COL_RANK,  y + HEADER_H / 2, COLOR_HEADER_TEXT, TEXT_ALIGN_LEFT,   TEXT_ALIGN_CENTER)
	draw.SimpleText("Player", "PVPLeaderboard_Header", COL_NAME,  y + HEADER_H / 2, COLOR_HEADER_TEXT, TEXT_ALIGN_LEFT,   TEXT_ALIGN_CENTER)
	draw.SimpleText("K",      "PVPLeaderboard_Header", COL_KILLS, y + HEADER_H / 2, COLOR_HEADER_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText("D",      "PVPLeaderboard_Header", COL_DEATH, y + HEADER_H / 2, COLOR_HEADER_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText("K/D",    "PVPLeaderboard_Header", COL_KD,    y + HEADER_H / 2, COLOR_HEADER_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText("Best",   "PVPLeaderboard_Header", COL_BEST,  y + HEADER_H / 2, COLOR_HEADER_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText("HS",     "PVPLeaderboard_Header", COL_HS,    y + HEADER_H / 2, COLOR_HEADER_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	y = y + HEADER_H

	-- Empty state: show placeholder when no data is recorded yet
	if numEntries == 0 then
		draw.SimpleText(
			"No PVP data recorded yet.", "PVPLeaderboard_Empty",
			w / 2, y + 30,
			COLOR_EMPTY, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
		)
		return
	end

	-- Data rows: one per leaderboard entry (capped at 10)
	for i, entry in ipairs(board) do
		if i > 10 then break end
		-- Alternating row backgrounds for readability
		local rowBg = (i % 2 == 0) and COLOR_ROW_EVEN or COLOR_ROW_ODD
		draw.RoundedBox(0, 0, y, w, ROW_H, rowBg)

		-- Rank color: gold/silver/bronze for top 3, white for the rest
		local rankColor = COLOR_WHITE
		if i == 1 then rankColor = COLOR_GOLD
		elseif i == 2 then rankColor = COLOR_SILVER
		elseif i == 3 then rankColor = COLOR_BRONZE
		end

		-- Rank number
		draw.SimpleText(
			tostring(i), "PVPLeaderboard_Row",
			COL_RANK, y + ROW_H / 2,
			rankColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
		)

		-- Player name (truncate long names to prevent overflow)
		local name = entry.name or "Unknown"
		if string.len(name) > 18 then
			name = string.sub(name, 1, 16) .. ".."
		end
		draw.SimpleText(
			name, "PVPLeaderboard_Row",
			COL_NAME, y + ROW_H / 2,
			rankColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
		)

		-- Kills
		draw.SimpleText(
			tostring(entry.kills), "PVPLeaderboard_Row",
			COL_KILLS, y + ROW_H / 2,
			COLOR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
		)

		-- Deaths
		draw.SimpleText(
			tostring(entry.deaths), "PVPLeaderboard_Row",
			COL_DEATH, y + ROW_H / 2,
			COLOR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
		)

		-- K/D ratio (calculated at display time, not stored)
		local kd = entry.deaths > 0
			and string.format("%.1f", entry.kills / entry.deaths)
			or tostring(entry.kills)
		draw.SimpleText(
			kd, "PVPLeaderboard_Row",
			COL_KD, y + ROW_H / 2,
			COLOR_GRAY, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
		)

		-- Best kill streak
		draw.SimpleText(
			tostring(entry.best_streak), "PVPLeaderboard_Row",
			COL_BEST, y + ROW_H / 2,
			COLOR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
		)

		-- Headshot kills
		draw.SimpleText(
			tostring(entry.headshots), "PVPLeaderboard_Row",
			COL_HS, y + ROW_H / 2,
			COLOR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
		)

		y = y + ROW_H
	end
end

-- =============================================================================
-- NET RECEIVERS
-- =============================================================================

--- Receive the full leaderboard cache from the server.
-- Called after every kill event and on the periodic refresh timer.
net.Receive("PVPLeaderboard_SyncCache", function()
	local count = net.ReadUInt(8)
	local board = {}

	for i = 1, count do
		local name           = net.ReadString()
		local kills          = net.ReadUInt(16)
		local deaths         = net.ReadUInt(16)
		local current_streak = net.ReadUInt(16)
		local best_streak    = net.ReadUInt(16)
		local headshots      = net.ReadUInt(16)
		local steamid64      = net.ReadString()

		board[i] = {
			name           = name,
			kills          = kills,
			deaths         = deaths,
			kd             = deaths > 0 and math.Round(kills / deaths, 2) or kills,
			current_streak = current_streak,
			best_streak    = best_streak,
			headshots      = headshots,
			steamid64      = steamid64,
		}
	end

	PVPLeaderboard.ClientCache = board
end)

--- Receive individual player stats (response to !pvpstats).
-- Displays the stats in the player's chat.
net.Receive("PVPLeaderboard_PlayerStats", function()
	local name      = net.ReadString()
	local kills     = net.ReadUInt(16)
	local deaths    = net.ReadUInt(16)
	local streak    = net.ReadUInt(16)
	local best      = net.ReadUInt(16)
	local headshots = net.ReadUInt(16)

	local kd = deaths > 0 and math.Round(kills / deaths, 2) or kills

	-- First line: header with player name
	chat.AddText(
		Color(255, 200, 50), "[PVP Leaderboard] ",
		Color(255, 255, 255), "Stats for ",
		Color(100, 200, 255), name
	)

	-- Second line: all stat values
	chat.AddText(
		Color(200, 200, 200), string.format(
			"  Kills: %d | Deaths: %d | K/D: %.2f | Streak: %d | Best: %d | HS: %d",
			kills, deaths, kd, streak, best, headshots
		)
	)
end)

--- Open the leaderboard as a VGUI panel (response to !pvpboard).
net.Receive("PVPLeaderboard_OpenBoard", function()
	-- Close existing panel if already open
	if IsValid(PVPLeaderboard.Panel) then
		PVPLeaderboard.Panel:Remove()
	end

	local panelW = 470
	local panelH = TITLE_H + HEADER_H + ROW_H * 10 + PAD

	local frame = vgui.Create("DFrame")
	frame:SetTitle("")
	frame:SetSize(panelW, panelH)
	frame:Center()
	frame:MakePopup()
	frame:SetDraggable(true)
	frame.btnMaxim:SetVisible(false)
	frame.btnMinim:SetVisible(false)
	frame.Paint = function(self, w, h)
		PVPLeaderboard.DrawBoard(w)
	end

	PVPLeaderboard.Panel = frame
end)

-- =============================================================================
-- INITIAL DATA REQUEST
-- =============================================================================

-- Request the current leaderboard from the server when the client finishes loading.
-- This ensures data is available for any Perm Props entities already on the map.
hook.Add("InitPostEntity", "PVPLeaderboard_RequestData", function()
	net.Start("PVPLeaderboard_RequestSync")
	net.SendToServer()
end)
