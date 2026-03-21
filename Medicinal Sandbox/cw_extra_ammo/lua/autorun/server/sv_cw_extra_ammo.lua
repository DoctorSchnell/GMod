-- =============================================================================
--  Extra Ammo on Weapon Pickup / Spawn
--  Author: Doctor Schnell
--
--  Gives players additional reserve ammo whenever they receive any weapon,
--  including CW 2.0 weapons, HL2 base weapons, and any other SWEP that
--  follows standard GMod ammo conventions.
--
--  Handles both primary and secondary ammo (e.g. SMG1 grenades, AR2 orbs).
-- =============================================================================

-- Number of extra full magazines to grant for primary (and clipped secondary)
-- ammo each time a weapon is received.
local EXTRA_MAGAZINES = 20

-- Flat amount of ammo to grant for clipless secondary ammo (e.g. SMG grenades,
-- AR2 energy orbs). These don't have a magazine size so a fixed amount is used.
local EXTRA_SECONDARY = 25


-- Helper: give extra reserve ammo for a clipped slot (primary or secondary).
-- Uses GetMaxClip to determine magazine size, multiplied by EXTRA_MAGAZINES.
-- ammoType is an integer ID (-1 means no ammo, e.g. crowbar).
-- maxClip is the maximum clip size for this slot.
local function giveClippedAmmo(ply, ammoType, maxClip)
    if not ammoType or ammoType < 0 then return end
    if not maxClip or maxClip <= 0 then return end

    ply:GiveAmmo(maxClip * EXTRA_MAGAZINES, ammoType, true)
end

-- Helper: give a flat amount of ammo for a clipless slot (e.g. SMG grenades).
-- ammoType is an integer ID, maxClip should be -1 to reach this branch.
local function giveCliplessAmmo(ply, ammoType, maxClip)
    if not ammoType or ammoType < 0 then return end
    if not maxClip or maxClip > 0 then return end  -- only for clipless slots

    ply:GiveAmmo(EXTRA_SECONDARY, ammoType, true)
end

-- Process a single weapon, giving ammo for both primary and secondary slots.
local function processWeapon(ply, wep)
    if not IsValid(ply) or not IsValid(wep) then return end

    local ammoType1 = wep:GetPrimaryAmmoType()
    local ammoType2 = wep:GetSecondaryAmmoType()
    local maxClip1  = wep:GetMaxClip1()
    local maxClip2  = wep:GetMaxClip2()

    -- Primary: always clipped
    giveClippedAmmo(ply, ammoType1, maxClip1)

    -- Secondary: clipped (e.g. some SWEPs) or clipless (e.g. SMG grenades)
    giveClippedAmmo(ply,  ammoType2, maxClip2)
    giveCliplessAmmo(ply, ammoType2, maxClip2)
end


-- Fires when a player picks up a weapon off the ground, is given one via the
-- Q menu weapons tab, or receives one as part of the spawn loadout.
-- A one-frame defer ensures the weapon is fully initialized before we read it.
hook.Add("PlayerCanPickupWeapon", "ExtraAmmoOnPickup", function(ply, wep)
    timer.Simple(0, function()
        processWeapon(ply, wep)
    end)
end)
