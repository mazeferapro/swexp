-- ============================================================
-- Star Wars: Expedition — Клиентский модуль зон
-- modules/cl_zones.lua
-- ============================================================

if SERVER then return end

-- ============================================================
-- Данные тиров
-- ============================================================

local TIER_COLORS = {
    [1] = Color(80,  200, 100),
    [2] = Color(80,  160, 255),
    [3] = Color(255, 180, 40),
    [4] = Color(220, 60,  60),
}

local TIER_NAMES = {
    [1] = "ТИР 1  —  ПЕРИМЕТР",
    [2] = "ТИР 2  —  ВНЕШНИЙ РУБЕЖ",
    [3] = "ТИР 3  —  АНОМАЛЬНЫЙ СЕКТОР",
    [4] = "ТИР 4  —  СЕРДЦЕ ТЬМЫ",
}

local ZONE_LABELS = {
    swexp_mat_zone = "Зона материалов",
    swexp_res_zone = "Зона исследований",
}

-- ============================================================
-- Плавный переход акцентного цвета
-- ============================================================

local function AnimateAccent(pnl, targetCol, duration)
    duration = duration or 0.25
    if not IsValid(pnl) then return end
    local start  = Color(pnl._accentColor.r, pnl._accentColor.g, pnl._accentColor.b)
    local startT = SysTime()
    local function step()
        if not IsValid(pnl) then return end
        local t = math.min((SysTime() - startT) / duration, 1)
        local e = SWUI.Animations.Easing.OutQuart(t)
        pnl._accentColor = Color(
            Lerp(e, start.r, targetCol.r),
            Lerp(e, start.g, targetCol.g),
            Lerp(e, start.b, targetCol.b)
        )
        if t < 1 then timer.Simple(0, step) end
    end
    timer.Simple(0, step)
end

-- ============================================================
-- Стилизованный слайдер
-- ============================================================

local function StyledSlider(parent, x, y, w, minV, maxV, defaultV, accentRef)
    local slider = vgui.Create("DNumSlider", parent)
    slider:SetPos(x, y)
    slider:SetSize(w, 30)
    slider:SetMin(minV)
    slider:SetMax(maxV)
    slider:SetDecimals(0)
    slider:SetValue(defaultV)
    slider:SetText("")

    slider.Slider.Paint = function(self, sw, sh)
        local frac = math.Clamp((slider:GetValue() - minV) / (maxV - minV), 0, 1)
        local col  = accentRef and accentRef() or SWUI.Colors.Accent
        draw.RoundedBox(3, 0, sh/2 - 3, sw,       6, Color(15, 28, 42, 220))
        if frac > 0 then
            draw.RoundedBox(3, 0, sh/2 - 3, sw * frac, 6, Color(col.r, col.g, col.b, 210))
        end
        local kx = sw * frac
        draw.RoundedBox(5, kx - 6, sh/2 - 6, 12, 12, Color(col.r, col.g, col.b, 255))
        draw.RoundedBox(5, kx - 4, sh/2 - 4,  8,  8, Color(220, 240, 255, 255))
    end

    if slider.TextArea then
        slider.TextArea:SetFont("SWUI.Tiny")
        slider.TextArea:SetTextColor(Color(200, 220, 240, 255))
    end

    return slider
end

-- ============================================================
-- Собственный Dropdown — оверлей поверх всего (не обрезается)
-- ============================================================

local function CreateTierDropdown(parent, x, y, w, currentTier, frameRef, onSelect)
    local ROW_H  = 34
    local PAD    = 6
    local HEADER = 34

    -- Кнопка-заголовок внутри контента окна
    local header = vgui.Create("DButton", parent)
    header:SetPos(x, y)
    header:SetSize(w, HEADER)
    header:SetText("")
    header._hov = 0

    local selectedTier = currentTier

    header.OnCursorEntered = function(self)
        local s = SysTime()
        local function anim()
            if not IsValid(self) then return end
            local t = math.min((SysTime()-s)/0.15, 1)
            self._hov = Lerp(SWUI.Animations.Easing.OutQuad(t), self._hov, 1)
            if t < 1 then timer.Simple(0, anim) end
        end
        timer.Simple(0, anim)
    end
    header.OnCursorExited = function(self)
        local s = SysTime()
        local v = self._hov
        local function anim()
            if not IsValid(self) then return end
            local t = math.min((SysTime()-s)/0.2, 1)
            self._hov = Lerp(SWUI.Animations.Easing.OutQuad(t), v, 0)
            if t < 1 then timer.Simple(0, anim) end
        end
        timer.Simple(0, anim)
    end

    header.Paint = function(self, bw, bh)
        local acc = frameRef._accentColor or TIER_COLORS[1]
        local bg  = Color(
            Lerp(self._hov, 12, 22),
            Lerp(self._hov, 22, 38),
            Lerp(self._hov, 34, 52),
            240
        )
        draw.RoundedBox(6, 0, 0, bw, bh, bg)
        surface.SetDrawColor(acc.r, acc.g, acc.b, 160 + 80 * self._hov)
        surface.DrawOutlinedRect(0, 0, bw, bh, 1)

        local tc = TIER_COLORS[selectedTier] or acc
        -- Цветная точка тира
        draw.RoundedBox(4, 10, bh/2 - 5, 10, 10, tc)
        draw.SimpleText(TIER_NAMES[selectedTier] or "ТИР ?", "SWUI.Small",
            28, bh/2, Color(220, 235, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(self._open and "▲" or "▼", "SWUI.Tiny",
            bw - 16, bh/2, Color(acc.r, acc.g, acc.b, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Оверлей-список (рисуется поверх всего как DFrame без рамки)
    local dropFrame = nil

    local function CloseDropdown()
        if IsValid(dropFrame) then
            SWUI.FadeOut(dropFrame, 0.15, 0, function()
                if IsValid(dropFrame) then dropFrame:Remove() end
                dropFrame = nil
            end)
        end
        if IsValid(header) then header._open = false end
    end

    local function OpenDropdown()
        if IsValid(dropFrame) then CloseDropdown() return end
        header._open = true

        local sx, sy = header:LocalToScreen(0, HEADER + 2)
        local listH  = #TIER_NAMES * ROW_H + PAD * 2

        dropFrame = vgui.Create("DFrame")
        dropFrame:SetSize(w, listH)
        dropFrame:SetPos(sx, sy)
        dropFrame:SetTitle("")
        dropFrame:SetDraggable(false)
        dropFrame:ShowCloseButton(false)
        dropFrame:SetMouseInputEnabled(true)
        dropFrame:SetKeyboardInputEnabled(false)
        dropFrame:MakePopup()
        dropFrame:SetAlpha(0)
        dropFrame:AlphaTo(255, 0.18, 0)

        dropFrame.Paint = function(self, fw, fh)
            draw.RoundedBox(8, 0, 0, fw, fh, Color(8, 14, 22, 250))
            local acc = frameRef._accentColor or TIER_COLORS[1]
            surface.SetDrawColor(acc.r, acc.g, acc.b, 120)
            surface.DrawOutlinedRect(0, 0, fw, fh, 1)
        end

        -- Закрытие при клике вне списка
        dropFrame.OnMousePressed = function(self, key)
            local mx, my = self:CursorPos()
            if mx < 0 or my < 0 or mx > w or my > listH then
                CloseDropdown()
            end
        end

        -- Строки тиров
        for i = 1, 4 do
            local row = vgui.Create("DButton", dropFrame)
            row:SetPos(PAD, PAD + (i - 1) * ROW_H)
            row:SetSize(w - PAD * 2, ROW_H - 2)
            row:SetText("")
            row._hov = 0
            row._sel = (i == selectedTier)

            row.OnCursorEntered = function(self)
                local s = SysTime()
                local function anim()
                    if not IsValid(self) then return end
                    local t = math.min((SysTime()-s)/0.12, 1)
                    self._hov = Lerp(SWUI.Animations.Easing.OutQuad(t), self._hov, 1)
                    if t < 1 then timer.Simple(0, anim) end
                end
                timer.Simple(0, anim)
            end
            row.OnCursorExited = function(self)
                local s = SysTime()
                local v = self._hov
                local function anim()
                    if not IsValid(self) then return end
                    local t = math.min((SysTime()-s)/0.15, 1)
                    self._hov = Lerp(SWUI.Animations.Easing.OutQuad(t), v, 0)
                    if t < 1 then timer.Simple(0, anim) end
                end
                timer.Simple(0, anim)
            end

            row.Paint = function(self, rw, rh)
                local tc = TIER_COLORS[i]
                local bg = Color(
                    tc.r * 0.12 + self._hov * tc.r * 0.18,
                    tc.g * 0.12 + self._hov * tc.g * 0.18,
                    tc.b * 0.12 + self._hov * tc.b * 0.18,
                    180 + self._hov * 50
                )
                draw.RoundedBox(5, 0, 0, rw, rh, bg)
                if self._sel then
                    surface.SetDrawColor(tc.r, tc.g, tc.b, 200)
                    surface.DrawOutlinedRect(0, 0, rw, rh, 1)
                end
                draw.RoundedBox(4, 8, rh/2 - 5, 10, 10, tc)
                draw.SimpleText(TIER_NAMES[i], "SWUI.Small",
                    26, rh/2,
                    self._sel and Color(255,255,255,255) or Color(180, 210, 230, 230),
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                if self._sel then
                    draw.SimpleText("✓", "SWUI.Small", rw - 14, rh/2,
                        Color(tc.r, tc.g, tc.b, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end

            row.DoClick = function()
                selectedTier = i
                -- Убираем галочку у остальных
                for _, ch in ipairs(dropFrame:GetChildren()) do
                    if IsValid(ch) and ch._sel ~= nil then ch._sel = false end
                end
                row._sel = true

                onSelect(i)
                AnimateAccent(frameRef, TIER_COLORS[i] or TIER_COLORS[1])
                CloseDropdown()
            end

            -- Stagger fade-in строк
            row:SetAlpha(0)
            SWUI.FadeIn(row, 0.2, (i - 1) * 0.04)
        end
    end

    header.DoClick = function()
        if IsValid(dropFrame) then CloseDropdown() else OpenDropdown() end
    end

    -- Возвращаем геттер текущего тира
    return header, function() return selectedTier end
end

-- ============================================================
-- Кнопка с анимацией + цвет тира
-- ============================================================

local function TierButton(parent, x, y, w, h, label, frameRef, onClick)
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetText("")
    btn._hov = 0

    btn.OnCursorEntered = function(self)
        local s = SysTime()
        local function anim()
            if not IsValid(self) then return end
            local t = math.min((SysTime()-s)/0.15, 1)
            self._hov = Lerp(SWUI.Animations.Easing.OutCubic(t), self._hov, 1)
            if t < 1 then timer.Simple(0, anim) end
        end
        timer.Simple(0, anim)
    end
    btn.OnCursorExited = function(self)
        local s = SysTime()
        local v = self._hov
        local function anim()
            if not IsValid(self) then return end
            local t = math.min((SysTime()-s)/0.2, 1)
            self._hov = Lerp(SWUI.Animations.Easing.OutCubic(t), v, 0)
            if t < 1 then timer.Simple(0, anim) end
        end
        timer.Simple(0, anim)
    end

    btn.Paint = function(self, bw, bh)
        local acc = frameRef._accentColor or SWUI.Colors.Accent
        local alpha = 180 + self._hov * 75
        draw.RoundedBox(6, 0, 0, bw, bh, Color(acc.r, acc.g, acc.b, alpha))
        if self._hov > 0 then
            draw.RoundedBox(6, 0, 0, bw, bh, Color(255, 255, 255, self._hov * 18))
        end
        draw.SimpleText(label, "SWUI.Small", bw/2, bh/2,
            Color(8, 14, 22, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = onClick
    SWUI.Animations.Presets.RippleClick(btn)
    return btn
end

-- ============================================================
-- Открыть меню настройки зоны
-- ============================================================

local function OpenZoneMenu(zone, class, tier, radius, respawn, maxCount)
    if IsValid(SWEXP_ZoneMenu) then SWEXP_ZoneMenu:Remove() end

    local zoneLbl = ZONE_LABELS[class] or "Зона"
    local initCol = TIER_COLORS[tier] or TIER_COLORS[1]
    local frameW  = 480
    local frameH  = 460

    -- ── Базовое окно SWUI ────────────────────────────────────
    local frame, content = SWUI.Animated.CreateWindow(
        string.upper(zoneLbl) .. "  —  НАСТРОЙКИ",
        frameW, frameH, nil, initCol
    )
    SWEXP_ZoneMenu = frame
    frame._accentColor = Color(initCol.r, initCol.g, initCol.b)

    -- Патчим Paint для живого акцента
    frame.Paint = function(self, pw, ph)
        local R      = 16
        local BORDER = 1
        local TBAR_H = 44
        local acc    = self._accentColor or initCol
        draw.RoundedBoxEx(R+BORDER, 0,      0,      pw,              ph,              Color(acc.r, acc.g, acc.b, 255), true, true, false, false)
        draw.RoundedBoxEx(R,        BORDER, BORDER, pw-BORDER*2,     ph-BORDER*2,     Color(6, 12, 18, 255),           true, true, false, false)
        draw.RoundedBox(R, BORDER, BORDER, pw-BORDER*2, TBAR_H, Color(12, 18, 26, 255))
        surface.SetDrawColor(12, 18, 26, 255)
        surface.DrawRect(BORDER, BORDER + TBAR_H - R, pw-BORDER*2, R)
        surface.SetDrawColor(acc.r, acc.g, acc.b, 255)
        surface.DrawRect(BORDER, BORDER + TBAR_H - 2, pw-BORDER*2, 2)
        draw.SimpleText(
            string.upper(zoneLbl) .. "  —  НАСТРОЙКИ",
            "SWUI.Header", BORDER + 16, BORDER + TBAR_H/2,
            SWUI.Colors.TextHi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
        )
    end

    -- ── Контент ─────────────────────────────────────────────
    local c  = content
    local cW = frameW
    local PAD = 24
    local y  = 16

    -- ── Метка тира ──────────────────────────────────────────
    local lblTier = vgui.Create("DLabel", c)
    lblTier:SetPos(PAD, y)
    lblTier:SetSize(cW - PAD*2, 16)
    lblTier:SetText("ТИР ЗОНЫ")
    lblTier:SetFont("SWUI.Tiny")
    lblTier:SetTextColor(SWUI.Colors.TextDim)
    SWUI.FadeIn(lblTier, 0.3, 0.05)

    y = y + 20

    -- ── Dropdown тира (оверлей) ──────────────────────────────
    local selectedTier = tier
    local _, getTier = CreateTierDropdown(c, PAD, y, cW - PAD*2, tier, frame, function(idx)
        selectedTier = idx
    end)
    -- getTier() возвращает актуальный выбранный тир
    SWUI.FadeIn(c:GetChildren()[#c:GetChildren()], 0.3, 0.10)

    y = y + 46

    -- ── Разделитель ──────────────────────────────────────────
    local divider = vgui.Create("DPanel", c)
    divider:SetPos(PAD, y)
    divider:SetSize(cW - PAD*2, 1)
    divider.Paint = function(self, dw, _)
        surface.SetDrawColor(26, 51, 72, 180)
        surface.DrawRect(0, 0, dw, 1)
    end
    SWUI.FadeIn(divider, 0.3, 0.12)

    y = y + 10

    -- ── Метка радиуса ────────────────────────────────────────
    local lblRadius = vgui.Create("DLabel", c)
    lblRadius:SetPos(PAD, y)
    lblRadius:SetSize(cW - PAD*2, 16)
    lblRadius:SetText("РАДИУС ЗОНЫ (ЕД.)")
    lblRadius:SetFont("SWUI.Tiny")
    lblRadius:SetTextColor(SWUI.Colors.TextDim)
    SWUI.FadeIn(lblRadius, 0.3, 0.15)

    y = y + 20

    local sliderRadius = StyledSlider(c, PAD, y, cW - PAD*2, 100, 3000, radius, function()
        return frame._accentColor or initCol
    end)
    SWUI.FadeIn(sliderRadius, 0.3, 0.18)

    y = y + 46

    -- ── Метка респавна ───────────────────────────────────────
    local lblRespawn = vgui.Create("DLabel", c)
    lblRespawn:SetPos(PAD, y)
    lblRespawn:SetSize(cW - PAD*2, 16)
    lblRespawn:SetText("ВРЕМЯ РЕСПАВНА (СЕК)")
    lblRespawn:SetFont("SWUI.Tiny")
    lblRespawn:SetTextColor(SWUI.Colors.TextDim)
    SWUI.FadeIn(lblRespawn, 0.3, 0.20)

    y = y + 20

    local sliderRespawn = StyledSlider(c, PAD, y, cW - PAD*2, 10, 600, respawn, function()
        return frame._accentColor or initCol
    end)
    SWUI.FadeIn(sliderRespawn, 0.3, 0.23)

    y = y + 46

    -- ── Метка макс. количества ───────────────────────────────
    local countLabel = (class == "swexp_mat_zone") and "МАКС. ПРЕДМЕТОВ В ЗОНЕ" or "МАКС. ТОЧЕК ИССЛЕДОВАНИЯ"
    local lblCount = vgui.Create("DLabel", c)
    lblCount:SetPos(PAD, y)
    lblCount:SetSize(cW - PAD*2, 16)
    lblCount:SetText(countLabel)
    lblCount:SetFont("SWUI.Tiny")
    lblCount:SetTextColor(SWUI.Colors.TextDim)
    SWUI.FadeIn(lblCount, 0.3, 0.25)

    y = y + 20

    local sliderCount = StyledSlider(c, PAD, y, cW - PAD*2, 1, 30, maxCount or 5, function()
        return frame._accentColor or initCol
    end)
    SWUI.FadeIn(sliderCount, 0.3, 0.27)

    y = y + 46

    -- ── Разделитель перед кнопками ────────────────────────────
    local divider2 = vgui.Create("DPanel", c)
    divider2:SetPos(PAD, y)
    divider2:SetSize(cW - PAD*2, 1)
    divider2.Paint = function(self, dw, _)
        surface.SetDrawColor(26, 51, 72, 180)
        surface.DrawRect(0, 0, dw, 1)
    end
    SWUI.FadeIn(divider2, 0.3, 0.30)

    y = y + 10

    local function SendSettings()
        if not IsValid(zone) then
            SWUI.Animations.Presets.Shake(frame, 5, 0.4)
            return false
        end
        net.Start("SWExp::Zone_SaveSettings")
            net.WriteEntity(zone)
            net.WriteInt(getTier(),                            8)
            net.WriteInt(math.Round(sliderRadius:GetValue()),  16)
            net.WriteInt(math.Round(sliderRespawn:GetValue()), 16)
            net.WriteInt(math.Round(sliderCount:GetValue()),   8)
        net.SendToServer()
        return true
    end

    -- ── Кнопки: [СОХРАНИТЬ] [ПРИМЕНИТЬ И ЗАКРЫТЬ] ────────────
    local btnW = (cW - PAD*2 - 12) / 2

    local btnSave = TierButton(c, PAD, y, btnW, 38, "СОХРАНИТЬ", frame, function()
        SendSettings()
    end)
    SWUI.FadeIn(btnSave, 0.3, 0.32)

    local btnApply = TierButton(c, PAD + btnW + 12, y, btnW, 38, "ПРИМЕНИТЬ И ЗАКРЫТЬ", frame, function()
        if SendSettings() then
            timer.Simple(0.12, function()
                if IsValid(frame) then frame:Close() end
            end)
        end
    end)
    SWUI.FadeIn(btnApply, 0.3, 0.35)
end

-- ============================================================
-- Получить запрос от сервера
-- ============================================================

net.Receive("SWExp::Zone_OpenMenu", function()
    local zone     = net.ReadEntity()
    local class    = net.ReadString()
    local tier     = net.ReadInt(8)
    local radius   = net.ReadInt(16)
    local respawn  = net.ReadInt(16)
    local maxCount = net.ReadInt(8)
    OpenZoneMenu(zone, class, tier, radius, respawn, maxCount)
end)

print("[SWExp] Клиентский модуль зон загружен (анимированный v2).")
