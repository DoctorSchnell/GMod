-- =============================================================================
--  Buildmode Enhancements v1.2.0
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Protects props owned by buildmode players from all damage sources
--  (ACF and standard Source engine), and prevents buildmode players
--  from dealing ACF damage.
--  Works with: Buildmode-ULX (kythre) + ACF3
-- =============================================================================

-- =============================================================================
-- HELPERS
-- =============================================================================

--- Resolve the owning player of an entity via CPPI or fallback buildOwner.
-- @param ent Entity - the entity to check ownership of
-- @return Player or nil
local function GetPropOwner(ent)
    if not IsValid(ent) then return end

    if CPPI and ent.CPPIGetOwner then
        local owner = ent:CPPIGetOwner()
        if IsValid(owner) then return owner end
    end

    if IsValid(ent.buildOwner) then
        return ent.buildOwner
    end
end

--- Trace an inflictor back to the attacking player.
-- Checks direct player, inflictor owner, and prop ownership chain.
-- @param inflictor Entity - the damage source
-- @return Player or nil
local function GetAttacker(inflictor)
    if not IsValid(inflictor) then return end

    if inflictor:IsPlayer() then return inflictor end

    if IsValid(inflictor:GetOwner()) and inflictor:GetOwner():IsPlayer() then
        return inflictor:GetOwner()
    end

    local owner = GetPropOwner(inflictor)
    if IsValid(owner) and owner:IsPlayer() then return owner end
end

--- Check if a player is currently in buildmode.
-- @param ply Player - the player to check
-- @return boolean
local function IsInBuildmode(ply)
    return IsValid(ply) and ply:IsPlayer() and ply.buildmode == true
end

-- =============================================================================
-- GENERAL DAMAGE PROTECTION (Source engine: RPG, grenades, physics, etc.)
-- =============================================================================

hook.Add("EntityTakeDamage", "BuildmodeEnhancements_PropProtect", function(target, dmginfo)
    -- Only protect non-player entities (props, vehicles, SENTs, etc.)
    if target:IsPlayer() then return end

    local owner = GetPropOwner(target)
    if not IsInBuildmode(owner) then return end

    -- Block damage TO buildmode player props
    dmginfo:SetDamage(0)
    dmginfo:ScaleDamage(0)
    return true
end)

-- =============================================================================
-- ACF3 DAMAGE PROTECTION (ACF bypasses EntityTakeDamage)
-- =============================================================================

hook.Add("ACF_PreDamageEntity", "BuildmodeEnhancements_ACFProtect", function(Entity, DmgResult, DmgInfo)
    -- Block damage TO buildmode player props
    if IsInBuildmode(GetPropOwner(Entity)) then
        return false
    end

    -- Block damage FROM buildmode players
    if IsInBuildmode(GetAttacker(DmgInfo.Attacker)) then
        return false
    end
end)
