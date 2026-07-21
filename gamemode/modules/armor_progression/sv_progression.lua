-- modules/armor_progression/sv_progression.lua
-- Серверная логика прокачки брони:
--   - база данных (swexp_armor_progression)
--   - начисление XP за убийства
--   - повышение уровня и применение бонусов
--   - синхронизация ArcCW_AttInv (инвентарь обвесов)
--   - синхронизация данных прокачки с клиентом

if CLIENT then return end

SWExp.ArmorProgression = SWExp.ArmorProgression or {}

-- [steamID][charID][armorClass] = {xp=N, level=N}
SWExp.ArmorProgression.PlayerData = {}

-- ============================================================
-- ИНИЦИАЛИЗАЦИЯ ТАБЛИЦЫ БД
-- ============================================================

hook.Add("DatabaseInitialized", "SWExp::ArmorProgression_DBInit", function()
    MySQLite.query([[
        CREATE TABLE IF NOT EXISTS `swexp_armor_progression` (
            `character_id` INTEGER NOT NULL,
            `armor_class`  VARCHAR(50) NOT NULL,
            `xp`           INTEGER DEFAULT 0,
            `level`        INTEGER DEFAULT 1,
            PRIMARY KEY (`character_id`, `armor_class`)
        );
    ]])
    MsgC(Color(190, 252, 3), "[ SWExp ][ Прокачка ]", color_white,
        " Таблица swexp_armor_progression проверена/создана.\n")
end)

-- ============================================================
-- ЗАГРУЗКА ИЗ БД
-- ============================================================

function SWExp.ArmorProgression:Load(pPlayer, cb)
    local charID = SWExp.Inventory:GetCharacterID(pPlayer)
    if not charID then
        if cb then cb() end
        return
    end

    local steamID = pPlayer:SteamID64()

    MySQLite.query(string.format(
        "SELECT `armor_class`, `xp`, `level` FROM `swexp_armor_progression` WHERE `character_id` = %d;",
        charID
    ), function(rows)
        if not IsValid(pPlayer) then return end

        self.PlayerData[steamID]         = self.PlayerData[steamID] or {}
        self.PlayerData[steamID][charID] = {}

        if rows then
            for _, row in ipairs(rows) do
                self.PlayerData[steamID][charID][row.armor_class] = {
                    xp    = tonumber(row.xp)    or 0,
                    level = tonumber(row.level) or 1,
                }
            end
        end

        if cb then cb() end
    end)
end

-- ============================================================
-- СОХРАНЕНИЕ ОДНОЙ ЗАПИСИ
-- ============================================================

function SWExp.ArmorProgression:SaveClass(charID, armorClass, xp, level)
    MySQLite.query(string.format(
        "REPLACE INTO `swexp_armor_progression` (`character_id`, `armor_class`, `xp`, `level`) VALUES (%d, %s, %d, %d);",
        charID,
        MySQLite.SQLStr(armorClass),
        xp,
        level
    ))
end

-- ============================================================
-- ПОЛУЧЕНИЕ ДАННЫХ ИГРОКА
-- ============================================================

function SWExp.ArmorProgression:GetData(pPlayer, armorClass)
    local charID = SWExp.Inventory:GetCharacterID(pPlayer)
    if not charID then return nil end

    local steamID = pPlayer:SteamID64()
    local charData = self.PlayerData[steamID] and self.PlayerData[steamID][charID]
    if not charData then return nil end

    return charData[armorClass] or { xp = 0, level = 1 }
end

-- ============================================================
-- НАЧИСЛЕНИЕ XP
-- Возвращает: leveledUp (bool), newLevel (int)
-- ============================================================

function SWExp.ArmorProgression:AddXP(pPlayer, armorClass, amount)
    local charID = SWExp.Inventory:GetCharacterID(pPlayer)
    if not charID then return false, 1 end

    local steamID = pPlayer:SteamID64()
    self.PlayerData[steamID]         = self.PlayerData[steamID] or {}
    self.PlayerData[steamID][charID] = self.PlayerData[steamID][charID] or {}

    local data = self.PlayerData[steamID][charID][armorClass]
        or { xp = 0, level = 1 }
    self.PlayerData[steamID][charID][armorClass] = data

    -- Не начисляем сверх максимума
    if data.level >= self.MaxLevel then return false, data.level end

    data.xp    = data.xp + amount
    local newLevel = self:GetLevelForXP(data.xp)
    local leveledUp = newLevel > data.level
    data.level = newLevel

    self:SaveClass(charID, armorClass, data.xp, data.level)
    self:SyncToClient(pPlayer)

    return leveledUp, newLevel
end

-- ============================================================
-- ПРИМЕНЕНИЕ БОНУСОВ ОТ ПРОКАЧКИ
-- Вызывается при экипировке брони, спавне и повышении уровня.
-- ============================================================

function SWExp.ArmorProgression:ApplyBonuses(pPlayer)
    if not IsValid(pPlayer) then return end

    local charID = SWExp.Inventory:GetCharacterID(pPlayer)
    if not charID then return end

    local steamID = pPlayer:SteamID64()
    local equip   = SWExp.Inventory.PlayerEquipment[steamID]
                   and SWExp.Inventory.PlayerEquipment[steamID][charID]
    local armorItem = equip and equip["armor"] and equip["armor"][1]

    if not armorItem then
        -- Броня снята: сброс всех бонусов
        pPlayer.SWExp_SpeedBonus = 0
        pPlayer:SetMaxHealth(100)
        if pPlayer:Health() > 100 then pPlayer:SetHealth(100) end
        if SWExp.Armor and SWExp.Armor.ApplyArmorSpeed then
            SWExp.Armor.ApplyArmorSpeed(pPlayer)
        end
        return
    end

    local armorData  = SWExp.Inventory:GetItemData(armorItem.itemID)
    if not armorData or not armorData.armorClass then return end

    local armorClass = armorData.armorClass
    local data = self:GetData(pPlayer, armorClass) or { level = 1, xp = 0 }
    local cfg  = self:GetLevelConfig(armorClass, data.level)
    if not cfg then return end

    -- Максимальное HP
    local newMaxHP = cfg.maxHP or 100
    pPlayer:SetMaxHealth(newMaxHP)
    if pPlayer:Health() > newMaxHP then pPlayer:SetHealth(newMaxHP) end

    -- Бонус к скорости (уменьшает штраф от брони)
    pPlayer.SWExp_SpeedBonus = cfg.speedBonus or 0
    if SWExp.Armor and SWExp.Armor.ApplyArmorSpeed then
        SWExp.Armor.ApplyArmorSpeed(pPlayer)
    end

    -- Бонус к броне (сверх значения предмета, кэп 75)
    local baseArmor  = math.floor((armorData.armorReduction or 0) * 100)
    local finalArmor = math.min(baseArmor + (cfg.armorBonus or 0), 75)
    pPlayer:SetArmor(finalArmor)
end

-- ============================================================
-- СИНХРОНИЗАЦИЯ ArcCW_AttInv
-- Источник 1: предметы в SWExp-инвентаре с полем attName
-- Источник 2: перки, разблокированные прогрессией
-- ============================================================

function SWExp.ArmorProgression:RebuildArcCWAttInv(pPlayer)
    if not IsValid(pPlayer) then return end
    if not ArcCW then return end

    local charID = SWExp.Inventory:GetCharacterID(pPlayer)
    if not charID then return end

    local steamID = pPlayer:SteamID64()

    -- Полный сброс
    pPlayer.ArcCW_AttInv = {}

    -- 1. Предметы в сетке инвентаря с полем attName
    local inv = SWExp.Inventory.PlayerInventories[steamID]
               and SWExp.Inventory.PlayerInventories[steamID][charID]
    if inv then
        for _, item in pairs(inv.items or {}) do
            local itemData = SWExp.Inventory:GetItemData(item.itemID)
            if itemData and itemData.attName
               and ArcCW.AttachmentTable[itemData.attName] then
                ArcCW:PlayerGiveAtt(pPlayer, itemData.attName, item.amount or 1)
            end
        end
    end

    -- 2. Предметы в слотах экипировки с полем attName
    local equip = SWExp.Inventory.PlayerEquipment[steamID]
                 and SWExp.Inventory.PlayerEquipment[steamID][charID]
    if equip then
        for _, slots in pairs(equip) do
            for _, item in pairs(slots) do
                if item and item.itemID then
                    local itemData = SWExp.Inventory:GetItemData(item.itemID)
                    if itemData and itemData.attName
                       and ArcCW.AttachmentTable[itemData.attName] then
                        ArcCW:PlayerGiveAtt(pPlayer, itemData.attName, item.amount or 1)
                    end
                end
            end
        end
    end

    -- 3. Перки от прокачки (все классы, все накопленные уровни)
    local charData = self.PlayerData[steamID] and self.PlayerData[steamID][charID]
    if charData then
        for armorClass, data in pairs(charData) do
            local unlockedPerks = self:GetUnlockedPerks(armorClass, data.level or 1)
            for perkName in pairs(unlockedPerks) do
                if ArcCW.AttachmentTable[perkName] then
                    -- Даём только если ещё нет (чтобы не накапливать дубли)
                    if (pPlayer.ArcCW_AttInv[perkName] or 0) < 1 then
                        ArcCW:PlayerGiveAtt(pPlayer, perkName, 1)
                    end
                end
            end
        end
    end

    -- Отправляем клиенту
    ArcCW:PlayerSendAttInv(pPlayer)
end

-- ============================================================
-- СИНХРОНИЗАЦИЯ ПРОГРЕССИИ С КЛИЕНТОМ
-- ============================================================

function SWExp.ArmorProgression:SyncToClient(pPlayer)
    if not IsValid(pPlayer) then return end

    local charID = SWExp.Inventory:GetCharacterID(pPlayer)
    if not charID then return end

    local steamID = pPlayer:SteamID64()
    local data    = self.PlayerData[steamID] and self.PlayerData[steamID][charID] or {}

    netstream.Start(pPlayer, "SWExp::ArmorProgressionSync", data)
end

-- ============================================================
-- ХУКИ
-- ============================================================

-- Загрузка прогрессии при выборе персонажа
-- Выполняется ПОСЛЕ загрузки инвентаря (CharacterSelected)
hook.Add("SWExp::CharacterSelected", "SWExp::ArmorProgression_Load", function(pPlayer)
    if not IsValid(pPlayer) then return end

    -- Небольшая задержка: даём инвентарю загрузиться из БД первым
    timer.Simple(0.3, function()
        if not IsValid(pPlayer) then return end
        SWExp.ArmorProgression:Load(pPlayer, function()
            if not IsValid(pPlayer) then return end
            SWExp.ArmorProgression:ApplyBonuses(pPlayer)
            SWExp.ArmorProgression:RebuildArcCWAttInv(pPlayer)
            SWExp.ArmorProgression:SyncToClient(pPlayer)
        end)
    end)
end)

-- ============================================================
-- ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ: начислить XP убийцу (игроку)
-- amount — количество XP (рассчитывается снаружи)
-- ============================================================

local function GiveKillXP(attacker, amount)
    if not IsValid(attacker) or not attacker:IsPlayer() then return end
    if not amount or amount <= 0 then return end

    local charID = SWExp.Inventory:GetCharacterID(attacker)
    if not charID then return end

    local steamID   = attacker:SteamID64()
    local equip     = SWExp.Inventory.PlayerEquipment[steamID]
                      and SWExp.Inventory.PlayerEquipment[steamID][charID]
    local armorItem = equip and equip["armor"] and equip["armor"][1]
    if not armorItem then return end   -- без брони XP не начисляется

    local armorData = SWExp.Inventory:GetItemData(armorItem.itemID)
    if not armorData or not armorData.armorClass then return end

    local armorClass          = armorData.armorClass
    local leveledUp, newLevel = SWExp.ArmorProgression:AddXP(attacker, armorClass, amount)

    if not leveledUp then return end

    -- Применяем новые бонусы
    SWExp.ArmorProgression:ApplyBonuses(attacker)
    SWExp.ArmorProgression:RebuildArcCWAttInv(attacker)

    -- Уведомление о повышении уровня
    local className = SWExp.ArmorProgression.ClassNames[armorClass] or armorClass
    local levelData = SWExp.ArmorProgression.Levels[newLevel]
    local levelName = levelData and levelData.name or ("Уровень " .. newLevel)

    attacker:ChatPrint(string.format(
        "[Прокачка] %s — %s (Ур. %d)!",
        className, levelName, newLevel))

    -- Если разблокировали перк — дополнительное сообщение
    local cfg = SWExp.ArmorProgression:GetLevelConfig(armorClass, newLevel)
    if cfg and cfg.perk and ArcCW and ArcCW.AttachmentTable[cfg.perk] then
        local perkName = ArcCW.AttachmentTable[cfg.perk].PrintName or cfg.perk
        attacker:ChatPrint(string.format(
            "[Прокачка] Разблокирован перк: %s", perkName))
    end
end

-- XP за убийство другого ИГРОКА (фиксированный XPPerKill)
hook.Add("PlayerDeath", "SWExp::ArmorProgression_XP", function(victim, inflictor, attacker)
    if not IsValid(attacker) or attacker == victim then return end
    GiveKillXP(attacker, SWExp.ArmorProgression.XPPerKill)
end)

-- XP за убийство ЛЮБОГО NPC — зависит от его максимального HP
-- Формула: XP = max(1, floor(maxHP / 10))
-- Примеры: maxHP 50 → 5 XP, maxHP 200 → 20 XP, maxHP 1000 → 100 XP
hook.Add("OnNPCKilled", "SWExp::ArmorProgression_NPC_XP", function(npc, attacker, inflictor)
    local maxHP = npc:GetMaxHealth()
    if maxHP <= 0 then maxHP = npc:Health() end   -- запасной вариант
    local xp = math.max(1, math.floor(maxHP / 10))

    -- attacker может быть игроком напрямую или снарядом/оружием — ищем владельца
    local killer = attacker
    if IsValid(killer) and not killer:IsPlayer() then
        killer = killer.GetOwner and killer:GetOwner() or NULL
    end

    GiveKillXP(killer, xp)
end)

-- Применение бонусов при экипировке брони
hook.Add("SWExp::ArmorEquipped", "SWExp::ArmorProgression_OnEquip", function(pPlayer, armorData)
    -- Обновляем NW-переменную класса (нужна клиентскому HUD)
    pPlayer:SetNWString("SWExp_ArmorClass", armorData and armorData.armorClass or "")
    timer.Simple(0.1, function()
        if IsValid(pPlayer) then
            SWExp.ArmorProgression:ApplyBonuses(pPlayer)
        end
    end)
end)

-- Сброс бонусов при снятии брони
hook.Add("SWExp::ArmorUnequipped", "SWExp::ArmorProgression_OnUnequip", function(pPlayer)
    pPlayer:SetNWString("SWExp_ArmorClass", "")
    pPlayer.SWExp_SpeedBonus = 0
    pPlayer:SetMaxHealth(100)
    if pPlayer:Health() > 100 then pPlayer:SetHealth(100) end
    if SWExp.Armor and SWExp.Armor.ApplyArmorSpeed then
        SWExp.Armor.ApplyArmorSpeed(pPlayer)
    end
end)

-- Восстановление бонусов после спавна (броня уже восстановлена ApplyEquippedArmor)
hook.Add("SWExp::ArmorRestored", "SWExp::ArmorProgression_OnRestore", function(pPlayer)
    if not IsValid(pPlayer) then return end

    -- Выставляем NW-класс (броня уже надета, читаем из экипировки)
    local charID  = SWExp.Inventory:GetCharacterID(pPlayer)
    local steamID = pPlayer:SteamID64()
    if charID then
        local equip     = SWExp.Inventory.PlayerEquipment[steamID]
                         and SWExp.Inventory.PlayerEquipment[steamID][charID]
        local armorItem = equip and equip["armor"] and equip["armor"][1]
        if armorItem then
            local armorData = SWExp.Inventory:GetItemData(armorItem.itemID)
            pPlayer:SetNWString("SWExp_ArmorClass",
                armorData and armorData.armorClass or "")
        end
    end

    timer.Simple(0.15, function()
        if IsValid(pPlayer) then
            SWExp.ArmorProgression:ApplyBonuses(pPlayer)
        end
    end)
end)

-- Пересборка ArcCW_AttInv при изменении инвентаря
hook.Add("SWExp::InventoryChanged", "SWExp::ArmorProgression_ArcCWSync", function(pPlayer)
    timer.Simple(0, function()
        if IsValid(pPlayer) then
            SWExp.ArmorProgression:RebuildArcCWAttInv(pPlayer)
        end
    end)
end)

-- Очистка при дисконнекте
hook.Add("PlayerDisconnected", "SWExp::ArmorProgression_Cleanup", function(pPlayer)
    SWExp.ArmorProgression.PlayerData[pPlayer:SteamID64()] = nil
end)

-- ============================================================
-- ADMIN КОМАНДЫ
-- ============================================================

-- Выдать XP: swexp_prog_givexp <ник> <класс> [количество]
concommand.Add("swexp_prog_givexp", function(ply, _, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end

    local targetName = args[1]
    local armorClass = args[2]
    local amount     = tonumber(args[3]) or 100

    if not targetName or not armorClass then
        print("[Прокачка] Использование: swexp_prog_givexp <ник> <класс> [xp]")
        return
    end

    for _, p in ipairs(player.GetAll()) do
        if string.find(string.lower(p:Nick()), string.lower(targetName), 1, true) then
            local leveledUp, newLevel = SWExp.ArmorProgression:AddXP(p, armorClass, amount)
            if leveledUp then
                SWExp.ArmorProgression:ApplyBonuses(p)
                SWExp.ArmorProgression:RebuildArcCWAttInv(p)
            end
            MsgC(Color(190, 252, 3), "[Прокачка] ", color_white,
                string.format("Выдано %d XP (%s) → %s | Level up: %s (Ур. %d)\n",
                    amount, armorClass, p:Nick(), tostring(leveledUp), newLevel))
            return
        end
    end

    MsgC(Color(255, 80, 80), "[Прокачка] Игрок не найден: " .. tostring(targetName) .. "\n")
end)

-- Сброс прокачки: swexp_prog_reset <ник> [класс]
concommand.Add("swexp_prog_reset", function(ply, _, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end

    local targetName = args[1]
    local armorClass = args[2]  -- nil = сброс всех классов

    if not targetName then
        print("[Прокачка] Использование: swexp_prog_reset <ник> [класс]")
        return
    end

    for _, p in ipairs(player.GetAll()) do
        if string.find(string.lower(p:Nick()), string.lower(targetName), 1, true) then
            local charID  = SWExp.Inventory:GetCharacterID(p)
            local steamID = p:SteamID64()
            if not charID then
                MsgC(Color(255, 80, 80), "[Прокачка] У игрока нет активного персонажа.\n")
                return
            end

            if armorClass then
                -- Сброс одного класса
                if SWExp.ArmorProgression.PlayerData[steamID]
                   and SWExp.ArmorProgression.PlayerData[steamID][charID] then
                    SWExp.ArmorProgression.PlayerData[steamID][charID][armorClass] = { xp = 0, level = 1 }
                end
                SWExp.ArmorProgression:SaveClass(charID, armorClass, 0, 1)
            else
                -- Сброс всех классов
                SWExp.ArmorProgression.PlayerData[steamID][charID] = {}
                MySQLite.query(string.format(
                    "DELETE FROM `swexp_armor_progression` WHERE `character_id` = %d;", charID))
            end

            SWExp.ArmorProgression:ApplyBonuses(p)
            SWExp.ArmorProgression:RebuildArcCWAttInv(p)
            SWExp.ArmorProgression:SyncToClient(p)

            MsgC(Color(190, 252, 3), "[Прокачка] ", color_white,
                string.format("Прокачка %s сброшена для %s\n",
                    armorClass or "всех классов", p:Nick()))
            return
        end
    end

    MsgC(Color(255, 80, 80), "[Прокачка] Игрок не найден: " .. tostring(targetName) .. "\n")
end)

-- Информация о прокачке: swexp_prog_info [ник]
concommand.Add("swexp_prog_info", function(ply, _, args)
    if IsValid(ply) and not ply:IsAdmin() then return end

    local targetName = args[1]

    for _, p in ipairs(player.GetAll()) do
        if not targetName
           or string.find(string.lower(p:Nick()), string.lower(targetName), 1, true) then
            local charID  = SWExp.Inventory:GetCharacterID(p)
            local steamID = p:SteamID64()
            local data    = SWExp.ArmorProgression.PlayerData[steamID]
                           and SWExp.ArmorProgression.PlayerData[steamID][charID]

            MsgC(Color(190, 252, 3), "[Прокачка] Игрок: ", color_white, p:Nick(), "\n")
            if data and next(data) then
                for cls, d in pairs(data) do
                    local className = SWExp.ArmorProgression.ClassNames[cls] or cls
                    MsgC(color_white, string.format(
                        "  %-12s Ур. %d | XP: %d\n", className, d.level, d.xp))
                end
            else
                MsgC(color_white, "  нет данных прокачки\n")
            end
        end
    end
end)

MsgC(Color(190, 252, 3), "[ SWExp ]", color_white, " Модуль прокачки брони (server) загружен.\n")
