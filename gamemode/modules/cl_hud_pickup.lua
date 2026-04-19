-- ============================================================
-- Star Wars: Expedition — Pickup Feed HUD
-- modules/cl_hud_pickup.lua
--
-- Заменяет стандартный base-gamemode pickup HUD (HUDDrawPickupHistory)
-- на кастомный в стиле SWUI.
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
    MaxItems     = 6,     -- максимум уведомлений на экране
    Duration     = 4.0,   -- сколько секунд висит
    FadeIn       = 0.2,   -- время появления
    FadeOut      = 0.45,  -- время исчезновения
    SlideTime    = 0.3,   -- время слайда справа
    PanelW       = 220,   -- ширина панели
    PanelH       = 42,    -- высота панели
    Gap          = 5,     -- промежуток между панелями
    MarginRight  = 30,    -- отступ от правого края
    MarginBottom = 165,   -- отступ от низа экрана (над ammo HUD)
}

-- ============================================================
-- Очередь уведомлений
-- ============================================================

local Feed = {}

-- ============================================================
-- Добавление записи в фид
-- ============================================================

local function AddFeedItem(name, icon, count)
    -- Если такой предмет уже есть — увеличиваем счётчик и сбрасываем таймер
    for _, item in ipairs(Feed) do
        if item.name == name then
            item.count = (item.count or 1) + (count or 1)
            item.startTime = CurTime()
            return
        end
    end

    -- Обрезаем очередь
    if #Feed >= CFG.MaxItems then
        table.remove(Feed, 1)
    end

    table.insert(Feed, {
        name      = name,
        icon      = icon and Material(icon) or nil,
        count     = count or 1,
        startTime = CurTime(),
        slideX    = S(CFG.PanelW + 40),
    })

    -- Звук
    if SWUI and SWUI.PlaySound and SWUI.Sounds then
        SWUI.PlaySound(SWUI.Sounds.Success, 0.35)
    end
end

-- ============================================================
-- Переопределяем GM-методы из base gamemode:
-- HUDDrawPickupHistory — рисовка (делаем пустой)
-- HUDWeaponPickedUp / HUDItemPickedUp / HUDAmmoPickedUp — данные
-- ============================================================

function GM:HUDDrawPickupHistory()
    -- Намеренно пусто — рисовку берёт HUDPaint хук ниже
end

function GM:HUDWeaponPickedUp(wep)
    if not IsValid(wep) then return end
    local name = wep:GetPrintName() or wep:GetClass()
    AddFeedItem(string.upper(name), nil, 1)
end

function GM:HUDItemPickedUp(itemName)
    AddFeedItem(string.upper(itemName), nil, 1)
end

function GM:HUDAmmoPickedUp(itemName, amount)
    AddFeedItem(string.upper(itemName), nil, amount)
end

-- ============================================================
-- Отрисовка фида
-- ============================================================

hook.Add('HUDPaint', 'SWExp::DrawPickupFeed', function()
    if #Feed == 0 then return end

    local sw  = ScrW()
    local sh  = ScrH()
    local now = CurTime()
    local pw  = S(CFG.PanelW)
    local ph  = S(CFG.PanelH)
    local gap = S(CFG.Gap)

    local totalH = #Feed * (ph + gap) - gap
    local baseX  = sw - pw - S(CFG.MarginRight)
    local baseY  = sh - S(CFG.MarginBottom) - totalH

    local toRemove = {}

    for i, item in ipairs(Feed) do
        local elapsed   = now - item.startTime
        local remaining = CFG.Duration - elapsed

        if elapsed >= CFG.Duration then
            table.insert(toRemove, i)
            continue
        end

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
        item.slideX = item.slideX + (0 - item.slideX) * eased * 0.3
        if math.abs(item.slideX) < 0.5 then item.slideX = 0 end

        local x = baseX + item.slideX
        local y = baseY + (i - 1) * (ph + gap)

        surface.SetAlphaMultiplier(alpha)

        -- Фон с обводкой в стиле SWUI
        draw.RoundedBox(S(7), x - 1, y - 1, pw + 2, ph + 2, Color(0, 184, 255, 45))
        draw.RoundedBox(S(6), x,     y,     pw,     ph,     Color(6, 12, 18, 220))

        -- Левая акцентная полоска
        draw.RoundedBox(S(3), x + S(2), y + S(6), S(3), ph - S(12), SWUI.Colors.Accent)

        local textX = x + S(14)
        local midY  = y + ph / 2

        -- Иконка (если есть)
        if item.icon then
            surface.SetDrawColor(255, 255, 255, 200)
            surface.SetMaterial(item.icon)
            surface.DrawTexturedRect(textX, midY - S(13), S(26), S(26))
            textX = textX + S(32)
        end

        -- Название предмета
        SWUI.DrawText(
            item.name,
            'SWUI.Small',
            textX,
            midY - (item.count > 1 and S(7) or 0),
            SWUI.Colors.TextHi,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )

        -- Количество (если > 1)
        if item.count > 1 then
            SWUI.DrawText(
                '×' .. item.count,
                'SWUI.Tiny',
                textX,
                midY + S(7),
                SWUI.Colors.Accent,
                TEXT_ALIGN_LEFT,
                TEXT_ALIGN_CENTER
            )
        end

        -- Значок "+" справа
        SWUI.DrawText(
            '+',
            'SWUI.Small',
            x + pw - S(12),
            midY,
            Color(SWUI.Colors.Accent.r, SWUI.Colors.Accent.g, SWUI.Colors.Accent.b, 160),
            TEXT_ALIGN_RIGHT,
            TEXT_ALIGN_CENTER
        )

        surface.SetAlphaMultiplier(1)
    end

    -- Удаляем устаревшие
    for i = #toRemove, 1, -1 do
        table.remove(Feed, toRemove[i])
    end
end)

-- ============================================================
-- Отладка
-- ============================================================

concommand.Add('swexp_test_feed', function(_, _, args)
    local name  = args[1] or 'ГРАНАТЫ ДЛЯ ПП'
    local count = tonumber(args[2]) or 1
    AddFeedItem(string.upper(name), nil, count)
end)

print('[SWExp] Pickup Feed HUD загружен.')
