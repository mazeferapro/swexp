-- ============================================================
-- Star Wars: Expedition — Система добычи материалов (сервер)
-- modules/sv_gathering.lua
--
-- Игрок подходит к swexp_material_node и зажимает E (IN_USE).
-- Пока кнопка удержана, прогресс растёт. При 100% — добыча.
-- Если игрок отпускает E, отходит или цель исчезает — сброс.
-- ============================================================

if CLIENT then return end

SWExp.Gathering = SWExp.Gathering or {}

-- ============================================================
-- Конфигурация
-- ============================================================

local GATHER_RANGE    = 120    -- максимальная дистанция добычи (ед.)
local GATHER_DURATION = 3.5    -- время удержания E для добычи (сек)
local GATHER_COOLDOWN = 0    -- кулдаун после успешной добычи (сек)

-- ============================================================
-- Net-строки
-- ============================================================

util.AddNetworkString("SWExp::Gather_Start")   -- сервер → клиент: начало добычи (имя + длительность)
util.AddNetworkString("SWExp::Gather_Stop")    -- сервер → клиент: отмена / сброс
util.AddNetworkString("SWExp::Gather_Result")  -- сервер → клиент: результат добычи

-- ============================================================
-- Состояние на сервере (на игрока)
-- ============================================================

-- _state[steamID] = {
--   startTime   = number,
--   target      = Entity,
--   cooldownEnd = number,
-- }
local _state = {}

-- ============================================================
-- Вспомогательные
-- ============================================================

local function GetState(ply)
    local sid = ply:SteamID64()
    if not _state[sid] then
        _state[sid] = {
            startTime   = 0,
            target      = nil,
            cooldownEnd = 0,
        }
    end
    return _state[sid]
end

-- Найти ближайший допустимый узел добычи рядом с игроком
local function FindNearestNode(ply)
    local pos  = ply:GetPos()
    local best = nil
    local bestDist = GATHER_RANGE

    for _, ent in ipairs(ents.FindByClass("swexp_material_node")) do
        if not IsValid(ent) then continue end
        if ent:GetNWBool("SWExp_Depleted") then continue end
        local d = pos:Distance(ent:GetPos())
        if d < bestDist then
            bestDist = d
            best     = ent
        end
    end

    return best
end

-- Сообщить клиенту о начале добычи (один раз)
local function SendStart(ply, name, duration, startTime)
    net.Start("SWExp::Gather_Start")
        net.WriteString(name or "")
        net.WriteFloat(duration)
        net.WriteFloat(startTime)   -- серверное CurTime() старта
    net.Send(ply)
end

-- Сообщить клиенту об отмене / завершении (один раз)
local function SendStop(ply)
    net.Start("SWExp::Gather_Stop")
    net.Send(ply)
end

-- Сбросить состояние добычи игрока
local function CancelGather(ply, st)
    if st.startTime ~= 0 then
        st.startTime = 0
        st.target    = nil
        SendStop(ply)
    end
end

-- ============================================================
-- Основной цикл — таймер на всех онлайн-игроков
-- Был hook.Add("Think", ...) с частотой ~66 Hz, что давало избыточную
-- нагрузку при 50+ игроках. Добыча ресурсов не требует такой точности,
-- достаточно 10 Hz (0.1s).
-- ============================================================

local function GatheringTick()
    local now = CurTime()

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() then continue end

        local st = GetState(ply)

        if ply:KeyDown(IN_USE) then

            -- Кулдаун
            if now < st.cooldownEnd then continue end

            if st.startTime == 0 then
                -- Ищем узел, на который смотрит игрок
                local tr = ply:GetEyeTrace()
                if IsValid(tr.Entity)
                    and tr.Entity:GetClass() == "swexp_material_node"
                    and not tr.Entity:GetNWBool("SWExp_Depleted")
                    and ply:GetPos():Distance(tr.Entity:GetPos()) <= GATHER_RANGE
                then
                    local node = tr.Entity
                    st.startTime = now
                    st.target    = node
                    -- Сообщаем клиенту о старте — он сам посчитает прогресс по CurTime()
                    local matName = node:GetNWString("SWExp_MatName", "Ресурс")
                    SendStart(ply, matName, GATHER_DURATION, now)
                    ply:EmitSound("buttons/blip1.wav", 60, 100, 0.5)
                end

            else
                -- Проверяем, всё ли в порядке с текущим узлом

                -- 1) Цель ещё жива?
                if not IsValid(st.target) or st.target:GetNWBool("SWExp_Depleted") then
                    CancelGather(ply, st)
                    continue
                end

                -- 2) Игрок смотрит на цель?
                local tr = ply:GetEyeTrace()
                if tr.Entity ~= st.target then
                    CancelGather(ply, st)
                    ply:EmitSound("buttons/button10.wav", 65, 90, 0.6)
                    continue
                end

                -- 3) Игрок ещё в зоне?
                local dist = ply:GetPos():Distance(st.target:GetPos())
                if dist > GATHER_RANGE + 60 then
                    CancelGather(ply, st)
                    ply:EmitSound("buttons/button10.wav", 65, 90, 0.6)
                    continue
                end

                -- 4) Добыча завершена?
                local elapsed  = now - st.startTime
                local progress = math.Clamp(elapsed / GATHER_DURATION, 0, 1)

                if progress >= 1 then
                    local success = st.target:DoGather(ply)

                    st.cooldownEnd = now + GATHER_COOLDOWN
                    st.startTime   = 0
                    st.target      = nil

                    -- Клиент сам знает время старта и длительность, поэтому
                    -- просто шлём Stop — он поймёт что 100% достигнуто
                    SendStop(ply)

                    if success then
                        ply:EmitSound("buttons/button14.wav", 70, 120, 0.8)
                    end
                end
            end

        else
            -- Кнопка отпущена
            if st.startTime ~= 0 then
                CancelGather(ply, st)
            end
        end
    end
end

timer.Create("SWExp::GatheringTick", 0.1, 0, GatheringTick)

-- ============================================================
-- Очистка при выходе игрока
-- ============================================================

hook.Add("PlayerDisconnected", "SWExp::Gathering_Cleanup", function(ply)
    if IsValid(ply) then
        _state[ply:SteamID64()] = nil
    end
end)

-- ============================================================
-- Смерть игрока — сбрасываем добычу
-- ============================================================

hook.Add("PlayerDeath", "SWExp::Gathering_CancelOnDeath", function(ply)
    if not IsValid(ply) then return end
    local st = GetState(ply)
    CancelGather(ply, st)
end)

print("[SWExp] Модуль добычи материалов (сервер) загружен.")
