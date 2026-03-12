-- modules/sv_chars.lua
-- Система персонажей SWExp

if CLIENT then return end

SWExp.Chars = SWExp.Chars or {}

-- ============================================================
-- Стартовый ранг и модель по умолчанию
-- ============================================================

local START_RANK    = 'TRP'
local DEFAULT_MODEL = 'models/player/combine_super_soldier.mdl'

-- Модель персонажа — всегда одна стандартная.
-- Броня будет менять модель отдельной системой позже.
function SWExp.Chars:GetModelForRank(rank)
    return DEFAULT_MODEL
end

-- ============================================================
-- Загрузка персонажей игрока из БД
-- ============================================================

function SWExp.Chars:Load(pPlayer, cb)
    local playerID = pPlayer.SWExp_ID
    if not playerID then return end

    MySQLite.query(
        string.format('SELECT * FROM `swexp_characters` WHERE player_id = %s ORDER BY id ASC;',
            MySQLite.SQLStr(playerID)),
        function(tRows)
            tRows = tRows or {}
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

            -- Стартовый ранг берём из конфига, fallback → TRP
            local startRank = START_RANK
            local startModel = SWExp.Chars:GetModelForRank(startRank)

            MySQLite.query(
                string.format(
                    'INSERT INTO `swexp_characters` (player_id, clone_number, callsign, `rank`) VALUES (%s, %s, %s, %s);',
                    MySQLite.SQLStr(playerID),
                    MySQLite.SQLStr(sNumber),
                    MySQLite.SQLStr(sCallsign),
                    MySQLite.SQLStr(startRank)
                ),
                function(_, insertID)
                    local newChar = {
                        id           = insertID,
                        player_id    = playerID,
                        clone_number = sNumber,
                        callsign     = sCallsign,
                        ['rank']     = startRank,
                        model        = startModel,
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
    if pPlayer.SWExp_ActiveChar and tonumber(pPlayer.SWExp_ActiveChar.id) == tonumber(nCharID) then
        if cb then cb(false, 'Нельзя удалить активного персонажа') end
        return
    end

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
            if pPlayer.SWExp_ActiveChar and tonumber(pPlayer.SWExp_ActiveChar.id) == tonumber(nCharID) then
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

    local mdl = DEFAULT_MODEL

    pPlayer:SetNWString('swexp_model',        mdl)
    pPlayer:SetNWString('swexp_callsign',     char.callsign)
    pPlayer:SetNWString('swexp_clone_number', char.clone_number)
    pPlayer:SetNWString('swexp_rank',         char['rank'])

    local rankShort = SWExp.Ranks and SWExp.Ranks:GetShortName(char['rank']) or char['rank']
    local displayName = string.format('%s %s %s', rankShort, char.clone_number, char.callsign)
    pPlayer.SWExp_DisplayName = displayName

    -- Устанавливаем ник
    pPlayer:SetNWString('swexp_display_name', displayName)
    pPlayer:SetNWString('Nick', displayName)  -- Для совместимости с некоторыми аддонами


    if SWExp.Config and SWExp.Config.RankArmor then
        local armor = SWExp.Config.RankArmor[char['rank']] or 0
        pPlayer:SetMaxArmor(100)
        pPlayer:SetArmor(armor)
        if SWExp.Armor and SWExp.Armor.ApplyArmorSpeed then
            SWExp.Armor.ApplyArmorSpeed(pPlayer)
        end
    end

    pPlayer:Spawn()
    -- Spawn() сбрасывает модель — ставим после
    pPlayer:SetModel(mdl)

    hook.Run('SWExp::CharacterSelected', pPlayer, char)
    netstream.Start(pPlayer, 'SWExp::CharSelected', char)

    if cb then cb(true, char) end
end

-- Хук: при любом спавне восстанавливаем модель персонажа
hook.Add('PlayerSpawn', 'SWExp::RestoreModel', function(pPlayer)
    if not IsValid(pPlayer) then return end
    if not pPlayer.SWExp_ActiveChar then return end
    pPlayer:SetModel(DEFAULT_MODEL)
end)

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

netstream.Hook('SWExp::RequestChars', function(pPlayer)
    if not IsValid(pPlayer) then return end
    SWExp.Chars:Load(pPlayer, function(tChars)
        netstream.Start(pPlayer, 'SWExp::OpenCharSelect', tChars)
    end)
end)

MsgC(Color(190, 252, 3), '[ SWExp ]', color_white, ' Модуль персонажей загружен.\n')

-- ============================================================
-- ДОБАВИТЬ В КОНЕЦ gamemode/modules/sv_chars.lua
-- Полное переопределение ника игрока
-- ============================================================
 
-- Переопределяем Nick() в метатаблице
local meta = FindMetaTable('Player')
local oldNick = meta.Nick
local oldName = meta.Name
local oldGetName = meta.GetName
 
function meta:Nick()
    if self.SWExp_DisplayName then
        return self.SWExp_DisplayName
    end
    return oldNick(self)
end
 
function meta:Name()
    if self.SWExp_DisplayName then
        return self.SWExp_DisplayName
    end
    return oldName(self)
end
 
function meta:GetName()
    if self.SWExp_DisplayName then
        return self.SWExp_DisplayName
    end
    return oldGetName(self)
end
 
-- Хук для чата
hook.Add('PlayerSay', 'SWExp::ChatName', function(ply, text, teamChat)
    if not IsValid(ply) then return end
    if not ply.SWExp_DisplayName then return end
    
    -- Форматируем сообщение с кастомным ником
    local msg = teamChat and '(TEAM) ' or ''
    msg = msg .. ply.SWExp_DisplayName .. ': ' .. text
    
    if teamChat then
        -- Отправляем только команде
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and p:Team() == ply:Team() then
                p:ChatPrint(msg)
            end
        end
    else
        -- Отправляем всем
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) then
                p:ChatPrint(msg)
            end
        end
    end
    
    return ''  -- Блокируем стандартное сообщение
end)
 
-- Синхронизация с клиентом для скорборда
hook.Add('PlayerInitialSpawn', 'SWExp::SyncDisplayName', function(ply)
    timer.Simple(1, function()
        if IsValid(ply) and ply.SWExp_DisplayName then
            ply:SetNWString('SWExp_Nick', ply.SWExp_DisplayName)
        end
    end)
end)
 
-- Обновляем NWString когда меняем ник
hook.Add('SWExp::CharacterSelected', 'SWExp::UpdateDisplayNameNW', function(ply, char)
    if IsValid(ply) and ply.SWExp_DisplayName then
        ply:SetNWString('SWExp_Nick', ply.SWExp_DisplayName)
    end
end)
 
print('[SWExp] Player nickname override loaded')