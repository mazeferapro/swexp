--[[--
    SWExp: Клиентский модуль тировых порталов
    modules/cl_tiered_portals.lua

    Загружается автоматически через SWExp.LoadModules (префикс cl_).

    Содержит:
    - Меню настройки портала для администраторов (открывается по E)
    - Стиль: идентичен меню зон (cl_zones.lua) — SWUI, анимации, dropdown тира
]]--

if SERVER then return end

-- ============================================================================
-- ДАННЫЕ ТИРОВ
-- ============================================================================

local TIER_COLORS = {
    [1] = Color(0,   220, 50),
    [2] = Color(50,  100, 255),
    [3] = Color(255, 140, 0),
    [4] = Color(220, 30,  30),
}

local TIER_NAMES = {
    [1] = "ТИР I  —  ПЕРИМЕТР",
    [2] = "ТИР II  —  ВНЕШНИЙ РУБЕЖ",
    [3] = "ТИР III  —  АНОМАЛЬНЫЙ СЕКТОР",
    [4] = "ТИР IV  —  СЕРДЦЕ ТЬМЫ",
}

local TIER_KEY_NAMES = {
    [1] = "Ключ врат (Tier 1)",
    [2] = "Ключ врат (Tier 2)",
    [3] = "Ключ врат (Tier 3)",
    [4] = "Ключ врат (Tier 4)",
}

-- ============================================================================
-- ПЛАВНАЯ АНИМАЦИЯ АКЦЕНТНОГО ЦВЕТА
-- ============================================================================

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

-- ============================================================================
-- КАСТОМНЫЙ DROPDOWN ТИРА (поверх всего, не обрезается окном)
-- ============================================================================

local function CreateTierDropdown(parent, x, y, w, currentTier, frameRef, onSelect)
    local ROW_H  = 34
    local PAD    = 6
    local HEADER = 34

    local selectedTier = currentTier

    local header = vgui.Create("DButton", parent)
    header:SetPos(x, y)
    header:SetSize(w, HEADER)
    header:SetText("")
    header._hov  = 0
    header._open = false

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
        draw.RoundedBox(4, 10, bh/2 - 5, 10, 10, tc)
        draw.SimpleText(TIER_NAMES[selectedTier] or "ТИР ?", "SWUI.Small",
            28, bh/2, Color(220, 235, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(self._open and "▲" or "▼", "SWUI.Tiny",
            bw - 16, bh/2, Color(acc.r, acc.g, acc.b, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

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
        local listH  = 4 * ROW_H + PAD * 2

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

        dropFrame.OnMousePressed = function(self, key)
            local mx, my = self:CursorPos()
            if mx < 0 or my < 0 or mx > w or my > listH then
                CloseDropdown()
            end
        end

        for i = 1, 4 do
            local row = vgui.Create("DButton", dropFrame)
            row:SetPos(PAD, PAD + (i-1) * ROW_H)
            row:SetSize(w - PAD*2, ROW_H - 2)
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
                for _, ch in ipairs(dropFrame:GetChildren()) do
                    if IsValid(ch) and ch._sel ~= nil then ch._sel = false end
                end
                row._sel = true
                onSelect(i)
                AnimateAccent(frameRef, TIER_COLORS[i] or TIER_COLORS[1])
                CloseDropdown()
            end

            row:SetAlpha(0)
            SWUI.FadeIn(row, 0.2, (i-1) * 0.04)
        end
    end

    header.DoClick = function()
        if IsValid(dropFrame) then CloseDropdown() else OpenDropdown() end
    end

    return header, function() return selectedTier end
end

-- ============================================================================
-- КНОПКА В СТИЛЕ SWUI
-- ============================================================================

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
        local acc   = frameRef._accentColor or SWUI.Colors.Accent
        local alpha = 180 + self._hov * 75
        draw.RoundedBox(6, 0, 0, bw, bh, Color(acc.r, acc.g, acc.b, alpha))
        if self._hov > 0 then
            draw.RoundedBox(6, 0, 0, bw, bh, Color(255, 255, 255, self._hov * 18))
        end
        draw.SimpleText(label, "SWUI.Small", bw/2, bh/2,
            Color(8, 14, 22, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = onClick
    if SWUI.Animations and SWUI.Animations.Presets and SWUI.Animations.Presets.RippleClick then
        SWUI.Animations.Presets.RippleClick(btn)
    end
    return btn
end

-- ============================================================================
-- ТЕКСТОВОЕ ПОЛЕ В СТИЛЕ SWUI
-- ============================================================================

local function StyledTextEntry(parent, x, y, w, h, placeholder, frameRef)
    local te = vgui.Create("DTextEntry", parent)
    te:SetPos(x, y)
    te:SetSize(w, h)
    te:SetFont("SWUI.Small")
    te:SetTextColor(Color(220, 235, 255, 255))
    te:SetCursorColor(Color(220, 235, 255, 255))
    te:SetText("")
    te:SetPlaceholderText(placeholder)
    te:SetPlaceholderColor(Color(100, 130, 160, 180))
    te:SetNumeric(true)
    te:SetMaximumCharCount(3)

    te.Paint = function(self, tw, th)
        local acc = frameRef._accentColor or SWUI.Colors.Accent
        local focused = self:HasFocus()
        draw.RoundedBox(6, 0, 0, tw, th, Color(12, 22, 34, 240))
        surface.SetDrawColor(acc.r, acc.g, acc.b, focused and 220 or 100)
        surface.DrawOutlinedRect(0, 0, tw, th, focused and 2 or 1)
        self:DrawTextEntryText(Color(220,235,255,255), Color(acc.r, acc.g, acc.b, 120), Color(220,235,255,255))
    end

    return te
end

-- ============================================================================
-- ОТКРЫТЬ МЕНЮ НАСТРОЙКИ ПОРТАЛА
-- ============================================================================

local function OpenPortalAdminMenu(portal, tier, myCode, linkedCode, isOpen)
    if IsValid(SWEXP_PortalMenu) then SWEXP_PortalMenu:Remove() end

    local initCol = TIER_COLORS[tier] or TIER_COLORS[1]
    local frameW  = 480
    local frameH  = 480

    local frame, content = SWUI.Animated.CreateWindow(
        "ТИРОВЫЙ ПОРТАЛ  —  НАСТРОЙКИ",
        frameW, frameH, nil, initCol
    )
    SWEXP_PortalMenu = frame
    frame._accentColor = Color(initCol.r, initCol.g, initCol.b)

    -- Патчим Paint для живого акцентного цвета
    frame.Paint = function(self, pw, ph)
        local R      = 16
        local BORDER = 1
        local TBAR_H = 44
        local acc    = self._accentColor or initCol
        draw.RoundedBoxEx(R+BORDER, 0,      0,      pw,          ph,          Color(acc.r, acc.g, acc.b, 255), true, true, false, false)
        draw.RoundedBoxEx(R,        BORDER, BORDER, pw-BORDER*2, ph-BORDER*2, Color(6, 12, 18, 255),           true, true, false, false)
        draw.RoundedBox(R, BORDER, BORDER, pw-BORDER*2, TBAR_H, Color(12, 18, 26, 255))
        surface.SetDrawColor(12, 18, 26, 255)
        surface.DrawRect(BORDER, BORDER + TBAR_H - R, pw-BORDER*2, R)
        surface.SetDrawColor(acc.r, acc.g, acc.b, 255)
        surface.DrawRect(BORDER, BORDER + TBAR_H - 2, pw-BORDER*2, 2)
        draw.SimpleText("ТИРОВЫЙ ПОРТАЛ  —  НАСТРОЙКИ", "SWUI.Header",
            BORDER + 16, BORDER + TBAR_H/2,
            SWUI.Colors.TextHi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local c   = content
    local cW  = frameW
    local PAD = 24
    local y   = 16

    -- ── Инфо-строка: мой код ──────────────────────────────────────────────────
    local infoPanel = vgui.Create("DPanel", c)
    infoPanel:SetPos(PAD, y)
    infoPanel:SetSize(cW - PAD*2, 36)
    infoPanel.Paint = function(self, pw, ph)
        local acc = frame._accentColor or initCol
        draw.RoundedBox(6, 0, 0, pw, ph, Color(6, 18, 30, 220))
        surface.SetDrawColor(acc.r, acc.g, acc.b, 80)
        surface.DrawOutlinedRect(0, 0, pw, ph, 1)
        draw.SimpleText("КОД ЭТОГО ПОРТАЛА:", "SWUI.Tiny",
            12, ph/2, Color(120, 160, 200, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(tostring(myCode), "SWUI.Header",
            pw - 16, ph/2, Color(220, 240, 255, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    SWUI.FadeIn(infoPanel, 0.3, 0.03)

    y = y + 46

    -- ── Метка тира ────────────────────────────────────────────────────────────
    local lblTier = vgui.Create("DLabel", c)
    lblTier:SetPos(PAD, y)
    lblTier:SetSize(cW - PAD*2, 16)
    lblTier:SetText("ТИР ПОРТАЛА")
    lblTier:SetFont("SWUI.Tiny")
    lblTier:SetTextColor(SWUI.Colors.TextDim)
    SWUI.FadeIn(lblTier, 0.3, 0.06)

    y = y + 20

    -- ── Dropdown тира ─────────────────────────────────────────────────────────
    local selectedTier = tier
    local _, getTier = CreateTierDropdown(c, PAD, y, cW - PAD*2, tier, frame, function(idx)
        selectedTier = idx
    end)
    SWUI.FadeIn(c:GetChildren()[#c:GetChildren()], 0.3, 0.10)

    y = y + 46

    -- ── Предупреждение если портал открыт ────────────────────────────────────
    if isOpen then
        local warnPanel = vgui.Create("DPanel", c)
        warnPanel:SetPos(PAD, y)
        warnPanel:SetSize(cW - PAD*2, 28)
        warnPanel.Paint = function(self, pw, ph)
            draw.RoundedBox(4, 0, 0, pw, ph, Color(80, 30, 10, 200))
            surface.SetDrawColor(200, 80, 30, 150)
            surface.DrawOutlinedRect(0, 0, pw, ph, 1)
            draw.SimpleText("⚠  Портал открыт — изменения вступят в силу после закрытия", "SWUI.Tiny",
                pw/2, ph/2, Color(255, 180, 80, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        SWUI.FadeIn(warnPanel, 0.3, 0.12)
        y = y + 36
    end

    -- ── Разделитель ───────────────────────────────────────────────────────────
    local div1 = vgui.Create("DPanel", c)
    div1:SetPos(PAD, y)
    div1:SetSize(cW - PAD*2, 1)
    div1.Paint = function(self, dw, _)
        surface.SetDrawColor(26, 51, 72, 180)
        surface.DrawRect(0, 0, dw, 1)
    end
    SWUI.FadeIn(div1, 0.3, 0.14)

    y = y + 10

    -- ── Метка связи ───────────────────────────────────────────────────────────
    local lblLink = vgui.Create("DLabel", c)
    lblLink:SetPos(PAD, y)
    lblLink:SetSize(cW - PAD*2, 16)
    lblLink:SetText("КОД СВЯЗАННОГО ПОРТАЛА (того же тира)")
    lblLink:SetFont("SWUI.Tiny")
    lblLink:SetTextColor(SWUI.Colors.TextDim)
    SWUI.FadeIn(lblLink, 0.3, 0.16)

    y = y + 20

    -- ── Поле ввода кода ───────────────────────────────────────────────────────
    local teCode = StyledTextEntry(c, PAD, y, cW - PAD*2, 40, "Введите 3-значный код (напр. 314)...", frame)
    teCode:SetText(linkedCode)
    SWUI.FadeIn(teCode, 0.3, 0.18)

    y = y + 50

    -- ── Подсказка: ключ тира ─────────────────────────────────────────────────
    local lblKey = vgui.Create("DLabel", c)
    lblKey:SetPos(PAD, y)
    lblKey:SetSize(cW - PAD*2, 16)
    lblKey:SetFont("SWUI.Tiny")
    lblKey:SetTextColor(SWUI.Colors.TextDim)

    -- Обновлять подсказку при смене тира
    local function UpdateKeyHint(t)
        local kn = TIER_KEY_NAMES[t] or "?"
        lblKey:SetText("Игрокам нужен предмет:  " .. kn)
        lblKey:SetTextColor(TIER_COLORS[t] or SWUI.Colors.TextDim)
    end
    UpdateKeyHint(selectedTier)

    -- Переопределяем onSelect чтобы обновлять подсказку
    local origOnSelect
    origOnSelect = function(idx)
        selectedTier = idx
        UpdateKeyHint(idx)
    end
    -- Пересоздавать dropdown нельзя, поэтому просто храним callback в getTier
    -- getTier уже корректно обновляется внутри CreateTierDropdown через upvalue

    SWUI.FadeIn(lblKey, 0.3, 0.20)

    y = y + 22

    -- ── Разделитель ───────────────────────────────────────────────────────────
    local div2 = vgui.Create("DPanel", c)
    div2:SetPos(PAD, y)
    div2:SetSize(cW - PAD*2, 1)
    div2.Paint = function(self, dw, _)
        surface.SetDrawColor(26, 51, 72, 180)
        surface.DrawRect(0, 0, dw, 1)
    end
    SWUI.FadeIn(div2, 0.3, 0.22)

    y = y + 10

    -- ── Кнопка "Разорвать связь" ──────────────────────────────────────────────
    local btnUnlink = vgui.Create("DButton", c)
    btnUnlink:SetPos(PAD, y)
    btnUnlink:SetSize(cW - PAD*2, 32)
    btnUnlink:SetText("")
    btnUnlink._hov = 0

    btnUnlink.OnCursorEntered = function(self)
        local s = SysTime()
        local function anim()
            if not IsValid(self) then return end
            local t = math.min((SysTime()-s)/0.15, 1)
            self._hov = Lerp(SWUI.Animations.Easing.OutQuad(t), self._hov, 1)
            if t < 1 then timer.Simple(0, anim) end
        end
        timer.Simple(0, anim)
    end
    btnUnlink.OnCursorExited = function(self)
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

    btnUnlink.Paint = function(self, bw, bh)
        local r = 180 + self._hov * 50
        draw.RoundedBox(5, 0, 0, bw, bh, Color(r * 0.35, 15, 15, 200))
        surface.SetDrawColor(r, 40, 40, 120 + self._hov * 80)
        surface.DrawOutlinedRect(0, 0, bw, bh, 1)
        draw.SimpleText("✕  РАЗОРВАТЬ СВЯЗЬ", "SWUI.Tiny",
            bw/2, bh/2, Color(255, 100, 100, 200 + self._hov * 55), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    btnUnlink.DoClick = function()
        teCode:SetText("")
        net.Start("SWExpPortal_SaveSettings")
            net.WriteEntity(portal)
            net.WriteInt(getTier(), 8)
            net.WriteString("")
        net.SendToServer()
        if IsValid(frame) then frame:Close() end
    end
    SWUI.FadeIn(btnUnlink, 0.3, 0.24)

    y = y + 40

    -- ── Кнопки: [СОХРАНИТЬ] [ПРИМЕНИТЬ И ЗАКРЫТЬ] ────────────────────────────
    local function SendSettings()
        if not IsValid(portal) then
            if SWUI.Animations and SWUI.Animations.Presets then
                SWUI.Animations.Presets.Shake(frame, 5, 0.4)
            end
            return false
        end
        net.Start("SWExpPortal_SaveSettings")
            net.WriteEntity(portal)
            net.WriteInt(getTier(), 8)
            net.WriteString(string.Trim(teCode:GetValue()))
        net.SendToServer()
        return true
    end

    local btnW = (cW - PAD*2 - 12) / 2

    local btnSave = TierButton(c, PAD, y, btnW, 40, "СОХРАНИТЬ", frame, function()
        SendSettings()
    end)
    SWUI.FadeIn(btnSave, 0.3, 0.28)

    local btnApply = TierButton(c, PAD + btnW + 12, y, btnW, 40, "ПРИМЕНИТЬ И ЗАКРЫТЬ", frame, function()
        if SendSettings() then
            timer.Simple(0.12, function()
                if IsValid(frame) then frame:Close() end
            end)
        end
    end)
    SWUI.FadeIn(btnApply, 0.3, 0.32)
end

-- ============================================================================
-- ПОЛУЧИТЬ ЗАПРОС ОТ СЕРВЕРА — ОТКРЫТЬ МЕНЮ
-- ============================================================================

net.Receive("SWExpPortal_OpenAdminMenu", function()
    local portal     = net.ReadEntity()
    local tier       = net.ReadInt(8)
    local myCode     = net.ReadInt(32)
    local linkedCode = net.ReadString()
    local isOpen     = net.ReadBool()

    OpenPortalAdminMenu(portal, tier, myCode, linkedCode, isOpen)
end)

print("[SWExp] Клиентский модуль тировых порталов загружен.")
