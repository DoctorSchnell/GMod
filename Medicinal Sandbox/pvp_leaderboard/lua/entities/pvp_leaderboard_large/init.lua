--[[
	PVP Leaderboard (Large) - Server
	Custom physics box matching the 3D sign dimensions.
	Author: Doctor Schnell
]]

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

-- Sign physics half-extents (matches client-side rendering)
-- Width: (470 * 0.40) / 2 + 1.5 border = 95.5
-- Height: (300 * 0.40) / 2 + 1.5 border = 61.5
-- Depth: 3 / 2 = 1.5
local HALF_DEPTH  = 1.5
local HALF_WIDTH  = 95.5
local HALF_HEIGHT = 61.5

function ENT:Initialize()
	self:SetModel("models/hunter/plates/plate1x1.mdl")
	self:PhysicsInitBox(
		Vector(-HALF_DEPTH, -HALF_WIDTH, -HALF_HEIGHT),
		Vector(HALF_DEPTH, HALF_WIDTH, HALF_HEIGHT)
	)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
	end
end
