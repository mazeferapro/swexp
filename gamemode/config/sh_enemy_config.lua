-- ============================================================
-- Star Wars: Expedition — Конфигурация системы спавна врагов
-- config/sh_enemy_config.lua
--
-- Формула: Количество врагов = f(ThreatTier × NoiseLevel)
--   • ThreatTier  (1-4) — КАЧЕСТВО врагов. Задаётся проходом через портал.
--   • NoiseLevel  (0..Max) — КОЛИЧЕСТВО врагов. Растёт от действий игрока.
--
-- Все параметры ниже — крутилки. Меняй значения, не трогай структуру.
-- ============================================================

SWExp.EnemyConfig = SWExp.EnemyConfig or {}
local C = SWExp.EnemyConfig

-- ============================================================
-- ОБЩИЕ ПАРАМЕТРЫ СИСТЕМЫ
-- ============================================================

C.System = {
    -- Как часто менеджер проверяет всех игроков и пулы (сек).
    -- Ниже = отзывчивее, но больше нагрузка. 0.5 — оптимум.
    thinkInterval   = 0.1,

    -- Минимальное расстояние от игрока до точки спавна (ед.)
    spawnMinDist    = 1000,
    -- Максимальное расстояние от игрока до точки спавна (ед.)
    spawnMaxDist    = 1500,

    -- Максимум попыток найти валидную точку спавна за один цикл
    spawnMaxTries   = 128,

    -- Буфер безопасной зоны: спавн запрещён ближе чем (safezone.Radius + buffer)
    safezoneBuffer  = 500,

    -- Grace period: сколько сек враги остаются после падения шума ниже порога (сек).
    -- По истечении — удаляются вдали от глаз игрока.
    lowNoiseGrace   = 0,

    -- При входе игрока в safezone — сразу же начинается деспавн его пула (сек).
    enterSafezoneDespawn = 5,

    -- Дистанция, дальше которой живой NPC удаляется при деспавне (ед.).
    -- Если игрок далеко от NPC при деспавне — NPC удаляется тихо.
    despawnHideDist = 1500,

    -- Дистанция слышимости выстрела для тревоги (ед.). Чисто косметическая в текущей версии.
    shotHearDist    = 1200,


    -- Leash-дистанция: враг дальше этого порога от игрока удаляется тихо,
    -- даже если шум ещё высокий (NPC потерялся, застрял, или игрок убежал).
    -- Рекомендуется spawnMaxDist * 1.5, т.е. 5250 при дефолтных настройках.

    leashDist       = 5250,
}

-- ============================================================
-- СИСТЕМА ШУМА
-- ============================================================

C.Noise = {
    -- Верхний предел шкалы шума
    max               = 100,

    -- Порог стелса. Ниже этого значения — враги не спавнятся, уже спавненные начинают grace.
    stealthThreshold  = 5,

    -- Скорость естественного затухания шума (единиц в секунду). Только когда игрок ничего не делает.
    decayPerSecond    = 0.5,

    -- Стартовое значение шума для нового игрока
    startValue        = 0,
}

-- ============================================================
-- ИСТОЧНИКИ ШУМА
-- Сколько шума добавляется за каждое действие.
-- ============================================================

C.Noise.Sources = {
    -- Harvest ноды материала (фиксированное значение, не зависит от тира ноды)
    harvest        = 10,

    -- Scan объекта исследования (фиксированное значение, не зависит от тира)
    scan           = 15,

    -- Взрыв / граната — за штуку
    explosion      = 15,

    -- Получение урона от NPC (за удар)
    takeDamage     = 3,

    -- Езда на технике (в секунду пока игрок за рулём)
    vehiclePerSec  = 1,

    -- Выстрел — дефолт, если оружие не найдено в таблице ниже
    shotDefault    = 4,
}

-- Выстрелы per weapon. Класс оружия → сколько шума добавляет выстрел.
-- Если класса нет в таблице — используется C.Noise.Sources.shotDefault.
C.Noise.WeaponShot = {
    -- Пример: пистолеты тише, тяжёлое оружие громче
    ["weapon_pistol"]     = 2,
    ["weapon_357"]        = 5,
    ["weapon_smg1"]       = 3,
    ["weapon_ar2"]        = 5,
    ["weapon_shotgun"]    = 6,
    ["weapon_crossbow"]   = 1,   -- тихое оружие
    ["weapon_rpg"]        = 15,
    ["weapon_frag"]       = 15,
    ["weapon_slam"]       = 10,
    ["weapon_crowbar"]    = 0,   -- ближний бой вообще тихий
    ["weapon_stunstick"]  = 0,
    ["weapon_physgun"]    = 0,
    ["weapon_physcannon"] = 0,
    ["gmod_tool"]         = 0,
    ["swexp_scanner"]     = 0,   -- сам сканер шума не даёт, а скан — да
}

-- ============================================================
-- ТИРЫ ВРАГОВ — КАЧЕСТВО
-- ============================================================
--
-- Каждый тир описывает какого уровня врагов получит игрок с ThreatTier = N.
--
-- Ключевые поля:
--   hp              — HP, принудительно ставится при спавне
--   damageScale     — множитель входящего урона от NPC к игроку (через EntityTakeDamage)
--   speedScale      — будущий хук, пока информативный
--   viewRange       — SightDistance в SetKeyValue
--   hearingRange    — будущий хук, пока информативный
--   aggression      — 0..1, шанс что NPC сразу идёт в атаку при обнаружении
--
--   npcClasses      — ТВОИ NPC-классы для этого тира.
--                     ВАЖНО: замени на классы установленных на сервере NPC.
--                     По умолчанию стоят HL2 NPC как плейсхолдеры для теста.
--
--   noiseToEnemy    — сколько единиц шума даёт ОДНОГО врага этого тира.
--                     Пример: 20 → Noise 40 = 2 врага, Noise 80 = 4 врага.
--   maxConcurrent   — жёсткий кап врагов этого тира на ОДНОГО игрока.
--   globalCap       — глобальный кап врагов этого тира на ВЕСЬ сервер.
--
--   waveSpawnInterval — интервал между спавном отдельных NPC (сек).
--                       Враги подтягиваются по одному, а не все разом.
--
--   omenSoundMin/Max — время звукового предвестника перед материализацией (сек).
--   omenSounds       — 3D-звуки предвестника (проигрываются в точке спавна)

C.Tier = {

    -- ──────────────── ТИР 1 — периметр ────────────────
    [1] = {
        name            = "Падальщики периметра",
        color           = Color(80, 200, 100),

        hp              = 400,
        damageScale     = 1.0,
        speedScale      = 1.0,
        viewRange       = 20000,
        hearingRange    = 20000,
        aggression      = 0,

        -- ЗАМЕНИ на своих NPC тира 1
        npcClasses      = { "npc_vj_gc_civilian_slasher_male", "npc_vj_gc_pack", "npc_vj_gc_lurker", "npc_vj_gc_civilian_slasher_female", "npc_vj_gc_ds2_crazystalker", "npc_vj_gc_brutez", "npc_vj_gc_growler"},

        noiseToEnemy    = 5,    -- 1 враг за каждые 20 единиц шума
        maxConcurrent   = 6,
        globalCap       = 40,

        waveSpawnInterval = 1,

        omenSoundMin    = 1.5,
        omenSoundMax    = 3,
        omenSounds      = {
            "ambient/creatures/town_child_scream1.wav",
        },
    },

    -- ──────────────── ТИР 2 — внешний рубеж ────────────────
    [2] = {
        name            = "Охотники рубежа",
        color           = Color(80, 160, 255),

        hp              = 600,
        damageScale     = 1.0,
        speedScale      = 1.05,
        viewRange       = 20000,
        hearingRange    = 20000,
        aggression      = 1.0,

        -- ЗАМЕНИ на своих NPC тира 2
        npcClasses      = {"npc_vj_gc_slasher4", "npc_vj_qc_enhancefeeder", "npc_vj_gc_lurker", "npc_vj_gc_enhanced_leaper", "npc_vj_gc_enhanced_puker", "npc_vj_gc_ds2_enhanced_stalker", "npc_vj_ac_twitcher", "npc_vj_gc_swallower", "npc_vj_gc_enhancedbrute1"},

        noiseToEnemy    = 5,
        maxConcurrent   = 6,
        globalCap       = 40,

        waveSpawnInterval = 3,

        omenSoundMin    = 4,
        omenSoundMax    = 6,
        omenSounds      = {
            "npc/zombie/zombie_alert1.wav",
            "npc/fast_zombie/wake1.wav",
        },
    },

    -- ──────────────── ТИР 3 — аномальный сектор ────────────────
    [3] = {
        name            = "Твари аномалий",
        color           = Color(255, 180, 40),

        hp              = 1000,
        damageScale     = 2,
        speedScale      = 2,
        viewRange       = 2000,
        hearingRange    = 2000,
        aggression      = 1.0,

        -- ЗАМЕНИ на своих NPC тира 3
        npcClasses      = { "npc_vj_gc_divider_soldier", "npc_vj_gc_divider_beam", "npc_vj_gc_divider_flame", "npc_vj_gc_divider_linegun", "npc_vj_gc_divider_pistol", "npc_vj_gc_divider_pulse", "npc_vj_gc_divider_rocket", "npc_vj_gc_divider_seeker", "npc_vj_gc_divider_shotgun"},

        noiseToEnemy    = 5,
        maxConcurrent   = 6,
        globalCap       = 40,

        waveSpawnInterval = 3,

        omenSoundMin    = 5,
        omenSoundMax    = 7,
        omenSounds      = {
            "npc/antlion/angry1.wav",
            "npc/antlion_guard/angry1.wav",
        },
    },

    -- ──────────────── ТИР 4 — сердце тьмы ────────────────
    [4] = {
        name            = "Владыки тьмы",
        color           = Color(220, 60, 60),

        hp              = 1000,
        damageScale     = 2.2,
        speedScale      = 1.15,
        viewRange       = 2800,
        hearingRange    = 2200,
        aggression      = 1.0,

        -- ЗАМЕНИ на своих NPC тира 4
        npcClasses      = { "npc_vj_gc_spider", "npc_vj_gc_tripodboss", "npc_vj_ac_gorefiend"},

        noiseToEnemy    = 14,
        maxConcurrent   = 10,
        globalCap       = 20,

        waveSpawnInterval = 3,

        omenSoundMin    = 6,
        omenSoundMax    = 8,
        omenSounds      = {
            "npc/hunter/pain1.wav",
            "npc/combine_soldier/vo/onyourfeetsoldier.wav",
        },
    },
}

-- ============================================================
-- HUD
-- ============================================================

C.HUD = {
    -- Показывать индикатор шума всегда (true) или только при изменении (false)
    alwaysVisible    = true,

    -- Плавность анимации полоски шума
    lerpSpeed        = 6,
}

-- ============================================================
-- ОТЛАДКА
-- ============================================================

C.Debug = {
    -- Печатать в консоль события (спавн, деспавн, смена тира игрока и т.д.)
    verbose          = false,

    -- Рисовать отладочные маркеры админам (точки спавна, пулы)
    drawAdminMarkers = false,
}

-- ============================================================
-- Вспомогательные функции
-- ============================================================

function C.GetTier(tier)
    return C.Tier[math.Clamp(tier or 1, 1, 4)]
end

function C.GetWeaponShotNoise(weaponClass)
    if not weaponClass or weaponClass == "" then return C.Noise.Sources.shotDefault end
    local v = C.Noise.WeaponShot[weaponClass]
    if v ~= nil then return v end
    return C.Noise.Sources.shotDefault
end

-- Возвращает целевое количество врагов для игрока с данным тиром и шумом.
-- Учитывает стелс-порог и кап по тиру. Глобальный кап проверяется в менеджере.
function C.GetTargetEnemyCount(tier, noise)
    if not noise or noise < C.Noise.stealthThreshold then return 0 end
    local tcfg = C.GetTier(tier)
    if not tcfg then return 0 end
    local n2e = tcfg.noiseToEnemy or 20
    local cap = tcfg.maxConcurrent or 4
    local cnt = math.floor(noise / n2e)
    return math.Clamp(cnt, 0, cap)
end

print("[SWExp] Конфиг системы спавна врагов загружен.")
