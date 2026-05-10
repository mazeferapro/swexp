-- ============================================================
-- SWExp: Safezone (swexp_safezone)
--
-- Админ-сущность, обозначающая безопасную территорию (хаб).
-- Внутри safezone:
--   • ThreatTier игрока сохраняется в LastThreatTier и обнуляется.
--   • Враги из пула игрока деспавнятся.
--   • Любой живой NPC, пересёкший границу, удаляется.
--   • Шум игрока затухает быстрее.
--
-- Параметры:
--   Radius    — радиус в юнитах (по умолчанию 1500)
--   HubName   — опциональное имя хаба для логов и админ-меток
-- ============================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "SWExp Safezone"
ENT.Category  = "SWExp Entities"
ENT.Spawnable = true
ENT.AdminOnly = true

function ENT:SetupDataTables()
    self:NetworkVar("Int",    0, "Radius")
    self:NetworkVar("String", 0, "HubName")
end

function ENT:GravGunPickupAllowed() return false end

-- Проверка: находится ли точка/игрок внутри этой safezone (радиус уже включает buffer)
function ENT:ContainsPos(vPos, bufferExtra)
    if not IsValid(self) then return false end
    local r = (self:GetRadius() or 1500) + (bufferExtra or 0)
    return self:GetPos():DistToSqr(vPos) <= (r * r)
end
