-- ============================================================
-- SWExp: Safezone (клиент)
-- entities/swexp_safezone/cl_init.lua
--
-- Видимость:
--   • Админы видят сферу радиуса + метку "ХАБ · имя".
--   • Обычные игроки ничего не видят (внешне это воздух).
-- ============================================================

include("shared.lua")

function ENT:Initialize() end

function ENT:Draw()
    -- Обычные игроки ничего не видят
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if not (lp:IsAdmin() or lp:IsSuperAdmin()) then return end

    local pos    = self:GetPos()
    local radius = self:GetRadius() or 1500
    local name   = self:GetHubName() or "Хаб"

    -- Пульсация для наглядности
    local pulse  = 0.5 + math.abs(math.sin(CurTime() * 1.2)) * 0.5
    local a1     = math.Round(30 + pulse * 35)
    local a2     = math.Round(90 + pulse * 40)

    -- Основной круг на земле (плашка с радиусом)
    render.SetColorMaterial()
    render.DrawWireframeSphere(pos, radius, 24, 12, Color(0, 255, 180, a1), true)

    -- Центральный маркер
    render.DrawSphere(pos + Vector(0, 0, 30), 12, 8, 8, Color(0, 255, 180, a2))

    -- Метка 3D2D над сущностью
    local eyeY = EyeAngles().y
    cam.Start3D2D(pos + Vector(0, 0, 60), Angle(0, eyeY - 90, 90), 0.12)
        local w, h = 240, 60
        draw.RoundedBox(6, -w/2, -h/2, w, h, Color(6, 12, 18, 220))
        draw.RoundedBox(2, -w/2 + 3, -h/2 + 8, 3, h - 16, Color(0, 255, 180, 220))
        draw.SimpleText("БЕЗОПАСНАЯ ЗОНА", "SWUI.Small",
            0, -h/2 + 8, Color(0, 255, 180, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText(string.upper(name), "SWUI.Body",
            0, -h/2 + 28, Color(220, 235, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    cam.End3D2D()
end
