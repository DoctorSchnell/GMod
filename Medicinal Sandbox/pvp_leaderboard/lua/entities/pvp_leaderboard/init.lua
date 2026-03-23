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

-- Prevent explosive blast force from moving the entity.
-- PhysicsSimulate only fires when the physics object is awake, so this has
-- zero cost while frozen. If something wakes the object, we immediately zero
-- all velocity so it never visibly moves. IsPlayerHolding() allows normal
-- physgun interaction.
function ENT:PhysicsSimulate(phys, deltatime)
	if not self:IsPlayerHolding() then
		phys:SetVelocity(Vector(0, 0, 0))
		phys:SetAngleVelocity(Vector(0, 0, 0))
		return SIM_NOTHING
	end
end

-- Re-freeze the physics object after something wakes it (e.g. explosion).
-- Throttled to 4x/sec — just puts the object back to sleep.
function ENT:Think()
	if not self:IsPlayerHolding() then
		local phys = self:GetPhysicsObject()
		if IsValid(phys) and phys:IsMotionEnabled() then
			phys:EnableMotion(false)
		end
	end
	self:NextThink(CurTime() + 0.25)
	return true
end

-- Block standard GMod damage (bullets, explosions, fire, etc.)
function ENT:OnTakeDamage(dmginfo)
	return false
end

-- =============================================================================
-- ACF DAMAGE PROTECTION
-- ACF bypasses the normal damage system, so we wrap ACF_Damage directly.
-- Same pattern as acf-buildmode-protection: Initialize hook + 1s delay
-- ensures ACF_Damage is defined before we wrap it.
-- =============================================================================

hook.Add("Initialize", "PVPLeaderboard_ACFProtection", function()
	timer.Simple(1, function()
		if not ACF_Damage then return end

		local OriginalACF_Damage = ACF_Damage

		function ACF_Damage(Entity, Energy, FrAera, Angle, Inflictor, Bone, ...)
			if IsValid(Entity) and Entity:GetClass() == "pvp_leaderboard" then
				return { Damage = 0, Overkill = 0, Loss = 0, Kill = false }
			end

			return OriginalACF_Damage(Entity, Energy, FrAera, Angle, Inflictor, Bone, ...)
		end
	end)
end)
