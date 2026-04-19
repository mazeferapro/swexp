--[[--
    SWExp: Выброшенный предмет — серверная часть
    Entity: nextrp_dropped_item
]]--

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_junk/cardboard_box002a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetMass(5)
    end

    self.SpawnTime = CurTime()
    self.ItemID    = nil
    self.Amount    = 1
end

function ENT:SetItemData(itemID, amount)
    self.ItemID = itemID
    self.Amount = amount or 1

    -- Передаём данные клиенту через NW
    self:SetNWString("SWExp_ItemID", itemID)
    self:SetNWInt("SWExp_Amount", self.Amount)

    -- Пытаемся взять модель из определения предмета
    local itemData = SWExp and SWExp.Inventory and SWExp.Inventory:GetItemData(itemID)
    if itemData and itemData.worldModel then
        self:SetModel(itemData.worldModel)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end
    end
end

function ENT:Think()
    local lifetime = SWExp and SWExp.Inventory and SWExp.Inventory.Config.DroppedItemLifetime or 300
    if CurTime() - self.SpawnTime > lifetime then
        self:Remove()
    end
    self:NextThink(CurTime() + 5)
    return true
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if not self.ItemID then return end

    local dist = activator:GetPos():Distance(self:GetPos())
    local radius = SWExp and SWExp.Inventory and SWExp.Inventory.Config.PickupRadius or 100
    if dist > radius then return end

    local success = SWExp.Inventory:AddItem(activator, self.ItemID, self.Amount)
    if success then
        self:Remove()
    end
end
