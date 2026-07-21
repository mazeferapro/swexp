-- ============================================================
-- config/sh_donate_shop_config.lua
-- Конфигурация донат-магазина StarWarsRP
--
-- КАК РАБОТАЮТ ПАКИ МОДЕЛЕЙ:
--   Поле  replaces  = playerModel из конфига брони (sh_inventory.lua).
--   Поле  model     = ТВОЯ альтернативная модель (замени на нужный .mdl).
--
--   Когда игрок надевает броню с playerModel == replaces
--   → сервер ставит model из пака вместо стандартной модели.
--   Когда броня снята → стандартная модель возвращается (cadet.mdl).
--
-- КАКИЕ СТАНДАРТНЫЕ МОДЕЛИ БРОНИ ИСПОЛЬЗУЮТСЯ:
--   Лёгкая  (все тиры) → models/sb_arf/sb_arf.mdl
--   Средняя (все тиры) → models/sb_sld/sb_sld.mdl
--   Тяжёлая (все тиры) → models/sb_heavy/sb_heavy.mdl
--   Инженер (все тиры) → models/sb_eng/sb_eng.mdl
--   Медик   (все тиры) → models/sb_med/sb_med.mdl
--
-- ДОБАВИТЬ НОВЫЙ ПАК:
--   1. Скопируй один из блоков ниже.
--   2. Дай уникальный id.
--   3. В replaces укажи стандартный playerModel брони из sh_inventory.lua.
--   4. В model укажи путь к альтернативной модели.
-- ============================================================

SWExp.DonateShop = SWExp.DonateShop or {}

-- ============================================================
-- КАТЕГОРИИ НАВИГАЦИИ
-- ============================================================

SWExp.DonateShop.Categories = {
    { id = 'models', name = 'Паки брони',      icon = '◈' },
    { id = 'slots',  name = 'Слот персонажа',  icon = '⊕' },
}

-- ============================================================
-- ТОВАРЫ
-- ============================================================

SWExp.DonateShop.Items = {

    -- ──────────────────────────────────────────────────────────
    -- ПАКИ БРОНИ
    -- replaces — стандартная модель из sh_inventory.lua (playerModel)
    -- model    — альтернативная модель (ЗАМЕНИ на нужный путь)
    --
    -- !! ВАЖНО: замени значение model на реальный путь к MDL
    --    Модель должна быть включена в workshop или addon сервера
    -- ──────────────────────────────────────────────────────────

    {
        id       = 'model_pack_arf_212',
        name     = 'Лёгкая броня — скин 833-го',
        desc     = 'Заменяет стандартную модель лёгкой брони (ARF) на альтернативную при надевании.',
        price    = 100,
        category = 'models',
        type     = 'model_pack',
        replaces = 'models/ct_arf/ct_arf.mdl',      -- стандартная модель брони
        model    = 'models/player/garith/crm/crm_leader_66_3.mdl',       -- ← ЗАМЕНИ на свой MDL-путь
    },
    {
        id       = 'model_pack_sld_212',
        name     = 'Средняя броня — скин 833-го',
        desc     = 'Заменяет стандартную модель средней брони (SLD) на альтернативную при надевании.',
        price    = 100,
        category = 'models',
        type     = 'model_pack',
        replaces = 'models/ct_pvt/ct_pvt.mdl',
        model    = 'models/player/garith/crm/crm_trooper.mdl',       -- ← ЗАМЕНИ на свой MDL-путь
    },
    {
        id       = 'model_pack_heavy_212',
        name     = 'Тяжёлая броня — скин 833-го',
        desc     = 'Заменяет стандартную модель тяжёлой брони на альтернативную при надевании.',
        price    = 100,
        category = 'models',
        type     = 'model_pack',
        replaces = 'models/ct_heavy/ct_heavy.mdl',
        model    = 'models/player/garith/crm/crm_drone_operator_gary.mdl',   -- ← ЗАМЕНИ на свой MDL-путь
    },
    {
        id       = 'model_pack_eng_212',
        name     = 'Броня инженера — скин 833-го',
        desc     = 'Заменяет стандартную модель брони инженера на альтернативную при надевании.',
        price    = 100,
        category = 'models',
        type     = 'model_pack',
        replaces = 'models/ct_eng/ct_eng.mdl',
        model    = 'models/player/garith/crm/crm_rett.mdl',       -- ← ЗАМЕНИ на свой MDL-путь
    },
    {
        id       = 'model_pack_med_212',
        name     = 'Броня медика — скин 833-го',
        desc     = 'Заменяет стандартную модель брони медика на альтернативную при надевании.',
        price    = 100,
        category = 'models',
        type     = 'model_pack',
        replaces = 'models/ct_med/ct_med.mdl',
        model    = 'models/player/garith/crm/crm_medic.mdl',       -- ← ЗАМЕНИ на свой MDL-путь
    },

    -- лев

    {
        id       = 'model_pack_arf_lev',
        name     = 'Лёгкая броня — скин левиафан',
        desc     = 'Заменяет стандартную модель лёгкой брони (ARF) на альтернативную при надевании.',
        price    = 200,
        category = 'models',
        type     = 'model_pack',
        replaces = 'models/ct_arf/ct_arf.mdl',      -- стандартная модель брони
        model    = 'models/player/garith/10th_3/marksman_3.mdl',       -- ← ЗАМЕНИ на свой MDL-путь
    },
    {
        id       = 'model_pack_sld_lev',
        name     = 'Средняя броня — скин левиафан',
        desc     = 'Заменяет стандартную модель средней брони (SLD) на альтернативную при надевании.',
        price    = 200,
        category = 'models',
        type     = 'model_pack',
        replaces = 'models/ct_pvt/ct_pvt.mdl',
        model    = 'models/player/garith/10th_3/commando_3.mdl',       -- ← ЗАМЕНИ на свой MDL-путь
    },
    {
        id       = 'model_pack_heavy_lev',
        name     = 'Тяжёлая броня — скин левиафан',
        desc     = 'Заменяет стандартную модель тяжёлой брони на альтернативную при надевании.',
        price    = 200,
        category = 'models',
        type     = 'model_pack',
        replaces = 'models/ct_heavy/ct_heavy.mdl',
        model    = 'models/player/garith/10th_3/darion_3.mdl',   -- ← ЗАМЕНИ на свой MDL-путь
    },
    {
        id       = 'model_pack_eng_lev',
        name     = 'Броня инженера — скин левиафан',
        desc     = 'Заменяет стандартную модель брони инженера на альтернативную при надевании.',
        price    = 200,
        category = 'models',
        type     = 'model_pack',
        replaces = 'models/ct_eng/ct_eng.mdl',
        model    = 'models/player/garith/10th_3/ranger_3.mdl',       -- ← ЗАМЕНИ на свой MDL-путь
    },
    {
        id       = 'model_pack_med_lev',
        name     = 'Броня медика — скин левиафан',
        desc     = 'Заменяет стандартную модель брони медика на альтернативную при надевании.',
        price    = 200,
        category = 'models',
        type     = 'model_pack',
        replaces = 'models/ct_med/ct_med.mdl',
        model    = 'models/player/garith/10th_3/grenadier_3.mdl',       -- ← ЗАМЕНИ на свой MDL-путь
    },

    -- ──────────────────────────────────────────────────────────
    -- СЛОТЫ ПЕРСОНАЖА
    -- stackable = true → можно купить несколько раз
    -- ──────────────────────────────────────────────────────────

    {
        id        = 'char_slot',
        name      = 'Слот персонажа',
        desc      = 'Добавляет 1 дополнительный слот для создания нового персонажа.',
        price     = 300,
        category  = 'slots',
        type      = 'character_slot',
        stackable = true,
    },

}

-- ============================================================
-- УТИЛИТЫ
-- ============================================================

function SWExp.DonateShop:GetItem(itemID)
    for _, v in ipairs(self.Items) do
        if v.id == itemID then return v end
    end
    return nil
end

function SWExp.DonateShop:GetItemsByCategory(catID)
    local out = {}
    for _, v in ipairs(self.Items) do
        if v.category == catID then out[#out + 1] = v end
    end
    return out
end

-- Найти активный пак который перекрывает конкретную модель брони.
-- Возвращает itemData пака или nil.
-- ownedMap = { [itemID] = true }
-- equippedItemID = itemID активного пака или nil
function SWExp.DonateShop:FindPackForArmorModel(armorModel, equippedItemID)
    if not equippedItemID then return nil end
    local pack = self:GetItem(equippedItemID)
    if not pack then return nil end
    if pack.type ~= 'model_pack' then return nil end
    if pack.replaces ~= armorModel then return nil end
    return pack
end
