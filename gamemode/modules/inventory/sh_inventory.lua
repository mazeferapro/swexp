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
    playerModel = "models/ct_arf/ct_arf.mdl",
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
    playerModel = "models/ct_arf/ct_arf.mdl",
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
    playerModel = "models/ct_arf/ct_arf.mdl",
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
    playerModel = "models/ct_arf/ct_arf.mdl",
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
    playerModel = "models/ct_arf/ct_arf.mdl",
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
    playerModel = "models/ct_pvt/ct_pvt.mdl",
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
    playerModel = "models/ct_pvt/ct_pvt.mdl",
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
    playerModel = "models/ct_pvt/ct_pvt.mdl",
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
    playerModel = "models/ct_pvt/ct_pvt.mdl",
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
    playerModel = "models/ct_pvt/ct_pvt.mdl",
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
    playerModel = "models/ct_heavy/ct_heavy.mdl",
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
    playerModel = "models/ct_heavy/ct_heavy.mdl",
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
    playerModel = "models/ct_heavy/ct_heavy.mdl",
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
    playerModel = "models/ct_heavy/ct_heavy.mdl",
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
    playerModel = "models/ct_heavy/ct_heavy.mdl",
    classSWEP = nil,
    isAvailableCloak = false
})

SWExp.Inventory:RegisterItem({
    id = "armor_arc",
    name = "Броня ARC (Тир 4)",
    description = "Тяжёлая броня клона.",
    icon = "swexpicon/swexp-armor-heavy.png",
    width = 3,
    height = 4,
    slotType = "armor",
    rarity = "epic",
    worldModel = "models/vortexgaming/tc13u/armor/chest.mdl",
    -- Уникальные параметры для sv_inventory
    armorTier = 4,
    armorReduction = 0.50,
    armorClass = "heavy",
    playerModel = "models/ct_arc/ct_arc.mdl",
    classSWEP = {"fort_datapad", "weapon_lvsrepair", "arccw_stimpistol", "weapon_defibrillator", "realistic_hook"},
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
    playerModel = "models/ct_eng/ct_eng.mdl",
    classSWEP = {"fort_datapad", "weapon_lvsrepair"},
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
    playerModel = "models/ct_eng/ct_eng.mdl",
    classSWEP = {"fort_datapad", "weapon_lvsrepair"},
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
    playerModel = "models/ct_eng/ct_eng.mdl",
    classSWEP = {"fort_datapad", "weapon_lvsrepair"},
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
    classSWEP = {"fort_datapad", "weapon_lvsrepair"},
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
    playerModel = "models/ct_eng/ct_eng.mdl",
    classSWEP = {"fort_datapad", "weapon_lvsrepair"},
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
    playerModel = "models/ct_med/ct_med.mdl",
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
    playerModel = "models/ct_med/ct_med.mdl",
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
    playerModel = "models/ct_med/ct_med.mdl",
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
    playerModel = "models/ct_med/ct_med.mdl",
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
    playerModel = "models/ct_med/ct_med.mdl",
    classSWEP = {"weapon_defibrillator", "arccw_stimpistol"},
    isAvailableCloak = false
})


-- Строительные ресурсы (фортификации)
SWExp.Inventory:RegisterItem({
    id          = "fort_supply",
    name        = "Строительные ресурсы",
    description = "Пакет полевых материалов для возведения фортификаций. Производится на Ассемблере.",
    icon        = "swexpicon/swexp-up.png",
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
    icon = "swexpicon//swexp-flash.png",
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
    worldModel = "models/helios/props/precursor_holocron_key.mdl",
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
    worldModel = "models/helios/props/precursor_holocron_key.mdl",
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
    worldModel = "models/helios/props/precursor_holocron_key.mdl",
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
    worldModel = "models/helios/props/precursor_holocron_key.mdl",
    portalTier = 4
})

-- Медикаменты
SWExp.Inventory:RegisterItem({
    id = "medkit",
    name = "Аптечка",
    description = "Постепенно восстанавливает 20 HP за 10 секунд (2 HP/сек)",
    icon = "swexpicon/swexp-health.png",
    width = 2,
    height = 1,
    slotType = "medical",
    rarity = "common",
    worldModel = "models/props/starwars/medical/ammo_pickup.mdl",
    -- Параметры хила со временем (HoT)
    healType     = "hot",       -- Heal over Time
    healPerTick  = 2,           -- HP за каждый тик
    tickInterval = 1.0,         -- Интервал между тиками (секунды)
    healDuration = 10,          -- Общая длительность (секунды) → 5 * 10 = 50 HP
})

SWExp.Inventory:RegisterItem({
    id = "medkit_advanced",
    name = "Улучшенная аптечка",
    description = "Постепенно восстанавливает 40 HP за 10 секунд (4 HP/сек)",
    icon = "swexpicon/swexp-health.png",
    width = 2,
    height = 2,
    slotType = "medical",
    rarity = "uncommon",
    worldModel = "models/props/starwars/medical/ammo_pickup.mdl",
    healType     = "hot",
    healPerTick  = 4,
    tickInterval = 1.0,
    healDuration = 10,
})

SWExp.Inventory:RegisterItem({
    id = "medkit_sci",
    name = "Научная аптечка",
    description = "Постепенно восстанавливает 60 HP за 10 секунд (6 HP/сек)",
    icon = "swexpicon/swexp-health.png",
    width = 2,
    height = 2,
    slotType = "medical",
    rarity = "rare",
    worldModel = "models/props/starwars/medical/ammo_pickup.mdl",
    healType     = "hot",
    healPerTick  = 6,
    tickInterval = 1.0,
    healDuration = 10,
})

SWExp.Inventory:RegisterItem({
    id = "medkit_exo",
    name = "Экзо-аптечка",
    description = "Постепенно восстанавливает 80 HP за 10 секунд (80 HP/сек)",
    icon = "swexpicon/swexp-health.png",
    width = 2,
    height = 2,
    slotType = "medical",
    rarity = "epic",
    worldModel = "models/props/starwars/medical/ammo_pickup.mdl",
    healType     = "hot",
    healPerTick  = 8,
    tickInterval = 1.0,
    healDuration = 10,
})

SWExp.Inventory:RegisterItem({
    id = "medkit_nanit",
    name = "Нанитная аптечка",
    description = "Постепенно восстанавливает 100 HP за 10 секунд (10 HP/сек)",
    icon = "swexpicon/swexp-health.png",
    width = 2,
    height = 2,
    slotType = "medical",
    rarity = "legendary",
    worldModel = "models/props/starwars/medical/ammo_pickup.mdl",
    healType     = "hot",
    healPerTick  = 10,
    tickInterval = 1.0,
    healDuration = 10,
})

-- Оружие
SWExp.Inventory:RegisterItem({
    id = "weapon_dc15a",
    name = "DC-15A",
    description = "",
    icon = "swexpicon/swexp-dc-15a.png",
    width = 5,
    height = 2,
    slotType = "primary",
    rarity = "uncommon",
    worldModel = "models/arccw/kraken/republic/world/w_dc15a.mdl",
    weaponClass = "arccw_k_dc15a"
})

SWExp.Inventory:RegisterItem({
    id = "weapon_dc15ag",
    name = "DC-15AG",
    description = "",
    icon = "swexpicon/swexp-dc-15ag.png",
    width = 5,
    height = 2,
    slotType = "primary",
    rarity = "rare",
    worldModel = "models/arccw/kraken/republic/world/w_dc15a.mdl",
    weaponClass = "arccw_k_dc15a_grenadier"
})

SWExp.Inventory:RegisterItem({
    id = "weapon_dc15s",
    name = "DC-15S",
    description = "",
    icon = "swexpicon/swexp-dc-15s.png",
    width = 4,
    height = 2,
    slotType = "primary",
    rarity = "common",
    worldModel = "models/arccw/kraken/republic/world/w_dc15s.mdl",
    weaponClass = "arccw_k_dc15s"
})

SWExp.Inventory:RegisterItem({
    id = "weapon_dc15sg",
    name = "DC-15SG",
    description = "",
    icon = "swexpicon/swexp-dc-15sg.png",
    width = 4,
    height = 2,
    slotType = "primary",
    rarity = "uncommon",
    worldModel = "models/arccw/kraken/republic/world/w_dc15s.mdl",
    weaponClass = "arccw_k_dc15s_grenadier"
})

SWExp.Inventory:RegisterItem({
    id = "weapon_dc15x",
    name = "DC-15X",
    description = "",
    icon = "swexpicon/swexp-dc-15x.png",
    width = 6,
    height = 2,
    slotType = "primary",
    rarity = "uncommon",
    worldModel = "models/arccw/kraken/republic/world/w_dc15x.mdl",
    weaponClass = "arccw_k_dc15x"
})

SWExp.Inventory:RegisterItem({
    id = "weapon_dc17",
    name = "DC-17",
    description = "",
    icon = "swexpicon/swexp-dc-17.png",
    width = 2,
    height = 2,
    slotType = "secondary",
    rarity = "common",
    worldModel = "models/arccw/kraken/republic/world/w_dc17.mdl",
    weaponClass = "arccw_k_dc17"
})

SWExp.Inventory:RegisterItem({
    id = "weapon_dc17e",
    name = "DC-17 улучшеный",
    description = "",
    icon = "swexpicon/swexp-dc-17.png",
    width = 2,
    height = 2,
    slotType = "secondary",
    rarity = "uncommon",
    worldModel = "models/arccw/kraken/republic/world/w_dc17ext.mdl",
    weaponClass = "arccw_k_dc17ext"
})

SWExp.Inventory:RegisterItem({
    id = "weapon_dc17de",
    name = "DC-17 Двойные улучшенные",
    description = "",
    icon = "swexpicon/swexp-dc-17d.png",
    width = 2,
    height = 2,
    slotType = "secondary",
    rarity = "rare",
    worldModel = "models/arccw/kraken/republic/world/w_dc17ext.mdl",
    weaponClass = "arccw_k_dc17ext_akimbo"
})

SWExp.Inventory:RegisterItem({
    id = "weapon_dc17d",
    name = "DC-17 Двойные",
    description = "",
    icon = "swexpicon/swexp-dc-17d.png",
    width = 2,
    height = 2,
    slotType = "secondary",
    rarity = "uncommon",
    worldModel = "models/arccw/kraken/republic/world/w_dc17.mdl",
    weaponClass = "arccw_k_dc17_akimbo"
})

SWExp.Inventory:RegisterItem({
    id = "weapon_dp23",
    name = "DP-23",
    description = "",
    icon = "swexpicon/swexp-dp-23.png",
    width = 4,
    height = 2,
    slotType = "primary",
    rarity = "rare",
    worldModel = "models/arccw/kraken/republic/world/w_dp23.mdl",
    weaponClass = "arccw_k_dp23"
})

SWExp.Inventory:RegisterItem({
    id = "weapon_dp23c",
    name = "DP-23C",
    description = "",
    icon = "swexpicon/swexp-dp-23c.png",
    width = 4,
    height = 2,
    slotType = "primary",
    rarity = "epic",
    worldModel = "models/arccw/kraken/republic/world/w_dp23c.mdl",
    weaponClass = "arccw_k_dp23c"
})

SWExp.Inventory:RegisterItem({
    id = "weapon_dp24",
    name = "DP-24",
    description = "",
    icon = "swexpicon/swexp-dp-24.png",
    width = 4,
    height = 2,
    slotType = "primary",
    rarity = "uncommon",
    worldModel = "models/arccw/kraken/republic/world/w_dp24.mdl",
    weaponClass = "arccw_k_dp24"
})

SWExp.Inventory:RegisterItem({
    id = "weapon_",
    name = "DP-24C",
    description = "",
    icon = "swexpicon/swexp-dp-24c.png",
    width = 4,
    height = 2,
    slotType = "primary",
    rarity = "rare",
    worldModel = "models/arccw/kraken/republic/world/w_dp24c.mdl",
    weaponClass = "arccw_k_dp24c"
})


SWExp.Inventory:RegisterItem({
    id = "weapon_e9",
    name = "E-9",
    description = "",
    icon = "swexpicon/swexp-e9.png",
    width = 3,
    height = 2,
    slotType = "primary",
    rarity = "rare",
    worldModel = "models/arccw/kraken/republic/world/w_e9.mdl",
    weaponClass = "arccw_k_republic_e9"
})

SWExp.Inventory:RegisterItem({
    id = "weapon_g125",
    name = "G-125",
    description = "",
    icon = "swexpicon/swexp-g125.png",
    width = 4,
    height = 2,
    slotType = "secondary",
    rarity = "legendary",
    worldModel = "models/arccw/kraken/sw/explosives/world/w_g125.mdl",
    weaponClass = "arccw_k_weapon_g125"
})

SWExp.Inventory:RegisterItem({
    id = "weapon_hh12",
    name = "HH-12",
    description = "",
    icon = "swexpicon/swexp-hh12.png",
    width = 5,
    height = 3,
    slotType = "heavy",
    rarity = "rare",
    worldModel = "models/arccw/kraken/sw/explosives/world/w_hh12_republic.mdl",
    weaponClass = "arccw_k_launcher_hh12"
})

SWExp.Inventory:RegisterItem({
    id = "weapon_dc15le",
    name = "DC-15LE",
    description = "",
    icon = "swexpicon/swexp-dc-15le.png",
    width = 5,
    height = 2,
    slotType = "primary",
    rarity = "rare",
    worldModel = "models/arccw/kraken/republic/world/w_dc15a.mdl",
    weaponClass = "arccw_k_dc15le"
})

SWExp.Inventory:RegisterItem({
    id = "weapon_rps6",
    name = "RPS-6",
    description = "",
    icon = "swexpicon/swexp-rps-6.png",
    width = 7,
    height = 3,
    slotType = "heavy",
    rarity = "uncommon",
    worldModel = "models/arccw/kraken/sw/explosives/world/w_rps6_republic.mdl",
    weaponClass = "arccw_k_launcher_rps6"
})

SWExp.Inventory:RegisterItem({
    id = "weapon_smartlauncher",
    name = "Smart Launcher",
    description = "",
    icon = "swexpicon/swexp-smart-launcher.png",
    width = 7,
    height = 2,
    slotType = "primary",
    rarity = "rare",
    worldModel = "models/arccw/kraken/sw/explosives/world/w_smartlauncher.mdl",
    weaponClass = "arccw_k_launcher_smartlauncher"
})

SWExp.Inventory:RegisterItem({
    id = "weapon_westarm5",
    name = "Westarm-5",
    description = "",
    icon = "swexpicon/swexp-westarm5.png",
    width = 4,
    height = 2,
    slotType = "primary",
    rarity = "epic",
    worldModel = "models/arccw/kraken/republic/world/w_westar.mdl",
    weaponClass = "arccw_k_westarm5"
})

SWExp.Inventory:RegisterItem({
    id = "weapon_antimaterial",
    name = "K-43",
    description = "",
    icon = "swexpicon/swexp-anti-material.png",
    width = 4,
    height = 2,
    slotType = "primary",
    rarity = "legendary",
    worldModel = "models/arccw/kraken/sw/explosives/world/w_sw_antimaterial.mdl",
    weaponClass = "arccw_k_weapon_antimaterial"
})

SWExp.Inventory:RegisterItem({
    id = "weapon_z6",
    name = "Z-6",
    description = "Тяжёлая роторная бластерная пушка",
    icon = "swexpicon/swexp-z6.png",
    width = 5,
    height = 3,
    slotType = "heavy",
    rarity = "uncommon",
    worldModel = "models/arccw/kraken/republic/world/w_z6.mdl",
    weaponClass = "arccw_k_z6"
})

SWExp.Inventory:RegisterItem({
    id = "weapon_z6a",
    name = "Z-6 Улучшенная",
    description = "Улучшенная тяжёлая роторная бластерная пушка",
    icon = "swexpicon/swexp-z6.png",
    width = 5,
    height = 3,
    slotType = "heavy",
    rarity = "rare",
    worldModel = "models/arccw/kraken/republic/world/w_z6.mdl",
    weaponClass = "arccw_k_z6adv"
})

SWExp.Inventory:RegisterItem({
    id = "weapon_plx1",
    name = "PLX-1",
    description = "",
    icon = "swexpicon/swexp-plx-1.png",
    width = 8,
    height = 3,
    slotType = "heavy",
    rarity = "epic",
    worldModel = "models/arccw/kraken/sw/explosives/world/w_plx1_republic.mdl",
    weaponClass = "arccw_k_launcher_plx1"
})

-- Обвесы

SWExp.Inventory:RegisterItem({
    id          = "att_a180_barrel_extended",
    name        = "Extended Barrel",
    description = "Improves ranged performance, but at the cost of mobility.",
    icon        = "entities/kraken/sops/atts/a180barrel.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "a180_barrel_extended",
})

SWExp.Inventory:RegisterItem({
    id          = "att_a180_grip",
    name        = "Tactical Grip",
    description = "Improves recoil at the cost of aim time.",
    icon        = "entities/kraken/sops/atts/a180grip.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "a180_grip",
})

SWExp.Inventory:RegisterItem({
    id          = "att_a280cfe_barrel_short",
    name        = "Shortbarrel",
    description = "Offers superior handling at the cost of performance.",
    icon        = "entities/kraken/sops/atts/cfeshort.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "a280cfe_barrel_short",
})

SWExp.Inventory:RegisterItem({
    id          = "att_a280cfe_barrel_sniper",
    name        = "Sniper Barrel",
    description = "Improves ranged performance, but at the cost of mobility.",
    icon        = "entities/kraken/sops/atts/cfesniper.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "a280cfe_barrel_sniper",
})

SWExp.Inventory:RegisterItem({
    id          = "att_a280cfe_powerpack",
    name        = "Extended-power",
    description = "More tibanna compression. More damage at the cost of less magazine capacity.",
    icon        = "entities/kraken/sops/atts/cfepowerpack.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "a280cfe_powerpack",
})

SWExp.Inventory:RegisterItem({
    id          = "att_a280cfe_stock_assault",
    name        = "Assault Stock",
    description = "Lightweight stock. Improves ADS speed at the cost of recoil.",
    icon        = "entities/kraken/sops/atts/assaultstock.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "a280cfe_stock_assault",
})

SWExp.Inventory:RegisterItem({
    id          = "att_a280cfe_stock_heavy",
    name        = "Heavy Stock",
    description = "Heavy stocK. Improves recoil.",
    icon        = "entities/kraken/sops/atts/cfe_heavystock.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "a280cfe_stock_heavy",
})

SWExp.Inventory:RegisterItem({
    id          = "att_ammunition_ap",
    name        = "APCR Projectile",
    description = "APCR (Armored Piercing Capped Rigid) rounds are designed to penetrate armor using a core of harder material, often tungsten or steel, encased in a metal cap. The cap helps the core maintain its shape and effectiveness upon impact.",
    icon        = "entities/kraken/ap_ammo.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "ammunition_ap",
})

SWExp.Inventory:RegisterItem({
    id          = "att_ammunition_cluster",
    name        = "Cluster Rocket",
    description = "A rocket equipped with cluster munitions, dispersing multiple smaller explosives upon detonation.",
    icon        = "entities/kraken/rocket_cluster.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "ammunition_cluster",
})

SWExp.Inventory:RegisterItem({
    id          = "att_ammunition_heat",
    name        = "HEAT Projectile",
    description = "HEAT (High Explosive Anti-Tank) rounds use a shaped charge to focus explosive energy on a small point, allowing them to penetrate light armored vehicles.",
    icon        = "entities/kraken/heat_ammo.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "ammunition_heat",
})

SWExp.Inventory:RegisterItem({
    id          = "att_ammunition_heatfs",
    name        = "HEAT-FS Projectile",
    description = "HEAT-FS (High Explosive Anti-Tank Fin-Stabilized) rounds are designed to penetrate armored vehicles. They use a shaped charge that focuses an explosive blast on a small point to melt through the armor, allowing the round to disable or destroy the target. The",
    icon        = "entities/kraken/heatfs_ammo.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "ammunition_heatfs",
})

SWExp.Inventory:RegisterItem({
    id          = "att_ammunition_track",
    name        = "Trackable Rocket",
    description = "A rocket equipped with tracking capabilities, allowing it to follow targets more effectively.",
    icon        = "entities/kraken/rocket_saclos.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "ammunition_track",
})

SWExp.Inventory:RegisterItem({
    id          = "att_arccw_k_dc15a_scope_ir",
    name        = "DC-15A Scope (x4/IR)",
    description = "Long range sniper optic. Used by the DLT-15A Blaster models.",
    icon        = "entities/arccw/kraken/atts/dc15scope.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "arccw_k_dc15a_scope_ir",
})

SWExp.Inventory:RegisterItem({
    id          = "att_arccw_k_dc15x_scope_ir",
    name        = "DC-15X Scope (x8/IR)",
    description = "Long range sniper optic. Used by the DLT-15X Blaster models.",
    icon        = "entities/arccw/kraken/atts/dc15scope.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "arccw_k_dc15x_scope_ir",
})

SWExp.Inventory:RegisterItem({
    id          = "att_arccw_k_dc17m_scope",
    name        = "DC-17m Sniper Scope",
    description = "",
    icon        = "entities/arccw/kraken/atts/dc17mscope.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "arccw_k_dc17m_scope",
})

SWExp.Inventory:RegisterItem({
    id          = "att_arccw_k_dlt15a_scope",
    name        = "DC-15A Scope (x4)",
    description = "Long range sniper optic. Used by the DLT-15A Blaster models.",
    icon        = "entities/arccw/kraken/atts/dc15scope.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "arccw_k_dlt15a_scope",
})

SWExp.Inventory:RegisterItem({
    id          = "att_arccw_k_dlt15x_scope",
    name        = "DC-15X Scope (x8)",
    description = "Long range sniper optic. Used by the DLT-15X Blaster models.",
    icon        = "entities/arccw/kraken/atts/dc15scope.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "arccw_k_dlt15x_scope",
})

SWExp.Inventory:RegisterItem({
    id          = "att_arccw_k_e5s_scope",
    name        = "E-5S Scope (x8)",
    description = "Long range sniper optic. Used by the E-5S Blaster models.",
    icon        = "entities/arccw/kraken/atts/e5sscope.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "arccw_k_e5s_scope",
})

SWExp.Inventory:RegisterItem({
    id          = "att_arccw_k_e5s_scope_ir",
    name        = "E-5S Scope (x8/IR)",
    description = "Long range sniper optic. Used by the E-5S Blaster models.",
    icon        = "entities/arccw/kraken/atts/e5sscope.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "arccw_k_e5s_scope_ir",
})

SWExp.Inventory:RegisterItem({
    id          = "att_arccw_k_valken38_scope",
    name        = "VALKEN-38 Scope (x8)",
    description = "Long range sniper optic. Used by the VALKEN-38 Blaster models.",
    icon        = "entities/arccw/kraken/atts/valkenscope.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "arccw_k_valken38_scope",
})

SWExp.Inventory:RegisterItem({
    id          = "att_arccw_k_valken38_scope_ir",
    name        = "VALKEN-38 Scope (x8/IR)",
    description = "Long range sniper optic. Used by the VALKEN-38 Blaster models.",
    icon        = "entities/arccw/kraken/atts/valkenscope.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "arccw_k_valken38_scope_ir",
})

SWExp.Inventory:RegisterItem({
    id          = "att_arccw_k_westarm5_scope",
    name        = "WESTAR-M5 Scope (x4)",
    description = "Long range sniper optic. Used by the WESTAR-M5  Blaster models.",
    icon        = "entities/arccw/kraken/atts/m5scope.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "arccw_k_westarm5_scope",
})

SWExp.Inventory:RegisterItem({
    id          = "att_arccw_k_westarm5_scope_ir",
    name        = "WESTAR-M5 Scope (x4/IR)",
    description = "Long range sniper optic. Used by the WESTAR-M5 Blaster models.",
    icon        = "entities/arccw/kraken/atts/m5scope.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "arccw_k_westarm5_scope_ir",
})

SWExp.Inventory:RegisterItem({
    id          = "att_b2_rocket",
    name        = "B2 Rocket",
    description = "Replace the main-fire for a rocket.",
    icon        = "",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "b2_rocket",
})

SWExp.Inventory:RegisterItem({
    id          = "att_bipod_specialforces",
    name        = "Deployed Bipod",
    description = "Deployed bipod for heavy weapons",
    icon        = "entities/kraken/sops/atts/bipod.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "bipod_specialforces",
})

SWExp.Inventory:RegisterItem({
    id          = "att_dc17_cooling",
    name        = "Cooling Improved",
    description = "Improves the weapon performance.",
    icon        = "entities/arccw/kraken/atts/module1.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "dc17_cooling",
})

SWExp.Inventory:RegisterItem({
    id          = "att_dc17_module",
    name        = "DC-17S Module",
    description = "Integrates the module of a DC-17S into the weapon.",
    icon        = "entities/arccw/kraken/atts/module2.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "dc17_module",
})

SWExp.Inventory:RegisterItem({
    id          = "att_dc17_powerpack",
    name        = "DC-17 Powerpack",
    description = "More magazine capacity at the cost of less damage.",
    icon        = "entities/arccw/kraken/atts/cooling.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "dc17_powerpack",
})

SWExp.Inventory:RegisterItem({
    id          = "att_dc17m_module_launcher",
    name        = "DC-17m Launcher Module",
    description = "Switches the DC-17m barrel to the anti-armor grenade launcher configuration. Fires explosive 40mm grenades with devastating area-of-effect damage.",
    icon        = "entities/arccw/kraken/atts/dc17m_launchermodule.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "dc17m_module_launcher",
})

SWExp.Inventory:RegisterItem({
    id          = "att_dc17m_module_shotgun",
    name        = "DC-17m Shotgun Module",
    description = "Switches the DC-17m barrel to the anti-personnel shotgun configuration. Fires 9 energy pellets per shot in a tight spread pattern with devastating close-range power.",
    icon        = "entities/arccw/kraken/atts/dc17m_shotgunmodule.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "dc17m_module_shotgun",
})

SWExp.Inventory:RegisterItem({
    id          = "att_dc17m_module_sniper",
    name        = "DC-17m Sniper Module",
    description = "Switches the DC-17m barrel to the long-range sniper configuration. Fires extremely powerful single shots with limited ammunition and no overheat fix.",
    icon        = "entities/arccw/kraken/atts/dc17m_snipermodule.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "dc17m_module_sniper",
})

SWExp.Inventory:RegisterItem({
    id          = "att_mode_at",
    name        = "Anti-Tank Mode",
    description = "Set the weapon mode to anti-tank. It will greatly improve its performance against vehicles",
    icon        = "entities/arccw/kraken/atts/at.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "mode_at",
})

SWExp.Inventory:RegisterItem({
    id          = "att_mode_charged",
    name        = "Charged Mode",
    description = "Set the weapon mode to charged shot. Designed for pistols. It will greatly improve its performance at long range, but it loses proficiency at short range.",
    icon        = "entities/arccw/kraken/atts/charged2.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "mode_charged",
})

SWExp.Inventory:RegisterItem({
    id          = "att_mode_g125",
    name        = "Tri-barrel Launcher",
    description = "Under-barrel tri-barreled projectile launcher. Press USE + RELOAD to switch to launcher mode. Overheats after a full 3-round burst.",
    icon        = "entities/kraken/g125_mode.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "mode_g125",
})

SWExp.Inventory:RegisterItem({
    id          = "att_mode_heatbased",
    name        = "Heat-Based Mode",
    description = "Set the weapon mode to heat-based.",
    icon        = "entities/arccw/kraken/atts/heatbased.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "mode_heatbased",
})

SWExp.Inventory:RegisterItem({
    id          = "att_mode_le",
    name        = "Long Engagements Mode",
    description = "Set the weapon mode to long range. It will greatly improve its performance at long range, but it loses proficiency at short range.",
    icon        = "entities/arccw/kraken/atts/le_mode.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "mode_le",
})

SWExp.Inventory:RegisterItem({
    id          = "att_mode_overcharged",
    name        = "Overcharged Mode",
    description = "Set the weapon mode to Overcharged Mode.",
    icon        = "entities/arccw/kraken/atts/charged.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "mode_overcharged",
})

SWExp.Inventory:RegisterItem({
    id          = "att_mode_overpressure",
    name        = "Overpressure Mode",
    description = "Set the weapon overpressurized mode.",
    icon        = "entities/arccw/kraken/atts/powerpack.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "mode_overpressure",
})

SWExp.Inventory:RegisterItem({
    id          = "att_mode_scatter",
    name        = "Blaster Scatter Mode",
    description = "Set the weapon mode to Scatter. Turns your weapon into a shotgun.",
    icon        = "entities/arccw/kraken/atts/scatter.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "mode_scatter",
})

SWExp.Inventory:RegisterItem({
    id          = "att_mode_scatter_pistol",
    name        = "Scatter Mode",
    description = "Set the weapon mode to Scatter. Turns your weapon into a shotgun.",
    icon        = "entities/arccw/kraken/atts/scatter.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "mode_scatter_pistol",
})

SWExp.Inventory:RegisterItem({
    id          = "att_mode_supersonic",
    name        = "Super-Sonic Mode",
    description = "Set the weapon mode to Super-Sonic Mode.",
    icon        = "entities/arccw/kraken/atts/supersonic.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "mode_supersonic",
})

SWExp.Inventory:RegisterItem({
    id          = "att_rx21_powerpack",
    name        = "Extended-power",
    description = "More tibanna compression. More damage at the cost of less magazine capacity.",
    icon        = "entities/kraken/sops/atts/rx21powerpack.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "rx21_powerpack",
})

SWExp.Inventory:RegisterItem({
    id          = "att_sops_ubgl_grapple_hook",
    name        = "GRAPPLING HOOK",
    description = "Adds a grappling hook as an underbarrel module. Launch, retract or extend a tether to pull yourself or light entities. Replicates the original hats_hook behavior.",
    icon        = "entities/kraken/sops/atts/grapple.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "sops_ubgl_grapple_hook",
})

SWExp.Inventory:RegisterItem({
    id          = "att_ubgl_dc15",
    name        = "Republic Underbarrel GL",
    description = "Single-shot underbarrel grenade launcher. Able to fire several basic grenade types.",
    icon        = "entities/arccw/kraken/atts/ubgl.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "ubgl_dc15",
})

SWExp.Inventory:RegisterItem({
    id          = "att_universal_vibroknife",
    name        = "Vibroknife",
    description = "Deploy a sharp vibroknife to suppress the enemy in melee",
    icon        = "entities/arccw/kraken/atts/vibroknife.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "universal_vibroknife",
})

SWExp.Inventory:RegisterItem({
    id          = "att_valken38_sling",
    name        = "Valken 38 Sling",
    description = "Assault sling which improves recoil control and stability but takes longer to aim with.",
    icon        = "entities/arccw/kraken/atts/sling.png",
    width       = 1,
    height      = 1,
    rarity      = "uncommon",
    canDrop     = true,
    attName     = "valken38_sling",
})

-- Материалы
SWExp.Inventory:RegisterItem({
    id          = "mat_basic",
    name        = "Материалы",
    description = "Ресурс добычи. Сдайте на Ассемблере — поступят в общий банк отряда.",
    icon        = "swexpicon/swexp-settings.png",
    width       = 1,
    height      = 1,
    stackable   = true,
    maxStack    = 50,
    rarity      = "common",
    category    = "material",
    canDrop     = false,
    worldModel  = "models/props_junk/garbage_metalcan001a.mdl"
})

-- Очки исследования (хранятся в инвентаре до сдачи на терминале)
SWExp.Inventory:RegisterItem({
    id          = "research_data",
    name        = "Данные исследования",
    description = "Полевые данные, собранные сканером. Сдайте на терминале исследований для пополнения банка ОИ.",
    icon        = "swexpicon/swexp-swexp-battery.png",
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