-- Спавн диллера на запуске сервера/клинапе
local function SpawnDealers()
    local dealersInfo = file.Read('dealers.txt', 'DATA')
    if dealersInfo == nil then
        file.Write('dealers.txt', '[]')
        print('[NextRP] Создан файл для спавнера техники!')
        return 
    end
    
    -- BUG-06 FIX: проверка на nil после парсинга JSON (при повреждённом файле)
    dealersInfo = util.JSONToTable(dealersInfo)
    if not dealersInfo then
        print('[NextRP] [ОШИБКА] Файл dealers.txt содержит невалидный JSON! Спавн дилеров отменён.')
        return
    end

    for k, v in pairs(dealersInfo) do
        -- Проверка карты
        if k ~= game.GetMap() then continue end

        for kk, vv in pairs(v) do 
        -- Проверка настроек диллера
            -- BUG-07 FIX: убраны дебаг-принты из продакшн-кода
            if not vv.pos then continue end
            if not vv.ang then continue end
            if not vv.platforms then continue end
            if not vv.faction then continue end
            if not vv.vehs then continue end

            

            -- BUG-01 FIX: nextrp_carspawner не существует — правильный класс swexp_carspawner
            local dealer = ents.Create('swexp_carspawner')
            if IsValid(dealer) then
                dealer:SetPos(vv.pos)
                dealer:SetAngles(vv.ang)
                dealer:AddFlags(FL_NOTARGET)

                dealer:Spawn()

                dealer:SpawnPlatforms(vv.platforms)
                dealer.Faction = vv.faction
                dealer.Vehicles = vv.vehs

                
            end
        end
    end

    if not file.Exists('cars.txt', 'DATA') then
        file.Write('cars.txt', '[]')
        print('Created cars file!')
    end

    local cars = util.JSONToTable(file.Read('cars.txt', 'DATA'))
    NextRPCarList = cars
end

hook.Add('InitPostEntity', 'NextRP::SpawnCarDealers', SpawnDealers)
hook.Add('PostCleanupMap', 'NextRP::SpawnCarDealers', SpawnDealers)

-- ============================================================================
-- СОХРАНЕНИЕ ТЕРМИНАЛОВ (общая функция — вызывается из netstream и concommand)
-- ============================================================================
local function DoSaveDealers(pPlayer)
    local dealers = ents.FindByClass('swexp_carspawner')

    local dealersInfo = file.Read('dealers.txt', 'DATA')
    -- BUG-05 FIX: при отсутствии файла НЕ выходим — продолжаем с пустой таблицей
    if dealersInfo == nil then
        file.Write('dealers.txt', '[]')
        print('[NextRP] Создан файл для спавнера техники!')
        dealersInfo = {}
    else
        -- BUG-06 FIX: проверка на nil после парсинга JSON
        dealersInfo = util.JSONToTable(dealersInfo)
        if not dealersInfo then
            print('[NextRP] [ОШИБКА] Файл dealers.txt содержит невалидный JSON! Сохраняется только текущая карта.')
            dealersInfo = {}
        end
    end

    dealersInfo[game.GetMap()] = {}

    for k, v in pairs(dealers) do
        local index = #dealersInfo[game.GetMap()] + 1
        dealersInfo[game.GetMap()][index] = {
            pos      = v:GetPos(),
            ang      = v:GetAngles(),
            platforms = v:GetPlatforms(),
            faction  = v.Faction,
            vehs     = v.Vehicles
        }
    end

    file.Write('dealers.txt', util.TableToJSON(dealersInfo))

    local count = #dealersInfo[game.GetMap()]
    local msg = '[SWExp] Сохранено терминалов: ' .. count .. ' (карта: ' .. game.GetMap() .. ')'
    print(msg)
    if IsValid(pPlayer) then pPlayer:ChatPrint(msg) end
end

-- Вызов из клиентского интерфейса
netstream.Hook('NextRP::SaveDealers', function(pPlayer)
    if not SWExp:HasPrivilege(pPlayer, 'manage_vehs') then return end
    DoSaveDealers(pPlayer)
end)

-- Консольная команда: работает как из консоли сервера, так и для игрока с правами
-- Использование: swexp_save_dealers
concommand.Add('swexp_save_dealers', function(pPlayer, cmd, args)
    -- pPlayer = nil когда вызывается из консоли сервера
    if IsValid(pPlayer) and not SWExp:HasPrivilege(pPlayer, 'manage_vehs') then
        pPlayer:ChatPrint('[SWExp] Ошибка: Недостаточно прав для сохранения терминалов!')
        return
    end
    DoSaveDealers(pPlayer)
end)