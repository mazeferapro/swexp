-- ============================================================
-- gamemode/config/sh_ranks.lua
-- Конфигурация званий клонов Великой Армии Республики
-- ============================================================

SWExp = SWExp or {}
SWExp.Ranks = SWExp.Ranks or {}

-- ============================================================
-- СПИСОК ЗВАНИЙ (от низшего к высшему)
-- ============================================================

SWExp.Ranks.List = {
    -- Рядовой состав
    {
        id = 'TRP',
        name = 'Рядовой',
        shortName = 'РДВ',
        color = Color(150, 150, 150),
        armor = 0,
        sortOrder = 1
    },
    {
        id = 'CPL',
        name = 'Капрал',
        shortName = 'КПР',
        color = Color(180, 180, 180),
        armor = 5,
        sortOrder = 2
    },
    
    -- Сержантский состав
    {
        id = 'SGT',
        name = 'Сержант',
        shortName = 'СРЖ',
        color = Color(100, 150, 255),
        armor = 10,
        sortOrder = 3
    },
    {
        id = 'SSGT',
        name = 'Старший сержант',
        shortName = 'СТ.СРЖ',
        color = Color(80, 130, 255),
        armor = 15,
        sortOrder = 4
    },
    {
        id = 'SGM',
        name = 'Сержант-майор',
        shortName = 'СРЖ-МАЙ',
        color = Color(60, 110, 255),
        armor = 20,
        sortOrder = 5
    },
    
    -- Офицерский состав
    {
        id = 'LT',
        name = 'Лейтенант',
        shortName = 'ЛЕЙ',
        color = Color(255, 200, 0),
        armor = 25,
        sortOrder = 6
    },
    {
        id = 'CPT',
        name = 'Капитан',
        shortName = 'КПТ',
        color = Color(255, 180, 0),
        armor = 30,
        sortOrder = 7
    },
    {
        id = 'MAJ',
        name = 'Майор',
        shortName = 'МАЙ',
        color = Color(255, 160, 0),
        armor = 35,
        sortOrder = 8
    },
    {
        id = 'CMDR',
        name = 'Командир',
        shortName = 'КМД',
        color = Color(255, 100, 0),
        armor = 40,
        sortOrder = 9
    },
    
    -- Высший состав
    {
        id = 'MCMDR',
        name = 'Маршал-командир',
        shortName = 'МРШ-КМД',
        color = Color(255, 50, 50),
        armor = 50,
        sortOrder = 10
    }
}

-- ============================================================
-- ХЕЛПЕРЫ
-- ============================================================

-- Получить данные звания по ID
function SWExp.Ranks:Get(rankID)
    for _, rank in ipairs(self.List) do
        if rank.id == rankID then
            return rank
        end
    end
    return nil
end

-- Получить полное имя звания
function SWExp.Ranks:GetName(rankID)
    local rank = self:Get(rankID)
    return rank and rank.name or 'НЕИЗВЕСТНО'
end

-- Получить короткое имя
function SWExp.Ranks:GetShortName(rankID)
    local rank = self:Get(rankID)
    return rank and rank.shortName or rankID
end

-- Получить цвет звания
function SWExp.Ranks:GetColor(rankID)
    local rank = self:Get(rankID)
    return rank and rank.color or Color(255, 255, 255)
end

-- Получить броню звания
function SWExp.Ranks:GetArmor(rankID)
    local rank = self:Get(rankID)
    return rank and rank.armor or 0
end

-- ============================================================
-- КОНФИГ ДЛЯ СОВМЕСТИМОСТИ
-- ============================================================

if SERVER then
    SWExp.Config = SWExp.Config or {}
    SWExp.Config.RankArmor = {}
    
    for _, rank in ipairs(SWExp.Ranks.List) do
        SWExp.Config.RankArmor[rank.id] = rank.armor
    end
end