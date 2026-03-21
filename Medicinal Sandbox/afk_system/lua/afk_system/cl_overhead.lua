--[[
    AFK System - 3D Spinning Overhead Sign
    Metal-framed sign with a solid opaque colored panel.
    Two nested mesh boxes: outer frame (dark metal) + inner panel (sign color).
    Text on front and back faces via cam.Start3D2D.
    Rotation synced across clients via shared NW float.
]]--

-------------------------------------------------
-- FONTS
-------------------------------------------------

surface.CreateFont("AFK_OverheadMain", {
    font = "Roboto",
    size = 110,
    weight = 700,
    antialias = true,
    shadow = false,
})

surface.CreateFont("AFK_OverheadSub", {
    font = "Roboto",
    size = 52,
    weight = 400,
    antialias = true,
    shadow = false,
})

-------------------------------------------------
-- MATERIAL (vertex-color, fully opaque)
-------------------------------------------------

local matBox = CreateMaterial("AFK_SignBoxMat_" .. SysTime(), "UnlitGeneric", {
    ["$basetexture"] = "color/white",
    ["$vertexcolor"] = 1,
    ["$vertexalpha"] = 0,
    ["$nolod"] = 1,
})

-------------------------------------------------
-- 3D BOX
-------------------------------------------------

local function MeshQuad(p1, p2, p3, p4, normal, col)
    mesh.Position(p1) mesh.Normal(normal) mesh.Color(col.r, col.g, col.b, 255) mesh.TexCoord(0, 0, 0) mesh.AdvanceVertex()
    mesh.Position(p2) mesh.Normal(normal) mesh.Color(col.r, col.g, col.b, 255) mesh.TexCoord(0, 1, 0) mesh.AdvanceVertex()
    mesh.Position(p3) mesh.Normal(normal) mesh.Color(col.r, col.g, col.b, 255) mesh.TexCoord(0, 1, 1) mesh.AdvanceVertex()
    mesh.Position(p4) mesh.Normal(normal) mesh.Color(col.r, col.g, col.b, 255) mesh.TexCoord(0, 0, 1) mesh.AdvanceVertex()
end

--- Draw a box from 8 corners with face/side/top colors.
local function DrawBox(ftl, ftr, fbr, fbl, btl, btr, bbr, bbl, faceCol, sideCol, topCol, nF, nR, nU)
    render.SetMaterial(matBox)

    for _, cullMode in ipairs({MATERIAL_CULLMODE_CW, MATERIAL_CULLMODE_CCW}) do
        render.CullMode(cullMode)
        mesh.Begin(MATERIAL_QUADS, 6)
            MeshQuad(fbl, fbr, ftr, ftl, nF, faceCol)
            MeshQuad(bbr, bbl, btl, btr, -nF, faceCol)
            MeshQuad(fbr, bbr, btr, ftr, nR, sideCol)
            MeshQuad(bbl, fbl, ftl, btl, -nR, sideCol)
            MeshQuad(ftl, ftr, btr, btl, nU, topCol)
            MeshQuad(bbl, bbr, fbr, fbl, -nU, sideCol)
        mesh.End()
    end

    render.CullMode(MATERIAL_CULLMODE_CCW)
end

--- Build 8 corners of a box centered at `pos`.
local function BoxCorners(pos, ri, up, fw)
    local ftl = pos + fw - ri + up
    local ftr = pos + fw + ri + up
    local fbr = pos + fw + ri - up
    local fbl = pos + fw - ri - up
    local btl = pos - fw - ri + up
    local btr = pos - fw + ri + up
    local bbr = pos - fw + ri - up
    local bbl = pos - fw - ri - up
    return ftl, ftr, fbr, fbl, btl, btr, bbr, bbl
end

-------------------------------------------------
-- TEXT OVERLAY
-------------------------------------------------

local function DrawSignText(signW, signH, tw, th, elapsed, stw, sth, fadeFrac, pulse)
    local textColor = ColorAlpha(AFK.Config.OverheadTextColor, 255 * fadeFrac * pulse)
    local padY = 14
    local textY = -signH / 2 + padY

    -- Drop shadow
    draw.SimpleText("AFK", "AFK_OverheadMain", 2, textY + 2,
        ColorAlpha(color_black, 180 * fadeFrac), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    draw.SimpleText("AFK", "AFK_OverheadMain", 0, textY,
        textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

    if elapsed ~= "" then
        local subColor = ColorAlpha(color_white, 210 * fadeFrac)
        draw.SimpleText(elapsed, "AFK_OverheadSub", 0, textY + th + 2,
            subColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
end

-------------------------------------------------
-- RENDERING
-------------------------------------------------

hook.Add("PostDrawTranslucentRenderables", "AFK_OverheadText", function(bDepth, bSkybox)
    if bSkybox then return end
    if not AFK.Config.ShowOverhead then return end

    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    local lpPos = lp:GetPos()
    local maxDist = AFK.Config.OverheadMaxDist
    local maxDistSqr = maxDist * maxDist

    local scale = AFK.Config.OverheadScale
    local curTime = CurTime()
    local bob = math.sin(curTime * 1.5) * 1.5
    local pulse = 0.85 + math.sin(curTime * 2.5) * 0.15
    local offset = AFK.Config.OverheadOffset

    -- Frame border width in world units
    local borderSize = 0.9
    -- Sign depth in world units
    local signDepth = 3

    surface.SetFont("AFK_OverheadMain")
    local tw, th = surface.GetTextSize("AFK")

    for _, ply in ipairs(player.GetAll()) do
        if not ply:GetNWBool(AFK.NW_IS_AFK, false) then continue end

        local isLocalPlayer = (ply == lp)
        if isLocalPlayer and not AFK.Config.ShowOverheadSelf then continue end

        local targetEnt = ply
        if not ply:Alive() then
            local ragdoll = ply:GetRagdollEntity()
            if IsValid(ragdoll) then
                targetEnt = ragdoll
            else
                continue
            end
        end

        local entPos = targetEnt:GetPos()
        local dist = lpPos:DistToSqr(entPos)
        if not isLocalPlayer and dist > maxDistSqr then continue end

        local fadeFrac
        if isLocalPlayer then
            fadeFrac = 1
        else
            fadeFrac = 1 - math.Clamp(dist / maxDistSqr, 0, 1)
            fadeFrac = fadeFrac ^ 0.3
        end

        -- Position above head. For the local player in first person, use EyePos
        -- so the sign is centered above the camera. In third person or for other
        -- players, use the head bone so it sits on the model.
        local headPos
        local isFirstPerson = isLocalPlayer and (GetViewEntity() == lp) and not lp:ShouldDrawLocalPlayer()

        if isFirstPerson then
            headPos = lp:EyePos()
        else
            local headBone = targetEnt:LookupBone("ValveBiped.Bip01_Head1")
            if headBone then
                headPos = targetEnt:GetBonePosition(headBone)
            end
            if not headPos then
                headPos = entPos + Vector(0, 0, targetEnt:OBBMaxs().z)
            end
        end

        local pos = headPos + Vector(0, 0, offset + bob)

        -- Synced spin
        local since = ply:GetNWFloat(AFK.NW_SINCE, 0)
        local spinSpeed = AFK.Config.OverheadSpinSpeed or 30
        local spinYaw = 0
        if since > 0 then
            spinYaw = ((curTime - since) * spinSpeed) % 360
        end

        -- Elapsed time
        local elapsed = ""
        if since > 0 then
            local secs = math.floor(curTime - since)
            local mins = math.floor(secs / 60)
            secs = secs % 60
            if mins > 0 then
                elapsed = string.format("%dm %02ds", mins, secs)
            else
                elapsed = string.format("%ds", secs)
            end
        end

        surface.SetFont("AFK_OverheadSub")
        local stw, sth = surface.GetTextSize(elapsed)

        -- Sign dimensions
        local padX = 55
        local padY = 14
        local signW = math.max(tw, stw) + padX * 2
        local signH = th + padY * 2
        if elapsed ~= "" then
            signH = signH + sth + 2
        end

        -- Orientation from the known-good text panel angle
        local frontAng = Angle(0, spinYaw - 90, 90)
        local signRight  = frontAng:Forward()
        local signUp     = Vector(0, 0, 1)
        local signNormal = signRight:Cross(signUp)
        signNormal:Normalize()

        -- Half-extents for the inner sign panel
        local halfW = (signW / 2) * scale
        local halfH = (signH / 2) * scale
        local halfD = signDepth / 2

        -- Metal frame colors (dark gunmetal gray, fully opaque)
        local frameFace = Color(55, 55, 60)
        local frameSide = Color(40, 40, 45)
        local frameTop  = Color(70, 70, 75)

        -- Outer frame box (larger than the sign panel on all axes)
        local frameHalfW = halfW + borderSize
        local frameHalfH = halfH + borderSize
        local frameHalfD = halfD

        local fri = signRight * frameHalfW
        local fup = signUp * frameHalfH
        local ffw = signNormal * frameHalfD
        local f1, f2, f3, f4, f5, f6, f7, f8 = BoxCorners(pos, fri, fup, ffw)
        DrawBox(f1, f2, f3, f4, f5, f6, f7, f8, frameFace, frameSide, frameTop, signNormal, signRight, signUp)

        -- Inner sign panel (the colored part)
        -- Protrudes slightly past the frame front/back so it covers
        -- the center of the frame's front/back faces, leaving the border visible.
        local bg = AFK.Config.OverheadBgColor
        local panelFace = Color(bg.r, bg.g, bg.b)
        local panelSide = Color(
            math.max(bg.r - 10, 0),
            math.max(bg.g - 10, 0),
            math.max(bg.b - 10, 0)
        )
        local panelTop = Color(
            math.min(bg.r + 8, 255),
            math.min(bg.g + 8, 255),
            math.min(bg.b + 8, 255)
        )

        local panelHalfD = halfD + 0.1  -- protrude past frame
        local pri = signRight * halfW
        local pup = signUp * halfH
        local pfw = signNormal * panelHalfD
        local p1, p2, p3, p4, p5, p6, p7, p8 = BoxCorners(pos, pri, pup, pfw)
        DrawBox(p1, p2, p3, p4, p5, p6, p7, p8, panelFace, panelSide, panelTop, signNormal, signRight, signUp)

        -- Front face text
        local frontTextPos = pos + signNormal * (panelHalfD + 0.1)
        cam.Start3D2D(frontTextPos, frontAng, scale)
            DrawSignText(signW, signH, tw, th, elapsed, stw, sth, fadeFrac, pulse)
        cam.End3D2D()

        -- Back face text
        local backAng = Angle(0, spinYaw + 90, 90)
        local backTextPos = pos - signNormal * (panelHalfD + 0.1)
        cam.Start3D2D(backTextPos, backAng, scale)
            DrawSignText(signW, signH, tw, th, elapsed, stw, sth, fadeFrac, pulse)
        cam.End3D2D()
    end
end)
