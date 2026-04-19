-- ============================================================
-- Star Wars: Expedition — Терминал исследований (клиент)
-- entities/swexp_research_terminal/cl_init.lua
-- ============================================================

include("shared.lua")

local LABEL_DIST  = 230
local PROMPT_DIST = 150

function ENT:Draw()
    self:DrawModel()
end

-- ============================================================
-- 3D-метка терминала (Exo 2 через SWUI)
-- ============================================================

hook.Add("PostDrawOpaqueRenderables", "SWExp::DrawTerminalLabel", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    for _, ent in ipairs(ents.FindByClass("swexp_research_terminal")) do
        if not IsValid(ent) then continue end

        local dist = lp:GetPos():Distance(ent:GetPos())
        if dist > LABEL_DIST then continue end

        local fadeAlpha = math.Clamp(
            1 - (dist - PROMPT_DIST) / (LABEL_DIST - PROMPT_DIST), 0, 1)

        local collected = lp:GetNWInt("SWExp_CollectedRP", 0)
        local eyeY      = EyeAngles().y

        local pos = ent:GetPos() + Vector(0, 0, 54)

        cam.Start3D2D(pos, Angle(0, eyeY - 90, 90), 0.075)

            local hasRP   = collected > 0
            local accentC = hasRP and Color(80, 255, 140) or Color(0, 184, 255)

            local boxW = 260
            local boxH = hasRP and 76 or 56
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
                "ТЕРМИНАЛ ИССЛЕДОВАНИЙ",
                "SWUI.Small",
                0, by + 11,
                Color(accentC.r, accentC.g, accentC.b, math.Round(255 * fadeAlpha)),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
            )

            -- Строка с собранными ОИ
            if hasRP then
                draw.SimpleText(
                    "Собрано ОИ: " .. collected,
                    "SWUI.Small",
                    0, by + 34,
                    Color(80, 255, 140, math.Round(240 * fadeAlpha)),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
                )
            else
                draw.SimpleText(
                    "Нет данных для сдачи",
                    "SWUI.Tiny",
                    0, by + 34,
                    Color(120, 150, 175, math.Round(180 * fadeAlpha)),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
                )
            end

            -- Подсказка
            if dist < PROMPT_DIST then
                local pA  = math.Clamp(1 - dist / PROMPT_DIST, 0.2, 1)
                local tip = hasRP
                    and ("[E]  Сдать " .. collected .. " ОИ в банк")
                    or  "[E]  Открыть терминал"
                draw.SimpleText(
                    tip,
                    "SWUI.Tiny",
                    0, by + boxH + 7,
                    Color(220, 235, 255, math.Round(190 * pA)),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
                )
            end

        cam.End3D2D()
    end
end)

print("[SWExp] swexp_research_terminal (клиент) загружен.")
