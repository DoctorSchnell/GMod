--[[
	PVP Combat Timer - Client HUD & Notifications
	Combat countdown HUD element and deny messages for spawning and pickup.
	Author: Doctor Schnell
]]

PVPCombat = PVPCombat or {}

-------------------------------------------------
-- HUD ELEMENT
-------------------------------------------------

-- Layout constants
local ICON_SIZE = 24
local BAR_WIDTH = 120
local BAR_HEIGHT = 6
local PADDING = 8
local PANEL_WIDTH = ICON_SIZE + PADDING + BAR_WIDTH + PADDING * 2
local PANEL_HEIGHT = ICON_SIZE + PADDING * 2

-- Colors
local COLOR_BG        = Color(20, 20, 20, 200)
local COLOR_BG_BORDER = Color(200, 60, 60, 180)
local COLOR_BAR_BG    = Color(40, 40, 40, 200)
local COLOR_BAR_FILL  = Color(220, 50, 50, 255)
local COLOR_BAR_FADE  = Color(220, 160, 50, 255)
local COLOR_TEXT      = Color(255, 255, 255, 255)
local COLOR_ICON      = Color(220, 60, 60, 255)

-- Smooth fade tracking
local hudAlpha = 0

-- Simple crosshair/target icon using basic draw calls
local function DrawCombatIcon(x, y, size, alpha)
	local col = ColorAlpha(COLOR_ICON, alpha)
	surface.SetDrawColor(col)

	local cx, cy = x + size / 2, y + size / 2
	local r = size / 2 - 2

	-- Outer ring
	draw.NoTexture()
	surface.DrawCircle(cx, cy, r, col)

	-- Cross lines
	surface.DrawLine(cx - r + 2, cy, cx + r - 2, cy)
	surface.DrawLine(cx, cy - r + 2, cx, cy + r - 2)

	-- Inner dot
	draw.RoundedBox(4, cx - 2, cy - 2, 4, 4, col)
end

hook.Add("HUDPaint", "PVPCombat_HUD", function()
	if not PVPCombat.Config or not PVPCombat.Config.Enabled then
		hudAlpha = 0
		return
	end

	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then
		hudAlpha = 0
		return
	end

	local inCombat = PVPCombat.IsInCombat(ply)
	local remaining = PVPCombat.GetTimeRemaining(ply)
	local cooldown = PVPCombat.Config.Cooldown or 10

	-- Smooth fade in/out
	local targetAlpha = inCombat and 255 or 0
	hudAlpha = Lerp(FrameTime() * 6, hudAlpha, targetAlpha)

	if hudAlpha < 1 then return end

	-- Position: top-center
	local x = (ScrW() - PANEL_WIDTH) / 2
	local y = 10
	local alpha = math.floor(hudAlpha)
	local fraction = remaining / cooldown

	-- Background panel
	draw.RoundedBox(6, x, y, PANEL_WIDTH, PANEL_HEIGHT, ColorAlpha(COLOR_BG, alpha * 0.78))

	-- Border highlight
	if alpha > 10 then
		surface.SetDrawColor(ColorAlpha(COLOR_BG_BORDER, alpha * 0.5))
		surface.DrawOutlinedRect(x, y, PANEL_WIDTH, PANEL_HEIGHT, 1)
	end

	-- Combat icon
	local iconX = x + PADDING
	local iconY = y + (PANEL_HEIGHT - ICON_SIZE) / 2
	DrawCombatIcon(iconX, iconY, ICON_SIZE, alpha)

	-- Timer text
	local textX = iconX + ICON_SIZE + PADDING
	local textY = y + PADDING - 1
	draw.SimpleText(
		string.format("IN COMBAT  %.1fs", remaining),
		"DermaDefaultBold",
		textX, textY,
		ColorAlpha(COLOR_TEXT, alpha),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
	)

	-- Progress bar background
	local barX = textX
	local barY = textY + 16
	draw.RoundedBox(3, barX, barY, BAR_WIDTH, BAR_HEIGHT, ColorAlpha(COLOR_BAR_BG, alpha * 0.78))

	-- Progress bar fill (color shifts from red to yellow as time runs down)
	local barFillWidth = math.Clamp(fraction, 0, 1) * BAR_WIDTH
	if barFillWidth > 0 then
		local barColor = fraction > 0.3 and COLOR_BAR_FILL or COLOR_BAR_FADE
		draw.RoundedBox(3, barX, barY, barFillWidth, BAR_HEIGHT, ColorAlpha(barColor, alpha))
	end
end)

-------------------------------------------------
-- SPAWN DENY NOTIFICATION
-------------------------------------------------

net.Receive("PVPCombat_DenyNotify", function()
	local class = net.ReadString()
	local remaining = net.ReadUInt(8)

	chat.AddText(
		Color(220, 50, 50), "[PVP Combat] ",
		Color(255, 255, 255), "You can't spawn ",
		Color(255, 200, 100), class,
		Color(255, 255, 255), " while in combat! ",
		Color(200, 200, 200), string.format("(%ds remaining)", remaining)
	)

	surface.PlaySound("buttons/button10.wav")
end)

-------------------------------------------------
-- PICKUP DENY NOTIFICATION
-------------------------------------------------

net.Receive("PVPCombat_PickupDeny", function()
	local class = net.ReadString()
	local remaining = net.ReadUInt(8)

	chat.AddText(
		Color(220, 50, 50), "[PVP Combat] ",
		Color(255, 255, 255), "You can't pick up ",
		Color(255, 200, 100), class,
		Color(255, 255, 255), " while in combat! ",
		Color(200, 200, 200), string.format("(%ds remaining)", remaining)
	)

	surface.PlaySound("buttons/button10.wav")
end)
