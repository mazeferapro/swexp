-- ============================================================
-- Star Wars: Expedition — Хранилище персонажа (клиент)
-- entities/entities/swexp_char_locker/cl_init.lua
-- ============================================================

include('shared.lua')

local LABEL_DIST  = 230
local PROMPT_DIST = 150

function ENT:Draw()
    self:DrawModel()
end

-- ============================================================
-- 3D-метка хранилища (единый стиль: шкаф / ассемблер / шкафчик)
-- ============================================================

hook.Add("PostDrawOpaqueRenderables", "SWExp::DrawCharLockerLabel", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    for _, ent in ipairs(ents.FindByClass("swexp_char_locker")) do
        if not IsValid(ent) then continue end

        local dist = lp:GetPos():Distance(ent:GetPos())
        if dist > LABEL_DIST then continue end

        local fadeAlpha = math.Clamp(
            1 - (dist - PROMPT_DIST) / (LABEL_DIST - PROMPT_DIST), 0, 1)

        local eyeY    = EyeAngles().y
        local pos     = ent:GetPos() + Vector(0, 0, 90)
        local accentC = Color(50, 180, 255)   -- голубой акцент хранилища

        cam.Start3D2D(pos, Angle(0, eyeY - 90, 90), 0.085)

            local boxW = 310
            local boxH = 72
            local bx   = -boxW / 2
            local by   = -boxH / 2

            -- Фон
            draw.RoundedBox(6, bx, by, boxW, boxH,
                Color(6, 12, 20, math.Round(218 * fadeAlpha)))

            -- Рамка
            surface.SetDrawColor(accentC.r, accentC.g, accentC.b, math.Round(155 * fadeAlpha))
            surface.DrawOutlinedRect(bx, by, boxW, boxH, 2)

            -- Левая полоска-акцент
            draw.RoundedBox(3, bx + 3, by + 8, 3, boxH - 16,
                Color(accentC.r, accentC.g, accentC.b, math.Round(200 * fadeAlpha)))

            -- Заголовок
            draw.SimpleText(
                "ХРАНИЛИЩЕ ПЕРСОНАЖА",
                "DermaDefaultBold",
                0, by + 14,
                Color(accentC.r, accentC.g, accentC.b, math.Round(255 * fadeAlpha)),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
            )

            -- Подсказка (показываем только вблизи)
            if dist < PROMPT_DIST then
                local promptAlpha = math.Clamp(1 - dist / PROMPT_DIST, 0, 1)
                draw.SimpleText(
                    "[E]  Открыть хранилище",
                    "DermaDefault",
                    0, by + boxH - 20,
                    Color(200, 200, 200, math.Round(200 * promptAlpha * fadeAlpha)),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
                )
            end

        cam.End3D2D()
    end
end)
