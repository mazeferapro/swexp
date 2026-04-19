-- ============================================================================
-- cl_interface.lua - Клиентский интерфейс дилера и редактор (SWUI)
-- ============================================================================

local MainFrame = nil

SWExp = SWExp or {}
SWExp.CarDealer = SWExp.CarDealer or {}
SWExp.CarDealer.VehiclePool = SWExp.CarDealer.VehiclePool or {}
SWExp.CarDealer.CurrentTechLevel = 1

-- Callback, вызываемый после получения SyncPool пока меню открыто.
-- Устанавливается в OpenMenu, сбрасывается после первого вызова.
local _onPoolSync = nil

-- ФИКС ПУСТОГО СПИСКА: при получении синхронизации, если меню открыто —
-- сразу перестраиваем список, чтобы не приходилось переключать вкладку
net.Receive("SWExp::CarDealer::SyncPool", function()
    SWExp.CarDealer.VehiclePool = net.ReadTable()
    SWExp.CarDealer.CurrentTechLevel = net.ReadUInt(8) or 1
    if _onPoolSync then
        _onPoolSync()
        _onPoolSync = nil
    end
end)

-- Клиентская консольная команда сохранения терминалов
concommand.Add('swexp_save_dealers', function()
    if not LocalPlayer():IsSuperAdmin() then
        print('[SWExp] Недостаточно прав!')
        return
    end
    netstream.Start('NextRP::SaveDealers')
    print('[SWExp] Запрос на сохранение терминалов отправлен...')
end)

-- ============================================================================
-- ИНТЕРФЕЙС ТЕРМИНАЛА (ГАРАЖ / ПРОИЗВОДСТВО)
-- ============================================================================
function SWExp.CarDealer:OpenMenu(tVehs, eEnt, tPlatforms, tVehicles, tCarList, nFaction)
    if IsValid(MainFrame) then MainFrame:Close() end

    -- Запрашиваем синк пула ДО открытия окна.
    -- BuildList() будет вызван ТОЛЬКО после ответа сервера (через _onPoolSync),
    -- чтобы список не был пустым при первом открытии.
    net.Start("SWExp::CarDealer::RequestSync")
    net.SendToServer()

    MainFrame = SWUI.Animated.CreateWindow('Терминал Техники', 1000, 700)
    local content = MainFrame.Content
    local cw, ch = content:GetWide(), content:GetTall()

    local titleBadge = vgui.Create("DPanel", MainFrame)
    titleBadge:SetSize(250, 26)
    titleBadge:SetPos(1000 - 350, 9)
    titleBadge.Paint = function(self, w, h)
        local currentMat = (SWExp and SWExp.Assembler and SWExp.Assembler._bank) or 0
        local txtTitle = "МАТЕРИАЛЫ:"
        local txtVal = tostring(currentMat)
        
        surface.SetFont("SWUI.Small")
        local twTitle, th = surface.GetTextSize(txtTitle)
        surface.SetFont("SWUI.Body")
        local twVal, _ = surface.GetTextSize(txtVal)

        local contentW = twTitle + twVal + 20
        local boxH = h

        local startX = w - contentW
        SWUI.DrawRoundedRect(startX, 0, contentW, boxH, 6, SWUI.Colors.Warn)

        SWUI.DrawText(txtTitle, "SWUI.Small", startX + 7, h/2, Color(255,255,255,180), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        SWUI.DrawText(txtVal, "SWUI.Body", startX + twTitle + 12, h/2, Color(255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local tabs = {
        { id = 'garage', label = 'ГАРАЖ (ПУЛ)' },
        { id = 'factory', label = 'ПРОИЗВОДСТВО' }
    }

    local activeTab = 'garage'
    
    local mainPanel = vgui.Create('DPanel', content)
    mainPanel:SetPos(0, 40)
    mainPanel:SetSize(cw, ch - 40 - 70) 
    mainPanel.Paint = function() end

    local function BuildList()
        mainPanel:Clear()

        local navItems = {}
        for k, v in ipairs(tVehs) do
            local countInPool = SWExp.CarDealer.VehiclePool[v.class] or 0

            if activeTab == 'garage' and countInPool <= 0 then continue end

            table.insert(navItems, {
                id = v.class,
                label = v.name,
                count = (activeTab == 'garage') and countInPool or nil,
                data = v
            })
        end

        local leftPanel = vgui.Create('DPanel', mainPanel)
        leftPanel:Dock(LEFT)
        leftPanel:SetWide(300)
        leftPanel.Paint = function(self, w, h)
            SWUI.DrawRoundedRect(0, 0, w, h, 8, SWUI.Colors.Panel2)
            surface.SetDrawColor(SWUI.Colors.Border)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        local leftScroll = vgui.Create("DScrollPanel", leftPanel)
        leftScroll:Dock(FILL)
        leftScroll:DockMargin(5, 5, 5, 5)
        
        local vbar = leftScroll:GetVBar()
        vbar:SetWide(4)
        vbar.Paint = function(s, pw, ph) draw.RoundedBox(2, 0, 0, pw, ph, Color(255,255,255,12)) end
        vbar.btnGrip.Paint = function(s, pw, ph) draw.RoundedBox(2, 0, 0, pw, ph, SWUI.Colors.Accent) end

        local rightPanel = vgui.Create('DPanel', mainPanel)
        rightPanel:Dock(FILL)
        rightPanel:DockMargin(10, 0, 0, 0)
        rightPanel.Paint = function(self, w, h)
            SWUI.DrawRoundedRect(0, 0, w, h, 8, SWUI.Colors.Panel2)
            surface.SetDrawColor(SWUI.Colors.Border)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        if #navItems == 0 then
            local lbl = vgui.Create("DLabel", rightPanel)
            lbl:SetText("Список пуст.")
            lbl:SetFont("SWUI.Body")
            lbl:SetTextColor(SWUI.Colors.TextDim)
            lbl:SizeToContents()
            lbl:Center()
            return
        end

        local activeVehID = navItems[1].id

        local function OnSelect(classID)
            activeVehID = classID
            rightPanel:Clear()
            local v = nil
            for _, item in ipairs(navItems) do if item.id == classID then v = item.data break end end
            if not v then return end

            local settings = SWExp.CarDealer:GetVehicleSettings(v.class)
            
            local cRankData = SWExp.Ranks and SWExp.Ranks:Get(settings.createRank)
            local createRankName = cRankData and cRankData.name or tostring(settings.createRank)
            local reqCreateOrder = cRankData and cRankData.sortOrder or 1

            local sRankData = SWExp.Ranks and SWExp.Ranks:Get(settings.spawnRank)
            local spawnRankName = sRankData and sRankData.name or tostring(settings.spawnRank)
            local reqSpawnOrder = sRankData and sRankData.sortOrder or 1

            local header = SWUI.CreateSectionHeader(rightPanel, v.name, 0, 0, rightPanel:GetWide())
            header:Dock(TOP)

            local infoPanel = vgui.Create('DPanel', rightPanel)
            infoPanel:Dock(TOP)
            infoPanel:SetTall(150)
            infoPanel.Paint = function(s, w, h)
                SWUI.DrawText(v.desc or 'Техника экспедиции', 'SWUI.Small', 20, 15, SWUI.Colors.Text)
                
                if activeTab == 'factory' then
                    SWUI.DrawText('Стоимость: ' .. settings.materialCost .. ' мат.', 'SWUI.Body', 20, 50, SWUI.Colors.Warn)
                    SWUI.DrawText('Требуемый ТЛ: ' .. settings.techLevel, 'SWUI.Small', 20, 80, SWUI.Colors.Accent)
                    SWUI.DrawText('Допуск к крафту: ' .. createRankName, 'SWUI.Small', 20, 110, SWUI.Colors.TextDim)
                else
                    SWUI.DrawText('В гараже: ' .. (SWExp.CarDealer.VehiclePool[v.class] or 0) .. ' шт.', 'SWUI.Body', 20, 50, SWUI.Colors.Green)
                    SWUI.DrawText('Допуск к управлению: ' .. spawnRankName, 'SWUI.Small', 20, 80, SWUI.Colors.TextDim)
                end
            end

            -- ЛОГИКА БЛОКИРОВКИ КНОПКИ
            local plyRankID = LocalPlayer():GetNWString("swexp_rank", "TRP")
            local plyRankData = SWExp.Ranks and SWExp.Ranks:Get(plyRankID)
            local plyOrder = plyRankData and plyRankData.sortOrder or 0

            -- ИСПРАВЛЕНИЕ: Берем актуальный ТЛ из кэша
            local currentTechLevel = SWExp.CarDealer.CurrentTechLevel or 1

            local hasRank = false
            if activeTab == 'factory' then
                hasRank = (plyOrder >= reqCreateOrder)
            else
                hasRank = (plyOrder >= reqSpawnOrder)
            end

            local btnText = ""
            local btnStyle = ""

            if not hasRank then
                btnText = "НЕДОСТАТОЧНО ЗВАНИЯ"
                btnStyle = "danger"
            elseif activeTab == 'factory' and currentTechLevel < settings.techLevel then
                btnText = "ТРЕБУЕТСЯ ТЕХ. УРОВЕНЬ " .. settings.techLevel
                btnStyle = "danger"
            else
                btnText = activeTab == 'factory' and ('ПРОИЗВЕСТИ ЗА ' .. settings.materialCost .. ' МАТ.') or 'ВЫЗВАТЬ ТЕХНИКУ'
                btnStyle = activeTab == 'factory' and 'warn' or 'accent'
            end

            local actionBtn = SWUI.CreateButton(rightPanel, btnText, 10, rightPanel:GetTall() - 50, rightPanel:GetWide() - 20, 40, btnStyle, function()
                if not hasRank then 
                    LocalPlayer():ChatPrint("[SWExp] У вас слишком низкое звание для этого действия!")
                    return 
                end
                if activeTab == 'factory' and currentTechLevel < settings.techLevel then
                    LocalPlayer():ChatPrint("[SWExp] Недостаточный технологический уровень базы!")
                    return
                end

                if activeTab == 'factory' then
                    netstream.Start('SWExp::CreateCar', v.class)
                else
                    netstream.Start('NextRP::SpawnCar', eEnt, v.class, 0, {})
                    MainFrame:Close()
                end
            end)
            actionBtn:Dock(BOTTOM)
            actionBtn:DockMargin(10, 10, 10, 10)
        end

        for _, item in ipairs(navItems) do
            local btn = vgui.Create("DButton", leftScroll)
            btn:Dock(TOP)
            btn:DockMargin(0, 0, 0, 4)
            btn:SetTall(44)
            btn:SetText("")
            btn.Paint = function(self, pw, ph)
                local active = (activeVehID == item.id)
                local hov = self:IsHovered()
                SWUI.DrawRoundedRect(0, 0, pw, ph, 5, active and SWUI.Colors.Accent or (hov and Color(255,255,255,18) or Color(255,255,255,6)))
                
                if active then
                    surface.SetDrawColor(Color(0,184,255,200))
                    surface.DrawOutlinedRect(0,0,pw,ph,1)
                end
                
                SWUI.DrawText(item.label, "SWUI.Body", 15, ph/2, active and Color(255,255,255) or SWUI.Colors.TextHi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                
                if item.count then
                    SWUI.DrawText("["..item.count.."]", "SWUI.Small", pw - 15, ph/2, SWUI.Colors.Green, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
            end
            btn.DoClick = function()
                OnSelect(item.id)
            end
        end

        OnSelect(navItems[1].id)
    end

    local tabBar = SWUI.CreateTabBar(content, tabs, 0, 0, 1000, 40, function(id)
        activeTab = id
        BuildList()
    end)

    -- ФИКС ПУСТОГО СПИСКА: не вызываем BuildList() сразу —
    -- ждём ответа сервера с актуальным пулом, затем строим список.
    -- Если ответ уже пришёл раньше (пул в кэше актуален) — строим немедленно.
    _onPoolSync = function()
        if IsValid(MainFrame) then BuildList() end
    end

    local bottomBtnContainer = vgui.Create("DPanel", content)
    bottomBtnContainer:SetSize(cw - 20, 50)
    bottomBtnContainer:SetPos(10, ch - 60)
    bottomBtnContainer.Paint = function() end 

    local isAdmin = LocalPlayer():IsSuperAdmin()

    -- Распределяем ширину кнопок: 1 кнопка (обычный) / 3 кнопки (админ)
    local totalW   = bottomBtnContainer:GetWide()
    local btnWidth = isAdmin and math.floor((totalW - 10) / 3) or totalW

    local returnBtn = SWUI.CreateButton(bottomBtnContainer, 'ВЕРНУТЬ ТЕХНИКУ', 0, 0, btnWidth, 40, 'danger', function()
        netstream.Start('NextRP::ReturnCar')
    end)
    returnBtn:Dock(LEFT)
    returnBtn:DockMargin(0, 5, 5, 5)
    returnBtn:SetWide(btnWidth)

    if isAdmin then
        local addPlatformBtn = SWUI.CreateButton(bottomBtnContainer, 'ДОБАВИТЬ ПЛАТФОРМУ', 0, 0, btnWidth, 40, 'accent', function()
            netstream.Start('SWExp::AddPlatform', eEnt)
        end)
        addPlatformBtn:Dock(LEFT)
        addPlatformBtn:DockMargin(0, 5, 5, 5)
        addPlatformBtn:SetWide(btnWidth)

        local saveBtn = SWUI.CreateButton(bottomBtnContainer, 'СОХРАНИТЬ ТЕРМИНАЛЫ', 0, 0, btnWidth, 40, 'warn', function()
            netstream.Start('NextRP::SaveDealers')
            LocalPlayer():ChatPrint('[SWExp] Терминалы сохранены!')
        end)
        saveBtn:Dock(LEFT)
        saveBtn:DockMargin(0, 5, 0, 5)
        saveBtn:SetWide(btnWidth)
    end
end

netstream.Hook('SWExp::OpenSpawnerMenu', function(tVehs, eSpawner, tPlatforms, tVehicles, nFaction, tCarList)
    NextRPCarList = tVehs
    SWExp.CarDealer:OpenMenu(tVehs, eSpawner, tPlatforms, tVehicles, tCarList, nFaction)
end)

-- ============================================================================
-- КОНСОЛЬНАЯ КОМАНДА ВЫЗОВА РЕДАКТОРА
-- ============================================================================
concommand.Add('swexp_parseveh', function()
    local ply = LocalPlayer()
    if not ply:IsSuperAdmin() then
        print('[SWExp] Недостаточно прав!')
        return
    end

    local trace = ply:GetEyeTrace()
    local veh = trace.Entity

    if not IsValid(veh) then
        print('[SWExp] Вы должны смотреть на технику!')
        return
    end

    local vehClass = veh:GetClass()
    netstream.Start('SWExp::GetVeh', veh, vehClass)
end)

-- ============================================================================
-- РЕДАКТОР НАСТРОЕК (ПРИЕМ ДАННЫХ ОТ СЕРВЕРА)
-- ============================================================================
netstream.Hook('SWExp::GetVeh', function(vehData, vehEnt)
    if not IsValid(vehEnt) then return end

    local vehClass = vehEnt:GetClass()
    local isRetrieved = (vehData ~= nil)
    local name = isRetrieved and vehData.name or vehEnt.PrintName or vehClass

    local mCost = isRetrieved and vehData.materialCost or 50
    local tLvl = isRetrieved and vehData.techLevel or 1
    local cRank = isRetrieved and vehData.createRank or 'TRP'
    local sRank = isRetrieved and vehData.spawnRank or 'TRP'

    local frame, content = SWUI.Animated.CreateWindow('Настройка: ' .. name, 600, 400)
    local cw, ch = content:GetWide(), content:GetTall()

    local saveBtn = SWUI.CreateButton(content, 'СОХРАНИТЬ В БАЗУ', 10, ch - 50, cw - 20, 40, 'accent', function()
        local vehTable = {
            class = vehClass,
            name = name,
            materialCost = tonumber(mCost) or 50,
            techLevel = tonumber(tLvl) or 1,
            createRank = cRank,
            spawnRank = sRank,
            skins = isRetrieved and vehData.skins or {},
            variations = isRetrieved and vehData.variations or {}
        }
        netstream.Start('SWExp::VehUpdate', vehTable)
        frame:Close()
    end)

    local scroll = SWUI.CreateScrollList(content, 10, 10, cw - 20, ch - 70)

    local yOff = 0

    local function AddInputRow(label, defaultVal, isNum, onChangeCallback)
        local row = vgui.Create('DPanel', scroll)
        row:SetPos(0, yOff)
        row:SetSize(scroll:GetWide() - 15, 32)
        row.Paint = function(self, w, h)
            SWUI.DrawText(label, 'SWUI.Small', 10, h/2, SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local input = SWUI.CreateInput(row, row:GetWide() - 360, 0, 360, 32, tostring(defaultVal))
        input.Entry:SetText(tostring(defaultVal))
        if isNum then input.Entry:SetNumeric(true) end

        if onChangeCallback then
            input.Entry.OnChange = function(s) onChangeCallback(s:GetValue()) end
        end

        yOff = yOff + 42
        return input
    end

    -- BUG-11 FIX: добавлено поле для редактирования имени транспорта
    AddInputRow("Название транспорта:", name, false, function(val) name = val end)
    AddInputRow("Мат. Стоимость:", mCost, true, function(val) mCost = val end)
    AddInputRow("Требуемый ТЛ (1-6):", tLvl, true, function(val) tLvl = val end)

    local function AddRankDropdown(label, currentRankID, onSelectCallback)
        local row = vgui.Create('DPanel', scroll)
        row:SetPos(0, yOff)
        row:SetSize(scroll:GetWide() - 15, 32)
        row.Paint = function(self, w, h)
            SWUI.DrawText(label, 'SWUI.Small', 10, h/2, SWUI.Colors.Warn, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        -- BUG-10 FIX: защита от nil на случай, если Ranks ещё не инициализированы
        local currentRankName = "Выберите..."
        if SWExp.Ranks and SWExp.Ranks.List then
            for _, r in ipairs(SWExp.Ranks.List) do
                if r.id == currentRankID then currentRankName = r.name break end
            end
        end

        local btn = vgui.Create('DButton', row)
        btn:SetPos(row:GetWide() - 360, 0)
        btn:SetSize(360, 32)
        btn:SetText("")
        btn._label = currentRankName

        btn.Paint = function(self, bw, bh)
            local bg  = self:IsHovered() and Color(20, 30, 40) or Color(0, 0, 0, 120)
            local brd = self:IsHovered() and SWUI.Colors.BorderHi or SWUI.Colors.Border
            SWUI.DrawRoundedRect(0, 0, bw, bh, 6, bg)
            surface.SetDrawColor(brd)
            surface.DrawOutlinedRect(0, 0, bw, bh, 1)
            SWUI.DrawText(self._label .. " ▼", 'SWUI.Body', 10, bh / 2, SWUI.Colors.TextHi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        btn.DoClick = function(self)
            local m = DermaMenu()
            -- BUG-10 FIX: защита от nil
            if SWExp.Ranks and SWExp.Ranks.List then
                for _, rank in ipairs(SWExp.Ranks.List) do
                    m:AddOption(rank.name, function()
                        self._label = rank.name
                        if onSelectCallback then onSelectCallback(rank.id) end
                    end)
                end
            else
                m:AddOption("(Ранги не загружены)", function() end)
            end
            m:Open()
        end

        yOff = yOff + 42
        return btn
    end

    AddRankDropdown("Мин. ранг производства:", cRank, function(newID) cRank = newID end)
    AddRankDropdown("Мин. ранг управления:", sRank, function(newID) sRank = newID end)
end)