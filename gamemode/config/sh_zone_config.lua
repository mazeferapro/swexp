-- ============================================================
-- Star Wars: Expedition — Конфигурация зон спавна
-- config/sh_zone_config.lua
--
-- Определяет параметры 4 тиров зон:
--   • сколько материалов/ОИ даёт каждый тир
--   • радиус зоны, лимит нодов, интервал респавна
--   • цвета и названия для визуализации
-- ============================================================

SWExp.ZoneConfig = SWExp.ZoneConfig or {}

-- ============================================================
-- ТИРЫ ЗОН
-- ============================================================

SWExp.ZoneConfig.Tiers = {

    -- ──────────────── ТИР 1 ────────────────
    [1] = {
        name        = "Зона 1 — Периметр",
        color       = Color(80, 200, 100),      -- зелёный

        -- Параметры зоны
        radius      = 600,                      -- радиус спавна нодов (ед.)
        maxMat      = 2,                        -- макс. одновременных материальных нодов
        maxRes      = 2,                        -- макс. одновременных точек исследования
        respawnTime = 300,                       -- секунд до следующего цикла спавна

        -- Материалы (mat_basic) за одну добычу
        matAmount   = { min = 1, max = 6 },
        matCharges  = { min = 3, max = 5 },     -- зарядов на ноде

        -- Очки исследования (research_data) за одно сканирование
        resPoints   = 5,                        -- предметов research_data
    },

    -- ──────────────── ТИР 2 ────────────────
    [2] = {
        name        = "Зона 2 — Внешний рубеж",
        color       = Color(80, 160, 255),      -- синий

        radius      = 600,
        maxMat      = 2,
        maxRes      = 2,
        respawnTime = 300,

        matAmount   = { min = 2, max = 10 },
        matCharges  = { min = 4, max = 5 },

        resPoints   = 10,
    },

    -- ──────────────── ТИР 3 ────────────────
    [3] = {
        name        = "Зона 3 — Аномальный сектор",
        color       = Color(255, 180, 40),      -- оранжевый

        radius      = 600,
        maxMat      = 2,
        maxRes      = 2,
        respawnTime = 600,

        matAmount   = { min = 3, max = 12 },
        matCharges  = { min = 5, max = 6 },

        resPoints   = 15,
    },

    -- ──────────────── ТИР 4 ────────────────
    [4] = {
        name        = "Зона 4 — Сердце тьмы",
        color       = Color(220, 60, 60),       -- красный

        radius      = 600,
        maxMat      = 8,
        maxRes      = 6,
        respawnTime = 600,

        matAmount   = { min = 4, max = 16 },
        matCharges  = { min = 6, max = 7 },

        resPoints   = 20,
    },
}

-- ============================================================
-- ТИПЫ МАТЕРИАЛЬНЫХ НОДОВ ПО ТИРАМ
-- Каждый тир имеет свой набор тематических типов
-- ============================================================

SWExp.ZoneConfig.MatTypes = {

    [1] = {
        {
            name      = "Металлолом",
            color     = Color(180, 180, 220),
            models    = { "models/niksacokica/vehicles/veh_neu_speeder_02_debris.mdl", "models/niksacokica/vehicles/veh_neu_speeder_02_debris.mdl"},
            sound     = "physics/metal/metal_box_impact_hard1.wav",
            monologue = "Остатки чего-то механического.",
        },
    },

    [2] = {
        {
            name      = "Мешок с припасами",
            color     = Color(80, 200, 255),
            models    = { "models/niksacokica/containers/pvp_loot_container_01.mdl"},
            sound     = "physics/metal/metal_canister_impact_hard1.wav",
            monologue = "Похоже в нём есть что-то полезное",
        },
    },

    [3] = {
        {
            name      = "Повреждённый ящик",
            color     = Color(255, 100, 220),
            models    = { "models/niksacokica/containers/con_square_crate_broken_no_debris.mdl", "models/niksacokica/containers/con_crate_04_broken_no_debris.mdl" },
            sound     = "ambient/energy/zap7.wav",
            monologue = "Может в нём осталось что-то полезное.",
        },
    },

    [4] = {
        {
            name      = "Ящик с материалами",
            color     = Color(220, 80, 255),
            models    = { "models/props_junk/metal_wire001a.mdl", "models/props_lab/beaker01.mdl" },
            sound     = "ambient/energy/force_field_loop1.wav",
            monologue = "Он наверняка набит полезными материалами.",
        },
    },
}

-- ============================================================
-- ТИПЫ ТОЧЕК ИССЛЕДОВАНИЯ ПО ТИРАМ
-- ============================================================

SWExp.ZoneConfig.ResTypes = {

    [1] = {
        {
            name      = "Следы присутствия",
            color     = Color(255, 200, 60),
            models    = { "models/vj_base/gibs/alien/gib1.mdl", "models/vj_base/gibs/human/gib1.mdl" },
            monologue = "Фу какая мерзость ... ",
        },
        
    },

    [2] = {
        {
            name      = "Следы присутствия",
            color     = Color(255, 200, 60),
            models    = { "models/vj_base/gibs/alien/gib1.mdl", "models/vj_base/gibs/human/gib1.mdl" },
            monologue = "Фу какая мерзость ... ",
        },
        
    },

    [3] = {
        {
            name      = "Следы присутствия",
            color     = Color(255, 200, 60),
            models    = { "models/vj_base/gibs/alien/gib1.mdl", "models/vj_base/gibs/human/gib1.mdl" },
            monologue = "Фу какая мерзость ... ",
        },
        
    },

    [4] = {
        {
            name      = "Следы присутствия",
            color     = Color(255, 200, 60),
            models    = { "models/vj_base/gibs/alien/gib1.mdl", "models/vj_base/gibs/human/gib1.mdl" },
            monologue = "Фу какая мерзость ... ",
        },
        
    },
}

-- ============================================================
-- Вспомогательные функции
-- ============================================================

function SWExp.ZoneConfig.GetTier(tier)
    return SWExp.ZoneConfig.Tiers[math.Clamp(tier, 1, 4)]
end

function SWExp.ZoneConfig.GetMatType(tier)
    local types = SWExp.ZoneConfig.MatTypes[math.Clamp(tier, 1, 4)]
    return types and types[math.random(#types)] or SWExp.ZoneConfig.MatTypes[1][1]
end

function SWExp.ZoneConfig.GetResType(tier)
    local types = SWExp.ZoneConfig.ResTypes[math.Clamp(tier, 1, 4)]
    return types and types[math.random(#types)] or SWExp.ZoneConfig.ResTypes[1][1]
end

print("[SWExp] Конфиг зон спавна загружен.")
