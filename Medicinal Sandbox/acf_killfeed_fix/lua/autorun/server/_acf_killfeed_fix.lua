-- =============================================================================
--  ACF Killfeed Fix  |  v3.0
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Removes ACF's killfeed hooks after initialisation, restoring
--  base gamemode killfeed behaviour and preventing duplicates.
-- =============================================================================

--- Remove ACF's custom killfeed hooks after all addons have loaded.
-- The base gamemode already handles killfeed entries cleanly; ACF's
-- duplicates cause double death notifications in the top-right corner.
hook.Add("InitPostEntity", "ACF_KillfeedFix", function()
    hook.Remove("OnNPCKilled", "ACF_OnNPCKilled")
    hook.Remove("PlayerDeath", "ACF_PlayerDeath")
end)
