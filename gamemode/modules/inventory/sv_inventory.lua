--[[--
    SWExp: Серверная часть системы инвентаря
    Модуль: inventory
]]--

AddCSLuaFile("sh_inventory.lua")
include("sh_inventory.lua")

SWExp.Inventory.PlayerInventories = {}
SWExp.Inventory.PlayerStorages = {}
SWExp.Inventory.PlayerEquipment = {}

-- Локальный fallback для rate-limit (если core/sv_net_ratelimit не загружен)
local function RateOk(ply, key, cd)
    if SWExp and SWExp.Net and SWExp.Net.RateCheck then
        return SWExp.Net:RateCheck(ply, key, cd)
    end
    return IsValid(ply)
end

-- Вспомогательные функции для classSWEP (может быть строкой ИЛИ таблицей строк)
local function GiveClassSWEP(pPlayer, classSWEP)
    if type(classSWEP) == "table" then
        for _, swep in ipairs(classSWEP) do
            if not IsValid(pPlayer:GetWeapon(swep)) then
                pPlayer:Give(swep, true)
            end
        end
    elseif type(classSWEP) == "string" then
        if not IsValid(pPlayer:GetWeapon(classSWEP)) then
            pPlayer:Give(classSWEP, true)
        end
    end
end

local function StripClassSWEP(pPlayer, classSWEP)
    if type(classSWEP) == "table" then
        for _, swep in ipairs(classSWEP) do
            pPlayer:StripWeapon(swep)
        end
    elseif type(classSWEP) == "string" then
        pPlayer:StripWeapon(classSWEP)
    end
end

-- Криптостойкий генератор уникальных ID предметов.
-- Коллизии на `os.time()+math.random()` полностью исключаются за счёт
-- монотонного счётчика SysTime + CRC32 случайного мусора.
local _uidCounter = 0
local function GenerateItemUID()
    _uidCounter = _uidCounter + 1
    local entropy = tostring(SysTime()) .. "_" .. tostring(math.random(1, 2^31 - 1))
    return string.format("%d_%d_%s",
        os.time(),
        _uidCounter,
        util.CRC(entropy)
    )
end

-- ============================================================================
-- ИНИЦИАЛИЗАЦИЯ БД
-- ============================================================================
hook.Add("DatabaseInitialized", "SWExp::Inventory_DB_Init", function()
    MySQLite.query([[
        CREATE TABLE IF NOT EXISTS swexp_inventory (
            character_id INTEGER NOT NULL PRIMARY KEY,
            grid_data TEXT,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    
    MySQLite.query([[
        CREATE TABLE IF NOT EXISTS swexp_storage (
            character_id INTEGER NOT NULL PRIMARY KEY,
            grid_data TEXT,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    
    MySQLite.query([[
        CREATE TABLE IF NOT EXISTS swexp_equipment (
            character_id INTEGER NOT NULL,
            slot_type VARCHAR(50) NOT NULL,
            slot_index INTEGER NOT NULL,
            item_data TEXT,
            PRIMARY KEY (character_id, slot_type, slot_index)
        )
    ]])
    
    MsgC(Color(0, 255, 0), "[SWExp] Таблицы инвентаря созданы!\n")
end)

-- ============================================================================
-- ЗАГРУЗКА И СОХРАНЕНИЕ
-- ============================================================================
function SWExp.Inventory:GetCharacterID(pPlayer)
    if not IsValid(pPlayer) then return nil end

    -- Обращаемся напрямую к твоей системе из sv_chars.lua
    if pPlayer.SWExp_ActiveChar and pPlayer.SWExp_ActiveChar.id then
        local id = tonumber(pPlayer.SWExp_ActiveChar.id)
        -- Виртуальный ADMIN-персонаж (id = -1) не имеет записи в БД.
        -- Возвращаем nil — все вызывающие функции (инвентарь, патроны,
        -- гранаты, экипировка) увидят nil и прервутся без SQL-запроса.
        if id == -1 then return nil end
        return id
    end

    return nil
end

function SWExp.Inventory:LoadCharacterInventory(pPlayer, callback)
    local charID = self:GetCharacterID(pPlayer)
    if not charID then 
        if callback then callback(false) end
        return 
    end
    
    local steamID = pPlayer:SteamID64()
    
    MySQLite.query(string.format("SELECT * FROM swexp_inventory WHERE character_id = %d", charID), function(result)
        if not IsValid(pPlayer) then return end
        local gridData = {}
        if result and result[1] and result[1].grid_data then gridData = self:DeserializeInventory(result[1].grid_data) end
        
        self.PlayerInventories[steamID] = self.PlayerInventories[steamID] or {}
        self.PlayerInventories[steamID][charID] = {grid = gridData.grid or {}, items = gridData.items or {}}
        
        MySQLite.query(string.format("SELECT * FROM swexp_storage WHERE character_id = %d", charID), function(storageResult)
            if not IsValid(pPlayer) then return end
            local storageData = {}
            if storageResult and storageResult[1] and storageResult[1].grid_data then storageData = self:DeserializeInventory(storageResult[1].grid_data) end
            
            self.PlayerStorages[steamID] = self.PlayerStorages[steamID] or {}
            self.PlayerStorages[steamID][charID] = {grid = storageData.grid or {}, items = storageData.items or {}}
            
            MySQLite.query(string.format("SELECT * FROM swexp_equipment WHERE character_id = %d", charID), function(equipResult)
                if not IsValid(pPlayer) then return end
                self.PlayerEquipment[steamID] = self.PlayerEquipment[steamID] or {}
                self.PlayerEquipment[steamID][charID] = {}
                
                if equipResult then
                    for _, row in ipairs(equipResult) do
                        local slotType = row.slot_type
                        local slotIndex = tonumber(row.slot_index)
                        local itemData = util.JSONToTable(row.item_data)
                        
                        self.PlayerEquipment[steamID][charID][slotType] = self.PlayerEquipment[steamID][charID][slotType] or {}
                        self.PlayerEquipment[steamID][charID][slotType][slotIndex] = itemData
                    end
                end
                
                self:SyncInventoryToClient(pPlayer)
                if callback then callback(true) end
            end)
        end)
    end)
end

function SWExp.Inventory:SaveCharacterInventory(pPlayer, charID)
    charID = charID or self:GetCharacterID(pPlayer)
    if not IsValid(pPlayer) or not charID then return end
    local steamID = pPlayer:SteamID64()
    
    local invData = self.PlayerInventories[steamID] and self.PlayerInventories[steamID][charID]
    if invData then
        local jsonData = self:SerializeInventory(invData)
        MySQLite.query(string.format("REPLACE INTO swexp_inventory (character_id, grid_data) VALUES (%d, %s)", charID, MySQLite.SQLStr(jsonData)))
    end
    
    local storageData = self.PlayerStorages[steamID] and self.PlayerStorages[steamID][charID]
    if storageData then
        local jsonData = self:SerializeInventory(storageData)
        MySQLite.query(string.format("REPLACE INTO swexp_storage (character_id, grid_data) VALUES (%d, %s)", charID, MySQLite.SQLStr(jsonData)))
    end
    
    local equipData = self.PlayerEquipment[steamID] and self.PlayerEquipment[steamID][charID]
    if equipData then
        for slotType, slots in pairs(equipData) do
            for slotIndex, itemData in pairs(slots) do
                if itemData then
                    MySQLite.query(string.format("REPLACE INTO swexp_equipment (character_id, slot_type, slot_index, item_data) VALUES (%d, %s, %d, %s)",
                        charID, MySQLite.SQLStr(slotType), slotIndex, MySQLite.SQLStr(util.TableToJSON(itemData))))
                else
                    MySQLite.query(string.format("DELETE FROM swexp_equipment WHERE character_id = %d AND slot_type = %s AND slot_index = %d", charID, MySQLite.SQLStr(slotType), slotIndex))
                end
            end
        end
    end
end

function SWExp.Inventory:SyncInventoryToClient(pPlayer)
    if not IsValid(pPlayer) then return end
    local charID = self:GetCharacterID(pPlayer)
    if not charID then return end
    local steamID = pPlayer:SteamID64()
    
    netstream.Start(pPlayer, "SWExp::InventorySync", {
        inventory = self.PlayerInventories[steamID] and self.PlayerInventories[steamID][charID] or {grid = {}, items = {}},
        storage = self.PlayerStorages[steamID] and self.PlayerStorages[steamID][charID] or {grid = {}, items = {}},
        equipment = self.PlayerEquipment[steamID] and self.PlayerEquipment[steamID][charID] or {}
    })
end

-- ============================================================================
-- БАЗОВЫЕ ОПЕРАЦИИ (ADD, REMOVE, MOVE)
-- ============================================================================
function SWExp.Inventory:AddItem(pPlayer, itemID, amount, targetStorage)
    if not IsValid(pPlayer) then return false, "Игрок не найден" end
    local charID = self:GetCharacterID(pPlayer)
    if not charID then return false, "Персонаж не загружен" end
    
    local itemData = self:GetItemData(itemID)
    if not itemData then return false, "Предмет не найден" end
    
    amount = amount or 1
    local originalAmount = amount  -- Сохраняем для уведомления
    local steamID = pPlayer:SteamID64()
    
    local storage, gridWidth, gridHeight
    if targetStorage == "storage" then
        storage = self.PlayerStorages[steamID] and self.PlayerStorages[steamID][charID]
        gridWidth = self.Config.StorageGridWidth
        gridHeight = self.Config.StorageGridHeight
    else
        storage = self.PlayerInventories[steamID] and self.PlayerInventories[steamID][charID]
        gridWidth = self.Config.GridWidth
        gridHeight = self.Config.GridHeight
    end
    
    if not storage then
        storage = {grid = {}, items = {}}
        if targetStorage == "storage" then
            self.PlayerStorages[steamID] = self.PlayerStorages[steamID] or {}
            self.PlayerStorages[steamID][charID] = storage
        else
            self.PlayerInventories[steamID] = self.PlayerInventories[steamID] or {}
            self.PlayerInventories[steamID][charID] = storage
        end
    end
    
    if itemData.stackable and amount > 0 then
        for uniqueID, item in pairs(storage.items) do
            if item.itemID == itemID and item.amount < itemData.maxStack then
                local canAdd = math.min(amount, itemData.maxStack - item.amount)
                item.amount = item.amount + canAdd
                amount = amount - canAdd
                
                if amount <= 0 then
                    hook.Run("SWExp::ItemAddedToInventory", pPlayer, itemID, originalAmount)
                    self:SyncInventoryToClient(pPlayer)
                    self:SaveCharacterInventory(pPlayer, charID)
                    hook.Run("SWExp::InventoryChanged", pPlayer)
                    return true
                end
            end
        end
    end
    
    while amount > 0 do
        local posX, posY = self:FindFreeSlot(storage.grid, gridWidth, gridHeight, itemData)
        if not posX then
            self:SyncInventoryToClient(pPlayer)
            self:SaveCharacterInventory(pPlayer, charID)
            return false, "Недостаточно места"
        end
        
        local stackAmount = itemData.stackable and math.min(amount, itemData.maxStack) or 1
        local uniqueID = GenerateItemUID()

        for x = posX, posX + itemData.width - 1 do
            for y = posY, posY + itemData.height - 1 do
                storage.grid[x .. "_" .. y] = uniqueID
            end
        end
        
        storage.items[uniqueID] = {itemID = itemID, amount = stackAmount, posX = posX, posY = posY}
        amount = amount - stackAmount
    end
    
    self:SyncInventoryToClient(pPlayer)
    self:SaveCharacterInventory(pPlayer, charID)

    -- Уведомление о подборе предмета на клиенте
    netstream.Start(pPlayer, "SWExp::ItemPickupNotify", {
        itemID = itemID,
        amount = originalAmount,
    })

    hook.Run("SWExp::ItemAddedToInventory", pPlayer, itemID, originalAmount)

    -- Хук для модулей, которым нужно знать об изменении инвентаря (ассемблер, исследования)
    hook.Run("SWExp::InventoryChanged", pPlayer)

    return true
end

function SWExp.Inventory:RemoveItem(pPlayer, uniqueID, amount, fromStorage)
    if not IsValid(pPlayer) then return false end
    local charID = self:GetCharacterID(pPlayer)
    if not charID then return false end
    
    local steamID = pPlayer:SteamID64()
    local storage = fromStorage and (self.PlayerStorages[steamID] and self.PlayerStorages[steamID][charID]) or (self.PlayerInventories[steamID] and self.PlayerInventories[steamID][charID])
    
    if not storage or not storage.items[uniqueID] then return false end
    local item = storage.items[uniqueID]
    local itemData = self:GetItemData(item.itemID)
    amount = amount or item.amount
    
    if item.amount <= amount then
        for x = item.posX, item.posX + itemData.width - 1 do
            for y = item.posY, item.posY + itemData.height - 1 do
                storage.grid[x .. "_" .. y] = nil
            end
        end
        storage.items[uniqueID] = nil
    else
        item.amount = item.amount - amount
    end
    
    self:SyncInventoryToClient(pPlayer)
    self:SaveCharacterInventory(pPlayer, charID)

    -- Хук для модулей, которым нужно знать об изменении инвентаря (ассемблер, исследования)
    hook.Run("SWExp::InventoryChanged", pPlayer)

    return true
end

-- ============================================================================
-- РАБОТА СО СТАКАМИ: РАЗДЕЛЕНИЕ И ОБЪЕДИНЕНИЕ
-- ============================================================================

-- Разделяет стак предмета на два. splitAmount — количество предметов в новом стаке.
function SWExp.Inventory:SplitItem(pPlayer, uniqueID, splitAmount, fromStorage)
    if not IsValid(pPlayer) then return false, "Игрок не найден" end
    local charID = self:GetCharacterID(pPlayer)
    if not charID then return false, "Персонаж не загружен" end
    local steamID = pPlayer:SteamID64()

    local storage = fromStorage
        and (self.PlayerStorages[steamID] and self.PlayerStorages[steamID][charID])
        or  (self.PlayerInventories[steamID] and self.PlayerInventories[steamID][charID])

    if not storage or not storage.items[uniqueID] then return false, "Предмет не найден" end

    local item     = storage.items[uniqueID]
    local itemData = self:GetItemData(item.itemID)
    if not itemData or not itemData.stackable then return false, "Предмет не складывается в стаки" end

    splitAmount = math.floor(tonumber(splitAmount) or 0)
    if splitAmount <= 0 or splitAmount >= item.amount then
        return false, "Некорректное количество для разделения"
    end

    local gridWidth  = fromStorage and self.Config.StorageGridWidth  or self.Config.GridWidth
    local gridHeight = fromStorage and self.Config.StorageGridHeight or self.Config.GridHeight

    -- Ищем свободный слот для нового стека
    local posX, posY = self:FindFreeSlot(storage.grid, gridWidth, gridHeight, itemData)
    if not posX then return false, "Нет свободного места для нового стека" end

    -- Уменьшаем исходный стек
    item.amount = item.amount - splitAmount

    -- Создаём новый стек
    local newUID = GenerateItemUID()
    for x = posX, posX + (itemData.width or 1) - 1 do
        for y = posY, posY + (itemData.height or 1) - 1 do
            storage.grid[x .. "_" .. y] = newUID
        end
    end
    storage.items[newUID] = { itemID = item.itemID, amount = splitAmount, posX = posX, posY = posY }

    self:SyncInventoryToClient(pPlayer)
    self:SaveCharacterInventory(pPlayer, charID)
    return true
end

-- Объединяет два стека одного типа. Если целевой стек заполнен частично — перекладывает
-- максимально возможное количество; остаток остаётся в исходном стеке.
function SWExp.Inventory:MergeItems(pPlayer, sourceUID, targetUID, fromStorage, toStorage)
    if not IsValid(pPlayer) then return false end
    local charID = self:GetCharacterID(pPlayer)
    if not charID then return false end
    local steamID = pPlayer:SteamID64()

    local srcStorage = fromStorage
        and (self.PlayerStorages[steamID] and self.PlayerStorages[steamID][charID])
        or  (self.PlayerInventories[steamID] and self.PlayerInventories[steamID][charID])
    local dstStorage = toStorage
        and (self.PlayerStorages[steamID] and self.PlayerStorages[steamID][charID])
        or  (self.PlayerInventories[steamID] and self.PlayerInventories[steamID][charID])

    if not srcStorage or not srcStorage.items[sourceUID] then return false end
    if not dstStorage or not dstStorage.items[targetUID] then return false end

    local srcItem = srcStorage.items[sourceUID]
    local dstItem = dstStorage.items[targetUID]

    -- Оба предмета должны быть одного типа
    if srcItem.itemID ~= dstItem.itemID then return false end

    local itemData = self:GetItemData(srcItem.itemID)
    if not itemData or not itemData.stackable then return false end

    local maxStack = itemData.maxStack or 1
    local canAdd   = maxStack - dstItem.amount
    if canAdd <= 0 then return false, "Целевой стек уже заполнен" end

    local moveAmount = math.min(srcItem.amount, canAdd)
    dstItem.amount = dstItem.amount + moveAmount
    srcItem.amount = srcItem.amount - moveAmount

    -- Если исходный стек полностью перенесён — удаляем его из сетки
    if srcItem.amount <= 0 then
        local oldRotated = srcItem.rotated == true or srcItem.rotated == 1
        local oldEffW = oldRotated and (itemData.height or 1) or (itemData.width or 1)
        local oldEffH = oldRotated and (itemData.width  or 1) or (itemData.height or 1)
        for x = srcItem.posX, srcItem.posX + oldEffW - 1 do
            for y = srcItem.posY, srcItem.posY + oldEffH - 1 do
                srcStorage.grid[x .. "_" .. y] = nil
            end
        end
        srcStorage.items[sourceUID] = nil
    end

    self:SyncInventoryToClient(pPlayer)
    self:SaveCharacterInventory(pPlayer, charID)
    return true
end

function SWExp.Inventory:MoveItem(pPlayer, uniqueID, newPosX, newPosY, fromStorage, toStorage, rotated)
    if not IsValid(pPlayer) then return false end
    local charID = self:GetCharacterID(pPlayer)
    if not charID then return false end
    local steamID = pPlayer:SteamID64()

    local sourceStorage = fromStorage and (self.PlayerStorages[steamID] and self.PlayerStorages[steamID][charID]) or (self.PlayerInventories[steamID] and self.PlayerInventories[steamID][charID])
    local targetStorage = toStorage and (self.PlayerStorages[steamID] and self.PlayerStorages[steamID][charID]) or (self.PlayerInventories[steamID] and self.PlayerInventories[steamID][charID])

    if not sourceStorage or not sourceStorage.items[uniqueID] or not targetStorage then return false end
    local item = sourceStorage.items[uniqueID]
    local itemData = self:GetItemData(item.itemID)
    if not itemData then return false end

    local gridWidth  = toStorage and self.Config.StorageGridWidth  or self.Config.GridWidth
    local gridHeight = toStorage and self.Config.StorageGridHeight or self.Config.GridHeight

    -- Нормализуем rotated: всегда булево значение (netstream может передать как 0/1 или nil)
    rotated = rotated == true or rotated == 1

    -- Нормализуем старый поворот предмета
    local oldRotated = item.rotated == true or item.rotated == 1

    local baseW = itemData.width  or 1
    local baseH = itemData.height or 1

    -- Эффективные размеры с учётом нового поворота
    local effectW = rotated and baseH or baseW
    local effectH = rotated and baseW or baseH

    -- Эффективные старые размеры с учётом СТАРОГО поворота
    local oldEffW = oldRotated and baseH or baseW
    local oldEffH = oldRotated and baseW or baseH

    -- Очищаем старые ячейки предмета используя его текущую позицию и поворот
    local oldGrid = {}
    for x = item.posX, item.posX + oldEffW - 1 do
        for y = item.posY, item.posY + oldEffH - 1 do
            local key = x .. "_" .. y
            oldGrid[key] = sourceStorage.grid[key]
            sourceStorage.grid[key] = nil
        end
    end

    local effData = { width = effectW, height = effectH }
    if not self:CanFitItem(targetStorage.grid, gridWidth, gridHeight, effData, newPosX, newPosY) then
        -- Возвращаем старые ячейки
        for key, val in pairs(oldGrid) do sourceStorage.grid[key] = val end
        return false
    end

    if sourceStorage ~= targetStorage then sourceStorage.items[uniqueID] = nil end

    for x = newPosX, newPosX + effectW - 1 do
        for y = newPosY, newPosY + effectH - 1 do
            targetStorage.grid[x .. "_" .. y] = uniqueID
        end
    end

    item.posX    = newPosX
    item.posY    = newPosY
    item.rotated = rotated
    targetStorage.items[uniqueID] = item

    self:SyncInventoryToClient(pPlayer)
    self:SaveCharacterInventory(pPlayer, charID)
    hook.Run("SWExp::InventoryChanged", pPlayer)
    return true
end

-- ============================================================================
-- ЭКИПИРОВКА И ПРАВИЛА БРОНИ ИЗ GDD
-- ============================================================================
function SWExp.Inventory:GetDynamicSlotCount(pPlayer, slotType)
    local charID = self:GetCharacterID(pPlayer)
    if not charID then return 0 end
    
    local steamID = pPlayer:SteamID64()
    local equip = self.PlayerEquipment[steamID] and self.PlayerEquipment[steamID][charID]
    
    -- ИСПРАВЛЕНИЕ: Обращаемся к слоту [1] как к числу
    local armorEquipped = equip and equip["armor"] and equip["armor"][1]
    
    local armorClass = "none"
    if armorEquipped then
        local armorData = self:GetItemData(armorEquipped.itemID)
        if armorData then armorClass = armorData.armorClass or "none" end
    end
    
    -- Слоты, не зависящие от класса брони: всегда открыты полностью
    local alwaysOpen = { special = true, medical = true, grenade = true }
    if alwaysOpen[slotType] then
        local cfg = self.Config.EquipmentSlots[slotType]
        return cfg and cfg.total or 1
    end

    local slotsMap = {
        ["light"]    = { primary = 2, secondary = 2, heavy = 0 },
        ["medium"]   = { primary = 2, secondary = 2, heavy = 0 },
        ["heavy"]    = { primary = 1, secondary = 2, heavy = 1 },
        ["engineer"] = { primary = 1, secondary = 2, heavy = 0 },
        ["medical"]  = { primary = 1, secondary = 2, heavy = 0 },
        ["none"]     = { primary = 0, secondary = 1, heavy = 0 },
    }

    local limits = slotsMap[armorClass] or slotsMap["none"]
    return limits[slotType] or self.Config.EquipmentSlots[slotType].free or 1
end

function SWExp.Inventory:EquipItem(pPlayer, uniqueID, slotType, slotIndex, fromStorage)
    local charID = self:GetCharacterID(pPlayer)
    if not charID then return false end
    
    local steamID = pPlayer:SteamID64()
    local source = fromStorage and (self.PlayerStorages[steamID] and self.PlayerStorages[steamID][charID]) or (self.PlayerInventories[steamID] and self.PlayerInventories[steamID][charID])
    
    if not source or not source.items[uniqueID] then return false end
    local item = source.items[uniqueID]
    local itemData = self:GetItemData(item.itemID)
    
    if itemData.slotType ~= slotType then return false end

    local allowedSlots = self:GetDynamicSlotCount(pPlayer, slotType)
    if slotType ~= "armor" and slotIndex > allowedSlots then return false end

    self.PlayerEquipment[steamID] = self.PlayerEquipment[steamID] or {}
    self.PlayerEquipment[steamID][charID] = self.PlayerEquipment[steamID][charID] or {}
    self.PlayerEquipment[steamID][charID][slotType] = self.PlayerEquipment[steamID][charID][slotType] or {}

    -- Фиксируем данные нового предмета ДО любых операций (AddItem меняет storage)
    local newItemID  = item.itemID
    local newAmount  = item.amount or 1
    local newPosX    = item.posX
    local newPosY    = item.posY
    local newEffW    = item.rotated and (itemData.height or 1) or (itemData.width or 1)
    local newEffH    = item.rotated and (itemData.width  or 1) or (itemData.height or 1)

    -- Если в слоте уже что-то есть — снимаем и возвращаем в инвентарь
    local currentItem = self.PlayerEquipment[steamID][charID][slotType][slotIndex]
    if currentItem then
        local curItemData = self:GetItemData(currentItem.itemID)
        if curItemData then
            -- Снимаем SWEP брони (classSWEP) или оружия (weaponClass)
            if slotType == "armor" then
                if curItemData.classSWEP then StripClassSWEP(pPlayer, curItemData.classSWEP) end
            elseif curItemData.weaponClass then
                pPlayer:StripWeapon(curItemData.weaponClass)
            end
        end
        -- Очищаем слот ДО AddItem чтобы избежать рекурсии
        self.PlayerEquipment[steamID][charID][slotType][slotIndex] = nil
        MySQLite.query(string.format(
            "DELETE FROM swexp_equipment WHERE character_id = %d AND slot_type = %s AND slot_index = %d",
            charID, MySQLite.SQLStr(slotType), slotIndex
        ))
        local replaceOk = self:AddItem(pPlayer, currentItem.itemID, currentItem.amount or 1)
        if not replaceOk then
            -- Нет места — дропаем снятый предмет на землю
            local dropEnt = ents.Create("nextrp_dropped_item")
            if IsValid(dropEnt) then
                dropEnt:SetPos(pPlayer:GetPos() + Vector(math.random(-30,30), math.random(-30,30), 10))
                dropEnt:Spawn()
                dropEnt:SetItemData(currentItem.itemID, currentItem.amount or 1)
            end
        end
    end

    -- Убираем новый предмет из сетки инвентаря (source мог измениться после AddItem — берём свежую ссылку)
    source = fromStorage and (self.PlayerStorages[steamID] and self.PlayerStorages[steamID][charID])
              or (self.PlayerInventories[steamID] and self.PlayerInventories[steamID][charID])
    if source and source.items[uniqueID] then
        for x = newPosX, newPosX + newEffW - 1 do
            for y = newPosY, newPosY + newEffH - 1 do
                source.grid[x .. "_" .. y] = nil
            end
        end
        source.items[uniqueID] = nil
    end

    -- Записываем в слот
    self.PlayerEquipment[steamID][charID][slotType][slotIndex] = {itemID = newItemID, amount = newAmount}

    if slotType == "armor" then
        -- Броня: сначала применяем модель и стат, потом выдаём SWEP
        pPlayer:SetMaxArmor(100)
        pPlayer:SetArmor((itemData.armorReduction or 0) * 100)
        if itemData.playerModel then
            pPlayer:SetModel(itemData.playerModel)
            if SWExp.Chars and SWExp.Chars.UpdateModel then
                SWExp.Chars:UpdateModel(pPlayer, itemData.playerModel)
            end
        end
        if SWExp.Armor and SWExp.Armor.ApplyArmorSpeed then
            SWExp.Armor.ApplyArmorSpeed(pPlayer)
        end
        if itemData.classSWEP then
            -- Give безопасно: если уже есть — не дублирует
            -- Поддержка classSWEP как строки и как таблицы строк
            GiveClassSWEP(pPlayer, itemData.classSWEP)
        end
    elseif itemData.weaponClass then
        -- Оружейный слот: выдаём SWEP если нет
        -- Второй аргумент true → НЕ выдавать стартовый запас патронов;
        -- запас управляется модулем ammo (по character_id из БД).
        if not IsValid(pPlayer:GetWeapon(itemData.weaponClass)) then
            pPlayer:Give(itemData.weaponClass, true)
        end
    end

    -- HOOK: пусть модуль ammo (или другие) подгрузит запас патронов / магазин гранаты
    hook.Run("SWExp::ItemEquipped", pPlayer, slotType, slotIndex, newItemID, newAmount)

    -- Обновляем NWBool маскировки если надели броню
    if slotType == "armor" then
        pPlayer:SetNWBool("SWExp_CloakAllowed", itemData.isAvailableCloak == true)
        -- Уведомляем систему шкафа: броня одета, нужно переприменить бодигруппы
        hook.Run('SWExp::ArmorEquipped', pPlayer, itemData)
    end

    self:SyncInventoryToClient(pPlayer)
    self:SaveCharacterInventory(pPlayer, charID)
    return true
end

function SWExp.Inventory:UnequipItem(pPlayer, slotType, slotIndex)
    local charID = self:GetCharacterID(pPlayer)
    if not charID then return false end

    local steamID = pPlayer:SteamID64()
    local equip = self.PlayerEquipment[steamID] and self.PlayerEquipment[steamID][charID]
    if not equip or not equip[slotType] or not equip[slotType][slotIndex] then return false end

    -- Нельзя снять броню если есть оружие в основном, второстепенном или тяжёлом слоте
    if slotType == "armor" then
        local weaponSlots = { "primary", "secondary", "heavy" }
        for _, wSlot in ipairs(weaponSlots) do
            if equip[wSlot] then
                for _, wItem in pairs(equip[wSlot]) do
                    if wItem and wItem.itemID then
                        pPlayer:ChatPrint("[Броня] Сначала снимите оружие из основного, второстепенного и тяжёлого слотов.")
                        return false
                    end
                end
            end
        end
    end
    
    local item = equip[slotType][slotIndex]

    -- HOOK: модули могут подменить количество, которое реально вернётся в инвентарь.
    -- Например, для гранат — сколько осталось в clip SWEP'а на момент снятия.
    local override = hook.Run("SWExp::ItemUnequipping", pPlayer, slotType, slotIndex, item.itemID)
    if isnumber(override) and override >= 0 then
        item.amount = override
    end

    local addOk
    if (item.amount or 0) > 0 then
        addOk = self:AddItem(pPlayer, item.itemID, item.amount)
    else
        -- Нечего возвращать (граната израсходована полностью) — просто пропускаем
        addOk = true
    end
    if not addOk then
        -- Нет места в инвентаре — дропаем предмет на землю рядом с игроком
        local dropEnt = ents.Create("nextrp_dropped_item")
        if IsValid(dropEnt) then
            dropEnt:SetPos(pPlayer:GetPos() + Vector(math.random(-30,30), math.random(-30,30), 10))
            dropEnt:Spawn()
            dropEnt:SetItemData(item.itemID, item.amount or 1)
        end
    end

    -- Удаляем из БД и памяти в любом случае
    MySQLite.query(string.format(
        "DELETE FROM swexp_equipment WHERE character_id = %d AND slot_type = %s AND slot_index = %d",
        charID, MySQLite.SQLStr(slotType), slotIndex
    ))

    equip[slotType][slotIndex] = nil

    local itemData = self:GetItemData(item.itemID)

    if slotType == "armor" then
        -- 1. Снять SWEP самой брони (крюк-кошка и т.д.)
        if itemData and itemData.classSWEP then
            StripClassSWEP(pPlayer, itemData.classSWEP)
        end

        -- 2. Снять ВСЕ SWEP из оружейных слотов и вернуть предметы в инвентарь
        --    equip["armor"][1] уже nil (выше), так что GetDynamicSlotCount корректен.
        local weaponSlots = {"primary", "secondary", "heavy", "special"}
        local currentEquip = self.PlayerEquipment[steamID] and self.PlayerEquipment[steamID][charID]
        if currentEquip then
            for _, wSlotType in ipairs(weaponSlots) do
                if currentEquip[wSlotType] then
                    for wSlotIdx, wItem in pairs(currentEquip[wSlotType]) do
                        if wItem and wItem.itemID then
                            local wData = self:GetItemData(wItem.itemID)
                            -- HOOK: подменить amount остатком (например, гранаты)
                            local wOverride = hook.Run("SWExp::ItemUnequipping", pPlayer, wSlotType, wSlotIdx, wItem.itemID)
                            if isnumber(wOverride) and wOverride >= 0 then
                                wItem.amount = wOverride
                            end
                            -- Снять SWEP
                            if wData and wData.weaponClass then
                                pPlayer:StripWeapon(wData.weaponClass)
                            end
                            -- Вернуть предмет в инвентарь; если нет места — дропнуть на землю
                            local addOk = ((wItem.amount or 0) > 0) and self:AddItem(pPlayer, wItem.itemID, wItem.amount or 1) or true
                            if not addOk then
                                local dropEnt = ents.Create("nextrp_dropped_item")
                                if IsValid(dropEnt) then
                                    dropEnt:SetPos(pPlayer:GetPos() + Vector(math.random(-30,30), math.random(-30,30), 10))
                                    dropEnt:Spawn()
                                    dropEnt:SetItemData(wItem.itemID, wItem.amount or 1)
                                end
                            end
                            -- Удалить из БД и данных
                            MySQLite.query(string.format(
                                "DELETE FROM swexp_equipment WHERE character_id = %d AND slot_type = %s AND slot_index = %d",
                                charID, MySQLite.SQLStr(wSlotType), wSlotIdx
                            ))
                            currentEquip[wSlotType][wSlotIdx] = nil
                        end
                    end
                end
            end
        end

        -- 3. Снять броню (HP/скорость)
        pPlayer:SetArmor(0)
        if SWExp.Armor and SWExp.Armor.ApplyArmorSpeed then
            SWExp.Armor.ApplyArmorSpeed(pPlayer)
        end

        -- 4. Вернуть дефолтную модель — и только сейчас, после всех операций
        local defaultModel = "models/player/olive/cadet/cadet.mdl"
        if SWExp.Chars and SWExp.Chars.GetModelForRank then
            defaultModel = SWExp.Chars:GetModelForRank(pPlayer:GetNWString("swexp_rank", "TRP"))
        end
        pPlayer:SetModel(defaultModel)
        if SWExp.Chars and SWExp.Chars.UpdateModel then
            SWExp.Chars:UpdateModel(pPlayer, defaultModel)
        end
        -- Сбрасываем право на маскировку при снятии брони
        pPlayer:SetNWBool("SWExp_CloakAllowed", false)
        -- Уведомляем систему шкафа: броня снята, нужно переприменить бодигруппы
        hook.Run('SWExp::ArmorUnequipped', pPlayer)
    elseif itemData and itemData.weaponClass then
        -- Обычный оружейный слот: снять SWEP
        pPlayer:StripWeapon(itemData.weaponClass)
    end

    self:SyncInventoryToClient(pPlayer)
    self:SaveCharacterInventory(pPlayer, charID)
    return true
end

-- Функция повторного применения всей экипировки (броня + оружие)
function SWExp.Inventory:ApplyEquippedArmor(pPlayer)
    local charID = self:GetCharacterID(pPlayer)
    if not charID then return end

    local steamID = pPlayer:SteamID64()
    local equip = self.PlayerEquipment[steamID] and self.PlayerEquipment[steamID][charID]
    if not equip then return end

    -- Восстановить броню
    local armorEquipped = equip["armor"] and equip["armor"][1]
    if armorEquipped then
        local itemData = self:GetItemData(armorEquipped.itemID)
        if itemData then
            pPlayer:SetMaxArmor(100)
            pPlayer:SetArmor(itemData.armorReduction * 100)
            if itemData.playerModel then pPlayer:SetModel(itemData.playerModel) end
            if itemData.classSWEP then
                -- Поддержка classSWEP как строки и как таблицы строк
                GiveClassSWEP(pPlayer, itemData.classSWEP)
            end
            if SWExp.Armor and SWExp.Armor.ApplyArmorSpeed then
                SWExp.Armor.ApplyArmorSpeed(pPlayer)
            end
            -- Синхронизируем право на маскировку из надетой брони
            pPlayer:SetNWBool("SWExp_CloakAllowed", itemData.isAvailableCloak == true)
        end
    else
        -- Брони нет — маскировка недоступна
        pPlayer:SetNWBool("SWExp_CloakAllowed", false)
    end

    -- Уведомляем шкаф: финальная модель выставлена, применяй бодигруппы
    hook.Run('SWExp::ArmorRestored', pPlayer)

    -- Восстановить оружие из всех оружейных слотов
    for slotType, slots in pairs(equip) do
        if slotType == "armor" then continue end
        for _, slotItem in pairs(slots) do
            if slotItem and slotItem.itemID then
                local itemData = self:GetItemData(slotItem.itemID)
                if itemData and itemData.weaponClass then
                    if not IsValid(pPlayer:GetWeapon(itemData.weaponClass)) then
                        pPlayer:Give(itemData.weaponClass, true)
                    end
                end
            end
        end
    end
end

function SWExp.Inventory:ForceUnequipInvalidSlots(pPlayer, charID, steamID)
    local equip = self.PlayerEquipment[steamID][charID]
    if not equip then return end
    
    for iterSlotType, _ in pairs(self.Config.EquipmentSlots) do
        if iterSlotType == "armor" then continue end
        local allowed = self:GetDynamicSlotCount(pPlayer, iterSlotType)
        if equip[iterSlotType] then
            for slotIdx, _ in pairs(equip[iterSlotType]) do
                if tonumber(slotIdx) > allowed then
                    self:UnequipItem(pPlayer, iterSlotType, tonumber(slotIdx))
                end
            end
        end
    end
end

-- ============================================================================
-- ВЫБРОС ПРЕДМЕТОВ (DROP И СУМКА СМЕРТИ)
-- ============================================================================
function SWExp.Inventory:DropItem(pPlayer, uniqueID, fromStorage)
    if not IsValid(pPlayer) then return false end
    local charID = self:GetCharacterID(pPlayer)
    if not charID then return false end
    
    local steamID = pPlayer:SteamID64()
    local storage = fromStorage and (self.PlayerStorages[steamID] and self.PlayerStorages[steamID][charID]) or (self.PlayerInventories[steamID] and self.PlayerInventories[steamID][charID])
    
    if not storage or not storage.items[uniqueID] then return false end
    local item = storage.items[uniqueID]
    local itemData = self:GetItemData(item.itemID)
    if not itemData or not itemData.canDrop then return false end
    
    local ent = ents.Create("nextrp_dropped_item") -- Если у тебя свое энтити, замени класс
    if not IsValid(ent) then return false end

    -- Ограничиваем дистанцию дропа: предмет падает не дальше MaxDropDistance от игрока
    local MaxDropDistance = SWExp.Inventory.Config.PickupRadius or 100
    local tr       = pPlayer:GetEyeTrace()
    local eyePos   = pPlayer:EyePos()
    local dropPos

    if tr.Hit and eyePos:Distance(tr.HitPos) <= MaxDropDistance then
        dropPos = tr.HitPos + tr.HitNormal * 10
    else
        -- Цель слишком далеко — кладём прямо перед игроком на земле
        local forward = pPlayer:GetForward()
        local nearPos = eyePos + forward * math.min(MaxDropDistance, 60)
        local groundTr = util.TraceLine({
            start  = nearPos,
            endpos = nearPos + Vector(0, 0, -200),
            filter = pPlayer,
            mask   = MASK_SOLID_BRUSHONLY,
        })
        dropPos = (groundTr.Hit and groundTr.HitPos or nearPos) + Vector(0, 0, 5)
    end

    ent:SetPos(dropPos)
    ent:Spawn()
    if ent.SetItemData then ent:SetItemData(item.itemID, item.amount) end
    
    self:RemoveItem(pPlayer, uniqueID, item.amount, fromStorage)
    return true
end

function SWExp.Inventory:DropAllItems(pPlayer, deathPos)
    local charID = self:GetCharacterID(pPlayer)
    if not charID then return end
    
    local steamID = pPlayer:SteamID64()
    local inventory = self.PlayerInventories[steamID] and self.PlayerInventories[steamID][charID]
    if not inventory then return end
    
    local itemsCopy = {}
    local hasItems = false
    
    if inventory.items then
        for uniqueID, item in pairs(inventory.items) do
            itemsCopy[uniqueID] = table.Copy(item)
            hasItems = true
        end
    end
    
    local equip = self.PlayerEquipment[steamID] and self.PlayerEquipment[steamID][charID]
    if equip then
        for slotType, slots in pairs(equip) do
            for slotIndex, item in pairs(slots) do
                if item and item.itemID then
                    itemsCopy["equip_" .. slotType .. "_" .. slotIndex] = table.Copy(item)
                    hasItems = true
                end
            end
        end
    end

    -- Добавляем боезапас игрока в сумку смерти
    local ammoBank = SWExp.Ammo and SWExp.Ammo.PlayerData
                     and SWExp.Ammo.PlayerData[steamID]
                     and SWExp.Ammo.PlayerData[steamID][charID]
    if ammoBank then
        for ammoType, amount in pairs(ammoBank) do
            if (amount or 0) > 0 then
                local key = "__ammo_" .. ammoType
                itemsCopy[key] = { itemID = key, ammoType = ammoType, amount = amount, isAmmo = true }
                hasItems = true
            end
        end
        -- Обнуляем боезапас в памяти и в БД
        SWExp.Ammo.PlayerData[steamID][charID] = {}
        if MySQLite then
            MySQLite.query(string.format(
                "DELETE FROM swexp_ammo WHERE character_id = %d",
                charID
            ))
        end
    end

    if not hasItems then return end

    -- Снимаем все SWEP (оружия и броня) прежде чем сбрасывать данные
    if equip then
        for slotType, slots in pairs(equip) do
            for slotIndex, item in pairs(slots) do
                if item and item.itemID then
                    local itemData = self:GetItemData(item.itemID)
                    if itemData then
                        if slotType == "armor" then
                            if itemData.classSWEP then StripClassSWEP(pPlayer, itemData.classSWEP) end
                        elseif itemData.weaponClass then
                            pPlayer:StripWeapon(itemData.weaponClass)
                        end
                    end
                end
            end
        end
        -- Сброс брони и скорости
        pPlayer:SetArmor(0)
        if SWExp.Armor and SWExp.Armor.ApplyArmorSpeed then
            SWExp.Armor.ApplyArmorSpeed(pPlayer)
        end
        -- Восстановить дефолтную модель
        local defaultModel = "models/player/olive/cadet/cadet.mdl"
        if SWExp.Chars and SWExp.Chars.GetModelForRank then
            defaultModel = SWExp.Chars:GetModelForRank(pPlayer:GetNWString("swexp_rank", "TRP"))
        end
        pPlayer:SetModel(defaultModel)
        if SWExp.Chars and SWExp.Chars.UpdateModel then
            SWExp.Chars:UpdateModel(pPlayer, defaultModel)
        end
    end

    local ent = ents.Create("nextrp_death_bag")
    if IsValid(ent) then
        ent:SetPos(deathPos + Vector(0, 0, 20))
        ent:Spawn()
        if ent.SetItems then ent:SetItems(itemsCopy) end
    end

    -- Очищаем инвентарь в памяти
    inventory.grid = {}
    inventory.items = {}

    -- Очищаем экипировку в памяти
    if self.PlayerEquipment[steamID] then
        self.PlayerEquipment[steamID][charID] = {}
    end

    -- Удаляем экипировку из БД
    MySQLite.query(string.format(
        "DELETE FROM swexp_equipment WHERE character_id = %d", charID
    ))

    self:SyncInventoryToClient(pPlayer)
    self:SaveCharacterInventory(pPlayer, charID)
end

-- ============================================================================
-- СЕТЕВЫЕ ХУКИ (NETSTREAM) И ХУКИ GMOD
-- ============================================================================

-- Загрузка инвентаря при выборе персонажа
hook.Add("SWExp::CharacterSelected", "SWExp::Inventory_LoadOnSelect", function(pPlayer, charData)
    if not IsValid(pPlayer) then return end

    SWExp.Inventory:LoadCharacterInventory(pPlayer, function(success)
        if success and IsValid(pPlayer) then
            -- Как только инвентарь загрузился из БД, возвращаем броню на место
            SWExp.Inventory:ApplyEquippedArmor(pPlayer)
            -- Синхронизируем NW-переменные для меток ассемблера и терминала исследований.
            -- Вызываем через небольшую паузу, чтобы все модули успели подписаться на хук.
            timer.Simple(0.5, function()
                if IsValid(pPlayer) then
                    hook.Run("SWExp::InventoryChanged", pPlayer)
                end
            end)
        end
    end)
end)

netstream.Hook("SWExp::InventoryMoveItem", function(pPlayer, data)
    if not RateOk(pPlayer, "InventoryMoveItem") then return end
    if not istable(data) then return end
    SWExp.Inventory:MoveItem(pPlayer, data.uniqueID, data.newX, data.newY, data.fromStorage, data.toStorage, data.rotated)
end)

netstream.Hook("SWExp::InventoryDropItem", function(pPlayer, data)
    if not RateOk(pPlayer, "InventoryDropItem") then return end
    if not istable(data) then return end
    SWExp.Inventory:DropItem(pPlayer, data.uniqueID, data.fromStorage)
end)

netstream.Hook("SWExp::InventoryEquipItem", function(pPlayer, data)
    if not RateOk(pPlayer, "InventoryEquipItem") then return end
    if not istable(data) then return end
    SWExp.Inventory:EquipItem(pPlayer, data.uniqueID, data.slotType, data.slotIndex, data.fromStorage)
end)

netstream.Hook("SWExp::InventoryUnequipItem", function(pPlayer, data)
    if not RateOk(pPlayer, "InventoryUnequipItem") then return end
    if not istable(data) then return end
    SWExp.Inventory:UnequipItem(pPlayer, data.slotType, data.slotIndex)
end)

-- Экипировка предмета прямо из сумки смерти (без прохода через инвентарь)
netstream.Hook("SWExp::InventoryEquipFromBag", function(pPlayer, data)
    if not RateOk(pPlayer, "InventoryEquipFromBag") then return end
    if not istable(data) then return end

    local ent = Entity(data.entIndex)
    if not IsValid(ent) or ent:GetPos():Distance(pPlayer:GetPos()) > SWExp.Inventory.Config.PickupRadius then return end

    local items = ent.GetItems and ent:GetItems() or {}
    local item = items[data.uniqueID]
    if not item then return end

    -- АТОМАРНО: удаляем предмет из сумки ПЕРВЫМ, чтобы исключить race condition / дюп.
    -- Если AddItem упадёт — вернём предмет в сумку.
    items[data.uniqueID] = nil
    if ent.SetItems then ent:SetItems(items) end

    local ok = SWExp.Inventory:AddItem(pPlayer, item.itemID, item.amount)
    if not ok then
        -- Откат: возвращаем предмет в сумку
        items[data.uniqueID] = item
        if ent.SetItems then ent:SetItems(items) end
        return
    end

    -- Экипируем: ищем uniqueID нового предмета в инвентаре
    local charID  = SWExp.Inventory:GetCharacterID(pPlayer)
    local steamID = pPlayer:SteamID64()
    local inv     = SWExp.Inventory.PlayerInventories[steamID] and SWExp.Inventory.PlayerInventories[steamID][charID]
    if not inv then return end

    -- Ищем только что добавленный предмет (по itemID)
    local newUID = nil
    for uid, invItem in pairs(inv.items or {}) do
        if invItem.itemID == item.itemID then
            newUID = uid
            break
        end
    end
    if not newUID then return end

    SWExp.Inventory:EquipItem(pPlayer, newUID, data.slotType, data.slotIndex, false)

    -- Обновляем сумку у клиента
    if table.Count(items) == 0 then
        netstream.Start(pPlayer, "SWExp::UpdateDeathBag", {entIndex = data.entIndex, items = items})
        timer.Simple(0.5, function()
            if IsValid(ent) then ent:Remove() end
        end)
    else
        netstream.Start(pPlayer, "SWExp::UpdateDeathBag", {entIndex = data.entIndex, items = items})
    end
end)

netstream.Hook("SWExp::InventoryUseItem", function(pPlayer, data)
    if not RateOk(pPlayer, "InventoryUseItem") then return end
    if not istable(data) then return end
    local charID = SWExp.Inventory:GetCharacterID(pPlayer)
    if not charID then return end
    local steamID = pPlayer:SteamID64()
    local storage = data.fromStorage and (SWExp.Inventory.PlayerStorages[steamID] and SWExp.Inventory.PlayerStorages[steamID][charID]) or (SWExp.Inventory.PlayerInventories[steamID] and SWExp.Inventory.PlayerInventories[steamID][charID])
    if not storage or not storage.items[data.uniqueID] then return end

    local item = storage.items[data.uniqueID]
    local itemData = SWExp.Inventory:GetItemData(item.itemID)

    if itemData and itemData.onUse then
        if itemData.onUse(pPlayer, item) then SWExp.Inventory:RemoveItem(pPlayer, data.uniqueID, 1, data.fromStorage) end
    end
end)

netstream.Hook("SWExp::InventoryTakeFromBag", function(pPlayer, data)
    if not RateOk(pPlayer, "InventoryTakeFromBag") then return end
    if not istable(data) then return end

    local ent = Entity(data.entIndex)
    if not IsValid(ent) or ent:GetPos():Distance(pPlayer:GetPos()) > SWExp.Inventory.Config.PickupRadius then return end

    local items = ent.GetItems and ent:GetItems() or {}
    local item = items[data.uniqueID]
    if not item then return end

    -- АТОМАРНО: удаляем из сумки ДО добавления игроку. Если не удастся — откатываем.
    items[data.uniqueID] = nil
    if ent.SetItems then ent:SetItems(items) end

    -- Обработка боезапаса из сумки смерти
    if item.isAmmo then
        if SWExp.Ammo and SWExp.Ammo.Give and SWExp.Ammo.Save then
            SWExp.Ammo:Give(pPlayer, item.ammoType, item.amount)
            SWExp.Ammo:Save(pPlayer)
            netstream.Start(pPlayer, "SWExp::UpdateDeathBag", {entIndex = data.entIndex, items = items})
            if table.Count(items) == 0 then
                timer.Simple(0.5, function()
                    if IsValid(ent) then ent:Remove() end
                end)
            end
        else
            -- Откат: SWExp.Ammo недоступен
            items[data.uniqueID] = item
            if ent.SetItems then ent:SetItems(items) end
            netstream.Start(pPlayer, "SWExp::UpdateDeathBag", {entIndex = data.entIndex, items = items})
        end
        return
    end

    if SWExp.Inventory:AddItem(pPlayer, item.itemID, item.amount) then

        -- Если клиент указал позицию и поворот — применяем через MoveItem
        local rotated = data.rotated or false
        local newX    = data.newX
        local newY    = data.newY
        if (rotated or (newX and newY)) then
            -- Ищем только что добавленный предмет по itemID
            local charID  = SWExp.Inventory:GetCharacterID(pPlayer)
            local steamID = pPlayer:SteamID64()
            local inv     = SWExp.Inventory.PlayerInventories[steamID] and SWExp.Inventory.PlayerInventories[steamID][charID]
            if inv then
                local newUID = nil
                for uid, invItem in pairs(inv.items or {}) do
                    if invItem.itemID == item.itemID then newUID = uid; break end
                end
                if newUID and (newX and newY) then
                    SWExp.Inventory:MoveItem(pPlayer, newUID, newX, newY, false, false, rotated)
                elseif newUID and rotated then
                    -- Нет конкретной позиции — просто перемещаем на то же место с поворотом
                    local invItem = inv.items[newUID]
                    if invItem then
                        SWExp.Inventory:MoveItem(pPlayer, newUID, invItem.posX, invItem.posY, false, false, rotated)
                    end
                end
            end
        end

        -- Всегда отправляем обновление клиенту (включая пустую таблицу — закроет окно)
        netstream.Start(pPlayer, "SWExp::UpdateDeathBag", {entIndex = data.entIndex, items = items})
        if table.Count(items) == 0 then
            timer.Simple(0.5, function()
                if IsValid(ent) then ent:Remove() end
            end)
        end
    else
        -- Откат: возвращаем предмет в сумку
        items[data.uniqueID] = item
        if ent.SetItems then ent:SetItems(items) end
        netstream.Start(pPlayer, "SWExp::UpdateDeathBag", {entIndex = data.entIndex, items = items})
    end
end)

hook.Add("PlayerSpawn", "SWExp::Inventory_ApplyArmorOnSpawn", function(pPlayer)
    -- Таймер 0.1 сек нужен, чтобы "перебить" стандартную модель из sv_chars.lua
    timer.Simple(0.1, function()
        if IsValid(pPlayer) then
            SWExp.Inventory:ApplyEquippedArmor(pPlayer)
        end
    end)
end)

netstream.Hook("SWExp::RequestInventoryOpen", function(pPlayer)
    if not RateOk(pPlayer, "InventoryOpen") then return end
    SWExp.Inventory:SyncInventoryToClient(pPlayer)
end)

-- Разделение стека: клиент просит отколоть splitAmount единиц в отдельный стек
netstream.Hook("SWExp::InventorySplitItem", function(pPlayer, data)
    if not RateOk(pPlayer, "InventorySplitItem") then return end
    if not istable(data) then return end
    SWExp.Inventory:SplitItem(pPlayer, data.uniqueID, data.amount, data.fromStorage)
end)

-- Объединение стеков: клиент перетащил один стек поверх другого того же предмета
netstream.Hook("SWExp::InventoryMergeItems", function(pPlayer, data)
    if not RateOk(pPlayer, "InventoryMergeItems") then return end
    if not istable(data) then return end
    SWExp.Inventory:MergeItems(pPlayer, data.sourceUID, data.targetUID, data.fromStorage, data.toStorage)
end)

-- ============================================================================
-- БЫСТРОЕ ПЕРЕМЕЩЕНИЕ (SHIFT + ЛКМ): авто-поиск свободного слота в цели
-- ============================================================================

-- Перемещает предмет из одного хранилища в другое, автоматически находя
-- первый свободный слот. Используется для Shift+Click в UI.
function SWExp.Inventory:QuickMoveItem(pPlayer, uniqueID, fromStorage, toStorage)
    if not IsValid(pPlayer) then return false, "Игрок не найден" end
    local charID = self:GetCharacterID(pPlayer)
    if not charID then return false, "Персонаж не загружен" end
    local steamID = pPlayer:SteamID64()

    local srcStorage = fromStorage
        and (self.PlayerStorages[steamID] and self.PlayerStorages[steamID][charID])
        or  (self.PlayerInventories[steamID] and self.PlayerInventories[steamID][charID])
    local dstStorage = toStorage
        and (self.PlayerStorages[steamID] and self.PlayerStorages[steamID][charID])
        or  (self.PlayerInventories[steamID] and self.PlayerInventories[steamID][charID])

    if not srcStorage or not srcStorage.items[uniqueID] then
        return false, "Предмет не найден"
    end
    if not dstStorage then return false, "Целевое хранилище не найдено" end

    local item     = srcStorage.items[uniqueID]
    local itemData = self:GetItemData(item.itemID)
    if not itemData then return false, "Данные предмета не найдены" end

    local dstGridW = toStorage and self.Config.StorageGridWidth  or self.Config.GridWidth
    local dstGridH = toStorage and self.Config.StorageGridHeight or self.Config.GridHeight

    -- Нормализуем поворот
    local rotated  = item.rotated == true or item.rotated == 1
    local baseW    = itemData.width  or 1
    local baseH    = itemData.height or 1
    local effW     = rotated and baseH or baseW
    local effH     = rotated and baseW or baseH

    -- Сначала пробуем с сохранением поворота, затем без поворота
    local fakeData = { width = effW, height = effH }
    local px, py = self:FindFreeSlot(dstStorage.grid, dstGridW, dstGridH, fakeData)

    -- Если с текущим поворотом не влезает — пробуем перевернуть
    if not px and (effW ~= effH) then
        fakeData = { width = effH, height = effW }
        px, py = self:FindFreeSlot(dstStorage.grid, dstGridW, dstGridH, fakeData)
        if px then rotated = not rotated end
    end

    if not px then return false, "Нет свободного места" end

    return self:MoveItem(pPlayer, uniqueID, px, py, fromStorage, toStorage, rotated)
end

-- Netstream: Shift+Click быстрое перемещение между инвентарём и хранилищем
netstream.Hook("SWExp::InventoryQuickMove", function(pPlayer, data)
    if not RateOk(pPlayer, "InventoryQuickMove") then return end
    if not istable(data) then return end
    SWExp.Inventory:QuickMoveItem(pPlayer, data.uniqueID, data.fromStorage, data.toStorage)
end)

hook.Add("PlayerDisconnected", "SWExp::Inventory_OnDisconnect", function(pPlayer)
    SWExp.Inventory:SaveCharacterInventory(pPlayer)
end)

hook.Add("PlayerDeath", "SWExp::Inventory_OnDeath", function(victim)
    if IsValid(victim) and SWExp.Inventory:GetCharacterID(victim) then
        timer.Simple(0.1, function() if IsValid(victim) then SWExp.Inventory:DropAllItems(victim, victim:GetPos()) end end)
    end
end)

-- ============================================================================
-- КОНСОЛЬНЫЕ КОМАНДЫ (АДМИН + ТЕСТЫ)
-- ============================================================================

-- Команда для выдачи предмета с нормальным выводом ошибок
concommand.Add("swexp_giveitem", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    
    local targetName = args[1]
    local itemID = args[2]
    local amount = tonumber(args[3]) or 1
    
    if not targetName or not itemID then 
        local msg = "[SWExp] Использование: swexp_giveitem <ник_или_часть_ника> <id_предмета> [кол-во]"
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print(msg) end
        return 
    end
    
    local targetPly = nil
    for _, p in ipairs(player.GetAll()) do
        if string.find(string.lower(p:Nick()), string.lower(targetName), 1, true) then 
            targetPly = p 
            break 
        end
    end
    
    if not IsValid(targetPly) then 
        local msg = "[SWExp] Ошибка: Игрок '" .. targetName .. "' не найден."
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print(msg) end
        return 
    end
    
    local success, err = SWExp.Inventory:AddItem(targetPly, itemID, amount)
    
    if success then
        local msg = "[SWExp] Успешно выдано: " .. itemID .. " (x" .. amount .. ") игроку " .. targetPly:Nick()
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print(msg) end
        targetPly:ChatPrint("Получено: " .. itemID .. " (x" .. amount .. ")")
    else
        local msg = "[SWExp] Ошибка выдачи: " .. tostring(err)
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print(msg) end
    end
end)

concommand.Add("swexp_listitems", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    for id, item in pairs(SWExp.Inventory.Items) do
        local msg = string.format("%-20s | %-15s | %s", id, item.slotType or "в инвентарь", item.name)
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print(msg) end
    end
end)

-- Тестовая команда swexp_test_setchar удалена из продакшна
-- (использовалась на этапе разработки для инициализации инвентаря без системы персонажей)

-- ОПАСНО: удаляет все таблицы инвентаря. Требует явного подтверждения CONFIRM.
concommand.Add("swexp_reset_inv_db", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end

    local confirm = args[1]
    if confirm ~= "CONFIRM" then
        local msg = "[SWExp] ОПАСНО! Эта команда удалит ВСЕ таблицы инвентаря. " ..
                    "Для выполнения: swexp_reset_inv_db CONFIRM"
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print(msg) end
        return
    end

    MySQLite.query("DROP TABLE IF EXISTS swexp_inventory;")
    MySQLite.query("DROP TABLE IF EXISTS swexp_storage;")
    MySQLite.query("DROP TABLE IF EXISTS swexp_equipment;")

    local who = IsValid(ply) and ply:Nick() or "CONSOLE"
    local logMsg = string.format("[SWExp] %s выполнил reset_inv_db. Требуется рестарт сервера.", who)
    if IsValid(ply) then
        ply:ChatPrint("[SWExp] Таблицы инвентаря удалены! Сделай рестарт сервера.")
    end
    print(logMsg)
end)

-- ============================================================================
-- СИСТЕМА АПТЕЧЕК: ХИЛ СО ВРЕМЕНЕМ (HoT — Heal over Time)
-- ============================================================================

SWExp.Inventory.HoTActive = SWExp.Inventory.HoTActive or {}  -- [steamID] = {ticksLeft, healPerTick}

--- Запускает хил со временем для игрока.
--- Если хил уже идёт — перезапускает с параметрами нового предмета.
function SWExp.Inventory:StartHoT(pPlayer, itemData)
    if not IsValid(pPlayer) then return end
    local sid   = pPlayer:SteamID64()
    local ticks = math.floor(itemData.healDuration / itemData.tickInterval)

    -- Прерываем старый таймер, если был
    if timer.Exists("SWExp::MedkitHoT_" .. sid) then
        timer.Remove("SWExp::MedkitHoT_" .. sid)
    end

    self.HoTActive[sid] = {
        ticksLeft    = ticks,
        totalTicks   = ticks,
        healPerTick  = itemData.healPerTick,
        tickInterval = itemData.tickInterval,
    }

    -- Сообщаем клиенту о старте хила
    netstream.Start(pPlayer, "SWExp::MedkitHoTState", {
        active       = true,
        duration     = itemData.healDuration,
        healPerTick  = itemData.healPerTick,
        tickInterval = itemData.tickInterval,
    })

    -- Запускаем серверный таймер
    timer.Create("SWExp::MedkitHoT_" .. sid, itemData.tickInterval, ticks, function()
        if not IsValid(pPlayer) then
            timer.Remove("SWExp::MedkitHoT_" .. sid)
            self.HoTActive[sid] = nil
            return
        end

        local state = self.HoTActive[sid]
        if not state then return end

        -- Лечим только живого игрока
        if pPlayer:Alive() then
            local newHP = math.min(pPlayer:Health() + state.healPerTick, pPlayer:GetMaxHealth())
            pPlayer:SetHealth(newHP)
        end

        state.ticksLeft = state.ticksLeft - 1

        -- Последний тик — завершаем
        if state.ticksLeft <= 0 then
            self.HoTActive[sid] = nil
            netstream.Start(pPlayer, "SWExp::MedkitHoTState", { active = false })
        end
    end)
end

--- Прерывает хил (например при смерти)
function SWExp.Inventory:StopHoT(pPlayer)
    if not IsValid(pPlayer) then return end
    local sid = pPlayer:SteamID64()
    timer.Remove("SWExp::MedkitHoT_" .. sid)
    if self.HoTActive[sid] then
        self.HoTActive[sid] = nil
        netstream.Start(pPlayer, "SWExp::MedkitHoTState", { active = false })
    end
end

-- Хотки: использование первой доступной аптечки из медицинского слота
netstream.Hook("SWExp::UseMedkitHotkey", function(pPlayer)
    if not RateOk(pPlayer, "UseMedkitHotkey") then return end
    if not IsValid(pPlayer) or not pPlayer:Alive() then return end

    -- Антиспам: нельзя применить аптечку если хил уже идёт
    local sid = pPlayer:SteamID64()
    if SWExp.Inventory.HoTActive[sid] then
        netstream.Start(pPlayer, "SWExp::MedkitHoTState", {
            active       = true,
            alreadyHealing = true,
        })
        return
    end

    local charID = SWExp.Inventory:GetCharacterID(pPlayer)
    if not charID then return end

    local equip = SWExp.Inventory.PlayerEquipment[sid]
    if not equip or not equip[charID] then return end

    local medSlots = equip[charID]["medical"]
    if not medSlots then return end

    -- Ищем первый заполненный медицинский слот
    local cfg = SWExp.Inventory.Config.EquipmentSlots["medical"]
    for i = 1, (cfg and cfg.total or 3) do
        local item = medSlots[i]
        if item then
            local itemData = SWExp.Inventory:GetItemData(item.itemID)
            if itemData and itemData.healType == "hot" then
                -- Уменьшаем стак / удаляем из слота
                if (item.amount or 1) > 1 then
                    medSlots[i].amount = (item.amount or 1) - 1
                else
                    medSlots[i] = nil
                    MySQLite.query(string.format(
                        "DELETE FROM swexp_equipment WHERE character_id = %d AND slot_type = %s AND slot_index = %d",
                        charID, MySQLite.SQLStr("medical"), i
                    ))
                end

                SWExp.Inventory:SaveCharacterInventory(pPlayer, charID)
                SWExp.Inventory:SyncInventoryToClient(pPlayer)

                -- Запускаем хил
                SWExp.Inventory:StartHoT(pPlayer, itemData)
                return
            end
        end
    end

    -- Нет аптечки в слоте
    netstream.Start(pPlayer, "SWExp::MedkitHoTState", { active = false, noMedkit = true })
end)

-- Прерываем хил при смерти
hook.Add("PlayerDeath", "SWExp::MedkitHoT_OnDeath", function(victim)
    SWExp.Inventory:StopHoT(victim)
end)

-- Чистим состояние при дисконнекте
hook.Add("PlayerDisconnected", "SWExp::MedkitHoT_OnDisconnect", function(pPlayer)
    local sid = pPlayer:SteamID64()
    timer.Remove("SWExp::MedkitHoT_" .. sid)
    SWExp.Inventory.HoTActive[sid] = nil
end)