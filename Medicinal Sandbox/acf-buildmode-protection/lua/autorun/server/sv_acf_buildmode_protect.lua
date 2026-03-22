-- =============================================================================
--  ACF Buildmode Prop Protection
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Blocks ACF damage on props owned by players in build mode,
--  and prevents buildmode players from dealing ACF damage.
--  Works with: Buildmode-ULX (kythre) + ACF2 (and ACF extra weapons)
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

hook.Add("Initialize", "BuildmodeACFProtection_Init", function()
    timer.Simple(1, function()
        if not ACF_Damage then return end

        local OriginalACF_Damage = ACF_Damage

        function ACF_Damage(Entity, Energy, FrAera, Angle, Inflictor, Bone, ...)
            -- Block damage TO buildmode player props
            if IsInBuildmode(GetPropOwner(Entity)) then
                return { Damage = 0, Overkill = 0, Loss = 0, Kill = false }
            end

            -- Block damage FROM buildmode players
            if IsInBuildmode(GetAttacker(Inflictor)) then
                return { Damage = 0, Overkill = 0, Loss = 0, Kill = false }
            end

            return OriginalACF_Damage(Entity, Energy, FrAera, Angle, Inflictor, Bone, ...)
        end
    end)
end)
