-- ============================================================
-- Star Wars: Expedition — Scoreboard
-- modules/cl_scoreboard.lua
-- ============================================================

if not CLIENT then return end

local SCOREBOARD = {}
SCOREBOARD.Frame = nil
SCOREBOARD.Window = nil
SCOREBOARD.PlayerRows = {}
SCOREBOARD.OpenRow = nil

-- ============================================================
-- ИКОНКИ (БЕЗ ЭМОДЗИ)
-- ============================================================

local function DrawIcon_Clock(x, y, size, col)
    draw.RoundedBox(size/2.5, x + size/5, y + size/5, size/1.5, size/1.5, col)
    surface.SetDrawColor(SWUI.Colors.PanelBG)
    draw.RoundedBox(0, x + size/2 - 1, y + size/4, 2, size/3, SWUI.Colors.PanelBG)
    draw.RoundedBox(0, x + size/2 - 1, y + size/2 - 1, size/4, 2, SWUI.Colors.PanelBG)
end

local function DrawIcon_Group(x, y, size, col)
    local s = size/4
    draw.RoundedBox(s/2, x + s/2, y + s/2, s, s, col)
    draw.RoundedBox(2, x + s/2, y + s*1.5, s, s*1.5, col)
    draw.RoundedBox(s/2, x + size/2 - s/2, y, s, s, col)
    draw.RoundedBox(2, x + size/2 - s/2, y + s*1.2, s, s*2, col)
    draw.RoundedBox(s/2, x + size - s*1.5, y + s/2, s, s, col)
    draw.RoundedBox(2, x + size - s*1.5, y + s*1.5, s, s*1.5, col)
end

local function DrawIcon_Skull(x, y, size, col)
    draw.RoundedBox(4, x + size/4, y + size/5, size/2, size/2.5, col)
    surface.SetDrawColor(SWUI.Colors.PanelBG)
    draw.RoundedBox(0, x + size/3, y + size/2.5, size/8, size/6, SWUI.Colors.PanelBG)
    draw.RoundedBox(0, x + size - size/3 - size/8, y + size/2.5, size/8, size/6, SWUI.Colors.PanelBG)
end

-- ============================================================
-- СОЗДАНИЕ ОКНА
-- ============================================================

function SCOREBOARD:Create()
    if IsValid(self.Frame) then
        self.Frame:Remove()
    end

    local overlay = vgui.Create('EditablePanel')
    overlay:SetSize(ScrW(), ScrH())
    overlay:SetPos(0, 0)
    overlay:SetKeyboardInputEnabled(false)
    overlay:SetMouseInputEnabled(true)
    
    overlay.Paint = function(pnl, w, h)
        surface.SetDrawColor(0, 0, 0, 165)
        surface.DrawRect(0, 0, w, h)
    end

    -- Занимает 70% ширины экрана и 75% высоты экрана
    local W, H = ScrW() * 0.7, ScrH() * 0.75

    local frame = vgui.Create('DPanel', overlay)
    frame:SetSize(W, H)
    frame:Center()

    frame.Paint = function(pnl, w, h)
        -- Внешняя граница accent с закруглениями
        draw.RoundedBoxEx(16, 0, 0, w, h, SWUI.Colors.Accent, true, true, false, false)
        
        -- Внутренний фон с отступом (создает эффект границы)
        draw.RoundedBoxEx(14, 2, 2, w - 4, h - 4, SWUI.Colors.PanelBG, true, true, false, false)
    end

    self.Frame = overlay
    self.Window = frame

    self:CreateTitlebar()
    self:CreateTabs()
    self:CreatePlayerList()
    self:CreateStatusbar()

    if SWUI.Animations and SWUI.Animations.Presets then
        SWUI.Animations.Presets.WindowOpen(frame, 0.35)
    end

    overlay:SetVisible(false)

    return overlay
end

-- ============================================================
-- TITLEBAR
-- ============================================================

function SCOREBOARD:CreateTitlebar()
    local bar = vgui.Create('DPanel', self.Window)
    bar:Dock(TOP)
    bar:DockMargin(2, 2, 2, 0)  -- Отступ от границы
    bar:SetTall(44)

    bar.Paint = function(pnl, w, h)
        draw.RoundedBoxEx(16, 0, 0, w, h, SWUI.Colors.Panel2, true, true, false, false)
        
        surface.SetDrawColor(SWUI.Colors.Accent)
        surface.DrawLine(0, h - 2, w, h - 2)
        surface.DrawLine(0, h - 1, w, h - 1)

        draw.SimpleText('ЛИЧНЫЙ СОСТАВ', 'SWUI.Header', w / 2, h / 2, SWUI.Colors.TextHi, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local count = #player.GetAll()
        local max = game.MaxPlayers()
        
        draw.SimpleText('ОНЛАЙН: ', 'SWUI.MonoSmall', w - 140, h / 2, SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(tostring(count), 'SWUI.MonoSmall', w - 88, h / 2, SWUI.Colors.Green, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(' / ' .. tostring(max), 'SWUI.MonoSmall', w - 70, h / 2, SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local btn = vgui.Create('DButton', bar)
    btn:SetPos(bar:GetWide() - 44, 10)
    btn:SetSize(24, 24)
    btn:SetText('')

    btn.Paint = function(pnl, w, h)
        draw.RoundedBox(5, 0, 0, w, h, Color(17, 17, 17))
        surface.SetDrawColor(pnl:IsHovered() and SWUI.Colors.Red or Color(51, 51, 51))
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText('×', 'SWUI.Small', w / 2, h / 2, pnl:IsHovered() and SWUI.Colors.Red or Color(85, 85, 85), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = function()
        SCOREBOARD:Hide()
    end
end

-- ============================================================
-- TABS
-- ============================================================

function SCOREBOARD:CreateTabs()
    local tabs = vgui.Create('DPanel', self.Window)
    tabs:Dock(TOP)
    tabs:DockMargin(2, 0, 2, 0)  -- Отступы по бокам
    tabs:SetTall(38)

    tabs.Paint = function(pnl, w, h)
        draw.RoundedBox(0, 0, 0, w, h, SWUI.Colors.Panel2)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawLine(0, h - 1, w, h - 1)
    end

    local tab = vgui.Create('DButton', tabs)
    tab:SetPos(0, 0)
    tab:SetSize(120, 38)
    tab:SetText('')

    tab.Paint = function(pnl, w, h)
        surface.SetDrawColor(SWUI.Colors.Accent.r, SWUI.Colors.Accent.g, SWUI.Colors.Accent.b, 10)
        surface.DrawRect(0, 0, w, h)
        
        surface.SetDrawColor(SWUI.Colors.Accent)
        surface.DrawLine(0, h - 2, w, h - 2)
        surface.DrawLine(0, h - 1, w, h - 1)

        draw.SimpleText('ИГРОКИ', 'SWUI.Small', w / 2, h / 2, SWUI.Colors.Accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

-- ============================================================
-- СПИСОК ИГРОКОВ
-- ============================================================

function SCOREBOARD:CreatePlayerList()
    local content = vgui.Create('DPanel', self.Window)
    content:Dock(FILL)
    content:DockMargin(2, 0, 2, 0)  -- Отступы по бокам
    content.Paint = function() end

    local header = vgui.Create('DPanel', content)
    header:Dock(TOP)
    header:SetTall(32)

    header.Paint = function(pnl, w, h)
        draw.RoundedBox(0, 0, 0, w, h, SWUI.Colors.Panel2)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawLine(0, h - 1, w, h - 1)

        -- Позиции совпадают с row.Paint
        local xAvatar = 8 + 16 + 8
        local xRank = xAvatar + 32 + 72
        local xCallsign = xRank + 80
        local xNumber = xCallsign + 250
        
        -- Ширина строки меньше на 19px, и она сдвинута вправо на 8px.
        -- Разница для правого края: -19 + 8 = -11. 
        -- Поэтому (w - 90) из строки превращается в (w - 101) для заголовка.
        local xPing = w - 101

        draw.SimpleText('ЗВАНИЕ', 'SWUI.Small', xRank, h / 2, SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText('ПОЗЫВНОЙ', 'SWUI.Small', xCallsign, h / 2, SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText('НОМЕР', 'SWUI.Small', xNumber, h / 2, SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText('ПИНГ', 'SWUI.Small', xPing, h / 2, SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local scroll = vgui.Create('DScrollPanel', content)
    scroll:Dock(FILL)
    scroll:DockMargin(8, 6, 8, 6)
    scroll.Paint = function() end

    local sbar = scroll:GetVBar()
    sbar:SetWide(3)
    sbar.Paint = function() end
    sbar.btnUp.Paint = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(pnl, w, h)
        draw.RoundedBox(2, 0, 0, w, h, SWUI.Colors.AccentDim)
    end

    self.ScrollPanel = scroll
    self:PopulateList()
end

-- ============================================================
-- ЗАПОЛНЕНИЕ СПИСКА
-- ============================================================

function SCOREBOARD:PopulateList()
    if not IsValid(self.ScrollPanel) then return end
    
    for _, row in pairs(self.PlayerRows) do
        if IsValid(row) then
            row:Remove()
        end
    end
    self.PlayerRows = {}

    local players = player.GetAll()
    table.sort(players, function(a, b)
        return (a:GetNWString('swexp_rank', 'TRP') > b:GetNWString('swexp_rank', 'TRP'))
    end)

    for _, ply in ipairs(players) do
        self:CreateRow(ply)
    end
end

-- ============================================================
-- СОЗДАНИЕ СТРОКИ
-- ============================================================

function SCOREBOARD:CreateRow(ply)
    local isSelf = (ply == LocalPlayer())
    
    local row = vgui.Create('DPanel', self.ScrollPanel)
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, 2)
    row:SetTall(42)
    row:SetCursor('hand')
    row._open = false
    row._ply = ply

    local callsign = ply:GetNWString('swexp_callsign', 'RECRUIT')
    local cloneNum = ply:GetNWString('swexp_clone_number', 'CT-0000')
    local rankID = ply:GetNWString('swexp_rank', 'TRP')
    
    local rankName = rankID
    local rankColor = SWUI.Colors.Accent
    
    if SWExp and SWExp.Ranks then
        rankName = SWExp.Ranks:GetShortName(rankID) or rankID
        rankColor = SWExp.Ranks:GetColor(rankID) or SWUI.Colors.Accent
    end

    local samGroup = 'User'
    if ply.GetUserGroup then
        local ug = ply:GetUserGroup()
        if ug and ug ~= '' then
            samGroup = string.upper(string.sub(ug, 1, 1)) .. string.sub(ug, 2)
        end
    end

    row.Paint = function(pnl, w, h)
        local mainH = 42
        local open = pnl._open

        local bg = isSelf and Color(0, 40, 65, 76) or Color(0, 0, 0, 38)
        if pnl:IsHovered() and not open then
            bg = Color(0, 40, 65, 64)
        end

        local border = open and SWUI.Colors.AccentDim or (pnl:IsHovered() and SWUI.Colors.BorderHi or SWUI.Colors.Border)

        draw.RoundedBox(7, 0, 0, w, mainH, bg)
        surface.SetDrawColor(border)
        surface.DrawOutlinedRect(0, 0, w, mainH, 1)

        -- Те же позиции что и в header
        local xAvatar = 8 + 16
        local xRank = xAvatar + 32 + 72
        local xCallsign = xRank + 80
        local xNumber = xCallsign + 250
        local xPing = w - 90

        draw.SimpleText(rankName, 'SWUI.Mono', xRank, mainH / 2, rankColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(callsign, 'SWUI.Body', xCallsign, mainH / 2, SWUI.Colors.TextHi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(cloneNum, 'SWUI.MonoSmall', xNumber, mainH / 2, SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local ping = ply:Ping()
        local pingCol = ping <= 50 and SWUI.Colors.Green or (ping <= 100 and SWUI.Colors.Warn or SWUI.Colors.Red)
        draw.SimpleText(ping .. ' мс', 'SWUI.MonoSmall', xPing, mainH / 2, pingCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        if open then
            local py = mainH + 1
            local ph = 138

            surface.SetDrawColor(0, 0, 0, 64)
            surface.DrawRect(0, py, w, ph)
            surface.SetDrawColor(SWUI.Colors.Border)
            surface.DrawLine(0, py, w, py)

            local cx, cy = 70, py + 14
            local cw, ch = 180, 110

            draw.RoundedBox(8, cx, cy, cw, ch, ColorAlpha(rankColor, 15))
            surface.SetDrawColor(rankColor)
            surface.DrawOutlinedRect(cx, cy, cw, ch, 2)

            draw.SimpleText('USER', 'SWUI.Header', cx + cw / 2, cy + 32, rankColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(callsign, 'SWUI.Small', cx + cw / 2, cy + 70, SWUI.Colors.TextHi, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            draw.SimpleText(rankName .. ' · ' .. cloneNum, 'SWUI.Tiny', cx + cw / 2, cy + 86, SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

            local sx = cx + cw + 16
            local sy = cy

            local hours = 0
            if ply.GetUTime then
                hours = math.floor((ply:GetUTime() or 0) / 3600)
            end

            DrawIcon_Clock(sx, sy + 2, 14, SWUI.Colors.Text)
            draw.SimpleText('Время на сервере', 'SWUI.Small', sx + 20, sy + 7, SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(hours .. ' ч', 'SWUI.Mono', sx + 180, sy + 7, SWUI.Colors.TextHi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            sy = sy + 26
            DrawIcon_Group(sx, sy + 2, 14, SWUI.Colors.Text)
            draw.SimpleText('Группа', 'SWUI.Small', sx + 20, sy + 7, SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(samGroup, 'SWUI.Mono', sx + 180, sy + 7, SWUI.Colors.TextHi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            sy = sy + 26
            DrawIcon_Skull(sx, sy + 2, 14, SWUI.Colors.Text)
            draw.SimpleText('Убийств', 'SWUI.Small', sx + 20, sy + 7, SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(tostring(ply:Frags()), 'SWUI.Mono', sx + 180, sy + 7, SWUI.Colors.TextHi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            sy = sy + 26
            DrawIcon_Skull(sx, sy + 2, 14, SWUI.Colors.Red)
            draw.SimpleText('Смертей', 'SWUI.Small', sx + 20, sy + 7, SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(tostring(ply:Deaths()), 'SWUI.Mono', sx + 180, sy + 7, SWUI.Colors.TextHi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    local avatar = vgui.Create('AvatarImage', row)
    avatar:SetPos(8, 5)
    avatar:SetSize(32, 32)
    avatar:SetPlayer(ply, 64)

    row.OnMousePressed = function(pnl, code)
        if code == MOUSE_LEFT then
            if pnl._open then
                pnl._open = false
                pnl:SetTall(42)
            else
                if SCOREBOARD.OpenRow and IsValid(SCOREBOARD.OpenRow) then
                    SCOREBOARD.OpenRow._open = false
                    SCOREBOARD.OpenRow:SetTall(42)
                end
                pnl._open = true
                pnl:SetTall(42 + 140)
                SCOREBOARD.OpenRow = pnl
            end
        elseif code == MOUSE_RIGHT then
            SCOREBOARD:OpenContextMenu(ply, row)
        end
    end

    table.insert(self.PlayerRows, row)
end

-- ============================================================
-- STATUSBAR
-- ============================================================

function SCOREBOARD:CreateStatusbar()
    local bar = vgui.Create('DPanel', self.Window)
    bar:Dock(BOTTOM)
    bar:DockMargin(2, 0, 2, 2)  -- Отступы по бокам и снизу
    bar:SetTall(30)

    bar.Paint = function(pnl, w, h)
        draw.RoundedBox(0, 0, 0, w, h, SWUI.Colors.Panel2)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawLine(0, 0, w, 0)

        local x = 18

        draw.RoundedBox(0, x, h / 2 - 2, 5, 5, SWUI.Colors.Green)
        x = x + 7
        draw.SimpleText('СЕРВЕР ОНЛАЙН', 'SWUI.Small', x, h / 2, SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        x = x + 130

        draw.RoundedBox(0, x, h / 2 - 2, 5, 5, SWUI.Colors.Warn)
        x = x + 7
        draw.SimpleText(string.upper(game.GetMap()), 'SWUI.Small', x, h / 2, SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        x = x + 180

        draw.SimpleText(os.date('%H:%M'), 'SWUI.Small', x, h / 2, SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end

-- ============================================================
-- КОНТЕКСТНОЕ МЕНЮ
-- ============================================================


function SCOREBOARD:OpenContextMenu(ply, parentRow)
    local menu = DermaMenu()
    
    -- Делаем меню чуть шире для красоты
    menu:SetMinimumWidth(220)

    menu.Paint = function(pnl, w, h)
        draw.RoundedBox(8, 0, 0, w, h, SWUI.Colors.BorderHi)
        draw.RoundedBox(7, 1, 1, w - 2, h - 2, SWUI.Colors.Panel2)
    end

    local function HasPerm(priv)
        local lp = LocalPlayer()
        if not CAMI then
            if priv == 'swexp.scoreboard.editslots' then
                return lp:IsSuperAdmin()
            else
                return lp:IsAdmin() or lp:IsSuperAdmin()
            end
        end
        
        local ok = false
        CAMI.PlayerHasAccess(lp, priv, function(b) ok = b end)
        return ok
    end

    -- Добавлен аргумент itemColor для цвета текста
    local function AddCustomOption(text, itemColor, callback)
        local opt = menu:AddOption(text)
        opt:SetFont('SWUI.Body')
        opt:SetTextColor(itemColor)
        opt:SetTall(34) -- Увеличиваем высоту пункта (стандартно около 22)
        opt.DoClick = callback
        
        opt.Paint = function(pnl, w, h)
            if pnl:IsHovered() then
                -- Подсветка при наведении теперь берет цвет самого текста, но делает его полупрозрачным
                draw.RoundedBox(4, 4, 2, w - 8, h - 4, ColorAlpha(itemColor, 25))
            end
        end
        return opt
    end

    -- Зеленый для копирования
    AddCustomOption('Скопировать SteamID', SWUI.Colors.Green, function()
        SetClipboardText(ply:SteamID())
        chat.AddText(SWUI.Colors.Green, '[Scoreboard] ', SWUI.Colors.TextHi, 'Steam ID скопирован!')
    end)

    if HasPerm('swexp.scoreboard.openprofile') then
        -- Обычный цвет для профиля
        AddCustomOption('Steam профиль', SWUI.Colors.TextHi, function()
            gui.OpenURL('https://steamcommunity.com/profiles/' .. ply:SteamID64())
        end)
    end

    menu:AddSpacer()

    if HasPerm('swexp.scoreboard.bring') then
        -- Акцентный (синий/основной) для телепортации
        AddCustomOption('Телепортировать к себе', SWUI.Colors.Accent, function()
            netstream.Start('SWExp::Scoreboard_Bring', ply)
        end)
    end

    if HasPerm('swexp.scoreboard.goto') then
        AddCustomOption('Телепортироваться', SWUI.Colors.Accent, function()
            netstream.Start('SWExp::Scoreboard_Goto', ply)
        end)
    end

    menu:AddSpacer()

    if HasPerm('swexp.scoreboard.editcharacter') then
        AddCustomOption('Изменить звание', SWUI.Colors.Warn, function()
            self:OpenEditRankMenu(ply)
        end)
        AddCustomOption('Изменить позывной', SWUI.Colors.Warn, function()
            self:OpenEditCallsignMenu(ply)
        end)
        AddCustomOption('Изменить номер', SWUI.Colors.Warn, function()
            self:OpenEditNumberMenu(ply)
        end)
    end

    if HasPerm('swexp.scoreboard.editslots') then
        AddCustomOption('Изменить слоты', SWUI.Colors.Warn, function()
            self:OpenSlotMenu(ply)
        end)
    end

    for _, child in ipairs(menu:GetCanvas():GetChildren()) do
        if child:GetName() == "Panel" then 
            child.Paint = function(pnl, w, h)
                surface.SetDrawColor(SWUI.Colors.Border)
                surface.DrawLine(10, h / 2, w - 10, h / 2)
            end
        end
    end

    menu:Open()
end

-- ============================================================
-- МЕНЮ РЕДАКТИРОВАНИЯ
-- ============================================================

function SCOREBOARD:OpenEditNumberMenu(ply)
    local frame, content = SWUI.CreateWindow('ИЗМЕНЕНИЕ НОМЕРА', 400, 220)
    local n = ply:GetNWString('swexp_clone_number', 'CT-0000')
    local displayNum = string.gsub(n, "CT%-", "")

    local l1 = vgui.Create('DLabel', content)
    l1:SetPos(20, 20)
    l1:SetFont('SWUI.Body')
    l1:SetTextColor(SWUI.Colors.TextHi)
    l1:SetText('Новый номер (только цифры):')
    l1:SizeToContents()

    local i1 = SWUI.CreateInput(content, 20, 50, 360, 38, displayNum)
    i1.Entry.OnTextChanged = function(self)
        local text = self:GetValue()
        local filtered = string.gsub(text, "[^0-9]", "")
        if text ~= filtered then self:SetValue(filtered) self:SetCaretPos(#filtered) end
    end

    SWUI.CreateButton(content, 'СОХРАНИТЬ', 20, 110, 170, 40, 'accent', function()
        local num = string.Trim(i1:GetValue())
        if num == '' or not tonumber(num) then
            chat.AddText(SWUI.Colors.Red, '[Admin] ', SWUI.Colors.TextHi, 'Номер должен содержать только цифры!')
            return
        end
        netstream.Start('SWExp::Scoreboard_EditNumber', { player = ply, clone_number = num })
        frame:Close()
    end)

    SWUI.CreateButton(content, 'ОТМЕНА', 210, 110, 170, 40, 'ghost', function() frame:Close() end)
end

-- ============================================================
-- МЕНЮ ИЗМЕНЕНИЯ ПОЗЫВНОГО
-- ============================================================
function SCOREBOARD:OpenEditCallsignMenu(ply)
    local frame, content = SWUI.CreateWindow('ИЗМЕНЕНИЕ ПОЗЫВНОГО', 400, 220)
    local c = ply:GetNWString('swexp_callsign', 'RECRUIT')

    local l1 = vgui.Create('DLabel', content)
    l1:SetPos(20, 20)
    l1:SetFont('SWUI.Body')
    l1:SetTextColor(SWUI.Colors.TextHi)
    l1:SetText('Новый позывной:')
    l1:SizeToContents()

    local i1 = SWUI.CreateInput(content, 20, 50, 360, 38, c)

    SWUI.CreateButton(content, 'СОХРАНИТЬ', 20, 110, 170, 40, 'accent', function()
        local callsign = string.Trim(i1:GetValue())
        if callsign == '' then return end
        netstream.Start('SWExp::Scoreboard_EditCallsign', { player = ply, callsign = string.upper(callsign) })
        frame:Close()
    end)

    SWUI.CreateButton(content, 'ОТМЕНА', 210, 110, 170, 40, 'ghost', function() frame:Close() end)
end

-- ============================================================
-- МЕНЮ ИЗМЕНЕНИЯ ЗВАНИЯ
-- ============================================================
function SCOREBOARD:OpenEditRankMenu(ply)
    local frame, content = SWUI.CreateWindow('ИЗМЕНЕНИЕ ЗВАНИЯ', 400, 220)
    local currentRankID = ply:GetNWString('swexp_rank', 'TRP')

    local l1 = vgui.Create('DLabel', content)
    l1:SetPos(20, 20)
    l1:SetFont('SWUI.Body')
    l1:SetTextColor(SWUI.Colors.TextHi)
    l1:SetText('Новое звание:')
    l1:SizeToContents()

    local comboBtn = vgui.Create('DButton', content)
    comboBtn:SetPos(20, 50)
    comboBtn:SetSize(360, 38)
    comboBtn:SetText('')
    
    local function GetRankName(id)
        if SWExp.Ranks and SWExp.Ranks:Get(id) then return SWExp.Ranks:Get(id).name .. ' (' .. id .. ')' end
        return id
    end
    
    comboBtn.Paint = function(self, w, h)
        local hov = self:IsHovered()
        SWUI.DrawRoundedRect(0, 0, w, h, 6, hov and Color(0, 40, 65, 120) or Color(0, 0, 0, 120))
        surface.SetDrawColor(hov and SWUI.Colors.BorderHi or SWUI.Colors.Border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(GetRankName(currentRankID), 'SWUI.Body', 16, h/2, SWUI.Colors.TextHi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText('▼', 'SWUI.Small', w - 20, h/2, SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    comboBtn.DoClick = function(self)
        if SWUI.PlaySound and SWUI.Sounds then SWUI.PlaySound(SWUI.Sounds.Click) end
        local menu = DermaMenu()
        menu:SetMinimumWidth(self:GetWide())
        menu.Paint = function(pnl, w, h)
            draw.RoundedBox(8, 0, 0, w, h, SWUI.Colors.BorderHi)
            draw.RoundedBox(7, 1, 1, w - 2, h - 2, SWUI.Colors.Panel2)
        end
        
        local sortedRanks = {}
        if SWExp.Ranks and SWExp.Ranks.List then
            for _, rank in ipairs(SWExp.Ranks.List) do table.insert(sortedRanks, rank) end
            table.sort(sortedRanks, function(a, b) return (a.sortOrder or 99) < (b.sortOrder or 99) end)
        else
            local fb = {'TRP', 'CPL', 'SGT', 'SSGT', 'SGM', 'LT', 'CPT', 'MAJ', 'CMDR', 'MCMDR'}
            for i, id in ipairs(fb) do table.insert(sortedRanks, {id = id, name = id, sortOrder = i}) end
        end
        
        for _, rank in ipairs(sortedRanks) do
            local opt = menu:AddOption(rank.name .. ' (' .. rank.id .. ')', function()
                currentRankID = rank.id
                if SWUI.PlaySound and SWUI.Sounds then SWUI.PlaySound(SWUI.Sounds.Select) end
            end)
            opt:SetFont('SWUI.Body')
            opt:SetTextColor(rank.color or SWUI.Colors.TextHi)
            opt:SetTall(34)
            opt.Paint = function(pnl, w, h)
                if pnl:IsHovered() then draw.RoundedBox(4, 4, 2, w - 8, h - 4, ColorAlpha(rank.color or SWUI.Colors.Accent, 25)) end
            end
        end
        local x, y = self:LocalToScreen(0, self:GetTall() + 2)
        menu:Open(x, y)
    end

    SWUI.CreateButton(content, 'СОХРАНИТЬ', 20, 110, 170, 40, 'accent', function()
        netstream.Start('SWExp::Scoreboard_EditRank', { player = ply, rank = currentRankID })
        frame:Close()
    end)

    SWUI.CreateButton(content, 'ОТМЕНА', 210, 110, 170, 40, 'ghost', function() frame:Close() end)
end

function SCOREBOARD:OpenSlotMenu(ply)
    local frame, content = SWUI.CreateWindow('СЛОТЫ', 450, 280)

    -- Пытаемся получить из NWInt, если нет - из переменной, fallback = 1
    local cur = ply:GetNWInt('swexp_character_slots', ply.SWExp_CharSlots or 1)

    local l1 = vgui.Create('DLabel', content)
    l1:SetPos(20, 20)
    l1:SetFont('SWUI.Body')
    l1:SetTextColor(SWUI.Colors.TextHi)
    l1:SetText('Текущее количество слотов: ' .. cur)
    l1:SizeToContents()
    
    local l2 = vgui.Create('DLabel', content)
    l2:SetPos(20, 70)
    l2:SetFont('SWUI.Body')
    l2:SetTextColor(SWUI.Colors.TextHi)
    l2:SetText('Новое количество:')
    l2:SizeToContents()

    local slider = vgui.Create('DNumSlider', content)
    slider:SetPos(20, 60)
    slider:SetSize(410, 50)
    slider:SetMin(1)
    slider:SetMax(10)
    slider:SetDecimals(0)
    slider:SetValue(cur)

    SWUI.CreateButton(content, 'СОХРАНИТЬ', 20, 165, 195, 45, 'accent', function()
        netstream.Start('SWExp::Scoreboard_EditSlots', {
            player = ply,
            slots = math.floor(slider:GetValue())
        })
        frame:Close()
    end)

    SWUI.CreateButton(content, 'ОТМЕНА', 235, 165, 195, 45, 'ghost', function()
        frame:Close()
    end)
end

-- ============================================================
-- ПОКАЗАТЬ/СКРЫТЬ
-- ============================================================

function SCOREBOARD:Show()
    if not IsValid(self.Frame) then
        self:Create()
    else
        -- Если интерфейс уже был создан, просто проигрываем анимацию заново
        if SWUI.Animations and SWUI.Animations.Presets then
            SWUI.Animations.Presets.WindowOpen(self.Window, 0.35)
            
            -- Сбрасываем и анимируем прозрачность главного черного фона
            self.Frame:SetAlpha(0)
            self.Frame:AlphaTo(255, 0.35, 0)
        end
    end
    
    self:PopulateList()
    self.Frame:SetVisible(true)
    self.Frame:MakePopup()
end

function SCOREBOARD:Hide()
    if IsValid(self.Frame) then
        self.Frame:SetKeyboardInputEnabled(false)
        
        if SWUI.Animations and SWUI.Animations.Presets then
            -- Проигрываем анимацию закрытия, а только потом полностью скрываем интерфейс
            SWUI.Animations.Presets.WindowClose(self.Window, 0.25, function()
                if IsValid(self.Frame) then
                    self.Frame:SetVisible(false)
                end
            end)
            
            -- Плавно скрываем черный фон
            self.Frame:AlphaTo(0, 0.25, 0)
        else
            -- Запасной вариант на случай, если анимации отключены
            self.Frame:SetVisible(false)
        end
    end
end

-- ============================================================
-- HOOKS
-- ============================================================

hook.Add('ScoreboardShow', 'SWExp::Scoreboard', function()
    SCOREBOARD:Show()
    return true
end)

hook.Add('ScoreboardHide', 'SWExp::Scoreboard', function()
    SCOREBOARD:Hide()
    return true
end)

MsgC(Color(0, 238, 119), '[ SWExp ] ', color_white, 'Scoreboard загружен.\n')