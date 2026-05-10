-- ============================================================
-- Star Wars: Expedition — Ассемблер (клиент)
-- entities/swexp_assembler/cl_init.lua
-- ============================================================

include("shared.lua")

local LABEL_DIST  = 230
local PROMPT_DIST = 150

function ENT:Draw()
    self:DrawModel()
end

-- ============================================================
-- 3D-метка ассемблера (стиль терминала исследований)
-- ============================================================

hook.Add("PostDrawOpaqueRenderables", "SWExp::DrawAssemblerLabel", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    for _, ent in ipairs(ents.FindByClass("swexp_assembler")) do
        if not IsValid(ent) then continue end

        local dist = lp:GetPos():Distance(ent:GetPos())
        if dist > LABEL_DIST then continue end

        local fadeAlpha = math.Clamp(
            1 - (dist - PROMPT_DIST) / (LABEL_DIST - PROMPT_DIST), 0, 1)

        -- Материалы в инвентаре игрока: берём из NWInt (синхронизируется сервером),
        -- что позволяет корректно отображать значение без открытия меню ассемблера.
        -- Для обратной совместимости используем _inHand только как запасной вариант.
        local totalMats = lp:GetNWInt("SWExp_MatInHand",
            (SWExp and SWExp.Assembler and SWExp.Assembler._inHand) or 0)

        local eyeY = EyeAngles().y
        local pos  = ent:GetPos() + Vector(0, 0, 60)

        cam.Start3D2D(pos, Angle(0, eyeY - 90, 90), 0.085)

            local hasMats  = totalMats > 0
            local accentC  = hasMats and Color(0, 184, 255) or Color(100, 130, 170)

            local boxW = 240
            local boxH = 68
            local bx   = -boxW / 2
            local by   = -boxH / 2

            -- Фон
            draw.RoundedBox(6, bx, by, boxW, boxH,
                Color(6, 11, 18, math.Round(218 * fadeAlpha)))

            -- Рамка
            surface.SetDrawColor(accentC.r, accentC.g, accentC.b, math.Round(155 * fadeAlpha))
            surface.DrawOutlinedRect(bx, by, boxW, boxH, 2)

            -- Левая полоска
            draw.RoundedBox(3, bx + 3, by + 8, 3, boxH - 16,
                Color(accentC.r, accentC.g, accentC.b, math.Round(255 * fadeAlpha)))

            -- Заголовок
            draw.SimpleText(
                "АССЕМБЛЕР",
                "SWUI.Small",
                0, by + 11,
                Color(accentC.r, accentC.g, accentC.b, math.Round(255 * fadeAlpha)),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
            )

            -- Строка материалов
            if hasMats then
                draw.SimpleText(
                    "Материалы: " .. totalMats .. " ед.",
                    "SWUI.Small",
                    0, by + 32,
                    Color(0, 200, 255, math.Round(240 * fadeAlpha)),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
                )
            else
                draw.SimpleText(
                    "Материалы отсутствуют",
                    "SWUI.Tiny",
                    0, by + 32,
                    Color(120, 150, 175, math.Round(180 * fadeAlpha)),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
                )
            end

            -- Подсказка
            if dist < PROMPT_DIST then
                local pA  = math.Clamp(1 - dist / PROMPT_DIST, 0.2, 1)
                draw.SimpleText(
                    "[E]  Открыть ассемблер",
                    "SWUI.Tiny",
                    0, by + boxH + 7,
                    Color(220, 235, 255, math.Round(190 * pA)),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
                )
            end

        cam.End3D2D()
    end
end)

print("[SWExp] swexp_assembler (клиент) загружен.")
