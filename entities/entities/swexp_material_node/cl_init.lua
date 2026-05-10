-- ============================================================
-- Star Wars: Expedition — Точка добычи материалов (клиент)
-- entities/swexp_material_node/cl_init.lua
-- ============================================================

include("shared.lua")

local PROMPT_DIST    = 160
local MONOLOGUE_DIST = 220

-- ============================================================
-- Перенос текста (аналогично research_point)
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

    -- Пульсирующее свечение вокруг не-истощённых узлов
    if not self:GetNWBool("SWExp_Depleted") then
        local t    = CurTime()
        local pulse = math.abs(math.sin(t * 2.0)) * 0.6 + 0.15
        local cr   = self:GetNWInt("SWExp_ColorR", 100)
        local cg   = self:GetNWInt("SWExp_ColorG", 200)
        local cb   = self:GetNWInt("SWExp_ColorB", 100)

        render.SetColorModulation(
            Lerp(pulse, 1, cr / 255),
            Lerp(pulse, 1, cg / 255),
            Lerp(pulse, 1, cb / 255)
        )
        self:DrawModel()
        render.SetColorModulation(1, 1, 1)
    end
end

-- ============================================================
-- 3D-метка — название ресурса, количество и подсказка [E]
-- ============================================================

hook.Add("PostDrawOpaqueRenderables", "SWExp::DrawMaterialLabels", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    local eyeY = EyeAngles().y

    for _, ent in ipairs(ents.FindByClass("swexp_material_node")) do
        if not IsValid(ent) then continue end
        if ent:GetNWBool("SWExp_Depleted") then continue end

        local dist = lp:GetPos():Distance(ent:GetPos())
        if dist > MONOLOGUE_DIST then continue end

        local fadeAlpha = math.Clamp(
            1 - (dist - PROMPT_DIST) / (MONOLOGUE_DIST - PROMPT_DIST), 0, 1)

        local name     = ent:GetNWString("SWExp_MatName",      "Ресурс")
        local mono     = ent:GetNWString("SWExp_MatMonologue", "...")
        local amount   = ent:GetNWInt("SWExp_MatAmount",       1)
        local charges  = ent:GetNWInt("SWExp_MatCharges",      1)
        local maxCh    = ent:GetNWInt("SWExp_MatMaxCharges",   1)
        local tier     = ent:GetNWInt("SWExp_Tier",            1)
        local cr       = ent:GetNWInt("SWExp_ColorR", 100)
        local cg       = ent:GetNWInt("SWExp_ColorG", 200)
        local cb       = ent:GetNWInt("SWExp_ColorB", 100)
        local col      = Color(cr, cg, cb)

        local pos = ent:GetPos() + Vector(0, 0, 18)

        cam.Start3D2D(pos, Angle(0, eyeY - 90, 90), 0.065)

            local boxW, boxH = 330, 100
            local bx, by    = -boxW / 2, -boxH / 2

            -- Фон
            draw.RoundedBox(6, bx, by, boxW, boxH,
                Color(6, 11, 18, math.Round(215 * fadeAlpha)))

            -- Рамка
            surface.SetDrawColor(col.r, col.g, col.b, math.Round(155 * fadeAlpha))
            surface.DrawOutlinedRect(bx, by, boxW, boxH, 2)

            -- Левая акцентная полоска
            draw.RoundedBox(3, bx + 3, by + 8, 3, boxH - 16,
                Color(col.r, col.g, col.b, math.Round(255 * fadeAlpha)))

            -- Название ресурса
            draw.SimpleText(
                string.upper(name),
                "SWUI.Small",
                bx + 14, by + 10,
                Color(col.r, col.g, col.b, math.Round(255 * fadeAlpha)),
                TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
            )

            -- Тир (правый верхний угол)
            draw.SimpleText(
                "ТИР " .. tier,
                "SWUI.Tiny",
                bx + boxW - 10, by + 10,
                Color(col.r, col.g, col.b, math.Round(180 * fadeAlpha)),
                TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP
            )

            -- Количество материалов за добычу
            draw.SimpleText(
                "+" .. amount .. " мат.",
                "SWUI.Small",
                bx + boxW - 10, by + 27,
                Color(col.r, col.g, col.b, math.Round(200 * fadeAlpha)),
                TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP
            )

            -- Монолог
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

            -- Заряды (полоска)
            if maxCh > 1 then
                local barW   = boxW - 28
                local barH   = 5
                local barX   = bx + 14
                local barY   = by + boxH - 14
                local fillW  = math.Round(barW * (charges / maxCh))

                draw.RoundedBox(2, barX - 1, barY - 1, barW + 2, barH + 2,
                    Color(0, 0, 0, math.Round(120 * fadeAlpha)))
                draw.RoundedBox(2, barX, barY, barW, barH,
                    Color(10, 20, 30, math.Round(200 * fadeAlpha)))
                if fillW > 0 then
                    draw.RoundedBox(2, barX, barY, fillW, barH,
                        Color(col.r, col.g, col.b, math.Round(220 * fadeAlpha)))
                end
            end

            -- Подсказка [E] вблизи
            if dist < PROMPT_DIST then
                local pA = math.Clamp(1 - dist / PROMPT_DIST, 0.2, 1)
                draw.SimpleText(
                    "[E] Удерживать для добычи",
                    "SWUI.Tiny",
                    0, by + boxH + 7,
                    Color(220, 230, 255, math.Round(190 * pA)),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
                )
            end

        cam.End3D2D()
    end
end)

-- ============================================================
-- Клиентский прогресс-бар зажатия E (HUD)
-- ============================================================
-- Прогресс считается локально по CurTime() — так же, как в сканере.
-- Сервер шлёт только два события: Start (имя + длительность + время старта)
-- и Stop (отмена или завершение). Никаких периодических пакетов.

local _gatherActive    = false
local _gatherName      = ""
local _gatherStartTime = 0     -- CurTime() момента старта на сервере
local _gatherDuration  = 3.5   -- длительность добычи (приходит с сервера)

net.Receive("SWExp::Gather_Start", function()
    _gatherName      = net.ReadString()
    _gatherDuration  = net.ReadFloat()
    _gatherStartTime = net.ReadFloat()
    _gatherActive    = true
end)

net.Receive("SWExp::Gather_Stop", function()
    _gatherActive = false
end)

local function S(n)
    return math.Round(n * (ScrH() / 1080))
end

hook.Add("HUDPaint", "SWExp::GatherHUD", function()
    if not _gatherActive then return end

    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    -- Прогресс считается каждый кадр прямо здесь — никаких рывков
    local p = math.Clamp((CurTime() - _gatherStartTime) / _gatherDuration, 0, 1)

    local sw, sh = ScrW(), ScrH()

    -- Цвет: оранжевый → зелёный (как в сканере синий → зелёный)
    local cr = math.Round(Lerp(p, 255, 80))
    local cg = math.Round(Lerp(p, 140, 220))
    local cb = math.Round(Lerp(p, 40,  80))

    local barW = S(260)
    local barH = S(10)
    local barX = (sw - barW) / 2
    local barY = sh * 0.64

    -- Фон и рамка (точно как в сканере)
    draw.RoundedBox(S(3), barX - 1, barY - 1, barW + 2, barH + 2, Color(0, 0, 0, 150))
    draw.RoundedBox(S(3), barX, barY, barW, barH, Color(10, 20, 30, 210))

    -- Заполнение
    local fillW = math.Round(barW * p)
    if fillW > 0 then
        draw.RoundedBox(S(3), barX, barY, fillW, barH, Color(cr, cg, cb, 230))
    end

    -- Текст сверху (стиль сканера)
    draw.SimpleText(
        "ДОБЫЧА: " .. string.upper(_gatherName) .. "... " .. math.Round(p * 100) .. "%",
        "SWUI.Small",
        sw / 2, barY - S(18),
        Color(cr, cg, cb, 255),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
    )
end)

print("[SWExp] swexp_material_node (клиент) загружен.")
