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
        font = 'Exo 2', size = S(64), weight = 800, extended = true,
    })
    surface.CreateFont('SWUI.HUD.AmmoReserve', {
        font = 'Exo 2', size = S(32), weight = 500, extended = true,
    })
    surface.CreateFont('SWUI.HUD.WeaponName', {
        font = 'Exo 2', size = S(20), weight = 500, extended = true,
    })
    surface.CreateFont('SWUI.HUD.Callsign', {
        font = 'Exo 2', size = S(28), weight = 700, extended = true,
    })
    surface.CreateFont('SWUI.HUD.CloneNum', {
        font = 'Exo 2', size = S(19), weight = 500, extended = true,
    })
    surface.CreateFont('SWUI.HUD.Compass', {
        font = 'Exo 2', size = S(24), weight = 700, extended = true,
    })
    surface.CreateFont('SWUI.HUD.CompassDim', {
        font = 'Exo 2', size = S(19), weight = 600, extended = true,
    })
    surface.CreateFont('SWUI.HUD.Degrees', {
        font = 'Exo 2', size = S(21), weight = 700, extended = true,
    })
    surface.CreateFont('SWUI.HUD.HPLabel', {
        font = 'Exo 2', size = S(21), weight = 600, extended = true,
    })
    surface.CreateFont('SWUI.HUD.HPVal', {
        font = 'Exo 2', size = S(22), weight = 600, extended = true,
    })
    surface.CreateFont('SWUI.HUD.Armor', {
        font = 'Exo 2', size = S(22), weight = 600, extended = true,
    })
    surface.CreateFont('SWUI.HUD.ScanText', {
        font = 'Exo 2', size = S(21), weight = 400, extended = true,
    })
    surface.CreateFont('SWUI.HUD.ScanAction', {
        font = 'Exo 2', size = S(19), weight = 700, extended = true,
    })
    surface.CreateFont('SWUI.HUD.ScanKey', {
        font = 'Exo 2', size = S(18), weight = 700, extended = true,
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
    ScanVisible  = false,
    ScanText     = '',
    ScanPulse    = 0,
    HPSmooth     = 100,
    MedkitAlpha  = 0,   -- плавное появление иконки аптечки
}

-- ============================================================
-- Утилиты
-- ============================================================

local function Panel(x, y, w, h, r)
    draw.RoundedBox(r + 1, x - 1, y - 1, w + 2, h + 2, Color(0, 184, 255, 255))
    draw.RoundedBox(r,     x,     y,     w,     h,     Color(6, 12, 18, 255))
end

local function Txt(text, font, x, y, col, aH, aV)
    SWUI.DrawTextShadow(text, font, x, y, col,
        aH or TEXT_ALIGN_LEFT, aV or TEXT_ALIGN_TOP, 2, 180)
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

    if SWExp and SWExp.IsCompassEnabled and not SWExp.IsCompassEnabled() then
        return
    end
    
    local player = LocalPlayer()
    if not player:Alive() then return end
    
    local sw = ScrW()
    local cx = sw / 2
    local W  = S(360)
    local H  = S(50)
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
    local ply = LocalPlayer()

    local callsign = IsValid(ply) and ply:GetNWString('swexp_callsign', '') or ''
    local cloneNum = IsValid(ply) and ply:GetNWString('swexp_clone_number', '') or ''
    local rankID   = IsValid(ply) and ply:GetNWString('swexp_rank', '') or ''

    if callsign == '' then callsign = 'ПРИЗРАК' end
    if cloneNum == '' then cloneNum = 'CT-0000' end
    if rankID   == '' then rankID   = 'TRP'     end

    callsign = string.upper(callsign)
    cloneNum = string.upper(cloneNum)

    local rankName  = SWExp.Ranks and SWExp.Ranks:GetShortName(rankID) or rankID
    local rankColor = SWExp.Ranks and SWExp.Ranks:GetColor(rankID)     or C.Accent

    local x = S(20)
    local y = ScrH() - S(20)

    -- Строка 2 (снизу): звание · номер — маленький, приглушённый
    local subLine = rankName .. '  ·  ' .. cloneNum
    surface.SetFont('SWUI.HUD.CloneNum')
    local _, hSub = surface.GetTextSize('A')

    -- Строка 1: позывной
    surface.SetFont('SWUI.HUD.Callsign')
    local _, hCall = surface.GetTextSize('A')

    local gap = S(4)

    -- Рисуем снизу вверх
    local y2 = y - hSub
    local y1 = y2 - gap - hCall

    -- Тонкая вертикальная акцентная черта слева
    draw.RoundedBox(0, x, y1, S(2), hCall + gap + hSub, C.Accent)

    local tx = x + S(8)

    -- Позывной (с тенью для читаемости на любом фоне)
    SWUI.DrawTextShadow(callsign, 'SWUI.HUD.Callsign', tx, y1, C.TextHi, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 2, 180)

    -- Звание (цветом звания) + разделитель + номер (приглушённый)
    surface.SetFont('SWUI.HUD.CloneNum')
    local wRank = surface.GetTextSize(rankName)
    local wSep  = surface.GetTextSize('  ·  ')

    SWUI.DrawTextShadow(rankName,  'SWUI.HUD.CloneNum', tx,               y2, rankColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 2, 180)
    SWUI.DrawTextShadow('  ·  ',   'SWUI.HUD.CloneNum', tx + wRank,       y2, C.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 2, 180)
    SWUI.DrawTextShadow(cloneNum,  'SWUI.HUD.CloneNum', tx + wRank + wSep, y2, C.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 2, 180)
end
 

-- ============================================================
-- ============================================================
-- АПТЕЧКИ (рядом с HP, слева от бара)
-- ============================================================

local function DrawMedkits()
    -- Читаем данные инвентаря только если система загружена
    if not SWExp.Inventory or not SWExp.Inventory.LocalData then return end

    local eq = SWExp.Inventory.LocalData.equipment
    if not eq then return end

    local medSlots = eq["medical"]

    -- Считаем общее количество аптечек во всех медицинских слотах
    local totalMedkits = 0
    if medSlots then
        for _, item in pairs(medSlots) do
            if item and item.itemID then
                local d = SWExp.Inventory:GetItemData(item.itemID)
                if d and d.healType == "hot" then
                    totalMedkits = totalMedkits + (item.amount or 1)
                end
            end
        end
    end

    -- Плавное появление / исчезновение
    local targetAlpha = totalMedkits > 0 and 255 or 80
    HUD.MedkitAlpha = Lerp(FrameTime() * 5, HUD.MedkitAlpha, targetAlpha)

    local a = math.floor(HUD.MedkitAlpha)
    if a < 4 then return end

    -- Позиционируем левее HP бара (зеркально к патронам справа)
    local barW = S(320)
    local barH = S(8)
    local cx   = ScrW() / 2
    local bx   = cx - barW / 2
    local y    = ScrH() - S(56)
    local mid  = y + barH / 2   -- вертикальный центр строки

    -- Блок расположен слева от лейбла HP
    local blockX = bx - S(52) - S(86)

    -- ── Медицинский крест (surface tools, как щит брони) ──
    -- Размер кратен 3 чтобы arm = size/3 делился без остатка → ноль субпиксельных артефактов
    local size = math.floor(S(18) / 3) * 3          -- ближайшее кратное 3 (при 1080p = 18)
    local arm  = math.floor(size / 3)               -- толщина луча  (при 1080p = 6)
    local off  = math.floor((size - arm) / 2)       -- отступ от края до луча (при 1080p = 6)
    local cx2  = blockX                             -- левый край квадрата (целый)
    local cy2  = math.floor(mid - size / 2)         -- верхний край квадрата (целый)

    local col = totalMedkits > 0
        and Color(0, 238, 119, a)
        or  Color(74, 122, 144, a)

    -- Вертикальный луч: (off, 0) → ширина arm, высота size
    draw.RoundedBox(1, cx2 + off, cy2,       arm,  size, col)
    -- Горизонтальный луч: (0, off) → ширина size, высота arm
    draw.RoundedBox(1, cx2,       cy2 + off, size, arm,  col)

    -- Количество: сразу правее знака
    Txt("x" .. tostring(totalMedkits), "SWUI.HUD.HPVal",
        blockX + size + S(5), mid,
        col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- Если HoT активен — мигающий пульс-маркер слева от знака
    if SWExp.Inventory.MedkitHoT and SWExp.Inventory.MedkitHoT.active then
        local pulse = 0.5 + math.abs(math.sin(CurTime() * 3)) * 0.5
        local pa    = math.floor(pulse * 220)
        local dot   = S(6)
        draw.RoundedBox(dot / 2, blockX - S(12), math.floor(mid - dot / 2), dot, dot,
            Color(0, 238, 119, pa))
    end
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
    local x    = bx - S(52)      -- лейбл слева от бара
    local y    = ScrH() - S(56)

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
    local y  = ScrH() - S(112)

    -- Weapon name
    Txt(string.upper(wepName), 'SWUI.HUD.WeaponName',
        rx, y, C.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

    -- Clip крупно
    Txt(tostring(clip), 'SWUI.HUD.AmmoClip',
        rx, y + S(22), C.TextHi, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

    -- / reserve мелко
    surface.SetFont('SWUI.HUD.AmmoClip')
    local clipW = surface.GetTextSize(tostring(clip))
    local sepX  = rx - clipW - S(6)

    Txt('/', 'SWUI.HUD.AmmoReserve', sepX, y + S(40), C.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    surface.SetFont('SWUI.HUD.AmmoReserve')
    local sepW = surface.GetTextSize('/')
    Txt(tostring(reserve), 'SWUI.HUD.AmmoReserve',
        sepX - sepW - S(4), y + S(40), C.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

    -- Pip bar
    if maxClip > 0 and maxClip <= 40 then
        local pW  = S(7)
        local pH  = S(4)
        local pG  = S(2)
        local tW  = maxClip * (pW + pG) - pG
        local pipY = y + S(98)
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

    local pw    = S(380)
    local cx    = ScrW() / 2
    local cy    = ScrH() / 2 - S(80)
    local lineH = S(28)

    local lines = WrapText(HUD.ScanText, 'SWUI.HUD.ScanText', pw - S(40))
    local ph    = math.max(S(110), #lines * lineH + S(60))
    local x     = cx - pw / 2
    local y     = cy - ph / 2

    draw.RoundedBox(S(11), x - 1, y - 1, pw + 2, ph + 2, Color(0, 184, 255, bAlpha))
    draw.RoundedBox(S(10), x, y, pw, ph, C.PanelBG)

    for i, line in ipairs(lines) do
        Txt(line, 'SWUI.HUD.ScanText', cx,
            y + S(12) + (i - 1) * lineH, C.Text,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    local aY   = y + ph - S(34)
    local kW   = S(28)
    local kH   = S(22)
    local kX   = cx - S(60)

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

local HIDE_HUD = {
    ['CHudHealth']          = true,
    ['CHudBattery']         = true,
    ['CHudAmmo']            = true,
    ['CHudSecondaryAmmo']   = true,
    ['CHudCrosshair']       = true,
    ['CHudDamageIndicator'] = true,
    ['CHudDeathNotice']     = true,
    ['CHudGeiger']          = true,
    ['CHudTrain']           = true,
    ['CHudZoom']            = true,
    ['CHudHistoryResource'] = true,
}

hook.Add('HUDShouldDraw', 'SWExp::HideDefaultHUD', function(name)
    if HIDE_HUD[name] then return false end
end)

-- Переопределяем метод геймода — гарантированно перекрывает аддоны
function GM:HUDShouldDraw(name)
    if HIDE_HUD[name] then return false end
    return self.BaseClass.HUDShouldDraw(self, name)
end

-- Полностью перехватываем отрисовку CHudDeathNotice — рисуем пустую функцию вместо неё
hook.Add('PostRenderVGUI', 'SWExp::KillDeathNotice', function()
    local worldPanel = vgui.GetWorldPanel()
    if not IsValid(worldPanel) then return end
    for _, pnl in ipairs(worldPanel:GetChildren()) do
        if IsValid(pnl) and pnl:GetName() == "CHudDeathNotice" then
            pnl:SetVisible(false)
            pnl:SetSize(0, 0)
            pnl:SetPos(-9999, -9999)
        end
    end
end)

-- ГЛАВНЫЙ ФИХ: Killfeed рисуется через hook DrawDeathNotice в GM:HUDPaint базового геймода.
-- HUDShouldDraw его не перехватывает. Блокируем хук напрямую.
hook.Add('DrawDeathNotice', 'SWExp::BlockDrawDeathNotice', function()
    return true -- возвращаем true = отменяем выполнение хука
end)

-- ============================================================
-- ИНФОРМАЦИЯ НАД ИГРОКАМИ (Overhead HUD)
-- ============================================================

local function DrawOverheadNames()
    local localPly = LocalPlayer()
    local shootPos = localPly:GetShootPos()
    local maxDist = 500 -- Максимальная дистанция видимости в юнитах

    for _, ply in ipairs(player.GetAll()) do
        -- Игнорируем себя, мертвых игроков и тех, кто скрыт
        if ply == localPly or not ply:Alive() or ply:GetNoDraw() then continue end

        local targetPos = ply:GetPos()
        local dist = shootPos:Distance(targetPos)
        if dist > maxDist then continue end

        -- Проверка на видимость сквозь стены
        local tr = util.TraceLine({
            start = shootPos,
            endpos = targetPos + Vector(0, 0, 50),
            filter = {localPly, ply}
        })
        if tr.Fraction < 1 then continue end

        -- Вычисляем плавную прозрачность
        local alphaFrac = 1 - (dist / maxDist)
        alphaFrac = math.Clamp(alphaFrac * 1.5, 0, 1)

        -- Позиция над головой
        local headPos = targetPos + Vector(0, 0, 80)
        if ply:Crouching() then
            headPos.z = headPos.z - 20
        end

        local screen = headPos:ToScreen()
        if not screen.visible then continue end

        -- Получаем данные
        local callsign = string.upper(ply:GetNWString('swexp_callsign', 'ПРИЗРАК'))
        local cloneNum = string.upper(ply:GetNWString('swexp_clone_number', 'CT-0000'))
        local rankID   = ply:GetNWString('swexp_rank', 'TRP')

        local rankName = SWExp.Ranks and SWExp.Ranks:GetShortName(rankID) or rankID
        local rankColor = SWExp.Ranks and SWExp.Ranks:GetColor(rankID) or SWUI.Colors.Accent

        -- Цвета с учетом прозрачности от дистанции
        local rCol = ColorAlpha(rankColor, 255 * alphaFrac)
        local wCol = ColorAlpha(SWUI.Colors.TextHi, 255 * alphaFrac)
        local sAlpha = 150 * alphaFrac

        -- Подготавливаем части текста
        local textRank = "[" .. rankName .. "]"
        local textName = " " .. cloneNum .. " " .. callsign

        -- Считаем ширину обеих частей, чтобы выровнять всю строчку строго по центру
        surface.SetFont('SWUI.HUD.Callsign')
        local wRank = surface.GetTextSize(textRank)
        local wName = surface.GetTextSize(textName)
        local totalW = wRank + wName

        -- Начальная точка по X (сдвигаем влево на половину от общей ширины)
        local startX = screen.x - (totalW / 2)
        local y = screen.y

        -- Отрисовываем стык-в-стык (Слева направо)
        -- 1. Цветное звание в скобках
        SWUI.DrawTextShadow(textRank, 'SWUI.HUD.Callsign', startX, y, rCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM, 1, sAlpha)

        -- 2. Белый номер и позывной (сдвинутые на ширину звания)
        SWUI.DrawTextShadow(textName, 'SWUI.HUD.Callsign', startX + wRank, y, wCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM, 1, sAlpha)
    end
end

-- ============================================================
-- Star Wars: Expedition — Weapon Selector
-- modules/cl_wepselect.lua
-- ============================================================

if not CLIENT then return end

local function S(n)
    return math.Round(n * (ScrH() / 1080))
end

-- Состояние селектора
local WEPSELECT = {
    IsActive = false,
    Alpha = 0,
    CloseTime = 0,
    Index = 1,
    Weapons = {}
}

-- Настройки
local DISPLAY_TIME = 2.5 -- Сколько секунд висит меню после скролла
local FADE_SPEED = 8     -- Скорость появления/затухания
local MAX_VISIBLE = 7    -- Максимальное количество оружия на экране

-- ============================================================
-- СКРЫТИЕ СТАНДАРТНОГО ХУДА
-- ============================================================
hook.Add('HUDShouldDraw', 'SWExp::HideDefaultWepSelect', function(name)
    if name == 'CHudWeaponSelection' then return false end
end)

-- ============================================================
-- ОБНОВЛЕНИЕ СПИСКА ОРУЖИЯ
-- ============================================================
local function UpdateWeaponList()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local weps = ply:GetWeapons()
    
    -- Сортируем оружие по слотам
    table.sort(weps, function(a, b)
        local slotA = a:GetSlot() or 0
        local slotB = b:GetSlot() or 0
        if slotA == slotB then
            return (a:GetSlotPos() or 0) < (b:GetSlotPos() or 0)
        end
        return slotA < slotB
    end)

    WEPSELECT.Weapons = weps

    if WEPSELECT.Index > #WEPSELECT.Weapons then
        WEPSELECT.Index = 1
    end
    
    if not WEPSELECT.IsActive then
        local activeWep = ply:GetActiveWeapon()
        if IsValid(activeWep) then
            for i, wep in ipairs(WEPSELECT.Weapons) do
                if wep == activeWep then
                    WEPSELECT.Index = i
                    break
                end
            end
        end
    end
end

-- ============================================================
-- ПЕРЕХВАТ НАЖАТИЙ КЛАВИШ
-- ============================================================
hook.Add('PlayerBindPress', 'SWExp::WepSelectInput', function(ply, bind, pressed)
    if not pressed then return end
    if not ply:Alive() or ply:InVehicle() then return end

    if string.find(bind, 'invnext') then
        UpdateWeaponList()
        if #WEPSELECT.Weapons == 0 then return end

        WEPSELECT.IsActive = true
        WEPSELECT.CloseTime = CurTime() + DISPLAY_TIME
        WEPSELECT.Index = WEPSELECT.Index + 1

        if WEPSELECT.Index > #WEPSELECT.Weapons then WEPSELECT.Index = 1 end
        if SWUI and SWUI.PlaySound then SWUI.PlaySound(SWUI.Sounds.Hover, 0.4) end
        return true
    end

    if string.find(bind, 'invprev') then
        UpdateWeaponList()
        if #WEPSELECT.Weapons == 0 then return end

        WEPSELECT.IsActive = true
        WEPSELECT.CloseTime = CurTime() + DISPLAY_TIME
        WEPSELECT.Index = WEPSELECT.Index - 1

        if WEPSELECT.Index < 1 then WEPSELECT.Index = #WEPSELECT.Weapons end
        if SWUI and SWUI.PlaySound then SWUI.PlaySound(SWUI.Sounds.Hover, 0.4) end
        return true
    end

    if string.find(bind, '+attack') and WEPSELECT.IsActive and WEPSELECT.Alpha > 0.5 then
        local selectedWep = WEPSELECT.Weapons[WEPSELECT.Index]
        if IsValid(selectedWep) then
            input.SelectWeapon(selectedWep)
            if SWUI and SWUI.PlaySound then SWUI.PlaySound(SWUI.Sounds.Select, 0.6) end
        end
        
        WEPSELECT.IsActive = false
        WEPSELECT.CloseTime = 0
        return true
    end
end)

-- ============================================================
-- ОТРИСОВКА СЕЛЕКТОРА
-- ============================================================
hook.Add('HUDPaint', 'SWExp::DrawWepSelect', function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then
        WEPSELECT.IsActive = false
        WEPSELECT.Alpha = 0
        return
    end

    if WEPSELECT.IsActive and CurTime() > WEPSELECT.CloseTime then
        WEPSELECT.IsActive = false
    end

    local targetAlpha = WEPSELECT.IsActive and 1 or 0
    WEPSELECT.Alpha = Lerp(FrameTime() * FADE_SPEED, WEPSELECT.Alpha, targetAlpha)

    if WEPSELECT.Alpha <= 0.01 then return end

    local totalWeps = #WEPSELECT.Weapons
    if totalWeps == 0 then return end

    -- Высчитываем какие элементы показывать (Скользящее окно)
    local halfVis = math.floor(MAX_VISIBLE / 2)
    local startIdx = WEPSELECT.Index - halfVis
    local endIdx = WEPSELECT.Index + halfVis

    if startIdx < 1 then
        endIdx = endIdx + math.abs(startIdx) + 1
        startIdx = 1
    end
    if endIdx > totalWeps then
        startIdx = startIdx - (endIdx - totalWeps)
        endIdx = totalWeps
    end
    startIdx = math.max(1, startIdx)

    local visibleCount = (endIdx - startIdx) + 1
    local itemW = S(280)
    local itemH = S(48)
    local gap = S(6)
    local totalH = visibleCount * (itemH + gap) - gap

    local startX = ScrW() - itemW - S(30)
    local startY = (ScrH() / 2) - (totalH / 2)

    surface.SetAlphaMultiplier(WEPSELECT.Alpha)

    -- Индикатор скрытого оружия СВЕРХУ
    if startIdx > 1 then
        draw.SimpleText('▲', 'SWUI.Small', startX + itemW / 2, startY - S(15), SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Отрисовка списка
    local drawPos = 0
    for i = startIdx, endIdx do
        local wep = WEPSELECT.Weapons[i]
        if not IsValid(wep) then continue end

        local isSelected = (i == WEPSELECT.Index)
        local y = startY + drawPos * (itemH + gap)
        local xOffset = isSelected and -S(15) or 0
        local x = startX + xOffset
        
        local bgCol = isSelected and Color(0, 40, 65, 230) or Color(11, 15, 20, 200)
        local borderCol = isSelected and SWUI.Colors.Accent or SWUI.Colors.Border

        -- Правильная закругленная обводка (Хитрость: рисуем бокс-границу, а внутри него бокс-фон на 2px меньше)
        draw.RoundedBox(6, x, y, itemW, itemH, borderCol)
        draw.RoundedBox(5, x + 1, y + 1, itemW - 2, itemH - 2, bgCol)

        -- Левая полоска для активного
        if isSelected then
            draw.RoundedBox(2, x + 2, y + S(6), S(4), itemH - S(12), SWUI.Colors.Accent)
        end

        local wepName = string.upper(wep:GetPrintName() or wep:GetClass())
        local textCol = isSelected and SWUI.Colors.TextHi or SWUI.Colors.TextDim
        local font = isSelected and 'SWUI.Body' or 'SWUI.Small'

        SWUI.DrawText(wepName, font, x + S(16), y + itemH / 2, textCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local slotNum = (wep:GetSlot() or 0) + 1
        SWUI.DrawText('[' .. slotNum .. ']', 'SWUI.MonoSmall', x + itemW - S(16), y + itemH / 2, 
            isSelected and SWUI.Colors.AccentDim or Color(255, 255, 255, 15), 
            TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            
        drawPos = drawPos + 1
    end

    -- Индикатор скрытого оружия СНИЗУ
    if endIdx < totalWeps then
        draw.SimpleText('▼', 'SWUI.Small', startX + itemW / 2, startY + totalH + S(15), SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    surface.SetAlphaMultiplier(1)
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
    DrawMedkits()
    DrawAmmo()
    DrawScanHint()
    DrawOverheadNames() -- <--- ДОБАВЛЕНО СЮДА
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


hook.Add('HUDDrawTargetID', 'SWExp::HideDefaultTargetID', function()
    return false
end)