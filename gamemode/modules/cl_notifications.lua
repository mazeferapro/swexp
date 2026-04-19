-- ============================================================
-- Star Wars: Expedition — Notifications HUD
-- modules/cl_notifications.lua
--
-- Заменяет стандартные GMod уведомления (notification.AddLegacy)
-- на кастомные в стиле SWUI.
-- Перехватывает: GM:AddNotify, notification.AddLegacy
-- Типы: NOTIFY_GENERIC, NOTIFY_ERROR, NOTIFY_UNDO,
--        NOTIFY_HINT, NOTIFY_CLEANUP
-- ============================================================

if not CLIENT then return end

-- ============================================================
-- Масштаб
-- ============================================================

local function S(n)
    return math.Round(n * (ScrH() / 1080))
end

-- ============================================================
-- Конфиг
-- ============================================================

local CFG = {
    MaxItems     = 8,
    FadeIn       = 0.2,
    FadeOut      = 0.4,
    SlideTime    = 0.25,
    PanelW       = 380,   -- ширина панели
    PanelMinH    = 44,    -- минимальная высота (1 строка)
    LineH        = 18,    -- высота одной строки текста
    PadV         = 14,    -- вертикальный отступ текста от края
    Gap          = 5,
    MarginRight  = 30,
    MarginBottom = 30,
}

-- ============================================================
-- Цвета по типу уведомления
-- ============================================================

local TypeColors = {
    [NOTIFY_GENERIC] = Color(0, 184, 255),    -- синий (акцент)
    [NOTIFY_ERROR]   = Color(220, 50,  30),   -- красный
    [NOTIFY_UNDO]    = Color(255, 180, 0),    -- жёлтый
    [NOTIFY_HINT]    = Color(0,  200, 120),   -- зелёный
    [NOTIFY_CLEANUP] = Color(160, 100, 255),  -- фиолетовый
}

local TypeIcons = {
    [NOTIFY_GENERIC] = '!',
    [NOTIFY_ERROR]   = '✕',
    [NOTIFY_UNDO]    = '↩',
    [NOTIFY_HINT]    = '?',
    [NOTIFY_CLEANUP] = '✓',
}

-- ============================================================
-- Очередь
-- ============================================================

local Notes = {}

-- ============================================================
-- Добавление уведомления
-- ============================================================

-- Разбивает текст на строки с учётом максимальной ширины
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

local function AddNote(str, ntype, duration)
    if not str or str == '' then return end

    str = string.Trim(str)

    -- Если такое уже есть — сбрасываем таймер
    for _, n in ipairs(Notes) do
        if n.text == str then
            n.startTime = CurTime()
            n.duration  = duration or 5
            return
        end
    end

    if #Notes >= CFG.MaxItems then
        table.remove(Notes, 1)
    end

    local col = TypeColors[ntype] or TypeColors[NOTIFY_GENERIC]
    local ico = TypeIcons[ntype]  or '!'

    -- Считаем строки (иконка + отступы занимают ~56px слева)
    local textMaxW = S(CFG.PanelW) - S(56)
    local lines    = WrapText(str, 'SWUI.Small', textMaxW)
    local ph       = math.max(S(CFG.PanelMinH), #lines * S(CFG.LineH) + S(CFG.PadV) * 2)

    table.insert(Notes, {
        text      = str,
        lines     = lines,
        ph        = ph,
        color     = col,
        icon      = ico,
        duration  = duration or 5,
        startTime = CurTime(),
        slideX    = S(CFG.PanelW + 40),
    })
end

-- ============================================================
-- Переопределяем GM:AddNotify — перехватываем все GMod уведомления
-- ============================================================

function GM:AddNotify(str, ntype, length)
    AddNote(str, ntype, length)
end

-- ============================================================
-- Перехватываем notification.AddLegacy напрямую
-- (на случай если что-то вызывает его минуя GM:AddNotify)
-- ============================================================

local _origAddLegacy = notification.AddLegacy
notification.AddLegacy = function(str, ntype, length)
    AddNote(str, ntype, length)
    -- НЕ вызываем оригинал — иначе стандартный UI всё равно нарисуется
end

-- ============================================================
-- Публичное API для геймода
-- ============================================================

function SWExp.Notify(str, ntype, duration)
    AddNote(str, ntype or NOTIFY_GENERIC, duration or 5)
end

-- ============================================================
-- Отрисовка
-- ============================================================

hook.Add('HUDPaint', 'SWExp::DrawNotifications', function()
    if #Notes == 0 then return end

    local sw  = ScrW()
    local sh  = ScrH()
    local now = CurTime()
    local pw  = S(CFG.PanelW)
    local gap = S(CFG.Gap)

    local baseX = sw - pw - S(CFG.MarginRight)
    local toRemove = {}

    -- Сначала считаем суммарную высоту снизу вверх
    local offsetY = S(CFG.MarginBottom)

    for i = 1, #Notes do
        local n       = Notes[i]
        local elapsed = now - n.startTime
        local remaining = n.duration - elapsed

        if elapsed >= n.duration then
            table.insert(toRemove, i)
            continue
        end

        local ph = n.ph

        -- Alpha
        local alpha = 1.0
        if elapsed < CFG.FadeIn then
            alpha = elapsed / CFG.FadeIn
        elseif remaining < CFG.FadeOut then
            alpha = remaining / CFG.FadeOut
        end
        alpha = math.Clamp(alpha, 0, 1)

        -- Слайд справа easeOutQuart
        local sp    = math.Clamp(elapsed / CFG.SlideTime, 0, 1)
        local t     = 1 - sp
        local eased = 1 - t * t * t * t
        n.slideX    = n.slideX + (0 - n.slideX) * eased * 0.35
        if math.abs(n.slideX) < 0.5 then n.slideX = 0 end

        local x   = baseX + n.slideX
        local y   = sh - offsetY - ph
        offsetY   = offsetY + ph + gap

        local col = n.color

        surface.SetAlphaMultiplier(alpha)

        -- Обводка
        draw.RoundedBox(S(7), x - 1, y - 1, pw + 2, ph + 2,
            Color(col.r, col.g, col.b, 50))
        -- Фон
        draw.RoundedBox(S(6), x, y, pw, ph, Color(6, 12, 18, 220))

        -- Левая цветная полоска
        draw.RoundedBox(S(3), x + S(2), y + S(6), S(3), ph - S(12),
            Color(col.r, col.g, col.b, 255))

        -- Иконка в кружке (центрирована по вертикали панели)
        local iconX = x + S(22)
        local iconY = y + ph / 2
        local iconR = S(12)
        draw.RoundedBox(iconR, iconX - iconR, iconY - iconR,
            iconR * 2, iconR * 2,
            Color(col.r, col.g, col.b, 40))
        draw.SimpleText(n.icon, 'SWUI.Small',
            iconX, iconY,
            Color(col.r, col.g, col.b, 255),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Текст: несколько строк
        local textX   = iconX + iconR + S(10)
        local lineH   = S(CFG.LineH)
        local totalTH = #n.lines * lineH
        local textY   = y + ph / 2 - totalTH / 2

        for li, line in ipairs(n.lines) do
            draw.SimpleText(line, 'SWUI.Small',
                textX, textY + (li - 1) * lineH,
                Color(220, 240, 255, 255),
                TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        surface.SetAlphaMultiplier(1)
    end

    -- Удаляем устаревшие (в обратном порядке)
    for i = #toRemove, 1, -1 do
        table.remove(Notes, toRemove[i])
    end
end)

-- ============================================================
-- Отладка
-- ============================================================

concommand.Add('swexp_test_notify', function(_, _, args)
    local types = { NOTIFY_GENERIC, NOTIFY_ERROR, NOTIFY_UNDO, NOTIFY_HINT, NOTIFY_CLEANUP }
    local labels = { 'GENERIC', 'ERROR', 'UNDO', 'HINT', 'CLEANUP' }
    for i, t in ipairs(types) do
        timer.Simple((i - 1) * 0.3, function()
            AddNote('Тест уведомления: ' .. labels[i], t, 5)
        end)
    end
end)

print('[SWExp] Notifications HUD загружен.')
