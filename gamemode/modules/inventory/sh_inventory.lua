--[[--
    SWExp: Общая часть системы инвентаря (Shared)
    Модуль: inventory
]]--

SWExp.Inventory = SWExp.Inventory or {}

-- ============================================================================
-- КОНФИГУРАЦИЯ
-- ============================================================================

SWExp.Inventory.Config = {
    -- Размер сетки инвентаря персонажа (DayZ стиль)
    GridWidth = 10,
    GridHeight = 6,
    
    -- Размер сетки хранилища (Ассемблер / Корабль)
    StorageGridWidth = 15,
    StorageGridHeight = 10,
    
    -- Размер ячейки в пикселях (для UI)
    CellSize = 50,
    
    -- Типы слотов снаряжения
    SlotTypes = {
        PRIMARY = "primary",           -- Основное оружие
        SECONDARY = "secondary",       -- Второстепенное снаряжение
        HEAVY = "heavy",               -- Тяжёлое снаряжение
        SPECIAL = "special",           -- Специальное снаряжение (Крюк-кошка, щит и т.д.)
        MEDICAL = "medical",           -- Медицинское снаряжение
        GRENADE = "grenade",           -- Слоты под гранаты (3 шт.)
        ARMOR = "armor"                -- Слот класса/брони (НОВОЕ ИЗ GDD)
    },

    -- Конфигурация максимального числа слотов
    -- (Реальное количество доступных слотов теперь контролируется надетой бронёй в cl/sv)
    EquipmentSlots = {
        primary = { total = 2},
        secondary = { total = 2},
        heavy = { total = 1},
        special = { total = 3},
        medical = { total = 3},
        grenade = { total = 3}, -- 3 слота под гранаты, всегда открыты
        armor = { total = 1} -- Только один костюм одновременно
    },
    
    -- Время жизни выброшенных предметов (в секундах)
    DroppedItemLifetime = 300,
    
    -- Радиус подбора предметов
    PickupRadius = 100
}

-- ============================================================================
-- БАЗА ПРЕДМЕТОВ
-- ============================================================================

SWExp.Inventory.Items = {}

function SWExp.Inventory:RegisterItem(itemData)
    if not itemData.id then
        MsgC(Color(255, 0, 0), "[SWExp Inventory] Ошибка: предмет без ID!\n")
        return false
    end
    
    -- Значения по умолчанию
    itemData.width = itemData.width or 1
    itemData.height = itemData.height or 1
    itemData.stackable = itemData.stackable or false
    itemData.maxStack = itemData.maxStack or 1
    itemData.weight = itemData.weight or 0.1
    itemData.canDrop = itemData.canDrop ~= false
    itemData.rarity = itemData.rarity or "common"
    
    self.Items[itemData.id] = itemData
    return true
end

function SWExp.Inventory:GetItemData(itemID)
    return self.Items[itemID]
end

-- ============================================================================
-- РЕГИСТРАЦИЯ ПРЕДМЕТОВ ИЗ GDD
-- ============================================================================

-- Броня (Определяет класс, модель, слоты и поглощение урона)
SWExp.Inventory:RegisterItem({
    id = "armor_light_t1",
    name = "Лёгкая броня (Тир 1)",
    description = "Комплект разведчика.",
    icon = "swexpicon/swexp-armor-light.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "common",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 1,
    armorReduction = 0.10,
    armorClass = "light",
    playerModel = "models/sb_arf/sb_arf.mdl",
    classSWEP = "realistic_hook",
    isAvailableCloak = true
})

SWExp.Inventory:RegisterItem({
    id = "armor_light_t2",
    name = "Лёгкая броня (Тир 2)",
    description = "Комплект разведчика.",
    icon = "swexpicon/swexp-armor-light.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "uncommon",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 2,
    armorReduction = 0.15,
    armorClass = "light",
    playerModel = "models/sb_arf/sb_arf.mdl",
    classSWEP = "realistic_hook",
    isAvailableCloak = true
})

SWExp.Inventory:RegisterItem({
    id = "armor_light_t3",
    name = "Лёгкая броня (Тир 3)",
    description = "Комплект разведчика.",
    icon = "swexpicon/swexp-armor-light.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "rare",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 3,
    armorReduction = 0.20,
    armorClass = "light",
    playerModel = "models/sb_arf/sb_arf.mdl",
    classSWEP = "realistic_hook",
    isAvailableCloak = true
})

SWExp.Inventory:RegisterItem({
    id = "armor_light_t4",
    name = "Лёгкая броня (Тир 4)",
    description = "Комплект разведчика.",
    icon = "swexpicon/swexp-armor-light.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "epic",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 4,
    armorReduction = 0.25,
    armorClass = "light",
    playerModel = "models/sb_arf/sb_arf.mdl",
    classSWEP = "realistic_hook",
    isAvailableCloak = true
})

SWExp.Inventory:RegisterItem({
    id = "armor_light_t5",
    name = "Лёгкая броня (Тир 5)",
    description = "Комплект разведчика.",
    icon = "swexpicon/swexp-armor-light.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "legendary",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 5,
    armorReduction = 0.30,
    armorClass = "light",
    playerModel = "models/sb_arf/sb_arf.mdl",
    classSWEP = "realistic_hook",
    isAvailableCloak = true
})

SWExp.Inventory:RegisterItem({
    id = "armor_medium_t1",
    name = "Средняя броня (Тир 1)",
    description = "Стандартная броня клона.",
    icon = "swexpicon/swexp-armor-medium.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "common",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 1,
    armorReduction = 0.30,
    armorClass = "medium",
    playerModel = "models/sb_sld/sb_sld.mdl",
    classSWEP = nil,
    isAvailableCloak = false
})

SWExp.Inventory:RegisterItem({
    id = "armor_medium_t2",
    name = "Средняя броня (Тир 2)",
    description = "Стандартная броня клона.",
    icon = "swexpicon/swexp-armor-medium.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "uncommon",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 2,
    armorReduction = 0.35,
    armorClass = "medium",
    playerModel = "models/sb_sld/sb_sld.mdl",
    classSWEP = nil,
    isAvailableCloak = false
})

SWExp.Inventory:RegisterItem({
    id = "armor_medium_t3",
    name = "Средняя броня (Тир 3)",
    description = "Стандартная броня клона.",
    icon = "swexpicon/swexp-armor-medium.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "rare",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 3,
    armorReduction = 0.40,
    armorClass = "medium",
    playerModel = "models/sb_sld/sb_sld.mdl",
    classSWEP = nil,
    isAvailableCloak = false
})

SWExp.Inventory:RegisterItem({
    id = "armor_medium_t4",
    name = "Средняя броня (Тир 4)",
    description = "Стандартная броня клона.",
    icon = "swexpicon/swexp-armor-medium.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "epic",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 4,
    armorReduction = 0.45,
    armorClass = "medium",
    playerModel = "models/sb_sld/sb_sld.mdl",
    classSWEP = nil,
    isAvailableCloak = false
})

SWExp.Inventory:RegisterItem({
    id = "armor_medium_t5",
    name = "Средняя броня (Тир 5)",
    description = "Стандартная броня клона.",
    icon = "swexpicon/swexp-armor-medium.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "legendary",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 5,
    armorReduction = 0.50,
    armorClass = "medium",
    playerModel = "models/sb_sld/sb_sld.mdl",
    classSWEP = nil,
    isAvailableCloak = false
})

SWExp.Inventory:RegisterItem({
    id = "armor_heavy_t1",
    name = "Тяжёлая броня (Тир 1)",
    description = "Тяжёлая броня клона.",
    icon = "swexpicon/swexp-armor-heavy.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "common",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 1,
    armorReduction = 0.40,
    armorClass = "heavy",
    playerModel = "models/sb_heavy/sb_heavy.mdl",
    classSWEP = nil,
    isAvailableCloak = false
})

SWExp.Inventory:RegisterItem({
    id = "armor_heavy_t2",
    name = "Тяжёлая броня (Тир 2)",
    description = "Тяжёлая броня клона.",
    icon = "swexpicon/swexp-armor-heavy.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "uncommon",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 2,
    armorReduction = 0.45,
    armorClass = "heavy",
    playerModel = "models/sb_heavy/sb_heavy.mdl",
    classSWEP = nil,
    isAvailableCloak = false
})

SWExp.Inventory:RegisterItem({
    id = "armor_heavy_t3",
    name = "Тяжёлая броня (Тир 3)",
    description = "Тяжёлая броня клона.",
    icon = "swexpicon/swexp-armor-heavy.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "rare",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 3,
    armorReduction = 0.50,
    armorClass = "heavy",
    playerModel = "models/sb_heavy/sb_heavy.mdl",
    classSWEP = nil,
    isAvailableCloak = false
})

SWExp.Inventory:RegisterItem({
    id = "armor_heavy_t4",
    name = "Тяжёлая броня (Тир 4)",
    description = "Тяжёлая броня клона.",
    icon = "swexpicon/swexp-armor-heavy.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "epic",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 4,
    armorReduction = 0.55,
    armorClass = "heavy",
    playerModel = "models/sb_heavy/sb_heavy.mdl",
    classSWEP = nil,
    isAvailableCloak = false
})

SWExp.Inventory:RegisterItem({
    id = "armor_heavy_t5",
    name = "Тяжёлая броня (Тир 5)",
    description = "Тяжёлая броня клона.",
    icon = "swexpicon/swexp-armor-heavy.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "legendary",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 5,
    armorReduction = 0.60,
    armorClass = "heavy",
    playerModel = "models/sb_heavy/sb_heavy.mdl",
    classSWEP = nil,
    isAvailableCloak = false
})

SWExp.Inventory:RegisterItem({
    id = "armor_eng_t1",
    name = "Инженерная броня (Тир 1)",
    description = "Тяжёлая броня клона.",
    icon = "swexpicon/swexp-armor-eng.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "сommon",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 1,
    armorReduction = 0.25,
    armorClass = "engineer",
    playerModel = "models/sb_eng/sb_eng.mdl",
    classSWEP = "fort_datapad",
    isAvailableCloak = false
})

SWExp.Inventory:RegisterItem({
    id = "armor_eng_t2",
    name = "Инженерная броня (Тир 2)",
    description = "Тяжёлая броня клона.",
    icon = "swexpicon/swexp-armor-eng.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "unсommon",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 2,
    armorReduction = 0.30,
    armorClass = "engineer",
    playerModel = "models/sb_eng/sb_eng.mdl",
    classSWEP = "fort_datapad",
    isAvailableCloak = false
})

SWExp.Inventory:RegisterItem({
    id = "armor_eng_t3",
    name = "Инженерная броня (Тир 3)",
    description = "Тяжёлая броня клона.",
    icon = "swexpicon/swexp-armor-eng.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "rare",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 3,
    armorReduction = 0.35,
    armorClass = "engineer",
    playerModel = "models/sb_eng/sb_eng.mdl",
    classSWEP = "fort_datapad",
    isAvailableCloak = false
})

SWExp.Inventory:RegisterItem({
    id = "armor_eng_t4",
    name = "Инженерная броня (Тир 4)",
    description = "Тяжёлая броня клона.",
    icon = "swexpicon/swexp-armor-eng.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "epic",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 4,
    armorReduction = 0.40,
    armorClass = "engineer",
    playerModel = "models/sb_eng/sb_eng.mdl",
    classSWEP = "fort_datapad",
    isAvailableCloak = false
})

SWExp.Inventory:RegisterItem({
    id = "armor_eng_t5",
    name = "Инженерная броня (Тир 5)",
    description = "Тяжёлая броня клона.",
    icon = "swexpicon/swexp-armor-eng.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "legendary",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 5,
    armorReduction = 0.45,
    armorClass = "engineer",
    playerModel = "models/sb_eng/sb_eng.mdl",
    classSWEP = "fort_datapad",
    isAvailableCloak = false
})

SWExp.Inventory:RegisterItem({
    id = "armor_med_t1",
    name = "Броня медика (Тир 1)",
    description = "Медецинская броня клона.",
    icon = "swexpicon/swexp-armor-medic.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "common",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 1,
    armorReduction = 0.25,
    armorClass = "medical",
    playerModel = "models/sb_med/sb_med.mdl",
    classSWEP = {"weapon_defibrillator", "arccw_stimpistol"},
    isAvailableCloak = false
})

SWExp.Inventory:RegisterItem({
    id = "armor_med_t2",
    name = "Броня медика (Тир 2)",
    description = "Медецинская броня клона.",
    icon = "swexpicon/swexp-armor-medic.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "uncommon",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 2,
    armorReduction = 0.30,
    armorClass = "medical",
    playerModel = "models/sb_med/sb_med.mdl",
    classSWEP = {"weapon_defibrillator", "arccw_stimpistol"},
    isAvailableCloak = false
})

SWExp.Inventory:RegisterItem({
    id = "armor_med_t3",
    name = "Броня медика (Тир 3)",
    description = "Медецинская броня клона.",
    icon = "swexpicon/swexp-armor-medic.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "rare",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 3,
    armorReduction = 0.35,
    armorClass = "medical",
    playerModel = "models/sb_med/sb_med.mdl",
    classSWEP = {"weapon_defibrillator", "arccw_stimpistol"},
    isAvailableCloak = false
})

SWExp.Inventory:RegisterItem({
    id = "armor_med_t4",
    name = "Броня медика (Тир 4)",
    description = "Медецинская броня клона.",
    icon = "swexpicon/swexp-armor-medic.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "epic",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 4,
    armorReduction = 0.40,
    armorClass = "medical",
    playerModel = "models/sb_med/sb_med.mdl",
    classSWEP = {"weapon_defibrillator", "arccw_stimpistol"},
    isAvailableCloak = false
})

SWExp.Inventory:RegisterItem({
    id = "armor_med_t5",
    name = "Броня медика (Тир 5)",
    description = "Медецинская броня клона.",
    icon = "swexpicon/swexp-armor-medic.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "legendary",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 5,
    armorReduction = 0.45,
    armorClass = "medical",
    playerModel = "models/sb_med/sb_med.mdl",
    classSWEP = {"weapon_defibrillator", "arccw_stimpistol"},
    isAvailableCloak = false
})


-- Строительные ресурсы (фортификации)
SWExp.Inventory:RegisterItem({
    id          = "fort_supply",
    name        = "Строительные ресурсы",
    description = "Пакет полевых материалов для возведения фортификаций. Производится на Ассемблере.",
    icon        = "icon16/brick.png",
    width       = 2,
    height      = 2,
    stackable   = true,
    maxStack    = 50,
    rarity      = "common",
    canDrop     = true,
})

-- Экспедиционные предметы
SWExp.Inventory:RegisterItem({
    id = "tool_flashlight",
    name = "Фонарик",
    description = "Стандартный фонарик. Экипируйте в специальный слот — тогда клавиша фонарика (F) будет работать.",
    icon = "icon16/lightbulb.png",
    width = 1,
    height = 2,
    slotType = "special",
    rarity = "uncommon",
    canDrop = true,
})

SWExp.Inventory:RegisterItem({
    id = "tool_scanner",
    name = "Научный сканер",
    description = "Необходим для сканирования аномалий и Вонгских биотехнологий. При потере крафтится заново.",
    icon = "swexpicon/swexp-swexp-atom.png",
    width = 2,
    height = 2,
    slotType = "special",
    rarity = "epic",
    worldModel = "models/weapons/sci-fi/w_sci_fi_pistol.mdl",
    weaponClass = "swexp_scanner"
})

SWExp.Inventory:RegisterItem({
    id = "key_tier1",
    name = "Ключ врат (Tier 1)",
    description = "Позволяет пройти во Вторую Зону планеты.",
    icon = "swexpicon/swexp-unlock.png",
    width = 1,
    height = 1,
    canDrop = true,
    rarity = "uncommon",
    worldModel = "models/props_junk/PopCan01a.mdl",
    portalTier = 1
})

SWExp.Inventory:RegisterItem({
    id = "key_tier2",
    name = "Ключ врат (Tier 2)",
    description = "Позволяет пройти в Третью Зону планеты.",
    icon = "swexpicon/swexp-unlock.png",
    width = 1,
    height = 1,
    canDrop = true,
    rarity = "rare",
    worldModel = "models/props_junk/PopCan01a.mdl",
    portalTier = 2
})

SWExp.Inventory:RegisterItem({
    id = "key_tier3",
    name = "Ключ врат (Tier 3)",
    description = "Позволяет пройти в Четвёртую Зону планеты.",
    icon = "swexpicon/swexp-unlock.png",
    width = 1,
    height = 1,
    canDrop = true,
    rarity = "epic",
    worldModel = "models/props_junk/PopCan01a.mdl",
    portalTier = 3
})

SWExp.Inventory:RegisterItem({
    id = "key_tier4",
    name = "Ключ врат (Tier 4)",
    description = "Позволяет пройти в Сердце Тьмы — самую опасную зону планеты.",
    icon = "swexpicon/swexp-unlock.png",
    width = 1,
    height = 1,
    canDrop = true,
    rarity = "legendary",
    worldModel = "models/props_junk/PopCan01a.mdl",
    portalTier = 4
})

-- Медикаменты
SWExp.Inventory:RegisterItem({
    id = "medkit",
    name = "Аптечка",
    description = "Постепенно восстанавливает 50 HP за 10 секунд (5 HP/сек)",
    icon = "swexpicon/swexp-health.png",
    width = 2,
    height = 1,
    slotType = "medical",
    rarity = "common",
    worldModel = "models/props_lab/jar001a.mdl",
    -- Параметры хила со временем (HoT)
    healType     = "hot",       -- Heal over Time
    healPerTick  = 5,           -- HP за каждый тик
    tickInterval = 1.0,         -- Интервал между тиками (секунды)
    healDuration = 10,          -- Общая длительность (секунды) → 5 * 10 = 50 HP
})

SWExp.Inventory:RegisterItem({
    id = "medkit_advanced",
    name = "Улучшенная аптечка",
    description = "Постепенно восстанавливает 100 HP за 10 секунд (10 HP/сек)",
    icon = "swexpicon/swexp-health.png",
    width = 2,
    height = 2,
    slotType = "medical",
    rarity = "uncommon",
    worldModel = "models/props_lab/jar001a.mdl",
    healType     = "hot",
    healPerTick  = 10,
    tickInterval = 1.0,
    healDuration = 10,
})

-- Оружие
SWExp.Inventory:RegisterItem({
    id = "weapon_dc15a",
    name = "DC-15A ",
    description = "",
    icon = "swexpicon/swexp-dc-15a.png",
    width = 4,
    height = 2,
    slotType = "primary",
    rarity = "common",
    worldModel = "models/weapons/w_ar2.mdl",
    weaponClass = "weapon_ar2"
})

SWExp.Inventory:RegisterItem({
    id = "weapon_z6",
    name = "Z-6 Роторная пушка",
    description = "Тяжёлая роторная бластерная пушка",
    icon = "icon16/bomb.png",
    width = 5,
    height = 3,
    slotType = "heavy",
    rarity = "rare",
    worldModel = "models/weapons/w_rpg.mdl",
    weaponClass = "arc9_sw_z6"
})

-- Материалы
SWExp.Inventory:RegisterItem({
    id          = "mat_basic",
    name        = "Материалы",
    description = "Ресурс добычи. Сдайте на Ассемблере — поступят в общий банк отряда.",
    icon        = "icon16/settings.png",
    width       = 1,
    height      = 1,
    stackable   = true,
    maxStack    = 50,
    rarity      = "common",
    category    = "material",
    canDrop     = true,
    worldModel  = "models/props_junk/garbage_metalcan001a.mdl"
})

-- Очки исследования (хранятся в инвентаре до сдачи на терминале)
SWExp.Inventory:RegisterItem({
    id          = "research_data",
    name        = "Данные исследования",
    description = "Полевые данные, собранные сканером. Сдайте на терминале исследований для пополнения банка ОИ.",
    icon        = "icon16/battery.png",
    width       = 1,
    height      = 1,
    stackable   = true,
    maxStack    = 50,
    canDrop     = false,
    rarity      = "uncommon",
})

-- ============================================================================
-- УТИЛИТЫ СЕТКИ
-- ============================================================================

function SWExp.Inventory:CanFitItem(grid, gridWidth, gridHeight, itemData, posX, posY)
    if not itemData then return false end
    
    local itemWidth = itemData.width or 1
    local itemHeight = itemData.height or 1
    
    if posX < 1 or posY < 1 then return false end
    if posX + itemWidth - 1 > gridWidth then return false end
    if posY + itemHeight - 1 > gridHeight then return false end
    
    for x = posX, posX + itemWidth - 1 do
        for y = posY, posY + itemHeight - 1 do
            local key = x .. "_" .. y
            if grid[key] then return false end
        end
    end
    
    return true
end

function SWExp.Inventory:FindFreeSlot(grid, gridWidth, gridHeight, itemData)
    if not itemData then return nil, nil end
    
    local itemWidth = itemData.width or 1
    local itemHeight = itemData.height or 1
    
    for y = 1, gridHeight - itemHeight + 1 do
        for x = 1, gridWidth - itemWidth + 1 do
            if self:CanFitItem(grid, gridWidth, gridHeight, itemData, x, y) then
                return x, y
            end
        end
    end
    
    return nil, nil
end

-- ============================================================================
-- СЕРИАЛИЗАЦИЯ / ВИЗУАЛ
-- ============================================================================

function SWExp.Inventory:SerializeInventory(inventoryData)
    return util.TableToJSON(inventoryData)
end

function SWExp.Inventory:DeserializeInventory(jsonString)
    if not jsonString or jsonString == "" then return {} end
    return util.JSONToTable(jsonString) or {}
end

function SWExp.Inventory:GetRarityColor(rarity)
    local colors = {
        common = Color(168, 204, 220),   -- SWUI Text
        uncommon = Color(0, 238, 119),   -- SWUI Green
        rare = Color(0, 184, 255),       -- SWUI Accent
        epic = Color(163, 53, 238),      -- Фиолетовый
        legendary = Color(255, 136, 0)   -- SWUI Warn
    }
    return colors[rarity] or colors.common
end

function SWExp.Inventory:GetRarityName(rarity)
    local names = {
        common = "Обычный",
        uncommon = "Необычный",
        rare = "Редкий",
        epic = "Эпический",
        legendary = "Легендарный"
    }
    return names[rarity] or names.common
end

print("[SWExp] Модуль инвентаря (shared) загружен!")