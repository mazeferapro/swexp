-- ============================================================
-- modules/sv_trademc.lua
-- Интеграция с TradeMC (автодонат)
-- https://trademc.org
--
-- В панели TradeMC (настройки товара) используй переменную %steamid%
-- — TradeMC подставляет Steam64 ID покупателя.
--
-- Доступные команды (выполняются через RCON):
--   swexp_give_currency %steamid% <кол-во>
--   swexp_give_slots    %steamid% <кол-во>
--   swexp_give_rank     %steamid% <id_персонажа> <ранг>
-- ============================================================

if CLIENT then return end

-- ============================================================
-- ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ
-- Ищет онлайн-игрока по Steam64 ID
-- ============================================================
local function FindPlayerBySteam64(steam64)
    for _, p in ipairs(player.GetAll()) do
        if p:SteamID64() == steam64 then
            return p
        end
    end
    return nil
end

-- ============================================================
-- КОМАНДА: swexp_give_currency <steam64> <кол-во>
-- Выдаёт донат-валюту. Работает онлайн и офлайн.
--
-- Пример команды в панели TradeMC:
--   swexp_give_currency %steamid% 100
-- ============================================================
concommand.Add('swexp_give_currency', function(ply, cmd, args)
    -- Разрешаем только из консоли сервера
    if IsValid(ply) then
        print('[TradeMC] Команда разрешена только из серверной консоли')
        return
    end

    local steam64 = args[1]
    local amount  = tonumber(args[2]) or 0

    if not steam64 or steam64 == '' or amount <= 0 then
        print('[TradeMC] Использование: swexp_give_currency <steam64> <кол-во>')
        return
    end

    -- Обновляем в БД (работает всегда — онлайн и офлайн)
    MySQLite.query(
        string.format(
            'UPDATE `swexp_players` SET donate_currency = donate_currency + %d WHERE community_id = %s;',
            amount,
            MySQLite.SQLStr(steam64)
        ),
        function()
            -- Если игрок онлайн — обновляем переменную в памяти сразу
            local target = FindPlayerBySteam64(steam64)
            if IsValid(target) then
                target.SWExp_DonateCurrency = (target.SWExp_DonateCurrency or 0) + amount
                -- Отправляем клиенту обновлённое значение
                netstream.Start(target, 'SWExp::DonateCurrencyUpdate', target.SWExp_DonateCurrency)
                print(string.format('[TradeMC] +%d donate_currency → %s (онлайн)', amount, target:Nick()))
            else
                print(string.format('[TradeMC] +%d donate_currency → Steam64 %s (офлайн, записано в БД)', amount, steam64))
            end
        end,
        function(err)
            print('[TradeMC] Ошибка БД при выдаче валюты: ' .. tostring(err))
        end
    )
end)

-- ============================================================
-- КОМАНДА: swexp_give_slots <steam64> <кол-во>
-- Выдаёт слоты персонажей. Работает онлайн и офлайн.
--
-- Пример команды в панели TradeMC:
--   swexp_give_slots %steamid% 1
-- ============================================================
concommand.Add('swexp_give_slots', function(ply, cmd, args)
    if IsValid(ply) then return end

    local steam64 = args[1]
    local amount  = tonumber(args[2]) or 1

    if not steam64 or steam64 == '' then
        print('[TradeMC] Использование: swexp_give_slots <steam64> <кол-во>')
        return
    end

    MySQLite.query(
        string.format(
            'UPDATE `swexp_players` SET character_slots = character_slots + %d WHERE community_id = %s;',
            amount,
            MySQLite.SQLStr(steam64)
        ),
        function()
            local target = FindPlayerBySteam64(steam64)
            if IsValid(target) then
                target.SWExp_CharSlots = (target.SWExp_CharSlots or 1) + amount
                print(string.format('[TradeMC] +%d слотов персонажа → %s (онлайн)', amount, target:Nick()))
            else
                print(string.format('[TradeMC] +%d слотов персонажа → Steam64 %s (офлайн, записано в БД)', amount, steam64))
            end
        end,
        function(err)
            print('[TradeMC] Ошибка БД при выдаче слотов: ' .. tostring(err))
        end
    )
end)

-- ============================================================
-- КОМАНДА: swexp_give_rank <steam64> <character_id> <ранг>
-- Выдаёт звание конкретному персонажу.
--
-- Пример команды в панели TradeMC (ранг SGT, персонаж ID=1):
--   swexp_give_rank %steamid% 1 SGT
--
-- Список рангов из sh_ranks.lua:
--   TRP, CPL, SGT, SSGT, SGM, LT, ...
-- ============================================================
concommand.Add('swexp_give_rank', function(ply, cmd, args)
    if IsValid(ply) then return end

    local steam64     = args[1]
    local charID      = tonumber(args[2])
    local rank        = args[3]

    if not steam64 or not charID or not rank then
        print('[TradeMC] Использование: swexp_give_rank <steam64> <character_id> <ранг>')
        return
    end

    -- Проверяем, что персонаж принадлежит этому игроку
    MySQLite.query(
        string.format(
            [[SELECT c.id FROM swexp_characters c
              JOIN swexp_players p ON p.id = c.player_id
              WHERE p.community_id = %s AND c.id = %d LIMIT 1;]],
            MySQLite.SQLStr(steam64),
            charID
        ),
        function(data)
            if not data or not data[1] then
                print(string.format('[TradeMC] Персонаж %d не найден для Steam64 %s', charID, steam64))
                return
            end

            MySQLite.query(
                string.format(
                    'UPDATE `swexp_characters` SET `rank` = %s WHERE id = %d;',
                    MySQLite.SQLStr(rank),
                    charID
                ),
                function()
                    local target = FindPlayerBySteam64(steam64)
                    if IsValid(target) then
                        -- Обновляем в памяти, если этот персонаж активен
                        if target.SWExp_ActiveChar and target.SWExp_ActiveChar.id == charID then
                            target.SWExp_ActiveChar['rank'] = rank
                        end
                        -- Обновляем в списке персонажей
                        for _, char in ipairs(target.SWExp_Characters or {}) do
                            if char.id == charID then
                                char['rank'] = rank
                                break
                            end
                        end
                        print(string.format('[TradeMC] Ранг %s → персонаж %d (%s, онлайн)', rank, charID, target:Nick()))
                    else
                        print(string.format('[TradeMC] Ранг %s → персонаж %d (офлайн, записано в БД)', rank, charID))
                    end
                end,
                function(err)
                    print('[TradeMC] Ошибка БД при выдаче ранга: ' .. tostring(err))
                end
            )
        end
    )
end)

print('[TradeMC] Модуль интеграции загружен.')
