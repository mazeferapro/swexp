-- config/sh_admin.lua
-- Список групп, считающихся администраторами в SWExp.
-- Используется SWExp.Utils:IsAdmin() и SWExp.Utils:IsSuperAdmin()

SWExp.Config = SWExp.Config or {}

SWExp.Config.Admins = {
    ['superadmin']       = true,
    ['admin']            = true,
}

SWExp.Config.SuperAdmins = {
    ['superadmin'] = true,
}