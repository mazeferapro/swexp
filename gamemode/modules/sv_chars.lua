-- modules/sv_chars.lua
-- Система персонажей SWExp

if CLIENT then return end

SWExp.Chars = SWExp.Chars or {}

-- ============================================================
-- Стартовый ранг и модель по умолчанию
-- ============================================================

local START_RANK    = 'TRP'
local DEFAULT_MODEL = 'models/player/olive/cadet/cadet.mdl'

function SWExp.Chars:GetModelForRank(rank)
    return DEFAULT_MODEL
end

-- ============================================================
-- Апдейт БД (Команда для добавления колонки model)
-- ============================================================
concommand.Add("swexp_update_chars_db", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    -- Добавляем колонку model в БД (если ее нет)
    MySQLite.query("ALTER TABLE `swexp_characters` ADD COLUMN `model` VARCHAR(255) DEFAULT NULL;")
    if IsValid(ply) then ply:ChatPrint("[SWExp] Колонка model добавлена в БД! Перезапустите сервер.") end
    print("[SWExp] Колонка model добавлена в БД! Перезапустите сервер.")
end)

-- ============================================================
-- Обновление модели (Новая функция для Инвентаря)
-- ============================================================
function SWExp.Chars:UpdateModel(pPlayer, newModel)
    if not IsValid(pPlayer) then return end
    local char = pPlayer.SWExp_ActiveChar
    if not char then return end

    -- Обновляем локально и для UI (F4 меню)
    char.model = newModel
    pPlayer:SetNWString('swexp_model', newModel)

    -- Виртуальный ADMIN-персонаж (id = -1) не хранится в БД — пропускаем запрос
    if tonumber(char.id) == -1 then return end

    -- Обновляем в БД
    MySQLite.query(string.format(
        "UPDATE `swexp_characters` SET model = %s WHERE id = %s AND player_id = %s;",
        MySQLite.SQLStr(newModel),
        MySQLite.SQLStr(char.id),
        MySQLite.SQLStr(pPlayer.SWExp_ID)
    ))
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
                -- Если модель пустая (перс только создан), берем дефолтную для ранга
                if not char.model or char.model == "" or char.model == "NULL" then
                    char.model = SWExp.Chars:GetModelForRank(char['rank'])
                end
            end

            -- Виртуальный ADMIN-персонаж добавляется ТОЛЬКО в локальный список
            -- для отображения в меню выбора. Он никогда не записывается в БД
            -- (id = -1 — признак виртуального персонажа; все DB-операции его игнорируют).
            if pPlayer:IsAdmin() or pPlayer:IsSuperAdmin() then
                table.insert(tRows, {
                    id           = -1,
                    player_id    = -1, -- не реальный player_id — защита от случайной записи
                    clone_number = "####",
                    callsign     = pPlayer.SWExp_RealSteamName or pPlayer:Nick(),
                    ['rank']     = "ADMIN",
                    model        = DEFAULT_MODEL,
                    _virtual     = true, -- маркер: этот объект существует только в памяти
                })
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

    local slots    = pPlayer.SWExp_CharSlots or 1
    local existing = pPlayer.SWExp_Characters or {}
    local realCount = 0
    for _, c in ipairs(existing) do
        if tonumber(c.id) ~= -1 then realCount = realCount + 1 end
    end

    if realCount >= slots then
        if cb then cb(false, 'Нет свободных слотов') end
        return
    end

    sNumber   = string.upper(string.Trim(sNumber   or ''))
    sCallsign = string.upper(string.Trim(sCallsign or ''))

    if sNumber == '' or sCallsign == '' then
        if cb then cb(false, 'Номер и позывной не могут быть пустыми') end
        return
    end

    MySQLite.query(
        string.format('SELECT id FROM `swexp_characters` WHERE clone_number = %s LIMIT 1;',
            MySQLite.SQLStr(sNumber)),
        function(tExist)
            if tExist and #tExist > 0 then
                if cb then cb(false, 'Персонаж с номером ' .. sNumber .. ' уже существует') end
                return
            end

            local startRank = START_RANK
            local startModel = SWExp.Chars:GetModelForRank(startRank)

            MySQLite.query(
                string.format(
                    'INSERT INTO `swexp_characters` (player_id, clone_number, callsign, `rank`, model) VALUES (%s, %s, %s, %s, %s);',
                    MySQLite.SQLStr(playerID),
                    MySQLite.SQLStr(sNumber),
                    MySQLite.SQLStr(sCallsign),
                    MySQLite.SQLStr(startRank),
                    MySQLite.SQLStr(startModel) -- Добавлено сохранение модели при создании
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
-- Удаление и Переименование (оставлено без изменений)
-- ============================================================

function SWExp.Chars:Delete(pPlayer, nCharID, cb)
    if not IsValid(pPlayer) then return end
    if tonumber(nCharID) == -1 then
        if cb then cb(false, 'Нельзя удалить системного персонажа') end
        return
    end

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

function SWExp.Chars:Rename(pPlayer, nCharID, sCallsign, cb)
    if not IsValid(pPlayer) then return end
    if tonumber(nCharID) == -1 then
        if cb then cb(false, 'Нельзя переименовать системного персонажа') end
        return
    end

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

    -- Виртуальный ADMIN-персонаж (id = -1) разрешён только реальным админам.
    -- Выбор этого персонажа не порождает никаких запросов к БД — ни сейчас,
    -- ни через UpdateModel, ни через другие функции (все они проверяют id == -1).
    if tonumber(char.id) == -1 then
        if not (pPlayer:IsAdmin() or pPlayer:IsSuperAdmin()) then
            if cb then cb(false, 'Нет доступа') end
            return
        end
    end

    pPlayer.SWExp_ActiveChar = char

    local mdl = char.model or DEFAULT_MODEL -- Теперь подтягиваем сохраненную

    pPlayer:SetNWString('swexp_model',        mdl)
    pPlayer:SetNWString('swexp_callsign',     char.callsign)
    pPlayer:SetNWString('swexp_clone_number', char.clone_number)
    pPlayer:SetNWString('swexp_rank',         char['rank'])

    local rankShort = SWExp.Ranks and SWExp.Ranks:GetShortName(char['rank']) or char['rank']
    local displayName = string.format('%s %s %s', rankShort, char.clone_number, char.callsign)
    pPlayer.SWExp_DisplayName = displayName

    pPlayer:SetNWString('swexp_display_name', displayName)
    pPlayer:SetNWString('Nick', displayName)

    if SWExp.Config and SWExp.Config.RankArmor then
        local armor = SWExp.Config.RankArmor[char['rank']] or 0
        pPlayer:SetMaxArmor(100)
        pPlayer:SetArmor(armor)
        if SWExp.Armor and SWExp.Armor.ApplyArmorSpeed then
            SWExp.Armor.ApplyArmorSpeed(pPlayer)
        end
    end

    pPlayer:Spawn()
    pPlayer:SetModel(mdl)
    pPlayer:SetupHands()

    hook.Run('SWExp::CharacterSelected', pPlayer, char)
    netstream.Start(pPlayer, 'SWExp::CharSelected', char)

    if cb then cb(true, char) end
end

hook.Add('PlayerSpawn', 'SWExp::RestoreModel', function(pPlayer)
    if not IsValid(pPlayer) then return end
    if not pPlayer.SWExp_ActiveChar then return end

    -- Восстанавливаем именно ту модель, которая сохранена в БД
    local mdl = pPlayer.SWExp_ActiveChar.model or DEFAULT_MODEL
    pPlayer:SetModel(mdl)
    pPlayer:SetupHands()
end)

function SWExp.Chars:GetByID(pPlayer, nCharID)
    for _, c in ipairs(pPlayer.SWExp_Characters or {}) do
        if tonumber(c.id) == tonumber(nCharID) then return c end
    end
    return nil
end

-- Netstream хуки оставлены без изменений
netstream.Hook('SWExp::CreateChar', function(pPlayer, tData)
    if not IsValid(pPlayer) then return end
    if not istable(tData) then return end
    SWExp.Chars:Create(pPlayer, tData.clone_number, tData.callsign, function(bOk, result)
        if bOk then netstream.Start(pPlayer, 'SWExp::OpenCharSelect', pPlayer.SWExp_Characters)
        else netstream.Start(pPlayer, 'SWExp::CharError', result) end
    end)
end)

netstream.Hook('SWExp::ChooseChar', function(pPlayer, nCharID)
    if not IsValid(pPlayer) then return end
    SWExp.Chars:Choose(pPlayer, nCharID)
end)

netstream.Hook('SWExp::DeleteChar', function(pPlayer, nCharID)
    if not IsValid(pPlayer) then return end
    SWExp.Chars:Delete(pPlayer, nCharID, function(bOk, err)
        if bOk then netstream.Start(pPlayer, 'SWExp::OpenCharSelect', pPlayer.SWExp_Characters)
        else netstream.Start(pPlayer, 'SWExp::CharError', err) end
    end)
end)

netstream.Hook('SWExp::RenameChar', function(pPlayer, nCharID, sCallsign)
    if not IsValid(pPlayer) then return end
    SWExp.Chars:Rename(pPlayer, nCharID, sCallsign, function(bOk, result)
        if bOk then netstream.Start(pPlayer, 'SWExp::OpenCharSelect', pPlayer.SWExp_Characters)
        else netstream.Start(pPlayer, 'SWExp::CharError', result) end
    end)
end)

netstream.Hook('SWExp::RequestChars', function(pPlayer)
    if not IsValid(pPlayer) then return end
    SWExp.Chars:Load(pPlayer, function(tChars)
        netstream.Start(pPlayer, 'SWExp::OpenCharSelect', tChars)
    end)
end)

local meta = FindMetaTable('Player')
local oldNick = meta.Nick
local oldName = meta.Name
local oldGetName = meta.GetName

hook.Add('PlayerInitialSpawn', 'SWExp::SaveRealSteamName', function(ply)
    ply.SWExp_RealSteamName = ply:Nick()
end)
 
function meta:Nick() if self.SWExp_DisplayName then return self.SWExp_DisplayName end return oldNick(self) end
function meta:Name() if self.SWExp_DisplayName then return self.SWExp_DisplayName end return oldName(self) end
function meta:GetName() if self.SWExp_DisplayName then return self.SWExp_DisplayName end return oldGetName(self) end
 
-- Радиус слышимости обычного RP-чата (юниты Source).
-- Должен совпадать с RP_PROXIMITY в sv_chat_commands.lua.
local SWEXP_CHAT_PROXIMITY = 700

hook.Add('PlayerSay', 'SWExp::ChatName', function(ply, text, teamChat)
    MsgC(Color(255, 200, 0), '[SWExp][ChatName] ', color_white,
        string.format('hook fired. ply=%s display=%s text=%q',
            IsValid(ply) and ply:Nick() or 'nil',
            tostring(ply and ply.SWExp_DisplayName),
            tostring(text)),
        '\n')

    if not IsValid(ply) or not ply.SWExp_DisplayName then
        MsgC(Color(255, 200, 0), '[SWExp][ChatName] ', color_white,
            '  -> no SWExp_DisplayName, returning nil\n')
        return
    end

    local msg = teamChat and '(TEAM) ' or ''
    msg = msg .. ply.SWExp_DisplayName .. ': ' .. text

    local recipientCount = 0
    if teamChat then
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and p:Team() == ply:Team() then
                p:ChatPrint(msg)
                recipientCount = recipientCount + 1
            end
        end
    else
        local talkerPos = ply:GetPos()
        local maxSqr    = SWEXP_CHAT_PROXIMITY * SWEXP_CHAT_PROXIMITY
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) then
                if p == ply or p:GetPos():DistToSqr(talkerPos) <= maxSqr then
                    p:ChatPrint(msg)
                    recipientCount = recipientCount + 1
                end
            end
        end
    end

    MsgC(Color(255, 200, 0), '[SWExp][ChatName] ', color_white,
        string.format('  -> sent ChatPrint to %d players, returning ""\n',
            recipientCount))

    return ''
end)

hook.Add('PlayerInitialSpawn', 'SWExp::SyncDisplayName', function(ply)
    timer.Simple(1, function()
        if IsValid(ply) and ply.SWExp_DisplayName then ply:SetNWString('SWExp_Nick', ply.SWExp_DisplayName) end
    end)
end)

hook.Add('SWExp::CharacterSelected', 'SWExp::UpdateDisplayNameNW', function(ply, char)
    if IsValid(ply) and ply.SWExp_DisplayName then ply:SetNWString('SWExp_Nick', ply.SWExp_DisplayName) end
end)
