-- ============================================================
-- Star Wars: Expedition — Точка добычи материалов (клиент)
-- entities/swexp_material_node/cl_init.lua
-- ============================================================

include("shared.lua")

local PROMPT_DIST    = 160
local MONOLOGUE_DIST = 220

-- ============================================================
-- Оборачивание текста (должно быть ПЕРВЫМ)
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
-- Кэш монологов
-- ============================================================

local MonologueCache = {}   -- ent -> { lines = {...}, lastText = "..." }

local function GetWrappedMonologue(ent, text, maxW)
    if not IsValid(ent) then return {} end

    local cache = MonologueCache[ent]
    if cache and cache.lastText == text then
        return cache.lines
    end

    local lines = WrapText(text, "SWUI.Tiny", maxW)
    MonologueCache[ent] = { lines = lines, lastText = text }
    return lines
end

-- ============================================================
-- Кэш активных узлов (главная оптимизация FPS)
-- ============================================================

local MaterialNodes = {}

hook.Add("OnEntityCreated", "SWExp::TrackMatNodes", function(ent)
    if IsValid(ent) and ent:GetClass() == "swexp_material_node" then
        MaterialNodes[ent] = true
    end
end)

hook.Add("EntityRemoved", "SWExp::TrackMatNodes", function(ent)
    if ent:GetClass() == "swexp_material_node" then
        MaterialNodes[ent] = nil
        MonologueCache[ent] = nil
    end
end)

-- На случай загрузки скрипта после спавна узлов
timer.Simple(0, function()
    for _, ent in ipairs(ents.FindByClass("swexp_material_node")) do
        if IsValid(ent) then
            MaterialNodes[ent] = true
        end
    end
end)

-- ============================================================
-- Отрисовка модели + пульсирующее свечение
-- ============================================================

function ENT:Draw()
    self:DrawModel()

    if not self:GetNWBool("SWExp_Depleted") then
        local t     = CurTime()
        local pulse = math.abs(math.sin(t * 2.0)) * 0.55 + 0.18
        local cr    = self:GetNWInt("SWExp_ColorR", 100)
        local cg    = self:GetNWInt("SWExp_ColorG", 200)
        local cb    = self:GetNWInt("SWExp_ColorB", 100)

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
-- 3D-метки (оптимизировано)
-- ============================================================

hook.Add("PostDrawOpaqueRenderables", "SWExp::DrawMaterialLabels", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    local eyeY  = EyeAngles().y
    local lpPos = lp:GetPos()

    for ent in pairs(MaterialNodes) do
        if not IsValid(ent) then
            MaterialNodes[ent] = nil
            MonologueCache[ent] = nil
            continue
        end
        if ent:GetNWBool("SWExp_Depleted") then continue end

        local dist = lpPos:Distance(ent:GetPos())
        if dist > MONOLOGUE_DIST then continue end

        local fade = math.Clamp(1 - (dist - PROMPT_DIST) / (MONOLOGUE_DIST - PROMPT_DIST), 0, 1)
        local a    = math.Round(255 * fade)

        local name    = ent:GetNWString("SWExp_MatName", "Ресурс")
        local mono    = ent:GetNWString("SWExp_MatMonologue", "...")
        local amount  = ent:GetNWInt("SWExp_MatAmount", 1)
        local charges = ent:GetNWInt("SWExp_MatCharges", 1)
        local maxCh   = ent:GetNWInt("SWExp_MatMaxCharges", 1)
        local tier    = ent:GetNWInt("SWExp_Tier", 1)
        local cr      = ent:GetNWInt("SWExp_ColorR", 100)
        local cg      = ent:GetNWInt("SWExp_ColorG", 200)
        local cb      = ent:GetNWInt("SWExp_ColorB", 100)

        local pos = ent:GetPos() + Vector(0, 0, 18)

        cam.Start3D2D(pos, Angle(0, eyeY - 90, 90), 0.065)

            local boxW, boxH = 330, 100
            local bx, by     = -boxW / 2, -boxH / 2

            -- Фон
            draw.RoundedBox(6, bx, by, boxW, boxH, Color(6, 11, 18, math.Round(215 * fade)))

            -- Рамка
            surface.SetDrawColor(cr, cg, cb, math.Round(155 * fade))
            surface.DrawOutlinedRect(bx, by, boxW, boxH, 2)

            -- Левая акцентная полоска
            draw.RoundedBox(3, bx + 3, by + 8, 3, boxH - 16, Color(cr, cg, cb, a))

            -- Название ресурса
            draw.SimpleText(
                string.upper(name),
                "SWUI.Small",
                bx + 14, by + 10,
                Color(cr, cg, cb, a),
                TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
            )

            -- Тир
            draw.SimpleText(
                "ТИР " .. tier,
                "SWUI.Tiny",
                bx + boxW - 10, by + 10,
                Color(cr, cg, cb, math.Round(180 * fade)),
                TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP
            )

            -- Количество
            draw.SimpleText(
                "+" .. amount .. " мат.",
                "SWUI.Small",
                bx + boxW - 10, by + 27,
                Color(cr, cg, cb, math.Round(200 * fade)),
                TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP
            )

            -- Монолог (из кэша)
            local lines = GetWrappedMonologue(ent, mono, boxW - 30)
            for i = 1, math.min(#lines, 2) do
                draw.SimpleText(
                    lines[i],
                    "SWUI.Tiny",
                    bx + 14, by + 32 + (i - 1) * 19,
                    Color(190, 212, 235, math.Round(215 * fade)),
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
                )
            end

            -- Полоска зарядов
            if maxCh > 1 then
                local barW  = boxW - 28
                local barH  = 5
                local barX  = bx + 14
                local barY  = by + boxH - 14
                local fillW = math.Round(barW * (charges / maxCh))

                draw.RoundedBox(2, barX - 1, barY - 1, barW + 2, barH + 2,
                    Color(0, 0, 0, math.Round(120 * fade)))
                draw.RoundedBox(2, barX, barY, barW, barH,
                    Color(10, 20, 30, math.Round(200 * fade)))
                if fillW > 0 then
                    draw.RoundedBox(2, barX, barY, fillW, barH,
                        Color(cr, cg, cb, math.Round(220 * fade)))
                end
            end

            -- Подсказка [E]
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
-- Клиентский прогресс-бар добычи (HUD)
-- ============================================================

local _gatherActive    = false
local _gatherName      = ""
local _gatherStartTime = 0
local _gatherDuration  = 3.5

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

    local p = math.Clamp((CurTime() - _gatherStartTime) / _gatherDuration, 0, 1)

    local sw, sh = ScrW(), ScrH()

    local cr = math.Round(Lerp(p, 255, 80))
    local cg = math.Round(Lerp(p, 140, 220))
    local cb = math.Round(Lerp(p, 40,  80))

    local barW = S(260)
    local barH = S(10)
    local barX = (sw - barW) / 2
    local barY = sh * 0.64

    draw.RoundedBox(S(3), barX - 1, barY - 1, barW + 2, barH + 2, Color(0, 0, 0, 150))
    draw.RoundedBox(S(3), barX, barY, barW, barH, Color(10, 20, 30, 210))

    local fillW = math.Round(barW * p)
    if fillW > 0 then
        draw.RoundedBox(S(3), barX, barY, fillW, barH, Color(cr, cg, cb, 230))
    end

    draw.SimpleText(
        "ДОБЫЧА: " .. string.upper(_gatherName) .. "... " .. math.Round(p * 100) .. "%",
        "SWUI.Small",
        sw / 2, barY - S(18),
        Color(cr, cg, cb, 255),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
    )
end)

print("[SWExp] swexp_material_node (клиент) загружен. [OPTIMIZED v2]")