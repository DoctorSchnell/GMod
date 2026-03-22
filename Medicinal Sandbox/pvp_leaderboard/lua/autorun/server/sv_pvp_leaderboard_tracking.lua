-- =============================================================================
--  PVP Leaderboard - Kill Tracking
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Hooks into PlayerDeath to record PVP kills and deaths.
--  Only counts kills where the attacker is tagged by the PVP Combat Timer.
-- =============================================================================

PVPLeaderboard = PVPLeaderboard or {}

-- =============================================================================
-- DEPENDENCY CHECK
-- =============================================================================

-- The PVP Combat Timer addon must be loaded for kill validation.
-- PVPCombat.IsInCombat(attacker) is the gate for counting kills.
-- If the combat timer is not present, tracking stays inactive with a warning.
local function HasCombatTimer()
	return PVPCombat and PVPCombat.IsInCombat
end

if not HasCombatTimer() then
	ServerLog("[PVP Leaderboard] WARNING: PVP Combat Timer not detected. Kill tracking will be inactive until it loads.\n")
end

-- =============================================================================
-- KILL TRACKING
-- =============================================================================

hook.Add("PlayerDeath", "PVPLeaderboard_TrackKill", function(victim, inflictor, attacker)
	-- Master toggle check
	if not PVPLeaderboard.Config.Enabled then return end

	-- PVP Combat Timer must be loaded for kill validation
	if not HasCombatTimer() then return end

	-- Both attacker and victim must be valid players
	if not IsValid(attacker) or not attacker:IsPlayer() then return end
	if not IsValid(victim) or not victim:IsPlayer() then return end

	-- Ignore self-kills (suicides, fall damage, etc.)
	if attacker == victim then return end

	-- Exclude bots from the leaderboard to avoid clutter
	if attacker:IsBot() or victim:IsBot() then return end

	-- The attacker must be combat-tagged by the PVP Combat Timer.
	-- This is the primary gate: only intentional PVP kills count.
	-- Buildmode players are already excluded at the combat timer level
	-- (they never get tagged), so no separate buildmode check is needed here.
	if not PVPCombat.IsInCombat(attacker) then return end

	-- Headshot detection: check the victim's last hit group.
	-- Works reliably for bullet weapons including CW 2.0.
	-- May miss some ACF projectile kills where hit group data is not set.
	-- This is an accepted limitation documented in the design spec.
	local isHeadshot = victim:LastHitGroup() == HITGROUP_HEAD

	-- Record the kill for the attacker (increments kills, streak, headshots)
	PVPLeaderboard.RecordKill(attacker, isHeadshot)

	-- Record the death for the victim (increments deaths, resets streak)
	PVPLeaderboard.RecordDeath(victim)

	-- Refresh the cache and broadcast the updated leaderboard to all clients.
	-- At sandbox server scale (5-25 players), this is a lightweight operation.
	PVPLeaderboard.RefreshAndBroadcast()
end)
