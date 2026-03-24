-- =============================================================================
--  Spawn Protection Enhancements
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  Shared initialization, ConVar sync, net message handling, and
--  cancel-on-fire logic. Enhances the Spawn Protection Workshop addon with
--  XGUI settings, fire-cancellation for HL2/CW 2.0/ACF weapons, and
--  dedicated server ConVar bridging.
-- =============================================================================

-- Shared reference table (accessible from XGUI panel)
SpawnProtEnh = SpawnProtEnh or {}

-- ConVar names must match the original addon exactly (except cancel_on_fire,
-- which is ours)
SpawnProtEnh.CVARS = {
    enable         = "sv_spawnprotection_enable",
    duration       = "sv_spawnprotection_duration",
    notification   = "sv_spawnprotection_notification",
    no_damage      = "sv_spawnprotection_no_damage",
    no_target      = "sv_spawnprotection_no_target",
    bubble         = "sv_spawnprotection_bubble",
    cancel_on_fire = "sv_spawnprotection_cancel_on_fire",
}

-- ConVars that require SuperAdmin (core behavior and timing)
-- Everything else requires Admin (visual and notification settings)
SpawnProtEnh.SUPERADMIN_CVARS = {
    ["sv_spawnprotection_enable"]         = true,
    ["sv_spawnprotection_duration"]       = true,
    ["sv_spawnprotection_no_damage"]      = true,
    ["sv_spawnprotection_no_target"]      = true,
    ["sv_spawnprotection_cancel_on_fire"] = true,
}

-- =============================================================================
-- SERVER
-- =============================================================================
if SERVER then

    util.AddNetworkString("SpawnProtEnh_Sync")
    util.AddNetworkString("SpawnProtEnh_Update")
    util.AddNetworkString("SpawnProtEnh_RequestSync")

    -- Create our own ConVar (the others are created by the workshop addon)
    CreateConVar(
        "sv_spawnprotection_cancel_on_fire", "1",
        bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY),
        "Cancel spawn protection when a protected player fires a weapon",
        0, 1
    )

    -- Rate limiting: per-player timestamps for updates and sync requests
    local lastUpdate = {}
    local lastSyncRequest = {}
    local RATE_LIMIT = 0.5
    local MAX_CVAR_LEN = 64

    -- Quick lookup of valid ConVar names for input validation
    local validCvars = {}
    for _, name in pairs(SpawnProtEnh.CVARS) do
        validCvars[name] = true
    end

    -- =============================================================================
    -- SyncConfig
    -- Reads all tracked ConVars and pushes their values to one player or
    -- broadcasts to everyone. Uses a compact binary format (12 bits total).
    -- =============================================================================
    local function SyncConfig(ply)
        -- Bail if the original addon has not finished creating all its ConVars.
        -- The cvars.AddChangeCallback hooks fire as each ConVar is created, so
        -- early calls will arrive before the full set exists.
        for _, name in pairs(SpawnProtEnh.CVARS) do
            if not GetConVar(name) then return end
        end

        net.Start("SpawnProtEnh_Sync")
            net.WriteBool(GetConVar(SpawnProtEnh.CVARS.enable):GetBool())
            net.WriteUInt(GetConVar(SpawnProtEnh.CVARS.duration):GetInt(), 6)
            net.WriteBool(GetConVar(SpawnProtEnh.CVARS.notification):GetBool())
            net.WriteBool(GetConVar(SpawnProtEnh.CVARS.no_damage):GetBool())
            net.WriteBool(GetConVar(SpawnProtEnh.CVARS.no_target):GetBool())
            net.WriteBool(GetConVar(SpawnProtEnh.CVARS.bubble):GetBool())
            net.WriteBool(GetConVar(SpawnProtEnh.CVARS.cancel_on_fire):GetBool())
        if ply then
            net.Send(ply)
        else
            net.Broadcast()
        end
    end

    -- Sync to each player after they finish loading
    hook.Add("PlayerFullLoad", "SpawnProtEnh_SyncOnJoin", function(ply)
        timer.Simple(1, function()
            if IsValid(ply) then
                SyncConfig(ply)
            end
        end)
    end)

    -- Broadcast updated values whenever any tracked ConVar changes
    for key, cvarName in pairs(SpawnProtEnh.CVARS) do
        cvars.AddChangeCallback(cvarName, function(_, _, _)
            SyncConfig()
        end, "SpawnProtEnh_Sync_" .. key)
    end

    -- =============================================================================
    -- Receive setting changes from the XGUI panel
    -- =============================================================================
    net.Receive("SpawnProtEnh_Update", function(_, ply)
        if not IsValid(ply) then return end

        local now = CurTime()
        if lastUpdate[ply] and (now - lastUpdate[ply]) < RATE_LIMIT then return end
        lastUpdate[ply] = now

        local count = net.ReadUInt(4)
        if count < 1 or count > 7 then return end

        local needsSuperAdmin = false
        local changes = {}

        for i = 1, count do
            local cvarName = net.ReadString()
            local value = net.ReadString()

            if #cvarName > MAX_CVAR_LEN then return end
            if not validCvars[cvarName] then return end

            if SpawnProtEnh.SUPERADMIN_CVARS[cvarName] then
                needsSuperAdmin = true
            end

            changes[i] = {name = cvarName, value = value}
        end

        if needsSuperAdmin and not ply:IsSuperAdmin() then
            ply:ChatPrint("[Spawn Protection] SuperAdmin required for one or more settings.")
            return
        end

        if not ply:IsAdmin() then
            ply:ChatPrint("[Spawn Protection] Admin required to change settings.")
            return
        end

        for _, change in ipairs(changes) do
            RunConsoleCommand(change.name, change.value)
        end
    end)

    -- =============================================================================
    -- Handle client requests for the current config
    -- =============================================================================
    net.Receive("SpawnProtEnh_RequestSync", function(_, ply)
        if not IsValid(ply) then return end

        local now = CurTime()
        if lastSyncRequest[ply] and (now - lastSyncRequest[ply]) < RATE_LIMIT then return end
        lastSyncRequest[ply] = now

        SyncConfig(ply)
    end)

    -- Clean up rate limit entries when players leave
    hook.Add("PlayerDisconnected", "SpawnProtEnh_CleanupRateLimit", function(ply)
        lastUpdate[ply] = nil
        lastSyncRequest[ply] = nil
    end)

    -- =============================================================================
    -- Cancel-on-Fire: remove spawn protection when a protected player attacks
    -- =============================================================================

    -- Resolves the owning player from an entity. Checks Entity:GetOwner()
    -- first, then falls back to CPPI ownership (used by ACF, Wire, etc.).
    local function GetOwningPlayer(ent)
        local owner = ent:GetOwner()
        if IsValid(owner) and owner:IsPlayer() then return owner end

        if ent.CPPIGetOwner then
            owner = ent:CPPIGetOwner()
            if IsValid(owner) and owner:IsPlayer() then return owner end
        end

        return nil
    end

    local function CancelSpawnProtection(ply)
        if ply.spawnProtCancelled then return end
        ply.spawnProtCancelled = true
        ply:SetNoTarget(false)

        if GetConVar("sv_spawnprotection_notification"):GetBool() then
            ply:ChatPrint("Spawn protection cancelled - you fired a weapon!")
        end

        -- Tell clients to remove the protection bubble via the workshop
        -- addon's own net message so the client renderer clears the sphere
        net.Start("SpawnProtectionUpdate")
            net.WriteEntity(ply)
            net.WriteBool(false)
            net.WriteFloat(0)
            net.WriteUInt(0, 8)
        net.Broadcast()
    end

    -- Reset the cancellation flag each time a player spawns, before the
    -- workshop addon applies fresh protection
    hook.Add("PlayerSpawn", "SpawnProtEnh_ResetCancel", function(ply)
        ply.spawnProtCancelled = nil
    end)

    -- -------------------------------------------------------------------------
    -- Detection: EntityFireBullets
    -- Catches HL2 weapons, CW 2.0 weapons, and ACF MG-type weapons that fire
    -- bullets through the standard Garry's Mod bullet system.
    -- -------------------------------------------------------------------------
    hook.Add("EntityFireBullets", "SpawnProtEnh_CancelOnFire", function(ent, data)
        if not GetConVar("sv_spawnprotection_cancel_on_fire"):GetBool() then return end

        local ply
        if ent:IsPlayer() then
            ply = ent
        else
            ply = GetOwningPlayer(ent)
        end

        if IsValid(ply) and ply:IsPlayer() and ply:IsPlayerSpawnProtected() and not ply.spawnProtCancelled then
            CancelSpawnProtection(ply)
        end
    end)

    -- -------------------------------------------------------------------------
    -- Patch: Override Player:IsPlayerSpawnProtected()
    -- The workshop addon's metatable function checks its local
    -- protectedPlayers table. We wrap it so code that calls
    -- IsPlayerSpawnProtected() sees false after cancellation.
    -- -------------------------------------------------------------------------
    hook.Add("InitPostEntity", "SpawnProtEnh_PatchMeta", function()
        timer.Simple(0, function()
            local meta = FindMetaTable("Player")
            local origIsProtected = meta.IsPlayerSpawnProtected

            if origIsProtected then
                meta.IsPlayerSpawnProtected = function(self)
                    if self.spawnProtCancelled then return false end
                    return origIsProtected(self)
                end
            end
        end)
    end)

    -- -------------------------------------------------------------------------
    -- Patch: Replace EntityTakeDamage hook
    -- The workshop addon's "BlockDamageDuringProtection" hook checks its local
    -- protectedPlayers table directly, which we cannot modify. We replace it
    -- with a version that respects our cancellation flag and detects ACF
    -- cannon/shell fire (which bypasses EntityFireBullets).
    -- -------------------------------------------------------------------------
    hook.Add("InitPostEntity", "SpawnProtEnh_PatchDamageHook", function()
        timer.Simple(0, function()
            local cancelCvar = GetConVar("sv_spawnprotection_cancel_on_fire")
            local enableCvar = GetConVar("sv_spawnprotection_enable")
            local noDamageCvar = GetConVar("sv_spawnprotection_no_damage")

            hook.Add("EntityTakeDamage", "BlockDamageDuringProtection", function(target, dmginfo)
                if not enableCvar:GetBool() then return end

                local attacker = dmginfo:GetAttacker()

                -- Cancel-on-fire: trace entity-based attackers (ACF shells,
                -- rockets, etc.) back to their owning player
                if cancelCvar:GetBool() and IsValid(attacker) then
                    local attackerPlayer

                    if attacker:IsPlayer() then
                        attackerPlayer = attacker
                    else
                        attackerPlayer = GetOwningPlayer(attacker)
                    end

                    if IsValid(attackerPlayer) and attackerPlayer:IsPlayerSpawnProtected() and not attackerPlayer.spawnProtCancelled then
                        CancelSpawnProtection(attackerPlayer)
                    end
                end

                -- Block damage TO protected players (unless cancelled)
                if target:IsPlayer() and target:IsPlayerSpawnProtected() and not target.spawnProtCancelled then
                    dmginfo:SetDamage(0)
                    return true
                end

                -- Block damage FROM protected players (if no_damage is on)
                if (target:IsNPC() or target:IsNextBot() or target:IsPlayer())
                    and IsValid(attacker) and attacker:IsPlayer()
                    and attacker:IsPlayerSpawnProtected() and not attacker.spawnProtCancelled
                    and noDamageCvar:GetBool()
                then
                    dmginfo:SetDamage(0)
                    return true
                end
            end)
        end)
    end)

-- =============================================================================
-- CLIENT
-- =============================================================================
else

    -- Config table holds the latest values synced from the server
    SpawnProtEnh.Config = SpawnProtEnh.Config or {}

    -- =============================================================================
    -- CW 2.0 compatibility fix
    -- =============================================================================
    -- CW2's RenderScreenspaceEffects hook assumes that several flashbang-
    -- related properties on the local player are always numbers. CW2
    -- initializes them in its own InitPostEntity hook, but the render hook
    -- can fire before that happens. We set safe defaults here in both
    -- InitPostEntity and a one-shot Think fallback to cover all timing
    -- scenarios.
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

    hook.Add("InitPostEntity", "SpawnProtEnh_CW2Compat", EnsureCW2Defaults)

    hook.Add("Think", "SpawnProtEnh_CW2Compat_Fallback", function()
        if EnsureCW2Defaults() then
            hook.Remove("Think", "SpawnProtEnh_CW2Compat_Fallback")
        end
    end)

    -- =============================================================================
    -- Receive synced config from server and store locally
    -- =============================================================================
    net.Receive("SpawnProtEnh_Sync", function()
        SpawnProtEnh.Config.enable         = net.ReadBool()
        SpawnProtEnh.Config.duration       = net.ReadUInt(6)
        SpawnProtEnh.Config.notification   = net.ReadBool()
        SpawnProtEnh.Config.no_damage      = net.ReadBool()
        SpawnProtEnh.Config.no_target      = net.ReadBool()
        SpawnProtEnh.Config.bubble         = net.ReadBool()
        SpawnProtEnh.Config.cancel_on_fire = net.ReadBool()

        hook.Run("SpawnProtEnh_ConfigUpdated")
    end)

end
-- End of sh_spawnprotection_enhancements.lua
