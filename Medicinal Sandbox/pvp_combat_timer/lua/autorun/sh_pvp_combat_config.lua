-- =============================================================================
--  PVP Combat Timer - Shared Configuration
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Shared ConVars and utility functions.
--  MUST run on both server and client so replicated ConVars register in both
--  realms.
-- =============================================================================

PVPCombat = PVPCombat or {}

-- Flags: persists to cfg, replicates to clients, notifies on change
local FLAGS = bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY)

-- =============================================================================
-- CONVAR DEFINITIONS
-- =============================================================================

-- Core settings
CreateConVar("pvpcombat_enabled",  "1",  FLAGS, "Enable/disable the PVP Combat Timer system.", 0, 1)
CreateConVar("pvpcombat_cooldown", "10", FLAGS, "Seconds after attacking before restrictions lift.", 5, 30)

-- Blocklist (shared by spawn blocking and pickup blocking)
CreateConVar("pvpcombat_blocklist", "item_healthkit;item_battery", FLAGS, "Semicolon-delimited entity classes blocked during combat.")

-- Pickup blocking toggle (uses the same blocklist above)
CreateConVar("pvpcombat_block_pickup", "1", FLAGS, "Block pickup of ground items during combat.", 0, 1)

-- NWFloat key for combat expiry time
PVPCombat.NW_KEY = "PVPCombat_ExpiresAt"

-- Runtime config table (synced from ConVars so we don't call GetConVar every frame)
PVPCombat.Config = PVPCombat.Config or {}

-- =============================================================================
-- BLOCKLIST PARSING
-- =============================================================================

-- Takes a raw semicolon-delimited string, returns a lowercase lookup table.
local function ParseBlocklist(raw)
	local list = {}
	for class in string.gmatch(raw, "([^;]+)") do
		class = string.Trim(class)
		if class ~= "" then
			list[string.lower(class)] = true
		end
	end
	return list
end

--- Parse the blocklist ConVar into a lookup table
function PVPCombat.GetBlocklist()
	return ParseBlocklist(GetConVar("pvpcombat_blocklist"):GetString())
end

-- =============================================================================
-- UTILITY
-- =============================================================================

--- Check if a player is currently combat-tagged
function PVPCombat.IsInCombat(ply)
	if not IsValid(ply) then return false end
	return CurTime() < ply:GetNWFloat(PVPCombat.NW_KEY, 0)
end

--- Get remaining combat time for a player (seconds, 0 if not in combat)
function PVPCombat.GetTimeRemaining(ply)
	if not IsValid(ply) then return 0 end
	return math.max(0, ply:GetNWFloat(PVPCombat.NW_KEY, 0) - CurTime())
end

-- =============================================================================
-- SYNC CONVARS -> PVPCombat.Config
-- =============================================================================

-- Called on load and whenever a ConVar changes.
local function SyncConfig()
	PVPCombat.Config.Enabled     = GetConVar("pvpcombat_enabled"):GetBool()
	PVPCombat.Config.Cooldown    = GetConVar("pvpcombat_cooldown"):GetFloat()
	PVPCombat.Config.Blocklist   = PVPCombat.GetBlocklist()
	PVPCombat.Config.BlockPickup = GetConVar("pvpcombat_block_pickup"):GetBool()
end

SyncConfig()

-- Re-sync on any change
local syncCvars = {
	"pvpcombat_enabled", "pvpcombat_cooldown", "pvpcombat_blocklist",
	"pvpcombat_block_pickup",
}
for _, name in ipairs(syncCvars) do
	cvars.AddChangeCallback(name, function() SyncConfig() end, "pvpcombat_sync")
end
