-- ============================================================
-- Star Wars: Expedition — Конфигурация системы боеприпасов
-- modules/ammo/sh_ammo_config.lua
--
-- Один источник правды:
--   - какие типы патронов существуют в игре (HL2 + ArcCW гранаты)
--   - сколько даёт пачка боеприпасов из ассемблера
--   - какие предметы инвентаря являются "гранатами" (расходные SWEP)
--
-- Используется и на сервере (выдача/сохранение), и на клиенте (HUD).
-- ============================================================

SWExp.Ammo = SWExp.Ammo or {}

-- ============================================================
-- 1. ТИПЫ ПАТРОНОВ (HL2 ammo types)
--    Имя должно совпадать с тем, что возвращает game.GetAmmoID/Name.
-- ============================================================

SWExp.Ammo.Types = {
    -- Базовые HL2 типы (для weapon_ar2 / weapon_pistol / weapon_smg1)
    AR2     = { name = "AR2",     displayName = "Энергоячейки (винтовка)" },
    Pistol  = { name = "Pistol",  displayName = "Энергоячейки (пистолет)" },
    SMG1    = { name = "SMG1",    displayName = "Энергоячейки (СМГ)"      },
}

-- ============================================================
-- 2. ГРАНАТЫ (ArcCW)
--    key   — itemID в инвентаре (для регистрации в sh_inventory)
--    swep  — класс SWEP, который выдаётся при экипировке
--    ammo  — ArcCW ammo type (НЕ HL2, это отдельная вселенная)
--    slot  — куда экипируется ("special" по умолчанию)
-- ============================================================

SWExp.Ammo.Grenades = {
    {
        key  = "arccwknadebacta",
        swep = "arccw_k_nade_bacta",
        ammo = "arccw_k_nade_bacta",
        name = "Бакта-граната",
        desc = "Граната с бактой.",
        icon = "swexpicon/swexp-nade-bacta.png",
    },
    {
        key  = "arccwknadefrag",
        swep = "arccw_k_nade_c14",
        ammo = "arccw_k_nade_c14",
        name = "Граната C-14",
        desc = "Противотанковая граната",
        icon = "swexpicon/swexp-nade-c25.png",
    },
    {
        key  = "arccwknadethermal",
        swep = "arccw_k_nade_thermal",
        ammo = "arccw_k_nade_thermal",
        name = "Термальный детонатор",
        desc = "Высокий урон по площади.",
        icon = "swexpicon/swexp-nade-thermal.png",
    },
    {
        key  = "arccwknadesmoke",
        swep = "arccw_k_nade_smoke",
        ammo = "arccw_k_nade_smoke",
        name = "Дымовая граната",
        desc = "Создаёт облако дыма.",
        icon = "swexpicon/swexp-nade-smoke.png",
    },
    {
        key  = "arccwknadeflashbang",
        swep = "arccw_k_nade_flashbang",
        ammo = "arccw_k_nade_flashbang",
        name = "Светошумовая граната",
        desc = "Ослепляет противников.",
        icon = "swexpicon/swexp-nade-flash.png",
    },
    {
        key  = "arccwknadestun",
        swep = "arccw_k_nade_stun",
        ammo = "arccw_k_nade_stun",
        name = "Электрошоковая граната",
        desc = "Парализует на короткое время.",
        icon = "swexpicon/swexp-nade-stun.png",
    },
    {
        key  = "arccwknadeshock",
        swep = "arccw_k_nade_shock",
        ammo = "arccw_k_nade_shock",
        name = "Шок-граната",
        desc = "Электрический разряд по площади.",
        icon = "swexpicon/swexp-nade-shock.png",
    },
    {
        key  = "arccwknadethermite",
        swep = "arccw_k_nade_thermite",
        ammo = "arccw_k_nade_thermite",
        name = "Термитная шашка",
        desc = "Прожигает металл.",
        icon = "swexpicon/swexp-nade-thermite.png",
    },
    {
        key  = "arccwknadeimpact",
        swep = "arccw_k_nade_impact",
        ammo = "arccw_k_nade_impact",
        name = "Импактная граната",
        desc = "Взрывается от удара.",
        icon = "swexpicon/swexp-nade-impact.png",
    },
    {
        key  = "arccwknadedioxis",
        swep = "arccw_k_nade_dioxis",
        ammo = "arccw_k_nade_dioxis",
        name = "Граната Диоксис",
        desc = "Граната с диоксисом.",
        icon = "swexpicon/swexp-nade-dioxis.png",
    },
    {
        key  = "arccwknadesequencecharger",
        swep = "arccw_k_nade_sequencecharger",
        ammo = "arccw_k_nade_sequencecharger",
        name = "Секвинсер",
        desc = "Большой бабах.",
        icon = "swexpicon/swexp-nade-sequence.png",
    },
    {
        key  = "arccwknadeantitankmine",
        swep = "arccw_k_nade_antitankmine",
        ammo = "arccw_k_nade_antitankmine",
        name = "Анти-танк мина",
        desc = "Противотанковая мина.",
        icon = "swexpicon/swexp-nade-antitank.png",
    },
    {
        key  = "arccwknadethermalimploder",
        swep = "arccw_k_nade_thermalimploder",
        ammo = "arccw_k_nade_thermalimploder",
        name = "Усиленная термальная",
        desc = "Улучшенная термальная граната.",
        icon = "swexpicon/swexp-nade-thermalin.png",
    },
    {
        key  = "arccwknadeplasmagrenade",
        swep = "arccw_k_nade_plasmagrenade",
        ammo = "arccw_k_nade_plasmagrenade",
        name = "Плазменная граната",
        desc = "Взрывается плазмой.",
        icon = "swexpicon/swexp-nade-plasma.png",
    },
    {
        key  = "arccwknadec25",
        swep = "arccw_k_nade_c25",
        ammo = "arccw_k_nade_c25",
        name = "С-25",
        desc = "",
        icon = "swexpicon/swexp-nade-c25.png",
    },
    {
        key  = "arccwknadesonar",
        swep = "arccw_k_nade_sonar",
        ammo = "arccw_k_nade_sonar",
        name = "Сонар граната",
        desc = "",
        icon = "swexpicon/swexp-nade-impact.png",
    },
    {
        key  = "arccwknadeblaststick",
        swep = "arccw_k_nade_blaststick",
        ammo = "arccw_k_nade_blaststick",
        name = "Бластик",
        desc = "Просто бластик.",
        icon = "swexpicon/swexp-nade-blaststick.png",
    },
    {
        key  = "arccwknadedetonite",
        swep = "arccw_k_nade_detonite",
        ammo = "arccw_k_nade_detonite",
        name = "Детонит",
        desc = "Прикрепляется к поверхностям.",
        icon = "swexpicon/swexp-nade-detonite.png",
    },
    {
        key  = "arccwknadedecoy",
        swep = "arccw_k_nade_decoy",
        ammo = "arccw_k_nade_decoy",
        name = "Декой",
        desc = "",
        icon = "swexpicon/swexp-nade-decoy.png",
    },
}

-- Вспомогательная функция: построить таблицу key → grenade
SWExp.Ammo.GrenadesByKey = {}
for _, g in ipairs(SWExp.Ammo.Grenades) do
    SWExp.Ammo.GrenadesByKey[g.key] = g
end

-- Обратный индекс: SWEP-класс → grenade (нужен для авто-снятия пустого SWEP)
SWExp.Ammo.GrenadesBySWEP = {}
for _, g in ipairs(SWExp.Ammo.Grenades) do
    SWExp.Ammo.GrenadesBySWEP[g.swep] = g
end

-- ============================================================
-- 3. ПАЧКИ БОЕПРИПАСОВ (предметы из ассемблера/инвентаря)
--    При onUse → даёт игроку count единиц патрона типа ammoType.
-- ============================================================

SWExp.Ammo.Boxes = {
    {
        itemID    = "ammo_blaster",
        ammoType  = "AR2",      -- HL2-тип (DC-15A работает на AR2)
        count     = 30,
        name      = "Энергоячейки (×30)",
        desc      = "Стандартные энергоячейки для бластерных винтовок (DC-15A).",
        icon      = "swexpicon/swexp-swexp-ammo.png",
        worldModel= "models/items/boxsrounds.mdl",
    },
    {
        itemID    = "ammo_blaster_pistol",
        ammoType  = "Pistol",
        count     = 24,
        name      = "Энергоячейки пистолета (×24)",
        desc      = "Малые энергоячейки для DC-17.",
        icon      = "icon16/ammo.png",
        worldModel= "models/items/boxsrounds.mdl",
    },
}

SWExp.Ammo.BoxesByItemID = {}
for _, b in ipairs(SWExp.Ammo.Boxes) do
    SWExp.Ammo.BoxesByItemID[b.itemID] = b
end

-- ============================================================
-- 4. УТИЛИТЫ
-- ============================================================

-- Проверить, что тип патрона валиден (есть в HL2 или это ArcCW-граната)
function SWExp.Ammo.IsValidType(ammoType)
    if game.GetAmmoID(ammoType) and game.GetAmmoID(ammoType) >= 0 then
        return true
    end
    return false
end

-- Получить ammoType, на который "садится" SWEP при экипировке.
-- Используется при выдаче запаса патронов через GiveAmmo при Equip.
function SWExp.Ammo.GetAmmoTypeForWeapon(weaponClass)
    -- Для гранат тип = сам класс ammo (ArcCW)
    local g = SWExp.Ammo.GrenadesBySWEP[weaponClass]
    if g then return g.ammo end

    -- Для остальных оружий — определяется из самого SWEP при выдаче,
    -- так что null допустим (sv_ammo возьмёт GetPrimaryAmmoType)
    return nil
end

if SERVER then
    print("[SWExp][Ammo] sh_ammo_config.lua загружен (сервер)")
else
    print("[SWExp][Ammo] sh_ammo_config.lua загружен (клиент)")
end
