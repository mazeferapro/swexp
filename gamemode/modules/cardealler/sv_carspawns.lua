-- ============================================================================
-- sv_carspawns.lua - Серверная логика спавна и пула техники (БД)
-- ============================================================================

SWExp = SWExp or {}
SWExp.CarDealer = SWExp.CarDealer or {}
SWExp.CarDealer.VehiclePool = SWExp.CarDealer.VehiclePool or {}

-- BUG-02 FIX: таблица брошенной техники [entity] = class
-- Заполняется при отключении игрока, очищается при возврате техники
SWExp.CarDealer.OrphanedVehicles = SWExp.CarDealer.OrphanedVehicles or {}

util.AddNetworkString("SWExp::CarDealer::SyncPool")
util.AddNetworkString("SWExp::CarDealer::RequestSync")

-- ИНИЦИАЛИЗАЦИЯ БАЗЫ ДАННЫХ ПУЛА
hook.Add("DatabaseInitialized", "SWExp::CarDealer_DB_Init", function()
    MySQLite.query([[
        CREATE TABLE IF NOT EXISTS swexp_vehicle_pool (
            class VARCHAR(128) NOT NULL PRIMARY KEY,
            count INT NOT NULL DEFAULT 0
        )
    ]], function()
        MySQLite.query("SELECT class, count FROM swexp_vehicle_pool", function(res)
            if res then
                for _, row in ipairs(res) do
                    SWExp.CarDealer.VehiclePool[row.class] = tonumber(row.count) or 0
                end
                MsgC(Color(0, 255, 0), "[SWExp] Пул техники загружен из БД!\n")
            end
        end)
    end)
end)

-- ФУНКЦИЯ ОБНОВЛЕНИЯ ПУЛА
function SWExp.CarDealer:UpdatePool(class, amount)
    local current = self.VehiclePool[class] or 0
    local newCount = math.max(0, current + amount)
    self.VehiclePool[class] = newCount
    
    MySQLite.query(string.format(
        "REPLACE INTO swexp_vehicle_pool (class, count) VALUES (%s, %d)",
        MySQLite.SQLStr(class), newCount
    ))
    
    self:SyncPoolToClients()
end

-- ИСПРАВЛЕНИЕ: Теперь сервер передает актуальный Тех. Уровень клиенту вместе с пулом
function SWExp.CarDealer:SyncPoolToClients(ply)
    local currentTechLevel = (SWExp and SWExp.Research and SWExp.Research._techLevel) or 1
    
    net.Start("SWExp::CarDealer::SyncPool")
    net.WriteTable(self.VehiclePool)
    net.WriteUInt(currentTechLevel, 8)
    
    if IsValid(ply) then net.Send(ply) else net.Broadcast() end
end

net.Receive("SWExp::CarDealer::RequestSync", function(len, ply)
    if IsValid(ply) then SWExp.CarDealer:SyncPoolToClients(ply) end
end)

-- BUG-02 FIX: при отключении игрока техника НЕ удаляется —
-- она переходит в статус "брошенной", чтобы любой другой игрок мог её вернуть
hook.Add("PlayerDisconnected", "SWExp::CarDealer_OrphanVeh", function(ply)
    if IsValid(ply.SpawnedVeh) then
        local sClass = ply.SpawnedVehClass or ply.SpawnedVeh:GetClass()
        SWExp.CarDealer.OrphanedVehicles[ply.SpawnedVeh] = sClass
        MsgC(Color(255, 180, 0), "[SWExp] Игрок отключился — техника '" .. sClass .. "' переведена в статус брошенной.\n")
    end
    ply.SpawnedVeh = nil
    ply.SpawnedVehClass = nil
end)

-- ПРОИЗВОДСТВО ТЕХНИКИ
netstream.Hook('SWExp::CreateCar', function(pPlayer, sClass)
    -- BUG-04 FIX: защита от спама кнопки / повторных запросов за короткое время
    if pPlayer._swexpCreateCarCooldown and pPlayer._swexpCreateCarCooldown > CurTime() then
        pPlayer:ChatPrint('[SWExp] Ошибка: Подождите перед следующим заказом!')
        return
    end
    pPlayer._swexpCreateCarCooldown = CurTime() + 2

    local settings = SWExp.CarDealer:GetVehicleSettings(sClass)
    
    local plyRankID = pPlayer:GetNWString("swexp_rank", "TRP")
    local plyRankData = SWExp.Ranks:Get(plyRankID)
    local plyOrder = plyRankData and plyRankData.sortOrder or 0

    local reqRankData = SWExp.Ranks:Get(settings.createRank or 'TRP')
    local reqOrder = reqRankData and reqRankData.sortOrder or 1

    if plyOrder < reqOrder then
        pPlayer:ChatPrint('[SWExp] Ошибка: Требуется звание не ниже: ' .. (reqRankData and reqRankData.name or 'Рядовой'))
        return
    end

    -- ИСПРАВЛЕНИЕ: Берем реальный тех. уровень базы
    local currentTechLevel = (SWExp and SWExp.Research and SWExp.Research._techLevel) or 1
    
    if currentTechLevel < settings.techLevel then
        pPlayer:ChatPrint('[SWExp] Ошибка: Требуется Технологический Уровень ' .. settings.techLevel .. '!')
        return
    end

    local currentMaterials = (SWExp.Assembler and SWExp.Assembler._bank) or 0
    if currentMaterials < settings.materialCost then
        pPlayer:ChatPrint('[SWExp] Ошибка: Недостаточно материалов в банке! (Нужно ' .. settings.materialCost .. ')')
        return
    end

    if SWExp.Assembler then
        SWExp.Assembler._bank = currentMaterials - settings.materialCost
        if MySQLite then
            MySQLite.query("UPDATE `swexp_assembler_bank` SET `materials`=" .. SWExp.Assembler._bank .. " WHERE `id`=1;")
        end
        net.Start("SWExp::Assembler_Update")
            net.WriteInt(SWExp.Assembler._bank, 32)
        net.Broadcast()
    end
    
    SWExp.CarDealer:UpdatePool(sClass, 1)
    pPlayer:ChatPrint('[SWExp] Успех: Техника произведена и доставлена в гараж!')
end)

-- ВЫЗОВ ТЕХНИКИ ИЗ ГАРАЖА
netstream.Hook('NextRP::SpawnCar', function(pPlayer, eSpawner, sClass, iSkin, tBodygroups)
    -- BUG-03 FIX: проверяем валидность терминала до любых обращений к eSpawner
    if not IsValid(eSpawner) then
        pPlayer:ChatPrint('[SWExp] Ошибка: Неверный терминал!')
        return
    end

    if IsValid(pPlayer.SpawnedVeh) then
        pPlayer:ChatPrint('[SWExp] Ошибка: Вы уже используете технику!')
        return
    end

    local settings = SWExp.CarDealer:GetVehicleSettings(sClass)
    
    local plyRankID = pPlayer:GetNWString("swexp_rank", "TRP")
    local plyRankData = SWExp.Ranks:Get(plyRankID)
    local plyOrder = plyRankData and plyRankData.sortOrder or 0

    local reqRankData = SWExp.Ranks:Get(settings.spawnRank or 'TRP')
    local reqOrder = reqRankData and reqRankData.sortOrder or 1

    if plyOrder < reqOrder then
        pPlayer:ChatPrint('[SWExp] Ошибка: У вас нет допуска к этой технике! Требуется: ' .. (reqRankData and reqRankData.name or 'Рядовой'))
        return
    end

    if SWExp.CarDealer:GetVehicleCount(sClass) <= 0 then
        pPlayer:ChatPrint('[SWExp] Ошибка: Этой техники нет в гараже! Сначала произведите её.')
        return
    end

    if not eSpawner.Platforms or table.Count(eSpawner.Platforms) == 0 then
        pPlayer:ChatPrint('[SWExp] Ошибка: К этому терминалу не привязана ни одна платформа! Админ должен добавить её через кнопку в меню.')
        return
    end

    local findedPlatform = nil
    for _, platform in pairs(eSpawner.Platforms) do
        local tr = util.TraceLine({ start = platform:GetPos(), endpos = platform:GetPos() + Vector(0, 0, 1000), filter = platform, ignoreworld = true })
        if not tr.Hit and not IsValid(tr.Entity) then findedPlatform = platform; break end
    end

    if IsValid(findedPlatform) then        
        local Veh = ents.Create(sClass)
        if not IsValid(Veh) then return end

        SWExp.CarDealer:UpdatePool(sClass, -1)

        Veh:SetPos(findedPlatform:GetPos() + Vector(0, 0, 100))
        Veh:SetAngles(findedPlatform:GetAngles())
        Veh:SetSkin(iSkin or 0)
        if tBodygroups then for k, v in pairs(tBodygroups) do Veh:SetBodygroup(k, v) end end

        Veh:Spawn()
        pPlayer.SpawnedVeh = Veh
        pPlayer.SpawnedVehClass = sClass
        pPlayer:ChatPrint('[SWExp] Успех: Техника выдана из гаража!')
    else
        pPlayer:ChatPrint('[SWExp] Ошибка: Все привязанные платформы заняты!')
    end
end)

-- ВОЗВРАТ ТЕХНИКИ
-- BUG-02 FIX: любой игрок может вернуть "брошенную" технику (после отключения хозяина)
netstream.Hook('NextRP::ReturnCar', function(pPlayer)
    local veh = nil
    local sClass = nil
    local isOrphaned = false

    -- Сначала проверяем собственную технику игрока
    if IsValid(pPlayer.SpawnedVeh) then
        veh = pPlayer.SpawnedVeh
        sClass = pPlayer.SpawnedVehClass or veh:GetClass()
    else
        -- Ищем ближайшую брошенную технику в радиусе 500 юнитов
        local bestDist = 500
        for orphVeh, orphClass in pairs(SWExp.CarDealer.OrphanedVehicles) do
            if IsValid(orphVeh) then
                local dist = pPlayer:GetPos():Distance(orphVeh:GetPos())
                if dist <= bestDist then
                    bestDist = dist
                    veh = orphVeh
                    sClass = orphClass
                    isOrphaned = true
                end
            else
                -- Чистим инвалидные записи из таблицы
                SWExp.CarDealer.OrphanedVehicles[orphVeh] = nil
            end
        end
    end

    if not IsValid(veh) then
        pPlayer:ChatPrint('[SWExp] Ошибка: У вас нет активной техники и поблизости нет брошенной техники!')
        return
    end

    -- Проверяем нахождение в зоне гаража
    local isNear = false

    for _, terminal in ipairs(ents.FindByClass("swexp_carspawner")) do
        if veh:GetPos():Distance(terminal:GetPos()) <= 1000 then
            isNear = true; break
        end
    end

    if not isNear then
        -- swexp_carplatform — реальное имя класса платформы (исправлено: было swexp_spawnplatform)
        for _, platform in ipairs(ents.FindByClass("swexp_carplatform")) do
            if veh:GetPos():Distance(platform:GetPos()) <= 1000 then
                isNear = true; break
            end
        end
    end

    if not isNear then
        if isOrphaned then
            pPlayer:ChatPrint('[SWExp] Ошибка: Вы должны подойти к брошенной технике (≤500) и находиться в зоне гаража!')
        else
            pPlayer:ChatPrint('[SWExp] Ошибка: Вы должны пригнать технику в зону гаража (на платформу)!')
        end
        return
    end

    SWExp.CarDealer:UpdatePool(sClass, 1)

    if isOrphaned then
        SWExp.CarDealer.OrphanedVehicles[veh] = nil
        pPlayer:ChatPrint('[SWExp] Успех: Брошенная техника возвращена в гараж.')
    else
        pPlayer.SpawnedVeh = nil
        pPlayer.SpawnedVehClass = nil
        pPlayer:ChatPrint('[SWExp] Успех: Техника возвращена в гараж.')
    end

    veh:Remove()
end)

-- ПРИМЕЧАНИЕ: обработчики SWExp::AddPlatform, SWExp::RemovePlatform,
-- SWExp::AddVehicle, SWExp::RemoveVehicle уже реализованы внутри энтити
-- swexp_carspawner/init.lua — дублировать их здесь не нужно.