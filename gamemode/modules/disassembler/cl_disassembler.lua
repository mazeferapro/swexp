-- ============================================================
-- Star Wars: Expedition — Дисассемблер (клиент)
-- modules/cl_disassembler.lua
-- ============================================================

if SERVER then return end

SWExp.Disassembler = SWExp.Disassembler or {}

-- Локальные данные
SWExp.Disassembler._bank  = 0
SWExp.Disassembler._items = {}   -- таблица {uniqueID, itemID, amount, refund}

-- ============================================================
-- Net: открыть меню
-- ============================================================

net.Receive("SWExp::Disasm_Open", function()
    SWExp.Disassembler._bank  = net.ReadInt(32)
    local json                = net.ReadString()
    SWExp.Disassembler._items = util.JSONToTable(json) or {}

    SWExp.Disassembler.OpenMenu()
end)

-- ============================================================
-- Net: результат разборки
-- ============================================================

net.Receive("SWExp::Disasm_Result", function()
    local ok      = net.ReadBool()
    local str     = net.ReadString()
    local uid     = net.ReadString()
    local num     = net.ReadInt(16)
    local newBank = net.ReadInt(32)

    SWExp.Disassembler._bank = newBank

    if ok then
        local name     = str
        local uniqueID = uid
        local refund   = num   -- now total for the stack that was disassembled

        chat.AddText(
            Color(255, 165, 0),   "[Дисассемблер] ",
            Color(200, 220, 255), "Разобрано: ",
            Color(255, 240, 130), name,
            Color(200, 220, 255), "  → банк ",
            Color(80, 220, 130),  "+" .. refund .. " мат."
        )
        if SWExp and SWExp.Notify then
            SWExp.Notify("Разобрано: " .. name .. " +" .. refund .. " мат.", NOTIFY_HINT, 5)
        end

        -- Обновить меню БЕЗ закрытия (оставляем открытым для следующих разборов)
        if IsValid(SWExp.Disassembler._frame) then
            -- Удаляем разобранный предмет из локального кэша по uniqueID
            local items = SWExp.Disassembler._items or {}
            for i = #items, 1, -1 do
                if items[i].uniqueID == uniqueID then
                    table.remove(items, i)
                    break
                end
            end
            if SWExp.Disassembler.RefreshList then
                SWExp.Disassembler.RefreshList()
            end
            if SWExp.Disassembler._refreshBank then
                SWExp.Disassembler._refreshBank()
            end
        end
    else
        local msg = str
        chat.AddText(Color(255, 80, 80), "[Дисассемблер] ", Color(200, 180, 180), msg)
        if SWExp and SWExp.Notify then
            SWExp.Notify(msg, NOTIFY_ERROR, 5)
        end
    end
end)

-- Синхронизация банка (если поменялся через ассемблер/другие действия пока меню открыто)
net.Receive("SWExp::Assembler_Update", function()
    SWExp.Disassembler._bank = net.ReadInt(32)
    if IsValid(SWExp.Disassembler._frame) and SWExp.Disassembler._refreshBank then
        SWExp.Disassembler._refreshBank()
    end
end)

-- ============================================================
-- Вспомогательная функция заполнения списка (используется и для начального открытия, и для RefreshList)
-- ============================================================

local function PopulateDisasmList(scroll, items, rowW)
    if not IsValid(scroll) then return end
    scroll:Clear()

    local rowH = 80
    local btnW = 120
    local cfg  = SWExp.AssemblerConfig

    if not items or #items == 0 then
        local lbl = vgui.Create("DLabel", scroll)
        lbl:SetText("В вашем инвентаре нет предметов, которые можно разобрать.")
        lbl:SetFont("SWUI.Body")
        lbl:SetTextColor(SWUI.Colors.TextDim)
        lbl:SizeToContents()
        lbl:SetPos(10, 12)
        return
    end

    for i, item in ipairs(items) do
        local uniqueID = item.uniqueID
        local itemID   = item.itemID
        local amount   = item.amount or 1
        local refund   = item.refund or 0

        -- Данные предмета из инвентарного конфига
        local itemData = SWExp.Inventory and SWExp.Inventory.Items and SWExp.Inventory.Items[itemID]
        local dispName = (itemData and itemData.name) or itemID
        local dispDesc = (itemData and itemData.description) or ""
        local itemIcon = itemData and itemData.icon

        -- Если нет в инвентаре — ищем в рецептах
        if not itemIcon and cfg then
            local recipe = cfg.GetRecipeIcon and cfg.GetRecipeIcon({ result = itemID }) or nil
            itemIcon = recipe
        end

        local row = vgui.Create("DPanel", scroll)
        row:SetPos(0, (i - 1) * (rowH + 5))
        row:SetSize(rowW, rowH)

        row.Paint = function(self, pw, ph)
            local hov = self:IsHovered() or (IsValid(self._btn) and self._btn:IsHovered())
            SWUI.DrawRoundedRect(0, 0, pw, ph, 6,
                hov and Color(30, 18, 4) or Color(14, 10, 4))
            surface.SetDrawColor(hov and Color(255, 140, 0) or Color(60, 40, 10))
            surface.DrawOutlinedRect(0, 0, pw, ph, 1)

            -- Иконка предмета
            if itemIcon then
                local mat = Material(itemIcon)
                if mat and not mat:IsError() then
                    surface.SetMaterial(mat)
                    surface.SetDrawColor(255, 255, 255)
                    surface.DrawTexturedRect(12, ph / 2 - 16, 32, 32)
                end
            end

            -- Название и описание
            local nameX = itemIcon and 54 or 14
            SWUI.DrawText(dispName, "SWUI.Body", nameX, 12,
                SWUI.Colors.TextHi, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            SWUI.DrawText(dispDesc, "SWUI.Tiny", nameX, 34,
                SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            -- Количество
            if amount > 1 then
                SWUI.DrawText("×" .. amount, "SWUI.Small", nameX, 52,
                    SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end

            -- Возврат материалов (уже total для этого стека)
            SWUI.DrawText("+" .. refund .. " мат.", "SWUI.Body", pw - btnW - 16, ph / 2,
                Color(80, 220, 130), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        -- Кнопка РАЗОБРАТЬ
        local btn = vgui.Create("DPanel", row)
        btn:SetPos(rowW - btnW - 8, (rowH - 36) / 2)
        btn:SetSize(btnW, 36)
        btn:SetCursor("hand")
        row._btn = btn

        btn.Paint = function(self, bw, bh)
            local hov = self:IsHovered()
            SWUI.DrawRoundedRect(0, 0, bw, bh, 4,
                hov and Color(50, 30, 0) or Color(28, 16, 0))
            surface.SetDrawColor(hov and Color(255, 165, 0) or Color(130, 80, 0))
            surface.DrawOutlinedRect(0, 0, bw, bh, 1)
            SWUI.DrawText("РАЗОБРАТЬ", "SWUI.Small", bw / 2, bh / 2,
                Color(255, 165, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        btn.OnMousePressed = function()
            -- Блокируем повторные клики до ответа сервера
            btn:SetCursor("arrow")
            btn.Paint = function(self, bw, bh)
                SWUI.DrawRoundedRect(0, 0, bw, bh, 4, Color(15, 10, 4))
                surface.SetDrawColor(SWUI.Colors.Border)
                surface.DrawOutlinedRect(0, 0, bw, bh, 1)
                SWUI.DrawText("...", "SWUI.Small", bw / 2, bh / 2,
                    SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            net.Start("SWExp::Disasm_Req")
                net.WriteString(uniqueID)
            net.SendToServer()
        end
    end
end

-- ============================================================
-- VGUI МЕНЮ
-- ============================================================

function SWExp.Disassembler.OpenMenu()
    if IsValid(SWExp.Disassembler._frame) then
        SWExp.Disassembler._frame:Close()
    end

    local items = SWExp.Disassembler._items

    -- ============================================================
    -- Размеры
    -- ============================================================
    local W, H = 700, 600
    local PAD  = 16

    local frame, content = SWUI.Animated.CreateWindow(
        "ДИСАССЕМБЛЕР", W, H, nil, Color(255, 140, 0))
    SWExp.Disassembler._frame = frame

    -- Очистка ссылок при закрытии окна пользователем (чтобы Refresh не пытался обновлять мёртвый UI)
    local origClose = frame.Close
    frame.Close = function(self)
        SWExp.Disassembler._frame      = nil
        SWExp.Disassembler._listScroll = nil
        SWExp.Disassembler._rowW       = nil
        origClose(self)
    end

    local cW = content:GetWide()
    local cH = content:GetTall()

    -- ============================================================
    -- ВЕРХНЯЯ ПАНЕЛЬ — банк
    -- ============================================================
    local topH   = 56
    local topBar = vgui.Create("DPanel", content)
    topBar:SetPos(PAD, PAD)
    topBar:SetSize(cW - PAD * 2, topH)
    topBar.Paint = function(self, pw, ph)
        SWUI.DrawRoundedRect(0, 0, pw, ph, 6, SWUI.Colors.Panel2)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawOutlinedRect(0, 0, pw, ph, 1)

        local bank = SWExp.Disassembler._bank

        SWUI.DrawText("БАНК МАТЕРИАЛОВ", "SWUI.Tiny", 14, 10,
            SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        SWUI.DrawText(tostring(bank), "SWUI.MonoLarge", 14, ph,
            Color(255, 165, 0), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawLine(160, 8, 160, ph - 8)

        SWUI.DrawText("ВОЗВРАТ", "SWUI.Tiny", 176, 10,
            SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        SWUI.DrawText("50% стоимости → в банк", "SWUI.Small", 176, ph / 2,
            Color(200, 160, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        -- Подсказка справа
        SWUI.DrawText("Выберите предмет для разборки", "SWUI.Small", pw - 14, ph / 2,
            SWUI.Colors.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    -- Функция обновления банка в топ-баре
    SWExp.Disassembler._refreshBank = function()
        if IsValid(topBar) then topBar:InvalidateLayout(true) end
    end

    -- ============================================================
    -- ОБЛАСТЬ СПИСКА ПРЕДМЕТОВ
    -- ============================================================
    local listY = PAD + topH + PAD
    local listH = cH - listY - PAD

    local listPanel = vgui.Create("DPanel", content)
    listPanel:SetPos(PAD, listY)
    listPanel:SetSize(cW - PAD * 2, listH)
    listPanel.Paint = function(self, pw, ph)
        SWUI.DrawRoundedRect(0, 0, pw, ph, 8, SWUI.Colors.Panel2)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawOutlinedRect(0, 0, pw, ph, 1)
    end

    local scroll = vgui.Create("DScrollPanel", listPanel)
    scroll:SetPos(6, 6)
    scroll:SetSize(cW - PAD * 2 - 12, listH - 12)
    scroll:GetVBar():SetWide(4)
    scroll:GetVBar().Paint = function(s, pw, ph)
        draw.RoundedBox(2, 0, 0, pw, ph, Color(255, 255, 255, 12))
    end
    scroll:GetVBar().btnGrip.Paint = function(s, pw, ph)
        draw.RoundedBox(2, 0, 0, pw, ph, Color(255, 140, 0))
    end

    -- Сохраняем ссылки для последующих обновлений списка без закрытия окна
    SWExp.Disassembler._listScroll = scroll
    local rowW = cW - PAD * 2 - 20
    SWExp.Disassembler._rowW = rowW

    -- Заполняем список (поддерживает пустой случай)
    PopulateDisasmList(scroll, items, rowW)
end

-- ============================================================
-- Обновление списка предметов "на лету" (после успешного разбора, без закрытия меню)
-- ============================================================

function SWExp.Disassembler.RefreshList()
    local scroll = SWExp.Disassembler._listScroll
    local rowW   = SWExp.Disassembler._rowW or 640
    if not IsValid(scroll) then return end

    local items = SWExp.Disassembler._items or {}
    PopulateDisasmList(scroll, items, rowW)
end

print("[SWExp] Модуль дисассемблера (клиент) загружен.")
