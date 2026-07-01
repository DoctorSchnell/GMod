-- =============================================================================
--  PVP Leaderboard (30 Day) - Server Entity Init
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  All behaviour (model, physics, freezing, ACF/standard damage protection) is
--  inherited from the base `pvp_leaderboard` entity via ENT.Base in shared.lua.
--  This file exists only so GMod reliably registers and networks the class,
--  mirroring the base's init/cl_init/shared structure.
-- =============================================================================

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
