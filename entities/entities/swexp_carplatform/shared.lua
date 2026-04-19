ENT.Type = 'anim'
ENT.Base = 'base_gmodentity'
ENT.PrintName = 'Платформа Гаража'
ENT.Author = 'SWExp'
ENT.Contact = ''
ENT.Purpose = ''
ENT.Instructions = ''
ENT.Spawnable = false
ENT.AdminSpawnable = false
ENT.Category = 'SWExp | Транспорт'
ENT.Editable = false
ENT.Carry = false

function ENT:SetupDataTables()
	self:NetworkVar( 'Int', 0, 'Number' )
    if SERVER then
        self:SetNumber(0)
    end
end