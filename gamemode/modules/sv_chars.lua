-- modules/chars/sv_chars.lua
-- Система персонажей SWExp
-- Персонаж: clone_number (CT-XXXX), callsign (позывной), rank (звание)

if CLIENT then return end

SWExp.Chars = SWExp.Chars or {}

-- ============================================================
-- Загрузка персонажей игрока из БД
-- ============================================================


local DEFAULT_MODEL = 'models/player/combine_super_soldier.mdl'

function SWExp.Chars:GetModelForRank(rank)
    -- Если джобы totrlw доступны в shared — берём оттуда
    if NextRP and NextRP.Jobs then
        for _, job in pairs(NextRP.Jobs) do
            if job.ranks and job.ranks[rank] and job.ranks[rank].model then
                return job.ranks[rank].model[1] or DEFAULT_MODEL
            end
        end
    end
    return DEFAULT_MODEL
end

function SWExp.Chars:Load(pPlayer, cb)
    local playerID = pPlayer.SWExp_ID
    if not playerID then return end

    MySQLite.query(
        string.format('SELECT * FROM `swexp_characters` WHERE player_id = %s ORDER BY id ASC;',
            MySQLite.SQLStr(playerID)),
        function(tRows)
            tRows = tRows or {}
            -- Добавляем модель к каждому персонажу на основе ранга
            for _, char in ipairs(tRows) do
                char.model = SWExp.Chars:GetModelForRank(char['rank'])
            end
            pPlayer.SWExp_Characters = tRows
            if cb then cb(pPlayer.SWExp_Characters) end
        end
    )
end

-- ============================================================
-- Создание персонажа
-- ============================================================

function SWExp.Chars:Create(pPlayer, sNumber, sCallsign, cb)
    if not IsValid(pPlayer) then return end

    local playerID = pPlayer.SWExp_ID
    if not playerID then return end

    -- Проверка слотов
    local slots    = pPlayer.SWExp_CharSlots or 1
    local existing = pPlayer.SWExp_Characters or {}
    if #existing >= slots then
        if cb then cb(false, 'Нет свободных слотов') end
        return
    end

    -- Валидация
    sNumber   = string.upper(string.Trim(sNumber   or ''))
    sCallsign = string.upper(string.Trim(sCallsign or ''))

    if sNumber == '' or sCallsign == '' then
        if cb then cb(false, 'Номер и позывной не могут быть пустыми') end
        return
    end

    -- Проверка уникальности номера
    MySQLite.query(
        string.format('SELECT id FROM `swexp_characters` WHERE clone_number = %s LIMIT 1;',
            MySQLite.SQLStr(sNumber)),
        function(tExist)
            if tExist and #tExist > 0 then
                if cb then cb(false, 'Персонаж с номером ' .. sNumber .. ' уже существует') end
                return
            end

            -- Вставляем
            MySQLite.query(
                string.format(
                    'INSERT INTO `swexp_characters` (player_id, clone_number, callsign, `rank`) VALUES (%s, %s, %s, %s);',
                    MySQLite.SQLStr(playerID),
                    MySQLite.SQLStr(sNumber),
                    MySQLite.SQLStr(sCallsign),
                    MySQLite.SQLStr('CT')
                ),
                function(_, insertID)
                    local newChar = {
                        id           = insertID,
                        player_id    = playerID,
                        clone_number = sNumber,
                        callsign     = sCallsign,
                        ['rank']     = 'CT',
                        model        = SWExp.Chars:GetModelForRank('CT'),
                    }

                    pPlayer.SWExp_Characters = pPlayer.SWExp_Characters or {}
                    table.insert(pPlayer.SWExp_Characters, newChar)

                    hook.Run('SWExp::CharacterCreated', pPlayer, newChar)

                    if cb then cb(true, newChar) end
                end
            )
        end
    )
end

-- ============================================================
-- Удаление персонажа
-- ============================================================

function SWExp.Chars:Delete(pPlayer, nCharID, cb)
    if not IsValid(pPlayer) then return end

    -- Нельзя удалить активного
    if pPlayer.SWExp_ActiveChar and pPlayer.SWExp_ActiveChar.id == nCharID then
        if cb then cb(false, 'Нельзя удалить активного персонажа') end
        return
    end

    -- Проверяем что персонаж принадлежит игроку
    local found = false
    for i, c in ipairs(pPlayer.SWExp_Characters or {}) do
        if tonumber(c.id) == tonumber(nCharID) then
            found = true
            table.remove(pPlayer.SWExp_Characters, i)
            break
        end
    end

    if not found then
        if cb then cb(false, 'Персонаж не найден') end
        return
    end

    MySQLite.query(
        string.format('DELETE FROM `swexp_characters` WHERE id = %s AND player_id = %s;',
            MySQLite.SQLStr(nCharID),
            MySQLite.SQLStr(pPlayer.SWExp_ID)),
        function()
            hook.Run('SWExp::CharacterDeleted', pPlayer, nCharID)
            if cb then cb(true) end
        end
    )
end

-- ============================================================
-- Переименование позывного
-- ============================================================

function SWExp.Chars:Rename(pPlayer, nCharID, sCallsign, cb)
    if not IsValid(pPlayer) then return end

    sCallsign = string.upper(string.Trim(sCallsign or ''))
    if sCallsign == '' then
        if cb then cb(false, 'Позывной не может быть пустым') end
        return
    end

    local char = SWExp.Chars:GetByID(pPlayer, nCharID)
    if not char then
        if cb then cb(false, 'Персонаж не найден') end
        return
    end

    MySQLite.query(
        string.format('UPDATE `swexp_characters` SET callsign = %s WHERE id = %s AND player_id = %s;',
            MySQLite.SQLStr(sCallsign),
            MySQLite.SQLStr(nCharID),
            MySQLite.SQLStr(pPlayer.SWExp_ID)),
        function()
            char.callsign = sCallsign

            -- Обновляем активного если это он
            if pPlayer.SWExp_ActiveChar and pPlayer.SWExp_ActiveChar.id == nCharID then
                pPlayer.SWExp_ActiveChar.callsign = sCallsign
                pPlayer:SetNWString('swexp_callsign', sCallsign)
            end

            hook.Run('SWExp::CharacterRenamed', pPlayer, char)
            if cb then cb(true, char) end
        end
    )
end

-- ============================================================
-- Выбор персонажа (активация)
-- ============================================================

function SWExp.Chars:Choose(pPlayer, nCharID, cb)
    if not IsValid(pPlayer) then return end

    local char = SWExp.Chars:GetByID(pPlayer, nCharID)
    if not char then
        if cb then cb(false, 'Персонаж не найден') end
        return
    end

    pPlayer.SWExp_ActiveChar = char

    -- NW для HUD
    -- Модель по рангу (первая из конфига джоба, иначе дефолт)
    local rankCfg = SWExp.Config and SWExp.Config.Ranks and SWExp.Config.Ranks[char['rank']]
    local mdl = (rankCfg and rankCfg.model and rankCfg.model[1])
             or 'models/player/olive/cr_heavy/cr_heavy.mdl'

    pPlayer:SetModel(mdl)
    pPlayer:SetNWString('swexp_model',        mdl)
    pPlayer:SetNWString('swexp_callsign',    char.callsign)
    pPlayer:SetNWString('swexp_clone_number', char.clone_number)
    pPlayer:SetNWString('swexp_rank',         char['rank'])

    -- Применяем броню по рангу если настроена
    if SWExp.Config and SWExp.Config.RankArmor then
        local armor = SWExp.Config.RankArmor[char['rank']] or 0
        pPlayer:SetMaxArmor(100)
        pPlayer:SetArmor(armor)
        if SWExp.Armor and SWExp.Armor.ApplyArmorSpeed then
            SWExp.Armor.ApplyArmorSpeed(pPlayer)
        end
    end

    -- Спавним
    pPlayer:Spawn()

    hook.Run('SWExp::CharacterSelected', pPlayer, char)

    -- Сообщаем клиенту
    netstream.Start(pPlayer, 'SWExp::CharSelected', char)

    if cb then cb(true, char) end
end

-- ============================================================
-- Хелпер: найти персонажа по ID
-- ============================================================

function SWExp.Chars:GetByID(pPlayer, nCharID)
    for _, c in ipairs(pPlayer.SWExp_Characters or {}) do
        if tonumber(c.id) == tonumber(nCharID) then
            return c
        end
    end
    return nil
end

-- ============================================================
-- Netstream хуки (клиент → сервер)
-- ============================================================

netstream.Hook('SWExp::CreateChar', function(pPlayer, tData)
    if not IsValid(pPlayer) then return end
    if not istable(tData) then return end

    SWExp.Chars:Create(pPlayer, tData.clone_number, tData.callsign, function(bOk, result)
        if bOk then
            netstream.Start(pPlayer, 'SWExp::OpenCharSelect', pPlayer.SWExp_Characters)
        else
            netstream.Start(pPlayer, 'SWExp::CharError', result)
        end
    end)
end)

netstream.Hook('SWExp::ChooseChar', function(pPlayer, nCharID)
    if not IsValid(pPlayer) then return end
    SWExp.Chars:Choose(pPlayer, nCharID)
end)

netstream.Hook('SWExp::DeleteChar', function(pPlayer, nCharID)
    if not IsValid(pPlayer) then return end

    SWExp.Chars:Delete(pPlayer, nCharID, function(bOk, err)
        if bOk then
            netstream.Start(pPlayer, 'SWExp::OpenCharSelect', pPlayer.SWExp_Characters)
        else
            netstream.Start(pPlayer, 'SWExp::CharError', err)
        end
    end)
end)

netstream.Hook('SWExp::RenameChar', function(pPlayer, nCharID, sCallsign)
    if not IsValid(pPlayer) then return end

    SWExp.Chars:Rename(pPlayer, nCharID, sCallsign, function(bOk, result)
        if bOk then
            netstream.Start(pPlayer, 'SWExp::OpenCharSelect', pPlayer.SWExp_Characters)
        else
            netstream.Start(pPlayer, 'SWExp::CharError', result)
        end
    end)
end)

-- Обновить список (F4 открыт)
netstream.Hook('SWExp::RequestChars', function(pPlayer)
    if not IsValid(pPlayer) then return end
    SWExp.Chars:Load(pPlayer, function(tChars)
        netstream.Start(pPlayer, 'SWExp::OpenCharSelect', tChars)
    end)
end)

MsgC(Color(190, 252, 3), '[ SWExp ]', color_white, ' Модуль персонажей загружен.\n')