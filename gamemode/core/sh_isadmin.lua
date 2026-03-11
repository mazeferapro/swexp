-- core/utils/sh_isadmin.lua
-- Утилиты для проверки прав игрока.
-- Работает как без внешнего админ-мода (по SWExp.Config.Admins),
-- так и совместно с SAM/ULX/любым CAMI-совместимым модом.

SWExp.Utils = SWExp.Utils or {}

--- Проверяет, является ли игрок администратором любого уровня.
-- При наличии SAM использует его группы через pPlayer:GetUserGroup().
-- @tparam Player pPlayer
-- @treturn boolean
function SWExp.Utils:IsAdmin(pPlayer)
    if not IsValid(pPlayer) then return false end
    return SWExp.Config.Admins[pPlayer:GetUserGroup()] or false
end

--- Проверяет, является ли игрок суперадминистратором.
-- @tparam Player pPlayer
-- @treturn boolean
function SWExp.Utils:IsSuperAdmin(pPlayer)
    if not IsValid(pPlayer) then return false end
    return SWExp.Config.SuperAdmins[pPlayer:GetUserGroup()] or false
end

-- ============================================================
-- Синхронизация с CAMI (SAM / ULX / любой совместимый мод)
-- Когда SAM меняет группу игрока — он вызывает этот хук,
-- и pPlayer:GetUserGroup() сразу возвращает новое значение.
-- Хук нужен чтобы уведомить остальные системы геймода.
-- ============================================================

hook.Add('CAMI.PlayerUsergroupChanged', 'SWExp::OnUsergroupChanged', function(pPlayer, sOld, sNew)
    if not IsValid(pPlayer) then return end

    MsgC(
        Color(190, 252, 3), '[ SWExp ]',
        color_white, ' Группа игрока ', Color(255, 200, 0), pPlayer:Nick(),
        color_white, ' изменена: ', sOld, ' → ', sNew, '\n'
    )

    -- Уведомляем остальные системы геймода об изменении прав
    hook.Run('SWExp::PlayerUsergroupChanged', pPlayer, sOld, sNew)
end)