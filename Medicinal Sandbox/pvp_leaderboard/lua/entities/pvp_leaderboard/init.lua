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
-- ACF-3 DAMAGE PROTECTION
-- ACF bypasses the normal damage system (OnTakeDamage/EntityTakeDamage), so we
-- veto damage to any leaderboard sign via ACF-3's native ACF_PreDamageEntity
-- hook (returning false cancels the damage). This replaces the old ACF2-era
-- global ACF_Damage wrapper, which no longer exists on ACF-3. Registered once
-- from the base entity file (the variants inherit and never re-run this);
-- ClassToPeriod covers all four sign classes. Skipped cleanly if ACF is absent.
-- =============================================================================

hook.Add("ACF_PreDamageEntity", "PVPLeaderboard_ACFProtection", function(Entity)
	if IsValid(Entity) and PVPLeaderboard.ClassToPeriod[Entity:GetClass()] then
		return false
	end
end)
