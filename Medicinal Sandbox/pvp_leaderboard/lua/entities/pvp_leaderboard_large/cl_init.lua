--[[
	PVP Leaderboard (Large) - Client
	Metal-framed 3D sign with leaderboard on both faces.
	Billboard-scale sign for outdoor areas and high visibility.
	Author: Doctor Schnell
]]

include("shared.lua")

-------------------------------------------------
-- SIGN CONSTANTS
-------------------------------------------------

-- Width of the leaderboard in 3D2D coordinate units (shared across all sizes)
local SCREEN_W = 470

-- Scale: maps 3D2D units to game units.
-- At 0.40, the 470-unit-wide screen spans ~188 game units.
local SCALE = 0.40

-- Metal frame border width in world units
local BORDER_SIZE = 1.5

-- Skip rendering beyond this distance squared (~1500 units).
local RENDER_DIST_SQ = 2250000

-- Render bounds (conservative, covers sign in any yaw orientation)
local CONTENT_W = SCREEN_W * SCALE
local CONTENT_H_EST = 300 * SCALE
local BOUND_XY = CONTENT_W / 2 + BORDER_SIZE + 5
local BOUND_Z  = CONTENT_H_EST / 2 + BORDER_SIZE + 5

-------------------------------------------------
-- RENDERING
-------------------------------------------------

function ENT:Initialize()
	self:SetRenderBounds(
		Vector(-BOUND_XY, -BOUND_XY, -BOUND_Z),
		Vector(BOUND_XY, BOUND_XY, BOUND_Z)
	)
end

function ENT:Draw()
	if not PVPLeaderboard or not PVPLeaderboard.DrawSign then return end

	if LocalPlayer():GetPos():DistToSqr(self:GetPos()) > RENDER_DIST_SQ then return end

	PVPLeaderboard.DrawSign(self:GetPos(), self:GetAngles().y, SCREEN_W, SCALE, BORDER_SIZE)
end
