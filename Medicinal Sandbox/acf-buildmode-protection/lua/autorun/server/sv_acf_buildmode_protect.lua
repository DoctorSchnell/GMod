--[[
    ACF Buildmode Prop Protection
    Blocks ACF damage on props owned by players in build mode,
    and prevents buildmode players from dealing ACF damage.
    Drop this addon folder into your server's addons directory.
    Works with: Buildmode-ULX (kythre) + ACF2 (and ACF extra weapons)
]]

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

local function GetAttacker(inflictor)
    if not IsValid(inflictor) then return end

    if inflictor:IsPlayer() then return inflictor end

    if IsValid(inflictor:GetOwner()) and inflictor:GetOwner():IsPlayer() then
        return inflictor:GetOwner()
    end

    local owner = GetPropOwner(inflictor)
    if IsValid(owner) and owner:IsPlayer() then return owner end
end

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
