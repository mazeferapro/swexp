-- ============================================================================
-- sv_jobparser.lua - Серверный парсер и сохранение техники (ЧЕРЕЗ SQL БД)
-- ============================================================================

SWExp = SWExp or {}
SWExp.CarDealer = SWExp.CarDealer or {}
NextRPCarList = NextRPCarList or {}

-- ИНИЦИАЛИЗАЦИЯ ТАБЛИЦЫ НАСТРОЕК В БД
local function InitCarSettingsDB()
    if not MySQLite then return end
    
    MySQLite.query([[
        CREATE TABLE IF NOT EXISTS swexp_vehicle_settings (
            class VARCHAR(128) NOT NULL PRIMARY KEY,
            name VARCHAR(128) NOT NULL,
            materialCost INT NOT NULL DEFAULT 50,
            techLevel INT NOT NULL DEFAULT 1,
            createRank VARCHAR(32) NOT NULL DEFAULT 'TRP',
            spawnRank VARCHAR(32) NOT NULL DEFAULT 'TRP'
        )
    ]], function()
        SWExp.CarDealer:LoadSettingsFromDB()
    end)
end
hook.Add("DatabaseInitialized", "SWExp::CarSettings_DB_Init", InitCarSettingsDB)

-- ФУНКЦИЯ ЗАГРУЗКИ ИЗ БД В ОПЕРАТИВКУ
function SWExp.CarDealer:LoadSettingsFromDB()
    MySQLite.query("SELECT * FROM swexp_vehicle_settings", function(res)
        NextRPCarList = {}
        if res then
            for _, row in ipairs(res) do
                table.insert(NextRPCarList, {
                    class = row.class,
                    name = row.name,
                    materialCost = tonumber(row.materialCost) or 50,
                    techLevel = tonumber(row.techLevel) or 1,
                    createRank = row.createRank or 'TRP',
                    spawnRank = row.spawnRank or 'TRP'
                })
            end
            MsgC(Color(0, 255, 0), "[SWExp] Настройки техники (" .. #NextRPCarList .. " шт.) загружены из БД!\n")
        end
    end)
end

-- BUG-08 FIX: вместо одного хрупкого таймера на 1 секунду используем
-- повторяющийся таймер с проверкой — пробуем до 10 раз с интервалом в 2 сек.
-- Это нужно при ручном рестарте скрипта, когда событие DatabaseInitialized
-- уже было вызвано и повторно не придёт.
local _retryCount = 0
local _retryMax   = 10
timer.Create("SWExp::CarSettings_DBInitRetry", 2, _retryMax, function()
    _retryCount = _retryCount + 1
    if MySQLite and MySQLite.isInitialized and MySQLite.isInitialized() then
        InitCarSettingsDB()
        timer.Remove("SWExp::CarSettings_DBInitRetry")
    elseif _retryCount >= _retryMax then
        MsgC(Color(255, 80, 80), "[SWExp] Настройки техники не загружены: БД недоступна после " .. _retryMax .. " попыток.\n")
    end
end)

-- ПОЛУЧЕНИЕ ДАННЫХ ДЛЯ КЛИЕНТА (ОТКРЫТИЕ РЕДАКТОРА)
netstream.Hook('SWExp::GetVeh', function(pPlayer, vehEnt, vehClass)
    if not pPlayer:IsSuperAdmin() then return end

    local foundData = nil
    for _, v in pairs(NextRPCarList) do
        if v.class == vehClass then
            foundData = v
            break 
        end
    end

    netstream.Start(pPlayer, 'SWExp::GetVeh', foundData, vehEnt)
end)

-- ОБНОВЛЕНИЕ И СОХРАНЕНИЕ ДАННЫХ ТЕХНИКИ НАПРЯМУЮ В БД
netstream.Hook('SWExp::VehUpdate', function(pPlayer, tData)
    if not pPlayer:IsSuperAdmin() then return end

    -- Формируем запрос REPLACE (Добавит новую запись или обновит существующую по class)
    local query = string.format([[
        REPLACE INTO swexp_vehicle_settings 
        (class, name, materialCost, techLevel, createRank, spawnRank) 
        VALUES (%s, %s, %d, %d, %s, %s)
    ]],
        MySQLite.SQLStr(tData.class),
        MySQLite.SQLStr(tData.name),
        tonumber(tData.materialCost) or 50,
        tonumber(tData.techLevel) or 1,
        MySQLite.SQLStr(tData.createRank or 'TRP'),
        MySQLite.SQLStr(tData.spawnRank or 'TRP')
    )

    MySQLite.query(query, function()
        -- После успешного сохранения в БД обновляем кэш в ОЗУ
        SWExp.CarDealer:LoadSettingsFromDB()
        
        pPlayer:ChatPrint('[SWExp] Транспорт "' .. tData.name .. '" успешно сохранён в SQL базу данных!')
        
        -- Синхронизируем интерфейсы
        if SWExp.CarDealer and SWExp.CarDealer.SyncPoolToClients then
            SWExp.CarDealer:SyncPoolToClients()
        end
    end)
end)