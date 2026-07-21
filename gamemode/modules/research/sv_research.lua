-- ============================================================
-- Star Wars: Expedition — Исследования (сервер)
-- modules/sv_research.lua
-- ============================================================

if CLIENT then return end

SWExp.Research = SWExp.Research or {}

-- Локальный fallback для rate-limit
local function RateOk(ply, key, cd)
    if SWExp and SWExp.Net and SWExp.Net.RateCheck then
        return SWExp.Net:RateCheck(ply, key, cd)
    end
    return IsValid(ply)
end

-- Максимальное расстояние от игрока до терминала для сдачи (квадрат)
local DEPOSIT_RANGE_SQR = 250 * 250

-- ============================================================
-- Net-строки
-- ============================================================

util.AddNetworkString("SWExp::Research_Scanned")         -- скан завершён → игрок
util.AddNetworkString("SWExp::Research_Deposit")         -- сдача завершена → игрок
util.AddNetworkString("SWExp::Research_OpenMenu")        -- открыть меню терминала → игрок
util.AddNetworkString("SWExp::Research_DepositRequest")  -- клиент нажал «Сдать» → сервер

-- ============================================================
-- Кэш общего банка ОИ (синхронизируется с БД)
-- ============================================================

SWExp.Research._bankRP    = 0
SWExp.Research._techLevel = 1

local function LoadBankRP(callback)
    if not MySQLite then return end
    MySQLite.query(
        "SELECT research_points, tech_level FROM swexp_server_progress WHERE id = 1",
        function(rows)
            if rows and rows[1] then
                SWExp.Research._bankRP    = tonumber(rows[1].research_points) or 0
                SWExp.Research._techLevel = tonumber(rows[1].tech_level) or 1
            end
            if callback then callback() end
        end
    )
end

hook.Add("DatabaseInitialized", "SWExp::Research_LoadBank", function()
    LoadBankRP()
end)

-- ============================================================
-- Подсчёт research_data в инвентаре игрока
-- ============================================================

local function CountResearchData(ply)
    if not SWExp.Inventory then return 0 end
    local charID  = SWExp.Inventory:GetCharacterID(ply)
    if not charID then return 0 end
    local steamID = ply:SteamID64()
    local storage = SWExp.Inventory.PlayerInventories[steamID]
                    and SWExp.Inventory.PlayerInventories[steamID][charID]
    if not storage then return 0 end

    local total = 0
    for _, item in pairs(storage.items) do
        if item.itemID == "research_data" then
            total = total + (item.amount or 1)
        end
    end
    return total
end

-- Удалить все research_data из инвентаря; вернуть количество
local function RemoveAllResearchData(ply)
    if not SWExp.Inventory then return 0 end
    local charID  = SWExp.Inventory:GetCharacterID(ply)
    if not charID then return 0 end
    local steamID = ply:SteamID64()
    local storage = SWExp.Inventory.PlayerInventories[steamID]
                    and SWExp.Inventory.PlayerInventories[steamID][charID]
    if not storage then return 0 end

    local total   = 0
    local toRemove = {}
    for uid, item in pairs(storage.items) do
        if item.itemID == "research_data" then
            total = total + (item.amount or 1)
            table.insert(toRemove, uid)
        end
    end

    for _, uid in ipairs(toRemove) do
        SWExp.Inventory:RemoveItem(ply, uid, nil, false)
    end

    return total
end

-- Синхронизировать NW var с фактическим количеством ОИ в инвентаре
function SWExp.Research.SyncCollectedRP(ply)
    if not IsValid(ply) then return end
    ply:SetNWInt("SWExp_CollectedRP", CountResearchData(ply))
end

-- ============================================================
-- API: добавить ОИ в инвентарь игрока (вызывается из DoScan)
-- ============================================================

function SWExp.Research.AddCollected(ply, amount)
    if not IsValid(ply) then return end
    if not SWExp.Inventory then return end

    local ok, err = SWExp.Inventory:AddItem(ply, "research_data", amount)
    if not ok then
        -- Инвентарь полон — уведомляем игрока и не теряем данные
        ply:ChatPrint("[SWExp] Инвентарь полон! Освободите место для Данных исследования.")
    end

    -- Обновляем NW после небольшой паузы (инвентарь синхронизируется асинхронно)
    timer.Simple(0.3, function()
        if IsValid(ply) then
            SWExp.Research.SyncCollectedRP(ply)
        end
    end)
end

-- ============================================================
-- API: сдать ОИ из инвентаря в банк
-- Вызывается из ENT:Use терминала
-- ============================================================

function SWExp.Research.Deposit(ply)
    if not IsValid(ply) then return false, 0 end

    local amount = RemoveAllResearchData(ply)
    if amount <= 0 then return false, 0 end

    -- Зачисляем в общий банк
    SWExp.Research._bankRP = SWExp.Research._bankRP + amount

    if MySQLite then
        MySQLite.query(string.format(
            "UPDATE swexp_server_progress SET research_points = %d WHERE id = 1",
            tonumber(SWExp.Research._bankRP) or 0
        ))
    end

    -- Пересчитываем тех. уровень
    if SWExp.ResearchConfig then
        local newLevel = SWExp.ResearchConfig.GetCurrentTechLevel(SWExp.Research._bankRP)
        if newLevel ~= SWExp.Research._techLevel then
            SWExp.Research._techLevel = newLevel
            if MySQLite then
                MySQLite.query(string.format(
                    "UPDATE swexp_server_progress SET tech_level = %d WHERE id = 1",
                    tonumber(newLevel) or 1
                ))
            end

            -- Проверяем финал
            local isFinal = SWExp.ResearchConfig.IsFinalLevel and
                            SWExp.ResearchConfig.IsFinalLevel(newLevel)

            -- Оповещаем весь сервер о новом уровне
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) then
                    if isFinal then
                        p:ChatPrint("[ ФИНАЛ ] ГИПЕРДРАЙВ ВОССТАНОВЛЕН! Экспедиция завершена!")
                        p:ChatPrint("[ ФИНАЛ ] Все технологии изучены. Поздравляем отряд!")
                    else
                        p:ChatPrint("[ ОИ ] Технологический уровень повышен до " .. newLevel .. "!")
                    end
                end
            end

            -- Хук для возможного расширения (вайп сервера и т.д.)
            hook.Run("SWExp::TechLevelChanged", newLevel, isFinal)
        end
    end

    -- Обнуляем NW var
    ply:SetNWInt("SWExp_CollectedRP", 0)

    -- Уведомляем игрока
    net.Start("SWExp::Research_Deposit")
        net.WriteInt(amount, 16)
        net.WriteInt(SWExp.Research._bankRP, 32)
    net.Send(ply)

    print(string.format("[SWExp] %s сдал %d ОИ. Итого в банке: %d", ply:Nick(), amount, SWExp.Research._bankRP))
    return true, amount
end

-- ============================================================
-- API: открыть меню терминала на клиенте
-- ============================================================

function SWExp.Research.SendMenuData(ply)
    if not IsValid(ply) then return end

    local bankRP    = SWExp.Research._bankRP
    local techLevel = SWExp.Research._techLevel
    local collected = CountResearchData(ply)
    local nextThreshold = SWExp.ResearchConfig
        and SWExp.ResearchConfig.GetNextThreshold(techLevel) or nil
    local maxLevel  = SWExp.ResearchConfig and SWExp.ResearchConfig.MaxTechLevel or 5

    net.Start("SWExp::Research_OpenMenu")
        net.WriteInt(techLevel,  8)
        net.WriteInt(bankRP,     32)
        net.WriteInt(collected,  16)
        net.WriteBool(nextThreshold ~= nil)
        if nextThreshold then
            net.WriteInt(nextThreshold, 32)
        end
        net.WriteInt(maxLevel, 8)
    net.Send(ply)
end

-- ============================================================
-- Клиент нажал «Сдать» в меню терминала
-- ============================================================

net.Receive("SWExp::Research_DepositRequest", function(len, ply)
    if not IsValid(ply) then return end
    if not RateOk(ply, "Research_DepositRequest") then return end

    -- Проверка расстояния до ближайшего research-терминала
    local plyPos = ply:GetPos()
    local nearest = nil
    local bestDistSqr = DEPOSIT_RANGE_SQR
    for _, term in ipairs(ents.FindByClass("swexp_research_terminal")) do
        if IsValid(term) then
            local d = plyPos:DistToSqr(term:GetPos())
            if d <= bestDistSqr then
                bestDistSqr = d
                nearest = term
            end
        end
    end
    if not IsValid(nearest) then
        ply:ChatPrint("[ОИ] Подойдите к терминалу исследований, чтобы сдать данные.")
        return
    end

    SWExp.Research.Deposit(ply)
end)

-- ============================================================
-- Синхронизация при входе игрока
-- ============================================================

hook.Add("PlayerInitialSpawn", "SWExp::Research_SyncOnSpawn", function(ply)
    -- Задержка нужна, чтобы инвентарь успел загрузиться из БД
    timer.Simple(3, function()
        if IsValid(ply) then
            SWExp.Research.SyncCollectedRP(ply)
        end
    end)
end)

-- Обновляем NW ОИ при любом изменении инвентаря (если инвентарь поддерживает хук)
hook.Add("SWExp::InventoryChanged", "SWExp::Research_SyncCollectedRP", function(ply)
    if IsValid(ply) then
        SWExp.Research.SyncCollectedRP(ply)
    end
end)

print("[SWExp] Модуль исследований (сервер) загружен.")
