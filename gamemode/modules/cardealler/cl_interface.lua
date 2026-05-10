-- ============================================================================
-- cl_interface.lua — Терминал техники (стиль Ассемблера)
-- ============================================================================

local MainFrame = nil

SWExp         = SWExp or {}
SWExp.CarDealer = SWExp.CarDealer or {}
SWExp.CarDealer.VehiclePool        = SWExp.CarDealer.VehiclePool or {}
SWExp.CarDealer.CurrentTechLevel   = 1

net.Receive("SWExp::CarDealer::SyncPool", function()
    SWExp.CarDealer.VehiclePool      = net.ReadTable()
    SWExp.CarDealer.CurrentTechLevel = net.ReadUInt(8) or 1
    -- Обновляем меню если оно открыто (возврат/производство техники)
    if IsValid(MainFrame) and BuildList then
        BuildList()
    end
end)

concommand.Add("swexp_save_dealers", function()
    if not LocalPlayer():IsSuperAdmin() then print("[SWExp] Недостаточно прав!") return end
    netstream.Start("NextRP::SaveDealers")
    print("[SWExp] Запрос на сохранение терминалов отправлен...")
end)

-- ============================================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ============================================================================

-- Кастомная кнопка в стиле ассемблера
local function MakeActionBtn(parent, text, style, x, y, w, h, onClick)
    local btn = vgui.Create("DPanel", parent)
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetCursor("hand")

    -- style: "accent" | "warn" | "danger" | "dim"
    local colMap = {
        accent = { bg = Color(0, 34, 55),    bgh = Color(0, 55, 85),    brd = Color(0, 140, 200),   brdh = Color(0, 184, 255),   txt = Color(0, 184, 255)   },
        warn   = { bg = Color(40, 28, 0),    bgh = Color(60, 40, 0),    brd = Color(180, 120, 0),   brdh = Color(255, 180, 0),   txt = Color(255, 200, 0)   },
        danger = { bg = Color(30, 8, 8),     bgh = Color(50, 14, 14),   brd = Color(140, 40, 40),   brdh = Color(220, 60, 60),   txt = Color(220, 80, 80)   },
        dim    = { bg = Color(14, 18, 24),   bgh = Color(14, 18, 24),   brd = Color(40, 50, 60),    brdh = Color(40, 50, 60),    txt = Color(80, 100, 120)  },
    }
    local c = colMap[style] or colMap.accent

    btn.Paint = function(self, bw, bh)
        local hov = self:IsHovered()
        SWUI.DrawRoundedRect(0, 0, bw, bh, 5, hov and c.bgh or c.bg)
        surface.SetDrawColor(hov and c.brdh or c.brd)
        surface.DrawOutlinedRect(0, 0, bw, bh, 1)
        SWUI.DrawText(text, "SWUI.Body", bw / 2, bh / 2, c.txt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.OnMousePressed = function()
        if onClick then onClick() end
    end
    return btn
end

-- ============================================================================
-- ГЛАВНОЕ МЕНЮ ТЕРМИНАЛА
-- ============================================================================

function SWExp.CarDealer:OpenMenu(tVehs, eEnt, tPlatforms, tVehicles, tCarList, nFaction)
    if IsValid(MainFrame) then MainFrame:Close() end

    net.Start("SWExp::CarDealer::RequestSync")
    net.SendToServer()

    -- ===== Размеры =====
    local W, H  = 1000, 700
    local PAD   = 16

    local frame, content = SWUI.Animated.CreateWindow("ТЕРМИНАЛ ТЕХНИКИ", W, H, nil, SWUI.Colors.Warn)
    MainFrame = frame

    local cW = content:GetWide()
    local cH = content:GetTall()

    -- ============================================================
    -- ВЕРХНЯЯ ПАНЕЛЬ — банк, ТЛ, режим
    -- ============================================================
    local topH   = 64
    local topBar = vgui.Create("DPanel", content)
    topBar:SetPos(PAD, PAD)
    topBar:SetSize(cW - PAD * 2, topH)

    local activeTab = "garage"  -- текущий режим (нужен для перерисовки top bar)

    topBar.Paint = function(self, pw, ph)
        SWUI.DrawRoundedRect(0, 0, pw, ph, 6, SWUI.Colors.Panel2)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawOutlinedRect(0, 0, pw, ph, 1)

        local bank = (SWExp.Assembler and SWExp.Assembler._bank) or 0
        local tl   = SWExp.CarDealer.CurrentTechLevel or 1

        -- Банк
        SWUI.DrawText("БАНК МАТЕРИАЛОВ", "SWUI.Tiny", 14, 10,
            SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        SWUI.DrawText(tostring(bank), "SWUI.MonoLarge", 14, ph,
            SWUI.Colors.Warn, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawLine(160, 8, 160, ph - 8)

        -- Тех. уровень
        SWUI.DrawText("ТЕХ. УРОВЕНЬ", "SWUI.Tiny", 176, 10,
            SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        SWUI.DrawText(tostring(tl), "SWUI.MonoLarge", 176, ph,
            SWUI.Colors.Accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawLine(290, 8, 290, ph - 8)

        -- Режим
        SWUI.DrawText("РЕЖИМ", "SWUI.Tiny", 306, 10,
            SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        local modeStr  = (activeTab == "factory") and "ПРОИЗВОДСТВО" or "ГАРАЖ"
        local modeCol  = (activeTab == "factory") and SWUI.Colors.Warn or SWUI.Colors.Green
        SWUI.DrawText(modeStr, "SWUI.MonoLarge", 306, ph,
            modeCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
    end

    -- ============================================================
    -- TAB-КНОПКИ (стиль категорий ассемблера, но горизонтально)
    -- ============================================================
    local tabs    = { { id = "garage", name = "ГАРАЖ" }, { id = "factory", name = "ПРОИЗВОДСТВО" } }
    local tabBtnW = 180
    local tabBtnH = 34
    local tabX    = (cW - PAD * 2) - PAD - #tabs * (tabBtnW + 6)

    local tabBtns = {}

    local function RefreshTabBtns()
        for _, tb in ipairs(tabBtns) do
            if IsValid(tb.panel) then tb.panel:InvalidateLayout(true) end
        end
        if IsValid(topBar) then topBar:InvalidateLayout(true) end
    end

    for i, tab in ipairs(tabs) do
        local tbX = tabX + (i - 1) * (tabBtnW + 6)
        local tbY = (topH - tabBtnH) / 2
        local tb  = vgui.Create("DPanel", topBar)
        tb:SetPos(tbX, tbY)
        tb:SetSize(tabBtnW, tabBtnH)
        tb:SetCursor("hand")

        local tabId = tab.id
        local tabName = tab.name

        tb.Paint = function(self, bw, bh)
            local active = (activeTab == tabId)
            local hov    = self:IsHovered()
            local bg     = active and SWUI.Colors.Warn or (hov and Color(255,255,255,18) or Color(255,255,255,6))
            SWUI.DrawRoundedRect(0, 0, bw, bh, 5, bg)
            if active then
                surface.SetDrawColor(Color(255, 180, 0, 200))
                surface.DrawOutlinedRect(0, 0, bw, bh, 1)
            end
            local txtCol = active and Color(255, 255, 255) or SWUI.Colors.TextHi
            SWUI.DrawText(tabName, "SWUI.Small", bw / 2, bh / 2,
                txtCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        tb.OnMousePressed = function()
            activeTab = tabId
            RefreshTabBtns()
            BuildList()
        end
        table.insert(tabBtns, { panel = tb, id = tabId })
    end

    -- ============================================================
    -- ТЕЛО: левая (список техники) + правая (детали)
    -- ============================================================
    local bodyY = PAD + topH + PAD
    local bodyH = cH - bodyY - PAD - 56  -- 56 — нижняя панель кнопок

    local catW   = 260
    local catPanel = vgui.Create("DPanel", content)
    catPanel:SetPos(PAD, bodyY)
    catPanel:SetSize(catW, bodyH)
    catPanel.Paint = function(self, pw, ph)
        SWUI.DrawRoundedRect(0, 0, pw, ph, 8, SWUI.Colors.Panel2)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawOutlinedRect(0, 0, pw, ph, 1)
    end

    local catScroll = vgui.Create("DScrollPanel", catPanel)
    catScroll:SetPos(6, 6)
    catScroll:SetSize(catW - 12, bodyH - 12)
    catScroll:GetVBar():SetWide(4)
    catScroll:GetVBar().Paint = function(s, pw, ph)
        draw.RoundedBox(2, 0, 0, pw, ph, Color(255,255,255,12))
    end
    catScroll:GetVBar().btnGrip.Paint = function(s, pw, ph)
        draw.RoundedBox(2, 0, 0, pw, ph, SWUI.Colors.Warn)
    end

    local detailX = PAD + catW + PAD
    local detailW = cW - detailX - PAD
    local detailPanel = vgui.Create("DPanel", content)
    detailPanel:SetPos(detailX, bodyY)
    detailPanel:SetSize(detailW, bodyH)
    detailPanel.Paint = function(self, pw, ph)
        SWUI.DrawRoundedRect(0, 0, pw, ph, 8, SWUI.Colors.Panel2)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawOutlinedRect(0, 0, pw, ph, 1)
    end

    -- ============================================================
    -- Функция заполнения детальной панели
    -- ============================================================
    local function ShowDetail(v, activeVehID)
        detailPanel:Clear()

        local settings       = SWExp.CarDealer:GetVehicleSettings(v.class)
        local currentTL      = SWExp.CarDealer.CurrentTechLevel or 1
        local bank           = (SWExp.Assembler and SWExp.Assembler._bank) or 0
        local countInPool    = SWExp.CarDealer.VehiclePool[v.class] or 0

        local plyRankID   = LocalPlayer():GetNWString("swexp_rank", "TRP")
        local plyRankData = SWExp.Ranks and SWExp.Ranks:Get(plyRankID)
        local plyOrder    = plyRankData and plyRankData.sortOrder or 0

        local cRankData   = SWExp.Ranks and SWExp.Ranks:Get(settings.createRank)
        local sRankData   = SWExp.Ranks and SWExp.Ranks:Get(settings.spawnRank)
        local reqCreate   = cRankData and cRankData.sortOrder or 1
        local reqSpawn    = sRankData and sRankData.sortOrder or 1
        local createName  = cRankData and cRankData.name or tostring(settings.createRank)
        local spawnName   = sRankData and sRankData.name or tostring(settings.spawnRank)

        local isFactory   = (activeTab == "factory")

        -- ── Заголовок ──────────────────────────────────────────
        local headerH = 50
        local headerPanel = vgui.Create("DPanel", detailPanel)
        headerPanel:SetPos(0, 0)
        headerPanel:SetSize(detailW, headerH)
        headerPanel.Paint = function(self, pw, ph)
            SWUI.DrawRoundedRect(0, 0, pw, ph, 8, Color(8, 14, 22))
            surface.SetDrawColor(SWUI.Colors.Border)
            surface.DrawLine(0, ph - 1, pw, ph - 1)
            SWUI.DrawText(v.name, "SWUI.Body", PAD, ph / 2,
                SWUI.Colors.TextHi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            -- Режим-тег справа
            local tagTxt = isFactory and "ПРОИЗВОДСТВО" or "ГАРАЖ"
            local tagCol = isFactory and SWUI.Colors.Warn or SWUI.Colors.Green
            SWUI.DrawText(tagTxt, "SWUI.Small", pw - PAD, ph / 2,
                tagCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        -- ── Блок информации ────────────────────────────────────
        local infoY  = headerH + PAD
        local infoPanel = vgui.Create("DPanel", detailPanel)
        infoPanel:SetPos(PAD, infoY)
        infoPanel:SetSize(detailW - PAD * 2, 180)
        infoPanel.Paint = function(self, pw, ph)
            SWUI.DrawRoundedRect(0, 0, pw, ph, 6, Color(6, 10, 16))
            surface.SetDrawColor(SWUI.Colors.Border)
            surface.DrawOutlinedRect(0, 0, pw, ph, 1)

            -- Описание
            SWUI.DrawText(v.desc or "Техника экспедиции", "SWUI.Small",
                14, 14, SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            if isFactory then
                -- Стоимость
                local costOk  = bank >= settings.materialCost
                SWUI.DrawText("СТОИМОСТЬ", "SWUI.Tiny", 14, 46,
                    SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                SWUI.DrawText(settings.materialCost .. " мат.", "SWUI.Body", 14, 64,
                    costOk and SWUI.Colors.Warn or Color(220, 80, 80),
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                -- Тех. уровень
                local tlOk = currentTL >= settings.techLevel
                SWUI.DrawText("ТЕХ. УРОВЕНЬ", "SWUI.Tiny", pw / 2, 46,
                    SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                SWUI.DrawText("Треб: " .. settings.techLevel .. "  Текущий: " .. currentTL,
                    "SWUI.Small", pw / 2, 64,
                    tlOk and SWUI.Colors.Accent or Color(220, 80, 80),
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                -- Допуск
                SWUI.DrawText("ДОПУСК К КРАФТУ", "SWUI.Tiny", 14, 102,
                    SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                SWUI.DrawText(createName, "SWUI.Small", 14, 120,
                    plyOrder >= reqCreate and SWUI.Colors.Green or Color(220, 80, 80),
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            else
                -- В гараже
                SWUI.DrawText("В ГАРАЖЕ", "SWUI.Tiny", 14, 46,
                    SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                SWUI.DrawText(countInPool .. " шт.", "SWUI.Body", 14, 64,
                    countInPool > 0 and SWUI.Colors.Green or Color(220, 80, 80),
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                -- Допуск к управлению
                SWUI.DrawText("ДОПУСК К УПРАВЛЕНИЮ", "SWUI.Tiny", pw / 2, 46,
                    SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                SWUI.DrawText(spawnName, "SWUI.Small", pw / 2, 64,
                    plyOrder >= reqSpawn and SWUI.Colors.Green or Color(220, 80, 80),
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
        end

        -- ── Кнопка действия ───────────────────────────────────
        local canAct = false
        local btnText, btnStyle

        if isFactory then
            local hasRank  = plyOrder >= reqCreate
            local hasTL    = currentTL >= settings.techLevel
            local hasMat   = bank >= settings.materialCost
            canAct    = hasRank and hasTL and hasMat
            btnText   = canAct
                and ("ПРОИЗВЕСТИ ЗА " .. settings.materialCost .. " МАТ.")
                or  (not hasRank and "НЕДОСТАТОЧНО ЗВАНИЯ"
                     or (not hasTL and ("ТРЕБУЕТСЯ ТЕХ. УР. " .. settings.techLevel)
                         or "НЕДОСТАТОЧНО МАТЕРИАЛОВ"))
            btnStyle  = canAct and "warn" or "dim"
        else
            local hasRank = plyOrder >= reqSpawn
            canAct    = hasRank
            btnText   = hasRank and "ВЫЗВАТЬ ТЕХНИКУ" or "НЕДОСТАТОЧНО ЗВАНИЯ"
            btnStyle  = hasRank and "accent" or "dim"
        end

        local btnH   = 46
        local btnY   = bodyH - btnH - PAD
        local actBtn = MakeActionBtn(detailPanel, btnText, btnStyle,
            PAD, btnY, detailW - PAD * 2, btnH, function()
                if not canAct then return end
                if isFactory then
                    netstream.Start("SWExp::CreateCar", v.class)
                else
                    -- Закрываем меню и запускаем режим выбора платформы
                    MainFrame:Close()
                    net.Start("SWExp::CarDealer::ReqPlatforms")
                        net.WriteEntity(eEnt)
                        net.WriteString(v.class)
                    net.SendToServer()
                end
            end)

        -- Разделитель перед кнопкой
        local sepPanel = vgui.Create("DPanel", detailPanel)
        sepPanel:SetPos(0, btnY - PAD)
        sepPanel:SetSize(detailW, 1)
        sepPanel.Paint = function(self, pw, ph)
            surface.SetDrawColor(SWUI.Colors.Border)
            surface.DrawLine(PAD, 0, pw - PAD, 0)
        end
    end

    -- ============================================================
    -- Построить список техники
    -- ============================================================
    local activeVehID = nil

    function BuildList()
        catScroll:Clear()
        detailPanel:Clear()

        local navItems = {}
        for _, v in ipairs(tVehs) do
            local countInPool = SWExp.CarDealer.VehiclePool[v.class] or 0
            if activeTab == "garage" and countInPool <= 0 then continue end
            table.insert(navItems, {
                id    = v.class,
                label = v.name,
                count = (activeTab == "garage") and countInPool or nil,
                data  = v,
            })
        end

        if #navItems == 0 then
            local lbl = vgui.Create("DLabel", detailPanel)
            lbl:SetText(activeTab == "garage" and "В гараже нет техники." or "Техника для производства отсутствует.")
            lbl:SetFont("SWUI.Body")
            lbl:SetTextColor(SWUI.Colors.TextDim)
            lbl:SizeToContents()
            lbl:SetPos(PAD, PAD)
            return
        end

        -- Выбор первого/последнего активного
        local firstID = navItems[1].id
        if activeVehID == nil then
            activeVehID = firstID
        else
            -- Проверяем что предыдущий выбор всё ещё в списке
            local found = false
            for _, it in ipairs(navItems) do if it.id == activeVehID then found = true break end end
            if not found then activeVehID = firstID end
        end

        local btnH = 44
        for _, item in ipairs(navItems) do
            local itemId = item.id
            local btn    = vgui.Create("DPanel", catScroll)
            btn:SetPos(0, 0)
            btn:SetSize(catW - 18, btnH)
            btn:SetCursor("hand")
            btn:Dock(TOP)
            btn:DockMargin(0, 0, 0, 4)

            btn.Paint = function(self, pw, ph)
                local active = (activeVehID == itemId)
                local hov    = self:IsHovered()
                SWUI.DrawRoundedRect(0, 0, pw, ph, 5,
                    active and SWUI.Colors.Warn
                    or (hov and Color(255,255,255,18) or Color(255,255,255,6)))
                if active then
                    surface.SetDrawColor(Color(255, 180, 0, 200))
                    surface.DrawOutlinedRect(0, 0, pw, ph, 1)
                end
                local txtCol = active and Color(255, 255, 255) or SWUI.Colors.TextHi
                SWUI.DrawText(item.label, "SWUI.Body", 14, ph / 2,
                    txtCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                if item.count then
                    SWUI.DrawText("[" .. item.count .. "]", "SWUI.Small", pw - 10, ph / 2,
                        SWUI.Colors.Green, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
            end

            btn.OnMousePressed = function()
                activeVehID = itemId
                catScroll:InvalidateLayout(true)
                -- Перестроить детали
                ShowDetail(item.data, activeVehID)
            end
        end

        -- Показать детали первого/выбранного элемента
        for _, item in ipairs(navItems) do
            if item.id == activeVehID then
                ShowDetail(item.data, activeVehID)
                break
            end
        end
    end

    -- ============================================================
    -- НИЖНЯЯ ПАНЕЛЬ КНОПОК
    -- ============================================================
    local botY     = cH - 56
    local botH     = 46
    local isAdmin  = LocalPlayer():IsSuperAdmin()
    local botCount = isAdmin and 3 or 1
    local botGap   = 8
    local botTotalW = cW - PAD * 2
    local botBtnW   = math.floor((botTotalW - botGap * (botCount - 1)) / botCount)

    local botPanel = vgui.Create("DPanel", content)
    botPanel:SetPos(PAD, botY)
    botPanel:SetSize(botTotalW, botH)
    botPanel.Paint = function() end

    MakeActionBtn(botPanel, "ВЕРНУТЬ ТЕХНИКУ", "danger",
        0, 0, botBtnW, botH, function()
            netstream.Start("NextRP::ReturnCar")
        end)

    if isAdmin then
        MakeActionBtn(botPanel, "ДОБАВИТЬ ПЛАТФОРМУ", "accent",
            botBtnW + botGap, 0, botBtnW, botH, function()
                netstream.Start("SWExp::AddPlatform", eEnt)
            end)
        MakeActionBtn(botPanel, "СОХРАНИТЬ ТЕРМИНАЛЫ", "warn",
            (botBtnW + botGap) * 2, 0, botBtnW, botH, function()
                netstream.Start("NextRP::SaveDealers")
                LocalPlayer():ChatPrint("[SWExp] Терминалы сохранены!")
            end)
    end

    -- ============================================================
    -- Первичный запрос пула — BuildList вызовется из net.Receive
    -- ============================================================
    BuildList()
end

-- ============================================================================
-- Net hook
-- ============================================================================
netstream.Hook("SWExp::OpenSpawnerMenu", function(tVehs, eSpawner, tPlatforms, tVehicles, nFaction, tCarList)
    NextRPCarList = tVehs
    SWExp.CarDealer:OpenMenu(tVehs, eSpawner, tPlatforms, tVehicles, tCarList, nFaction)
end)

-- ============================================================================
-- РЕДАКТОР НАСТРОЕК ТРАНСПОРТА (суперадмин)
-- ============================================================================
concommand.Add("swexp_parseveh", function()
    local ply = LocalPlayer()
    if not ply:IsSuperAdmin() then print("[SWExp] Недостаточно прав!") return end

    local veh = ply:GetEyeTrace().Entity
    if not IsValid(veh) then print("[SWExp] Смотрите на технику!") return end

    netstream.Start("SWExp::GetVeh", veh, veh:GetClass())
end)

netstream.Hook("SWExp::GetVeh", function(vehData, vehEnt)
    if not IsValid(vehEnt) then return end

    local vehClass    = vehEnt:GetClass()
    local isRetrieved = (vehData ~= nil)
    local name  = isRetrieved and vehData.name        or vehEnt.PrintName or vehClass
    local mCost = isRetrieved and vehData.materialCost or 50
    local tLvl  = isRetrieved and vehData.techLevel    or 1
    local cRank = isRetrieved and vehData.createRank   or "TRP"
    local sRank = isRetrieved and vehData.spawnRank    or "TRP"

    local frame, content = SWUI.Animated.CreateWindow("Настройка: " .. name, 600, 420, nil, SWUI.Colors.Warn)
    local cW, cH = content:GetWide(), content:GetTall()
    local PAD = 14
    local yOff = 0

    local scroll = vgui.Create("DScrollPanel", content)
    scroll:SetPos(PAD, PAD)
    scroll:SetSize(cW - PAD * 2, cH - PAD * 2 - 58)
    scroll:GetVBar():SetWide(4)
    scroll:GetVBar().Paint = function(s, pw, ph)
        draw.RoundedBox(2, 0, 0, pw, ph, Color(255,255,255,12))
    end
    scroll:GetVBar().btnGrip.Paint = function(s, pw, ph)
        draw.RoundedBox(2, 0, 0, pw, ph, SWUI.Colors.Warn)
    end

    local rowW = cW - PAD * 2 - 20

    local function AddRow(label, default, isNum, onChange)
        local row = vgui.Create("DPanel", scroll)
        row:SetPos(0, yOff)
        row:SetSize(rowW, 38)
        row.Paint = function(self, pw, ph)
            SWUI.DrawRoundedRect(0, 0, pw, ph, 4, Color(6, 10, 16))
            surface.SetDrawColor(SWUI.Colors.Border)
            surface.DrawOutlinedRect(0, 0, pw, ph, 1)
            SWUI.DrawText(label, "SWUI.Small", 12, ph / 2,
                SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        local entry = vgui.Create("DTextEntry", row)
        entry:SetPos(rowW - 240, 4)
        entry:SetSize(228, 30)
        entry:SetText(tostring(default))
        entry:SetFont("SWUI.Mono")
        entry:SetNumeric(isNum or false)
        entry:SetTextColor(SWUI.Colors.TextHi)
        entry.Paint = function(self, ew, eh)
            SWUI.DrawRoundedRect(0, 0, ew, eh, 4, Color(4, 8, 14))
            surface.SetDrawColor(self:IsEditing() and SWUI.Colors.Warn or SWUI.Colors.Border)
            surface.DrawOutlinedRect(0, 0, ew, eh, 1)
            self:DrawTextEntryText(SWUI.Colors.TextHi, Color(255, 180, 0), SWUI.Colors.TextHi)
        end
        if onChange then entry.OnChange = function(s) onChange(s:GetValue()) end end
        yOff = yOff + 48
        return entry
    end

    local function AddRankRow(label, currentID, onSelect)
        local row = vgui.Create("DPanel", scroll)
        row:SetPos(0, yOff)
        row:SetSize(rowW, 38)
        row.Paint = function(self, pw, ph)
            SWUI.DrawRoundedRect(0, 0, pw, ph, 4, Color(6, 10, 16))
            surface.SetDrawColor(SWUI.Colors.Border)
            surface.DrawOutlinedRect(0, 0, pw, ph, 1)
            SWUI.DrawText(label, "SWUI.Small", 12, ph / 2,
                SWUI.Colors.Warn, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        local curName = "Выберите..."
        if SWExp.Ranks and SWExp.Ranks.List then
            for _, r in ipairs(SWExp.Ranks.List) do
                if r.id == currentID then curName = r.name break end
            end
        end
        local btn = vgui.Create("DPanel", row)
        btn:SetPos(rowW - 240, 4)
        btn:SetSize(228, 30)
        btn:SetCursor("hand")
        btn._label = curName
        btn.Paint = function(self, bw, bh)
            local hov = self:IsHovered()
            SWUI.DrawRoundedRect(0, 0, bw, bh, 4, hov and Color(20, 14, 0) or Color(4, 8, 14))
            surface.SetDrawColor(hov and SWUI.Colors.Warn or SWUI.Colors.Border)
            surface.DrawOutlinedRect(0, 0, bw, bh, 1)
            SWUI.DrawText(self._label .. "  ▼", "SWUI.Small", 10, bh / 2,
                SWUI.Colors.TextHi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        btn.OnMousePressed = function(self)
            local m = DermaMenu()
            if SWExp.Ranks and SWExp.Ranks.List then
                for _, rank in ipairs(SWExp.Ranks.List) do
                    local r = rank
                    m:AddOption(r.name, function()
                        self._label = r.name
                        if onSelect then onSelect(r.id) end
                    end)
                end
            end
            m:Open()
        end
        yOff = yOff + 48
        return btn
    end

    AddRow("Название:", name, false, function(v) name = v end)
    AddRow("Стоимость (мат.):", mCost, true, function(v) mCost = v end)
    AddRow("Тех. уровень (1–6):", tLvl, true, function(v) tLvl = v end)
    AddRankRow("Мин. звание (крафт):", cRank, function(id) cRank = id end)
    AddRankRow("Мин. звание (управление):", sRank, function(id) sRank = id end)

    MakeActionBtn(content, "СОХРАНИТЬ В БАЗУ", "accent",
        PAD, cH - PAD - 46, cW - PAD * 2, 46, function()
            netstream.Start("SWExp::VehUpdate", {
                class        = vehClass,
                name         = name,
                materialCost = tonumber(mCost) or 50,
                techLevel    = tonumber(tLvl)  or 1,
                createRank   = cRank,
                spawnRank    = sRank,
                skins        = isRetrieved and vehData.skins      or {},
                variations   = isRetrieved and vehData.variations or {},
            })
            frame:Close()
        end)
end)
