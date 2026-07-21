include('shared.lua')

-- ============================================================
-- Блокировка Q-меню (Spawnmenu) для обычных игроков
-- ============================================================

hook.Add("SpawnMenuOpen", "SWExp::RestrictQMenu", function()
    local ply = LocalPlayer()
    if not (ply:IsAdmin() or ply:IsSuperAdmin()) then
        return false
    end
end)

-- ============================================================
-- Блокировка C-меню (контекстное меню) для обычных игроков
-- ============================================================

hook.Add("OnContextMenuOpen", "SWExp::RestrictCMenu", function()
    local ply = LocalPlayer()
    if not (ply:IsAdmin() or ply:IsSuperAdmin()) then
        return true  -- возврат true отменяет открытие C-меню
    end
end)