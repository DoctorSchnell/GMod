-- =============================================================================
--  PVP Leaderboard (24 Hour) - Shared Entity Registration
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Thin variant of the base `pvp_leaderboard` sign that displays the rolling
--  24-hour board. All physics, damage protection, freezing, and 3D2D rendering
--  are inherited from the base via ENT.Base; only the period and display name
--  differ. The period is encoded in the class name so Perm Props restores the
--  correct board after a map change.
-- =============================================================================

ENT.Type      = "anim"
ENT.Base      = "pvp_leaderboard"

ENT.PrintName = "PVP Leaderboard (24 Hour)"
ENT.Author    = "Doctor Schnell & Claude (Anthropic)"
ENT.Category  = "PVP Leaderboard"

ENT.Spawnable = true
ENT.RenderGroup = RENDERGROUP_OPAQUE  -- opaque so it writes depth; see base entity

ENT.Period    = "24h"
