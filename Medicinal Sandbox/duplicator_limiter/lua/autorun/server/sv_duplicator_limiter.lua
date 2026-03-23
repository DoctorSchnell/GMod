-- =============================================================================
--  Duplicator Limiter — Server Core
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Wraps duplicator.Paste to batch entity creation across multiple server
--  ticks, preventing crashes from large workshop duplications.
--
--  Small pastes (entity count <= batch size) pass through to the original
--  function unmodified.  Large pastes are split into batches with a
--  configurable delay between each.  All entities are frozen during batching
--  to prevent physics from scattering them.  Constraints, PostEntityPaste
--  hooks, and motion restoration happen after all batches complete, then a
--  single undo entry is created for the entire paste.
--
--  KEY DETAIL: Entity positions in dupe data are stored *relative* to the
--  duplicator module's LocalPos/LocalAng variables.  The Duplicator tool
--  sets these before calling Paste and resets them to origin afterward.
--  Deferred batches must restore LocalPos/LocalAng before each batch or
--  entities will spawn at the map origin.
-- =============================================================================

-- Per-player state
local lastPaste = {}    -- SteamID -> CurTime of last paste
local pasteJobs = {}    -- SteamID -> active job table

-- =============================================================================
-- CAPTURE DUPLICATOR COORDINATE CONTEXT
-- =============================================================================
-- The duplicator module stores LocalPos/LocalAng as locals that are set via
-- SetLocalPos/SetLocalAng.  The Duplicator tool sets these to the paste hit
-- position before calling Paste, then resets them to origin afterward.
-- We intercept the setters to capture the current values so deferred batches
-- can restore them.

local lastLocalPos = Vector(0, 0, 0)
local lastLocalAng = Angle(0, 0, 0)

local origSetLocalPos = duplicator.SetLocalPos
local origSetLocalAng = duplicator.SetLocalAng

function duplicator.SetLocalPos(v)
    lastLocalPos = Vector(v)   -- snapshot (copy)
    origSetLocalPos(v)
end

function duplicator.SetLocalAng(v)
    lastLocalAng = Angle(v)    -- snapshot (copy)
    origSetLocalAng(v)
end

-- =============================================================================
-- NET MESSAGE — XGUI config changes
-- =============================================================================

util.AddNetworkString("DupLimiter_ConfigUpdate")

local ALLOWED_CVARS = {
    ["duplimiter_enabled"]      = true,
    ["duplimiter_batch_size"]   = true,
    ["duplimiter_delay"]        = true,
    ["duplimiter_max_entities"] = true,
    ["duplimiter_cooldown"]     = true,
    ["duplimiter_admin_bypass"] = true,
}

local MAX_VALUE_LEN  = 16
local configCooldown = {}  -- SteamID -> last config-change time

net.Receive("DupLimiter_ConfigUpdate", function(_, ply)
    if not IsValid(ply) then return end
    if not ply:IsSuperAdmin() then return end

    -- Rate-limit config changes
    local sid = ply:SteamID()
    local now = CurTime()
    if configCooldown[sid] and (now - configCooldown[sid]) < 0.5 then return end
    configCooldown[sid] = now

    local cvar  = net.ReadString()
    local value = net.ReadString()

    if not ALLOWED_CVARS[cvar] then return end
    if #cvar > 64 or #value > MAX_VALUE_LEN then return end

    RunConsoleCommand(cvar, value)
end)

-- =============================================================================
-- HELPERS
-- =============================================================================

local function Notify(ply, msg)
    if not IsValid(ply) then return end
    ply:ChatPrint("[Duplicator Limiter] " .. msg)
end

--- Finalize a completed paste job: entity modifiers, PostEntityPaste,
--- constraints, motion restore, and undo.
local function FinalizeJob(sid)
    local job = pasteJobs[sid]
    if not job then return end

    -- Apply entity & bone modifiers, then PostEntityPaste
    -- (mirrors the second loop in the original duplicator.Paste)
    for _, ent in pairs(job.CreatedEntities) do
        if IsValid(ent) then
            pcall(duplicator.ApplyEntityModifiers, job.Player, ent)
            pcall(duplicator.ApplyBoneModifiers, job.Player, ent)

            if ent.PostEntityPaste then
                local ok, err = pcall(ent.PostEntityPaste, ent,
                    job.Player or NULL, ent, job.CreatedEntities)
                if not ok then
                    ErrorNoHalt("[DupLimiter] PostEntityPaste error: " .. tostring(err) .. "\n")
                end
            end
        end
    end

    -- Constraints (must run after all entities exist)
    local CreatedConstraints = {}
    if job.ConstraintList then
        for k, v in pairs(job.ConstraintList) do
            local ok, c = pcall(duplicator.CreateConstraintFromTable,
                v, job.CreatedEntities, job.Player)
            if ok and IsValid(c) then
                CreatedConstraints[k] = c
            end
        end
    end

    -- Restore motion on entities that were unfrozen before we froze them
    for k, _ in pairs(job.WasUnfrozen) do
        local ent = job.CreatedEntities[k]
        if IsValid(ent) then
            local phys = ent:GetPhysicsObject()
            if IsValid(phys) then
                phys:EnableMotion(true)
            end
        end
    end

    -- Single undo entry for the entire paste
    if IsValid(job.Player) then
        undo.Create("Duplicator")
            for _, ent in pairs(job.CreatedEntities) do
                if IsValid(ent) then undo.AddEntity(ent) end
            end
            for _, c in pairs(CreatedConstraints) do
                if IsValid(c) then undo.AddEntity(c) end
            end
            undo.SetPlayer(job.Player)
        undo.Finish()

        local count = table.Count(job.CreatedEntities)
        Notify(job.Player, "Paste complete! (" .. count .. " entities)")
    end

    pasteJobs[sid] = nil
end

--- Process the next batch for a queued paste job.
local function ProcessNextBatch(sid)
    local job = pasteJobs[sid]
    if not job then return end

    -- Player left mid-paste
    if not IsValid(job.Player) then
        pasteJobs[sid] = nil
        return
    end

    job.BatchIndex = job.BatchIndex + 1
    local batch = job.Batches[job.BatchIndex]

    -- All batches done → finalize
    if not batch then
        FinalizeJob(sid)
        return
    end

    -- -----------------------------------------------------------------
    -- Restore the duplicator coordinate context for this batch.
    -- CreateEntityFromTable converts relative positions via LocalToWorld
    -- using the module's LocalPos/LocalAng.  The Duplicator tool resets
    -- these to origin after Paste returns, so deferred batches must
    -- restore them or entities will spawn at (0,0,0).
    -- -----------------------------------------------------------------
    duplicator.SetLocalPos(job.PastePos)
    duplicator.SetLocalAng(job.PasteAng)

    -- Spawn this batch (pcall-protected so one bad entity can't break
    -- the timer chain and stall the entire paste)
    for k, v in pairs(batch) do
        local ok, ent = pcall(duplicator.CreateEntityFromTable, job.Player, v)
        if ok and IsValid(ent) then
            ent:SetCreator(job.Player)

            -- Replicate the per-entity work that duplicator.Paste does
            -- after CreateEntityFromTable returns
            if ent.RestoreNetworkVars then
                pcall(ent.RestoreNetworkVars, ent, v.DT)
            end
            if ent.OnDuplicated then
                pcall(ent.OnDuplicated, ent, v)
            end

            ent.BoneMods        = v.BoneMods and table.Copy(v.BoneMods)
            ent.EntityMods      = v.EntityMods and table.Copy(v.EntityMods)
            ent.PhysicsObjects  = v.PhysicsObjects and table.Copy(v.PhysicsObjects)

            job.CreatedEntities[k] = ent

            -- Freeze unfrozen entities so they don't fall/scatter while
            -- remaining batches are still being spawned, and register
            -- all frozen physics with the player so double-tap R works.
            -- (The original Paste sets ActionPlayer for this, but we
            -- call CreateEntityFromTable directly so it stays nil.)
            local phys = ent:GetPhysicsObject()
            if IsValid(phys) then
                if phys:IsMotionEnabled() then
                    phys:EnableMotion(false)
                    job.WasUnfrozen[k] = true
                end
                job.Player:AddFrozenPhysicsObject(ent, phys)
            end
        elseif not ok then
            ErrorNoHalt("[DupLimiter] CreateEntityFromTable error: " .. tostring(ent) .. "\n")
        end
    end

    -- Reset coordinate context to origin so other operations aren't affected
    duplicator.SetLocalPos(Vector(0, 0, 0))
    duplicator.SetLocalAng(Angle(0, 0, 0))

    -- Schedule next batch (always runs, even if some entities errored)
    timer.Create("DupLimiter_" .. sid, DupLimiter.Config.Delay, 1, function()
        ProcessNextBatch(sid)
    end)
end

-- =============================================================================
-- FPP ANTI-SPAM BYPASS
-- =============================================================================
-- FPP's anti-spam ghosts or removes entities spawned too quickly.  During a
-- batched paste our addon already rate-limits via batch size, cooldown, and
-- entity cap, so FPP's per-entity anti-spam is redundant and would break the
-- paste.  Returning false from this hook tells FPP to skip anti-spam checks
-- for entities created by an active batched paste.

hook.Add("FPP_ShouldRegisterAntiSpam", "DupLimiter_BypassFPP", function(ply, ent, IsDuplicate)
    if not IsValid(ply) then return end
    local sid = ply:SteamID()
    if pasteJobs[sid] then
        return false
    end
end)

-- =============================================================================
-- CLEANUP
-- =============================================================================

hook.Add("PlayerDisconnected", "DupLimiter_Cleanup", function(ply)
    local sid = ply:SteamID()
    lastPaste[sid]      = nil
    pasteJobs[sid]      = nil
    configCooldown[sid] = nil
    timer.Remove("DupLimiter_" .. sid)
end)

-- =============================================================================
-- WRAP duplicator.Paste
-- =============================================================================

local OriginalPaste = duplicator.Paste

function duplicator.Paste(Player, EntityList, ConstraintList)
    -- Disabled or non-player → pass through
    if not DupLimiter or not DupLimiter.Config or not DupLimiter.Config.Enabled then
        return OriginalPaste(Player, EntityList, ConstraintList)
    end
    if not IsValid(Player) or not Player:IsPlayer() then
        return OriginalPaste(Player, EntityList, ConstraintList)
    end

    -- Admin bypass
    if DupLimiter.Config.AdminBypass and Player:IsAdmin() then
        return OriginalPaste(Player, EntityList, ConstraintList)
    end

    local sid         = Player:SteamID()
    local now         = CurTime()
    local entityCount = table.Count(EntityList)

    -- Already pasting?
    if pasteJobs[sid] then
        Notify(Player, "Please wait for your current paste to finish.")
        return {}, {}
    end

    -- Cooldown
    local cooldown = DupLimiter.Config.Cooldown
    if cooldown > 0 and lastPaste[sid] then
        local elapsed = now - lastPaste[sid]
        if elapsed < cooldown then
            Notify(Player, "Please wait " .. math.ceil(cooldown - elapsed) ..
                "s before pasting again.")
            return {}, {}
        end
    end

    -- Entity cap
    local maxEnts = DupLimiter.Config.MaxEntities
    if maxEnts > 0 and entityCount > maxEnts then
        Notify(Player, "Paste denied: " .. entityCount ..
            " entities exceeds the limit of " .. maxEnts .. ".")
        return {}, {}
    end

    lastPaste[sid] = now

    local batchSize = DupLimiter.Config.BatchSize

    -- Small paste → run original directly (full compatibility)
    if entityCount <= batchSize then
        return OriginalPaste(Player, EntityList, ConstraintList)
    end

    -- -----------------------------------------------------------------
    -- Large paste → split into batches
    -- -----------------------------------------------------------------

    -- Capture the duplicator coordinate context.  The tool will reset
    -- LocalPos/LocalAng to origin after we return, so we need to save
    -- them now and restore them before each deferred batch.
    local pastePos = Vector(lastLocalPos)
    local pasteAng = Angle(lastLocalAng)

    local batches = {}
    local current = {}
    local n       = 0

    -- Deep-copy each entity data table so CreateEntityFromTable's
    -- in-place Pos/Angle conversion doesn't affect other batches.
    for k, v in pairs(EntityList) do
        current[k] = table.Copy(v)
        n = n + 1
        if n >= batchSize then
            batches[#batches + 1] = current
            current = {}
            n = 0
        end
    end
    if next(current) then
        batches[#batches + 1] = current
    end

    Notify(Player, "Pasting " .. entityCount .. " entities in " ..
        #batches .. " batches...")

    pasteJobs[sid] = {
        Player          = Player,
        Batches         = batches,
        BatchIndex      = 0,
        CreatedEntities = {},
        WasUnfrozen     = {},
        ConstraintList  = ConstraintList and table.Copy(ConstraintList) or {},
        PastePos        = pastePos,
        PasteAng        = pasteAng,
    }

    -- Kick off — batch 1 runs synchronously on this tick
    ProcessNextBatch(sid)

    -- Return empty tables so the Duplicator tool's own undo is a no-op.
    -- Our FinalizeJob creates the real undo covering all entities.
    return {}, {}
end
