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
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

-- Which leaderboard period this sign displays. The 24h/7d/30d variants inherit
-- from this entity and override ENT.Period; the class itself encodes the period
-- so Perm Props restores the right board after a map change.
ENT.Period    = "alltime"
