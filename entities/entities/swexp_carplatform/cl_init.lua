include('shared.lua')

-- Изменили convar на swexp_
local SHOULD_DRAW = CreateConVar( 'swexp_showplatforms', 0, FCVAR_ARCHIVE, 'Показывает или скрывает платформы техники' )

function ENT:Initialize()
	self:SetNoDraw(true)
end

function ENT:Think()
	self:SetNoDraw(not SHOULD_DRAW:GetBool())
end

function ENT:Draw()
	if self:GetNoDraw() then return end
    self:DrawModel()

    local distance = LocalPlayer():GetPos():DistToSqr(self:GetPos())
	if distance > 30000 * 2 then return end

	local ang = LocalPlayer():EyeAngles()
	local pos = self:GetPos() + ang:Up() * 5 + Vector(0, 0, 10)

	ang:RotateAroundAxis(ang:Forward(), 90)
	ang:RotateAroundAxis(ang:Right(), 90)

	local alpha = math.Clamp(math.Remap(distance, 30000 * 0.25, 30000, 255, 0), 0, 255)

    cam.Start3D2D( pos, ang, 0.04 )
        -- Используем шрифт и цвет из новой библиотеки
		draw.SimpleText( 'ПЛАТФОРМА #' .. self:GetNumber(), 'SWUI.Header', 0, 0, Color(0, 184, 255, alpha), TEXT_ALIGN_CENTER )
	cam.End3D2D()
end