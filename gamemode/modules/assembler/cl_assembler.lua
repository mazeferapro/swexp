-- ============================================================
-- Star Wars: Expedition — Ассемблер (клиент)
-- modules/cl_assembler.lua
-- ============================================================

if SERVER then return end

SWExp.Assembler = SWExp.Assembler or {}

-- Локальный кэш
SWExp.Assembler._bank      = 0
SWExp.Assembler._inHand    = 0   -- материалы в инвентаре игрока
SWExp.Assembler._limit     = 30  -- дневной лимит текущего игрока
SWExp.Assembler._usedToday = 0   -- потрачено сегодня
SWExp.Assembler._limits    = {}  -- все лимиты по званиям (для интерфейса командира)

-- ============================================================
-- Net: открыть меню
-- ============================================================

net.Receive("SWExp::Assembler_Open", function()
    local techLevel  = net.ReadUInt(8)
    SWExp.Assembler._bank      = net.ReadInt(32)
    SWExp.Assembler._inHand    = net.ReadUInt(16)
    SWExp.Assembler._limit     = net.ReadUInt(16)
    SWExp.Assembler._usedToday = net.ReadUInt(16)
    local limitsJSON           = net.ReadString()
    SWExp.Assembler._limits    = util.JSONToTable(limitsJSON) or {}

    SWExp.Assembler.OpenMenu(techLevel)
end)

-- Net: обновление банка (от сервера без открытия меню)
net.Receive("SWExp::Assembler_Update", function()
    SWExp.Assembler._bank = net.ReadInt(32)
    if IsValid(SWExp.Assembler._frame) then
        if SWExp.Assembler._refreshBank then SWExp.Assembler._refreshBank() end
    end
end)

-- Net: тех. уровень изменился — перезагружаем меню если открыто
net.Receive("SWExp::Assembler_TechLevel", function()
    local newLevel = net.ReadUInt(8)
    local isFinal  = net.ReadBool()

    -- Показать уведомление в чате
    if isFinal then
        chat.AddText(
            Color(255, 215, 0), "[Исследования] ",
            Color(255, 255, 255), "Максимальный тех. уровень достигнут! Все рецепты открыты."
        )
    else
        chat.AddText(
            Color(80, 200, 255), "[Исследования] ",
            Color(200, 230, 255), "Тех. уровень повышен до ",
            Color(255, 240, 100), tostring(newLevel)
        )
    end

    -- Перезагрузить меню ассемблера с новым уровнем
    if IsValid(SWExp.Assembler._frame) then
        SWExp.Assembler.OpenMenu(newLevel)
    end
end)

-- Net: синхронизация всех лимитов
net.Receive("SWExp::Assembler_LimitsSync", function()
    local limitsJSON = net.ReadString()
    SWExp.Assembler._limits = util.JSONToTable(limitsJSON) or {}
    -- Обновить окно лимитов (если открыто) или основное меню
    if SWExp.Assembler._refreshLimits then
        SWExp.Assembler._refreshLimits()
    end
end)

-- Net: результат сдачи
net.Receive("SWExp::Assembler_DepositResult", function()
    local ok     = net.ReadBool()
    local errMsg = net.ReadString()
    local amount = net.ReadInt(16)
    local bank   = net.ReadInt(32)

    SWExp.Assembler._bank   = bank
    SWExp.Assembler._inHand = 0

    if ok then
        -- Читаем флаг обновления лимита
        local hasUsedUpdate = net.ReadBool()
        if hasUsedUpdate then
            local newUsed = net.ReadUInt(16)
            SWExp.Assembler._usedToday = newUsed
            chat.AddText(
                Color(0, 200, 255),   "[Ассемблер] ",
                Color(200, 220, 255), "Сдано в банк: ",
                Color(255, 240, 100), "+" .. amount .. " мат.",
                Color(140, 160, 190), "  (банк: " .. bank .. ") ",
                Color(100, 220, 140), "Лимит восстановлен на " .. amount .. " мат."
            )
        else
            chat.AddText(
                Color(0, 200, 255),   "[Ассемблер] ",
                Color(200, 220, 255), "Сдано в банк: ",
                Color(255, 240, 100), "+" .. amount .. " мат.",
                Color(140, 160, 190), "  (банк: " .. bank .. ")"
            )
        end
    else
        chat.AddText(Color(255, 80, 80), "[Ассемблер] ", Color(200, 180, 180), errMsg)
    end

    if IsValid(SWExp.Assembler._frame) then
        if SWExp.Assembler._refreshBank then SWExp.Assembler._refreshBank() end
    end
end)

-- Net: результат крафта
net.Receive("SWExp::Assembler_CraftResult", function()
    local ok     = net.ReadBool()
    local msg    = net.ReadString()
    local amount = net.ReadUInt(8)
    -- При успехе сервер дополнительно шлёт usedToday и bank
    local newUsed = ok and net.ReadUInt(16) or nil
    local newBank = ok and net.ReadInt(32)  or nil

    if ok then
        if newUsed then SWExp.Assembler._usedToday = newUsed end
        if newBank then SWExp.Assembler._bank      = newBank end
        chat.AddText(
            Color(80, 255, 140),  "[Ассемблер] ",
            Color(200, 220, 255), "Создано: ",
            Color(255, 240, 130), msg,
            Color(130, 200, 255), "  ×" .. amount
        )
        if SWExp and SWExp.Notify then
            SWExp.Notify("Создано: " .. msg .. " ×" .. amount, NOTIFY_HINT, 5)
        end
        -- Обновить топ-бар и кнопки рецептов
        if IsValid(SWExp.Assembler._frame) and SWExp.Assembler._refreshBank then
            SWExp.Assembler._refreshBank()
        end
    else
        chat.AddText(Color(255, 80, 80), "[Ассемблер] ", Color(200, 180, 180), msg)
        if SWExp and SWExp.Notify then
            SWExp.Notify(msg, NOTIFY_ERROR, 5)
        end
    end
end)

-- Net: обновление usedToday + limit (по таймеру или после сброса даты; не пересоздаёт меню)
net.Receive("SWExp::Assembler_UsageUpdate", function()
    local newUsed  = net.ReadUInt(16)
    local newLimit = net.ReadUInt(16)
    SWExp.Assembler._usedToday = newUsed
    if newLimit and newLimit > 0 then
        SWExp.Assembler._limit = newLimit
    end
    if IsValid(SWExp.Assembler._frame) and SWExp.Assembler._refreshBank then
        SWExp.Assembler._refreshBank()
    end
end)

-- ============================================================
-- VGUI МЕНЮ
-- ============================================================

-- ============================================================
-- Вспомогательная функция: может ли текущий игрок настраивать лимиты
-- ============================================================
local function LocalCanManageLimits()
    local lp = LocalPlayer()
    if not IsValid(lp) then return false end
    if lp:IsAdmin() or lp:IsSuperAdmin() then return true end
    local myRank = lp:GetNWString("swexp_rank", "")
    return SWExp.Ranks and SWExp.Ranks:CanManageLimits(myRank) or false
end

function SWExp.Assembler.OpenMenu(techLevel)
    if IsValid(SWExp.Assembler._frame) then
        SWExp.Assembler._frame:Close()
    end

    local cfg = SWExp.AssemblerConfig
    if not cfg then return end

    -- ============================================================
    -- Размеры
    -- ============================================================
    local W, H  = 1280, 840
    local PAD   = 16

    local frame, content = SWUI.Animated.CreateWindow("АССЕМБЛЕР", W, H, nil, SWUI.Colors.Accent)
    SWExp.Assembler._frame = frame

    local cW = content:GetWide()
    local cH = content:GetTall()

    -- ============================================================
    -- ВЕРХНЯЯ ПАНЕЛЬ — банк, у игрока, лимит
    -- ============================================================
    local topH = 64
    local topBar = vgui.Create("DPanel", content)
    topBar:SetPos(PAD, PAD)
    topBar:SetSize(cW - PAD * 2, topH)

    local function DrawTopBar(self, pw, ph)
        SWUI.DrawRoundedRect(0, 0, pw, ph, 6, SWUI.Colors.Panel2)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawOutlinedRect(0, 0, pw, ph, 1)

        local bank      = SWExp.Assembler._bank
        local inHand    = SWExp.Assembler._inHand
        local limit     = SWExp.Assembler._limit
        local usedToday = SWExp.Assembler._usedToday
        local remaining = math.max(0, limit - usedToday)

        -- Банк
        SWUI.DrawText("БАНК МАТЕРИАЛОВ", "SWUI.Tiny", 14, 10,
            SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        SWUI.DrawText(tostring(bank), "SWUI.MonoLarge", 14, ph,
            SWUI.Colors.Accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

        -- Разделитель
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawLine(160, 8, 160, ph - 8)

        -- У игрока
        SWUI.DrawText("В ИНВЕНТАРЕ", "SWUI.Tiny", 176, 10,
            SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        SWUI.DrawText(tostring(inHand), "SWUI.MonoLarge", 176, ph,
            inHand > 0 and Color(255, 220, 60) or SWUI.Colors.TextDim,
            TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

        surface.DrawLine(310, 8, 310, ph - 8)

        -- Лимит
        SWUI.DrawText("ДНЕВНОЙ ЛИМИТ", "SWUI.Tiny", 326, 10,
            SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        SWUI.DrawText(tostring(usedToday) .. " / " .. tostring(limit), "SWUI.Mono", 326, ph / 2 + 2,
            SWUI.Colors.TextHi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        -- Полоса лимита
        local barX, barW2, barH2 = 326, 120, 6
        local barY = ph - 14
        SWUI.DrawRoundedRect(barX, barY, barW2, barH2, 3, Color(255,255,255,15))
        local fill = limit > 0 and math.Clamp(usedToday / limit, 0, 1) or 0
        local barCol = fill > 0.85 and Color(255,80,80) or (fill > 0.6 and Color(255,160,0) or SWUI.Colors.Accent)
        SWUI.DrawRoundedRect(barX, barY, math.max(barH2, math.Round(barW2 * fill)), barH2, 3, barCol)


        -- Разделитель перед таймером
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawLine(560, 8, 560, ph - 8)

        -- Время до сброса лимита (до следующей полуночи UTC).
        -- Используем компоненты UTC напрямую — избегаем os.time(utc_table) который трактует числа как local time.
        local now = os.time()
        local utc = os.date("!*t", now)
        local secondsIntoDay = ((utc.hour or 0) * 3600) + ((utc.min or 0) * 60) + (utc.sec or 0)
        local secsLeft = (24 * 3600) - secondsIntoDay
        if secsLeft < 0 then secsLeft = 0 end
        local hh = math.floor(secsLeft / 3600)
        local mm = math.floor((secsLeft % 3600) / 60)
        local ss = secsLeft % 60
        local resetStr = string.format("%02d:%02d:%02d", hh, mm, ss)

        SWUI.DrawText("СБРОС ЛИМИТА", "SWUI.Tiny", 576, 10,
            SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        SWUI.DrawText(resetStr, "SWUI.Mono", 576, ph - 10,
            Color(180, 200, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

        -- Авто-обновление usedToday после перехода через полночь (когда таймер дошёл до 0),
        -- если меню оставили открытым. Срабатывает при перерисовке топбара.
        if secsLeft <= 3 then
            if not self._postResetSent then
                self._postResetSent = true
                timer.Simple(2, function()
                    if IsValid(SWExp.Assembler._frame) then
                        net.Start("SWExp::Assembler_RefreshMyUsage")
                        net.SendToServer()
                    end
                end)
            end
        else
            self._postResetSent = nil
        end

        -- Тех. уровень
        SWUI.DrawText("ТЕХ. УР. " .. techLevel, "SWUI.Small", pw - 14, ph / 2,
            SWUI.Colors.Accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    topBar.Paint = DrawTopBar

    -- Делаем таймер "живым": периодически инвалидируем layout чтобы Paint вызывался часто и цифры тикали.
    -- Также здесь — периодический запрос актуального usedToday с сервера (ловим естественный сброс даты).
    local tickInterval = 0.35
    topBar.Think = function(self)
        local ct = CurTime()
        if not self._nextTick then self._nextTick = ct + tickInterval end
        if ct >= self._nextTick then
            self._nextTick = ct + tickInterval
            if IsValid(self) then self:InvalidateLayout(true) end
        end

        if not self._lastUsageRefresh then self._lastUsageRefresh = ct end
        if ct - self._lastUsageRefresh > 45 then
            self._lastUsageRefresh = ct
            if IsValid(SWExp.Assembler._frame) then
                net.Start("SWExp::Assembler_RefreshMyUsage")
                net.SendToServer()
            end
        end
    end

    SWExp.Assembler._refreshBank = function()
        if IsValid(topBar) then topBar:InvalidateLayout(true) end
        if IsValid(SWExp.Assembler._recipeScroll) then
            SWExp.Assembler._recipeScroll:InvalidateLayout(true)
        end
    end

    -- Кнопка СДАТЬ + (если нужно) кнопка ЛИМИТЫ
    local canLimits   = LocalCanManageLimits()
    local limitsBtnW  = canLimits and 140 or 0
    local depositBtnW = 120
    local btnGap      = 8
    local rightPad    = 14
    -- Суммарная ширина кнопок справа
    local rightBtnsW  = depositBtnW + (canLimits and (limitsBtnW + btnGap) or 0)

    -- Кнопка НАСТРОЙКА ЛИМИТОВ (только если есть флаг canManageLimits)
    if canLimits then
        local limBtn = vgui.Create("DPanel", topBar)
        limBtn:SetPos(cW - PAD * 2 - rightBtnsW - rightPad, 8)
        limBtn:SetSize(limitsBtnW, topH - 16)
        limBtn:SetCursor("hand")
        limBtn.Paint = function(self, bw, bh)
            local hov = self:IsHovered()
            SWUI.DrawRoundedRect(0, 0, bw, bh, 5,
                hov and Color(40, 25, 0) or Color(22, 14, 0))
            surface.SetDrawColor(hov and Color(255, 180, 0) or Color(150, 100, 0))
            surface.DrawOutlinedRect(0, 0, bw, bh, 1)
            SWUI.DrawText("ЛИМИТЫ", "SWUI.Body", bw / 2, bh / 2,
                Color(255, 180, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        limBtn.OnMousePressed = function()
            SWExp.Assembler.OpenLimitsMenu()
        end
    end

    local depositBtn = vgui.Create("DPanel", topBar)
    depositBtn:SetPos(cW - PAD * 2 - depositBtnW - rightPad, 8)
    depositBtn:SetSize(depositBtnW, topH - 16)
    depositBtn:SetCursor("hand")
    depositBtn.Paint = function(self, bw, bh)
        local inHand = SWExp.Assembler._inHand
        local hov    = self:IsHovered()
        if inHand > 0 then
            SWUI.DrawRoundedRect(0, 0, bw, bh, 5,
                hov and Color(0, 50, 30) or Color(0, 30, 15))
            surface.SetDrawColor(hov and Color(0, 220, 130) or Color(0, 140, 80))
            surface.DrawOutlinedRect(0, 0, bw, bh, 1)
            SWUI.DrawText("СДАТЬ +" .. inHand, "SWUI.Body", bw / 2, bh / 2,
                Color(0, 255, 140), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        else
            SWUI.DrawRoundedRect(0, 0, bw, bh, 5, Color(15, 20, 25))
            surface.SetDrawColor(SWUI.Colors.Border)
            surface.DrawOutlinedRect(0, 0, bw, bh, 1)
            SWUI.DrawText("НЕТ МАТ.", "SWUI.Body", bw / 2, bh / 2,
                SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
    depositBtn.OnMousePressed = function()
        if SWExp.Assembler._inHand <= 0 then return end
        net.Start("SWExp::Assembler_DepositReq")
        net.SendToServer()
    end

    -- ============================================================
    -- ТЕЛО: левая панель (категории) + правая (рецепты)
    -- ============================================================
    local bodyY  = PAD + topH + PAD
    local bodyH  = cH - bodyY - PAD
    local recipeH = bodyH

    -- Левая — категории
    local catW = 180
    local catPanel = vgui.Create("DPanel", content)
    catPanel:SetPos(PAD, bodyY)
    catPanel:SetSize(catW, recipeH)
    catPanel.Paint = function(self, pw, ph)
        SWUI.DrawRoundedRect(0, 0, pw, ph, 8, SWUI.Colors.Panel2)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawOutlinedRect(0, 0, pw, ph, 1)
    end

    -- Правая — рецепты
    local recipeX = PAD + catW + PAD
    local recipeW = cW - recipeX - PAD

    local recipePanel = vgui.Create("DPanel", content)
    recipePanel:SetPos(recipeX, bodyY)
    recipePanel:SetSize(recipeW, recipeH)
    recipePanel.Paint = function(self, pw, ph)
        SWUI.DrawRoundedRect(0, 0, pw, ph, 8, SWUI.Colors.Panel2)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawOutlinedRect(0, 0, pw, ph, 1)
    end

    local scroll = vgui.Create("DScrollPanel", recipePanel)
    scroll:SetPos(6, 6)
    scroll:SetSize(recipeW - 12, recipeH - 12)
    scroll:GetVBar():SetWide(4)
    scroll:GetVBar().Paint = function(s, pw, ph)
        draw.RoundedBox(2, 0, 0, pw, ph, Color(255,255,255,12))
    end
    scroll:GetVBar().btnGrip.Paint = function(s, pw, ph)
        draw.RoundedBox(2, 0, 0, pw, ph, SWUI.Colors.Accent)
    end
    SWExp.Assembler._recipeScroll = scroll

    -- ============================================================
    -- Список рецептов (с группировкой по тирам)
    -- ============================================================

    -- Цвета редкости по тирам (совпадают с GetRarityColor в sh_inventory)
    local TIER_COLORS = {
        [1] = Color(168, 204, 220),   -- common    — светло-синий
        [2] = Color(0,  238, 119),    -- uncommon  — зелёный
        [3] = Color(0,  184, 255),    -- rare      — синий
        [4] = Color(163, 53, 238),    -- epic      — фиолетовый
        [5] = Color(255, 136,  0),    -- legendary — оранжевый
    }
    local TIER_NAMES = { "I", "II", "III", "IV", "V" }

    -- Состояние сворачивания тиров: сохраняется между сменой категорий
    -- collapsedTiers[N] = true  → тир N свёрнут
    local collapsedTiers = {}

    local function PopulateRecipes(categoryID)
        scroll:Clear()
        local recipes = cfg.GetRecipesByCategory(categoryID)
        if not recipes or #recipes == 0 then
            local lbl = vgui.Create("DLabel", scroll)
            lbl:SetText("Рецептов нет.") lbl:SetFont("SWUI.Body")
            lbl:SetTextColor(SWUI.Colors.TextDim) lbl:SizeToContents() lbl:SetPos(10, 10)
            return
        end

        local rowH      = 100   -- высота строки рецепта
        local tierHeadH = 32    -- высота заголовка тира
        local iconSz    = 44    -- размер иконки предмета
        local iconX     = 10    -- отступ иконки слева
        local textX     = iconX + iconSz + 12  -- начало текстового блока

        local y           = 4
        local currentTier = nil

        for _, recipe in ipairs(recipes) do
            local tier   = recipe.techLevel or 1
            local locked = tier > techLevel
            local cost   = recipe.cost or 0
            local rName  = recipe.name or recipe.result
            local rDesc  = recipe.desc or ""
            local rAmt   = recipe.amount or 1
            local tc     = TIER_COLORS[tier] or Color(200, 200, 200)

            -- ── Заголовок тира (кликабельный) ────────────────────────
            if tier ~= currentTier then
                currentTier = tier
                local tierLocked  = tier > techLevel
                local capturedCat = categoryID  -- захватываем для замыкания

                local hdr = vgui.Create("DPanel", scroll)
                hdr:SetPos(0, y)
                hdr:SetSize(recipeW - 20, tierHeadH)
                hdr:SetCursor("hand")

                hdr.Paint = function(self, pw, ph)
                    local collapsed = collapsedTiers[tier]
                    local hov       = self:IsHovered()

                    -- фоновый тинт (чуть ярче при наведении)
                    local alpha = hov and (tierLocked and 18 or 32) or (tierLocked and 10 or 22)
                    surface.SetDrawColor(Color(tc.r, tc.g, tc.b, alpha))
                    surface.DrawRect(0, 0, pw, ph)

                    -- левая полоса цвета тира
                    surface.SetDrawColor(tierLocked and Color(100, 60, 60) or tc)
                    surface.DrawRect(0, 0, 3, ph)

                    -- нижняя линия-разделитель
                    surface.SetDrawColor(Color(tc.r, tc.g, tc.b, 35))
                    surface.DrawRect(0, ph - 1, pw, 1)

                    -- стрелка-индикатор (треугольник)
                    local arrowX, arrowY = 16, math.floor(ph / 2)
                    local arrowCol = tierLocked and Color(120, 70, 70) or tc
                    draw.NoTexture()
                    surface.SetDrawColor(arrowCol)
                    if collapsed then
                        -- ► вправо (свёрнуто)
                        surface.DrawPoly({
                            { x = arrowX - 4, y = arrowY - 5 },
                            { x = arrowX - 4, y = arrowY + 5 },
                            { x = arrowX + 4, y = arrowY },
                        })
                    else
                        -- ▼ вниз (развёрнуто)
                        surface.DrawPoly({
                            { x = arrowX - 5, y = arrowY - 3 },
                            { x = arrowX + 5, y = arrowY - 3 },
                            { x = arrowX,     y = arrowY + 4 },
                        })
                    end

                    -- подпись тира
                    local tLabel = "   ТИР " .. (TIER_NAMES[tier] or tostring(tier))
                    SWUI.DrawText(tLabel, "SWUI.Small", 26, ph / 2,
                        tierLocked and Color(140, 80, 80) or tc,
                        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                    -- статус / подсказка справа
                    if tierLocked then
                        SWUI.DrawText("ЗАБЛОКИРОВАНО", "SWUI.Tiny", pw - 10, ph / 2,
                            Color(200, 80, 80), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    else
                        local hint = collapsed and "нажмите чтобы развернуть" or "нажмите чтобы свернуть"
                        SWUI.DrawText(hint, "SWUI.Tiny", pw - 10, ph / 2,
                            Color(tc.r, tc.g, tc.b, hov and 200 or 100),
                            TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    end
                end

                hdr.OnMousePressed = function()
                    collapsedTiers[tier] = not collapsedTiers[tier]
                    PopulateRecipes(capturedCat)
                end

                y = y + tierHeadH + 3
            end

            -- ── Пропускаем рецепты свёрнутого тира ───────────────────
            if collapsedTiers[tier] then continue end

            -- ── Строка рецепта ────────────────────────────────────────
            local function CanCraft()
                if locked then return false end
                if SWExp.Assembler._bank < cost then return false end
                local remaining = math.max(0, SWExp.Assembler._limit - SWExp.Assembler._usedToday)
                return remaining >= cost
            end

            local row = vgui.Create("DPanel", scroll)
            row:SetPos(0, y)
            row:SetSize(recipeW - 20, rowH)

            row.Paint = function(self, pw, ph)
                local can = CanCraft()
                local bg  = locked and Color(22, 10, 10)
                         or (can and Color(4, 22, 12) or Color(14, 18, 28))
                SWUI.DrawRoundedRect(0, 0, pw, ph, 6, bg)

                -- Рамка
                local bord = locked and Color(80, 30, 30)
                          or (can and Color(0, 100, 50) or SWUI.Colors.Border)
                surface.SetDrawColor(bord)
                surface.DrawOutlinedRect(0, 0, pw, ph, 1)

                -- Левая полоса цвета тира
                surface.SetDrawColor(Color(tc.r, tc.g, tc.b, locked and 35 or 90))
                surface.DrawRect(0, 0, 3, ph)

                -- Иконка (увеличенная)
                local recipeIcon = cfg.GetRecipeIcon(recipe)
                if recipeIcon then
                    local mat = Material(recipeIcon)
                    if mat and not mat:IsError() then
                        surface.SetMaterial(mat)
                        surface.SetDrawColor(locked and Color(80, 80, 80) or Color(255, 255, 255))
                        surface.DrawTexturedRect(iconX, math.floor(ph / 2 - iconSz / 2), iconSz, iconSz)
                    end
                end

                -- Название
                local nameCol = locked and SWUI.Colors.TextDim
                             or (can and SWUI.Colors.Green or SWUI.Colors.TextHi)
                SWUI.DrawText(rName, "SWUI.Body", textX, 12, nameCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                -- Описание
                SWUI.DrawText(rDesc, "SWUI.Tiny", textX, 38, SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                -- Стоимость
                local bank    = SWExp.Assembler._bank
                local costCol = bank >= cost and Color(255, 220, 100) or Color(255, 80, 80)
                SWUI.DrawText("Стоимость: " .. cost .. " мат.", "SWUI.Small", textX, ph - 18,
                    locked and SWUI.Colors.TextDim or costCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                -- Количество результата
                if rAmt > 1 then
                    SWUI.DrawText("x" .. rAmt, "SWUI.Small", pw - 130, 12,
                        SWUI.Colors.Accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                end

                -- Метка блокировки
                if locked then
                    SWUI.DrawText("ТИР " .. (recipe.techLevel or 1), "SWUI.Tiny", pw - 130, 12,
                        Color(200, 80, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                end
            end

            -- Кнопка СОЗДАТЬ
            if not locked then
                local btnW = 110
                local btn  = SWUI.CreateButton(row, "СОЗДАТЬ",
                    recipeW - 20 - btnW - 10 - 6,
                    (rowH - 34) / 2, btnW, 34, "ghost")
                btn.Paint = function(self, bw, bh)
                    local can = CanCraft()
                    local hov = self:IsHovered()
                    if can then
                        SWUI.DrawRoundedRect(0, 0, bw, bh, 4, hov and Color(0, 55, 28) or Color(0, 34, 16))
                        surface.SetDrawColor(hov and SWUI.Colors.Green or Color(0, 100, 50))
                        surface.DrawOutlinedRect(0, 0, bw, bh, 1)
                        SWUI.DrawText("СОЗДАТЬ", "SWUI.Small", bw/2, bh/2, SWUI.Colors.Green, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    else
                        SWUI.DrawRoundedRect(0, 0, bw, bh, 4, Color(15, 20, 25))
                        surface.SetDrawColor(SWUI.Colors.Border)
                        surface.DrawOutlinedRect(0, 0, bw, bh, 1)
                        SWUI.DrawText("СОЗДАТЬ", "SWUI.Small", bw/2, bh/2, SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                end
                btn.DoClick = function()
                    if not CanCraft() then return end
                    net.Start("SWExp::Assembler_CraftReq")
                        net.WriteString(recipe.id)
                    net.SendToServer()
                end
            end

            y = y + rowH + 5
        end
    end

    -- ============================================================
    -- Кнопки категорий
    -- ============================================================
    local cats     = cfg.Categories
    local activeCat = cats[1] and cats[1].id or "armor"
    PopulateRecipes(activeCat)

    local catBtnH = 44
    for i, cat in ipairs(cats) do
        local btn = vgui.Create("DPanel", catPanel)
        btn:SetPos(8, 10 + (i-1)*(catBtnH+4))
        btn:SetSize(catW - 16, catBtnH)
        btn.Paint = function(self, pw, ph)
            local active = (activeCat == cat.id)
            local hov    = self:IsHovered()
            SWUI.DrawRoundedRect(0, 0, pw, ph, 5,
                active and SWUI.Colors.Accent or (hov and Color(255,255,255,18) or Color(255,255,255,6)))
            if active then
                surface.SetDrawColor(Color(0,184,255,200))
                surface.DrawOutlinedRect(0,0,pw,ph,1)
            end
            if cat.icon then
                local m = Material(cat.icon)
                if m and not m:IsError() then
                    surface.SetMaterial(m) surface.SetDrawColor(255,255,255)
                    surface.DrawTexturedRect(8, ph/2-9, 18, 18)
                end
            end
            SWUI.DrawText(cat.name, "SWUI.Body", 34, ph/2,
                active and Color(255,255,255) or SWUI.Colors.TextHi,
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        btn:SetCursor("hand")
        btn.OnMousePressed = function()
            activeCat = cat.id
            PopulateRecipes(activeCat)
        end
    end

end

-- ============================================================
-- ОТДЕЛЬНОЕ МЕНЮ НАСТРОЙКИ ЛИМИТОВ
-- ============================================================

function SWExp.Assembler.OpenLimitsMenu()
    -- Закрыть старое, если уже открыто
    if IsValid(SWExp.Assembler._limFrame) then
        SWExp.Assembler._limFrame:Close()
        return
    end

    if not LocalCanManageLimits() then return end

    local cfg    = SWExp.AssemblerConfig
    local ranks  = SWExp.Ranks and SWExp.Ranks.List or {}
    if not cfg or #ranks == 0 then return end

    -- ============================================================
    -- Окно
    -- ============================================================
    local W, H = 860, 420
    local PAD  = 14

    local frame, content = SWUI.Animated.CreateWindow("НАСТРОЙКА ЛИМИТОВ ПО ЗВАНИЯМ", W, H, nil, Color(255, 160, 0))
    SWExp.Assembler._limFrame = frame

    local cW = content:GetWide()
    local cH = content:GetTall()

    -- Заголовок-подсказка
    local hintPanel = vgui.Create("DPanel", content)
    hintPanel:SetPos(PAD, PAD)
    hintPanel:SetSize(cW - PAD * 2, 34)
    hintPanel.Paint = function(self, pw, ph)
        SWUI.DrawRoundedRect(0, 0, pw, ph, 4, Color(30, 20, 0))
        surface.SetDrawColor(Color(255, 160, 0, 60))
        surface.DrawOutlinedRect(0, 0, pw, ph, 1)
        SWUI.DrawText(
            "Установите максимальное количество материалов, доступных каждому званию в сутки.",
            "SWUI.Tiny", pw / 2, ph / 2,
            Color(200, 160, 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
    end

    -- Область со столбцами по каждому званию
    local gridY  = PAD + 34 + PAD
    local gridH  = cH - gridY - PAD
    local colW   = math.floor((cW - PAD * 2) / #ranks)

    -- Таблица DTextEntry по rankID, чтобы обновлять при синхронизации
    local entries = {}

    for i, rankData in ipairs(ranks) do
        local rID   = rankData.id
        local colX  = PAD + (i - 1) * colW

        -- Фон колонки
        local colPanel = vgui.Create("DPanel", content)
        colPanel:SetPos(colX, gridY)
        colPanel:SetSize(colW - 2, gridH)
        colPanel.Paint = function(self, pw, ph)
            SWUI.DrawRoundedRect(0, 0, pw, ph, 6, Color(8, 12, 18))
            surface.SetDrawColor(Color(255, 255, 255, 8))
            surface.DrawOutlinedRect(0, 0, pw, ph, 1)
        end

        -- Название звания
        local lblPanel = vgui.Create("DPanel", colPanel)
        lblPanel:SetPos(0, 0)
        lblPanel:SetSize(colW - 2, 42)
        lblPanel.Paint = function(self, pw, ph)
            SWUI.DrawRoundedRect(0, 0, pw, ph, 6, Color(12, 16, 22))
            surface.SetDrawColor(rankData.color or Color(100, 120, 150))
            surface.DrawLine(4, ph - 1, pw - 4, ph - 1)
            SWUI.DrawText(rankData.shortName or rID, "SWUI.Small", pw / 2, ph / 2,
                rankData.color or SWUI.Colors.TextHi, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Текущий лимит
        local curLimit = SWExp.Assembler._limits[rID]
                      or (cfg.DefaultDailyLimits and cfg.DefaultDailyLimits[rID])
                      or cfg.DefaultLimit or 30

        -- Поле ввода
        local entry = vgui.Create("DTextEntry", colPanel)
        entry:SetPos(6, 50)
        entry:SetSize(colW - 2 - 12, 36)
        entry:SetText(tostring(curLimit))
        entry:SetFont("SWUI.Mono")
        entry:SetNumeric(true)
        entry:SetTextColor(SWUI.Colors.TextHi)
        entry.Paint = function(self, pw, ph)
            SWUI.DrawRoundedRect(0, 0, pw, ph, 4, Color(6, 10, 16))
            surface.SetDrawColor(self:IsEditing() and Color(255, 160, 0) or SWUI.Colors.Border)
            surface.DrawOutlinedRect(0, 0, pw, ph, 1)
            self:DrawTextEntryText(SWUI.Colors.TextHi, Color(255, 160, 0), SWUI.Colors.TextHi)
        end
        entries[rID] = entry

        -- Кнопка ПРИМЕНИТЬ
        local applyH = 36
        local applyBtn = vgui.Create("DPanel", colPanel)
        applyBtn:SetPos(6, 96)
        applyBtn:SetSize(colW - 2 - 12, applyH)
        applyBtn:SetCursor("hand")
        applyBtn.Paint = function(self, pw, ph)
            local hov = self:IsHovered()
            SWUI.DrawRoundedRect(0, 0, pw, ph, 4,
                hov and Color(50, 32, 0) or Color(28, 18, 0))
            surface.SetDrawColor(hov and Color(255, 200, 0) or Color(140, 100, 0))
            surface.DrawOutlinedRect(0, 0, pw, ph, 1)
            SWUI.DrawText("ПРИМЕНИТЬ", "SWUI.Tiny", pw / 2, ph / 2,
                Color(255, 200, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        applyBtn.OnMousePressed = function()
            local val = tonumber(entry:GetValue()) or 0
            val = math.Clamp(val, 0, 9999)
            SWExp.Assembler._limits[rID] = val
            net.Start("SWExp::Assembler_SetLimit")
                net.WriteString(rID)
                net.WriteUInt(val, 16)
            net.SendToServer()
            -- Визуальная подтверждение
            chat.AddText(
                Color(255, 180, 0), "[Ассемблер] ",
                Color(220, 210, 180), "Лимит для ",
                rankData.color or Color(255,255,255), rankData.name or rID,
                Color(220, 210, 180), " установлен на ",
                Color(255, 240, 100), tostring(val) .. " мат./день"
            )
        end
    end

    -- При синхронизации обновляем поля ввода в этом окне
    SWExp.Assembler._refreshLimits = function()
        for rID, entry in pairs(entries) do
            if IsValid(entry) then
                local v = SWExp.Assembler._limits[rID]
                       or (cfg.DefaultDailyLimits and cfg.DefaultDailyLimits[rID])
                       or cfg.DefaultLimit or 30
                entry:SetText(tostring(v))
            end
        end
    end

    frame.OnClose = function()
        SWExp.Assembler._limFrame = nil
        SWExp.Assembler._refreshLimits = nil
    end
end

print("[SWExp] Модуль ассемблера (клиент) загружен.")
