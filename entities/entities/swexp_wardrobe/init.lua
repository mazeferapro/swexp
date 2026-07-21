-- ============================================================
-- Star Wars: Expedition — Шкаф (сервер)
-- entities/entities/swexp_wardrobe/init.lua
-- ============================================================

AddCSLuaFile('cl_init.lua')
AddCSLuaFile('shared.lua')
include('shared.lua')

function ENT:Initialize()
    self:SetModel('models/props_furniture/scifi_refrigerator.mdl')
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_PLAYER)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end

    self:SetUseType(SIMPLE_USE)
end

function ENT:Use(activator, caller)
    if not caller:IsPlayer() then return end
    if not caller.SWExp_ActiveChar then
        caller:ChatPrint('[Шкаф] Сначала выберите персонажа.')
        return
    end

    local char  = caller.SWExp_ActiveChar
    local model = caller:GetModel()

    -- Берём настройки именно для ТЕКУЩЕЙ модели (может быть модель брони)
    local allData   = char.bodygroupsData or {}
    local modelData = allData[model] or {}

    netstream.Start(caller, 'SWExp::OpenWardrobeUI', {
        model      = model,
        skin       = modelData.skin or 0,
        bodygroups = modelData.bodygroups or {},
    })
end
