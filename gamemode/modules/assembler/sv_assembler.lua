-- ============================================================
-- Star Wars: Expedition — Ассемблер (сервер)
-- modules/sv_assembler.lua
--
-- Общий банк материалов отряда + дневные лимиты по званиям.
--
-- ТАБЛИЦЫ MySQL:
--   swexp_assembler_bank   — id=1, materials INT
--   swexp_assembler_limits — rank_id VARCHAR PK, daily_limit INT
--   swexp_assembler_usage  — player_id INT, usage_date DATE, used INT
-- ============================================================

if CLIENT then return end

SWExp.Assembler = SWExp.Assembler or {}

-- Локальный fallback для rate-limit (если core/sv_net_ratelimit не загружен)
local function RateOk(ply, key, cd)
    if SWExp and SWExp.Net and SWExp.Net.RateCheck then
        return SWExp.Net:RateCheck(ply, key, cd)
    end
    return IsValid(ply)
end

-- ============================================================
-- Состояние сервера (кэш; сохраняется в MySQL)
-- ============================================================

SWExp.Assembler._bank      = 0       -- материалы в общем банке
SWExp.Assembler._limits    = {}      -- rankID → дневной лимит (из БД)
SWExp.Assembler._todayDate = ""      -- текущая дата "YYYY-MM-DD"

-- ============================================================
-- Net-строки
-- ============================================================

util.AddNetworkString("SWExp::Assembler_Open")          -- сервер → клиент: открыть меню
util.AddNetworkString("SWExp::Assembler_Update")        -- сервер → клиент (или всем): обновить банк
util.AddNetworkString("SWExp::Assembler_DepositReq")    -- клиент → сервер: сдать материалы
util.AddNetworkString("SWExp::Assembler_DepositResult") -- сервер → клиент: результат сдачи
util.AddNetworkString("SWExp::Assembler_CraftReq")      -- клиент → сервер: крафт
util.AddNetworkString("SWExp::Assembler_CraftResult")   -- сервер → клиент: результат крафта
util.AddNetworkString("SWExp::Assembler_SetLimit")      -- клиент (командир) → сервер: сменить лимит
util.AddNetworkString("SWExp::Assembler_LimitsSync")    -- сервер → клиент: все лимиты
util.AddNetworkString("SWExp::Assembler_TechLevel")     -- сервер → клиент: тех. уровень изменился
util.AddNetworkString("SWExp::Assembler_RefreshMyUsage")-- клиент → сервер: запросить актуальное usedToday (для авто-сброса после полуночи)
util.AddNetworkString("SWExp::Assembler_UsageUpdate")   -- сервер → клиент: обновить used/limit без пересоздания меню

-- ============================================================
-- Вспомогательные функции работы с инвентарём
-- ============================================================

-- Синхронизирует NWInt "SWExp_MatInHand" для клиентской метки ассемблера.
-- Вызывается при входе и после любого изменения мат. в инвентаре игрока.
local function SyncMatNW(ply)
    if not IsValid(ply) then return end
    local charID  = SWExp.Inventory and SWExp.Inventory:GetCharacterID(ply)
    local total   = 0
    if charID then
        local steamID = ply:SteamID64()
        local stor = SWExp.Inventory.PlayerInventories[steamID]
                     and SWExp.Inventory.PlayerInventories[steamID][charID]
        if stor then
            for _, item in pairs(stor.items) do
                if item.itemID == "mat_basic" then
                    total = total + (item.amount or 1)
                end
            end
        end
    end
    ply:SetNWInt("SWExp_MatInHand", total)
end
SWExp.Assembler.SyncMatNW = SyncMatNW  -- экспортируем для sv_inventory и т.п.

local function CountMatInInventory(ply)
    if not SWExp.Inventory then return 0 end
    local charID  = SWExp.Inventory:GetCharacterID(ply)
    if not charID then return 0 end
    local steamID = ply:SteamID64()
    local stor = SWExp.Inventory.PlayerInventories[steamID]
                 and SWExp.Inventory.PlayerInventories[steamID][charID]
    if not stor then return 0 end
    local total = 0
    for _, item in pairs(stor.items) do
        if item.itemID == "mat_basic" then
            total = total + (item.amount or 1)
        end
    end
    return total
end

local function RemoveAllMatFromInventory(ply)
    if not SWExp.Inventory then return 0 end
    local charID  = SWExp.Inventory:GetCharacterID(ply)
    if not charID then return 0 end
    local steamID = ply:SteamID64()
    local stor = SWExp.Inventory.PlayerInventories[steamID]
                 and SWExp.Inventory.PlayerInventories[steamID][charID]
    if not stor then return 0 end
    local total, toRemove = 0, {}
    for uid, item in pairs(stor.items) do
        if item.itemID == "mat_basic" then
            total = total + (item.amount or 1)
            table.insert(toRemove, { uid = uid, amt = item.amount or 1 })
        end
    end
    for _, e in ipairs(toRemove) do
        SWExp.Inventory:RemoveItem(ply, e.uid, e.amt, false)
    end
    return total
end

-- ============================================================
-- Дата (UTC; сброс лимитов ежедневно)
-- ============================================================

local function TodayDate()
    return os.date("!%Y-%m-%d")
end

-- ============================================================
-- MySQL инициализация
-- ============================================================

local function InitDB()
    if not MySQLite then return end

    -- Банк
    MySQLite.query([[
        CREATE TABLE IF NOT EXISTS `swexp_assembler_bank` (
            `id`        INT NOT NULL DEFAULT 1,
            `materials` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`)
        );
    ]])
    MySQLite.query("INSERT IGNORE INTO `swexp_assembler_bank` (`id`,`materials`) VALUES (1,0);")

    -- Лимиты по званиям
    MySQLite.query([[
        CREATE TABLE IF NOT EXISTS `swexp_assembler_limits` (
            `rank_id`     VARCHAR(32) NOT NULL,
            `daily_limit` INT         NOT NULL DEFAULT 30,
            PRIMARY KEY (`rank_id`)
        );
    ]])

    -- Дневное использование
    MySQLite.query([[
        CREATE TABLE IF NOT EXISTS `swexp_assembler_usage` (
            `player_id`  INT         NOT NULL,
            `usage_date` DATE        NOT NULL,
            `used`       INT         NOT NULL DEFAULT 0,
            PRIMARY KEY (`player_id`, `usage_date`)
        );
    ]])

    -- Загрузить банк
    MySQLite.query(
        "SELECT `materials` FROM `swexp_assembler_bank` WHERE `id`=1",
        function(rows)
            if rows and rows[1] then
                SWExp.Assembler._bank = tonumber(rows[1].materials) or 0
            end
        end
    )

    -- Загрузить лимиты (мёрж с дефолтами из конфига — INSERT OR IGNORE для SQLite / INSERT IGNORE для MySQL)
    if SWExp.AssemblerConfig then
        for rankID, def in pairs(SWExp.AssemblerConfig.DefaultDailyLimits) do
            MySQLite.query(
                string.format("INSERT IGNORE INTO `swexp_assembler_limits` (`rank_id`,`daily_limit`) VALUES (%s, %d);",
                    MySQLite.SQLStr(rankID), tonumber(def) or 30)
            )
        end
    end

    MySQLite.query(
        "SELECT `rank_id`, `daily_limit` FROM `swexp_assembler_limits`",
        function(rows)
            if rows then
                for _, row in ipairs(rows) do
                    SWExp.Assembler._limits[row.rank_id] = tonumber(row.daily_limit) or 30
                end
            end
            -- Заполнить дефолтами для тех, кого нет в таблице
            if SWExp.AssemblerConfig then
                for rankID, def in pairs(SWExp.AssemblerConfig.DefaultDailyLimits) do
                    if not SWExp.Assembler._limits[rankID] then
                        SWExp.Assembler._limits[rankID] = def
                    end
                end
            end
        end
    )
end

hook.Add("DatabaseInitialized", "SWExp::Assembler_InitDB", function()
    InitDB()
end)

-- ============================================================
-- Получить дневное использование игрока
-- ============================================================

local function GetUsedToday(playerDBID, callback)
    if not MySQLite then callback(0) return end
    local pid = tonumber(playerDBID) or 0
    local today = TodayDate()
    MySQLite.query(
        string.format("SELECT `used` FROM `swexp_assembler_usage` WHERE `player_id`=%d AND `usage_date`=%s",
            pid, MySQLite.SQLStr(today)),
        function(rows)
            if rows and rows[1] then
                callback(tonumber(rows[1].used) or 0)
            else
                callback(0)
            end
        end
    )
end

-- Добавить к использованию
local function AddUsage(playerDBID, amount)
    if not MySQLite then return end
    local pid = tonumber(playerDBID) or 0
    local amt = tonumber(amount) or 0
    local today = TodayDate()
    MySQLite.query(
        string.format(
            "INSERT INTO `swexp_assembler_usage` (`player_id`,`usage_date`,`used`) VALUES (%d, %s, %d) " ..
            "ON DUPLICATE KEY UPDATE `used`=`used`+%d;",
            pid, MySQLite.SQLStr(today), amt, amt
        )
    )
end

-- Уменьшить использование (при сдаче материалов) — не ниже нуля
local function ReduceUsage(playerDBID, amount)
    if not MySQLite then return end
    local pid = tonumber(playerDBID) or 0
    local amt = tonumber(amount) or 0
    local today = TodayDate()
    MySQLite.query(
        string.format(
            "UPDATE `swexp_assembler_usage` SET `used`=GREATEST(0, `used`-%d) " ..
            "WHERE `player_id`=%d AND `usage_date`=%s;",
            amt, pid, MySQLite.SQLStr(today)
        )
    )
end

-- ============================================================
-- Получить DB ID игрока из NW или из chars
-- ============================================================

local function GetPlayerDBID(ply)
    -- pPlayer.SWExp_ID устанавливается sv_playerhooks при загрузке игрока из БД
    local id = ply.SWExp_ID
    if id and id > 0 then return id end
    return nil
end

-- ============================================================
-- Получить лимит игрока по его званию
-- ============================================================

local function GetPlayerLimit(ply)
    local rankID = ply:GetNWString("swexp_rank", "TRP")
    return SWExp.Assembler._limits[rankID]
        or (SWExp.AssemblerConfig and SWExp.AssemblerConfig.GetDefaultLimit and
            SWExp.AssemblerConfig.GetDefaultLimit(rankID))
        or 30
end

-- ============================================================
-- Синхронизировать данные ассемблера конкретному игроку
-- (банк + его дневное использование + его лимит + все лимиты)
-- ============================================================

function SWExp.Assembler.SendMenuData(ply)
    if not IsValid(ply) then return end

    local techLevel  = SWExp.Research and SWExp.Research._techLevel or 1
    local bank       = SWExp.Assembler._bank
    local inHand     = CountMatInInventory(ply)
    local limit      = GetPlayerLimit(ply)
    local playerDBID = GetPlayerDBID(ply)

    local function DoSend(usedToday)
        -- Упакуем лимиты в JSON для передачи
        local limitsJSON = util.TableToJSON(SWExp.Assembler._limits)

        net.Start("SWExp::Assembler_Open")
            net.WriteUInt(techLevel,   8)
            net.WriteInt(bank,         32)
            net.WriteUInt(inHand,      16)
            net.WriteUInt(limit,       16)
            net.WriteUInt(usedToday,   16)
            net.WriteString(limitsJSON)
        net.Send(ply)
        hook.Run("SWExp::AssemblerMenuOpened", ply)
    end

    if playerDBID and MySQLite then
        GetUsedToday(playerDBID, DoSend)
    else
        DoSend(0)
    end
end

-- Разослать обновление банка всем онлайн (после сдачи/крафта)
local function BroadcastBankUpdate(bank)
    net.Start("SWExp::Assembler_Update")
        net.WriteInt(bank, 32)
    net.Broadcast()
end

-- ============================================================
-- Обработка: СДАТЬ материалы в банк
-- ============================================================

net.Receive("SWExp::Assembler_DepositReq", function(len, ply)
    if not IsValid(ply) then return end
    if not RateOk(ply, "Assembler_DepositReq") then return end

    local amount = RemoveAllMatFromInventory(ply)
    if amount <= 0 then
        net.Start("SWExp::Assembler_DepositResult")
            net.WriteBool(false)
            net.WriteString("У вас нет материалов для сдачи.")
            net.WriteInt(0, 16)
            net.WriteInt(SWExp.Assembler._bank, 32)
        net.Send(ply)
        return
    end

    -- Зачисляем в банк
    SWExp.Assembler._bank = SWExp.Assembler._bank + amount
    if MySQLite then
        MySQLite.query(
            string.format("UPDATE `swexp_assembler_bank` SET `materials`=%d WHERE `id`=1;",
                tonumber(SWExp.Assembler._bank) or 0)
        )
    end

    print(string.format("[SWExp|Asm] %s сдал %d мат. Банк: %d", ply:Nick(), amount, SWExp.Assembler._bank))

    SyncMatNW(ply)  -- обнуляем метку ассемблера над головой

    -- Сбрасываем использованный лимит на количество сданных материалов
    local playerDBID = GetPlayerDBID(ply)
    if playerDBID and MySQLite then
        ReduceUsage(playerDBID, amount)
        -- Получаем обновлённое значение и отправляем клиенту
        GetUsedToday(playerDBID, function(newUsed)
            net.Start("SWExp::Assembler_DepositResult")
                net.WriteBool(true)
                net.WriteString("")
                net.WriteInt(amount, 16)
                net.WriteInt(SWExp.Assembler._bank, 32)
                net.WriteBool(true)           -- флаг: есть обновление лимита
                net.WriteUInt(newUsed, 16)
            net.Send(ply)
        end)
    else
        net.Start("SWExp::Assembler_DepositResult")
            net.WriteBool(true)
            net.WriteString("")
            net.WriteInt(amount, 16)
            net.WriteInt(SWExp.Assembler._bank, 32)
            net.WriteBool(false)  -- нет обновления лимита
        net.Send(ply)
    end

    BroadcastBankUpdate(SWExp.Assembler._bank)
end)

-- ============================================================
-- Обработка: КРАФТ
-- ============================================================

net.Receive("SWExp::Assembler_CraftReq", function(len, ply)
    if not IsValid(ply) then return end
    if not RateOk(ply, "Assembler_CraftReq") then return end

    local recipeID = net.ReadString()
    if not recipeID or recipeID == "" then return end
    -- Лимит длины: ID рецепта не может быть длиннее 64 символов
    if #recipeID > 64 then return end

    local cfg = SWExp.AssemblerConfig
    if not cfg then
        net.Start("SWExp::Assembler_CraftResult")
            net.WriteBool(false)
            net.WriteString("Конфиг ассемблера не загружен.")
            net.WriteUInt(0, 8)
        net.Send(ply)
        return
    end

    local recipe = cfg.GetRecipe(recipeID)
    if not recipe then
        net.Start("SWExp::Assembler_CraftResult")
            net.WriteBool(false)
            net.WriteString("Рецепт не найден.")
            net.WriteUInt(0, 8)
        net.Send(ply)
        return
    end

    -- Тех. уровень
    local techLevel = SWExp.Research and SWExp.Research._techLevel or 1
    if recipe.techLevel and recipe.techLevel > techLevel then
        net.Start("SWExp::Assembler_CraftResult")
            net.WriteBool(false)
            net.WriteString("Недостаточный тех. уровень (нужен " .. recipe.techLevel .. ", текущий " .. techLevel .. ").")
            net.WriteUInt(0, 8)
        net.Send(ply)
        return
    end

    local cost = recipe.cost or 0

    -- Банк
    if SWExp.Assembler._bank < cost then
        net.Start("SWExp::Assembler_CraftResult")
            net.WriteBool(false)
            net.WriteString("В банке недостаточно материалов (" .. SWExp.Assembler._bank .. "/" .. cost .. ").")
            net.WriteUInt(0, 8)
        net.Send(ply)
        return
    end

    -- Дневной лимит игрока
    local playerDBID = GetPlayerDBID(ply)
    local limit      = GetPlayerLimit(ply)

    local function ProceedWithUsage(usedToday)
        local remaining = limit - usedToday
        if remaining < cost then
            net.Start("SWExp::Assembler_CraftResult")
                net.WriteBool(false)
                net.WriteString("Превышен дневной лимит. Использовано: " .. usedToday .. "/" .. limit
                    .. " мат. Осталось: " .. math.max(0, remaining) .. ".")
                net.WriteUInt(0, 8)
            net.Send(ply)
            return
        end

        -- Место в инвентаре
        if not SWExp.Inventory then
            net.Start("SWExp::Assembler_CraftResult")
                net.WriteBool(false)
                net.WriteString("Система инвентаря недоступна.")
                net.WriteUInt(0, 8)
            net.Send(ply)
            return
        end

        local amount = recipe.amount or 1
        local ok, err = SWExp.Inventory:AddItem(ply, recipe.result, amount)
        if not ok then
            net.Start("SWExp::Assembler_CraftResult")
                net.WriteBool(false)
                net.WriteString("Нет места в инвентаре для «" .. (recipe.name or recipe.result) .. "».")
                net.WriteUInt(0, 8)
            net.Send(ply)
            return
        end

        -- Всё OK — списываем из банка и пишем использование
        SWExp.Assembler._bank = SWExp.Assembler._bank - cost
        if MySQLite then
            MySQLite.query(
                "UPDATE `swexp_assembler_bank` SET `materials`=" .. SWExp.Assembler._bank .. " WHERE `id`=1;"
            )
        end

        if playerDBID then
            AddUsage(playerDBID, cost)
        end

        local craftedName = recipe.name or recipe.result
        print(string.format("[SWExp|Asm] %s скрафтил «%s» ×%d (-%d мат, банк=%d)",
            ply:Nick(), craftedName, amount, cost, SWExp.Assembler._bank))

        -- Передаём сколько использовано сегодня ПОСЛЕ крафта
        local newUsed = usedToday + cost

        SyncMatNW(ply)  -- обновляем метку ассемблера (предмет добавлен в инвентарь)

        net.Start("SWExp::Assembler_CraftResult")
            net.WriteBool(true)
            net.WriteString(craftedName)
            net.WriteUInt(amount, 8)
            net.WriteUInt(newUsed, 16)
            net.WriteInt(SWExp.Assembler._bank, 32)
        net.Send(ply)

        BroadcastBankUpdate(SWExp.Assembler._bank)
    end

    if playerDBID and MySQLite then
        GetUsedToday(playerDBID, ProceedWithUsage)
    else
        ProceedWithUsage(0)
    end
end)

-- ============================================================
-- Обновление usedToday по запросу клиента (чтобы лимит "сбрасывался" в UI после полуночи UTC,
-- даже если меню ассемблера оставлено открытым долгое время).
-- ============================================================

net.Receive("SWExp::Assembler_RefreshMyUsage", function(len, ply)
    if not IsValid(ply) then return end
    if not RateOk(ply, "Assembler_RefreshMyUsage", 8) then return end

    local playerDBID = GetPlayerDBID(ply)
    local function SendUpdate(usedToday)
        net.Start("SWExp::Assembler_UsageUpdate")
            net.WriteUInt(usedToday, 16)
            net.WriteUInt(GetPlayerLimit(ply), 16)
        net.Send(ply)
    end

    if playerDBID and MySQLite then
        GetUsedToday(playerDBID, SendUpdate)
    else
        SendUpdate(0)
    end
end)

-- ============================================================
-- Обработка: командир меняет лимит звания
-- ============================================================

net.Receive("SWExp::Assembler_SetLimit", function(len, ply)
    if not IsValid(ply) then return end
    if not RateOk(ply, "Assembler_SetLimit") then return end

    -- Только командиры и выше (CMDR, MCMDR) или админ
    local rank = ply:GetNWString("swexp_rank", "")
    local isCommander = (rank == "CMDR" or rank == "MCMDR")
    local isAdmin     = ply:IsAdmin() or ply:IsSuperAdmin()
    if not isCommander and not isAdmin then
        ply:ChatPrint("[Ассемблер] Только командиры могут менять лимиты.")
        return
    end

    local rankID   = net.ReadString()
    local newLimit = net.ReadUInt(16)

    if not rankID or rankID == "" then return end
    if #rankID > 32 then return end
    newLimit = math.Clamp(newLimit, 0, 9999)

    SWExp.Assembler._limits[rankID] = newLimit

    if MySQLite then
        MySQLite.query(
            string.format(
                "INSERT INTO `swexp_assembler_limits` (`rank_id`,`daily_limit`) VALUES (%s, %d) " ..
                "ON DUPLICATE KEY UPDATE `daily_limit`=%d;",
                MySQLite.SQLStr(rankID), newLimit, newLimit
            )
        )
    end

    ply:ChatPrint(string.format("[Ассемблер] Лимит для %s установлен: %d мат./день", rankID, newLimit))
    print(string.format("[SWExp|Asm] %s изменил лимит %s → %d", ply:Nick(), rankID, newLimit))

    -- Разослать обновлённые лимиты всем
    local limitsJSON = util.TableToJSON(SWExp.Assembler._limits)
    net.Start("SWExp::Assembler_LimitsSync")
        net.WriteString(limitsJSON)
    net.Broadcast()
end)

-- ============================================================
-- Синхронизация банка при входе игрока
-- ============================================================

hook.Add("PlayerInitialSpawn", "SWExp::Assembler_SyncOnJoin", function(ply)
    timer.Simple(5, function()
        if not IsValid(ply) then return end
        net.Start("SWExp::Assembler_Update")
            net.WriteInt(SWExp.Assembler._bank, 32)
        net.Send(ply)
        SyncMatNW(ply)  -- синхронизируем количество мат. в инвентаре сразу при входе
    end)
end)

-- Обновляем NW при любом изменении инвентаря (если инвентарь поддерживает хук)
hook.Add("SWExp::InventoryChanged", "SWExp::Assembler_SyncMatNW", function(ply)
    if IsValid(ply) then SyncMatNW(ply) end
end)

-- ============================================================
-- Синхронизация тех. уровня с клиентами ассемблера
-- ============================================================

hook.Add("SWExp::TechLevelChanged", "SWExp::Assembler_BroadcastTechLevel", function(newLevel, isFinal)
    net.Start("SWExp::Assembler_TechLevel")
        net.WriteUInt(newLevel, 8)
        net.WriteBool(isFinal or false)
    net.Broadcast()
end)

print("[SWExp] Модуль ассемблера (сервер) загружен.")

