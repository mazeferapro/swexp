-- ============================================================
-- SWExp: Player Spawn Point (клиент)
-- entities/swexp_player_spawn/cl_init.lua
--
-- Видимость:
--   • Админы видят маркер с лейблом и стрелкой направления.
--   • Обычные игроки ничего не видят.
-- ============================================================

include("shared.lua")

function ENT:Initialize() end

function ENT:Draw()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if not (lp:IsAdmin() or lp:IsSuperAdmin()) then return end

    local pos   = self:GetPos()
    local label = self:GetSpawnLabel() or "Spawn"

    -- Пульсация для наглядности
    local pulse = 0.5 + math.abs(math.sin(CurTime() * 1.5)) * 0.5
    local a1    = math.Round(60 + pulse * 60)
    local a2    = math.Round(150 + pulse * 80)

    render.SetColorMaterial()

    -- Круг на земле
    render.DrawWireframeSphere(pos + Vector(0, 0, 4), 32, 16, 4,
        Color(80, 180, 255, a1), true)

    -- Центральный маркер
    render.DrawSphere(pos + Vector(0, 0, 36), 10, 12, 12,
        Color(80, 200, 255, a2))

    -- Стрелка направления, куда смотрит точка
    local ang = self:GetAngles()
    render.DrawBeam(
        pos + Vector(0, 0, 36),
        pos + Vector(0, 0, 36) + ang:Forward() * 40,
        6, 0, 1, Color(80, 200, 255, 220))

    -- Метка 3D2D над сущностью
    local eyeY = EyeAngles().y
    cam.Start3D2D(pos + Vector(0, 0, 80), Angle(0, eyeY - 90, 90), 0.12)
        local w, h = 240, 60
        draw.RoundedBox(6, -w/2, -h/2, w, h, Color(6, 12, 18, 220))
        draw.RoundedBox(2, -w/2 + 3, -h/2 + 8, 3, h - 16, Color(80, 200, 255, 220))
        draw.SimpleText("ТОЧКА СПАВНА", "SWUI.Small",
            0, -h/2 + 8, Color(80, 200, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText(string.upper(label), "SWUI.Body",
            0, -h/2 + 28, Color(220, 235, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    cam.End3D2D()
end
