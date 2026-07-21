-- ============================================================
-- Star Wars: Expedition — Хранилище персонажа (сервер)
-- entities/entities/swexp_char_locker/init.lua
-- ============================================================

AddCSLuaFile('cl_init.lua')
AddCSLuaFile('shared.lua')
include('shared.lua')

-- Максимальное расстояние от игрока до шкафчика (юниты Source)
local USE_DISTANCE = 100

function ENT:Initialize()
    self:SetModel('models/reizer_props/srsp/sci_fi/armory_02_2/armory_02_2.mdl')
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_PLAYER)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end

    self:SetUseType(SIMPLE_USE)
end

function ENT:Use(activator, caller)
    if not IsValid(caller) or not caller:IsPlayer() then return end

    -- Проверяем выбранного персонажа
    if not caller.SWExp_ActiveChar then
        caller:ChatPrint('[Хранилище] Сначала выберите персонажа.')
        return
    end

    -- Проверяем расстояние (дополнительная серверная защита)
    if caller:GetPos():Distance(self:GetPos()) > USE_DISTANCE then
        caller:ChatPrint('[Хранилище] Подойдите ближе.')
        return
    end

    -- Запрашиваем открытие через модуль char_locker
    -- Хук обработан в modules/char_locker/sv_char_locker.lua
    hook.Run('SWExp::LockerUse', caller, self)
end
