AddCSLuaFile( 'cl_init.lua' )
AddCSLuaFile( 'shared.lua' )
 
include('shared.lua')
 
function ENT:Initialize()
	self:SetModel('models/props_c17/oildrum001.mdl')
	self:SetHullType( HULL_HUMAN )
	self:SetHullSizeNormal()
	self:SetSolid( SOLID_BBOX )
	self:CapabilitiesAdd( CAP_ANIMATEDFACE )
	self:CapabilitiesAdd( CAP_TURN_HEAD )
	self:DropToFloor()
	self:SetMoveType( MOVETYPE_NONE )
	self:SetCollisionGroup( COLLISION_GROUP_PLAYER )
	self:SetUseType( SIMPLE_USE )

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
	end

	self.Platforms = {}
	self.Vehicles = {}
	self.Faction = TYPE_NONE
end

function ENT:Use(pPlayer)
	-- Передаем NextRPCarList (или пустую таблицу, если он еще не загружен)
	local carList = NextRPCarList or {}
	netstream.Start(pPlayer, 'SWExp::OpenSpawnerMenu', carList, self, self.Platforms, self.Vehicles, self.Faction, carList)
end

function ENT:OnRemove()
	for k, v in pairs(self.Platforms) do 
		if IsValid(v) then v:Remove() end 
	end
end

function ENT:GetPlatforms()
	local t = {}
	for k, v in pairs(self.Platforms) do
		if IsValid(v) then
			t[#t + 1] = {
				pos = v:GetPos(),
				ang = v:GetAngles()
			}
		end
	end
	return t
end

function ENT:SpawnPlatforms(tData)
	for k, v in pairs(self.Platforms) do 
		if IsValid(v) then v:Remove() end 
	end
	self.Platforms = {}

	for k, v in pairs(tData) do
		-- Убедись, что энтити платформы переименована в swexp_carplatform
		local ePlatform = ents.Create('swexp_carplatform')
		if not IsValid(ePlatform) then continue end
		
		ePlatform:SetPos(v.pos)
		ePlatform:SetAngles(v.ang)
		ePlatform:SetNumber(#self.Platforms + 1)
		ePlatform:Spawn()

		self.Platforms[#self.Platforms + 1] = ePlatform
	end
end

function ENT:OnTakeDamage()
    return 0
end

function ENT:Think()
    self:ResetSequence( self:LookupSequence( 'idle_all_01' ) )
    self:ResetSequenceInfo()
end

-- ============================================================================
-- ХУКИ НАСТРОЙКИ (Для Админов)
-- ============================================================================

netstream.Hook('SWExp::SetFactionForDealer', function(pPlayer, eSpawner, nFaction)
	if not pPlayer:IsSuperAdmin() then return end
	eSpawner.Faction = nFaction
end)

netstream.Hook('SWExp::AddPlatform', function(pPlayer, eSpawner)
	if not pPlayer:IsSuperAdmin() then return end
	
	local ePlatform = ents.Create('swexp_carplatform')
	if not IsValid(ePlatform) then return end
	
	ePlatform:SetPos(eSpawner:GetPos() + Vector(0, 0, 100))
	ePlatform:SetNumber(#eSpawner.Platforms + 1)
	ePlatform:Spawn()

	eSpawner.Platforms[#eSpawner.Platforms + 1] = ePlatform

	timer.Simple(.1, function()
		netstream.Start(pPlayer, 'SWExp::OpenSpawnerMenu', NextRPCarList or {}, eSpawner, eSpawner.Platforms, eSpawner.Vehicles, eSpawner.Faction, NextRPCarList or {})
	end)
end)

netstream.Hook('SWExp::RemovePlatform', function(pPlayer, eSpawner, iID)
	if not pPlayer:IsSuperAdmin() then return end
	if not IsValid(eSpawner.Platforms[iID]) then return end

	eSpawner.Platforms[iID]:Remove()
	eSpawner.Platforms[iID] = nil
	
	local counter = 0
	local platformsReplacment = {}

	for k, v in pairs(eSpawner.Platforms) do
		platformsReplacment[counter + 1] = v
		counter = counter + 1
	end

	eSpawner.Platforms = platformsReplacment

	timer.Simple(.1, function()
		netstream.Start(pPlayer, 'SWExp::OpenSpawnerMenu', NextRPCarList or {}, eSpawner, eSpawner.Platforms, eSpawner.Vehicles, eSpawner.Faction, NextRPCarList or {})
	end)
end)

netstream.Hook('SWExp::AddVehicle', function(pPlayer, eSpawner, sClass)
	if not pPlayer:IsSuperAdmin() then return end

	eSpawner.Vehicles[sClass] = true
	
	timer.Simple(.1, function()
		netstream.Start(pPlayer, 'SWExp::OpenSpawnerMenu', NextRPCarList or {}, eSpawner, eSpawner.Platforms, eSpawner.Vehicles, eSpawner.Faction, NextRPCarList or {})
	end)
end)

netstream.Hook('SWExp::RemoveVehicle', function(pPlayer, eSpawner, sClass)
	if not pPlayer:IsSuperAdmin() then return end

	eSpawner.Vehicles[sClass] = false
	
	timer.Simple(.1, function()
		netstream.Start(pPlayer, 'SWExp::OpenSpawnerMenu', NextRPCarList or {}, eSpawner, eSpawner.Platforms, eSpawner.Vehicles, eSpawner.Faction, NextRPCarList or {})
	end)
end)