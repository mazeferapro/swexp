-- ============================================================
-- Star Wars: Expedition — UI Library
-- libs/pawsui/swexp_ui.lua
-- 
-- Визуальный стиль:
--   Accent:    #00b8ff  (0, 184, 255)
--   Warn:      #ff8800  (255, 136, 0)
--   Green:     #00ee77  (0, 238, 119)
--   Panel BG:  #0b0f14
--   Panel2:    #0e1319
--   Border:    #1a3348
--   Border hi: #2a6080
--   Text:      #a8ccdc
--   Text dim:  #3a6070
--   Text hi:   #e4f4ff
-- ============================================================

SWUI = SWUI or {}

-- ============================================================
-- ЦВЕТА
-- ============================================================

SWUI.Colors = {
    Accent      = Color(0,   184, 255),
    AccentDim   = Color(0,   79,  110),
    Warn        = Color(255, 136, 0  ),
    WarnDim     = Color(122, 64,  0  ),
    Green       = Color(0,   238, 119),
    Red         = Color(255, 51,  34 ),

    PanelBG     = Color(11,  15,  20 ),
    Panel2      = Color(14,  19,  25 ),
    PanelBG_A   = Color(6,   12,  18, 184),  -- полупрозрачный для HUD

    Border      = Color(26,  51,  72 ),
    BorderHi    = Color(42,  96,  128),

    Text        = Color(168, 204, 220),
    TextDim     = Color(58,  96,  112),
    TextHi      = Color(228, 244, 255),

    Black       = Color(0,   0,   0  ),
    White       = Color(255, 255, 255),
    Transparent = Color(0,   0,   0,  0),
}

-- ============================================================
-- ШРИФТЫ — масштабируются под разрешение экрана
-- ============================================================

local function SWUI_CreateFonts()
    local function S(n) return math.max(1, math.Round(n * (ScrH() / 1080))) end
    local FONT = 'Exo 2'
    local MONO = 'Exo 2'

    surface.CreateFont('SWUI.Title',     { font=FONT, size=S(28), weight=800, extended=true })
    surface.CreateFont('SWUI.Header',    { font=FONT, size=S(22), weight=700, extended=true })
    surface.CreateFont('SWUI.Body',      { font=FONT, size=S(18), weight=500, extended=true })
    surface.CreateFont('SWUI.Small',     { font=FONT, size=S(15), weight=600, extended=true })
    surface.CreateFont('SWUI.Tiny',      { font=FONT, size=S(13), weight=600, extended=true })
    surface.CreateFont('SWUI.Mono',      { font=MONO, size=S(17), weight=700, extended=true })
    surface.CreateFont('SWUI.MonoLarge', { font=MONO, size=S(30), weight=700, extended=true })
    surface.CreateFont('SWUI.MonoSmall', { font=MONO, size=S(14), weight=700, extended=true })
end

SWUI_CreateFonts()
hook.Add('OnScreenSizeChanged', 'SWUI::RecreateFonts', SWUI_CreateFonts)

-- ============================================================
-- РИСОВАНИЕ: утилиты
-- ============================================================

-- Закруглённый прямоугольник с заливкой
function SWUI.DrawRoundedRect(x, y, w, h, r, col)
    draw.RoundedBox(r, x, y, w, h, col)
end

-- Универсальная панель: фон + скруглённая граница (рисуется ВНУТРИ)
function SWUI.DrawPanel(x, y, w, h, r, bg_col, border_col, border_w)
    border_w   = border_w   or 1
    border_col = border_col or SWUI.Colors.Accent
    bg_col     = bg_col     or SWUI.Colors.PanelBG
    -- Сначала фон
    draw.RoundedBox(r, x, y, w, h, bg_col)
    -- Граница внутри через surface.DrawLine по периметру
    surface.SetDrawColor(border_col)
    for i = 0, border_w - 1 do
        local ox = x + i
        local oy = y + i
        local ow = w - i * 2
        local oh = h - i * 2
        surface.DrawLine(ox + r,      oy,           ox + ow - r,  oy)
        surface.DrawLine(ox + r,      oy + oh,      ox + ow - r,  oy + oh)
        surface.DrawLine(ox,          oy + r,       ox,           oy + oh - r)
        surface.DrawLine(ox + ow,     oy + r,       ox + ow,      oy + oh - r)
    end
end

-- Горизонтальная линия-разделитель
function SWUI.DrawDivider(x, y, w, col)
    col = col or SWUI.Colors.Border
    surface.SetDrawColor(col)
    surface.DrawLine(x, y, x + w, y)
end

-- Текст с выравниванием (обёртка draw.SimpleText)
function SWUI.DrawText(text, font, x, y, col, alignH, alignV)
    draw.SimpleText(text, font, x, y, col, alignH or TEXT_ALIGN_LEFT, alignV or TEXT_ALIGN_TOP)
end

-- Текст с тенью
function SWUI.DrawTextShadow(text, font, x, y, col, alignH, alignV, shadow_offset, shadow_alpha)
    shadow_offset = shadow_offset or 1
    shadow_alpha  = shadow_alpha  or 100
    draw.SimpleText(text, font, x + shadow_offset, y + shadow_offset,
        Color(0, 0, 0, shadow_alpha), alignH or TEXT_ALIGN_LEFT, alignV or TEXT_ALIGN_TOP)
    draw.SimpleText(text, font, x, y, col, alignH or TEXT_ALIGN_LEFT, alignV or TEXT_ALIGN_TOP)
end

-- Прямоугольник с градиентом (горизонтальный)
function SWUI.DrawGradientH(x, y, w, h, colLeft, colRight)
    surface.SetDrawColor(colLeft)
    surface.DrawRect(x, y, w / 2, h)
    -- Простая эмуляция через два прямоугольника
    surface.SetDrawColor(colRight)
    surface.DrawRect(x + w / 2, y, w / 2, h)
end

-- Полупрозрачный оверлей поверх всего
function SWUI.DrawOverlay(alpha)
    surface.SetDrawColor(0, 0, 0, alpha or 160)
    surface.DrawRect(0, 0, ScrW(), ScrH())
end

-- ============================================================
-- КОМПОНЕНТ: ОКНО (Window)
-- ============================================================
-- Создаёт базовое окно в стиле SWExp с titlebar
-- Параметры:
--   title    string
--   w, h     number
--   parent   Panel (опционально)
--   accent   Color (опционально, по умолчанию Warn — оранжевый, как в инвентаре)
-- Возвращает: frame

function SWUI.CreateWindow(title, w, h, parent, accent)
    accent = accent or SWUI.Colors.Warn

    local R      = 16
    local TBAR_H = 44
    local BORDER = 1  -- толщина границы

    -- Фрейм на 2px больше чтобы внешний RoundedBox не обрезался
    local frame = vgui.Create('DFrame', parent)
    frame:SetSize(w + BORDER * 2, h + BORDER * 2)
    frame:Center()
    frame:SetTitle('')
    frame:SetDraggable(true)
    frame:ShowCloseButton(false)
    frame:MakePopup()

    function frame:Paint(pw, ph)
        -- Точно как компас: внешний = синий, внутренний = фон
        draw.RoundedBoxEx(R + BORDER, 0,      0,      pw,              ph,              Color(0, 184, 255, 255), true, true, false, false)
        draw.RoundedBoxEx(R,          BORDER, BORDER, pw - BORDER * 2, ph - BORDER * 2, Color(6, 12, 18, 255), true, true, false, false)

        -- Titlebar фон
        draw.RoundedBox(R, BORDER, BORDER, pw - BORDER * 2, TBAR_H, Color(12, 18, 26, 255))
        surface.SetDrawColor(12, 18, 26, 255)
        surface.DrawRect(BORDER, BORDER + TBAR_H - R, pw - BORDER * 2, R)

        -- Accent линия под titlebar
        surface.SetDrawColor(accent)
        surface.DrawRect(BORDER, BORDER + TBAR_H - 2, pw - BORDER * 2, 2)

        -- Заголовок
        draw.SimpleText(string.upper(title), 'SWUI.Header', BORDER + 16, BORDER + TBAR_H / 2,
            SWUI.Colors.TextHi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    end



    -- Кнопка закрытия
    local closeBtn = vgui.Create('DButton', frame)
    closeBtn:SetPos(w - 30, BORDER + 9)
    closeBtn:SetSize(26, 26)
    closeBtn:SetText('')
    closeBtn.Paint = function(self, bw, bh)
        local hov = self:IsHovered()
        draw.RoundedBox(5, 0, 0, bw, bh, hov and Color(60,16,12) or Color(25,25,25))
        draw.SimpleText('×', 'SWUI.Header', bw/2, bh/2,
            hov and SWUI.Colors.Red or Color(120,120,120),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    closeBtn.DoClick = function() frame:Close() end

    -- Контент-панель (смещена на BORDER)
    local content = vgui.Create('DPanel', frame)
    content:SetPos(BORDER, BORDER + TBAR_H)
    content:SetSize(w, h - TBAR_H)
    content.Paint = function(self, pw, ph) end
    frame.Content = content

    return frame, content
end

-- ============================================================
-- КОМПОНЕНТ: КНОПКА (Button)
-- ============================================================
-- style: 'accent' | 'warn' | 'ghost' | 'danger'

function SWUI.CreateButton(parent, text, x, y, w, h, style, onClick)
    style = style or 'accent'

    local colMap = {
        accent = { bg = Color(0, 40, 65),   bgHov = Color(0, 55, 85),   border = SWUI.Colors.AccentDim, borderHov = SWUI.Colors.Accent, text = SWUI.Colors.Accent  },
        warn   = { bg = Color(40, 25, 0),   bgHov = Color(55, 35, 0),   border = SWUI.Colors.WarnDim,   borderHov = SWUI.Colors.Warn,   text = SWUI.Colors.Warn    },
        ghost  = { bg = Color(0, 0, 0, 0),  bgHov = Color(20, 30, 40),  border = SWUI.Colors.Border,    borderHov = SWUI.Colors.BorderHi, text = SWUI.Colors.Text  },
        danger = { bg = Color(40, 10, 8),   bgHov = Color(60, 16, 12),  border = Color(80, 30, 25),     borderHov = SWUI.Colors.Red,    text = SWUI.Colors.Red     },
    }
    local c = colMap[style] or colMap.accent

    local btn = vgui.Create('DButton', parent)
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetText('')

    btn.Paint = function(self, bw, bh)
        local bg  = self:IsHovered() and c.bgHov  or c.bg
        local brd = self:IsHovered() and c.borderHov or c.border
        SWUI.DrawRoundedRect(0, 0, bw, bh, 6, bg)
        surface.SetDrawColor(brd)
        surface.DrawOutlinedRect(0, 0, bw, bh, 1)
        SWUI.DrawText(text, 'SWUI.Body', bw / 2, bh / 2, c.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    if onClick then btn.DoClick = onClick end
    return btn
end

-- ============================================================
-- КОМПОНЕНТ: LABEL (StatLabel)
-- ============================================================
-- Рисует пару: [dim label] [hi value] — как «ТЛ  2»

function SWUI.CreateStatLabel(parent, label, value, x, y)
    local pnl = vgui.Create('DPanel', parent)
    pnl:SetPos(x, y)
    pnl:SetSize(200, 18)
    pnl.Paint = function(self, pw, ph)
        SWUI.DrawText(label, 'SWUI.Tiny', 0, ph / 2, SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        SWUI.DrawText(tostring(value or '—'), 'SWUI.Mono', pw, ph / 2, SWUI.Colors.TextHi, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    function pnl:SetValue(v)
        value = v
    end
    return pnl
end

-- ============================================================
-- КОМПОНЕНТ: ПОЛОСА ПРОГРЕССА (ProgressBar)
-- ============================================================
-- col: цвет заливки (Color), по умолчанию зелёный

function SWUI.CreateProgressBar(parent, x, y, w, h, col)
    col = col or SWUI.Colors.Green

    local pnl = vgui.Create('DPanel', parent)
    pnl:SetPos(x, y)
    pnl:SetSize(w, h)
    pnl._frac = 1.0

    pnl.Paint = function(self, pw, ph)
        -- Track
        SWUI.DrawRoundedRect(0, 0, pw, ph, ph / 2, Color(255, 255, 255, 15))
        -- Fill
        local fw = math.max(ph, math.Round(pw * self._frac))
        SWUI.DrawRoundedRect(0, 0, fw, ph, ph / 2, col)
    end

    function pnl:SetFraction(f)
        self._frac = math.Clamp(f, 0, 1)
    end

    function pnl:SetValue(cur, max)
        if max and max > 0 then
            self:SetFraction(cur / max)
        end
    end

    return pnl
end

-- ============================================================
-- КОМПОНЕНТ: SECTION HEADER
-- ============================================================
-- Горизонтальный заголовок секции с разделительной линией снизу

function SWUI.CreateSectionHeader(parent, text, x, y, w)
    local pnl = vgui.Create('DPanel', parent)
    pnl:SetPos(x, y)
    pnl:SetSize(w, 30)
    pnl.Paint = function(self, pw, ph)
        SWUI.DrawRoundedRect(0, 0, pw, ph, 0, SWUI.Colors.Panel2)
        SWUI.DrawText(text, 'SWUI.Small', 14, ph / 2, SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawLine(0, ph - 1, pw, ph - 1)
    end
    return pnl
end

-- ============================================================
-- КОМПОНЕНТ: TABS (TabBar)
-- ============================================================
-- tabs: { {label='...', id='...'}, ... }
-- onChange: function(id)

function SWUI.CreateTabBar(parent, tabs, x, y, w, h, onChange)
    local bar = vgui.Create('DPanel', parent)
    bar:SetPos(x, y)
    bar:SetSize(w, h)

    local active = tabs[1] and tabs[1].id
    local buttons = {}
    local tabW = math.floor(w / #tabs)

    bar.Paint = function(self, pw, ph)
        SWUI.DrawRoundedRect(0, 0, pw, ph, 0, SWUI.Colors.Panel2)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawLine(0, ph - 1, pw, ph - 1)
    end

    for i, tab in ipairs(tabs) do
        local btn = vgui.Create('DButton', bar)
        btn:SetPos((i - 1) * tabW, 0)
        btn:SetSize(tabW, h)
        btn:SetText('')

        btn.Paint = function(self, bw, bh)
            local isActive = (active == tab.id)
            local col = isActive and SWUI.Colors.Accent or (self:IsHovered() and SWUI.Colors.TextHi or SWUI.Colors.Text)
            if self:IsHovered() and not isActive then
                surface.SetDrawColor(0, 40, 65, 120)
                surface.DrawRect(0, 0, bw, bh)
            end

            if isActive then
                surface.SetDrawColor(SWUI.Colors.Accent)
                surface.DrawRect(0, bh - 2, bw, 2)
            end

            SWUI.DrawText(tab.label, 'SWUI.Small', bw / 2, bh / 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        btn.DoClick = function()
            active = tab.id
            if onChange then onChange(tab.id) end
        end

        buttons[tab.id] = btn
    end

    function bar:SetActive(id)
        active = id
    end

    return bar
end

-- ============================================================
-- КОМПОНЕНТ: BADGE (маленький тег)
-- ============================================================
-- style: 'accent' | 'warn' | 'green' | 'dim'

function SWUI.DrawBadge(text, x, y, style)
    style = style or 'dim'
    local map = {
        accent = { bg = Color(0, 40, 65, 200),   text = SWUI.Colors.Accent },
        warn   = { bg = Color(40, 25, 0, 200),   text = SWUI.Colors.Warn   },
        green  = { bg = Color(0, 30, 15, 200),   text = SWUI.Colors.Green  },
        dim    = { bg = Color(20, 20, 20, 180),  text = SWUI.Colors.TextDim},
    }
    local c = map[style] or map.dim

    surface.SetFont('SWUI.Tiny')
    local tw, th = surface.GetTextSize(text)
    local pw = tw + 10
    local ph = 16

    SWUI.DrawRoundedRect(x, y, pw, ph, 3, c.bg)
    surface.SetDrawColor(c.text.r, c.text.g, c.text.b, 80)
    surface.DrawOutlinedRect(x, y, pw, ph, 1)
    SWUI.DrawText(text, 'SWUI.Tiny', x + pw / 2, y + ph / 2, c.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-- ============================================================
-- КОМПОНЕНТ: SLOT TILE (слот инвентаря/оружия)
-- ============================================================
-- size: пиксельный размер квадрата
-- filled: bool
-- Возвращает панель, на которой можно рисовать иконку

function SWUI.CreateSlotTile(parent, x, y, size, filled, onClick)
    local tile = vgui.Create('DButton', parent)
    tile:SetPos(x, y)
    tile:SetSize(size, size)
    tile:SetText('')
    tile._filled = filled or false

    tile.Paint = function(self, pw, ph)
        local hov = self:IsHovered()

        if self._filled then
            local bg  = hov and Color(0, 40, 65) or Color(26, 42, 54)
            local brd = hov and SWUI.Colors.BorderHi or SWUI.Colors.Border
            SWUI.DrawRoundedRect(0, 0, pw, ph, 8, bg)
            surface.SetDrawColor(brd)
            surface.DrawOutlinedRect(0, 0, pw, ph, 1)
            -- subtle gradient overlay
        else
            local bg  = hov and Color(0, 30, 50, 100) or Color(0, 0, 0, 100)
            local brd = hov and SWUI.Colors.BorderHi or SWUI.Colors.Border
            SWUI.DrawRoundedRect(0, 0, pw, ph, 8, bg)
            surface.SetDrawColor(brd)
            surface.DrawOutlinedRect(0, 0, pw, ph, 1)
            SWUI.DrawText('ПУСТО', 'SWUI.Tiny', pw / 2, ph / 2, SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    if onClick then tile.DoClick = onClick end
    return tile
end

-- ============================================================
-- КОМПОНЕНТ: TITLEBAR RESOURCE BADGE
-- ============================================================
-- Рисует бейдж материалов/исследований в titlebar (как в ассемблере)

function SWUI.DrawResourceBadge(x, y, dotCol, labelText, value)
    local w = 90
    local h = 26

    -- bg
    surface.SetDrawColor(dotCol.r, dotCol.g, dotCol.b, 15)
    surface.DrawRect(x, y, w, h)
    surface.SetDrawColor(dotCol.r, dotCol.g, dotCol.b, 50)
    surface.DrawOutlinedRect(x, y, w, h, 1)

    -- dot
    surface.SetDrawColor(dotCol)
    local dotX = x + 10
    local dotY = y + h / 2
    surface.DrawRect(dotX - 3, dotY - 3, 7, 7)

    -- label
    SWUI.DrawText(labelText, 'SWUI.Tiny', dotX + 10, y + h / 2, SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- value
    SWUI.DrawText(tostring(value), 'SWUI.Mono', x + w - 8, y + h / 2, dotCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

-- ============================================================
-- КОМПОНЕНТ: СПИСОК (ScrollList)
-- ============================================================
-- Возвращает DScrollPanel со стилизованным scrollbar

function SWUI.CreateScrollList(parent, x, y, w, h)
    local scroll = vgui.Create('DScrollPanel', parent)
    scroll:SetPos(x, y)
    scroll:SetSize(w, h)

    scroll.Paint = function(self, pw, ph)
        -- пустой фон
    end

    local sbar = scroll:GetVBar()
    sbar:SetWide(4)
    sbar.Paint = function(self, sw, sh)
        SWUI.DrawRoundedRect(0, 0, sw, sh, 2, Color(255, 255, 255, 5))
    end
    sbar.btnUp.Paint   = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(self, sw, sh)
        SWUI.DrawRoundedRect(0, 0, sw, sh, 2, SWUI.Colors.AccentDim)
    end

    return scroll
end

-- ============================================================
-- КОМПОНЕНТ: ROW ITEM (строка рецепта/предмета в списке)
-- ============================================================
-- selected: bool
-- locked:   bool

function SWUI.CreateListRow(parent, h, selected, locked, onClick)
    local row = vgui.Create('DPanel', parent)
    row:SetTall(h)
    row._selected = selected or false
    row._locked   = locked   or false
    row:SetCursor('hand')
    row.OnMousePressed = function(self, mc)
        if mc == MOUSE_LEFT and onClick then onClick() end
    end

    row.Paint = function(self, pw, ph)
        local hov  = self:IsHovered() and not self._locked
        local sel  = self._selected

        local bg, brd
        if sel then
            bg  = Color(0, 40, 65, 220)
            brd = SWUI.Colors.Accent
        elseif hov then
            bg  = Color(0, 40, 65, 220)
            brd = SWUI.Colors.BorderHi
        else
            bg  = Color(0, 0, 0, 100)
            brd = SWUI.Colors.Border
        end

        if self._locked then
            bg  = Color(0, 0, 0, 60)
            brd = SWUI.Colors.Border
        end

        SWUI.DrawRoundedRect(0, 0, pw, ph, 8, bg)
        surface.SetDrawColor(brd)
        surface.DrawOutlinedRect(0, 0, pw, ph, 1)

        if sel then
        end
    end

    if onClick then row.DoClick = onClick end
    return row
end

-- ============================================================
-- КОМПОНЕНТ: INPUT (TextEntry)
-- ============================================================

function SWUI.CreateInput(parent, x, y, w, h, placeholder)
    local wrap = vgui.Create('DPanel', parent)
    wrap:SetPos(x, y)
    wrap:SetSize(w, h)
    wrap.Paint = function(self, pw, ph)
        SWUI.DrawRoundedRect(0, 0, pw, ph, 6, Color(0, 0, 0, 120))
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawOutlinedRect(0, 0, pw, ph, 1)
    end

    local entry = vgui.Create('DTextEntry', wrap)
    entry:SetPos(8, 0)
    entry:SetSize(w - 16, h)
    entry:SetFont('SWUI.Body')
    entry:SetTextColor(SWUI.Colors.TextHi)
    entry:SetCursorColor(SWUI.Colors.Accent)
    entry:SetPlaceholderText(placeholder or '')
    entry:SetPlaceholderColor(SWUI.Colors.TextDim)
    entry:SetPaintBackground(false)

    wrap.Entry = entry

    function wrap:GetValue() return entry:GetValue() end
    function wrap:SetValue(v) entry:SetValue(v) end

    return wrap
end

-- ============================================================
-- КОМПОНЕНТ: CATEGORY NAV (левая панель категорий)
-- ============================================================
-- items: { {id, icon, label, count}, ... }
-- onChange: function(id)

function SWUI.CreateCategoryNav(parent, items, x, y, w, h, onChange, cornerRadius)
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

    for _, item in ipairs(items) do
        local btn = vgui.Create('DPanel', nav)
        btn:SetPos(0, yOff)
        btn:SetSize(w, rowH)
        btn:SetCursor('hand')
        btn._hov = false
        btn.OnCursorEntered = function(self) self._hov = true end
        btn.OnCursorExited  = function(self) self._hov = false end
        btn.OnMousePressed  = function(self, mc)
            if mc == MOUSE_LEFT then self:DoClick() end
        end
        btn.DoClick = function() end

        btn.Paint = function(self, bw, bh)
            local isActive = (active == item.id)
            local hov = self._hov

            if isActive then
                surface.SetDrawColor(SWUI.Colors.Accent)
                surface.DrawRect(0, 0, 3, bh)
            elseif hov then
                surface.SetDrawColor(0, 40, 65, 220)
                surface.DrawRect(0, 0, bw, bh)
            end

            local tc = isActive and SWUI.Colors.Accent or (hov and SWUI.Colors.TextHi or SWUI.Colors.Text)

            -- icon
            SWUI.DrawText(item.icon or '', 'SWUI.Body', 16, bh / 2, tc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            -- label
            SWUI.DrawText(string.upper(item.label), 'SWUI.Small', 42, bh / 2, tc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            -- count badge
            if item.count and item.count > 0 then
                local cStr = tostring(item.count)
                surface.SetFont('SWUI.MonoSmall')
                local cw = surface.GetTextSize(cStr) + 10
                local cx = bw - cw - 10
                local cy = bh / 2 - 8

                local badgeBg = isActive and Color(0, 184, 255, 25) or Color(255, 255, 255, 12)
                SWUI.DrawRoundedRect(cx, cy, cw, 16, 3, badgeBg)
                SWUI.DrawText(cStr, 'SWUI.MonoSmall', cx + cw / 2, bh / 2, tc, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        btn.DoClick = function()
            active = item.id
            if onChange then onChange(item.id) end
        end

        yOff = yOff + rowH + 2
    end

    function nav:SetActive(id)
        active = id
    end

    return nav
end

-- ============================================================
-- КОМПОНЕНТ: TOOLTIP
-- ============================================================
-- Глобальный tooltip — вызывать в HUDPaint или аналогичном хуке

SWUI._tooltip = {
    visible = false,
    name    = '',
    sub     = '',
    desc    = '',
    stats   = {},
}

function SWUI.ShowTooltip(name, sub, desc, stats)
    SWUI._tooltip.visible = true
    SWUI._tooltip.name    = name  or ''
    SWUI._tooltip.sub     = sub   or ''
    SWUI._tooltip.desc    = desc  or ''
    SWUI._tooltip.stats   = stats or {}
end

function SWUI.HideTooltip()
    SWUI._tooltip.visible = false
end

function SWUI.DrawTooltip()
    local tt = SWUI._tooltip
    if not tt.visible then return end

    local mx, my = gui.MousePos()
    local pw = 220
    local ph = 20 + (tt.name ~= '' and 20 or 0) + (tt.sub ~= '' and 16 or 0) + (tt.desc ~= '' and 30 or 0) + #tt.stats * 18

    local x = mx + 14
    local y = my + 14
    if x + pw > ScrW() then x = mx - pw - 6 end
    if y + ph > ScrH() then y = my - ph - 6 end

    -- bg
    SWUI.DrawRoundedRect(x, y, pw, ph, 8, Color(11, 15, 20, 240))
    surface.SetDrawColor(SWUI.Colors.BorderHi)
    surface.DrawOutlinedRect(x, y, pw, ph, 1)

    local cy = y + 10

    if tt.name ~= '' then
        SWUI.DrawText(tt.name, 'SWUI.Header', x + 10, cy, SWUI.Colors.TextHi)
        cy = cy + 20
    end

    if tt.sub ~= '' then
        SWUI.DrawText(tt.sub, 'SWUI.Tiny', x + 10, cy, SWUI.Colors.TextDim)
        cy = cy + 16
    end

    if tt.desc ~= '' then
        -- Wrap text вручную
        draw.DrawText(tt.desc, 'SWUI.Small', x + 10, cy, SWUI.Colors.Text, TEXT_ALIGN_LEFT)
        cy = cy + 30
    end

    for _, stat in ipairs(tt.stats) do
        SWUI.DrawText(stat.label, 'SWUI.Tiny', x + 10,      cy, SWUI.Colors.TextDim)
        SWUI.DrawText(stat.value, 'SWUI.Mono', x + pw - 10, cy, stat.col or SWUI.Colors.TextHi, TEXT_ALIGN_RIGHT)
        cy = cy + 18
    end
end

-- Регистрируем отрисовку тултипа поверх всего
hook.Add('DrawOverlay', 'SWUI.Tooltip', function()
    SWUI.DrawTooltip()
end)

-- ============================================================
-- Star Wars: Expedition — UI Sound System
-- libs/swexp_ui_sounds.lua
--
-- Подключение: include('libs/swexp_ui_sounds.lua') в shared.lua
-- на клиенте (после swexp_ui.lua)
-- ============================================================

if not CLIENT then return end

-- ============================================================
-- ЗВУКИ — используем стандартные Half-Life 2 / GMod звуки
-- которые точно есть в любой сборке
-- ============================================================

SWUI.Sounds = {
    -- Наведение курсора
    Hover    = 'uisfx/sound-8.wav',   -- мягкий тихий тик
    -- Клик / подтверждение
    Click    = 'uisfx/sound-1.wav',   -- чёткий клик
    -- Клик кнопки опасного действия (danger / warn стиль)
    ClickWarn = 'uisfx/sound-1.wav',  -- более жёсткий
    -- Открытие окна
    Open     = 'uisfx/sound-3.wav',    -- «появление»
    -- Закрытие окна
    Close    = 'uisfx/sound-4.wav',   -- «схлопывание»
    -- Смена вкладки / таба
    Tab      = 'uisfx/sound-1.wav',   -- лёгкий переключатель
    -- Выбор строки в списке
    Select   = 'uisfx/sound-1.wav',   -- мягкий выбор
    -- Ошибка / заблокировано
    Denied   = 'uisfx/sound-1.wav',    -- низкий, запрещающий
    -- Успешное действие (применить, экипировать)
    Success  = 'uisfx/sound-1.wav',   -- позитивный
}

-- Громкость по умолчанию (можно будет вынести в настройки)
SWUI.SoundVolume = 1

-- ============================================================
-- Вспомогательная функция воспроизведения
-- ============================================================

function SWUI.PlaySound(snd, vol)
    surface.PlaySound(snd)
    -- surface.PlaySound не поддерживает громкость напрямую,
    -- поэтому используем EmitSound через LocalPlayer если доступен
    local ply = IsValid(LocalPlayer()) and LocalPlayer()
    if ply then
        ply:EmitSound(snd, 75, 100, vol or SWUI.SoundVolume)
    end
end

-- ============================================================
-- Патчим SWUI компоненты — добавляем звуки к уже существующим
-- функциям создания элементов
-- ============================================================

-- ── Сохраняем оригиналы ─────────────────────────────────────

local _CreateWindow  = SWUI.CreateWindow
local _CreateButton  = SWUI.CreateButton
local _CreateTabBar  = SWUI.CreateTabBar
local _CreateListRow = SWUI.CreateListRow
local _CreateSlotTile = SWUI.CreateSlotTile
local _CreateCategoryNav = SWUI.CreateCategoryNav

-- ── ОКНО ────────────────────────────────────────────────────

function SWUI.CreateWindow(title, w, h, parent, accent)
    local frame, content = _CreateWindow(title, w, h, parent, accent)

    -- Звук при открытии
    SWUI.PlaySound(SWUI.Sounds.Open)

    -- Патчим кнопку закрытия (она создаётся внутри CreateWindow)
    -- Находим её как дочерний DButton с Paint через итерацию
    for _, child in ipairs(frame:GetChildren()) do
        if child:GetClassName() == 'DButton' then
            local origDoClick = child.DoClick
            child.DoClick = function(self)
                SWUI.PlaySound(SWUI.Sounds.Close)
                if origDoClick then origDoClick(self) end
            end
            break
        end
    end

    return frame, content
end

-- ── КНОПКА ──────────────────────────────────────────────────

function SWUI.CreateButton(parent, text, x, y, w, h, style, onClick)
    local btn = _CreateButton(parent, text, x, y, w, h, style, onClick)

    -- Звук наведения
    btn.OnCursorEntered = function(self)
        SWUI.PlaySound(SWUI.Sounds.Hover, SWUI.SoundVolume * 0.6)
    end

    -- Звук клика (в зависимости от стиля)
    local origDoClick = btn.DoClick
    btn.DoClick = function(self)
        local snd = (style == 'danger' or style == 'warn')
            and SWUI.Sounds.ClickWarn
            or  SWUI.Sounds.Click
        SWUI.PlaySound(snd)
        if origDoClick then origDoClick(self) end
    end

    return btn
end

-- ── ТАБЫ ────────────────────────────────────────────────────

function SWUI.CreateTabBar(parent, tabs, x, y, w, h, onChange)
    -- Оборачиваем onChange чтобы добавить звук при смене таба
    local wrappedOnChange = function(id)
        SWUI.PlaySound(SWUI.Sounds.Tab, SWUI.SoundVolume * 0.7)
        if onChange then onChange(id) end
    end

    local bar = _CreateTabBar(parent, tabs, x, y, w, h, wrappedOnChange)

    -- Звук наведения на кнопки табов
    for _, child in ipairs(bar:GetChildren()) do
        if child:GetClassName() == 'DButton' then
            child.OnCursorEntered = function(self)
                SWUI.PlaySound(SWUI.Sounds.Hover, SWUI.SoundVolume * 0.5)
            end
        end
    end

    return bar
end

-- ── СТРОКА СПИСКА ───────────────────────────────────────────

function SWUI.CreateListRow(parent, h, selected, locked, onClick)
    -- Добавляем звуки в onClick
    local wrappedOnClick
    if onClick then
        wrappedOnClick = function()
            if locked then
                SWUI.PlaySound(SWUI.Sounds.Denied)
            else
                SWUI.PlaySound(SWUI.Sounds.Select)
                onClick()
            end
        end
    end

    local row = _CreateListRow(parent, h, selected, locked, wrappedOnClick)

    -- Звук наведения (только если не заблокирована)
    row.OnCursorEntered = function(self)
        if not self._locked then
            SWUI.PlaySound(SWUI.Sounds.Hover, SWUI.SoundVolume * 0.45)
        end
    end

    return row
end

-- ── СЛОТ ТАЙЛ ───────────────────────────────────────────────

function SWUI.CreateSlotTile(parent, x, y, size, filled, onClick)
    local wrappedOnClick
    if onClick then
        wrappedOnClick = function()
            SWUI.PlaySound(filled and SWUI.Sounds.Select or SWUI.Sounds.Denied)
            onClick()
        end
    end

    local tile = _CreateSlotTile(parent, x, y, size, filled, wrappedOnClick)

    tile.OnCursorEntered = function(self)
        SWUI.PlaySound(SWUI.Sounds.Hover, SWUI.SoundVolume * 0.4)
    end

    return tile
end

-- ── КАТЕГОРИЙНЫЙ НАВ ────────────────────────────────────────

function SWUI.CreateCategoryNav(parent, items, x, y, w, h, onChange, cornerRadius)
    -- Оборачиваем onChange
    local wrappedOnChange = function(id)
        SWUI.PlaySound(SWUI.Sounds.Tab, SWUI.SoundVolume * 0.65)
        if onChange then onChange(id) end
    end

    local nav = _CreateCategoryNav(parent, items, x, y, w, h, wrappedOnChange, cornerRadius)

    -- Звук наведения на строки навигации
    for _, child in ipairs(nav:GetChildren()) do
        if child:GetClassName() == 'DPanel' then
            child.OnCursorEntered = function(self)
                self._hov = true
                SWUI.PlaySound(SWUI.Sounds.Hover, SWUI.SoundVolume * 0.4)
            end
        end
    end

    return nav
end

-- ============================================================
-- Публичные хелперы для ручного использования в модулях
-- ============================================================

-- Вызывай когда действие успешно завершено (экипировка, крафт)
function SWUI.SoundSuccess()
    SWUI.PlaySound(SWUI.Sounds.Success)
end

-- Вызывай когда действие заблокировано или ошибка
function SWUI.SoundDenied()
    SWUI.PlaySound(SWUI.Sounds.Denied)
end

-- Вызывай при открытии любого кастомного окна вручную
function SWUI.SoundOpen()
    SWUI.PlaySound(SWUI.Sounds.Open)
end

print('[SWExp] UI Library загружена.')