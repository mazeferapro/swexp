-- ============================================================
-- Star Wars: Expedition — Регистрация предметов боеприпасов и гранат
-- modules/ammo/sh_ammo_items.lua
--
-- Здесь все ammo_blaster / ammo_*_grenade регистрируются в SWExp.Inventory.
-- Делается отдельным файлом, чтобы НЕ трогать sh_inventory.lua и
-- держать всю систему боеприпасов в одной папке.
-- ============================================================

-- Регистрация откладывается до Initialize — к этому моменту
-- inventory-модуль уже отработает RegisterItem в sh_inventory.lua
-- (папка ammo/ грузится раньше inventory/ по алфавиту).

local function RegisterAmmoItems()
    if not SWExp or not SWExp.Inventory or not SWExp.Inventory.RegisterItem then
        -- На всякий случай — повторим попытку через 0.1 сек
        timer.Simple(0.1, RegisterAmmoItems)
        return
    end

-- ============================================================
-- 1. ПАЧКИ БОЕПРИПАСОВ (расходники с onUse → +N патронов)
-- ============================================================

for _, box in ipairs(SWExp.Ammo.Boxes or {}) do
    SWExp.Inventory:RegisterItem({
        id          = box.itemID,
        name        = box.name,
        description = box.desc,
        icon        = box.icon or "icon16/ammo.png",
        width       = 1,
        height      = 1,
        stackable   = true,
        maxStack    = 10,        -- до 10 пачек в одном слоте
        rarity      = "common",
        category    = "ammo",
        canDrop     = true,
        worldModel  = box.worldModel or "models/items/boxsrounds.mdl",
        ammoType    = box.ammoType,
        ammoCount   = box.count,
        -- onUse вызывается из netstream "SWExp::InventoryUseItem"
        onUse = function(pPlayer, item)
            if SERVER and SWExp.Ammo and SWExp.Ammo.UseBox then
                return SWExp.Ammo.UseBox(pPlayer, item)
            end
            return false
        end
    })
end

-- ============================================================
-- 2. ГРАНАТЫ (предметы в слотах "grenade", аналогично аптечкам)
--    Каждая граната — отдельный нерастекуемый предмет в слоте.
--    SWEP НЕ выдаётся при экипировке. Бросок выполняется через
--    модуль grenade/sv_grenade.lua: временно даём SWEP → форсируем
--    бросок → стрипаем → списываем 1 шт. из слота.
-- ============================================================

for _, gr in ipairs(SWExp.Ammo.Grenades or {}) do
    local def = {
        id            = gr.key,
        name          = gr.name,
        description   = gr.desc,
        icon          = gr.icon,
        width         = 1,
        height        = 1,
        slotType      = "grenade",
        stackable     = false,                       -- 1 предмет = 1 граната
        maxStack      = 1,
        rarity        = "uncommon",
        category      = "grenade",
        canDrop       = true,
        worldModel    = "models/weapons/w_grenade.mdl",
        grenadeSWEP   = gr.swep,                     -- какой SWEP временно выдавать при броске
        grenadeAmmo   = gr.ammo,                     -- ArcCW ammo type (для совместимости)
    }

    if not SWExp.Inventory:GetItemData(gr.key) then
        SWExp.Inventory:RegisterItem(def)
    else
        -- Перезаписываем поля у существующего, чтобы перевести в новую модель
        local existing = SWExp.Inventory:GetItemData(gr.key)
        existing.slotType    = "grenade"
        existing.stackable   = false
        existing.maxStack    = 1
        existing.category    = "grenade"
        existing.grenadeSWEP = gr.swep
        existing.grenadeAmmo = gr.ammo
        existing.weaponClass = nil   -- ОТКЛЮЧАЕМ старую логику EquipItem→Give
        existing.ammoType    = nil
    end
end

    if SERVER then
        print("[SWExp][Ammo] sh_ammo_items.lua: зарегистрировано "
            ..#(SWExp.Ammo.Boxes or {}).." пачек и "
            ..#(SWExp.Ammo.Grenades or {}).." гранат.")
    end
end -- end of RegisterAmmoItems

-- Запускаем регистрацию после полной загрузки геймода
hook.Add("Initialize", "SWExp::Ammo::RegisterItemsOnInit", RegisterAmmoItems)
-- Подстраховка на случай горячей перезагрузки lua_run
if SWExp and SWExp.Inventory and SWExp.Inventory.RegisterItem then
    RegisterAmmoItems()
end
