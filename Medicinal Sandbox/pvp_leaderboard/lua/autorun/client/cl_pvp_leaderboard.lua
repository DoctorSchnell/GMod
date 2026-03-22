--[[
	PVP Leaderboard - Client Cache, Rendering, & Net Receivers
	Receives leaderboard data from the server and stores it locally.
	Provides DrawBoard() for 2D content and DrawSign() for 3D mesh sign entities.
	Author: Doctor Schnell
]]

PVPLeaderboard = PVPLeaderboard or {}

-------------------------------------------------
-- CLIENT-SIDE CACHE
-------------------------------------------------

-- The local copy of the leaderboard, updated by the server.
-- Entities read from this table for 3D2D rendering.
PVPLeaderboard.ClientCache = PVPLeaderboard.ClientCache or {}

--- Public accessor for entities to read the current leaderboard data.
-- @return table - array of leaderboard entries (may be empty)
function PVPLeaderboard.GetClientCache()
	return PVPLeaderboard.ClientCache
end

-------------------------------------------------
-- FONTS
-------------------------------------------------

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

-------------------------------------------------
-- LEADERBOARD RENDERING
-------------------------------------------------

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
-- Both wall and kiosk entities call this from their Draw functions.
-- Drawing starts at (0, 0) and extends right/down.
-- @param w number - screen width in 3D2D units
function PVPLeaderboard.DrawBoard(w)
	local board = PVPLeaderboard.ClientCache or {}
	local numEntries = #board

	-- Calculate total height based on number of entries.
	-- Minimum height accommodates the "no data" message.
	local contentH = TITLE_H + HEADER_H + ROW_H * math.max(numEntries, 3) + PAD
	local h = contentH

	-- Background panel with thin border
	draw.RoundedBox(4, 0, 0, w, h, COLOR_BG)
	surface.SetDrawColor(COLOR_BORDER)
	surface.DrawOutlinedRect(0, 0, w, h, 1)

	-- Title bar (crimson red, rounded top corners only)
	draw.RoundedBoxEx(4, 0, 0, w, TITLE_H, COLOR_TITLE_BG, true, true, false, false)
	draw.SimpleText(
		"PVP LEADERBOARD", "PVPLeaderboard_Title",
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

	-- Data rows: one per leaderboard entry
	for i, entry in ipairs(board) do
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

-------------------------------------------------
-- 3D SIGN RENDERING
-------------------------------------------------

-- Vertex-colored material for the sign mesh (fully opaque)
local matSign = CreateMaterial("PVPLB_SignMat_" .. SysTime(), "UnlitGeneric", {
	["$basetexture"] = "color/white",
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 0,
	["$nolod"] = 1,
})

--- Emit one quad (4 vertices) into the active mesh.Begin block.
local function MeshQuad(p1, p2, p3, p4, normal, col)
	mesh.Position(p1) mesh.Normal(normal) mesh.Color(col.r, col.g, col.b, 255) mesh.TexCoord(0, 0, 0) mesh.AdvanceVertex()
	mesh.Position(p2) mesh.Normal(normal) mesh.Color(col.r, col.g, col.b, 255) mesh.TexCoord(0, 1, 0) mesh.AdvanceVertex()
	mesh.Position(p3) mesh.Normal(normal) mesh.Color(col.r, col.g, col.b, 255) mesh.TexCoord(0, 1, 1) mesh.AdvanceVertex()
	mesh.Position(p4) mesh.Normal(normal) mesh.Color(col.r, col.g, col.b, 255) mesh.TexCoord(0, 0, 1) mesh.AdvanceVertex()
end

--- Draw a 6-faced box from 8 corners with per-face-group colors.
local function DrawMeshBox(ftl, ftr, fbr, fbl, btl, btr, bbr, bbl, faceCol, sideCol, topCol, nF, nR, nU)
	render.SetMaterial(matSign)

	for _, cullMode in ipairs({MATERIAL_CULLMODE_CW, MATERIAL_CULLMODE_CCW}) do
		render.CullMode(cullMode)
		mesh.Begin(MATERIAL_QUADS, 6)
			MeshQuad(fbl, fbr, ftr, ftl, nF, faceCol)
			MeshQuad(bbr, bbl, btl, btr, -nF, faceCol)
			MeshQuad(fbr, bbr, btr, ftr, nR, sideCol)
			MeshQuad(bbl, fbl, ftl, btl, -nR, sideCol)
			MeshQuad(ftl, ftr, btr, btl, nU, topCol)
			MeshQuad(bbl, bbr, fbr, fbl, -nU, sideCol)
		mesh.End()
	end

	render.CullMode(MATERIAL_CULLMODE_CCW)
end

--- Compute 8 corners of a box centered at `pos` with half-extents along ri, up, fw.
local function BoxCorners(pos, ri, up, fw)
	local ftl = pos + fw - ri + up
	local ftr = pos + fw + ri + up
	local fbr = pos + fw + ri - up
	local fbl = pos + fw - ri - up
	local btl = pos - fw - ri + up
	local btr = pos - fw + ri + up
	local bbr = pos - fw + ri - up
	local bbl = pos - fw - ri - up
	return ftl, ftr, fbr, fbl, btl, btr, bbr, bbl
end

-- Metal frame colors (dark gunmetal)
local FRAME_FACE = Color(55, 55, 60)
local FRAME_SIDE = Color(40, 40, 45)
local FRAME_TOP  = Color(70, 70, 75)

-- Sign panel colors (dark charcoal, near COLOR_BG)
local PANEL_FACE = Color(20, 20, 25)
local PANEL_SIDE = Color(15, 15, 20)
local PANEL_TOP  = Color(25, 25, 30)

-- Sign depth in world units
local SIGN_DEPTH = 3

--- Draw a metal-framed 3D sign with the leaderboard on both faces.
-- Called by entity Draw functions. Renders the mesh frame, inner panel,
-- and leaderboard content on the front and back.
-- @param pos      Vector - entity world position (sign center)
-- @param yaw      number - entity yaw angle in degrees
-- @param screenW  number - leaderboard width in 3D2D units
-- @param scale    number - 3D2D-to-world-unit scale factor
-- @param border   number - frame border width in world units
function PVPLeaderboard.DrawSign(pos, yaw, screenW, scale, border)
	local board = PVPLeaderboard.ClientCache or {}
	local numEntries = #board

	-- Content height matching DrawBoard layout
	local contentH = TITLE_H + HEADER_H + ROW_H * math.max(numEntries, 3) + PAD

	-- Half-extents of the content area in world units
	local halfW = (screenW * scale) / 2
	local halfH = (contentH * scale) / 2
	local halfD = SIGN_DEPTH / 2

	-- Sign orientation (vertical, follows entity yaw)
	local frontAng = Angle(0, yaw - 90, 90)
	local signRight  = frontAng:Forward()
	local signUp     = Vector(0, 0, 1)
	local signNormal = signRight:Cross(signUp)
	signNormal:Normalize()

	-- Outer frame (metal border around the panel)
	local frameHalfW = halfW + border
	local frameHalfH = halfH + border
	local fri = signRight * frameHalfW
	local fup = signUp * frameHalfH
	local ffw = signNormal * halfD
	local f1, f2, f3, f4, f5, f6, f7, f8 = BoxCorners(pos, fri, fup, ffw)
	DrawMeshBox(f1, f2, f3, f4, f5, f6, f7, f8, FRAME_FACE, FRAME_SIDE, FRAME_TOP, signNormal, signRight, signUp)

	-- Inner panel (flush with frame, slightly protruding front/back)
	local panelHalfD = halfD + 0.1
	local pri = signRight * halfW
	local pup = signUp * halfH
	local pfw = signNormal * panelHalfD
	local p1, p2, p3, p4, p5, p6, p7, p8 = BoxCorners(pos, pri, pup, pfw)
	DrawMeshBox(p1, p2, p3, p4, p5, p6, p7, p8, PANEL_FACE, PANEL_SIDE, PANEL_TOP, signNormal, signRight, signUp)

	-- Front face: leaderboard content (origin at top-left of content area)
	local frontTextPos = pos + signNormal * (panelHalfD + 0.1)
		- signRight * halfW
		+ signUp * halfH
	cam.Start3D2D(frontTextPos, frontAng, scale)
		PVPLeaderboard.DrawBoard(screenW)
	cam.End3D2D()

	-- Back face: mirrored leaderboard content
	local backAng = Angle(0, yaw + 90, 90)
	local backRight = backAng:Forward()
	local backTextPos = pos - signNormal * (panelHalfD + 0.1)
		- backRight * halfW
		+ signUp * halfH
	cam.Start3D2D(backTextPos, backAng, scale)
		PVPLeaderboard.DrawBoard(screenW)
	cam.End3D2D()
end

-------------------------------------------------
-- NET RECEIVERS
-------------------------------------------------

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

-------------------------------------------------
-- INITIAL DATA REQUEST
-------------------------------------------------

-- Request the current leaderboard from the server when the client finishes loading.
-- This ensures data is available for any Perm Props entities already on the map.
hook.Add("InitPostEntity", "PVPLeaderboard_RequestData", function()
	net.Start("PVPLeaderboard_RequestSync")
	net.SendToServer()
end)
