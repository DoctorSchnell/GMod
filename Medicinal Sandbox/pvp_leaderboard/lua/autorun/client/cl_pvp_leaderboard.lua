-- =============================================================================
--  PVP Leaderboard - Client Cache, Rendering, & Net Receivers
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Receives leaderboard data from the server and stores it locally.
--  Provides DrawBoard() for 2D content rendering on entities and panels.
--  Sort mode cycles automatically with split-flap transition animation.
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
local COLOR_FLAP        = Color(255, 176, 0, 255)

-- Layout constants (in 3D2D coordinate units)
local TITLE_H  = 36
local HEADER_H = 24
local ROW_H    = 22
local PAD      = 8

-- Column X positions for each data field
local COL_RANK  = 10
local COL_NAME  = 40
local COL_KILLS = 225
local COL_DEATH = 285
local COL_KD    = 345
local COL_BEST  = 395
local COL_HS    = 445

-- =============================================================================
-- SORT MODE DEFINITIONS
-- =============================================================================

-- Each mode defines a sort key, the column it highlights, and a comparator.
-- Tiebreakers fall through to kills to keep ordering stable.
local SORT_MODES = {
	{
		col = COL_KILLS,
		sortFunc = function(a, b)
			if a.kills ~= b.kills then return a.kills > b.kills end
			if a.best_streak ~= b.best_streak then return a.best_streak > b.best_streak end
			return a.headshots > b.headshots
		end,
	},
	{
		col = COL_KD,
		sortFunc = function(a, b)
			local aKD = a.deaths > 0 and (a.kills / a.deaths) or a.kills
			local bKD = b.deaths > 0 and (b.kills / b.deaths) or b.kills
			if aKD ~= bKD then return aKD > bKD end
			return a.kills > b.kills
		end,
	},
	{
		col = COL_BEST,
		sortFunc = function(a, b)
			if a.best_streak ~= b.best_streak then return a.best_streak > b.best_streak end
			return a.kills > b.kills
		end,
	},
	{
		col = COL_HS,
		sortFunc = function(a, b)
			if a.headshots ~= b.headshots then return a.headshots > b.headshots end
			return a.kills > b.kills
		end,
	},
}

-- Active sort mode index (1 = kills, 2 = K/D, 3 = best streak, 4 = headshots)
local currentSortIndex = 1

-- =============================================================================
-- SPLIT-FLAP TRANSITION ANIMATION
-- =============================================================================

-- Timing constants (seconds)
local FLAP_BASE_DELAY   = 0.3   -- scramble all rows for this long before settling starts
local FLAP_ROW_STAGGER  = 0.10  -- delay between each successive row beginning to settle
local FLAP_RESOLVE_TIME = 0.4   -- time for one row's characters to resolve left-to-right
local FLAP_RATE         = 18    -- character flips per second during scramble

-- Character set for the scramble display (uppercase + digits, like a real flap board)
local FLAP_CHARSET = "ABCDEFGHJKLMNPQRSTUVWXYZ0123456789"
local FLAP_CHARSET_LEN = #FLAP_CHARSET

-- Transition state shared by all entity renderers
local transition = {
	active    = false,
	startTime = 0,
	rows      = {},   -- target display rows (pre-computed string values)
}

--- Return a deterministic pseudo-random flap character.
-- Changes at FLAP_RATE Hz; unique per row, column, and character position.
local function GetFlapChar(row, col, charPos)
	local tick = math.floor(CurTime() * FLAP_RATE)
	local hash = (tick * 251 + row * 31 + col * 7 + charPos * 13) % FLAP_CHARSET_LEN
	return string.sub(FLAP_CHARSET, hash + 1, hash + 1)
end

--- Compute how far a row has progressed through its resolve phase.
-- @return number - 0 (pure scramble), 0..1 (resolving L-to-R), or 1 (settled)
local function GetRowResolveProgress(rowIndex)
	if not transition.active then return 1 end

	local elapsed = CurTime() - transition.startTime
	local resolveStart = FLAP_BASE_DELAY + (rowIndex - 1) * FLAP_ROW_STAGGER
	local resolveEnd   = resolveStart + FLAP_RESOLVE_TIME

	if elapsed >= resolveEnd then return 1 end
	if elapsed < resolveStart then return 0 end
	return (elapsed - resolveStart) / FLAP_RESOLVE_TIME
end

--- Produce display text with the split-flap scramble effect.
-- Resolved characters appear left-to-right as progress increases.
local function FlapText(targetText, resolveProgress, row, col)
	if resolveProgress >= 1 then return targetText end

	local len = #targetText
	if len == 0 then return "" end

	local resolvedCount = resolveProgress > 0
		and math.floor(resolveProgress * (len + 1))
		or 0

	local chars = {}
	for i = 1, len do
		if i <= resolvedCount then
			chars[i] = string.sub(targetText, i, i)
		else
			chars[i] = GetFlapChar(row, col, i)
		end
	end

	return table.concat(chars)
end

--- Sort a shallow copy of the board by the given mode index.
local function SortBoard(board, modeIndex)
	local sorted = {}
	for i, entry in ipairs(board) do
		sorted[i] = entry
	end
	table.sort(sorted, SORT_MODES[modeIndex].sortFunc)
	return sorted
end

--- Convert a sorted entry array into display-ready row strings.
local function BoardToRows(board)
	local rows = {}
	for i = 1, #board do
		local entry = board[i]
		local name = entry.name or "Unknown"
		if #name > 18 then name = string.sub(name, 1, 16) .. ".." end

		local kd = entry.deaths > 0
			and string.format("%.1f", entry.kills / entry.deaths)
			or tostring(entry.kills)

		rows[i] = {
			rank   = tostring(i),
			name   = name,
			kills  = tostring(entry.kills),
			deaths = tostring(entry.deaths),
			kd     = kd,
			best   = tostring(entry.best_streak),
			hs     = tostring(entry.headshots),
		}
	end
	return rows
end

--- Begin a split-flap transition to a new sort mode.
local function BeginSortTransition(newIndex)
	if transition.active then return end

	local board = PVPLeaderboard.ClientCache or {}
	if #board == 0 then
		currentSortIndex = newIndex
		return
	end

	local newSorted = SortBoard(board, newIndex)
	transition.rows      = BoardToRows(newSorted)
	transition.active    = true
	transition.startTime = CurTime()
	currentSortIndex     = newIndex
end

--- Deactivate the transition once the last row has fully settled.
local function CheckTransitionComplete()
	if not transition.active then return end

	local maxRow = #transition.rows
	if maxRow == 0 then maxRow = 1 end
	local totalDuration = FLAP_BASE_DELAY + (maxRow - 1) * FLAP_ROW_STAGGER + FLAP_RESOLVE_TIME

	if CurTime() - transition.startTime >= totalDuration then
		transition.active = false
	end
end

-- =============================================================================
-- DRAWING HELPERS
-- =============================================================================

-- Column header definitions (label, x-position)
local HEADERS = {
	{label = "Kills",     col = COL_KILLS},
	{label = "Deaths",    col = COL_DEATH},
	{label = "K/D",       col = COL_KD},
	{label = "KS",  col = COL_BEST},
	{label = "HS",  col = COL_HS},
}

--- Draw the column header row at the given y offset.
-- @param w number - panel width
-- @param y number - y offset to draw at
local function DrawHeaders(w, y)
	draw.RoundedBox(0, 0, y, w, HEADER_H, COLOR_HEADER_BG)

	local activeCol = SORT_MODES[currentSortIndex].col

	draw.SimpleText("#",      "PVPLeaderboard_Header", COL_RANK, y + HEADER_H / 2, COLOR_HEADER_TEXT, TEXT_ALIGN_LEFT,   TEXT_ALIGN_CENTER)
	draw.SimpleText("Player", "PVPLeaderboard_Header", COL_NAME, y + HEADER_H / 2, COLOR_HEADER_TEXT, TEXT_ALIGN_LEFT,   TEXT_ALIGN_CENTER)

	for _, hdr in ipairs(HEADERS) do
		local color = (hdr.col == activeCol) and COLOR_GOLD or COLOR_HEADER_TEXT
		draw.SimpleText(hdr.label, "PVPLeaderboard_Header", hdr.col, y + HEADER_H / 2, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

--- Draw a single data row with split-flap animation support.
-- @param w number - panel width
-- @param y number - y offset to draw at
-- @param i number - row index (1-based, used for rank color and animation timing)
-- @param row table - display row strings {rank, name, kills, deaths, kd, best, hs}
local function DrawDataRow(w, y, i, row)
	local rowBg = (i % 2 == 0) and COLOR_ROW_EVEN or COLOR_ROW_ODD
	draw.RoundedBox(0, 0, y, w, ROW_H, rowBg)

	local rankColor = COLOR_WHITE
	if i == 1 then rankColor = COLOR_GOLD
	elseif i == 2 then rankColor = COLOR_SILVER
	elseif i == 3 then rankColor = COLOR_BRONZE
	end

	local progress = GetRowResolveProgress(i)
	local scrambling = transition.active and progress < 1

	local textColor = scrambling and COLOR_FLAP or COLOR_WHITE
	local nameColor = scrambling and COLOR_FLAP or rankColor
	local kdColor   = scrambling and COLOR_FLAP or COLOR_GRAY

	draw.SimpleText(scrambling and FlapText(row.rank, progress, i, 1) or row.rank,
		"PVPLeaderboard_Row", COL_RANK, y + ROW_H / 2, nameColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(scrambling and FlapText(row.name, progress, i, 2) or row.name,
		"PVPLeaderboard_Row", COL_NAME, y + ROW_H / 2, nameColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(scrambling and FlapText(row.kills, progress, i, 3) or row.kills,
		"PVPLeaderboard_Row", COL_KILLS, y + ROW_H / 2, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(scrambling and FlapText(row.deaths, progress, i, 4) or row.deaths,
		"PVPLeaderboard_Row", COL_DEATH, y + ROW_H / 2, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(scrambling and FlapText(row.kd, progress, i, 5) or row.kd,
		"PVPLeaderboard_Row", COL_KD, y + ROW_H / 2, kdColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(scrambling and FlapText(row.best, progress, i, 6) or row.best,
		"PVPLeaderboard_Row", COL_BEST, y + ROW_H / 2, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(scrambling and FlapText(row.hs, progress, i, 7) or row.hs,
		"PVPLeaderboard_Row", COL_HS, y + ROW_H / 2, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

--- Get the current display rows, applying sort and transition state.
-- @return table - array of display row tables
local function GetDisplayRows()
	local board = PVPLeaderboard.ClientCache or {}
	if #board == 0 then return {} end

	if transition.active then
		return transition.rows
	end

	local sorted = SortBoard(board, currentSortIndex)
	return BoardToRows(sorted)
end

-- =============================================================================
-- ENTITY DRAWING (3D2D)
-- =============================================================================

--- Draw the full leaderboard at the current 3D2D origin.
-- Called by the entity Draw function. Fixed at 10 rows to fit the plate model.
-- @param w number - screen width in 3D2D units
function PVPLeaderboard.DrawBoard(w)
	CheckTransitionComplete()

	local board = PVPLeaderboard.ClientCache or {}

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

	DrawHeaders(w, TITLE_H)

	local y = TITLE_H + HEADER_H

	if #board == 0 then
		draw.SimpleText(
			"No PVP data recorded yet.", "PVPLeaderboard_Empty",
			w / 2, y + 30,
			COLOR_EMPTY, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
		)
		return
	end

	local displayRows = GetDisplayRows()
	for i, row in ipairs(displayRows) do
		if i > 10 then break end
		DrawDataRow(w, y, i, row)
		y = y + ROW_H
	end
end

-- =============================================================================
-- SORT CYCLE TIMER
-- =============================================================================

--- Create (or restart) the client-side sort cycling timer.
local function StartSortCycleTimer()
	local interval = PVPLeaderboard.Config.SortInterval or 20

	if timer.Exists("PVPLeaderboard_SortCycle") then
		timer.Remove("PVPLeaderboard_SortCycle")
	end

	timer.Create("PVPLeaderboard_SortCycle", interval, 0, function()
		local nextIndex = (currentSortIndex % #SORT_MODES) + 1
		BeginSortTransition(nextIndex)
	end)
end

StartSortCycleTimer()

-- Restart the cycle timer when the sort interval ConVar changes
cvars.AddChangeCallback("pvplb_sort_interval", function()
	timer.Simple(0, StartSortCycleTimer)
end, "pvplb_sort_cycle")

-- =============================================================================
-- NET RECEIVERS
-- =============================================================================

--- Receive a sort mode override from the server (!pvpsort command).
-- Triggers a split-flap transition and resets the cycle timer.
net.Receive("PVPLeaderboard_SetSort", function()
	local index = net.ReadUInt(3)
	if index < 1 or index > #SORT_MODES then return end

	if index ~= currentSortIndex then
		BeginSortTransition(index)
	end

	-- Reset the cycle timer so it counts from now
	StartSortCycleTimer()
end)

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
-- Uses a fixed title/header area with a scrollable row section so all
-- entries from the cache are visible (not capped at 10 like the entity).
net.Receive("PVPLeaderboard_OpenBoard", function()
	-- Close existing panel if already open
	if IsValid(PVPLeaderboard.Panel) then
		PVPLeaderboard.Panel:Remove()
	end

	local panelW = 470
	local fixedH = TITLE_H + HEADER_H
	local scrollH = ROW_H * 10 + PAD
	local panelH = fixedH + scrollH

	local frame = vgui.Create("DFrame")
	frame:SetTitle("")
	frame:SetSize(panelW, panelH)
	frame:Center()
	frame:MakePopup()
	frame:SetDraggable(true)
	frame.btnMaxim:SetVisible(false)
	frame.btnMinim:SetVisible(false)

	-- Paint fixed header: background, title bar, and column headers
	frame.Paint = function(self, w, h)
		draw.RoundedBox(4, 0, 0, w, h, COLOR_BG)
		surface.SetDrawColor(COLOR_BORDER)
		surface.DrawOutlinedRect(0, 0, w, h, 1)

		draw.RoundedBoxEx(4, 0, 0, w, TITLE_H, COLOR_TITLE_BG, true, true, false, false)
		draw.SimpleText(
			"ALL TIME PVP RECORD", "PVPLeaderboard_Title",
			w / 2, TITLE_H / 2,
			COLOR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
		)

		DrawHeaders(w, TITLE_H)
	end

	-- Scrollable area for data rows (positioned below the fixed header)
	local scroll = vgui.Create("DScrollPanel", frame)
	scroll:SetPos(0, fixedH)
	scroll:SetSize(panelW, scrollH)

	local rowCanvas = vgui.Create("DPanel", scroll)
	rowCanvas:Dock(TOP)
	rowCanvas:SetTall(ROW_H * 10 + PAD)

	rowCanvas.Paint = function(self, w, h)
		CheckTransitionComplete()

		local displayRows = GetDisplayRows()
		if #displayRows == 0 then
			draw.SimpleText(
				"No PVP data recorded yet.", "PVPLeaderboard_Empty",
				w / 2, 30,
				COLOR_EMPTY, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
			)
			return
		end

		-- Resize canvas to fit all rows
		local targetH = ROW_H * #displayRows + PAD
		if self:GetTall() ~= targetH then
			self:SetTall(targetH)
		end

		local y = 0
		for i, row in ipairs(displayRows) do
			DrawDataRow(w, y, i, row)
			y = y + ROW_H
		end
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
