-- ============================================================
-- Star Wars: Expedition — Шкаф (клиент)
-- modules/cl_wardrobe.lua
-- ============================================================

if SERVER then return end

SWExp.Wardrobe        = SWExp.Wardrobe or {}
SWExp.Wardrobe._frame = nil

local function InverseLerp(pos, p1, p2)
    local range = p2 - p1
    if range == 0 then return 1 end
    return (pos - p1) / range
end

-- ============================================================
-- ОТКРЫТИЕ ОКНА
-- ============================================================

function SWExp.Wardrobe.OpenUI(data)
    if IsValid(SWExp.Wardrobe._frame) then
        SWExp.Wardrobe._frame:Close()
        SWExp.Wardrobe._frame = nil
        return
    end

    -- ── Размеры ────────────────────────────────────────────
    local W       = 1060
    local H       = 660
    local MODEL_W = 620
    local PANEL_W = W - MODEL_W
    local CH      = H - 44        -- высота content (после titlebar)
    local PAD     = 10

    -- ── Рабочие данные ─────────────────────────────────────
    local currentData = {
        skin       = tonumber(data.skin) or 0,
        bodygroups = {},
    }
    if istable(data.bodygroups) then
        for k, v in pairs(data.bodygroups) do
            currentData.bodygroups[tonumber(k)] = tonumber(v)
        end
    end

    -- ============================================================
    -- ОКНО
    -- ============================================================
    local frame, content = SWUI.Animated.CreateWindow('ВНЕШНИЙ ВИД', W, H, nil, SWUI.Colors.Accent)
    SWExp.Wardrobe._frame = frame

    local origClose = frame.Close
    frame.Close = function(self)
        SWExp.Wardrobe._frame = nil
        origClose(self)
    end

    -- ============================================================
    -- ЛЕВАЯ ЧАСТЬ: 3D-просмотр модели
    -- Важно: НЕ переопределяем Paint у DModelPanel — иначе рендер
    -- 3D-модели блокируется. Подсказки рисуем отдельной панелью.
    -- ============================================================
    local modelPanel = vgui.Create('DModelPanel', content)
    modelPanel:SetPos(0, 0)
    modelPanel:SetSize(MODEL_W, CH)
    modelPanel:SetModel(data.model or LocalPlayer():GetModel())

    -- Тонкий фон-разделитель поверх модели (не блокирует 3D-рендер)
    local modelOverlay = vgui.Create('DPanel', content)
    modelOverlay:SetPos(0, 0)
    modelOverlay:SetSize(MODEL_W, CH)
    modelOverlay:SetMouseInputEnabled(false)
    -- Короткое имя модели для отображения
    local modelArgs     = string.Split(data.model or '', '/')
    local modelShortName = string.upper(string.sub(modelArgs[#modelArgs] or 'неизвестно', 1, -5))

    modelOverlay.Paint = function(s, w, h)
        -- Вертикальный разделитель
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawRect(w - 1, 0, 1, h)
        -- Текущая модель (для какой сохраняем)
        SWUI.DrawText(
            'МОДЕЛЬ: ' .. modelShortName,
            'SWUI.Small',
            w / 2, h - 52,
            SWUI.Colors.Accent,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
        -- Подсказка
        SWUI.DrawText(
            'Настройки сохраняются отдельно для каждой модели',
            'SWUI.Small',
            w / 2, h - 34,
            SWUI.Colors.TextDim,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
        -- Управление
        SWUI.DrawText(
            'ЛКМ — вращение    ПКМ — смещение    Колесо — зум',
            'SWUI.Small',
            w / 2, h - 16,
            Color(SWUI.Colors.TextDim.r, SWUI.Colors.TextDim.g, SWUI.Colors.TextDim.b, 140),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
    end

    -- Применяем сохранённые значения к превью
    timer.Simple(0, function()
        if not IsValid(modelPanel) then return end
        modelPanel.Entity:SetSkin(currentData.skin)
        for k, v in pairs(currentData.bodygroups) do
            modelPanel.Entity:SetBodygroup(k, v)
        end
    end)

    -- Камера
    modelPanel:SetLookAt(Vector(0, 0, 56))
    modelPanel:SetCamPos(Vector(80, 0, 56))
    modelPanel:SetFOV(22)

    modelPanel.rot       = 180
    modelPanel.fov       = 22
    modelPanel.dragging  = false
    modelPanel.dragging2 = false
    modelPanel.ux = 0; modelPanel.uy = 0
    modelPanel.xmod = 0; modelPanel.ymod = 0

    function modelPanel:LayoutEntity(ent)
        local newrot = self.rot
        local newfov = self.fov

        if self.dragging then
            newrot = self.rot + (gui.MouseX() - self.ux) * 0.4
            newfov = math.Clamp(self.fov - (gui.MouseY() - self.uy) * 0.07, 8, 75)
        end

        local nxm = self.xmod
        local nym = self.ymod
        if self.dragging2 then
            nxm = math.Clamp(self.xmod + (self.ux - gui.MouseX()) * 0.02, -20, 20)
            nym = math.Clamp(self.ymod + (self.uy - gui.MouseY()) * 0.02, -20, 20)
        end

        ent:SetAngles(Angle(0, 0, 0))
        self:SetFOV(newfov)

        local h    = 56
        local frac = InverseLerp(newfov, 75, 8)
        h = Lerp(frac, 56, 68)

        local norm = (self:GetCamPos() - Vector(0, 0, h))
        norm:Normalize()
        local la = norm:Angle()

        local offset = Vector(0, 0, nym * 2 * (1 - frac)) + la:Right() * nxm * 2 * (1 - frac)
        self:SetLookAt(Vector(0, 0, h) - offset)
        self:SetCamPos(
            Vector(
                80 * math.sin(newrot * (math.pi / 180)),
                80 * math.cos(newrot * (math.pi / 180)),
                h + 4 * (1 - frac)
            ) - offset
        )
    end

    function modelPanel:OnMousePressed(k)
        self.ux = gui.MouseX(); self.uy = gui.MouseY()
        self.dragging  = (k == MOUSE_LEFT)
        self.dragging2 = (k == MOUSE_RIGHT)
    end

    function modelPanel:OnMouseReleased(k)
        if self.dragging then
            self.rot = self.rot + (gui.MouseX() - self.ux) * 0.4
            self.fov = math.Clamp(self.fov - (gui.MouseY() - self.uy) * 0.07, 8, 75)
        end
        if self.dragging2 then
            self.xmod = math.Clamp(self.xmod + (self.ux - gui.MouseX()) * 0.02, -20, 20)
            self.ymod = math.Clamp(self.ymod + (self.uy - gui.MouseY()) * 0.02, -20, 20)
        end
        self.dragging = false; self.dragging2 = false
    end

    function modelPanel:OnCursorExited()
        if self.dragging or self.dragging2 then
            self:OnMouseReleased(MOUSE_LEFT)
        end
    end

    function modelPanel:OnMouseWheeled(delta)
        self.fov = math.Clamp(self.fov - delta * 2, 8, 75)
    end

    -- ============================================================
    -- ПРАВАЯ ЧАСТЬ: настройки
    -- ============================================================
    local rightPanel = vgui.Create('DPanel', content)
    rightPanel:SetPos(MODEL_W, 0)
    rightPanel:SetSize(PANEL_W, CH)
    rightPanel.Paint = function(s, w, h)
        SWUI.DrawRoundedRect(0, 0, w, h, 0, SWUI.Colors.Panel2)
    end

    -- Кнопка сохранения (внизу)
    local BTN_H   = 48
    SWUI.CreateButton(
        rightPanel,
        'СОХРАНИТЬ ВНЕШНИЙ ВИД',
        PAD, CH - BTN_H - PAD,
        PANEL_W - PAD * 2, BTN_H,
        'accent',
        function()
            netstream.Start('SWExp::SaveBodygroups', {
                skin       = currentData.skin,
                bodygroups = currentData.bodygroups,
            })
            SWUI.PlaySound(SWUI.Sounds.Success)
            timer.Simple(0.2, function()
                if IsValid(frame) then frame:Close() end
            end)
        end
    )

    -- Скролл-панель
    local SCROLL_H = CH - BTN_H - PAD * 3
    local scroll   = vgui.Create('DScrollPanel', rightPanel)
    scroll:SetPos(PAD, PAD)
    scroll:SetSize(PANEL_W - PAD * 2, SCROLL_H)

    local vbar = scroll:GetVBar()
    vbar.Paint = function(s, w, h)
        SWUI.DrawRoundedRect(0, 0, w, h, 3, Color(8, 12, 18))
    end
    vbar.btnUp.Paint   = function() end
    vbar.btnDown.Paint = function() end
    vbar.btnGrip.Paint = function(s, w, h)
        SWUI.DrawRoundedRect(2, 0, w - 4, h, 3, SWUI.Colors.AccentDim)
    end

    local inner  = vgui.Create('DPanel', scroll)
    local innerW = PANEL_W - PAD * 2 - 12
    inner:SetWide(innerW)
    inner.Paint = function() end

    local innerY = 6

    -- ── Хелпер: заголовок секции ──────────────────────────
    local function AddSectionHeader(text)
        local hdr = vgui.Create('DPanel', inner)
        hdr:SetPos(0, innerY)
        hdr:SetSize(innerW, 34)
        hdr.Paint = function(s, w, h)
            SWUI.DrawText(string.upper(text), 'SWUI.Body', 6, h / 2,
                SWUI.Colors.Accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            surface.SetDrawColor(SWUI.Colors.AccentDim)
            surface.DrawRect(0, h - 1, w, 1)
        end
        innerY = innerY + 38
    end

    -- ── Хелпер: ряд пронумерованных кнопок ───────────────
    --   label    — название бодигруппы
    --   count    — число вариантов
    --   selected — текущий активный индекс (0-based)
    --   onChange — callback(newIndex)
    local function AddGroupRow(label, count, selected, onChange)
        -- Название группы
        local lbl = vgui.Create('DPanel', inner)
        lbl:SetPos(4, innerY)
        lbl:SetSize(innerW - 4, 24)
        lbl.Paint = function(s, w, h)
            SWUI.DrawText(label, 'SWUI.Small', 0, h / 2,
                SWUI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        innerY = innerY + 26

        -- Кнопки: максимум 10 в ряд, квадратные
        local COLS   = math.min(count, 10)
        local btnW   = math.floor((innerW - 4) / COLS) - 1
        local btnH   = math.max(btnW, 32)  -- квадратные, минимум 32px
        local ROWS   = math.ceil(count / COLS)
        local buttons = {}

        for i = 0, count - 1 do
            local col = i % COLS
            local row = math.floor(i / COLS)

            local btn = vgui.Create('DButton', inner)
            btn:SetPos(4 + col * (btnW + 1), innerY + row * (btnH + 2))
            btn:SetSize(btnW, btnH)
            btn:SetText('')
            btn._selected = (i == selected)
            btn._hov      = 0

            btn.OnCursorEntered = function(self)
                SWUI.PlaySound(SWUI.Sounds.Hover, SWUI.SoundVolume * 0.3)
                local st, sa = SysTime(), self._hov
                local function tick()
                    if not IsValid(self) then return end
                    local p = math.min((SysTime() - st) / 0.12, 1)
                    self._hov = Lerp(SWUI.Animations.Easing.OutQuad(p), sa, 1)
                    if p < 1 then timer.Simple(0, tick) end
                end
                timer.Simple(0, tick)
            end

            btn.OnCursorExited = function(self)
                local st, sa = SysTime(), self._hov
                local function tick()
                    if not IsValid(self) then return end
                    local p = math.min((SysTime() - st) / 0.18, 1)
                    self._hov = Lerp(SWUI.Animations.Easing.OutQuad(p), sa, 0)
                    if p < 1 then timer.Simple(0, tick) end
                end
                timer.Simple(0, tick)
            end

            btn.Paint = function(self, bw, bh)
                local sel = self._selected
                local hov = self._hov

                local bg
                if sel then
                    bg = Color(0, 65, 105, 230)
                else
                    bg = Color(
                        math.floor(hov * 10),
                        math.floor(hov * 40),
                        math.floor(hov * 65),
                        150 + math.floor(hov * 50)
                    )
                end
                SWUI.DrawRoundedRect(0, 0, bw, bh, 5, bg)

                local brd = sel and SWUI.Colors.Accent
                    or (hov > 0.4 and SWUI.Colors.BorderHi or SWUI.Colors.Border)
                surface.SetDrawColor(brd)
                surface.DrawOutlinedRect(0, 0, bw, bh, 1)

                -- Отображаем 1-based номер (1, 2, 3 ... n)
                local tc = sel and SWUI.Colors.Accent or SWUI.Colors.TextHi
                SWUI.DrawText(tostring(i + 1), 'SWUI.Body', bw / 2, bh / 2,
                    tc, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            local capturedI = i
            btn.DoClick = function(self)
                for _, other in ipairs(buttons) do
                    if IsValid(other) then other._selected = false end
                end
                self._selected = true
                SWUI.PlaySound(SWUI.Sounds.Select)
                if onChange then onChange(capturedI) end
            end

            table.insert(buttons, btn)
        end

        innerY = innerY + ROWS * (btnH + 2) + 10
    end

    -- ============================================================
    -- ЗАПОЛНЕНИЕ ПРАВОЙ ПАНЕЛИ (ждём создания entity в modelPanel)
    -- ============================================================
    timer.Simple(0, function()
        if not IsValid(modelPanel) or not IsValid(inner) then return end

        local ent        = modelPanel.Entity
        local skinCount  = ent:SkinCount()
        local hasContent = false

        -- ── СКИНЫ ─────────────────────────────────────────
        if skinCount > 1 then
            hasContent = true
            AddSectionHeader('Скины')
            AddGroupRow('Вариант скина', skinCount, currentData.skin, function(i)
                currentData.skin = i
                if IsValid(modelPanel) then modelPanel.Entity:SetSkin(i) end
            end)
        end

        -- ── БОДИГРУППЫ ────────────────────────────────────
        local bgs = {}
        for _, bg in pairs(ent:GetBodyGroups()) do
            if bg.num > 1 then table.insert(bgs, bg) end
        end
        table.sort(bgs, function(a, b) return a.id < b.id end)

        if #bgs > 0 then
            hasContent = true
            AddSectionHeader('Бодигруппы')

            for _, bg in ipairs(bgs) do
                local bgName = (bg.name and bg.name ~= '') and bg.name or ('Группа ' .. bg.id)
                local selSub = currentData.bodygroups[bg.id] or 0
                local capturedBG = bg

                AddGroupRow(bgName, bg.num, selSub, function(i)
                    currentData.bodygroups[capturedBG.id] = i
                    if IsValid(modelPanel) then
                        modelPanel.Entity:SetBodygroup(capturedBG.id, i)
                    end
                end)
            end
        end

        if not hasContent then
            local noData = vgui.Create('DPanel', inner)
            noData:SetPos(0, innerY)
            noData:SetSize(innerW, 50)
            noData.Paint = function(s, w, h)
                SWUI.DrawText('У текущей модели нет настроек', 'SWUI.Body',
                    w / 2, h / 2, SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            innerY = innerY + 54
        end

        inner:SetTall(innerY + 8)

        rightPanel:SetAlpha(0)
        SWUI.FadeIn(rightPanel, 0.35, 0.1)
    end)
end

-- ============================================================
-- NETSTREAM
-- ============================================================

netstream.Hook('SWExp::OpenWardrobeUI', function(data)
    if not istable(data) then return end
    SWExp.Wardrobe.OpenUI(data)
end)

netstream.Hook('SWExp::WardrobeError', function(msg)
    chat.AddText(Color(255, 80, 80), '[Шкаф] ', Color(255, 255, 255), tostring(msg))
end)

MsgC(Color(190, 252, 3), '[ SWExp ]', color_white, ' Шкаф (клиент) загружен.\n')
