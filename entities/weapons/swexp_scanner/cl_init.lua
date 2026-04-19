-- ============================================================
-- Star Wars: Expedition — Полевой сканер (клиент)
-- weapons/swexp_scanner/cl_init.lua
-- ============================================================

include("shared.lua")

local function S(n)
    return math.Round(n * (ScrH() / 1080))
end

-- ============================================================
-- PROXIMITY BEEPER
-- ============================================================

local BEEP_RANGE = 600
local BEEP_SOUND = "buttons/button17.wav"
local _beepNext  = 0

hook.Add("Think", "SWExp::ScannerBeeper", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    local wep = lp:GetActiveWeapon()
    if not IsValid(wep) or wep:GetClass() ~= "swexp_scanner" then return end

    local now = CurTime()
    if now < _beepNext then return end

    local nearest = math.huge
    for _, ent in ipairs(ents.FindByClass("swexp_research_point")) do
        if IsValid(ent) and not ent:GetNWBool("SWExp_Scanned") then
            local d = lp:GetPos():Distance(ent:GetPos())
            if d < nearest then nearest = d end
        end
    end
    if nearest >= BEEP_RANGE then return end

    local frac     = 1 - math.Clamp(nearest / BEEP_RANGE, 0, 1)
    local interval = Lerp(frac, 1.8, 0.07)
    local pitch    = math.Round(Lerp(frac, 75, 155))
    local volume   = Lerp(frac, 0.25, 0.75)

    sound.Play(BEEP_SOUND, lp:GetPos(), 60, pitch, volume)
    _beepNext = now + interval
end)

-- ============================================================
-- 3D ЭФФЕКТЫ: луч + каркасный квадрат по объекту
-- ============================================================

local _matLaser   = nil
local SWEEP_SPEED = 1.2   -- циклов в секунду (вверх-вниз)
local BEAM_WIDTH  = 2.0
-- Высота каркасного квадрата-слайса (в локальных единицах)
local SLICE_H     = 4

hook.Add("PostDrawTranslucentRenderables", "SWExp::ScannerFX", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    local wep = lp:GetActiveWeapon()
    if not IsValid(wep) or wep:GetClass() ~= "swexp_scanner" then return end

    local scanning = wep:GetScanning()
    local progress = wep:GetScanProgress()
    local now      = CurTime()

    -- Цвет: синий → зелёный
    local cr = math.Round(Lerp(progress, 80,  50))
    local cg = math.Round(Lerp(progress, 160, 230))
    local cb = math.Round(Lerp(progress, 255, 100))

    -- Цель
    local target = nil
    if scanning then
        local tr = lp:GetEyeTrace()
        if IsValid(tr.Entity)
            and tr.Entity:GetClass() == "swexp_research_point"
            and not tr.Entity:GetNWBool("SWExp_Scanned") then
            target = tr.Entity
        end
    end

    if not IsValid(target) then return end

    _matLaser = _matLaser or Material("effects/laser1")

    -- ============================================================
    -- ЛУЧ ИЗ СТВОЛА — аттачмент muzzle на ViewModel
    -- ============================================================
    local muzzle
    local vm = lp:GetViewModel()
    if IsValid(vm) then
        local attIdx = vm:LookupAttachment("muzzle")
        if attIdx and attIdx > 0 then
            local att = vm:GetAttachment(attIdx)
            if att then muzzle = att.Pos end
        end
    end
    if not muzzle then
        muzzle = wep:GetPos()
    end

    -- RenderBounds
    local rMin, rMax = target:GetRenderBounds()

    -- ============================================================
    -- КАРКАСНЫЙ КВАДРАТ (слайс) — движется вверх-вниз по объекту
    -- ============================================================
    local sweepPhase = (now * SWEEP_SPEED) % 2
    local sweepT     = sweepPhase < 1 and sweepPhase or (2 - sweepPhase)

    local sliceZ = Lerp(sweepT, rMin.z, rMax.z)

    local pad = 3
    local x0, x1 = rMin.x - pad, rMax.x + pad
    local y0, y1 = rMin.y - pad, rMax.y + pad

    local A = target:LocalToWorld(Vector(x0, y0, sliceZ))
    local B = target:LocalToWorld(Vector(x1, y0, sliceZ))
    local C = target:LocalToWorld(Vector(x1, y1, sliceZ))
    local D = target:LocalToWorld(Vector(x0, y1, sliceZ))

    -- Выбираем грань ближайшую к игроку:
    -- середины всех 4 граней, берём ту что ближе к muzzle
    local sides = {
        (A + B) * 0.5,  -- грань AB
        (B + C) * 0.5,  -- грань BC
        (C + D) * 0.5,  -- грань CD
        (D + A) * 0.5,  -- грань DA
    }
    local beamTarget = sides[1]
    local bestDist   = muzzle:DistToSqr(sides[1])
    for i = 2, 4 do
        local d = muzzle:DistToSqr(sides[i])
        if d < bestDist then
            bestDist   = d
            beamTarget = sides[i]
        end
    end

    -- Луч идёт на ближайшую грань движущегося квадрата
    render.SetMaterial(_matLaser)
    render.DrawBeam(
        muzzle, beamTarget,
        BEAM_WIDTH * (0.9 + math.sin(now * 15) * 0.1),
        0, 1,
        Color(cr, cg, cb, math.Round(160 + math.sin(now * 10) * 50))
    )

    render.SetMaterial(_matLaser)
    local lineColor = Color(cr, cg, cb, 230)
    render.DrawBeam(A, B, 2, 0, 1, lineColor)
    render.DrawBeam(B, C, 2, 0, 1, lineColor)
    render.DrawBeam(C, D, 2, 0, 1, lineColor)
    render.DrawBeam(D, A, 2, 0, 1, lineColor)
end)

-- ============================================================
-- HUD — прицел (круг + точка), прогресс-бар, кулдаун
-- ============================================================

hook.Add("HUDPaint", "SWExp::ScannerHUD", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    local wep = lp:GetActiveWeapon()
    if not IsValid(wep) or wep:GetClass() ~= "swexp_scanner" then return end

    local sw, sh   = ScrW(), ScrH()
    local now      = CurTime()
    local cx, cy   = sw / 2, sh / 2

    local cdEnd    = wep:GetCooldownEnd()
    local onCD     = (cdEnd > now)
    local scanning = wep:GetScanning()
    local progress = wep:GetScanProgress()

    -- Цвет прицела
    local cr, cg, cb, ca
    local pulse = math.abs(math.sin(now * 4)) * 0.4 + 0.6
    if scanning then
        cr = math.Round(Lerp(progress, 80,  50))
        cg = math.Round(Lerp(progress, 160, 230))
        cb = math.Round(Lerp(progress, 255, 100))
        ca = 230
    elseif onCD then
        cr, cg, cb, ca = 200, 110, 60, 170
    else
        cr, cg, cb = 80, 190, 255
        ca = math.Round(200 * pulse)
    end

    -- Круг
    local SEGS   = 48
    local radius = S(22)
    surface.SetDrawColor(cr, cg, cb, ca)
    for i = 0, SEGS - 1 do
        local a1 = math.rad(i       / SEGS * 360)
        local a2 = math.rad((i + 1) / SEGS * 360)
        surface.DrawLine(
            cx + math.cos(a1) * radius, cy + math.sin(a1) * radius,
            cx + math.cos(a2) * radius, cy + math.sin(a2) * radius
        )
    end

    -- Точка
    local dotR = S(2)
    surface.SetDrawColor(cr, cg, cb, ca)
    surface.DrawRect(cx - dotR, cy - dotR, dotR * 2, dotR * 2)

    -- Прогресс-бар и текст при сканировании
    if scanning then
        local barW = S(260)
        local barH = S(10)
        local barX = (sw - barW) / 2
        local barY = sh * 0.64

        draw.RoundedBox(S(3), barX - 1, barY - 1, barW + 2, barH + 2, Color(0, 0, 0, 150))
        draw.RoundedBox(S(3), barX, barY, barW, barH, Color(10, 20, 30, 210))

        local fillW = math.Round(barW * progress)
        if fillW > 0 then
            draw.RoundedBox(S(3), barX, barY, fillW, barH, Color(cr, cg, cb, 230))
        end

        draw.SimpleText(
            "СКАНИРОВАНИЕ... " .. math.Round(progress * 100) .. "%",
            "SWUI.Small",
            sw / 2, barY - S(18),
            Color(cr, cg, cb, 255),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
        )

    elseif onCD then
        local remaining = math.ceil(cdEnd - now)
        draw.SimpleText(
            "Кулдаун: " .. remaining .. " с",
            "SWUI.Small",
            sw / 2, cy + radius + S(10),
            Color(220, 130, 70, 220),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
        )
    end
end)

-- ============================================================
-- Скрываем стандартный TargetID
-- ============================================================

hook.Add("HUDDrawTargetID", "SWExp::ScannerHideTarget", function()
    local lp  = LocalPlayer()
    local wep = IsValid(lp) and lp:GetActiveWeapon()
    if IsValid(wep) and wep:GetClass() == "swexp_scanner" then
        return true
    end
end)

print("[SWExp] swexp_scanner (клиент) загружен.")
