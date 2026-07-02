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

-- The local copy of every period's leaderboard, keyed by period id, updated by
-- the server. Entities/panels read from these tables for rendering.
PVPLeaderboard.ClientCaches = PVPLeaderboard.ClientCaches or {}

-- =============================================================================
-- FONTS
-- =============================================================================

-- Large bold font for the title bar
surface.CreateFont("PVPLeaderboard_Title", {
	font = "Roboto",
	size = 64,
	weight = 700,
	antialias = true,
})

-- Medium font for column headers
surface.CreateFont("PVPLeaderboard_Header", {
	font = "Roboto",
	size = 36,
	weight = 600,
	antialias = true,
})

-- Standard font for data rows
surface.CreateFont("PVPLeaderboard_Row", {
	font = "Roboto",
	size = 32,
	weight = 400,
	antialias = true,
})

-- Small font for the "no data" placeholder
surface.CreateFont("PVPLeaderboard_Empty", {
	font = "Roboto",
	size = 28,
	weight = 400,
	antialias = true,
})

-- Font for the period switcher tabs on the !pvpboard panel
surface.CreateFont("PVPLeaderboard_Tab", {
	font = "Roboto",
	size = 26,
	weight = 600,
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

-- Layout constants (in 3D2D coordinate units, 2x for high-res rendering)
local TITLE_H  = 72
local HEADER_H = 48
local ROW_H    = 45.5
local PAD      = 1

-- Column X positions for each data field
local COL_RANK  = 20
local COL_NAME  = 80
local COL_KILLS = 450
local COL_DEATH = 570
local COL_KD    = 690
local COL_BEST  = 790
local COL_HS    = 890

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

-- Forward declaration: defined with the display-row cache further down, but the
-- sort-transition logic (above that point) needs to invalidate the cache.
local InvalidateDisplayRows

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

-- Transition state shared by all renderers. The sort cycle is global (every
-- board flips column together), but each board renders its own period's rows,
-- so we no longer precompute a single row set here — only the timing state.
local transition = {
	active    = false,
	startTime = 0,
	maxRows   = 0,   -- longest visible board, for completion timing
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

--- Begin a split-flap transition to a new sort mode (applies to all boards).
local function BeginSortTransition(newIndex)
	if transition.active then return end

	currentSortIndex = newIndex
	-- Sort column changed: cached rows are stale, rebuild on next draw.
	InvalidateDisplayRows()

	-- Time the animation to the longest board across all periods so every
	-- visible row gets to settle (entities cap at 10; the panel may show more).
	local maxRows = 0
	for _, board in pairs(PVPLeaderboard.ClientCaches) do
		if #board > maxRows then maxRows = #board end
	end

	if maxRows == 0 then
		-- Nothing on any board to animate; just switch instantly.
		transition.active = false
		return
	end

	transition.active    = true
	transition.startTime = CurTime()
	transition.maxRows   = maxRows
end

--- Deactivate the transition once the last row has fully settled.
local function CheckTransitionComplete()
	if not transition.active then return end

	local maxRow = transition.maxRows
	if maxRow < 1 then maxRow = 1 end
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
	draw.RoundedBox(0, 2, y, w - 4, HEADER_H, COLOR_HEADER_BG)

	local activeCol = SORT_MODES[currentSortIndex].col

	draw.SimpleText("#",      "PVPLeaderboard_Header", COL_RANK, y + HEADER_H / 2, COLOR_HEADER_TEXT, TEXT_ALIGN_LEFT,   TEXT_ALIGN_CENTER)
	draw.SimpleText("Player", "PVPLeaderboard_Header", COL_NAME, y + HEADER_H / 2, COLOR_HEADER_TEXT, TEXT_ALIGN_LEFT,   TEXT_ALIGN_CENTER)

	for _, hdr in ipairs(HEADERS) do
		local color = (hdr.col == activeCol) and COLOR_GOLD or COLOR_HEADER_TEXT
		draw.SimpleText(hdr.label, "PVPLeaderboard_Header", hdr.col, y + HEADER_H / 2, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

-- Data-row column layout. `color` selects a palette slot resolved per row below
-- ("name" tracks the rank medal color, "kd" is greyed, "text" is white). The
-- array index doubles as the split-flap column seed (kept identical to the
-- original 1..7 ordering so the scramble looks the same).
local DATA_COLUMNS = {
	{key = "rank",   x = COL_RANK,  align = TEXT_ALIGN_LEFT,   color = "name"},
	{key = "name",   x = COL_NAME,  align = TEXT_ALIGN_LEFT,   color = "name"},
	{key = "kills",  x = COL_KILLS, align = TEXT_ALIGN_CENTER, color = "text"},
	{key = "deaths", x = COL_DEATH, align = TEXT_ALIGN_CENTER, color = "text"},
	{key = "kd",     x = COL_KD,    align = TEXT_ALIGN_CENTER, color = "kd"},
	{key = "best",   x = COL_BEST,  align = TEXT_ALIGN_CENTER, color = "text"},
	{key = "hs",     x = COL_HS,    align = TEXT_ALIGN_CENTER, color = "text"},
}

--- Draw a single data row with split-flap animation support.
-- @param w number - panel width
-- @param y number - y offset to draw at
-- @param i number - row index (1-based, used for rank color and animation timing)
-- @param row table - display row strings {rank, name, kills, deaths, kd, best, hs}
local function DrawDataRow(w, y, i, row)
	local rowBg = (i % 2 == 0) and COLOR_ROW_EVEN or COLOR_ROW_ODD
	draw.RoundedBox(0, 2, y, w - 4, ROW_H, rowBg)

	local rankColor = COLOR_WHITE
	if i == 1 then rankColor = COLOR_GOLD
	elseif i == 2 then rankColor = COLOR_SILVER
	elseif i == 3 then rankColor = COLOR_BRONZE
	end

	local progress = GetRowResolveProgress(i)
	local scrambling = transition.active and progress < 1

	local cy = y + ROW_H / 2
	for col, spec in ipairs(DATA_COLUMNS) do
		local text = row[spec.key]
		local color
		if scrambling then
			text  = FlapText(text, progress, i, col)
			color = COLOR_FLAP
		elseif spec.color == "name" then color = rankColor
		elseif spec.color == "kd"   then color = COLOR_GRAY
		else color = COLOR_WHITE
		end
		draw.SimpleText(text, "PVPLeaderboard_Row", spec.x, cy, color, spec.align, TEXT_ALIGN_CENTER)
	end
end

-- Memo of display rows, keyed by period id. The sorted/formatted rows depend
-- only on the cache and the active sort column (the split-flap scramble is
-- applied later at draw time from row progress), and both change only at
-- discrete moments — a new sync or a sort change — so the cache is invalidated
-- on those events rather than rebuilt every frame.
local displayRowCache = {}

--- Drop all cached display rows. Called when the cache or sort column changes.
-- (Assigns the forward-declared upvalue from the sort-mode section above.)
function InvalidateDisplayRows()
	displayRowCache = {}
end

--- Get the current display rows for one period (sorted by the active column).
-- @param periodId string - period id (defaults to "alltime")
-- @return table - array of display row tables (may be empty)
local function GetDisplayRows(periodId)
	periodId = periodId or "alltime"

	local cached = displayRowCache[periodId]
	if cached then return cached end

	local board = PVPLeaderboard.ClientCaches[periodId] or {}
	local rows = (#board == 0) and {} or BoardToRows(SortBoard(board, currentSortIndex))

	displayRowCache[periodId] = rows
	return rows
end

--- Draw the "no data" placeholder centered at the given y.
local function DrawEmptyState(w, y)
	draw.SimpleText(
		"No PVP data recorded yet.", "PVPLeaderboard_Empty",
		w / 2, y,
		COLOR_EMPTY, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
	)
end

-- Precomputed "<label> PVP RECORD" title per period id (labels are static), so
-- the render path is a table lookup instead of a linear scan + concat per frame.
local PERIOD_TITLES = {}
for _, period in ipairs(PVPLeaderboard.Periods) do
	PERIOD_TITLES[period.id] = period.label .. " PVP RECORD"
end

-- =============================================================================
-- ENTITY DRAWING (3D2D)
-- =============================================================================

--- Draw the full leaderboard at the current 3D2D origin.
-- Called by the entity Draw function. Fixed at 10 rows to fit the plate model.
-- @param w number - screen width in 3D2D units
-- @param periodId string - which period board to render (defaults to "alltime")
function PVPLeaderboard.DrawBoard(w, periodId)
	periodId = periodId or "alltime"

	CheckTransitionComplete()

	local board = PVPLeaderboard.ClientCaches[periodId] or {}

	-- Fixed height for 10 rows (matches plate3x5 dimensions)
	local h = TITLE_H + HEADER_H + ROW_H * 10 + PAD

	-- Background panel with thin border
	draw.RoundedBox(8, 0, 0, w, h, COLOR_BG)
	surface.SetDrawColor(COLOR_BORDER)
	surface.DrawOutlinedRect(0, 0, w, h, 2)

	-- Title bar (crimson red, rounded top corners only). Period label drives the
	-- heading, e.g. "ALL TIME PVP RECORD", "24 HOUR PVP RECORD".
	draw.RoundedBoxEx(8, 0, 0, w, TITLE_H, COLOR_TITLE_BG, true, true, false, false)
	draw.SimpleText(
		PERIOD_TITLES[periodId] or "PVP RECORD", "PVPLeaderboard_Title",
		w / 2, TITLE_H / 2,
		COLOR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
	)

	DrawHeaders(w, TITLE_H)

	local y = TITLE_H + HEADER_H

	if #board == 0 then
		DrawEmptyState(w, y + 60)
		return
	end

	local displayRows = GetDisplayRows(periodId)
	for i, row in ipairs(displayRows) do
		if i > 10 then break end
		DrawDataRow(w, y, i, row)
		y = y + ROW_H
	end
end

-- =============================================================================
-- SORT CYCLE TIMER
-- =============================================================================

--- Create (or restart) the client-side sort cycling timer. Reads the interval
-- straight from the ConVar so it does not depend on the shared config callback
-- having run first; timer.Create with the same name replaces any existing timer.
local function StartSortCycleTimer()
	local interval = GetConVar("pvplb_sort_interval"):GetInt()

	timer.Create("PVPLeaderboard_SortCycle", interval, 0, function()
		local nextIndex = (currentSortIndex % #SORT_MODES) + 1
		BeginSortTransition(nextIndex)
	end)
end

StartSortCycleTimer()

-- Restart the cycle timer when the sort interval ConVar changes
cvars.AddChangeCallback("pvplb_sort_interval", StartSortCycleTimer, "pvplb_sort_cycle")

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

--- Receive every period's leaderboard cache from the server.
-- Called after every kill event and on the periodic refresh timer. Period
-- blocks arrive in PVPLeaderboard.Periods order (same list on both realms).
net.Receive("PVPLeaderboard_SyncCache", function()
	local periodCount = net.ReadUInt(4)
	local caches = {}

	for p = 1, periodCount do
		local count = net.ReadUInt(8)
		local board = {}

		for i = 1, count do
			-- All six fields are read to stay aligned with the wire format, but
			-- only the ones the board actually renders are stored (K/D is derived
			-- in BoardToRows; current_streak/steamid64 are unused client-side).
			local name        = net.ReadString()
			local kills       = net.ReadUInt(16)
			local deaths      = net.ReadUInt(16)
			net.ReadUInt(16) -- current_streak (unused)
			local best_streak = net.ReadUInt(16)
			local headshots   = net.ReadUInt(16)
			net.ReadString() -- steamid64 (unused)

			board[i] = {
				name        = name,
				kills       = kills,
				deaths      = deaths,
				best_streak = best_streak,
				headshots   = headshots,
			}
		end

		local period = PVPLeaderboard.Periods[p]
		if period then caches[period.id] = board end
	end

	PVPLeaderboard.ClientCaches = caches
	-- New data arrived: drop cached display rows so they rebuild on next draw.
	InvalidateDisplayRows()
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
-- Fixed title bar + a period tab strip + column headers, with a scrollable row
-- section so all entries are visible (not capped at 10 like the entity). The
-- tabs switch which period (All Time / 24h / 7d / 30d) is displayed.
net.Receive("PVPLeaderboard_OpenBoard", function()
	-- Initial period to show, chosen by the !pvpboard command argument.
	local initialIdx = net.ReadUInt(4)
	local initialPeriod = PVPLeaderboard.Periods[initialIdx]
		and PVPLeaderboard.Periods[initialIdx].id or "alltime"

	-- Close existing panel if already open
	if IsValid(PVPLeaderboard.Panel) then
		PVPLeaderboard.Panel:Remove()
	end

	-- Which period this panel is currently showing (mutated by the tab buttons).
	local selectedPeriod = initialPeriod

	local panelW  = 940
	local TAB_H   = 44
	local fixedH  = TITLE_H + TAB_H + HEADER_H
	local scrollH = ROW_H * 10 + PAD
	local panelH  = fixedH + scrollH

	local frame = vgui.Create("DFrame")
	frame:SetTitle("")
	frame:SetSize(panelW, panelH)
	frame:Center()
	frame:MakePopup()
	frame:SetDraggable(true)
	frame.btnMaxim:SetVisible(false)
	frame.btnMinim:SetVisible(false)

	-- Paint fixed chrome: background, title bar (selected period), tab strip
	-- background, and column headers.
	frame.Paint = function(self, w, h)
		draw.RoundedBox(8, 0, 0, w, h, COLOR_BG)
		surface.SetDrawColor(COLOR_BORDER)
		surface.DrawOutlinedRect(0, 0, w, h, 2)

		draw.RoundedBoxEx(8, 0, 0, w, TITLE_H, COLOR_TITLE_BG, true, true, false, false)
		draw.SimpleText(
			PERIOD_TITLES[selectedPeriod] or "PVP RECORD", "PVPLeaderboard_Title",
			w / 2, TITLE_H / 2,
			COLOR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
		)

		draw.RoundedBox(0, 2, TITLE_H, w - 4, TAB_H, COLOR_HEADER_BG)

		DrawHeaders(w, TITLE_H + TAB_H)
	end

	-- Period switcher tabs, evenly spread across the tab strip.
	local tabCount = #PVPLeaderboard.Periods
	local margin   = 8
	local gap      = 6
	local tabW     = (panelW - margin * 2 - gap * (tabCount - 1)) / tabCount
	local tabBtnH  = TAB_H - 14
	local tabY     = TITLE_H + 7

	for i, period in ipairs(PVPLeaderboard.Periods) do
		local btn = vgui.Create("DButton", frame)
		btn:SetText("")
		btn:SetSize(tabW, tabBtnH)
		btn:SetPos(margin + (i - 1) * (tabW + gap), tabY)
		btn.Paint = function(self, w, h)
			local active = (selectedPeriod == period.id)
			draw.RoundedBox(4, 0, 0, w, h, active and COLOR_TITLE_BG or COLOR_ROW_ODD)
			if active then
				surface.SetDrawColor(COLOR_GOLD)
				surface.DrawOutlinedRect(0, 0, w, h, 1)
			end
			draw.SimpleText(period.label, "PVPLeaderboard_Tab", w / 2, h / 2,
				active and COLOR_WHITE or COLOR_GRAY, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		btn.DoClick = function()
			selectedPeriod = period.id
			surface.PlaySound("buttons/button14.wav")
		end
	end

	-- Scrollable area for data rows (positioned below the fixed chrome)
	local scroll = vgui.Create("DScrollPanel", frame)
	scroll:SetPos(0, fixedH)
	scroll:SetSize(panelW, scrollH)

	local rowCanvas = vgui.Create("DPanel", scroll)
	rowCanvas:Dock(TOP)
	rowCanvas:SetTall(ROW_H * 10 + PAD)

	rowCanvas.Paint = function(self, w, h)
		CheckTransitionComplete()

		local displayRows = GetDisplayRows(selectedPeriod)
		if #displayRows == 0 then
			DrawEmptyState(w, 60)
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

	-- Request a fresh sync so windowed boards are current the moment it opens.
	net.Start("PVPLeaderboard_RequestSync")
	net.SendToServer()

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
