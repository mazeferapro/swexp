AddCSLuaFile( 'cl_init.lua' )
AddCSLuaFile( 'shared.lua' )
 
include('shared.lua')
 
function ENT:Initialize()
	self:SetModel('models/hunter/plates/plate2x4.mdl')
	self:SetSolid( SOLID_BBOX )
	self:DropToFloor()
	self:SetMoveType( MOVETYPE_NONE )
	self:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
	self:SetUseType( SIMPLE_USE )

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
	end

	self:SetMaterial( 'models/debug/debugwhite' )
    -- Голубоватый полупрозрачный цвет в стиле SWExp
	self:SetColor(Color(0, 184, 255, 100))
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
	self:DrawShadow(false)
end

function ENT:Use()
	self:DropToFloor()
end