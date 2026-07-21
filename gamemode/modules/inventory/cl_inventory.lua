--[[--
    SWExp: Клиентская часть системы инвентаря
    Модуль: inventory

    Компоновка окна:
    [ СЕТКА ИНВЕНТАРЯ ] [ 3D МОДЕЛЬ + СЛОТ БРОНИ ] [ СЛОТЫ СНАРЯЖЕНИЯ ]
]]--

SWExp.Inventory = SWExp.Inventory or {}
SWExp.Inventory.LocalData = {
    inventory = { grid = {}, items = {} },
    storage   = { grid = {}, items = {} },
    equipment = {}
}

SWExp.Inventory.UI          = nil
SWExp.Inventory.DraggedItem = nil
SWExp.Inventory._openCooldown = false  -- защита от зажатия клавиши

-- ============================================================================
-- СЕТЕВЫЕ ОБРАБОТЧИКИ
-- ============================================================================

netstream.Hook("SWExp::InventorySync", function(data)
    SWExp.Inventory.LocalData.inventory = data.inventory or { grid = {}, items = {} }
    SWExp.Inventory.LocalData.storage   = data.storage   or { grid = {}, items = {} }
    SWExp.Inventory.LocalData.equipment = data.equipment or {}
    if IsValid(SWExp.Inventory.UI) then
        SWExp.Inventory:RefreshUI()
    end
    -- Уведомляем модуль хранилища об обновлении данных
    hook.Run("SWExp::InventorySynced")
end)

netstream.Hook("SWExp::OpenDeathBag", function(data)
    SWExp.Inventory:OpenDeathBagUI(data.entIndex, data.items)
end)

netstream.Hook("SWExp::UpdateDeathBag", function(data)
    SWExp.Inventory:RefreshDeathBagUI(data.items)
end)

-- ============================================================================
-- ОТКРЫТИЕ ОКНА
-- ============================================================================

function SWExp.Inventory:OpenUI()
    -- Защита от зажатия клавиши: игнорируем повторный вызов в течение 0.3с
    if self._openCooldown then return end
    self._openCooldown = true
    timer.Simple(0.3, function() SWExp.Inventory._openCooldown = false end)

    -- Тоггл: если уже открыт — закрываем с анимацией
    if IsValid(self.UI) then
        SWUI.HideTooltip()
        local closing = self.UI
        self.UI = nil
        if closing.Close then
            closing:Close()
        else
            closing:Remove()
        end
        return
    end

    netstream.Start("SWExp::RequestInventoryOpen")

    local cfg  = self.Config
    local CELL = cfg.CellSize  -- 50

    -- Размеры трёх колонок
    local PAD      = 10
    local COL_INV  = cfg.GridWidth * CELL          -- 10*50 = 500
    local COL_MID  = 220
    local COL_EQP  = 260
    local WND_W    = PAD + COL_INV + PAD + COL_MID + PAD + COL_EQP + PAD
    local WND_H    = 680

    local frame, content = SWUI.Animated.CreateWindow("ИНВЕНТАРЬ", WND_W, WND_H)
    self.UI = frame

    -- Инвентарь — левая сторона экрана
    frame:SetPos(10, (ScrH() - WND_H) / 2)

    -- Контентная зона (без тайтлбара ~44px)
    local cH = WND_H - 44

    -- ==============================================================
    -- ЛЕВАЯ КОЛОНКА: Сетка инвентаря
    -- ==============================================================
    local xInv = PAD
    local yInv = PAD

    SWUI.CreateSectionHeader(content, "ИНВЕНТАРЬ", xInv, yInv, COL_INV)

    self.InventoryGrid = self:CreateGrid(content, cfg.GridWidth, cfg.GridHeight, "inventory")
    self.InventoryGrid:SetPos(xInv, yInv + 32)

    -- ==============================================================
    -- ЦЕНТРАЛЬНАЯ КОЛОНКА: Модель + слот брони
    -- ==============================================================
    local xMid = xInv + COL_INV + PAD

    local midPanel = vgui.Create("DPanel", content)
    midPanel:SetPos(xMid, yInv)
    midPanel:SetSize(COL_MID, cH - PAD * 2)
    midPanel.Paint = function(pnl, w, h)
        SWUI.DrawPanel(0, 0, w, h, 8, Color(8, 14, 20, 200), SWUI.Colors.Border, 1)
    end

    SWUI.CreateSectionHeader(midPanel, "ПЕРСОНАЖ", 0, 0, COL_MID)

    -- 3D-модель игрока — с анимацией входа и позой "armsinfront"
    local invPoseTime     = 0
    local invPoseProgress = 0

    local INV_POSE_BONES = {
        ["ValveBiped.Bip01_R_Forearm"]  = Angle(-43, -107,  15),
        ["ValveBiped.Bip01_R_UpperArm"] = Angle( 20,  -57,  -6),
        ["ValveBiped.Bip01_L_UpperArm"] = Angle(-28,  -59,   1),
        ["ValveBiped.Bip01_R_Thigh"]    = Angle(  4,   -6,   0),
        ["ValveBiped.Bip01_L_Thigh"]    = Angle( -7,    0,   0),
        ["ValveBiped.Bip01_L_Forearm"]  = Angle( 51, -120, -18),
        ["ValveBiped.Bip01_R_Hand"]     = Angle( 14,  -33,  -7),
        ["ValveBiped.Bip01_L_Hand"]     = Angle( 25,   31, -14),
    }

    local mdl = vgui.Create("DModelPanel", midPanel)
    mdl:SetPos(0, 32)
    mdl:SetSize(COL_MID, 340)
    mdl:SetFOV(25)
    mdl:SetLookAt(Vector(0, 0, 38))
    mdl:SetCamPos(Vector(120, 0, 38))
    mdl:SetAmbientLight(Color(80, 140, 200))
    mdl:SetDirectionalLight(BOX_FRONT,  Color(150, 200, 255))
    mdl:SetDirectionalLight(BOX_LEFT,   Color(0, 150, 220))
    mdl:SetDirectionalLight(BOX_RIGHT,  Color(0, 100, 180))
    mdl:SetDirectionalLight(BOX_BOTTOM, Color(20, 80, 140))

    function mdl:LayoutEntity(ent)
        local elapsed = CurTime() - invPoseTime
        ent:FrameAdvance(RealFrameTime())

        local camT = math.Clamp(elapsed / 1.1, 0, 1)
        camT = 1 - math.pow(1 - camT, 3)
        self:SetCamPos(Vector(120, Lerp(camT, 80, 0), 38))
        self:SetLookAt(Vector(0, 0, 38))
        ent:SetAngles(Angle(0, Lerp(camT, 30, 0), 0))

        local poseTarget = elapsed >= 0.5 and 1 or 0
        invPoseProgress = Lerp(FrameTime() * 3, invPoseProgress, poseTarget)

        for boneName, targetAng in pairs(INV_POSE_BONES) do
            local bid = ent:LookupBone(boneName)
            if bid and bid >= 0 then
                ent:ManipulateBoneAngles(bid, targetAng * invPoseProgress)
            end
        end
    end

    -- Скрываем панель до окончания анимации открытия окна
    mdl:SetAlpha(0)

    self._modelPanel = mdl

    -- Применяем сохранённые бодигруппы из LocalPlayer к панели превью
    -- ВАЖНО: функция объявлена ПОСЛЕ local mdl, иначе Lua не захватит upvalue
    local function ApplyBGToPanel()
        timer.Simple(0, function()
            if not IsValid(mdl) or not IsValid(LocalPlayer()) then return end
            local ply = LocalPlayer()
            for _, bg in pairs(mdl.Entity:GetBodyGroups()) do
                mdl.Entity:SetBodygroup(bg.id, ply:GetBodygroup(bg.id))
            end
            mdl.Entity:SetSkin(ply:GetSkin())
        end)
    end

    -- Загружаем модель без запуска анимации (тихая загрузка)
    local _lastModel = ""
    local function PreloadModel()
        if not IsValid(mdl) then return end
        if not IsValid(LocalPlayer()) then return end
        local curModel = LocalPlayer():GetModel()
        if curModel ~= "" and curModel ~= _lastModel then
            _lastModel = curModel
            mdl:SetModel(curModel)
            ApplyBGToPanel()
        end
    end
    PreloadModel()
    timer.Simple(0.15, PreloadModel)  -- запасной вызов, если модель ещё не пришла

    -- После анимации открытия окна (0.35с) показываем модель и запускаем вход
    timer.Simple(0.4, function()
        if not IsValid(mdl) then return end
        PreloadModel()
        invPoseTime     = CurTime()
        invPoseProgress = 0
        mdl:SetAlpha(255)
    end)

    -- Отслеживаем смену модели через таймер (не перекрываем Think панели)
    timer.Create("SWExpInvModelWatch", 0.1, 0, function()
        if not IsValid(mdl) then
            timer.Remove("SWExpInvModelWatch")
            return
        end
        if not IsValid(LocalPlayer()) then return end
        local curModel = LocalPlayer():GetModel()
        if curModel ~= "" and curModel ~= _lastModel then
            _lastModel = curModel
            mdl:SetModel(curModel)
            ApplyBGToPanel()
            -- Сбрасываем позу только если панель уже видна
            if mdl:GetAlpha() > 0 then
                invPoseTime     = CurTime()
                invPoseProgress = 0
            end
        end
    end)

    mdl.OnRemove = function()
        timer.Remove("SWExpInvModelWatch")
    end

    -- UpdateModel для вызовов из RefreshUI
    local function UpdateModel()
        if not IsValid(mdl) then return end
        local curModel = IsValid(LocalPlayer()) and LocalPlayer():GetModel() or ""
        if curModel ~= "" and curModel ~= _lastModel then
            _lastModel = curModel
            mdl:SetModel(curModel)
            ApplyBGToPanel()
            if mdl:GetAlpha() > 0 then
                invPoseTime     = CurTime()
                invPoseProgress = 0
            end
        end
    end
    self._updateModel = UpdateModel

    -- Скрываем модель при закрытии окна, до анимации закрытия (0.25с)
    local _origClose = frame.Close
    frame.Close = function(f)
        if IsValid(mdl) then mdl:SetAlpha(0) end
        _origClose(f)
    end

    -- Разделитель
    local divPanel = vgui.Create("DPanel", midPanel)
    divPanel:SetPos(8, 378)
    divPanel:SetSize(COL_MID - 16, 1)
    divPanel.Paint = function(p, w, h)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawRect(0, 0, w, h)
    end

    -- Метка слота брони
    local armorLblPanel = vgui.Create("DPanel", midPanel)
    armorLblPanel:SetPos(0, 384)
    armorLblPanel:SetSize(COL_MID, 18)
    armorLblPanel.Paint = function(p, w, h)
        SWUI.DrawText("КЛАСС / БРОНЯ", "SWUI.Tiny", w / 2, h / 2, SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Слот брони — по центру
    local ARMOR_SIZE = 68
    local armorSlotX = (COL_MID - ARMOR_SIZE) / 2
    local armorSlotY = 406
    local armorSlot  = vgui.Create("DButton", midPanel)
    armorSlot:SetPos(armorSlotX, armorSlotY)
    armorSlot:SetSize(ARMOR_SIZE, ARMOR_SIZE)
    armorSlot:SetText("")
    armorSlot.SlotType  = "armor"
    armorSlot.SlotIndex = 1
    self._armorSlot = armorSlot

    local function UpdateArmorModel() end
    self._updateArmorModel = UpdateArmorModel

    armorSlot.Paint = function(pnl, w, h)
        local hov  = pnl:IsHovered()
        local eq   = self.LocalData.equipment["armor"]
        local item = eq and eq[1]

        -- Подсветка при drag (принимает только броню)
        local dragHL = false
        if self.DraggedItem then
            local d = self:GetItemData(self.DraggedItem.itemID)
            if d and d.slotType == "armor" then dragHL = true end
        end

        local bg  = dragHL and Color(0, 60, 90, 180)
                    or item  and (hov and Color(0, 40, 65) or Color(26, 42, 54))
                    or (hov  and Color(0, 30, 50, 100) or Color(0, 0, 0, 100))
        local brd = dragHL and SWUI.Colors.Accent
                    or (hov and SWUI.Colors.BorderHi or SWUI.Colors.Border)

        SWUI.DrawRoundedRect(0, 0, w, h, 8, bg)
        surface.SetDrawColor(brd)
        surface.DrawOutlinedRect(0, 0, w, h, dragHL and 2 or 1)

        if item then
            local d = self:GetItemData(item.itemID)
            if d and d.icon then
                surface.SetDrawColor(255, 255, 255)
                surface.SetMaterial(Material(d.icon))
                surface.DrawTexturedRect(10, 10, w - 20, h - 20)
            end
        else
            SWUI.DrawText("БРОНЯ", "SWUI.Tiny", w / 2, h / 2, SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    armorSlot.OnCursorEntered = function(pnl)
        local eq = self.LocalData.equipment["armor"]
        local item = eq and eq[1]
        if item then
            local d = self:GetItemData(item.itemID)
            if d then self:_ShowEquipTooltip(d) end
        end
    end

    armorSlot.OnCursorExited = function()
        SWUI.HideTooltip()
    end

    armorSlot.DoRightClick = function(pnl)
        local eq = self.LocalData.equipment["armor"]
        if eq and eq[1] then
            SWUI.HideTooltip()
            self:OpenInventoryContextMenu(nil, "armor", 1)
        end
    end

    -- Описание под слотом брони
    local armorDescPanel = vgui.Create("DPanel", midPanel)
    armorDescPanel:SetPos(4, armorSlotY + ARMOR_SIZE + 6)
    armorDescPanel:SetSize(COL_MID - 8, 36)
    armorDescPanel.Paint = function(pnl, w, h)
        local eq   = self.LocalData.equipment["armor"]
        local item = eq and eq[1]
        if item then
            local d = self:GetItemData(item.itemID)
            if d then
                SWUI.DrawText(d.name or "", "SWUI.Tiny", w / 2, 6,  self:GetRarityColor(d.rarity), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                SWUI.DrawText("Класс: " .. string.upper(d.armorClass or "—"), "SWUI.Tiny", w / 2, 22, SWUI.Colors.TextDim,  TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            end
        else
            SWUI.DrawText("Броня не надета", "SWUI.Tiny", w / 2, h / 2, SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- ==============================================================
    -- ПРАВАЯ КОЛОНКА: Слоты снаряжения (primary, secondary, heavy, special)
    -- ==============================================================
    local xEqp = xMid + COL_MID + PAD

    local eqpPanel = vgui.Create("DPanel", content)
    eqpPanel:SetPos(xEqp, yInv)
    eqpPanel:SetSize(COL_EQP, cH - PAD * 2)
    eqpPanel.Paint = function() end

    SWUI.CreateSectionHeader(eqpPanel, "СНАРЯЖЕНИЕ", 0, 0, COL_EQP)

    -- Слоты: primary / secondary / heavy / special / medical
    local slotOrder = {"primary", "secondary", "heavy", "special", "medical", "grenade"}
    local slotLabels = {
        primary   = "ОСНОВНОЕ ОРУЖИЕ",
        secondary = "ВТОРОСТЕПЕННОЕ",
        heavy     = "ТЯЖЁЛОЕ ОРУЖИЕ",
        special   = "СПЕЦИАЛЬНОЕ",
        medical   = "МЕДИЦИНА",
    }
    -- special и medical: всегда открыты все слоты, без блокировки бронёй
    local ALWAYS_OPEN = { special = true, medical = true, grenade = true }

    self._equipSlots = {}

    local SLOT_SIZE = 56
    local SLOT_GAP  = 6
    local yOff = 34

    for _, slotType in ipairs(slotOrder) do
        local slotCfg = self.Config.EquipmentSlots[slotType]
        if not slotCfg then continue end

        -- Метка
        local lbl = vgui.Create("DPanel", eqpPanel)
        lbl:SetPos(2, yOff)
        lbl:SetSize(COL_EQP - 4, 18)
        local sTypeCopy = slotType
        lbl.Paint = function(p, w, h)
            SWUI.DrawText(slotLabels[sTypeCopy] or string.upper(sTypeCopy), "SWUI.Tiny", 4, h / 2, SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        yOff = yOff + 20

        self._equipSlots[slotType] = {}

        for i = 1, slotCfg.total do
            local slot = vgui.Create("DButton", eqpPanel)
            slot:SetPos((i - 1) * (SLOT_SIZE + SLOT_GAP) + 2, yOff)
            slot:SetSize(SLOT_SIZE, SLOT_SIZE)
            slot:SetText("")
            slot.SlotIndex = i
            slot.SlotType  = slotType
            self._equipSlots[slotType][i] = slot

            local si = i
            local st = slotType

            slot.Paint = function(pnl, w, h)
                local available = ALWAYS_OPEN[st] and slotCfg.total or self:GetDynamicSlotCount(st)
                local locked    = si > available
                local eq        = self.LocalData.equipment[st]
                local item      = eq and eq[si]
                local hov       = pnl:IsHovered()

                -- Подсветка при drag: показываем зелёным если предмет сюда подходит
                local dragHL = false
                if self.DraggedItem and not locked then
                    local d = self:GetItemData(self.DraggedItem.itemID)
                    if d and d.slotType == st and si <= available then
                        dragHL = true
                    end
                end

                if locked then
                    SWUI.DrawRoundedRect(0, 0, w, h, 8, Color(10, 10, 10, 80))
                    surface.SetDrawColor(Color(30, 30, 30))
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                    -- Иконка замка
                    local lx, ly = w/2, h/2
                    surface.SetDrawColor(SWUI.Colors.TextDim)
                    surface.DrawRect(lx - 5, ly - 8, 10, 7)
                    draw.RoundedBox(3, lx - 7, ly - 2, 14, 11, SWUI.Colors.TextDim)
                    draw.RoundedBox(2, lx - 2, ly + 1, 4, 5, Color(10, 10, 10, 200))
                elseif dragHL then
                    local bg  = item and Color(0, 50, 80) or Color(0, 40, 65, 140)
                    SWUI.DrawRoundedRect(0, 0, w, h, 8, bg)
                    surface.SetDrawColor(SWUI.Colors.Accent)
                    surface.DrawOutlinedRect(0, 0, w, h, 2)
                    if item then
                        local d = self:GetItemData(item.itemID)
                        if d and d.icon then
                            surface.SetDrawColor(255, 255, 255, 150)
                            surface.SetMaterial(Material(d.icon))
                            surface.DrawTexturedRect(8, 8, w - 16, h - 16)
                        end
                    end
                elseif item then
                    local bg  = hov and Color(0, 40, 65) or Color(26, 42, 54)
                    local brd = hov and SWUI.Colors.BorderHi or SWUI.Colors.Border
                    SWUI.DrawRoundedRect(0, 0, w, h, 8, bg)
                    surface.SetDrawColor(brd)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                    local d = self:GetItemData(item.itemID)
                    if d and d.icon then
                        surface.SetDrawColor(255, 255, 255)
                        surface.SetMaterial(Material(d.icon))
                        surface.DrawTexturedRect(8, 8, w - 16, h - 16)
                    end
                    if item.amount and item.amount > 1 then
                        SWUI.DrawTextShadow("x"..item.amount, "SWUI.Tiny", w - 4, h - 16, color_white, TEXT_ALIGN_RIGHT)
                    end
                else
                    local bg  = hov and Color(0, 30, 50, 100) or Color(0, 0, 0, 100)
                    local brd = hov and SWUI.Colors.BorderHi or SWUI.Colors.Border
                    SWUI.DrawRoundedRect(0, 0, w, h, 8, bg)
                    surface.SetDrawColor(brd)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                    SWUI.DrawText(tostring(si), "SWUI.Tiny", w / 2, h / 2, SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end

            slot.OnCursorEntered = function(pnl)
                local eq   = self.LocalData.equipment[st]
                local item = eq and eq[si]
                if item then
                    local d = self:GetItemData(item.itemID)
                    if d then self:_ShowEquipTooltip(d) end
                end
            end

            slot.OnCursorExited = function()
                SWUI.HideTooltip()
            end

            slot.DoRightClick = function(pnl)
                local available = ALWAYS_OPEN[st] and slotCfg.total or self:GetDynamicSlotCount(st)
                if si <= available then
                    local eq = self.LocalData.equipment[st]
                    if eq and eq[si] then
                        SWUI.HideTooltip()
                        self:OpenInventoryContextMenu(nil, st, si)
                    end
                end
            end
        end

        yOff = yOff + SLOT_SIZE + 10
    end

    self:RefreshUI()
end

-- ============================================================================
-- СОЗДАНИЕ СЕТКИ
-- ============================================================================

function SWExp.Inventory:CreateGrid(parent, gridWidth, gridHeight, gridType)
    local cfg  = self.Config
    local CELL = cfg.CellSize

    local grid = vgui.Create("DPanel", parent)
    grid:SetSize(gridWidth * CELL, gridHeight * CELL)
    grid.GridType   = gridType
    grid.GridWidth  = gridWidth
    grid.GridHeight = gridHeight
    grid.Cells = {}

    grid.Paint = function(pnl, w, h)
        SWUI.DrawPanel(0, 0, w, h, 4, Color(6, 10, 14, 210), SWUI.Colors.Border, 1)
    end

    for gy = 1, gridHeight do
        for gx = 1, gridWidth do
            local cell = vgui.Create("DPanel", grid)
            cell:SetPos((gx - 1) * CELL, (gy - 1) * CELL)
            cell:SetSize(CELL, CELL)
            cell.GX = gx
            cell.GY = gy
            cell.IsOccupied = false
            cell._highlight  = nil  -- "green" / "red" / nil

            cell.Paint = function(pnl, w, h)
                surface.SetDrawColor(SWUI.Colors.Border)
                surface.DrawOutlinedRect(0, 0, w, h)

                if pnl.IsOccupied and not pnl._highlight then
                    surface.SetDrawColor(0, 40, 65, 50)
                    surface.DrawRect(1, 1, w - 2, h - 2)
                end

                if pnl._highlight == "green" then
                    surface.SetDrawColor(0, 238, 119, 80)
                    surface.DrawRect(1, 1, w - 2, h - 2)
                    surface.SetDrawColor(0, 238, 119, 180)
                    surface.DrawOutlinedRect(0, 0, w, h)
                elseif pnl._highlight == "red" then
                    surface.SetDrawColor(255, 51, 34, 80)
                    surface.DrawRect(1, 1, w - 2, h - 2)
                    surface.SetDrawColor(255, 51, 34, 180)
                    surface.DrawOutlinedRect(0, 0, w, h)
                elseif pnl._highlight == "orange" then
                    -- Подсветка объединения стеков
                    surface.SetDrawColor(255, 165, 0, 80)
                    surface.DrawRect(1, 1, w - 2, h - 2)
                    surface.SetDrawColor(255, 165, 0, 220)
                    surface.DrawOutlinedRect(0, 0, w, h)
                end
            end

            grid.Cells[gx .. "_" .. gy] = cell
        end
    end

    -- Think: обновляем подсветку ячеек при drag
    grid.Think = function(pnl)
        if not self.DraggedItem then
            -- Сброс
            for _, cell in pairs(grid.Cells) do
                cell._highlight = nil
            end
            return
        end

        local itemData = self:GetItemData(self.DraggedItem.itemID)
        if not itemData then return end

        -- Сбрасываем
        for _, cell in pairs(grid.Cells) do
            cell._highlight = nil
        end

        -- Ищем ячейку под курсором
        local mx, my = gui.MousePos()
        local ox, oy = grid:LocalToScreen(0, 0)
        local relX = mx - ox
        local relY = my - oy

        if relX < 0 or relY < 0 or relX >= grid:GetWide() or relY >= grid:GetTall() then return end

        local hovX = math.floor(relX / CELL) + 1
        local hovY = math.floor(relY / CELL) + 1

        local stor = gridType == "storage" and self.LocalData.storage or self.LocalData.inventory
        local tmpGrid = table.Copy(stor.grid or {})
        if self.DraggedItem.uniqueID then
            for k, v in pairs(tmpGrid) do
                if v == self.DraggedItem.uniqueID then tmpGrid[k] = nil end
            end
        end

        -- Учитываем поворот при расчёте занимаемых ячеек
        local rotated = self.DraggedItem.rotated == true or self.DraggedItem.rotated == 1
        local iW = rotated and (itemData.height or 1) or (itemData.width  or 1)
        local iH = rotated and (itemData.width  or 1) or (itemData.height or 1)

        -- Проверяем, можно ли объединить стек: предмет складываемый и под курсором
        -- лежит стек того же типа с незаполненным максимумом
        if itemData.stackable then
            local hovKey  = hovX .. "_" .. hovY
            local realStor = gridType == "storage" and self.LocalData.storage or self.LocalData.inventory
            local hovUID  = realStor.grid and realStor.grid[hovKey]
            if hovUID and hovUID ~= self.DraggedItem.uniqueID then
                local hovItem = realStor.items and realStor.items[hovUID]
                if hovItem and hovItem.itemID == self.DraggedItem.itemID
                    and (hovItem.amount or 1) < (itemData.maxStack or 1) then
                    -- Подсвечиваем ячейку целевого стека оранжевым (merge)
                    local mergeCell = grid.Cells[hovKey]
                    if mergeCell then mergeCell._highlight = "orange" end
                    return
                end
            end
        end

        -- Временная копия itemData с повёрнутыми размерами для CanFitItem
        local fakeData = { width = iW, height = iH }
        local fits = self:CanFitItem(tmpGrid, gridWidth, gridHeight, fakeData, hovX, hovY)
        local col  = fits and "green" or "red"

        for dx = 0, iW - 1 do
            for dy = 0, iH - 1 do
                local cx = hovX + dx
                local cy = hovY + dy
                local cell = grid.Cells[cx .. "_" .. cy]
                if cell then cell._highlight = col end
            end
        end
    end

    return grid
end

-- ============================================================================
-- ОБНОВЛЕНИЕ UI
-- ============================================================================

function SWExp.Inventory:RefreshUI()
    if not IsValid(self.UI) then return end

    -- Обновить модель сразу и с задержкой (модель игрока может реплицироваться чуть позже синка)
    if self._updateModel then
        self._updateModel()
        timer.Simple(0.3, function()
            if IsValid(SWExp.Inventory.UI) and SWExp.Inventory._updateModel then
                SWExp.Inventory._updateModel()
            end
        end)
    end

    -- Обновить 3D-модель в слоте брони
    if self._updateArmorModel then
        self._updateArmorModel()
    end

    -- Перерисовать предметы в сетке
    self:ClearItemPanels(self.InventoryGrid)
    self:DrawItems(self.InventoryGrid, self.LocalData.inventory, "inventory")
end

function SWExp.Inventory:ClearItemPanels(grid)
    if not IsValid(grid) then return end
    for _, child in pairs(grid:GetChildren()) do
        if child.IsItemPanel then child:Remove() end
    end
    if grid.Cells then
        for _, cell in pairs(grid.Cells) do
            cell.IsOccupied = false
            cell._highlight  = nil
        end
    end
end

function SWExp.Inventory:DrawItems(grid, storageData, gridType)
    if not IsValid(grid) or not storageData then return end
    local cfg  = self.Config
    local CELL = cfg.CellSize

    -- Занятые ячейки
    for key, uid in pairs(storageData.grid or {}) do
        if grid.Cells[key] then grid.Cells[key].IsOccupied = true end
    end

    for uniqueID, item in pairs(storageData.items or {}) do
        local itemData = self:GetItemData(item.itemID)
        if not itemData then continue end

        -- Учитываем поворот предмета (нормализуем: netstream может дать true/1/false/nil)
        local rotated = item.rotated == true or item.rotated == 1
        local baseW   = itemData.width  or 1
        local baseH   = itemData.height or 1
        local itemW   = (rotated and baseH or baseW) * CELL
        local itemH   = (rotated and baseW or baseH) * CELL
        local posX    = (item.posX - 1) * CELL
        local posY    = (item.posY - 1) * CELL

        local ip = vgui.Create("DButton", grid)
        ip.IsItemPanel = true
        ip.UniqueID    = uniqueID
        ip.ItemData    = itemData
        ip.Item        = item
        ip.GridType    = gridType
        ip:SetPos(posX, posY)
        ip:SetSize(itemW, itemH)
        ip:SetText("")
        ip:MoveToFront()

        ip.Paint = function(pnl, w, h)
            local rarCol  = self:GetRarityColor(itemData.rarity)
            local hov     = pnl:IsHovered()
            local isRot   = ip.Item.rotated == true or ip.Item.rotated == 1

            draw.RoundedBox(4, 2, 2, w - 4, h - 4, ColorAlpha(rarCol, hov and 160 or 90))

            if itemData.icon then
                local sz = math.min(w, h) - 10
                surface.SetDrawColor(255, 255, 255)
                surface.SetMaterial(Material(itemData.icon))
                surface.DrawTexturedRect(w / 2 - sz / 2, h / 2 - sz / 2, sz, sz)
            end

            if item.amount and item.amount > 1 then
                SWUI.DrawTextShadow("x"..item.amount, "SWUI.Small", w - 6, h - 22, color_white, TEXT_ALIGN_RIGHT)
            end

            surface.SetDrawColor(rarCol)
            surface.DrawOutlinedRect(2, 2, w - 4, h - 4, 1)
            if isRot then
                SWUI.DrawText("↻", "SWUI.Tiny", w - 4, 4, Color(255,255,255,120), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            end
        end

        ip.OnMousePressed = function(pnl, btn)
            if btn == MOUSE_LEFT then
                SWUI.HideTooltip()
                -- Shift + ЛКМ: быстрое перемещение между инвентарём и хранилищем
                if input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT) then
                    if gridType == "storage" then
                        -- Из хранилища → инвентарь
                        netstream.Start("SWExp::InventoryQuickMove", {
                            uniqueID    = uniqueID,
                            fromStorage = true,
                            toStorage   = false,
                        })
                    elseif gridType == "inventory" and SWExp.CharLocker and IsValid(SWExp.CharLocker.UI) then
                        -- Из инвентаря → хранилище (только если окно хранилища открыто)
                        netstream.Start("SWExp::InventoryQuickMove", {
                            uniqueID    = uniqueID,
                            fromStorage = false,
                            toStorage   = true,
                        })
                    else
                        self:StartDrag(pnl)
                    end
                else
                    self:StartDrag(pnl)
                end
            elseif btn == MOUSE_RIGHT then
                SWUI.HideTooltip()
                self:OpenInventoryContextMenu(pnl)
            end
        end

        ip.OnCursorEntered = function(pnl)
            if not self.DraggedItem then
                self:ShowItemTooltip(pnl)
            end
        end

        ip.OnCursorExited = function()
            SWUI.HideTooltip()
        end
    end
end

-- ============================================================================
-- DRAG & DROP
-- ============================================================================

-- Пересоздаёт визуальный ghost при drag (с учётом поворота)
function SWExp.Inventory:_RebuildDragVisual()
    if IsValid(self._dragVisual) then self._dragVisual:Remove() end

    local itemData = self:GetItemData(self.DraggedItem.itemID)
    local CELL     = self.Config.CellSize
    local rotated  = self.DraggedItem.rotated == true or self.DraggedItem.rotated == 1
    local baseW    = itemData.width  or 1
    local baseH    = itemData.height or 1
    local dW = (rotated and baseH or baseW) * CELL
    local dH = (rotated and baseW or baseH) * CELL

    local vis = vgui.Create("DPanel")
    vis:SetSize(dW, dH)
    vis:SetMouseInputEnabled(false)
    vis:MakePopup()
    self._dragVisual = vis

    local inv = self
    vis.Paint = function(p, w, h)
        local col = inv:GetRarityColor(itemData.rarity)
        draw.RoundedBox(4, 0, 0, w, h, ColorAlpha(col, 200))
        if itemData.icon then
            -- Иконка вписана в панель (панель уже нужного размера с учётом поворота)
            local sz = math.min(w, h) - 8
            surface.SetDrawColor(255, 255, 255, 230)
            surface.SetMaterial(Material(itemData.icon))
            surface.DrawTexturedRect(w / 2 - sz / 2, h / 2 - sz / 2, sz, sz)
        end
        surface.SetDrawColor(col)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        if rotated then
            SWUI.DrawText("↻", "SWUI.Tiny", w - 4, 4, Color(255,255,255,180), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end
    end

    return dW, dH
end

function SWExp.Inventory:StartDrag(itemPanel)
    SWUI.HideTooltip()

    self.DraggedItem = {
        itemID      = itemPanel.Item.itemID,
        uniqueID    = itemPanel.UniqueID,
        amount      = itemPanel.Item.amount,
        fromStorage = itemPanel.GridType == "storage",
        -- Сохраняем текущий поворот предмета (нормализуем в булево)
        rotated     = itemPanel.Item.rotated == true or itemPanel.Item.rotated == 1,
    }

    local dW, dH = self:_RebuildDragVisual()

    hook.Add("Think", "SWExp::Drag", function()
        if not IsValid(self._dragVisual) then
            hook.Remove("Think", "SWExp::Drag")
            return
        end
        -- Проверяем Space для поворота
        if input.IsKeyDown(KEY_SPACE) then
            if not self._spaceWasDown then
                self._spaceWasDown = true
                -- Меняем флаг поворота
                self.DraggedItem.rotated = not self.DraggedItem.rotated
                dW, dH = self:_RebuildDragVisual()
            end
        else
            self._spaceWasDown = false
        end

        local mx, my = gui.MousePos()
        if IsValid(self._dragVisual) then
            self._dragVisual:SetPos(mx - dW / 2, my - dH / 2)
        end

        if not input.IsMouseDown(MOUSE_LEFT) then
            self:EndDrag()
        end
    end)
end

function SWExp.Inventory:EndDrag()
    if not self.DraggedItem then return end

    -- Если тащим из сумки — обрабатывает отдельная функция
    if self.DraggedItem.fromBag then
        self:EndBagDrag()
        return
    end

    if IsValid(self._dragVisual) then self._dragVisual:Remove() end

    local mx, my  = gui.MousePos()
    local CELL    = self.Config.CellSize
    local dropped = false

    -- Проверяем сетку инвентаря
    local grid = self.InventoryGrid
    if IsValid(grid) then
        local gx, gy = grid:LocalToScreen(0, 0)
        local gw, gh = grid:GetSize()
        if mx >= gx and mx <= gx + gw and my >= gy and my <= gy + gh then
            local cellX = math.floor((mx - gx) / CELL) + 1
            local cellY = math.floor((my - gy) / CELL) + 1

            -- Проверяем возможность объединения стеков перед обычным перемещением
            local invData    = self.LocalData.inventory
            local dragData   = self:GetItemData(self.DraggedItem.itemID)
            local targetUID  = invData.grid and invData.grid[cellX .. "_" .. cellY]

            if targetUID and targetUID ~= self.DraggedItem.uniqueID
                and dragData and dragData.stackable then
                local targetItem = invData.items and invData.items[targetUID]
                if targetItem and targetItem.itemID == self.DraggedItem.itemID
                    and (targetItem.amount or 1) < (dragData.maxStack or 1) then
                    -- Объединяем стеки
                    netstream.Start("SWExp::InventoryMergeItems", {
                        sourceUID   = self.DraggedItem.uniqueID,
                        targetUID   = targetUID,
                        fromStorage = self.DraggedItem.fromStorage,
                        toStorage   = false,
                    })
                    dropped = true
                end
            end

            if not dropped then
                netstream.Start("SWExp::InventoryMoveItem", {
                    uniqueID    = self.DraggedItem.uniqueID,
                    newX        = cellX,
                    newY        = cellY,
                    fromStorage = self.DraggedItem.fromStorage,
                    toStorage   = false,
                    rotated     = self.DraggedItem.rotated or false,
                })
                dropped = true
            end
        end
    end

    -- Проверяем сетку хранилища (окно swexp_char_locker)
    if not dropped and SWExp.CharLocker and IsValid(SWExp.CharLocker.StorageGrid) then
        local sg = SWExp.CharLocker.StorageGrid
        local gx, gy = sg:LocalToScreen(0, 0)
        local gw, gh = sg:GetSize()
        if mx >= gx and mx <= gx + gw and my >= gy and my <= gy + gh then
            local cellX = math.floor((mx - gx) / CELL) + 1
            local cellY = math.floor((my - gy) / CELL) + 1

            local storData   = self.LocalData.storage
            local dragData   = self:GetItemData(self.DraggedItem.itemID)
            local targetUID  = storData.grid and storData.grid[cellX .. "_" .. cellY]

            if targetUID and targetUID ~= self.DraggedItem.uniqueID
                and dragData and dragData.stackable then
                local targetItem = storData.items and storData.items[targetUID]
                if targetItem and targetItem.itemID == self.DraggedItem.itemID
                    and (targetItem.amount or 1) < (dragData.maxStack or 1) then
                    netstream.Start("SWExp::InventoryMergeItems", {
                        sourceUID   = self.DraggedItem.uniqueID,
                        targetUID   = targetUID,
                        fromStorage = self.DraggedItem.fromStorage,
                        toStorage   = true,
                    })
                    dropped = true
                end
            end

            if not dropped then
                netstream.Start("SWExp::InventoryMoveItem", {
                    uniqueID    = self.DraggedItem.uniqueID,
                    newX        = cellX,
                    newY        = cellY,
                    fromStorage = self.DraggedItem.fromStorage,
                    toStorage   = true,
                    rotated     = self.DraggedItem.rotated or false,
                })
                dropped = true
            end
        end
    end

    -- Проверяем слот брони
    if not dropped and IsValid(self._armorSlot) then
        local sx, sy = self._armorSlot:LocalToScreen(0, 0)
        local sw, sh = self._armorSlot:GetSize()
        if mx >= sx and mx <= sx + sw and my >= sy and my <= sy + sh then
            local itemData = self:GetItemData(self.DraggedItem.itemID)
            if itemData and itemData.slotType == "armor" then
                netstream.Start("SWExp::InventoryEquipItem", {
                    uniqueID    = self.DraggedItem.uniqueID,
                    slotType    = "armor",
                    slotIndex   = 1,
                    fromStorage = self.DraggedItem.fromStorage
                })
                dropped = true
            end
        end
    end

    -- Проверяем слоты снаряжения
    if not dropped and self._equipSlots then
        for slotType, slots in pairs(self._equipSlots) do
            for i, slot in pairs(slots) do
                if IsValid(slot) then
                    local sx, sy = slot:LocalToScreen(0, 0)
                    local sw, sh = slot:GetSize()
                    if mx >= sx and mx <= sx + sw and my >= sy and my <= sy + sh then
                        local itemData  = self:GetItemData(self.DraggedItem.itemID)
                        local available = self:GetDynamicSlotCount(slotType)
                        if itemData and itemData.slotType == slotType and i <= available then
                            netstream.Start("SWExp::InventoryEquipItem", {
                                uniqueID    = self.DraggedItem.uniqueID,
                                slotType    = slotType,
                                slotIndex   = i,
                                fromStorage = self.DraggedItem.fromStorage
                            })
                            dropped = true
                        end
                        break
                    end
                end
            end
            if dropped then break end
        end
    end

    -- Выброс за пределы окна
    -- Предмет выбрасывается только если мышь вне обоих окон: инвентаря И хранилища.
    if not dropped then
        local insideAnyWindow = false

        if IsValid(self.UI) then
            local ux, uy = self.UI:LocalToScreen(0, 0)
            local uw, uh = self.UI:GetSize()
            if mx >= ux and mx <= ux + uw and my >= uy and my <= uy + uh then
                insideAnyWindow = true
            end
        end

        if not insideAnyWindow and SWExp.CharLocker and IsValid(SWExp.CharLocker.UI) then
            local lx, ly = SWExp.CharLocker.UI:LocalToScreen(0, 0)
            local lw, lh = SWExp.CharLocker.UI:GetSize()
            if mx >= lx and mx <= lx + lw and my >= ly and my <= ly + lh then
                insideAnyWindow = true
            end
        end

        if not insideAnyWindow then
            netstream.Start("SWExp::InventoryDropItem", {
                uniqueID    = self.DraggedItem.uniqueID,
                fromStorage = self.DraggedItem.fromStorage
            })
        end
    end

    self.DraggedItem = nil
    hook.Remove("Think", "SWExp::Drag")
end

-- ============================================================================
-- ДИАЛОГ РАЗДЕЛЕНИЯ СТЕКА
-- ============================================================================

function SWExp.Inventory:OpenSplitDialog(itemPanel)
    if IsValid(self._splitDialog) then self._splitDialog:Remove() end

    local item     = itemPanel.Item
    local maxSplit = item.amount - 1    -- минимум 1 предмет остаётся в исходном стеке
    local splitAmt = math.max(1, math.floor(maxSplit / 2))

    -- ---------------------------------------------------------------
    -- Окно через SWUI
    -- ---------------------------------------------------------------
    local WND_W, WND_H = 360, 220
    local PAD = 10
    local frame, content = SWUI.Animated.CreateWindow("РАЗДЕЛИТЬ СТЕК", WND_W, WND_H)
    self._splitDialog = frame
    frame:Center()

    -- ── Информационная строка ────────────────────────────────────────
    local infoPanel = vgui.Create("DPanel", content)
    infoPanel:SetPos(PAD, 6)
    infoPanel:SetSize(WND_W - PAD * 2, 24)
    infoPanel.Paint = function(pnl, w, h)
        SWUI.DrawText(
            (itemPanel.ItemData.name or "") .. "  ·  в стеке: " .. item.amount,
            "SWUI.Tiny", w / 2, h / 2,
            SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
    end

    -- ── Тонкий разделитель ──────────────────────────────────────────
    local sep = vgui.Create("DPanel", content)
    sep:SetPos(PAD, 34)
    sep:SetSize(WND_W - PAD * 2, 1)
    sep.Paint = function(pnl, w, h)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawRect(0, 0, w, h)
    end

    -- ── Счётчик (кнопки − / цифра / +) ─────────────────────────────
    local CTRL_Y   = 42
    local BTN_SIZE = 38
    local NUM_W    = WND_W - PAD * 2 - BTN_SIZE * 2 - 8

    -- Кнопка «−»
    local btnMinus = vgui.Create("DButton", content)
    btnMinus:SetPos(PAD, CTRL_Y)
    btnMinus:SetSize(BTN_SIZE, BTN_SIZE)
    btnMinus:SetText("")
    btnMinus.Paint = function(pnl, w, h)
        local col = pnl:IsHovered() and SWUI.Colors.Accent or SWUI.Colors.Border
        SWUI.DrawRoundedRect(0, 0, w, h, 5, ColorAlpha(col, pnl:IsHovered() and 40 or 15))
        surface.SetDrawColor(col)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        SWUI.DrawText("−", "SWUI.Body", w / 2, h / 2 - 1, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btnMinus.DoClick = function()
        splitAmt = math.max(1, splitAmt - 1)
    end

    -- Дисплей текущего значения
    local numDisplay = vgui.Create("DPanel", content)
    numDisplay:SetPos(PAD + BTN_SIZE + 4, CTRL_Y)
    numDisplay:SetSize(NUM_W, BTN_SIZE)
    numDisplay.Paint = function(pnl, w, h)
        SWUI.DrawPanel(0, 0, w, h, 4, Color(4, 8, 12, 180), SWUI.Colors.Border, 1)
        SWUI.DrawText(
            tostring(splitAmt),
            "SWUI.Body", w / 2, h / 2,
            SWUI.Colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
    end

    -- Кнопка «+»
    local btnPlus = vgui.Create("DButton", content)
    btnPlus:SetPos(PAD + BTN_SIZE + 4 + NUM_W + 4, CTRL_Y)
    btnPlus:SetSize(BTN_SIZE, BTN_SIZE)
    btnPlus:SetText("")
    btnPlus.Paint = function(pnl, w, h)
        local col = pnl:IsHovered() and SWUI.Colors.Accent or SWUI.Colors.Border
        SWUI.DrawRoundedRect(0, 0, w, h, 5, ColorAlpha(col, pnl:IsHovered() and 40 or 15))
        surface.SetDrawColor(col)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        SWUI.DrawText("+", "SWUI.Body", w / 2, h / 2 - 1, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btnPlus.DoClick = function()
        splitAmt = math.min(maxSplit, splitAmt + 1)
    end

    -- ── Кастомный слайдер ───────────────────────────────────────────
    local SL_Y   = CTRL_Y + BTN_SIZE + 8
    local SL_H   = 14
    local SL_W   = WND_W - PAD * 2

    local sliderPanel = vgui.Create("DPanel", content)
    sliderPanel:SetPos(PAD, SL_Y)
    sliderPanel:SetSize(SL_W, SL_H)
    sliderPanel:SetMouseInputEnabled(true)

    local function sliderFrac() return (splitAmt - 1) / math.max(1, maxSplit - 1) end

    sliderPanel.Paint = function(pnl, w, h)
        -- Трек
        draw.RoundedBox(3, 0, h / 2 - 2, w, 4, Color(20, 34, 44, 200))
        -- Заливка
        local fill = math.max(0, sliderFrac() * w)
        if fill > 0 then
            draw.RoundedBox(3, 0, h / 2 - 2, fill, 4, SWUI.Colors.Accent)
        end
        -- Ползунок
        local tx = math.Clamp(fill, 5, w - 5)
        draw.RoundedBox(5, tx - 5, h / 2 - 5, 10, 10, SWUI.Colors.Accent)
        surface.SetDrawColor(Color(255, 255, 255, 60))
        surface.DrawOutlinedRect(tx - 5, h / 2 - 5, 10, 10, 1)
    end

    -- Обновляем значение по позиции курсора на слайдере
    local function updateSliderFromMouse()
        if not IsValid(sliderPanel) then return end
        local mx, _ = sliderPanel:CursorPos()
        local frac  = math.Clamp(mx / sliderPanel:GetWide(), 0, 1)
        splitAmt = math.Clamp(math.Round(1 + frac * (maxSplit - 1)), 1, maxSplit)
    end

    sliderPanel.OnMousePressed = function(pnl, btn)
        if btn == MOUSE_LEFT then updateSliderFromMouse() end
    end

    -- Think для перетаскивания ползунка
    hook.Add("Think", "SWExp::SplitSliderDrag", function()
        if not IsValid(sliderPanel) then
            hook.Remove("Think", "SWExp::SplitSliderDrag")
            return
        end
        if input.IsMouseDown(MOUSE_LEFT) and sliderPanel:IsHovered() then
            updateSliderFromMouse()
        end
    end)

    -- ── Кнопки «Разделить» / «Отмена» ───────────────────────────────
    local BTN_Y = SL_Y + SL_H + 10
    local BTN_W = (WND_W - PAD * 2 - 6) / 2

    local btnOk = vgui.Create("DButton", content)
    btnOk:SetPos(PAD, BTN_Y)
    btnOk:SetSize(BTN_W, 38)
    btnOk:SetText("")
    btnOk.Paint = function(pnl, w, h)
        local col = pnl:IsHovered() and SWUI.Colors.Green or SWUI.Colors.Border
        SWUI.DrawRoundedRect(0, 0, w, h, 5, ColorAlpha(col, pnl:IsHovered() and 50 or 20))
        surface.SetDrawColor(col)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        SWUI.DrawText("Разделить", "SWUI.Body", w / 2, h / 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btnOk.DoClick = function()
        if splitAmt >= 1 and splitAmt < item.amount then
            netstream.Start("SWExp::InventorySplitItem", {
                uniqueID    = itemPanel.UniqueID,
                amount      = splitAmt,
                fromStorage = itemPanel.GridType == "storage",
            })
        end
        hook.Remove("Think", "SWExp::SplitSliderDrag")
        frame:Remove()
    end

    local btnCancel = vgui.Create("DButton", content)
    btnCancel:SetPos(PAD + BTN_W + 6, BTN_Y)
    btnCancel:SetSize(BTN_W, 38)
    btnCancel:SetText("")
    btnCancel.Paint = function(pnl, w, h)
        local col = pnl:IsHovered() and SWUI.Colors.Red or SWUI.Colors.Border
        SWUI.DrawRoundedRect(0, 0, w, h, 5, ColorAlpha(col, pnl:IsHovered() and 50 or 20))
        surface.SetDrawColor(col)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        SWUI.DrawText("Отмена", "SWUI.Body", w / 2, h / 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btnCancel.DoClick = function()
        hook.Remove("Think", "SWExp::SplitSliderDrag")
        frame:Remove()
    end

    -- Чистим хук при закрытии окна
    frame.OnClose = function()
        hook.Remove("Think", "SWExp::SplitSliderDrag")
    end
end

-- ============================================================================
-- КОНТЕКСТНОЕ МЕНЮ (стиль scoreboard)
-- ============================================================================

-- itemPanel: панель предмета из инвентаря (или nil если снять с экипировки)
-- equipSlotType, equipSlotIndex: если это слот экипировки
function SWExp.Inventory:OpenInventoryContextMenu(itemPanel, equipSlotType, equipSlotIndex)
    -- Уничтожаем старое меню если было
    if IsValid(self._ctxMenu) then
        self._ctxMenu:Remove()
        self._ctxMenu = nil
    end

    local menu = DermaMenu()
    self._ctxMenu = menu
    menu:SetMinimumWidth(200)

    menu.Paint = function(pnl, w, h)
        draw.RoundedBox(8, 0, 0, w, h, SWUI.Colors.BorderHi)
        draw.RoundedBox(7, 1, 1, w - 2, h - 2, SWUI.Colors.Panel2)
    end

    local function AddOpt(text, col, icon, callback)
        local opt = menu:AddOption(text)
        opt:SetFont("SWUI.Body")
        opt:SetTextColor(col)
        opt:SetTall(34)
        opt.DoClick = function()
            SWUI.HideTooltip()
            callback()
        end
        opt.Paint = function(pnl, w, h)
            if pnl:IsHovered() then
                draw.RoundedBox(4, 4, 2, w - 8, h - 4, ColorAlpha(col, 25))
            end
        end
        if icon then opt:SetIcon(icon) end
        return opt
    end

    local function AddSep()
        local sep = menu:AddSpacer()
        if sep then
            sep.Paint = function(pnl, w, h)
                surface.SetDrawColor(SWUI.Colors.Border)
                surface.DrawLine(10, h / 2, w - 10, h / 2)
            end
        end
    end

    -- Если это слот экипировки — только "Снять"
    if equipSlotType then
        AddOpt("Снять", SWUI.Colors.Warn, "icon16/arrow_down.png", function()
            netstream.Start("SWExp::InventoryUnequipItem", {
                slotType  = equipSlotType,
                slotIndex = equipSlotIndex
            })
        end)
        menu:Open()
        return
    end

    -- Иначе — контекст предмета из инвентаря
    if not itemPanel or not itemPanel.ItemData then return end
    local itemData = itemPanel.ItemData

    -- Разделение стека — только для складываемых предметов с количеством > 1
    if itemData.stackable and itemPanel.Item and (itemPanel.Item.amount or 1) > 1 then
        AddOpt("Разделить стек", SWUI.Colors.Warn, "icon16/arrow_divide.png", function()
            self:OpenSplitDialog(itemPanel)
        end)
        AddSep()
    end

    if itemData.onUse then
        AddOpt("Использовать", SWUI.Colors.Green, "icon16/accept.png", function()
            netstream.Start("SWExp::InventoryUseItem", {
                uniqueID    = itemPanel.UniqueID,
                fromStorage = itemPanel.GridType == "storage"
            })
        end)
        AddSep()
    end

    if itemData.slotType then
        AddOpt("Экипировать", SWUI.Colors.Accent, "icon16/shield.png", function()
            if itemData.slotType == "armor" then
                netstream.Start("SWExp::InventoryEquipItem", {
                    uniqueID    = itemPanel.UniqueID,
                    slotType    = "armor",
                    slotIndex   = 1,
                    fromStorage = itemPanel.GridType == "storage"
                })
                return
            end
            local slotCfg  = self.Config.EquipmentSlots[itemData.slotType]
            local alwaysOpen = { special = true, medical = true, grenade = true }
            local available = alwaysOpen[itemData.slotType] and slotCfg.total or self:GetDynamicSlotCount(itemData.slotType)
            for si = 1, available do
                local eq = self.LocalData.equipment[itemData.slotType]
                if not eq or not eq[si] then
                    netstream.Start("SWExp::InventoryEquipItem", {
                        uniqueID    = itemPanel.UniqueID,
                        slotType    = itemData.slotType,
                        slotIndex   = si,
                        fromStorage = itemPanel.GridType == "storage"
                    })
                    break
                end
            end
        end)
    end

    if itemData.canDrop then
        AddSep()
        AddOpt("Выбросить", SWUI.Colors.Red, "icon16/bin.png", function()
            netstream.Start("SWExp::InventoryDropItem", {
                uniqueID    = itemPanel.UniqueID,
                fromStorage = itemPanel.GridType == "storage"
            })
        end)
    end

    -- Стилизуем разделители — уже внутри AddSep
    menu:Open()
end

-- ============================================================================
-- ТУЛТИПЫ
-- ============================================================================

-- Тултип для предметов в инвентаре
function SWExp.Inventory:ShowItemTooltip(itemPanel)
    if not itemPanel or not itemPanel.ItemData then return end
    -- Передаём контекст (тип сетки) чтобы тултип мог показать подсказку Shift+ЛКМ
    self:_ShowItemDataTooltip(itemPanel.ItemData, itemPanel.GridType)
end

-- Тултип для экипированных предметов
function SWExp.Inventory:_ShowEquipTooltip(itemData)
    self:_ShowItemDataTooltip(itemData)
end

-- Локализация слотов экипировки
local SLOT_NAMES = {
    armor     = "Броня",
    primary   = "Основное оружие",
    secondary = "Второстепенное оружие",
    heavy     = "Тяжёлое оружие",
    special   = "Специальное",
}

-- Общая функция отображения тултипа
-- gridType: "inventory" / "storage" / "bag" / nil — используется для подсказки Shift+ЛКМ
function SWExp.Inventory:_ShowItemDataTooltip(itemData, gridType)
    local stats = {
        { label = "Размер", value = (itemData.width or 1) .. "×" .. (itemData.height or 1) },
    }

    -- Слот экипировки вместо веса
    if itemData.slotType then
        local slotName = SLOT_NAMES[itemData.slotType] or itemData.slotType
        table.insert(stats, { label = "Слот", value = slotName, col = SWUI.Colors.Accent })
    end

    -- Характеристики брони
    if itemData.armorTier then
        table.insert(stats, { label = "Тир",    value = tostring(itemData.armorTier),                           col = SWUI.Colors.Warn  })
        table.insert(stats, { label = "Защита", value = math.Round((itemData.armorReduction or 0) * 100) .. "%", col = SWUI.Colors.Green })
        local armorClassNames = {
            light    = "Лёгкий",
            medium   = "Средний",
            heavy    = "Тяжёлый",
            engineer = "Инженерный",
            medical  = "Медицинский",
        }
        local cls = itemData.armorClass or "none"
        table.insert(stats, { label = "Класс", value = armorClassNames[cls] or string.upper(cls), col = SWUI.Colors.Accent })
    end

    -- Обрезаем описание до 80 символов
    local desc = itemData.description or ""
    if #desc > 80 then desc = string.sub(desc, 1, 77) .. "..." end

    -- Подсказка Shift+ЛКМ в зависимости от контекста
    local shiftHint = nil
    if gridType == "bag" then
        shiftHint = "Shift+ЛКМ: взять в инвентарь"
    elseif gridType == "storage" then
        shiftHint = "Shift+ЛКМ: перенести в инвентарь"
    elseif gridType == "inventory" and SWExp.CharLocker and IsValid(SWExp.CharLocker.UI) then
        shiftHint = "Shift+ЛКМ: перенести в хранилище"
    end
    if shiftHint then
        table.insert(stats, { label = shiftHint, value = "", col = Color(0, 200, 255, 180) })
    end

    SWUI.ShowTooltip(itemData.name, self:GetRarityName(itemData.rarity), desc, stats)
end

-- ============================================================================
-- УТИЛИТЫ КЛИЕНТА
-- ============================================================================

function SWExp.Inventory:GetDynamicSlotCount(slotType)
    -- Слоты, не зависящие от класса брони: всегда открыты полностью
    local alwaysOpen = { special = true, medical = true, grenade = true }
    if alwaysOpen[slotType] then
        local cfg = self.Config.EquipmentSlots[slotType]
        return cfg and cfg.total or 1
    end

    local eq    = self.LocalData.equipment["armor"]
    local armed = eq and eq[1]
    local cls   = "none"
    if armed then
        local d = self:GetItemData(armed.itemID)
        if d then cls = d.armorClass or "none" end
    end
    local map = {
        light    = { primary = 1, secondary = 2, heavy = 0 },
        medium   = { primary = 2, secondary = 2, heavy = 0 },
        heavy    = { primary = 1, secondary = 2, heavy = 1 },
        engineer = { primary = 1, secondary = 2, heavy = 0 },
        medical  = { primary = 1, secondary = 2, heavy = 0 },
        none     = { primary = 0, secondary = 1, heavy = 0 },
    }
    local limits = map[cls] or map["none"]
    local fromMap = limits[slotType]
    if fromMap ~= nil then return fromMap end
    local slotCfg = self.Config.EquipmentSlots[slotType]
    return slotCfg and slotCfg.free or 1
end

-- ============================================================================
-- СУМКА СМЕРТИ
-- ============================================================================

-- Виртуальная «сетка» сумки смерти для drag&drop
-- items: таблица {[uniqueID] = {itemID, amount, posX, posY}}
-- Мы размещаем предметы автоматически при получении
function SWExp.Inventory:_BuildBagGrid(items, bagW)
    local BAG_W = bagW or (self.Config and self.Config.GridWidth or 10)

    -- Сначала считаем суммарную площадь предметов чтобы подобрать минимальную высоту
    local totalCells = 0
    for _, item in pairs(items or {}) do
        if item.isAmmo then
            totalCells = totalCells + 1  -- амmo занимает 1x1
        else
            local d = self:GetItemData(item.itemID)
            if d then totalCells = totalCells + (d.width or 1) * (d.height or 1) end
        end
    end
    -- Минимум GridHeight строк (как у инвентаря игрока), расширяем при необходимости (запас +2 строки)
    local minRows = self.Config and self.Config.GridHeight or 6
    local BAG_H = math.max(minRows, math.ceil(totalCells / BAG_W) + 2)

    local grid = {}
    local placed = {}

    for uid, item in pairs(items or {}) do
        -- Боезапас отображается как 1x1 ячейка
        if item.isAmmo then
            local fakeD = { width = 1, height = 1 }
            local px, py = self:FindFreeSlot(grid, BAG_W, BAG_H, fakeD)
            if px then
                grid[px .. "_" .. py] = uid
                placed[uid] = { itemID = item.itemID, ammoType = item.ammoType, amount = item.amount or 0, isAmmo = true, posX = px, posY = py, rotated = false }
            end
            continue
        end

        local d = self:GetItemData(item.itemID)
        if not d then continue end

        -- В сумке предметы всегда без поворота (оригинальные размеры)
        local px, py = self:FindFreeSlot(grid, BAG_W, BAG_H, d)

        if px then
            for x = px, px + (d.width or 1) - 1 do
                for y = py, py + (d.height or 1) - 1 do
                    grid[x .. "_" .. y] = uid
                end
            end
            placed[uid] = { itemID = item.itemID, amount = item.amount or 1, posX = px, posY = py, rotated = false }
        end
    end

    return placed, grid, BAG_W, BAG_H
end

function SWExp.Inventory:OpenDeathBagUI(entIndex, rawItems)
    if IsValid(self.DeathBagUI) then self.DeathBagUI:Remove() end

    -- Открываем инвентарь если не открыт (чтобы можно было перетаскивать)
    if not IsValid(self.UI) then
        self:OpenUI()
        -- Небольшая задержка чтобы UI успел создаться
        timer.Simple(0.05, function()
            SWExp.Inventory:_CreateDeathBagWindow(entIndex, rawItems)
        end)
        return
    end

    self:_CreateDeathBagWindow(entIndex, rawItems)
end

function SWExp.Inventory:_CreateDeathBagWindow(entIndex, rawItems)
    if IsValid(self.DeathBagUI) then self.DeathBagUI:Remove() end

    local cfg  = self.Config
    local CELL = cfg.CellSize
    local BAG_W = cfg.GridWidth   -- совпадает с шириной инвентаря игрока
    local PAD   = 12
    local MAX_VISIBLE_ROWS = cfg.GridHeight  -- совпадает с высотой инвентаря игрока

    -- Сначала строим grid чтобы узнать реальный BAG_H
    local placedItems, bagGrid, rW, rH = self:_BuildBagGrid(rawItems, BAG_W)
    local BAG_H = rH

    self.LocalData.deathBag = { grid = bagGrid, items = placedItems }

    -- Высота контентной области (с ограничением по экрану)
    local visibleH = math.min(BAG_H, MAX_VISIBLE_ROWS) * CELL
    local needsScroll = BAG_H > MAX_VISIBLE_ROWS

    local wndW = PAD + BAG_W * CELL + PAD
    local wndH = 44 + PAD + 28 + visibleH + PAD

    local frame, content = SWUI.Animated.CreateWindow("СУМКА СНАРЯЖЕНИЯ", wndW, wndH)
    self.DeathBagUI = frame
    frame.DeathBagEnt = entIndex

    -- Сумка — правая сторона экрана, по центру по вертикали
    frame:SetPos(ScrW() - wndW - 10, (ScrH() - wndH) / 2)

    SWUI.CreateSectionHeader(content, "ПРЕДМЕТЫ В СУМКЕ", PAD, PAD, BAG_W * CELL)

    if needsScroll then
        -- Скролл-панель для длинных сумок
        local scroll = vgui.Create("DScrollPanel", content)
        scroll:SetPos(PAD, PAD + 28)
        scroll:SetSize(BAG_W * CELL, visibleH)
        -- Убираем стандартный скроллбар стиль
        local sbar = scroll:GetVBar()
        sbar:SetWide(6)

        self.DeathBagGrid = self:CreateBagGrid(scroll, BAG_W, BAG_H, entIndex)
        self.DeathBagGrid:SetPos(0, 0)
    else
        self.DeathBagGrid = self:CreateBagGrid(content, BAG_W, BAG_H, entIndex)
        self.DeathBagGrid:SetPos(PAD, PAD + 28)
    end

    self:_DrawBagItems(entIndex, rawItems)

    -- При закрытии окна чистим данные
    frame.OnClose = function()
        self.LocalData.deathBag = nil
        self.DeathBagGrid = nil
    end
end

-- Создаём сетку для сумки — отдельная функция потому что у сумки нет MoveItem,
-- только "взять" (TakeFromBag)
function SWExp.Inventory:CreateBagGrid(parent, gridW, gridH, entIndex)
    local CELL = self.Config.CellSize

    local grid = vgui.Create("DPanel", parent)
    grid:SetSize(gridW * CELL, gridH * CELL)
    grid.GridType  = "bag"
    grid.GridWidth  = gridW
    grid.GridHeight = gridH
    grid.Cells = {}

    grid.Paint = function(pnl, w, h)
        SWUI.DrawPanel(0, 0, w, h, 4, Color(6, 10, 14, 210), SWUI.Colors.Border, 1)
    end

    for gy = 1, gridH do
        for gx = 1, gridW do
            local cell = vgui.Create("DPanel", grid)
            cell:SetPos((gx - 1) * CELL, (gy - 1) * CELL)
            cell:SetSize(CELL, CELL)
            cell.IsOccupied = false
            cell._highlight  = nil

            cell.Paint = function(pnl, w, h)
                surface.SetDrawColor(SWUI.Colors.Border)
                surface.DrawOutlinedRect(0, 0, w, h)
                if pnl.IsOccupied then
                    surface.SetDrawColor(60, 15, 0, 60)
                    surface.DrawRect(1, 1, w - 2, h - 2)
                end
            end

            grid.Cells[gx .. "_" .. gy] = cell
        end
    end

    return grid
end

function SWExp.Inventory:_DrawBagItems(entIndex, rawItems)
    if not IsValid(self.DeathBagGrid) then return end
    local grid = self.DeathBagGrid
    local CELL = self.Config.CellSize

    -- Очищаем старые панели
    for _, child in pairs(grid:GetChildren()) do
        if child.IsItemPanel then child:Remove() end
    end
    for _, cell in pairs(grid.Cells) do
        cell.IsOccupied = false
    end

    -- Перестраиваем grid по актуальным rawItems
    local p, bg = self:_BuildBagGrid(rawItems, grid.GridWidth)
    local bagData = { grid = bg, items = p }
    self.LocalData.deathBag = bagData

    local placed  = bagData.items
    local bagGrid = bagData.grid

    -- Занятые ячейки
    for key, _ in pairs(bagGrid) do
        if grid.Cells[key] then grid.Cells[key].IsOccupied = true end
    end

    for uid, item in pairs(placed) do
        local posX = (item.posX - 1) * CELL
        local posY = (item.posY - 1) * CELL

        -- Специальная отрисовка для боезапаса
        if item.isAmmo then
            local ip = vgui.Create("DButton", grid)
            ip.IsItemPanel = true
            ip.UniqueID    = uid
            ip.Item        = item
            ip.GridType    = "bag"
            ip:SetPos(posX, posY)
            ip:SetSize(CELL, CELL)
            ip:SetText("")
            ip:MoveToFront()

            local ammoColor = Color(255, 200, 50)

            ip.Paint = function(pnl, w, h)
                local hov = pnl:IsHovered()
                draw.RoundedBox(4, 2, 2, w - 4, h - 4, hov and Color(80, 60, 10, 180) or Color(50, 38, 8, 160))
                draw.SimpleText("[AMO]", "SWUI.Tiny", w / 2, h / 2 - 8, ammoColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText(item.ammoType or "", "SWUI.Tiny", w / 2, h / 2 + 6, Color(220, 200, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                SWUI.DrawTextShadow("x" .. (item.amount or 0), "SWUI.Tiny", w - 4, h - 14, color_white, TEXT_ALIGN_RIGHT)
                surface.SetDrawColor(ammoColor)
                surface.DrawOutlinedRect(2, 2, w - 4, h - 4, 1)
            end

            ip.OnMousePressed = function(pnl, btn)
                if btn == MOUSE_LEFT then
                    -- Shift + ЛКМ: быстро взять боезапас из сумки
                    if input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT) then
                        SWUI.HideTooltip()
                        netstream.Start("SWExp::InventoryTakeFromBag", {
                            entIndex = entIndex,
                            uniqueID = uid,
                        })
                    end
                elseif btn == MOUSE_RIGHT then
                    SWUI.HideTooltip()
                    local capturedUID = uid
                    local capturedEnt = entIndex
                    local menu = DermaMenu()
                    menu:SetMinimumWidth(200)
                    local opt = menu:AddOption("Взять боезапас")
                    opt:SetFont("SWUI.Body")
                    opt:SetTextColor(Color(80, 220, 80))
                    opt:SetTall(34)
                    opt.DoClick = function()
                        netstream.Start("SWExp::InventoryTakeFromBag", {
                            entIndex = capturedEnt,
                            uniqueID = capturedUID
                        })
                    end
                    menu:Open()
                end
            end

            ip.OnCursorEntered = function(pnl)
                SWUI.ShowTooltip("Боезапас: " .. (item.ammoType or "?"), nil,
                    "Количество: " .. (item.amount or 0) .. " ед.",
                    {{ label = "Shift+ЛКМ: взять в инвентарь", value = "", col = Color(0, 200, 255, 180) }}
                )
            end
            ip.OnCursorExited = function() SWUI.HideTooltip() end
            continue
        end

        local d = self:GetItemData(item.itemID)
        if not d then continue end

        -- В сумке предметы всегда без поворота
        local itemW = (d.width  or 1) * CELL
        local itemH = (d.height or 1) * CELL

        local ip = vgui.Create("DButton", grid)
        ip.IsItemPanel = true
        ip.UniqueID    = uid
        ip.ItemData    = d
        ip.Item        = item
        ip.GridType    = "bag"
        ip:SetPos(posX, posY)
        ip:SetSize(itemW, itemH)
        ip:SetText("")
        ip:MoveToFront()

        ip.Paint = function(pnl, w, h)
            local rarCol = self:GetRarityColor(d.rarity)
            local hov    = pnl:IsHovered()
            draw.RoundedBox(4, 2, 2, w - 4, h - 4, ColorAlpha(rarCol, hov and 160 or 90))
            if d.icon then
                local sz = math.min(w, h) - 10
                surface.SetDrawColor(255, 255, 255)
                surface.SetMaterial(Material(d.icon))
                surface.DrawTexturedRect(w / 2 - sz / 2, h / 2 - sz / 2, sz, sz)
            end
            if item.amount and item.amount > 1 then
                SWUI.DrawTextShadow("x"..item.amount, "SWUI.Small", w - 6, h - 22, color_white, TEXT_ALIGN_RIGHT)
            end
            surface.SetDrawColor(rarCol)
            surface.DrawOutlinedRect(2, 2, w - 4, h - 4, 1)
        end

        -- ЛКМ: начать drag (источник = "bag"); Shift+ЛКМ — быстро взять в инвентарь
        ip.OnMousePressed = function(pnl, btn)
            if btn == MOUSE_LEFT then
                SWUI.HideTooltip()
                if input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT) then
                    -- Shift + ЛКМ: сразу забрать предмет из сумки в инвентарь
                    local capturedUID = uid
                    local capturedEnt = entIndex
                    netstream.Start("SWExp::InventoryTakeFromBag", {
                        entIndex = capturedEnt,
                        uniqueID = capturedUID,
                    })
                else
                    self:StartBagDrag(pnl, entIndex)
                end
            elseif btn == MOUSE_RIGHT then
                SWUI.HideTooltip()
                local capturedUID = uid
                local capturedEnt = entIndex
                local capturedItem = d  -- itemData уже объявлен выше как d

                local menu = DermaMenu()
                menu:SetMinimumWidth(200)
                menu.Paint = function(p, w, h)
                    draw.RoundedBox(8, 0, 0, w, h, SWUI.Colors.BorderHi)
                    draw.RoundedBox(7, 1, 1, w - 2, h - 2, SWUI.Colors.Panel2)
                end

                local function AddBagOpt(text, col, callback)
                    local opt = menu:AddOption(text)
                    opt:SetFont("SWUI.Body")
                    opt:SetTextColor(col)
                    opt:SetTall(34)
                    opt.DoClick = function() callback() end
                    opt.Paint = function(p, w, h)
                        if p:IsHovered() then draw.RoundedBox(4, 4, 2, w - 8, h - 4, ColorAlpha(col, 25)) end
                    end
                    return opt
                end

                -- "Экипировать" — только если у предмета есть slotType
                if capturedItem and capturedItem.slotType then
                    AddBagOpt("Экипировать", SWUI.Colors.Accent, function()
                        local st = capturedItem.slotType
                        if st == "armor" then
                            netstream.Start("SWExp::InventoryEquipFromBag", {
                                entIndex  = capturedEnt,
                                uniqueID  = capturedUID,
                                slotType  = "armor",
                                slotIndex = 1,
                            })
                        else
                            local slotCfg    = self.Config.EquipmentSlots[st]
                            local alwaysOpen = { special = true, medical = true, grenade = true }
                            local available  = alwaysOpen[st] and slotCfg.total or self:GetDynamicSlotCount(st)
                            -- Ищем первый свободный слот
                            for si = 1, available do
                                local eq = self.LocalData.equipment[st]
                                if not eq or not eq[si] then
                                    netstream.Start("SWExp::InventoryEquipFromBag", {
                                        entIndex  = capturedEnt,
                                        uniqueID  = capturedUID,
                                        slotType  = st,
                                        slotIndex = si,
                                    })
                                    break
                                end
                            end
                        end
                    end)
                end

                -- Разделитель
                if capturedItem and capturedItem.slotType then
                    local sep = menu:AddSpacer()
                    if sep then
                        sep.Paint = function(p, w, h)
                            surface.SetDrawColor(SWUI.Colors.Border)
                            surface.DrawLine(10, h / 2, w - 10, h / 2)
                        end
                    end
                end

                AddBagOpt("Взять в инвентарь", SWUI.Colors.Green, function()
                    netstream.Start("SWExp::InventoryTakeFromBag", {
                        entIndex = capturedEnt,
                        uniqueID = capturedUID
                    })
                end)

                menu:Open()
            end
        end

        ip.OnCursorEntered = function(pnl)
            if not self.DraggedItem then
                -- Используем _ShowItemDataTooltip напрямую с gridType = "bag" для подсказки Shift+ЛКМ
                self:_ShowItemDataTooltip(d, "bag")
            end
        end

        ip.OnCursorExited = function()
            SWUI.HideTooltip()
        end
    end
end

-- Drag из сумки в инвентарь/слоты
function SWExp.Inventory:StartBagDrag(itemPanel, entIndex)
    self.DraggedItem = {
        itemID      = itemPanel.Item.itemID,
        uniqueID    = itemPanel.UniqueID,
        amount      = itemPanel.Item.amount,
        fromBag     = true,
        bagEntIndex = entIndex,
        fromStorage = false,
        rotated     = false,
    }

    local dW, dH = self:_RebuildDragVisual()

    hook.Add("Think", "SWExp::Drag", function()
        if not IsValid(self._dragVisual) then
            hook.Remove("Think", "SWExp::Drag")
            return
        end
        -- Space — поворот
        if input.IsKeyDown(KEY_SPACE) then
            if not self._spaceWasDown then
                self._spaceWasDown = true
                self.DraggedItem.rotated = not self.DraggedItem.rotated
                dW, dH = self:_RebuildDragVisual()
            end
        else
            self._spaceWasDown = false
        end

        local mx, my = gui.MousePos()
        if IsValid(self._dragVisual) then
            self._dragVisual:SetPos(mx - dW / 2, my - dH / 2)
        end
        if not input.IsMouseDown(MOUSE_LEFT) then
            self:EndBagDrag()
        end
    end)
end

function SWExp.Inventory:EndBagDrag()
    if not self.DraggedItem or not self.DraggedItem.fromBag then return end
    if IsValid(self._dragVisual) then self._dragVisual:Remove() end

    local mx, my  = gui.MousePos()
    local CELL    = self.Config.CellSize
    local dropped = false
    local bagEnt  = self.DraggedItem.bagEntIndex
    local bagUID  = self.DraggedItem.uniqueID
    local itemData = self:GetItemData(self.DraggedItem.itemID)

    -- 1. Слот брони
    if not dropped and IsValid(self._armorSlot) then
        local sx, sy = self._armorSlot:LocalToScreen(0, 0)
        local sw, sh = self._armorSlot:GetSize()
        if mx >= sx and mx <= sx + sw and my >= sy and my <= sy + sh then
            if itemData and itemData.slotType == "armor" then
                netstream.Start("SWExp::InventoryEquipFromBag", {
                    entIndex  = bagEnt,
                    uniqueID  = bagUID,
                    slotType  = "armor",
                    slotIndex = 1,
                })
                dropped = true
            end
        end
    end

    -- 2. Слоты снаряжения
    if not dropped and self._equipSlots then
        local ALWAYS_OPEN = { special = true, grenade = true }
        for slotType, slots in pairs(self._equipSlots) do
            for i, slot in pairs(slots) do
                if IsValid(slot) then
                    local sx, sy = slot:LocalToScreen(0, 0)
                    local sw, sh = slot:GetSize()
                    if mx >= sx and mx <= sx + sw and my >= sy and my <= sy + sh then
                        local slotCfg  = self.Config.EquipmentSlots[slotType]
                        local available = ALWAYS_OPEN[slotType] and slotCfg.total or self:GetDynamicSlotCount(slotType)
                        if itemData and itemData.slotType == slotType and i <= available then
                            netstream.Start("SWExp::InventoryEquipFromBag", {
                                entIndex  = bagEnt,
                                uniqueID  = bagUID,
                                slotType  = slotType,
                                slotIndex = i,
                            })
                            dropped = true
                        end
                        break
                    end
                end
            end
            if dropped then break end
        end
    end

    -- 3. Сетка инвентаря (взять с сохранением поворота)
    if not dropped then
        local grid = self.InventoryGrid
        if IsValid(grid) then
            local gx, gy = grid:LocalToScreen(0, 0)
            local gw, gh = grid:GetSize()
            if mx >= gx and mx <= gx + gw and my >= gy and my <= gy + gh then
                local cellX = math.floor((mx - gx) / CELL) + 1
                local cellY = math.floor((my - gy) / CELL) + 1
                netstream.Start("SWExp::InventoryTakeFromBag", {
                    entIndex = bagEnt,
                    uniqueID = bagUID,
                    rotated  = self.DraggedItem.rotated or false,
                    newX     = cellX,
                    newY     = cellY,
                })
                dropped = true
            end
        end
    end

    self.DraggedItem = nil
    hook.Remove("Think", "SWExp::Drag")
end

function SWExp.Inventory:RefreshDeathBagUI(items)
    if not IsValid(self.DeathBagUI) then return end
    local entIndex = self.DeathBagUI.DeathBagEnt

    -- Если сумка пуста — закрываем окно с анимацией
    if table.Count(items or {}) == 0 then
        local closing = self.DeathBagUI
        self.DeathBagUI = nil
        if closing.Close then
            closing:Close()
        else
            closing:Remove()
        end
        return
    end

    self:_DrawBagItems(entIndex, items)
end

-- ============================================================================
-- КОМАНДЫ И БИНДИНГИ
-- ============================================================================

concommand.Add("swexp_inventory", function()
    SWExp.Inventory:OpenUI()
end)

function SWExp.Inventory:GetOpenKey()
    return cookie.GetNumber("swexp_key_inventory_open", KEY_I)
end

hook.Add("PlayerButtonDown", "SWExp::InventoryHotkey", function(ply, button)
    if button == SWExp.Inventory:GetOpenKey() and ply == LocalPlayer() then
        SWExp.Inventory:OpenUI()
    end
end)

-- ============================================================================
-- СИСТЕМА АПТЕЧЕК: ГОРЯЧАЯ КЛАВИША И HUD-ИНДИКАТОР
-- ============================================================================

SWExp.Inventory.MedkitHoT = {
    active      = false,
    duration    = 0,
    startTime   = 0,
    healPerTick = 0,
}

--- Читает привязанную клавишу аптечки из cookie (настраивается в F4 → Настройки)
function SWExp.Inventory:GetMedkitKey()
    return cookie.GetNumber("swexp_key_use_medkit", KEY_H)
end

-- Слушаем нажатие клавиши аптечки
hook.Add("PlayerButtonDown", "SWExp::MedkitHotkey", function(ply, button)
    if ply ~= LocalPlayer() then return end
    if button ~= SWExp.Inventory:GetMedkitKey() then return end

    -- Нельзя использовать если уже идёт хил
    if SWExp.Inventory.MedkitHoT.active then
        chat.AddText(Color(255, 200, 0), "[Аптечка] ", color_white, "Хил уже активен!")
        return
    end

    -- Проверяем: есть ли аптечка в медицинском слоте (клиентская проверка для UX)
    local eq       = SWExp.Inventory.LocalData.equipment["medical"]
    local hasMedkit = false
    if eq then
        for _, item in pairs(eq) do
            if item then
                local d = SWExp.Inventory:GetItemData(item.itemID)
                if d and d.healType == "hot" then hasMedkit = true; break end
            end
        end
    end

    if not hasMedkit then
        chat.AddText(Color(255, 80, 80), "[Аптечка] ", color_white, "Нет аптечки в медицинском слоте!")
        surface.PlaySound("buttons/button10.wav")
        return
    end

    -- Отправляем запрос на сервер
    netstream.Start("SWExp::UseMedkitHotkey")
    surface.PlaySound("items/smallmedkit1.wav")
end)

-- Получаем ответ от сервера о состоянии HoT
netstream.Hook("SWExp::MedkitHoTState", function(data)
    if data.noMedkit then
        chat.AddText(Color(255, 80, 80), "[Аптечка] ", color_white, "Нет аптечки в медицинском слоте!")
        surface.PlaySound("buttons/button10.wav")
        return
    end

    if data.alreadyHealing then
        chat.AddText(Color(255, 200, 0), "[Аптечка] ", color_white, "Хил уже активен!")
        return
    end

    if data.active then
        SWExp.Inventory.MedkitHoT.active      = true
        SWExp.Inventory.MedkitHoT.duration    = data.duration or 10
        SWExp.Inventory.MedkitHoT.startTime   = CurTime()
        SWExp.Inventory.MedkitHoT.healPerTick = data.healPerTick or 5
        chat.AddText(Color(0, 238, 119), "[Аптечка] ", color_white,
            "Хил активирован: +" .. data.healPerTick .. " HP/сек на " .. data.duration .. " сек.")
    else
        SWExp.Inventory.MedkitHoT.active = false
    end
end)

-- ============================================================================
-- HoT: СВЕЧЕНИЕ ПО КРАЯМ ЭКРАНА (вместо полоски прогресса)
-- ============================================================================

-- Кэшируем материалы градиентов
local _gradL = Material("vgui/gradient-l")
local _gradR = Material("vgui/gradient-r")
local _gradU = Material("vgui/gradient-u")
local _gradD = Material("vgui/gradient-d")

hook.Add("HUDPaint", "SWExp::MedkitHoT_ScreenGlow", function()
    local hot = SWExp.Inventory.MedkitHoT
    if not hot.active then return end

    local elapsed  = CurTime() - hot.startTime
    local fraction = math.Clamp(1 - elapsed / hot.duration, 0, 1)

    if fraction <= 0 then
        hot.active = false
        return
    end

    local sw, sh = ScrW(), ScrH()

    -- Размер «языка» свечения (от края к центру)
    local glowSize = math.floor(sw * 0.15)

    -- Пульсирующая альфа: плавно мигает — максимум 70, чтобы не залеплять экран
    local pulse  = 0.6 + math.abs(math.sin(CurTime() * 2.6)) * 0.4
    -- Постепенно угасает к концу действия аптечки
    local baseA  = math.floor(70 * fraction * pulse)

    local r, g, b = 0, 238, 119   -- зелёный SWUI

    -- Левый край
    surface.SetDrawColor(r, g, b, baseA)
    surface.SetMaterial(_gradL)
    surface.DrawTexturedRect(0, 0, glowSize, sh)

    -- Правый край
    surface.SetDrawColor(r, g, b, baseA)
    surface.SetMaterial(_gradR)
    surface.DrawTexturedRect(sw - glowSize, 0, glowSize, sh)

    -- Верхний край
    surface.SetDrawColor(r, g, b, baseA)
    surface.SetMaterial(_gradU)
    surface.DrawTexturedRect(0, 0, sw, glowSize)

    -- Нижний край
    surface.SetDrawColor(r, g, b, baseA)
    surface.SetMaterial(_gradD)
    surface.DrawTexturedRect(0, sh - glowSize, sw, glowSize)
end)

