-- ============================================================
-- Star Wars: Expedition — Pickup Notification HUD
-- modules/inventory/cl_pickup_notify.lua
--
-- Уведомления о подборе предметов в стиле SWUI.
-- Сервер вызывает: netstream.Start(ply, "SWExp::ItemPickupNotify", { itemID, amount })
-- ============================================================

if not CLIENT then return end

-- ============================================================
-- НАСТРОЙКИ
-- ============================================================

local CFG = {
    MaxNotifications = 5,       -- Максимум одновременных уведомлений
    NotifyDuration   = 4.0,     -- Секунд висит уведомление
    FadeInTime       = 0.25,    -- Время появления
    FadeOutTime      = 0.5,     -- Время исчезновения
    SlideInTime      = 0.3,     -- Время слайда
    Width            = 260,     -- Ширина панели
    Height           = 52,      -- Высота одной панели
    Gap              = 6,       -- Отступ между панелями
    MarginLeft       = 30,      -- Отступ от левого края
    MarginTop        = 30,      -- Отступ от верха экрана (база)
    IconSize         = 32,      -- Размер иконки предмета
}

-- ============================================================
-- МАСШТАБ
-- ============================================================

local function S(n)
    return math.Round(n * (ScrH() / 1080))
end

-- ============================================================
-- ОЧЕРЕДЬ УВЕДОМЛЕНИЙ
-- ============================================================

local Notifications = {}  -- { alpha, slideX, startTime, itemData, amount, icon }

-- ============================================================
-- ПОЛУЧЕНИЕ ДАННЫХ ПРЕДМЕТА
-- ============================================================

local function GetItemData(itemID)
    if SWExp and SWExp.Inventory and SWExp.Inventory.GetItemData then
        return SWExp.Inventory:GetItemData(itemID)
    end
    return nil
end

-- ============================================================
-- ДОБАВЛЕНИЕ УВЕДОМЛЕНИЯ
-- ============================================================

local function AddPickupNotification(itemID, amount)
    local itemData = GetItemData(itemID)
    local name     = itemData and itemData.name        or itemID
    local icon     = itemData and itemData.icon        or nil
    local rarity   = itemData and itemData.rarity      or 'common'

    -- Цвет по редкости (дублируем логику из cl_inventory)
    local rarityColors = {
        common    = SWUI.Colors.TextDim,
        uncommon  = SWUI.Colors.Green,
        rare      = SWUI.Colors.Accent,
        epic      = Color(180, 80, 255),
        legendary = SWUI.Colors.Warn,
    }
    local rarityCol = rarityColors[rarity] or SWUI.Colors.TextDim

    -- Не превышаем максимум
    if #Notifications >= CFG.MaxNotifications then
        table.remove(Notifications, 1)
    end

    -- Материал иконки
    local mat = nil
    if icon then
        mat = Material(icon)
    end

    table.insert(Notifications, {
        alpha     = 0,
        slideX    = -S(CFG.Width + 20),  -- Начинаем за левым краем экрана
        startTime = CurTime(),
        name      = name,
        amount    = amount or 1,
        mat       = mat,
        rarityCol = rarityCol,
        rarity    = rarity,
    })

    -- Звук подбора
    if SWUI and SWUI.PlaySound and SWUI.Sounds then
        SWUI.PlaySound(SWUI.Sounds.Success)
    end
end

-- ============================================================
-- ПОЛУЧЕНИЕ СЕТЕВОГО СООБЩЕНИЯ
-- ============================================================

netstream.Hook("SWExp::ItemPickupNotify", function(data)
    if not data then return end
    AddPickupNotification(data.itemID, data.amount)
end)

-- ============================================================
-- ОТРИСОВКА HUD
-- ============================================================

hook.Add("HUDPaint", "SWExp::DrawPickupNotifications", function()
    if #Notifications == 0 then return end

    local sw = ScrW()
    local sh = ScrH()
    local now = CurTime()

    -- Левый верхний угол. Размещаемся ниже Pickup Feed и блока Notifications.
    local baseX = S(CFG.MarginLeft)
    local baseY = S(CFG.MarginTop)
        + (SWExp_PickupFeedHeight or 0)
        + (SWExp_NotificationsHeight or 0)

    local toRemove = {}

    for i, n in ipairs(Notifications) do
        local elapsed = now - n.startTime
        local alpha   = 1.0

        -- Fade in
        if elapsed < CFG.FadeInTime then
            alpha = elapsed / CFG.FadeInTime
        end

        -- Fade out (последние FadeOutTime секунд)
        local remaining = CFG.NotifyDuration - elapsed
        if remaining < CFG.FadeOutTime then
            alpha = remaining / CFG.FadeOutTime
        end

        -- Удаляем если время вышло
        if elapsed >= CFG.NotifyDuration then
            table.insert(toRemove, i)
        end

        -- Плавный слайд слева
        local targetSlide = 0
        local slideProgress = math.Clamp(elapsed / CFG.SlideInTime, 0, 1)
        -- easeOutQuart
        local t = 1 - slideProgress
        local eased = 1 - t * t * t * t
        n.slideX = Lerp(eased, n.slideX, targetSlide)

        alpha = math.Clamp(alpha, 0, 1)

        local x = baseX + n.slideX
        local y = baseY + (i - 1) * (S(CFG.Height) + S(CFG.Gap))
        local w = S(CFG.Width)
        local h = S(CFG.Height)

        surface.SetAlphaMultiplier(alpha)

        -- Фон панели
        local r = 8
        draw.RoundedBox(r + 1, x - 1, y - 1, w + 2, h + 2, Color(0, 184, 255, math.Round(200 * alpha)))
        draw.RoundedBox(r,     x,     y,     w,     h,     Color(6, 12, 18, math.Round(230 * alpha)))

        -- Левая акцентная полоска (цвет редкости)
        local rc = n.rarityCol
        draw.RoundedBox(3, x + 2, y + S(6), S(3), h - S(12),
            Color(rc.r, rc.g, rc.b, math.Round(255 * alpha)))

        local iconSize = S(CFG.IconSize)
        local iconX    = x + S(14)
        local iconY    = y + (h - iconSize) / 2

        -- Иконка предмета
        if n.mat then
            surface.SetDrawColor(255, 255, 255, math.Round(220 * alpha))
            surface.SetMaterial(n.mat)
            surface.DrawTexturedRect(iconX, iconY, iconSize, iconSize)
        else
            -- Заглушка-квадрат если иконки нет
            surface.SetDrawColor(rc.r, rc.g, rc.b, math.Round(40 * alpha))
            surface.DrawRect(iconX, iconY, iconSize, iconSize)
            surface.SetDrawColor(rc.r, rc.g, rc.b, math.Round(80 * alpha))
            surface.DrawOutlinedRect(iconX, iconY, iconSize, iconSize, 1)
        end

        local textX = iconX + iconSize + S(10)
        local midY  = y + h / 2

        -- Название предмета
        draw.SimpleText(
            string.upper(n.name),
            'SWUI.Small',
            textX,
            midY - S(8),
            Color(SWUI.Colors.TextHi.r, SWUI.Colors.TextHi.g, SWUI.Colors.TextHi.b, math.Round(255 * alpha)),
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )

        -- Количество / надпись "ПОЛУЧЕНО"
        local subText = n.amount > 1
            and ('×' .. n.amount)
            or  'ПОЛУЧЕНО'
        local subCol = n.amount > 1
            and Color(rc.r, rc.g, rc.b, math.Round(200 * alpha))
            or  Color(SWUI.Colors.TextDim.r, SWUI.Colors.TextDim.g, SWUI.Colors.TextDim.b, math.Round(200 * alpha))

        draw.SimpleText(
            subText,
            'SWUI.Tiny',
            textX,
            midY + S(6),
            subCol,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )

        surface.SetAlphaMultiplier(1)
    end

    -- Удаляем устаревшие (в обратном порядке)
    for i = #toRemove, 1, -1 do
        table.remove(Notifications, toRemove[i])
    end
end)

-- ============================================================
-- ОТЛАДОЧНАЯ КОМАНДА (тест без сервера)
-- ============================================================

concommand.Add("swexp_test_pickup", function(_, _, args)
    local itemID = args[1] or "medpack"
    local amount = tonumber(args[2]) or 1
    AddPickupNotification(itemID, amount)
end)

print('[SWExp] Pickup Notify UI загружен.')
