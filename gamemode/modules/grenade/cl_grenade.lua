-- ============================================================
-- Star Wars: Expedition — Клиентская часть гранатных слотов
-- modules/grenade/cl_grenade.lua
--
-- Что делает:
--   * 2 настраиваемые клавиши: throw (бросок) и cycle (переключатель слота)
--     Привязка через F4 → Настройки → Гранаты (cookie: swexp_key_grenade_*)
--   * Cycle перебирает слоты по кругу 1→2→3→1; пустые слоты пропускаются,
--     если есть хоть один заполненный.
--   * При нажатии throw — шлёт netstream на сервер
--   * Рисует HUD с тремя слотами (внизу справа, выше индикатора патронов)
--   * Принимает фидбек от сервера (cooldown / empty / busy)
-- ============================================================

SWExp.Grenade        = SWExp.Grenade or {}
SWExp.Grenade.Active = SWExp.Grenade.Active or 1   -- активный слот (1..3)

-- ============================================================
-- 1. ЧТЕНИЕ КЛАВИШ ИЗ COOKIE (общий ключ с F4)
-- ============================================================

function SWExp.Grenade:GetThrowKey()
    return cookie.GetNumber("swexp_key_grenade_throw", KEY_G)
end

function SWExp.Grenade:GetCycleKey()
    return cookie.GetNumber("swexp_key_grenade_cycle", KEY_V)
end

-- ============================================================
-- 2. ЦИКЛИЧЕСКОЕ ПЕРЕКЛЮЧЕНИЕ СЛОТА
--    Идём по кругу. Если все слоты пусты — просто инкремент.
--    Если есть хоть один заполненный — следующий заполненный.
-- ============================================================

local function GetGrenadeSlots()
    local eq = SWExp.Inventory and SWExp.Inventory.LocalData
               and SWExp.Inventory.LocalData.equipment
    return eq and eq["grenade"] or {}
end

local function CountFilled(slots)
    local n = 0
    for _, v in pairs(slots) do
        if v then n = n + 1 end
    end
    return n
end

function SWExp.Grenade:CycleActive()
    local slots = GetGrenadeSlots()
    local count = (SWExp.Grenade.Config and SWExp.Grenade.Config.SlotCount) or 3
    local filled = CountFilled(slots)

    if filled == 0 then
        -- Все пусты — просто +1 по кругу
        self.Active = (self.Active % count) + 1
        return
    end

    -- Идём по кругу, ищем следующий заполненный
    local cur = self.Active
    for _ = 1, count do
        cur = (cur % count) + 1
        if slots[cur] then
            self.Active = cur
            return
        end
    end
end

-- ============================================================
-- 3. ОБРАБОТЧИК НАЖАТИЙ
-- ============================================================

-- Дебаунс: PlayerButtonDown в Garry's Mod иногда триггерится дважды
-- на один физический нажим (особенно с low fps или auto-repeat). Защищаемся
-- минимальным интервалом между обработанными нажатиями для каждой клавиши.
local DEBOUNCE_INTERVAL = 0.18    -- секунды
local _lastFire = {}              -- [keyCode] = lastCurTime

local function debounce(keyCode)
    local now = CurTime()
    local last = _lastFire[keyCode] or 0
    if now - last < DEBOUNCE_INTERVAL then return false end
    _lastFire[keyCode] = now
    return true
end

hook.Add("PlayerButtonDown", "SWExp::Grenade::Hotkeys", function(ply, button)
    if ply ~= LocalPlayer() then return end
    if not IsValid(ply) or not ply:Alive() then return end
    if vgui.GetKeyboardFocus() then return end

    local kThrow = SWExp.Grenade:GetThrowKey()
    local kCycle = SWExp.Grenade:GetCycleKey()

    if button == kCycle then
        if not debounce(kCycle) then return end
        SWExp.Grenade:CycleActive()
        surface.PlaySound("ui/buttonclick.wav")
        return
    end

    if button == kThrow then
        if not debounce(kThrow) then return end
        local slots = GetGrenadeSlots()
        if not slots[SWExp.Grenade.Active] then
            chat.AddText(Color(255, 80, 80), "[Граната] ", color_white,
                "Слот "..SWExp.Grenade.Active.." пуст!")
            surface.PlaySound((SWExp.Grenade.Config and SWExp.Grenade.Config.EmptyClickSound)
                              or "buttons/button10.wav")
            return
        end
        netstream.Start("SWExp::ThrowGrenade", { slotIndex = SWExp.Grenade.Active })
    end
end)

-- ============================================================
-- 4. ФИДБЕК ОТ СЕРВЕРА
-- ============================================================

netstream.Hook("SWExp::GrenadeFeedback", function(data)
    if not data or not data.type then return end
    if data.type == "cooldown" then
        chat.AddText(Color(255, 200, 0), "[Граната] ", color_white,
            string.format("Кулдаун: %.1f сек", data.remaining or 0))
    elseif data.type == "empty" then
        chat.AddText(Color(255, 80, 80), "[Граната] ", color_white, "Слот пуст!")
        surface.PlaySound("buttons/button10.wav")
    elseif data.type == "busy" then
        chat.AddText(Color(255, 200, 0), "[Граната] ", color_white, "Уже бросаете!")
    elseif data.type == "invalid" then
        chat.AddText(Color(255, 80, 80), "[Граната] ", color_white, "Граната недоступна.")
    end
end)

-- ============================================================
-- 5. HUD-ИНДИКАТОР (3 слота гранат, внизу справа)
--    Поднят выше, чтобы не перекрывать индикатор патронов.
-- ============================================================

local HUD_W      = 56
local HUD_H      = 56
local HUD_GAP    = 6
local HUD_MARGIN_X = 24
local HUD_MARGIN_Y = 180   -- было ~110 — поднимаем над патронами

local function CreateGrenadeFonts()
    surface.CreateFont("SWExpGrenadeKey", {
        font = "Exo 2", size = 14, weight = 700, antialias = true, extended = true,
    })
    surface.CreateFont("SWExpGrenadeName", {
        font = "Exo 2", size = 13, weight = 500, antialias = true, extended = true,
    })
    surface.CreateFont("SWExpGrenadeNum", {
        font = "Exo 2", size = 18, weight = 800, antialias = true, extended = true,
    })
end

CreateGrenadeFonts()
hook.Add('OnScreenSizeChanged', 'SWExp::Grenade::RecreateFonts', CreateGrenadeFonts)
hook.Add('InitPostEntity', 'SWExp::Grenade::RecreateFontsOnInit', function()
    CreateGrenadeFonts()
    timer.Simple(5, function()
        if IsValid(LocalPlayer()) then CreateGrenadeFonts() end
    end)
end)

local KEY_NAMES = {}
local function KeyDisplay(keyCode)
    if not keyCode or keyCode == 0 then return "—" end
    if KEY_NAMES[keyCode] then return KEY_NAMES[keyCode] end
    local name = input.GetKeyName(keyCode) or "?"
    name = string.upper(name)
    KEY_NAMES[keyCode] = name
    return name
end

-- Слушаем смену клавиш в F4 (cookie перепишется — нам надо сбросить кеш)
hook.Add("Think", "SWExp::Grenade::InvalidateKeyCache", function()
    -- Дешёвая инвалидация: раз в 2 сек пересобираем кеш
    if (SWExp.Grenade._lastInvalidate or 0) < CurTime() then
        KEY_NAMES = {}
        SWExp.Grenade._lastInvalidate = CurTime() + 2
    end
end)

hook.Add("HUDPaint", "SWExp::Grenade::HUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    local slots = GetGrenadeSlots()

    local count = (SWExp.Grenade.Config and SWExp.Grenade.Config.SlotCount) or 3
    local totalW = count * HUD_W + (count - 1) * HUD_GAP
    local startX = ScrW() - totalW - HUD_MARGIN_X
    local y      = ScrH() - HUD_H - HUD_MARGIN_Y

    for i = 1, count do
        local x = startX + (i - 1) * (HUD_W + HUD_GAP)
        local item = slots[i]
        local active = (i == SWExp.Grenade.Active)

        -- Фон
        local bgColor = active and Color(40, 80, 110, 220) or Color(20, 20, 25, 180)
        draw.RoundedBox(6, x, y, HUD_W, HUD_H, bgColor)

        -- Рамка активного
        if active then
            surface.SetDrawColor(0, 184, 255, 255)
            surface.DrawOutlinedRect(x, y, HUD_W, HUD_H, 2)
        else
            surface.SetDrawColor(60, 60, 70, 255)
            surface.DrawOutlinedRect(x, y, HUD_W, HUD_H, 1)
        end

        -- Номер слота сверху-слева внутри ячейки
        draw.SimpleText(tostring(i), "SWExpGrenadeNum",
            x + 6, y + 4, Color(168, 204, 220, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        if item then
            local d = SWExp.Inventory:GetItemData(item.itemID)
            if d and d.icon then
                local mat = Material(d.icon)
                if mat and not mat:IsError() then
                    surface.SetMaterial(mat)
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.DrawTexturedRect(x + (HUD_W - 32) / 2, y + 12, 32, 32)
                end
            end
            if d and d.name then
                draw.SimpleText(string.sub(d.name, 1, 12), "SWExpGrenadeName",
                    x + HUD_W / 2, y + HUD_H - 12, Color(220, 230, 240, 230),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        else
            draw.SimpleText("—", "SWExpGrenadeNum",
                x + HUD_W / 2, y + HUD_H / 2, Color(80, 80, 90, 200),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- Подпись с клавишами над панелью
    local throwKey = SWExp.Grenade:GetThrowKey()
    local cycleKey = SWExp.Grenade:GetCycleKey()
    draw.SimpleText("Бросок: ["..KeyDisplay(throwKey).."]   Сменить: ["..KeyDisplay(cycleKey).."]",
        "SWExpGrenadeKey",
        startX + totalW, y - 6,
        Color(168, 204, 220, 220),
        TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
end)

print("[SWExp][Grenade] cl_grenade.lua загружен")
