-- ============================================================
--  ACF Killfeed Fix  |  v3.0
--  Removes ACF's killfeed hooks after initialisation, restoring
--  base gamemode killfeed behaviour and preventing duplicates.
-- ============================================================

hook.Add("InitPostEntity", "ACF_KillfeedFix", function()
    hook.Remove("OnNPCKilled", "ACF_OnNPCKilled")
    hook.Remove("PlayerDeath", "ACF_PlayerDeath")
end)
