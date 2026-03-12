-- modules/cl_f4.lua
-- F4 Меню — выбор персонажа SWExp

if SERVER then return end

SWExp.F4 = SWExp.F4 or {}

local tChars   = {}
local nCurrent = 1
local nActive  = 0

local DEFAULT_MODEL = 'models/player/combine_super_soldier.mdl'

local function IsEmpty(c) return c == nil or c._empty == true end
local function GetSlots() return LocalPlayer():GetNWInt('swexp_char_slots', 1) end

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
        SWUI.DrawText('ТЕРМИНАЛ КЛОНОВ', 'SWUI.Header', 24, th/2,
            SWUI.Colors.TextHi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    SWUI.CreateButton(titlePnl, '×', SW - 44, 7, 30, 30, 'ghost', function()
        frame:Remove()
    end)

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
        draw.RoundedBox(15, 0, 0, w, h, Color(col.r, col.g, col.b, 18))
        surface.SetDrawColor(col.r, col.g, col.b, 80)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        if bActive then
            local blink = 0.5 + math.abs(math.sin(CurTime() * 2.5)) * 0.5
            draw.RoundedBox(3, 10, h/2-3, 6, 6, Color(0, 238, 119, math.floor(blink*255)))
        else
            draw.RoundedBox(3, 10, h/2-3, 6, 6, col)
        end
        SWUI.DrawText(bActive and 'АКТИВЕН' or 'НЕ АКТИВЕН', 'SWUI.Tiny',
            24, h/2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- ── DModelPanel ──────────────────────────────────────────
    -- Используем TDLib как в cl_body.lua
    local modelIcon = TDLib('DModelPanel', panChars)
    modelIcon:SetSize(500, 700)
    modelIcon:SetModel(DEFAULT_MODEL)
    modelIcon:SetFOV(25)
    -- Камера: смотрим на центр тела (Z=60 = примерно грудь), отдаление по X
    modelIcon:SetLookAt(Vector(0, 0, 60))
    modelIcon:SetCamPos(Vector(100, 0, 60))
    modelIcon:SetAmbientLight(Color(100, 140, 180))
    modelIcon:SetDirectionalLight(BOX_FRONT,  Color(200, 230, 255))
    modelIcon:SetDirectionalLight(BOX_LEFT,   Color(50,  110, 190))
    modelIcon:SetDirectionalLight(BOX_BOTTOM, Color(20,  50,  90))

    -- Автовращение
    function modelIcon:LayoutEntity(ent)
        ent:SetAngles(Angle(0, CurTime() * 30, 0))
    end
    modelIcon:SetVisible(false)

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

    -- ── Правая инфо-панель ────────────────────────────────────
    local IW, IH = 260, 380
    local infoPnl = vgui.Create('DPanel', panChars)
    infoPnl:SetSize(IW, IH)
    infoPnl.Paint = function(s, w, h)
        draw.RoundedBox(10, 0, 0, w, h, Color(8, 13, 22, 230))
        surface.SetDrawColor(SWUI.Colors.Border.r, SWUI.Colors.Border.g, SWUI.Colors.Border.b, 255)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        surface.SetDrawColor(SWUI.Colors.Accent.r, SWUI.Colors.Accent.g, SWUI.Colors.Accent.b, 255)
        surface.DrawRect(1, 0, w-2, 2)
    end
    infoPnl:SetVisible(false)

    SWUI.CreateSectionHeader(infoPnl, 'ДОСЬЕ КЛОНА', 0, 0, IW)

    local function InfoRow(parent, yy, caption)
        local row = vgui.Create('DPanel', parent)
        row:SetPos(0, yy); row:SetSize(IW, 36)
        row.Paint = function(s, w, h)
            surface.SetDrawColor(255, 255, 255, 3)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(SWUI.Colors.Border.r, SWUI.Colors.Border.g, SWUI.Colors.Border.b, 80)
            surface.DrawLine(12, h-1, w-12, h-1)
        end
        local lbl = vgui.Create('DLabel', row)
        lbl:SetPos(12, 0); lbl:SetSize(100, 36)
        lbl:SetFont('SWUI.Tiny'); lbl:SetTextColor(SWUI.Colors.TextDim)
        lbl:SetText(caption); lbl:SetContentAlignment(4)
        local val = vgui.Create('DLabel', row)
        val:SetPos(110, 0); val:SetSize(IW-122, 36)
        val:SetFont('SWUI.Small'); val:SetTextColor(SWUI.Colors.TextHi)
        val:SetText('—'); val:SetContentAlignment(6)
        return val
    end

    local valNum  = InfoRow(infoPnl, 30,  'НОМЕР')
    local valCs   = InfoRow(infoPnl, 66,  'ПОЗЫВНОЙ')
    local valRnk  = InfoRow(infoPnl, 102, 'ЗВАНИЕ')
    local valStat = InfoRow(infoPnl, 138, 'СТАТУС')

    -- XP
    local xpFrac = 0
    local xpHdr = vgui.Create('DLabel', infoPnl)
    xpHdr:SetPos(12, 182); xpHdr:SetSize(IW-24, 14)
    xpHdr:SetFont('SWUI.Tiny'); xpHdr:SetTextColor(SWUI.Colors.TextDim); xpHdr:SetText('ОПЫТ')

    local xpBar = SWUI.CreateProgressBar(infoPnl, 12, 198, IW-24, 8, SWUI.Colors.Accent)

    local xpSub = vgui.Create('DLabel', infoPnl)
    xpSub:SetPos(12, 208); xpSub:SetSize(IW-24, 14)
    xpSub:SetFont('SWUI.Tiny'); xpSub:SetTextColor(SWUI.Colors.TextDim); xpSub:SetText('')

    SWUI.DrawDivider(12, 232, IW-24, SWUI.Colors.Border)

    local iBattalion = vgui.Create('DLabel', infoPnl)
    iBattalion:SetPos(12, 240); iBattalion:SetSize(IW-24, 14)
    iBattalion:SetFont('SWUI.Tiny'); iBattalion:SetTextColor(SWUI.Colors.TextDim)
    iBattalion:SetText('ВЕЛИКАЯ АРМИЯ РЕСПУБЛИКИ')

    local iDesc = vgui.Create('DLabel', infoPnl)
    iDesc:SetPos(12, 258); iDesc:SetSize(IW-24, 60)
    iDesc:SetFont('SWUI.Tiny'); iDesc:SetTextColor(Color(90, 120, 145))
    iDesc:SetText('Клон-троопер Звёздного Корпуса.\nСлужит Республике по велению долга.')
    iDesc:SetWrap(true)

    local iSlots = vgui.Create('DLabel', infoPnl)
    iSlots:SetPos(12, IH-24); iSlots:SetSize(IW-24, 16)
    iSlots:SetFont('SWUI.Tiny'); iSlots:SetTextColor(SWUI.Colors.TextDim); iSlots:SetText('')

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
                    draw.RoundedBox(3, 0, dh/2-3, 16, 6, SWUI.Colors.Accent)
                else
                    draw.RoundedBox(6, dw/2-4, dh/2-4, 8, 8, SWUI.Colors.BorderHi)
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

    local lblErr = vgui.Create('DLabel', panCreate)
    lblErr:SetPos(16, 120); lblErr:SetSize(368, 16)
    lblErr:SetFont('SWUI.Tiny'); lblErr:SetTextColor(Color(220, 60, 60)); lblErr:SetText('')

    SWUI.CreateButton(panCreate, 'СОЗДАТЬ', 16, 144, 172, 38, 'accent', function()
        local n = string.upper(string.Trim(inpNum:GetValue()))
        local c = string.upper(string.Trim(inpCs:GetValue()))
        if n == '' or c == '' then lblErr:SetText('Заполните все поля') return end
        lblErr:SetText('')
        netstream.Start('SWExp::CreateChar', { clone_number = n, callsign = c })
        panCreate:SetVisible(false)
    end)

    SWUI.CreateButton(panCreate, 'ОТМЕНА', 200, 144, 132, 38, 'ghost', function()
        panCreate:SetVisible(false)
    end)

    -- ============================================================
    -- UpdateUI — обновляет всё под текущий nCurrent
    -- ============================================================

    function SWExp.F4:UpdateUI()
        local char = tChars[nCurrent]

        -- позиционирование по центру контента
        local cx = CW / 2
        local cy = BODY_H / 2

        modelIcon:SetPos(cx - 250, cy - 350)
        emptyPnl:SetPos(cx - 100, cy - 150)
        infoPnl:SetPos(cx + 200, cy - 190)
        badgePnl:SetPos(CW - 180, 18)
        navL:SetPos(16, cy - 22)
        navR:SetPos(CW - 60, cy - 22)
        btnRowPnl:SetPos(0, BODY_H - 56)

        RebuildDots()
        dotPnl:SetPos(cx - #tChars * 12, BODY_H - 72)

        -- чистим кнопки
        for _, c in ipairs(btnRowPnl:GetChildren()) do c:Remove() end

        if IsEmpty(char) then
            modelIcon:SetVisible(false)
            emptyPnl:SetVisible(true)
            infoPnl:SetVisible(false)
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
            infoPnl:SetVisible(true)
            badgePnl:SetVisible(true)

            lblName:SetText(char.callsign or '???')
            lblRank:SetText(char['rank'] or '')
            lblNumber:SetText(char.clone_number or '')

            local isAct = tonumber(char.id) == nActive
            bActive = isAct

            valNum:SetText(char.clone_number or '—')
            valCs:SetText(char.callsign or '—')
            valRnk:SetText(char['rank'] or '—')
            valStat:SetText(isAct and 'АКТИВЕН' or 'В РЕЗЕРВЕ')
            valStat:SetTextColor(isAct and SWUI.Colors.Green or SWUI.Colors.TextDim)

            local exp = tonumber(char.exp) or 0
            xpFrac = math.Clamp(exp / 1000, 0, 1)
            xpBar:SetValue(exp, 1000)
            xpHdr:SetText('ОПЫТ  ' .. exp .. ' XP')
            xpSub:SetText(exp .. ' / 1000 до следующего уровня')

            local used = 0
            for _, c in ipairs(tChars) do if not c._empty then used = used + 1 end end
            iSlots:SetText('СЛОТЫ: ' .. used .. ' / ' .. GetSlots())

            -- кнопки действий
            local bW, gap = 148, 10
            local count   = isAct and 2 or 3
            local totalW  = count * bW + (count-1) * gap + (isAct and 22 or 0)
            local sx      = CW/2 - totalW/2

            if isAct then
                SWUI.CreateButton(btnRowPnl, '● АКТИВЕН', sx, 4, bW+22, 40, 'ghost')
                local b2 = SWUI.CreateButton(btnRowPnl, 'ПЕРЕИМЕНОВАТЬ', sx+bW+22+gap, 4, bW, 40, 'ghost')
                b2.DoClick = function()
                    Derma_StringRequest('Позывной', 'Новый позывной:', char.callsign or '',
                        function(v) if v ~= '' then netstream.Start('SWExp::RenameChar', tonumber(char.id), v) end end)
                end
            else
                local b1 = SWUI.CreateButton(btnRowPnl, 'ВЫБРАТЬ', sx, 4, bW, 40, 'accent')
                b1.DoClick = function()
                    netstream.Start('SWExp::ChooseChar', tonumber(char.id))
                    frame:Close()
                end
                local b2 = SWUI.CreateButton(btnRowPnl, 'ПЕРЕИМЕНОВАТЬ', sx+bW+gap, 4, bW, 40, 'ghost')
                b2.DoClick = function()
                    Derma_StringRequest('Позывной', 'Новый позывной:', char.callsign or '',
                        function(v) if v ~= '' then netstream.Start('SWExp::RenameChar', tonumber(char.id), v) end end)
                end
                local b3 = SWUI.CreateButton(btnRowPnl, 'УДАЛИТЬ', sx+(bW+gap)*2, 4, bW, 40, 'danger')
                b3.DoClick = function()
                    Derma_Query('Удалить ' .. (char.callsign or '') .. '?', 'Подтверждение',
                        'Удалить', function() netstream.Start('SWExp::DeleteChar', tonumber(char.id)) end,
                        'Отмена', function() end)
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
    -- ТАБ НАСТРОЙКИ
    -- ============================================================

    local panSettings = MakeTab(false)
    panels['settings'] = panSettings

    local scroll = SWUI.CreateScrollList(panSettings, CW/2 - 280, 20, 560, BODY_H - 40)

    local function SGroup(txt)
        local l = vgui.Create('DLabel', scroll)
        l:Dock(TOP); l:DockMargin(0, 12, 0, 4); l:SetTall(16)
        l:SetFont('SWUI.Tiny'); l:SetTextColor(SWUI.Colors.TextDim)
        l:SetText(string.upper(txt))
    end

    local function SRow(label, desc)
        local row = vgui.Create('DPanel', scroll)
        row:Dock(TOP); row:DockMargin(0, 0, 0, 4); row:SetTall(desc and 54 or 42)
        row.Paint = function(s, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(0, 0, 0, 50))
            surface.SetDrawColor(SWUI.Colors.Border.r, SWUI.Colors.Border.g, SWUI.Colors.Border.b, 255)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        local l = vgui.Create('DLabel', row)
        l:SetPos(14, desc and 7 or 11); l:SetSize(460, 20)
        l:SetFont('SWUI.Body'); l:SetTextColor(SWUI.Colors.Text); l:SetText(label)
        if desc then
            local s2 = vgui.Create('DLabel', row)
            s2:SetPos(14, 28); s2:SetSize(460, 16)
            s2:SetFont('SWUI.Tiny'); s2:SetTextColor(SWUI.Colors.TextDim); s2:SetText(desc)
        end
        local cb = vgui.Create('DCheckBox', row)
        cb:SetPos(row:GetWide() - 50, row:GetTall()/2 - 10); cb:SetSize(36, 20); cb:SetValue(true)
        cb.Paint = function(s, cw, ch)
            local on = s:GetChecked()
            draw.RoundedBox(10, 0, 0, cw, ch, on and SWUI.Colors.AccentDim or Color(255,255,255,15))
            surface.SetDrawColor(SWUI.Colors.Accent.r, SWUI.Colors.Accent.g, SWUI.Colors.Accent.b, on and 200 or 60)
            surface.DrawOutlinedRect(0, 0, cw, ch, 1)
            draw.RoundedBox(7, on and cw-18 or 2, 3, 15, 14, on and SWUI.Colors.Accent or Color(70,70,70))
        end
    end

    SGroup('Звук')
    SRow('Звуки интерфейса', 'Звуки при открытии меню и взаимодействии')
    SRow('Громкость игрового модуля')
    SGroup('HUD')
    SRow('Показывать компас')
    SRow('Показывать подсказки сканирования', 'Текст над сканируемыми объектами')
    SGroup('Прочее')
    SRow('Уведомления об уровне прогресса')
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
    if IsValid(SWExp.F4.Frame) then SWExp.F4:Refresh(t) else SWExp.F4:Open(t) end
end)

netstream.Hook('SWExp::CharSelected', function()
    if IsValid(SWExp.F4.Frame) then SWExp.F4.Frame:Close() end
end)

netstream.Hook('SWExp::CharError', function(msg)
    notification.AddLegacy('Ошибка: ' .. (msg or ''), NOTIFY_ERROR, 4)
end)

hook.Add('PlayerButtonDown', 'SWExp::F4Key', function(ply, btn)
    if btn ~= KEY_F4 then return end
    if IsValid(SWExp.F4.Frame) then SWExp.F4.Frame:Close() return end
    netstream.Start('SWExp::RequestChars')
end)