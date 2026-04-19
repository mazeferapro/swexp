-- ============================================================
-- Star Wars: Expedition — Scoreboard (Server)
-- modules/sv_scoreboard.lua
-- 
-- Обработка административных команд через scoreboard
-- Интеграция с CAMI для проверки прав
-- ============================================================

if CLIENT then return end

SWExp.Scoreboard = SWExp.Scoreboard or {}

-- ============================================================
-- РЕГИСТРАЦИЯ CAMI ПРАВ
-- ============================================================

local function RegisterCAMIPrivileges()
    if not CAMI then
        MsgC(Color(255, 136, 0), '[SWExp] ', color_white, 'CAMI not found! Using basic permission checks.\n')
        return
    end

    -- Регистрация прав
    CAMI.RegisterPrivilege({
        Name = 'swexp.scoreboard.openprofile',
        MinAccess = 'admin',
        Description = 'Allows opening player Steam profiles from scoreboard'
    })

    CAMI.RegisterPrivilege({
        Name = 'swexp.scoreboard.bring',
        MinAccess = 'admin',
        Description = 'Allows bringing players to your position'
    })

    CAMI.RegisterPrivilege({
        Name = 'swexp.scoreboard.goto',
        MinAccess = 'admin',
        Description = 'Allows teleporting to players'
    })

    CAMI.RegisterPrivilege({
        Name = 'swexp.scoreboard.editcharacter',
        MinAccess = 'admin',
        Description = 'Allows editing player character data'
    })

    CAMI.RegisterPrivilege({
        Name = 'swexp.scoreboard.editslots',
        MinAccess = 'superadmin',
        Description = 'Allows editing player character slots'
    })

    MsgC(Color(0, 238, 119), '[SWExp] ', color_white, 'CAMI privileges registered for scoreboard.\n')
end

-- Регистрация при инициализации
hook.Add('Initialize', 'SWExp::Scoreboard_RegisterCAMI', RegisterCAMIPrivileges)

-- ============================================================
-- ПРОВЕРКА ПРАВ ДОСТУПА
-- ============================================================

local function HasPermission(ply, privilege)
    if not IsValid(ply) then return false end

    if CAMI then
        local hasAccess = false
        CAMI.PlayerHasAccess(ply, privilege, function(bAccess)
            hasAccess = bAccess
        end)
        return hasAccess
    else
        -- Fallback на стандартные проверки
        if privilege == 'swexp.scoreboard.editslots' then
            return ply:IsSuperAdmin()
        elseif privilege == 'swexp.scoreboard.openprofile' or
               privilege == 'swexp.scoreboard.bring' or
               privilege == 'swexp.scoreboard.goto' or
               privilege == 'swexp.scoreboard.editcharacter' then
            return ply:IsAdmin() or ply:IsSuperAdmin()
        end
        return false
    end
end

-- ============================================================
-- ЛОГИРОВАНИЕ АДМИНИСТРАТИВНЫХ ДЕЙСТВИЙ
-- ============================================================

local function LogAdminAction(admin, action, target, details)
    local logMessage = string.format(
        '[SWExp Admin] %s (%s) %s on %s (%s)%s',
        admin:Nick(),
        admin:SteamID(),
        action,
        target:Nick(),
        target:SteamID(),
        details and (' - ' .. details) or ''
    )

    MsgC(Color(0, 184, 255), logMessage, '\n')

    -- TODO: Добавить запись в БД если нужно
    -- MySQLite.query(...)

    hook.Run('SWExp::AdminAction', admin, action, target, details)
end

-- ============================================================
-- NETSTREAM ОБРАБОТЧИКИ
-- ============================================================

-- ТЕЛЕПОРТИРОВАТЬ К СЕБЕ
netstream.Hook('SWExp::Scoreboard_Bring', function(ply, target)
    if not IsValid(ply) or not IsValid(target) then return end

    if not HasPermission(ply, 'swexp.scoreboard.bring') then
        ply:ChatPrint('[SWExp] You don\'t have permission to bring players!')
        return
    end

    if target == ply then
        ply:ChatPrint('[SWExp] You cannot bring yourself!')
        return
    end

    local oldPos = target:GetPos()

    -- Телепортация
    target:SetPos(ply:GetPos() + ply:GetForward() * 100)
    target:SetEyeAngles(Angle(0, (ply:GetPos() - target:GetPos()):Angle().y, 0))

    -- Уведомления
    ply:ChatPrint(string.format('[SWExp] Brought %s to your position', target:Nick()))
    target:ChatPrint(string.format('[SWExp] You were brought to %s by an administrator', ply:Nick()))

    -- Логирование
    LogAdminAction(ply, 'BRING', target, string.format('From %s', tostring(oldPos)))

    hook.Run('SWExp::PlayerBrought', ply, target, oldPos)
end)

-- ТЕЛЕПОРТИРОВАТЬСЯ К ИГРОКУ
netstream.Hook('SWExp::Scoreboard_Goto', function(ply, target)
    if not IsValid(ply) or not IsValid(target) then return end

    if not HasPermission(ply, 'swexp.scoreboard.goto') then
        ply:ChatPrint('[SWExp] You don\'t have permission to teleport to players!')
        return
    end

    if target == ply then
        ply:ChatPrint('[SWExp] You cannot teleport to yourself!')
        return
    end

    local oldPos = ply:GetPos()

    -- Телепортация
    ply:SetPos(target:GetPos() + target:GetForward() * -100)
    ply:SetEyeAngles(Angle(0, (target:GetPos() - ply:GetPos()):Angle().y, 0))

    -- Уведомление
    ply:ChatPrint(string.format('[SWExp] Teleported to %s', target:Nick()))

    -- Логирование
    LogAdminAction(ply, 'GOTO', target, string.format('From %s', tostring(oldPos)))

    hook.Run('SWExp::AdminGoto', ply, target, oldPos)
end)

-- ИЗМЕНИТЬ ДАННЫЕ ПЕРСОНАЖА
-- Вспомогательная функция для обновления имени над головой (DisplayName)
local function UpdatePlayerDisplayName(target)
    local rank = target:GetNWString('swexp_rank', 'TRP')
    local cloneNumber = target:GetNWString('swexp_clone_number', '0000')
    local callsign = target:GetNWString('swexp_callsign', 'RECRUIT')
    
    local rankShort = SWExp.Ranks and SWExp.Ranks:GetShortName(rank) or rank
    local displayName = string.format('%s %s %s', rankShort, cloneNumber, callsign)
    
    target.SWExp_DisplayName = displayName
    target:SetNWString('swexp_display_name', displayName)
    target:SetNWString('Nick', displayName)
end

-- ============================================================
-- 1. ИЗМЕНИТЬ НОМЕР
-- ============================================================
netstream.Hook('SWExp::Scoreboard_EditNumber', function(ply, data)
    local target = data.player
    if not IsValid(ply) or not IsValid(target) or not HasPermission(ply, 'swexp.scoreboard.editcharacter') then return end

    local cloneNumber = string.upper(string.Trim(data.clone_number or ''))
    if not string.match(cloneNumber, '^[0-9]+$') then return end

    local oldNum = target:GetNWString('swexp_clone_number', 'N/A')
    target:SetNWString('swexp_clone_number', cloneNumber)
    UpdatePlayerDisplayName(target)

    if target.SWExp_ActiveChar then
        MySQLite.query(string.format("UPDATE `swexp_characters` SET clone_number = %s WHERE id = %s AND player_id = %s;",
            MySQLite.SQLStr(cloneNumber), MySQLite.SQLStr(target.SWExp_ActiveChar.id), MySQLite.SQLStr(target.SWExp_ID)))
        target.SWExp_ActiveChar.clone_number = cloneNumber
    end

    ply:ChatPrint(string.format('[SWExp] Номер игрока %s изменен на %s', target:Nick(), cloneNumber))
    LogAdminAction(ply, 'EDIT NUMBER', target, string.format('%s → %s', oldNum, cloneNumber))
end)

-- ============================================================
-- 2. ИЗМЕНИТЬ ПОЗЫВНОЙ
-- ============================================================
netstream.Hook('SWExp::Scoreboard_EditCallsign', function(ply, data)
    local target = data.player
    if not IsValid(ply) or not IsValid(target) or not HasPermission(ply, 'swexp.scoreboard.editcharacter') then return end

    local callsign = string.upper(string.Trim(data.callsign or ''))
    if callsign == '' then return end

    local oldCallsign = target:GetNWString('swexp_callsign', 'N/A')
    target:SetNWString('swexp_callsign', callsign)
    UpdatePlayerDisplayName(target)

    if target.SWExp_ActiveChar then
        MySQLite.query(string.format("UPDATE `swexp_characters` SET callsign = %s WHERE id = %s AND player_id = %s;",
            MySQLite.SQLStr(callsign), MySQLite.SQLStr(target.SWExp_ActiveChar.id), MySQLite.SQLStr(target.SWExp_ID)))
        target.SWExp_ActiveChar.callsign = callsign
    end

    ply:ChatPrint(string.format('[SWExp] Позывной игрока %s изменен на %s', target:Nick(), callsign))
    LogAdminAction(ply, 'EDIT CALLSIGN', target, string.format('%s → %s', oldCallsign, callsign))
end)

-- ============================================================
-- 3. ИЗМЕНИТЬ ЗВАНИЕ
-- ============================================================
netstream.Hook('SWExp::Scoreboard_EditRank', function(ply, data)
    local target = data.player
    if not IsValid(ply) or not IsValid(target) or not HasPermission(ply, 'swexp.scoreboard.editcharacter') then return end

    local rank = string.upper(string.Trim(data.rank or ''))
    if rank == '' then return end

    local oldRank = target:GetNWString('swexp_rank', 'N/A')
    target:SetNWString('swexp_rank', rank)
    UpdatePlayerDisplayName(target)

    if target.SWExp_ActiveChar then
        MySQLite.query(string.format("UPDATE `swexp_characters` SET `rank` = %s WHERE id = %s AND player_id = %s;",
            MySQLite.SQLStr(rank), MySQLite.SQLStr(target.SWExp_ActiveChar.id), MySQLite.SQLStr(target.SWExp_ID)))
        target.SWExp_ActiveChar['rank'] = rank
    end

    ply:ChatPrint(string.format('[SWExp] Звание игрока %s изменено на %s', target:Nick(), rank))
    LogAdminAction(ply, 'EDIT RANK', target, string.format('%s → %s', oldRank, rank))
end)

-- ИЗМЕНИТЬ КОЛИЧЕСТВО СЛОТОВ
netstream.Hook('SWExp::Scoreboard_EditSlots', function(ply, data)
    if not IsValid(ply) or not istable(data) then return end

    local target = data.player
    if not IsValid(target) then return end

    if not HasPermission(ply, 'swexp.scoreboard.editslots') then
        ply:ChatPrint('[SWExp] You don\'t have permission to edit character slots!')
        return
    end

    local newSlots = tonumber(data.slots)
    if not newSlots or newSlots < 1 or newSlots > 10 then
        ply:ChatPrint('[SWExp] Slot count must be between 1 and 10!')
        return
    end

    -- Сохранение старого значения
    local oldSlots = target.SWExp_CharSlots or 1

    -- Обновление
    target.SWExp_CharSlots = newSlots
    
    -- Синхронизация с клиентом
    target:SetNWInt('swexp_character_slots', newSlots)

    -- Обновление в БД
    MySQLite.query(
        string.format(
            'UPDATE `swexp_players` SET character_slots = %d WHERE id = %s;',
            newSlots,
            MySQLite.SQLStr(target.SWExp_ID)
        )
    )

    -- Уведомления
    ply:ChatPrint(string.format('[SWExp] Updated character slots for %s: %d → %d',
        target:Nick(), oldSlots, newSlots))
    target:ChatPrint(string.format('[SWExp] Your character slots have been updated to %d', newSlots))

    -- Логирование
    LogAdminAction(ply, 'EDIT SLOTS', target, string.format('%d → %d', oldSlots, newSlots))

    hook.Run('SWExp::SlotsEdited', ply, target, oldSlots, newSlots)
end)

-- ============================================================
-- КОНСОЛЬНЫЕ КОМАНДЫ
-- ============================================================

-- Команда для установки данных персонажа
concommand.Add('swexp_setcharacter', function(ply, cmd, args)
    if not IsValid(ply) or not HasPermission(ply, 'swexp.scoreboard.editcharacter') then
        if IsValid(ply) then
            ply:ChatPrint('[SWExp] You don\'t have permission to use this command!')
        end
        return
    end

    if #args < 4 then
        ply:ChatPrint('[SWExp] Usage: swexp_setcharacter <player> <clone_number> <callsign> <rank>')
        return
    end

    local target = nil
    for _, p in ipairs(player.GetAll()) do
        if string.find(string.lower(p:Nick()), string.lower(args[1])) then
            target = p
            break
        end
    end

    if not IsValid(target) then
        ply:ChatPrint('[SWExp] Player not found!')
        return
    end

    local cloneNumber = string.upper(args[2])
    local callsign = string.upper(args[3])
    local rank = string.upper(args[4])

    target:SetNWString('swexp_clone_number', cloneNumber)
    target:SetNWString('swexp_callsign', callsign)
    target:SetNWString('swexp_rank', rank)

    ply:ChatPrint(string.format('[SWExp] Set character data for %s', target:Nick()))
    LogAdminAction(ply, 'SET CHARACTER (console)', target,
        string.format('%s, %s, %s', cloneNumber, callsign, rank))
end)

-- Команда для установки слотов
concommand.Add('swexp_setslots', function(ply, cmd, args)
    if not IsValid(ply) or not HasPermission(ply, 'swexp.scoreboard.editslots') then
        if IsValid(ply) then
            ply:ChatPrint('[SWExp] You don\'t have permission to use this command!')
        end
        return
    end

    if #args < 2 then
        ply:ChatPrint('[SWExp] Usage: swexp_setslots <player> <slots>')
        return
    end

    local target = nil
    for _, p in ipairs(player.GetAll()) do
        if string.find(string.lower(p:Nick()), string.lower(args[1])) then
            target = p
            break
        end
    end

    if not IsValid(target) then
        ply:ChatPrint('[SWExp] Player not found!')
        return
    end

    local slots = tonumber(args[2])
    if not slots or slots < 1 or slots > 10 then
        ply:ChatPrint('[SWExp] Slots must be between 1 and 10!')
        return
    end

    target.SWExp_CharSlots = slots
    target:SetNWInt('swexp_character_slots', slots)
    ply:ChatPrint(string.format('[SWExp] Set character slots for %s to %d', target:Nick(), slots))
    LogAdminAction(ply, 'SET SLOTS (console)', target, tostring(slots))
end)

-- Синхронизация слотов при заходе игрока (с ожиданием ответа от БД)
hook.Add('PlayerInitialSpawn', 'SWExp::Scoreboard_SyncSlots', function(ply)
    local timerName = "SWExp_SyncSlots_" .. ply:SteamID64()
    
    -- Проверяем каждую секунду до 30 раз. Как только данные из БД придут — синхронизируем и выключаем таймер.
    timer.Create(timerName, 1, 30, function()
        if IsValid(ply) and ply.SWExp_CharSlots then
            ply:SetNWInt('swexp_character_slots', ply.SWExp_CharSlots)
            timer.Remove(timerName)
        end
    end)
end)

MsgC(Color(190, 252, 3), '[ SWExp ]', color_white, ' Scoreboard (server) загружен.\n')