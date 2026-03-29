-- =============================================================================
--  Persistent Punishments - Database Layer
--  Author: Doctor Schnell & Claude (Anthropic)
--
--  SQLite storage via GMod's built-in sql.* library (sv.db).
--  One row per active punishment per player, keyed by auto-increment ID.
-- =============================================================================

local TABLE_NAME = "persistent_punishments"

-- =============================================================================
-- SCHEMA
-- =============================================================================

function PPunish.InitDatabase()
    local query = string.format([[
        CREATE TABLE IF NOT EXISTS %s (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            steamid64 TEXT NOT NULL,
            player_name TEXT NOT NULL DEFAULT 'Unknown',
            punishment_type TEXT NOT NULL,
            reason TEXT NOT NULL DEFAULT '',
            admin_steamid64 TEXT NOT NULL,
            admin_name TEXT NOT NULL DEFAULT 'Console',
            applied_at INTEGER NOT NULL,
            expires_at INTEGER NOT NULL,
            jail_pos_x REAL DEFAULT NULL,
            jail_pos_y REAL DEFAULT NULL,
            jail_pos_z REAL DEFAULT NULL,
            active INTEGER NOT NULL DEFAULT 1
        )
    ]], TABLE_NAME)

    local result = sql.Query(query)
    if result == false then
        ServerLog("[Persistent Punishments] ERROR: Failed to create table: " .. (sql.LastError() or "unknown") .. "\n")
        return
    end

    -- Index for fast lookups by player + active status
    sql.Query(string.format(
        "CREATE INDEX IF NOT EXISTS idx_pp_active ON %s (steamid64, active)",
        TABLE_NAME
    ))

    ServerLog("[Persistent Punishments] Database table initialized.\n")
end

PPunish.InitDatabase()

-- =============================================================================
-- CRUD OPERATIONS
-- =============================================================================

--- Add a new persistent punishment to the database.
-- @param steamid64 string
-- @param playerName string
-- @param punishType string - "gag", "mute", "freeze", "jail"
-- @param reason string
-- @param adminSteamid64 string
-- @param adminName string
-- @param minutes number - 0 = permanent
-- @param jailPos Vector or nil - only for jail type
-- @return number|nil - the row ID of the inserted record, or nil on failure
function PPunish.AddPunishment(steamid64, playerName, punishType, reason, adminSteamid64, adminName, minutes, jailPos)
    local now = os.time()
    local expiresAt = 0
    if minutes > 0 then
        expiresAt = now + (minutes * 60)
    end

    local jailX, jailY, jailZ = "NULL", "NULL", "NULL"
    if jailPos then
        jailX = tostring(jailPos.x)
        jailY = tostring(jailPos.y)
        jailZ = tostring(jailPos.z)
    end

    local query = string.format(
        "INSERT INTO %s (steamid64, player_name, punishment_type, reason, admin_steamid64, admin_name, applied_at, expires_at, jail_pos_x, jail_pos_y, jail_pos_z, active) VALUES (%s, %s, %s, %s, %s, %s, %d, %d, %s, %s, %s, 1)",
        TABLE_NAME,
        sql.SQLStr(steamid64),
        sql.SQLStr(playerName),
        sql.SQLStr(punishType),
        sql.SQLStr(reason),
        sql.SQLStr(adminSteamid64),
        sql.SQLStr(adminName),
        now,
        expiresAt,
        jailX, jailY, jailZ
    )

    local result = sql.Query(query)
    if result == false then
        ServerLog("[Persistent Punishments] ERROR: Failed to insert punishment: " .. (sql.LastError() or "unknown") .. "\n")
        return nil
    end

    -- Retrieve the last inserted row ID
    local idResult = sql.QueryValue("SELECT last_insert_rowid()")
    return tonumber(idResult)
end

--- Deactivate a punishment by its ID (soft delete).
-- @param id number
function PPunish.RemovePunishment(id)
    sql.Query(string.format(
        "UPDATE %s SET active = 0 WHERE id = %d",
        TABLE_NAME, id
    ))
end

--- Deactivate all punishments of a specific type for a player.
-- @param steamid64 string
-- @param punishType string
function PPunish.RemovePunishmentByType(steamid64, punishType)
    sql.Query(string.format(
        "UPDATE %s SET active = 0 WHERE steamid64 = %s AND punishment_type = %s AND active = 1",
        TABLE_NAME, sql.SQLStr(steamid64), sql.SQLStr(punishType)
    ))
end

--- Get all active punishments for a player (excludes expired).
-- @param steamid64 string
-- @return table - array of punishment records, or empty table
function PPunish.GetActivePunishments(steamid64)
    local now = os.time()
    local query = string.format(
        "SELECT * FROM %s WHERE steamid64 = %s AND active = 1 AND (expires_at = 0 OR expires_at > %d)",
        TABLE_NAME, sql.SQLStr(steamid64), now
    )

    local result = sql.Query(query)
    if not result then return {} end

    local punishments = {}
    for _, row in ipairs(result) do
        table.insert(punishments, {
            id              = tonumber(row.id),
            steamid64       = row.steamid64,
            player_name     = row.player_name,
            punishment_type = row.punishment_type,
            reason          = row.reason,
            admin_steamid64 = row.admin_steamid64,
            admin_name      = row.admin_name,
            applied_at      = tonumber(row.applied_at) or 0,
            expires_at      = tonumber(row.expires_at) or 0,
            jail_pos_x      = tonumber(row.jail_pos_x),
            jail_pos_y      = tonumber(row.jail_pos_y),
            jail_pos_z      = tonumber(row.jail_pos_z),
        })
    end

    return punishments
end

--- Get all active punishments across all players (for XGUI panel).
-- @return table - array of punishment records
function PPunish.GetAllActivePunishments()
    local now = os.time()
    local query = string.format(
        "SELECT * FROM %s WHERE active = 1 AND (expires_at = 0 OR expires_at > %d) ORDER BY applied_at DESC",
        TABLE_NAME, now
    )

    local result = sql.Query(query)
    if not result then return {} end

    local punishments = {}
    for _, row in ipairs(result) do
        table.insert(punishments, {
            id              = tonumber(row.id),
            steamid64       = row.steamid64,
            player_name     = row.player_name,
            punishment_type = row.punishment_type,
            reason          = row.reason,
            admin_steamid64 = row.admin_steamid64,
            admin_name      = row.admin_name,
            applied_at      = tonumber(row.applied_at) or 0,
            expires_at      = tonumber(row.expires_at) or 0,
        })
    end

    return punishments
end

--- Expire all overdue punishments (mark as inactive).
-- @return number - count of expired records
function PPunish.ExpireOverdue()
    local now = os.time()
    sql.Query(string.format(
        "UPDATE %s SET active = 0 WHERE expires_at > 0 AND expires_at <= %d AND active = 1",
        TABLE_NAME, now
    ))

    -- sql.Query returns nil on success for UPDATE, false on error
    -- Use changes count to report
    local changes = sql.QueryValue("SELECT changes()")
    return tonumber(changes) or 0
end

--- Update an existing punishment's duration and/or reason.
-- @param id number - the punishment row ID
-- @param newMinutes number - new duration in minutes (0 = permanent). Pass -1 to keep existing.
-- @param newReason string - new reason. Pass nil or "" to keep existing.
-- @return boolean - true if updated
function PPunish.UpdatePunishment(id, newMinutes, newReason)
    -- Fetch the existing record to get applied_at for recalculating expires_at
    local query = string.format(
        "SELECT applied_at, reason, expires_at FROM %s WHERE id = %d AND active = 1",
        TABLE_NAME, id
    )
    local result = sql.Query(query)
    if not result or #result == 0 then return false end

    local row = result[1]
    local setClauses = {}

    if newMinutes >= 0 then
        local newExpiresAt = 0
        if newMinutes > 0 then
            newExpiresAt = os.time() + (newMinutes * 60)
        end
        table.insert(setClauses, string.format("expires_at = %d", newExpiresAt))
    end

    if newReason and newReason ~= "" then
        table.insert(setClauses, string.format("reason = %s", sql.SQLStr(newReason)))
    end

    if #setClauses == 0 then return false end

    local updateQuery = string.format(
        "UPDATE %s SET %s WHERE id = %d AND active = 1",
        TABLE_NAME, table.concat(setClauses, ", "), id
    )

    local updateResult = sql.Query(updateQuery)
    if updateResult == false then
        ServerLog("[Persistent Punishments] ERROR: Failed to update punishment #" .. id .. ": " .. (sql.LastError() or "unknown") .. "\n")
        return false
    end

    return true
end

--- Get a single punishment by ID.
-- @param id number
-- @return table or nil
function PPunish.GetPunishmentByID(id)
    local query = string.format(
        "SELECT * FROM %s WHERE id = %d",
        TABLE_NAME, id
    )
    local result = sql.Query(query)
    if not result or #result == 0 then return nil end

    local row = result[1]
    return {
        id              = tonumber(row.id),
        steamid64       = row.steamid64,
        player_name     = row.player_name,
        punishment_type = row.punishment_type,
        reason          = row.reason,
        admin_steamid64 = row.admin_steamid64,
        admin_name      = row.admin_name,
        applied_at      = tonumber(row.applied_at) or 0,
        expires_at      = tonumber(row.expires_at) or 0,
        jail_pos_x      = tonumber(row.jail_pos_x),
        jail_pos_y      = tonumber(row.jail_pos_y),
        jail_pos_z      = tonumber(row.jail_pos_z),
        active          = tonumber(row.active) or 0,
    }
end

--- Check if a player has an active punishment of a specific type.
-- @param steamid64 string
-- @param punishType string
-- @return boolean
function PPunish.HasActivePunishment(steamid64, punishType)
    local now = os.time()
    local query = string.format(
        "SELECT 1 FROM %s WHERE steamid64 = %s AND punishment_type = %s AND active = 1 AND (expires_at = 0 OR expires_at > %d) LIMIT 1",
        TABLE_NAME, sql.SQLStr(steamid64), sql.SQLStr(punishType), now
    )

    local result = sql.Query(query)
    return result ~= nil and result ~= false
end
