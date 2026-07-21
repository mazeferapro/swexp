--[[--
    SWExp: Сумка смерти — серверная часть
    Entity: nextrp_death_bag
]]--

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/vj_base/duffle_bag.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetMass(10)
    end

    self.SpawnTime = CurTime()
    self.Items     = {}

    -- Время жизни сумки смерти: 5 минут
    self.Lifetime = 300
end

function ENT:SetItems(items)
    self.Items = items or {}
    self:SetNWInt("SWExp_ItemCount", table.Count(self.Items))
end

function ENT:GetItems()
    return self.Items
end

function ENT:Think()
    if CurTime() - self.SpawnTime > self.Lifetime then
        self:Remove()
    end
    self:NextThink(CurTime() + 10)
    return true
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    local dist = activator:GetPos():Distance(self:GetPos())
    local radius = SWExp and SWExp.Inventory and SWExp.Inventory.Config.PickupRadius or 100
    if dist > radius then return end

    -- Открываем UI сумки смерти на клиенте
    netstream.Start(activator, "SWExp::OpenDeathBag", {
        entIndex = self:EntIndex(),
        items    = self.Items
    })
end
