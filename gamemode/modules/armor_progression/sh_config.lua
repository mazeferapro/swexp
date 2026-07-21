-- modules/armor_progression/sh_config.lua
-- Конфигурация прокачки персонажа по классу брони.
-- Shared: загружается и на сервере, и на клиенте.

SWExp = SWExp or {}
SWExp.ArmorProgression = SWExp.ArmorProgression or {}

-- ============================================================
-- ОБЩИЕ ПАРАМЕТРЫ
-- ============================================================

SWExp.ArmorProgression.XPPerKill = 15   -- XP за убийство игрока (фиксировано)
SWExp.ArmorProgression.MaxLevel  = 50

-- ============================================================
-- УРОВНИ (50 штук, генерируются программно)
-- XP = floor(200 * (level-1)^1.5)
-- L2=200 L5=1600 L10=5400 L20=16567 L30=31241 L40=48726 L50=68600
-- ============================================================

local TIER_NAMES = {
    { name = "Новобранец", count = 10 },
    { name = "Рядовой",    count = 10 },
    { name = "Специалист", count = 10 },
    { name = "Ветеран",    count = 10 },
    { name = "Элита",      count = 10 },
}

local ROMAN = { "I","II","III","IV","V","VI","VII","VIII","IX","X" }

SWExp.ArmorProgression.Levels = {}

do
    local lvl = 1
    for _, tier in ipairs(TIER_NAMES) do
        for sub = 1, tier.count do
            local xp = (lvl == 1) and 0 or math.floor(500 * (lvl - 1) ^ 1.5)
            SWExp.ArmorProgression.Levels[lvl] = {
                xp   = xp,
                name = tier.name .. " " .. ROMAN[sub],
            }
            lvl = lvl + 1
        end
    end
end

-- ============================================================
-- ГЕНЕРАЦИЯ КОНФИГА КЛАССОВ (50 уровней на класс)
--
--   maxHP      — плавно от maxHP_min до maxHP_max
--   speedBonus — плавно от 0 до speedMax
--   armorBonus — ступенчато: ≥10→0.5 ≥20→1.0 ≥30→2.0 ≥40→3.5 50→5.0
--   perk       — выдаётся на конкретных уровнях
-- ============================================================

local function MakeClassConfig(opts)
    local cfg = {}
    for i = 1, 50 do
        local t  = (i - 1) / 49

        local hp = math.floor(opts.maxHP_min + (opts.maxHP_max - opts.maxHP_min) * t)
        local sp = math.floor(opts.speedMax * t * 1000 + 0.5) / 1000

        local ab = 0
        if i >= 10 then ab = 0.5 end
        if i >= 20 then ab = 1.0 end
        if i >= 30 then ab = 2.0 end
        if i >= 40 then ab = 3.5 end
        if i == 50 then ab = 5.0 end

        local entry = { maxHP = hp, speedBonus = sp, armorBonus = ab }
        if opts.perks and opts.perks[i] then
            entry.perk = opts.perks[i]
        end

        cfg[i] = entry
    end
    return cfg
end

SWExp.ArmorProgression.ClassConfig = {

    -- Лёгкая (Разведчик): ARF ур.5 / Десантник ур.15 / ARC ур.45
    ["light"] = MakeClassConfig({
        maxHP_min = 100, maxHP_max = 300,
        speedMax  = 0.12,
        perks = {[1] = "perk_clonetrooper" ,[5] = "perk_clonearf", [15] = "perk_cloneairborne", [45] = "perk_clonearc" },
    }),

    -- Средняя (Солдат): Солдат ур.5 / BARC ур.25
    ["medium"] = MakeClassConfig({
        maxHP_min = 100, maxHP_max = 300,
        speedMax  = 0.10,
        perks = { [1] = "perk_clonetrooper", [25] = "perk_clonebarc" },
    }),

    -- Тяжёлая: больший прирост HP, лучший бонус скорости. Командо ур.15
    ["heavy"] = MakeClassConfig({
        maxHP_min = 100, maxHP_max = 300,
        speedMax  = 0.15,
        perks = {[1] = "perk_clonetrooper", [15] = "perk_comando" },
    }),

    -- Инженерная: ARC ур.10
    ["engineer"] = MakeClassConfig({
        maxHP_min = 100, maxHP_max = 300,
        speedMax  = 0.10,
        perks = {[1] = "perk_clonetrooper", [10] = "perk_clonearc" },
    }),

    -- Медицинская: Медик ур.5
    ["medical"] = MakeClassConfig({
        maxHP_min = 100, maxHP_max = 300,
        speedMax  = 0.10,
        perks = {[1] = "perk_clonetrooper", [5] = "perk_clonemedic" },
    }),
}

-- ============================================================
-- ЧЕЛОВЕКОЧИТАЕМЫЕ НАЗВАНИЯ КЛАССОВ
-- ============================================================

SWExp.ArmorProgression.ClassNames = {
    ["light"]    = "Разведчик",
    ["medium"]   = "Солдат",
    ["heavy"]    = "Тяжёлый",
    ["engineer"] = "Инженер",
    ["medical"]  = "Медик",
}

-- ============================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (shared)
-- ============================================================

function SWExp.ArmorProgression:GetLevelForXP(xp)
    local level = 1
    for lvl, data in pairs(self.Levels) do
        if xp >= data.xp and lvl > level then
            level = lvl
        end
    end
    return math.min(level, self.MaxLevel)
end

function SWExp.ArmorProgression:GetNextThreshold(level)
    local next = self.Levels[level + 1]
    return next and next.xp or nil
end

function SWExp.ArmorProgression:GetLevelConfig(armorClass, level)
    local cc = self.ClassConfig[armorClass]
    return cc and cc[level] or nil
end

function SWExp.ArmorProgression:GetUnlockedPerks(armorClass, level)
    local cc = self.ClassConfig[armorClass]
    if not cc then return {} end
    local perks = {}
    for lvl = 1, level do
        local cfg = cc[lvl]
        if cfg and cfg.perk then
            perks[cfg.perk] = true
        end
    end
    return perks
end
