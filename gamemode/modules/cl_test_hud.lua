-- Star Wars: Expedition
-- modules/hud/cl_test_ui.lua
-- Открыть: swexp_test_ui в консоли

concommand.Add('swexp_test_ui', function()

    local W, H = 1000, 620
    local frame, content = SWUI.CreateWindow('СНАРЯЖЕНИЕ КЛОНА', W, H)

    -- ── ТАБЫ ──────────────────────────────────────────────────
    local panels = {}

    SWUI.CreateTabBar(content, {
        { id = 'inventory', label = 'ИНВЕНТАРЬ'  },
        { id = 'equipment', label = 'СНАРЯЖЕНИЕ' },
        { id = 'character', label = 'ПЕРСОНАЖ'   },
    }, 0, 0, W, 42, function(id)
        for tid, pnl in pairs(panels) do pnl:SetVisible(tid == id) end
    end)

    local function MakePanel(visible)
        local p = vgui.Create('DPanel', content)
        p:SetPos(0, 42)
        p:SetSize(W, H - 82)
        p.Paint = function() end
        p:SetVisible(visible or false)
        return p
    end

    -- ── ИНВЕНТАРЬ ─────────────────────────────────────────────
    local invPanel = MakePanel(true)
    invPanel.Paint = function(self, pw, ph)
        draw.RoundedBoxEx(16, 0, 0, pw, ph, Color(6, 12, 18, 255), false, false, true, true)
    end
    panels['inventory'] = invPanel

    SWUI.CreateCategoryNav(invPanel, {
        { id = 'weapons',   icon = '',  label = 'Оружие',    count = 3  },
        { id = 'armor',     icon = '',  label = 'Броня',     count = 1  },
        { id = 'medical',   icon = '',  label = 'Медицина',  count = 4  },
        { id = 'materials', icon = '',  label = 'Материалы', count = 12 },
    }, 0, 0, 180, H - 82)

    local scroll = SWUI.CreateScrollList(invPanel, 188, 8, W - 196, H - 98)

    local items = {
        { name = 'DC-15A Бластер',  tier = 'I',   cls = 'ПЕХОТА',  cost = 25,  locked = false },
        { name = 'DC-15X Снайпер',  tier = 'II',  cls = 'СНАЙПЕР', cost = 45,  locked = false },
        { name = 'Республ. доспех', tier = 'II',  cls = 'СРЕДНИЙ', cost = 60,  locked = false },
        { name = 'Тяжёлый доспех',  tier = 'III', cls = 'ТЯЖЁЛЫЙ', cost = 90,  locked = true  },
        { name = 'Медпак',          tier = 'I',   cls = 'МЕДИК',   cost = 15,  locked = false },
        { name = 'Стимулятор',      tier = 'II',  cls = 'МЕДИК',   cost = 30,  locked = false },
    }

    local selRow = nil
    for _, item in ipairs(items) do
        local row
        local _item = item  -- захватываем в closure
        row = SWUI.CreateListRow(scroll, 52, false, _item.locked, function()
            if _item.locked then return end
            if selRow then selRow._selected = false end
            selRow = row
            row._selected = true
        end)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 4)

        local _row = row
        row.Paint = function(self, pw, ph)
            -- фон строки (из библиотеки)
            local hov = self:IsHovered() and not self._locked
            local sel = self._selected
            local bg  = sel  and Color(0,40,65,220)
                     or hov  and Color(0,30,50,180)
                     or Color(0,0,0,100)
            local brd = sel  and SWUI.Colors.Accent
                     or hov  and SWUI.Colors.BorderHi
                     or SWUI.Colors.Border
            if self._locked then bg = Color(0,0,0,60); brd = SWUI.Colors.Border end
            draw.RoundedBox(8, 0, 0, pw, ph, bg)
            surface.SetDrawColor(brd)
            surface.DrawOutlinedRect(0, 0, pw, ph, 1)

            -- Тир-полоска слева
            local tierColors = { I=Color(68,136,102), II=SWUI.Colors.AccentDim, III=Color(136,100,68) }
            local tc = tierColors[_item.tier] or SWUI.Colors.Border
            surface.SetDrawColor(tc)
            surface.DrawRect(0, 0, 3, ph)

            -- Название
            local nameCol = _item.locked and SWUI.Colors.TextDim or SWUI.Colors.TextHi
            draw.SimpleText(_item.name, 'SWUI.Header', 16, 10, nameCol)

            -- Тир · Класс
            draw.SimpleText('ТИР ' .. _item.tier .. '  ·  ' .. _item.cls, 'SWUI.Tiny', 16, 30, SWUI.Colors.TextDim)

            -- Стоимость
            local costCol = _item.locked and SWUI.Colors.TextDim or SWUI.Colors.Green
            draw.SimpleText(_item.cost .. ' МАТ', 'SWUI.Mono', pw - 16, ph/2, costCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

            -- Замок если locked
            if _item.locked then
                draw.SimpleText('[LOCKED]', 'SWUI.Tiny', pw - 80, 10, SWUI.Colors.TextDim)
            end
        end
    end

    -- ── СНАРЯЖЕНИЕ ────────────────────────────────────────────
    local eqPanel = MakePanel()
    eqPanel.Paint = function(self, pw, ph)
        draw.RoundedBoxEx(16, 0, 0, pw, ph, Color(6, 12, 18, 255), false, false, true, true)
    end
    panels['equipment'] = eqPanel

    SWUI.CreateSectionHeader(eqPanel, 'Основное оружие', 14, 10, W/2 - 28)

    local slotDefs = {
        { filled = true,  name = 'DC-15A' },
        { filled = true,  name = 'DC-15X' },
        { filled = false },
        { filled = false },
    }
    for i, sd in ipairs(slotDefs) do
        local _sd = sd
        local s = SWUI.CreateSlotTile(eqPanel, 14 + (i-1)*72, 46, 64, sd.filled)
        if sd.filled then
            s.Paint = function(self, pw, ph)
                local hov = self:IsHovered()
                local bg  = hov and Color(30,53,69) or Color(26,42,54)
                draw.RoundedBox(9, -1,-1, pw+2, ph+2, SWUI.Colors.BorderHi)
                draw.RoundedBox(8,  0, 0, pw,   ph,   bg)
                draw.SimpleText(_sd.name, 'SWUI.Small', pw/2, ph/2, SWUI.Colors.TextHi, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    end

    SWUI.CreateSectionHeader(eqPanel, 'Характеристики', W/2, 10, W/2 - 14)

    local stats = {
        { label='УРОН',       value='55 дм'   },
        { label='СКОРОСТРЕЛ', value='600 RPM' },
        { label='ПОГЛОЩЕНИЕ', value='25%'     },
        { label='ВЕС',        value='3.2 кг'  },
    }
    for i, st in ipairs(stats) do
        SWUI.CreateStatLabel(eqPanel, st.label, st.value, W/2 + 14, 46 + (i-1)*28)
    end

    SWUI.CreateButton(eqPanel, 'СНЯТЬ БРОНЮ', 14, H - 130, 140, 30, 'warn')
    SWUI.CreateButton(eqPanel, 'ЭКИПИРОВАТЬ', 14, H - 94,  140, 30, 'accent')

    -- ── ПЕРСОНАЖ ──────────────────────────────────────────────
    local charPanel = MakePanel()
    charPanel.Paint = function(self, pw, ph)
        draw.RoundedBoxEx(16, 0, 0, pw, ph, Color(6, 12, 18, 255), false, false, true, true)
    end
    panels['character'] = charPanel

    local header = vgui.Create('DPanel', charPanel)
    header:SetPos(0, 0)
    header:SetSize(W, 110)
    header.Paint = function(self, pw, ph)
        draw.SimpleText('ПРИЗРАК',             'SWUI.Title', pw/2, 36, SWUI.Colors.TextHi,  TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText('CT-4471  ·  РЯДОВОЙ', 'SWUI.Mono',  pw/2, 64, SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawLine(pw/4, 88, pw*3/4, 88)
    end

    SWUI.CreateSectionHeader(charPanel, 'Прогресс', 14, 118, W - 28)

    local xpBar = SWUI.CreateProgressBar(charPanel, 14, 158, W - 28, 10, SWUI.Colors.Accent)
    xpBar:SetValue(340, 1000)

    SWUI.CreateStatLabel(charPanel, 'ОПЫТ', '340 / 1000', 14, 178)

    local resBar = SWUI.CreateProgressBar(charPanel, 14, 220, W - 28, 10, SWUI.Colors.Warn)
    resBar:SetValue(47, 100)
    SWUI.CreateStatLabel(charPanel, 'МАТЕРИАЛЫ', '47 / 100', 14, 240)

    -- ── КНОПКИ ОКНА ───────────────────────────────────────────
    SWUI.CreateButton(content, 'ЗАКРЫТЬ',   W - 130, H - 38, 116, 30, 'ghost',  function() frame:Close() end)
    SWUI.CreateButton(content, 'ПРИМЕНИТЬ', W - 260, H - 38, 120, 30, 'accent', function()
        chat.AddText(SWUI.Colors.Accent, '[SWExp] ', color_white, 'Применено!')
        frame:Close()
    end)

end)

hook.Add('InitPostEntity', 'SWExp::TestUIHint', function()
    timer.Simple(2, function()
        chat.AddText(SWUI.Colors.Accent, '[SWExp] ', SWUI.Colors.TextDim,
            'Тест UI: ', SWUI.Colors.TextHi, 'swexp_test_ui')
    end)
end)