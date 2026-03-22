-- =============================================================================
--  PVP Leaderboard - Client Entity Rendering
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Metal-framed floating sign with 3D2D leaderboard rendering on both faces.
--  Uses a PHX 3x5 plate for collision (model hidden).
-- =============================================================================

include("shared.lua")

-- =============================================================================
-- SCREEN CONSTANTS
-- =============================================================================

-- Width of the leaderboard in 3D2D coordinate units
local SCREEN_W = 940

-- Scale: maps 3D2D units to game units.
-- At 0.25, the 940-unit-wide screen spans ~235 game units (fits the 3x5 plate).
-- Half the scale of the original 0.50 for 2x sharper text rendering.
local SCALE = 0.25

-- Fixed content height: 10 rows (title + header + 10 data rows + padding).
-- 72 + 48 + 45.5*10 + 1 = 576 3D2D units → 144 game units at 0.25 scale.
local CONTENT_H = 576

-- Computed game-unit dimensions
local GAME_W = SCREEN_W * SCALE   -- 235
local GAME_H = CONTENT_H * SCALE  -- 144
local HALF_W = GAME_W / 2         -- 117.5
local HALF_H = GAME_H / 2         -- 72

-- Sign construction
local BORDER_SIZE = 1.5
local SIGN_DEPTH = 3
local HALF_D = SIGN_DEPTH / 2

-- Skip 3D2D rendering beyond this distance squared (~1500 units).
local RENDER_DIST_SQ = 52500000

-- 3D2D text offsets and angles (entity local space)
local PANEL_FRONT = HALF_D + 0.4
local FRONT_OFFSET = Vector(-HALF_H, -HALF_W, PANEL_FRONT)
local FRONT_ANGLE  = Angle(0, 90, 0)
local BACK_OFFSET  = Vector(-HALF_H, HALF_W, -PANEL_FRONT)
local BACK_ANGLE   = Angle(0, -90, 180)

-- =============================================================================
-- MATERIAL (vertex-color, fully opaque)
-- =============================================================================

local matBox = CreateMaterial("PVPLeaderboard_SignMat_" .. SysTime(), "UnlitGeneric", {
	["$basetexture"] = "color/white",
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 0,
	["$nolod"] = 1,
})

-- =============================================================================
-- 3D BOX HELPERS
-- =============================================================================

local function MeshQuad(p1, p2, p3, p4, normal, col)
	mesh.Position(p1) mesh.Normal(normal) mesh.Color(col.r, col.g, col.b, 255) mesh.TexCoord(0, 0, 0) mesh.AdvanceVertex()
	mesh.Position(p2) mesh.Normal(normal) mesh.Color(col.r, col.g, col.b, 255) mesh.TexCoord(0, 1, 0) mesh.AdvanceVertex()
	mesh.Position(p3) mesh.Normal(normal) mesh.Color(col.r, col.g, col.b, 255) mesh.TexCoord(0, 1, 1) mesh.AdvanceVertex()
	mesh.Position(p4) mesh.Normal(normal) mesh.Color(col.r, col.g, col.b, 255) mesh.TexCoord(0, 0, 1) mesh.AdvanceVertex()
end

local function DrawMeshBox(ftl, ftr, fbr, fbl, btl, btr, bbr, bbl, faceCol, sideCol, topCol, nF, nR, nU)
	render.SetMaterial(matBox)

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

-- =============================================================================
-- SIGN COLORS
-- =============================================================================

local FRAME_FACE = Color(55, 55, 60)
local FRAME_SIDE = Color(40, 40, 45)
local FRAME_TOP  = Color(70, 70, 75)

local PANEL_FACE = Color(20, 20, 25)
local PANEL_SIDE = Color(10, 10, 15)
local PANEL_TOP  = Color(28, 28, 33)

-- =============================================================================
-- RENDERING
-- =============================================================================

function ENT:Draw()
	-- Model is hidden; the mesh sign replaces it visually.

	if LocalPlayer():GetPos():DistToSqr(self:GetPos()) > RENDER_DIST_SQ then return end

	local pos = self:GetPos()
	local ang = self:GetAngles()

	-- Orientation vectors from entity angles.
	-- The plate lies flat: Up = surface normal, Forward/Right = plane axes.
	local signNormal = ang:Up()
	local signUp     = ang:Forward()
	local signRight  = ang:Right()

	-- Outer frame (metal border)
	local fri = signRight * (HALF_W + BORDER_SIZE)
	local fup = signUp * (HALF_H + BORDER_SIZE)
	local ffw = signNormal * HALF_D
	local f1, f2, f3, f4, f5, f6, f7, f8 = BoxCorners(pos, fri, fup, ffw)
	DrawMeshBox(f1, f2, f3, f4, f5, f6, f7, f8, FRAME_FACE, FRAME_SIDE, FRAME_TOP, signNormal, signRight, signUp)

	-- Inner panel (protrudes slightly past frame so it covers the center face)
	local panelHalfD = HALF_D + 0.1
	local pri = signRight * HALF_W
	local pup = signUp * HALF_H
	local pfw = signNormal * panelHalfD
	local p1, p2, p3, p4, p5, p6, p7, p8 = BoxCorners(pos, pri, pup, pfw)
	DrawMeshBox(p1, p2, p3, p4, p5, p6, p7, p8, PANEL_FACE, PANEL_SIDE, PANEL_TOP, signNormal, signRight, signUp)

	if not PVPLeaderboard or not PVPLeaderboard.DrawBoard then return end

	-- Front face 3D2D
	local frontPos = self:LocalToWorld(FRONT_OFFSET)
	local frontAng = self:LocalToWorldAngles(FRONT_ANGLE)
	cam.Start3D2D(frontPos, frontAng, SCALE)
		PVPLeaderboard.DrawBoard(SCREEN_W)
	cam.End3D2D()

	-- Back face 3D2D
	local backPos = self:LocalToWorld(BACK_OFFSET)
	local backAng = self:LocalToWorldAngles(BACK_ANGLE)
	cam.Start3D2D(backPos, backAng, SCALE)
		PVPLeaderboard.DrawBoard(SCREEN_W)
	cam.End3D2D()
end
