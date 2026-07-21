-- ============================================================
-- Star Wars: Expedition — Сохранение локации и тира игрока
-- modules/sv_spawn_location.lua
--
-- БД: отдельная таблица `swexp_player_locations`.
-- Колонки:
--   character_id INT PK   — ID персонажа (swexp_characters.id)
--   map_name     VARCHAR  — карта, на которой сделан снэпшот
--   pos_x/y/z    FLOAT
--   ang_y        FLOAT    — yaw, остальное не нужно для игрока
--   tier         INT      — ThreatTier из sv_enemy_manager
--   updated_at   TIMESTAMP
--
-- Карта проверяется при загрузке: если map_name != game.GetMap(),
-- сохранение считается невалидным → игрок появится на swexp_player_spawn.
--
-- Когда сохраняем:
--   • штатный выход с сервера (SWExp::PlayerDisconnecting, alive);
--   • авто-сейв раз в N секунд;
--   • ShutDown / смена карты;
--   • смена персонажа в Choose() — позиция СТАРОГО перса фиксируется
--     ДО подмены ActiveChar (через хук SWExp::CharacterSwitching);
--   • после реса дефибриллятором (Revival_onPlayerRevived).
--
-- Когда сбрасываем (DELETE):
--   • настоящая смерть без дефибриллятора (PlayerDeath).
-- ============================================================

if CLIENT then return end

SWExp               = SWExp               or {}
SWExp.SpawnLocation = SWExp.SpawnLocation or {}
local SL = SWExp.SpawnLocation

SL.AutoSaveInterval = SL.AutoSaveInterval or 30

-- ============================================================
-- Схема БД + миграция
-- ============================================================

local function CreateLocationTable()
    if not MySQLite or not MySQLite.query then return end
    MySQLite.query([[
        CREATE TABLE IF NOT EXISTS swexp_player_locations (
            character_id INT NOT NULL PRIMARY KEY,
            map_name     VARCHAR(64) NOT NULL DEFAULT '',
            pos_x        FLOAT NOT NULL,
            pos_y        FLOAT NOT NULL,
            pos_z        FLOAT NOT NULL,
            ang_y        FLOAT NOT NULL DEFAULT 0,
            tier         INT   NOT NULL DEFAULT 1,
            updated_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
    ]], function()
        -- Миграция: если таблица была создана старой версией без map_name,
        -- ALTER TABLE добавит колонку (молча игнорируется на новых установках).
    end)
end

hook.Add("DatabaseInitialized", "SWExp::SpawnLocation::CreateTable", CreateLocationTable)
timer.Simple(2, CreateLocationTable)  -- fallback на hot-reload

-- ============================================================
-- Утилиты
-- ============================================================

local function GetActiveCharID(ply)
    if not IsValid(ply) then return nil end
    local char = ply.SWExp_ActiveChar
    if not char then return nil end
    local id = tonumber(char.id)
    if not id or id == -1 then return nil end -- виртуальный ADMIN
    return id
end

local function GetPlayerTier(ply)
    if not IsValid(ply) then return 1 end
    if SWExp.EnemyMgr and SWExp.EnemyMgr.Pools then
        local p = SWExp.EnemyMgr.Pools[ply:SteamID64() or ""]
        if p then
            if p.tier and p.tier > 0 then return p.tier end
            if p.lastTier and p.lastTier > 0 then return p.lastTier end
        end
    end
    -- Кэш в enemy_manager перед удалением пула
    if ply.SWExp_DisconnectTier and ply.SWExp_DisconnectTier > 0 then
        return ply.SWExp_DisconnectTier
    end
    -- NWInt — переживает удаление пула
    local nw = ply:GetNWInt("SWExp_ThreatTier", 0)
    if nw and nw > 0 then return nw end
    return 1
end

local function IsAdminPly(ply)
    return IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin())
end

-- ============================================================
-- Низкоуровневые операции
-- ============================================================

-- Универсальный сейв: позволяет писать под конкретный charID
-- (используется при смене персонажа).
function SL.WriteRaw(charID, pos, angY, tier, mapName)
    if not charID or not pos then return end
    MySQLite.query(string.format([[
        REPLACE INTO swexp_player_locations
            (character_id, map_name, pos_x, pos_y, pos_z, ang_y, tier)
        VALUES (%s, %s, %s, %s, %s, %s, %s);
    ]],
        MySQLite.SQLStr(charID),
        MySQLite.SQLStr(mapName or game.GetMap()),
        MySQLite.SQLStr(pos.x),
        MySQLite.SQLStr(pos.y),
        MySQLite.SQLStr(pos.z),
        MySQLite.SQLStr(angY or 0),
        MySQLite.SQLStr(tier or 1)
    ))
end

-- Сохранить АКТИВНОГО персонажа игрока (поза + тир + текущая карта).
function SL.Save(ply)
    if not IsValid(ply) then return end
    if not ply:Alive() then return end
    if ply:InVehicle() then return end

    local charID = GetActiveCharID(ply)
    if not charID then return end

    local pos = ply:GetPos()
    if pos:LengthSqr() < 1 then return end

    SL.WriteRaw(charID, pos, ply:EyeAngles().y, GetPlayerTier(ply), game.GetMap())
end

-- Сохранить для конкретного charID (например, старого персонажа)
function SL.SaveFor(charID, ply)
    if not IsValid(ply) then return end
    if not ply:Alive() then return end
    if ply:InVehicle() then return end
    if not charID or charID == -1 then return end

    local pos = ply:GetPos()
    if pos:LengthSqr() < 1 then return end

    SL.WriteRaw(charID, pos, ply:EyeAngles().y, GetPlayerTier(ply), game.GetMap())
end

function SL.Clear(charID)
    if not charID then return end
    MySQLite.query(string.format(
        "DELETE FROM swexp_player_locations WHERE character_id = %s;",
        MySQLite.SQLStr(charID)
    ))
end

-- Загрузка с проверкой карты.
function SL.Load(charID, cb)
    if not charID then if cb then cb(nil) end return end
    MySQLite.query(string.format(
        "SELECT map_name, pos_x, pos_y, pos_z, ang_y, tier FROM swexp_player_locations WHERE character_id = %s LIMIT 1;",
        MySQLite.SQLStr(charID)
    ), function(rows)
        if not rows or not rows[1] then
            if cb then cb(nil) end
            return
        end
        local r = rows[1]
        -- Проверка карты: если сохранение для другой карты — игнорируем,
        -- игрок заспавнится на swexp_player_spawn для текущей карты.
        local savedMap = tostring(r.map_name or "")
        if savedMap ~= game.GetMap() then
            if cb then cb(nil, "map_mismatch") end
            return
        end
        if cb then cb({
            pos  = Vector(tonumber(r.pos_x) or 0, tonumber(r.pos_y) or 0, tonumber(r.pos_z) or 0),
            ang  = Angle(0, tonumber(r.ang_y) or 0, 0),
            tier = tonumber(r.tier) or 1,
        }) end
    end)
end

-- ============================================================
-- Восстановление при выборе персонажа
-- ============================================================

local function ApplySavedLocation(ply, data)
    if not IsValid(ply) then return end
    if not ply:Alive() then return end
    if not data then return end

    ply:SetPos(data.pos)
    ply:SetEyeAngles(data.ang)
    if ply:GetVelocity():LengthSqr() > 1 then
        ply:SetVelocity(-ply:GetVelocity())
    end

    if SWExp.EnemyMgr and SWExp.EnemyMgr.SetThreatTier then
        local tier = data.tier or 1
        if tier < 1 then tier = 1 end
        -- Не переопределяем тир если восстановленная позиция находится
        -- внутри сейв-зоны: UpdatePool сам сбросит тир до 0 через
        -- OnPlayerEnterSafezone. Если мы принудительно поставим tier=lastTier,
        -- а pool.isInSafezone уже true — UpdatePool никогда не пересбросит,
        -- и игрок навсегда застрянет с ненулевым тиром внутри сейв-зоны.
        local inSafe = SWExp.IsInSafezone and SWExp.IsInSafezone(ply:GetPos(), 0)
        if not inSafe then
            SWExp.EnemyMgr.SetThreatTier(ply, tier)
        end
    end

    ply.SWExp_SpawnLocationRestored = true
end

hook.Add("SWExp::CharacterSelected", "SWExp::SpawnLocation::Restore", function(ply, char)
    if not IsValid(ply) then return end
    local charID = char and tonumber(char.id) or nil
    if not charID or charID == -1 then return end

    SL.Load(charID, function(data, reason)
        if not IsValid(ply) then return end
        if not data then
            -- Нет сохранённой локации (или другая карта) — спавн через swexp_player_spawn
            return
        end
        timer.Simple(0.05, function() ApplySavedLocation(ply, data) end)
        timer.Simple(0.2,  function() ApplySavedLocation(ply, data) end)
    end)
end)

-- ============================================================
-- Смена персонажа в рантайме: сохраняем СТАРОГО до подмены ActiveChar
-- ============================================================

hook.Add("SWExp::CharacterSwitching", "SWExp::SpawnLocation::OnSwitch", function(ply, oldChar, newChar)
    if not IsValid(ply) then return end
    if not oldChar then return end
    local oldID = tonumber(oldChar.id)
    if not oldID or oldID == -1 then return end
    if not ply:Alive() then return end -- мёртвый старый персонаж не должен переписать чистку
    SL.SaveFor(oldID, ply)
end)

-- ============================================================
-- Реакция на смерть, респавн и дефибриллятор-рес
-- ============================================================

hook.Add("PlayerDeath", "SWExp::SpawnLocation::OnDeath", function(victim)
    if not IsValid(victim) then return end
    victim.SWExp_DiedPendingClear = true
    local charID = GetActiveCharID(victim)
    if charID then SL.Clear(charID) end
end)

hook.Add("PlayerSpawn", "SWExp::SpawnLocation::OnSpawn", function(ply)
    if not IsValid(ply) then return end
    -- Дефибриллятор-рес: позицию выставит сам аддон (deathPos),
    -- потом отработает Revival_onPlayerRevived и сохранит локацию.
    if ply._defibrRevive then
        ply.SWExp_DiedPendingClear = nil
        return
    end
    ply.SWExp_DiedPendingClear = nil
end)

hook.Add("Revival_onPlayerRevived", "SWExp::SpawnLocation::OnRevive", function(ply)
    if not IsValid(ply) then return end
    if not ply:Alive() then return end
    SL.Save(ply)
end)

-- ============================================================
-- Авто-сейв и сохранение при выходе/смене карты
-- ============================================================

timer.Create("SWExp::SpawnLocation::AutoSave", SL.AutoSaveInterval, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() and ply.SWExp_ActiveChar then
            SL.Save(ply)
        end
    end
end)

-- Используем SWExp::PlayerDisconnecting (fired в GM:PlayerDisconnected,
-- core/sv_playerhooks.lua). Тир здесь читается с фолбэком на
-- ply.SWExp_DisconnectTier, который выставил sv_enemy_manager.
hook.Add("SWExp::PlayerDisconnecting", "SWExp::SpawnLocation::OnDisconnect", function(ply)
    if not IsValid(ply) then return end
    if not ply:Alive() then return end
    SL.Save(ply)
end)

hook.Add("ShutDown", "SWExp::SpawnLocation::OnShutdown", function()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() then
            SL.Save(ply)
        end
    end
end)

-- ============================================================
-- Админ-команды
-- ============================================================

concommand.Add("swexp_loc_save", function(ply)
    if not IsAdminPly(ply) then return end
    SL.Save(ply)
    ply:ChatPrint("[SWExp] Локация принудительно сохранена.")
end)

concommand.Add("swexp_loc_clear", function(ply)
    if not IsAdminPly(ply) then return end
    local charID = GetActiveCharID(ply)
    if charID then
        SL.Clear(charID)
        ply:ChatPrint("[SWExp] Сохранение локации удалено.")
    else
        ply:ChatPrint("[SWExp] Нет активного персонажа.")
    end
end)

print("[SWExp] sv_spawn_location загружен.")
