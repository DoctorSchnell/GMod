-- =============================================================================
--  PVP Leaderboard - Shared Entity Registration
--  Author: Doctor Schnell & Claude (Anthropic)
-- =============================================================================

ENT.Type      = "anim"
ENT.Base      = "base_gmodentity"

ENT.PrintName = "PVP Leaderboard (All Time)"
ENT.Author    = "Doctor Schnell & Claude (Anthropic)"
ENT.Category  = "PVP Leaderboard"

ENT.Spawnable = true
-- Opaque so the sign writes depth and translucent objects (chat bubbles, sprites,
-- particles) sort correctly behind it. It was RENDERGROUP_TRANSLUCENT, which
-- skipped depth writes and let those objects overdraw the board. The board panel
-- is effectively solid, so nothing is lost by rendering it opaque.
ENT.RenderGroup = RENDERGROUP_OPAQUE

-- Which leaderboard period this sign displays. The 24h/7d/30d variants inherit
-- from this entity and override ENT.Period; the class itself encodes the period
-- so Perm Props restores the right board after a map change.
ENT.Period    = "alltime"
