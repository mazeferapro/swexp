--[[--
    SWExp: Сумка смерти — клиентская часть
    Entity: nextrp_death_bag
]]--

include("shared.lua")

function ENT:Draw()
    self:DrawModel()
end

-- Рендерим иконку и надпись над сумкой
hook.Add("PostDrawOpaqueRenderables", "SWExp::DrawDeathBagLabels", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    for _, ent in ipairs(ents.FindByClass("nextrp_death_bag")) do
        if not IsValid(ent) then continue end

        local dist = lp:GetPos():Distance(ent:GetPos())
        if dist > 250 then continue end

        local itemCount = ent:GetNWInt("SWExp_ItemCount", 0)
        local alpha     = math.Clamp(1 - (dist / 250), 0.3, 1)

        local pos = ent:GetPos() + Vector(0, 0, 25)

        cam.Start3D2D(pos, Angle(0, EyeAngles().y - 90, 90), 0.12)
            -- Фон
            draw.RoundedBox(8, -120, -22, 240, 44,
                Color(20, 5, 5, math.Round(210 * alpha)))

            -- Красная рамка (смерть)
            surface.SetDrawColor(220, 40, 40, math.Round(200 * alpha))
            surface.DrawOutlinedRect(-120, -22, 240, 44, 2)

            -- Название
            draw.SimpleText(
                "☠ СУМКА СНАРЯЖЕНИЯ",
                "DermaDefault",
                0, -6,
                Color(220, 60, 60, math.Round(255 * alpha)),
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER
            )

            -- Количество предметов
            draw.SimpleText(
                "Предметов: " .. itemCount,
                "DermaDefault",
                0, 10,
                Color(200, 200, 200, math.Round(200 * alpha)),
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER
            )

            -- Подсказка
            local pickupAlpha = math.Clamp((120 - dist) / 120, 0, 1)
            if pickupAlpha > 0 then
                draw.SimpleText(
                    "[E] Открыть",
                    "DermaDefault",
                    0, 30,
                    Color(255, 255, 255, math.Round(200 * pickupAlpha)),
                    TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_CENTER
                )
            end
        cam.End3D2D()
    end
end)
