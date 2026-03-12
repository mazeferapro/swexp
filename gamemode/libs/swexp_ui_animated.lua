-- ============================================================
-- Star Wars: Expedition — Animated UI Components
-- libs/swexp_ui_animated.lua
--
-- Обёртки над стандартными SWUI компонентами с анимациями
-- Подключение: include('libs/swexp_ui_animated.lua') после swexp_ui_animations.lua
-- ============================================================

if not CLIENT then return end

SWUI.Animated = SWUI.Animated or {}

-- ============================================================
-- ANIMATED WINDOW — окно с анимацией появления/закрытия
-- ============================================================

function SWUI.Animated.CreateWindow(title, w, h, parent, accentColor)
    local window = SWUI.CreateWindow(title, w, h, parent, accentColor)
    
    -- Применяем анимацию появления
    SWUI.Animations.Presets.WindowOpen(window, 0.35)
    
    -- Переопределяем Close с анимацией
    local originalClose = window.Close
    window.Close = function(self)
        SWUI.Animations.Presets.WindowClose(self, 0.25, function()
            if originalClose then originalClose(self) end
        end)
    end
    
    return window
end

-- ============================================================
-- ANIMATED BUTTON — кнопка с hover анимацией
-- ============================================================

function SWUI.Animated.CreateButton(parent, x, y, w, h, label, style, onClick)
    local btn = SWUI.CreateButton(parent, x, y, w, h, label, style, onClick)
    
    -- Применяем hover анимацию
    SWUI.Animations.Presets.ButtonHover(btn, 1.03, 0.15)
    
    -- Ripple эффект при клике
    SWUI.Animations.Presets.RippleClick(btn)
    
    return btn
end

-- ============================================================
-- ANIMATED CATEGORY NAV — навигация с плавными переходами
-- ============================================================

function SWUI.Animated.CreateCategoryNav(parent, items, x, y, w, h, onChange, cornerRadius)
    local nav = vgui.Create('DPanel', parent)
    nav:SetPos(x, y)
    nav:SetSize(w, h)
    local cr = cornerRadius or 16
    
    nav.Paint = function(self, pw, ph)
        draw.RoundedBoxEx(cr, 0, 0, pw, ph, Color(10, 16, 22, 255), false, false, true, false)
        surface.SetDrawColor(SWUI.Colors.BorderHi)
        surface.DrawLine(pw - 1, 0, pw - 1, ph)
    end

    local active = items[1] and items[1].id
    local rowH = 38
    local yOff = 10
    local buttons = {}

    for idx, item in ipairs(items) do
        local btn = vgui.Create('DPanel', nav)
        btn:SetPos(0, yOff)
        btn:SetSize(w, rowH)
        btn:SetCursor('hand')
        btn._hov = false
        btn._active = false
        btn._animProgress = 0  -- Для индикатора активности
        btn._hoverAlpha = 0    -- Для hover подсветки
        
        -- Анимация цвета
        btn._bgColor = Color(0, 0, 0, 0)
        
        btn.OnCursorEntered = function(self)
            self._hov = true
            SWUI.PlaySound(SWUI.Sounds.Hover, SWUI.SoundVolume * 0.4)
            
            -- Анимация hover альфы
            local startTime = SysTime()
            local startAlpha = self._hoverAlpha
            
            local animThink
            animThink = function()
                if not IsValid(self) then return end
                
                local elapsed = SysTime() - startTime
                local progress = math.min(elapsed / 0.15, 1)
                local eased = SWUI.Animations.Easing.OutQuad(progress)
                
                self._hoverAlpha = Lerp(eased, startAlpha, 1)
                
                if progress < 1 then
                    timer.Simple(0, animThink)
                end
            end
            timer.Simple(0, animThink)
        end
        
        btn.OnCursorExited = function(self)
            self._hov = false
            
            -- Анимация убирания hover
            local startTime = SysTime()
            local startAlpha = self._hoverAlpha
            
            local animThink
            animThink = function()
                if not IsValid(self) then return end
                
                local elapsed = SysTime() - startTime
                local progress = math.min(elapsed / 0.2, 1)
                local eased = SWUI.Animations.Easing.OutQuad(progress)
                
                self._hoverAlpha = Lerp(eased, startAlpha, 0)
                
                if progress < 1 then
                    timer.Simple(0, animThink)
                end
            end
            timer.Simple(0, animThink)
        end
        
        btn.OnMousePressed = function(self, mc)
            if mc == MOUSE_LEFT then self:DoClick() end
        end
        
        btn.DoClick = function(self) end

        btn.Paint = function(self, bw, bh)
            local isActive = self._active
            
            -- Анимированная подсветка при hover
            if self._hoverAlpha > 0 then
                local hoverColor = Color(0, 40, 65, 220 * self._hoverAlpha)
                surface.SetDrawColor(hoverColor)
                surface.DrawRect(0, 0, bw, bh)
            end
            
            -- Анимированный индикатор активности (левая граница)
            if self._animProgress > 0 then
                surface.SetDrawColor(SWUI.Colors.Accent)
                local barWidth = 3 * self._animProgress
                surface.DrawRect(0, 0, barWidth, bh)
            end

            local tc = Color(
                Lerp(self._animProgress, SWUI.Colors.Text.r, SWUI.Colors.Accent.r),
                Lerp(self._animProgress, SWUI.Colors.Text.g, SWUI.Colors.Accent.g),
                Lerp(self._animProgress, SWUI.Colors.Text.b, SWUI.Colors.Accent.b)
            )

            -- icon
            SWUI.DrawText(item.icon or '', 'SWUI.Body', 16, bh / 2, tc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            -- label
            SWUI.DrawText(string.upper(item.label), 'SWUI.Small', 42, bh / 2, tc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            -- count badge с анимацией
            if item.count and item.count > 0 then
                local cStr = tostring(item.count)
                surface.SetFont('SWUI.MonoSmall')
                local cw = surface.GetTextSize(cStr) + 10
                local cx = bw - cw - 10
                local cy = bh / 2 - 8

                local badgeBg = Color(
                    Lerp(self._animProgress, 255, SWUI.Colors.Accent.r),
                    Lerp(self._animProgress, 255, SWUI.Colors.Accent.g),
                    Lerp(self._animProgress, 255, SWUI.Colors.Accent.b),
                    Lerp(self._animProgress, 12, 25)
                )
                SWUI.DrawRoundedRect(cx, cy, cw, 16, 3, badgeBg)
                SWUI.DrawText(cStr, 'SWUI.MonoSmall', cx + cw / 2, bh / 2, tc, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
        
        -- Функция для анимации активации
        btn.SetActiveAnimated = function(self, isActive)
            self._active = isActive
            
            local targetProgress = isActive and 1 or 0
            local startProgress = self._animProgress
            local startTime = SysTime()
            local duration = 0.3
            
            local animThink
            animThink = function()
                if not IsValid(self) then return end
                
                local elapsed = SysTime() - startTime
                local progress = math.min(elapsed / duration, 1)
                local eased = SWUI.Animations.Easing.OutQuart(progress)
                
                self._animProgress = Lerp(eased, startProgress, targetProgress)
                
                if progress < 1 then
                    timer.Simple(0, animThink)
                end
            end
            timer.Simple(0, animThink)
        end

        btn.DoClick = function(self)
            -- Деактивируем все кнопки
            for _, otherBtn in ipairs(buttons) do
                if IsValid(otherBtn) then
                    otherBtn:SetActiveAnimated(false)
                end
            end
            
            -- Активируем текущую
            self:SetActiveAnimated(true)
            active = item.id
            
            SWUI.PlaySound(SWUI.Sounds.Tab, SWUI.SoundVolume * 0.65)
            if onChange then onChange(item.id) end
        end
        
        -- Стартовая анимация появления (stagger)
        btn:SetAlpha(0)
        SWUI.FadeIn(btn, 0.3, idx * 0.05)
        
        table.insert(buttons, btn)
        yOff = yOff + rowH + 2
    end
    
    -- Устанавливаем первую кнопку активной
    if buttons[1] then
        timer.Simple(0.1, function()
            if IsValid(buttons[1]) then
                buttons[1]:SetActiveAnimated(true)
            end
        end)
    end

    function nav:SetActive(id)
        active = id
        for _, btn in ipairs(buttons) do
            if IsValid(btn) then
                btn:SetActiveAnimated(btn._itemID == id)
            end
        end
    end

    return nav
end

-- ============================================================
-- ANIMATED LIST ROW — строка списка с hover анимацией
-- ============================================================

function SWUI.Animated.CreateListRow(parent, h, selected, locked, onClick)
    local row = vgui.Create('DPanel', parent)
    row:SetTall(h)
    row._selected = selected or false
    row._locked = locked or false
    row:SetCursor('hand')
    
    -- Анимация параметры
    row._hoverProgress = 0
    row._selectProgress = selected and 1 or 0
    
    row.OnCursorEntered = function(self)
        if self._locked then return end
        
        SWUI.PlaySound(SWUI.Sounds.Hover, SWUI.SoundVolume * 0.45)
        
        -- Анимация hover
        local startTime = SysTime()
        local startProgress = self._hoverProgress
        
        local animThink
        animThink = function()
            if not IsValid(self) then return end
            
            local elapsed = SysTime() - startTime
            local progress = math.min(elapsed / 0.15, 1)
            local eased = SWUI.Animations.Easing.OutQuad(progress)
            
            self._hoverProgress = Lerp(eased, startProgress, 1)
            
            if progress < 1 then
                timer.Simple(0, animThink)
            end
        end
        timer.Simple(0, animThink)
    end
    
    row.OnCursorExited = function(self)
        -- Анимация убирания hover
        local startTime = SysTime()
        local startProgress = self._hoverProgress
        
        local animThink
        animThink = function()
            if not IsValid(self) then return end
            
            local elapsed = SysTime() - startTime
            local progress = math.min(elapsed / 0.2, 1)
            local eased = SWUI.Animations.Easing.OutQuad(progress)
            
            self._hoverProgress = Lerp(eased, startProgress, 0)
            
            if progress < 1 then
                timer.Simple(0, animThink)
            end
        end
        timer.Simple(0, animThink)
    end
    
    row.OnMousePressed = function(self, mc)
        if mc == MOUSE_LEFT and onClick then
            if self._locked then
                SWUI.PlaySound(SWUI.Sounds.Denied)
                SWUI.Animations.Presets.Shake(self, 3, 0.3)
            else
                SWUI.PlaySound(SWUI.Sounds.Select)
                onClick()
            end
        end
    end

    row.Paint = function(self, pw, ph)
        local hov = self._hoverProgress
        local sel = self._selectProgress
        local locked = self._locked
        
        -- Интерполированный фон
        local bgAlpha = 100
        if locked then
            bgAlpha = 60
        else
            bgAlpha = bgAlpha + (120 * math.max(hov, sel))
        end
        
        local bg = Color(0, math.min(40 * math.max(hov, sel), 40), math.min(65 * math.max(hov, sel), 65), bgAlpha)
        SWUI.DrawRoundedRect(0, 0, pw, ph, 8, bg)
        
        -- Интерполированная граница
        local brd
        if locked then
            brd = SWUI.Colors.Border
        elseif sel > 0.5 then
            brd = Color(
                Lerp(sel, SWUI.Colors.BorderHi.r, SWUI.Colors.Accent.r),
                Lerp(sel, SWUI.Colors.BorderHi.g, SWUI.Colors.Accent.g),
                Lerp(sel, SWUI.Colors.BorderHi.b, SWUI.Colors.Accent.b)
            )
        else
            brd = Color(
                Lerp(hov, SWUI.Colors.Border.r, SWUI.Colors.BorderHi.r),
                Lerp(hov, SWUI.Colors.Border.g, SWUI.Colors.BorderHi.g),
                Lerp(hov, SWUI.Colors.Border.b, SWUI.Colors.BorderHi.b)
            )
        end
        
        surface.SetDrawColor(brd)
        surface.DrawOutlinedRect(0, 0, pw, ph, 1)
    end
    
    -- Метод для анимированного изменения selected
    row.SetSelectedAnimated = function(self, isSelected)
        self._selected = isSelected
        
        local targetProgress = isSelected and 1 or 0
        local startProgress = self._selectProgress
        local startTime = SysTime()
        local duration = 0.25
        
        local animThink
        animThink = function()
            if not IsValid(self) then return end
            
            local elapsed = SysTime() - startTime
            local progress = math.min(elapsed / duration, 1)
            local eased = SWUI.Animations.Easing.OutQuart(progress)
            
            self._selectProgress = Lerp(eased, startProgress, targetProgress)
            
            if progress < 1 then
                timer.Simple(0, animThink)
            end
        end
        timer.Simple(0, animThink)
    end

    return row
end

-- ============================================================
-- ANIMATED DROPDOWN MENU — выпадающее меню с expand анимацией
-- ============================================================

function SWUI.Animated.CreateDropdown(parent, x, y, w, items, defaultIndex, onChange)
    local dropdown = vgui.Create('DPanel', parent)
    dropdown:SetPos(x, y)
    dropdown:SetSize(w, 32)
    dropdown._isOpen = false
    dropdown._selectedIndex = defaultIndex or 1
    dropdown._items = items
    
    local header = vgui.Create('DButton', dropdown)
    header:Dock(TOP)
    header:SetTall(32)
    header:SetText('')
    header._hoverAlpha = 0
    
    header.Paint = function(self, hw, hh)
        -- Фон с hover анимацией
        local bgAlpha = 120 + (100 * self._hoverAlpha)
        SWUI.DrawRoundedRect(0, 0, hw, hh, 6, Color(0, 0, 0, bgAlpha))
        
        local brdColor = Color(
            Lerp(self._hoverAlpha, SWUI.Colors.Border.r, SWUI.Colors.BorderHi.r),
            Lerp(self._hoverAlpha, SWUI.Colors.Border.g, SWUI.Colors.BorderHi.g),
            Lerp(self._hoverAlpha, SWUI.Colors.Border.b, SWUI.Colors.BorderHi.b)
        )
        surface.SetDrawColor(brdColor)
        surface.DrawOutlinedRect(0, 0, hw, hh, 1)
        
        -- Текст
        local text = items[dropdown._selectedIndex] or 'Select...'
        SWUI.DrawText(text, 'SWUI.Body', 10, hh / 2, SWUI.Colors.TextHi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        
        -- Стрелка
        local arrowIcon = dropdown._isOpen and '▲' or '▼'
        SWUI.DrawText(arrowIcon, 'SWUI.Small', hw - 16, hh / 2, SWUI.Colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    -- Hover анимация для header
    header.OnCursorEntered = function(self)
        local startTime = SysTime()
        local startAlpha = self._hoverAlpha
        
        local animThink
        animThink = function()
            if not IsValid(self) then return end
            
            local elapsed = SysTime() - startTime
            local progress = math.min(elapsed / 0.15, 1)
            local eased = SWUI.Animations.Easing.OutQuad(progress)
            
            self._hoverAlpha = Lerp(eased, startAlpha, 1)
            
            if progress < 1 then
                timer.Simple(0, animThink)
            end
        end
        timer.Simple(0, animThink)
    end
    
    header.OnCursorExited = function(self)
        local startTime = SysTime()
        local startAlpha = self._hoverAlpha
        
        local animThink
        animThink = function()
            if not IsValid(self) then return end
            
            local elapsed = SysTime() - startTime
            local progress = math.min(elapsed / 0.2, 1)
            local eased = SWUI.Animations.Easing.OutQuad(progress)
            
            self._hoverAlpha = Lerp(eased, startAlpha, 0)
            
            if progress < 1 then
                timer.Simple(0, animThink)
            end
        end
        timer.Simple(0, animThink)
    end
    
    -- Контейнер для items
    local itemsContainer = vgui.Create('DPanel', dropdown)
    itemsContainer:Dock(TOP)
    itemsContainer:SetTall(0)
    itemsContainer:SetAlpha(0)
    itemsContainer.Paint = function(self, iw, ih)
        SWUI.DrawRoundedRect(0, 2, iw, ih - 2, 6, Color(11, 15, 20, 240))
        surface.SetDrawColor(SWUI.Colors.BorderHi)
        surface.DrawOutlinedRect(0, 2, iw, ih - 2, 1)
    end
    
    -- Toggle dropdown
    header.DoClick = function()
        dropdown._isOpen = not dropdown._isOpen
        
        if dropdown._isOpen then
            SWUI.PlaySound(SWUI.Sounds.Open)
            
            -- Expand анимация
            local targetHeight = #items * 28 + 4
            SWUI.Animations.Presets.Expand(itemsContainer, targetHeight, 0.25)
            SWUI.FadeIn(itemsContainer, 0.2)
            
            -- Создаём items если еще не созданы
            if #itemsContainer:GetChildren() == 0 then
                for i, itemText in ipairs(items) do
                    local item = vgui.Create('DButton', itemsContainer)
                    item:Dock(TOP)
                    item:DockMargin(2, 2, 2, 0)
                    item:SetTall(28)
                    item:SetText('')
                    item._hoverAlpha = 0
                    item._index = i
                    
                    item.Paint = function(self, iw, ih)
                        local isSelected = (self._index == dropdown._selectedIndex)
                        
                        if isSelected or self._hoverAlpha > 0 then
                            local alpha = isSelected and 180 or (140 * self._hoverAlpha)
                            surface.SetDrawColor(0, 40, 65, alpha)
                            surface.DrawRect(0, 0, iw, ih)
                        end
                        
                        local tc = isSelected and SWUI.Colors.Accent or SWUI.Colors.Text
                        SWUI.DrawText(itemText, 'SWUI.Body', 8, ih / 2, tc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    end
                    
                    item.OnCursorEntered = function(self)
                        SWUI.PlaySound(SWUI.Sounds.Hover, SWUI.SoundVolume * 0.4)
                        
                        local startTime = SysTime()
                        local startAlpha = self._hoverAlpha
                        
                        local animThink
                        animThink = function()
                            if not IsValid(self) then return end
                            
                            local elapsed = SysTime() - startTime
                            local progress = math.min(elapsed / 0.12, 1)
                            local eased = SWUI.Animations.Easing.OutQuad(progress)
                            
                            self._hoverAlpha = Lerp(eased, startAlpha, 1)
                            
                            if progress < 1 then
                                timer.Simple(0, animThink)
                            end
                        end
                        timer.Simple(0, animThink)
                    end
                    
                    item.OnCursorExited = function(self)
                        local startTime = SysTime()
                        local startAlpha = self._hoverAlpha
                        
                        local animThink
                        animThink = function()
                            if not IsValid(self) then return end
                            
                            local elapsed = SysTime() - startTime
                            local progress = math.min(elapsed / 0.15, 1)
                            local eased = SWUI.Animations.Easing.OutQuad(progress)
                            
                            self._hoverAlpha = Lerp(eased, startAlpha, 0)
                            
                            if progress < 1 then
                                timer.Simple(0, animThink)
                            end
                        end
                        timer.Simple(0, animThink)
                    end
                    
                    item.DoClick = function(self)
                        SWUI.PlaySound(SWUI.Sounds.Select)
                        dropdown._selectedIndex = self._index
                        dropdown._isOpen = false
                        
                        -- Collapse анимация
                        SWUI.Animations.Presets.Expand(itemsContainer, 0, 0.2)
                        SWUI.FadeOut(itemsContainer, 0.15)
                        
                        if onChange then onChange(self._index, itemText) end
                    end
                    
                    -- Stagger fade in
                    item:SetAlpha(0)
                    SWUI.FadeIn(item, 0.2, i * 0.03)
                end
            end
        else
            SWUI.PlaySound(SWUI.Sounds.Close)
            
            -- Collapse анимация
            SWUI.Animations.Presets.Expand(itemsContainer, 0, 0.2)
            SWUI.FadeOut(itemsContainer, 0.15)
        end
    end
    
    return dropdown
end

print('[SWExp] Animated UI Components загружены.')