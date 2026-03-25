-- =============================================================================
--  Spawn Protection ULX Patch
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Shared initialization, ConVar sync, and net message handling.
--  The original Workshop addon creates its ConVars server-side only, which
--  breaks the spawnmenu settings panel on dedicated servers. This file bridges
--  the gap by syncing ConVar values to clients via net messages, and receives
--  setting changes from the XGUI panel with tiered permission checks.
-- =============================================================================

-- Shared reference table (accessible from ULX commands and XGUI panel)
SpawnProtULX = SpawnProtULX or {}

-- ConVar names must match the original addon exactly
SpawnProtULX.CVARS = {
    enable       = "sv_spawnprotection_enable",
    duration     = "sv_spawnprotection_duration",
    notification = "sv_spawnprotection_notification",
    no_damage    = "sv_spawnprotection_no_damage",
    no_target    = "sv_spawnprotection_no_target",
    bubble       = "sv_spawnprotection_bubble",
}

-- ConVars that require SuperAdmin (core behavior and timing)
-- Everything else requires Admin (visual and notification settings)
SpawnProtULX.SUPERADMIN_CVARS = {
    ["sv_spawnprotection_enable"]    = true,
    ["sv_spawnprotection_duration"]  = true,
    ["sv_spawnprotection_no_damage"] = true,
    ["sv_spawnprotection_no_target"] = true,
}

-- =============================================================================
-- SERVER
-- =============================================================================
if SERVER then

    util.AddNetworkString("SpawnProtULX_Sync")
    util.AddNetworkString("SpawnProtULX_Update")
    util.AddNetworkString("SpawnProtULX_RequestSync")

    -- Rate limiting: per-player timestamps for updates and sync requests
    local lastUpdate = {}
    local lastSyncRequest = {}
    local RATE_LIMIT = 0.5
    local MAX_CVAR_LEN = 64

    -- Quick lookup of valid ConVar names for input validation
    local validCvars = {}
    for _, name in pairs(SpawnProtULX.CVARS) do
        validCvars[name] = true
    end

    -- =============================================================================
    -- SyncConfig
    -- Reads all tracked ConVars and pushes their values to one player or
    -- broadcasts to everyone. Uses a compact binary format (11 bits total).
    -- =============================================================================
    local function SyncConfig(ply)
        -- Bail if the original addon has not finished creating all its ConVars.
        -- The cvars.AddChangeCallback hooks fire as each ConVar is created, so
        -- early calls will arrive before the full set exists.
        for _, name in pairs(SpawnProtULX.CVARS) do
            if not GetConVar(name) then return end
        end

        net.Start("SpawnProtULX_Sync")
            net.WriteBool(GetConVar(SpawnProtULX.CVARS.enable):GetBool())
            net.WriteUInt(GetConVar(SpawnProtULX.CVARS.duration):GetInt(), 6)
            net.WriteBool(GetConVar(SpawnProtULX.CVARS.notification):GetBool())
            net.WriteBool(GetConVar(SpawnProtULX.CVARS.no_damage):GetBool())
            net.WriteBool(GetConVar(SpawnProtULX.CVARS.no_target):GetBool())
            net.WriteBool(GetConVar(SpawnProtULX.CVARS.bubble):GetBool())
        if ply then
            net.Send(ply)
        else
            net.Broadcast()
        end
    end

    -- Sync to each player after they finish loading
    -- Short delay ensures the original addon's ConVars are initialized
    hook.Add("PlayerFullLoad", "SpawnProtULX_SyncOnJoin", function(ply)
        timer.Simple(1, function()
            if IsValid(ply) then
                SyncConfig(ply)
            end
        end)
    end)

    -- Broadcast updated values whenever any tracked ConVar changes
    for key, cvarName in pairs(SpawnProtULX.CVARS) do
        cvars.AddChangeCallback(cvarName, function(_, _, _)
            SyncConfig()
        end, "SpawnProtULX_Sync_" .. key)
    end

    -- =============================================================================
    -- Receive setting changes from the XGUI panel
    -- All changes are bundled into a single net message to avoid rate limit
    -- issues. The message contains a count byte followed by name/value pairs.
    -- Validates each ConVar name and enforces tiered permissions.
    -- =============================================================================
    net.Receive("SpawnProtULX_Update", function(_, ply)
        if not IsValid(ply) then return end

        -- Rate limit (per-player, per-batch)
        local now = CurTime()
        if lastUpdate[ply] and (now - lastUpdate[ply]) < RATE_LIMIT then return end
        lastUpdate[ply] = now

        -- Read the number of changes in this batch (capped at 6)
        local count = net.ReadUInt(4)
        if count < 1 or count > 6 then return end

        -- Track the highest permission level needed for this batch so we
        -- can reject the whole thing early if the player lacks access
        local needsSuperAdmin = false
        local changes = {}

        for i = 1, count do
            local cvarName = net.ReadString()
            local value = net.ReadString()

            -- Validate ConVar name
            if #cvarName > MAX_CVAR_LEN then return end
            if not validCvars[cvarName] then return end

            if SpawnProtULX.SUPERADMIN_CVARS[cvarName] then
                needsSuperAdmin = true
            end

            changes[i] = {name = cvarName, value = value}
        end

        -- Permission check for the batch
        if needsSuperAdmin and not ply:IsSuperAdmin() then
            ply:ChatPrint("[Spawn Protection] SuperAdmin required for one or more settings.")
            return
        end

        if not ply:IsAdmin() then
            ply:ChatPrint("[Spawn Protection] Admin required to change settings.")
            return
        end

        -- Apply all changes
        for _, change in ipairs(changes) do
            RunConsoleCommand(change.name, change.value)
        end
    end)

    -- =============================================================================
    -- Handle client requests for the current config (pull on XGUI tab open)
    -- =============================================================================
    net.Receive("SpawnProtULX_RequestSync", function(_, ply)
        if not IsValid(ply) then return end

        -- Rate limit sync requests
        local now = CurTime()
        if lastSyncRequest[ply] and (now - lastSyncRequest[ply]) < RATE_LIMIT then return end
        lastSyncRequest[ply] = now

        SyncConfig(ply)
    end)

    -- Clean up rate limit entries when players leave
    hook.Add("PlayerDisconnected", "SpawnProtULX_CleanupRateLimit", function(ply)
        lastUpdate[ply] = nil
        lastSyncRequest[ply] = nil
    end)

-- =============================================================================
-- CLIENT
-- =============================================================================
else

    -- Config table holds the latest values synced from the server
    SpawnProtULX.Config = SpawnProtULX.Config or {}

    -- =============================================================================
    -- CW 2.0 compatibility fix
    -- =============================================================================
    -- CW2's RenderScreenspaceEffects hook (cl_hooks.lua:55) assumes that
    -- several flashbang-related properties on the local player are always
    -- numbers. CW2 initializes them in its own InitPostEntity hook, but
    -- the render hook can fire before that happens. The spawn protection
    -- addon shifts load timing just enough to expose this race condition,
    -- causing a nil-vs-number comparison spam. We set safe defaults here
    -- in both InitPostEntity and a one-shot Think fallback to cover all
    -- timing scenarios.
    -- =============================================================================
    local cw2Defaults = {
        cwFlashbangDuration         = 0,
        cwFlashbangIntensity        = 0,
        cwFlashbangDisplayIntensity = 0,
        cwFlashDuration             = 0,
        cwFlashIntensity            = 0,
    }

    local function EnsureCW2Defaults()
        local ply = LocalPlayer()
        if not IsValid(ply) then return false end

        for key, default in pairs(cw2Defaults) do
            if ply[key] == nil then
                ply[key] = default
            end
        end

        return true
    end

    -- Primary path: InitPostEntity fires once after all entities are ready
    hook.Add("InitPostEntity", "SpawnProtULX_CW2Compat", EnsureCW2Defaults)

    -- Fallback: one-shot Think hook in case the render hook wins the race
    hook.Add("Think", "SpawnProtULX_CW2Compat_Fallback", function()
        if EnsureCW2Defaults() then
            hook.Remove("Think", "SpawnProtULX_CW2Compat_Fallback")
        end
    end)

    -- =============================================================================
    -- Receive synced config from server and store locally
    -- =============================================================================
    net.Receive("SpawnProtULX_Sync", function()
        SpawnProtULX.Config.enable       = net.ReadBool()
        SpawnProtULX.Config.duration     = net.ReadUInt(6)
        SpawnProtULX.Config.notification = net.ReadBool()
        SpawnProtULX.Config.no_damage    = net.ReadBool()
        SpawnProtULX.Config.no_target    = net.ReadBool()
        SpawnProtULX.Config.bubble       = net.ReadBool()

        -- Fire a hook so the XGUI panel can refresh if it is open
        hook.Run("SpawnProtULX_ConfigUpdated")
    end)

end
-- End of sh_spawnprotection_ulx.lua
