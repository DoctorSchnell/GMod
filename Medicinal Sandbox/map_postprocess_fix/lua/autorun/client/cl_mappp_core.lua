-- Map Post-Process Fix - Client Core
-- Addon by Doctor Schnell
--
-- Listens for config pushes from the server and applies post-processing
-- overrides. The three controllable settings are:
--
--   Tonemap Scale  - HDR brightness. Controlled via render.SetToneMappingScaleLinear()
--                    in a per-frame render hook. This bypasses the cheat-protected
--                    mat_force_tonemap_scale ConVar entirely, and also prevents the
--                    map's env_tonemap_controller from reasserting its own values.
--
--   Bloom Scale    - Engine bloom intensity via mat_bloomscale. 0 disables,
--                    1.0 is the default. Not cheat-protected.
--
--   Specular       - Specular reflections on world surfaces via mat_specular.
--                    0 disables, 1 enables. Not cheat-protected.
--
-- A sentinel value of -1 from the server means "don't touch this
-- setting," leaving it at whatever the client or engine has set.
--
-- Bloom and specular are enforced via a periodic timer every 2 seconds
-- to catch other addons (e.g. FPS Booster) overwriting them. Tonemap
-- doesn't need a timer because the render hook runs every frame.

local TAG = "[MapPP]"

-- Stores the last config the server sent us. nil means no config
-- for the current map (restore defaults).
local activeConfig = nil

-- Tracks whether we have received any sync response from the server
-- this session. Used by the retry fallback to avoid waiting forever
-- if InitPostEntity didn't fire or the message got lost.
local receivedSync = false

-- Whether we should be actively overriding right now. This combines
-- the master toggle and whether we have a config, so the render hook
-- can bail out with a single boolean check per frame.
local enforcing = false

-- Cached ConVar objects for bloom and specular. Tonemap no longer
-- uses a ConVar at all.
local cv_bloom    = GetConVar("mat_bloomscale")
local cv_specular = GetConVar("mat_specular")
local cv_enabled  = GetConVar("mappp_enabled")

-- ============================================================
-- Tonemap override (per-frame render hook)
-- ============================================================

-- This hook fires every frame during the render pass. When active,
-- it forces the tonemapping scale to our configured value, which
-- prevents both the map's env_tonemap_controller and any other
-- addon from changing it. The cost is one function call per frame,
-- which is negligible.
hook.Add("RenderScreenspaceEffects", "MapPP_TonemapOverride", function()
    if not enforcing then return end
    if not activeConfig then return end

    local scale = activeConfig.tonemap_scale

    -- Only override if the config specifies a tonemap value (not -1).
    if not scale or scale < 0 then return end

    -- SetToneMappingScaleLinear takes a Vector where all three
    -- components are typically the same value. This directly controls
    -- the HDR tonemapping without needing sv_cheats.
    render.SetToneMappingScaleLinear(Vector(scale, scale, scale))
end)

-- ============================================================
-- Bloom and specular override (ConVar-based)
-- ============================================================

-- Applies bloom and specular overrides via their ConVars. These two
-- are not cheat-protected, so RunConsoleCommand works fine.
local function ApplyConVarOverrides(config)
    if config.bloom_scale and config.bloom_scale >= 0 then
        RunConsoleCommand("mat_bloomscale", tostring(config.bloom_scale))
    end

    if config.mat_specular and config.mat_specular >= 0 then
        RunConsoleCommand("mat_specular", tostring(math.Round(config.mat_specular)))
    end
end

-- Resets bloom and specular to engine defaults. Tonemap resets
-- automatically when the render hook stops running (the engine's
-- auto-exposure takes back over).
local function RestoreDefaults()
    RunConsoleCommand("mat_bloomscale", "1")
    RunConsoleCommand("mat_specular", "1")

    print(TAG .. " Restored default post-processing")
end

-- Master state refresh. Called when the config changes or the
-- enabled toggle flips. Sets the enforcing flag that the render
-- hook checks, and applies or restores the ConVar-based settings.
local function RefreshState()
    local enabled = cv_enabled:GetBool()

    if enabled and activeConfig then
        enforcing = true
        ApplyConVarOverrides(activeConfig)
        print(TAG .. " Applied overrides for " .. game.GetMap())
    else
        enforcing = false
        RestoreDefaults()
    end
end

-- ============================================================
-- Continuous enforcement for bloom and specular
-- ============================================================

-- Compares a ConVar's current value against the expected override.
-- Returns true if the ConVar has drifted and needs correction.
local function HasDrifted(cvar, expected)
    return math.abs(cvar:GetFloat() - expected) > 0.001
end

-- Runs every 2 seconds to catch other addons overwriting bloom or
-- specular. Tonemap is handled per-frame by the render hook so it
-- doesn't need checking here.
local function EnforceConVars()
    if not enforcing then return end
    if not activeConfig then return end

    local config = activeConfig

    if config.bloom_scale and config.bloom_scale >= 0 then
        if HasDrifted(cv_bloom, config.bloom_scale) then
            RunConsoleCommand("mat_bloomscale", tostring(config.bloom_scale))
            print(TAG .. " Re-enforced bloomscale (was overridden)")
        end
    end

    if config.mat_specular and config.mat_specular >= 0 then
        local expected = math.Round(config.mat_specular)
        if HasDrifted(cv_specular, expected) then
            RunConsoleCommand("mat_specular", tostring(expected))
            print(TAG .. " Re-enforced mat_specular (was overridden)")
        end
    end
end

-- 2 seconds is frequent enough to catch FPS Booster and similar
-- addons that set values on spawn or toggle.
timer.Create("MapPP_Enforce", 2, 0, EnforceConVars)

-- ============================================================
-- Receiving config from the server
-- ============================================================

net.Receive("MapPP_SyncConfig", function()
    receivedSync = true

    local hasConfig = net.ReadBool()

    if hasConfig then
        activeConfig = {
            tonemap_scale = net.ReadFloat(),
            bloom_scale   = net.ReadFloat(),
            mat_specular  = net.ReadFloat()
        }
    else
        activeConfig = nil
    end

    RefreshState()
end)

-- ============================================================
-- Requesting config from the server
-- ============================================================

-- InitPostEntity fires after the client is fully loaded into the map,
-- meaning our net.Receive handler above is guaranteed to be registered.
-- The server's original push may arrive before this point (and get
-- silently dropped), so the client asks explicitly here.
--
-- A retry timer fires after 5 seconds as a fallback in case
-- InitPostEntity didn't fire (known GMod issue on map change) or
-- the initial message was lost. The server also pushes via
-- PlayerFullLoad as a belt-and-suspenders measure.
hook.Add("InitPostEntity", "MapPP_RequestConfig", function()
    receivedSync = false

    net.Start("MapPP_ClientReady")
    net.SendToServer()

    timer.Create("MapPP_SyncRetry", 5, 1, function()
        if not receivedSync then
            net.Start("MapPP_ClientReady")
            net.SendToServer()
        end
    end)
end)

-- ============================================================
-- Reacting to the master toggle
-- ============================================================

-- If an admin flips the enabled ConVar while players are on the map,
-- pick up the change immediately instead of waiting for a rejoin.
cvars.AddChangeCallback("mappp_enabled", function(name, oldVal, newVal)
    RefreshState()
end, "MapPP_EnableToggle")
