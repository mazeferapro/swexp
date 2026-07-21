-- ============================================================
-- modules/donate/cl_donate_shop.lua
-- Донат-магазин — клиентская часть
--
-- Открытие: console command "swexp_donate" (или вызов SWExp.DonateShop.Open())
--
-- Структура окна:
--   Левый сайдбар (220px): баланс + навигация
--   Правая область (820px):
--     • Паки моделей / Слоты → сетка карточек (3 в ряд)
--     • Мой инвентарь         → список с кнопками Применить/Убрать
-- ============================================================

if SERVER then return end

SWExp.DonateShop     = SWExp.DonateShop or {}
SWExp.DonateShop._UI = nil  -- ссылка на открытое окно

-- Локальный кэш (обновляется при каждом открытии)
local _currency     = 0
local _inventory    = {}   -- { [itemID] = count }  — поддержка stackable товаров (напр. слоты)
local _activePacks  = {}   -- { [itemID] = true }  — надетые паки персонажа

local function GetOwnedCount(itemID) return _inventory[itemID] or 0 end
local function IsOwned(itemID)  return GetOwnedCount(itemID) > 0 end
local function IsEquipped(itemID) return _activePacks[itemID] == true end

-- ============================================================
-- ПРИЁМ СЕТЕВЫХ ДАННЫХ
-- ============================================================

netstream.Hook('SWExp::DonateShop_Data', function(data)
    _currency = data.currency or 0
    _inventory = {}
    for _, id in ipairs(data.inventory or {}) do
        _inventory[id] = (_inventory[id] or 0) + 1
    end
    _activePacks = {}
    for _, id in ipairs(data.activePacks or {}) do
        _activePacks[id] = true
    end

    if IsValid(SWExp.DonateShop._UI) then
        SWExp.DonateShop._UI:FullRefresh()
    else
        SWExp.DonateShop._BuildUI()
    end
end)

netstream.Hook('SWExp::DonateCurrencyUpdate', function(newVal)
    _currency = newVal
    if IsValid(SWExp.DonateShop._UI) and SWExp.DonateShop._UI.RefreshCurrency then
        SWExp.DonateShop._UI:RefreshCurrency()
    end
end)

netstream.Hook('SWExp::DonateShop_BuyResult', function(result)
    if result.ok then
        _currency             = result.newCurrency or _currency
        local id = result.itemID
        _inventory[id] = (_inventory[id] or 0) + 1
        SWUI.SoundSuccess()
        if IsValid(SWExp.DonateShop._UI) then
            SWExp.DonateShop._UI:FullRefresh()
        end
        -- Всплывающее уведомление (если модуль есть)
        if SWExp.Notify then
            SWExp.Notify('✓ ' .. result.msg, SWUI.Colors.Green)
        end
    else
        SWUI.SoundDenied()
        if SWExp.Notify then
            SWExp.Notify('✗ ' .. result.msg, SWUI.Colors.Warn)
        end
    end
end)

netstream.Hook('SWExp::DonateShop_EquipResult', function(result)
    if result.ok then
        if result.equipped then
            -- Если сервер заменил конфликтующий пак — снимаем его на клиенте
            if result.replacedID then
                _activePacks[result.replacedID] = nil
            end
            _activePacks[result.itemID] = true
        else
            _activePacks[result.itemID] = nil
        end
        SWUI.SoundSuccess()
        if IsValid(SWExp.DonateShop._UI) then
            SWExp.DonateShop._UI:FullRefresh()
        end
    else
        SWUI.SoundDenied()
    end
end)

-- ============================================================
-- ОТКРЫТИЕ: запрашиваем данные → сервер ответит DonateShop_Data
-- ============================================================

function SWExp.DonateShop.Open()
    if IsValid(SWExp.DonateShop._UI) then
        SWExp.DonateShop._UI:Close()
        return
    end
    netstream.Start('SWExp::DonateShop_RequestData')
end

concommand.Add('swexp_donate', function()
    SWExp.DonateShop.Open()
end)

-- ============================================================
-- КОНСТАНТЫ СТИЛЯ
-- ============================================================

local GOLD     = Color(255, 196, 40)
local GOLD_DIM = Color(40, 35, 5, 220)
local GOLD_BRD = Color(255, 196, 40, 80)

-- ============================================================
-- СТРОИТЕЛЬНЫЕ ФУНКЦИИ UI
-- ============================================================

-- ── Скроллбар в едином стиле ────────────────────────────────
local function StyleScrollbar(scroll)
    local sbar = scroll:GetVBar()
    sbar:SetWide(5)
    sbar.Paint         = function(s, w, h) draw.RoundedBox(3, 0, 0, w, h, Color(8, 14, 20)) end
    sbar.btnUp.Paint   = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(s, w, h) draw.RoundedBox(3, 0, 0, w, h, SWUI.Colors.AccentDim) end
end

-- ── Кнопка с цветом ─────────────────────────────────────────
local function MakeButton(parent, x, y, w, h, label, col, onClick)
    local btn   = vgui.Create('DButton', parent)
    btn._hov    = false
    btn._col    = col
    btn._label  = label
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetText('')
    btn.OnCursorEntered = function(s) s._hov = true  end
    btn.OnCursorExited  = function(s) s._hov = false end
    btn.Paint = function(s, bw, bh)
        local c = s._col
        local bg = Color(c.r, c.g, c.b, s._hov and 220 or 160)
        draw.RoundedBox(6, 0, 0, bw, bh, bg)
        if s._hov then
            surface.SetDrawColor(Color(c.r, c.g, c.b, 80))
            surface.DrawOutlinedRect(0, 0, bw, bh, 1)
        end
        draw.SimpleText(s._label, 'SWUI.Small', bw / 2, bh / 2,
            SWUI.Colors.PanelBG, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = onClick or function() end
    return btn
end

-- ── Карточка товара в магазине ───────────────────────────────
local function BuildItemCard(parent, item, cx, cy, cw, ch, onBuy, onEquip)
    local ownedCount = GetOwnedCount(item.id)
    local isOwned    = ownedCount > 0
    local isStackable = item.stackable == true
    local isEquip   = (item.type == 'model_pack') and IsEquipped(item.id)
    local canAfford = _currency >= item.price

    local card = vgui.Create('DPanel', parent)
    card:SetPos(cx, cy)
    card:SetSize(cw, ch)
    card.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, SWUI.Colors.Panel2)
        local brd = isEquip and SWUI.Colors.Green
                  or (isOwned and Color(255, 196, 40, 120))
                  or SWUI.Colors.Border
        surface.SetDrawColor(brd)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local PREV_H = 162

    -- Превью: 3D-модель или заглушка
    if item.type == 'model_pack' and item.model then
        local mdlPnl = vgui.Create('DModelPanel', card)
        mdlPnl:SetPos(0, 0)
        mdlPnl:SetSize(cw, PREV_H)
        mdlPnl:SetModel(item.model)
        mdlPnl:SetCamPos(Vector(52, 0, 74))
        mdlPnl:SetLookAt(Vector(0, 0, 68))
        mdlPnl:SetFOV(38)
        mdlPnl.LayoutEntity = function() end  -- без автовращения

        -- Градиент снизу превью
        local grad = vgui.Create('DPanel', card)
        grad:SetPos(0, PREV_H - 28)
        grad:SetSize(cw, 28)
        grad.Paint = function(s, gw, gh)
            draw.RoundedBox(0, 0, 0, gw, gh, Color(14, 19, 25, 210))
        end
    else
        -- Иконка для не-модельных товаров
        local iconPnl = vgui.Create('DPanel', card)
        iconPnl:SetPos(0, 0)
        iconPnl:SetSize(cw, PREV_H)
        iconPnl.Paint = function(s, iw, ih)
            draw.RoundedBoxEx(8, 0, 0, iw, ih, Color(10, 15, 22), true, true, false, false)
            draw.SimpleText('⊕', 'SWUI.MonoLarge', iw / 2, ih / 2,
                Color(GOLD.r, GOLD.g, GOLD.b, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- Бейдж статуса
    if isOwned then
        local badge = vgui.Create('DPanel', card)
        local badgeTxt = isEquip and '● НАДЕТ' or '✓ КУПЛЕНО'
        if isStackable then
            badgeTxt = '× ' .. ownedCount
        end
        local bc       = isEquip and SWUI.Colors.Green or GOLD
        surface.SetFont('SWUI.Tiny')
        local btw = surface.GetTextSize(badgeTxt) + 14
        badge:SetPos(8, 8)
        badge:SetSize(btw, 20)
        badge.Paint = function(s, bw, bh)
            draw.RoundedBox(4, 0, 0, bw, bh, Color(bc.r, bc.g, bc.b, 200))
            draw.SimpleText(badgeTxt, 'SWUI.Tiny', bw / 2, bh / 2,
                Color(10, 10, 10), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- Название (2 строки, полностью)
    local nameY = PREV_H + 8
    local nameLbl = vgui.Create('DLabel', card)
    nameLbl:SetPos(10, nameY)
    nameLbl:SetSize(cw - 20, 40)
    nameLbl:SetText(item.name)
    nameLbl:SetFont('SWUI.Body')
    nameLbl:SetTextColor(SWUI.Colors.TextHi)
    nameLbl:SetWrap(true)
    nameLbl:SetAutoStretchVertical(false)

    -- Нижняя строка: цена + кнопка
    local BOT_Y = ch - 36
    local PRICE_W = 72

    -- Ценник
    local priceTag = vgui.Create('DPanel', card)
    priceTag:SetPos(10, BOT_Y + 3)
    priceTag:SetSize(PRICE_W, 26)
    priceTag.Paint = function(s, pw, ph)
        draw.RoundedBox(4, 0, 0, pw, ph, GOLD_DIM)
        draw.SimpleText('◉ ' .. tostring(item.price), 'SWUI.Small', pw / 2, ph / 2,
            GOLD, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Кнопка действия
    local BTN_W = cw - PRICE_W - 28
    local BTN_X = PRICE_W + 18

    -- Для stackable (напр. char_slot) показываем кнопку "Купить" даже если уже владеем (можно купить несколько раз)
    local showPermanentOwnedUI = isOwned and not isStackable

    if showPermanentOwnedUI then
        if item.type == 'model_pack' then
            local lbl = isEquip and 'Убрать' or 'Применить'
            local col = isEquip and SWUI.Colors.Warn or SWUI.Colors.Green
            MakeButton(card, BTN_X, BOT_Y, BTN_W, 30, lbl, col, function()
                if onEquip then onEquip(item.id, not isEquip) end
            end)
        end
        -- stackable owned (slots) — не заходим сюда, показываем кнопку Купить ниже
    else
        -- Кнопка "Купить" (доступна всегда для stackable, и для ещё не купленных)
        local locked = not canAfford
        local buyBtn = vgui.Create('DButton', card)
        buyBtn:SetPos(BTN_X, BOT_Y)
        buyBtn:SetSize(BTN_W, 30)
        buyBtn:SetText('')
        buyBtn._hov = false
        buyBtn.OnCursorEntered = function(s) s._hov = true  end
        buyBtn.OnCursorExited  = function(s) s._hov = false end
        buyBtn.Paint = function(s, bw, bh)
            if locked then
                draw.RoundedBox(6, 0, 0, bw, bh, Color(20, 22, 28))
                surface.SetDrawColor(SWUI.Colors.Border)
                surface.DrawOutlinedRect(0, 0, bw, bh, 1)
                draw.SimpleText('Купить', 'SWUI.Small', bw / 2, bh / 2,
                    SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            else
                draw.RoundedBox(6, 0, 0, bw, bh, Color(40, 35, 5, s._hov and 255 or 210))
                draw.SimpleText('Купить', 'SWUI.Small', bw / 2, bh / 2,
                    GOLD, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
        buyBtn.DoClick = function()
            if locked then SWUI.SoundDenied() return end
            if onBuy then onBuy(item.id) end
        end
    end

    return card
end

-- ── Панель магазина (сетка карточек) ────────────────────────
local function BuildShopContent(parent, catID, rw, rh, onBuy, onEquip)
    local CARD_W = 250
    local CARD_H = 272
    local COLS   = 3
    local PAD_X  = 18
    local GAP_X  = math.floor((rw - PAD_X * 2 - CARD_W * COLS) / (COLS - 1))
    local PAD_Y  = 14
    local GAP_Y  = 14

    local scroll = vgui.Create('DScrollPanel', parent)
    scroll:SetPos(0, 0)
    scroll:SetSize(rw, rh)
    StyleScrollbar(scroll)

    local inner = vgui.Create('DPanel', scroll)
    inner:SetWide(rw)
    inner.Paint = function() end

    local items = SWExp.DonateShop:GetItemsByCategory(catID)

    if #items == 0 then
        inner:SetTall(rh)
        local lbl = vgui.Create('DLabel', inner)
        lbl:SetPos(0, 80)
        lbl:SetSize(rw, 30)
        lbl:SetText('В этой категории пока нет товаров.')
        lbl:SetFont('SWUI.Body')
        lbl:SetTextColor(SWUI.Colors.TextDim)
        lbl:SetContentAlignment(5)
        return scroll
    end

    local rows = math.ceil(#items / COLS)
    inner:SetTall(PAD_Y + rows * (CARD_H + GAP_Y) + PAD_Y)

    for i, item in ipairs(items) do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        local cx  = PAD_X + col * (CARD_W + GAP_X)
        local cy  = PAD_Y + row * (CARD_H + GAP_Y)
        BuildItemCard(inner, item, cx, cy, CARD_W, CARD_H, onBuy, onEquip)
    end

    return scroll
end

-- ── Панель инвентаря (список) ────────────────────────────────
local function BuildInventoryContent(parent, rw, rh, onEquip)
    local ROW_H  = 72
    local ROW_G  = 6
    local PAD    = 16
    local THUMB  = 54

    local scroll = vgui.Create('DScrollPanel', parent)
    scroll:SetPos(0, 0)
    scroll:SetSize(rw, rh)
    StyleScrollbar(scroll)

    -- Собираем список купленных предметов (с поддержкой количества для stackable)
    local ownedItems = {}
    for _, item in ipairs(SWExp.DonateShop.Items) do
        if IsOwned(item.id) then
            ownedItems[#ownedItems + 1] = item
        end
    end

    local inner = vgui.Create('DPanel', scroll)
    inner:SetWide(rw)
    inner.Paint = function() end

    if #ownedItems == 0 then
        inner:SetTall(rh)
        local lbl = vgui.Create('DLabel', inner)
        lbl:SetPos(0, 100)
        lbl:SetSize(rw, 28)
        lbl:SetText('Ваш инвентарь пуст. Загляните в магазин!')
        lbl:SetFont('SWUI.Body')
        lbl:SetTextColor(SWUI.Colors.TextDim)
        lbl:SetContentAlignment(5)
        return scroll
    end

    inner:SetTall(PAD + #ownedItems * (ROW_H + ROW_G) + PAD)

    for idx, item in ipairs(ownedItems) do
        local isEquip = (item.type == 'model_pack') and IsEquipped(item.id)
        local rowY    = PAD + (idx - 1) * (ROW_H + ROW_G)
        local rowW    = rw - PAD * 2

        local row = vgui.Create('DPanel', inner)
        row:SetPos(PAD, rowY)
        row:SetSize(rowW, ROW_H)
        row.Paint = function(s, rw2, rh2)
            local bg = isEquip and Color(5, 28, 12, 220) or Color(14, 20, 28, 220)
            draw.RoundedBox(8, 0, 0, rw2, rh2, bg)
            local brd = isEquip and SWUI.Colors.Green or SWUI.Colors.Border
            surface.SetDrawColor(brd)
            surface.DrawOutlinedRect(0, 0, rw2, rh2, 1)
        end

        -- Превью (квадрат слева)
        local thumbPad = (ROW_H - THUMB) / 2
        if item.type == 'model_pack' and item.model then
            local mdlThumb = vgui.Create('DModelPanel', row)
            mdlThumb:SetPos(thumbPad, thumbPad)
            mdlThumb:SetSize(THUMB, THUMB)
            mdlThumb:SetModel(item.model)
            mdlThumb:SetCamPos(Vector(55, 0, 48))
            mdlThumb:SetLookAt(Vector(0, 0, 48))
            mdlThumb:SetFOV(58)
            mdlThumb.LayoutEntity = function() end
        else
            local iconPnl = vgui.Create('DPanel', row)
            iconPnl:SetPos(thumbPad, thumbPad)
            iconPnl:SetSize(THUMB, THUMB)
            iconPnl.Paint = function(s, iw, ih)
                draw.RoundedBox(6, 0, 0, iw, ih, SWUI.Colors.PanelBG)
                draw.SimpleText('⊕', 'SWUI.Header', iw / 2, ih / 2,
                    Color(GOLD.r, GOLD.g, GOLD.b, 140), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        -- Название и тип
        local TX = ROW_H + 4
        local TW = rowW - TX - 130

        local ownedCnt = GetOwnedCount(item.id)
        local displayName = item.name
        if item.stackable and ownedCnt > 1 then
            displayName = item.name .. ' ×' .. ownedCnt
        end

        local nameLbl = vgui.Create('DLabel', row)
        nameLbl:SetPos(TX, 14)
        nameLbl:SetSize(TW, 22)
        nameLbl:SetText(displayName)
        nameLbl:SetFont('SWUI.Body')
        nameLbl:SetTextColor(SWUI.Colors.TextHi)

        local typeStr = item.type == 'model_pack'      and 'Пак моделей'
                      or item.type == 'character_slot'  and 'Слот персонажа'
                      or item.type

        local typeLbl = vgui.Create('DLabel', row)
        typeLbl:SetPos(TX, 38)
        typeLbl:SetSize(TW, 18)
        typeLbl:SetText(typeStr)
        typeLbl:SetFont('SWUI.Small')
        typeLbl:SetTextColor(SWUI.Colors.TextDim)

        -- Кнопка Применить / Убрать (только для model_pack)
        if item.type == 'model_pack' then
            local BTN_W2 = 110
            local BTN_X2 = rowW - BTN_W2 - 10
            local BTN_Y2 = (ROW_H - 30) / 2
            local lbl    = isEquip and 'Убрать' or 'Применить'
            local col    = isEquip and SWUI.Colors.Warn or SWUI.Colors.Green
            MakeButton(row, BTN_X2, BTN_Y2, BTN_W2, 30, lbl, col, function()
                if onEquip then onEquip(item.id, not isEquip) end
            end)
        end
    end

    return scroll
end

-- ============================================================
-- ПОСТРОЕНИЕ ГЛАВНОГО ОКНА
-- ============================================================

function SWExp.DonateShop._BuildUI()
    if IsValid(SWExp.DonateShop._UI) then return end

    local W     = 1040
    local H     = 660
    local CH    = H - 44
    local NAV_W = 224

    local frame, content = SWUI.Animated.CreateWindow(
        'ДОНАТ МАГАЗИН', W, H, nil, GOLD
    )
    SWExp.DonateShop._UI = frame

    -- Закрытие → чистим ссылку
    local origClose = frame.Close
    frame.Close = function(self)
        SWExp.DonateShop._UI = nil
        origClose(self)
    end

    -- ──────────────────────────────────────────────────────────
    -- ЛЕВАЯ ПАНЕЛЬ
    -- ──────────────────────────────────────────────────────────
    local leftPanel = vgui.Create('DPanel', content)
    leftPanel:SetPos(0, 0)
    leftPanel:SetSize(NAV_W, CH)
    leftPanel.Paint = function(s, w, h)
        surface.SetDrawColor(SWUI.Colors.Panel2)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawRect(w - 1, 0, 1, h)
    end

    -- Баланс
    local balPanel = vgui.Create('DPanel', leftPanel)
    balPanel:SetPos(0, 0)
    balPanel:SetSize(NAV_W, 90)
    balPanel.Paint = function(s, w, h)
        -- фон
        draw.RoundedBox(0, 0, 0, w, h, Color(28, 24, 4, 220))
        -- нижняя линия
        surface.SetDrawColor(GOLD_BRD)
        surface.DrawRect(0, h - 1, w, 1)
        -- иконка
        draw.SimpleText('◉', 'SWUI.Header', w / 2, 16,
            GOLD, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        -- значение
        draw.SimpleText(tostring(_currency), 'SWUI.MonoLarge', w / 2, 34,
            GOLD, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        -- подпись
        draw.SimpleText('ДОНАТ-МОНЕТ', 'SWUI.Tiny', w / 2, h - 14,
            SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Обновление баланса без пересборки
    frame.RefreshCurrency = function(self)
        balPanel:InvalidateLayout(true)
    end

    -- Кнопка пополнения монет
    local buyBtn = vgui.Create('DButton', leftPanel)
    buyBtn:SetPos(10, 96)
    buyBtn:SetSize(NAV_W - 20, 28)
    buyBtn:SetText('')
    buyBtn:SetCursor('hand')
    buyBtn._hov = false
    buyBtn.OnCursorEntered = function(s) s._hov = true  end
    buyBtn.OnCursorExited  = function(s) s._hov = false end
    buyBtn.Paint = function(s, w, h)
        draw.RoundedBox(5, 0, 0, w, h, s._hov and Color(52, 42, 5, 245) or Color(32, 26, 3, 200))
        surface.SetDrawColor(s._hov and GOLD or GOLD_BRD)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText('+ КУПИТЬ МОНЕТЫ', 'SWUI.Tiny', w / 2, h / 2,
            s._hov and GOLD or Color(GOLD.r, GOLD.g, GOLD.b, 175),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    buyBtn.DoClick = function()
        gui.OpenURL('https://swrpexp.trademc.org/')
    end

    -- ──────────────────────────────────────────────────────────
    -- ПРАВАЯ ОБЛАСТЬ (контентная)
    -- ──────────────────────────────────────────────────────────
    local RW = W - NAV_W
    local rightPanel = vgui.Create('DPanel', content)
    rightPanel:SetPos(NAV_W, 0)
    rightPanel:SetSize(RW, CH)
    rightPanel.Paint = function() end

    -- Активный контент (хранит ссылку на текущую ScrollPanel)
    local activeContent = nil

    local function ClearContent()
        if IsValid(activeContent) then activeContent:Remove() end
        activeContent = nil
    end

    -- Callbacks для карточек
    local function OnBuy(itemID)
        netstream.Start('SWExp::DonateShop_Buy', itemID)
    end
    local function OnEquip(itemID, doEquip)
        netstream.Start('SWExp::DonateShop_EquipModel', {
            itemID = itemID,
            equip  = doEquip,
        })
    end

    -- Функция переключения контента по nav-id
    local currentNavID = 'models'

    local function ShowContent(navID)
        currentNavID = navID
        ClearContent()

        if navID == 'inventory' then
            activeContent = BuildInventoryContent(rightPanel, RW, CH, OnEquip)
        else
            -- navID = 'models' или 'slots' → категория магазина
            activeContent = BuildShopContent(rightPanel, navID, RW, CH, OnBuy, OnEquip)
        end
    end

    -- Полная пересборка (при изменении inventory / equippedModel)
    frame.FullRefresh = function(self)
        ShowContent(currentNavID)
        balPanel:InvalidateLayout(true)
    end

    -- ──────────────────────────────────────────────────────────
    -- НАВИГАЦИЯ
    -- ──────────────────────────────────────────────────────────
    local navItems = {
        { id = 'models',    label = 'Паки моделей',  icon = '◈' },
        { id = 'slots',     label = 'Слоты',          icon = '⊕' },
        { id = 'inventory', label = 'Мой инвентарь',  icon = '⊞' },
    }

    SWUI.Animated.CreateCategoryNav(
        leftPanel,
        navItems,
        0, 132,
        NAV_W, CH - 132,
        function(id) ShowContent(id) end,
        0
    )

    -- Начальный контент
    ShowContent('models')

    frame:Center()
    frame:MakePopup()
end

print('[SWExp.DonateShop] Клиентский модуль загружен.')
