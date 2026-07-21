-- ============================================================
-- modules/donate/sv_donate_shop.lua
-- Донат-магазин — серверная часть
--
-- КАК РАБОТАЕТ:
--   1. Игрок покупает пак (например "Лёгкая броня — Альт. скин").
--   2. Пак сохраняется в swexp_donate_charmodel (character_id → item_id).
--   3. Когда броня надевается (SWExp::ArmorEquipped):
--      - Берём playerModel брони из itemData
--      - Ищем у игрока пак с pack.replaces == playerModel
--      - Если нашли → SetModel(pack.model) вместо стандартной модели
--   4. Броня снята → SWExp::ArmorUnequipped → sv_inventory.lua сам
--      восстанавливает cadet.mdl, мы ничего не делаем.
-- ============================================================

if CLIENT then return end

SWExp.DonateShop = SWExp.DonateShop or {}

-- ============================================================
-- ИНИЦИАЛИЗАЦИЯ БД
-- ============================================================

hook.Add('DatabaseInitialized', 'SWExp::DonateShop_DBInit', function()
    MySQLite.query([[
        CREATE TABLE IF NOT EXISTS `swexp_donate_inventory` (
            `id`           INT AUTO_INCREMENT PRIMARY KEY,
            `player_id`    INT NOT NULL,
            `item_id`      VARCHAR(128) NOT NULL,
            `purchased_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX (`player_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
    ]], function()
        MySQLite.query([[
            CREATE TABLE IF NOT EXISTS `swexp_donate_charmodel` (
                `character_id` INT NOT NULL,
                `item_id`      VARCHAR(128) NOT NULL,
                PRIMARY KEY (`character_id`, `item_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
        ]], function()
            print('[SWExp.DonateShop] Таблицы инициализированы.')
        end)
    end)
end)

-- ============================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ============================================================

local function GetInventory(playerID, cb)
    MySQLite.query(
        string.format('SELECT `item_id` FROM `swexp_donate_inventory` WHERE `player_id` = %d;', playerID),
        function(rows)
            local list = {}
            if rows then for _, r in ipairs(rows) do list[#list + 1] = r.item_id end end
            cb(list)
        end,
        function(err)
            print('[SWExp.DonateShop] Ошибка GetInventory: ' .. tostring(err))
            cb({})
            return true
        end
    )
end

-- Все активные паки персонажа (может быть несколько — по одному на тип брони)
local function GetCharModels(charID, cb)
    MySQLite.query(
        string.format('SELECT `item_id` FROM `swexp_donate_charmodel` WHERE `character_id` = %d;', charID),
        function(rows)
            local list = {}
            if rows then for _, r in ipairs(rows) do list[#list + 1] = r.item_id end end
            cb(list)
        end,
        function(err)
            print('[SWExp.DonateShop] Ошибка GetCharModels: ' .. tostring(err))
            cb({})
            return true
        end
    )
end

-- ============================================================
-- ПРИМЕНЕНИЕ МОДЕЛИ-ОВЕРРАЙДА
-- Вызывается ПОСЛЕ надевания брони.
-- Ищет пак с pack.replaces == armorPlayerModel и применяет pack.model.
-- ============================================================

function SWExp.DonateShop.ApplyArmorModelOverride(pPlayer, armorItemData)
    if not IsValid(pPlayer) then return end

    local char = pPlayer.SWExp_ActiveChar
    if not char or tonumber(char.id) == -1 then return end
    local charID = tonumber(char.id)

    -- Модель брони из конфига предмета
    local armorModel = armorItemData and armorItemData.playerModel
    if not armorModel then return end

    GetCharModels(charID, function(equippedPacks)
        if not IsValid(pPlayer) then return end

        -- Перебираем активные паки — ищем тот, что перекрывает эту модель брони
        for _, itemID in ipairs(equippedPacks) do
            local pack = SWExp.DonateShop:GetItem(itemID)
            if pack and pack.type == 'model_pack' and pack.replaces == armorModel then
                pPlayer:SetModel(pack.model)
                print(string.format('[SWExp.DonateShop] %s: модель брони %s → %s',
                    pPlayer:Nick(), armorModel, pack.model))
                return
            end
        end
        -- Пака нет — оставляем модель брони без изменений
    end)
end

-- ============================================================
-- ХУКИ
-- ============================================================

-- Броня надета: стандартная модель уже установлена sv_inventory.lua →
-- сразу проверяем наш пак и при необходимости перекрываем.
hook.Add('SWExp::ArmorEquipped', 'SWExp::DonateShop_ArmorOn', function(pPlayer, itemData)
    timer.Simple(0.05, function()
        SWExp.DonateShop.ApplyArmorModelOverride(pPlayer, itemData)
    end)
end)

-- При выборе персонажа броня восстанавливается асинхронно через
-- ApplyEquippedArmor → ждём и перепроверяем модель.
hook.Add('SWExp::CharacterSelected', 'SWExp::DonateShop_CharSelect', function(pPlayer)
    timer.Simple(1.5, function()
        if not IsValid(pPlayer) then return end

        local char = pPlayer.SWExp_ActiveChar
        if not char or tonumber(char.id) == -1 then return end
        local charID  = tonumber(char.id)
        local steamID = pPlayer:SteamID64()

        -- Проверяем надета ли броня
        if not (SWExp.Inventory and SWExp.Inventory.PlayerEquipment) then return end
        local eq = SWExp.Inventory.PlayerEquipment[steamID]
        if not (eq and eq[charID] and eq[charID]['armor'] and eq[charID]['armor'][1]) then return end

        local armorSlot = eq[charID]['armor'][1]
        local itemData  = SWExp.Inventory:GetItemData(armorSlot.itemID)
        SWExp.DonateShop.ApplyArmorModelOverride(pPlayer, itemData)
    end)
end)

-- ============================================================
-- NETSTREAM: запрос данных при открытии меню
-- ============================================================

netstream.Hook('SWExp::DonateShop_RequestData', function(pPlayer)
    if not IsValid(pPlayer) then return end
    local playerID = pPlayer.SWExp_ID
    if not playerID then return end

    GetInventory(playerID, function(ownedList)
        if not IsValid(pPlayer) then return end

        local char   = pPlayer.SWExp_ActiveChar
        local charID = char and tonumber(char.id)

        local function Send(activePacks)
            netstream.Start(pPlayer, 'SWExp::DonateShop_Data', {
                currency    = pPlayer.SWExp_DonateCurrency or 0,
                inventory   = ownedList,
                activePacks = activePacks,   -- список item_id надетых паков
            })
        end

        if charID and charID ~= -1 then
            GetCharModels(charID, function(packs)
                if IsValid(pPlayer) then Send(packs) end
            end)
        else
            Send({})
        end
    end)
end)

-- ============================================================
-- NETSTREAM: покупка товара
-- ============================================================

netstream.Hook('SWExp::DonateShop_Buy', function(pPlayer, itemID)
    if not IsValid(pPlayer) then return end
    if type(itemID) ~= 'string' then return end

    local itemData = SWExp.DonateShop:GetItem(itemID)
    if not itemData then
        netstream.Start(pPlayer, 'SWExp::DonateShop_BuyResult', { ok = false, msg = 'Товар не найден.' })
        return
    end

    local playerID = pPlayer.SWExp_ID
    if not playerID then return end

    local currency = pPlayer.SWExp_DonateCurrency or 0
    if currency < itemData.price then
        netstream.Start(pPlayer, 'SWExp::DonateShop_BuyResult', { ok = false, msg = 'Недостаточно донат-монет.' })
        return
    end

    if not itemData.stackable then
        MySQLite.query(
            string.format(
                'SELECT `id` FROM `swexp_donate_inventory` WHERE `player_id` = %d AND `item_id` = %s LIMIT 1;',
                playerID, MySQLite.SQLStr(itemID)
            ),
            function(rows)
                if not IsValid(pPlayer) then return end
                if rows and rows[1] then
                    netstream.Start(pPlayer, 'SWExp::DonateShop_BuyResult', { ok = false, msg = 'Вы уже купили этот товар.' })
                    return
                end
                SWExp.DonateShop._CompletePurchase(pPlayer, playerID, itemData)
            end,
            function(err)
                print('[SWExp.DonateShop] Ошибка проверки дубликата: ' .. tostring(err))
                return true
            end
        )
    else
        SWExp.DonateShop._CompletePurchase(pPlayer, playerID, itemData)
    end
end)

function SWExp.DonateShop._CompletePurchase(pPlayer, playerID, itemData)
    local newCurrency = (pPlayer.SWExp_DonateCurrency or 0) - itemData.price
    pPlayer.SWExp_DonateCurrency = newCurrency

    MySQLite.query(string.format(
        'UPDATE `swexp_players` SET `donate_currency` = %d WHERE `id` = %d;',
        newCurrency, playerID
    ))

    if itemData.type == 'character_slot' then
        pPlayer.SWExp_CharSlots = (pPlayer.SWExp_CharSlots or 1) + 1
        MySQLite.query(string.format(
            'UPDATE `swexp_players` SET `character_slots` = `character_slots` + 1 WHERE `id` = %d;',
            playerID
        ))
        pPlayer:SetNWInt('swexp_character_slots', pPlayer.SWExp_CharSlots)
    end

    MySQLite.query(
        string.format(
            'INSERT INTO `swexp_donate_inventory` (`player_id`, `item_id`) VALUES (%d, %s);',
            playerID, MySQLite.SQLStr(itemData.id)
        ),
        function()
            if not IsValid(pPlayer) then return end
            netstream.Start(pPlayer, 'SWExp::DonateShop_BuyResult', {
                ok          = true,
                msg         = 'Куплено: ' .. itemData.name,
                itemID      = itemData.id,
                newCurrency = newCurrency,
            })
            print(string.format('[SWExp.DonateShop] %s купил "%s" за %d монет (остаток: %d)',
                pPlayer:Nick(), itemData.name, itemData.price, newCurrency))
        end,
        function(err)
            print('[SWExp.DonateShop] Ошибка записи покупки: ' .. tostring(err))
            pPlayer.SWExp_DonateCurrency = (pPlayer.SWExp_DonateCurrency or 0) + itemData.price
            netstream.Start(pPlayer, 'SWExp::DonateShop_BuyResult', { ok = false, msg = 'Ошибка сервера.' })
            return true
        end
    )
end

-- ============================================================
-- NETSTREAM: экипировка / снятие пака
-- ============================================================

netstream.Hook('SWExp::DonateShop_EquipModel', function(pPlayer, data)
    if not IsValid(pPlayer) then return end
    if type(data) ~= 'table' then return end

    local itemID  = data.itemID
    local doEquip = data.equip

    if type(itemID) ~= 'string' then return end

    local char = pPlayer.SWExp_ActiveChar
    if not char or tonumber(char.id) == -1 then
        netstream.Start(pPlayer, 'SWExp::DonateShop_EquipResult',
            { ok = false, msg = 'Нет активного персонажа.' })
        return
    end

    local charID   = tonumber(char.id)
    local playerID = pPlayer.SWExp_ID

    if doEquip then
        -- Проверяем что куплен
        MySQLite.query(
            string.format(
                'SELECT `id` FROM `swexp_donate_inventory` WHERE `player_id` = %d AND `item_id` = %s LIMIT 1;',
                playerID, MySQLite.SQLStr(itemID)
            ),
            function(rows)
                if not IsValid(pPlayer) then return end
                if not rows or not rows[1] then
                    netstream.Start(pPlayer, 'SWExp::DonateShop_EquipResult',
                        { ok = false, msg = 'Предмет не в инвентаре.' })
                    return
                end

                -- Проверяем: нет ли уже надетого пака с тем же replaces
                local newPack = SWExp.DonateShop:GetItem(itemID)
                local conflictID = nil   -- itemID конфликтующего пака (если есть)

                if newPack and newPack.replaces then
                    GetCharModels(charID, function(equippedPacks)
                        if not IsValid(pPlayer) then return end

                        for _, eqID in ipairs(equippedPacks) do
                            if eqID ~= itemID then
                                local eqPack = SWExp.DonateShop:GetItem(eqID)
                                if eqPack and eqPack.replaces == newPack.replaces then
                                    conflictID = eqID
                                    break
                                end
                            end
                        end

                        -- Если есть конфликт — сначала снимаем старый пак
                        local function DoInsert()
                            MySQLite.query(
                                string.format(
                                    'INSERT IGNORE INTO `swexp_donate_charmodel` (`character_id`, `item_id`) VALUES (%d, %s);',
                                    charID, MySQLite.SQLStr(itemID)
                                ),
                                function()
                                    if not IsValid(pPlayer) then return end

                                    -- Немедленно применяем если броня надета
                                    local steamID = pPlayer:SteamID64()
                                    if SWExp.Inventory and SWExp.Inventory.PlayerEquipment then
                                        local eq = SWExp.Inventory.PlayerEquipment[steamID]
                                        if eq and eq[charID] and eq[charID]['armor'] and eq[charID]['armor'][1] then
                                            local armorSlot = eq[charID]['armor'][1]
                                            local aData = SWExp.Inventory:GetItemData(armorSlot.itemID)
                                            SWExp.DonateShop.ApplyArmorModelOverride(pPlayer, aData)
                                        end
                                    end

                                    netstream.Start(pPlayer, 'SWExp::DonateShop_EquipResult',
                                        { ok = true, itemID = itemID, equipped = true, replacedID = conflictID })
                                end,
                                function(err)
                                    print('[SWExp.DonateShop] Ошибка экипировки: ' .. tostring(err))
                                    return true
                                end
                            )
                        end

                        if conflictID then
                            -- Удаляем конфликтующий пак перед вставкой нового
                            MySQLite.query(
                                string.format(
                                    'DELETE FROM `swexp_donate_charmodel` WHERE `character_id` = %d AND `item_id` = %s;',
                                    charID, MySQLite.SQLStr(conflictID)
                                ),
                                function()
                                    if IsValid(pPlayer) then DoInsert() end
                                end,
                                function(err)
                                    print('[SWExp.DonateShop] Ошибка снятия конфликта: ' .. tostring(err))
                                    return true
                                end
                            )
                        else
                            DoInsert()
                        end
                    end)
                else
                    -- Пак без replaces (или не найден) — просто вставляем
                    MySQLite.query(
                        string.format(
                            'INSERT IGNORE INTO `swexp_donate_charmodel` (`character_id`, `item_id`) VALUES (%d, %s);',
                            charID, MySQLite.SQLStr(itemID)
                        ),
                        function()
                            if not IsValid(pPlayer) then return end
                            netstream.Start(pPlayer, 'SWExp::DonateShop_EquipResult',
                                { ok = true, itemID = itemID, equipped = true })
                        end,
                        function(err)
                            print('[SWExp.DonateShop] Ошибка экипировки: ' .. tostring(err))
                            return true
                        end
                    )
                end
            end,
            function(err)
                print('[SWExp.DonateShop] Ошибка проверки: ' .. tostring(err))
                return true
            end
        )
    else
        -- Снять пак
        MySQLite.query(
            string.format(
                'DELETE FROM `swexp_donate_charmodel` WHERE `character_id` = %d AND `item_id` = %s;',
                charID, MySQLite.SQLStr(itemID)
            ),
            function()
                if not IsValid(pPlayer) then return end

                -- Восстанавливаем стандартную модель брони если она надета
                local steamID = pPlayer:SteamID64()
                if SWExp.Inventory and SWExp.Inventory.PlayerEquipment then
                    local eq = SWExp.Inventory.PlayerEquipment[steamID]
                    if eq and eq[charID] and eq[charID]['armor'] and eq[charID]['armor'][1] then
                        local armorSlot = eq[charID]['armor'][1]
                        local aData = SWExp.Inventory:GetItemData(armorSlot.itemID)
                        if aData and aData.playerModel then
                            pPlayer:SetModel(aData.playerModel)
                        end
                    end
                end

                netstream.Start(pPlayer, 'SWExp::DonateShop_EquipResult',
                    { ok = true, itemID = itemID, equipped = false })
            end,
            function(err)
                print('[SWExp.DonateShop] Ошибка снятия: ' .. tostring(err))
                return true
            end
        )
    end
end)

print('[SWExp.DonateShop] Серверный модуль загружен.')
