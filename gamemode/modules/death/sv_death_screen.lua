-- ============================================================
-- Star Wars: Expedition — Death Screen (Server)
-- modules/death/sv_death_screen.lua
--
-- Серверная часть экрана смерти.
--   * Запрещает игроку возрождаться в течение SWExp.DeathCfg.RespawnDelay секунд.
--   * Шлёт клиенту netstream-пакет с временем смерти и длительностью таймера.
--   * После окончания таймера (или по нажатию пробела клиентом, если включено)
--     — возрождает игрока стандартным Spawn().
-- ============================================================

if CLIENT then return end

SWExp                = SWExp                or {}
SWExp.Death          = SWExp.Death          or {}
SWExp.Death._Pending = SWExp.Death._Pending or {}  -- [ply] = endTime

-- Локальный шорткат
local function GetDelay()
    return (SWExp.DeathCfg and SWExp.DeathCfg.RespawnDelay) or 30
end

local function IsManualAllowed()
    return SWExp.DeathCfg and SWExp.DeathCfg.AllowManualRespawn ~= false
end

-- ============================================================
-- Хук на смерть игрока
-- ============================================================

hook.Add('PlayerDeath', 'SWExp::DeathScreen::OnDeath', function(victim, inflictor, attacker)
    if not IsValid(victim) or not victim:IsPlayer() then return end

    local nDelay  = GetDelay()
    local nEndAt  = CurTime() + nDelay

    SWExp.Death._Pending[victim] = nEndAt

    -- Сообщаем клиенту:
    --   nDelay  — общая длительность блокировки (для отрисовки прогресса)
    --   nEndAt  — абсолютное время завершения (CurTime на сервере)
    netstream.Start(victim, 'SWExp::DeathScreen::Show', nDelay, nEndAt)
end)

-- ============================================================
-- Блокируем автоматический респавн
-- PlayerDeathThink вызывается каждый тик, пока игрок мёртв.
-- Возврат false → запрещает респавн в этом тике.
-- ============================================================

hook.Add('PlayerDeathThink', 'SWExp::DeathScreen::BlockRespawn', function(ply)
    local nEndAt = SWExp.Death._Pending[ply]
    if not nEndAt then return end

    if CurTime() < nEndAt then
        -- Ещё рано — блокируем респавн.
        return false
    end

    if not IsManualAllowed() then
        -- Если ручной респавн отключён — возрождаем сами.
        SWExp.Death._Pending[ply] = nil
        return  -- nil → стандартное поведение, респавн разрешён
    end

    -- Таймер истёк, ручной респавн разрешён — ждём IN_JUMP от игрока.
    -- Возвращаем false, чтобы движок не возродил автоматически.
    return false
end)

-- ============================================================
-- Ручной респавн по нажатию [ПРОБЕЛ] (KeyPress IN_JUMP).
-- Срабатывает только если таймер уже истёк.
-- ============================================================

hook.Add('KeyPress', 'SWExp::DeathScreen::ManualRespawn', function(ply, key)
    if not IsValid(ply) or ply:Alive() then return end
    if key ~= IN_JUMP then return end
    if not IsManualAllowed() then return end

    local nEndAt = SWExp.Death._Pending[ply]
    if not nEndAt then return end
    if CurTime() < nEndAt then return end

    SWExp.Death._Pending[ply] = nil
    ply:Spawn()
end)

-- ============================================================
-- Чистим состояние при выходе/смене карты
-- ============================================================

hook.Add('PlayerDisconnected', 'SWExp::DeathScreen::Cleanup', function(ply)
    SWExp.Death._Pending[ply] = nil
end)

hook.Add('PlayerSpawn', 'SWExp::DeathScreen::ClearOnSpawn', function(ply)
    SWExp.Death._Pending[ply] = nil
    -- Сообщаем клиенту скрыть экран на случай форсированного респавна
    -- (например, через админ-команду).
    netstream.Start(ply, 'SWExp::DeathScreen::Hide')
end)
