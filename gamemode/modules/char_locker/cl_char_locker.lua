-- ============================================================
-- Star Wars: Expedition — Хранилище персонажа (клиент)
-- modules/char_locker/cl_char_locker.lua
-- ============================================================

if SERVER then return end

SWExp.CharLocker = SWExp.CharLocker or {}

-- ============================================================
-- Открытие обоих окон: инвентарь + хранилище
-- ============================================================

-- Внутренняя функция — создаёт окно хранилища.
-- Вызывается только когда инвентарь уже гарантированно открыт.
local function _BuildLockerWindow()
    if IsValid(SWExp.CharLocker.UI) then return end  -- уже открыто

    local cfg  = SWExp.Inventory.Config
    local CELL = cfg.CellSize
    local GW   = cfg.StorageGridWidth   -- 15
    local GH   = cfg.StorageGridHeight  -- 10

    local PAD   = 12
    local WND_W = PAD + GW * CELL + PAD
    local WND_H = 44 + PAD + 28 + GH * CELL + PAD + 36 + PAD

    local frame, content = SWUI.Animated.CreateWindow(
        "ХРАНИЛИЩЕ ПЕРСОНАЖА", WND_W, WND_H, nil,
        Color(50, 180, 255)
    )
    SWExp.CharLocker.UI = frame

    -- Расставляем оба окна рядом без перекрытия.
    -- Хранилище — слева, инвентарь — справа.
    -- Пара центрируется по экрану; если суммарная ширина > экрана,
    -- оба окна сдвигаются к левому краю с минимальным отступом.
    local GAP = 10
    if IsValid(SWExp.Inventory.UI) then
        local invFrame = SWExp.Inventory.UI
        local iw = invFrame:GetWide()
        local ih = invFrame:GetTall()

        local totalW = WND_W + GAP + iw
        local startX = math.max(4, math.floor((ScrW() - totalW) / 2))
        local startY = math.max(4, math.floor((ScrH() - math.max(WND_H, ih)) / 2))

        -- Хранилище слева
        frame:SetPos(startX, startY)
        -- Инвентарь правее хранилища
        invFrame:SetPos(startX + WND_W + GAP, startY)
    else
        frame:Center()
    end

    -- Заголовок секции
    SWUI.CreateSectionHeader(content,
        "ЛИЧНЫЙ СТАШ (" .. GW .. "\195\151" .. GH .. ")",
        PAD, PAD, GW * CELL)

    -- Сетка хранилища (переиспользуем CreateGrid из Inventory)
    local storageGrid = SWExp.Inventory:CreateGrid(content, GW, GH, "storage")
    storageGrid:SetPos(PAD, PAD + 28)
    SWExp.CharLocker.StorageGrid = storageGrid

    SWExp.Inventory:DrawItems(storageGrid, SWExp.Inventory.LocalData.storage, "storage")

    -- Нижняя строка: счётчик заполненности
    local bottomY = PAD + 28 + GH * CELL + PAD
    local bottomH = 32

    local countPanel = vgui.Create("DPanel", content)
    countPanel:SetPos(PAD, bottomY)
    countPanel:SetSize(GW * CELL, bottomH)
    countPanel.Paint = function(p, w, h)
        SWUI.DrawPanel(0, 0, w, h, 4, SWUI.Colors.Panel2, SWUI.Colors.Border, 1)
        local stor  = SWExp.Inventory.LocalData.storage
        local count = 0
        for _ in pairs(stor and stor.items or {}) do count = count + 1 end
        SWUI.DrawText(
            string.format("Занято: %d / %d ячеек", count, GW * GH),
            "SWUI.Tiny", 12, h / 2,
            SWUI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
        )
        SWUI.DrawText(
            "Перетащите предметы между окнами",
            "SWUI.Tiny", w - 12, h / 2,
            SWUI.Colors.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
        )
    end

    -- Закрытие инвентаря автоматически закрывает хранилище и наоборот
    local invFrame = SWExp.Inventory.UI
    if IsValid(invFrame) then
        local origInvClose = invFrame.Close
        invFrame.Close = function(f)
            if IsValid(SWExp.CharLocker.UI) then
                SWExp.CharLocker.UI:Remove()
            end
            origInvClose(f)
        end
    end

    frame.OnClose = function()
        SWExp.CharLocker.UI          = nil
        SWExp.CharLocker.StorageGrid = nil
        -- Закрываем инвентарь, если он ещё открыт
        if IsValid(SWExp.Inventory.UI) then
            SWExp.Inventory.UI:Close()
        end
    end
end

function SWExp.CharLocker:OpenUI()
    -- Если оба окна уже открыты — закрываем оба
    if IsValid(self.UI) or IsValid(SWExp.Inventory.UI) then
        if IsValid(self.UI)            then self.UI:Close() end
        if IsValid(SWExp.Inventory.UI) then SWExp.Inventory.UI:Close() end
        return
    end

    -- Сначала открываем инвентарь (он сам запросит SWExp::RequestInventoryOpen),
    -- затем строим окно хранилища рядом с ним.
    SWExp.Inventory:OpenUI()

    -- Небольшая задержка: ждём окончания анимации открытия инвентаря,
    -- чтобы его позиция была финальной.
    timer.Simple(0.08, function()
        _BuildLockerWindow()
    end)
end

-- ============================================================
-- Обновление отрисовки при синхронизации данных
-- (вызывается после получения SWExp::InventorySync)
-- ============================================================

function SWExp.CharLocker:RefreshUI()
    if not IsValid(self.StorageGrid) then return end
    -- Сначала удаляем старые панели предметов и сбрасываем занятость ячеек,
    -- иначе на месте перемещённых предметов остаются "призраки".
    SWExp.Inventory:ClearItemPanels(self.StorageGrid)
    SWExp.Inventory:DrawItems(
        self.StorageGrid,
        SWExp.Inventory.LocalData.storage,
        "storage"
    )
end

-- ============================================================
-- Netstream: сервер говорит открыть хранилище
-- ============================================================

netstream.Hook("SWExp::OpenCharLocker", function()
    -- InventorySync уже получен чуть раньше этого пакета (сервер шлёт их подряд).
    -- Открываем оба окна: инвентарь и хранилище.
    SWExp.CharLocker:OpenUI()
end)

-- ============================================================
-- Перехватываем InventorySync чтобы обновить окно хранилища,
-- если оно уже открыто
-- ============================================================

hook.Add("SWExp::InventorySynced", "SWExp::CharLocker_Refresh", function()
    SWExp.CharLocker:RefreshUI()
end)

-- ============================================================
-- Закрывать окно хранилища при смене персонажа
-- ============================================================

netstream.Hook("SWExp::CharSelected", function()
    if IsValid(SWExp.CharLocker.UI) then
        SWExp.CharLocker.UI:Close()
    end
end)
