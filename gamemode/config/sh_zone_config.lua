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
        maxMat      = 5,                        -- макс. одновременных материальных нодов
        maxRes      = 4,                        -- макс. одновременных точек исследования
        respawnTime = 90,                       -- секунд до следующего цикла спавна

        -- Материалы (mat_basic) за одну добычу
        matAmount   = { min = 1, max = 3 },
        matCharges  = { min = 1, max = 2 },     -- зарядов на ноде

        -- Очки исследования (research_data) за одно сканирование
        resPoints   = 1,                        -- предметов research_data
    },

    -- ──────────────── ТИР 2 ────────────────
    [2] = {
        name        = "Зона 2 — Внешний рубеж",
        color       = Color(80, 160, 255),      -- синий

        radius      = 700,
        maxMat      = 6,
        maxRes      = 5,
        respawnTime = 75,

        matAmount   = { min = 3, max = 6 },
        matCharges  = { min = 1, max = 3 },

        resPoints   = 2,
    },

    -- ──────────────── ТИР 3 ────────────────
    [3] = {
        name        = "Зона 3 — Аномальный сектор",
        color       = Color(255, 180, 40),      -- оранжевый

        radius      = 800,
        maxMat      = 7,
        maxRes      = 5,
        respawnTime = 60,

        matAmount   = { min = 5, max = 10 },
        matCharges  = { min = 2, max = 3 },

        resPoints   = 3,
    },

    -- ──────────────── ТИР 4 ────────────────
    [4] = {
        name        = "Зона 4 — Сердце тьмы",
        color       = Color(220, 60, 60),       -- красный

        radius      = 900,
        maxMat      = 8,
        maxRes      = 6,
        respawnTime = 45,

        matAmount   = { min = 8, max = 16 },
        matCharges  = { min = 2, max = 4 },

        resPoints   = 5,
    },
}

-- ============================================================
-- ТИПЫ МАТЕРИАЛЬНЫХ НОДОВ ПО ТИРАМ
-- Каждый тир имеет свой набор тематических типов
-- ============================================================

SWExp.ZoneConfig.MatTypes = {

    [1] = {
        {
            name      = "Обломки техники",
            color     = Color(180, 180, 220),
            models    = { "models/props_junk/garbage_metalcan001a.mdl", "models/props_junk/PopCan01a.mdl" },
            sound     = "physics/metal/metal_box_impact_hard1.wav",
            monologue = "Остатки чего-то механического. Вонгского? Нет — слишком примитивно. Кто-то был здесь раньше.",
        },
        {
            name      = "Органические волокна",
            color     = Color(120, 220, 80),
            models    = { "models/props_lab/beaker01.mdl", "models/props_lab/jar001a.mdl" },
            sound     = "physics/flesh/flesh_impact_hard1.wav",
            monologue = "Местная флора. Волокна прочнее стандартной дюрасталевой нити — и легче. Военные оценят.",
        },
    },

    [2] = {
        {
            name      = "Залежи криобрита",
            color     = Color(80, 200, 255),
            models    = { "models/props_c17/canister01a.mdl", "models/props_c17/canister02a.mdl" },
            sound     = "physics/metal/metal_canister_impact_hard1.wav",
            monologue = "Кристаллы криобрита. Промёрзшие до самой сердцевины — но ценные. Интересно, как они здесь образовались.",
        },
        {
            name      = "Металлолом Вонгов",
            color     = Color(200, 140, 60),
            models    = { "models/props_junk/metal_wire001a.mdl", "models/props_c17/oildrum001a.mdl" },
            sound     = "physics/metal/metal_solid_impact_hard1.wav",
            monologue = "Биологический металл Вонгов. Живой — или был живым. Не трогать голыми руками.",
        },
    },

    [3] = {
        {
            name      = "Энергетические кристаллы",
            color     = Color(255, 100, 220),
            models    = { "models/props_combine/combine_mine01.mdl", "models/props_junk/garbage_bag001a.mdl" },
            sound     = "ambient/energy/zap7.wav",
            monologue = "Нестабильные. Лучше не бросать. Зато заряд держат лучше любого аккумулятора.",
        },
        {
            name      = "Вонгские биокристаллы",
            color     = Color(180, 255, 120),
            models    = { "models/props_lab/jar001a.mdl", "models/props_c17/canister02a.mdl" },
            sound     = "ambient/energy/whiteflash.wav",
            monologue = "Живые кристаллы. Растут прямо на камне. Вонги используют их в биотехнологии — значит, ценные.",
        },
    },

    [4] = {
        {
            name      = "Артефактный сплав",
            color     = Color(255, 200, 60),
            models    = { "models/props_c17/oildrum001a.mdl", "models/props_combine/combine_mine01.mdl" },
            sound     = "ambient/energy/zap9.wav",
            monologue = "Этот металл не из известных мне сплавов. Древний. Очень древний. И очень прочный.",
        },
        {
            name      = "Сердцевина аномалии",
            color     = Color(220, 80, 255),
            models    = { "models/props_junk/metal_wire001a.mdl", "models/props_lab/beaker01.mdl" },
            sound     = "ambient/energy/force_field_loop1.wav",
            monologue = "Источник здешних аномалий. Излучение зашкаливает. Долго рядом не стоять — но материал того стоит.",
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
            models    = { "models/props_junk/garbage_metalcan001a.mdl", "models/props_junk/garbage_bag001a.mdl" },
            monologue = "Здесь кто-то был. Недавно. Следы не наши — оборудование незнакомое. Надо зафиксировать.",
        },
        {
            name      = "Аномалия планеты",
            color     = Color(80, 160, 255),
            models    = { "models/props_c17/canister01a.mdl", "models/props_combine/combine_mine01.mdl" },
            monologue = "Сенсоры зашкаливают. Энергетическая аномалия, либо помехи — не разберу. Нужен скан.",
        },
    },

    [2] = {
        {
            name      = "Вонгская биотехнология",
            color     = Color(120, 220, 80),
            models    = { "models/props_lab/beaker01.mdl", "models/props_lab/jar001a.mdl" },
            monologue = "Это живое? Или было живым? Вонги делают всё из органики. Нужно сканировать.",
        },
        {
            name      = "Мёртвый Вонг",
            color     = Color(220, 80, 80),
            models    = { "models/props_junk/metal_wire001a.mdl", "models/props_c17/oildrum001a.mdl" },
            monologue = "Вонг. Мёртв. Но не от нашего оружия — следы ритуала. Это важно знать.",
        },
    },

    [3] = {
        {
            name      = "Артефакт древней цивилизации",
            color     = Color(200, 130, 255),
            models    = { "models/props_c17/fishingtackle01.mdl", "models/props_junk/PopCan01a.mdl" },
            monologue = "Это старше всего, что я видел. Намного старше. Здесь жили разумные существа до Вонгов.",
        },
        {
            name      = "Энергетический источник",
            color     = Color(80, 220, 255),
            models    = { "models/props_combine/combine_mine01.mdl", "models/props_c17/canister02a.mdl" },
            monologue = "Постоянный энергетический фон. Не природный. Кто-то построил здесь что-то очень давно.",
        },
    },

    [4] = {
        {
            name      = "Ядро аномалии",
            color     = Color(255, 80, 80),
            models    = { "models/props_lab/jar001a.mdl", "models/props_c17/canister01a.mdl" },
            monologue = "Это центр всего. Датчики сходят с ума. Сканируй быстро и уходи — здесь опасно.",
        },
        {
            name      = "Реликвия предшественников",
            color     = Color(255, 220, 80),
            models    = { "models/props_c17/fishingtackle01.mdl", "models/props_junk/metal_wire001a.mdl" },
            monologue = "Реликвия. Учёные с базы за такое отдадут половину разработок. Надо сканировать аккуратно.",
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
