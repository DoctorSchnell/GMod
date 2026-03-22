-- =============================================================================
--  PVP Combat Timer - ULX Commands
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Action commands only. All config (enable/disable, cooldown, blocklist)
--  is managed through the XGUI settings panel.
-- =============================================================================

-- =============================================================================
-- TEST COMBAT TAG (tag yourself for testing)
-- =============================================================================

function ulx.pvpcombat_test(calling_ply)
	if not IsValid(calling_ply) then return end

	if not PVPCombat.Config.Enabled then
		ULib.tsayError(calling_ply, "PVP Combat Timer is currently disabled.")
		return
	end

	-- Tag the calling player using the configured cooldown
	local expiresAt = CurTime() + PVPCombat.Config.Cooldown
	calling_ply:SetNWFloat(PVPCombat.NW_KEY, expiresAt)

	local seconds = math.ceil(PVPCombat.Config.Cooldown)
	ulx.fancyLogAdmin(calling_ply, "#A activated a combat tag on themselves for #s seconds.", seconds)
end

local test = ulx.command("PVP Combat Timer", "ulx pvpcombat_test", ulx.pvpcombat_test, "!pvpcombattest")
test:defaultAccess(ULib.ACCESS_ADMIN)
test:help("Tag yourself as in-combat for testing purposes.")

-- =============================================================================
-- CLEAR COMBAT TAG (admin override)
-- =============================================================================

function ulx.pvpcombat_cleartag(calling_ply, target_ply)
	if not IsValid(target_ply) then
		ULib.tsayError(calling_ply, "Invalid player.")
		return
	end

	target_ply:SetNWFloat(PVPCombat.NW_KEY, 0)
	ulx.fancyLogAdmin(calling_ply, "#A cleared the combat tag on #T.", target_ply)
end

local cleartag = ulx.command("PVP Combat Timer", "ulx pvpcombat_cleartag", ulx.pvpcombat_cleartag, "!pvpcombatclear")
cleartag:addParam{type = ULib.cmds.PlayerArg}
cleartag:defaultAccess(ULib.ACCESS_SUPERADMIN)
cleartag:help("Clear a player's combat tag manually.")
