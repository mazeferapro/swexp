-- ============================================================
-- SWExp: Player Spawn Point (shared)
-- entities/swexp_player_spawn/shared.lua
--
-- Админ-сущность — точка спавна игрока. Игрок появляется на
-- одной из таких точек:
--   • при первом входе на сервер (нет сохранённой локации);
--   • после "настоящей" смерти (saved location очищается).
--
-- При обычном выходе/респавне через дефибриллятор появление
-- идёт по сохранённой локации (см. modules/sv_spawn_location.lua).
--
-- Параметры:
--   SpawnLabel — опциональная метка (для админ-меню/логов).
-- ============================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "SWExp Player Spawn"
ENT.Category  = "SWExp Entities"
ENT.Spawnable = true
ENT.AdminOnly = true

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "SpawnLabel")
end

function ENT:GravGunPickupAllowed() return false end
