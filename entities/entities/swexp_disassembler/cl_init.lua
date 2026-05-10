-- ============================================================
-- Star Wars: Expedition — Дисассемблер (клиент)
-- entities/swexp_disassembler/cl_init.lua
-- ============================================================

include("shared.lua")

local LABEL_DIST  = 230
local PROMPT_DIST = 150

function ENT:Draw()
    self:DrawModel()
end

-- ============================================================
-- 3D-метка дисассемблера
-- ============================================================

hook.Add("PostDrawOpaqueRenderables", "SWExp::DrawDisassemblerLabel", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    for _, ent in ipairs(ents.FindByClass("swexp_disassembler")) do
        if not IsValid(ent) then continue end

        local dist = lp:GetPos():Distance(ent:GetPos())
        if dist > LABEL_DIST then continue end

        local fadeAlpha = math.Clamp(
            1 - (dist - PROMPT_DIST) / (LABEL_DIST - PROMPT_DIST), 0, 1)

        local eyeY = EyeAngles().y
        local pos  = ent:GetPos() + Vector(0, 0, 60)

        -- Акцентный цвет дисассемблера — тёплый оранжевый
        local accentC = Color(255, 140, 0)

        cam.Start3D2D(pos, Angle(0, eyeY - 90, 90), 0.085)

            local boxW = 240
            local boxH = 68
            local bx   = -boxW / 2
            local by   = -boxH / 2

            draw.RoundedBox(6, bx, by, boxW, boxH,
                Color(18, 11, 4, math.Round(218 * fadeAlpha)))

            surface.SetDrawColor(accentC.r, accentC.g, accentC.b, math.Round(155 * fadeAlpha))
            surface.DrawOutlinedRect(bx, by, boxW, boxH, 2)

            draw.RoundedBox(3, bx + 3, by + 8, 3, boxH - 16,
                Color(accentC.r, accentC.g, accentC.b, math.Round(255 * fadeAlpha)))

            draw.SimpleText(
                "ДИСАССЕМБЛЕР",
                "SWUI.Small",
                0, by + 11,
                Color(accentC.r, accentC.g, accentC.b, math.Round(255 * fadeAlpha)),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
            )

            draw.SimpleText(
                "Разбор предметов",
                "SWUI.Tiny",
                0, by + 32,
                Color(200, 160, 80, math.Round(200 * fadeAlpha)),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
            )

            if dist < PROMPT_DIST then
                local pA = math.Clamp(1 - dist / PROMPT_DIST, 0.2, 1)
                draw.SimpleText(
                    "[E]  Открыть дисассемблер",
                    "SWUI.Tiny",
                    0, by + boxH + 7,
                    Color(255, 220, 160, math.Round(190 * pA)),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
                )
            end

        cam.End3D2D()
    end
end)

print("[SWExp] swexp_disassembler (клиент) загружен.")
