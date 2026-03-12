-- modules/cl_f4.lua
-- F4 Меню — выбор персонажа SWExp
-- ПЕРЕДЕЛАНО: добавлен splash screen, блокировка выхода, кнопка disconnect

if SERVER then return end

SWExp.F4 = SWExp.F4 or {}

local tChars   = {}
local nCurrent = 1
local nActive  = 0
local hasShownSplash = false

local DEFAULT_MODEL = 'models/player/combine_super_soldier.mdl'

local function IsEmpty(c) return c == nil or c._empty == true end
local function GetSlots() return LocalPlayer():GetNWInt('swexp_char_slots', 3) end

-- ============================================================
-- Загрузка настроек из cookie
-- ============================================================

-- Звуки интерфейса (по умолчанию включены)
SWUI.SoundEnabled = cookie.GetString('swexp_ui_sounds', '1') == '1'

-- Патчим SWUI.PlaySound чтобы учитывать настройку
if SWUI and SWUI.PlaySound then
    local _OriginalPlaySound = SWUI.PlaySound
    SWUI.PlaySound = function(snd, vol)
        if SWUI.SoundEnabled then
            _OriginalPlaySound(snd, vol)
        end
    end
end

-- Компас (по умолчанию включён)
hook.Add('HUDPaint', 'SWExp::CompassToggle', function()
    -- Этот хук блокирует отрисовку компаса если настройка выключена
    -- Компас рисуется в DrawCompass() в cl_hud.lua
end)

-- Переменная для проверки в DrawCompass
function SWExp.IsCompassEnabled()
    return cookie.GetString('swexp_show_compass', '1') == '1'
end

-- ============================================================
-- SPLASH SCREEN при первом входе
-- ============================================================

function SWExp.F4:ShowSplash(onContinue)
    local splash = vgui.Create('DPanel')
    splash:SetSize(ScrW(), ScrH())
    splash:SetPos(0, 0)
    splash:MakePopup()
    splash:SetKeyboardInputEnabled(true)
    splash:SetAlpha(0)
    
    splash.Paint = function(s, w, h)
        surface.SetDrawColor(6, 10, 16, 255)
        surface.DrawRect(0, 0, w, h)
        
        SWUI.DrawText('STAR WARS: EXPEDITION', 'SWUI.MonoLarge', w / 2, h / 2 - 60, 
            SWUI.Colors.Accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        local pulse = math.abs(math.sin(CurTime() * 2))
        local alpha = 120 + (pulse * 135)
        local col = Color(SWUI.Colors.TextHi.r, SWUI.Colors.TextHi.g, SWUI.Colors.TextHi.b, alpha)
        SWUI.DrawText('НАЖМИТЕ ENTER ДЛЯ ПРОДОЛЖЕНИЯ', 'SWUI.Body', w / 2, h / 2 + 40, 
            col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    splash.OnKeyCodePressed = function(s, key)
        if key == KEY_ENTER then
            surface.PlaySound('UI/buttonclick.wav')
            s:AlphaTo(0, 0.5, 0, function()
                s:Remove()
                if onContinue then onContinue() end
            end)
        end
    end
    
    splash:AlphaTo(255, 0.6, 0)
end

-- ============================================================
-- Открытие меню
-- ============================================================

function SWExp.F4:Open(tCharacters)
    if IsValid(self.Frame) then self.Frame:Remove() end

    tChars   = tCharacters or {}
    nCurrent = 1

    -- определяем активного по позывному
    local localCS = LocalPlayer():GetNWString('swexp_callsign', '')
    nActive = 0
    for _, c in ipairs(tChars) do
        if c.callsign == localCS then nActive = tonumber(c.id) end
    end

    -- добавляем пустой слот если есть место
    if #tChars < GetSlots() then
        tChars[#tChars + 1] = { _empty = true }
    end

    local SW, SH = ScrW(), ScrH()
    local CW, CH = SW, SH

    local frame = vgui.Create('DFrame')
    frame:SetSize(SW, SH)
    frame:SetPos(0, 0)
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame.Paint = function(s, fw, fh)
        surface.SetDrawColor(6, 10, 16, 255)
        surface.DrawRect(0, 0, fw, fh)
    end
    self.Frame = frame

    local TBAR = 46
    local titlePnl = vgui.Create('DPanel', frame)
    titlePnl:SetPos(0, 0)
    titlePnl:SetSize(SW, TBAR)
    titlePnl.Paint = function(s, tw, th)
        SWUI.DrawRoundedRect(0, 0, tw, th, 0, SWUI.Colors.Panel2)
        surface.SetDrawColor(SWUI.Colors.Accent.r, SWUI.Colors.Accent.g, SWUI.Colors.Accent.b, 255)
        surface.DrawRect(0, th - 2, tw, 2)
        SWUI.DrawText('ТЕРМИНАЛ ПЕРСОНАЖЕЙ', 'SWUI.Header', 24, th/2,
            SWUI.Colors.TextHi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- Если персонаж НЕ выбран - добавляем кнопку disconnect, НЕ добавляем ×
    if nActive == 0 then
        -- Кнопка "ВЫЙТИ С СЕРВЕРА"
        local btnDC = vgui.Create('DButton', titlePnl)
        btnDC:SetPos(SW - 220, 7)
        btnDC:SetSize(200, 30)
        btnDC:SetText('')
        btnDC.Paint = function(s, w, h)
            local hov = s:IsHovered()
            draw.RoundedBox(6, 0, 0, w, h, hov and Color(140, 30, 30) or Color(100, 20, 20))
            surface.SetDrawColor(SWUI.Colors.Red)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            SWUI.DrawText('ВЫЙТИ С СЕРВЕРА', 'SWUI.Small', w/2, h/2, SWUI.Colors.TextHi, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btnDC.DoClick = function()
            LocalPlayer():ConCommand('disconnect')
        end
    else
        -- Если выбран - добавляем кнопку ×
        SWUI.CreateButton(titlePnl, '×', SW - 44, 7, 30, 30, 'ghost', function()
            frame:Remove()
        end)
    end

    local content = vgui.Create('DPanel', frame)
    content:SetPos(0, TBAR)
    content:SetSize(SW, SH - TBAR)
    content.Paint = function() end

    local panels = {}

    SWUI.CreateTabBar(content, {
        { id = 'chars',    label = 'ПЕРСОНАЖИ' },
        { id = 'settings', label = 'НАСТРОЙКИ'  },
    }, 0, 0, CW, 38, function(id)
        for tid, pnl in pairs(panels) do pnl:SetVisible(tid == id) end
    end)

    local TAB_Y  = 38
    local BODY_H = SH - TBAR - TAB_Y

    local function MakeTab(visible)
        local p = vgui.Create('DPanel', content)
        p:SetPos(0, TAB_Y)
        p:SetSize(CW, BODY_H)
        p.Paint = function(s, pw, ph)
            surface.SetDrawColor(6, 10, 16, 255)
            surface.DrawRect(0, 0, pw, ph)
        end
        p:SetVisible(visible or false)
        return p
    end

    -- ============================================================
    -- ТАБ ПЕРСОНАЖИ
    -- ============================================================

    local panChars = MakeTab(true)
    panels['chars'] = panChars

    -- ── Лейблы сверху слева ──────────────────────────────────
    local lblName = vgui.Create('DLabel', panChars)
    lblName:SetPos(24, 18)
    lblName:SetSize(500, 40)
    lblName:SetFont('SWUI.Title')
    lblName:SetTextColor(SWUI.Colors.TextHi)
    lblName:SetText('')

    local lblRank = vgui.Create('DLabel', panChars)
    lblRank:SetPos(24, 58)
    lblRank:SetSize(300, 20)
    lblRank:SetFont('SWUI.Small')
    lblRank:SetTextColor(SWUI.Colors.TextDim)
    lblRank:SetText('')

    local lblNumber = vgui.Create('DLabel', panChars)
    lblNumber:SetPos(24, 78)
    lblNumber:SetSize(300, 18)
    lblNumber:SetFont('SWUI.Mono')
    lblNumber:SetTextColor(SWUI.Colors.TextDim)
    lblNumber:SetText('')

    -- ── Статус-бейдж ─────────────────────────────────────────
    local bActive = false
    local badgePnl = vgui.Create('DPanel', panChars)
    badgePnl:SetSize(160, 30)
    badgePnl.Paint = function(s, w, h)
        local col = bActive and SWUI.Colors.Green or SWUI.Colors.TextDim
        
        -- Фон без обводки
        draw.RoundedBox(15, 0, 0, w, h, Color(col.r, col.g, col.b, 18))
        
        -- Точка статуса
        if bActive then
            local blink = 0.5 + math.abs(math.sin(CurTime() * 2.5)) * 0.5
            draw.RoundedBox(3, 10, h/2-3, 6, 6, Color(0, 238, 119, math.floor(blink*255)))
        else
            draw.RoundedBox(3, 10, h/2-3, 6, 6, col)
        end
        
        -- Текст статуса
        SWUI.DrawText(bActive and 'АКТИВЕН' or 'НЕ АКТИВЕН', 'SWUI.Tiny',
            24, h/2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- ── DModelPanel с голографическими кругами ──────────────────────────
    local modelIcon = TDLib('DModelPanel', panChars)
    modelIcon:SetSize(500, 700)
    modelIcon:SetModel(DEFAULT_MODEL)
    modelIcon:SetFOV(25)
    modelIcon:SetLookAt(Vector(0, 0, 60))
    modelIcon:SetCamPos(Vector(100, 0, 60))
    
    -- Улучшенное освещение с голубым оттенком
    modelIcon:SetAmbientLight(Color(80, 140, 200))
    modelIcon:SetDirectionalLight(BOX_FRONT,  Color(150, 200, 255))
    modelIcon:SetDirectionalLight(BOX_LEFT,   Color(0, 150, 220))
    modelIcon:SetDirectionalLight(BOX_RIGHT,  Color(0, 100, 180))
    modelIcon:SetDirectionalLight(BOX_BOTTOM, Color(20, 80, 140))

    function modelIcon:LayoutEntity(ent)
        ent:SetAngles(Angle(0, CurTime() * 30, 0))
    end
    
    modelIcon:SetVisible(false)
    
    -- ── Голографические круги на фоне ──────────────────
    local circlesPanel = vgui.Create('DPanel', panChars)
    circlesPanel:SetSize(CW, BODY_H)
    circlesPanel:SetPos(0, 0)
    circlesPanel.Paint = function(s, w, h)
        local centerX = w / 2
        local centerY = h / 2
        
        -- Рисуем концентрические круги от центра экрана
        local circleColor = Color(0, 184, 255, 20)
        
        -- Большие круги (фон)
        for i = 1, 5 do
            local radius = 200 + (i * 150)
            surface.SetDrawColor(circleColor.r, circleColor.g, circleColor.b, 8)
            draw.NoTexture()
            surface.DrawCircle(centerX, centerY, radius, circleColor.r, circleColor.g, circleColor.b, 10)
        end
        
        -- Средние круги
        for i = 1, 3 do
            local radius = 150 + (i * 80)
            surface.SetDrawColor(circleColor.r, circleColor.g, circleColor.b, 15)
            surface.DrawCircle(centerX, centerY, radius, circleColor.r, circleColor.g, circleColor.b, 12)
        end
        
        -- Внутренние яркие круги
        for i = 1, 2 do
            local radius = 100 + (i * 50)
            surface.SetDrawColor(circleColor.r, circleColor.g, circleColor.b, 25)
            surface.DrawCircle(centerX, centerY, radius, circleColor.r, circleColor.g, circleColor.b, 15)
        end
    end
    circlesPanel:MoveToBack()

    -- ── Пустой слот-заглушка ─────────────────────────────────
    local emptyPnl = vgui.Create('DPanel', panChars)
    emptyPnl:SetSize(200, 300)
    emptyPnl.Paint = function(s, w, h)
        draw.RoundedBox(8, w/2-48, 24,  96, 72,  Color(12, 20, 30))
        draw.RoundedBox(8, w/2-48, 104, 96, 90,  Color(12, 20, 30))
        draw.RoundedBox(8, w/2-44, 202, 88, 76,  Color(12, 20, 30))
        SWUI.DrawText('+', 'SWUI.Title', w/2, h/2, SWUI.Colors.BorderHi, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    emptyPnl:SetVisible(false)

    -- ── Правая инфо-панель УБРАНА - информация дублируется ──────
    -- Досье клона убрано полностью

    -- ── Навигационные стрелки ─────────────────────────────────
    local navL = SWUI.CreateButton(panChars, '◄', 0, 0, 44, 44, 'ghost')
    local navR = SWUI.CreateButton(panChars, '►', 0, 0, 44, 44, 'ghost')
    navL.DoClick = function() SWExp.F4:Go(((nCurrent - 2) % #tChars) + 1) end
    navR.DoClick = function() SWExp.F4:Go((nCurrent % #tChars) + 1) end

    -- ── Точки-индикаторы ─────────────────────────────────────
    local dotPnl = vgui.Create('DPanel', panChars)
    dotPnl.Paint = function() end
    local dots = {}

    local function RebuildDots()
        for _, d in ipairs(dots) do if IsValid(d) then d:Remove() end end
        dots = {}
        dotPnl:SetSize(#tChars * 24, 12)
        for i = 1, #tChars do
            local d = vgui.Create('DButton', dotPnl)
            d:SetPos((i-1)*24, 0); d:SetSize(12, 12); d:SetText('')
            local ii = i
            d.Paint = function(s, dw, dh)
                if ii == nCurrent then
                    -- Активный - круг побольше
                    draw.RoundedBox(6, 0, 0, 12, 12, SWUI.Colors.Accent)
                else
                    -- Неактивный - маленький круг по центру
                    draw.RoundedBox(4, 2, 2, 8, 8, SWUI.Colors.BorderHi)
                end
            end
            d.DoClick = function() SWExp.F4:Go(ii) end
            dots[i] = d
        end
    end

    -- ── Кнопки действий ──────────────────────────────────────
    local btnRowPnl = vgui.Create('DPanel', panChars)
    btnRowPnl:SetSize(CW, 48)
    btnRowPnl.Paint = function() end

    -- ── Панель создания персонажа ─────────────────────────────
    local panCreate = vgui.Create('DPanel', panChars)
    panCreate:SetSize(400, 210)
    panCreate.Paint = function(s, pw, ph)
        draw.RoundedBox(10, 0, 0, pw, ph, Color(10, 15, 24, 248))
        surface.SetDrawColor(SWUI.Colors.Border.r, SWUI.Colors.Border.g, SWUI.Colors.Border.b, 255)
        surface.DrawOutlinedRect(0, 0, pw, ph, 1)
        surface.SetDrawColor(SWUI.Colors.Accent.r, SWUI.Colors.Accent.g, SWUI.Colors.Accent.b, 255)
        surface.DrawRect(1, 0, pw-2, 2)
        SWUI.DrawText('НОВЫЙ КЛОН', 'SWUI.Tiny', pw/2, 12, SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    panCreate:SetVisible(false)

    local inpNum = SWUI.CreateInput(panCreate, 16, 28, 368, 38, 'Номер (CT-1104)')
    local inpCs  = SWUI.CreateInput(panCreate, 16, 74, 368, 38, 'Позывной (ПРИЗРАК)')
    
    -- Фильтр только цифры - через Think хук
    local lastValue = ''
    inpNum.Entry.Think = function(self)
        local text = self:GetValue()
        if text ~= lastValue then
            local filtered = string.gsub(text, '[^0-9]', '')  -- Оставляем только цифры
            if text ~= filtered then
                self:SetValue(filtered)
                self:SetCaretPos(string.len(filtered))
            end
            lastValue = filtered
        end
    end

    local lblErr = vgui.Create('DLabel', panCreate)
    lblErr:SetPos(16, 120); lblErr:SetSize(368, 16)
    lblErr:SetFont('SWUI.Tiny'); lblErr:SetTextColor(Color(220, 60, 60)); lblErr:SetText('')

    SWUI.CreateButton(panCreate, 'СОЗДАТЬ', 16, 144, 368, 38, 'accent', function()
        local n = string.upper(string.Trim(inpNum:GetValue()))
        local c = string.upper(string.Trim(inpCs:GetValue()))
        if n == '' or c == '' then lblErr:SetText('Заполните все поля') return end
        lblErr:SetText('')
        netstream.Start('SWExp::CreateChar', { clone_number = n, callsign = c })
        panCreate:SetVisible(false)
    end)

    -- ============================================================
    -- UpdateUI — обновляет всё под текущий nCurrent
    -- ============================================================

    function SWExp.F4:UpdateUI()
        local char = tChars[nCurrent]

        local cx = CW / 2
        local cy = BODY_H / 2

        modelIcon:SetPos(cx - 250, cy - 350)
        emptyPnl:SetPos(cx - 100, cy - 150)
        badgePnl:SetPos(CW - 180, 18)
        navL:SetPos(16, cy - 22)
        navR:SetPos(CW - 60, cy - 22)
        btnRowPnl:SetPos(0, BODY_H - 56)

        RebuildDots()
        dotPnl:SetPos(cx - #tChars * 12, BODY_H - 72)

        for _, c in ipairs(btnRowPnl:GetChildren()) do c:Remove() end

        if IsEmpty(char) then
            modelIcon:SetVisible(false)
            emptyPnl:SetVisible(true)
            badgePnl:SetVisible(false)

            lblName:SetText('+ НОВЫЙ КЛОН')
            lblRank:SetText('')
            lblNumber:SetText('')
            bActive = false

            panCreate:SetPos(cx - 200, cy - 105)
            panCreate:SetVisible(true)
        else
            panCreate:SetVisible(false)
            modelIcon:SetVisible(true)
            emptyPnl:SetVisible(false)
            badgePnl:SetVisible(true)

            lblName:SetText(char.callsign or '???')
            lblRank:SetText(char['rank'] or '')
            lblNumber:SetText(char.clone_number or '')

            local isAct = tonumber(char.id) == nActive
            bActive = isAct

            local bW, gap = 148, 10
            local count   = isAct and 2 or 3
            local totalW  = count * bW + (count-1) * gap + (isAct and 22 or 0)
            local sx      = CW/2 - totalW/2

            if isAct then
                SWUI.CreateButton(btnRowPnl, '● АКТИВЕН', sx, 4, bW+22, 40, 'ghost')
                local b2 = SWUI.CreateButton(btnRowPnl, 'ПЕРЕИМЕНОВАТЬ', sx+bW+22+gap, 4, bW, 40, 'ghost')
                b2.DoClick = function()
                    -- Кастомное окно переименования
                    local renameFrame, renameContent = SWUI.CreateWindow('ПЕРЕИМЕНОВАНИЕ', 400, 220)
                    
                    local lbl = vgui.Create('DLabel', renameContent)
                    lbl:SetPos(20, 20)
                    lbl:SetSize(360, 20)
                    lbl:SetFont('SWUI.Body')
                    lbl:SetTextColor(SWUI.Colors.TextHi)
                    lbl:SetText('Новый позывной:')
                    
                    local input = SWUI.CreateInput(renameContent, 20, 50, 360, 38, char.callsign or '')
                    
                    SWUI.CreateButton(renameContent, 'СОХРАНИТЬ', 20, 130, 170, 38, 'accent', function()
                        local v = string.Trim(input:GetValue())
                        if v ~= '' then
                            netstream.Start('SWExp::RenameChar', tonumber(char.id), v)
                            renameFrame:Close()
                        end
                    end)
                    
                    SWUI.CreateButton(renameContent, 'ОТМЕНА', 210, 130, 170, 38, 'ghost', function()
                        renameFrame:Close()
                    end)
                end
            else
                local b1 = SWUI.CreateButton(btnRowPnl, 'ВЫБРАТЬ', sx, 4, bW, 40, 'accent')
                b1.DoClick = function()
                    print('==================')
                    print('[DEBUG CL] Нажата кнопка ВЫБРАТЬ')
                    print('[DEBUG CL] ID персонажа:', char.id, type(char.id))
                    print('[DEBUG CL] Отправляю netstream...')
                    print('==================')
                    netstream.Start('SWExp::ChooseChar', tonumber(char.id))
                    
                    -- Закрываем меню сразу после выбора
                    timer.Simple(0.1, function()
                        if IsValid(frame) then
                            frame:Remove()
                        end
                    end)
                end
                local b2 = SWUI.CreateButton(btnRowPnl, 'ПЕРЕИМЕНОВАТЬ', sx+bW+gap, 4, bW, 40, 'ghost')
                b2.DoClick = function()
                    -- Кастомное окно переименования
                    local renameFrame, renameContent = SWUI.CreateWindow('ПЕРЕИМЕНОВАНИЕ', 400, 220)
                    
                    local lbl = vgui.Create('DLabel', renameContent)
                    lbl:SetPos(20, 20)
                    lbl:SetSize(360, 20)
                    lbl:SetFont('SWUI.Body')
                    lbl:SetTextColor(SWUI.Colors.TextHi)
                    lbl:SetText('Новый позывной:')
                    
                    local input = SWUI.CreateInput(renameContent, 20, 50, 360, 38, char.callsign or '')
                    
                    SWUI.CreateButton(renameContent, 'СОХРАНИТЬ', 20, 130, 170, 38, 'accent', function()
                        local v = string.Trim(input:GetValue())
                        if v ~= '' then
                            netstream.Start('SWExp::RenameChar', tonumber(char.id), v)
                            renameFrame:Close()
                        end
                    end)
                    
                    SWUI.CreateButton(renameContent, 'ОТМЕНА', 210, 130, 170, 38, 'ghost', function()
                        renameFrame:Close()
                    end)
                end
                local b3 = SWUI.CreateButton(btnRowPnl, 'УДАЛИТЬ', sx+(bW+gap)*2, 4, bW, 40, 'danger')
                b3.DoClick = function()
                    -- Кастомное окно подтверждения удаления
                    local confirmFrame, confirmContent = SWUI.CreateWindow('ПОДТВЕРЖДЕНИЕ', 400, 220)
                    
                    local lbl = vgui.Create('DLabel', confirmContent)
                    lbl:SetPos(20, 40)
                    lbl:SetSize(360, 40)
                    lbl:SetFont('SWUI.Body')
                    lbl:SetTextColor(SWUI.Colors.TextHi)
                    lbl:SetText('Удалить персонажа ' .. (char.callsign or '') .. '?')
                    lbl:SetWrap(true)
                    lbl:SetContentAlignment(5)
                    
                    SWUI.CreateButton(confirmContent, 'УДАЛИТЬ', 20, 130, 170, 38, 'danger', function()
                        netstream.Start('SWExp::DeleteChar', tonumber(char.id))
                        confirmFrame:Close()
                    end)
                    
                    SWUI.CreateButton(confirmContent, 'ОТМЕНА', 210, 130, 170, 38, 'ghost', function()
                        confirmFrame:Close()
                    end)
                end
            end
        end
    end

    function SWExp.F4:Go(idx)
        nCurrent = math.Clamp(idx, 1, math.max(1, #tChars))
        self:UpdateUI()
    end

    self:UpdateUI()

    -- ============================================================
    -- ТАБ НАСТРОЙКИ (РАБОЧИЕ)
    -- ============================================================

    local panSettings = MakeTab(false)
    panels['settings'] = panSettings

    local scroll = SWUI.CreateScrollList(panSettings, CW/2 - 280, 20, 560, BODY_H - 40)

    local function SGroup(txt)
        local l = vgui.Create('DLabel', scroll)
        l:Dock(TOP); l:DockMargin(0, 16, 0, 6); l:SetTall(18)
        l:SetFont('SWUI.Small'); l:SetTextColor(SWUI.Colors.Accent)
        l:SetText(string.upper(txt))
    end

    local function SRow(label, desc, cookieKey, defaultValue, onChange)
        local row = vgui.Create('DPanel', scroll)
        row:Dock(TOP); row:DockMargin(0, 0, 0, 6); row:SetTall(desc and 60 or 46)
        row.Paint = function(s, w, h)
            SWUI.DrawRoundedRect(0, 0, w, h, 8, Color(0, 0, 0, 100))
            surface.SetDrawColor(SWUI.Colors.Border)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        
        -- Текст СЛЕВА
        local l = vgui.Create('DLabel', row)
        l:SetPos(16, desc and 10 or 13)
        l:SetSize(450, 20)  -- Фиксированная ширина
        l:SetFont('SWUI.Body')
        l:SetTextColor(SWUI.Colors.TextHi)
        l:SetText(label)
        
        if desc then
            local s2 = vgui.Create('DLabel', row)
            s2:SetPos(16, 32)
            s2:SetSize(450, 16)
            s2:SetFont('SWUI.Tiny')
            s2:SetTextColor(SWUI.Colors.TextDim)
            s2:SetText(desc)
        end
        
        -- Чекбокс СПРАВА
        local cb = vgui.Create('DCheckBox', row)
        cb:SetPos(480, row:GetTall() / 2 - 11)  -- Абсолютная позиция
        cb:SetSize(40, 22)
        
        -- Загружаем значение из cookie
        local savedValue = cookie.GetString('swexp_' .. cookieKey, defaultValue and '1' or '0')
        cb:SetValue(savedValue == '1')
        
        cb.Paint = function(s, cw, ch)
            local on = s:GetChecked()
            -- Фон без обводки
            SWUI.DrawRoundedRect(0, 0, cw, ch, 11, on and SWUI.Colors.AccentDim or Color(255, 255, 255, 15))
            
            -- Кружочек-ползунок
            if on then
                -- Включено - голубой кружок справа
                draw.RoundedBox(8, cw - 19, 3, 16, 16, SWUI.Colors.Accent)
            else
                -- Выключено - серый кружок слева
                draw.RoundedBox(8, 2, 3, 16, 16, Color(100, 100, 100))
            end
        end
        
        cb.OnChange = function(s, val)
            -- Сохраняем в cookie
            cookie.Set('swexp_' .. cookieKey, val and '1' or '0')
            
            -- Вызываем callback
            if onChange then
                onChange(val)
            end
            
            -- Звук переключения
            if SWUI and SWUI.PlaySound then
                SWUI.PlaySound(SWUI.Sounds.Click, 0.5)
            end
        end
        
        return cb
    end

    SGroup('Звук')
    
    SRow('Звуки интерфейса', 'Звуки при открытии меню и нажатии кнопок', 'ui_sounds', true, function(enabled)
        -- Обновляем глобальную переменную
        SWUI.SoundEnabled = enabled
        
        if enabled then
            chat.AddText(SWUI.Colors.Accent, '[SWExp] ', SWUI.Colors.TextHi, 'Звуки интерфейса включены')
        else
            chat.AddText(SWUI.Colors.Accent, '[SWExp] ', SWUI.Colors.TextDim, 'Звуки интерфейса отключены')
        end
    end)

    SGroup('HUD')
    
    SRow('Показывать компас', 'Отображение компаса на экране', 'show_compass', true, function(enabled)
        -- Отправляем на сервер (если нужно) или просто сохраняем локально
        if enabled then
            chat.AddText(SWUI.Colors.Accent, '[SWExp] ', SWUI.Colors.TextHi, 'Компас включён')
        else
            chat.AddText(SWUI.Colors.Accent, '[SWExp] ', SWUI.Colors.TextDim, 'Компас отключён')
        end
    end)
end

-- ============================================================
-- Refresh / Netstream / F4
-- ============================================================

function SWExp.F4:Refresh(tNew)
    tChars = tNew or {}
    if #tChars < GetSlots() then tChars[#tChars + 1] = { _empty = true } end
    nCurrent = math.Clamp(nCurrent, 1, math.max(1, #tChars))
    if IsValid(self.Frame) then self:UpdateUI() else self:Open(tNew) end
end

netstream.Hook('SWExp::OpenCharSelect', function(t)
    -- Если первый раз - показываем splash
    if not hasShownSplash then
        hasShownSplash = true
        SWExp.F4:ShowSplash(function()
            SWExp.F4:Open(t)
        end)
    else
        if IsValid(SWExp.F4.Frame) then SWExp.F4:Refresh(t) else SWExp.F4:Open(t) end
    end
end)

netstream.Hook('SWExp::CharSelected', function()
    print('[DEBUG CL] Получен SWExp::CharSelected - персонаж выбран!')
    if IsValid(SWExp.F4.Frame) then
        SWExp.F4.Frame:Remove()
    end
end)

netstream.Hook('SWExp::CharError', function(msg)
    notification.AddLegacy('Ошибка: ' .. (msg or ''), NOTIFY_ERROR, 4)
end)

hook.Add('PlayerButtonDown', 'SWExp::F4Key', function(ply, btn)
    if btn ~= KEY_F4 then return end
    
    -- Если персонаж не выбран - блокируем F4
    local localCS = LocalPlayer():GetNWString('swexp_callsign', '')
    if localCS == '' or not localCS then return true end
    
    if IsValid(SWExp.F4.Frame) then SWExp.F4.Frame:Close() return end
    netstream.Start('SWExp::RequestChars')
end)