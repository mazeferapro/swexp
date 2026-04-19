-- ============================================================
-- Star Wars: Expedition -- Исследования (клиент)
-- modules/cl_research.lua
-- ============================================================

if SERVER then return end

-- ============================================================
-- Открытие меню терминала
-- ============================================================

net.Receive("SWExp::Research_OpenMenu", function()
    local techLevel     = net.ReadInt(8)
    local bankRP        = net.ReadInt(32)
    local collected     = net.ReadInt(16)
    local hasNext       = net.ReadBool()
    local nextThreshold = hasNext and net.ReadInt(32) or nil
    local maxLevel      = net.ReadInt(8)

    SWExp.Research.OpenTerminalMenu(techLevel, bankRP, collected, nextThreshold, maxLevel)
end)

-- ============================================================
-- Результат скана
-- ============================================================

net.Receive("SWExp::Research_Scanned", function()
    local points = net.ReadInt(8)
    local name   = net.ReadString()

    chat.AddText(
        Color(130, 220, 100), "[Сканер] ",
        Color(200, 220, 255), "Данные получены: ",
        Color(255, 240, 130), name,
        Color(130, 255, 160), "  +" .. points .. " ОИ"
    )
    chat.AddText(
        Color(140, 160, 190), "  Предмет добавлен в инвентарь. Сдайте на терминале исследований."
    )

    if SWExp and SWExp.Notify then
        SWExp.Notify("+" .. points .. " ОИ: " .. name, NOTIFY_HINT, 6)
    end
end)

-- ============================================================
-- Результат сдачи на терминале
-- ============================================================

net.Receive("SWExp::Research_Deposit", function()
    local amount = net.ReadInt(16)
    local bank   = net.ReadInt(32)

    chat.AddText(
        Color(80, 200, 255),  "[Терминал] ",
        Color(200, 220, 255), "Сдано в банк: ",
        Color(80, 255, 140),  "+" .. amount .. " ОИ",
        Color(140, 160, 190), "  (всего в банке: " .. bank .. " ОИ)"
    )

    if SWExp and SWExp.Notify then
        SWExp.Notify("Сдано " .. amount .. " ОИ в банк! Всего: " .. bank, NOTIFY_HINT, 6)
    end
end)

-- ============================================================
-- VGUI МЕНЮ ТЕРМИНАЛА
-- ============================================================

SWExp.Research = SWExp.Research or {}

function SWExp.Research.OpenTerminalMenu(techLevel, bankRP, collected, nextThreshold, maxLevel)
    if IsValid(SWExp.Research._terminalFrame) then
        SWExp.Research._terminalFrame:Close()
    end

    local cfg = SWExp.ResearchConfig

    local lvlData = cfg and cfg.TechLevels and cfg.TechLevels[techLevel]
    local lvlName = lvlData and lvlData.name or ("Уровень " .. techLevel)
    local atMax   = (techLevel >= maxLevel)

    local prevThreshold = lvlData and lvlData.rp_threshold or 0
    local progress = 0
    if not atMax and nextThreshold and nextThreshold > prevThreshold then
        progress = math.Clamp((bankRP - prevThreshold) / (nextThreshold - prevThreshold), 0, 1)
    elseif atMax then
        progress = 1
    end

    local nextUnlocks = (cfg and cfg.TechUnlocks and not atMax) and (cfg.TechUnlocks[techLevel + 1] or {}) or {}

    -- ============================================================
    -- Размеры окна
    -- ============================================================
    local W, H = 1100, 800
    local PAD  = 16

    local frame, content = SWUI.Animated.CreateWindow("ТЕРМИНАЛ ИССЛЕДОВАНИЙ", W, H, nil, SWUI.Colors.Green)
    SWExp.Research._terminalFrame = frame

    local cW = content:GetWide()
    local cH = content:GetTall()

    -- ============================================================
    -- ЛЕВАЯ КОЛОНКА (38%) -- статус и кнопка сдать
    -- ============================================================
    local leftW = math.Round(cW * 0.38)
    local rightX = PAD + leftW + PAD

    local leftPanel = vgui.Create("DPanel", content)
    leftPanel:SetPos(PAD, PAD)
    leftPanel:SetSize(leftW, cH - PAD * 2)
    leftPanel.Paint = function(self, pw, ph)
        SWUI.DrawRoundedRect(0, 0, pw, ph, 8, SWUI.Colors.Panel2)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawOutlinedRect(0, 0, pw, ph, 1)
    end

    local lp = 16
    local ly = 16

    -- Заголовок
    local function DrawSectionLabel(parent, y, text)
        local lbl = vgui.Create("DPanel", parent)
        lbl:SetPos(lp, y)
        lbl:SetSize(leftW - lp * 2, 26)
        lbl.Paint = function(s, pw, ph)
            SWUI.DrawText(text, "SWUI.Small", 0, ph / 2,
                SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            surface.SetDrawColor(SWUI.Colors.Border)
            surface.DrawLine(0, ph - 1, pw, ph - 1)
        end
        return y + 34
    end

    ly = DrawSectionLabel(leftPanel, ly, "СТАТУС ЭКСПЕДИЦИИ")

    -- Тех. уровень крупно
    local techBig = vgui.Create("DPanel", leftPanel)
    techBig:SetPos(lp, ly)
    techBig:SetSize(leftW - lp * 2, 86)
    techBig.Paint = function(s, pw, ph)
        local numCol = atMax and SWUI.Colors.Warn or SWUI.Colors.Green
        SWUI.DrawText(tostring(techLevel), "SWUI.MonoLarge", 0, ph / 2,
            numCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local sub = atMax and "МАКСИМАЛЬНЫЙ УРОВЕНЬ" or string.upper(lvlName)
        SWUI.DrawText(sub,            "SWUI.Body", 52, ph / 2 - 13,
            SWUI.Colors.TextHi,  TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        SWUI.DrawText("ТЕХ. УРОВЕНЬ", "SWUI.Small", 52, ph / 2 + 10,
            SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    ly = ly + 94

    -- Статы
    local function DrawStat(parent, y, label, value, valColor)
        local row = vgui.Create("DPanel", parent)
        row:SetPos(lp, y)
        row:SetSize(leftW - lp * 2, 32)
        row.Paint = function(s, pw, ph)
            SWUI.DrawText(label, "SWUI.Body", 0, ph / 2,
                SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            SWUI.DrawText(value, "SWUI.Mono", pw, ph / 2,
                valColor or SWUI.Colors.TextHi, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        return y + 38
    end

    ly = DrawStat(leftPanel, ly, "Банк ОИ",        tostring(bankRP),    SWUI.Colors.Accent)
    ly = DrawStat(leftPanel, ly, "Собрано (у вас)", tostring(collected),
        collected > 0 and SWUI.Colors.Green or SWUI.Colors.TextDim)

    if not atMax and nextThreshold then
        local need = math.max(0, nextThreshold - bankRP)
        ly = DrawStat(leftPanel, ly, "До уровня " .. (techLevel + 1), tostring(need) .. " ОИ", SWUI.Colors.Warn)
    end

    ly = ly + 4

    -- Разделитель
    local divider = vgui.Create("DPanel", leftPanel)
    divider:SetPos(lp, ly)
    divider:SetSize(leftW - lp * 2, 1)
    divider.Paint = function(s, pw, ph)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawLine(0, 0, pw, 0)
    end
    ly = ly + 12

    -- Полоса прогресса
    local progLabelPnl = vgui.Create("DPanel", leftPanel)
    progLabelPnl:SetPos(lp, ly)
    progLabelPnl:SetSize(leftW - lp * 2, 26)
    progLabelPnl.Paint = function(s, pw, ph)
        if atMax then
            SWUI.DrawText("Максимальный уровень достигнут", "SWUI.Body",
                pw / 2, ph / 2, SWUI.Colors.Warn, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        else
            local pct = math.Round(progress * 100)
            SWUI.DrawText("Прогресс: " .. pct .. "%", "SWUI.Body",
                0, ph / 2, SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            SWUI.DrawText(tostring(bankRP) .. " / " .. tostring(nextThreshold or "?"), "SWUI.Body",
                pw, ph / 2, SWUI.Colors.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end
    ly = ly + 32

    local progBar = vgui.Create("DPanel", leftPanel)
    progBar:SetPos(lp, ly)
    progBar:SetSize(leftW - lp * 2, 14)
    progBar._prog = progress
    progBar.Paint = function(s, pw, ph)
        SWUI.DrawRoundedRect(0, 0, pw, ph, ph / 2, Color(255, 255, 255, 15))
        local fw = math.max(ph, math.Round(pw * s._prog))
        local col = atMax and SWUI.Colors.Warn or SWUI.Colors.Green
        SWUI.DrawRoundedRect(0, 0, fw, ph, ph / 2, col)
    end
    ly = ly + 24

    -- ============================================================
    -- Шкала уровней
    -- ============================================================
    ly = ly + 8

    local timelinePnl = vgui.Create("DPanel", leftPanel)
    timelinePnl:SetPos(lp, ly)
    timelinePnl:SetSize(leftW - lp * 2, 36)
    timelinePnl.Paint = function(s, pw, ph)
        local steps = maxLevel
        local stepW = pw / steps
        for i = 1, steps do
            local x = (i - 1) * stepW
            local done = i <= techLevel
            local cur  = i == techLevel
            local col  = done and (cur and SWUI.Colors.Green or Color(0, 120, 60)) or Color(255, 255, 255, 20)
            SWUI.DrawRoundedRect(x + 2, ph / 2 - 6, stepW - 4, 12, 4, col)
            SWUI.DrawText(tostring(i), "SWUI.Small", x + stepW / 2, ph / 2,
                done and Color(255, 255, 255) or Color(255, 255, 255, 50),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
    ly = ly + 44

    -- ============================================================
    -- КНОПКА СДАТЬ (прибита к низу левой панели)
    -- ============================================================
    local btnH = 50
    local depositBtn = vgui.Create("DPanel", leftPanel)
    depositBtn:SetPos(lp, leftPanel:GetTall() - btnH - lp)
    depositBtn:SetSize(leftW - lp * 2, btnH)
    if collected > 0 then depositBtn:SetCursor("hand") end
    depositBtn.Paint = function(self, bw, bh)
        if collected > 0 then
            local hov = self:IsHovered()
            SWUI.DrawRoundedRect(0, 0, bw, bh, 6,
                hov and Color(0, 55, 30) or Color(0, 35, 18))
            surface.SetDrawColor(hov and SWUI.Colors.Green or Color(0, 120, 60))
            surface.DrawOutlinedRect(0, 0, bw, bh, 1)
            SWUI.DrawText("СДАТЬ  " .. collected .. "  ОИ  В  БАНК",
                "SWUI.Body", bw / 2, bh / 2,
                SWUI.Colors.Green, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        else
            SWUI.DrawRoundedRect(0, 0, bw, bh, 6, Color(15, 20, 25))
            surface.SetDrawColor(SWUI.Colors.Border)
            surface.DrawOutlinedRect(0, 0, bw, bh, 1)
            SWUI.DrawText("НЕТ ДАННЫХ ДЛЯ СДАЧИ",
                "SWUI.Body", bw / 2, bh / 2,
                SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
    depositBtn.OnMousePressed = function()
        if collected <= 0 then return end
        net.Start("SWExp::Research_DepositRequest")
        net.SendToServer()
        frame:Close()
    end

    -- ============================================================
    -- ПРАВАЯ КОЛОНКА (62%) -- разблокировки + все уровни
    -- ============================================================
    local rightW = cW - rightX - PAD

    local rightPanel = vgui.Create("DPanel", content)
    rightPanel:SetPos(rightX, PAD)
    rightPanel:SetSize(rightW, cH - PAD * 2)
    rightPanel.Paint = function(self, pw, ph)
        SWUI.DrawRoundedRect(0, 0, pw, ph, 8, SWUI.Colors.Panel2)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawOutlinedRect(0, 0, pw, ph, 1)
    end

    local rp = 14
    local ry = 16

    -- Заголовок правой панели
    local unlockTitle = vgui.Create("DPanel", rightPanel)
    unlockTitle:SetPos(rp, ry)
    unlockTitle:SetSize(rightW - rp * 2, 20)
    unlockTitle.Paint = function(s, pw, ph)
        local title = atMax and "ЭКСПЕДИЦИЯ ЗАВЕРШЕНА"
            or ("РАЗБЛОКИРОВКИ НА УРОВНЕ " .. (techLevel + 1))
        SWUI.DrawText(title, "SWUI.Small", 0, ph / 2,
            SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawLine(0, ph - 1, pw, ph - 1)
    end
    ry = ry + 30

    -- Скролл для списка разблокировок
    local scrollH = cH - PAD * 2 - ry - rp
    local scroll = vgui.Create("DScrollPanel", rightPanel)
    scroll:SetPos(rp, ry)
    scroll:SetSize(rightW - rp * 2, scrollH)
    scroll:GetVBar():SetWide(4)
    scroll:GetVBar().Paint = function(s, pw, ph)
        draw.RoundedBox(2, 0, 0, pw, ph, Color(255, 255, 255, 12))
    end
    scroll:GetVBar().btnGrip.Paint = function(s, pw, ph)
        draw.RoundedBox(2, 0, 0, pw, ph, SWUI.Colors.Green)
    end

    local sw = rightW - rp * 2 - 8
    local sy = 0

    if atMax then
        local finPnl = vgui.Create("DPanel", scroll)
        finPnl:SetPos(0, sy)
        finPnl:SetSize(sw, 100)
        finPnl.Paint = function(s, pw, ph)
            SWUI.DrawRoundedRect(0, 0, pw, ph, 6, Color(40, 30, 0))
            surface.SetDrawColor(SWUI.Colors.Warn)
            surface.DrawOutlinedRect(0, 0, pw, ph, 1)
            SWUI.DrawText("Все технологии изучены.",
                "SWUI.Body", pw / 2, 28,
                SWUI.Colors.Warn, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            SWUI.DrawText("Продолжайте собирать данные для финального протокола.",
                "SWUI.Small", pw / 2, 56,
                SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end
        sy = sy + 108
    else
        -- Разблокировки следующего уровня
        if #nextUnlocks > 0 then
            for _, unlock in ipairs(nextUnlocks) do
                local rowH = 80
                local itemRow = vgui.Create("DPanel", scroll)
                itemRow:SetPos(0, sy)
                itemRow:SetSize(sw, rowH)

                local uName = unlock.name or ""
                local uDesc = unlock.desc or ""
                local uIcon = unlock.icon

                itemRow.Paint = function(s, pw, ph)
                    SWUI.DrawRoundedRect(0, 0, pw, ph, 6, Color(255, 255, 255, 5))
                    surface.SetDrawColor(SWUI.Colors.Border)
                    surface.DrawOutlinedRect(0, 0, pw, ph, 1)

                    if uIcon then
                        local mat = Material(uIcon)
                        if mat and not mat:IsError() then
                            surface.SetMaterial(mat)
                            surface.SetDrawColor(SWUI.Colors.Green)
                            surface.DrawTexturedRect(12, ph / 2 - 12, 24, 24)
                        end
                    end

                    SWUI.DrawText(uName, "SWUI.Body", 46, 14,
                        SWUI.Colors.TextHi, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    SWUI.DrawText(uDesc, "SWUI.Small", 46, 40,
                        SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                end
                sy = sy + rowH + 5
            end
        else
            local emptyPnl = vgui.Create("DPanel", scroll)
            emptyPnl:SetPos(0, sy)
            emptyPnl:SetSize(sw, 44)
            emptyPnl.Paint = function(s, pw, ph)
                SWUI.DrawText("Данные засекречены", "SWUI.Body",
                    pw / 2, ph / 2, SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            sy = sy + 52
        end
    end

    -- Разделитель перед полным списком уровней
    sy = sy + 8
    local div2 = vgui.Create("DPanel", scroll)
    div2:SetPos(0, sy)
    div2:SetSize(sw, 20)
    div2.Paint = function(s, pw, ph)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawLine(0, ph / 2, pw, ph / 2)
        SWUI.DrawText("ВСЕ УРОВНИ", "SWUI.Tiny", pw / 2, ph / 2,
            SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    sy = sy + 28

    -- Список всех уровней
    if cfg and cfg.TechLevels then
        for lvl = 1, maxLevel do
            local ld      = cfg.TechLevels[lvl]
            if not ld then continue end
            local isDone  = lvl <= techLevel
            local isCur   = lvl == techLevel
            local unlocks = (cfg.TechUnlocks and cfg.TechUnlocks[lvl]) or {}

            local rowH = 44 + (#unlocks > 0 and #unlocks * 24 or 0)
            local lvlRow = vgui.Create("DPanel", scroll)
            lvlRow:SetPos(0, sy)
            lvlRow:SetSize(sw, rowH)

            local lName   = ld.name or ("Уровень " .. lvl)
            local lThresh = ld.rp_threshold or 0

            lvlRow.Paint = function(s, pw, ph)
                local bg = isCur and Color(0, 40, 20) or (isDone and Color(255,255,255,4) or Color(255,255,255,2))
                SWUI.DrawRoundedRect(0, 0, pw, ph, 5, bg)
                local bord = isCur and Color(0, 160, 80) or (isDone and Color(0, 80, 40) or SWUI.Colors.Border)
                surface.SetDrawColor(bord)
                surface.DrawOutlinedRect(0, 0, pw, ph, 1)

                local numCol = isCur and SWUI.Colors.Green or (isDone and Color(0, 160, 80) or SWUI.Colors.TextDim)
                SWUI.DrawText(tostring(lvl), "SWUI.Body", 12, 14,
                    numCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                SWUI.DrawText(string.upper(lName), "SWUI.Body", 34, 14,
                    isDone and SWUI.Colors.TextHi or SWUI.Colors.TextDim,
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                SWUI.DrawText(tostring(lThresh) .. " ОИ", "SWUI.Small", pw - 10, 16,
                    SWUI.Colors.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

                for i, u in ipairs(unlocks) do
                    SWUI.DrawText("+ " .. (u.name or ""), "SWUI.Small", 34, 36 + (i - 1) * 24,
                        isDone and Color(100, 200, 130) or Color(255,255,255,30),
                        TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                end
            end
            sy = sy + rowH + 5
        end
    end
end

print("[SWExp] Модуль исследований (клиент) загружен.")
