-- ============================================================
-- Star Wars: Expedition — Объект исследования (клиент)
-- entities/swexp_research_point/cl_init.lua
-- ============================================================

include("shared.lua")

local MONOLOGUE_DIST = 200
local PROMPT_DIST    = 180

-- ============================================================
-- Перенос текста по ширине (для cam.Start3D2D пространства)
-- ============================================================

local function WrapText(text, font, maxW)
    surface.SetFont(font)
    local words = string.Explode(" ", text)
    local lines, line = {}, ""
    for _, w in ipairs(words) do
        local test = line == "" and w or (line .. " " .. w)
        if surface.GetTextSize(test) > maxW and line ~= "" then
            table.insert(lines, line)
            line = w
        else
            line = test
        end
    end
    if line ~= "" then table.insert(lines, line) end
    return lines
end

-- ============================================================
-- Отрисовка модели
-- ============================================================

function ENT:Draw()
    self:DrawModel()
end

-- ============================================================
-- 3D-метка — монолог клона + подсказка для сканера
-- ============================================================

hook.Add("PostDrawOpaqueRenderables", "SWExp::DrawResearchLabels", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    local eyeY = EyeAngles().y

    for _, ent in ipairs(ents.FindByClass("swexp_research_point")) do
        if not IsValid(ent) then continue end
        if ent:GetNWBool("SWExp_Scanned") then continue end

        local dist = lp:GetPos():Distance(ent:GetPos())
        if dist > MONOLOGUE_DIST then continue end

        local fadeAlpha = math.Clamp(
            1 - (dist - PROMPT_DIST) / (MONOLOGUE_DIST - PROMPT_DIST), 0, 1)

        local name  = ent:GetNWString("SWExp_ResName",      "Неизвестный объект")
        local mono  = ent:GetNWString("SWExp_ResMonologue", "...")
        local pts   = ent:GetNWInt("SWExp_ResPoints",       1)
        local cr    = ent:GetNWInt("SWExp_ColorR", 100)
        local cg    = ent:GetNWInt("SWExp_ColorG", 200)
        local cb    = ent:GetNWInt("SWExp_ColorB", 255)
        local col   = Color(cr, cg, cb)

        local pos = ent:GetPos() + Vector(0, 0, 16)

        cam.Start3D2D(pos, Angle(0, eyeY - 90, 90), 0.065)

            local boxW, boxH = 310, 96
            local bx, by     = -boxW / 2, -boxH / 2

            -- Фон
            draw.RoundedBox(6, bx, by, boxW, boxH,
                Color(6, 11, 18, math.Round(215 * fadeAlpha)))

            -- Рамка
            surface.SetDrawColor(col.r, col.g, col.b, math.Round(155 * fadeAlpha))
            surface.DrawOutlinedRect(bx, by, boxW, boxH, 2)

            -- Левая акцентная полоска
            draw.RoundedBox(3, bx + 3, by + 8, 3, boxH - 16,
                Color(col.r, col.g, col.b, math.Round(255 * fadeAlpha)))

            -- Имя типа объекта (Exo 2 Bold через SWUI.Small)
            draw.SimpleText(
                string.upper(name),
                "SWUI.Small",
                bx + 14, by + 10,
                Color(col.r, col.g, col.b, math.Round(255 * fadeAlpha)),
                TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
            )

            -- Очки исследования (справа)
            draw.SimpleText(
                "+" .. pts .. " ОИ",
                "SWUI.Small",
                bx + boxW - 10, by + 10,
                Color(col.r, col.g, col.b, math.Round(200 * fadeAlpha)),
                TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP
            )

            -- Монолог (максимум 2 строки, SWUI.Tiny)
            local lines = WrapText(mono, "SWUI.Tiny", boxW - 30)
            for i = 1, math.min(#lines, 2) do
                draw.SimpleText(
                    lines[i],
                    "SWUI.Tiny",
                    bx + 14, by + 32 + (i - 1) * 19,
                    Color(190, 212, 235, math.Round(215 * fadeAlpha)),
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
                )
            end

            -- Подсказка со сканером (только вблизи)
            if dist < PROMPT_DIST then
                local pA = math.Clamp(1 - dist / PROMPT_DIST, 0.2, 1)
                draw.SimpleText(
                    "[ЛКМ] Удерживать для сканирования",
                    "SWUI.Tiny",
                    0, by + boxH + 7,
                    Color(220, 230, 255, math.Round(190 * pA)),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
                )
            end

        cam.End3D2D()
    end
end)

print("[SWExp] swexp_research_point (клиент) загружен.")
