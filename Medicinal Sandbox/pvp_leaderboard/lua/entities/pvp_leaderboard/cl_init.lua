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

-- Skip sign rendering beyond this distance squared (~7245 units).
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
-- SIGN COLORS
-- =============================================================================

local FRAME_FACE = Color(55, 55, 60)
local FRAME_SIDE = Color(40, 40, 45)
local FRAME_TOP  = Color(70, 70, 75)

local PANEL_FACE = Color(20, 20, 25)
local PANEL_SIDE = Color(10, 10, 15)
local PANEL_TOP  = Color(28, 28, 33)

-- =============================================================================
-- CACHED SIGN MESH
-- =============================================================================
--
-- The frame + panel geometry is identical for every sign in entity-local space,
-- so it is baked once into a static IMesh (in local coordinates) and drawn each
-- frame through a model matrix built from the entity's position/angles. This
-- replaces the previous approach that rebuilt the mesh — and allocated ~44
-- Vectors — every frame per sign. The box is baked double-sided (each quad
-- emitted in both windings) so it renders identically from both faces under the
-- default cull mode, matching the old two-pass CW/CCW draw.

-- Local-space axes for a flat-lying plate: local Up is the surface normal, local
-- Forward is the sign's "up", local Right is the sign's "right".
local L_NORMAL = Vector(0, 0, 1)
local L_UP     = Vector(1, 0, 0)
local L_RIGHT  = Vector(0, 1, 0)

local function MeshQuad(p1, p2, p3, p4, col)
	mesh.Position(p1) mesh.Color(col.r, col.g, col.b, 255) mesh.TexCoord(0, 0, 0) mesh.AdvanceVertex()
	mesh.Position(p2) mesh.Color(col.r, col.g, col.b, 255) mesh.TexCoord(0, 1, 0) mesh.AdvanceVertex()
	mesh.Position(p3) mesh.Color(col.r, col.g, col.b, 255) mesh.TexCoord(0, 1, 1) mesh.AdvanceVertex()
	mesh.Position(p4) mesh.Color(col.r, col.g, col.b, 255) mesh.TexCoord(0, 0, 1) mesh.AdvanceVertex()
end

-- Emit a quad in both windings (double-sided under default cull).
local function MeshQuadBoth(p1, p2, p3, p4, col)
	MeshQuad(p1, p2, p3, p4, col)
	MeshQuad(p4, p3, p2, p1, col)
end

-- Append one box (12 quads: 6 faces × 2 windings) to the mesh currently open.
local function EmitBox(ri, up, fw, faceCol, sideCol, topCol)
	local ftl =  fw - ri + up
	local ftr =  fw + ri + up
	local fbr =  fw + ri - up
	local fbl =  fw - ri - up
	local btl = -fw - ri + up
	local btr = -fw + ri + up
	local bbr = -fw + ri - up
	local bbl = -fw - ri - up

	MeshQuadBoth(fbl, fbr, ftr, ftl, faceCol) -- front face
	MeshQuadBoth(bbr, bbl, btl, btr, faceCol) -- back face
	MeshQuadBoth(fbr, bbr, btr, ftr, sideCol) -- right side
	MeshQuadBoth(bbl, fbl, ftl, btl, sideCol) -- left side
	MeshQuadBoth(ftl, ftr, btr, btl, topCol)  -- top
	MeshQuadBoth(bbl, bbr, fbr, fbl, sideCol) -- bottom
end

-- Lazily built on first Draw (needs a render context). Two boxes × 12 quads.
local signMesh

local function BuildSignMesh()
	local m = Mesh(matBox)
	mesh.Begin(m, MATERIAL_QUADS, 2 * 12)
		-- Outer frame (metal border)
		EmitBox(
			L_RIGHT * (HALF_W + BORDER_SIZE),
			L_UP * (HALF_H + BORDER_SIZE),
			L_NORMAL * HALF_D,
			FRAME_FACE, FRAME_SIDE, FRAME_TOP
		)
		-- Inner panel (protrudes slightly past the frame to cover the center face)
		EmitBox(
			L_RIGHT * HALF_W,
			L_UP * HALF_H,
			L_NORMAL * (HALF_D + 0.1),
			PANEL_FACE, PANEL_SIDE, PANEL_TOP
		)
	mesh.End()
	return m
end

-- =============================================================================
-- RENDERING
-- =============================================================================

-- Rendered in the OPAQUE pass (see ENT.RenderGroup in shared.lua). The board is
-- a solid dark panel, so drawing it opaque makes it write to the depth buffer —
-- which lets later translucent objects (chat bubbles, sprites, particles) sort
-- correctly behind it instead of being painted over the top. A translucent
-- render group (the old setting) skips depth writes and caused that overdraw.
function ENT:Draw()
	-- Model is hidden; the mesh sign replaces it visually.

	if LocalPlayer():GetPos():DistToSqr(self:GetPos()) > RENDER_DIST_SQ then return end

	-- Draw the cached local-space sign mesh through the entity's transform.
	signMesh = signMesh or BuildSignMesh()

	local matrix = Matrix()
	matrix:SetTranslation(self:GetPos())
	matrix:SetAngles(self:GetAngles())

	render.SetMaterial(matBox)
	cam.PushModelMatrix(matrix)
		signMesh:Draw()
	cam.PopModelMatrix()

	if not PVPLeaderboard or not PVPLeaderboard.DrawBoard then return end

	-- Period this sign shows (inherited classes override ENT.Period).
	local period = self.Period or "alltime"

	-- Front face 3D2D
	local frontPos = self:LocalToWorld(FRONT_OFFSET)
	local frontAng = self:LocalToWorldAngles(FRONT_ANGLE)
	cam.Start3D2D(frontPos, frontAng, SCALE)
		PVPLeaderboard.DrawBoard(SCREEN_W, period)
	cam.End3D2D()

	-- Back face 3D2D
	local backPos = self:LocalToWorld(BACK_OFFSET)
	local backAng = self:LocalToWorldAngles(BACK_ANGLE)
	cam.Start3D2D(backPos, backAng, SCALE)
		PVPLeaderboard.DrawBoard(SCREEN_W, period)
	cam.End3D2D()
end
