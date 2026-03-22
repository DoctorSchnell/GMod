-- =============================================================================
--  PVP Leaderboard - Server Entity Init
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Initializes the entity model and physics.
--  Uses a PHX 3x5 plate as the backing prop (hidden behind the display).
-- =============================================================================

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
	self:SetModel("models/hunter/plates/plate3x5.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
	end
end
