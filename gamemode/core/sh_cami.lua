-- core/sh_cami.lua
-- Регистрация привилегий CAMI и система проверки прав SWExp.
--
-- Использование:
--   if SWExp:HasPrivilege(pPlayer, "manage_chars") then ... end

SWExp.Permissions = SWExp.Permissions or {}

-- ============================================================
-- Список привилегий
-- Формат: ['ключ'] = { 'MinAccess', 'описание' }
-- MinAccess: 'user' | 'admin' | 'superadmin'
-- ============================================================

local PRIVILEGES = {
    -- Управление
    ['manage_chars'] = {
        'admin',
        'Доступ к управлению персонажами игроков.',
    },
    ['manage_ranks'] = {
        'admin',
        'Доступ к управлению рангами/званиями.',
    },
    ['manage_slots'] = {
        'superadmin',
        'Доступ к управлению слотами персонажей.',
    },
    ['manage_vehs'] = {
        'superadmin',
        'Доступ к управлению транспортом (ангар).',
    },
    ['manage_spawns'] = {
        'admin',
        'Доступ к управлению точками спавна.',
    },
    ['manage_progress'] = {
        'superadmin',
        'Доступ к управлению прогрессом сервера (tech_level, materials).',
    },

    -- Спавн объектов
    ['spawn_sweps'] = {
        'admin',
        'Доступ к спавну оружия (SWEPs).',
    },
    ['spawn_effects'] = {
        'admin',
        'Доступ к спавну эффектов.',
    },
    ['spawn_npc'] = {
        'admin',
        'Доступ к спавну NPC.',
    },
    ['spawn_ragdolls'] = {
        'admin',
        'Доступ к спавну рагдоллов.',
    },
    ['spawn_ents'] = {
        'admin',
        'Доступ к спавну энтитей.',
    },
    ['spawn_props'] = {
        'admin',
        'Доступ к спавну пропов.',
    },

    -- Ивенты
    ['run_event'] = {
        'admin',
        'Доступ к запуску/управлению ивентами.',
    },
    ['screen_notify'] = {
        'superadmin',
        'Доступ к отправке экранных уведомлений.',
    },
}

-- ============================================================
-- Регистрация привилегий в CAMI
-- ============================================================

for sKey, tData in pairs(PRIVILEGES) do
    CAMI.RegisterPrivilege({
        Name        = 'swexp_' .. sKey,
        MinAccess   = tData[1],
        Description = tData[2],
    })
    MsgC(Color(190, 252, 3), '[ SWExp ]', color_white, ' Привилегия "swexp_' .. sKey .. '" зарегистрирована.\n')
end

-- ============================================================
-- Публичный API
-- ============================================================

--- Проверяет наличие привилегии у игрока.
-- @tparam Player pPlayer
-- @tparam string sPrivilege  ключ из таблицы PRIVILEGES (без префикса swexp_)
-- @treturn boolean
function SWExp.Permissions.HasPrivilege(pPlayer, sPrivilege)
    return CAMI.PlayerHasAccess(pPlayer, 'swexp_' .. sPrivilege)
end

--- Алиас через таблицу геймода: SWExp:HasPrivilege(pPlayer, sPrivilege)
function SWExp:HasPrivilege(pPlayer, sPrivilege)
    return SWExp.Permissions.HasPrivilege(pPlayer, sPrivilege)
end