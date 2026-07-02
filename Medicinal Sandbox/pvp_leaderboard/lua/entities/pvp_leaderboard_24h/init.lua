-- =============================================================================
--  PVP Leaderboard (24 Hour) - Server Entity Init
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  All behaviour (model, physics, freezing, ACF/standard damage protection) is
--  inherited from the base `pvp_leaderboard` entity via ENT.Base in shared.lua.
--  This file exists so GMod reliably registers and networks the class: on this
--  server a shared.lua-only variant does NOT appear in the Q menu, so the thin
--  init/cl_init/shared trio is required, not just convention.
-- =============================================================================

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
