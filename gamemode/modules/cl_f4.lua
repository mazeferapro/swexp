-- modules/chars/cl_f4.lua
-- F4 Меню — система персонажей
-- Полноэкранное меню на базе SWUI

if SERVER then return end

SWExp.F4 = SWExp.F4 or {}

local tChars   = {}
local nActive  = 0
local nCurrent = 1

-- ============================================================
-- Хелперы
-- ============================================================

local function IsEmpty(char) return char == nil or char._empty == true end

-- ============================================================
-- Открытие меню
-- ============================================================

function SWExp.F4:Open(tCharacters)
    if IsValid(self.Frame) then self.Frame:Remove() end

    tChars   = tCharacters or {}
    nCurrent = 1

    -- Найдём активного
    local localCallsign = LocalPlayer():GetNWString('swexp_callsign', '')
    nActive = 0
    for _, c in ipairs(tChars) do
        if c.callsign == localCallsign then nActive = tonumber(c.id) end
    end

    -- Пустой слот
    local slots = LocalPlayer().SWExp_CharSlots or 1
    if #tChars < slots then
        tChars[#tChars + 1] = { _empty = true }
    end

    local SW, SH = ScrW(), ScrH()

    -- ── Полноэкранный фрейм ──────────────────────────
    local frame = vgui.Create('DFrame')
    frame:SetSize(SW, SH)
    frame:SetPos(0, 0)
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame.Paint = function(s, fw, fh)
        -- Тёмный фон
        surface.SetDrawColor(SWUI.Colors.PanelBG)
        surface.DrawRect(0, 0, fw, fh)
    end
    self.Frame = frame

    -- ── Titlebar ─────────────────────────────────────
    local TBAR = 46
    local titlePnl = vgui.Create('DPanel', frame)
    titlePnl:SetPos(0, 0)
    titlePnl:SetSize(SW, TBAR)
    titlePnl.Paint = function(s, tw, th)
        SWUI.DrawRoundedRect(0, 0, tw, th, 0, SWUI.Colors.Panel2)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawRect(0, th - 1, tw, 1)
        -- Accent линия слева
        surface.SetDrawColor(SWUI.Colors.Accent)
        surface.DrawRect(0, th - 2, tw, 2)
    end

    SWUI.DrawText('ЭКСПЕДИЦИОННЫЙ ТЕРМИНАЛ', 'SWUI.Header', 24, TBAR / 2,
        SWUI.Colors.TextHi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- Subtext — текущий клон
    local lblSub = vgui.Create('DLabel', titlePnl)
    lblSub:SetPos(SW / 2 - 150, 0)
    lblSub:SetSize(300, TBAR)
    lblSub:SetFont('SWUI.Small')
    lblSub:SetTextColor(SWUI.Colors.TextDim)
    lblSub:SetContentAlignment(5)
    local function UpdateSub()
        local cn = LocalPlayer():GetNWString('swexp_clone_number', '')
        local cs = LocalPlayer():GetNWString('swexp_callsign', '')
        lblSub:SetText(cn ~= '' and (cn .. (cs ~= '' and '  ·  ' .. cs or '')) or '')
    end
    UpdateSub()

    -- Кнопка закрыть
    local btnClose = vgui.Create('DButton', titlePnl)
    btnClose:SetPos(SW - 36, 10)
    btnClose:SetSize(26, 26)
    btnClose:SetText('')
    btnClose.Paint = function(s, bw, bh)
        local hov = s:IsHovered()
        draw.RoundedBox(5, 0, 0, bw, bh, hov and Color(60, 16, 12) or Color(25, 25, 25))
        SWUI.DrawText('×', 'SWUI.Header', bw / 2, bh / 2,
            hov and SWUI.Colors.Red or Color(100, 100, 100),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btnClose.DoClick = function() frame:Remove() end

    -- ── Табы ─────────────────────────────────────────
    local TABBAR_H = 42
    local activeTab = 'chars'
    local tabPanels = {}

    local tabBar = vgui.Create('DPanel', frame)
    tabBar:SetPos(0, TBAR)
    tabBar:SetSize(SW, TABBAR_H)
    tabBar.Paint = function(s, tw, th)
        SWUI.DrawRoundedRect(0, 0, tw, th, 0, SWUI.Colors.Panel2)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawRect(0, th - 1, tw, 1)
    end

    local tabDefs = {
        { id = 'chars',    label = '🪖  ПЕРСОНАЖИ' },
        { id = 'settings', label = '⚙  НАСТРОЙКИ'  },
    }

    local function SwitchTab(id)
        activeTab = id
        for n, p in pairs(tabPanels) do p:SetVisible(n == id) end
    end

    local tabX = 0
    for _, td in ipairs(tabDefs) do
        local tid = td.id
        local btn = vgui.Create('DButton', tabBar)
        btn:SetPos(tabX, 0)
        btn:SetSize(180, TABBAR_H)
        btn:SetText('')
        btn.Paint = function(s, bw, bh)
            local on = activeTab == tid
            if on then
                surface.SetDrawColor(Color(0, 184, 255, 12))
                surface.DrawRect(0, 0, bw, bh)
                surface.SetDrawColor(SWUI.Colors.Accent)
                surface.DrawRect(0, bh - 2, bw, 2)
            end
            SWUI.DrawText(td.label, 'SWUI.Small', bw / 2, bh / 2,
                on and SWUI.Colors.Accent or (s:IsHovered() and SWUI.Colors.Text or SWUI.Colors.TextDim),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function() SwitchTab(tid) end
        tabX = tabX + 180
    end

    local CONTENT_Y = TBAR + TABBAR_H
    local CONTENT_H = SH - CONTENT_Y

    -- ============================================================
    -- ТАБ ПЕРСОНАЖИ
    -- ============================================================

    local panChars = vgui.Create('DPanel', frame)
    panChars:SetPos(0, CONTENT_Y)
    panChars:SetSize(SW, CONTENT_H)
    panChars.Paint = function(s, pw, ph)
        -- Тёмный фон с лёгким зеленоватым оттенком снизу (как в мокапе)
        SWUI.DrawRoundedRect(0, 0, pw, ph, 0, Color(6, 10, 16))

        -- Радиальный пол
        local cx = pw / 2
        for i = 80, 0, -1 do
            local r = i / 80
            surface.SetDrawColor(Color(0, 60, 100, math.floor((1 - r) * 20)))
            local rw = r * 300
            surface.DrawRect(cx - rw, ph - rw * 0.35, rw * 2, rw * 0.35)
        end

        -- Сетка пола
        surface.SetDrawColor(Color(0, 184, 255, 6))
        local gridH  = 140
        local gridY0 = ph - gridH
        local cell   = 44
        for gx = 0, pw, cell do
            surface.DrawLine(gx, gridY0, gx, ph)
        end
        for gy = gridY0, ph, math.floor(cell / 3) do
            surface.DrawLine(0, gy, pw, gy)
        end

        -- Градиент сверху
        for i = 0, 100 do
            local a = math.floor((1 - i / 100) * 200)
            surface.SetDrawColor(Color(6, 10, 16, a))
            surface.DrawRect(0, i, pw, 1)
        end

        -- Градиент снизу
        for i = 0, 130 do
            local a = math.floor((i / 130) * 220)
            surface.SetDrawColor(Color(6, 10, 16, a))
            surface.DrawRect(0, ph - 130 + i, pw, 1)
        end
    end
    tabPanels['chars'] = panChars

    -- ── Верхний оверлей: имя/ранг/статус ─────────────
    local overlayTop = vgui.Create('DPanel', panChars)
    overlayTop:SetPos(0, 0)
    overlayTop:SetSize(SW, 110)
    overlayTop.Paint = function() end

    local lblName = vgui.Create('DLabel', overlayTop)
    lblName:SetPos(44, 18)
    lblName:SetSize(SW / 2, 48)
    lblName:SetFont('SWUI.Title')
    lblName:SetTextColor(SWUI.Colors.TextHi)

    local lblRank = vgui.Create('DLabel', overlayTop)
    lblRank:SetPos(44, 66)
    lblRank:SetSize(SW / 2, 22)
    lblRank:SetFont('SWUI.Small')
    lblRank:SetTextColor(SWUI.Colors.TextDim)

    local lblNumber = vgui.Create('DLabel', overlayTop)
    lblNumber:SetPos(44, 87)
    lblNumber:SetSize(SW / 2, 18)
    lblNumber:SetFont('SWUI.Mono')
    lblNumber:SetTextColor(SWUI.Colors.TextDim)

    -- Статус-бейдж
    local badgePnl = vgui.Create('DPanel', overlayTop)
    badgePnl:SetPos(SW - 200, 20)
    badgePnl:SetSize(160, 32)
    local bActive = false
    badgePnl.Paint = function(s, bw, bh)
        local bc  = bActive and Color(0, 238, 119, 20)   or Color(255, 255, 255, 8)
        local brd = bActive and Color(0, 238, 119, 80)   or SWUI.Colors.Border
        local col = bActive and SWUI.Colors.Green         or SWUI.Colors.TextDim
        local txt = bActive and 'АКТИВЕН'                 or 'НЕ АКТИВЕН'
        draw.RoundedBox(16, 0, 0, bw, bh, bc)
        surface.SetDrawColor(brd)
        surface.DrawOutlinedRect(0, 0, bw, bh, 1)
        if bActive then
            local blink = 0.5 + math.abs(math.sin(CurTime() * 2.5)) * 0.5
            draw.RoundedBox(3, 12, bh / 2 - 3, 6, 6, Color(0, 238, 119, math.floor(blink * 255)))
        else
            draw.RoundedBox(3, 12, bh / 2 - 3, 6, 6, SWUI.Colors.TextDim)
        end
        SWUI.DrawText(txt, 'SWUI.Tiny', 26, bh / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- ── Модель игрока по центру (DModelPanel) ─────────────────
    local DEFAULT_MODEL = 'models/player/combine_super_soldier.mdl'

    local modelPnl = vgui.Create('DModelPanel', panChars)
    modelPnl:SetSize(320, 480)
    modelPnl:SetModel(DEFAULT_MODEL)
    modelPnl:SetFOV(45)
    modelPnl:SetAmbientLight(Color(40, 60, 80))
    modelPnl:SetDirectionalLight(BOX_FRONT,  Color(100, 180, 255))
    modelPnl:SetDirectionalLight(BOX_LEFT,   Color(20,  60,  100))
    modelPnl:SetDirectionalLight(BOX_BOTTOM, Color(10,  30,  50))

    function modelPnl:LayoutEntity(ent)
        ent:SetAngles(Angle(0, 180, 0))
    end

    modelPnl.Paint = function(s, mw, mh) end

    -- Пустой слот — заглушка
    local emptyPnl = vgui.Create('DPanel', panChars)
    emptyPnl:SetSize(200, 300)
    emptyPnl.Paint = function(s, cw, ch)
        SWUI.DrawRoundedRect(cw / 2 - 44, 30,  88, 64,  8, Color(20, 30, 40))
        SWUI.DrawRoundedRect(cw / 2 - 44, 100, 88, 85,  8, Color(20, 30, 40))
        SWUI.DrawRoundedRect(cw / 2 - 40, 190, 80, 78,  8, Color(20, 30, 40))
        SWUI.DrawText('+', 'SWUI.Title', cw / 2, ch / 2, SWUI.Colors.BorderHi,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    emptyPnl:SetVisible(false)

    local clonePnl = modelPnl

    -- ── Стрелки навигации ─────────────────────────────
    local function NavArrow(side)
        local btn = vgui.Create('DButton', panChars)
        btn:SetSize(52, 52)
        btn:SetText('')
        btn.Paint = function(s, bw, bh)
            local hov = s:IsHovered()
            draw.RoundedBox(26, 0, 0, bw, bh, Color(0, 0, 0, 140))
            surface.SetDrawColor(hov and SWUI.Colors.Accent or SWUI.Colors.BorderHi)
            surface.DrawOutlinedRect(0, 0, bw, bh, 1)
            SWUI.DrawText(side == 'l' and '◄' or '►', 'SWUI.Small', bw / 2, bh / 2,
                hov and SWUI.Colors.Accent or SWUI.Colors.TextDim,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        return btn
    end

    local navL = NavArrow('l')
    local navR = NavArrow('r')
    navL.DoClick = function() SWExp.F4:Navigate(-1) end
    navR.DoClick = function() SWExp.F4:Navigate(1) end

    -- ── Нижний оверлей: кнопки + точки ───────────────
    local overlayBot = vgui.Create('DPanel', panChars)
    overlayBot.Paint = function() end

    -- Точки-навигация
    local dotPnl = vgui.Create('DPanel', overlayBot)
    dotPnl.Paint = function() end
    local dots = {}

    local function RebuildDots()
        for _, d in ipairs(dots) do if IsValid(d) then d:Remove() end end
        dots = {}
        dotPnl:SetSize(#tChars * 26, 14)
        for i = 1, #tChars do
            local d = vgui.Create('DButton', dotPnl)
            d:SetPos((i - 1) * 26, 0)
            d:SetSize(14, 14)
            d:SetText('')
            local idx = i
            d.Paint = function(s, dw, dh)
                if i == nCurrent then
                    draw.RoundedBox(3, 0, dh / 2 - 3, 18, 6, SWUI.Colors.Accent)
                else
                    draw.RoundedBox(3, dw / 2 - 3, dh / 2 - 3, 6, 6, SWUI.Colors.BorderHi)
                end
            end
            d.DoClick = function() SWExp.F4:GoTo(idx) end
            dots[i] = d
        end
    end

    -- Ряд кнопок действий
    local btnRowPnl = vgui.Create('DPanel', overlayBot)
    btnRowPnl:SetSize(SW, 44)
    btnRowPnl.Paint = function() end

    -- ── Панель создания нового персонажа ──────────────
    local panCreate = vgui.Create('DPanel', panChars)
    panCreate:SetSize(400, 210)
    panCreate.Paint = function(s, cw, ch)
        SWUI.DrawRoundedRect(0, 0, cw, ch, 10, Color(11, 15, 21, 245))
        surface.SetDrawColor(SWUI.Colors.BorderHi)
        surface.DrawOutlinedRect(0, 0, cw, ch, 1)
        SWUI.DrawText('НОВЫЙ ПЕРСОНАЖ', 'SWUI.Tiny', cw / 2, 16,
            SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    panCreate:SetVisible(false)

    local inpNumber   = SWUI.CreateInput(panCreate, 20, 36,  360, 38, 'Номер (CT-XXXX)')
    local inpCallsign = SWUI.CreateInput(panCreate, 20, 86,  360, 38, 'Позывной (ПРИЗРАК)')

    local lblErr = vgui.Create('DLabel', panCreate)
    lblErr:SetPos(20, 132)
    lblErr:SetSize(360, 18)
    lblErr:SetFont('SWUI.Tiny')
    lblErr:SetTextColor(SWUI.Colors.Red)
    lblErr:SetText('')

    SWUI.CreateButton(panCreate, 'СОЗДАТЬ', 20, 158, 160, 36, 'accent', function()
        local num = string.upper(string.Trim(inpNumber:GetValue()))
        local cs  = string.upper(string.Trim(inpCallsign:GetValue()))
        if num == '' or cs == '' then lblErr:SetText('Заполните все поля') return end
        netstream.Start('SWExp::CreateChar', { clone_number = num, callsign = cs })
        panCreate:SetVisible(false)
    end)

    SWUI.CreateButton(panCreate, 'ОТМЕНА', 192, 158, 120, 36, 'ghost', function()
        panCreate:SetVisible(false)
    end)

    -- ── Главная функция обновления UI ─────────────────
    function SWExp.F4:UpdateUI()
        local char = tChars[nCurrent]

        -- Позиции
        -- Центрируем модель
        modelPnl:SetPos(SW / 2 - 160, CONTENT_H / 2 - 240)
        emptyPnl:SetPos(SW / 2 - 100, CONTENT_H / 2 - 150)

        local char = tChars[nCurrent]
        if IsEmpty(char) then
            modelPnl:SetVisible(false)
            emptyPnl:SetVisible(true)
        else
            modelPnl:SetVisible(true)
            emptyPnl:SetVisible(false)
            -- Модель берём прямо из таблицы персонажа (сервер уложил её туда)
            local mdl = char.model or DEFAULT_MODEL
            if modelPnl:GetModel() ~= mdl then
                modelPnl:SetModel(mdl)
            end
        end
        navL:SetPos(36, CONTENT_H / 2 - 26)
        navR:SetPos(SW - 88, CONTENT_H / 2 - 26)

        overlayBot:SetPos(0, CONTENT_H - 120)
        overlayBot:SetSize(SW, 120)
        btnRowPnl:SetPos(0, 10)

        RebuildDots()
        dotPnl:SetPos(SW / 2 - #tChars * 13, 74)

        -- Чистим кнопки
        for _, c in ipairs(btnRowPnl:GetChildren()) do c:Remove() end

        if IsEmpty(char) then
            lblName:SetText('+ НОВЫЙ КЛОН')
            lblRank:SetText('')
            lblNumber:SetText('— — —')
            bActive = false
            panCreate:SetPos(SW / 2 - 200, CONTENT_H / 2 - 105)
            panCreate:SetVisible(true)
        else
            panCreate:SetVisible(false)
            lblName:SetText(char.callsign or '???')
            lblRank:SetText(char['rank'] or 'CT')
            lblNumber:SetText(char.clone_number or '')
            bActive = (tonumber(char.id) == nActive)

            -- Кнопки по центру
            local btnW   = 150
            local gap    = 12
            local count  = bActive and 2 or 3
            local totalW = count * btnW + (count - 1) * gap
            local startX = SW / 2 - totalW / 2

            if bActive then
                SWUI.CreateButton(btnRowPnl, '● ИГРАЮ СЕЙЧАС', startX, 0, btnW + 30, 44, 'ghost')
                local b2 = SWUI.CreateButton(btnRowPnl, 'ПЕРЕИМЕНОВАТЬ',
                    startX + btnW + 30 + gap, 0, btnW, 44, 'ghost')
                b2.DoClick = function()
                    Derma_StringRequest('Изменение позывного', 'Новый позывной:', char.callsign or '',
                        function(v) if v and v ~= '' then
                            netstream.Start('SWExp::RenameChar', tonumber(char.id), v)
                        end end)
                end
            else
                local b1 = SWUI.CreateButton(btnRowPnl, 'ВЫБРАТЬ', startX, 0, btnW, 44, 'accent')
                b1.DoClick = function()
                    netstream.Start('SWExp::ChooseChar', tonumber(char.id))
                    frame:Remove()
                end

                local b2 = SWUI.CreateButton(btnRowPnl, 'ПЕРЕИМЕНОВАТЬ',
                    startX + btnW + gap, 0, btnW, 44, 'ghost')
                b2.DoClick = function()
                    Derma_StringRequest('Изменение позывного', 'Новый позывной:', char.callsign or '',
                        function(v) if v and v ~= '' then
                            netstream.Start('SWExp::RenameChar', tonumber(char.id), v)
                        end end)
                end

                local b3 = SWUI.CreateButton(btnRowPnl, 'УДАЛИТЬ',
                    startX + (btnW + gap) * 2, 0, btnW, 44, 'danger')
                b3.DoClick = function()
                    Derma_Query('Удалить ' .. (char.callsign or '') .. '?', 'Подтверждение',
                        'Удалить', function()
                            netstream.Start('SWExp::DeleteChar', tonumber(char.id))
                        end,
                        'Отмена', function() end)
                end
            end
        end
    end

    -- ── Навигация ─────────────────────────────────────
    function SWExp.F4:Navigate(dir)
        self:GoTo(((nCurrent - 1 + dir) % #tChars) + 1)
    end

    function SWExp.F4:GoTo(idx)
        nCurrent = math.Clamp(idx, 1, math.max(1, #tChars))
        self:UpdateUI()
    end

    self:UpdateUI()

    -- ============================================================
    -- ТАБ НАСТРОЙКИ
    -- ============================================================

    local panSettings = vgui.Create('DPanel', frame)
    panSettings:SetPos(0, CONTENT_Y)
    panSettings:SetSize(SW, CONTENT_H)
    panSettings:SetVisible(false)
    panSettings.Paint = function(s, pw, ph)
        SWUI.DrawRoundedRect(0, 0, pw, ph, 0, SWUI.Colors.PanelBG)
    end
    tabPanels['settings'] = panSettings

    local scroll = SWUI.CreateScrollList(panSettings, SW / 2 - 300, 32, 600, CONTENT_H - 64)

    local function SettGroup(text)
        local lbl = vgui.Create('DLabel', scroll)
        lbl:Dock(TOP)
        lbl:DockMargin(0, 14, 0, 6)
        lbl:SetTall(18)
        lbl:SetFont('SWUI.Tiny')
        lbl:SetTextColor(SWUI.Colors.TextDim)
        lbl:SetText(string.upper(text))
    end

    local function SettRow(label, desc)
        local row = vgui.Create('DPanel', scroll)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 4)
        row:SetTall(desc and 60 or 46)
        row.Paint = function(s, rw, rh)
            SWUI.DrawRoundedRect(0, 0, rw, rh, 8, Color(0, 0, 0, 60))
            surface.SetDrawColor(SWUI.Colors.Border)
            surface.DrawOutlinedRect(0, 0, rw, rh, 1)
        end

        local lbl = vgui.Create('DLabel', row)
        lbl:SetPos(16, desc and 10 or 13)
        lbl:SetSize(440, 20)
        lbl:SetFont('SWUI.Body')
        lbl:SetTextColor(SWUI.Colors.Text)
        lbl:SetText(label)

        if desc then
            local sub = vgui.Create('DLabel', row)
            sub:SetPos(16, 32)
            sub:SetSize(440, 16)
            sub:SetFont('SWUI.Tiny')
            sub:SetTextColor(SWUI.Colors.TextDim)
            sub:SetText(desc)
        end

        local tog = vgui.Create('DCheckBox', row)
        tog:SetPos(row:GetWide() - 52, row:GetTall() / 2 - 11)
        tog:SetSize(38, 22)
        tog:SetValue(true)
        tog.Paint = function(s, tw, th)
            local on = s:GetChecked()
            draw.RoundedBox(11, 0, 0, tw, th, on and SWUI.Colors.AccentDim or Color(255, 255, 255, 20))
            surface.SetDrawColor(on and SWUI.Colors.Accent or SWUI.Colors.Border)
            surface.DrawOutlinedRect(0, 0, tw, th, 1)
            draw.RoundedBox(8, on and tw - 19 or 2, 3, 16, 16,
                on and SWUI.Colors.Accent or Color(80, 80, 80))
        end
        return row
    end

    SettGroup('Звук')
    SettRow('Звуки интерфейса', 'Звуки при открытии меню и взаимодействии')
    SettRow('Громкость геймода')

    SettGroup('HUD')
    SettRow('Показывать компас')
    SettRow('Показывать подсказки сканирования', 'Текст мыслей клона над объектами')

    SettGroup('Прочее')
    SettRow('Уведомления об уровне прогресса')

    SwitchTab('chars')
end

-- ============================================================
-- Refresh
-- ============================================================

function SWExp.F4:Refresh(tNew)
    tChars = tNew or {}
    local slots = LocalPlayer().SWExp_CharSlots or 1
    if #tChars < slots then tChars[#tChars + 1] = { _empty = true } end
    nCurrent = math.Clamp(nCurrent, 1, math.max(1, #tChars))
    if IsValid(self.Frame) then self:UpdateUI() else self:Open(tNew) end
end

-- ============================================================
-- Netstream
-- ============================================================

netstream.Hook('SWExp::OpenCharSelect', function(t)
    if IsValid(SWExp.F4.Frame) then SWExp.F4:Refresh(t) else SWExp.F4:Open(t) end
end)

netstream.Hook('SWExp::CharSelected', function()
    if IsValid(SWExp.F4.Frame) then SWExp.F4.Frame:Remove() end
end)

netstream.Hook('SWExp::CharError', function(msg)
    notification.AddLegacy('Ошибка: ' .. (msg or ''), NOTIFY_ERROR, 4)
end)

-- ============================================================
-- F4
-- ============================================================

hook.Add('PlayerButtonDown', 'SWExp::F4Key', function(ply, btn)
    if btn ~= KEY_F4 then return end
    if IsValid(SWExp.F4.Frame) then SWExp.F4.Frame:Remove() return end
    netstream.Start('SWExp::RequestChars')
end)