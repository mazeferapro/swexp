-- Star Wars: Expedition
-- modules/hud/cl_hud.lua

-- ============================================================
-- Scale — база 1080p
-- ============================================================

local function S(n)
    return math.Round(n * (ScrH() / 1080))
end

-- ============================================================
-- Шрифты — всё Exo 2, монospace тоже Exo 2 Bold
-- ============================================================

local function CreateFonts()
    surface.CreateFont('SWUI.HUD.AmmoClip', {
        font = 'Exo 2', size = S(56), weight = 800, extended = true,
    })
    surface.CreateFont('SWUI.HUD.AmmoReserve', {
        font = 'Exo 2', size = S(26), weight = 500, extended = true,
    })
    surface.CreateFont('SWUI.HUD.WeaponName', {
        font = 'Exo 2', size = S(16), weight = 500, extended = true,
    })
    surface.CreateFont('SWUI.HUD.Callsign', {
        font = 'Exo 2', size = S(24), weight = 700, extended = true,
    })
    surface.CreateFont('SWUI.HUD.CloneNum', {
        font = 'Exo 2', size = S(15), weight = 500, extended = true,
    })
    surface.CreateFont('SWUI.HUD.Compass', {
        font = 'Exo 2', size = S(20), weight = 700, extended = true,
    })
    surface.CreateFont('SWUI.HUD.CompassDim', {
        font = 'Exo 2', size = S(15), weight = 600, extended = true,
    })
    surface.CreateFont('SWUI.HUD.Degrees', {
        font = 'Exo 2', size = S(17), weight = 700, extended = true,
    })
    surface.CreateFont('SWUI.HUD.HPLabel', {
        font = 'Exo 2', size = S(17), weight = 600, extended = true,
    })
    surface.CreateFont('SWUI.HUD.HPVal', {
        font = 'Exo 2', size = S(18), weight = 600, extended = true,
    })
    surface.CreateFont('SWUI.HUD.Armor', {
        font = 'Exo 2', size = S(18), weight = 600, extended = true,
    })
    surface.CreateFont('SWUI.HUD.ScanText', {
        font = 'Exo 2', size = S(17), weight = 400, extended = true,
    })
    surface.CreateFont('SWUI.HUD.ScanAction', {
        font = 'Exo 2', size = S(15), weight = 700, extended = true,
    })
    surface.CreateFont('SWUI.HUD.ScanKey', {
        font = 'Exo 2', size = S(14), weight = 700, extended = true,
    })
end

CreateFonts()

hook.Add('OnScreenSizeChanged', 'SWExp::RecreateFonts', function()
    CreateFonts()
end)

-- ============================================================
-- Цвета
-- ============================================================

local C = {
    PanelBG   = Color(6,  12, 18, 184),
    Border    = Color(0, 184, 255, 41),
    Accent    = Color(0, 184, 255),
    AccentDim = Color(0,  79, 110),
    Warn      = Color(255, 136, 0),
    Green     = Color(0, 238, 119),
    TextHi    = Color(234, 246, 255),
    Text      = Color(200, 232, 248),
    TextDim   = Color(74, 122, 144),
    HPTrack   = Color(255, 255, 255, 15),
}

-- ============================================================
-- Состояние
-- ============================================================

local HUD = {
    ScanVisible = false,
    ScanText    = '',
    ScanPulse   = 0,
    HPSmooth    = 100,
}

-- ============================================================
-- Утилиты
-- ============================================================

local function Panel(x, y, w, h, r)
    draw.RoundedBox(r + 1, x - 1, y - 1, w + 2, h + 2, Color(0, 184, 255, 255))
    draw.RoundedBox(r,     x,     y,     w,     h,     Color(6, 12, 18, 255))
end

local function Txt(text, font, x, y, col, aH, aV)
    draw.SimpleText(text, font, x, y, col,
        aH or TEXT_ALIGN_LEFT, aV or TEXT_ALIGN_TOP)
end

local function WrapText(text, font, maxW)
    surface.SetFont(font)
    local lines, line = {}, ''
    for _, word in ipairs(string.Explode(' ', text)) do
        local test = line == '' and word or (line .. ' ' .. word)
        if surface.GetTextSize(test) > maxW and line ~= '' then
            table.insert(lines, line)
            line = word
        else
            line = test
        end
    end
    if line ~= '' then table.insert(lines, line) end
    return lines
end

-- ============================================================
-- КОМПАС
-- ============================================================

local DIRS    = {'С','СВ','В','ЮВ','Ю','ЮЗ','З','СЗ'}
-- Угол каждого направления в градусах (0=С, 45=СВ, ...)
local DANGLES = {0, 45, 90, 135, 180, 225, 270, 315}

local function DrawCompass()
    local sw = ScrW()
    local cx = sw / 2
    local W  = S(340)
    local H  = S(40)
    local x  = cx - W / 2
    local y  = S(22)

    Panel(x, y, W, H, S(20))

    -- Центральная линия поверх
    surface.SetDrawColor(C.Accent)
    surface.DrawRect(cx - 1, y + S(6), 1, H - S(12))
    surface.SetDrawColor(0, 184, 255, 60)
    surface.DrawRect(cx - S(2), y + S(6), S(3), H - S(12))

    local ply = LocalPlayer()
    local yaw = ((-(IsValid(ply) and ply:GetAngles().y or 0) + 90) % 360)

    -- Сколько градусов влезает в ширину компаса
    local degsVisible = 180  -- 180° на всю ширину
    local pxPerDeg    = W / degsVisible

    -- Рисуем метки для всех 8 направлений
    -- Проверяем каждое направление, попадает ли оно в видимую зону
    for di, da in ipairs(DANGLES) do
        -- Угловое смещение от центра (yaw)
        local delta = ((da - yaw + 540) % 360) - 180
        -- Только если в пределах видимости + чуть за краями для плавности
        if math.abs(delta) <= degsVisible / 2 + 20 then
            local tx     = cx + delta * pxPerDeg
            local ty     = y + H / 2
            local isC    = math.abs(delta) < 3   -- почти по центру
            local dist   = math.abs(delta)
            -- Плавное затухание к краям
            local alpha  = math.Clamp(1 - (dist - degsVisible * 0.35) / (degsVisible * 0.15), 0, 1)

            local col
            if isC then
                col = C.TextHi
            else
                col = Color(
                    C.TextDim.r, C.TextDim.g, C.TextDim.b,
                    math.Round(255 * alpha)
                )
            end

            -- Рисуем текст только если видим
            if alpha > 0.05 then
                local font = isC and 'SWUI.HUD.Compass' or 'SWUI.HUD.CompassDim'
                -- Clamp чтобы не рисовать за краями панели
                if tx > x + S(20) and tx < x + W - S(20) then
                    Txt(DIRS[di], font, tx, ty, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end
        end
    end

    -- Мелкие тики каждые 22.5° (ровно между кардинальными)
    for i = 0, 15 do
        local deg = i * 22.5
        -- Пропускаем кардинальные (кратные 45°)
        local isCard = (i % 2 == 0)
        if not isCard then
            local delta = ((deg - yaw + 540) % 360) - 180
            if math.abs(delta) <= degsVisible / 2 then
                local tx    = cx + delta * pxPerDeg
                local alpha = math.Clamp(1 - (math.abs(delta) - degsVisible * 0.35) / (degsVisible * 0.15), 0.1, 0.5)
                surface.SetDrawColor(C.TextDim.r, C.TextDim.g, C.TextDim.b, math.Round(80 * alpha))
                surface.DrawRect(tx - 1, y + H / 2 - S(4), 1, S(8))
            end
        end
    end

    Txt(string.format('%d°', math.Round(yaw)), 'SWUI.HUD.Degrees',
        cx, y + H + S(5), C.Accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
end

-- ============================================================
-- ПЕРСОНАЖ (bottom left)
-- ============================================================

local function DrawCharacter()
    local char     = SWExp and SWExp.LocalCharacter
    local callsign = char and string.upper(char.callsign or '') or 'ПРИЗРАК'
    local cloneNum = char and char.clone_number or 'CT-0000'

    local pw = S(160)
    local ph = S(58)
    local x  = S(20)
    local y  = ScrH() - ph - S(24)

    Panel(x, y, pw, ph, S(10))

    Txt(callsign, 'SWUI.HUD.Callsign', x + S(14), y + S(10), C.TextHi)
    Txt(cloneNum, 'SWUI.HUD.CloneNum', x + S(14), y + S(34), C.TextDim)
end

-- ============================================================
-- HP + БРОНЯ (bottom center)
-- ============================================================

local function DrawHP()
    local ply   = LocalPlayer()
    local hp    = IsValid(ply) and ply:Health()       or 100
    local maxHP = IsValid(ply) and ply:GetMaxHealth() or 100
    if maxHP <= 0 then maxHP = 100 end

    HUD.HPSmooth = Lerp(FrameTime() * 6, HUD.HPSmooth, hp)
    local frac   = math.Clamp(HUD.HPSmooth / maxHP, 0, 1)

    local barW = S(320)
    local barH = S(8)
    local cx   = ScrW() / 2
    local bx   = cx - barW / 2   -- бар центрирован по экрану
    local x    = bx - S(42)      -- лейбл слева от бара
    local y    = ScrH() - S(48)

    -- HP label (белый)
    Txt('HP', 'SWUI.HUD.HPLabel', x, y + barH / 2, C.TextHi,
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- Track
    draw.RoundedBox(S(4), bx, y, barW, barH, C.HPTrack)

    -- Fill
    local fc = frac > 0.5 and Color(0, 153, 64)
            or frac > 0.25 and Color(200, 120, 0)
            or Color(200, 40, 30)
    draw.RoundedBox(S(4), bx, y, math.max(S(8), barW * frac), barH, fc)

    -- HP value + броня в одной строке
    local armor   = IsValid(ply) and ply:Armor() or 0
    local valX    = bx + barW + S(12)
    local valMid  = y + barH / 2

    Txt(string.format('%d / %d', math.Round(hp), maxHP),
        'SWUI.HUD.HPVal', valX, valMid, C.TextHi,
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- Разделитель и броня со значком щита
    surface.SetFont('SWUI.HUD.HPVal')
    local hpTxtW = surface.GetTextSize(string.format('%d / %d', math.Round(hp), maxHP))
    local shieldX = valX + hpTxtW + S(14)
    local shieldY = valMid

    -- Знак брони: щит из линий (Garry's Mod surface tools)
    local sw = S(10)  -- ширина щита
    local sh = S(13)  -- высота щита
    local sx = shieldX
    local sy = shieldY - sh / 2

    surface.SetDrawColor(C.Accent)
    -- Верхняя левая дуга (имитация через линии)
    surface.DrawLine(sx,          sy,           sx + sw / 2,  sy)           -- top left half
    surface.DrawLine(sx + sw / 2, sy,           sx + sw,      sy)           -- top right half
    surface.DrawLine(sx,          sy,           sx,           sy + sh * 0.6) -- left side
    surface.DrawLine(sx + sw,     sy,           sx + sw,      sy + sh * 0.6) -- right side
    surface.DrawLine(sx,          sy + sh * 0.6, sx + sw / 2, sy + sh)      -- bottom left diagonal
    surface.DrawLine(sx + sw,     sy + sh * 0.6, sx + sw / 2, sy + sh)      -- bottom right diagonal

    -- Значение брони
    Txt(armor .. '%', 'SWUI.HUD.Armor', shieldX + sw + S(5), valMid, C.Accent,
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

-- ============================================================
-- ПАТРОНЫ (bottom right)
-- ============================================================

local function DrawAmmo()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return end

    local clip    = wep:Clip1()
    local maxClip = wep:GetMaxClip1()
    local reserve = ply:GetAmmoCount(wep:GetPrimaryAmmoType())
    local wepName = wep:GetPrintName() or ''

    if clip < 0 then return end

    local rx = ScrW() - S(24)
    local y  = ScrH() - S(90)

    -- Weapon name
    Txt(string.upper(wepName), 'SWUI.HUD.WeaponName',
        rx, y, C.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

    -- Clip крупно
    Txt(tostring(clip), 'SWUI.HUD.AmmoClip',
        rx, y + S(18), C.TextHi, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

    -- / reserve мелко
    surface.SetFont('SWUI.HUD.AmmoClip')
    local clipW = surface.GetTextSize(tostring(clip))
    local sepX  = rx - clipW - S(6)

    Txt('/', 'SWUI.HUD.AmmoReserve', sepX, y + S(32), C.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    surface.SetFont('SWUI.HUD.AmmoReserve')
    local sepW = surface.GetTextSize('/')
    Txt(tostring(reserve), 'SWUI.HUD.AmmoReserve',
        sepX - sepW - S(4), y + S(32), C.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

    -- Pip bar
    if maxClip > 0 and maxClip <= 40 then
        local pW  = S(7)
        local pH  = S(4)
        local pG  = S(2)
        local tW  = maxClip * (pW + pG) - pG
        local pipY = y + S(80)
        for i = 1, maxClip do
            local px  = rx - tW + (i - 1) * (pW + pG)
            surface.SetDrawColor(i <= clip
                and Color(0, 184, 255, 128)
                or  Color(255, 255, 255, 20))
            surface.DrawRect(px, pipY, pW, pH)
        end
    end
end

-- ============================================================
-- SCAN HINT (center)
-- ============================================================

local function DrawScanHint()
    if not HUD.ScanVisible then return end

    HUD.ScanPulse = (HUD.ScanPulse + FrameTime() / 2.2) % 1
    local bAlpha  = math.Round(64 + math.abs(math.sin(HUD.ScanPulse * math.pi)) * 89)

    local pw    = S(340)
    local cx    = ScrW() / 2
    local cy    = ScrH() / 2 - S(80)
    local lineH = S(22)

    local lines = WrapText(HUD.ScanText, 'SWUI.HUD.ScanText', pw - S(40))
    local ph    = math.max(S(90), #lines * lineH + S(50))
    local x     = cx - pw / 2
    local y     = cy - ph / 2

    draw.RoundedBox(S(11), x - 1, y - 1, pw + 2, ph + 2, Color(0, 184, 255, bAlpha))
    draw.RoundedBox(S(10), x, y, pw, ph, C.PanelBG)

    for i, line in ipairs(lines) do
        Txt(line, 'SWUI.HUD.ScanText', cx,
            y + S(12) + (i - 1) * lineH, C.Text,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    local aY   = y + ph - S(28)
    local kW   = S(24)
    local kH   = S(18)
    local kX   = cx - S(50)

    draw.RoundedBox(S(5), kX - 1, aY - 1, kW + 2, kH + 2, C.AccentDim)
    draw.RoundedBox(S(4), kX, aY, kW, kH, Color(0, 184, 255, 30))
    Txt('E', 'SWUI.HUD.ScanKey', kX + kW / 2, aY + kH / 2,
        C.Accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    Txt('СКАНИРОВАТЬ ОБЪЕКТ', 'SWUI.HUD.ScanAction',
        kX + kW + S(8), aY + kH / 2, C.Accent,
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

-- ============================================================
-- Скрываем ванильный HUD
-- ============================================================

hook.Add('HUDShouldDraw', 'SWExp::HideDefaultHUD', function(name)
    local hide = {
        'CHudHealth','CHudBattery','CHudAmmo','CHudSecondaryAmmo',
        'CHudCrosshair','CHudDamageIndicator','CHudDeathNotice',
        'CHudGeiger','CHudTrain','CHudZoom',
    }
    for _, v in ipairs(hide) do
        if name == v then return false end
    end
end)

-- ============================================================
-- HUDPaint
-- ============================================================

hook.Add('HUDPaint', 'SWExp::DrawHUD', function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    if ply:GetObserverMode() ~= OBS_MODE_NONE then return end

    DrawCompass()
    DrawCharacter()
    DrawHP()
    DrawAmmo()
    DrawScanHint()
end)

-- ============================================================
-- API
-- ============================================================

function SWExp.HUD_ShowScanHint(text)
    HUD.ScanVisible = true
    HUD.ScanText    = text or ''
    HUD.ScanPulse   = 0
end

function SWExp.HUD_HideScanHint()
    HUD.ScanVisible = false
end

net.Receive('SWExp::SyncArmor', function()
    local armorClass = net.ReadString()
    local armorTier  = net.ReadInt(8)
    local ply = LocalPlayer()
    if IsValid(ply) then
        ply.SWExp_ArmorClass = armorClass ~= '' and armorClass or nil
        ply.SWExp_ArmorTier  = armorTier > 0 and armorTier or nil
    end
end)