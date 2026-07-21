-- ============================================================
-- Star Wars: Expedition — Шкаф (клиент)
-- entities/entities/swexp_wardrobe/cl_init.lua
-- ============================================================

include('shared.lua')

local LABEL_DIST  = 230
local PROMPT_DIST = 150

function ENT:Draw()
    self:DrawModel()
end

-- ============================================================
-- 3D-метка шкафа (единый стиль: ассемблер / дисассемблер / терминал)
-- ============================================================

hook.Add("PostDrawOpaqueRenderables", "SWExp::DrawWardrobeLabel", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    for _, ent in ipairs(ents.FindByClass("swexp_wardrobe")) do
        if not IsValid(ent) then continue end

        local dist = lp:GetPos():Distance(ent:GetPos())
        if dist > LABEL_DIST then continue end

        local fadeAlpha = math.Clamp(
            1 - (dist - PROMPT_DIST) / (LABEL_DIST - PROMPT_DIST), 0, 1)

        local eyeY    = EyeAngles().y
        local pos     = ent:GetPos() + Vector(0, 0, 100)
        local accentC = Color(180, 80, 255)  -- фиолетовый акцент шкафа

        cam.Start3D2D(pos, Angle(0, eyeY - 90, 90), 0.085)

            local boxW = 260
            local boxH = 68
            local bx   = -boxW / 2
            local by   = -boxH / 2

            -- Фон
            draw.RoundedBox(6, bx, by, boxW, boxH,
                Color(10, 6, 18, math.Round(218 * fadeAlpha)))

            -- Рамка
            surface.SetDrawColor(accentC.r, accentC.g, accentC.b, math.Round(155 * fadeAlpha))
            surface.DrawOutlinedRect(bx, by, boxW, boxH, 2)

            -- Левая полоска
            draw.RoundedBox(3, bx + 3, by + 8, 3, boxH - 16,
                Color(accentC.r, accentC.g, accentC.b, math.Round(255 * fadeAlpha)))

            -- Заголовок
            draw.SimpleText(
                "ШКАФ",
                "SWUI.Small",
                0, by + 11,
                Color(accentC.r, accentC.g, accentC.b, math.Round(255 * fadeAlpha)),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
            )

            -- Описание
            draw.SimpleText(
                "Изменение внешнего вида персонажа",
                "SWUI.Tiny",
                0, by + 32,
                Color(190, 150, 230, math.Round(200 * fadeAlpha)),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
            )

            -- Подсказка
            if dist < PROMPT_DIST then
                local pA = math.Clamp(1 - dist / PROMPT_DIST, 0.2, 1)
                draw.SimpleText(
                    "[E]  Открыть шкаф",
                    "SWUI.Tiny",
                    0, by + boxH + 7,
                    Color(220, 200, 255, math.Round(190 * pA)),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
                )
            end

        cam.End3D2D()
    end
end)

print("[SWExp] swexp_wardrobe (клиент) загружен.")
